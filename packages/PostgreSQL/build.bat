@echo off
setlocal enabledelayedexpansion
rem
rem  Build script for the current library, it should not be called directly from the
rem  command line, but should be called from mpt.py.
rem
rem  The values of these environment variables come from mpt.py:
rem  ARCH            - x64 or x86
rem  ROOT_DIR        - root location of msvc-pkg
rem  PREFIX          - install location of current library
rem  PREFIX_PATH     - install location of third party libraries
rem  _PREFIX         - default install location if not list in settings.yaml
rem
rem  Copyright (c) 2024 Jianshan Jiang
rem
rem  Permission is hereby granted, free of charge, to any person obtaining a copy
rem  of this software and associated documentation files (the "Software"), to deal
rem  in the Software without restriction, including without limitation the rights
rem  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
rem  copies of the Software, and to permit persons to whom the Software is
rem  furnished to do so, subject to the following conditions:
rem
rem  The above copyright notice and this permission notice shall be included in all
rem  copies or substantial portions of the Software.
rem
rem  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
rem  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
rem  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
rem  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
rem  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
rem  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
rem  SOFTWARE.

for /f "delims=" %%i in ('yq -r ".name" config.yaml') do set PKG_NAME=%%i
for /f "delims=" %%i in ('yq -r ".version" config.yaml') do set PKG_VER=%%i
if "%ROOT_DIR%"=="" (
    echo Don't directly run %~nx0 from command line.
    echo To build !PKG_NAME! and its dependencies, please go to the root location of msvc-pkg, and then press
    echo mpt !PKG_NAME!
    goto :end
)
call "%ROOT_DIR%\compiler.bat" %ARCH%
set RELS_DIR=%ROOT_DIR%\releases
set SRC_DIR=%RELS_DIR%\%PKG_NAME%-%PKG_VER%
set BUILD_DIR=%SRC_DIR%\src\tools\msvc
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX

call :configure_stage
call :build_stage
call :install_package
goto :end

rem ==============================================================================
rem  Configure package and ready to build
rem ==============================================================================
:configure_stage
call :clean_build
cd "%BUILD_DIR%"
echo "Configuring %PKG_NAME% %PKG_VER%"
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

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && build || exit 1
exit /b 0

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && install %PREFIX% || exit 1
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && clean
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
