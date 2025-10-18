# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
import subprocess
from pathlib import Path
from typing import List, Optional
from rich.text import Text

from mpt import ROOT_DIR
from mpt.bash import BashUtils
from mpt.log import RichLogger
from mpt.path import PathUtils
from mpt.view import RichPanel


class PatchHandler:
    """
    Comprehensive patch management system for source code modification and customization.

    Provides robust patch application capabilities with support for multiple patch sources,
    cross-platform compatibility, and detailed error reporting. Handles the complete
    patch lifecycle from discovery to application with comprehensive validation and
    logging throughout the process.
    """

    @staticmethod
    def apply_patches(
        source_dir: Path,
        patch_dir: Optional[Path] = None,
        patch_files: Optional[List[Path]] = None,
        config: Optional[dict] = None
    ) -> bool:
        """
        Execute the complete patch application process with comprehensive validation and error handling.

        Coordinates the full patch application workflow including source directory validation,
        patch file discovery from multiple sources, bash environment setup, and sequential
        patch application. Provides detailed logging and error reporting for each step.

        Parameters:
            source_dir (Path): Target directory where source code is located and patches should be applied
            patch_dir (Optional[Path]): Directory containing patch files to discover and apply
            patch_files (Optional[List[Path]]): Explicit list of patch files to apply, bypassing discovery
            config (Optional[dict]): Library configuration dictionary used for library-specific patch discovery

        Returns:
            bool: True if all patches were applied successfully or no patches were found,
                  False if any patch application failed or critical errors occurred
        """
        # Validate source directory exists
        if not source_dir.exists():
            RichLogger.error(f"Source directory not found: [bold red]{source_dir}[/bold red]")
            return False

        # Determine patch files to apply based on provided parameters
        patches = []
        if patch_files:
            patches = [p for p in patch_files if p.exists()]
            RichLogger.debug(f"Using explicitly provided patch files: [bold cyan]{len(patches)}[/bold cyan] files found")
        elif config and 'name' in config:
            patch_dir = ROOT_DIR / 'ports' / config['name']
            if patch_dir.exists():
                patches = sorted(patch_dir.glob('*.diff'))
                RichLogger.debug(f"Found patches from config: [bold cyan]{len(patches)}[/bold cyan] files in [bold cyan]{patch_dir}[/bold cyan]")
        elif patch_dir and patch_dir.exists():
            patches = sorted(patch_dir.glob('*.diff'))
            RichLogger.debug(f"Found patches from patch directory: [bold cyan]{len(patches)}[/bold cyan] files in [bold cyan]{patch_dir}[/bold cyan]")

        if not patches:
            return True

        # Find bash executable for patch application
        bash_path = BashUtils.find_bash()
        if not bash_path:
            RichLogger.error("Bash not found, cannot apply patches")
            return False
        RichLogger.debug(f"Using bash executable: [bold cyan]{bash_path}[/bold cyan]")

        # Apply patches one by one
        patch_status = True
        successful_patches = 0
        original_dir = Path.cwd()
        RichLogger.debug(f"Original working directory: [bold cyan]{original_dir}[/bold cyan]")

        try:
            # Change to source directory for patch application
            os.chdir(source_dir)
            for idx, patch in enumerate(patches, start=1):
                try:
                    RichLogger.info(f"Applying patch ([bold cyan]{idx}[/bold cyan]/[bold cyan]{len(patches)}[/bold cyan]): [bold cyan]{patch.name}[/bold cyan]")
                    # Convert Windows path to Unix path for compatibility
                    unix_patch_path = PathUtils.win_to_unix(patch)
                    if not Path(patch).exists():
                        RichLogger.error(f"Patch file not found: [bold red]{patch}[/bold red]")
                        patch_status = False
                        continue
                    # Build patch command
                    cmd = f"patch -Np1 -i \"{unix_patch_path}\""
                    RichLogger.debug(f"Executing patch command: [bold cyan]{cmd}[/bold cyan]")
                    # Execute patch command
                    p = subprocess.Popen(
                        [bash_path, "-c", cmd],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT
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
                        successful_patches += 1
                        RichLogger.debug(f"Successfully applied patch: [bold cyan]{patch.name}[/bold cyan]")
                    else:
                        RichLogger.error(f"Patch application failed: [bold red]{patch.name}[/bold red]")
                        RichLogger.debug(f"Command used: [bold cyan]{cmd}[/bold cyan]")
                        RichLogger.debug(f"Working directory: [bold cyan]{os.getcwd()}[/bold cyan]")
                        RichLogger.debug(f"Patch path: [bold cyan]{unix_patch_path}[/bold cyan]")
                        patch_status = False
                except Exception as e:
                    RichLogger.exception(f"Unexpected error applying patch {patch.name}: [bold red]{e}[/bold red]")
                    patch_status = False

            # Display patch application summary
            PatchHandler._show_patch_summary(len(patches), successful_patches)
            return patch_status

        except Exception as e:
            RichLogger.exception(f"Unexpected error during patch application: [bold red]{e}[/bold red]")
            return False
        finally:
            os.chdir(original_dir)
            RichLogger.debug(f"Restored original working directory: [bold cyan]{original_dir}[/bold cyan]")

    @staticmethod
    def _show_patch_summary(total: int, successful: int):
        """
        Generate and display a formatted summary of patch application results.

        Creates a visually appealing summary panel showing patch application statistics
        including total patches attempted, successful applications, and failures.
        Uses color coding and formatting to provide clear at-a-glance status information.

        Parameters:
            total (int): Total number of patch files attempted during the application process
            successful (int): Number of patches that were successfully applied without errors
        """
        failed = total - successful

        summary_text = Text.from_markup(
            f"Total Patches: [bold yellow]{total}[/bold yellow]"
            f" | Applied: [bold green]{successful}[/bold green]"
            f" | Failed: [bold red]{failed}[/bold red]",
            justify="center"
        )

        RichPanel.summary(
            content=summary_text,
            title="Patch Application Summary"
        )
