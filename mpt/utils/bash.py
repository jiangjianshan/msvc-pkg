# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
import re
import shutil
import stat
import subprocess
import sys
import time
import winreg
import locale

from pathlib import Path
from typing import Optional

from mpt.core.log import Logger
from mpt.core.console import console

class BashUtils:
    """
    Windows-specific Bash and Git location utility with caching and comprehensive error handling.

    Provides robust methods for locating Git installation directories and Bash executables
    on Windows systems. Implements caching mechanisms for performance optimization and
    includes detailed error reporting and logging for troubleshooting installation issues.
    """

    _git_root = None
    _bash_path = None
    _sed_path = None

    @classmethod
    def find_git_root(cls):
        """
        Locate the root installation directory of Git on Windows systems.

        Implements a multi-step discovery process to find the Git installation directory:
        1. Checks for cached result to avoid redundant searches
        2. Locates git.exe executable using system PATH search
        3. Derives Git root directory from executable location
        4. Validates directory existence and accessibility
        5. Caches successful results for future reference

        Returns:
            str: Absolute path to the Git installation root directory,
                 or None if Git is not found or inaccessible
        """
        if cls._git_root:
            return cls._git_root

        git_path = cls.find_git()
        if not git_path:
            return None

        try:
            if isinstance(git_path, bytes):
                git_path = git_path.decode(locale.getpreferredencoding())

            git_dir = Path(git_path).resolve().parent.parent
            if git_dir.exists():
                cls._git_root = str(git_dir)
                return cls._git_root
            Logger.warning(f"Git root directory does not exist: [bold cyan]{git_dir}[/bold cyan]")
            return None
        except Exception as e:
            Logger.exception(f"Error resolving Git root: [bold red]{str(e)}[/bold red]")
            return None

    @classmethod
    def find_bash(cls):
        """
        Locate the Bash executable within a Git installation on Windows.

        Finds the bash.exe executable that is typically bundled with Git for Windows.
        Uses cached Git root directory information when available to optimize
        search performance and provides detailed error reporting for missing components.

        Returns:
            str: Absolute path to the bash.exe executable,
                 or None if Bash is not found within the Git installation
        """
        if cls._bash_path:
            return cls._bash_path

        git_root = cls.find_git_root()
        if not git_root:
            Logger.warning("Cannot find bash.exe without Git root directory")
            return None

        try:
            bash_path = Path(git_root) / 'bin' / 'bash.exe'
            if bash_path.exists():
                cls._bash_path = str(bash_path)
                return cls._bash_path
            Logger.warning(f"bash.exe not found in directory: [bold cyan]{bash_path.parent}[/bold cyan]")
            return None
        except Exception as e:
            Logger.exception(f"Error locating bash.exe: [bold red]{str(e)}[/bold red]")
            return None

    @staticmethod
    def find_git():
        """
        Search system PATH and registry for Git executable with comprehensive error handling.

        Executes a system-wide search for git.exe using multiple discovery strategies:
        1. Queries the system PATH environment variable using 'where' command
        2. Handles encoding variations in path output
        3. Validates each candidate path for file existence
        4. Provides detailed logging of search process and results

        Returns:
            str: Absolute path to the first valid git.exe found in system PATH,
                 or None if no Git installation is detected
        """
        try:
            result = subprocess.run(
                ["where", "git.exe"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )

            if result.returncode != 0:
                Logger.error("Git not found in system PATH")
                return None

            paths = []
            for path in result.stdout.splitlines():
                if path:
                    try:
                        str_path = path.decode(locale.getpreferredencoding()).strip()
                        normalized = os.path.normpath(str_path)
                        paths.append(normalized)
                    except UnicodeDecodeError:
                        Logger.warning(f"Failed to decode path: [bold cyan]{path}[/bold cyan]")
                        continue

            for path in paths:
                if os.path.exists(path):
                    return path
            Logger.warning("No valid Git installation found in system PATH")
            return None
        except subprocess.CalledProcessError as e:
            error_msg = e.stderr.decode(errors='ignore') if e.stderr else "Unknown error"
            Logger.exception(f"{error_msg}")
        except Exception as e:
            Logger.exception(f"Unexpected error finding git.exe: [bold red]{str(e)}[/bold red]")
            return None
