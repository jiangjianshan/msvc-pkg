# -*- coding: utf-8 -*-
#
# Copyright (c) 2024 Jianshan Jiang
#

import sys
from typing import NoReturn

from yaml import SafeDumper

from mpt.action import ActionHandler
from mpt.cli import CommandLineParser
from mpt.runtime import RuntimeManager
from mpt.log import RichLogger


def main() -> NoReturn:
    """
    Main entry point for the library management application.

    Orchestrates the complete application workflow with comprehensive error handling
    and resource management. The execution flow includes:

    1. Logging system initialization
    2. YAML output configuration
    3. System dependency validation
    4. Command line argument parsing
    5. User configuration updates (if needed)
    6. Action execution based on user input
    7. Proper exit code reporting

    This function ensures proper cleanup and consistent behavior across all execution paths.
    """
    # Initialize logging first to capture all application events
    RichLogger.initialize()

    # Configure YAML output for consistent null representation
    _configure_yaml_output()

    # Validate system dependencies before proceeding
    if not _check_system_dependencies():
        sys.exit(1)

    # Parse command line arguments
    triplet, action, libraries, lib_prefixes = CommandLineParser.parse_arguments()

    # Update user configuration if library prefixes are provided
    _update_user_configuration(lib_prefixes)

    # Execute the requested action
    success = _execute_action(triplet, action, libraries)

    # Exit with appropriate status code
    sys.exit(0 if success else 1)


def _configure_yaml_output() -> None:
    """Configure YAML dumper for consistent null value representation."""
    SafeDumper.add_representer(
        type(None),
        lambda dumper, value: dumper.represent_scalar('tag:yaml.org,2002:null', '')
    )


def _check_system_dependencies() -> bool:
    """
    Validate and install required system dependencies.

    Returns:
        bool: True if dependencies are satisfied, False otherwise
    """
    if not RuntimeManager.check_and_install():
        RichLogger.critical("System dependency check failed. Application cannot continue.")
        return False
    return True


def _update_user_configuration(lib_prefixes: dict) -> None:
    """
    Update user configuration with library prefixes if provided.

    Args:
        lib_prefixes: Dictionary of library prefixes to write to configuration
    """
    if not lib_prefixes:
        return

    RichLogger.debug("Writing library prefixes to user configuration")
    try:
        from mpt.config import UserConfig
        UserConfig.dump({"lib_prefixes": lib_prefixes})
    except Exception as e:
        RichLogger.exception("Failed to write library prefixes to user configuration")
        # Non-critical error - continue execution


def _execute_action(triplet: str, action: str, libraries: list) -> bool:
    """
    Execute the requested action with the given parameters.

    Args:
        triplet: Target triplet (e.g., x64-windows)
        action: Action to perform
        libraries: List of libraries to process

    Returns:
        bool: True if action completed successfully, False otherwise
    """
    handler = ActionHandler(triplet, libraries)

    if not _dispatch_action(handler, action):
        RichLogger.error(f"Action '{action}' failed.")
        return False
    return True


def _dispatch_action(handler: ActionHandler, action: str) -> bool:
    """
    Route to the appropriate action handler method.

    Args:
        handler: Initialized ActionHandler instance
        action: Action identifier string

    Returns:
        bool: True if action executed successfully, False otherwise

    Raises:
        SystemExit: If unsupported action is requested
    """
    action_mapping = {
        'install': handler.install,
        'uninstall': handler.uninstall,
        'list': handler.list,
        'dependency': handler.dependency,
        'fetch': handler.fetch,
        'clean': handler.clean,
        'add': handler.add,
        'remove': handler.remove
    }

    if action not in action_mapping:
        RichLogger.error(f"Unsupported action: {action}")
        return False

    return action_mapping[action]()

if __name__ == "__main__":
    main()
