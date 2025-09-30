#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME
echo "Patching package $PKG_NAME $PKG_VER"
cd "$SRC_DIR" || exit 1
python utils/git-sync-deps

echo "Patching CMakeLists.txt on top level"
sed                                                                                                \
  -e 's|set(${PATH} ${TARGET}/cmake)|set(${PATH} ${CMAKE_INSTALL_LIBDIR}/cmake/${TARGET})|g'       \
  -i CMakeLists.txt