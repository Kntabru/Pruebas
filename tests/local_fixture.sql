-- LOCAL TEST FIXTURE ONLY. Never execute in Supabase.
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

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_points(attempt_count integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE STRICT
 SET search_path TO ''
AS $function$ select case attempt_count when 1 then 10 when 2 then 8 when 3 then 6 when 4 then 4 when 5 then 2 when 6 then 1 else 0 end $function$
;

CREATE TABLE "palabreo_private"."daily_plans" ("scope_key" text NOT NULL,
"play_date" date NOT NULL,
"daily_words" smallint NOT NULL);
CREATE TABLE "palabreo_private"."daily_word_reservations" ("play_date" date NOT NULL,
"answer" text NOT NULL,
"competition_kind" text NOT NULL);
CREATE TABLE "palabreo_private"."direct_invitations" ("id" uuid DEFAULT gen_random_uuid() NOT NULL,
"league_id" uuid NOT NULL,
"recipient_id" uuid NOT NULL,
"created_by" uuid NOT NULL,
"expires_at" timestamp with time zone NOT NULL,
"status" text DEFAULT 'pending'::text NOT NULL);
CREATE TABLE "palabreo_private"."global_ranking_settings" ("singleton" boolean DEFAULT true NOT NULL,
"launch_from" timestamp with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
"history_from" timestamp with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL);
CREATE TABLE "palabreo_private"."guesses" ("round_id" uuid NOT NULL,
"attempt_number" smallint NOT NULL,
"guess" text NOT NULL,
"clues" jsonb NOT NULL,
"created_at" timestamp with time zone DEFAULT now() NOT NULL,
"request_id" uuid);
CREATE TABLE "palabreo_private"."invitations" ("id" uuid DEFAULT gen_random_uuid() NOT NULL,
"league_id" uuid NOT NULL,
"created_by" uuid NOT NULL,
"token_hash" text NOT NULL,
"expires_at" timestamp with time zone NOT NULL,
"revoked_at" timestamp with time zone,
"max_uses" integer DEFAULT 20 NOT NULL,
"uses" integer DEFAULT 0 NOT NULL);
CREATE TABLE "palabreo_private"."solutions" ("challenge_id" uuid NOT NULL,
"answer" text NOT NULL,
"play_date" date NOT NULL,
"competition_kind" text NOT NULL,
"scope_key" uuid NOT NULL);
CREATE TABLE "palabreo_private"."word_catalog" ("word" text NOT NULL,
"is_answer" boolean DEFAULT false NOT NULL);
CREATE TABLE "palabreo_private"."word_reports" ("word" text NOT NULL,
"user_id" uuid NOT NULL,
"created_at" timestamp with time zone DEFAULT clock_timestamp() NOT NULL);
CREATE TABLE "public"."challenges" ("id" uuid DEFAULT gen_random_uuid() NOT NULL,
"league_id" uuid,
"play_date" date NOT NULL,
"slot" smallint NOT NULL,
"created_at" timestamp with time zone DEFAULT now() NOT NULL);
CREATE TABLE "public"."competition_rounds" ("id" uuid DEFAULT gen_random_uuid() NOT NULL,
"challenge_id" uuid NOT NULL,
"user_id" uuid NOT NULL,
"status" text DEFAULT 'playing'::text NOT NULL,
"attempts" smallint DEFAULT 0 NOT NULL,
"started_at" timestamp with time zone DEFAULT now() NOT NULL,
"finished_at" timestamp with time zone,
"duration_ms" bigint,
"points" integer GENERATED ALWAYS AS (
CASE
    WHEN (status = 'won'::text) THEN palabreo_points((attempts)::integer)
    ELSE 0
END) STORED);
CREATE TABLE "public"."league_members" ("league_id" uuid NOT NULL,
"user_id" uuid NOT NULL,
"joined_at" timestamp with time zone DEFAULT now() NOT NULL,
"left_at" timestamp with time zone);
CREATE TABLE "public"."leagues" ("id" uuid DEFAULT gen_random_uuid() NOT NULL,
"name" text NOT NULL,
"owner_id" uuid NOT NULL,
"created_at" timestamp with time zone DEFAULT now() NOT NULL,
"daily_words" smallint DEFAULT 3 NOT NULL);
CREATE TABLE "public"."profiles" ("id" uuid NOT NULL,
"alias" text NOT NULL,
"created_at" timestamp with time zone DEFAULT now() NOT NULL);
ALTER TABLE "palabreo_private"."daily_plans" ADD CONSTRAINT "daily_plans_pkey" PRIMARY KEY (scope_key, play_date);
ALTER TABLE "palabreo_private"."daily_word_reservations" ADD CONSTRAINT "daily_word_reservations_pkey" PRIMARY KEY (play_date, answer);
ALTER TABLE "palabreo_private"."daily_word_reservations" ADD CONSTRAINT "daily_word_reservations_play_date_answer_competition_kind_key" UNIQUE (play_date, answer, competition_kind);
ALTER TABLE "palabreo_private"."direct_invitations" ADD CONSTRAINT "direct_invitations_league_id_recipient_id_key" UNIQUE (league_id, recipient_id);
ALTER TABLE "palabreo_private"."direct_invitations" ADD CONSTRAINT "direct_invitations_pkey" PRIMARY KEY (id);
ALTER TABLE "palabreo_private"."global_ranking_settings" ADD CONSTRAINT "global_ranking_settings_pkey" PRIMARY KEY (singleton);
ALTER TABLE "palabreo_private"."guesses" ADD CONSTRAINT "guesses_pkey" PRIMARY KEY (round_id, attempt_number);
ALTER TABLE "palabreo_private"."invitations" ADD CONSTRAINT "invitations_pkey" PRIMARY KEY (id);
ALTER TABLE "palabreo_private"."invitations" ADD CONSTRAINT "invitations_token_hash_key" UNIQUE (token_hash);
ALTER TABLE "palabreo_private"."solutions" ADD CONSTRAINT "solutions_pkey" PRIMARY KEY (challenge_id);
ALTER TABLE "palabreo_private"."solutions" ADD CONSTRAINT "solutions_play_date_scope_key_answer_key" UNIQUE (play_date, scope_key, answer);
ALTER TABLE "palabreo_private"."word_catalog" ADD CONSTRAINT "word_catalog_pkey" PRIMARY KEY (word);
ALTER TABLE "palabreo_private"."word_reports" ADD CONSTRAINT "word_reports_pkey" PRIMARY KEY (word, user_id);
ALTER TABLE "public"."challenges" ADD CONSTRAINT "challenges_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."competition_rounds" ADD CONSTRAINT "competition_rounds_challenge_id_user_id_key" UNIQUE (challenge_id, user_id);
ALTER TABLE "public"."competition_rounds" ADD CONSTRAINT "competition_rounds_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."league_members" ADD CONSTRAINT "league_members_pkey" PRIMARY KEY (league_id, user_id);
ALTER TABLE "public"."leagues" ADD CONSTRAINT "leagues_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."profiles" ADD CONSTRAINT "profiles_pkey" PRIMARY KEY (id);
ALTER TABLE "palabreo_private"."daily_plans" ADD CONSTRAINT "daily_plans_daily_words_check" CHECK (daily_words >= 3 AND daily_words <= 9);
ALTER TABLE "palabreo_private"."daily_word_reservations" ADD CONSTRAINT "daily_word_reservations_answer_check" CHECK (answer ~ '^[A-ZÑ]{5}$'::text);
ALTER TABLE "palabreo_private"."daily_word_reservations" ADD CONSTRAINT "daily_word_reservations_competition_kind_check" CHECK (competition_kind = ANY (ARRAY['global'::text, 'private'::text]));
ALTER TABLE "palabreo_private"."direct_invitations" ADD CONSTRAINT "direct_invitations_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text]));
ALTER TABLE "palabreo_private"."global_ranking_settings" ADD CONSTRAINT "global_ranking_settings_singleton_check" CHECK (singleton);
ALTER TABLE "palabreo_private"."guesses" ADD CONSTRAINT "guesses_attempt_number_check" CHECK (attempt_number >= 1 AND attempt_number <= 6);
ALTER TABLE "palabreo_private"."guesses" ADD CONSTRAINT "guesses_clues_check" CHECK (jsonb_typeof(clues) = 'array'::text AND jsonb_array_length(clues) = 5);
ALTER TABLE "palabreo_private"."guesses" ADD CONSTRAINT "guesses_guess_check" CHECK (guess ~ '^[A-ZÑ]{5}$'::text);
ALTER TABLE "palabreo_private"."invitations" ADD CONSTRAINT "invitations_check" CHECK (uses >= 0 AND uses <= max_uses);
ALTER TABLE "palabreo_private"."invitations" ADD CONSTRAINT "invitations_max_uses_check" CHECK (max_uses > 0);
ALTER TABLE "palabreo_private"."invitations" ADD CONSTRAINT "invitations_token_hash_check" CHECK (token_hash ~ '^[0-9a-f]{64}$'::text);
ALTER TABLE "palabreo_private"."solutions" ADD CONSTRAINT "solutions_answer_check" CHECK (answer ~ '^[A-ZÑ]{5}$'::text);
ALTER TABLE "palabreo_private"."word_catalog" ADD CONSTRAINT "word_catalog_word_check" CHECK (word ~ '^[A-ZÑ]{5}$'::text);
ALTER TABLE "public"."challenges" ADD CONSTRAINT "challenges_slot_check" CHECK (slot >= 1 AND slot <= 9);
ALTER TABLE "public"."competition_rounds" ADD CONSTRAINT "competition_rounds_attempts_check" CHECK (attempts >= 0 AND attempts <= 6);
ALTER TABLE "public"."competition_rounds" ADD CONSTRAINT "competition_rounds_check" CHECK (status = 'playing'::text AND finished_at IS NULL AND duration_ms IS NULL AND attempts < 6 OR status = 'won'::text AND attempts >= 1 AND attempts <= 6 AND finished_at IS NOT NULL AND duration_ms IS NOT NULL OR status = 'lost'::text AND attempts = 6 AND finished_at IS NOT NULL AND duration_ms IS NOT NULL OR status = 'abandoned'::text AND finished_at IS NOT NULL);
ALTER TABLE "public"."competition_rounds" ADD CONSTRAINT "competition_rounds_check1" CHECK (finished_at IS NULL OR finished_at >= started_at);
ALTER TABLE "public"."competition_rounds" ADD CONSTRAINT "competition_rounds_duration_ms_check" CHECK (duration_ms >= 0);
ALTER TABLE "public"."competition_rounds" ADD CONSTRAINT "competition_rounds_status_check" CHECK (status = ANY (ARRAY['playing'::text, 'won'::text, 'lost'::text, 'abandoned'::text]));
ALTER TABLE "public"."league_members" ADD CONSTRAINT "league_members_check" CHECK (left_at IS NULL OR left_at >= joined_at);
ALTER TABLE "public"."leagues" ADD CONSTRAINT "leagues_daily_words_check" CHECK (daily_words >= 3 AND daily_words <= 9);
ALTER TABLE "public"."leagues" ADD CONSTRAINT "leagues_name_check" CHECK (length(name) >= 3 AND length(name) <= 60);
ALTER TABLE "public"."profiles" ADD CONSTRAINT "profiles_alias_check" CHECK (length(alias) >= 3 AND length(alias) <= 48);
ALTER TABLE "palabreo_private"."direct_invitations" ADD CONSTRAINT "direct_invitations_created_by_fkey" FOREIGN KEY (created_by) REFERENCES profiles(id);
ALTER TABLE "palabreo_private"."direct_invitations" ADD CONSTRAINT "direct_invitations_league_id_fkey" FOREIGN KEY (league_id) REFERENCES leagues(id) ON DELETE CASCADE;
ALTER TABLE "palabreo_private"."direct_invitations" ADD CONSTRAINT "direct_invitations_recipient_id_fkey" FOREIGN KEY (recipient_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE "palabreo_private"."guesses" ADD CONSTRAINT "guesses_round_id_fkey" FOREIGN KEY (round_id) REFERENCES competition_rounds(id) ON DELETE CASCADE;
ALTER TABLE "palabreo_private"."invitations" ADD CONSTRAINT "invitations_created_by_fkey" FOREIGN KEY (created_by) REFERENCES profiles(id);
ALTER TABLE "palabreo_private"."invitations" ADD CONSTRAINT "invitations_league_id_fkey" FOREIGN KEY (league_id) REFERENCES leagues(id) ON DELETE CASCADE;
ALTER TABLE "palabreo_private"."solutions" ADD CONSTRAINT "solutions_challenge_id_fkey" FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE CASCADE;
ALTER TABLE "palabreo_private"."solutions" ADD CONSTRAINT "solutions_play_date_answer_competition_kind_fkey" FOREIGN KEY (play_date, answer, competition_kind) REFERENCES palabreo_private.daily_word_reservations(play_date, answer, competition_kind);
ALTER TABLE "palabreo_private"."word_reports" ADD CONSTRAINT "word_reports_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE "palabreo_private"."word_reports" ADD CONSTRAINT "word_reports_word_fkey" FOREIGN KEY (word) REFERENCES palabreo_private.word_catalog(word);
ALTER TABLE "public"."challenges" ADD CONSTRAINT "challenges_league_id_fkey" FOREIGN KEY (league_id) REFERENCES leagues(id) ON DELETE CASCADE;
ALTER TABLE "public"."competition_rounds" ADD CONSTRAINT "competition_rounds_challenge_id_fkey" FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE CASCADE;
ALTER TABLE "public"."competition_rounds" ADD CONSTRAINT "competition_rounds_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE "public"."league_members" ADD CONSTRAINT "league_members_league_id_fkey" FOREIGN KEY (league_id) REFERENCES leagues(id) ON DELETE CASCADE;
ALTER TABLE "public"."league_members" ADD CONSTRAINT "league_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE "public"."leagues" ADD CONSTRAINT "leagues_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES profiles(id);
ALTER TABLE "public"."profiles" ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE UNIQUE INDEX guesses_request_id ON palabreo_private.guesses USING btree (round_id, request_id) WHERE (request_id IS NOT NULL);
CREATE UNIQUE INDEX challenges_global_day ON public.challenges USING btree (play_date, slot) WHERE (league_id IS NULL);
CREATE UNIQUE INDEX challenges_league_day ON public.challenges USING btree (league_id, play_date, slot) WHERE (league_id IS NOT NULL);
CREATE INDEX challenges_date ON public.challenges USING btree (play_date);
CREATE INDEX competition_rounds_user ON public.competition_rounds USING btree (user_id);
CREATE UNIQUE INDEX profiles_alias_unique ON public.profiles USING btree (lower(alias));
CREATE FUNCTION public.palabreo_is_member(wanted_league uuid) RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path TO '' AS $$
 SELECT EXISTS(SELECT 1 FROM public.league_members WHERE league_id=wanted_league AND user_id=auth.uid() AND left_at IS NULL)$$;
CREATE FUNCTION public.palabreo_week(day date) RETURNS date LANGUAGE sql IMMUTABLE AS $$SELECT date_trunc('week',day::timestamp)::date$$;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION palabreo_private.assign_day(p_league uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d date:=palabreo_private.today();v_slot integer;chosen text;cid uuid;kind text;day_count integer;
begin
 -- Serializa la asignación diaria para evitar coincidencias entre ámbitos.
 perform pg_advisory_xact_lock(hashtext('palabreo-day:'||d::text));
 if p_league is not null then perform palabreo_private.assign_day(null);end if;
 kind:=case when p_league is null then 'global' else 'private' end;
 if p_league is null then day_count:=5;
 else
  select daily_words into day_count from public.leagues where id=p_league;
  if not found then raise exception 'La liga no existe';end if;
  insert into palabreo_private.daily_plans(scope_key,play_date,daily_words) values(p_league::text,d,day_count) on conflict do nothing;
  select daily_words into day_count from palabreo_private.daily_plans where scope_key=p_league::text and play_date=d;
 end if;
 for v_slot in 1..day_count loop
  if not exists(select 1 from public.challenges c join palabreo_private.solutions s on s.challenge_id=c.id where c.play_date=d and c.slot=v_slot and c.league_id is not distinct from p_league) then
   select w.word into chosen from palabreo_private.word_catalog w
   where w.is_answer
    and not exists(select 1 from palabreo_private.daily_word_reservations x where x.play_date=d and x.answer=w.word and x.competition_kind<>kind)
    and not exists(select 1 from public.challenges c join palabreo_private.solutions s on s.challenge_id=c.id where c.play_date between d-7 and d and c.league_id is not distinct from p_league and s.answer=w.word)
   order by random() limit 1;
   if chosen is null then raise exception 'No hay suficientes palabras disponibles';end if;
   insert into public.challenges(league_id,play_date,slot) values(p_league,d,v_slot)
    on conflict do nothing;
   select c.id into cid from public.challenges c where c.league_id is not distinct from p_league and c.play_date=d and c.slot=v_slot;
   insert into palabreo_private.solutions(challenge_id,answer) values(cid,chosen);
  end if;
 end loop;
end $function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION palabreo_private.expire_rounds()
 RETURNS void
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 update public.competition_rounds r set status='abandoned',finished_at=((c.play_date+1)::timestamp at time zone 'Europe/Madrid'),duration_ms=null
 from public.challenges c where c.id=r.challenge_id and c.play_date<palabreo_private.today() and r.status='playing';
$function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION palabreo_private.freeze_challenge()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if new.play_date<>old.play_date
  or new.league_id is distinct from old.league_id
  or new.slot<>old.slot then
  raise exception 'No se puede cambiar la fecha ni el ámbito de un desafío';
 end if;
 return new;
end $function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION palabreo_private.require_scope(p_league uuid)
 RETURNS void
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
begin
 if auth.uid() is null then raise exception 'Inicia sesión para competir' using errcode='42501';end if;
 if p_league is not null and not public.palabreo_is_member(p_league) then raise exception 'No perteneces a esta liga' using errcode='42501';end if;
end $function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION palabreo_private.reserve_daily_word()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
 challenge public.challenges%rowtype;
begin
 if tg_op='UPDATE' then
  raise exception 'Las soluciones asignadas son inmutables';
 end if;

 select * into strict challenge
 from public.challenges
 where id=new.challenge_id;

 new.play_date:=challenge.play_date;
 new.competition_kind:=
  case when challenge.league_id is null then 'global' else 'private' end;
 new.scope_key:=
  coalesce(challenge.league_id,'00000000-0000-0000-0000-000000000000'::uuid);

 insert into palabreo_private.daily_word_reservations(
  play_date,answer,competition_kind
 )
 values(new.play_date,new.answer,new.competition_kind)
 on conflict(play_date,answer) do nothing;

 return new;
end $function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION palabreo_private.round_view(p_round uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select jsonb_build_object('id',r.id,'challenge_id',r.challenge_id,'status',r.status,'attempts',r.attempts,'points',r.points,
 'started_at',r.started_at,'finished_at',r.finished_at,'duration_ms',r.duration_ms,'server_time',clock_timestamp(),
 'date',c.play_date,'slot',c.slot,'league_id',c.league_id,'daily_words',(select count(*) from public.challenges day_c where day_c.play_date=c.play_date and day_c.league_id is not distinct from c.league_id),
 'guesses',coalesce((select jsonb_agg(jsonb_build_object('word',g.guess,'result',g.clues) order by g.attempt_number) from palabreo_private.guesses g where g.round_id=r.id),'[]'::jsonb),
 'answer',case when r.status<>'playing' then s.answer else null end)
 from public.competition_rounds r join public.challenges c on c.id=r.challenge_id join palabreo_private.solutions s on s.challenge_id=c.id where r.id=p_round
$function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION palabreo_private.today()
 RETURNS date
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$select (now() at time zone 'Europe/Madrid')::date$function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_create_league(p_name text, p_daily_words integer DEFAULT 3)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare lid uuid;
begin
 perform palabreo_private.require_scope(null);
 perform 1 from public.profiles where id=auth.uid() for update;
 if length(trim(p_name)) not between 3 and 60 then raise exception 'El nombre necesita entre 3 y 60 caracteres';end if;
 if (select count(*) from public.league_members where user_id=auth.uid() and left_at is null)>=5 then raise exception 'Puedes participar en un máximo de cinco ligas privadas, contando las creadas y las que te unes';end if;
 if p_daily_words is null or p_daily_words not between 3 and 9 then raise exception 'Elige entre tres y nueve palabras diarias';end if;
 insert into public.leagues(name,owner_id,daily_words) values(trim(p_name),auth.uid(),p_daily_words) returning id into lid;
 insert into public.league_members(league_id,user_id) values(lid,auth.uid());return lid;
end $function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_day(p_league uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
 perform palabreo_private.require_scope(p_league);perform palabreo_private.assign_day(p_league);perform palabreo_private.expire_rounds();
 select jsonb_build_object('date',palabreo_private.today(),'week',public.palabreo_week(palabreo_private.today()),
 'daily_words',(select count(*) from public.challenges dc where dc.play_date=palabreo_private.today() and dc.league_id is not distinct from p_league),'league_id',p_league,'name',coalesce((select l.name from public.leagues l where l.id=p_league),'Competición global'),
 'challenges',coalesce(jsonb_agg(jsonb_build_object('id',c.id,'slot',c.slot,'status',coalesce(r.status,'new'),'attempts',coalesce(r.attempts,0),'points',coalesce(r.points,0)) order by c.slot),'[]'::jsonb)) into result
 from public.challenges c left join public.competition_rounds r on r.challenge_id=c.id and r.user_id=auth.uid()
 where c.play_date=palabreo_private.today() and c.league_id is not distinct from p_league;
 return result;
end $function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_guess(p_round uuid, p_guess text, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.competition_rounds%rowtype;c public.challenges%rowtype;solution text;guess_word text;remaining text[];clues text[]:=array['absent','absent','absent','absent','absent'];i integer;j integer;ended timestamptz:=clock_timestamp();new_status text;
begin
 select * into strict r from public.competition_rounds where id=p_round for update;
 if r.user_id is distinct from auth.uid() then raise exception 'Esta ronda no te pertenece' using errcode='42501';end if;
 select * into strict c from public.challenges where id=r.challenge_id;perform palabreo_private.require_scope(c.league_id);
 if p_request_id is null then raise exception 'Falta el identificador del intento';end if;
 if exists(select 1 from palabreo_private.guesses g where g.round_id=r.id and g.request_id=p_request_id) then return palabreo_private.round_view(r.id);end if;
 if r.status<>'playing' then return palabreo_private.round_view(r.id);end if;
 if c.play_date<>palabreo_private.today() then
  update public.competition_rounds set status='abandoned',finished_at=((c.play_date+1)::timestamp at time zone 'Europe/Madrid') where id=r.id;
  return palabreo_private.round_view(r.id);
 end if;
 guess_word:=upper(translate(lower(trim(p_guess)),'áàäâéèëêíìïîóòöôúùüû','aaaaeeeeiiiioooouuuu'));
 if guess_word is null or guess_word !~ '^[A-ZÑ]{5}$' or not exists(select 1 from palabreo_private.word_catalog w where w.word=guess_word) then raise exception 'No conozco esa palabra. Prueba con otra.' using errcode='22023';end if;
 select s.answer into strict solution from palabreo_private.solutions s where s.challenge_id=c.id;
 remaining:=string_to_array(solution,null);
 for i in 1..5 loop if substr(guess_word,i,1)=substr(solution,i,1) then clues[i]:='correct';remaining[i]:=null;end if;end loop;
 for i in 1..5 loop
  if clues[i]<>'correct' then j:=array_position(remaining,substr(guess_word,i,1));if j is not null then clues[i]:='present';remaining[j]:=null;end if;end if;
 end loop;
 new_status:=case when guess_word=solution then 'won' when r.attempts=5 then 'lost' else 'playing' end;
 insert into palabreo_private.guesses(round_id,attempt_number,guess,clues,request_id) values(r.id,r.attempts+1,guess_word,to_jsonb(clues),p_request_id);
 update public.competition_rounds set attempts=r.attempts+1,status=new_status,
 finished_at=case when new_status<>'playing' then ended else null end,
 duration_ms=case when new_status<>'playing' then greatest(0,floor(extract(epoch from (ended-r.started_at))*1000))::bigint else null end where id=r.id;
 return palabreo_private.round_view(r.id);
end $function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_leagues()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform palabreo_private.require_scope(null);
 return coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'daily_words',l.daily_words,'owner',l.owner_id=auth.uid(),'members',(select count(*) from public.league_members all_members where all_members.league_id=l.id and all_members.left_at is null),'capacity',20) order by l.name) from public.leagues l join public.league_members m on m.league_id=l.id where m.user_id=auth.uid() and m.left_at is null),'[]'::jsonb);
end $function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_open_round(p_challenge uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c public.challenges%rowtype;rid uuid;
begin
 select * into strict c from public.challenges where id=p_challenge;
 perform palabreo_private.require_scope(c.league_id);perform palabreo_private.expire_rounds();
 if c.play_date<>palabreo_private.today() then raise exception 'Este desafío ya no está disponible';end if;
 if not exists(select 1 from palabreo_private.solutions s where s.challenge_id=c.id) then raise exception 'Este desafío aún no está listo';end if;
 insert into public.competition_rounds(challenge_id,user_id) values(c.id,auth.uid()) on conflict(challenge_id,user_id) do nothing;
 select r.id into rid from public.competition_rounds r where r.challenge_id=c.id and r.user_id=auth.uid();
 return palabreo_private.round_view(rid);
end $function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_points(attempt_count integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE STRICT
 SET search_path TO ''
AS $function$ select case attempt_count when 1 then 10 when 2 then 8 when 3 then 6 when 4 then 4 when 5 then 2 when 6 then 1 else 0 end $function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_report_word(p_word text, p_round uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_word text;already boolean;total integer;
begin
 perform palabreo_private.require_scope(null);
 v_word:=upper(translate(lower(trim(p_word)),'áàäâéèëêíìïîóòöôúùüû','aaaaeeeeiiiioooouuuu'));
 if v_word is null or v_word !~ '^[A-ZÑ]{5}$' or not exists(select 1 from palabreo_private.word_catalog w where w.word=v_word) then raise exception 'No se encuentra esa palabra';end if;
 if p_round is not null and not exists(select 1 from public.competition_rounds r join palabreo_private.solutions s on s.challenge_id=r.challenge_id where r.id=p_round and r.user_id=auth.uid() and r.status<>'playing' and s.answer=v_word) then raise exception 'Termina tu ronda antes de avisar sobre esta palabra';end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 select exists(select 1 from palabreo_private.word_reports r where r.word=v_word and r.user_id=auth.uid()) into already;
 if not already then
  if (select count(*) from palabreo_private.word_reports where user_id=auth.uid() and created_at>clock_timestamp()-interval '24 hours')>=10 then raise exception 'Puedes avisar de hasta diez palabras diferentes cada 24 horas';end if;
  insert into palabreo_private.word_reports(word,user_id) values(v_word,auth.uid());
 end if;
 select count(*)::integer into total from palabreo_private.word_reports r where r.word=v_word;
 return jsonb_build_object('already_reported',already,'reports',total,'review_needed',total>=3);
end $function$
;

-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_set_league_words(p_league uuid, p_daily_words integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare owner uuid;tomorrow boolean;
begin
 perform palabreo_private.require_scope(p_league);
 if p_league is null then raise exception 'Selecciona una liga';end if;
 if p_daily_words is null or p_daily_words not between 3 and 9 then raise exception 'Elige entre tres y nueve palabras diarias';end if;
 -- Mismo bloqueo que la asignación: un cambio nunca divide la jornada entre usuarios.
 perform pg_advisory_xact_lock(hashtext('palabreo-day:'||palabreo_private.today()::text));
 select owner_id into owner from public.leagues where id=p_league for update;
 if owner is distinct from auth.uid() then raise exception 'Solo el creador puede cambiar las palabras diarias' using errcode='42501';end if;
 update public.leagues set daily_words=p_daily_words where id=p_league;
 select exists(select 1 from palabreo_private.daily_plans where scope_key=p_league::text and play_date=palabreo_private.today()) into tomorrow;
 return jsonb_build_object('daily_words',p_daily_words,'applies_tomorrow',tomorrow);
end $function$
;

ALTER TABLE "palabreo_private"."daily_plans" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "palabreo_private"."daily_plans" TO service_role;
ALTER TABLE "palabreo_private"."daily_word_reservations" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "palabreo_private"."daily_word_reservations" TO service_role;
ALTER TABLE "palabreo_private"."direct_invitations" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "palabreo_private"."direct_invitations" TO service_role;
ALTER TABLE "palabreo_private"."global_ranking_settings" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "palabreo_private"."global_ranking_settings" TO service_role;
ALTER TABLE "palabreo_private"."guesses" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "palabreo_private"."guesses" TO service_role;
ALTER TABLE "palabreo_private"."invitations" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "palabreo_private"."invitations" TO service_role;
REVOKE ALL ON SCHEMA "palabreo_private" FROM PUBLIC;
GRANT USAGE ON SCHEMA "palabreo_private" TO service_role;
ALTER TABLE "palabreo_private"."solutions" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "palabreo_private"."solutions" TO service_role;
CREATE TRIGGER reserve_daily_word BEFORE INSERT OR UPDATE ON palabreo_private.solutions FOR EACH ROW EXECUTE FUNCTION palabreo_private.reserve_daily_word();
ALTER TABLE "palabreo_private"."word_catalog" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "palabreo_private"."word_catalog" TO service_role;
ALTER TABLE "palabreo_private"."word_reports" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "palabreo_private"."word_reports" TO service_role;
ALTER TABLE "public"."challenges" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "public"."challenges" TO service_role;
GRANT SELECT ON "public"."challenges" TO authenticated;
CREATE POLICY "challenges_read" ON "public"."challenges" FOR SELECT TO "authenticated" USING (((league_id IS NULL) OR palabreo_is_member(league_id)));
CREATE TRIGGER freeze_challenge BEFORE UPDATE ON challenges FOR EACH ROW EXECUTE FUNCTION palabreo_private.freeze_challenge();
ALTER TABLE "public"."competition_rounds" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "public"."competition_rounds" TO service_role;
GRANT SELECT ON "public"."competition_rounds" TO authenticated;
CREATE POLICY "rounds_read" ON "public"."competition_rounds" FOR SELECT TO "authenticated" USING ((user_id = auth.uid()));
ALTER TABLE "public"."league_members" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "public"."league_members" TO service_role;
GRANT SELECT ON "public"."league_members" TO authenticated;
CREATE POLICY "members_read" ON "public"."league_members" FOR SELECT TO "authenticated" USING (palabreo_is_member(league_id));
ALTER TABLE "public"."leagues" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "public"."leagues" TO service_role;
GRANT SELECT ON "public"."leagues" TO authenticated;
CREATE POLICY "leagues_read" ON "public"."leagues" FOR SELECT TO "authenticated" USING (palabreo_is_member(id));
ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;
GRANT ALL ON "public"."profiles" TO service_role;
GRANT SELECT ON "public"."profiles" TO authenticated;
CREATE POLICY "profiles_read" ON "public"."profiles" FOR SELECT TO "authenticated" USING (true);
REVOKE ALL ON SCHEMA "public" FROM PUBLIC;
GRANT USAGE ON SCHEMA "public" TO service_role;
GRANT USAGE ON SCHEMA "public" TO anon,authenticated;
DO $acl$ DECLARE f record; BEGIN
FOR f IN SELECT p.oid::regprocedure AS signature,n.nspname,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('public','palabreo_private') LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.signature);
 IF f.nspname='public' THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.signature);END IF;
END LOOP;END $acl$;
-- Invented fixtures only. No real users or online words are imported.
INSERT INTO auth.users(id) VALUES ('11111111-1111-4111-8111-111111111111'),('22222222-2222-4222-8222-222222222222'),('33333333-3333-4333-8333-333333333333');
INSERT INTO public.profiles(id,alias) VALUES ('11111111-1111-4111-8111-111111111111','Local One'),('22222222-2222-4222-8222-222222222222','Local Two'),('33333333-3333-4333-8333-333333333333','Local Outsider');
SET request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';

INSERT INTO palabreo_private.word_catalog(word,is_answer) SELECT w,true FROM unnest(string_to_array('ABRIL ACERO AMIGO ARENA ARBOL ARROZ AVION BAILE BARCO BRISA CAMPO CANTO CARTA CIELO CLAVE COBRE CORAL COSTA CREMA CUEVA DULCE ENERO FAROL FELIZ FUEGO GLOBO GRANO HIELO HOGAR HUEVO JUEGO LAPIZ LIBRO LLAVE LUNAR MADRE MAGIA MANGO MANTA MARZO METAL MUNDO NARIZ NIEVE NOCHE NORTE OTOÑO OVEJA PAPEL PERRO PIANO PLATA PLAYA PLAZA PLUMA POEMA PRADO QUESO RADIO RATON RELOJ ROBLE RUMBO SELVA SILLA SUEÑO TABLA TARDE TECHO TIGRE TORRE TRIGO VERDE VIAJE VOCAL ZORRO ABEJA ABETO ABONO ABRIR ACTOR AGUDO AGUJA ALAMO ALBUM ALDEA ALETA ALGUN ALIÑO ALTAR AMBOS ANCHO ANDAR ANGEL ANIMO ANTES APOYO ARAÑA ARDER ASADO ASTRO ATOMO ATRAS AUDAZ AUTOR AVENA AVISO AYUDA AZOTE BALON BANCO BANDA BARBA BARRA BASTA BICHO BOLSA BOMBA BORDE BOTON BRAVO BRAZO BRUJA BUENO BURLA BUSCA CABAL CABER CABLE CABRA CACAO CAIDA CAJON CALDO CALMA CALOR CALVO CANAL CAÑON CAPAZ CARNE CARRO CASCO CAUSA CEBRA CEDRO CELDA CENAR CERCA CERDO CHICO CHINA CICLO CIEGA CINTA CIRCO CISNE CLARO CLASE CLIMA COFRE COLMO COLON COMER COMUN CONDE COPIA CORTE COSER CRUCE CUERO CULPA CURSO CURVA DANZA DEBER DECIR DEJAR DENSO DIETA DISCO DOBLE DOLOR DORAR DOSIS DRAMA DUELO DUEÑO DUQUE ECHAR ERROR ETAPA EXITO EXTRA FALDA FALLO FALSO FALTO FAUNA FECHA FERIA FIBRA FIRMA FLACO FLOJA FLORA FONDO FORMA FRASE FRESA FRITO FRUTA GALLO GANAR GARRA GASTO GATOS GENIO GENTE GESTO GOLFO GOLPE GORDO GORRA GOTEO GRADO GRASA GRAVE GRUPO GUAPO GUISO GUSTO HABER HABLA HACER HASTA HECHO HILAR HONDO HONOR HOTEL HUMOR IDEAL IGUAL ISLAS JAMAS JAULA JOVEN JUEZA JULIO JUNIO JUSTO LABIO LARGO LENTO LENTE LIBRE LIDER LIMON LINDO LINEA LISTA LITRO LLAMA LLANO LLEVA LLORO LOCAL LOGRO LUCHA LUCES LUEGO LUGAR LUNES MACHO MALVA MANCO MANDO MANIA MARCA MAREA MARCO MASAS MAYOR MEDIA MEDIO MEJOR MELON MENOR MENOS MENTE MERMA MIEDO MIRAR MISMO MOLDE MONJA MONTE MORAL MORIR MORRO MOSCA MOTOR MOVIL MUCHO MUELA MUJER MUSLO NAIPE NATAL NECIO NEGRO NIETO NOBLE NORIA NORMA NUEVE NUEVO NUNCA OASIS OBESO OBRAR OESTE OJALA OLIVA OLLAS OPERA ORDEN OREJA ORUGA OVALO OZONO PACTO PADRE PAGOS PALMA PALMO PANAL PANDO PANEL PARED PARTE PASEO PASTA PATIO PAUSA PECES PEDAL PEDIR PEGAR PEINE PELAR PELEA PELOS PENAL PESAR PESTE PICAR PIEZA PILAR PINZA PISTA PITON PLANO PLATO PLOMO PODER POLEN POLLO POLVO PONER POSTE PRIMO PRISA PROSA PULGA PULPO PULSO PUNTO QUEDO QUEJA QUEMA QUIEN QUIZA RABIA RASGO RASPA RAYAR RAZON REGLA REINA REINO RENTA RESTO REZAR RIEGO RIFLE RIGOR RISAS RITMO RIVAL ROBAR ROCAS RODEO ROGAR ROJOS ROMPE RONDA RUBIO RUIDO RURAL SABER SABIO SACAR SALIR SALON SALSA SALTO SALUD SANTO SECAR SEDAL SEÑAL SERIO SIETE SIGLO SIGNO SOBRE SOCIO SOLAR SOPLO SORDO SUAVE SUBIR SUCIA SUCIO SUELO SUERO SUMAR SURCO SUSTO TACON TACTO TALLA TALLO TANGO TANTO TAPAR TAREA TARRO TARTA TASAR TAZON TEMOR TENAZ TENER TENIS TERMO TERNO TESIS TEXTO TIBIO TILDE TINTE TIPOS TIRAR TOCAR TOMAR TONTO TOPAR TORPE TORSO TOSER TOTAL TRAER TRAMA TRAMO TRATO TRECE TRIBU TRIPA TRONO TROZO TUMBA TURNO UNICO UNION USADO USUAL VACIO VALLE VALOR VAPOR VARON VASCO VASTO VECES VEJEZ VELOZ VENAS VENTA VERBO VERSO VIEJO VIGOR VILLA VIRUS VISOR VISTA VITAL VIVIR VUELO YERBA YOGUR ZANJA ZARPA ZURDO ESTAS ESTOY AHORA VAMOS TENGO DONDE TIENE PUEDO TODOS SABES PUEDE USTED FAVOR SEÑOR ESTAN COSAS ESTAR NADIE ELLOS FUERA DESDE TENIA HABIA BUENA GUSTA TODAS CREES VISTO HEMOS ENTRE DICHO ESTOS CHICA HACIA HACES SABIA PENSE SERIA ADIOS SOMOS NUEVA PASAR NIÑOS VENIR HORAS DEBES MANOS VIENE VENGA CINCO OTROS MISMA SIGUE COCHE DICES PUEDA PODIA ACABO FINAL LISTO MESES ABAJO FACIL LLAMO HIJOS CREER UNICA TRATA HACEN DICEN SABEN HAGAS LEJOS QUEDA MATAR LLEVO TENGA VERTE SITIO MURIO VERAS DIGAS MUCHA FALTA OTRAS CALLE ACABA HARIA HABRA LLEGO SUENA JUGAR VEMOS DEMAS ARMAS AMIGA SALVO HABLO NOVIA DEBEN DARLE VERLO POBRE PAGAR MITAD VISTE ELLAS NOVIO ESTES TRAJE DECIA SALIO ENTRA FOTOS LLAME HABLE DIRIA BROMA DESEO VAYAS JUNTO HAZLO SEGUN MIREN CARGO VIEJA VIDAS HARAS CREIA BEBER LLEGA LINDA SOLIA CREEN JODER PERRA QUISE QUEDE PARIS LLENO IRNOS MODOS PIDIO VERME PARAR AQUEL DUELE MILES DARME CORRE NIVEL SERAN DEJES DARTE COLOR HAYAS GANAS VERLA VAYAN DEBIA SERAS PERDI LLEVE VIDEO ACASO HAGAN DANDO ENVIO LARGA LLENA SALGA PODRA ESTEN HEROE TRAGO SANTA DAMAS DEJAS ENTRO LECHE AYUDE SENTI MUERE VOLAR TANTA YENDO MALAS COGER IDEAS LOCOS VENGO BAJAR SIRVE EPOCA OIGAN SERIE SOLOS CORTO DESEA DATOS CASAS POCOS TOQUE TRAJO DEBIO CARGA DISTE PODRE DEDOS SEPAS CASOS SUPER PONTE HARAN RAYOS TOMAS PONGA AYUDO NEGRA TRATE TONTA DEBIL HUELE FUESE BELLA QUISO MALOS HAYAN PECHO CREAR NIÑAS BUSCO GUAPA BEBES PONES PENSO CONTO LADOS PONGO DEJEN LEIDO TRUCO VIMOS GUSTE CORTA INDIA MUEVE VERLE CAIDO CLARA FIRME AMBAS BORDO NOTAS DARIA DROGA SOLAS VENIA LEGAL POCAS BOLSO VOLVI VIVEN DEJAN RUEGO PASAN OBVIO AMABA AUTOS OISTE VIVES VIVOS VIVIA METER FUMAR PIZZA SABRA MIRES LEYES PASOS SAQUE BALAS ACABE SERES MOVER ENVIE CASAR MIRAS MIRAD JULIA HECHA HAZME JUEGA RICOS SIGAN SERLO PONEN ZORRA CRUEL ENVIA DUCHA CUIDA DUDAS VOTOS DILES NACIO CIEGO FALSA CREAS MUERA JUNTA SALEN MUERO CARAS COSTO CAJAS TOMEN TETAS SALGO DIRAS BOLAS DAMOS CHINO ROBIN VEGAS SALES DIGAN DEUDA QUITA NADAR CIVIL PAGUE METIO PAGAN CANTA HARTO MUSEO ESPIA AMADO METRO KILOS JAPON BRUCE RUSIA HIJAS MANDA RUSOS ADORO FLOTA JUDIO ABRAN VERAN BOTAS METAS PLACA CALLA SABOR CITAS VACIA PUNTA OIDOS MUEVA GUION PAPAS JOYAS LETRA CESAR GRITO SALVE PASAS PINTA PASEN HUESO CONTE SONAR ALMAS TUNEL PRIMA DAÑOS GAFAS VENDE TRAES QUITO RUEDA TEMAS GORDA GRANT RATAS ATACO CARAY ABRIO FATAL PUTAS RUBIA SEPAN BREVE OBRAS NAVES MATEN REVES DOLAR BODAS ROBOT AGUAS TOMES MATAN REYES SALTA NUBES DARSE DIERA PORNO TUYOS VOCES APAGA OIRME DIANA SUELE HOJAS ODIAS LANZA FALLA OIRLO DARAN GRITA VOTAR CREYO VIUDA VENID DIMOS TOMAN SALIA VIERA ROSAS BAILA BELLO INDIO PAREN CAZAR ROLLO PLAZO VELAS SUYOS ACTUA ALTOS RANGO PONLO COMES DIEGO BAJAS MANDE QUITE MASON BESAR LAVAR UNIDO MARTE PATAS ACTOS PRESA MOTEL LLORA VUELA PESCA ELIGE HARTA FINES GREEN COMIO MENTI COMEN HORNO PARES COLIN VODKA BARON CELOS NIEGA COGIO COPAS DUROS JEFES RUMOR AEREA BESOS RARAS COREA VERIA LANCE PIDES SELLO LOGRE DIGNO MAFIA PARTO CULPO PASES SIGAS USABA POLLA CAUSO ALTAS ROPAS AMADA TEMIA ABUSO PILLO LOBOS JODAN PLENA SUBIO ATAUD MATAS RAROS MIRAN PAVOS CRECE DANOS RADAR CARLA DIRAN TENES LOCAS VIVIO PAULA HADAS TEMER PAGAS DIOSA ARTES OIRTE SABRE DINOS OCUPO ALLEN SUFRE DARAS JUSTA VACAS ROJAS METES TIMES MINAS IDOLO CAIGA BRUNO SALVA EUROS TALES PONIA DESEE SOBRA PRESO DURAR LICOR CURAR ACIDO CUIDE MONOS CRECI TUMOR BAJEN BAHIA GANAN ODIAN POETA NAZIS SACAS ROMPI TRAEN TUYAS FIRMO CREAN AEREO CERRO TOCAS NACER MATES GIRAR ASUMO BINGO VERSE ORINA ATADO PISOS SOÑAR JODAS BAÑOS BARRO MULTA JABON DEMOS QUEMO CUBRE DORMI DEJAD SUIZA REHEN SUBAN HUECO ANDAS HACHA BURRO LASER HAZTE BAJOS TIROS SUITE LANZO NIEGO FLASH FURIA PIDEN ROMEO POLIS ATACA GRIPE ENANO VASOS JAMON ELEGI PUTOS CRIAR TORTA NEGAR LENTA COBRA OPINA POSEE DEBAS SEXTO ECHAS AIRES HUELO VENDO CLAVO CAMAS LIRAS MARTA VALEN HERIR ADORA USARE VIVAS OCUPA FLUJO SUYAS OIMOS ACOSO ASILO DUEÑA MESAS CAERA LUCHO ZONAS DURAS ROBOS RECTO BASES VIOLO JUDIA ARABE EBRIO SIRVO TARDA MILAN PARAD RIÑON AREAS NIETA TINTA VIAJA ATRAE BUZON HURRA LATIN DELTA TIRAS RODAR BOXEO LUCIA DENME JORGE VENDI TEMES HABRE PALOS ENOJO SUENE SUDOR VALGA CUIDO RUINA ANDAN PLAGA ALIAS FARSA SENOS ATICO DADOS ROMAN DOLER ONDAS APURO PEGUE ANUAL LLORE VENDA PENAS CULTO NOTAR MANGA AHOGO CAVAR BARES MUROS ROTOS APODO CORRI RINDO SIRVA FILAS BRUTO VALIA RECTA DECIS REDES VERGA ACTUO ARMAR CARLO USADA BOTES PLENO ELITE LAZOS PONLE MILLA LOGRA MONJE CAGAR MATON HUIDO CRACK TOCAN GRITE KARMA ETICA HALLE FRENO SALTE BOTIN PINTO DUDAR ODIAR DETEN BANDO APOYA SESOS COMAS TORNO CRUZA USARA CRUZO MONTA FALLE FILME LETAL VALLA DOLIO OCUPE LATAS DENLE CAIGO ACUSA GOTAS VAGON COGES PIDAS ABRAS VIAJO PACES DANTE RODEA PODES MISIL SENTO DICHA RAMON BATES AROMA CANTE RAMAS REUNE VENUS TUTOR TRAIA BOLOS ELIJO GASES HAZLE NINJA SUTIL BLUES GRAND HALLO CULOS MUDAR COMAN LIBRA TENSO ABRES DABAN PONLA VEROS NOMAS SOPLA ABREN IRIAS CANSE METEN AVISE SACAN EVITA UNIDA TEMEN MOVIO ZOMBI REJAS BLUSA MENTA PESOS EXIGE COBRO APAGO CROSS MATEO DALES MAPAS CORRA TACOS PLANA ROBAN SALID NAVAL LECHO VALIO TUBOS UNETE LABOR ALEJA SEMEN FEROZ HACED YERNO COÑAC PELEO RACHA CHULO VALER CAPAS ACTUE BUQUE PARAS GENES PANDA FINGE SONDA CESTA ECHEN TURCO EXIJO MORIA CAROS CHILE HABIL CEDER FICHA BAILO BONOS PUÑOS PATOS TIMON ACERA ACUSO ATAJO NIÑEZ DAÑAR TIREN CALME TARDO PUROS MONTO COMIA BORDA ECHAN VEIAN ROMPA FINCA SATAN ELIJA AVISA LUISA DIGNA ROTAS QUEME CHOCO BEBIO PEDIA FRIAS SUEÑA LUCIR MARES FRUTO SENTE PLACE GRABO SURGE SALAS VINOS MEDIR LEERE GASTE DOBLA PATAN PROBE FUMAS GORRO NUDOS ECHES CELIA BANCA CRIOS TROPA CUYOS DURAN DADAS CUOTA CENAS CORRO QUEJO BEBIA JUGUE DENSE BARCA SUBES UTERO CEJAS CRUDO VEIAS LUCHE AUDIO TAXIS CAUSE CASES CIFRA ATADA MORSE HIMNO JARRA HILOS PERLA RUTAS SOCIA PIZCA ALEJE MUEVO FRIOS ABRID YENES TAZAS AMARE TIRES MICRO CAFES TENSA FERRY BEBEN MUTUO CURRY FORMO GANSO COGED JUDAS VALES PILLE AMARA PASTO PILAS SANOS OPINO SUECO JURAR CARPA ROMPO VIVAN SECOS TENED GALES RICAS SEXTA METAN TRAPO MOTOS CHUPA MAMAS HALLA COLGO PESAS OIRLA PANZA ANOTA JUANA LLENE TINTO VIOLA HONRA LEELO LIGHT LEELA HUIDA OMEGA TOROS DAROS TERCO DONAR SEAIS CHOCA SHOWS TIRAN HORCA SUBEN SORDA CURSI CERRE BAJES GASTA FLUYE MAGOS MOVIA GRIFO RUEGA JAQUE CABOS ERAIS RAYAS LUCEN PENES HIRIO BROTE CASAN ALEJO CURAS NUERA ALIEN SECTA NACEN DELIA VENIS SUDAR VOILA VAGOS LIGAS PAÑAL LIGAR GILES MOTIN OBVIA RANAS SACOS BRUJO BONES HINDU ESQUI COGEN PISAR YATES BOCAS BALSA FIJAR CANSO PAULO SEÑAS CRIAS JALEO CHOZA VICIO FLOJO DADME BEBAS ANDEN PARAN BACON TRAED TOMAD BLEDO NOBEL PEDOS CHIVO SOLTO PEGAS GAMMA BAJAN PORRO TELON TRAGA APOYE NAZCA EBRIA PORTA CALLO ALGAS GUIAR CUYAS POLAR RAMPA APOLO MOMIA SANAR AGUDA RINDE CUBRO PELEE ATROZ SORBO BALDE ANGUS ORGIA ROCIO HUNDE PROBO SUFRO DUDES MORAN HOBBY SUDES SAUNA REUNA PASAD DANES DENOS PUDIN SPRAY LAGOS CAGUE CUBOS ASUMI BABOR FRENA TALON COMIC SUFRA FUSIL COJAN ISLAM METIA TIBIA SECAS OIGAS BESAS COSTE LUNAS ROBAS ROGUE MARGO BORRA JODIO ANCLA BULTO POZOS YEGUA MAREO PIDAN GANGA ACRES COJAS SIRIA RAZAS COLAS DOLIA MAURA PATEO DUELA IRIAN SUIZO CHIPS SUBAS ETICO ENOJA SUPON SERTE VENTE ANTRO FALTE CRUDA CAZAS GRABE TITAN HUECA ELEVA VUELE AÑADE FORZO FUNDA ANOTO RETOS ULTRA ANOTE ASUME HONGO EVITO PURAS OLIVE FLOTE GRABA SUDAN PORTE TIRON GALAN HARTE VALGO LIADO HOYOS PETRA MALES UNIRA BUCEO BORRO GIRAS POSEO ANIMA SABLE CANSA GANES FENIX GRIAL ENOJE OPONE MANTO TESLA CLUBS KAPPA PEGAN BEBAN PATEA BUFON HEDOR BAMBU HAZLA VENCE ARDEN PILLA DARLO VELLO MUGRE DONAS HUYES EMITE MUTUA AMBAR BELEN HONDA BAJAD ANDES PARIO CAPTO LUZCO RAMOS SUBID RUGBY USALO CODOS PORTO SETAS FIJAS MULAS ROSEN JURAS BOLLO RIETE DONES BATIR SERLE DANCE GUIDO TAPAS CUBRA FIERA AHOGA FREIR RUSAS CONGO LATIR GUIAS REUNI SWING MALTA PICOS DELLA REIDO FUERE CANOA BERTA JALEA JEREZ FUGAZ SODIO DEBUT LAMER CERDA OVNIS TORAX TEJAS RAPTO GUETO TELAS VIRAL JERGA ODIES SIMIO RINGO JUZGO WATTS TONOS CITAR OXIDO SILVA MITOS EVITE MUDAS PEZON HUYEN SUBIA PRIME ANSIA PALCO NENAS VAGAR CALMO SERVI DADLE FUNDO PINTE LOBBY NEGUE MECHA SEXYS ABRIA BELGA ANCHA PARTA DROGO DARLA EPICO FORCE GANEN GNOMO VOTEN DECID GARZA PAJAR FINAS FLACA CASTA FILMO ARPIA CULPE CURRO VIUDO FINOS JUZGA GUIÑO EPICA MODAS SUFRI TIRAD CISCO FANGO REMOS HECES TRINA ICONO TERCA POSAR MIGAS SUENO PALAS DARDO REMAR SENDA VIBRA LUCIO TURBO LADRA PIQUE NASAL ERASE FRITA MOJAR DABAS JEQUE RENOS DOBLO ASADA VAINA ANIME COCOS SIDRA ELFOS HELIO ENANA GIRAN LEONA PEROS PROFE CESTO DIQUE PESAN COPIO MOCOS VATER STAND CORAN HUYAS AGITA BUCLE GIROS HIERE WEBER BAYAS BUSTO LIDIA IBAIS PUDRA SEDAN SUECA POTRO AJENO CAREY LEILA DEBAN PUÑAL ROUGE ROLES CHEFS GRAMO FILMS RENAL OIRLE VIOLE CEROS PATEE PONED PISAS FAROS BANJO CALVA CUPON TAPON AMAME BORRE PORRA ATLAS BECAS TASAS ARMAN NAVIO OYEME COJIN PASEA BURLO AORTA PRIOR SITUA FRIKI LIMBO TANGA ALPES JODES SENIL BESAN FORME VOLVO MOROS SIOUX VIESE ARCOS HUELA COLES AGOTA ESTAD ROBEN CETRO MAMON BOBOS BUDIN PEAJE BRUTA CINES HURTO ASPEN IRANI FLUIR IREIS BATEO GOZAR PINOS REIAN DENSA FINGI RITOS MAYAS SUMAS DIESE BASTO RIZOS FOCAS TEJER LEJIA SAMBA OIRAN RETRO RINDA ACUDE FUGAS RELAX SALDO LAVAS AJENA FEMUR VASTA IMITA TEMAN PERSA LUJOS ARDOR PESCO ACUSE VERJA SILBA OIRAS CHUPO COGIA HUMOS LUCRO UNIRE OSTRA SACAD FOSIL FINJO VOTAN LIBIA CLORO CAZAN OSADO VISON NERON TALLE SEQUE BACHE TENLO OCASO RUDOS CAERE SUELA CAIAN DICTA CALIZ ORINO FORRO NIDOS ARNES GOLES SUMAN MALLA OLIDO ADORE CERCO VIGAS MEADO PERAS RONCA JUNTE SOLES VIVIS CABEN PULIR PULSA RESTA CHAPA CHECA RALLY TRETA ALIJO MORAS BAÑAR LEERA PICAN MURAL ANSIO FASES ALOJA TRACE RATOS CAGAS FOCOS PULSE OPERO FOLLA FOSAS COPOS FUMAN MITIN BEIGE PICAS ACUDA ROQUE AYUNO CASEN LEALO GRATA LATEX ADAMA ANEXO HINDI COÑOS JUGOS BESES PODIO FILMA PARIR TALCO PECAS BASAN TURBA GIREN OYERA PELIS FAENA ARADO DALIA YACIA MUSGO PANES CREED CEDIO REGAR TURCA INGLE TIESO TRABA CANAS DUNAS LAPSO MIRON BUZOS REZOS TEJON ANULA FOBIA ALZAR DOCIL MARGA AGOTO BUCAL MENUS POLOS NOTAN RECAE PURGA BOTAR CHUPE PINES REGIS MARLO SANAS AVARO BOTOX CLAVA JALAR ORINE ALEGA APEGO HUYAN CORSE ILESO MINGO JODEN USALA ELEVO QUEJE HORDA EXODO LAVAN COROS BAZAR FUMES GOLFA HURON RALLO JADEO FETAL VARIA ARDUO GALON VELAR ASOMO ROBES CATRE ECHAD LUZCA VIGIA FLUYA FOLLE FOLLO PARDO ARPON OPUSO SOPLE BUHOS OSTIA VIRIL BRICE ELIJE QUEPA CUBRI IDEAR CREME POROS HUNDA SALIS TECLA PECAR COPIE CREDO ERIZO ALFIL CUNDA GEMAS OBTEN TAPIZ EDEMA ONZAS TENUE LUPUS ACOSA MAMBO TIARA CAPTA COITO RIMAS GARBO REZAS BONUS FIJOS LEVES TIFUS BURLE FROTA TENOR BRAVA SAUCE VALET CLERO YACEN MORSA OVULO TEMPO TIFON NEVAR SAPOS TORNA HAREN MIMOS GRAVA TRUST BOCON LOGIA APURE NANCE FINJA HIGOS APENA CUTRE SOLTE RUEDO TOSCA BANAL CAÑAS COMED VENCI GUITA VESTI GRUÑE VACIE VEAIS GOTEA AGRIA SIENA ASUMA BATAS RASCA PAPAL BOXER VEALO NADAN UBICA LILAS SEXOS ATORO DOTES REMEN TOTEM CHECO CURAN ALOJO GRUTA LORES FUNDE NACHO RUMBA BOMBO POLIO LATON BARRE BATEA BRAGA NOTEN TUMBO LITIO RENDI LIGUE BAJON OPERE LEPRA TROTE VOLCO COMBO BOINA SIGNE UNASE ASOMA MEADA ACTAS DRAGO LARVA MUDAN FIJAN PARTI REZAN ARETE CONOS VILES HIENA BEBED CROMO ACUDI ORALE CHULA IONES PIÑAS REUNO SIRIO FUROR URNAS PUJAR SAVIA NIEVA GRILL LIRIO YARDA RISCO SPORT CENSO LEEME VEASE SURJA MIDEN PARIA REIRA MOZOS ABUSA DIVAN SELLA ACIDA DANDI BATON BRUMA GATAS DICTE MAGMA ALCES GASAS TRAZO ODIEN POSEA PENDE CHELO FIERO MAMAR PAVOR MIXTA ROCKS SACHA OMISO TAROT ESNOB ARDID ATALO CHITA GRATO DELES PUNKS RONCO ARDIO GOMAS NITRO FREDO NABOS PIPAS ROSCA ALANA DOMAR MIDES DUDEN FUSCO SHORT FONDA MORDI INCAS ROSCO AXILA SATEN AGITO CLIPS ESTER PUDRE TACHO CAGAN APELO TRUFA PASMA PEQUE PITOS BILIS JURAN LABIA LOTES TORCI BONGO RUBIN SAUDI AMAIS BLOGS HADAR GAJES CAGON IMPAR MUECA OLIVO MOLER MUDES PISES FIDEO FORJA PONIS DUETO ERRAR TANDA CUELA PUDOR ZARPO SOGAS CAPTE SOPAS CALZA MAMUT RECEN MAESE BEMOL LICEO ARIOS VIRAR BESEN GEMIR AÑORO CULTA ARCAS FRENE CHATO PAJAS JADEA LONGO BICIS MONDO SIGMA HIPPY PISAN POSES APURA DAGAS OCHOS CORSO MARCI LINCE SOBRO AGRIO BIZCO DICTO ENEMA FALCO HAMPA JALEN LAZAR OIRIA AÑADA DORSO NAFTA TAMIL NADAS LIADA CINTO RESES TREPA ARDIA MIOPE VIRGO APICE CRIAN JARRO PEDIS ZUMBA ANULO BUSES EDUCO LATIA TOSCO VARAS ARGEL BROTA OPTAR TOPOS AGOTE MELLA SARTA ARAÑO PARCA AULAS ANULE TRAZA LOROS TRABO ATEOS MUDOS PAÑOS POSTA VORAZ CATEO MEROS VIVAZ POMPA RIMEL MIDAS SALMO CACHO CUTIS CAOBA CAQUI ESPIE ARIES CHATA CRETA PAUTA YEMAS AGATA HORNE MENEA RUGIR SUEÑE UNIOS ZAFAR APAÑO COLAR ATARE GUIAN EMANA MENEO ARLEN HUNOS MAGNA DUDAN HABAS RETAR ABUSE CORPS CUREN FIJEN GALOS INSTO ORCOS DUCHO LAVES MATAD VICHY AVIAR HACHE SOFAS VISAS GAMBA NALGA OJIVA APTOS MAURO VISIR AÑADI CASPA CONGA NINFA BARDO ASOME EMITA PALME REIRE BIDON FROTE CESEN ELEVE LLAGA RAJAR RIÑAS PULPA CATES CLAMA FROTO PUZLE TEJOS BOLIN BURRA RUBOR AÑADO MAGNO MIXTO CANON HONRO HUNDO COCER ALBIN AMARO CURIE PATER HUMAN REDIL ZEBRA AJUAR LAVEN MOVED UBICO GRECO VIÑAS HERVE JURES MIRZA RUNAS ZURDA CREPE PODAR NICHO OJETE SUBTE CARPE PICOR PERNO RETEN TOLDO CELTA PENSA QUERO NACES NUBLA LARES PUMAS ROSES AGITE ACOGE RACHE SERME BONZO OIDAS TREPO VELOS AVIVA CLICS OLERA TAURO VAGAS YACER ESPIO FECAL HUIRE TRIOS VENZA ZURRA DOGMA GRUAS PLEBE SEXIS CAÑOS HALES RAJAN CABIA BAGRE NARCO NOGAL NENES BAÑAS BREEN GIRES ILUSO MINAR ALADO ARMEN FACTO PELAS SABED TOCAD MATIZ DAÑAN HIPER RENTO VAGAN BOSTA IMPIO REOJO BETUN LEMUR MANSO SAGAZ ALEGO ILESA PIOJO SALMA SECAN BRASA MACON PRIVA TUMBE CHIEN PUBIS AMATO AZOTO FUTON NARRA ROSAL GALAS ZUMOS ARCON ARDUA FOROS MAREE TENME CILLA OGROS DUREN FETOS HANZO REINE AZOTA RECES MIRLO MONGO GUIEN SELLE TILDA AISLA FUSTA HIERA BOZAL FARDO VERAZ BASAR BASTE CHAVO VOTAS BAYON CRUJE HALEN JOLIN LAMIA LANDO AÑEJO DUCTO GANSA MOJON SODAS BAÑAN INTER RECIO BASAS FEUDO OPINE TIESA TIMAR BOXES FLAMA ASNOS DOREN GAITA PEDID TAPIA PEINA AVIDO OSADA ASTER COJEA MODEM HUIRA REGIO UNTAR ALISA PASEE REIAS ARBOR PATIN ATAÑE CAVAN MERCA TONEL ALABO DUCHE JOTAS LAMAS LEIAS MUÑON PICHA TABLE DATAN NECIA ORCAS PREVE COSIO LEGOS MOLAN ABATE CAVEN CHOLO EVOCA FILON FORJO OIROS CAIAS CUAJO MISAS VULVA CHUTE ROTAR TANJA MEMOS NADIR OLMOS REUMA TACHA ALFAS CACHE EBANO RASCO LIMAS SACRO LAUDA MESON ROCHA CRASO FOGON ROTOR SEDAS VIREN CAYOS SUDAS USAIS AMINA BIRRA CIMAS HEBRA ALCEN ARGOS ARGOT BABEL DUMAS GALGO NUTRE OBESA SANSA SARNA ARIDO CHAPO RULOS CAUTO HUIAN MOLON NOTES OPUSE PARRA RELES TUNDA OLIAN TELAR ACUDO ARIAS CAUCE PACHA REZAD TAIGA TENDI ARGON BURDO JUNCO RAYON ODIOS POLEA QUIER ALABA FRIES LOMAS MAJOS MONAS MORRA BOSON CHALE LEGUA SAJON ATRIO CUCHI LAMIO TRENA ATALA FACHA GAUSS LUMEN BATIO IRISA PISEN HIDRA IMITO OIRSE YELMO CUECE LEVAR RIGEN APNEA AULLA FUTIL RIMAR TULIO BABAS FUMEN MIRRA CUNAS ASEOS DEDAL FLUIA FORUM MOLAR EQUIS INFLA LEALA TOPES ASTAS CHIST GACHA FLOTO LOMOS MOJAS QUERA ROCES TEDIO ACEBO DORAN LOGAR PETAR TOGAS ATARA CUATE HUCHA MAMAN',' ')) w;
SELECT public.palabreo_create_league('Legacy five',3);
SELECT public.palabreo_day((SELECT id FROM public.leagues WHERE name='Legacy five'));

SELECT public.palabreo_guess((public.palabreo_open_round((SELECT id FROM public.challenges WHERE league_id IS NOT NULL ORDER BY slot LIMIT 1))->>'id')::uuid,(SELECT answer FROM palabreo_private.solutions WHERE challenge_id=(SELECT id FROM public.challenges WHERE league_id IS NOT NULL ORDER BY slot LIMIT 1)),gen_random_uuid());
