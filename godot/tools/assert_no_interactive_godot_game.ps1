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
        [string]$OperationName
    )

    $interactiveProcesses = @(Get-InteractiveGodotProjectProcesses -TargetProjectPath $ProjectPath)
    if ($interactiveProcesses.Count -eq 0) {
        return
    }

    $processSummary = ($interactiveProcesses | ForEach-Object {
        "PID $($_.ProcessId)"
    }) -join ", "

    if ($env:GODOT_ALLOW_VALIDATION_DURING_PLAY -eq '1') {
        try {
            [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = 'BelowNormal'
        }
        catch {}
        Write-Warning (
            (
                "{0} proceeding while this project is running interactively ({1}) " +
                "because GODOT_ALLOW_VALIDATION_DURING_PLAY=1. Validation runs at " +
                "BelowNormal priority; the live game may still feel brief frame drops."
            ) -f $OperationName, $processSummary
        )
        return
    }

    throw (
        "{0} blocked because this project is running interactively ({1}). " +
        "Stop play mode before running automated Godot validation, or set " +
        "GODOT_ALLOW_VALIDATION_DURING_PLAY=1 to accept low-priority validation during play."
    ) -f $OperationName, $processSummary
}
