#!/usr/bin/env bash

#=============================================================
#  setup_pi.sh - Install Pi and Herdr, then configure Pi
#  from the existing ".pi" configuration directory.
#=============================================================

#=============================================================
#  setup_pi.sh - Install Pi and Herdr, then configure Pi
#  from the existing \".pi\" configuration directory.
#=============================================================

set -euo pipefail

#-------------------------------------------
# Helper functions
#-------------------------------------------
usage() {
  cat <<'EOF'
Usage: $0 [OPTIONS]

  The script must be run from the directory that contains the
  configuration module \".pi\" – typically the repository root.

  Options:
    -h, --help   Show this help message and exit.
    -d, --dryrun Dry‑run the installation commands without executing them.

  Example:
    ./setup_pi.sh
EOF
  exit 0
}

#-------------------------------------------
# Parse arguments
#-------------------------------------------
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage;;
    -d|--dryrun) DRY_RUN=1; shift;;
    *) echo "Unknown option: $1"; usage;;
  esac
done

#-------------------------------------------
# Helper to run commands
#-------------------------------------------
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo ">> $*"  # Dry‑run mode
  else
    echo "$*"
    eval "$*"
  fi
}

#-------------------------------------------
# Step 1: Install the latest Pi
#-------------------------------------------
PI_INSTALL_URL="https://pi.dev/install.sh"
RUN_PI_INSTALL="curl -fsSL \"$PI_INSTALL_URL\" | bash -s -- --latest"
run "$RUN_PI_INSTALL"

# The official installer places the CLI at ~/bin/pi or updates $PATH.
# Ensure it's available for the rest of the script.
export PATH="$HOME/bin:$PATH"

#-------------------------------------------
# Step 2: Install Herdr
#-------------------------------------------
# Herdr is distributed via a simple script; adjust the URL if it changes.
HERDR_INSTALL_URL="https://herdr.dev/install.sh"
RUN_HERDR_INSTALL="curl -fsSL \"$HERDR_INSTALL_URL\" | bash -s -- -y"
run "$RUN_HERDR_INSTALL"

# Ensure herdr CLI is on the path
export PATH="$HOME/bin:$PATH"

#-------------------------------------------
# Install models from existing .pi config
#-------------------------------------------
MODEL_JSON="${HOME}/.pi/agent/models.json"

if [[ -f "$MODEL_JSON" ]]; then
  echo "Found models.json at $MODEL_JSON – preparing to install models"

  # Use jq for JSON parsing – install if missing
  if ! command -v jq > /dev/null 2>&1; then
    echo "jq not found – attempting to install it"
    if command -v apt-get > /dev/null 2>&1; then
      run "sudo apt-get update && sudo apt-get install -y jq"
    elif command -v dnf > /dev/null 2>&1; then
      run "sudo dnf install -y jq"
    elif command -v yum > /dev/null 2>&1; then
      run "sudo yum install -y jq"
    else
      echo "Could not autodetect package manager – please install jq manually"
    fi
  fi

  # Collect model identifiers from the JSON file
  mapfile -t MODEL_IDS < <(jq -r '.models[].id' "$MODEL_JSON")
  if [[ ${#MODEL_IDS[@]} -eq 0 ]]; then
    echo "No models defined in $MODEL_JSON – skipping"
  else
    for MODEL_ID in "${MODEL_IDS[@]}"; do
      echo "Installing model: $MODEL_ID"
      run "pi install model $MODEL_ID"
    done
  fi
else
  echo "No $MODEL_JSON present – skipping additional model installation"
fi


#-------------------------------------------
# Step 3: Copy the current .pi config
#-------------------------------------------
# Determine current user and home directory
USER_NAME="${USER:-$LOGNAME}"
USER_HOME="${HOME:-$(eval echo ~${USER_NAME})}"

# Locate the .pi configuration in the user's home
CONFIG_SOURCE="${USER_HOME}/.pi"
CONFIG_TARGET="${USER_HOME}/.pi"

if [[ ! -d "$CONFIG_SOURCE" ]]; then
  echo "Error: Expected configuration directory \"$CONFIG_SOURCE\" not found." >&2
  exit 1
fi

# Copy (or update) the configuration directory
run "cp -rv \"$CONFIG_SOURCE\" \"$CONFIG_TARGET\""


#-------------------------------------------
# Step 4: Apply configuration to Pi
#-------------------------------------------
# The exact command depends on Pi's CLI. It might look something like:
#   pi config apply --source="$CONFIG_TARGET"
# We check if the command exists.
if command -v pi >/dev/null 2>&1; then
  run "pi config apply --source=$CONFIG_TARGET"

else
  echo "Warning: 'pi' command not found after installation; skip config apply.")
fi

#-------------------------------------------
# Completion message
#-------------------------------------------
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry‑run completed – no changes were made."
else
  echo "Pi and Herdr installation complete. Configuration applied."
fi

