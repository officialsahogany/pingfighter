#!/bin/bash
# 자동 저장을 백그라운드에서 시작하는 스크립트

echo "🚀 자동 저장 시작 중..."

# 이미 실행 중인지 확인
pid_file="auto_save.pid"

if [ -f "$pid_file" ]; then
    existing_pid=$(cat "$pid_file" 2>/dev/null)
    if [[ "$existing_pid" =~ ^[0-9]+$ ]] && kill -0 "$existing_pid" 2>/dev/null; then
        echo "⚠️  이미 실행 중입니다! (PID: $existing_pid)"
        echo "종료하려면: ./stop_auto_save.sh"
        exit 0
    else
        rm -f "$pid_file"
    fi
fi

if pgrep -f "[a]uto_git_save.sh" >/dev/null 2>&1; then
    echo "⚠️  이미 실행 중입니다!"
    echo "종료하려면: ./stop_auto_save.sh"
    exit 0
fi

# 백그라운드 실행
nohup ./auto_git_save.sh > auto_save.log 2>&1 &
echo $! > "$pid_file"

echo "✅ 백그라운드에서 실행 중! (PID: $(cat "$pid_file"))"
echo "📄 로그 확인: tail -f auto_save.log"
echo "🛑 종료하려면: ./stop_auto_save.sh"
