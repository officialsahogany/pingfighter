param(
    [Parameter(Mandatory = $true)]
    [string]$BasePath,

    [Parameter(Mandatory = $true)]
    [string]$EditedPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [double]$CenterX,

    [Parameter(Mandatory = $true)]
    [double]$CenterY,

    [Parameter(Mandatory = $true)]
    [double]$RadiusX,

    [Parameter(Mandatory = $true)]
    [double]$RadiusY,

    [ValidateRange(0.0, 0.99)]
    [double]$InnerRatio = 0.78
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
    finally {
        $graphics.Dispose()
    }
    return $bitmap
}

function Get-BitmapBytes {
    param([Drawing.Bitmap]$Bitmap)
    $rect = [Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
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
    $rect = [Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
    $data = $Bitmap.LockBits($rect, [Drawing.Imaging.ImageLockMode]::WriteOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        [Runtime.InteropServices.Marshal]::Copy($Bytes, 0, $data.Scan0, $Bytes.Length)
    }
    finally {
        $Bitmap.UnlockBits($data)
    }
}

function Get-SmoothWeight {
    param([double]$Distance, [double]$Inner)
    if ($Distance -le $Inner) { return 1.0 }
    if ($Distance -ge 1.0) { return 0.0 }
    $t = (1.0 - $Distance) / (1.0 - $Inner)
    return $t * $t * (3.0 - 2.0 * $t)
}

$resolvedBase = (Resolve-Path -LiteralPath $BasePath).Path
$resolvedEdited = (Resolve-Path -LiteralPath $EditedPath).Path
$resolvedOutput = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
if (Test-Path -LiteralPath $resolvedOutput) {
    throw "Refusing to overwrite existing output: $resolvedOutput"
}

$baseSource = [Drawing.Image]::FromFile($resolvedBase)
$editedSource = [Drawing.Image]::FromFile($resolvedEdited)
try {
    if ($baseSource.Width -ne $editedSource.Width -or $baseSource.Height -ne $editedSource.Height) {
        throw "Image dimensions differ"
    }
    $base = New-ArgbBitmap -Source $baseSource
    $edited = New-ArgbBitmap -Source $editedSource
    try {
        $baseData = Get-BitmapBytes -Bitmap $base
        $editedData = Get-BitmapBytes -Bitmap $edited
        $cx = $CenterX * $base.Width
        $cy = $CenterY * $base.Height
        $rx = $RadiusX * $base.Width
        $ry = $RadiusY * $base.Height
        if ($rx -le 0.0 -or $ry -le 0.0) {
            throw "Ellipse radii must be positive"
        }

        $changed = 0
        $minX = $base.Width
        $minY = $base.Height
        $maxX = -1
        $maxY = -1
        $x0 = [Math]::Max(0, [Math]::Floor($cx - $rx))
        $x1 = [Math]::Min($base.Width - 1, [Math]::Ceiling($cx + $rx))
        $y0 = [Math]::Max(0, [Math]::Floor($cy - $ry))
        $y1 = [Math]::Min($base.Height - 1, [Math]::Ceiling($cy + $ry))
        for ($y = $y0; $y -le $y1; $y++) {
            for ($x = $x0; $x -le $x1; $x++) {
                $dx = ($x - $cx) / $rx
                $dy = ($y - $cy) / $ry
                $weight = Get-SmoothWeight -Distance ([Math]::Sqrt($dx * $dx + $dy * $dy)) -Inner $InnerRatio
                if ($weight -le 0.0) {
                    continue
                }
                $offset = $y * $baseData.Stride + $x * 4
                $pixelChanged = $false
                for ($channel = 0; $channel -lt 4; $channel++) {
                    $baseValue = [double]$baseData.Bytes[$offset + $channel]
                    $editedValue = [double]$editedData.Bytes[$offset + $channel]
                    $result = [Math]::Round($baseValue + ($editedValue - $baseValue) * $weight)
                    $result = [Math]::Max(0, [Math]::Min(255, $result))
                    if ([byte]$result -ne $baseData.Bytes[$offset + $channel]) {
                        $pixelChanged = $true
                    }
                    $baseData.Bytes[$offset + $channel] = [byte]$result
                }
                if ($pixelChanged) {
                    $changed++
                    $minX = [Math]::Min($minX, $x)
                    $minY = [Math]::Min($minY, $y)
                    $maxX = [Math]::Max($maxX, $x)
                    $maxY = [Math]::Max($maxY, $y)
                }
            }
        }
        Set-BitmapBytes -Bitmap $base -Bytes $baseData.Bytes
        $base.Save($resolvedOutput, [Drawing.Imaging.ImageFormat]::Png)
        Write-Output "changed_pixels=$changed bbox=$minX,$minY,$($maxX-$minX+1),$($maxY-$minY+1) ellipse=$CenterX,$CenterY,$RadiusX,$RadiusY inner=$InnerRatio"
        Write-Output "output=$resolvedOutput size=$($base.Width)x$($base.Height)"
    }
    finally {
        $base.Dispose()
        $edited.Dispose()
    }
}
finally {
    $baseSource.Dispose()
    $editedSource.Dispose()
}
