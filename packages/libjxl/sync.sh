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
  cd "$ROOT_DIR"
  SJPEG_SRC="$RELS_DIR/sjpeg"
  echo "Source directory of sjpeg: $SJPEG_SRC"
  if [[ -d "$SRC_DIR/third_party/sjpeg" ]]; then
    rm -rf "$SRC_DIR/third_party/sjpeg"
  fi
  ln -sv "$SJPEG_SRC" "$SRC_DIR/third_party/sjpeg"
}

patch_package
