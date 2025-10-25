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
    "https://github.com/gameltb/Comfyui-StableSR.git"
    "https://github.com/fssorc/ComfyUI_FaceShaper.git"
)
CHECKPOINTS=(
    "https://huggingface.co/Iceclear/StableSR/resolve/main/stablesr_768v_000139.ckpt"
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

# Local workflows to copy into ComfyUI
WORKFLOWS_LOCAL=(
    "${WORKSPACE}/vastai_comfyui_wan2.1/comfyui/workflows/RaoxiHendes.json"
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

# CLIP vision models required by IP-Adapter (exact filenames for Unified Loader)
CLIP_VISION_H14=(
    # ViT-H/14 LAION2B
    "https://huggingface.co/laion/CLIP-ViT-H-14-laion2B-s32B-b79K/resolve/main/model.safetensors|CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"
)
CLIP_VISION_BIGG=(
    # ViT-bigG/14 LAION2B
    "https://huggingface.co/laion/CLIP-ViT-bigG-14-laion2B-39B-b160k/resolve/main/model.safetensors|CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
)

IPADAPTERS=(
    "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors"
)

# IP-Adapter SDXL models (exact filenames, placed under models/ipadapter)
IPADAPTERS_SDXL=(
    "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors|ip-adapter-plus_sdxl_vit-h.safetensors"
    "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus-face_sdxl_vit-h.safetensors|ip-adapter-plus-face_sdxl_vit-h.safetensors"
    "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl.safetensors|ip-adapter_sdxl.safetensors"
    "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl_vit-h.safetensors|ip-adapter_sdxl_vit-h.safetensors"
    # FaceID PLUS V2 (SDXL) — keep .bin extension for correct loading
    "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin|faceid.plusv2.sdxl.bin"
)
# Optional image encoder for SDXL IP-Adapter Plus/Face (kept for compatibility)
IPADAPTER_IMAGE_ENCODER=(
    "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors|image_encoder/model.safetensors"
)

LORA_MODELS_GDRIVE=(
    "https://drive.google.com/file/d/1uMQpuRw-Oxe_hPNcWYuKNLWM4Yv_N9_i/view"
    "https://drive.google.com/file/d/1L8dVYCkg1XL_8bm4oNEml8lTxaB-WVSz/view"
)

LORA_MODELS=(
     #"https://huggingface.co/GritTin/LoraStableDiffusion/resolve/main/Body Type_alpha1.0_rank4_noxattn_last.safetensors"
)

# Loras that require exact filenames for auto-detection (Unified Loader)
LORA_MODELS_RENAMED=(
    # FaceID PLUS V2 LoRA (SDXL)
    "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors|faceid.plusv2.sdxl.lora.safetensors"
)
ULTRALYTICS_BBOX=(
    "https://huggingface.co/Ultralytics/YOLOv8/resolve/8a9e1a55f987a77f9966c2ac3f80aa8aa37b3c1a/yolov8m.pt"
    "https://huggingface.co/ashllay/YOLO_Models/resolve/e07b01219ff1807e1885015f439d788b038f49bd/bbox/face_yolov8m.pt"
    "https://huggingface.co/WolfAether21/ADETAILER-STABLE-DIFFUSION-PLUGIN/resolve/main/vagina-v3.0-fantasy.pt"
    "https://huggingface.co/ashllay/YOLO_Models/resolve/e07b01219ff1807e1885015f439d788b038f49bd/bbox/female-breast-v4.0-fantasy.pt"
    "https://huggingface.co/ashllay/YOLO_Models/resolve/e07b01219ff1807e1885015f439d788b038f49bd/bbox/hand_yolov8s.pt"
    "https://huggingface.co/ashllay/YOLO_Models/resolve/e07b01219ff1807e1885015f439d788b038f49bd/bbox/vagina-v3.2.pt"
    "https://huggingface.co/ashllay/YOLO_Models/resolve/e07b01219ff1807e1885015f439d788b038f49bd/bbox/nsfw_watermarks_s_yolov8_v1.pt"
    "https://huggingface.co/ashllay/YOLO_Models/resolve/e07b01219ff1807e1885015f439d788b038f49bd/bbox/watermarks_s_yolov8_v1.pt"
    "https://huggingface.co/ashllay/YOLO_Models/resolve/e07b01219ff1807e1885015f439d788b038f49bd/bbox/penis.pt"
    "https://huggingface.co/ashllay/YOLO_Models/resolve/e07b01219ff1807e1885015f439d788b038f49bd/bbox/full_eyes_detect_v1.pt"
    "https://huggingface.co/ashllay/YOLO_Models/resolve/e07b01219ff1807e1885015f439d788b038f49bd/bbox/Eyes.pt"
    "https://huggingface.co/ashllay/YOLO_Models/resolve/e07b01219ff1807e1885015f439d788b038f49bd/bbox/Eyeful_v2-Paired.pt"
)
ULTRALYTICS_SEGM=(
    "https://huggingface.co/ashllay/YOLO_Models/resolve/e07b01219ff1807e1885015f439d788b038f49bd/segm/Anzhc%20Face%20seg%20768%20v2%20y8n.pt"
    "https://huggingface.co/ashllay/YOLO_Models/resolve/e07b01219ff1807e1885015f439d788b038f49bd/segm/Anzhc%20Breasts%20Seg%20v1%201024m.pt"
)
SAMS=(
    "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/sams/sam_vit_b_01ec64.pth"
)
STABLESR=(
    "https://huggingface.co/Iceclear/StableSR/resolve/main/webui_768v_139.ckpt"
)

# LivePortrait models for FaceShaper (landmark detection)
LIVEPORTRAIT_MODELS=(
    "https://huggingface.co/Kijai/LivePortrait_safetensors/resolve/main/landmark.onnx"
    "https://huggingface.co/Kijai/LivePortrait_safetensors/resolve/main/landmark_model.pth"
)

# ReActor dependencies (for RaoxiHendes workflow)
REACTOR_ONNX=(
    "https://huggingface.co/deepinsight/insightface/resolve/main/models/inswapper_128.onnx"
)
REACTOR_FACE_MODELS=(
    # Place your custom face libraries here (optional), e.g.:
    # "https://example.com/path/to/blend_flo_sheip_dilaca_saramaga_ystrhvsky_robin.safetensors"
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
    # Copy local workflows (if present)
    provisioning_copy_workflows \
        "${workflows_dir}" \
        "${WORKFLOWS_LOCAL[@]}"
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
    # Download OpenAI CLIP-ViT/L-14 vision model
    provisioning_get_files \
        "${COMFYUI_DIR}/models/clip_vision" \
        "${CLIP_VISION[@]}"
    # Download CLIP models with the exact filenames IP-Adapter expects
    provisioning_get_renamed_files \
        "${COMFYUI_DIR}/models/clip_vision" \
        "${CLIP_VISION_H14[@]}"
    provisioning_get_renamed_files \
        "${COMFYUI_DIR}/models/clip_vision" \
        "${CLIP_VISION_BIGG[@]}"
    # IP-Adapter SDXL models and optional image encoder (placed in models/ipadapter)
    provisioning_get_renamed_files \
        "${COMFYUI_DIR}/models/ipadapter" \
        "${IPADAPTERS_SDXL[@]}"
    provisioning_get_renamed_files \
        "${COMFYUI_DIR}/models/ipadapter" \
        "${IPADAPTER_IMAGE_ENCODER[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/checkpoints" \
        "${CHECKPOINTS[@]}"
    provisioning_get_drive_files \
        "${COMFYUI_DIR}/models/checkpoints" \
        "${CHECKPOINTS_GDRIVE[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/loras" \
        "${LORA_MODELS[@]}"
    provisioning_get_drive_files \
        "${COMFYUI_DIR}/models/loras" \
        "${LORA_MODELS_GDRIVE[@]}"
    # Download LoRAs with explicit filenames for loader compatibility
    provisioning_get_renamed_files \
        "${COMFYUI_DIR}/models/loras" \
        "${LORA_MODELS_RENAMED[@]}"
    # Also keep a copy with the upstream filename for reference
    if [[ -f "${COMFYUI_DIR}/models/loras/faceid.plusv2.sdxl.lora.safetensors" ]]; then
        cp -f "${COMFYUI_DIR}/models/loras/faceid.plusv2.sdxl.lora.safetensors" \
              "${COMFYUI_DIR}/models/loras/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"
    fi
    provisioning_get_files \
        "${COMFYUI_DIR}/models/ultralytics/bbox" \
        "${ULTRALYTICS_BBOX[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/ultralytics/seg" \
        "${ULTRALYTICS_SEGM[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/sams" \
        "${SAMS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/stablesr" \
        "${STABLESR[@]}"

    # LivePortrait weights for FaceShaper
    provisioning_get_files \
        "${COMFYUI_DIR}/models/liveportrait" \
        "${LIVEPORTRAIT_MODELS[@]}"

    # ReActor models (inswapper and optional face libraries)
    provisioning_get_files \
        "${COMFYUI_DIR}/models/reactor" \
        "${REACTOR_ONNX[@]}"
    mkdir -p "${COMFYUI_DIR}/models/reactor/faces"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/reactor/faces" \
        "${REACTOR_FACE_MODELS[@]}"

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

function provisioning_get_files_rename_file() {
    if [[ -z $2 ]]; then return 1; fi
    
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"

    while [[ $# -gt 0 ]]; do
        url="$1"
        new_name=""
        shift
        # si hay un segundo argumento y no empieza por "http" (o "gs://", "s3://", etc.), lo tomamos como nombre
        if [[ $# -gt 0 && ! "$1" =~ ^https?:// ]]; then
            new_name="$1"
            shift
        fi
        if [[ -n "$new_name" ]]; then
            printf "Downloading: %s as %s\n" "$url" "$new_name"
            provisioning_download "$url" "$dir/$new_name"
        else
            printf "Downloading: %s\n" "$url"
            provisioning_download "$url" "$dir"
        fi
        printf "\n"
    done
}

# Robust renaming downloader: entries as "url|new_name"
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
            # Ensure destination subdirectories exist when name contains folders
            local dest_path="${dir}/${name}"
            local dest_dir
            dest_dir=$(dirname "$dest_path")
            mkdir -p "$dest_dir"
            mv -f "$downloaded" "$dest_path"
            printf "Saved as: %s\n" "$dest_path"
        fi
        rm -rf "$tmp_dir"
        printf "\n"
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
