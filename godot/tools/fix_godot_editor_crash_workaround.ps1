param(
    [string]$GodotExe = "",
    [string]$ProjectDir = (Split-Path -Parent $PSScriptRoot),
    [string]$EditorSettings = (Join-Path $env:APPDATA "Godot\editor_settings-4.6.tres"),
    [string]$AppUserDataDir = (Join-Path $env:APPDATA "Godot\app_userdata\pingfighter"),
    [switch]$Launch
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")

$runningGodot = Get-Process | Where-Object { $_.ProcessName -like "Godot*" }
if ($runningGodot) {
    $runningGodot | Select-Object Id, ProcessName, MainWindowTitle
    throw "Close Godot first, then run this workaround. The script will not force-close unsaved editor work."
}

if (-not (Test-Path -LiteralPath $EditorSettings -PathType Leaf)) {
    throw "Godot editor settings not found: $EditorSettings"
}

$ProjectFile = Join-Path $ProjectDir "project.godot"

if (-not (Test-Path -LiteralPath $ProjectFile -PathType Leaf)) {
    throw "Godot project.godot not found in: $ProjectDir"
}

if ((Get-Item -LiteralPath $ProjectFile).Length -le 0) {
    throw "Godot project.godot is empty. Restore project settings before running this workaround: $ProjectFile"
}

if ([System.IO.File]::ReadAllText($ProjectFile, [System.Text.Encoding]::UTF8) -notmatch '(?m)^run/main_scene="res://scenes/boot_flow\.tscn"$') {
    throw "Godot project.godot does not point at boot_flow.tscn. Restore the boot flow settings before running this workaround."
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$settingsBackup = "$EditorSettings.bak_codex_safe_window_$stamp"
Copy-Item -LiteralPath $EditorSettings -Destination $settingsBackup
Write-Output "Backed up editor settings: $settingsBackup"

function Set-EditorLine([string]$content, [string]$key, [string]$value) {
    $escaped = [regex]::Escape($key)
    $line = "$key = $value"
    if ($content -match "(?m)^$escaped\s*=") {
        return [regex]::Replace($content, "(?m)^$escaped\s*=.*$", $line)
    }
    return $content -replace "(\[resource\]\r?\n)", "`$1$line`r`n"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$text = [System.IO.File]::ReadAllText($EditorSettings, [System.Text.Encoding]::UTF8)
$text = Set-EditorLine $text "interface/editor/single_window_mode" "true"
$text = Set-EditorLine $text "interface/multi_window/enable" "false"
$text = Set-EditorLine $text "interface/multi_window/restore_windows_on_load" "false"
$text = Set-EditorLine $text "interface/multi_window/maximize_window" "false"
$text = Set-EditorLine $text "run/window_placement/rect" "4"
$text = Set-EditorLine $text "run/window_placement/game_embed_mode" "-1"
[System.IO.File]::WriteAllText($EditorSettings, $text, $utf8NoBom)
Write-Output "Applied single-window, fullscreen placement, and no-embed editor settings."

$projectCache = Join-Path $ProjectDir ".godot"
$shaderCache = Join-Path $AppUserDataDir "shader_cache"

if (Test-Path -LiteralPath $projectCache) {
    $target = Join-Path $ProjectDir ".godot_bak_$stamp"
    Rename-Item -LiteralPath $projectCache -NewName (Split-Path -Leaf $target)
    Write-Output "Renamed project cache: $projectCache -> $target"
} else {
    Write-Output "Project cache not found: $projectCache"
}

if (Test-Path -LiteralPath $shaderCache) {
    $target = Join-Path $AppUserDataDir "shader_cache_bak_$stamp"
    Rename-Item -LiteralPath $shaderCache -NewName (Split-Path -Leaf $target)
    Write-Output "Renamed shader cache: $shaderCache -> $target"
} else {
    Write-Output "Shader cache not found: $shaderCache"
}

if ($Launch) {
    $godotPath = Resolve-GodotGuiPath -GodotExe $GodotExe
    $arguments = @(
        "--editor",
        "--path", $ProjectDir,
        "--single-window",
        "--rendering-driver", "opengl3",
        "--rendering-method", "gl_compatibility"
    )
    Write-Output "Godot: $godotPath"
    Start-Process -FilePath $godotPath -ArgumentList $arguments -WorkingDirectory $ProjectDir
}
