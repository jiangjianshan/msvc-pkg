@echo off
setlocal enabledelayedexpansion
rem
rem  Build script for the current library, it should not be called directly from the
rem  command line, but should be called from mpt.py.
rem
rem  The values of these environment variables come from mpt.py:
rem  ARCH            - x64 or x86
rem  ROOT_DIR        - root location of msvc-pkg
rem  PREFIX          - install location of current library
rem  PREFIX_PATH     - install location of third party libraries
rem  _PREFIX         - default install location if not list in settings.yaml
rem
rem  Copyright (c) 2024 Jianshan Jiang
rem
rem  Permission is hereby granted, free of charge, to any person obtaining a copy
rem  of this software and associated documentation files (the "Software"), to deal
rem  in the Software without restriction, including without limitation the rights
rem  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
rem  copies of the Software, and to permit persons to whom the Software is
rem  furnished to do so, subject to the following conditions:
rem
rem  The above copyright notice and this permission notice shall be included in all
rem  copies or substantial portions of the Software.
rem
rem  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
rem  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
rem  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
rem  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
rem  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
rem  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
rem  SOFTWARE.

for /f "delims=" %%i in ('yq -r ".name" config.yaml') do set PKG_NAME=%%i
for /f "delims=" %%i in ('yq -r ".version" config.yaml') do set PKG_VER=%%i
if "%ROOT_DIR%"=="" (
    echo Don't directly run %~nx0 from command line.
    echo To build !PKG_NAME! and its dependencies, please go to the root location of msvc-pkg, and then press
    echo mpt !PKG_NAME!
    goto :end
)
call "%ROOT_DIR%\compiler.bat" %ARCH% oneapi
set RELS_DIR=%ROOT_DIR%\releases
set SRC_DIR=%RELS_DIR%\%PKG_NAME%-%PKG_VER%
set BUILD_DIR=%SRC_DIR%
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:strict -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX
set F_OPTS=-nologo -MD -Qdiag-disable:10448 -fast -fp:strict -names:lowercase -assume:nounderscore -Qopenmp -Qopenmp-simd -fpp

call :build_stage
call :install_package
goto :end

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Cleaning %PKG_NAME% %PKG_VER%"
call :clean_build
if not defined GMP_PREFIX set GMP_PREFIX=%_PREFIX%
if not defined MPFR_PREFIX set MPFR_PREFIX=%_PREFIX%
echo "Building %PKG_NAME% %PKG_VER%"
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

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%\fortran-var1" && copy /Y /V *.exe "%PREFIX%\bin"
cd "%BUILD_DIR%\fortran-var2" && copy /Y /V *.exe "%PREFIX%\bin"
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%\fortran-var1" && del /s /q *.exe *.obj *.mod
cd "%BUILD_DIR%\fortran-var2" && del /s /q *.exe *.obj *.mod
exit /b 0

:end
