#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME-$PKG_VER

echo "Patching package $PKG_NAME $PKG_VER"
cd "$SRC_DIR" || exit 1
rm -rfv autom4te.cache *.tar.gz config.log config.status config.h
find . -name ".deps" -type d -print -exec rm -rfv {} \;
find . -name ".*" -type f -print -exec rm -rfv {} \;
find . -name "Makefile" -type f -print -exec rm -rfv {} \;
find . -name "stamp-*" -type f -print -exec rm -rfv {} \;

echo "Patching Makefile.in in fortran folder"
pushd fortran || exit 1
sed                                                                          \
  -e "s|^AR = ar|AR = $ROOT_DIR/wrappers/ar-lib lib -nologo|g"               \
  -e 's|libarprec_f_main.a|libarprec_f_main|g'                               \
  -e 's|libarprecmod.a|libarprecmod.lib|g'                                   \
  -e 's|libarprec.a|libarprec.lib|g'                                         \
  -i Makefile.in
popd || exit 1

echo "Patching Makefile.in in src folder"
pushd src || exit 1
sed                                                                          \
  -e "s|^AR = ar|AR = $ROOT_DIR/wrappers/ar-lib lib -nologo|g"               \
  -e 's|libarprec.a|libarprec.lib|g'                                         \
  -i Makefile.in
popd || exit 1

echo "Patching Makefile.in in tests folder"
pushd tests || exit 1
sed                                                                          \
  -e 's|libarprec_f_main.a|libarprec_f_main|g'                               \
  -e 's|libarprecmod.a|libarprecmod.lib|g'                                   \
  -e 's|libarprec.a|libarprec.lib|g'                                         \
  -i Makefile.in
popd || exit 1

echo "Patching Makefile.in in toolkit folder"
pushd toolkit || exit 1
sed                                                                          \
  -e 's|libarprec_f_main.a|libarprec_f_main|g'                               \
  -e 's|libarprecmod.a|libarprecmod.lib|g'                                   \
  -e 's|libarprec.a|libarprec.lib|g'                                         \
  -i Makefile.in
popd || exit 1

echo "Patching configure in top level"
sed                                                                          \
  -e "s|-mp|-MP:$(nproc)|g"                                                  \
  -i configure
chmod +x configure
