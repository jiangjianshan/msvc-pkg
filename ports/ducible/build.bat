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
set BUILD_DIR=%SRC_DIR%\vs\vs2015
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX
set CL=-MP

call :clean_stage
call :build_stage
call :install_stage
call :clean_stage
goto :end

:clean_stage
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && (
  rmdir /s /q x64
  rmdir /s /q pdbdump\x64
  rmdir /s /q ducible\x64
)
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
rem NOTE:
rem 1. Converting pe/format.h to UTF-8 with BOM or pass /UTF-8 otpion
rem    to fix error C2039: 'CvSignature': is not a member of 'CV_INFO_PDB70'
rem    If use cl /EP -c patch_image.cpp, you will see only CvSignature are not
rem    in side struct CV_INFO_PDB70 but other three are there, actually pe/format.h
rem    has defined CvSignature inside struct CV_INFO_PDB70, this is caused by
rem    encoding issue
cd "%BUILD_DIR%" && msbuild ducible.sln /p:Configuration=Release               ^
  /p:Platform=%ARCH% /p:PlatformToolset=v143 /p:UseEnv=true                    ^
  /p:SkipUWP=true /p:ContinueOnError=true /p:WindowsTargetPlatformVersion=10.0
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
if not exist "%PREFIX%\bin" mkdir "%PREFIX%\bin"
cd "%BUILD_DIR%" && xcopy /Y /F /I %ARCH%\Release\*.exe "%PREFIX%\bin" || exit 1
exit /b 0

:end
