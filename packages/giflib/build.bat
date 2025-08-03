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
set BUILD_DIR=%SRC_DIR%
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
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
call :clean_build
cl %C_OPTS% %C_DEFS% /c *.c || exit 1
if %errorlevel% neq 0 exit 1
set common=getopt.lib libgif.lib libutil.lib
set sources=dgif_lib.c egif_lib.c gifalloc.c gif_err.c gif_font.c gif_hash.c openbsd-reallocarray.c
set objects=%sources:.c=.obj%
link /NOLOGO /DLL /IMPLIB:gif.lib /OUT:gif.dll %objects% || exit 1
lib /OUT:libgif.lib %objects% || exit 1
set usources=qprintf.c quantize.c getarg.c
set uobjects=%usources:.c=.obj%
link /NOLOGO /DLL /IMPLIB:util.lib /OUT:util.dll %uobjects% libgif.lib || exit 1
lib /OUT:libutil.lib %uobjects% || exit 1
link /NOLOGO /OUT:gif2rgb.exe gif2rgb.obj %common% || exit 1
link /NOLOGO /OUT:gifbuild.exe gifbuild.obj %common% || exit 1
link /NOLOGO /OUT:giffix.exe giffix.obj %common% || exit 1
link /NOLOGO /OUT:giftext.exe giftext.obj %common% || exit 1
link /NOLOGO /OUT:giftool.exe giftool.obj %common% || exit 1
link /NOLOGO /OUT:gifclrmp.exe gifclrmp.obj %common% || exit 1
link /NOLOGO /OUT:gifbg.exe gifbg.obj %common% || exit 1
link /NOLOGO /OUT:gifcolor.exe gifcolor.obj %common% || exit 1
link /NOLOGO /OUT:gifecho.exe gifecho.obj %common% || exit 1
link /NOLOGO /OUT:giffilter.exe giffilter.obj %common% || exit 1
link /NOLOGO /OUT:gifhisto.exe gifhisto.obj %common% || exit 1
link /NOLOGO /OUT:gifinto.exe gifinto.obj %common% || exit 1
link /NOLOGO /OUT:gifsponge.exe gifsponge.obj %common% || exit 1
link /NOLOGO /OUT:gifwedge.exe gifwedge.obj %common% || exit 1
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
  xcopy /Y /F /I *.exe "%PREFIX%\bin" || exit 1
  xcopy /Y /F /I *.lib "%PREFIX%\lib" || exit 1
  xcopy /Y /F /I *.dll "%PREFIX%\bin" || exit 1
  xcopy /Y /F /I gif_lib.h "%PREFIX%\include"
)
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && del /s *.exe *.lib *.dll
exit /b 0

:end
