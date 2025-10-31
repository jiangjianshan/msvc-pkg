<div align="center">
  <h1>✨🚀 msforge 🚀✨</h1>
</div>

# Overview

`msforge` is an extremely lightweight library management system. It does not rely on environments like MinGW-w64, Cygwin, or WSL but is based on the native Windows MSVC/MSVC-like command-line toolchain, focusing on building Windows-native libraries from source. This project provides developers with a large number of pre-configured open-source library configurations and compilation scripts that have resolved build issues, including many libraries that are notoriously difficult to compile. `msforge` significantly simplifies the workflow for adding new libraries. This is the very purpose and principle behind `msforge`'s creation.

`msforge` adopts a flexible plugin-based architecture. Each library is an independent plugin, allowing deep customization of the build process. It features rich and colorful console and log file output, making it easy to troubleshoot build issues, and can handle complex dependency builds, including full support for scenarios like bootstrap builds.

The project is continuously evolving, and we welcome your contributions! If a library you need is not yet supported, you can https://github.com/jiangjianshan/msforge/issues or refer to the [Contribution Guide](#contribution-guide) to add the open-source library yourself.

# Quick Start

Getting started with `msforge` is very quite simple.

```bash
# 1. Clone the repository
git clone https://github.com/jiangjianshan/msforge.git
cd msforge

# 2. View all available commands and options
mpt --help

# 3. Compile and install all supported libraries for the x64 architecture on Windows from source (default behavior)
mpt
```

After installation, the libraries are built and ready for use in your projects. You can use the `--<library-name>-prefix` option to set a custom installation path for each library.

# Using `msforge`

`msforge` provides a simple, consistent command-line interface for all operations.

**Managing Libraries:**
```bash
# Install libraries (x64 is the default architecture)
mpt gettext gmp gsl glib fftw libxml2 llvm-project mpc mpfr OpenBLAS ncurses readline VTK
# Specify the x86 architecture on Windows
mpt --triplet x86-windows gettext gmp gsl glib fftw libxml2 llvm-project mpc mpfr OpenBLAS ncurses readline VTK

# Uninstall libraries
mpt --uninstall OpenCV
mpt --triplet x86-windows --uninstall gettext gmp gsl glib fftw libxml2 llvm-project mpc mpfr OpenBLAS ncurses readline VTK

# List the status of all or specific libraries
mpt --list
mpt --list gettext gmp gsl glib fftw libxml2 llvm-project mpc mpfr OpenBLAS ncurses readline VTK
```

**Understanding Dependencies:**
```bash
# Display a visual dependency tree
mpt --dependency
mpt --dependency gettext gmp gsl glib fftw libxml2 llvm-project mpc mpfr OpenBLAS ncurses readline VTK
```

**Advanced Operations:**
```bash
# Only download source code, do not build
mpt --fetch gettext gmp gsl glib fftw libxml2 llvm-project mpc mpfr OpenBLAS ncurses readline VTK

# Clean downloaded archives, extracted folders, and compilation/installation logs
mpt --clean
mpt --clean gettext gmp gsl glib fftw libxml2 llvm-project mpc mpfr OpenBLAS ncurses readline VTK

# Uninstall installed libraries
mpt --uninstall gettext gmp gsl glib fftw libxml2 llvm-project mpc mpfr OpenBLAS ncurses readline VTK

# Add a new library configuration
mpt --add <new-library-name>
```
For a complete list of commands and examples, run `mpt --help`.

# Core Features

- **Native MSVC Toolchain Support**: Deeply integrated with the MSVC/MSVC-like environment, patching GNU toolchains to conform to Windows library naming conventions.
- **Flexible Build System Support**: Not bound to a specific build system; supports Autotools, CMake, Meson, MSBuild, Makefile, etc.
- **Smart Dependency Management**: Automatically resolves complex dependencies, visualizes dependency trees, and supports circular dependencies and bootstrap scenarios.
- **Lightweight and Efficient**: Based on native Windows toolchains, no need for additional heavy environments, keeping the system clean.
- **Enhanced Build Experience**: Provides colored log output, incremental builds, patch application, and other practical features.

# Contribution Guide

`msforge` is an open-source project serving the community. It has successfully built a wide variety of open-source libraries and continues to expand. The complete list of supported libraries can be viewed via the `mpt --list` command. We greatly appreciate your contributions.

**Ways you can help:**
*   [Submit an issue](https://github.com/jiangjianshan/msforge/issues) to report bugs or suggest features.
*   [Add a new library](#adding-a-new-library) or fix existing ones.

### Adding a New Library

1.  **Prepare the configuration:**
    ```bash
    mpt --add <library-name>
    ```
2.  **Fetch the source code:**
    ```bash
    mpt --fetch <library-name>
    ```
3.  **Apply patches (if needed)**: Create `.diff` files for Windows-specific fixes.
4.  **Write the build script**: Create `build.bat` or `build.sh` in the `ports/<library-name>` directory. Refer to existing examples for guidance.
5.  **Test and submit:**
    ```bash
    mpt <library-name> # Build and test
    ```
    Then, submit a Pull Request containing your new `ports/<library-name>` directory.

For more details, refer to the existing library configurations in the `ports` directory.

# Resources

*   **Source Code & Library Configurations:** https://github.com/jiangjianshan/msforge
*   **Issues & Discussions:** https://github.com/jiangjianshan/msforge/issues