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
  patch -Np1 -i "$PKG_DIR/001-winpthreads-avoid-other-libraries-report-pid_t-error.diff"

  echo "Patching thread.h in src"
  pushd src || exit 1
  sed                                                                                    \
    -e 's|struct _pthread_v \*WINPTHREAD_API|WINPTHREAD_API struct _pthread_v *|g'       \
    -i thread.h
  popd || exit 1

  # XXX: libtool don't have options can set the naming style of static and
  #      shared library. Here is only a workaround.

  echo "Patching ltmain.sh in build-aux"
  pushd build-aux || exit 1
  sed                                                                                    \
    -e 's|old_library=$libname.$libext|old_library=lib$libname.$libext|g'                \
    -e 's|$output_objdir/$libname.$libext|$output_objdir/lib$libname.$libext|g'          \
    -i ltmain.sh
  popd || exit 1

  echo "Patching configure in top level"
  sed                                                                                    \
    -e 's|.dll.lib|.lib|g'                                                               \
    -i configure
  chmod +x configure
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR mingw-w64-$PKG_VER$EXT 3 mingw-w64-$PKG_VER/mingw-w64-libraries/winpthreads