# -*- coding: utf-8 -*-
#
# Copyright (c) 2024 Jianshan Jiang
#
import hashlib
import os
import re
import shutil
import stat
import subprocess
import sys
import time
import winreg
import ctypes

from ctypes import wintypes
from pathlib import Path
from typing import Optional

from mpt.log import RichLogger


# Define Windows API constants
FO_DELETE = 0x0003
FOF_ALLOWUNDO = 0x0040
FOF_NOCONFIRMATION = 0x0010
FOF_NOERRORUI = 0x0400
FOF_SILENT = 0x0004

class SHFILEOPSTRUCTW(ctypes.Structure):
    """Structure for the Windows SHFileOperation function."""
    _fields_ = [
        ("hwnd", wintypes.HWND),
        ("wFunc", ctypes.c_uint),
        ("pFrom", ctypes.c_wchar_p),
        ("pTo", ctypes.c_wchar_p),
        ("fFlags", ctypes.c_short),
        ("fAnyOperationsAborted", wintypes.BOOL),
        ("hNameMappings", ctypes.c_void_p),
        ("lpszProgressTitle", ctypes.c_wchar_p),
    ]

class FileUtils:
    """
    A utility class for comprehensive file system operations.

    Provides robust methods for file and directory management, including deletion
    (with options for permanent removal or moving to the recycle bin), permission
    handling, and error recovery. Designed for cross-platform compatibility and
    challenging file system scenarios.
    """

    @staticmethod
    def _move_to_recycle_bin(path):
        """
        Moves a file or directory to the Windows Recycle Bin using the Windows Shell API.

        Args:
            path: A Path object or string representing the target file or directory.

        Returns:
            bool: True if the operation succeeded, False otherwise.
        """
        try:
            # Convert to absolute path string
            path_str = os.path.abspath(str(path))

            if not os.path.exists(path_str):
                RichLogger.error(f"Path does not exist: [bold red]{path_str}[/bold red]")
                return False

            # Prepare a double null-terminated string as required by the Windows API
            double_null_terminated = path_str + '\0\0'

            # Initialize the file operation structure
            fileop = SHFILEOPSTRUCTW()
            fileop.hwnd = 0
            fileop.wFunc = FO_DELETE
            fileop.pFrom = ctypes.c_wchar_p(double_null_terminated)
            fileop.pTo = None
            fileop.fFlags = FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_SILENT
            fileop.fAnyOperationsAborted = False
            fileop.hNameMappings = 0
            fileop.lpszProgressTitle = None

            # Invoke the Windows Shell function
            shell32 = ctypes.windll.shell32
            result = shell32.SHFileOperationW(ctypes.byref(fileop))

            if result == 0 and not fileop.fAnyOperationsAborted:
                RichLogger.info(f"Moved to recycle bin: [bold green]{path_str}[/bold green]")
                return True
            else:
                RichLogger.error(f"Failed to move to recycle bin (error code: {result}): [bold red]{path_str}[/bold red]")
                return False

        except Exception as e:
            RichLogger.exception(f"Failed to move to recycle bin: [bold red]{path}[/bold red]")
            return False

    @staticmethod
    def delete_file(file_path, permanent=True):
        """
        Deletes a file, either permanently or by moving it to the recycle bin.

        Args:
            file_path: Path object or string of the file to delete.
            permanent: If True, deletes permanently; if False, moves to recycle bin. Defaults to True.

        Returns:
            bool: True if successful, False otherwise.

        Raises:
            Exception: If the file operation fails.
        """
        try:
            if not os.path.exists(file_path):
                return True

            # Attempt to remove read-only attribute to allow deletion
            try:
                os.chmod(file_path, stat.S_IWRITE)
            except Exception as e:
                RichLogger.exception(f"Failed to change file permissions: {file_path}")

            if permanent:
                os.remove(file_path)
                RichLogger.info(f"Permanently deleted file: [bold yellow]{file_path}[/bold yellow]")
            else:
                success = FileUtils._move_to_recycle_bin(file_path)
                if not success:
                    RichLogger.error(f"Failed to move file to recycle bin: [bold red]{file_path}[/bold red]")
                    return False

            return True
        except Exception as e:
            RichLogger.exception(f"Failed to process file [bold red]{file_path}[/bold red]")
            raise

    @staticmethod
    def delete_directory(directory, permanent=True):
        """
        Deletes a directory and all its contents, either permanently or by moving to the recycle bin.

        Args:
            directory: Path object of the directory to delete.
            permanent: If True, deletes permanently; if False, moves to recycle bin. Defaults to True.

        Returns:
            bool: True if successful, False otherwise.
        """
        try:
            if not directory.exists():
                return True

            # Helper function to make files/directories writable during deletion
            def make_writable(action, name, exc):
                try:
                    os.chmod(name, stat.S_IWRITE)
                    if action:
                        action(name)
                except Exception as e:
                    RichLogger.exception(f"Failed to make writable: {name}")
                    raise

            if permanent:
                shutil.rmtree(directory, onerror=make_writable)
                RichLogger.info(f"Permanently deleted directory: [bold yellow]{directory}[/bold yellow]")
            else:
                success = FileUtils._move_to_recycle_bin(directory)
                if not success:
                    RichLogger.error(f"Failed to move directory to recycle bin: [bold red]{directory}[/bold red]")
                    return False

            return True
        except Exception as e:
            RichLogger.exception(f"Critical error during directory processing: [bold red]{directory}[/bold red]")
            return False

    @staticmethod
    def make_writable(path):
        """
        Modifies permissions to ensure the path is writable by the current user.

        Args:
            path: Path object to modify.

        Returns:
            bool: True if permissions were changed successfully, False otherwise.
        """
        try:
            if not path.exists():
                return False
            try:
                os.chmod(path, stat.S_IWRITE)
                return True
            except Exception as e:
                RichLogger.exception(f"Failed to change permissions: {path}")
                return False
        except Exception as e:
            RichLogger.exception(f"Failed to make path writable: [bold red]{path}[/bold red]")
            return False

    @staticmethod
    def safe_delete(file, permanent=True):
        """
        Safely deletes a file with comprehensive permission checks and error handling.

        Args:
            file: Path object of the file to delete.
            permanent: If True, deletes permanently; if False, moves to recycle bin. Defaults to True.

        Returns:
            bool: True if the file was deleted or did not exist, False on critical errors.
        """
        try:
            if not file.exists():
                return True
            try:
                if not FileUtils._is_writable(file):
                    FileUtils.make_writable(file)

                if permanent:
                    file.unlink()
                    RichLogger.info(f"Permanently deleted file: [bold yellow]{file}[/bold yellow]")
                else:
                    success = FileUtils._move_to_recycle_bin(file)
                    if not success:
                        RichLogger.error(f"Failed to move file to recycle bin: {file}")
                        return False

                return True
            except Exception as e:
                RichLogger.exception(f"Failed during permission check: {file}")
                return False
        except PermissionError as pe:
            RichLogger.exception(f"Permission denied when processing file [bold red]{file}[/bold red]")
            return False
        except Exception as e:
            RichLogger.exception(f"File processing failed: [bold red]{file}[/bold red]")
            return False

    @staticmethod
    def _is_writable(path):
        """
        Checks if the current user has write permission for the specified path.

        Args:
            path: Path object to check.

        Returns:
            bool: True if the user can write to the path, False otherwise.
        """
        try:
            return os.access(path, os.W_OK)
        except Exception as e:
            RichLogger.exception(f"Failed to check write permissions: {path}")
            return False

    @staticmethod
    def extract_file_extension(filename_or_url: str) -> str:
        """
        Extracts the file extension from a filename or URL.

        Args:
            filename_or_url: The input string containing a filename or URL.

        Returns:
            str: The extracted file extension, or an empty string if not found.
        """
        basename = FileUtils._extract_basename(filename_or_url)

        pattern = r'\.([a-z][a-z0-9]{1,4}(?:\.[a-z][a-z0-9]{1,4}){0,1})$'
        match = re.search(pattern, basename, re.IGNORECASE)

        if match:
            return match.group(1)

        return ""

    @staticmethod
    def _extract_basename(path_or_url: str) -> str:
        """
        Extracts the base filename from a path or URL, removing parameters and fragments.

        Args:
            path_or_url: The input path or URL string.

        Returns:
            str: The extracted base filename.
        """
        without_params = path_or_url.split('?')[0].split('#')[0]
        return Path(without_params).name

    @staticmethod
    def calc_hash(file_path: Path, algorithm: str = "sha256") -> Optional[str]:
        """
        Calculates the hash digest of a file using the specified algorithm.

        Args:
            file_path: Path to the file.
            algorithm: Hash algorithm to use (default: "sha256").

        Returns:
            Optional[str]: The hexadecimal hash string, or None if an error occurs.
        """
        try:
            hash_func = getattr(hashlib, algorithm)()
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_func.update(chunk)
            return hash_func.hexdigest()
        except (IOError, AttributeError, ValueError):
            return None
