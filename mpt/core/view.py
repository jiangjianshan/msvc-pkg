# -*- coding: utf-8 -*-
"""
Rich UI components for creating and rendering tables and panels with enhanced styling.
This module provides utility classes for creating formatted tables and panels using the Rich library.

Copyright (c) 2024 Jianshan Jiang

"""

from rich.table import Table
from rich import box
from rich.panel import Panel
from rich.console import Group
from rich.text import Text
from rich.align import Align

from mpt.core.console import console
from mpt.core.log import Logger


class RichTable:
    """
    Advanced table rendering utility with comprehensive styling and formatting capabilities.

    Provides a high-level interface for creating and displaying richly formatted tables
    using the Rich library. Supports custom styling, alignment options, and responsive
    layout adjustments for optimal terminal display.
    """

    @staticmethod
    def create(show_header=True, header_style="bold", expand=False,
               box_style=box.ROUNDED, title=None):
        """
        Initialize a new Rich Table instance with comprehensive styling configuration.

        Creates a table object with customizable appearance settings including header visibility,
        border styling, expansion behavior, and optional title display. Provides consistent
        defaults for common table presentation scenarios.

        Args:
            show_header (bool): Controls whether column headers are displayed
            header_style (str): Text styling for header cells (e.g., "bold", "italic")
            expand (bool): Determines if table expands to fill available terminal width
            box_style: Border styling configuration using Rich box constants
            title (str): Optional title text displayed above the table

        Returns:
            Table: Configured Rich Table instance ready for column and row population
        """
        try:
            return Table(
                box=box_style,
                show_header=show_header,
                header_style=header_style,
                expand=expand,
                title=title
            )
        except Exception as e:
            Logger.exception("Failed to create Rich table")
            raise

    @staticmethod
    def add_column(table, column, style=None, header_style=None,
                  justify="left", no_wrap=True, width=None):
        """
        Add a formatted column to a table with comprehensive styling options.

        Configures and adds a single column to the specified table with control over
        text styling, alignment, wrapping behavior, and width constraints. Handles
        header styling inheritance and provides sensible defaults for common use cases.

        Args:
            table (Table): Table object to which the column will be added
            column (str): Header text for the column
            style (str): Text styling for column content cells
            header_style (str): Custom styling for column header (defaults to bold version of style)
            justify (str): Text alignment within column cells ("left", "center", "right")
            no_wrap (bool): Prevents text wrapping within column cells
            width (int): Fixed width constraint for the column (None for automatic sizing)
        """
        try:
            if not header_style:
                header_style = f"bold {style}" if style else "bold"

            table.add_column(
                column,
                style=style,
                header_style=header_style,
                justify=justify,
                no_wrap=no_wrap,
                width=width
            )
        except Exception as e:
            Logger.exception("Failed to add column to table")
            raise

    @staticmethod
    def add_row(table, *args, style=None):
        """
        Insert a new row of data into the table with optional row-wide styling.

        Adds a complete row of cell content to the table, supporting both individual
        cell values and optional uniform styling applied across all cells in the row.
        Handles variable argument length for flexible row population.

        Args:
            table (Table): Table object to receive the new row
            *args: Variable number of cell values for the row
            style (str): Optional styling applied uniformly to all cells in the row
        """
        try:
            table.add_row(*args, style=style)
        except Exception as e:
            Logger.exception("Failed to add row to table")
            raise

    @staticmethod
    def render(table, align_center=False, width=None):
        """
        Display the fully configured table in the terminal with optional alignment.

        Renders the completed table to the console output, with support for center
        alignment and custom width constraints. Automatically determines appropriate
        display width based on terminal dimensions when not explicitly specified.

        Args:
            table (Table): Fully configured table object ready for display
            align_center (bool): Centers the table within the terminal when True
            width (int): Optional width constraint for table rendering
        """
        try:
            if align_center:
                if not width:
                    width = console.width
                aligned_table = Align.center(table, width=width)
                console.print(aligned_table)
            else:
                console.print(table)
        except Exception as e:
            Logger.exception("Failed to render table")
            raise

class RichPanel:
    """
    Sophisticated panel rendering system for creating visually appealing information displays.

    Provides advanced panel creation capabilities with support for mixed content types,
    comprehensive styling options, and flexible layout configurations. Ideal for summary
    displays, status reports, and structured information presentation.
    """

    @staticmethod
    def summary(content, title="Summary", table=None,
               border_style="bold cyan", box_style=box.ROUNDED,
               padding=(0, 1), width=None, title_align="center", expand=False):
        """
        Create and display a comprehensive summary panel with optional tabular data.

        Constructs a richly formatted panel designed for summary information display,
        supporting combined table and text content with extensive styling control.
        Handles automatic width calculation, content grouping, and consistent styling
        for professional-looking output.

        Args:
            content: Primary textual content to display in the panel body
            title (str): Panel title text displayed in the header
            table (Table): Optional table to display above the main content
            border_style (str): Color and style specification for panel borders
            box_style: Box design configuration using Rich box constants
            padding (tuple): Internal spacing specification as (vertical, horizontal) pixels
            width (int): Optional fixed width for the panel (auto-calculated if None)
            title_align (str): Text alignment for the title ("left", "center", "right")
            expand (bool): Allows panel to expand to full available width when True
        """
        try:
            if width is None:
                width = console.width - 4
            if table is not None:
                elements = [
                    Align.center(table, width=width),
                    "",
                    content
                ]
                panel_content = Group(*elements)
            else:
                panel_content = content
            panel = Panel(
                panel_content,
                title=title,
                title_align=title_align,
                border_style=border_style,
                box=box_style,
                padding=padding,
                width=width,
                expand=expand
            )
            console.print(panel)
        except Exception as e:
            Logger.exception("Failed to create and render summary panel")
            raise
