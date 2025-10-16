# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#

from rich.text import Text
from rich.table import Table
from rich import box

from mpt.core.log import RichLogger
from mpt.core.view import RichPanel


class CommandLineHelp:
    """Command line help display utility for MSVC Package Tool.

    Provides rich-formatted help information with comprehensive option
    descriptions and usage examples. Uses advanced table formatting and
    styling for improved user experience.
    """

    # Constants for table formatting
    OPTION_WIDTH = 20
    DESCRIPTION_WIDTH = 60
    EXAMPLES_WIDTH = 60

    @staticmethod
    def display_help():
        """
        Display comprehensive help information with rich formatting.

        Generates a complete help display with formatted tables for options
        and examples. Uses color coding, icons, and aligned columns for
        improved readability.
        """
        try:
            usage_text = Text("📝 Usage:\n", style="bold")
            usage_text.append("     mpt [OPTIONS] [LIBRARIES...]\n", style="bold green")
            RichLogger.print(usage_text)

            RichLogger.print("⚙️ Options:", style="bold")
            CommandLineHelp._display_options_table()

            RichLogger.print("🚀 Examples:", style="bold")
            CommandLineHelp._display_examples_table()

            RichLogger.print(
                "Default behavior: Install all libraries for x64 architecture",
                style="italic"
            )

            RichLogger.print(
                "For more information, visit: https://github.com/msvc-pkg",
                style="dim"
            )
        except Exception as e:
            RichLogger.exception(f"Error displaying help: {str(e)}")
            raise

    @staticmethod
    def _display_options_table():
        """
        Generate and display formatted table of command line options.

        Creates a rich-formatted table with aligned columns displaying all
        available command line options, their descriptions, and visual icons
        for improved user guidance.
        """
        try:
            options_table = Table(
                show_header=False,
                box=box.SIMPLE,
                min_width=80,
                show_lines=False
            )

            options_table.add_column("Option", style="bold cyan", no_wrap=True, width=CommandLineHelp.OPTION_WIDTH)
            options_table.add_column("Description", style="dim", justify="left", min_width=CommandLineHelp.DESCRIPTION_WIDTH)

            option_rows = [
                ("--install", "🛠️ Install specified libraries or all libraries"),
                ("--uninstall", "🚮 Uninstall specified libraries or all libraries"),
                ("--list", "📋 List installation status of libraries"),
                ("--dependency", "🌳 Show dependency tree for specified libraries"),
                ("--clean", "🧹 Clean build artifacts for specified libraries"),
                ("--fetch", "📥 Download source archives for specified libraries"),
                ("--<lib>-prefix PATH", "📚 Set library-specific installation prefix"),
                ("--arch ARCH", "🎯 Specify target architecture (x64 or x86)"),
                ("--add", "➕ Add and configure a new library with build system detection"),
                ("--remove", "➖ Remove library configuration files"),
                ("-h, --help", "💡 Show this help message and exit"),
                ("[LIBRARIES]", "📦 List of libraries to process (optional)")
            ]

            for option, description in option_rows:
                options_table.add_row(option, description)

            RichLogger.print(options_table)
        except Exception as e:
            RichLogger.exception(f"Error displaying options table: {str(e)}")
            raise

    @staticmethod
    def _display_examples_table():
        """
        Generate and display formatted table of usage examples.

        Creates a comprehensive table of common usage scenarios with
        example commands and their descriptions. Uses visual icons and
        consistent formatting for improved readability.
        """
        try:
            examples_table = Table(
                show_header=False,
                box=box.SIMPLE,
                min_width=150,
                show_lines=False,
                padding=(0, 1)
            )

            examples_table.add_column("Command", style="bold green", no_wrap=True, width=CommandLineHelp.EXAMPLES_WIDTH)
            examples_table.add_column("Description", style="italic", justify="left", min_width=CommandLineHelp.DESCRIPTION_WIDTH)

            example_rows = [
                ("mpt", "🔄 Install all libraries for x64 (default behavior)"),
                ("mpt --arch x86", "🔧 Install all libraries for x86 architecture"),
                ("mpt --add libjxl", "➕ Add and configure specific library with auto-detection"),
                ("mpt --add gmp fftw", "➕ Add multiple library configurations"),
                ("mpt --remove libjxl", "➖ Remove specific library configuration"),
                ("mpt --remove gmp fftw", "➖ Remove multiple library configurations"),
                ("mpt --install gmp fftw", "🧮 Install math libraries (GMP, FFTW) for x64"),
                ("mpt --install boost eigen", "📚 Install C++ libraries (Boost, Eigen) for x64"),
                ("mpt --install opencv vtk", "📷 Install computer vision libraries (OpenCV, VTK) for x64"),
                ("mpt --install llvm-project", "🔧 Install complex toolchain (LLVM) for x64"),
                ("mpt --install ffmpeg", "🎬 Install multimedia framework (FFmpeg) for x64"),
                ("mpt --install openssl curl", "📡 Install networking libraries (OpenSSL, cURL) for x64"),
                ("mpt --install --arch x86 gmp fftw", "🧮 Install math libraries for x86 architecture"),
                ("mpt --uninstall", "🗑️ Uninstall all libraries for x64"),
                ("mpt --arch x86 --uninstall gmp fftw", "🗑️ Uninstall specific libraries for x86"),
                ("mpt --list", "📋 List status of all libraries for x64"),
                ("mpt --list gmp fftw", "📋 List status of specific libraries"),
                ("mpt --dependency", "🌳 Show dependency tree for all libraries"),
                ("mpt --dependency gmp fftw", "🌿 Show dependency tree for specific libraries"),
                ("mpt --clean", "🧹 Clean artifacts for all libraries"),
                ("mpt --clean gmp fftw", "🧹 Clean artifacts for specific libraries"),
                ("mpt --fetch", "📥 Download sources for all libraries"),
                ("mpt --fetch gmp fftw", "📥 Download sources for specific libraries"),
                ("mpt --help", "📘 Display this help information"),
                ("mpt --llvm-project-prefix D:\\LLVM", "📚 Set library-specific prefix for LLVM"),
                ("mpt --install --perl-prefix D:\\Perl", "🐪 Install Perl with custom prefix"),
                # Advanced examples with complex libraries
                ("mpt --install llvm-project --arch x64", "🔧 Install LLVM toolchain for x64 (complex build)"),
                ("mpt --install boost --arch x86", "📚 Install Boost library for x86 (long build process)"),
                ("mpt --install opencv --arch x64", "📷 Install OpenCV computer vision library for x64"),
                ("mpt --install ffmpeg --arch x64", "🎬 Install FFmpeg multimedia framework for x64"),
                ("mpt --install vtk --arch x64", "📊 Install VTK visualization toolkit for x64"),
                ("mpt --install openssl --arch x64", "🔒 Install OpenSSL cryptography library for x64"),
                ("mpt --install ruby --arch x64", "💎 Install Ruby interpreter for x64"),
                ("mpt --install perl --arch x64", "🐪 Install Perl interpreter for x64"),
                ("mpt --install lua --arch x64", "🌙 Install Lua interpreter for x64"),
                ("mpt --install luajit --arch x64", "📚 Install LuaJIT interpreter for x64"),
                # Complex dependency examples
                ("mpt --install opencv --arch x64 --opencv-prefix D:\\opencv", "📷 Install OpenCV with custom prefix"),
                ("mpt --install ffmpeg --arch x64 --ffmpeg-prefix D:\\ffmpeg", "🎬 Install FFmpeg with custom prefix"),
                ("mpt --install llvm-project --arch x64 --llvm-project-prefix D:\\llvm", "🔧 Install LLVM with custom prefix"),
                ("mpt --install boost --arch x64 --boost-prefix D:\\boost", "📚 Install Boost with custom prefix"),
            ]

            for command, description in example_rows:
                examples_table.add_row(command, description)

            RichLogger.print(examples_table)

            # Add library categories information
            RichLogger.print("\n📚 Library Categories:", style="bold")
            categories_table = Table(
                show_header=False,
                box=box.SIMPLE,
                min_width=80,
                show_lines=False,
                padding=(0, 1)
            )

            categories_table.add_column("Category", style="bold cyan", no_wrap=True, width=20)
            categories_table.add_column("Examples", style="dim", justify="left", min_width=60)

            category_rows = [
                ("🧮 Math Libraries", "gmp, fftw, eigen, openblas, lapack"),
                ("📚 C++ Libraries", "boost, fmt, spdlog, rapidjson, protobuf"),
                ("🎬 Multimedia", "ffmpeg, openh264, libvpx, opus, flac"),
                ("📷 Graphics", "opencv, vtk, filament, mesa, vulkan"),
                ("📦 Compression", "zlib, brotli, bzip2, lz4, zstd"),
                ("📡 Networking", "curl, c-ares, grpc, nghttp2, libssh2"),
                ("🔧 Development", "llvm-project, cmake, nasm, doxygen, cppcheck"),
                ("🐪 System", "openssl, libiconv, gettext, perl, ruby")
            ]

            for category, examples in category_rows:
                categories_table.add_row(category, examples)

            RichLogger.print(categories_table)

            RichLogger.print(
                "\n💡 Tip: Use 'mpt --list' to see all available libraries and their status",
                style="italic"
            )

            # Add advanced usage tips
            RichLogger.print("\n🔧 Advanced Usage Tips:", style="bold")
            tips_table = Table(
                show_header=False,
                box=box.SIMPLE,
                min_width=80,
                show_lines=False,
                padding=(0, 1)
            )

            tips_table.add_column("Tip", style="bold cyan", no_wrap=True, width=20)
            tips_table.add_column("Description", style="dim", justify="left", min_width=60)

            tip_rows = [
                ("📚 Library Prefix", "Use --<lib>-prefix for library-specific installation paths"),
                ("🌳 Dependency Tree", "Use --dependency to visualize library dependencies"),
                ("🧹 Clean Builds", "Use --clean to remove build artifacts before rebuilding"),
                ("📥 Source Download", "Use --fetch to download sources without building"),
                ("🎯 Cross-Compilation", "Use --arch to specify target architecture (x64/x86)"),
            ]

            for tip, description in tip_rows:
                tips_table.add_row(tip, description)

            RichLogger.print(tips_table)

        except Exception as e:
            RichLogger.exception(f"Error displaying examples table: {str(e)}")
            raise
