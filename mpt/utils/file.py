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
import ctypes
from ctypes import wintypes

from pathlib import Path
from typing import Optional

from mpt.core.log import RichLogger

# Define Windows API constants
FO_DELETE = 0x0003
FOF_ALLOWUNDO = 0x0040
FOF_NOCONFIRMATION = 0x0010
FOF_NOERRORUI = 0x0400
FOF_SILENT = 0x0004

class SHFILEOPSTRUCTW(ctypes.Structure):
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
    Comprehensive file system operations utility with robust error handling and cross-platform compatibility.

    Provides advanced file and directory management capabilities including safe deletion to recycle bin,
    permission management, and retry mechanisms. Designed to handle challenging file system
    scenarios with comprehensive logging and error recovery.
    """

    @staticmethod
    def _move_to_recycle_bin(path):
        """
        Move a file or directory to Windows Recycle Bin using ctypes and Windows API.

        This method utilizes the Windows Shell API through ctypes to move items to the recycle bin
        instead of permanent deletion, providing a safety net against accidental data loss.

        Args:
            path: Path object or string representing the file/directory to be moved to recycle bin

        Returns:
            bool: True if operation was successful, False otherwise
        """
        try:
            # Convert Path object to absolute path string
            path_str = os.path.abspath(str(path))

            # Check if path exists
            if not os.path.exists(path_str):
                RichLogger.error(f"Path does not exist: [bold red]{path_str}[/bold red]")
                return False

            # Ensure the path is double null-terminated (Windows API requirement)
            # Note: We need a string terminated by two null characters, so we add two null characters after the path string
            double_null_terminated = path_str + '\0\0'

            # Set up the file operation structure
            fileop = SHFILEOPSTRUCTW()
            fileop.hwnd = 0
            fileop.wFunc = FO_DELETE
            fileop.pFrom = ctypes.c_wchar_p(double_null_terminated)
            fileop.pTo = None
            fileop.fFlags = FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_SILENT
            fileop.fAnyOperationsAborted = False
            fileop.hNameMappings = 0
            fileop.lpszProgressTitle = None

            # Call SHFileOperationW
            shell32 = ctypes.windll.shell32
            result = shell32.SHFileOperationW(ctypes.byref(fileop))

            # Check result
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
        Delete a file either permanently or by moving it to the recycle bin.

        Provides a straightforward file deletion method with options for permanent deletion
        or moving to recycle bin. Handles permission issues and provides verification of 
        successful operation.

        Args:
            file_path: Path object or string representing the file to be deleted
            permanent: Boolean flag indicating whether to permanently delete (True) or 
                      move to recycle bin (False). Defaults to True.

        Returns:
            bool: True if file was successfully deleted, False otherwise

        Raises:
            Exception: If file operation fails
        """
        try:
            if not os.path.exists(file_path):
                return True

            # Remove read-only attribute on Windows to allow deletion
            try:
                os.chmod(file_path, stat.S_IWRITE)
            except Exception as e:
                RichLogger.exception(f"Failed to change file permissions: {file_path}")

            if permanent:
                # Permanently delete the file
                os.remove(file_path)
                RichLogger.info(f"Permanently deleted file: [bold yellow]{file_path}[/bold yellow]")
            else:
                # Move file to recycle bin
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
        Delete a directory and all contents either permanently or by moving to the recycle bin.

        Provides a straightforward directory deletion method with options for permanent deletion
        or moving to recycle bin. Handles permission issues for contained files and directories.

        Args:
            directory: Path object representing the directory to delete
            permanent: Boolean flag indicating whether to permanently delete (True) or 
                      move to recycle bin (False). Defaults to True.

        Returns:
            bool: True if directory was successfully deleted, False otherwise
        """
        try:
            if not directory.exists():
                return True

            # Ensure directory and contents are writable to allow deletion
            def make_writable(action, name, exc):
                try:
                    os.chmod(name, stat.S_IWRITE)
                    if action:
                        action(name)
                except Exception as e:
                    RichLogger.exception(f"Failed to make writable: {name}")
                    raise

            if permanent:
                # Permanently delete the directory
                shutil.rmtree(directory, onerror=make_writable)
                RichLogger.info(f"Permanently deleted directory: [bold yellow]{directory}[/bold yellow]")
            else:
                # Move directory to recycle bin
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
        Modify file system permissions to ensure a path is writable by the current user.

        Changes permissions on files and directories to remove read-only attributes,
        enabling subsequent modification or deletion operations. Handles both files
        and directories with appropriate permission changes.

        Args:
            path: Path object to modify permissions for

        Returns:
            bool: True if permissions were successfully changed, False otherwise
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
        Safely delete a file with comprehensive permission checking and error handling.

        Provides a safe file deletion method with options for permanent deletion
        or moving to recycle bin. Includes existence verification and permission assessment.

        Args:
            file: Path object representing the file to delete
            permanent: Boolean flag indicating whether to permanently delete (True) or 
                      move to recycle bin (False). Defaults to True.

        Returns:
            bool: True if file was successfully deleted or didn't exist, False on critical errors
        """
        try:
            if not file.exists():
                return True
            try:
                if not FileUtils._is_writable(file):
                    FileUtils.make_writable(file)

                if permanent:
                    # Permanently delete the file
                    file.unlink()
                    RichLogger.info(f"Permanently deleted file: [bold yellow]{file}[/bold yellow]")
                else:
                    # Move to recycle bin
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
        Determine if the current user has write permissions for a specified path.

        Checks file system permissions to verify write access capabilities for
        the current user context. Useful for pre-operation validation and
        permission error prevention.

        Args:
            path: Path object to check for write permissions

        Returns:
            bool: True if the current user can write to the path, False otherwise
        """
        try:
            if os.access(path, os.W_OK):
                return True
            return False
        except Exception as e:
            RichLogger.exception(f"Failed to check write permissions: {path}")
            return False
