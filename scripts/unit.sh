#!/bin/bash
# scripts/unit.sh: one unit program of compiler/tests/units.txt, built by a fibc (the seed) and run from the root. It passes when the program
# exits 0 and prints no line that starts with FAIL. The module path is compiler/, compiler/tests/native (the programs' shared helpers) and
# compiler/tests/support (types.check); LLVM 21 is linked shared from LLVM_LIBDIR.
# usage: scripts/unit.sh FIBC FILE.fib OUTDIR        Exit 0 pass, 1 fail, 2 usage.
set -u
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root" || exit 2
fibc=${1:?usage: unit.sh FIBC FILE OUTDIR}; f=${2:?usage: unit.sh FIBC FILE OUTDIR}; out=${3:?usage: unit.sh FIBC FILE OUTDIR}
lib=${LLVM_LIBDIR:-/usr/lib/llvm-21/lib}
name=$(basename "$f" .fib); mkdir -p "$out"
"$fibc" build "$f" -I compiler -I compiler/tests/native -I compiler/tests/support -L "$lib" -l LLVM-21 -o "$out/$name" > "$out/$name.build" 2>&1 \
  || { tail -n 20 "$out/$name.build"; echo "FAIL $f: did not build"; exit 1; }
LD_LIBRARY_PATH=$lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} timeout 600 "$out/$name" > "$out/$name.out" 2>&1; st=$?
cat "$out/$name.out"
fails=$(grep -c '^FAIL' "$out/$name.out")
if [ "$st" -eq 0 ] && [ "$fails" -eq 0 ]; then echo "unit $name: pass ($(grep -c '^ok' "$out/$name.out") ok lines)"; exit 0; fi
echo "FAIL unit $name: exit $st, $fails FAIL lines"; exit 1
