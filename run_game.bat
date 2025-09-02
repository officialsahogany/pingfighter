@echo off
chcp 65001 > nul
title PingFighter - 핑파이터
echo ========================================
echo    핑파이터 (PingFighter) v1.0
echo    보스 배틀 아케이드 탁구 게임
echo ========================================
echo.
echo 게임을 시작합니다...
python pingfighter.py
if errorlevel 1 (
    echo.
    echo ❌ 게임 실행 중 오류가 발생했습니다.
    echo Python과 pygame이 설치되어 있는지 확인하세요.
    echo install_requirements.bat을 먼저 실행해주세요.
)
pause
