# syntax=docker/dockerfile:1.26

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
ENV RENOVATE_VERSION=44.32.2

# Renovate. Install with every lifecycle script blocked, then build exactly the
# one that is actually needed: `re2` fetches a prebuilt native binary from its
# install script. Without RE2, Renovate's regex managers fall back to V8's
# engine, which can hang on adversarial patterns supplied through
# `renovate.json` — and that fallback is silent, so the RE2 smoke test below is
# what catches it.
# Both flags are load-bearing. npm 12 blocks lifecycle scripts unless they are
# allow-listed, and that applies to `npm rebuild` too — without --allow-scripts
# the rebuild prints "rebuilt dependencies successfully", exits 0 and does
# nothing, which is why the smoke test rather than the exit code is the guard
# here. Naming re2 keeps the grant to a single package: the others npm would
# otherwise run are not needed anyway, since `core-js-pure` wraps its postinstall
# in try/catch and `dtrace-provider` falls back to `suppress-error.js`.
RUN npm install -g --ignore-scripts "renovate@${RENOVATE_VERSION}" && \
    npm rebuild -g --allow-scripts=re2 re2 && \
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
# hadolint ignore=DL3059
RUN renovate --version

# --- Renovate functional: CLI help loads all managers -------------------
# `renovate --help` exercises module loading across every manager (npm,
# nuget, etc.) and datasource. Catches a broken post-install step that
# left RE2 or another native dep in an unusable state.
# hadolint ignore=DL3059
RUN renovate --help

# --- RE2 native module loads --------------------------------------------
# Exercise RE2 directly to catch prebuilt-binary mismatches. If the `re2`
# post-install step didn't run (or the prebuilt binary doesn't match the
# runtime), require() throws at load time and this test fails fast — with
# a clearer signal than a buried Renovate startup error.
# `re2` is a nested dep of renovate (not a top-level global), so it has to be
# resolved from inside renovate's own package. Don't assemble that path from
# `$(npm root -g)` by hand: where npm places a global package underneath that
# root is an implementation detail, and it changed in npm 12. Point NODE_PATH
# at the global root so `renovate` itself resolves, then let Node walk up from
# there to find `re2` the way it normally would.
# hadolint ignore=DL3059
RUN <<'EOF'
set -euo pipefail
NODE_PATH="$(npm root -g)" node -e '
  const path = require("path");
  const renovateDir = path.dirname(require.resolve("renovate/package.json"));
  const RE2 = require(require.resolve("re2", { paths: [renovateDir] }));
  if (!new RE2("^\\d+$").test("42")) process.exit(1);
'
EOF

# --- Inheritance: vulcan tools still work -------------------------------
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
