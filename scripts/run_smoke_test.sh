#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR%/scripts}"

export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-dummy}"
export PINGFIGHTER_MODERN_LOOP=1
export PINGFIGHTER_SMOKE_TEST=1

python3 "$PROJECT_ROOT/pingfighter.py" --modern-loop --smoke-test "$@"
