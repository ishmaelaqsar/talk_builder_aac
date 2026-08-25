#!/usr/bin/env bash
# Run the CI checks in a container, so the host needs no Flutter SDK.
#
# Usage:
#   tool/verify.sh              # format check, analyze, test
#   tool/verify.sh format       # rewrite files with dart format
#   tool/verify.sh shell        # interactive shell in the container
set -euo pipefail

IMAGE="${FLUTTER_IMAGE:-ghcr.io/cirruslabs/flutter:stable}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# A named volume keeps the pub cache between runs, so `pub get` stays fast.
run() {
  docker run --rm -t \
    -v "$REPO:/app" \
    -v talk_builder_pub_cache:/root/.pub-cache \
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
      -w /app "$IMAGE" bash
    ;;
  *)
    echo "usage: $0 [check|format|shell]" >&2
    exit 2
    ;;
esac
