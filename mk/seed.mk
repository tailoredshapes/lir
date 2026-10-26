# mk/seed.mk: the fibber compiler named by SEED (one url and one sha256 per platform; the bare lines are linux-x86_64's), fetched by
# scripts/fetch-seed.sh into build/seed/<sha256>/: a changed SEED is a new directory, a wrong sha256 is a failure that names it. Downloads
# are cached in FIB_SEED_CACHE (DIR/<sha256>/seed.tar.gz).
SEED_URL := $(shell sed -n 's/^url\.$(FIB_PLATFORM)=//p' SEED)
SEED_SHA := $(shell sed -n 's/^sha256\.$(FIB_PLATFORM)=//p' SEED)
ifeq ($(SEED_URL),)
  ifeq ($(FIB_PLATFORM),linux-x86_64)
    SEED_URL := $(shell sed -n 's/^url=//p' SEED)
    SEED_SHA := $(shell sed -n 's/^sha256=//p' SEED)
  endif
endif
ifeq ($(SEED_SHA),)
  SEED_SHA := no-seed-for-$(FIB_PLATFORM)
endif
SEED_DIR := $(BUILD)/seed/$(SEED_SHA)
SEED_FIBC := $(SEED_DIR)/bin/fibc
SEED_ABS := $(abspath $(SEED_FIBC))
export FIB_SEED_CACHE ?= $(HOME)/.cache/fibber-scratch/seeds

$(SEED_FIBC): | scripts/fetch-seed.sh
	rm -rf $(SEED_DIR); mkdir -p $(SEED_DIR)/unpack
	FIB_PLATFORM=$(FIB_PLATFORM) scripts/fetch-seed.sh $(SEED_DIR)/unpack > /dev/null
	mv $(SEED_DIR)/unpack/fibc-*/* $(SEED_DIR)/ && rm -rf $(SEED_DIR)/unpack
	touch $@ && test -x $@ && $@ --version

seed: $(SEED_FIBC)   ## fetch and verify the seed compiler that SEED names
print-seed: $(SEED_FIBC)   ## print the path of the seed compiler
	@echo $(SEED_ABS)
.PHONY: seed print-seed
