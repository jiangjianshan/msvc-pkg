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
  cd "$RELS_DIR/BuildTools" || exit 1
  export COIN_AUTOTOOLS_DIR=/usr
  WANT_AUTOCONF='2.72' WANT_AUTOMAKE='1.17' ./run_autotools $SRC_DIR/Bcps

  cd "$SRC_DIR" || exit 1
  rm -rfv Bcps/autom4te.cache
  find . -name "*~" -type f -print -exec rm -rfv {} \;
}

patch_package
