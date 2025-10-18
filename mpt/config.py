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
from mpt.log import RichLogger
from mpt.yaml import YamlUtils


class UserConfig:
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
            config = YamlUtils.load(config_path, "user settings")
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
            return YamlUtils.dump(config_path, merged_config, "user settings")
        except Exception as e:
            RichLogger.exception(
                f"Unexpected error saving user configuration: [bold yellow]{e}[/bold yellow]"
            )
            return False

    @staticmethod
    def get_prefix(arch: str, lib: str) -> Path:
        """
        Retrieve the installation prefix path for a specific library and architecture.

        Looks up the configured prefix path for the given library and architecture
        from the user settings. If no custom prefix is defined in settings.yaml,
        falls back to the default installation directory within the project.

        Args:
            arch: Target architecture (e.g., 'x64', 'x86')
            lib: Name of the library whose prefix path should be retrieved

        Returns:
            Path object representing the installation directory for the specified
            library and architecture

        Algorithm:
            1. Load user configuration from settings.yaml
            2. Navigate through the prefix configuration hierarchy (prefix -> arch -> lib)
            3. Return custom prefix if defined in user configuration
            4. Fall back to default path (ROOT_DIR / 'installed' / arch) if not configured
        """
        config = UserConfig.load()

        # Check if prefix configuration exists and has the specified architecture
        prefix_config = config.get('prefix', {})
        if arch in prefix_config:
            arch_prefixes = prefix_config[arch]
            # Return custom prefix if defined for the specific library
            if lib in arch_prefixes:
                custom_prefix = Path(arch_prefixes[lib])
                return custom_prefix

        # Fall back to default installation directory
        default_prefix = ROOT_DIR / 'installed' / arch
        return default_prefix

    @staticmethod
    def get_prefixs(arch: str) -> Dict[str, Path]:
        """
        Retrieve all defined prefix paths for a specific architecture.

        Extracts the complete mapping of library names to their prefix paths
        for the given architecture from the user configuration. Returns an
        empty dictionary if no prefixes are defined for the specified architecture.

        Args:
            arch: Target architecture (e.g., 'x64', 'x86') whose prefix mappings should be retrieved

        Returns:
            Dictionary mapping library names to their configured Path objects for the specified architecture,
            or empty dictionary if no prefixes are defined

        Algorithm:
            1. Load user configuration from settings.yaml
            2. Extract prefix configuration for the specified architecture
            3. Convert all string paths to Path objects for consistent interface
            4. Return complete mapping of library prefixes
        """
        config = UserConfig.load()

        # Navigate to the architecture-specific prefix configuration
        prefix_config = config.get('prefix', {})
        arch_prefixes = prefix_config.get(arch, {})

        # Convert all string paths to Path objects
        result = {lib: Path(path) for lib, path in arch_prefixes.items()}

        RichLogger.debug(
            f"Retrieved [bold cyan]{len(result)}[/bold cyan] prefix mappings "
            f"for architecture [bold cyan]{arch}[/bold cyan]"
        )
        return result


class LibraryConfig:
    """
    Specialized configuration manager for library definitions and metadata.

    Handles the loading and management of library-specific configuration files
    located in the ports directory. Supports both individual library configuration
    access and bulk loading of all available library configurations.
    """

    @staticmethod
    def load(lib: str) -> Optional[Dict[str, Any]]:
        """
        Load configuration for a specific library from its port directory.

        Retrieves and parses the config.yaml file for the specified library, providing
        access to build instructions, dependency information, and library metadata.
        Handles missing or malformed configuration files with appropriate error logging.

        Args:
            lib: Name of the library whose configuration should be loaded

        Returns:
            Dictionary containing library configuration data, or None if not found or invalid
        """
        try:
            config_path = ROOT_DIR / 'ports' / lib / 'config.yaml'
            return YamlUtils.load(config_path, f"{lib}")
        except Exception as e:
            RichLogger.exception(
                f"Unexpected error loading configuration for library [bold red]{lib}[/bold red]. "
                f"Error: [bold yellow]{e}[/bold yellow]"
            )
            return None

    @staticmethod
    def load_all() -> Dict[str, Dict[str, Any]]:
        """
        Discover and load configurations for all available libraries in the ports directory.

        Performs a comprehensive scan of the ports directory, identifying all
        valid library configurations and loading them into a unified dictionary structure.
        Provides detailed logging of the discovery process and any configuration issues.

        Returns:
            Dictionary mapping library names to their configuration dictionaries,
            or an empty dictionary if no valid configurations are found

        Algorithm:
            1. Validate existence and accessibility of ports directory
            2. Iterate through all subdirectories representing potential libraries
            3. Attempt to load configuration from each library's config.yaml file
            4. Collect successfully loaded configurations with appropriate error reporting
            5. Return comprehensive mapping of library names to configuration data
        """
        try:
            ports_dir = ROOT_DIR / 'ports'
            libs = {}
            libs_dirs = [d for d in ports_dir.iterdir() if d.is_dir()]
            RichLogger.debug(f"Found [bold cyan]{len(libs_dirs)}[/bold cyan] potential library directories")

            for lib_dir in libs_dirs:
                lib_name = lib_dir.name
                config = LibraryConfig.load(lib_name)
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
                f"Unexpected error occurred while loading all library configurations: [bold yellow]{e}[/bold yellow]"
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
            config_path = ROOT_DIR / 'ports' / lib / 'config.yaml'
            # Directly write the provided config data without merging
            return YamlUtils.dump(config_path, config_data, f"{lib} library configuration")
        except Exception as e:
            RichLogger.exception(
                f"Unexpected error saving configuration for library [bold red]{lib}[/bold red]. "
                f"Error: [bold yellow]{e}[/bold yellow]"
            )
            return False


class RequirementsConfig:
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
                config = YamlUtils.load(path, "requirements.yaml")
        else:
            # Fallback for older Python versions
            with resources.path("mpt.resources", "requirements.yaml") as path:
                config = YamlUtils.load(path, "requirements.yaml")

        if config:
            deps = config.get('dependencies', [])
            RichLogger.debug(f"Loaded [bold cyan]{len(deps)}[/bold cyan] dependencies from requirements.yaml")
            return deps

        RichLogger.warning("No dependencies found in requirements.yaml")
        return []
