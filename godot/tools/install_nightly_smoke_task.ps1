#requires -Version 5.1
<#
.SYNOPSIS
    Register / unregister the 디스크하츠 - 링피아 nightly full-smoke Scheduled Task.

.DESCRIPTION
    Creates a per-user Windows Scheduled Task that runs
    godot/tools/run_nightly_smoke.ps1 once a day. The task runs as the current
    user with LIMITED (non-elevated) rights and only when that user is logged on
    -- matching the "runs while the machine is on" model. -StartWhenAvailable
    makes a missed run (machine off at the scheduled time) fire on next logon.

    Idempotent (-Force overwrites an existing task of the same name).

    Install:
        powershell -ExecutionPolicy Bypass -File godot\tools\install_nightly_smoke_task.ps1
    Custom time:
        powershell -ExecutionPolicy Bypass -File godot\tools\install_nightly_smoke_task.ps1 -Time 02:30
    Uninstall:
        powershell -ExecutionPolicy Bypass -File godot\tools\install_nightly_smoke_task.ps1 -Uninstall

.PARAMETER Time
    Daily start time "HH:mm" (default "03:00").

.PARAMETER TaskName
    Scheduled task name (default "LingpiaNightlySmoke").

.PARAMETER Uninstall
    Remove the task instead of creating it.
#>
param(
    [string]$Time = "03:00",
    [string]$TaskName = "LingpiaNightlySmoke",
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$tools = $PSScriptRoot

if ($Uninstall) {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Removed scheduled task '$TaskName'."
    }
    else {
        Write-Host "No scheduled task '$TaskName' found; nothing to remove."
    }
    return
}

$job = (Resolve-Path -LiteralPath (Join-Path $tools "run_nightly_smoke.ps1")).Path
$psExe = (Get-Command powershell.exe).Source
$startAt = [DateTime]::Parse($Time)

$action = New-ScheduledTaskAction -Execute $psExe `
    -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $job)
$trigger = New-ScheduledTaskTrigger -Daily -At $startAt
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 3)
$principal = New-ScheduledTaskPrincipal `
    -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName `
    -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
    -Description "디스크하츠 - 링피아: nightly full smoke suite (all *_smoke.gd)" `
    -Force | Out-Null

Write-Host "Registered scheduled task '$TaskName' (daily $Time, current user, non-elevated)."
Write-Host "Runs:    $job"
Write-Host "Logs:    %LOCALAPPDATA%\LingpiaNightlySmoke (LAST_RESULT.txt = latest verdict)"
Write-Host "Run now: Start-ScheduledTask -TaskName $TaskName"
Write-Host "Remove:  powershell -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -Uninstall"
