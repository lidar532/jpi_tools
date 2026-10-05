#!/usr/bin/env bash

# ==============================================================
#  setup_pi.sh – Bootstrap a fresh Pi/Herdr installation and copy the
#  current .pi configuration from this repository.
#
#  The script assumes that the directory containing this file also
#  contains the repository's ``.pi`` directory.
# ==============================================================

set -euo pipefail

# ------------------------------------------------------------------
# Helper: Usage
# ------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: $0 [OPTIONS]

  Options:
    -h, --help      Show this help message and exit.
    -d, --dryrun    Execute the script in dry‑run mode (no writes).

  The script must be run from the repository root that contains the
  .pi configuration directory.
EOF
  exit 0
}

# ------------------------------------------------------------------
# Parse command‑line options
# ------------------------------------------------------------------
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage;;
    -d|--dryrun) DRY_RUN=1; shift;;
    *) echo "Unknown option: $1"; usage;;
  esac
done

# ------------------------------------------------------------------
# Helper to run commands (respect dry‑run)
# ------------------------------------------------------------------
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "\u003e\u003e $*"
  else
    echo "$*"
    eval "$*"
  fi
}

# ------------------------------------------------------------------
# 1. Install the latest Pi
# ------------------------------------------------------------------
PI_INSTALL_URL="https://pi.dev/install.sh"
run "curl -fsSL \"$PI_INSTALL_URL\" | bash -s -- --latest"
export PATH="$HOME/bin:$PATH"      # Pi installs to $HOME/bin

# ------------------------------------------------------------------
# 2. Install Herdr
# ------------------------------------------------------------------
HERDR_INSTALL_URL="https://herdr.dev/install.sh"
run "curl -fsSL \"$HERDR_INSTALL_URL\" | bash -s -- -y"
export PATH="$HOME/bin:$PATH"

# ------------------------------------------------------------------
# 3. Install models declared in the repository’s .pi configuration
# ------------------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_PI_DIR="$SCRIPT_DIR/.pi"
MODEL_JSON="$REPO_PI_DIR/agent/models.json"

if [[ -f "$MODEL_JSON" ]]; then
  echo "Found models.json – installing models listed therein"
  if ! command -v jq > /dev/null 2>&1; then
    echo 'jq not found – installing it'
    if command -v apt-get > /dev/null 2>&1; then
      run "sudo apt-get update && sudo apt-get install -y jq"
    elif command -v dnf > /dev/null 2>&1; then
      run "sudo dnf install -y jq"
    elif command -v yum > /dev/null 2>&1; then
      run "sudo yum install -y jq"
    else
      echo 'Could not autodetect package manager – please install jq manually'
    fi
  fi
  # Grab model IDs and install each
  mapfile -t MODEL_IDS < <(jq -r '.models[].id' "$MODEL_JSON")
  if [[ ${#MODEL_IDS[@]} -eq 0 ]]; then
    echo 'No models found in models.json – nothing to install'
  else
    for MODEL_ID in "${MODEL_IDS[@]}"; do
      echo "Installing model $MODEL_ID"
      run "pi install model $MODEL_ID"
    done
  fi
else
  echo "No $MODEL_JSON – skipping model installation"
fi

# ------------------------------------------------------------------
# 4. Copy repository .pi configuration into the user’s home
# ------------------------------------------------------------------
USER_HOME="${HOME:-$(eval echo ~${USER:-$LOGNAME})}"
CONFIG_TARGET="$USER_HOME/.pi"

run "mkdir -p \"$CONFIG_TARGET\""
run "cp -rv "$REPO_PI_DIR"/* "$CONFIG_TARGET""

# ------------------------------------------------------------------
# 5. Apply configuration to Pi
# ------------------------------------------------------------------
if command -v pi > /dev/null 2>&1; then
  run "pi config apply --source="$CONFIG_TARGET""
else
  echo "Warning: 'pi' not found – configuration will not be applied"
fi

# ------------------------------------------------------------------
# Done!
# ------------------------------------------------------------------
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry‑run finished – no system changes were made."
else
  echo "Pi and Herdr installed, configured, and models from the repo installed."
fi

EOF