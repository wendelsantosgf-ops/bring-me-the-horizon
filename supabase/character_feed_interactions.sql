-- Reactions and comments on character announcements in the BMTH feed.
-- Run in Supabase SQL Editor. Existing characters and posts are not modified.
create table if not exists public.character_reactions (
 character_id uuid not null references public.characters(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 reaction text not null check (reaction in ('like','dislike')),
 created_at timestamptz not null default now(),
 primary key(character_id,user_id)
);
create table if not exists public.character_comments (
 id uuid primary key default gen_random_uuid(),
 character_id uuid not null references public.characters(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 content text not null check (char_length(trim(content)) between 1 and 2000),
 created_at timestamptz not null default now()
);
create index if not exists character_comments_character_created_idx on public.character_comments(character_id,created_at);
alter table public.character_reactions enable row level security;
alter table public.character_comments enable row level security;
grant select,insert,update,delete on public.character_reactions to authenticated;
grant select,insert,update,delete on public.character_comments to authenticated;
drop policy if exists character_reactions_read on public.character_reactions;
create policy character_reactions_read on public.character_reactions for select to authenticated using (true);
drop policy if exists character_reactions_insert on public.character_reactions;
create policy character_reactions_insert on public.character_reactions for insert to authenticated with check (user_id=auth.uid());
drop policy if exists character_reactions_update on public.character_reactions;
create policy character_reactions_update on public.character_reactions for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
drop policy if exists character_reactions_delete on public.character_reactions;
create policy character_reactions_delete on public.character_reactions for delete to authenticated using (user_id=auth.uid());
drop policy if exists character_comments_read on public.character_comments;
create policy character_comments_read on public.character_comments for select to authenticated using (true);
drop policy if exists character_comments_insert on public.character_comments;
create policy character_comments_insert on public.character_comments for insert to authenticated with check (user_id=auth.uid());
drop policy if exists character_comments_delete on public.character_comments;
create policy character_comments_delete on public.character_comments for delete to authenticated using (user_id=auth.uid() or public.bmth_is_admin());
