#!/bin/bash
if [ -z "$ROOT_DIR" ]; then
    echo "Don't directly run $0 from command line, it should be called from mpt.bat directly."
    exit 0
fi
ROOT_DIR=$(cygpath -u "$ROOT_DIR")
SRC_DIR=$ROOT_DIR/releases/$PKG_NAME-$PKG_VER
echo "Patching package $PKG_NAME $PKG_VER"
cd "$SRC_DIR" || exit 1
# XXX: libtool don't have options can set the naming style of static and
#      shared library. Here is only a workaround.
echo "Patching ltmain.sh in top level"
sed                                                                                                \
  -e 's|old_library=$libname\.$libext|old_library=lib$libname.$libext|g'                           \
  -e 's|$output_objdir/$libname\.$libext|$output_objdir/lib$libname.$libext|g'                     \
  -i ltmain.sh

# NOTE: Changed '*,cl*)' to '*,cl| *,icx-cl* | *,ifx*)' and 'cl*)' to 'cl* | icx-cl* | ifort* | ifx*)'
#       can solved following two issues:
#       1) If use 'dumpbin /export fftw3.lib', the result will be look like below:
#         ordinal hint RVA      name
#         1       0    000E1650 DFFTW_CLEANUP
#         2       1    000E17A0 DFFTW_COST
#         It contain the value of ordinal, hint and RVA, but this is not want for those libraries
#         that use MSVC compiler and want to import this fftw3.lib.
#       2) The library_names_spec is not correct because it contains .dll name. This will also cause
#          the shared library will be converted to symbolic link as .dll file.
echo "Patching configure in top level"
sed                                                                                                \
  -e "s|libname_spec='lib\$name'|libname_spec='\$name'|g"                                          \
  -e 's|\.dll\.lib|.lib|g'                                                                         \
  -e 's/ \*,cl\*)/ *,cl* | *,icx-cl* | *,ifort* | *,ifx*)/g'                                       \
  -e 's/ cl\*)/ cl* | icx-cl* | ifort* | ifx*)/g'                                                  \
  -e 's/ ifort\*)/ ifort* | ifx*)/g'                                                               \
  -e 's/ ifort\*,ia64\*)/ ifort*,ia64* | ifx*,ia64*)/g'                                            \
  -e 's/ ifort\*|nagfor\*)/ ifort*|ifx*|nagfor*)/g'                                                \
  -e 's|ifort ifc|ifort ifx ifc|g'                                                                 \
  -i configure
chmod +x configure
