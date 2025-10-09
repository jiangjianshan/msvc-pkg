<div align="center">
  <h1>✨🚀 MSVC-PKG 🚀✨</h1>
  <p>A lightweight framework for building native Windows libraries from source, designed for C/C++/Fortran projects</p>
</div>

## 📖 Overview

MSVC-PKG is a lightweight framework focused on building native Windows libraries from source code, supporting C/C++/Fortran open-source projects.

It adopts a flexible plugin architecture where each library acts as an independent plugin located in the `packages/<library-name>` directory, containing configuration files, patch files (as needed), and build scripts. The framework is not bound to specific compilers or build systems, allowing complete customization of the compilation process. It provides automated dependency resolution, full-color output for both console and log files, dependency tree and build order generation, dual build support, and more, significantly simplifying the management and building process for numerous open-source libraries.

## 💪 Core Advantages

### 🚀 Lightweight and Efficient
- For libraries built with Autotools, only requires Git for Windows and core MSYS2 components (~30MB)
- No need for a full Cygwin/MSYS2 environment, enabling rapid deployment
- Maintains a clean system environment with minimal redundant dependencies

### 🔧 Native Development Support
- Patches GNU libtool to ensure compliance with MSVC naming conventions
  - Static library: `lib{name}.lib`
  - Dynamic library: `{name}.lib`
- Comprehensive support for various compilers including Microsoft Visual C++, LLVM, Intel, and NVIDIA CUDA
- Automatic configuration of each compiler's environment

### 🧩 Flexible Building
- No binding architecture, supports mainstream build systems (Autotools, CMake, Meson, MSBuild)
- Each library uses its native build system, controlled through custom scripts
- Direct editing and adjustment of build scripts for complete control

### 📊 Intelligent Management
- Automated dependency resolution and build order generation
- Visual dependency trees to clearly display complex relationships
- Handles circular dependencies and bootstrap scenarios
- Independent process and isolated environment for building
- Detailed version and build history recording to ensure consistency

### 💡 Enhanced Experience
- **Incremental Builds**: Intelligently detects changes and only rebuilds necessary components
- **Colored Logs**: Full-color highlighted output for both terminal and log files, improving readability
- **Archive Support**: Supports multiple formats for flexible handling of source packages
- **Patch Application**: Automatically applies custom patches during the build process
- **Unified Management**: Manages 339+ libraries with a single command (continuously growing)

> If you are developing in C/C++/Fortran on Windows and seek deep control over dependency building, highly customized environments, and seamless compatibility with MSVC/MSVC-like toolchains, msvc-pkg is your ideal choice.

## 🚀 Quick Start

```bash
# Clone the project
git clone https://github.com/jiangjianshan/msvc-pkg.git

# Enter the directory
cd msvc-pkg

# View detailed help
mpt --help

# Install all supported libraries (default x64 architecture)
mpt
```

## 🤝 Contributing

Building libraries is a challenging task. MSVC-PKG has successfully built 339+ open-source libraries and continues to expand support, aiming for the widest coverage among similar projects. We sincerely invite like-minded contributors to join us.

### 📝 Reporting Issues
- **Bug Reports**: Provide detailed steps, expected vs. actual behavior, and relevant logs
- **Feature Requests**: Describe specific use cases and expected benefits

### 📦 Adding New Libraries

#### Complete Process

1. **Prepare Environment**
   ```bash
   # Fork this repository
   # Create a feature branch
   ```

2. **Create Configuration**
   ```bash
   # Interactively create configuration file
   mpt --add <library-name>
   ```

3. **Fetch Source Code**
   ```bash
   # Download/clone source code
   mpt --fetch <library-name>
   ```

4. **Apply Patches** (Optional)
   - Create `.diff` files for Windows-specific fixes
   - Resolve build and compilation errors on Windows platform

5. **Write Scripts**
   - Create `build.bat` or `build.sh` based on build system type
   - Refer to examples of similar build systems in existing packages directory

6. **Test and Submit**
   ```bash
   # Compile and install (may require returning to steps 4-5 for adjustments)
   mpt <library-name>
   
   # Check build logs and generated files
   # Submit Pull Request (including packages/<library-name> directory and new files)
   ```

### 🔧 Development Process
1. Fork this repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -m 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Create a Pull Request

---

<div align="center">
  <sub>Welcome to Star ⭐ this project to support the development of MSVC-PKG!</sub>
</div>
