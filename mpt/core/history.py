# -*- coding: utf-8 -*-
"""
History manager module for tracking library installation records

Copyright (c) 2024 Jianshan Jiang

"""

from datetime import datetime
from pathlib import Path

from mpt import ROOT_DIR
from mpt.core.log import RichLogger
from mpt.utils.yaml import YamlUtils


class HistoryManager:
    """Manages installation history records for libraries with version tracking and build metadata.

    Provides comprehensive tracking of library installations across different architectures,
    including version information, build timestamps, and dependency type support. Maintains
    persistent records in YAML format for reliable state management across sessions.
    """
    RECORD_FILE = ROOT_DIR / 'installed' / 'msvc-pkg' / 'status.yaml'

    @classmethod
    def _get_record_path(cls) -> Path:
        """
        Retrieve the filesystem path to the installation history storage file.

        Provides a centralized access point for the history file location, ensuring
        consistent path resolution throughout the history management system.

        Returns:
            Path: Absolute filesystem path to the installation history YAML file
        """
        try:
            return cls.RECORD_FILE
        except Exception as e:
            RichLogger.exception(f"Error getting record path: {e}")
            raise

    @classmethod
    def _load_records(cls) -> dict:
        """
        Load installation records from persistent YAML storage with error handling.

        Safely reads the history file from disk, handling various error conditions
        including missing files, permission issues, and malformed YAML content.
        Provides graceful fallback to empty records on any failure.

        Returns:
            dict: Nested dictionary structure containing installation records,
                  or empty dictionary if file doesn't exist or errors occur
        """
        record_path = cls._get_record_path()
        if not record_path.exists():
            return {}
        records = YamlUtils.load(record_path, "installed.yaml") or {}
        return records

    @classmethod
    def _save_records(cls, records: dict) -> bool:
        """
        Persist installation records to YAML storage with comprehensive error handling.

        Safely writes the complete history structure to disk, ensuring proper
        directory creation, file permissions, and data integrity. Uses YAML
        serialization with Unicode support and deterministic key ordering.

        Args:
            records (dict): Complete installation records structure to persist

        Returns:
            bool: True if records were successfully written to disk, False on any error
        """
        record_path = cls._get_record_path()
        record_path.parent.mkdir(parents=True, exist_ok=True)
        return YamlUtils.dump(record_path, records, "installed.yaml", sort_keys=True)

    @classmethod
    def add_record(cls, arch: str, node_name: str, version: str) -> bool:
        """
        Create or update an installation record for a specific library node and architecture.

        Records comprehensive installation metadata including library version,
        build timestamp, and architecture specification. Supports both new
        installations and updates to existing records with proper version tracking.

        Args:
            arch (str): Target architecture identifier (e.g., 'x64', 'x86')
            node_name (str): Library node identifier with optional dependency type
                            (e.g., "pcre:required" for required dependency)
            version (str): Version string of the installed library

        Returns:
            bool: True if record was successfully created or updated, False on error
        """
        try:
            records = cls._load_records()

            # Initialize architecture record if it doesn't exist
            if arch not in records:
                records[arch] = {}

            # Initialize library record if it doesn't exist
            if node_name not in records[arch]:
                records[arch][node_name] = {}

            records[arch][node_name] = {
                'version': version,
                'built': datetime.now(),
            }

            success = cls._save_records(records)
            if not success:
                RichLogger.error(f"[[bold red]{node_name}[/bold red]] Failed to add record for library on arch [magenta]{arch}[/magenta]")
            return success
        except Exception as e:
            RichLogger.exception(f"Error adding record for {node_name} on {arch}: {e}")
            return False

    @classmethod
    def remove_record(cls, arch: str, node_name: str) -> bool:
        """
        Remove installation record for a specific library node and architecture.

        Deletes the specified library record and performs cleanup of empty architecture
        entries to maintain data consistency. Handles non-existent records gracefully.

        Args:
            arch (str): Target architecture identifier from which to remove the record
            node_name (str): Library node identifier to remove from history

        Returns:
            bool: True if record was removed or didn't exist, False on persistence error
        """
        try:
            records = cls._load_records()
            if not records:
                return True

            if arch in records and node_name in records[arch]:
                # Remove the specific dependency type record
                del records[arch][node_name]

                # Clean up empty architecture entries
                if not records[arch]:
                    del records[arch]

                return cls._save_records(records)
            return True
        except Exception as e:
            RichLogger.exception(f"Error removing record for {node_name} on {arch}: {e}")
            return False

    @classmethod
    def check_installed(cls, arch: str, node_name: str) -> bool:
        """
        Verify if a specific library node is installed for a given architecture.

        Checks the installation history for evidence of a successful installation
        of the specified library node on the target architecture, regardless of
        version or build timestamp.

        Args:
            arch (str): Target architecture to check for installation
            node_name (str): Library node identifier to verify installation status

        Returns:
            bool: True if library node is recorded as installed for the architecture,
                  False otherwise
        """
        try:
            records = cls._load_records()
            return arch in records and node_name in records[arch]
        except Exception as e:
            RichLogger.exception(f"Error checking installation status for {node_name} on {arch}: {e}")
            return False

    @classmethod
    def check_for_update(cls, arch: str, node_name: str, config: dict) -> bool:
        """
        Determine if a library node requires updating based on version comparison.

        Compares the currently installed version (from history) with the target
        version (from configuration) to identify update requirements. Also detects
        missing installation records that would necessitate an initial installation.

        Args:
            arch (str): Target architecture for version comparison
            node_name (str): Library node identifier to check for updates
            config (dict): Current library configuration containing target version

        Returns:
            bool: True if an update is required (version mismatch or not installed),
                  False if current installation matches target version
        """
        try:
            # Check if library node is installed
            installed = cls.check_installed(arch, node_name)
            if not installed:
                return True

            # Get library node information
            lib_info = cls.get_library_info(arch, node_name)
            if not lib_info:
                return True

            # Compare versions
            current_version = config.get('version', 'unknown')
            if current_version != lib_info.get('version'):
                return True

            return False
        except Exception as e:
            RichLogger.exception(f"Error checking for update for {node_name} on {arch}: {e}")
            return True

    @classmethod
    def get_library_info(cls, arch: str, node_name: str) -> dict:
        """
        Retrieve comprehensive installation information for a specific library node.

        Extracts complete installation metadata including version, build timestamp,
        and architecture details. Handles various timestamp formats and provides
        normalized datetime objects for consistent processing.

        Args:
            arch (str): Target architecture from which to retrieve library information
            node_name (str): Library node identifier for information lookup

        Returns:
            dict: Dictionary containing version string and datetime object for build time,
                  or None if no record exists for the specified library and architecture
        """
        try:
            records = cls._load_records()
            if not records or arch not in records or node_name not in records[arch]:
                return None

            record = records[arch][node_name]
            result = {
                'version': record.get('version'),
            }

            time_val = record.get('built')
            if isinstance(time_val, datetime):
                result['built'] = time_val
            elif isinstance(time_val, str):
                result['built'] = datetime.fromisoformat(time_val)
            else:
                result['built'] = None

            return result
        except Exception as e:
            RichLogger.exception(f"Error getting library info for {node_name} on {arch}: {e}")
            return None

    @classmethod
    def get_arch_records(cls, arch: str) -> dict:
        """Get all records for a specific architecture.

        Args:
            arch: Target architecture identifier

        Returns:
            dict: Dictionary of library records for the architecture, or empty dict if none
        """
        try:
            records = cls._load_records()
            return records.get(arch, {})
        except Exception as e:
            RichLogger.exception(f"Error getting records for arch {arch}: {e}")
            return {}
