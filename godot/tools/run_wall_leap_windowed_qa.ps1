param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WallLeapWindowedInput {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool PostMessage(IntPtr hWnd, uint message, UIntPtr wParam, IntPtr lParam);
}
'@

$godotPath = Resolve-GodotConsolePath -GodotExe $GodotExe
$logDir = Join-Path $ProjectPath ".godot\codex_logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
$stdoutPath = Join-Path $logDir "wall_leap_windowed_${stamp}.out.log"
$stderrPath = Join-Path $logDir "wall_leap_windowed_${stamp}.err.log"
$engineLogPath = Join-Path $logDir "wall_leap_windowed_${stamp}.engine.log"
$engineLogArgument = ".godot/codex_logs/wall_leap_windowed_${stamp}.engine.log"
$qaProcess = $null
$renderProcess = $null
$windowHandle = [IntPtr]::Zero
$mousePoint = [IntPtr]((400 -shl 16) -bor 600)
$zeroWord = [UIntPtr]::new([uint64]0)

function Get-QaText {
    $parts = @()
    if (Test-Path -LiteralPath $stdoutPath) {
        $parts += Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $parts += Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
    }
    return ($parts -join "`n")
}

function Wait-QaMarker {
    param(
        [string]$Marker,
        [int]$Count
    )
    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline) {
        $matches = [regex]::Matches((Get-QaText), [regex]::Escape($Marker)).Count
        if ($matches -ge $Count) {
            return
        }
        Start-Sleep -Milliseconds 40
    }
    throw "Timed out waiting for $Marker #$Count`n$(Get-QaText)"
}

function Send-QaButton {
    param(
        [bool]$Right,
        [bool]$Down
    )
    if ($Right) {
        $message = if ($Down) { 0x0204 } else { 0x0205 }
        $word = if ($Down) { 2 } else { 0 }
    }
    else {
        $message = if ($Down) { 0x0201 } else { 0x0202 }
        $word = if ($Down) { 1 } else { 0 }
    }
    $wordPointer = [UIntPtr]::new([uint64]$word)
    if (-not [WallLeapWindowedInput]::PostMessage($windowHandle, $message, $wordPointer, $mousePoint)) {
        throw "PostMessage failed for mouse message $message"
    }
    Start-Sleep -Milliseconds 150
}

try {
    $qaProcess = Start-Process -FilePath $godotPath -ArgumentList @(
        "--path", $ProjectPath,
        "--windowed",
        "--resolution", "1200x800",
        "--rendering-method", "mobile",
        "--log-file", $engineLogArgument,
        "-s", "res://tools/wall_leap_windowed_qa.gd"
    ) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru

    for ($attempt = 0; $attempt -lt 100; $attempt++) {
        $child = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($qaProcess.Id)" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "Godot*.exe" -and $_.Name -notlike "*console*" } |
            Select-Object -First 1
        if ($null -ne $child) {
            $renderProcess = Get-Process -Id $child.ProcessId -ErrorAction Stop
            break
        }
        Start-Sleep -Milliseconds 50
    }
    if ($null -eq $renderProcess) {
        throw "Godot render child was not available"
    }
    for ($attempt = 0; $attempt -lt 100; $attempt++) {
        $renderProcess.Refresh()
        if ($renderProcess.MainWindowHandle -ne [IntPtr]::Zero) {
            $windowHandle = $renderProcess.MainWindowHandle
            break
        }
        Start-Sleep -Milliseconds 50
    }
    if ($windowHandle -eq [IntPtr]::Zero) {
        throw "Godot QA render window was not available"
    }
    [WallLeapWindowedInput]::ShowWindow($windowHandle, 5) | Out-Null
    [WallLeapWindowedInput]::SetForegroundWindow($windowHandle) | Out-Null

    Wait-QaMarker -Marker "await_rmb_press" -Count 1
    Send-QaButton -Right $true -Down $true
    Wait-QaMarker -Marker "await_rmb_release" -Count 1
    Send-QaButton -Right $true -Down $false
    Wait-QaMarker -Marker "await_lmb_press" -Count 1
    Send-QaButton -Right $false -Down $true
    Wait-QaMarker -Marker "await_lmb_release" -Count 1
    Send-QaButton -Right $false -Down $false
    Wait-QaMarker -Marker "await_rmb_press" -Count 2
    Send-QaButton -Right $true -Down $true
    Wait-QaMarker -Marker "await_rmb_release" -Count 2
    Send-QaButton -Right $true -Down $false
    Wait-QaMarker -Marker "await_rmb_press" -Count 3
    Send-QaButton -Right $true -Down $true
    Wait-QaMarker -Marker "await_rmb_release" -Count 3
    Send-QaButton -Right $true -Down $false

    $deadline = (Get-Date).AddSeconds(30)
    do {
        $outputText = Get-QaText
        if ($outputText -match "wall_leap_windowed_qa: ok" -or $outputText -match "^(SCRIPT ERROR|ERROR:|FATAL:)") {
            break
        }
        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $deadline)
    Start-Sleep -Milliseconds 400
    $outputText = Get-QaText
    $outputText | Write-Host
    if ($outputText -match "^(SCRIPT ERROR|ERROR:|FATAL:)" -or $outputText -match "Invalid call") {
        throw "Windowed Wall-Leap QA emitted an engine or script error"
    }
    if ($outputText -notmatch "wall_leap_windowed_qa: ok") {
        throw "Windowed Wall-Leap QA did not print its ok marker"
    }
    Write-Host "Windowed Wall-Leap QA passed."
}
catch {
    Write-Host "Windowed Wall-Leap QA logs preserved:"
    Write-Host "  $stdoutPath"
    Write-Host "  $stderrPath"
    Write-Host "  $engineLogPath"
    throw
}
finally {
    if ($windowHandle -ne [IntPtr]::Zero) {
        [WallLeapWindowedInput]::PostMessage($windowHandle, 0x0202, $zeroWord, $mousePoint) | Out-Null
        [WallLeapWindowedInput]::PostMessage($windowHandle, 0x0205, $zeroWord, $mousePoint) | Out-Null
    }
    if ($null -ne $renderProcess) {
        $renderProcess.Refresh()
        if (-not $renderProcess.HasExited) {
            Stop-Process -Id $renderProcess.Id -Force
        }
    }
    if ($null -ne $qaProcess) {
        $qaProcess.Refresh()
        if (-not $qaProcess.HasExited) {
            Stop-Process -Id $qaProcess.Id -Force
        }
    }
}
