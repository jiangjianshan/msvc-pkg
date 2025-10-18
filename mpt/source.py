# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
import re
import shutil
import subprocess

from pathlib import Path
from typing import Optional

from mpt import ROOT_DIR
from mpt.archive import ArchiveHandler
from mpt.download import DownloadHandler
from mpt.file import FileUtils
from mpt.git import GitHandler
from mpt.log import RichLogger
from mpt.patch import PatchHandler


class SourceManager:
    """
    Comprehensive source code management system for downloading, extracting, and maintaining source repositories.

    Provides end-to-end source code handling including Git repository management, archive processing,
    patch application, and exclusion filtering. Supports complex source configurations with multiple
    extra sources and robust error recovery mechanisms.
    """

    @staticmethod
    def _apply_exclusions(directory: Path, patterns: list) -> bool:
        """
        Apply file and directory exclusion patterns to a target directory with comprehensive filtering.

        Processes a list of glob patterns to remove matching files and directories from the
        specified target directory. Handles both files and directories with appropriate
        deletion methods and provides detailed logging of exclusion operations.

        Args:
            directory: Target directory where exclusion patterns should be applied
            patterns: List of glob patterns specifying files/directories to exclude

        Returns:
            bool: True if all exclusion operations completed successfully, False if any errors occurred
        """
        try:
            success = True
            for pattern in patterns:
                for item in directory.glob(pattern):
                    try:
                        if item.is_file() or item.is_symlink():
                            item.unlink()
                            RichLogger.debug(f"Excluded file: [bold cyan]{item}[/bold cyan]")
                        elif item.is_dir():
                            shutil.rmtree(item)
                            RichLogger.debug(f"Excluded directory: [bold cyan]{item}[/bold cyan]")
                    except Exception as e:
                        RichLogger.error(f"Failed to exclude [bold cyan]{item}[/bold cyan]: [bold red]{str(e)}[/bold red]")
                        success = False
            return success
        except Exception as e:
            RichLogger.exception(f"Exception in _apply_exclusions: {str(e)}")
            return False

    @staticmethod
    def is_git_url(url: str) -> bool:
        """
        Determine if a URL points to a Git repository using comprehensive detection heuristics.

        Analyzes URL patterns to identify Git repositories, primarily checking for the
        conventional '.git' extension used by most Git hosting services and platforms.

        Args:
            url: URL string to analyze for Git repository characteristics

        Returns:
            bool: True if URL appears to point to a Git repository, False otherwise
        """
        try:
            is_git = GitHandler.is_git_source(url)
            return is_git
        except Exception as e:
            RichLogger.exception(f"Exception in is_git_url: {str(e)}")
            return False

    @staticmethod
    def _run_check_command(command: str, cwd: Path) -> bool:
        """
        Execute a verification command to determine if source processing is required.

        Runs shell commands to check if source code needs additional processing such as
        extraction or synchronization. Handles command execution errors gracefully and
        provides detailed logging of command execution and results.

        Args:
            command: Shell command string to execute for verification
            cwd: Working directory where the command should be executed

        Returns:
            bool: True if command execution succeeds (return code 0), False otherwise
        """
        try:
            result = subprocess.run(command, shell=True, cwd=cwd, capture_output=True, text=True)
            if result.returncode == 0:
                RichLogger.debug(f"Check command passed: [bold cyan]{command}[/bold cyan]")
                return True
            else:
                RichLogger.debug(f"Check command failed with return code {result.returncode}: [bold cyan]{command}[/bold cyan]")
                return False
        except Exception as e:
            RichLogger.exception(f"Exception in _run_check_command: {str(e)}")
            return False

    @staticmethod
    def fetch_source(config: dict) -> Optional[Path]:
        """
        Execute the complete source acquisition and processing pipeline with comprehensive error handling.

        Coordinates the full source management workflow including:
        - Primary source processing (Git cloning or archive extraction)
        - Extra source processing for additional components
        - Error recovery and detailed status reporting

        Args:
            config: Source configuration dictionary containing URL, version, and processing options

        Returns:
            Path: Path to the processed source directory, or None on failure
        """
        try:
            source_dir = SourceManager._process_source(config)
            if not source_dir:
                RichLogger.error(f"Source fetch failed for [bold cyan]{config['name']}[/bold cyan]")
                return None
            if 'extras' in config:
                for extra in config['extras']:
                    extra_path = SourceManager._process_source(extra, base_dir=source_dir)
                    if not extra_path:
                        RichLogger.warning(f"Failed to process extra source: [bold cyan]{extra['name']}[/bold cyan]")
            return source_dir
        except Exception as e:
            RichLogger.exception(f"Exception in fetch_source: {str(e)}")
            return None

    @staticmethod
    def _process_source(source_config: dict,
                       base_dir: Optional[Path] = None) -> Optional[Path]:
        """
        Process an individual source component with support for both main and extra sources.

        Handles the complete processing lifecycle for a single source including:
        - Target directory determination based on source type
        - Existing source update or new source acquisition
        - Check command execution for processing requirement detection
        - Configuration parameter expansion and validation

        Args:
            source_config: Configuration dictionary for the specific source
            base_dir: Optional base directory for extra source processing

        Returns:
            Path: Path to the processed source directory, or None on failure
        """
        try:
            url = source_config['url']
            name = source_config['name']
            version = source_config.get('version', 'unknown')
            sha256 = source_config.get('sha256')
            extract_path = source_config.get('extract')
            include = source_config.get('include')
            target = source_config.get('target')

            # Check for extra source check command
            force_extract = False
            # Determine target directory
            if base_dir and target:
                target_dir = base_dir / target
                RichLogger.debug(f"Using base directory with target: [bold green]{target_dir}[/bold green]")
                if 'check' in source_config:
                    check_command = source_config['check']
                    if SourceManager._run_check_command(check_command, base_dir):
                        RichLogger.info(f"Check command indicates processing needed for extra source: [bold cyan]{name}[/bold cyan]")
                        force_extract = True
                    else:
                        RichLogger.info(f"Check command indicates no processing needed for extra source: [bold cyan]{name}[/bold cyan]")
            else:
                if SourceManager.is_git_url(url):
                    target_dir = ROOT_DIR / 'buildtrees' / 'sources' / f"{name}"
                else:
                    target_dir = ROOT_DIR / 'buildtrees' / 'sources' / f"{name}-{version}"
            if target_dir.exists():
                return SourceManager._handle_existing_source(source_config, target_dir, force_extract)
            else:
                RichLogger.debug(f"Target directory does not exist: [bold green]{target_dir}[/bold green]")
                return SourceManager._fetch_new_source(source_config, target_dir, force_extract)
        except Exception as e:
            RichLogger.exception(f"Exception in _process_source: {str(e)}")
            return None

    @staticmethod
    def _handle_existing_source(config: dict, source_dir: Path, force_extract: bool) -> Optional[Path]:
        """
        Manage existing source directories with appropriate update or re-extraction strategies.

        Determines the optimal processing approach for existing sources based on their type:
        - Git repositories: Update with latest changes using Git operations
        - Archive sources: Re-extract if forced or if directory is empty
        - Provides comprehensive error handling and recovery for corrupted sources

        Args:
            config: Source configuration dictionary
            source_dir: Path to the existing source directory
            force_extract: Boolean forcing re-extraction even if source exists

        Returns:
            Path: Path to the processed source directory, or None on failure
        """
        try:
            if SourceManager.is_git_url(config['url']):
                return SourceManager._update_git_repository(config, source_dir)
            else:
                return SourceManager._process_archive_source(config, source_dir, force_extract)
        except Exception as e:
            RichLogger.exception(f"Exception in _handle_existing_source: {str(e)}")
            return None

    @staticmethod
    def _fetch_new_source(config: dict, source_dir: Path, force_extract: bool) -> Optional[Path]:
        """
        Acquire and process new sources that don't currently exist in the local environment.

        Handles the initial acquisition of sources using appropriate methods:
        - Git repositories: Clone from remote URLs with configuration options
        - Archive sources: Download, verify, and extract archive files
        - Provides comprehensive error handling for acquisition failures

        Args:
            config: Source configuration dictionary
            source_dir: Target directory where source should be placed
            force_extract: Boolean forcing extraction even if not typically required

        Returns:
            Path: Path to the processed source directory, or None on failure
        """
        try:
            if SourceManager.is_git_url(config['url']):
                RichLogger.debug(f"Cloning Git repository: [bold cyan]{config['url']}[/bold cyan]")
                success = GitHandler.clone_repository(config, source_dir)
                if not success:
                    RichLogger.error(f"Failed to clone repository: [bold cyan]{config['url']}[/bold cyan]")
                    return None
                return source_dir
            else:
                return SourceManager._process_archive_source(config, source_dir, force_extract)
        except Exception as e:
            RichLogger.exception(f"Exception in _fetch_new_source: {str(e)}")
            return None

    @staticmethod
    def _process_archive_source(config: dict, source_dir: Path, force_extract: bool) -> Optional[Path]:
        """
        Handle archive-based source processing with download, verification, and extraction.

        Manages the complete archive processing pipeline including:
        - Archive file availability checking and downloading
        - Hash verification for integrity validation
        - Archive extraction with optional path filtering
        - Patch application for custom modifications

        Args:
            config: Archive source configuration dictionary
            source_dir: Target directory for archive extraction
            force_extract: Boolean forcing extraction even if target directory exists

        Returns:
            Path: Path to the processed source directory, or None on failure
        """
        try:
            archive_path = SourceManager._ensure_archive_exists(config)
            if not archive_path:
                RichLogger.error(f"Archive not available for [bold cyan]{config['name']}[/bold cyan]")
                return None
            if not source_dir.exists():
                source_dir.mkdir(parents=True, exist_ok=True)
            if force_extract or not any(source_dir.iterdir()):
                if not SourceManager._extract_and_patch(archive_path, source_dir, config):
                    return None
            return source_dir
        except Exception as e:
            RichLogger.exception(f"Exception in _process_archive_source: {str(e)}")
            return None

    @staticmethod
    def _ensure_archive_exists(config: dict) -> Optional[Path]:
        """
        Guarantee archive file availability through download or verification of existing files.

        Implements a comprehensive archive management strategy with multiple scenarios:
        - Existing file without verification requirements
        - Existing file with hash verification
        - New file download with optional verification
        - Error handling for download failures and verification mismatches

        Args:
            config: Archive configuration containing URL, expected hash, and other metadata

        Returns:
            Path: Filesystem path to the verified archive file, or None if unavailable
        """
        try:
            url = config['url']
            archive_filename = SourceManager._get_archive_filename(url, config)
            archive_path = ROOT_DIR / 'downloads' / archive_filename
            # Case 1: File exists and no hash verification needed
            if archive_path.exists() and 'sha256' not in config:
                RichLogger.info(f"Using existing archive: [bold cyan]{archive_filename}[/bold cyan]")
                return archive_path
            # Case 2: File exists but verification required
            if archive_path.exists() and 'sha256' in config:
                expected_hash = config['sha256']
                # Perform single verification
                if ArchiveHandler.verify_hash(archive_path, expected_hash):
                    return archive_path
                else:
                    RichLogger.warning(f"Archive verification failed - removing invalid file: [bold cyan]{archive_filename}[/bold cyan]")
                    FileUtils.delete_file(archive_path)
            # Case 3: File doesn't exist, need to download
            if not DownloadHandler.download_file(url, archive_path):
                RichLogger.error(f"Archive download failed: [bold cyan]{archive_filename}[/bold cyan]")
                return None
            # Case 4: Verification needed after download
            if 'sha256' in config:
                expected_hash = config['sha256']
                if not ArchiveHandler.verify_hash(archive_path, expected_hash):
                    RichLogger.error(f"Downloaded archive failed verification: [bold cyan]{archive_filename}[/bold cyan]")
                    FileUtils.delete_file(archive_path)
                    return None
            return archive_path
        except Exception as e:
            RichLogger.exception(f"Exception in _ensure_archive_exists: {str(e)}")
            return None

    @staticmethod
    def _update_git_repository(config: dict, source_dir: Path) -> Optional[Path]:
        """
        Update existing Git repositories with robust error recovery and integrity checking.

        Provides sophisticated Git repository management including:
        - Repository integrity validation before update attempts
        - Graceful update operations with comprehensive error handling
        - Automatic repair mechanisms for corrupted repositories
        - Detailed logging throughout the update process

        Args:
            config: Git repository configuration dictionary
            source_dir: Path to the existing Git repository

        Returns:
            Path: Path to the updated repository, or None on failure
        """
        try:
            RichLogger.info(f"Updating Git repository: [bold cyan]{config['name']}[/bold cyan]")
            if not GitHandler.verify_repository_integrity(source_dir, config):
                RichLogger.warning(f"Repository integrity issue detected: [bold cyan]{source_dir}[/bold cyan]")
                if GitHandler.repair_repository(source_dir, config):
                    RichLogger.info(f"Repository repaired successfully: [bold cyan]{source_dir}[/bold cyan]")
                    return source_dir
                RichLogger.error(f"Repository repair failed: [bold cyan]{source_dir}[/bold cyan]")
                return None

            updated = GitHandler.update_repository(source_dir, config)
            if not updated:
                RichLogger.warning(f"Update failed - attempting repair: [bold cyan]{source_dir}[/bold cyan]")
                if GitHandler.repair_repository(source_dir, config):
                    RichLogger.info(f"Repository repaired after update failure: [bold cyan]{source_dir}[/bold cyan]")
                    return source_dir
                return None

            RichLogger.info(f"Repository updated successfully: [bold cyan]{source_dir}[/bold cyan]")
            return source_dir
        except Exception as e:
            RichLogger.exception(f"Exception in _update_git_repository: {str(e)}")
            RichLogger.warning(f"Exception during update - attempting repair: [bold cyan]{source_dir}[/bold cyan]")
            if GitHandler.repair_repository(source_dir, config):
                RichLogger.info(f"Repository repaired after exception: [bold cyan]{source_dir}[/bold cyan]")
                return source_dir
            return None

    @staticmethod
    def _extract_and_patch(archive_path: Path, source_dir: Path, config: dict) -> bool:
        """
        Execute complete archive extraction and post-processing pipeline.

        Coordinates the multi-stage processing of archive files including:
        - Archive extraction with optional subpath targeting
        - File and directory exclusion based on patterns
        - Patch application for source code modifications
        - Comprehensive error handling for each processing stage

        Args:
            archive_path: Path to the archive file for extraction
            source_dir: Target directory for extracted contents
            config: Source configuration containing processing instructions

        Returns:
            bool: True if all extraction and processing stages completed successfully, False otherwise
        """
        try:
            extract_path = config.get('extract')
            exclude_patterns = config.get('exclude', [])

            RichLogger.debug(f"Extracting archive: [bold cyan]{archive_path}[/bold cyan] to [bold green]{source_dir}[/bold green]")

            if not ArchiveHandler.extract(
                archive_path=archive_path,
                target_dir=source_dir,
                extract_path=extract_path,
                remove_archive=False
            ):
                RichLogger.error(f"Archive extraction failed: [bold cyan]{archive_path}[/bold cyan]")
                return False

            if exclude_patterns:
                RichLogger.info(f"Applying exclusions for [bold cyan]{config['name']}[/bold cyan]")
                if not SourceManager._apply_exclusions(source_dir, exclude_patterns):
                    RichLogger.error(f"File exclusion failed for [bold cyan]{config['name']}[/bold cyan]")
                    return False

            if not PatchHandler.apply_patches(source_dir, config=config):
                RichLogger.error(f"Patch application failed for [bold cyan]{config['name']}[/bold cyan]")
                return False

            RichLogger.debug(f"Successfully extracted and patched: [bold cyan]{config['name']}[/bold cyan]")
            return True
        except Exception as e:
            RichLogger.exception(f"Exception in _extract_and_patch: {str(e)}")
            return False

    @staticmethod
    def _get_archive_filename(url: str, config: dict) -> str:
        """
        Generate appropriate filenames for archive files based on URL patterns and configuration.

        Creates consistent and predictable filenames for downloaded archives using:
        - Library name and version from configuration
        - URL-based extension detection
        - Fallback strategies for unknown archive types

        Args:
            url: Source URL for archive downloading
            config: Source configuration containing name and version information

        Returns:
            str: Generated filename for the archive file
        """
        try:
            base_name = f"{config['name']}-{config['version']}"
            extension = SourceManager._guess_extension(url)
            filename = f"{base_name}.{extension}"
            return filename
        except Exception as e:
            RichLogger.exception(f"Exception in _get_archive_filename: {str(e)}")
            return f"{config['name']}-{config['version']}.zip"

    @staticmethod
    def _guess_extension(url: str) -> str:
        """
        Determine archive file format based on URL patterns and common extension conventions.

        Implements comprehensive archive type detection using:
        - Extension pattern matching for common archive formats
        - Regular expression matching for complex extension patterns
        - Fallback to default format when detection fails

        Args:
            url: URL string to analyze for archive format indicators

        Returns:
            str: Detected archive format extension
        """
        try:
            extensions = {
                '.tar.gz': 'tar.gz',
                '.tgz': 'tar.gz',
                '.tar.bz2': 'tar.bz2',
                '.tbz2': 'tar.bz2',
                '.tar.xz': 'tar.xz',
                '.txz': 'tar.xz',
                '.tar': 'tar',
                '.zip': 'zip'
            }
            for ext, result in extensions.items():
                if url.endswith(ext):
                    return result

            patterns = {
                r'\.t(?:ar\.)?gz$': 'tar.gz',
                r'\.t(?:ar\.)?bz2$': 'tar.bz2',
                r'\.t(?:ar\.)?xz$': 'tar.xz'
            }
            for pattern, result in patterns.items():
                if re.search(pattern, url, re.IGNORECASE):
                    RichLogger.debug(f"Detected pattern [bold cyan]{pattern}[/bold cyan] for URL: [bold green]{url}[/bold green]")
                    return result

            RichLogger.warning(f"Unknown extension for URL [bold cyan]{url}[/bold cyan], defaulting to zip")
            return 'zip'
        except Exception as e:
            RichLogger.exception(f"Exception in _guess_extension: {str(e)}")
            return 'zip'
