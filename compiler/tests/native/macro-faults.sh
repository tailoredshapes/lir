#!/bin/bash
# The planted faults of a macro's module (spec/lir.md 4.6): what it declares (native.macros.declares), the program's object files a
# session adds it from (native.jit `session-add-module-keyed`, native.jit.objects) and the program's memo of library forms
# (native.macros.memo). lairf and unit-macro-declares.fib are built by the
# seed as they are (the cases of cases/lir/macros and the unit must pass), then once per fault with one module changed in a shadow
# directory that comes first on the module path; each fault must make a case of cases/lir/macros or the unit fail. A fault that does not
# fail is a hole in the tests. Not in `make gate` (it builds lairf once per fault): run it after a change to those modules.
# usage: macro-faults.sh FIBC [WORKDIR]     (LLVM_LIBDIR the directory of libLLVM-21.so; JOBS faults at once, default 4)
# Exit: 0 the clean build passes and every fault is caught; 1 not; 2 a tool is missing.
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
fibc=${1:?usage: macro-faults.sh FIBC [WORKDIR]}
[ -x "$fibc" ] || { echo "macro-faults: no fibc at $fibc" >&2; exit 2; }
libdir=${LLVM_LIBDIR:-/usr/lib/llvm-21/lib}
work=${2:-${TMPDIR:-/tmp}/macro-faults-$$}
jobs=${JOBS:-4}
mkdir -p "$work"
export LD_LIBRARY_PATH=$libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
cd "$root" || exit 2

# run DIR: builds lairf and the unit with DIR first on the module path, runs the macro cases and the unit; the verdict in DIR/verdict.
run() {
  local d=$1
  # the main file is copied beside the shadow: fibc looks in the main file's directory first, so the shadow must be that directory
  cp compiler/lairf.fib "$d/lairf.fib"
  if ! "$fibc" build "$d/lairf.fib" -I "$d" -I compiler -L "$libdir" -l LLVM-21 -o "$d/lairf" > "$d/build.log" 2>&1 \
     || ! "$fibc" build compiler/tests/native/unit-macro-declares.fib -I "$d" -I compiler -I compiler/tests/native -I compiler/tests/support \
            -L "$libdir" -l LLVM-21 -o "$d/unit" >> "$d/build.log" 2>&1; then
    echo "build failed" > "$d/verdict"; return
  fi
  "$d/lairf" --old-spelling cases cases/lir/macros -j 4 > "$d/cases.out" 2>&1
  "$d/unit" > "$d/unit.out" 2>&1; local ust=$?
  local cfail; cfail=$(grep -c '^FAIL' "$d/cases.out")
  local total; total=$(grep '^total:' "$d/cases.out")
  if [ "$cfail" -eq 0 ] && [ -n "$total" ] && [ "$ust" -eq 0 ] && ! grep -q '^FAIL\|  fail ' "$d/unit.out"; then
    echo "pass: $total; unit: $(grep 'scenarios' "$d/unit.out")" > "$d/verdict"
  else
    echo "fail: $total; first: $(grep -m1 '^FAIL' "$d/cases.out" | cut -c1-120); unit: $(grep 'scenarios' "$d/unit.out")" > "$d/verdict"
  fi
}

mkdir -p "$work/clean"
run "$work/clean"
case $(cat "$work/clean/verdict") in
  pass*) echo "clean: $(cat "$work/clean/verdict")" ;;
  *) echo "clean build does not pass: $(cat "$work/clean/verdict") (logs in $work/clean)"; exit 1 ;;
esac

names=(); bad=0
# fault NAME FILE FROM TO: compiler/FILE with the first FROM replaced by TO, in its own shadow directory, run in the background.
fault() {
  local name=$1 file=$2 d="$work/$1"
  mkdir -p "$d/$(dirname "$file")"
  python3 - "$root/compiler/$file" "$d/$file" "$3" "$4" <<'EOM' || { echo "macro-faults: $name: the text to change is not in $file" >&2; bad=1; return; }
import sys
src, dst, a, b = sys.argv[1:5]
s = open(src).read()
if a not in s:
    sys.exit(1)
open(dst, "w").write(s.replace(a, b, 1))
EOM
  names+=("$name")
  run "$d" &
  while [ "$(jobs -r | wc -l)" -ge "$jobs" ]; do wait -n; done
}

D=native/macros/declares.fib
J=native/jit.fib
fault no-pruning-guard $D '(and (. p clean) (empty? (. p missing)))' 'true'
fault guard-ignores-missing $D '(and (. p clean) (empty? (. p missing)))' '(. p clean)'
fault guard-ignores-clean $D '(and (. p clean) (empty? (. p missing)))' '(empty? (. p missing))'
fault struct-twice-is-clean $D '(if (contains? (. p structs) (. s name))' '(if false'
fault symbol-twice-is-clean $D '(if (or (starts-with? name "llvm.") (contains? (. p symbols) name))' '(if (starts-with? name "llvm.")'
fault cycle-not-seen $D '(cenv/env-cyclic? env (. s name))' 'false'
fault fields-not-followed $D '((some fs) (named-in-all rest fs))' '((some fs) rest)'
fault result-types-not-followed $D '(structs (struct-closure p (into roots (types-named decls iface syms)))))' '(structs (struct-closure p roots)))'
fault old-at-not-stripped $D '(starts-with? a "@") (conj (conj acc a) (str-slice a 1 (str-len a)))' '(starts-with? a "@") (conj acc a)'
fault old-struct-not-stripped $D '(starts-with? a "%struct.") (conj (conj acc a) (str-slice a 8 (str-len a)))' '(starts-with? a "%struct.") (conj acc a)'
fault globals-not-declared $D '((ItDeclareGlobal g) (refer (add-symbol p (. g name) at) (. g ty)))' '((ItDeclareGlobal g) (refer p (. g ty)))'
fault earlier-macros-not-declared $D '(vec (keep (fn (pr: (Pair i64 str)) (macro-item env s (- -1 (. pr fst)) (. pr snd))) macros))' '[]'
fault symbols-not-mentioned $D '((SxAtom a _ _) (mention-text acc a))' '((SxAtom a _ _) acc)'
fault cache-object-not-copied $J '(orc/add-object (. s lljit) (objects/buffer-copy buf))' '(orc/add-object (. s lljit) buf)'
M=native/macros/memo.fib
fault cache-key-without-declarations $M '(key (str (print/print-module (LModule decls)) (. d key)))' '(key (. d key))'
fault memo-heads-ignored $M '(not (some? (first (filter (fn (h: str) (some? (get @(. env macros) h))) hs))))' 'true'
fault memo-readtable-ignored $M '(if (or @(. (. (. env readers) table) active) (= sp 0)' '(if (or false (= sp 0)'
fault memo-key-without-text $M '(some (str (sexp-pos form) " " (str-slice (. env text) (span-start sp) (span-end sp))))' '(some (str (sexp-pos form)))'
wait

for n in "${names[@]}"; do
  v=$(cat "$work/$n/verdict" 2>/dev/null || echo "no verdict")
  case $v in
    fail*) echo "caught      $n: $v" ;;
    *) echo "NOT CAUGHT  $n: $v"; bad=1 ;;
  esac
done
[ "$bad" -eq 0 ] && echo "macro-faults: every fault caught" && exit 0
exit 1
