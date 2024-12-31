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
set BUILD_DIR=%SRC_DIR%\win
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
cd "%BUILD_DIR%"
nmake -f makefile.vc release || exit 1
exit /b 0

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
nmake -f makefile.vc install INSTALLDIR=%PREFIX% || exit 1
echo "Generating tcl.pc to %PREFIX%\lib\pkgconfig"
set PC_FILE="%PREFIX%\lib\pkgconfig\tcl.pc"
if not exist "%PREFIX%\lib\pkgconfig" mkdir "%PREFIX%\lib\pkgconfig"
echo # tcl pkg-config source file> %PC_FILE%
echo:>> %PC_FILE%
echo prefix=%PREFIX:\=/%>> %PC_FILE%
echo exec_prefix=%PREFIX:\=/%>> %PC_FILE%
echo libdir=%PREFIX:\=/%/lib>> %PC_FILE%
echo includedir=%PREFIX:\=/%/include>> %PC_FILE%
echo libfile=tcl86t.lib>> %PC_FILE%
echo:>> %PC_FILE%
echo Name: Tool Command Language>> %PC_FILE%
echo Description: Tcl is a powerful, easy-to-learn dynamic programming language, suitable for a wide range of uses.>> %PC_FILE%
echo URL: https://www.tcl-lang.org/>> %PC_FILE%
echo Version: 8.6.15>> %PC_FILE%
echo Requires.private: zlib>= 1.2.3>> %PC_FILE%
echo Libs: -L${libdir} -ltcl86t -ltclstub86>> %PC_FILE%
echo Libs.private: -lzdll>> %PC_FILE%
echo Cflags: -I${includedir}>> %PC_FILE%
echo "Done"
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
nmake -f makefile.vc clean
exit /b 0

:end