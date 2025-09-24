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
  cd "$SRC_DIR" || exit 1
  WANT_AUTOCONF='2.69' WANT_AUTOMAKE='1.16' ./autogen.sh
  rm -rfv autom4te.cache
  find . -name "*~" -type f -print -exec rm -rfv {} \;
}

patch_package
