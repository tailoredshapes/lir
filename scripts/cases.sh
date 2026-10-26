#!/bin/bash
# scripts/cases.sh: lair's cases, every directory of cases/lir, with the old spelling admitted (spec/lir.md 2, transitional). The cases that do
# not pass must be exactly those listed in scripts/cases.expected (one path per line; `#` starts a comment), as fibber's ci-stage2.expected.
# usage: scripts/cases.sh LAIRF [JOBS]        Exit 0 when the set of failing cases equals the list, 1 when not, 2 for a usage error.
set -u
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root" || exit 2
lairf=${1:?usage: cases.sh LAIRF [JOBS]}; jobs=${2:-4}
[ -x "$lairf" ] || { echo "cases: no lairf at $lairf" >&2; exit 2; }
out=$(mktemp -d "${TMPDIR:-/tmp}/cases.XXXXXX"); trap 'rm -rf "$out"' EXIT
"$lairf" --old-spelling cases cases/lir -j "$jobs" > "$out/rows" 2>&1; st=$?
total=$(grep '^total:' "$out/rows" || true)
[ -n "$total" ] || { echo "FAIL cases: no total line (lairf exit $st)"; tail -n 20 "$out/rows"; exit 1; }
grep -v '^ok ' "$out/rows" | grep -v ' cases, ' || true
echo "$total"
grep '^FAIL ' "$out/rows" | sed -E 's/^FAIL +//; s/: .*//' | LC_ALL=C sort > "$out/got"
grep -v '^#' scripts/cases.expected | grep -v '^[[:space:]]*$' | LC_ALL=C sort > "$out/want"
if ! cmp -s "$out/got" "$out/want"; then
  echo "FAIL cases: the failing cases differ from scripts/cases.expected (< expected, > got):"; diff "$out/want" "$out/got"; exit 1
fi
echo "cases: the failing cases are those of scripts/cases.expected ($(wc -l < "$out/want"))"
