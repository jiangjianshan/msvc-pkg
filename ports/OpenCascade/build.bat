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

call "%ROOT_DIR%\compiler.bat" %ARCH% oneapi
set BUILD_DIR=%SRC_DIR%\build%ARCH:x=%
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX

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

:configure_stage
echo "Configuring %PKG_NAME% %PKG_VER%"
cd "%ROOT_DIR%"
for /f "tokens=1-4 delims=." %%a in ("!TCL_VER!") do set tcl_major_minor=%%a%%b
for /f "tokens=1-4 delims=." %%a in ("!TK_VER!") do set tk_major_minor=%%a%%b
if not defined FFMPEG_PREFIX set FFMPEG_PREFIX=%_PREFIX%
if not defined FREETYPE_PREFIX set FREETYPE_PREFIX=%_PREFIX%
if not defined FREEIMAGE_PREFIX set FREEIMAGE_PREFIX=%_PREFIX%
if not defined ONETBB_PREFIX set ONETBB_PREFIX=%_PREFIX%
if not defined RAPIDJSON_PREFIX set RAPIDJSON_PREFIX=%_PREFIX%
if not defined TCL_PREFIX set TCL_PREFIX=%_PREFIX%
if not defined TK_PREFIX set TK_PREFIX=%_PREFIX%
if not defined VTK_PREFIX set VTK_PREFIX=%_PREFIX%
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

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja -k 0 -j%NUMBER_OF_PROCESSORS% || exit 1
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja install || exit 1
exit /b 0

:end
