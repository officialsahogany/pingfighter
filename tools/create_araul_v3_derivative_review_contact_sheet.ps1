param(
    [string]$AnchorDirectory = "art_sources/araul_prologue/final_v3",
    [string]$CandidateDirectory = "art_sources/araul_prologue/v3_rebuild_candidates",
    [string]$OutputPath = "art_sources/araul_prologue/v3_rebuild_candidates/araul_v3_derivatives_review_contact_sheet.png"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$plates = @(
    @{ Label = "A2  Memorial tablet appears"; Path = Join-Path $CandidateDirectory "araul_prologue_v3_a2_candidate_01.png" },
    @{ Label = "A3  Tablet cracks / spirit strand"; Path = Join-Path $CandidateDirectory "araul_prologue_v3_a3_candidate_01.png" },
    @{ Label = "B2  Orb expelled"; Path = Join-Path $CandidateDirectory "araul_prologue_v3_b2_candidate_01.png" },
    @{ Label = "C1  Eight rays / exhausted queen"; Path = Join-Path $CandidateDirectory "araul_prologue_v3_c1_candidate_04.png" },
    @{ Label = "D2  Host recovery / spirit absorption"; Path = Join-Path $CandidateDirectory "araul_prologue_v3_d2_candidate_04.png" },
    @{ Label = "D1  Accepted reference"; Path = Join-Path $AnchorDirectory "araul_prologue_v3_d1_confrontation.png" }
)

$resolvedOutput = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
if (Test-Path -LiteralPath $resolvedOutput) { throw "Refusing to overwrite existing output: $resolvedOutput" }
$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory)) { New-Item -ItemType Directory -Path $outputDirectory | Out-Null }

$canvasWidth = 4800
$canvasHeight = 2920
$margin = 54
$gap = 34
$headerHeight = 82
$columns = 3
$rows = 2
$cellWidth = [int](($canvasWidth - $margin * 2 - $gap * ($columns - 1)) / $columns)
$cellHeight = [int](($canvasHeight - $margin * 2 - $gap * ($rows - 1)) / $rows)
$imageHeight = $cellHeight - $headerHeight

$canvas = [Drawing.Bitmap]::new($canvasWidth, $canvasHeight, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
$graphics = [Drawing.Graphics]::FromImage($canvas)
$labelFont = [Drawing.Font]::new("Arial", 31, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
$detailFont = [Drawing.Font]::new("Arial", 22, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$labelBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(242, 229, 194))
$detailBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(166, 184, 196))
$borderPen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(83, 112, 126), 3)
try {
    $graphics.Clear([Drawing.Color]::FromArgb(8, 12, 18))
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality

    for ($index = 0; $index -lt $plates.Count; $index++) {
        $column = $index % $columns
        $row = [Math]::Floor($index / $columns)
        $x = $margin + $column * ($cellWidth + $gap)
        $y = $margin + $row * ($cellHeight + $gap)
        $plate = $plates[$index]
        $image = [Drawing.Image]::FromFile((Resolve-Path -LiteralPath $plate.Path))
        try {
            if ($image.Width -ne 1672 -or $image.Height -ne 941) {
                throw "$($plate.Path) must be 1672x941"
            }
            $graphics.DrawString($plate.Label, $labelFont, $labelBrush, [single]$x, [single]$y)
            $graphics.DrawString("1672x941 source candidate", $detailFont, $detailBrush, [single]$x, [single]($y + 43))
            $targetTop = $y + $headerHeight
            $scale = [Math]::Min($cellWidth / [double]$image.Width, $imageHeight / [double]$image.Height)
            $targetWidth = [int][Math]::Round($image.Width * $scale)
            $targetHeight = [int][Math]::Round($image.Height * $scale)
            $targetX = $x + [int](($cellWidth - $targetWidth) / 2)
            $targetY = $targetTop + [int](($imageHeight - $targetHeight) / 2)
            $targetRect = [Drawing.Rectangle]::new($targetX, $targetY, $targetWidth, $targetHeight)
            $graphics.DrawImage($image, $targetRect)
            $graphics.DrawRectangle($borderPen, $targetRect)
        }
        finally { $image.Dispose() }
    }

    $canvas.Save($resolvedOutput, [Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $borderPen.Dispose()
    $detailBrush.Dispose()
    $labelBrush.Dispose()
    $detailFont.Dispose()
    $labelFont.Dispose()
    $graphics.Dispose()
    $canvas.Dispose()
}

Write-Output "output=$resolvedOutput size=${canvasWidth}x${canvasHeight} plates=$($plates.Count)"
