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
  patch -Np1 -i "$PKG_DIR/001-icu4c-75-1-move-DLLs-to-the-bin-directory.diff"

  # download and extract data for icu4c
  local data_url=https://github.com/unicode-org/icu/releases/download/release-$PKG_VER/icu4c-${PKG_VER//-/_}-data.zip
  local data_archive=$(basename "$data_url")
  cd "$TAGS_DIR"
  if [[ ! -f "$data_archive" ]]; then
    wget --no-check-certificate "$data_url" -O "$data_archive"
  fi
  echo "Extracting $data_archive"
  unzip -q -o "$data_archive" -d "$SRC_DIR/source"
  echo "Done"
}

. $ROOT_DIR/common.sh
download_extract $PKG_NAME-$PKG_VER$EXT
