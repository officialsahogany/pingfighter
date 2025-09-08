#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$HERE/mcp.config.json"

# Load local env (not committed) if present
if [[ -f "$HERE/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$HERE/.env"
  set +a
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "[ERROR] npx not found. Install Node.js (>=18) first." >&2
  exit 1
fi

echo "[INFO] Starting MCP client with config: $CONFIG"
echo "[INFO] Tip: export API keys (e.g., SLACK_BOT_TOKEN, YOUTUBE_API_KEY) or place them in mcp/.env"

# Expand ${VARS} in JSON to concrete values when envsubst is available
if command -v envsubst >/dev/null 2>&1; then
  TMPCFG="$(mktemp -t mcp_cfg.XXXXXX)"
  trap 'rm -f "$TMPCFG"' EXIT
  envsubst < "$CONFIG" > "$TMPCFG"
  exec npx -y @modelcontextprotocol/cli --config "$TMPCFG"
else
  echo "[WARN] envsubst not found; using raw config (expects CLI to resolve env)." >&2
  exec npx -y @modelcontextprotocol/cli --config "$CONFIG"
fi
