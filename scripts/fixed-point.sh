#!/bin/bash
# scripts/fixed-point.sh: lair compiles itself through lIR (the split plan, section 5). The seed emits lairf as an executable's lIR (`emit
# --exe`: without it `main` prints its result, and the rebuilt lairf fails most cases); the seed-built lairf (L1) builds that lIR into L2;
# then L1 and L2 must emit the same LLVM IR for it, and L2 must pass every case. The two binaries are not compared byte for byte: they differ
# (not investigated) and that is not proposed as a check.
# usage: scripts/fixed-point.sh SEED_FIBC LAIRF OUTDIR [JOBS]        Exit 0 when both hold, 1 when not, 2 for a usage error.
set -u
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root" || exit 2
seed=${1:?usage: fixed-point.sh SEED LAIRF OUT [JOBS]}; l1=${2:?usage}; out=${3:?usage}; jobs=${4:-4}
lib=${LLVM_LIBDIR:-/usr/lib/llvm-21/lib}
[ -x "$seed" ] && [ -x "$l1" ] || { echo "fixed-point: give the seed fibc and a lairf" >&2; exit 2; }
rm -rf "$out"; mkdir -p "$out"
t0=$(date +%s)
"$seed" emit --exe compiler/lairf.fib -I compiler > "$out/lairf.lir" 2> "$out/emit.err" || { tail -n 20 "$out/emit.err"; echo "FAIL fixed-point: the seed did not emit lairf"; exit 1; }
echo "emit: $(wc -c < "$out/lairf.lir") bytes of lIR, $(( $(date +%s) - t0 )) s"
t0=$(date +%s)
"$l1" --old-spelling build "$out/lairf.lir" -o "$out/lairf2" -O 2 -L "$lib" -l LLVM-21 > "$out/build.log" 2>&1 \
  || { tail -n 20 "$out/build.log"; echo "FAIL fixed-point: L1 did not build the lIR of lairf"; exit 1; }
echo "L1 builds L2: $(( $(date +%s) - t0 )) s"
"$l1" --old-spelling emit-llvm "$out/lairf.lir" > "$out/L1.ll" 2> "$out/L1.err" || { tail -n 5 "$out/L1.err"; echo "FAIL fixed-point: L1 emit-llvm"; exit 1; }
"$out/lairf2" --old-spelling emit-llvm "$out/lairf.lir" > "$out/L2.ll" 2> "$out/L2.err" || { tail -n 5 "$out/L2.err"; echo "FAIL fixed-point: L2 emit-llvm"; exit 1; }
if cmp -s "$out/L1.ll" "$out/L2.ll"; then echo "L1 == L2 at emit-llvm ($(wc -l < "$out/L1.ll") lines)"
else echo "FAIL fixed-point: L1 and L2 emit different LLVM IR for lairf's lIR: $(cmp "$out/L1.ll" "$out/L2.ll" 2>&1 | head -1)"; exit 1; fi
res=$("$out/lairf2" --old-spelling cases cases/lir -j "$jobs" 2>&1); st=$?
total=$(printf '%s\n' "$res" | grep '^total:' || true)
case "$st:$total" in
  0:*", 0 fail"*) echo "L2 cases: $total" ;;
  *) printf '%s\n' "$res" | grep '^FAIL' | head -n 10; echo "FAIL fixed-point: L2 on the cases (exit $st): ${total:-no total line}"; exit 1 ;;
esac
echo "PASS fixed-point"
