#!/usr/bin/env bash
set -euo pipefail

# context7 MCP 서버를 로컬 node_modules에서 실행한다.
API_KEY="${CONTEXT7_API_KEY:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/node_modules/@upstash/context7-mcp"
ENTRY_POINT="$PACKAGE_DIR/dist/index.js"

if [[ ! -f "$ENTRY_POINT" ]]; then
  echo "[context7] 실행 파일을 찾을 수 없습니다: $ENTRY_POINT" >&2
  echo "npm install --prefix mcp @upstash/context7-mcp" >&2
  exit 1
fi

if [[ -n "$API_KEY" ]]; then
  exec node "$ENTRY_POINT" --api-key "$API_KEY" "$@"
else
  exec node "$ENTRY_POINT" "$@"
fi
