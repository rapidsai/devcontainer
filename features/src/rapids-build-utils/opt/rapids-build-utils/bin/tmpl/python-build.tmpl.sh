#! /usr/bin/env bash

build_${PY_LIB}_python() {

    local mode="editable";

    # pull out the --mode editable|wheel arg (if any)
    eval "$(                                  \
        devcontainer-utils-parse-args --names '
            m|mode                            |
        ' - <<< "$@"                          \
      | xargs -r -d'\n' -I% echo -n local %\; \
    )";

    mode="${m:-${mode:-"editable"}}";

    build-${PY_LIB}-python-${mode} ${__rest__[@]};
}

if test -n "${rapids_build_utils_debug:-}"; then
    PS4="+ ${BASH_SOURCE[0]}:\${LINENO} "; set -x;
fi

build_${PY_LIB}_python "$@";
