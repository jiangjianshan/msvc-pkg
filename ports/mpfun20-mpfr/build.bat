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
set BUILD_DIR=%SRC_DIR%
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:strict -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX
set F_OPTS=-nologo -MD -Qdiag-disable:10448 -fast -fp:strict -names:lowercase -assume:nounderscore -Qopenmp -Qopenmp-simd -fpp

call :clean_stage
call :build_stage
call :install_stage
call :clean_stage
goto :end

:clean_stage
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%\fortran-var1" && del /s /q *.exe *.obj *.mod
cd "%BUILD_DIR%\fortran-var2" && del /s /q *.exe *.obj *.mod
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
if not defined GMP_PREFIX set GMP_PREFIX=%_PREFIX%
if not defined MPFR_PREFIX set MPFR_PREFIX=%_PREFIX%
cd "%BUILD_DIR%\fortran-var1"
set libs=%GMP_PREFIX%\lib\gmp.lib %MPFR_PREFIX%\lib\mpfr.lib
set base_source=mpfuna.f90 mpfund.f90 mpfune.f90 mpfunf.f90 mpfung1.f90        ^
  mpfunh1.f90 mpmodule.f90 second.f90
set base_objs=%base_source:.f90=.obj%
@echo on
ifx %F_OPTS% -c %base_source% || exit 1
cl %C_OPTS% -c mpinterface.c || exit 1
ifx %F_OPTS% -heap-arrays -exe:testmpfun.exe testmpfun.f90 !base_objs!         ^
  mpinterface.obj !libs! || exit 1
ifx %F_OPTS% -heap-arrays -exe:tpolysolve.exe tpolysolve.f90 !base_objs!       ^
  mpinterface.obj !libs! || exit 1
ifx %F_OPTS% -heap-arrays -exe:tpslq1.exe tpslq1.f90 !base_objs!               ^
  mpinterface.obj !libs! || exit 1
ifx %F_OPTS% -heap-arrays -exe:tpslqm1.exe tpslqm1.f90 !base_objs!             ^
  mpinterface.obj !libs! || exit 1
ifx %F_OPTS% -heap-arrays -exe:tpphix3.exe tpphix3.f90 !base_objs!             ^
  mpinterface.obj !libs! || exit 1
ifx %F_OPTS% -heap-arrays -exe:tquad.exe tquad.f90 !base_objs!                 ^
  mpinterface.obj !libs! || exit 1
@echo off
cd "%BUILD_DIR%\fortran-var2"
set base_source=mpfuna.f90 mpfund.f90 mpfune.f90 mpfunf.f90 mpfung2.f90        ^
  mpfunh2.f90 mpmodule.f90 second.f90
set base_objs=%base_source:.f90=.obj%
@echo on
ifx %F_OPTS% -c %base_source% || exit 1
cl %C_OPTS% -c mpinterface.c || exit 1
ifx %F_OPTS% -heap-arrays -exe:testmpfun.exe testmpfun.f90 !base_objs!         ^
  mpinterface.obj !libs! || exit 1
ifx %F_OPTS% -heap-arrays -exe:tpolysolve.exe tpolysolve.f90 !base_objs!       ^
  mpinterface.obj !libs! || exit 1
ifx %F_OPTS% -heap-arrays -exe:tpslq1.exe tpslq1.f90 !base_objs!               ^
  mpinterface.obj !libs! || exit 1
ifx %F_OPTS% -heap-arrays -exe:tpslqm1.exe tpslqm1.f90 !base_objs!             ^
  mpinterface.obj !libs! || exit 1
ifx %F_OPTS% -heap-arrays -exe:tpslqm2.exe tpslqm2.f90 !base_objs!             ^
  mpinterface.obj !libs! || exit 1
ifx %F_OPTS% -heap-arrays -exe:tpslqm3.exe tpslqm3.f90 !base_objs!             ^
  mpinterface.obj !libs! || exit 1
ifx %F_OPTS% -heap-arrays -exe:tpphix3.exe tpphix3.f90 !base_objs!             ^
  mpinterface.obj !libs! || exit 1
ifx %F_OPTS% -heap-arrays -exe:tquad.exe tquad.f90 !base_objs!                 ^
  mpinterface.obj !libs! || exit 1
@echo off
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%\fortran-var1" && xcopy /Y /F /I *.exe "%PREFIX%\bin"
cd "%BUILD_DIR%\fortran-var2" && xcopy /Y /F /I *.exe "%PREFIX%\bin"
exit /b 0

:end
