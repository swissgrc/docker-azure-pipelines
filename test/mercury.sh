#!/usr/bin/env bash
# Smoke tests for azure-pipelines-mercury.
# Usage: test/mercury.sh <image-ref>
#   e.g. test/mercury.sh ghcr.io/swissgrc/azure-pipelines-mercury:2026.04.21.0
#
# Every assertion is one `docker run` so failures are easy to read in CI logs.
# All dependencies live inside the container — the host only needs docker.

set -euo pipefail

IMAGE="${1:?usage: test/mercury.sh <image-ref>}"

run() { docker run --rm "$IMAGE" "$@"; }

# --- mercury's own tool -------------------------------------------------
run playwright --version

# --- Browser install path is set, populated, and world-readable --------
run test -d /ms-playwright
run bash -c 'test "$PLAYWRIGHT_BROWSERS_PATH" = "/ms-playwright"'
run bash -c 'test "$(stat -c %a /ms-playwright)" = "777"'

# --- Playwright functional: each browser launches headless -------------
# Launch each browser, open about:blank, verify the user-agent string.
# Exercises the full native-dep chain: if any shared library is missing,
# the browser exits non-zero at launch with a loader error naming the lib.
# NODE_PATH points at the global node_modules root so `require("playwright")`
# resolves against the globally-installed package.
for BROWSER in chromium firefox webkit; do
  docker run --rm "$IMAGE" bash -c "
    set -euo pipefail
    NODE_PATH=\"\$(npm root -g)\" node -e \"
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
    \"
  "
done

# --- Inheritance: vulcan tools still work ------------------------------
run dotnet --version
run dotnet --list-sdks
run node --version
run npm --version

# --- Inheritance: terra tools still work -------------------------------
run git --version
run docker --version
run jq --version
run yq --version
run claude --version
run copilot --version
