#!/bin/bash
#
# Set build environment of Visutal C++ Build Tools and Intel OneAPI
#

LANG=en_US
export LANG

check_arch()
{
  local mach_name=
  mach_name=$(uname -m)
  case $mach_name in
    x86_64 )
      export HOST_ARCH=x64  # or AMD64 or Intel64 or whatever
      ;;
    i*86 )
      export HOST_ARCH=x86  # or IA32 or Intel32 or whatever
      ;;
    * )
      # leave HOST_ARCH as-is
      ;;
  esac
  if [ -z "$ARCH" ]; then
    ARCH=x64
  fi
}

check_arch
if [[ "$ARCH" == "x86" ]] || [[ "$ARCH" == "x64" ]]; then
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
  # for creating 32-bit or 64-bit binaries: through the following bash commands:
  # Set environment variables for using MSVC 14,
  # for creating native 32-bit or 64-bit Windows executables.

  # Windows tools
  PATH=$(cygpath -u 'C:\Program Files (x86)\Windows Kits\10')/bin/${WindowsSDKVersion}/${ARCH}:"$PATH"

  # Windows C library headers and libraries.
  WindowsCrtIncludeDir='C:\Program Files (x86)\Windows Kits\10\Include\'"${WindowsSDKVersion}"'\ucrt'
  WindowsCrtLibDir='C:\Program Files (x86)\Windows Kits\10\Lib\'"${WindowsSDKVersion}"'\ucrt\'
  if [ -z "$INCLUDE" ]; then
    INCLUDE="${WindowsCrtIncludeDir}"
  else
    INCLUDE="${WindowsCrtIncludeDir};$INCLUDE"
  fi
  if [ -z "$LIB" ]; then
    LIB="${WindowsCrtLibDir}${ARCH}"
  else
    LIB="${WindowsCrtLibDir}${ARCH};$LIB"
  fi

  # Windows API headers and libraries.
  WindowsSdkIncludeDir='C:\Program Files (x86)\Windows Kits\10\Include\'"${WindowsSDKVersion}"'\'
  WindowsSdkLibDir='C:\Program Files (x86)\Windows Kits\10\Lib\'"${WindowsSDKVersion}"'\um\'
  INCLUDE="${WindowsSdkIncludeDir}um;${WindowsSdkIncludeDir}shared;$INCLUDE"
  LIB="${WindowsSdkLibDir}${ARCH};$LIB"

  # Windows WinRT library headers and libraries.
  WindowsWinrtIncludeDir='C:\Program Files (x86)\Windows Kits\10\Include\'"${WindowsSDKVersion}"'\winrt'
  WindowsWinrtLibDir='C:\Program Files (x86)\Windows Kits\10\Lib\'"${WindowsSDKVersion}"'\winrt\'
  INCLUDE="${WindowsWinrtIncludeDir};$INCLUDE"
  LIB="${WindowsWinrtLibDir}${ARCH};$LIB"

  # Windows CppWinRT library headers and libraries.
  WindowsCppWinrtIncludeDir='C:\Program Files (x86)\Windows Kits\10\Include\'"${WindowsSDKVersion}"'\cppwinrt'
  WindowsCppWinrtLibDir='C:\Program Files (x86)\Windows Kits\10\Lib\'"${WindowsSDKVersion}"'\cppwinrt\'
  INCLUDE="${WindowsCppWinrtIncludeDir};$INCLUDE"
  LIB="${WindowsCppWinrtLibDir}${ARCH};$LIB"

  # Visual C++ tools, headers and libraries.
  VSWHERE=$(cygpath -u 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe')
  VSINSTALLDIR=$("$VSWHERE" -nologo -latest -products "*" -all -property installationPath | tr -d '\r')
  VSINSTALLVERSION=$("$VSWHERE" -nologo -latest -products "*" -all -property installationVersion | tr -d '\r')
  VCToolsVersion=$(head -1 "${VSINSTALLDIR}"'\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt' | tr -d '\r')
  VCINSTALLDIR="${VSINSTALLDIR}"'\VC\Tools\MSVC\'"${VCToolsVersion}"
  # build some project need VCTOOLSINSTALLDIR, e.g. perl
  VCTOOLSINSTALLDIR=${VCINSTALLDIR}
  PATH=$(cygpath -u "${VCINSTALLDIR}")/bin/Host${HOST_ARCH}/${ARCH}:"$PATH"
  INCLUDE="${VCINSTALLDIR}"'\include;'"${VCINSTALLDIR}"'\atlmfc\include;'"${INCLUDE}"
  LIB="${VCINSTALLDIR}"'\lib\'"${ARCH}"';'"${VCINSTALLDIR}"'\atlmfc\lib\'"${ARCH}"';'"${LIB}"

  # Universal CRT
  PATH=$(cygpath -u "${WindowsSdkDir}")Redist/ucrt/DLLs/$ARCH:"$PATH"

  # MSBuild
  if [ "$HOST_ARCH" == "x86" ]; then
    PATH=$(cygpath -u "${VSINSTALLDIR}")/MSBuild/Current/Bin:"$PATH"
  else
    PATH=$(cygpath -u "${VSINSTALLDIR}")/MSBuild/Current/Bin/amd64:"$PATH"
  fi
  # location of Microsoft.Cpp.Default.props
  PATH=$(cygpath -u "${VSINSTALLDIR}")'/MSBuild/Microsoft/VC/v'"${VSINSTALLVERSION%%.*}"'0:'"$PATH"

  echo "[$0] Initializing Visual Studio command-line environment..."
  echo "Visual C++ Tools Version                               : $VCToolsVersion"
  echo "Visual C++ Install Directory                           : $VCINSTALLDIR"
  echo "Windows SDK Install Directory                          : $WindowsSdkDir"
  echo "Windows SDK version                                    : $WindowsSDKVersion"
  echo "Visual Studio command-line environment initialized for : $ARCH"

  # NOTE:
  # 1. There may have name conflict between third-party libraries and compiler's one, e.g. icuuc.lib.
  #    In order to link the correct one. The paths of some third-party libraries must be placed in
  #    front of the compiler's path
  # 2. Taken care of bin PATH, let it updated in mpt.py but not here. Because some program must use the
  #    one from Git for Windows, e.g. m4.
  readarray -td';' array <<<"$PREFIX_PATH"
  for p in "${array[@]}"; do
    _p=$(cygpath -u "${p}")
    [[ -d "${_p}/include" ]] && INCLUDE="${p}"'\include;'"${INCLUDE}"
    [[ -d "${_p}/lib" ]] && LIB="${p}"'\lib;'"${LIB}"
    [[ -d "${_p}/lib/cmake" ]] && CMAKE_PREFIX_PATH="${_p}"/lib/cmake:"${CMAKE_PREFIX_PATH}"
    [[ -d "${_p}/lib/pkgconfig" ]] && PKG_CONFIG_PATH="${_p}"/lib/pkgconfig:"${PKG_CONFIG_PATH}"
  done

fi

export INCLUDE LIB PATH VCINSTALLDIR WindowsSdkDir WindowsSDKVersion VSINSTALLDIR VCTOOLSINSTALLDIR VSINSTALLVERSION VCToolsVersion CMAKE_PREFIX_PATH PKG_CONFIG_PATH
