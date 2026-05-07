#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Qwen3-TTS + Coqui FreeVC24 Vast.ai Provisioning Script
# - Keeps Qwen and Coqui in separate virtualenvs
# - Fails hard if Qwen is unusable
# - Optionally fails or degrades clearly if Coqui/FreeVC24 is unusable
# ------------------------------------------------------------------------------

echo "[qwen-voice] Provisioning start: $(date -Is)"

if [ -f "/.noprovisioning" ]; then
  echo "[qwen-voice] /.noprovisioning present -> skipping provisioning."
  exit 0
fi

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
FREEVC_MODEL_NAME="${FREEVC_MODEL_NAME:-voice_conversion_models/multilingual/vctk/freevc24}"
TORCH_INDEX_URL="${TORCH_INDEX_URL:-https://download.pytorch.org/whl/cu121}"
COQUI_VENV="${COQUI_VENV:-/venv/coqui_freevc}"
COQUI_REQUIRED_FOR_QWEN_FREEVC_REMOTE="${COQUI_REQUIRED_FOR_QWEN_FREEVC_REMOTE:-1}"
QWEN_MAIN_PYTHON="/venv/main/bin/python"
QWEN_MAIN_PIP="/venv/main/bin/pip"
COQUI_PYTHON="${COQUI_VENV}/bin/python"
COQUI_PIP="${COQUI_VENV}/bin/pip"

fail_qwen() {
  echo "[qwen-voice] qwen_runtime_error: $1"
  exit 1
}

fail_coqui() {
  echo "[qwen-voice] coqui_runtime_error: $1"
  if [ "$COQUI_REQUIRED_FOR_QWEN_FREEVC_REMOTE" = "1" ]; then
    echo "[qwen-voice] coqui_runtime_required=yes -> failing provisioning"
    exit 1
  fi
  echo "[qwen-voice] coqui_runtime_required=no -> disabling Coqui capability and continuing"
  export COQUI_REMOTE_ENABLE=0
  COQUI_REMOTE_ENABLE_STATE=0
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[qwen-voice] missing command: $1"
    exit 1
  fi
}

echo "[qwen-voice] system_runtime_start"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
  git \
  ffmpeg \
  sox \
  espeak-ng \
  libsndfile1 \
  libsndfile1-dev \
  ca-certificates \
  curl \
  build-essential \
  python3-venv
echo "[qwen-voice] system_runtime_ok"

if [ ! -f "$QWEN_MAIN_PYTHON" ]; then
  fail_qwen "missing $QWEN_MAIN_PYTHON"
fi

# shellcheck disable=SC1091
source /venv/main/bin/activate
echo "[qwen-voice] qwen_runtime_venv=/venv/main"
python -V || true
python -m pip -V || true

echo "[qwen-voice] qwen_runtime_pip_toolchain_start"
"$QWEN_MAIN_PIP" install --upgrade "pip<27" "setuptools>=70,<82" "wheel<0.48"
echo "[qwen-voice] qwen_runtime_pip_toolchain_ok"

echo "[qwen-voice] qwen_runtime_torch_start"
"$QWEN_MAIN_PIP" uninstall -y torch torchvision torchaudio || true
"$QWEN_MAIN_PIP" install --index-url "$TORCH_INDEX_URL" torch torchvision torchaudio
echo "[qwen-voice] qwen_runtime_torch_ok"

echo "[qwen-voice] qwen_runtime_cuda_check_start"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi || true
else
  echo "[qwen-voice] WARNING: nvidia-smi not available"
fi

"$QWEN_MAIN_PYTHON" - <<'PY' || exit 1
import sys
try:
    import torch
    print('qwen_runtime_torch_version:', torch.__version__)
    print('qwen_runtime_torch_cuda_version:', torch.version.cuda)
    print('qwen_runtime_cuda_available:', torch.cuda.is_available())
    if not torch.cuda.is_available():
        raise RuntimeError('CUDA is required for Qwen runtime, but torch.cuda.is_available() is false.')
except Exception as exc:
    print('qwen_runtime_cuda_check_failed:', exc)
    sys.exit(1)
PY

echo "[qwen-voice] qwen_runtime_disable_tf_start"
export TRANSFORMERS_NO_TF=1
export USE_TF=0
"$QWEN_MAIN_PIP" uninstall -y \
  tensorflow \
  tensorflow-cpu \
  tensorflow-gpu \
  tensorflow-intel \
  tensorflow-io-gcs-filesystem || true
echo "[qwen-voice] qwen_runtime_disable_tf_ok"

echo "[qwen-voice] qwen_runtime_packages_start"
"$QWEN_MAIN_PIP" install -U \
  "qwen-tts==0.1.1" \
  "transformers==4.57.3" \
  "accelerate==1.12.0" \
  soundfile \
  ninja \
  packaging
echo "[qwen-voice] qwen_runtime_packages_ok"

echo "[qwen-voice] qwen_runtime_import_smoke_start"
"$QWEN_MAIN_PYTHON" - <<'PY' || exit 1
import soundfile as sf
print('qwen_runtime_soundfile:', sf.__version__)
from qwen_tts import Qwen3TTSModel
print('qwen_runtime_import_ok:', Qwen3TTSModel.__name__)
PY

echo "[qwen-voice] qwen_runtime_flash_attn_optional_start"
"$QWEN_MAIN_PIP" install -U flash-attn --no-build-isolation || echo "[qwen-voice] WARN: flash-attn install failed, using sdpa"
echo "[qwen-voice] qwen_runtime_flash_attn_optional_done"

echo "[qwen-voice] qwen_runtime_hf_cli_start"
"$QWEN_MAIN_PIP" uninstall -y hf-xet || true
"$QWEN_MAIN_PIP" install -U "huggingface_hub[cli]>=0.26.0,<1.0"
require_cmd hf
hf --version || true
echo "[qwen-voice] qwen_runtime_hf_cli_ok"

export HF_HOME="${WORKSPACE}/hf"
export TRANSFORMERS_CACHE="${WORKSPACE}/hf"
export HUGGINGFACE_HUB_CACHE="${WORKSPACE}/hf"
mkdir -p "$HF_HOME"
echo "[qwen-voice] qwen_runtime_hf_home=$HF_HOME"

if [ -n "${HF_TOKEN:-}" ]; then
  echo "[qwen-voice] qwen_runtime_hf_login_start"
  hf auth login --token "$HF_TOKEN" --add-to-git-credential
  echo "[qwen-voice] qwen_runtime_hf_login_ok"
else
  echo "[qwen-voice] qwen_runtime_hf_login_skipped"
fi

echo "[qwen-voice] qwen_runtime_hf_warm_start"
hf download "$QWEN_TOKENIZER_REPO" --cache-dir "$HF_HOME"
hf download "$QWEN_BASE_REPO" --cache-dir "$HF_HOME"
hf download "$QWEN_CUSTOM_REPO" --cache-dir "$HF_HOME"
hf download "$QWEN_VOICE_DESIGN_REPO" --cache-dir "$HF_HOME"
echo "[qwen-voice] qwen_runtime_hf_warm_ok"

echo "[qwen-voice] qwen_runtime_model_smoke_start"
"$QWEN_MAIN_PYTHON" - <<'PY' || exit 1
import torch
from qwen_tts import Qwen3TTSModel

print('qwen_runtime_gpu_name:', torch.cuda.get_device_name(0))
model = Qwen3TTSModel.from_pretrained(
    'Qwen/Qwen3-TTS-12Hz-1.7B-Base',
    device_map='cuda:0',
    dtype=torch.bfloat16,
    attn_implementation='sdpa',
)
print('qwen_runtime_model_load_smoke: ok', type(model).__name__)
PY

echo "[qwen-voice] qwen_runtime_ready"

COQUI_REMOTE_ENABLE_STATE=1
echo "[qwen-voice] coqui_runtime_venv_start path=$COQUI_VENV"
python3 -m venv "$COQUI_VENV" || fail_coqui "could not create $COQUI_VENV"

if [ ! -f "$COQUI_PYTHON" ]; then
  fail_coqui "missing $COQUI_PYTHON after venv creation"
fi

"$COQUI_PIP" install --upgrade "pip<27" "setuptools>=70,<82" "wheel<0.48" || fail_coqui "failed upgrading coqui pip toolchain"

echo "[qwen-voice] coqui_runtime_packages_start"
"$COQUI_PIP" install -U \
  --index-url "$TORCH_INDEX_URL" \
  torch torchvision torchaudio || fail_coqui "failed installing torch in coqui venv"
"$COQUI_PIP" install -U \
  "TTS>=0.22,<0.23" \
  soundfile || fail_coqui "failed installing Coqui TTS packages"
echo "[qwen-voice] coqui_runtime_packages_ok"

echo "[qwen-voice] coqui_runtime_import_smoke_start"
"$COQUI_PYTHON" - <<'PY' || fail_coqui "Coqui import smoke failed"
import torch
print('coqui_runtime_torch_version:', torch.__version__)
print('coqui_runtime_torch_cuda_version:', torch.version.cuda)
print('coqui_runtime_cuda_available:', torch.cuda.is_available())
if not torch.cuda.is_available():
    raise RuntimeError('CUDA is required for FreeVC runtime, but torch.cuda.is_available() is false.')
from TTS.api import TTS
print('coqui_runtime_import_ok:', TTS.__name__)
PY

echo "[qwen-voice] freevc_load_smoke_start"
"$COQUI_PYTHON" - <<'PY' || fail_coqui "FreeVC load smoke failed"
from TTS.api import TTS
model_name = 'voice_conversion_models/multilingual/vctk/freevc24'
vc = TTS(model_name=model_name, progress_bar=False, gpu=True)
print('freevc_load_smoke: ok', type(vc).__name__)
PY

echo "[qwen-voice] freevc_conversion_smoke_start"
export SOURCE_WAV="${WORKSPACE}/freevc_source.wav"
export TARGET_WAV="${WORKSPACE}/freevc_target.wav"
export OUT_WAV="${WORKSPACE}/freevc_out.wav"
espeak-ng -w "$SOURCE_WAV" "This is the emotional source sample for FreeVC conversion."
espeak-ng -w "$TARGET_WAV" "This is the target voice sample for FreeVC conversion."
"$COQUI_PYTHON" - <<'PY' || fail_coqui "FreeVC conversion smoke failed"
import os
from pathlib import Path
from TTS.api import TTS

source = os.environ['SOURCE_WAV']
target = os.environ['TARGET_WAV']
out = os.environ['OUT_WAV']
vc = TTS(model_name='voice_conversion_models/multilingual/vctk/freevc24', progress_bar=False, gpu=True)
vc.voice_conversion_to_file(source_wav=source, target_wav=target, file_path=out)
out_path = Path(out)
if not out_path.exists() or out_path.stat().st_size <= 0:
    raise RuntimeError('FreeVC conversion did not produce a valid output file.')
print('freevc_conversion_smoke: ok', out)
PY

echo "[qwen-voice] coqui_runtime_ready"

cat >/etc/profile.d/qwen_remote.sh <<EOF
export HF_HOME=/workspace/hf
export TRANSFORMERS_CACHE=/workspace/hf
export HUGGINGFACE_HUB_CACHE=/workspace/hf
export TRANSFORMERS_NO_TF=1
export USE_TF=0
export QWEN_REMOTE_PYTHON=${QWEN_MAIN_PYTHON}
export QWEN_REMOTE_DEVICE=cuda
export QWEN_REMOTE_DTYPE=bfloat16
export QWEN_REMOTE_ATTN_IMPLEMENTATION=sdpa
export QWEN_REMOTE_MODEL_DIR_BASE=Qwen/Qwen3-TTS-12Hz-1.7B-Base
export QWEN_REMOTE_MODEL_DIR_CUSTOM_VOICE=Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice
export QWEN_REMOTE_MODEL_DIR_VOICE_DESIGN=Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign
export COQUI_REMOTE_ENABLE=${COQUI_REMOTE_ENABLE_STATE}
export COQUI_REMOTE_PYTHON=${COQUI_PYTHON}
export FREEVC_MODEL_NAME=${FREEVC_MODEL_NAME}
EOF
chmod 644 /etc/profile.d/qwen_remote.sh
echo "[qwen-voice] runtime_env_persisted=/etc/profile.d/qwen_remote.sh"

touch "${WORKSPACE}/logs/qwen_voice_ready.ok"
echo "[qwen-voice] Ready marker written to ${WORKSPACE}/logs/qwen_voice_ready.ok"

echo
echo "[qwen-voice] Provisioning complete: $(date -Is)"
echo "[qwen-voice] qwen_runtime_python=${QWEN_MAIN_PYTHON}"
echo "[qwen-voice] coqui_runtime_python=${COQUI_PYTHON}"
echo "[qwen-voice] coqui_remote_enable=${COQUI_REMOTE_ENABLE_STATE}"
echo "[qwen-voice] logs=${LOG_FILE}"
