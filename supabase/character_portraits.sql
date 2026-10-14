-- BMTH / Retratos dos personagens
-- Execute no SQL Editor do Supabase.
alter table public.characters add column if not exists portrait_url text;
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('character-images','character-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists bmth_character_image_upload on storage.objects;
create policy bmth_character_image_upload on storage.objects for insert to authenticated
with check (bucket_id='character-images' and (storage.foldername(name))[1]=(select auth.uid())::text
  and exists(select 1 from public.characters c join public.profile p on p.id=c.profile_id
    where c.id::text=(storage.foldername(name))[2] and p.user_id=(select auth.uid())));
-- As imagens são públicas para que qualquer visitante do perfil possa vê-las.
-- A criação de novos arquivos é restrita ao dono do personagem.
