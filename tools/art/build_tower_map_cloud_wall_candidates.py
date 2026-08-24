#!/usr/bin/env python3
"""Build review-only Tower map cloud-wall candidates and evidence.

The outputs intentionally stay under ``images/``. They are not registered in
the Godot asset catalog and must not be consumed by runtime code before the
Stage A approval gate is cleared.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


REPO_ROOT = Path(__file__).resolve().parents[2]
CANDIDATE_ROOT = REPO_ROOT / "images" / "tower_map_cloud_wall_candidates_e757"
RAW_ROOT = CANDIDATE_ROOT / "source_raw"
ASSET_ROOT = CANDIDATE_ROOT / "candidates"
REVIEW_ROOT = CANDIDATE_ROOT / "review"
REFERENCE_PATH = (
    REPO_ROOT
    / "docs"
    / "reference_art"
    / "tower_map_cloud_wall_reference_20260824.png"
)

INK = np.array([0x30, 0x27, 0x1F], dtype=np.float32)
SMOKE_MID = np.array([0x72, 0x60, 0x4B], dtype=np.float32)
SMOKE_LIGHT = np.array([0xB8, 0x9F, 0x78], dtype=np.float32)
PAPER_LIGHT = np.array([0xF1, 0xDF, 0xB8], dtype=np.float32)
PAPER_DEEP = np.array([0xD7, 0xBD, 0x88], dtype=np.float32)
SURROUND = (0x18, 0x15, 0x12, 0xFF)
WORLD_WIDTH = 692
X4 = 4

SPECS = {
    "cloud_wall_interior_dense_a": {
        "raw": "cloud_wall_interior_dense_a_imagegen_raw.png",
        "world_size": (WORLD_WIDTH, 320),
        "texture_size": (WORLD_WIDTH * X4, 320 * X4),
        "tileable_x": True,
        "tileable_y": True,
    },
    "cloud_wall_interior_macro_b": {
        "raw": "cloud_wall_interior_macro_b_imagegen_raw.png",
        "world_size": (WORLD_WIDTH, 320),
        "texture_size": (WORLD_WIDTH * X4, 320 * X4),
        "tileable_x": True,
        "tileable_y": True,
    },
    "cloud_wall_dissolve": {
        "raw": "cloud_wall_dissolve_imagegen_raw_v2_false_alpha.png",
        "world_size": (WORLD_WIDTH, 224),
        "texture_size": (WORLD_WIDTH * X4, 224 * X4),
        "tileable_x": True,
        "dissolve": True,
    },
}


def smoothstep(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
    scaled = np.clip((value - edge0) / max(1.0e-6, edge1 - edge0), 0.0, 1.0)
    return scaled * scaled * (3.0 - 2.0 * scaled)


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.LANCZOS,
    )
    left = max(0, (resized.width - size[0]) // 2)
    top = max(0, (resized.height - size[1]) // 2)
    return resized.crop((left, top, left + size[0], top + size[1])).convert("RGBA")


def palette_rgb(rgb: np.ndarray) -> np.ndarray:
    luminance = (
        rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722
    )
    low, high = np.percentile(luminance, (2.0, 98.0))
    tone = np.clip((luminance - low) / max(1.0, high - low), 0.0, 1.0)
    tone = np.power(tone, 0.92)
    first = np.clip(tone / 0.58, 0.0, 1.0)[..., None]
    second = np.clip((tone - 0.58) / 0.42, 0.0, 1.0)[..., None]
    dark_to_mid = INK[None, None, :] * (1.0 - first) + SMOKE_MID[None, None, :] * first
    return dark_to_mid * (1.0 - second) + SMOKE_LIGHT[None, None, :] * second


def make_tileable_axis(image: Image.Image, axis: int) -> Image.Image:
    arr = np.asarray(image.convert("RGBA"), dtype=np.float32)
    length = arr.shape[axis]
    rolled = np.roll(arr, length // 2, axis=axis)

    positions = np.arange(length, dtype=np.float32)
    distance = np.abs(positions - (length - 1) * 0.5) / max(1.0, length * 0.5)
    center_weight = 1.0 - smoothstep(0.10, 0.42, distance)
    weight_shape = [1, 1, 1]
    weight_shape[axis] = length
    center_weight = center_weight.reshape(weight_shape)
    combined = rolled * (1.0 - center_weight) + arr * center_weight

    if axis == 1:
        edge = (combined[:, 0, :] + combined[:, -1, :]) * 0.5
        combined[:, 0, :] = edge
        combined[:, -1, :] = edge
    else:
        edge = (combined[0, :, :] + combined[-1, :, :]) * 0.5
        combined[0, :, :] = edge
        combined[-1, :, :] = edge
    return Image.fromarray(np.uint8(np.clip(np.round(combined), 0.0, 255.0)))


def reconstruct_wall(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    output = np.empty_like(rgba, dtype=np.uint8)
    output[..., :3] = np.uint8(np.clip(np.round(palette_rgb(rgba[..., :3])), 0, 255))
    output[..., 3] = 255
    return Image.fromarray(output)


def reconstruct_dissolve(image: Image.Image, join_wall: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    rgb = rgba[..., :3]
    luminance = rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722
    dark_strength = np.clip((247.0 - luminance) / 124.0, 0.0, 1.0)
    warm_strength = np.clip((rgb[..., 0] - rgb[..., 2] - 2.0) / 54.0, 0.0, 1.0)
    source_strength = np.maximum(dark_strength, warm_strength * 0.92)
    source_strength = np.asarray(
        Image.fromarray(np.uint8(np.round(source_strength * 255.0))).filter(
            ImageFilter.GaussianBlur(radius=2.4)
        ),
        dtype=np.float32,
    ) / 255.0

    y = np.linspace(0.0, 1.0, image.height, dtype=np.float32)[:, None]
    opaque_join = 1.0 - smoothstep(0.16, 0.32, y)
    downward_fade = 1.0 - smoothstep(0.30, 0.83, y)
    alpha = np.maximum(source_strength, opaque_join) * downward_fade

    # Keep mean opacity monotonically non-increasing down the strip so the
    # reveal boundary cannot read as a second horizontal band.
    previous_mean = 1.0
    for row_index in range(alpha.shape[0]):
        row_mean = float(alpha[row_index].mean())
        if row_mean > previous_mean and row_mean > 1.0e-6:
            alpha[row_index] *= previous_mean / row_mean
        else:
            previous_mean = row_mean
    alpha[int(round(image.height * 0.85)) :, :] = 0.0

    mask = np.zeros_like(rgba, dtype=np.uint8)
    mask[..., 3] = np.uint8(np.clip(np.round(alpha * 255.0), 0, 255))
    tileable_mask = np.asarray(
        make_tileable_axis(Image.fromarray(mask), 1).convert("RGBA"), dtype=np.uint8
    )[..., 3]

    wall_rgba = np.asarray(join_wall.convert("RGBA"), dtype=np.uint8)
    repeats = (image.height + join_wall.height - 1) // join_wall.height
    joined_rgb = np.tile(wall_rgba[..., :3], (repeats, 1, 1))[: image.height]
    output = np.empty_like(rgba, dtype=np.uint8)
    output[..., :3] = joined_rgb
    output[..., 3] = tileable_mask
    output[output[..., 3] == 0, :3] = np.uint8(INK)
    return Image.fromarray(output)


def enforce_monotonic_alpha(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    alpha = rgba[..., 3].copy()
    alpha[int(round(image.height * 0.85)) :, :] = 0
    previous_sum = int(alpha.shape[1] * 255)
    for row_index in range(alpha.shape[0]):
        current_sum = int(alpha[row_index].astype(np.uint64).sum())
        if current_sum > previous_sum and current_sum > 0:
            scaled = np.floor(
                alpha[row_index].astype(np.float64) * previous_sum / current_sum
            )
            alpha[row_index] = np.uint8(np.clip(scaled, 0, 255))
            current_sum = int(alpha[row_index].astype(np.uint64).sum())
        previous_sum = current_sum
    rgba[..., 3] = alpha
    rgba[rgba[..., 3] == 0, :3] = np.uint8(INK)
    return Image.fromarray(rgba)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def asset_metrics(image: Image.Image, spec: dict[str, object]) -> dict[str, object]:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    rgb = rgba[..., :3]
    alpha = rgba[..., 3]
    visible = alpha > 0
    result: dict[str, object] = {
        "world_size": list(spec["world_size"]),
        "texture_size": [image.width, image.height],
        "visible_pixels": int(visible.sum()),
        "opaque_pixels": int((alpha == 255).sum()),
        "transparent_pixels": int((alpha == 0).sum()),
        "intermediate_alpha_pixels": int(((alpha > 0) & (alpha < 255)).sum()),
        "alpha_min": int(alpha.min()),
        "alpha_max": int(alpha.max()),
        "near_white_pixels": int(np.all(rgb >= 232, axis=2).sum()),
    }
    if spec.get("tileable_x"):
        edge = np.abs(rgba[:, 0, :].astype(np.int16) - rgba[:, -1, :].astype(np.int16))
        result["x_edge_mean_abs_rgba_delta"] = round(float(edge.mean()), 6)
        result["x_edge_max_abs_rgba_delta"] = int(edge.max())
    if spec.get("tileable_y"):
        edge = np.abs(rgba[0, :, :].astype(np.int16) - rgba[-1, :, :].astype(np.int16))
        result["y_edge_mean_abs_rgba_delta"] = round(float(edge.mean()), 6)
        result["y_edge_max_abs_rgba_delta"] = int(edge.max())
    if spec.get("dissolve"):
        row_means = alpha.astype(np.float32).mean(axis=1)
        result["top_20pct_mean_alpha"] = round(float(row_means[: max(1, image.height // 5)].mean()), 6)
        result["bottom_15pct_max_alpha"] = int(alpha[int(round(image.height * 0.85)) :, :].max())
        result["row_mean_alpha_increase_count"] = int((np.diff(row_means) > 0.01).sum())
    return result


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (Path("C:/Windows/Fonts/malgun.ttf"), Path("C:/Windows/Fonts/arial.ttf")):
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def checker(size: tuple[int, int], cell: int = 32) -> Image.Image:
    image = Image.new("RGBA", size, SURROUND)
    draw = ImageDraw.Draw(image)
    colors = ((0xF1, 0xDF, 0xB8, 255), (0xD7, 0xBD, 0x88, 255))
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            draw.rectangle(
                (x, y, min(size[0], x + cell), min(size[1], y + cell)),
                fill=colors[((x // cell) + (y // cell)) % 2],
            )
    return image


def fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    scale = min(size[0] / image.width, size[1] / image.height)
    return image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.LANCZOS,
    )


def draw_panel(
    sheet: Image.Image,
    image: Image.Image,
    rect: tuple[int, int, int, int],
    title: str,
    transparent: bool = False,
) -> None:
    x, y, width, height = rect
    panel = checker((width, height)) if transparent else Image.new("RGBA", (width, height), SURROUND)
    display = fit(image, (width - 32, height - 74))
    panel.alpha_composite(display, ((width - display.width) // 2, 58 + (height - 66 - display.height) // 2))
    sheet.alpha_composite(panel, (x, y))
    draw = ImageDraw.Draw(sheet)
    draw.rectangle((x, y, x + width, y + height), outline=(0xD7, 0xBD, 0x88, 255), width=3)
    draw.text(
        (x + 16, y + 12),
        title,
        fill=tuple(int(value) for value in PAPER_LIGHT) + (255,),
        stroke_fill=(0x30, 0x27, 0x1F, 255),
        stroke_width=3,
        font=load_font(28),
    )


def contact_sheet(reference: Image.Image, assets: dict[str, Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", (2400, 1600), SURROUND)
    draw = ImageDraw.Draw(sheet)
    draw.text(
        (48, 24),
        "Tower map cloud wall · Stage A candidate review",
        fill=tuple(int(value) for value in PAPER_LIGHT) + (255,),
        font=load_font(42),
    )
    draw_panel(sheet, reference, (48, 92, 720, 1450), "REFERENCE · user-provided")
    draw_panel(
        sheet,
        assets["cloud_wall_interior_dense_a"],
        (812, 92, 1540, 570),
        "A · dense connected wall · 692×320 world · seamless XY",
    )
    draw_panel(
        sheet,
        assets["cloud_wall_interior_macro_b"],
        (812, 700, 1540, 570),
        "B · macro-flow comparison · REJECT: broad light-channel risk",
    )
    draw_panel(
        sheet,
        assets["cloud_wall_dissolve"],
        (812, 1308, 1540, 234),
        "shared lower dissolve · 692×224 world · seamless X · real alpha",
        transparent=True,
    )
    return sheet


def seam_proof(image: Image.Image, repeats_x: int, repeats_y: int, transparent: bool) -> Image.Image:
    world = image.resize((image.width // X4, image.height // X4), Image.Resampling.LANCZOS)
    size = (world.width * repeats_x, world.height * repeats_y)
    canvas = checker(size, cell=24) if transparent else Image.new("RGBA", size, SURROUND)
    for y in range(repeats_y):
        for x in range(repeats_x):
            canvas.alpha_composite(world, (x * world.width, y * world.height))
    return canvas


def alpha_scaled(image: Image.Image, multiplier: float) -> Image.Image:
    output = image.copy()
    alpha = np.asarray(output.getchannel("A"), dtype=np.float32)
    output.putalpha(Image.fromarray(np.uint8(np.clip(np.round(alpha * multiplier), 0, 255))))
    return output


def reference_mockup(reference: Image.Image, wall: Image.Image, dissolve: Image.Image, label: str) -> Image.Image:
    # The scoreboard is a separate screen-space layer in production. Crop it
    # out here so the review sheet judges only the map/cloud relationship.
    base = reference.crop((0, 108, reference.width, reference.height)).convert("RGBA")
    wall_scaled_height = round(320 * base.width / WORLD_WIDTH)
    dissolve_top = wall_scaled_height * 2
    dissolve_height = 285
    wall_world = wall.resize((WORLD_WIDTH, 320), Image.Resampling.LANCZOS)
    wall_scaled = wall_world.resize((base.width, wall_scaled_height), Image.Resampling.LANCZOS)
    wall_end = dissolve_top
    y = 0
    while y < wall_end:
        height = min(wall_scaled.height, wall_end - y)
        base.alpha_composite(wall_scaled.crop((0, 0, wall_scaled.width, height)), (0, y))
        y += wall_scaled.height
    dissolve_scaled = dissolve.resize((base.width, dissolve_height), Image.Resampling.LANCZOS)
    base.alpha_composite(dissolve_scaled, (0, dissolve_top))

    canvas = Image.new("RGBA", (base.width, base.height + 72), SURROUND)
    canvas.alpha_composite(base, (0, 72))
    ImageDraw.Draw(canvas).text(
        (24, 18),
        label,
        fill=tuple(int(value) for value in PAPER_LIGHT) + (255,),
        font=load_font(30),
    )
    return canvas


def main() -> None:
    ASSET_ROOT.mkdir(parents=True, exist_ok=True)
    REVIEW_ROOT.mkdir(parents=True, exist_ok=True)
    assets: dict[str, Image.Image] = {}
    report: dict[str, object] = {
        "stage": "A_candidate_only",
        "runtime_wired": False,
        "reference": {
            "path": str(REFERENCE_PATH.relative_to(REPO_ROOT)).replace("\\", "/"),
            "sha256": sha256(REFERENCE_PATH),
        },
        "texture_density": "x4",
        "assets": {},
        "rejected_sources": [
            "images/tower_map_cloud_wall_candidates_e757/candidates/cloud_wall_interior_macro_b_imagegen_candidate_x4.png",
            "images/tower_map_cloud_wall_candidates_e757/source_raw/cloud_wall_dissolve_imagegen_raw_v1_false_alpha.png",
            "images/tower_map_cloud_wall_candidates_e757/source_raw/cloud_wall_dissolve_imagegen_raw_v2_false_alpha.png",
        ],
        "recommended_assets": [
            "images/tower_map_cloud_wall_candidates_e757/candidates/cloud_wall_interior_dense_a_imagegen_candidate_x4.png",
            "images/tower_map_cloud_wall_candidates_e757/candidates/cloud_wall_dissolve_imagegen_candidate_x4.png",
        ],
    }

    for name, spec in SPECS.items():
        raw_path = RAW_ROOT / str(spec["raw"])
        sized = cover(Image.open(raw_path), tuple(spec["texture_size"]))
        candidate = (
            reconstruct_dissolve(sized, assets["cloud_wall_interior_dense_a"])
            if spec.get("dissolve")
            else reconstruct_wall(sized)
        )
        if spec.get("tileable_x") and not spec.get("dissolve"):
            candidate = make_tileable_axis(candidate, 1)
        if spec.get("tileable_y"):
            candidate = make_tileable_axis(candidate, 0)
        if spec.get("dissolve"):
            candidate = enforce_monotonic_alpha(candidate)
        output_path = ASSET_ROOT / f"{name}_imagegen_candidate_x4.png"
        candidate.save(output_path, optimize=True)
        assets[name] = candidate
        metrics = asset_metrics(candidate, spec)
        if spec.get("dissolve"):
            wall_rgba = np.asarray(
                assets["cloud_wall_interior_dense_a"].convert("RGBA"), dtype=np.int16
            )
            dissolve_rgba = np.asarray(candidate.convert("RGBA"), dtype=np.int16)
            join_delta = np.abs(wall_rgba[-1, :, :] - dissolve_rgba[0, :, :])
            metrics["interior_a_join_mean_abs_rgba_delta"] = round(
                float(join_delta.mean()), 6
            )
            metrics["interior_a_join_max_abs_rgba_delta"] = int(join_delta.max())
        metrics["source_raw"] = str(raw_path.relative_to(REPO_ROOT)).replace("\\", "/")
        metrics["sha256"] = sha256(output_path)
        report["assets"][name] = metrics

    reference = Image.open(REFERENCE_PATH).convert("RGBA")
    contact_sheet(reference, assets).save(REVIEW_ROOT / "01_reference_and_candidates.png", optimize=True)
    seam_proof(assets["cloud_wall_interior_dense_a"], 3, 2, False).save(
        REVIEW_ROOT / "02_interior_a_seam_3x2_world.png", optimize=True
    )
    seam_proof(assets["cloud_wall_interior_macro_b"], 3, 2, False).save(
        REVIEW_ROOT / "03_interior_b_seam_3x2_world.png", optimize=True
    )
    seam_proof(assets["cloud_wall_dissolve"], 3, 1, True).save(
        REVIEW_ROOT / "04_dissolve_seam_3x_world.png", optimize=True
    )
    reference_mockup(
        reference,
        assets["cloud_wall_interior_dense_a"],
        assets["cloud_wall_dissolve"],
        "Candidate A · dense wall + organic lower dissolve",
    ).save(REVIEW_ROOT / "05_reference_mockup_candidate_a.png", optimize=True)
    reference_mockup(
        reference,
        assets["cloud_wall_interior_macro_b"],
        assets["cloud_wall_dissolve"],
        "Candidate B · REJECT · broad light-channel and join mismatch",
    ).save(REVIEW_ROOT / "06_reference_mockup_candidate_b.png", optimize=True)

    (REVIEW_ROOT / "A_STAGE_QA.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
