
# GitLab CLI (gitlab-cli)

Installs the GitLab CLI. Auto-detects latest version and installs needed dependencies.

## Example Usage

```json
"features": {
    "ghcr.io/rapidsai/devcontainers/features/gitlab-cli:25": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select version of the GitLab CLI, if not latest. | string | latest |



## OS Support

This Feature should work on recent versions of Debian/Ubuntu-based distributions with the `apt` package manager installed.

`bash` is required to execute the `install.sh` script.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/rapidsai/devcontainers/blob/main/features/src/gitlab-cli/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
