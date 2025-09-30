#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME
echo "Patching package $PKG_NAME $PKG_VER"
cd "$SRC_DIR" || exit 1
echo "Patching configure in top level"
sed                                                                            \
  -e 's|IMPLIBNAME=libx264\.dll\.lib|IMPLIBNAME=x264.lib|g'                    \
  -e 's|SONAME=libx264-$API\.dll|SONAME=x264-$API.dll|g'                       \
  -i configure
chmod +x configure
