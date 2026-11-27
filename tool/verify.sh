#!/usr/bin/env bash
# Run the CI checks in a container, so the host needs no Flutter SDK.
#
# Usage:
#   tool/verify.sh              # format check, analyze, test
#   tool/verify.sh format       # rewrite files with dart format
#   tool/verify.sh shell        # interactive shell in the container
#
# Set FLUTTER_SDK to a Flutter checkout on the host to use it in place of the
# image's own SDK, for a release that no image carries yet.
set -euo pipefail

IMAGE="${FLUTTER_IMAGE:-ghcr.io/cirruslabs/flutter:stable}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# git refuses a checkout that another user owns, and the Flutter tool reads
# its version through git, so the mounted checkout is marked safe.
SDK_ARGS=()
if [[ -n "${FLUTTER_SDK:-}" ]]; then
  SDK_ARGS=(
    -v "$FLUTTER_SDK:/sdks/flutter"
    -e GIT_CONFIG_COUNT=1
    -e GIT_CONFIG_KEY_0=safe.directory
    -e GIT_CONFIG_VALUE_0='*'
  )
fi

# A named volume keeps the pub cache between runs, so `pub get` stays fast.
# The +-form expands an empty array to nothing under `set -u` in bash 3.2.
run() {
  docker run --rm -t \
    -v "$REPO:/app" \
    -v talk_builder_pub_cache:/root/.pub-cache \
    ${SDK_ARGS[@]+"${SDK_ARGS[@]}"} \
    -w /app \
    "$IMAGE" bash -lc "$1"
}

case "${1:-check}" in
  check)
    run 'flutter pub get \
      && dart format --output=none --set-exit-if-changed . \
      && flutter analyze \
      && flutter test'
    ;;
  format)
    run 'dart format .'
    ;;
  shell)
    docker run --rm -it \
      -v "$REPO:/app" \
      -v talk_builder_pub_cache:/root/.pub-cache \
      ${SDK_ARGS[@]+"${SDK_ARGS[@]}"} \
      -w /app "$IMAGE" bash
    ;;
  *)
    echo "usage: $0 [check|format|shell]" >&2
    exit 2
    ;;
esac
