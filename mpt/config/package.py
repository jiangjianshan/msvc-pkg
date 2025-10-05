# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
import yaml
from importlib import resources
from pathlib import Path
from typing import Dict, List, Optional, Any, Union

from mpt import ROOT_DIR
from mpt.config.base import BaseConfig
from mpt.core.log import RichLogger


class PackageConfig(BaseConfig):
    """
    Specialized configuration manager for library package definitions and metadata.

    Handles the loading and management of library-specific configuration files
    located in the packages directory. Supports both individual library configuration
    access and bulk loading of all available package configurations.
    """

    @staticmethod
    def load(lib: str) -> Optional[Dict[str, Any]]:
        """
        Load configuration for a specific library from its package directory.

        Retrieves and parses the config.yaml file for the specified library, providing
        access to build instructions, dependency information, and package metadata.
        Handles missing or malformed configuration files with appropriate error logging.

        Args:
            lib: Name of the library whose configuration should be loaded

        Returns:
            Dictionary containing library configuration data, or None if not found or invalid
        """
        try:
            config_path = ROOT_DIR / 'packages' / lib / 'config.yaml'
            return BaseConfig._load_yaml_config(config_path, f"{lib}")
        except Exception as e:
            RichLogger.exception(
                f"Unexpected error loading configuration for library [bold red]{lib}[/bold red]. "
                f"Error: [bold yellow]{e}[/bold yellow]"
            )
            return None

    @staticmethod
    def load_all() -> Dict[str, Dict[str, Any]]:
        """
        Discover and load configurations for all available libraries in the packages directory.

        Performs a comprehensive scan of the packages directory, identifying all
        valid library configurations and loading them into a unified dictionary structure.
        Provides detailed logging of the discovery process and any configuration issues.

        Returns:
            Dictionary mapping library names to their configuration dictionaries,
            or an empty dictionary if no valid configurations are found

        Algorithm:
            1. Validate existence and accessibility of packages directory
            2. Iterate through all subdirectories representing potential libraries
            3. Attempt to load configuration from each library's config.yaml file
            4. Collect successfully loaded configurations with appropriate error reporting
            5. Return comprehensive mapping of library names to configuration data
        """
        try:
            pkgs_dir = ROOT_DIR / 'packages'
            if not pkgs_dir.exists():
                RichLogger.critical(
                    f"Packages directory not found: [bold red]{pkgs_dir}[/bold red]. "
                    f"Please check your installation."
                )
                return {}
            if not pkgs_dir.is_dir():
                RichLogger.critical(
                    f"Packages path is not a directory: [bold red]{pkgs_dir}[/bold red]. "
                    f"Please check your installation."
                )
                return {}

            libs = {}
            libs_dirs = [d for d in pkgs_dir.iterdir() if d.is_dir()]
            RichLogger.debug(f"Found [bold cyan]{len(libs_dirs)}[/bold cyan] potential library directories")

            for lib_dir in libs_dirs:
                lib_name = lib_dir.name
                config = PackageConfig.load(lib_name)
                if config:
                    libs[lib_name] = config
                else:
                    RichLogger.warning(
                        f"No valid configuration found for library: [bold yellow]{lib_name}[/bold yellow] "
                        f"in directory: [cyan]{lib_dir}[/cyan]"
                    )

            RichLogger.info(f"Loaded configurations for [bold green]{len(libs)}[/bold green] out of [bold cyan]{len(libs_dirs)}[/bold cyan] libraries")
            return libs
        except Exception as e:
            RichLogger.exception(
                f"Unexpected error occurred while loading all package configurations: [bold yellow]{e}[/bold yellow]"
            )
            return {}

    @staticmethod
    def dump(lib: str, config_data: Dict[str, Any]) -> bool:
        """
        Persist library configuration changes to the library's config file with proper merging.

        Writes updated configuration values to the library's config.yaml file while preserving
        existing unspecified settings. Implements a merge strategy that combines new
        values with existing configuration to prevent accidental data loss.

        Args:
            lib: Name of the library whose configuration should be updated
            config_data: Dictionary containing configuration updates to persist

        Returns:
            Boolean indicating successful persistence of configuration changes
        """
        try:
            config_path = ROOT_DIR / 'packages' / lib / 'config.yaml'
            # Load existing config first to preserve other settings
            existing_config = PackageConfig.load(lib) or {}
            # Merge new data with existing config
            merged_config = {**existing_config, **config_data}
            return BaseConfig._dump_yaml_config(config_path, merged_config, f"{lib} library configuration")
        except Exception as e:
            RichLogger.exception(
                f"Unexpected error saving configuration for library [bold red]{lib}[/bold red]. "
                f"Error: [bold yellow]{e}[/bold yellow]"
            )
            return False
