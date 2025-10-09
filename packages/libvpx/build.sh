#!/bin/bash
#
# Build script for the current library.
#
# This script is designed to be invoked by `mpt.bat` using the command `mpt <library_name>`.
# It relies on specific environment variables set by the `mpt` process to function correctly.
#
# Environment Variables Provided by `mpt` (in addition to system variables):
#   ARCH          - Target architecture to build for. Valid values: `x64` or `x86`.
#   PKG_NAME      - Name of the current library being built.
#   PKG_VER       - Version of the current library being built.
#   ROOT_DIR      - Root directory of the msvc-pkg project.
#   SRC_DIR       - Source code directory of the current library.
#   PREFIX        - **Actual installation path prefix** for the *current* library after successful build.
#                   This path is where the built artifacts for *this specific library* will be installed.
#                   It usually equals `_PREFIX`, but **may differ** if a non-default installation path
#                   was explicitly specified for this library (e.g., `D:\LLVM` for `llvm-project`).
#   PREFIX_PATH   - List of installation directory prefixes for third-party dependencies.
#   _PREFIX       - **Default installation path prefix** for all built libraries.
#                   This is the root directory where libraries are installed **unless overridden**
#                   by a specific `PREFIX` setting for an individual library.
#
#   For each direct dependency `{Dependency}` of the current library:
#     {Dependency}_SRC - Source code directory of the dependency `{Dependency}`.
#     {Dependency}_VER - Version of the dependency `{Dependency}`.

. $ROOT_DIR/compiler.sh $ARCH
BUILD_DIR=$SRC_DIR/build${ARCH//x/}
C_OPTS='-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics'
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

install_stage()
{
  echo "Installing $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" || exit 1
  cp -rv *.h $PREFIX/include
  pushd x64/Release
  cp -rv *.lib $PREFIX/lib
  popd
  if [[ ! -f "$PREFIX/lib/vpx.lib" ]]; then
    ln -sv "$PREFIX/lib/vpxmd.lib" "$PREFIX/lib/vpx.lib"
  fi
  clean_build
}

configure_stage
patch_stage
build_stage
install_stage
