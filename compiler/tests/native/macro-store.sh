#!/bin/bash
# compiler/tests/native/macro-store.sh: the object files of macro sessions kept on disk between programs (native.jit.store). With a store
# of its own (FIB_LIRO_CACHE), cases/lir/macros/cache.lir is run cold (its modules compiled and stored), warm (every one taken from the
# store: no check, no code generation), then with every stored file holding another module's key (each refused: compiled again), and
# with FIB_LIRO_CACHE=off (nothing stored); its output must be the case's every time.
# usage: macro-store.sh LAIRF        Exit 0 when every run is as said, 1 when not, 2 for a usage error.
set -u
root=$(cd "$(dirname "$0")/../../.." && pwd); cd "$root" || exit 2
lairf=${1:?usage: macro-store.sh LAIRF}
[ -x "$lairf" ] || { echo "macro-store: no lairf at $lairf" >&2; exit 2; }
dir=$(mktemp -d "${TMPDIR:-/tmp}/macro-store.XXXXXX"); trap 'rm -rf "$dir"' EXIT
store=$dir/cache/macro-objects
want=$'1 2 1 2\n2 20'
bad=0
# run NAME [CACHE]: the case run once, its output and FIB_TIME lines kept as DIR/NAME.out and DIR/NAME.err
run() {
  FIB_LIRO_CACHE=${2:-$dir/cache} FIB_TIME=1 "$lairf" --old-spelling run cases/lir/macros/cache.lir > "$dir/$1.out" 2> "$dir/$1.err"
  if [ "$(cat "$dir/$1.out")" = "$want" ]; then echo "ok $1: output"; else echo "FAIL $1: output $(tr '\n' '|' < "$dir/$1.out")"; bad=1; fi
}
phase() { grep -c "^time lir.macros.$2 " "$dir/$1.err"; }
expect() { # NAME TEXT CONDITION
  if eval "$3"; then echo "ok $1: $2"; else echo "FAIL $1: $2"; bad=1; fi
}

run cold
stored=$(ls "$store"/*.lo 2>/dev/null | wc -l)
expect cold "modules compiled ($(phase cold jit.codegen) sessions) and $stored stored" '[ "$(phase cold jit.codegen)" -gt 0 ] && [ "$stored" -gt 0 ]'

run warm
expect warm "taken from the store ($(phase warm jit.store-load) sessions), none checked or generated" \
  '[ "$(phase warm jit.store-load)" -gt 0 ] && [ "$(phase warm jit.check)" -eq 0 ] && [ "$(phase warm jit.codegen)" -eq 0 ]'

# every file now holds the key and object of another: the store must refuse each and compile again
files=("$store"/*.lo)
if [ "${#files[@]}" -ge 2 ]; then
  cp "${files[0]}" "$dir/first"
  for ((i = 0; i < ${#files[@]} - 1; i++)); do cp "${files[$((i + 1))]}" "${files[$i]}"; done
  cp "$dir/first" "${files[$(( ${#files[@]} - 1 ))]}"
fi
run swapped
expect swapped "every file refused, modules compiled again ($(phase swapped jit.codegen) sessions)" '[ "$(phase swapped jit.codegen)" -gt 0 ]'

run off off
expect off "no store under FIB_LIRO_CACHE=off: modules compiled ($(phase off jit.codegen) sessions), none loaded" \
  '[ "$(phase off jit.store-load)" -eq 0 ] && [ "$(phase off jit.codegen)" -gt 0 ]'

[ "$bad" -eq 0 ] && echo "macro-store: pass" && exit 0
echo "macro-store: FAIL"; exit 1
