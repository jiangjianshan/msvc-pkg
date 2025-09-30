#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME
echo "Patching package $PKG_NAME $PKG_VER"
cd "$SRC_DIR" || exit 1
sed -i -r \
-e ':a
$!N
s/(\s*)(build_by_default\s*:\s*false,)\n(\s*\)[^\n]*)/\1\2\n\1name_suffix : '"'"'lib'"'"',\n\3/
t b
P
D
:b
p
d' \
src/meson.build tests/meson.build tools/meson.build
