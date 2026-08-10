param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$ChunkSize = 450
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
Assert-NoInteractiveGodotGame -ProjectPath $ProjectPath -OperationName "Godot warning scan"

. (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
. (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
$godotPath = Resolve-GodotConsolePath -GodotExe $GodotExe

Write-Host "Godot: $godotPath"
Write-Host "Project: $ProjectPath"
Write-Host "Warning scan: res://tools/gd_warning_scan.gd"

$scanLogDir = Join-Path $ProjectPath ".godot\codex_logs"
New-Item -ItemType Directory -Force -Path $scanLogDir | Out-Null

function Invoke-WarningScanChunk {
    param(
        [int]$StartIndex,
        [int]$CurrentChunkSize
    )

    $scanLogPath = Join-Path $scanLogDir ("warning_scan_{0}_{1}_{2}.log" -f $PID, $StartIndex, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))
    $godotArgs = @(
        "--headless",
        "--path",
        $ProjectPath,
        "--log-file",
        $scanLogPath,
        "--script",
        "res://tools/gd_warning_scan.gd"
    )
    if ($CurrentChunkSize -gt 0) {
        $godotArgs += "--"
        $godotArgs += "--start-index=$StartIndex"
        $godotArgs += "--max-count=$CurrentChunkSize"
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $chunkOutput = & $godotPath @godotArgs 2>&1
        $chunkExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if (Test-Path -LiteralPath $scanLogPath -PathType Leaf) {
            Remove-Item -LiteralPath $scanLogPath -Force
        }
    }

    return @{
        Output = @($chunkOutput)
        ExitCode = $chunkExitCode
    }
}

function Assert-WarningScanOutput {
    param(
        [object[]]$Output,
        [int]$ExitCode
    )

    $outputText = ($Output | Out-String)
    # Godot can emit unrelated environment errors in headless Windows runs, such
    # as certificate-store reads. Keep those from masking real script warnings.
    $seriousErrorLines = @($Output | Where-Object {
        $line = $_.ToString()
        Test-GodotSeriousErrorLine -Line $line
    })
    $hasGdscriptWarning = $outputText -match "(?s)WARNING:.*?at:\s+GDScript::reload"

    if ($ExitCode -ne 0) {
        throw "Godot warning scan failed with exit code $ExitCode"
    }
    if ($seriousErrorLines.Count -gt 0) {
        throw "Godot warning scan emitted an error despite exit code 0"
    }
    if ($hasGdscriptWarning) {
        throw "Godot warning scan emitted GDScript warnings"
    }
}

$totalScripts = $null
$startIndex = 0
do {
    $result = Invoke-WarningScanChunk -StartIndex $startIndex -CurrentChunkSize $ChunkSize
    $output = @($result.Output)
    $output | ForEach-Object { Write-Host $_ }
    if ($null -eq $totalScripts) {
        foreach ($lineObject in $output) {
            $line = $lineObject.ToString()
            if ($line -match "^gd_warning_scan: scanning (\d+) scripts") {
                $totalScripts = [int]$Matches[1]
                break
            }
        }
    }
    Assert-WarningScanOutput -Output $output -ExitCode ([int]$result.ExitCode)
    if ($ChunkSize -le 0) {
        break
    }
    if ($null -eq $totalScripts) {
        throw "Godot warning scan did not report the script count"
    }
    $startIndex += $ChunkSize
} while ($startIndex -lt $totalScripts)

if ((Test-Path -LiteralPath $scanLogDir -PathType Container) -and -not (Get-ChildItem -LiteralPath $scanLogDir -Force)) {
    Remove-Item -LiteralPath $scanLogDir -Force
}

Write-Host ""
Write-Host "Godot warning scan passed with no GDScript warnings."
