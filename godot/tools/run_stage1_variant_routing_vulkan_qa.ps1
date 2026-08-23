param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dalji", "gaksi", "podo")]
    [string]$Variant,
    [switch]$FloorOneSecondEncounter,
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
$validationPriorityContext = $null
try {
    $validationPriorityContext = Assert-NoInteractiveGodotGame `
        -ProjectPath $ProjectPath `
        -OperationName "Stage 1 variant routing Vulkan QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $qaPath = "res://tools/stage1_variant_routing_vulkan_qa.gd"
    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("stage1_variant_routing_vulkan_qa_{0}_{1}_{2}.log" -f $Variant, $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))

    $previousErrorActionPreference = $ErrorActionPreference
    $previousFloorOneSecondEncounter = $env:STAGE1_QA_FLOOR_ONE_SECOND_ENCOUNTER
    $env:STAGE1_QA_FLOOR_ONE_SECOND_ENCOUNTER = if ($FloorOneSecondEncounter) { "1" } else { "0" }
    $ErrorActionPreference = "Continue"
    try {
        $output = & $godot `
            --path $ProjectPath `
            --windowed `
            --resolution 1280x750 `
            --rendering-method mobile `
            --rendering-driver vulkan `
            --log-file $logPath `
            -s $qaPath `
            -- `
            "--stage1-variant=$Variant" 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        $env:STAGE1_QA_FLOOR_ONE_SECOND_ENCOUNTER = $previousFloorOneSecondEncounter
    }

    $output | ForEach-Object { Write-Host $_ }
    $outputText = ($output | Out-String)
    $seriousErrors = @($output | Where-Object { Test-GodotSeriousErrorLine -Line $_.ToString() })
    if ($exitCode -ne 0 -or $seriousErrors.Count -gt 0 -or -not $outputText.Contains("stage1_variant_routing_vulkan_qa: ok")) {
        Write-Host "Stage 1 variant routing QA log preserved for triage: $logPath"
        if ($exitCode -ne 0) { throw "$qaPath failed with exit code $exitCode" }
        if ($seriousErrors.Count -gt 0) { throw "$qaPath emitted a Godot error despite exit code 0" }
        throw "$qaPath did not emit its ok marker"
    }
    Remove-Item -LiteralPath $logPath -Force
    if (-not (Get-ChildItem -LiteralPath $logDir -Force)) {
        Remove-Item -LiteralPath $logDir -Force
    }
    Write-Host "Stage 1 variant routing Vulkan QA passed: $Variant"
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
