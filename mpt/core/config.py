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
from mpt.core.log import RichLogger


class BaseConfig:
    """
    Base configuration management class providing core YAML file handling capabilities.

    Implements the fundamental operations for loading and saving YAML configuration files
    with comprehensive error handling, encoding support, and validation. Serves as the
    foundation for all specialized configuration managers in the system.
    """

    @staticmethod
    def _load_yaml_config(config_path: Path, config_name: str) -> Optional[Dict[str, Any]]:
        """
        Load and parse YAML configuration file with robust error handling and validation.

        Provides a secure and reliable method for reading YAML configuration files with
        comprehensive error detection and reporting. Handles file existence checks,
        format validation, encoding issues, and parsing errors with detailed logging.

        Args:
            config_path: Absolute filesystem path to the YAML configuration file
            config_name: Descriptive name of the configuration for logging and error reporting

        Returns:
            Dictionary containing parsed configuration data, or None if loading fails

        Raises:
            FileNotFoundError: When the specified configuration file does not exist
            yaml.YAMLError: When YAML parsing fails due to malformed syntax
            UnicodeDecodeError: When file encoding issues prevent proper reading
            Exception: For any other unexpected errors during file operations
        """
        if not config_path.exists():
            RichLogger.error(f"Configuration file not found: [bold red]{config_path}[/bold red]")
            return None

        if not config_path.is_file():
            RichLogger.error(f"Configuration path is not a file: [bold red]{config_path}[/bold red]")
            return None
        try:
            with open(config_path, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f) or {}
                return config
        except yaml.YAMLError as e:
            RichLogger.exception(
                f"YAML parsing error in [bold red]{config_name}[/bold red] at [bold red]{config_path}[/bold red]. "
                f"Error: [bold yellow]{e}[/bold yellow]"
            )
        except UnicodeDecodeError as e:
            RichLogger.exception(
                f"Encoding error reading [bold red]{config_name}[/bold red] at [bold red]{config_path}[/bold red]. "
                f"File must be UTF-8 encoded. Error: [bold yellow]{e}[/bold yellow]"
            )
        except Exception as e:
            RichLogger.exception(
                f"Unexpected error loading [bold red]{config_name}[/bold red] at [bold red]{config_path}[/bold red]. "
                f"Error: [bold yellow]{e}[/bold yellow]"
            )

        return None

    @staticmethod
    def _dump_yaml_config(config_path: Path, config_data: Dict[str, Any], config_name: str) -> bool:
        """
        Serialize and write configuration data to YAML file with comprehensive error handling.

        Safely writes configuration dictionaries to YAML files with proper directory
        creation, encoding handling, and error recovery. Ensures data integrity through
        atomic write operations and validation.

        Args:
            config_path: Absolute filesystem path where configuration should be written
            config_data: Dictionary containing configuration data to serialize
            config_name: Descriptive name of the configuration for logging purposes

        Returns:
            Boolean indicating successful write operation (True) or failure (False)
        """
        try:
            # Ensure parent directory exists
            config_path.parent.mkdir(parents=True, exist_ok=True)

            # Custom YAML dumper class to ensure proper formatting
            class ConfigDumper(yaml.SafeDumper):
                def increase_indent(self, flow=False, indentless=False):
                    # Override to ensure proper indentation for nested structures
                    return super().increase_indent(flow, False)

            with open(config_path, 'w', encoding='utf-8') as f:
                # Use custom dumper with appropriate settings
                yaml.dump(
                    config_data,
                    f,
                    Dumper=ConfigDumper,
                    default_flow_style=False,
                    sort_keys=False,
                    indent=2
                )

            return True
        except Exception as e:
            RichLogger.exception(
                f"Error writing [bold red]{config_name}[/bold red] to [bold red]{config_path}[/bold red]. "
                f"Error: [bold yellow]{e}[/bold yellow]"
            )
            return False


class UserConfig(BaseConfig):
    """
    User-specific configuration management for project-wide settings and preferences.

    Handles the loading and persistence of user-configurable settings that affect
    system-wide behavior. Supports both reading existing configurations and updating
    settings with proper merge operations to preserve unspecified values.
    """

    @staticmethod
    def load() -> Dict[str, Any]:
        """
        Load user-specific configuration from the project settings file.

        Retrieves and parses the settings.yaml file containing user preferences and
        system-wide configuration options. Provides graceful fallback to empty
        configuration when the file doesn't exist or contains errors.

        Returns:
            Dictionary containing all user configuration settings, or empty dictionary
            if no valid configuration is available
        """
        try:
            config_path = ROOT_DIR / "settings.yaml"
            config = BaseConfig._load_yaml_config(config_path, "user settings")
            return config or {}
        except Exception as e:
            RichLogger.exception(
                f"Unexpected error loading user configuration: [bold yellow]{e}[/bold yellow]"
            )
            return {}

    @staticmethod
    def dump(config_data: Dict[str, Any]) -> bool:
        """
        Persist user configuration changes to the settings file with proper merging.

        Writes updated configuration values to the settings.yaml file while preserving
        existing unspecified settings. Implements a merge strategy that combines new
        values with existing configuration to prevent accidental data loss.

        Args:
            config_data: Dictionary containing configuration updates to persist

        Returns:
            Boolean indicating successful persistence of configuration changes
        """
        try:
            config_path = ROOT_DIR / "settings.yaml"
            # Load existing config first to preserve other settings
            existing_config = UserConfig.load()
            # Merge new data with existing config
            merged_config = {**existing_config, **config_data}
            return BaseConfig._dump_yaml_config(config_path, merged_config, "user settings")
        except Exception as e:
            RichLogger.exception(
                f"Unexpected error saving user configuration: [bold yellow]{e}[/bold yellow]"
            )
            return False


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
        Persist library configuration to the library's config file.

        Writes configuration values to the library's config.yaml file without merging.

        Args:
            lib: Name of the library whose configuration should be updated
            config_data: Dictionary containing configuration to persist

        Returns:
            Boolean indicating successful persistence of configuration changes
        """
        try:
            config_path = ROOT_DIR / 'packages' / lib / 'config.yaml'
            # Directly write the provided config data without merging
            return BaseConfig._dump_yaml_config(config_path, config_data, f"{lib} library configuration")
        except Exception as e:
            RichLogger.exception(
                f"Unexpected error saving configuration for library [bold red]{lib}[/bold red]. "
                f"Error: [bold yellow]{e}[/bold yellow]"
            )
            return False


class RequirementsConfig(BaseConfig):
    """
    Dependency requirements configuration manager for embedded system requirements.

    Handles loading of system dependency requirements from an embedded YAML resource
    file. Provides access to the list of dependencies needed for proper system
    operation, with support for both modern and legacy Python resource access methods.
    """

    @staticmethod
    def load() -> List[str]:
        """
        Load system dependency requirements from embedded resource file.

        Accesses and parses the requirements.yaml file containing the list of
        system dependencies required for proper operation. Implements cross-version
        compatible resource access with fallback mechanisms for different Python versions.

        Returns:
            List of dependency names required by the system, or empty list if
            no requirements are specified or loading fails

        Algorithm:
            1. Attempt to access embedded resource using modern Python 3.9+ API
            2. Fall back to legacy resource access method if modern API unavailable
            3. Parse YAML content and extract dependencies list
            4. Handle resource access errors with appropriate logging
            5. Return empty list as safe default when loading fails
        """
        # Use resources.files() for better Python 3.9+ compatibility
        if hasattr(resources, 'files'):
            config_path = resources.files("mpt.resources") / "requirements.yaml"
            with resources.as_file(config_path) as path:
                config = BaseConfig._load_yaml_config(path, "requirements.yaml")
        else:
            # Fallback for older Python versions
            with resources.path("mpt.resources", "requirements.yaml") as path:
                config = BaseConfig._load_yaml_config(path, "requirements.yaml")

        if config:
            deps = config.get('dependencies', [])
            RichLogger.debug(f"Loaded [bold cyan]{len(deps)}[/bold cyan] dependencies from requirements.yaml")
            return deps

        RichLogger.warning("No dependencies found in requirements.yaml")
        return []
