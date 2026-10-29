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
