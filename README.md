# dotfiles

Personal macOS setup: zsh (oh-my-zsh + powerlevel10k), neovim, tmux, and git config,
plus a Homebrew Brewfile and a script that puts it all in place on a new machine.

## Fresh machine setup

```sh
git clone https://github.com/<your-username>/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` is idempotent — safe to re-run. It will:

1. Install Homebrew if it's missing.
2. Install every package in `Brewfile` (`brew bundle`).
3. Install oh-my-zsh and clone the powerlevel10k theme + zsh plugins it needs
   (zsh-autosuggestions, zsh-syntax-highlighting, zsh-history-substring-search).
4. Symlink the tracked configs into place:
   - `zsh/zshrc` → `~/.zshrc`
   - `zsh/p10k.zsh` → `~/.p10k.zsh`
   - `nvim/init.lua` → `~/.config/nvim/init.lua`
   - `tmux/tmux.conf` → `~/.tmux.conf`
   - `git/gitconfig` → `~/.gitconfig`

Any existing file at those paths is moved (not deleted) into
`~/.dotfiles-backup/<timestamp>/` before the symlink is created.

## Updating

- Edit the files in this repo directly (they're symlinked from `$HOME`, so
  changes take effect immediately) and commit.
- To pick up newly installed Homebrew packages: `brew bundle dump --force --file=Brewfile`.

## Neovim plugins

Plugins are managed by lazy.nvim and kept deliberately small (the same set has
to be allowed on the work machine). Exact versions are pinned in
`nvim/lazy-lock.json`, which lazy.nvim writes next to the real `init.lua`.

- Update on purpose: `:Lazy update`, review, then commit `lazy-lock.json`.
- Reproduce elsewhere: `:Lazy restore` checks out the pinned commits.
- Runtime tools the config expects: `fzf`, `fd`, `ripgrep`, `jq`,
  `tree-sitter-cli` + a C compiler (treesitter parsers), and Node.js (pyright via Mason).

## Keymaps

Leader is `Space`. tmux prefix is `Ctrl-Space`.

### Navigation (nvim + tmux)

| Key | Action |
|---|---|
| `Ctrl-h/j/k/l` | Move to the nvim split in that direction; at nvim's edge, move to the tmux pane instead. Outside nvim, moves tmux panes. Works in nvim-tree too. |
| `prefix` `Ctrl-l` | Clear the shell screen (plain `Ctrl-l` is taken by navigation) |

The handoff is ~10 lines in `init.lua` (`navigate()`), not a plugin. tmux
forwards the keys to nvim when the pane runs nvim/fzf (`is_vim` in tmux.conf).

### Neovim

| Key | Action |
|---|---|
| `<leader>pf` / `pb` / `ps` | Find files / open buffers / grep project (fzf-lua) |
| `<leader>pv` | Toggle file explorer (nvim-tree) |
| `<leader>pr` | Review working-tree changes as a book (paginate; only if `~/Desktop/personal_projects/paginate` exists) |
| `<leader>c` | Copy `file:line` (visual: `file:start-end`) to clipboard |
| `<leader>e` | Show diagnostic under cursor |
| `<leader>f` | Format JSON with jq (JSON buffers only) |
| `<Esc>` | Clear search highlight |
| `<leader>gs` / `gb` | Fugitive status / blame |
| `<leader>gd` | Diff current file vs index or a ref |
| `<leader>gt` | Toggle stage/unstage current file |
| `<leader>gu` / `gl` / `gc` | Review: uncommitted changes / a commit / whole branch vs merge-base |
| `<leader>gp` | Preview git hunk |
| `]c` / `[c` | Next/prev git hunk (in diff mode: next/prev diff block) |
| `gd` / `gD` | LSP definition / declaration |
| `grr` `gri` `grn` `gra` `grt` `K` | Neovim built-ins: references, implementation, rename, code action, type definition, hover |

In fzf-lua `git_status`: `Ctrl-h` stage, `Ctrl-l` unstage.

### tmux

| Key | Action |
|---|---|
| `prefix` `"` / `%` | Split below / right, in the current directory |
| `prefix` `P` | Paste the macOS clipboard (lowercase `p` stays "previous window") |
| `prefix` `r` | Reload config |
| copy mode `v` / `V` / `Ctrl-v` | Select / select line / block toggle |
| copy mode `y` / `Enter` | Copy to macOS clipboard |
| copy mode `Y` | Copy as a single line (newlines → spaces, never auto-runs on paste) |

### Deliberate choices (avoiding collisions)

- Copy-location is `<leader>c`; nothing else may start with `<leader>c`, or it
  would wait for the longer key (why there is no custom `<leader>ca`).
- No custom `gr`/`gi`/`<leader>rn`/`<leader>ca`: Neovim's built-in `gr*` LSP maps
  cover them, and a custom `gr` would delay all of them. Built-in `gi`
  (resume insert) is left intact.
- nvim-tree's `<C-k>` (file info popup) is unbound so `Ctrl-k` navigates.
- Plain `Ctrl-h/j/k/l` in shell panes no longer reach zsh (clear-screen,
  kill-line, backspace, enter); see `prefix Ctrl-l` above.

## Exporting to the work machine

Copy `nvim/init.lua` + `nvim/lazy-lock.json` into `~/.config/nvim/`, and
`tmux/tmux.conf` to `~/.tmux.conf`, then run `:Lazy restore` in nvim and
`tmux source-file ~/.tmux.conf`.

## Notes

- `git/gitconfig` bakes in the `user.name`/`user.email` above — update it if you
  fork this for a different identity.
- Not tracked on purpose: SSH keys, API tokens, machine-specific secrets. Keep
  those out of this repo.
