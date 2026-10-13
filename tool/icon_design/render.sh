#!/usr/bin/env bash
# 用 Edge 无头模式把 svg/ 下的图标渲染成 1024×1024 PNG。
#
# 两个坑：
# 1. 连续启动 Edge 会抢同一份 user-data-dir，后启动的直接静默退出，
#    所以每次渲染都给一个独立目录；
# 2. --screenshot 传反斜杠的 Windows 路径会被 shell 吞掉转义、把文件名写坏，
#    统一用正斜杠（Edge 在 Windows 上接受）。——来自Trae
set -euo pipefail

EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
# Edge 只认 Windows 风格路径，用 cygpath 换算再把反斜杠换成正斜杠
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="$(cygpath -w "$HERE" | tr '\\' '/')"
TMPW="$(cygpath -w "${TMPDIR:-/tmp}" | tr '\\' '/')"
mkdir -p "$HERE/png"

i=0
for name in "$@"; do
  i=$((i + 1))
  rm -f "$HERE/png/$name.png"
  "$EDGE" --headless=new --disable-gpu --no-sandbox --hide-scrollbars --no-first-run \
    --default-background-color=00000000 \
    --user-data-dir="$TMPW/edgeicon$$-$i" \
    --window-size=1024,1024 \
    --screenshot="$D/png/$name.png" \
    "file:///$D/svg/$name.svg" >/dev/null 2>&1
  sleep 1
done
