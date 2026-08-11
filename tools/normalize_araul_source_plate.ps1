param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [int]$TargetWidth = 1672,
    [int]$TargetHeight = 941
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) {
    [IO.Path]::GetFullPath($OutputPath)
}
else {
    [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
}
if (Test-Path -LiteralPath $resolvedOutput) {
    throw "Refusing to overwrite existing output: $resolvedOutput"
}
$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$source = [Drawing.Bitmap]::FromFile($resolvedInput)
try {
    if ($source.Height -ne $TargetHeight) {
        throw "Unexpected source height: $($source.Height), expected $TargetHeight"
    }
    $missingColumns = $TargetWidth - $source.Width
    if ($missingColumns -lt 0 -or $missingColumns -gt 2) {
        throw "Unexpected source width: $($source.Width), expected $TargetWidth, $($TargetWidth - 1), or $($TargetWidth - 2)"
    }

    $output = [Drawing.Bitmap]::new($TargetWidth, $TargetHeight, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($output)
    try {
        $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.DrawImageUnscaled($source, 0, 0)
        if ($missingColumns -gt 0) {
            $lastSourceColumn = [Drawing.Rectangle]::new(($source.Width - 1), 0, 1, $TargetHeight)
            for ($x = $source.Width; $x -lt $TargetWidth; $x++) {
                $lastOutputColumn = [Drawing.Rectangle]::new($x, 0, 1, $TargetHeight)
                $graphics.DrawImage($source, $lastOutputColumn, $lastSourceColumn, [Drawing.GraphicsUnit]::Pixel)
            }
        }
    }
    finally {
        $graphics.Dispose()
    }
    $output.Save($resolvedOutput, [Drawing.Imaging.ImageFormat]::Png)
    $output.Dispose()

    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedOutput).Hash.ToLowerInvariant()
    Write-Output "input=$resolvedInput source_size=$($source.Width)x$($source.Height)"
    Write-Output "output=$resolvedOutput size=$($TargetWidth)x$($TargetHeight) sha256=$hash"
}
finally {
    $source.Dispose()
}
