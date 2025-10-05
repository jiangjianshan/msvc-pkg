# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#

import re

from pathlib import Path
from typing import Set, List

from mpt import ROOT_DIR
from mpt.core.history import HistoryManager
from mpt.core.log import RichLogger
from mpt.utils.file import FileUtils
from mpt.utils.path import PathUtils


class UninstallManager:
    """
    Static class for uninstalling libraries by parsing build system log files
    and removing installed files based on build system specific patterns.
    """

    @staticmethod
    def uninstall_library(arch: str, lib: str) -> bool:
        """
        Uninstall a library by parsing its build log file to find installed files
        and then removing them.

        Args:
            arch: Target architecture
            lib: Name of the library to uninstall

        Returns:
            bool: True if uninstallation was successful, False otherwise
        """
        HistoryManager.remove_record(arch, lib)

        # Construct log file path
        log_file = ROOT_DIR / "logs" / f"{lib}.log"

        if not log_file.exists():
            RichLogger.debug(f"Log file not found: {log_file}")
            return False

        # Read log content
        try:
            log_content = log_file.read_text(encoding='utf-8', errors='ignore')
        except Exception as e:
            RichLogger.debug(f"Error reading log file {log_file}: {e}")
            return False

        # Determine build system type and extract installed files
        installed_files = set()
        if UninstallManager._is_meson_build(log_content):
            installed_files.update(UninstallManager._extract_meson_files(log_content))
        elif UninstallManager._is_cmake_build(log_content):
            installed_files.update(UninstallManager._extract_cmake_files(log_content))
        elif UninstallManager._is_autotools_build(log_content):
            installed_files.update(UninstallManager._extract_autotools_files(log_content))
        else:
            # Assume MSBuild/MSVC build
            installed_files.update(UninstallManager._extract_ms_files(log_content))

        if not installed_files:
            RichLogger.debug(f"No installed files found for {lib}")
            return True

        # Delete files
        RichLogger.debug(f"Uninstalling {lib}...")
        removed_count = 0
        for file_path in installed_files:
            try:
                if file_path.is_dir():
                    FileUtils.force_delete_directory(file_path)
                else:
                    FileUtils.force_delete_file(file_path)
                RichLogger.debug(f"Removed: {file_path}")
                removed_count += 1
            except Exception as e:
                RichLogger.debug(f"Failed to remove {file_path}: {e}")
                return False

        RichLogger.debug(f"Successfully removed {removed_count} files")
        return True

    @staticmethod
    def _is_meson_build(log_content: str) -> bool:
        """Check if build was done with Meson build system"""
        return "The Meson build system" in log_content

    @staticmethod
    def _is_cmake_build(log_content: str) -> bool:
        """Check if build was done with CMake build system"""
        return ("The CXX compiler identification" in log_content or
                "The C compiler identification" in log_content)

    @staticmethod
    def _is_autotools_build(log_content: str) -> bool:
        """Check if build was done with Autotools build system"""
        return "checking for a BSD-compatible install" in log_content

    @staticmethod
    def _extract_meson_files(log_content: str) -> Set[str]:
        """Extract installed files from Meson build logs"""
        files = set()
        # Pattern for Meson installation lines
        pattern = r"Installing\s+(.*?)\s+to\s+(.*?)\s*$"

        for line in log_content.split('\n'):
            if "Installing" in line and "to" in line:
                match = re.search(pattern, line, re.IGNORECASE)
                if match:
                    source_path = match.group(1).strip()
                    target_path = match.group(2).strip()
                    # Extract the base name from source path
                    source_basename = Path(source_path).name
                    # Combine target path and source basename to get full file path
                    full_target_path = Path(target_path) / source_basename
                    files.add(str(full_target_path))
        return files

    @staticmethod
    def _extract_cmake_files(log_content: str) -> Set[str]:
        """Extract installed files from CMake build logs"""
        files = set()
        # Pattern for CMake installation lines
        pattern = r"-- Installing:\s*(.*)"

        for line in log_content.split('\n'):
            if "-- Installing:" in line:
                match = re.search(pattern, line)
                if match:
                    file_path = match.group(1).strip()
                    files.add(file_path)
        return files

    @staticmethod
    def _extract_autotools_files(log_content: str) -> Set[str]:
        """Extract installed files from Autotools build logs using regex patterns"""
        files = set()
        # Compile pattern with re.MULTILINE flag to handle multi-line content
        pattern = re.compile(
            r".*?/usr/bin/install\s+(?:-c\s+)?(?:-m\s+\d+\s+)?(.*?)\s+['\"]([^'\"]+)['\"]",
            re.MULTILINE
        )
        # Process the entire log content as a single string with multiline support
        matches = pattern.findall(log_content)
        RichLogger.debug(f"Found {len(matches)} install commands in log")
        for i, match in enumerate(matches):
            sources_part = match[0].strip()
            destination = match[1].strip()
            RichLogger.debug(f"Command {i+1}: sources='{sources_part}', destination='{destination}'")
            # Split sources part into individual files (ignore options starting with -)
            sources = [src for src in sources_part.split() if not src.startswith('-')]
            if not sources:
                RichLogger.debug("  No valid sources found, skipping")
                continue
            # Convert destination to Windows path
            win_destination = PathUtils.unix_to_win(destination)
            # Handle multiple source files with one destination directory
            if len(sources) > 1:
                # Multiple sources mean destination is a directory
                RichLogger.debug(f"Multiple sources detected, treating '{win_destination}' as directory")
                for source in sources:
                    # Convert source to Windows path and extract filename
                    win_source = PathUtils.unix_to_win(source)
                    source_filename = Path(win_source).name
                    # Combine destination directory with source filename
                    installed_file = str(Path(win_destination) / source_filename)
                    # Check if file exists before adding
                    if Path(installed_file).exists():
                        files.add(installed_file)
            else:
                # Single source file
                source = sources[0]
                win_source = PathUtils.unix_to_win(source)
                source_filename = Path(win_source).name
                # Check if destination has a file extension
                if Path(win_destination).suffix:
                    # Destination is a file path
                    RichLogger.debug(f"Single source detected, adding destination as file: {win_destination}")
                    if Path(win_destination).exists():
                        files.add(win_destination)
                else:
                    # Destination is a directory, combine with source filename
                    installed_file = str(Path(win_destination) / source_filename)
                    RichLogger.debug(f"Single source detected, adding combined path: {installed_file}")
                    if Path(installed_file).exists():
                        files.add(installed_file)
        return files

    @staticmethod
    def _extract_ms_files(log_content: str) -> Set[str]:
        """Extract installed files from MSBuild/MSVC build logs"""
        files = set()
        # Pattern for file copy operations in MS builds
        pattern = r".*->\s*(.*)"

        for line in log_content.split('\n'):
            if "->" in line and ("bin" in line or "lib" in line or "include" in line):
                match = re.search(pattern, line)
                if match:
                    file_path = match.group(1).strip()
                    files.add(file_path)
        return files
