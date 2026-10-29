-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_points(attempt_count integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE STRICT
 SET search_path TO ''
AS $function$ select case attempt_count when 1 then 10 when 2 then 8 when 3 then 6 when 4 then 4 when 5 then 2 when 6 then 1 else 0 end $function$
;
