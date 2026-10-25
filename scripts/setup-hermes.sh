#!/bin/bash
# setup-hermes.sh — Hermes Agent on the Mac runner
#
#   1. Installs Hermes Agent from the official installer
#   2. Serves it on the Tailscale tailnet (port 9119) so a phone can reach it
#   3. Clones kosaai/hermex onto the visible Desktop
#
# Safe to run on a fresh runner: every step warns instead of aborting.
# Hermes still needs its own sign-in (Nous Portal + a model) before it can run.

set -uo pipefail

HERMEX_REPO="https://github.com/kosaai/hermex.git"
DESKTOP="/Users/runner/Desktop"
HERMES_PORT="${HERMES_PORT:-9119}"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "             🤖 HERMES AGENT SETUP"
echo "════════════════════════════════════════════════════════════"
echo ""

# ── 1. Hermes Agent ────────────────────────────────────────────────
echo "📦 [1/3] Installing Hermes Agent..."
if command -v hermes >/dev/null 2>&1; then
  echo "    ✅ Already installed: $(hermes --version 2>/dev/null || echo unknown)"
else
  if curl -fsSL --max-time 180 https://hermes-agent.nousresearch.com/install.sh | bash; then
    echo "    ✅ Installed"
  else
    echo "    ⚠️  Install failed (network or Cloudflare block) — continuing"
  fi
fi
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
if command -v hermes >/dev/null 2>&1; then
  echo "    Version: $(hermes --version 2>/dev/null || echo unknown)"
else
  echo "    ⚠️  'hermes' not on PATH — run: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ── 2. Tailscale ───────────────────────────────────────────────────
echo ""
echo "🔗 [2/3] Exposing Hermes on the tailnet (port ${HERMES_PORT})..."
TS="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
if [ ! -x "$TS" ]; then TS="$(command -v tailscale || true)"; fi

if [ -n "$TS" ] && [ -x "$TS" ]; then
  "$TS" serve --bg "${HERMES_PORT}" 2>&1 | head -5 || true
  sleep 3
  echo "    serve status:"
  "$TS" serve status 2>&1 | head -8 | sed 's/^/      /' || true
  HERMES_URL="$("$TS" serve status 2>/dev/null | grep -oE 'https://[^ ]+' | head -1)"
  [ -n "${HERMES_URL:-}" ] && echo "    ✅ ${HERMES_URL}" || true
else
  echo "    ⚠️  tailscale CLI not found — skipping (run: tailscale serve --bg ${HERMES_PORT})"
fi

# ── 3. Hermex on the Desktop ───────────────────────────────────────
echo ""
echo "📱 [3/3] Cloning Hermex to the Desktop..."
DEST="${DESKTOP}/hermex"
if [ -d "$DEST/.git" ]; then
  echo "    ✅ Already present: $DEST"
else
  mkdir -p "$DESKTOP" 2>/dev/null || true
  if git clone --depth 1 "$HERMEX_REPO" "$DEST" 2>&1 | tail -3; then
    echo "    ✅ Cloned to $DEST"
  else
    echo "    ⚠️  Clone failed"
  fi
fi
ls -d "$DEST" >/dev/null 2>&1 && echo "    📂 $DEST" || true

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Hermes still needs its own sign-in:"
echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
echo "    hermes auth add nous      # Nous Portal"
echo "    hermes model              # pick a provider + model"
echo "════════════════════════════════════════════════════════════"
echo ""
