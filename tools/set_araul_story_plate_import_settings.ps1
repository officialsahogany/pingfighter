param(
    [string]$AssetDirectory = "godot/assets/ui/story/han_miryang_prologue"
)

$ErrorActionPreference = "Stop"
$resolvedDirectory = (Resolve-Path -LiteralPath $AssetDirectory).Path
$sidecars = Get-ChildItem -LiteralPath $resolvedDirectory -Filter "araul_prologue_v2_*.png.import" -File
if ($sidecars.Count -ne 8) {
    throw "Expected 8 v2 story plate sidecars, found $($sidecars.Count)"
}

$utf8NoBom = [Text.UTF8Encoding]::new($false)
foreach ($sidecar in $sidecars) {
    $content = [IO.File]::ReadAllText($sidecar.FullName)
    $uidMatch = [regex]::Match($content, 'uid="([^"]+)"')
    $sourceMatch = [regex]::Match($content, 'source_file="([^"]+)"')
    $bptcPathMatch = [regex]::Match($content, 'path\.bptc="(res://\.godot/imported/[^\"]+)\.bptc\.ctex"')
    $legacyPathMatch = [regex]::Match($content, 'path="(res://\.godot/imported/[^\"]+)\.ctex"')
    if (-not $uidMatch.Success -or -not $sourceMatch.Success -or
        (-not $bptcPathMatch.Success -and -not $legacyPathMatch.Success)) {
        throw "Could not parse generated import sidecar: $($sidecar.FullName)"
    }
    $uid = $uidMatch.Groups[1].Value
    $source = $sourceMatch.Groups[1].Value
    $basePath = if ($bptcPathMatch.Success) { $bptcPathMatch.Groups[1].Value } else { $legacyPathMatch.Groups[1].Value }
    $replacement = @"
[remap]

importer="texture"
type="CompressedTexture2D"
uid="$uid"
path.bptc="$basePath.bptc.ctex"
path.astc="$basePath.astc.ctex"
metadata={
"imported_formats": ["s3tc_bptc", "etc2_astc"],
"vram_texture": true
}

[deps]

source_file="$source"
dest_files=["$basePath.bptc.ctex", "$basePath.astc.ctex"]

[params]

compress/mode=2
compress/high_quality=true
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"@
    [IO.File]::WriteAllText($sidecar.FullName, $replacement.Replace("`n", "`r`n"), $utf8NoBom)
    Write-Output "updated=$($sidecar.Name)"
}
