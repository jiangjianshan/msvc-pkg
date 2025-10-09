# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
import logging
from pathlib import Path
from typing import Dict, Optional

from mpt import ROOT_DIR
from mpt.core.git import GitHandler
from mpt.core.history import HistoryManager
from mpt.core.log import RichLogger
from mpt.core.patch import PatchHandler
from mpt.core.run import Runner
from mpt.core.source import SourceManager
from mpt.core.dependency import DependencyResolver
from mpt.utils.bash import BashUtils


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
        # Parse node name to get library name and dependency type
        lib_name, dep_type = DependencyResolver.parse_dependency_name(node_name)

        # Check if rebuild is required
        if not BuildManager._should_build(arch, node_name, config):
            RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build skipped - already up to date")
            return True

        # Create log directory if it doesn't exist
        log_dir = ROOT_DIR / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)

        # Prepare environment variables
        Runner.setup_environment(arch, lib_name)

        # Fetch source code
        source_path = SourceManager.fetch_source(config)
        if not source_path or not source_path.exists():
            RichLogger.critical(f"[[bold cyan]{node_name}[/bold cyan]] Source acquisition failed")
            return False

        # Run the main build script
        script_file = config.get('run')
        if script_file:
            log_file = ROOT_DIR / "logs" / f"{lib_name}.log"
            script_path = ROOT_DIR / 'packages' / lib_name / script_file
            if not script_path.exists():
                RichLogger.error(f"Build script not found: [bold cyan]{script_path}[/bold cyan]")
                return False
            RichLogger.info(f"[[bold cyan]{node_name}[/bold cyan]] Starting build process on architecture [bold magenta]{arch}[/bold magenta]")
            if Runner.run_script(script_path, log_file):
                version = config.get('version', 'unknown')
                HistoryManager.add_record(arch, node_name, version)
                RichLogger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build completed successfully")
                return True
            else:
                HistoryManager.remove_record(arch, node_name)
                RichLogger.error(f"[[bold cyan]{node_name}[/bold cyan]] Build failed")
                return False
        else:
            return True
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
        # Parse node name to get library name and dependency type
        lib_name, dep_type = DependencyResolver.parse_dependency_name(node_name)

        # Check if library node is not installed
        if not HistoryManager.check_installed(arch, node_name):
            RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: not installed")
            return True

        # Check if library node update is available
        if HistoryManager.check_for_update(arch, node_name, config):
            RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: update available")
            return True

        # Get library node information
        lib_info = HistoryManager.get_library_info(arch, node_name)
        if not lib_info:
            RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: no library info")
            return True

        # Check if library node has no build timestamp
        lib_built = lib_info.get('built')
        if not lib_built:
            RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: no build timestamp")
            return True

        # Check for any file changes in the package directory
        pkg_dir = ROOT_DIR / 'packages' / lib_name
        if pkg_dir.exists():
            try:
                # Walk through all files in the package directory
                for file_path in pkg_dir.rglob('*'):
                    if file_path.is_file():
                        file_mtime = file_path.stat().st_mtime
                        if file_mtime > lib_built.timestamp():
                            RichLogger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build required: file {file_path.relative_to(pkg_dir)} modified")
                            return True
            except OSError as e:
                RichLogger.exception(f"Error checking file modification times in [bold cyan]{pkg_dir}[/bold cyan]")
                return True

        # Check for source code updates (for git repositories)
        if SourceManager.is_git_url(config.get('url', '')):
            source_dir = ROOT_DIR / 'releases' / lib_name
            if source_dir.exists():
                try:
                    last_commit_time = GitHandler.get_last_commit_time(source_dir)
                    if not last_commit_time:
                        RichLogger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build required: Failed to get commit time")
                        return True
                    elif last_commit_time > lib_built.timestamp():
                        RichLogger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build required: source code updated")
                        return True
                except Exception as e:
                    RichLogger.exception(f"Error checking git commit time for {source_dir}")
                    return True

        # Check all dependencies for rebuild requirements
        deps = DependencyResolver.get_dependencies(lib_name, dep_type)

        for dep in deps:
            RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Checking dependency: [bold cyan]{dep}[/bold cyan]")

            # Get dependency information
            dep_info = HistoryManager.get_library_info(arch, dep)
            if not dep_info:
                RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] No info for dependency [bold cyan]{dep}[/bold cyan]")
                continue

            dep_built = dep_info.get('built')
            if not dep_built:
                RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] No build timestamp for dependency [bold cyan]{dep}[/bold cyan]")
                continue

            # Compare build timestamps
            if dep_built > lib_built:
                RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: dependency [bold cyan]{dep}[/bold cyan] was updated")
                return True

        return False
