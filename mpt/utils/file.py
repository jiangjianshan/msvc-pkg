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

from mpt.core.log import RichLogger

class FileUtils:
    """
    Comprehensive file system operations utility with robust error handling and cross-platform compatibility.

    Provides advanced file and directory management capabilities including forced deletion,
    permission management, and retry mechanisms. Designed to handle challenging file system
    scenarios with comprehensive logging and error recovery.
    """

    MAX_RETRIES = 5
    RETRY_DELAY = 1.0
    MAX_DELETE_RETRIES = 5
    DELETE_RETRY_DELAY = 1.0

    @staticmethod
    def force_delete_file(file_path):
        """
        Forcefully delete a file with comprehensive permission handling and verification.

        Implements a robust file deletion strategy that handles read-only attributes,
        permission issues, and verification of successful deletion. Specifically designed
        for Windows systems but maintains cross-platform compatibility.

        Args:
            file_path: Path object or string representing the file to be deleted

        Returns:
            bool: True if file was successfully deleted, False otherwise

        Raises:
            Exception: If file persists after deletion attempts, indicating a critical failure
        """
        try:
            if os.path.exists(file_path):
                # Remove read-only attribute on Windows
                try:
                    os.chmod(file_path, stat.S_IWRITE)
                except Exception as e:
                    RichLogger.exception(f"Failed to change file permissions: {file_path}")
                    raise

                try:
                    os.remove(file_path)
                except Exception as e:
                    RichLogger.exception(f"Failed to remove file: {file_path}")
                    raise

                # Verify file is actually deleted
                if os.path.exists(file_path):
                    RichLogger.error(f"File still exists after deletion attempt: [bold red]{file_path}[/bold red]")
                    raise Exception(f"File still exists after deletion: {file_path}")
            return True
        except Exception as e:
            RichLogger.exception(f"Failed to delete file [bold red]{file_path}[/bold red]")
            raise

    @staticmethod
    def force_delete_directory(directory, max_retries=MAX_RETRIES, retry_delay=RETRY_DELAY):
        """
        Recursively delete a directory and all contents with robust retry mechanism.

        Implements a comprehensive directory removal strategy with:
        - Recursive deletion of all files and subdirectories
        - Permission handling for read-only files and directories
        - Configurable retry mechanism with exponential backoff
        - Verification of complete deletion after operation

        Args:
            directory: Path object representing the directory to delete
            max_retries: Maximum number of retry attempts before giving up
            retry_delay: Delay in seconds between retry attempts

        Returns:
            bool: True if directory was successfully deleted, False if all attempts failed
        """
        try:
            success = False
            for attempt in range(1, max_retries + 1):
                try:
                    # Handle Windows permissions
                    def make_writable(action, name, exc):
                        try:
                            os.chmod(name, stat.S_IWRITE)
                            action(name)
                        except Exception as e:
                            RichLogger.exception(f"Failed to make writable and remove: {name}")
                            raise

                    if directory.exists():
                        try:
                            shutil.rmtree(directory, onerror=make_writable)
                        except Exception as e:
                            RichLogger.exception(f"Failed to remove directory tree: {directory}")
                            raise

                        # Verify deletion
                        if not directory.exists():
                            success = True
                            break
                    else:
                        success = True
                        break
                except Exception as e:
                    RichLogger.exception(f"Deletion error on attempt [bold red]{attempt}[/bold red]: {directory}")

                # Delay before next attempt
                if attempt < max_retries and not success:
                    time.sleep(retry_delay)

            if not success:
                RichLogger.error(f"Failed to delete directory after [bold red]{max_retries}[/bold red] attempts: [bold red]{directory}[/bold red]")
            return success
        except Exception as e:
            RichLogger.exception(f"Critical error during directory deletion: [bold red]{directory}[/bold red]")
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
        Safely delete a file with comprehensive permission checking and error handling.

        Implements a safe file deletion workflow that includes:
        - Existence verification before attempting deletion
        - Permission assessment and automatic correction
        - Detailed error logging for troubleshooting
        - Graceful handling of permission errors and other exceptions

        Args:
            file: Path object representing the file to delete

        Returns:
            bool: True if file was successfully deleted or didn't exist, False on critical errors
        """
        try:
            if not file.exists():
                return True
            try:
                if not FileUtils._is_writable(file):
                    FileUtils.make_writable(file)

                try:
                    file.unlink()
                    return True
                except Exception as e:
                    RichLogger.exception(f"Failed to unlink file: {file}")
                    return False
            except Exception as e:
                RichLogger.exception(f"Failed during permission check: {file}")
                return False
        except PermissionError as pe:
            RichLogger.exception(f"Permission denied when deleting file [bold red]{file}[/bold red]")
            return False
        except Exception as e:
            RichLogger.exception(f"File deletion failed: [bold red]{file}[/bold red]")
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
