@echo off
chcp 65001 >nul
title 누끼 따기 프로그램

cd /d "%~dp0"

REM 가상환경 확인
if not exist "venv" (
    echo 가상환경 생성 중...
    python -m venv venv
    call venv\Scripts\activate.bat
    echo 의존성 설치 중...
    pip install --upgrade pip
    pip install rembg Pillow
) else (
    call venv\Scripts\activate.bat
)

echo 누끼 따기 프로그램 시작...
python remover.py

pause
