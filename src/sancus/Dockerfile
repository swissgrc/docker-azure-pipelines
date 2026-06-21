# syntax=docker/dockerfile:1.25

# BASE_TAG is overridden by CI (`--build-arg BASE_TAG=<tag>`); the default
# here keeps `docker buildx build src/sancus` working without flags.
ARG BASE_TAG=latest


# ============================================================================
# base - minimal runtime deps that need to exist in `final` too
# ============================================================================
FROM ghcr.io/swissgrc/azure-pipelines-vulcan:${BASE_TAG} AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]


# ============================================================================
# build - download tools; everything here is discarded from `final`
# ============================================================================
FROM base AS build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- APT helpers (build-stage only) --------------------------------------
# gnupg dearmors the Microsoft repo key and verifies the jsign PGP signature.
# curl is inherited from terra.
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

# --- jsign (standalone CLI fat jar from Maven Central) -------------------
# Maven Central is the only channel offering BOTH a first-class Renovate
# datasource AND a verifiable signature: jsign's GitHub releases publish no
# checksum/signature file, whereas every Maven Central artifact carries a
# `.asc` PGP signature. We verify it against Emmanuel Bourg's pinned key
# fingerprint (he signs all net.jsign releases) — fitting rigor for a
# code-signing tool. Renovate bumps JSIGN_VERSION; the signature is fetched
# fresh at build time, so there is no committed hash to rot.
# renovate: datasource=maven depName=net.jsign:jsign
ENV JSIGN_VERSION=7.4

# Fingerprint of "Emmanuel Bourg <ebourg@apache.org>" (verified on
# keys.openpgp.org). This pin is the trust anchor: we assert the fetched key
# matches it, so a compromised keyserver cannot substitute a different key,
# and `gpg --verify` fails the build closed if the artifact was not signed
# by this key.
ENV JSIGN_KEY_FINGERPRINT=B8CE4DE21080DCF903E16C40F513C419E4B9D0AC

RUN GNUPGHOME="$(mktemp -d)" && export GNUPGHOME && \
    base="https://repo1.maven.org/maven2/net/jsign/jsign/${JSIGN_VERSION}" && \
    curl -fsSL -o /tmp/jsign.jar     "${base}/jsign-${JSIGN_VERSION}.jar" && \
    curl -fsSL -o /tmp/jsign.jar.asc "${base}/jsign-${JSIGN_VERSION}.jar.asc" && \
    curl -fsSL "https://keys.openpgp.org/vks/v1/by-fingerprint/${JSIGN_KEY_FINGERPRINT}" | \
        gpg --import && \
    gpg --list-keys --with-colons --fingerprint | \
        awk -F: '/^fpr:/ {print $10; exit}' | \
        grep -qx "${JSIGN_KEY_FINGERPRINT}" && \
    gpg --batch --verify /tmp/jsign.jar.asc /tmp/jsign.jar && \
    rm -rf "${GNUPGHOME}" /tmp/jsign.jar.asc


# ============================================================================
# final - runtime image
# ============================================================================
FROM base AS final

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /

LABEL org.opencontainers.image.vendor="Swiss GRC AG" \
      org.opencontainers.image.authors="Swiss GRC AG <opensource@swissgrc.com>" \
      org.opencontainers.image.title="azure-pipelines-sancus" \
      org.opencontainers.image.documentation="https://github.com/swissgrc/docker-azure-pipelines"

# renovate: datasource=github-tags depName=Azure/azure-cli extractVersion=^azure-cli-(?<version>.*)$
ENV AZURE_CLI_VERSION=2.87.0

# Headless JRE that runs jsign (no GUI/AWT needed for signing). Its hard
# dependency on ca-certificates-java populates Java's truststore, which jsign
# needs for HTTPS calls to cloud KMS backends (e.g. Azure Key Vault).
# renovate: datasource=repology depName=debian_13/openjdk-21 versioning=deb
ENV OPENJDK_VERSION=21.0.11+10-1~deb13u2

# osslsigncode: independent Authenticode signature verification — jsign signs
# but has no verify command of its own.
# renovate: datasource=repology depName=debian_13/osslsigncode versioning=deb
ENV OSSLSIGNCODE_VERSION=2.9-2

# Bring Microsoft keyring + source list in from `build`.
COPY --from=build /etc/apt/keyrings/microsoft.gpg /etc/apt/keyrings/microsoft.gpg
COPY --from=build /etc/apt/sources.list.d/azure-cli.list /etc/apt/sources.list.d/azure-cli.list

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        "azure-cli=${AZURE_CLI_VERSION}-1~bookworm" \
        "openjdk-21-jre-headless=${OPENJDK_VERSION}" \
        "osslsigncode=${OSSLSIGNCODE_VERSION}" && \
    rm -rf /var/lib/apt/lists/*

# jsign fat jar + a thin wrapper so `jsign ...` behaves like a native CLI.
COPY --from=build /tmp/jsign.jar /usr/local/lib/jsign.jar
RUN printf '#!/usr/bin/env sh\nexec java -jar /usr/local/lib/jsign.jar "$@"\n' \
        > /usr/local/bin/jsign && \
    chmod +x /usr/local/bin/jsign

# Inline smoke tests + cleanup in one layer.
# /root/.azure is created by `az --version` on first invocation.
RUN az --version && \
    java -version && \
    jsign --version && \
    osslsigncode --version && \
    apt-get clean && \
    rm -rf \
        /var/lib/apt/lists/* /var/cache/apt/archives/* \
        /tmp/* /root/.cache \
        /root/.azure


# ============================================================================
# test - smoke tests against the final image; driven by bake with
#        output=cacheonly so the result layer is discarded after assertions.
# ============================================================================
FROM final AS test

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- sancus's own tools --------------------------------------------------
# hadolint ignore=DL3059
RUN jsign --version && \
    az --version && \
    osslsigncode --version && \
    java -version

# --- Functional: sign a real PE end-to-end ------------------------------
# Builds a .NET assembly (the PE that Cake/MSBuild emits and that sancus
# exists to sign), signs it with jsign via a self-signed PKCS#12 keystore
# (keytool ships with the JRE), then confirms an Authenticode signature is
# embedded using osslsigncode. `extract-signature` needs no trust chain and
# exits non-zero unless a signature is present, so it is an independent check
# of jsign's output. Exercises the full jsign -> JRE -> crypto-provider path.
# hadolint ignore=DL3059
RUN <<'EOF'
set -euo pipefail
tmp="$(mktemp -d)"
dotnet new console -o "$tmp/app"
dotnet build -c Release -o "$tmp/out" "$tmp/app"
dll="$tmp/out/app.dll"
test -f "$dll"
keytool -genkeypair -alias test -keyalg RSA -keysize 2048 -validity 1 \
    -dname "CN=sancus smoke test" -storetype PKCS12 -ext eku=codeSigning \
    -keystore "$tmp/ks.p12" -storepass changeit
jsign --keystore "$tmp/ks.p12" --storepass changeit --alias test "$dll"
osslsigncode extract-signature -in "$dll" -out "$tmp/sig.pkcs7"
test -s "$tmp/sig.pkcs7"
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
