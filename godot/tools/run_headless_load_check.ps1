param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
$godotPath = Resolve-GodotConsolePath -GodotExe $GodotExe

Write-Host "Godot: $godotPath"
Write-Host "Project: $ProjectPath"
Write-Host "Headless load check"

$checkLogDir = Join-Path $ProjectPath ".godot\codex_logs"
New-Item -ItemType Directory -Force -Path $checkLogDir | Out-Null
$checkLogPath = Join-Path $checkLogDir ("headless_load_{0}_{1}.log" -f $PID, [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff"))

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    # --quit (첫 프레임 종료)는 부트가 character_select.tscn 의존체인을 스레드
    # 로드하는 도중 종료를 걸어, 진행 중이던 스크립트 컴파일이 중단되며 가짜
    # SCRIPT ERROR(폰트/셰이더 preload 실패)를 뿜거나 반대로 의존체인을 아예
    # 로드하기 전에 끝나 허위 GREEN이 된다. 1200프레임이면 클린트리에서도
    # 비동기 부트 로드가 완주한 뒤 종료된다(2026-07-14 트리아지).
    # The application quit coordinator starts graceful teardown at frame 1200.
    # Keep a later engine-level fallback so a broken coordinator cannot hang
    # this wrapper forever; the marker check below proves the fallback was not
    # the path that ended a successful run.
    $output = & $godotPath --headless --path $ProjectPath --log-file $checkLogPath --quit-after 1320 -- --ringpia-headless-load-quit-after=1200 --ringpia-headless-sync-prewarm 2>&1
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
$outputText = ($output | Out-String)
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
if ($outputText -notmatch '\[ApplicationQuitCoordinator\] graceful headless shutdown complete') {
    throw "Godot headless load check did not complete the graceful application shutdown path"
}
if ($outputText -match 'ObjectDB instances leaked') {
    throw "Godot headless load check leaked ObjectDB instances at exit"
}

Write-Host ""
Write-Host "Godot headless load check passed."
