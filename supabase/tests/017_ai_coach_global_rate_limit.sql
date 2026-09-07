-- Roadmap Item 14C: forge_check_and_increment_ai_coach_global_usage
-- behavior (allowed under cap, rejected + self-rolled-back over cap) and
-- its server-only access boundary (anon/authenticated get permission
-- denied, matching every other forge_* internal function in this
-- project). No per-user state is involved — this is a single global
-- daily counter — so no auth.users/mission fixtures are needed.

begin;

do $$
declare
  caught boolean;
  allowed boolean;
  v_count integer;
begin
  set local role postgres;

  -- Start from a clean slate for today's row regardless of what earlier
  -- tests in the same run may have touched.
  delete from public.ai_coach_daily_usage where usage_date = current_date;

  -- (1) First three calls under a cap of 3 are all allowed, and the
  -- counter increments by exactly one per call.
  allowed := public.forge_check_and_increment_ai_coach_global_usage(3);
  if not allowed then
    raise exception 'FAIL: 1st call under cap=3 was rejected';
  end if;
  select request_count into v_count from public.ai_coach_daily_usage where usage_date = current_date;
  if v_count <> 1 then
    raise exception 'FAIL: expected request_count=1 after 1st call, got %', v_count;
  end if;

  allowed := public.forge_check_and_increment_ai_coach_global_usage(3);
  allowed := public.forge_check_and_increment_ai_coach_global_usage(3);
  select request_count into v_count from public.ai_coach_daily_usage where usage_date = current_date;
  if v_count <> 3 then
    raise exception 'FAIL: expected request_count=3 after 3 calls, got %', v_count;
  end if;
  raise notice 'PASS: three calls under cap=3 all allowed, counter reaches 3';

  -- (2) A 4th call against the same cap=3 is rejected, and its own
  -- increment is rolled back — the counter stays at 3, not 4.
  allowed := public.forge_check_and_increment_ai_coach_global_usage(3);
  if allowed then
    raise exception 'FAIL: 4th call exceeded cap=3 but was still allowed';
  end if;
  select request_count into v_count from public.ai_coach_daily_usage where usage_date = current_date;
  if v_count <> 3 then
    raise exception 'FAIL: a rejected call was not rolled back — expected request_count=3, got %', v_count;
  end if;
  raise notice 'PASS: call over cap is rejected and costs no quota (counter stays at 3)';

  -- (3) A later, separate call with a higher cap in the same day
  -- resumes counting from the existing total, not from zero.
  allowed := public.forge_check_and_increment_ai_coach_global_usage(10);
  if not allowed then
    raise exception 'FAIL: call under a raised cap=10 (current count 3) was rejected';
  end if;
  select request_count into v_count from public.ai_coach_daily_usage where usage_date = current_date;
  if v_count <> 4 then
    raise exception 'FAIL: expected request_count=4 after raising the cap, got %', v_count;
  end if;
  raise notice 'PASS: the daily counter persists and accumulates across calls with different caps';

  delete from public.ai_coach_daily_usage where usage_date = current_date;

  -- --- access boundary: authenticated cannot call this directly ------
  reset role;
  set local role authenticated;

  caught := false;
  begin
    perform public.forge_check_and_increment_ai_coach_global_usage(1000);
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error (authenticated calling the RPC): %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: authenticated could call forge_check_and_increment_ai_coach_global_usage directly';
  end if;
  raise notice 'PASS: authenticated cannot call forge_check_and_increment_ai_coach_global_usage directly';

  -- --- access boundary: anon cannot call this directly ----------------
  reset role;
  set local role anon;

  caught := false;
  begin
    perform public.forge_check_and_increment_ai_coach_global_usage(1000);
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error (anon calling the RPC): %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: anon could call forge_check_and_increment_ai_coach_global_usage directly';
  end if;
  raise notice 'PASS: anon cannot call forge_check_and_increment_ai_coach_global_usage directly';

  -- --- access boundary: neither role can read/write the table directly
  reset role;
  set local role authenticated;

  caught := false;
  begin
    perform 1 from public.ai_coach_daily_usage limit 1;
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error (authenticated selecting ai_coach_daily_usage): %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: authenticated could SELECT ai_coach_daily_usage directly';
  end if;
  raise notice 'PASS: authenticated cannot SELECT ai_coach_daily_usage directly';
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 017_ai_coach_global_rate_limit.sql'; end $$;

rollback;
