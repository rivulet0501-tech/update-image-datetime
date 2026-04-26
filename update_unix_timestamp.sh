#!/usr/bin/env bash
# update_unix_timestamp.sh
#
# 处理文件名中包含 Unix 时间戳的照片，将时间戳转换为拍摄时间。
#
# 适用规律（按顺序匹配，取第一个命中的规则）：
#
#   1. wx_camera_TIMESTAMP.jpg       — 微信相机，毫秒级时间戳
#      例：wx_camera_1664629124753.jpg
#
#   2. mmexportTIMESTAMP.jpg         — 微信导出，毫秒级时间戳
#      例：mmexport1670726615695.jpg
#
#   3. beauty_TIMESTAMP.jpg          — 美图秀秀，毫秒级时间戳
#      例：beauty_1667568005364.jpeg
#
#   4. JanePhoto_TIMESTAMP.jpg       — Jane 美颜，毫秒级时间戳
#      例：JanePhoto_1559004786211.jpg
#
#   5. TempPhoto_TIMESTAMP_xxx.jpg   — 秒级时间戳（10位）
#      例：TempPhoto_1667035133_original.jpg
#
#   6. Camera_XHS_TIMESTAMP.jpg      — 小红书相机，毫秒级时间戳
#      例：Camera_XHS_1761196978652.jpg
#
#   7. UUID(36位)TIMESTAMP(13位).jpeg — UUID 拼接毫秒时间戳
#      例：97d5366a-a7ce-4c3a-a259-8024f33438211748587257913.jpeg
#
#   8. TIMESTAMP_pic.jpg             — 纯毫秒时间戳 + _pic 后缀
#      例：1557323094264_pic.jpg
#
#   9. 含有 13 位毫秒时间戳的文件名（其他前缀/中缀）
#      例：5804835_CP0FEDBMX3_1554825442402-v2-0.jpg
#          1589000900979.jpg
#
# 用法：
#   bash update_unix_timestamp.sh [imagelist.txt]
#
# 依赖：exiftool, date（GNU coreutils）

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

# 将时间戳（毫秒或秒）转换为 "YYYY:MM:DD HH:MM:SS" 格式
ts_to_datetime() {
    local ts="$1"
    local secs
    if (( ${#ts} >= 12 )); then
        # 毫秒时间戳，转为秒
        secs=$(( ts / 1000 ))
    else
        secs="$ts"
    fi
    date -d "@${secs}" "+%Y:%m:%d %H:%M:%S"
}

count=0
skip=0

while IFS= read -r line; do
    filepath="${line#*. }"
    [[ -z "$filepath" ]] && continue

    filename="$(basename "$filepath")"
    TS=""

    # 规则 1：wx_camera_TIMESTAMP.jpg
    if [[ "$filename" =~ ^wx_camera_([0-9]{10,13})\. ]]; then
        TS="${BASH_REMATCH[1]}"

    # 规则 2：mmexportTIMESTAMP.jpg
    elif [[ "$filename" =~ ^mmexport([0-9]{10,13})\. ]]; then
        TS="${BASH_REMATCH[1]}"

    # 规则 3：beauty_TIMESTAMP.jpg
    elif [[ "$filename" =~ ^beauty_([0-9]{10,13})\. ]]; then
        TS="${BASH_REMATCH[1]}"

    # 规则 4：JanePhoto_TIMESTAMP.jpg
    elif [[ "$filename" =~ ^JanePhoto_([0-9]{10,13})\. ]]; then
        TS="${BASH_REMATCH[1]}"

    # 规则 5：TempPhoto_TIMESTAMP_xxx.jpg（秒级，10位）
    elif [[ "$filename" =~ ^TempPhoto_([0-9]{10})_ ]]; then
        TS="${BASH_REMATCH[1]}"

    # 规则 6：Camera_XHS_TIMESTAMP.jpg
    elif [[ "$filename" =~ ^Camera_XHS_([0-9]{10,13})\. ]]; then
        TS="${BASH_REMATCH[1]}"

    # 规则 7：UUID(36位) + 毫秒时间戳(13位).jpeg
    # UUID 格式：xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx（36字符，含4个横线）
    elif [[ "$filename" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}([0-9]{13})\. ]]; then
        TS="${BASH_REMATCH[1]}"

    # 规则 8：TIMESTAMP_pic.jpg（13位毫秒时间戳）
    elif [[ "$filename" =~ ^([0-9]{13})_pic\. ]]; then
        TS="${BASH_REMATCH[1]}"

    # 规则 9：文件名中包含 13 位毫秒时间戳（兜底规则）
    # 匹配：纯时间戳文件名，或含时间戳的复合文件名（如 5804835_CP0FEDBMX3_1554825442402-v2-0.jpg）
    elif [[ "$filename" =~ (^|[^0-9])([0-9]{13})([^0-9]|$) ]]; then
        TS="${BASH_REMATCH[2]}"
    fi

    if [[ -n "$TS" ]]; then
        DATETIME="$(ts_to_datetime "$TS")"
        echo "设置 $filepath  =>  $DATETIME  (ts=$TS)"
        exiftool -overwrite_original -DateTimeOriginal="$DATETIME" "$filepath"
        (( count++ )) || true
    else
        (( skip++ )) || true
    fi
done < <(sed 's/^[0-9]*\. //' "$IMAGELIST")

echo "完成：共更新 $count 个文件，跳过 $skip 个文件（不匹配的格式）。"
