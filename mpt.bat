@echo off
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
echo  Usage: mpt [help^|--help^|-h] [arch] [ports]
echo
echo  Optional Options:
echo  help ^| --help ^| -h      : Display this help
echo  arch                    : Available value are x86 or x64. [default: x64]
echo  ports                   : list of those ports want to be built.
echo                            [default: build all available ports and their
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

