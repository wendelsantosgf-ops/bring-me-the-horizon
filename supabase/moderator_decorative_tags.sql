-- BMTH: permitir moderadores gerenciar tags decorativas sem conceder cargos.
-- Execute no Supabase SQL Editor. Requer supabase/staff_moderation.sql instalado.
-- Níveis: dono 3, moderador 2, curador 1, membro 0.

-- Remove políticas administrativas anteriores, substituindo por políticas de staff.
drop policy if exists bmth_tags_admin_insert on public.bmth_profile_tags;
drop policy if exists bmth_tags_admin_update on public.bmth_profile_tags;
drop policy if exists bmth_tags_admin_delete on public.bmth_profile_tags;
drop policy if exists bmth_tag_assignments_admin_insert on public.bmth_profile_tag_assignments;
drop policy if exists bmth_tag_assignments_admin_delete on public.bmth_profile_tag_assignments;

-- Reservar nomes de cargos para impedir criação/edição de tags falsas.
create or replace function public.bmth_is_decorative_tag(p_name text)
returns boolean language sql immutable set search_path='' as $$
 select lower(btrim(coalesce(p_name,''))) !~ '^(moderador(a|es|as)?|curador(a|es|as)?|administrador(a|es|as)?|admins?)$'
$$;
revoke all on function public.bmth_is_decorative_tag(text) from public,anon;
grant execute on function public.bmth_is_decorative_tag(text) to authenticated;

create policy bmth_tags_staff_insert on public.bmth_profile_tags
for insert to authenticated
with check (public.bmth_staff_level(auth.uid()) >= 2 and public.bmth_is_decorative_tag(name));
create policy bmth_tags_staff_update on public.bmth_profile_tags
for update to authenticated
using (public.bmth_staff_level(auth.uid()) >= 2 and public.bmth_is_decorative_tag(name))
with check (public.bmth_staff_level(auth.uid()) >= 2 and public.bmth_is_decorative_tag(name));
create policy bmth_tags_staff_delete on public.bmth_profile_tags
for delete to authenticated
using (public.bmth_staff_level(auth.uid()) >= 2 and public.bmth_is_decorative_tag(name));

create policy bmth_tag_assignments_staff_insert on public.bmth_profile_tag_assignments
for insert to authenticated
with check (public.bmth_staff_level(auth.uid()) >= 2 and exists (
 select 1 from public.bmth_profile_tags t where t.id=tag_id and public.bmth_is_decorative_tag(t.name)
));
create policy bmth_tag_assignments_staff_delete on public.bmth_profile_tag_assignments
for delete to authenticated
using (public.bmth_staff_level(auth.uid()) >= 2 and exists (
 select 1 from public.bmth_profile_tags t where t.id=tag_id and public.bmth_is_decorative_tag(t.name)
));
