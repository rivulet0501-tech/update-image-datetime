#!/usr/bin/env bash
# update_myxj.sh
#
# 处理 MYXJ 美颜相机格式的照片，从文件名中提取拍摄时间。
#
# 适用规律：
#   MYXJ_YYYYMMDDHHMMSS_fast.jpg
#   MYXJ_YYYYMMDDHHMMSS_save.jpg
#   MYXJ_YYYYMMDDHHMMSSmmm_fast.jpg  （新版本文件名，时间戳后附加毫秒）
#
# 用法：
#   bash update_myxj.sh [imagelist.txt]
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
    # 去掉行首的序号（如 "1. "）
    filepath="${line#*. }"
    [[ -z "$filepath" ]] && continue

    filename="$(basename "$filepath")"

    # 匹配 MYXJ_YYYYMMDDHHMMSS[ms]_(fast|save).(jpg|jpeg)（大小写不敏感）
    # 提取前 8 位日期和随后的 6 位时间
    if [[ "$filename" =~ ^MYXJ_([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})[0-9]*_ ]]; then
        YEAR="${BASH_REMATCH[1]}"
        MON="${BASH_REMATCH[2]}"
        DAY="${BASH_REMATCH[3]}"
        HOUR="${BASH_REMATCH[4]}"
        MIN="${BASH_REMATCH[5]}"
        SEC="${BASH_REMATCH[6]}"
        DATETIME="${YEAR}:${MON}:${DAY} ${HOUR}:${MIN}:${SEC}"
        echo "设置 $filepath  =>  $DATETIME"
        exiftool -overwrite_original -DateTimeOriginal="$DATETIME" -FileModifyDate="$DATETIME" "$filepath"
        (( count++ )) || true
    else
        (( skip++ )) || true
    fi
done < <(sed 's/^[0-9]*\. //' "$IMAGELIST")

echo "完成：共更新 $count 个文件，跳过 $skip 个文件（不匹配的格式）。"
