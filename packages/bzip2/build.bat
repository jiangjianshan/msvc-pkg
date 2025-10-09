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

call "%ROOT_DIR%\compiler.bat" %ARCH%
set BUILD_DIR=%SRC_DIR%
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX

call :prepare_stage
call :build_stage
call :install_stage
goto :end

rem ==============================================================================
rem  Prepare package before configure or build
rem ==============================================================================
:prepare_stage
echo "Patching package %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%"
sed -e "/DESCRIPTION/d" -e "s|LIBBZ2|BZ2|g" -i libbz2.def
exit /b 0

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
set base_source=blocksort.c huffman.c crctable.c randtable.c compress.c decompress.c bzlib.c
cl %C_OPTS% %C_DEFS% /c %base_source%
link /nologo /DLL /IMPLIB:bz2.lib /DEF:libbz2.def /OUT:bz2.dll %base_source:.c=.obj%
cl %C_OPTS% %C_DEFS% /c bzip2.c
link /nologo /OUT:bzip2.exe bzip2.obj bz2.lib
lib /OUT:libbz2.lib %base_source:.c=.obj%
cl %C_OPTS% %C_DEFS% /c bzip2recover.c
link /nologo /OUT:bzip2recover.exe bzip2recover.obj
exit /b 0

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
if not exist "%PREFIX%\bin" mkdir "%PREFIX%\bin"
if not exist "%PREFIX%\include" mkdir "%PREFIX%\include"
if not exist "%PREFIX%\lib" mkdir "%PREFIX%\lib"
if not exist "%PREFIX%\share\man\man1" mkdir "%PREFIX%\share\man\man1"
cd "%BUILD_DIR%" && (
	xcopy /Y /F /I bzip2.exe "%PREFIX%\bin"
	if not exist "%PREFIX%\bin\bunzip2.exe" (
    mklink "%PREFIX%\bin\bunzip2.exe" "%PREFIX%\bin\bzip2.exe"
	)
	if not exist "%PREFIX%\bin\bzcat.exe" (
		mklink "%PREFIX%\bin\bzcat.exe" "%PREFIX%\bin\bzip2.exe"
	)
	xcopy /Y /F /I bzip2recover.exe "%PREFIX%\bin"
	xcopy /Y /F /I bzip2.1 "%PREFIX%\share\man\man1"
	xcopy /Y /F /I bzlib.h "%PREFIX%\include"
	xcopy /Y /F /I *.dll "%PREFIX%\bin"
	xcopy /Y /F /I *.lib "%PREFIX%\lib"
	xcopy /Y /F /I bzgrep "%PREFIX%\bin"
	if not exist "%PREFIX%\bin\bzegrep" (
    mklink "%PREFIX%\bin\bzegrep" "%PREFIX%\bin\bzgrep"
  )
	if not exist "%PREFIX%\bin\bzfgrep" (
	  mklink "%PREFIX%\bin\bzfgrep" "%PREFIX%\bin\bzgrep"
	)
	xcopy /Y /F /I bzmore "%PREFIX%\bin"
	if not exist "%PREFIX%\bin\bzless" (
	  mklink "%PREFIX%\bin\bzless" "%PREFIX%\bin\bzmore"
	)
	xcopy /Y /F /I bzdiff "%PREFIX%\bin"
	if not exist "%PREFIX%\bin\bzcmp" (
	  mklink "%PREFIX%\bin\bzcmp" "%PREFIX%\bin\bzdiff"
	)
	xcopy /Y /F /I *.1 "%PREFIX%\share\man\man1"
	echo .dll man1\bzgrep.1> "%PREFIX%\share\man\man1\bzegrep.1"
	echo .dll man1\bzgrep.1> "%PREFIX%\share\man\man1\bzfgrep.1"
	echo .dll man1\bzmore.1> "%PREFIX%\share\man\man1\bzless.1"
	echo .dll man1\bzdiff.1> "%PREFIX%\share\man\man1\bzcmp.1"
)
echo "Generating bzip2.pc to %PREFIX%\lib\pkgconfig"
set PC_FILE=%PREFIX%\lib\pkgconfig\bzip2.pc
if not exist "%PREFIX%\lib\pkgconfig" mkdir "%PREFIX%\lib\pkgconfig"
where cygpath >nul 2>&1
if "%errorlevel%" neq "0" (
	echo prefix=%PREFIX:\=/%> %PC_FILE%
	echo exec_prefix=%PREFIX:\=/%>> %PC_FILE%
	echo libdir=%PREFIX:\=/%/lib>> %PC_FILE%
	echo sharedlibdir=%PREFIX:\=/%/lib>> %PC_FILE%
	echo includedir=%PREFIX:\=/%/include>> %PC_FILE%
) else (
  for /f "delims=" %%i in ('cygpath -u "%PREFIX%"') do set PREFIX_UNIX=%%i
	echo prefix=!PREFIX_UNIX!> %PC_FILE%
	echo exec_prefix=!PREFIX_UNIX!>> %PC_FILE%
	echo libdir=!PREFIX_UNIX!/lib>> %PC_FILE%
	echo sharedlibdir=!PREFIX_UNIX!/lib>> %PC_FILE%
	echo includedir=!PREFIX_UNIX!/include>> %PC_FILE%
)
echo:>> %PC_FILE%
echo Name: bzip2>> %PC_FILE%
echo Description: bzip2 compression library>> %PC_FILE%
echo Version: 1.0.8>> %PC_FILE%
echo:>> %PC_FILE%
echo Requires:>> %PC_FILE%
echo Libs: -L${libdir} -L${sharedlibdir} -lbz2>> %PC_FILE%
echo Cflags: -I${includedir}>> %PC_FILE%
echo "Done"
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && del /s *.obj *.lib *.dll *.exe *.rb2 *.tst
exit /b 0

:end
