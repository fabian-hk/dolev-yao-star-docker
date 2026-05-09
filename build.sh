#!/usr/bin/env bash
set -euo pipefail

IMAGE="fabianhk/dystar-with-code-server:latest"
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

echo "Building and pushing $IMAGE for platforms: $PLATFORMS"

echo "Context: $CONTEXT_DIR"
echo "Dockerfile: $DOCKER_FILE"

export DOCKER_BUILDKIT=1
docker buildx build \
  --platform "$PLATFORMS" \
  -t "$IMAGE" \
  --file "$DOCKER_FILE" \
  --push \
  "$CONTEXT_DIR"

echo "Done: pushed $IMAGE"
