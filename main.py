# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#

import sys
from typing import Dict, List, Tuple, NoReturn

from yaml import SafeDumper

from mpt.core.action import ActionHandler
from mpt.core.cli import CommandLineParser
from mpt.core.runtime import RuntimeManager
from mpt.core.log import RichLogger


def main() -> NoReturn:
    """
    Primary application entry point orchestrating the complete package management workflow.

    Executes the full application lifecycle with comprehensive error handling and
    resource management. Coordinates all major system components including logging
    initialization, dependency verification, command line parsing, and action execution.
    Ensures proper cleanup and exit code reporting regardless of execution outcome.

    Workflow:
    1. Initialize structured logging system for execution tracking
    2. Configure YAML output formatting for consistent null representation
    3. Validate and install required system dependencies via RuntimeManager
    4. Parse command line arguments to determine execution parameters
    5. Write library prefixes to user configuration if provided
    6. Initialize action handler with parsed parameters
    7. Dispatch to appropriate action handler based on user request
    8. Log final execution status

    Note:
        This function serves as the central coordination point for all application
        components and ensures proper error handling and resource cleanup regardless
        of execution path outcome.
    """
    # Initialize application logging system first to capture all events
    RichLogger.initialize()
    RichLogger.debug("Main application logger initialized successfully.")

    # Configure YAML output once at the application level
    _configure_yaml_output()

    # Check and install required system dependencies
    RichLogger.debug("Starting system dependency check and installation process.")
    if not RuntimeManager.check_and_install():
        RichLogger.critical("Critical system dependency check failed. Application cannot continue.")
        sys.exit(1)

    RichLogger.info("System dependency validation completed successfully.")

    # Parse command line arguments to determine execution parameters
    RichLogger.debug("Parsing command line arguments.")
    arch, action, libraries, prefix, lib_prefixes = CommandLineParser.parse_arguments()
    RichLogger.debug(
        f"Arguments parsed: arch={arch}, action={action}, "
        f"libraries={libraries}, prefix={prefix}, "
        f"lib_prefixes_keys={list(lib_prefixes.keys())}"
    )

    # Write lib_prefixes to settings.yaml if not empty
    if lib_prefixes:
        RichLogger.debug("Writing library prefixes to user configuration")
        try:
            from mpt.config import UserConfig
            UserConfig.write({"lib_prefixes": lib_prefixes})
        except Exception as e:
            RichLogger.exception("Failed to write library prefixes to user configuration")
            # Continue execution as this is not critical

    # Initialize action handler with parsed parameters
    RichLogger.debug(f"Initializing ActionHandler for architecture: {arch}")
    handler = ActionHandler(arch, libraries)

    # Dispatch to appropriate action based on user request
    RichLogger.info(f"Executing action: {action}")
    success = _dispatch_action(handler, action)
    # Set final status and exit code
    if success:
        RichLogger.info(f"Action '[bold cyan]{action}[/bold cyan]' completed successfully.")
    else:
        RichLogger.error(f"Action '[bold cyan]{action}[/bold cyan]' failed.")

def _configure_yaml_output() -> None:
    """
    Configure YAML serialization behavior for consistent None value representation.

    Modifies the global YAML SafeDumper to represent Python None values as empty
    strings instead of 'null' literals. This ensures cleaner and more consistent
    YAML output throughout the application, particularly for configuration files
    and serialized data structures.

    Side Effects:
        Modifies the global SafeDumper class behavior for None type representation
        across all YAML serialization operations within the application

    Implementation:
        Uses SafeDumper.add_representer() to override the default None serialization
        behavior, replacing 'null' with empty string representation
    """
    try:
        SafeDumper.add_representer(
            type(None),
            lambda dumper, value: dumper.represent_scalar('tag:yaml.org,2002:null', '')
        )
        RichLogger.debug("YAML SafeDumper configured for null representation.")
    except Exception as e:
        RichLogger.exception("Failed to configure YAML SafeDumper")
        raise

def _dispatch_action(handler: ActionHandler, action: str) -> bool:
    """
    Route execution to the appropriate action handler method based on action type.

    Maps action names from command line arguments to corresponding handler methods.
    Provides validation for supported actions and ensures proper error handling for
    unsupported action requests.

    Args:
        handler: Initialized ActionHandler instance with configured architecture and libraries
        action: Action identifier string determining which handler method to invoke

    Returns:
        bool: True if the dispatched action executed successfully, False otherwise

    Raises:
        SystemExit: Terminates application with error code if unsupported action is requested

    Supported Actions:
        - install: Package installation with dependency resolution
        - uninstall: Package removal and cleanup
        - list: Package status listing and information display
        - dependency: Dependency tree visualization and analysis
        - fetch: Source code acquisition without building
        - clean: Build artifact removal and cleanup
    """
    try:
        action_methods = {
            'install': handler.install,
            'uninstall': handler.uninstall,
            'list': handler.list,
            'dependency': handler.dependency,
            'fetch': handler.fetch,
            'clean': handler.clean
        }

        action_func = action_methods.get(action)
        if action_func is None:
            RichLogger.critical(f"Unsupported action requested: '{action}'. This indicates a logic error in argument parsing or dispatch.")
            sys.exit(1)  # This should not happen if CLI parsing is correct

        RichLogger.debug(f"Dispatching to action handler method: {action_func.__name__}")
        return action_func()
    except Exception as e:
        RichLogger.exception(f"Exception occurred during action dispatch for '{action}'")
        return False


if __name__ == "__main__":
    main()
