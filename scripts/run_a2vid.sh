#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${LTX2_IMAGE_NAME:-ltx2-infer:latest}"
MODEL_DIR="${LTX2_MODEL_DIR:-${ROOT}/../models}"
OUTPUT_DIR="${LTX2_OUTPUT_DIR:-${ROOT}/outputs}"
SYNC_OUTPUT_DIR="${LTX2_SYNC_OUTPUT_DIR:-${ROOT}/outputs}"
SYNC_OUTPUT="${LTX2_SYNC_OUTPUT:-1}"
OUTPUT_FILE="$(basename "${LTX2_OUTPUT_FILE:-a2vid.mp4}")"

CHECKPOINT="${LTX2_CHECKPOINT:-${MODEL_DIR}/ltx-2.3-22b-dev.safetensors}"
DISTILLED_LORA="${LTX2_DISTILLED_LORA:-${MODEL_DIR}/ltx-2.3-22b-distilled-lora-384-1.1.safetensors}"
UPSCALER="${LTX2_UPSCALER:-${MODEL_DIR}/ltx-2.3-spatial-upscaler-x2-1.1.safetensors}"
GEMMA_ROOT="${LTX2_GEMMA_ROOT:-${MODEL_DIR}/gemma-3-12b-it-qat-q4_0-unquantized}"
PROMPT="${1:-A nighttime idol boy band concert performance on a large stage, synchronized choreography, dynamic lighting, cinematic camera movement.}"
AUDIO_PATH="${LTX2_AUDIO_PATH:-}"
EXTRA_ARGS=("${@:2}")
if [[ -n "${LTX2_AUDIO_MAX_DURATION:-}" ]]; then
    EXTRA_ARGS+=(--audio-max-duration "${LTX2_AUDIO_MAX_DURATION}")
fi
OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_FILE}"

if [[ -z "${AUDIO_PATH}" ]]; then
    echo "Set LTX2_AUDIO_PATH to a local audio file for A2Vid generation." >&2
    exit 1
fi

AUDIO_PATH="$(realpath -m "${AUDIO_PATH}")"
AUDIO_DIR="$(dirname "${AUDIO_PATH}")"

mkdir -p "${OUTPUT_DIR}"

for path in "${CHECKPOINT}" "${DISTILLED_LORA}" "${UPSCALER}" "${GEMMA_ROOT}" "${AUDIO_PATH}"; do
    if [[ ! -e "${path}" ]]; then
        echo "Missing required path: ${path}" >&2
        exit 1
    fi
done

docker run --rm --gpus all --ipc=host \
    -e HF_HOME=/workspace/models/.hf-cache \
    -v "${ROOT}":/workspace/LTX-2 \
    -v "${MODEL_DIR}":/workspace/models \
    -v "${OUTPUT_DIR}":/workspace/outputs \
    -v "${AUDIO_DIR}":/workspace/audio \
    -w /workspace/LTX-2 \
    "${IMAGE_NAME}" \
    python3 -m ltx_pipelines.a2vid_two_stage \
        --checkpoint-path "/workspace/models/$(basename "${CHECKPOINT}")" \
        --distilled-lora "/workspace/models/$(basename "${DISTILLED_LORA}")" "${LTX2_DISTILLED_LORA_STRENGTH:-0.8}" \
        --spatial-upsampler-path "/workspace/models/$(basename "${UPSCALER}")" \
        --gemma-root "/workspace/models/$(basename "${GEMMA_ROOT}")" \
        --prompt "${PROMPT}" \
        --audio-path "/workspace/audio/$(basename "${AUDIO_PATH}")" \
        --audio-start-time "${LTX2_AUDIO_START_TIME:-0}" \
        --output-path "/workspace/outputs/${OUTPUT_FILE}" \
        --height "${LTX2_HEIGHT:-512}" \
        --width "${LTX2_WIDTH:-768}" \
        --num-frames "${LTX2_NUM_FRAMES:-193}" \
        --frame-rate "${LTX2_FRAME_RATE:-24}" \
        --num-inference-steps "${LTX2_NUM_INFERENCE_STEPS:-30}" \
        --offload "${LTX2_OFFLOAD:-none}" \
        "${EXTRA_ARGS[@]}"

if [[ "${SYNC_OUTPUT}" != "0" && "$(realpath -m "${OUTPUT_DIR}")" != "$(realpath -m "${SYNC_OUTPUT_DIR}")" ]]; then
    mkdir -p "${SYNC_OUTPUT_DIR}"
    cp -f "${OUTPUT_PATH}" "${SYNC_OUTPUT_DIR}/${OUTPUT_FILE}"
    echo "Synced output to ${SYNC_OUTPUT_DIR}/${OUTPUT_FILE}"
fi