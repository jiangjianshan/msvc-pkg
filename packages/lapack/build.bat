@echo off
setlocal enabledelayedexpansion
rem
rem  Build script for the current library, it should not be called directly from the
rem  command line, but should be called from mpt.bat.
rem
rem  The values of these environment variables come from mpt.bat:
rem  ARCH            - x64 or x86
rem  PKG_NAME        - name of library
rem  PKG_VER         - version of library
rem  ROOT_DIR        - root location of msvc-pkg
rem  PREFIX          - install location of current library
rem  PREFIX_PATH     - install location of third party libraries
rem  _PREFIX         - default install location if not list in settings.yaml
rem

if "%ROOT_DIR%"=="" (
    echo Don't directly run %~nx0 from command line.
    echo To build !PKG_NAME! and its dependencies, please go to the root location of msvc-pkg, and then press
    echo mpt !PKG_NAME!
    goto :end
)
call "%ROOT_DIR%\compiler.bat" %ARCH% oneapi
set RELS_DIR=%ROOT_DIR%\releases
set SRC_DIR=%RELS_DIR%\%PKG_NAME%-%PKG_VER%
set BUILD_DIR=%SRC_DIR%\build%ARCH:x=%
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX -DLAPACK_COMPLEX_STRUCTURE
set F_OPTS=-nologo -MD -Qdiag-disable:10448 -fp:precise -Qopenmp -Qopenmp-simd -fpp

call :configure_stage
call :build_stage
call :install_stage
goto :end

rem ==============================================================================
rem  Configure package and ready to build
rem ==============================================================================
:configure_stage
call :clean_build
echo "Configuring %PKG_NAME% %PKG_VER%"
mkdir "%BUILD_DIR%" && cd "%BUILD_DIR%"
cmake -G "Ninja"                                                               ^
  -DBUILD_SHARED_LIBS=ON                                                       ^
  -DCMAKE_BUILD_TYPE=Release                                                   ^
  -DCMAKE_C_COMPILER=cl                                                        ^
  -DCMAKE_C_FLAGS="%C_OPTS% %C_DEFS%"                                          ^
  -DCMAKE_Fortran_COMPILER=ifort                                               ^
  -DCMAKE_Fortran_FLAGS="%F_OPTS%"                                             ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                            ^
  -DCBLAS=ON                                                                   ^
  -DLAPACKE=ON                                                                 ^
  -DBUILD_INDEX64=ON                                                           ^
  -DBUILD_INDEX64_EXT_API=OFF                                                  ^
  -DBUILD_COMPLEX=ON                                                           ^
  -DBUILD_COMPLEX16=ON                                                         ^
  -DBUILD_DEPRECATED=ON                                                        ^
  -DBUILD_DOUBLE=ON                                                            ^
  -DLAPACKE_WITH_TMG=ON                                                        ^
  -DUSE_OPTIMIZED_BLAS=OFF                                                     ^
  -DUSE_OPTIMIZED_LAPACK=OFF                                                   ^
  .. || exit 1
exit /b 0

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja -j%NUMBER_OF_PROCESSORS%
exit /b 0

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja install || exit 1
rem blas64.lib -> blas.lib
if exist "%PREFIX%\lib\blas.lib" del /q "%PREFIX%\lib\blas.lib"
mklink "%PREFIX%\lib\blas.lib" "%PREFIX%\lib\blas64.lib"
rem cblas64.lib -> blas.lib
if exist "%PREFIX%\lib\cblas.lib" del /q "%PREFIX%\lib\cblas.lib"
mklink "%PREFIX%\lib\cblas.lib" "%PREFIX%\lib\cblas64.lib"
rem lapack64.lib -> lapack.lib
if exist "%PREFIX%\lib\lapack.lib" del /q "%PREFIX%\lib\lapack.lib"
mklink "%PREFIX%\lib\lapack.lib" "%PREFIX%\lib\lapack64.lib"
rem lapacke64.lib -> lapacke.lib
if exist "%PREFIX%\lib\lapacke.lib" del /q "%PREFIX%\lib\lapacke.lib"
mklink "%PREFIX%\lib\lapacke.lib" "%PREFIX%\lib\lapacke64.lib"
rem tmglib64.lib -> tmglib.lib
if exist "%PREFIX%\lib\tmglib.lib" del /q "%PREFIX%\lib\tmglib.lib"
mklink "%PREFIX%\lib\tmglib.lib" "%PREFIX%\lib\tmglib64.lib"
sed -E "s#([A-Za-z]):[\\/]#/\L\1/#gI" -i "%PREFIX%/lib/pkgconfig/lapack64.pc"
sed -E "s#([A-Za-z]):[\\/]#/\L\1/#gI" -i "%PREFIX%/lib/pkgconfig/blas64.pc"
sed -E "s#([A-Za-z]):[\\/]#/\L\1/#gI" -i "%PREFIX%/lib/pkgconfig/cblas64.pc"
sed -E "s#([A-Za-z]):[\\/]#/\L\1/#gI" -i "%PREFIX%/lib/pkgconfig/lapacke64.pc"
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
