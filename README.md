# 🚀 msvc-pkg
`msvc-pkg` consists solely of 📜scripts, 🔧patches, and 📄YAML configuration files. Leveraging MSVC/MSVC-like command-line 🛠️toolchains, it enables users to compile each library from source within the `packages` directory of this repository.

## ✨ Key Features

- 🔧 Fully relies on MSVC/MSVC-like toolchains to generate native Windows binaries
- 🛠️ Lightweight UNIX-like environment without requiring additional installations of Cygwin/MSYS2
- 🤖 Automatically generate dependency tree and detect circular dependencies based on package configurations
- 🌳 Nice view of dependency tree for each package on terminal
- 🌈 Rich and vibrant colors in the terminal during display output
- 🚧 Each library's build environment (UNIX-like or Windows) is isolated within the terminal
- 🔌 Enhanced compiler's wrappers for C/C++/Fortran/MPI and etc

## Screenshots
<div align="center">
  <img src="https://raw.githubusercontent.com/jiangjianshan/i/master/list-pkgs.png" alt="list-pkgs" width="427" height="510">
</div>
<div align="center">
  <img src="https://raw.githubusercontent.com/jiangjianshan/i/master/dep-tree.png" alt="dep-tree" width="649" height="377">
</div>
<div align="center">
  <img src="https://raw.githubusercontent.com/jiangjianshan/i/master/cmake-build.png" alt="cmake-build" width="827" height="454">
</div>

## 📜 Special Notes

- **Intel Compiler Support**: `2024.2.1` is the final version supporting `ifort`

## 🚀 Getting Started

### 🏗️ Initial Setup
   ```bash
   # Initial cloning
   git clone https://github.com/jiangjianshan/msvc-pkg.git
   
   # Commands below are dedicated for future content synchronization
   cd msvc-pkg
   git fetch origin main
   git reset --hard origin/main
   ```
  > 💡 Pro Tip: The `settings.yaml` will be created on the root of `msvc-pkg` folder if it is missing, you must check the content of it before run `mpt` with or without parameters.

### 🖥️ Basic Commands

| Command                        | Description                                                                 | Example Usage               |
|--------------------------------|-----------------------------------------------------------------------------|-----------------------------|
| `mpt --list`                   | List all available libraries which support by `msvc-pkg`                    | `mpt --list`                |
| `mpt`                          | Build all libraries for default architecture (`x64`)                        | `mpt`                       |
| `mpt <arch>`                   | Build all libraries for specified architecture (`x86`/`x64`)                | `mpt x86`                   |
| `mpt <arch> <pkg1> <pkg2>...`  | Build specific packages with dependencies for specified architecture        | `mpt x86 gmp ffmpeg`        |
| `mpt <pkg1> <pkg2>...`         | Build specific packages with dependencies                                   | `mpt gmp ffmpeg`            |

## ➕ How To Add New Package

1. Create package directory in `packages/`, e.g. `gmp`
2. For those libraries using cmake, meson, autotools, msbuild, nmake and so on, take the examples inside `packages/` and add required files:
   ```bash
   gmp/
   ├── sync.sh                # Source fetching and patching if have
   ├── build.bat/build.sh     # Script for build configuration, compile and install
   ├── config.yaml            # define package essential information
   └── *.diff                 # Patch files for this package (required if need)
   ```

## 🤝 Contributing

It is a huge job to create the scripts to build as many as libraries as possible. We welcome contributions through:
- 🐛 Bug reports
- 💡 Feature proposals
- 📦 New package additions
- 📚 Documentation improvements
