-- BMTH: múltiplas imagens e GIFs nas publicações sociais.
-- Execute no SQL Editor do Supabase antes de testar o novo editor.
create table if not exists public.bmth_post_media(
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.community_posts(id) on delete cascade,
 url text not null check (length(url) between 8 and 2048),
 position integer not null default 0,
 created_at timestamptz not null default now()
);
create index if not exists bmth_post_media_order_idx on public.bmth_post_media(post_id,position);
alter table public.bmth_post_media enable row level security;
drop policy if exists bmth_post_media_read on public.bmth_post_media;
create policy bmth_post_media_read on public.bmth_post_media for select to authenticated using(true);
drop policy if exists bmth_post_media_insert on public.bmth_post_media;
create policy bmth_post_media_insert on public.bmth_post_media for insert to authenticated with check(
 exists(select 1 from public.community_posts p where p.id=post_id and p.user_id=auth.uid())
 and not public.bmth_is_restricted(auth.uid(),'post')
);
drop policy if exists bmth_post_media_delete on public.bmth_post_media;
create policy bmth_post_media_delete on public.bmth_post_media for delete to authenticated using(
 exists(select 1 from public.community_posts p where p.id=post_id and p.user_id=auth.uid())
 or public.bmth_staff_level()>=2
);
-- O bucket já existe; amplia os tipos e tamanho máximo para GIFs animados.
update storage.buckets set public=true,file_size_limit=15728640,
 allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif']
 where id='community-images';
