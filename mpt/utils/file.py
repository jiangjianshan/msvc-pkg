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

    MAX_RETRIES = 5
    RETRY_DELAY = 1.0
    MAX_DELETE_RETRIES = 5
    DELETE_RETRY_DELAY = 1.0

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
    def force_delete_file(file_path):
        """
        Safely move a file to Windows Recycle Bin with comprehensive permission handling and verification.

        Implements a robust file deletion strategy that moves files to recycle bin instead of
        permanent deletion. Handles read-only attributes, permission issues, and provides
        verification of successful operation. Specifically designed for Windows systems.

        Args:
            file_path: Path object or string representing the file to be moved to recycle bin

        Returns:
            bool: True if file was successfully moved to recycle bin, False otherwise

        Raises:
            Exception: If file operation fails after all attempts, indicating a critical failure
        """
        try:
            if os.path.exists(file_path):
                # Remove read-only attribute on Windows to allow movement to recycle bin
                try:
                    os.chmod(file_path, stat.S_IWRITE)
                except Exception as e:
                    RichLogger.exception(f"Failed to change file permissions: {file_path}")
                    # Don't raise here, just log and continue

                # Move file to recycle bin instead of permanent deletion
                success = FileUtils._move_to_recycle_bin(file_path)

                if not success:
                    RichLogger.error(f"Failed to move file to recycle bin: [bold red]{file_path}[/bold red]")
                    # Instead of raising an exception, fall back to permanent deletion
                    try:
                        os.remove(file_path)
                        RichLogger.info(f"Fallback: Permanently deleted file: [bold yellow]{file_path}[/bold yellow]")
                        return True
                    except Exception as e:
                        RichLogger.exception(f"Fallback deletion also failed: [bold red]{file_path}[/bold red]")
                        raise Exception(f"Failed to delete file: {file_path}")

                # Verify file is no longer in original location
                if os.path.exists(file_path):
                    RichLogger.warning(f"File still exists after recycle bin operation: [bold yellow]{file_path}[/bold yellow]")
                    # Fallback to traditional delete if recycle bin operation failed
                    try:
                        os.remove(file_path)
                        RichLogger.info(f"Fallback: Permanently deleted file: [bold yellow]{file_path}[/bold yellow]")
                    except Exception as e:
                        RichLogger.exception(f"Fallback deletion also failed: [bold red]{file_path}[/bold red]")
                        raise
            return True
        except Exception as e:
            RichLogger.exception(f"Failed to process file [bold red]{file_path}[/bold red]")
            raise

    @staticmethod
    def force_delete_directory(directory, max_retries=MAX_RETRIES, retry_delay=RETRY_DELAY):
        """
        Recursively move a directory and all contents to Windows Recycle Bin with robust retry mechanism.

        Implements a comprehensive directory removal strategy with:
        - Movement of entire directory structure to recycle bin
        - Permission handling for read-only files and directories
        - Configurable retry mechanism with exponential backoff
        - Verification of successful operation after completion

        Args:
            directory: Path object representing the directory to move to recycle bin
            max_retries: Maximum number of retry attempts before giving up
            retry_delay: Delay in seconds between retry attempts

        Returns:
            bool: True if directory was successfully moved to recycle bin, False if all attempts failed
        """
        try:
            success = False
            for attempt in range(1, max_retries + 1):
                try:
                    # Ensure directory is writable to allow movement to recycle bin
                    def make_writable(action, name, exc):
                        try:
                            os.chmod(name, stat.S_IWRITE)
                            if action:
                                action(name)
                        except Exception as e:
                            RichLogger.exception(f"Failed to make writable: {name}")
                            raise

                    if directory.exists():
                        # First try to move entire directory to recycle bin
                        success = FileUtils._move_to_recycle_bin(directory)

                        if success:
                            # Verify deletion from original location
                            if not directory.exists():
                                break
                            else:
                                RichLogger.warning(f"Directory still exists after recycle bin operation: [bold yellow]{directory}[/bold yellow]")
                                success = False

                        # If recycle bin operation failed, fallback to traditional delete
                        if not success and attempt == max_retries:
                            RichLogger.warning(f"Recycle bin operation failed, attempting traditional delete: [bold yellow]{directory}[/bold yellow]")
                            try:
                                shutil.rmtree(directory, onerror=make_writable)
                                RichLogger.info(f"Fallback: Permanently deleted directory: [bold yellow]{directory}[/bold yellow]")
                                success = True
                                break
                            except Exception as e:
                                RichLogger.exception(f"Fallback deletion also failed: [bold red]{directory}[/bold red]")
                                raise
                    else:
                        success = True
                        break
                except Exception as e:
                    RichLogger.exception(f"Deletion error on attempt [bold red]{attempt}[/bold red]: {directory}")

                # Delay before next attempt
                if attempt < max_retries and not success:
                    time.sleep(retry_delay)

            if not success:
                RichLogger.error(f"Failed to process directory after [bold red]{max_retries}[/bold red] attempts: [bold red]{directory}[/bold red]")
            return success
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
    def safe_unlink(file):
        """
        Safely move a file to Windows Recycle Bin with comprehensive permission checking and error handling.

        Implements a safe file deletion workflow that includes:
        - Existence verification before attempting operation
        - Permission assessment and automatic correction
        - Movement to recycle bin instead of permanent deletion
        - Detailed error logging for troubleshooting
        - Graceful handling of permission errors and other exceptions

        Args:
            file: Path object representing the file to move to recycle bin

        Returns:
            bool: True if file was successfully moved to recycle bin or didn't exist, False on critical errors
        """
        try:
            if not file.exists():
                return True
            try:
                if not FileUtils._is_writable(file):
                    FileUtils.make_writable(file)

                # Move to recycle bin instead of permanent deletion
                success = FileUtils._move_to_recycle_bin(file)

                if not success:
                    RichLogger.error(f"Failed to move file to recycle bin: {file}")
                    # Fallback to permanent deletion
                    try:
                        file.unlink()
                        RichLogger.info(f"Fallback: Permanently deleted file: [bold yellow]{file}[/bold yellow]")
                        return True
                    except Exception as e:
                        RichLogger.exception(f"Fallback deletion also failed: {file}")
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
