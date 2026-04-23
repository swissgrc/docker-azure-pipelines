#!/usr/bin/env bash
# Smoke tests for azure-pipelines-hermes.
# Usage: test/hermes.sh <image-ref>
#   e.g. test/hermes.sh ghcr.io/swissgrc/azure-pipelines-hermes:2026.04.21.0
#
# Every assertion is one `docker run` so failures are easy to read in CI logs.
# All dependencies live inside the container — the host only needs docker.

set -euo pipefail

IMAGE="${1:?usage: test/hermes.sh <image-ref>}"

run() { docker run --rm "$IMAGE" "$@"; }

# --- hermes's own tool ---------------------------------------------------
run renovate --version

# --- Renovate functional: CLI help loads all managers -------------------
# `renovate --help` exercises module loading across every manager (npm,
# nuget, etc.) and datasource. Catches a broken post-install step that
# left RE2 or another native dep in an unusable state.
run renovate --help

# --- RE2 native module loads --------------------------------------------
# Exercise RE2 directly to catch prebuilt-binary mismatches. If the `re2`
# post-install step didn't run (or the prebuilt binary doesn't match the
# runtime), require() throws at load time and this test fails fast — with
# a clearer signal than a buried Renovate startup error.
# `re2` is a nested dep of renovate (not a top-level global), so NODE_PATH
# must point at renovate's own node_modules — $(npm root -g) alone isn't
# enough since Node's resolver doesn't descend into sibling packages.
docker run --rm "$IMAGE" bash -c '
  set -euo pipefail
  NODE_PATH="$(npm root -g)/renovate/node_modules" node -e "const RE2 = require(\"re2\"); if (!new RE2(\"^\\\\d+$\").test(\"42\")) process.exit(1)"
'

# --- Inheritance: vulcan tools still work -------------------------------
run dotnet --version
run dotnet --list-sdks
run node --version
run npm --version

# --- Inheritance: terra tools still work --------------------------------
run git --version
run docker --version
run jq --version
run yq --version
run claude --version
run copilot --version
