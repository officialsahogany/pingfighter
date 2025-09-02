@echo off
chcp 65001 > nul
title PingFighter - 패키지 설치
echo ========================================
echo    PingFighter 필수 패키지 설치
echo ========================================
echo.
echo Python 버전 확인...
python --version
echo.
echo pygame 설치 중...
pip install pygame
echo.
echo ✅ 설치 완료!
echo run_game.bat을 실행하여 게임을 시작하세요.
pause
