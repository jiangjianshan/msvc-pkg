#!/bin/bash
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

  echo "Patching pkg_config.cmake in build/cmake"
  pushd build/cmake || exit 1
  sed                                                                          \
    -e 's| -lm||g'                                                             \
    -i pkg_config.cmake
  popd || exit 1
}

patch_package
