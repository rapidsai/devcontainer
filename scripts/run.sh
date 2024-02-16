#! /usr/bin/env bash

run_devcontainer() {

    set -Eeuo pipefail;

    # PS4="+ ${BASH_SOURCE[0]}:\${LINENO} "; set -x;

    # cd to the repo root
    cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/..";

    # Generate the devcontainer
    eval "$(./scripts/generate.sh "$@" | xargs -r -d'\n' -I% echo -n local %\;)";

    echo "tag=${tag-}" >&2;
    echo "workspace=${workspace-}" >&2;

    if ! test -n "${workspace-}" || ! test -n "${tag-}"; then exit 1; fi;

    # Print the generated devcontainer JSON
    cat "${workspace}/.devcontainer/devcontainer.json" >&2;

    # Build and tag the devcontainer

    # shellcheck disable=SC2317
    cleanup_1() {
        code=$?;
        set -x;
        find ./features/src -maxdepth 1 -type d -name '*\.[0-9]' -exec rm -r "{}" \;
        rm -rf "${1}";
        exit "${code}";
    }

    # shellcheck disable=SC2064
    trap "cleanup_1 '${workspace}'" EXIT;

    devcontainer build \
        --workspace-folder "${workspace}" \
        --cache-from "docker.io/rapidsai/devcontainers:${tag}" \
        --image-name "docker.io/rapidsai/devcontainers:${tag}" \
        ;

    mkdir -p -m 0755 .scratch/.{aws,cache,config};

    local term="${TERM:-}";
    local lines="$(tput lines)";
    local columns="$(tput cols)";
    local sccache_region="us-east-2";
    local ssh_auth_sock="/tmp/ssh-auth-sock";
    local sccache_bucket="rapids-sccache-devs";
    local histfile="/home/coder/.cache/._bash_history";
    local vault_host="https://vault.ops.k8s.rapids.ai";

    local vars=();
    vars+=("TERM=${term}");
    vars+=("LINES=${lines}");
    vars+=("COLUMNS=${columns}");
    vars+=("HISTFILE=${histfile}");
    vars+=("VAULT_HOST=${vault_host}");
    vars+=("SSH_AUTH_SOCK=${ssh_auth_sock}");
    vars+=("SCCACHE_BUCKET=${sccache_bucket}");
    vars+=("SCCACHE_REGION=${sccache_region}");

    local -r remote_envs="$(echo "${vars[@]}" | xargs -r -d' ' -I% echo -n '--remote-env % ')";

    # Start the devcontainer
    devcontainer up \
        ${remote_envs} \
        --skip-post-attach \
        --remove-existing-container \
        --terminal-rows "${lines}" \
        --terminal-columns "${columns}" \
        --mount-workspace-git-root false \
        --workspace-folder "${workspace}" \
        --cache-from "docker.io/rapidsai/devcontainers:${tag}" \
        --mount "type=bind,source=${SSH_AUTH_SOCK},target=/tmp/ssh-auth-sock" \
        --mount "type=bind,source=$(pwd)/.scratch/.aws,target=/home/coder/.aws" \
        --mount "type=bind,source=$(pwd)/.scratch/.cache,target=/home/coder/.cache" \
        --mount "type=bind,source=$(pwd)/.scratch/.config,target=/home/coder/.config" \
        --mount "type=bind,source=$(pwd)/features/src/utils/opt/devcontainer,target=/opt/devcontainer" \
        --additional-features '{ "./features/src/rapids-build-utils": {} }' \
        --mount "type=bind,source=$(pwd)/features/src/rapids-build-utils/opt/rapids-build-utils,target=/opt/rapids-build-utils" \
        ;

    local -r container_id="$(docker ps | grep -P "vsc-${workspace#"${TMPDIR:-/tmp}/"}-[0-9a-z]{64}-uid" | cut -d' ' -f1)";
    local -r image_tag="$(
        docker image inspect --format '{{index (split (index .RepoTags 0) ":") 0}}' "$(
            docker inspect "${container_id}" --format '{{index (split .Image ":") 1}}'
        )"
    )";

    # shellcheck disable=SC2317
    cleanup_2() {
        code=$?;
        set -x;
        find ./features/src -maxdepth 1 -type d -name '*\.[0-9]' -exec rm -r "{}" \;
        echo "Removing ${container_id}";
        docker rm -f "${container_id}" >/dev/null 2>&1 || true;
        docker rmi -f "${image_tag}" >/dev/null 2>&1 || true;
        docker rmi -f "${image_tag%%-uid*}" >/dev/null 2>&1 || true;
        rm -rf "${1}";
        exit "${code}";
    }

    # shellcheck disable=SC2064
    trap "cleanup_2 '${workspace}'" EXIT;

    local cmds="${@:4}";

    devcontainer exec \
        ${remote_envs} \
        --terminal-rows "${lines}" \
        --terminal-columns "${columns}" \
        --mount-workspace-git-root false \
        --workspace-folder "${workspace}" \
        ${cmds:-/bin/bash};
}

(run_devcontainer "$@");
