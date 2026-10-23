#!/usr/bin/env bash
set -euo pipefail

# Build the pi-msb image and load it into Microsandbox under a fixed tag.
# Because the tag never changes ("latest"), the launcher can keep referring to
# pi-msb:latest forever.
#
# Usage:
#   ./build-msb.sh
#   IMAGE=pi-msb TAG=latest PI_VERSION=1.4.0 ./build-msb.sh
#   TAG=dev ./build-msb.sh          # experiment without touching :latest

IMAGE="${IMAGE:-pi-msb}"
TAG="${TAG:-latest}"
PI_VERSION="${PI_VERSION:-1.4.0}"
REF="${IMAGE}:${TAG}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

for cmd in docker msb; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "error: '$cmd' not found in PATH" >&2
    exit 1
  }
done

TAR="$(mktemp "${TMPDIR:-/tmp}/pi-msb.XXXXXX")"
trap 'rm -f "$TAR"' EXIT

echo "==> Building $REF (pi $PI_VERSION)"
docker build --build-arg "PI_VERSION=$PI_VERSION" -t "$REF" .

echo "==> Exporting image to $TAR"
docker save "$REF" -o "$TAR"

echo "==> Loading into msb as $REF"
msb load --input "$TAR" --tag "$REF"

echo "==> Images in the msb cache"
msb images -q

echo
echo "Done. Launch (or re-launch with --replace) using: $REF"
