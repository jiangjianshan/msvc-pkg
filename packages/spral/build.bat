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
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -Zc:__cplusplus -march=AVX2 -Xclang -O2 -march=native -fms-extensions -fms-compatibility -fms-compatibility-version=19.42
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX
set F_OPTS=-nologo -MD -Qdiag-disable:10448 -fp:precise -Qopenmp -Qopenmp-simd -names:lowercase -assume:underscore -fpp
if not defined LLVM_PROJECT_PREFIX set LLVM_PROJECT_PREFIX=%PREFIX%
set PATH=%LLVM_PROJECT_PREFIX%\bin;%PATH%

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
mkdir "%BUILD_DIR%"
cd "%SRC_DIR%"
copy /Y /V "%SRC_DIR%\nvcc_arch_sm.c" "%BUILD_DIR%"
rem NOTE: Up to the newest version 1.7.0 of meson, it still can't detect icx-cl.
rem       And the openmp version of msvc is too low, so that use clang-cl.exe instead of cl.exe
set CC=clang-cl
set CXX=clang-cl
set FC=ifort
set FC_LD=link
rem See https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/index.html#nvcc-environment-variables
set NVCC_CCBIN=clang-cl
set OMP_CANCELLATION=TRUE
set OMP_PROC_BIND=TRUE
meson setup "%BUILD_DIR%"                                                      ^
  --buildtype=release                                                          ^
  --prefix="%PREFIX%"                                                          ^
  --mandir="%PREFIX%\share\man"                                                ^
  -Dc_args="%C_OPTS% %C_DEFS%"                                                 ^
  -Dcpp_args="-EHsc %C_OPTS% %C_DEFS%"                                         ^
  -Dfortran_args="%F_OPTS%"                                                    ^
  -Dfortran_link_args="pthread.lib"                             ^
  -Dlibblas=openblas                                                           ^
  -Dliblapack=lapack                                                           ^
  -Dlibhwloc=hwloc                                                             ^
  -Dlibmetis=metis || exit 1
exit /b 0

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja
exit /b 0

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja install || exit 1
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
