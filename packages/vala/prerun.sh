#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME-$PKG_VER
echo "Patching package $PKG_NAME $PKG_VER"
cd "$SRC_DIR" || exit 1
pushd gobject-introspection || exit 1
echo "Patching Makefile.am in gobject-introspection"
sed                                                                                                \
  -e 's|pkglibexecdir = $(libdir)/vala@PACKAGE_SUFFIX@|pkglibexecdir = \$(libdir)|g'               \
  -i Makefile.am
echo "Patching Makefile.in in gobject-introspection"
sed                                                                                                \
  -e 's|pkglibexecdir = $(libdir)/vala@PACKAGE_SUFFIX@|pkglibexecdir = \$(libdir)|g'               \
  -i Makefile.in
popd || exit 1

WANT_AUTOCONF='2.69' WANT_AUTOMAKE='1.16' autoreconf -ifv
rm -rfv autom4te.cache
find . -name "*~" -type f -print -exec rm -rfv {} \;
