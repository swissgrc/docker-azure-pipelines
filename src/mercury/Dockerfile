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


# ============================================================================
# test - smoke tests against the final image; driven by bake with
#        output=cacheonly so the result layer is discarded after assertions.
# ============================================================================
FROM final AS test

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- mercury's own tool -------------------------------------------------
RUN playwright --version

# --- Browser install path is set, populated, and world-readable --------
RUN test -d /ms-playwright
RUN test "$PLAYWRIGHT_BROWSERS_PATH" = "/ms-playwright"
RUN test "$(stat -c %a /ms-playwright)" = "777"

# --- Playwright functional: each browser launches headless -------------
# Launch each browser, open about:blank, verify the user-agent string.
# Exercises the full native-dep chain: if any shared library is missing,
# the browser exits non-zero at launch with a loader error naming the lib.
# NODE_PATH points at the global node_modules root so `require("playwright")`
# resolves against the globally-installed package.
RUN <<'EOF'
set -euo pipefail
export NODE_PATH="$(npm root -g)"
for BROWSER in chromium firefox webkit; do
  node -e "
    const { $BROWSER } = require('playwright');
    (async () => {
      const browser = await $BROWSER.launch();
      const ctx = await browser.newContext();
      const page = await ctx.newPage();
      await page.goto('about:blank');
      const ua = await page.evaluate(() => navigator.userAgent);
      if (!ua || !ua.length) process.exit(1);
      console.log('$BROWSER:', ua);
      await browser.close();
    })().catch(e => { console.error(e); process.exit(1); });
  "
done
EOF

# --- Inheritance: vulcan tools still work ------------------------------
RUN dotnet --version && \
    dotnet --list-sdks && \
    node --version && \
    npm --version

# --- Inheritance: terra tools still work -------------------------------
RUN git --version && \
    docker --version && \
    jq --version && \
    yq --version && \
    claude --version && \
    copilot --version
