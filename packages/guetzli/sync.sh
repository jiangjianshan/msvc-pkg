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
  cd "$SRC_DIR"
  sed                                                                          \
    -e 's|shlwapi.lib;%|shlwapi.lib;libpng16.lib;%|g'                          \
    guetzli.vcxproj > guetzli.vcxproj-t
  mv guetzli.vcxproj-t guetzli.vcxproj
}

patch_package
