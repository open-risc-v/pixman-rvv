#!/usr/bin/env bash
# 真实包用例：pixman 的 fill / composite / linear-gradient 三条路径。
# A/B 都跑同一个探针（test/pkg_pixman.c），但链接各自的 libpixman（src/ vs baseline/）。
# 产出：哈希文本 + PPM 像素图，逐字节比较。
set -euo pipefail

: "${STAGE:=run}" "${SIDE:=A}" "${BIN:=build/native}" "${DATA:=build/ab-data}" "${OUT:=build/ab-data/out}"
mkdir -p "$DATA" "$OUT"

case "$STAGE" in
  gen)
    ;;  # 输入是程序内确定性生成的，不需要外部语料
  run)
    if [ ! -x "$BIN/pixman_harness" ]; then
      echo "缺少 $BIN/pixman_harness（上游未接入或构建失败）" >&2
      exit 1
    fi
    "$BIN/pixman_harness" "$OUT/composite.ppm" > "$OUT/hash.txt"
    # 自证：PPM 头与大小必须对得上，防止"跑了个空文件也算一致"
    size=$(wc -c < "$OUT/composite.ppm" | tr -d ' ')
    [ "$size" -ge $((129 * 97 * 3)) ] || { echo "PPM 尺寸异常：$size" >&2; exit 1; }
    ;;
  *)
    echo "未知 STAGE=$STAGE" >&2; exit 2 ;;
esac
