param(
    [string]$RuntimeDirectory = "godot/assets/ui/story/han_miryang_prologue",
    [string]$SourceOutputDirectory = "art_sources/araul_prologue/fx_layers",
    [ValidateRange(0, 255)][int]$CyanMargin = 24,
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
        [object[]]$ExcludeEllipses = @(),
        [int]$Padding = 8
    )

    $basePath = Join-Path $resolvedRuntimeDirectory $BaseFile
    $targetPath = Join-Path $resolvedRuntimeDirectory $TargetFile
    $sourceOutput = Join-Path $resolvedSourceDirectory ("araul_prologue_v3_{0}.png" -f $Key)
    $runtimeOutput = Join-Path $resolvedRuntimeDirectory ("araul_prologue_v3_{0}.png" -f $Key)
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
            $parsedExcludeEllipses = @()
            foreach ($ellipseValue in $ExcludeEllipses) {
                $values = @([string]$ellipseValue -split ',' | ForEach-Object {
                    [double]::Parse($_, [Globalization.CultureInfo]::InvariantCulture)
                })
                if ($values.Count -ne 4) {
                    throw "Expected normalized exclusion ellipse cx,cy,rx,ry, got: $ellipseValue"
                }
                $parsedExcludeEllipses += ,$values
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
            $baseCyanDominantPixels = 0
            $cyanCandidatePixels = 0

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
                    if ($Mode -eq "positive_cyan_full" -and $baseBlue -gt $baseRed + $CyanMargin -and $baseGreen -gt $baseRed + $CyanMargin) {
                        $baseCyanDominantPixels++
                    }
                    $maxDelta = [Math]::Max(
                        [Math]::Abs($targetBlue - $baseBlue),
                        [Math]::Max([Math]::Abs($targetGreen - $baseGreen), [Math]::Abs($targetRed - $baseRed))
                    )
                    if ($maxDelta -eq 0) {
                        continue
                    }

                    $excluded = $false
                    foreach ($excludedEllipse in $parsedExcludeEllipses) {
                        $excludeDx = ($nx - $excludedEllipse[0]) / $excludedEllipse[2]
                        $excludeDy = ($ny - $excludedEllipse[1]) / $excludedEllipse[3]
                        if ($excludeDx * $excludeDx + $excludeDy * $excludeDy -le 1.0) {
                            $excluded = $true
                            break
                        }
                    }
                    if ($excluded) {
                        continue
                    }

                    if ($Mode.StartsWith("positive_cyan")) {
                        $positiveBlue = [Math]::Max(0, $targetBlue - $baseBlue)
                        $positiveGreen = [Math]::Max(0, $targetGreen - $baseGreen)
                        $positiveRed = [Math]::Max(0, $targetRed - $baseRed)
                        $positiveMax = [Math]::Max($positiveBlue, [Math]::Max($positiveGreen, $positiveRed))
                        if ($targetBlue -le $targetRed + $CyanMargin -or $targetGreen -le $targetRed + $CyanMargin -or $positiveMax -lt 6) {
                            continue
                        }
                        $cyanCandidatePixels++
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
                cyan_margin_8bit = $CyanMargin
                base_cyan_false_positive_pixels = $baseCyanDominantPixels
                base_cyan_false_positive_ratio = if ($Mode -eq "positive_cyan_full") { $baseCyanDominantPixels / [double]($width * $height) } else { 0.0 }
                cyan_candidate_pixels = $cyanCandidatePixels
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
    -BaseFile "araul_prologue_v3_a1_coronation.png" `
    -TargetFile "araul_prologue_v3_a2_tablet.png" `
    -Mode "opaque_ellipse" `
    -Ellipse @(0.525, 0.42, 0.085, 0.29)
$results += Export-FxLayer -Key "fx_orb" `
    -BaseFile "araul_prologue_v3_b1_resistance.png" `
    -TargetFile "araul_prologue_v3_b2_orb_extraction.png" `
    -Mode "opaque_ellipse" `
    -Ellipse @(0.555, 0.31, 0.095, 0.16)
$results += Export-FxLayer -Key "fx_rays" `
    -BaseFile "araul_prologue_v3_a1_coronation.png" `
    -TargetFile "araul_prologue_v3_c1_eight_rays.png" `
    -Mode "positive_cyan_full" `
    -ExcludeEllipses @("0.30,0.43,0.17,0.38", "0.61,0.56,0.075,0.19")
$results += Export-FxLayer -Key "fx_shard" `
    -BaseFile "araul_prologue_v3_d1_confrontation.png" `
    -TargetFile "araul_prologue_v3_d2_first_strike.png" `
    -Mode "positive_cyan_rects" `
    -Rects @("0.20,0.12,0.68,0.72") `
    -ExcludeEllipses @("0.295,0.255,0.065,0.115")

$reportPath = Join-Path $resolvedSourceDirectory "araul_prologue_v3_rev6_fx_extraction.json"
$report = [ordered]@{
    schema = "araul-prologue-v3-rev6-fx-extraction"
    source = "V3 runtime 3344x1882 accepted plates"
    tool = "tools/extract_araul_prologue_fx_layers.ps1"
    cyan_calibration = [ordered]@{
        channel_scale = "8-bit 0..255"
        selected_margin = $CyanMargin
        v3_a1_measured_false_positive_pixels = ($results | Where-Object { $_.key -eq "fx_rays" } | Select-Object -First 1).base_cyan_false_positive_pixels
        v3_a1_measured_false_positive_ratio = ($results | Where-Object { $_.key -eq "fx_rays" } | Select-Object -First 1).base_cyan_false_positive_ratio
        rationale = "margin 24 reduces the no-effect A1 cyan background from 152631 pixels at margin 16 to 5956 while retaining the eight C1 ray families"
    }
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
