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
set BUILD_DIR=%SRC_DIR%\fortran
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:strict -Qopenmp -Qopenmp-simd
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX
set F_OPTS=-nologo -MD -Qdiag-disable:10448 -fast -fp:strict -Qopenmp -Qopenmp-simd

call :build_stage
call :install_package
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
ifort %F_OPTS% -c %base_source%
ifort %F_OPTS% -heap-arrays -exe:testmpfun.exe testmpfun.f90 !base_objs!
ifort %F_OPTS% -heap-arrays -exe:tpslq1.exe tpslq1.f90 !base_objs!
ifort %F_OPTS% -heap-arrays -exe:tpslqm1.exe tpslqm1.f90 !base_objs!
ifort %F_OPTS% -heap-arrays -exe:tpslqm2.exe tpslqm2.f90 !base_objs!
ifort %F_OPTS% -heap-arrays -exe:tpslqm3.exe tpslqm3.f90 !base_objs!
ifort %F_OPTS% -heap-arrays -exe:tquad.exe tquad.f90 !base_objs!
ifort %F_OPTS% -heap-arrays -exe:tpphix3.exe tpphix3.f90 !base_objs!
@echo off
exit /b 0

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
copy /Y /V *.exe "%PREFIX%\bin"
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
