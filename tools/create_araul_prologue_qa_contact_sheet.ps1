param(
    [Parameter(Mandatory = $true)]
    [string]$CaptureDir,

    [string]$OutputPath = "docs/qa_evidence/araul_prologue_v2/rev5_vulkan_contact_sheet.png"
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

$captureRoot = (Resolve-Path -LiteralPath $CaptureDir).Path
$resolvedOutput = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
$outputDir = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$cellWidth = 640
$cellHeight = 360
$columns = 5
$rows = 4
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
Write-Output "output=$resolvedOutput size=3200x1440"
