#!/usr/bin/env bash
# Smoke tests for azure-pipelines-terra.
# Usage: test/terra.sh <image-ref>
#   e.g. test/terra.sh ghcr.io/swissgrc/azure-pipelines-terra:2026.04.15.0
#
# Every assertion is one `docker run` so failures are easy to read in CI logs.
# All dependencies live inside the container — the host only needs docker.

set -euo pipefail

IMAGE="${1:?usage: test/terra.sh <image-ref>}"

run()            { docker run --rm    "$IMAGE" "$@"; }
runInteractive() { docker run --rm -i "$IMAGE" "$@"; }

# --- Version checks -------------------------------------------------------
# Duplicates many of the Dockerfile's inline smoke tests but re-asserts
# from outside the build, proving PATH + runtime deps work in a cold-start
# container.
run curl --version
run unzip -v
run docker --version
run docker buildx version
run docker compose version
run docker-buildx version
run docker-compose version
run git --version
run git lfs version
run jq --version
run yq --version
run copilot --version
run claude --version

# --- Functional smoke tests ----------------------------------------------
# jq parses JSON on stdin.
[[ "$(echo '{"a":1}' | runInteractive jq '.a')" == "1" ]]

# yq parses YAML on stdin.
[[ "$(echo 'a: 1' | runInteractive yq '.a')" == "1" ]]

# Git clones over HTTPS — exercises libcurl3-gnutls runtime dep.
# `awk 'NR==1'` reads to EOF (unlike `head -n1` which closes early and gives
# docker SIGPIPE on some hosts), so host `pipefail` still catches a failing
# git while only the first ref line is printed for readability.
run git ls-remote https://github.com/octocat/Hello-World.git | awk 'NR==1'

# Git LFS registers its filters into git config — proves the binary integrates
# with git, not just that it loads.
run git lfs install

# Buildx is reachable as a docker CLI plugin (not just a standalone binary).
run docker buildx ls
