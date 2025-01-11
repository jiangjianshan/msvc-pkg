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
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -Qopenmp -Qopenmp-simd -Wno-implicit-function-declaration -Wno-deprecated-non-prototype
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX -D__STDC__ -DNDEBUG
set F_OPTS=-nologo -MD -Qdiag-disable:10448 -fp:precise -Qopenmp -Qopenmp-simd -names:lowercase -assume:underscore

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
  -DCMAKE_BUILD_TYPE=Release                                                   ^
  -DCMAKE_C_COMPILER=icx-cl                                                    ^
  -DCMAKE_C_FLAGS="%C_OPTS% %C_DEFS%"                                          ^
  -DCMAKE_Fortran_COMPILER=ifx                                                 ^
  -DCMAKE_Fortran_FLAGS="%F_OPTS%"                                             ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                            ^
  -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=lld"                                   ^
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON                                         ^
  -DSCALAPACK_BUILD_TESTS=OFF                                                  ^
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
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja install || exit 1
if exist "%PREFIX%/lib/cmake/scalapack" rmdir /q "%PREFIX%/lib/cmake/scalapack"
mklink /D "%PREFIX%/lib/cmake/scalapack" "%PREFIX%/lib/cmake/scalapack-%PKG_VER%" || exit 1
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%" || exit 1
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
rmdir /s /q %SRC_DIR%\BLACS\INSTALL\CMakeFiles
del /q %SRC_DIR%\BLACS\INSTALL\CMakeCache.txt
del /q %SRC_DIR%\BLACS\INSTALL\.ninja_deps
del /q %SRC_DIR%\BLACS\INSTALL\.ninja_log
del /q %SRC_DIR%\BLACS\INSTALL\build.ninja
del /q %SRC_DIR%\BLACS\INSTALL\cmake_install.cmake
del /q %SRC_DIR%\BLACS\INSTALL\*.exe
exit /b 0

:end
