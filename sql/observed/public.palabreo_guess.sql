-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_guess(p_round uuid, p_guess text, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.competition_rounds%rowtype;c public.challenges%rowtype;solution text;guess_word text;remaining text[];clues text[]:=array['absent','absent','absent','absent','absent'];i integer;j integer;ended timestamptz:=clock_timestamp();new_status text;
begin
 select * into strict r from public.competition_rounds where id=p_round for update;
 if r.user_id is distinct from auth.uid() then raise exception 'Esta ronda no te pertenece' using errcode='42501';end if;
 select * into strict c from public.challenges where id=r.challenge_id;perform palabreo_private.require_scope(c.league_id);
 if p_request_id is null then raise exception 'Falta el identificador del intento';end if;
 if exists(select 1 from palabreo_private.guesses g where g.round_id=r.id and g.request_id=p_request_id) then return palabreo_private.round_view(r.id);end if;
 if r.status<>'playing' then return palabreo_private.round_view(r.id);end if;
 if c.play_date<>palabreo_private.today() then
  update public.competition_rounds set status='abandoned',finished_at=((c.play_date+1)::timestamp at time zone 'Europe/Madrid') where id=r.id;
  return palabreo_private.round_view(r.id);
 end if;
 guess_word:=upper(translate(lower(trim(p_guess)),'áàäâéèëêíìïîóòöôúùüû','aaaaeeeeiiiioooouuuu'));
 if guess_word is null or guess_word !~ '^[A-ZÑ]{5}$' or not exists(select 1 from palabreo_private.word_catalog w where w.word=guess_word) then raise exception 'No conozco esa palabra. Prueba con otra.' using errcode='22023';end if;
 select s.answer into strict solution from palabreo_private.solutions s where s.challenge_id=c.id;
 remaining:=string_to_array(solution,null);
 for i in 1..5 loop if substr(guess_word,i,1)=substr(solution,i,1) then clues[i]:='correct';remaining[i]:=null;end if;end loop;
 for i in 1..5 loop
  if clues[i]<>'correct' then j:=array_position(remaining,substr(guess_word,i,1));if j is not null then clues[i]:='present';remaining[j]:=null;end if;end if;
 end loop;
 new_status:=case when guess_word=solution then 'won' when r.attempts=5 then 'lost' else 'playing' end;
 insert into palabreo_private.guesses(round_id,attempt_number,guess,clues,request_id) values(r.id,r.attempts+1,guess_word,to_jsonb(clues),p_request_id);
 update public.competition_rounds set attempts=r.attempts+1,status=new_status,
 finished_at=case when new_status<>'playing' then ended else null end,
 duration_ms=case when new_status<>'playing' then greatest(0,floor(extract(epoch from (ended-r.started_at))*1000))::bigint else null end where id=r.id;
 return palabreo_private.round_view(r.id);
end $function$
;
