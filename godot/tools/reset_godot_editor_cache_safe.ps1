param(
    [string]$ProjectDir = (Split-Path -Parent $PSScriptRoot),
    [string]$AppUserDataDir = (Join-Path $env:APPDATA "Godot\app_userdata\pingfighter")
)

$ErrorActionPreference = "Stop"

$runningGodot = Get-Process | Where-Object { $_.ProcessName -like "Godot*" }
if ($runningGodot) {
    $runningGodot | Select-Object Id, ProcessName, MainWindowTitle
    throw "Godot is still running. Close the editor first, then run this cache reset."
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
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
