#requires -Version 5.1

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scanner = Join-Path $PSScriptRoot "verify_no_project_secrets.ps1"
$tempRoot = Join-Path $repoRoot (".codex_tmp\secret_scan_verifier_{0}" -f $PID)
$cleanPath = Join-Path $tempRoot "clean.toml"
$secretPath = Join-Path $tempRoot "synthetic.env"

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $utf8TrackedPathProbe = "docs/" + (-join @(
        [char]0xD551, [char]0xD30C, [char]0xC774, [char]0xD130,
        [char]0x005F,
        [char]0xAE30, [char]0xBCF8, [char]0xAC00, [char]0xC774, [char]0xB4DC
    )) + ".html"
    $previousOutputEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(437)
        & $scanner `
            -RepoRoot $repoRoot `
            -TrackedOnly `
            -EnumerationProbePath $utf8TrackedPathProbe
    }
    finally {
        [Console]::OutputEncoding = $previousOutputEncoding
    }

    [System.IO.File]::WriteAllText(
        $cleanPath,
        'token = "${CONTEXT7_API_KEY}"' + "`n" +
            'Authorization = "Bearer ${AUTOSPRITE_API_KEY}"' + "`n" +
            ('image = "data:image/png;base64,AAAA' + ('AI' + 'za') + ('A' * 24) + 'BBBB"') + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    & $scanner -RepoRoot $repoRoot -Paths @($cleanPath)

    $syntheticValues = @(
        ('ctx7' + 'sk-' + ('A' * 24)),
        ('vs' + 'pk_' + ('B' * 24)),
        ('AI' + 'za' + ('C' * 24)),
        ('Bearer ' + ('D' * 24)),
        ('https://example.invalid/?' + ('X-Amz' + '-Signature=') + ('E' * 32))
    )
    [System.IO.File]::WriteAllText(
        $secretPath,
        ($syntheticValues -join "`n") + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    $captured = [System.Collections.Generic.List[string]]::new()
    $failure = ""
    try {
        & $scanner -RepoRoot $repoRoot -Paths @($secretPath) 6>&1 |
            ForEach-Object { $captured.Add($_.ToString()) }
    }
    catch {
        $failure = $_.Exception.Message
    }
    $capturedText = $captured -join "`n"
    foreach ($ruleId in @("context7", "autosprite", "google_ai", "literal_bearer", "signed_url")) {
        if ($capturedText -notmatch ("\[" + [regex]::Escape($ruleId) + "\]")) {
            throw "Secret scanner failed to reject synthetic rule: $ruleId"
        }
    }
    if ($failure -notmatch "Project secret scan rejected redacted findings") {
        throw "Secret scanner did not fail closed on synthetic credentials"
    }
    foreach ($syntheticValue in $syntheticValues) {
        if ($capturedText.Contains($syntheticValue) -or $failure.Contains($syntheticValue)) {
            throw "Secret scanner exposed a synthetic credential value"
        }
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Write-Host "project secret scanner regression: ok"
