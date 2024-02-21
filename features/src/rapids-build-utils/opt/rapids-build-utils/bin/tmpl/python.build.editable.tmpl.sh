#!/usr/bin/env bash

# Usage:
#  build-${PY_LIB}-python-editable [OPTION]...
#
# Build ${PY_LIB} in editable mode.
#
# @_include_value_options rapids-get-num-archs-jobs-and-load -h;
# @_include_cmake_options;
# @_include_pip_install_options;
# @_include_pip_package_index_options;
# @_include_pip_general_options;

# shellcheck disable=SC1091
. rapids-generate-docstring;

build_${PY_LIB}_python_editable() {
    local -;
    set -euo pipefail;

    eval "$(_parse_args "$@" <&0)";

    local py_lib="${PY_LIB}";
    local py_src="${PY_SRC}";

    if [[ ! -d "${py_src}" ]]; then
        exit 1;
    fi

    eval "$(                                    \
    PARALLEL_LEVEL=${PARALLEL_LEVEL:-$(nproc)}  \
        rapids-get-num-archs-jobs-and-load "$@" \
    )";

    # shellcheck disable=SC1091
    . devcontainer-utils-debug-output 'rapids_build_utils_debug' 'build-all build-${NAME} build-${PY_LIB}-python build-${PY_LIB}-python-editable';

    local -a cmake_args_=(
        ${PY_CMAKE_ARGS}
        ${CMAKE_ARGS:-}
        ${CPP_DEPS}
        ${CPP_ARGS}
        ${v:+--log-level=VERBOSE}
    );

    local -a cmake_args="(
        ${cmake_args_+"${cmake_args_[*]@Q}"}
        $(rapids-select-cmake-args "${ARGS[@]}")
    )";

    if test -n "${v}"; then
        ninja_args+=("-v");
    fi

    if test -n "${n_jobs}"; then
        ninja_args+=("-j${n_jobs}");
    fi

    if test -n "${n_load}"; then
        ninja_args+=("-l${n_load}");
    fi

    local -a pip_args_=(${PIP_INSTALL_ARGS});
    local -a pip_args="(
        ${pip_args_+"${pip_args_[*]@Q}"}
        $(rapids-select-pip-wheel-args "${ARGS[@]}")
    )";

    if rapids-python-uses-scikit-build-core "${py_src}"; then
        pip_args+=(-C "build-dir=$(rapids-get-cmake-build-dir -- "${py_src}" "${cmake_args[@]}")");
    else
        export SETUPTOOLS_ENABLE_FEATURES=legacy-editable;
    fi

    pip_args+=("--no-build-isolation");
    pip_args+=("--no-deps");
    pip_args+=("--editable");
    pip_args+=("${py_src}");

    cmake_args+=("-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON");

    trap "rm -rf '${py_src}/${py_lib//"-"/"_"}.egg-info'" EXIT;

    time (
        export ${PY_ENV} PATH="$PATH";

        local cudaflags="${CUDAFLAGS:+$CUDAFLAGS }-t=${n_arch}";
        local nvcc_append_flags="${NVCC_APPEND_FLAGS:+$NVCC_APPEND_FLAGS }-t=${n_arch}";

        CUDAFLAGS="${cudaflags}"                     \
        CMAKE_GENERATOR="Ninja"                      \
        PARALLEL_LEVEL="${n_jobs}"                   \
        CMAKE_ARGS="${cmake_args[*]}"                \
        SKBUILD_BUILD_OPTIONS="${ninja_args[*]}"     \
        NVCC_APPEND_FLAGS="${nvcc_append_flags}"     \
            python -m pip install "${pip_args[@]}"   \
        ;
        { set +x; } 2>/dev/null; echo -n "${py_lib} install time:";
    ) 2>&1;
}

build_${PY_LIB}_python_editable "$@" <&0;
