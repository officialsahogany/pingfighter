param(
    [Parameter(Mandatory = $true)]
    [string]$BasePath,

    [Parameter(Mandatory = $true)]
    [string]$EffectPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [double]$CenterX = (735.0 / 1672.0),
    [double]$CenterY = (485.0 / 941.0),
    [double]$AngleDegrees = 335.0,
    [double]$StartRadius = 120.0,
    [double]$EndRadius = 360.0,
    [double]$StartCoreHalfWidth = 12.0,
    [double]$EndCoreHalfWidth = 26.0,
    [double]$FeatherWidth = 6.0,
    [double]$CapFeather = 8.0
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

if ($EndRadius -le $StartRadius -or $StartCoreHalfWidth -le 0.0 -or $EndCoreHalfWidth -le 0.0 -or
    $FeatherWidth -le 0.0 -or $CapFeather -le 0.0) {
    throw "The tapered-capsule radii and feather widths must be positive"
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
        $cx = $CenterX * $base.Width
        $cy = $CenterY * $base.Height
        $radians = $AngleDegrees * [Math]::PI / 180.0
        $directionX = [Math]::Cos($radians)
        $directionY = -[Math]::Sin($radians)
        $changed = 0
        for ($y = 0; $y -lt $base.Height; $y++) {
            for ($x = 0; $x -lt $base.Width; $x++) {
                $dx = $x - $cx
                $dy = $y - $cy
                $along = $dx * $directionX + $dy * $directionY
                if ($along -le $StartRadius -or $along -ge $EndRadius) { continue }
                $across = [Math]::Abs(-$dx * $directionY + $dy * $directionX)
                $progress = ($along - $StartRadius) / ($EndRadius - $StartRadius)
                $coreHalfWidth = $StartCoreHalfWidth + ($EndCoreHalfWidth - $StartCoreHalfWidth) * $progress
                if ($across -ge $coreHalfWidth + $FeatherWidth) { continue }
                $startWeight = Get-SmoothStep -Value $along -Low $StartRadius -High ($StartRadius + $CapFeather)
                $endWeight = 1.0 - (Get-SmoothStep -Value $along -Low ($EndRadius - $CapFeather) -High $EndRadius)
                $acrossWeight = 1.0 - (Get-SmoothStep -Value $across -Low $coreHalfWidth -High ($coreHalfWidth + $FeatherWidth))
                $weight = $startWeight * $endWeight * $acrossWeight
                if ($weight -le 0.0) { continue }
                $offset = $y * $baseData.Stride + $x * 4
                $pixelChanged = $false
                for ($channel = 0; $channel -lt 4; $channel++) {
                    $effectValue = [double]$effectData.Bytes[$offset + $channel]
                    $baseValue = [double]$baseData.Bytes[$offset + $channel]
                    $result = [byte][Math]::Round($effectValue + ($baseValue - $effectValue) * $weight)
                    if ($result -ne $effectData.Bytes[$offset + $channel]) { $pixelChanged = $true }
                    $effectData.Bytes[$offset + $channel] = $result
                }
                if ($pixelChanged) { $changed++ }
            }
        }
        Set-BitmapBytes -Bitmap $effect -Bytes $effectData.Bytes
        $effect.Save($resolvedOutput, [Drawing.Imaging.ImageFormat]::Png)
        Write-Output "removed_angle=$AngleDegrees changed_pixels=$changed center=$CenterX,$CenterY radius=$StartRadius..$EndRadius width=$StartCoreHalfWidth..$EndCoreHalfWidth feather=$FeatherWidth"
        Write-Output "output=$resolvedOutput size=$($effect.Width)x$($effect.Height)"
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
