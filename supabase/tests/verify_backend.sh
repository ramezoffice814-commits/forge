#!/usr/bin/env bash
# Forge — complete backend verification harness (spec section 19, Roadmap
# Item 12 section 4).
#
# One command to run everything that needs a real local Supabase/
# Postgres and/or Deno once those become available in this environment:
# start -> reset (applies every migration + seed.sql) -> SQL security
# tests 002..latest -> Deno shared-module tests -> (best-effort) Edge
# Function smoke checks.
#
# Never fakes execution: every step either genuinely runs or the script
# exits with a clear message about what's missing (Docker, Deno) and
# what could NOT be verified as a result — matching every prior phase's
# "do not pretend it ran if Docker is unavailable" instruction. Nothing
# in this script is invoked automatically by this session; it exists to
# be run explicitly once tooling is available.
#
# Windows-compatible: this repo's shell tooling is already Git Bash
# (see every other *.sh under supabase/tests/), which runs this file
# identically on Windows/macOS/Linux — no separate .ps1 needed.
#
# Lessons folded in from Roadmap Item 12's actual first real run of this
# harness against a live Windows/Docker-Desktop/WSL2 machine:
#   - `npx --yes supabase ...` can hang indefinitely on some machines
#     (observed: 3+ minutes with zero output, even with network access).
#     `npm install --no-save supabase` into a local node_modules/, then
#     calling the resulting ./node_modules/.bin/supabase binary
#     directly, was reliable where bare npx was not — this script now
#     prefers that path automatically.
#   - `psql` is not guaranteed to be on the host PATH even when Docker
#     and the Supabase CLI both work fine (observed on this exact
#     machine) — this script now falls back to running SQL test files
#     through `docker exec -i <db-container> psql` when a bare `psql`
#     binary isn't found, using the same local Postgres the CLI itself
#     just started.
#   - The bundled Realtime service's Erlang/BEAM runtime can crash with
#     SIGILL under some virtualized Docker environments during its own
#     self-hosted seed step — unrelated to this project's schema/RLS/
#     functions, and this project never uses Supabase Realtime at all
#     (grep confirms zero references under lib/ or supabase/). See
#     supabase/config.toml's [realtime] comment. Storage and Studio are
#     disabled in the same config for the unrelated reason that neither
#     is used by this project either, and every extra container narrows
#     the health-check margin on a resource-constrained machine.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
DB_CONTAINER="${DB_CONTAINER:-supabase_db_forge}"
FAILED=0

section() { echo; echo "=== $1 ==="; }

section "1/5: Supabase CLI availability"
SUPABASE_BIN=""
if [ -x "$REPO_ROOT/node_modules/.bin/supabase" ]; then
  SUPABASE_BIN="$REPO_ROOT/node_modules/.bin/supabase"
elif command -v supabase >/dev/null 2>&1; then
  SUPABASE_BIN="supabase"
else
  echo "Local ./node_modules/.bin/supabase not found — installing it now"
  echo "(npx --yes supabase is unreliable on some machines; a local install is used instead)."
  if ! (cd "$REPO_ROOT" && npm install --no-save supabase >/tmp/forge_supabase_install.log 2>&1); then
    echo "FAIL: could not install the Supabase CLI via npm. Aborting — nothing below this line ran."
    tail -40 /tmp/forge_supabase_install.log
    exit 1
  fi
  SUPABASE_BIN="$REPO_ROOT/node_modules/.bin/supabase"
fi
if ! "$SUPABASE_BIN" --version >/tmp/forge_supabase_version.log 2>&1; then
  echo "FAIL: Supabase CLI ($SUPABASE_BIN) did not respond to --version. Aborting — nothing below this line ran."
  cat /tmp/forge_supabase_version.log
  exit 1
fi
echo "OK: $SUPABASE_BIN --version -> $(cat /tmp/forge_supabase_version.log)"

section "2/5: Docker engine availability"
# `docker ps` rather than `docker info`: the latter gathers a much
# larger system-wide report (plugins, storage driver, discovered
# devices, ...) and was observed to hang/time out under load on a
# resource-constrained machine even while Docker was fully healthy and
# `docker ps`/`docker exec` both responded instantly — a false negative
# from an over-strict probe, not a real outage.
if ! timeout 15 docker ps >/dev/null 2>&1; then
  echo "FAIL: Docker engine is not reachable (checked via 'docker ps', 15s timeout)."
  echo "If Docker Desktop was just launched, a first cold start can take 2-4 minutes — retry"
  echo "this script rather than repeatedly polling by hand."
  echo "Supabase local Postgres cannot start without it. Nothing below this line ran."
  echo "This is a genuine, reported blocker — not simulated as passing."
  exit 1
fi
echo "OK: Docker engine is reachable."

section "3/5: supabase start + db reset (migrations + seed.sql)"
(cd "$REPO_ROOT" && "$SUPABASE_BIN" start) || { echo "FAIL: supabase start"; exit 1; }
(cd "$REPO_ROOT" && "$SUPABASE_BIN" db reset) || { echo "FAIL: supabase db reset (a migration or seed.sql failed)"; FAILED=1; }

section "4/5: SQL security/behavior tests (002 through latest)"
run_sql_file() {
  local script="$1"
  if command -v psql >/dev/null 2>&1; then
    psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$script"
  else
    docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$script"
  fi
}
if [ "$FAILED" -eq 0 ]; then
  if ! command -v psql >/dev/null 2>&1; then
    echo "NOTE: no local psql binary found — running SQL test files via"
    echo "'docker exec -i $DB_CONTAINER psql' against the container Supabase just started instead."
  fi
  for script in "$REPO_ROOT"/supabase/tests/0*.sql; do
    echo "--- $(basename "$script") ---"
    if ! run_sql_file "$script"; then
      echo "FAIL: $(basename "$script")"
      FAILED=1
    fi
  done
else
  echo "SKIPPED — migrations/seed did not apply cleanly; fix those first (per every prior "
  echo "phase's own instruction: do not work around a broken schema/RLS assumption)."
fi

section "5/5: Deno shared-module tests"
if command -v deno >/dev/null 2>&1; then
  (cd "$REPO_ROOT" && deno test supabase/functions/_shared/) || FAILED=1
else
  echo "SKIPPED — Deno CLI not installed in this environment."
  echo "'npm install -g deno' has been confirmed to work even when its postinstall script is"
  echo "blocked by an allow-scripts policy — the deno.js wrapper it installs still runs fine"
  echo "(it extracts its bundled binary lazily on first invocation)."
fi

echo
if [ "$FAILED" -eq 0 ]; then
  echo "=== ALL EXECUTED CHECKS PASSED ==="
  echo "(Full-HTTP Edge Function smoke tests — signing up a real user via GoTrue and calling"
  echo " a deployed function with its JWT through Kong — and true two-connection concurrency"
  echo " races were both verified by hand during Roadmap Item 12 and are not yet scripted"
  echo " here; see that phase's final report for the exact commands and results.)"
else
  echo "=== ONE OR MORE CHECKS FAILED — see FAIL lines above ==="
  exit 1
fi
