param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$Preset = "Windows Desktop",
    [string]$OutputDir = "",
    [ValidateSet("Release", "Debug", "Pack")]
    [string]$Mode = "Release",
    [string]$GodotVersion = "4.6.2.stable",
    [switch]$ForcePackFallback,
    [switch]$SkipRuntimeCopy
)

$ErrorActionPreference = "Stop"

function Find-GodotConsole {
    if ($GodotExe -and (Test-Path -LiteralPath $GodotExe -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $GodotExe).Path
    }

    $knownPath = "C:\Users\woduq\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
    if (Test-Path -LiteralPath $knownPath -PathType Leaf) {
        return $knownPath
    }

    foreach ($commandName in @("godot_console", "godot4", "godot")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command -and (Test-Path -LiteralPath $command.Source -PathType Leaf)) {
            return $command.Source
        }
    }

    $downloadDir = Join-Path $env:USERPROFILE "Downloads"
    if (Test-Path -LiteralPath $downloadDir -PathType Container) {
        $candidate = Get-ChildItem -LiteralPath $downloadDir -Recurse -Filter "Godot*_console.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($null -ne $candidate) {
            return $candidate.FullName
        }
    }

    throw "Godot console executable not found. Pass -GodotExe with the full Godot console path."
}

function Get-GodotGuiExe {
    param([string]$ConsolePath)

    $guiPath = $ConsolePath -replace "_console\.exe$", ".exe"
    if ($guiPath -ne $ConsolePath -and (Test-Path -LiteralPath $guiPath -PathType Leaf)) {
        return $guiPath
    }

    return $ConsolePath
}

function Get-WindowsTemplateStatus {
    param([string]$Version)

    $templateDir = Join-Path ([Environment]::GetFolderPath("ApplicationData")) "Godot\export_templates\$Version"
    $releaseTemplate = Join-Path $templateDir "windows_release_x86_64.exe"
    $debugTemplate = Join-Path $templateDir "windows_debug_x86_64.exe"

    return [PSCustomObject]@{
        TemplateDir = $templateDir
        Release = Test-Path -LiteralPath $releaseTemplate -PathType Leaf
        Debug = Test-Path -LiteralPath $debugTemplate -PathType Leaf
        ReleasePath = $releaseTemplate
        DebugPath = $debugTemplate
    }
}

function Invoke-GodotCommand {
    param(
        [string]$GodotPath,
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $GodotPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $output | ForEach-Object { Write-Host $_ }
    $outputText = ($output | Out-String)
    $hasGodotError = $outputText -match "(?m)(SCRIPT ERROR|ERROR:|FATAL:|Parse Error|Compile Error|Failed to load script|Invalid call)"

    if ($exitCode -ne 0) {
        throw "Godot command failed with exit code $exitCode."
    }
    if ($hasGodotError) {
        throw "Godot command emitted an error despite exit code 0."
    }
}

function Write-PackLauncher {
    param(
        [string]$LauncherPath,
        [string]$GuiGodotPath
    )

    $launcher = @(
        "@echo off",
        "set `"GODOT_EXE=$GuiGodotPath`"",
        "`"%GODOT_EXE%`" --main-pack `"%~dp0PingFighter.pck`"",
        "if errorlevel 1 pause"
    )
    Set-Content -LiteralPath $LauncherPath -Value $launcher -Encoding ASCII
}

function Copy-PackRuntime {
    param(
        [string]$GuiGodotPath,
        [string]$TargetDir
    )

    $runtimePath = Join-Path $TargetDir "PingFighter_Godot_Runtime.exe"
    Copy-Item -LiteralPath $GuiGodotPath -Destination $runtimePath -Force
    return $runtimePath
}

$godotPath = Find-GodotConsole
$godotGuiPath = Get-GodotGuiExe -ConsolePath $godotPath
$projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
$targetDir = if ($OutputDir) { $OutputDir } else { Join-Path $projectRoot "builds\windows" }
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

$templateStatus = Get-WindowsTemplateStatus -Version $GodotVersion
$canExportExe = if ($Mode -eq "Debug") { $templateStatus.Debug } else { $templateStatus.Release }
$effectiveMode = $Mode

if ($ForcePackFallback -or $Mode -eq "Pack" -or -not $canExportExe) {
    if ($Mode -ne "Pack" -and -not $canExportExe) {
        Write-Warning "Windows export template is missing at $($templateStatus.TemplateDir). Building a runnable PCK fallback."
    }
    $effectiveMode = "Pack"
}

Write-Host "Godot: $godotPath"
Write-Host "Project: $projectRoot"
Write-Host "Preset: $Preset"
Write-Host "Mode: $effectiveMode"
Write-Host "Output: $targetDir"

if ($effectiveMode -eq "Pack") {
    $pckPath = Join-Path $targetDir "PingFighter.pck"
    $launcherPath = Join-Path $targetDir "PingFighter_Godot_Launcher.cmd"
    $launcherGodotPath = $godotGuiPath
    Invoke-GodotCommand -GodotPath $godotPath -Arguments @(
        "--headless",
        "--path", $projectRoot,
        "--export-pack", $Preset, $pckPath
    )
    if (-not $SkipRuntimeCopy) {
        $runtimePath = Copy-PackRuntime -GuiGodotPath $godotGuiPath -TargetDir $targetDir
        $launcherGodotPath = "%~dp0$([System.IO.Path]::GetFileName($runtimePath))"
        Write-Host "Runtime: $runtimePath"
    }
    Write-PackLauncher -LauncherPath $launcherPath -GuiGodotPath $launcherGodotPath
    Write-Host "Built pack: $pckPath"
    Write-Host "Launcher: $launcherPath"
    exit 0
}

$exePath = Join-Path $targetDir "PingFighter.exe"
$exportFlag = if ($Mode -eq "Debug") { "--export-debug" } else { "--export-release" }
Invoke-GodotCommand -GodotPath $godotPath -Arguments @(
    "--headless",
    "--path", $projectRoot,
    $exportFlag, $Preset, $exePath
)
Write-Host "Built executable: $exePath"
