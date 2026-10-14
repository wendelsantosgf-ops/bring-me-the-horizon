-- BMTH: armazenamento público de capas de Wiki
-- Execute no SQL Editor do Supabase (uma vez).
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('wiki-images','wiki-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];

drop policy if exists bmth_wiki_image_upload on storage.objects;
create policy bmth_wiki_image_upload on storage.objects
for insert to authenticated
with check (
 bucket_id='wiki-images'
 and (storage.foldername(name))[1]=(select auth.uid())::text
 and lower(storage.extension(name)) in ('jpg','jpeg','png','webp')
);
-- Bucket público permite exibir capas no feed para todos.
-- O upload exige login e pasta com o próprio ID de usuário.
