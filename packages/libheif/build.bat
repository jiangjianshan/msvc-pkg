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
rem NOTE: Both AVM and libaom has same installation file name 'aom/aomdx.h', but
rem       the one from AVM may contain 'config/aom_config.h' which was not installed.
rem       So the patch for AVM maybe need if compiler said missing 'config/aom_config.h'
cmake -G "Ninja"                                                               ^
  -DBUILD_SHARED_LIBS=ON                                                       ^
  -DBUILD_TESTING=OFF                                                          ^
  -DCMAKE_BUILD_TYPE=Release                                                   ^
  -DCMAKE_C_COMPILER=cl                                                        ^
  -DCMAKE_C_FLAGS="%C_OPTS% %C_DEFS%"                                          ^
  -DCMAKE_C_STANDARD_LIBRARIES="ntdll.lib vmaf.lib pthread.lib"                ^
  -DCMAKE_CXX_COMPILER=cl                                                      ^
  -DCMAKE_CXX_FLAGS="-EHsc %C_OPTS% %C_DEFS%"                                  ^
  -DCMAKE_CXX_STANDARD_LIBRARIES="ntdll.lib vmaf.lib pthread.lib"              ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                            ^
  -DENABLE_PLUGIN_LOADING=OFF                                                  ^
  -DWITH_DAV1D=ON                                                              ^
  -DWITH_DAV1D_PLUGIN=OFF                                                      ^
  -DWITH_EXAMPLES=OFF                                                          ^
  -DWITH_JPEG_ENCODER=ON                                                       ^
  -DWITH_JPEG_DECODER=ON                                                       ^
  -DWITH_KVAZAAR=ON                                                            ^
  -DWITH_KVAZAAR_PLUGIN=OFF                                                    ^
  -DWITH_LIBDE265=ON                                                           ^
  -DWITH_LIBDE265_PLUGIN=OFF                                                   ^
  -DWITH_LIBSHARPYUV=ON                                                        ^
  -DWITH_RAV1E=ON                                                              ^
  -DWITH_RAV1E_PLUGIN=OFF                                                      ^
  -DWITH_SvtEnc=ON                                                             ^
  -DWITH_SvtEnc_PLUGIN=OFF                                                     ^
  -DWITH_UVG266=ON                                                             ^
  -DWITH_UVG266_PLUGIN=OFF                                                     ^
  -DWITH_VVDEC=ON                                                              ^
  -DWITH_VVDEC_PLUGIN=OFF                                                      ^
  -DWITH_VVENC=ON                                                              ^
  -DWITH_VVENC_PLUGIN=OFF                                                      ^
  -DWITH_X265=ON                                                               ^
  -DWITH_X265_PLUGIN=OFF                                                       ^
  -DWITH_FFMPEG_DECODER=ON                                                     ^
  -DWITH_FFMPEG_DECODER_PLUGIN=OFF                                             ^
  -DWITH_AOM_DECODER=ON                                                        ^
  -DWITH_AOM_DECODER_PLUGIN=OFF                                                ^
  -DWITH_AOM_ENCODER=ON                                                        ^
  -DWITH_AOM_ENCODER_PLUGIN=OFF                                                ^
  -DWITH_HEADER_COMPRESSION=ON                                                 ^
  -DWITH_JPEG_DECODER=ON                                                       ^
  -DWITH_JPEG_DECODER_PLUGIN=OFF                                               ^
  -DWITH_JPEG_ENCODER=ON                                                       ^
  -DWITH_JPEG_ENCODER_PLUGIN=OFF                                               ^
  -DWITH_OpenH264_DECODER=ON                                                   ^
  -DWITH_OpenH264_DECODER_PLUGIN=OFF                                           ^
  -DWITH_OpenH264_ENCODER=ON                                                   ^
  -DWITH_OpenJPEG_DECODER=ON                                                   ^
  -DWITH_OpenJPEG_DECODER_PLUGIN=OFF                                           ^
  -DWITH_OpenJPEG_ENCODER=ON                                                   ^
  -DWITH_OpenJPEG_ENCODER_PLUGIN=OFF                                           ^
  -DWITH_OPENJPH_DECODER=ON                                                    ^
  -DWITH_OPENJPH_ENCODER=ON                                                    ^
  -DWITH_REDUCED_VISIBILITY=OFF                                                ^
  -DWITH_UNCOMPRESSED_CODEC=ON                                                 ^
  .. || exit 1
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
pushd "%PREFIX%\lib\pkgconfig"
sed -e "s#\([=]\|-[IL]\|^\)\([A-Za-z]\):[\\/]#\1/\L\2/#g" -i libheif.pc
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
