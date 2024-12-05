# msvc-pkg

🚀 ***msvc-pkg*** is a very lightweight build manager using MSVC or MSVC-like command line toolset for C/C++ open source libraries. There are more than 180+ open source libraries available on👝 ***packages*** folder. More libraries are comming. If you found the pacakge you want is not there, you can send an request.

## What kinds of features?

- ⚓ ***msvc-pkg*** made you don't need to install Cygwin or MSYS2 to build autotools base project on Windows.
- 🏛️ ***msvc-pkg*** has rich colorful output during build and install procedure.
- 🏗️ ***msvc-pkg*** has seperate subprocess for bash and win32 environment to do a native build.
- 🏘️ ***msvc-pkg*** has implemented the missing features of libtool which can't set the naming style of static and shared libraries.
- 🥁 ***msvc-pkg*** has reduced the difficulty to build GNU Autotools base projects, e.g. 💘 gmp 💚, 💘 ncurses 💚 and so on.
- 🎹 ***msvc-pkg*** has made some patches for compile, ar-lib and so on wrapper from GNU, so that can build more GNU projects.
- 🏆 ***msvc-pkg*** build some libraries with its dependencies on steps if need.

## Dependencies

- [Visual C++ Build Tools and Windows 10/11 SDK](https://visualstudio.microsoft.com/zh-hans/downloads/?q=build+tools)
- [Intel Fortran Compiler Classic and Intel Fortran Compiler](https://www.intel.com/content/www/us/en/developer/tools/oneapi/fortran-compiler-download.html)
- [Intel oneAPI Math Kernel Library](https://www.intel.com/content/www/us/en/developer/tools/oneapi/onemkl-download.html)
- [Intel MPI Library](https://www.intel.com/content/www/us/en/developer/tools/oneapi/mpi-library-download.html)
- [Git for Windows](https://git-scm.com/download/win)
- [Python 3](https://www.python.org/downloads/)
- [CMake](https://cmake.org/download/)
- [wget](https://eternallybored.org/misc/wget/)
- [ninja](https://ninja-build.org/)
- [meson](https://mesonbuild.com/)
- [yq](https://github.com/mikefarah/yq)
- [Windows Terminal](https://learn.microsoft.com/en-us/windows/terminal/)

## Quick Start

For your first time to use ***msvc-pkg***, you can do following steps first.
```bat
git clone https://github.com/jiangjianshan/msvc-pkg.git
cd msvc-pkg
bootstrap.bat
```

📝Please note that this🚂 ***bootstrap.bat*** will not only install those [Dependencies](#dependencies)
above, but will also install some neccessary build essentials into Git for windows. So that ***msvc-pkg***
can build autotools base projects on Windows without install Cygwin or MSYS2.

Then, it is recommand to create a file ***settings.yaml*** and put it in the root folder of ***msvc-pkg***. Below is
an example for it. Because you may want some libraries install to your defined location.
```yaml
# settings.yaml
# Those haven't been defined will be on default prefix, e.g. msvc-pkg\x64 or msvc-pkg\x86
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

📝Please notice that don't delete this🛠️ ***settings.yaml*** file because ***msvc-pkg*** will also store
the installed information for packages in it. The command line tool🔨 ***mpt*** need it.

## How to use

To use ***msvc-pkg*** is quick simple.

### Example: build all available packages

```bat
rem build all available libraries on default host architecture
mpt
```

```bat
rem build and install all available libraries on x86 architecture
mpt x86
```

### Example: build one and more available but not all packages

```bat
rem build gmp, gettext on default host architecture
mpt gmp gettext
```

## Contributors

This project follows the [all-contributors](https://allcontributors.org) specification.
🚈 The goal is use MSVC and MSVC-like toolset to build as much as C/C++ open source librareis as possible. It is a ✨huge✨ job and full of 🎉challenge🎉.
Contributions of any kind are welcome! If you think this project is good, the 🌟star🌟 you click on in the upper right corner is one of the incentives given to the author.
