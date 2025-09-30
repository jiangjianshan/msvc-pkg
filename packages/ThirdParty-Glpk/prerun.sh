#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME
echo "Patching package $PKG_NAME $PKG_VER"
cd "$SRC_DIR" || exit 1
if [ ! -d "glpk" ]; then
  ./get.Glpk || exit 1
fi

echo "Patching configure in glpk_config_files"
# NOTE: This patch must be before ./get.Glpk
pushd glpk_config_files || exit 1
echo "Patching configure in top level"
sed                                                                                                \
  -e "s|libname_spec='lib\$name'|libname_spec='\$name'|g"                                          \
  -e 's|\.dll\.lib|.lib|g'                                                                         \
  -i configure
chmod +x configure
popd || exit 1

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
  -i configure
chmod +x configure
