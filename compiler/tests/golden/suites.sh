# compiler/tests/golden/suites.sh: the golden suites of lairf, sourced by golden.sh (not run). fibber's suites.sh (fibber ce3d8314) reduced
# to its three lairf rows; the goldens and their input lists are fibber's, recorded by fibber's stage 2 lairf.
# One line of `suite_table` per suite: NAME | TOOL | OPTIONS | RUST COMMAND | INPUT FILES (shell globs, repository-relative).
#   TOOL          the tool built from compiler/TOOL.fib (lairf); invoked as `TOOL OPTIONS FILE`.
#   RUST COMMAND  what the Rust oracle of fibber's tag seed-1 was run as when the golden was first recorded (history only).
# The golden of a suite is NAME.golden (the output and exit status of the tool on each input, in order) and NAME.files (the inputs in it).
suite_table() {
  cat <<'EOF'
lair-ast|lairf|dump-ast|lair|cases/lir/*/*.lir compiler/tests/native/h2-edge/*.lir
lair-check|lairf|check|lair|cases/lir/*/*.lir compiler/tests/native/h2-edge/*.lir
lair-llvm|lairf|emit-llvm|lair|cases/lir/*/*.lir
EOF
}
