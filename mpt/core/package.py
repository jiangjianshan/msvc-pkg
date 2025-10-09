# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#

from pathlib import Path
from rich.prompt import Prompt, Confirm, IntPrompt
from typing import Dict, List, Optional, Union

from mpt import ROOT_DIR
from mpt.core.log import RichLogger
from mpt.core.source import SourceManager
from mpt.core.config import PackageConfig
from mpt.utils.file import FileUtils

class PackageManager:
    """Handles interactive generation of package configuration files."""

    @staticmethod
    def add_library(lib: str):
        """
        Interactively creates config.yaml for a new library package.

        Args:
            lib (str): Library name (must match directory name in packages/)
        """
        # Create package directory using pathlib
        pkg_dir = ROOT_DIR / 'packages' / lib
        pkg_dir.mkdir(parents=True, exist_ok=True)

        # Initialize config dictionary
        config: Dict[str, Union[str, bool, int, Dict, List]] = {
            "name": lib
        }

        # Collect basic information
        config['version'] = Prompt.ask("Enter library version", default="1.0.0")
        config['url'] = Prompt.ask("Enter source URL (download/clone)")

        # Process common source configuration
        PackageManager._process_source_config(config, lib)
        # Process extra resources
        PackageManager._process_extras(config)
        # Process dependencies
        PackageManager._process_dependencies(config)
        # Process build script selection
        PackageManager._process_run(config)
        if not PackageConfig.dump(lib, config):
            RichLogger.error(f"Failed to save configuration for library [bold red]{lib}[/bold red]")
            return
        RichLogger.debug(f"[SUCCESS] Configuration created at {pkg_dir / 'config.yaml'}")

    @staticmethod
    def remove_library(lib: str) -> bool:
        """
        Remove a library package configuration and directory.

        Args:
            lib (str): Library name (must match directory name in packages/)

        Returns:
            bool: True if removal was successful, False otherwise
        """
        try:
            # Create package directory path using pathlib
            pkg_dir = ROOT_DIR / 'packages' / lib

            # Check if directory exists
            if not pkg_dir.exists():
                RichLogger.error(f"Library [bold red]{lib}[/bold red] does not exist")
                return False

            # Confirm removal with user
            if not Confirm.ask(f"Are you sure you want to remove library [bold red]{lib}[/bold red]?"):
                RichLogger.info(f"Library removal cancelled for [cyan]{lib}[/cyan]")
                return False

            # Remove directory and all contents
            FileUtils.force_delete_directory(pkg_dir)

            RichLogger.info(f"Successfully removed library [cyan]{lib}[/cyan]")
            return True
        except Exception as e:
            RichLogger.exception(f"Error removing library {lib}: {str(e)}")
            return False

    @staticmethod
    def _collect_source_info(source_name: str) -> Dict:
        """
        Collect common source information for both main and extra sources.

        Args:
            source_name (str): Name of the source (for prompting)

        Returns:
            Dict: Dictionary containing collected source info
        """
        info = {
            "name": source_name,
            "version": Prompt.ask(f"Enter version for {source_name}", default="1.0.0"),
            "url": Prompt.ask(f"Enter URL for {source_name}")
        }
        return info

    @staticmethod
    def _process_source_config(source_config: Dict, source_name: str):
        """
        Process common source configuration for both main and extra sources.

        Args:
            source_config (Dict): Source configuration dictionary to update
            source_name (str): Name of the source (for prompting)
        """
        # For Git sources, add Git-specific options
        if SourceManager.is_git_url(source_config["url"]):
            source_config['recursive'] = Confirm.ask(
                f"Does {source_name} have submodules?", default=False)
            source_config['depth'] = IntPrompt.ask(
                f"Set Git depth for {source_name}", default=1)

            # Process submodules for Git sources
            if source_config.get('recursive', False) and Confirm.ask(f"Configure submodules for {source_name}?"):
                source_config['submodules'] = {}
                while True:
                    sub_name = Prompt.ask(f"Enter submodule name for {source_name} (leave blank to finish)")
                    if not sub_name:
                        break
                    source_config['submodules'][sub_name] = {
                        'url': Prompt.ask(f"Enter Git URL for {sub_name}"),
                        'branch': Prompt.ask(f"Enter branch for {sub_name}", default="main")
                    }
        else:
            # For non-Git sources, collect SHA256
            source_config['sha256'] = Prompt.ask(f"Enter SHA256 checksum for {source_name}")

    @staticmethod
    def _process_extras(config: Dict):
        """Process extra resources configuration."""
        if Confirm.ask("Add extra resources?"):
            config['extras'] = []
            while True:
                extra_name = Prompt.ask("Enter extra resource name (leave blank to finish)")
                if not extra_name:
                    break
                # Collect common source info
                extra = PackageManager._collect_source_info(extra_name)
                # Process common source configuration
                PackageManager._process_source_config(extra, extra_name)
                # Add extra-specific fields
                extra['target'] = Prompt.ask(f"Enter target path for {extra_name}")
                # Only add check field if user provides input
                check_input = Prompt.ask(f"Enter existence check command for {extra_name}", default="")
                if check_input:
                    extra['check'] = check_input

                config['extras'].append(extra)

    @staticmethod
    def _process_dependencies(config: Dict):
        """Process dependencies configuration."""
        if Confirm.ask("Add dependencies?"):
            config['dependencies'] = {}

            # Required dependencies
            req_deps = Prompt.ask("Enter required dependencies (comma separated)", default="")
            if req_deps.strip():
                config['dependencies']['required'] = [d.strip() for d in req_deps.split(",") if d.strip()]

            # Optional dependencies
            opt_deps = Prompt.ask("Enter optional dependencies (comma separated)", default="")
            if opt_deps.strip():
                config['dependencies']['optional'] = [d.strip() for d in opt_deps.split(",") if d.strip()]

    @staticmethod
    def _process_run(config: Dict):
        """Process build script configuration."""
        # Present options for build script selection
        RichLogger.info("\nSelect build script type:")
        RichLogger.info("1. No build script (empty)")
        RichLogger.info("2. Windows batch file (build.bat)")
        RichLogger.info("3. Unix shell script (build.sh)")
        choice = IntPrompt.ask("Enter your choice (1-3)", default=1, choices=["1", "2", "3"])
        if choice == 1:
            config['run'] = ""  # Empty script
        elif choice == 2:
            config['run'] = "build.bat"  # Windows batch file
        elif choice == 3:
            config['run'] = "build.sh"  # Unix shell script
        RichLogger.debug(f"Selected build script: {config['run']}")
