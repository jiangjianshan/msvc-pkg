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
  patch -Np1 -i "$PKG_DIR/001-fftw-compile-on-msvc.diff"

  # XXX: libtool don't have options can set the naming style of static and
  #      shared library. Here is only a workaround.

  echo "Patching ltmain.sh at top level"
  sed                                                                                    \
    -e 's|old_library=$libname.$libext|old_library=lib$libname.$libext|g'                \
    -e 's|$output_objdir/$libname.$libext|$output_objdir/lib$libname.$libext|g'          \
    -i ltmain.sh

  # NOTE: The library_names_spec is not correct because it contains .dll name. This will also cause
  #       the shared library will be converted to symbolic link as .dll file. This issue can be solved
  #       by changed '*,cl*)' to '*,cl| *,ifort*)'
  echo "Patching configure in top level"
  sed                                                                                    \
    -e "s|libname_spec='lib\$name'|libname_spec='\$name'|g"                              \
    -e "s|.dll.lib|.lib|g"                                                               \
    -e 's/\*,cl\*)/\*,cl\* | \*,ifort\*)/g'                                              \
    -i configure
  chmod +x configure
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT
