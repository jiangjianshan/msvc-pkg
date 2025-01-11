#!/bin/bash

LANG=en_US
export LANG

ROOT_DIR=$(cygpath -u "$ROOT_DIR")
PKG_NAME=$(yq -r '.name' config.yaml)
PKG_VER=$(yq -r '.version' config.yaml)
PKG_URL=$(yq -r '.url' config.yaml)
PKG_DIR=$ROOT_DIR/packages/$PKG_NAME
RELS_DIR=$ROOT_DIR/releases
TAGS_DIR=$ROOT_DIR/tags
SRC_DIR=$RELS_DIR/$PKG_NAME-$PKG_VER
ARCHIVE=$(basename -- "$PKG_URL")
EXT=${ARCHIVE#$(echo "$ARCHIVE" | sed 's/\.[^[:digit:]].*$//g')}

patch_package()
{
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
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT
