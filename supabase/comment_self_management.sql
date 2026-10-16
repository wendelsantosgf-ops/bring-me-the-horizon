-- BMTH | Permitir que membros editem os próprios comentários.
-- Executar uma vez no Supabase SQL Editor. Preserva as restrições de silenciamento.

alter table public.community_comments enable row level security;
alter table public.character_comments enable row level security;

drop policy if exists bmth_own_comment_update on public.community_comments;
create policy bmth_own_comment_update on public.community_comments
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()) and not public.bmth_is_restricted(auth.uid(), 'mute'));

drop policy if exists bmth_own_character_comment_update on public.character_comments;
create policy bmth_own_character_comment_update on public.character_comments
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()) and not public.bmth_is_restricted(auth.uid(), 'mute'));

-- Exclusão do próprio comentário (políticas antigas continuam válidas).
drop policy if exists bmth_own_character_comment_delete on public.character_comments;
create policy bmth_own_character_comment_delete on public.character_comments
for delete to authenticated using (user_id = (select auth.uid()));
