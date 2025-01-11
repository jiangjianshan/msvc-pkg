@echo off
setlocal enabledelayedexpansion

rem  Fix error C2226: syntax error: unexpected type 'llvmrem sysrem UnicodeCharRange'
powershell -command "Set-WinSystemLocale -SystemLocale en-US"

rem  https://docs.python.org/3/using/windows.html#removing-the-max-path-limitation
reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t reg_DWORD /d 1

if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set ARCH=x64
) else (
    set ARCH=x86
)

set GIT_ROOT="C:\\Program Files\\Git"
set OLDPATH=%PATH%
set PATH=%PATH%;%~dp0%ARCH%\bin;%GIT_ROOT%\bin

cd /d %~dp0
mkdir %ARCH%\bin
mkdir tmp
cd tmp

call :check_wget || goto :end
call :check_vcbuildtools || goto :end
call :check_cuda || goto :end
call :check_oneapi || goto :end
call :check_python || goto :end
call :check_git || goto :end
call :check_rust || goto :end

rem Dealing with line endings
rem See https://stackoverflow.com/questions/1967370/git-replacing-lf-with-crlf
git config --global core.autocrlf input
git config --global core.autocrlf false

rem speed up git handling if on bash environment
git config --system core.fileMode false

rem Changed the default behavior of Git for Windows
git config --global core.ignorecase false

call :check_cmake || goto :end
call :check_ninja || goto :end
call :check_yq || goto :end
call :git_bash_add_tools || goto :end
goto :end

rem ==============================================================================
rem Check Visual C++ Build Tools whether has been installed
rem ==============================================================================
:check_vcbuildtools
echo Checking VC Build Tools whether has been installed
set vsinstall=
if "%VSINSTALLDIR%" neq "" (
  set "vsinstall=%VSINSTALLDIR%"
) else (
  if not exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" goto :install_vcbuildtools
  for /f "delims=" %%r in ('^""%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -nologo -latest -products "*" -all -property installationPath^"') do set vsinstall=%%r
)
if exist "%vsinstall%\VC\Auxiliary\Build\vcvarsall.bat" exit /b 0
:install_vcbuildtools
  rem Download the Build Tools bootstrapper
  if not exist "vs_buildTools.exe" curl -SL -o vs_buildTools.exe https://aka.ms/vs/17/release/vs_buildTools.exe || goto :end
  rem https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022
  rem https://learn.microsoft.com/en-us/visualstudio/install/command-line-parameter-examples?view=vs-2022
  rem https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022
  echo Installing Visual C++ Build Tools
  vs_buildTools.exe                                                            ^
    --includeRecommended                                                       ^
    --wait                                                                     ^
    --passive                                                                  ^
    --norestart		                                                             ^
    --removeOos true                                                           ^
    --downloadThenInstall	                                                     ^
    --addProductLang En-us                                                     ^
    --add Microsoft.VisualStudio.Workload.VCTools                              ^
    --add Microsoft.Net.Component.4.8.1.TargetingPack	                         ^
    --add Microsoft.VisualStudio.Component.VC.ATL	                             ^
    --add Microsoft.VisualStudio.Component.VC.ATLMFC                           ^
    --add Microsoft.VisualStudio.Component.VC.ASAN                             ^
    --remove Microsoft.VisualStudio.Component.VC.CMake.Project	               ^
    --remove Microsoft.VisualStudio.Component.TestTools.BuildTools
  echo Done.
)
exit /b 0

rem ==============================================================================
rem Check CUDA whether has been installed
rem ==============================================================================
:check_cuda
for /f "usebackq tokens=*" %%i in (`wmic path win32_VideoController get name ^| findstr "NVIDIA"`) do (
  set nv_gpu=%%i
)
if "!nv_gpu!" == "" (
  echo You don't have NVIDIA GPU on your PC
  exit /b 0
) else (
  echo You NVIDIA GPU is !nv_gpu!
  echo Checking CUDA and CUDNN whether has been installed
  if "%CUDA_PATH%" == "" (
    set with_cuda=
    echo:
    echo "Do you want to install CUDA and CUDNN? [yes/y/no/n]"
    echo "If you do not want, just press Enter to cancel"
    echo:
    set /p with_cuda=
    if "!with_cuda!"=="yes" goto :install_cuda
    if "!with_cuda!"=="y" goto :install_cuda
  )
  exit /b 0
)
:install_cuda
echo You don't have CUDA installed
set CUDA_FULL_VERSION=12.6.2_560.94
for /f "tokens=1-4 delims=." %%a in ("!CUDA_FULL_VERSION!") do set cuda_major=%%a
for /f "tokens=1-4 delims=." %%a in ("!CUDA_FULL_VERSION!") do set cuda_major_minor=%%a.%%b
for /f "delims=_" %%a in ("!CUDA_FULL_VERSION!") do set cuda_version=%%a
rem https://docs.nvidia.com/cuda/cuda-installation-guide-microsoft-windows/index.html
if not exist "cuda_!CUDA_FULL_VERSION!_windows.exe" (
  echo Downloading CUDA !CUDA_FULL_VERSION!, please wait ...
  wget https://developer.download.nvidia.com/compute/cuda/!CUDA_VERSION!/local_installers/cuda_!CUDA_FULL_VERSION!_windows.exe
)
echo Installing CUDA !CUDA_FULL_VERSION!, please wait ...
cuda_!CUDA_FULL_VERSION!_windows.exe -s cuda_profiler_api_!cuda_major_minor! cudart_!cuda_major_minor! cuobjdump_!cuda_major_minor! cupti_!cuda_major_minor! cuxxfilt_!cuda_major_minor! demo_suite_!cuda_major_minor! nvcc_!cuda_major_minor! nvdisasm_!cuda_major_minor! nvfatbin_!cuda_major_minor! nvjitlink_!cuda_major_minor! nvml_dev_!cuda_major_minor! nvprof_!cuda_major_minor! nvprune_!cuda_major_minor! nvrtc_!cuda_major_minor! nvrtc_dev_!cuda_major_minor! opencl_!cuda_major_minor! visual_profiler_!cuda_major_minor! sanitizer_!cuda_major_minor! thrust_!cuda_major_minor! cublas_!cuda_major_minor! cublas_dev_!cuda_major_minor! cufft_!cuda_major_minor! cufft_dev_!cuda_major_minor! curand_!cuda_major_minor! curand_dev_!cuda_major_minor! cusolver_!cuda_major_minor! cusolver_dev_!cuda_major_minor! cusparse_!cuda_major_minor! cusparse_dev_!cuda_major_minor! npp_!cuda_major_minor! npp_dev_!cuda_major_minor! nvjpeg_!cuda_major_minor! nvjpeg_dev_!cuda_major_minor! occupancy_calculator_!cuda_major_minor!
echo Done.

set CUDNN_VERSION=9.5.0.50
rem https://docs.nvidia.com/deeplearning/cudnn/latest/reference/support-matrix.html#support-matrix
rem https://docs.nvidia.com/deeplearning/cudnn/latest/installation/windows.html
if not exist "cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive.zip" (
  echo Downloading CUDNN !CUDNN_VERSION!, please wait ...
  wget https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/windows-x86_64/cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive.zip
)
powershell Expand-Archive -Path cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive.zip -DestinationPath . > nul || pause
if not exist "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v!cuda_major_minor!\lib\x64" mkdir "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v!cuda_major_minor!\lib\x64"

pushd cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive
xcopy /S /F /V bin "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v!cuda_major_minor!\bin"
xcopy /S /F /V include "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v!cuda_major_minor!\include"
xcopy /S /F /V lib\x64 "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v!cuda_major_minor!\lib\x64"
popd
echo Done.
exit /b 0

rem ==============================================================================
rem  Check Intel OneAPI whether has been installed. If not, install it automatically
rem ==============================================================================
:check_oneapi
set ONEAPI_ROOT="C:\Program Files (x86)\Intel\oneAPI"
for /f "usebackq tokens=*" %%i in (`wmic cpu get name ^| findstr "Intel"`) do (
  set intel_cpu=%%i
)
if "!intel_cpu!" == "" (
  echo You don't have Intel CPU on your PC, but use Intel OneAPI should be OK.
)
set component_lists=intel.oneapi.win.cpp-dpcpp-common
set with_basekit=no
set with_hpckit=no
rem Components available for installation:
rem https://oneapi-src.github.io/oneapi-ci/
if not exist "!ONEAPI_ROOT!\mkl" (
  set with_mkl=
  echo:
  echo "Do you want to install Intel oneAPI Math Kernel Library ^(oneMKL^)? [yes/y/no/n]"
  echo "If you do not want, just press Enter to cancel"
  echo:
  set /p with_mkl=
  if "!with_mkl!"=="yes" (
    set with_basekit=yes
    set component_lists=!component_lists!:intel.oneapi.win.mkl.devel
  )
  if "!with_mkl!"=="y" (
    set with_basekit=yes
    set component_lists=!component_lists!:intel.oneapi.win.mkl.devel
  )
)
if not exist "!ONEAPI_ROOT!\compiler" (
  if not exist "w_BaseKit_p_2024.2.1.101_offline.exe" (
    echo Downloading Intel OneAPI BaseKit
    wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/d91caaa0-7306-46ea-a519-79a0423e1903/w_BaseKit_p_2024.2.1.101_offline.exe || goto :end
  )
  set with_basekit=yes
)
if "!with_basekit!"=="yes" (
  echo Installing Intel OneAPI BaseKit
  w_BaseKit_p_2024.2.1.101_offline.exe -a --silent --eula accept --components !component_lists!
)
if not exist "!ONEAPI_ROOT!\mpi" (
  if not exist "w_HPCKit_p_2024.2.1.80_offline.exe" (
    echo Downloading Intel OneAPI HPCKit
    wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/745e923a-3f85-4e1e-b6dd-637c0e9ccba6/w_HPCKit_p_2024.2.1.80_offline.exe || goto :end
  )
  set with_hpckit=yes
)
if "!with_hpckit!"=="yes" (
  echo Installing Intel OneAPI HPCKit
  w_HPCKit_p_2024.2.1.80_offline.exe -a --silent --eula accept --components intel.oneapi.win.ifort-compiler:intel.oneapi.win.mpi.devel
)
exit /b 0

rem ==============================================================================
rem Check wget whether has been installed
rem ==============================================================================
:check_wget
echo Checking wget whether has been installed
where wget >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Installing wget ...
  curl -L https://eternallybored.org/misc/wget/1.21.4/%ARCH:x=%/wget.exe -o %~dp0%ARCH%\bin\wget.exe || goto :end
)
echo Done.
exit /b 0

rem ==============================================================================
rem  Check ninja whether has been installed. If not, install it automatically
rem ==============================================================================
:check_ninja
echo Checking Ninja whether has been installed
where ninja >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Installing ninja
  if not exist "ninja-win.zip" (
    wget --no-check-certificate https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-win.zip || goto :end
  )
  powershell Expand-Archive -Path ninja-win.zip -DestinationPath . > nul || goto :end
  copy /Y /V ninja.exe %~dp0%ARCH%\bin\ninja.exe
)
echo Done.
exit /b 0

rem ==============================================================================
rem  Check python whether has been installed, If not, install it automatically
rem ==============================================================================
:check_python
echo Checking Python whether has been installed
set PYTHON_VERSION=3.12.8
where python >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Installing python 3 ...
  if "%ARCH%" == "x64" (
    if not exist "python-!PYTHON_VERSION!-amd64.exe" (
      wget --no-check-certificate https://www.python.org/ftp/python/!PYTHON_VERSION!/python-!PYTHON_VERSION!-amd64.exe || goto :end
    )
    start /wait python-!PYTHON_VERSION!-amd64.exe InstallAllUsers=1 TargetDir=C:\Python312 PrependPath=1 Include_test=0 || goto :end
  ) else (
    if not exist "python-!PYTHON_VERSION!.exe" (
      wget --no-check-certificate https://www.python.org/ftp/python/!PYTHON_VERSION!/python-!PYTHON_VERSION!.exe || goto :end
    )
    start /wait python-!PYTHON_VERSION!.exe InstallAllUsers=1 TargetDir=C:\Python312 PrependPath=1 Include_test=0 || goto :end
  )
)
echo Installing 3rd party libraries for Python ...
set PATH=C:\Python312\Scripts;C:\Python312;%PATH%
python -m pip install --upgrade pip setuptools
python -m pip install --upgrade meson pygments pyyaml requests rich yamllint psutil || goto :end
echo Done
exit /b 0

rem ==============================================================================
rem  check cmake whether has been installed
rem ==============================================================================
:check_cmake
echo Checking CMake whether has been installed
set CMAKE_VERSION=3.31.2
where cmake >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Installing CMake ...
  if "%ARCH%" == "x64" (
    if not exist "cmake-!CMAKE_VERSION!-windows-x86_64.msi" (
      wget --no-check-certificate https://github.com/Kitware/CMake/releases/download/v!CMAKE_VERSION!/cmake-!CMAKE_VERSION!-windows-x86_64.msi || goto :end
    )
    start /wait msiexec -i cmake-!CMAKE_VERSION!-windows-x86_64.msi || goto :end
  ) else (
    if not exist "cmake-!CMAKE_VERSION!-windows-i368.msi" (
      wget --no-check-certificate https://github.com/Kitware/CMake/releases/download/v!CMAKE_VERSION!/cmake-!CMAKE_VERSION!-windows-i368.msi || goto :end
    )
    start /wait msiexec -i cmake-!CMAKE_VERSION!-windows-i368.msi || goto :end
  )
)
echo Done
exit /b 0

rem ==============================================================================
rem  check git whether has been installed
rem ==============================================================================
:check_git
echo Checking Git whether has been installed
set GIT_VERSION=2.47.1
where git >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Intalling Git
  if "%ARCH%" == "x64" (
    if not exist "Git-!GIT_VERSION!-64-bit.exe" (
      wget --no-check-certificate https://github.com/git-for-windows/git/releases/download/v!GIT_VERSION!.windows.1/Git-!GIT_VERSION!-64-bit.exe || goto :end
    )
    start /wait Git-!GIT_VERSION!-64-bit.exe || goto :end
  ) else (
    if not exist "Git-!GIT_VERSION!-32-bit.exe" (
      wget --no-check-certificate https://github.com/git-for-windows/git/releases/download/v!GIT_VERSION!.windows.1/Git-!GIT_VERSION!-32-bit.exe || goto :end
    )
    start /wait Git-!GIT_VERSION!-32-bit.exe || goto :end
  )
)
echo Done
exit /b 0

rem ==============================================================================
rem  Download archive and extract it
rem ==============================================================================
:download_extract
setlocal
set url=%1
set dest=%2
set SH="C:\\Program Files\\Git\\bin\\bash.exe"
for %%F in ("%url%") do set archive=%%~nxF
set folder=!archive:.pkg.tar.zst=!
if not exist "%archive%" (
  wget --no-check-certificate %url% || goto :end
)
if not exist "%folder%" (
  mkdir %folder% && %SH% -c "tar -I zstd --exclude='.BUILDINFO' --exclude='.MTREE' --exclude='.PKGINFO' -xvf %archive% -C %folder%" || goto :end
  xcopy /Y /F /S %folder% %dest%
)
exit /b 0

rem ==============================================================================
rem  Add more tools in Git for Windows
rem ==============================================================================
:git_bash_add_tools
setlocal
echo Adding more tools into Git Bash on Windows
if exist "!GIT_ROOT!" (
  rem zstd
  if not exist "!GIT_ROOT!\mingw64\bin\zstd.exe" (
    if not exist "zstd-v1.5.6-win!ARCH:x=!.zip" (
      wget --no-check-certificate https://github.com/facebook/zstd/releases/download/v1.5.6/zstd-v1.5.6-win!ARCH:x=!.zip
    )
    if not exist "zstd-v1.5.6-win!ARCH:x=!" (
      powershell Expand-Archive -Path zstd-v1.5.6-win!ARCH:x=!.zip -DestinationPath . > nul || goto :end
      copy /Y /V /B zstd-v1.5.6-win!ARCH:x=!\zstd.exe !GIT_ROOT!\mingw64\bin\zstd.exe
    )
  )
  rem The depencencies can be seen in https://packages.msys2.org for each package,
  rem e.g. https://packages.msys2.org/base/rsync
  rem other depencencies of autotools
  if not exist "!GIT_ROOT!\usr\bin\msys-stdc++-6.dll" (
    call :download_extract https://repo.msys2.org/msys/x86_64/gcc-libs-13.3.0-1-x86_64.pkg.tar.zst !GIT_ROOT!
  )
  if not exist "!GIT_ROOT!\usr\bin\m4.exe" (
    call :download_extract https://repo.msys2.org/msys/x86_64/m4-1.4.19-2-x86_64.pkg.tar.zst !GIT_ROOT!
  )
  if not exist "!GIT_ROOT!\usr\bin\make.exe" (
    call :download_extract https://repo.msys2.org/msys/x86_64/make-4.4.1-2-x86_64.pkg.tar.zst !GIT_ROOT!
  )
  if not exist "!GIT_ROOT!\usr\bin\libtool" (
    call :download_extract https://repo.msys2.org/msys/x86_64/libtool-2.4.7-3-x86_64.pkg.tar.zst !GIT_ROOT!
    call :download_extract https://repo.msys2.org/msys/x86_64/libltdl-2.4.7-4-x86_64.pkg.tar.zst !GIT_ROOT!
  )
  if not exist "!GIT_ROOT!\usr\bin\pkgconf.exe" (
    call :download_extract https://repo.msys2.org/msys/x86_64/pkgconf-2.3.0-1-x86_64.pkg.tar.zst !GIT_ROOT!
  )
  if not exist "!GIT_ROOT!\usr\bin\bison.exe" (
    call :download_extract https://repo.msys2.org/msys/x86_64/bison-3.8.2-5-x86_64.pkg.tar.zst !GIT_ROOT!
  )
  if not exist "!GIT_ROOT!\usr\bin\flex.exe" (
    call :download_extract https://repo.msys2.org/msys/x86_64/flex-2.6.4-3-x86_64.pkg.tar.zst !GIT_ROOT!
  )
  rem autoconf
  if not exist "!GIT_ROOT!\usr\share\autoconf-2.13" call :download_extract https://repo.msys2.org/msys/x86_64/autoconf2.13-2.13-6-any.pkg.tar.zst !GIT_ROOT!
  if not exist "!GIT_ROOT!\usr\share\autoconf-2.69" call :download_extract https://repo.msys2.org/msys/x86_64/autoconf2.69-2.69-4-any.pkg.tar.zst !GIT_ROOT!
  if not exist "!GIT_ROOT!\usr\share\autoconf-2.71" call :download_extract https://repo.msys2.org/msys/x86_64/autoconf2.71-2.71-3-any.pkg.tar.zst !GIT_ROOT!
  if not exist "!GIT_ROOT!\usr\share\autoconf-2.72" call :download_extract https://repo.msys2.org/msys/x86_64/autoconf2.72-2.72-1-any.pkg.tar.zst !GIT_ROOT!
  if not exist "!GIT_ROOT!\usr\bin\autoconf" (
    call :download_extract https://repo.msys2.org/msys/x86_64/autoconf-wrapper-20240607-1-any.pkg.tar.zst !GIT_ROOT!
    call :download_extract https://repo.msys2.org/msys/x86_64/autoconf-archive-2023.02.20-1-any.pkg.tar.zst !GIT_ROOT!
  )
  rem automake
  if not exist "!GIT_ROOT!\usr\share\automake-1.10" call :download_extract https://repo.msys2.org/msys/x86_64/automake1.10-1.10.3-5-any.pkg.tar.zst !GIT_ROOT!
  if not exist "!GIT_ROOT!\usr\share\automake-1.11" call :download_extract https://repo.msys2.org/msys/x86_64/automake1.11-1.11.6-6-any.pkg.tar.zst !GIT_ROOT!
  if not exist "!GIT_ROOT!\usr\share\automake-1.12" call :download_extract https://repo.msys2.org/msys/x86_64/automake1.12-1.12.6-6-any.pkg.tar.zst !GIT_ROOT!
  if not exist "!GIT_ROOT!\usr\share\automake-1.13" call :download_extract https://repo.msys2.org/msys/x86_64/automake1.13-1.13.4-7-any.pkg.tar.zst !GIT_ROOT!
  if not exist "!GIT_ROOT!\usr\share\automake-1.14" call :download_extract https://repo.msys2.org/msys/x86_64/automake1.14-1.14.1-6-any.pkg.tar.zst !GIT_ROOT!
  if not exist "!GIT_ROOT!\usr\share\automake-1.15" call :download_extract https://repo.msys2.org/msys/x86_64/automake1.15-1.15.1-4-any.pkg.tar.zst !GIT_ROOT!
  if not exist "!GIT_ROOT!\usr\share\automake-1.16" call :download_extract https://repo.msys2.org/msys/x86_64/automake1.16-1.16.5-1-any.pkg.tar.zst !GIT_ROOT!
  if not exist "!GIT_ROOT!\usr\share\automake-1.17" call :download_extract https://repo.msys2.org/msys/x86_64/automake1.17-1.17-1-any.pkg.tar.zst !GIT_ROOT!
  if not exist "!GIT_ROOT!\usr\bin\automake" call :download_extract https://repo.msys2.org/msys/x86_64/automake-wrapper-20240607-1-any.pkg.tar.zst !GIT_ROOT!
  rem texinfo
  if not exist "!GIT_ROOT!\usr\bin\texi2any" (
    call :download_extract https://repo.msys2.org/msys/x86_64/texinfo-7.1.1-1-x86_64.pkg.tar.zst !GIT_ROOT!
  )
  rem rsync
  if not exist "!GIT_ROOT!\usr\bin\rsync.exe" (
    call :download_extract https://repo.msys2.org/msys/x86_64/liblz4-1.9.4-1-x86_64.pkg.tar.zst !GIT_ROOT!
    call :download_extract https://repo.msys2.org/msys/x86_64/libxxhash-0.8.2-1-x86_64.pkg.tar.zst !GIT_ROOT!
    call :download_extract https://repo.msys2.org/msys/x86_64/libzstd-1.5.6-1-x86_64.pkg.tar.zst !GIT_ROOT!
    call :download_extract https://repo.msys2.org/msys/x86_64/rsync-3.3.0-1-x86_64.pkg.tar.zst !GIT_ROOT!
  )
  rem gperf
  if not exist "!GIT_ROOT!\usr\bin\gperf.exe" (
    call :download_extract https://repo.msys2.org/msys/x86_64/gperf-3.1-6-x86_64.pkg.tar.zst !GIT_ROOT!
  )
)
echo Done.
exit /b 0

rem ==============================================================================
rem Check yq whether has been installed. If not, install it automatically
rem ==============================================================================
:check_yq
echo Checking yq whether has been installed
where yq >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Installing yq ...
  if not exist "yq.exe" (
    if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
      wget --no-check-certificate https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_windows_amd64.exe -O yq.exe || goto :end
    ) else (
      wget --no-check-certificate https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_windows_386.exe -O yq.exe || goto :end
    )
  )
  copy /Y /V yq.exe %~dp0%ARCH%\bin\yq.exe
)
echo Done.
exit /b 0

rem ==============================================================================
rem  check rust whether has been installed
rem ==============================================================================
:check_rust
echo Checking Rust whether has been installed
where rustc >nul 2>&1
if "%errorlevel%" neq "0" (
  echo Installing Rust ...
  if not exist "rustup-init.exe" (
    if "%ARCH%" == "x64" (
      wget --no-check-certificate https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe || goto :end
    ) else (
      wget --no-check-certificate https://static.rust-lang.org/rustup/dist/i686-pc-windows-msvc/rustup-init.exe || goto :end
    )
  )
  start /wait rustup-init.exe || goto :end
  set PATH=%HOME%\.cargo\bin;%PATH%
  rustup default stable-msvc
)
echo Done
exit /b 0

:end
cd /d %~dp0
rmdir /s /q tmp
set PATH=%OLDPATH%
set vsinstall=
set vswhere=
set vcvarsall=
