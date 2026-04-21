param(
    [ValidateSet("fast", "precise")]
    [string]$Mode = "fast"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$settingsPath = Join-Path $repoRoot ".claude\sprite_workflow_settings.json"

if (-not (Test-Path -LiteralPath $settingsPath)) {
    throw "Settings file not found: $settingsPath"
}

$json = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$json.spriteWorkflowMode = $Mode
$json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $settingsPath -Encoding UTF8

Write-Output "spriteWorkflowMode=$Mode"
Write-Output $settingsPath
