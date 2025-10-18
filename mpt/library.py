# -*- coding: utf-8 -*-
#
# Copyright (c) 2024 Jianshan Jiang
#

import requests

from pathlib import Path
from rich.prompt import Prompt, Confirm, IntPrompt
from typing import Dict, List, Optional, Union
from urllib.parse import urljoin

from mpt import ROOT_DIR
from mpt.config import LibraryConfig
from mpt.file import FileUtils
from mpt.log import RichLogger
from mpt.source import SourceManager


class LibraryManager:
    """Handles interactive generation of library configuration files."""

    @staticmethod
    def add_library(lib: str):
        """
        Interactively creates a config.yaml file for a new library.

        Args:
            lib (str): Library name (must match the directory name under ports/)
        """
        # Create library directory using pathlib
        lib_dir = ROOT_DIR / 'ports' / lib
        lib_dir.mkdir(parents=True, exist_ok=True)

        # Initialize configuration dictionary
        config: Dict[str, Union[str, bool, int, Dict, List]] = {
            "name": lib
        }

        # Collect basic library information
        config['version'] = Prompt.ask("Enter library version", default="1.0.0")
        config['url'] = Prompt.ask("Enter source URL (for download/clone)")

        # Process common source configuration
        source_path = LibraryManager._process_source_config(config, lib)
        # Process extra resources
        LibraryManager._process_extras(config)
        # Process dependencies
        LibraryManager._process_dependencies(config)
        # Process build script selection
        LibraryManager._process_script(config, source_path)

        if not LibraryConfig.dump(lib, config):
            RichLogger.error(f"Failed to save configuration for library [bold red]{lib}[/bold red]")
            return
        RichLogger.debug(f"[SUCCESS] Configuration created at {lib_dir / 'config.yaml'}")

    @staticmethod
    def remove_library(lib: str) -> bool:
        """
        Removes a library configuration and its directory.

        Args:
            lib (str): Library name (must match the directory name under ports/)

        Returns:
            bool: True if removal was successful, False otherwise
        """
        try:
            # Create library directory path using pathlib
            lib_dir = ROOT_DIR / 'ports' / lib

            # Check if directory exists
            if not lib_dir.exists():
                RichLogger.error(f"Library [bold red]{lib}[/bold red] does not exist")
                return False

            # Confirm removal with user
            if not Confirm.ask(f"Are you sure you want to remove library [bold red]{lib}[/bold red]?"):
                RichLogger.info(f"Library removal cancelled for [cyan]{lib}[/cyan]")
                return False

            # Remove directory and all contents
            FileUtils.delete_directory(lib_dir, permanent=False)

            RichLogger.info(f"Successfully removed library [cyan]{lib}[/cyan]")
            return True
        except Exception as e:
            RichLogger.exception(f"Error removing library {lib}: {str(e)}")
            return False

    @staticmethod
    def _collect_source_info(source_name: str) -> Dict:
        """
        Collects common source information for both main and extra sources.

        Args:
            source_name (str): Name of the source (used for prompting)

        Returns:
            Dict: Dictionary containing collected source information
        """
        info = {
            "name": source_name,
            "version": Prompt.ask(f"Enter version for {source_name}", default="1.0.0"),
            "url": Prompt.ask(f"Enter URL for {source_name}")
        }
        return info

    @staticmethod
    def _get_gitmodules_url(git_url: str, branch: str = "master") -> str:
        """
        Construct the correct URL for accessing .gitmodules file from Git repository.

        Args:
            git_url: Git repository URL
            branch: Branch name (default: "master")

        Returns:
            str: URL to access .gitmodules file
        """
        # Handle GitHub repositories
        if 'github.com' in git_url:
            # Convert https://github.com/owner/repo.git to
            # https://raw.githubusercontent.com/owner/repo/branch/.gitmodules
            repo_path = git_url.replace('https://github.com/', '').replace('.git', '')
            return f"https://raw.githubusercontent.com/{repo_path}/{branch}/.gitmodules"

        # Handle GitLab repositories
        elif 'gitlab.com' in git_url:
            # Convert https://gitlab.com/owner/repo.git to
            # https://gitlab.com/owner/repo/-/raw/branch/.gitmodules
            repo_path = git_url.replace('https://gitlab.com/', '').replace('.git', '')
            return f"https://gitlab.com/{repo_path}/-/raw/{branch}/.gitmodules"

        # For other Git repositories, try to construct a reasonable URL
        else:
            # Fallback: try to access .gitmodules directly from the repo
            return urljoin(git_url, '.gitmodules')

    @staticmethod
    def _process_source_config(source_config: Dict, source_name: str) -> Optional[Path]:
        """
        Process common source configuration for both main and extra sources.

        Args:
            source_config: Source configuration dictionary to update
            source_name: Name of the source (for prompting)

        Returns:
            Optional[Path]: Path to the downloaded source if successful, None otherwise
        """
        source_path = None

        # For Git sources, add Git-specific options
        if SourceManager.is_git_url(source_config["url"]):
            # Check if .gitmodules file exists
            has_gitmodules = False
            try:
                # Get branch from version field (user might enter 'master', 'main', etc.)
                branch = source_config.get('version', 'master')
                # Construct the correct .gitmodules URL
                gitmodules_url = LibraryManager._get_gitmodules_url(source_config["url"], branch)

                response = requests.get(gitmodules_url, timeout=10, verify=False)
                has_gitmodules = response.status_code == 200

            except requests.Timeout:
                RichLogger.warning(f"Timeout occurred while checking .gitmodules for {source_name}")
                # Use interactive prompt when timeout occurs
                has_gitmodules = Confirm.ask(
                    f"Timeout occurred while checking .gitmodules for {source_name}. "
                    f"Do you want to enable recursive clone?",
                    default=False
                )
            except (requests.RequestException, Exception) as e:
                RichLogger.debug(f"Failed to check .gitmodules: {str(e)}")
                # Use interactive prompt when other errors occur
                has_gitmodules = Confirm.ask(
                    f"Failed to check .gitmodules for {source_name}: {str(e)}. "
                    f"Do you want to enable recursive clone?",
                    default=False
                )

            # Automatically set recursive based on .gitmodules detection or user input
            source_config['recursive'] = has_gitmodules
            if has_gitmodules:
                RichLogger.info(f"Enabled recursive clone for {source_name}")
            else:
                RichLogger.info(f"Disabled recursive clone for {source_name}")

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

            # For Git sources, fetch the source to clone the repository
            try:
                source_path = SourceManager.fetch_source(source_config)
                if source_path is not None:
                    RichLogger.info(f"Successfully cloned Git repository for {source_name} to {source_path}")
                else:
                    RichLogger.warning(f"Failed to clone Git repository for {source_name}")
            except Exception as e:
                RichLogger.warning(f"Error cloning Git repository for {source_name}: {str(e)}")

        else:
            # For non-Git sources, try to download and calculate SHA256
            try:
                # Download source file
                source_path = SourceManager.fetch_source(source_config)
                if source_path is not None:
                    # Get file extension using improved method
                    ext = FileUtils.extract_file_extension(source_config['url'])

                    # Build download filename
                    download_filename = f"{source_config['name']}-{source_config['version']}.{ext}"
                    download_filepath = ROOT_DIR / 'downloads' / download_filename

                    # Calculate SHA256
                    if download_filepath.exists():
                        sha256_value = FileUtils.calc_hash(download_filepath)
                        source_config['sha256'] = sha256_value
                        RichLogger.info(f"Automatically calculated SHA256 for {source_name}: {sha256_value}")
                    else:
                        RichLogger.warning(f"Download file not found: {download_filepath}")
                        source_config['sha256'] = None
                else:
                    RichLogger.warning(f"Failed to download source for {source_name}")
                    source_config['sha256'] = None

            except Exception as e:
                RichLogger.warning(f"Error processing non-Git source for {source_name}: {str(e)}")
                # Fallback to manual input if automatic processing fails
                sha256_input = Prompt.ask(f"Enter SHA256 checksum for {source_name}", default="")
                if sha256_input.strip():
                    source_config['sha256'] = sha256_input.strip()
                else:
                    source_config['sha256'] = None

        return source_path

    @staticmethod
    def _process_extras(config: Dict):
        """Processes extra resources configuration."""
        if Confirm.ask("Add extra resources?"):
            config['extras'] = []
            while True:
                extra_name = Prompt.ask("Enter extra resource name (leave blank to finish)")
                if not extra_name:
                    break
                # Collect common source information
                extra = LibraryManager._collect_source_info(extra_name)
                # Process common source configuration
                LibraryManager._process_source_config(extra, extra_name)
                # Add extra-specific fields
                extra['target'] = Prompt.ask(f"Enter target path for {extra_name}")
                # Only add check field if user provides input
                check_input = Prompt.ask(f"Enter existence check command for {extra_name}", default="")
                if check_input:
                    extra['check'] = check_input

                config['extras'].append(extra)

    @staticmethod
    def _process_dependencies(config: Dict):
        """Processes dependencies configuration."""
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

            if not config['dependencies'].get('required') and not config['dependencies'].get('optional'):
                config['dependencies'] = None
        else:
            config['dependencies'] = None

    @staticmethod
    def _process_script(config: Dict, source_path: Optional[Path] = None):
        """Processes build script configuration.

        Args:
            config: Configuration dictionary to update
            source_path: Path to the downloaded source (if available)
        """
        # If source was successfully downloaded, auto-detect build system
        if source_path is not None and source_path.exists():
            RichLogger.info("Auto-detecting build system from downloaded source...")

            # Check for CMakeLists.txt
            cmake_lists = source_path / "CMakeLists.txt"
            if cmake_lists.exists():
                config['script'] = "build.bat"
                RichLogger.info("Detected CMake build system (CMakeLists.txt), using build.bat")
                return

            # Check for meson.build
            meson_build = source_path / "meson.build"
            if meson_build.exists():
                config['script'] = "build.bat"
                RichLogger.info("Detected Meson build system (meson.build), using build.bat")
                return

            # Check for configure.ac (autotools)
            configure_ac = source_path / "configure.ac"
            if configure_ac.exists():
                config['script'] = "build.sh"
                RichLogger.info("Detected Autotools build system (configure.ac), using build.sh")
                return

            # Check for other common build files as fallback
            makefile = source_path / "Makefile"
            configure_script = source_path / "configure"

            if makefile.exists() or configure_script.exists():
                config['script'] = "build.sh"
                RichLogger.info("Detected Makefile or configure script, using build.sh")
                return

            # If no build system detected, fall back to default
            RichLogger.warning("No standard build system detected in source root")
            config['script'] = "build.bat"
            RichLogger.info("Using default build.bat")

        else:
            # Fallback to manual selection if source download failed or unavailable
            RichLogger.warning("Source download failed or unavailable, using manual build script selection")

            # Present build script options
            RichLogger.info("\nSelect build script type:")
            RichLogger.info("1. No build script (empty)")
            RichLogger.info("2. Windows batch file (build.bat)")
            RichLogger.info("3. Unix shell script (build.sh)")

            choice = IntPrompt.ask("Enter your choice (1-3)", default=1, choices=["1", "2", "3"])

            if choice == 1:
                config['script'] = ""  # Empty script
            elif choice == 2:
                config['script'] = "build.bat"  # Windows batch file
            elif choice == 3:
                config['script'] = "build.sh"  # Unix shell script

            RichLogger.debug(f"Selected build script: {config['script']}")
