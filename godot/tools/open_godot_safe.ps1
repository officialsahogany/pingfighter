param(
    [string]$GodotExe = "$env:USERPROFILE\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe",
    [string]$ProjectDir = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) {
    throw "Godot executable not found: $GodotExe"
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

$arguments = @(
    "--editor",
    "--path", $ProjectDir,
    "--single-window",
    "--rendering-driver", "opengl3",
    "--rendering-method", "gl_compatibility"
)

Start-Process -FilePath $GodotExe -ArgumentList $arguments -WorkingDirectory $ProjectDir
