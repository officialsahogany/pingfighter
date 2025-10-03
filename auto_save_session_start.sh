#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

BASELINE_FILE=".git/auto_save_baseline"
PID_FILE="auto_save.pid"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "❌ 작업 트리에 미커밋 변경이 있습니다. 자동 저장을 시작하기 전에 정리해주세요." >&2
    exit 1
fi

if [ -f "$BASELINE_FILE" ]; then
    echo "⚠️ 기존 세션 기준점($BASELINE_FILE)이 덮어쓰기 됩니다." >&2
fi

baseline_hash=$(git rev-parse HEAD)
baseline_iso=$(git show -s --format='%cI' HEAD)
baseline_desc=$(git show -s --format='%s' HEAD)

{
    echo "$baseline_hash"
    echo "$baseline_iso"
    echo "$baseline_desc"
} > "$BASELINE_FILE"

echo "💾 세션 기준점을 저장했습니다: $baseline_hash ($baseline_iso)"

if [ -f "$PID_FILE" ]; then
    existing_pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [[ "$existing_pid" =~ ^[0-9]+$ ]] && kill -0 "$existing_pid" 2>/dev/null; then
        echo "ℹ️ 기존 자동 저장 프로세스(PID $existing_pid)를 정리합니다."
        ./stop_auto_save.sh >/dev/null 2>&1 || true
    else
        rm -f "$PID_FILE"
    fi
fi

./start_auto_save.sh

echo "✅ 자동 저장이 활성화되었습니다. 롤백은 ./auto_save_session_rollback.sh 로 수행하세요."
