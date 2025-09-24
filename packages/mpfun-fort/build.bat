@echo off
setlocal enabledelayedexpansion
rem
rem  Build script for the current library, it should not be called directly from the
rem  command line, but should be called from mpt.bat.
rem
rem  The values of these environment variables come from mpt.bat:
rem  ARCH            - x64 or x86
rem  PKG_NAME        - name of library
rem  PKG_VER         - version of library
rem  ROOT_DIR        - root location of msvc-pkg
rem  PREFIX          - install location of current library
rem  PREFIX_PATH     - install location of third party libraries
rem  _PREFIX         - default install location if not list in settings.yaml
rem

if "%ROOT_DIR%"=="" (
    echo Don't directly run %~nx0 from command line.
    echo To build !PKG_NAME! and its dependencies, please go to the root location of msvc-pkg, and then press
    echo mpt !PKG_NAME!
    goto :end
)
call "%ROOT_DIR%\compiler.bat" %ARCH% oneapi
set RELS_DIR=%ROOT_DIR%\releases
set SRC_DIR=%RELS_DIR%\%PKG_NAME%-%PKG_VER%
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
set base_source=mpfuna.f90 mpfunbq.f90 mpfunc.f90 mpfund.f90 mpfune.f90        ^
  mpfunf.f90 mpfungq2.f90 mpmodule.f90 second.f90
set base_objs=%base_source:.f90=.obj%
@echo on
ifort %F_OPTS% -c %base_source% || exit 1
ifort %F_OPTS% -heap-arrays -exe:testmpfun.exe testmpfun.f90 !base_objs! || exit 1
ifort %F_OPTS% -heap-arrays -exe:tpslq1.exe tpslq1.f90 !base_objs! || exit 1
ifort %F_OPTS% -heap-arrays -exe:tpslqm1.exe tpslqm1.f90 !base_objs! || exit 1
ifort %F_OPTS% -heap-arrays -exe:tpslqm2.exe tpslqm2.f90 !base_objs! || exit 1
ifort %F_OPTS% -heap-arrays -exe:tpslqm3.exe tpslqm3.f90 !base_objs! || exit 1
ifort %F_OPTS% -heap-arrays -exe:tquad.exe tquad.f90 !base_objs! || exit 1
ifort %F_OPTS% -heap-arrays -exe:tpphix3.exe tpphix3.f90 !base_objs! || exit 1
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
