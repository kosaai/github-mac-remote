#!/usr/bin/env bash
set -Eeuo pipefail

export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"

DESKTOP="$HOME/Desktop"
mkdir -p "$DESKTOP"
LOG="$DESKTOP/Hermes-Install-Auth.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== Hermes installation and authentication ==="
date

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: This script requires macOS."
  exit 1
fi

# Check the required Git dependency.
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: Git is missing. Install Apple's Command Line Tools first."
  exit 1
fi

# Install Hermes only if the CLI is not already available.
if ! command -v hermes >/dev/null 2>&1; then
  echo "Installing Hermes from the official installer..."
  curl -fsSL --connect-timeout 20 --max-time 300 \
    https://hermes-agent.nousresearch.com/install.sh \
    -o "${TMPDIR:-/tmp}/hermes-install.sh"
  bash "${TMPDIR:-/tmp}/hermes-install.sh"
  export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
fi

if ! command -v hermes >/dev/null 2>&1; then
  echo "ERROR: Hermes CLI was not found after installation."
  exit 1
fi

echo "Hermes version:"
hermes --version

# Try to open Chrome explicitly if installed.
open_chrome() {
  local url="$1"
  if [[ -d "/Applications/Google Chrome.app" ]]; then
    open -a "Google Chrome" "$url" || true
  elif [[ -d "$HOME/Applications/Google Chrome.app" ]]; then
    open -a "$HOME/Applications/Google Chrome.app" "$url" || true
  else
    echo "Chrome app not found in standard Applications folders."
    echo "Hermes may use the macOS default browser instead."
  fi
}

echo "Opening the Nous Portal subscription page in Chrome..."
open_chrome "https://portal.nousresearch.com/manage-subscription"

echo ""
echo "Starting official Hermes Portal setup."
echo "Complete the login and model selection in the browser/terminal."
echo "If OAuth opens a URL, use Chrome on this Mac runner."
echo ""

# The official command performs OAuth and provider setup.
hermes setup --portal

echo ""
echo "Checking Portal authentication status..."
if hermes portal info; then
  echo "Portal status command completed."
else
  echo "WARNING: Portal status did not confirm authentication."
  echo "Check the output above and this log: $LOG"
  exit 1
fi

echo ""
echo "Finished. Log saved at: $LOG"
