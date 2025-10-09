# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import locale
import os
import subprocess
import re
import shutil
from pathlib import Path
from rich.prompt import Confirm, IntPrompt

from mpt import ROOT_DIR
from mpt.core.archive import ArchiveHandler
from mpt.core.config import RequirementsConfig
from mpt.core.download import DownloadHandler
from mpt.core.log import RichLogger
from mpt.core.patch import PatchHandler
from mpt.core.view import RichTable, RichPanel
from mpt.utils.bash import BashUtils

class RuntimeManager:
    """
    Manages the installation and verification of system dependencies and extensions.

    Handles the complete lifecycle including checking existing installations,
    downloading packages, executing installation commands, applying patches,
    and coordinating system restarts when required.
    """

    restart_pending = False

    @classmethod
    def check_and_install(cls):
        """
        Main entry point for dependency management.

        Loads requirements configuration and processes each dependency:
        - Checks if dependency is already installed
        - Handles interactive variant selection when needed
        - Installs missing dependencies
        - Processes associated extensions
        - Manages system restart requirements

        Returns:
            bool: True if all dependencies were processed successfully, False otherwise
        """
        requirements = RequirementsConfig.load()
        if not requirements:
            RichLogger.info("No dependencies found in requirements.yaml")
            return True

        git_root = BashUtils.find_git_root()
        all_success = True

        for dep in requirements:
            dep_name = dep.get('name', 'Unknown')
            if cls._check_dependency(dep, git_root):
                # Dependency is already installed, process extensions
                if not cls.restart_pending and git_root is not None:
                    extensions = dep.get('extensions', [])
                    if extensions:
                        cls._process_extensions(extensions, git_root)
            else:
                variants = dep.get('variants', [])
                interactive = dep.get('interactive', False)

                # Handle interactive variant selection
                if variants and interactive:
                    RichLogger.print(f"Dependency [bold cyan]{dep_name}[/bold cyan] has multiple variants:")
                    variant_names = [v.get('name', 'Unknown') for v in variants]
                    installed_variants = []

                    # Check which variants are already installed
                    for idx, variant in enumerate(variants):
                        variant_check = variant.get('check', '')
                        if variant_check:
                            try:
                                expanded_cmd = cls._expand_envvars(variant_check)
                                expanded_cmd = cls._expand_placeholders(expanded_cmd, git_root)
                                result = subprocess.run(
                                    expanded_cmd,
                                    shell=True,
                                    stdout=subprocess.DEVNULL,
                                    stderr=subprocess.DEVNULL
                                )
                                if result.returncode == 0:
                                    installed_variants.append(idx + 1)
                            except Exception:
                                pass

                    # Show already installed variants
                    if installed_variants:
                        RichLogger.print("Already installed variants:")
                        for idx in installed_variants:
                            RichLogger.print(f"{idx}. {variant_names[idx-1]} [green]✓[/green]")

                    # Show available variants for installation
                    uninstalled_variants = [i+1 for i in range(len(variants)) if i+1 not in installed_variants]
                    if uninstalled_variants:
                        RichLogger.print("Available variants to install:")
                        for idx in uninstalled_variants:
                            RichLogger.print(f"{idx}. {variant_names[idx-1]}")

                        try:
                            choice = IntPrompt.ask(
                                "Select a variant to install",
                                choices=[str(i) for i in uninstalled_variants],
                                default=uninstalled_variants[0] if uninstalled_variants else None
                            )

                            if choice:
                                selected_variant = variants[choice - 1]
                                variant_dep = {
                                    'name': f"{dep_name} ({selected_variant['name']})",
                                    'url': selected_variant.get('url'),
                                    'sha256': selected_variant.get('sha256'),
                                    'install': selected_variant.get('install', ''),
                                    'target': selected_variant.get('target', ''),
                                    'restart': dep.get('restart', False),
                                    'check': selected_variant.get('check', '')
                                }
                                if cls._install_dependency(variant_dep, git_root):
                                    if not cls.restart_pending and git_root is not None:
                                        extensions = dep.get('extensions', [])
                                        if extensions:
                                            cls._process_extensions(extensions, git_root)
                                else:
                                    RichLogger.error(f"Failed to install variant: [bold cyan]{selected_variant['name']}[/bold cyan]")
                                    all_success = False
                        except Exception as e:
                            RichLogger.error(f"Error during variant selection: {str(e)}")
                            all_success = False
                    else:
                        RichLogger.info(f"All variants of [bold cyan]{dep_name}[/bold cyan] are already installed")
                else:
                    # Non-interactive installation or no variants
                    if 'install' in dep or 'target' in dep:
                        if cls._install_dependency(dep, git_root):
                            if not cls.restart_pending and git_root is not None:
                                extensions = dep.get('extensions', [])
                                if extensions:
                                    cls._process_extensions(extensions, git_root)
                        else:
                            RichLogger.error(f"Failed to install dependency: [bold cyan]{dep_name}[/bold cyan]")
                            all_success = False
                    else:
                        RichLogger.error(f"No installation method for dependency: [bold cyan]{dep_name}[/bold cyan]")
                        all_success = False

        if cls.restart_pending:
            RichLogger.warning("System restart is required to complete installation")
            RichLogger.print("\n[bold yellow]System Restart Required[/bold yellow]")
            RichLogger.print("Some components require a system restart to function properly")
            if Confirm.ask("Do you want to restart now?", default=True):
                RichLogger.info("Initiating system restart...")
                os.system("shutdown /r /t 0")
            else:
                RichLogger.warning("Please restart your computer when convenient")
                return False

        return all_success

    @staticmethod
    def _expand_envvars(cmd: str) -> str:
        """
        Expands environment variables in a command string.

        Replaces %VAR% patterns with actual environment variable values.

        Args:
            cmd (str): Command string containing environment variable references

        Returns:
            str: Command string with environment variables expanded
        """
        def replace_env(match):
            var = match.group(1)
            return os.environ.get(var, match.group(0))

        return re.sub(r'%([^%]+)%', replace_env, cmd)

    @staticmethod
    def _expand_placeholders(cmd: str, git_root: Path) -> str:
        """
        Replaces custom placeholders in command strings with actual paths.

        Handles {GIT_ROOT} and {ROOT_DIR} placeholders and normalizes path separators.

        Args:
            cmd (str): Command string containing placeholders
            git_root (Path): Path to use for {GIT_ROOT} substitution

        Returns:
            str: Command string with placeholders replaced
        """
        if git_root is not None:
            cmd = cmd.replace("{GIT_ROOT}", str(git_root))
        cmd = cmd.replace("{ROOT_DIR}", str(ROOT_DIR))
        return cmd.replace('/', '\\')

    @classmethod
    def _check_dependency(cls, dep, git_root):
        """
        Verifies if a dependency is already installed and functional.

        Executes the dependency-specific check command to determine installation status.

        Args:
            dep (dict): Dependency configuration containing check command
            git_root (Path): Git root directory for placeholder expansion

        Returns:
            bool: True if dependency is installed and verified, False otherwise
        """
        dep_name = dep.get('name', 'Unknown')
        check_cmd = dep.get('check', '')
        variants = dep.get('variants', [])

        # Check all variants if no top-level check command exists
        if variants and not check_cmd:
            all_variants_installed = True
            for variant in variants:
                variant_check = variant.get('check', '')
                if variant_check:
                    try:
                        expanded_cmd = cls._expand_envvars(variant_check)
                        expanded_cmd = cls._expand_placeholders(expanded_cmd, git_root)
                        result = subprocess.run(
                            expanded_cmd,
                            shell=True,
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL
                        )
                        if result.returncode != 0:
                            all_variants_installed = False
                            break
                    except Exception as e:
                        RichLogger.debug(f"Error checking variant {variant.get('name', 'Unknown')}: {str(e)}")
                        all_variants_installed = False
                        break
            return all_variants_installed

        # Regular check logic
        if not check_cmd:
            return False

        try:
            expanded_cmd = cls._expand_envvars(check_cmd)
            expanded_cmd = cls._expand_placeholders(expanded_cmd, git_root)
            result = subprocess.run(
                expanded_cmd,
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            return result.returncode == 0
        except Exception as e:
            RichLogger.exception(f"Error checking dependency [bold cyan]{dep_name}[/bold cyan]: {str(e)}")
            return False

    @classmethod
    def _install_dependency(cls, dep, git_root):
        """
        Installs a dependency using the specified installation method.

        Supports both target-based installation (file operations) and command-based installation.

        Args:
            dep (dict): Dependency configuration containing installation instructions
            git_root (Path): Git root directory for placeholder expansion

        Returns:
            bool: True if installation completed successfully, False otherwise
        """
        dep_name = dep.get('name', 'Unknown')
        install_cmd = dep.get('install', '')
        target = dep.get('target', '')

        # Use target-based installation if specified
        if target:
            return cls._process_target(dep, git_root)
        elif install_cmd:
            return cls._process_install(dep, git_root)
        else:
            RichLogger.error(f"No installation method specified for dependency: [bold cyan]{dep_name}[/bold cyan]")
            return False

    @classmethod
    def _process_target(cls, dep, git_root):
        """
        Processes dependency installation using target specification.

        Downloads files, verifies hashes, and handles both archive extraction and file copying.

        Args:
            dep (dict): Dependency configuration
            git_root (Path): Git root directory for placeholder expansion

        Returns:
            bool: True if installation completed successfully, False otherwise
        """
        dep_name = dep.get('name', 'Unknown')
        target = dep.get('target', '')
        url = dep.get('url')
        sha256 = dep.get('sha256')
        requires_restart = dep.get('restart', False)

        if not url:
            RichLogger.error(f"No URL provided for dependency with target: [bold cyan]{dep_name}[/bold cyan]")
            return False

        try:
            # Expand environment variables and placeholders in target path
            expanded_target = cls._expand_envvars(target)
            expanded_target = cls._expand_placeholders(expanded_target, git_root)
            target_path = Path(expanded_target)

            download_dir = ROOT_DIR / 'tags'
            download_dir.mkdir(parents=True, exist_ok=True)
            installer_path = download_dir / Path(url).name

            # Download and verify file
            if installer_path.exists():
                if sha256 and ArchiveHandler.verify_hash(installer_path, sha256):
                    RichLogger.info(f"Using verified installer for [bold cyan]{dep_name}[/bold cyan]")
                else:
                    RichLogger.warning(f"Installer hash mismatch or missing, redownloading [bold cyan]{dep_name}[/bold cyan]")
                    installer_path.unlink(missing_ok=True)
                    RichLogger.info(f"Downloading installer for [bold cyan]{dep_name}[/bold cyan]")
                    if not DownloadHandler.download_file(url, installer_path, verify_ssl=False):
                        RichLogger.error(f"Failed to download installer for dependency: [bold cyan]{dep_name}[/bold cyan]")
                        return False
            else:
                RichLogger.debug(f"Downloading installer for [bold cyan]{dep_name}[/bold cyan]")
                if not DownloadHandler.download_file(url, installer_path, verify_ssl=False):
                    RichLogger.error(f"Failed to download installer for dependency: [bold cyan]{dep_name}[/bold cyan]")
                    return False

            if sha256 and not ArchiveHandler.verify_hash(installer_path, sha256):
                RichLogger.error(f"Installer hash verification failed for dependency: [bold cyan]{dep_name}[/bold cyan]")
                return False

            # Check if the file is an archive
            archive_extensions = {'.zip', '.tar', '.gz', '.tgz', '.bz2', '.tbz2', '.xz', '.txz', '.zst', '.zstd'}

            if installer_path.suffix.lower() in archive_extensions:
                # Extract archive to target directory
                if not target_path.is_dir():
                    RichLogger.error(f"Target must be a directory for archive files: [bold cyan]{dep_name}[/bold cyan]")
                    return False

                RichLogger.info(f"Extracting archive for [bold cyan]{dep_name}[/bold cyan] to [bold cyan]{target_path}[/bold cyan]")
                if ArchiveHandler.extract(installer_path, target_path):
                    RichLogger.info(f"Extracted [bold cyan]{installer_path.name}[/bold cyan] to [bold cyan]{target_path}[/bold cyan]")
                    if requires_restart:
                        cls.restart_pending = True
                    return True
                else:
                    RichLogger.error(f"Failed to extract archive for dependency: [bold cyan]{dep_name}[/bold cyan]")
                    return False
            else:
                # Copy regular file to target location
                if target_path.is_dir():
                    # Target is a directory, copy file to it
                    target_path.mkdir(parents=True, exist_ok=True)
                    dest_path = target_path / installer_path.name
                    shutil.copy2(installer_path, dest_path)
                    RichLogger.info(f"Copied [bold cyan]{installer_path.name}[/bold cyan] to [bold cyan]{target_path}[/bold cyan]")
                else:
                    # Target is a file, copy and rename
                    target_path.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(installer_path, target_path)
                    RichLogger.info(f"Copied [bold cyan]{installer_path.name}[/bold cyan] to [bold cyan]{target_path}[/bold cyan]")
                if requires_restart:
                    cls.restart_pending = True
                return True

        except Exception as e:
            RichLogger.exception(f"Error processing target for dependency [bold cyan]{dep_name}[/bold cyan]: {str(e)}")
            return False

    @classmethod
    def _process_install(cls, dep, git_root):
        """
        Processes dependency installation using install command.

        Downloads installers if needed, executes installation commands, and handles output.

        Args:
            dep (dict): Dependency configuration
            git_root (Path): Git root directory for placeholder expansion

        Returns:
            bool: True if installation completed successfully, False otherwise
        """
        dep_name = dep.get('name', 'Unknown')
        install_cmd = dep.get('install', '')
        url = dep.get('url')
        sha256 = dep.get('sha256')
        requires_restart = dep.get('restart', False)

        if not install_cmd:
            RichLogger.error(f"No installation command for dependency: [bold cyan]{dep_name}[/bold cyan]")
            return False

        p = None
        exit_code = None
        success = False
        installer_path = None

        try:
            if url:
                download_dir = ROOT_DIR / 'tags'
                download_dir.mkdir(parents=True, exist_ok=True)
                installer_path = download_dir / Path(url).name

                # Download and verify file
                if installer_path.exists():
                    if sha256 and ArchiveHandler.verify_hash(installer_path, sha256):
                        RichLogger.info(f"Using verified installer for [bold cyan]{dep_name}[/bold cyan]")
                    else:
                        RichLogger.warning(f"Installer hash mismatch or missing, redownloading [bold cyan]{dep_name}[/bold cyan]")
                        installer_path.unlink(missing_ok=True)
                        RichLogger.info(f"Downloading installer for [bold cyan]{dep_name}[/bold cyan]")
                        if not DownloadHandler.download_file(url, installer_path, verify_ssl=False):
                            RichLogger.error(f"Failed to download installer for dependency: [bold cyan]{dep_name}[/bold cyan]")
                            return False
                else:
                    RichLogger.info(f"Downloading installer for [bold cyan]{dep_name}[/bold cyan]")
                    if not DownloadHandler.download_file(url, installer_path, verify_ssl=False):
                        RichLogger.error(f"Failed to download installer for dependency: [bold cyan]{dep_name}[/bold cyan]")
                        return False

                if sha256 and not ArchiveHandler.verify_hash(installer_path, sha256):
                    RichLogger.error(f"Installer hash verification failed for dependency: [bold cyan]{dep_name}[/bold cyan]")
                    return False
            else:
                RichLogger.info(f"Installing dependency without installer download: [bold cyan]{dep_name}[/bold cyan]")

            if '\n' in install_cmd:
                install_cmd = ' && '.join(
                    line.strip()
                    for line in install_cmd.splitlines()
                    if line.strip()
                )
            else:
                install_cmd = install_cmd.strip()
            install_cmd = cls._expand_envvars(install_cmd)
            install_cmd = cls._expand_placeholders(install_cmd, git_root)
            RichLogger.debug(f"Installing [bold cyan]{dep_name}[/bold cyan]...")
            RichLogger.debug(f"Executing command: {install_cmd}")
            RichLogger.debug(f"Working directory: {installer_path.parent if url else git_root}")
            p = subprocess.Popen(
                install_cmd,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                cwd=installer_path.parent if url else git_root
            )
            # Process output in real-time
            for line in iter(p.stdout.readline, b''):
                decoded_line = line.decode('utf-8', errors='ignore').rstrip()
                RichLogger.info(decoded_line, markup=False)
                if p.poll() is not None:
                    break
            # Wait for process completion
            exit_code = p.wait()
            if exit_code == 0:
                RichLogger.info(f"Installation completed for [bold cyan]{dep_name}[/bold cyan]")
                if requires_restart:
                    RichLogger.warning(f"{dep_name} requires system restart")
                    cls.restart_pending = True
                success = True
            else:
                RichLogger.error(f"Installation failed for dependency [bold cyan]{dep_name}[/bold cyan] with exit code: {exit_code}")
                success = False

        except Exception as e:
            RichLogger.exception(f"Error installing dependency [bold cyan]{dep_name}[/bold cyan]: {str(e)}")
            success = False
        finally:
            if p and p.poll() is None:
                p.terminate()
                p.wait(timeout=5)

        return success

    @classmethod
    def _check_extension(cls, ext, git_root):
        """
        Verifies if an extension is already installed and functional.

        Executes the extension-specific check command to determine installation status.

        Args:
            ext (dict): Extension configuration containing check command
            git_root (Path): Git root directory for placeholder expansion

        Returns:
            bool: True if extension is installed and verified, False otherwise
        """
        check_cmd = ext.get('check', '')
        if not check_cmd:
            return False

        # Skip check if git_root is None and command contains {GIT_ROOT}
        if git_root is None and "{GIT_ROOT}" in check_cmd:
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
            RichLogger.error(f"Error checking extension: {str(e)}")
            return False

    @classmethod
    def _process_extensions(cls, extensions, git_root):
        """
        Processes all extensions associated with a dependency.

        Checks if extensions are already installed and installs missing ones.

        Args:
            extensions (list): List of extension configurations to process
            git_root (Path): Git root directory for placeholder expansion

        Returns:
            list: Names of successfully processed extensions
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
                RichLogger.exception(f"Error processing extension {ext.get('name', 'Unknown')}: {str(e)}")

        return installed_list

    @classmethod
    def _install_extension(cls, ext, git_root):
        """
        Installs an extension by downloading and extracting it.

        Handles archive extraction, file filtering, and patch application.

        Args:
            ext (dict): Extension configuration containing installation instructions
            git_root (Path): Git root directory for placeholder expansion

        Returns:
            bool: True if extension installation completed successfully, False otherwise
        """
        ext_name = ext.get('name', 'Unknown')
        url = ext.get('url')
        sha256 = ext.get('sha256')
        target = ext.get('target')
        exclude = ext.get('exclude', [])
        include = ext.get('include', [])
        patch_config = ext.get('patch')

        if not url or not target:
            RichLogger.error(f"Missing URL or target for extension: [bold cyan]{ext_name}[/bold cyan]")
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
                    RichLogger.info(f"Using cached archive for [bold cyan]{ext_name}[/bold cyan]")
                else:
                    download_path.unlink(missing_ok=True)
                    RichLogger.info(f"Downloading extension: [bold cyan]{ext_name}[/bold cyan]")
                    if not DownloadHandler.download_file(url, download_path, verify_ssl=False):
                        RichLogger.error(f"Download failed for extension: [bold cyan]{ext_name}[/bold cyan]")
                        return False
            else:
                RichLogger.info(f"Downloading extension: [bold cyan]{ext_name}[/bold cyan]")
                if not DownloadHandler.download_file(url, download_path, verify_ssl=False):
                    RichLogger.error(f"Download failed for extension: [bold cyan]{ext_name}[/bold cyan]")
                    return False

            if sha256 and not ArchiveHandler.verify_hash(download_path, sha256):
                RichLogger.error(f"Hash verification failed for extension: [bold cyan]{ext_name}[/bold cyan]")
                return False

            RichLogger.info(f"Installing extension: [bold cyan]{ext_name}[/bold cyan]")
            if not ArchiveHandler.extract(
                archive_path=download_path,
                target_dir=target_path,
                exclude=exclude,
                include=include,
                remove_archive=False
            ):
                RichLogger.error(f"Extraction failed for extension: [bold cyan]{ext_name}[/bold cyan]")
                return False

            if patch_config:
                patch_files = []
                for patch_name in patch_config:
                    patch_file = ROOT_DIR / 'mpt' / 'config' / patch_name
                    RichLogger.debug(f"Looking for patch at: {patch_file.resolve()}")
                    if not patch_file.exists():
                        RichLogger.error(f"Patch file not found: [bold red]{patch_file}[/bold red]")
                        return False
                    patch_files.append(patch_file.resolve())

                if PatchHandler.apply_patches(
                    source_dir=target_path,
                    patch_files=patch_files
                ):
                    RichLogger.info(f"Applied {len(patch_files)} patches for [bold cyan]{ext_name}[/bold cyan]")
                else:
                    RichLogger.error(f"Failed to apply patches for extension: [bold cyan]{ext_name}[/bold cyan]")
                    return False

            return True

        except Exception as e:
            RichLogger.exception(f"Error installing extension [bold cyan]{ext_name}[/bold cyan]: {str(e)}")
            return False
