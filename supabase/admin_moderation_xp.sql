-- BMTH: permissões de proprietário/admin + concessão direta de XP.
-- Execute no SQL Editor do Supabase. Não apaga publicações ou personagens.
-- Pré-requisito: supabase/admin_progression.sql e supabase/community_social_feed.sql já executados.
-- O administrador é reconhecido por public.bmth_is_admin(), NÃO pelo HTML.

grant select,update,delete on public.community_posts, public.ability_wikis, public.characters to authenticated;
alter table public.community_posts enable row level security;
alter table public.ability_wikis enable row level security;
alter table public.characters enable row level security;

-- Recria as permissões específicas. As políticas anteriores de leitura/criação permanecem.
drop policy if exists community_posts_update_owner on public.community_posts;
drop policy if exists community_posts_delete on public.community_posts;
drop policy if exists community_posts_delete_owner_admin on public.community_posts;
create policy community_posts_update_owner on public.community_posts for update to authenticated
using (user_id=(select auth.uid()) or public.bmth_is_admin())
with check (user_id=(select auth.uid()) or public.bmth_is_admin());
create policy community_posts_delete_owner_admin on public.community_posts for delete to authenticated
using (user_id=(select auth.uid()) or public.bmth_is_admin());

drop policy if exists ability_wikis_update_owner on public.ability_wikis;
drop policy if exists ability_wikis_delete_owner on public.ability_wikis;
drop policy if exists ability_wikis_update_owner_admin on public.ability_wikis;
drop policy if exists ability_wikis_delete_owner_admin on public.ability_wikis;
create policy ability_wikis_update_owner_admin on public.ability_wikis for update to authenticated
using (public.bmth_is_admin() or exists (
 select 1 from public.characters c join public.profile p on p.id=c.profile_id
 where c.id=character_id and p.user_id=(select auth.uid())
))
with check (public.bmth_is_admin() or exists (
 select 1 from public.characters c join public.profile p on p.id=c.profile_id
 where c.id=character_id and p.user_id=(select auth.uid())
));
create policy ability_wikis_delete_owner_admin on public.ability_wikis for delete to authenticated
using (public.bmth_is_admin() or exists (
 select 1 from public.characters c join public.profile p on p.id=c.profile_id
 where c.id=character_id and p.user_id=(select auth.uid())
));

drop policy if exists characters_update_owner on public.characters;
drop policy if exists characters_delete_owner on public.characters;
drop policy if exists characters_update_owner_admin on public.characters;
drop policy if exists characters_delete_owner_admin on public.characters;
create policy characters_update_owner_admin on public.characters for update to authenticated
using (public.bmth_is_admin() or exists (
 select 1 from public.profile p where p.id=profile_id and p.user_id=(select auth.uid())
))
with check (public.bmth_is_admin() or exists (
 select 1 from public.profile p where p.id=profile_id and p.user_id=(select auth.uid())
));
create policy characters_delete_owner_admin on public.characters for delete to authenticated
using (public.bmth_is_admin() or exists (
 select 1 from public.profile p where p.id=profile_id and p.user_id=(select auth.uid())
));

-- RPC: XP adicionado de maneira atômica, sem sobrescrever progressão concorrente.
-- XP acumulado total preserva o excedente entre ranks D/C/B/A.
create or replace function public.bmth_grant_xp(p_character uuid, p_amount integer)
returns table(total_xp integer, new_rank text)
language plpgsql security definer set search_path = '' as $$
declare v_total integer; v_rank text;
begin
 if not public.bmth_is_admin() then raise exception 'Acesso administrativo negado'; end if;
 if p_amount is null or p_amount < 1 or p_amount > 10000 then raise exception 'Informe entre 1 e 10000 XP'; end if;
 if not exists(select 1 from public.characters where id=p_character) then raise exception 'Personagem não encontrado'; end if;
 -- Serializa concessões ao mesmo personagem mesmo quando a progressão ainda não existe.
 perform 1 from public.characters where id=p_character for update;
 select cp.xp into v_total from public.character_progression cp where cp.character_id=p_character;
 v_total:=coalesce(v_total,0)+p_amount;
 if v_total>1000000 then raise exception 'Limite de XP atingido'; end if;
 v_rank:=case when v_total>=300 then 'A' when v_total>=200 then 'B' when v_total>=100 then 'C' else 'D' end;
 insert into public.character_progression(character_id,rank,xp)
 values(p_character,v_rank,v_total)
 on conflict(character_id) do update set rank=excluded.rank,xp=excluded.xp;
 return query select v_total,v_rank;
end; $$;
revoke all on function public.bmth_grant_xp(uuid,integer) from public,anon;
grant execute on function public.bmth_grant_xp(uuid,integer) to authenticated;

-- Observação: PostgreSQL combina políticas permissivas por OR.
-- Revise políticas UPDATE/DELETE antigas caso tenha criado outras fora dos scripts BMTH.
