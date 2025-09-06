#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# Packages are installed after nodes so we can fix them...

APT_PACKAGES=(
    #"package-1"
    #"package-2"
)

PIP_PACKAGES=(
    gdown
    #"package-1"
    #"package-2"
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager.git"
    "https://github.com/cubiq/ComfyUI_essentials.git"
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git"
    "https://github.com/1038lab/ComfyUI-RMBG.git"
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
    "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git"
    "https://github.com/skfoo/ComfyUI-Coziness.git"
    "https://github.com/WASasquatch/was-node-suite-comfyui.git"
    "https://github.com/kk8bit/kaytool.git"
    "https://github.com/Gourieff/ComfyUI-ReActor.git"
)
CHECKPOINTS_GDRIVE=(
    #"https://drive.google.com/file/d/1-AHN-BJaI2jGGQV0zQ6OpVRku12a3Z69/view" #V1
    "https://drive.google.com/file/d/1S1cjUo7XBaZYrXeGHjTRcMca8kni6Wb8/view" #V3
)

WORKFLOWS=(
)

WORKFLOWS_GDRIVE=(
    "https://drive.google.com/file/d/1nQ5vQcRwbuNjR3JiI4cqD5uZqHKLSvcV/view"
    
)

CLIP_MODELS=(
)

UNET_MODELS=(
)

VAE_MODELS=(
)

CLIP_VISION=(
    "https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/model.safetensors"
)

IPADAPTERS=(
)

LORA_MODELS_GDRIVE=(
    "https://drive.google.com/file/d/1uMQpuRw-Oxe_hPNcWYuKNLWM4Yv_N9_i/view"
)

LORA_MODELS=(
    "https://huggingface.co/GritTin/LoraStableDiffusion/resolve/main/Body%20Type_alpha1.0_rank4_noxattn_last.safetensors"
)
ULTRALYTICS=(
    "https://huggingface.co/Ultralytics/YOLOv8/resolve/8a9e1a55f987a77f9966c2ac3f80aa8aa37b3c1a/yolov8m.pt"
)

function provisioning_get_drive_files() {
  local target_dir="$1"; shift
  mkdir -p "$target_dir"
  for url in "$@"; do
    if [[ ! -f "${target_dir}" ]]; then
      echo "Descargando: $url -> ${target_dir}/"
      gdown --fuzzy "$url" -O "${target_dir}/"
    else
      echo "Ya existe el archivo en: ${target_dir}/ (omitiendo descarga)"
    fi
  done
}


### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    workflows_dir="${COMFYUI_DIR}/user/default/workflows"
    mkdir -p "${workflows_dir}"
    provisioning_get_files \
        "${workflows_dir}" \
        "${WORKFLOWS[@]}"
    provisioning_get_drive_files \
        "${workflows_dir}" \
        "${WORKFLOWS_GDRIVE[@]}"        
    provisioning_get_files \
        "${COMFYUI_DIR}/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/clip" \
        "${CLIP_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/clip_vision" \
        "${CLIP_VISION[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/xlabs/ipadapters" \
        "${IPADAPTERS[@]}"
    provisioning_get_drive_files \
        "${COMFYUI_DIR}/models/checkpoints" \
        "${CHECKPOINTS_GDRIVE[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/loras" \
        "${LORA_MODELS[@]}"
    provisioning_get_drive_files \
        "${COMFYUI_DIR}/models/loras" \
        "${LORA_MODELS_GDRIVE[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/ultralytics/bbox" \
        "${ULTRALYTICS[@]}"
    
        
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

    # Check if the token is valid
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

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

# Download from $1 URL to $2 file path
function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif 
        [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]];then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

# Allow user to disable provisioning if they started with a script they didn't want
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi