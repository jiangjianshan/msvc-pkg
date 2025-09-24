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
  cd "$SRC_DIR" || exit 1

  echo "Patching windows-makefile.tmpl in Configurations"
  pushd Configurations || exit 1
  sed                                                                          \
    -e 's|$(INSTALLTOP)\\html\\|$(INSTALLTOP)\\share\\man\\|g'                 \
    -i windows-makefile.tmpl
  popd || exit 1
}

patch_package
