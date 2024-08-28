# msvc-pkg

**msvc-pkg** helps you to use MSVC or MSVC-like toolset to do native build on Windows for a lots of open source libraries.

## Why?

There are already some good projects exist, e.g. [vcpkg](https://github.com/microsoft/vcpkg), [MXE](https://github.com/mxe/mxe), [MINGW-packages](https://github.com/msys2/MINGW-packages) and so on. Why I create this project?

- **msvc-pkg** has made an exactly native win32/win64 build for supported free open source libraries.
- **msvc-pkg** has implemented the missing features of libtool which can't set the naming style of static and shared libraries.
- **msvc-pkg** has reduced the difficulty to build GNU Autotools base projects, e.g. gmp, ncurses and so on.
- **msvc-pkg** has made some patches for compile, ar-lib and so on wrapper from GNU, so that can build more GNU projects.
- **msvc-pkg** has made color highlight for warnings or errors during configure and build procedure.
- **msvc-pkg** can build library with its dependencies together.


## Dependencies

- [Cygwin](https://www.cygwin.com/)
- [Visual C++ Build Tools or Visual Studio and Windows 10/11 SDK](https://visualstudio.microsoft.com/zh-hans/downloads/?q=build+tools)
- [Git](https://git-scm.com/download/win)
- [Python 3](https://www.python.org/downloads/)
- [CMake](https://cmake.org/download/)
- [wget](https://eternallybored.org/misc/wget/)
- [ninja](https://ninja-build.org/)
- [meson](https://mesonbuild.com/)
- Windows Terminal (Optional but recommend to have it)

## Quick Start

First, download **msvc-pkg** from Github in your local location
```bat
git clone https://github.com/jiangjianshan/msvc-pkg.git
```

If you don't install those [Dependencies](#dependencies) above, you can run
```bat
bootstrap.bat
````
on the command prompt, ```bootstrap.bat``` will check and install them automatically except for some of them only ask you to install the newest version

## How to use

### Example: get help of msvc-pkg


On Cygwin terminal, type
```bash
./mpt --help
```

### Example: build all available libraries


```bash
# build all available libraries on default host architecture, and install them
# on default prefix
./mpt
```

```bash
# build and install all available libraries on x86 architecture, and install them
# on default prefix
./mpt --arch x86
```

```bash
# build all available libraries on default host architecture and install them to D:\mswin64
./mpt --prefix "D:\mswin64"
```

```bash
# build all available libraries on default host architecture, and install them
# on default prefix except for llvm-project and lua have their own install prefix
./mpt --llvm-project-prefix "D:\LLVM" --lua-prefix "D:\Lua"
```

```bash
# build all available libraries on default host architecture, and install them
# on D:\mswin64 except for llvm-project and lua have their own install prefix
./mpt --llvm-project-prefix "D:\LLVM" --lua-prefix "D:\Lua" --prefix "D:\mswin64"
```

### Example: build some but not all available libraries


```bash
# build gmp on default host architecture and install it to default prefix
./mpt gmp
```

```bash
# build gmp and ncurses on default host architecture and install them to default prefix
./mpt gmp ncurses
```

```bash
# build gmp and ncurses on default architecture and install them to D:\mswin64
./mpt --prefix "D:\mswin64" gmp ncurses
```

## Contributors

This project follows the [all-contributors](https://allcontributors.org) specification.
Contributions of any kind are welcome!

