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
