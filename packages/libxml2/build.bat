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
set BUILD_DIR=%SRC_DIR%\build%ARCH:x=%
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS

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
mkdir "%BUILD_DIR%" && cd "%BUILD_DIR%"
cmake -G "Ninja"                                                               ^
  -DBUILD_SHARED_LIBS=ON                                                       ^
  -DCMAKE_BUILD_TYPE=Release                                                   ^
  -DCMAKE_C_COMPILER=cl                                                        ^
  -DCMAKE_C_FLAGS="%C_OPTS% %C_DEFS%"                                          ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                            ^
  -DLIBXML2_WITH_AUTOMATA=ON                                                   ^
  -DLIBXML2_WITH_C14N=ON                                                       ^
  -DLIBXML2_WITH_CATALOG=ON                                                    ^
  -DLIBXML2_WITH_DEBUG=ON                                                      ^
  -DLIBXML2_WITH_EXPR=ON                                                       ^
  -DLIBXML2_WITH_FTP=ON                                                        ^
  -DLIBXML2_WITH_HTML=ON                                                       ^
  -DLIBXML2_WITH_HTTP=ON                                                       ^
  -DLIBXML2_WITH_ICONV=ON                                                      ^
  -DLIBXML2_WITH_ICU=ON                                                        ^
  -DLIBXML2_WITH_ISO8859X=ON                                                   ^
  -DLIBXML2_WITH_LEGACY=ON                                                     ^
  -DLIBXML2_WITH_LZMA=ON                                                       ^
  -DLIBXML2_WITH_MODULES=ON                                                    ^
  -DLIBXML2_WITH_OUTPUT=ON                                                     ^
  -DLIBXML2_WITH_PATTERN=ON                                                    ^
  -DLIBXML2_WITH_PROGRAMS=ON                                                   ^
  -DLIBXML2_WITH_PUSH=ON                                                       ^
  -DLIBXML2_WITH_PYTHON=ON                                                     ^
  -DLIBXML2_WITH_READER=ON                                                     ^
  -DLIBXML2_WITH_REGEXPS=ON                                                    ^
  -DLIBXML2_WITH_SAX1=ON                                                       ^
  -DLIBXML2_WITH_SCHEMAS=ON                                                    ^
  -DLIBXML2_WITH_SCHEMATRON=ON                                                 ^
  -DLIBXML2_WITH_TESTS=ON                                                      ^
  -DLIBXML2_WITH_THREADS=ON                                                    ^
  -DLIBXML2_WITH_THREAD_ALLOC=ON                                               ^
  -DLIBXML2_WITH_TLS=ON                                                        ^
  -DLIBXML2_WITH_TREE=ON                                                       ^
  -DLIBXML2_WITH_UNICODE=ON                                                    ^
  -DLIBXML2_WITH_VALID=ON                                                      ^
  -DLIBXML2_WITH_WRITER=ON                                                     ^
  -DLIBXML2_WITH_XINCLUDE=ON                                                   ^
  -DLIBXML2_WITH_XPATH=ON                                                      ^
  -DLIBXML2_WITH_XPTR=ON                                                       ^
  -DLIBXML2_WITH_XPTR_LOCS=ON                                                  ^
  -DLIBXML2_WITH_ZLIB=ON                                                       ^
  ..
if %errorlevel% neq 0 exit 1
exit /b 0

rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja -j%NUMBER_OF_PROCESSORS%
exit /b 0

rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja install || exit 1
if not exist "%PREFIX%\lib\xml2.lib" (
  mklink "%PREFIX%\lib\xml2.lib" "%PREFIX%\lib\libxml2.lib"
)
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%" && if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
exit /b 0

:end