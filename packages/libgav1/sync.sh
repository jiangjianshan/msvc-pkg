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
  cd "$ROOT_DIR" || exit 1
  ABSEIL_CPP_VER=$(yq -r ".$ARCH.abseil-cpp.version" installed.yaml)
  ABSEIL_CPP_SRC="$RELS_DIR/abseil-cpp-$ABSEIL_CPP_VER"
  echo "Source directory of abseil-cpp: $ABSEIL_CPP_SRC"

  cd "$SRC_DIR" || exit 1
  [[ ! -d "third_party" ]] && mkdir -p third_party
  if [[ ! -d "$SRC_DIR/third_party/abseil-cpp" ]]; then
      ln -sv "$ABSEIL_CPP_SRC" "$SRC_DIR/third_party/abseil-cpp"
  fi
}

patch_package
