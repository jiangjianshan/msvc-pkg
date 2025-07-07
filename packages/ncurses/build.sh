#!/bin/bash
#
#  Build script for the current library, it should not be called directly from the
#  command line, but should be called from mpt.py.
#
#  The values of these environment variables come from mpt.py:
#  ARCH            - x64 or x86
#  ROOT_DIR        - root location of msvc-pkg
#  PREFIX          - install location of current library
#  PREFIX_PATH     - install location of third party libraries
#  _PREFIX         - default install location if not list in settings.yaml
#
#  Copyright (c) 2024 Jianshan Jiang
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in all
#  copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#  SOFTWARE.

PKG_NAME=$(yq -r '.name' config.yaml)
PKG_VER=$(yq -r '.version' config.yaml)
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line."
    echo "To build $PKG_NAME and its dependencies, please go to the root location of msvc-pkg, and then press"
    echo "mpt $PKG_NAME"
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
. $ROOT_DIR/compiler.sh $ARCH
PREFIX=$(cygpath -u "$PREFIX")
RELS_DIR=$ROOT_DIR/releases
SRC_DIR=$RELS_DIR/$PKG_NAME-$PKG_VER
BUILD_DIR=$SRC_DIR/build${ARCH//x/}
C_OPTS='-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics'
C_DEFS='-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX'

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
  # NOTE:
  # 1. Don't use CPP="$ROOT_DIR/wrappers/compile cl -nologo -EP" here,
  #    it will cause checking absolute name of standard files is empty.
  #    e.g. checking absolute name of <fcntl.h> ... '', but we can use
  #    CPP="$ROOT_DIR/wrappers/compile cl -nologo -E"
  # 2. Don't use 'compile cl -nologo' but 'compile cl'. Because configure
  #    on some libraries will detect whether is msvc compiler according to
  #    '*cl | cl.exe'
  # 3. with below options, ncurses which version is 6.2 need to add
  #    '--with-shared' configuation option if not use '--disable-curses'
  AR="$ROOT_DIR/wrappers/ar-lib lib -nologo"                                   \
  CC="$ROOT_DIR/wrappers/compile cl"                                           \
  CFLAGS="$C_OPTS"                                                             \
  CPP="$ROOT_DIR/wrappers/compile cl -E"                                       \
  CPPFLAGS="$C_DEFS"                                                           \
  CXX="$ROOT_DIR/wrappers/compile cl"                                          \
  CXXFLAGS="-EHsc $C_OPTS"                                                     \
  CXXCPP="$ROOT_DIR/wrappers/compile cl -E"                                    \
  DLLTOOL="link -verbose -dll"                                                 \
  LD="link -nologo"                                                            \
  LIBS="-lgetopt -lpcre2-posix -luser32"                                       \
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
    --disable-getcap                                                           \
    --disable-hard-tabs                                                        \
    --disable-home-terminfo                                                    \
    --disable-leaks                                                            \
    --disable-macros                                                           \
    --disable-overwrite                                                        \
    --disable-stripping                                                        \
    --disable-termcap                                                          \
    --disable-rpath                                                            \
    --enable-assertions                                                        \
    --enable-colorfgbg                                                         \
    --enable-database                                                          \
    --enable-echo                                                              \
    --enable-exp-win32                                                         \
    --enable-ext-colors                                                        \
    --enable-ext-funcs                                                         \
    --enable-ext-mouse                                                         \
    --enable-ext-putwin                                                        \
    --enable-interop                                                           \
    --enable-opaque-curses                                                     \
    --enable-opaque-form                                                       \
    --enable-opaque-menu                                                       \
    --enable-opaque-panel                                                      \
    --enable-pc-files                                                          \
    --enable-signed-char                                                       \
    --enable-sigwinch                                                          \
    --enable-sp-funcs                                                          \
    --enable-tcap-names                                                        \
    --enable-term-driver                                                       \
    --enable-warnings                                                          \
    --enable-wgetch-events                                                     \
    --with-build-cc="$ROOT_DIR/wrappers/compile cl -nologo"                    \
    --with-build-cflags="$C_OPTS"                                             \
    --with-build-cpp="$ROOT_DIR/wrappers/compile cl -nologo -E"                \
    --with-build-cppflags="-DBUILDING_NCURSES $C_DEFS"                        \
    --with-cxx-shared                                                          \
    --with-fallbacks=ms-terminal                                               \
    --with-form-libname=form                                                   \
    --with-menu-libname=menu                                                   \
    --with-normal                                                              \
    --with-panel-libname=panel                                                 \
    --with-progs                                                               \
    --with-shared                                                              \
    --without-ada                                                              \
    --without-cxx-binding                                                      \
    --without-debug                                                            \
    --without-libtool                                                          \
    --without-manpages                                                         \
    --without-tests                                                            \
    ac_cv_header_getopt_h=yes                                                  \
    ac_cv_func_getopt=yes                                                      \
    ac_cv_header_dirent_dirent_h=yes                                           \
    cf_cv_mb_len_max=yes                                                       \
    gt_cv_locale_zh_CN=none || exit 1
}

patch_stage()
{
  echo "Patching $PKG_NAME $PKG_VER after configure"
  cd "$BUILD_DIR"
  # fix .a to .lib and .dll.a to .lib
  sed                                                                          \
    -e 's|.dll.a|.lib|g'                                                       \
    -i mk_shared_lib.sh

  if [[ -d "c++" ]]; then
    pushd c++
    echo "patching Makefile in c++ folder"
    sed                                                                        \
      -e 's|libform.dll.a|form.lib|g'                                          \
      -e 's|libmenu.dll.a|menu.lib|g'                                          \
      -e 's|libpanel.dll.a|panel.lib|g'                                        \
      -e 's|libformw.dll.a|formw.lib|g'                                        \
      -e 's|libmenuw.dll.a|menuw.lib|g'                                        \
      -e 's|libpanelw.dll.a|panelw.lib|g'                                      \
      -e 's|libncurses.dll.a|ncurses.lib|g'                                    \
      -e 's|libncurses++.a|libncurses++.lib|g'                                 \
      -e 's|libncurses++.dll.a|ncurses++.lib|g'                                \
      -e 's|libncurses++$(ABI_VERSION).dll|ncurses++$(ABI_VERSION).dll|g'      \
      -e 's|libncurses++${ABI_VERSION}.dll|ncurses++${ABI_VERSION}.dll|g'      \
      -e 's|libncursesw.dll.a|ncursesw.lib|g'                                  \
      -e 's|libncursesw++.a|libncursesw++.lib|g'                               \
      -e 's|libncursesw++.dll.a|ncursesw++.lib|g'                              \
      -e 's|libncursesw++$(ABI_VERSION).dll|ncursesw++$(ABI_VERSION).dll|g'    \
      -e 's|libncursesw++${ABI_VERSION}.dll|ncursesw++${ABI_VERSION}.dll|g'    \
      -i Makefile
    popd
  fi

  pushd ncurses
  echo "patching Makefile in ncurses folder"
  sed                                                                          \
    -e 's|libncurses.a|libncurses.lib|g'                                       \
    -e 's|libncurses.dll.a|ncurses.lib|g'                                      \
    -e 's|libncurses$(ABI_VERSION).dll|ncurses$(ABI_VERSION).dll|g'            \
    -e 's|libncurses${ABI_VERSION}.dll|ncurses${ABI_VERSION}.dll|g'            \
    -e 's|libncursesw.a|libncursesw.lib|g'                                     \
    -e 's|libncursesw.dll.a|ncursesw.lib|g'                                    \
    -e 's|libncursesw$(ABI_VERSION).dll|ncursesw$(ABI_VERSION).dll|g'          \
    -e 's|libncursesw${ABI_VERSION}.dll|ncursesw${ABI_VERSION}.dll|g'          \
    -i Makefile
  popd

  pushd form
  echo "patching Makefile in form folder"
  sed                                                                          \
    -e 's|libform.a|libform.lib|g'                                             \
    -e 's|libform.dll.a|form.lib|g'                                            \
    -e 's|libform$(ABI_VERSION).dll|form$(ABI_VERSION).dll|g'                  \
    -e 's|libform${ABI_VERSION}.dll|form${ABI_VERSION}.dll|g'                  \
    -e 's|libformw.a|libformw.lib|g'                                           \
    -e 's|libformw.dll.a|formw.lib|g'                                          \
    -e 's|libformw$(ABI_VERSION).dll|formw$(ABI_VERSION).dll|g'                \
    -e 's|libformw${ABI_VERSION}.dll|formw${ABI_VERSION}.dll|g'                \
    -i Makefile
  popd

  pushd menu
  echo "patching Makefile in menu folder"
  sed                                                                          \
    -e 's|libmenu.a|libmenu.lib|g'                                             \
    -e 's|libmenu.dll.a|menu.lib|g'                                            \
    -e 's|libmenu$(ABI_VERSION).dll|menu$(ABI_VERSION).dll|g'                  \
    -e 's|libmenu${ABI_VERSION}.dll|menu${ABI_VERSION}.dll|g'                  \
    -e 's|libmenuw.a|libmenuw.lib|g'                                           \
    -e 's|libmenuw.dll.a|menuw.lib|g'                                          \
    -e 's|libmenuw$(ABI_VERSION).dll|menuw$(ABI_VERSION).dll|g'                \
    -e 's|libmenuw${ABI_VERSION}.dll|menuw${ABI_VERSION}.dll|g'                \
    -i Makefile
  popd

  pushd panel
  echo "patching Makefile in panel folder"
  sed                                                                          \
    -e 's|libpanel.a|libpanel.lib|g'                                           \
    -e 's|libpanel.dll.a|panel.lib|g'                                          \
    -e 's|libpanel$(ABI_VERSION).dll|panel$(ABI_VERSION).dll|g'                \
    -e 's|libpanel${ABI_VERSION}.dll|panel${ABI_VERSION}.dll|g'                \
    -e 's|libpanelw.a|libpanelw.lib|g'                                         \
    -e 's|libpanelw.dll.a|panelw.lib|g'                                        \
    -e 's|libpanelw$(ABI_VERSION).dll|panelw$(ABI_VERSION).dll|g'              \
    -e 's|libpanelw${ABI_VERSION}.dll|panelw${ABI_VERSION}.dll|g'              \
    -i Makefile
  popd

  if [[ -d "progs" ]]; then
    pushd progs
    echo "patching Makefile in progs folder"
    sed                                                                        \
      -e 's|libncurses.dll.a|ncurses.lib|g'                                    \
      -e 's|libncursesw.dll.a|ncursesw.lib|g'                                  \
      -i Makefile
    popd
  fi

  if [[ -d "test" ]]; then
    pushd "test"
    echo "patching Makefile in test folder"
    sed                                                                        \
      -e 's|libform.dll.a|form.lib|g'                                          \
      -e 's|libmenu.dll.a|menu.lib|g'                                          \
      -e 's|libpanel.dll.a|panel.lib|g'                                        \
      -e 's|libncurses.dll.a|ncurses.lib|g'                                    \
      -e 's|libformw.dll.a|formw.lib|g'                                        \
      -e 's|libmenuw.dll.a|menuw.lib|g'                                        \
      -e 's|libpanelw.dll.a|panelw.lib|g'                                      \
      -e 's|libncursesw.dll.a|ncursesw.lib|g'                                  \
      -i Makefile
    popd
  fi

  pushd misc
  echo "patching Makefile in misc folder"
  sed                                                                          \
    -e 's|dll.a|.lib|g'                                                        \
    -i gen-pkgconfig
  popd
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
  if [[ ! -d "$PREFIX/include/ncurses" ]]; then
    ln -sv "$PREFIX/include/ncursesw" "$PREFIX/include/ncurses"
  fi
  if [[ ! -f "$PREFIX/lib/libncurses.lib" ]]; then
    ln -sv "$PREFIX/lib/libncursesw.lib" "$PREFIX/lib/libncurses.lib"
  fi
  if [[ ! -f "$PREFIX/lib/ncurses.lib" ]]; then
    ln -sv "$PREFIX/lib/ncursesw.lib" "$PREFIX/lib/ncurses.lib"
  fi
  if [[ ! -f "$PREFIX/lib/libform.lib" ]]; then
    ln -sv "$PREFIX/lib/libformw.lib" "$PREFIX/lib/libform.lib"
  fi
  if [[ ! -f "$PREFIX/lib/form.lib" ]]; then
    ln -sv "$PREFIX/lib/formw.lib" "$PREFIX/lib/form.lib"
  fi
  if [[ ! -f "$PREFIX/lib/libmenu.lib" ]]; then
    ln -sv "$PREFIX/lib/libmenuw.lib" "$PREFIX/lib/libmenu.lib"
  fi
  if [[ ! -f "$PREFIX/lib/menu.lib" ]]; then
    ln -sv "$PREFIX/lib/menuw.lib" "$PREFIX/lib/menu.lib"
  fi
  if [[ ! -f "$PREFIX/lib/libpanel.lib" ]]; then
    ln -sv "$PREFIX/lib/libpanelw.lib" "$PREFIX/lib/libpanel.lib"
  fi
  if [[ ! -f "$PREFIX/lib/panel.lib" ]]; then
    ln -sv "$PREFIX/lib/panelw.lib" "$PREFIX/lib/panel.lib"
  fi
  clean_build
}

configure_stage
patch_stage
build_stage
install_package
