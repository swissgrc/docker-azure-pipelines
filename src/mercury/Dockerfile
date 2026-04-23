# syntax=docker/dockerfile:1.7

# BASE_TAG is overridden by CI (`--build-arg BASE_TAG=<tag>`); the default
# here keeps `docker buildx build src/mercury` working without flags.
ARG BASE_TAG=latest


# ============================================================================
# base - minimal runtime deps that need to exist in `final` too
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
      org.opencontainers.image.title="azure-pipelines-mercury" \
      org.opencontainers.image.documentation="https://github.com/swissgrc/docker-azure-pipelines"

# renovate: datasource=npm depName=playwright
ENV PLAYWRIGHT_VERSION=1.59.1

# Matches the official Playwright image path. Downstream pipelines inherit
# this env var and find browsers without extra configuration.
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# Install the Playwright CLI, then install browsers + their system deps.
# `--ignore-scripts` skips Playwright's auto-browser postinstall (which in
# some versions ignores PLAYWRIGHT_BROWSERS_PATH and writes to /root/.cache).
# `playwright install --with-deps` runs `apt-get update` + `apt-get install`
# under the hood — clean the apt cache in the same RUN so it doesn't bleed
# into this layer. /ms-playwright is intentionally preserved.
RUN npm install -g --ignore-scripts \
        "playwright@${PLAYWRIGHT_VERSION}" && \
    playwright --version && \
    playwright install --with-deps chromium firefox webkit && \
    chmod -R 777 /ms-playwright && \
    apt-get clean && \
    rm -rf \
        /var/lib/apt/lists/* /var/cache/apt/archives/* \
        /root/.cache \
        /root/.npm /tmp/node-compile-cache

# Inline smoke test omitted since Playwright's own smoke test is just `playwright --version`
# (which we run above) and the browsers are tested in the e2e pipeline.
