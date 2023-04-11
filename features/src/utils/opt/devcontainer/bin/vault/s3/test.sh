#! /usr/bin/env bash

# Test AWS S3 credentials are still valid the same way sccache does

test_aws_creds() {

    set -euo pipefail;

    if [[ ! -f ~/.aws/stamp ]]; then exit 1; fi;
    if [[ ! -f ~/.aws/config ]]; then exit 1; fi;
    if [[ ! -f ~/.aws/credentials ]]; then exit 1; fi;

    local bucket="$(grep 'bucket=' ~/.aws/config | sed 's/bucket=//')";
    if [[ -z "${bucket:-}" ]]; then exit 1; fi;

    local region="$(grep 'region=' ~/.aws/config | sed 's/region=//')";

    local aws_access_key_id="$(grep 'aws_access_key_id=' ~/.aws/credentials | sed 's/aws_access_key_id=//')";
    if [[ -z "${aws_access_key_id:-}" ]]; then exit 1; fi;

    local aws_secret_access_key="$(grep 'aws_secret_access_key=' ~/.aws/credentials | sed 's/aws_secret_access_key=//')";
    if [[ -z "${aws_access_key_id:-}" ]]; then exit 1; fi;

    local aws_session_token="$(grep 'aws_session_token=' ~/.aws/credentials | sed 's/aws_session_token=//')";

    local code=;

    # Test GET
    code=$(                                                     \
        AWS_SESSION_TOKEN="$aws_session_token"                  \
        AWS_ACCESS_KEY_ID="$aws_access_key_id"                  \
        AWS_SECRET_ACCESS_KEY="$aws_secret_access_key"          \
        aws-curl                                                \
            -s -o /dev/null -w "%{http_code}"                   \
            -X GET ${region:+--region $region}                  \
            "https://${bucket}.s3.amazonaws.com/.sccache_check" \
    );

    if  [ "${code}" -lt 200 ] \
     || [ "${code}" -gt 299 ] \
     && [ "${code}" -ne 404 ] ; then
        exit 1;
    fi

    echo -n "Hello, World!" > /tmp/.sccache_check;

    # Test PUT
    code=$(                                                     \
        AWS_SESSION_TOKEN="$aws_session_token"                  \
        AWS_ACCESS_KEY_ID="$aws_access_key_id"                  \
        AWS_SECRET_ACCESS_KEY="$aws_secret_access_key"          \
        aws-curl -d @/tmp/.sccache_check                        \
            -s -o /dev/null -w "%{http_code}"                   \
            -X PUT ${region:+--region $region}                  \
            "https://${bucket}.s3.amazonaws.com/.sccache_check" \
    );

    if  [ "${code}" -lt 200 ] \
     || [ "${code}" -gt 299 ] ; then
        exit 2;
    fi

    exit 0;
}

(test_aws_creds "$@");
