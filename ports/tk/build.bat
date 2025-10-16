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
set BUILD_DIR=%SRC_DIR%\win
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX
set CL=-MP %C_OPTS% %C_DEFS%

call :clean_stage
call :build_stage
call :install_stage
call :clean_stage
goto :end

:clean_stage
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && nmake /K -f makefile.vc clean
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
nmake /K -f makefile.vc release || exit 1
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
nmake /K -f makefile.vc install INSTALLDIR=%PREFIX% || exit 1
echo "Generating tk.pc %PREFIX%\lib\pkgconfig"
set PC_FILE="%PREFIX%\lib\pkgconfig\tk.pc"
if not exist "%PREFIX%\lib\pkgconfig" mkdir "%PREFIX%\lib\pkgconfig"
echo # tk pkg-config source file> %PC_FILE%
echo:>> %PC_FILE%
where cygpath >nul 2>&1
if "%errorlevel%" neq "0" (
  echo prefix=%PREFIX:\=/%>> %PC_FILE%
  echo exec_prefix=%PREFIX:\=/%>> %PC_FILE%
  echo libdir=%PREFIX:\=/%/lib>> %PC_FILE%
  echo includedir=%PREFIX:\=/%/include>> %PC_FILE%
) else (
  for /f "delims=" %%i in ('cygpath -u "%PREFIX%"') do set PREFIX_UNIX=%%i
  echo prefix=!PREFIX_UNIX!> %PC_FILE%
  echo exec_prefix=!PREFIX_UNIX!>> %PC_FILE%
  echo libdir=!PREFIX_UNIX!/lib>> %PC_FILE%
  echo includedir=!PREFIX_UNIX!/include>> %PC_FILE%
)
echo libfile=tcl86t.lib>> %PC_FILE%
echo:>> %PC_FILE%
echo Name: The Tk Toolkit>> %PC_FILE%
echo Description: Tk is a cross-platform graphical user interface toolkit, the standard GUI not only for Tcl, but for many other dynamic languages as well.>> %PC_FILE%
echo URL: https://www.tcl-lang.org/>> %PC_FILE%
echo Version: 8.6.15>> %PC_FILE%
echo Requires: tcl>= 8.6>> %PC_FILE%
echo Libs: -L${libdir} -ltk86t -ltkstub86>> %PC_FILE%
echo Libs.private:>> %PC_FILE%
echo Cflags: -I${includedir}>> %PC_FILE%
echo "Done"
exit /b 0

:end