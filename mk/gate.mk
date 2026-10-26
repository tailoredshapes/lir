# mk/gate.mk: `make gate` builds every stamp of mk/checks.mk (-k: one failure does not hide the others), then reports one line per stage
# (the tools' build times, each check's seconds or its failure) and PASS or FAIL. The stamps make it incremental: a stage whose inputs did
# not change keeps its stamp. `make -j8 gate` runs eight recipes at once.
gate-stamps: $(GATE_STAMPS)
gate-report:
	@fail=0; for t in lairf lir2c lir2js; do \
	  if [ -x $(BIN)/$$t ]; then echo "ok   build $$t"; else echo "FAIL build $$t (log: $(BIN)/$$t.log)"; fail=1; fi; done; \
	for c in $(GATE_CHECKS); do s=$(GATE_DIR)/$$c.ok; \
	  if [ -f $$s ]; then printf 'ok   %-22s %4s s\n' "$$c" "$$(cat $$s)"; else echo "FAIL $$c (log: $(GATE_DIR)/$$c.log)"; fail=1; fi; done; \
	if [ $$fail = 0 ]; then echo "PASS gate ($(words $(GATE_CHECKS)) checks)"; else echo "FAIL gate"; exit 1; fi
gate:   ## every check (cases, goldens, units, tool tests, backends, fixed point): one line per stage, then PASS or FAIL
	@$(MAKE) --no-print-directory -k gate-stamps || true
	@$(MAKE) --no-print-directory gate-report
.PHONY: gate gate-stamps gate-report
