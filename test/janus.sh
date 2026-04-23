#!/usr/bin/env bash
# Smoke tests for azure-pipelines-janus.
# Usage: test/janus.sh <image-ref>
#   e.g. test/janus.sh ghcr.io/swissgrc/azure-pipelines-janus:2026.04.20.0
#
# Every assertion is one `docker run` so failures are easy to read in CI logs.
# All dependencies live inside the container — the host only needs docker.

set -euo pipefail

IMAGE="${1:?usage: test/janus.sh <image-ref>}"

run() { docker run --rm "$IMAGE" "$@"; }

# --- janus's own tools ---------------------------------------------------
run az --version
run terraform --version
run tflint --version
run packer --version
run helm version
run kubectl version --client
run kubelogin --version
run swa --version

# --- Azure CLI functional: reaches Azure endpoints -----------------------
# `az extension list-available` downloads the public extension index from
# azcliextensionsync.blob.core.windows.net — a genuine anonymous HTTPS call
# that proves DNS + outbound networking + CLI initialization.
# (`az cloud list` would be local-only; its cloud definitions ship with the CLI.)
run az extension list-available --output table

# --- Terraform functional: inits and validates an empty config ----------
run bash -c '
  set -euo pipefail
  cd "$(mktemp -d)"
  echo "terraform { }" > main.tf
  terraform init
  terraform validate
'

# --- Helm functional: adds a public chart repo --------------------------
# kubernetes-sigs/metrics-server is an actively maintained chart repo;
# charts.helm.sh/stable was deprecated in November 2020 and is now archived.
run bash -c '
  set -euo pipefail
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
  helm repo update
  helm search repo metrics-server/
'

# --- kubectl functional: binary loads and parses flags without a cluster
run kubectl api-resources --help

# --- Packer functional: inits and validates an empty template -----------
run bash -c '
  set -euo pipefail
  cd "$(mktemp -d)"
  cat > main.pkr.hcl <<PACKER
packer {
  required_plugins {}
}
source "null" "test" {
  communicator = "none"
}
build {
  sources = ["source.null.test"]
}
PACKER
  packer init .
  packer validate .
'

# --- SWA CLI functional: deploy subcommand loads its modules ------------
# `swa deploy --help` forces deploy-path imports (native bindings, lazy
# sub-packages) so we catch any regression from `--ignore-scripts` skipping
# a post-install step that the deploy code path relies on.
run swa deploy --help

# --- Inheritance: vulcan tools still work -------------------------------
# Condensed — full set proven by vulcan.sh; here we prove inheritance.
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
