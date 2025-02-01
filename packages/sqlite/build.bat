@echo off
chcp 65001 > nul
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
set BUILD_DIR=%SRC_DIR%
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX

call :build_stage
call :install_package
goto :end

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
if not defined TCL_PREFIX set TCL_PREFIX=%PREFIX%
nmake /f Makefile.msc TCLDIR=!TCL_PREFIX!                                      ^
  CCOPTS="%C_OPTS% %C_DEFS%"                                                   ^
  BUILD_ZLIB=0                                                                 ^
  USE_ZLIB=1                                                                   ^
  USE_ICU=1                                                                    ^
  USE_CRT_DLL=1                                                                ^
  DYNAMIC_SHELL=1                                                              ^
  PLATFORM=%ARCH%                                                              ^
  || exit 1
exit /b 0

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
if not exist "%PREFIX%\bin" mkdir "%PREFIX%\bin"
if not exist "%PREFIX%\include" mkdir "%PREFIX%\include"
if not exist "%PREFIX%\lib" mkdir "%PREFIX%\lib"
cd "%BUILD_DIR%" && (
  copy /Y /V *.exe %PREFIX%\bin || exit 1
  copy /Y /V *.dll %PREFIX%\bin || exit 1
  copy /Y /V *.lib %PREFIX%\lib || exit 1
  copy /Y /V sqlite3.h %PREFIX%\include
)
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && del *.o *.obj *.exp *.lib *.dll *.exe *.ilk *.pdb *.lo
exit /b 0

:end
