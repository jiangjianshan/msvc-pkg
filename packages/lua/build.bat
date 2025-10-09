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
set BUILD_DIR=%SRC_DIR%\src
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX
rem get major and minor version
for /f "tokens=1,2* delims=." %%a in ("%PKG_VER%") do (
    set pkg_ver_trim=%%a%%b
)

call :build_stage
call :install_stage
goto :end

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
rem https://blog.spreendigital.de/2019/06/25/how-to-compile-lua-5-3-5-for-windows/
cl /MD /O2 /c /DLUA_BUILD_AS_DLL *.c
ren lua.obj lua.o
ren luac.obj luac.o
link /DLL /IMPLIB:lua%pkg_ver_trim%.lib /OUT:lua%pkg_ver_trim%.dll *.obj
link /OUT:lua.exe lua.o lua%pkg_ver_trim%.lib
lib /OUT:liblua%pkg_ver_trim%.lib *.obj
link /OUT:luac.exe luac.o liblua%pkg_ver_trim%.lib
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
  echo F | xcopy /F /Y lua%pkg_ver_trim%.lib lua.lib
  xcopy /F /Y /I *.exe %PREFIX%\bin
  xcopy /F /Y /I *.lib %PREFIX%\lib
  xcopy /F /Y /I *.dll %PREFIX%\bin
  xcopy /F /Y /I lauxlib.h %PREFIX%\include
  xcopy /F /Y /I lua*.h %PREFIX%\include
  xcopy /F /Y /I lua*.hpp %PREFIX%\include
)
echo "Generating lua.pc to %PREFIX%\lib\pkgconfig"
set PC_FILE=%PREFIX%\lib\pkgconfig\lua.pc
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
echo Name: lua>> %PC_FILE%
echo Description: Lua is a powerful, efficient, lightweight, embeddable scripting language>> %PC_FILE%
echo Version: %PKG_VER%>> %PC_FILE%
echo:>> %PC_FILE%
echo Requires:>> %PC_FILE%
echo Libs: -L${libdir} -L${sharedlibdir} -llua -lluac>> %PC_FILE%
echo Cflags: -I${includedir}>> %PC_FILE%
echo "Done"
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && del /s *.o *.obj *.exp *.lib *.dll *.exe
exit /b 0

:end
