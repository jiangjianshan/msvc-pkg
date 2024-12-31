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
C_OPTS='-nologo -MD -diagnostics:column -wd4819 -wd4996 -wd4430 -fp:precise -openmp:llvm'
C_DEFS='-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS'

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
    YASM_OBJ_FMT=win32
  elif [[ "$ARCH" == "x64" ]]; then
    HOST_TRIPLET=x86_64-w64-mingw32
    YASM_OBJ_FMT=win64
  fi
  # Issue: 'Warning: linker path does not have real file for library -ljpeg'.
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
  AS="yasm -Xvc -f $YASM_OBJ_FMT -rraw -pgas"                                  \
  CC="$ROOT_DIR/wrappers/compile cl"                                           \
  CFLAGS="$C_OPTS"                                                             \
  CPP="$ROOT_DIR/wrappers/compile cl -E"                                       \
  CPPFLAGS="$C_DEFS -I$SRC_DIR"                                                 \
  CXX="$ROOT_DIR/wrappers/compile cl"                                          \
  CXXFLAGS="-EHsc $C_OPTS"                                                     \
  CXXCPP="$ROOT_DIR/wrappers/compile cl -E"                                    \
  DLLTOOL="link.exe -verbose -dll"                                             \
  LD="link -nologo"                                                            \
  NM="dumpbin -nologo -symbols"                                                \
  PKG_CONFIG="/usr/bin/pkg-config"                                             \
  RANLIB=":"                                                                   \
  RC="$ROOT_DIR/wrappers/windres-rc rc -nologo"                                \
  STRIP=":"                                                                    \
  WINDRES="$ROOT_DIR/wrappers/windres-rc rc -nologo"                           \
  ../configure --build="$(sh ../config.guess)"                                 \
    --host="$HOST_TRIPLET"                                                     \
    --prefix="$PREFIX"                                                         \
    --bindir="$PREFIX/bin"                                                     \
    --includedir="$PREFIX/include"                                             \
    --libdir="$PREFIX/lib"                                                     \
    --datarootdir="$PREFIX/share"                                              \
    --enable-static                                                            \
    --enable-shared                                                            \
    --with-x=no                                                                \
    --with-ffmpeg=no                                                           \
    gt_cv_locale_zh_CN=none || exit 1
}

patch_stage()
{
  echo "Patching $PKG_NAME $PKG_VER after configure"
  cd "$BUILD_DIR"
  # FIXME:
  # To solve following issue
  # libtool: warning: undefined symbols not allowed in x86_64-w64-mingw32 shared libraries; building static only
  echo "Patching libtool in top level"
  sed                                                                          \
    -e "s/\(allow_undefined=\)yes/\1no/"                                       \
    -i libtool
  chmod +x libtool
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
patch_stage
build_stage
install_package