#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${LTX2_IMAGE_NAME:-ltx2-infer:latest}"
MODEL_DIR="${LTX2_MODEL_DIR:-${ROOT}/../models}"
OUTPUT_DIR="${LTX2_OUTPUT_DIR:-${ROOT}/outputs}"
SYNC_OUTPUT_DIR="${LTX2_SYNC_OUTPUT_DIR:-${ROOT}/outputs}"
SYNC_OUTPUT="${LTX2_SYNC_OUTPUT:-1}"
OUTPUT_FILE="$(basename "${LTX2_OUTPUT_FILE:-ic-lora.mp4}")"

DISTILLED_CHECKPOINT="${LTX2_DISTILLED_CHECKPOINT:-${MODEL_DIR}/ltx-2.3-22b-distilled-1.1.safetensors}"
UPSCALER="${LTX2_UPSCALER:-${MODEL_DIR}/ltx-2.3-spatial-upscaler-x2-1.1.safetensors}"
GEMMA_ROOT="${LTX2_GEMMA_ROOT:-${MODEL_DIR}/gemma-3-12b-it-qat-q4_0-unquantized}"
IC_LORA="${LTX2_IC_LORA:-${MODEL_DIR}/ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors}"
REFERENCE_VIDEO="${LTX2_REFERENCE_VIDEO:-}"
REFERENCE_STRENGTH="${LTX2_REFERENCE_STRENGTH:-0.75}"
PROMPT="${1:-A cinematic realistic video preserving the reference subject, composition, and motion with improved detail and stable faces.}"
EXTRA_ARGS=("${@:2}")
OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_FILE}"

if [[ -z "${REFERENCE_VIDEO}" ]]; then
    echo "Set LTX2_REFERENCE_VIDEO to a local MP4 reference video for IC-LoRA conditioning." >&2
    exit 1
fi

REFERENCE_VIDEO="$(realpath -m "${REFERENCE_VIDEO}")"
REFERENCE_DIR="$(dirname "${REFERENCE_VIDEO}")"
REFERENCE_BASENAME="$(basename "${REFERENCE_VIDEO}")"

mkdir -p "${OUTPUT_DIR}"

for path in "${DISTILLED_CHECKPOINT}" "${UPSCALER}" "${GEMMA_ROOT}" "${IC_LORA}" "${REFERENCE_VIDEO}"; do
    if [[ ! -e "${path}" ]]; then
        echo "Missing required path: ${path}" >&2
        echo "Run scripts/download_models.sh first, or set LTX2_MODEL_DIR/LTX2_DISTILLED_CHECKPOINT/LTX2_UPSCALER/LTX2_GEMMA_ROOT/LTX2_IC_LORA/LTX2_REFERENCE_VIDEO." >&2
        exit 1
    fi
done

docker run --rm --gpus all --ipc=host \
    -e HF_HOME=/workspace/models/.hf-cache \
    -v "${ROOT}":/workspace/LTX-2 \
    -v "${MODEL_DIR}":/workspace/models \
    -v "${OUTPUT_DIR}":/workspace/outputs \
    -v "${REFERENCE_DIR}":/workspace/reference \
    -w /workspace/LTX-2 \
    "${IMAGE_NAME}" \
    python3 -m ltx_pipelines.ic_lora \
        --distilled-checkpoint-path "/workspace/models/$(basename "${DISTILLED_CHECKPOINT}")" \
        --spatial-upsampler-path "/workspace/models/$(basename "${UPSCALER}")" \
        --gemma-root "/workspace/models/$(basename "${GEMMA_ROOT}")" \
        --lora "/workspace/models/$(basename "${IC_LORA}")" "${LTX2_IC_LORA_STRENGTH:-1.0}" \
        --video-conditioning "/workspace/reference/${REFERENCE_BASENAME}" "${REFERENCE_STRENGTH}" \
        --prompt "${PROMPT}" \
        --output-path "/workspace/outputs/${OUTPUT_FILE}" \
        --height "${LTX2_HEIGHT:-512}" \
        --width "${LTX2_WIDTH:-768}" \
        --num-frames "${LTX2_NUM_FRAMES:-121}" \
        --frame-rate "${LTX2_FRAME_RATE:-24}" \
        --offload "${LTX2_OFFLOAD:-none}" \
        "${EXTRA_ARGS[@]}"

if [[ "${SYNC_OUTPUT}" != "0" && "$(realpath -m "${OUTPUT_DIR}")" != "$(realpath -m "${SYNC_OUTPUT_DIR}")" ]]; then
    mkdir -p "${SYNC_OUTPUT_DIR}"
    cp -f "${OUTPUT_PATH}" "${SYNC_OUTPUT_DIR}/${OUTPUT_FILE}"
    echo "Synced output to ${SYNC_OUTPUT_DIR}/${OUTPUT_FILE}"
fi
