@echo off
rem Set Visual C++ Build Tools environment
set vsinstall=
set vswhere=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe
if "%VSINSTALLDIR%" NEQ "" (
  set "vsinstall=%VSINSTALLDIR%"
) else (
  for /f "delims=" %%r in ('^""%vswhere%" -nologo -latest -products "*" -all -property installationPath^"') do set vsinstall=%%r
)
set "vcvarsall=%vsinstall%\VC\Auxiliary\Build\vcvarsall.bat"
if exist "%vsinstall%\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt" (
  set /p vsversion=<"%vsinstall%\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt"
)
if not exist "%vcvarsall%" (
  echo Can't find any installation of Visual Studio
  goto :end
)
echo Visual C++ Tools Version     : %vsversion%
call "%vcvarsall%" %1

rem Set Intel OneAPI environment
set "ONEAPI_ROOT=%ProgramFiles(x86)%\Intel\oneAPI"
if exist "%ONEAPI_ROOT%" (
  if "%1" == "x64" call "%ONEAPI_ROOT%\setvars.bat" intel64 vs2022 --include-intel-llvm
  if "%1" == "x86" call "%ONEAPI_ROOT%\setvars.bat" ia32 vs2022 --include-intel-llvm
)

rem Set CUDA environment
if exist "%CUDA_PATH%" (
  set "PATH=%PATH%;%CUDA_PATH%\extras\demo_suite"
  set "INCLUDE=%CUDA_PATH%\include;!INCLUDE!"
  set "LIB=%CUDA_PATH%\lib\x64;%CUDA_PATH%\lib\win32;!LIB!"
)

rem NOTE:
rem 1. There may have name conflict between third-party libraries and compiler's one, e.g. icuuc.lib.
rem    In order to link the correct one. The paths of some third-party libraries must be placed in
rem    front of the compiler's path
rem 2. Taken care of bin PATH, let it updated in mpt.py but not here. Because some program must use the
rem    one from Git for Windows, e.g. m4.
set remain=%PREFIX_PATH%
:loop
for /f "tokens=1* delims=;" %%a in ("%remain%") do (
  if exist "%%a\include" set "INCLUDE=%%a\include;!INCLUDE!"
  if exist "%%a\lib" set "LIB=%%a\lib;!LIB!"
  if exist "%%a\lib\cmake" set "CMAKE_PREFIX_PATH=%%a;!CMAKE_PREFIX_PATH!"
  if exist "%%a\lib\pkgconfig" set "PKG_CONFIG_PATH=%%a\lib\pkgconfig;!PKG_CONFIG_PATH!"
  set remain=%%b
)
if defined remain goto :loop

:end
set vsinstall=
set vswhere=
set vsversion=
