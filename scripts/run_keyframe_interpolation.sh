#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${LTX2_IMAGE_NAME:-ltx2-infer:latest}"
MODEL_DIR="${LTX2_MODEL_DIR:-${ROOT}/../models}"
OUTPUT_DIR="${LTX2_OUTPUT_DIR:-${ROOT}/outputs}"
SYNC_OUTPUT_DIR="${LTX2_SYNC_OUTPUT_DIR:-${ROOT}/outputs}"
SYNC_OUTPUT="${LTX2_SYNC_OUTPUT:-1}"
OUTPUT_FILE="$(basename "${LTX2_OUTPUT_FILE:-keyframe-transition.mp4}")"

CHECKPOINT="${LTX2_CHECKPOINT:-${MODEL_DIR}/ltx-2.3-22b-dev.safetensors}"
DISTILLED_LORA="${LTX2_DISTILLED_LORA:-${MODEL_DIR}/ltx-2.3-22b-distilled-lora-384-1.1.safetensors}"
UPSCALER="${LTX2_UPSCALER:-${MODEL_DIR}/ltx-2.3-spatial-upscaler-x2-1.1.safetensors}"
GEMMA_ROOT="${LTX2_GEMMA_ROOT:-${MODEL_DIR}/gemma-3-12b-it-qat-q4_0-unquantized}"
PROMPT="${1:-A smooth cinematic dance transition preserving the same adult male dancer, same studio lighting, same outfit, fluid camera motion.}"
EXTRA_ARGS=("${@:2}")
OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_FILE}"

: "${LTX2_START_IMAGE:?Set LTX2_START_IMAGE to the first keyframe image path.}"
: "${LTX2_END_IMAGE:?Set LTX2_END_IMAGE to the final keyframe image path.}"

mkdir -p "${OUTPUT_DIR}"

for path in "${CHECKPOINT}" "${DISTILLED_LORA}" "${UPSCALER}" "${GEMMA_ROOT}" "${LTX2_START_IMAGE}" "${LTX2_END_IMAGE}"; do
    if [[ ! -e "${path}" ]]; then
        echo "Missing required path: ${path}" >&2
        exit 1
    fi
done

host_to_container_path() {
    local host_path abs_path root_abs output_abs rel_path
    host_path="$1"
    abs_path="$(realpath -m "${host_path}")"
    root_abs="$(realpath -m "${ROOT}")"
    output_abs="$(realpath -m "${OUTPUT_DIR}")"

    if [[ "${abs_path}" == "${output_abs}" ]]; then
        echo "/workspace/outputs"
    elif [[ "${abs_path}" == "${output_abs}"/* ]]; then
        rel_path="${abs_path#"${output_abs}/"}"
        echo "/workspace/outputs/${rel_path}"
    elif [[ "${abs_path}" == "${root_abs}"/* ]]; then
        rel_path="${abs_path#"${root_abs}/"}"
        echo "/workspace/LTX-2/${rel_path}"
    else
        echo "Path is not mounted in Docker: ${host_path}" >&2
        echo "Place conditioning images under ${OUTPUT_DIR} or ${ROOT}." >&2
        return 1
    fi
}

START_IMAGE_CONTAINER="$(host_to_container_path "${LTX2_START_IMAGE}")"
END_IMAGE_CONTAINER="$(host_to_container_path "${LTX2_END_IMAGE}")"
NUM_FRAMES="${LTX2_NUM_FRAMES:-25}"
END_FRAME="${LTX2_END_FRAME:-$((NUM_FRAMES - 1))}"

docker run --rm --gpus all --ipc=host \
    -e HF_HOME=/workspace/models/.hf-cache \
    -v "${ROOT}":/workspace/LTX-2 \
    -v "${MODEL_DIR}":/workspace/models \
    -v "${OUTPUT_DIR}":/workspace/outputs \
    -w /workspace/LTX-2 \
    "${IMAGE_NAME}" \
    python3 -m ltx_pipelines.keyframe_interpolation \
        --checkpoint-path "/workspace/models/$(basename "${CHECKPOINT}")" \
        --distilled-lora "/workspace/models/$(basename "${DISTILLED_LORA}")" "${LTX2_DISTILLED_LORA_STRENGTH:-0.8}" \
        --spatial-upsampler-path "/workspace/models/$(basename "${UPSCALER}")" \
        --gemma-root "/workspace/models/$(basename "${GEMMA_ROOT}")" \
        --prompt "${PROMPT}" \
        --output-path "/workspace/outputs/${OUTPUT_FILE}" \
        --height "${LTX2_HEIGHT:-512}" \
        --width "${LTX2_WIDTH:-768}" \
        --num-frames "${NUM_FRAMES}" \
        --frame-rate "${LTX2_FRAME_RATE:-24}" \
        --num-inference-steps "${LTX2_NUM_INFERENCE_STEPS:-30}" \
        --offload "${LTX2_OFFLOAD:-none}" \
        --image "${START_IMAGE_CONTAINER}" 0 "${LTX2_START_STRENGTH:-1.0}" \
        --image "${END_IMAGE_CONTAINER}" "${END_FRAME}" "${LTX2_END_STRENGTH:-1.0}" \
        "${EXTRA_ARGS[@]}"

if [[ "${SYNC_OUTPUT}" != "0" && "$(realpath -m "${OUTPUT_DIR}")" != "$(realpath -m "${SYNC_OUTPUT_DIR}")" ]]; then
    mkdir -p "${SYNC_OUTPUT_DIR}"
    cp -f "${OUTPUT_PATH}" "${SYNC_OUTPUT_DIR}/${OUTPUT_FILE}"
    echo "Synced output to ${SYNC_OUTPUT_DIR}/${OUTPUT_FILE}"
fi