# s7 Scheme — fetch the pinned interpreter source, build the standalone
# interpreter, and run the Scheme test suite through it.
# s7 is downloaded at build time (not vendored); see scripts/fetch-s7.sh.

CC      ?= cc
S7_DIR  := .s7
BIN_DIR := bin
S7      := $(BIN_DIR)/s7

# Canonical s7 standalone build (Linux). WITH_MAIN gives s7.c a REPL/main;
# -export-dynamic is required so the FFI can resolve symbols at runtime.
CFLAGS  ?= -O2
S7_CFLAGS := -DWITH_MAIN -I$(S7_DIR) $(CFLAGS)
S7_LDFLAGS := -ldl -lm -Wl,-export-dynamic

# Every *.scm under tests/ is a test; each must exit non-zero on failure.
TESTS := $(wildcard tests/*.scm)

.PHONY: all build test repl fetch clean distclean

all: build

# Download + checksum-verify the pinned s7 source. Idempotent: the recipe only
# runs when .s7/s7.c is missing.
$(S7_DIR)/s7.c:
	scripts/fetch-s7.sh $(S7_DIR)
fetch: $(S7_DIR)/s7.c

build: $(S7)

$(S7): $(S7_DIR)/s7.c
	@mkdir -p $(BIN_DIR)
	$(CC) $(S7_DIR)/s7.c -o $@ $(S7_CFLAGS) $(S7_LDFLAGS)

# Run each test script; s7 exits non-zero if the script calls (exit N>0) or errors.
test: build
	@if [ -z "$(TESTS)" ]; then \
	  echo "No tests/*.scm yet — nothing to run."; \
	else \
	  fail=0; \
	  for t in $(TESTS); do \
	    printf '  s7 %s ... ' "$$t"; \
	    if ./$(S7) "$$t" >/dev/null; then echo ok; else echo FAIL; fail=1; fi; \
	  done; \
	  [ $$fail -eq 0 ] || { echo "Some tests failed."; exit 1; }; \
	  echo "All tests passed."; \
	fi

# Start an interactive s7 REPL.
repl: build
	./$(S7)

clean:
	rm -rf $(BIN_DIR)

# Also drop the fetched source (forces a re-download on the next build).
distclean: clean
	rm -rf $(S7_DIR)
