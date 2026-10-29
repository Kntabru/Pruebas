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
