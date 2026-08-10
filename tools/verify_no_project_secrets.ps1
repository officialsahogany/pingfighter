param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$TrackedOnly,
    [string[]]$Paths = @()
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path -LiteralPath $RepoRoot).Path

$textExtensions = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
foreach ($extension in @(
    ".cfg", ".conf", ".cs", ".env", ".gd", ".html", ".ini", ".js",
    ".json", ".md", ".properties", ".ps1", ".py", ".sh", ".toml",
    ".ts", ".tsv", ".txt", ".xml", ".yaml", ".yml"
)) {
    $null = $textExtensions.Add($extension)
}

$rules = [ordered]@{
    context7 = [regex]::Escape(('ctx7' + 'sk-')) + '[A-Za-z0-9_-]{20,64}'
    autosprite = [regex]::Escape(('vs' + 'pk_')) + '[A-Za-z0-9_-]{20,80}'
    google_ai = [regex]::Escape(('AI' + 'za')) + '[A-Za-z0-9_-]{20,80}'
    literal_bearer = '(?i)\bBearer\s+(?!\$\{)[A-Za-z0-9._-]{20,}'
    signed_url = '(?i)(' + ('X-Amz' + '-Signature') + '|' +
        ('X-Goog' + '-Signature') + '|[?&]sig=[A-Za-z0-9%._~-]{12,})'
}

function Get-DisplayPath {
    param([string]$AbsolutePath)

    $repoPrefix = $repo.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if ($AbsolutePath.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $AbsolutePath.Substring($repoPrefix.Length).Replace('\', '/')
    }
    return [System.IO.Path]::GetFileName($AbsolutePath)
}

function Test-TextCandidate {
    param([string]$Path)

    $name = [System.IO.Path]::GetFileName($Path)
    if ($name -in @(".env", ".env.save")) {
        return $true
    }
    return $textExtensions.Contains([System.IO.Path]::GetExtension($Path))
}

$scanPaths = [System.Collections.Generic.List[string]]::new()
if ($Paths.Count -gt 0) {
    foreach ($path in $Paths) {
        $absolute = if ([System.IO.Path]::IsPathRooted($path)) {
            [System.IO.Path]::GetFullPath($path)
        } else {
            [System.IO.Path]::GetFullPath((Join-Path $repo $path))
        }
        if (Test-Path -LiteralPath $absolute -PathType Leaf) {
            $scanPaths.Add($absolute)
        }
    }
} else {
    $tracked = @(& git -c core.quotepath=false -C $repo ls-files --cached)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to enumerate tracked project files"
    }
    foreach ($relative in $tracked) {
        $absolute = [System.IO.Path]::GetFullPath((Join-Path $repo $relative))
        if ((Test-Path -LiteralPath $absolute -PathType Leaf) -and
            (Test-TextCandidate -Path $absolute)) {
            $scanPaths.Add($absolute)
        }
    }

    if (-not $TrackedOnly) {
        foreach ($relative in @(
            ".mcp.json",
            ".codex/config.toml",
            ".vscode/mcp.json",
            "mcp/.env.save",
            ".claude/settings.json"
        )) {
            $absolute = [System.IO.Path]::GetFullPath((Join-Path $repo $relative))
            if ((Test-Path -LiteralPath $absolute -PathType Leaf) -and
                -not $scanPaths.Contains($absolute)) {
                $scanPaths.Add($absolute)
            }
        }
    }
}

$findings = [System.Collections.Generic.List[object]]::new()
foreach ($path in $scanPaths) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($path)
    }
    catch {
        $findings.Add([pscustomobject]@{
            Path = Get-DisplayPath -AbsolutePath $path
            Rule = "unreadable"
        })
        continue
    }
    if ($bytes -contains 0) {
        continue
    }
    $text = [System.Text.UTF8Encoding]::new($false, $false).GetString($bytes)
    # Standalone HTML exports embed multi-megabyte images as base64 data URLs.
    # Their random alphabet can contain credential-looking prefixes by chance;
    # the payload is binary content, not project configuration or source text.
    $text = [regex]::Replace(
        $text,
        '(?is)data:[^;,\s]+;base64,[A-Za-z0-9+/=\r\n]+',
        '[embedded-data-redacted]'
    )
    foreach ($rule in $rules.GetEnumerator()) {
        if ([regex]::IsMatch($text, $rule.Value)) {
            $findings.Add([pscustomobject]@{
                Path = Get-DisplayPath -AbsolutePath $path
                Rule = $rule.Key
            })
        }
    }
}

if ($findings.Count -gt 0) {
    Write-Host "project secret scan: RED ($($findings.Count) finding(s))"
    foreach ($finding in $findings) {
        Write-Host ("  - {0} [{1}]" -f $finding.Path, $finding.Rule)
    }
    throw "Project secret scan rejected redacted findings"
}

Write-Host "project secret scan: ok ($($scanPaths.Count) files)"
