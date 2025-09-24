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
  WANT_AUTOCONF='2.69' WANT_AUTOMAKE='1.16' autoreconf -ifv
  rm -rfv autom4te.cache
  find . -name "*~" -type f -print -exec rm -rfv {} \;
  # ifort          gfortran         Commentary
  # -----------------------------------------------------------------------
  # -Vaxlib                         Enables old VAX library compatibility
  #                                 (should not be necessary with gfortran
  #                                 and newer ifort versions)
  #
  # -Vaxlib is an older option for the version 9.0 and older compilers and no longer exists
  echo "Patching configure in top level"
  # NOTE: Changed '*,cl* | *,icl*)' to '*,cl| *,icl* | *,ifort*)'
  #       can solved following issues:
  #       1) The library_names_spec is not correct because it contains .dll name. This will also cause
  #          the shared library will be converted to symbolic link as .dll file.
  sed                                                                                                \
    -e "s|-mp -Vaxlib|-MP:$(nproc)|g"                                                                \
    -i configure
  chmod +x configure
}

patch_package
