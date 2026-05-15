#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${LTX2_IMAGE_NAME:-ltx2-infer:latest}"
MODEL_DIR="${LTX2_MODEL_DIR:-${ROOT}/../models}"
OUTPUT_DIR="${LTX2_OUTPUT_DIR:-${ROOT}/outputs}"
SYNC_OUTPUT_DIR="${LTX2_SYNC_OUTPUT_DIR:-${ROOT}/outputs}"
SYNC_OUTPUT="${LTX2_SYNC_OUTPUT:-1}"
OUTPUT_FILE="$(basename "${LTX2_OUTPUT_FILE:-distilled-smoke.mp4}")"

CHECKPOINT="${LTX2_CHECKPOINT:-${MODEL_DIR}/ltx-2.3-22b-distilled-1.1.safetensors}"
UPSCALER="${LTX2_UPSCALER:-${MODEL_DIR}/ltx-2.3-spatial-upscaler-x2-1.1.safetensors}"
GEMMA_ROOT="${LTX2_GEMMA_ROOT:-${MODEL_DIR}/gemma-3-12b-it-qat-q4_0-unquantized}"
PROMPT="${1:-A quiet cinematic shot of sunlight moving across a glass table, dust motes drifting in the air, shallow depth of field, natural colors.}"
OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_FILE}"

mkdir -p "${OUTPUT_DIR}"

for path in "${CHECKPOINT}" "${UPSCALER}" "${GEMMA_ROOT}"; do
    if [[ ! -e "${path}" ]]; then
        echo "Missing required model path: ${path}" >&2
        echo "Run scripts/download_models.sh first, or set LTX2_MODEL_DIR/LTX2_UPSCALER/LTX2_GEMMA_ROOT." >&2
        exit 1
    fi
done

require_gemma_file() {
    local pattern="$1"
    local found
    found="$(find "${GEMMA_ROOT}" -name "${pattern}" -print -quit 2>/dev/null || true)"
    if [[ -z "${found}" ]]; then
        echo "Gemma text encoder is incomplete: missing ${pattern} under ${GEMMA_ROOT}" >&2
        echo "If you have access to the gated Gemma repo, set HF_TOKEN and rerun scripts/download_models.sh." >&2
        exit 1
    fi
}

require_gemma_file "model*.safetensors"
require_gemma_file "tokenizer.model"
require_gemma_file "preprocessor_config.json"

docker run --rm --gpus all --ipc=host \
    -e HF_HOME=/workspace/models/.hf-cache \
    -v "${ROOT}":/workspace/LTX-2 \
    -v "${MODEL_DIR}":/workspace/models \
    -v "${OUTPUT_DIR}":/workspace/outputs \
    -w /workspace/LTX-2 \
    "${IMAGE_NAME}" \
    python3 -m ltx_pipelines.distilled \
        --distilled-checkpoint-path "/workspace/models/$(basename "${CHECKPOINT}")" \
        --spatial-upsampler-path "/workspace/models/$(basename "${UPSCALER}")" \
        --gemma-root "/workspace/models/$(basename "${GEMMA_ROOT}")" \
        --prompt "${PROMPT}" \
        --output-path "/workspace/outputs/${OUTPUT_FILE}" \
        --height "${LTX2_HEIGHT:-256}" \
        --width "${LTX2_WIDTH:-256}" \
        --num-frames "${LTX2_NUM_FRAMES:-9}" \
        --frame-rate "${LTX2_FRAME_RATE:-24}" \
        --offload "${LTX2_OFFLOAD:-cpu}"

    if [[ "${SYNC_OUTPUT}" != "0" && "$(realpath -m "${OUTPUT_DIR}")" != "$(realpath -m "${SYNC_OUTPUT_DIR}")" ]]; then
        mkdir -p "${SYNC_OUTPUT_DIR}"
        cp -f "${OUTPUT_PATH}" "${SYNC_OUTPUT_DIR}/${OUTPUT_FILE}"
        echo "Synced output to ${SYNC_OUTPUT_DIR}/${OUTPUT_FILE}"
    fi