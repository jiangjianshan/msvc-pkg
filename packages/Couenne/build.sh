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
SRC_DIR=$RELS_DIR/$PKG_NAME
BUILD_DIR=$SRC_DIR/build${ARCH//x/}
C_OPTS='-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics'
C_DEFS='-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX'
F_OPTS='-nologo -MD -Qdiag-disable:10448 -fp:precise -Qopenmp -Qopenmp-simd -fpp'

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
    HOST_TRIPLET=i686-w64-mingw32
  elif [[ "$ARCH" == "x64" ]]; then
    HOST_TRIPLET=x86_64-w64-mingw32
  fi
  # NOTE:
  # 1. Don't use CPP="$ROOT_DIR/wrappers/compile cl -nologo -EP" here,
  #    it will cause checking absolute name of standard files is empty.
  #    e.g. checking absolute name of <fcntl.h> ... '', but we can use
  #    CPP="$ROOT_DIR/wrappers/compile cl -nologo -E"
  # 2. Don't use 'compile cl -nologo' but 'compile cl'. Because configure
  #    on some libraries will detect whether is msvc compiler according to
  #    '*cl | cl.exe'
  # 3. Taken care of the logic of func_resolve_sysroot() and func_replace_sysroot()
  #    in ltmain.sh, otherwise may have '-L=*' in the filed of 'dependency_libs' in
  #    *.la. So don't set --with-sysroot if --libdir has been set
  AR="$ROOT_DIR/wrappers/ar-lib lib -nologo"                                   \
  CC="cl"                                                                      \
  CFLAGS="$C_OPTS"                                                             \
  CPP="cl -E"                                                                  \
  CPPFLAGS="$C_DEFS"                                                           \
  CXX="cl"                                                                     \
  CXXFLAGS="-EHsc $C_OPTS"                                                     \
  CXXCPP="cl -E"                                                               \
  DLLTOOL="link -verbose -dll"                                                 \
  LD="link -nologo"                                                            \
  NM="dumpbin -nologo -symbols"                                                \
  PKG_CONFIG="/usr/bin/pkg-config"                                             \
  RANLIB=":"                                                                   \
  RC="$ROOT_DIR/wrappers/windres-rc rc -nologo"                                \
  STRIP=":"                                                                    \
  WINDRES="$ROOT_DIR/wrappers/windres-rc rc -nologo"                           \
  ../configure --build="$(sh ../config.guess)"                                 \
    --host="$HOST_TRIPLET"                                                     \
    --prefix="$PREFIX"                                                         \
    --bindir="$PREFIX/bin"                                                     \
    --includedir="$PREFIX/include"                                             \
    --libdir="$PREFIX/lib"                                                     \
    --enable-msvc                                                              \
    --enable-shared                                                            \
    --with-lapack-lflags="-lblas -llapack"                                     \
    lt_cv_deplibs_check_method=${lt_cv_deplibs_check_method='pass_all'}        \
    gt_cv_locale_zh_CN=none || exit 1
}

patch_stage()
{
  echo "Patching $PKG_NAME $PKG_VER after configure"
  cd "$BUILD_DIR" || exit 1
  # FIXME:
  # To solve following issue
  # libtool: warning: undefined symbols not allowed in x86_64-w64-mingw32
  # shared libraries; building static only
  if [ -f "libtool" ]; then
    echo "Patching libtool in top level"
    sed                                                                        \
      -e "s/\(allow_undefined=\)yes/\1no/"                                     \
      -i libtool
    chmod +x libtool
  fi
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
  clean_build
}

configure_stage
patch_stage
build_stage
install_package
