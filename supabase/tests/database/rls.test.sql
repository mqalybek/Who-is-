-- =====================================================================
-- Тесты RLS и get_round_results. Запуск: npm run db:test
-- Всё внутри транзакции и откатывается в конце — база не меняется.
--
-- Действующие лица:
--   Алия (owner)  — создала круг «Класс»
--   Бек, Дана     — участники «Класса»
--   Чужой         — не состоит в «Классе», у него свой круг
-- =====================================================================
begin;

select plan(32);

-- ---------------------------------------------------------------------
-- Помощники: «войти» под пользователем / выйти в анонимы / вернуться в админа.
-- ---------------------------------------------------------------------
create function pg_temp.login_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end;
$$;

create function pg_temp.login_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  perform set_config('request.jwt.claim.sub', '', true);
  execute 'set local role anon';
end;
$$;

create function pg_temp.logout() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
end;
$$;

-- ---------------------------------------------------------------------
-- Данные (создаём от имени суперпользователя, RLS не мешает).
-- ---------------------------------------------------------------------
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'aliya@test.kz'),
  ('00000000-0000-0000-0000-00000000000b', 'bek@test.kz'),
  ('00000000-0000-0000-0000-00000000000d', 'dana@test.kz'),
  ('00000000-0000-0000-0000-0000000000ff', 'stranger@test.kz');

insert into public.profiles (id, username) values
  ('00000000-0000-0000-0000-00000000000a', 'aliya'),
  ('00000000-0000-0000-0000-00000000000b', 'bek'),
  ('00000000-0000-0000-0000-00000000000d', 'dana'),
  ('00000000-0000-0000-0000-0000000000ff', 'stranger');

-- Владелец добавляется в circle_members триггером.
insert into public.circles (id, name, owner_id) values
  ('c0000000-0000-0000-0000-000000000001', 'Класс', '00000000-0000-0000-0000-00000000000a'),
  ('c0000000-0000-0000-0000-000000000002', 'Чужой круг', '00000000-0000-0000-0000-0000000000ff');

insert into public.circle_members (circle_id, user_id) values
  ('c0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b'),
  ('c0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000d');

insert into public.questions (id, text_ru, pack, source, status) values
  ('a0000000-0000-0000-0000-000000000001', 'Кто из нас лучше всех танцует?', 'friends', 'system', 'approved');

insert into public.questions (id, text_ru, source, author_id, circle_id, status) values
  ('a0000000-0000-0000-0000-000000000002', 'Кто из нас первым придёт на урок?', 'user',
   '00000000-0000-0000-0000-00000000000b', 'c0000000-0000-0000-0000-000000000001', 'approved'),
  ('a0000000-0000-0000-0000-000000000003', 'Кто из нас скрытый вопрос?', 'user',
   '00000000-0000-0000-0000-00000000000d', 'c0000000-0000-0000-0000-000000000001', 'hidden');

-- Активный раунд (идёт сейчас) и будущий раунд (ещё не начался).
insert into public.daily_rounds (id, circle_id, question_id, round_date, starts_at, ends_at) values
  ('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001',
   'a0000000-0000-0000-0000-000000000001', current_date, now() - interval '1 hour', now() + interval '1 hour'),
  ('d0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001',
   'a0000000-0000-0000-0000-000000000002', current_date + 1, now() + interval '1 day', now() + interval '2 days');

-- =====================================================================
-- 1. Чужой пользователь не видит круг и его вопросы
-- =====================================================================
select pg_temp.login_as('00000000-0000-0000-0000-0000000000ff');

select is_empty(
  $$ select 1 from public.circles where id = 'c0000000-0000-0000-0000-000000000001' $$,
  'Чужой не видит чужой круг'
);
select is_empty(
  $$ select 1 from public.circle_members where circle_id = 'c0000000-0000-0000-0000-000000000001' $$,
  'Чужой не видит участников чужого круга'
);
select is_empty(
  $$ select 1 from public.questions where circle_id = 'c0000000-0000-0000-0000-000000000001' $$,
  'Чужой не видит вопросы чужого круга'
);
select is_empty(
  $$ select 1 from public.daily_rounds where circle_id = 'c0000000-0000-0000-0000-000000000001' $$,
  'Чужой не видит раунды чужого круга'
);
select is_empty(
  $$ select 1 from public.profiles where id = '00000000-0000-0000-0000-00000000000a' $$,
  'Чужой не видит профили людей, с которыми у него нет общего круга'
);
select results_eq(
  $$ select id from public.circles $$,
  $$ values ('c0000000-0000-0000-0000-000000000002'::uuid) $$,
  'Чужой видит только свой круг'
);
select results_eq(
  $$ select id from public.questions $$,
  $$ values ('a0000000-0000-0000-0000-000000000001'::uuid) $$,
  'Чужой видит только глобальные одобренные вопросы'
);
-- update чужого круга просто не находит строк — проверяем, что название не изменилось.
select pg_temp.login_as('00000000-0000-0000-0000-0000000000ff');
update public.circles set name = 'Взломано' where id = 'c0000000-0000-0000-0000-000000000001';
select pg_temp.logout();
select is(
  (select name from public.circles where id = 'c0000000-0000-0000-0000-000000000001'),
  'Класс',
  'Чужой не может переименовать чужой круг'
);

-- =====================================================================
-- 2. Участник видит свой круг; скрытые вопросы видны только автору
-- =====================================================================
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');

select results_eq(
  $$ select id from public.circles $$,
  $$ values ('c0000000-0000-0000-0000-000000000001'::uuid) $$,
  'Участник видит свой круг'
);
select results_eq(
  $$ select count(*)::int from public.circle_members where circle_id = 'c0000000-0000-0000-0000-000000000001' $$,
  $$ values (3) $$,
  'Участник видит всех участников своего круга'
);
select results_eq(
  $$ select id from public.questions where circle_id is not null $$,
  $$ values ('a0000000-0000-0000-0000-000000000002'::uuid) $$,
  'Участник видит одобренный вопрос круга, но не чужой скрытый'
);
select results_eq(
  $$ select id from public.daily_rounds $$,
  $$ values ('d0000000-0000-0000-0000-000000000001'::uuid) $$,
  'Участник видит начавшийся раунд, но не будущий'
);
select throws_ok(
  $$ update public.profiles set is_banned = false where id = '00000000-0000-0000-0000-00000000000b' $$,
  '42501', null,
  'Пользователь не может сам менять is_banned'
);
select pg_temp.logout();

-- =====================================================================
-- 3. Таблицу votes нельзя прочитать напрямую
-- =====================================================================
insert into public.votes (round_id, voter_id, target_id) values
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');

select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
select throws_ok(
  $$ select * from public.votes $$,
  '42501', null,
  'Участник круга не может читать votes'
);
select throws_ok(
  $$ select count(*) from public.votes $$,
  '42501', null,
  'Участник круга не может даже посчитать строки в votes'
);
select throws_ok(
  $$ update public.votes set target_id = voter_id $$,
  '42501', null,
  'Голоса нельзя менять'
);
select throws_ok(
  $$ delete from public.votes $$,
  '42501', null,
  'Голоса нельзя удалять'
);
select pg_temp.logout();

select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
select throws_ok(
  $$ select * from public.votes $$,
  '42501', null,
  'Даже владелец круга не может читать votes'
);
select pg_temp.logout();

select pg_temp.login_anon();
select throws_ok(
  $$ select * from public.votes $$,
  '42501', null,
  'Аноним не может читать votes'
);
select throws_ok(
  $$ select * from public.circles $$,
  '42501', null,
  'Аноним не может читать circles'
);
select pg_temp.logout();

-- =====================================================================
-- 4. Ограничения голосования
-- =====================================================================
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');

select throws_ok(
  $$ insert into public.votes (round_id, voter_id, target_id) values
     ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000b') $$,
  '23514', null,
  'Нельзя проголосовать за себя'
);
select lives_ok(
  $$ insert into public.votes (round_id, voter_id, target_id) values
     ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000d') $$,
  'Можно проголосовать за участника своего круга'
);
select throws_ok(
  $$ insert into public.votes (round_id, voter_id, target_id) values
     ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a') $$,
  '23505', null,
  'Нельзя проголосовать дважды в одном раунде'
);
select throws_ok(
  $$ insert into public.votes (round_id, voter_id, target_id) values
     ('d0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a') $$,
  '42501', null,
  'Нельзя голосовать в раунде, который ещё не начался'
);
select pg_temp.logout();

select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
select throws_ok(
  $$ insert into public.votes (round_id, voter_id, target_id) values
     ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-0000000000ff') $$,
  '42501', null,
  'Нельзя проголосовать за человека не из круга'
);
select throws_ok(
  $$ insert into public.votes (round_id, voter_id, target_id) values
     ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b') $$,
  '42501', null,
  'Нельзя проголосовать от чужого имени'
);
select pg_temp.logout();

select pg_temp.login_as('00000000-0000-0000-0000-0000000000ff');
select throws_ok(
  $$ insert into public.votes (round_id, voter_id, target_id) values
     ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000ff', '00000000-0000-0000-0000-00000000000a') $$,
  '42501', null,
  'Чужой не может голосовать в раунде чужого круга'
);
select pg_temp.logout();

-- =====================================================================
-- 5. get_round_results
-- Сейчас голоса: Алия → Бек, Бек → Дана. Дана не голосовала.
-- =====================================================================
select is(
  pg_get_function_result('public.get_round_results(uuid)'::regprocedure),
  'TABLE(target_id uuid, votes_count integer)',
  'RPC возвращает только target_id и количество — без voter_id'
);

select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
select results_eq(
  $$ select target_id, votes_count from public.get_round_results('d0000000-0000-0000-0000-000000000001') order by target_id $$,
  $$ values ('00000000-0000-0000-0000-00000000000b'::uuid, 1), ('00000000-0000-0000-0000-00000000000d'::uuid, 1) $$,
  'Проголосовавший участник видит агрегированные результаты'
);
select pg_temp.logout();

select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
select throws_ok(
  $$ select * from public.get_round_results('d0000000-0000-0000-0000-000000000001') $$,
  '42501', 'not_allowed',
  'Участник, который ещё не голосовал, результаты не видит'
);
select pg_temp.logout();

select pg_temp.login_as('00000000-0000-0000-0000-0000000000ff');
select throws_ok(
  $$ select * from public.get_round_results('d0000000-0000-0000-0000-000000000001') $$,
  '42501', 'not_allowed',
  'Чужой не видит результаты раунда чужого круга'
);
select pg_temp.logout();

select pg_temp.login_anon();
select throws_ok(
  $$ select * from public.get_round_results('d0000000-0000-0000-0000-000000000001') $$,
  '42501', null,
  'Аноним не может вызвать get_round_results'
);
select pg_temp.logout();

select * from finish();
rollback;
