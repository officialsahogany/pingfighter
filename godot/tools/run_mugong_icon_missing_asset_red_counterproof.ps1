param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
$validationPriorityContext = $null
$candidate = $null
$probePath = ""
try {
    $validationPriorityContext = Assert-NoInteractiveGodotGame `
        -ProjectPath $ProjectPath `
        -OperationName "Mugong icon missing-asset RED counterproof" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $resolvedProject = (Resolve-Path -LiteralPath $ProjectPath).Path
    $iconDir = Join-Path $resolvedProject "assets\sprites\perks"
    $resolvedIconDir = (Resolve-Path -LiteralPath $iconDir).Path
    if (-not $resolvedIconDir.StartsWith($resolvedProject, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Resolved icon directory escaped the requested project: $resolvedIconDir"
    }
    $candidate = Get-ChildItem -LiteralPath $resolvedIconDir -File -Filter "*_mugong_icon.png" |
        Sort-Object Name |
        Select-Object -First 1
    if ($null -eq $candidate) {
        throw "No Mugong icon PNG was available for the RED counterproof"
    }
    if (-not $candidate.FullName.StartsWith($resolvedIconDir, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Resolved RED counterproof target escaped the icon directory: $($candidate.FullName)"
    }

    $probePath = "$($candidate.FullName).codex-red-probe-$PID"
    $logDir = Join-Path $resolvedProject ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("mugong_icon_missing_asset_red_{0}_{1}.log" -f $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))
    Move-Item -LiteralPath $candidate.FullName -Destination $probePath
    try {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $output = & $godot `
                --headless `
                --path $resolvedProject `
                --log-file $logPath `
                -s res://tests/runtime_perk_general_icon_static_smoke.gd 2>&1
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        $output | ForEach-Object { Write-Host $_ }
        $outputText = ($output | Out-String)
        $expectedFailure = "$($candidate.BaseName -replace '_mugong_icon$', '') filesystem-discovered Mugong source PNG should exist"
        if ($exitCode -eq 0) {
            throw "Missing-asset counterproof stayed GREEN after temporarily removing $($candidate.Name)"
        }
        if (-not $outputText.Contains($expectedFailure)) {
            throw "Missing-asset counterproof failed for an unrelated reason; expected: $expectedFailure"
        }
        Write-Host "Mugong icon missing-asset RED counterproof passed: $($candidate.Name)"
        Write-Host "Counterproof log preserved: $logPath"
    }
    finally {
        if (Test-Path -LiteralPath $probePath -PathType Leaf) {
            Move-Item -LiteralPath $probePath -Destination $candidate.FullName
        }
    }
}
finally {
    if ($probePath -ne "" -and (Test-Path -LiteralPath $probePath -PathType Leaf) -and $null -ne $candidate) {
        Move-Item -LiteralPath $probePath -Destination $candidate.FullName
    }
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
