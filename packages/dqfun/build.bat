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

call "%ROOT_DIR%\compiler.bat" %ARCH% oneapi
set BUILD_DIR=%SRC_DIR%\fortran
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:strict
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX
set F_OPTS=-nologo -MD -Qdiag-disable:10448 -fast -fp:strict -Qopenmp -Qopenmp-simd -fpp

call :build_stage
call :install_stage
goto :end

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Cleaning %PKG_NAME% %PKG_VER%"
call :clean_build
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
set base_source=dqfuna.f90 dqfune.f90 dqmodule.f90 second.f90
set base_objs=%base_source:.f90=.obj%
@echo on
ifx %F_OPTS% -c %base_source% || exit 1
ifx %F_OPTS% -exe:testdqfun.exe testdqfun.f90 !base_objs! || exit 1
ifx %F_OPTS% -exe:tpslqm1dq.exe tpslqm1dq.f90 !base_objs! || exit 1
ifx %F_OPTS% -exe:tquaddq.exe tquaddq.f90 !base_objs! || exit 1
ifx %F_OPTS% -exe:tpphixdq.exe tpphixdq.f90 !base_objs! || exit 1
@echo off
exit /b 0

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
xcopy /Y /F /I *.exe "%PREFIX%\bin"
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && del /s /q *.exe *.obj *.mod
exit /b 0

:end
