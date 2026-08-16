param(
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "assert_no_interactive_godot_game.ps1")

function Get-InteractiveGodotProjectProcesses {
    param([string]$TargetProjectPath)
    return @([pscustomobject]@{
        ProcessId = 424242
        CommandLine = "godot --path `"$TargetProjectPath`""
    })
}

$originalPriority = [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass
$blocked = $false
try {
    $null = Assert-NoInteractiveGodotGame `
        -ProjectPath $ProjectPath `
        -OperationName "interactive-play guard RED fixture"
}
catch {
    $blocked = $true
}
if (-not $blocked) {
    throw "interactive-play guard RED fixture did not fail closed without -AllowDuringPlay"
}

$context = $null
try {
    $context = Assert-NoInteractiveGodotGame `
        -ProjectPath $ProjectPath `
        -OperationName "interactive-play guard GREEN fixture" `
        -AllowDuringPlay
    if (-not [bool]$context.Demoted) {
        throw "interactive-play guard GREEN fixture did not report priority demotion"
    }
    $effectivePriority = [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass
    if ($effectivePriority -ne 'BelowNormal' -and $effectivePriority -ne 'Idle') {
        throw "interactive-play guard GREEN fixture priority is $effectivePriority"
    }
}
finally {
    Restore-GodotValidationPriority -Context $context
}

$restoredPriority = [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass
if ($restoredPriority -ne $originalPriority) {
    throw "interactive-play guard failed to restore priority: expected $originalPriority, got $restoredPriority"
}

Write-Host "interactive-play validation guard verification: ok"
