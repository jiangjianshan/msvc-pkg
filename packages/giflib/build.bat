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
set BUILD_DIR=%SRC_DIR%
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
  copy /Y /V *.exe "%PREFIX%\bin" || exit 1
  copy /Y /V *.lib "%PREFIX%\lib" || exit 1
  copy /Y /V *.dll "%PREFIX%\bin" || exit 1
  copy /Y /V gif_lib.h "%PREFIX%\include"
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
