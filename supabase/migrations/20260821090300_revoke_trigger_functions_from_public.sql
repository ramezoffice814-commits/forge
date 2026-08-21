-- Roadmap Item 13: follow-up to 20260821090200 — handle_new_user and
-- handle_new_user_progression still had EXECUTE granted to the PUBLIC
-- pseudo-role (Postgres's default for any newly created function,
-- never explicitly revoked by their original Phase 10B migrations,
-- unlike every later function which does revoke-then-grant). Revoking
-- from the specific `anon`/`authenticated` roles in 20260821090200 was
-- not sufficient on its own: a PUBLIC grant applies to every role
-- regardless of that role's own individual grants/revokes, so anon/
-- authenticated could still reach these via the PUBLIC path until this
-- migration. Confirmed via information_schema.routine_privileges
-- before and after (see Roadmap Item 13's final report).

revoke execute on function public.handle_new_user() from public;
revoke execute on function public.handle_new_user_progression() from public;
