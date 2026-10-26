# mk/tools.mk: lairf, lir2c and lir2js, each built by the seed from compiler/TOOL.fib with nothing but compiler/ on the module path and
# the library the seed ships. A tool is rebuilt when any source under compiler/ (tests aside) or lib/lir changes.
BIN := $(BUILD)/bin
TOOL_SRC := $(shell find compiler lib -type f \( -name '*.fib' -o -name '*.lir' -o -name '*.js' -o -name '*.mjs' -o -name '*.cpp' \) -not -path 'compiler/tests/*')
LAIRF := $(abspath $(BIN)/lairf)
LIR2C := $(abspath $(BIN)/lir2c)
LIR2JS := $(abspath $(BIN)/lir2js)
LLVM_ARGS := -L $(LLVM_LIBDIR) -l LLVM-21
tool_args_lairf := $(LLVM_ARGS)
tool_args_lir2c :=
tool_args_lir2js :=

$(BIN)/lairf $(BIN)/lir2c $(BIN)/lir2js: $(BIN)/%: compiler/%.fib $(TOOL_SRC) $(SEED_FIBC) | $(BIN)/
	t0=$$(date +%s); ( ulimit -v $(MEM_LIMIT) 2> /dev/null; timeout $(TOOLS_TIMEOUT) $(SEED_FIBC) build $< -I compiler $(tool_args_$*) -o $@.new ) > $@.log 2>&1 \
	  || { tail -n 20 $@.log; echo "FAIL build $*"; exit 1; }; mv $@.new $@; echo "build $*: $$(( $$(date +%s) - t0 )) s"

tools: $(BIN)/lairf $(BIN)/lir2c $(BIN)/lir2js   ## build lairf, lir2c and lir2js with the seed
.PHONY: tools
