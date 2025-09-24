#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
RELS_DIR=$ROOT_DIR/releases
SRC_DIR=$RELS_DIR/$PKG_NAME-$PKG_VER

patch_package()
{
  echo "Patching package $PKG_NAME $PKG_VER"
  cd "$SRC_DIR" || exit 1

  # XXX: libtool don't have options can set the naming style of static and
  #      shared library. Here is only a workaround.

  echo "Patching ltmain.sh in top level"
  sed                                                                                                \
    -e 's|old_library=$libname\.$libext|old_library=lib$libname.$libext|g'                           \
    -e 's|$output_objdir/$libname\.$libext|$output_objdir/lib$libname.$libext|g'                     \
    -i ltmain.sh

  echo "Patching configure in top level"
  sed                                                                                                \
    -e "s|libname_spec='lib\$name'|libname_spec='\$name'|g"                                          \
    -e 's|\.dll\.lib|.lib|g'                                                                         \
    -e 's|libglodb\.a|libglodb.lib|g'                                                                \
    -e 's|libdb\.a|libdb.lib|g'                                                                      \
    -e 's|libgloparser\.a|libgloparser.lib|g'                                                        \
    -e 's|libgloutil\.a|libgloutil.lib|g'                                                            \
    -e 's|libgloglibc\.a|libgloglibc.lib|g'                                                          \
    -e 's|lib/libsqlite3\.so|bin/sqlite3.dll|g'                                                      \
    -e 's|lib/libsqlite3\.dylib|lib/libsqlite3.lib|g'                                                \
    -i configure
  chmod +x configure
}

patch_package
