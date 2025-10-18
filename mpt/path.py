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

from pathlib import Path
from typing import Optional

from mpt.bash import BashUtils
from mpt.log import RichLogger


class PathUtils:
    """
    Cross-platform path format conversion utility with Cygwin integration support.

    Provides specialized path conversion capabilities between Windows and Unix/Linux
    path formats, primarily targeting environments where Windows paths need to be
    used within Unix-like subsystems such as Cygwin or WSL (Windows Subsystem for Linux).
    """

    @staticmethod
    def is_windows_path(path):
        """
        Check if the given path follows Windows path format.

        This method examines the path string to determine if it conforms to Windows
        path conventions, such as starting with a drive letter (e.g., C:\\) or using
        backslashes as directory separators.

        Args:
            path: Path string to evaluate

        Returns:
            bool: True if the path appears to be a Windows path, False otherwise
        """
        # Convert to string if it's a Path object
        path_str = str(path) if isinstance(path, Path) else path

        # Check for Windows drive letter pattern (e.g., C:\ or C:/)
        if re.match(r'^[A-Za-z]:[\\/]', path_str):
            return True

        # Check for UNC path pattern (e.g., \\server\share)
        if re.match(r'^\\\\\\\\[^\\\\/]+[\\\\/]+[^\\\\/]+', path_str):
            return True

        # Check for predominant use of backslashes as separators
        if '\\' in path_str and (path_str.count('\\') > path_str.count('/')):
            return True

        return False

    @staticmethod
    def win_to_unix(path):
        """
        Convert Windows-native file paths to Unix/Linux format using Cygwin's path conversion.

        This method leverages the Cygwin environment's path conversion capabilities to
        transform Windows-style paths (e.g., "C:\\Users\\name") to Unix-style paths
        (e.g., '/c/Users/name'). Essential for interoperability between
        Windows applications and Unix-based tools or subsystems.

        Args:
            path: Windows path to convert, either as a Path object or string representation

        Returns:
            str: Unix-formatted path string, or original path if conversion fails

        Note:
            Requires Git for Windows installation and proper bash environment setup.
            Falls back to returning the original path if conversion is not possible.
        """
        try:
            if not isinstance(path, Path):
                path = Path(path)

            if not path.exists():
                RichLogger.warning(f"Path does not exist: [bold yellow]{path}[/bold yellow]")

            bash_path = BashUtils.find_bash()
            if not bash_path:
                RichLogger.error("Bash not found, cannot convert path")
                return str(path)

            cmd = f"cygpath -u \"{str(path)}\""
            result = subprocess.run(
                [bash_path, "-c", cmd],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )

            unix_path = result.stdout.decode('utf-8').strip()
            return unix_path
        except Exception as e:
            RichLogger.exception(f"Exception occurred during path conversion: {e}")
            return str(path)

    @staticmethod
    def unix_to_win(path):
        """
        Convert Unix/Linux file paths to Windows-native format using Cygwin's path conversion.

        This method leverages the Cygwin environment's path conversion capabilities to
        transform Unix-style paths (e.g., '/c/Users/name') to Windows-style paths
        (e.g., "C:\\Users\\name"). Essential for interoperability between
        Unix-based tools and Windows applications.

        Args:
            path: Unix path to convert, either as a Path object or string representation

        Returns:
            str: Windows-formatted path string, or original path if conversion fails

        Note:
            Requires Git for Windows installation and proper bash environment setup.
            Falls back to returning the original path if conversion is not possible.
        """
        try:
            # Convert to string if it's a Path object
            path_str = str(path) if isinstance(path, Path) else path

            bash_path = BashUtils.find_bash()
            if not bash_path:
                RichLogger.error("Bash not found, cannot convert path")
                return path_str

            cmd = f"cygpath -w \"{path_str}\""
            result = subprocess.run(
                [bash_path, "-c", cmd],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )

            win_path = result.stdout.decode('utf-8').strip()
            return win_path
        except Exception as e:
            RichLogger.exception(f"Exception occurred during path conversion: {e}")
            return str(path) if isinstance(path, Path) else path
