# 🚀 msvc-pkg: Unified Build System for MSVC/MSV-like Toolchain

**Native Windows Compilation | Colorized output | Dependency Automation**  
A robust framework for building C/C++/Fortran open-source libraries using MSVC/MSVC-like toolchains

[![Build Systems](https://img.shields.io/badge/Build-CMake%20|%20Meson%20|%20Autotools-blue)]()
[![Compilers](https://img.shields.io/badge/Compiler-MSVC%20|%20Intel%20C++%20|%20Intel%20Fortran-green)]()
[![Dependency](https://img.shields.io/badge/Dependency-Auto%20Resolution-orange)]()

## ✨ Key Features

- **Native Windows Experience**  
  ✅ No Cygwin/MSYS2 required - Direct Autotools compilation in Git Bash with few tools required  
  ✅ Pure MSVC/MSVC-like toolchain builds (No MinGW adaptation)  
  ✅ Not generate .dll.lib or .dll.a but .lib if using libtool

- **Smart Dependency Management**  
  🌳 Automatic dependency tree resolution with nice tree view on terminal visualization  
  📦 On-demand dependency builds with strategies

- **Enterprise-grade Build System**  
  🎨 Colorized terminal output with per-library log archives  
  🛠️ Parallel compilation (Nmake/GNU Make/CMake/Meson integration)  

- **Developer-Friendly Design**  
  📂 Isolated build environments per library  
  🔄 Automatic patch application via `.diff` files  

## 📦 System Requirements
| Component | Purpose |
|-----------|---------|
| [Visual C++ Build Tools](https://visualstudio.microsoft.com/zh-hans/downloads/?q=build+tools) | Mostly use compiler in `msvc-pkg` |
| [Intel oneAPI DPC++/C++ Compiler 2024.2.1](https://www.intel.com/content/www/us/en/developer/tools/oneapi/dpc-compiler.html) | Some libraries need icx-cl/clang-cl to build due to cl can't sucessfully do |
| [Intel Fortran Compiler Classic and Intel Fortran Compiler 2024.2.1](https://www.intel.com/content/www/us/en/developer/tools/oneapi/fortran-compiler-download.html) | MSVC is missing Fortran compiler |
| [Intel MPI Library](https://www.intel.com/content/www/us/en/developer/tools/oneapi/mpi-library-download.html) | MPI build support |
| [Rust for Windows](https://www.rust-lang.org/tools/install) | Few libraries need Rust compiler |
| [Git for Windows](https://git-scm.com/download/win) | Minimal bash environment and git fetch and sychronize libraries |
| [Python 3](https://www.python.org/downloads/) | `mpt` i.e. mpt.bat will exactly invoke mpt.py |
| [CMake](https://cmake.org/download/) | The project contain CMakeLists.txt need it |
| [wget](https://eternallybored.org/misc/wget/) | download archive file of libraries |
| [ninja](https://ninja-build.org/) | CMake/Meson based project work with ninja |
| [meson](https://mesonbuild.com/) | The project contain meson.build need it |
| [yq](https://github.com/mikefarah/yq) | parse yaml files, e.g. config.yaml, installed.yaml and settings.yaml |
| [Windows Terminal](https://learn.microsoft.com/en-us/windows/terminal/) | Recommend for best experience |

> 💡 Pro Tip: Most dependencies can be auto-installed via run `mpt` in windows terminal

## 🚀 Getting Started

### Initial Setup
1. Clone repository:
   ```bash
   git clone https://github.com/jiangjianshan/msvc-pkg.git
   cd msvc-pkg
   ```

2. Create configuration file to define default installation location of some libraries (optional, but it is good to have):
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

  > 💡 Pro Tip: to make **msvc-pkg** easy to use, the feature of option '--prefix' is done via `settings.yaml`

## 🚀 Basic Commands

| Command                        | Description                                                                 | Example Usage               |
|--------------------------------|-----------------------------------------------------------------------------|-----------------------------|
| `mpt --list`                   | List all available packages                                                 | `mpt --list`                |
| `mpt`                          | Build **all libraries** for default architecture (x64)                      | `mpt`                       |
| `mpt <arch>`                   | Build all libraries for specified architecture (`x86`/`x64`)                | `mpt x86`                   |
| `mpt <pkg1> <pkg2>...`         | Build specific packages with dependencies                                   | `mpt ncurses gettext`       |


## 📦 New Package

1. Create package directory in `packages/`
2. Add required files:
   ```bash
   ncurses/
   ├── sync.sh                # Source fetching/patching
   ├── build.bat/build.sh     # Windows build script
   ├── config.yaml            # Metadata
   └── *.diff                 # Patch files (optional)
   ```
> 💡 Pro Tip: There many examples exist inside `packages` folder

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
