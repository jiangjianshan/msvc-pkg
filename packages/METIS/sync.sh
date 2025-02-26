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
  cd "$SRC_DIR"
  patch -Np1 -i "$PKG_DIR/001-METIS-fix-compile-link-errors.diff"
  patch -Np1 -i "$PKG_DIR/002-METIS-missing-install-target-if-use-ninja.diff"
  # TODO: The better way is to define a function with particular regular expression
  #       in a .cmake to convert the objects files to .def file
  patch -Np1 -i "$PKG_DIR/003-METIS-fix-build-shared-library-on-msvc.diff"

  echo "Patching vsgen.bat in top level"
  sed                                                                          \
    -e 's|-DCMAKE_CONFIGURATION_TYPES=|-DCMAKE_BUILD_TYPE=|g'                  \
    -i 'vsgen.bat'

  # NOTE: ThirdParty-HSL need 'IDXTYPEWIDTH' to 32 but not 64
  pushd "include" || exit 1
  sed                                                                          \
    -e 's|\/\/#define IDXTYPEWIDTH 32|#define IDXTYPEWIDTH 32|g'               \
    -e 's|\/\/#define REALTYPEWIDTH 32|#define REALTYPEWIDTH 32|g'             \
    metis.h > metis.h-t
  mv metis.h-t metis.h
  popd || exit 1
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT
