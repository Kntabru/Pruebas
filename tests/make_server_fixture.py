"""Produce a LOCAL-ONLY fixture from supplied metadata, with invented users and mock auth.
This is not a production schema dump. Unmodified membership/week helpers are modeled.
"""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
tables=json.loads((root/'validation/server-structure-observed.json').read_text())
security=json.loads((root/'validation/server-security-observed.json').read_text())
q=lambda name:'"'+name.replace('"','""')+'"'
parts=['''-- LOCAL TEST FIXTURE ONLY. Never execute in Supabase.
DO $$BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='postgres') THEN CREATE ROLE postgres SUPERUSER;END IF;
IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon;END IF;
IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated;END IF;
IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role BYPASSRLS;END IF;END $$;
SET ROLE postgres;
CREATE SCHEMA auth;
CREATE SCHEMA palabreo_private;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
GRANT USAGE ON SCHEMA auth TO authenticated,anon;
SET check_function_bodies=off;
''']
parts.append((root/'sql/observed/public.palabreo_points.sql').read_text())
for row in tables:
 if row['name']=='word_review_queue':continue
 columns=[]
 for c in row['columns']:
  field=q(c['columna'])+' '+c['tipo'];default=c['default']
  if default:
   default=default.replace('\\n','\n')
   field+=(' GENERATED ALWAYS AS ('+default+') STORED') if c['columna']=='points' else ' DEFAULT '+default
  if c['not_null']:field+=' NOT NULL'
  columns.append(field)
 parts.append('CREATE TABLE '+q(row['schema'])+'.'+q(row['name'])+' ('+',\n'.join(columns)+');')
# Unique/primary first, other checks next, references last.
constraints=[]
for row in tables:
 for c in row['constraints'] or []:
  priority=2 if c['definicion'].startswith('FOREIGN KEY') else 0 if c['definicion'].startswith(('PRIMARY KEY','UNIQUE')) else 1
  constraints.append((priority,f'ALTER TABLE {q(row["schema"])}.{q(row["name"])} ADD CONSTRAINT {q(c["nombre"])} {c["definicion"]};'))
parts.extend(text for _,text in sorted(constraints))
constraint_names={c['nombre'] for row in tables for c in row['constraints'] or []}
for row in tables:
 for index in row['indexes'] or []:
  name=re.search(r'CREATE (?:UNIQUE )?INDEX (\S+)',index).group(1)
  if name.strip('"') not in constraint_names:parts.append(index+';')
parts.append('''CREATE FUNCTION public.palabreo_is_member(wanted_league uuid) RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path TO '' AS $$
 SELECT EXISTS(SELECT 1 FROM public.league_members WHERE league_id=wanted_league AND user_id=auth.uid() AND left_at IS NULL)$$;
CREATE FUNCTION public.palabreo_week(day date) RETURNS date LANGUAGE sql IMMUTABLE AS $$SELECT date_trunc('week',day::timestamp)::date$$;
''')
for p in sorted((root/'sql/observed').glob('*.sql')):parts.append(p.read_text())
for row in security:
 name=q(row['schema'])+'.'+q(row['name']);d=row['details']
 if row['type']=='esquema':
  name=q(row['schema'])
  parts.append(f'REVOKE ALL ON SCHEMA {name} FROM PUBLIC;')
  parts.append(f'GRANT USAGE ON SCHEMA {name} TO service_role;')
  if row['schema']=='public':parts.append(f'GRANT USAGE ON SCHEMA {name} TO anon,authenticated;')
 elif row['type']=='objeto' and row['name']!='word_review_queue':
  if d['rls']:parts.append(f'ALTER TABLE {name} ENABLE ROW LEVEL SECURITY;')
  parts.append(f'GRANT ALL ON {name} TO service_role;')
  if 'authenticated=r/' in d['permisos']:parts.append(f'GRANT SELECT ON {name} TO authenticated;')
 elif row['type']=='trigger':parts.append(d['definicion']+';')
 elif row['type']=='RLS':
  policy=f'CREATE POLICY {q(d["politica"])} ON {name} FOR {d["comando"]} TO '+','.join(q(role) for role in d['roles'])
  if d['using']:policy+=' USING ('+d['using']+')'
  if d['check']:policy+=' WITH CHECK ('+d['check']+')'
  parts.append(policy+';')
# Match observed function ACLs (not the special global defaults of a new local database).
parts.append('''DO $acl$ DECLARE f record; BEGIN
FOR f IN SELECT p.oid::regprocedure AS signature,n.nspname,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('public','palabreo_private') LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.signature);
 IF f.nspname='public' THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.signature);END IF;
END LOOP;END $acl$;
-- Invented fixtures only. No real users or online words are imported.
INSERT INTO auth.users(id) VALUES ('11111111-1111-4111-8111-111111111111'),('22222222-2222-4222-8222-222222222222'),('33333333-3333-4333-8333-333333333333');
INSERT INTO public.profiles(id,alias) VALUES ('11111111-1111-4111-8111-111111111111','Local One'),('22222222-2222-4222-8222-222222222222','Local Two'),('33333333-3333-4333-8333-333333333333','Local Outsider');
SET request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
''')
text=(root/'js/game.js').read_text();answers=re.search(r'const answers\s*=\s*`([^`]+)`',text).group(1).split()
answers=[a for a in dict.fromkeys(answers) if re.fullmatch('[A-ZÑ]{5}',a)]
parts.append("INSERT INTO palabreo_private.word_catalog(word,is_answer) SELECT w,true FROM unnest(string_to_array('"+' '.join(answers)+"',' ')) w;")
parts.append("SELECT public.palabreo_create_league('Legacy five',3);\nSELECT public.palabreo_day((SELECT id FROM public.leagues WHERE name='Legacy five'));\n")
# Keep a completed historical result to detect accidental changes in migration.
parts.append("SELECT public.palabreo_guess((public.palabreo_open_round((SELECT id FROM public.challenges WHERE league_id IS NOT NULL ORDER BY slot LIMIT 1))->>'id')::uuid,(SELECT answer FROM palabreo_private.solutions WHERE challenge_id=(SELECT id FROM public.challenges WHERE league_id IS NOT NULL ORDER BY slot LIMIT 1)),gen_random_uuid());")
(root/'tests/local_fixture.sql').write_text('\n'.join(parts)+'\n')
print('Local fixture generated. Never use tests/local_fixture.sql in Supabase.')
