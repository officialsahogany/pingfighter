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
        main_changes=""
        if git diff --cached --name-only | grep -q "pingfighter.py"; then
            main_changes="메인 게임 로직 업데이트"
        elif git diff --cached --name-only | grep -q "\.py$"; then
            main_changes="Python 코드 업데이트"
        else
            main_changes="프로젝트 파일 업데이트"
        fi
        
        # 커밋
        git commit -m "Auto-save #${commit_count}: ${main_changes} - ${timestamp}"
        
        # Push
        if git push origin feature/refactor-ui; then
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