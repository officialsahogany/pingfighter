param(
    [string]$GodotExe = "$env:USERPROFILE\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe",
    [string]$ProjectDir = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) {
    throw "Godot executable not found: $GodotExe"
}

if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir "project.godot") -PathType Leaf)) {
    throw "Godot project.godot not found in: $ProjectDir"
}

$arguments = @(
    "--editor",
    "--path", $ProjectDir,
    "--single-window",
    "--rendering-driver", "opengl3",
    "--rendering-method", "gl_compatibility"
)

Start-Process -FilePath $GodotExe -ArgumentList $arguments -WorkingDirectory $ProjectDir
