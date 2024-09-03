#!/bin/bash

export LC_ALL=C
set -o pipefail

# NOTE: Avoid to be sourced multiple times
[ "$sourced_compiler_sh" != "" ] && return || sourced_compiler_sh=.
export sourced_compiler_sh

. utils/pathutils.sh
# Load Visual C++ toolchain environments
. utils/config-msvc.sh 
# The CUDA and CUDNN environments will be load if $CUDA_PATH was defined
# at windows's environment
. utils/config-cuda.sh
