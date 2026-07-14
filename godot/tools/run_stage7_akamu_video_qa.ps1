param(
    [string]$GodotExe = "",
    [string]$FfmpegExe = "",
    [string]$FfprobeExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string[]]$WindowSizes = @("1280x720", "1920x1080")
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")

$expectedBytes = 2183964
$expectedSha256 = "c44aadcd843bcf7b42445e8770e855a8b5bd2fad7277308a80c6e8fe38356982"
$videoPath = Join-Path $ProjectPath "assets\video\stage7_akamu_intro_v1.ogv"
$smokePath = "res://tests/stage7_akamu_prebattle_video_smoke.gd"
$liveFrameSmokePath = "res://tests/stage7_akamu_prebattle_live_frame_smoke.gd"
$battleInitializeSmokePath = "res://tests/battle_scene_battle_initialize_lifecycle_smoke.gd"

function Resolve-ToolPath {
    param(
        [string]$ExplicitPath,
        [string]$CommandName
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) {
            throw "$CommandName executable not found: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "$CommandName was not found on PATH. Pass -${CommandName}Exe explicitly."
    }
    return $command.Source
}

function Assert-Equal {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Label
    )

    if ($Actual -ne $Expected) {
        throw "$Label mismatch: expected '$Expected', got '$Actual'"
    }
}

function Invoke-FullDecode {
    param(
        [string]$FfmpegPath,
        [string]$InputPath,
        [string[]]$MapArgs,
        [string]$Label
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $FfmpegPath -hide_banner -v error -xerror -i $InputPath @MapArgs -f null - 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0) {
        throw "$Label full-stream decode failed with exit code $exitCode"
    }
}

function Invoke-WindowedSmoke {
    param(
        [string]$GodotPath,
        [int]$Width,
        [int]$Height
    )

    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("stage7_video_qa_{0}x{1}_{2}.log" -f $Width, $Height, $PID)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $GodotPath `
            --windowed `
            --path $ProjectPath `
            --resolution ("{0}x{1}" -f $Width, $Height) `
            --position 40,40 `
            --log-file $logPath `
            -s $smokePath `
            -- `
            ("--qa-width={0}" -f $Width) `
            ("--qa-height={0}" -f $Height) 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $output | ForEach-Object { Write-Host $_ }
    $outputText = $output | Out-String
    $seriousLines = @($output | Where-Object {
        $line = $_.ToString()
        ($line -notmatch "Failed to read the root certificate store") -and
        (
            ($line -match "^(SCRIPT ERROR|ERROR:|FATAL:)") -or
            ($line -match "(Parse Error|Compile Error|Failed to load script|Invalid call|GDScript backtrace)") -or
            ($line -match "ObjectDB instances leaked at exit") -or
            ($line -match "RID allocations.*leaked")
        )
    })
    if (($exitCode -ne 0) -or ($seriousLines.Count -gt 0) -or
        ($outputText -notmatch "stage7_akamu_prebattle_video_smoke: ok") -or
        ($outputText -notmatch "stage7_akamu_prebattle_video_windowed_metrics:")) {
        Write-Host "windowed Stage 7 QA log preserved for triage: $logPath"
    }
    if ($exitCode -ne 0) {
        throw "windowed Stage 7 video smoke ${Width}x${Height} failed with exit code $exitCode"
    }
    if ($seriousLines.Count -gt 0) {
        throw "windowed Stage 7 video smoke ${Width}x${Height} emitted an error or leak warning"
    }
    if ($outputText -notmatch "stage7_akamu_prebattle_video_smoke: ok") {
        throw "windowed Stage 7 video smoke ${Width}x${Height} did not print its ok marker"
    }
    if ($outputText -notmatch "stage7_akamu_prebattle_video_windowed_metrics:") {
        throw "windowed Stage 7 video smoke ${Width}x${Height} did not print visual metrics"
    }
    # 디스크 증적 대조: 스모크가 남긴 metrics.txt의 result=PASS를 실제로 확인
    # (stdout ok 마커만 믿지 않는다).
    $captureLine = ($output | Where-Object { $_.ToString() -match "stage7_akamu_prebattle_video_windowed_capture: " } | Select-Object -First 1)
    if ($null -eq $captureLine) {
        Write-Host "windowed Stage 7 QA log preserved for triage: $logPath"
        throw "windowed Stage 7 video smoke ${Width}x${Height} did not report its capture path"
    }
    $capturePath = ($captureLine.ToString() -split "stage7_akamu_prebattle_video_windowed_capture: ", 2)[1].Trim()
    $metricsPath = Join-Path (Split-Path -Parent $capturePath) "metrics.txt"
    if (-not (Test-Path -LiteralPath $metricsPath -PathType Leaf)) {
        Write-Host "windowed Stage 7 QA log preserved for triage: $logPath"
        throw "windowed Stage 7 QA metrics file missing on disk: $metricsPath"
    }
    $metricsText = Get-Content -LiteralPath $metricsPath -Raw
    if ($metricsText -notmatch "(?m)^result=PASS$") {
        Write-Host "windowed Stage 7 QA log preserved for triage: $logPath"
        throw "windowed Stage 7 QA evidence did not record result=PASS: $metricsPath"
    }
    # 모든 검증(stdout + 디스크 artifact result=PASS)을 통과한 뒤에만 로그를
    # 정리한다 — 어떤 실패 경로든 로그는 증적으로 남는다(throw는 위에서 발생).
    if (Test-Path -LiteralPath $logPath -PathType Leaf) {
        Remove-Item -LiteralPath $logPath -Force
    }
}

function Invoke-HeadlessSmoke {
    param(
        [string]$GodotPath,
        [string]$HeadlessSmokePath,
        [string]$OkMarker
    )

    $logDir = Join-Path $ProjectPath ".godot\codex_logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir ("stage7_video_qa_headless_{0}.log" -f $PID)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $GodotPath `
            --headless `
            --path $ProjectPath `
            --log-file $logPath `
            -s $HeadlessSmokePath 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $output | ForEach-Object { Write-Host $_ }
    $outputText = $output | Out-String
    $seriousLines = @($output | Where-Object {
        $line = $_.ToString()
        ($line -notmatch "Failed to read the root certificate store") -and
        (
            ($line -match "^(SCRIPT ERROR|ERROR:|FATAL:)") -or
            ($line -match "(Parse Error|Compile Error|Failed to load script|Invalid call|GDScript backtrace)") -or
            ($line -match "ObjectDB instances leaked at exit") -or
            ($line -match "RID allocations.*leaked")
        )
    })
    $passed = ($exitCode -eq 0) -and ($seriousLines.Count -eq 0) -and
        ($outputText -match [regex]::Escape($OkMarker))
    # 성공 판정 후에만 로그 삭제 — 실패 시 증적 보존(windowed 경로와 동일 계약).
    if (Test-Path -LiteralPath $logPath -PathType Leaf) {
        if ($passed) {
            Remove-Item -LiteralPath $logPath -Force
        }
        else {
            Write-Host "headless Stage 7 QA log preserved for triage: $logPath"
        }
    }
    if ($exitCode -ne 0) {
        throw "headless Stage 7 video smoke failed with exit code $exitCode"
    }
    if ($seriousLines.Count -gt 0) {
        throw "headless Stage 7 video smoke emitted an error or leak warning"
    }
    if ($outputText -notmatch [regex]::Escape($OkMarker)) {
        throw "headless Stage 7 smoke '$HeadlessSmokePath' did not print its ok marker"
    }
}

if (-not (Test-Path -LiteralPath $videoPath -PathType Leaf)) {
    throw "Stage 7 runtime OGV not found: $videoPath"
}

$godotPath = Resolve-GodotConsolePath -GodotExe $GodotExe
$ffmpegPath = Resolve-ToolPath -ExplicitPath $FfmpegExe -CommandName "ffmpeg"
$ffprobePath = Resolve-ToolPath -ExplicitPath $FfprobeExe -CommandName "ffprobe"

Write-Host "Godot: $godotPath"
Write-Host "FFmpeg: $ffmpegPath"
Write-Host "FFprobe: $ffprobePath"
Write-Host "Video: $videoPath"

$file = Get-Item -LiteralPath $videoPath
Assert-Equal -Actual $file.Length -Expected $expectedBytes -Label "runtime OGV byte size"
$sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $videoPath).Hash.ToLowerInvariant()
Assert-Equal -Actual $sha256 -Expected $expectedSha256 -Label "runtime OGV SHA-256"

$probeOutput = & $ffprobePath `
    -v error `
    -count_packets `
    -show_entries "stream=index,codec_type,codec_name,width,height,coded_width,coded_height,r_frame_rate,nb_read_packets,sample_rate,channels:format=duration,size" `
    -of json `
    $videoPath
if ($LASTEXITCODE -ne 0) {
    throw "ffprobe failed with exit code $LASTEXITCODE"
}
$probe = ($probeOutput | Out-String) | ConvertFrom-Json
$videoStream = @($probe.streams | Where-Object { $_.codec_type -eq "video" }) | Select-Object -First 1
$audioStream = @($probe.streams | Where-Object { $_.codec_type -eq "audio" }) | Select-Object -First 1
if ($null -eq $videoStream -or $null -eq $audioStream) {
    throw "runtime OGV must contain one video stream and one audio stream"
}

Assert-Equal -Actual $videoStream.codec_name -Expected "theora" -Label "video codec"
Assert-Equal -Actual ([int]$videoStream.width) -Expected 760 -Label "video picture width"
Assert-Equal -Actual ([int]$videoStream.height) -Expected 750 -Label "video picture height"
Assert-Equal -Actual ([int]$videoStream.coded_width) -Expected 768 -Label "video coded width"
Assert-Equal -Actual ([int]$videoStream.coded_height) -Expected 752 -Label "video coded height"
Assert-Equal -Actual $videoStream.r_frame_rate -Expected "30/1" -Label "video frame rate"
Assert-Equal -Actual ([int]$videoStream.nb_read_packets) -Expected 300 -Label "video packet count"
Assert-Equal -Actual $audioStream.codec_name -Expected "vorbis" -Label "audio codec"
Assert-Equal -Actual ([int]$audioStream.sample_rate) -Expected 48000 -Label "audio sample rate"
Assert-Equal -Actual ([int]$audioStream.channels) -Expected 2 -Label "audio channel count"
Assert-Equal -Actual ([int64]$probe.format.size) -Expected ([int64]$expectedBytes) -Label "probe container size"
$duration = [double]$probe.format.duration
if ([math]::Abs($duration - 10.1) -gt 0.001) {
    throw "container duration mismatch: expected 10.1, got $duration"
}

Write-Host "FFmpeg full-decode: video + audio"
Invoke-FullDecode `
    -FfmpegPath $ffmpegPath `
    -InputPath $videoPath `
    -MapArgs @("-map", "0:v:0", "-map", "0:a:0") `
    -Label "video + audio"

Write-Host "Godot headless contract smoke"
Invoke-HeadlessSmoke `
    -GodotPath $godotPath `
    -HeadlessSmokePath $smokePath `
    -OkMarker "stage7_akamu_prebattle_video_smoke: ok"
Write-Host "Godot live shell/frame wiring smoke"
Invoke-HeadlessSmoke `
    -GodotPath $godotPath `
    -HeadlessSmokePath $liveFrameSmokePath `
    -OkMarker "stage7_akamu_prebattle_live_frame_smoke: ok"
Write-Host "Godot live shell dynamic-stage BGM initialization smoke"
Invoke-HeadlessSmoke `
    -GodotPath $godotPath `
    -HeadlessSmokePath $battleInitializeSmokePath `
    -OkMarker "battle_scene_battle_initialize_lifecycle_smoke: ok"

foreach ($windowSize in $WindowSizes) {
    if ($windowSize -notmatch "^(\d+)x(\d+)$") {
        throw "invalid window size '$windowSize'; expected WIDTHxHEIGHT"
    }
    $width = [int]$Matches[1]
    $height = [int]$Matches[2]
    Write-Host "Godot Vulkan/windowed contract smoke: ${width}x${height}"
    Invoke-WindowedSmoke -GodotPath $godotPath -Width $width -Height $height
}

Write-Host ""
Write-Host "Stage 7 Akamu prebattle video QA passed."
