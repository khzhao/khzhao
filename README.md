# khzhao

`khzhao` is a lightweight personal environment manager. It installs this repo,
keeps a small set of dotfiles/configs in sync, provides a dedicated NVChad
Neovim profile called `zim`, and exposes repo-owned project templates through
`khzhao run`.

The ownership model is deliberate:

- khzhao manages shell blocks, dotfile links, `zim` config/state, legacy cleanup,
  and its own entrypoint.
- khzhao can install missing tools to normal user-local locations.
- `khzhao uninstall` removes khzhao-owned state and settings, but keeps tool
  binaries such as `uv`, `node`, `nvm`, and `nvim`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/khzhao/khzhao/main/install.sh | bash
```

Skip tool installation/checks:

```bash
curl -fsSL https://raw.githubusercontent.com/khzhao/khzhao/main/install.sh | bash -s -- --skip-tools
```

Install creates `~/.khzhao` for the repo, state, backups, and temp files, then
links:

```text
~/.local/bin/khzhao -> ~/.khzhao/repo/khzhao
```

## What It Manages

Tools:

- checks prerequisites: `git`, `curl`
- installs if missing or unsuitable: `neovim`, `uv`, `node`/`npm`
- runs legacy Vim cleanup for older khzhao releases

Tool installs use normal user-local locations:

- `uv`: official uv installer with shell profile edits disabled
- `node`/`npm`: `nvm` under `~/.nvm`
- `nvim`: official Neovim release archive under `~/.local/share/neovim`, linked
  from `~/.local/bin/nvim`

Dotfiles and shell config:

- symlinks: `~/.vimrc`, `~/.gitconfig`, `~/.gitignore_global`, `~/.tmux.conf`
- shell blocks: `~/.bashrc`, `~/.zshrc`
- local user files are sourced but not removed: `~/.bashrc.khzhao`,
  `~/.zshrc.khzhao`

Editor profile:

- `zim` is the khzhao Neovim profile.
- `zim` launches regular `nvim` with `NVIM_APPNAME=zim`.
- NVChad is installed from `https://github.com/NvChad/starter` into
  `~/.config/zim`.
- khzhao overlays repo-owned mappings from `share/configs/zim/lua/mappings.lua`.
- Runtime state is isolated under `~/.local/share/zim`, `~/.local/state/zim`,
  and `~/.cache/zim`.
- The normal Neovim profile is left alone: `~/.config/nvim`,
  `~/.local/share/nvim`, `~/.local/state/nvim`, `~/.cache/nvim`.

## Commands

```bash
khzhao install [--dry-run] [--skip-tools] [--only <name>]
khzhao update [--dry-run]
khzhao uninstall [--dry-run] [--restore-backups]
khzhao cheatsheet [--path]
khzhao info
khzhao list
khzhao doctor
khzhao run <task-name> [args...]
```

Examples:

```bash
khzhao install --only zim
khzhao update
khzhao cheatsheet
khzhao doctor
zim
```

`khzhao update` updates `~/.khzhao/repo` and reruns `khzhao install`.

## Uninstall

```bash
khzhao uninstall
```

Uninstall removes khzhao-owned artifacts:

- managed dotfile symlinks and shell blocks
- `~/.local/bin/khzhao`
- `~/.local/bin/zim`
- `~/.config/zim`
- `~/.local/share/zim`, `~/.local/state/zim`, `~/.cache/zim`
- legacy Vim artifacts from older khzhao releases
- `~/.khzhao`

If khzhao moved an existing file aside to create a managed symlink, plain
uninstall restores that file before deleting `~/.khzhao`.

Use exact rollback only when needed:

```bash
khzhao uninstall --restore-backups
```

`--restore-backups` also restores full-file backups for managed shell rc files.
That can discard shell rc edits made after installing khzhao, so plain
`khzhao uninstall` is usually safer.

Uninstall does not remove `git`, `curl`, `uv`, `node`, `nvm`, `nvim`,
`~/.bashrc.khzhao`, or `~/.zshrc.khzhao`.

## Project Templates

`khzhao run` is the repo task runner. Current task:

```bash
khzhao run new-project <family> <name> [--base <base>] [--with <components>]
```

Supported families:

- `python`: default base `package`; default components
  `ipykernel,ruff,pre-commit,pyrefly,pytest`
- `cpp`: default base `project`

Examples:

```bash
khzhao run new-project python mypkg
khzhao run new-project python mypkg --with ruff,pytest
khzhao run new-project cpp mylib
khzhao run new-project python --list-components
khzhao run new-project cpp --list-bases
```

Python dependencies are pinned with `uv add --bounds lower --upgrade --no-sync`.

## Source Of Truth

The manifests define the managed surface:

- `share/manifest/tools.psv`
- `share/manifest/configs.psv`
- `share/manifest/dotfiles.psv`
- `share/manifest/tasks.psv`

The installed repo at `~/.khzhao/repo` remains the source of truth; `share/` is
not copied elsewhere.
