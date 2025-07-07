@echo off
setlocal enabledelayedexpansion
rem
rem  Build script for the current library, it should not be called directly from the
rem  command line, but should be called from mpt.py.
rem
rem  The values of these environment variables come from mpt.py:
rem  ARCH            - x64 or x86
rem  ROOT_DIR        - root location of msvc-pkg
rem  PREFIX          - install location of current library
rem  PREFIX_PATH     - install location of third party libraries
rem  _PREFIX         - default install location if not list in settings.yaml
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

for /f "delims=" %%i in ('yq -r ".name" config.yaml') do set PKG_NAME=%%i
for /f "delims=" %%i in ('yq -r ".version" config.yaml') do set PKG_VER=%%i
if "%ROOT_DIR%"=="" (
    echo Don't directly run %~nx0 from command line.
    echo To build !PKG_NAME! and its dependencies, please go to the root location of msvc-pkg, and then press
    echo mpt !PKG_NAME!
    goto :end
)
call "%ROOT_DIR%\compiler.bat" %ARCH%
set RELS_DIR=%ROOT_DIR%\releases
set SRC_DIR=%RELS_DIR%\%PKG_NAME%-%PKG_VER%
set BUILD_DIR=%SRC_DIR%
set C_OPTS=-nologo -MD -diagnostics:column -wd4819 -wd4996 -fp:precise -openmp:llvm -utf-8 -Zc:__cplusplus -experimental:c11atomics
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX

call :configure_stage
call :build_stage
call :install_package
goto :end

rem ==============================================================================
rem  Configure package and ready to build
rem ==============================================================================
:configure_stage
rem  call :clean_build
echo "Configuring %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
rem TODO:
rem 1. If the build folder is not same as source folder, following issue will occur:
rem    executable host ruby is required. use --with-baseruby option.
rem 2. If Visual C++ compiler version is euqal or higher than 17.13, following issue
rem    may occur and fail to build:
rem  linking miniruby.exe
rem     Creating library miniruby.lib and object miniruby.exp
rem  [BUG] heap_idx_for_size: allocation size too large (size=145u, heap_idx=146u)
rem  ruby 3.4.2 (2025-02-15 revision d2930f8e7a) [x64-mswin64_140]
rem
rem  -- Control frame information -----------------------------------------------
rem  c:0001 p:---- s:0003 e:000002 DUMMY  [FINISH]
rem
rem  -- Threading information ---------------------------------------------------
rem  Total ractor count: 0
rem  Ruby thread count for this ractor: 0
rem
rem  -- C level backtrace information -------------------------------------------
rem  C:\Windows\SYSTEM32\ntdll.dll(ZwWaitForSingleObject+0x14) [0x00007FFE8826D574]
rem  C:\Windows\System32\KERNELBASE.dll(WaitForSingleObjectEx+0x8e) [0x00007FFE85C0920E]
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\miniruby.exe(rb_print_backtrace+0x3e) [0x00007FF76458648A]
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\vm_dump.c:847
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\miniruby.exe(rb_vm_bugreport+0x1ba) [0x00007FF76458664A]
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\vm_dump.c:1158
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\miniruby.exe(rb_bug_without_die_internal+0x72) [0x00007FF764451C72]
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\error.c:1097
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\miniruby.exe(rb_bug+0x20) [0x00007FF764451B60] E:\Githubs\msvc-pkg\releases\ruby-3.4.2\error.c:1117
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\miniruby.exe(newobj_of+0x1d0) [0x00007FF764467E34] E:\Githubs\msvc-pkg\releases\ruby-3.4.2\gc.c:1024
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\miniruby.exe(rb_wb_protected_newobj_of+0x35) [0x00007FF76446F589]
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\gc.c:1063
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\miniruby.exe(rb_str_buf_new+0x4d) [0x00007FF764529759]
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\string.c:1646
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\miniruby.exe(rb_enc_vsprintf+0x27) [0x00007FF76451A35B]
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\sprintf.c:1184
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\miniruby.exe(rb_raise+0x26) [0x00007FF764452A5A] E:\Githubs\msvc-pkg\releases\ruby-3.4.2\error.c:3768
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\miniruby.exe(rb_st_init_existing_table_with_size+0x102) [0x00007FF76451E69A]
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\st.c:531
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\miniruby.exe(rb_st_init_table_with_size+0x30) [0x00007FF76451E724]
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\st.c:587
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\miniruby.exe(rb_vm_encoded_insn_data_table_init+0x1f) [0x00007FF764496E83]
rem  E:\Githubs\msvc-pkg\releases\ruby-3.4.2\iseq.c:3745
rem
win32\configure.bat --prefix="%PREFIX%" --srcdir="%SRC_DIR%" || exit 1
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
nmake install || exit 1
call :clean_build
exit /b 0

rem ==============================================================================
rem  Clean files generated during build procedure
rem ==============================================================================
:clean_build
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%
del /s /q *.obj *.exe *.lib *.dll *.exp *.pdb
exit /b 0

:end
