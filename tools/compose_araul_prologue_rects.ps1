param(
    [Parameter(Mandatory = $true)]
    [string]$BasePath,

    [Parameter(Mandatory = $true)]
    [string]$EditedPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [string[]]$NormalizedRects
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function Resolve-NormalizedRect {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [Parameter(Mandatory = $true)]
        [int]$Width,
        [Parameter(Mandatory = $true)]
        [int]$Height
    )

    $parts = $Value.Split(',')
    if ($parts.Count -ne 4) {
        throw "Expected normalized rect x0,y0,x1,y1, got: $Value"
    }
    $values = @($parts | ForEach-Object {
        [double]::Parse($_, [Globalization.CultureInfo]::InvariantCulture)
    })
    if ($values[0] -lt 0.0 -or $values[1] -lt 0.0 -or
        $values[2] -gt 1.0 -or $values[3] -gt 1.0 -or
        $values[2] -le $values[0] -or $values[3] -le $values[1]) {
        throw "Invalid normalized rect: $Value"
    }

    $x0 = [Math]::Floor($values[0] * $Width)
    $y0 = [Math]::Floor($values[1] * $Height)
    $x1 = [Math]::Ceiling($values[2] * $Width)
    $y1 = [Math]::Ceiling($values[3] * $Height)
    return [Drawing.Rectangle]::FromLTRB($x0, $y0, $x1, $y1)
}

function Copy-RectPixels {
    param(
        [Parameter(Mandatory = $true)]
        [Drawing.Bitmap]$Source,
        [Parameter(Mandatory = $true)]
        [Drawing.Bitmap]$Destination,
        [Parameter(Mandatory = $true)]
        [Drawing.Rectangle]$Rect
    )

    $format = [Drawing.Imaging.PixelFormat]::Format32bppArgb
    $sourceData = $Source.LockBits($Rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, $format)
    $destinationData = $Destination.LockBits($Rect, [Drawing.Imaging.ImageLockMode]::WriteOnly, $format)
    try {
        $rowBytes = $Rect.Width * 4
        $row = New-Object byte[] $rowBytes
        for ($y = 0; $y -lt $Rect.Height; $y++) {
            $sourcePointer = [IntPtr]::Add($sourceData.Scan0, $y * $sourceData.Stride)
            $destinationPointer = [IntPtr]::Add($destinationData.Scan0, $y * $destinationData.Stride)
            [Runtime.InteropServices.Marshal]::Copy($sourcePointer, $row, 0, $rowBytes)
            [Runtime.InteropServices.Marshal]::Copy($row, 0, $destinationPointer, $rowBytes)
        }
    }
    finally {
        $Source.UnlockBits($sourceData)
        $Destination.UnlockBits($destinationData)
    }
}

$resolvedBase = (Resolve-Path -LiteralPath $BasePath).Path
$resolvedEdited = (Resolve-Path -LiteralPath $EditedPath).Path
$resolvedOutput = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}
if (Test-Path -LiteralPath $resolvedOutput) {
    throw "Refusing to overwrite existing output: $resolvedOutput"
}

$baseSource = [Drawing.Image]::FromFile($resolvedBase)
$editedSource = [Drawing.Image]::FromFile($resolvedEdited)
try {
    if ($baseSource.Width -ne $editedSource.Width -or $baseSource.Height -ne $editedSource.Height) {
        throw "Image dimensions differ: base=$($baseSource.Width)x$($baseSource.Height), edited=$($editedSource.Width)x$($editedSource.Height)"
    }

    $base = New-Object Drawing.Bitmap($baseSource.Width, $baseSource.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $edited = New-Object Drawing.Bitmap($editedSource.Width, $editedSource.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $output = New-Object Drawing.Bitmap($baseSource.Width, $baseSource.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        foreach ($pair in @(@($baseSource, $base), @($editedSource, $edited))) {
            $graphics = [Drawing.Graphics]::FromImage($pair[1])
            try {
                $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.DrawImageUnscaled($pair[0], 0, 0)
            }
            finally {
                $graphics.Dispose()
            }
        }

        $fullRect = New-Object Drawing.Rectangle(0, 0, $base.Width, $base.Height)
        Copy-RectPixels -Source $base -Destination $output -Rect $fullRect
        foreach ($value in $NormalizedRects) {
            $rect = Resolve-NormalizedRect -Value $value -Width $base.Width -Height $base.Height
            Copy-RectPixels -Source $edited -Destination $output -Rect $rect
            Write-Output "copied_rect=$($rect.X),$($rect.Y),$($rect.Width),$($rect.Height) normalized=$value"
        }

        $output.Save($resolvedOutput, [Drawing.Imaging.ImageFormat]::Png)
        Write-Output "output=$resolvedOutput size=$($output.Width)x$($output.Height)"
    }
    finally {
        $base.Dispose()
        $edited.Dispose()
        $output.Dispose()
    }
}
finally {
    $baseSource.Dispose()
    $editedSource.Dispose()
}
