-- BMTH / Etapa 1: administração de progressão.
-- Execute no SQL Editor do Supabase, com uma conta de proprietário do projeto.
-- Depois de executar, substitua o UUID abaixo pelo auth.users.id do administrador:
-- INSERT INTO public.bmth_admins (user_id) VALUES ('SEU-UUID-AQUI') ON CONFLICT DO NOTHING;

create table if not exists public.bmth_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.bmth_admins enable row level security;
revoke all on public.bmth_admins from anon, authenticated;
grant select on public.bmth_admins to authenticated;
drop policy if exists bmth_admins_read_self on public.bmth_admins;
create policy bmth_admins_read_self on public.bmth_admins for select to authenticated
  using (user_id = (select auth.uid()));

create table if not exists public.bmth_xp_requests (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters(id) on delete cascade,
  requested_by uuid not null references auth.users(id) on delete cascade default auth.uid(),
  amount integer not null check (amount between 1 and 1000),
  reason text not null check (char_length(trim(reason)) between 5 and 1000),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists bmth_xp_requests_status_idx on public.bmth_xp_requests(status,created_at);
alter table public.bmth_xp_requests enable row level security;
grant select,insert on public.bmth_xp_requests to authenticated;
drop policy if exists bmth_xp_requests_read on public.bmth_xp_requests;
create policy bmth_xp_requests_read on public.bmth_xp_requests for select to authenticated
  using (requested_by = (select auth.uid()) or exists (select 1 from public.bmth_admins a where a.user_id = (select auth.uid())));
drop policy if exists bmth_xp_requests_insert on public.bmth_xp_requests;
create policy bmth_xp_requests_insert on public.bmth_xp_requests for insert to authenticated
  with check (
    requested_by = (select auth.uid()) and status = 'pending' and reviewed_by is null and reviewed_at is null
    and exists (
      select 1 from public.characters c join public.profile p on p.id=c.profile_id
      where c.id=character_id and p.user_id=(select auth.uid())
    )
  );

create or replace function public.bmth_is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.bmth_admins where user_id = (select auth.uid()));
$$;
revoke all on function public.bmth_is_admin() from public,anon;
grant execute on function public.bmth_is_admin() to authenticated;

create or replace function public.bmth_set_progression(p_character uuid, p_rank text default null, p_xp integer default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_rank text; v_xp integer;
begin
  if not public.bmth_is_admin() then raise exception 'Acesso administrativo negado'; end if;
  if not exists(select 1 from public.characters where id=p_character) then raise exception 'Personagem não encontrado'; end if;
  if p_rank is not null and p_rank not in ('D','C','B','A') then raise exception 'Rank inválido'; end if;
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
    -- XP acumulado; a cada 100 pontos sobe um rank, até A.
    v_rank:=case when v_total>=300 then 'A' when v_total>=200 then 'B' when v_total>=100 then 'C' else 'D' end;
    insert into public.character_progression(character_id,rank,xp)
      values(r.character_id,v_rank,v_total)
      on conflict(character_id) do update set rank=excluded.rank,xp=excluded.xp;
  end if;
  update public.bmth_xp_requests set status=case when p_approve then 'approved' else 'rejected' end,
    reviewed_by=auth.uid(),reviewed_at=now() where id=p_request;
end; $$;
revoke all on function public.bmth_review_xp(uuid,boolean) from public,anon;
grant execute on function public.bmth_review_xp(uuid,boolean) to authenticated;
