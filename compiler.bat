@echo off
rem
rem  Set Visual C++ Build Tools environment
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

rem The unix tools may be need for some libraries
for /f "delims=" %%i in ('where git.exe') do set GIT_ROOT=%%i
set "BASH_ROOT=!GIT_ROOT:~0,-12!\usr\bin"
set "PATH=%PATH%;!BASH_ROOT!"

:end
set vsinstall=
set vswhere=
set vsversion=
