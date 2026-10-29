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
