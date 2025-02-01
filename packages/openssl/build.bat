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
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX

call :configure_stage
call :build_stage
call :install_package
goto :end

rem ==============================================================================
rem  Configure package and ready to build
rem ==============================================================================
:configure_stage
call :clean_build
echo "Configuring %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
if "%ARCH%"=="x64" set HOST_TRIPLET=VC-WIN64A
if "%ARCH%"=="x86" set HOST_TRIPLET=VC-WIN32
perl Configure !HOST_TRIPLET!                                                  ^
  --prefix="%PREFIX:\=/%"                                                      ^
  --openssldir="%PREFIX:\=/%/ssl"                                              ^
  shared                                                                       ^
  CFLAGS="%C_OPTS%"                                                            ^
  CPPFLAGS="%C_DEFS%"                                                          ^
  CXXFLAGS="-EHsc %C_OPTS%"                                                    ^
  || exit 1
exit /b 0

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
nmake || exit 1
exit /b 0

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
nmake install INSTALLDIR="%PREFIX%" || exit 1
if not exist "%PREFIX%\lib\crypto.lib" (
  mklink "%PREFIX%\lib\crypto.lib" "%PREFIX%\lib\libcrypto.lib"
)
if not exist "%PREFIX%\lib\ssl.lib" (
  mklink "%PREFIX%\lib\ssl.lib" "%PREFIX%\lib\libssl.lib"
)
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
nmake clean INSTALLDIR="%PREFIX%"
del /s /q *.tmp makefile.in *.res configdata.pm *.lib *.exp
del /s /q include\openssl\configuration.h
rmdir /s /q doc\man
rmdir /s /q doc\html
exit /b 0

:end
