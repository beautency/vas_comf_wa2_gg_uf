#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Qwen3-TTS Vast.ai Provisioning Script
# - Based on higsg.sh structure
# - Installs Qwen TTS runtime and required Python packages
# - Downloads only the Qwen3 TTS Base model by default for voice cloning
# - VoiceDesign / CustomVoice can be re-enabled later if needed
# - Validates CUDA/PyTorch compatibility and optionally installs flash-attn
# - Assumes host NVIDIA driver must match installed PyTorch CUDA build
# - No need for wan2gp, TTS server on :8080, or Jupyter for this integration
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

echo "[qwen-voice] Checking NVIDIA / PyTorch compatibility"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi || true
else
  echo "[qwen-voice] WARNING: nvidia-smi not available"
fi

python - <<'PY'
import sys
try:
    import torch
    print('torch:', torch.__version__)
    print('torch.version.cuda:', torch.version.cuda)
    print('cuda_available:', torch.cuda.is_available())
except Exception as exc:
    print('torch check failed:', exc)
    sys.exit(0)
PY

# ------------------------------------------------------------------------------
# 2) System dependencies
# ------------------------------------------------------------------------------
echo "[qwen-voice] Installing system deps"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
  git \
  ffmpeg \
  sox \
  libsndfile1 \
  libsndfile1-dev \
  ca-certificates \
  curl \
  build-essential

# ------------------------------------------------------------------------------
# 3) Python deps
# ------------------------------------------------------------------------------
echo "[qwen-voice] Upgrading pip toolchain safely"
python -m pip install --upgrade "pip<27" "setuptools>=70,<82" "wheel<0.48"

echo "[qwen-voice] Installing Qwen TTS runtime and support packages"
python -m pip install -U qwen-tts soundfile transformers accelerate ninja packaging

echo "[qwen-voice] Note: torch is expected to already be installed in /venv/main with a host-compatible CUDA build."
echo "[qwen-voice] If CUDA is unavailable, update the NVIDIA driver or reinstall PyTorch with a compatible CUDA version."

echo "[qwen-voice] Installing flash-attn (GPU accelerator for faster inference)"
python -m pip install -U flash-attn --no-build-isolation || echo "[qwen-voice] WARN: flash-attn install failed, continuing with sdpa/eager"

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

cat >/etc/profile.d/qwen_remote.sh <<'EOF'
export HF_HOME=/workspace/hf
export TRANSFORMERS_CACHE=/workspace/hf
export HUGGINGFACE_HUB_CACHE=/workspace/hf
export TRANSFORMERS_NO_TF=1
export USE_TF=0
export QWEN_REMOTE_DEVICE=cuda
export QWEN_REMOTE_DTYPE=float16
export QWEN_REMOTE_MODEL_DIR_BASE=/workspace/models/Qwen3-TTS-12Hz-1.7B-Base
export QWEN_REMOTE_MODEL_DIR_CUSTOM_VOICE=/workspace/models/Qwen3-TTS-12Hz-1.7B-CustomVoice
export QWEN_REMOTE_MODEL_DIR_VOICE_DESIGN=/workspace/models/Qwen3-TTS-12Hz-1.7B-VoiceDesign
EOF
chmod 644 /etc/profile.d/qwen_remote.sh
echo "[qwen-voice] Persisted Qwen runtime env to /etc/profile.d/qwen_remote.sh"

if [ -n "${HF_TOKEN:-}" ]; then
  echo "[qwen-voice] Logging into Hugging Face"
  hf auth login --token "$HF_TOKEN" --add-to-git-credential
else
  echo "[qwen-voice] No HF_TOKEN provided (anonymous)"
fi

# ------------------------------------------------------------------------------
# 5) Download models (idempotent)
# ------------------------------------------------------------------------------
# VOICE_DESIGN_MODEL_ID="Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"
# CUSTOM_VOICE_MODEL_ID="Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice"
VOICE_CLONE_MODEL_ID="Qwen/Qwen3-TTS-12Hz-1.7B-Base"
MODELS_DIR="${WORKSPACE}/models"
# VOICE_DESIGN_MODEL_DIR="${MODELS_DIR}/Qwen3-TTS-12Hz-1.7B-VoiceDesign"
# CUSTOM_VOICE_MODEL_DIR="${MODELS_DIR}/Qwen3-TTS-12Hz-1.7B-CustomVoice"
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

# Clone-only provisioning by default:
# download_if_missing "$VOICE_DESIGN_MODEL_ID" "$VOICE_DESIGN_MODEL_DIR" "${VOICE_DESIGN_MODEL_DIR}/.download_ok"
# download_if_missing "$CUSTOM_VOICE_MODEL_ID" "$CUSTOM_VOICE_MODEL_DIR" "${CUSTOM_VOICE_MODEL_DIR}/.download_ok"
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
print("voice_clone_model:", "Qwen/Qwen3-TTS-12Hz-1.7B-Base")
print("smoke_test: ok")
PY

if [ -f "/workspace/reference_voice.wav" ]; then
  echo "[qwen-voice] Running real VoiceClone audio smoke test"
  python - <<'PY'
import os
import torch
import soundfile as sf
from qwen_tts import Qwen3TTSModel

device = "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.float16 if device == "cuda" else torch.float32
attn = "sdpa" if device == "cuda" else "eager"
model = Qwen3TTSModel.from_pretrained(
    "/workspace/models/Qwen3-TTS-12Hz-1.7B-Base",
    device_map=device,
    dtype=dtype,
    attn_implementation=attn,
)
wavs, sr = model.generate_voice_clone(
    text="Hola, esta es una prueba de clonacion de voz con Qwen TTS.",
    ref_audio="/workspace/reference_voice.wav",
    ref_text="Texto de referencia que corresponde al audio de muestra.",
    language="Spanish",
    non_streaming_mode=True,
)
out_path = "/workspace/qwen_voice_clone_test.wav"
sf.write(out_path, wavs[0], sr)
print("voice_clone_smoke:", out_path, os.path.getsize(out_path))
PY
else
  echo "[qwen-voice] VoiceClone smoke test skipped: /workspace/reference_voice.wav not found"
fi

touch "${WORKSPACE}/logs/qwen_voice_ready.ok"
echo "[qwen-voice] Ready marker written to ${WORKSPACE}/logs/qwen_voice_ready.ok"

# ------------------------------------------------------------------------------
# 7) Final instructions
# ------------------------------------------------------------------------------
echo
echo "[qwen-voice] Provisioning complete: $(date -Is)"
echo
echo "[qwen-voice] Recommended validation:"
echo "  nvidia-smi"
echo "  python -c \"import torch; print(torch.__version__, torch.version.cuda, torch.cuda.is_available())\""
echo "[qwen-voice] If cuda_available is False, update the host NVIDIA driver or reinstall a PyTorch build compatible with the current driver."
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
echo "      dtype=torch.float16,"
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
