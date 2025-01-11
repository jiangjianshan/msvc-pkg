# msvc-pkg

- ⚓ Have you ever encountered a build failure after spending a lot of time to build libraries and their dependencies?
- 🏛️ Do you want to compile Autotools-based libraries on Windows withoug installing Cygwin or MSYS2?
- 🏗️ Do you want to have a colorful and meaningful terminal for the compilation process?
- 🏘️ Do you want to have .lib instead of .dll.a or .lib as suffix for the generated library files when using GNU libtool?
- 🥁 Do you want to use MSVC or MSVC-like toolchain for native compilation on Windows without using MinGW?
- 🏆 Do you want to automatically compile all build dependencies when compiling a library?
- 🚗 Do you want to have independent compilation process for each library?
- and etc.

🚀 ***msvc-pkg*** is the right lightweight build manager you are looking for. It consists of more than 200+ open source libraries, which are available under👝 ***packages*** folder. Some of these libraries are not easy to be built on Windows, e.g. 💘 gmp 💚, 💘 ncurses 💚 and so on. More and more libraries are comming.

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

## Quick Start

Before you start to use ***msvc-pkg***, the following steps are needed.

```bat
git clone https://github.com/jiangjianshan/msvc-pkg.git
cd msvc-pkg
bootstrap.bat
```

📝Please note that this🚂 ***bootstrap.bat*** will not only install those [Dependencies](#dependencies)
above, but also install some neccessary build essentials into Git for windows. So that ***msvc-pkg***
can build autotools base projects on Windows without install Cygwin or MSYS2.

Then, it is recommand to create a file ***settings.yaml*** and put it in the root folder of ***msvc-pkg***. In case you want to install some libraries to your pre-defined location. Here is an example.

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

## Contributors

This project follows the [all-contributors](https://allcontributors.org) specification. 🚈 The goal of ***msvc-pkg*** is to use MSVC and MSVC-like toolset to build as many C/C++/Fortran open source librareis as possible. It is a ✨huge✨ effort. Any volunteer for further contribution is welcome. If you find this project useful, please kindly click the 🌟star🌟 on the upper right corner. Thanks.
