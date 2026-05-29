param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
$godotPath = Resolve-GodotConsolePath -GodotExe $GodotExe

Write-Host "Godot: $godotPath"
Write-Host "Project: $ProjectPath"
Write-Host "Warning scan: res://tools/gd_warning_scan.gd"

$scanLogDir = Join-Path $ProjectPath ".godot\codex_logs"
New-Item -ItemType Directory -Force -Path $scanLogDir | Out-Null
$scanLogPath = Join-Path $scanLogDir ("warning_scan_{0}_{1}.log" -f $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $output = & $godotPath --headless --debug --path $ProjectPath --log-file $scanLogPath --script "res://tools/gd_warning_scan.gd" 2>&1
    $exitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
    if (Test-Path -LiteralPath $scanLogPath -PathType Leaf) {
        Remove-Item -LiteralPath $scanLogPath -Force
    }
    if ((Test-Path -LiteralPath $scanLogDir -PathType Container) -and -not (Get-ChildItem -LiteralPath $scanLogDir -Force)) {
        Remove-Item -LiteralPath $scanLogDir -Force
    }
}

$output | ForEach-Object { Write-Host $_ }
$outputText = ($output | Out-String)
# Godot can emit unrelated environment errors in headless Windows runs, such
# as certificate-store reads. Keep those from masking real script warnings.
$seriousErrorLines = @($output | Where-Object {
    $line = $_.ToString()
    ($line -notmatch "Failed to read the root certificate store") -and
        (($line -match "^(SCRIPT ERROR|ERROR:|FATAL:)") -or
            ($line -match "(Parse Error|Compile Error|Failed to load script|Invalid call|GDScript backtrace)"))
})
$hasGdscriptWarning = $outputText -match "(?s)WARNING:.*?at:\s+GDScript::reload"

if ($exitCode -ne 0) {
    throw "Godot warning scan failed with exit code $exitCode"
}
if ($seriousErrorLines.Count -gt 0) {
    throw "Godot warning scan emitted an error despite exit code 0"
}
if ($hasGdscriptWarning) {
    throw "Godot warning scan emitted GDScript warnings"
}

Write-Host ""
Write-Host "Godot warning scan passed with no GDScript warnings."
