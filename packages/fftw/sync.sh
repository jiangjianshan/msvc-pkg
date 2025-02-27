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
  patch -Np1 -i "$PKG_DIR/001-fftw-compile-on-msvc.diff"

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

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT
