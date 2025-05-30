# 🚀 msvc-pkg
`msvc-pkg` consists solely of 📜scripts, 🔧patches, and 📄YAML configuration files. Leveraging MSVC/MSVC-like command-line 🛠️toolchains, it enables users to compile each library from source within the `packages` directory of this repository

**Native Windows Compilation | Compiler | Dependency Managment | Colorized Output**  
[![Build Systems](https://img.shields.io/badge/Build-CMake%20|%20Meson%20|%20Autotools%20|%20Nmake%20|%20MSBuild-blue)]()
[![Compilers](https://img.shields.io/badge/Compiler-MSVC%20|%20Intel%20C++%20|%20Intel%20Fortran%20|%20llvm-green)]()
[![Dependency](https://img.shields.io/badge/Dependency-Auto%20Resolution-orange)]()
[![Rich Colors](https://img.shields.io/badge/Colors-Rich-yellow)]()

## ✨ Key Features

`msvc-pkg` is similar to [vcpkg](https://github.com/microsoft/vcpkg) and [MINGW-Packages](https://github.com/msys2/MINGW-packages), but its lightweight design and focus on the following features make it worth trying
- 🔧 Fully relies on MSVC/MSVC-like toolchains to generate native Windows binaries
- 🛠️ Lightweight UNIX-like environment without requiring additional installations of Cygwin/MSYS2
- 🤖 Automatically generate dependency tree and detect circular dependencies based on package configurations
- 🌳 Nice view of dependency tree for each package on terminal
- 🌈 Rich and vibrant colors in the terminal during display output
- 🚧 Each library's build environment (UNIX-like or Windows) is isolated within the terminal
- 🔌 Enhanced compiler's wrappers for C/C++/Fortran/MPI and etc


## 📜 Special Notes

- **Intel Compiler Support**: 2024.2.1 is the final version supporting `ifort`
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

2. Create `settings.yaml` to decide whether to install some components and define default install prefix of some libraries (optional, but it is good to have):
   ```yaml
    components:
      cuda: no
      cudnn: no
      intel-dpcpp: yes
      intel-ifort: yes
      intel-mpi: yes
      intel-mkl: no
      rust: yes
    prefix:
      x64:
        Vim: D:\Vim
        llvm-project: D:\LLVM
        lua: D:\Lua
        perl: D:\Perl
        ruby: D:\Ruby
        tcl: D:\Tcl
        tk: D:\Tcl
      x86:
   ```
  > 💡 Pro Tip: The `settings.yaml` must be on the root of `msvc-pkg` folder. If you don't want to install some components, change its value from `yes` to `no`.

### 🖥️ Basic Commands

| Command                        | Description                                                                 | Example Usage               |
|--------------------------------|-----------------------------------------------------------------------------|-----------------------------|
| `mpt --list`                   | List all available packages                                                 | `mpt --list`                |
| `mpt`                          | Build all libraries for default architecture (`x64`)                        | `mpt`                       |
| `mpt <arch>`                   | Build all libraries for specified architecture (`x86`/`x64`)                | `mpt x86`                   |
| `mpt <arch> <pkg1> <pkg2>...`  | Build specific packages with dependencies for specified architecture        | `mpt x86 gmp ffmpeg`        |
| `mpt <pkg1> <pkg2>...`         | Build specific packages with dependencies                                   | `mpt gmp ffmpeg`            |

## ➕ How To Add New Package

1. Create package directory in `packages/`, e.g. `gmp`
2. Add required files:
   ```bash
   gmp/
   ├── sync.sh                # Source fetching and patching if have
   ├── build.bat/build.sh     # Script for build configuration, compile and install
   ├── config.yaml            # define package essential information
   └── *.diff                 # Patch files for this package (required if need)
   ```
> 💡 Pro Tip: There many examples exist inside `packages` folder can be taken as reference

## 🤝 Contributing

It is a huge job to create the scripts to build as many as libraries as possible. We welcome contributions through:
- 🐛 Bug reports
- 💡 Feature proposals
- 📦 New package additions
- 📚 Documentation improvements

### 🏆 Contributors
[![Contributors](https://contrib.rocks/image?repo=jiangjianshan/msvc-pkg)](https://github.com/jiangjianshan/msvc-pkg/graphs/contributors)
