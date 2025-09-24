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

  # Fix system_libs of llvm-config has wrongly link to zstd.dll.lib but not zstd.lib
  pushd llvm/lib/Support || exit 1
  sed                                                                                                                  \
    -e 's|\${zstd_target} PROPERTY LOCATION_\${build_type}|${zstd_target} PROPERTY IMPORTED_IMPLIB_${build_type}|g'    \
    -e 's|\${zstd_target} PROPERTY LOCATION|${zstd_target} PROPERTY IMPORTED_IMPLIB|g'                                 \
    -i CMakeLists.txt
  popd || exit 1

  # Fix SyntaxWarning invalid escape sequence if use python 3.12
  pushd llvm/utils
  sed                                                                          \
    -e 's|re.match("|re.match(r"|g'                                            \
    -i extract_symbols.py
  popd
}

patch_package
