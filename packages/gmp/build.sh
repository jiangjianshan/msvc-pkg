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
# NOTE:
# 1. Don't add '-D_DLL' option. It will cause build shared library of gmp failed.
C_DEFS='-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX'

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

  echo "Patching configure in top level"
  sed                                                                                                \
    -e "s|libname_spec='lib\$name'|libname_spec='\$name'|g"                                          \
    -e 's|\.dll\.lib|.lib|g'                                                                         \
    -e 's|#include "$srcdir\/gmp-h.in"|#include "gmp-h.in"|g'                                        \
    -e 's|#include "$srcdir\/gmp-impl.h"|#include "gmp-impl.h"|g'                                    \
    -e 's|#include \\"$srcdir\/gmp-h.in\\"|#include \\"gmp-h.in\\"|g'                                \
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
    YASM_OBJ_FMT=win32
  elif [[ "$ARCH" == "x64" ]]; then
    HOST_TRIPLET=x86_64-w64-mingw32
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
  AR="$ROOT_DIR/wrappers/ar-lib lib -nologo"                                   \
  AS="yasm -Xvc -f $YASM_OBJ_FMT -rraw -pgas"                                  \
  CC="$ROOT_DIR/wrappers/compile cl"                                           \
  CC_FOR_BUILD="$ROOT_DIR/wrappers/compile cl"                                 \
  CCAS="yasm -Xvc -f $YASM_OBJ_FMT -rraw -pgas"                                \
  CPP="$ROOT_DIR/wrappers/compile cl -E"                                       \
  CPPFLAGS="$C_DEFS -I$SRC_DIR -I$BUILD_DIR"                                   \
  CPP_FOR_BUILD="$ROOT_DIR/wrappers/compile cl -E"                             \
  CXX="$ROOT_DIR/wrappers/compile cl"                                          \
  CXXFLAGS="-EHsc $C_OPTS"                                                     \
  CXXCPP="$ROOT_DIR/wrappers/compile cl -E"                                    \
  DLLTOOL="link -verbose -dll"                                                 \
  LD="link -nologo"                                                            \
  NM="dumpbin -nologo -symbols"                                                \
  PKG_CONFIG="/usr/bin/pkg-config"                                             \
  RANLIB=":"                                                                   \
  RC="$ROOT_DIR/wrappers/windres-rc rc -nologo"                                \
  STRIP=":"                                                                    \
  WINDRES="$ROOT_DIR/wrappers/windres-rc rc -nologo"                           \
  ../configure --host="$HOST_TRIPLET"                                          \
    --prefix="$PREFIX"                                                         \
    --bindir="$PREFIX/bin"                                                     \
    --includedir="$PREFIX/include"                                             \
    --libdir="$PREFIX/lib"                                                     \
    --datarootdir="$PREFIX/share"                                              \
    --enable-cxx                                                               \
    --enable-static                                                            \
    --disable-shared                                                           \
    ac_cv_func_vsnprintf=yes                                                   \
    ac_cv_header_sstream=yes                                                   \
    ac_cv_type_std__locale=yes                                                 \
    gmp_cv_asm_w32=".word"                                                     \
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
    YASM_OBJ_FMT=win32
  elif [[ "$ARCH" == "x64" ]]; then
    HOST_TRIPLET=x86_64-w64-mingw32
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
  AR="$ROOT_DIR/wrappers/ar-lib lib -nologo"                                   \
  AS="yasm -Xvc -f $YASM_OBJ_FMT -rraw -pgas"                                  \
  CC="$ROOT_DIR/wrappers/compile cl"                                           \
  CC_FOR_BUILD="$ROOT_DIR/wrappers/compile cl"                                 \
  CCAS="yasm -Xvc -f $YASM_OBJ_FMT -rraw -pgas"                                \
  CPP="$ROOT_DIR/wrappers/compile cl -E"                                       \
  CPPFLAGS="$C_DEFS -I$SRC_DIR -I$BUILD_DIR"                                   \
  CPP_FOR_BUILD="$ROOT_DIR/wrappers/compile cl -E"                             \
  CXX="$ROOT_DIR/wrappers/compile cl"                                          \
  CXXFLAGS="-EHsc $C_OPTS"                                                     \
  CXXCPP="$ROOT_DIR/wrappers/compile cl -E"                                    \
  DLLTOOL="link -verbose -dll"                                                 \
  LD="link -nologo"                                                            \
  NM="dumpbin -nologo -symbols"                                                \
  PKG_CONFIG="/usr/bin/pkg-config"                                             \
  RANLIB=":"                                                                   \
  RC="$ROOT_DIR/wrappers/windres-rc rc -nologo"                                \
  STRIP=":"                                                                    \
  WINDRES="$ROOT_DIR/wrappers/windres-rc rc -nologo"                           \
  ../configure --host="$HOST_TRIPLET"                                          \
    --prefix="$PREFIX"                                                         \
    --bindir="$PREFIX/bin"                                                     \
    --includedir="$PREFIX/include"                                             \
    --libdir="$PREFIX/lib"                                                     \
    --datarootdir="$PREFIX/share"                                              \
    --enable-cxx                                                               \
    --enable-shared                                                            \
    --disable-static                                                           \
    ac_cv_func_vsnprintf=yes                                                   \
    ac_cv_header_sstream=yes                                                   \
    ac_cv_type_std__locale=yes                                                 \
    gmp_cv_asm_w32=".word"                                                     \
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
