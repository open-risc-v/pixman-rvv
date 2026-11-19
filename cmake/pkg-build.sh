#!/usr/bin/env bash
# 用上游自己的构建系统把上游库编译进 <OUT>/prefix，供 A/B 两侧各自构建。
#   pkg-build.sh <上游源码树> <输出目录>
# A（src/）与 B（baseline/）各跑一次；两侧差异只来自源码树与 RVV_KERNELS 宏
# （native 下无差异，交叉编译到 RVV 时才体现）。
set -euo pipefail
SRC=$1
OUT=$2
MARCH=${3:-rv64gcv}
KERN=${4:-0}
if [ "$KERN" = "1" ]; then export CFLAGS="${CFLAGS:-} -march=${MARCH} -DRVV_KERNELS=1"; fi

rm -rf "${OUT}"
mkdir -p "${OUT}/bld"

meson setup "${OUT}/bld" "${SRC}" \
  --prefix "${OUT}/prefix" --libdir lib --buildtype release \
  -Ddefault_library=static >/dev/null
meson compile -C "${OUT}/bld" >/dev/null
meson install -C "${OUT}/bld" >/dev/null
echo "== 上游 pixman 构建完成：${OUT}/prefix"
