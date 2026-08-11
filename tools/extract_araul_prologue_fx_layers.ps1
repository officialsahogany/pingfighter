param(
    [string]$RuntimeDirectory = "godot/assets/ui/story/han_miryang_prologue",
    [string]$SourceOutputDirectory = "art_sources/araul_prologue/fx_layers",
    [switch]$Force
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

function Get-BitmapBytes {
    param([Parameter(Mandatory = $true)][Drawing.Bitmap]$Bitmap)
    $rect = [Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
    $data = $Bitmap.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $bytes = New-Object byte[] ([Math]::Abs($data.Stride) * $Bitmap.Height)
        [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
        return @{ Bytes = $bytes; Stride = $data.Stride }
    }
    finally {
        $Bitmap.UnlockBits($data)
    }
}

function Set-BitmapBytes {
    param([Parameter(Mandatory = $true)][Drawing.Bitmap]$Bitmap, [Parameter(Mandatory = $true)][byte[]]$Bytes)
    $rect = [Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
    $data = $Bitmap.LockBits($rect, [Drawing.Imaging.ImageLockMode]::WriteOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        if ($Bytes.Length -ne [Math]::Abs($data.Stride) * $Bitmap.Height) {
            throw "Output byte length does not match bitmap dimensions"
        }
        [Runtime.InteropServices.Marshal]::Copy($Bytes, 0, $data.Scan0, $Bytes.Length)
    }
    finally {
        $Bitmap.UnlockBits($data)
    }
}

function Export-FxLayer {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][string]$BaseFile,
        [Parameter(Mandatory = $true)][string]$TargetFile,
        [Parameter(Mandatory = $true)][string]$Mode,
        [object[]]$Rects = @(),
        [double[]]$Ellipse = @(),
        [int]$Padding = 8
    )

    $basePath = Join-Path $resolvedRuntimeDirectory $BaseFile
    $targetPath = Join-Path $resolvedRuntimeDirectory $TargetFile
    $sourceOutput = Join-Path $resolvedSourceDirectory ("araul_prologue_v2_{0}.png" -f $Key)
    $runtimeOutput = Join-Path $resolvedRuntimeDirectory ("araul_prologue_v2_{0}.png" -f $Key)
    foreach ($outputPath in @($sourceOutput, $runtimeOutput)) {
        if ((Test-Path -LiteralPath $outputPath) -and -not $Force) {
            throw "Refusing to overwrite existing FX layer without -Force: $outputPath"
        }
    }

    $baseSource = [Drawing.Image]::FromFile($basePath)
    $targetSource = [Drawing.Image]::FromFile($targetPath)
    try {
        if ($baseSource.Width -ne $targetSource.Width -or $baseSource.Height -ne $targetSource.Height) {
            throw "$Key base and target dimensions differ"
        }
        $base = New-ArgbBitmap -Source $baseSource
        $target = New-ArgbBitmap -Source $targetSource
        try {
            $baseData = Get-BitmapBytes -Bitmap $base
            $targetData = Get-BitmapBytes -Bitmap $target
            $width = $base.Width
            $height = $base.Height
            $fullBytes = New-Object byte[] ($baseData.Bytes.Length)
            $parsedRects = @()
            foreach ($rectValue in $Rects) {
                $values = @([string]$rectValue -split ',' | ForEach-Object {
                    [double]::Parse($_, [Globalization.CultureInfo]::InvariantCulture)
                })
                if ($values.Count -ne 4) {
                    throw "Expected normalized rect x0,y0,x1,y1, got: $rectValue"
                }
                $parsedRects += ,$values
            }
            $scanLeft = 0
            $scanTop = 0
            $scanRight = $width
            $scanBottom = $height
            if ($parsedRects.Count -gt 0) {
                $scanLeft = [Math]::Max(0, [Math]::Floor((($parsedRects | ForEach-Object { $_[0] }) | Measure-Object -Minimum).Minimum * $width))
                $scanTop = [Math]::Max(0, [Math]::Floor((($parsedRects | ForEach-Object { $_[1] }) | Measure-Object -Minimum).Minimum * $height))
                $scanRight = [Math]::Min($width, [Math]::Ceiling((($parsedRects | ForEach-Object { $_[2] }) | Measure-Object -Maximum).Maximum * $width))
                $scanBottom = [Math]::Min($height, [Math]::Ceiling((($parsedRects | ForEach-Object { $_[3] }) | Measure-Object -Maximum).Maximum * $height))
            }
            elseif ($Mode -eq "opaque_ellipse") {
                $scanLeft = [Math]::Max(0, [Math]::Floor(($Ellipse[0] - $Ellipse[2]) * $width))
                $scanTop = [Math]::Max(0, [Math]::Floor(($Ellipse[1] - $Ellipse[3]) * $height))
                $scanRight = [Math]::Min($width, [Math]::Ceiling(($Ellipse[0] + $Ellipse[2]) * $width))
                $scanBottom = [Math]::Min($height, [Math]::Ceiling(($Ellipse[1] + $Ellipse[3]) * $height))
            }
            $pixelCount = 0
            $minX = $width
            $minY = $height
            $maxX = -1
            $maxY = -1

            for ($y = $scanTop; $y -lt $scanBottom; $y++) {
                $ny = ([double]$y + 0.5) / $height
                for ($x = $scanLeft; $x -lt $scanRight; $x++) {
                    $nx = ([double]$x + 0.5) / $width
                    $inside = $true
                    if ($Mode -eq "opaque_rects" -or $Mode -eq "positive_cyan_rects") {
                        $inside = $false
                        foreach ($rect in $parsedRects) {
                            if ($nx -ge $rect[0] -and $nx -lt $rect[2] -and $ny -ge $rect[1] -and $ny -lt $rect[3]) {
                                $inside = $true
                                break
                            }
                        }
                    }
                    elseif ($Mode -eq "opaque_ellipse") {
                        $dx = ($nx - $Ellipse[0]) / $Ellipse[2]
                        $dy = ($ny - $Ellipse[1]) / $Ellipse[3]
                        $inside = $dx * $dx + $dy * $dy -le 1.0
                    }
                    if (-not $inside) {
                        continue
                    }

                    $offset = $y * $baseData.Stride + $x * 4
                    $baseBlue = [int]$baseData.Bytes[$offset]
                    $baseGreen = [int]$baseData.Bytes[$offset + 1]
                    $baseRed = [int]$baseData.Bytes[$offset + 2]
                    $targetBlue = [int]$targetData.Bytes[$offset]
                    $targetGreen = [int]$targetData.Bytes[$offset + 1]
                    $targetRed = [int]$targetData.Bytes[$offset + 2]
                    $maxDelta = [Math]::Max(
                        [Math]::Abs($targetBlue - $baseBlue),
                        [Math]::Max([Math]::Abs($targetGreen - $baseGreen), [Math]::Abs($targetRed - $baseRed))
                    )
                    if ($maxDelta -eq 0) {
                        continue
                    }

                    if ($Mode.StartsWith("positive_cyan")) {
                        $positiveBlue = [Math]::Max(0, $targetBlue - $baseBlue)
                        $positiveGreen = [Math]::Max(0, $targetGreen - $baseGreen)
                        $positiveRed = [Math]::Max(0, $targetRed - $baseRed)
                        $positiveMax = [Math]::Max($positiveBlue, [Math]::Max($positiveGreen, $positiveRed))
                        if ($targetBlue -le $targetRed + 16 -or $targetGreen -le $targetRed + 16 -or $positiveMax -lt 6) {
                            continue
                        }
                        $fullBytes[$offset] = [byte]$positiveBlue
                        $fullBytes[$offset + 1] = [byte]$positiveGreen
                        $fullBytes[$offset + 2] = [byte]$positiveRed
                    }
                    else {
                        $fullBytes[$offset] = [byte]$targetBlue
                        $fullBytes[$offset + 1] = [byte]$targetGreen
                        $fullBytes[$offset + 2] = [byte]$targetRed
                    }
                    $fullBytes[$offset + 3] = 255
                    $pixelCount++
                    $minX = [Math]::Min($minX, $x)
                    $minY = [Math]::Min($minY, $y)
                    $maxX = [Math]::Max($maxX, $x)
                    $maxY = [Math]::Max($maxY, $y)
                }
            }

            if ($pixelCount -le 0) {
                throw "$Key extraction produced no pixels"
            }
            $cropLeft = [Math]::Max(0, $minX - $Padding)
            $cropTop = [Math]::Max(0, $minY - $Padding)
            $cropRight = [Math]::Min($width - 1, $maxX + $Padding)
            $cropBottom = [Math]::Min($height - 1, $maxY + $Padding)
            $cropWidth = $cropRight - $cropLeft + 1
            $cropHeight = $cropBottom - $cropTop + 1
            $crop = New-Object Drawing.Bitmap($cropWidth, $cropHeight, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
            try {
                $cropStride = $cropWidth * 4
                $cropBytes = New-Object byte[] ($cropStride * $cropHeight)
                for ($cropY = 0; $cropY -lt $cropHeight; $cropY++) {
                    $sourceOffset = ($cropTop + $cropY) * $baseData.Stride + $cropLeft * 4
                    [Array]::Copy($fullBytes, $sourceOffset, $cropBytes, $cropY * $cropStride, $cropStride)
                }
                Set-BitmapBytes -Bitmap $crop -Bytes $cropBytes
                $crop.Save($sourceOutput, [Drawing.Imaging.ImageFormat]::Png)
                Copy-Item -LiteralPath $sourceOutput -Destination $runtimeOutput -Force
            }
            finally {
                $crop.Dispose()
            }

            $sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceOutput).Hash.ToLowerInvariant()
            return [ordered]@{
                key = $Key
                file = [IO.Path]::GetFileName($sourceOutput)
                base_file = $BaseFile
                target_file = $TargetFile
                mode = $Mode
                pixel_count = $pixelCount
                crop_offset = @($cropLeft, $cropTop)
                crop_size = @($cropWidth, $cropHeight)
                full_size = @($width, $height)
                sha256 = $sha
            }
        }
        finally {
            $base.Dispose()
            $target.Dispose()
        }
    }
    finally {
        $baseSource.Dispose()
        $targetSource.Dispose()
    }
}

$resolvedRuntimeDirectory = (Resolve-Path -LiteralPath $RuntimeDirectory).Path
$resolvedSourceDirectory = [IO.Path]::GetFullPath((Join-Path (Get-Location) $SourceOutputDirectory))
if (-not (Test-Path -LiteralPath $resolvedSourceDirectory)) {
    New-Item -ItemType Directory -Path $resolvedSourceDirectory | Out-Null
}

$results = @()
$results += Export-FxLayer -Key "fx_tablet" `
    -BaseFile "araul_prologue_v2_a1_coronation.png" `
    -TargetFile "araul_prologue_v2_a2_tablet.png" `
    -Mode "opaque_rects" `
    -Rects @("0.40,0.00,0.68,0.66")
$results += Export-FxLayer -Key "fx_orb" `
    -BaseFile "araul_prologue_v2_b1_resistance.png" `
    -TargetFile "araul_prologue_v2_b2_orb_extraction.png" `
    -Mode "opaque_ellipse" `
    -Ellipse @(0.535, 0.30, 0.13, 0.20)
$results += Export-FxLayer -Key "fx_rays" `
    -BaseFile "araul_prologue_v2_a1_coronation.png" `
    -TargetFile "araul_prologue_v2_c1_eight_rays.png" `
    -Mode "positive_cyan_full"
$results += Export-FxLayer -Key "fx_shard" `
    -BaseFile "araul_prologue_v2_d1_confrontation.png" `
    -TargetFile "araul_prologue_v2_d2_first_strike.png" `
    -Mode "positive_cyan_rects" `
    -Rects @("0.20,0.14,0.62,0.72")
$results += Export-FxLayer -Key "fx_tendril" `
    -BaseFile "araul_prologue_v2_a2_tablet.png" `
    -TargetFile "araul_prologue_v2_a3_spirit.png" `
    -Mode "opaque_rects" `
    -Rects @(
        "0.28,0.18,0.44,0.52",
        "0.28,0.16,0.36,0.26",
        "0.36,0.159,0.40,0.18"
    )

$reportPath = Join-Path $resolvedSourceDirectory "araul_prologue_v2_rev6_fx_extraction.json"
$report = [ordered]@{
    schema = "araul-prologue-v2-rev6-fx-extraction"
    source = "runtime 3344x1882 accepted plates"
    tool = "tools/extract_araul_prologue_fx_layers.ps1"
    layers = $results
}
[IO.File]::WriteAllText(
    $reportPath,
    (($report | ConvertTo-Json -Depth 8) + "`n"),
    [Text.UTF8Encoding]::new($false)
)
$results | ForEach-Object {
    Write-Output ("{0} pixels={1} offset={2},{3} size={4}x{5} sha256={6}" -f `
        $_.key, $_.pixel_count, $_.crop_offset[0], $_.crop_offset[1], $_.crop_size[0], $_.crop_size[1], $_.sha256)
}
Write-Output "report=$reportPath"
