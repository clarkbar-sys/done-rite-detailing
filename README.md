<!--
  ┌─────────────────────────────────────────────────────────────────────┐
  │  You are reading the template's own README.                          │
  │  After clicking "Use this template", delete this comment block and   │
  │  the "Getting started" section below, then fill in the placeholders. │
  └─────────────────────────────────────────────────────────────────────┘
-->

# {{PROJECT_NAME}}

> {{ONE_LINE_DESCRIPTION}}

<!-- Keep the badge(s) for the language(s) this repo uses; delete the rest. -->
[![CI (C/C++)](https://github.com/clarkbar-sys/{{REPO_NAME}}/actions/workflows/ci-c.yml/badge.svg)](https://github.com/clarkbar-sys/{{REPO_NAME}}/actions/workflows/ci-c.yml)
[![CI (Scheme)](https://github.com/clarkbar-sys/{{REPO_NAME}}/actions/workflows/ci-scheme.yml/badge.svg)](https://github.com/clarkbar-sys/{{REPO_NAME}}/actions/workflows/ci-scheme.yml)
[![CI (Python)](https://github.com/clarkbar-sys/{{REPO_NAME}}/actions/workflows/ci-python.yml/badge.svg)](https://github.com/clarkbar-sys/{{REPO_NAME}}/actions/workflows/ci-python.yml)
[![Publish container (s7)](https://github.com/clarkbar-sys/{{REPO_NAME}}/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/clarkbar-sys/{{REPO_NAME}}/actions/workflows/docker-publish.yml)
[![License](https://img.shields.io/badge/license-GPL--2.0-blue.svg)](./LICENSE)

## Overview

Describe what this project does and who it's for in 2–3 sentences.

This repo is set up for **[s7 Scheme](https://ccrma.stanford.edu/software/snd/snd/s7.html)**
(CCRMA / Stanford) — a tiny, embeddable Scheme that's just two C files. The
source is fetched from upstream and **checksum-verified at build time**
([`scripts/fetch-s7.sh`](./scripts/fetch-s7.sh)) rather than vendored, so the
repo stays lean while builds stay pinned. No Guile, no Racket.

## Run s7 anywhere

**Container (GitHub Container Registry)** — nothing to install but Docker:

```bash
# interactive REPL
docker run --rm -it ghcr.io/clarkbar-sys/{{REPO_NAME}}

# run a script from the current directory
docker run --rm -v "$PWD:/work" ghcr.io/clarkbar-sys/{{REPO_NAME}} script.scm
```

**Static binary** — a single dependency-free file attached to each
[release](https://github.com/clarkbar-sys/{{REPO_NAME}}/releases):

```bash
curl -fsSLO https://github.com/clarkbar-sys/{{REPO_NAME}}/releases/latest/download/s7-linux-x86_64
chmod +x s7-linux-x86_64 && ./s7-linux-x86_64 script.scm
```

**Build it locally** — needs only a C compiler:

```bash
make build          # -> bin/s7
make repl           # start a REPL
./bin/s7 examples/hello.scm
```

## Development

```bash
make build          # fetch (pinned) + compile the s7 interpreter -> bin/s7
make test           # build, then run every tests/*.scm (each must exit 0)
make repl           # interactive REPL
make clean          # remove build outputs
```

The s7 version is pinned by `sha256` in [`scripts/fetch-s7.sh`](./scripts/fetch-s7.sh);
run `scripts/fetch-s7.sh --update` to see the current upstream checksum/version
and bump the pin.

## Releases

Releases are automated with
[release-please](https://github.com/googleapis/release-please). Commit using
[Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`,
`chore:` …) and a **Release PR** is opened and kept up to date automatically —
it bumps the version and updates [CHANGELOG.md](./CHANGELOG.md). Merge that PR to
tag the release; `release.yml` then builds and attaches the program artifacts.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) and the
[Coding Standards](./STANDARDS.md). Please also read our
[Code of Conduct](./CODE_OF_CONDUCT.md).

## Security

Found a vulnerability? See [SECURITY.md](./SECURITY.md) — please do **not** open a
public issue for security reports.

## License

Distributed under the terms of the [GNU GPL v2](./LICENSE).

---

<details>
<summary><strong>📋 New-repo checklist (delete this section once done)</strong></summary>

After creating a repo from this template:

- [ ] Replace `{{PROJECT_NAME}}`, `{{ONE_LINE_DESCRIPTION}}`, `{{REPO_NAME}}` above
- [ ] Keep the CI workflow(s) for your language(s) (`ci-c` / `ci-scheme` /
      `ci-python`); delete the rest, and delete the badges to match
- [ ] **Scheme is pre-wired for s7**: `ci-scheme` + container publish
      (`docker-publish`) + `release` need no TODOs. Put your Scheme in `src/` /
      `tests/` (see `examples/` and `tests/smoke.scm`)
- [ ] For C / Python: fill in the `TODO:` build/test commands, review
      [STANDARDS.md](./STANDARDS.md), and fill the `{{PLACEHOLDERS}}` in
      `pyproject.toml` (configs enforce an 80% coverage floor by default)
- [ ] Update `.github/CODEOWNERS` with the real owning team
- [ ] Enable branch protection on `main` (require CI + 1 review); add the
      `ci-scheme` jobs as required status checks
- [ ] After the first push to `main`, make the GHCR package public if you want
      `docker pull` without auth (repo → Packages → package settings)
- [ ] Confirm `SECURITY.md` contact is correct
- [ ] Releases: commit with [Conventional Commits](https://www.conventionalcommits.org/)
      so release-please can version + changelog automatically; wire the build step
      in `.github/workflows/release.yml`
- [ ] Delete the "Getting started" TODOs once real commands exist

</details>
