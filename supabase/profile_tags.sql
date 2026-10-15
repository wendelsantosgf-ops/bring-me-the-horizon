-- BMTH: tags coloridas de perfil. Execute no Supabase SQL Editor.
-- Tags sao exclusivamente visuais; nao concedem permissoes.
create table if not exists public.bmth_profile_tags (
 id uuid primary key default gen_random_uuid(),
 name text not null unique check (char_length(trim(name)) between 2 and 24),
 color text not null default '#d96a9b' check (color ~ '^#[0-9A-Fa-f]{6}$'),
 created_at timestamptz not null default now()
);
create table if not exists public.bmth_profile_tag_assignments (
 profile_id uuid not null references public.profile(id) on delete cascade,
 tag_id uuid not null references public.bmth_profile_tags(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key (profile_id,tag_id)
);
create index if not exists bmth_profile_tag_assignments_tag_idx on public.bmth_profile_tag_assignments(tag_id);
alter table public.bmth_profile_tags enable row level security;
alter table public.bmth_profile_tag_assignments enable row level security;
grant select on public.bmth_profile_tags,public.bmth_profile_tag_assignments to authenticated;
grant insert,update,delete on public.bmth_profile_tags,public.bmth_profile_tag_assignments to authenticated;
drop policy if exists bmth_tags_read on public.bmth_profile_tags;
create policy bmth_tags_read on public.bmth_profile_tags for select to authenticated using (true);
drop policy if exists bmth_tags_admin_insert on public.bmth_profile_tags;
create policy bmth_tags_admin_insert on public.bmth_profile_tags for insert to authenticated with check (public.bmth_is_admin());
drop policy if exists bmth_tags_admin_update on public.bmth_profile_tags;
create policy bmth_tags_admin_update on public.bmth_profile_tags for update to authenticated using (public.bmth_is_admin()) with check (public.bmth_is_admin());
drop policy if exists bmth_tags_admin_delete on public.bmth_profile_tags;
create policy bmth_tags_admin_delete on public.bmth_profile_tags for delete to authenticated using (public.bmth_is_admin());
drop policy if exists bmth_tag_assignments_read on public.bmth_profile_tag_assignments;
create policy bmth_tag_assignments_read on public.bmth_profile_tag_assignments for select to authenticated using (true);
drop policy if exists bmth_tag_assignments_admin_insert on public.bmth_profile_tag_assignments;
create policy bmth_tag_assignments_admin_insert on public.bmth_profile_tag_assignments for insert to authenticated with check (public.bmth_is_admin());
drop policy if exists bmth_tag_assignments_admin_delete on public.bmth_profile_tag_assignments;
create policy bmth_tag_assignments_admin_delete on public.bmth_profile_tag_assignments for delete to authenticated using (public.bmth_is_admin());
-- Tags iniciais (sem atribuir a ninguem).
insert into public.bmth_profile_tags(name,color) values
 ('Administrador','#e35a83'),('Moderador','#a78bfa'),('Narrador','#e4b56d'),
 ('Veterano','#58b9a8'),('Membro','#8792b5')
on conflict (name) do nothing;
