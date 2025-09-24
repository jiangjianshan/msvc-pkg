# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import locale
import os
import subprocess
import re
from pathlib import Path
from rich.prompt import Confirm

from mpt import ROOT_DIR
from mpt.core.archive import ArchiveHandler
from mpt.core.download import DownloadHandler
from mpt.core.console import console
from mpt.core.log import Logger
from mpt.core.patch import PatchHandler
from mpt.core.view import RichTable, RichPanel
from mpt.utils.bash import BashUtils
from mpt.config.loader import RequirementsConfig

class RuntimeManager:
    """
    Comprehensive runtime environment management system for dependency and extension handling.

    Provides end-to-end management of system dependencies, extensions, and runtime components
    with support for automated installation, verification, and system restart coordination.
    Handles complex dependency chains, extension patching, and cross-platform compatibility.
    """

    restart_pending = False

    @classmethod
    def check_and_install(cls):
        """
        Execute complete dependency and extension management lifecycle with comprehensive validation.

        Orchestrates the full runtime environment setup process including:
        - Dependency requirement loading from configuration
        - Existing installation verification
        - Automated dependency installation with multiple methods
        - Extension processing with patching support
        - System restart coordination for components requiring reboot
        - Missing dependency reporting and user guidance

        Returns:
            bool: True if all dependencies and extensions are successfully satisfied,
                  False if any critical components are missing or installation fails
        """
        requirements = RequirementsConfig.load()
        if not requirements:
            Logger.info("No dependencies found in requirements.yaml")
            return True

        missing_deps = []
        git_root = BashUtils.find_git_root()

        for dep in requirements:
            dep_name = dep.get('name', 'Unknown')
            if cls._check_dependency(dep, git_root):
                extensions = dep.get('extensions', [])
                if extensions:
                    cls._process_extensions(extensions, git_root)
            else:
                if 'install' in dep:
                    if cls._install_dependency(dep, git_root):
                        extensions = dep.get('extensions', [])
                        if extensions:
                            cls._process_extensions(extensions, git_root)
                        continue
                    else:
                        Logger.error(f"Failed to install dependency: [bold cyan]{dep_name}[/bold cyan]")

                missing_deps.append({
                    'name': dep_name,
                    'hint': dep.get('hint', 'Please see documentation')
                })

        if cls.restart_pending:
            Logger.warning("System restart is required to complete installation")
            console.print("\n[bold yellow]System Restart Required[/bold yellow]")
            console.print("Some components require a system restart to function properly")
            if Confirm.ask("Do you want to restart now?", default=True):
                Logger.info("Initiating system restart...")
                os.system("shutdown /r /t 0")
            else:
                Logger.warning("Please restart your computer when convenient")
                return False
        if missing_deps:
            cls._show_missing_dependencies(missing_deps)
            return False
        return True

    @staticmethod
    def _expand_envvars(cmd: str) -> str:
        """
        Expand environment variable references in command strings with proper substitution.

        Processes command strings containing environment variable references (e.g., %VAR%)
        and replaces them with their actual values from the current environment.

        Args:
            cmd (str): Command string potentially containing environment variable references

        Returns:
            str: Command string with all environment variables expanded to their actual values
        """
        def replace_env(match):
            var = match.group(1)
            return os.environ.get(var, match.group(0))

        return re.sub(r'%([^%]+)%', replace_env, cmd)

    @staticmethod
    def _expand_placeholders(cmd: str, git_root: Path) -> str:
        """
        Replace custom placeholders in command strings with actual system paths.

        Handles specialized placeholder substitution including {GIT_ROOT} replacement
        and path separator normalization for cross-platform command execution.

        Args:
            cmd (str): Command string containing placeholder tokens
            git_root (Path): Filesystem path to use for {GIT_ROOT} substitution

        Returns:
            str: Command string with all placeholders replaced by actual values
        """
        cmd = cmd.replace("{GIT_ROOT}", str(git_root))
        return cmd.replace('/', '\\')

    @classmethod
    def _check_dependency(cls, dep, git_root):
        """
        Verify if a specific dependency is already installed and functional on the system.

        Executes dependency-specific verification commands to determine installation status.
        Handles command expansion, execution, and result interpretation with comprehensive
        error handling for reliable dependency detection.

        Args:
            dep (dict): Dependency configuration containing verification command
            git_root (Path): Git root directory path for placeholder expansion

        Returns:
            bool: True if dependency verification succeeds, False otherwise
        """
        dep_name = dep.get('name', 'Unknown')
        check_cmd = dep.get('check', '')
        if not check_cmd:
            return False
        expanded_cmd = cls._expand_envvars(check_cmd)
        expanded_cmd = cls._expand_placeholders(expanded_cmd, git_root)
        try:
            result = subprocess.run(
                expanded_cmd,
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            return result.returncode == 0
        except Exception as e:
            Logger.exception(f"Error checking dependency [bold cyan]{dep_name}[/bold cyan]: {str(e)}")
            return False

    @classmethod
    def _install_dependency(cls, dep, git_root):
        """
        Execute complete dependency installation process with multiple installation methods.

        Supports various installation approaches including:
        - Direct command execution
        - Downloadable installer packages with hash verification
        - Environment variable and placeholder expansion
        - System restart requirement detection and coordination

        Args:
            dep (dict): Dependency configuration containing installation instructions
            git_root (Path): Git root directory path for placeholder expansion

        Returns:
            bool: True if dependency installation completes successfully, False otherwise
        """
        dep_name = dep.get('name', 'Unknown')
        install_cmd = dep.get('install', '')
        url = dep.get('url')
        sha256 = dep.get('sha256')
        requires_restart = dep.get('restart', False)

        if not install_cmd:
            Logger.error(f"No installation command for dependency: [bold cyan]{dep_name}[/bold cyan]")
            return False

        p = None
        exit_code = None
        success = False

        try:
            if url:
                download_dir = ROOT_DIR / 'tags'
                download_dir.mkdir(parents=True, exist_ok=True)
                installer_path = download_dir / Path(url).name
                if installer_path.exists():
                    if sha256 and ArchiveHandler.verify_hash(installer_path, sha256):
                        Logger.info(f"Using verified installer for [bold cyan]{dep_name}[/bold cyan]")
                    else:
                        Logger.warning(f"Installer hash mismatch or missing, redownloading [bold cyan]{dep_name}[/bold cyan]")
                        installer_path.unlink(missing_ok=True)
                        Logger.info(f"Downloading installer for [bold cyan]{dep_name}[/bold cyan]")
                        if not DownloadHandler.download_file(url, installer_path, verify_ssl=False):
                            Logger.error(f"Failed to download installer for dependency: [bold cyan]{dep_name}[/bold cyan]")
                            return False
                else:
                    Logger.info(f"Downloading installer for [bold cyan]{dep_name}[/bold cyan]")
                    if not DownloadHandler.download_file(url, installer_path, verify_ssl=False):
                        Logger.error(f"Failed to download installer for dependency: [bold cyan]{dep_name}[/bold cyan]")
                        return False

                if sha256 and not ArchiveHandler.verify_hash(installer_path, sha256):
                    Logger.error(f"Installer hash verification failed for dependency: [bold cyan]{dep_name}[/bold cyan]")
                    return False

                original_filename = Path(url).name
                installer_path_str = str(installer_path)
                if " " in installer_path_str:
                    installer_path_str = f'"{installer_path_str}"'
                install_cmd = install_cmd.replace(original_filename, installer_path_str)
            else:
                Logger.info(f"Installing dependency without installer download: [bold cyan]{dep_name}[/bold cyan]")

            if '\n' in install_cmd:
                install_cmd = ' '.join(
                    line.strip()
                    for line in install_cmd.splitlines()
                    if line.strip()
                )
            else:
                install_cmd = install_cmd.strip()
            install_cmd = cls._expand_envvars(install_cmd)
            install_cmd = cls._expand_placeholders(install_cmd, git_root)
            Logger.debug(f"Installing [bold cyan]{dep_name}[/bold cyan]...")
            p = subprocess.Popen(
                install_cmd,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT
            )
            # Process output in real-time
            for line in iter(p.stdout.readline, b''):
                decoded_line = line.decode('utf-8', errors='ignore').rstrip()
                Logger.info(decoded_line, markup=False)
                if p.poll() is not None:
                    break
            # Wait for process completion
            exit_code = p.wait()
            if exit_code == 0:
                Logger.info(f"Installation completed for [bold cyan]{dep_name}[/bold cyan]")
                if requires_restart:
                    Logger.warning(f"{dep_name} requires system restart")
                    cls.restart_pending = True
                success = True
            else:
                Logger.error(f"Installation failed for dependency [bold cyan]{dep_name}[/bold cyan] with exit code: {exit_code}")
                success = False

        except Exception as e:
            Logger.exception(f"Error installing dependency [bold cyan]{dep_name}[/bold cyan]: {str(e)}")
            success = False
        finally:
            if p and p.poll() is None:
                p.terminate()
                p.wait(timeout=5)

        return success

    @classmethod
    def _check_extension(cls, ext, git_root):
        """
        Verify if a specific extension component is already installed and functional.

        Executes extension-specific verification commands to determine installation status.
        Handles command expansion and execution with proper error handling for
        reliable extension detection.

        Args:
            ext (dict): Extension configuration containing verification command
            git_root (Path): Git root directory path for placeholder expansion

        Returns:
            bool: True if extension verification succeeds, False otherwise
        """
        check_cmd = ext.get('check', '')
        if not check_cmd:
            return False
        try:
            expanded_cmd = cls._expand_envvars(check_cmd)
            expanded_cmd = cls._expand_placeholders(expanded_cmd, git_root)
            result = subprocess.run(
                expanded_cmd,
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE
            )
            return result.returncode == 0
        except Exception as e:
            Logger.error(f"Error checking extension: {str(e)}")
            return False

    @classmethod
    def _process_extensions(cls, extensions, git_root):
        """
        Manage the complete extension processing lifecycle including installation and verification.

        Coordinates the installation of multiple extensions with proper dependency ordering
        and status tracking. Returns a list of successfully processed extensions for
        reporting and further processing.

        Args:
            extensions (list): List of extension configurations to process
            git_root (Path): Git root directory path for placeholder expansion

        Returns:
            list: Names of extensions that were successfully installed or verified
        """
        installed_list = []
        for ext in extensions:
            try:
                ext_name = ext.get('name', 'Unknown')
                if cls._check_extension(ext, git_root):
                    installed_list.append(ext_name)
                    continue

                if cls._install_extension(ext, git_root):
                    installed_list.append(ext_name)
            except Exception as e:
                Logger.exception(f"Error processing extension {ext.get('name', 'Unknown')}: {str(e)}")

        return installed_list

    @classmethod
    def _install_extension(cls, ext, git_root):
        """
        Execute complete extension installation process with advanced features.

        Handles the full extension installation workflow including:
        - Remote package downloading with hash verification
        - Archive extraction with inclusion/exclusion filtering
        - Patch application for custom modifications
        - Comprehensive error handling and rollback capabilities

        Args:
            ext (dict): Extension configuration containing installation instructions
            git_root (Path): Git root directory path for placeholder expansion

        Returns:
            bool: True if extension installation completes successfully, False otherwise
        """
        ext_name = ext.get('name', 'Unknown')
        url = ext.get('url')
        sha256 = ext.get('sha256')
        target = ext.get('target')
        exclude = ext.get('exclude', [])
        include = ext.get('include', [])
        patch_config = ext.get('patch')

        if not url or not target:
            Logger.error(f"Missing URL or target for extension: [bold cyan]{ext_name}[/bold cyan]")
            return False

        try:
            expanded_target = cls._expand_envvars(target)
            expanded_target = cls._expand_placeholders(expanded_target, git_root)
            target_path = Path(expanded_target)
            target_path.mkdir(parents=True, exist_ok=True)

            download_dir = ROOT_DIR / 'tags'
            download_dir.mkdir(parents=True, exist_ok=True)
            download_path = download_dir / Path(url).name

            if download_path.exists():
                if sha256 and ArchiveHandler.verify_hash(download_path, sha256):
                    Logger.info(f"Using cached archive for [bold cyan]{ext_name}[/bold cyan]")
                else:
                    download_path.unlink(missing_ok=True)
                    Logger.info(f"Downloading extension: [bold cyan]{ext_name}[/bold cyan]")
                    if not DownloadHandler.download_file(url, download_path, verify_ssl=False):
                        Logger.error(f"Download failed for extension: [bold cyan]{ext_name}[/bold cyan]")
                        return False
            else:
                Logger.info(f"Downloading extension: [bold cyan]{ext_name}[/bold cyan]")
                if not DownloadHandler.download_file(url, download_path, verify_ssl=False):
                    Logger.error(f"Download failed for extension: [bold cyan]{ext_name}[/bold cyan]")
                    return False

            if sha256 and not ArchiveHandler.verify_hash(download_path, sha256):
                Logger.error(f"Hash verification failed for extension: [bold cyan]{ext_name}[/bold cyan]")
                return False

            Logger.info(f"Installing extension: [bold cyan]{ext_name}[/bold cyan]")
            if not ArchiveHandler.extract(
                archive_path=download_path,
                target_dir=target_path,
                exclude=exclude,
                include=include,
                remove_archive=False
            ):
                Logger.error(f"Extraction failed for extension: [bold cyan]{ext_name}[/bold cyan]")
                return False

            if patch_config:
                patch_files = []
                for patch_name in patch_config:
                    patch_file = ROOT_DIR / 'mpt' / 'config' / patch_name
                    Logger.debug(f"Looking for patch at: {patch_file.resolve()}")
                    if not patch_file.exists():
                        Logger.error(f"Patch file not found: [bold red]{patch_file}[/bold red]")
                        return False
                    patch_files.append(patch_file.resolve())

                if PatchHandler.apply_patches(
                    source_dir=target_path,
                    patch_files=patch_files
                ):
                    Logger.info(f"Applied {len(patch_files)} patches for [bold cyan]{ext_name}[/bold cyan]")
                else:
                    Logger.error(f"Failed to apply patches for extension: [bold cyan]{ext_name}[/bold cyan]")
                    return False

            return True

        except Exception as e:
            Logger.exception(f"Error installing extension [bold cyan]{ext_name}[/bold cyan]: {str(e)}")
            return False

    @staticmethod
    def _show_missing_dependencies(missing_deps):
        """
        Generate and display a formatted report of missing dependencies with guidance.

        Creates a user-friendly summary of dependencies that could not be automatically
        installed, providing clear instructions for manual installation steps.
        Uses color coding and structured formatting for improved readability.

        Args:
            missing_deps (list): List of missing dependency information dictionaries
        """
        if not missing_deps:
            return

        content_lines = [
            "The following dependencies are missing and require manual installation:\n"
        ]

        for dep in missing_deps:
            hint = dep.get('hint', 'Please see documentation')
            content_lines.append(
                f"• [bold yellow]{dep['name']}[/bold yellow]: {hint}"
            )

        content_lines.append("\nPlease install these dependencies and try again.")

        RichPanel.summary(
            content="\n".join(content_lines),
            title="Missing Dependencies",
            border_style="bold red"
        )
