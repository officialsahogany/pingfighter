#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

BASELINE_FILE=".git/auto_save_baseline"
PID_FILE="auto_save.pid"

if [ ! -f "$BASELINE_FILE" ]; then
    echo "❌ 저장된 세션 기준점이 없습니다. 먼저 ./auto_save_session_start.sh 를 실행해 주세요." >&2
    exit 1
fi

baseline_hash=$(sed -n '1p' "$BASELINE_FILE")
baseline_iso=$(sed -n '2p' "$BASELINE_FILE" || true)
baseline_desc=$(sed -n '3p' "$BASELINE_FILE" || true)

if [ -z "$baseline_hash" ]; then
    echo "❌ 기준점 파일이 손상되었습니다. 수동으로 확인하세요: $BASELINE_FILE" >&2
    exit 1
fi

echo "🛑 자동 저장 프로세스를 중지합니다."
if ! ./stop_auto_save.sh >/dev/null 2>&1; then
    echo "⚠️ 자동 저장 프로세스를 완전히 중지하지 못했습니다. 관리자 권한으로 다시 실행하세요." >&2
fi

if [ -f "$PID_FILE" ]; then
    pid_check=$(cat "$PID_FILE" 2>/dev/null || true)
    if [[ "$pid_check" =~ ^[0-9]+$ ]] && (kill -0 "$pid_check" 2>/dev/null || ps -p "$pid_check" >/dev/null 2>&1); then
        echo "❌ 자동 저장이 아직 실행 중입니다. 권한이 필요한 경우 'sudo ./stop_auto_save.sh' 등으로 먼저 종료하세요." >&2
        exit 1
    fi
fi

if git rev-parse --verify "$baseline_hash" >/dev/null 2>&1; then
    echo "↩️  $baseline_hash 기준으로 워크트리를 복원합니다."
    git reset --hard "$baseline_hash"
else
    echo "❌ 기준점 커밋을 찾을 수 없습니다: $baseline_hash" >&2
    exit 1
fi

rm -f "$BASELINE_FILE"

echo "✅ 롤백 완료: $baseline_hash"
[ -n "$baseline_iso" ] && echo "   기록된 시간: $baseline_iso"
[ -n "$baseline_desc" ] && echo "   커밋 메시지: $baseline_desc"

echo "ℹ️ 자동 저장을 다시 시작하려면 ./auto_save_session_start.sh 를 실행하세요."
