#!/usr/bin/env bash

# Usage:
#  build-${NAME} [OPTION]...
#
# Configure and build ${CPP_LIB}, then build an editable install or wheel of ${PY_LIB}.
#
# Boolean options:
#  -h,--help                              print this text
#  -v,--verbose                           verbose output
#
# Options that require values:
#  -t,--type (editable|wheel)             The type of Python build to run (editable or wheel)
#                                         (default: editable)
#  -a,--archs <num>                       Build <num> CUDA archs in parallel
#                                         (default: 1)
#  -j,--parallel <num>                    Run <num> parallel compilation jobs
#                                         (default: $(nproc))
#  -m,--max-device-obj-memory-usage <num> An upper-bound on the amount of memory each CUDA device object compilation
#                                         is expected to take. This is used to estimate the number of parallel device
#                                         object compilations that can be launched without hitting the system memory
#                                         limit.
#                                         Higher values yield fewer parallel CUDA device object compilations.
#                                         (default: 1)
#  -D* <var>[:<type>]=<value>             Create or update a cmake cache entry.

build_${NAME}() {
    local -;
    set -euo pipefail;


    eval "$(devcontainer-utils-parse-args "$0" --take '
        -t,--type
    ' - <<< "${@@Q}")";
    # shellcheck disable=SC1091
    . devcontainer-utils-debug-output 'rapids_build_utils_debug' 'build-all build-${NAME}';

    for lib in ${CPP_LIB}; do
        if type build-${lib}-cpp >/dev/null 2>&1; then
            build-${lib}-cpp "${OPTS[@]}";
        fi
    done

    for lib in ${PY_LIB}; do
        if type build-${lib}-python >/dev/null 2>&1; then
            build-${lib}-python-${t:-${type:-"editable"}} "${OPTS[@]}";
        fi
    done
}

build_${NAME} "$@";
