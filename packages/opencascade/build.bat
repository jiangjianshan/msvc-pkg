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
set SRC_DIR=%ROOT_DIR%\releases\%PKG_NAME%-%PKG_VER%
set BUILD_DIR=%SRC_DIR%\build%ARCH:x=%
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX

call :configure_stage
call :build_stage
call :install_stage
goto :end

rem ==============================================================================
rem  Configure package and ready to build
rem ==============================================================================
:configure_stage
call :clean_build
cd "%ROOT_DIR%"
for /f "delims=" %%i in ('yq -r ".%ARCH%.tcl.version" installed.yaml') do set TCL_FULL_VERSION=%%i
for /f "tokens=1-4 delims=." %%a in ("!TCL_FULL_VERSION!") do set tcl_major_minor=%%a%%b
for /f "delims=" %%i in ('yq -r ".%ARCH%.tk.version" installed.yaml') do set TK_FULL_VERSION=%%i
for /f "tokens=1-4 delims=." %%a in ("!TK_FULL_VERSION!") do set tk_major_minor=%%a%%b
if not defined FFMPEG_PREFIX set FFMPEG_PREFIX=%_PREFIX%
if not defined FREETYPE_PREFIX set FREETYPE_PREFIX=%_PREFIX%
if not defined FREEIMAGE_PREFIX set FREEIMAGE_PREFIX=%_PREFIX%
if not defined ONETBB_PREFIX set ONETBB_PREFIX=%_PREFIX%
if not defined RAPIDJSON_PREFIX set RAPIDJSON_PREFIX=%_PREFIX%
if not defined TCL_PREFIX set TCL_PREFIX=%_PREFIX%
if not defined TK_PREFIX set TK_PREFIX=%_PREFIX%
if not defined VTK_PREFIX set VTK_PREFIX=%_PREFIX%
echo "Configuring %PKG_NAME% %PKG_VER%"
mkdir "%BUILD_DIR%" && cd "%BUILD_DIR%"
rem FIXME: Don't use ffmpeg because opencascade use old API which has been removed from ffmpeg
cmake -G "Ninja"                                                               ^
  -DBUILD_SHARED_LIBS=ON                                                       ^
  -DCMAKE_BUILD_TYPE=Release                                                   ^
  -DCMAKE_C_COMPILER=cl                                                        ^
  -DCMAKE_C_FLAGS="%C_OPTS% %C_DEFS%"                                          ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                            ^
  -DBUILD_MODULE_FoundationClasses=ON                                          ^
  -DBUILD_MODULE_ModelingData=ON                                               ^
  -DBUILD_MODULE_ModelingAlgorithms=ON                                         ^
  -DBUILD_MODULE_Visualization=ON                                              ^
  -DBUILD_MODULE_ApplicationFramework=ON                                       ^
  -DBUILD_MODULE_DataExchange=ON                                               ^
  -DBUILD_MODULE_DETools=ON                                                    ^
  -DBUILD_MODULE_Draw=ON                                                       ^
  -DBUILD_DOC_Overview=OFF                                                     ^
  -DBUILD_LIBRARY_TYPE="Shared"                                                ^
  -DBUILD_WITH_DEBUG=OFF                                                       ^
  -DBUILD_USE_VCPKG=OFF                                                        ^
  -DUSE_D3D=ON                                                                 ^
  -DUSE_DRACO=ON                                                               ^
  -DUSE_FFMPEG=OFF                                                             ^
  -DUSE_FREETYPE=ON                                                            ^
  -DUSE_FREEIMAGE=ON                                                           ^
  -DUSE_RAPIDJSON=ON                                                           ^
  -DUSE_TK=ON                                                                  ^
  -DUSE_VTK=ON                                                                 ^
  -DUSE_TCL=ON                                                                 ^
  -DUSE_TBB=OFF                                                                ^
  -D3RDPARTY_DRACO_DIR="!DRACO_PREFIX:\=/!"                                    ^
  -D3RDPARTY_DRACO_INCLUDE_DIR="!DRACO_PREFIX:\=/!/include"                    ^
  -D3RDPARTY_DRACO_LIBRARY_DIR="!DRACO_PREFIX:\=/!/lib"                        ^
  -D3RDPARTY_FREETYPE_DIR="!FREETYPE_PREFIX:\=/!"                              ^
  -D3RDPARTY_FREETYPE_INCLUDE_DIR="!FREETYPE_PREFIX:\=/!/include"              ^
  -D3RDPARTY_FREETYPE_INCLUDE_DIR="!FREETYPE_PREFIX:\=/!/include"              ^
  -D3RDPARTY_FREETYPE_LIBRARY_DIR="!FREETYPE_PREFIX:\=/!/lib"                  ^
  -D3RDPARTY_FREEIMAGE_DIR="!FREEIMAGE_PREFIX:\=/!"                            ^
  -D3RDPARTY_FREEIMAGE_INCLUDE_DIR="!FREEIMAGE_PREFIX:\=/!/include"            ^
  -D3RDPARTY_FREEIMAGE_LIBRARY_DIR="!FREEIMAGE_PREFIX:\=/!/lib"                ^
  -D3RDPARTY_RAPIDJSON_DIR="!RAPIDJSON_PREFIX:\=/!"                            ^
  -D3RDPARTY_RAPIDJSON_INCLUDE_DIR="!RAPIDJSON_PREFIX:\=/!/include"            ^
  -D3RDPARTY_TCL_DIR="!TCL_PREFIX:\=/!"                                        ^
  -D3RDPARTY_TCL_INCLUDE_DIR="!TCL_PREFIX:\=/!/include"                        ^
  -D3RDPARTY_TCL_LIBRARY_DIR="!TCL_PREFIX:\=/!/lib"                            ^
  -D3RDPARTY_TCL_LIBRARY="!TCL_PREFIX:\=/!/lib/tcl!tcl_major_minor!t.lib"      ^
  -D3RDPARTY_TK_DIR="!TK_PREFIX:\=/!"                                          ^
  -D3RDPARTY_TK_INCLUDE_DIR="!TK_PREFIX:\=/!/include"                          ^
  -D3RDPARTY_TK_LIBRARY_DIR="!TK_PREFIX:\=/!/lib"                              ^
  -D3RDPARTY_TK_LIBRARY="!TK_PREFIX:\=/!/lib/tk!tk_major_minor!t.lib"          ^
  -D3RDPARTY_VTK_DIR="!VTK_PREFIX:\=/!"                                        ^
  -D3RDPARTY_VTK_INCLUDE_DIR="!VTK_PREFIX:\=/!/include"                        ^
  -D3RDPARTY_VTK_LIBRARY_DIR="!VTK_PREFIX:\=/!/lib"                            ^
  -DINSTALL_DIR="%PREFIX%"                                                     ^
  -DINSTALL_DIR_BIN="bin"                                                      ^
  -DINSTALL_DIR_CMAKE="lib/cmake/opencascade"                                  ^
  -DINSTALL_DIR_DATA="share/opencascade/data"                                  ^
  -DINSTALL_DIR_DOC="share/doc/opencascade"                                    ^
  -DINSTALL_DIR_INCLUDE="include/opencascade"                                  ^
  -DINSTALL_DIR_LIB="lib"                                                      ^
  -DINSTALL_DIR_RESOURCE="share/opencascade/resources"                         ^
  -DINSTALL_DIR_SAMPLES="share/opencascade/samples"                            ^
  -DINSTALL_DIR_SCRIPT="bin"                                                   ^
  -DTCL_TCLSH_VERSION="!tcl_major_minor!"                                      ^
  -DTCL_TCLSH="!TCL_PREFIX:\=/!/lib/tclConfig.sh"                              ^
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
