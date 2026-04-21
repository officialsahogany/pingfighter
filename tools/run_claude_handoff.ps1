param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$HandoffPath,

    [Parameter(Position = 1)]
    [string]$Label,

    [string]$Model = "sonnet",
    [string]$PermissionMode = "acceptEdits",
    [string]$OutputRoot = ".tmp/automation",
    [switch]$DryRun
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$resolvedHandoff = if ([System.IO.Path]::IsPathRooted($HandoffPath)) {
    $HandoffPath
} else {
    Join-Path $repoRoot $HandoffPath
}

$args = @(
    "-3",
    (Join-Path $repoRoot "tools\claude_handoff_runner.py"),
    "--handoff", $resolvedHandoff,
    "--output-root", $OutputRoot,
    "--model", $Model,
    "--permission-mode", $PermissionMode
)

if ($Label) {
    $args += @("--label", $Label)
}

if ($DryRun) {
    $args += "--dry-run"
}

& py @args
exit $LASTEXITCODE
