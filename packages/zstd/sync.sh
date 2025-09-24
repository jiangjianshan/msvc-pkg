#!/bin/bash
#
#  Script used to synchronize library source code after patch via .diff but before build script run
#
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
RELS_DIR=$ROOT_DIR/releases
SRC_DIR=$RELS_DIR/$PKG_NAME-$PKG_VER

patch_package()
{
  echo "Patching package $PKG_NAME $PKG_VER"
  cd "$SRC_DIR"
  pushd "build/VS2010/libzstd-dll"
  sed                                                                          \
    -e 's|#include "zstd.h"|#include "../../../lib/zstd.h"|g'                  \
    libzstd-dll.rc > libzstd-dll.rc-t
  mv libzstd-dll.rc-t libzstd-dll.rc
  popd
}

patch_package
