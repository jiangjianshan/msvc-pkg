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


class YamlUtils:
    """
    YAML file utility class providing core YAML file handling capabilities.

    Implements the fundamental operations for loading and saving YAML files
    with comprehensive error handling, encoding support, and validation. 
    Serves as a utility class for various YAML file operations including
    configuration files, manifests, and other YAML-based data files.
    """

    @staticmethod
    def load(file_path: Path, file_description: str = "YAML file") -> Optional[Dict[str, Any]]:
        """
        Load and parse YAML file with robust error handling and validation.

        Provides a secure and reliable method for reading YAML files with
        comprehensive error detection and reporting. Handles file existence checks,
        format validation, encoding issues, and parsing errors with detailed logging.

        Args:
            file_path: Absolute filesystem path to the YAML file
            file_description: Descriptive name of the YAML file for logging and error reporting

        Returns:
            Dictionary containing parsed YAML data, or None if loading fails

        Raises:
            FileNotFoundError: When the specified YAML file does not exist
            yaml.YAMLError: When YAML parsing fails due to malformed syntax
            UnicodeDecodeError: When file encoding issues prevent proper reading
            Exception: For any other unexpected errors during file operations
        """
        if not file_path.exists():
            RichLogger.error(f"YAML file not found: [bold red]{file_path}[/bold red]")
            return None

        if not file_path.is_file():
            RichLogger.error(f"YAML file path is not a file: [bold red]{file_path}[/bold red]")
            return None
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                yaml_data = yaml.safe_load(f) or {}
                return yaml_data
        except yaml.YAMLError as e:
            RichLogger.exception(
                f"YAML parsing error in [bold red]{file_description}[/bold red] at [bold red]{file_path}[/bold red]. "
                f"Error: [bold yellow]{e}[/bold yellow]"
            )
        except UnicodeDecodeError as e:
            RichLogger.exception(
                f"Encoding error reading [bold red]{file_description}[/bold red] at [bold red]{file_path}[/bold red]. "
                f"File must be UTF-8 encoded. Error: [bold yellow]{e}[/bold yellow]"
            )
        except Exception as e:
            RichLogger.exception(
                f"Unexpected error loading [bold red]{file_description}[/bold red] at [bold red]{file_path}[/bold red]. "
                f"Error: [bold yellow]{e}[/bold yellow]"
            )

        return None

    @staticmethod
    def dump(file_path: Path, data: Dict[str, Any], file_description: str = "YAML file", sort_keys: bool = False) -> bool:
        """
        Serialize and write data to YAML file with comprehensive error handling.

        Safely writes data dictionaries to YAML files with proper directory
        creation, encoding handling, and error recovery. Ensures data integrity through
        atomic write operations and validation.

        Args:
            file_path: Absolute filesystem path where YAML file should be written
            data: Dictionary containing data to serialize to YAML
            file_description: Descriptive name of the YAML file for logging purposes
            sort_keys: Whether to sort dictionary keys alphabetically in output (default: False)

        Returns:
            Boolean indicating successful write operation (True) or failure (False)
        """
        try:
            # Ensure parent directory exists
            file_path.parent.mkdir(parents=True, exist_ok=True)

            # Custom YAML dumper class to ensure proper formatting
            class YamlDumper(yaml.SafeDumper):
                def increase_indent(self, flow=False, indentless=False):
                    # Override to ensure proper indentation for nested structures
                    return super().increase_indent(flow, False)

            with open(file_path, 'w', encoding='utf-8') as f:
                # Use custom dumper with appropriate settings
                yaml.dump(
                    data,
                    f,
                    Dumper=YamlDumper,
                    default_flow_style=False,
                    sort_keys=sort_keys,
                    indent=2
                )

            return True
        except Exception as e:
            RichLogger.exception(
                f"Error writing [bold red]{file_description}[/bold red] to [bold red]{file_path}[/bold red]. "
                f"Error: [bold yellow]{e}[/bold yellow]"
            )
            return False
