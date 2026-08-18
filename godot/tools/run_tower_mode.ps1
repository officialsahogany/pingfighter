# 탑 등정 모드로 게임을 실행하는 라이브 QA 런처.
# TOWER_ASCENT_VERTICAL_SLICE 플래그를 이 프로세스에만 켜고 윈도우드 게임을 띄운다.
# 사용법: PowerShell에서 ./tools/run_tower_mode.ps1  (또는 파일 우클릭 → PowerShell로 실행)
# 에디터·다른 실행에는 영향을 주지 않는다.

param(
    [ValidateSet(
        "",
        "floor_02_molewang",
        "floor_02_arachne",
        "floor_03_teddy_bear",
        "floor_03_alice"
    )]
    [string]$ReplayBossSlot = "",
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = 'Stop'

if ($ReplayBossSlot) {
    $previousTowerFlag = [Environment]::GetEnvironmentVariable(
        "TOWER_ASCENT_VERTICAL_SLICE",
        "Process"
    )
    try {
        $env:TOWER_ASCENT_VERTICAL_SLICE = '1'
        & (Join-Path $PSScriptRoot "run_tower_ascent_boss_entry_visual_qa.ps1") `
            -SlotId $ReplayBossSlot `
            -GodotExe $GodotExe `
            -ProjectPath $ProjectPath
        if ($LASTEXITCODE -ne 0) {
            throw "Tower mode live replay failed: $ReplayBossSlot"
        }
        Write-Host "Tower mode live replay passed: $ReplayBossSlot" -ForegroundColor Green
    }
    finally {
        if ($null -eq $previousTowerFlag) {
            [Environment]::SetEnvironmentVariable(
                "TOWER_ASCENT_VERTICAL_SLICE",
                $null,
                "Process"
            )
        }
        else {
            $env:TOWER_ASCENT_VERTICAL_SLICE = $previousTowerFlag
        }
    }
    exit 0
}

$godotCandidates = @(
    'C:\Users\woduq\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe'
)
$godot = $godotCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $godot) {
    throw "Godot 실행 파일을 찾지 못했습니다: $($godotCandidates -join ', ')"
}

$projectFilePath = Join-Path $ProjectPath 'project.godot'
if (-not (Test-Path $projectFilePath)) {
    throw "project.godot 을 찾지 못했습니다: $projectFilePath"
}

$env:TOWER_ASCENT_VERTICAL_SLICE = '1'
Write-Host "탑 등정 모드 플래그 ON — 게임을 시작합니다." -ForegroundColor Green
& $godot --path $ProjectPath
