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

  echo "Patching ltmain.sh in top level"
  sed                                                                                                \
    -e 's|old_library=$libname\.$libext|old_library=lib$libname\.$libext|g'                          \
    -e 's|$output_objdir/$libname\.$libext|$output_objdir/lib$libname\.$libext|g'                    \
    -i ltmain.sh

  echo "Patching configure in top level"
  sed                                                                                                \
    -e 's|\.dll\.lib|\.lib|g'                                                                        \
    -i configure
  chmod +x configure
}

. $ROOT_DIR/common.sh
wget_sync $PKG_URL $SRC_DIR $PKG_NAME-$PKG_VER$EXT

# download old version of coinhsl which is free of charge
coinhsl_url=https://sourceforge.net/projects/csv4students/files/Linux64.BAK/coinhsl-2024.05.15.zip
coinhsl_archive=$(basename -- "$coinhsl_url")
if [[ ! -f "$TAGS_DIR/$coinhsl_archive" ]]; then
  if ! wget --no-check-certificate "$coinhsl_url" -O "$TAGS_DIR/$coinhsl_archive"; then
    echo "Failed to download $coinhsl_archive from $coinhsl_url"
    exit 1
  fi
fi
if [[ ! -d "$SRC_DIR/coinhsl" ]]; then
  correct_sha256='b99e8c117f871cead24648147dfef23d79603a5fff0b37617a12a0570da5d472'
  if verify_file $coinhsl_url "$coinhsl_archive" $correct_sha256; then
    if ! extract "$SRC_DIR/coinhsl" "$coinhsl_archive"; then
      echo "Failed to extract $archive into $SRC_DIR/coinhsl"
      exit 1
    fi
  fi
fi
