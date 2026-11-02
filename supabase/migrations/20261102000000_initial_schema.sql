-- Brikkin Content Engine: initial database tables
-- Run once in Supabase: SQL Editor -> New query -> paste -> Run.
-- Every table is private per user (Row Level Security): people only see their own rows.

-- 1. Personas / brand voices (Persona tab)
create table if not exists public.personas (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name        text not null,
  kind        text,                      -- creator, brand, founder, etc.
  data        jsonb not null default '{}'::jsonb,  -- full persona profile
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- 2. Audits: every script / campaign audit and its result
create table if not exists public.audits (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  persona_id    uuid references public.personas (id) on delete set null,
  audit_type    text not null check (audit_type in ('script', 'campaign')),
  content_type  text,                    -- reel script, carousel, OOH, 360 launch, ...
  goal          text,
  input_text    text not null,
  score         smallint check (score between 0 and 100),
  verdict       text,
  flagged_words text[] not null default '{}',
  report        jsonb not null default '{}'::jsonb,  -- full proof report
  revised_text  text,
  created_at    timestamptz not null default now()
);

-- 3. Settings: custom banned words and other per-user preferences
create table if not exists public.user_settings (
  user_id       uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  banned_words  text[] not null default '{}',
  skills        jsonb not null default '[]'::jsonb,
  updated_at    timestamptz not null default now()
);

-- 4. Content performance: how published posts actually did
create table if not exists public.content_posts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  audit_id      uuid references public.audits (id) on delete set null,
  title         text not null,
  platform      text,                    -- instagram, linkedin, youtube, ...
  format        text,                    -- reel, carousel, static, ...
  pillar        text,
  post_url      text,
  published_on  date,
  views         integer default 0,
  reach         integer default 0,
  likes         integer default 0,
  comments      integer default 0,
  shares        integer default 0,
  saves         integer default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists audits_user_created_idx   on public.audits (user_id, created_at desc);
create index if not exists personas_user_idx         on public.personas (user_id);
create index if not exists content_posts_user_idx    on public.content_posts (user_id, published_on desc);

-- Keep updated_at current
create or replace function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists personas_touch on public.personas;
create trigger personas_touch before update on public.personas
  for each row execute function public.touch_updated_at();
drop trigger if exists user_settings_touch on public.user_settings;
create trigger user_settings_touch before update on public.user_settings
  for each row execute function public.touch_updated_at();
drop trigger if exists content_posts_touch on public.content_posts;
create trigger content_posts_touch before update on public.content_posts
  for each row execute function public.touch_updated_at();

-- Row Level Security: each signed-in user can only read and change their own rows
alter table public.personas      enable row level security;
alter table public.audits        enable row level security;
alter table public.user_settings enable row level security;
alter table public.content_posts enable row level security;

drop policy if exists "own personas" on public.personas;
create policy "own personas" on public.personas
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "own audits" on public.audits;
create policy "own audits" on public.audits
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "own settings" on public.user_settings;
create policy "own settings" on public.user_settings
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "own posts" on public.content_posts;
create policy "own posts" on public.content_posts
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
