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
from mpt.core.config import PackageConfig
from mpt.core.help import CommandLineHelp
from mpt.core.log import RichLogger
from mpt.core.view import RichPanel


class CommandLineParser:
    """Command line interface parser for MSVC Package Tool.

    Provides comprehensive argument parsing, validation, and help display for
    the MSVC Package Tool. Supports multiple actions, architecture
    selection, prefix configuration, and library-specific settings with rich
    formatted output and detailed error reporting.
    """

    @staticmethod
    def parse_arguments() -> Tuple[str, str, List[str], str, Dict[str, str]]:
        """
        Parse and validate command line arguments for the MSVC Package Tool.

        Processes command line inputs including actions, target architecture,
        library selection, prefix configuration, and library-specific settings.
        Provides comprehensive error handling and validation with user-friendly
        error messages and formatted help output.

        Returns:
            Tuple containing parsed and validated arguments:
            - architecture: Target architecture specification ('x64' or 'x86')
            - action: Requested operation ('install', 'uninstall', 'list', etc.)
            - libraries: List of library names to process
            - global_prefix: Global installation prefix path for all libraries
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
        return args.arch, action, libraries, args.prefix, lib_prefixes

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
                '--arch',
                choices=['x64', 'x86'],
                default='x64',
                help="Specify target architecture (default: x64)"
            )

            parser.add_argument(
                '--prefix',
                default=f"{ROOT_DIR}\\x64",
                help="Set global installation prefix for all libraries"
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
        Validate requested library names against available packages.

        Checks if specified libraries exist in the package configuration system.
        Provides detailed error output with available library listings when
        invalid library names are detected.

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
            all_libs = list(PackageConfig.load_all().keys())
            libraries = requested_libs or all_libs

            if not libraries:
                return all_libs

            invalid_libs = [lib for lib in libraries if lib not in all_libs]

            if invalid_libs:
                content = Text()
                content.append("Invalid libraries:\n", style="red")
                content.append("   " + " ".join(invalid_libs), style="bold red")
                content.append("\n\n")
                content.append("Available libraries:\n", style="bold green")

                libs_per_line = 8
                for i in range(0, len(all_libs), libs_per_line):
                    line_libs = all_libs[i:i + libs_per_line]
                    content.append("   " + " ".join(line_libs) + "\n", style="cyan")

                RichPanel.summary(
                    content=content,
                    title="Library Summary"
                )
                sys.exit(1)

            return libraries
        except Exception as e:
            RichLogger.exception(f"Error validating libraries: {str(e)}")
            sys.exit(1)
