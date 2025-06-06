#!/bin/bash
#
#  Script used to synchronize library source code, called by mpt.py directly
#  before calling the build script
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

LANG=en_US
export LANG

PKG_NAME=$(yq -r '.name' config.yaml)
PKG_VER=$(yq -r '.version' config.yaml)
PKG_URL=$(yq -r '.url' config.yaml)
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.py directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
PKG_DIR=$ROOT_DIR/packages/$PKG_NAME
RELS_DIR=$ROOT_DIR/releases
TAGS_DIR=$ROOT_DIR/tags
SRC_DIR=$RELS_DIR/$PKG_NAME-$PKG_VER
ARCHIVE=$(basename -- "$PKG_URL")
EXT=${ARCHIVE#$(echo "$ARCHIVE" | sed 's/\.[^[:digit:]].*$//g')}

patch_package()
{
  echo "Patching package $PKG_NAME $PKG_VER"
  cd "$SRC_DIR" || exit 1

  rm -rfv autom4te.cache *.tar.gz config.log config.status config.h
  find . -name ".deps" -type d -print -exec rm -rfv {} \;
  find . -name ".*" -type f -print -exec rm -rfv {} \;
  find . -name "Makefile" -type f -print -exec rm -rfv {} \;
  find . -name "stamp-*" -type f -print -exec rm -rfv {} \;

  echo "Patching Makefile.in in fortran folder"
  pushd fortran || exit 1
  sed                                                                          \
    -e "s|^AR = ar|AR = $ROOT_DIR/wrappers/ar-lib lib -nologo|g"               \
    -e 's|libarprec_f_main.a|libarprec_f_main|g'                               \
    -e 's|libarprecmod.a|libarprecmod.lib|g'                                   \
    -e 's|libarprec.a|libarprec.lib|g'                                         \
    -i Makefile.in
  popd || exit 1

  echo "Patching Makefile.in in src folder"
  pushd src || exit 1
  sed                                                                          \
    -e "s|^AR = ar|AR = $ROOT_DIR/wrappers/ar-lib lib -nologo|g"               \
    -e 's|libarprec.a|libarprec.lib|g'                                         \
    -i Makefile.in
  popd || exit 1

  echo "Patching Makefile.in in tests folder"
  pushd tests || exit 1
  sed                                                                          \
    -e 's|libarprec_f_main.a|libarprec_f_main|g'                               \
    -e 's|libarprecmod.a|libarprecmod.lib|g'                                   \
    -e 's|libarprec.a|libarprec.lib|g'                                         \
    -i Makefile.in
  popd || exit 1

  echo "Patching Makefile.in in toolkit folder"
  pushd toolkit || exit 1
  sed                                                                          \
    -e 's|libarprec_f_main.a|libarprec_f_main|g'                               \
    -e 's|libarprecmod.a|libarprecmod.lib|g'                                   \
    -e 's|libarprec.a|libarprec.lib|g'                                         \
    -i Makefile.in
  popd || exit 1

  echo "Patching configure in top level"
  sed                                                                          \
    -e "s|-mp|-MP:$(nproc)|g"                                                  \
    -i configure
  chmod +x configure
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT
