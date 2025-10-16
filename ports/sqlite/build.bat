@echo off
chcp 65001 > nul
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

call "%ROOT_DIR%\compiler.bat" %ARCH%
set BUILD_DIR=%SRC_DIR%
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX
set CL=-MP %C_OPTS% %C_DEFS%

call :clean_stage
call :build_stage
call :install_stage
call :clean_stage
goto :end

:clean_stage
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && del *.o *.obj *.exp *.lib *.dll *.exe *.ilk *.pdb *.lo
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
if not defined ICU4C_PREFIX set ICU4C_PREFIX=%_PREFIX%
if not defined TCL_PREFIX set TCL_PREFIX=%_PREFIX%
if not defined ZLIB_PREFIX set ZLIB_PREFIX=%_PREFIX%
nmake /K /f Makefile.msc TCLDIR=!TCL_PREFIX!                                   ^
  CCOPTS="%C_OPTS% %C_DEFS%"                                                   ^
  BUILD_ZLIB=0                                                                 ^
  USE_ZLIB=1                                                                   ^
  ZLIBDIR=!ZLIB_PREFIX!                                                        ^
  USE_ICU=1                                                                    ^
  ICUDIR=!ICU4C_PREFIX!                                                        ^
  USE_CRT_DLL=1                                                                ^
  DYNAMIC_SHELL=1                                                              ^
  PLATFORM=%ARCH%                                                              ^
  || exit 1
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
if not exist "%PREFIX%\bin" mkdir "%PREFIX%\bin"
if not exist "%PREFIX%\include" mkdir "%PREFIX%\include"
if not exist "%PREFIX%\lib" mkdir "%PREFIX%\lib"
cd "%BUILD_DIR%" && (
  xcopy /Y /F /I *.exe %PREFIX%\bin || exit 1
  xcopy /Y /F /I *.dll %PREFIX%\bin || exit 1
  xcopy /Y /F /I *.lib %PREFIX%\lib || exit 1
  xcopy /Y /F /I sqlite3.h %PREFIX%\include
)
exit /b 0

:end
