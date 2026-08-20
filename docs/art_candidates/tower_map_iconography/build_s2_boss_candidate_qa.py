"""Build deterministic S2 boss-icon candidate QA boards and print hard gates.

This script operates only on documentation candidates. It never writes under the
Godot project or creates import metadata.
"""

from __future__ import annotations

import colorsys
from collections import deque
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
CELL = 32
ZOOM = 8
COLS = 5
ROWS = 3
DARK = (21, 27, 35, 255)
LIGHT = (239, 232, 211, 255)


@dataclass(frozen=True)
class Candidate:
    boss_id: str
    key: str


CANDIDATES = (
    Candidate("dalji", "magenta"),
    Candidate("gaksital", "magenta"),
    Candidate("podo", "magenta"),
    Candidate("cheongringwi", "magenta"),
    Candidate("molewang", "magenta"),
    Candidate("arachne", "green"),
    Candidate("yeonmyo", "magenta"),
    Candidate("teddy_bear", "magenta"),
    Candidate("alice", "green"),
    Candidate("ponk", "magenta"),
    Candidate("hongryun", "magenta"),
    Candidate("tetriser", "green"),
    Candidate("akamu_rigo", "magenta"),
    Candidate("minotaur", "magenta"),
)


def fit_icon(source: Image.Image, size: int, content_size: int) -> Image.Image:
    source = source.convert("RGBA")
    alpha = source.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("candidate has no visible pixels")
    cropped = source.crop(bbox)
    scale = min(content_size / cropped.width, content_size / cropped.height)
    target = (
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    )
    resized = cropped.resize(target, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    position = ((size - target[0]) // 2, (size - target[1]) // 2)
    canvas.alpha_composite(resized, position)
    return canvas


def edge_alpha_count(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    width, height = image.size
    edge = []
    edge.extend(alpha.crop((0, 0, width, 1)).getdata())
    edge.extend(alpha.crop((0, height - 1, width, height)).getdata())
    edge.extend(alpha.crop((0, 1, 1, height - 1)).getdata())
    edge.extend(alpha.crop((width - 1, 1, width, height - 1)).getdata())
    return sum(value != 0 for value in edge)


def key_residue_count(image: Image.Image, key: str) -> int:
    count = 0
    for red, green, blue, alpha in image.convert("RGBA").getdata():
        if alpha < 32:
            continue
        if key == "magenta":
            # The generated magenta border is not a single #ff00ff value. Its
            # green channel nevertheless stays below 48; that separates it
            # from intentional rose paint such as cheongringwi's tiny tips.
            residue = red >= 170 and blue >= 150 and green <= 48 and red - green >= 110 and blue - green >= 100
        else:
            residue = green >= 160 and green - red >= 80 and green - blue >= 80
        count += residue
    return count


def enclosed_transparent_count(image: Image.Image) -> int:
    """Count transparent pixels that cannot reach an image edge."""
    alpha = image.convert("RGBA").getchannel("A")
    width, height = image.size
    transparent = [value < 32 for value in alpha.getdata()]
    exterior = bytearray(width * height)
    queue: deque[int] = deque()

    def seed(x: int, y: int) -> None:
        index = y * width + x
        if transparent[index] and not exterior[index]:
            exterior[index] = 1
            queue.append(index)

    for x in range(width):
        seed(x, 0)
        seed(x, height - 1)
    for y in range(1, height - 1):
        seed(0, y)
        seed(width - 1, y)

    while queue:
        index = queue.popleft()
        x = index % width
        y = index // width
        if x > 0:
            seed(x - 1, y)
        if x + 1 < width:
            seed(x + 1, y)
        if y > 0:
            seed(x, y - 1)
        if y + 1 < height:
            seed(x, y + 1)

    return sum(is_transparent and not exterior[index] for index, is_transparent in enumerate(transparent))


def accent_ratio(image: Image.Image, boss_id: str) -> float:
    """Measure the intended broad color family at the actual 32px size."""
    ranges = {
        "dalji": lambda h, s, v: 190 <= h <= 250 and s >= 0.35 and v >= 0.25,
        "gaksital": lambda h, s, v: 185 <= h <= 230 and s >= 0.35 and v >= 0.30,
        "podo": lambda h, s, v: 170 <= h <= 230 and s >= 0.10 and v >= 0.45,
        "cheongringwi": lambda h, s, v: 215 <= h <= 270 and s >= 0.30 and v >= 0.25,
        "molewang": lambda h, s, v: 220 <= h <= 285 and s >= 0.18 and v >= 0.32,
        "arachne": lambda h, s, v: (h >= 300 or h <= 10) and s >= 0.12 and v >= 0.50,
        "yeonmyo": lambda h, s, v: 50 <= h <= 100 and s >= 0.45 and v >= 0.35,
        "teddy_bear": lambda h, s, v: 175 <= h <= 230 and s >= 0.10 and v >= 0.35,
        "alice": lambda h, s, v: (h >= 325 or h <= 10) and s >= 0.40 and v >= 0.35,
        "ponk": lambda h, s, v: 50 <= h <= 115 and s >= 0.40 and v >= 0.30,
        "hongryun": lambda h, s, v: 180 <= h <= 235 and s >= 0.08 and 0.20 <= v <= 0.80,
        "tetriser": lambda h, s, v: 240 <= h <= 295 and s >= 0.35 and v >= 0.25,
        "akamu_rigo": lambda h, s, v: s <= 0.25 and v >= 0.45,
        "minotaur": lambda h, s, v: s <= 0.25 and v >= 0.65,
    }
    predicate = ranges[boss_id]
    visible = 0
    accent = 0
    for red, green, blue, alpha in image.convert("RGBA").getdata():
        if alpha < 32:
            continue
        visible += 1
        hue, saturation, value = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
        accent += predicate(hue * 360, saturation, value)
    return 100.0 * accent / visible


def composite_board(
    icons: list[Image.Image],
    background: tuple[int, int, int, int],
    cols: int = COLS,
    rows: int = ROWS,
) -> Image.Image:
    board = Image.new("RGBA", (cols * CELL, rows * CELL), background)
    for index, icon in enumerate(icons):
        x = (index % cols) * CELL
        y = (index // cols) * CELL
        board.alpha_composite(icon, (x, y))
    return board


def main() -> None:
    icons_32: list[Image.Image] = []
    icons_large: list[Image.Image] = []
    failures: list[str] = []

    print("boss_id\tsource_size\tedge_alpha\tkey_residue\tenclosed_alpha_holes\taccent_32px_pct")
    for candidate in CANDIDATES:
        path = ROOT / f"s2_boss_{candidate.boss_id}_alpha.png"
        image = Image.open(path).convert("RGBA")
        edge = edge_alpha_count(image)
        residue = key_residue_count(image, candidate.key)
        icon_32 = fit_icon(image, CELL, 30)
        holes = enclosed_transparent_count(icon_32)
        ratio = accent_ratio(icon_32, candidate.boss_id)
        print(f"{candidate.boss_id}\t{image.width}x{image.height}\t{edge}\t{residue}\t{holes}\t{ratio:.2f}")
        if edge:
            failures.append(f"{candidate.boss_id}: {edge} nontransparent edge pixels")
        if residue:
            failures.append(f"{candidate.boss_id}: {residue} keyed-color residue pixels")
        if ratio < 30.0:
            failures.append(f"{candidate.boss_id}: {ratio:.2f}% accent area at 32px")
        # Transparent holes are valid intentional negative space. A keyed
        # enclosed pocket remains opaque and is caught by key_residue_count.
        icons_32.append(icon_32)
        icons_large.append(fit_icon(image, 256, 220))

    alpha_sheet = Image.new("RGBA", (COLS * 256, ROWS * 256), (0, 0, 0, 0))
    for index, icon in enumerate(icons_large):
        alpha_sheet.alpha_composite(icon, ((index % COLS) * 256, (index // COLS) * 256))
    alpha_sheet.save(ROOT / "s2_boss_candidate_alpha_sheet.png")

    dark = composite_board(icons_32, DARK)
    light = composite_board(icons_32, LIGHT)
    actual = Image.new("RGBA", (dark.width * 2, dark.height), (0, 0, 0, 0))
    actual.paste(dark, (0, 0))
    actual.paste(light, (dark.width, 0))
    actual.save(ROOT / "s2_boss_candidate_32px_dark_light.png")

    enlarged = actual.resize((actual.width * ZOOM, actual.height * ZOOM), Image.Resampling.NEAREST)
    enlarged.save(ROOT / "s2_boss_candidate_32px_zoom8_dark_light.png")

    noncombat_paths = (
        "s2_v2_shop_alpha.png",
        "s2_v2_training_alpha.png",
        "s2_v2_fallen_monk_alpha.png",
        "s2_v2_guardian_spring_alpha.png",
        "s2_v2_rest_alpha.png",
        "s2_v2_map_hint_alpha.png",
    )
    all_icons = [fit_icon(Image.open(ROOT / path), CELL, 30) for path in noncombat_paths]
    all_icons.extend(icons_32)
    all_dark = composite_board(all_icons, DARK, 5, 4)
    all_light = composite_board(all_icons, LIGHT, 5, 4)
    all_actual = Image.new("RGBA", (all_dark.width * 2, all_dark.height), (0, 0, 0, 0))
    all_actual.paste(all_dark, (0, 0))
    all_actual.paste(all_light, (all_dark.width, 0))
    all_actual.save(ROOT / "s2_all_20_candidate_32px_dark_light.png")
    all_actual.resize(
        (all_actual.width * ZOOM, all_actual.height * ZOOM),
        Image.Resampling.NEAREST,
    ).save(ROOT / "s2_all_20_candidate_32px_zoom8_dark_light.png")

    if failures:
        raise SystemExit("QA FAILED\n" + "\n".join(failures))
    print("QA PASSED: edge alpha 0, keyed-color residue 0, and all 32px accent areas >= 30%")


if __name__ == "__main__":
    main()
