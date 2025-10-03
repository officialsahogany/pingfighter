#!/bin/bash

# Real-time Auto Git Save Script using fswatch
# 파일 변경 즉시 감지하여 git commit & push

echo "🚀 PingFighter 실시간 자동 저장 시스템"
echo "📁 모니터링: *.py 파일"
echo "⚡ 실시간 감지 모드"
echo "----------------------------------------"

# fswatch 설치 확인
if ! command -v fswatch &> /dev/null; then
    echo "⚠️  fswatch가 설치되어 있지 않습니다."
    echo "설치하려면: brew install fswatch"
    echo ""
    echo "대신 30초 간격 모드로 전환합니다..."
    ./auto_git_save.sh
    exit 1
fi

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 마지막 커밋 시간 (중복 방지)
last_commit_time=0
commit_count=0

# 파일 변경 감지 함수
handle_change() {
    current_time=$(date +%s)
    
    # 5초 내 중복 커밋 방지
    if (( current_time - last_commit_time < 5 )); then
        return
    fi
    
    # Git 상태 확인
    if [[ $(git status --porcelain) ]]; then
        echo -e "\n${YELLOW}📝 파일 변경 감지!${NC}"
        
        # 변경 파일 표시
        changed_files=$(git status --short)
        echo "$changed_files"
        
        # 주요 변경사항 분석
        if echo "$changed_files" | grep -q "pingfighter.py"; then
            change_type="🎮 메인 게임 로직"
        elif echo "$changed_files" | grep -q "supply_drop.py"; then
            change_type="📦 보급 시스템"
        elif echo "$changed_files" | grep -q "supply_aircraft"; then
            change_type="✈️ 보급기 디자인"
        elif echo "$changed_files" | grep -q "item_effects/"; then
            change_type="💎 아이템 효과"
        else
            change_type="🔧 코드 업데이트"
        fi
        
        # Git 저장
        git add -A
        
        commit_count=$((commit_count + 1))
        timestamp=$(date '+%H:%M:%S')
        
        # 커밋 메시지
        git commit -m "Auto-save #${commit_count}: ${change_type} - ${timestamp}"
        
        # Push (백그라운드)
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        if [ -z "$current_branch" ]; then
            echo "❌ 현재 브랜치를 확인할 수 없습니다. 자동 저장을 중단합니다."
            exit 1
        fi
        remote_name="${AUTO_GIT_REMOTE:-origin}"
        git push "$remote_name" "$current_branch" &
        push_pid=$!
        
        # Push 완료 대기 (최대 5초)
        timeout=5
        while (( timeout > 0 )) && kill -0 $push_pid 2>/dev/null; do
            sleep 0.5
            ((timeout--))
        done
        
        if ! kill -0 $push_pid 2>/dev/null; then
            echo -e "${GREEN}✅ 저장 완료! (${change_type})${NC}"
            afplay /System/Library/Sounds/Funk.aiff &
        else
            echo "⏳ Push 진행 중..."
        fi
        
        last_commit_time=$current_time
        echo -e "${BLUE}총 자동 저장: ${commit_count}회${NC}"
        echo "----------------------------------------"
    fi
}

echo -e "${GREEN}✨ 실시간 모니터링 시작!${NC}"
echo "종료: Ctrl+C"
echo ""

# fswatch로 파일 감지
fswatch -r -e ".*" -i "\\.py$" -i "\\.txt$" \
    --exclude ".git" \
    --exclude "__pycache__" \
    --exclude ".pyc" \
    /Volumes/T7/윈도우용최신/game/bosspong/ | while read path; do
    handle_change
done