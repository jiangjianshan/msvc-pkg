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
set C_OPTS=-Xclang -O3 -march=native -fms-extensions -fms-compatibility -fms-compatibility-version=19.42
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX -DHWY_WANT_WASM2

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
  -DCMAKE_C_COMPILER=clang-cl                                                  ^
  -DCMAKE_C_FLAGS="%C_OPTS% %C_DEFS%"                                          ^
  -DCMAKE_CXX_COMPILER=clang-cl                                                ^
  -DCMAKE_CXX_FLAGS="-EHsc %C_OPTS% %C_DEFS%"                                  ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                            ^
  -DCMAKE_MT=mt                                                                ^
  -DJPEGXL_FORCE_SYSTEM_HWY=ON                                                 ^
  -DJPEGXL_FORCE_SYSTEM_BROTLI=ON                                              ^
  -DJPEGXL_FORCE_SYSTEM_HWY=ON                                                 ^
  -DJPEGXL_FORCE_SYSTEM_LCMS2=ON                                               ^
  -DJPEGXL_ENABLE_BENCHMARK=OFF                                                ^
  -DJPEGXL_ENABLE_DOXYGEN=OFF                                                  ^
  -DJPEGXL_ENABLE_EXAMPLES=OFF                                                 ^
  -DJPEGXL_ENABLE_FUZZERS=OFF                                                  ^
  -DJPEGXL_ENABLE_JNI=OFF                                                      ^
  -DJPEGXL_ENABLE_MANPAGES=OFF                                                 ^
  -DJPEGXL_ENABLE_OPENEXR=OFF                                                  ^
  -DJPEGXL_ENABLE_PLUGINS=ON                                                   ^
  -DJPEGXL_ENABLE_SJPEG=ON                                                     ^
  -DJPEGXL_ENABLE_SKCMS=OFF                                                    ^
  -DJPEGXL_ENABLE_TCMALLOC=OFF                                                 ^
  -DJPEGXL_ENABLE_VIEWERS=ON                                                   ^
  -DJPEGXL_ENABLE_AVX512=ON                                                    ^
  -DJPEGXL_ENABLE_AVX512_SPR=ON                                                ^
  -DJPEGXL_ENABLE_AVX512_ZEN4=ON                                               ^
  -DSJPEG_ENABLE_SIMD=ON                                                       ^
  -DBUILD_TESTING=OFF                                                          ^
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
