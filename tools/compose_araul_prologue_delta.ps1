param(
    [Parameter(Mandatory = $true)]
    [string]$BasePath,

    [Parameter(Mandatory = $true)]
    [string]$DeltaFromPath,

    [Parameter(Mandatory = $true)]
    [string]$DeltaToPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$NormalizedBounds = "0,0,1,1",

    [ValidateRange(0, 255)]
    [int]$Threshold = 0
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function New-ArgbBitmap {
    param([Parameter(Mandatory = $true)][Drawing.Image]$Source)
    $bitmap = New-Object Drawing.Bitmap($Source.Width, $Source.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.DrawImageUnscaled($Source, 0, 0)
    }
    finally {
        $graphics.Dispose()
    }
    return $bitmap
}

function Resolve-NormalizedRect {
    param([string]$Value, [int]$Width, [int]$Height)
    $parts = $Value.Split(',')
    if ($parts.Count -ne 4) {
        throw "Expected normalized bounds x0,y0,x1,y1, got: $Value"
    }
    $values = @($parts | ForEach-Object {
        [double]::Parse($_, [Globalization.CultureInfo]::InvariantCulture)
    })
    if ($values[0] -lt 0.0 -or $values[1] -lt 0.0 -or
        $values[2] -gt 1.0 -or $values[3] -gt 1.0 -or
        $values[2] -le $values[0] -or $values[3] -le $values[1]) {
        throw "Invalid normalized bounds: $Value"
    }
    return [Drawing.Rectangle]::FromLTRB(
        [Math]::Floor($values[0] * $Width),
        [Math]::Floor($values[1] * $Height),
        [Math]::Ceiling($values[2] * $Width),
        [Math]::Ceiling($values[3] * $Height)
    )
}

function Get-BitmapBytes {
    param([Parameter(Mandatory = $true)][Drawing.Bitmap]$Bitmap)
    $rect = New-Object Drawing.Rectangle(0, 0, $Bitmap.Width, $Bitmap.Height)
    $data = $Bitmap.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $length = [Math]::Abs($data.Stride) * $Bitmap.Height
        $bytes = New-Object byte[] $length
        [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $length)
        return @{ Bytes = $bytes; Stride = $data.Stride }
    }
    finally {
        $Bitmap.UnlockBits($data)
    }
}

function Set-BitmapBytes {
    param([Drawing.Bitmap]$Bitmap, [byte[]]$Bytes)
    $rect = New-Object Drawing.Rectangle(0, 0, $Bitmap.Width, $Bitmap.Height)
    $data = $Bitmap.LockBits($rect, [Drawing.Imaging.ImageLockMode]::WriteOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $length = [Math]::Abs($data.Stride) * $Bitmap.Height
        if ($Bytes.Length -ne $length) {
            throw "Byte length mismatch: bytes=$($Bytes.Length), bitmap=$length"
        }
        [Runtime.InteropServices.Marshal]::Copy($Bytes, 0, $data.Scan0, $length)
    }
    finally {
        $Bitmap.UnlockBits($data)
    }
}

$resolvedBase = (Resolve-Path -LiteralPath $BasePath).Path
$resolvedFrom = (Resolve-Path -LiteralPath $DeltaFromPath).Path
$resolvedTo = (Resolve-Path -LiteralPath $DeltaToPath).Path
$resolvedOutput = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
if (Test-Path -LiteralPath $resolvedOutput) {
    throw "Refusing to overwrite existing output: $resolvedOutput"
}
$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$baseSource = [Drawing.Image]::FromFile($resolvedBase)
$fromSource = [Drawing.Image]::FromFile($resolvedFrom)
$toSource = [Drawing.Image]::FromFile($resolvedTo)
try {
    if ($baseSource.Width -ne $fromSource.Width -or $baseSource.Height -ne $fromSource.Height -or
        $baseSource.Width -ne $toSource.Width -or $baseSource.Height -ne $toSource.Height) {
        throw "All images must have identical dimensions"
    }
    $base = New-ArgbBitmap -Source $baseSource
    $from = New-ArgbBitmap -Source $fromSource
    $to = New-ArgbBitmap -Source $toSource
    try {
        $baseData = Get-BitmapBytes -Bitmap $base
        $fromData = Get-BitmapBytes -Bitmap $from
        $toData = Get-BitmapBytes -Bitmap $to
        if ($baseData.Stride -ne $fromData.Stride -or $baseData.Stride -ne $toData.Stride) {
            throw "Bitmap strides differ"
        }

        $bounds = Resolve-NormalizedRect -Value $NormalizedBounds -Width $base.Width -Height $base.Height
        $changed = 0
        $minX = $base.Width
        $minY = $base.Height
        $maxX = -1
        $maxY = -1
        for ($y = $bounds.Top; $y -lt $bounds.Bottom; $y++) {
            for ($x = $bounds.Left; $x -lt $bounds.Right; $x++) {
                $offset = $y * $baseData.Stride + $x * 4
                $isDifferent = $false
                for ($channel = 0; $channel -lt 4; $channel++) {
                    if ([Math]::Abs([int]$toData.Bytes[$offset + $channel] - [int]$fromData.Bytes[$offset + $channel]) -gt $Threshold) {
                        $isDifferent = $true
                        break
                    }
                }
                if (-not $isDifferent) {
                    continue
                }
                for ($channel = 0; $channel -lt 4; $channel++) {
                    $baseData.Bytes[$offset + $channel] = $toData.Bytes[$offset + $channel]
                }
                $changed++
                $minX = [Math]::Min($minX, $x)
                $minY = [Math]::Min($minY, $y)
                $maxX = [Math]::Max($maxX, $x)
                $maxY = [Math]::Max($maxY, $y)
            }
        }
        Set-BitmapBytes -Bitmap $base -Bytes $baseData.Bytes
        $base.Save($resolvedOutput, [Drawing.Imaging.ImageFormat]::Png)
        $bbox = "none"
        if ($changed -gt 0) {
            $bbox = "$minX,$minY,$($maxX - $minX + 1),$($maxY - $minY + 1)"
        }
        Write-Output "changed_pixels=$changed bbox=$bbox bounds=$NormalizedBounds threshold=$Threshold"
        Write-Output "output=$resolvedOutput size=$($base.Width)x$($base.Height)"
    }
    finally {
        $base.Dispose()
        $from.Dispose()
        $to.Dispose()
    }
}
finally {
    $baseSource.Dispose()
    $fromSource.Dispose()
    $toSource.Dispose()
}
