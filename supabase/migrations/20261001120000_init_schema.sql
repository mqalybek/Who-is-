-- =====================================================================
-- Шаг 2.1. Таблицы, ограничения и индексы (CLAUDE.md, раздел 4).
-- RLS и политики — в следующей миграции.
-- =====================================================================

-- ---------------------------------------------------------------------
-- profiles — публичный профиль пользователя. id = auth.users.id.
-- Строку создаёт сам пользователь на экране онбординга (выбор ника).
-- ---------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique
    check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name text
    check (char_length(display_name) between 1 and 40),
  avatar_url text
    check (char_length(avatar_url) <= 500),
  locale text not null default 'ru'
    check (locale in ('ru', 'kk')),
  can_submit_questions boolean not null default true,
  is_banned boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- circles — «круг» друзей.
-- owner_id может стать null, если владелец удалил аккаунт
-- (передачу владения решим на шаге с удалением аккаунта).
-- ---------------------------------------------------------------------

-- Короткий код приглашения: 8 символов без похожих (0/O, 1/I/L).
create function public.generate_invite_code()
returns text
language sql
volatile
set search_path = ''
as $$
  select string_agg(
    substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789', 1 + floor(random() * 31)::int, 1),
    ''
  )
  from generate_series(1, 8);
$$;

create table public.circles (
  id uuid primary key default gen_random_uuid(),
  name text not null
    check (char_length(btrim(name)) between 1 and 40),
  invite_code text not null unique default public.generate_invite_code()
    check (invite_code ~ '^[A-Z0-9]{6,12}$'),
  owner_id uuid references public.profiles (id) on delete set null,
  timezone text not null default 'Asia/Almaty',
  created_at timestamptz not null default now()
);

create index circles_owner_id_idx on public.circles (owner_id);

-- ---------------------------------------------------------------------
-- circle_members — кто в каком круге и с какой ролью.
-- ---------------------------------------------------------------------
create table public.circle_members (
  circle_id uuid not null references public.circles (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member'
    check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

-- PK уже даёт индекс по (circle_id, user_id); этот — для «мои круги».
create index circle_members_user_id_idx on public.circle_members (user_id);

-- ---------------------------------------------------------------------
-- questions — вопросы «Кто из нас…?».
-- system: глобальные (circle_id = null), без автора, обязательно с паком.
-- user:   предложены участником, привязаны к кругу.
-- ---------------------------------------------------------------------
create table public.questions (
  id uuid primary key default gen_random_uuid(),
  text_ru text
    check (char_length(text_ru) between 3 and 200),
  text_kk text
    check (char_length(text_kk) between 3 and 200),
  pack text
    check (pack in ('friends', 'toi', 'school', 'work', 'future', 'warm')),
  source text not null
    check (source in ('system', 'user')),
  author_id uuid references public.profiles (id) on delete set null,
  circle_id uuid references public.circles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'hidden')),
  report_count integer not null default 0
    check (report_count >= 0),
  created_at timestamptz not null default now(),

  -- Хотя бы один язык должен быть заполнен.
  constraint questions_has_text check (text_ru is not null or text_kk is not null),
  -- Системные вопросы: без автора, глобальные, с паком.
  constraint questions_system_shape check (
    source <> 'system' or (author_id is null and circle_id is null and pack is not null)
  ),
  -- Пользовательские вопросы всегда принадлежат кругу.
  constraint questions_user_shape check (source <> 'user' or circle_id is not null)
);

create index questions_circle_status_idx on public.questions (circle_id, status);
create index questions_author_id_idx on public.questions (author_id);
create index questions_global_approved_idx on public.questions (pack)
  where circle_id is null and status = 'approved';

-- ---------------------------------------------------------------------
-- question_approvals — одобрения пользовательских вопросов.
-- ---------------------------------------------------------------------
create table public.question_approvals (
  question_id uuid not null references public.questions (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (question_id, user_id)
);

create index question_approvals_user_id_idx on public.question_approvals (user_id);

-- ---------------------------------------------------------------------
-- daily_rounds — «вопрос дня» в конкретном круге.
-- ---------------------------------------------------------------------
create table public.daily_rounds (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete cascade,
  round_date date not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  constraint daily_rounds_time_order check (ends_at > starts_at),
  constraint daily_rounds_one_per_day unique (circle_id, round_date)
);

create index daily_rounds_question_id_idx on public.daily_rounds (question_id);

-- ---------------------------------------------------------------------
-- votes — голоса. Клиенты НИКОГДА не читают эту таблицу напрямую.
-- ---------------------------------------------------------------------
create table public.votes (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.daily_rounds (id) on delete cascade,
  voter_id uuid not null references public.profiles (id) on delete cascade,
  target_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint votes_one_per_round unique (round_id, voter_id),
  constraint votes_not_self check (voter_id <> target_id)
);

-- Для подсчёта результатов раунда: group by target_id.
create index votes_round_target_idx on public.votes (round_id, target_id);
create index votes_voter_id_idx on public.votes (voter_id);
create index votes_target_id_idx on public.votes (target_id);

-- ---------------------------------------------------------------------
-- reports — жалобы на вопрос или на пользователя.
-- Причина — из фиксированного списка: свободного текста между людьми нет.
-- ---------------------------------------------------------------------
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  question_id uuid references public.questions (id) on delete cascade,
  reported_user_id uuid references public.profiles (id) on delete cascade,
  reason text not null
    check (reason in ('offensive', 'appearance', 'bullying', 'spam', 'other')),
  status text not null default 'open'
    check (status in ('open', 'confirmed', 'rejected')),
  created_at timestamptz not null default now(),
  -- Жалоба ровно на что-то одно: либо на вопрос, либо на человека.
  constraint reports_one_target check (num_nonnulls(question_id, reported_user_id) = 1),
  constraint reports_not_self check (reported_user_id is null or reported_user_id <> reporter_id)
);

create index reports_reporter_id_idx on public.reports (reporter_id);
create index reports_question_id_idx on public.reports (question_id);
create index reports_reported_user_id_idx on public.reports (reported_user_id);

-- ---------------------------------------------------------------------
-- blocks — кто кого заблокировал.
-- ---------------------------------------------------------------------
create table public.blocks (
  blocker_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  primary key (blocker_id, blocked_id),
  constraint blocks_not_self check (blocker_id <> blocked_id)
);

create index blocks_blocked_id_idx on public.blocks (blocked_id);

-- ---------------------------------------------------------------------
-- push_tokens — Expo push-токены устройств.
-- Один токен = одно устройство, поэтому token — первичный ключ.
-- ---------------------------------------------------------------------
create table public.push_tokens (
  token text primary key
    check (char_length(token) between 10 and 255),
  user_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  platform text not null
    check (platform in ('ios', 'android')),
  updated_at timestamptz not null default now()
);

create index push_tokens_user_id_idx on public.push_tokens (user_id);
