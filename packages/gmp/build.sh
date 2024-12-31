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
C_OPTS='-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm'
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
  CPPFLAGS="$C_DEFS -I$SRC_DIR -I$BUILD_DIR"                                    \
  CPP_FOR_BUILD="$ROOT_DIR/wrappers/compile cl -E"                             \
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
    gt_cv_locale_zh_CN=none
  [[ $? -ne 0 ]] && exit 1
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
build_stage
install_package