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
set BUILD_DIR=%SRC_DIR%
set OPTIONS=-nologo -MD -diagnostics:column -wd4819 -openmp:llvm
set DEFINES=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS


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
cl %OPTIONS% %DEFINES% /c %base_source%
link /nologo /DLL /DEF:libbz2.def /OUT:libbz2.dll %base_source:.c=.obj%
cl %OPTIONS% %DEFINES% /c bzip2.c
link /nologo /OUT:bzip2.exe bzip2.obj libbz2.lib
cl %OPTIONS% %DEFINES% /c bzip2recover.c
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
	copy /Y /V bzip2.exe "%PREFIX%\bin\bzip2.exe"
	copy /Y /V bzip2.exe "%PREFIX%\bin\bunzip2.exe"
	copy /Y /V bzip2.exe "%PREFIX%\bin\bzcat.exe"
	copy /Y /V bzip2recover.exe "%PREFIX%\bin\bzip2recover.exe"
	copy /Y /V bzip2.1 "%PREFIX%\share\man\man1"
	copy /Y /V bzlib.h "%PREFIX%\include"
	copy /Y /V *.dll "%PREFIX%\bin"
	copy /Y /V *.lib "%PREFIX%\lib"
	copy /Y /V bzgrep "%PREFIX%\bin"
	if not exist "%PREFIX%\bin\bzegrep" (
  	mklink "%PREFIX%\bin\bzegrep" "%PREFIX%\bin\bzgrep"
  )
	if not exist "%PREFIX%\bin\bzfgrep" (
	  mklink "%PREFIX%\bin\bzfgrep" "%PREFIX%\bin\bzgrep"
	)
	copy /Y /V bzmore "%PREFIX%\bin"
	if not exist "%PREFIX%\bin\bzless" (
	  mklink "%PREFIX%\bin\bzless" "%PREFIX%\bin\bzmore"
	)
	copy /Y /V bzdiff "%PREFIX%\bin"
	if not exist "%PREFIX%\bin\bzcmp" (
	  mklink "%PREFIX%\bin\bzcmp" "%PREFIX%\bin\bzdiff"
	)
	copy /Y /V *.1 "%PREFIX%\share\man\man1"
	echo .dll man1\bzgrep.1> "%PREFIX%\share\man\man1\bzegrep.1"
	echo .dll man1\bzgrep.1> "%PREFIX%\share\man\man1\bzfgrep.1"
	echo .dll man1\bzmore.1> "%PREFIX%\share\man\man1\bzless.1"
	echo .dll man1\bzdiff.1> "%PREFIX%\share\man\man1\bzcmp.1"
)
echo "Generating bzip2.pc"
if not exist "%PREFIX%\lib\pkgconfig" mkdir "%PREFIX%\lib\pkgconfig"
echo prefix=%PREFIX:\=/%> "%PREFIX%\lib\pkgconfig\bzip2.pc"
echo exec_prefix=%PREFIX:\=/%>> %PREFIX%\lib\pkgconfig\bzip2.pc"
echo libdir=%PREFIX:\=/%/lib>> %PREFIX%\lib\pkgconfig\bzip2.pc"
echo sharedlibdir=%PREFIX:\=/%/lib>> %PREFIX%\lib\pkgconfig\bzip2.pc"
echo includedir=%PREFIX:\=/%/include>> %PREFIX%\lib\pkgconfig\bzip2.pc"
echo:>> %PREFIX%\lib\pkgconfig\bzip2.pc"
echo Name: bzip2>> "%PREFIX%\lib\pkgconfig\bzip2.pc"
echo Description: bzip2 compression library>> "%PREFIX%\lib\pkgconfig\bzip2.pc"
echo Version: 1.0.8>> "%PREFIX%\lib\pkgconfig\bzip2.pc"
echo:>> %PREFIX%\lib\pkgconfig\bzip2.pc"
echo Requires:>> %PREFIX%\lib\pkgconfig\bzip2.pc"
echo Libs: -L${libdir} -L${sharedlibdir} -lbz2>> %PREFIX%\lib\pkgconfig\bzip2.pc"
echo Cflags: -I${includedir}>> %PREFIX%\lib\pkgconfig\bzip2.pc"
echo "Done"
if not exist "%PREFIX%\lib\bz2.lib" (
  mklink "%PREFIX%\lib\bz2.lib" "%PREFIX%\lib\libz2.lib"
)
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
