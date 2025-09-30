#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME-$PKG_VER
echo "Patching package $PKG_NAME $PKG_VER"
cd "$SRC_DIR" || exit 1
echo "Patching libvvdec.pc.in in pkgconfig"
pushd pkgconfig || exit 1
sed                                                                          \
  -e 's| -lstdc++ -lm||g'                                                    \
  -i libvvdec.pc.in
popd || exit 1