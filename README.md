# khzhao

Small GitHub-repo-backed personal environment manager.

## Install

Prompt before installing missing packages:

```bash
curl -fsSL https://raw.githubusercontent.com/khzhao/khzhao/main/install.sh | bash
```

Skip package installation entirely:

```bash
curl -fsSL https://raw.githubusercontent.com/khzhao/khzhao/main/install.sh | bash -s -- --skip-packages
```

Install missing packages without prompts:

```bash
curl -fsSL https://raw.githubusercontent.com/khzhao/khzhao/main/install.sh | bash -s -- --force
```

Install creates:

```text
~/.khzhao/
  repo/
  state/
  backups/
  logs/
  tmp/
```

Command entrypoint:

```text
~/.local/bin/khzhao -> ~/.khzhao/repo/khzhao
```

Required packages: `git`, `curl`, `uv`, `node`/`npm`.

Missing packages prompt with `[Y/n]`; `--force` answers yes. Existing `node`/`npm` installations are reused. If Node is missing, khzhao installs `nvm` and uses it to install latest LTS Node. Packages are not khzhao-owned.

## Commands

```bash
khzhao install
khzhao update [--dry-run]
khzhao uninstall
khzhao info
khzhao run <task> [...]
khzhao list
khzhao doctor
khzhao help
```

`khzhao update` fast-forwards `~/.khzhao/repo` and reruns `khzhao install`.

## Uninstall

```bash
khzhao uninstall
khzhao uninstall --restore-backups
```

Removes khzhao-owned artifacts:

- managed dotfile symlinks
- managed shell blocks
- `~/.local/bin/khzhao`
- `~/.khzhao`

Does not remove global/user packages or generated projects.

## Project Templates

```bash
khzhao run new-project <family> <name> [--base <base>] [--with <components>]
```

- `python`: default base `package`, default components `ipykernel,ruff,pre-commit,pyrefly,pytest`
- `cpp`: default base `project`, no components

```bash
khzhao run new-project python mypkg
khzhao run new-project python mypkg --with ruff,pytest
khzhao run new-project cpp mylib
khzhao run new-project python --list-components
khzhao run new-project cpp --list-bases
```

Python packages are pinned with `uv add --bounds lower --upgrade --no-sync`. The `pre-commit` component depends on `ruff` and uses the resolved Ruff version in `.pre-commit-config.yaml`.

## Repo Layout

```text
install.sh
khzhao
install/
  run.sh
  packages/
share/
  manifest/
  dotfiles/
  tasks/
  templates/
```

The repo is the source of truth. `share/` is not duplicated into `~/.khzhao`; installed machines use `~/.khzhao/repo/share`.
