#!/bin/bash

LANG=en_US
export LANG

ROOT_DIR=$(cygpath -u "$ROOT_DIR")
PKG_NAME=$(yq -r '.name' config.yaml)
PKG_VER=$(yq -r '.version' config.yaml)
PKG_URL=$(yq -r '.url' config.yaml)
PKG_DIR=$ROOT_DIR/packages/$PKG_NAME
RELS_DIR=$ROOT_DIR/releases
TAGS_DIR=$ROOT_DIR/tags
SRC_DIR=$RELS_DIR/$PKG_NAME-$PKG_VER
ARCHIVE=$(basename -- "$PKG_URL")
EXT=${ARCHIVE#$(echo "$ARCHIVE" | sed 's/\.[^[:digit:]].*$//g')}

patch_package()
{
  echo "Patching package $PKG_NAME $PKG_VER"
  cd "$SRC_DIR" || exit 1
  patch -Np1 -i "$PKG_DIR/001-CoinUtils-fix-pkgconfig-path-syntax-error.diff"

  # NOTE: To fix the extension of library from .a to .lib
  echo "Patching configure in the top level"
  sed                                                                          \
    -e 's/ICL\*)/ICL\* | \*mpicl)/g'                                           \
    -i configure
  chmod +x configure

  echo "Patching configure in the CoinUtils"
  pushd CoinUtils || exit 1
  sed                                                                          \
    -e 's/ICL\*)/ICL\* | \*mpicl)/g'                                           \
    -i configure
  chmod +x configure
  popd || exit 1
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT
