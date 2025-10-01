#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# WAN Img2Vid – provisioning for WanImg22Vid-v11.json

APT_PACKAGES=(
    #"package-1"
)

PIP_PACKAGES=(
    #"ultralytics"
)

NODES=(
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/city96/ComfyUI-GGUF"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/Smirnov75/ComfyUI-mxToolkit"
    "https://github.com/facok/ComfyUI-HunyuanVideoMultiLora"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
    "https://github.com/WASasquatch/was-node-suite-comfyui"
    "https://github.com/kijai/ComfyUI-Florence2"
    "https://github.com/yuvraj108c/ComfyUI-Upscaler-Tensorrt"
    "https://github.com/pollockjj/ComfyUI-MultiGPU"
)

# Copy local workflow
WORKFLOWS_LOCAL=(
    "${WORKSPACE}/vastai_comfyui_wan2.1/comfyui/workflows/WanImg22Vid-v11.json"
)

# Core WAN 2.1 models
CLIP_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
)

VAE_MODELS=(
    # Base VAE (we will also create a copy with the fp8 filename expected by the workflow)
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
)

# Clip vision: download and save with workflow-expected name under wan2/
CLIP_VISION_RENAMED=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors|wan2/clip_vision_h_fp8_e4m3fn.safetensors"
)

DIFFUSION_MODELS=(
    # Include both 480p and 720p i2v variants (fp8 e4m3fn)
    "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models/diffusion_models/WAN/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors"
    "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models/diffusion_models/WAN/wan2.1_i2v_720p_14B_fp8_e4m3fn.safetensors"
)

# Optional WAN LoRAs referenced by the workflow (add URLs if you have them)
WAN_LORAS_URLS=(
    # Example format (url|save_as_in_wan_subdir):
    # "https://example.com/wan/360-orbit.safetensors|wan/360-orbit.safetensors"
    # "https://example.com/wan/T2V-I2V_h4nd_p4nties_v3.safetensors|wan/T2V-I2V_h4nd_p4nties_v3.safetensors"
)

# Upscalers
UPSCALE_MODELS=(
    # RealESRGAN baseline
    "https://huggingface.co/spaces/Marne/Real-ESRGAN/resolve/main/RealESRGAN_x4plus.pth|RealESRGAN_x4plus.pth"
    # If you have a source URL for 4xNomos2_realplksr_dysample.pt, add it here:
    # "https://example.com/upscalers/4xNomos2_realplksr_dysample.pt|4xNomos2_realplksr_dysample.pt"
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_update_comfyui
    provisioning_get_nodes
    provisioning_get_pip_packages

    # Workflows
    local workflows_dir="${COMFYUI_DIR}/user/default/workflows"
    mkdir -p "${workflows_dir}"
    provisioning_copy_workflows "${workflows_dir}" "${WORKFLOWS_LOCAL[@]}"

    # Models
    provisioning_get_files "${COMFYUI_DIR}/models/clip"            "${CLIP_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/vae"             "${VAE_MODELS[@]}"
    # Create a copy with the exact name used by the workflow
    if [[ -f "${COMFYUI_DIR}/models/vae/wan_2.1_vae.safetensors" ]]; then
        cp -f "${COMFYUI_DIR}/models/vae/wan_2.1_vae.safetensors" \
              "${COMFYUI_DIR}/models/vae/wan_2.1_vae_fp8_e4m3fn.safetensors"
    fi

    provisioning_get_files "${COMFYUI_DIR}/models/diffusion_models" "${DIFFUSION_MODELS[@]}"
    provisioning_get_renamed_files "${COMFYUI_DIR}/models/clip_vision" "${CLIP_VISION_RENAMED[@]}"

    # LoRAs: create folder and optionally download declared items
    mkdir -p "${COMFYUI_DIR}/models/loras/wan"
    provisioning_get_renamed_files "${COMFYUI_DIR}/models/loras" "${WAN_LORAS_URLS[@]}"

    # Upscalers
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

# Ensure FP8 support tag (v0.3.34+) is present
provisioning_update_comfyui() {
    required_tag="v0.3.34"
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

function provisioning_copy_workflows() {
    local dest="$1"; shift
    mkdir -p "$dest"
    for src in "$@"; do
        if [[ -f "$src" ]]; then
            echo "Installing workflow: $src -> $dest/"
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
        provisioning_download "${url}" "$dir"
        printf "\n"
    done
}

# For inputs defined as "url|new_name" (supports subfolders in new_name)
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
            mkdir -p "${dir}/$(dirname "$name")"
            mv -f "$downloaded" "${dir}/${name}"
            printf "Saved as: %s\n" "${dir}/${name}"
        fi
        rm -rf "$tmp_dir"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#         Provisioning WAN Img2Vid           #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
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

# Download from $1 URL to $2 directory
function provisioning_download() {
    local url="$1"; local dest="$2"; local chunk="${3:-4M}"
    local auth_token=""
    if [[ -n $HF_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    mkdir -p "$dest"
    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="$chunk" -P "$dest" "$url"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="$chunk" -P "$dest" "$url"
    fi
}

if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi

