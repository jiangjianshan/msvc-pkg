#!/bin/bash
#
#  Build script for the current library, it should not be called directly from the
#  command line, but should be called from mpt.bat.
#
#  The values of these environment variables come from mpt.bat:
#  ARCH            - x64 or x86
#  PKG_NAME        - name of library
#  PKG_VER         - version of library
#  ROOT_DIR        - root location of msvc-pkg
#  PREFIX          - install location of current library
#  PREFIX_PATH     - install location of third party libraries
#  _PREFIX         - default install location if not list in settings.yaml
#

if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line."
    echo "To build $PKG_NAME and its dependencies, please go to the root location of msvc-pkg, and then press"
    echo "mpt $PKG_NAME"
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
. $ROOT_DIR/compiler.sh $ARCH
PREFIX=$(cygpath -u "$PREFIX")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME-$PKG_VER
BUILD_DIR=$SRC_DIR/build${ARCH//x/}
C_OPTS='-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics'
C_DEFS='-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX'
CU_OPTS="-gencode arch=compute_${NV_COMPUTE//.},code=sm_${NV_COMPUTE//.} -O2"

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
    --nvccflags="$CU_OPTS $C_DEFS"                                             \
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
  if ! make install; then
    exit 1
  fi
  clean_build
}

configure_stage
patch_stage
build_stage
install_stage
