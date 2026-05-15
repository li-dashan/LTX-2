#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${LTX2_IMAGE_NAME:-ltx2-infer:latest}"
MODEL_DIR="${LTX2_MODEL_DIR:-${ROOT}/../models}"
OUTPUT_DIR="${LTX2_OUTPUT_DIR:-${ROOT}/outputs}"
SYNC_OUTPUT_DIR="${LTX2_SYNC_OUTPUT_DIR:-${ROOT}/outputs}"
SYNC_OUTPUT="${LTX2_SYNC_OUTPUT:-1}"
OUTPUT_FILE="$(basename "${LTX2_OUTPUT_FILE:-two-stage-hq.mp4}")"

CHECKPOINT="${LTX2_CHECKPOINT:-${MODEL_DIR}/ltx-2.3-22b-dev.safetensors}"
DISTILLED_LORA="${LTX2_DISTILLED_LORA:-${MODEL_DIR}/ltx-2.3-22b-distilled-lora-384-1.1.safetensors}"
UPSCALER="${LTX2_UPSCALER:-${MODEL_DIR}/ltx-2.3-spatial-upscaler-x2-1.1.safetensors}"
GEMMA_ROOT="${LTX2_GEMMA_ROOT:-${MODEL_DIR}/gemma-3-12b-it-qat-q4_0-unquantized}"
PROMPT="${1:-A cinematic realistic concert performance on a nighttime stage.}"
EXTRA_ARGS=("${@:2}")
OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_FILE}"

mkdir -p "${OUTPUT_DIR}"

for path in "${CHECKPOINT}" "${DISTILLED_LORA}" "${UPSCALER}" "${GEMMA_ROOT}"; do
    if [[ ! -e "${path}" ]]; then
        echo "Missing required model path: ${path}" >&2
        echo "Run scripts/download_models.sh first, or set LTX2_MODEL_DIR/LTX2_CHECKPOINT/LTX2_DISTILLED_LORA/LTX2_UPSCALER/LTX2_GEMMA_ROOT." >&2
        exit 1
    fi
done

docker run --rm --gpus all --ipc=host \
    -e HF_HOME=/workspace/models/.hf-cache \
    -v "${ROOT}":/workspace/LTX-2 \
    -v "${MODEL_DIR}":/workspace/models \
    -v "${OUTPUT_DIR}":/workspace/outputs \
    -w /workspace/LTX-2 \
    "${IMAGE_NAME}" \
    python3 -m ltx_pipelines.ti2vid_two_stages_hq \
        --checkpoint-path "/workspace/models/$(basename "${CHECKPOINT}")" \
        --distilled-lora "/workspace/models/$(basename "${DISTILLED_LORA}")" "${LTX2_DISTILLED_LORA_STRENGTH:-0.8}" \
        --distilled-lora-strength-stage-1 "${LTX2_DISTILLED_LORA_STRENGTH_STAGE_1:-0.4}" \
        --distilled-lora-strength-stage-2 "${LTX2_DISTILLED_LORA_STRENGTH_STAGE_2:-0.8}" \
        --spatial-upsampler-path "/workspace/models/$(basename "${UPSCALER}")" \
        --gemma-root "/workspace/models/$(basename "${GEMMA_ROOT}")" \
        --prompt "${PROMPT}" \
        --output-path "/workspace/outputs/${OUTPUT_FILE}" \
        --height "${LTX2_HEIGHT:-512}" \
        --width "${LTX2_WIDTH:-768}" \
        --num-frames "${LTX2_NUM_FRAMES:-121}" \
        --frame-rate "${LTX2_FRAME_RATE:-24}" \
        --num-inference-steps "${LTX2_NUM_INFERENCE_STEPS:-30}" \
        --offload "${LTX2_OFFLOAD:-none}" \
        "${EXTRA_ARGS[@]}"

if [[ "${SYNC_OUTPUT}" != "0" && "$(realpath -m "${OUTPUT_DIR}")" != "$(realpath -m "${SYNC_OUTPUT_DIR}")" ]]; then
    mkdir -p "${SYNC_OUTPUT_DIR}"
    cp -f "${OUTPUT_PATH}" "${SYNC_OUTPUT_DIR}/${OUTPUT_FILE}"
    echo "Synced output to ${SYNC_OUTPUT_DIR}/${OUTPUT_FILE}"
fi
