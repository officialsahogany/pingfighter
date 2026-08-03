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
    throw (
        "{0} blocked because this project is running interactively ({1}). " +
        "Stop play mode before running automated Godot validation."
    ) -f $OperationName, $processSummary
}
