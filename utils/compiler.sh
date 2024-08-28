#!/bin/bash

export LC_ALL=C
set -o pipefail

# NOTE: Avoid to be sourced multiple times
[ "$sourced_compiler_sh" != "" ] && return || sourced_compiler_sh=.
export sourced_compiler_sh

# Locate vcvarsall.bat
# Inputs:
#   VSINSTALLDIR: The path to the Visual Studio installation directory (optional)
# Outputs:
#   stdout: The windows-style path to vcvarsall.bat
find_vcvarsall()
{
  local vsinstalldir

  if [[ -n "${VSINSTALLDIR:-}" ]]; then
    vsinstalldir="$VSINSTALLDIR"
  else
    local vswhere
    vswhere=$(command -v 'vswhere' 2>/dev/null || unix_path 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe')
    vsinstalldir=$("$vswhere" -nologo -latest -products "*" -all -property installationPath </dev/null | fix_crlf)
    if [[ -z "$vsinstalldir" ]]; then
      printf 'error: vswhere returned an empty installation path\n' >&2
      return 1
    fi
  fi
  printf '%s\n' "$(win_wpath "$vsinstalldir")\\VC\\Auxiliary\\Build\\vcvarsall.bat"
}

# Run a command with cmd.exe
# Inputs:
#   $@: The command string to run (use cmdesc to escape arguments when needed)
# Outputs:
#   stdout: The cmd.exe standard output
#   stderr: The cmd.exe error output
cmd()
{
  # This seems to work fine on all supported platforms
  # (even with all the weird path and argument conversions on MSYS-like)
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' cmd.exe /s /c " ; $* "
}

# Escape a cmd.exe command argument
# Inputs:
#   $1: The argument to escape
# Outputs:
#   stdout: The escaped argument
cmdesc()
{
  sed 's/[^0-9A-Za-z]/^\0/g' <<<"$1"
}

. utils/pathutils.sh
 
vcvarsall_args=()
for arg in "$@"; do
  vcvarsall_args+=("$(cmdesc "$arg")")
done

# Get MSVC environment variables from vcvarsall.bat
vcvarsall=$(find_vcvarsall)
vcvarsall_env=$({ cmd "$(cmdesc "$vcvarsall")" "${vcvarsall_args[@]}" '&&' 'set' </dev/null || true; } | fix_crlf)

# Filter MSVC environment variables and export them.
# The list of variables to export was based on a comparison between a clean environment and the vcvarsall.bat
# environment (on different MSVC versions, tools and architectures).
#
# Windows environment variables are case-insensitive while Unix-like environment variables are case-sensitive, so:
# - we always use uppercase names to prevent duplicates environment variables on the Unix-like side
# - we also ensure that only the first occurrence of a variable is exported (see below)
#
# While Windows environment variables are case-insensitive, it is possible to have duplicates in some edge cases.
# e.g. using Git Bash:
#  export xxx=1; export XXX=2; export xXx=3; cmd.exe //c set XxX=4 '&&' set
# will output:
#  XXX=4
#  xXx=3
#  xxx=1

declare -A seen_vars
export_env()
{
  local name=${1^^}
  local value=$2

  if [[ ! "$name" =~ ^[A-Z0-9_]+$ ]]; then return; fi
  if [[ -n "${seen_vars[$name]:-}" ]]; then return; fi
  seen_vars[$name]=1
  export "${name}=${value}"
}

name=
value=
initialized=false
while IFS='=' read -r name value; do
  if [[ "$initialized" == 'false' ]]; then
    if [[ -n "$value" ]]; then name+="=$value"; fi
    if [[ "$name" == *' Environment initialized for: '* ]]; then initialized=true; fi
    printf '%s\n' "$name" >&2
    continue
  fi

  case "${name^^}" in
  LIB | LIBPATH | INCLUDE | EXTERNAL_INCLUDE | COMMANDPROMPTTYPE | DEVENVDIR | EXTENSIONSDKDIR | FRAMEWORK* | \
    PLATFORM | PREFERREDTOOLARCHITECTURE | UCRT* | UNIVERSALCRTSDK* | VCIDE* | VCINSTALL* | VCPKG* | VCTOOLS* | \
    VSCMD* | VSINSTALL* | VS[0-9]* | VISUALSTUDIO* | WINDOWSLIB* | WINDOWSSDK*)
    export_env "$name" "$value"
    ;;
  PATH)
    # PATH is a special case, requiring special handling
    new_paths=
    new_paths=$(win_unixpaths "$value")             # Convert to unix-style path list
    new_paths=$(normalize_paths "${new_paths}:${PATH}") # Prepend the current PATH
    export_env 'WINDOWS_PATH' "$value"
    export_env 'PATH' "$new_paths"
    ;;
  esac
done <<<"$vcvarsall_env"
