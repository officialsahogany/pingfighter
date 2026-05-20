@echo off
REM PingFighter Godot - SteamPipe upload helper.
REM Usage:
REM   steam\upload_godot_steam.bat <steam_account>
REM
REM Before real upload, replace AppID/DepotID in:
REM   steam\app_build_godot.vdf
REM   steam\depot_build_godot_windows.vdf
REM
REM app_build_godot.vdf uses Preview="1" by default for a dry run.
REM Change it to "0" only when the SteamPipe preview looks correct.

chcp 65001 >nul
setlocal

if "%~1"=="" (
    echo Usage: %~nx0 ^<steam_account^>
    exit /b 1
)

set STEAM_ACCOUNT=%~1

where steamcmd.exe >nul 2>nul
if errorlevel 1 (
    if exist "C:\steamworks\sdk\tools\ContentBuilder\builder\steamcmd.exe" (
        set STEAMCMD="C:\steamworks\sdk\tools\ContentBuilder\builder\steamcmd.exe"
    ) else (
        echo [ERROR] steamcmd.exe was not found.
        echo Install Steamworks SDK or add steamcmd.exe to PATH.
        exit /b 1
    )
) else (
    set STEAMCMD=steamcmd.exe
)

pushd "%~dp0.."

if not exist "dist\PingFighter_Godot_Steam\PingFighter.exe" (
    echo [ERROR] dist\PingFighter_Godot_Steam\PingFighter.exe is missing.
    popd
    endlocal
    exit /b 1
)

if not exist "dist\PingFighter_Godot_Steam\PingFighter.pck" (
    echo [ERROR] dist\PingFighter_Godot_Steam\PingFighter.pck is missing.
    popd
    endlocal
    exit /b 1
)

echo.
echo === SteamPipe Godot upload/preview (account: %STEAM_ACCOUNT%) ===
%STEAMCMD% +login %STEAM_ACCOUNT% +run_app_build "%CD%\steam\app_build_godot.vdf" +quit

popd
endlocal
