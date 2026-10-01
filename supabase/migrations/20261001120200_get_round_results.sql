-- =====================================================================
-- Шаг 2.3. RPC get_round_results — единственный способ узнать результаты.
--
-- Возвращает только агрегаты: target_id + количество голосов.
-- voter_id наружу не уходит никогда (CLAUDE.md, раздел 2, п. 2).
-- Доступ: только участник круга этого раунда, который уже проголосовал.
-- =====================================================================

create function public.get_round_results(round_id uuid)
returns table (target_id uuid, votes_count integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  -- Одна проверка на всё: раунд существует, пользователь в круге и уже голосовал.
  -- Не различаем причины отказа, чтобы не подсказывать, существует ли раунд.
  if v_uid is null or not exists (
    select 1
    from public.daily_rounds r
    join public.circle_members m
      on m.circle_id = r.circle_id and m.user_id = v_uid
    join public.votes v
      on v.round_id = r.id and v.voter_id = v_uid
    where r.id = get_round_results.round_id
  ) then
    raise exception 'not_allowed'
      using errcode = '42501',
            hint = 'Results are available only to circle members who voted in this round';
  end if;

  return query
    select v.target_id, count(*)::integer as votes_count
    from public.votes v
    where v.round_id = get_round_results.round_id
    group by v.target_id
    order by votes_count desc, v.target_id;
end;
$$;

revoke all on function public.get_round_results(uuid) from public, anon;
grant execute on function public.get_round_results(uuid) to authenticated;
