<div align="center">
  <h1>✨🚀 MSVC-PKG 🚀✨</h1>
</div>

## 📖 Overview

MSVC-PKG is a lightweight framework designed for building native Windows libraries from source code, supporting C/C++/Fortran open-source projects. 🛠️ Each library acts like a plugin residing in the `packages/<library-name>` directory, containing the 📄 config.yaml configuration file, 🩹 optional .diff patch files (zero or more), and the 🛠️ build.bat or build.sh build script. Through its flexible plugin architecture, the framework does not bind to specific 🔧 compilers or 🏗️ build systems, allowing each library to customize its compilation process. It provides 🧠 automated dependency resolution, 🎨 full-color output logs, 🌳 dependency tree generation, and 📊 topological sorting, simplifying the management and building of numerous libraries. msvc-pkg offers many more powerful features—clone the repository to experience its full potential firsthand. 🚀

---

## ✨ Core Features

- ⚡ **Minimal Environment**: Only requires Git for Windows and core MSYS2 components (~30MB) - no full Cygwin/MSYS2 needed.
- 🧠 **Smart Dependency Resolution**: Automatically resolves library dependencies including complex bootstrap scenarios with visual trees and optimal build order.
- 🛠️ **MSVC-Compliant Output**: Patched libtool ensures proper Windows naming (lib{name}.lib for static, {name}.lib for dynamic).
- 🛡️ **Isolated Build Environments**: Each library builds in separate processes with dedicated environment variables.
- 🔌 **Flexible Plugin Architecture**: YAML configs and custom scripts allow each library to integrate as independent plugin.
- 🏗️ **Build System Agnostic**: Supports Autotools, CMake, Meson, MSBuild - each library chooses its own build system.
- 🔧 **Multi-Compiler Support**: Works with MSVC, Intel, LLVM, and NVIDIA CUDA with automatic environment configuration.
- 📦 **Unified Management**: Single command manages 339+ C/C++/Fortran libraries (and growing).
- 🔄 **Incremental Builds**: Detects changes and rebuilds only what's necessary for maximum efficiency.
- 🎨 **Rich Terminal Experience**: Full colorized output throughout entire operation with highlighting in both terminal and log files.
- 🧹 **Easy Cleanup**: One-click removal of temporary files, downloaded archives, and logs.
- 📂 **Advanced Archive Handling**: Supports all major archive formats with pattern-based file filtering.
- 🔍 **Git Integrity Management**: Automatically detects and repairs damaged repositories including submodules.
- 🔄 **Runtime Dependency Handling**: Auto-detects and installs system-level runtime dependencies.
- 🩹 **Patch Application**: Supports custom patch application during build for source code modifications.
- 📊 **Version Tracking**: Maintains detailed records of installed versions and build history.

## 🚀 Quick Start

```bash
# Clone the project
git clone https://github.com/jiangjianshan/msvc-pkg.git

cd msvc-pkg
# View full command support
mpt --help

# Install all libraries (default: --install --arch x64)
mpt
```

## 📖 Basic Commands

| Command | Emoji | Description |
|---------|-------|-------------|
| `mpt <library>` | 📥 | Install specific library |
| `mpt --install` | 🔧 | Install specified/all libraries (default) |
| `mpt --uninstall` | 🗑️ | Uninstall specified/all libraries |
| `mpt --list` | 📋 | List installation status |
| `mpt --dependency` | 🌳 | Show dependency trees |
| `mpt --fetch` | ⬇️ | Download source code |
| `mpt --clean` | 🧹 | Clean build artifacts |

## 🏗️ Configuration Template <a id="configuration-template"></a>

```yaml
# Basic Information
name: Library Name (Must match the `packages/<library-name>` directory name)
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
run: build.bat or build.sh # Located in the `packages/<library-name>` directory
```

## 📋 Configuration Examples <a id="configuration-examples"></a>

### 🔗 Basic Git Repository (No Submodules)
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

### 🔗 Git with Submodules
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

### 📦 Archive Source
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

See the `packages` directory for more detailed examples. 🔍

## 🤝 Contributing

We welcome contributions! 🎉 Here's how you can help:

### 🐛 Reporting Issues
- **Bug Reports**: Detailed steps, expected vs actual behavior, logs
- **Feature Requests**: Clear use cases and benefits

### 📦 Adding New Libraries

**Detailed Steps:**

1. **📝 Create Configuration File**
   - Create `config.yaml` in `packages/<library-name>/`
   - Refer to the *[Configuration Template](#configuration-template)* and [Configuration Examples](#configuration-examples) sections above for detailed syntax and examples

2. **🩹 Create Patch Files (If Needed)**
   - Create `.diff` files for Windows-specific fixes required to successfully compile the library
   - Patch files are optional and should be created based on the specific library's requirements

3. **🛠️ Write Build Scripts**
   - Create `build.bat` or `build.sh` based on the library's build system
   - Refer to examples of similar build systems in existing packages

4. **🧪 Test and Submit**
   ```bash
   mpt <library-name> # Test installation
   ```
   - Check build logs and generated files
   - Fork repository, create feature branch, submit Pull Request

### 🔧 Development Process
1. **Fork Repository**
2. **Create Feature Branch**
3. **Make Changes**
4. **Test Thoroughly**
5. **Submit Pull Request**
