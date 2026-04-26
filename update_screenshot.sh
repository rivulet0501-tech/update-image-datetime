#!/usr/bin/env bash
# update_screenshot.sh
#
# 处理截图命名格式的图片，从文件名中提取拍摄时间。
#
# 适用规律：
#   ScreenShot_YYYYMMDD-HHMMSS.png
#   例：ScreenShot_20171015-211119.png  →  2017:10:15 21:11:19
#
# 用法：
#   bash update_screenshot.sh [imagelist.txt]
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

    # 匹配 ScreenShot_YYYYMMDD-HHMMSS.ext
    if [[ "$filename" =~ ^ScreenShot_([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})\. ]]; then
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
