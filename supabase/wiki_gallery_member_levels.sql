-- BMTH | Galerias de Wikis e níveis de comunidade
-- Execute no Supabase SQL Editor antes de testar as novas funções.
-- O limite de tamanho de arquivos do bucket wiki-images deve aceitar GIFs de até 15 MB.
create table if not exists public.bmth_wiki_media (
 id uuid primary key default gen_random_uuid(),
 wiki_id uuid not null references public.ability_wikis(id) on delete cascade,
 url text not null check (length(url) between 8 and 2048),
 position integer not null default 0,
 created_at timestamptz not null default now()
);
create index if not exists bmth_wiki_media_order on public.bmth_wiki_media(wiki_id,position);
alter table public.bmth_wiki_media enable row level security;
drop policy if exists bmth_wiki_media_read on public.bmth_wiki_media;
create policy bmth_wiki_media_read on public.bmth_wiki_media for select to authenticated using (true);
drop policy if exists bmth_wiki_media_insert on public.bmth_wiki_media;
create policy bmth_wiki_media_insert on public.bmth_wiki_media for insert to authenticated with check (
 exists (select 1 from public.ability_wikis w join public.characters c on c.id=w.character_id join public.profile p on p.id=c.profile_id where w.id=wiki_id and p.user_id=auth.uid())
 and not public.bmth_is_restricted(auth.uid(),'post')
);
drop policy if exists bmth_wiki_media_delete on public.bmth_wiki_media;
create policy bmth_wiki_media_delete on public.bmth_wiki_media for delete to authenticated using (
 exists (select 1 from public.ability_wikis w join public.characters c on c.id=w.character_id join public.profile p on p.id=c.profile_id where w.id=wiki_id and p.user_id=auth.uid())
 or public.bmth_staff_level() >= 2
);
create table if not exists public.bmth_member_xp (
 user_id uuid primary key references auth.users(id) on delete cascade,
 xp_tenths bigint not null default 0 check (xp_tenths>=0),
 last_daily date,
 updated_at timestamptz not null default now()
);
alter table public.bmth_member_xp enable row level security;
drop policy if exists bmth_member_xp_read on public.bmth_member_xp;
create policy bmth_member_xp_read on public.bmth_member_xp for select to authenticated using (true);
create table if not exists public.bmth_member_xp_events (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 event_type text not null,
 target_id uuid,
 awarded_on date not null default (now() at time zone 'America/Sao_Paulo')::date,
 created_at timestamptz not null default now(),
 unique(user_id,event_type,target_id,awarded_on)
);
alter table public.bmth_member_xp_events enable row level security;
create or replace function public.bmth_daily_checkin()
returns bigint language plpgsql security definer set search_path='' as $$
declare v_user uuid := auth.uid(); v_today date := (now() at time zone 'America/Sao_Paulo')::date; v_xp bigint;
begin
 if v_user is null then raise exception 'Login necessário'; end if;
 insert into public.bmth_member_xp(user_id,xp_tenths,last_daily) values(v_user,50,v_today)
 on conflict(user_id) do update set xp_tenths=public.bmth_member_xp.xp_tenths+case when public.bmth_member_xp.last_daily is distinct from v_today then 50 else 0 end,
 last_daily=v_today,updated_at=now();
 select xp_tenths into v_xp from public.bmth_member_xp where user_id=v_user;
 return v_xp;
end $$;
revoke all on function public.bmth_daily_checkin() from public;
grant execute on function public.bmth_daily_checkin() to authenticated;
create or replace function public.bmth_reward_engagement()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_owner uuid; v_target uuid; v_kind text; v_count integer;
begin
 if tg_table_name='wiki_comments' then
  if length(trim(new.content))<10 then return new; end if;
  select p.user_id into v_owner from public.ability_wikis w join public.characters c on c.id=w.character_id join public.profile p on p.id=c.profile_id where w.id=new.wiki_id;
  v_target:=new.wiki_id;v_kind:='wiki_comment';
 elsif tg_table_name='community_comments' then
  if length(trim(new.content))<10 then return new; end if;
  select user_id into v_owner from public.community_posts where id=new.post_id;
  v_target:=new.post_id;v_kind:='feed_comment';
 else return new;
 end if;
 if v_owner is null or v_owner=new.user_id or public.bmth_is_restricted(new.user_id,'comment') then return new; end if;
 select count(*) into v_count from public.bmth_member_xp_events where user_id=new.user_id and awarded_on=(now() at time zone 'America/Sao_Paulo')::date and event_type in ('wiki_comment','feed_comment');
 if v_count>=20 then return new; end if;
 insert into public.bmth_member_xp_events(user_id,event_type,target_id)
 values(new.user_id,v_kind,v_target) on conflict do nothing;
 if found then
  insert into public.bmth_member_xp(user_id,xp_tenths) values(new.user_id,1)
  on conflict(user_id) do update set xp_tenths=public.bmth_member_xp.xp_tenths+1,updated_at=now();
 end if;
 return new;
end $$;
drop trigger if exists bmth_wiki_comment_xp on public.wiki_comments;
create trigger bmth_wiki_comment_xp after insert on public.wiki_comments for each row execute function public.bmth_reward_engagement();
drop trigger if exists bmth_feed_comment_xp on public.community_comments;
create trigger bmth_feed_comment_xp after insert on public.community_comments for each row execute function public.bmth_reward_engagement();
