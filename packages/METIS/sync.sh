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
  cd "$SRC_DIR"
  patch -Np1 -i "$PKG_DIR/001-METIS-fix-compile-link-errors.diff"
  patch -Np1 -i "$PKG_DIR/002-METIS-missing-install-target-if-use-ninja.diff"

  pushd "include" || exit 1
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
  popd || exit 1
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT
