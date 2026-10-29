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
