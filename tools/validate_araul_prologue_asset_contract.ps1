param(
    [string]$SourceDir = "art_sources/araul_prologue/final_v3",
    [string]$RuntimeDir = "godot/assets/ui/story/han_miryang_prologue",
    [string]$ManifestPath = "godot/assets/ui/story/han_miryang_prologue/araul_prologue_v3_manifest.json",
    [switch]$SourceOnly
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
if (-not ("AraulMaskAudit" -as [type])) {
    Add-Type -TypeDefinition @"
using System;

public static class AraulMaskAudit
{
    public static long[] Count(byte[] baseBytes, int baseStride, byte[] derivedBytes, int derivedStride, int width, int height, string mask)
    {
        long changed = 0;
        long outside = 0;
        long minOutsideX = width;
        long minOutsideY = height;
        long maxOutsideX = -1;
        long maxOutsideY = -1;
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int a = y * baseStride + x * 4;
                int b = y * derivedStride + x * 4;
                bool different = false;
                for (int c = 0; c < 4; c++) {
                    if (baseBytes[a + c] != derivedBytes[b + c]) {
                        different = true;
                        break;
                    }
                }
                if (!different) continue;
                changed++;
                if (!Allowed(mask, x, y, width, height)) {
                    outside++;
                    minOutsideX = Math.Min(minOutsideX, x);
                    minOutsideY = Math.Min(minOutsideY, y);
                    maxOutsideX = Math.Max(maxOutsideX, x);
                    maxOutsideY = Math.Max(maxOutsideY, y);
                }
            }
        }
        return new long[] { changed, outside, minOutsideX, minOutsideY, maxOutsideX, maxOutsideY };
    }

    private static bool Allowed(string mask, int x, int y, int width, int height)
    {
        switch (mask) {
            case "A1":
                return Rect(x, y, width, height, 0.40, 0.00, 0.68, 0.66)
                    || Rect(x, y, width, height, 0.16, 0.08, 0.44, 0.94)
                    || Rect(x, y, width, height, 0.10, 0.42, 0.26, 0.76)
                    || Rect(x, y, width, height, 0.32, 0.56, 0.74, 1.00);
            case "A2":
                return Rect(x, y, width, height, 0.40, 0.00, 0.68, 0.66);
            case "A3":
                return Rect(x, y, width, height, 0.40, 0.00, 0.68, 0.66)
                    || Rect(x, y, width, height, 0.28, 0.18, 0.44, 0.52)
                    || Rect(x, y, width, height, 0.28, 0.16, 0.36, 0.26)
                    || Rect(x, y, width, height, 0.36, 0.159, 0.40, 0.18);
            case "B2":
                return Ellipse(x, y, width, height, 0.535, 0.30, 0.13, 0.20);
            case "D2":
                return Ellipse(x, y, width, height, 0.235, 0.30, 0.135, 0.28)
                    || Ellipse(x, y, width, height, 0.47, 0.52, 0.17, 0.25)
                    || Ellipse(x, y, width, height, 0.492, 0.705, 0.070, 0.150)
                    || Ellipse(x, y, width, height, 0.476, 0.855, 0.050, 0.145)
                    || Ellipse(x, y, width, height, 0.505, 0.685, 0.075, 0.135);
            default:
                throw new ArgumentOutOfRangeException("mask", mask, "Unknown plate mask");
        }
    }

    private static bool Rect(int x, int y, int width, int height, double x0, double y0, double x1, double y1)
    {
        return x >= Math.Floor(x0 * width) && x < Math.Ceiling(x1 * width)
            && y >= Math.Floor(y0 * height) && y < Math.Ceiling(y1 * height);
    }

    private static bool Ellipse(int x, int y, int width, int height, double cx, double cy, double rx, double ry)
    {
        double dx = (x - cx * width) / (rx * width);
        double dy = (y - cy * height) / (ry * height);
        return dx * dx + dy * dy < 1.0;
    }
}
"@
}

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    $repoRoot = Split-Path -Parent $PSScriptRoot
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
}

function Get-ImageInfo {
    param([Parameter(Mandatory = $true)][string]$Path)
    $source = [Drawing.Image]::FromFile($Path)
    try {
        return @{ Width = $source.Width; Height = $source.Height }
    }
    finally {
        $source.Dispose()
    }
}

function Get-ArgbData {
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
        $rect = [Drawing.Rectangle]::new(0, 0, $bitmap.Width, $bitmap.Height)
        $locked = $bitmap.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $length = [Math]::Abs($locked.Stride) * $bitmap.Height
            $bytes = New-Object byte[] $length
            [Runtime.InteropServices.Marshal]::Copy($locked.Scan0, $bytes, 0, $length)
            return @{ Bytes = $bytes; Stride = $locked.Stride; Width = $bitmap.Width; Height = $bitmap.Height }
        }
        finally {
            $bitmap.UnlockBits($locked)
            $bitmap.Dispose()
        }
    }
    finally {
        $source.Dispose()
    }
}

function Test-PlateMask {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$DerivedPath,
        [Parameter(Mandatory = $true)][string]$Mask
    )
    $base = Get-ArgbData -Path $BasePath
    $derived = Get-ArgbData -Path $DerivedPath
    if ($base.Width -ne $derived.Width -or $base.Height -ne $derived.Height) {
        throw "$Name dimensions differ"
    }
    $counts = [AraulMaskAudit]::Count(
        $base.Bytes,
        $base.Stride,
        $derived.Bytes,
        $derived.Stride,
        $base.Width,
        $base.Height,
        $Mask
    )
    $changed = $counts[0]
    $outside = $counts[1]
    $outsideBbox = if ($outside -gt 0) { "$($counts[2]),$($counts[3])-$($counts[4]),$($counts[5])" } else { "none" }
    Write-Output "$Name changed_pixels=$changed outside_mask=$outside outside_bbox=$outsideBbox"
    if ($changed -le 0) {
        throw "$Name contains no visible change"
    }
    if ($outside -ne 0) {
        throw "$Name changed $outside pixels outside its deterministic mask"
    }
}

$sourceRoot = Get-NormalizedPath -Path $SourceDir
$runtimeRoot = Get-NormalizedPath -Path $RuntimeDir
$manifestFile = Get-NormalizedPath -Path $ManifestPath
$manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
$sourceManifestPath = Get-NormalizedPath -Path ([string]$manifest.source_manifest)
if (-not (Test-Path -LiteralPath $sourceManifestPath -PathType Leaf)) {
    throw "Missing V3 source manifest: $sourceManifestPath"
}
$sourceManifestSha = (Get-FileHash -LiteralPath $sourceManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($sourceManifestSha -ne [string]$manifest.source_manifest_sha256) {
    throw "V3 source manifest SHA mismatch"
}

$expectedKeys = @("A1", "A2", "A3", "B1", "B2", "C1", "D1", "D2")
$actualKeys = @($manifest.plates | ForEach-Object { $_.key })
if (@($actualKeys | Select-Object -Unique).Count -ne 8 -or (Compare-Object $expectedKeys $actualKeys).Count -ne 0) {
    throw "Manifest must contain exactly the unique plate keys A1..D2"
}

foreach ($plate in $manifest.plates) {
    $sourcePath = Join-Path $sourceRoot $plate.source_file
    $runtimePath = Join-Path $runtimeRoot $plate.runtime_file
    $importPath = "$runtimePath.import"
    $requiredPaths = @($sourcePath)
    if (-not $SourceOnly) {
        $requiredPaths += @($runtimePath, $importPath)
    }
    foreach ($required in $requiredPaths) {
        if (-not (Test-Path -LiteralPath $required)) {
            throw "Missing asset contract path: $required"
        }
    }
    $sourceInfo = Get-ImageInfo -Path $sourcePath
    if ($sourceInfo.Width -ne 1672 -or $sourceInfo.Height -ne 941) {
        throw "$($plate.key) source must be 1672x941"
    }
    $sourceSha = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sourceSha -ne [string]$plate.source_sha256) {
        throw "$($plate.key) source SHA mismatch"
    }
    if (-not $SourceOnly) {
        $runtimeInfo = Get-ImageInfo -Path $runtimePath
        if ($runtimeInfo.Width -ne 3344 -or $runtimeInfo.Height -ne 1882) {
            throw "$($plate.key) runtime must be 3344x1882"
        }
        $runtimeSha = (Get-FileHash -LiteralPath $runtimePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($runtimeSha -ne [string]$plate.runtime_sha256) {
            throw "$($plate.key) runtime SHA mismatch"
        }
        $importText = Get-Content -LiteralPath $importPath -Raw -Encoding UTF8
        foreach ($token in @(
            'compress/mode=2',
            'compress/high_quality=true',
            'mipmaps/generate=true',
            '"vram_texture": true',
            '"imported_formats": ["s3tc_bptc", "etc2_astc"]'
        )) {
            if (-not $importText.Contains($token)) {
                throw "$($plate.key) import contract missing: $token"
            }
        }
    }
}

$a1 = Join-Path $sourceRoot "araul_a1_v35_proportion_fix.png"
$c1 = Join-Path $sourceRoot "araul_prologue_v3_c1_eight_rays.png"
$derivativeValidator = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "validate_araul_v3_derivative_candidates.ps1"
& $derivativeValidator -AnchorDirectory $sourceRoot -CandidateDirectory $sourceRoot
$c1Validator = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "validate_araul_c1_plate.ps1"
& $c1Validator -A1Path $a1 -C1Path $c1

Write-Output "araul_prologue_asset_contract: PASS"
