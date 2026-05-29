# syntax=docker/dockerfile:1.24

# BASE_TAG is overridden by CI (`--build-arg BASE_TAG=<tag>`); the default
# here keeps `docker buildx build src/vulcan` working without flags.
ARG BASE_TAG=latest


# ============================================================================
# base - minimal runtime deps that need to exist in `final` too
# ============================================================================
FROM ghcr.io/swissgrc/azure-pipelines-terra:${BASE_TAG} AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]


# ============================================================================
# build - download tools; everything here is discarded from `final`.
# ============================================================================
FROM base AS build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- APT helpers (build-stage only) --------------------------------------
# renovate: datasource=repology depName=debian_13/gnupg2 versioning=deb
ENV GNUPG_VERSION=2.4.7-21+deb13u1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gnupg="${GNUPG_VERSION}" && \
    rm -rf /var/lib/apt/lists/*

# --- .NET SDK 9 (bypasses dotnet-install.sh) -----------------------------
# renovate: datasource=dotnet-version depName=dotnet-sdk
ENV DOTNET9_VERSION=9.0.314

ADD https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET9_VERSION}/dotnet-sdk-${DOTNET9_VERSION}-linux-x64.tar.gz /tmp/
ADD https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET9_VERSION}/dotnet-sdk-${DOTNET9_VERSION}-linux-x64.tar.gz.sha512 /tmp/

RUN expected_sha=$(awk '{print $1}' "/tmp/dotnet-sdk-${DOTNET9_VERSION}-linux-x64.tar.gz.sha512") && \
    echo "${expected_sha}  /tmp/dotnet-sdk-${DOTNET9_VERSION}-linux-x64.tar.gz" | sha512sum -c - && \
    mkdir -p /usr/share/dotnet && \
    tar -xzf "/tmp/dotnet-sdk-${DOTNET9_VERSION}-linux-x64.tar.gz" -C /usr/share/dotnet && \
    /usr/share/dotnet/dotnet --list-sdks | grep -q "^9\\." && \
    rm "/tmp/dotnet-sdk-${DOTNET9_VERSION}-linux-x64.tar.gz" \
        "/tmp/dotnet-sdk-${DOTNET9_VERSION}-linux-x64.tar.gz.sha512"

# --- .NET SDK 10 (bypasses dotnet-install.sh) ----------------------------
# renovate: datasource=dotnet-version depName=dotnet-sdk
ENV DOTNET10_VERSION=10.0.300

ADD https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET10_VERSION}/dotnet-sdk-${DOTNET10_VERSION}-linux-x64.tar.gz /tmp/
ADD https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET10_VERSION}/dotnet-sdk-${DOTNET10_VERSION}-linux-x64.tar.gz.sha512 /tmp/

RUN expected_sha=$(awk '{print $1}' "/tmp/dotnet-sdk-${DOTNET10_VERSION}-linux-x64.tar.gz.sha512") && \
    echo "${expected_sha}  /tmp/dotnet-sdk-${DOTNET10_VERSION}-linux-x64.tar.gz" | sha512sum -c - && \
    tar -xzf "/tmp/dotnet-sdk-${DOTNET10_VERSION}-linux-x64.tar.gz" -C /usr/share/dotnet && \
    /usr/share/dotnet/dotnet --list-sdks | grep -q "^9\\." && \
    /usr/share/dotnet/dotnet --list-sdks | grep -q "^10\\." && \
    rm "/tmp/dotnet-sdk-${DOTNET10_VERSION}-linux-x64.tar.gz" \
        "/tmp/dotnet-sdk-${DOTNET10_VERSION}-linux-x64.tar.gz.sha512"

# --- NodeSource APT repo (keyring + source list; nodejs installed in `final`)
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
        gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    chmod a+r /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list

# --- uv ------------------------------------------------------------------
# renovate: datasource=github-releases depName=astral-sh/uv
ENV UV_VERSION=0.11.17

ADD https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz /tmp/uv.tar.gz
ADD https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz.sha256 /tmp/uv.tar.gz.sha256

RUN expected_sha=$(awk '{print $1}' /tmp/uv.tar.gz.sha256) && \
    echo "${expected_sha}  /tmp/uv.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/uv.tar.gz -C /tmp/ && \
    /tmp/uv-x86_64-unknown-linux-gnu/uv --version


# ============================================================================
# final - runtime image
# ============================================================================
FROM base AS final

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /

LABEL org.opencontainers.image.vendor="Swiss GRC AG" \
      org.opencontainers.image.authors="Swiss GRC AG <opensource@swissgrc.com>" \
      org.opencontainers.image.title="azure-pipelines-vulcan" \
      org.opencontainers.image.documentation="https://github.com/swissgrc/docker-azure-pipelines"

# renovate: datasource=repology depName=debian_13/fontconfig versioning=deb
ENV FONTCONFIG_VERSION=2.15.0-2.3

# .NET needs ICU for globalization (TimeZone/CultureInfo init). Microsoft
# Only ICU is not yet shipped from terra base images
# renovate: datasource=repology depName=debian_13/icu versioning=deb
ENV LIBICU_VERSION=76.1-4

# renovate: datasource=github-tags depName=nodejs/node extractVersion=^v(?<version>.*)$
ENV NODE_VERSION=24.15.0

# renovate: datasource=repology depName=debian_13/python3-defaults versioning=deb
ENV PYTHON3_VERSION=3.13.5-1

# Bring keyrings + source list in from `build`.
COPY --from=build /etc/apt/keyrings/nodesource.gpg /etc/apt/keyrings/nodesource.gpg
COPY --from=build /etc/apt/sources.list.d/nodesource.list /etc/apt/sources.list.d/nodesource.list

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        fontconfig="${FONTCONFIG_VERSION}" \
        libicu76="${LIBICU_VERSION}" \
        "nodejs=${NODE_VERSION}-1nodesource1" \
        "python3=${PYTHON3_VERSION}" && \
    rm -rf /var/lib/apt/lists/*

# .NET SDKs 9 + 10
COPY --from=build /usr/share/dotnet /usr/share/dotnet
RUN ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

# --- uv ------------------------------------------------------------------
COPY --from=build /tmp/uv-x86_64-unknown-linux-gnu/uv /usr/local/bin/uv
COPY --from=build /tmp/uv-x86_64-unknown-linux-gnu/uvx /usr/local/bin/uvx

# --- Node package managers (npm, yarn, pnpm) -----------------------------
# renovate: datasource=github-tags depName=npm/cli extractVersion=^v(?<version>.*)$
ENV NPM_VERSION=11.15.0
# renovate: datasource=github-tags depName=yarnpkg/yarn extractVersion=^v(?<version>.*)$
ENV YARN_VERSION=1.22.22
# renovate: datasource=github-tags depName=pnpm/pnpm extractVersion=^v(?<version>.*)$
ENV PNPM_VERSION=11.4.0

RUN npm install -g --ignore-scripts \
        "npm@${NPM_VERSION}" \
        "yarn@${YARN_VERSION}" \
        "pnpm@${PNPM_VERSION}" && \
    npm --version && \
    yarn --version && \
    pnpm --version && \
    rm -rf /root/.npm /tmp/node-compile-cache

# --- .NET env + PATH (preserved verbatim from existing dotnet-* images) ---
# PATH prefix is redundant with the /usr/bin/dotnet symlink but guarantees
# discovery if an inherited PATH ever reorders /usr/bin.
ENV DOTNET_NOLOGO=true \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true \
    DOTNET_CLI_TELEMETRY_OPTOUT=true \
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    NUGET_XMLDOC_MODE=skip \
    PATH="/usr/share/dotnet:${PATH}"

# Prevent uv from downloading Python (use system-installed python3) and use
# copy link mode which is safe inside containers.
ENV UV_PYTHON_DOWNLOADS=never \
    UV_LINK_MODE=copy

# Inline smoke tests + cleanup in one layer.
RUN dotnet --version && \
    dotnet --list-sdks | grep "^9\\." && \
    dotnet --list-sdks | grep "^10\\." && \
    node --version && \
    npm --version && \
    yarn --version && \
    pnpm --version && \
    python3 --version && \
    uv --version && \
    fc-list | head -n1 && \
    apt-get clean && \
    rm -rf \
        /var/lib/apt/lists/* /var/cache/apt/archives/* \
        /tmp/* /root/.cache \
        /root/.npm /root/.local/share/pnpm


# ============================================================================
# test - smoke tests against the final image; driven by bake with
#        output=cacheonly so the result layer is discarded after assertions.
# ============================================================================
FROM final AS test

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- vulcan's own tools --------------------------------------------------
# hadolint ignore=DL3059
RUN dotnet --version && \
    dotnet --list-sdks && \
    node --version && \
    npm --version && \
    yarn --version && \
    pnpm --version && \
    python3 --version && \
    uv --version && \
    fc-list --version

# --- .NET env vars are actually exported --------------------------------
# hadolint ignore=DL3059
RUN test "$(printenv DOTNET_NOLOGO)" = "true" && \
    test "$(printenv DOTNET_CLI_TELEMETRY_OPTOUT)" = "true" && \
    test "$(printenv NUGET_XMLDOC_MODE)" = "skip" && \
    test "$(printenv DISABLE_AUTOUPDATER)" = "1"

# --- Functional: both SDKs compile end-to-end ---------------------------
# hadolint ignore=DL3059
RUN <<'EOF'
set -euo pipefail
tmp="$(mktemp -d)"
dotnet new console --framework net9.0 -o "$tmp/app9" && dotnet build -f net9.0 "$tmp/app9"
dotnet new console --framework net10.0 -o "$tmp/app10" && dotnet build -f net10.0 "$tmp/app10"
EOF

# --- Functional: Node runs scripts --------------------------------------
# hadolint ignore=DL3059
RUN test "$(echo 'console.log(2 + 2)' | node)" = "4"

# --- Functional: uv uses system Python 3.13 ----------------------------
# hadolint ignore=DL3059
RUN uv run --no-project --python python3 python3 -c "import sys; assert sys.version_info >= (3, 13), sys.version"

# --- Functional: Yarn and pnpm reach their respective registries --------
# Exercises outbound HTTPS + package manager resolution without a full install.
# hadolint ignore=DL3059
RUN yarn info lodash name
# hadolint ignore=DL3059
RUN pnpm info lodash name

# --- Inheritance: every terra tool still works --------------------------
# Condensed — full set proven by terra's test stage; here we prove inheritance,
# not retest each tool.
# hadolint ignore=DL3059
RUN git --version && \
    docker --version && \
    jq --version && \
    yq --version && \
    claude --version && \
    copilot --version
