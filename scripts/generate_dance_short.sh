#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${LTX2_IMAGE_NAME:-ltx2-infer:latest}"
OUTPUT_DIR="${LTX2_OUTPUT_DIR:-${ROOT}/outputs}"
SYNC_OUTPUT_DIR="${LTX2_SYNC_OUTPUT_DIR:-${ROOT}/outputs}"
MODEL_DIR="${LTX2_MODEL_DIR:-${ROOT}/../models}"

mkdir -p "${OUTPUT_DIR}" "${SYNC_OUTPUT_DIR}"

BASE_ENV=(
    LTX2_MODEL_DIR="${MODEL_DIR}"
    LTX2_OUTPUT_DIR="${OUTPUT_DIR}"
    LTX2_SYNC_OUTPUT_DIR="${SYNC_OUTPUT_DIR}"
    LTX2_HEIGHT="${LTX2_HEIGHT:-512}"
    LTX2_WIDTH="${LTX2_WIDTH:-768}"
    LTX2_FRAME_RATE="${LTX2_FRAME_RATE:-24}"
    LTX2_NUM_INFERENCE_STEPS="${LTX2_NUM_INFERENCE_STEPS:-30}"
    LTX2_OFFLOAD="${LTX2_OFFLOAD:-none}"
)

extract_first_frame() {
    local video_path image_path
    video_path="$1"
    image_path="$2"
    docker run --rm \
        -v "${OUTPUT_DIR}":/workspace/outputs \
        "${IMAGE_NAME}" \
        ffmpeg -y -i "/workspace/outputs/$(basename "${video_path}")" -frames:v 1 "/workspace/outputs/$(basename "${image_path}")"
}

extract_last_frame() {
    local video_path image_path
    video_path="$1"
    image_path="$2"
    docker run --rm \
        -v "${OUTPUT_DIR}":/workspace/outputs \
        "${IMAGE_NAME}" \
        ffmpeg -y -sseof -0.12 -i "/workspace/outputs/$(basename "${video_path}")" -update 1 -q:v 2 "/workspace/outputs/$(basename "${image_path}")"
}

generate_shot() {
    local output_file prompt image_path
    output_file="$1"
    prompt="$2"
    image_path="${3:-}"

    if [[ -n "${image_path}" ]]; then
        env "${BASE_ENV[@]}" LTX2_OUTPUT_FILE="${output_file}" LTX2_NUM_FRAMES="${LTX2_SHOT_FRAMES:-121}" \
            "${ROOT}/scripts/run_two_stage.sh" "${prompt}" \
            --image "/workspace/outputs/$(basename "${image_path}")" 0 "${LTX2_REFERENCE_STRENGTH:-0.72}"
    else
        env "${BASE_ENV[@]}" LTX2_OUTPUT_FILE="${output_file}" LTX2_NUM_FRAMES="${LTX2_SHOT_FRAMES:-121}" \
            "${ROOT}/scripts/run_two_stage.sh" "${prompt}"
    fi
}

generate_transition() {
    local output_file start_image end_image prompt
    output_file="$1"
    start_image="$2"
    end_image="$3"
    prompt="$4"
    env "${BASE_ENV[@]}" LTX2_OUTPUT_FILE="${output_file}" LTX2_NUM_FRAMES="${LTX2_TRANSITION_FRAMES:-25}" \
        LTX2_START_IMAGE="${start_image}" LTX2_END_IMAGE="${end_image}" \
        "${ROOT}/scripts/run_keyframe_interpolation.sh" "${prompt}"
}

SUBJECT="a five-member adult male idol group performing on a large nighttime concert stage, handsome athletic members with defined physiques, smooth fair skin, coordinated black and white stage outfits with fitted sleeveless tops, tasteful non-explicit framing, consistent faces and outfits across every shot"
STYLE="cinematic realistic K-pop concert film, powerful beat-driven electronic pop background music, synchronized rhythmic choreography, neon LED walls, moving spotlights, haze, cheering crowd silhouettes, glossy stage floor, dramatic but clean lighting, camera movement locked to the music beat, no repeated camera moves"

SHOT_01_PROMPT="${SUBJECT}. They open in a tight V formation under blue and white spotlights, hitting sharp chest pops and shoulder accents on a heavy downbeat. The camera starts with a low wide crane push-in timed to the first four beats, then cuts into a brief stabilized front tracking move, ${STYLE}."
SHOT_02_PROMPT="${SUBJECT}. The group breaks into alternating center swaps and synchronized footwork, emphasizing athletic torsos and clean arm lines. The camera uses a lateral steadicam sweep from stage left to stage right, landing exactly on each bass hit, with LED equalizer graphics pulsing behind them, ${STYLE}."
SHOT_03_PROMPT="${SUBJECT}. They perform a high-energy chorus section with body rolls, fast hand hits, and a compact wave passing from member to member. The camera switches to a controlled semicircle orbit around the formation, accelerating only on drum fills and avoiding the previous push-in or side sweep, ${STYLE}."
SHOT_04_PROMPT="${SUBJECT}. The finale moves to the front edge of the stage with a powerful synchronized freeze, bright backlights, confetti bursts, and the crowd glowing beyond the runway. The camera rises from a low hero angle into a short overhead reveal on the final beat, then holds a clean final frame, ${STYLE}."

TRANSITION_PROMPT="A smooth keyframe interpolation preserving the same adult male idol group, same coordinated stage outfits, same nighttime concert stage, continuous beat-synchronized choreography, rhythmic motion blur, lighting changes matching strong electronic pop music, varied camera movement without repeating the previous shot."

generate_shot "idol-boyband-shot-01.mp4" "${SHOT_01_PROMPT}"
extract_first_frame "${OUTPUT_DIR}/idol-boyband-shot-01.mp4" "${OUTPUT_DIR}/idol-boyband-reference.png"
extract_last_frame "${OUTPUT_DIR}/idol-boyband-shot-01.mp4" "${OUTPUT_DIR}/idol-boyband-shot-01-last.png"

generate_shot "idol-boyband-shot-02.mp4" "${SHOT_02_PROMPT}" "${OUTPUT_DIR}/idol-boyband-reference.png"
extract_first_frame "${OUTPUT_DIR}/idol-boyband-shot-02.mp4" "${OUTPUT_DIR}/idol-boyband-shot-02-first.png"
extract_last_frame "${OUTPUT_DIR}/idol-boyband-shot-02.mp4" "${OUTPUT_DIR}/idol-boyband-shot-02-last.png"

generate_transition "idol-boyband-transition-01-02.mp4" "${OUTPUT_DIR}/idol-boyband-shot-01-last.png" "${OUTPUT_DIR}/idol-boyband-shot-02-first.png" "${TRANSITION_PROMPT}"

generate_shot "idol-boyband-shot-03.mp4" "${SHOT_03_PROMPT}" "${OUTPUT_DIR}/idol-boyband-reference.png"
extract_first_frame "${OUTPUT_DIR}/idol-boyband-shot-03.mp4" "${OUTPUT_DIR}/idol-boyband-shot-03-first.png"
extract_last_frame "${OUTPUT_DIR}/idol-boyband-shot-03.mp4" "${OUTPUT_DIR}/idol-boyband-shot-03-last.png"

generate_transition "idol-boyband-transition-02-03.mp4" "${OUTPUT_DIR}/idol-boyband-shot-02-last.png" "${OUTPUT_DIR}/idol-boyband-shot-03-first.png" "${TRANSITION_PROMPT}"

generate_shot "idol-boyband-shot-04.mp4" "${SHOT_04_PROMPT}" "${OUTPUT_DIR}/idol-boyband-reference.png"
extract_first_frame "${OUTPUT_DIR}/idol-boyband-shot-04.mp4" "${OUTPUT_DIR}/idol-boyband-shot-04-first.png"

generate_transition "idol-boyband-transition-03-04.mp4" "${OUTPUT_DIR}/idol-boyband-shot-03-last.png" "${OUTPUT_DIR}/idol-boyband-shot-04-first.png" "${TRANSITION_PROMPT}"

CONCAT_FILE="${OUTPUT_DIR}/idol-boyband-concat.txt"
VIDEO_ONLY_FILE="idol-boyband-final-video-only.mp4"
FINAL_AUDIO_FILE="idol-boyband-final-crossfade-audio.m4a"
FINAL_DURATION="${LTX2_FINAL_DURATION:-23.294}"
FINAL_AUDIO_FADE_OUT_START="${LTX2_FINAL_AUDIO_FADE_OUT_START:-22.6}"
FINAL_AUDIO_CROSSFADE="${LTX2_FINAL_AUDIO_CROSSFADE:-0.18}"
cat > "${CONCAT_FILE}" <<EOF
file '/workspace/outputs/idol-boyband-shot-01.mp4'
file '/workspace/outputs/idol-boyband-transition-01-02.mp4'
file '/workspace/outputs/idol-boyband-shot-02.mp4'
file '/workspace/outputs/idol-boyband-transition-02-03.mp4'
file '/workspace/outputs/idol-boyband-shot-03.mp4'
file '/workspace/outputs/idol-boyband-transition-03-04.mp4'
file '/workspace/outputs/idol-boyband-shot-04.mp4'
EOF

docker run --rm \
    -v "${OUTPUT_DIR}":/workspace/outputs \
    "${IMAGE_NAME}" \
    ffmpeg -y -f concat -safe 0 -i /workspace/outputs/$(basename "${CONCAT_FILE}") -map 0:v:0 -an -c:v copy "/workspace/outputs/${VIDEO_ONLY_FILE}"

docker run --rm \
    -v "${OUTPUT_DIR}":/workspace/outputs \
    "${IMAGE_NAME}" \
    ffmpeg -y \
        -i /workspace/outputs/idol-boyband-shot-01.mp4 \
        -i /workspace/outputs/idol-boyband-transition-01-02.mp4 \
        -i /workspace/outputs/idol-boyband-shot-02.mp4 \
        -i /workspace/outputs/idol-boyband-transition-02-03.mp4 \
        -i /workspace/outputs/idol-boyband-shot-03.mp4 \
        -i /workspace/outputs/idol-boyband-transition-03-04.mp4 \
        -i /workspace/outputs/idol-boyband-shot-04.mp4 \
        -filter_complex "[0:a][1:a]acrossfade=d=${FINAL_AUDIO_CROSSFADE}:c1=tri:c2=tri[a01];[a01][2:a]acrossfade=d=${FINAL_AUDIO_CROSSFADE}:c1=tri:c2=tri[a02];[a02][3:a]acrossfade=d=${FINAL_AUDIO_CROSSFADE}:c1=tri:c2=tri[a03];[a03][4:a]acrossfade=d=${FINAL_AUDIO_CROSSFADE}:c1=tri:c2=tri[a04];[a04][5:a]acrossfade=d=${FINAL_AUDIO_CROSSFADE}:c1=tri:c2=tri[a05];[a05][6:a]acrossfade=d=${FINAL_AUDIO_CROSSFADE}:c1=tri:c2=tri,apad,atrim=0:${FINAL_DURATION},afade=t=out:st=${FINAL_AUDIO_FADE_OUT_START}:d=0.7[aout]" \
        -map "[aout]" -c:a aac "/workspace/outputs/${FINAL_AUDIO_FILE}"

docker run --rm \
    -v "${OUTPUT_DIR}":/workspace/outputs \
    "${IMAGE_NAME}" \
    ffmpeg -y -i "/workspace/outputs/${VIDEO_ONLY_FILE}" -i "/workspace/outputs/${FINAL_AUDIO_FILE}" -map 0:v:0 -map 1:a:0 -c:v copy -c:a copy -shortest /workspace/outputs/idol-boyband-final.mp4

if [[ "$(realpath -m "${OUTPUT_DIR}")" != "$(realpath -m "${SYNC_OUTPUT_DIR}")" ]]; then
    cp -f "${OUTPUT_DIR}/idol-boyband-final.mp4" "${SYNC_OUTPUT_DIR}/idol-boyband-final.mp4"
    echo "Synced output to ${SYNC_OUTPUT_DIR}/idol-boyband-final.mp4"
fi