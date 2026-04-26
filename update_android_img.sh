#!/usr/bin/env bash
# update_android_img.sh
#
# 处理 Android 相机标准命名格式的照片，从文件名中提取拍摄时间。
#
# 适用规律：
#   IMG_YYYYMMDD_HHMMSS.jpg / .JPG / .JPEG
#   VIDEO_YYYYMMDD_HHMMSS.jpg
#
# 用法：
#   bash update_android_img.sh [imagelist.txt]
#
# 依赖：exiftool

set -euo pipefail

IMAGELIST="${1:-imagelist.txt}"

if [[ ! -f "$IMAGELIST" ]]; then
    echo "错误：找不到图片列表文件：$IMAGELIST" >&2
    exit 1
fi

if ! command -v exiftool &>/dev/null; then
    echo "错误：未找到 exiftool，请先安装。" >&2
    exit 1
fi

count=0
skip=0

while IFS= read -r line; do
    filepath="${line#*. }"
    [[ -z "$filepath" ]] && continue

    filename="$(basename "$filepath")"

    # 匹配 IMG_YYYYMMDD_HHMMSS 或 VIDEO_YYYYMMDD_HHMMSS
    if [[ "$filename" =~ ^(IMG|VIDEO)_([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})\. ]]; then
        YEAR="${BASH_REMATCH[2]}"
        MON="${BASH_REMATCH[3]}"
        DAY="${BASH_REMATCH[4]}"
        HOUR="${BASH_REMATCH[5]}"
        MIN="${BASH_REMATCH[6]}"
        SEC="${BASH_REMATCH[7]}"
        DATETIME="${YEAR}:${MON}:${DAY} ${HOUR}:${MIN}:${SEC}"
        echo "设置 $filepath  =>  $DATETIME"
        exiftool -overwrite_original -DateTimeOriginal="$DATETIME" "$filepath"
        (( count++ )) || true
    else
        (( skip++ )) || true
    fi
done < <(sed 's/^[0-9]*\. //' "$IMAGELIST")

echo "完成：共更新 $count 个文件，跳过 $skip 个文件（不匹配的格式）。"
