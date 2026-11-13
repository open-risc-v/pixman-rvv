# 上游接入：pixman 用 meson，先由 pkg-build.sh 编进 <build>/pkg/prefix，
# 再让 A/B 探针链接该前缀下的 libpixman。A/B 各自独立前缀，唯一变量是源码树。
#
# 纪律：探针只消费公开 API；一旦探针依赖内部头文件，上游重构就会伪装成"移植失败"。

set(PKG_ROOT "${CMAKE_BINARY_DIR}/pkg")
if(NOT DEFINED PKG_PREFIX)
  set(PKG_PREFIX "${PKG_ROOT}/prefix")
  add_custom_target(pkg ALL
  COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/cmake/pkg-build.sh" "${SRC_DIR}" "${PKG_ROOT}"
  COMMENT "构建上游 pixman（${SRC_DIR}）"
  VERBATIM)
  set(HAVE_PKG_TARGET TRUE)
endif()

add_executable(pixman_harness test/pkg_pixman.c)
if(HAVE_PKG_TARGET)
  add_dependencies(pixman_harness pkg)
endif()
# 用 -l 形式而不是绝对路径：否则 CMake 会把 .a 当成"缺规则的文件"，
# 在首次配置（库还没生成）时直接报错。
target_include_directories(pixman_harness PRIVATE "${PKG_PREFIX}/include/pixman-1")
target_link_directories(pixman_harness PRIVATE "${PKG_PREFIX}/lib")
target_link_libraries(pixman_harness PRIVATE pixman-1 m)
target_compile_options(pixman_harness PRIVATE ${RVV_FLAGS})

add_test(NAME pixman_harness COMMAND pixman_harness)
