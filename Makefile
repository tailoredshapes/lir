# Makefile: lIR's build coordinator (GNU Make 4; macOS: gmake). Targets are files under build/: the seed under build/seed/, the tools under
# build/bin/, one stamp per check under build/gate/ (its log beside it). The rules follow fibber's mk/ (fibber ce3d8314), reduced to lIR's.
#   make tools    build/bin/lairf, lir2c, lir2js, built by the seed
#   make gate     every check, then one line per stage and PASS or FAIL
include mk/config.mk
include mk/seed.mk
include mk/tools.mk
include mk/checks.mk
include mk/gate.mk

help:   ## this list
	@grep -hE '^[a-zA-Z_-]+:.*## ' Makefile mk/*.mk | sed -E 's/:.*## /\t/' | sort | awk -F'\t' '{ printf "  %-14s %s\n", $$1, $$2 }'
clean:   ## remove build/
	rm -rf $(BUILD)
.PHONY: help clean
