param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
$validationPriorityContext = $null
try {
    $validationPriorityContext = Assert-NoInteractiveGodotGame `
        -ProjectPath $ProjectPath `
        -OperationName "Mugong icon wiring Vulkan visual QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $qaSpecs = @(
        @{
            Path = "res://tools/runtime_perk_traditional_choice_capture.gd"
            Marker = "runtime_perk_traditional_choice_capture: ok"
        },
        @{
            Path = "res://tests/remaining_mugong_collection_visual_qa.gd"
            Marker = "remaining_mugong_collection_visual_qa: ok"
        },
        @{
            Path = "res://tests/mugong_icon_debug_codex_visual_qa.gd"
            Marker = "mugong_icon_debug_codex_visual_qa: ok"
        },
        @{
            Path = "res://tests/character_info_mugong_round_slot_visual_qa.gd"
            Marker = "character_info_mugong_round_slot_visual_qa: ok"
        }
    )
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null

    foreach ($qaSpec in $qaSpecs) {
        $qaPath = [string]$qaSpec.Path
        $qaSlug = ([System.IO.Path]::GetFileNameWithoutExtension($qaPath)) -replace "[^A-Za-z0-9_.-]", "_"
        $logPath = Join-Path $logDir ("mugong_icon_wiring_{0}_{1}_{2}.log" -f $qaSlug, $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $output = & $godot `
                --path $ProjectPath `
                --windowed `
                --rendering-method mobile `
                --rendering-driver vulkan `
                --log-file $logPath `
                -s $qaPath 2>&1
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        $output | ForEach-Object { Write-Host $_ }
        $outputText = ($output | Out-String)
        $seriousErrors = @($output | Where-Object {
            Test-GodotSeriousErrorLine -Line $_.ToString()
        })
        if (
            $exitCode -ne 0 `
            -or $seriousErrors.Count -gt 0 `
            -or -not $outputText.Contains([string]$qaSpec.Marker)
        ) {
            Write-Host "Mugong icon wiring visual QA log preserved for triage: $logPath"
            if ($exitCode -ne 0) {
                throw "$qaPath failed with exit code $exitCode"
            }
            if ($seriousErrors.Count -gt 0) {
                throw "$qaPath emitted a Godot error despite exit code 0"
            }
            throw "$qaPath did not emit its terminal marker"
        }
        Remove-Item -LiteralPath $logPath -Force
    }

    if (-not (Get-ChildItem -LiteralPath $logDir -Force)) {
        Remove-Item -LiteralPath $logDir -Force
    }
    Write-Host "Mugong icon wiring Vulkan visual QA passed."
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
