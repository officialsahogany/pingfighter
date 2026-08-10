param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")
Assert-NoInteractiveGodotGame -ProjectPath $ProjectPath -OperationName "Victory highlight non-headless pixel QA"

. (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
. (Join-Path $PSScriptRoot "godot_output_classifier.ps1")
$godot = Resolve-GodotConsolePath -GodotExe $GodotExe
$qaPath = "res://tests/victory_highlight_replay_clip_pixel_qa.gd"
$logDir = Join-Path $ProjectPath ".godot\codex_logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logPath = Join-Path $logDir ("victory_highlight_clip_pixel_qa_{0}_{1}.log" -f $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    # Deliberately no --headless: this QA proves the real CanvasItem clip mask.
    $output = & $godot --path $ProjectPath --log-file $logPath -s $qaPath 2>&1
    $exitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
    if (Test-Path -LiteralPath $logPath -PathType Leaf) {
        Remove-Item -LiteralPath $logPath -Force
    }
    if ((Test-Path -LiteralPath $logDir -PathType Container) -and -not (Get-ChildItem -LiteralPath $logDir -Force)) {
        Remove-Item -LiteralPath $logDir -Force
    }
}

$output | ForEach-Object { Write-Host $_ }
$outputText = ($output | Out-String)
$okMarker = "victory_highlight_replay_clip_pixel_qa: ok"
$seriousErrors = @($output | Where-Object {
    $line = $_.ToString()
    Test-GodotSeriousErrorLine -Line $line
})

if ($exitCode -ne 0) {
    throw "$qaPath failed with exit code $exitCode"
}
if ($seriousErrors.Count -gt 0) {
    throw "$qaPath emitted a Godot error despite exit code 0"
}
if ($outputText -notmatch [regex]::Escape($okMarker)) {
    throw "$qaPath did not emit the required ok marker"
}

Write-Host "Victory highlight non-headless pixel QA passed."
