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
C_DEFS='-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX -DYY_NO_UNISTD_H'

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
  # Issue: 'Warning: linker path does not have real file for library -lShell32'.
  # The reason should be in the function of func_win32_libid in ltmain.sh. It use OBJDUMP
  # which is missing from MSVC. That will cause the value of win32_libid_type is unknown.
  # There are at least two way to solve this issue:
  # 1. set OBJDUMP=llvm-objdump
  # 2. set lt_cv_deplibs_check_method as below
  export lt_cv_deplibs_check_method=${lt_cv_deplibs_check_method='pass_all'}
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
  CC="$ROOT_DIR/wrappers/compile cl"                                           \
  CFLAGS="$C_OPTS"                                                             \
  CPP="$ROOT_DIR/wrappers/compile cl -E"                                       \
  CPPFLAGS="$C_DEFS -I${NCURSES_PREFIX:-$PREFIX}/include/ncurses"              \
  DLLTOOL="link.exe -verbose -dll"                                             \
  LD="link -nologo"                                                            \
  LIBS="-lShell32 -lzdll -licuuc -licuin -llibsqlite3"                         \
  LT_SYS_LIBRARY_PATH="$(cygpath -u "$PREFIX")"                                \
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
    --enable-static                                                            \
    --enable-shared                                                            \
    --with-included-ltdl                                                       \
    --with-sco                                                                 \
    --with-sqlite3="$(cygpath -u "${SQLITE_PREFIX:-$PREFIX}")"                 \
    --with-ncurses="$(cygpath -u "${NCURSES_PREFIX:-$PREFIX}")"                \
    --with-universal-ctags=ctags                                               \
    ac_header_dirent=dirent.h                                                  \
    ac_cv_header_dirent_h=yes                                                  \
    ac_cv_func_closedir=yes                                                    \
    ac_cv_func_opendir=yes                                                     \
    ac_cv_func_readdir=yes                                                     \
    ac_cv_func_snprintf=yes                                                    \
    gt_cv_locale_zh_CN=none || exit 1
}

patch_stage()
{
  echo "Patching $PKG_NAME $PKG_VER after configure"
  cd "$BUILD_DIR"

  echo "Patching Makefile libdb"
  pushd libdb || exit 1
  sed                                                                          \
    -e 's|libglodb\.a|libglodb\.lib|g'                                         \
    -i Makefile
  popd || exit 1

  echo "Patching Makefile in libglibc"
  pushd libglibc || exit 1
  sed                                                                          \
    -e 's|libgloglibc\.a|libgloglibc\.lib|g'                                   \
    -i Makefile
  popd || exit 1

  echo "Patching Makefile in libparser"
  pushd libparser || exit 1
  sed                                                                          \
    -e 's|libgloparser\.a|libgloparser\.lib|g'                                 \
    -i Makefile
  popd || exit 1

  echo "Patching Makefile in libutil"
  pushd libutil || exit 1
  sed                                                                          \
    -e 's|libgloutil\.a|libgloutil\.lib|g'                                     \
    -i Makefile
  popd || exit 1

}

build_stage()
{
  echo "Building $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" || exit 1
  if ! make -j$(nproc); then
    exit 1
  fi
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
