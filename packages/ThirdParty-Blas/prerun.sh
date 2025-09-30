#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME-$PKG_VER
echo "Patching package $PKG_NAME $PKG_VER"
cd "$ROOT_DIR/releases/BuildTools" || exit 1
export COIN_AUTOTOOLS_DIR=/usr
WANT_AUTOCONF='2.72' WANT_AUTOMAKE='1.17' ./run_autotools $SRC_DIR
cd "$SRC_DIR" || exit 1
if [ ! -f "scopy.f" ]; then
  # NOTE: The archive from 'www.netlib.org/blas/blas.tgz' can't be compile successfully, but
  #       the one from 'coin-or-tools.github.io/ThirdParty-Blas' can.
  ./get.Blas
fi
rm -rfv autom4te.cache
find . -name "*~" -type f -print -exec rm -rfv {} \;
