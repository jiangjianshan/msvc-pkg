# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
import ctypes
import threading
import time

from ctypes import wintypes
from pathlib import Path
from typing import Set, List, Optional

from mpt.log import RichLogger


class Win32FileMonitor:
    """
    Windows file system monitor using Windows API via ctypes.
    """

    # Constants
    FILE_LIST_DIRECTORY = 0x0001
    OPEN_EXISTING = 3
    FILE_FLAG_BACKUP_SEMANTICS = 0x02000000

    # Symbolic link related flags
    FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000

    # Monitor flags - track all file operations
    FILE_NOTIFY_CHANGE_FILE_NAME = 0x00000001
    FILE_NOTIFY_CHANGE_DIR_NAME = 0x00000002
    FILE_NOTIFY_CHANGE_ATTRIBUTES = 0x00000004
    FILE_NOTIFY_CHANGE_SIZE = 0x00000008
    FILE_NOTIFY_CHANGE_LAST_WRITE = 0x00000010
    FILE_NOTIFY_CHANGE_SECURITY = 0x00000100

    # File action codes
    FILE_ACTION_ADDED = 1
    FILE_ACTION_REMOVED = 2
    FILE_ACTION_MODIFIED = 3
    FILE_ACTION_RENAMED_OLD_NAME = 4
    FILE_ACTION_RENAMED_NEW_NAME = 5

    def __init__(self, target_dir: str):
        """Initialize file monitor for specified directory."""
        self.target_dir = Path(target_dir).resolve()
        self.detected_files: Set[Path] = set()
        self.detected_symlinks: Set[Path] = set()
        self._monitoring = False
        self._thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()

        # Load kernel32 library
        self.kernel32 = ctypes.WinDLL('kernel32', use_last_error=True)
        self._setup_api_functions()

    def _setup_api_functions(self):
        """Setup Windows API function prototypes."""
        # CreateFileW function prototype
        self.kernel32.CreateFileW.argtypes = [
            wintypes.LPWSTR, wintypes.DWORD, wintypes.DWORD,
            wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE
        ]
        self.kernel32.CreateFileW.restype = wintypes.HANDLE

        # ReadDirectoryChangesW function prototype
        self.kernel32.ReadDirectoryChangesW.argtypes = [
            wintypes.HANDLE, wintypes.LPVOID, wintypes.DWORD, wintypes.BOOL,
            wintypes.DWORD, wintypes.LPDWORD, wintypes.LPVOID, wintypes.LPVOID
        ]
        self.kernel32.ReadDirectoryChangesW.restype = wintypes.BOOL

        # CloseHandle function prototype
        self.kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
        self.kernel32.CloseHandle.restype = wintypes.BOOL

    def start_monitoring(self):
        """Start file system monitoring."""
        if self._monitoring:
            return

        self._monitoring = True
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self._thread.start()

    def stop_monitoring(self):
        """Stop file system monitoring."""
        if not self._monitoring:
            return

        self._stop_event.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=3.0)
        self._monitoring = False

    def _monitor_loop(self):
        """Main monitoring loop using Windows API."""
        dir_handle = None

        try:
            # Ensure target directory exists
            self.target_dir.mkdir(parents=True, exist_ok=True)

            # Open directory handle with symbolic link support
            dir_handle = self.kernel32.CreateFileW(
                str(self.target_dir),
                self.FILE_LIST_DIRECTORY,
                0x7,  # FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE
                None,
                self.OPEN_EXISTING,
                self.FILE_FLAG_BACKUP_SEMANTICS | self.FILE_FLAG_OPEN_REPARSE_POINT,
                None
            )

            if dir_handle == -1:
                error = ctypes.WinError(ctypes.get_last_error())
                RichLogger.error(f"Failed to open directory: {error}")
                return

            # Use larger buffer for notifications
            buffer_size = 64 * 1024  # 64KB buffer
            buffer = (ctypes.c_byte * buffer_size)()
            bytes_returned = wintypes.DWORD()

            while not self._stop_event.is_set():
                # Clear buffer
                ctypes.memset(buffer, 0, buffer_size)
                bytes_returned.value = 0

                # Wait for directory changes
                success = self.kernel32.ReadDirectoryChangesW(
                    dir_handle,
                    buffer,
                    buffer_size,
                    True,  # Monitor subdirectories
                    (self.FILE_NOTIFY_CHANGE_FILE_NAME |
                     self.FILE_NOTIFY_CHANGE_DIR_NAME |
                     self.FILE_NOTIFY_CHANGE_ATTRIBUTES |
                     self.FILE_NOTIFY_CHANGE_SIZE |
                     self.FILE_NOTIFY_CHANGE_LAST_WRITE |
                     self.FILE_NOTIFY_CHANGE_SECURITY),
                    ctypes.byref(bytes_returned),
                    None,
                    None
                )

                if not success:
                    error = ctypes.WinError(ctypes.get_last_error())
                    RichLogger.error(f"ReadDirectoryChangesW failed: {error}")
                    time.sleep(0.1)
                    continue

                if bytes_returned.value > 0:
                    self._process_buffer(buffer, bytes_returned.value)
                else:
                    # Short delay when no changes detected
                    time.sleep(0.05)

        except Exception as e:
            RichLogger.error(f"Monitoring error: {e}")
        finally:
            if dir_handle and dir_handle != -1:
                self.kernel32.CloseHandle(dir_handle)

    def _process_buffer(self, buffer, buffer_size):
        """Process notification buffer - track all file operations, no filtering for directories."""
        offset = 0

        while offset < buffer_size:
            # Read structure fields
            next_entry_offset = ctypes.c_uint32.from_buffer(buffer, offset).value
            action = ctypes.c_uint32.from_buffer(buffer, offset + 4).value
            filename_length = ctypes.c_uint32.from_buffer(buffer, offset + 8).value

            if filename_length > 0 and (offset + 12 + filename_length) <= buffer_size:
                # Extract filename bytes
                filename_bytes = bytes(buffer[offset+12:offset+12+filename_length])

                try:
                    filename = filename_bytes.decode('utf-16le').rstrip('\x00')
                    full_path = self.target_dir / filename

                    # Track all file operations, including symbolic links
                    if action in [self.FILE_ACTION_ADDED,
                                self.FILE_ACTION_RENAMED_NEW_NAME,
                                self.FILE_ACTION_MODIFIED]:
                        try:
                            # Track all paths, including directories and symbolic links
                            if full_path.exists():
                                self.detected_files.add(full_path)

                                # Special handling for symbolic links
                                if self._is_symlink(full_path):
                                    self.detected_symlinks.add(full_path)

                        except OSError as e:
                            # Enhanced error handling for symbolic links
                            if "symbolic link" in str(e).lower() or "reparse point" in str(e).lower():
                                RichLogger.warning(f"Symbolic link access issue for {filename}: {e}")
                                # Still track the path even if access is restricted
                                self.detected_files.add(full_path)
                                self.detected_symlinks.add(full_path)
                            else:
                                RichLogger.error(f"Error accessing path {filename}: {e}")

                except UnicodeDecodeError:
                    # Skip filename decoding errors
                    pass

            # Move to next entry
            if next_entry_offset == 0:
                break
            offset += next_entry_offset

    def _is_symlink(self, path: Path) -> bool:
        """Check if the given path is a symbolic link."""
        try:
            return path.is_symlink()
        except (OSError, PermissionError):
            # Fallback method for cases where is_symlink() fails
            try:
                if path.exists():
                    # Check file attributes for reparse point flag
                    attributes = ctypes.windll.kernel32.GetFileAttributesW(str(path))
                    return attributes != -1 and (attributes & 0x400) != 0  # FILE_ATTRIBUTE_REPARSE_POINT
            except:
                pass
        return False

    def scan_existing_symlinks(self) -> List[str]:
        """Scan and return all existing symbolic links in the target directory."""
        symlinks_found = []

        try:
            RichLogger.info(f"Scanning for existing symbolic links in: {self.target_dir}")

            for item in self.target_dir.iterdir():
                try:
                    if self._is_symlink(item):
                        symlinks_found.append(item.name)
                        self.detected_symlinks.add(item)
                        RichLogger.info(f"Found existing symbolic link: {item.name}")
                except (OSError, PermissionError) as e:
                    RichLogger.warning(f"Cannot check symbolic link {item}: {e}")

        except Exception as e:
            RichLogger.error(f"Error scanning for symbolic links: {e}")

        return sorted(symlinks_found)

    def get_detected_symlinks(self) -> List[str]:
        """Get list of detected symbolic links during monitoring."""
        valid_symlinks = []

        for symlink_path in self.detected_symlinks:
            try:
                if symlink_path.exists() and self._is_symlink(symlink_path):
                    rel_path = symlink_path.relative_to(self.target_dir)
                    valid_symlinks.append(str(rel_path).replace('\\', '/'))
            except Exception as e:
                RichLogger.error(f"Skipping invalid symbolic link {symlink_path}: {e}")

        return sorted(valid_symlinks)

    def get_new_files(self) -> List[str]:
        """Get list of new files detected during monitoring (including symbolic links)."""
        valid_files = []

        for file_path in self.detected_files:
            try:
                # Include all paths, no directory filtering
                if file_path.exists():
                    rel_path = file_path.relative_to(self.target_dir)
                    valid_files.append(str(rel_path).replace('\\', '/'))
            except Exception as e:
                RichLogger.error(f"Skipping invalid file {file_path}: {e}")

        return sorted(valid_files)

    def refresh_detection(self) -> dict:
        """Refresh detection and return all detected items including symbolic links."""
        # Scan for existing symbolic links
        self.scan_existing_symlinks()

        return {
            'all_files': self.get_new_files(),
            'symlinks': self.get_detected_symlinks(),
            'regular_files': [f for f in self.get_new_files()
                            if f not in self.get_detected_symlinks()]
        }


# FILE_NOTIFY_INFORMATION structure for reference
class FILE_NOTIFY_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("NextEntryOffset", wintypes.DWORD),
        ("Action", wintypes.DWORD),
        ("FileNameLength", wintypes.DWORD),
        ("FileName", wintypes.WCHAR * 1)
    ]
