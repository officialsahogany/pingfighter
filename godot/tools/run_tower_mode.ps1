# 탑 등정 모드로 게임을 실행하는 라이브 QA 런처.
# TOWER_ASCENT_VERTICAL_SLICE 플래그를 이 프로세스에만 켜고 윈도우드 게임을 띄운다.
# 사용법: PowerShell에서 ./tools/run_tower_mode.ps1  (또는 파일 우클릭 → PowerShell로 실행)
# 에디터·다른 실행에는 영향을 주지 않는다.

$ErrorActionPreference = 'Stop'

$godotCandidates = @(
    'C:\Users\woduq\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe'
)
$godot = $godotCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $godot) {
    throw "Godot 실행 파일을 찾지 못했습니다: $($godotCandidates -join ', ')"
}

$projectPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'project.godot'
if (-not (Test-Path $projectPath)) {
    throw "project.godot 을 찾지 못했습니다: $projectPath"
}

$env:TOWER_ASCENT_VERTICAL_SLICE = '1'
Write-Host "탑 등정 모드 플래그 ON — 게임을 시작합니다." -ForegroundColor Green
& $godot --path (Split-Path $projectPath -Parent)
