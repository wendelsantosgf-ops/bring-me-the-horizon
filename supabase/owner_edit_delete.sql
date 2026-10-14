-- BMTH: permitir que cada autor edite/apague suas publicações, Wikis e personagens.
-- Execute no SQL Editor do Supabase. Não altera nem apaga registros.
drop policy if exists "community_posts_update_owner" on public.community_posts;
create policy "community_posts_update_owner" on public.community_posts for update to authenticated
using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));

-- As Wikis pertencem ao personagem, que pertence ao perfil do usuário.
drop policy if exists "ability_wikis_update_owner" on public.ability_wikis;
create policy "ability_wikis_update_owner" on public.ability_wikis for update to authenticated
using (exists (select 1 from public.characters c join public.profile p on p.id=c.profile_id where c.id=character_id and p.user_id=(select auth.uid())))
with check (exists (select 1 from public.characters c join public.profile p on p.id=c.profile_id where c.id=character_id and p.user_id=(select auth.uid())));
drop policy if exists "ability_wikis_delete_owner" on public.ability_wikis;
create policy "ability_wikis_delete_owner" on public.ability_wikis for delete to authenticated
using (exists (select 1 from public.characters c join public.profile p on p.id=c.profile_id where c.id=character_id and p.user_id=(select auth.uid())));

drop policy if exists "characters_update_owner" on public.characters;
create policy "characters_update_owner" on public.characters for update to authenticated
using (exists (select 1 from public.profile p where p.id=profile_id and p.user_id=(select auth.uid())))
with check (exists (select 1 from public.profile p where p.id=profile_id and p.user_id=(select auth.uid())));
drop policy if exists "characters_delete_owner" on public.characters;
create policy "characters_delete_owner" on public.characters for delete to authenticated
using (exists (select 1 from public.profile p where p.id=profile_id and p.user_id=(select auth.uid())));
