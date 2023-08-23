#! /usr/bin/env bash

build_${PY_LIB}_python() {

    set -euo pipefail;

    if [[ ! -d ~/${PY_SRC} ]]; then
        exit 1;
    fi

    local verbose="1";
    local parallel="";
    local wheel_dir="";

    eval "$(                                  \
        devcontainer-utils-parse-args --names '
            j|parallel                        |
            v|verbose                         |
            w|wheel-dir                       |
            prefer-binary                     |
            only-binary                       |
            no-verify                         |
            no-build-isolation                |
            no-deps                           |
            no-use-pep517                     |
        ' - <<< "$@"                          \
      | xargs -r -d'\n' -I% echo -n local %\; \
    )";

    verbose="${v:-${verbose:-}}";
    wheel_dir="${w:-${wheel_dir}}";
    parallel="${j:-${parallel:-${JOBS:-${PARALLEL_LEVEL:-$(nproc --ignore=2)}}}}";

    local cmake_args=();

    if test -n "${verbose}"; then
        cmake_args+=("--log-level=VERBOSE");
    fi

    # Define both lowercase and uppercase
    # `-DFIND_<lib>_CPP=ON` and `-DFIND_<LIB>_CPP=ON` because the RAPIDS
    # scikit-build CMakeLists.txt's aren't 100% consistent in the casing
    cmake_args+=(${CPP_DEPS});
    cmake_args+=(${CPP_ARGS});
    cmake_args+=(${__rest__[@]});

    local ninja_args=();
    if test -n "${verbose}"; then
        ninja_args+=("-v");
    fi
    if test -n "${parallel}"; then
        if [ "${parallel:-}" = "true" ]; then
            parallel="";
        fi
        ninja_args+=("-j${parallel}");
    fi

    local pip_args=();
    if test -n "${verbose}"; then
        pip_args+=("-vv");
    fi

    if test -n "${no_build_isolation:-}"; then
        pip_args+=("--no-build-isolation");
    fi

    if test -n "${no_deps:-}"; then
        pip_args+=("--no-deps");
    fi

    if test -n "${wheel_dir:-}"; then
        pip_args+=("-w" "${wheel_dir}");
    fi

    if test -n "${prefer_binary:-}"; then
        pip_args+=("--prefer-binary");
        if [ "${prefer_binary:-}" != "true" ]; then
            pip_args+=("${prefer_binary:-}");
        fi
    fi

    if test -n "${only_binary:-}"; then
        pip_args+=("--only-binary");
        if [ "${only_binary:-}" != "true" ]; then
            pip_args+=("${only_binary:-}");
        fi
    fi

    if test -n "${no_verify:-}"; then
        pip_args+=("--no-verify");
    fi

    if test -n "${no_use_pep517:-}"; then
        pip_args+=("--no-use-pep517");
    fi


    pip_args+=(~/"${PY_SRC}");

    trap "rm -rf ~/'${PY_SRC}/${PY_LIB//-/_}.egg-info'" EXIT;

    time                                              \
    CMAKE_GENERATOR="Ninja"                           \
    SKBUILD_BUILD_OPTIONS="${ninja_args[@]}"          \
    CMAKE_ARGS="$(rapids-parse-cmake-args ${cmake_args[@]})" \
        python -m pip wheel ${pip_args[@]}            \
    ;
}

if test -n "${rapids_build_utils_debug:-}"; then
    PS4="+ ${BASH_SOURCE[0]}:\${LINENO} "; set -x;
fi

(build_${PY_LIB}_python "$@");
