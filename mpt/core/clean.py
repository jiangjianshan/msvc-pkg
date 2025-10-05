# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
import shutil
from pathlib import Path
from typing import Dict, Tuple, List, Optional

from mpt import ROOT_DIR
from mpt.utils.file import FileUtils
from mpt.config.package import PackageConfig
from mpt.core.log import RichLogger
from mpt.core.source import SourceManager


class CleanManager:
    """Manages the cleanup of build artifacts, source directories, and archive files.

    Provides comprehensive cleaning operations for library build environments,
    including log removal, source directory cleanup, and archive file deletion.
    Supports both Git-based and versioned source repositories with pattern-based
    file matching and safe deletion practices.
    """

    @staticmethod
    def clean_library(lib: str) -> Dict[str, Tuple[bool, str] | bool]:
        """
        Execute comprehensive cleanup of all artifacts for a specific library.

        Coordinates the complete cleanup process including log files, source directories,
        and downloaded archives. Handles configuration loading, error recovery, and
        provides detailed results for each cleanup category.

        Args:
            lib: Name of the library to clean, used to identify related artifacts

        Returns:
            Dictionary containing cleanup results for each category with:
            - logs: Tuple of (success status, log file path or error message)
            - source: Tuple of (success status, source directory path or error message)
            - archives: Tuple of (success status, archive file path or error message)
            - is_git: Boolean indicating if the library uses Git source repository
        """
        RichLogger.info(f"[[bold cyan]{lib}[/bold cyan]] Starting clean process")
        try:
            config = PackageConfig.load(lib)
            if not config:
                RichLogger.error(f"[[bold cyan]{lib}[/bold cyan]] Failed to load config")
                return CleanManager._create_error_result("Config error")

            log_result = CleanManager.clean_logs(lib)
            source_result = CleanManager.clean_source(lib, config)
            archive_result = CleanManager.clean_archives(lib)
            is_git = config and config.get('url') and SourceManager.is_git_url(config.get('url', ''))

            RichLogger.info(f"[[bold cyan]{lib}[/bold cyan]] Clean process completed for library")
            return {
                'logs': log_result,
                'source': source_result,
                'archives': archive_result,
                'is_git': is_git
            }

        except Exception as e:
            RichLogger.exception(f"[[bold cyan]{lib}[/bold cyan]] Error cleaning library")
            return CleanManager._create_error_result(str(e))

    @staticmethod
    def _create_error_result(error_msg: str) -> Dict[str, Tuple[bool, str] | bool]:
        """
        Create a standardized error result dictionary for cleanup failures.

        Generates a consistent error response structure when cleanup operations
        encounter unrecoverable errors, ensuring uniform error reporting.

        Args:
            error_msg: Descriptive error message explaining the failure reason

        Returns:
            Dictionary with error status for all cleanup categories using the
            provided error message as the result description
        """
        return {
            'logs': (False, error_msg),
            'source': (False, error_msg),
            'archives': (False, error_msg),
            'is_git': False
        }

    @staticmethod
    def clean_logs(lib: str) -> Tuple[bool, str]:
        """
        Remove build log files associated with a specific library.

        Deletes the primary log file for the library build process while
        providing appropriate logging and error handling for the operation.

        Args:
            lib: Library name used to identify the corresponding log file

        Returns:
            Tuple containing:
            - Boolean indicating overall success of log cleanup operation
            - String with path of deleted log file or "N/A" if no log found
        """
        log_file = ROOT_DIR / "logs" / f"{lib}.txt"
        if log_file.exists():
            try:
                RichLogger.info(f"Removing log file: [bold green]{log_file}[/bold green]")
                log_file.unlink()
                RichLogger.info(f"Successfully removed log file: [bold green]{log_file.relative_to(ROOT_DIR)}[/bold green]")
                return True, str(log_file.relative_to(ROOT_DIR))
            except Exception as e:
                RichLogger.exception(f"Failed to remove log file [bold green]{log_file}[/bold green]")
                return False, f"Failed to remove {log_file.relative_to(ROOT_DIR)}"
        RichLogger.info(f"No log file found for library: [bold cyan]{lib}[/bold cyan]")
        return True, "N/A"

    @staticmethod
    def clean_source(lib: str, config: PackageConfig) -> Tuple[bool, str]:
        """
        Remove all source directories and build artifacts for a library.

        Performs comprehensive source cleanup including:
        - Primary source directory removal
        - Version-specific source directories (for non-Git repositories)
        - Pattern-based cleanup of additional build artifacts
        - Safe deletion with proper error handling and logging

        Args:
            lib: Library name used to identify source directories
            config: Library configuration containing source type and version information

        Returns:
            Tuple containing:
            - Boolean indicating complete success of all source cleanup operations
            - Semicolon-separated string of cleaned paths or "N/A" if none found
        """
        cleaned_paths = []
        all_success = True

        RichLogger.info(f"Cleaning source directories for library: [bold cyan]{lib}[/bold cyan]")

        # Clean main source directory
        source_dir = ROOT_DIR / "releases" / lib
        if source_dir.exists() and source_dir.is_dir():
            RichLogger.info(f"Removing source directory: [bold green]{source_dir}[/bold green]")
            try:
                if FileUtils.force_delete_directory(source_dir):
                    cleaned_paths.append(str(source_dir.relative_to(ROOT_DIR)))
                    RichLogger.info(f"Successfully removed source directory: [bold green]{source_dir.relative_to(ROOT_DIR)}[/bold green]")
                else:
                    RichLogger.error(f"Failed to remove source: [bold red]{source_dir}[/bold red]")
                    all_success = False
            except Exception as e:
                RichLogger.exception(f"Error removing source directory: [bold red]{source_dir}[/bold red]")
                all_success = False

        # Clean versioned directory for non-git sources
        if not SourceManager.is_git_url(config.get('url', '')):
            version = config.get('version', 'unknown')
            versioned_dir = ROOT_DIR / "releases" / f"{lib}-{version}"
            if versioned_dir.exists() and versioned_dir.is_dir():
                RichLogger.info(f"Removing versioned source directory: [bold green]{versioned_dir}[/bold green]")
                try:
                    if FileUtils.force_delete_directory(versioned_dir):
                        cleaned_paths.append(str(versioned_dir.relative_to(ROOT_DIR)))
                        RichLogger.info(f"Successfully removed versioned source directory: [bold green]{versioned_dir.relative_to(ROOT_DIR)}[/bold green]")
                    else:
                        RichLogger.error(f"Failed to remove versioned source: [bold red]{versioned_dir}[/bold red]")
                        all_success = False
                except Exception as e:
                    RichLogger.exception(f"Error removing versioned source directory: [bold red]{versioned_dir}[/bold red]")
                    all_success = False

        # Clean additional patterns
        additional_patterns = [
            ROOT_DIR / "releases" / f"{lib}-*"
        ]

        for pattern in additional_patterns:
            RichLogger.info(f"Processing pattern: [bold yellow]{pattern}[/bold yellow]")
            try:
                for path in Path(ROOT_DIR).glob(str(pattern.relative_to(ROOT_DIR))):
                    if path.exists():
                        RichLogger.info(f"Removing path: [bold green]{path}[/bold green]")
                        try:
                            if FileUtils.force_delete_directory(path):
                                cleaned_paths.append(str(path.relative_to(ROOT_DIR)))
                                RichLogger.info(f"Successfully removed path: [bold green]{path.relative_to(ROOT_DIR)}[/bold green]")
                            else:
                                RichLogger.error(f"Failed to remove path: [bold red]{path}[/bold red]")
                                all_success = False
                        except Exception as e:
                            RichLogger.exception(f"Error removing path: [bold red]{path}[/bold red]")
                            all_success = False
            except Exception as e:
                RichLogger.exception(f"Error processing pattern: [bold yellow]{pattern}[/bold yellow]")
                all_success = False

        if not cleaned_paths:
            RichLogger.info(f"No source directories found to clean for library: [bold cyan]{lib}[/bold cyan]")

        message = "; ".join(cleaned_paths) if cleaned_paths else "N/A"
        return all_success, message

    @staticmethod
    def clean_archives(lib: str) -> Tuple[bool, str]:
        """
        Remove downloaded archive files for a specific library.

        Deletes archive files matching common patterns and extensions from the
        tags directory, including various compression formats and naming conventions.

        Args:
            lib: Library name used to generate archive file patterns

        Returns:
            Tuple containing:
            - Boolean indicating complete success of all archive cleanup operations
            - Semicolon-separated string of deleted archive paths or "N/A" if none found
        """
        cleaned_paths = []
        all_success = True
        tags_dir = ROOT_DIR / "tags"

        RichLogger.info(f"Cleaning archive files for library: [bold cyan]{lib}[/bold cyan]")

        archive_patterns = [
            f"{lib}-*.*",
            f"{lib}_*.zip",
            f"{lib}_*.tar.gz",
            f"{lib}_*.tar.bz2",
            f"{lib}_*.tar.xz"
        ]

        for pattern in archive_patterns:
            RichLogger.info(f"Processing archive pattern: [bold yellow]{pattern}[/bold yellow]")
            try:
                for archive in tags_dir.glob(pattern):
                    if archive.is_file():
                        RichLogger.info(f"Removing archive: [bold green]{archive}[/bold green]")
                        try:
                            if FileUtils.safe_unlink(archive):
                                cleaned_paths.append(str(archive.relative_to(ROOT_DIR)))
                                RichLogger.info(f"Successfully removed archive: [bold green]{archive.relative_to(ROOT_DIR)}[/bold green]")
                            else:
                                RichLogger.error(f"Failed to remove archive: [bold red]{archive}[/bold red]")
                                all_success = False
                        except Exception as e:
                            RichLogger.exception(f"Error removing archive: [bold red]{archive}[/bold red]")
                            all_success = False
            except Exception as e:
                RichLogger.exception(f"Error processing archive pattern: [bold yellow]{pattern}[/bold yellow]")
                all_success = False

        if not cleaned_paths:
            RichLogger.info(f"No archive files found to clean for library: [bold cyan]{lib}[/bold cyan]")

        message = "; ".join(cleaned_paths) if cleaned_paths else "N/A"
        return all_success, message
