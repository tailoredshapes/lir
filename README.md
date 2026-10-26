# lIR

lIR is LLVM IR written as S-expressions. It is a thin, one-to-one mapping:
every lIR form is an LLVM IR form with LLVM's name, and lIR adds no sugar,
no implicit conversions, and no vocabulary of any language built on it.
What lIR adds is verification: a module is parsed, checked as a whole by
lIR's own checker, lowered to LLVM IR, and run through the LLVM verifier,
on every path. An invalid module is an error with a message and a source
position; it never reaches LLVM's code generator.

```
(define (main i32) ()
  (block entry
    (ret (i32 0))))
```

This repository holds the language and its tools:

| Path | What |
|------|------|
| `spec/lir.md` | the contract: the language, the checker, the library API, the `lair` tool, and the cases. Where the code and the spec disagree, the disagreement is a bug to report, not a licence to change either. |
| `compiler/lir/` | the reader, AST, checker, printer, ownership verifier, the table of words, the respelling tool, and the target table (`lir.targets`, `lir.target`) |
| `compiler/native/` | lair, the compiler: lowering to LLVM, passes, the JIT, ahead-of-time builds and linking, compiled lIR objects (liro), kernels and WGSL, the fuzzer, the case harness, and the command line |
| `compiler/llvm/` | the bindings of LLVM-C (and the ThinLTO shim `thinlto.cpp`) |
| `compiler/c/`, `compiler/js/` | the C backend (`lir2c`) and the JavaScript backend (`lir2js`, with its runtime `compiler/js/rt/`) |
| `compiler/lairf.fib`, `lir2c.fib`, `lir2js.fib` | the three tools |
| `lib/lir/` | lIR's macro and reader libraries (`require-macros`) |
| `cases/lir/` | the cases, each with its verdict in its header (`lairf cases`) |
| `lir-audit/` | the audit of liar's lIR, each finding re-established as a case in `cases/lir/audit` |
| `compiler/tests/` | unit programs, goldens, and the differential checks of the backends |
| `docs/design/` | the designs of lair, the backends, and lIR's facts |

The tools are written in [fibber](https://github.com/tailoredshapes/fibber),
which embeds lair at the source level: fibber keeps a pinned, read-only copy
of the code paths of this repository. This repository is the source of truth
for them.

## Build

You need Linux on x86-64 (or macOS on Apple silicon), GNU Make 4, LLVM 21
(the shared `libLLVM-21`), a C compiler, curl, and Node.js for the
JavaScript backend's check.

The tools are built by a released fibber compiler, the seed. The file `SEED`
names it by URL and SHA-256 for each platform, and `make seed` fetches and
verifies it under `build/seed/`. lair compiles with the seed and the library
the seed ships, so lair can use a new fibber language or library feature
only once a fibber release has it.

```
make tools        # build/lairf, build/lir2c, build/lir2js
make gate         # every check; prints one line per stage and PASS or FAIL
make help         # the other targets
```

`LLVM_LIBDIR` names the directory of `libLLVM-21` (default
`/usr/lib/llvm-21/lib`, or Homebrew's `llvm@21` on macOS).

## Use

```
build/lairf run prog.lir              # check, lower, and run through the JIT
build/lairf build prog.lir -o prog    # an executable
build/lairf check prog.lir            # the checker alone
build/lairf emit-llvm prog.lir        # the LLVM IR
build/lairf cases cases/lir -j 8      # the cases
```

The tree's lIR is in the old spelling until it is respelled (spec/lir.md §2):
the build passes `--old-spelling` (`FIB_LIR_SPELLING=old`) to every lairf it
runs.

## How work is judged

Nothing is done until an executable test says so (spec/method.md). `make
gate` runs the cases, the goldens, the unit programs, the tool checks, the
differential checks of the C and JavaScript backends against lair, and lair's
fixed point: lair compiles its own lIR, and the rebuilt lairf emits the same
LLVM IR.

## License

BSD 3-Clause; see `LICENSE`.
