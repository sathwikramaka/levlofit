#!/usr/bin/env bash
# Local verification runner with compact output: one line per step, full log tail only on failure.
# Usage (repo root): bash tools/verify.sh [handbook] [functions] [deno] [db] [flutter] [website]   (no args = all but db)
# Read-only apart from build caches; never touches a remote project. Mirrors .github/workflows/ci.yml plus local DB tests.
set -u
cd "$(dirname "$0")/.." || exit 2
ROOT=$(pwd)
DENO=${DENO:-$(command -v deno || echo "$HOME/.deno/bin/deno.exe")}
FLUTTER=${FLUTTER:-$(command -v flutter || echo /c/flutter/bin/flutter)}
LOG=$(mktemp)
fail=0

step() {  # step <label> <summary-grep> <command...>
  local label=$1 pat=$2; shift 2
  local t0=$SECONDS
  if "$@" >"$LOG" 2>&1; then
    local s; s=$(grep -E "$pat" "$LOG" | tail -1 | tr -s ' ')
    printf 'PASS %-34s %3ss  %s\n' "$label" $((SECONDS - t0)) "${s:0:90}"
  else
    fail=$((fail + 1))
    printf 'FAIL %-34s %3ss\n' "$label" $((SECONDS - t0))
    tail -40 "$LOG" | sed 's/^/     /'
  fi
}

F=supabase/functions
handbook() {
  step "handbook: register tests" '^(Ran|OK)' python -I data/evidence/test_extract_claims.py
  step "food data: FDC builder tests" '^(Ran|OK)' python -I data/fdc/test_build_foods_fdc.py
  step "handbook: freshness --check" 'reviewed' python -I data/evidence/extract_claims.py --check
  # Builder output must equal the working-tree migration (the builder rewrites it; a difference means it was stale).
  step "handbook: migration matches builder" 'identical' bash -c 'M=supabase/migrations/20261007400000_handbook_v3.sql; B=$(mktemp); cp "$M" "$B";
    python -I data/build_handbook.py >/dev/null && if cmp -s "$M" "$B"; then echo identical; rm -f "$B"; else echo "migration was stale; builder output written, old copy at $B"; exit 1; fi'
}
handbook4() {  # Handbook v4 book draft (data/handbook_v4): builds the draft only, never the production migration
  step "handbook4: draft book tests" '^(Ran|OK)' python -I data/handbook_v4/test_book.py
}
functions() {
  step "functions: node tests" '^# pass' node --test $F/_shared/plan-engine.test.ts $F/_shared/llm.test.ts $F/_shared/body-check.test.ts $F/_shared/handbook.test.ts \
    $F/coach-chat/coach-chat.test.ts $F/delete-account/delete-account.test.ts $F/generate-plan/generate-plan.test.ts $F/_eval/eval.test.ts tools/release_docs.test.mjs
  step "functions: offline eval" '^strict:' node $F/_eval/run.ts
  step "functions: strict tsc" '.' bash -c "website/node_modules/.bin/tsc --noEmit --strict --target es2022 --module esnext --moduleResolution bundler \
    --allowImportingTsExtensions --resolveJsonModule --lib es2022,dom --types node --typeRoots website/node_modules/@types \
    $F/_shared/*.ts $F/_eval/personas.ts $F/_eval/score.ts $F/_eval/cases.ts && echo clean"
}
deno_() {
  step "deno: check" 'Check' bash -c "cd $F && '$DENO' check --lock=_test/deno.lock --frozen coach-chat/index.ts generate-plan/index.ts delete-account/index.ts body-check/index.ts"
  step "deno: lint" 'Checked' bash -c "cd $F && '$DENO' lint coach-chat/index.ts generate-plan/index.ts delete-account/index.ts body-check/index.ts _shared/body-check.ts _shared/coach-context.ts _shared/llm.ts _shared/handbook.ts _shared/rate.ts _shared/plan-engine.ts _shared/swap.ts _shared/meal.ts _test/deno-smoke.ts"
  step "deno: smoke (127.0.0.1 only)" 'passed' bash -c "cd $F && '$DENO' run --lock=_test/deno.lock --frozen --allow-env --allow-read --allow-net=127.0.0.1 _test/deno-smoke.ts"
}
db() { step "db: supabase test db (LOCAL)" 'Result|Tests=' supabase test db; }
flutter_() {
  step "flutter: analyze" 'issues|No issues' bash -c "cd app && '$FLUTTER' analyze --no-pub"
  step "flutter: test" 'All tests passed|[0-9]+:[0-9]+ \+[0-9]+' bash -c "cd app && '$FLUTTER' test --no-pub"
}
website() {
  step "website: lint" '.' bash -c 'cd website && npm run -s lint && echo clean'
  # Build first: next build writes the route types (.next/types) that tsc needs on a clean checkout.
  step "website: build" 'Compiled|Route' bash -c 'cd website && NEXT_TELEMETRY_DISABLED=1 npm run -s build'
  step "website: tsc" '.' bash -c 'cd website && npx --no-install tsc --noEmit --incremental false && echo clean'
}

suites=("$@"); [ ${#suites[@]} -eq 0 ] && suites=(handbook functions deno flutter website)
for s in "${suites[@]}"; do
  case $s in
    handbook) handbook ;; handbook4) handbook4 ;; functions) functions ;; deno) deno_ ;; db) db ;; flutter) flutter_ ;; website) website ;;
    *) echo "unknown suite: $s"; exit 2 ;;
  esac
done
rm -f "$LOG"
echo "== $fail failed step(s) =="
[ $fail -eq 0 ]
