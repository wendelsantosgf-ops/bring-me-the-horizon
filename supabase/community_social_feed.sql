-- BMTH: feed social independente das Wikis. Execute no SQL Editor do Supabase.
-- Não remove nem altera registros existentes.
create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null default '' check (char_length(content)<=5000),
  image_url text,
  created_at timestamptz not null default now(),
  constraint community_posts_nonempty check (length(trim(content))>0 or image_url is not null)
);
create index if not exists community_posts_recent_idx on public.community_posts(created_at desc);
alter table public.community_posts enable row level security;
drop policy if exists "community_posts_read" on public.community_posts;
create policy "community_posts_read" on public.community_posts for select to authenticated using (true);
drop policy if exists "community_posts_insert" on public.community_posts;
create policy "community_posts_insert" on public.community_posts for insert to authenticated with check ((select auth.uid())=user_id);
drop policy if exists "community_posts_delete" on public.community_posts;
create policy "community_posts_delete" on public.community_posts for delete to authenticated using ((select auth.uid())=user_id);

create table if not exists public.community_reactions (
  post_id uuid not null references public.community_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null check (reaction in ('like','dislike')),
  created_at timestamptz not null default now(),
  primary key(post_id,user_id)
);
alter table public.community_reactions enable row level security;
drop policy if exists "community_reactions_read" on public.community_reactions;
create policy "community_reactions_read" on public.community_reactions for select to authenticated using (true);
drop policy if exists "community_reactions_insert" on public.community_reactions;
create policy "community_reactions_insert" on public.community_reactions for insert to authenticated with check ((select auth.uid())=user_id);
drop policy if exists "community_reactions_update" on public.community_reactions;
create policy "community_reactions_update" on public.community_reactions for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
drop policy if exists "community_reactions_delete" on public.community_reactions;
create policy "community_reactions_delete" on public.community_reactions for delete to authenticated using ((select auth.uid())=user_id);

create table if not exists public.community_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (length(trim(content))>0 and char_length(content)<=2000),
  created_at timestamptz not null default now()
);
create index if not exists community_comments_post_idx on public.community_comments(post_id,created_at);
alter table public.community_comments enable row level security;
drop policy if exists "community_comments_read" on public.community_comments;
create policy "community_comments_read" on public.community_comments for select to authenticated using (true);
drop policy if exists "community_comments_insert" on public.community_comments;
create policy "community_comments_insert" on public.community_comments for insert to authenticated with check ((select auth.uid())=user_id);
drop policy if exists "community_comments_delete" on public.community_comments;
create policy "community_comments_delete" on public.community_comments for delete to authenticated using ((select auth.uid())=user_id);

-- Reações negativas em Wikis, sem alterar wiki_likes existente.
create table if not exists public.wiki_dislikes (
  wiki_id uuid not null references public.ability_wikis(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(wiki_id,user_id)
);
alter table public.wiki_dislikes enable row level security;
drop policy if exists "wiki_dislikes_read" on public.wiki_dislikes;
create policy "wiki_dislikes_read" on public.wiki_dislikes for select to authenticated using (true);
drop policy if exists "wiki_dislikes_insert" on public.wiki_dislikes;
create policy "wiki_dislikes_insert" on public.wiki_dislikes for insert to authenticated with check ((select auth.uid())=user_id);
drop policy if exists "wiki_dislikes_delete" on public.wiki_dislikes;
create policy "wiki_dislikes_delete" on public.wiki_dislikes for delete to authenticated using ((select auth.uid())=user_id);

-- Imagens do feed em bucket separado, com acesso público de leitura.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('community-images','community-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
drop policy if exists "community_images_read" on storage.objects;
create policy "community_images_read" on storage.objects for select to public using (bucket_id='community-images');
drop policy if exists "community_images_upload" on storage.objects;
create policy "community_images_upload" on storage.objects for insert to authenticated
with check (bucket_id='community-images' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "community_images_delete" on storage.objects;
create policy "community_images_delete" on storage.objects for delete to authenticated
using (bucket_id='community-images' and (storage.foldername(name))[1]=(select auth.uid())::text);
