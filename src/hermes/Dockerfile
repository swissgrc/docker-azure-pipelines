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
