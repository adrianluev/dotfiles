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

## Notes

- `git/gitconfig` bakes in the `user.name`/`user.email` above — update it if you
  fork this for a different identity.
- Not tracked on purpose: SSH keys, API tokens, machine-specific secrets. Keep
  those out of this repo.
