-- =====================================================================
-- Шаг 2.2. Row Level Security (CLAUDE.md, раздел 4).
--
-- Принцип: всё запрещено, пока явно не разрешено политикой.
-- Политики только для роли authenticated: anon (без входа) не видит ничего.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Вспомогательные функции в схеме private.
-- Схема private не доступна через API Supabase (там только public),
-- поэтому клиент не может вызвать эти функции напрямую.
-- security definer нужен, чтобы проверка членства не упиралась
-- в RLS самой таблицы circle_members (иначе бесконечная рекурсия).
-- ---------------------------------------------------------------------
create schema if not exists private;
grant usage on schema private to authenticated;

-- Является ли текущий пользователь участником круга.
create function private.is_circle_member(p_circle_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.circle_members m
    where m.circle_id = p_circle_id
      and m.user_id = (select auth.uid())
  );
$$;

-- Является ли текущий пользователь владельцем или админом круга.
create function private.is_circle_admin(p_circle_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.circle_members m
    where m.circle_id = p_circle_id
      and m.user_id = (select auth.uid())
      and m.role in ('owner', 'admin')
  );
$$;

-- Есть ли у текущего пользователя общий круг с другим пользователем.
create function private.shares_circle_with(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.circle_members mine
    join public.circle_members theirs on theirs.circle_id = mine.circle_id
    where mine.user_id = (select auth.uid())
      and theirs.user_id = p_user_id
  );
$$;

-- Активный (не забаненный) пользователь с профилем.
create function private.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and not p.is_banned
  );
$$;

-- Можно ли текущему пользователю проголосовать за p_target_id в раунде p_round_id:
-- раунд идёт прямо сейчас, и голосующий, и цель — участники круга этого раунда.
-- Голос за себя и повторный голос отсекают ограничения таблицы votes.
create function private.can_vote(p_round_id uuid, p_target_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_active_user()
    and exists (
      select 1
      from public.daily_rounds r
      join public.circle_members voter
        on voter.circle_id = r.circle_id and voter.user_id = (select auth.uid())
      join public.circle_members target
        on target.circle_id = r.circle_id and target.user_id = p_target_id
      where r.id = p_round_id
        and now() >= r.starts_at
        and now() < r.ends_at
    );
$$;

revoke all on all functions in schema private from public;
-- Генератор кода приглашения нужен authenticated как default колонки, но не anon.
revoke all on function public.generate_invite_code() from anon;
grant execute on all functions in schema private to authenticated;

-- ---------------------------------------------------------------------
-- Включаем RLS везде.
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.questions enable row level security;
alter table public.question_approvals enable row level security;
alter table public.daily_rounds enable row level security;
alter table public.votes enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;
alter table public.push_tokens enable row level security;

-- ---------------------------------------------------------------------
-- Права на таблицы. По умолчанию Supabase даёт anon/authenticated всё,
-- а RLS режет строки. Мы дополнительно убираем лишнее на уровне прав,
-- чтобы даже ошибка в политике не открыла данные.
-- ВАЖНО: в новых миграциях для новых таблиц права нужно выдавать так же явно.
-- ---------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;

grant select on public.profiles to authenticated;
-- Менять can_submit_questions и is_banned может только сервер.
grant insert (id, username, display_name, avatar_url, locale) on public.profiles to authenticated;
grant update (username, display_name, avatar_url, locale) on public.profiles to authenticated;

grant select, delete on public.circles to authenticated;
-- invite_code генерируется сервером, клиент его не задаёт и не меняет.
grant insert (name, owner_id, timezone) on public.circles to authenticated;
grant update (name, timezone) on public.circles to authenticated;

-- Вступление в круг — через RPC по коду приглашения (шаг «Круги»).
grant select, delete on public.circle_members to authenticated;

-- Вопросы создаёт только Edge Function submit-question (сервисный ключ).
grant select, delete on public.questions to authenticated;

grant select on public.question_approvals to authenticated;

grant select on public.daily_rounds to authenticated;

-- votes: только вставка. Ни select, ни update, ни delete.
grant insert (round_id, voter_id, target_id) on public.votes to authenticated;

grant select on public.reports to authenticated;
grant insert (reporter_id, question_id, reported_user_id, reason) on public.reports to authenticated;

grant select, delete on public.blocks to authenticated;
grant insert (blocker_id, blocked_id) on public.blocks to authenticated;

grant select, delete on public.push_tokens to authenticated;
grant insert (token, user_id, platform, updated_at) on public.push_tokens to authenticated;
grant update (platform, updated_at) on public.push_tokens to authenticated;

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------
-- profiles: видно себя и людей из общих кругов
create policy profiles_select_self_or_shared_circle
  on public.profiles for select
  to authenticated
  using (id = (select auth.uid()) or private.shares_circle_with(id));

-- profiles: создать можно только свой
create policy profiles_insert_own
  on public.profiles for insert
  to authenticated
  with check (id = (select auth.uid()));

-- profiles: менять можно только свой
create policy profiles_update_own
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- circles
-- ---------------------------------------------------------------------
-- owner_id нужен для insert ... returning: строка владельца в circle_members
-- появляется триггером уже после проверки этой политики.
-- circles: видно только свои круги
create policy circles_select_member
  on public.circles for select
  to authenticated
  using (private.is_circle_member(id) or owner_id = (select auth.uid()));

-- circles: создать может активный пользователь, владелец — он сам
create policy circles_insert_as_owner
  on public.circles for insert
  to authenticated
  with check (owner_id = (select auth.uid()) and private.is_active_user());

-- circles: менять название может владелец или админ
create policy circles_update_admin
  on public.circles for update
  to authenticated
  using (private.is_circle_admin(id))
  with check (private.is_circle_admin(id));

-- circles: удалить может только владелец
create policy circles_delete_owner
  on public.circles for delete
  to authenticated
  using (owner_id = (select auth.uid()));

-- Создатель круга автоматически становится его участником с ролью owner.
create function private.add_circle_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.owner_id is not null then
    insert into public.circle_members (circle_id, user_id, role)
    values (new.id, new.owner_id, 'owner');
  end if;
  return new;
end;
$$;

create trigger circles_add_owner
  after insert on public.circles
  for each row execute function private.add_circle_owner();

-- ---------------------------------------------------------------------
-- circle_members
-- ---------------------------------------------------------------------
-- circle_members: видно участников своих кругов
create policy circle_members_select_same_circle
  on public.circle_members for select
  to authenticated
  using (private.is_circle_member(circle_id));

-- Выйти из круга может любой, кроме владельца (иначе круг останется без хозяина).
-- Исключить участника (role = member) может владелец или админ (раздел 5).
-- circle_members: выйти самому или исключить участника
create policy circle_members_delete_leave_or_kick
  on public.circle_members for delete
  to authenticated
  using (
    (user_id = (select auth.uid()) and role <> 'owner')
    or (role = 'member' and private.is_circle_admin(circle_id))
  );

-- ---------------------------------------------------------------------
-- questions
-- ---------------------------------------------------------------------
-- Глобальные одобренные — всем вошедшим.
-- Вопросы круга — только его участникам: одобренные и ожидающие одобрения
-- (их надо видеть, чтобы одобрить). Скрытые/отклонённые — только автору и админам.
-- questions: глобальные одобренные и вопросы своих кругов
create policy questions_select_global_or_circle
  on public.questions for select
  to authenticated
  using (
    (circle_id is null and status = 'approved')
    or (
      circle_id is not null
      and private.is_circle_member(circle_id)
      and (
        status in ('approved', 'pending')
        or author_id = (select auth.uid())
        or private.is_circle_admin(circle_id)
      )
    )
  );

-- questions: админ круга может удалить вопрос круга
create policy questions_delete_circle_admin
  on public.questions for delete
  to authenticated
  using (circle_id is not null and private.is_circle_admin(circle_id));

-- ---------------------------------------------------------------------
-- question_approvals — пока только чтение своих.
-- Одобрение добавим на шаге модерации (вместе с логикой «2 одобрения»).
-- ---------------------------------------------------------------------
-- question_approvals: видно только свои
create policy question_approvals_select_own
  on public.question_approvals for select
  to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- daily_rounds — видят участники круга, и только уже начавшиеся раунды
-- (чтобы нельзя было подсмотреть вопрос заранее).
-- ---------------------------------------------------------------------
-- daily_rounds: начавшиеся раунды своих кругов
create policy daily_rounds_select_started_member
  on public.daily_rounds for select
  to authenticated
  using (private.is_circle_member(circle_id) and starts_at <= now());

-- ---------------------------------------------------------------------
-- votes — только вставка своего голоса. Политики на select НЕТ намеренно:
-- результаты отдаёт только RPC get_round_results.
-- ---------------------------------------------------------------------
-- votes: свой голос в активный раунд своего круга за участника круга
create policy votes_insert_own_active_round
  on public.votes for insert
  to authenticated
  with check (
    voter_id = (select auth.uid())
    and private.can_vote(round_id, target_id)
  );

-- ---------------------------------------------------------------------
-- reports — видно и создавать можно только свои.
-- Жаловаться можно только на то, что пользователь и так видит.
-- ---------------------------------------------------------------------
-- reports: видно только свои
create policy reports_select_own
  on public.reports for select
  to authenticated
  using (reporter_id = (select auth.uid()));

-- reports: создать свою жалобу
create policy reports_insert_own
  on public.reports for insert
  to authenticated
  with check (
    reporter_id = (select auth.uid())
    and (
      (question_id is not null and exists (
        select 1 from public.questions q where q.id = reports.question_id
      ))
      or (reported_user_id is not null and private.shares_circle_with(reported_user_id))
    )
  );

-- ---------------------------------------------------------------------
-- blocks — только свои.
-- ---------------------------------------------------------------------
-- blocks: видно только свои
create policy blocks_select_own
  on public.blocks for select
  to authenticated
  using (blocker_id = (select auth.uid()));

-- blocks: заблокировать от своего имени
create policy blocks_insert_own
  on public.blocks for insert
  to authenticated
  with check (blocker_id = (select auth.uid()));

-- blocks: разблокировать свою блокировку
create policy blocks_delete_own
  on public.blocks for delete
  to authenticated
  using (blocker_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- push_tokens — только свои.
-- ---------------------------------------------------------------------
-- push_tokens: видно свои
create policy push_tokens_select_own
  on public.push_tokens for select
  to authenticated
  using (user_id = (select auth.uid()));

-- push_tokens: добавить свой
create policy push_tokens_insert_own
  on public.push_tokens for insert
  to authenticated
  with check (user_id = (select auth.uid()));

-- push_tokens: обновить свой
create policy push_tokens_update_own
  on public.push_tokens for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- push_tokens: удалить свой
create policy push_tokens_delete_own
  on public.push_tokens for delete
  to authenticated
  using (user_id = (select auth.uid()));
