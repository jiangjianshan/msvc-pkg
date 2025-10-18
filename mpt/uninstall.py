# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#

from pathlib import Path
from typing import Set

from mpt import ROOT_DIR
from mpt.config import UserConfig
from mpt.file import FileUtils
from mpt.history import HistoryManager
from mpt.log import RichLogger


class UninstallManager:
    """
    Static class for uninstalling libraries by parsing installed file lists
    and removing files based on the recorded installation manifest.
    """

    @staticmethod
    def uninstall_library(arch: str, lib: str) -> int:
        """
        Uninstall a library by parsing its installed file list and removing all recorded files.

        Args:
            arch: Target architecture
            lib: Name of the library to uninstall

        Returns:
            int: Number of files successfully removed, or -1 if uninstallation failed
        """
        # Remove the library record from history
        HistoryManager.remove_record(arch, lib)

        # Construct installed file list path
        list_file = ROOT_DIR / 'installed' / 'msvc-pkg' / 'info' / f"{lib}_{arch}.list"

        if not list_file.exists():
            RichLogger.debug(f"Installed file list not found: {list_file}")
            return 0  # No files to remove, but not considered a failure

        # Read the installed file list content
        try:
            list_content = list_file.read_text(encoding='utf-8', errors='ignore')
        except Exception as e:
            RichLogger.debug(f"Error reading installed file list {list_file}: {e}")
            return -1  # Considered a failure

        # Parse the file list to get installed files
        prefix = UserConfig.get_prefix(arch, lib)
        installed_files = UninstallManager._get_installed(list_content, prefix)

        if not installed_files:
            RichLogger.debug(f"No installed files found in the list for {lib}")
            return 0  # No files to remove, but not considered a failure

        # Delete files recorded in the installed file list
        RichLogger.debug(f"Uninstalling {lib}...")
        removed_count = UninstallManager._remove_files(installed_files)

        # Remove empty directories under the prefix
        empty_dirs_removed = UninstallManager._remove_empty_directories(prefix, installed_files)

        RichLogger.debug(f"Successfully removed {removed_count} files")
        return removed_count

    @staticmethod
    def _get_installed(list_content: str, prefix: Path) -> Set[Path]:
        """
        Parse the installed file list content and convert relative paths to absolute paths.

        Args:
            list_content: Content of the installed file list
            prefix: Installation prefix path for resolving relative paths

        Returns:
            Set of absolute Path objects representing installed files
        """
        files = set()

        # Split content by lines and process each line
        lines = list_content.strip().split('\n')
        RichLogger.debug(f"Found {len(lines)} entries in installed file list")

        for line in lines:
            line = line.strip()
            if not line:
                continue  # Skip empty lines

            # Convert relative path to absolute path using the prefix
            relative_path = Path(line)
            absolute_path = prefix / relative_path

            # Normalize the path to resolve any '..' components safely
            try:
                normalized_path = absolute_path.resolve()
                files.add(normalized_path)
                RichLogger.debug(f"Installed file: {normalized_path}")
            except Exception as e:
                RichLogger.debug(f"Error normalizing path {absolute_path}: {e}")
                # Add the non-normalized path as fallback
                files.add(absolute_path)
                RichLogger.debug(f"Installed file (fallback): {absolute_path}")

        return files

    @staticmethod
    def _remove_files(installed_files: Set[Path]) -> int:
        """
        Remove all files and directories in the installed files set.

        Args:
            installed_files: Set of paths to remove

        Returns:
            Number of successfully removed files/directories
        """
        removed_count = 0

        for file_path in installed_files:
            try:
                if file_path.is_dir():
                    FileUtils.delete_directory(file_path)
                else:
                    FileUtils.delete_file(file_path)
                removed_count += 1
            except Exception as e:
                RichLogger.debug(f"Failed to remove {file_path}: {e}")
                # Continue with other files instead of returning immediately
                # We'll count only successfully removed files

        return removed_count

    @staticmethod
    def _remove_empty_directories(prefix: Path, installed_files: Set[Path]) -> int:
        """
        Remove empty directories under the prefix that were part of the installation.

        Args:
            prefix: The installation prefix directory
            installed_files: Set of installed files that were removed

        Returns:
            Number of empty directories successfully removed
        """
        empty_dirs_removed = 0

        # Collect all directories that contained the installed files
        directories_to_check = set()

        for file_path in installed_files:
            # Get all parent directories of the file
            parent = file_path.parent
            while parent != prefix and parent != prefix.parent and prefix in parent.parents:
                directories_to_check.add(parent)
                parent = parent.parent

        # Sort directories by depth (deepest first) to remove from bottom up
        sorted_directories = sorted(directories_to_check, key=lambda p: len(p.parts), reverse=True)

        for directory in sorted_directories:
            try:
                # Check if directory is empty and exists
                if directory.exists() and directory.is_dir():
                    # Check if directory is empty
                    if not any(directory.iterdir()):
                        FileUtils.delete_directory(directory)
                        empty_dirs_removed += 1
                        RichLogger.debug(f"Removed empty directory: {directory}")
            except Exception as e:
                RichLogger.debug(f"Failed to check/remove directory {directory}: {e}")
                # Continue with other directories

        return empty_dirs_removed
