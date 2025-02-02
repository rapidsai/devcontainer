#!/usr/bin/env bash

# Usage:
#  rapids-make-conda-env [OPTION]...
#
# Make a combined conda environment for all repos.
#
# Boolean options:
#  -h,--help             Print this text.
#  -f,--force            Delete the existing conda env and recreate it from scratch.
#
# @_include_value_options rapids-make-conda-dependencies -h

# shellcheck disable=SC1091
. rapids-generate-docstring;

make_conda_env() {
    local -;
    set -euo pipefail;

    eval "$(_parse_args --take '-f,--force' "${@:2}" <&0)";

    # shellcheck disable=SC1091
    . devcontainer-utils-debug-output 'rapids_build_utils_debug' 'make-conda-env';

    local env_name="${1}"; shift;
    local env_file_name="${env_name}.yml";

    # Remove the current conda env if called with `-f,--force`
    if test -n "${f-}"; then
        rm -rf "${HOME}/.conda/envs/${env_name}" \
               "${HOME}/.conda/envs/${env_file_name}";
    fi

    local -r new_env_path="$(realpath -m "/tmp/${env_file_name}")";
    local -r old_env_path="$(realpath -m "${HOME}/.conda/envs/${env_file_name}")";

    rapids-make-conda-dependencies "${OPTS[@]}" > "${new_env_path}";

    if test -f "${new_env_path}" && test "$(wc -l "${new_env_path}" | cut -d' ' -f1)" -gt 0; then

        # If the conda env doesn't exist, make one
        if ! conda info -e | grep -qE "^${env_name} "; then
            echo -e "Creating '${env_name}' conda environment\n" 1>&2;
            echo -e "Environment (${env_file_name}):\n" 1>&2;
            cat "${new_env_path}";
            echo "";

            conda env create -n "${env_name}" -f "${new_env_path}" --solver=libmamba;
        # If the conda env does exist but it's different from the generated one,
        # print the diff between the envs and update it
        elif ! diff -BNqw "${old_env_path}" "${new_env_path}" >/dev/null 2>&1; then
            echo -e "Creating '${env_name}' conda environment\n" 1>&2;
            echo -e "Environment (${env_file_name}):\n" 1>&2;

            # Print the diff to the console for debugging
            [ ! -f "${old_env_path}" ]                         \
             && cat "${new_env_path}"                          \
             || diff -BNyw "${old_env_path}" "${new_env_path}" \
             || true                                           \
             && echo "";

            # If the conda env exists, recreate it from scratch.
            # Most conda issues are due to updating existing envs with new packages.
            # We mount in the package cache, so this should still be fast in most cases.
            rm -rf "${HOME}/.conda/envs/${env_name}";

            conda env create -n "${env_name}" -f "${new_env_path}" --solver=libmamba;
        fi

        cp -a "${new_env_path}" "${old_env_path}";
    else
        rm -f "${new_env_path}" "${old_env_path}";
        echo -e "Not creating '${env_name}' conda environment because '${env_file_name}' is empty." 1>&2;
    fi
}

# shellcheck disable=SC1091
. /opt/conda/etc/profile.d/conda.sh;
# shellcheck disable=SC1091
. /opt/conda/etc/profile.d/mamba.sh;

make_conda_env "${DEFAULT_CONDA_ENV:-rapids}" "$@" <&0;

# shellcheck disable=SC1090
. /etc/profile.d/*-miniforge.sh;
