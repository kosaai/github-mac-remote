
#!/usr/bin/env bash
set -Eeuo pipefail

echo "========================================"
echo " Hermes Agent - Installation Only"
echo "========================================"

# 1. Verify the operating system
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: This installer requires macOS."
  exit 1
fi

echo "[1/5] macOS detected"
sw_vers

# 2. Verify required tools
for tool in git curl bash; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: Required tool is missing: $tool"
    exit 1
  fi
done

echo "[2/5] Required tools are available"
git --version
curl --version | head -n 1

# 3. Download the official installer
INSTALLER="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/hermes-official-install.sh"

echo "[3/5] Downloading the official Hermes installer..."
curl --fail --show-error --silent --location \
  --connect-timeout 20 \
  --max-time 180 \
  https://hermes-agent.nousresearch.com/install.sh \
  --output "$INSTALLER"

if [[ ! -s "$INSTALLER" ]]; then
  echo "ERROR: The downloaded installer is empty."
  exit 1
fi

# 4. Install Hermes
echo "[4/5] Running the official installer..."
bash "$INSTALLER"

# Make Hermes available in subsequent GitHub Actions steps.
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$HOME/.local/bin" >> "$GITHUB_PATH"
  echo "$HOME/.hermes/bin" >> "$GITHUB_PATH"
fi

# 5. Verify the actual installation
echo "[5/5] Verifying Hermes..."

if ! command -v hermes >/dev/null 2>&1; then
  echo "ERROR: Installation finished, but the hermes command was not found."
  exit 1
fi

if ! hermes --version; then
  echo "ERROR: Hermes is installed but its version check failed."
  exit 1
fi

echo ""
echo "SUCCESS: Hermes Agent is installed and its CLI responds."
echo "No authentication, server, or Tailscale changes were made."
