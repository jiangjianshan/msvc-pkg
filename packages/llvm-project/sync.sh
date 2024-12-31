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

  # Fix SyntaxWarning invalid escape sequence if use python 3.12
  pushd llvm/utils
  sed                                                                          \
    -e 's|re.match("|re.match(r"|g'                                            \
    extract_symbols.py > extract_symbols.py-t
  mv extract_symbols.py-t extract_symbols.py
  popd
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT
