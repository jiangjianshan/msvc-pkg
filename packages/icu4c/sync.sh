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
  patch -Np1 -i "$PKG_DIR/001-icu4c-move-DLLs-to-the-bin-directory.diff"
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT

# download and extract data for icu4c
data_url=https://github.com/unicode-org/icu/releases/download/release-$PKG_VER/icu4c-${PKG_VER//-/_}-data.zip
data_archive=$(basename -- "$data_url")
if [[ ! -f "$TAGS_DIR/$data_archive" ]]; then
  if ! wget --no-check-certificate "$data_url" -O "$TAGS_DIR/$data_archive"; then
    echo "Failed to download $data_archive from $data_url"
    exit 1
  fi
fi
if [[ ! -d "$SRC_DIR/source/data/locales" ]]; then
  correct_sha256='a5104212dc317a64f9b035723ea706f2f4fd5a0f37b7923fae7aeb9d1d0061b1'
  if verify_file $data_url "$data_archive" $correct_sha256; then
    if ! extract "$SRC_DIR/source" "$data_archive"; then
      echo "Failed to extract $archive into $dest_dir"
      exit 1
    fi
  fi
fi
