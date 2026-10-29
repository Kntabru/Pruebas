-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_leagues()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform palabreo_private.require_scope(null);
 return coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'daily_words',l.daily_words,'owner',l.owner_id=auth.uid(),'members',(select count(*) from public.league_members all_members where all_members.league_id=l.id and all_members.left_at is null),'capacity',20) order by l.name) from public.leagues l join public.league_members m on m.league_id=l.id where m.user_id=auth.uid() and m.left_at is null),'[]'::jsonb);
end $function$
;
