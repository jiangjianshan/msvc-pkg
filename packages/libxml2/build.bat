@echo off
setlocal enabledelayedexpansion
rem
rem Build script for the current library.
rem
rem This script is designed to be invoked by `mpt.bat` using the command `mpt <library_name>`.
rem It relies on specific environment variables set by the `mpt` process to function correctly.
rem
rem Environment Variables Provided by `mpt` (in addition to system variables):
rem   ARCH          - Target architecture to build for. Valid values: `x64` or `x86`.
rem   PKG_NAME      - Name of the current library being built.
rem   PKG_VER       - Version of the current library being built.
rem   ROOT_DIR      - Root directory of the msvc-pkg project.
rem   SRC_DIR       - Source code directory of the current library.
rem   PREFIX        - **Actual installation path prefix** for the *current* library after successful build.
rem                   This path is where the built artifacts for *this specific library* will be installed.
rem                   It usually equals `_PREFIX`, but **may differ** if a non-default installation path
rem                   was explicitly specified for this library (e.g., `D:\LLVM` for `llvm-project`).
rem   PREFIX_PATH   - List of installation directory prefixes for third-party dependencies.
rem   _PREFIX       - **Default installation path prefix** for all built libraries.
rem                   This is the root directory where libraries are installed **unless overridden**
rem                   by a specific `PREFIX` setting for an individual library.
rem
rem   For each direct dependency `{Dependency}` of the current library:
rem     {Dependency}_SRC - Source code directory of the dependency `{Dependency}`.
rem     {Dependency}_VER - Version of the dependency `{Dependency}`.

call "%ROOT_DIR%\compiler.bat" %ARCH%
set BUILD_DIR=%SRC_DIR%\build%ARCH:x=%
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX

call :configure_stage
call :build_stage
call :install_stage
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
:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja install || exit 1
if not exist "%PREFIX%\lib\xml2.lib" (
  mklink "%PREFIX%\lib\xml2.lib" "%PREFIX%\lib\libxml2.lib"
)
pushd "%PREFIX%\lib\pkgconfig"
sed -e "s#\([=]\|-[IL]\|^\)\([A-Za-z]\):[\\/]#\1/\L\2/#g" -i libxml-2.0.pc
popd
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
