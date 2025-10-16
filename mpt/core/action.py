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
from rich.prompt import Prompt
from rich.table import Table
from rich.text import Text
from textwrap import shorten

from mpt import ROOT_DIR
from mpt.core.config import LibraryConfig
from mpt.core.library import LibraryManager
from mpt.core.build import BuildManager
from mpt.core.clean import CleanManager
from mpt.core.dependency import DependencyResolver
from mpt.core.git import GitHandler
from mpt.core.history import HistoryManager
from mpt.core.log import RichLogger
from mpt.core.source import SourceManager
from mpt.core.uninstall import UninstallManager
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
        self.terminal_width = RichLogger.get_console_width()

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

        Displays interactive options for cleaning operations and removes selected
        artifacts based on user choice. Shows a comprehensive summary table of
        cleaning operations.

        Returns:
            bool: True if all cleaning operations succeeded, False otherwise
        """
        # Display cleaning options to user
        clean_options = [
            "1. Delete only log files for libraries (Uninstall action need and recommend to keep it)",
            "2. Delete only compressed libraries (only for non-Git sources)",
            "3. Delete only source directories (cloned or extracted)",
            "4. Delete all: logs, compressed libraries, and source directories"
        ]

        choice_panel = Panel(
            "\n".join(clean_options),
            title="🧹 Cleaning Options",
            border_style="blue",
            width=self.terminal_width
        )
        RichLogger.print(choice_panel)

        # Get user choice
        choice = Prompt.ask(
            "Please select an option (1-4)",
            choices=["1", "2", "3", "4"],
            default="4"
        )

        # Create table based on selected option
        clean_table = RichTable.create()
        RichTable.add_column(clean_table, "📁 Library", style="cyan", header_style="bold cyan", justify="left")

        if choice in ["1", "4"]:
            RichTable.add_column(clean_table, "📝 Log", style="green", header_style="bold green", justify="center")
        if choice in ["2", "4"]:
            RichTable.add_column(clean_table, "📦 Archive", style="magenta", header_style="bold magenta", justify="center", no_wrap=False)
        if choice in ["3", "4"]:
            RichTable.add_column(clean_table, "📂 Source", style="yellow", header_style="bold yellow", justify="center", no_wrap=False)

        RichTable.add_column(clean_table, "✅ Status", style="blue", header_style="bold blue", justify="left")

        overall_success = True
        success_count = 0
        max_path_width = self.terminal_width // 5

        for lib in self.libraries:
            config = LibraryConfig.load(lib)
            # Perform cleaning based on user choice
            if choice == "1":
                clean_result = CleanManager.clean_logs(lib)
                log_success, log_path = clean_result
                source_success, source_path = True, "N/A"
                archive_success, archive_path = True, "N/A"
                lib_success = log_success
            elif choice == "2":
                clean_result = CleanManager.clean_archives(lib)
                archive_success, archive_path = clean_result
                log_success, log_path = True, "N/A"
                source_success, source_path = True, "N/A"
                lib_success = archive_success
            elif choice == "3":
                clean_result = CleanManager.clean_source(lib, config)
                source_success, source_path = clean_result
                log_success, log_path = True, "N/A"
                archive_success, archive_path = True, "N/A"
                lib_success = source_success
            else:  # choice == "4"
                clean_result = CleanManager.clean_library(lib)
                log_success, log_path = clean_result['logs']
                source_success, source_path = clean_result['source']
                archive_success, archive_path = clean_result['archives']
                lib_success = all([log_success, source_success, archive_success])

            # Shorten paths for display
            log_display = self._shorten_path(log_path, max_path_width) if choice in ["1", "4"] else "N/A"
            source_display = self._shorten_path(source_path, max_path_width) if choice in ["3", "4"] else "N/A"
            archive_display = self._shorten_path(archive_path, max_path_width) if choice in ["2", "4"] else "N/A"

            if lib_success:
                success_count += 1
            else:
                overall_success = False

            # Create status text with appropriate color
            status_text = "[bold green]Success[/bold green]" if lib_success else "[bold red]Failed[/bold red]"

            # Add row to the table with appropriate columns based on choice
            row_data = [f"[cyan]{lib}[/cyan]"]

            if choice in ["1", "4"]:
                row_data.append(log_display if log_path != "N/A" else self._status_icon(log_success))
            if choice in ["2", "4"]:
                row_data.append(archive_display if archive_path != "N/A" else self._status_icon(archive_success))
            if choice in ["3", "4"]:
                row_data.append(source_display if source_path != "N/A" else self._status_icon(source_success))

            row_data.append(status_text)
            RichTable.add_row(clean_table, *row_data)

        # Render summary panel with appropriate title based on choice
        action_name = {
            "1": "Log Cleaning",
            "2": "Archive Cleaning",
            "3": "Source Cleaning",
            "4": "Complete Cleaning"
        }[choice]

        stats_text = self._get_stats_text(len(self.libraries), success_count, "Cleaned")
        self._render_summary_panel(f"🧹 {action_name} Summary", clean_table, stats_text)

        return overall_success

    def install(self) -> bool:
        """Install libraries with dependency resolution and build process.

        Resolves dependencies and builds each library. Displays installation
        status summary with success/failure indicators.

        Returns:
            bool: True if all installations succeeded, False otherwise
        """
        install_table = RichTable.create()
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
                else:
                    status = "[bold green]Installed[/bold green]"
                    success_count += 1
                # Add row to the table
                RichTable.add_row(install_table,
                    f"[cyan]{lib}[/cyan]",
                    status
                )
            except Exception as e:
                RichLogger.exception(f"Error installing library {lib}")
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
        """Uninstall libraries by removing installation files and records.

        Removes library installation files using UninstallManager and removes
        library records from history. Displays uninstallation summary with
        status and deleted file count for each library.

        Returns:
            bool: True if all libraries were successfully uninstalled, False otherwise
        """
        uninstall_table = RichTable.create()
        RichTable.add_column(uninstall_table, "📁 Library", style="cyan", header_style="bold cyan", justify="left")
        RichTable.add_column(uninstall_table, "🚮 Files Removed", style="magenta", header_style="bold magenta", justify="center")
        RichTable.add_column(uninstall_table, "📦 Status", style="green", header_style="bold green", justify="center")

        success_count = 0
        total_removed = 0

        for lib in self.libraries:
            # Remove library installation files and records
            removed_count = UninstallManager.uninstall_library(self.arch, lib)
            if removed_count > 0:
                status = "[bold green]Success[/bold green]"
                success_count += 1
                total_removed += removed_count
                RichLogger.info(f"Successfully uninstalled library [cyan]{lib}[/cyan], removed {removed_count} files")
            else:
                status = "[bold red]Failed[/bold red]"
                removed_count = 0
                RichLogger.error(f"Failed to uninstall library [cyan]{lib}[/cyan]")

            # Add row to the table
            RichTable.add_row(uninstall_table,
                f"[cyan]{lib}[/cyan]",
                f"[magenta]{removed_count}[/magenta]",
                status
            )

        # Create statistics text with total removed files
        stats_text = Text.from_markup(
            f"📋 Total Libraries: [bold yellow]{len(self.libraries)}[/bold yellow]"
            f" | ✅ Uninstalled: [bold green]{success_count}[/bold green]"
            f" | ❌ Failed: [bold red]{len(self.libraries) - success_count}[/bold red]"
            f" | 🚮 Total Files Removed: [bold magenta]{total_removed}[/bold magenta]",
            justify="center"
        )

        # Render summary panel
        self._render_summary_panel("🚮 Uninstallation Summary", uninstall_table, stats_text)
        return success_count == len(self.libraries)

    def list(self) -> bool:
        """Display comprehensive status information for libraries.

        Shows installation status, version information, last build time,
        and update availability for each library in a formatted table.

        Returns:
            bool: Always returns True (operation doesn't fail on display)
        """
        arch_records = HistoryManager.get_arch_records(self.arch)

        list_table = RichTable.create()
        RichTable.add_column(list_table, "📁 Library", style="cyan", header_style="bold cyan", justify="left")
        RichTable.add_column(list_table, "📝 Status", style="green", header_style="bold green", justify="center")
        RichTable.add_column(list_table, "📦 Version", style="yellow", header_style="bold yellow", justify="center", no_wrap=False)
        RichTable.add_column(list_table, "🕒 Last Built", style="magenta", header_style="bold magenta", justify="center", no_wrap=False)

        installed_count = 0
        not_installed_count = 0
        update_available_count = 0
        ignore_count = 0

        for lib in self.libraries:
            config = LibraryConfig.load(lib)

            if not config.get('script'):
                ignore_count += 1
                RichTable.add_row(list_table,
                    f"[bold cyan]{lib}[/bold cyan]",
                    "[bold blue]Ignore[/bold blue]",
                    f"[bold yellow]{config.get('version', 'unknown')}[/bold yellow]",
                    "N/A"
                )
                continue

            installed = lib in arch_records
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
                RichLogger.exception(f"Error resolving dependencies for library {lib}")
                overall_success = False
        return overall_success

    def fetch(self) -> bool:
        """Fetch library source code from repositories or archives.

        Retrieves source code for specified libraries,  and displays fetch operation summary.

        Returns:
            bool: True if all fetch operations succeeded, False otherwise
        """
        fetch_table = RichTable.create()
        RichTable.add_column(fetch_table, "📁 Library", style="cyan", header_style="bold cyan", justify="left")
        RichTable.add_column(fetch_table, "📂 Source", style="yellow", header_style="bold yellow", justify="center", no_wrap=False)
        RichTable.add_column(fetch_table, "📦 Status", style="green", header_style="bold green", justify="center")

        success_count = 0
        for lib in self.libraries:
            try:
                source_path = "N/A"
                status = "[bold red]Failed[/bold red]"

                # Load library configuration
                config = LibraryConfig.load(lib)
                if not config:
                    RichLogger.error(f"Failed to load config for library [cyan]{lib}[/cyan]")
                    RichTable.add_row(fetch_table,
                        f"[bold cyan]{lib}[/bold cyan]",
                        "N/A",
                        "[bold red]Config error[/bold red]"
                    )
                    continue

                source_path = SourceManager.fetch_source(config)
                if not source_path or not source_path.exists():
                    RichLogger.error(f"Source acquisition failed for library [cyan]{lib}[/cyan]")
                    return False

                # Check if source fetching was successful
                if not source_path:
                    RichLogger.error(f"Failed to fetch source for library [cyan]{lib}[/cyan]")
                    status = "[bold red]Failed[/bold red]"
                else:
                    status = "[bold green]Success[/bold green]"
                    success_count += 1
                    RichLogger.info(f"Successfully fetched source for library [cyan]{lib}[/cyan]")

                # Add row to the table
                RichTable.add_row(fetch_table,
                    f"[bold cyan]{lib}[/bold cyan]",
                    f"[bold yellow]{source_path}[/bold yellow]" if source_path != "N/A" else "N/A",
                    status
                )
            except Exception as e:
                RichLogger.exception(f"Error fetching source for library {lib}")
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

    def add(self) -> bool:
        """Interactively create new library configurations.

        Guides the user through creating config.yaml files for new libraries
        with detailed prompts for each configuration option.

        Returns:
            bool: True if all libraries were successfully configured, False otherwise
        """
        add_table = RichTable.create()
        RichTable.add_column(add_table, "📁 Library", style="cyan", header_style="bold cyan", justify="left")
        RichTable.add_column(add_table, "📝 Status", style="green", header_style="bold green", justify="center")

        success_count = 0

        for lib in self.libraries:
            try:
                # Check if library already exists
                lib_dir = ROOT_DIR / 'ports' / lib
                if lib_dir.exists() and (lib_dir / "config.yaml").exists():
                    RichLogger.warning(f"Library [cyan]{lib}[/cyan] already exists. Skipping creation.")
                    RichTable.add_row(add_table,
                        f"[cyan]{lib}[/cyan]",
                        "[bold yellow]Skipped (Exists)[/bold yellow]"
                    )
                    continue

                # Use LibraryManager to interactively create config
                LibraryManager.add_library(lib)
                success_count += 1
                RichLogger.info(f"Successfully created configuration for library [cyan]{lib}[/cyan]")

                # Add success row to the table
                RichTable.add_row(add_table,
                    f"[cyan]{lib}[/cyan]",
                    "[bold green]Created[/bold green]"
                )

            except Exception as e:
                RichLogger.exception(f"Error creating configuration for library {lib}")
                # Add error row to the table
                RichTable.add_row(add_table,
                    f"[cyan]{lib}[/cyan]",
                    "[bold red]Failed[/bold red]"
                )

        # Render summary panel
        stats_text = self._get_stats_text(len(self.libraries), success_count, "Created")
        self._render_summary_panel("➕ Library Creation Summary", add_table, stats_text)

        # Display helpful tip if no libraries were created
        if success_count == 0:
            tip_text = Text.from_markup("💡 Use `mpt --add <library-name>` to create a new library configuration.")
            RichPanel.summary(
                content=tip_text,
                title="Tip",
                border_style="blue",
                width=self.terminal_width
            )

        return success_count > 0

    def remove(self) -> bool:
        """Remove library configurations with interactive confirmation.

        Guides the user through removing library configurations with
        detailed prompts for confirmation.

        Returns:
            bool: True if all libraries were successfully removed, False otherwise
        """
        remove_table = RichTable.create()
        RichTable.add_column(remove_table, "📁 Library", style="cyan", header_style="bold cyan", justify="left")
        RichTable.add_column(remove_table, "📝 Status", style="green", header_style="bold green", justify="center")

        success_count = 0

        for lib in self.libraries:
            try:
                # Use LibraryManager to remove library config
                if LibraryManager.remove_library(lib):
                    success_count += 1
                    RichLogger.info(f"Successfully removed configuration for library [cyan]{lib}[/cyan]")
                    # Add success row to the table
                    RichTable.add_row(remove_table,
                        f"[cyan]{lib}[/cyan]",
                        "[bold green]Removed[/bold green]"
                    )
                else:
                    # Add failure row to the table
                    RichTable.add_row(remove_table,
                        f"[cyan]{lib}[/cyan]",
                        "[bold red]Failed[/bold red]"
                    )

            except Exception as e:
                RichLogger.exception(f"Error removing configuration for library {lib}")
                # Add error row to the table
                RichTable.add_row(remove_table,
                    f"[cyan]{lib}[/cyan]",
                    "[bold red]Failed[/bold red]"
                )

        # Render summary panel
        stats_text = self._get_stats_text(len(self.libraries), success_count, "Removed")
        self._render_summary_panel("➖ Library Removal Summary", remove_table, stats_text)

        return success_count > 0
