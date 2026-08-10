$ErrorActionPreference = "Stop"

function Get-JsonValue {
    param(
        [string]$Path,
        [string[]]$Segments
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        $data = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
        $value = $data
        foreach ($segment in $Segments) {
            if ($null -eq $value) {
                return $null
            }
            $value = $value.$segment
        }
        return $value
    }
    catch {
        return $null
    }
}

$apiKey = $env:BFL_API_KEY
$source = "env"

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    $sources = @(
        @{
            Path = (Join-Path $env:USERPROFILE ".vscode\mcp.json")
            Segments = @("mcpServers", "flux-kontext", "env", "BFL_API_KEY")
            Name = "user-vscode-mcp"
        },
        @{
            Path = "d:\main\bosspong\.vscode\mcp.json"
            Segments = @("mcpServers", "flux-kontext", "env", "BFL_API_KEY")
            Name = "project-vscode-mcp"
        },
        @{
            Path = (Join-Path $env:USERPROFILE ".claude\settings.json")
            Segments = @("mcpServers", "flux-kontext", "env", "BFL_API_KEY")
            Name = "user-claude-settings"
        }
    )

    foreach ($candidate in $sources) {
        $apiKey = Get-JsonValue -Path $candidate.Path -Segments $candidate.Segments
        if (-not [string]::IsNullOrWhiteSpace($apiKey)) {
            $source = $candidate.Name
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Error "BFL_API_KEY not found in env, ~/.vscode/mcp.json, project .vscode/mcp.json, or ~/.claude/settings.json"
    exit 1
}

$tracePath = Join-Path $env:TEMP "flux_kontext_mcp_wrapper_trace.log"
Add-Content -LiteralPath $tracePath -Value ("{0} source={1}" -f (Get-Date).ToString("s"), $source)
[Console]::Error.WriteLine("WRAPPER_START source=$source")

$env:BFL_API_KEY = $apiKey
$serverPath = Join-Path $env:USERPROFILE ".claude\mcp-servers\flux-kontext-mcp\server.js"
& node $serverPath
