#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# Face Replicator (FLUX) – node + model bootstrap for vast.ai
# Based on flux.sh and FaceReplicator_flux_v1.0.json

# APT/PIP extras if needed (most deps come via node requirements)
APT_PACKAGES=(
    #"package-1"
)

PIP_PACKAGES=(
    #"ultralytics"
    #"insightface"
)

# Custom nodes required by the workflow
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/lldacing/ComfyUI_PuLID_Flux_ll"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/ltdrdata/ComfyUI-Impact-Subpack"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/cubiq/ComfyUI-Image-Saver"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/cubiq/ComfyUI_LayerStyle_Advance"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/crystian/ComfyUI-Crystools"
    "https://github.com/mav-rik/ComfyUI-TeaCache"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
    "https://github.com/1038lab/ComfyUI-RMBG"
)

# Workflows: copy local FaceReplicator workflow into the container user workflows
WORKFLOWS_LOCAL=(
    "${WORKSPACE}/vastai_comfyui_wan2.1/comfyui/workflows/FaceReplicator_flux_v1.0.json"
)

# Core FLUX models
CLIP_MODELS=(
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"
)

UNET_MODELS=(
    # Provide a freely downloadable option by default; licensed ones appended below if HF_TOKEN valid
    "https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors"
)

VAE_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"
    "https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors"
)

CLIP_VISION=(
    "https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/model.safetensors"
)

# PuLID model(s) for FLUX (FaceReplicator uses pulid_flux_v0.9.1.safetensors)
PULID_MODELS=(
    "https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors"
    # You can also include 0.9.0 if desired:
    #"https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.0.safetensors"
)

# Optional LoRA used by the workflow (Ace++ portrait)
LORA_MODELS=(
    "https://huggingface.co/ali-vilab/ACE_Plus/resolve/main/portrait/comfyui_portrait_lora64.safetensors|Ace plus"
)

# Upscale models referenced by the workflow
UPSCALE_MODELS=(
    # Format: url|optional_rename
    "https://huggingface.co/aryan1107/Upscalers/resolve/main/4xUltrasharp_4xUltrasharpV10.pt|4xUltrasharp_4xUltrasharpV10.pt"
    "https://huggingface.co/imaginai/upscale-models/resolve/main/4xRealWebPhoto_v4_dat2.pth|4xRealWebPhoto_v4_dat2.pth"
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages

    # Install workflows
    workflows_dir="${COMFYUI_DIR}/user/default/workflows"
    mkdir -p "${workflows_dir}"
    provisioning_copy_workflows "${workflows_dir}" "${WORKFLOWS_LOCAL[@]}"

    # If user has a valid HF token, prefer licensed FLUX models
    if provisioning_has_valid_hf_token; then
        UNET_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors")
        VAE_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors")
    else
        # Fall back to schnell if no token
        UNET_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors")
        VAE_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors")
    fi

    # Core model downloads
    provisioning_get_files "${COMFYUI_DIR}/models/unet"           "${UNET_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/vae"            "${VAE_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/clip"           "${CLIP_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/clip_vision"    "${CLIP_VISION[@]}"

    # PuLID
    provisioning_get_files "${COMFYUI_DIR}/models/pulid"          "${PULID_MODELS[@]}"

    # LoRA(s)
    provisioning_get_loras  "${COMFYUI_DIR}/models/loras"         "${LORA_MODELS[@]}"

    # Upscale models
    provisioning_get_renamed_files "${COMFYUI_DIR}/models/upscale_models" "${UPSCALE_MODELS[@]}"

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

function provisioning_copy_workflows() {
    local dest="$1"; shift
    mkdir -p "$dest"
    for src in "$@"; do
        if [[ -f "$src" ]]; then
            printf "Installing workflow: %s -> %s\n" "$src" "$dest"
            cp -f "$src" "$dest/"
        fi
    done
}

function provisioning_get_files() {
    if [[ -z $2 ]]; then return 1; fi
    local dir="$1"; shift
    local arr=("$@")
    mkdir -p "$dir"
    printf "Downloading %s file(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

# For inputs defined as "url|new_name"
function provisioning_get_renamed_files() {
    if [[ -z $2 ]]; then return 1; fi
    local dir="$1"; shift
    local arr=("$@")
    mkdir -p "$dir"
    for entry in "${arr[@]}"; do
        local url="${entry%%|*}"
        local name="${entry#*|}"
        local tmp_dir="${dir}/.tmp_download"
        mkdir -p "$tmp_dir"
        printf "Downloading: %s\n" "$url"
        provisioning_download "$url" "$tmp_dir"
        local downloaded
        downloaded=$(find "$tmp_dir" -maxdepth 1 -type f | head -n1)
        if [[ -n "$downloaded" ]]; then
            mv -f "$downloaded" "${dir}/${name}"
            printf "Saved as: %s\n" "${dir}/${name}"
        fi
        rm -rf "$tmp_dir"
        printf "\n"
    done
}

# For LoRAs defined as "url|subdir"
function provisioning_get_loras() {
    if [[ -z $2 ]]; then return 1; fi
    local base="$1"; shift
    local arr=("$@")
    for entry in "${arr[@]}"; do
        local url="${entry%%|*}"
        local subdir="${entry#*|}"
        local dest="${base}/${subdir}"
        mkdir -p "$dest"
        printf "Downloading LoRA: %s -> %s\n" "$url" "$dest"
        provisioning_download "$url" "$dest"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#      Provisioning Face Replicator (FLUX)   #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete: Application will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"
    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")
    [[ "$response" -eq 200 ]]
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"
    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")
    [[ "$response" -eq 200 ]]
}

# Download from $1 URL to $2 file path
function provisioning_download() {
    local url="$1"; local dest="$2"; local chunk="${3:-4M}"
    local auth_token=""
    if [[ -n $HF_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="$chunk" -P "$dest" "$url"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="$chunk" -P "$dest" "$url"
    fi
}

# Allow user to disable provisioning if they started with a script they didn't want
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi

