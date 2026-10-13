#!/usr/bin/env bash
# FunClass 发布打包脚本
# 1) 生成构建哈希 + 递增构建编号（写入 lib/core/build_info.g.dart）
# 2) 用 --build-number 覆盖 Android versionCode，保证手机能覆盖安装
# 3) 把 APK 复制成带版本号与哈希的文件名，并打印 SHA-256
# 用法：bash tool/build_apk.sh            （release 包）
#      bash tool/build_apk.sh --debug    （调试包）
# 来自Trae
set -euo pipefail

cd "$(dirname "$0")/.."

# Flutter 可执行文件：优先 FLUTTER_BIN 环境变量，其次本机默认路径，
# 都不存在时从 PATH 查找（GitHub Actions 等 CI 环境走这条路）
FLUTTER="${FLUTTER_BIN:-F:/otherCode/flutter-dev/flutter/bin/flutter}"
if ! [ -f "$FLUTTER" ]; then
  FLUTTER="$(command -v flutter)" || { echo "!! 找不到 flutter 可执行文件" >&2; exit 1; }
fi
INFO="lib/core/build_info.g.dart"
APK_DIR="build/app/outputs/flutter-apk"

MODE="release"
EXTRA_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --debug) MODE="debug" ;;
    --split) EXTRA_ARGS+=("--split-per-abi") ;;
    *) EXTRA_ARGS+=("$arg") ;;
  esac
done

echo "==> 生成构建信息"
"$FLUTTER" pub get >/dev/null
dart run tool/gen_build_info.dart

BUILD_NUMBER=$(sed -n "s/^const int buildNumber = \([0-9]*\);/\1/p" "$INFO")
BUILD_HASH=$(sed -n "s/^const String buildHash = '\([0-9a-f]*\)';/\1/p" "$INFO")
APP_VERSION=$(sed -n "s/^const String appVersion = '\([^']*\)';/\1/p" "$INFO")

if [ -z "$BUILD_NUMBER" ] || [ -z "$BUILD_HASH" ]; then
  echo "!! 解析构建信息失败，请检查 $INFO" >&2
  exit 1
fi

echo "==> 构建 ${APP_VERSION}+${BUILD_NUMBER} ($BUILD_HASH)"
"$FLUTTER" build apk "--$MODE" "--build-number=${BUILD_NUMBER}" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}

SRC="$APK_DIR/app-$MODE.apk"
[ -f "$SRC" ] || SRC="$APK_DIR/app-release.apk"

NAME="funclass-${APP_VERSION}+${BUILD_NUMBER}-${BUILD_HASH}-$MODE.apk"
cp "$SRC" "$APK_DIR/$NAME"

echo ""
echo "================ 打包完成 ================"
echo "文件名    : $NAME"
echo "版本号    : $APP_VERSION (versionCode $BUILD_NUMBER)"
echo "构建哈希  : $BUILD_HASH"
echo "构建时间  : $(sed -n "s/^const String buildTime = '\([^']*\)';/\1/p" "$INFO")"
echo "SHA-256   : $(sha256sum "$APK_DIR/$NAME" | cut -d' ' -f1)"
echo "大小      : $(du -h "$APK_DIR/$NAME" | cut -f1)"
echo "路径      : $(pwd)/$APK_DIR/$NAME"