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

  # Fix install location of files
  echo "Patching coinhsl.pc.in in top level"
  sed                                                                                                \
    -e 's|/coin-or/|/coin/|g'                                                                        \
    -i coinhsl.pc.in

  echo "Patching Makefile.am in top level"
  sed                                                                                                \
    -e 's|/coin-or/|/coin/|g'                                                                        \
    -i Makefile.am

  echo "Patching Makefile.in in top level"
  sed                                                                                                \
    -e 's|/coin-or/|/coin/|g'                                                                        \
    -i Makefile.in
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT

# download old version of coinhsl which is free of charge
coinhsl_url=https://sourceforge.net/projects/csv4students/files/Linux64.BAK/coinhsl-2024.05.15.zip
coinhsl_archive=$(basename -- "$coinhsl_url")
if [[ ! -f "$TAGS_DIR/$coinhsl_archive" ]]; then
  if ! wget --no-check-certificate "$coinhsl_url" -O "$TAGS_DIR/$coinhsl_archive"; then
    echo "Failed to download $coinhsl_archive from $coinhsl_url"
    exit 1
  fi
fi
if [[ ! -d "$SRC_DIR/coinhsl" ]]; then
  correct_sha256='b99e8c117f871cead24648147dfef23d79603a5fff0b37617a12a0570da5d472'
  if verify_file $coinhsl_url "$coinhsl_archive" $correct_sha256; then
    if ! extract "$SRC_DIR/coinhsl" "$coinhsl_archive"; then
      echo "Failed to extract $archive into $SRC_DIR/coinhsl"
      exit 1
    fi
  fi
fi
