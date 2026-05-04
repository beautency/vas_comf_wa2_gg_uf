#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE:-$PWD}/ComfyUI

APT_PACKAGES=(
    #"package-1"
    #"package-2"
)

PIP_PACKAGES=(
    #"package-1"
    #"package-2"
)

NODES=(
    "https://github.com/city96/ComfyUI-GGUF"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/Smirnov75/ComfyUI-mxToolkit"
    "https://github.com/chrisgoringe/cg-use-everywhere"
    "https://github.com/jamesWalker55/comfyui-various"
    "https://github.com/evanspearman/ComfyMath"
    "https://github.com/Lightricks/ComfyUI-LTXVideo"
    "https://github.com/alexopus/ComfyUI-Image-Saver"
    "https://github.com/tritant/ComfyUI_Custom_Switch"
)

WORKFLOWS=(
)

INPUT=(
)

CHECKPOINT_MODELS=(
)

CLIP_MODELS=(
    "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors"
    "https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/text_encoders/ltx-2.3_text_projection_bf16.safetensors"
)

UNET_MODELS=(
)

LORA_MODELS=(
)

VAE_MODELS=(
    "https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_audio_vae_bf16.safetensors"
    "https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_video_vae_bf16.safetensors"
    "https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/taeltx2_3.safetensors"
)

VAE_RENAMED=(
)

ESRGAN_MODELS=(
)

CONTROLNET_MODELS=(
)

DIFFUSION_MODELS=(
    "https://huggingface.co/vantagewithai/LTX-2.3-GGUF/resolve/main/dev/ltx-2-3-22b-dev-Q4_K_M.gguf"
)

CLIP_VISION=(
)

CLIP_VISION_RENAMED=(
)

UPSCALE_MODEL=(
)

LTX_AV_CHECKPOINT_URL="${LTX_AV_CHECKPOINT_URL:-https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-av-step-1751000_vocoder_24K.safetensors}"

CUSTOM_MODELS=(
    "${LTX_AV_CHECKPOINT_URL}::${COMFYUI_DIR}/models/checkpoints/ltx-av-step-1751000_vocoder_24K.safetensors"
    "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma-3-12b-it-qat-q4_0-unquantized_readout_proj/model/model.safetensors::${COMFYUI_DIR}/models/clip/gemma-3-12b-it-qat-q4_0-unquantized_readout_proj/model/model.safetensors"
    "https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-spatial-upscaler-x2-1.1.safetensors::${COMFYUI_DIR}/models/latent_upscale_models/ltx-2.3-spatial-upscaler-x2-1.1.safetensors"
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-spatial-upscaler-x2-1.0.safetensors::${COMFYUI_DIR}/models/latent_upscale_models/ltx-2-spatial-upscaler-x2-1.0.safetensors"
    "https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/loras/ltx-2.3-22b-distilled-lora-dynamic_fro09_avg_rank_105_bf16.safetensors::${COMFYUI_DIR}/models/lora/90 video/ltx-2.3-22b-distilled-lora-dynamic_fro09_avg_rank_105_bf16.safetensors"
    "https://huggingface.co/Lightricks/LTX-2-19b-IC-LoRA-Detailer/resolve/main/ltx-2-19b-ic-lora-detailer.safetensors::${COMFYUI_DIR}/models/lora/90 video/ltx-2-19b-ic-lora-detailer.safetensors"
)

LOCAL_WORKFLOW_SOURCE="${COMFYUI_DIR%/ComfyUI}/vastai_comfyui_wan2.1/comfyui/workflows/ltx23AllInOneWorkflowForRTX_v43.json"
LOCAL_WORKFLOW_TARGET="${COMFYUI_DIR}/user/default/workflows/ltx23AllInOneWorkflowForRTX_v43.json"

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_update_comfyui
    provisioning_get_nodes
    provisioning_get_pip_packages
    workflows_dir="${COMFYUI_DIR}/user/default/workflows"
    mkdir -p "${workflows_dir}"
    provisioning_get_local_workflow
    provisioning_get_files \
        "${workflows_dir}" \
        "${WORKFLOWS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/input" \
        "${INPUT[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/checkpoints" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/lora" \
        "${LORA_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/clip" \
        "${CLIP_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}"
    if [[ ${#VAE_RENAMED[@]} -gt 0 ]]; then
        provisioning_copy_renamed_files \
            "${COMFYUI_DIR}/models/vae" \
            "${VAE_RENAMED[@]}"
    fi
    provisioning_get_files \
        "${COMFYUI_DIR}/models/esrgan" \
        "${ESRGAN_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/diffusion_models" \
        "${DIFFUSION_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/clip_vision" \
        "${CLIP_VISION[@]}"
    if [[ ${#CLIP_VISION_RENAMED[@]} -gt 0 ]]; then
        provisioning_copy_renamed_files \
            "${COMFYUI_DIR}/models/clip_vision" \
            "${CLIP_VISION_RENAMED[@]}"
    fi
    provisioning_get_files \
        "${COMFYUI_DIR}/models/upscale_models" \
        "${UPSCALE_MODEL[@]}"
    provisioning_get_custom_models
    provisioning_print_end
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
            sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
            pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
}

provisioning_update_comfyui() {
    required_tag="v0.3.75"
    cd ${COMFYUI_DIR}
    git fetch --all --tags
    current_commit=$(git rev-parse HEAD)
    required_commit=$(git rev-parse "$required_tag")
    if git merge-base --is-ancestor "$current_commit" "$required_commit"; then
        git checkout "$required_tag"
        pip install --no-cache-dir -r requirements.txt
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                   pip install --no-cache-dir -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip install --no-cache-dir -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_local_workflow() {
    if [[ -f "$LOCAL_WORKFLOW_TARGET" ]]; then
        printf "Workflow already exists: %s\n" "$LOCAL_WORKFLOW_TARGET"
        return
    fi
    if [[ -f "$LOCAL_WORKFLOW_SOURCE" ]]; then
        printf "Copying workflow: %s\n" "$LOCAL_WORKFLOW_SOURCE"
        mkdir -p "$(dirname "$LOCAL_WORKFLOW_TARGET")"
        cp "$LOCAL_WORKFLOW_SOURCE" "$LOCAL_WORKFLOW_TARGET"
    else
        printf "Local workflow source not found: %s\n" "$LOCAL_WORKFLOW_SOURCE"
    fi
}

function provisioning_get_files() {
    if [[ -z $2 ]]; then return 1; fi

    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_get_custom_models() {
    if [[ ${#CUSTOM_MODELS[@]} -eq 0 ]]; then
        return
    fi
    printf "Downloading %s custom model(s)...\n" "${#CUSTOM_MODELS[@]}"
    for entry in "${CUSTOM_MODELS[@]}"; do
        url="${entry%%::*}"
        target="${entry#*::}"
        if [[ -z "$url" || -z "$target" || "$url" == "$target" ]]; then
            continue
        fi
        if [[ -f "$target" ]]; then
            printf "Skipping (already exists): %s\n" "$target"
            continue
        fi
        mkdir -p "$(dirname "$target")"
        provisioning_download_as "$url" "$target"
        printf "\n"
    done
}

function provisioning_copy_renamed_files() {
    local base_dir="$1"
    shift
    if [[ $# -eq 0 ]]; then
        return
    fi
    for entry in "$@"; do
        IFS='|' read -r src dest <<< "$entry"
        if [[ -z "$src" || -z "$dest" ]]; then
            continue
        fi
        local src_path="${base_dir}/${src}"
        local dest_path="${base_dir}/${dest}"
        if [[ -f "$src_path" ]]; then
            mkdir -p "$(dirname "$dest_path")"
            if [[ ! -f "$dest_path" ]]; then
                cp "$src_path" "$dest_path"
            fi
        else
            printf "Warning: source not found for rename: %s\n" "$src_path"
        fi
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Application will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")

    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")

    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

function provisioning_download_as() {
    local url="$1"
    local target="$2"
    local auth_header=()
    if [[ -n $HF_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_header=(--header "Authorization: Bearer $HF_TOKEN")
    elif [[ -n $CIVITAI_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_header=(--header "Authorization: Bearer $CIVITAI_TOKEN")
    fi
    if [[ -f "$target" ]]; then
        return
    fi
    wget -q --show-progress -e dotbytes=4M "${auth_header[@]}" -O "$target" "$url"
}

if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi
