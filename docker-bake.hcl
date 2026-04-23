// Bake definition for the terra → vulcan → {janus,mercury,hermes} graph.
//
// Local usage:
//   docker buildx bake validate           # build test stages for all images
//   docker buildx bake default --load     # build & load final images
//   docker buildx bake vulcan-test        # test a single image (builds deps)
//   VERSION=myfeature docker buildx bake validate
//
// CI usage (wired via docker/bake-action):
//   PR:   targets=validate                                    (no login, no push)
//   main: targets=validate + targets=default push=true        (LATEST, PUSH_CACHE set)

variable "VERSION" {
  default = "local"
}

variable "REGISTRY" {
  default = "ghcr.io/swissgrc"
}

// Add the :latest tag (set true on main only).
variable "LATEST" {
  default = false
}

// Push cache layers back to the registry (set true on main only; PRs have no
// write credentials to GHCR).
variable "PUSH_CACHE" {
  default = false
}

function "image" {
  params = [name]
  result = "${REGISTRY}/azure-pipelines-${name}"
}

function "tags" {
  params = [name]
  result = concat(
    ["${image(name)}:${VERSION}"],
    LATEST ? ["${image(name)}:latest"] : []
  )
}

function "cache_from" {
  params = [name]
  result = ["type=registry,ref=${image(name)}:cache"]
}

function "cache_to" {
  params = [name]
  result = PUSH_CACHE ? ["type=registry,ref=${image(name)}:cache,mode=max"] : []
}

group "default" {
  targets = ["terra", "vulcan", "janus", "mercury", "hermes"]
}

group "validate" {
  targets = ["terra-test", "vulcan-test", "janus-test", "mercury-test", "hermes-test"]
}

target "_common" {
  args = {
    BASE_TAG = "${VERSION}"
  }
}

// --- Build targets ----------------------------------------------------------
// `contexts` wires each downstream image's `FROM ghcr.io/.../<base>:${VERSION}`
// to the in-memory build result of the upstream target. BuildKit never
// contacts the registry for these refs, which is what makes PR builds work.

target "terra" {
  inherits   = ["_common"]
  context    = "src/terra"
  tags       = tags("terra")
  cache-from = cache_from("terra")
  cache-to   = cache_to("terra")
}

target "vulcan" {
  inherits = ["_common"]
  context  = "src/vulcan"
  contexts = {
    "${image("terra")}:${VERSION}" = "target:terra"
  }
  tags       = tags("vulcan")
  cache-from = cache_from("vulcan")
  cache-to   = cache_to("vulcan")
}

target "janus" {
  inherits = ["_common"]
  context  = "src/janus"
  contexts = {
    "${image("vulcan")}:${VERSION}" = "target:vulcan"
  }
  tags       = tags("janus")
  cache-from = cache_from("janus")
  cache-to   = cache_to("janus")
}

target "mercury" {
  inherits = ["_common"]
  context  = "src/mercury"
  contexts = {
    "${image("vulcan")}:${VERSION}" = "target:vulcan"
  }
  tags       = tags("mercury")
  cache-from = cache_from("mercury")
  cache-to   = cache_to("mercury")
}

target "hermes" {
  inherits = ["_common"]
  context  = "src/hermes"
  contexts = {
    "${image("vulcan")}:${VERSION}" = "target:vulcan"
  }
  tags       = tags("hermes")
  cache-from = cache_from("hermes")
  cache-to   = cache_to("hermes")
}

// --- Test targets -----------------------------------------------------------
// Each inherits its build target (so contexts + args propagate), overrides
// `target` to build the Dockerfile `test` stage, and discards the result
// via `output=cacheonly` — the assertions run, no image is exported.

target "terra-test" {
  inherits = ["terra"]
  target   = "test"
  output   = ["type=cacheonly"]
}

target "vulcan-test" {
  inherits = ["vulcan"]
  target   = "test"
  output   = ["type=cacheonly"]
}

target "janus-test" {
  inherits = ["janus"]
  target   = "test"
  output   = ["type=cacheonly"]
}

target "mercury-test" {
  inherits = ["mercury"]
  target   = "test"
  output   = ["type=cacheonly"]
}

target "hermes-test" {
  inherits = ["hermes"]
  target   = "test"
  output   = ["type=cacheonly"]
}
