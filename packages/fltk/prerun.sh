#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME-$PKG_VER
echo "Patching package $PKG_NAME $PKG_VER"
cd "$SRC_DIR" || exit 1
echo "Patching setup.cmake in CMake"
pushd CMake || exit 1
sed                                                                                    \
  -e 's|FLTK_CONFIG_PATH CMake|FLTK_CONFIG_PATH lib/cmake/${PROJECT_NAME}|g'           \
  -i setup.cmake
popd || exit 1
