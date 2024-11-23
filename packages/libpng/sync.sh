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

  # Fix some files are missing installed on Win32 platform
  echo "Patching CMakeLists.txt in top level"
  sed                                                                          \
    -e 's|NOT WIN32 OR CYGWIN|WIN32 OR CYGWIN|g'                               \
    -e 's|NOT CMAKE_HOST_WIN32 OR CYGWIN|CMAKE_HOST_WIN32 OR CYGWIN|g'         \
    -e 's|-lz -lm|-lz|g'                                                       \
    CMakeLists.txt > CMakeLists.txt-t
  mv CMakeLists.txt-t CMakeLists.txt
}

. $ROOT_DIR/common.sh
download_extract $PKG_NAME-$PKG_VER$EXT
