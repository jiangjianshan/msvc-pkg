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
set BUILD_DIR=%SRC_DIR%\src
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX
rem get major and minor version
for /f "tokens=1,2* delims=." %%a in ("%PKG_VER%") do (
    set pkg_ver_trim=%%a%%b
)

call :build_stage
call :install_package
goto :end

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
cl /MD /O2 /c /DLUA_BUILD_AS_DLL /DLUA_COMPAT_5_3 *.c
set base_objs=
for /f %%i in ('dir /b *.c ^| findstr /v "lua*.c"') do (
    set base_objs=!base_objs! %%i
)
rem https://blog.spreendigital.de/2019/06/25/how-to-compile-lua-5-3-5-for-windows/
link /DLL /IMPLIB:lua%pkg_ver_trim%.lib /OUT:lua%pkg_ver_trim%.dll !base_objs:.c=.obj!
link /OUT:lua%pkg_ver_trim%.exe lua.obj lua%pkg_ver_trim%.lib
lib /OUT:lua%pkg_ver_trim%.lib *.obj
link /OUT:luac%pkg_ver_trim%.exe luac.obj lua%pkg_ver_trim%.lib
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
  copy /Y /V lua%pkg_ver_trim%.exe lua.exe || exit 1
  copy /Y /V luac%pkg_ver_trim%.exe luac.exe || exit 1
  copy /Y /V lua%pkg_ver_trim%.lib lua.lib || exit 1
  copy /Y /V *.exe %PREFIX%\bin
  copy /Y /V *.lib %PREFIX%\lib
  copy /Y /V *.dll %PREFIX%\bin
  copy /Y /V lauxlib.h %PREFIX%\include
  copy /Y /V lua*.h %PREFIX%\include
  copy /Y /V lua*.hpp %PREFIX%\include
)
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && del *.o *.obj *.exp *.lib *.dll *.exe
exit /b 0

:end
