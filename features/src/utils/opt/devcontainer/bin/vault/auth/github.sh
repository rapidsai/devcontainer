#! /usr/bin/env bash


get_vault_token() {
    local -;
    set -Eeuo pipefail;

    # shellcheck disable=SC2154
    if test -n "${devcontainer_utils_debug:-}" \
    && { test -z "${devcontainer_utils_debug##*"*"*}" \
      || test -z "${rapids_build_utils_debug##*"vault-auth-github"*}"; }; then
        PS4="+ ${BASH_SOURCE[0]}:\${LINENO} "; set -x;
    fi

    local -r VAULT_HOST="$1";
    local -r user_orgs=("${@:2}");
    local -r gh_token="$(gh auth token)";
    local vault_token=null;
    local o;
    local org;

    for o in "${user_orgs[@]}"; do
        for org in $(echo -e "${o}\n${o,,}\n${o^^}" | sort -su); do
            vault_token="$(                                     \
                curl -s                                         \
                    -X POST                                     \
                    -H "Content-Type: application/json"         \
                    -d "{\"token\": \"${gh_token}\"}"           \
                    "${VAULT_HOST}/v1/auth/github-${org}/login" \
              | jq -r '.auth.client_token'                      \
            )";
            if test "${vault_token:-null}" != null; then
                break;
            fi
        done
        if test "${vault_token:-null}" != null; then
            break;
        fi
    done

    echo "vault_token='$vault_token'";
}

get_vault_token "$@";
