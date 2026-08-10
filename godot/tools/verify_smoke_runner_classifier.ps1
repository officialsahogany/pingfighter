param(
    [string]$GodotExe = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_godot_exe.ps1")

$godotPath = Resolve-GodotConsolePath -GodotExe $GodotExe
$runnerPath = Join-Path $PSScriptRoot "run_smoke_tests.ps1"
$warningFixture = "res://tests/fixtures/runner_warning_backtrace_fixture.gd"
$benignTextFixture = "res://tests/fixtures/runner_benign_diagnostic_text_fixture.gd"
$errorFixture = "res://tests/fixtures/runner_error_backtrace_fixture.gd"
$scriptErrorFixture = "res://tests/fixtures/runner_script_error_line_fixture.gd"
$fatalFixture = "res://tests/fixtures/runner_fatal_line_fixture.gd"
$certificateSubstringFixture = "res://tests/fixtures/runner_certificate_substring_error_fixture.gd"
$exactCertificateFixture = "res://tests/fixtures/runner_exact_certificate_error_fixture.gd"

function Assert-RejectedBySmokeRunner {
    param(
        [string]$Fixture,
        [string]$Label
    )

    $failure = ""
    try {
        & $runnerPath -GodotExe $godotPath -ProjectPath $ProjectPath -Tests @($Fixture)
    }
    catch {
        $failure = $_.Exception.Message
    }

    if ($failure -notmatch "emitted a Godot error despite exit code 0") {
        throw "Smoke runner failed to reject the $Label fixture"
    }
}

# A warning includes a GDScript backtrace in Godot 4.6. That backtrace must not
# turn an otherwise successful smoke into a false failure.
& $runnerPath -GodotExe $godotPath -ProjectPath $ProjectPath -Tests @($warningFixture)

# Diagnostic words in ordinary test output are not engine severity markers.
& $runnerPath -GodotExe $godotPath -ProjectPath $ProjectPath -Tests @($benignTextFixture)

# Godot can emit this exact environment diagnostic on otherwise healthy runs.
# Only the exact line is accepted; certificate superstrings remain RED below.
& $runnerPath -GodotExe $godotPath -ProjectPath $ProjectPath -Tests @($exactCertificateFixture)

# Each real line-start severity must remain RED even when the fixture prints its
# ok marker and exits with code 0. These reverse legs prevent the classifier fix
# from becoming a blanket suppression or narrowing to ERROR: alone.
Assert-RejectedBySmokeRunner -Fixture $errorFixture -Label "error-backtrace"
Assert-RejectedBySmokeRunner -Fixture $scriptErrorFixture -Label "SCRIPT ERROR"
Assert-RejectedBySmokeRunner -Fixture $fatalFixture -Label "FATAL"
Assert-RejectedBySmokeRunner -Fixture $certificateSubstringFixture -Label "certificate-substring ERROR"

Write-Host "smoke runner classifier: ok"
