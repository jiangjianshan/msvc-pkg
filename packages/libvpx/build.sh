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
    YASM_OBJ_FMT=win32
  elif [[ "$ARCH" == "x64" ]]; then
    HOST_TRIPLET=x86_64-win64-vs17
    YASM_OBJ_FMT=win64
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
  # 4. Don't set CFLAGS for gmp, because yasm also use this flags. If
  #    there are some flags are unknown for yasm, the configuration will
  #    fail
  # 5. Don't use yasm 1.3.0 to build it because some syntax of .s is not
  #    supported. It's recommand to use git master version of yasm
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
