param(
    [string]$GodotExe = "",
    [string]$ProjectDir = (Split-Path -Parent $PSScriptRoot),
    [string]$EditorSettings = (Join-Path $env:APPDATA "Godot\editor_settings-4.6.tres")
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")
$godotPath = Resolve-GodotGuiPath -GodotExe $GodotExe

function Set-EditorLine([string]$content, [string]$key, [string]$value) {
    $escaped = [regex]::Escape($key)
    $line = "$key = $value"
    if ($content -match "(?m)^$escaped\s*=") {
        return [regex]::Replace($content, "(?m)^$escaped\s*=.*$", $line)
    }
    return $content -replace "(\[resource\]\r?\n)", "`$1$line`r`n"
}

function Update-EditorWindowSettingsForSafeRun([string]$settingsPath) {
    if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
        Write-Warning "Godot editor settings not found, skipping no-embed setup: $settingsPath"
        return
    }

    $runningGodot = @(Get-Process | Where-Object { $_.ProcessName -like "Godot*" })
    if ($runningGodot.Count -gt 0) {
        throw "Godot is already running. Close it before rerunning this script so fullscreen/no-embed editor settings persist."
    }

    $text = [System.IO.File]::ReadAllText($settingsPath, [System.Text.Encoding]::UTF8)
    $updated = $text
    $updated = Set-EditorLine $updated "interface/editor/single_window_mode" "true"
    $updated = Set-EditorLine $updated "interface/multi_window/enable" "false"
    $updated = Set-EditorLine $updated "interface/multi_window/restore_windows_on_load" "false"
    $updated = Set-EditorLine $updated "interface/multi_window/maximize_window" "false"
    $updated = Set-EditorLine $updated "run/window_placement/rect" "4"
    $updated = Set-EditorLine $updated "run/window_placement/game_embed_mode" "-1"

    if ($updated -eq $text) {
        Write-Host "Godot editor fullscreen/no-embed settings already applied."
        return
    }

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backup = "$settingsPath.bak_codex_no_embed_$stamp"
    Copy-Item -LiteralPath $settingsPath -Destination $backup
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($settingsPath, $updated, $utf8NoBom)
    Write-Host "Applied Godot editor fullscreen/no-embed settings. Backup: $backup"
}

$ProjectFile = Join-Path $ProjectDir "project.godot"

if (-not (Test-Path -LiteralPath $ProjectFile -PathType Leaf)) {
    throw "Godot project.godot not found in: $ProjectDir"
}

if ((Get-Item -LiteralPath $ProjectFile).Length -le 0) {
    throw "Godot project.godot is empty. Restore project settings before opening Godot: $ProjectFile"
}

$projectText = [System.IO.File]::ReadAllText($ProjectFile, [System.Text.Encoding]::UTF8)
if ($projectText -notmatch '(?m)^run/main_scene="res://scenes/boot_flow\.tscn"$') {
    throw "Godot project.godot does not point at boot_flow.tscn. Restore the boot flow settings before opening Godot."
}

Update-EditorWindowSettingsForSafeRun -settingsPath $EditorSettings

$arguments = @(
    "--editor",
    "--path", $ProjectDir,
    "--single-window",
    "--rendering-driver", "opengl3",
    "--rendering-method", "gl_compatibility"
)

Write-Host "Godot: $godotPath"
Write-Host "Project: $ProjectDir"
Start-Process -FilePath $godotPath -ArgumentList $arguments -WorkingDirectory $ProjectDir
