#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME-$PKG_VER
echo "Patching package $PKG_NAME $PKG_VER"
cd "$SRC_DIR" || exit 1
pushd "build/VS2010/libzstd-dll" || exit 1
sed                                                                          \
  -e 's|#include "zstd.h"|#include "../../../lib/zstd.h"|g'                  \
  libzstd-dll.rc > libzstd-dll.rc-t
mv libzstd-dll.rc-t libzstd-dll.rc
popd || exit 1