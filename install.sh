#!/usr/bin/env bash
# Bootstraps a fresh macOS machine with this dotfiles repo: Homebrew packages,
# oh-my-zsh + its plugins/theme, and symlinks for zsh/nvim/tmux/git config.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d%H%M%S)"

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }

link_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    return
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mkdir -p "$BACKUP_DIR"
    log "Backing up existing $dest -> $BACKUP_DIR/"
    mv "$dest" "$BACKUP_DIR/"
  fi
  ln -s "$src" "$dest"
  log "Linked $dest -> $src"
}

clone_if_missing() {
  local repo="$1" dest="$2"
  if [ ! -d "$dest" ]; then
    log "Cloning $repo -> $dest"
    git clone --depth=1 "$repo" "$dest"
  fi
}

# --- Homebrew ---
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

log "Installing packages from Brewfile"
brew bundle --file="$DOTFILES_DIR/Brewfile"

# --- oh-my-zsh ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  log "Installing oh-my-zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
clone_if_missing https://github.com/romkatv/powerlevel10k "$ZSH_CUSTOM/themes/powerlevel10k"
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_if_missing https://github.com/zsh-users/zsh-history-substring-search "$ZSH_CUSTOM/plugins/zsh-history-substring-search"

# --- symlinks ---
log "Linking dotfiles"
link_file "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/zsh/p10k.zsh" "$HOME/.p10k.zsh"
link_file "$DOTFILES_DIR/nvim/init.lua" "$HOME/.config/nvim/init.lua"
link_file "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
link_file "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"

if [ -d "$BACKUP_DIR" ]; then
  log "Existing files were backed up to $BACKUP_DIR"
fi

log "Done. Restart your terminal (or run 'exec zsh') to pick everything up."
