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
  vim/
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

Missing packages prompt with `[Y/n]`; `--force` answers yes. Existing `node`/`npm` installations are reused. If Node is missing, khzhao installs `nvm` and uses it to install latest LTS Node. Packages are not khzhao-owned. Vim is assumed to already exist on the machine.

Vim plugins are khzhao-owned and installed under:

```text
~/.khzhao/vim/
  autoload/plug.vim
  plugged/
```

The managed Vim config uses vim-plug to install NERDTree and vim-buftabline. `khzhao install` bootstraps vim-plug and runs `PlugInstall` when installing the Vim config.

## Commands

```bash
khzhao install [--dry-run] [--force] [--only <name>]
khzhao update [--dry-run]
khzhao uninstall [--dry-run] [--restore-backups]
khzhao info
khzhao run <task> [...]
khzhao list
khzhao doctor
khzhao help
```

`khzhao update` fast-forwards `~/.khzhao/repo` and reruns `khzhao install`.

## Dotfiles

Managed symlinks:

- `~/.vimrc`
- `~/.gitconfig`
- `~/.gitignore_global`
- `~/.tmux.conf`

Managed shell blocks:

- `~/.bashrc`
- `~/.zshrc`

Install one dotfile by manifest name:

```bash
khzhao install --only vimrc
```

## Uninstall

```bash
khzhao uninstall
khzhao uninstall --restore-backups
```

Removes khzhao-owned artifacts:

- managed dotfile symlinks
- managed shell blocks
- managed Vim plugins under `~/.khzhao/vim`
- `~/.NERDTreeBookmarks`
- `~/.local/bin/khzhao`
- `~/.khzhao`

Does not remove global/user packages, generated projects, or unrelated `~/.vim` files.

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
