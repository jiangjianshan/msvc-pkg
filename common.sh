#!/bin/bash

extract() {
  local dest_dir=$1
  local archive=$2
  local strip_level=$3
  local inner_dir=$4
  [[ -z $strip_level ]] && strip_level=1
  echo "Extracting $archive into $dest_dir"
  case "$archive" in
    *.lz | *.tar.bz2 | *.tar.gz | *.tar.xz | *.tgz)
      if [[ -z $inner_dir ]]; then
        mkdir -p "$dest_dir" && cd "$RELS_DIR" || exit 1
        tar --strip-components=$strip_level -xvf "$TAGS_DIR/$archive" -C "$dest_dir" >/dev/null
      else
        mkdir -p "$dest_dir" && cd "$dest_dir" || exit 1
        tar --strip-components=$strip_level -xvf "$TAGS_DIR/$archive" "$inner_dir" >/dev/null
      fi
      ;;
    *.zip)
      unzip -q -o "$TAGS_DIR/$archive" -d "$dest_dir" >/dev/null
      ;;
    *)
      echo "$TAGS_DIR/$archive cannot be extracted via extract()"
      exit 1
      ;;
  esac
  echo "Done"
}

verify_file() {
  local pkg_url=$1
  local archive=$2
  local correct_sha256=$3
  local calc_sha256
  echo "Checking file integrity of $1"
  calc_sha256=$(sha256sum "$TAGS_DIR/$archive" | cut -d ' ' -f1)
  if [ -n "$correct_sha256" ]; then
    if [[ ! "$correct_sha256" = "$calc_sha256" ]]; then
      echo "File $archive is corrupted, download it again, please wait"
      if ! wget --no-check-certificate "$pkg_url" -O "$TAGS_DIR/$archive"; then
        echo "Failed to download $archive from $pkg_url"
        exit 1
      fi
    fi
  fi
}

wget_sync()
{
  local pkg_url=$1
  local dest_dir=$2
  local archive=$3
  local strip_level=$4
  local inner_dir=$5
  if [[ ! -f "$TAGS_DIR/$archive" ]]; then
    echo "Downloading $archive, please wait ..."
    if ! wget --no-check-certificate "$pkg_url" -O "$TAGS_DIR/$archive"; then
      echo "Failed to download $archive from $pkg_url"
      exit 1
    fi
  fi
  if [[ ! -d "$dest_dir" ]]; then
    local correct_sha256=$(yq -r '.sha256' config.yaml)
    if verify_file $pkg_url "$archive" $correct_sha256; then
      if ! extract "$dest_dir" "$archive" "$strip_level" "$inner_dir"; then
        echo "Failed to extract $archive into $dest_dir"
        exit 1
      elif [[ $(type -t patch_package) == function ]]; then
        patch_package
      fi
    fi
  fi
}

git_sync()
{
  local pkg_url=$1
  local dest_dir=$2
  local repo_name=$3
  local branch=$4
  if [ ! -d "$dest_dir" ]; then
    echo "Cloning $branch into $dest_dir"
    if ! git clone --config core.autocrlf=false --single-branch -b "$branch" "$pkg_url" "$(cygpath -m "$dest_dir")"; then
      echo "Failed to clone $repo_name into $dest_dir"
      exit 1
    fi
  elif [ ! -d "$dest_dir/.git" ]; then
    rm -rf "$dest_dir"
    echo "Cloning $branch into $dest_dir"
    if ! git clone --config core.autocrlf=false --single-branch -b "$branch" "$pkg_url" "$(cygpath -m "$dest_dir")"; then
      echo "Failed to clone $repo_name into $dest_dir"
      exit 1
    fi
  else
    echo "Updating repository $repo_name"
    pushd "$dest_dir" || exit 1
    # TODO: Sometimes the network is not really good and git sync will often fail.
    #       This may cause build procedure will break here during synchronization.
    #       Temporary remove 'exit 1' here
    git fetch origin "$branch"
    git reset --hard "origin/$branch"
    popd || exit 1
  fi
}

git_rescure()
{
  local pkg_url=$1
  local dest_dir=$2
  local repo_name=$3
  local branch=$4
  if [ ! -d "$dest_dir" ]; then
    echo "Cloning branch $branch into $dest_dir"
    if ! git clone --recurse-submodules --shallow-submodules -b "$branch" "$pkg_url" "$(cygpath -m "$dest_dir")"; then
      echo "Failed to clone $repo_name into $dest_dir"
      exit 1
    fi
  elif [ ! -d "$dest_dir/.git" ]; then
    rm -rf "$dest_dir"
    echo "Cloning branch $branch into $dest_dir"
    if ! git clone --recurse-submodules --shallow-submodules -b "$branch" "$pkg_url" "$(cygpath -m "$dest_dir")"; then
      echo "Failed to clone $repo_name into $dest_dir"
      exit 1
    fi
  else
    cd "$dest_dir" || exit 1
    if [[ "$branch" == "master" ]] || [[ $branch == "main" ]]; then
      echo "Updating $branch_ver of repository $repo_name"
      git submodule update --init --recursive
    else
      local branch_ver
      branch_ver=$(git name-rev --name-only HEAD)
      if [ "$branch" == "$branch_ver" ]; then
        echo "Branch version is $branch_ver"
        for m in $(git status | grep -oP '(?<=modified:\s{3}).*(?=\s{1}\(.*\))'); do
          rm -rfv "$m"
        done
        echo "Updating $branch_ver of repository $repo_name"
        # TODO: Sometimes the network is not really good and git sync will often fail.
        #       This may cause build procedure will break here during synchronization.
        #       Temporary remove 'exit 1' here
        git submodule update --init --recursive
      else
        echo "Deleting the old branch version $branch_ver of respository $repo_name"
        rm -rf "$dest_dir"
        echo "Cloning the new branch version $branch of respository $repo_name"
        if ! git clone --recurse-submodules --shallow-submodules -b "$branch" "$pkg_url" "$(cygpath -m "$dest_dir")";  then
          echo "Failed to clone $repo_name into $dest_dir"
          exit 1
        fi
      fi
    fi
  fi
}
