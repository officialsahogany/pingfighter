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
        # Only wrappers whose whole run is short and light may declare this.
        # The opt-in engages only when the caller declares it AND the user set
        # GODOT_ALLOW_VALIDATION_DURING_PLAY=1; heavy wrappers (full warning
        # scan, smoke batches, windowed pixel QA) must not declare it. The
        # bypass demotes the CALLER process so the spawned Godot child inherits
        # BelowNormal; the declaring wrapper owns restoring its original
        # priority class in a finally block.
        [switch]$AllowDuringPlay
    )

    $interactiveProcesses = @(Get-InteractiveGodotProjectProcesses -TargetProjectPath $ProjectPath)
    if ($interactiveProcesses.Count -eq 0) {
        return
    }

    $processSummary = ($interactiveProcesses | ForEach-Object {
        "PID $($_.ProcessId)"
    }) -join ", "

    if ($AllowDuringPlay -and $env:GODOT_ALLOW_VALIDATION_DURING_PLAY -eq '1') {
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
                "because GODOT_ALLOW_VALIDATION_DURING_PLAY=1 and this operation " +
                "declares -AllowDuringPlay. Verified process priority: {2}. The live " +
                "game may still feel brief frame drops."
            ) -f $OperationName, $processSummary, $effectivePriority
        )
        return
    }

    throw (
        "{0} blocked because this project is running interactively ({1}). " +
        "Stop play mode before running automated Godot validation. " +
        "GODOT_ALLOW_VALIDATION_DURING_PLAY=1 applies only to operations that " +
        "declare -AllowDuringPlay (short checks such as the headless load check)."
    ) -f $OperationName, $processSummary
}
