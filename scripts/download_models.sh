#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${LTX2_IMAGE_NAME:-ltx2-infer:latest}"
MODEL_DIR="${LTX2_MODEL_DIR:-${ROOT}/../models}"

mkdir -p "${MODEL_DIR}"

docker run --rm -i \
    -e HF_TOKEN="${HF_TOKEN:-}" \
    -e HF_HUB_DISABLE_XET="${HF_HUB_DISABLE_XET:-1}" \
    -e HF_HOME=/workspace/models/.hf-cache \
    -v "${MODEL_DIR}":/workspace/models \
    "${IMAGE_NAME}" \
    python3 - <<'PY'
import os
import sys
from pathlib import Path

from huggingface_hub import hf_hub_download, snapshot_download
from huggingface_hub.errors import GatedRepoError, HfHubHTTPError

model_dir = Path("/workspace/models")
token = os.environ.get("HF_TOKEN") or None

print("Downloading spatial upscaler...")
hf_hub_download(
    repo_id="Lightricks/LTX-2.3",
    filename="ltx-2.3-spatial-upscaler-x2-1.1.safetensors",
    local_dir=model_dir,
    token=token,
)

print("Downloading distilled checkpoint...")
hf_hub_download(
    repo_id="Lightricks/LTX-2.3",
    filename="ltx-2.3-22b-distilled-1.1.safetensors",
    local_dir=model_dir,
    token=token,
)

print("Downloading dev checkpoint for production two-stage pipelines...")
hf_hub_download(
    repo_id="Lightricks/LTX-2.3",
    filename="ltx-2.3-22b-dev.safetensors",
    local_dir=model_dir,
    token=token,
)

print("Downloading distilled LoRA for production two-stage pipelines...")
hf_hub_download(
    repo_id="Lightricks/LTX-2.3",
    filename="ltx-2.3-22b-distilled-lora-384-1.1.safetensors",
    local_dir=model_dir,
    token=token,
)

print("Downloading Gemma text encoder...")
try:
    snapshot_download(
        repo_id="google/gemma-3-12b-it-qat-q4_0-unquantized",
        local_dir=model_dir / "gemma-3-12b-it-qat-q4_0-unquantized",
        token=token,
    )
except GatedRepoError:
    print(
        "Gemma download requires an authenticated Hugging Face token with access to "
        "google/gemma-3-12b-it-qat-q4_0-unquantized.",
        file=sys.stderr,
    )
    print("Set HF_TOKEN in the shell and rerun scripts/download_models.sh.", file=sys.stderr)
    raise SystemExit(2)
except HfHubHTTPError as exc:
    message = str(exc)
    if "public gated repositories" in message:
        print(
            "Your Hugging Face token is valid, but its fine-grained settings do not allow "
            "access to public gated repositories.",
            file=sys.stderr,
        )
        print(
            "Enable that permission for this token, or use a read token that can access gated public repos.",
            file=sys.stderr,
        )
        raise SystemExit(3)
    raise
print("Model downloads complete.")
PY