-- Cura database schema for Supabase.
--
-- Paste this whole file into Supabase: SQL Editor -> New query -> Run.
-- It is safe to run more than once.
--
-- The model:
--   profiles            one row per person who signs up (family or caregiver)
--   caregiver_profiles  a caregiver's public listing: where they work, how far
--                       they travel, specialties, languages
--   circles             one "care circle" per loved one. Everyone caring for that
--                       person, near or far, is a member of the same circle.
--   circle_members      who is in which circle (family or caregiver)
--   invites             a family asking a caregiver to join their circle
--   entries             everything the circle shares: notes, comments, daily
--                       check-ins and messages
--
-- Row Level Security means the database itself enforces who can see what. A
-- person only ever sees circles they belong to, and a caregiver's exact home
-- address is never stored, only a rounded work area.

create extension if not exists pgcrypto;

-- ── Tables ─────────────────────────────────────────────────

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('family', 'caregiver')),
  name text not null,
  phone text not null default '',
  language text not null default 'en',
  relationship text,
  created_at timestamptz not null default now()
);

create table if not exists public.caregiver_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  -- Shown in search. The phone number stays private in profiles.
  display_name text not null,
  headline text not null default '',
  bio text not null default '',
  hourly_rate numeric not null default 0,
  years_experience int not null default 1,
  specialties text[] not null default '{}',
  languages text[] not null default '{}',
  -- Rounded to roughly 1 km so a caregiver's exact address is never exposed.
  area_label text not null default '',
  lat double precision not null,
  lng double precision not null,
  service_radius_km numeric not null default 15,
  available boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.circles (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles (id) on delete cascade,
  -- The loved one's care profile (Memory Care Passport) as JSON.
  pnc jsonb not null,
  -- Short code other relatives type in to join this circle.
  join_code text not null unique default upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 6)),
  created_at timestamptz not null default now()
);

create table if not exists public.circle_members (
  circle_id uuid not null references public.circles (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null check (role in ('family', 'caregiver')),
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

create table if not exists public.invites (
  id text primary key,
  circle_id uuid not null references public.circles (id) on delete cascade,
  family_id uuid not null references public.profiles (id) on delete cascade,
  caregiver_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  data jsonb not null,
  created_at timestamptz not null default now(),
  responded_at timestamptz
);

create table if not exists public.entries (
  id text primary key,
  circle_id uuid not null references public.circles (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('note', 'comment', 'quiz', 'message')),
  data jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists entries_circle_idx on public.entries (circle_id, created_at desc);
create index if not exists invites_caregiver_idx on public.invites (caregiver_id);
create index if not exists invites_circle_idx on public.invites (circle_id);
create index if not exists members_user_idx on public.circle_members (user_id);

-- ── Helpers (security definer so policies don't recurse) ───

create or replace function public.is_member(c uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from circle_members where circle_id = c and user_id = auth.uid());
$$;

create or replace function public.is_family_member(c uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from circle_members where circle_id = c and user_id = auth.uid() and role = 'family');
$$;

-- You can see someone's profile if it is you, you share a circle, or there is
-- an invite between you.
create or replace function public.can_see_profile(p uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p = auth.uid()
    or exists (
      select 1 from circle_members a join circle_members b on a.circle_id = b.circle_id
      where a.user_id = auth.uid() and b.user_id = p)
    or exists (
      select 1 from invites i
      where (i.family_id = auth.uid() and i.caregiver_id = p)
         or (i.caregiver_id = auth.uid() and i.family_id = p));
$$;

-- ── Row Level Security ─────────────────────────────────────

alter table public.profiles enable row level security;
alter table public.caregiver_profiles enable row level security;
alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.invites enable row level security;
alter table public.entries enable row level security;

drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles for select to authenticated
  using (public.can_see_profile(id));
drop policy if exists "profiles write own" on public.profiles;
create policy "profiles write own" on public.profiles for insert to authenticated
  with check (id = auth.uid());
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Caregiver listings are a public directory for signed-in users.
drop policy if exists "listings read" on public.caregiver_profiles;
create policy "listings read" on public.caregiver_profiles for select to authenticated using (true);
drop policy if exists "listings insert own" on public.caregiver_profiles;
create policy "listings insert own" on public.caregiver_profiles for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists "listings update own" on public.caregiver_profiles;
create policy "listings update own" on public.caregiver_profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "circles read" on public.circles;
create policy "circles read" on public.circles for select to authenticated
  using (public.is_member(id) or created_by = auth.uid());
drop policy if exists "circles create" on public.circles;
create policy "circles create" on public.circles for insert to authenticated
  with check (created_by = auth.uid());
drop policy if exists "circles update" on public.circles;
create policy "circles update" on public.circles for update to authenticated
  using (public.is_family_member(id)) with check (public.is_family_member(id));

drop policy if exists "members read" on public.circle_members;
create policy "members read" on public.circle_members for select to authenticated
  using (public.is_member(circle_id));
-- Members are only ever added by the functions below, never directly.

drop policy if exists "invites read" on public.invites;
create policy "invites read" on public.invites for select to authenticated
  using (caregiver_id = auth.uid() or public.is_member(circle_id));
drop policy if exists "invites create" on public.invites;
create policy "invites create" on public.invites for insert to authenticated
  with check (family_id = auth.uid() and public.is_family_member(circle_id) and status = 'pending');
drop policy if exists "invites update" on public.invites;
create policy "invites update" on public.invites for update to authenticated
  using (caregiver_id = auth.uid() or public.is_family_member(circle_id));

drop policy if exists "entries read" on public.entries;
create policy "entries read" on public.entries for select to authenticated
  using (public.is_member(circle_id));
drop policy if exists "entries create" on public.entries;
create policy "entries create" on public.entries for insert to authenticated
  with check (author_id = auth.uid() and public.is_member(circle_id));
drop policy if exists "entries update own" on public.entries;
create policy "entries update own" on public.entries for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());
drop policy if exists "entries delete own" on public.entries;
create policy "entries delete own" on public.entries for delete to authenticated
  using (author_id = auth.uid());

-- ── Functions the app calls ───────────────────────────────

-- Create a circle for a loved one and make the creator its first member.
create or replace function public.create_circle(pnc jsonb)
returns public.circles language plpgsql security definer set search_path = public as $$
declare c circles;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into circles (created_by, pnc) values (auth.uid(), pnc) returning * into c;
  insert into circle_members (circle_id, user_id, role) values (c.id, auth.uid(), 'family');
  return c;
end $$;

-- A relative joins an existing circle with its code.
create or replace function public.join_circle(code text)
returns public.circles language plpgsql security definer set search_path = public as $$
declare c circles;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into c from circles where join_code = upper(trim(code));
  if c.id is null then raise exception 'No care circle has that code.'; end if;
  insert into circle_members (circle_id, user_id, role) values (c.id, auth.uid(), 'family')
    on conflict do nothing;
  return c;
end $$;

-- When a caregiver accepts an invite, they join the circle automatically.
create or replace function public.on_invite_answered()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    insert into circle_members (circle_id, user_id, role)
      values (new.circle_id, new.caregiver_id, 'caregiver')
      on conflict do nothing;
  end if;
  if new.status is distinct from old.status then
    new.responded_at := now();
  end if;
  return new;
end $$;

drop trigger if exists invite_answered on public.invites;
create trigger invite_answered before update on public.invites
  for each row execute function public.on_invite_answered();

-- The caregiver can only change the status of their own invite, not its terms.
create or replace function public.guard_invite_update()
returns trigger language plpgsql as $$
begin
  if auth.uid() = old.caregiver_id and not public.is_family_member(old.circle_id) then
    if new.data is distinct from old.data or new.circle_id <> old.circle_id
       or new.family_id <> old.family_id or new.caregiver_id <> old.caregiver_id then
      raise exception 'Caregivers can only accept or decline.';
    end if;
    if new.status not in ('accepted', 'declined') then
      raise exception 'Caregivers can only accept or decline.';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists invite_guard on public.invites;
create trigger invite_guard before update on public.invites
  for each row execute function public.guard_invite_update();

grant execute on function public.create_circle(jsonb) to authenticated;
grant execute on function public.join_circle(text) to authenticated;

-- ── Live updates ──────────────────────────────────────────

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin alter publication supabase_realtime add table public.entries; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.invites; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.circles; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.circle_members; exception when duplicate_object then null; end;
end $$;
