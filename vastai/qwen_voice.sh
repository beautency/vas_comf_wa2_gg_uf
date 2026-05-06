#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Qwen3-TTS Vast.ai Provisioning Script
# - Based on higsg.sh structure
# - Installs qwen-tts and persistent Hugging Face cache
# - Downloads Qwen3 TTS models for voice design, custom voice, and cloning
# ------------------------------------------------------------------------------

echo "[qwen-voice] Provisioning start: $(date -Is)"

if [ -f "/.noprovisioning" ]; then
  echo "[qwen-voice] /.noprovisioning present -> skipping provisioning."
  exit 0
fi

# ------------------------------------------------------------------------------
# Workspace & logging
# ------------------------------------------------------------------------------
WORKSPACE="${WORKSPACE:-/workspace}"
mkdir -p "$WORKSPACE"

LOG_DIR="${WORKSPACE}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/provision_qwen_voice.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[qwen-voice] WORKSPACE=$WORKSPACE"

# ------------------------------------------------------------------------------
# 1) Activate venv
# ------------------------------------------------------------------------------
if [ -f "/venv/main/bin/activate" ]; then
  # shellcheck disable=SC1091
  source /venv/main/bin/activate
  echo "[qwen-voice] Activated /venv/main"
else
  echo "[qwen-voice] WARNING: /venv/main not found"
fi

python -V || true
python -m pip -V || true

# ------------------------------------------------------------------------------
# 2) System dependencies
# ------------------------------------------------------------------------------
echo "[qwen-voice] Installing system deps"
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
# 3) Python deps
# ------------------------------------------------------------------------------
echo "[qwen-voice] Upgrading pip"
python -m pip install --upgrade pip setuptools wheel

echo "[qwen-voice] Installing Qwen TTS runtime"
python -m pip install -U qwen-tts soundfile

# ------------------------------------------------------------------------------
# 4) Hugging Face CLI and persistent cache
# ------------------------------------------------------------------------------
echo "[qwen-voice] Installing huggingface_hub CLI"
python -m pip uninstall -y hf-xet || true
python -m pip install -U "huggingface_hub[cli]>=0.26.0,<1.0"

if ! command -v hf >/dev/null 2>&1; then
  echo "[qwen-voice] ERROR: hf CLI not found"
  exit 1
fi

hf --version || true

export HF_HOME="${WORKSPACE}/hf"
export TRANSFORMERS_CACHE="${WORKSPACE}/hf"
export HUGGINGFACE_HUB_CACHE="${WORKSPACE}/hf"
mkdir -p "$HF_HOME"

echo "[qwen-voice] HF_HOME=$HF_HOME"

if [ -n "${HF_TOKEN:-}" ]; then
  echo "[qwen-voice] Logging into Hugging Face"
  hf auth login --token "$HF_TOKEN" --add-to-git-credential
else
  echo "[qwen-voice] No HF_TOKEN provided (anonymous)"
fi

# ------------------------------------------------------------------------------
# 5) Download models (idempotent)
# ------------------------------------------------------------------------------
VOICE_DESIGN_MODEL_ID="Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"
CUSTOM_VOICE_MODEL_ID="Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice"
VOICE_CLONE_MODEL_ID="Qwen/Qwen3-TTS-12Hz-1.7B-Base"
MODELS_DIR="${WORKSPACE}/models"
VOICE_DESIGN_MODEL_DIR="${MODELS_DIR}/Qwen3-TTS-12Hz-1.7B-VoiceDesign"
CUSTOM_VOICE_MODEL_DIR="${MODELS_DIR}/Qwen3-TTS-12Hz-1.7B-CustomVoice"
VOICE_CLONE_MODEL_DIR="${MODELS_DIR}/Qwen3-TTS-12Hz-1.7B-Base"

mkdir -p "$MODELS_DIR"

download_if_missing() {
  local repo_id="$1"
  local out_dir="$2"
  local marker="$3"

  if [ -f "$marker" ]; then
    echo "[qwen-voice] Already downloaded: $repo_id"
    return 0
  fi

  echo "[qwen-voice] Downloading $repo_id"
  mkdir -p "$out_dir"
  hf download "$repo_id" --local-dir "$out_dir"
  echo "$repo_id" > "$marker"
}

download_if_missing "$VOICE_DESIGN_MODEL_ID" "$VOICE_DESIGN_MODEL_DIR" "${VOICE_DESIGN_MODEL_DIR}/.download_ok"
download_if_missing "$CUSTOM_VOICE_MODEL_ID" "$CUSTOM_VOICE_MODEL_DIR" "${CUSTOM_VOICE_MODEL_DIR}/.download_ok"
download_if_missing "$VOICE_CLONE_MODEL_ID" "$VOICE_CLONE_MODEL_DIR" "${VOICE_CLONE_MODEL_DIR}/.download_ok"

# ------------------------------------------------------------------------------
# 6) Smoke test
# ------------------------------------------------------------------------------
echo "[qwen-voice] Running smoke test"

python - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda_available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("gpu:", torch.cuda.get_device_name(0))

from qwen_tts import Qwen3TTSModel
print("qwen_tts import: ok")
print("voice_design_model:", "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign")
print("custom_voice_model:", "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice")
print("voice_clone_model:", "Qwen/Qwen3-TTS-12Hz-1.7B-Base")
print("smoke_test: ok")
PY

# ------------------------------------------------------------------------------
# 7) Final instructions
# ------------------------------------------------------------------------------
echo
echo "[qwen-voice] Provisioning complete: $(date -Is)"
echo
echo "[qwen-voice] VoiceDesign test command:"
echo "  source /venv/main/bin/activate"
echo "  export HF_HOME=/workspace/hf"
echo "  python - <<'PY'"
echo "  import torch"
echo "  import soundfile as sf"
echo "  from qwen_tts import Qwen3TTSModel"
echo "  model = Qwen3TTSModel.from_pretrained("
echo "      '/workspace/models/Qwen3-TTS-12Hz-1.7B-VoiceDesign',"
echo "      device_map='cuda:0',"
echo "      dtype=torch.bfloat16,"
echo "  )"
echo "  wavs, sr = model.generate_voice_design("
echo "      text='Hola, esto es una prueba de voz con Qwen TTS en Vast.ai.',"
echo "      language='Spanish',"
echo "      instruct='Voz natural, clara y cercana, con tono profesional y amable.'"
echo "  )"
echo "  sf.write('/workspace/qwen_voice_design_test.wav', wavs[0], sr)"
echo "  PY"
echo
echo "[qwen-voice] CustomVoice test command:"
echo "  source /venv/main/bin/activate"
echo "  export HF_HOME=/workspace/hf"
echo "  python - <<'PY'"
echo "  import torch"
echo "  import soundfile as sf"
echo "  from qwen_tts import Qwen3TTSModel"
echo "  model = Qwen3TTSModel.from_pretrained("
echo "      '/workspace/models/Qwen3-TTS-12Hz-1.7B-CustomVoice',"
echo "      device_map='cuda:0',"
echo "      dtype=torch.bfloat16,"
echo "  )"
echo "  wavs, sr = model.generate_custom_voice("
echo "      text='Hola, esta es una prueba con una voz predefinida de Qwen TTS.',"
echo "      language='Spanish',"
echo "      speaker='Chelsie',"
echo "      instruct='Tono calido, natural y seguro.'"
echo "  )"
echo "  sf.write('/workspace/qwen_custom_voice_test.wav', wavs[0], sr)"
echo "  PY"
echo
echo "[qwen-voice] VoiceClone test command:"
echo "  source /venv/main/bin/activate"
echo "  export HF_HOME=/workspace/hf"
echo "  python - <<'PY'"
echo "  import torch"
echo "  import soundfile as sf"
echo "  from qwen_tts import Qwen3TTSModel"
echo "  model = Qwen3TTSModel.from_pretrained("
echo "      '/workspace/models/Qwen3-TTS-12Hz-1.7B-Base',"
echo "      device_map='cuda:0',"
echo "      dtype=torch.bfloat16,"
echo "  )"
echo "  wavs, sr = model.generate_voice_clone("
echo "      text='Hola, esta es una prueba de clonacion de voz con Qwen TTS.',"
echo "      ref_audio='/workspace/reference_voice.wav',"
echo "      ref_text='Texto de referencia que corresponde al audio de muestra.',"
echo "      language='Spanish'"
echo "  )"
echo "  sf.write('/workspace/qwen_voice_clone_test.wav', wavs[0], sr)"
echo "  PY"
echo
echo "[qwen-voice] Logs: $LOG_FILE"
