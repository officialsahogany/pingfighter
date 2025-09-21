#!/bin/bash
# 자동 저장을 백그라운드에서 시작하는 스크립트

echo "🚀 자동 저장 시작 중..."

# 이미 실행 중인지 확인
if pgrep -f "auto_git_save" > /dev/null; then
    echo "⚠️  이미 실행 중입니다!"
    echo "종료하려면: ./stop_auto_save.sh"
    exit 1
fi

# 백그라운드 실행
nohup ./auto_git_save.sh > auto_save.log 2>&1 &
echo $! > auto_save.pid

echo "✅ 백그라운드에서 실행 중! (PID: $(cat auto_save.pid))"
echo "📄 로그 확인: tail -f auto_save.log"
echo "🛑 종료하려면: ./stop_auto_save.sh"