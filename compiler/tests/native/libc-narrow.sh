#!/bin/bash
# The libc functions of a 32-bit target (compiler/lir/targets.fib `libc-narrow-names`, native.lower `add-declare`, native.lower.calls `narrow-args` and
# `widen-result`): lIR says `i64` for a `size_t`, a `long`, a `pthread_t` or an `unsigned long`; a 32-bit libc takes `i32`. For wasm32 the LLVM IR of a module that
# declares and calls the functions the runtime added after the first table (memmove, strtol, setvbuf, pthread_*, sched_getaffinity, prctl) is checked:
#   - the declaration has `i32` in every position lIR wrote `i64`, and in no other;
#   - a call narrows an `i64` argument to `i32` (saturating: a value over 4294967295 becomes -1, so a request too big fails instead of wrapping) and widens an `i32` result back;
#   - the functions without an `i64` (getrlimit, fdopen, fflush, sigaction, sigaltstack, pthread_attr_getstack, pthread_cond_signal) and `lseek`, whose `off_t` is a real
#     64-bit value, are declared as lIR wrote them;
#   - the same module on x86_64 is declared with `i64` throughout (the narrowing is the 32-bit targets' alone).
# usage: libc-narrow.sh    (LAIRF names lairf, default `lairf`; run from anywhere; LD_LIBRARY_PATH must reach libLLVM-21.so if it is not in the default path)
# Exit: 0 every check holds; 1 one fails; 2 no lairf.
set -u
lairf=${LAIRF:-lairf}
command -v "$lairf" >/dev/null 2>&1 || [ -x "$lairf" ] || { echo "libc-narrow: no lairf: set LAIRF" >&2; exit 2; }
export FIB_LIR_SPELLING=${FIB_LIR_SPELLING:-old}
T=$(mktemp -d "${TMPDIR:-/tmp}/libc-narrow.XXXXXX"); trap 'rm -rf "$T"' EXIT
bad=0
ok() { echo "ok   $*"; }
no() { echo "FAIL $*"; bad=1; }
cat > "$T/m.lir" <<'LIR'
(declare memmove ptr (ptr ptr i64))
(declare strtol i64 (ptr ptr i32))
(declare setvbuf i32 (ptr ptr i32 i64))
(declare pthread_attr_setguardsize i32 (ptr i64))
(declare pthread_getattr_np i32 (i64 ptr))
(declare pthread_join i32 (i64 ptr))
(declare pthread_self i64 ())
(declare sched_getaffinity i32 (i32 i64 ptr))
(declare prctl i32 (i32 ptr i64 i64 i64))
(declare getrlimit i32 (i32 ptr))
(declare fdopen ptr (i32 ptr))
(declare fflush i32 (ptr))
(declare sigaction i32 (i32 ptr ptr))
(declare sigaltstack i32 (ptr ptr))
(declare pthread_attr_getstack i32 (ptr ptr ptr))
(declare pthread_cond_signal i32 (ptr))
(declare lseek i64 (i32 i64 i32))
(define (use i64) ((ptr p) (i64 n))
  (block entry
    (let ((a (call @memmove p p n))
          (b (call @strtol p p (i32 10)))
          (c (call @setvbuf p p (i32 0) n))
          (d (call @pthread_attr_setguardsize p n))
          (e (call @pthread_getattr_np n p))
          (f (call @pthread_join n p))
          (g (call @pthread_self))
          (h (call @sched_getaffinity (i32 0) n p))
          (i (call @prctl (i32 15) p n n n))
          (j (call @lseek (i32 0) n (i32 1))))
      (ret (add b (add g j))))))
(define (main i32) () (block entry (ret (i32 0))))
LIR
# the declarations the 32-bit targets must print, and the ones every target prints
cat > "$T/want32" <<'LL'
declare ptr @memmove(ptr, ptr, i32)
declare i32 @strtol(ptr, ptr, i32)
declare i32 @setvbuf(ptr, ptr, i32, i32)
declare i32 @pthread_attr_setguardsize(ptr, i32)
declare i32 @pthread_getattr_np(i32, ptr)
declare i32 @pthread_join(i32, ptr)
declare i32 @pthread_self()
declare i32 @sched_getaffinity(i32, i32, ptr)
declare i32 @prctl(i32, ptr, i32, i32, i32)
LL
cat > "$T/same" <<'LL'
declare i32 @getrlimit(i32, ptr)
declare ptr @fdopen(i32, ptr)
declare i32 @fflush(ptr)
declare i32 @sigaction(i32, ptr, ptr)
declare i32 @sigaltstack(ptr, ptr)
declare i32 @pthread_attr_getstack(ptr, ptr, ptr)
declare i32 @pthread_cond_signal(ptr)
declare i64 @lseek(i32, i64, i32)
LL
sed -e 's/ptr @memmove(ptr, ptr, i32)/ptr @memmove(ptr, ptr, i64)/' -e 's/i32 @strtol(ptr, ptr, i32)/i64 @strtol(ptr, ptr, i32)/' \
    -e 's/@setvbuf(ptr, ptr, i32, i32)/@setvbuf(ptr, ptr, i32, i64)/' -e 's/@pthread_attr_setguardsize(ptr, i32)/@pthread_attr_setguardsize(ptr, i64)/' \
    -e 's/@pthread_getattr_np(i32, ptr)/@pthread_getattr_np(i64, ptr)/' -e 's/@pthread_join(i32, ptr)/@pthread_join(i64, ptr)/' \
    -e 's/i32 @pthread_self()/i64 @pthread_self()/' -e 's/@sched_getaffinity(i32, i32, ptr)/@sched_getaffinity(i32, i64, ptr)/' \
    -e 's/@prctl(i32, ptr, i32, i32, i32)/@prctl(i32, ptr, i64, i64, i64)/' "$T/want32" > "$T/want64"
check_triple() { # TRIPLE WANTFILE: every line of WANTFILE and of `same` is a declaration of the module's LLVM IR
  local t=$1 w=$2 ll="$T/$1.ll" n=0
  (ulimit -v 16000000; timeout 300 "$lairf" --target "$t" emit-llvm "$T/m.lir" > "$ll" 2> "$T/err") || { no "$t: emit-llvm failed: $(head -c 300 "$T/err")"; return 1; }
  while read -r line; do
    fn=${line#*@}; fn=${fn%%(*}
    if grep -qxF "$line" "$ll"; then n=$((n+1)); else no "$t: missing [$line]; the module declares [$(grep -F "@$fn(" "$ll" | head -1 | cut -c1-90)]"; fi
  done < <(cat "$w" "$T/same")
  [ $bad -eq 0 ] && ok "$t: $n declarations are as expected"
}
after() { grep -A1 -E "$1" "$2" | tail -1; }   # the line after the first line matching $1
calls32() { # the narrowing and widening at the calls, wasm32
  local ll="$T/$1.ll" c
  for c in 'call i32 @strtol' 'call i32 @pthread_self'; do
    after "$c" "$ll" | grep -qE 'sext i32 %[A-Za-z0-9_.]+ to i64' && ok "$1: the result of ${c#call i32 } is sign-extended to i64" || no "$1: no sext after [$c]: $(after "$c" "$ll")"
  done
  for c in 'call ptr @memmove\(ptr %p, ptr %p, i32 %[A-Za-z0-9_.]+\)' 'call i32 @pthread_attr_setguardsize\(ptr %p, i32 %[A-Za-z0-9_.]+\)' \
           'call i32 @pthread_join\(i32 %[A-Za-z0-9_.]+, ptr %p\)' 'call i32 @sched_getaffinity\(i32 0, i32 %[A-Za-z0-9_.]+, ptr %p\)'; do
    grep -qE "$c" "$ll" && ok "$1: an i64 argument is passed as i32 [${c%%\\(*}]" || no "$1: no call matching [$c]"
  done
  grep -qE 'select i1 %[A-Za-z0-9_.]+, i32 -1, i32 %[A-Za-z0-9_.]+' "$ll" && ok "$1: a narrowed argument saturates to -1" || no "$1: no saturating select"
  grep -qE 'call i64 @lseek\(i32 0, i64 %n, i32 1\)' "$ll" && ok "$1: lseek keeps its i64 off_t" || no "$1: lseek was narrowed"
}
for t in wasm32-wasip1 wasm32-unknown-unknown; do
  b=$bad; check_triple "$t" "$T/want32"; [ $bad -eq $b ] && calls32 "$t"
done
check_triple x86_64-unknown-linux-gnu "$T/want64"
[ $bad -eq 0 ] && echo "libc-narrow: every check holds"
exit $bad
