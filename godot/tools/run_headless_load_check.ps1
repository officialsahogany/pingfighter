param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Find-GodotConsole {
    if ($GodotExe -and (Test-Path -LiteralPath $GodotExe -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $GodotExe).Path
    }

    $knownPath = "C:\Users\woduq\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
    if (Test-Path -LiteralPath $knownPath -PathType Leaf) {
        return $knownPath
    }

    $downloadDir = Join-Path $env:USERPROFILE "Downloads"
    if (Test-Path -LiteralPath $downloadDir -PathType Container) {
        $candidate = Get-ChildItem -LiteralPath $downloadDir -Recurse -Filter "Godot*_console.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($null -ne $candidate) {
            return $candidate.FullName
        }
    }

    throw "Godot console executable not found. Pass -GodotExe with the full Godot console path."
}

$godotPath = Find-GodotConsole

Write-Host "Godot: $godotPath"
Write-Host "Project: $ProjectPath"
Write-Host "Headless load check"

$checkLogDir = Join-Path $ProjectPath ".godot\codex_logs"
New-Item -ItemType Directory -Force -Path $checkLogDir | Out-Null
$checkLogPath = Join-Path $checkLogDir ("headless_load_{0}_{1}.log" -f $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $output = & $godotPath --headless --path $ProjectPath --log-file $checkLogPath --quit 2>&1
    $exitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
    if (Test-Path -LiteralPath $checkLogPath -PathType Leaf) {
        Remove-Item -LiteralPath $checkLogPath -Force
    }
    if ((Test-Path -LiteralPath $checkLogDir -PathType Container) -and -not (Get-ChildItem -LiteralPath $checkLogDir -Force)) {
        Remove-Item -LiteralPath $checkLogDir -Force
    }
}

$output | ForEach-Object { Write-Host $_ }
$seriousErrorLines = @($output | Where-Object {
    $line = $_.ToString()
    ($line -notmatch "Failed to read the root certificate store") -and
        (($line -match "^(SCRIPT ERROR|ERROR:|FATAL:)") -or
            ($line -match "(Parse Error|Compile Error|Failed to load script|Invalid call|GDScript backtrace)"))
})

if ($exitCode -ne 0) {
    throw "Godot headless load check failed with exit code $exitCode"
}
if ($seriousErrorLines.Count -gt 0) {
    throw "Godot headless load check emitted an error despite exit code 0"
}

Write-Host ""
Write-Host "Godot headless load check passed."
