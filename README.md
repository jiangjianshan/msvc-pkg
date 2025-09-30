<div align="center">
  <h1>✨🚀 MSVC-PKG 🚀✨</h1>
  <p><strong>🛠️ A Lightweight Build Dependency & Source Compilation Solution for Windows C/C++/Fortran Developers 🛠️</strong></p>
</div>

<br>

<div align="center">
  <p>🎯 <em>Streamline your Windows development workflow with effortless dependency management</em> 🎯</p>
</div>

## 📖 Overview

MSVC-PKG is a specialized build automation tool 🛠️ designed for Windows C/C++/Fortran development. It provides a streamlined solution for compiling open-source libraries from source code, generating native Windows libraries (.lib and .dll) without requiring complex environment setups. 

By leveraging a minimal dependency environment (Git for Windows + essential MSYS2 components), MSVC-PKG eliminates the need for full Cygwin/MSYS2 installations. Its plugin-style architecture 🧩 supports multiple build systems and ensures each library builds in complete isolation with independent environment settings, preventing conflicts and ensuring reproducible builds across x86 and x64 architectures. 🚀

## ✨ Core Features

- ⚡ **Lightweight & Efficient**: Requires only Git for Windows and ~20-30MB of MSYS2 components — no full Cygwin/MSYS2 needed. Complete builds directly within Git Bash. 🌟
- 🧠 **Smart Dependency Management**: Automatically resolves dependency trees, visually renders them, and generates optimal compilation orders. Supports both required and optional dependencies for bootstrap builds. 📊
- 🏗️ **Native Windows Builds**: Specialized for Windows native compilation, generating .lib and .dll files. Supports both x86 and x64 architecture targets. 🔧
- 🛡️ **Isolated Build Environments**: Each library compiles in an independent process with isolated environment settings, ensuring no conflicts between different library builds. ✅
- 🔌 **Extensible & Flexible**: Plugin-style design simplifies adding new libraries. Supports Git repos (with submodule management), various archive formats, and extra resources. 🧩
- 🛠️ **Build System Agnostic**: Works with autotools, CMake, Meson, MSBuild, GNU Make, NMake, and more. ✅
- 🔧 **Multi-Compiler Support**: Compatible with MSVC, Intel oneAPI, Clang/LLVM, and CUDA toolchains. Auto-configures environment variables per build. 💪
- 📦 **Unified Library Management**: One-click install for 339+ (and growing) C/C++/Fortran open-source libraries. 🎉
- 🔄 **Smart Build Optimization**: Conditionally rebuilds on changes, supports incremental compilation, and saves significant development time. ⏱️
- 🎨 **Rich Visual Experience**: Real-time colorized tables, panels, and detailed logs enhance usability and simplify debugging. ✨
- 🧹 **Easy Maintenance**: One-command cleanup removes temporary files, archives, and logs to free disk space. 🗑

## 🏆 Why Choose MSVC-PKG?

- ⏱️ **Massive Time Savings**: Already solves build issues for numerous complex libraries, saving hours, days, or even months of debugging time. 🎯
- 🎯 **Reduced Errors**: Automated processes eliminate manual configuration mistakes. ✅
- 📚 **Easy to Learn**: Provides numerous example configurations; adding new libraries often requires just minor adjustments based on existing examples. 🎓

## 🚀 Quick Start

```bash
# Clone the project
git clone https://github.com/jiangjianshan/msvc-pkg.git

cd msvc-pkg
# View full command support (Format: mpt [options] [libraries])
mpt --help

# Install all source libraries (Uses --install and --arch x64 options by default)
mpt
```

## 💼 Ideal Use Cases

- 🔧 **Native Windows Development**: C/C++/Fortran project development. 🏗️
- 🎮 **Game Development**: Game engine building and dependency management. 🕹️
- 📊 **Scientific Computing**: Numerical analysis and scientific computing libraries. 🔬
- 🤖 **Machine Learning**: AI and machine learning frameworks. 🧠
- 🌐 **Network Services**: Backend services and network application development. 🌍
- 🔬 **Academic Research**: Academic research and prototyping. 📚

## 📖 Detailed Usage

### Basic Commands

```bash
# Install a specific library
mpt <library-name>

# Install specified libraries or all libraries if none specified, this is default option
mpt --install

# Uninstall specified libraries or all libraries if none specified
mpt --uninstall

# List installation status of specified libraries or all libraries if none specified
mpt --list

# Show dependency tree for specified libraries or all libraries if none specified
mpt --dependency

# Fetch source code for specified libraries or all libraries if none specified
mpt --fetch

# Clean build artifacts for specified libraries or all libraries if none specified
mpt --clean
```

## 🏗️ Configuration Template Explained

MSVC-PKG uses YAML configuration files. Here's the full field specification:

```yaml
# Basic Information
name: Library Name (Must match the packages/<library-name> directory name)
version: Library Version
url: Source download/clone URL

# Checksum (Only needed for archive files)
sha256: Correct SHA256 checksum for the archive

# Git Repository Specific
recursive: true/false # Whether it has submodules
depth: 1 # git --depth parameter setting

# Submodule Configuration, maybe empty if no need
submodules:
  Submodule_Name:
    url: Submodule Git URL
    branch: Branch name (e.g., 'mirror')

# Extra Resources, optional, maybe empty if no need
extras:
  - name: Extra_Source_Name
    # version, url, sha256, etc., same as main source
    target: Relative path from the main source directory
    check: Command to check if the extra source already exists

# Dependencies, maybe empty if no dependencies
dependencies:
  required: # Required dependencies
    - dependency1
    - dependency2
    - ...
  optional: # Optional dependencies (for bootstrap build)
    - dependency1
    - dependency2
    - ...

# Build Script, maybe empty if only no need to install
run: build.bat or build.sh # Located in the packages/<library-name>/ directory
```

## 📋 Configuration Examples

### Basic Git Repo (No Submodules)
```yaml
name: CoinUtils
version: master
url: https://github.com/coin-or/CoinUtils.git
recursive: false
depth: 1
dependencies:
  required:
    - bzip2
    - dlfcn-win32
    - zlib
run: build.sh
```

### Git Repo (With Submodule URL Update)
```yaml
name: libjxl
version: v0.11.1
url: https://github.com/libjxl/libjxl.git
recursive: true
depth: 1
submodules:
  third_party/skcms:
    url: https://github.com/google/skcms
    branch: mirror
dependencies:
  required:
    - pkg-config
    - highway
run: build.bat
```

### Archive Source
```yaml
name: pcre
version: 8.45
url: https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.tar.bz2
sha256: 4dae6fdcd2bb0bb6c37b5f97c33c2be954da743985369cddac3546e3218bffb8
dependencies:
  required:
    - dirent
    - bzip2
run: build.bat
```

### Complex Dependencies
```yaml
name: libheif
version: 1.20.2
url: https://github.com/strukturag/libheif/archive/refs/tags/v1.20.2.tar.gz
sha256: b70340395d84184bb8dfc833dd51c95ae049435f7ff9abc7b505a08b5ee2bd2a
dependencies:
  required:
    - dav1d
    - ffmpeg
    - libde265
    - libjpeg-turbo
  optional:
    - graphviz:required   # bootstrap build: libheif (only with required dependencies) -> graphviz(only with required dependencies) -> libheif 
run: build.bat
```

See the `packages` directory for more detailed examples. 🔍

## 🤝 Contributing Guide

We warmly welcome and appreciate all forms of community contributions! 🎉 Here's how you can help make MSVC-PKG even better:

### 🐛 Reporting Issues
- **🔍 Bug Reports**: Found a problem? Please open an issue with detailed steps to reproduce, expected vs actual behavior, and relevant logs. 📝
- **💡 Feature Requests**: Have an idea to improve MSVC-PKG? Share your suggestions with clear use cases and benefits. 🌟

### 📦 Adding New Libraries
- **🛠️ Library Contributions**: Want to add support for a new library? Follow our configuration templates and examples in the `packages` directory. 🎯
  
  **Detailed Steps for Adding a New Library:**
  
  1. **🔍 Determine Library Type**
     - Git repository (with or without submodules) 📂
     - Archive source (tar.gz, tar.bz2, zip, etc.) 📦
     - Needs extra resources? 🎯

  2. **📝 Create Configuration File**
     - Create `config.yaml` in `packages/<library-name>/` 📄
     - Refer to existing templates and examples in the `packages` directory. 🔍

  3. **🛠️ Write Build Scripts**
     - Based on build system (autotools, CMake, Meson, etc.) ⚙️
     - Refer to examples of similar build systems in the `packages` directory. 📚
     - Add `prerun.sh` if special preprocessing is needed. 🎯

  4. **🧪 Test and Submit**
     ```bash
     mpt <library-name> # Test installation
     # Check build logs and generated files
     ```
     - Fork the repository, create a feature branch, submit your changes, and open a Pull Request. 🔄

- **🧪 Testing**: Ensure your library builds correctly on both x86 and x64 architectures before submitting. ✅

### 🔧 Development Process
1. **🎯 Fork the Repository**: Create your own fork of the MSVC-PKG project. 🔄
2. **🌿 Create a Feature Branch**: Use descriptive branch names related to your contribution. 📋
3. **💻 Make Your Changes**: Follow the existing code style and patterns. 🛠️
4. **🧪 Test Thoroughly**: Verify your changes work as expected. ✅
5. **📤 Submit a Pull Request**: Provide a clear description of your changes and their benefits. 🚀

### 📋 Code Standards
- **🎨 Consistent Formatting**: Follow the existing code style and formatting conventions. ✨
- **📝 Clear Comments**: Document complex logic and non-obvious decisions. 🔍

### 🌟 Recognition
All significant contributions will be acknowledged in our contributors list! 🏆 Your help makes the Windows C/C++/Fortran development ecosystem better for everyone. 💖

Thank you for considering contributing to MSVC-PKG! Together, we can build an amazing development toolchain. 🤝🚀

---

<div align="center">
  <h3>💻✨ Say goodbye to dependency hell and experience a modernized Windows C/C++/Fortran development workflow! ✨💻</h3>
  <p>🎯 <strong>MSVC-PKG lets you focus on coding, not environment configuration!</strong> 🎯</p>
</div>
