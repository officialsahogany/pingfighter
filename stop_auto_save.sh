#!/bin/bash
# 자동 저장 중지 스크립트

if [ -f auto_save.pid ]; then
    PID=$(cat auto_save.pid)
    if kill -0 $PID 2>/dev/null; then
        kill $PID
        echo "✅ 자동 저장이 중지되었습니다!"
        rm auto_save.pid
    else
        echo "⚠️  프로세스가 실행 중이 아닙니다."
        rm auto_save.pid
    fi
else
    # PID 파일이 없으면 프로세스 이름으로 찾기
    if pgrep -f "auto_git_save" > /dev/null; then
        pkill -f "auto_git_save"
        echo "✅ 자동 저장이 중지되었습니다!"
    else
        echo "❌ 실행 중인 자동 저장이 없습니다."
    fi
fi