-- BMTH in-app notifications: run in Supabase SQL Editor.
create table if not exists public.bmth_notifications (
 id uuid primary key default gen_random_uuid(),
 recipient_id uuid not null references auth.users(id) on delete cascade,
 actor_id uuid references auth.users(id) on delete set null,
 kind text not null,
 title text not null,
 href text not null default './comunidade.html',
 read_at timestamptz,
 created_at timestamptz not null default now()
);
create index if not exists bmth_notifications_recipient_idx on public.bmth_notifications(recipient_id,created_at desc);
alter table public.bmth_notifications enable row level security;
grant select,update,delete on public.bmth_notifications to authenticated;
drop policy if exists bmth_notifications_select on public.bmth_notifications;
create policy bmth_notifications_select on public.bmth_notifications for select to authenticated using (recipient_id=auth.uid());
drop policy if exists bmth_notifications_update on public.bmth_notifications;
create policy bmth_notifications_update on public.bmth_notifications for update to authenticated using (recipient_id=auth.uid()) with check (recipient_id=auth.uid());
drop policy if exists bmth_notifications_delete on public.bmth_notifications;
create policy bmth_notifications_delete on public.bmth_notifications for delete to authenticated using (recipient_id=auth.uid());
-- Notifications are generated server-side; players cannot forge messages to other users.
create or replace function public.bmth_notify_character_event() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare owner_user uuid; actor uuid; char_name text; character_profile uuid;
begin
 if TG_TABLE_NAME='characters' then
  select p.user_id into actor from public.profile p where p.id=new.profile_id;
  char_name=trim(coalesce(new.first_name,'')||' '||coalesce(new.last_name,''));
  insert into public.bmth_notifications(recipient_id,actor_id,kind,title,href)
  select p.user_id,actor,'new_character','Nova ficha: '||char_name,'./perfil.html?id='||new.profile_id::text||'&character='||new.id::text
  from public.profile p where p.user_id<>actor;
 elsif TG_TABLE_NAME='character_comments' then
  select p.user_id,trim(coalesce(c.first_name,'')||' '||coalesce(c.last_name,'')),c.profile_id into owner_user,char_name,character_profile
  from public.characters c join public.profile p on p.id=c.profile_id where c.id=new.character_id;
  if owner_user is not null and owner_user<>new.user_id then
   insert into public.bmth_notifications(recipient_id,actor_id,kind,title,href)
   values(owner_user,new.user_id,'character_comment','Comentaram na ficha de '||char_name,'./perfil.html?id='||character_profile::text||'&character='||new.character_id::text);
  end if;
 elsif TG_TABLE_NAME='character_reactions' then
  select p.user_id,trim(coalesce(c.first_name,'')||' '||coalesce(c.last_name,'')) into owner_user,char_name
  from public.characters c join public.profile p on p.id=c.profile_id where c.id=new.character_id;
  if owner_user is not null and owner_user<>new.user_id then
   insert into public.bmth_notifications(recipient_id,actor_id,kind,title,href)
   values(owner_user,new.user_id,'character_reaction','Reagiram à ficha de '||char_name,'./comunidade.html');
  end if;
 end if;
 return new;
end $$;
drop trigger if exists bmth_character_created_notify on public.characters;
create trigger bmth_character_created_notify after insert on public.characters for each row execute function public.bmth_notify_character_event();
-- Optional triggers activate only when the interaction tables exist.
do $$ begin
 if to_regclass('public.character_comments') is not null then
  execute 'drop trigger if exists bmth_character_commented_notify on public.character_comments';
  execute 'create trigger bmth_character_commented_notify after insert on public.character_comments for each row execute function public.bmth_notify_character_event()';
 end if;
 if to_regclass('public.character_reactions') is not null then
  execute 'drop trigger if exists bmth_character_reacted_notify on public.character_reactions';
  execute 'create trigger bmth_character_reacted_notify after insert on public.character_reactions for each row execute function public.bmth_notify_character_event()';
 end if;
end $$;
