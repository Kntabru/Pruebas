"""Build a migration from observed server functions; never connects to a database."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
out=root/'sql/migrations';out.mkdir(parents=True,exist_ok=True)
def observed(name):return (root/'sql/observed'/f'{name}.sql').read_text().split('\n',1)[1]
def change(s,a,b):
 if a not in s:raise ValueError('Observed function differs: '+a[:80])
 return s.replace(a,b)
parts=["""-- Palabreo 1.20: migration for the observed existing database, NOT a fresh schema.
-- DO NOT RUN until the complete script and backups have been reviewed.
-- Preserves users, profiles, leagues, challenges and historical results.
-- Changes only word lengths and adds the 6/7-letter catalog. No rows are deleted.
-- Requires a privileged SQL Editor session. All changes are atomic.
BEGIN;
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '120s';
SELECT pg_advisory_xact_lock(hashtext('palabreo-migration-1.20'));
DO $guard$
BEGIN
 IF to_regclass('palabreo_private.word_catalog') IS NULL
 OR to_regprocedure('public.palabreo_guess(uuid,text,uuid)') IS NULL
 THEN RAISE EXCEPTION 'Missing expected Palabreo schema. Nothing applied.'; END IF;
 IF EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='public.leagues'::regclass AND attname='length_mode' AND NOT attisdropped)
 THEN RAISE EXCEPTION 'Length migration already present or schema differs. Do not run again.'; END IF;
END $guard$;
ALTER TABLE public.leagues ADD COLUMN length_mode text NOT NULL DEFAULT '5'
 CHECK (length_mode IN ('5','6','7','random'));
ALTER TABLE palabreo_private.daily_plans ADD COLUMN word_length smallint NOT NULL DEFAULT 5
 CHECK (word_length IN (5,6,7));
ALTER TABLE public.challenges ADD COLUMN word_length smallint NOT NULL DEFAULT 5
 CHECK (word_length IN (5,6,7));
ALTER TABLE public.challenges ADD CONSTRAINT challenges_global_five_letters
 CHECK (league_id IS NOT NULL OR word_length=5);
-- Defaults retain every existing league, day and challenge at five letters.
ALTER TABLE palabreo_private.word_catalog DROP CONSTRAINT word_catalog_word_check;
ALTER TABLE palabreo_private.word_catalog ADD CONSTRAINT word_catalog_word_check CHECK (word ~ '^[A-ZÑ]{5,7}$');
ALTER TABLE palabreo_private.solutions DROP CONSTRAINT solutions_answer_check;
ALTER TABLE palabreo_private.solutions ADD CONSTRAINT solutions_answer_check CHECK (answer ~ '^[A-ZÑ]{5,7}$');
ALTER TABLE palabreo_private.daily_word_reservations DROP CONSTRAINT daily_word_reservations_answer_check;
ALTER TABLE palabreo_private.daily_word_reservations ADD CONSTRAINT daily_word_reservations_answer_check CHECK (answer ~ '^[A-ZÑ]{5,7}$');
ALTER TABLE palabreo_private.guesses DROP CONSTRAINT guesses_guess_check;
ALTER TABLE palabreo_private.guesses ADD CONSTRAINT guesses_guess_check CHECK (guess ~ '^[A-ZÑ]{5,7}$');
ALTER TABLE palabreo_private.guesses DROP CONSTRAINT guesses_clues_check;
ALTER TABLE palabreo_private.guesses ADD CONSTRAINT guesses_clues_check
 CHECK (jsonb_typeof(clues)='array' AND jsonb_array_length(clues)=char_length(guess));
CREATE INDEX word_catalog_length_answers_idx ON palabreo_private.word_catalog ((char_length(word)),is_answer);
CREATE FUNCTION palabreo_private.freeze_league_length() RETURNS trigger
LANGUAGE plpgsql SET search_path TO '' AS $body$
BEGIN
 IF NEW.length_mode IS DISTINCT FROM OLD.length_mode THEN
  RAISE EXCEPTION 'La longitud de una liga no se puede cambiar después de crearla' USING ERRCODE='22023';
 END IF;
 RETURN NEW;
END $body$;
REVOKE ALL ON FUNCTION palabreo_private.freeze_league_length() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER freeze_league_length BEFORE UPDATE ON public.leagues
 FOR EACH ROW EXECUTE FUNCTION palabreo_private.freeze_league_length();
"""]
create=observed('public.palabreo_create_league')
create=change(create,'public.palabreo_create_league(p_name text, p_daily_words integer DEFAULT 3)','public.palabreo_create_league_v120(p_name text, p_daily_words integer, p_length_mode text)')
create=change(create,'declare lid uuid;','declare lid uuid;')
create=change(create,' insert into public.leagues(name,owner_id,daily_words) values(trim(p_name),auth.uid(),p_daily_words)'," if p_length_mode IS NULL OR p_length_mode NOT IN ('5','6','7','random') then raise exception 'Elige longitud 5, 6, 7 o aleatoria' using errcode='22023';end if;\n insert into public.leagues(name,owner_id,daily_words,length_mode) values(trim(p_name),auth.uid(),p_daily_words,p_length_mode)")
parts += [create,"REVOKE ALL ON FUNCTION public.palabreo_create_league_v120(text,integer,text) FROM PUBLIC,anon;\nGRANT EXECUTE ON FUNCTION public.palabreo_create_league_v120(text,integer,text) TO authenticated;\n"]
assign=observed('palabreo_private.assign_day')
assign=change(assign,'kind text;day_count integer;','kind text;day_count integer;length_mode text;chosen_length smallint;')
assign=change(assign,'if p_league is null then day_count:=5;','if p_league is null then day_count:=5;chosen_length:=5;')
assign=change(assign,'select daily_words into day_count from public.leagues where id=p_league;','select l.daily_words,l.length_mode into day_count,length_mode from public.leagues l where id=p_league;')
assign=change(assign,'insert into palabreo_private.daily_plans(scope_key,play_date,daily_words) values(p_league::text,d,day_count) on conflict do nothing;',"chosen_length:=case when length_mode='random' then (5+floor(random()*3))::smallint else length_mode::smallint end;\n  insert into palabreo_private.daily_plans(scope_key,play_date,daily_words,word_length) values(p_league::text,d,day_count,chosen_length) on conflict do nothing;")
assign=change(assign,'select daily_words into day_count from palabreo_private.daily_plans where scope_key=p_league::text and play_date=d;','select dp.daily_words,dp.word_length into day_count,chosen_length from palabreo_private.daily_plans dp where scope_key=p_league::text and play_date=d;')
assign=change(assign,'where w.is_answer','where w.is_answer and char_length(w.word)=chosen_length')
assign=change(assign,'insert into public.challenges(league_id,play_date,slot) values(p_league,d,v_slot)','insert into public.challenges(league_id,play_date,slot,word_length) values(p_league,d,v_slot,chosen_length)')
parts.append(assign)
freeze=observed('palabreo_private.freeze_challenge');freeze=change(freeze,'or new.slot<>old.slot then','or new.slot<>old.slot\n  or new.word_length<>old.word_length then');parts.append(freeze)
reserve=observed('palabreo_private.reserve_daily_word');reserve=change(reserve,' new.play_date:=challenge.play_date;'," if char_length(new.answer)<>challenge.word_length then raise exception 'La solución no coincide con la longitud del desafío';end if;\n new.play_date:=challenge.play_date;");parts.append(reserve)
view=observed('palabreo_private.round_view');view=change(view,"'date',c.play_date,'slot'","'word_length',c.word_length,'date',c.play_date,'slot'");parts.append(view)
day=observed('public.palabreo_day');day=change(day,"'challenges',coalesce", "'word_length',coalesce(max(c.word_length),5),'challenges',coalesce");day=change(day,"'id',c.id,'slot',c.slot","'id',c.id,'word_length',c.word_length,'slot',c.slot");parts.append(day)
guess=observed('public.palabreo_guess');guess=change(guess,"clues text[]:=array['absent','absent','absent','absent','absent']","clues text[]")
guess=change(guess,"guess_word !~ '^[A-ZÑ]{5}$'", "guess_word !~ '^[A-ZÑ]{5,7}$' or char_length(guess_word)<>c.word_length")
guess=change(guess,' remaining:=string_to_array(solution,null);'," clues:=array_fill('absent'::text,ARRAY[c.word_length::integer]);\n remaining:=string_to_array(solution,null);")
guess=change(guess,'for i in 1..5 loop','for i in 1..c.word_length loop');parts.append(guess)
leagues=observed('public.palabreo_leagues');leagues=change(leagues,"'daily_words',l.daily_words,", "'length_mode',l.length_mode,'daily_words',l.daily_words,");parts.append(leagues)
report=observed('public.palabreo_report_word');report=change(report,"v_word !~ '^[A-ZÑ]{5}$'","v_word !~ '^[A-ZÑ]{5,7}$'");parts.append(report)
parts.append("""-- Enforce row length consistency even for direct privileged inserts.
CREATE FUNCTION palabreo_private.check_guess_length() RETURNS trigger
LANGUAGE plpgsql SET search_path TO '' AS $body$
DECLARE expected integer;
BEGIN
 SELECT c.word_length INTO STRICT expected FROM public.competition_rounds r
 JOIN public.challenges c ON c.id=r.challenge_id WHERE r.id=NEW.round_id;
 IF char_length(NEW.guess)<>expected THEN RAISE EXCEPTION 'Longitud de intento incorrecta' USING ERRCODE='22023';END IF;
 RETURN NEW;
END $body$;
REVOKE ALL ON FUNCTION palabreo_private.check_guess_length() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER check_guess_length BEFORE INSERT OR UPDATE ON palabreo_private.guesses
 FOR EACH ROW EXECUTE FUNCTION palabreo_private.check_guess_length();
-- Existing RLS, ownership and grants are preserved. No private catalog access is granted.
""")
data=json.loads((root/'data/words-6-7.json').read_text())
for n in ['6','7']:
 d=data[n]['normal'];words=' '.join(d['accepted']);answers=' '.join(d['answers'])
 parts.append(f"""-- {n}-letter catalog: FrequencyWords CC BY-SA 4.0 + Hunspell MPL; see DICTIONARY.md.
INSERT INTO palabreo_private.word_catalog(word,is_answer)
SELECT w,w=ANY(string_to_array('{answers}',' '))
FROM unnest(string_to_array('{words}',' ')) AS w
ON CONFLICT(word) DO NOTHING;
""")
parts.append("NOTIFY pgrst, 'reload schema';\nCOMMIT;\n")
(out/'palabreo_1_20.sql').write_text('\n'.join(parts))
print('Generated complete migration (not executed):',out/'palabreo_1_20.sql')
