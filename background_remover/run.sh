#!/bin/bash
# 누끼 따기 프로그램 실행 스크립트 (macOS/Linux)

cd "$(dirname "$0")"

# 가상환경 확인
if [ ! -d "venv" ]; then
    echo "가상환경 생성 중..."
    python3 -m venv venv
    source venv/bin/activate
    echo "의존성 설치 중..."
    pip install --upgrade pip
    pip install rembg Pillow
else
    source venv/bin/activate
fi

echo "누끼 따기 프로그램 시작..."
python remover.py
