# syntax=docker/dockerfile:1.7

# ============================================================================
# base - minimal runtime deps that need to exist in `final` too.
# ============================================================================
FROM debian:13.4-slim@sha256:4ffb3a1511099754cddc70eb1b12e50ffdb67619aa0ab6c13fcd800a78ef7c7a AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# renovate: datasource=repology depName=debian_13/ca-certificates versioning=loose
ENV CA_CERTIFICATES_VERSION=20250419

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates="${CA_CERTIFICATES_VERSION}" && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*


# ============================================================================
# build - compile/download tools; everything here is discarded from `final`.
# ============================================================================
FROM base AS build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- APT helpers (build-stage only) ---------------------------------------
# renovate: datasource=repology depName=debian_13/curl versioning=deb
ENV CURL_VERSION=8.14.1-2+deb13u2
# renovate: datasource=repology depName=debian_13/gnupg2 versioning=deb
ENV GNUPG_VERSION=2.4.7-21+deb13u1
# renovate: datasource=repology depName=debian_13/lsb-release versioning=deb
ENV LSB_RELEASE_VERSION=12.1-1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl="${CURL_VERSION}" \
        gnupg="${GNUPG_VERSION}" \
        lsb-release="${LSB_RELEASE_VERSION}" && \
    rm -rf /var/lib/apt/lists/*

# --- jq -------------------------------------------------------------------
# renovate: datasource=github-releases depName=jqlang/jq extractVersion=^jq-(?<version>.*)$
ENV JQ_VERSION=1.8.0

ADD --chmod=755 https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64 /tmp/jq
ADD https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/sha256sum.txt /tmp/jq-sha256.txt
RUN expected_sha=$(grep -E '[[:space:]]jq-linux-amd64$' /tmp/jq-sha256.txt | awk '{print $1}') && \
    echo "${expected_sha}  /tmp/jq" | sha256sum -c - && \
    /tmp/jq --version

# --- yq -------------------------------------------------------------------
# renovate: datasource=github-releases depName=mikefarah/yq extractVersion=^v(?<version>.*)$
ENV YQ_VERSION=4.52.4

ADD --chmod=755 https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64 /tmp/yq
ADD https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/checksums /tmp/yq-checksums
ADD https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/checksums_hashes_order /tmp/yq-hashes-order

# yq ships one wide checksums file with many hash columns; checksums_hashes_order
# names each column in order. Look up the SHA-256 column dynamically so a future
# release that reorders columns doesn't silently verify against the wrong hash.
RUN sha256_col=$(awk '$0=="SHA-256" {print NR; exit}' /tmp/yq-hashes-order) && \
    expected_sha=$(awk -v c=$((sha256_col + 1)) '$1=="yq_linux_amd64" {print $c}' /tmp/yq-checksums) && \
    echo "${expected_sha}  /tmp/yq" | sha256sum -c - && \
    /tmp/yq --version

# --- Git from source ------------------------------------------------------
# renovate: datasource=github-tags depName=git/git extractVersion=^v(?<version>.*)$
ENV GIT_VERSION=2.53.0

# Repology has no debian_13 data for build-essential, so we query the apt
# archive directly via Renovate's `deb` datasource.
# renovate: datasource=deb depName=build-essential registryUrl=https://deb.debian.org/debian?suite=trixie&components=main&binaryArch=amd64 versioning=deb
ENV BUILD_ESSENTIAL_VERSION=12.12
# renovate: datasource=repology depName=debian_13/dh-autoreconf versioning=deb
ENV DH_AUTORECONF_VERSION=20
# renovate: datasource=repology depName=debian_13/gettext versioning=deb
ENV GETTEXT_VERSION=0.23.1-2
# renovate: datasource=repology depName=debian_13/libcurl4-gnutls-dev versioning=deb
ENV LIBCURL4_GNUTLS_DEV_VERSION=8.14.1-2+deb13u2
# renovate: datasource=repology depName=debian_13/libexpat1-dev versioning=deb
ENV LIBEXPAT1_DEV_VERSION=2.7.1-2
# renovate: datasource=repology depName=debian_13/openssl versioning=deb
ENV LIBSSL_DEV_VERSION=3.5.5-1~deb13u2
# renovate: datasource=repology depName=debian_13/zlib versioning=deb
ENV ZLIB1G_DEV_VERSION=1:1.3.dfsg+really1.3.1-1+b1

# Install Git build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential="${BUILD_ESSENTIAL_VERSION}" \
        dh-autoreconf="${DH_AUTORECONF_VERSION}" \
        gettext="${GETTEXT_VERSION}" \
        libcurl4-gnutls-dev="${LIBCURL4_GNUTLS_DEV_VERSION}" \
        libexpat1-dev="${LIBEXPAT1_DEV_VERSION}" \
        libssl-dev="${LIBSSL_DEV_VERSION}" \
        zlib1g-dev="${ZLIB1G_DEV_VERSION}" && \
    rm -rf /var/lib/apt/lists/*

# Compile Git from source. prefix/sysconfdir are passed as make variables
# (Git's Makefile honors them) so we skip ./configure entirely — autoconf
# would require `cd` into the source tree. sysconfdir=/etc matches Debian's
# layout so `git config --system` and `git lfs install --system` write to
# /etc/gitconfig, not /usr/etc/gitconfig.
ADD https://github.com/git/git/archive/refs/tags/v${GIT_VERSION}.tar.gz /tmp/git.tar.gz
RUN tar -xzf /tmp/git.tar.gz -C /tmp && \
    make -C "/tmp/git-${GIT_VERSION}" prefix=/usr sysconfdir=/etc -j"$(nproc)" install && \
    git --version

# --- Git LFS (upstream tarball; avoids APT pulling in `git` + Perl transitively)
# renovate: datasource=github-releases depName=git-lfs/git-lfs extractVersion=^v(?<version>.*)$
ENV GIT_LFS_VERSION=3.5.1

# sha256sums.asc is a PGP cleartext-signed list in binary-mode sha256sum format
# (`<hash> *<file>`). We verify the hash only — the `*FILENAME` pattern also
# naturally excludes the PGP headers/footers from the grep.
RUN base="https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}" && \
    curl -fsSL -o /tmp/git-lfs.tar.gz     "${base}/git-lfs-linux-amd64-v${GIT_LFS_VERSION}.tar.gz" && \
    curl -fsSL -o /tmp/git-lfs-sha256.asc "${base}/sha256sums.asc" && \
    expected_sha=$(grep -E "\*git-lfs-linux-amd64-v${GIT_LFS_VERSION}\.tar\.gz$" /tmp/git-lfs-sha256.asc | awk '{print $1}') && \
    echo "${expected_sha}  /tmp/git-lfs.tar.gz" | sha256sum -c - && \
    mkdir -p /tmp/git-lfs-extract && \
    tar -xzf /tmp/git-lfs.tar.gz -C /tmp/git-lfs-extract --strip-components=1 && \
    install -m 0755 /tmp/git-lfs-extract/git-lfs /tmp/git-lfs && \
    /tmp/git-lfs version && \
    rm -rf /tmp/git-lfs.tar.gz /tmp/git-lfs-sha256.asc /tmp/git-lfs-extract

# --- Docker APT repo (key + source list; plugins installed in `final`) ---
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list

# --- Claude CLI (bypasses install.sh for reproducibility ------------------
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ENV CLAUDE_VERSION=2.1.105

ENV CLAUDE_KEY_FINGERPRINT=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
# Anthropic's GCS distribution bucket. If this ever 403s, check the canonical
# URL in the upstream installer at https://claude.ai/install.sh - the UUID is
# part of the bucket name and would change on rotation.
ENV CLAUDE_RELEASES=https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases

RUN GNUPGHOME="$(mktemp -d)" && export GNUPGHOME && \
    curl -fsSL https://downloads.claude.ai/keys/claude-code.asc | gpg --import && \
    gpg --list-keys --with-colons --fingerprint | \
        awk -F: '/^fpr:/ {print $10; exit}' | \
        grep -qx "${CLAUDE_KEY_FINGERPRINT}" && \
    curl -fsSL -o /tmp/manifest.json     "${CLAUDE_RELEASES}/${CLAUDE_VERSION}/manifest.json" && \
    curl -fsSL -o /tmp/manifest.json.sig "${CLAUDE_RELEASES}/${CLAUDE_VERSION}/manifest.json.sig" && \
    gpg --verify /tmp/manifest.json.sig /tmp/manifest.json && \
    expected_sha=$(/tmp/jq -r '.platforms."linux-x64".checksum' /tmp/manifest.json) && \
    curl -fsSL -o /tmp/claude "${CLAUDE_RELEASES}/${CLAUDE_VERSION}/linux-x64/claude" && \
    echo "${expected_sha}  /tmp/claude" | sha256sum -c - && \
    chmod +x /tmp/claude && \
    /tmp/claude --version && \
    rm -rf "${GNUPGHOME}" /tmp/manifest.json /tmp/manifest.json.sig

# --- Copilot CLI ----------------------------------------------------------
# renovate: datasource=github-releases depName=github/copilot-cli extractVersion=^v(?<version>.*)$
ENV COPILOT_VERSION=1.0.24

RUN base="https://github.com/github/copilot-cli/releases/download/v${COPILOT_VERSION}" && \
    curl -fsSL -o /tmp/copilot.tar.gz "${base}/copilot-linux-x64.tar.gz" && \
    curl -fsSL -o /tmp/SHA256SUMS.txt "${base}/SHA256SUMS.txt" && \
    expected_sha=$(grep -E '[[:space:]]copilot-linux-x64\.tar\.gz$' /tmp/SHA256SUMS.txt | awk '{print $1}') && \
    echo "${expected_sha}  /tmp/copilot.tar.gz" | sha256sum -c - && \
    mkdir -p /tmp/copilot-extract && \
    tar -xzf /tmp/copilot.tar.gz -C /tmp/copilot-extract && \
    install -m 0755 /tmp/copilot-extract/copilot /tmp/copilot && \
    /tmp/copilot --version && \
    rm -rf /tmp/copilot.tar.gz /tmp/SHA256SUMS.txt /tmp/copilot-extract


# ============================================================================
# final - runtime image
# ============================================================================
FROM base AS final

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /

LABEL org.opencontainers.image.vendor="Swiss GRC AG" \
      org.opencontainers.image.authors="Swiss GRC AG <opensource@swissgrc.com>" \
      org.opencontainers.image.title="azure-pipelines-terra" \
      org.opencontainers.image.documentation="https://github.com/swissgrc/docker-azure-pipelines"

# renovate: datasource=repology depName=debian_13/curl versioning=deb
ENV CURL_VERSION=8.14.1-2+deb13u2
# renovate: datasource=repology depName=debian_13/curl versioning=deb
ENV LIBCURL3_GNUTLS_VERSION=8.14.1-2+deb13u2
# renovate: datasource=repology depName=debian_13/unzip versioning=deb
ENV UNZIP_VERSION=6.0-29

# renovate: datasource=github-tags depName=docker/cli extractVersion=^v(?<version>.*)$
ENV DOCKER_CLI_VERSION=29.4.0
# renovate: datasource=github-tags depName=docker/buildx extractVersion=^v(?<version>.*)$
ENV DOCKER_BUILDX_VERSION=0.33.0
# renovate: datasource=github-tags depName=docker/compose extractVersion=^v(?<version>.*)$
ENV DOCKER_COMPOSE_VERSION=5.1.3

# Bring keyring + source list file in from `build`.
COPY --from=build /etc/apt/keyrings/docker.gpg /etc/apt/keyrings/docker.gpg
COPY --from=build /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/docker.list

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl="${CURL_VERSION}" \
        unzip="${UNZIP_VERSION}" \
        libcurl3-gnutls="${LIBCURL3_GNUTLS_VERSION}" \
        "docker-ce-cli=5:${DOCKER_CLI_VERSION}-1~debian.13~trixie" \
        "docker-buildx-plugin=${DOCKER_BUILDX_VERSION}-1~debian.13~trixie" \
        "docker-compose-plugin=${DOCKER_COMPOSE_VERSION}-1~debian.13~trixie" && \
    rm -rf /var/lib/apt/lists/*

# Compiled Git artifacts.
COPY --from=build /usr/bin/git /usr/bin/git
COPY --from=build /usr/libexec/git-core /usr/libexec/git-core
COPY --from=build /usr/share/git-core/templates /usr/share/git-core/templates

# Single-binary tools.
COPY --from=build /tmp/jq      /usr/local/bin/jq
COPY --from=build /tmp/yq      /usr/local/bin/yq
COPY --from=build /tmp/git-lfs /usr/local/bin/git-lfs
COPY --from=build /tmp/claude  /usr/local/bin/claude
COPY --from=build /tmp/copilot /usr/local/bin/copilot

# Expose docker-buildx and docker-compose as standalone commands too.
ENV PATH="/usr/libexec/docker/cli-plugins:${PATH}"

# Prevent Claude CLI's background auto-updater from defeating the version pin.
ENV DISABLE_AUTOUPDATER=1

# Inline smoke tests - fail the build immediately if any tool is broken
# and cleanup files no longer needed
RUN curl --version && \
    unzip -v && \
    docker --version && \
    docker buildx version && \
    docker compose version && \
    docker-buildx version && \
    docker-compose version && \
    git --version && \
    git lfs install --system && \
    git lfs version && \
    jq --version && \
    yq --version && \
    copilot --version && \
    claude --version && \
    apt-get clean && \
    rm -rf \
        /var/lib/apt/lists/* /var/cache/apt/archives/* \
        # /root/.cache: copilot --version unpacks runtime assets here.
        /tmp/* /root/.cache


# ============================================================================
# test - smoke tests against the final image; driven by bake with
#        output=cacheonly so the result layer is discarded after assertions.
# ============================================================================
FROM final AS test

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- Version checks ------------------------------------------------------
# Re-assert PATH + runtime deps resolve against `final`, catching anything
# the inline checks in `final` couldn't see (e.g., post-cleanup state).
RUN curl --version && \
    unzip -v && \
    docker --version && \
    docker buildx version && \
    docker compose version && \
    docker-buildx version && \
    docker-compose version && \
    git --version && \
    git lfs version && \
    jq --version && \
    yq --version && \
    copilot --version && \
    claude --version

# --- Functional smoke tests ---------------------------------------------
# jq parses JSON on stdin.
RUN [[ "$(echo '{"a":1}' | jq '.a')" == "1" ]]

# yq parses YAML on stdin.
RUN [[ "$(echo 'a: 1' | yq '.a')" == "1" ]]

# Git clones over HTTPS — exercises libcurl3-gnutls runtime dep.
# `awk 'NR==1'` reads to EOF (unlike `head -n1` which closes early and gives
# git SIGPIPE on some hosts), so pipefail still catches a failing git while
# only the first ref line is printed for readability.
RUN git ls-remote https://github.com/octocat/Hello-World.git | awk 'NR==1'

# Git LFS registers its filters into git config — proves the binary integrates
# with git, not just that it loads.
RUN git lfs install

# Buildx is reachable as a docker CLI plugin (not just a standalone binary).
RUN docker buildx ls
