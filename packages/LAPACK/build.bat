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
set OPTIONS=-nologo -MD -diagnostics:column -wd4819 -fp:precise -openmp:llvm
set DEFINES=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS
set F_OPTIONS=-nologo -Qdiag-disable:10448


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
cmake -G "Ninja"                                                               ^
  -DBUILD_SHARED_LIBS=ON                                                       ^
  -DCMAKE_BUILD_TYPE=Release                                                   ^
  -DCMAKE_C_COMPILER=cl                                                        ^
  -DCMAKE_C_FLAGS="%OPTIONS% %DEFINES%"                                        ^
  -DCMAKE_CXX_COMPILER=cl                                                      ^
  -DCMAKE_CXX_FLAGS="-EHsc %OPTIONS% %DEFINES%"                                ^
  -DCMAKE_Fortran_COMPILER=ifort                                               ^
  -DCMAKE_Fortran_FLAGS="%F_OPTIONS%"                                          ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                            ^
  -DBUILD_DEPRECATED=ON                                                        ^
  -DBUILD_INDEX64=ON                                                           ^
  -DCBLAS=ON                                                                   ^
  -DLAPACKE=ON                                                                 ^
  -DLAPACKE_WITH_TMG=ON                                                        ^
  -DUSE_OPTIMIZED_BLAS=OFF                                                     ^
  -DUSE_OPTIMIZED_LAPACK=OFF                                                   ^
  ..
if %errorlevel% neq 0 exit 1
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
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja install
if %errorlevel% neq 0 exit 1
if "%ARCH%" == "x64" (
  if not exist "%PREFIX%\lib\cmake\lapack64" (
    mklink /D "%PREFIX%\lib\cmake\lapack64" "%PREFIX%\lib\cmake\lapack64-%PKG_VER%"
  )
  if not exist "%PREFIX%\lib\cmake\cblas64" (
    mklink /D "%PREFIX%\lib\cmake\cblas64" "%PREFIX%\lib\cmake\cblas64-%PKG_VER%"
  )
  if not exist "%PREFIX%\lib\cmake\lapacke64" (
    mklink /D "%PREFIX%\lib\cmake\lapacke64" "%PREFIX%\lib\cmake\lapacke64-%PKG_VER%"
  )
  if not exist "%PREFIX%\lib\pkgconfig\lapack.pc" (
    mklink "%PREFIX%\lib\pkgconfig\lapack.pc" "%PREFIX%\lib\pkgconfig\lapack64.pc"
  )
  if not exist "%PREFIX%\lib\pkgconfig\blas.pc" (
    mklink "%PREFIX%\lib\pkgconfig\blas.pc" "%PREFIX%\lib\pkgconfig\blas64.pc"
  )
  if not exist "%PREFIX%\lib\pkgconfig\cblas.pc" (
    mklink "%PREFIX%\lib\pkgconfig\cblas.pc" "%PREFIX%\lib\pkgconfig\cblas64.pc"
  )
  if not exist "%PREFIX%\lib\blas.lib" (
    mklink "%PREFIX%\lib\blas.lib" "%PREFIX%\lib\blas64.lib"
  )
  if not exist "%PREFIX%\lib\lapack.lib" (
    mklink "%PREFIX%\lib\lapack.lib" "%PREFIX%\lib\lapack64.lib"
  )
  if not exist "%PREFIX%\lib\tmglib.lib" (
    mklink "%PREFIX%\lib\tmglib.lib" "%PREFIX%\lib\tmglib64.lib"
  )
  if not exist "%PREFIX%\bin\libblas.dll" (
    mklink "%PREFIX%\bin\libblas.dll" "%PREFIX%\bin\libblas64.dll"
  )
  if not exist "%PREFIX%\bin\libcblas.dll" (
    mklink "%PREFIX%\bin\libcblas.dll" "%PREFIX%\bin\libcblas64.dll"
  )
  if not exist "%PREFIX%\bin\liblapack.dll" (
    mklink "%PREFIX%\bin\liblapack.dll" "%PREFIX%\bin\liblapack64.dll"
  )
  if not exist "%PREFIX%\bin\libtmglib.dll" (
    mklink "%PREFIX%\bin\libtmglib.dll" "%PREFIX%\bin\libtmglib64.dll"
  )
  if not exist "%PREFIX%\bin\liblapacke.dll" (
    mklink "%PREFIX%\bin\liblapacke.dll" "%PREFIX%\bin\liblapacke64.dll"
  )
)
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
