-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_day(p_league uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
 perform palabreo_private.require_scope(p_league);perform palabreo_private.assign_day(p_league);perform palabreo_private.expire_rounds();
 select jsonb_build_object('date',palabreo_private.today(),'week',public.palabreo_week(palabreo_private.today()),
 'daily_words',(select count(*) from public.challenges dc where dc.play_date=palabreo_private.today() and dc.league_id is not distinct from p_league),'league_id',p_league,'name',coalesce((select l.name from public.leagues l where l.id=p_league),'Competición global'),
 'challenges',coalesce(jsonb_agg(jsonb_build_object('id',c.id,'slot',c.slot,'status',coalesce(r.status,'new'),'attempts',coalesce(r.attempts,0),'points',coalesce(r.points,0)) order by c.slot),'[]'::jsonb)) into result
 from public.challenges c left join public.competition_rounds r on r.challenge_id=c.id and r.user_id=auth.uid()
 where c.play_date=palabreo_private.today() and c.league_id is not distinct from p_league;
 return result;
end $function$
;
