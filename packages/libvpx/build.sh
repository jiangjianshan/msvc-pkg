#!/bin/bash
#
#  Build script for the current library, it should not be called directly from the
#  command line, but should be called from mpt.py.
#
#  The values of these environment variables come from mpt.py:
#  ARCH            - x64 or x86
#  ROOT_DIR        - root location of msvc-pkg
#  PREFIX          - install location of current library
#  PREFIX_PATH     - install location of third party libraries
#  _PREFIX         - default install location if not list in settings.yaml
#
#  Copyright (c) 2024 Jianshan Jiang
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in all
#  copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#  SOFTWARE.

PKG_NAME=$(yq -r '.name' config.yaml)
PKG_VER=$(yq -r '.version' config.yaml)
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line."
    echo "To build $PKG_NAME and its dependencies, please go to the root location of msvc-pkg, and then press"
    echo "mpt $PKG_NAME"
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
. $ROOT_DIR/compiler.sh $ARCH
PREFIX=$(cygpath -u "$PREFIX")
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
    YASM_OBJ_FMT=win32
  elif [[ "$ARCH" == "x64" ]]; then
    HOST_TRIPLET=x86_64-win64-vs17
    YASM_OBJ_FMT=win64
  fi
  PKG_CONFIG="/usr/bin/pkg-config"                                             \
  ../configure --target="$HOST_TRIPLET"                                        \
    --prefix="$PREFIX"                                                         \
    --disable-examples                                                         \
    --disable-docs                                                             \
    --enable-pic                                                               \
    --enable-codec-srcs                                                        \
    --enable-vp9-highbitdepth                                                  \
    --enable-better-hw-compatibility                                           \
    --enable-vp8                                                               \
    --enable-vp9                                                               \
    --enable-internal-stats                                                    \
    --enable-postproc                                                          \
    --enable-vp9-postproc                                                      \
    --enable-onthefly-bitpacking                                               \
    --enable-error-concealment                                                 \
    --enable-coefficient-range-checking                                        \
    --enable-onthefly-bitpacking                                               \
    --enable-runtime-cpu-detect                                                \
    --enable-static                                                            \
    --enable-small                                                             \
    --enable-postproc-visualizer                                               \
    --enable-multi-res-encoding                                                \
    --enable-vp9-temporal-denoising                                            \
    --enable-webm-io                                                           \
    --enable-libyuv                                                            \
    || exit 1
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
  if [[ ! -f "$PREFIX/lib/vpx.lib" ]]; then
    ln -sv "$PREFIX/lib/x64/vpxmd.lib" "$PREFIX/lib/vpx.lib"
  fi
  clean_build
}

configure_stage
build_stage
install_package
