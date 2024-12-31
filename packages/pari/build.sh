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
  cd "$SRC_DIR" || exit 1
  [[ -d "$BUILD_DIR" ]] && rm -rf "$BUILD_DIR"
  [[ -d "src64" ]] && rm -rf "src64"
  [[ -f "doc/gphelp" ]] && rm -f "doc/gphelp"
  [[ -f "doc/paricfg.tex" ]] && rm -f "doc/paricfg.tex"
  [[ -f "misc/tex2mail" ]] && rm -f "misc/tex2mail"
  [[ -f "src/desc/pari.desc" ]] && rm -f "src/desc/pari.desc"
  find . -type f -name '*.obj' -delete
  find . -type f -name '*.exe' -delete
  find . -type f -name 'Makefile' -delete
  find . -type l -delete
}

configure_stage()
{
  echo "Configuring $PKG_NAME $PKG_VER"
  clean_build
  mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR" || exit 1
  if [[ "$ARCH" == "x86" ]]; then
    HOST_TRIPLET=i686-mingw
  elif [[ "$ARCH" == "x64" ]]; then
    HOST_TRIPLET=x86_64-mingw
  fi
  cd "$SRC_DIR" || exit 1
  # NOTE:
  # 1. Don't use CPP="$ROOT_DIR/wrappers/compile cl -nologo -EP" here,
  #    it will cause checking absolute name of standard files is empty.
  #    e.g. checking absolute name of <fcntl.h> ... '', but we can use
  #    CPP="$ROOT_DIR/wrappers/compile cl -nologo -E"
  # 2. Don't use 'compile cl -nologo' but 'compile cl'. Because configure
  #    on some libraries will detect whether is msvc compiler according to
  #    '*cl | cl.exe'
  AR="$ROOT_DIR/wrappers/ar-lib lib -nologo"                                   \
  CC="$ROOT_DIR/wrappers/compile cl"                                           \
  CFLAGS="$C_OPTS"                                                             \
  CPP="$ROOT_DIR/wrappers/compile cl -E"                                       \
  CPPFLAGS="$C_DEFS"                                                           \
  CXX="$ROOT_DIR/wrappers/compile cl"                                          \
  CXXFLAGS="-EHsc $C_OPTS"                                                     \
  CXXCPP="$ROOT_DIR/wrappers/compile cl -E"                                    \
  DLLTOOL="link.exe -verbose -dll"                                             \
  LD="$ROOT_DIR/wrappers/compile cl"                                           \
  NM="dumpbin -nologo -symbols"                                                \
  PKG_CONFIG="/usr/bin/pkg-config"                                             \
  RANLIB=":"                                                                   \
  RC="$ROOT_DIR/wrappers/windres-rc rc -nologo"                                \
  STRIP=":"                                                                    \
  WINDRES="$ROOT_DIR/wrappers/windres-rc rc -nologo"                           \
  ./Configure --host="$HOST_TRIPLET"                                           \
    --prefix="$PREFIX"                                                         \
    --bindir="$PREFIX/bin"                                                     \
    --includedir="$PREFIX/include"                                             \
    --libdir="$PREFIX/lib"                                                     \
    --builddir="$BUILD_DIR"                                                    \
    --graphic=win32                                                            \
    --time=ftime                                                               \
    --with-readline="$(cygpath -m "${READLINE_PREFIX:-$PREFIX}")"              \
    --with-ncurses-lib="$(cygpath -m "${NCURSES_PREFIX:-$PREFIX}/lib")"        \
    --with-gmp="$(cygpath -m "${GMP_PREFIX:-$PREFIX}")"                        \
    --with-fltk="$(cygpath -m "${FLTK_PREFIX:-$PREFIX}")" || exit 1
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
