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
BUILD_DIR=$SRC_DIR
C_OPTS='-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics'
C_DEFS='-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX'

build_stage()
{
  echo "Building $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" && make -j$(nproc) PREFIX=$PREFIX
}

install_stage()
{
  echo "Installing $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" || exit 1
  if ! make install PREFIX=$PREFIX; then
    exit 1
  fi
  sed -E "s|^(prefix=).*|\1${PREFIX}|" -i "${PREFIX}/lib/pkgconfig/ffnvcodec.pc"
}

build_stage
install_stage
