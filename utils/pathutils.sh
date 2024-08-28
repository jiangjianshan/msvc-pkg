#!/bin/bash

# Convert path to an absolute unix-style path
unix_path()
{
  local path=$1
  case "$bash_platform" in
    WSL)
      case "$path" in
      [a-zA-Z]:\\* | [a-zA-Z]:/* | \\\\* | //*)
        # Convert windows path using wslpath (unix mode, absolute path)
        wslpath -u -a -- "$path"
        ;;
      *)
        # Convert unix path using realpath
        realpath -m -- "$path"
        ;;
      esac
      ;;
    *)
      cygpath -u -a -- "$path"
      ;;
  esac
}

# Convert path to an absolute windows-style path
win_wpath()
{
  local path=$1
  case "$bash_platform" in
    WSL)
      case "$path" in
      [a-zA-Z]:\\* | [a-zA-Z]:/* | \\\\* | //*)
        # Already a windows path
        printf '%s' "$path"
        ;;
      *)
        # Convert using wslpath (windows mode, absolute path)
        wslpath -w -a -- "$path"
        ;;
      esac
      ;;
    *)
      # Convert using cygpath (windows mode, absolute path, long form)
      cygpath -w -a -l -- "$path"
      ;;
  esac
}

# Convert path to an absolute windows-style path, but with regular slashes
win_mpath()
{
  local path=$1
  case "$bash_platform" in
    WSL)
      case "$path" in
      [a-zA-Z]:\\* | [a-zA-Z]:/* | \\\\* | //*)
        # Already a windows path
        printf '%s' "$path"
        ;;
      *)
        # Convert using wslpath (windows mode, absolute path)
        wslpath -m -a -- "$path"
        ;;
      esac
      ;;
    *)
      # Convert using cygpath (windows mode, absolute path, long form)
      cygpath -m -a -l -- "$path"
      ;;
  esac
}

# Convert a windows-style path list to a unix-style path list
win_unixpaths()
{
  local win_paths=$1

  local path_dir first=true
  while IFS= read -r -d';' path_dir; do
    if [[ -z "$path_dir" ]]; then continue; fi
    if [[ "$first" == 'true' ]]; then first=false; else printf ':'; fi
    printf '%s' "$(unix_path "$path_dir")"
  done <<<"${win_paths};"
}

# Normalize a unix-style path list, removing duplicates and empty entries
normalize_paths()
{
  local unix_paths=$1

  declare -A seen_paths
  local path_dir first=true
  while IFS= read -r -d ':' path_dir; do
    if [[ -z "$path_dir" ]]; then continue; fi
    if [[ -n "${seen_paths[$path_dir]:-}" ]]; then continue; fi
    seen_paths[$path_dir]=1

    if [[ "$first" == 'true' ]]; then first=false; else printf ':'; fi
    printf '%s' "$path_dir"
  done <<<"${unix_paths}:"
}

# Convert CRLF to LF
fix_crlf()
{
  sed 's/\r$//'
}

# check which bash environment is running
case "${OSTYPE:-}" in
  cygwin* | msys* | win32)
    declare bash_platform='CYG'
    ;;
  *)
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
      declare bash_platform='WSL'
    else
      printf 'error: Unsupported platform (%s)\n' "${OSTYPE:-}" >&2
      printf 'hint: This script only supports Bash on Windows (Git Bash, WSL, etc.)\n' >&2
      return 1
    fi
    ;;
esac

