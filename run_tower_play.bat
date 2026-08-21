@echo off
REM 환격전 탑 등정 모드로 게임을 바로 실행한다 (에디터 없이).
setlocal
set "TOWER_ASCENT_VERTICAL_SLICE=1"
set "GODOT_EXE=C:\Users\woduq\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
    echo [run_tower_play] Godot 실행 파일을 찾을 수 없습니다:
    echo                  %GODOT_EXE%
    pause
    exit /b 1
)
echo [run_tower_play] TOWER_ASCENT_VERTICAL_SLICE=1
start "" "%GODOT_EXE%" --path "%~dp0godot" --
endlocal
