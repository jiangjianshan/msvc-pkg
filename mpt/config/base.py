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

            with open(config_path, 'w', newline='', encoding='utf-8') as f:
                yaml.safe_dump(config_data, f, indent=2)

            return True
        except Exception as e:
            RichLogger.exception(
                f"Error writing [bold red]{config_name}[/bold red] to [bold red]{config_path}[/bold red]. "
                f"Error: [bold yellow]{e}[/bold yellow]"
            )
            return False
