-- Observed definition supplied by user; reference only, not a migration.
CREATE OR REPLACE FUNCTION public.palabreo_report_word(p_word text, p_round uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_word text;already boolean;total integer;
begin
 perform palabreo_private.require_scope(null);
 v_word:=upper(translate(lower(trim(p_word)),'áàäâéèëêíìïîóòöôúùüû','aaaaeeeeiiiioooouuuu'));
 if v_word is null or v_word !~ '^[A-ZÑ]{5}$' or not exists(select 1 from palabreo_private.word_catalog w where w.word=v_word) then raise exception 'No se encuentra esa palabra';end if;
 if p_round is not null and not exists(select 1 from public.competition_rounds r join palabreo_private.solutions s on s.challenge_id=r.challenge_id where r.id=p_round and r.user_id=auth.uid() and r.status<>'playing' and s.answer=v_word) then raise exception 'Termina tu ronda antes de avisar sobre esta palabra';end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 select exists(select 1 from palabreo_private.word_reports r where r.word=v_word and r.user_id=auth.uid()) into already;
 if not already then
  if (select count(*) from palabreo_private.word_reports where user_id=auth.uid() and created_at>clock_timestamp()-interval '24 hours')>=10 then raise exception 'Puedes avisar de hasta diez palabras diferentes cada 24 horas';end if;
  insert into palabreo_private.word_reports(word,user_id) values(v_word,auth.uid());
 end if;
 select count(*)::integer into total from palabreo_private.word_reports r where r.word=v_word;
 return jsonb_build_object('already_reported',already,'reports',total,'review_needed',total>=3);
end $function$
;
