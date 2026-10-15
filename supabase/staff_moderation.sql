-- BMTH: hierarquia de staff e moderacao. Executar no Supabase SQL Editor.
-- Dono = bmth_admins; moderador = nivel 2; curador = nivel 1; membro = 0.
create table if not exists public.bmth_staff (
 user_id uuid primary key references auth.users(id) on delete cascade,
 role text not null check(role in ('moderator','curator')),
 appointed_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.bmth_sanctions (
 id uuid primary key default gen_random_uuid(),
 target_user uuid not null references auth.users(id) on delete cascade,
 actor_user uuid not null references auth.users(id),
 kind text not null check(kind in ('mute','ban')),
 reason text not null check(length(trim(reason)) between 5 and 1000),
 expires_at timestamptz,
 revoked_at timestamptz,
 revoked_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 check(expires_at is null or expires_at>created_at)
);
create index if not exists bmth_sanctions_active_idx on public.bmth_sanctions(target_user,kind,expires_at) where revoked_at is null;
alter table public.bmth_staff enable row level security;
alter table public.bmth_sanctions enable row level security;
revoke all on public.bmth_staff,public.bmth_sanctions from anon,authenticated;
grant select on public.bmth_staff to authenticated;
create or replace function public.bmth_staff_level(p_user uuid default auth.uid())
returns integer language sql stable security definer set search_path='' as $$
 select case when exists(select 1 from public.bmth_admins where user_id=p_user) then 3
 when exists(select 1 from public.bmth_staff where user_id=p_user and role='moderator') then 2
 when exists(select 1 from public.bmth_staff where user_id=p_user and role='curator') then 1 else 0 end
$$;
revoke all on function public.bmth_staff_level(uuid) from public,anon;
grant execute on function public.bmth_staff_level(uuid) to authenticated;
drop policy if exists bmth_staff_read on public.bmth_staff;
create policy bmth_staff_read on public.bmth_staff for select to authenticated using(true);
create or replace function public.bmth_is_restricted(p_user uuid, p_kind text)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.bmth_sanctions where target_user=p_user and revoked_at is null and (expires_at is null or expires_at>now()) and (kind='ban' or kind=p_kind))
$$;
revoke all on function public.bmth_is_restricted(uuid,text) from public,anon;
grant execute on function public.bmth_is_restricted(uuid,text) to authenticated;
create or replace function public.bmth_appoint_staff(p_user uuid,p_role text)
returns void language plpgsql security definer set search_path='' as $$
declare v_actor integer; v_target integer;
begin
 v_actor:=public.bmth_staff_level(auth.uid());v_target:=public.bmth_staff_level(p_user);
 if p_user=auth.uid() or v_target>=v_actor then raise exception 'Hierarquia nao permite esta alteracao';end if;
 if p_role='moderator' and v_actor<>3 then raise exception 'Apenas o dono nomeia moderadores';end if;
 if p_role not in ('moderator','curator') or v_actor<2 then raise exception 'Cargo ou permissao invalida';end if;
 if not exists(select 1 from public.profile where user_id=p_user) then raise exception 'Membro nao encontrado';end if;
 insert into public.bmth_staff(user_id,role,appointed_by) values(p_user,p_role,auth.uid())
 on conflict(user_id) do update set role=excluded.role,appointed_by=excluded.appointed_by;
end $$;
create or replace function public.bmth_remove_staff(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if public.bmth_staff_level(auth.uid())<2 or public.bmth_staff_level(p_user)>=public.bmth_staff_level(auth.uid()) then raise exception 'Permissao negada';end if;
 if public.bmth_staff_level(p_user)=2 and public.bmth_staff_level(auth.uid())<>3 then raise exception 'Apenas o dono remove moderadores';end if;
 delete from public.bmth_staff where user_id=p_user;
end $$;
create or replace function public.bmth_apply_sanction(p_user uuid,p_kind text,p_reason text,p_expires_at timestamptz default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;v_level integer;
begin
 v_level:=public.bmth_staff_level(auth.uid());
 if v_level<1 or (p_kind='ban' and v_level<2) or p_kind not in ('mute','ban') then raise exception 'Permissao insuficiente';end if;
 if public.bmth_staff_level(p_user)>=v_level then raise exception 'Nao pode punir cargo igual ou superior';end if;
 if length(trim(coalesce(p_reason,'')))<5 or length(p_reason)>1000 then raise exception 'Informe um motivo de 5 a 1000 caracteres';end if;
 if p_expires_at is not null and p_expires_at<=now() then raise exception 'Duracao invalida';end if;
 if not exists(select 1 from public.profile where user_id=p_user) then raise exception 'Membro nao encontrado';end if;
 insert into public.bmth_sanctions(target_user,actor_user,kind,reason,expires_at)
 values(p_user,auth.uid(),p_kind,trim(p_reason),p_expires_at) returning id into v_id;
 return v_id;
end $$;
create or replace function public.bmth_revoke_sanction(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_row public.bmth_sanctions%rowtype;
begin
 select * into v_row from public.bmth_sanctions where id=p_id for update;
 if not found then raise exception 'Punicao nao encontrada';end if;
 if public.bmth_staff_level(auth.uid())<2 and not (public.bmth_staff_level(auth.uid())=1 and v_row.kind='mute' and v_row.actor_user=auth.uid()) then raise exception 'Permissao insuficiente';end if;
 if public.bmth_staff_level(v_row.target_user)>=public.bmth_staff_level(auth.uid()) then raise exception 'Hierarquia nao permite esta acao';end if;
 update public.bmth_sanctions set revoked_at=now(),revoked_by=auth.uid() where id=p_id and revoked_at is null;
end $$;
create or replace function public.bmth_moderate_post(p_post uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare v_author uuid;
begin
 if public.bmth_staff_level(auth.uid())<2 then raise exception 'Apenas moderadores removem postagens';end if;
 select user_id into v_author from public.community_posts where id=p_post;
 if v_author is null then raise exception 'Postagem nao encontrada';end if;
 if public.bmth_staff_level(v_author)>=public.bmth_staff_level(auth.uid()) then raise exception 'Hierarquia protegida';end if;
 if length(trim(coalesce(p_reason,'')))<5 then raise exception 'Motivo obrigatorio';end if;
 delete from public.community_posts where id=p_post;
end $$;
do $$ begin
 if not exists(select 1 from information_schema.tables where table_schema='public' and table_name='bmth_moderation_log') then
 create table public.bmth_moderation_log(id uuid primary key default gen_random_uuid(),actor_user uuid not null,action text not null,target_user uuid,target_post uuid,reason text,created_at timestamptz not null default now());
 end if;
end $$;
alter table public.bmth_moderation_log enable row level security;
revoke all on public.bmth_moderation_log from anon,authenticated;
-- Acoes sao registradas automaticamente no banco (sem escrita direta pelo cliente).
create or replace function public.bmth_log_moderation() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='bmth_sanctions' then
 insert into public.bmth_moderation_log(actor_user,action,target_user,reason) values(coalesce(new.revoked_by,new.actor_user),case when tg_op='INSERT' then new.kind else 'revoke_'||new.kind end,new.target_user,new.reason);
 end if;
 return new;
end $$;
drop trigger if exists bmth_sanctions_log on public.bmth_sanctions;
create trigger bmth_sanctions_log after insert or update of revoked_at on public.bmth_sanctions for each row execute function public.bmth_log_moderation();
-- Aplicar bloqueios no proprio banco, evitando bypass pelo navegador.
drop policy if exists community_posts_insert on public.community_posts;
create policy community_posts_insert on public.community_posts for insert to authenticated with check(auth.uid()=user_id and not public.bmth_is_restricted(auth.uid(),'mute'));
drop policy if exists community_comments_insert on public.community_comments;
create policy community_comments_insert on public.community_comments for insert to authenticated with check(auth.uid()=user_id and not public.bmth_is_restricted(auth.uid(),'mute'));
drop policy if exists community_reactions_insert on public.community_reactions;
create policy community_reactions_insert on public.community_reactions for insert to authenticated with check(auth.uid()=user_id and not public.bmth_is_restricted(auth.uid(),'ban'));
drop policy if exists community_reactions_update on public.community_reactions;
create policy community_reactions_update on public.community_reactions for update to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id and not public.bmth_is_restricted(auth.uid(),'ban'));
-- Permitir remocao por moderador via funcao SECURITY DEFINER.
revoke all on function public.bmth_appoint_staff(uuid,text),public.bmth_remove_staff(uuid),public.bmth_apply_sanction(uuid,text,text,timestamptz),public.bmth_revoke_sanction(uuid),public.bmth_moderate_post(uuid,text) from public,anon;
grant execute on function public.bmth_appoint_staff(uuid,text),public.bmth_remove_staff(uuid),public.bmth_apply_sanction(uuid,text,text,timestamptz),public.bmth_revoke_sanction(uuid),public.bmth_moderate_post(uuid,text) to authenticated;

-- Politicas restritivas se combinam com TODAS as politicas permissivas existentes.
-- Bloqueia tambem Wikis, comentarios de personagens e reacoes.
do $$
declare t text;
begin
 foreach t in array array['community_posts','community_comments','community_reactions','ability_wikis','wiki_comments','wiki_likes','wiki_dislikes','character_comments','character_reactions'] loop
 if to_regclass('public.'||t) is not null then
 execute format('drop policy if exists bmth_sanctions_guard_insert on public.%I',t);
 execute format('create policy bmth_sanctions_guard_insert on public.%I as restrictive for insert to authenticated with check (not public.bmth_is_restricted(auth.uid(), %L))',t,
 case when t in ('community_posts','community_comments','wiki_comments','character_comments','ability_wikis') then 'mute' else 'ban' end);
 end if;
 end loop;
end $$;
-- Guardar atualizacoes de conteudo (sem impedir exclusao do proprio conteudo).
do $$
declare t text;
begin
 foreach t in array array['community_posts','ability_wikis'] loop
 if to_regclass('public.'||t) is not null then
 execute format('drop policy if exists bmth_sanctions_guard_update on public.%I',t);
 execute format('create policy bmth_sanctions_guard_update on public.%I as restrictive for update to authenticated using (not public.bmth_is_restricted(auth.uid(), %L)) with check (not public.bmth_is_restricted(auth.uid(), %L))',t,'mute','mute');
 end if;
 end loop;
end $$;
