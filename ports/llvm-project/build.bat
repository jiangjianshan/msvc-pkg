@echo off
setlocal enabledelayedexpansion
rem
rem Build script for the current library.
rem
rem This script is designed to be invoked by `mpt.bat` using the command `mpt <library_name>`.
rem It relies on specific environment variables set by the `mpt` process to function correctly.
rem
rem Environment Variables Provided by `mpt` (in addition to system variables):
rem   ARCH          - Target architecture to build for. Valid values: `x64` or `x86`.
rem   PKG_NAME      - Name of the current library being built.
rem   PKG_VER       - Version of the current library being built.
rem   ROOT_DIR      - Root directory of the msvc-pkg project.
rem   SRC_DIR       - Source code directory of the current library.
rem   PREFIX        - **Actual installation path prefix** for the *current* library after successful build.
rem                   This path is where the built artifacts for *this specific library* will be installed.
rem                   It usually equals `_PREFIX`, but **may differ** if a non-default installation path
rem                   was explicitly specified for this library (e.g., `D:\LLVM` for `llvm-project`).
rem   PREFIX_PATH   - List of installation directory prefixes for third-party dependencies.
rem   _PREFIX       - **Default installation path prefix** for all built libraries.
rem                   This is the root directory where libraries are installed **unless overridden**
rem                   by a specific `PREFIX` setting for an individual library.
rem
rem   For each direct dependency `{Dependency}` of the current library:
rem     {Dependency}_SRC - Source code directory of the dependency `{Dependency}`.
rem     {Dependency}_VER - Version of the dependency `{Dependency}`.

call "%ROOT_DIR%\compiler.bat" %ARCH%
set BUILD_DIR=%SRC_DIR%\build%ARCH:x=%
set C_OPTS=-nologo -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -D_SILENCE_NONFLOATING_COMPLEX_DEPRECATION_WARNING

call :prepare_stage
call :clean_stage
call :configure_stage
call :build_stage
call :install_stage
call :clean_stage
goto :end

:clean_stage
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%" && if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
exit /b 0

:prepare_stage
echo "Preparing %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%"
rem Fix system_libs of llvm-config has wrongly link to zstd.dll.lib but not zstd.lib
pushd llvm\lib\Support
sed                                                                                                                  ^
  -e "s|\${zstd_target} PROPERTY LOCATION_\${build_type}|${zstd_target} PROPERTY IMPORTED_IMPLIB_${build_type}|g"    ^
  -e "s|\${zstd_target} PROPERTY LOCATION|${zstd_target} PROPERTY IMPORTED_IMPLIB|g"                                 ^
  -i CMakeLists.txt
popd
rem Fix SyntaxWarning invalid escape sequence if use python 3.12
pushd llvm\utils
sed -e "s/re.match(\"/re.match(r\"/g" -i extract_symbols.py
popd
exit /b 0

:configure_stage
echo "Configuring %PKG_NAME% %PKG_VER%"
mkdir "%BUILD_DIR%" && cd "%BUILD_DIR%"
cmake -G "Ninja"                                                                                   ^
  -DCMAKE_BUILD_TYPE=Release                                                                       ^
  -DCMAKE_C_COMPILER=cl                                                                            ^
  -DCMAKE_C_FLAGS="%C_OPTS% %C_DEFS%"                                                              ^
  -DCMAKE_CXX_COMPILER=cl                                                                          ^
  -DCMAKE_CXX_FLAGS="-EHsc %C_OPTS% %C_DEFS%"                                                      ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                                                ^
  -DCMAKE_INSTALL_UCRT_LIBRARIES=ON                                                                ^
  -DCMAKE_POLICY_DEFAULT_CMP0074=OLD                                                               ^
  -DCMAKE_POLICY_DEFAULT_CMP0116=OLD                                                               ^
  -DCLANG_DEFAULT_CXX_STDLIB=libc++                                                                ^
  -DCLANG_DEFAULT_LINKER=lld                                                                       ^
  -DCLANG_DEFAULT_OBJCOPY=llvm-objcopy                                                             ^
  -DCLANG_DEFAULT_OPENMP_RUNTIME=libomp                                                            ^
  -DCLANG_DEFAULT_RTLIB=compiler-rt                                                                ^
  -DCLANG_ENABLE_ARCMT=OFF                                                                         ^
  -DCLANG_ENABLE_OBJC_REWRITER=OFF                                                                 ^
  -DLIBCXX_USE_COMPILER_RT=ON                                                                      ^
  -DLLVM_BUILD_DOCS=OFF                                                                            ^
  -DLLVM_BUILD_EXAMPLES=OFF                                                                        ^
  -DLLVM_BUILD_LLVM_C_DYLIB=ON                                                                     ^
  -DLLVM_BUILD_TESTS=OFF                                                                           ^
  -DLLVM_BUILD_TOOLS=ON                                                                            ^
  -DLLVM_BUILD_UTILS=ON                                                                            ^
  -DLLVM_ENABLE_EH=ON                                                                              ^
  -DLLVM_ENABLE_RTTI=ON                                                                            ^
  -DLLVM_ENABLE_PROJECTS="bolt;clang;clang-tools-extra;lld;openmp;polly;pstl"                      ^
  -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx"                                                      ^
  -DLLVM_INCLUDE_BENCHMARKS=ON                                                                     ^
  -DLLVM_INCLUDE_DOCS=OFF                                                                          ^
  -DLLVM_INCLUDE_EXAMPLES=OFF                                                                      ^
  -DLLVM_INCLUDE_TESTS=OFF                                                                         ^
  -DLLVM_INCLUDE_TOOLS=ON                                                                          ^
  -DLLVM_INCLUDE_UTILS=ON                                                                          ^
  -DLLVM_INSTALL_UTILS=ON                                                                          ^
  -DLLVM_OPTIMIZED_TABLEGEN=ON                                                                     ^
  -DLLVM_TARGETS_TO_BUILD=X86                                                                      ^
  -DCLANG_ENABLE_BOOTSTRAP=ON                                                                      ^
  -DCLANG_BOOTSTRAP_PASSTHROUGH="CMAKE_BUILD_TYPE;CMAKE_INSTALL_PREFIX;CMAKE_INSTALL_LIBDIR;CMAKE_INSTALL_UCRT_LIBRARIES;CMAKE_POLICY_DEFAULT_CMP0074;CMAKE_POLICY_DEFAULT_CMP0116;CMAKE_FIND_PACKAGE_PREFER_CONFIG;CLANG_DEFAULT_CXX_STDLIB;CLANG_DEFAULT_LINKER;CLANG_DEFAULT_OBJCOPY;CLANG_DEFAULT_OPENMP_RUNTIME;CLANG_DEFAULT_RTLIB;CLANG_ENABLE_ARCMT;CLANG_ENABLE_OBJC_REWRITER;LIBCXX_USE_COMPILER_RT;LLVM_BUILD_DOCS;LLVM_BUILD_EXAMPLES;LLVM_BUILD_LLVM_C_DYLIB;LLVM_BUILD_TOOLS;LLVM_BUILD_TESTS;LLVM_BUILD_UTILS;LLVM_ENABLE_EH;LLVM_ENABLE_RTTI;LLVM_ENABLE_PROJECTS;LLVM_ENABLE_RUNTIMES;LLVM_INCLUDE_BENCHMARKS;LLVM_INCLUDE_EXAMPLES;LLVM_INCLUDE_TESTS;LLVM_INCLUDE_TOOLS;LLVM_INCLUDE_UTILS;LLVM_INSTALL_UTILS;LLVM_OPTIMIZED_TABLEGEN;LLVM_TARGETS_TO_BUILD;FFI_INCLUDE_DIRS;FFI_LIBRARIES;FFI_STATIC_LIBRARIES;OCAML_STDLIB_PATH;Z3_INCLUDE_DIR;Z3_LIBRARIES;ZLIB_INCLUDE_DIR;ZLIB_LIBRARY;zstd_INCLUDE_DIR;zstd_LIBRARY;zstd_STATIC_LIBRARY;LIBXML2_INCLUDE_DIR;LIBXML2_INCLUDE_DIRS;LIBXML2_LIBRARIES;LIBXML2_XMLLINT_EXECUTABLE;LIBXML2_DEFINITIONS;LIBXML2_LIBRARY;PERL_EXECUTABLE;Python3_EXECUTABLE;Python3_LIBRARIES;Python3_INCLUDE_DIRS;Python3_LIBRARY_DIRS;Python3_RUNTIME_LIBRARY_DIRS;Python3_ROOT_DIR_DIR;Python3_FIND_ABI;Python3_FIND_STRATEGY;Python3_FIND_REGISTRY;Python3_FIND_FRAMEWORK;Python3_FIND_UNVERSIONED_NAMES;SWIG_DIR;SWIG_EXECUTABLE"                                                                                                           ^
  -DBOOTSTRAP_LLVM_ENABLE_LLD=ON                                                                   ^
  ../llvm || exit 1
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja -k 0 -j%NUMBER_OF_PROCESSORS% stage2 || exit 1
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja stage2-install || exit 1
exit /b 0

:end
