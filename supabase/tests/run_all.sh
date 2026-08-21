#!/usr/bin/env bash
# Runs every RLS/security test script against a local Supabase Postgres
# in order, stopping at the first failure. Assumes `supabase start` has
# already been run (or any local Postgres reachable at DB_URL with these
# migrations + seed.sql applied).
set -euo pipefail

DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for script in "$DIR"/0*.sql; do
  echo "=== running $(basename "$script") ==="
  psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$script"
done

echo "=== all RLS/security test scripts passed ==="
