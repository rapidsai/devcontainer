#!/usr/bin/env bash

# shellcheck disable=SC2016

ALT_SCRIPT_DIR="${ALT_SCRIPT_DIR:-/usr/bin}";
TEMPLATES="${TEMPLATES:-/opt/rapids-build-utils/bin/tmpl}";
TMP_SCRIPT_DIR="${TMP_SCRIPT_DIR:-/tmp/rapids-build-utils}";
COMPLETION_TMPL="${COMPLETION_TMPL:-"$(which devcontainer-utils-bash-completion.tmpl)"}";
COMPLETION_FILE="${COMPLETION_FILE:-${HOME}/.bash_completion.d/rapids-build-utils-completions}";

generate_completions() {
    local -;
    set -euo pipefail;

    if type devcontainer-utils-debug-output >/dev/null 2>&1; then
        # shellcheck disable=SC1091
        . devcontainer-utils-debug-output 'rapids_build_utils_debug' 'generate-scripts';

        readarray -t commands < <(find "${TMP_SCRIPT_DIR}"/ -maxdepth 1 -type f -exec basename {} \;);

        devcontainer-utils-generate-bash-completion          \
            --out-file "$(realpath -m "${COMPLETION_FILE}")" \
            --template "$(realpath -m "${COMPLETION_TMPL}")" \
            ${commands[@]/#/--command }                      \
        ;
    fi
}

clean_scripts_and_aliases() {
    local -;
    set -euo pipefail;

    if type devcontainer-utils-debug-output >/dev/null 2>&1; then
        # shellcheck disable=SC1091
        . devcontainer-utils-debug-output 'rapids_build_utils_debug' 'generate-scripts';
    fi

    readarray -t commands < <(find "${TMP_SCRIPT_DIR}"/ -maxdepth 1 -type f -exec basename {} \;);
    sudo rm -f -- \
        "${commands[@]/#/${ALT_SCRIPT_DIR}\/}" \
        "${commands[@]/#/${TMP_SCRIPT_DIR}\/}" ;
}

generate_script() {
    local bin="${1:-}";
    if test -n "${bin}"; then
        (
            cat - \
          | envsubst '$HOME $NAME $SRC_PATH $PY_ENV $PY_SRC $PY_LIB $BIN_DIR $CPP_LIB $CPP_SRC $CPP_ARGS $CPP_DEPS $GIT_TAG $GIT_REPO $GIT_HOST $GIT_UPSTREAM $PY_CMAKE_ARGS $PIP_WHEEL_ARGS $PIP_INSTALL_ARGS' \
          | tee "${TMP_SCRIPT_DIR}/${bin}" >/dev/null;

            chmod +x "${TMP_SCRIPT_DIR}/${bin}";

            sudo ln -sf "${TMP_SCRIPT_DIR}/${bin}" "${ALT_SCRIPT_DIR}/${bin}";

            if [[ "${bin}" != "${bin,,}" ]]; then
                sudo ln -sf "${TMP_SCRIPT_DIR}/${bin,,}" "${ALT_SCRIPT_DIR}/${bin,,}";
            fi
        ) & true;

        echo "$!"
    fi
}

generate_all_script_impl() {
    local bin="${SCRIPT}-all";
    if test -n "${bin}" && ! test -f "${TMP_SCRIPT_DIR}/${bin}"; then
        (
            cat - \
          | envsubst '$NAME $NAMES $SCRIPT' \
          | tee "${TMP_SCRIPT_DIR}/${bin}" >/dev/null;

            chmod +x "${TMP_SCRIPT_DIR}/${bin}";

            sudo ln -sf "${TMP_SCRIPT_DIR}/${bin}" "${ALT_SCRIPT_DIR}/${bin}";
        ) & true;

        echo "$!"
    fi
}

generate_all_script() {
    if test -f "${TEMPLATES}/all.${SCRIPT}.tmpl.sh"; then (
        # shellcheck disable=SC2002
        cat "${TEMPLATES}/all.${SCRIPT}.tmpl.sh" \
      | generate_all_script_impl       ;
    ) || true;
    elif test -f "${TEMPLATES}/all.tmpl.sh"; then (
        # shellcheck disable=SC2002
        cat "${TEMPLATES}/all.tmpl.sh" \
      | generate_all_script_impl       ;
    ) || true;
    fi
}

generate_clone_script() {
    if test -f "${TEMPLATES}/repo.clone.tmpl.sh"; then (
        # shellcheck disable=SC2002
        cat "${TEMPLATES}/repo.clone.tmpl.sh" \
      | generate_script "clone-${NAME}"  ;
    ) || true;
    fi
}

generate_repo_scripts() {
    local script_name;
    for script_name in "configure" "build" "cpack" "clean" "install" "uninstall"; do
        if test -f "${TEMPLATES}/repo.${script_name}.tmpl.sh"; then (
            # shellcheck disable=SC2002
            cat "${TEMPLATES}/repo.${script_name}.tmpl.sh" \
          | generate_script "${script_name}-${NAME}"  ;
        ) || true;
        fi
    done
}

generate_cpp_scripts() {
    local script_name;
    for script_name in "clean" "configure" "build" "cpack" "install" "uninstall"; do
        if test -f "${TEMPLATES}/cpp.${script_name}.tmpl.sh"; then (
            # shellcheck disable=SC2002
            cat "${TEMPLATES}/cpp.${script_name}.tmpl.sh"  \
          | CPP_SRC="${SRC_PATH:-}${CPP_SRC:+/$CPP_SRC}"   \
            generate_script "${script_name}-${CPP_LIB-}-cpp";
        ) || true;
        fi
    done
}

generate_python_scripts() {
    local script_name;
    for script_name in "build" "clean" "uninstall"; do
        if test -f "${TEMPLATES}/python.${script_name}.tmpl.sh"; then (
            # shellcheck disable=SC2002
            cat "${TEMPLATES}/python.${script_name}.tmpl.sh" \
          | generate_script "${script_name}-${PY_LIB}-python";
        ) || true;
        fi
    done
    for script_name in "editable" "wheel"; do
        if test -f "${TEMPLATES}/python.build.${script_name}.tmpl.sh"; then (
            # shellcheck disable=SC2002
            cat "${TEMPLATES}/python.build.${script_name}.tmpl.sh" \
          | generate_script "build-${PY_LIB}-python-${script_name}";
        ) || true;
        fi
    done
}

generate_scripts() {
    local -;
    set -euo pipefail;

    # Generate and install the "clone-<repo>" scripts

    # Ensure we're in this script's directory
    cd "$( cd "$( dirname "$(realpath -m "${BASH_SOURCE[0]}")" )" && pwd )";

    eval "$(rapids-list-repos "$@")";

    if type devcontainer-utils-debug-output >/dev/null 2>&1; then
        # shellcheck disable=SC1091
        . devcontainer-utils-debug-output 'rapids_build_utils_debug' 'generate-scripts';
    fi

    local -A cpp_name_to_path;

    local i;
    local j;
    local k;

    local repo_names=();
    local -r bin_dir="$(dirname "$(rapids-get-cmake-build-dir)")/latest";

    for ((i=0; i < ${repos_length:-0}; i+=1)); do

        local repo="repos_${i}";
        local repo_name="${repo}_name";
        local repo_path="${repo}_path";
        local cpp_length="${repo}_cpp_length";
        local py_length="${repo}_python_length";
        local git_repo="${repo}_git_repo";
        local git_host="${repo}_git_host";
        local git_tag="${repo}_git_tag";
        local git_upstream="${repo}_git_upstream";

        repo_name="${!repo_name,,}";
        repo_names+=("${repo_name}");

        local deps=();
        local cpp_libs=();
        local cpp_dirs=();

        local py_libs=()
        local py_dirs=()

        for ((j=0; j < ${!cpp_length:-0}; j+=1)); do

            local cpp_name="${repo}_cpp_${j}_name";
            local cpp_args="${repo}_cpp_${j}_args";
            local cpp_sub_dir="${repo}_cpp_${j}_sub_dir";
            local cpp_depends_length="${repo}_cpp_${j}_depends_length";
            local cpp_path=~/"${!repo_path:-}${!cpp_sub_dir:+/${!cpp_sub_dir}}";

            cpp_dirs+=("${cpp_path}");
            cpp_libs+=("${!cpp_name:-}");
            cpp_name="${!cpp_name:-}";

            cpp_name_to_path["${cpp_name}"]="${cpp_path}";

            local cpp_deps=();

            for ((k=0; k < ${!cpp_depends_length:-0}; k+=1)); do
                local dep="${repo}_cpp_${j}_depends_${k}";
                local dep_cpp_name="${!dep}";
                if ! test -v cpp_name_to_path["${dep_cpp_name}"]; then
                    continue;
                fi
                local dep_cpp_path="${cpp_name_to_path["${dep_cpp_name}"]}";

                cpp_deps+=("-D${!dep}_ROOT=\"${dep_cpp_path}/${bin_dir}\"");
                cpp_deps+=("-D${!dep,,}_ROOT=\"${dep_cpp_path}/${bin_dir}\"");
                cpp_deps+=("-D${!dep^^}_ROOT=\"${dep_cpp_path}/${bin_dir}\"");
                deps+=("${cpp_deps[@]}");
            done

            if [[ -d ~/"${!repo_path:-}/.git" ]]; then
                NAME="${repo_name:-}"        \
                SRC_PATH=~/"${!repo_path:-}" \
                BIN_DIR="${bin_dir}"         \
                CPP_LIB="${cpp_name:-}"      \
                CPP_SRC="${!cpp_sub_dir:-}"  \
                CPP_ARGS="${!cpp_args:-}"    \
                CPP_DEPS="${cpp_deps[*]}"    \
                generate_cpp_scripts         ;
            fi
        done

        local args=();

        for ((k=0; k < ${#cpp_libs[@]}; k+=1)); do
            # Define both lowercase and uppercase
            # `-DFIND_<lib>_CPP=ON` and `-DFIND_<LIB>_CPP=ON` because the RAPIDS
            # scikit-build CMakeLists.txt's aren't 100% consistent in the casing
            local cpp_dir="${cpp_dirs[$k]}";
            local cpp_lib="${cpp_libs[$k]}";
            args+=("-DFIND_${cpp_lib}_CPP=ON");
            args+=("-DFIND_${cpp_lib,,}_CPP=ON");
            args+=("-DFIND_${cpp_lib^^}_CPP=ON");
            deps+=("-D${cpp_lib}_ROOT=\"${cpp_dir}/${bin_dir}\"");
            deps+=("-D${cpp_lib,,}_ROOT=\"${cpp_dir}/${bin_dir}\"");
            deps+=("-D${cpp_lib^^}_ROOT=\"${cpp_dir}/${bin_dir}\"");
        done

        for ((j=0; j < ${!py_length:-0}; j+=1)); do
            local py_env="${repo}_python_${j}_env";
            local py_name="${repo}_python_${j}_name";
            local py_cmake_args="${repo}_python_${j}_args_cmake";
            local pip_wheel_args="${repo}_python_${j}_args_wheel";
            local pip_install_args="${repo}_python_${j}_args_install";
            local py_sub_dir="${repo}_python_${j}_sub_dir";
            # local py_depends_length="${repo}_python_${j}_depends_length";
            local py_path=~/"${!repo_path:-}${!py_sub_dir:+/${!py_sub_dir}}";

            py_dirs+=("${py_path}");
            py_libs+=("${!py_name}");

            if [[ -d ~/"${!repo_path:-}/.git" ]]; then
                NAME="${repo_name:-}"                     \
                BIN_DIR="${bin_dir}"                      \
                SRC_PATH=~/"${!repo_path:-}"              \
                PY_SRC="${py_path}"                       \
                PY_LIB="${!py_name}"                      \
                PY_ENV="${!py_env:-}"                     \
                CPP_ARGS="${args[*]}"                     \
                CPP_DEPS="${deps[*]}"                     \
                PY_CMAKE_ARGS="${!py_cmake_args:-}"       \
                PIP_WHEEL_ARGS="${!pip_wheel_args:-}"     \
                PIP_INSTALL_ARGS="${!pip_install_args:-}" \
                generate_python_scripts                   ;
            fi
        done;

        if [[ -d ~/"${!repo_path:-}/.git" ]]; then
            NAME="${repo_name:-}"      \
            PY_LIB="${py_libs[*]@Q}"   \
            CPP_LIB="${cpp_libs[*]@Q}" \
            generate_repo_scripts      ;
        fi

        # Generate a clone script for each repo
        NAME="${repo_name:-}"             \
        SRC_PATH=~/"${!repo_path:-}"      \
        PY_LIB="${py_libs[*]@Q}"          \
        PY_SRC="${py_dirs[*]@Q}"          \
        CPP_LIB="${cpp_libs[*]@Q}"        \
        CPP_SRC="${cpp_dirs[*]@Q}"        \
        GIT_TAG="${!git_tag:-}"           \
        GIT_REPO="${!git_repo:-}"         \
        GIT_HOST="${!git_host:-}"         \
        GIT_UPSTREAM="${!git_upstream:-}" \
        generate_clone_script             ;
    done

    unset cpp_name_to_path;

    if ((${#repo_names[@]} > 0)); then
        for script in "clone" "clean" "configure" "build" "cpack" "install" "uninstall"; do
            # Generate a script to run a script for all repos
            NAME="${repo_names[0]}"    \
            NAMES="${repo_names[*]@Q}" \
            SCRIPT="${script}"         \
            generate_all_script        ;
        done;
    fi
}

_generate() {
    local -;
    set -euo pipefail;

    echo "Generating RAPIDS build scripts in ${ALT_SCRIPT_DIR}";

    mkdir -p "${TMP_SCRIPT_DIR}";

    # Clean the cached parsed docstrings
    rm -rf /tmp/rapids-build-utils/.docstrings-cache/;
    # Bash completions
    rm -f "$(realpath -m "${COMPLETION_FILE}")";
    # Clean existing scripts and aliases
    clean_scripts_and_aliases;

    # Generate new scripts
    local pid;
    for pid in $(generate_scripts "$@"); do
        while test -e "/proc/${pid}"; do
            sleep 0.1;
        done
    done

    # Generate new bash completions
    generate_completions;
}

_generate "$@";
