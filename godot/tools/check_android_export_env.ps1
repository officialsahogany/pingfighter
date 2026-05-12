param(
    [string]$GodotVersion = "4.6.2.stable",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Test-FileExists {
    param([string]$Path)
    return [bool]($Path -and (Test-Path -LiteralPath $Path -PathType Leaf))
}

function Test-DirExists {
    param([string]$Path)
    return [bool]($Path -and (Test-Path -LiteralPath $Path -PathType Container))
}

function Get-EditorSettingValue {
    param(
        [string]$SettingsPath,
        [string]$Key
    )
    if (-not (Test-FileExists $SettingsPath)) {
        return ""
    }
    $escaped = [regex]::Escape($Key)
    $match = Select-String -LiteralPath $SettingsPath -Pattern "^\s*$escaped\s*=\s*`"([^`"]*)`"" | Select-Object -First 1
    if ($null -eq $match) {
        return ""
    }
    return $match.Matches[0].Groups[1].Value
}

function Find-ApkSigner {
    param([string]$SdkPath)
    if (-not (Test-DirExists $SdkPath)) {
        return ""
    }
    $buildTools = Join-Path $SdkPath "build-tools"
    if (-not (Test-DirExists $buildTools)) {
        return ""
    }
    $candidate = Get-ChildItem -LiteralPath $buildTools -Recurse -Filter "apksigner*" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in @("apksigner.bat", "apksigner") } |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if ($null -eq $candidate) {
        return ""
    }
    return $candidate.FullName
}

$appData = [Environment]::GetFolderPath("ApplicationData")
$localAppData = [Environment]::GetFolderPath("LocalApplicationData")
$settingsPath = Join-Path $appData "Godot\editor_settings-4.6.tres"
$templateDir = Join-Path $appData "Godot\export_templates\$GodotVersion"
$androidDebugTemplate = Join-Path $templateDir "android_debug.apk"
$androidReleaseTemplate = Join-Path $templateDir "android_release.apk"

$editorJavaPath = Get-EditorSettingValue $settingsPath "export/android/java_sdk_path"
$editorSdkPath = Get-EditorSettingValue $settingsPath "export/android/android_sdk_path"
$sdkCandidates = @(
    $env:ANDROID_HOME,
    $env:ANDROID_SDK_ROOT,
    $editorSdkPath,
    (Join-Path $localAppData "Android\Sdk")
) | Where-Object { $_ -and $_.Trim() -ne "" } | Select-Object -Unique

$javaCommand = Get-Command java -ErrorAction SilentlyContinue
$javaPath = if ($editorJavaPath) { $editorJavaPath } elseif ($env:JAVA_HOME) { $env:JAVA_HOME } elseif ($javaCommand) { $javaCommand.Source } else { "" }
$sdkPath = ""
foreach ($candidate in $sdkCandidates) {
    if (Test-DirExists $candidate) {
        $sdkPath = $candidate
        break
    }
}

$adbPath = if ($sdkPath) { Join-Path $sdkPath "platform-tools\adb.exe" } else { "" }
$apkSignerPath = Find-ApkSigner $sdkPath
$presetPath = Join-Path $ProjectPath "export_presets.cfg"

$checks = @(
    [PSCustomObject]@{ Name = "Godot project"; Ok = (Test-DirExists $ProjectPath); Path = $ProjectPath },
    [PSCustomObject]@{ Name = "Android export preset"; Ok = (Test-FileExists $presetPath); Path = $presetPath },
    [PSCustomObject]@{ Name = "Android debug template"; Ok = (Test-FileExists $androidDebugTemplate); Path = $androidDebugTemplate },
    [PSCustomObject]@{ Name = "Android release template"; Ok = (Test-FileExists $androidReleaseTemplate); Path = $androidReleaseTemplate },
    [PSCustomObject]@{ Name = "Java/JDK"; Ok = [bool]$javaPath; Path = $javaPath },
    [PSCustomObject]@{ Name = "Android SDK"; Ok = (Test-DirExists $sdkPath); Path = $sdkPath },
    [PSCustomObject]@{ Name = "ADB"; Ok = (Test-FileExists $adbPath); Path = $adbPath },
    [PSCustomObject]@{ Name = "APK signer"; Ok = (Test-FileExists $apkSignerPath); Path = $apkSignerPath }
)

$checks | Format-Table -AutoSize

if ($checks.Ok -contains $false) {
    Write-Host ""
    Write-Host "Missing Android export prerequisites."
    Write-Host "Template download URL:"
    Write-Host "  https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_export_templates.tpz"
    Write-Host "Godot editor settings to fill after installing JDK/SDK:"
    Write-Host "  export/android/java_sdk_path"
    Write-Host "  export/android/android_sdk_path"
    exit 1
}

Write-Host ""
Write-Host "Android export prerequisites look ready."
