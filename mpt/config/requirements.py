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
            config_path = resources.files("mpt.config") / "requirements.yaml"
            with resources.as_file(config_path) as path:
                config = BaseConfig._load_yaml_config(path, "requirements.yaml")
        else:
            # Fallback for older Python versions
            with resources.path("mpt.config", "requirements.yaml") as path:
                config = BaseConfig._load_yaml_config(path, "requirements.yaml")

        if config:
            deps = config.get('dependencies', [])
            RichLogger.debug(f"Loaded [bold cyan]{len(deps)}[/bold cyan] dependencies from requirements.yaml")
            return deps

        RichLogger.warning("No dependencies found in requirements.yaml")
        return []
