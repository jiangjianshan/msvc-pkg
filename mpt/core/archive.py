# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import fnmatch
import os
import tarfile
import zipfile
import hashlib
import shutil
import re
import zstandard as zstd
import io

from pathlib import Path
from typing import Optional, Union, List

from mpt.core.log import RichLogger

class ArchiveHandler:
    """Provides comprehensive utilities for archive handling, extraction, and hash verification"""

    @staticmethod
    def _should_exclude(file_path: str, exclude_list: Optional[List[str]]) -> bool:
        """
        Determine if a file path matches any exclusion patterns.

        Processes glob-style patterns and directory exclusions to identify files
        that should be skipped during archive extraction operations.

        Args:
            file_path: The normalized file path to check against exclusion rules
            exclude_list: List of glob patterns or directory paths to exclude

        Returns:
            bool: True if the file matches any exclusion pattern, False otherwise
        """
        try:
            if not exclude_list:
                return False

            normalized_path = file_path.replace('\\', '/')
            for pattern in exclude_list:
                if pattern.endswith('/'):
                    dir_pattern = pattern.rstrip('/')
                    if normalized_path.startswith(dir_pattern + '/'):
                        return True
                elif fnmatch.fnmatch(normalized_path, pattern):
                    return True
            return False
        except Exception as e:
            RichLogger.exception(f"Error in _should_exclude for file {file_path}: {str(e)}")
            return False

    @staticmethod
    def verify_hash(file_path: Path, expected_hash: str) -> bool:
        """
        Perform SHA256 hash verification on a file with comprehensive error reporting.

        Computes the cryptographic hash of the specified file and compares it against
        the expected value. Provides detailed logging for mismatch scenarios and
        file access errors.

        Args:
            file_path: Path object pointing to the file for hash verification
            expected_hash: Expected SHA256 hash value in hexadecimal format

        Returns:
            bool: True if hash matches or no expected hash provided, False on 
                  mismatch, file not found, or read errors
        """
        try:
            if not expected_hash:
                return True

            if not file_path.exists():
                RichLogger.error(f"File not found: {file_path}")
                return False

            hash_func = hashlib.sha256()
            chunk_size = 131072
            with open(file_path, "rb") as f:
                while True:
                    chunk = f.read(chunk_size)
                    if not chunk:
                        break
                    hash_func.update(chunk)
            actual_hash = hash_func.hexdigest()

            if actual_hash == expected_hash:
                return True
            else:
                RichLogger.error(f"Hash mismatch for file: {file_path}")
                RichLogger.error(f"Expected: {expected_hash}")
                RichLogger.error(f"Actual: {actual_hash}")
                return False
        except Exception as e:
            RichLogger.exception(f"Hash verification failed for {file_path}: {str(e)}")
            return False

    @staticmethod
    def extract(
        archive_path: Path,
        target_dir: Path,
        extract_path: Optional[str] = None,
        remove_archive: bool = False,
        include: Optional[List[str]] = None,
        exclude: Optional[List[str]] = None
    ) -> bool:
        """
        Extract archive contents to target directory with advanced filtering options.

        Supports multiple archive formats (ZSTD, ZIP, TAR) with pattern-based
        inclusion/exclusion filtering. Handles path normalization, security checks,
        and optional archive cleanup after successful extraction.

        Args:
            archive_path: Source archive file to extract
            target_dir: Destination directory for extracted contents
            extract_path: Optional subpath within archive to extract (partial extraction)
            remove_archive: If True, deletes source archive after successful extraction
            include: List of glob patterns specifying files to include (None for all)
            exclude: List of glob patterns specifying files to exclude

        Returns:
            bool: True if extraction completed successfully, False on any error
        """
        try:
            if not archive_path.exists():
                RichLogger.error(f"Archive not found: {archive_path}")
                return False

            if not target_dir.exists():
                try:
                    target_dir.mkdir(parents=True, exist_ok=True)
                except Exception as e:
                    RichLogger.exception(f"Failed to create target directory {target_dir}: {str(e)}")
                    return False

            archive_ext = archive_path.suffix.lower()
            if archive_ext in [".zst", ".zstd"]:
                success = ArchiveHandler._extract_zstd(archive_path, target_dir, extract_path, include, exclude)
            elif archive_ext == ".zip":
                success = ArchiveHandler._extract_zip(archive_path, target_dir, extract_path, include, exclude)
            else:
                success = ArchiveHandler._extract_tar(archive_path, target_dir, extract_path, include, exclude)

            if success and remove_archive:
                try:
                    archive_path.unlink()
                except Exception as e:
                    RichLogger.exception(f"Failed to remove archive {archive_path}: {str(e)}")

            return success
        except Exception as e:
            RichLogger.exception(f"Archive extraction failed for {archive_path}: {str(e)}")
            return False

    @staticmethod
    def _extract_zstd(
        archive_path: Path,
        target_dir: Path,
        extract_path: Optional[str],
        include: Optional[List[str]],
        exclude: Optional[List[str]]
    ) -> bool:
        """
        Extract Zstandard-compressed TAR archive with filtering capabilities.

        Decompresses ZSTD stream and processes embedded TAR archive with
        pattern-based file selection and security validation.

        Args:
            archive_path: Path to ZSTD compressed archive file
            target_dir: Destination directory for extracted files
            extract_path: Optional subdirectory within archive to extract
            include: List of patterns for file inclusion filtering
            exclude: List of patterns for file exclusion filtering

        Returns:
            bool: True if extraction successful and files were extracted, False otherwise
        """
        try:
            dctx = zstd.ZstdDecompressor()

            with open(archive_path, "rb") as fh:
                stream_reader = dctx.stream_reader(fh)
                tar_buffer = io.BytesIO(stream_reader.read())

                with tarfile.open(fileobj=tar_buffer, mode="r:") as tar:
                    extracted_count = 0
                    base_path = ArchiveHandler._determine_base_path(tar, extract_path)
                    for member in tar.getmembers():
                        try:
                            if member.isdir():
                                continue
                            member_path = member.name.replace('\\', '/')

                            if base_path and not member_path.startswith(base_path):
                                continue

                            if ArchiveHandler._is_unsafe_path(member_path):
                                continue

                            if exclude and ArchiveHandler._should_exclude(member_path, exclude):
                                continue

                            if include:
                                matched = False
                                for pattern in include:
                                    if fnmatch.fnmatch(member_path, pattern):
                                        matched = True
                                        break
                                if not matched:
                                    continue

                            if base_path and member_path.startswith(base_path):
                                relative_path = member_path[len(base_path):]
                            else:
                                relative_path = member_path

                            relative_path = ArchiveHandler._normalize_path(relative_path)
                            if not relative_path:
                                continue

                            member.name = relative_path

                            tar.extract(member, path=str(target_dir))
                            extracted_count += 1
                        except Exception as e:
                            RichLogger.exception(f"Failed to extract member {member.name}: {str(e)}")
                            continue
                    return extracted_count > 0

        except zstd.ZstdError as e:
            RichLogger.exception(f"ZST decompression failed: {str(e)}")
            return False
        except tarfile.TarError as e:
            RichLogger.exception(f"Tar extraction failed: {str(e)}")
            return False
        except Exception as e:
            RichLogger.exception(f"Unexpected error during ZSTD extraction: {str(e)}")
            return False

    @staticmethod
    def _extract_zip(
        archive_path: Path,
        target_dir: Path,
        extract_path: Optional[str],
        include: Optional[List[str]],
        exclude: Optional[List[str]]
    ) -> bool:
        """
        Extract ZIP archive contents with pattern filtering and security checks.

        Processes ZIP format archives with support for partial extraction and
        selective file inclusion/exclusion based on glob patterns.

        Args:
            archive_path: Path to ZIP archive file
            target_dir: Destination directory for extracted contents
            extract_path: Optional path within archive to limit extraction scope
            include: List of glob patterns for file inclusion
            exclude: List of glob patterns for file exclusion

        Returns:
            bool: True if successful extraction occurred, False on errors or no files matched
        """
        try:
            with zipfile.ZipFile(archive_path, "r") as zip_ref:
                base_path = ArchiveHandler._determine_base_path(zip_ref, extract_path)
                extracted_count = 0

                for member in zip_ref.infolist():
                    try:
                        if member.is_dir():
                            continue
                        full_archive_path = member.filename.replace('\\', '/')
                        if base_path and not full_archive_path.startswith(base_path):
                            continue

                        if exclude and ArchiveHandler._should_exclude(full_archive_path, exclude):
                            continue

                        if include:
                            matched = False
                            for pattern in include:
                                if fnmatch.fnmatch(full_archive_path, pattern):
                                    matched = True
                                    break
                            if not matched:
                                continue

                        if base_path and full_archive_path.startswith(base_path):
                            relative_path = full_archive_path[len(base_path):]
                        else:
                            relative_path = full_archive_path

                        relative_path = ArchiveHandler._normalize_path(relative_path)
                        if not relative_path:
                            continue

                        member.filename = relative_path

                        zip_ref.extract(member, path=str(target_dir))
                        extracted_count += 1
                    except Exception as e:
                        RichLogger.exception(f"Failed to extract member {member.filename}: {str(e)}")
                        continue
                return extracted_count > 0

        except Exception as e:
            RichLogger.exception(f"Failed to extract ZIP archive {archive_path}: {str(e)}")
            return False

    @staticmethod
    def _extract_tar(
        archive_path: Path,
        target_dir: Path,
        extract_path: Optional[str],
        include: Optional[List[str]],
        exclude: Optional[List[str]]
    ) -> bool:
        """
        Extract TAR archive (including compressed variants) with filtering.

        Handles various TAR formats (compressed with gzip, bzip2, etc.) with
        comprehensive file filtering and security path validation.

        Args:
            archive_path: Path to TAR archive file (any supported compression)
            target_dir: Target directory for extracted files
            extract_path: Optional subpath within archive for partial extraction
            include: List of patterns for file inclusion
            exclude: List of patterns for file exclusion

        Returns:
            bool: True if files were successfully extracted, False on errors or no matches
        """
        try:
            with tarfile.open(archive_path, "r:*") as tar_ref:
                members = tar_ref.getmembers()
                base_path = ArchiveHandler._determine_base_path(tar_ref, extract_path)
                extracted_count = 0

                for member in members:
                    try:
                        if not member.isfile():
                            continue
                        full_archive_path = member.name.replace('\\', '/')
                        if base_path and not full_archive_path.startswith(base_path):
                            continue

                        if exclude and ArchiveHandler._should_exclude(full_archive_path, exclude):
                            continue

                        if ArchiveHandler._is_unsafe_path(full_archive_path):
                            continue

                        if include:
                            matched = False
                            for pattern in include:
                                if fnmatch.fnmatch(full_archive_path, pattern):
                                    matched = True
                                    break
                            if not matched:
                                continue

                        if base_path and full_archive_path.startswith(base_path):
                            relative_path = full_archive_path[len(base_path):]
                        else:
                            relative_path = full_archive_path

                        relative_path = ArchiveHandler._normalize_path(relative_path)
                        if not relative_path:
                            continue

                        member.name = relative_path

                        tar_ref.extract(member, path=str(target_dir))
                        extracted_count += 1
                    except Exception as e:
                        RichLogger.exception(f"Failed to extract member {member.name}: {str(e)}")
                        continue
                return extracted_count > 0

        except Exception as e:
            RichLogger.exception(f"Failed to extract TAR archive {archive_path}: {str(e)}")
            return False

    @staticmethod
    def _is_unsafe_path(path: str) -> bool:
        """
        Validate path for potential security risks and unsafe patterns.

        Detects various path-based security vulnerabilities including:
        - Absolute paths
        - Directory traversal sequences (..)
        - Windows reserved device names
        - Network paths and UNC references
        - User home directory references

        Args:
            path: File path string to validate for safety

        Returns:
            bool: True if path contains potentially unsafe elements, False if safe
        """
        try:
            if path.startswith("/"):
                return True
            if re.match(r"^[a-zA-Z]:\\", path) or path.startswith("\\\\"):
                return True
            if ".." in path or path.startswith("~"):
                return True
            if re.search(r"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)", path, re.IGNORECASE):
                return True
            return False
        except Exception as e:
            RichLogger.exception(f"Error in _is_unsafe_path for path {path}: {str(e)}")
            return True

    @staticmethod
    def _normalize_path(original_path: str) -> str:
        """
        Normalize file path and perform security validation.

        Converts path separators to unified format, removes unsafe leading characters,
        and validates against path traversal and other security concerns.

        Args:
            original_path: Raw path string from archive entry

        Returns:
            str: Normalized and validated path, or empty string if path is unsafe
        """
        try:
            normalized_path = original_path.replace('\\', '/')
            normalized_path = normalized_path.lstrip('/')

            if ArchiveHandler._is_unsafe_path(normalized_path):
                return ""
            return normalized_path
        except Exception as e:
            RichLogger.exception(f"Error in _normalize_path for path {original_path}: {str(e)}")
            return ""

    @staticmethod
    def _determine_base_path(archive, extract_path: Optional[str]) -> str:
        """
        Determine appropriate base extraction path within archive structure.

        Analyzes archive contents to identify the appropriate root path for extraction,
        either based on explicit extract_path parameter or by auto-detecting
        common archive structures with single top-level directories.

        Args:
            archive: Archive object (ZipFile or TarFile) to analyze
            extract_path: Optional explicit path to use as extraction root

        Returns:
            str: Normalized base path for extraction (with trailing slash), 
                 or empty string for flat extraction
        """
        try:
            if extract_path:
                normalized_path = extract_path.replace('\\', '/').strip('/') + '/'
                if isinstance(archive, zipfile.ZipFile):
                    all_items = [info.filename for info in archive.infolist()]
                elif isinstance(archive, tarfile.TarFile):
                    all_items = [member.name for member in archive.getmembers()]
                else:
                    all_items = []

                matching_items = [item for item in all_items if item.replace('\\', '/').startswith(normalized_path)]
                if not matching_items:
                    RichLogger.warning(f"No items in archive match extract path: {normalized_path}")
                return normalized_path

            if isinstance(archive, zipfile.ZipFile):
                all_items = [info.filename for info in archive.infolist()]
            elif isinstance(archive, tarfile.TarFile):
                all_items = [member.name for member in archive.getmembers()]
            else:
                return ""

            if not all_items:
                return ""

            top_level_items = set()
            for path in all_items:
                clean_path = path.replace('\\', '/').lstrip('/')
                parts = clean_path.split('/')
                if parts:
                    top_level = parts[0]
                    if top_level == '__MACOSX':
                        continue
                    top_level_items.add(top_level)

            non_hidden_dirs = []
            for item in top_level_items:
                is_directory = any(
                    len(p.split('/')) > 1 and p.split('/')[0] == item
                    for p in all_items
                )
                if is_directory:
                    non_hidden_dirs.append(item)

            if len(non_hidden_dirs) == 1:
                base_dir = non_hidden_dirs[0]
                return f"{base_dir}/"

            return ""
        except Exception as e:
            RichLogger.exception(f"Error in _determine_base_path: {str(e)}")
            return ""
