#!/bin/bash
#
# The values of these environment variables come from mpt.py:
# ARCH            - x64 or x86
# ROOT_DIR        - root location of msvc-pkg
# PREFIX          - install location of current library
# PREFIX_PATH     - install location of third party libraries
#
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
. $ROOT_DIR/compiler.sh
PREFIX=$(cygpath -u "$PREFIX")
PKG_NAME=$(yq -r '.name' config.yaml)
PKG_VER=$(yq -r '.version' config.yaml)
RELS_DIR=$ROOT_DIR/releases
SRC_DIR=$RELS_DIR/$PKG_NAME-$PKG_VER
BUILD_DIR=$SRC_DIR/build${ARCH//x/}
C_OPTS='-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -Zc:__cplusplus -experimental:c11atomics'
C_DEFS='-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX'

clean_build()
{
  echo "Cleaning $PKG_NAME $PKG_VER"
  cd "$SRC_DIR" && [[ -d "$BUILD_DIR" ]] && rm -rf "$BUILD_DIR"
}

configure_stage()
{
  echo "Configuring $PKG_NAME $PKG_VER"
  clean_build
  mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR" || exit 1
  if [[ "$ARCH" == "x86" ]]; then
    HOST_TRIPLET=x86-win32-vs17
  elif [[ "$ARCH" == "x64" ]]; then
    HOST_TRIPLET=x86_64-win64-vs17
  fi
  PKG_CONFIG="/usr/bin/pkg-config"                                             \
  ../configure --target="$HOST_TRIPLET"                                        \
    --prefix="$PREFIX"                                                         \
    --disable-examples                                                         \
    --disable-docs                                                             \
    --enable-vp8                                                               \
    --enable-vp9                                                               \
    --enable-postproc                                                          \
    --enable-vp9-postproc                                                      \
    --enable-onthefly-bitpacking                                               \
    --enable-error-concealment                                                 \
    --enable-coefficient-range-checking                                        \
    --enable-runtime-cpu-detect                                                \
    --enable-static                                                            \
    --enable-small                                                             \
    --enable-postproc-visualizer                                               \
    --enable-multi-res-encoding                                                \
    --enable-vp9-temporal-denoising                                            \
    --enable-webm-io                                                           \
    --enable-libyuv || exit 1
}

build_stage()
{
  echo "Building $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" && make -j$(nproc)
}

install_package()
{
  echo "Installing $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" || exit 1
  if ! make install; then
    exit 1
  fi
  # FIXME:
  # 1. correct the install location of .lib
  mv "$PREFIX/lib/x64/vpxmd.lib" "$PREFIX/lib/vpxmd.lib"
  clean_build
}

configure_stage
build_stage
install_package
