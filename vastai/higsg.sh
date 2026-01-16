#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Higgs Audio (Higgs TTS) Vast.ai Provisioning Script (UPDATED)
# - Fixes hf hub version conflicts (<1.0)
# - Uses `hf` CLI instead of `huggingface-cli`
# - Downloads models to WORKSPACE for persistence
# ------------------------------------------------------------------------------

echo "[higgs] Provisioning start: $(date -Is)"

# Skip provisioning if flag exists (common Vast pattern)
if [ -f "/.noprovisioning" ]; then
  echo "[higgs] /.noprovisioning present -> skipping provisioning."
  exit 0
fi

# Persistent workspace (Vast usually provides WORKSPACE)
WORKSPACE="${WORKSPACE:-/workspace}"
mkdir -p "$WORKSPACE"

# Logging
LOG_DIR="${WORKSPACE}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/provision_higgs.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[higgs] WORKSPACE=$WORKSPACE"

# ------------------------------------------------------------------------------
# 1) Activate template venv if present
# ------------------------------------------------------------------------------
if [ -f "/venv/main/bin/activate" ]; then
  # shellcheck disable=SC1091
  source /venv/main/bin/activate
  echo "[higgs] Activated /venv/main"
else
  echo "[higgs] WARNING: /venv/main not found. Using system python/pip."
fi

python -V || true
python -m pip -V || true

# ------------------------------------------------------------------------------
# 2) System deps for audio + build
# ------------------------------------------------------------------------------
echo "[higgs] Installing system deps (ffmpeg, libsndfile, git, etc.)"
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
# 3) Clone / update Higgs repo
# ------------------------------------------------------------------------------
HIGGS_DIR="${WORKSPACE}/higgs-audio"
if [ -d "${HIGGS_DIR}/.git" ]; then
  echo "[higgs] Repo exists -> git pull"
  cd "$HIGGS_DIR"
  git fetch --all --prune
  git pull --rebase
else
  echo "[higgs] Cloning repo to ${HIGGS_DIR}"
  git clone https://github.com/boson-ai/higgs-audio.git "$HIGGS_DIR"
  cd "$HIGGS_DIR"
fi

# ------------------------------------------------------------------------------
# 4) Python deps
# ------------------------------------------------------------------------------
echo "[higgs] Upgrading pip"
python -m pip install --upgrade pip

echo "[higgs] Installing Higgs python requirements"
python -m pip install -r requirements.txt
python -m pip install -e .

# ------------------------------------------------------------------------------
# 5) Hugging Face Hub (PIN < 1.0) + CLI (`hf`)
#    This avoids: tokenizers/transformers require huggingface-hub<1.0
# ------------------------------------------------------------------------------
echo "[higgs] Installing compatible huggingface_hub (<1.0) with hf CLI"

# Remove any incompatible hub
python -m pip uninstall -y huggingface_hub hf-xet || true

# Install a compatible 0.x series with CLI
python -m pip install -U "huggingface_hub[cli]>=0.26.0,<1.0"

# Verify CLI exists
if ! command -v hf >/dev/null 2>&1; then
  echo "[higgs] ERROR: hf CLI not found after install. Check venv/PATH."
  exit 1
fi

hf --version || true

# ------------------------------------------------------------------------------
# 6) Persistent HF cache (IMPORTANT)
# ------------------------------------------------------------------------------
export HF_HOME="${WORKSPACE}/hf"
export TRANSFORMERS_CACHE="${WORKSPACE}/hf"
export HUGGINGFACE_HUB_CACHE="${WORKSPACE}/hf"
mkdir -p "$HF_HOME"

echo "[higgs] HF_HOME=$HF_HOME"

# Optional auth (set HF_TOKEN env var in Vast)
if [ -n "${HF_TOKEN:-}" ]; then
  echo "[higgs] HF_TOKEN provided -> hf auth login"
  hf auth login --token "$HF_TOKEN" --add-to-git-credential
else
  echo "[higgs] No HF_TOKEN provided -> proceeding anonymous (may be rate-limited)."
fi

# ------------------------------------------------------------------------------
# 7) Download models (weights + tokenizer) into WORKSPACE
# ------------------------------------------------------------------------------
MODEL_ID="${MODEL_ID:-bosonai/higgs-audio-v2-generation-3B-base}"
TOKENIZER_ID="${TOKENIZER_ID:-bosonai/higgs-audio-v2-tokenizer}"

MODELS_DIR="${WORKSPACE}/models"
MODEL_DIR="${MODELS_DIR}/higgs-audio-v2-generation-3B-base"
TOKENIZER_DIR="${MODELS_DIR}/higgs-audio-v2-tokenizer"

mkdir -p "$MODELS_DIR"

download_if_missing() {
  local repo_id="$1"
  local out_dir="$2"
  local marker="$3"

  if [ -f "$marker" ]; then
    echo "[higgs] Already downloaded: $repo_id (marker exists)"
    return 0
  fi

  echo "[higgs] Downloading: $repo_id -> $out_dir"
  mkdir -p "$out_dir"

  # `hf download` supports --local-dir
  hf download "$repo_id" --local-dir "$out_dir"

  echo "$repo_id" > "$marker"
}

download_if_missing "$MODEL_ID" "$MODEL_DIR" "${MODEL_DIR}/.download_ok"
download_if_missing "$TOKENIZER_ID" "$TOKENIZER_DIR" "${TOKENIZER_DIR}/.download_ok"

echo "[higgs] Models present under: $MODELS_DIR"

# ------------------------------------------------------------------------------
# 8) Smoke test (CUDA presence)
# ------------------------------------------------------------------------------
SMOKE="${WORKSPACE}/higgs_smoke_test.py"
cat > "$SMOKE" <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda_available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("gpu:", torch.cuda.get_device_name(0))
PY

echo "[higgs] Running smoke test"
python "$SMOKE" || true

# ------------------------------------------------------------------------------
# 9) Final hints
# ------------------------------------------------------------------------------
echo "[higgs] Provisioning complete: $(date -Is)"
echo
echo "[higgs] Example run:"
echo "  cd ${HIGGS_DIR}"
echo "  export HF_HOME=${HF_HOME}"
echo "  python3 examples/generation.py \\"
echo "    --transcript \"Hola. Esto es una prueba.\" \\"
echo "    --temperature 0.3 \\"
echo "    --out_path ${WORKSPACE}/generation.wav"
echo
echo "[higgs] Logs: ${LOG_FILE}"
