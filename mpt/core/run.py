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
from rich.text import Text

from mpt.utils.bash import BashUtils
from mpt.core.console import console
from mpt.core.log import Logger
from mpt.core.view import RichPanel

class Runner:
    """
    Advanced command execution and process management system with real-time output processing.

    Provides robust subprocess execution capabilities with cross-platform compatibility,
    console mode preservation, real-time output analysis, and comprehensive logging.
    Handles both direct command execution and script file execution with appropriate
    interpreter selection.
    """

    # Class variable to store original console mode
    _saved_console_mode = None

    @staticmethod
    def _save_console_mode():
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
                Runner._saved_console_mode = mode.value
                Logger.debug(f"Saved console mode: {Runner._saved_console_mode:#x}")
        except Exception as e:
            Logger.exception(f"Save console mode error: {e}")

    @staticmethod
    def _restore_console_mode():
        """
        Restore previously saved console mode configuration on Windows systems.

        Reapplies the console mode settings that were captured before subprocess
        execution. This ensures terminal functionality remains consistent even after
        child processes may have altered console behavior.

        Note:
            Only executes on Windows when console mode was previously saved
        """
        if sys.platform != 'win32' or Runner._saved_console_mode is None:
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
            if current_mode.value != Runner._saved_console_mode:
                if ctypes.windll.kernel32.SetConsoleMode(handle, Runner._saved_console_mode):
                    Logger.debug(f"Restored console mode: {Runner._saved_console_mode:#x}")
        except Exception as e:
            Logger.exception(f"Restore console mode error: {e}")

    @staticmethod
    def execute(env, cmds, shell=False, log_file=None):
        """
        Execute system commands with real-time output processing and error detection.

        Provides a robust command execution interface with comprehensive features:
        - Real-time output parsing with error and warning pattern detection
        - Cross-platform compatibility with Windows console mode preservation
        - Optional file logging for output capture and archival
        - Detailed execution summary with statistics and status reporting
        - Proper environment variable handling for build processes

        Args:
            env: Dictionary of environment variables to set for the subprocess
            cmds: Command specification as either a list of arguments or a single string
            shell: Boolean indicating whether to execute through system shell
            log_file: Optional path for capturing process output to a log file

        Returns:
            int: Exit code of the executed process, or -1 if execution failed

        Raises:
            Preserves subprocess exceptions but handles them internally with logging
        """
        error_pattern = re.compile(r'\b[Ee]rror\b\s+:?')
        warning_pattern = re.compile(r'\b[Ww]arning\b\s+:?')
        exit_code = -1
        error_count = 0
        warning_count = 0

        try:
            # Save console mode before execution
            Runner._save_console_mode()
            if log_file:
                Logger.add_file_logging(log_file)
            p = subprocess.Popen(
                cmds,
                shell=shell,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT
            )
            # Process output in real-time
            for line in iter(p.stdout.readline, b''):
                decoded_line = line.decode('utf-8', errors='ignore').rstrip()
                if error_pattern.search(decoded_line):
                    Logger.error(decoded_line, markup=False)
                    error_count += 1
                elif warning_pattern.search(decoded_line):
                    Logger.warning(decoded_line, markup=False)
                    warning_count += 1
                else:
                    Logger.info(decoded_line, markup=False)
                if p.poll() is not None:
                    break
            # Wait for process completion
            exit_code = p.wait()
            return exit_code

        except Exception as e:
            Logger.exception(f"Unhandled execution error: [bold red]{str(e)}[/bold red]")
            return -1

        finally:
            if log_file:
                Logger.remove_file_logging()
            # CRITICAL: Restore console mode immediately after process exits
            Runner._restore_console_mode()
            Logger.debug(f"Process exit code: {exit_code}")
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

    @staticmethod
    def run_script(env, script_file, log_file=None):
        """
        Execute script files with automatic interpreter selection and environment setup.

        Handles the execution of various script types with appropriate interpreter
        selection (.bat files on Windows, shell scripts via Bash on all platforms).
        Manages working directory changes and provides consistent environment setup
        for reproducible script execution.

        Args:
            env: Dictionary of environment variables for script execution
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
                    Logger.critical("Bash not found")
                    return False
                cmds = [bash_path, script_file.name]
            exit_code = Runner.execute(env, cmds, log_file=log_file)
            return exit_code == 0
        except Exception as e:
            Logger.exception(f"Failed to execute script: {e}")
            return False
        finally:
            os.chdir(orig_dir)
