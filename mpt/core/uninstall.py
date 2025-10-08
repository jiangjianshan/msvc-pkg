# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#

import re

from pathlib import Path, PureWindowsPath
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
    def uninstall_library(arch: str, lib: str) -> int:
        """
        Uninstall a library by parsing its build log file to find installed files
        and then removing them.

        Args:
            arch: Target architecture
            lib: Name of the library to uninstall

        Returns:
            int: Number of files successfully removed, or -1 if uninstallation failed
        """
        HistoryManager.remove_record(arch, lib)

        # Construct log file path
        log_file = ROOT_DIR / "logs" / f"{lib}.log"

        if not log_file.exists():
            RichLogger.debug(f"Log file not found: {log_file}")
            return 0  # No files to remove, but not considered a failure

        # Read log content
        try:
            log_content = log_file.read_text(encoding='utf-8', errors='ignore')
        except Exception as e:
            RichLogger.debug(f"Error reading log file {log_file}: {e}")
            return -1  # Considered a failure

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
            return 0  # No files to remove, but not considered a failure

        # Check for dangerous paths containing only '.' or '..'
        dangerous_paths = {path for path in installed_files
                          if str(path) in ('.', '..') or
                             any(part in ('.', '..') for part in path.parts)}
        if dangerous_paths:
            RichLogger.exception(f"Dangerous paths found in installed files for {lib}: {dangerous_paths}")
            return 0

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
                # Continue with other files instead of returning immediately
                # We'll count only successfully removed files

        RichLogger.debug(f"Successfully removed {removed_count} files")
        return removed_count

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
        return "checking for suffix of object files" in log_content

    @staticmethod
    def _extract_windows_symbolic_links(log_content: str) -> Set[Path]:
        """
        Extract Windows symbolic links created with mklink command from build logs

        Args:
            log_content: Content of the build log

        Returns:
            Set of Path objects representing symbolic link targets
        """
        files = set()

        # Pattern for Windows mklink command output - matches the file path between
        # "symbolic link created for" and "<<===>>"
        pattern = re.compile(
            r"symbolic link created for\s+(.*?)\s+<<===>>\s+.*",
            re.MULTILINE | re.IGNORECASE
        )

        # Find all symbolic link matches in the log content
        matches = pattern.findall(log_content)
        RichLogger.debug(f"Found {len(matches)} Windows symbolic link creations")

        # Process symbolic link matches
        for file_path in matches:
            clean_path = file_path.strip()
            if clean_path:
                file_path_obj = Path(clean_path)
                if file_path_obj.exists():
                    files.add(file_path_obj)
                    RichLogger.debug(f"Windows symbolic link target: {clean_path}")
                else:
                    RichLogger.debug(f"Windows symbolic link target does not exist: {clean_path}")

        return files

    @staticmethod
    def _extract_unix_symbolic_links(log_content: str) -> Set[Path]:
        """
        Extract Unix symbolic links created with ln command from build logs

        Args:
            log_content: Content of the build log

        Returns:
            Set of Path objects representing symbolic link sources (left side of ->)
        """
        files = set()

        # Pattern for Unix ln command output - matches the source path before "->"
        pattern = re.compile(
            r"['\"]([^'\"]+)['\"]\s*->\s*['\"][^'\"]*['\"]",
            re.MULTILINE
        )

        # Find all symbolic link matches in the log content
        matches = pattern.findall(log_content)
        RichLogger.debug(f"Found {len(matches)} Unix symbolic link creations")

        # Process symbolic link matches
        for file_path in matches:
            clean_path = file_path.strip()
            if clean_path:
                file_path_obj = Path(PathUtils.unix_to_win(clean_path))
                if file_path_obj.exists():
                    files.add(file_path_obj)
                    RichLogger.debug(f"Unix symbolic link source: {clean_path}")
                else:
                    RichLogger.debug(f"Unix symbolic link source does not exist: {clean_path}")

        return files

    @staticmethod
    def _extract_cmake_files(log_content: str) -> Set[Path]:
        """Extract installed files from CMake build logs using regex patterns"""
        files = set()
        # Pattern for CMake installation lines
        pattern = re.compile(r"-- Installing:\s*(.*)", re.MULTILINE)

        # Find all matches in the log content
        matches = pattern.findall(log_content)
        RichLogger.debug(f"Found {len(matches)} CMake install commands")

        for file_path in matches:
            clean_path = file_path.strip()
            if clean_path:
                files.add(Path(clean_path))
                RichLogger.debug(f"CMake install: {clean_path}")

        # Add Windows symbolic links
        files.update(UninstallManager._extract_windows_symbolic_links(log_content))

        # Some CMake base library may don't have cmake install command
        files.update(UninstallManager._extract_ms_files(log_content))

        return files

    @staticmethod
    def _extract_meson_files(log_content: str) -> Set[Path]:
        """Extract installed files from Meson build logs using regex patterns"""
        files = set()
        # Pattern for Meson installation lines
        pattern = re.compile(r"Installing\s+(.*?)\s+to\s+(.*?)\s*$", re.MULTILINE | re.IGNORECASE)

        # Find all matches in the log content
        matches = pattern.findall(log_content)
        RichLogger.debug(f"Found {len(matches)} Meson install commands")

        for match in matches:
            source_path = match[0].strip()
            target_path = match[1].strip()
            # Extract the base name from source path
            source_basename = Path(source_path).name
            # Combine target path and source basename to get full file path
            full_target_path = Path(target_path) / source_basename
            files.add(full_target_path)
            RichLogger.debug(f"Meson install: source={source_path}, target={target_path}, full_path={full_target_path}")

        # Add Windows symbolic links
        files.update(UninstallManager._extract_windows_symbolic_links(log_content))

        return files

    @staticmethod
    def _extract_ms_files(log_content: str) -> Set[Path]:
        """Extract installed files from MSBuild/MSVC build logs using regex patterns"""
        files = set()

        # Pattern for xcopy command output - matches source and destination paths with same extension
        # Handles both quoted and unquoted paths on both sides of "->"
        # Ensures source and destination file extensions are identical
        pattern = re.compile(
            r"^(?:'([^']+\.([a-zA-Z0-9]+))'\s->\s*'([^']+\.\2)'|([^\s'].*?\.([a-zA-Z0-9]+))\s->\s*([^\n]+\.\5))",
            re.MULTILINE
        )

        # Find all matches in the log content
        matches = list(pattern.finditer(log_content))
        RichLogger.debug(f"Found {len(matches)} xcopy operations with matching file extensions")

        # Process matches
        for match in matches:
            # Extract the destination path from the match
            # Group 3 for quoted destination, group 6 for unquoted destination
            dest_path = match.group(3) if match.group(3) else match.group(6)
            if not dest_path:
                continue
            clean_path = dest_path.strip()
            # Convert Unix-style path to Windows-style if needed
            if not PathUtils.is_windows_path(clean_path):
                win_path = PathUtils.unix_to_win(clean_path)
            else:
                win_path = clean_path
            dest_path_obj = Path(win_path)
            if dest_path_obj.exists():
                files.add(dest_path_obj)
                RichLogger.debug(f"xcopy destination: {dest_path_obj}")
            else:
                RichLogger.debug(f"xcopy destination does not exist: {dest_path_obj}")
        # Add Windows symbolic links
        symbolic_links = UninstallManager._extract_windows_symbolic_links(log_content)
        files.update(symbolic_links)

        return files

    @staticmethod
    def _extract_autotools_files(log_content: str) -> Set[Path]:
        """Extract installed files from Autotools build logs using regex patterns"""
        files = set()

        # TODO: I have made significant optimizations to the uninstall.py script. However,
        #       handling the locating of installed files for libraries built with autotools
        #       is quite complex. Most of the functionality has been implemented, with only
        #       a few edge cases left to optimize.

        # Extract files from different types of install commands
        files.update(UninstallManager._extract_ordinary_install_commands(log_content))
        files.update(UninstallManager._extract_libtool_install_commands(log_content))
        files.update(UninstallManager._extract_for_loop_install_commands(log_content))
        files.update(UninstallManager._extract_installing_as_patterns(log_content))

        # Add Unix symbolic links
        files.update(UninstallManager._extract_unix_symbolic_links(log_content))

        return files

    @staticmethod
    def _extract_ordinary_install_commands(log_content: str) -> Set[Path]:
        """
        Extract installed files from ordinary /usr/bin/install commands in Autotools build logs.

        Args:
            log_content: Content of the build log

        Returns:
            Set of Path objects representing installed files
        """
        files = set()
        import shlex

        # Pattern for /usr/bin/install commands with exactly 0 or 1 leading whitespace
        pattern_install = re.compile(
            r'^\s?/usr/bin/install\s+.*$',  # Match entire install command line
            re.MULTILINE
        )

        # Process all matching ordinary install commands
        matches_install = pattern_install.findall(log_content)
        RichLogger.debug(f"Found {len(matches_install)} ordinary install commands")

        for command_line in matches_install:
            try:
                # Use shlex to split the command line into arguments
                args = shlex.split(command_line)

                # Remove the install command itself
                args = args[1:] if args and args[0] == '/usr/bin/install' else args

                # Filter out options and their arguments
                filtered_args = []
                i = 0
                while i < len(args):
                    if args[i] in ['-c', '-d', '-D', '-T', '-v']:
                        # These options don't take arguments
                        i += 1
                    elif args[i] in ['-m']:
                        # -m takes a mode argument, skip both
                        i += 2
                    elif args[i].startswith('-'):
                        # Skip any other options
                        i += 1
                    else:
                        # This is a file path
                        filtered_args.append(args[i])
                        i += 1

                if len(filtered_args) < 2:
                    RichLogger.debug(f"Skipping install command with insufficient arguments: {command_line}")
                    continue

                # The last argument is the destination
                destination = filtered_args[-1]
                # All other arguments are sources
                sources = filtered_args[:-1]

                # Clean destination (remove quotes if any)
                clean_destination = destination.strip().strip("'")
                win_destination = PathUtils.unix_to_win(clean_destination)

                RichLogger.debug(f"Processing install command: sources={sources}, dest='{clean_destination}'")

                # Check if destination is a directory (doesn't have a file extension or ends with path separator)
                dest_path = Path(win_destination)
                is_directory = ('.' not in dest_path.name or
                               win_destination.endswith('/') or
                               win_destination.endswith('\\') or
                               len(sources) > 1)

                if is_directory:
                    # Case 2: Install to directory - combine destination with each source filename
                    for source in sources:
                        clean_source = source.strip().strip("'")
                        win_source = PathUtils.unix_to_win(clean_source)
                        source_filename = Path(win_source).name
                        installed_file_path = dest_path / source_filename

                        if installed_file_path.exists():
                            files.add(installed_file_path)
                            RichLogger.debug(f"Added file (to directory): {installed_file_path}")
                        else:
                            RichLogger.debug(f"File in directory does not exist: {installed_file_path}")
                else:
                    # Case 1: Direct install to file path - use destination as is
                    if dest_path.exists():
                        files.add(dest_path)
                        RichLogger.debug(f"Added file (direct install): {win_destination}")
                    else:
                        RichLogger.debug(f"File does not exist: {win_destination}")

            except Exception as e:
                RichLogger.debug(f"Error parsing install command '{command_line}': {e}")
                continue

        return files

    @staticmethod
    def _extract_libtool_install_commands(log_content: str) -> Set[Path]:
        """
        Extract installed files from libtool install commands in Autotools build logs.

        Args:
            log_content: Content of the build log

        Returns:
            Set of Path objects representing installed files
        """
        files = set()

        # Pattern for libtool install commands
        pattern_libtool_install = re.compile(
            r'^\s?libtool: install: /usr/bin/install\s+(?:-c\s+)?(?:-m\s+\d+\s+)?(.*?)\s+([\'"]?)([^\'"\s]+)(?:\2|\s|$)',
            re.MULTILINE
        )

        # Process libtool install commands
        matches_libtool = pattern_libtool_install.finditer(log_content)
        RichLogger.debug(f"Found {len(list(matches_libtool))} libtool install commands")

        # Recreate the iterator
        matches_libtool = pattern_libtool_install.finditer(log_content)

        for i, match in enumerate(matches_libtool):
            RichLogger.debug(f"=== Libtool Match {i+1} ===")
            RichLogger.debug(f"Full match: {match.group(0)}")
            RichLogger.debug(f"Sources part: '{match.group(1)}'")
            RichLogger.debug(f"Quote char: '{match.group(2)}'")
            RichLogger.debug(f"Destination: '{match.group(3)}'")

            destination = match.group(3).strip()
            win_destination = PathUtils.unix_to_win(destination)
            RichLogger.debug(f"Libtool install: destination='{win_destination}'")
            if Path(win_destination).exists():
                files.add(Path(win_destination))
                RichLogger.debug(f"Added libtool file: '{win_destination}'")
            else:
                RichLogger.debug(f"Libtool install destination does not exist: '{win_destination}'")

        return files

    @staticmethod
    def _extract_for_loop_install_commands(log_content: str) -> Set[Path]:
        """
        Extract installed files from install commands in for loops in Autotools build logs.

        Args:
            log_content: Content of the build log

        Returns:
            Set of Path objects representing installed files
        """
        files = set()

        # Pattern for install commands in for loops
        # Modified regex to remove trailing semicolon in destination path
        pattern_for_loop = re.compile(
            r'^\s*for\s+(\w+)\s+in\s+([^;]+);\s*do\s*\\\s*'
            r'\s*/usr/bin/install\s+(?:-c\s+)?(?:-m\s+\d+\s+)?([^\s\\]+)\s*\\\s*'
            r'\s*([^\s;\\]+);?\s*\\\s*'  # Modified here to remove semicolon
            r'\s*done;?\s*\\?',
            re.MULTILINE
        )

        # Process for loops with install commands - destination path obtained through variable substitution
        matches_for = pattern_for_loop.findall(log_content)
        RichLogger.debug(f"Found {len(matches_for)} for loops with install commands")

        for match in matches_for:
            var_name = match[0].strip()
            file_list_str = match[1].strip()
            source_template = match[2].strip()
            dest_template = match[3].strip()  # Should not contain semicolon now

            # Clean file list string, handle multiple consecutive spaces
            file_list_str = re.sub(r'\s+', ' ', file_list_str)
            # Parse file list (remove empty items)
            files_in_loop = [f.strip() for f in file_list_str.split() if f.strip()]

            RichLogger.debug(f"For loop: variable={var_name}, files={files_in_loop}, source_template={source_template}, dest_template={dest_template}")

            for file_name in files_in_loop:
                # Replace variables in destination template (e.g., $file)
                actual_dest = dest_template.replace(f"${var_name}", file_name)
                win_dest = PathUtils.unix_to_win(actual_dest)

                # Check if file exists (using modified filename)
                if Path(win_dest).exists():
                    files.add(Path(win_dest))
                    RichLogger.debug(f"  File {file_name} -> {win_dest} [FOUND]")
                else:
                    # TODO: Currently trying to modify file extension (.sin -> .sed), need to find better approach
                    modified_win_dest = win_dest
                    if file_name.endswith('.sin'):
                        modified_win_dest = win_dest.replace('.sin', '.sed')
                        if Path(modified_win_dest).exists():
                            files.add(Path(modified_win_dest))
                            RichLogger.debug(f"  File {file_name} -> {modified_win_dest} [FOUND AFTER MODIFICATION]")
                        else:
                            RichLogger.debug(f"For loop destination does not exist: {win_dest} (also tried {modified_win_dest})")
                    else:
                        RichLogger.debug(f"For loop destination does not exist: {win_dest}")

        return files

    @staticmethod
    def _extract_installing_as_patterns(log_content: str) -> Set[Path]:
        """
        Extract installed files from "installing ... as ..." patterns in Autotools build logs.

        Args:
            log_content: Content of the build log

        Returns:
            Set of Path objects representing installed files
        """
        files = set()

        # Pattern for "installing ... as ..." pattern (destination path may not have quotes)
        pattern_installing_as = re.compile(
            r'^\s?installing\s+.*?\s+as\s+(\S+)',
            re.MULTILINE | re.IGNORECASE
        )

        # Process "installing as" patterns - destination path is a file
        matches_as = pattern_installing_as.findall(log_content)
        RichLogger.debug(f"Found {len(matches_as)} 'installing as' patterns")
        for dest_path in matches_as:
            win_dest = PathUtils.unix_to_win(dest_path)
            RichLogger.debug(f"Installing as: destination={win_dest}")
            if Path(win_dest).exists():
                files.add(Path(win_dest))
            else:
                RichLogger.debug(f"Installing as destination does not exist: {win_dest}")

        return files
