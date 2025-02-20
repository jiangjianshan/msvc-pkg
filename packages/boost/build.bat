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
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX

call :configure_stage
call :install_package
goto :end

rem ==============================================================================
rem  Configure package and ready to build
rem ==============================================================================
:configure_stage
call :clean_build
echo "Configuring %PKG_NAME% %PKG_VER%"
mkdir "%BUILD_DIR%" && cd "%SRC_DIR%" && bootstrap.bat || exit 1
exit /b 0


rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
set BITS=64
if "%ARCH%" == "x86" set BITS=32
cd "%SRC_DIR%" && b2 install -j%NUMBER_OF_PROCESSORS% --prefix="%PREFIX%"              ^
  --build-dir="%BUILD_DIR%" --build-type=complete variant=release                      ^
  address-model=!BITS! threading=multi link=static,shared runtime-link=shared          ^
  --without-mpi --without-graph_parallel
for /f "tokens=1-4 delims=." %%a in ("%PKG_VER%") do set boost_major_minor=%%a_%%b
rem NOTE:
rem There are maybe newer version of boost need to be linked, so that remove the old one.
rem Please use 'rmdir' but not 'rmdir /s' for the symbolic link created by 'mklink /D'
if exist "%PREFIX%\include\boost" rmdir "%PREFIX%\include\boost"
mklink /D "%PREFIX%\include\boost" "%PREFIX%\include\boost-!boost_major_minor!"
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
