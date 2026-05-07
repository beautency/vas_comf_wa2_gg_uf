#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Qwen3-TTS Vast.ai Provisioning Script
# - GPU-only provisioning for Qwen3-TTS remote generation
# - Pins runtime versions known to work together
# - Uses Hugging Face repo IDs as runtime model refs
# - Fails fast during provisioning if CUDA/PyTorch/model load is not usable
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

QWEN_BASE_REPO="Qwen/Qwen3-TTS-12Hz-1.7B-Base"
QWEN_CUSTOM_REPO="Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice"
QWEN_VOICE_DESIGN_REPO="Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"
QWEN_TOKENIZER_REPO="Qwen/Qwen3-TTS-Tokenizer-12Hz"

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
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA is required for this GPU-only Qwen node, but torch.cuda.is_available() is false.")
except Exception as exc:
    print('torch check failed:', exc)
    sys.exit(1)
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

echo "[qwen-voice] Disabling TensorFlow for Transformers"
export TRANSFORMERS_NO_TF=1
export USE_TF=0
python -m pip uninstall -y \
  tensorflow \
  tensorflow-cpu \
  tensorflow-gpu \
  tensorflow-intel \
  tensorflow-io-gcs-filesystem || true

echo "[qwen-voice] Installing pinned Qwen TTS runtime packages"
python -m pip install -U \
  "qwen-tts==0.1.1" \
  "transformers==4.57.3" \
  "accelerate==1.12.0" \
  soundfile \
  ninja \
  packaging

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
export QWEN_REMOTE_DTYPE=bfloat16
export QWEN_REMOTE_ATTN_IMPLEMENTATION=flash_attention_2
export QWEN_REMOTE_MODEL_DIR_BASE=Qwen/Qwen3-TTS-12Hz-1.7B-Base
export QWEN_REMOTE_MODEL_DIR_CUSTOM_VOICE=Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice
export QWEN_REMOTE_MODEL_DIR_VOICE_DESIGN=Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign
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
echo "[qwen-voice] Warming Hugging Face cache for Qwen3-TTS models"
hf download "$QWEN_TOKENIZER_REPO" --cache-dir "$HF_HOME"
hf download "$QWEN_BASE_REPO" --cache-dir "$HF_HOME"
hf download "$QWEN_CUSTOM_REPO" --cache-dir "$HF_HOME"
hf download "$QWEN_VOICE_DESIGN_REPO" --cache-dir "$HF_HOME"

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
else:
    raise RuntimeError("CUDA is required for qwen_voice.sh smoke test.")

import soundfile as sf
print("soundfile import: ok", sf.__version__)

from qwen_tts import Qwen3TTSModel
print("qwen_tts import: ok")
print("voice_clone_model:", "Qwen/Qwen3-TTS-12Hz-1.7B-Base")
print("smoke_test: ok")
PY

echo "[qwen-voice] Running GPU model-load smoke test"
python - <<'PY'
import torch
from qwen_tts import Qwen3TTSModel

model = Qwen3TTSModel.from_pretrained(
    "Qwen/Qwen3-TTS-12Hz-1.7B-Base",
    device_map="cuda:0",
    dtype=torch.bfloat16,
    attn_implementation="flash_attention_2",
)
print("model_load_smoke: ok", type(model).__name__)
PY

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
echo "      'Qwen/Qwen3-TTS-12Hz-1.7B-Base',"
echo "      device_map='cuda:0',"
echo "      dtype=torch.bfloat16,"
echo "      attn_implementation='flash_attention_2',"
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
