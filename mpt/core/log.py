# -*- coding: utf-8 -*-
"""
Centralized logging utility for mpt package with markup support.
Provides enhanced logging capabilities including console/file output and markup rendering.

Copyright (c) 2024 Jianshan Jiang

"""

import logging
import os

from pathlib import Path

from rich.logging import RichHandler
from rich.traceback import install

from mpt.core.console import console

class Logger:
    """
    Centralized logging utility for MPT application with rich text formatting support.

    Provides a unified logging interface with enhanced capabilities including console
    and file output, markup rendering, and exception tracing. Built on the Rich library
    for beautiful terminal output and comprehensive logging features.
    """

    # Class variables for logging state
    _initialized = False
    _logger = logging.getLogger("mpt")
    _formatter = None
    _file_handler = None

    @classmethod
    def initialize(cls, log_level=logging.DEBUG):
        """
        Initialize and configure the application logging system with Rich formatting.

        Sets up the logging infrastructure including console output handlers, log level
        configuration, and traceback formatting. Handles user configuration loading
        and ensures proper cleanup of existing handlers to avoid duplication.

        Args:
            log_level (int, optional): Default logging level to use if not specified
                                      in user configuration. Defaults to DEBUG level.
        """
        if cls._initialized:
            return

        # Import here to avoid circular dependencies
        from mpt.config.loader import UserConfig

        # Load user configuration for logging settings
        user_settings = UserConfig.load()

        # Map string log levels to logging constants
        level_str = user_settings.get('level', 'debug').lower()
        valid_levels = {
            'debug': logging.DEBUG,
            'info': logging.INFO,
            'warning': logging.WARNING,
            'error': logging.ERROR,
            'critical': logging.CRITICAL
        }

        # Use configured level or default to DEBUG
        log_level = valid_levels.get(level_str, logging.DEBUG)
        cls._logger.setLevel(log_level)

        # Clean up any existing handlers
        for handler in cls._logger.handlers[:]:
            cls._logger.removeHandler(handler)
            handler.close()

        # Create RichHandler for enhanced console output with markup disabled
        console_handler = RichHandler(
            console=console,
            markup=False,
            show_level=False,
            show_path=False,
            show_time=False,
            rich_tracebacks=True,
            tracebacks_show_locals=True
        )

        # Configure formatter for log messages
        cls._formatter = logging.Formatter("%(message)s")
        console_handler.setFormatter(cls._formatter)
        cls._logger.addHandler(console_handler)

        # Install rich traceback handler for better exception reporting
        install(console=console, show_locals=True)

        # Mark logger as initialized
        cls._initialized = True

    @classmethod
    def add_file_logging(cls, log_file, level=logging.DEBUG):
        """
        Add file-based logging to complement console output with persistent storage.

        Configures a file handler to write log messages to disk alongside console output.
        Ensures proper directory creation and handles existing file handlers gracefully.
        Supports UTF-8 encoding for international character compatibility.

        Args:
            log_file (str or Path): Filesystem path where log messages should be written
            level (int): Minimum severity level for messages to be written to the file

        Note:
            Replaces any existing file handler to ensure only one file output is active
        """
        # Remove existing file handler if present
        cls.remove_file_logging()

        try:
            # Ensure directory exists
            log_dir = os.path.dirname(log_file)
            if log_dir:
                os.makedirs(log_dir, exist_ok=True)

            # Create file handler
            cls._file_handler = logging.FileHandler(log_file, mode='w', encoding='utf-8')
            cls._file_handler.setLevel(level)
            cls._file_handler.setFormatter(cls._formatter)

            # Add handler to logger
            cls._logger.addHandler(cls._file_handler)
        except Exception as e:
            cls._logger.error(f"Failed to add file logging: {e}")

    @classmethod
    def remove_file_logging(cls):
        """
        Remove file-based logging from the logging configuration.

        Safely detaches and closes the file handler to release file resources and
        stop writing log messages to disk. Handles cleanup even if no file handler
        is currently active.
        """
        if cls._file_handler:
            try:
                cls._logger.removeHandler(cls._file_handler)
                cls._file_handler.close()
            except Exception as e:
                cls._logger.error(f"Failed to remove file logging: {e}")
            finally:
                cls._file_handler = None

    @classmethod
    def debug(cls, msg, *args, markup=True, **kwargs):
        """
        Log a debug-level message with optional rich text formatting.

        Records detailed diagnostic information useful for debugging during development.
        Typically hidden in production environments unless debug logging is enabled.

        Args:
            msg: Primary message text to log
            *args: Additional positional arguments for message formatting
            markup (bool): If True, enables Rich markup parsing for styled output
            **kwargs: Additional keyword arguments passed to the underlying logger
        """
        if markup:
            kwargs['extra'] = {"markup": True}
        cls._logger.debug(msg, *args, **kwargs)

    @classmethod
    def info(cls, msg, *args, markup=True, **kwargs):
        """
        Log an informational message with optional rich text formatting.

        Records general operational information about application state and progress.
        Suitable for normal operation monitoring and status reporting.

        Args:
            msg: Primary message text to log
            *args: Additional positional arguments for message formatting
            markup (bool): If True, enables Rich markup parsing for styled output
            **kwargs: Additional keyword arguments passed to the underlying logger
        """
        if markup:
            kwargs['extra'] = {"markup": True}
        cls._logger.info(msg, *args, **kwargs)

    @classmethod
    def warning(cls, msg, *args, markup=True, **kwargs):
        """
        Log a warning message with optional rich text formatting.

        Records potentially harmful situations that don't prevent application operation
        but may indicate underlying issues that require attention.

        Args:
            msg: Primary message text to log
            *args: Additional positional arguments for message formatting
            markup (bool): If True, enables Rich markup parsing for styled output
            **kwargs: Additional keyword arguments passed to the underlying logger
        """
        if markup:
            kwargs['extra'] = {"markup": True}
        cls._logger.warning(msg, *args, **kwargs)

    @classmethod
    def error(cls, msg, *args, markup=True, **kwargs):
        """
        Log an error message with optional rich text formatting.

        Records serious issues that prevent specific operations from completing
        successfully but don't necessarily cause complete application failure.

        Args:
            msg: Primary message text to log
            *args: Additional positional arguments for message formatting
            markup (bool): If True, enables Rich markup parsing for styled output
            **kwargs: Additional keyword arguments passed to the underlying logger
        """
        if markup:
            kwargs['extra'] = {"markup": True}
        cls._logger.error(msg, *args, **kwargs)

    @classmethod
    def critical(cls, msg, *args, markup=True, **kwargs):
        """
        Log a critical error message with optional rich text formatting.

        Records severe issues that prevent the application from continuing normal
        operation and may require immediate administrative intervention.

        Args:
            msg: Primary message text to log
            *args: Additional positional arguments for message formatting
            markup (bool): If True, enables Rich markup parsing for styled output
            **kwargs: Additional keyword arguments passed to the underlying logger
        """
        if markup:
            kwargs['extra'] = {"markup": True}
        cls._logger.critical(msg, *args, **kwargs)

    @classmethod
    def exception(cls, msg, *args, markup=True, **kwargs):
        """
        Log an exception message with full stack trace and optional rich text formatting.

        Records error information along with complete stack trace details for
        debugging purposes. Automatically captures and includes exception context.

        Args:
            msg: Primary message text to log
            *args: Additional positional arguments for message formatting
            markup (bool): If True, enables Rich markup parsing for styled output
            **kwargs: Additional keyword arguments passed to the underlying logger
        """
        if markup:
            kwargs['extra'] = {"markup": True}
        cls._logger.exception(msg, *args, **kwargs)
