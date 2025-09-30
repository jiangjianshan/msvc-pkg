# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#

import os
import sys

from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from rich import box
from rich.align import Align
from rich.console import Group
from rich.padding import Padding
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from textwrap import shorten

from mpt import ROOT_DIR
from mpt.config.loader import PackageConfig
from mpt.core.build import BuildManager
from mpt.core.clean import CleanManager
from mpt.core.console import console
from mpt.core.dependency import DependencyResolver
from mpt.core.git import GitHandler
from mpt.core.history import HistoryManager
from mpt.core.log import Logger
from mpt.core.run import Runner
from mpt.core.source import SourceManager
from mpt.core.view import RichTable, RichPanel


class ActionHandler:
    def __init__(self, arch, libraries):
        """Initialize ActionHandler with target architecture and library list.

        Args:
            arch: Target architecture for library operations
            libraries: List of library names to process
        """
        self.arch = arch
        self.libraries = libraries
        self.terminal_width = console.width

    def _status_icon(self, success: bool) -> str:
        """Generate a rich-formatted status icon based on operation success.

        Args:
            success: Boolean indicating operation success status

        Returns:
            str: Rich-formatted status icon string
        """
        return "[bold green]✓[/bold green]" if success else "[bold red]✗[/bold red]"

    def _shorten_path(self, path: str, max_len: int) -> str:
        """Shorten file path for display with ellipsis placeholder.

        Args:
            path: Original file path to shorten
            max_len: Maximum allowed length for display

        Returns:
            str: Shortened path with ellipsis if needed
        """
        return shorten(path, width=max_len, placeholder="...") if path != "N/A" else path

    def _create_summary_table(self) -> Table:
        """Create a base summary table with consistent styling.

        Returns:
            Table: Pre-configured Rich table instance
        """
        return RichTable.create()

    def _render_summary_panel(self, title: str, table: Table, stats_text: Text,
                             extra_content: Optional[Text] = None) -> None:
        """Render a formatted summary panel with table and statistics.

        Args:
            title: Panel title text
            table: Table instance to display
            stats_text: Text object containing statistics
            extra_content: Optional additional content to display below stats
        """
        content = stats_text
        if extra_content:
            content = Group(stats_text, Padding(extra_content, (1, 0)))

        RichPanel.summary(
            content=content,
            title=f"[bold]{title}[/bold]",
            table=table,
            width=self.terminal_width,
            title_align="center"
        )

    def _get_stats_text(self, total: int, success: int, action: str) -> Text:
        """Generate formatted statistics text for summary display.

        Args:
            total: Total number of operations attempted
            success: Number of successful operations
            action: Action name for display in statistics

        Returns:
            Text: Rich-formatted statistics text
        """
        return Text.from_markup(
            f"📋 Total Libraries: [bold yellow]{total}[/bold yellow]"
            f" | ✅ {action}: [bold green]{success}[/bold green]"
            f" | ❌ Failed: [bold red]{total - success}[/bold red]",
            justify="center"
        )

    def clean(self) -> bool:
        """Clean build artifacts for specified libraries with detailed summary.

        Removes logs, source directories, and archive files for each library.
        Displays a comprehensive summary table of cleaning operations.

        Returns:
            bool: True if all cleaning operations succeeded, False otherwise
        """
        clean_table = self._create_summary_table()
        RichTable.add_column(clean_table, "📁 Library", style="cyan", header_style="bold cyan", justify="left")
        RichTable.add_column(clean_table, "📝 Log", style="green", header_style="bold green", justify="center")
        RichTable.add_column(clean_table, "📂 Source", style="yellow", header_style="bold yellow", justify="center", no_wrap=False)
        RichTable.add_column(clean_table, "📦 Archive", style="magenta", header_style="bold magenta", justify="center", no_wrap=False)
        RichTable.add_column(clean_table, "✅ Status", style="blue", header_style="bold blue", justify="left")

        overall_success = True
        success_count = 0
        max_path_width = self.terminal_width // 5

        for lib in self.libraries:
            try:
                # Clean library artifacts
                clean_result = CleanManager.clean_library(lib)
                log_success, log_path = clean_result['logs']
                source_success, source_path = clean_result['source']
                archive_success, archive_path = clean_result['archives']

                # Shorten paths for display
                log_display = self._shorten_path(log_path, max_path_width)
                source_display = self._shorten_path(source_path, max_path_width)
                archive_display = self._shorten_path(archive_path, max_path_width) if not clean_result['is_git'] else "N/A"

                # Check if all cleaning operations were successful
                lib_success = all([log_success, source_success, archive_success])
                if lib_success:
                    success_count += 1
                else:
                    overall_success = False

                # Create status text with appropriate color
                status_text = "[bold green]Success[/bold green]" if lib_success else "[bold red]Failed[/bold red]"

                # Add row to the table
                RichTable.add_row(clean_table,
                    f"[cyan]{lib}[/cyan]",
                    log_display if log_path != "N/A" else self._status_icon(log_success),
                    source_display if source_path != "N/A" else self._status_icon(source_success),
                    archive_display if archive_path != "N/A" else self._status_icon(archive_success),
                    status_text
                )
            except Exception as e:
                Logger.exception(f"Error cleaning library {lib}")
                overall_success = False
                # Add error row to the table
                RichTable.add_row(clean_table,
                    f"[cyan]{lib}[/cyan]",
                    "[red]Error[/red]",
                    "[red]Error[/red]",
                    "[red]Error[/red]",
                    "[bold red]Failed[/bold red]"
                )

        # Render summary panel
        stats_text = self._get_stats_text(len(self.libraries), success_count, "Cleaned")
        self._render_summary_panel("🧹 Clean Summary", clean_table, stats_text)
        return overall_success

    def install(self) -> bool:
        """Install libraries with dependency resolution and build process.

        Resolves dependencies and builds each library. Displays installation
        status summary with success/failure indicators.

        Returns:
            bool: True if all installations succeeded, False otherwise
        """
        install_table = self._create_summary_table()
        RichTable.add_column(install_table, "📁 Library", style="cyan", header_style="bold cyan", justify="left")
        RichTable.add_column(install_table, "📦 Status", style="green", header_style="bold green", justify="center")

        overall_success = True
        success_count = 0

        for lib in self.libraries:
            try:
                # Resolve dependencies and build library
                dep_success = DependencyResolver.resolve(lib, self.arch, build=True)

                if not dep_success:
                    status = "[bold red]Failed[/bold red]"
                    overall_success = False
                    Logger.error(f"Installation failed for library [cyan]{lib}[/cyan]")
                else:
                    status = "[bold green]Installed[/bold green]"
                    success_count += 1
                    Logger.info(f"Successfully installed library [cyan]{lib}[/cyan]")

                # Add row to the table
                RichTable.add_row(install_table,
                    f"[cyan]{lib}[/cyan]",
                    status
                )
            except Exception as e:
                Logger.exception(f"Error installing library {lib}")
                overall_success = False
                # Add error row to the table
                RichTable.add_row(install_table,
                    f"[cyan]{lib}[/cyan]",
                    "[bold red]Failed[/bold red]"
                )

        # Render summary panel
        stats_text = self._get_stats_text(len(self.libraries), success_count, "Installed")
        self._render_summary_panel("📦 Installation Summary", install_table, stats_text)

        return overall_success

    def uninstall(self) -> bool:
        """Uninstall libraries by removing installation records.

        Removes library records from history and displays uninstallation
        summary with status for each library.

        Returns:
            bool: True if all libraries were successfully uninstalled, False otherwise
        """
        uninstall_table = self._create_summary_table()
        RichTable.add_column(uninstall_table, "📁 Library", style="cyan", header_style="bold cyan", justify="left")
        RichTable.add_column(uninstall_table, "📦 Status", style="green", header_style="bold green", justify="center")

        success_count = 0
        for lib in self.libraries:
            try:
                # Remove library records
                files_removed = HistoryManager.remove_record(self.arch, lib)
                if files_removed > 0:
                    status = "[bold green]Uninstalled[/bold green]"
                    success_count += 1
                    Logger.info(f"Successfully uninstalled library [cyan]{lib}[/cyan]")
                else:
                    status = "[bold red]Not installed[/bold red]"
                    Logger.warning(f"Library [cyan]{lib}[/cyan] was not installed")

                # Add row to the table
                RichTable.add_row(uninstall_table,
                    f"[cyan]{lib}[/cyan]",
                    status
                )
            except Exception as e:
                Logger.exception(f"Error uninstalling library {lib}")
                # Add error row to the table
                RichTable.add_row(uninstall_table,
                    f"[cyan]{lib}[/cyan]",
                    "[bold red]Failed[/bold red]"
                )

        # Render summary panel
        stats_text = self._get_stats_text(len(self.libraries), success_count, "Uninstalled")
        self._render_summary_panel("🗑️ Uninstallation Summary", uninstall_table, stats_text)
        return success_count == len(self.libraries)

    def list(self) -> bool:
        """Display comprehensive status information for libraries.

        Shows installation status, version information, last build time,
        and update availability for each library in a formatted table.

        Returns:
            bool: Always returns True (operation doesn't fail on display)
        """
        arch_records = HistoryManager.get_arch_records(self.arch)

        list_table = self._create_summary_table()
        RichTable.add_column(list_table, "📁 Library", style="cyan", header_style="bold cyan", justify="left")
        RichTable.add_column(list_table, "📝 Status", style="green", header_style="bold green", justify="center")
        RichTable.add_column(list_table, "📦 Version", style="yellow", header_style="bold yellow", justify="center", no_wrap=False)
        RichTable.add_column(list_table, "🕒 Last Built", style="magenta", header_style="bold magenta", justify="center", no_wrap=False)

        installed_count = 0
        not_installed_count = 0
        update_available_count = 0
        ignore_count = 0

        for lib in self.libraries:
            config = PackageConfig.load(lib)

            if not config.get('run'):
                ignore_count += 1
                RichTable.add_row(list_table,
                    f"[bold cyan]{lib}[/bold cyan]",
                    "[bold blue]Ignore[/bold blue]",
                    f"[bold yellow]{config.get('version', 'unknown')}[/bold yellow]",
                    "N/A"
                )
                continue

            installed = lib in arch_records
            Logger.debug(f"Library [cyan]{lib}[/cyan] installation status: [yellow]{installed}[/yellow]")

            status_display = "[bold yellow]Error[/bold yellow]"
            version = "N/A"
            last_built = "N/A"

            if not installed:
                not_installed_count += 1
                status_display = "[bold red]Not Installed[/bold red]"
                version = f"[bold yellow]{config.get('version', 'unknown')}[/bold yellow]"
            else:
                installed_count += 1
                lib_info = arch_records[lib]

                time_val = lib_info.get('built')
                if isinstance(time_val, datetime):
                    built_time = time_val
                elif isinstance(time_val, str):
                    try:
                        built_time = datetime.fromisoformat(time_val)
                    except ValueError:
                        built_time = None
                else:
                    built_time = None

                lib_ver = lib_info.get('version')
                lib_built = built_time

                current_version = config.get('version', 'unknown')
                if current_version != lib_ver:
                    update_available_count += 1
                    status_display = "[bold yellow]Update Available[/bold yellow]"
                else:
                    status_display = "[bold green]Installed[/bold green]"

                if lib_ver is not None:
                    version = f"[bold yellow]{lib_ver}[/bold yellow]"
                else:
                    version = "[bold yellow]N/A[/bold yellow]"

                if lib_built:
                    last_built = lib_built.strftime("%Y-%m-%d %H:%M")
                else:
                    last_built = "[bold yellow]Unknown[/bold yellow]"

            RichTable.add_row(list_table,
                f"[bold cyan]{lib}[/bold cyan]",
                status_display,
                version,
                last_built
            )

        stats_text = Text.from_markup(
            f"📋 Total Libraries: [bold yellow]{len(self.libraries)}[/bold yellow] | "
            f"✅ Installed: [bold green]{installed_count}[/bold green] | "
            f"🔄 Update Available: [bold yellow]{update_available_count}[/bold yellow] | "
            f"❌ Not Installed: [bold red]{not_installed_count}[/bold red] | "
            f"🙈 Ignores: [bold blue]{ignore_count}[/bold blue]",
            justify="center"
        )

        self._render_summary_panel("📊 Library Status Summary", list_table, stats_text)

        if installed_count == 0:
            tip_text = Text.from_markup("💡 Use `mpt --install <library>` to install libraries.")
            RichPanel.summary(
                content=tip_text,
                title="Tip",
                border_style="blue",
                width=self.terminal_width
            )
        return True

    def dependency(self) -> bool:
        """Resolve and display dependency information without building.

        Analyzes and displays dependency trees for specified libraries
        without performing actual installation or build operations.

        Returns:
            bool: True if all dependency resolutions succeeded, False otherwise
        """
        overall_success = True
        for lib in self.libraries:
            try:
                # Resolve dependencies without building
                success = DependencyResolver.resolve(lib, self.arch, build=False)
                if not success:
                    overall_success = False
            except Exception as e:
                Logger.exception(f"Error resolving dependencies for library {lib}")
                overall_success = False
        return overall_success

    def fetch(self) -> bool:
        """Fetch library source code from repositories or archives.

        Retrieves source code for specified libraries,  and displays fetch operation summary.

        Returns:
            bool: True if all fetch operations succeeded, False otherwise
        """
        fetch_table = self._create_summary_table()
        RichTable.add_column(fetch_table, "📁 Library", style="cyan", header_style="bold cyan", justify="left")
        RichTable.add_column(fetch_table, "📂 Source", style="yellow", header_style="bold yellow", justify="center", no_wrap=False)
        RichTable.add_column(fetch_table, "📦 Status", style="green", header_style="bold green", justify="center")

        success_count = 0
        for lib in self.libraries:
            try:
                source_path = "N/A"
                status = "[bold red]Failed[/bold red]"

                # Load library configuration
                config = PackageConfig.load(lib)
                if not config:
                    Logger.error(f"Failed to load config for library [cyan]{lib}[/cyan]")
                    RichTable.add_row(fetch_table,
                        f"[bold cyan]{lib}[/bold cyan]",
                        "N/A",
                        "[bold red]Config error[/bold red]"
                    )
                    continue

                # Prepare environment variables and fetch source
                Runner.prepare_envvars(self.arch, lib)
                source_path = SourceManager.fetch_source(config)
                if not source_path or not source_path.exists():
                    Logger.error(f"Source acquisition failed for library [cyan]{lib}[/cyan]")
                    return False

                # Check if source fetching was successful
                if not source_path:
                    Logger.error(f"Failed to fetch source for library [cyan]{lib}[/cyan]")
                    status = "[bold red]Failed[/bold red]"
                else:
                    status = "[bold green]Success[/bold green]"
                    success_count += 1
                    Logger.info(f"Successfully fetched source for library [cyan]{lib}[/cyan]")

                # Add row to the table
                RichTable.add_row(fetch_table,
                    f"[bold cyan]{lib}[/bold cyan]",
                    f"[bold yellow]{source_path}[/bold yellow]" if source_path != "N/A" else "N/A",
                    status
                )
            except Exception as e:
                Logger.exception(f"Error fetching source for library {lib}")
                # Add error row to the table
                RichTable.add_row(fetch_table,
                    f"[bold cyan]{lib}[/bold cyan]",
                    "N/A",
                    "[bold red]Failed[/bold red]"
                )

        # Render summary panel
        stats_text = self._get_stats_text(len(self.libraries), success_count, "Fetched")
        self._render_summary_panel("📥 Fetch Summary", fetch_table, stats_text)
        return success_count == len(self.libraries)
