#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_DIR="${LTX2_MODEL_DIR:-${ROOT}/../models}"
OUTPUT_DIR="${LTX2_OUTPUT_DIR:-${ROOT}/outputs}"
SYNC_OUTPUT_DIR="${LTX2_SYNC_OUTPUT_DIR:-${ROOT}/outputs}"

REFERENCE_FILE="$(basename "${LTX2_REFERENCE_OUTPUT_FILE:-daniel-wu-streetdance-hq-reference-1024x640.mp4}")"
FINAL_FILE="$(basename "${LTX2_OUTPUT_FILE:-daniel-wu-streetdance-hq-ic-lora-1024x640.mp4}")"
REFERENCE_PATH="${OUTPUT_DIR}/${REFERENCE_FILE}"
REUSE_REFERENCE="${LTX2_REUSE_REFERENCE:-0}"

HEIGHT="${LTX2_HEIGHT:-640}"
WIDTH="${LTX2_WIDTH:-1024}"
NUM_FRAMES="${LTX2_NUM_FRAMES:-561}"
FRAME_RATE="${LTX2_FRAME_RATE:-24}"
OFFLOAD="${LTX2_OFFLOAD:-none}"
HQ_STEPS="${LTX2_HQ_NUM_INFERENCE_STEPS:-30}"
REFERENCE_STRENGTH="${LTX2_REFERENCE_STRENGTH:-0.75}"

HQ_PROMPT="${LTX2_HQ_PROMPT:-A single continuous uncut one-shot realistic concert film of Daniel Wu, one adult male performer alone on a large nighttime concert stage, performing energetic hip-hop street dance. The camera stays close enough for clean recognizable facial detail and upper-body motion, mostly medium-wide and waist-up framing with occasional full-body footwork shots. He wears a fitted black and silver stage outfit with tasteful athletic styling, moving through sharp chest pops, shoulder hits, fast footwork, body waves, spins, freezes, and powerful rhythmic gestures synchronized to strong electronic pop concert music. The stage has neon LED walls, moving spotlights, haze, glossy reflective floor, backlights, cheering crowd silhouettes, and occasional confetti near the ending. The camera never cuts: it begins as a low wide crane push-in on the opening downbeat, settles into a closer face-readable tracking view, glides laterally with the footwork, eases into a smooth semicircle orbit during the chorus, then rises into a short overhead reveal for the finale, all as one continuous camera move synchronized to the beat, no repeated camera movement, cinematic realistic lighting, coherent stage layout, stable natural face and outfit throughout.}"

IC_PROMPT="${LTX2_IC_PROMPT:-A refined realistic long one-take concert film of Daniel Wu, one adult male performer alone on the same nighttime concert stage, preserving the reference video stage layout, hip-hop dance timing, outfit, and camera motion while improving stable natural face detail, clean facial features, coherent anatomy, crisp hands, and high-quality concert lighting. Keep the neon LED walls, moving spotlights, haze, glossy reflective floor, cheering crowd silhouettes, energetic rhythmic street dance, tasteful athletic stage styling, and one continuous camera move with no cuts.}"

mkdir -p "${OUTPUT_DIR}" "${SYNC_OUTPUT_DIR}"

if [[ "${REUSE_REFERENCE}" != "1" || ! -f "${REFERENCE_PATH}" ]]; then
    env \
        LTX2_MODEL_DIR="${MODEL_DIR}" \
        LTX2_OUTPUT_DIR="${OUTPUT_DIR}" \
        LTX2_SYNC_OUTPUT_DIR="${SYNC_OUTPUT_DIR}" \
        LTX2_OUTPUT_FILE="${REFERENCE_FILE}" \
        LTX2_HEIGHT="${HEIGHT}" \
        LTX2_WIDTH="${WIDTH}" \
        LTX2_NUM_FRAMES="${NUM_FRAMES}" \
        LTX2_FRAME_RATE="${FRAME_RATE}" \
        LTX2_NUM_INFERENCE_STEPS="${HQ_STEPS}" \
        LTX2_OFFLOAD="${OFFLOAD}" \
        "${ROOT}/scripts/run_two_stage_hq.sh" "${HQ_PROMPT}"
else
    echo "Reusing existing HQ reference: ${REFERENCE_PATH}"
fi

env \
    LTX2_MODEL_DIR="${MODEL_DIR}" \
    LTX2_OUTPUT_DIR="${OUTPUT_DIR}" \
    LTX2_SYNC_OUTPUT_DIR="${SYNC_OUTPUT_DIR}" \
    LTX2_OUTPUT_FILE="${FINAL_FILE}" \
    LTX2_REFERENCE_VIDEO="${REFERENCE_PATH}" \
    LTX2_REFERENCE_STRENGTH="${REFERENCE_STRENGTH}" \
    LTX2_HEIGHT="${HEIGHT}" \
    LTX2_WIDTH="${WIDTH}" \
    LTX2_NUM_FRAMES="${NUM_FRAMES}" \
    LTX2_FRAME_RATE="${FRAME_RATE}" \
    LTX2_OFFLOAD="${OFFLOAD}" \
    "${ROOT}/scripts/run_ic_lora.sh" "${IC_PROMPT}"

echo "HQ reference: ${REFERENCE_PATH}"
echo "IC-LoRA output: ${OUTPUT_DIR}/${FINAL_FILE}"
if [[ "$(realpath -m "${OUTPUT_DIR}")" != "$(realpath -m "${SYNC_OUTPUT_DIR}")" ]]; then
    echo "Synced IC-LoRA output: ${SYNC_OUTPUT_DIR}/${FINAL_FILE}"
fi
