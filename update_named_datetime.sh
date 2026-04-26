#!/usr/bin/env bash
# update_named_datetime.sh
#
# 处理文件名中包含完整日期时间字符串的照片（非 MYXJ / IMG_ANDROID / SelfieCity 格式）。
#
# 适用规律（按顺序匹配，取第一个命中的规则）：
#
#   1. beauty_YYYYMMDDHHMMSS.jpg
#      例：beauty_20181027140451.jpg  →  2018:10:27 14:04:51
#
#   2. Cover_YYYYMMDDHHMMSS[ms].jpg
#      例：Cover_20190526160213186.jpg  →  2019:05:26 16:02:13
#
#   3. MEITU_YYYYMMDD_HHMMSS[ms].jpg
#      例：MEITU_20250531_113309902.jpg  →  2025:05:31 11:33:09
#
#   4. april_YYYY-MM-DD-HH-MM-SS-ms.jpg
#      例：april_2019-08-01-22-26-18-236.jpg  →  2019:08:01 22:26:18
#
#   5. YYYY-MM-DD-HH-MM-SS-ms.jpg  （文件名开头就是日期-时间格式）
#      例：2020-03-18-11-52-53-595.jpg  →  2020:03:18 11:52:53
#
#   6. YYYYMMDDHHMMSS.jpg  （纯 14 位数字文件名）
#      例：20190904190251.jpg  →  2019:09:04 19:02:51
#
# 用法：
#   bash update_named_datetime.sh [imagelist.txt]
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
    DATETIME=""

    # 规则 1：beauty_YYYYMMDDHHMMSS.jpg（14位命名日期时间，优先于 unix_timestamp 脚本的 beauty_ 规则）
    if [[ "$filename" =~ ^beauty_([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})\. ]]; then
        DATETIME="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"

    # 规则 2：Cover_YYYYMMDDHHMMSS[ms].jpg
    elif [[ "$filename" =~ ^Cover_([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})[0-9]*\. ]]; then
        DATETIME="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"

    # 规则 3：MEITU_YYYYMMDD_HHMMSS[ms].jpg
    elif [[ "$filename" =~ ^MEITU_([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})[0-9]*\. ]]; then
        DATETIME="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"

    # 规则 4：april_YYYY-MM-DD-HH-MM-SS-ms.jpg
    elif [[ "$filename" =~ ^april_([0-9]{4})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2})- ]]; then
        DATETIME="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"

    # 规则 5：YYYY-MM-DD-HH-MM-SS-ms.jpg（文件名直接以日期开头）
    elif [[ "$filename" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2})- ]]; then
        DATETIME="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"

    # 规则 6：纯 14 位数字文件名 YYYYMMDDHHMMSS.xxx
    elif [[ "$filename" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})\. ]]; then
        DATETIME="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
    fi

    if [[ -n "$DATETIME" ]]; then
        echo "设置 $filepath  =>  $DATETIME"
        exiftool -overwrite_original -DateTimeOriginal="$DATETIME" -FileModifyDate="$DATETIME" "$filepath"
        (( count++ )) || true
    else
        (( skip++ )) || true
    fi
done < <(sed 's/^[0-9]*\. //' "$IMAGELIST")

echo "完成：共更新 $count 个文件，跳过 $skip 个文件（不匹配的格式）。"
