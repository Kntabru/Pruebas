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
