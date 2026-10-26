# lir

lIR (LLVM IR as S-expressions) and lair, its compiler, with the C and
JavaScript backends. Cut from fibber (owner decision 2026-10-26: "Lir and
lair should be their own repo"); see README.md.

fibber compiles lair at the source level and keeps a pinned, read-only copy
of `compiler/{lir,native,llvm,c}`, `compiler/lir.fib`, `compiler/lairf.fib`
and `spec/lir.md`. Changes to those paths start here; fibber syncs them.

## How work is judged

Read spec/method.md (fibber's method, copied at fibber ce3d8314; it applies
here unchanged). In short: nothing is done until an executable test
says so; claims in docs, commit messages and chat carry no weight.

- Do not describe anything as working, passing or implemented unless you
  ran it in this session and can quote the output.
- A test that cannot fail is worse than no test. Pending is not pass.
- When spec/lir.md and the code disagree, stop and report; do not quietly
  change either.
- `make gate` is the gate: it must print PASS before a push.

## lIR is LLVM IR

lIR forms mirror LLVM IR's names and syntax. A new form is an LLVM IR
form with LLVM's name; do not invent abstractions (spec/lir.md, the
introduction and §6.10).

## Spelling (spec/lir.md §2)

- Every word lIR owns is upper case and is LLVM's word (`DEFINE`, `ADD`,
  `I64`, `TAILCC`). The lower case is free for names and for languages
  built on lIR.
- A reference or a type is a form, never a sigil: `(GLOBAL NAME)`,
  `(STRUCT NAME)`, `(VECTOR N T)`, `(ARRAY N T)`, `(PTR (ADDRSPACE 1))`.
- The words are one table, `compiler/lir/words.fib`;
  `compiler/tests/lir/words.sh` holds it equal to the spec's grammar. A new
  word goes into the grammar and the table together.
- The old spelling is transitional: the tree's cases are in it until they
  are respelled, so the build sets `FIB_LIR_SPELLING=old` and runs `lairf
  --old-spelling`. New text is written in the new spelling.

## Code

- lair is a fibber program. It must compile with the seed (`SEED`) and the
  library the seed ships; it may not require a fibber compiler module.
- Files under 500 lines, functions under 50. Use the library's own tools:
  flat `cond`, `try-let`, `if-some`, destructuring, `defrecord`.
- The self-hosting trap applies, because fibber compiles lair: a new core
  form or builtin of fibber must not share a name with a function here.

## Commits

- One logical change per commit; the message says what and why.
- Never commit build output. Never rewrite pushed history.
