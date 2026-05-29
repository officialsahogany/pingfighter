$ErrorActionPreference = "Stop"

function Test-GodotExecutablePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }
    return Test-Path -LiteralPath $Path -PathType Leaf
}

function Resolve-GodotExecutableCandidate {
    param(
        [string]$Path,
        [switch]$PreferConsole
    )

    if (-not (Test-GodotExecutablePath -Path $Path)) {
        return ""
    }

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    if ($PreferConsole -and $resolved -notmatch "_console\.exe$") {
        $consolePath = $resolved -replace "\.exe$", "_console.exe"
        if (Test-GodotExecutablePath -Path $consolePath) {
            return (Resolve-Path -LiteralPath $consolePath).Path
        }
    }

    return $resolved
}

function Get-GodotSearchRoots {
    $roots = New-Object System.Collections.Generic.List[string]

    foreach ($root in @(
        $PSScriptRoot,
        (Join-Path $PSScriptRoot ".."),
        (Join-Path $PSScriptRoot "..\.."),
        $env:GODOT_HOME,
        $env:USERPROFILE,
        (Join-Path $env:USERPROFILE "Downloads"),
        (Join-Path $env:LOCALAPPDATA "Programs"),
        ${env:ProgramFiles},
        ${env:ProgramFiles(x86)}
    )) {
        if (-not [string]::IsNullOrWhiteSpace($root) -and
            (Test-Path -LiteralPath $root -PathType Container)) {
            $roots.Add((Resolve-Path -LiteralPath $root).Path)
        }
    }

    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        if (-not $drive.IsReady) {
            continue
        }
        foreach ($name in @("Godot", "Tools", "Apps", "PortableApps", "Downloads", "dev", "main")) {
            $candidate = Join-Path $drive.RootDirectory.FullName $name
            if (Test-Path -LiteralPath $candidate -PathType Container) {
                $roots.Add((Resolve-Path -LiteralPath $candidate).Path)
            }
        }
    }

    return $roots | Select-Object -Unique
}

function Find-GodotExecutableInRoots {
    param([switch]$PreferConsole)

    foreach ($root in Get-GodotSearchRoots) {
        foreach ($pattern in @(
            "Godot*_console.exe",
            "Godot*.exe",
            "*\Godot*_console.exe",
            "*\Godot*.exe",
            "*\*\Godot*_console.exe",
            "*\*\Godot*.exe"
        )) {
            $matches = @(Get-ChildItem -Path (Join-Path $root $pattern) -File -ErrorAction SilentlyContinue |
                Sort-Object FullName -Descending)
            foreach ($match in $matches) {
                $resolved = Resolve-GodotExecutableCandidate -Path $match.FullName -PreferConsole:$PreferConsole
                if ($resolved) {
                    return $resolved
                }
            }
        }
    }

    return ""
}

function Resolve-GodotConsolePath {
    param([string]$GodotExe = "")

    foreach ($candidate in @(
        $GodotExe,
        $env:GODOT_CONSOLE_EXE,
        $env:GODOT_EXE
    )) {
        $resolved = Resolve-GodotExecutableCandidate -Path $candidate -PreferConsole
        if ($resolved) {
            return $resolved
        }
    }

    foreach ($commandName in @("godot_console", "godot4_console", "godot4", "godot")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            $resolved = Resolve-GodotExecutableCandidate -Path $command.Source -PreferConsole
            if ($resolved) {
                return $resolved
            }
        }
    }

    $discovered = Find-GodotExecutableInRoots -PreferConsole
    if ($discovered) {
        return $discovered
    }

    throw "Godot executable not found. Pass -GodotExe, set GODOT_CONSOLE_EXE/GODOT_EXE, add Godot to PATH, or place Godot beside this repo on the external drive."
}

function Resolve-GodotGuiPath {
    param([string]$GodotExe = "")

    $resolved = Resolve-GodotConsolePath -GodotExe $GodotExe
    $guiPath = $resolved -replace "_console\.exe$", ".exe"
    if ($guiPath -ne $resolved -and (Test-GodotExecutablePath -Path $guiPath)) {
        return (Resolve-Path -LiteralPath $guiPath).Path
    }
    return $resolved
}
