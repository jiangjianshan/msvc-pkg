@echo off
rem
rem MSVC-PKG Main Entry Batch Script - Windows Environment Configuration and Bootstrap
rem
rem Provides the primary execution environment for the MSVC-PKG package management system.
rem Configures Windows environment variables, validates dependencies, and initializes
rem the Python-based package management toolchain with proper system configuration.

rem Set console code page to UTF-8 (65001) to support Unicode characters
rem Essential for proper display of formatted output and international text
chcp 65001 >nul

setlocal enabledelayedexpansion

rem Configure MSYS2 compatibility environment variables
rem These settings ensure proper symbolic link handling and path inheritance
set LOGONSERVER=\\LOCALHOST

rem Native Windows symbolic link support
set MSYS=winsymlinks:nativestrict

rem Inherit system PATH in MSYS2 environment
set MSYS2_PATH_TYPE=inherit

rem NOTE:
rem MSYSTEM environment variable intentionally not set
rem This prevents interference with MSYS2 toolchain detection while maintaining
rem compatibility with packages that inspect MSYSTEM for build configuration
rem Some packages (e.g., gobject-introspection) use MSYSTEM to determine compiler
rem behavior, but all build.bat scripts execute outside MSYS2 environment
rem set MSYSTEM=MINGW64

rem Configure Python runtime environment
rem Prevent .pyc file generation to avoid clutter and potential version conflicts
set PYTHONDONTWRITEBYTECODE=1

rem Ensure UTF-8 encoding for all Python input/output operations
set PYTHONIOENCODING=utf-8

rem Set internationalization and localization variables
rem Uniform UTF-8 locale settings for consistent text processing
set LANG=en_US.UTF-8
set LC_ALL=en_US.UTF-8
set LC_CTYPE=en_US.UTF-8

rem Disable GObject introspection cache to prevent stale binding issues
set GI_SCANNER_DISABLE_CACHE=1

rem Verify Python installation exists and is accessible
python --version >nul 2>&1 || (
    echo Python not found. Please install from: https://www.python.org/downloads/
    pause
    exit /b 1
)

rem Check for required Python packages using importlib
rem Installs missing dependencies automatically if not present
python -c "import importlib.util as i;exit(any(not i.find_spec(m) for m in('pygments','yaml','rich','requests','zstandard')))" >nul 2>&1 || (
    echo Installing required Python packages...
    python -m pip install Pygments PyYAML rich requests zstandard
)

rem  https://docs.python.org/3/using/windows.html#removing-the-max-path-limitation
reg query HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled >nul 2>&1 || (
  reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t reg_DWORD /d 1
)

set "ORIG_PATH=%PATH%"
set "PATH=%~dp0installed\x64-windows\bin;%~dp0installed\x86-windows\bin;%PATH%"
python main.py %*
set "PATH=%ORIG_PATH%"
