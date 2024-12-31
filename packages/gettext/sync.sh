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

  # XXX: libtool don't have options can set the naming style of static and
  #      shared library. Here is only a workaround.

  echo "Patching ltmain.sh in build-aux"
  pushd build-aux || exit 1
  sed                                                                                                \
    -e 's|old_library=$libname.$libext|old_library=lib$libname.$libext|g'                            \
    -e 's|$output_objdir/$libname.$libext|$output_objdir/lib$libname.$libext|g'                      \
    -i ltmain.sh
  popd || exit 1

  echo "Patching ltmain.sh in gettext-tools/examples/hello-c++-kde/admin"
  pushd gettext-tools/examples/hello-c++-kde/admin || exit 1
  sed                                                                                                \
    -e 's|old_library=$libname.$libext|old_library=lib$libname.$libext|g'                            \
    -e 's|$output_objdir/$libname.$libext|$output_objdir/lib$libname.$libext|g'                      \
    -i ltmain.sh
  popd || exit 1

  echo "Patching ltmain.sh in libtextstyle/build-aux"
  pushd libtextstyle/build-aux || exit 1
  sed                                                                                                \
    -e 's|old_library=$libname.$libext|old_library=lib$libname.$libext|g'                            \
    -e 's|$output_objdir/$libname.$libext|$output_objdir/lib$libname.$libext|g'                      \
    -i ltmain.sh
  popd || exit 1

  echo "Patching configure in top level"
  sed                                                                                                \
    -e 's|.dll.def|.def|g'                                                                           \
    -e 's|.dll.lib|.lib|g'                                                                           \
    -i configure
  chmod +x configure

  echo "Patching configure in gettext-runtime"
  pushd gettext-runtime || exit 1
  sed                                                                                                \
    -e 's|.dll.def|.def|g'                                                                           \
    -e 's|.dll.lib|.lib|g'                                                                           \
    -i configure
  chmod +x configure
  popd || exit 1

  echo "Patching configure in gettext-runtime/intl"
  pushd gettext-runtime/intl || exit 1
  sed                                                                                                \
    -e 's|.dll.def|.def|g'                                                                           \
    -e 's|.dll.lib|.lib|g'                                                                           \
    -i configure
  chmod +x configure
  popd || exit 1

  echo "Patching configure in gettext-runtime/libasprintf"
  pushd gettext-runtime/libasprintf || exit 1
  sed                                                                                                \
    -e 's|.dll.def|.def|g'                                                                           \
    -e 's|.dll.lib|.lib|g'                                                                           \
    -i configure
  chmod +x configure
  popd || exit 1

  echo "Patching configure in gettext-tools"
  pushd gettext-tools || exit 1
  sed                                                                                                \
    -e 's|.dll.def|.def|g'                                                                           \
    -e 's|.dll.lib|.lib|g'                                                                           \
    -i configure
  chmod +x configure
  popd || exit 1

  echo "Patching configure in gettext-tools/examples"
  pushd gettext-tools/examples || exit 1
  sed                                                                                                \
    -e 's|.dll.def|.def|g'                                                                           \
    -e 's|.dll.lib|.lib|g'                                                                           \
    -i configure
  chmod +x configure
  popd || exit 1

  echo "Patching configure in libtextstyle"
  pushd libtextstyle || exit 1
  sed                                                                                                \
    -e 's|.dll.def|.def|g'                                                                           \
    -e 's|.dll.lib|.lib|g'                                                                           \
    -i configure
  chmod +x configure
  popd || exit 1
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT
