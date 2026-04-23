# Docker images for Azure Pipelines container jobs

<!-- markdownlint-disable MD013 -->
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://github.com/swissgrc/docker-azure-pipelines/blob/main/LICENSE) [![CI](https://img.shields.io/github/actions/workflow/status/swissgrc/docker-azure-pipelines/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/swissgrc/docker-azure-pipelines/actions/workflows/ci.yml) [![Lint](https://img.shields.io/github/actions/workflow/status/swissgrc/docker-azure-pipelines/lint.yml?branch=main&style=flat-square&label=Lint)](https://github.com/swissgrc/docker-azure-pipelines/actions/workflows/lint.yml)
<!-- markdownlint-restore -->

Docker images to run various workloads in [Azure Pipelines container jobs].

## Usage

These images can be used to run builds, deployments, end-to-end tests, and dependency updates in [Azure Pipelines container jobs]. Pick the image matching your workload — see the [Images](#images) table below.

### Azure Pipelines Container Job

To use an image in an Azure Pipelines Container Job, reference it with the `container` property.

The following example shows a build step using the `vulcan` image (.NET + Node.js runtimes):

```yaml
- stage: build
  jobs:
    - job: Build
      container: ghcr.io/swissgrc/azure-pipelines-vulcan:latest
      steps:
        - bash: |
            dotnet --version
            node --version
```

## Images

| Image                                                                                                                  | Role                   | Base             |
|------------------------------------------------------------------------------------------------------------------------|------------------------|------------------|
| [`azure-pipelines-terra`](https://github.com/swissgrc/docker-azure-pipelines/pkgs/container/azure-pipelines-terra)     | L1 foundation          | `debian:13-slim` |
| [`azure-pipelines-vulcan`](https://github.com/swissgrc/docker-azure-pipelines/pkgs/container/azure-pipelines-vulcan)   | L2 build runtimes      | `terra`          |
| [`azure-pipelines-janus`](https://github.com/swissgrc/docker-azure-pipelines/pkgs/container/azure-pipelines-janus)     | L3a deployment         | `vulcan`         |
| [`azure-pipelines-mercury`](https://github.com/swissgrc/docker-azure-pipelines/pkgs/container/azure-pipelines-mercury) | L3b end-to-end testing | `vulcan`         |
| [`azure-pipelines-hermes`](https://github.com/swissgrc/docker-azure-pipelines/pkgs/container/azure-pipelines-hermes)   | L3c dependency updates | `vulcan`         |

All images are published to [GHCR] under `ghcr.io/swissgrc/`.

### `azure-pipelines-terra`

Foundation image with shared CLIs used by every downstream image.

- Everything from `debian:13-slim`
- Docker CLI, Buildx plugin, Compose plugin
- Git (compiled from source)
- Git LFS
- jq
- yq
- Claude CLI
- GitHub Copilot CLI
- curl, unzip

### `azure-pipelines-vulcan`

Build runtimes image for compiling and packaging .NET and Node.js applications.

- Everything from `terra`
- .NET SDK 9
- .NET SDK 10
- Node.js 24
- npm, Yarn, pnpm
- fontconfig

### `azure-pipelines-janus`

Deployment image for provisioning infrastructure and deploying to Azure / Kubernetes.

- Everything from `vulcan`
- Azure CLI
- Azure Static Web Apps CLI (`swa`)
- Terraform
- tflint
- Packer
- Helm
- kubectl
- kubelogin

### `azure-pipelines-mercury`

End-to-end testing image with Playwright and its browsers pre-installed.

- Everything from `vulcan`
- Playwright
- Chromium, Firefox, WebKit browsers (with OS dependencies)

### `azure-pipelines-hermes`

Dependency updates image for running [Renovate] self-hosted.

- Everything from `vulcan`
- Renovate

## Tags

| Tag            | Description                                                                                         |
|----------------|-----------------------------------------------------------------------------------------------------|
| `latest`       | Latest stable release (from `main` branch)                                                          |
| `YYYY.MM.DD.N` | Immutable version for a specific CI run (`N` = zero-based count of prior publishes on that UTC day) |

All images produced by one CI run share the same `YYYY.MM.DD.N` tag. Failed runs leave gaps in the `N` sequence.

[Azure Pipelines container jobs]: https://docs.microsoft.com/en-us/azure/devops/pipelines/process/container-phases
[GHCR]: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
[Renovate]: https://github.com/renovatebot/renovate
