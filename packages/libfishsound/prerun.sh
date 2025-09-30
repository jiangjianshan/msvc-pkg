#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME-$PKG_VER
echo "Patching package $PKG_NAME $PKG_VER"
cd "$SRC_DIR" || exit 1
# NOTE: In order to msvc can build shared library, configure and ltmain.sh files
#       need to be updated.
WANT_AUTOCONF='2.69' WANT_AUTOMAKE='1.16' autoreconf -ifv
rm -rfv autom4te.cache
find . -name "*~" -type f -print -exec rm -rfv {} \;