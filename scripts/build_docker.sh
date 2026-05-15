#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${LTX2_IMAGE_NAME:-ltx2-infer:latest}"

docker build -t "${IMAGE_NAME}" -f "${ROOT}/docker/Dockerfile" "${ROOT}"