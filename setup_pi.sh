#!/usr/bin/env bash

# ==============================================================
#  setup_pi.sh – Bootstrap a fresh Pi/Herdr installation and copy the
#  current .pi configuration from this repository.
#
#  The script assumes that the directory containing this file also
#  contains the repository's .pi directory.
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

  Options:
    -h, --help      Show this help message and exit.
    -d, --dryrun    Execute in dry-run mode (no changes made).

  What it does:
    1. Installs the latest Pi from https://pi.dev
    2. Installs Herdr
    3. Backs up any existing ~/.pi to ~/.pi.bak.<timestamp>
    4. Copies this repository's .pi into ~/.pi
    5. Installs every model listed in .pi/agent/models.json
    6. Runs 'pi config apply'

  Note: set credentials referenced by models.json (for example
  \$OLLAMA_API_KEY) before running, or run Pi's auth flow afterwards.
  No API keys are stored in this repository.
EOF
  exit 0
}

# ------------------------------------------------------------------
# Parse command-line options
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
# run: execute a program with arguments (safe, no eval).
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

# run_shell: execute a shell command string that needs pipelines/&&.
run_shell() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '>> %s\n' "$1"
  else
    printf '>> %s\n' "$1"
    eval "$1"
  fi
}

# ------------------------------------------------------------------
# Early sanity checks
# ------------------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required but not installed. Please install it first." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_PI_DIR="$SCRIPT_DIR/.pi"
MODEL_JSON="$REPO_PI_DIR/agent/models.json"

if [[ ! -d "$REPO_PI_DIR" ]]; then
  echo "Error: repository .pi directory not found at $REPO_PI_DIR" >&2
  exit 1
fi

USER_HOME="${HOME:?HOME is not set}"
CONFIG_TARGET="$USER_HOME/.pi"

# ------------------------------------------------------------------
# 1. Install the latest Pi
# ------------------------------------------------------------------
PI_INSTALL_URL="https://pi.dev/install.sh"
run_shell "curl -fsSL \"$PI_INSTALL_URL\" | bash -s -- --latest"
export PATH="$HOME/bin:$PATH"        # Pi installs into $HOME/bin

# ------------------------------------------------------------------
# 2. Install Herdr
# ------------------------------------------------------------------
HERDR_INSTALL_URL="https://herdr.dev/install.sh"
run_shell "curl -fsSL \"$HERDR_INSTALL_URL\" | bash -s -- -y"
export PATH="$HOME/bin:$PATH"

# ------------------------------------------------------------------
# 3. Copy the repository .pi into the user's home directory
#    (cp -a preserves permissions/links; "./." includes dotfiles)
# ------------------------------------------------------------------
# Back up an existing ~/.pi so nothing is silently lost
if [[ -e "$CONFIG_TARGET" ]]; then
  BACKUP="${CONFIG_TARGET}.bak.$(date +%Y%m%d%H%M%S)"
  echo "Existing $CONFIG_TARGET found – backing up to $BACKUP"
  run mv "$CONFIG_TARGET" "$BACKUP"
fi

run mkdir -p "$CONFIG_TARGET"
run cp -a "$REPO_PI_DIR/." "$CONFIG_TARGET/"

# ------------------------------------------------------------------
# 4. Install all models declared in .pi/agent/models.json
# ------------------------------------------------------------------
if [[ -f "$MODEL_JSON" ]]; then
  echo "Found $MODEL_JSON – installing models listed therein"

  # Ensure jq is available
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq not found – attempting to install it"
    if   command -v apt-get >/dev/null 2>&1; then
      run_shell "sudo apt-get update && sudo apt-get install -y jq"
    elif command -v dnf >/dev/null 2>&1; then
      run_shell "sudo dnf install -y jq"
    elif command -v yum >/dev/null 2>&1; then
      run_shell "sudo yum install -y jq"
    else
      echo "Warning: could not auto-install jq; trying python3 fallback" >&2
    fi
  fi

  # Parse model IDs with jq, falling back to python3.
  # `select(...)` drops null *and* empty-string IDs.
  MODEL_IDS=()
  if command -v jq >/dev/null 2>&1; then
    mapfile -t MODEL_IDS < <(jq -r '(.models[]?, .providers[]?.models[]?) | select(.id != null and .id != "") | .id' "$MODEL_JSON" 2>/dev/null | sort -u)
  elif command -v python3 >/dev/null 2>&1; then
    mapfile -t MODEL_IDS < <(python3 -c '
import json, sys
data = json.load(open(sys.argv[1]))
ids = []
for m in data.get("models", []):
    if m.get("id"):
        ids.append(m["id"])
for provider in data.get("providers", {}).values():
    for m in provider.get("models", []):
        if m.get("id"):
            ids.append(m["id"])
for mid in dict.fromkeys(ids):
    print(mid)
' "$MODEL_JSON" 2>/dev/null)
  else
    echo "Warning: neither jq nor python3 available; cannot parse models.json" >&2
  fi

  if [[ ${#MODEL_IDS[@]} -eq 0 ]]; then
    echo "No models found to install."
  else
    for MODEL_ID in "${MODEL_IDS[@]}"; do
      run pi install model "$MODEL_ID"
    done
  fi
else
  echo "No $MODEL_JSON found – skipping model installation."
fi

# ------------------------------------------------------------------
# 5. Apply configuration to Pi
# ------------------------------------------------------------------
if command -v pi >/dev/null 2>&1; then
  run pi config apply --source="$CONFIG_TARGET"
else
  echo "Warning: 'pi' not found – configuration will not be applied" >&2
fi

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry-run finished – no system changes were made."
else
  echo "Pi and Herdr installed, models and configuration applied."
fi
