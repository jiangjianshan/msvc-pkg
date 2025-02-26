@echo off
rem
rem  This is the initial call entry of msvc-pkg from command line
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

setlocal enabledelayedexpansion

set LOGONSERVER=\\LOCALHOST
set MSYS=winsymlinks:nativestrict
set MSYS2_PATH_TYPE=inherit
rem NOTE: It's not necessary to set MSYSTEM because we don't use mingw-w64 toolchain.
rem       The environment variable MSYSTEM will impact the build environment of some
rem       packages, e.g. gobject-introspection. The ccompiler.py will get compiler_name
rem       depend on this environment variable. But in fact all build.bat are not in
rem       msys2 environment.
rem set MSYSTEM=MINGW64

goto begin

rem ---------------------------------------------------------------------------
rem Help information
rem ---------------------------------------------------------------------------
:usage
echo Script for building open source libraries on Windows,
echo  Usage: mpt [help^|--help^|-h] [arch] [packages]
echo
echo  Optional Options:
echo  help ^| --help ^| -h    : Display this help
echo  arch                    : Available value are x86 or x64. [default: x64]
echo  packages                : list of those packages want to be built.
echo                            [default: build all available packages and their
echo                            dependencies if they haven't built successful yet]
echo  Example:
echo    mpt
echo    mpt x86 gmp gettext
echo    mpt x64
echo    mpt gmp gettext
goto end

rem ---------------------------------------------------------------------------
rem The first entry point
rem ---------------------------------------------------------------------------
:begin
if "%1"=="help" goto usage
if "%1"=="--help" goto usage
if "%1"=="-h" goto usage
python mpt.py %*

