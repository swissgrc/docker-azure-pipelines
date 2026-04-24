# syntax=docker/dockerfile:1.23

# BASE_TAG is overridden by CI (`--build-arg BASE_TAG=<tag>`); the default
# here keeps `docker buildx build src/janus` working without flags.
ARG BASE_TAG=latest


# ============================================================================
# base - minimal runtime deps that need to exist in `final` too
# ============================================================================
FROM ghcr.io/swissgrc/azure-pipelines-vulcan:${BASE_TAG} AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]


# ============================================================================
# build - download tools; everything here is discarded from `final`.
# ============================================================================
FROM base AS build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- APT helpers (build-stage only) --------------------------------------
# Only gnupg is needed — curl + unzip are inherited from terra.
# renovate: datasource=repology depName=debian_13/gnupg2 versioning=deb
ENV GNUPG_VERSION=2.4.7-21+deb13u1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gnupg="${GNUPG_VERSION}" && \
    rm -rf /var/lib/apt/lists/*

# --- Azure CLI APT repo (key + source list; package installed in `final`) -
# Microsoft does not publish a `trixie` suite; hardcode `bookworm`.
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
        gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg && \
    chmod a+r /etc/apt/keyrings/microsoft.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ bookworm main" \
        > /etc/apt/sources.list.d/azure-cli.list

# --- Terraform -----------------------------------------------------------
# renovate: datasource=github-tags depName=hashicorp/terraform extractVersion=^v(?<version>.*)$
ENV TERRAFORM_VERSION=1.13.3

RUN base="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}" && \
    curl -fsSL -o /tmp/terraform.zip "${base}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" && \
    curl -fsSL -o /tmp/terraform_SHA256SUMS "${base}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" && \
    expected_sha=$(grep -E '[[:space:]]terraform_'"${TERRAFORM_VERSION}"'_linux_amd64\.zip$' /tmp/terraform_SHA256SUMS | awk '{print $1}') && \
    echo "${expected_sha}  /tmp/terraform.zip" | sha256sum -c - && \
    unzip -q /tmp/terraform.zip terraform -d /tmp && \
    /tmp/terraform --version && \
    rm /tmp/terraform.zip /tmp/terraform_SHA256SUMS

# --- Packer --------------------------------------------------------------
# renovate: datasource=github-tags depName=hashicorp/packer extractVersion=^v(?<version>.*)$
ENV PACKER_VERSION=1.15.1

RUN base="https://releases.hashicorp.com/packer/${PACKER_VERSION}" && \
    curl -fsSL -o /tmp/packer.zip "${base}/packer_${PACKER_VERSION}_linux_amd64.zip" && \
    curl -fsSL -o /tmp/packer_SHA256SUMS "${base}/packer_${PACKER_VERSION}_SHA256SUMS" && \
    expected_sha=$(grep -E '[[:space:]]packer_'"${PACKER_VERSION}"'_linux_amd64\.zip$' /tmp/packer_SHA256SUMS | awk '{print $1}') && \
    echo "${expected_sha}  /tmp/packer.zip" | sha256sum -c - && \
    unzip -q /tmp/packer.zip packer -d /tmp && \
    /tmp/packer --version && \
    rm /tmp/packer.zip /tmp/packer_SHA256SUMS

# --- tflint --------------------------------------------------------------
# renovate: datasource=github-releases depName=terraform-linters/tflint extractVersion=^v(?<version>.*)$
ENV TFLINT_VERSION=0.62.0

RUN base="https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}" && \
    curl -fsSL -o /tmp/tflint.zip "${base}/tflint_linux_amd64.zip" && \
    curl -fsSL -o /tmp/tflint_checksums.txt "${base}/checksums.txt" && \
    expected_sha=$(grep -E '[[:space:]]tflint_linux_amd64\.zip$' /tmp/tflint_checksums.txt | awk '{print $1}') && \
    echo "${expected_sha}  /tmp/tflint.zip" | sha256sum -c - && \
    unzip -q /tmp/tflint.zip tflint -d /tmp && \
    /tmp/tflint --version && \
    rm /tmp/tflint.zip /tmp/tflint_checksums.txt

# --- Helm ----------------------------------------------------------------
# renovate: datasource=github-tags depName=helm/helm extractVersion=^v(?<version>.*)$
ENV HELM_VERSION=4.1.4

RUN base="https://get.helm.sh" && \
    curl -fsSL -o /tmp/helm.tar.gz "${base}/helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
    curl -fsSL -o /tmp/helm.tar.gz.sha256 "${base}/helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256" && \
    expected_sha=$(awk '{print $1}' /tmp/helm.tar.gz.sha256) && \
    echo "${expected_sha}  /tmp/helm.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/helm.tar.gz -C /tmp --strip-components=1 linux-amd64/helm && \
    /tmp/helm version && \
    rm /tmp/helm.tar.gz /tmp/helm.tar.gz.sha256

# --- kubectl -------------------------------------------------------------
# renovate: datasource=github-tags depName=kubernetes/kubernetes extractVersion=^v(?<version>.*)$
ENV KUBECTL_VERSION=1.36.0

RUN base="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64" && \
    curl -fsSL -o /tmp/kubectl "${base}/kubectl" && \
    curl -fsSL -o /tmp/kubectl.sha256 "${base}/kubectl.sha256" && \
    expected_sha=$(awk '{print $1}' /tmp/kubectl.sha256) && \
    echo "${expected_sha}  /tmp/kubectl" | sha256sum -c - && \
    chmod +x /tmp/kubectl && \
    /tmp/kubectl version --client && \
    rm /tmp/kubectl.sha256

# --- kubelogin -----------------------------------------------------------
# renovate: datasource=github-releases depName=Azure/kubelogin extractVersion=^v(?<version>.*)$
ENV KUBELOGIN_VERSION=0.2.17

RUN base="https://github.com/Azure/kubelogin/releases/download/v${KUBELOGIN_VERSION}" && \
    curl -fsSL -o /tmp/kubelogin.zip "${base}/kubelogin-linux-amd64.zip" && \
    curl -fsSL -o /tmp/kubelogin.zip.sha256 "${base}/kubelogin-linux-amd64.zip.sha256" && \
    expected_sha=$(awk '{print $1}' /tmp/kubelogin.zip.sha256) && \
    echo "${expected_sha}  /tmp/kubelogin.zip" | sha256sum -c - && \
    unzip -jq /tmp/kubelogin.zip bin/linux_amd64/kubelogin -d /tmp && \
    /tmp/kubelogin --version && \
    rm /tmp/kubelogin.zip /tmp/kubelogin.zip.sha256


# ============================================================================
# final - runtime image
# ============================================================================
FROM base AS final

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /

LABEL org.opencontainers.image.vendor="Swiss GRC AG" \
      org.opencontainers.image.authors="Swiss GRC AG <opensource@swissgrc.com>" \
      org.opencontainers.image.title="azure-pipelines-janus" \
      org.opencontainers.image.documentation="https://github.com/swissgrc/docker-azure-pipelines"

# renovate: datasource=github-tags depName=Azure/azure-cli extractVersion=^azure-cli-(?<version>.*)$
ENV AZURE_CLI_VERSION=2.85.0

# renovate: datasource=npm depName=@azure/static-web-apps-cli
ENV SWA_CLI_VERSION=2.0.9

# Bring Microsoft keyring + source list in from `build`.
COPY --from=build /etc/apt/keyrings/microsoft.gpg /etc/apt/keyrings/microsoft.gpg
COPY --from=build /etc/apt/sources.list.d/azure-cli.list /etc/apt/sources.list.d/azure-cli.list

# Azure CLI
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        "azure-cli=${AZURE_CLI_VERSION}-1~bookworm" && \
    rm -rf /var/lib/apt/lists/*

# Single-binary tools from `build`.
COPY --from=build /tmp/terraform /usr/local/bin/terraform
COPY --from=build /tmp/tflint    /usr/local/bin/tflint
COPY --from=build /tmp/packer    /usr/local/bin/packer
COPY --from=build /tmp/helm      /usr/local/bin/helm
COPY --from=build /tmp/kubectl   /usr/local/bin/kubectl
COPY --from=build /tmp/kubelogin /usr/local/bin/kubelogin

# SWA CLI
RUN npm install -g --ignore-scripts \
        "@azure/static-web-apps-cli@${SWA_CLI_VERSION}" && \
    swa --version && \
    rm -rf /root/.npm /tmp/node-compile-cache

# Inline smoke tests + cleanup in one layer.
# /root/.azure is created by `az --version` on first invocation.
RUN az --version && \
    terraform --version && \
    tflint --version && \
    packer --version && \
    helm version && \
    kubectl version --client && \
    kubelogin --version && \
    swa --version && \
    apt-get clean && \
    rm -rf \
        /var/lib/apt/lists/* /var/cache/apt/archives/* \
        /tmp/* /root/.cache \
        /root/.npm \
        /root/.azure


# ============================================================================
# test - smoke tests against the final image; driven by bake with
#        output=cacheonly so the result layer is discarded after assertions.
# ============================================================================
FROM final AS test

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- janus's own tools ---------------------------------------------------
# hadolint ignore=DL3059
RUN az --version && \
    terraform --version && \
    tflint --version && \
    packer --version && \
    helm version && \
    kubectl version --client && \
    kubelogin --version && \
    swa --version

# --- Azure CLI functional: reaches Azure endpoints -----------------------
# `az extension list-available` downloads the public extension index from
# azcliextensionsync.blob.core.windows.net — a genuine anonymous HTTPS call
# that proves DNS + outbound networking + CLI initialization.
# hadolint ignore=DL3059
RUN az extension list-available --output table

# --- Terraform functional: inits and validates an empty config ----------
# hadolint ignore=DL3059
RUN <<'EOF'
set -euo pipefail
tmp="$(mktemp -d)"
echo "terraform { }" > "$tmp/main.tf"
terraform -chdir="$tmp" init
terraform -chdir="$tmp" validate
EOF

# --- Helm functional: adds a public chart repo --------------------------
# kubernetes-sigs/metrics-server is an actively maintained chart repo.
# hadolint ignore=DL3059
RUN <<'EOF'
set -euo pipefail
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm search repo metrics-server/
EOF

# --- kubectl functional: binary loads and parses flags without a cluster
# hadolint ignore=DL3059
RUN kubectl api-resources --help

# --- Packer functional: inits and validates an empty template -----------
# hadolint ignore=DL3059
RUN <<'EOF'
set -euo pipefail
tmp="$(mktemp -d)"
cat > "$tmp/main.pkr.hcl" <<PACKER
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
packer init "$tmp"
packer validate "$tmp"
EOF

# --- SWA CLI functional: deploy subcommand loads its modules ------------
# `swa deploy --help` forces deploy-path imports (native bindings, lazy
# sub-packages) so we catch any regression from `--ignore-scripts` skipping
# a post-install step that the deploy code path relies on.
# hadolint ignore=DL3059
RUN swa deploy --help

# --- Inheritance: vulcan tools still work -------------------------------
# Condensed — full set proven by vulcan's test stage; here we prove inheritance.
# hadolint ignore=DL3059
RUN dotnet --version && \
    dotnet --list-sdks && \
    node --version && \
    npm --version

# --- Inheritance: terra tools still work --------------------------------
# hadolint ignore=DL3059
RUN git --version && \
    docker --version && \
    jq --version && \
    yq --version && \
    claude --version && \
    copilot --version
