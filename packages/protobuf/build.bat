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
call "%ROOT_DIR%\compiler.bat" %ARCH%
set SRC_DIR=%ROOT_DIR%\releases\%PKG_NAME%-%PKG_VER%
set BUILD_DIR=%SRC_DIR%\build%ARCH:x=%
set C_OPTS=-nologo -MD -diagnostics:column -wd4047 -wd4091 -wd4819 -wd4996 -wd5287 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX -DPROTOBUF_USE_DLLS

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
if not defined PROTOBUF_PREFIX set PROTOBUF_PREFIX=%_PREFIX%
rem Clean old installation to avoid possible compile errors
pushd "!PROTOBUF_PREFIX!\include"
if exist "upb" rmdir /s /q "upb"
if exist "upb_generator" rmdir /s /q "upb_generator"
if exist "google\protobuf\descriptor.upb.h" del /s /q "google\protobuf\descriptor.upb.h"
if exist "google\protobuf\descriptor.upb_minitable.h" del /s /q "google\protobuf\descriptor.upb_minitable.h"
if exist "google\protobuf\compiler\rust\upb_helpers.h" del /s /q "google\protobuf\compiler\rust\upb_helpers.h"
popd
mkdir "%BUILD_DIR%" && cd "%BUILD_DIR%"
cmake -G "Ninja"                                                               ^
  -DBUILD_SHARED_LIBS=ON                                                       ^
  -DCMAKE_BUILD_TYPE=Release                                                   ^
  -DCMAKE_C_COMPILER=cl                                                        ^
  -DCMAKE_C_FLAGS="%C_OPTS% %C_DEFS%"                                          ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                            ^
  -Dprotobuf_BUILD_EXAMPLES=OFF                                                ^
  -Dprotobuf_BUILD_LIBPROTOC=ON                                                ^
  -Dprotobuf_BUILD_SHARED_LIBS=ON                                              ^
  -Dprotobuf_BUILD_TESTS=OFF                                                   ^
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
pushd "%PREFIX%\lib\pkgconfig"
for %%f in ("protobuf*.pc") do (
  sed -e "s#\([=]\|-[IL]\|^\)\([A-Za-z]\):[\\/]#\1/\L\2/#g" -i "%%~f"
)
sed -e "s#\([=]\|-[IL]\|^\)\([A-Za-z]\):[\\/]#\1/\L\2/#g" -i upb.pc
sed -e "s#\([=]\|-[IL]\|^\)\([A-Za-z]\):[\\/]#\1/\L\2/#g" -i utf8_range.pc
popd
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
