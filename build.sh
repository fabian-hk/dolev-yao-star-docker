#!/usr/bin/env bash
set -euo pipefail

IMAGE_BASE="fabianhk/dystar-with-code-server"
# Fixed default tag (do not override)
DEFAULT_TAG="latest"
# Optionally provide an extra tag via env var EXTRA_TAG or as first CLI arg.
EXTRA_TAG="${EXTRA_TAG:-${1:-}}"

PLATFORMS="linux/amd64,linux/arm64"
BUILDER_NAME="dystar_builder"
CONTEXT_DIR="${BUILD_CONTEXT:-$(pwd)}"

# Path to Dockerfile. Use DOCKER_FILE if provided, otherwise default to
# a Dockerfile inside the build context.
DOCKER_FILE="${DOCKER_FILE:-$CONTEXT_DIR/Dockerfile}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found. Install Docker and try again." >&2
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "docker buildx not available. Ensure Docker 19.03+ and buildx enabled." >&2
  exit 1
fi

# create or select builder
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  docker buildx create --name "$BUILDER_NAME" --use
else
  docker buildx use "$BUILDER_NAME"
fi

echo "Building and pushing images for platforms: $PLATFORMS"

echo "Context: $CONTEXT_DIR"
echo "Dockerfile: $DOCKER_FILE"

# Prepare tag list (always push DEFAULT_TAG, optionally EXTRA_TAG)
TAGS=("$IMAGE_BASE:$DEFAULT_TAG")
if [ -n "$EXTRA_TAG" ] && [ "$EXTRA_TAG" != "$DEFAULT_TAG" ]; then
  TAGS+=("$IMAGE_BASE:$EXTRA_TAG")
fi

echo "Will push tags: ${TAGS[*]}"

export DOCKER_BUILDKIT=1
build_cmd=(docker buildx build --platform "$PLATFORMS" --file "$DOCKER_FILE" --push "$CONTEXT_DIR")
for t in "${TAGS[@]}"; do
  build_cmd+=( -t "$t" )
done

"${build_cmd[@]}"

echo "Done: pushed ${TAGS[*]}"
