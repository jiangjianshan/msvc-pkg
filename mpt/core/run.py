# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import logging
import os
import re
import subprocess
import sys

from pathlib import Path
from typing import Dict, Any, Optional, Union, List
from rich.text import Text

from mpt import ROOT_DIR
from mpt.config.package import PackageConfig
from mpt.config.user import UserConfig
from mpt.core.dependency import DependencyResolver
from mpt.core.log import RichLogger
from mpt.core.source import SourceManager
from mpt.core.view import RichPanel, RichTable
from mpt.utils.bash import BashUtils
from mpt.utils.path import PathUtils

class Runner:
    """
    Windows command execution and process management system with real-time output processing.

    Provides robust subprocess execution capabilities with Windows console mode preservation,
    real-time output analysis, and comprehensive logging. Handles both direct command
    execution and script file execution with appropriate interpreter selection.
    """

    # Class variables
    _saved_console_mode = None
    _proc_env = None  # Process environment variables

    @classmethod
    def _setup_basic_environment(cls, arch: str, lib_config: Dict[str, Any]) -> None:
        """
        Set up basic environment variables for the build process.

        Args:
            arch: Target architecture specification
            lib_config: Library configuration dictionary
        """
        # Set basic environment variables
        cls._proc_env['ARCH'] = arch

        # Set package-specific environment variables
        lib_name = lib_config.get('name')
        lib_ver = str(lib_config.get('version'))
        lib_url = lib_config.get('url')

        if SourceManager.is_git_url(lib_url):
            lib_srcdir = str(ROOT_DIR / 'releases' / lib_name)
        else:
            lib_srcdir = str(ROOT_DIR / 'releases' / f"{lib_name}-{lib_ver}")

        lib_script = lib_config.get('run')
        lib_rootdir = str(ROOT_DIR)

        if Path(lib_script).name.endswith('.sh'):
            lib_rootdir = PathUtils.win_to_unix(lib_rootdir)
            lib_srcdir = PathUtils.win_to_unix(lib_srcdir)

        cls._proc_env['ROOT_DIR'] = lib_rootdir
        cls._proc_env['SRC_DIR'] = lib_srcdir
        cls._proc_env['PKG_NAME'] = lib_name
        cls._proc_env['PKG_VER'] = lib_ver

    @classmethod
    def _setup_prefix_environment(cls, arch: str, lib: str, lib_config: Dict[str, Any]) -> str:
        """
        Set up prefix-related environment variables and PATH configurations.

        Args:
            arch: Target architecture specification
            lib: Library name for package-specific configuration
            lib_config: Library configuration dictionary

        Returns:
            str: The primary prefix path for the current library
        """
        prefix = str(ROOT_DIR / arch)
        cls._proc_env['_PREFIX'] = prefix
        prefix_paths = [prefix]

        user_settings = UserConfig.load()
        prefix_config = user_settings.get('prefix', {}) or {}

        # Process architecture-specific prefix configurations
        if arch in prefix_config:
            for lib_name, lib_prefix in prefix_config[arch].items():
                # Create environment variable name from library name
                prefix_env = lib_name.replace('-', '_').upper() + '_PREFIX'
                cls._proc_env[prefix_env] = lib_prefix

                # Update prefix if this is the current library
                if lib_name == lib:
                    prefix = lib_prefix

                # Add binary directory to PATH if it exists
                bin_dir = Path(lib_prefix) / 'bin'
                if bin_dir.exists():
                    current_path = cls._proc_env.get('PATH', '')
                    if str(bin_dir) not in current_path:
                        cls._proc_env['PATH'] = f"{str(bin_dir)}{os.pathsep}{current_path}"

                # Add to prefix paths
                prefix_paths.append(lib_prefix)

        # Set final environment variables
        cls._proc_env['PREFIX_PATH'] = os.pathsep.join(prefix_paths)

        lib_script = lib_config.get('run')
        if Path(lib_script).name.endswith('.sh'):
            prefix = PathUtils.win_to_unix(prefix)

        cls._proc_env['PREFIX'] = prefix
        return prefix

    @classmethod
    def _setup_dependency_environment(cls, lib: str) -> None:
        """
        Set up environment variables for library dependencies.

        Args:
            lib: Library name for which to set up dependency environment variables
        """
        deps = DependencyResolver.get_dependencies(lib)
        for dep in deps:
            dep_config = PackageConfig.load(dep)
            dep_name = dep_config.get('name')
            dep_ver = dep_config.get('version')
            dep_url = dep_config.get('url')

            dep_src_env = dep_name.replace('-', '_').upper() + '_SRC'
            if SourceManager.is_git_url(dep_url):
                cls._proc_env[dep_src_env] = str(ROOT_DIR / 'releases' / f"{dep_name}")
            else:
                cls._proc_env[dep_src_env] = str(ROOT_DIR / 'releases' / f"{dep_name}-{dep_ver}")

            dep_ver_env = dep_name.replace('-', '_').upper() + '_VER'
            cls._proc_env[dep_ver_env] = str(dep_ver)

    @classmethod
    def _display_environment_summary(cls) -> None:
        """
        Display a formatted table of newly configured environment variables.

        Creates a visually appealing table showing environment variables that were
        set during the environment setup process, excluding common system variables
        like PATH. Uses appropriate emoji symbols to enhance readability.
        """
        # Create table with emoji-enhanced title
        table = RichTable.create(title="🌍 Environment Variables Setup")

        # Define emoji mapping for environment variables based on their characteristics
        emoji_mapping = {
            'ARCH': '🔧',
            'ROOT_DIR': '📁',
            'SRC_DIR': '📂',
            'PKG_NAME': '📚',
            'PKG_VER': '📜',
            'PREFIX': '📍',
            'PREFIX_PATH': '🧭',
            '_PREFIX': '🔗'
        }

        # Add columns to table
        RichTable.add_column(table, "Variable", style="cyan", justify="left")
        RichTable.add_column(table, "Value", style="green", justify="left")

        # Collect environment variables to display based on their characteristics
        env_vars_to_display = []

        # 1. Basic environment variables (from _setup_basic_environment)
        basic_vars = ['ARCH', 'ROOT_DIR', 'SRC_DIR', 'PKG_NAME', 'PKG_VER']
        env_vars_to_display.extend(basic_vars)

        # 2. Prefix environment variables (from _setup_prefix_environment)
        prefix_vars = ['PREFIX', 'PREFIX_PATH', '_PREFIX']
        env_vars_to_display.extend(prefix_vars)

        # 3. Dependency environment variables (from _setup_dependency_environment)
        # Look for variables ending with _SRC or _VER
        for key in cls._proc_env:
            if key.endswith('_SRC') or key.endswith('_VER'):
                env_vars_to_display.append(key)
                # Assign appropriate emoji if not already in mapping
                if key not in emoji_mapping:
                    emoji_mapping[key] = '📂' if key.endswith('_SRC') else '📜'

        # 4. Library-specific prefix variables (e.g., LIBNAME_PREFIX)
        for key in cls._proc_env:
            if key.endswith('_PREFIX') and key != '_PREFIX':
                env_vars_to_display.append(key)
                if key not in emoji_mapping:
                    emoji_mapping[key] = '📌'

        # Display the collected environment variables
        for key in env_vars_to_display:
            if key in cls._proc_env and key != 'PATH':  # Skip PATH as requested
                emoji = emoji_mapping.get(key, '📝')  # Default emoji for unexpected vars
                RichTable.add_row(table, f"{emoji} {key}", str(cls._proc_env[key]))

        # Render the table
        RichTable.render(table, align_center=False)

    @classmethod
    def setup_environment(cls, arch: str, lib: str) -> None:
        """
        Prepare and configure environment variables for Windows build processes.

        Constructs a comprehensive environment setup including:
        - Architecture-specific build settings (ARCH)
        - Library-specific configuration values (PKG_NAME, PKG_VER, SRC_DIR)
        - Prefix path configurations from user settings
        - Dependency library prefix references
        - PATH updates for dependency binaries
        - Source directory references for dependencies

        Args:
            arch: Target architecture specification (e.g., 'x86_64', 'arm64')
            lib: Library name for package-specific configuration loading

        Note:
            This method modifies the class-level _proc_env variable which is used
            by subsequent execute() calls. It should be called before any command execution.
        """
        # Create fresh environment copy to ensure isolation
        cls._proc_env = os.environ.copy()

        # Load package configuration
        lib_config = PackageConfig.load(lib)

        # Set up environment in logical stages
        cls._setup_basic_environment(arch, lib_config)
        cls._setup_prefix_environment(arch, lib, lib_config)
        cls._setup_dependency_environment(lib)
        cls._display_environment_summary()

    @classmethod
    def _save_console_mode(cls):
        """
        Preserve the current Windows console mode configuration.

        Captures and stores the current console mode settings to ensure they can be
        restored after subprocess execution. This is critical for maintaining terminal
        functionality and appearance when child processes modify console settings.

        Note:
            Only applicable on Windows platforms; no-op on other operating systems
        """
        if sys.platform != 'win32':
            return

        try:
            import ctypes
            from ctypes import wintypes

            STD_OUTPUT_HANDLE = -11
            handle = ctypes.windll.kernel32.GetStdHandle(STD_OUTPUT_HANDLE)

            mode = wintypes.DWORD()
            if ctypes.windll.kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
                cls._saved_console_mode = mode.value
                RichLogger.debug(f"Saved console mode: {cls._saved_console_mode:#x}")
        except Exception as e:
            RichLogger.exception(f"Save console mode error: {e}")

    @classmethod
    def _restore_console_mode(cls):
        """
        Restore previously saved Windows console mode configuration.

        Reapplies the console mode settings that were captured before subprocess
        execution. This ensures terminal functionality remains consistent even after
        child processes may have altered console behavior.

        Note:
            Only executes on Windows when console mode was previously saved
        """
        if sys.platform != 'win32' or cls._saved_console_mode is None:
            return

        try:
            import ctypes
            from ctypes import wintypes

            STD_OUTPUT_HANDLE = -11
            handle = ctypes.windll.kernel32.GetStdHandle(STD_OUTPUT_HANDLE)

            # Get current mode
            current_mode = wintypes.DWORD()
            if not ctypes.windll.kernel32.GetConsoleMode(handle, ctypes.byref(current_mode)):
                return

            # Restore only if changed
            if current_mode.value != cls._saved_console_mode:
                if ctypes.windll.kernel32.SetConsoleMode(handle, cls._saved_console_mode):
                    RichLogger.debug(f"Restored console mode: {cls._saved_console_mode:#x}")
        except Exception as e:
            RichLogger.exception(f"Restore console mode error: {e}")

    @classmethod
    def execute(cls, cmds: Union[List[str], str], shell: bool = False, log_file: Optional[Union[str, Path]] = None) -> int:
        """
        Execute system commands with real-time output processing and error detection.

        Provides a robust command execution interface with comprehensive features:
        - Real-time output parsing with error and warning pattern detection
        - Windows console mode preservation
        - Optional file logging for output capture and archival
        - Detailed execution summary with statistics and status reporting
        - Proper environment variable handling for build processes

        Args:
            cmds: Command specification as either a list of arguments or a single string
            shell: If True, execute the command through the system shell
            log_file: Optional path for capturing process output to a log file

        Returns:
            int: Exit code of the executed process (0 for success), or -1 if execution
                 failed due to an exception.
        """
        error_pattern = re.compile(r'(?i)(?:^|\s)(?:error\s*[#:]\s*\d+|error\s+[A-Z]+\d+|\berror\b\s*:\s*[^\\/]|\berror\b\s+\d+|CMake Error|fatal[^:]*:|ERROR:|(?:configure|ninja|NMAKE)\s*:\s*(?:fatal\s+)?error|make.*(?:Error \d+|Stop\.|Segmentation fault)|MSB\d+\s*error)')
        warning_pattern = re.compile(r'(?i)(?:^|\s)(?:warning\s*[#:]\s*\d+|warning\s+[A-Z]+\d+|\bwarning\b\s*:\s*[^\\/]|CMake Warning|WARNING:|(?:configure|ninja|NMAKE)\s*:\s*warning|MSB\d+\s*warning)')
        exit_code = -1
        error_count = 0
        warning_count = 0

        try:
            # Save console mode before execution
            cls._save_console_mode()
            if log_file:
                RichLogger.add_file_logging(log_file)
            p = subprocess.Popen(
                cmds,
                shell=shell,
                env=cls._proc_env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT
            )
            # Process output in real-time
            for line in iter(p.stdout.readline, b''):
                decoded_line = line.decode('utf-8', errors='ignore').rstrip()
                if error_pattern.search(decoded_line):
                    RichLogger.error(decoded_line, markup=False)
                    error_count += 1
                elif warning_pattern.search(decoded_line):
                    RichLogger.warning(decoded_line, markup=False)
                    warning_count += 1
                else:
                    RichLogger.info(decoded_line, markup=False)
                if p.poll() is not None:
                    break
            # Wait for process completion
            exit_code = p.wait()
            return exit_code

        except Exception as e:
            RichLogger.exception(f"Unhandled execution error: [bold red]{str(e)}[/bold red]")
            return -1

        finally:
            if log_file:
                RichLogger.remove_file_logging()
            # CRITICAL: Restore console mode immediately after process exits
            cls._restore_console_mode()
            RichLogger.debug(f"Process exit code: {exit_code}")
            status = "✅ Success" if exit_code == 0 else "❌ Failed"
            summary_text = Text.from_markup(
                f"📊 Status: [bold green]{status}[/bold green] | "
                f"🔢 Exit Code: [bold cyan]{exit_code}[/bold cyan] | "
                f"❌ Errors: [bold red]{error_count}[/bold red] | "
                f"🔶 Warnings: [bold yellow]{warning_count}[/bold yellow]",
                justify="center"
            )
            RichPanel.summary(
                content=summary_text,
                title="Execution Summary"
            )

    @classmethod
    def run_script(cls, script_file: Union[str, Path], log_file: Optional[Union[str, Path]] = None) -> bool:
        """
        Execute script files with automatic interpreter selection on Windows.

        Handles the execution of various script types with appropriate interpreter
        selection:
        - .bat files: executed directly
        - Other scripts: executed using Bash (typically Git Bash on Windows)

        The method automatically changes the working directory to the script's location
        during execution and restores the original directory afterwards.

        Args:
            script_file: Path to the script file to execute
            log_file: Optional path for capturing script output to a log file

        Returns:
            bool: True if script executed successfully (exit code 0), False otherwise
        """
        script_file = Path(script_file) if isinstance(script_file, str) else script_file
        script_dir = script_file.parent
        orig_dir = os.getcwd()
        try:
            os.chdir(script_dir)
            if script_file.name.endswith('.bat'):
                cmds = [script_file.name]
            else:
                bash_path = BashUtils.find_bash()
                if not bash_path:
                    RichLogger.critical("Bash not found")
                    return False
                cmds = [bash_path, script_file.name]
            exit_code = cls.execute(cmds, log_file=log_file)
            return exit_code == 0
        except Exception as e:
            RichLogger.exception(f"Failed to execute script: {e}")
            return False
        finally:
            os.chdir(orig_dir)
