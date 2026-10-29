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
