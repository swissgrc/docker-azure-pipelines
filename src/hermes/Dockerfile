# syntax=docker/dockerfile:1.7

# BASE_TAG is overridden by CI (`--build-arg BASE_TAG=<tag>`); the default
# here keeps `docker buildx build src/hermes` working without flags.
ARG BASE_TAG=latest


# ============================================================================
# base - vulcan's runtime, no additions needed
# ============================================================================
FROM ghcr.io/swissgrc/azure-pipelines-vulcan:${BASE_TAG} AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]


# ============================================================================
# final - runtime image
# ============================================================================
FROM base AS final

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /

LABEL org.opencontainers.image.vendor="Swiss GRC AG" \
      org.opencontainers.image.authors="Swiss GRC AG <opensource@swissgrc.com>" \
      org.opencontainers.image.title="azure-pipelines-hermes" \
      org.opencontainers.image.documentation="https://github.com/swissgrc/docker-azure-pipelines"

# renovate: datasource=npm depName=renovate
ENV RENOVATE_VERSION=43.138.3

# Renovate. Scripts deliberately enabled (no `--ignore-scripts`) so the
# `re2` post-install step can fetch its prebuilt native binary. Without RE2,
# Renovate's regex managers fall back to V8's engine, which can hang on
# adversarial patterns supplied through `renovate.json`.
RUN npm install -g "renovate@${RENOVATE_VERSION}" && \
    renovate --version && \
    rm -rf /root/.npm /tmp/node-compile-cache

# Inline smoke test omitted since Renovate's own smoke test is just `renovate --version`
# (which we run above) and the rest of the tools are tested in the e2e pipeline.


# ============================================================================
# test - smoke tests against the final image; driven by bake with
#        output=cacheonly so the result layer is discarded after assertions.
# ============================================================================
FROM final AS test

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- hermes's own tool ---------------------------------------------------
RUN renovate --version

# --- Renovate functional: CLI help loads all managers -------------------
# `renovate --help` exercises module loading across every manager (npm,
# nuget, etc.) and datasource. Catches a broken post-install step that
# left RE2 or another native dep in an unusable state.
RUN renovate --help

# --- RE2 native module loads --------------------------------------------
# Exercise RE2 directly to catch prebuilt-binary mismatches. If the `re2`
# post-install step didn't run (or the prebuilt binary doesn't match the
# runtime), require() throws at load time and this test fails fast — with
# a clearer signal than a buried Renovate startup error.
# `re2` is a nested dep of renovate (not a top-level global), so NODE_PATH
# must point at renovate's own node_modules — $(npm root -g) alone isn't
# enough since Node's resolver doesn't descend into sibling packages.
RUN <<'EOF'
set -euo pipefail
NODE_PATH="$(npm root -g)/renovate/node_modules" node -e 'const RE2 = require("re2"); if (!new RE2("^\\d+$").test("42")) process.exit(1)'
EOF

# --- Inheritance: vulcan tools still work -------------------------------
RUN dotnet --version && \
    dotnet --list-sdks && \
    node --version && \
    npm --version

# --- Inheritance: terra tools still work --------------------------------
RUN git --version && \
    docker --version && \
    jq --version && \
    yq --version && \
    claude --version && \
    copilot --version
