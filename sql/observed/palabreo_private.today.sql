-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION palabreo_private.today()
 RETURNS date
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$select (now() at time zone 'Europe/Madrid')::date$function$
;
