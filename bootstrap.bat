@echo off

setlocal enabledelayedexpansion

:: Fix error C2226: syntax error: unexpected type 'llvm::sys::UnicodeCharRange'
powershell -command "Set-WinSystemLocale -SystemLocale en-US"

:: https://docs.python.org/3/using/windows.html#removing-the-max-path-limitation
reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t reg_DWORD /d 1

set OLDPATH=%PATH%
set PATH=C:\cygwin64\bin;%PATH%
echo [%~nx0] Checking wget whether has been installed
call :check_wget || goto :end
echo [%~nx0] Checking VC Build Tools whether has been installed
call :check_vcbuildtools vs_buildTools || goto :end
echo [%~nx0] Checking Python whether has been installed
call :check_python || goto :end
echo [%~nx0] Checking meson whether has been installed
call :check_meson || goto :end
echo [%~nx0] Checking Git whether has been installed
call :check_git || goto :end
echo [%~nx0] Checking CMake whether has been installed
call :check_cmake || goto :end
echo [%~nx0] Checking Ninja whether has been installed
call :check_ninja || goto :end
echo [%~nx0] Checking Cygwin whether has been installed
call :check_cygwin || goto :end
goto :end

::==============================================================================
:: Check wget whether has been installed. If not, install it automatically
::==============================================================================
:check_wget
where wget >nul 2>&1
if "%errorlevel%" neq "0" (
  echo [%~nx0] wget is missing, you can download the newest version from https://eternallybored.org/misc/wget
  goto :end
)
exit /b 0

::==============================================================================
:: Check Visual C++ Build Tools whether has been installed. If not, install it
:: automatically
::==============================================================================
:check_vcbuildtools
set vsinstall=
if "%VSINSTALLDIR%" neq "" (
  set "vsinstall=%VSINSTALLDIR%"
) else (
  if not exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" goto :install_vcbuildtools
  for /f "delims=" %%r in ('^""%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -nologo -latest -products "*" -all -property installationPath^"') do set vsinstall=%%r
)
if exist "%vsinstall%\VC\Auxiliary\Build\vcvarsall.bat" exit /b 0
:install_vcbuildtools
  cd /d %~dp0
  :: Download the Build Tools bootstrapper
  if "%1"=="vs_community" set vsinstaller=vs_community.exe
  if "%1"=="vs_buildTools" set vsinstaller=vs_buildTools.exe
  if not exist "!vsinstaller!" curl -SL -o !vsinstaller! https://aka.ms/vs/17/release/!vsinstaller! || goto :end
  :: https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022
  :: https://learn.microsoft.com/en-us/visualstudio/install/command-line-parameter-examples?view=vs-2022
  :: https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022
  if "%1"=="vs_community" (
    !vsinstaller!                                                                         ^
      --includeRecommended                                                                ^
      --wait                                                                              ^
      --passive                                                                           ^
      --norestart                                                                         ^
      --removeOos true                                                                    ^
      --downloadThenInstall                                                               ^
      --addProductLang En-us                                                              ^
      --add Microsoft.VisualStudio.Workload.NativeDesktop                                 ^
      --add Microsoft.Net.Component.4.8.1.TargetingPack                                   ^
      --add Microsoft.VisualStudio.Component.VC.ATL                                       ^
      --add Microsoft.VisualStudio.Component.VC.ATLMFC                                    ^
      --add Microsoft.VisualStudio.Component.VC.ASAN                                      ^
      --remove Component.Microsoft.VisualStudio.LiveShare.2022                            ^
      --remove Microsoft.VisualStudio.ComponentGroup.WebToolsExtensions                   ^
      --remove Microsoft.VisualStudio.Component.Debugger.JustInTime                       ^
      --remove Microsoft.VisualStudio.Component.IntelliCode                               ^
      --remove Microsoft.VisualStudio.Component.NuGet                                     ^
      --remove Microsoft.VisualStudio.Component.JavaScript.TypeScript                     ^
      --remove Microsoft.VisualStudio.Component.Roslyn.LanguageServices                   ^
      --remove Microsoft.VisualStudio.Component.TypeScript.TSServer                       ^
      --remove Component.VisualStudio.GitHub.Copilot                                      ^
      --remove Microsoft.VisualStudio.Component.VC.DiagnosticTools                        ^
      --remove Microsoft.VisualStudio.Component.SecurityIssueAnalysis                     ^
      --remove Microsoft.VisualStudio.Component.Windows11Sdk.WindowsPerformanceToolkit    ^
      --remove Microsoft.VisualStudio.Component.CppBuildInsights                          ^
      --remove Microsoft.VisualStudio.Component.VC.TestAdapterForBoostTest                ^
      --remove Microsoft.VisualStudio.Component.VC.TestAdapterForGoogleTest               ^
      --remove Microsoft.VisualStudio.Component.Vcpkg                                     ^
      --remove Microsoft.VisualStudio.Component.VC.CMake.Project	                        ^
      --remove Microsoft.VisualStudio.Component.TestTools.BuildTools
  ) else (
    !vsinstaller!                                                                         ^
      --includeRecommended                                                                ^
      --wait                                                                              ^
      --passive                                                                           ^
      --norestart		                                                                       ^
      --removeOos true                                                                    ^
      --downloadThenInstall	                                                              ^
      --addProductLang En-us                                                              ^
      --add Microsoft.VisualStudio.Workload.VCTools                                       ^
      --add Microsoft.Net.Component.4.8.1.TargetingPack	                                  ^
      --add Microsoft.VisualStudio.Component.VC.ATL	                                      ^
      --add Microsoft.VisualStudio.Component.VC.ATLMFC                                    ^
      --add Microsoft.VisualStudio.Component.VC.ASAN                                      ^
      --remove Microsoft.VisualStudio.Component.VC.CMake.Project	                        ^
      --remove Microsoft.VisualStudio.Component.TestTools.BuildTools
  )
  :: cleanup
  del /q !vsinstaller!
)
exit /b 0


::==============================================================================
:: Check ninja whether has been installed. If not, install it automatically
::==============================================================================
:check_ninja
where ninja >nul 2>&1
if "%errorlevel%" neq "0" (
  echo [%~nx0] ninja is missing, you can download the newest version from https://github.com/ninja-build/ninja
)
exit /b 0


::==============================================================================
:: Check python whether has been installed, If not, install it automatically
::==============================================================================
:check_python
where python >nul 2>&1
if "%errorlevel%" neq "0" (
  echo [%~nx0] Please install python 3, you can download the newest installer from https://www.python.org/downloads/
)
exit /b 0


::==============================================================================
:: check cmake whether has been installed
::==============================================================================
:check_cmake
where cmake >nul 2>&1
if "%errorlevel%" neq "0" (
  echo [%~nx0] Please install cmake, you can download the newest installer from https://cmake.org/download/
)
exit /b 0


::==============================================================================
:: check git whether has been installed
::==============================================================================
:check_git
where git >nul 2>&1
if "%errorlevel%" neq "0" (
  echo [%~nx0] Please install git, you can download the newest installer from https://www.git-scm.com/download/win
)
exit /b 0


::==============================================================================
:: install cygwin if it is not exist
::==============================================================================
:check_cygwin
setlocal
set cygwin_url="https://www.cygwin.com/setup-x86_64.exe"
set cygwin_prefix="C:\cygwin64"
if not exist "!cygwin_prefix!" (
  if exist setup-x86_64.exe (
    echo [%~nx0] Delete the old version of setup-x86_64.exe
    del /s /q setup-x86_64.exe
  )
  echo [%~nx0] Download a new version of setup-x86_64.exe
  wget --no-check-certificate !cygwin_url! -O setup-x86_64.exe || goto :end
  echo [%~nx0] Installing cygwin
  :: see https://cygwin.com/faq/faq.html#faq.setup.cli
  setup-x86_64.exe -a x86_64 -d -g -r -n -N -q -O -s https://mirrors.tuna.tsinghua.edu.cn/cygwin/ -R !cygwin_prefix! -P "cygrunsrv,autoconf,automake,libtool,make,pkg-config,patch,flex,bison,dos2unix,gperf"
  echo [%~nx0] Removing all caches
  for /d /r %%i in (*mirrors.tuna.tsinghua.edu.cn*) do @rmdir /s /q "%%i"
  echo [%~nx0] Speeding up cygwin
  bash utils/config-cygwin.sh
  del /s /q setup-x86_64.exe
  echo [%~nx0] Done
)
exit /b 0


::==============================================================================
:: check meson whether has been installed
::==============================================================================
:check_meson
where meson >nul 2>&1
if "%errorlevel%" neq "0" (
  echo [%~nx0] Installing meson
  python -m pip install --upgrade meson || goto :end
  echo [%~nx0] Done
)
exit /b 0

:end
set PATH=%OLDPATH%
set vsinstall=
set vswhere=
set vcvarsall=
