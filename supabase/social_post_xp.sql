-- BMTH: +0,5 XP por publicação no feed, máximo de 10 recompensas por dia.
-- Execute uma vez no SQL Editor do Supabase; idempotente.
-- 1 XP = 10 unidades em bmth_member_xp.xp_tenths.
create or replace function public.bmth_reward_social_post()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'America/Sao_Paulo')::date;
  v_awarded integer;
begin
  if new.user_id is null or public.bmth_is_restricted(new.user_id,'post') then
    return new;
  end if;

  -- Não premiar publicações vazias, mesmo que contenham somente mídia.
  -- Publicações com imagem e texto curto são válidas.
  if length(btrim(coalesce(new.content,''))) < 3 then
    return new;
  end if;

  -- Serializa recompensas do mesmo membro para impedir ultrapassar o limite.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.user_id::text, 87231));

  select count(*) into v_awarded
  from public.bmth_member_xp_events
  where user_id=new.user_id and event_type='social_post' and awarded_on=v_today;
  if v_awarded >= 10 then
    return new;
  end if;

  insert into public.bmth_member_xp_events(user_id,event_type,target_id,awarded_on)
  values(new.user_id,'social_post',new.id,v_today)
  on conflict do nothing;

  if found then
    insert into public.bmth_member_xp(user_id,xp_tenths)
    values(new.user_id,5)
    on conflict(user_id) do update
    set xp_tenths=public.bmth_member_xp.xp_tenths+5,updated_at=now();
  end if;
  return new;
end;
$$;

revoke all on function public.bmth_reward_social_post() from public,anon,authenticated;
drop trigger if exists bmth_social_post_xp on public.community_posts;
create trigger bmth_social_post_xp
after insert on public.community_posts
for each row execute function public.bmth_reward_social_post();
