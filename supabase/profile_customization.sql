-- Personalização visual individual dos perfis
create table if not exists public.profile_customization (
  profile_id uuid primary key references public.profile(id) on delete cascade,
  accent_color text not null default '#d03951'
    check (accent_color ~ '^#[0-9A-Fa-f]{6}$'),
  background_url text
    check (background_url is null or (length(background_url) <= 2048 and background_url ~ '^https://')),
  tagline text not null default ''
    check (char_length(tagline) <= 140),
  custom_cards jsonb not null default '[]'::jsonb
    check (jsonb_typeof(custom_cards) = 'array' and jsonb_array_length(custom_cards) <= 4 and pg_column_size(custom_cards) <= 6000),
  updated_at timestamptz not null default now()
);
alter table public.profile_customization enable row level security;
drop policy if exists "Everyone signed in can view profile themes" on public.profile_customization;
create policy "Everyone signed in can view profile themes"
on public.profile_customization for select to authenticated using (true);
drop policy if exists "Owners create profile themes" on public.profile_customization;
create policy "Owners create profile themes"
on public.profile_customization for insert to authenticated
with check (exists (select 1 from public.profile p where p.id=profile_id and p.user_id=(select auth.uid())));
drop policy if exists "Owners update profile themes" on public.profile_customization;
create policy "Owners update profile themes"
on public.profile_customization for update to authenticated
using (exists (select 1 from public.profile p where p.id=profile_id and p.user_id=(select auth.uid())))
with check (exists (select 1 from public.profile p where p.id=profile_id and p.user_id=(select auth.uid())));
