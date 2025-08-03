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
call "%ROOT_DIR%\compiler.bat" %ARCH%
set RELS_DIR=%ROOT_DIR%\releases
set SRC_DIR=%RELS_DIR%\%PKG_NAME%-%PKG_VER%
set BUILD_DIR=%SRC_DIR%
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX

call :build_stage
call :install_package
goto :end

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
set base_source=blocksort.c huffman.c crctable.c randtable.c compress.c decompress.c bzlib.c
cl %C_OPTS% %C_DEFS% /c %base_source%
link /nologo /DLL /IMPLIB:bz2.lib /DEF:libbz2.def /OUT:bz2.dll %base_source:.c=.obj%
cl %C_OPTS% %C_DEFS% /c bzip2.c
link /nologo /OUT:bzip2.exe bzip2.obj bz2.lib
lib /OUT:libbz2.lib %base_source:.c=.obj%
cl %C_OPTS% %C_DEFS% /c bzip2recover.c
link /nologo /OUT:bzip2recover.exe bzip2recover.obj
exit /b 0

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
if not exist "%PREFIX%\bin" mkdir "%PREFIX%\bin"
if not exist "%PREFIX%\include" mkdir "%PREFIX%\include"
if not exist "%PREFIX%\lib" mkdir "%PREFIX%\lib"
if not exist "%PREFIX%\share\man\man1" mkdir "%PREFIX%\share\man\man1"
cd "%BUILD_DIR%" && (
	xcopy /Y /F bzip2.exe "%PREFIX%\bin\bzip2.exe"
	xcopy /Y /F bzip2.exe "%PREFIX%\bin\bunzip2.exe"
	xcopy /Y /F bzip2.exe "%PREFIX%\bin\bzcat.exe"
	xcopy /Y /F bzip2recover.exe "%PREFIX%\bin\bzip2recover.exe"
	xcopy /Y /F bzip2.1 "%PREFIX%\share\man\man1"
	xcopy /Y /F bzlib.h "%PREFIX%\include"
	xcopy /Y /F /I *.dll "%PREFIX%\bin"
	xcopy /Y /F /I *.lib "%PREFIX%\lib"
	xcopy /Y /F bzgrep "%PREFIX%\bin"
	if not exist "%PREFIX%\bin\bzegrep" (
  	mklink "%PREFIX%\bin\bzegrep" "%PREFIX%\bin\bzgrep"
  )
	if not exist "%PREFIX%\bin\bzfgrep" (
	  mklink "%PREFIX%\bin\bzfgrep" "%PREFIX%\bin\bzgrep"
	)
	xcopy /Y /V /F bzmore "%PREFIX%\bin"
	if not exist "%PREFIX%\bin\bzless" (
	  mklink "%PREFIX%\bin\bzless" "%PREFIX%\bin\bzmore"
	)
	xcopy /Y /V /F bzdiff "%PREFIX%\bin"
	if not exist "%PREFIX%\bin\bzcmp" (
	  mklink "%PREFIX%\bin\bzcmp" "%PREFIX%\bin\bzdiff"
	)
	xcopy /Y /F /I *.1 "%PREFIX%\share\man\man1"
	echo .dll man1\bzgrep.1> "%PREFIX%\share\man\man1\bzegrep.1"
	echo .dll man1\bzgrep.1> "%PREFIX%\share\man\man1\bzfgrep.1"
	echo .dll man1\bzmore.1> "%PREFIX%\share\man\man1\bzless.1"
	echo .dll man1\bzdiff.1> "%PREFIX%\share\man\man1\bzcmp.1"
)
echo "Generating bzip2.pc to %PREFIX%\lib\pkgconfig"
set PC_FILE=%PREFIX%\lib\pkgconfig\bzip2.pc
if not exist "%PREFIX%\lib\pkgconfig" mkdir "%PREFIX%\lib\pkgconfig"
where cygpath >nul 2>&1
if "%errorlevel%" neq "0" (
	echo prefix=%PREFIX:\=/%> %PC_FILE%
	echo exec_prefix=%PREFIX:\=/%>> %PC_FILE%
	echo libdir=%PREFIX:\=/%/lib>> %PC_FILE%
	echo sharedlibdir=%PREFIX:\=/%/lib>> %PC_FILE%
	echo includedir=%PREFIX:\=/%/include>> %PC_FILE%
) else (
  for /f "delims=" %%i in ('cygpath -u "%PREFIX%"') do set PREFIX_UNIX=%%i
	echo prefix=!PREFIX_UNIX!> %PC_FILE%
	echo exec_prefix=!PREFIX_UNIX!>> %PC_FILE%
	echo libdir=!PREFIX_UNIX!/lib>> %PC_FILE%
	echo sharedlibdir=!PREFIX_UNIX!/lib>> %PC_FILE%
	echo includedir=!PREFIX_UNIX!/include>> %PC_FILE%
)
echo:>> %PC_FILE%
echo Name: bzip2>> %PC_FILE%
echo Description: bzip2 compression library>> %PC_FILE%
echo Version: 1.0.8>> %PC_FILE%
echo:>> %PC_FILE%
echo Requires:>> %PC_FILE%
echo Libs: -L${libdir} -L${sharedlibdir} -lbz2>> %PC_FILE%
echo Cflags: -I${includedir}>> %PC_FILE%
echo "Done"
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && del /s *.obj *.lib *.dll *.exe *.rb2 *.tst
exit /b 0

:end
