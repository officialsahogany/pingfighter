#!/bin/bash

# Auto Git Save Script for PingFighter
# 파일 변경 감지 시 자동으로 git commit & push

echo "🚀 PingFighter 자동 저장 시스템 시작!"
echo "📁 모니터링 디렉토리: $(pwd)"
echo "⏱️  체크 간격: 30초"
echo "🔔 알림음: Funk.aiff"
echo "----------------------------------------"
echo "종료하려면 Ctrl+C를 누르세요"
echo ""

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 카운터 초기화
commit_count=0
note_file="auto_git_note.txt"

while true; do
    # Git 상태 체크
    if [[ $(git status --porcelain) ]]; then
        echo -e "${YELLOW}📝 변경사항 감지!${NC}"
        
        # 변경된 파일 목록 표시
        echo "변경된 파일:"
        git status --short
        
        # Git 저장
        git add -A
        
        # 현재 시간과 커밋 메시지 생성
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        commit_count=$((commit_count + 1))
        
        # 주요 변경 파일 확인
        summary_key=""
        if git diff --cached --name-only | grep -q "pingfighter.py"; then
            summary_key="메인 게임 로직 작업"
        elif git diff --cached --name-only | grep -q "\.py$"; then
            summary_key="Python 코드 작업"
        else
            summary_key="프로젝트 파일 작업"
        fi
        
        user_note=""
        if [ -s "$note_file" ]; then
            user_note=$(head -n1 "$note_file" | tr -d '\r')
            : > "$note_file"
        fi

        summary="$summary_key"
        if [ -n "$user_note" ]; then
            summary="$user_note"
        fi
        if [ -z "$summary" ]; then
            summary="자동 저장 작업"
        fi

        brief_time=$(date '+%H:%M')
        brief_line="▌${brief_time} - ${summary}"
        echo "$brief_line"

        printf -v commit_message 'Auto-save #%s: %s - %s' "$commit_count" "$summary" "$timestamp"

        # 커밋
        git commit -m "$commit_message"
        
        # Push
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        if [ -z "$current_branch" ]; then
            echo "❌ 현재 브랜치를 확인할 수 없습니다. 저장을 종료합니다."
            exit 1
        fi
        remote_name="${AUTO_GIT_REMOTE:-origin}"
        if git push "$remote_name" "$current_branch"; then
            echo -e "${GREEN}✅ GitHub에 푸시 완료!${NC}"
            
            # 성공 알림음
            afplay /System/Library/Sounds/Funk.aiff
            
            echo -e "${GREEN}💾 자동 저장 완료! (총 ${commit_count}회)${NC}"
        else
            echo "❌ Push 실패! 네트워크를 확인하세요."
            # 에러 알림음
            afplay /System/Library/Sounds/Basso.aiff
        fi
        
        echo "----------------------------------------"
    fi
    
    # 30초 대기 (진행 표시)
    echo -n "다음 체크까지: "
    for i in {30..1}; do
        printf "\r다음 체크까지: %02d초" $i
        sleep 1
    done
    echo -e "\r체크 중...                    "
done