# mk/checks.mk: one stamp build/gate/NAME.ok per check, its output in build/gate/NAME.log. Each check is `check_NAME`, its command (one
# simple command, run from the root under the limits of mk/config.mk), and `tools_NAME`, the tools of build/bin it needs. Every stamp also depends on
# its tools, the test inputs (compiler/tests, cases, lib/lir, spec, scripts), and this file.
GATE_DIR := $(BUILD)/gate
TEST_SRC := $(shell find compiler/tests cases lib spec scripts -type f) $(wildcard lir-audit/*)
T := compiler/tests

# lair's cases, every one; the cases that do not pass must be exactly those of scripts/cases.expected
check_cases := scripts/cases.sh $(LAIRF) $(CASE_JOBS)
tools_cases := lairf
# the goldens of lairf (compiler/tests/golden): dump-ast, check and emit-llvm of every case input, output and status
check_golden-lair-ast := env GOLDEN_OUT=$(ABS_BUILD)/golden/ast $(T)/golden/golden.sh --tools $(ABS_BUILD)/bin --only lair-ast
tools_golden-lair-ast := lairf
check_golden-lair-check := env GOLDEN_OUT=$(ABS_BUILD)/golden/check $(T)/golden/golden.sh --tools $(ABS_BUILD)/bin --only lair-check
tools_golden-lair-check := lairf
check_golden-lair-llvm := env GOLDEN_OUT=$(ABS_BUILD)/golden/llvm $(T)/golden/golden.sh --tools $(ABS_BUILD)/bin --only lair-llvm
tools_golden-lair-llvm := lairf
# the unit programs (compiler/tests/units.txt), each built by the seed and run: exit 0 and no FAIL line
UNIT_FILES := $(shell grep -v '^\#' $(T)/units.txt | grep -v '^$$')
# the stamp of FILE is unit-NAME (NAME its base name, without a leading `unit-` of its own)
unit_name = unit-$(patsubst unit-%,%,$(basename $(notdir $(1))))
UNIT_NAMES := $(foreach f,$(UNIT_FILES),$(call unit_name,$(f)))
$(foreach f,$(UNIT_FILES),$(eval check_$(call unit_name,$(f)) := scripts/unit.sh $(SEED_ABS) $(f) $(ABS_BUILD)/units))
# Not a check: compiler/tests/native/skeleton.sh (every module of compiler/lir and compiler/native must be required by skeleton.fib) fails:
# 69 modules added since 2026-10-04 are not listed, and it was in no gate of fibber's. Listing them takes a function of each; to be done.
# Not checks: the planted-fault suites compiler/tests/native/j-faults.sh and f-faults.sh catch every fault but one each, whose text is no
# longer in the code (j: trampoline-void-without-ret in native/jit/trampoline.fib; f: tree-bracket in native/fuzz/tree.fib), so they exit 1.
# They were in no gate of fibber's. The fault texts are to be brought up to date with the code.
# the table of words equals the upper-case atoms of spec/lir.md's grammar
check_words := env LAIRF=$(LAIRF) OUT=$(ABS_BUILD)/tmp/words $(T)/lir/words.sh
tools_words := lairf
# `lairf respell` over every lIR file: parse-equivalent, idempotent, and new spelling alone where it can be
check_respell := env LAIRF=$(LAIRF) OUT=$(ABS_BUILD)/tmp/respell $(T)/lir/respell.sh
tools_respell := lairf
# lIR's facts through lair's three check modes and the C and JS backends
check_facts := env L=$(LAIRF) $(T)/native/facts.sh $(SEED_ABS)
tools_facts := lairf
# the module's target form reaches the code generator; the AArch64 sibling-call fault stays fixed (assembly on any host)
check_p0-target := env LAIRF=$(LAIRF) $(T)/native/p0-target.sh
tools_p0-target := lairf
check_a64-sibcall := env L=$(LAIRF) $(T)/native/a64-sibcall.sh $(SEED_ABS)
tools_a64-sibcall := lairf
# the JS backend: the runtime's unit tests, then every case natively and as JavaScript (node), against compiler/tests/js/expected.txt
check_js := env LAIRF=$(LAIRF) LIR2JS=$(LIR2JS) CHECK_JOBS=$(CASE_JOBS) scripts/check-js.sh
tools_js := lairf lir2js
# the C backend: every case natively and through C (gcc), against compiler/tests/c-backend/expected.txt
check_c-diff := env LAIRF=$(LAIRF) LIR2C=$(LIR2C) $(T)/c-backend/diff.sh -j $(CASE_JOBS) --reject --expect $(T)/c-backend/expected.txt
tools_c-diff := lairf lir2c
# lair's fixed point: lairf builds the lIR of itself, and the rebuilt lairf emits the same LLVM IR and passes the cases
check_fixed-point := scripts/fixed-point.sh $(SEED_ABS) $(LAIRF) $(ABS_BUILD)/fixed-point $(CASE_JOBS)
tools_fixed-point := lairf

# the object files of macro sessions kept on disk between programs: cold, warm, refused when a file holds another key, none when off
check_macro-store := compiler/tests/native/macro-store.sh $(LAIRF)
tools_macro-store := lairf

# the libc functions of a 32-bit target: declared and called with `i32` where lIR says `i64` (wasm32; LLVM IR checked, nothing run)
check_libc-narrow := env LAIRF=$(LAIRF) $(T)/native/libc-narrow.sh
tools_libc-narrow := lairf

GATE_CHECKS := cases golden-lair-ast golden-lair-check golden-lair-llvm $(UNIT_NAMES) words respell facts \
  p0-target a64-sibcall libc-narrow macro-store js c-diff fixed-point
# The table of the runtime's C functions equals the declares of fibber's rt/*.lir. rt lives in fibber, so this check is part of the gate only when
# FIBBER_RT names that directory (`make gate FIBBER_RT=../fibber/rt`); it reruns when a file of it changes.
FIBBER_RT ?=
ifneq ($(FIBBER_RT),)
check_runtime-fns := env TMPDIR=$(ABS_BUILD)/tmp $(T)/native/runtime-fns.sh $(abspath $(FIBBER_RT))
tools_runtime-fns :=
GATE_CHECKS += runtime-fns
$(GATE_DIR)/runtime-fns.ok: $(wildcard $(FIBBER_RT)/*.lir)
endif
GATE_STAMPS := $(addprefix $(GATE_DIR)/,$(addsuffix .ok,$(GATE_CHECKS)))

define gate_check
$(GATE_DIR)/$(1).ok: $(addprefix $(BIN)/,$(tools_$(1))) $(SEED_FIBC) $(TEST_SRC) mk/checks.mk | $(GATE_DIR)/ $(ABS_BUILD)/tmp/
	@echo "check $(1)"
	@$$(call stamp,$(check_$(1)))
endef
$(foreach c,$(GATE_CHECKS),$(eval $(call gate_check,$(c))))

$(foreach c,$(GATE_CHECKS),$(eval check-$(c): $(GATE_DIR)/$(c).ok))
.PHONY: $(addprefix check-,$(GATE_CHECKS))
