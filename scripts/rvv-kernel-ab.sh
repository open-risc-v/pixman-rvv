#!/usr/bin/env bash
# G3：pixman 的 RVV 功能 A/B。
#
# 和别的包不同，pixman 上游**已经自带 RVV 实现**（pixman-rvv.c，要求 GCC 14 / Clang 18
# 的 intrinsics 1.0 与 -march=rv64gcv1p0），所以这里不是"写内核"，而是"打开并验收"：
#   A = 上游 RVV 实现生效（-march=rv64gcv，meson 自动探测通过）
#   B = 显式 -Drvv=disabled，同一 -march 下只走标量/编译器自动向量化
# 功能用 qemu 逐字节比对；性能只能在真机上取，脚本同时产出两个静态基准二进制。
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${IMAGE:-rvv-cross:2}
OUT=build/rvv-k

docker run --rm -v "$PWD":/work -w /work "${IMAGE}" bash -lc "
set -e
rm -rf ${OUT}; mkdir -p ${OUT}
for side in on off; do
  echo \"== 构建 \$side\"
  opt=''
  if [ \$side = off ]; then opt='-Drvv=disabled'; fi
  meson setup ${OUT}/\$side/bld src --cross-file cmake/meson-cross-riscv64-rvv-\$side.ini \
    --prefix /work/${OUT}/\$side/prefix --libdir lib --buildtype release \
    -Ddefault_library=static \$opt > ${OUT}/\$side-meson.log 2>&1 || { tail -25 ${OUT}/\$side-meson.log; exit 1; }
  meson compile -C ${OUT}/\$side/bld > ${OUT}/\$side-build.log 2>&1 || { tail -25 ${OUT}/\$side-build.log; exit 1; }
  meson install -C ${OUT}/\$side/bld > /dev/null

  cmake -S . -B ${OUT}/\$side/harness -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
    -DCMAKE_C_FLAGS='-march=rv64gcv' \
    -DPKG_PREFIX=/work/${OUT}/\$side/prefix > /dev/null 2>&1
  cmake --build ${OUT}/\$side/harness -j > /dev/null 2>&1
  qemu-riscv64 -L /usr/riscv64-linux-gnu ${OUT}/\$side/harness/pixman_harness \
    ${OUT}/\$side/composite.ppm > ${OUT}/\$side/hash.txt

  riscv64-linux-gnu-gcc -O3 -march=rv64gcv -static \
    -I ${OUT}/\$side/prefix/include/pixman-1 \
    test/bench_over.c ${OUT}/\$side/prefix/lib/libpixman-1.a -lm \
    -o ${OUT}/\$side/bench_over
done

echo '--- A：上游 RVV 生效 ---'; cat ${OUT}/on/hash.txt
echo '--- B：rvv=disabled ---'; cat ${OUT}/off/hash.txt
if cmp -s ${OUT}/on/hash.txt ${OUT}/off/hash.txt; then
  echo '== 功能一致：RVV 路径与标量路径逐字节相同'
else
  echo '== 功能不一致'; exit 1
fi
"
