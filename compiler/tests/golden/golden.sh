#!/bin/bash
# The golden checks of lairf: each suite of suites.sh runs lairf on its inputs and compares the output and exit status of every input with
# the golden recorded in this directory (NAME.golden, inputs in NAME.files). Adapted from fibber's golden.sh (fibber ce3d8314): the lairf
# rows only, one process per input, no slots. After an intended change, regenerate with --update and read the diff in git before committing.
# usage: compiler/tests/golden/golden.sh [--update [--rescan]] [--only SUITE..] [--tools DIR | --fibc F]
#        compiler/tests/golden/golden.sh --show SUITE FILE [--tools DIR | --fibc F]     lairf's output for one input
#   --tools DIR  a directory holding lairf
#   --fibc F     (default: FIBC) builds lairf into $GOLDEN_OUT/tools first
#   --rescan     with --update: take every file the suite's globs match now as its inputs
# Environment: GOLDEN_OUT scratch (default $TMPDIR/golden), LLVM_LIBDIR. The emitted IR is for FIB_TARGET_CPU=x86-64-v2, as recorded.
# Prints `ok SUITE (N inputs)` or `FAIL SUITE: first differing line` for each suite; exit 0 only if none failed; 2 for a usage error.
set -u
export FIB_LIR_SPELLING=${FIB_LIR_SPELLING:-old}
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
. "$here/suites.sh"
show=; showf=; update=0; rescan=0; only=(); tools=; fibc=${FIBC:-}
while [ $# -gt 0 ]; do
  case $1 in
    --update) update=1 ;;
    --rescan) rescan=1 ;;
    --only) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do only+=("$1"); shift; done; continue ;;
    --tools) tools=${2:?--tools DIR}; shift ;;
    --fibc) fibc=${2:?--fibc F}; shift ;;
    --show) show=${2:?--show SUITE FILE}; showf=${3:?--show SUITE FILE}; shift 2 ;;
    *) echo "usage: golden.sh [--update [--rescan]] [--only SUITE..] [--tools DIR | --fibc F]" >&2; exit 2 ;;
  esac
  shift
done
out=${GOLDEN_OUT:-${TMPDIR:-/tmp}/golden}; mkdir -p "$out"
export FIB_TARGET_CPU=x86-64-v2
lib=${LLVM_LIBDIR:-/usr/lib/llvm-21/lib}
export LD_LIBRARY_PATH=$lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
cd "$root" || exit 2
if [ -z "$tools" ]; then
  [ -x "$fibc" ] || { echo "golden: give --tools DIR or --fibc F (or FIBC)" >&2; exit 2; }
  tools=$out/tools; mkdir -p "$tools"
  "$fibc" build compiler/lairf.fib -I compiler -L "$lib" -l LLVM-21 -o "$tools/lairf" > "$tools/lairf.log" 2>&1 \
    || { tail -n 20 "$tools/lairf.log"; echo "golden: lairf did not build" >&2; exit 2; }
fi

# block TOOL OPTIONS FILE BLOCKFILE: one input's block (the `#### FILE` line, the output, the `status N` line) in BLOCKFILE
block() {
  # shellcheck disable=SC2086
  { echo "#### $3"; (ulimit -v 8000000; timeout 600 "$tools/$1" $2 "$3" 2>&1; echo "status $?") | sed "s|$root|<root>|g"; } > "$4"
}

if [ -n "$show" ]; then
  while IFS='|' read -r name tool opts _rust _globs; do
    if [ "$name" = "$show" ]; then block "$tool" "$opts" "$showf" "$out/block"; cat "$out/block"; exit 0; fi
  done < <(suite_table)
  echo "golden: no suite $show" >&2; exit 2
fi

# run_suite NAME TOOL OPTIONS GLOBS: one suite; prints its line, returns 1 if it failed
run_suite() {
  local name=$1 tool=$2 opts=$3 globs=$4 files=$here/$1.files gold=$here/$1.golden new=$out/$1.new f
  if [ "$rescan" -eq 1 ]; then
    # shellcheck disable=SC2086
    ls -1 $globs 2>/dev/null | LC_ALL=C sort > "$files"
  fi
  [ -f "$files" ] && { [ -f "$gold" ] || [ "$update" -eq 1 ]; } || { echo "FAIL $name: no golden ($name.golden)"; return 1; }
  : > "$new"
  while read -r f; do block "$tool" "$opts" "$f" "$out/block.$name"; cat "$out/block.$name" >> "$new"; done < "$files"
  if [ "$update" -eq 1 ]; then cp "$new" "$gold"; echo "updated $name ($(wc -l < "$files") inputs)"; return 0; fi
  if cmp -s "$new" "$gold"; then echo "ok $name ($(wc -l < "$files") inputs)"; return 0; fi
  echo "FAIL $name: $(diff "$gold" "$new" | grep -m1 '^[<>]' | cut -c1-160)"; diff "$gold" "$new" | head -8; return 1
}

bad=0
while IFS='|' read -r name tool opts _rust globs; do
  [ -z "$name" ] && continue
  if [ ${#only[@]} -gt 0 ] && [[ " ${only[*]} " != *" $name "* ]]; then continue; fi
  run_suite "$name" "$tool" "$opts" "$globs" || bad=1
done < <(suite_table)
exit $bad
