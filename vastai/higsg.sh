#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Higgs Audio (Higgs TTS) Vast.ai Provisioning Script — FINAL STABLE
# - Forces PyTorch-only (disables TensorFlow)
# - Pins huggingface_hub < 1.0
# - Uses `hf` CLI
# - Downloads models persistently
# ------------------------------------------------------------------------------

echo "[higgs] Provisioning start: $(date -Is)"

# Skip provisioning if flag exists
if [ -f "/.noprovisioning" ]; then
  echo "[higgs] /.noprovisioning present -> skipping provisioning."
  exit 0
fi

# ------------------------------------------------------------------------------
# Workspace & logging
# ------------------------------------------------------------------------------
WORKSPACE="${WORKSPACE:-/workspace}"
mkdir -p "$WORKSPACE"

LOG_DIR="${WORKSPACE}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/provision_higgs.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[higgs] WORKSPACE=$WORKSPACE"

# ------------------------------------------------------------------------------
# 1) Activate venv
# ------------------------------------------------------------------------------
if [ -f "/venv/main/bin/activate" ]; then
  # shellcheck disable=SC1091
  source /venv/main/bin/activate
  echo "[higgs] Activated /venv/main"
else
  echo "[higgs] WARNING: /venv/main not found"
fi

python -V || true
python -m pip -V || true

# ------------------------------------------------------------------------------
# 2) Force PyTorch-only Transformers (NO TensorFlow)
# ------------------------------------------------------------------------------
echo "[higgs] Disabling TensorFlow for Transformers"
export TRANSFORMERS_NO_TF=1
export USE_TF=0

# Remove TensorFlow if present (prevents protobuf crashes)
python -m pip uninstall -y \
  tensorflow \
  tensorflow-cpu \
  tensorflow-gpu \
  tensorflow-intel \
  tensorflow-io-gcs-filesystem || true

# ------------------------------------------------------------------------------
# 3) System dependencies
# ------------------------------------------------------------------------------
echo "[higgs] Installing system deps"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
  git \
  ffmpeg \
  libsndfile1 \
  ca-certificates \
  curl \
  build-essential

# ------------------------------------------------------------------------------
# 4) Clone / update Higgs repo
# ------------------------------------------------------------------------------
HIGGS_DIR="${WORKSPACE}/higgs-audio"

if [ -d "${HIGGS_DIR}/.git" ]; then
  echo "[higgs] Updating Higgs repo"
  cd "$HIGGS_DIR"
  git fetch --all --prune
  git pull --rebase
else
  echo "[higgs] Cloning Higgs repo"
  git clone https://github.com/boson-ai/higgs-audio.git "$HIGGS_DIR"
  cd "$HIGGS_DIR"
fi

# ------------------------------------------------------------------------------
# 5) Python deps
# ------------------------------------------------------------------------------
echo "[higgs] Upgrading pip"
python -m pip install --upgrade pip

echo "[higgs] Installing Higgs requirements"
python -m pip install -r requirements.txt
python -m pip install -e .

# ------------------------------------------------------------------------------
# 6) Hugging Face Hub (pin <1.0) + hf CLI
# ------------------------------------------------------------------------------
echo "[higgs] Installing compatible huggingface_hub (<1.0)"

python -m pip uninstall -y huggingface_hub hf-xet || true
python -m pip install -U "huggingface_hub[cli]>=0.26.0,<1.0"

if ! command -v hf >/dev/null 2>&1; then
  echo "[higgs] ERROR: hf CLI not found"
  exit 1
fi

hf --version || true

# ------------------------------------------------------------------------------
# 7) Persistent HF cache
# ------------------------------------------------------------------------------
export HF_HOME="${WORKSPACE}/hf"
export TRANSFORMERS_CACHE="${WORKSPACE}/hf"
export HUGGINGFACE_HUB_CACHE="${WORKSPACE}/hf"
mkdir -p "$HF_HOME"

echo "[higgs] HF_HOME=$HF_HOME"

# Optional auth
if [ -n "${HF_TOKEN:-}" ]; then
  echo "[higgs] Logging into Hugging Face"
  hf auth login --token "$HF_TOKEN" --add-to-git-credential
else
  echo "[higgs] No HF_TOKEN provided (anonymous)"
fi

# ------------------------------------------------------------------------------
# 8) Download models (idempotent)
# ------------------------------------------------------------------------------
MODEL_ID="bosonai/higgs-audio-v2-generation-3B-base"
TOKENIZER_ID="bosonai/higgs-audio-v2-tokenizer"

MODELS_DIR="${WORKSPACE}/models"
MODEL_DIR="${MODELS_DIR}/higgs-audio-v2-generation-3B-base"
TOKENIZER_DIR="${MODELS_DIR}/higgs-audio-v2-tokenizer"

mkdir -p "$MODELS_DIR"

download_if_missing() {
  local repo_id="$1"
  local out_dir="$2"
  local marker="$3"

  if [ -f "$marker" ]; then
    echo "[higgs] Already downloaded: $repo_id"
    return 0
  fi

  echo "[higgs] Downloading $repo_id"
  mkdir -p "$out_dir"
  hf download "$repo_id" --local-dir "$out_dir"
  echo "$repo_id" > "$marker"
}

download_if_missing "$MODEL_ID" "$MODEL_DIR" "${MODEL_DIR}/.download_ok"
download_if_missing "$TOKENIZER_ID" "$TOKENIZER_DIR" "${TOKENIZER_DIR}/.download_ok"

# ------------------------------------------------------------------------------
# 9) Smoke test (CUDA)
# ------------------------------------------------------------------------------
echo "[higgs] Running smoke test"

python - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda_available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("gpu:", torch.cuda.get_device_name(0))
PY

# ------------------------------------------------------------------------------
# 10) Final instructions
# ------------------------------------------------------------------------------
echo
echo "[higgs] Provisioning complete: $(date -Is)"
echo
echo "[higgs] Test command:"
echo "  source /venv/main/bin/activate"
echo "  export TRANSFORMERS_NO_TF=1"
echo "  export USE_TF=0"
echo "  cd /workspace/higgs-audio"
echo "  python examples/generation.py \\"
echo "    --transcript \"Bienvenidos a Registro Cero.\" \\"
echo "    --temperature 0.3 \\"
echo "    --out_path /workspace/prueba.wav"
echo
echo "[higgs] Logs: $LOG_FILE"
