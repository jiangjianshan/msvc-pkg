@echo off
setlocal enabledelayedexpansion
rem
rem  Build script for the current library, it should not be called directly from the
rem  command line, but should be called from mpt.py.
rem
rem  The values of these environment variables come from mpt.py:
rem  ARCH            - x64 or x86
rem  ROOT_DIR        - root location of msvc-pkg
rem  PREFIX          - install location of current library
rem  PREFIX_PATH     - install location of third party libraries
rem  _PREFIX         - default install location if not list in settings.yaml
rem
rem  Copyright (c) 2024 Jianshan Jiang
rem
rem  Permission is hereby granted, free of charge, to any person obtaining a copy
rem  of this software and associated documentation files (the "Software"), to deal
rem  in the Software without restriction, including without limitation the rights
rem  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
rem  copies of the Software, and to permit persons to whom the Software is
rem  furnished to do so, subject to the following conditions:
rem
rem  The above copyright notice and this permission notice shall be included in all
rem  copies or substantial portions of the Software.
rem
rem  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
rem  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
rem  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
rem  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
rem  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
rem  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
rem  SOFTWARE.

for /f "delims=" %%i in ('yq -r ".name" config.yaml') do set PKG_NAME=%%i
for /f "delims=" %%i in ('yq -r ".version" config.yaml') do set PKG_VER=%%i
if "%ROOT_DIR%"=="" (
    echo Don't directly run %~nx0 from command line.
    echo To build !PKG_NAME! and its dependencies, please go to the root location of msvc-pkg, and then press
    echo mpt !PKG_NAME!
    goto :end
)
call "%ROOT_DIR%\compiler.bat" %ARCH%
set RELS_DIR=%ROOT_DIR%\releases
set SRC_DIR=%RELS_DIR%\%PKG_NAME%-%PKG_VER%
set BUILD_DIR=%SRC_DIR%\build%ARCH:x=%
set C_OPTS=-nologo -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -D_SILENCE_NONFLOATING_COMPLEX_DEPRECATION_WARNING

call :configure_stage
call :build_stage
call :install_package
goto :end

rem ==============================================================================
rem  Configure package and ready to build
rem ==============================================================================
:configure_stage
call :clean_build
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

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja -j%NUMBER_OF_PROCESSORS% stage2
exit /b 0

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja stage2-install || exit 1
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%" && if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
exit /b 0

:end
