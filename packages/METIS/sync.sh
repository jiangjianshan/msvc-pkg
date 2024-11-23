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
ARCHIVE=$(basename "$PKG_URL")
EXT=${ARCHIVE#$(echo "$ARCHIVE" | sed 's/\.[^[:digit:]].*$//g')}

patch_package()
{
  echo "Patching package $PKG_NAME $PKG_VER"
  cd "$SRC_DIR"
  patch -Np1 -i "$PKG_DIR/001-METIS-5.2.1-fix-compile-link-errors.diff"
  pushd "include"
  if [ "$ARCH" == "x86" ]; then
    sed                                                                        \
      -e 's|\/\/#define IDXTYPEWIDTH 32|#define IDXTYPEWIDTH 32|g'             \
      -e 's|\/\/#define REALTYPEWIDTH 32|#define REALTYPEWIDTH 32|g'           \
      metis.h > metis.h-t
    mv metis.h-t metis.h
  else
    sed                                                                        \
      -e 's|\/\/#define IDXTYPEWIDTH 32|#define IDXTYPEWIDTH 64|g'             \
      -e 's|\/\/#define REALTYPEWIDTH 32|#define REALTYPEWIDTH 64|g'           \
      metis.h > metis.h-t
    mv metis.h-t metis.h
  fi
}

. $ROOT_DIR/common.sh
download_extract $PKG_NAME-$PKG_VER$EXT
