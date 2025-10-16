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

call :clean_stage
call :configure_stage
call :build_stage
call :install_stage
call :clean_stage
goto :end

:clean_stage
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%" && if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
exit /b 0

:configure_stage
echo "Configuring %PKG_NAME% %PKG_VER%"
mkdir "%BUILD_DIR%" && cd "%BUILD_DIR%"
cmake -G "Ninja"                                                               ^
  -DBUILD_SHARED_LIBS=ON                                                       ^
  -DCMAKE_BUILD_TYPE=Release                                                   ^
  -DCMAKE_C_COMPILER=cl                                                        ^
  -DCMAKE_C_FLAGS="%C_OPTS% %C_DEFS%"                                          ^
  -DCMAKE_CXX_COMPILER=cl                                                      ^
  -DCMAKE_CXX_FLAGS="-EHsc %C_OPTS% %C_DEFS%"                                  ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                            ^
  -DCMAKE_POLICY_DEFAULT_CMP0074=OLD                                           ^
  -DSDL_ALSA=ON                                                                ^
  -DSDL_ALSA_SHARED=ON                                                         ^
  -DSDL_ASSEMBLY=ON                                                            ^
  -DSDL_AVX=ON                                                                 ^
  -DSDL_AVX2=ON                                                                ^
  -DSDL_AVX512F=ON                                                             ^
  -DSDL_CLOCK_GETTIME=ON                                                       ^
  -DSDL_DIRECTX=ON                                                             ^
  -DSDL_GPU_DXVK=ON                                                            ^
  -DSDL_HIDAPI=ON                                                              ^
  -DSDL_HIDAPI_JOYSTICK=ON                                                     ^
  -DSDL_HIDAPI_LIBUSB=ON                                                       ^
  -DSDL_HIDAPI_LIBUSB_SHARED=ON                                                ^
  -DSDL_IBUS=ON                                                                ^
  -DSDL_INSTALL=ON                                                             ^
  -DSDL_JACK=ON                                                                ^
  -DSDL_JACK_SHARED=ON                                                         ^
  -DSDL_KMSDRM=ON                                                              ^
  -DSDL_KMSDRM_SHARED=ON                                                       ^
  -DSDL_LASX=ON                                                                ^
  -DSDL_LIBC=ON                                                                ^
  -DSDL_LIBICONV=ON                                                            ^
  -DSDL_LSX=ON                                                                 ^
  -DSDL_METAL=ON                                                               ^
  -DSDL_MMX=ON                                                                 ^
  -DSDL_PTHREADS=ON                                                            ^
  -DSDL_PTHREADS_SEM=ON                                                        ^
  -DSDL_PULSEAUDIO=ON                                                          ^
  -DSDL_PULSEAUDIO_SHARED=ON                                                   ^
  -DSDL_RENDER_D3D=ON                                                          ^
  -DSDL_RENDER_D3D11=ON                                                        ^
  -DSDL_RENDER_D3D12=ON                                                        ^
  -DSDL_RENDER_GPU=ON                                                          ^
  -DSDL_RENDER_METAL=ON                                                        ^
  -DSDL_RENDER_VULKAN=ON                                                       ^
  -DSDL_SSE=ON                                                                 ^
  -DSDL_SSE2=ON                                                                ^
  -DSDL_SSE3=ON                                                                ^
  -DSDL_SSE4_1=ON                                                              ^
  -DSDL_SSE4_2=ON                                                              ^
  .. || exit 1
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja -k 0 -j%NUMBER_OF_PROCESSORS% || exit 1
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja install || exit 1
pushd "%PREFIX%\lib\pkgconfig"
sed -e "s#\([A-Za-z]\):/\([^/]\)#/\L\1\E/\2#g" -i sdl2.pc
popd
exit /b 0

:end
