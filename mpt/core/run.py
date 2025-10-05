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
from mpt.core.log import RichLogger
from mpt.core.view import RichPanel
from mpt.utils.bash import BashUtils

class Runner:
    """
    Advanced command execution and process management system with real-time output processing.

    Provides robust subprocess execution capabilities with cross-platform compatibility,
    console mode preservation, real-time output analysis, and comprehensive logging.
    Handles both direct command execution and script file execution with appropriate
    interpreter selection.
    """

    # Class variables
    _saved_console_mode = None
    _proc_env = None  # Process environment variables

    @classmethod
    def prepare_envvars(cls, arch: str, lib: str) -> None:
        """
        Prepare and configure environment variables for build processes.

        Constructs a comprehensive environment setup including:
        - Architecture-specific build settings
        - Library-specific configuration values
        - Prefix path configurations from user settings
        - Dependency library prefix references
        - PATH updates for dependency binaries

        Args:
            arch: Target architecture specification for environment tuning
            lib: Library name for package-specific configuration loading
        """
        # Create fresh environment copy to ensure isolation
        cls._proc_env = os.environ.copy()

        # Set basic environment variables
        cls._proc_env['ARCH'] = arch
        cls._proc_env['ROOT_DIR'] = str(ROOT_DIR)

        # Load package configuration and set package-specific variables
        config = PackageConfig.load(lib)
        cls._proc_env['PKG_NAME'] = config.get('name')
        cls._proc_env['PKG_VER'] = str(config.get('version'))

        # Set prefix paths
        prefix = ROOT_DIR / arch
        cls._proc_env['_PREFIX'] = str(prefix)

        prefix_paths = [str(prefix)]
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
        cls._proc_env['PREFIX'] = str(prefix)

    @classmethod
    def _save_console_mode(cls):
        """
        Preserve the current console mode configuration on Windows systems.

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
        Restore previously saved console mode configuration on Windows systems.

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
        - Cross-platform compatibility with Windows console mode preservation
        - Optional file logging for output capture and archival
        - Detailed execution summary with statistics and status reporting
        - Proper environment variable handling for build processes

        Args:
            cmds: Command specification as either a list of arguments or a single string
            shell: Boolean indicating whether to execute through system shell
            log_file: Optional path for capturing process output to a log file

        Returns:
            int: Exit code of the executed process, or -1 if execution failed

        Raises:
            Preserves subprocess exceptions but handles them internally with logging
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
            status = "✅ Success" if exit_code == 0 else "❌❌ Failed"
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
        Execute script files with automatic interpreter selection and environment setup.

        Handles the execution of various script types with appropriate interpreter
        selection (.bat files on Windows, shell scripts via Bash on all platforms).
        Manages working directory changes and provides consistent environment setup
        for reproducible script execution.

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
