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
  patch -Np1 -i "$PKG_DIR/001-icu4c-move-DLLs-to-the-bin-directory.diff"
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT

# download and extract data for icu4c
data_url=https://github.com/unicode-org/icu/releases/download/release-$PKG_VER/icu4c-${PKG_VER//-/_}-data.zip
data_archive=$(basename -- "$data_url")
if [[ ! -f "$TAGS_DIR/$data_archive" ]]; then
  if ! wget --no-check-certificate "$data_url" -O "$TAGS_DIR/$data_archive"; then
    echo "Failed to download $data_archive from $data_url"
    exit 1
  fi
fi
if [[ ! -d "$SRC_DIR/source/data/locales" ]]; then
  correct_sha256='a5104212dc317a64f9b035723ea706f2f4fd5a0f37b7923fae7aeb9d1d0061b1'
  if verify_file $data_url "$data_archive" $correct_sha256; then
    if ! extract "$SRC_DIR/source/data" "$data_archive"; then
      echo "Failed to extract $archive into $SRC_DIR/source/data"
      exit 1
    fi
  fi
fi
