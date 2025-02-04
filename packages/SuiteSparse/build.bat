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
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -Qopenmp -Qopenmp-simd
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX -DBLAS_UNDERSCORE
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
rem TODO: If enable CUDA, the linker of intel compiler will pass the link flags to
rem       nvcc and cause unknown options issue. So now set DSUITESPARSE_USE_CUDA
rem       to OFF unitl find a way can solve this issue. Maybe have to modify the
rem       content of target_link_options inside those CMakeLists.txt or *.cmake.
cmake -G "Ninja"                                                               ^
  -DBUILD_SHARED_LIBS=ON                                                       ^
  -DCMAKE_BUILD_TYPE=Release                                                   ^
  -DCMAKE_C_COMPILER=icx-cl                                                    ^
  -DCMAKE_C_FLAGS="%C_OPTS% %C_DEFS%"                                          ^
  -DCMAKE_CXX_COMPILER=icx-cl                                                  ^
  -DCMAKE_CXX_FLAGS="-EHsc %C_OPTS% %C_DEFS%"                                  ^
  -DCMAKE_Fortran_COMPILER=ifx                                                 ^
  -DCMAKE_Fortran_FLAGS="%F_OPTS%"                                             ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                            ^
  -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=lld"                                   ^
  -DCMAKE_LINKER_TYPE=MSVC                                                     ^
  -DBLAS_LIBRARIES="openblas.lib"                                              ^
  -DLAPACK_LIBRARIES="openblas.lib"                                            ^
  -DSUITESPARSE_USE_CUDA=OFF                                                   ^
  -DSUITESPARSE_DEMOS=OFF                                                      ^
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
