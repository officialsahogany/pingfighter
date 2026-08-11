param(
    [Parameter(Mandatory = $true)]
    [string]$A1Path,

    [Parameter(Mandatory = $true)]
    [string]$C1Path
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function New-RgbBitmap {
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

function Get-Luma {
    param([byte[]]$Bytes, [int]$Offset)
    $blue = [double]$Bytes[$Offset]
    $green = [double]$Bytes[$Offset + 1]
    $red = [double]$Bytes[$Offset + 2]
    return 0.0722 * $blue + 0.7152 * $green + 0.2126 * $red
}

function Get-CircularDistanceDegrees {
    param([int]$A, [int]$B)
    $delta = [Math]::Abs($A - $B) % 360
    return [Math]::Min($delta, 360 - $delta)
}

function Test-InEllipse {
    param([double]$X, [double]$Y, [double[]]$Ellipse, [int]$Width, [int]$Height)
    $dx = ($X - $Ellipse[0] * $Width) / ($Ellipse[2] * $Width)
    $dy = ($Y - $Ellipse[1] * $Height) / ($Ellipse[3] * $Height)
    return ($dx * $dx + $dy * $dy) -le 1.000001
}

function Test-InRayCapsule {
    param([double]$X, [double]$Y, [double]$AngleDegrees)
    $centerX = 835.0
    $centerY = 350.0
    $radians = $AngleDegrees * [Math]::PI / 180.0
    $directionX = [Math]::Cos($radians)
    $directionY = -[Math]::Sin($radians)
    $dx = $X - $centerX
    $dy = $Y - $centerY
    $along = $dx * $directionX + $dy * $directionY
    if ($along -lt 24.0 -or $along -gt 1050.0) { return $false }
    $progress = ($along - 24.0) / (1050.0 - 24.0)
    $halfWidth = 7.0 + 11.0 * $progress + 4.1
    $across = [Math]::Abs(-$dx * $directionY + $dy * $directionX)
    return $across -le $halfWidth
}

function Get-RayBandsAtRadius {
    param(
        [bool[]]$Effect,
        [int]$Width,
        [int]$Height,
        [double]$CenterX,
        [double]$CenterY,
        [int]$Radius,
        [int]$Thickness = 2
    )

    $flags = New-Object bool[] 360
    for ($angle = 0; $angle -lt 360; $angle++) {
        $radians = $angle * [Math]::PI / 180.0
        $cosine = [Math]::Cos($radians)
        $sine = [Math]::Sin($radians)
        for ($radialOffset = -$Thickness; $radialOffset -le $Thickness; $radialOffset++) {
            $sampleRadius = $Radius + $radialOffset
            $x = [int][Math]::Round($CenterX + $cosine * $sampleRadius)
            $y = [int][Math]::Round($CenterY - $sine * $sampleRadius)
            if ($x -ge 0 -and $x -lt $Width -and $y -ge 0 -and $y -lt $Height -and
                $Effect[$y * $Width + $x]) {
                $flags[$angle] = $true
                break
            }
        }
    }

    # Close circular angular gaps of at most two degrees inside a thick band.
    $closed = [bool[]]$flags.Clone()
    for ($angle = 0; $angle -lt 360; $angle++) {
        if (-not $flags[$angle]) { continue }
        for ($gap = 1; $gap -le 2; $gap++) {
            $other = ($angle + $gap + 1) % 360
            if (-not $flags[$other]) { continue }
            for ($fill = 1; $fill -le $gap; $fill++) {
                $closed[($angle + $fill) % 360] = $true
            }
        }
    }

    $falseAnchor = -1
    for ($angle = 0; $angle -lt 360; $angle++) {
        if (-not $closed[$angle]) {
            $falseAnchor = $angle
            break
        }
    }
    if ($falseAnchor -lt 0) {
        return @()
    }

    $bands = New-Object Collections.Generic.List[object]
    $runStart = -1
    $runLength = 0
    for ($step = 1; $step -le 360; $step++) {
        $angle = ($falseAnchor + $step) % 360
        if ($closed[$angle]) {
            if ($runStart -lt 0) { $runStart = $angle }
            $runLength++
        }
        elseif ($runStart -ge 0) {
            if ($runLength -ge 3) {
                $center = [int][Math]::Round(($runStart + ($runLength - 1) * 0.5) % 360)
                $bands.Add([pscustomobject]@{ Center = $center; Width = $runLength })
            }
            $runStart = -1
            $runLength = 0
        }
    }
    if ($runStart -ge 0 -and $runLength -ge 3) {
        $center = [int][Math]::Round(($runStart + ($runLength - 1) * 0.5) % 360)
        $bands.Add([pscustomobject]@{ Center = $center; Width = $runLength })
    }
    return @($bands | Sort-Object Center)
}

$a1Source = [Drawing.Image]::FromFile((Resolve-Path -LiteralPath $A1Path))
$c1Source = [Drawing.Image]::FromFile((Resolve-Path -LiteralPath $C1Path))
try {
    if ($a1Source.Width -ne 1672 -or $a1Source.Height -ne 941) {
        throw "A1 must be the 1672x941 source plate"
    }
    if ($c1Source.Width -ne $a1Source.Width -or $c1Source.Height -ne $a1Source.Height) {
        throw "C1 dimensions differ from A1"
    }

    $a1 = New-RgbBitmap -Source $a1Source
    $c1 = New-RgbBitmap -Source $c1Source
    try {
        $a1Data = Get-BitmapBytes -Bitmap $a1
        $c1Data = Get-BitmapBytes -Bitmap $c1
        $width = $a1.Width
        $height = $a1.Height
        $pixelCount = $width * $height
        $effect = New-Object bool[] $pixelCount
        $baselineCount = 0
        $effectCount = 0
        $negativeChannelPixels = 0
        $negativeOutsideSemanticMasks = 0
        $rightBandChanged = 0
        $rightBandPixels = 0

        $rayAngles = @(35.5, 75.5, 121.5, 158.5, 199.5, 247.5, 305.5, 356.0)
        $characterEllipses = @([double[]]@(0.30, 0.43, 0.17, 0.38), [double[]]@(0.61, 0.56, 0.075, 0.19))

        for ($y = 0; $y -lt $height; $y++) {
            for ($x = 0; $x -lt $width; $x++) {
                $offsetA = $y * $a1Data.Stride + $x * 4
                $offsetC = $y * $c1Data.Stride + $x * 4
                $aBlue = [int]$a1Data.Bytes[$offsetA]
                $aGreen = [int]$a1Data.Bytes[$offsetA + 1]
                $aRed = [int]$a1Data.Bytes[$offsetA + 2]
                $cBlue = [int]$c1Data.Bytes[$offsetC]
                $cGreen = [int]$c1Data.Bytes[$offsetC + 1]
                $cRed = [int]$c1Data.Bytes[$offsetC + 2]

                if ($aBlue -gt $aRed + 32 -and $aGreen -gt $aRed + 32) {
                    $baselineCount++
                }
                $delta = [Math]::Max([Math]::Abs($cBlue - $aBlue), [Math]::Max([Math]::Abs($cGreen - $aGreen), [Math]::Abs($cRed - $aRed)))
                $hasNegativeDelta = $cBlue -lt $aBlue -or $cGreen -lt $aGreen -or $cRed -lt $aRed
                if ($hasNegativeDelta) {
                    $negativeChannelPixels++
                }
                if ($cBlue -gt $cRed + 24 -and $cGreen -gt $cRed + 24 -and $delta -ge 20) {
                    $effect[$y * $width + $x] = $true
                    $effectCount++
                }
                if ($hasNegativeDelta) {
                    $allowed = $false
                    foreach ($ellipse in $characterEllipses) {
                        if (Test-InEllipse -X $x -Y $y -Ellipse $ellipse -Width $width -Height $height) {
                            $allowed = $true
                            break
                        }
                    }
                    if (-not $allowed) {
                        foreach ($angle in $rayAngles) {
                            if (Test-InRayCapsule -X $x -Y $y -AngleDegrees $angle) {
                                $allowed = $true
                                break
                            }
                        }
                    }
                    if (-not $allowed) { $negativeOutsideSemanticMasks++ }
                }
                if ($x -ge [Math]::Floor($width * 0.70)) {
                    $rightBandPixels++
                    if ($delta -gt 0) {
                        $rightBandChanged++
                    }
                }
            }
        }

        # Dilate the effect mask by 5% of plate width using a summed-area table.
        $radius = [int][Math]::Round($width * 0.05)
        $integralWidth = $width + 1
        $integral = New-Object int[] (($width + 1) * ($height + 1))
        for ($y = 0; $y -lt $height; $y++) {
            $rowSum = 0
            for ($x = 0; $x -lt $width; $x++) {
                if ($effect[$y * $width + $x]) { $rowSum++ }
                $integral[($y + 1) * $integralWidth + ($x + 1)] = $integral[$y * $integralWidth + ($x + 1)] + $rowSum
            }
        }

        $neutralCount = 0
        $a1NeutralLuma = 0.0
        $c1NeutralLuma = 0.0
        for ($y = 0; $y -lt $height; $y++) {
            $y0 = [Math]::Max(0, $y - $radius)
            $y1 = [Math]::Min($height - 1, $y + $radius)
            for ($x = 0; $x -lt $width; $x++) {
                $x0 = [Math]::Max(0, $x - $radius)
                $x1 = [Math]::Min($width - 1, $x + $radius)
                $sum = $integral[($y1 + 1) * $integralWidth + ($x1 + 1)] -
                    $integral[$y0 * $integralWidth + ($x1 + 1)] -
                    $integral[($y1 + 1) * $integralWidth + $x0] +
                    $integral[$y0 * $integralWidth + $x0]
                if ($sum -gt 0) { continue }
                $neutralCount++
                $a1NeutralLuma += Get-Luma -Bytes $a1Data.Bytes -Offset ($y * $a1Data.Stride + $x * 4)
                $c1NeutralLuma += Get-Luma -Bytes $c1Data.Bytes -Offset ($y * $c1Data.Stride + $x * 4)
            }
        }

        $baselineRate = $baselineCount / [double]$pixelCount
        $effectRate = $effectCount / [double]$pixelCount
        $effectRatio = if ($baselineCount -gt 0) { $effectCount / [double]$baselineCount } else { [double]::PositiveInfinity }
        $neutralRate = $neutralCount / [double]$pixelCount
        $a1Mean = if ($neutralCount -gt 0) { $a1NeutralLuma / $neutralCount } else { 0.0 }
        $c1Mean = if ($neutralCount -gt 0) { $c1NeutralLuma / $neutralCount } else { 0.0 }
        $lumaDeltaRate = if ($a1Mean -gt 0.0) { ($c1Mean - $a1Mean) / $a1Mean } else { [double]::PositiveInfinity }
        $rightBandChangeRate = if ($rightBandPixels -gt 0) { $rightBandChanged / [double]$rightBandPixels } else { 0.0 }

        # Count the thick beams on two independent polar annuli. This keeps
        # isolated sparks out, distinguishes the nearby 335/350-degree bands,
        # and locks the exact eight-direction story contract.
        $rayCenterX = 835.0
        $rayCenterY = 350.0
        $expectedRayCenters = @(36, 76, 122, 159, 200, 248, 306, 356)
        $rayBandsByRadius = @{}
        foreach ($rayRadius in @(180, 190)) {
            $rayBandsByRadius[$rayRadius] = @(Get-RayBandsAtRadius -Effect $effect -Width $width -Height $height -CenterX $rayCenterX -CenterY $rayCenterY -Radius $rayRadius -Thickness 3)
        }

        $failures = New-Object Collections.Generic.List[string]
        if ($effectRatio -lt 3.0) { $failures.Add("effect ratio is below 3x") }
        if ($effectRate -lt 0.02) { $failures.Add("effect coverage is below 2%") }
        if ($negativeOutsideSemanticMasks -ne 0) { $failures.Add("C1 contains channel decreases outside the ray/character semantic masks") }
        foreach ($rayRadius in @(180, 190)) {
            $rayBands = @($rayBandsByRadius[$rayRadius])
            if ($rayBands.Count -ne 8) {
                $failures.Add("expected exactly 8 ray bands at radius $rayRadius, found $($rayBands.Count)")
                continue
            }
            for ($rayIndex = 0; $rayIndex -lt $expectedRayCenters.Count; $rayIndex++) {
                $actualCenter = [int]$rayBands[$rayIndex].Center
                $expectedCenter = [int]$expectedRayCenters[$rayIndex]
                if ((Get-CircularDistanceDegrees -A $actualCenter -B $expectedCenter) -gt 6) {
                    $failures.Add("ray $rayIndex at radius $rayRadius is centered at $actualCenter degrees; expected $expectedCenter +/- 6")
                }
            }
        }

        Write-Output ("size={0}x{1}" -f $width, $height)
        Write-Output ("baseline_teal={0} ({1:P3})" -f $baselineCount, $baselineRate)
        Write-Output ("new_effect={0} ({1:P3}) ratio={2:N2}x" -f $effectCount, $effectRate, $effectRatio)
        Write-Output ("neutral_sample={0} ({1:P3}) dilation_radius={2}px" -f $neutralCount, $neutralRate, $radius)
        Write-Output ("neutral_luma_a1={0:N4} c1={1:N4} drift={2:P3}" -f $a1Mean, $c1Mean, $lumaDeltaRate)
        Write-Output ("right_band_changed={0} ({1:P3})" -f $rightBandChanged, $rightBandChangeRate)
        Write-Output ("positive_only_negative_pixels={0}" -f $negativeChannelPixels)
        Write-Output ("negative_outside_semantic_masks={0}" -f $negativeOutsideSemanticMasks)
        foreach ($rayRadius in @(180, 190)) {
            $rayBands = @($rayBandsByRadius[$rayRadius])
            Write-Output ("ray_annulus_{0}_count={1} centers_deg={2} widths_deg={3}" -f
                $rayRadius,
                $rayBands.Count,
                (($rayBands | ForEach-Object { $_.Center }) -join ','),
                (($rayBands | ForEach-Object { $_.Width }) -join ','))
        }

        if ($failures.Count -gt 0) {
            foreach ($failure in $failures) { Write-Error $failure }
            exit 1
        }
        Write-Output "araul_c1_plate_qa: PASS"
    }
    finally {
        $a1.Dispose()
        $c1.Dispose()
    }
}
finally {
    $a1Source.Dispose()
    $c1Source.Dispose()
}
