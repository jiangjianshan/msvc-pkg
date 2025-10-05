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
C_OPTS='-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -Wno-implicit-function-declaration -Wno-pointer-sign -Xclang -O2 -fms-extensions -fms-hotpatch -fms-compatibility -fms-compatibility-version='${MSC_VER}
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
    -i configure
  chmod +x configure
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
  # NOTE:
  # 1. Don't use CPP="$ROOT_DIR/wrappers/compile cl -nologo -EP" here,
  #    it will cause checking absolute name of standard files is empty.
  #    e.g. checking absolute name of <fcntl.h> ... '', but we can use
  #    CPP="$ROOT_DIR/wrappers/compile cl -nologo -E"
  # 2. Don't use 'compile cl -nologo' but 'compile cl'. Because configure
  #    on some libraries will detect whether is msvc compiler according to
  #    '*cl | cl.exe'
  AR="$ROOT_DIR/wrappers/ar-lib lib -nologo"                                   \
  CC="$ROOT_DIR/wrappers/compile clang-cl"                                     \
  CFLAGS="$C_OPTS"                                                             \
  CPP="$ROOT_DIR/wrappers/compile clang-cl -E"                                 \
  CPPFLAGS="$C_DEFS"                                                           \
  CXX="$ROOT_DIR/wrappers/compile clang-cl"                                    \
  CXXFLAGS="-EHsc $C_OPTS"                                                     \
  CXXCPP="$ROOT_DIR/wrappers/compile clang-cl -E"                              \
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
    --disable-esdtest                                                          \
    --enable-shared                                                            \
    --enable-static                                                            \
    --enable-roar-default-slp                                                  \
    --enable-wmm                                                               \
    --enable-alsa                                                              \
    --enable-alsa-mmap                                                         \
    --enable-broken-oss                                                        \
    --enable-arts                                                              \
    --enable-nas                                                               \
    --enable-pulse                                                             \
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
configure_stage
patch_stage
build_stage
install_stage
