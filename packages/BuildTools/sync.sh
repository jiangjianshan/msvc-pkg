#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
RELS_DIR=$ROOT_DIR/releases
SRC_DIR=$RELS_DIR/$PKG_NAME

patch_package()
{
  echo "Patching package $PKG_NAME $PKG_VER"
  cd "$SRC_DIR" || exit 1

  echo "Patching run_autotools in top level"
  sed                                                                          \
    -e '/patch -p1 < BuildTools\/libtool-icl.patch/d'                          \
    -e 's/automake || exit 1/automake --add-missing || exit 1/g'               \
    -i run_autotools
}

patch_package
