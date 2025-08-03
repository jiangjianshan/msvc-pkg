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

download_extras()
{
  # download and extract expat
  expat_url=https://github.com/libexpat/libexpat/archive/refs/tags/R_2_4_7.tar.gz
  expat_archive=expat-2.4.7.tar.gz
  if [[ ! -f "$TAGS_DIR/$expat_archive" ]]; then
    if ! wget --no-check-certificate "$expat_url" -O "$TAGS_DIR/$expat_archive"; then
      echo "Failed to download $expat_archive from $expat_url"
      exit 1
    fi
  fi
  if [[ ! -f "$SRC_DIR/third-party/expat/lib/xmlparse.c" ]]; then
    correct_sha256='ddc1111651cdd4095b67c9d9ed46babfb8fb64843d89ff785399f5739b84867b'
    if verify_file $expat_url "$expat_archive" $correct_sha256; then
      if ! extract "$SRC_DIR/third-party/tmp" "$expat_archive"; then
        echo "Failed to extract $expat_archive into $SRC_DIR/third-party/tmp"
        exit 1
      fi
      cp -rv $SRC_DIR/third-party/tmp/expat/lib $SRC_DIR/third-party/expat
      rm -rf $SRC_DIR/third-party/tmp
    fi
  fi

  # download and extract zlib
  zlib_url=https://www.zlib.net/fossils/zlib-1.2.13.tar.gz
  zlib_archive=zlib-1.2.13.tar.gz
  if [[ ! -f "$TAGS_DIR/$zlib_archive" ]]; then
    if ! wget --no-check-certificate "$zlib_url" -O "$TAGS_DIR/$zlib_archive"; then
      echo "Failed to download $zlib_archive from $zlib_url"
      exit 1
    fi
  fi
  if [[ ! -f "$SRC_DIR/third-party/zlib/zlib.h" ]]; then
    correct_sha256='b3a24de97a8fdbc835b9833169501030b8977031bcb54b3b3ac13740f846ab30'
    if verify_file $zlib_url "$zlib_archive" $correct_sha256; then
      if ! extract "$SRC_DIR/third-party/tmp" "$zlib_archive"; then
        echo "Failed to extract $zlib_archive into $SRC_DIR/third-party/tmp"
        exit 1
      fi
      cp -rv $SRC_DIR/third-party/tmp/*.h $SRC_DIR/third-party/zlib
      cp -rv $SRC_DIR/third-party/tmp/*.c $SRC_DIR/third-party/zlib
      rm -rf $SRC_DIR/third-party/tmp
    fi
  fi
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT
