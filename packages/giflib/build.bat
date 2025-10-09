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

call :build_stage
call :install_stage
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
:install_stage
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
