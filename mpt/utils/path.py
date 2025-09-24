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

from mpt.core.log import Logger
from mpt.core.console import console
from mpt.utils.bash import BashUtils

class PathUtils:
    """
    Cross-platform path format conversion utility with Cygwin integration support.

    Provides specialized path conversion capabilities between Windows and Unix/Linux
    path formats, primarily targeting environments where Windows paths need to be
    used within Unix-like subsystems such as Cygwin or WSL (Windows Subsystem for Linux).
    """

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
                Logger.warning(f"Path does not exist: [bold yellow]{path}[/bold yellow]")

            bash_path = BashUtils.find_bash()
            if not bash_path:
                Logger.error("Bash not found, cannot convert path")
                return str(path)

            cmd = f"cygpath -u \"{str(path)}\""
            result = subprocess.run(
                [bash_path, "-c", cmd],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )

            unix_path = result.stdout.strip()
            return unix_path
        except Exception as e:
            Logger.exception(f"Exception occurred during path conversion: {e}")
            return str(path)
