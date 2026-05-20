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

$apiKey = $env:GEMINI_API_KEY
$source = "env"

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    $sources = @(
        @{
            Path = (Join-Path $env:USERPROFILE ".vscode\mcp.json")
            Segments = @("mcpServers", "gemini", "env", "GEMINI_API_KEY")
            Name = "user-vscode-mcp"
        },
        @{
            Path = "d:\main\bosspong\.vscode\mcp.json"
            Segments = @("mcpServers", "gemini", "env", "GEMINI_API_KEY")
            Name = "project-vscode-mcp"
        },
        @{
            Path = (Join-Path $env:USERPROFILE ".claude\settings.json")
            Segments = @("mcpServers", "gemini", "env", "GEMINI_API_KEY")
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
    Write-Error "GEMINI_API_KEY not found in env, ~/.vscode/mcp.json, project .vscode/mcp.json, or ~/.claude/settings.json"
    exit 1
}

$tracePath = Join-Path $env:TEMP "gemini_mcp_wrapper_trace.log"
try {
    Add-Content -LiteralPath $tracePath -Value ("{0} source={1}" -f (Get-Date).ToString("s"), $source)
}
catch {
    # Tracing must never block MCP startup.
}

$env:GEMINI_API_KEY = $apiKey
$env:GEMINI_MCP_SKIP_STARTUP_CHECK = if ([string]::IsNullOrWhiteSpace($env:GEMINI_MCP_SKIP_STARTUP_CHECK)) { "true" } else { $env:GEMINI_MCP_SKIP_STARTUP_CHECK }
$env:QUIET = if ([string]::IsNullOrWhiteSpace($env:QUIET)) { "true" } else { $env:QUIET }
$repoRoot = Split-Path -Parent $PSScriptRoot
$serverPath = Join-Path $repoRoot "mcp\node_modules\@rlabs-inc\gemini-mcp\dist\index.js"

if (-not (Test-Path -LiteralPath $serverPath)) {
    Write-Error "Gemini MCP package not found at $serverPath. Run: npm install --prefix mcp @rlabs-inc/gemini-mcp"
    exit 1
}

$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
$nodePath = if ($nodeCommand) { $nodeCommand.Source } else { $null }

if ([string]::IsNullOrWhiteSpace($nodePath)) {
    $nodeCandidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        $nodeCandidates += (Join-Path $env:ProgramFiles "nodejs\node.exe")
    }
    if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
        $nodeCandidates += (Join-Path ${env:ProgramFiles(x86)} "nodejs\node.exe")
    }
    $nodeCandidates += "C:\Program Files\nodejs\node.exe"
    $nodeCandidates += "C:\Program Files (x86)\nodejs\node.exe"

    foreach ($candidate in $nodeCandidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            $nodePath = $candidate
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($nodePath)) {
    Write-Error "node.exe not found in PATH or standard Program Files locations"
    exit 1
}

& $nodePath $serverPath
