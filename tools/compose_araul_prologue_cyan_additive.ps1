param(
    [Parameter(Mandatory = $true)]
    [string]$BasePath,

    [Parameter(Mandatory = $true)]
    [string]$EffectPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [int]$ChromaLow = 12,
    [int]$ChromaHigh = 40,
    [int]$DeltaLow = 6,
    [int]$DeltaHigh = 28
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function New-ArgbBitmap {
    param([Drawing.Image]$Source)
    $bitmap = New-Object Drawing.Bitmap($Source.Width, $Source.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.DrawImageUnscaled($Source, 0, 0)
    }
    finally { $graphics.Dispose() }
    return $bitmap
}

function Get-BitmapBytes {
    param([Drawing.Bitmap]$Bitmap)
    $rect = [Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
    $data = $Bitmap.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $bytes = New-Object byte[] ([Math]::Abs($data.Stride) * $Bitmap.Height)
        [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
        return @{ Bytes = $bytes; Stride = $data.Stride }
    }
    finally { $Bitmap.UnlockBits($data) }
}

function Set-BitmapBytes {
    param([Drawing.Bitmap]$Bitmap, [byte[]]$Bytes)
    $rect = [Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
    $data = $Bitmap.LockBits($rect, [Drawing.Imaging.ImageLockMode]::WriteOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try { [Runtime.InteropServices.Marshal]::Copy($Bytes, 0, $data.Scan0, $Bytes.Length) }
    finally { $Bitmap.UnlockBits($data) }
}

function Get-SmoothStep {
    param([double]$Value, [double]$Low, [double]$High)
    if ($Value -le $Low) { return 0.0 }
    if ($Value -ge $High) { return 1.0 }
    $t = ($Value - $Low) / ($High - $Low)
    return $t * $t * (3.0 - 2.0 * $t)
}

$resolvedOutput = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
if (Test-Path -LiteralPath $resolvedOutput) { throw "Refusing to overwrite existing output: $resolvedOutput" }
$baseSource = [Drawing.Image]::FromFile((Resolve-Path -LiteralPath $BasePath))
$effectSource = [Drawing.Image]::FromFile((Resolve-Path -LiteralPath $EffectPath))
try {
    if ($baseSource.Width -ne $effectSource.Width -or $baseSource.Height -ne $effectSource.Height) {
        throw "Image dimensions differ"
    }
    $base = New-ArgbBitmap -Source $baseSource
    $effect = New-ArgbBitmap -Source $effectSource
    try {
        $baseData = Get-BitmapBytes -Bitmap $base
        $effectData = Get-BitmapBytes -Bitmap $effect
        $changed = 0
        $alphaPixels = 0
        for ($y = 0; $y -lt $base.Height; $y++) {
            for ($x = 0; $x -lt $base.Width; $x++) {
                $offset = $y * $baseData.Stride + $x * 4
                $baseBlue = [int]$baseData.Bytes[$offset]
                $baseGreen = [int]$baseData.Bytes[$offset + 1]
                $baseRed = [int]$baseData.Bytes[$offset + 2]
                $effectBlue = [int]$effectData.Bytes[$offset]
                $effectGreen = [int]$effectData.Bytes[$offset + 1]
                $effectRed = [int]$effectData.Bytes[$offset + 2]
                $chroma = [Math]::Min($effectBlue - $effectRed, $effectGreen - $effectRed)
                $positiveDelta = [Math]::Max(0, [Math]::Max($effectBlue - $baseBlue, [Math]::Max($effectGreen - $baseGreen, $effectRed - $baseRed)))
                $alpha = (Get-SmoothStep -Value $chroma -Low $ChromaLow -High $ChromaHigh) *
                    (Get-SmoothStep -Value $positiveDelta -Low $DeltaLow -High $DeltaHigh)
                if ($alpha -le 0.0) { continue }
                $alphaPixels++
                $pixelChanged = $false
                for ($channel = 0; $channel -lt 3; $channel++) {
                    $baseValue = [int]$baseData.Bytes[$offset + $channel]
                    $effectValue = [int]$effectData.Bytes[$offset + $channel]
                    $positive = [Math]::Max(0, $effectValue - $baseValue)
                    $result = [byte][Math]::Min(255, [Math]::Round($baseValue + $positive * $alpha))
                    if ($result -ne $baseData.Bytes[$offset + $channel]) { $pixelChanged = $true }
                    $baseData.Bytes[$offset + $channel] = $result
                }
                if ($pixelChanged) { $changed++ }
            }
        }
        Set-BitmapBytes -Bitmap $base -Bytes $baseData.Bytes
        $base.Save($resolvedOutput, [Drawing.Imaging.ImageFormat]::Png)
        Write-Output "alpha_pixels=$alphaPixels changed_pixels=$changed"
        Write-Output "output=$resolvedOutput size=$($base.Width)x$($base.Height)"
    }
    finally {
        $base.Dispose()
        $effect.Dispose()
    }
}
finally {
    $baseSource.Dispose()
    $effectSource.Dispose()
}
