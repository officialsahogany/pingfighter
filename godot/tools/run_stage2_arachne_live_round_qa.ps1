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
        -OperationName "Stage 2 Arachne live round Vulkan QA" `
        -AllowDuringPlay

    . (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
    . (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
    $godot = Resolve-GodotConsolePath -GodotExe $GodotExe
    $qaPath = "res://tools/stage2_arachne_live_round_qa.gd"
    $logDir = Join-Path $ProjectPath "logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir (
        "stage2_arachne_live_round_qa_{0}_{1}.log" -f `
            $PID,
            [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff")
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $godot `
            --path $ProjectPath `
            --windowed `
            --resolution 2020x1246 `
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
    $okMarker = "stage2_arachne_live_round_qa: ok"
    if ($exitCode -ne 0 -or $seriousErrors.Count -gt 0 -or -not $outputText.Contains($okMarker)) {
        Write-Host "Arachne live-round QA log preserved for triage: $logPath"
        if ($exitCode -ne 0) { throw "$qaPath failed with exit code $exitCode" }
        if ($seriousErrors.Count -gt 0) { throw "$qaPath emitted a Godot error despite exit code 0" }
        throw "$qaPath did not emit its ok marker"
    }
    Write-Host "Stage 2 Arachne live round Vulkan QA passed. Log: $logPath"
}
finally {
    Restore-GodotValidationPriority -Context $validationPriorityContext
}
