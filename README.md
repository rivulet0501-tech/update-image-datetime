# update-image-datetime

一组 Bash 脚本，用于根据**文件名**或**目录名**中包含的日期时间信息，批量修正照片的 EXIF `DateTimeOriginal` 与文件修改时间（`FileModifyDate`）。

## 依赖

- [`exiftool`](https://exiftool.org/)（所有脚本必须）
- `date`（GNU coreutils，`update_unix_timestamp.sh` 需要）

## 使用方法

所有脚本的用法统一为：

```bash
bash <脚本名>.sh [图片列表文件]
```

- **图片列表文件**：包含待处理图片路径的文本文件，每行一条路径。行首可带 `N. ` 格式的序号（如 `1. /path/to/photo.jpg`），脚本会自动去除。
- 默认读取当前目录下的 `imagelist.txt`，也可通过参数指定其他路径。

生成图片列表示例（在 macOS / Linux 下）：

```bash
find /your/photo/dir -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | nl -ba > imagelist.txt
```

## 脚本说明

### `update_android_img.sh`

处理 Android 标准相机命名格式的照片。

**适用格式：**
- `IMG_YYYYMMDD_HHMMSS.jpg`
- `VIDEO_YYYYMMDD_HHMMSS.mp4`

### `update_myxj.sh`

处理**美颜相机（MYXJ）**格式的照片。

**适用格式：**
- `MYXJ_YYYYMMDDHHMMSS_fast.jpg`
- `MYXJ_YYYYMMDDHHMMSS_save.jpg`
- `MYXJ_YYYYMMDDHHMMSSmmm_fast.jpg`（新版，含毫秒）

### `update_selfiecity.sh`

处理 **SelfieCity** 美颜相机格式的照片。

**适用格式：**
- `SelfieCity_YYYYMMDDHHMMSS_save.jpg`
- `SelfieCity_YYYYMMDDHHMMSS_org.jpg`

### `update_named_datetime.sh`

处理文件名中直接嵌入日期时间字符串的照片（非上述格式）。

**适用格式（按优先级依次匹配）：**

| 规则 | 示例文件名 | 提取结果 |
|------|-----------|---------|
| `Cover_YYYYMMDDHHMMSS[ms].jpg` | `Cover_20190526160213186.jpg` | `2019:05:26 16:02:13` |
| `MEITU_YYYYMMDD_HHMMSS[ms].jpg` | `MEITU_20250531_113309902.jpg` | `2025:05:31 11:33:09` |
| `april_YYYY-MM-DD-HH-MM-SS-ms.jpg` | `april_2019-08-01-22-26-18-236.jpg` | `2019:08:01 22:26:18` |
| `YYYY-MM-DD-HH-MM-SS-ms.jpg` | `2020-03-18-11-52-53-595.jpg` | `2020:03:18 11:52:53` |
| `YYYYMMDDHHMMSS.jpg`（纯14位数字）| `20190904190251.jpg` | `2019:09:04 19:02:51` |

### `update_unix_timestamp.sh`

处理文件名中包含 **Unix 时间戳**的照片，支持毫秒（13位）和秒级（10位）时间戳。

**适用格式（按优先级依次匹配）：**

| 规则 | 示例文件名 | 说明 |
|------|-----------|------|
| `wx_camera_TIMESTAMP.jpg` | `wx_camera_1664629124753.jpg` | 微信相机，毫秒级 |
| `mmexportTIMESTAMP.jpg` | `mmexport1670726615695.jpg` | 微信导出，毫秒级 |
| `beauty_TIMESTAMP.jpg` | `beauty_1667568005364.jpeg` | 美图秀秀，毫秒级 |
| `JanePhoto_TIMESTAMP.jpg` | `JanePhoto_1559004786211.jpg` | Jane 美颜，毫秒级 |
| `TempPhoto_TIMESTAMP_xxx.jpg` | `TempPhoto_1667035133_original.jpg` | 秒级（10位） |
| `Camera_XHS_TIMESTAMP.jpg` | `Camera_XHS_1761196978652.jpg` | 小红书相机，毫秒级 |
| `UUID(36位)TIMESTAMP(13位).jpeg` | `97d5366a-...-8024f33438211748587257913.jpeg` | UUID 拼接毫秒时间戳 |
| `TIMESTAMP_pic.jpg` | `1557323094264_pic.jpg` | 毫秒时间戳 + `_pic` 后缀 |
| 含13位时间戳的任意文件名 | `5804835_CP0FEDBMX3_1554825442402-v2-0.jpg` | 兜底规则 |

### `update_dir_date.sh`

当**文件名本身无法提取日期时间**时，回退到从**父目录名**提取日期。

**支持的目录命名规律（按优先级）：**

| 规则 | 目录示例 | 提取结果 |
|------|---------|---------|
| `YYYY-MM-DD` | `.../2022-04-14/IMG_1876.JPG` | `2022:04:14 00:00:00` |
| `YYYY/MM`（两级目录）| `.../2022/11/IMG_8729.JPG` | `2022:11:01 00:00:00` |
| `YYYYMMDD`（8位纯数字）| `.../20190909/hash_file.jpg` | `2019:09:09 00:00:00` |
| `YYYYMM`（6位纯数字）| `.../202005/hash_file.jpg` | `2020:05:01 00:00:00` |

文件名已包含可识别日期时间的文件会被自动跳过，不重复处理。

## 典型工作流

```bash
# 1. 生成图片列表
find /your/photo/dir -type f -iname "*.jpg" | nl -ba > imagelist.txt

# 2. 按相机/App 类型依次运行脚本
bash update_android_img.sh imagelist.txt
bash update_myxj.sh imagelist.txt
bash update_selfiecity.sh imagelist.txt
bash update_named_datetime.sh imagelist.txt
bash update_unix_timestamp.sh imagelist.txt

# 3. 对仍未处理的文件，尝试从目录名补全日期
bash update_dir_date.sh imagelist.txt
```

> **提示：** 各脚本互相独立，可按需单独运行，也可组合使用。每个脚本均使用 `exiftool -overwrite_original`，直接覆盖原文件的 EXIF 数据，不生成备份文件，请确保已做好原始文件备份。
