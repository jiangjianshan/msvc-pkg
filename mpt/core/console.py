# -*- coding: utf-8 -*-
"""
Enhanced console output module with rich text formatting support.

Provides a pre-configured Console instance for consistent, styled terminal output
across the MSVC-PKG build system. This module ensures uniform text formatting,
color rendering, and terminal capabilities throughout the application.

Features:
- Truecolor support for vibrant, consistent color rendering
- Cross-platform terminal compatibility with forced terminal emulation
- Syntax highlighting for improved code and log readability
- Disabled file logging for clean console-only output
- Global accessibility for consistent styling across all modules

Copyright (c) 2024 Jianshan Jiang

"""

from rich.console import Console

"""
Initialize a global Console instance with enhanced terminal capabilities
Configured for maximum compatibility and visual consistency across platforms
Force terminal emulation ensures rich formatting even in basic terminals
Truecolor support provides 24-bit color depth for vibrant output
Syntax highlighting enhances readability of code snippets and structured data
Disabled file logging prevents unwanted output redirection to files
"""
console = Console(
    force_terminal=True,      # Ensure rich formatting in all terminal environments
    color_system="truecolor", # Enable 24-bit color support for vibrant output
    highlight=True,           # Apply syntax highlighting to code and structured text
    log_path=False            # Disable automatic logging to file for clean console output
)

# Define public interface for this module
# Exposes only the pre-configured console instance for consistent usage
__all__ = ['console']
