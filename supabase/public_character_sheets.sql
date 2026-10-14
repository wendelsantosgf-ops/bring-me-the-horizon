-- BMTH: fichas e progressão visíveis para todos os jogadores autenticados.
-- Mantém as políticas existentes de edição, exclusão e concessão de XP.
-- Execute no SQL Editor do Supabase. Não altera nem exclui registros.

alter table public.characters enable row level security;
alter table public.character_progression enable row level security;

grant select on public.characters to authenticated;
grant select on public.character_progression to authenticated;

drop policy if exists bmth_characters_public_read on public.characters;
create policy bmth_characters_public_read
on public.characters for select to authenticated
using (true);

drop policy if exists bmth_progression_public_read on public.character_progression;
create policy bmth_progression_public_read
on public.character_progression for select to authenticated
using (true);

-- Observação: 'public' aqui significa visível aos membros autenticados.
-- Edição e exclusão continuam sob as políticas de proprietário/admin.
