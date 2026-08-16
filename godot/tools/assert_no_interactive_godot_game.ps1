function Get-GodotCommandLineProjectPath {
    param([string]$CommandLine)

    if ([string]::IsNullOrWhiteSpace($CommandLine)) {
        return $null
    }

    $pathMatch = [regex]::Match(
        $CommandLine,
        '(?i)(?:^|\s)--path(?:=|\s+)(?:"([^"]+)"|(\S+))'
    )
    if (-not $pathMatch.Success) {
        return $null
    }

    $pathValue = $pathMatch.Groups[1].Value
    if ([string]::IsNullOrWhiteSpace($pathValue)) {
        $pathValue = $pathMatch.Groups[2].Value
    }
    try {
        return [IO.Path]::GetFullPath($pathValue).TrimEnd([char[]]@('\', '/'))
    }
    catch {
        return $null
    }
}

function Get-InteractiveGodotProjectProcesses {
    param([string]$TargetProjectPath)

    $normalizedTargetPath = [IO.Path]::GetFullPath($TargetProjectPath).TrimEnd([char[]]@('\', '/'))
    $godotProcesses = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" -ErrorAction SilentlyContinue)
    foreach ($process in $godotProcesses) {
        $commandLine = [string]$process.CommandLine
        if ([string]::IsNullOrWhiteSpace($commandLine)) {
            continue
        }
        if ($commandLine -match '(?i)(?:^|\s)--headless(?:\s|$)' -or
            $commandLine -match '(?i)(?:^|\s)--editor(?:\s|$)') {
            continue
        }

        $processProjectPath = Get-GodotCommandLineProjectPath -CommandLine $commandLine
        if ($null -ne $processProjectPath -and
            $processProjectPath.Equals($normalizedTargetPath, [StringComparison]::OrdinalIgnoreCase)) {
            $process
        }
    }
}

function Assert-NoInteractiveGodotGame {
    param(
        [string]$ProjectPath,
        [string]$OperationName,
        # Validation wrappers may explicitly declare concurrent play support.
        # The guard demotes the CALLER so spawned Godot children inherit
        # BelowNormal. Every declaring wrapper must restore the returned
        # OriginalPriorityClass in a finally block.
        [switch]$AllowDuringPlay
    )

    $interactiveProcesses = @(Get-InteractiveGodotProjectProcesses -TargetProjectPath $ProjectPath)
    if ($interactiveProcesses.Count -eq 0) {
        return [pscustomobject]@{
            Demoted = $false
            OriginalPriorityClass = [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass
        }
    }

    $processSummary = ($interactiveProcesses | ForEach-Object {
        "PID $($_.ProcessId)"
    }) -join ", "

    if ($AllowDuringPlay) {
        $originalPriority = [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass
        try {
            [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = 'BelowNormal'
        }
        catch {}
        $effectivePriority = [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass
        if ($effectivePriority -ne 'BelowNormal' -and $effectivePriority -ne 'Idle') {
            throw (
                "{0} blocked: BelowNormal demotion failed (actual priority: {1}) while " +
                "this project is running interactively ({2}). Refusing to run validation " +
                "at normal priority during play."
            ) -f $OperationName, $effectivePriority, $processSummary
        }
        Write-Warning (
            (
                "{0} proceeding while this project is running interactively ({1}) " +
                "because this wrapper declares -AllowDuringPlay. Verified process " +
                "priority: {2}. The live " +
                "game may still feel brief frame drops."
            ) -f $OperationName, $processSummary, $effectivePriority
        )
        return [pscustomobject]@{
            Demoted = $true
            OriginalPriorityClass = $originalPriority
        }
    }

    throw (
        "{0} blocked because this project is running interactively ({1}). " +
        "This wrapper must declare -AllowDuringPlay and restore the validation " +
        "priority context before it may run concurrently."
    ) -f $OperationName, $processSummary
}

function Restore-GodotValidationPriority {
    param([object]$Context)

    if ($null -eq $Context -or -not [bool]$Context.Demoted) {
        return
    }
    try {
        [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = $Context.OriginalPriorityClass
    }
    catch {
        throw "Failed to restore validation caller priority to $($Context.OriginalPriorityClass): $($_.Exception.Message)"
    }
    $restoredPriority = [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass
    if ($restoredPriority -ne $Context.OriginalPriorityClass) {
        throw "Validation caller priority restore mismatch: expected $($Context.OriginalPriorityClass), got $restoredPriority"
    }
}
