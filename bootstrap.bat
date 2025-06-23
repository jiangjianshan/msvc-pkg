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

echo Checking system requirements for mpt
rem  Fix error C2226: syntax error: unexpected type 'llvmrem sysrem UnicodeCharRange'
for /f "tokens=2*" %%a in ('powershell -command "Get-WinSystemLocale" ^| findstr en-US') do set SYSTEM_LOCALE=%%a
if "!SYSTEM_LOCALE!" neq "en-US" powershell -command "Set-WinSystemLocale -SystemLocale en-US"

rem  https://docs.python.org/3/using/windows.html#removing-the-max-path-limitation
reg query HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled >nul 2>&1 || (
  reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t reg_DWORD /d 1
)

if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
  set ARCH=x64
) else (
  set ARCH=x86
)

set "ROOT_DIR=%~dp0"
if "!ROOT_DIR:~-1!"=="\" set "ROOT_DIR=!ROOT_DIR:~0,-1!"
set OLDPATH=%PATH%
set PATH=%PATH%;%USERPROFILE%\.cargo\bin;%ROOT_DIR%\%ARCH%\bin

cd /d "%ROOT_DIR%"
if not exist "%ROOT_DIR%\%ARCH%\bin" mkdir "%ROOT_DIR%\%ARCH%\bin"
if not exist "%ROOT_DIR%\tags" mkdir "%ROOT_DIR%\tags"

set restart_terminal=
call :check_wget || goto :end
call :check_yq || goto :end
call :check_vcbuildtools || goto :end
call :check_cuda || goto :end
call :check_oneapi || goto :end
call :check_git || goto :end
call :check_cmake || goto :end
call :check_rust || goto :end
call :check_ninja || goto :end
call :check_python || goto :end
if not "!restart_terminal!"=="" goto :restart
call :git_bash_add_tools || goto :end
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
if exist "%vsinstall%\VC\Auxiliary\Build\vcvarsall.bat" (
  echo visual c++ compiler             : installed
  exit /b 0
)
:install_vcbuildtools
if not exist "vs_buildTools.exe" curl -SL -o vs_buildTools.exe https://aka.ms/vs/17/release/vs_buildTools.exe
rem https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-history#fixed-version-bootstrappers
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
  --remove Microsoft.VisualStudio.Component.VC.CMake.Project	               ^
  --remove Microsoft.VisualStudio.Component.TestTools.BuildTools
del /Q vs_buildTools.exe
exit /b 0

rem ==============================================================================
rem Check CUDA and CUDNN whether has been installed
rem ==============================================================================
:check_cuda
cd /d "%ROOT_DIR%\tags"
if "%CUDA_PATH%" == "" (
  for /f "usebackq tokens=*" %%i in (`wmic path win32_VideoController get name ^| findstr "NVIDIA"`) do (
    set nv_gpu=%%i
  )
  if "!nv_gpu!" == "" (
    echo You don't have NVIDIA GPU on your PC
  ) else (
    for /f "delims=" %%i in ('yq -r ".components.cuda" %ROOT_DIR%\settings.yaml') do set with_cuda=%%i
    if "!with_cuda!"=="yes" goto :install_cuda
  ) 
) else (
  echo CUDA                            : installed
)
exit /b 0
:install_cuda
set CUDA_FULL_VERSION=12.9.1_576.57
for /f "tokens=1-4 delims=." %%a in ("!CUDA_FULL_VERSION!") do set cuda_major=%%a
for /f "tokens=1-4 delims=." %%a in ("!CUDA_FULL_VERSION!") do set cuda_major_minor=%%a.%%b
for /f "delims=_" %%a in ("!CUDA_FULL_VERSION!") do set CUDA_VERSION=%%a
rem https://docs.nvidia.com/cuda/cuda-installation-guide-microsoft-windows/index.html
if not exist "cuda_!CUDA_FULL_VERSION!_windows.exe" (
  wget --no-check-certificate https://developer.download.nvidia.com/compute/cuda/!CUDA_VERSION!/local_installers/cuda_!CUDA_FULL_VERSION!_windows.exe
)
echo Installing CUDA Toolkit !CUDA_FULL_VERSION!
cuda_!CUDA_FULL_VERSION!_windows.exe -s                                                              ^
  cublas_!cuda_major_minor! cublas_dev_!cuda_major_minor!                                            ^
  cuda_profiler_api_!cuda_major_minor!                                                               ^
  cudart_!cuda_major_minor!                                                                          ^
  cufft_!cuda_major_minor! cufft_dev_!cuda_major_minor!                                              ^
  cuobjdump_!cuda_major_minor!                                                                       ^
  cupti_!cuda_major_minor!                                                                           ^
  curand_!cuda_major_minor! curand_dev_!cuda_major_minor!                                            ^
  cusolver_!cuda_major_minor! cusolver_dev_!cuda_major_minor!                                        ^
  cusparse_!cuda_major_minor! cusparse_dev_!cuda_major_minor!                                        ^
  cuxxfilt_!cuda_major_minor!                                                                        ^
  demo_suite_!cuda_major_minor!                                                                      ^
  nsight_compute_!cuda_major_minor! nsight_systems_!cuda_major_minor! nsight_vse_!cuda_major_minor!  ^
  npp_!cuda_major_minor! npp_dev_!cuda_major_minor!                                                  ^
  nvcc_!cuda_major_minor!                                                                            ^
  nvdisasm_!cuda_major_minor!                                                                        ^
  nvfatbin_!cuda_major_minor!                                                                        ^
  nvjitlink_!cuda_major_minor!                                                                       ^
  nvjpeg_!cuda_major_minor! nvjpeg_dev_!cuda_major_minor!                                            ^
  nvml_dev_!cuda_major_minor!                                                                        ^
  nvprof_!cuda_major_minor!                                                                          ^
  nvprune_!cuda_major_minor!                                                                         ^
  nvrtc_!cuda_major_minor! nvrtc_dev_!cuda_major_minor!                                              ^
  nvtx_!cuda_major_minor!                                                                            ^
  occupancy_calculator_!cuda_major_minor!                                                            ^
  opencl_!cuda_major_minor!                                                                          ^
  sanitizer_!cuda_major_minor!                                                                       ^
  thrust_!cuda_major_minor!                                                                          ^
  visual_profiler_!cuda_major_minor!                                                                 ^
  visual_studio_integration_!cuda_major_minor!
for /f "delims=" %%i in ('yq -r ".components.cudnn" %ROOT_DIR%\settings.yaml') do set with_cudnn=%%i
if "!with_cudnn!"=="yes" goto :install_cudnn
exit /b 0
:install_cudnn
set CUDNN_VERSION=9.10.2.21
rem https://docs.nvidia.com/deeplearning/cudnn/latest/reference/support-matrix.html#support-matrix
rem https://docs.nvidia.com/deeplearning/cudnn/latest/installation/windows.html
if not exist "cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive.zip" (
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
set restart_terminal=1
cd /d "%ROOT_DIR%"
exit /b 0

rem ==============================================================================
rem  Check Intel OneAPI whether has been installed
rem ==============================================================================
:check_oneapi
cd /d "%ROOT_DIR%\tags"
set ONEAPI_ROOT="C:\Program Files (x86)\Intel\oneAPI"
set oneapi_version=2024.2.1
rem Components available for installation:
rem https://oneapi-src.github.io/oneapi-ci/
if not exist "!ONEAPI_ROOT!" (
  for /f "delims=" %%i in ('yq -r ".components.oneapi" %ROOT_DIR%\settings.yaml') do set with_oneapi=%%i
  if "!with_oneapi!"=="yes" (
    rem https://www.intel.com/content/www/us/en/developer/articles/tool/compilers-redistributable-libraries-by-version.html
    where sycl*.dll >nul 2>&1 || (
      if not exist "w_dpcpp_cpp_runtime_p_!oneapi_version!.1084.exe" (
        wget --no-check-certificate https://registrationcenter-download.intel.com/akdlm/IRC_NAS/15a35578-2f9a-4f39-804b-3906e0a5f8fc/w_dpcpp_cpp_runtime_p_!oneapi_version!.1084.exe
      )
      echo Installing Intel oneAPI DPC++/C++ Compiler Runtime for Windows
      start /wait w_dpcpp_cpp_runtime_p_!oneapi_version!.1084.exe
    )
    where libifcoremd.dll >nul 2>&1 || (
      if not exist "w_ifort_runtime_p_!oneapi_version!.1084.exe" (
        wget --no-check-certificate https://registrationcenter-download.intel.com/akdlm/IRC_NAS/ea23d696-a77f-4a4a-8996-20d02cdbc48f/w_ifort_runtime_p_!oneapi_version!.1084.exe
      )
      echo Installing Intel Fortran Compiler Runtime for Windows* ^(IFX/IFORT^)
      start /wait w_ifort_runtime_p_!oneapi_version!.1084.exe
    )
    if not exist "w_BaseKit_p_!oneapi_version!.101_offline.exe" (
      wget --no-check-certificate https://registrationcenter-download.intel.com/akdlm/IRC_NAS/d91caaa0-7306-46ea-a519-79a0423e1903/w_BaseKit_p_!oneapi_version!.101_offline.exe
    )
    echo Installing Intel oneAPI BaseKit
    w_BaseKit_p_!oneapi_version!.101_offline.exe -a --silent --eula accept --components intel.oneapi.win.cpp-dpcpp-common
    if not exist "w_HPCKit_p_!oneapi_version!.80_offline.exe" (
      wget --no-check-certificate https://registrationcenter-download.intel.com/akdlm/IRC_NAS/745e923a-3f85-4e1e-b6dd-637c0e9ccba6/w_HPCKit_p_!oneapi_version!.80_offline.exe
    )
    echo Installing Intel oneAPI HPCKit
    w_HPCKit_p_!oneapi_version!.80_offline.exe -a --silent --eula accept --components intel.oneapi.win.cpp-dpcpp-common:intel.oneapi.win.ifort-compiler:intel.oneapi.win.mpi.devel
  )
) else (
  echo intel compilers and mpi library : installed
)
cd /d "%ROOT_DIR%"
exit /b 0

rem ==============================================================================
rem Check wget whether has been installed
rem ==============================================================================
:check_wget
set WGET_VERSION=1.21.4
where wget >nul 2>&1
if "%errorlevel%" neq "0" (
  curl -L https://eternallybored.org/misc/wget/!WGET_VERSION!/%ARCH:x=%/wget.exe -o %ROOT_DIR%\%ARCH%\bin\wget.exe
) else (
  echo wget                            : installed
)
exit /b 0

rem ==============================================================================
rem  Check ninja whether has been installed. If not, install it automatically
rem ==============================================================================
:check_ninja
set NINJA_VERSION=1.12.1
where ninja >nul 2>&1
if "%errorlevel%" neq "0" (
  if not exist "ninja-win.zip" (
    wget --no-check-certificate https://github.com/ninja-build/ninja/releases/download/v!NINJA_VERSION!/ninja-win.zip
  )
  powershell Expand-Archive -Path ninja-win.zip -DestinationPath . > nul
  copy /Y /V ninja.exe %ROOT_DIR%\%ARCH%\bin\ninja.exe
  del /Q ninja-win.zip ninja.exe
) else (
  echo ninja                           : installed
)
exit /b 0

rem ==============================================================================
rem  Check python whether has been installed, If not, install it automatically
rem ==============================================================================
:check_python
where python >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Python is missing, you can download it from https://www.python.org/downloads/
  set restart_terminal=1
) else (
  echo python                          : installed
  if "%errorlevel%" equ "0" python -m pip install --upgrade --timeout 3 pip setuptools meson Pygments PyYAML rich
)
exit /b 0

rem ==============================================================================
rem  check cmake whether has been installed
rem ==============================================================================
:check_cmake
where cmake >nul 2>&1
if "%errorlevel%" neq "0" (
  echo CMake is missing, you can download it from https://cmake.org/download/
  set restart_terminal=1
) else (
  echo cmake                           : installed
)
exit /b 0

rem ==============================================================================
rem  check git whether has been installed
rem ==============================================================================
:check_git
where git >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Git for windows is missing, you can download it from https://gitforwindows.org/
  set restart_terminal=1
) else (
  echo git                             : installed
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
  wget --no-check-certificate %url%
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
    wget --no-check-certificate https://github.com/facebook/zstd/releases/download/v1.5.6/zstd-v1.5.6-win!ARCH:x=!.zip
  )
  if not exist "zstd-v1.5.6-win!ARCH:x=!" (
    powershell Expand-Archive -Path zstd-v1.5.6-win!ARCH:x=!.zip -DestinationPath . > nul
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
set YQ_VERSION=4.45.4
where yq >nul 2>&1
if "%errorlevel%" neq "0" (
  set host_suffix=_386
  if "%ARCH%" == "x64" set host_suffix=_amd64
  if not exist "yq.exe" (
    wget --no-check-certificate https://github.com/mikefarah/yq/releases/download/v!YQ_VERSION!/yq_windows!host_suffix!.exe -O %ROOT_DIR%\%ARCH%\bin\yq.exe
  )
) else (
  echo yq                              : installed
)
exit /b 0

rem ==============================================================================
rem  check rust whether has been installed
rem ==============================================================================
:check_rust
where rustc >nul 2>&1
if "%errorlevel%" neq "0" (
  for /f "delims=" %%i in ('yq -r ".components.rust" %ROOT_DIR%\settings.yaml') do set with_rust=%%i
  if "!with_rust!"=="yes" call :install_rust || goto :end
) else (
  echo rust                            : installed
)
exit /b 0
:install_rust
if not exist "rustup-init.exe" (
  set host_prefix=i686-
  if "%ARCH%" == "x64" set host_prefix=x86_64-
  wget --no-check-certificate https://static.rust-lang.org/rustup/dist/!host_prefix!pc-windows-msvc/rustup-init.exe
)
start /wait rustup-init.exe
rustup default stable-msvc
del /Q rustup-init.exe
exit /b 0

rem ==============================================================================
rem  Restart windows terminal to reload environments variables on next open
rem ==============================================================================
:restart
echo Press Enter to restart terminal to take effect of newer environment variables
pause
exit 0

:end
cd /d "%ROOT_DIR%"
set PATH=%OLDPATH%
set vsinstall=
set vswhere=
set vcvarsall=
echo Done
