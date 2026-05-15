FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    ffmpeg \
    git \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    libsm6 \
    libxext6 \
    libxrender1 \
    python3 \
    python3-pip \
    python3-venv \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace/LTX-2

COPY pyproject.toml uv.lock README.md ./

RUN python3 -m pip install --upgrade pip setuptools wheel
RUN python3 -m pip install --index-url https://download.pytorch.org/whl/cu118 \
    torch==2.7.1 \
    torchaudio==2.7.1 \
    torchvision==0.22.1

COPY packages ./packages

RUN python3 -m pip install \
    -e packages/ltx-core \
    -e packages/ltx-pipelines
RUN python3 -m pip install transformers==4.57.6

CMD ["python3", "-m", "ltx_pipelines.distilled", "--help"]