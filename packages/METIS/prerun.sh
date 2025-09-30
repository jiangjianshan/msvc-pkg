#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME-$PKG_VER
echo "Patching package $PKG_NAME $PKG_VER"
cd "$SRC_DIR" || exit 1
echo "Patching vsgen.bat in top level"
sed                                                                            \
  -e 's|-DCMAKE_CONFIGURATION_TYPES=|-DCMAKE_BUILD_TYPE=|g'                    \
  -i 'vsgen.bat'

# NOTE: Fix issue when build ceres-solver: cannot convert argument 1 from 'StorageIndex *' to 'idx_t *'
pushd "include" || exit 1
sed                                                                            \
  -e 's|\/\/#define IDXTYPEWIDTH 32|#define IDXTYPEWIDTH 32|g'                 \
  -e 's|\/\/#define REALTYPEWIDTH 32|#define REALTYPEWIDTH 32|g'               \
  metis.h > metis.h-t
mv metis.h-t metis.h
popd || exit 1