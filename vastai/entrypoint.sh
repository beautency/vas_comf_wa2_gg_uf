#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Qwen3-TTS Vast.ai Entrypoint Script
# - Activates the virtual environment
# - Starts Jupyter Notebook for interactive development
# - Assumes provisioning has already been completed
# ------------------------------------------------------------------------------

echo "[qwen-voice-entrypoint] Starting entrypoint: $(date -Is)"

# Activate virtual environment
if [ -f "/venv/main/bin/activate" ]; then
  # shellcheck disable=SC1091
  source /venv/main/bin/activate
  echo "[qwen-voice-entrypoint] Activated /venv/main"
else
  echo "[qwen-voice-entrypoint] WARNING: /venv/main not found"
fi

# Set workspace
WORKSPACE="${WORKSPACE:-/workspace}"
cd "$WORKSPACE"

# Set Hugging Face cache
export HF_HOME="${WORKSPACE}/hf"
export TRANSFORMERS_CACHE="${WORKSPACE}/hf"
export HUGGINGFACE_HUB_CACHE="${WORKSPACE}/hf"

echo "[qwen-voice-entrypoint] WORKSPACE=$WORKSPACE"
echo "[qwen-voice-entrypoint] HF_HOME=$HF_HOME"

# Start Jupyter Notebook
echo "[qwen-voice-entrypoint] Starting Jupyter Notebook on port 8080"
jupyter notebook --ip=0.0.0.0 --port=8080 --allow-root --no-browser --NotebookApp.token='' --NotebookApp.password=''