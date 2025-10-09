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
C_OPTS='-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:contract -Qopenmp -Qopenmp-simd -Wno-implicit-function-declaration -Wno-pointer-sign -Xclang -O2 -fms-extensions -fms-hotpatch -fms-compatibility -fms-compatibility-version='${MSC_VER}
C_DEFS='-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX'
F_OPTS='-nologo -MD -Qdiag-disable:10448 -fp:contract -Qopenmp -Qopenmp-simd -fpp'

clean_build()
{
  echo "Cleaning $PKG_NAME $PKG_VER"
  cd "$SRC_DIR" && [[ -d "$BUILD_DIR" ]] && rm -rf "$BUILD_DIR"
}

prepare_stage()
{
  echo "Patching package $PKG_NAME $PKG_VER"
  cd "$SRC_DIR" || exit 1
  # XXX: libtool don't have options can set the naming style of static and
  #      shared library. Here is only a workaround.
  echo "Patching ltmain.sh in top level"
  sed                                                                                                \
    -e 's|old_library=$libname\.$libext|old_library=lib$libname.$libext|g'                           \
    -e 's|$output_objdir/$libname\.$libext|$output_objdir/lib$libname.$libext|g'                     \
    -i ltmain.sh

  # NOTE: Changed '*,cl*)' to '*,cl| *,icx-cl* | *,ifx*)' and 'cl*)' to 'cl* | icx-cl* | ifort* | ifx*)'
  #       can solved following two issues:
  #       1) If use 'dumpbin /export fftw3.lib', the result will be look like below:
  #         ordinal hint RVA      name
  #         1       0    000E1650 DFFTW_CLEANUP
  #         2       1    000E17A0 DFFTW_COST
  #         It contain the value of ordinal, hint and RVA, but this is not want for those libraries
  #         that use MSVC compiler and want to import this fftw3.lib.
  #       2) The library_names_spec is not correct because it contains .dll name. This will also cause
  #          the shared library will be converted to symbolic link as .dll file.
  echo "Patching configure in top level"
  sed                                                                                                \
    -e "s|libname_spec='lib\$name'|libname_spec='\$name'|g"                                          \
    -e 's|\.dll\.lib|.lib|g'                                                                         \
    -e 's/ \*,cl\*)/ *,cl* | *,icx-cl* | *,ifort* | *,ifx*)/g'                                       \
    -e 's/ cl\*)/ cl* | icx-cl* | ifort* | ifx*)/g'                                                  \
    -e 's/ ifort\*)/ ifort* | ifx*)/g'                                                               \
    -e 's/ ifort\*,ia64\*)/ ifort*,ia64* | ifx*,ia64*)/g'                                            \
    -e 's/ ifort\*|nagfor\*)/ ifort*|ifx*|nagfor*)/g'                                                \
    -e 's|ifort ifc|ifort ifx ifc|g'                                                                 \
    -i configure
  chmod +x configure
}

configure_stage1()
{
  echo "Configuring $PKG_NAME $PKG_VER" on stage 1
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
  # 3. If not set 'MPILIBS="-limpi"', after the following command:
  #    /bin/sh ../libtool  --tag=CC   --mode=link /e/Githubs/msvc-pkg/wrappers/mpiicl
  #    it will be not except one as here:
  #    libtool: link: /e/Githubs/msvc-pkg/wrappers/mpiicl
  #    but will be the one not related to mpi wrapper
  #    libtool: link: /e/Githubs/msvc-pkg/wrappers/compile cl
  # 4. option '--enable-generic-simd128' and '--enable-generic-simd256'
  #    will be failed at msvc complie phase. msvc doesn't support
  #    '__attribute__ ((vector_size(16)))' and '__m128' is not really
  #    equivalent to it. But use clang-cl or icx-cl instead of cl can
  #    solve this issue.
  AR="$ROOT_DIR/wrappers/ar-lib lib -nologo"                                   \
  CC="$ROOT_DIR/wrappers/compile icx-cl"                                       \
  CFLAGS="$C_OPTS"                                                             \
  CPP="$ROOT_DIR/wrappers/compile icx-cl -E"                                   \
  CPPFLAGS="$C_DEFS"                                                           \
  CXX="$ROOT_DIR/wrappers/compile icx-cl"                                      \
  CXXFLAGS="-EHsc $C_OPTS"                                                     \
  CXXCPP="$ROOT_DIR/wrappers/compile icx-cl -E"                                \
  DLLTOOL="link -verbose -dll"                                                 \
  F77="ifx"                                                                    \
  FFLAGS="-f77rtl $F_OPTS"                                                     \
  FC="ifx"                                                                     \
  FCFLAGS="$F_OPTS"                                                            \
  LD="lld-link"                                                                \
  LDFLAGS="-fuse-ld=lld"                                                       \
  MPICC="$ROOT_DIR/wrappers/mpiicl"                                            \
  MPICXX="$ROOT_DIR/wrappers/mpiicl"                                           \
  MPIF77="$ROOT_DIR/wrappers/mpiifx"                                           \
  MPILIBS="-limpi"                                                             \
  NM="dumpbin -nologo -symbols"                                                \
  PKG_CONFIG="/usr/bin/pkg-config"                                             \
  RANLIB=":"                                                                   \
  RC="$ROOT_DIR/wrappers/windres-rc rc -nologo"                                \
  STRIP=":"                                                                    \
  WINDRES="$ROOT_DIR/wrappers/windres-rc rc -nologo"                           \
  ../configure --host="$HOST_TRIPLET"                                          \
    --prefix="$PREFIX"                                                         \
    --enable-shared                                                            \
    --enable-static                                                            \
    --enable-single                                                            \
    --enable-sse                                                               \
    --enable-sse2                                                              \
    --enable-avx                                                               \
    --enable-avx2                                                              \
    --enable-avx512                                                            \
    --enable-avx-128-fma                                                       \
    --enable-mips-zbus-timer                                                   \
    --enable-generic-simd128                                                   \
    --enable-generic-simd256                                                   \
    --enable-fma                                                               \
    --enable-mpi                                                               \
    --enable-openmp                                                            \
    --enable-threads                                                           \
    --with-our-malloc                                                          \
    --with-our-malloc16                                                        \
    --with-windows-f77-mangling                                                \
    ac_cv_prog_f77_v="-verbose"                                                \
    lt_cv_deplibs_check_method=${lt_cv_deplibs_check_method='pass_all'}        \
    gt_cv_locale_zh_CN=none || exit 1
}

configure_stage2()
{
  echo "Configuring $PKG_NAME $PKG_VER" on stage 2
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
  # 3. If not set 'MPILIBS="-limpi"', after the following command:
  #    /bin/sh ../libtool  --tag=CC   --mode=link /e/Githubs/msvc-pkg/wrappers/mpiicl
  #    it will be not except one as here:
  #    libtool: link: /e/Githubs/msvc-pkg/wrappers/mpiicl
  #    but will be the one not related to mpi wrapper
  #    libtool: link: /e/Githubs/msvc-pkg/wrappers/compile cl
  # 4. option '--enable-generic-simd128' and '--enable-generic-simd256'
  #    will be failed at msvc complie phase. msvc doesn't support
  #    '__attribute__ ((vector_size(16)))' and '__m128' is not really
  #    equivalent to it. But use clang-cl or icx-cl instead of cl can
  #    solve this issue.
  AR="$ROOT_DIR/wrappers/ar-lib lib -nologo"                                   \
  CC="$ROOT_DIR/wrappers/compile icx-cl"                                       \
  CFLAGS="$C_OPTS"                                                             \
  CPP="$ROOT_DIR/wrappers/compile icx-cl -E"                                   \
  CPPFLAGS="$C_DEFS"                                                           \
  CXX="$ROOT_DIR/wrappers/compile icx-cl"                                      \
  CXXFLAGS="-EHsc $C_OPTS"                                                     \
  CXXCPP="$ROOT_DIR/wrappers/compile icx-cl -E"                                \
  DLLTOOL="link -verbose -dll"                                                 \
  F77="ifx"                                                                    \
  FFLAGS="-f77rtl $F_OPTS"                                                     \
  FC="ifx"                                                                     \
  FCFLAGS="$F_OPTS"                                                            \
  LD="lld-link"                                                                \
  LDFLAGS="-fuse-ld=lld"                                                       \
  MPICC="$ROOT_DIR/wrappers/mpiicl"                                            \
  MPICXX="$ROOT_DIR/wrappers/mpiicl"                                           \
  MPIF77="$ROOT_DIR/wrappers/mpiifx"                                           \
  MPILIBS="-limpi"                                                             \
  NM="dumpbin -nologo -symbols"                                                \
  PKG_CONFIG="/usr/bin/pkg-config"                                             \
  RANLIB=":"                                                                   \
  RC="$ROOT_DIR/wrappers/windres-rc rc -nologo"                                \
  STRIP=":"                                                                    \
  WINDRES="$ROOT_DIR/wrappers/windres-rc rc -nologo"                           \
  ../configure --host="$HOST_TRIPLET"                                          \
    --prefix="$PREFIX"                                                         \
    --enable-shared                                                            \
    --enable-static                                                            \
    --enable-sse2                                                              \
    --enable-avx                                                               \
    --enable-avx2                                                              \
    --enable-avx512                                                            \
    --enable-avx-128-fma                                                       \
    --enable-mips-zbus-timer                                                   \
    --enable-generic-simd128                                                   \
    --enable-generic-simd256                                                   \
    --enable-fma                                                               \
    --enable-mpi                                                               \
    --enable-openmp                                                            \
    --enable-threads                                                           \
    --with-our-malloc                                                          \
    --with-our-malloc16                                                        \
    --with-windows-f77-mangling                                                \
    ac_cv_prog_f77_v="-verbose"                                                \
    lt_cv_deplibs_check_method=${lt_cv_deplibs_check_method='pass_all'}        \
    gt_cv_locale_zh_CN=none || exit 1
}

configure_stage3()
{
  echo "Configuring $PKG_NAME $PKG_VER" on stage 3
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
  # 3. If not set 'MPILIBS="-limpi"', after the following command:
  #    /bin/sh ../libtool  --tag=CC   --mode=link /e/Githubs/msvc-pkg/wrappers/mpiicl
  #    it will be not except one as here:
  #    libtool: link: /e/Githubs/msvc-pkg/wrappers/mpiicl
  #    but will be the one not related to mpi wrapper
  #    libtool: link: /e/Githubs/msvc-pkg/wrappers/compile cl
  AR="$ROOT_DIR/wrappers/ar-lib lib -nologo"                                   \
  CC="$ROOT_DIR/wrappers/compile icx-cl"                                       \
  CFLAGS="$C_OPTS"                                                             \
  CPP="$ROOT_DIR/wrappers/compile icx-cl -E"                                   \
  CPPFLAGS="$C_DEFS"                                                           \
  CXX="$ROOT_DIR/wrappers/compile icx-cl"                                      \
  CXXFLAGS="-EHsc $C_OPTS"                                                     \
  CXXCPP="$ROOT_DIR/wrappers/compile icx-cl -E"                                \
  DLLTOOL="link -verbose -dll"                                                 \
  F77="ifx"                                                                    \
  FFLAGS="-f77rtl $F_OPTS"                                                     \
  FC="ifx"                                                                     \
  FCFLAGS="$F_OPTS"                                                            \
  LD="lld-link"                                                                \
  LDFLAGS="-fuse-ld=lld"                                                       \
  MPICC="$ROOT_DIR/wrappers/mpiicl"                                            \
  MPICXX="$ROOT_DIR/wrappers/mpiicl"                                           \
  MPIF77="$ROOT_DIR/wrappers/mpiifx"                                           \
  MPILIBS="-limpi"                                                             \
  NM="dumpbin -nologo -symbols"                                                \
  PKG_CONFIG="/usr/bin/pkg-config"                                             \
  RANLIB=":"                                                                   \
  RC="$ROOT_DIR/wrappers/windres-rc rc -nologo"                                \
  STRIP=":"                                                                    \
  WINDRES="$ROOT_DIR/wrappers/windres-rc rc -nologo"                           \
  ../configure --host="$HOST_TRIPLET"                                          \
    --prefix="$PREFIX"                                                         \
    --enable-shared                                                            \
    --enable-static                                                            \
    --enable-long-double                                                       \
    --enable-mips-zbus-timer                                                   \
    --enable-fma                                                               \
    --enable-mpi                                                               \
    --enable-openmp                                                            \
    --enable-threads                                                           \
    --with-our-malloc                                                          \
    --with-our-malloc16                                                        \
    --with-windows-f77-mangling                                                \
    ac_cv_prog_f77_v="-verbose"                                                \
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
configure_stage1
patch_stage
build_stage
install_stage
configure_stage2
patch_stage
build_stage
install_stage
configure_stage3
patch_stage
build_stage
install_stage
