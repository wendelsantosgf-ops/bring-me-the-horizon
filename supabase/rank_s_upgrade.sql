-- BMTH / Rank S (400 XP). Execute UMA VEZ no Supabase SQL Editor.
-- Mantém todos os personagens e XP existentes. Nenhum UPDATE em dados existentes.
-- Suporta coluna rank em enum PostgreSQL ou texto com CHECK simples.
DO $rank_s$
DECLARE col_type text; enum_schema text; enum_name text; item record;
BEGIN
 SELECT t.typtype::text,n.nspname,t.typname INTO col_type,enum_schema,enum_name
 FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
 JOIN pg_namespace cn ON cn.oid=c.relnamespace
 JOIN pg_type t ON t.oid=a.atttypid
 JOIN pg_namespace n ON n.oid=t.typnamespace
 WHERE cn.nspname='public' AND c.relname='character_progression'
 AND a.attname='rank' AND NOT a.attisdropped;
 IF col_type IS NULL THEN RAISE EXCEPTION 'Coluna public.character_progression.rank não encontrada'; END IF;
 IF col_type='e' THEN
   EXECUTE format('ALTER TYPE %I.%I ADD VALUE IF NOT EXISTS %L',enum_schema,enum_name,'S');
 ELSE
   FOR item IN
    SELECT con.conname,pg_get_constraintdef(con.oid) AS definition
    FROM pg_constraint con
    WHERE con.conrelid='public.character_progression'::regclass AND con.contype='c'
   LOOP
    IF item.definition ILIKE '%rank%' AND item.definition LIKE '%''A''%'
      AND item.definition LIKE '%''B''%' AND item.definition LIKE '%''C''%'
      AND item.definition LIKE '%''D''%' THEN
      EXECUTE format('ALTER TABLE public.character_progression DROP CONSTRAINT %I',item.conname);
    END IF;
   END LOOP;
   ALTER TABLE public.character_progression
     ADD CONSTRAINT bmth_progression_rank_s_check CHECK (rank::text IN ('D','C','B','A','S'));
 END IF;
END $rank_s$;

create or replace function public.bmth_set_progression(p_character uuid, p_rank text default null, p_xp integer default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_rank text; v_xp integer;
begin
  if not public.bmth_is_admin() then raise exception 'Acesso administrativo negado'; end if;
  if not exists(select 1 from public.characters where id=p_character) then raise exception 'Personagem não encontrado'; end if;
  if p_rank is not null and p_rank not in ('D','C','B','A','S') then raise exception 'Rank inválido'; end if;
  if p_xp is not null and (p_xp < 0 or p_xp > 1000000) then raise exception 'XP inválido'; end if;
  select rank::text, xp into v_rank,v_xp from public.character_progression where character_id=p_character for update;
  v_rank:=coalesce(p_rank,v_rank,'D'); v_xp:=coalesce(p_xp,v_xp,0);
  insert into public.character_progression(character_id,rank,xp)
    values(p_character,v_rank,v_xp)
    on conflict(character_id) do update set rank=excluded.rank,xp=excluded.xp;
end; $$;
revoke all on function public.bmth_set_progression(uuid,text,integer) from public,anon;
grant execute on function public.bmth_set_progression(uuid,text,integer) to authenticated;

create or replace function public.bmth_review_xp(p_request uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare r public.bmth_xp_requests%rowtype; v_rank text; v_xp integer; v_total integer;
begin
  if not public.bmth_is_admin() then raise exception 'Acesso administrativo negado'; end if;
  select * into r from public.bmth_xp_requests where id=p_request for update;
  if not found or r.status <> 'pending' then raise exception 'Pedido não está pendente'; end if;
  if p_approve then
    select rank::text,xp into v_rank,v_xp from public.character_progression where character_id=r.character_id for update;
    v_total:=coalesce(v_xp,0)+r.amount;
    -- XP acumulado; a cada 100 pontos sobe um rank, até S.
    v_rank:=case when v_total>=400 then 'S' when v_total>=300 then 'A' when v_total>=200 then 'B' when v_total>=100 then 'C' else 'D' end;
    insert into public.character_progression(character_id,rank,xp)
      values(r.character_id,v_rank,v_total)
      on conflict(character_id) do update set rank=excluded.rank,xp=excluded.xp;
  end if;
  update public.bmth_xp_requests set status=case when p_approve then 'approved' else 'rejected' end,
    reviewed_by=auth.uid(),reviewed_at=now() where id=p_request;
end; $$;
revoke all on function public.bmth_review_xp(uuid,boolean) from public,anon;
grant execute on function public.bmth_review_xp(uuid,boolean) to authenticated;

create or replace function public.bmth_grant_xp(p_character uuid, p_amount integer)
returns table(total_xp integer, new_rank text)
language plpgsql security definer set search_path = '' as $$
declare v_total integer; v_rank text;
begin
 if not public.bmth_is_admin() then raise exception 'Acesso administrativo negado'; end if;
 if p_amount is null or p_amount < 1 or p_amount > 10000 then raise exception 'Informe entre 1 e 10000 XP'; end if;
 if not exists(select 1 from public.characters where id=p_character) then raise exception 'Personagem não encontrado'; end if;
 -- Serializa concessões ao mesmo personagem mesmo quando a progressão ainda não existe.
 perform 1 from public.characters where id=p_character for update;
 select cp.xp into v_total from public.character_progression cp where cp.character_id=p_character;
 v_total:=coalesce(v_total,0)+p_amount;
 if v_total>1000000 then raise exception 'Limite de XP atingido'; end if;
 v_rank:=case when v_total>=400 then 'S' when v_total>=300 then 'A' when v_total>=200 then 'B' when v_total>=100 then 'C' else 'D' end;
 insert into public.character_progression(character_id,rank,xp)
 values(p_character,v_rank,v_total)
 on conflict(character_id) do update set rank=excluded.rank,xp=excluded.xp;
 return query select v_total,v_rank;
end; $$;
revoke all on function public.bmth_grant_xp(uuid,integer) from public,anon;
grant execute on function public.bmth_grant_xp(uuid,integer) to authenticated;
