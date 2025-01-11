@echo off
setlocal enabledelayedexpansion
rem
rem The values of these environment variables come from mpt.py:
rem ARCH              - x64 or x86
rem ROOT_DIR          - root location of msvc-pkg
rem PREFIX            - install location of current library
rem PREFIX_PATH       - install location of third party libraries
rem
call "%ROOT_DIR%\compiler.bat" %ARCH%
for /f "delims=" %%i in ('yq -r ".name" config.yaml') do set PKG_NAME=%%i
for /f "delims=" %%i in ('yq -r ".version" config.yaml') do set PKG_VER=%%i
set RELS_DIR=%ROOT_DIR%\releases
set SRC_DIR=%RELS_DIR%\%PKG_NAME%-%PKG_VER%
set BUILD_DIR=%SRC_DIR%\build%ARCH:x=%
set C_OPTS=-nologo -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX -D_SILENCE_NONFLOATING_COMPLEX_DEPRECATION_WARNING

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
  -DCLANG_DEFAULT_CXX_STDLIB=libc++                                                                ^
  -DCLANG_DEFAULT_LINKER=lld                                                                       ^
  -DCLANG_DEFAULT_OBJCOPY=llvm-objcopy                                                             ^
  -DCLANG_DEFAULT_OPENMP_RUNTIME=libomp                                                            ^
  -DCLANG_DEFAULT_RTLIB=compiler-rt                                                                ^
  -DCLANG_ENABLE_ARCMT=OFF                                                                         ^
  -DCLANG_ENABLE_OBJC_REWRITER=OFF                                                                 ^
  -DLIBCXX_USE_COMPILER_RT=ON                                                                      ^
  -DLLVM_BUILD_LLVM_C_DYLIB=ON                                                                     ^
  -DLLVM_BUILD_TOOLS=ON                                                                            ^
  -DLLVM_BUILD_UTILS=ON                                                                            ^
  -DLLVM_ENABLE_EH=ON                                                                              ^
  -DLLVM_ENABLE_RTTI=ON                                                                            ^
  -DLLVM_ENABLE_ZSTD=ON                                                                            ^
  -DLLVM_ENABLE_PROJECTS="bolt;clang;clang-tools-extra;libc;lld;lldb;openmp;polly;pstl"            ^
  -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx"                                                      ^
  -DLLVM_INCLUDE_BENCHMARKS=ON                                                                     ^
  -DLLVM_INCLUDE_TOOLS=ON                                                                          ^
  -DLLVM_INCLUDE_UTILS=ON                                                                          ^
  -DLLVM_INSTALL_UTILS=ON                                                                          ^
  -DLLVM_OPTIMIZED_TABLEGEN=ON                                                                     ^
  -DLLVM_TARGETS_TO_BUILD=X86                                                                      ^
  -DCLANG_ENABLE_BOOTSTRAP=ON                                                                      ^
  -DCLANG_BOOTSTRAP_PASSTHROUGH="CMAKE_BUILD_TYPE;CMAKE_INSTALL_PREFIX;CMAKE_INSTALL_LIBDIR;CMAKE_INSTALL_UCRT_LIBRARIES;CLANG_DEFAULT_CXX_STDLIB;CLANG_DEFAULT_LINKER;CLANG_DEFAULT_OBJCOPY;CLANG_DEFAULT_OPENMP_RUNTIME;CLANG_DEFAULT_RTLIB;CLANG_ENABLE_ARCMT;CLANG_ENABLE_OBJC_REWRITER;LIBCXX_USE_COMPILER_RT;LLVM_BUILD_LLVM_C_DYLIB;LLVM_BUILD_TOOLS;LLVM_BUILD_UTILS;LLVM_ENABLE_EH;LLVM_ENABLE_RTTI;LLVM_ENABLE_ZSTD;LLVM_ENABLE_PROJECTS;LLVM_ENABLE_RUNTIMES;LLVM_INCLUDE_BENCHMARKS;LLVM_INCLUDE_TOOLS;LLVM_INCLUDE_UTILS;LLVM_INSTALL_UTILS;LLVM_OPTIMIZED_TABLEGEN;LLVM_TARGETS_TO_BUILD;FFI_INCLUDE_DIRS;FFI_LIBRARIES;FFI_STATIC_LIBRARIES;OCAML_STDLIB_PATH;Z3_INCLUDE_DIR;Z3_LIBRARIES;ZLIB_INCLUDE_DIR;ZLIB_LIBRARY;LLVM_ENABLE_ZSTD;zstd_INCLUDE_DIR;zstd_LIBRARY;zstd_STATIC_LIBRARY;LIBXML2_INCLUDE_DIR;LIBXML2_INCLUDE_DIRS;LIBXML2_LIBRARIES;LIBXML2_XMLLINT_EXECUTABLE;LIBXML2_DEFINITIONS;LIBXML2_LIBRARY;PERL_EXECUTABLE;Python3_EXECUTABLE;Python3_LIBRARIES;Python3_INCLUDE_DIRS;Python3_LIBRARY_DIRS;Python3_RUNTIME_LIBRARY_DIRS;Python3_ROOT_DIR_DIR;Python3_FIND_ABI;Python3_FIND_STRATEGY;Python3_FIND_REGISTRY;Python3_FIND_FRAMEWORK;Python3_FIND_UNVERSIONED_NAMES;SWIG_DIR;SWIG_EXECUTABLE"    ^
  -DBOOTSTRAP_LLVM_ENABLE_LTO=Thin                                                                 ^
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
