# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
import logging
from pathlib import Path
from typing import Dict, Optional

from mpt import ROOT_DIR
from mpt.core.console import console
from mpt.core.git import GitHandler
from mpt.core.history import HistoryManager
from mpt.config.loader import PackageConfig, UserConfig
from mpt.core.log import Logger
from mpt.core.patch import PatchHandler
from mpt.core.run import Runner
from mpt.core.source import SourceManager
from mpt.core.dependency import DependencyResolver


class BuildManager:
    """Manages the complete build lifecycle for libraries with dependency type support.

    Handles source acquisition, environment preparation, script execution, and
    build validation. Supports conditional rebuilding based on dependency changes,
    configuration updates, and source code modifications.
    """

    @staticmethod
    def build_library(node_name: str, arch: str, config: Dict) -> bool:
        """
        Execute the complete build process for a library with dependency tracking.

        Coordinates the entire build workflow including dependency checking, source
        acquisition, environment setup, script execution, and history recording.
        Supports conditional rebuilding based on various change detection mechanisms.

        Args:
            node_name: Library identifier with optional dependency type suffix
                       (e.g., "pcre:required" for required dependency)
            arch: Target architecture specification (e.g., "x86_64", "arm64")
            config: Library configuration dictionary containing build instructions,
                    source location, version information, and other metadata

        Returns:
            bool: True if build completed successfully or was legitimately skipped,
                  False if any critical build step failed
        """
        try:
            success = True
            # Parse node name to get library name and dependency type
            lib_name, dep_type = DependencyResolver.parse_dependency_name(node_name)

            # Check if rebuild is required
            if not BuildManager._should_build(arch, node_name, config):
                Logger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build skipped - already up to date")
                return True

            # Create log directory if it doesn't exist
            log_dir = ROOT_DIR / "logs"
            log_dir.mkdir(parents=True, exist_ok=True)

            # Prepare environment variables
            env = BuildManager.prepare_envvars(arch, lib_name)

            # Fetch source code
            source_path, needs_sync = SourceManager.fetch_source(config)
            if not source_path or not source_path.exists():
                Logger.critical(f"[[bold cyan]{node_name}[/bold cyan]] Source acquisition failed")
                return False

            # Run sync script if source was just fetched
            if needs_sync:
                sync_script_path = ROOT_DIR / 'packages' / lib_name / "sync.sh"
                if sync_script_path.exists():
                    Logger.debug(f"Running sync script: [bold cyan]{sync_script_path}[/bold cyan]")
                    if not Runner.run_script(env, sync_script_path):
                        success = False

            # Run the main build script
            script_file = config.get('run')
            if script_file:
                log_file = ROOT_DIR / "logs" / f"{lib_name}.log"
                script_path = ROOT_DIR / 'packages' / lib_name / script_file
                if not script_path.exists():
                    Logger.error(f"Build script not found: [bold cyan]{script_path}[/bold cyan]")
                    return False

                Logger.info(f"[[bold cyan]{node_name}[/bold cyan]] Starting build process on architecture [bold magenta]{arch}[/bold magenta]")

                success = Runner.run_script(env, script_path, log_file)
                if success:
                    version = config.get('version', 'unknown')
                    HistoryManager.add_record(arch, node_name, version)
                    Logger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build completed successfully")
                else:
                    HistoryManager.remove_record(arch, node_name)
                    Logger.error(f"[[bold cyan]{node_name}[/bold cyan]] Build failed")

            return success
        except Exception as e:
            Logger.exception(f"Unexpected error in build_library for {node_name}")
            return False

    @staticmethod
    def _should_build(arch: str, node_name: str, config: Dict) -> bool:
        """
        Determine whether a library requires rebuilding based on multiple factors.

        Performs comprehensive change detection including:
        - Installation status verification
        - Version update availability checking
        - Configuration file modification detection
        - Build script modification detection
        - Source code updates (for Git repositories)
        - Dependency rebuild requirement propagation

        Args:
            arch: Target architecture for build compatibility checking
            node_name: Library identifier with dependency type specification
            config: Library configuration containing source and version information

        Returns:
            bool: True if any condition warrants a rebuild, False if the existing
                  build remains valid and up-to-date
        """
        try:
            # Parse node name to get library name and dependency type
            lib_name, dep_type = DependencyResolver.parse_dependency_name(node_name)

            # Check if library node is not installed
            if not HistoryManager.check_installed(arch, node_name):
                Logger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: not installed")
                return True

            # Check if library node update is available
            if HistoryManager.check_for_update(arch, node_name, config):
                Logger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: update available")
                return True

            # Get library node information
            lib_info = HistoryManager.get_library_info(arch, node_name)
            if not lib_info:
                Logger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: no library info")
                return True

            # Check if library node has no build timestamp
            lib_built = lib_info.get('built')
            if not lib_built:
                Logger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: no build timestamp")
                return True

            # Check for configuration file changes
            config_path = ROOT_DIR / 'packages' / lib_name / 'config.yaml'
            if config_path.exists():
                try:
                    config_mtime = config_path.stat().st_mtime
                    if config_mtime > lib_built.timestamp():
                        Logger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build required: configuration modified")
                        return True
                except OSError as e:
                    Logger.exception(f"Error checking config file modification time for [bold cyan]{config_path}[/bold cyan]")
                    return True

            # Check for build script changes
            build_script = config.get('run')
            if build_script:
                script_path = ROOT_DIR / 'packages' / lib_name / build_script
                if script_path.exists():
                    try:
                        script_mtime = script_path.stat().st_mtime
                        if script_mtime > lib_built.timestamp():
                            Logger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build required: build script modified")
                            return True
                    except OSError as e:
                        Logger.exception(f"Error checking script file modification time for [bold cyan]{script_path}[/bold cyan]")
                        return True

            # Check for source code updates (for git repositories)
            if SourceManager.is_git_url(config.get('url', '')):
                source_dir = ROOT_DIR / 'releases' / lib_name
                if source_dir.exists():
                    try:
                        last_commit_time = GitHandler.get_last_commit_time(source_dir)
                        if not last_commit_time:
                            Logger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build required: Failed to get commit time")
                            return True
                        elif last_commit_time > lib_built.timestamp():
                            Logger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build required: source code updated")
                            return True
                    except Exception as e:
                        Logger.exception(f"Error checking git commit time for {source_dir}")
                        return True

            # Check all dependencies for rebuild requirements
            deps = DependencyResolver.get_dependencies(lib_name, dep_type)

            for dep in deps:
                Logger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Checking dependency: [bold cyan]{dep}[/bold cyan]")

                # Get dependency information
                dep_info = HistoryManager.get_library_info(arch, dep)
                if not dep_info:
                    Logger.debug(f"[[bold cyan]{node_name}[/bold cyan]] No info for dependency [bold cyan]{dep}[/bold cyan]")
                    continue

                dep_built = dep_info.get('built')
                if not dep_built:
                    Logger.debug(f"[[bold cyan]{node_name}[/bold cyan]] No build timestamp for dependency [bold cyan]{dep}[/bold cyan]")
                    continue

                # Compare build timestamps
                if dep_built > lib_built:
                    Logger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: dependency [bold cyan]{dep}[/bold cyan] was updated")
                    return True

            return False
        except Exception as e:
            Logger.exception(f"Unexpected error in _should_build for {node_name}")
            return True

    @staticmethod
    def prepare_envvars(arch: str, lib: str) -> Dict[str, str]:
        """
        Prepare and configure environment variables for build processes.

        Constructs a comprehensive environment setup including:
        - Architecture-specific build settings
        - Library-specific configuration values
        - Prefix path configurations from user settings
        - Dependency library prefix references
        - PATH updates for dependency binaries

        Args:
            arch: Target architecture specification for environment tuning
            lib: Library name for package-specific configuration loading

        Returns:
            Dict[str, str]: Dictionary containing all environment variables
                           required for successful build execution
        """
        try:
            # Copy current environment
            env = os.environ.copy()

            # Set basic environment variables
            env['ARCH'] = arch
            env['ROOT_DIR'] = str(ROOT_DIR)

            # Load package configuration and set package-specific variables
            config = PackageConfig.load(lib)
            env['PKG_NAME'] = config.get('name')
            env['PKG_VER'] = str(config.get('version'))

            # Set prefix paths
            prefix = ROOT_DIR / arch
            env['_PREFIX'] = str(prefix)

            prefix_paths = [str(prefix)]
            user_settings = UserConfig.load()
            prefix_config = user_settings.get('prefix', {}) or {}

            # Process architecture-specific prefix configurations
            if arch in prefix_config:
                for lib_name, lib_prefix in prefix_config[arch].items():
                    # Create environment variable name from library name
                    prefix_env = lib_name.replace('-', '_').upper() + '_PREFIX'
                    env[prefix_env] = lib_prefix

                    # Update prefix if this is the current library
                    if lib_name == lib:
                        prefix = lib_prefix

                    # Add binary directory to PATH if it exists
                    bin_dir = Path(lib_prefix) / 'bin'
                    if bin_dir.exists():
                        current_path = env.get('PATH', '')
                        if str(bin_dir) not in current_path:
                            env['PATH'] = f"{str(bin_dir)}{os.pathsep}{current_path}"

                    # Add to prefix paths
                    prefix_paths.append(lib_prefix)

            # Set final environment variables
            env['PREFIX_PATH'] = os.pathsep.join(prefix_paths)
            env['PREFIX'] = str(prefix)
            return env
        except Exception as e:
            Logger.exception(f"Unexpected error in prepare_envvars for {lib}")
            env = os.environ.copy()
            env['ARCH'] = arch
            env['ROOT_DIR'] = str(ROOT_DIR)
            env['PREFIX'] = str(ROOT_DIR / arch)
            return env
