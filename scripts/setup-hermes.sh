#!/bin/bash
# setup-hermes.sh — Hermes Agent on the Mac runner
#
#   1. Installs Hermes Agent from the official installer
#   2. Starts the REAL backend server (hermes serve) on 127.0.0.1:9119
#   3. Tunnels it over Tailscale so a phone can reach it
#   4. Clones kosaai/hermex onto the visible Desktop
#
# Safe to run on a fresh runner: every step warns instead of aborting.
# Hermes still needs its own sign-in (Nous Portal + a model) before it can
# serve traffic — see the note at the end.

set -uo pipefail

HERMEX_REPO="https://github.com/kosaai/hermex.git"
DESKTOP="/Users/runner/Desktop"
HERMES_PORT="${HERMES_PORT:-9119}"
HERMES_HOST="127.0.0.1"
LOG_FILE="$HOME/hermes-serve.log"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "             🤖 HERMES AGENT SETUP"
echo "════════════════════════════════════════════════════════════"
echo ""

# ── 1. Hermes Agent ────────────────────────────────────────────────
echo "📦 [1/4] Installing Hermes Agent..."
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
  exit 0
fi

# ── 2. The real backend server ─────────────────────────────────────
# `hermes serve` is the JSON-RPC/WebSocket gateway the desktop app and
# remote clients connect to. Without it nothing listens on the port.
echo ""
echo "🚀 [2/4] Starting Hermes backend server on ${HERMES_HOST}:${HERMES_PORT}..."

# Free the port from any previous instance.
hermes serve --stop >/dev/null 2>&1 || true
lsof -ti tcp:"${HERMES_PORT}" 2>/dev/null | xargs -r kill -9 2>/dev/null || true
sleep 1

nohup hermes serve --port "${HERMES_PORT}" --host "${HERMES_HOST}" --skip-build \
  >"${LOG_FILE}" 2>&1 &
SERVER_PID=$!
echo "    PID: ${SERVER_PID}"
echo "    Log: ${LOG_FILE}"

# Wait for it to actually accept connections.
UP=0
for _ in $(seq 1 30); do
  if lsof -iTCP:"${HERMES_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then UP=1; break; fi
  if ! kill -0 "${SERVER_PID}" >/dev/null 2>&1; then break; fi
  sleep 1
done

if [ "$UP" = "1" ]; then
  echo "    ✅ Server is listening on ${HERMES_HOST}:${HERMES_PORT}"
  curl -fsS --max-time 5 "http://${HERMES_HOST}:${HERMES_PORT}/api/status" 2>/dev/null \
    | head -c 200 && echo "" || true
else
  echo "    ⚠️  Server is NOT listening — likely missing sign-in (Nous Portal + model)."
  echo "       Last log lines:"
  tail -5 "${LOG_FILE}" 2>/dev/null | sed 's/^/       /' || true
fi

# ── 3. Tailscale tunnel ────────────────────────────────────────────
# `serve` keeps the port inside the tailnet. Binding to 127.0.0.1 plus a
# Tailscale tunnel is the supported way to keep it off the public internet:
# `hermes serve --insecure` is a deprecated no-op and no longer bypasses auth.
echo ""
echo "🔗 [3/4] Tunnelling Hermes over Tailscale (port ${HERMES_PORT})..."
TS="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
if [ ! -x "$TS" ]; then TS="$(command -v tailscale || true)"; fi

if [ -n "$TS" ] && [ -x "$TS" ]; then
  "$TS" serve --bg "${HERMES_PORT}" 2>&1 | head -5 || true
  sleep 3
  echo "    serve status:"
  "$TS" serve status 2>&1 | head -8 | sed 's/^/      /' || true
  # Pick the URL whose own port is ${HERMES_PORT}. `serve status` lists every
  # route, so taking the first https URL can return a different service.
  HERMES_URL="$("$TS" serve status 2>/dev/null \
    | grep -oE 'https://[^[:space:]]+' \
    | grep -E ":${HERMES_PORT}([[:space:]]|\$)" \
    | head -1)"
  if [ -n "${HERMES_URL:-}" ]; then
    echo "    ✅ ${HERMES_URL}"
  else
    echo "    ⚠️  Could not read the serve URL for port ${HERMES_PORT}"
  fi
else
  echo "    ⚠️  tailscale CLI not found — run: tailscale serve --bg ${HERMES_PORT}"
fi

# ── 4. Hermex on the Desktop ───────────────────────────────────────
echo ""
echo "📱 [4/4] Cloning Hermex to the Desktop..."
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
echo "  Finish sign-in before the server can serve traffic:"
echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
echo "    hermes auth add nous      # Nous Portal"
echo "    hermes model              # pick a provider + model"
echo "    hermes serve --port ${HERMES_PORT}   # restart after sign-in"
echo "════════════════════════════════════════════════════════════"
echo ""
