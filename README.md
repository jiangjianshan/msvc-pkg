# 🚀 msvc-pkg
`msvc-pkg` consists solely of 📜scripts, 🔧patches, and 📄YAML configuration files. Leveraging MSVC/MSVC-like command-line 🛠️toolchains, it enables users to compile each library from source within the `packages` directory of this repository

**Native Windows Compilation | Compiler | Dependency Managment | Colorized Output**  
[![Build Systems](https://img.shields.io/badge/Build-CMake%20|%20Meson%20|%20Autotools%20|%20Nmake%20|%20MSBuild-blue)]()
[![Compilers](https://img.shields.io/badge/Compiler-MSVC%20|%20Intel%20C++%20|%20Intel%20Fortran%20|%20llvm-green)]()
[![Dependency](https://img.shields.io/badge/Dependency-Auto%20Resolution-orange)]()
[![Rich Colors](https://img.shields.io/badge/Colors-Rich-yellow)]()

## ✨ Key Features

- 🛠️ Lightweight UNIX-like environment for autotools projects which no need to install additional Cygwin/MSYS2
- 🤖 Library configuration-aware automatic interdependency resolution
- 🔄 Auto-detected inter-library cyclic dependencies
- 🔧 Fully relies on MSVC/MSVC-like toolchains to generate native Windows binaries
- 🛠️ Patched libtool to make library suffix is .lib but not .dll.lib or .dll.a
- 🌳 Nice view of dependency tree for each library on terminal
- 🌈 Rich and vibrant colors in the terminal during display output
- 🚧 Each library's build environment (UNIX-like or Windows) is isolated within the terminal
- 🔌 Enhanced compiler's wrappers for C/C++/Fortran/MPI and etc
- 🛠️ Automatically or interactively install missing runtime dependencies

## System Requirements
- [Visual C++ Build Tools and Windows 10/11 SDK](https://visualstudio.microsoft.com/zh-hans/downloads/?q=build+tools)
- [Intel oneAPI DPC++/C++ Compiler 2024.2.1](https://www.intel.com/content/www/us/en/developer/tools/oneapi/dpc-compiler.html)
- [Intel Fortran Compiler Classic and Intel Fortran Compiler 2024.2.1](https://www.intel.com/content/www/us/en/developer/tools/oneapi/fortran-compiler-download.html)
- [Intel MPI Library](https://www.intel.com/content/www/us/en/developer/tools/oneapi/mpi-library-download.html)
- [Intel MKL](https://www.intel.com/content/www/us/en/developer/tools/oneapi/onemkl-download.html) (optional)
- [Rust for Windows](https://www.rust-lang.org/tools/install)
- [Git for Windows](https://git-scm.com/download/win)
- [Python 3](https://www.python.org/downloads/)
- [CMake](https://cmake.org/download/)
- [wget](https://eternallybored.org/misc/wget/)
- [ninja](https://ninja-build.org/)
- [meson](https://mesonbuild.com/)
- [yq](https://github.com/mikefarah/yq)
- [CUDA Toolkit](https://developer.nvidia.com/cuda-toolkit) (optional)
- [Windows Terminal](https://learn.microsoft.com/en-us/windows/terminal/) (optional)
 > 💡 Pro Tip: Most of requirements will be automatically installed via run `mpt` with or without parameters

## 📜 Special Notes

- **Intel Compiler Support**: 2024.2.1 is the final version supporting `ifort`
- **CUDA Toolkit**: it is around 5.78GB space need, you can skip it if the libraries you build don't need this dependency
- **Intel MKL**: it is around 6.5GB space need, you can skip it if the libraries you build don't need this dependency
- **Internet connection**: msvc-pkg automatically checks for missing runtime dependencies, so ensure a stable internet connection is maintained during runtime
- **Saving your time**: with the poor documents or not so friendly on Win32 platform, many libraries aren't so easy to build with MSVC/MSVC-like toolset. But `msvc-pkg` help you a lot

## 🚀 Getting Started

### 🏗️ Initial Setup
1. Synchronize the github repository:
   ```bash
   # Initial cloning
   git clone https://github.com/jiangjianshan/msvc-pkg.git
   
   # Commands below are dedicated for future content synchronization
   cd msvc-pkg
   git fetch origin main
   git reset --hard origin/main
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

### 🖥️ Basic Commands

| Command                        | Description                                                                 | Example Usage               |
|--------------------------------|-----------------------------------------------------------------------------|-----------------------------|
| `mpt --list`                   | List all available packages                                                 | `mpt --list`                |
| `mpt`                          | Build all libraries for default architecture (x64)                          | `mpt`                       |
| `mpt <arch>`                   | Build all libraries for specified architecture (`x86`/`x64`)                | `mpt x86`                   |
| `mpt <arch> <pkg1> <pkg2>...`  | Build specific packages with dependencies for specified architecture        | `mpt x86 ncurses gettext`   |
| `mpt <pkg1> <pkg2>...`         | Build specific packages with dependencies                                   | `mpt ncurses gettext`       |

## ➕ How To Add New Package

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

### 🏆 Contributors
[![Contributors](https://contrib.rocks/image?repo=jiangjianshan/msvc-pkg)](https://github.com/jiangjianshan/msvc-pkg/graphs/contributors)
