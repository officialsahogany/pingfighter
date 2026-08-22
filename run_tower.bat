@echo off
REM 환격전 탑 등정 모드로 Godot 에디터를 켠다 (-e). 에디터에서 F5 로 돌리면 탑 모드가 상속된다.
REM 탑은 본 프로젝트의 기본값이며, 이 런처는 환경변수도 명시해 이중으로 보장한다.
setlocal
set "TOWER_ASCENT_VERTICAL_SLICE=1"
set "GODOT_EXE=C:\Users\woduq\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
    echo [run_tower] Godot 실행 파일을 찾을 수 없습니다:
    echo             %GODOT_EXE%
    echo             경로가 바뀌었으면 이 파일의 GODOT_EXE 를 고치세요.
    pause
    exit /b 1
)
echo [run_tower] TOWER_ASCENT_VERTICAL_SLICE=1
start "" "%GODOT_EXE%" -e --path "%~dp0godot"
endlocal
