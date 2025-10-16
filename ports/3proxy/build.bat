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
set CL=-MP %C_OPTS% %C_DEFS%
set MAKEFILE=Makefile.msvc
if "%ARCH%"=="x64" (
  set MAKEFILE=Makefile.msvc64
)

call :prepare_stage
call :clean_stage
call :build_stage
call :install_stage
call :clean_stage
goto :end

:clean_stage
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && (
  del /s /q *.obj *.exe *.lib
  if exist "bin64" rmdir /s /q "bin64"
)
exit /b 0

:prepare_stage
echo "Preparing %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%"
sed -e "s|/nologo /MT |/nologo |g" -i %MAKEFILE%
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
if "%ARCH%"=="x64" (
  if not exist "bin64" mkdir "bin64"
)
nmake /K -f %MAKEFILE% || exit 1
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
if not exist "%PREFIX%\bin" mkdir "%PREFIX%\bin"
if not exist "%PREFIX%\lib" mkdir "%PREFIX%\lib"
if not exist "%PREFIX%\share\man\man3" mkdir "%PREFIX%\share\man\man3"
if not exist "%PREFIX%\share\man\man8" mkdir "%PREFIX%\share\man\man8"
if not exist "%PREFIX%\etc\3proxy" mkdir "%PREFIX%\etc\3proxy"
if not exist "%PREFIX%\etc\3proxy\conf" mkdir "%PREFIX%\etc\3proxy\conf"
cd "%SRC_DIR%" && (
  if "%ARCH%"=="x64" (
    pushd bin64
  ) else (
    pushd bin
  )
  xcopy /Y /F /I *.exe "%PREFIX%\bin"
  xcopy /Y /F /I *.dll "%PREFIX%\bin"
  xcopy /Y /F /I *.lib "%PREFIX%\lib"
  popd
  echo F | xcopy /Y /F scripts\3proxy.cfg.chroot "%PREFIX%\etc\3proxy\3proxy.cfg"
  xcopy /Y /F /I scripts\3proxy.cfg "%PREFIX%\etc\3proxy\conf"
  xcopy /Y /F /I scripts\add3proxyuser.sh "%PREFIX%\etc\3proxy\conf"
  type nul > "%PREFIX%\etc\3proxy\conf\counters"
  type nul > "%PREFIX%\etc\3proxy\conf\bandlimiters"
  xcopy /Y /F /I man\*.3 "%PREFIX%\share\man\man3"
  xcopy /Y /F /I man\*.8 "%PREFIX%\share\man\man8"
)
exit /b 0

:end

