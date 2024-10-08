#!/bin/bash

export LC_ALL=C
set -o pipefail

exit_error()
{
  local line_no=$1
  local err_code=$2
  echo -e "[$0] Failed at line ${RED}$line_no${COL_RESET} with error code ${RED}$err_code${COL_RESET}"
  exit $err_code
}

build_log()
{
  tee -a "$LOG_FILE"
}

display_info()
{
  echo [$0] Display information > >(build_log) 2>&1
  printf "%-18s: %s\n" "PKG_DEPS" "$PKG_DEPS" > >(build_log) 2>&1
  printf "%-18s: %s\n" "ARCH" "$ARCH" > >(build_log) 2>&1
  printf "%-18s: %s\n" "HOST_ARCH" "$HOST_ARCH" > >(build_log) 2>&1
  printf "%-18s: %s\n" "FWD" "$FWD" > >(build_log) 2>&1
  printf "%-18s: %s\n" "PREFIX" "$PREFIX" > >(build_log) 2>&1
  printf "%-18s: %s\n" "PREFIX_M" "$PREFIX_M" > >(build_log) 2>&1
  printf "%-18s: %s\n" "PREFIX_W" "$PREFIX_W" > >(build_log) 2>&1
  printf "%-18s: %s\n" "TAGS_DIR" "$TAGS_DIR" > >(build_log) 2>&1
  printf "%-18s: %s\n" "PATCHES_DIR" "$PATCHES_DIR" > >(build_log) 2>&1
  printf "%-18s: %s\n" "PKGS_DIR" "$PKGS_DIR" > >(build_log) 2>&1
  printf "%-18s: %s\n" "PKG_NAME" "$PKG_NAME" > >(build_log) 2>&1
  printf "%-18s: %s\n" "PKG_VER" "$PKG_VER" > >(build_log) 2>&1
  printf "%-18s: %s\n" "PKG_URL" "$PKG_URL" > >(build_log) 2>&1
  printf "%-18s: %s\n" "SRC_DIR" "$SRC_DIR" > >(build_log) 2>&1
  printf "%-18s: %s\n" "SRC_DIR_M" "$SRC_DIR_M" > >(build_log) 2>&1
  printf "%-18s: %s\n" "BUILD_DIR" "$BUILD_DIR" > >(build_log) 2>&1
  printf "%-18s: %s\n" "BUILD_DIR_M" "$BUILD_DIR_M" > >(build_log) 2>&1
  printf "%-18s: %s\n" "LOGS_DIR" "$LOGS_DIR" > >(build_log) 2>&1
  printf "%-18s: %s\n" "LOG_FILE" "$LOG_FILE" > >(build_log) 2>&1
}

configure_cmd()
{
  "$@" > >(build_log) 2>&1                                                                     \
      | sed -E -e "s| yes$|$(echo -e " ${GREEN}yes${COL_RESET}")|g"                            \
             -e "s| yes |$(echo -e " ${GREEN}yes${COL_RESET} ")|g"                           \
             -e "s| no$|$(echo -e " ${YELLOW}no${COL_RESET}")|g"                             \
             -e "s| no |$(echo -e " ${YELLOW}no${COL_RESET} ")|g"                            \
             -e "s| unsupported$|$(echo -e " ${YELLOW}unsupported${COL_RESET}")|g"           \
             -e "s| Error |$(echo -e "${RED} Error ${COL_RESET}")|g"                         \
             -e "s| error |$(echo -e "${RED} error ${COL_RESET}")|g"                         \
             -e "s| Warning |$(echo -e "${YELLOW} Warning ${COL_RESET}")|g"                  \
             -e "s| Warning:|$(echo -e "${YELLOW} WARNING${COL_RESET}:")|g"                  \
             -e "s| warning |$(echo -e "${YELLOW} warning ${COL_RESET}")|g"                  \
             -e "s| WARNING:|$(echo -e "${YELLOW} WARNING${COL_RESET}:")|g"                  \
      || exit_error $LINENO $?
}

build_cmd()
{
  "$@" > >(build_log) 2>&1                                                                     \
    | sed -E -e "s| Error |$(echo -e "${RED} Error ${COL_RESET}")|g"                           \
           -e "s| error |$(echo -e "${RED} error ${COL_RESET}")|g"                           \
           -e "s| Warning |$(echo -e "${YELLOW} Warning ${COL_RESET}")|g"                    \
           -e "s| warning |$(echo -e "${YELLOW} warning ${COL_RESET}")|g"                    \
    || exit_error $LINENO $?
}

install_cmd()
{
  "$@" > >(build_log) 2>&1                                                                     \
    | sed -E -e "s| Error |$(echo -e "${RED} Error ${COL_RESET}")|g"                           \
           -e "s| error |$(echo -e "${RED} error ${COL_RESET}")|g"                           \
           -e "s| Warning |$(echo -e "${YELLOW} Warning ${COL_RESET}")|g"                    \
           -e "s| warning |$(echo -e "${YELLOW} warning ${COL_RESET}")|g"                    \
    || exit_error $LINENO $?
}

create_dirs()
{
  if [ ! -d "$TAGS_DIR" ]; then mkdir -p $TAGS_DIR; fi
  if [ ! -d "$PKGS_DIR" ]; then mkdir -p $PKGS_DIR; fi
  if [ ! -d "$LOGS_DIR" ]; then mkdir -p $LOGS_DIR; fi
  if [ ! -d "$PREFIX" ]; then mkdir -p $PREFIX; fi
  while test $# -gt 0; do
    case "$1" in
      * )
        if [ ! -d "$PREFIX/$1" ]; then mkdir -p "$PREFIX/$1"; fi
        shift ;;
    esac
  done
}

clean_log()
{
  if [ -f "$LOG_FILE" ]; then rm -rf "$LOG_FILE"; fi
}

check_depends()
{
  cd $FWD/builds
  if [ -n "$PKG_DEPS" ]; then
    local depends_array=($PKG_DEPS)
    for p in "${depends_array[@]}"; do
      echo [$0] Searching dependency $p on $ARCH
      if [ ! -f $OK_FILE ]; then touch $OK_FILE; fi
      if [ -f "$p" ]; then
        eval "$FWD/builds/$p" || exit_error $LINENO $?
      else
        echo [$0] Missing build script for package $p
        exit 1
      fi
    done
  fi
}

download_extract()
{
  local pkg_url=$1
  local archive=$2
  local dest_dir=$3
  cd $TAGS_DIR
  if [ ! -f "$archive" ]; then
    wget --no-check-certificate $pkg_url -O $archive || exit_error $LINENO $?
  else
    case "$archive" in
      *.gz | *.tgz)
        local check_tool=gzip
        ;;
      *.bz2)
        local check_tool=bzip2 
        ;;
      *.xz)
        local check_tool=xz 
        ;;
      *)
        echo "Unknown archive format"
        exit 1
        ;;
    esac
    if ! $check_tool -t "$archive" &>/dev/null; then
      echo [$0] File $archive is corrupted, redownload it again
      wget --no-check-certificate $pkg_url -O $archive || exit_error $LINENO $?
    fi
  fi
  if [ ! -d "$SRC_DIR" ]; then
    cd $PKGS_DIR
    if [[ ! -d "$dest_dir" ]]; then
      mkdir -p "$dest_dir"
    fi
    tar -xvf $TAGS_DIR/$archive -C $dest_dir --strip-components=1 || exit_error $LINENO $?
    patch_package
  fi
}

git_sync()
{
  local branch=$1
  cd $PKGS_DIR
  if [ ! -d "$SRC_DIR" ]; then
    git clone --config core.autocrlf=false --single-branch -b $branch $PKG_URL $PKG_NAME || exit_error $LINENO $?
  elif [ ! -d "$SRC_DIR/.git" ]; then
    rm -rf $SRC_DIR
    git clone --config core.autocrlf=false --single-branch -b $branch $PKG_URL $PKG_NAME || exit_error $LINENO $?
  else
    echo [$0] Updating $PKG_NAME
    pushd $SRC_DIR
    git fetch origin $branch || exit_error $LINENO $?
    git reset --hard origin/$branch || exit_error $LINENO $?
    popd
  fi
}

git_rescure()
{
  local branch=$1
  cd $PKGS_DIR
  if [ ! -d "$SRC_DIR" ]; then
    git clone --recurse-submodules --shallow-submodules -b $branch $PKG_URL
  elif [ ! -d "$SRC_DIR/.git" ]; then
    rm -rf $SRC_DIR
    git clone --recurse-submodules --shallow-submodules -b $branch $PKG_URL
  else
    cd $SRC_DIR
    local branch_ver=`git name-rev --name-only HEAD | sed 's/[^0-9.]*\([0-9.]*\).*/\1/'`
    if [ "$PKG_VER" == "$branch_ver" ]; then
      echo [$0] Branch version is $branch_ver 
      for m in `git status | grep -oP '(?<=modified:\s{3}).*(?=\s{1}\(.*\))'`; do
        rm -rfv $m
      done
      # FIXME:
      # 1. To solve the issue of "fatal: destination path 'xxx' already exists and is 
      #    not an empty directory.", change 'git submodule update --init --recursive'
      #    to following three lines:
      git submodule deinit --force . 
      git submodule init 
      git submodule update --recursive
    else
      cd $PKGS_DIR
      echo [$0] Deleting the old branch version $branch_ver
      rm -rf $SRC_DIR 
      echo [$0] Cloning the new branch version $PKG_VER
      git clone --recurse-submodules --shallow-submodules -b $branch $PKG_URL
    fi
  fi

}

do_actions()
{
  check_depends
  local name=$1
  if [ -z "$name" ]; then
    name=$PKG_NAME
  fi
  if [ ! -s "$OK_FILE" ]; then
    echo [$0] Build library $name because build-ok.txt is empty
    process_build
  elif [[ $CLEAN_BUILD -eq 1 ]]; then
    echo [$0] Build library $name because --clean-build option is present
    process_build
  else
    local not_found=0
    grep -Eqw "$ARCH+\s+$name\s+.+" $OK_FILE || not_found=1
    if [[ $not_found -eq 1 ]]; then
      echo [$0] Build library $name because it was not successful build yet
      process_build
    else
      old_arch=`grep -Eo "\w+\s+$name\s+.+" $OK_FILE | awk '{print $1}' | awk '$1=$1'`
      old_pkg_ver=`grep -Eo "\w+\s+$name\s+.+" $OK_FILE | awk '{print $3}' | awk '$1=$1'`
      if [ "$old_arch" == "$ARCH" ] && [ "$old_pkg_ver" != "$PKG_VER" ]; then
        echo [$0] Build library $name because previous version is older than current one
        process_build
      else
        echo [$0] Library $name was installed, not need to build
      fi
    fi
  fi
}

build_ok()
{
  local name=$1
  if [ -z "$name" ]; then
    name=$PKG_NAME
  fi
  if [[ -f "$OK_FILE" ]] && [[ -s "$OK_FILE" ]]; then
    local not_found=0
    grep -Eqw "$ARCH+\s+$name\s+.+" $OK_FILE || not_found=1
    if [[ $not_found -eq 1 ]]; then
      echo [$0] Append build OK result into build-ok.txt because now it is OK
      printf "%-4s %-26s %-12s %-60s\n" $ARCH "$name" "$PKG_VER" "$PREFIX_M">> $OK_FILE
    else
      old_arch=`grep -Eo "\w+\s+$name\s+.+" $OK_FILE | awk '{print $1}' | awk '$1=$1'`
      old_pkg_ver=`grep -Eo "\w+\s+$name\s+.+" $OK_FILE | awk '{print $3}' | awk '$1=$1'`
      if [ "$old_arch" == "$ARCH" ] && [ "$old_pkg_ver" != "$PKG_VER" ]; then
        echo [$0] Update build OK result into build-ok.txt because version is updated
        replaced_line="`printf "%-4s %-26s %-12s %-60s\n" $ARCH "$name" "$PKG_VER" "$PREFIX_M"`"
        sed                                                                                    \
          -e "s|.\+\s\+$name\s\+.\+|$replaced_line|g"                                         \
        $OK_FILE > $OK_FILE-t
        mv $OK_FILE-t $OK_FILE
      fi
    fi
    sort -n -k 2 $OK_FILE > $OK_FILE-t
    mv $OK_FILE-t $OK_FILE
  else
    echo [$0] Save build OK result because now it is OK and build-ok.txt is empty
    printf "%-4s %-26s %-12s %-60s\n" $ARCH "$name" "$PKG_VER" "$PREFIX_M">> $OK_FILE
  fi
}

configure_options()
{
  if [[ -f "$OK_FILE" ]] && [[ -s "$OK_FILE" ]]; then
    while read -a line; do 
      local old_arch=${line[0]}
      local pkg_name=${line[1]}
      local old_prefix=${line[3]}
      desired_var_name="${pkg_name/-/_}_prefix"
      desired_value=$(unix_path "$old_prefix")
      export ${desired_var_name^^}=$desired_value
      if [[ "$old_arch" == "$ARCH" ]] && [[ "$PREFIX_PATH_M" != *"$old_prefix"* ]]; then
        if [ -z "$PREFIX_PATH_M" ]; then
          PREFIX_PATH_M="$old_prefix"
        else
          PREFIX_PATH_M="$PREFIX_PATH_M;$old_prefix"
        fi
        # NOTE:
        # 1. If add $old_prefix/bin to PATH here, they must be putted behind the 
        #    original $PATH. Especially the path of custom build of Perl.
        #    If not do like that, autoconf and automake will use windows's
        #    Perl but not cygwin's Perl. This will cause the configuration
        #    of prcoess fail
        local old_bin=$(unix_path "$old_prefix/bin")
        if [[ -d "$old_bin" ]] && [[ "$PATH" != *"$old_bin"* ]]; then
          PATH="$PATH":"$old_bin"
        fi
      fi
    done < $OK_FILE
    # For pkg-config from cygwin
    array=($(echo $PREFIX_PATH_M | tr ";" "\n"))
    for p in "${array[@]}"; do
      local old_pkgconfig=$p/lib/pkgconfig
      if [[ -d "$old_pkgconfig" ]] && [[ "$PKG_CONFIG_PATH" != *"$old_pkgconfig"* ]]; then
        if [ -z "$PKG_CONFIG_PATH" ]; then
          PKG_CONFIG_PATH="$p/lib/pkgconfig"
        else
          PKG_CONFIG_PATH="$PKG_CONFIG_PATH;$p/lib/pkgconfig"
        fi
      fi
      # NOTE:
      # 1. Don't add those include path to $INCLUDE, otherwise check_include_file commmand in cmake
      #    may be failed
      # 2. Some msbuild project need this updated $INCLUDE
      local old_include="$p/include"
      if [[ -d "$old_include" ]] && [[ "$INCLUDE" != *"${old_include//\//\\}"* ]]; then
        if [[ -z "$INCLUDE" ]]; then
          INCLUDE=$(win_wpath "$old_include")
        else
          INCLUDE="$INCLUDE"';'$(win_wpath "$old_include")
        fi
      fi
      local old_lib="$p/lib"
      if [[ -d "$old_lib" ]] && [[ "$LIB" != *"${old_lib//\//\\}"* ]]; then
        if [[ -z "$LIB" ]]; then
          LIB=$(win_wpath "$old_lib")
        else
          LIB="$LIB"';'$(win_wpath "$old_lib")
        fi
      fi
    done
  fi
  if [ "$ARCH" == "x86" ]; then
    YASM_OBJ_FMT=win32
  else
    YASM_OBJ_FMT=win64
  fi
  OPTIONS='-nologo -MD -fp:precise -diagnostics:column -wd4819 -openmp:llvm'
  # https://learn.microsoft.com/en-us/cpp/c-runtime-library/compatibility?view=msvc-170
  # https://learn.microsoft.com/en-us/archive/msdn-magazine/2005/may/repel-attacks-with-visual-studio-2005-safe-c-and-c-libraries
  DEFINES="-DWIN32 -D_WIN32_WINNT=$WIN32_TARGET -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS -D_CRT_SECURE_NO_DEPRECATE -D_SILENCE_NONFLOATING_COMPLEX_DEPRECATION_WARNING"
  echo [$0] Part of configuration options:
  printf "%-18s: %s\n" "PKG_CONFIG_PATH" "$PKG_CONFIG_PATH" > >(build_log) 2>&1
  printf "%-18s: %s\n" "CMAKE_PREFIX_PATH" "$PREFIX_PATH_M" > >(build_log) 2>&1
  printf "%-18s: %s\n" "INCLUDE" "$INCLUDE" > >(build_log) 2>&1
  printf "%-18s: %s\n" "LIB" "$LIB" > >(build_log) 2>&1
}

pre_config()
{
  WIN32_TARGET=_WIN32_WINNT_WIN10
  TAGS_DIR=$FWD/tags
  PATCHES_DIR=$FWD/patches
  LOGS_DIR=$FWD/logs
  LOG_FILE=$LOGS_DIR/build-$PKG_NAME.txt
  OK_FILE=$FWD/build-ok.txt
  SRC_DIR_M=$(win_mpath $SRC_DIR)
  if [ -n "$BUILD_DIR" ]; then BUILD_DIR_M=$(win_mpath $BUILD_DIR); fi
  PKG_PREFIX=$(echo ${PKG_NAME//-/_} | tr a-z A-Z)_PREFIX
  if [ -n "${!PKG_PREFIX}" ]; then
    PREFIX=$(win_mpath "${!PKG_PREFIX}")
  elif [ -z "$COMMON_PREFIX" ]; then
    if [ "$ARCH" == "x86" ]; then
      PREFIX="$FWD/x86"
    else
      PREFIX="$FWD/x64"
    fi
  else
    PREFIX=$COMMON_PREFIX
  fi
  PREFIX_M=$(win_mpath $PREFIX)
  PREFIX_W=$(win_wpath $PREFIX)
}

. $FWD/utils/colors.sh
. $FWD/utils/pathutils.sh
pre_config
