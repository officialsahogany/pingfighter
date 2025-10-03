#!/bin/bash

echo "GitHub Token 설정 스크립트"
echo "========================"
echo ""
read -p "GitHub Token을 입력하세요 (ghp_로 시작): " TOKEN

if [[ $TOKEN == ghp_* ]]; then
    echo "토큰 확인됨. Git 설정 중..."
    git remote set-url origin https://officialsahogany:$TOKEN@github.com/officialsahogany/pingfighter.git
    echo "✅ 설정 완료!"

    echo ""
    echo "테스트 중..."
    git push --dry-run

    if [ $? -eq 0 ]; then
        echo "✅ 인증 성공! 자동 저장이 정상 작동합니다."
    else
        echo "❌ 인증 실패. 토큰을 확인해주세요."
    fi
else
    echo "❌ 올바른 토큰 형식이 아닙니다. (ghp_로 시작해야 함)"
fi