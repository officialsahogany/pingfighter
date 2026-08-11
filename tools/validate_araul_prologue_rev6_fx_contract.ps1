param(
    [string]$RuntimeDirectory = "godot/assets/ui/story/han_miryang_prologue",
    [string]$SourceDirectory = "art_sources/araul_prologue/fx_layers"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function Open-ArgbBitmap {
    param([Parameter(Mandatory = $true)][string]$Path)
    $source = [Drawing.Image]::FromFile($Path)
    try {
        $bitmap = New-Object Drawing.Bitmap($source.Width, $source.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.DrawImageUnscaled($source, 0, 0)
        }
        finally {
            $graphics.Dispose()
        }
        return $bitmap
    }
    finally {
        $source.Dispose()
    }
}

function Read-BitmapBytes {
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

function Assert-ImportContract {
    param([Parameter(Mandatory = $true)][string]$PngPath)
    $sidecar = "$PngPath.import"
    if (-not (Test-Path -LiteralPath $sidecar)) {
        throw "Missing import sidecar: $sidecar"
    }
    $content = [IO.File]::ReadAllText($sidecar)
    foreach ($needle in @(
        'compress/mode=2',
        'compress/high_quality=true',
        'mipmaps/generate=true',
        '"vram_texture": true',
        '"s3tc_bptc"',
        '"etc2_astc"'
    )) {
        if (-not $content.Contains($needle)) {
            throw "Import contract missing '$needle': $sidecar"
        }
    }
}

function Test-RoundTripEllipse {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$LayerPath,
        [Parameter(Mandatory = $true)][int[]]$Offset,
        [Parameter(Mandatory = $true)][double[]]$Ellipse
    )
    $base = Open-ArgbBitmap -Path $BasePath
    $target = Open-ArgbBitmap -Path $TargetPath
    $layer = Open-ArgbBitmap -Path $LayerPath
    try {
        $baseData = Read-BitmapBytes -Bitmap $base
        $targetData = Read-BitmapBytes -Bitmap $target
        $layerData = Read-BitmapBytes -Bitmap $layer
        $errors = 0
        $outsideAlpha = 0
        for ($ly = 0; $ly -lt $layer.Height; $ly++) {
            $fy = $Offset[1] + $ly
            $ny = ([double]$fy + 0.5) / $base.Height
            for ($lx = 0; $lx -lt $layer.Width; $lx++) {
                $fx = $Offset[0] + $lx
                $nx = ([double]$fx + 0.5) / $base.Width
                $dx = ($nx - $Ellipse[0]) / $Ellipse[2]
                $dy = ($ny - $Ellipse[1]) / $Ellipse[3]
                $inside = $dx * $dx + $dy * $dy -le 1.0
                $layerOffset = $ly * $layerData.Stride + $lx * 4
                $alpha = [int]$layerData.Bytes[$layerOffset + 3]
                if (-not $inside) {
                    if ($alpha -ne 0) { $outsideAlpha++ }
                    continue
                }
                $fullOffset = $fy * $baseData.Stride + $fx * 4
                for ($channel = 0; $channel -lt 3; $channel++) {
                    $reconstructed = if ($alpha -eq 0) { [int]$baseData.Bytes[$fullOffset + $channel] } else { [int]$layerData.Bytes[$layerOffset + $channel] }
                    if ($reconstructed -ne [int]$targetData.Bytes[$fullOffset + $channel]) {
                        $errors++
                    }
                }
            }
        }
        if ($outsideAlpha -ne 0 -or $errors -ne 0) {
            throw "$Key roundtrip failed: channel_errors=$errors outside_alpha=$outsideAlpha"
        }
        Write-Output "$Key roundtrip=PASS outside_alpha=0"
    }
    finally {
        $base.Dispose(); $target.Dispose(); $layer.Dispose()
    }
}

function Assert-ExcludedEllipsesTransparent {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][string]$LayerPath,
        [Parameter(Mandatory = $true)][int[]]$Offset,
        [Parameter(Mandatory = $true)][int[]]$FullSize,
        [Parameter(Mandatory = $true)][object[]]$Ellipses
    )
    $layer = Open-ArgbBitmap -Path $LayerPath
    try {
        $layerData = Read-BitmapBytes -Bitmap $layer
        $ghostPixels = 0
        for ($ly = 0; $ly -lt $layer.Height; $ly++) {
            $fy = $Offset[1] + $ly
            $ny = ([double]$fy + 0.5) / $FullSize[1]
            for ($lx = 0; $lx -lt $layer.Width; $lx++) {
                $alpha = [int]$layerData.Bytes[$ly * $layerData.Stride + $lx * 4 + 3]
                if ($alpha -eq 0) { continue }
                $fx = $Offset[0] + $lx
                $nx = ([double]$fx + 0.5) / $FullSize[0]
                foreach ($ellipseValue in $Ellipses) {
                    $ellipse = [double[]]$ellipseValue
                    $dx = ($nx - $ellipse[0]) / $ellipse[2]
                    $dy = ($ny - $ellipse[1]) / $ellipse[3]
                    if ($dx * $dx + $dy * $dy -le 1.0) {
                        $ghostPixels++
                        break
                    }
                }
            }
        }
        if ($ghostPixels -ne 0) {
            throw "$Key exclusion failed: ghost_pixels=$ghostPixels"
        }
        Write-Output "$Key excluded_ghost_pixels=0"
    }
    finally {
        $layer.Dispose()
    }
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$runtimeCandidate = if ([IO.Path]::IsPathRooted($RuntimeDirectory)) { $RuntimeDirectory } else { Join-Path $repositoryRoot $RuntimeDirectory }
$sourceCandidate = if ([IO.Path]::IsPathRooted($SourceDirectory)) { $SourceDirectory } else { Join-Path $repositoryRoot $SourceDirectory }
$runtimeRoot = (Resolve-Path -LiteralPath $runtimeCandidate).Path
$sourceRoot = (Resolve-Path -LiteralPath $sourceCandidate).Path
$reportPath = Join-Path $sourceRoot "araul_prologue_v3_rev6_fx_extraction.json"
$report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($report.schema -ne "araul-prologue-v3-rev6-fx-extraction") {
    throw "Unexpected rev6 FX extraction schema"
}
if ([int]$report.cyan_calibration.selected_margin -ne 24) {
    throw "V3 cyan margin must remain the measured 24/255"
}
if ([double]$report.cyan_calibration.v3_a1_measured_false_positive_ratio -gt 0.0011) {
    throw "V3 A1 cyan false-positive rate exceeds the calibrated ceiling"
}

$layersByKey = @{}
foreach ($layer in $report.layers) {
    $layersByKey[[string]$layer.key] = $layer
    $sourcePath = Join-Path $sourceRoot ([string]$layer.file)
    $runtimePath = Join-Path $runtimeRoot ([string]$layer.file)
    if (-not (Test-Path -LiteralPath $sourcePath) -or -not (Test-Path -LiteralPath $runtimePath)) {
        throw "Missing rev6 FX layer: $($layer.key)"
    }
    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash.ToLowerInvariant()
    $runtimeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $runtimePath).Hash.ToLowerInvariant()
    if ($sourceHash -ne [string]$layer.sha256 -or $runtimeHash -ne $sourceHash) {
        throw "FX hash mismatch: $($layer.key)"
    }
    $bitmap = Open-ArgbBitmap -Path $sourcePath
    try {
        if ($bitmap.Width -ne [int]$layer.crop_size[0] -or $bitmap.Height -ne [int]$layer.crop_size[1]) {
            throw "FX crop size mismatch: $($layer.key)"
        }
    }
    finally {
        $bitmap.Dispose()
    }
    Assert-ImportContract -PngPath $runtimePath
}

$tablet = $layersByKey["fx_tablet"]
Test-RoundTripEllipse -Key "fx_tablet" `
    -BasePath (Join-Path $runtimeRoot "araul_prologue_v3_a1_coronation.png") `
    -TargetPath (Join-Path $runtimeRoot "araul_prologue_v3_a2_tablet.png") `
    -LayerPath (Join-Path $runtimeRoot ([string]$tablet.file)) `
    -Offset ([int[]]$tablet.crop_offset) `
    -Ellipse ([double[]]@(0.525, 0.42, 0.085, 0.29))

$orb = $layersByKey["fx_orb"]
Test-RoundTripEllipse -Key "fx_orb" `
    -BasePath (Join-Path $runtimeRoot "araul_prologue_v3_b1_resistance.png") `
    -TargetPath (Join-Path $runtimeRoot "araul_prologue_v3_b2_orb_extraction.png") `
    -LayerPath (Join-Path $runtimeRoot ([string]$orb.file)) `
    -Offset ([int[]]$orb.crop_offset) `
    -Ellipse ([double[]]@(0.555, 0.31, 0.095, 0.16))

$rays = $layersByKey["fx_rays"]
Assert-ExcludedEllipsesTransparent -Key "fx_rays" `
    -LayerPath (Join-Path $runtimeRoot ([string]$rays.file)) `
    -Offset ([int[]]$rays.crop_offset) `
    -FullSize ([int[]]@(3344, 1882)) `
    -Ellipses @([double[]]@(0.30, 0.43, 0.17, 0.38), [double[]]@(0.61, 0.56, 0.075, 0.19))

$shard = $layersByKey["fx_shard"]
Assert-ExcludedEllipsesTransparent -Key "fx_shard" `
    -LayerPath (Join-Path $runtimeRoot ([string]$shard.file)) `
    -Offset ([int[]]$shard.crop_offset) `
    -FullSize ([int[]]@(3344, 1882)) `
    -Ellipses @([double[]]@(0.295, 0.255, 0.065, 0.115))

Write-Output "araul_prologue_rev6_fx_contract: PASS"
