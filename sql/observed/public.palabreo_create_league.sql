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
