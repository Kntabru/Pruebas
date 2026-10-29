"""Run ONLY against the synthetic LOCAL database from make_server_fixture.py.
No Supabase URL, password or remote database argument is accepted.
"""
from pathlib import Path
import hashlib,json,subprocess,sys,concurrent.futures
ROOT=Path(__file__).resolve().parents[1]
PSQL='/workspace/server-validation/postgresql/usr/lib/postgresql/17/bin/psql'
SOCKET='/workspace/server-validation/socket'
base=[PSQL,'-X','-q','-A','-t','-v','ON_ERROR_STOP=1','-h',SOCKET,'-U','agent','-d','palabreo_test']
U1='11111111-1111-4111-8111-111111111111';U2='22222222-2222-4222-8222-222222222222';U3='33333333-3333-4333-8333-333333333333'
def sql(text,user=None,fail=False):
 prefix=f"SET ROLE authenticated;SET request.jwt.claim.sub='{user}';" if user else 'SET ROLE postgres;'
 r=subprocess.run(base+['-c',prefix+text],capture_output=True,text=True)
 if fail:
  assert r.returncode!=0,'Expected rejection: '+text[:100]
  return r.stderr
 if r.returncode:raise RuntimeError(r.stderr+'\nSQL: '+text[:300])
 return r.stdout.strip()
def js(text,user=None):return json.loads(sql(text,user))
def snapshot():
 tables=json.loads((ROOT/'validation/server-structure-observed.json').read_text());result={}
 for t in tables:
  if t['name']=='word_review_queue':continue
  name=t['schema']+'.'+t['name'];where=" WHERE char_length(word)=5" if t['name']=='word_catalog' else ''
  result[name]=js("SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) FROM (SELECT to_jsonb(t)-'length_mode'-'word_length' v FROM "+name+' t'+where+') s')
 return result
before=snapshot()
permissions=sql("SELECT jsonb_agg(jsonb_build_array(n.nspname,c.relname,c.relacl::text,c.relrowsecurity,c.relforcerowsecurity) ORDER BY n.nspname,c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('public','palabreo_private') AND c.relkind='r'")
r=subprocess.run(base+['-c','SET ROLE postgres','-f',str(ROOT/'sql/migrations/palabreo_1_20.sql')],capture_output=True,text=True)
if r.returncode:raise RuntimeError(r.stderr)
assert before==snapshot(),'Migration changed existing data'
assert permissions==sql("SELECT jsonb_agg(jsonb_build_array(n.nspname,c.relname,c.relacl::text,c.relrowsecurity,c.relforcerowsecurity) ORDER BY n.nspname,c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('public','palabreo_private') AND c.relkind='r'"),'Table grants/RLS changed'
checks=['existing rows preserved','table ACL/RLS preserved']
old=js("SELECT public.palabreo_leagues()",U1)[0]['id']
assert sql(f"SELECT length_mode FROM public.leagues WHERE id='{old}'")=='5'
for mode in ['5','6','7','random']:
 lid=sql(f"SELECT public.palabreo_create_league_v120('New {mode}',3,'{mode}')",U1)
 sql(f"INSERT INTO public.league_members(league_id,user_id) VALUES ('{lid}','{U2}')")
 day=js(f"SELECT public.palabreo_day('{lid}')",U1)
 day2=js(f"SELECT public.palabreo_day('{lid}')",U2)
 assert day['challenges']==day2['challenges'] and day['word_length']==day2['word_length']
 length=day['word_length'];assert length in [5,6,7]
 if mode!='random':assert length==int(mode)
 assert len(day['challenges'])==3 and {c['word_length'] for c in day['challenges']}=={length}
 challenge=day['challenges'][0]['id']
 packet=js(f"SELECT public.palabreo_open_round('{challenge}')",U1)
 assert packet['word_length']==length and packet['answer'] is None
 round_id=packet['id'];answer=sql(f"SELECT answer FROM palabreo_private.solutions WHERE challenge_id='{challenge}'")
 assert len(answer)==length
 other=sql(f"SELECT word FROM palabreo_private.word_catalog WHERE char_length(word)={length} AND word<>'{answer}' LIMIT 1")
 result=js(f"SELECT public.palabreo_guess('{round_id}','{other}','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')",U1)
 assert result['attempts']==1 and len(result['guesses'][0]['result'])==length
 retry=js(f"SELECT public.palabreo_guess('{round_id}','{other}','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')",U1)
 assert retry['attempts']==1
 err=sql(f"SELECT public.palabreo_guess('{round_id}','AAA','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')",U1,True)
 assert 'No conozco' in err
 won=js(f"SELECT public.palabreo_guess('{round_id}','{answer}','cccccccc-cccc-4ccc-8ccc-cccccccccccc')",U1)
 assert won['status']=='won' and won['points']==8 and won['answer']==answer and won['guesses'][-1]['result']==['correct']*length
 sql(f"SELECT public.palabreo_guess('{round_id}','{answer}',gen_random_uuid())",U2,True)
 sql(f"SELECT public.palabreo_day('{lid}')",U3,True)
 sql(f"UPDATE public.leagues SET length_mode='6' WHERE id='{lid}'" if mode!='6' else f"UPDATE public.leagues SET length_mode='7' WHERE id='{lid}'",fail=True)
 settings=js(f"SELECT public.palabreo_set_league_words('{lid}',4)",U1)
 assert settings['applies_tomorrow']
 assert len(js(f"SELECT public.palabreo_day('{lid}')",U1)['challenges'])==3
 report=js(f"SELECT public.palabreo_report_word('{answer}','{round_id}')",U1);assert report['reports']==1
 # A different member can lose independently without altering the first member's result.
 packet2=js(f"SELECT public.palabreo_open_round('{challenge}')",U2)
 for _ in range(6):lost=js(f"SELECT public.palabreo_guess('{packet2['id']}','{other}',gen_random_uuid())",U2)
 assert lost['status']=='lost' and lost['attempts']==6 and lost['points']==0
 checks.append('league '+mode+': shared day, lengths, win/loss, idempotency, authorization, reports, immutable length, daily-count independence')
 if mode=='random':random_lid=lid
# Legacy day plan and challenges retain five letters.
legacy=js(f"SELECT public.palabreo_day('{old}')",U1);assert legacy['word_length']==5
assert sql(f"SELECT status FROM public.competition_rounds r JOIN public.challenges c ON c.id=r.challenge_id WHERE c.league_id='{old}'")=='won'
checks.append('legacy league and completed result preserved')
assert js('SELECT public.palabreo_day()',U1)['word_length']==5
sql('SELECT * FROM palabreo_private.word_catalog',U1,True)
sql("SELECT public.palabreo_create_league_v120('Bad',3,'8')",U3,True)
checks.append('global remains five; private catalog inaccessible; invalid configuration rejected')
# Shift the clock ONLY in the synthetic DB; leave server-side Madrid logic untouched in migration.
sql("CREATE OR REPLACE FUNCTION palabreo_private.today() RETURNS date LANGUAGE sql STABLE SET search_path TO '' AS $$SELECT coalesce(nullif(current_setting('palabreo_test.date',true),''),(now() at time zone 'Europe/Madrid')::date::text)::date$$")
# Two simultaneous first requests must converge to the same committed plan and words.
future='2026-12-01'
def open_future(user):return js(f"SET palabreo_test.date='{future}';SELECT public.palabreo_day('{random_lid}')",user)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:
 a,b=list(ex.map(open_future,[U1,U2]))
assert a['word_length']==b['word_length'] and a['challenges']==b['challenges']
counts={5:0,6:0,7:0}
for i in range(1,31):
 date=f'2027-01-{i:02}'
 day=js(f"SET palabreo_test.date='{date}';SELECT public.palabreo_day('{random_lid}')",U1)
 counts[day['word_length']]+=1
 assert len(day['challenges'])==4 and {c['word_length'] for c in day['challenges']}=={day['word_length']}
assert all(counts.values()),counts
checks.append('random: one persisted choice per day; concurrent members agree; all three lengths observed across 30 synthetic dates')
# Applying twice must stop before modifying anything.
r=subprocess.run(base+['-c','SET ROLE postgres','-f',str(ROOT/'sql/migrations/palabreo_1_20.sql')],capture_output=True,text=True)
assert r.returncode and 'already present' in r.stderr
checks.append('second application fails safely before changes')
report={'database':'local PostgreSQL 17.11, invented users only','production_supabase_modified':False,'checks':checks,'random_days':counts,'caveats':['Mock auth.uid and unchanged membership/week helpers in fixture; not a full Supabase instance.','No remote schema/data backup was retrieved.','No claim that production migration has been applied.']}
(ROOT/'validation/server-migration-results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
