#!/bin/bash
#
# This file should be sourced by another bash script
#

download_extract()
{
  echo "Preparing $PKG_NAME $PKG_VER"
  cd "$TAGS_DIR"
  local archive=$1
  local strip_level=$2
  local inner_dir=$3
  [[ -z $strip_level ]] && strip_level=1
  if [[ ! -f "$archive" ]]; then
    echo "Downloading $archive, please wait ..."
    wget --no-check-certificate "$PKG_URL" -O "$archive"
    [[ $? -ne 0 ]] && exit 1
  fi
  if [ ! -d "$SRC_DIR" ]; then
    echo "Checking file integrity of $archive"
    if ! tar -tf "$archive" &> /dev/null; then
      echo "File $archive is corrupted, download it again, please wait"
      wget --no-check-certificate "$PKG_URL" -O "$archive"
      [[ $? -ne 0 ]] && exit 1
    fi
    echo "Strip level: $strip_level"
    if [[ -z $inner_dir ]]; then
      mkdir -p "$SRC_DIR" && cd "$RELS_DIR"
    else
      echo "Inner folder: $inner_dir"
      mkdir -p "$SRC_DIR" && cd "$SRC_DIR"
    fi
    echo "Extracting $archive into $SRC_DIR"
    case $archive in
      *.lz)
        if [[ -z $inner_dir ]]; then
          tar --strip-components=$strip_level --lzip -xvf "$TAGS_DIR/$archive" -C "$SRC_DIR" >/dev/null
        else
          tar --strip-components=$strip_level --lzip -xvf "$TAGS_DIR/$archive" "$inner_dir" >/dev/null
        fi
        [[ $? -ne 0 ]] && exit 1
        ;;
      *.*)
        if [[ -z $inner_dir ]]; then
          tar --strip-components=$strip_level -xvf "$TAGS_DIR/$archive" -C "$SRC_DIR" >/dev/null
        else
          tar --strip-components=$strip_level -xvf "$TAGS_DIR/$archive" "$inner_dir" >/dev/null
        fi
        [[ $? -ne 0 ]] && exit 1
        ;;
    esac
    echo "Done"
    if [[ $(type -t patch_package) == function ]]; then
      patch_package
    fi
  fi
}


git_sync()
{
  local branch=$1
  cd "$RELS_DIR"
  if [ ! -d "$SRC_DIR" ]; then
    echo "Cloning $branch into $SRC_DIR"
    git clone --config core.autocrlf=false --single-branch -b "$branch" "$PKG_URL" "$PKG_NAME"
    [[ $? -ne 0 ]] && exit 1
  elif [ ! -d "$SRC_DIR/.git" ]; then
    rm -rf "$SRC_DIR"
    echo "Cloning $branch into $SRC_DIR"
    git clone --config core.autocrlf=false --single-branch -b "$branch" "$PKG_URL" "$PKG_NAME"
    [[ $? -ne 0 ]] && exit 1
  else
    echo "Updating repository $PKG_NAME"
    pushd "$SRC_DIR"
    # TODO:
    # 1. Sometimes the network is not really good and git sync will often fail.
    #    This may cause build procedure will break here during synchronization.
    #    Temporary remove 'exit 1' here
    git fetch origin "$branch"
    git reset --hard "origin/$branch"
    popd
  fi
  if [[ $(type -t patch_package) == function ]]; then
    patch_package
  fi
}


git_rescure()
{
  local branch=$1
  cd "$RELS_DIR"
  if [ ! -d "$SRC_DIR" ]; then
    echo "Cloning branch $branch into $RELS_DIR"
    git clone --recurse-submodules --shallow-submodules -b "$branch" "$PKG_URL" "$PKG_NAME"
    [[ $? -ne 0 ]] && exit 1
  elif [ ! -d "$SRC_DIR/.git" ]; then
    rm -rf "$SRC_DIR"
    echo "Cloning branch $branch into $RELS_DIR"
    git clone --recurse-submodules --shallow-submodules -b "$branch" "$PKG_URL" "$PKG_NAME"
    [[ $? -ne 0 ]] && exit 1
  else
    cd "$SRC_DIR"
    local branch_ver
    branch_ver=$(git name-rev --name-only HEAD | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')
    if [ "$PKG_VER" == "$branch_ver" ]; then
      echo "Branch version is $branch_ver"
      for m in $(git status | grep -oP '(?<=modified:\s{3}).*(?=\s{1}\(.*\))'); do
        rm -rfv "$m"
      done
      echo "Updating $branch_ver of repository $PKG_NAME"
      # TODO:
      # 1. Sometimes the network is not really good and git sync will often fail.
      #    This may cause build procedure will break here during synchronization.
      #    Temporary remove 'exit 1' here
      git submodule update --init --recursive
    else
      cd "$RELS_DIR"
      echo "Deleting the old branch version $branch_ver of respository $PKG_NAME"
      rm -rf "$SRC_DIR"
      echo "Cloning the new branch version $PKG_VER of respository $PKG_NAME"
      git clone --recurse-submodules --shallow-submodules -b "$branch" "$PKG_URL" "$PKG_NAME"
      [[ $? -ne 0 ]] && exit 1
    fi
  fi
  if [[ $(type -t patch_package) == function ]]; then
    patch_package
  fi
}
