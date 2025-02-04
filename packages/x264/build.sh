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
SRC_DIR=$RELS_DIR/$PKG_NAME
BUILD_DIR=$SRC_DIR/build${ARCH//x/}
C_OPTS='-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:fast -openmp:llvm -Zc:__cplusplus -experimental:c11atomics'
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
  CC=cl ../configure --host="$HOST_TRIPLET"                                    \
    --prefix="$PREFIX"                                                         \
    --bindir="$PREFIX/bin"                                                     \
    --includedir="$PREFIX/include"                                             \
    --libdir="$PREFIX/lib"                                                     \
    --enable-static                                                            \
    --enable-shared                                                            \
    --extra-cflags="$C_OPTS $C_DEFS" || exit 1
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
build_stage
install_package
