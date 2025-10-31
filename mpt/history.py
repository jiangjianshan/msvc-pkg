# -*- coding: utf-8 -*-
"""
History manager module for tracking library installation records per triplet

Copyright (c) 2024 Jianshan Jiang

"""

from datetime import datetime
from pathlib import Path

from mpt import ROOT_DIR
from mpt.log import RichLogger
from mpt.yaml import YamlUtils


class HistoryManager:
    """Manages installation history records for libraries with per-triplet storage.

    Provides comprehensive tracking of library installations across different triplets,
    including version information, build timestamps. Maintains persistent records in
    separate YAML files for each triplet for better organization.
    """

    @classmethod
    def _get_record_path(cls, triplet: str) -> Path:
        """
        Retrieve the filesystem path to the installation history storage file for a specific triplet.

        Args:
            triplet: Target triplet identifier (e.g., 'x64-windows')

        Returns:
            Path: Absolute filesystem path to the triplet-specific installation history YAML file
        """
        try:
            return ROOT_DIR / 'installed' / 'info' / triplet / 'status.yaml'
        except Exception as e:
            RichLogger.exception(f"Error getting record path for triplet {triplet}: {e}")
            raise

    @classmethod
    def _load_records(cls, triplet: str) -> dict:
        """
        Load installation records from triplet-specific YAML storage with error handling.

        Args:
            triplet: Target triplet identifier

        Returns:
            dict: Nested dictionary structure containing installation records for the triplet,
                  or empty dictionary if file doesn't exist or errors occur
        """
        record_path = cls._get_record_path(triplet)
        if not record_path.exists():
            return {}
        records = YamlUtils.load(record_path, f"status.yaml") or {}
        return records

    @classmethod
    def _save_records(cls, triplet: str, records: dict) -> bool:
        """
        Persist installation records to triplet-specific YAML storage.

        Args:
            triplet: Target triplet identifier
            records: Complete installation records structure to persist for the triplet

        Returns:
            bool: True if records were successfully written to disk, False on any error
        """
        record_path = cls._get_record_path(triplet)
        record_path.parent.mkdir(parents=True, exist_ok=True)
        return YamlUtils.dump(record_path, records, f"status.yaml", sort_keys=True)

    @classmethod
    def add_record(cls, triplet: str, node_name: str, version: str) -> bool:
        """
        Create or update an installation record for a specific library node and triplet.

        Args:
            triplet: Target triplet identifier (e.g., 'x64-windows')
            node_name: Library node identifier with optional dependency type
            version: Version string of the installed library

        Returns:
            bool: True if record was successfully created or updated, False on error
        """
        try:
            records = cls._load_records(triplet)

            # Initialize library record if it doesn't exist
            if node_name not in records:
                records[node_name] = {}

            records[node_name] = {
                'version': version,
                'built': datetime.now()
            }

            success = cls._save_records(triplet, records)
            if not success:
                RichLogger.error(f"[[bold red]{node_name}[/bold red]] Failed to add record for library on triplet [magenta]{triplet}[/magenta]")
            else:
                RichLogger.info(f"[[bold green]{node_name}[/bold green]] Successfully added installation record for triplet [magenta]{triplet}[/magenta]")
            return success
        except Exception as e:
            RichLogger.exception(f"Error adding record for {node_name} on {triplet}: {e}")
            return False

    @classmethod
    def remove_record(cls, triplet: str, node_name: str) -> bool:
        """
        Remove installation record for a specific library node and triplet.

        Args:
            triplet: Target triplet identifier from which to remove the record
            node_name: Library node identifier to remove from history

        Returns:
            bool: True if record was removed or didn't exist, False on persistence error
        """
        try:
            records = cls._load_records(triplet)
            if not records:
                return True

            if node_name in records:
                # Remove the specific library record
                del records[node_name]
                success = cls._save_records(triplet, records)
                if success:
                    RichLogger.info(f"[[bold green]{node_name}[/bold green]] Successfully removed installation record for triplet [magenta]{triplet}[/magenta]")
                return success
            return True
        except Exception as e:
            RichLogger.exception(f"Error removing record for {node_name} on {triplet}: {e}")
            return False

    @classmethod
    def check_installed(cls, triplet: str, node_name: str) -> bool:
        """
        Verify if a specific library node is installed for a given triplet.

        Args:
            triplet: Target triplet to check for installation
            node_name: Library node identifier to verify installation status

        Returns:
            bool: True if library node is recorded as installed for the triplet,
                  False otherwise
        """
        try:
            records = cls._load_records(triplet)
            return node_name in records
        except Exception as e:
            RichLogger.exception(f"Error checking installation status for {node_name} on {triplet}: {e}")
            return False

    @classmethod
    def check_for_update(cls, triplet: str, node_name: str, config: dict) -> bool:
        """
        Determine if a library node requires updating based on version comparison.

        Args:
            triplet: Target triplet for version comparison
            node_name: Library node identifier to check for updates
            config: Current library configuration containing target version

        Returns:
            bool: True if an update is required (version mismatch or not installed),
                  False if current installation matches target version
        """
        try:
            # Check if library node is installed
            installed = cls.check_installed(triplet, node_name)
            if not installed:
                return True

            # Get library node information
            lib_info = cls.get_library_info(triplet, node_name)
            if not lib_info:
                return True

            # Compare versions
            current_version = config.get('version', 'unknown')
            if current_version != lib_info.get('version'):
                return True

            return False
        except Exception as e:
            RichLogger.exception(f"Error checking for update for {node_name} on {triplet}: {e}")
            return True

    @classmethod
    def get_library_info(cls, triplet: str, node_name: str) -> dict:
        """
        Retrieve comprehensive installation information for a specific library node.

        Args:
            triplet: Target triplet from which to retrieve library information
            node_name: Library node identifier for information lookup

        Returns:
            dict: Dictionary containing version string, datetime object for build time,
                 or None if no record exists
        """
        try:
            records = cls._load_records(triplet)
            if not records or node_name not in records:
                return None

            record = records[node_name]
            result = {
                'version': record.get('version')
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
            RichLogger.exception(f"Error getting library info for {node_name} on {triplet}: {e}")
            return None

    @classmethod
    def get_triplet_records(cls, triplet: str) -> dict:
        """
        Get all records for a specific triplet.

        Args:
            triplet: Target triplet identifier

        Returns:
            dict: Dictionary of library records for the triplet, or empty dict if none
        """
        try:
            records = cls._load_records(triplet)
            return records
        except Exception as e:
            RichLogger.exception(f"Error getting records for triplet {triplet}: {e}")
            return {}
