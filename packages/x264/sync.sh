#!/bin/bash

LANG=en_US
export LANG

ROOT_DIR=$(cygpath -u "$ROOT_DIR")
PKG_NAME=$(yq -r '.name' config.yaml)
PKG_VER=$(yq -r '.version' config.yaml)
PKG_URL=$(yq -r '.url' config.yaml)
PKG_DIR=$ROOT_DIR/packages/$PKG_NAME
RELS_DIR=$ROOT_DIR/releases
SRC_DIR=$RELS_DIR/$PKG_NAME

patch_package()
{
  echo "Patching package $PKG_NAME $PKG_VER"
  cd "$SRC_DIR"

  echo "Patching configure in top level"
  sed                                                                          \
    -e 's|IMPLIBNAME=libx264.dll.lib|IMPLIBNAME=x264.lib|g'                    \
    -e 's|SONAME=libx264-$API.dll|SONAME=x264-$API.dll|g'                      \
    -i configure
  chmod +x configure
}

. $ROOT_DIR/common.sh
git_sync $PKG_URL $SRC_DIR $PKG_NAME $PKG_VER
patch_package
