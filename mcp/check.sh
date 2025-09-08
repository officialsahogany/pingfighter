#!/usr/bin/env bash
set -euo pipefail

ok() { printf "\033[32m[OK]\033[0m %s\n" "$*"; }
warn() { printf "\033[33m[WARN]\033[0m %s\n" "$*"; }
err() { printf "\033[31m[ERROR]\033[0m %s\n" "$*"; }

fail=0

if command -v node >/dev/null 2>&1; then ok "node $(node -v)"; else err "Node not found"; fail=1; fi
if command -v npx  >/dev/null 2>&1; then ok "npx $(npx -v)"; else err "npx not found"; fail=1; fi

need_env=(
  # uncomment those you need for a quick check
  # SLACK_BOT_TOKEN
  # YOUTUBE_API_KEY
)

for k in "${need_env[@]}"; do
  if [[ -z "${!k-}" ]]; then warn "$k not set"; else ok "$k present"; fi
done

if [[ $fail -ne 0 ]]; then exit 1; fi
ok "Environment looks good. Run: bash mcp/run.sh"

