#!/usr/bin/env bash

# Usage:
#  clone-all [OPTION]...
#
# Runs clone-<repo> for each repo in "${NAMES}".
#
# Boolean options:
#  -h,--help                    print this text
#  -v,--verbose                 verbose output
#  --no-fork                    don't prompt the user to fork the repo if a user fork isn't found
#                               (default: false)
#  --no-update-env              don't update the Python env with the repo's dependencies after cloning
#                               (default: false)
#  --clone-upstream             always clone the upstream, not the user's fork
#                               (default: false)
#
# Options that require values:
#  -j,--parallel <num>          Clone <num> repos in parallel
#                               (default: 1)

clone_all() {
    local -;
    set -euo pipefail;

    eval "$(devcontainer-utils-parse-args "$0" --skip '
        --no-fork
        --clone-upstream
    ' - <<< "${@@Q}")";

    eval "$(rapids-get-num-archs-jobs-and-load -a3 "$@")";

    # shellcheck disable=SC1091
    . devcontainer-utils-debug-output 'rapids_build_utils_debug' 'clone-all';

    echo ${NAMES} \
  | tr '[:space:]' '\0' \
  | xargs ${v:+-t} -r -0 -P${n_jobs} -I% bash -c "
    if type clone-% >/dev/null 2>&1; then
        clone-% -j ${n_arch} --no-update-env ${OPTS[*]} || exit 255;
    fi
    ";

    if test -z "${no_update_env-}"; then
        rapids-update-content-command;
        rapids-post-attach-command;
    fi
}

clone_all "$@";
