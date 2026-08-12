param(
    [Parameter(Mandatory = $true)]
    [string]$CaptureDir,

    [string]$OutputPath = "docs/qa_evidence/araul_prologue_v2/rev5_vulkan_contact_sheet.png",

    [switch]$IncludeMotionFrames,

    [switch]$IncludeSpatialFrames,

    [switch]$IncludeRhythmFrames
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$items = @(
    @{ File = "ko_1920x1080_b2_orb.png"; Label = "KO / B2 orb extraction" },
    @{ File = "ko_1920x1080_c1_eight_rays.png"; Label = "KO / C1 eight rays" },
    @{ File = "ko_1920x1080_d1_confrontation.png"; Label = "KO / D1 confrontation" },
    @{ File = "ko_1920x1080_d2_first_strike.png"; Label = "KO / D2 first strike" },
    @{ File = "ko_1920x1080_final_fade.png"; Label = "KO / 1080p final fade" },
    @{ File = "ko_1920x1080_subtitle.png"; Label = "KO / 1080p subtitle" },
    @{ File = "ja_1920x1080_subtitle.png"; Label = "JA / 1080p subtitle" },
    @{ File = "zh_1920x1080_subtitle.png"; Label = "ZH / 1080p subtitle" },
    @{ File = "en_1920x1080_subtitle.png"; Label = "EN / 1080p subtitle" },
    @{ File = "es_1920x1080_subtitle.png"; Label = "ES / 1080p subtitle" },
    @{ File = "pt-BR_1920x1080_subtitle.png"; Label = "PT-BR / 1080p subtitle" },
    @{ File = "ru_1920x1080_subtitle.png"; Label = "RU / 1080p subtitle" },
    @{ File = "en_1920x1080_chapter.png"; Label = "EN / 1080p chapter" },
    @{ File = "en_2560x1440_chapter.png"; Label = "EN / 1440p chapter" },
    @{ File = "es_1920x1080_chapter.png"; Label = "ES / 1080p chapter" },
    @{ File = "es_2560x1440_chapter.png"; Label = "ES / 1440p chapter" },
    @{ File = "ru_1920x1080_chapter.png"; Label = "RU / 1080p chapter" },
    @{ File = "ru_2560x1440_chapter.png"; Label = "RU / 1440p chapter" }
)
if ($IncludeMotionFrames) {
    $motionItems = @(
        @{ File = "ko_1920x1080_motion_flash_2615.png"; Label = "rev6 / 26.15 ray flash" },
        @{ File = "ko_1920x1080_motion_rays_268.png"; Label = "rev6 / 26.80 ray growth" },
        @{ File = "ko_1920x1080_motion_impact_3305.png"; Label = "rev6 / 33.05 impact flash" },
        @{ File = "ko_1920x1080_motion_shard_335.png"; Label = "rev6 / 33.50 shard intake" }
    )
    $items = @($motionItems) + @($items)
}
if ($IncludeSpatialFrames) {
    $spatialItems = @(
        @{ File = "ko_1920x1080_spatial_dust_80.png"; Label = "rev6.5a / 1080p spatial dust" },
        @{ File = "ko_1920x1080_a1_coronation.png"; Label = "rev6.5a / 1080p follow-up 8.60" },
        @{ File = "ko_2560x1440_spatial_dust_80.png"; Label = "rev6.5a / 1440p spatial dust" },
        @{ File = "ko_2560x1440_a1_coronation.png"; Label = "rev6.5a / 1440p follow-up 8.60" }
    )
    $items = @($spatialItems) + @($items)
}
if ($IncludeRhythmFrames) {
    $rhythmItems = @(
        @{ File = "ko_1920x1080_rhythm_orb_peak_2612.png"; Label = "rev6.5b / 26.12 orb peak" },
        @{ File = "ko_1920x1080_rhythm_ray_stagger_2655.png"; Label = "rev6.5b / 26.55 ray stagger" },
        @{ File = "ko_1920x1080_rhythm_sparks_2755.png"; Label = "rev6.5b / 27.55 delayed sparks" },
        @{ File = "ko_1920x1080_rhythm_last_ember_2942.png"; Label = "rev6.5b / 29.42 last ember" },
        @{ File = "ko_1920x1080_rhythm_guard_glint_3017.png"; Label = "rev6.5b / 30.17 blade glints" },
        @{ File = "ko_1920x1080_rhythm_hitstop_3306.png"; Label = "rev6.5b / 33.06 hitstop" },
        @{ File = "ko_1920x1080_rhythm_recovery_3335.png"; Label = "rev6.5b / 33.35 host recovery" },
        @{ File = "ko_1920x1080_rhythm_h5_pause_3965.png"; Label = "rev6.5b / 39.65 H5 pause" },
        @{ File = "ko_1920x1080_rhythm_tail_vignette_448.png"; Label = "rev6.5b / 44.80 tail vignette" },
        @{ File = "ko_2560x1440_rhythm_orb_peak_2612.png"; Label = "rev6.5b / 1440p orb peak" },
        @{ File = "ko_2560x1440_rhythm_last_ember_2942.png"; Label = "rev6.5b / 1440p last ember" },
        @{ File = "ko_2560x1440_rhythm_guard_glint_3017.png"; Label = "rev6.5b / 1440p blade glints" },
        @{ File = "ko_2560x1440_rhythm_tail_vignette_448.png"; Label = "rev6.5b / 1440p tail vignette" },
        @{ File = "en_1920x1080_rhythm_n.png"; Label = "rev6.5b / EN divine voice" },
        @{ File = "es_1920x1080_rhythm_e1.png"; Label = "rev6.5b / ES E1 2.5s" },
        @{ File = "ru_1920x1080_rhythm_e1.png"; Label = "rev6.5b / RU E1 2.5s" }
    )
    $items = @($rhythmItems) + @($items)
}

$captureRoot = (Resolve-Path -LiteralPath $CaptureDir).Path
$resolvedOutput = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
$outputDir = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$cellWidth = 640
$cellHeight = 360
$columns = 5
$rows = [Math]::Ceiling($items.Count / $columns)
$canvas = [Drawing.Bitmap]::new(
    [int]($cellWidth * $columns),
    [int]($cellHeight * $rows),
    [Drawing.Imaging.PixelFormat]::Format24bppRgb
)
$graphics = [Drawing.Graphics]::FromImage($canvas)
try {
    $graphics.Clear([Drawing.Color]::Black)
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $font = New-Object Drawing.Font("Segoe UI", 13, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
    $labelBrush = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(210, 0, 0, 0))
    $textBrush = New-Object Drawing.SolidBrush([Drawing.Color]::White)
    try {
        for ($index = 0; $index -lt $items.Count; $index++) {
            $item = $items[$index]
            $path = Join-Path $captureRoot $item.File
            if (-not (Test-Path -LiteralPath $path)) {
                throw "Missing capture for contact sheet: $path"
            }
            $source = [Drawing.Image]::FromFile($path)
            try {
                $x = ($index % $columns) * $cellWidth
                $y = [Math]::Floor($index / $columns) * $cellHeight
                $graphics.DrawImage($source, [Drawing.Rectangle]::new($x, $y, $cellWidth, $cellHeight))
                $graphics.FillRectangle($labelBrush, $x, $y, $cellWidth, 27)
                $graphics.DrawString([string]$item.Label, $font, $textBrush, $x + 8, $y + 5)
            }
            finally {
                $source.Dispose()
            }
        }
    }
    finally {
        $font.Dispose()
        $labelBrush.Dispose()
        $textBrush.Dispose()
    }
    $canvas.Save($resolvedOutput, [Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $graphics.Dispose()
    $canvas.Dispose()
}

Write-Output "araul_prologue_contact_sheet: PASS"
Write-Output "output=$resolvedOutput size=$($cellWidth * $columns)x$($cellHeight * $rows)"
