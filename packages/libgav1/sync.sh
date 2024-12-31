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
  cd "$ROOT_DIR"
  ABSEIL_CPP_VER=$(yq -r ".$ARCH.abseil-cpp.version" installed.yaml)
  ABSEIL_CPP_SRC="$RELS_DIR/abseil-cpp-$ABSEIL_CPP_VER"
  echo "Source directory of abseil-cpp: $ABSEIL_CPP_SRC"
  cd "$SRC_DIR"
  patch -Np1 -i "$PKG_DIR/001-libgav1-compile-on-msvc.diff"

  [[ ! -d "third_party" ]] && mkdir -p third_party
  if [[ ! -d "$SRC_DIR/third_party/abseil-cpp" ]]; then
      ln -sv "$ABSEIL_CPP_SRC" "$SRC_DIR/third_party/abseil-cpp"
  fi
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT
