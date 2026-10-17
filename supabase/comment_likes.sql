-- BMTH: curtidas por comentario em publicacoes, fichas e wikis.
-- Execute uma vez no SQL Editor do Supabase. Nao altera comentarios existentes.
create table if not exists public.bmth_comment_likes (
  comment_type text not null check (comment_type in ('community_comments','character_comments','wiki_comments')),
  comment_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_type, comment_id, user_id)
);
create index if not exists bmth_comment_likes_comment_idx on public.bmth_comment_likes(comment_type, comment_id);
alter table public.bmth_comment_likes enable row level security;
drop policy if exists "bmth_comment_likes_read" on public.bmth_comment_likes;
create policy "bmth_comment_likes_read" on public.bmth_comment_likes for select to authenticated using (true);
drop policy if exists "bmth_comment_likes_insert" on public.bmth_comment_likes;
create policy "bmth_comment_likes_insert" on public.bmth_comment_likes for insert to authenticated
with check (auth.uid()=user_id and
  (comment_type='community_comments' and exists(select 1 from public.community_comments c where c.id=comment_id)
   or comment_type='character_comments' and exists(select 1 from public.character_comments c where c.id=comment_id)
   or comment_type='wiki_comments' and exists(select 1 from public.wiki_comments c where c.id=comment_id)));
drop policy if exists "bmth_comment_likes_delete" on public.bmth_comment_likes;
create policy "bmth_comment_likes_delete" on public.bmth_comment_likes for delete to authenticated using (auth.uid()=user_id);
-- Limpa curtidas de comentarios removidos, sem tocar nos comentarios.
create or replace function public.bmth_cleanup_comment_likes() returns trigger language plpgsql security definer set search_path=public as $$
begin
 delete from public.bmth_comment_likes where comment_type=TG_TABLE_NAME and comment_id=old.id;
 return old;
end; $$;
drop trigger if exists bmth_comment_likes_cleanup on public.community_comments;
create trigger bmth_comment_likes_cleanup after delete on public.community_comments for each row execute function public.bmth_cleanup_comment_likes();
drop trigger if exists bmth_comment_likes_cleanup on public.character_comments;
create trigger bmth_comment_likes_cleanup after delete on public.character_comments for each row execute function public.bmth_cleanup_comment_likes();
drop trigger if exists bmth_comment_likes_cleanup on public.wiki_comments;
create trigger bmth_comment_likes_cleanup after delete on public.wiki_comments for each row execute function public.bmth_cleanup_comment_likes();
