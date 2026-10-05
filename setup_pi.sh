#!/usr/bin/env bash

# ==============================================================
#  setup_pi.sh – Bootstrap a fresh Pi + Herdr installation and
#  install this repository's .pi configuration.
#
#  End-to-end usage:
#    git clone https://github.com/lidar532/jpi_tools.git
#    cd jpi_tools
#    ./setup_pi.sh
#    source ~/.bashrc      # or open a new terminal
# ==============================================================

set -euo pipefail

# ------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

  Bootstrap Pi + Herdr and install the .pi configuration stored in this
  repository.

  Getting started (end-to-end):

    git clone https://github.com/lidar532/jpi_tools.git
    cd jpi_tools
    ./setup_pi.sh
    source ~/.bashrc      # or open a new terminal

  Options:
    -h, --help      Show this help message and exit.
    -d, --dryrun    Execute in dry-run mode (no changes made).

  What it does:
    1. Installs the latest Pi from https://pi.dev
    2. Installs Herdr
    3. Adds the Pi/Herdr bin directories to your shell profile
    4. Merges this repository's .pi into ~/.pi (existing config is backed up)
    5. Prints how to start using Pi

  Note: models.json references credentials through environment variables
  (for example \\$OLLAMA_API_KEY). Set them before starting Pi, or sign in
  with /login. No API keys are stored in this repository.
EOF
  exit 0
}

# ------------------------------------------------------------------
# Parse options
# ------------------------------------------------------------------
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    -d|--dryrun) DRY_RUN=1; shift ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------
# run: execute a program with arguments (no eval)
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '>>'
    printf ' %q' "$@"
    printf '\n'
  else
    printf '>>'
    printf ' %q' "$@"
    printf '\n'
    "$@"
  fi
}

# run_shell: execute a shell string (pipelines / &&)
run_shell() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '>> %s\n' "$1"
  else
    printf '>> %s\n' "$1"
    eval "$1"
  fi
}

# persist_path: add Pi/Herdr bin dirs to shell profiles (idempotent)
persist_path() {
  local dirs="$PI_BIN_DIR:$PI_NODE_BIN_DIR:$PI_LOCAL_BIN"
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '>> would add to shell profiles: export PATH="%s:$PATH"\n' "$dirs"
    return
  fi
  for rc in "$USER_HOME/.bashrc" "$USER_HOME/.bash_profile" "$USER_HOME/.zshrc" "$USER_HOME/.profile"; do
    [[ -f "$rc" ]] || continue
    if grep -qF '.pi/agent/bin' "$rc" 2>/dev/null; then
      echo "PATH already configured in $rc"
      continue
    fi
    {
      printf '\n# Added by jpi_tools/setup_pi.sh\n'
      printf 'export PATH="%s:$PATH"\n' "$dirs"
    } >> "$rc"
    echo "Added Pi/Herdr PATH to $rc"
  done
}

# ------------------------------------------------------------------
# Sanity checks
# ------------------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required but not installed. Please install it first." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_PI_DIR="$SCRIPT_DIR/.pi"

if [[ ! -d "$REPO_PI_DIR" ]]; then
  echo "Error: repository .pi directory not found at $REPO_PI_DIR" >&2
  exit 1
fi

USER_HOME="${HOME:?HOME is not set}"
CONFIG_TARGET="$USER_HOME/.pi"

PI_BIN_DIR="$USER_HOME/.pi/agent/bin"
PI_NODE_BIN_DIR="${XDG_DATA_HOME:-$USER_HOME/.local/share}/pi-node/current/bin"
PI_LOCAL_BIN="$USER_HOME/.local/bin"
export PATH="$PI_BIN_DIR:$PI_NODE_BIN_DIR:$PI_LOCAL_BIN:$PATH"

# ------------------------------------------------------------------
# 1. Install the latest Pi
# ------------------------------------------------------------------
PI_INSTALL_URL="https://pi.dev/install.sh"
run_shell "curl -fsSL \"$PI_INSTALL_URL\" | bash -s -- --latest"
export PATH="$PI_BIN_DIR:$PI_NODE_BIN_DIR:$PI_LOCAL_BIN:$PATH"

# ------------------------------------------------------------------
# 2. Install Herdr
# ------------------------------------------------------------------
HERDR_INSTALL_URL="https://herdr.dev/install.sh"
run_shell "curl -fsSL \"$HERDR_INSTALL_URL\" | bash -s -- -y"
export PATH="$PI_BIN_DIR:$PI_NODE_BIN_DIR:$PI_LOCAL_BIN:$PATH"

# ------------------------------------------------------------------
# 3. Persist the PATH for future shells
# ------------------------------------------------------------------
persist_path

# ------------------------------------------------------------------
# 4. Install the repository .pi configuration.
#    Merge into ~/.pi so the just-installed Pi program is preserved.
# ------------------------------------------------------------------
run mkdir -p "$CONFIG_TARGET"

BACKUP_DIR="$USER_HOME/.pi.config-bak.$(date +%Y%m%d%H%M%S)"
have_backup=0
for rel in agent/models.json agent/models-store.json agent/settings.json agent/extensions; do
  target="$CONFIG_TARGET/$rel"
  if [[ -e "$target" ]]; then
    if [[ $have_backup -eq 0 ]]; then
      echo "Backing up existing config to $BACKUP_DIR"
      have_backup=1
    fi
    run mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    run cp -a "$target" "$BACKUP_DIR/$rel"
  fi
done

run cp -a "$REPO_PI_DIR/." "$CONFIG_TARGET/"

# ------------------------------------------------------------------
# 5. Verify
# ------------------------------------------------------------------
if [[ $DRY_RUN -eq 0 ]] && command -v pi >/dev/null 2>&1; then
  echo
  echo "Models now available to Pi:"
  pi --list-models 2>/dev/null | head -n 6 || true
fi

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry-run finished – no system changes were made."
else
  echo
  echo "Pi and Herdr installed, and the repository .pi configuration installed."
  if command -v pi >/dev/null 2>&1; then
    echo "'pi' is ready to use."
  else
    echo "Note: 'pi' is not on PATH in this shell yet."
  fi
  echo "To use 'pi' in your current shell, run:"
  echo "    source ~/.bashrc      # or ~/.zshrc"
  echo "or simply open a new terminal."
fi
