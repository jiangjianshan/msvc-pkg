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
CU_OPTS="-gencode arch=compute_${NV_COMPUTE//.},code=sm_${NV_COMPUTE//.} -O2"

clean_stage()
{
  echo "Cleaning $PKG_NAME $PKG_VER"
  cd "$SRC_DIR" && [[ -d "$BUILD_DIR" ]] && rm -rf "$BUILD_DIR"
}

configure_stage()
{
  echo "Configuring $PKG_NAME $PKG_VER"
  mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
  if [[ "$ARCH" == "x86" ]]; then
    HOST_TRIPLET=x86
  elif [[ "$ARCH" == "x64" ]]; then
    HOST_TRIPLET=x86_64
  fi
  if [[ -d "$CUDA_PATH" ]]; then
    WITH_GPU=--enable-cuda-nvcc
  else
    WITH_GPU=
  fi
  # NOTE:
  # 1. Don't use CPP="$ROOT_DIR/wrappers/compile cl -nologo -EP" here,
  #    it will cause checking absolute name of standard files is empty.
  #    e.g. checking absolute name of <fcntl.h> ... '', but we can use
  #    CPP="$ROOT_DIR/wrappers/compile cl -nologo -E"
  # 2. Don't use 'compile cl -nologo' but 'compile cl'. Because configure
  #    on some libraries will detect whether is msvc compiler according to
  #    '*cl | cl.exe'
  ../configure --prefix="$PREFIX"                                              \
    --arch="$HOST_TRIPLET"                                                     \
    --toolchain=msvc                                                           \
    --disable-debug                                                            \
    --enable-avisynth                                                          \
    --enable-chromaprint                                                       \
    --enable-gmp                                                               \
    --enable-gpl                                                               \
    --enable-nonfree                                                           \
    --enable-version3                                                          \
    --enable-avisynth                                                          \
    --enable-lcms2                                                             \
    --enable-libaom                                                            \
    --enable-libdav1d                                                          \
    --enable-libfdk-aac                                                        \
    --enable-libfontconfig                                                     \
    --enable-libfreetype                                                       \
    --enable-libfribidi                                                        \
    --enable-libharfbuzz                                                       \
    --enable-libjxl                                                            \
    --enable-libopenh264                                                       \
    --enable-libopenjpeg                                                       \
    --enable-libopus                                                           \
    --enable-librsvg                                                           \
    --enable-libsvtav1                                                         \
    --enable-libvpx                                                            \
    --enable-libvvenc                                                          \
    --enable-libwebp                                                           \
    --enable-libx264                                                           \
    --enable-libx265                                                           \
    --enable-libxml2                                                           \
    --enable-libzmq                                                            \
    --enable-openssl                                                           \
    --enable-pic                                                               \
    --enable-shared $WITH_GPU                                                  \
    --extra-cflags="$C_OPTS $C_DEFS"                                           \
    --extra-cxxflags="-EHsc $C_OPTS $C_DEFS"                                   \
    --extra-libs="pthread.lib"                                                 \
    --host-cflags="$C_OPTS"                                                    \
    --host-cppflags="$C_DEFS"                                                  \
    --nvccflags="$CU_OPTS $C_DEFS" || exit 1
}

build_stage()
{
  echo "Building $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" && make -k -j$(nproc) || exit 1
}

install_stage()
{
  echo "Installing $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" && make install || exit 1
}

clean_stage
configure_stage
build_stage
install_stage
clean_stage
