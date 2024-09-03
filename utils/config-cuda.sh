#!/bin/bash
#
# Set INCLUDE and LIB of CUDA and CUDNN
#
if [ -n "$CUDA_PATH" ]; then
  # PATH is a special case, requiring special handling
  new_paths=
  new_paths=$(win_unixpaths "$CUDA_PATH/bin;$CUDA_PATH/extras/demo_suite")  # Convert to unix-style path list
  new_paths=$(normalize_paths "${new_paths}:${PATH}")                       # Prepend the current PATH
  PATH="$new_paths"
  if nvcc --version 2&> /dev/null; then
    # Determine CUDA version using default nvcc binary
    CUDA_VERSION=$(nvcc --version | sed -n 's/^.*release \([0-9]\+\.[0-9]\+\).*$/\1/p')
  else
    echo [$0] Can not find the exact version of CUDA
    exit 1
  fi
  CUDAINSTALLDIR=$CUDA_PATH
  INCLUDE="${CUDAINSTALLDIR}"'\include;'"$INCLUDE"
  LIB="${CUDAINSTALLDIR}"'\lib\'"$HOST_ARCH"';'"$LIB"
  CUDNN_VERSION_H=`find "$(unix_path "$CUDA_PATH")" -name "cudnn_version.h"`
  if [ -z "$CUDNN_VERSION_H" ]; then
    CUDNN_VERSION_H=`find "$(unix_path "C:\Program Files\NVIDIA\CUDNN")" -name "cudnn_version.h"`
  fi
  CUDNN_MAJOR=`cat "$CUDNN_VERSION_H" | grep "#define CUDNN_MAJOR" | fix_crlf | awk '{print $3}'`
  CUDNN_MINOR=`cat "$CUDNN_VERSION_H" | grep "#define CUDNN_MINOR" | fix_crlf | awk '{print $3}'`
  CUDNN_VERSION=${CUDNN_MAJOR}.${CUDNN_MINOR}
  CUDNNINSTALLDIR='C:\Program Files\NVIDIA\CUDNN\v'"$CUDNN_VERSION"
  INCLUDE="${CUDNNINSTALLDIR}"'\include\'"$CUDA_VERSION"';'"$INCLUDE"
  LIB="${CUDNNINSTALLDIR}"'\lib\'"$CUDA_VERSION"'\'"$HOST_ARCH"';'"$LIB"
  NV_COMPUTE=$(deviceQuery | awk '/CUDA Capability Major/{print $(NF)}')
  echo "[$0] Setting CUDA and CUDNN Toochain environment"
  echo "CUDA version                                           : $CUDA_VERSION"
  echo "CUDNN Version                                          : $CUDNN_VERSION"
  echo "CUDA Capability Major                                  : $NV_COMPUTE"
fi

export PATH INCLUDE LIB CUDA_VERSION CUDNN_VERSION NV_COMPUTE
