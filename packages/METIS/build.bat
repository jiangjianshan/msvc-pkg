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
set BUILD_DIR=%SRC_DIR%\build\windows
set OPTIONS=-nologo -MD -diagnostics:column -wd4819 -openmp:llvm
set DEFINES=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS


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
cd "%SRC_DIR%" && vsgen.bat                                                    ^
  -DBUILD_SHARED_LIBS=ON                                                       ^
  -DCMAKE_C_COMPILER=cl                                                        ^
  -DCMAKE_C_FLAGS="%OPTIONS% %DEFINES%"                                        ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                            ^
  -DGKLIB_PATH="%GKLIB_PREFIX%"                                                ^
  -DOPENMP=ON                                                                  ^
  -DGKREGEX=ON                                                                 ^
  -DGKRAND=ON
if %errorlevel% neq 0 exit 1
exit /b 0


rem ==============================================================================
rem  Build package
rem ==============================================================================
:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && msbuild METIS.sln /p:Configuration=Release /p:Platform=x64 ^
    /p:PlatformToolset=v143 /p:UseEnv=true /p:SkipUWP=true
exit /b 0


rem ==============================================================================
rem  Install package
rem ==============================================================================
:install_package
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && (
  copy /Y /V "programs\Release\*.exe" "%PREFIX%%\bin"
  copy /Y /V "libmetis\Release\*.lib" "%PREFIX%\lib"
  copy /Y /V "%SRC_DIR%\include\*.h" "%PREFIX%\include"
)
call :clean_build
exit /b 0


rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%"
if exist "build" rmdir /s /q "build"
exit /b 0


:end
