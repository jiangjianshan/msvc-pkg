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
