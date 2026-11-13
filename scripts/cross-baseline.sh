#!/usr/bin/env bash
# 交叉编译基线版本（pixman 用 meson，需 --cross-file）：
# baseline 编成 riscv64，探针用 qemu-user 跑，与 native 基线逐字段比对。
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=${IMAGE:-rvv-cross:1}
MARCH=${MARCH:-rv64gc}
OUT=build/riscv64-b

docker run --rm -v "$PWD":/work -w /work "${IMAGE}" bash -lc "
set -e
rm -rf ${OUT}
sed -i \"s/-march=rv64gc/-march=${MARCH}/\" cmake/meson-cross-riscv64.ini
meson setup ${OUT}/bld baseline --cross-file cmake/meson-cross-riscv64.ini \
  --prefix /work/${OUT}/prefix --libdir lib --buildtype release \
  -Ddefault_library=static > /tmp/m.log 2>&1 || { tail -30 /tmp/m.log; exit 1; }
meson compile -C ${OUT}/bld > /tmp/mb.log 2>&1 || { tail -20 /tmp/mb.log; exit 1; }
meson install -C ${OUT}/bld > /dev/null

cmake -S . -B ${OUT}/harness -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
  -DCMAKE_C_FLAGS='-march=${MARCH}' \
  -DPKG_PREFIX=/work/${OUT}/prefix > /tmp/h.log 2>&1 || { tail -30 /tmp/h.log; exit 1; }
cmake --build ${OUT}/harness -j > /tmp/hb.log 2>&1 || { tail -20 /tmp/hb.log; exit 1; }

mkdir -p ${OUT}/out
qemu-riscv64 -L /usr/riscv64-linux-gnu ${OUT}/harness/pixman_harness ${OUT}/out/composite.ppm > ${OUT}/out/hash.txt
echo \"--- riscv64（${MARCH}）---\"; cat ${OUT}/out/hash.txt
echo \"--- native 基线 ---\"; cat build/ab-data/out/01_pixman_composite/a/hash.txt
"
