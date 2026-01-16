#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Higgs Audio (Higgs TTS) Vast.ai Provisioning Script
# - Clona/actualiza repo
# - Instala deps
# - Descarga modelos en WORKSPACE (persistente)
# ------------------------------------------------------------------------------

echo "[higgs] Provisioning start: $(date -Is)"

# Permite saltarte provisioning si existe este flag (patrón Vast común)
if [ -f "/.noprovisioning" ]; then
  echo "[higgs] /.noprovisioning present -> skipping provisioning."
  exit 0
fi

# WORKSPACE suele existir en Vast y apuntar a almacenamiento persistente
WORKSPACE="${WORKSPACE:-/workspace}"
mkdir -p "$WORKSPACE"

# Logging simple
LOG_DIR="${WORKSPACE}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/provision_higgs.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[higgs] WORKSPACE=$WORKSPACE"

# ------------------------------------------------------------------------------
# 1) Activar venv base del template (muchos templates Vast lo traen aquí)
# ------------------------------------------------------------------------------
if [ -f "/venv/main/bin/activate" ]; then
  # shellcheck disable=SC1091
  source /venv/main/bin/activate
  echo "[higgs] Activated /venv/main"
else
  echo "[higgs] WARNING: /venv/main not found. Using system python/pip."
fi

python -V || true
pip -V || true

# ------------------------------------------------------------------------------
# 2) Dependencias del sistema (audio + build basics)
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
# 3) Clonar/actualizar repo Higgs
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

echo "[higgs] Installing python requirements"
pip install -r requirements.txt
pip install -e .

# Hugging Face tooling
echo "[higgs] Ensuring huggingface_hub + hf cli"
pip install --upgrade "huggingface_hub[cli]"

# ------------------------------------------------------------------------------
# 5) Configurar cache persistente HF (IMPORTANTÍSIMO)
# ------------------------------------------------------------------------------
export HF_HOME="${WORKSPACE}/hf"
export TRANSFORMERS_CACHE="${WORKSPACE}/hf"
export HUGGINGFACE_HUB_CACHE="${WORKSPACE}/hf"
mkdir -p "$HF_HOME"

echo "[higgs] HF_HOME=$HF_HOME"

# Login opcional (si pasas HF_TOKEN en Vast ENV)
if [ -n "${HF_TOKEN:-}" ]; then
  echo "[higgs] HF_TOKEN provided -> logging in (non-interactive)"
  huggingface-cli login --token "$HF_TOKEN" --add-to-git-credential true || true
else
  echo "[higgs] No HF_TOKEN provided -> proceeding anonymous (may be rate-limited)."
fi

# ------------------------------------------------------------------------------
# 6) Descarga de modelos (pesos + tokenizer)
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

  # --local-dir-use-symlinks False evita symlinks raros cuando WORKSPACE está en FS distinto
  huggingface-cli download "$repo_id" \
    --local-dir "$out_dir" \
    --local-dir-use-symlinks False

  # Marker para idempotencia
  echo "$repo_id" > "$marker"
}

download_if_missing "$MODEL_ID" "$MODEL_DIR" "${MODEL_DIR}/.download_ok"
download_if_missing "$TOKENIZER_ID" "$TOKENIZER_DIR" "${TOKENIZER_DIR}/.download_ok"

echo "[higgs] Models downloaded under: $MODELS_DIR"

# ------------------------------------------------------------------------------
# 7) Smoke test (no genera audio, solo confirma que CUDA existe)
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
# 8) Instrucciones útiles
# ------------------------------------------------------------------------------
echo "[higgs] Provisioning complete: $(date -Is)"
echo
echo "[higgs] Next steps (example):"
echo "  cd ${HIGGS_DIR}"
echo "  export HF_HOME=${HF_HOME}"
echo "  python3 examples/generation.py \\"
echo "    --transcript \"Hola. Esto es una prueba.\" \\"
echo "    --temperature 0.3 \\"
echo "    --out_path ${WORKSPACE}/generation.wav"
echo
echo "[higgs] Logs: ${LOG_FILE}"
