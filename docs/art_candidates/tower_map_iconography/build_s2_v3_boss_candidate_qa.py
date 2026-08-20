"""Build deterministic S2 v3 20-icon QA boards and enforce hard gates.

The board order is deliberately grouped by broad color family.  This script
operates only on documentation candidates; it never writes under the Godot
project and never creates import metadata.
"""

from __future__ import annotations

import colorsys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
CELL = 32
ZOOM = 8
COLS = 4
ROWS = 5
DARK = (21, 27, 35, 255)
LIGHT = (239, 232, 211, 255)
# Fitted 32px icons deliberately occupy most of their cells, so raw overlap is
# naturally high even for visibly different contours.  Require at least 18% of
# the combined silhouette to differ; the dark/light board remains authoritative.
PAIR_IOU_LIMIT = 0.82


@dataclass(frozen=True)
class Candidate:
    icon_id: str
    path: str
    family: str
    key: str | None = None


# Two adjacent cells form one family pair.  No family may occur a third time.
CANDIDATES = (
    Candidate("shop", "s2_v2_shop_alpha.png", "gold"),
    Candidate("ponk", "s2_v3_boss_ponk_alpha.png", "gold", "magenta"),
    Candidate("training", "s2_v2_training_alpha.png", "red"),
    Candidate("gaksital", "s2_v3_boss_gaksital_alpha.png", "red", "green"),
    Candidate("fallen_monk", "s2_v2_fallen_monk_alpha.png", "purple"),
    Candidate("tetriser", "s2_v3_boss_tetriser_alpha.png", "purple", "green"),
    Candidate("guardian_spring", "s2_v2_guardian_spring_alpha.png", "green"),
    Candidate("cheongringwi", "s2_v3_boss_cheongringwi_alpha.png", "green", "magenta"),
    Candidate("rest", "s2_v2_rest_alpha.png", "orange"),
    Candidate("hongryun", "s2_v3_boss_hongryun_alpha.png", "orange", "green"),
    Candidate("map_hint", "s2_v2_map_hint_alpha.png", "cream"),
    Candidate("minotaur", "s2_v3_boss_minotaur_alpha.png", "cream", "magenta"),
    Candidate("podo", "s2_v3_boss_podo_alpha.png", "blue", "magenta"),
    Candidate("alice", "s2_v3_boss_alice_alpha.png", "blue", "magenta"),
    Candidate("arachne", "s2_v3_boss_arachne_alpha.png", "pink", "green"),
    Candidate("yeonmyo", "s2_v3_boss_yeonmyo_alpha.png", "pink", "green"),
    Candidate("molewang", "s2_v3_boss_molewang_alpha.png", "brown", "green"),
    Candidate("teddy_bear", "s2_v3_boss_teddy_bear_alpha.png", "brown", "green"),
    Candidate("dalji", "s2_v3_boss_dalji_alpha.png", "neutral", "magenta"),
    Candidate("akamu_rigo", "s2_v3_boss_akamu_rigo_alpha.png", "neutral", "green"),
)

BOSS_ORDER = (
    "dalji",
    "gaksital",
    "podo",
    "cheongringwi",
    "molewang",
    "arachne",
    "yeonmyo",
    "teddy_bear",
    "alice",
    "ponk",
    "hongryun",
    "tetriser",
    "akamu_rigo",
    "minotaur",
)


def fit_icon(source: Image.Image, size: int, content_size: int) -> Image.Image:
    source = source.convert("RGBA")
    bbox = source.getchannel("A").getbbox()
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
    canvas.alpha_composite(resized, ((size - target[0]) // 2, (size - target[1]) // 2))
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


def key_residue_count(image: Image.Image, key: str | None) -> int:
    if key is None:
        return 0
    count = 0
    for red, green, blue, alpha in image.convert("RGBA").getdata():
        if alpha < 32:
            continue
        if key == "magenta":
            residue = (
                red >= 170
                and blue >= 150
                and green <= 48
                and red - green >= 110
                and blue - green >= 100
            )
        else:
            residue = green >= 160 and green - red >= 80 and green - blue >= 80
        count += residue
    return count


def family_pixel(family: str, hue: float, saturation: float, value: float) -> bool:
    if family == "gold":
        # Include the pale lacquer highlight and umber shadow of the same gold
        # paint, not just its fully saturated center.
        return 28 <= hue <= 75 and saturation >= 0.25 and value >= 0.36
    if family == "red":
        return (hue <= 18 or hue >= 350) and saturation >= 0.45 and value >= 0.30
    if family == "purple":
        return 235 <= hue <= 335 and saturation >= 0.25 and value >= 0.25
    if family == "green":
        return 65 <= hue <= 195 and saturation >= 0.25 and value >= 0.23
    if family == "orange":
        return 5 <= hue <= 55 and saturation >= 0.45 and value >= 0.35
    if family == "cream":
        return saturation <= 0.45 and value >= 0.65
    if family == "blue":
        return 180 <= hue <= 250 and saturation >= 0.25 and value >= 0.15
    if family == "pink":
        return 305 <= hue <= 355 and saturation >= 0.18 and value >= 0.48
    if family == "brown":
        return 12 <= hue <= 48 and saturation >= 0.25 and 0.16 <= value <= 0.82
    if family == "neutral":
        return saturation <= 0.25 and value >= 0.08
    raise ValueError(f"unknown family: {family}")


def accent_ratio(image: Image.Image, family: str) -> float:
    visible = 0
    accent = 0
    for red, green, blue, alpha in image.convert("RGBA").getdata():
        if alpha < 32:
            continue
        visible += 1
        hue, saturation, value = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
        accent += family_pixel(family, hue * 360, saturation, value)
    return 100.0 * accent / visible


def silhouette_iou(left: Image.Image, right: Image.Image) -> float:
    left_mask = [value >= 32 for value in left.getchannel("A").getdata()]
    right_mask = [value >= 32 for value in right.getchannel("A").getdata()]
    intersection = sum(a and b for a, b in zip(left_mask, right_mask))
    union = sum(a or b for a, b in zip(left_mask, right_mask))
    return intersection / union


def composite_board(
    icons: list[Image.Image],
    background: tuple[int, int, int, int],
    cols: int = COLS,
    rows: int = ROWS,
) -> Image.Image:
    board = Image.new("RGBA", (cols * CELL, rows * CELL), background)
    for index, icon in enumerate(icons):
        board.alpha_composite(icon, ((index % cols) * CELL, (index // cols) * CELL))
    return board


def main() -> None:
    failures: list[str] = []
    icons_32: list[Image.Image] = []
    icons_large: list[Image.Image] = []

    family_counts = Counter(candidate.family for candidate in CANDIDATES)
    print("family_counts=" + ", ".join(f"{name}:{count}" for name, count in sorted(family_counts.items())))
    for family, count in sorted(family_counts.items()):
        if count >= 3:
            failures.append(f"{family}: family used {count} times")

    print("icon_id\tfamily\tsource_size\tedge_alpha\tkey_residue\taccent_32px_pct")
    for candidate in CANDIDATES:
        path = ROOT / candidate.path
        image = Image.open(path).convert("RGBA")
        edge = edge_alpha_count(image)
        residue = key_residue_count(image, candidate.key)
        icon_32 = fit_icon(image, CELL, 30)
        ratio = accent_ratio(icon_32, candidate.family)
        print(f"{candidate.icon_id}\t{candidate.family}\t{image.width}x{image.height}\t{edge}\t{residue}\t{ratio:.2f}")
        if edge:
            failures.append(f"{candidate.icon_id}: {edge} nontransparent edge pixels")
        if residue:
            failures.append(f"{candidate.icon_id}: {residue} keyed-color residue pixels")
        if ratio < 30.0:
            failures.append(f"{candidate.icon_id}: {ratio:.2f}% family area at 32px")
        icons_32.append(icon_32)
        icons_large.append(fit_icon(image, 256, 220))

    print("family\tleft\tright\tsilhouette_iou\tunion_difference")
    for index in range(0, len(CANDIDATES), 2):
        left = CANDIDATES[index]
        right = CANDIDATES[index + 1]
        if left.family != right.family:
            failures.append(f"board pair mismatch: {left.icon_id}/{right.icon_id}")
            continue
        iou = silhouette_iou(icons_32[index], icons_32[index + 1])
        print(f"{left.family}\t{left.icon_id}\t{right.icon_id}\t{iou:.3f}\t{1.0 - iou:.3f}")
        if iou >= PAIR_IOU_LIMIT:
            failures.append(
                f"{left.family}: {left.icon_id}/{right.icon_id} silhouette IoU {iou:.3f}"
            )

    alpha_sheet = Image.new("RGBA", (COLS * 256, ROWS * 256), (0, 0, 0, 0))
    for index, icon in enumerate(icons_large):
        alpha_sheet.alpha_composite(icon, ((index % COLS) * 256, (index // COLS) * 256))
    alpha_sheet.save(ROOT / "s2_v3_all_20_family_pairs_alpha_sheet.png")

    dark = composite_board(icons_32, DARK)
    light = composite_board(icons_32, LIGHT)
    actual = Image.new("RGBA", (dark.width * 2, dark.height), (0, 0, 0, 0))
    actual.paste(dark, (0, 0))
    actual.paste(light, (dark.width, 0))
    actual.save(ROOT / "s2_v3_all_20_family_pairs_32px_dark_light.png")
    actual.resize(
        (actual.width * ZOOM, actual.height * ZOOM),
        Image.Resampling.NEAREST,
    ).save(ROOT / "s2_v3_all_20_family_pairs_32px_zoom8_dark_light.png")

    icon_by_id = {
        candidate.icon_id: icon for candidate, icon in zip(CANDIDATES, icons_32)
    }
    boss_icons = [icon_by_id[boss_id] for boss_id in BOSS_ORDER]
    boss_dark = composite_board(boss_icons, DARK, 7, 2)
    boss_light = composite_board(boss_icons, LIGHT, 7, 2)
    boss_actual = Image.new("RGBA", (boss_dark.width * 2, boss_dark.height), (0, 0, 0, 0))
    boss_actual.paste(boss_dark, (0, 0))
    boss_actual.paste(boss_light, (boss_dark.width, 0))
    boss_actual.save(ROOT / "s2_v3_boss_14_floor_order_32px_dark_light.png")
    boss_actual.resize(
        (boss_actual.width * ZOOM, boss_actual.height * ZOOM),
        Image.Resampling.NEAREST,
    ).save(ROOT / "s2_v3_boss_14_floor_order_32px_zoom8_dark_light.png")

    if failures:
        raise SystemExit("QA FAILED\n" + "\n".join(failures))
    print(
        "QA PASSED: no family count >= 3; edge alpha 0; keyed residue 0; "
        "all family areas >= 30%; paired silhouette union difference > 18%"
    )


if __name__ == "__main__":
    main()
