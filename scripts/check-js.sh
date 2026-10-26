#!/bin/bash
# scripts/check-js.sh: the JS backend's check with tools already built (compiler/tests/js/check.sh builds its own with a fibc): the runtime's
# unit tests (rt-test.mjs), then the differential harness over cases/lir and compiler/tests/js/cases with the reject cases, against
# compiler/tests/js/expected.txt (docs/design/js-backend.md).
# Environment: LAIRF, LIR2JS, NODE (default node), CHECK_JOBS (programs at once, default 2). Exit 0 when both hold.
set -u
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root" || exit 2
: "${LAIRF:?set LAIRF}" "${LIR2JS:?set LIR2JS}"
node=${NODE:-node}
command -v "$node" > /dev/null 2>&1 || { echo "FAIL js: no node (NODE=$node)"; exit 1; }
export LD_LIBRARY_PATH=${LLVM_LIBDIR:-/usr/lib/llvm-21/lib}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
ok=0
"$node" compiler/tests/js/rt-test.mjs || { echo "FAIL js: rt-test.mjs"; ok=1; }
compiler/tests/js/diff.sh -j "${CHECK_JOBS:-2}" --reject --expect compiler/tests/js/expected.txt || ok=1
exit $ok
