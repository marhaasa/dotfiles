#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
  else
    error "Unsupported OS: $OSTYPE"
  fi
  info "Detected OS: $OS"
}

# Check for required commands
check_requirements() {
  local required_cmds=("git" "ln")

  for cmd in "${required_cmds[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      error "Required command not found: $cmd"
    fi
  done

  # Check for Homebrew on macOS
  if [[ "$OS" == "macos" ]] && ! command -v brew &>/dev/null; then
    warn "Homebrew not found. Install it from https://brew.sh"
  fi
}

# Create directories
create_directories() {
  info "Creating directories..."

  # Config directories
  mkdir -p "$HOME/.config"/{nvim,zsh,ghostty,omniwm}
  mkdir -p "$HOME/.zsh_functions"
  mkdir -p "$HOME/.local/bin"

  # macOS specific
  if [[ "$OS" == "macos" ]]; then
    mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
  fi
}

# Backup existing files
backup_if_exists() {
  local file=$1
  if [[ -e "$file" ]] && [[ ! -L "$file" ]]; then
    warn "Backing up existing $file to $file.backup"
    mv "$file" "$file.backup"
  fi
}

# Create symlink safely
create_symlink() {
  local source=$1
  local target=$2

  # Check if source exists
  if [[ ! -e "$source" ]]; then
    error "Source file does not exist: $source"
  fi

  # Backup existing file if it's not a symlink
  backup_if_exists "$target"

  # Remove existing symlink
  if [[ -L "$target" ]]; then
    rm "$target"
  fi

  # Create new symlink
  ln -sf "$source" "$target"
  info "Linked $source -> $target"
}

# Setup shell configurations
setup_shell() {
  info "Setting up shell configurations..."

  create_symlink "$PWD/.zshrc" "$HOME/.zshrc"
  create_symlink "$PWD/.bash_profile" "$HOME/.bash_profile"
  create_symlink "$PWD/.bashrc" "$HOME/.bashrc"
  create_symlink "$PWD/.inputrc" "$HOME/.inputrc"
  create_symlink "$PWD/.zsh_functions" "$HOME/.zsh_functions"
  create_symlink "$PWD/newsboat/" "$HOME/.newsboat"
  create_symlink "$PWD/visidata/visidatarc" "$HOME/.visidatarc"
}

# Setup Neovim
setup_neovim() {
  info "Setting up Neovim..."

  create_symlink "$PWD/nvim" "$HOME/.config/nvim"

  # Install Neovim if not present
  if ! command -v nvim &>/dev/null; then
    warn "Neovim not found. Please install it."
  else
    if command -v nvim >/dev/null 2>&1; then
      info "Installing LazyVim plugins..."
      nvim --headless "+Lazy! sync" +qa
    fi
  fi

}

# Setup OmniWM (tiling window manager). settings.toml is the canonical, live-reloaded
# config; the symlink target is preserved by OmniWM's atomic saves (>= 0.6.3).
setup_omniwm() {
  info "Setting up OmniWM..."

  if [[ "$OS" == "macos" ]]; then
    create_symlink "$PWD/omniwm/settings.toml" "$HOME/.config/omniwm/settings.toml"

    # OmniWM requires "Displays have separate Spaces" (System Settings > Desktop & Dock >
    # Mission Control). spans-displays=1 means it is OFF; unset or 0 means ON.
    if [[ "$(defaults read com.apple.spaces spans-displays 2>/dev/null || echo 0)" == "1" ]]; then
      defaults write com.apple.spaces spans-displays -bool false
      warn "Enabled 'Displays have separate Spaces' for OmniWM. Log out and back in to apply."
    fi
  else
    warn "OmniWM setup only configured for macOS"
  fi
}

# Setup Ghostty
setup_ghostty() {
  info "Setting up Ghostty..."

  if [[ "$OS" == "macos" ]]; then
    create_symlink "$PWD/ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
  else
    warn "Ghostty setup only configured for macOS"
  fi
}

# Setup notes and iCloud (macOS only)
# Resolve an installed app bundle: Spotlight lookup by bundle id first, then the
# given fallback paths. Prints the path, or returns 1 if the app is not installed.
resolve_app() {
  local bundle_id=$1
  shift
  local path
  path=$(mdfind "kMDItemCFBundleIdentifier == '$bundle_id'" 2>/dev/null \
    | grep -E '^/(System/)?Applications/' | head -1)
  if [[ -n "$path" && -d "$path" ]]; then
    echo "$path"
    return 0
  fi
  for path in "$@"; do
    if [[ -d "$path" ]]; then
      echo "$path"
      return 0
    fi
  done
  return 1
}

# Add an app to the Dock at a position, skipping apps that are not installed.
dock_add() {
  local position=$1 bundle_id=$2
  shift 2
  local app
  if app=$(resolve_app "$bundle_id" "$@"); then
    dockutil --add "$app" --position "$position" --no-restart
  else
    warn "Dock: $bundle_id not installed, skipping"
  fi
}

setup_macos_specific() {
  if [[ "$OS" != "macos" ]]; then
    return
  fi

  info "Setting up macOS-specific configurations..."

  # Notes
  local notes_path="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notes/"
  if [[ -d "$notes_path" ]]; then
    create_symlink "$notes_path" "$HOME/notes"
  else
    warn "Notes directory not found at $notes_path"
  fi

  # iCloud
  local icloud_path="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  if [[ -d "$icloud_path" ]]; then
    create_symlink "$icloud_path" "$HOME/icloud"
  else
    warn "iCloud directory not found at $icloud_path"
  fi

  info "Configuring dock..."
  # Remove everything first (optional)
  dockutil --remove all --no-restart

  # Add your favorite apps in order. Apps are resolved by bundle id so a moved
  # bundle (e.g. Safari, which lives in /Applications, not /System/Applications)
  # never becomes a dead "?" tile; unknown apps are skipped with a warning.
  dock_add 1 com.mitchellh.ghostty          "/Applications/Ghostty.app"
  dock_add 2 com.apple.Safari               "/Applications/Safari.app"
  dock_add 3 com.anthropic.claudefordesktop "/Applications/Claude.app"
  dock_add 4 com.apple.iCal                 "/System/Applications/Calendar.app"
  dock_add 5 com.apple.Music                "/System/Applications/Music.app"

  # Remove recent apps part of Dock
  defaults write com.apple.dock show-recents -bool false

  # Finally, restart the Dock to apply
  osascript -e 'tell application "Dock" to quit'

  info "Dock configured!"
}

# Homebrew 6 ignores formulae and casks from third-party taps until the tap is
# trusted. `brew bundle install` persists the trust declared with `trusted: true`
# in the Brewfile, but only while processing the tap entry, so formulae from that
# tap are not upgrade-checked on the same run. Trusting up front (idempotent, and
# valid before the tap is even tapped) makes the first run complete.
trust_brewfile_taps() {
  local tap
  while IFS= read -r tap; do
    [[ -n "$tap" ]] || continue
    brew trust "$tap" >/dev/null 2>&1 || warn "Could not trust tap $tap"
  done < <(sed -nE "s/^tap '([^']+)', trusted: true.*/\1/p" Brewfile)
}

# Casks whose Caskroom still holds a full copy of the old app, instead of a symlink
# to /Applications, make `brew upgrade` fail with "It seems there is already an App
# at '/opt/homebrew/Caskroom/...'": brew cannot move the old app back before
# replacing it. Self-updating apps (Signal, VS Code, Postman, Miro, ...) end up in
# this state. `--force` lets brew overwrite the stale copy. Only casks brew already
# considers outdated are listed, so up-to-date casks are never touched.
stale_outdated_casks() {
  local caskroom outdated cask app
  caskroom="$(brew --prefix)/Caskroom"
  outdated=$(brew outdated --cask --quiet 2>/dev/null) || return 0
  for cask in $outdated; do
    for app in "$caskroom/$cask"/*/*.app; do
      if [[ -d "$app" && ! -L "$app" ]]; then
        echo "$cask"
        break
      fi
    done
  done
}

retry_stale_cask_upgrades() {
  local stale
  stale=$(stale_outdated_casks | tr '\n' ' ')
  stale=${stale% }
  [[ -n "$stale" ]] || return 0

  warn "Stale app copies in the Caskroom block upgrading: $stale"
  info "Retrying with: brew upgrade --cask --force $stale"
  # shellcheck disable=SC2086
  brew upgrade --cask --force $stale \
    || warn "Still failing. Casks that need sudo or a quit app (Docker, Parallels) may need a manual: brew upgrade --cask --force <cask>"
}

# Install packages
install_packages() {
  info "Installing packages..."

  if [[ "$OS" == "macos" ]] && command -v brew &>/dev/null; then
    if [[ -f "Brewfile" ]]; then
      info "Installing Homebrew packages..."
      trust_brewfile_taps
      if ! brew bundle; then
        warn "Some Homebrew packages failed to install or upgrade"
        retry_stale_cask_upgrades
      fi
    else
      warn "Brewfile not found"
    fi
  fi

  # Claude Code: installed with the native installer (self-updating), not Homebrew.
  # The Homebrew cask lagged behind, and its /opt/homebrew/bin/claude shadowed the
  # native ~/.local/bin/claude on PATH, so `claude` kept running an old version.
  if [[ -x "$HOME/.local/bin/claude" ]]; then
    info "Claude Code already installed (native)"
  else
    info "Installing Claude Code (native installer)..."
    curl -fsSL https://claude.ai/install.sh | bash || warn "Claude Code install failed"
  fi
  if brew list --cask claude-code &>/dev/null; then
    warn "Homebrew cask 'claude-code' is still installed and shadows the native install: brew uninstall --cask claude-code"
  fi

  # Install Python tools
  if command -v pipx &>/dev/null; then
    info "Installing Python tools..."
    pipx install poetry ms-fabric-cli || warn "Failed to install Python tools"
  else
    warn "pipx not found. Install it with: brew install pipx"
  fi
}

# Post-install tasks
post_install() {
  info "Running post-install tasks..."

  # Add zsh to /etc/shells
  info "Adding zsh to /etc/shells..."
  echo $(which zsh) | sudo tee -a /etc/shells

  info "Set zsh as default user shell"
  sudo chsh -s $(which zsh) $USER

  # Set zsh as default shell if not already
  if [[ "$SHELL" != */zsh ]]; then
    warn "Current shell is not zsh. Run 'chsh -s $(which zsh)' to change it."
  fi

  # Set up ssh config with 1Password ssh agent
  info "Set up ssh config with 1Password agent..."
  SSH_CONFIG="$HOME/.ssh/config"
  ONEPASSWORD_AGENT_PATH="~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock"

  # Create ~/.ssh directory if it doesn't exist
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  # Add 1Password SSH agent config if not already present
  if ! grep -q "IdentityAgent .*2BUA8C4S2C.com.1password" "$SSH_CONFIG" 2>/dev/null; then
    {
      echo ""
      echo "Host *"
      echo "  IdentityAgent $ONEPASSWORD_AGENT_PATH"
    } >>"$SSH_CONFIG"
    info "Added 1Password SSH agent to ~/.ssh/config"
  else
    info "1Password SSH agent already configured in ~/.ssh/config"
  fi

  chmod 600 "$SSH_CONFIG"

  # Set Git user config
  info "Set up git config"
  if [ -z "$(git config --global user.name)" ]; then
    git config --global user.name "marhaasa"
    git config --global user.email "marius@aasarod.no"
    info "Configured Git user and email."
  else
    info "Git user and email already configured."
  fi

}

# Main installation
main() {
  info "Starting dotfiles setup..."

  detect_os
  check_requirements
  create_directories
  setup_shell
  setup_neovim
  setup_ghostty
  setup_omniwm
  setup_macos_specific
  install_packages
  post_install

  info "Setup complete! 🎉"
  info "Please restart your terminal or run 'source ~/.zshrc'"
}

# Run main function
main "$@"
