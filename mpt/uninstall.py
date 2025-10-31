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
    Provides functionality to cleanly remove library installations.
    """

    @staticmethod
    def uninstall_library(triplet: str, lib: str) -> int:
        """
        Uninstall a library by parsing its installed file list and removing all recorded files.

        Args:
            triplet: Target triplet (e.g., x64-windows) specifying the build target
            lib: Name of the library to uninstall

        Returns:
            int: Number of files successfully removed, 0 if no files found, -1 if uninstallation failed
        """
        # Remove the library record from installation history
        HistoryManager.remove_record(triplet, lib)

        # Construct path to the installed file list for this library
        list_file = ROOT_DIR / 'installed' / 'info' / triplet / f"{lib}.list"

        # Check if the installed file list exists
        if not list_file.exists():
            RichLogger.debug(f"Installed file list not found: {list_file}")
            return 0  # No files to remove, but not considered a failure

        # Read the installed file list content
        try:
            list_content = list_file.read_text(encoding='utf-8', errors='ignore')
        except Exception as e:
            RichLogger.debug(f"Error reading installed file list {list_file}: {e}")
            return -1  # Considered a failure due to read error

        # Parse the file list to get installed files with absolute paths
        prefix = UserConfig.get_prefix(triplet, lib)
        installed_files = UninstallManager._get_installed(list_content, prefix)

        # Check if any installed files were found
        if not installed_files:
            RichLogger.debug(f"No installed files found in the list for {lib}")
            return 0  # No files to remove, but not considered a failure

        # Delete files recorded in the installed file list
        RichLogger.debug(f"Uninstalling {lib}...")
        removed_count = UninstallManager._remove_files(installed_files)

        # Remove empty directories under the prefix that were part of the installation
        empty_dirs_removed = UninstallManager._remove_empty_directories(prefix, installed_files)

        RichLogger.debug(f"Successfully removed {removed_count} files and {empty_dirs_removed} empty directories")
        return removed_count

    @staticmethod
    def _get_installed(list_content: str, prefix: Path) -> Set[Path]:
        """
        Parse the installed file list content and convert relative paths to absolute paths.

        Args:
            list_content: Content of the installed file list with relative paths
            prefix: Installation prefix directory to resolve absolute paths

        Returns:
            Set[Path]: Set of absolute paths to installed files and directories
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

            # Do not use resolve() to preserve symbolic link information
            # Using the original absolute path maintains the correct file type detection
            files.add(absolute_path)

            # Check path type before any resolution to correctly identify symbolic links
            if absolute_path.is_symlink():
                RichLogger.debug(f"Symbolic link found: {absolute_path} -> {absolute_path.resolve()}")
            elif FileUtils.is_junction_point(absolute_path):
                RichLogger.debug(f"Junction point found: {absolute_path}")
            elif absolute_path.exists():
                if absolute_path.is_file():
                    RichLogger.debug(f"Regular file: {absolute_path}")
                elif absolute_path.is_dir():
                    RichLogger.debug(f"Regular directory: {absolute_path}")
            else:
                RichLogger.debug(f"Path does not exist: {absolute_path}")

        return files

    @staticmethod
    def _remove_files(installed_files: Set[Path]) -> int:
        """
        Remove all files, directories, and symbolic links in the installed files set.
        Uses a specific order: symbolic links first, then files, then directories.

        Args:
            installed_files: Set of absolute paths to remove

        Returns:
            int: Number of successfully removed files/directories/links
        """
        removed_count = 0

        # Categorize paths by type for ordered removal
        symbolic_links = set()  # Symbolic links and junction points
        regular_files = set()   # Regular files
        regular_dirs = set()    # Regular directories

        # Classify each path by type
        for file_path in installed_files:
            if file_path.is_symlink() or FileUtils.is_junction_point(file_path):
                symbolic_links.add(file_path)
            elif file_path.is_file():
                regular_files.add(file_path)
            elif file_path.is_dir():
                regular_dirs.add(file_path)
            else:
                # Path doesn't exist or is a special file type
                RichLogger.debug(f"Path does not exist or is special: {file_path}")

        # Step 1: Remove symbolic links and junction points first
        for symlink_path in symbolic_links:
            try:
                if symlink_path.exists():
                    # Symbolic links and junction points are permanently deleted
                    if symlink_path.is_symlink():
                        symlink_path.unlink()
                        removed_count += 1
                        RichLogger.debug(f"Removed symbolic link: {symlink_path}")
                    elif FileUtils.is_junction_point(symlink_path):
                        # Use FileUtils for consistent deletion behavior
                        if FileUtils.delete_directory(symlink_path, permanent=True):
                            removed_count += 1
                            RichLogger.debug(f"Removed junction point: {symlink_path}")
            except Exception as e:
                RichLogger.debug(f"Error removing symbolic link/junction {symlink_path}: {e}")

        # Step 2: Remove regular files
        for file_path in regular_files:
            if file_path.exists() and file_path.is_file():
                if FileUtils.delete_file(file_path, permanent=True):
                    removed_count += 1

        # Step 3: Remove regular directories (only empty ones)
        for dir_path in regular_dirs:
            if dir_path.exists() and dir_path.is_dir():
                # Only delete empty directories to avoid data loss
                if not any(dir_path.iterdir()):
                    if FileUtils.delete_directory(dir_path, permanent=True):
                        removed_count += 1
                        RichLogger.debug(f"Removed empty directory: {dir_path}")
                else:
                    RichLogger.debug(f"Skipping non-empty directory: {dir_path}")

        return removed_count

    @staticmethod
    def _remove_empty_directories(prefix: Path, installed_files: Set[Path]) -> int:
        """
        Remove empty directories under the prefix that were part of the installation.
        Skips symbolic links and junction points. Processes directories from deepest to shallowest.

        Args:
            prefix: The installation prefix directory
            installed_files: Set of installed files that were removed

        Returns:
            int: Number of empty directories successfully removed
        """
        empty_dirs_removed = 0
        directories_to_check = set()

        # Collect all parent directories of regular files (excluding links)
        for file_path in installed_files:
            # Skip symbolic links and junction points for directory cleanup
            if file_path.is_symlink() or FileUtils.is_junction_point(file_path):
                continue

            # Traverse up the directory tree to collect all parent directories
            parent = file_path.parent
            while parent != prefix and parent != prefix.parent and prefix in parent.parents:
                # Only include regular directories, not links
                if (parent.exists() and
                    parent.is_dir() and
                    not (parent.is_symlink() or FileUtils.is_junction_point(parent))):
                    directories_to_check.add(parent)
                parent = parent.parent

        # Sort directories by depth (deepest first) for proper cleanup order
        sorted_directories = sorted(directories_to_check, key=lambda p: len(p.parts), reverse=True)

        # Remove empty directories starting from the deepest level
        for directory in sorted_directories:
            try:
                # Verify it's a regular directory (not a link) and exists
                if (directory.exists() and
                    directory.is_dir() and
                    not directory.is_symlink() and
                    not FileUtils.is_junction_point(directory)):

                    # Check if directory is empty before removal
                    if not any(directory.iterdir()):
                        if FileUtils.delete_directory(directory, permanent=True):
                            empty_dirs_removed += 1
                            RichLogger.debug(f"Removed empty directory: {directory}")
            except Exception as e:
                RichLogger.debug(f"Failed to check/remove directory {directory}: {e}")

        return empty_dirs_removed
