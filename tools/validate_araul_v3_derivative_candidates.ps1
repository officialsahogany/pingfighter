param(
    [string]$AnchorDirectory = "art_sources/araul_prologue/final_v3",
    [string]$CandidateDirectory = "art_sources/araul_prologue/final_v3"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function New-ArgbBitmap {
    param([Drawing.Image]$Source)
    $bitmap = [Drawing.Bitmap]::new($Source.Width, $Source.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
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
        $bytes = [byte[]]::new([Math]::Abs($data.Stride) * $Bitmap.Height)
        [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
        return @{ Bytes = $bytes; Stride = $data.Stride }
    }
    finally { $Bitmap.UnlockBits($data) }
}

function Read-Plate {
    param([string]$Path)
    $source = [Drawing.Image]::FromFile((Resolve-Path -LiteralPath $Path))
    try {
        if ($source.Width -ne 1672 -or $source.Height -ne 941) {
            throw "$Path must be 1672x941, got $($source.Width)x$($source.Height)"
        }
        $bitmap = New-ArgbBitmap -Source $source
        try {
            $data = Get-BitmapBytes -Bitmap $bitmap
            return @{ Bytes = $data.Bytes; Stride = $data.Stride; Width = $bitmap.Width; Height = $bitmap.Height }
        }
        finally { $bitmap.Dispose() }
    }
    finally { $source.Dispose() }
}

function Test-InEllipse {
    param([double]$X, [double]$Y, [double[]]$Ellipse, [int]$Width, [int]$Height)
    $dx = ($X - $Ellipse[0] * $Width) / ($Ellipse[2] * $Width)
    $dy = ($Y - $Ellipse[1] * $Height) / ($Ellipse[3] * $Height)
    return ($dx * $dx + $dy * $dy) -le 1.000001
}

function Test-InAnyEllipse {
    param([double]$X, [double]$Y, [object[]]$Ellipses, [int]$Width, [int]$Height)
    foreach ($ellipse in $Ellipses) {
        if (Test-InEllipse -X $X -Y $Y -Ellipse $ellipse -Width $Width -Height $Height) { return $true }
    }
    return $false
}

function Test-InRayCapsule {
    param([double]$X, [double]$Y, [double]$AngleDegrees)
    $cx = 835.0
    $cy = 350.0
    $radians = $AngleDegrees * [Math]::PI / 180.0
    $directionX = [Math]::Cos($radians)
    $directionY = -[Math]::Sin($radians)
    $dx = $X - $cx
    $dy = $Y - $cy
    $along = $dx * $directionX + $dy * $directionY
    if ($along -lt 24.0 -or $along -gt 1050.0) { return $false }
    $progress = ($along - 24.0) / (1050.0 - 24.0)
    $halfWidth = 7.0 + (18.0 - 7.0) * $progress + 4.1
    $across = [Math]::Abs(-$dx * $directionY + $dy * $directionX)
    return $across -le $halfWidth
}

function Get-RayBands {
    param([bool[]]$Effect, [int]$Width, [int]$Height, [int]$Radius)
    $flags = [bool[]]::new(360)
    for ($angle = 0; $angle -lt 360; $angle++) {
        $rad = $angle * [Math]::PI / 180.0
        for ($dr = -3; $dr -le 3; $dr++) {
            $x = [int][Math]::Round(835.0 + [Math]::Cos($rad) * ($Radius + $dr))
            $y = [int][Math]::Round(350.0 - [Math]::Sin($rad) * ($Radius + $dr))
            if ($x -ge 0 -and $x -lt $Width -and $y -ge 0 -and $y -lt $Height -and $Effect[$y * $Width + $x]) {
                $flags[$angle] = $true
                break
            }
        }
    }
    $closed = [bool[]]$flags.Clone()
    for ($angle = 0; $angle -lt 360; $angle++) {
        if (-not $flags[$angle]) { continue }
        for ($gap = 1; $gap -le 2; $gap++) {
            $other = ($angle + $gap + 1) % 360
            if ($flags[$other]) {
                for ($fill = 1; $fill -le $gap; $fill++) { $closed[($angle + $fill) % 360] = $true }
            }
        }
    }
    $anchor = 0
    while ($anchor -lt 360 -and $closed[$anchor]) { $anchor++ }
    if ($anchor -eq 360) { return @() }
    $bands = [Collections.Generic.List[object]]::new()
    $start = -1
    $length = 0
    for ($step = 1; $step -le 360; $step++) {
        $angle = ($anchor + $step) % 360
        if ($closed[$angle]) {
            if ($start -lt 0) { $start = $angle }
            $length++
        }
        elseif ($start -ge 0) {
            if ($length -ge 3) {
                $bands.Add([pscustomobject]@{ Center = [int][Math]::Round(($start + ($length - 1) * 0.5) % 360); Width = $length })
            }
            $start = -1
            $length = 0
        }
    }
    return @($bands | Sort-Object Center)
}

function Measure-ExactOutsideEllipses {
    param([hashtable]$Base, [hashtable]$Candidate, [object[]]$Ellipses)
    $changed = 0
    $outside = 0
    for ($y = 0; $y -lt $Base.Height; $y++) {
        for ($x = 0; $x -lt $Base.Width; $x++) {
            $baseOffset = $y * $Base.Stride + $x * 4
            $candidateOffset = $y * $Candidate.Stride + $x * 4
            $different = $false
            for ($channel = 0; $channel -lt 4; $channel++) {
                if ($Base.Bytes[$baseOffset + $channel] -ne $Candidate.Bytes[$candidateOffset + $channel]) { $different = $true; break }
            }
            if (-not $different) { continue }
            $changed++
            if (-not (Test-InAnyEllipse -X $x -Y $y -Ellipses $Ellipses -Width $Base.Width -Height $Base.Height)) { $outside++ }
        }
    }
    return @{ Changed = $changed; Outside = $outside }
}

$a1 = Read-Plate -Path (Join-Path $AnchorDirectory "araul_a1_v35_proportion_fix.png")
$b1 = Read-Plate -Path (Join-Path $AnchorDirectory "araul_b1_v35_serious_tone_test.png")
$d1 = Read-Plate -Path (Join-Path $AnchorDirectory "araul_prologue_v3_d1_confrontation.png")
$a2 = Read-Plate -Path (Join-Path $CandidateDirectory "araul_prologue_v3_a2_tablet.png")
$a3 = Read-Plate -Path (Join-Path $CandidateDirectory "araul_prologue_v3_a3_spirit.png")
$b2 = Read-Plate -Path (Join-Path $CandidateDirectory "araul_prologue_v3_b2_orb_extraction.png")
$c1 = Read-Plate -Path (Join-Path $CandidateDirectory "araul_prologue_v3_c1_eight_rays.png")
$d2 = Read-Plate -Path (Join-Path $CandidateDirectory "araul_prologue_v3_d2_first_strike.png")

$failures = [Collections.Generic.List[string]]::new()
$exactCases = @(
    @{ Name = "A1_to_A2"; Base = $a1; Candidate = $a2; Ellipses = ,([double[]]@(0.525, 0.42, 0.085, 0.29)) },
    @{ Name = "A2_to_A3"; Base = $a2; Candidate = $a3; Ellipses = @([double[]]@(0.525, 0.42, 0.085, 0.29), [double[]]@(0.45, 0.32, 0.13, 0.11), [double[]]@(0.335, 0.22, 0.05, 0.10)) },
    @{ Name = "B1_to_B2"; Base = $b1; Candidate = $b2; Ellipses = ,([double[]]@(0.555, 0.31, 0.095, 0.16)) }
)
foreach ($case in $exactCases) {
    $measurement = Measure-ExactOutsideEllipses -Base $case.Base -Candidate $case.Candidate -Ellipses $case.Ellipses
    Write-Output "$($case.Name): changed=$($measurement.Changed) outside_mask=$($measurement.Outside)"
    if ($measurement.Outside -ne 0) { $failures.Add("$($case.Name) changed outside its deterministic masks") }
}

$c1Effect = [bool[]]::new($a1.Width * $a1.Height)
$c1Changed = 0
$c1NegativeOutside = 0
$d2Changed = 0
$d2NegativeOutside = 0
$d2RightBandChanged = 0
$rayAngles = @(35.5, 75.5, 121.5, 158.5, 199.5, 247.5, 305.5, 356.0)
$c1CharacterEllipses = @([double[]]@(0.30, 0.43, 0.17, 0.38), [double[]]@(0.61, 0.56, 0.075, 0.19))
$d2FaceEllipse = ,([double[]]@(0.295, 0.255, 0.065, 0.115))
for ($y = 0; $y -lt $a1.Height; $y++) {
    for ($x = 0; $x -lt $a1.Width; $x++) {
        $aOffset = $y * $a1.Stride + $x * 4
        $cOffset = $y * $c1.Stride + $x * 4
        $dBaseOffset = $y * $d1.Stride + $x * 4
        $dOffset = $y * $d2.Stride + $x * 4

        $cDelta = 0
        $cNegative = $false
        $dDelta = 0
        $dNegative = $false
        for ($channel = 0; $channel -lt 3; $channel++) {
            $cDiff = [int]$c1.Bytes[$cOffset + $channel] - [int]$a1.Bytes[$aOffset + $channel]
            $dDiff = [int]$d2.Bytes[$dOffset + $channel] - [int]$d1.Bytes[$dBaseOffset + $channel]
            $cDelta = [Math]::Max($cDelta, [Math]::Abs($cDiff))
            $dDelta = [Math]::Max($dDelta, [Math]::Abs($dDiff))
            if ($cDiff -lt 0) { $cNegative = $true }
            if ($dDiff -lt 0) { $dNegative = $true }
        }
        if ($cDelta -gt 0) { $c1Changed++ }
        if ($dDelta -gt 0) {
            $d2Changed++
            if ($x -ge [Math]::Floor($a1.Width * 0.70)) { $d2RightBandChanged++ }
        }
        if ($cDelta -ge 20) {
            $blue = [int]$c1.Bytes[$cOffset]
            $green = [int]$c1.Bytes[$cOffset + 1]
            $red = [int]$c1.Bytes[$cOffset + 2]
            if ($blue -gt $red + 24 -and $green -gt $red + 24) { $c1Effect[$y * $a1.Width + $x] = $true }
        }
        if ($cNegative) {
            $allowed = Test-InAnyEllipse -X $x -Y $y -Ellipses $c1CharacterEllipses -Width $a1.Width -Height $a1.Height
            if (-not $allowed) {
                foreach ($angle in $rayAngles) {
                    if (Test-InRayCapsule -X $x -Y $y -AngleDegrees $angle) { $allowed = $true; break }
                }
            }
            if (-not $allowed) { $c1NegativeOutside++ }
        }
        if ($dNegative -and -not (Test-InAnyEllipse -X $x -Y $y -Ellipses $d2FaceEllipse -Width $a1.Width -Height $a1.Height)) {
            $d2NegativeOutside++
        }
    }
}

Write-Output "C1: changed=$c1Changed negative_outside_semantic_masks=$c1NegativeOutside"
Write-Output "D2: changed=$d2Changed negative_outside_face_mask=$d2NegativeOutside right_30pct_changed=$d2RightBandChanged"
if ($c1NegativeOutside -ne 0) { $failures.Add("C1 contains channel decreases outside the ray/character semantic masks") }
if ($d2NegativeOutside -ne 0) { $failures.Add("D2 contains channel decreases outside the recovery face mask") }
if ($d2RightBandChanged -ne 0) { $failures.Add("D2 changes Han Miryang's locked right-side band") }

$expectedCenters = @(36, 76, 122, 159, 200, 248, 306, 356)
foreach ($radius in @(180, 190)) {
    $bands = @(Get-RayBands -Effect $c1Effect -Width $a1.Width -Height $a1.Height -Radius $radius)
    Write-Output ("C1 rays radius={0}: count={1} centers={2} widths={3}" -f $radius, $bands.Count, (($bands | ForEach-Object Center) -join ','), (($bands | ForEach-Object Width) -join ','))
    if ($bands.Count -ne 8) {
        $failures.Add("C1 expected 8 rays at radius $radius, found $($bands.Count)")
        continue
    }
    for ($index = 0; $index -lt 8; $index++) {
        $delta = [Math]::Abs([int]$bands[$index].Center - $expectedCenters[$index])
        $delta = [Math]::Min($delta, 360 - $delta)
        if ($delta -gt 8) { $failures.Add("C1 ray $index at radius $radius drifted to $($bands[$index].Center) degrees") }
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Error $failure }
    exit 1
}
Write-Output "araul_v3_source_derivatives: PASS"
