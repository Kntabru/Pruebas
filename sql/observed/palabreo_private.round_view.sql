-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION palabreo_private.round_view(p_round uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select jsonb_build_object('id',r.id,'challenge_id',r.challenge_id,'status',r.status,'attempts',r.attempts,'points',r.points,
 'started_at',r.started_at,'finished_at',r.finished_at,'duration_ms',r.duration_ms,'server_time',clock_timestamp(),
 'date',c.play_date,'slot',c.slot,'league_id',c.league_id,'daily_words',(select count(*) from public.challenges day_c where day_c.play_date=c.play_date and day_c.league_id is not distinct from c.league_id),
 'guesses',coalesce((select jsonb_agg(jsonb_build_object('word',g.guess,'result',g.clues) order by g.attempt_number) from palabreo_private.guesses g where g.round_id=r.id),'[]'::jsonb),
 'answer',case when r.status<>'playing' then s.answer else null end)
 from public.competition_rounds r join public.challenges c on c.id=r.challenge_id join palabreo_private.solutions s on s.challenge_id=c.id where r.id=p_round
$function$
;
