#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

BASELINE_FILE=".git/auto_save_baseline"
PID_FILE="auto_save.pid"

if [ -f "$BASELINE_FILE" ]; then
    baseline_hash=$(sed -n '1p' "$BASELINE_FILE")
    baseline_iso=$(sed -n '2p' "$BASELINE_FILE")
    baseline_desc=$(sed -n '3p' "$BASELINE_FILE")
    echo "📌 세션 기준점: $baseline_hash"
    [ -n "$baseline_iso" ] && echo "   기록 시각: $baseline_iso"
    [ -n "$baseline_desc" ] && echo "   메시지: $baseline_desc"
else
    echo "📌 세션 기준점이 설정되지 않았습니다. ./auto_save_session_start.sh 로 생성하세요."
fi

if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [[ "$pid" =~ ^[0-9]+$ ]]; then
        if kill -0 "$pid" 2>/dev/null || ps -p "$pid" >/dev/null 2>&1; then
            echo "🚀 자동 저장 실행 중 (PID: $pid)"
        else
            echo "⚠️ PID $pid 정보를 확인할 수 없습니다. 권한 문제일 수 있으니 필요 시 관리자 권한으로 ./stop_auto_save.sh 실행 후 재시작하세요."
        fi
    else
        echo "⚠️ PID 파일이 손상되었습니다. 필요 시 ./stop_auto_save.sh 실행 후 삭제하세요."
    fi
else
    echo "🛑 자동 저장이 실행 중이 아닙니다. ./auto_save_session_start.sh 로 시작할 수 있습니다."
fi
