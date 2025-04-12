@echo off
rem
rem  This is a script used by msvc-pkg to check whether certain items are missing
rem  from environment dependencies. If a missing item is detected, it will initiate
rem  a download, unattended and interactive installation.
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

echo Checking dependencies to run msvc-pkg
rem  Fix error C2226: syntax error: unexpected type 'llvmrem sysrem UnicodeCharRange'
for /f "tokens=2*" %%a in ('powershell -command "Get-WinSystemLocale" ^| findstr en-US') do set SYSTEM_LOCALE=%%a
if "%SYSTEM_LOCALE%" neq "en-US" powershell -command "Set-WinSystemLocale -SystemLocale en-US"

rem  https://docs.python.org/3/using/windows.html#removing-the-max-path-limitation
reg query HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled >nul 2>&1
if "%errorlevel%" neq "0" reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t reg_DWORD /d 1

if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set ARCH=x64
) else (
    set ARCH=x86
)

set OLDPATH=%PATH%
set PATH=%PATH%;C:\Python312\Scripts;C:\Python312;%USERPROFILE%\.cargo\bin;%~dp0%ARCH%\bin

cd /d %~dp0
if not exist "%ARCH%\bin" mkdir "%ARCH%\bin"
if not exist "%~dp0\tags" mkdir "%~dp0\tags"

call :check_wget || goto :end
call :check_vcbuildtools || goto :end
call :check_cuda || goto :end
call :check_oneapi || goto :end
call :check_python || goto :end
call :check_git || goto :end
call :git_bash_add_tools || goto :end
call :check_cmake || goto :end
call :check_rust || goto :end
call :check_ninja || goto :end
call :check_yq || goto :end

if not exist "%USERPROFILE%\.gitconfig" (
  rem Dealing with line endings
  rem See https://stackoverflow.com/questions/1967370/git-replacing-lf-with-crlf
  git config --global core.autocrlf false
  rem Speed up git handling if on bash environment
  git config --system core.filemode false
  rem Changed the default behavior of Git for Windows
  git config --global core.ignorecase false
) else (
  git config --global --list | findstr core.autocrlf=false >nul 2>&1
  if "%errorlevel%" neq "0" git config --global core.autocrlf false
  git config --system --list | findstr core.filemode=false >nul 2>&1
  if "%errorlevel%" neq "0" git config --system core.filemode false
  git config --global --list | findstr core.ignorecase=false >nul 2>&1
  if "%errorlevel%" neq "0" git config --global core.ignorecase false
)

goto :end

rem ==============================================================================
rem Check Visual C++ Build Tools whether has been installed
rem ==============================================================================
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
echo Downloading the Build Tools bootstrapper
if not exist "vs_buildTools.exe" curl -SL -o vs_buildTools.exe https://aka.ms/vs/17/release/vs_buildTools.exe || (
  echo Failed to download vs_buildTools.exe
  del /Q vs_buildTools.exe
  exit /b 1
)
rem https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022
rem https://learn.microsoft.com/en-us/visualstudio/install/command-line-parameter-examples?view=vs-2022
rem https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022
echo Installing Visual C++ Build Tools
vs_buildTools.exe                                                            ^
  --includeRecommended                                                       ^
  --wait                                                                     ^
  --passive                                                                  ^
  --norestart                                                                ^
  --removeOos true                                                           ^
  --downloadThenInstall	                                                     ^
  --addProductLang En-us                                                     ^
  --add Microsoft.VisualStudio.Workload.VCTools                              ^
  --add Microsoft.Net.Component.4.8.1.TargetingPack                          ^
  --add Microsoft.VisualStudio.Component.VC.ATL	                             ^
  --add Microsoft.VisualStudio.Component.VC.ATLMFC                           ^
  --add Microsoft.VisualStudio.Component.VC.ASAN                             ^
  --remove Microsoft.VisualStudio.Component.VC.CMake.Project	             ^
  --remove Microsoft.VisualStudio.Component.TestTools.BuildTools
del /Q vs_buildTools.exe
exit /b 0

rem ==============================================================================
rem Check CUDA and CUDNN whether has been installed
rem ==============================================================================
:check_cuda
cd "%~dp0\tags"
for /f "usebackq tokens=*" %%i in (`wmic path win32_VideoController get name ^| findstr "NVIDIA"`) do (
  set nv_gpu=%%i
)
if "!nv_gpu!" == "" (
  echo You don't have NVIDIA GPU on your PC
  exit /b 0
) else (
  if "%CUDA_PATH%" == "" (
    set with_cuda=
    echo Do you want to install CUDA and CUDNN? [yes/y/no/n]
    echo If you do not want, just press Enter to cancel
    set /p with_cuda=
    if "!with_cuda!"=="yes" goto :install_cuda
    if "!with_cuda!"=="y" goto :install_cuda
  )
  exit /b 0
)
:install_cuda
echo You don't have CUDA installed
set CUDA_FULL_VERSION=12.8.1_572.61
for /f "tokens=1-4 delims=." %%a in ("!CUDA_FULL_VERSION!") do set cuda_major=%%a
for /f "tokens=1-4 delims=." %%a in ("!CUDA_FULL_VERSION!") do set cuda_major_minor=%%a.%%b
for /f "delims=_" %%a in ("!CUDA_FULL_VERSION!") do set CUDA_VERSION=%%a
rem https://docs.nvidia.com/cuda/cuda-installation-guide-microsoft-windows/index.html
if not exist "cuda_!CUDA_FULL_VERSION!_windows.exe" (
  echo Downloading CUDA !CUDA_FULL_VERSION!
  wget --no-check-certificate https://developer.download.nvidia.com/compute/cuda/!CUDA_VERSION!/local_installers/cuda_!CUDA_FULL_VERSION!_windows.exe
)
echo Installing CUDA !CUDA_FULL_VERSION!
cuda_!CUDA_FULL_VERSION!_windows.exe -s cuda_profiler_api_!cuda_major_minor! cudart_!cuda_major_minor! cuobjdump_!cuda_major_minor! cupti_!cuda_major_minor! cuxxfilt_!cuda_major_minor! demo_suite_!cuda_major_minor! nvcc_!cuda_major_minor! nvdisasm_!cuda_major_minor! nvfatbin_!cuda_major_minor! nvjitlink_!cuda_major_minor! nvml_dev_!cuda_major_minor! nvprof_!cuda_major_minor! nvprune_!cuda_major_minor! nvrtc_!cuda_major_minor! nvrtc_dev_!cuda_major_minor! opencl_!cuda_major_minor! visual_profiler_!cuda_major_minor! sanitizer_!cuda_major_minor! thrust_!cuda_major_minor! cublas_!cuda_major_minor! cublas_dev_!cuda_major_minor! cufft_!cuda_major_minor! cufft_dev_!cuda_major_minor! curand_!cuda_major_minor! curand_dev_!cuda_major_minor! cusolver_!cuda_major_minor! cusolver_dev_!cuda_major_minor! cusparse_!cuda_major_minor! cusparse_dev_!cuda_major_minor! npp_!cuda_major_minor! npp_dev_!cuda_major_minor! nvjpeg_!cuda_major_minor! nvjpeg_dev_!cuda_major_minor! occupancy_calculator_!cuda_major_minor!

set CUDNN_VERSION=9.8.0.87
rem https://docs.nvidia.com/deeplearning/cudnn/latest/reference/support-matrix.html#support-matrix
rem https://docs.nvidia.com/deeplearning/cudnn/latest/installation/windows.html
if not exist "cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive.zip" (
  echo Downloading CUDNN !CUDNN_VERSION!
  wget --no-check-certificate https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/windows-x86_64/cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive.zip
)
powershell Expand-Archive -Path cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive.zip -DestinationPath . > nul || pause
if not exist "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v!cuda_major_minor!\lib\x64" mkdir "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v!cuda_major_minor!\lib\x64"

pushd cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive
xcopy /S /F /V bin "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v!cuda_major_minor!\bin"
xcopy /S /F /V include "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v!cuda_major_minor!\include"
xcopy /S /F /V lib\x64 "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v!cuda_major_minor!\lib\x64"
popd
rmdir /S /Q cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive
cd "%~dp0"
exit /b 0

rem ==============================================================================
rem  Check Intel OneAPI whether has been installed. If not, install it automatically
rem ==============================================================================
:check_oneapi
cd "%~dp0\tags"
set ONEAPI_ROOT="C:\Program Files (x86)\Intel\oneAPI"
for /f "usebackq tokens=*" %%i in (`wmic cpu get name ^| findstr "Intel"`) do (
  set intel_cpu=%%i
)
if "!intel_cpu!" == "" (
  echo You don't have Intel CPU on your PC, but use Intel OneAPI should be OK.
)
set oneapi_version=2024.2.1
set action=
set component_lists=
rem Components available for installation:
rem https://oneapi-src.github.io/oneapi-ci/
if not exist "!ONEAPI_ROOT!\compiler" (
  rem https://www.intel.com/content/www/us/en/developer/articles/tool/compilers-redistributable-libraries-by-version.html
  if not exist "w_dpcpp_cpp_runtime_p_!oneapi_version!.1084.exe" (
    echo Downloading Intel oneAPI DPC++/C++ Compiler Runtime for Windows
    wget --no-check-certificate https://registrationcenter-download.intel.com/akdlm/IRC_NAS/15a35578-2f9a-4f39-804b-3906e0a5f8fc/w_dpcpp_cpp_runtime_p_!oneapi_version!.1084.exe || (
      echo Failed to download w_dpcpp_cpp_runtime_p_!oneapi_version!.1084.exe
      del /Q w_dpcpp_cpp_runtime_p_!oneapi_version!.1084.exe
      exit /b 1
    )
  )
  if not exist "w_ifort_runtime_p_!oneapi_version!.1084.exe" (
    echo Downloading Intel Fortran Compiler Runtime for Windows* ^(IFX/IFORT^)
    wget --no-check-certificate https://registrationcenter-download.intel.com/akdlm/IRC_NAS/ea23d696-a77f-4a4a-8996-20d02cdbc48f/w_ifort_runtime_p_!oneapi_version!.1084.exe || (
      echo Failed to download w_ifort_runtime_p_!oneapi_version!.1084.exe
      del /Q w_ifort_runtime_p_!oneapi_version!.1084.exe
      exit /b 1
    )
  )
  echo Installing Intel oneAPI DPC++/C++ Compiler Runtime for Windows
  start /wait w_dpcpp_cpp_runtime_p_!oneapi_version!.1084.exe || (
    echo Failed to install Intel oneAPI DPC++/C++ Compiler Runtime for Windows
    del /Q w_dpcpp_cpp_runtime_p_!oneapi_version!.1084.exe
    exit /b 1
  )
  echo Installing Intel Fortran Compiler Runtime for Windows* ^(IFX/IFORT^)
  start /wait w_ifort_runtime_p_!oneapi_version!.1084.exe || (
    echo Failed to install Intel Fortran Compiler Runtime for Windows ^(IFX/IFORT^)
    del /Q w_ifort_runtime_p_!oneapi_version!.1084.exe
    exit /b 1
  )
  set component_lists=intel.oneapi.win.cpp-dpcpp-common
  set action=install
)
if not exist "!ONEAPI_ROOT!\mkl" (
  set with_mkl=
  echo Do you want to install Intel oneAPI Math Kernel Library ^(oneMKL^)? [yes/y/no/n]
  echo If you do not want, just press Enter to cancel
  set /p with_mkl=
  if "!with_mkl!"=="yes" (
    if "!component_lists!"=="" set component_lists=intel.oneapi.win.cpp-dpcpp-common
    set component_lists=!component_lists!:intel.oneapi.win.mkl.devel
    rem If intel compiler has been installed last time, the value 'action' is empty
    if "!action!"=="" set action=modify
  )
  if "!with_mkl!"=="y" (
    if "!component_lists!"=="" set component_lists=intel.oneapi.win.cpp-dpcpp-common
    set component_lists=!component_lists!:intel.oneapi.win.mkl.devel
    if "!action!"=="" set action=modify
  )
)
if not "!component_lists!"=="" (
  if not exist "w_BaseKit_p_!oneapi_version!.101_offline.exe" (
    echo Downloading Intel OneAPI BaseKit for Windows
    wget --no-check-certificate https://registrationcenter-download.intel.com/akdlm/IRC_NAS/d91caaa0-7306-46ea-a519-79a0423e1903/w_BaseKit_p_!oneapi_version!.101_offline.exe || (
      echo Failed to download w_BaseKit_p_!oneapi_version!.101_offline.exe
      del /Q w_BaseKit_p_!oneapi_version!.101_offline.exe
      exit /b 1
    )
  )
  echo Installing or Modify Intel OneAPI BaseKit
  if "!action!"=="" set action=install
  rem https://www.intel.com/content/www/us/en/docs/oneapi/installation-guide-windows/2024-1/install-with-command-line.html
  w_BaseKit_p_!oneapi_version!.101_offline.exe -a --silent --eula accept --action !action! --components !component_lists! || (
    echo Failed to install Intel OneAPI BaseKit
    exit /b 1
  )
)
if not exist "!ONEAPI_ROOT!\mpi" (
  if not exist "w_HPCKit_p_!oneapi_version!.80_offline.exe" (
    echo Downloading Intel OneAPI HPCKit
    wget --no-check-certificate https://registrationcenter-download.intel.com/akdlm/IRC_NAS/745e923a-3f85-4e1e-b6dd-637c0e9ccba6/w_HPCKit_p_!oneapi_version!.80_offline.exe || (
      echo Failed to download w_HPCKit_p_!oneapi_version!.80_offline.exe
      del /Q w_HPCKit_p_!oneapi_version!.80_offline.exe
      exit /b 1
    )
  )
  echo Installing Intel OneAPI HPCKit
  w_HPCKit_p_!oneapi_version!.80_offline.exe -a --silent --eula accept --components intel.oneapi.win.ifort-compiler:intel.oneapi.win.mpi.devel || (
    echo Failed to install Intel OneAPI HPCKit
    exit /b 1
  )
)
cd "%~dp0"
exit /b 0

rem ==============================================================================
rem Check wget whether has been installed
rem ==============================================================================
:check_wget
set WGET_VERSION=1.21.4
where wget >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Installing wget
  curl -L https://eternallybored.org/misc/wget/!WGET_VERSION!/%ARCH:x=%/wget.exe -o %~dp0%ARCH%\bin\wget.exe || (
    echo Failed to install wget
    del /Q "%~dp0%ARCH%\bin\wget.exe"
    exit /b 1
  )
)
exit /b 0

rem ==============================================================================
rem  Check ninja whether has been installed. If not, install it automatically
rem ==============================================================================
:check_ninja
set NINJA_VERSION=1.12.1
where ninja >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Installing ninja
  if not exist "ninja-win.zip" (
    wget --no-check-certificate https://github.com/ninja-build/ninja/releases/download/v!NINJA_VERSION!/ninja-win.zip || (
      echo Failed to download ninja
      del /Q ninja-win.zip
      exit /b 1
    )
  )
  powershell Expand-Archive -Path ninja-win.zip -DestinationPath . > nul || (
    echo Failed to extract ninja-win.zip
    exit /b 1
  )
  copy /Y /V ninja.exe %~dp0%ARCH%\bin\ninja.exe
  del /Q ninja-win.zip ninja.exe
)
exit /b 0

rem ==============================================================================
rem  Check python whether has been installed, If not, install it automatically
rem ==============================================================================
:check_python
set PYTHON_VERSION=3.12.9
where python >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Installing python 3
  set host_suffix=
  if "%ARCH%" == "x64" set host_suffix=-amd64
  if not exist "python-!PYTHON_VERSION!!host_suffix!.exe" (
    wget --no-check-certificate https://www.python.org/ftp/python/!PYTHON_VERSION!/python-!PYTHON_VERSION!!host_suffix!.exe || goto :end
  )
  start /wait python-!PYTHON_VERSION!!host_suffix!.exe InstallAllUsers=1 TargetDir=C:\Python312 PrependPath=1 Include_test=0 || goto :end
  del /Q python-!PYTHON_VERSION!!host_suffix!.exe
)
ping -n 1 -w 1000 8.8.8.8 > nul
if "%errorlevel%" equ "0" python -m pip install --upgrade pip setuptools meson Pygments PyYAML rich
exit /b 0

rem ==============================================================================
rem  check cmake whether has been installed
rem ==============================================================================
:check_cmake
set CMAKE_VERSION=3.31.6
where cmake >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Installing CMake
  set host_suffix=i368
  if "%ARCH%" == "x64" set host_suffix=x86_64
  if not exist "cmake-!CMAKE_VERSION!-windows-!host_suffix!.msi" (
    wget --no-check-certificate https://github.com/Kitware/CMake/releases/download/v!CMAKE_VERSION!/cmake-!CMAKE_VERSION!-windows-!host_suffix!.msi || goto :end
  )
  start /wait msiexec -i cmake-!CMAKE_VERSION!-windows-!host_suffix!.msi || goto :end
  del /Q cmake-!CMAKE_VERSION!-windows-!host_suffix!.msi
)
exit /b 0

rem ==============================================================================
rem  check git whether has been installed
rem ==============================================================================
:check_git
set GIT_VERSION=2.47.1.2
where git >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Intalling Git !GIT_VERSION!
  for /f "tokens=1-4 delims=." %%a in ("%GIT_VERSION%") do (
      if "%%d"=="" (
          set git_patch_version=1
      ) else (
          set git_patch_version=%%d
      )
  )
  set host_suffix=32
  if "%ARCH%" == "x64" set host_suffix=64
  if not exist "Git-!GIT_VERSION!-!host_suffix!-bit.exe" (
    wget --no-check-certificate https://github.com/git-for-windows/git/releases/download/v!GIT_VERSION:~0,6!.windows.!git_patch_version!/Git-!GIT_VERSION!-!host_suffix!-bit.exe || goto :end
  )
  start /wait Git-!GIT_VERSION!-!host_suffix!-bit.exe || goto :end
  del /Q Git-!GIT_VERSION!-!host_suffix!-bit.exe
)
exit /b 0

rem ==============================================================================
rem  Download archive and extract it
rem ==============================================================================
:download_extract
set url=%1
set dest=%2
for %%F in ("%url%") do set archive=%%~nxF
set folder=!archive:.pkg.tar.zst=!
if not exist "%archive%" (
  wget --no-check-certificate %url% || (
    echo Failed to download %archive%
    del /Q %archive%
    exit /b 1
  )
)
if not exist "%folder%" (
  mkdir %folder% && bash -c "tar -I zstd --exclude='.BUILDINFO' --exclude='.MTREE' --exclude='.PKGINFO' -xvf %archive% -C %folder%" || (
    echo Failed to extract %archive% to %folder%
    exit /b 1
  )
  xcopy /Y /F /S %folder% %dest%
  del /Q %archive%
  rmdir /S /Q %folder%
)
exit /b 0

rem ==============================================================================
rem  Add more tools in Git for Windows
rem ==============================================================================
:git_bash_add_tools
if not defined GIT_PREFIX (
  for /f "delims=" %%i in ('where git.exe 2^>nul') do (
    set "git_path=%%i"
    set "GIT_PREFIX=!git_path:\bin\git.exe=!"
    set "GIT_PREFIX=!GIT_PREFIX:\cmd\git.exe=!"
    if exist "!GIT_PREFIX!" goto found_git
  )
)
exit /b 0
:found_git
set PATH=!GIT_PREFIX!\bin;%PATH%
rem zstd
if not exist "!GIT_PREFIX!\mingw64\bin\zstd.exe" (
  if not exist "zstd-v1.5.6-win!ARCH:x=!.zip" (
    wget --no-check-certificate https://github.com/facebook/zstd/releases/download/v1.5.6/zstd-v1.5.6-win!ARCH:x=!.zip || (
      echo Failed to download zstd-v1.5.6-win!ARCH:x=!.zip
      exit /b 1
    )
  )
  if not exist "zstd-v1.5.6-win!ARCH:x=!" (
    powershell Expand-Archive -Path zstd-v1.5.6-win!ARCH:x=!.zip -DestinationPath . > nul || (
      echo Failed to extract zstd-v1.5.6-win!ARCH:x=!.zip
      exit /b 1
    )
    copy /Y /V /B zstd-v1.5.6-win!ARCH:x=!\zstd.exe "!GIT_PREFIX!\mingw64\bin\zstd.exe"
  )
  del /Q zstd-v1.5.6-win!ARCH:x=!.zip
  rmdir /S /Q zstd-v1.5.6-win!ARCH:x=!
)
rem The depencencies can be seen in https://packages.msys2.org for each package,
rem e.g. https://packages.msys2.org/base/rsync
rem other depencencies of autotools
if not exist "!GIT_PREFIX!\usr\bin\msys-stdc++-6.dll" (
  call :download_extract https://repo.msys2.org/msys/x86_64/gcc-libs-13.3.0-1-x86_64.pkg.tar.zst "!GIT_PREFIX!"
)
if not exist "!GIT_PREFIX!\usr\bin\m4.exe" (
  call :download_extract https://repo.msys2.org/msys/x86_64/m4-1.4.19-2-x86_64.pkg.tar.zst "!GIT_PREFIX!"
)
if not exist "!GIT_PREFIX!\usr\bin\make.exe" (
  call :download_extract https://repo.msys2.org/msys/x86_64/make-4.4.1-2-x86_64.pkg.tar.zst "!GIT_PREFIX!"
)
if not exist "!GIT_PREFIX!\usr\bin\libtool" (
  call :download_extract https://repo.msys2.org/msys/x86_64/libtool-2.5.4-1-x86_64.pkg.tar.zst "!GIT_PREFIX!"
)
if not exist "!GIT_PREFIX!\usr\bin\pkgconf.exe" (
  call :download_extract https://repo.msys2.org/msys/x86_64/pkgconf-2.3.0-1-x86_64.pkg.tar.zst "!GIT_PREFIX!"
)
if not exist "!GIT_PREFIX!\usr\bin\bison.exe" (
  call :download_extract https://repo.msys2.org/msys/x86_64/bison-3.8.2-5-x86_64.pkg.tar.zst "!GIT_PREFIX!"
)
if not exist "!GIT_PREFIX!\usr\bin\flex.exe" (
  call :download_extract https://repo.msys2.org/msys/x86_64/flex-2.6.4-3-x86_64.pkg.tar.zst "!GIT_PREFIX!"
)
rem autoconf
if not exist "!GIT_PREFIX!\usr\share\autoconf-2.69" call :download_extract https://repo.msys2.org/msys/x86_64/autoconf2.69-2.69-4-any.pkg.tar.zst "!GIT_PREFIX!"
if not exist "!GIT_PREFIX!\usr\share\autoconf-2.71" call :download_extract https://repo.msys2.org/msys/x86_64/autoconf2.71-2.71-3-any.pkg.tar.zst "!GIT_PREFIX!"
if not exist "!GIT_PREFIX!\usr\share\autoconf-2.72" call :download_extract https://repo.msys2.org/msys/x86_64/autoconf2.72-2.72-1-any.pkg.tar.zst "!GIT_PREFIX!"
if not exist "!GIT_PREFIX!\usr\bin\autoconf" (
  call :download_extract https://repo.msys2.org/msys/x86_64/autoconf-wrapper-20240607-1-any.pkg.tar.zst "!GIT_PREFIX!"
  call :download_extract https://repo.msys2.org/msys/x86_64/autoconf-archive-2023.02.20-1-any.pkg.tar.zst "!GIT_PREFIX!"
)
rem automake
if not exist "!GIT_PREFIX!\usr\share\automake-1.15" call :download_extract https://repo.msys2.org/msys/x86_64/automake1.15-1.15.1-4-any.pkg.tar.zst "!GIT_PREFIX!"
if not exist "!GIT_PREFIX!\usr\share\automake-1.16" call :download_extract https://repo.msys2.org/msys/x86_64/automake1.16-1.16.5-1-any.pkg.tar.zst "!GIT_PREFIX!"
if not exist "!GIT_PREFIX!\usr\share\automake-1.17" call :download_extract https://repo.msys2.org/msys/x86_64/automake1.17-1.17-1-any.pkg.tar.zst "!GIT_PREFIX!"
if not exist "!GIT_PREFIX!\usr\bin\automake" call :download_extract https://repo.msys2.org/msys/x86_64/automake-wrapper-20240607-1-any.pkg.tar.zst "!GIT_PREFIX!"
rem texinfo
if not exist "!GIT_PREFIX!\usr\bin\texi2any" (
  call :download_extract https://repo.msys2.org/msys/x86_64/texinfo-7.1.1-1-x86_64.pkg.tar.zst "!GIT_PREFIX!"
)
rem rsync
if not exist "!GIT_PREFIX!\usr\bin\rsync.exe" (
  call :download_extract https://repo.msys2.org/msys/x86_64/liblz4-1.9.4-1-x86_64.pkg.tar.zst "!GIT_PREFIX!"
  call :download_extract https://repo.msys2.org/msys/x86_64/libxxhash-0.8.2-1-x86_64.pkg.tar.zst "!GIT_PREFIX!"
  call :download_extract https://repo.msys2.org/msys/x86_64/libzstd-1.5.6-1-x86_64.pkg.tar.zst "!GIT_PREFIX!"
  call :download_extract https://repo.msys2.org/msys/x86_64/rsync-3.3.0-1-x86_64.pkg.tar.zst "!GIT_PREFIX!"
)
rem gperf
if not exist "!GIT_PREFIX!\usr\bin\gperf.exe" (
  call :download_extract https://repo.msys2.org/msys/x86_64/gperf-3.1-6-x86_64.pkg.tar.zst "!GIT_PREFIX!"
)
exit /b 0

rem ==============================================================================
rem Check yq whether has been installed. If not, install it automatically
rem ==============================================================================
:check_yq
set YQ_VERSION=4.45.1
where yq >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Installing yq
  if not exist "yq.exe" (
    if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
      wget --no-check-certificate https://github.com/mikefarah/yq/releases/download/v!YQ_VERSION!/yq_windows_amd64.exe -O %~dp0%ARCH%\bin\yq.exe || (
        echo Failed to install yq
        exit /b 1
      )
    ) else (
      wget --no-check-certificate https://github.com/mikefarah/yq/releases/download/v!YQ_VERSION!/yq_windows_386.exe -O %~dp0%ARCH%\bin\yq.exe || (
        echo Failed to install yq
        exit /b 1
      )
    )
  )
)
exit /b 0

rem ==============================================================================
rem  check rust whether has been installed
rem ==============================================================================
:check_rust
where rustc >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Installing Rust
  if not exist "rustup-init.exe" (
    if "%ARCH%" == "x64" (
      wget --no-check-certificate https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe || (
        echo Failed to download rust
        exit /b 1
      )
    ) else (
      wget --no-check-certificate https://static.rust-lang.org/rustup/dist/i686-pc-windows-msvc/rustup-init.exe || (
        echo Failed to download rust
        exit /b 1
      )
    )
  )
  start /wait rustup-init.exe || (
    echo Failed to install rust
    exit /b 1
  )
  rustup default stable-msvc
  del /Q rustup-init.exe
)
exit /b 0

:end
cd /d %~dp0
set PATH=%OLDPATH%
set vsinstall=
set vswhere=
set vcvarsall=
