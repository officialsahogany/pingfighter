@echo off
chcp 65001 > nul
title PingFighter - 패키지 설치
echo ========================================
echo    PingFighter 필수 패키지 설치
echo ========================================
echo.

REM 가상환경 생성
if not exist .venv_win (
    echo 가상환경 생성 중...
    python -m venv .venv_win
    if errorlevel 1 (
        echo ❌ 가상환경 생성 실패!
        pause
        exit /b 1
    )
    echo ✅ 가상환경 생성 완료!
    echo.
)

REM Python 버전 확인
echo Python 버전 확인...
if exist .venv_win\Scripts\python.exe (
    .venv_win\Scripts\python.exe --version
    echo 가상환경 사용: .venv_win
) else (
    python --version
    echo 시스템 Python 사용
)
echo.

REM 패키지 설치
echo 필수 패키지 설치 중... (시간이 걸릴 수 있습니다)
if exist .venv_win\Scripts\pip.exe (
    .venv_win\Scripts\pip.exe install -r requirements.txt
) else (
    pip install -r requirements.txt
)

if errorlevel 1 (
    echo.
    echo ❌ 패키지 설치 중 오류가 발생했습니다.
    pause
    exit /b 1
)

echo.
echo ✅ 모든 패키지 설치 완료!
echo run_game.bat을 실행하여 게임을 시작하세요.
pause
