#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME-$PKG_VER
echo "Patching package $PKG_NAME $PKG_VER"
cd "$SRC_DIR" || exit 1
echo "Patching CMakeLists.txt in BLACS/INSTALL folder"
pushd BLACS/INSTALL || exit 1
sed                                                                          \
  -e 's|VERSION 2.8|VERSION 3.9|g'                                           \
  -i CMakeLists.txt
popd || exit 1