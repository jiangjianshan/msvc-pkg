@echo off
setlocal enabledelayedexpansion
set LOGONSERVER=\\LOCALHOST
set MSYS=winsymlinks:nativestrict
set MSYS2_PATH_TYPE=inherit
set MSYSTEM=MINGW64

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

