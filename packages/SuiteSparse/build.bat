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
set OPTIONS=-Xclang -O3 -march=native -fms-extensions -fms-compatibility -fms-compatibility-version=19.41
set DEFINES=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS


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
set SUFFIX=64
if "%ARCH%" == "x86" set SUFFIX=
cmake -G "Ninja"                                                               ^
  -DBUILD_SHARED_LIBS=ON                                                       ^
  -DCMAKE_BUILD_TYPE=Release                                                   ^
  -DCMAKE_C_COMPILER=clang-cl                                                  ^
  -DCMAKE_C_FLAGS="%OPTIONS% %DEFINES%"                                        ^
  -DCMAKE_CXX_COMPILER=clang-cl                                                ^
  -DCMAKE_CXX_FLAGS="-EHsc %OPTIONS% %DEFINES%"                                ^
  -DCMAKE_Fortran_COMPILER=flang-new                                           ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                            ^
  -DCMAKE_MT=mt                                                                ^
  -DLAPACK_LIBRARIES="lapack!SUFFIX!.lib"                                      ^
  -DSUITESPARSE_DEMOS=OFF                                                      ^
  -DBUILD_TESTING=OFF                                                          ^
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
