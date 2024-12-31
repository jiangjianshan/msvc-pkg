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
set BUILD_DIR=%SRC_DIR%\w64
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS

call :build_stage
call :install_package
goto :end

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
call :clean_build
cd "%BUILD_DIR%"
copy /Y /V config_VC config.h
nmake.exe -f Makefile_VC_DLL || exit 1
exit /b 0

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
if not exist "%PREFIX%\bin" mkdir "%PREFIX%\bin"
if not exist "%PREFIX%\lib" mkdir "%PREFIX%\lib"
cd "%BUILD_DIR%"
copy /Y /V *.exe "%PREFIX%\bin" || exit 1
copy /Y /V *.dll "%PREFIX%\bin" || exit 1
copy /Y /V *.lib "%PREFIX%\lib" || exit 1
if exist "%PREFIX%\lib\glpk.lib" del /q "%PREFIX%\lib\glpk.lib"
mklink "%PREFIX%\lib\glpk.lib" "%PREFIX%\lib\glpk_5_0.lib"
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%"
del /s *.exe *.obj *.pdb *.lib *.dll *.ilk
del /s w64\config.h
exit /b 0

:end
