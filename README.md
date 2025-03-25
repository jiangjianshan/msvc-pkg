# msvc-pkg

🚀 ***msvc-pkg*** offer you the scripts and following features to build all libraries from sources:

- No need to install Cygwin or MSYS2, but let you still can compile autotools based libraries on Git for Windows.
- Each build process of libraries have a rich colorful and meaningful terminal and save logging files separately.
- No need to install IDE, but only those [Dependencies](#dependencies) which can be installed automatically when run ***mpt*** in windows terminal.
- Use MSVC or MSVC-like toolsets for native build on Windows, i.e. without using MinGW.
- Build all dependencies on neccessary when build a library.
- Each dependencies for a library have a nice tree view on terminal
- Set up independent build process for each libraries, which is more convenience for Win32 and Bash environment build.
- and etc.

## Dependencies

- [Visual C++ Build Tools and Windows 10/11 SDK](https://visualstudio.microsoft.com/zh-hans/downloads/?q=build+tools)
- [Intel oneAPI DPC++/C++ Compiler 2024.2.1](https://www.intel.com/content/www/us/en/developer/tools/oneapi/dpc-compiler.html)
- [Intel Fortran Compiler Classic and Intel Fortran Compiler 2024.2.1](https://www.intel.com/content/www/us/en/developer/tools/oneapi/fortran-compiler-download.html)
- [Intel MPI Library](https://www.intel.com/content/www/us/en/developer/tools/oneapi/mpi-library-download.html)
- [Rust for Windows](https://www.rust-lang.org/tools/install)
- [Git for Windows](https://git-scm.com/download/win)
- [Python 3](https://www.python.org/downloads/)
- [CMake](https://cmake.org/download/)
- [wget](https://eternallybored.org/misc/wget/)
- [ninja](https://ninja-build.org/)
- [meson](https://mesonbuild.com/)
- [yq](https://github.com/mikefarah/yq)
- [Windows Terminal](https://learn.microsoft.com/en-us/windows/terminal/)

📝Note

- We need Intel compiler mostly because MSVC is missing Fortran compiler and some C/C++ language extension are not supported yet.
- The final version of Intel compiler can support both 32 and 64bit are 2024.2.1, and this is also the last version to have ***ifort***.


## Quick Start

Before you start to use ***msvc-pkg***, it is recommand to create a file ***settings.yaml*** and put it in the root folder of ***msvc-pkg***. In case you want to install some libraries to your pre-defined location. Here is an example.

```yaml
# settings.yaml
# The default location is msvc-pkg\x64 or msvc-pkg\x86
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

## How to use

Using ***msvc-pkg*** is quick and simple. ***mpt.bat*** is the entry point from command line. Open the Windows terminal and follow the command from the below examples.

### Example:

If you want to see the installation status of all available packages

```bat
mpt --list
```

If you want to build all available libraries on default host architecture

```bat
mpt
```

But if you want to build them on another architecture, e.g. x86

```bat
mpt x86
```

In case you don't want to build all but just some of them, e.g. gmp, gettext, ncurses, readline, on default host architecture

```bat
mpt gmp gettext ncurses readline
```

## How to add a new package

Many examples are available on ***packages*** folder, only following files are need for the libraries that you want to add:
- ***sync.sh*** work with ***common.sh***, it is used to get the source of libraries and make patched if necessary before build.
- ***build.bat*** or ***build.sh*** is the build script on Win32 or Bash environment which depend on the libraries.
- ***config.yaml*** is the configuration file for libraries, some essential information have been defined there and will be used on ***mpt.py***, ***sync.sh*** and ***build.bat*** or ***build.sh***. Please notice that the name section in this file must be same as the folder name that contain ***config.yaml***.
- The ***.diff*** files are depend on the libraries. If no patch needed before build, they will be no needed.

## Contributors

This project follows the [all-contributors](https://allcontributors.org) specification. 🚈 The goal of ***msvc-pkg*** is to use MSVC and MSVC-like toolset to build as many C/C++/Fortran open source librareis as possible. It is a ✨huge✨ effort. Any volunteer for further contribution is welcome.
