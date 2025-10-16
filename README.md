<div align="center">
  <h1>✨🚀 msvc-pkg 🚀✨</h1>
</div>

# Overview

msvc-pkg is an extremely lightweight library management system. It does not rely on environments like MinGW-w64, Cygwin, or WSL, but instead is built upon native Windows MSVC/MSVC-like command-line toolchains, focusing on compiling Windows native libraries from source code. This project provides developers with a vast collection of pre-configured open-source library definitions that have resolved common build issues, while significantly simplifying the workflow for adding new libraries. This embodies the very purpose and philosophy behind msvc-pkg's creation.

msvc-pkg employs a flexible plugin-based architecture where each library is an independent plugin, allowing for deep customization of the build process. It features rich color output in both the console and log files, facilitating troubleshooting during builds, and is capable of handling complex dependency trees, including full support for scenarios like bootstrap builds.

This project is continuously evolving, and we welcome your contributions! If a library you need is not yet supported, you can [submit an issue](https://github.com/jiangjianshan/msvc-pkg/issues) or refer to the [Contribution Guide](#contribution-guide) to add the open-source library yourself.

# Quick Start

Getting started with msvc-pkg is straightforward.

```bash
# 1. Clone the repository
git clone https://github.com/jiangjianshan/msvc-pkg.git
cd msvc-pkg

# 2. View all available commands and options
mpt --help

# 3. Install all supported libraries for x64 architecture (default behavior)
mpt

# 4. Alternatively, install specific libraries
mpt --install gmp ffmpeg gettext ncurses readline
```

After installation, the libraries are built and ready for use in your projects. You can set a custom installation prefix for each library using the `--<library-name>-prefix` option.

# Using msvc-pkg

msvc-pkg provides a simple, consistent command-line interface for all operations.

**Managing Libraries:**
```bash
# Install libraries (x64 is the default architecture)
mpt --install gsl opencv llvm-project
mpt --install --arch x86 gmp  # Specify x86 architecture

# Uninstall libraries
mpt --uninstall opencv
mpt --arch x86 --uninstall gmp fftw

# List the status of all or specific libraries
mpt --list
mpt --list gmp fftw grpc libiconv gettext libunistring
```

**Understanding Dependencies:**
```bash
# Display a visual dependency tree
mpt --dependency
mpt --dependency glib PostgreSQL OpenBLAS
```

**Advanced Operations:**
```bash
# Download source code without building
mpt --fetch ffmpeg

# Clean build artifacts to force a fresh build
mpt --clean
mpt --clean gmp fftw

# Add a new library configuration (for contributors)
mpt --add <new-library-name>
```
For a complete list of commands and examples, run `mpt --help`.

# Core Features

- **Native MSVC Toolchain Support**: Deep integration with MSVC/MSVC-like environments, patching GNU toolchains to conform to Windows library naming conventions.
- **Flexible Build System Support**: Not bound to any specific build system; supports Autotools, CMake, Meson, MSBuild, Makefile, etc.
- **Intelligent Dependency Management**: Automatically resolves complex dependency relationships, visualizes dependency trees, and supports circular dependencies and bootstrap scenarios.
- **Lightweight and Efficient**: Based on native Windows toolchains, requires no additional heavy environments, keeping the system clean.
- **Enhanced Build Experience**: Provides colored log output, incremental builds, patch application, and other practical features.

# Contribution Guide

msvc-pkg is an open-source project serving the community. It has successfully built a wide variety of open-source libraries and continues to expand. The complete list of supported libraries can be viewed using the `mpt --list `command. We greatly appreciate your contributions.

**Ways you can help:**
*   [Submit an issue](https://github.com/jiangjianshan/msvc-pkg/issues) to report bugs or request features.
*   [Add a new library](#adding-a-new-library) or fix existing ones.

### Adding a New Library

1.  **Prepare Configuration:**
    ```bash
    mpt --add <library-name>
    ```
2.  **Fetch Source Code:**
    ```bash
    mpt --fetch <library-name>
    ```
3.  **Apply Patches (if needed)**: Create `.diff` files for Windows-specific fixes.
4.  **Write Build Scripts**: Create `build.bat` or `build.sh` in the `ports/<library-name>` directory, referring to existing examples.
5.  **Test and Submit:**
    ```bash
    mpt <library-name> # Build and test
    ```
    Then, submit a Pull Request containing your new `ports/<library-name>` directory.

For more details, please refer to the existing library configurations in the `ports` directory.

# Resources

*   **Source Code & Library Ports:** https://github.com/jiangjianshan/msvc-pkg
*   **Issues & Discussions:** https://github.com/jiangjianshan/msvc-pkg/issues

---

<div align="center">
If you appreciate the work on msvc-pkg, please give it a star ⭐ to encourage and support our continued development!
</div>