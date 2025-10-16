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
set BUILD_DIR=%SRC_DIR%\src\tools\msvc
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX

call :clean_stage
call :configure_stage
call :build_stage
call :install_stage
call :clean_stage
goto :end

:clean_stage
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && clean
exit /b 0

:configure_stage
echo "Configuring %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
echo "Generating config.pl into %BUILD_DIR%"
echo use strict;>config.pl
echo use warnings;>>config.pl
echo.>>config.pl
echo our $config;>>config.pl
echo.>>config.pl
call :find_prefix gss gss-server.exe
call :find_prefix icu uconv.exe
call :find_prefix lz4 lz4.exe
call :find_prefix zstd zstd.exe
call :find_prefix nls gettext.exe
call :find_prefix tcl tclsh*.exe
call :find_prefix perl perl.exe
call :find_prefix python python.exe
call :find_prefix openssl openssl.exe
call :find_prefix xml xml2-config
call :find_prefix xslt xslt-config
call :find_prefix iconv iconv.exe
call :find_prefix zlib zlib1.dll
echo.>>config.pl
echo 1;>>config.pl
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && build || exit 1
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && install %PREFIX% || exit 1
exit /b 0

rem ==============================================================================
rem  Find prefix path of specify file
rem ==============================================================================
:find_prefix
setlocal
set "var_name=%1"
set "file_name=%2"
for /f "delims=" %%i in ('where %file_name% 2^>nul') do (
	if not defined file_dir (
    set "file_dir=%%~dpi"
		if "!file_dir:~-1!"=="\" set "file_dir=!file_dir:~0,-1!"
    for %%i in ("!file_dir!") do set "last_dir=%%~nxi"
		if "!last_dir!"=="bin" (
			pushd "!file_dir!"
			cd ..
			set "prefix_dir=!cd!"
			popd
		) else (
			set "prefix_dir=!file_dir!"
		)
   if "!prefix_dir:~-1!"=="\" set "prefix_dir=!prefix_dir:~0,-1!"
		echo $config-^>{'%var_name%'} = '!prefix_dir!';>>config.pl
	)
)
endlocal
exit /b 0

:end
