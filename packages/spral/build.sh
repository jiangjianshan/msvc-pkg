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

. $ROOT_DIR/compiler.sh $ARCH oneapi
BUILD_DIR=$SRC_DIR/build${ARCH//x/}
# NOTE: Use '-Qopenmp -Qopenmp-simd' here will cause 'icx-cl: error: clang frontend command failed due to signal' when compile NumericSubtree.cxx.
#       There are two solutions:
#       1. Remove '-Qopenmp -Qopenmp-simd'
#       2. Don't add '-EHsc' to CXXFLAGS
C_OPTS='-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -Qopenmp -Qopenmp-simd -Xclang -O2 -fms-extensions -fms-hotpatch -fms-compatibility -fms-compatibility-version='${MSC_VER}
C_DEFS='-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX'
F_OPTS='-nologo -MD -Qdiag-disable:10448 -Qdiag-disable:10441 -fp:precise -Qopenmp -Qopenmp-simd -fpp'

clean_build()
{
  echo "Cleaning $PKG_NAME $PKG_VER"
  cd "$SRC_DIR" && [[ -d "$BUILD_DIR" ]] && rm -rf "$BUILD_DIR"
}

prepare_stage()
{
  echo "Patching package $PKG_NAME $PKG_VER"
  cd "$SRC_DIR" || exit 1
  if [ ! -f "AUTHORS" ]; then
    touch ./AUTHORS
  fi
  if [ ! -f "NEWS" ]; then
    touch ./NEWS
  fi
  WANT_AUTOCONF='2.69' WANT_AUTOMAKE='1.16' autoreconf -ifv
  rm -rfv autom4te.cache
  find . -name "*~" -type f -print -exec rm -rfv {} \;
}

configure_stage()
{
  echo "Configuring $PKG_NAME $PKG_VER"
  clean_build
  mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR" || exit 1
  if [[ -d "$CUDA_PATH" ]]; then
    cp -v "$SRC_DIR/nvcc_arch_sm.c" "$BUILD_DIR"
    WITHOUT_GPU=
  else
    WITHOUT_GPU=--disable-gpu
  fi
  export OMP_CANCELLATION=TRUE
  export OMP_PROC_BIND=TRUE
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
  # 3. If use ifx, it will throw out 'xfortcom: Fatal: There has been an internal compiler error (C0000005)"
  #    when compile akeep.f90, so that use ifort here
  AR="$ROOT_DIR/wrappers/ar-lib lib -nologo"                                                                 \
  CC="$ROOT_DIR/wrappers/compile icx-cl"                                                                     \
  CFLAGS="$C_OPTS"                                                                                           \
  CPP="$ROOT_DIR/wrappers/compile icx-cl -E"                                                                 \
  CPPFLAGS="$C_DEFS"                                                                                         \
  CXX="$ROOT_DIR/wrappers/compile icx-cl"                                                                    \
  CXXFLAGS="$C_OPTS"                                                                                         \
  CXXCPP="$ROOT_DIR/wrappers/compile icx-cl -E"                                                              \
  CXXLIB="-Qcxxlib"                                                                                          \
  DLLTOOL="link -verbose -dll"                                                                               \
  F77="$ROOT_DIR/wrappers/compile ifort"                                                                     \
  FFLAGS="-f77rtl $F_OPTS"                                                                                   \
  FC="$ROOT_DIR/wrappers/compile ifort"                                                                      \
  FCFLAGS="$F_OPTS"                                                                                          \
  LD="link -nologo"                                                                                          \
  NM="dumpbin -nologo -symbols"                                                                              \
  NVCCFLAGS="-shared -gencode arch=compute_${NV_COMPUTE//.},code=sm_${NV_COMPUTE//.} -Xcompiler=-MD"         \
  PKG_CONFIG="/usr/bin/pkg-config"                                                                           \
  RANLIB=":"                                                                                                 \
  RC="$ROOT_DIR/wrappers/windres-rc rc -nologo"                                                              \
  STRIP=":"                                                                                                  \
  WINDRES="$ROOT_DIR/wrappers/windres-rc rc -nologo"                                                         \
  ../configure --host="$HOST_TRIPLET"                                                                        \
    --prefix="$PREFIX"                                                                                       \
    --disable-static                                                                                         \
    --enable-shared $WITHOUT_GPU                                                                             \
    --with-blas="-lblas"                                                                                     \
    --with-lapack="-llapack"                                                                                 \
    --with-metis="-lmetis"                                                                                   \
    --with-metis-inc-dir="$(cygpath -u "${METIS_PREFIX:-$_PREFIX}")/include"                                 \
    ac_cv_prog_f77_v="-verbose"                                                                              \
    ac_cv_prog_fc_v="-verbose"                                                                               \
    lt_cv_deplibs_check_method=${lt_cv_deplibs_check_method='pass_all'}                                      \
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
    sed                                                                                                      \
      -e "s/\(allow_undefined=\)yes/\1no/"                                                                   \
      -i libtool
    chmod +x libtool
  fi
}

build_stage()
{
  echo "Building $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" && make
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

prepare_stage
configure_stage
patch_stage
build_stage
install_stage
