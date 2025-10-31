# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import argparse
import re
import sys
from typing import Dict, List, Tuple

from rich.text import Text
from rich.table import Table
from rich import box

from mpt import ROOT_DIR
from mpt.config import LibraryConfig
from mpt.help import CommandLineHelp
from mpt.log import RichLogger
from mpt.view import RichPanel


class CommandLineParser:
    """Command line interface parser for MSVC Package Tool.

    Provides comprehensive argument parsing, validation, and help display for
    the MSVC Package Tool. Supports multiple actions, architecture
    selection, and library-specific settings with rich formatted output and
    detailed error reporting.
    """

    @staticmethod
    def parse_arguments() -> Tuple[str, str, List[str], Dict[str, str]]:
        """
        Parse and validate command line arguments for the MSVC Package Tool.

        Processes command line inputs including actions, target architecture,
        library selection, and library-specific settings.
        Provides comprehensive error handling and validation with user-friendly
        error messages and formatted help output.

        Returns:
            Tuple containing parsed and validated arguments:
            - architecture: Target architecture specification ('x64' or 'x86')
            - action: Requested operation ('install', 'uninstall', 'list', etc.)
            - libraries: List of library names to process
            - lib_prefixes: Dictionary of library-specific prefix paths

        Raises:
            SystemExit: Terminates application with appropriate exit code on
                       validation errors or help requests
        """
        parser = CommandLineParser._create_parser()
        args, unknown_args = parser.parse_known_args()
        lib_prefixes = CommandLineParser._process_unknown_args(unknown_args)
        if args.help:
            CommandLineHelp.display_help()
            sys.exit(0)
        action = CommandLineParser._determine_action(args)
        # Skip library validation for 'add' action
        if action == 'add' or action == 'remove':
            libraries = args.libraries
        else:
            libraries = CommandLineParser._validate_libraries(args.libraries)
        return args.triplet, action, libraries, lib_prefixes

    @staticmethod
    def _create_parser() -> argparse.ArgumentParser:
        """
        Create and configure the argument parser with all supported options.

        Constructs a comprehensive argument parser with mutually exclusive
        action flags, architecture selection, prefix configuration, and
        library specification. Uses custom formatting for improved help display.

        Returns:
            argparse.ArgumentParser: Fully configured argument parser instance
                                    with all MSVC-PKG command line options
        """
        try:
            parser = argparse.ArgumentParser(
                prog='mpt',
                description="MSVC Package Tool",
                formatter_class=argparse.RawTextHelpFormatter,
                add_help=False,
                epilog="Default behavior: Install all libraries for x64 architecture"
            )

            action_group = parser.add_mutually_exclusive_group(required=False)

            actions = [
                ('--install', 'Install specified libraries or all libraries if none specified'),
                ('--uninstall', 'Uninstall specified libraries or all libraries if none specified'),
                ('--list', 'List installation status of specified libraries or all libraries if none specified'),
                ('--dependency', 'Show dependency tree for specified libraries or all libraries if none specified'),
                ('--fetch', 'Fetch source code for specified libraries or all libraries if none specified'),
                ('--clean', 'Clean build artifacts for specified libraries or all libraries if none specified'),
                ('--add', 'Add and configure a new library with automatic build system detection'),
                ('--remove', 'Remove library configuration files')
            ]

            for arg, help_text in actions:
                action_group.add_argument(arg, action='store_true', help=help_text)

            parser.add_argument(
                '--triplet',
                default='x64-windows',
                help="Specify target triplet in format {arch}-{os} (default: x64-windows)"
            )

            parser.add_argument(
                '-h', '--help',
                action='store_true',
                help="Show this help message and exit"
            )

            parser.add_argument(
                'libraries',
                nargs='*',
                default=[],
                help="List of libraries to process (optional)"
            )

            return parser
        except Exception as e:
            RichLogger.exception(f"Failed to create argument parser: {str(e)}")
            raise

    @staticmethod
    def _process_unknown_args(unknown_args: List[str]) -> Dict[str, str]:
        """
        Process unrecognized arguments for library-specific prefix configuration.

        Parses arguments following the --<library>-prefix pattern to extract
        library-specific installation paths. Validates argument format and
        provides detailed error messages for malformed inputs.

        Args:
            unknown_args: List of arguments not recognized by the main parser

        Returns:
            Dictionary mapping library names to their custom prefix paths

        Raises:
            SystemExit: Terminates application with error code on malformed
                       prefix arguments or missing path values
        """
        try:
            lib_prefixes = {}
            pattern = re.compile(r'^--(.+)-prefix$')
            i = 0

            while i < len(unknown_args):
                arg = unknown_args[i]
                match = pattern.match(arg)

                if match:
                    lib_name = match.group(1)
                    if i + 1 < len(unknown_args) and not unknown_args[i+1].startswith('--'):
                        lib_prefixes[lib_name] = unknown_args[i+1]
                        i += 2
                        continue
                    else:
                        RichLogger.error(f"Missing path for argument: {arg}")
                        sys.exit(1)
                else:
                    RichLogger.error(f"Unrecognized argument: {arg}")
                    sys.exit(1)

                i += 1

            return lib_prefixes
        except Exception as e:
            RichLogger.exception(f"Error processing unknown arguments: {str(e)}")
            sys.exit(1)

    @staticmethod
    def _determine_action(args) -> str:
        """
        Determine the primary action based on parsed argument flags.

        Evaluates mutually exclusive action flags to identify the requested
        operation. Defaults to 'install' if no explicit action is specified.

        Args:
            args: Parsed arguments object containing action flags

        Returns:
            String representing the determined action ('install', 'uninstall',
            'list', 'dependency', 'fetch', or 'clean')
        """
        try:
            action_mapping = {
                'install': args.install,
                'uninstall': args.uninstall,
                'list': args.list,
                'dependency': args.dependency,
                'fetch': args.fetch,
                'clean': args.clean,
                'add': args.add,
                'remove': args.remove
            }

            for action, flag in action_mapping.items():
                if flag:
                    return action

            return 'install'
        except Exception as e:
            RichLogger.exception(f"Error determining action: {str(e)}")
            sys.exit(1)

    @staticmethod
    def _validate_libraries(requested_libs: List[str]) -> List[str]:
        """
        Validate requested library names against available libraries.

        Checks if specified libraries exist in the library configuration system.
        Provides case-insensitive matching and detailed error output with available
        library listings when invalid library names are detected.

        Args:
            requested_libs: List of library names provided by the user

        Returns:
            List of validated library names for processing

        Raises:
            SystemExit: Terminates application with error code when invalid
                       library names are detected, displaying formatted
                       error message with available options
        """
        try:
            all_libs = list(LibraryConfig.load_all().keys())
            libraries = requested_libs or all_libs

            if not libraries:
                return all_libs

            # Case-insensitive validation
            lib_lower_map = {lib.lower(): lib for lib in all_libs}
            validated_libs = []
            invalid_libs = []

            for lib in libraries:
                if (original_case := lib_lower_map.get(lib.lower())):
                    validated_libs.append(original_case)
                else:
                    invalid_libs.append(lib)

            if invalid_libs:
                content = Text()
                content.append("Invalid libraries:\n", style="red")
                content.append("   " + " ".join(invalid_libs), style="bold red")
                content.append("\n\nAvailable libraries:\n", style="bold green")

                for i in range(0, len(all_libs), 8):
                    content.append("   " + " ".join(all_libs[i:i+8]) + "\n", style="cyan")

                RichPanel.summary(content=content, title="Library Summary")
                sys.exit(1)

            return validated_libs
        except Exception as e:
            RichLogger.exception(f"Error validating libraries: {str(e)}")
            sys.exit(1)
