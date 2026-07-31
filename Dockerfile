# syntax=docker/dockerfile:1
#
# A portable s7 Scheme interpreter you can pull and run anywhere:
#   docker run --rm -it ghcr.io/clarkbar-sys/<repo>            # interactive REPL
#   docker run --rm -v "$PWD:/work" ghcr.io/clarkbar-sys/<repo> script.scm
#
# s7 is fetched from CCRMA and checksum-verified at build time (see
# scripts/fetch-s7.sh) — it is not vendored in this repo.

# ---- build stage: fetch + compile s7 + the REPL's libc FFI shim -------------
FROM debian:bookworm-slim AS build

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY scripts/fetch-s7.sh scripts/fetch-s7.sh
RUN scripts/fetch-s7.sh s7

WORKDIR /build/s7
# S7_LOAD_PATH is baked in so the interactive REPL finds repl.scm + libc_s7.so
# no matter what directory s7 is launched from.
RUN mkdir -p /out/lib \
 && cc s7.c -o /out/s7 \
      -DWITH_MAIN -DS7_LOAD_PATH='"/usr/local/lib/s7"' \
      -I. -O2 -ldl -lm -Wl,-export-dynamic

# Pre-build libc_s7.so (the FFI shim the deluxe REPL loads) so the runtime image
# needs no C compiler. Running in script mode keeps the build output clean.
RUN echo '(require libc.scm)' > /tmp/mk-libc.scm \
 && /out/s7 /tmp/mk-libc.scm \
 && cp libc_s7.so cload.scm libc.scm repl.scm /out/lib/

# ---- runtime stage: just the interpreter + its support files ----------------
FROM debian:bookworm-slim AS runtime

LABEL org.opencontainers.image.title="s7" \
      org.opencontainers.image.description="s7 Scheme interpreter (CCRMA/Stanford), standalone build" \
      org.opencontainers.image.licenses="0BSD"

COPY --from=build /out/s7      /usr/local/bin/s7
COPY --from=build /out/lib/    /usr/local/lib/s7/

# Scripts mounted by the user land here; the REPL still works from any cwd.
WORKDIR /work

# No args -> interactive REPL. `... script.scm` -> run the script.
ENTRYPOINT ["/usr/local/bin/s7"]
