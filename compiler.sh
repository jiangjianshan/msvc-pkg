#!/bin/bash
#
#  compiler.sh - Visual Studio Build Environment Configuration Script (Cygwin/MSYS2)
#
#  Purpose: Initializes the command-line build environment for Microsoft Visual C++,
#           Intel oneAPI Base Toolkit, and NVIDIA CUDA Toolkit on Windows within
#           Cygwin or MSYS2 shells. This script mirrors the functionality of vcenv.bat
#           but uses native shell commands to manipulate environment variables,
#           making it suitable for Unix-like environments on Windows.
#
#  Key Functionality:
#    - Detects Visual Studio installation and Windows SDK locations via registry queries.
#    - Constructs the MSVC build environment (INCLUDE, LIB, PATH, etc.) manually.
#    - Optionally initializes the extensive Intel oneAPI environment (compilers, MPI, MKL, TBB, etc.).
#    - Optionally initializes the CUDA Toolkit environment.
#    - Processes the $PREFIX_PATH variable to prepend third-party library paths.
#
#  Usage: source vcenv.sh [x86|x64|amd64|x86_amd64|...] [oneapi]
#         Arguments specify target architecture and whether to enable Intel oneAPI.
#
#  Copyright (c) 2024 Jianshan Jiang
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#

LANG=en_US
export LANG

# Function: prepend_path
# Purpose: Safely prepends a new directory path to an existing path string.
#          Handles cases where the existing path might be empty or undefined.
# Parameters:
#   $1 - The new path segment to add to the front.
#   $2 - The existing path variable contents.
#   $3 - The path separator character (e.g., ':' for Unix, ';' for Windows within this script).
# Returns: Prints the new composite path string to stdout.
prepend_path()
{
  path_to_add="$1"
  path_is_now="$2"
  path_seperator="$3"
  if [ "" = "${path_is_now}" ] ; then   # avoid dangling ":"
    printf "%s" "${path_to_add}"
  else
    printf "%s" "${path_to_add}${path_seperator}${path_is_now}"
  fi
}

# Function: check_arch
# Purpose: Detects the host machine's architecture (x86 or x64) by querying `uname -m`.
#          Sets the global HOST_ARCH variable accordingly. This is used to determine
#          the correct paths for host tools within the Visual Studio directory structure.
check_arch()
{
  local mach_name=
  mach_name=$(uname -m)
  case $mach_name in
    x86_64 )
      HOST_ARCH=x64  # or AMD64 or Intel64 or whatever
      ;;
    i*86 )
      HOST_ARCH=x86  # or IA32 or Intel32 or whatever
      ;;
    * )
      # leave HOST_ARCH as-is
      ;;
  esac
  export HOST_ARCH
}

# Function: config_msvc
# Purpose: Core function to set up the Microsoft Visual C++ build environment.
#          Reads registry keys to find Windows SDK and Visual Studio install locations,
#          then constructs INCLUDE, LIB, and PATH variables to mimic the behavior of
#          vcvarsall.bat. Also extracts the compiler version.
config_msvc()
{
  #
  # Visual C++ build Tools environment initialized for x64 or x86
  #
  if [[ "$HOST_ARCH" == "x86" ]]; then
    WindowsSdkDir=$(cmd //c REG QUERY "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0" -v "InstallationFolder" | grep -oP '(?<=\s{4}Installa
tionFolder\s{4}REG_SZ\s{4}).*')
    WindowsSDKVersion=$(cmd //c REG QUERY "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0" -v "ProductVersion" | grep -oP '(?<=\s{4}ProductVersion\s{4}REG_SZ\s{4}).*')
  else
    WindowsSdkDir=$(cmd //c REG QUERY "HKLM\SOFTWARE\WOW6432Node\Microsoft\Microsoft SDKs\Windows\v10.0" -v "InstallationFolder" | grep -oP '(?<=\s{4}InstallationFolder\s{4}REG_SZ\s{4}).*')
    WindowsSDKVersion=$(cmd //c REG QUERY "HKLM\SOFTWARE\WOW6432Node\Microsoft\Microsoft SDKs\Windows\v10.0" -v "ProductVersion" | grep -oP '(?<=\s{4}ProductVersion\s{4}REG_SZ\s{4}).*')
  fi
  WindowsSDKVersion=$WindowsSDKVersion'.0'
  WindowsSdkDir=$(cygpath -d "${WindowsSdkDir}")
  # for creating 32-bit or 64-bit binaries: through the following bash commands:
  # Set environment variables for using MSVC 14,
  # for creating native 32-bit or 64-bit Windows executables.
  # Windows tools
  PATH=$(prepend_path "$(cygpath -u "${WindowsSdkDir}")bin/${WindowsSDKVersion}/${TARGET_ARCH}" "${PATH:-}" ":")
  # Windows C library headers and libraries.
  WindowsCrtIncludeDir="${WindowsSdkDir}"'Include\'"${WindowsSDKVersion}"'\ucrt'
  WindowsCrtLibDir="${WindowsSdkDir}"'Lib\'"${WindowsSDKVersion}"'\ucrt\'
  INCLUDE=$(prepend_path "${WindowsCrtIncludeDir}" "${INCLUDE:-}" ";")
  LIB=$(prepend_path "${WindowsCrtLibDir}${TARGET_ARCH}" "${LIB:-}" ";")
  # Windows API headers and libraries.
  WindowsSdkIncludeDir="${WindowsSdkDir}"'Include\'"${WindowsSDKVersion}"'\'
  WindowsSdkLibDir="${WindowsSdkDir}"'Lib\'"${WindowsSDKVersion}"'\um\'
  INCLUDE=$(prepend_path "${WindowsSdkIncludeDir}um" "${INCLUDE:-}" ";")
  INCLUDE=$(prepend_path "${WindowsSdkIncludeDir}shared" "${INCLUDE:-}" ";")
  LIB=$(prepend_path "${WindowsSdkLibDir}${TARGET_ARCH}" "${LIB:-}" ";")
  # Visual C++ tools, headers and libraries.
  VSWHERE=$(cygpath -u 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe')
  VSINSTALLDIR=$("$VSWHERE" -nologo -latest -products "*" -all -property installationPath | tr -d '\r')
  VSINSTALLDIR=$(cygpath -d "${VSINSTALLDIR}")
  VSINSTALLVERSION=$("$VSWHERE" -nologo -latest -products "*" -all -property installationVersion | tr -d '\r')
  VCToolsVersion=$(head -1 "${VSINSTALLDIR}"'\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt' | tr -d '\r')
  VCINSTALLDIR="${VSINSTALLDIR}"'\VC\Tools\MSVC\'"${VCToolsVersion}"
  # build some project need VCTOOLSINSTALLDIR, e.g. perl
  VCTOOLSINSTALLDIR=${VCINSTALLDIR}
  PATH=$(prepend_path "$(cygpath -u "${VCINSTALLDIR}")/bin/Host${HOST_ARCH}/${TARGET_ARCH}" "${PATH:-}" ":")
  INCLUDE=$(prepend_path "${VCINSTALLDIR}"'\include' "${INCLUDE:-}" ";")
  INCLUDE=$(prepend_path "${VCINSTALLDIR}"'\atlmfc\include' "${INCLUDE:-}" ";")
  LIB=$(prepend_path "${VCINSTALLDIR}"'\lib\'"${TARGET_ARCH}" "${LIB:-}" ";")
  LIB=$(prepend_path "${VCINSTALLDIR}"'\atlmfc\lib\'"${TARGET_ARCH}" "${LIB:-}" ";")
  # Universal CRT
  PATH=$(prepend_path "$(cygpath -u "${WindowsSdkDir}")Redist/ucrt/DLLs/${TARGET_ARCH}" "${PATH:-}" ":")
  # MSBuild
  if [ "$HOST_ARCH" == "x86" ]; then
    PATH=$(prepend_path "$(cygpath -u "${VSINSTALLDIR}")/MSBuild/Current/Bin" "${PATH:-}" ":")
  else
    PATH=$(prepend_path "$(cygpath -u "${VSINSTALLDIR}")/MSBuild/Current/Bin/amd64" "${PATH:-}" ":")
  fi
  # location of Microsoft.Cpp.Default.props
  PATH=$(prepend_path "$(cygpath -u "${VSINSTALLDIR}")/MSBuild/Microsoft/VC/v${VSINSTALLVERSION%%.*}0" "${PATH:-}" ":")
  # Extract _MSC_VER
  MSC_FULL_VER=$(cl 2>&1 | awk 'match($0, /Version ([0-9]+\.[0-9]+\.[0-9]+)/, a) {print a[1]; exit}')
  MSC_VER=${MSC_FULL_VER%.*}
  echo "Initializing Visual Studio command-line environment..."
  echo "Visual C++ Compiler Version                            : ${MSC_FULL_VER}"
  echo "Visual C++ Tools Version                               : ${VCToolsVersion}"
  echo "Visual C++ Install Directory                           : $(cygpath -w -l "${VCINSTALLDIR}")"
  echo "Windows SDK Install Directory                          : $(cygpath -w -l "${WindowsSdkDir}")"
  echo "Windows SDK version                                    : ${WindowsSDKVersion}"
  echo "Visual Studio command-line environment initialized for : ${TARGET_ARCH}"
  export WindowsSdkDir
  export WindowsSDKVersion
  export PATH
  export INCLUDE
  export LIB
  export VSINSTALLDIR
  export VSINSTALLVERSION
  export VCToolsVersion
  export VCINSTALLDIR
  export VCTOOLSINSTALLDIR
  export MSC_FULL_VER
  export MSC_VER
}

# Function: config_oneapi
# Purpose: Comprehensive setup for the Intel oneAPI toolchain environment.
#          Configures environment variables for multiple oneAPI components:
#          - Intel LLVM-based C++ Compiler (ICX/ICPX) and classic Fortran Compiler
#          - Intel MPI Library
#          - Intel Math Kernel Library (MKL)
#          - Intel Threading Building Blocks (TBB)
#          - Intel Integrated Performance Primitives (IPP) and Cryptography (IPPCP)
#          - Intel DPC++ Library (oneDPL)
#          - And other tools (Debugger, OCLOC, etc.)
#          The specific components activated depend on their installation presence.
config_oneapi()
{
  ONEAPI_ROOT='C:\Program Files (x86)\Intel\oneAPI'
  if [ -d "${ONEAPI_ROOT:-}" ]; then
    #
    # Intel OneAPI environment initialized for $ARCH
    #
    ONEAPI_ROOT=$(cygpath -d 'C:\Program Files (x86)\Intel\oneAPI')
    CMPLR_ROOT="${ONEAPI_ROOT}"'\compiler\latest'
    DEV_UTILITIES_ROOT="${ONEAPI_ROOT}"'\dev-utilities\latest'
    DPL_ROOT="${ONEAPI_ROOT}"'\dpl\latest'
    OCLOC_ROOT="${ONEAPI_ROOT}"'\ocloc\latest'
    I_MPI_ROOT="${ONEAPI_ROOT}"'\mpi\latest'
    INTELGTDEBUGGERROOT="${ONEAPI_ROOT}"'\debugger\latest'
    TBBROOT="${ONEAPI_ROOT}"'\tbb\latest'
    MKLROOT="${ONEAPI_ROOT}"'\mkl\latest'
    IPPROOT="${ONEAPI_ROOT}"'\ipp\latest'
    IPPCRYPTOROOT="${ONEAPI_ROOT}"'\ippcp\latest'
    IFORT_COMPILER24="${ONEAPI_ROOT}"'\compiler\2024.2'
    USE_INTEL_LLVM=1
    TARGET_VS=vs2022
    if [[ "${TARGET_ARCH}" == "x64" ]]; then
      INTEL_TARGET_ARCH=intel64
      if [ -d "${IPPCRYPTOROOT:-}" ]; then
        IPPCP_TARGET_ARCH=intel64
      fi
      if [ -d "${IPPROOT:-}" ]; then
        IPP_TARGET_ARCH=intel64
      fi
      if [ -d "${TBBROOT:-}" ]; then
        TBB_ARCH_SUFFIX=
        TBB_TARGET_ARCH=intel64
      fi
      VS_TARGET_ARCH=amd64
    else
      INTEL_TARGET_ARCH=ia32
      INTEL_TARGET_ARCH_IA32=ia32
      if [ -d "${IPPCRYPTOROOT:-}" ]; then
        IPPCP_TARGET_ARCH=ia32
      fi
      if [ -d "${IPPROOT:-}" ]; then
        IPP_TARGET_ARCH=ia32
      fi
      if [ -d "${TBBROOT:-}" ]; then
        TBB_ARCH_SUFFIX=32
        TBB_TARGET_ARCH=ia32
      fi
      VS_TARGET_ARCH=x86
    fi
    # Intel DPC/C++ compiler
    if [ -d "${CMPLR_ROOT:-}" ]; then
      CMAKE_PREFIX_PATH=$(prepend_path "${ONEAPI_ROOT}"'\compiler\latest' "${CMAKE_PREFIX_PATH:-}" ";")
      CPATH=$(prepend_path "${ONEAPI_ROOT}"'\compiler\latest\include' "${CPATH:-}" ";")
      INCLUDE=$(prepend_path "${ONEAPI_ROOT}"'\compiler\latest\include' "${INCLUDE:-}" ";")
      LIB=$(prepend_path "${ONEAPI_ROOT}"'\compiler\latest\lib\clang\19\lib\windows' "${LIB:-}" ";")
      LIB=$(prepend_path "${ONEAPI_ROOT}"'\compiler\latest\opt\compiler\lib' "${LIB:-}" ";")
      LIB=$(prepend_path "${ONEAPI_ROOT}"'\compiler\latest\lib'"${TBB_ARCH_SUFFIX:-}" "${LIB:-}" ";")
      OCL_ICD_FILENAMES=$(prepend_path "${ONEAPI_ROOT}"'\compiler\latest\bin\intelocl64_emu.dll' "${OCL_ICD_FILENAMES:-}" ";")
      OCL_ICD_FILENAMES=$(prepend_path "${ONEAPI_ROOT}"'\compiler\latest\bin\intelocl64.dll' "${OCL_ICD_FILENAMES:-}" ";")
      PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/compiler/latest/lib/ocloc" "${PATH:-}" ":")
      PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/compiler/latest/bin${TBB_ARCH_SUFFIX:-}" "${PATH:-}" ":")
      if [ $USE_INTEL_LLVM -eq 1 ]; then
        PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/compiler/latest/bin/compiler" "${PATH:-}" ":")
      fi
      PKG_CONFIG_PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/compiler/latest/lib${TBB_ARCH_SUFFIX:-}/pkgconfig" "${PKG_CONFIG_PATH:-}" ":")
    fi
    # Intel dev utilities
    if [ -d "${DEV_UTILITIES_ROOT:-}" ]; then
      CPATH=$(prepend_path "${ONEAPI_ROOT}"'\dev-utilities\latest\include' "${CPATH:-}" ";")
      INCLUDE=$(prepend_path "${ONEAPI_ROOT}"'\dev-utilities\latest\include' "${INCLUDE:-}" ";")
      PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/dev-utilities/latest/bin" "${PATH:-}" ":")
    fi
    #  Intel OpenCL Offline Compiler
    if [ -d "${OCLOC_ROOT:-}" ]; then
      CPATH=$(prepend_path "${ONEAPI_ROOT}"'\ocloc\latest\include' "${CPATH:-}" ";")
      INCLUDE=$(prepend_path "${ONEAPI_ROOT}"'\ocloc\latest\include' "${INCLUDE:-}" ";")
      PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/ocloc/latest/bin" "${PATH:-}" ":")
    fi
    # Intel DPC Library
    if [ -d "${DPL_ROOT:-}" ]; then
      CMAKE_PREFIX_PATH=$(prepend_path "${ONEAPI_ROOT}"'\dpl\latest\lib\cmake\oneDPL' "${CMAKE_PREFIX_PATH:-}" ";")
      CPATH=$(prepend_path "${ONEAPI_ROOT}"'\dpl\latest\include' "${CPATH:-}" ";")
      PKG_CONFIG_PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/dpl/latest/lib/pkgconfig" "${PKG_CONFIG_PATH:-}" ":")
    fi
    # Intel MPI Library
    if [ -d "${I_MPI_ROOT:-}" ]; then
      I_MPI_OFI_LIBRARY_INTERNAL=1
      INCLUDE=$(prepend_path "${ONEAPI_ROOT}"'\mpi\latest\include' "${INCLUDE:-}" ";")
      LIB=$(prepend_path "${ONEAPI_ROOT}"'\mpi\latest\lib' "${LIB:-}" ";")
      PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/mpi/latest/opt/mpi/libfabric/bin" "${PATH:-}" ":")
      PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/mpi/latest/bin" "${PATH:-}" ":")
      PKG_CONFIG_PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/mpi/latest/lib/pkgconfig" "${PKG_CONFIG_PATH:-}" ":")
    fi
    # Intel Debuger
    if [ -d "${INTELGTDEBUGGERROOT:-}" ]; then
      DIAGUTIL_PATH="${ONEAPI_ROOT}"'\debugger\latest\etc\debugger\sys_check'
      PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/debugger/latest/opt/debugger/bin" "${PATH:-}" ":")
    fi
    # Intel TBB
    if [ -d "${TBBROOT:-}" ]; then
      CMAKE_PREFIX_PATH=$(prepend_path "${ONEAPI_ROOT}"'\tbb\latest' "${CMAKE_PREFIX_PATH:-}" ";")
      CPATH=$(prepend_path "${ONEAPI_ROOT}"'\tbb\latest\include' "${CPATH:-}" ";")
      INCLUDE=$(prepend_path "${ONEAPI_ROOT}"'\tbb\latest\include' "${INCLUDE:-}" ";")
      LIB=$(prepend_path "${ONEAPI_ROOT}"'\tbb\latest\lib'"${TBB_ARCH_SUFFIX:-}" "${LIB:-}" ";")
      PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/tbb/latest/bin${TBB_ARCH_SUFFIX:-}" "${PATH:-}" ":")
      PKG_CONFIG_PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/tbb/latest/lib${TBB_ARCH_SUFFIX:-}/pkgconfig" "${PKG_CONFIG_PATH:-}" ":")
      TBB_BIN_DIR="${ONEAPI_ROOT}"'\tbb\latest\bin'"${TBB_ARCH_SUFFIX:-}"
      TBB_DLL_PATH="${ONEAPI_ROOT}"'\tbb\latest\bin'"${TBB_ARCH_SUFFIX:-}"
      TBB_SCRIPT_DIR="${ONEAPI_ROOT}"'\tbb\latest'
    fi
    # Intel MKL
    if [ -d "${MKLROOT:-}" ]; then
      CPATH=$(prepend_path "${ONEAPI_ROOT}"'\mkl\latest\include' "${CPATH:-}" ";")
      INCLUDE=$(prepend_path "${ONEAPI_ROOT}"'\mkl\latest\include' "${INCLUDE:-}" ";")
      LIB=$(prepend_path "${ONEAPI_ROOT}"'\mkl\latest\lib'"${TBB_ARCH_SUFFIX:-}" "${LIB:-}" ";")
      NLSPATH="${ONEAPI_ROOT}"'\mkl\latest\share\locale\1033'
      PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/mkl/latest/bin${TBB_ARCH_SUFFIX:-}" "${PATH:-}" ":")
      PKG_CONFIG_PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/mkl/latest/lib/pkgconfig" "${PKG_CONFIG_PATH:-}" ":")
    fi
    # Intel IPP
    if [ -d "${IPPROOT:-}" ]; then
      CMAKE_PREFIX_PATH=$(prepend_path "${ONEAPI_ROOT}"'\ipp\latest\lib\cmake\ipp' "${CMAKE_PREFIX_PATH:-}" ";")
      INCLUDE=$(prepend_path "${ONEAPI_ROOT}"'\ipp\latest\include' "${INCLUDE:-}" ";")
      LIB=$(prepend_path "${ONEAPI_ROOT}"'\ipp\latest\lib'"${TBB_ARCH_SUFFIX:-}" "${LIB:-}" ";")
      CPATH=$(prepend_path "${ONEAPI_ROOT}"'\ipp\latest\include' "${CPATH:-}" ";")
      LIBRARY_PATH=$(prepend_path "${ONEAPI_ROOT}"'\ipp\latest\lib'"${TBB_ARCH_SUFFIX:-}" "${LIB:-}" ";")
      PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/ipp/latest/bin" "${PATH:-}" ":")
    fi
    # Intel IPPCP
    if [ -d "${IPPCRYPTOROOT:-}" ]; then
      IPPCP_TARGET_BIN_ARCH=bin
      IPPCP_TARGET_LIB_ARCH=lib
      CPATH=$(prepend_path "${ONEAPI_ROOT}"'\ippcp\latest\include' "${CPATH:-}" ";")
      INCLUDE=$(prepend_path "${ONEAPI_ROOT}"'\ippcp\latest\include' "${INCLUDE:-}" ";")
      LIB=$(prepend_path "${ONEAPI_ROOT}"'\ippcp\latest\lib'"${TBB_ARCH_SUFFIX:-}" "${LIB:-}" ";")
      LIBRARY_PATH=$(prepend_path "${ONEAPI_ROOT}"'\ippcp\latest\lib'"${TBB_ARCH_SUFFIX:-}" "${LIB:-}" ";")
      PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/ippcp/latest/bin${TBB_ARCH_SUFFIX:-}" "${PATH:-}" ":")
      PKG_CONFIG_PATH=$(prepend_path "$(cygpath -u "${ONEAPI_ROOT}")/ippcp/latest/lib/pkgconfig" "${PKG_CONFIG_PATH:-}" ":")
    fi
    echo "Intel OneAPI Install Directory                         : $(cygpath -w -l "${ONEAPI_ROOT}")"
    echo ":: initializing oneAPI environment..."
    echo "   Initializing Visual Studio command-line environment..."
    echo "   Visual Studio version $VCToolsVersion environment configured."
    echo "   \"$(cygpath -w -l "${VSINSTALLDIR}")\""
    echo "   Visual Studio command-line environment initialized for: '${TARGET_ARCH}'"
    if [ -d "${CMPLR_ROOT:-}" ]; then
      echo ":  compiler -- latest"
      export CMPLR_ROOT
      export IFORT_COMPILER24
    fi
    if [ -d "${INTELGTDEBUGGERROOT:-}" ]; then
      echo ":  debugger -- latest"
      export DIAGUTIL_PATH
    fi
    if [ -d "${DEV_UTILITIES_ROOT:-}" ]; then
      echo ":  dev-utilities -- latest"
      export INTELGTDEBUGGERROOT
    fi
    if [ -d "${DPL_ROOT:-}" ]; then
      echo ":  dpl -- latest"
      export DPL_ROOT
    fi
    if [ -d "${IPPROOT:-}" ]; then
      echo ":  ipp -- latest"
      export IPP_TARGET_ARCH
      export IPPROOT
    fi
    if [ -d "${IPPCRYPTOROOT:-}" ]; then
      echo ":  ippcp -- latest"
      export IPPCP_TARGET_ARCH
      export IPPCP_TARGET_BIN_ARCH
      export IPPCP_TARGET_LIB_ARCH
      export IPPCRYPTOROOT
    fi
    if [ -d "${MKLROOT:-}" ]; then
      echo ":  mkl -- latest"
      export MKLROOT
      export NLSPATH
    fi
    if [ -d "${I_MPI_ROOT:-}" ]; then
      echo ":  mpi -- latest"
      export I_MPI_OFI_LIBRARY_INTERNAL
      export I_MPI_ROOT
    fi
    if [ -d "${OCLOC_ROOT:-}" ]; then
      echo ":  ocloc -- latest"
      export OCLOC_ROOT
      export OCL_ICD_FILENAMES
    fi
    if [ -d "${TBBROOT:-}" ]; then
      echo ":  tbb -- latest"
      export TBBROOT
      export TBB_ARCH_SUFFIX
      export TBB_BIN_DIR
      export TBB_DLL_PATH
      export TBB_SCRIPT_DIR
      export TBB_TARGET_ARCH
    fi
    echo ":: oneAPI environment initialized ::"
    export CMAKE_PREFIX_PATH
    export CPATH
    export INCLUDE
    export INTEL_TARGET_ARCH
    export INTEL_TARGET_ARCH_IA32
    export LIB
    export LIBRARY_PATH
    export ONEAPI_ROOT
    export PATH
    export PKG_CONFIG_PATH
    export TARGET_VS
    export USE_INTEL_LLVM
    export VS_TARGET_ARCH
  fi
}

# Function: config_cuda
# Purpose: Initializes the environment for the NVIDIA CUDA Toolkit.
#          Adds CUDA binary, include, and library directories to PATH, INCLUDE, and LIB.
#          Queries and displays the GPU's compute capability version.
config_cuda()
{
  if [ -d "${CUDA_PATH:-}" ]; then
    CUDA_HOME=$(cygpath -d "${CUDA_PATH}")
    PATH=$(prepend_path "$(cygpath -u "${CUDA_HOME}")/bin" "${PATH:-}" ":")
    PATH=$(prepend_path "$(cygpath -u "${CUDA_HOME}")/extras/demo_suite" "${PATH:-}" ":")
    INCLUDE=$(prepend_path "${CUDA_HOME}"'\include' "${INCLUDE:-}" ";")
    LIB=$(prepend_path "${CUDA_HOME}"'\lib\x64' "${LIB:-}" ";")
    NV_COMPUTE=$(deviceQuery | awk '/CUDA Capability Major/{print $(NF)}')
    echo "Initializing CUDA command-line environment..."
    echo "CUDA Install Directory                                 : $(cygpath -w -l "${CUDA_HOME}")"
    echo "CUDA Capability Major/Minor version number             : ${NV_COMPUTE}"
    echo "CUDA command-line environment initialized for          : ${TARGET_ARCH}"
    export CUDA_HOME
    export PATH
    export LIB
    export INCLUDE
    export NV_COMPUTE
  fi
}

# Function: config_misc
# Purpose: Processes the semicolon-separated list of directories in $PREFIX_PATH.
#          Prepend their include/, lib/, lib/cmake, and lib/pkgconfig subdirectories
#          to the respective environment variables (INCLUDE, LIB, CMAKE_PREFIX_PATH, PKG_CONFIG_PATH).
#          This prioritizes user-provided or third-party libraries over system ones,
#          crucial for avoiding conflicts (e.g., with ICU libraries provided by VC++).
config_misc()
{
  # NOTE:
  # 1. There may have name conflict between third-party libraries and compiler's one, e.g. icuuc.lib.
  #    In order to link the correct one. The paths of some third-party libraries must be placed in
  #    front of the compiler's path
  # 2. Taken care of bin PATH, let it updated in mpt.py but not here. Because some program must use the
  #    one from Git for Windows, e.g. m4.
  # 3. Commented out following two lines. Because the final element has a newline that hasn't been removed.
  #    This will cause ifort can't work on cygwin/msys2 environment.
  #   readarray -t d';' array <<<"$PREFIX_PATH"
  #   for p in "${array[@]}"; do
  for p in ${PREFIX_PATH//;/ }; do
    if [ -d "${p}" ]; then
      _p=$(cygpath -u "${p}")
      if [ -d "${_p}/include" ]; then
        INCLUDE=$(prepend_path "${p}"'\include' "${INCLUDE:-}" ";")
      fi
      if [ -d "${_p}/lib" ]; then
        LIB=$(prepend_path "${p}"'\lib' "${LIB:-}" ";")
      fi
      if [ -d "${_p}/lib/cmake" ]; then
        CMAKE_PREFIX_PATH=$(prepend_path "${p}"'\lib\cmake' "${CMAKE_PREFIX_PATH:-}" ";")
      fi
      if [ -d "${_p}/lib/pkgconfig" ]; then
        PKG_CONFIG_PATH=$(prepend_path "$(cygpath -u "${_p}/lib/pkgconfig")" "${PKG_CONFIG_PATH:-}" ":")
      fi
    fi
  done
  export INCLUDE
  export LIB
  export CMAKE_PREFIX_PATH
  export PKG_CONFIG_PATH
}

# Main script argument parsing loop
HOST_ARCH=
TARGET_ARCH=
WITH_ONEAPI=
while [[ $# -gt 0 ]]; do
  case "$1" in
    x86 | amd64_x86 | x64_x86)
      TARGET_ARCH=x86
      shift 1
      ;;
    x86_amd64 | x86_x64 | amd64 | x64)
      TARGET_ARCH=x64
      shift 1
      ;;
    oneapi)
      WITH_ONEAPI=1
      shift 1
      ;;
    *)
      ;;
  esac
done

if [ "${TARGET_ARCH}" != "x86" ] && [ "${TARGET_ARCH}" != "x64" ]; then
  echo "Error: The environment variable 'ARCH' must be x86 or x64"
  exit 1
fi
check_arch
config_msvc
if [[ -n "${WITH_ONEAPI}" ]]; then
  config_oneapi
fi
config_cuda
config_misc
