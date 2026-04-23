#!/usr/bin/env bash
# Smoke tests for azure-pipelines-vulcan.
# Usage: test/vulcan.sh <image-ref>
#   e.g. test/vulcan.sh ghcr.io/swissgrc/azure-pipelines-vulcan:2026.04.17.0
#
# Every assertion is one `docker run` so failures are easy to read in CI logs.
# All dependencies live inside the container — the host only needs docker.

set -euo pipefail

IMAGE="${1:?usage: test/vulcan.sh <image-ref>}"

run() { docker run --rm "$IMAGE" "$@"; }
runInteractive() { docker run --rm -i "$IMAGE" "$@"; }

# --- vulcan's own tools --------------------------------------------------
run dotnet --version
run dotnet --list-sdks
run node --version
run npm --version
run yarn --version
run pnpm --version
run fc-list --version

# --- .NET env vars are actually exported ---------------------------------
[[ "$(run printenv DOTNET_NOLOGO)" == "true" ]]
[[ "$(run printenv DOTNET_CLI_TELEMETRY_OPTOUT)" == "true" ]]
[[ "$(run printenv NUGET_XMLDOC_MODE)" == "skip" ]]
# Inherited from terra — re-asserted to catch accidental un-set.
[[ "$(run printenv DISABLE_AUTOUPDATER)" == "1" ]]

# --- Functional: both SDKs compile end-to-end ---------------------------
# Uses a tempdir inside the container; no host bind-mounts.
run bash -c '
  set -euo pipefail
  cd "$(mktemp -d)"
  dotnet new console --framework net9.0 -o app9 && dotnet build -f net9.0 app9
  dotnet new console --framework net10.0 -o app10 && dotnet build -f net10.0 app10
'

# --- Functional: Node runs scripts --------------------------------------
[[ "$(echo 'console.log(2 + 2)' | runInteractive node)" == "4" ]]

# --- Functional: Yarn and pnpm reach their respective registries --------
# Exercises outbound HTTPS + package manager resolution without a full install.
# No --cwd: `yarn info` is a pure registry query, and passing /tmp would be
# rewritten by Git Bash's MSYS path translation on Windows hosts.
run yarn info lodash name
run pnpm info lodash name

# --- Inheritance: every terra tool still works --------------------------
# Condensed — full set is proven by terra.sh; here we prove inheritance,
# not retest each tool.
run git --version
run docker --version
run jq --version
run yq --version
run claude --version
run copilot --version
