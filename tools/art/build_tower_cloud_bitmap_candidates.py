#!/usr/bin/env python3
"""Build review-only Tower map cloud bitmap candidates and evidence.

This script intentionally writes outside ``godot/assets``. Stage A candidates
must remain disconnected from the runtime catalog until explicit approval.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


REPO_ROOT = Path(__file__).resolve().parents[2]
CANDIDATE_ROOT = REPO_ROOT / "images" / "tower_map_cloud_bitmap_candidates_cc3b"
RAW_ROOT = CANDIDATE_ROOT / "source_raw"
ASSET_ROOT = CANDIDATE_ROOT / "candidates"
REVIEW_ROOT = CANDIDATE_ROOT / "review"
MAP_SCROLL_ROOT = REPO_ROOT / "godot" / "assets" / "sprites" / "tower" / "map_scroll"

INK = np.array([0x30, 0x27, 0x1F], dtype=np.float32)
PAPER_LIGHT = np.array([0xF1, 0xDF, 0xB8], dtype=np.float32)
PAPER_DEEP = np.array([0xD7, 0xBD, 0x88], dtype=np.float32)
SURROUND = (0x18, 0x15, 0x12, 0xFF)
WORLD_BAND_SIZE = (692, 320)
X4 = 4

SPECS = {
    "cloud_swirl_large": {
        "raw": "cloud_swirl_large_imagegen_raw.png",
        "world_size": (260, 160),
        "texture_size": (1040, 640),
        "alpha_min": 0.18,
        "alpha_max": 0.68,
    },
    "cloud_swirl_medium": {
        "raw": "cloud_swirl_medium_imagegen_raw.png",
        "world_size": (196, 112),
        "texture_size": (784, 448),
        "alpha_min": 0.16,
        "alpha_max": 0.62,
    },
    "cloud_wisp": {
        "raw": "cloud_wisp_imagegen_raw.png",
        "world_size": (152, 64),
        "texture_size": (608, 256),
        "alpha_min": 0.10,
        "alpha_max": 0.48,
    },
    "cloud_haze_band": {
        "raw": "cloud_haze_band_imagegen_raw.png",
        "world_size": (692, 144),
        "texture_size": (2768, 576),
        "alpha_min": 0.10,
        "alpha_max": 0.46,
        "tileable_x": True,
    },
}


def smoothstep(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
    scaled = np.clip((value - edge0) / max(1.0e-6, edge1 - edge0), 0.0, 1.0)
    return scaled * scaled * (3.0 - 2.0 * scaled)


def alpha_bbox(image: Image.Image, threshold: int = 3) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.nonzero(alpha > threshold)
    if xs.size == 0 or ys.size == 0:
        return (0, 0, image.width, image.height)
    pad_x = max(4, int(round((xs.max() - xs.min() + 1) * 0.04)))
    pad_y = max(4, int(round((ys.max() - ys.min() + 1) * 0.05)))
    return (
        max(0, int(xs.min()) - pad_x),
        max(0, int(ys.min()) - pad_y),
        min(image.width, int(xs.max()) + 1 + pad_x),
        min(image.height, int(ys.max()) + 1 + pad_y),
    )


def contain_rgba(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    cropped = image.crop(alpha_bbox(image))
    scale = min(size[0] / cropped.width, size[1] / cropped.height)
    resized = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(
        resized,
        ((size[0] - resized.width) // 2, (size[1] - resized.height) // 2),
    )
    return canvas


def cover_rgba(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    cropped = image.crop(alpha_bbox(image))
    scale = max(size[0] / cropped.width, size[1] / cropped.height)
    resized = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        Image.Resampling.LANCZOS,
    )
    left = max(0, (resized.width - size[0]) // 2)
    top = max(0, (resized.height - size[1]) // 2)
    return resized.crop((left, top, left + size[0], top + size[1]))


def reconstruct_soft_alpha(
    image: Image.Image,
    alpha_minimum: float,
    alpha_maximum: float,
) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    rgb = rgba[..., :3]
    source_alpha = rgba[..., 3] / 255.0

    # Use luminance only for opacity/material variation, then rebuild RGB on a
    # fixed warm ink-to-hanji axis. This removes generated green/magenta edge
    # contamination rather than trying to key it out after the fact.
    luminance = (
        rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722
    )
    ink_luma = float(INK @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32))
    paper_luma = float(
        PAPER_LIGHT @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    )
    paper_ratio = smoothstep(
        ink_luma * 0.88,
        paper_luma * 1.02,
        luminance,
    )
    opacity_strength = alpha_minimum + (
        alpha_maximum - alpha_minimum
    ) * np.power(1.0 - paper_ratio, 0.72)

    softened_alpha = np.asarray(
        Image.fromarray(np.uint8(np.clip(source_alpha * 255.0, 0.0, 255.0))).filter(
            ImageFilter.GaussianBlur(radius=1.65)
        ),
        dtype=np.float32,
    ) / 255.0
    final_alpha = np.clip(
        (source_alpha * 0.34 + softened_alpha * 0.66) * opacity_strength,
        0.0,
        1.0,
    )

    # Preserve generated wash lightness while keeping every visible pixel in
    # the approved warm palette gamut.
    warm_paper = PAPER_DEEP[None, None, :] * (1.0 - paper_ratio[..., None] * 0.58) + (
        PAPER_LIGHT[None, None, :] * paper_ratio[..., None] * 0.58
    )
    final_rgb = INK[None, None, :] * (1.0 - paper_ratio[..., None]) + (
        warm_paper * paper_ratio[..., None]
    )
    output = np.empty_like(rgba, dtype=np.uint8)
    output[..., :3] = np.uint8(np.clip(np.round(final_rgb), 0.0, 255.0))
    output[..., 3] = np.uint8(np.clip(np.round(final_alpha * 255.0), 0.0, 255.0))
    output[output[..., 3] == 0, :3] = np.uint8(INK)
    return Image.fromarray(output)


def make_tileable_x(image: Image.Image) -> Image.Image:
    arr = np.asarray(image.convert("RGBA"), dtype=np.float32)
    width = arr.shape[1]
    rolled = np.roll(arr, width // 2, axis=1)

    # The roll moves the candidate repeat edge to an originally continuous
    # interior span. Replace the now-central source edge with an interior patch
    # and feather broadly so neither transition forms a vertical line.
    xs = np.arange(width, dtype=np.float32)
    distance = np.abs(xs - (width - 1) * 0.5) / max(1.0, width * 0.5)
    center_weight = 1.0 - smoothstep(0.10, 0.42, distance)
    center_weight = center_weight[None, :, None]
    combined = rolled * (1.0 - center_weight) + arr * center_weight

    # Make the repeated boundary a pair of equal feathered columns while
    # retaining adjacent interior texture on both sides.
    edge_average = (combined[:, 0, :] + combined[:, -1, :]) * 0.5
    combined[:, 0, :] = edge_average
    combined[:, -1, :] = edge_average
    return Image.fromarray(np.uint8(np.clip(np.round(combined), 0.0, 255.0)))


def asset_metrics(image: Image.Image) -> dict[str, object]:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    rgb = rgba[..., :3].astype(np.int16)
    alpha = rgba[..., 3]
    visible = alpha > 0
    intermediate = (alpha > 0) & (alpha < 255)
    thin = (alpha > 0) & (alpha <= 96)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    green_fringe = visible & (green > red + 36) & (green > blue + 36)
    magenta_fringe = visible & (red > green + 36) & (blue > green + 36)
    exact_green = visible & (red == 0) & (green == 255) & (blue == 0)
    visible_count = int(visible.sum())
    return {
        "texture_size": [image.width, image.height],
        "visible_pixels": visible_count,
        "intermediate_alpha_pixels": int(intermediate.sum()),
        "intermediate_alpha_ratio_of_visible": round(
            float(intermediate.sum()) / max(1, visible_count), 6
        ),
        "thin_alpha_pixels_le_96": int(thin.sum()),
        "thin_alpha_ratio_of_visible": round(float(thin.sum()) / max(1, visible_count), 6),
        "alpha_min_visible": int(alpha[visible].min()) if visible_count else 0,
        "alpha_max": int(alpha.max()),
        "alpha_unique_levels": int(np.unique(alpha).size),
        "green_fringe_pixels": int(green_fringe.sum()),
        "magenta_fringe_pixels": int(magenta_fringe.sum()),
        "exact_00ff00_pixels": int(exact_green.sum()),
    }


def tile_edge_metrics(image: Image.Image) -> dict[str, object]:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.int16)
    edge_delta = np.abs(rgba[:, 0, :] - rgba[:, -1, :])
    adjacent_delta = np.abs(rgba[:, 1, :] - rgba[:, 0, :])
    return {
        "edge_mean_abs_rgba_delta": round(float(edge_delta.mean()), 6),
        "edge_max_abs_rgba_delta": int(edge_delta.max()),
        "first_interior_mean_abs_rgba_delta": round(float(adjacent_delta.mean()), 6),
    }


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        Path("C:/Windows/Fonts/malgun.ttf"),
        Path("C:/Windows/Fonts/arial.ttf"),
    ):
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def checker(size: tuple[int, int], cell: int = 40) -> Image.Image:
    image = Image.new("RGBA", size, SURROUND)
    draw = ImageDraw.Draw(image)
    colors = ((0xF1, 0xDF, 0xB8, 255), (0xD7, 0xBD, 0x88, 255))
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            draw.rectangle(
                (x, y, min(size[0], x + cell), min(size[1], y + cell)),
                fill=colors[((x // cell) + (y // cell)) % 2],
            )
    draw.rectangle((size[0] // 2, 0, size[0], size[1]), fill=SURROUND)
    return image


def fit_image(image: Image.Image, size: tuple[int, int], margin: int = 20) -> Image.Image:
    inner = (max(1, size[0] - margin * 2), max(1, size[1] - margin * 2))
    scale = min(inner[0] / image.width, inner[1] / image.height)
    return image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.LANCZOS,
    )


def make_contact_sheet(assets: dict[str, Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", (2200, 1400), SURROUND)
    draw = ImageDraw.Draw(sheet)
    title_font = load_font(42)
    label_font = load_font(28)
    draw.text(
        (55, 30),
        "Tower map cloud bitmap candidates · Stage A",
        fill=tuple(int(value) for value in PAPER_LIGHT) + (255,),
        font=title_font,
    )
    slots = {
        "cloud_swirl_large": (50, 105, 1020, 560),
        "cloud_swirl_medium": (1130, 105, 1020, 560),
        "cloud_wisp": (50, 735, 1020, 560),
        "cloud_haze_band": (1130, 735, 1020, 560),
    }
    for name, (x, y, width, height) in slots.items():
        panel = checker((width, height))
        display = fit_image(assets[name], (width, height - 58), margin=20)
        panel.alpha_composite(display, ((width - display.width) // 2, 48 + (height - 58 - display.height) // 2))
        sheet.alpha_composite(panel, (x, y))
        draw.rectangle((x, y, x + width, y + height), outline=(0xD7, 0xBD, 0x88, 255), width=3)
        spec = SPECS[name]
        draw.text(
            (x + 18, y + 12),
            f"{name}  ·  world {spec['world_size'][0]}×{spec['world_size'][1]}  ·  x4 {spec['texture_size'][0]}×{spec['texture_size'][1]}",
            fill=(0x30, 0x27, 0x1F, 255),
            stroke_fill=(0xF1, 0xDF, 0xB8, 230),
            stroke_width=3,
            font=label_font,
        )
    return sheet


def alpha_scaled(image: Image.Image, multiplier: float) -> Image.Image:
    output = image.copy()
    alpha = np.asarray(output.getchannel("A"), dtype=np.float32)
    output.putalpha(Image.fromarray(np.uint8(np.clip(np.round(alpha * multiplier), 0, 255))))
    return output


def place(base: Image.Image, overlay: Image.Image, xy: tuple[int, int], alpha: float = 1.0) -> None:
    base.alpha_composite(alpha_scaled(overlay, alpha), xy)


def build_floor_cloud_composite(
    base_band: Image.Image,
    assets: dict[str, Image.Image],
    reveal_alpha: float,
) -> tuple[Image.Image, Image.Image]:
    overlay = Image.new("RGBA", base_band.size, (0, 0, 0, 0))
    haze = assets["cloud_haze_band"]
    place(overlay, haze, (0, 350), 0.92 * reveal_alpha)
    place(overlay, assets["cloud_swirl_large"], (-70, 180), 0.88 * reveal_alpha)
    place(overlay, assets["cloud_swirl_medium"], (1780, 90), 0.82 * reveal_alpha)
    place(overlay, assets["cloud_wisp"], (1050, 720), 0.92 * reveal_alpha)
    composite = Image.alpha_composite(base_band.convert("RGBA"), overlay)
    return composite, overlay


def terrain_visibility_metrics(base: Image.Image, composite: Image.Image, overlay: Image.Image) -> dict[str, object]:
    base_gray = np.asarray(base.convert("L"), dtype=np.float32)
    composite_gray = np.asarray(composite.convert("L"), dtype=np.float32)
    alpha = np.asarray(overlay.getchannel("A"), dtype=np.uint8)
    covered = alpha >= 16
    thin = (alpha >= 16) & (alpha <= 96)

    def correlation(mask: np.ndarray) -> float:
        if int(mask.sum()) < 2:
            return 0.0
        left = base_gray[mask]
        right = composite_gray[mask]
        if left.std() < 1.0e-6 or right.std() < 1.0e-6:
            return 0.0
        return float(np.corrcoef(left, right)[0, 1])

    return {
        "covered_pixels": int(covered.sum()),
        "thin_cloud_pixels": int(thin.sum()),
        "terrain_luma_correlation_under_all_cloud": round(correlation(covered), 6),
        "terrain_luma_correlation_under_thin_cloud": round(correlation(thin), 6),
        "mean_abs_luma_change_under_thin_cloud": round(
            float(np.abs(composite_gray[thin] - base_gray[thin]).mean()) if thin.any() else 0.0,
            6,
        ),
    }


def evidence_crop(image: Image.Image, title: str) -> Image.Image:
    target = image.resize((1384, 640), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (1384, 720), SURROUND)
    canvas.alpha_composite(target, (0, 80))
    ImageDraw.Draw(canvas).text(
        (34, 20),
        title,
        fill=tuple(int(value) for value in PAPER_LIGHT) + (255,),
        font=load_font(34),
    )
    return canvas


def build_fit_all(assets: dict[str, Image.Image]) -> Image.Image:
    band_names = [
        "human_realm_01_mountain_rev2_x4.png",
        "human_realm_02_village_rev2_x4.png",
        "human_realm_03_river_rev2_x4.png",
        "immortal_realm_01_islands_rev2_x4.png",
        "immortal_realm_02_cloud_cranes_rev2_x4.png",
        "immortal_realm_03_pavilions_rev2_x4.png",
    ]
    world = Image.new("RGBA", (692, 3840), (0, 0, 0, 0))
    small_assets = {
        name: image.resize(SPECS[name]["world_size"], Image.Resampling.LANCZOS)
        for name, image in assets.items()
    }
    for floor_index in range(12):
        band = Image.open(MAP_SCROLL_ROOT / band_names[floor_index % len(band_names)]).convert("RGB")
        band = band.resize(WORLD_BAND_SIZE, Image.Resampling.LANCZOS).convert("RGBA")
        y = floor_index * 320
        world.alpha_composite(band, (0, y))
        floor_overlay = Image.new("RGBA", WORLD_BAND_SIZE, (0, 0, 0, 0))
        place(floor_overlay, small_assets["cloud_haze_band"], (0, 84), 0.92)
        if floor_index % 2 == 0:
            place(floor_overlay, small_assets["cloud_swirl_large"], (-18, 98), 0.78)
            place(floor_overlay, small_assets["cloud_wisp"], (405, 52), 0.84)
        else:
            place(floor_overlay, small_assets["cloud_swirl_medium"], (458, 120), 0.82)
            place(floor_overlay, small_assets["cloud_wisp"], (38, 46), 0.84)
        world.alpha_composite(floor_overlay, (0, y))

    canvas = Image.new("RGBA", (2020, 1246), SURROUND)
    scroll = world.resize((218, 1120), Image.Resampling.LANCZOS)
    x = (canvas.width - scroll.width) // 2
    y = 74
    canvas.alpha_composite(scroll, (x, y))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((x - 5, y, x - 1, y + scroll.height), fill=(0x30, 0x27, 0x1F, 210))
    draw.rectangle((x + scroll.width, y, x + scroll.width + 4, y + scroll.height), fill=(0x30, 0x27, 0x1F, 210))
    draw.text(
        (42, 24),
        "Fit-all judgment · 12 floor bands",
        fill=tuple(int(value) for value in PAPER_LIGHT) + (255,),
        font=load_font(38),
    )
    return canvas


def build_surround_edge(base_band: Image.Image, assets: dict[str, Image.Image]) -> Image.Image:
    canvas = Image.new("RGBA", (2020, 1246), SURROUND)
    paper = base_band.resize((1450, 670), Image.Resampling.LANCZOS)
    paper_x, paper_y = 380, 300
    canvas.alpha_composite(paper, (paper_x, paper_y))
    cloud = assets["cloud_swirl_large"].resize((1040, 640), Image.Resampling.LANCZOS)
    canvas.alpha_composite(cloud, (118, 325))
    haze = assets["cloud_haze_band"].resize((1450, 302), Image.Resampling.LANCZOS)
    canvas.alpha_composite(haze, (paper_x, 620))
    draw = ImageDraw.Draw(canvas)
    draw.text(
        (42, 24),
        "Surround edge judgment · soft alpha crosses ink field",
        fill=tuple(int(value) for value in PAPER_LIGHT) + (255,),
        font=load_font(38),
    )
    return canvas


def main() -> None:
    ASSET_ROOT.mkdir(parents=True, exist_ok=True)
    REVIEW_ROOT.mkdir(parents=True, exist_ok=True)
    assets: dict[str, Image.Image] = {}
    report: dict[str, object] = {
        "stage": "A_candidate_only",
        "runtime_wired": False,
        "world_band_size": list(WORLD_BAND_SIZE),
        "texture_density": "x4",
        "assets": {},
    }

    for name, spec in SPECS.items():
        raw = Image.open(RAW_ROOT / str(spec["raw"])).convert("RGBA")
        target_size = tuple(spec["texture_size"])
        sized = cover_rgba(raw, target_size) if spec.get("tileable_x") else contain_rgba(raw, target_size)
        candidate = reconstruct_soft_alpha(
            sized,
            float(spec["alpha_min"]),
            float(spec["alpha_max"]),
        )
        if spec.get("tileable_x"):
            candidate = make_tileable_x(candidate)
        output_path = ASSET_ROOT / f"{name}_imagegen_candidate_x4.png"
        candidate.save(output_path, optimize=True)
        assets[name] = candidate
        metrics = asset_metrics(candidate)
        metrics["world_size"] = list(spec["world_size"])
        metrics["source_raw"] = str((RAW_ROOT / str(spec["raw"])).relative_to(REPO_ROOT)).replace("\\", "/")
        if spec.get("tileable_x"):
            metrics["tile_edge"] = tile_edge_metrics(candidate)
        report["assets"][name] = metrics

    contact_sheet = make_contact_sheet(assets)
    contact_sheet.save(REVIEW_ROOT / "01_contact_sheet.png", optimize=True)

    base_band = Image.open(MAP_SCROLL_ROOT / "immortal_realm_02_cloud_cranes_rev2_x4.png").convert("RGBA")
    locked, locked_overlay = build_floor_cloud_composite(base_band, assets, 1.0)
    revealing, _ = build_floor_cloud_composite(base_band, assets, 0.5)
    evidence_crop(locked, "Locked floor terrain · full cloud opacity").save(
        REVIEW_ROOT / "02_locked_floor_composite.png", optimize=True
    )
    evidence_crop(revealing, "Reveal midpoint · 50% visual fade").save(
        REVIEW_ROOT / "03_reveal_midpoint_composite.png", optimize=True
    )
    build_fit_all(assets).save(REVIEW_ROOT / "04_fit_all_composite.png", optimize=True)
    build_surround_edge(base_band, assets).save(
        REVIEW_ROOT / "05_surround_edge_composite.png", optimize=True
    )

    haze = assets["cloud_haze_band"]
    triplet = Image.new("RGBA", (haze.width * 3, haze.height), SURROUND)
    for index in range(3):
        triplet.alpha_composite(haze, (index * haze.width, 0))
    triplet.save(REVIEW_ROOT / "06_haze_band_3x_seam_proof_x4.png", optimize=True)
    triplet.resize((2076, 432), Image.Resampling.LANCZOS).save(
        REVIEW_ROOT / "07_haze_band_3x_seam_review.png", optimize=True
    )

    report["terrain_visibility"] = terrain_visibility_metrics(
        base_band, locked, locked_overlay
    )
    (REVIEW_ROOT / "A_STAGE_QA.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
