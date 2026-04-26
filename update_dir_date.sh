#!/usr/bin/env bash
# update_dir_date.sh
#
# 对文件名中无法提取日期时间信息的照片，根据父目录名来设置 DateTimeOriginal。
# 本脚本仅处理文件名不匹配以下已知前缀的文件：
#   MYXJ_、IMG_YYYYMMDD_、VIDEO_YYYYMMDD_、SelfieCity_、Cover_、
#   MEITU_、april_、wx_camera_、mmexport、beauty_、JanePhoto_、
#   TempPhoto_、Camera_XHS_、以及含 13 位时间戳的文件名
#
# 支持的目录命名规律（按优先级）：
#
#   1. YYYY-MM-DD    例：/WePhotos/2022-04-14/IMG_1876.JPG
#      → DateTimeOriginal = YYYY:MM:DD 00:00:00
#
#   2. YYYY/MM       例：/WePhotos/2022/11/IMG_8729.JPG
#      → DateTimeOriginal = YYYY:MM:01 00:00:00
#
#   3. YYYYMMDD（8位纯数字）  例：/P20/20190909/hash_file.jpg
#      → DateTimeOriginal = YYYY:MM:DD 00:00:00
#
#   4. YYYYMM（6位纯数字）   例：/P20/202005/hash_file.jpg
#      → DateTimeOriginal = YYYY:MM:01 00:00:00
#
# 用法：
#   bash update_dir_date.sh [imagelist.txt]
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

# 判断文件名是否已有可提取的日期时间，返回 0 表示"有"，1 表示"无"
filename_has_datetime() {
    local name="$1"
    # MYXJ_ 格式
    [[ "$name" =~ ^MYXJ_[0-9]{14,} ]] && return 0
    # IMG_YYYYMMDD_HHMMSS 或 VIDEO_YYYYMMDD_HHMMSS
    [[ "$name" =~ ^(IMG|VIDEO)_[0-9]{8}_[0-9]{6}\. ]] && return 0
    # SelfieCity_
    [[ "$name" =~ ^SelfieCity_[0-9]{14}_ ]] && return 0
    # Cover_
    [[ "$name" =~ ^Cover_[0-9]{14} ]] && return 0
    # MEITU_
    [[ "$name" =~ ^MEITU_[0-9]{8}_[0-9]{6} ]] && return 0
    # april_ 格式
    [[ "$name" =~ ^april_[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}- ]] && return 0
    # YYYY-MM-DD-HH-MM-SS 开头
    [[ "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}- ]] && return 0
    # 纯 14 位数字（YYYYMMDDHHMMSS）
    [[ "$name" =~ ^[0-9]{14}\. ]] && return 0
    # Unix 时间戳前缀
    [[ "$name" =~ ^(wx_camera_|mmexport|beauty_|JanePhoto_|TempPhoto_|Camera_XHS_) ]] && return 0
    # UUID(36) + 13位时间戳
    [[ "$name" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}[0-9]{13}\. ]] && return 0
    # 13位时间戳_pic
    [[ "$name" =~ ^[0-9]{13}_pic\. ]] && return 0
    # 文件名本身就是 13 位时间戳
    [[ "$name" =~ ^[0-9]{13}\. ]] && return 0
    # 含 13 位时间戳的复合文件名
    [[ "$name" =~ (^|[^0-9])[0-9]{13}([^0-9]|$) ]] && return 0

    return 1
}

count=0
skip=0
skip_has_dt=0

while IFS= read -r line; do
    filepath="${line#*. }"
    [[ -z "$filepath" ]] && continue

    filename="$(basename "$filepath")"
    dirpath="$(dirname "$filepath")"
    parent="$(basename "$dirpath")"
    grandparent="$(basename "$(dirname "$dirpath")")"

    # 跳过文件名中已有日期时间信息的文件
    if filename_has_datetime "$filename"; then
        (( skip_has_dt++ )) || true
        continue
    fi

    DATETIME=""

    # 规则 1：父目录名为 YYYY-MM-DD
    if [[ "$parent" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]]; then
        DATETIME="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} 00:00:00"

    # 规则 2：祖父目录为 YYYY，父目录为 MM（两级合起来是 YYYY/MM）
    elif [[ "$parent" =~ ^([0-9]{2})$ && "$grandparent" =~ ^([0-9]{4})$ ]]; then
        YEAR="$grandparent"
        MON="$parent"
        DATETIME="${YEAR}:${MON}:01 00:00:00"

    # 规则 3：父目录名为 YYYYMMDD（8位纯数字）
    elif [[ "$parent" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})$ ]]; then
        DATETIME="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} 00:00:00"

    # 规则 4：父目录名为 YYYYMM（6位纯数字）
    elif [[ "$parent" =~ ^([0-9]{4})([0-9]{2})$ ]]; then
        DATETIME="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:01 00:00:00"
    fi

    if [[ -n "$DATETIME" ]]; then
        echo "设置 $filepath  =>  $DATETIME"
        exiftool -overwrite_original -DateTimeOriginal="$DATETIME" "$filepath"
        (( count++ )) || true
    else
        echo "跳过（无法从目录名提取日期）：$filepath" >&2
        (( skip++ )) || true
    fi
done < <(sed 's/^[0-9]*\. //' "$IMAGELIST")

echo "完成：共更新 $count 个文件，跳过 $skip_has_dt 个（文件名已含日期），跳过 $skip 个（目录名无法解析）。"
