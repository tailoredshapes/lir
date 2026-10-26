# mk/config.mk: the settings every section shares. Nothing here is a target but the directories.
ifeq ($(filter 4.% 5.%,$(MAKE_VERSION)),)
  $(error lir needs GNU Make 4 or later (this is $(MAKE_VERSION)); on macOS `brew install make` and run `gmake`)
endif
.DEFAULT_GOAL := help
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SECONDARY:
.SUFFIXES:
MAKEFLAGS += --no-builtin-rules --no-builtin-variables

ROOT := $(CURDIR)
BUILD ?= build
ABS_BUILD := $(abspath $(BUILD))
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)
PLATFORM := $(shell echo "$(UNAME_S)-$(UNAME_M)" | tr 'A-Z' 'a-z' | sed 's/linux-amd64/linux-x86_64/; s/darwin-aarch64/darwin-arm64/')
FIB_PLATFORM ?= $(PLATFORM)
ifeq ($(UNAME_S),Darwin)
  LLVM_LIBDIR ?= /opt/homebrew/opt/llvm@21/lib
else
  LLVM_LIBDIR ?= /usr/lib/llvm-21/lib
endif
export LLVM_LIBDIR
export LLVMLIB := $(LLVM_LIBDIR)
export LLVM_LIB := $(LLVM_LIBDIR)

# CASE_JOBS: cases at once inside one recipe (`lairf cases -j`, the differential checks); make's -j runs recipes side by side.
CASE_JOBS ?= 4
# Every check runs under TOOLS_TIMEOUT seconds and a MEM_LIMIT of address space (KB, `ulimit -v`).
TOOLS_TIMEOUT ?= 1800
MEM_LIMIT ?= 16000000

# A fibc reads the library it ships: no fibber lib/ here. The tree's lIR is in the old spelling until it is respelled (spec/lir.md 2,
# transitional): every lairf of the build admits it (`lairf --old-spelling` is the same switch).
unexport FIB_LIB
unexport FIB_PATH
export FIB_LIR_SPELLING := old
export TMPDIR := $(ABS_BUILD)/tmp
$(shell mkdir -p $(TMPDIR))
unexport LD_LIBRARY_PATH

# $(call stamp,CMD): runs CMD (one simple command, `env VAR=.. PROGRAM ARGS..`) under the time and memory limits with its output in the
# stamp's .log; the stamp holds the elapsed seconds and exists only when CMD passed.
define stamp
rm -f $@; t0=$$(date +%s); if ( ulimit -v $(MEM_LIMIT) 2> /dev/null; timeout $(TOOLS_TIMEOUT) $(1) ) > $(@:%.ok=%.log) 2>&1; then echo "$$(( $$(date +%s) - t0 ))" > $@; else echo "FAIL $@ (log: $(@:%.ok=%.log))"; tail -n 20 $(@:%.ok=%.log); exit 1; fi
endef

# a directory, as an order-only prerequisite (`| $(BUILD)/x/`)
%/:
	mkdir -p $@
