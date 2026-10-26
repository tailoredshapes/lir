#!/bin/bash
# The table of the runtime's C functions (compiler/lir/targets.fib) is complete. fibber's runtime is lIR text, rt/*.lir, and declares the C functions it calls;
# the table `runtime-c-functions` lists them (the wasm32-unknown-unknown, nvptx64 and wgsl rows lack all of them; a row's `libc-lacks` names from it) and
# `libc-narrow-names` the ones whose `i64` is a `size_t`, `long` or `pthread_t` that a 32-bit libc takes as `i32`. Copied from fibber's
# compiler/tests/native/targets-emit.sh, section 0 (fibber 139e374a), and extended:
#   1. `runtime-c-functions` is exactly the `(DECLARE name ..)`s of RT/*.lir;
#   2. every function of rt that declares an `i64` is in `libc-narrow-names`, or is one of REAL64 (a real 64-bit value: `lseek`'s `off_t`), so a new declare
#      is classified when it is added and a 32-bit target does not call it with a word of the wrong width;
#   3. every name of `libc-narrow-names` and of every `libc-lacks` is a runtime C function or one the library declares (LIBRARY below) -- a name that no
#      table row mentions cannot have been checked.
# usage: runtime-fns.sh RT_DIR    (fibber's rt/, read only; TARGETS names another targets.fib, default compiler/lir/targets.fib of this tree)
# Exit: 0 every check holds; 1 one fails; 2 no rt directory or no table.
set -u
export LC_ALL=C
here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/../../.." && pwd)
rt=${1:-}; targets=${TARGETS:-$root/compiler/lir/targets.fib}
[ -n "$rt" ] && ls "$rt"/*.lir > /dev/null 2>&1 || { echo "runtime-fns: usage: runtime-fns.sh RT_DIR (fibber's rt/, with its *.lir)" >&2; exit 2; }
[ -f "$targets" ] || { echo "runtime-fns: no table at $targets" >&2; exit 2; }
REAL64="lseek"
LIBRARY="fcntl fmemopen ftell getcwd getentropy poll readlink recv recvfrom send sendto setbuf"   # in libc-narrow-names for the library's own declares, not rt's
T=$(mktemp -d "${TMPDIR:-/tmp}/runtime-fns.XXXXXX"); trap 'rm -rf "$T"' EXIT
bad=0
ok() { echo "ok   $*"; }
no() { echo "FAIL $*"; bad=1; }
rt_decls() { grep -ho '^(DECLARE [^ ]*' "$rt"/*.lir | awk '{print $2}' | sort -u; }
# the quoted names of the defun NAME of the table, comments left out
names_of() { sed -n "/^(defun $1 /,/^\$/p" "$targets" | grep -v '^[[:space:]]*;;' | grep -o '"[^"]*"' | tr -d '"' | sort -u; }
names_of runtime-c-functions > "$T/table"; names_of libc-narrow-names > "$T/narrow"
[ -s "$T/table" ] && [ -s "$T/narrow" ] || { echo "runtime-fns: found no runtime-c-functions or libc-narrow-names in $targets" >&2; exit 2; }
# 1. the table is the declares
if diff <(rt_decls) "$T/table" > "$T/d"; then ok "runtime-c-functions is exactly the $(rt_decls | wc -l) declares of $rt/*.lir"
else no "runtime-c-functions and rt/*.lir differ (< rt declares, > table): $(tr '\n' ' ' < "$T/d")"; fi
# 2. a declare with an i64 is narrowed or real 64-bit
i64_decls() { grep -h '^(DECLARE ' "$rt"/*.lir | grep -E '\bI64\b' | awk '{print $2}' | sort -u; }
unclassified=$(comm -23 <(i64_decls) <(sort -u "$T/narrow" <(tr ' ' '\n' <<< "$REAL64"))); 
[ -z "$unclassified" ] && ok "every rt declare with an I64 ($(i64_decls | wc -l)) is in libc-narrow-names or REAL64 ($REAL64)" \
  || no "rt declares an I64 in functions neither in libc-narrow-names nor REAL64: $(tr '\n' ' ' <<< "$unclassified")"
wrong=$(comm -12 "$T/narrow" <(tr ' ' '\n' <<< "$REAL64" | sort -u)); [ -z "$wrong" ] || no "REAL64 names a narrowed function: $wrong"
# 3. nothing in the narrow list or in libc-lacks is unknown
lacks=$(sed -n '/^(defun row-/,/^$/p' "$targets" | grep -oE '\[("[a-z_0-9]+" ?)+\]' | grep -o '"[^"]*"' | tr -d '"' | sort -u)
known=$(sort -u "$T/table" <(tr ' ' '\n' <<< "$LIBRARY"))
stray=$(comm -23 <(sort -u "$T/narrow" <(printf '%s\n' $lacks)) <(printf '%s\n' $known))
[ -z "$stray" ] && ok "libc-narrow-names and every libc-lacks name a runtime C function or LIBRARY's" || no "named in libc-narrow-names or libc-lacks and nowhere in the runtime: $(tr '\n' ' ' <<< "$stray")"
[ $bad -eq 0 ] && echo "runtime-fns: every check holds"
exit $bad
