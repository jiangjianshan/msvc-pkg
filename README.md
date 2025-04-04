# 🚀 msvc-pkg
`msvc-pkg` consists solely of scripts, patches, and YAML configuration files. Leveraging MSVC/MSVC-like command-line toolchains, it enables users to compile each library from source within the `packages` directory of this repository

**Native Windows Compilation | Compiler | Dependency Managment | Colorized Output**  
[![Build Systems](https://img.shields.io/badge/Build-CMake%20|%20Meson%20|%20Autotools%20|%20Nmake%20|%20MSBuild-blue)]()
[![Compilers](https://img.shields.io/badge/Compiler-MSVC%20|%20Intel%20C++%20|%20Intel%20Fortran%20|%20llvm-green)]()
[![Dependency](https://img.shields.io/badge/Dependency-Auto%20Resolution-orange)]()
[![Rich Colors](https://img.shields.io/badge/Colors-Rich-yellow)]()

## ✨ Key Features

- 🛠️ Compiling Autotools projects requires no additional Cygwin/MSYS2 installations. It leverages Git for Windows' built-in minimal MSYS2 environment and ~20-30MB of Autotools dependencies
- 🤖 Automatically resolves build dependencies and detects circular dependencies based on each library's `config.yaml` configuration
- 🔧 A MinGW-w64-independent compilation environment that fully relies on MSVC/MSVC-like toolchains to generate native Windows binaries
- 🛠️ The import library suffix for dynamic link libraries (DLLs) will be .lib instead of .dll.lib if using libtool in that library
- 🌳 Each library's dependency tree is visualized as a hierarchical diagram in the terminal prior to compilation
- 🌈 Each library's build output is rendered in rich and vibrant colors in the terminal
- 🚧 Each library's build environment (UNIX-like or Windows) is isolated within the terminal
- 🔌 Delivers improved Visual C++ wrappers for GCC interoperability and migrated Intel MPI compiler encapsulation utilities

## 📦 System Requirements
### 🖥️ Core Dependencies
| Component | Minimum Version | Notes |
|-----------|-----------------|-------|
| [Visual C++ Build Tools](https://visualstudio.microsoft.com/zh-hans/downloads/?q=build+tools) | 2019+ | MSVC toolchain base |
| [Intel oneAPI Compilers](https://www.intel.com/content/www/us/en/developer/tools/oneapi/dpc-compiler.html) | 2024.2.1 | C++/Fortran optimization |
| [Intel MPI Library](https://www.intel.com/content/www/us/en/developer/tools/oneapi/mpi-library.html) | 2021.13 | Parallel computing |
| [Rust for Windows](https://www.rust-lang.org/tools/install) | 1.85+ | Rust bindings |
| [Git for Windows](https://git-scm.com/download/win) | 2.40+ | Git and minimal MSYS2 environment |
| [Python](https://www.python.org/downloads/) | 3.9+ | 📜`mpt.py` is written in Python |
| [CMake](https://cmake.org/download/) | 3.11+ | CMake is a powerful and comprehensive solution for managing the software build process |
| [wget](https://eternallybored.org/misc/wget/) | 1.21.4+ | download archive file of libraries |
| [ninja](https://ninja-build.org/) | 1.12.1+ | Ninja is a small build system with a focus on speed |
| [meson](https://mesonbuild.com/) | 1.6.0+ | Meson is a fast and user friendly build system that supports multiple platforms and languages |
| [yq](https://github.com/mikefarah/yq) | 4.45.1+ | A lightweight and portable command-line YAML, JSON and XML processor |
| [Windows 10/11 SDK](https://developer.microsoft.com/windows/downloads/) | 10.0.20348.0+ | Windows API support |

### 🔧 Optional Dependencies
| Component | Purpose | Recommended Version |
|-----------|---------|---------------------|
| [CUDA Toolkit](https://developer.nvidia.com/cuda-toolkit) | GPU acceleration | 12.2+ |
| [Windows Terminal](https://learn.microsoft.com/windows/terminal/) | Recommend for best experience | 1.18+ |

> 💡 Pro Tip: Most dependencies can be auto-installed via run `mpt` in windows terminal

## 🚀 Getting Started

### Initial Setup
1. Clone repository:
   ```bash
   git clone https://github.com/jiangjianshan/msvc-pkg.git
   cd msvc-pkg
   ```

2. Create `settings.yaml` to define default install prefix of some libraries (optional, but it is good to have):
   ```yaml
   prefix:
     x64:
       llvm-project: D:\LLVM
       lua: D:\Lua
       perl: D:\Perl
       ruby: D:\Ruby
       tcl: D:\Tcl
       tk: D:\Tcl
     x86:
   ```

  > 💡 Pro Tip: to reduce usage complexity, the --prefix option is replaced with a settings.yaml file to define installation paths for individual libraries. And `settings.yaml` must be on the root of `msvc-pkg` folder

## 🚀 Basic Commands

| Command                        | Description                                                                 | Example Usage               |
|--------------------------------|-----------------------------------------------------------------------------|-----------------------------|
| `mpt --list`                   | List all available packages                                                 | `mpt --list`                |
| `mpt`                          | Build **all libraries** for default architecture (x64)                      | `mpt`                       |
| `mpt <arch>`                   | Build all libraries for specified architecture (`x86`/`x64`)                | `mpt x86`                   |
| `mpt <pkg1> <pkg2>...`         | Build specific packages with dependencies                                   | `mpt ncurses gettext`       |


## 📦 How To Add New Package

1. Create package directory in `packages/`
2. Add required files:
   ```bash
   ncurses/
   ├── sync.sh                # Source fetching and patching if have
   ├── build.bat/build.sh     # Script for build configuration, compile and install
   ├── config.yaml            # define package essential information
   └── *.diff                 # Patch files for this package (required if need)
   ```
> 💡 Pro Tip: There many examples exist inside `packages` folder can be taken as reference

## 🤝 Contributing

We welcome contributions through:
- 🐛 Bug reports
- 💡 Feature proposals
- 📦 New package additions
- 📚 Documentation improvements

**Contribution Workflow:**
1. Fork the repository
2. Create feature branch (`git checkout -b feature/awesome-feature`)
3. Commit changes (`git commit -am 'Add awesome feature'`)
4. Push branch (`git push origin feature/awesome-feature`)
5. Create Pull Request

## 📜 Special Notes

- **Intel Compiler Support**: 2024.2.1 is the final version supporting `ifort`
