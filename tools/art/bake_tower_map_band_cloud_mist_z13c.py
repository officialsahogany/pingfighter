#!/usr/bin/env python3
"""Bake the approved yeouidu cloud mist into six Tower map band edges.

The input is the exact rejected Z13 art from commit 4739e14ce. Each band uses
one fixed, contiguous 279-row RGBA strip from the approved map-cloud bitmap.
The strip is resized horizontally and blurred as one 2D patch, then split into
a 140-row bottom edge and a 140-row top edge with one textured row shared at
the butt. This preserves forward source order and exact x4 C0 continuity
without column equalization, reflection, or synthesized rows.

Only the first and last 35 world pixels are written. Rows [140:1140) in the
x4 files remain byte-identical to the pinned Z13 base.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


TEXTURE_SCALE = 4
EXPECTED_SIZE = (2768, 1280)
WORLD_SIZE = (692, 320)
EDGE_WORLD_PX = 35
EDGE_ROWS = EDGE_WORLD_PX * TEXTURE_SCALE
CORE_WORLD_PX = 18
CORE_ROWS = CORE_WORLD_PX * TEXTURE_SCALE
COVERED_WORLD_PX = 26
COVERED_ROWS = COVERED_WORLD_PX * TEXTURE_SCALE
MAP_SCROLL_RELATIVE = Path("godot/assets/sprites/tower/map_scroll")
MANIFEST_NAME = "tower_map_scroll_x4_manifest.json"

METHOD = "approved_yeouidu_contiguous_mist_strip_bake_v2"
BASE_METHOD = "forward_exemplar_residual_lap_v2"
BASE_COMMIT = "4739e14ce7f38005947555b59876676def8f723d"
SOURCE_APPROVAL_COMMIT = "50c440f946209dc5d149f136a5cf629fc8942681"
SOURCE_RELATIVE = Path(
    "images/tower_map_cloud_bitmap_candidates_cc3b/candidates/"
    "cloud_haze_band_imagegen_candidate_x4.png"
)
SOURCE_SHA256 = (
    "11c84301b4fef6f758da4c1d4d58ac7b26693dce799eb486a69fe8ed2b009cfb"
)
SOURCE_SIZE = (2768, 576)
FIXED_SEED = 0x5A313343
FIXED_SEED_ROLE = "calibration_seed_and_literal_table_version"
REVERSE_COUNTERFACTUAL_CONSTRUCTION = (
    "copy_then_bottom_edge_equals_reversed_top_edge_v1"
)
EDGE_PATCH_HEIGHT = 140
STRIP_HEIGHT = EDGE_PATCH_HEIGHT * 2 - 1
DESTINATION_WIDTH = 2768
MINIMUM_HORIZONTAL_SCALE = 2.0
MAXIMUM_HORIZONTAL_SCALE = 3.0
GAUSSIAN_BLUR_TEXTURE_PX = 2.0
MAXIMUM_MIST_TONE_LUMA = 205.0
MAXIMUM_MIST_TONE_CONTRAST_RATIO = 1.0

MINIMUM_VARIANCE_RATIO = 0.80
MAXIMUM_VARIANCE_RATIO = 1.25
MAXIMUM_MIRROR_CORRELATION = 0.12
MAXIMUM_LUMA_DELTA = 5.0
MINIMUM_CORE_OPACITY = 0.90
MAXIMUM_CORE_OPACITY = 1.0
MINIMUM_COVERAGE_THROUGH_26 = 0.90
MINIMUM_RAGGED_MASK_RESIDUAL_STD = 0.01
MINIMUM_FEATHER_FRONT_STD_TEXTURE_PX = 6.0
MINIMUM_CENTER_DETAIL_RATIO = 0.75
MAXIMUM_CENTER_DETAIL_RATIO = 1.25


@dataclass(frozen=True)
class StripSpec:
    x: int
    y: int
    width: int
    detail_gain: float


@dataclass(frozen=True)
class BandSpec:
    output: str
    strip: StripSpec
    base_output_sha256: str
    base_rgb_sha256: str
    immutable_body_rgb_sha256: str
    base_edge_bleed_sha256: str


BAND_SPECS = (
    BandSpec(
        "human_realm_01_mountain_rev2_x4.png",
        StripSpec(6, 209, 1152, 1.10),
        "c9510f9415f44cef8ae9b90e05d67bfc2be3db345b078bae71b20865706a6db6",
        "b85d9a2b4b2616259b58e2c8eac62644dd45323b2b1c534128fa3223fb0edbdd",
        "eaccd05cb5d630bd17dda27441dd0cf9f30ff47f9fa6f09f3371e404a310bb66",
        "3aadc883b559010d57d69fe80f58452cfba30b738ab7490f3ed135b351c49817",
    ),
    BandSpec(
        "human_realm_02_village_rev2_x4.png",
        StripSpec(96, 176, 1088, 1.30),
        "4f0fc3b4703f00074b878a5b07f787f2a4896bff85f397b390f493673dc9ebfd",
        "0001e85e2684fe4b4df03567d689d88f5903318dbaff69050dfb7d2f9ee9b84b",
        "225a824f22ca6ae8ad5ec1f759abce948f6c31323763e3e1026e8bad07a8b20c",
        "138fabe29cf6b86a6e06ea2835058b7ad4f5933a2e666555a24077b96769926a",
    ),
    BandSpec(
        "human_realm_03_river_rev2_x4.png",
        StripSpec(1524, 160, 1024, 1.20),
        "29b1f8123863248b4fde779ddcdede592410d79029725f938136cf5784fa5f9e",
        "d08a28b9559a016f5983fe4bc737ead704ded41a355820ff258209814730a9b9",
        "43df9f91774636208273bc8c7a9a8378b004c14959e26f408b163b823b179ed7",
        "699a0d0d8fd0c164ae7297b9d12e6ec12aafa306b1b7670dea060ab526c99fdf",
    ),
    BandSpec(
        "immortal_realm_01_islands_rev2_x4.png",
        StripSpec(0, 200, 928, 1.60),
        "1da86fe656698b27f3bf5afe795d869fe201591776ac2799ab05e80cf1901a09",
        "9b225ca73444e4e7d32f4e49a4fa8d41675a2b38bac42dad4526751121bc3d01",
        "c796c5b7d6819e22af1f5b8880e80650edcccaac66c4faff12cd92019ec54a3e",
        "fdbc01744e4dd6ac00650514d5121f97aea735b03cf9e06ad13014ebb32c70a1",
    ),
    BandSpec(
        "immortal_realm_02_cloud_cranes_rev2_x4.png",
        StripSpec(102, 235, 1024, 1.30),
        "2f5ed583ee8231a7046f194e9c5089cd84feb5dbff63a9eab443d0a031af83ab",
        "88d3bb57fde05c21ce6f744ac18d229e2626beec92a846ee1ce043e4c3511952",
        "b2e31dfa59b80f3a8e176179d190fe3856af5cd764b519784353a911410336f4",
        "ed5b4cc94363076804320e68184fc25ee5bee4909756f6fcc584a9a98fc77cc6",
    ),
    BandSpec(
        "immortal_realm_03_pavilions_rev2_x4.png",
        StripSpec(650, 193, 1024, 1.10),
        "72bfd1e06958bfb1c8b073add85fa7ee62185f9955300121c2ac6ea93444cfe5",
        "44275fbc05944fbb4e8efa8fe1668dfa59b0dd4d93ffb876faa95214a3eaf9d9",
        "c9f83853ebf3b9c6a6b5dbcf034f7f00527b891c2ea7dae562b9378c7e1c239e",
        "9bcbf407d9982b2a917032cc6fe0e3d5b314a61c3b15a036574f7f7c4efc897d",
    ),
)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def rgb_sha256(pixels: np.ndarray) -> str:
    return sha256_bytes(np.ascontiguousarray(pixels).tobytes())


def png_sha256(pixels: np.ndarray) -> str:
    encoded = io.BytesIO()
    Image.fromarray(pixels).save(
        encoded,
        format="PNG",
        compress_level=9,
        optimize=False,
    )
    return sha256_bytes(encoded.getvalue())


def canonical_json_sha256(value: object) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return sha256_bytes(encoded)


def strip_table_payload() -> dict[str, object]:
    return {
        "fixed_seed": FIXED_SEED,
        "fixed_seed_role": FIXED_SEED_ROLE,
        "strips": [
            {
                "output": spec.output,
                "x": spec.strip.x,
                "y": spec.strip.y,
                "width": spec.strip.width,
                "height": STRIP_HEIGHT,
                "detail_gain": spec.strip.detail_gain,
            }
            for spec in BAND_SPECS
        ],
    }


def validate_strip_table() -> None:
    edge_rects: set[tuple[int, int, int, int]] = set()
    for spec in BAND_SPECS:
        strip = spec.strip
        rect = (strip.x, strip.y, strip.width, STRIP_HEIGHT)
        if strip.x < 0 or strip.y < 0:
            raise RuntimeError(f"{spec.output}: negative mist strip origin")
        if strip.x + strip.width > SOURCE_SIZE[0] or strip.y + STRIP_HEIGHT > SOURCE_SIZE[1]:
            raise RuntimeError(f"{spec.output}: mist strip escaped approved source")
        horizontal_scale = DESTINATION_WIDTH / strip.width
        if not MINIMUM_HORIZONTAL_SCALE <= horizontal_scale <= MAXIMUM_HORIZONTAL_SCALE:
            raise RuntimeError(f"{spec.output}: mist strip scale escaped [2,3]")
        bottom = (strip.x, strip.y, strip.width, EDGE_PATCH_HEIGHT)
        top = (
            strip.x,
            strip.y + EDGE_PATCH_HEIGHT - 1,
            strip.width,
            EDGE_PATCH_HEIGHT,
        )
        if bottom in edge_rects or top in edge_rects or bottom == top:
            raise RuntimeError(f"{spec.output}: 12-edge crop table is not unique")
        edge_rects.add(bottom)
        edge_rects.add(top)
    if len(edge_rects) != len(BAND_SPECS) * 2:
        raise RuntimeError("fixed mist crop table must contain 12 unique edges")


def load_rgb(path: Path) -> np.ndarray:
    with Image.open(path) as image:
        if image.mode != "RGB" or image.size != EXPECTED_SIZE:
            raise RuntimeError(
                f"{path.name}: expected RGB 2768x1280, got {image.mode} {image.size}"
            )
        return np.asarray(image, dtype=np.uint8).copy()


def load_source(repo_root: Path) -> np.ndarray:
    path = repo_root / SOURCE_RELATIVE
    if file_sha256(path) != SOURCE_SHA256:
        raise RuntimeError("approved yeouidu cloud source SHA-256 drifted")
    with Image.open(path) as image:
        if image.mode != "RGBA" or image.size != SOURCE_SIZE:
            raise RuntimeError("approved yeouidu cloud source must remain RGBA 2768x576")
        return np.asarray(image, dtype=np.uint8).copy()


def body_rgb_sha256(pixels: np.ndarray) -> str:
    return sha256_bytes(np.ascontiguousarray(pixels[EDGE_ROWS:-EDGE_ROWS]).tobytes())


def luma(pixels: np.ndarray) -> np.ndarray:
    return (
        pixels[..., 0].astype(np.float64) * 0.2126
        + pixels[..., 1].astype(np.float64) * 0.7152
        + pixels[..., 2].astype(np.float64) * 0.0722
    )


def alpha_weighted_luma_std(pixels: np.ndarray) -> float:
    values = luma(pixels[..., :3])
    alpha = pixels[..., 3].astype(np.float64) / 255.0
    weights = np.maximum(alpha, 1.0 / 255.0)
    mean = float((values * weights).sum() / weights.sum())
    return float(
        np.sqrt((np.square(values - mean) * weights).sum() / weights.sum())
    )


def smootherstep(values: np.ndarray) -> np.ndarray:
    clipped = np.clip(values, 0.0, 1.0)
    return clipped * clipped * clipped * (
        clipped * (clipped * 6.0 - 15.0) + 10.0
    )


def resize_world(pixels: np.ndarray) -> np.ndarray:
    return np.asarray(
        Image.fromarray(pixels).resize(WORLD_SIZE, Image.Resampling.LANCZOS),
        dtype=np.uint8,
    )


def crop_strip(source: np.ndarray, strip: StripSpec) -> tuple[np.ndarray, dict[str, object]]:
    crop = np.ascontiguousarray(
        source[strip.y : strip.y + STRIP_HEIGHT, strip.x : strip.x + strip.width]
    )
    if crop.shape != (STRIP_HEIGHT, strip.width, 4):
        raise RuntimeError(f"mist strip escaped source: {strip}")
    horizontal_scale = DESTINATION_WIDTH / strip.width
    if not MINIMUM_HORIZONTAL_SCALE <= horizontal_scale <= MAXIMUM_HORIZONTAL_SCALE:
        raise RuntimeError(f"mist patch scale escaped [2,3]: {horizontal_scale}")
    resized = Image.fromarray(crop).resize(
        (DESTINATION_WIDTH, STRIP_HEIGHT),
        Image.Resampling.LANCZOS,
    )
    blurred = resized.filter(ImageFilter.GaussianBlur(GAUSSIAN_BLUR_TEXTURE_PX))
    patch = np.asarray(blurred, dtype=np.uint8).copy()
    bottom_crop = np.ascontiguousarray(crop[:EDGE_PATCH_HEIGHT])
    top_crop = np.ascontiguousarray(crop[EDGE_PATCH_HEIGHT - 1 :])
    return patch, {
        "selection_method": "fixed_seed_calibrated_literal_contiguous_strip_table_v2",
        "rect": [strip.x, strip.y, strip.width, STRIP_HEIGHT],
        "horizontal_scale": horizontal_scale,
        "vertical_scale": 1.0,
        "detail_gain": strip.detail_gain,
        "crop_rgba_sha256": sha256_bytes(crop.tobytes()),
        "approved_source_alpha_weighted_luma_std": alpha_weighted_luma_std(crop),
        "resized_blurred_rgba_sha256": sha256_bytes(patch.tobytes()),
        "bottom_crop": {
            "rect": [strip.x, strip.y, strip.width, EDGE_PATCH_HEIGHT],
            "rgba_sha256": sha256_bytes(bottom_crop.tobytes()),
            "resized_blurred_rgba_sha256": sha256_bytes(
                np.ascontiguousarray(patch[:EDGE_PATCH_HEIGHT]).tobytes()
            ),
        },
        "top_crop": {
            "rect": [
                strip.x,
                strip.y + EDGE_PATCH_HEIGHT - 1,
                strip.width,
                EDGE_PATCH_HEIGHT,
            ],
            "rgba_sha256": sha256_bytes(top_crop.tobytes()),
            "resized_blurred_rgba_sha256": sha256_bytes(
                np.ascontiguousarray(patch[EDGE_PATCH_HEIGHT - 1 :]).tobytes()
            ),
        },
        "shared_textured_row": EDGE_PATCH_HEIGHT - 1,
    }


def opacity_mask(patch: np.ndarray, top_edge: bool) -> np.ndarray:
    native_alpha = patch[..., 3].astype(np.float64) / 255.0
    brush = smootherstep(
        (native_alpha - 12.0 / 255.0) / ((56.0 - 12.0) / 255.0)
    )
    rows = np.arange(EDGE_PATCH_HEIGHT, dtype=np.float64)
    distance = rows if top_edge else EDGE_PATCH_HEIGHT - 1 - rows
    distance = np.broadcast_to(distance[:, None], brush.shape)
    shoulder = 1.0 - 0.04 * smootherstep(
        (distance + 8.0 * (0.5 - brush) - 72.0) / 32.0
    )
    outer = 1.0 - smootherstep(
        (distance + 24.0 * (0.5 - brush) - 116.0) / 12.0
    )
    dense = (0.94 + 0.04 * brush) * shoulder * outer
    lobe = brush * (1.0 - smootherstep((distance - 128.0) / 12.0))
    wisps = 0.18 * brush * (1.0 - smootherstep((distance - 132.0) / 8.0))
    opacity = np.maximum.reduce((dense, lobe, wisps))
    opacity = np.where(distance < COVERED_ROWS, 1.0, opacity)
    return np.clip(opacity, 0.0, 1.0)


def tone_and_composite_strip(
    base: np.ndarray,
    patch: np.ndarray,
    bottom_opacity: np.ndarray,
    top_opacity: np.ndarray,
    detail_gain: float,
    approved_source_luma_std: float,
) -> tuple[np.ndarray, dict[str, object]]:
    target_rgb = base[EDGE_ROWS:-EDGE_ROWS].mean(axis=(0, 1), dtype=np.float64)
    target_luma = float(luma(base[EDGE_ROWS:-EDGE_ROWS]).mean())
    rgb = patch[..., :3].astype(np.float64)
    native_alpha = patch[..., 3].astype(np.float64) / 255.0
    weights = np.maximum(native_alpha, 1.0 / 255.0)
    source_luma = luma(rgb)
    source_luma_mean = float((source_luma * weights).sum() / weights.sum())
    source_luma_std = float(
        np.sqrt(
            (
                np.square(source_luma - source_luma_mean) * weights
            ).sum()
            / weights.sum()
        )
    )
    normalized_alpha = native_alpha / max(float(native_alpha.max()), 1.0 / 255.0)
    pigment_support = smootherstep(normalized_alpha / 0.08)
    detail = detail_gain * pigment_support * (
        source_luma - source_luma_mean
    )
    butt_detail = np.concatenate(
        (detail[:EDGE_PATCH_HEIGHT], detail[EDGE_PATCH_HEIGHT - 1 :]),
        axis=0,
    )
    opacity = np.concatenate((bottom_opacity, top_opacity), axis=0)
    base_zone = np.concatenate((base[-EDGE_ROWS:], base[:EDGE_ROWS]), axis=0)

    def compose(
        global_offset: int,
    ) -> tuple[np.ndarray, float, float, float, float, float]:
        toned = (
            target_rgb[None, None, :]
            + butt_detail[..., None]
            + float(global_offset)
        )
        toned_luma = luma(toned)
        toned -= np.maximum(toned_luma - MAXIMUM_MIST_TONE_LUMA, 0.0)[..., None]
        toned = np.clip(toned, 0.0, 255.0)
        tone_luma = luma(toned)
        result = np.rint(
            base_zone.astype(np.float64) * (1.0 - opacity[..., None])
            + toned * opacity[..., None]
        )
        result = np.clip(result, 0, 255).astype(np.uint8)
        top_mean = float(luma(result[EDGE_ROWS:]).mean())
        bottom_mean = float(luma(result[:EDGE_ROWS]).mean())
        return (
            result,
            float(luma(result).mean()),
            float(tone_luma.max()),
            float(tone_luma.std()),
            top_mean,
            bottom_mean,
        )

    _initial, _initial_luma, _initial_max, _initial_std, _initial_top, _initial_bottom = (
        compose(0)
    )
    top_mean_opacity = max(float(top_opacity.mean()), 1.0e-6)
    bottom_mean_opacity = max(float(bottom_opacity.mean()), 1.0e-6)
    estimated = int(
        round(
            (
                (target_luma - _initial_top) / top_mean_opacity
                + (target_luma - _initial_bottom) / bottom_mean_opacity
            )
            * 0.5
        )
    )
    candidates = []
    for offset in range(estimated - 8, estimated + 9):
        result, result_luma, tone_max, tone_std, top_mean, bottom_mean = compose(offset)
        top_delta = abs(top_mean - target_luma)
        bottom_delta = abs(bottom_mean - target_luma)
        candidates.append(
            (
                max(top_delta, bottom_delta),
                abs(result_luma - target_luma),
                abs(offset),
                offset,
                result,
                tone_max,
                tone_std,
                top_mean,
                bottom_mean,
            )
        )
    (
        _edge_delta,
        _combined_delta,
        _abs_offset,
        offset,
        result,
        tone_max,
        tone_std,
        top_mean,
        bottom_mean,
    ) = min(
        candidates, key=lambda item: item[:4]
    )
    contrast_ratio = tone_std / max(approved_source_luma_std, 1.0e-9)
    if contrast_ratio > MAXIMUM_MIST_TONE_CONTRAST_RATIO:
        raise RuntimeError(
            "mist patch was not low-contrast: "
            f"{contrast_ratio} > {MAXIMUM_MIST_TONE_CONTRAST_RATIO}"
        )
    return result, {
        "detail_model": "whole_strip_rec709_luma_about_alpha_weighted_mean_v1",
        "source_alpha_weighted_mean_luma": source_luma_mean,
        "target_body_mean_rgb": [float(value) for value in target_rgb],
        "target_body_luma": target_luma,
        "detail_gain": detail_gain,
        "global_rgb_offset": offset,
        "global_offset_objective": "minimize_maximum_top_bottom_body_luma_delta",
        "composited_luma": float(luma(result).mean()),
        "top_composited_luma": top_mean,
        "bottom_composited_luma": bottom_mean,
        "maximum_edge_body_luma_delta": max(
            abs(top_mean - target_luma), abs(bottom_mean - target_luma)
        ),
        "mist_tone_maximum_luma": tone_max,
        "approved_source_alpha_weighted_luma_std": approved_source_luma_std,
        "resized_blurred_source_alpha_weighted_luma_std": source_luma_std,
        "mist_tone_luma_std": tone_std,
        "mist_to_source_contrast_ratio": contrast_ratio,
    }


def column_variance_metrics(sample: np.ndarray, texture_scale: int) -> dict[str, float | int]:
    rows = EDGE_WORLD_PX * texture_scale
    values = luma(sample)
    seam = np.concatenate((values[-rows:], values[:rows]), axis=0)
    body = values[rows:-rows]
    seam_variance = np.var(seam, axis=0)
    body_variance = np.var(body, axis=0)
    return {
        "texture_scale": texture_scale,
        "seam_mean_column_variance": float(seam_variance.mean()),
        "body_mean_column_variance": float(body_variance.mean()),
        "mean_ratio": float(seam_variance.mean() / body_variance.mean()),
        "seam_median_column_variance": float(np.median(seam_variance)),
        "body_median_column_variance": float(np.median(body_variance)),
        "median_ratio": float(np.median(seam_variance) / np.median(body_variance)),
    }


def shifted_abs_pearson_max(first: np.ndarray, second: np.ndarray, radius: int, step: int) -> float:
    maximum = 0.0
    for shift in range(-radius, radius + 1, step):
        if shift < 0:
            a, b = first[:, :shift], second[:, -shift:]
        elif shift > 0:
            a, b = first[:, shift:], second[:, :-shift]
        else:
            a, b = first, second
        av = a.ravel() - float(a.mean())
        bv = b.ravel() - float(b.mean())
        denominator = float(
            np.sqrt(float(np.square(av).sum()) * float(np.square(bv).sum()))
        )
        if denominator > 1.0e-9:
            maximum = max(maximum, abs(float(np.dot(av, bv) / denominator)))
    return maximum


def measured_mirror_correlation(sample: np.ndarray, texture_scale: int) -> float:
    rows = EDGE_WORLD_PX * texture_scale
    values = luma(sample)
    blurred = np.asarray(
        Image.fromarray(np.clip(np.rint(values), 0, 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(3 * texture_scale)
        ),
        dtype=np.float64,
    )
    high_pass = values - blurred
    top = high_pass[:rows]
    bottom_mirrored = high_pass[-rows:][::-1]
    return shifted_abs_pearson_max(
        top,
        bottom_mirrored,
        64 * texture_scale,
        texture_scale,
    )


def mirror_metrics(sample: np.ndarray, texture_scale: int) -> dict[str, float | int | str]:
    rows = EDGE_WORLD_PX * texture_scale
    maximum = measured_mirror_correlation(sample, texture_scale)
    counterfactual = sample.copy()
    counterfactual[-rows:] = sample[:rows][::-1]
    counterfactual_correlation = measured_mirror_correlation(
        counterfactual,
        texture_scale,
    )
    return {
        "texture_scale": texture_scale,
        "high_pass_radius_px": 3 * texture_scale,
        "maximum_shift_px": 64 * texture_scale,
        "maximum_absolute_correlation": maximum,
        "counterfactual_construction": REVERSE_COUNTERFACTUAL_CONSTRUCTION,
        "counterfactual_bottom_edge_rows": rows,
        "mirrored_counterfactual_correlation": counterfactual_correlation,
    }


def luma_metrics(sample: np.ndarray, texture_scale: int) -> dict[str, float | int]:
    rows = EDGE_WORLD_PX * texture_scale
    values = luma(sample)
    top_mean = float(values[:rows].mean())
    bottom_mean = float(values[-rows:].mean())
    seam_mean = float(np.concatenate((values[-rows:], values[:rows]), axis=0).mean())
    body_mean = float(values[rows:-rows].mean())
    return {
        "texture_scale": texture_scale,
        "top_mean": top_mean,
        "bottom_mean": bottom_mean,
        "seam_mean": seam_mean,
        "body_mean": body_mean,
        "top_absolute_delta": abs(top_mean - body_mean),
        "bottom_absolute_delta": abs(bottom_mean - body_mean),
        "absolute_delta": abs(seam_mean - body_mean),
        "ratio": seam_mean / body_mean,
        "endpoint_row_mean_jump": abs(float(values[0].mean() - values[-1].mean())),
    }


def center_detail_metrics(sample: np.ndarray, texture_scale: int) -> dict[str, float | int]:
    rows = EDGE_WORLD_PX * texture_scale
    values = luma(sample)
    butt = np.concatenate((values[-rows:], values[:rows]), axis=0)
    center = rows
    row_detail = np.std(butt, axis=1)
    center_detail = float((row_detail[center - 1] + row_detail[center]) * 0.5)
    near = 4 * texture_scale
    far = 16 * texture_scale
    controls = np.concatenate(
        (row_detail[center - far : center - near], row_detail[center + near : center + far])
    )
    control_detail = float(np.median(controls))
    row_means = butt.mean(axis=1)
    local_steps = np.abs(np.diff(row_means[center - far : center + far + 1]))
    return {
        "texture_scale": texture_scale,
        "center_row_detail": center_detail,
        "neighbor_row_detail_median": control_detail,
        "center_to_neighbor_detail_ratio": center_detail / max(control_detail, 1.0e-9),
        "center_row_mean_luma_jump": abs(float(row_means[center] - row_means[center - 1])),
        "maximum_local_row_mean_luma_step": float(local_steps.max()),
    }


def measure_metrics(pixels: np.ndarray) -> dict[str, object]:
    world = resize_world(pixels)
    return {
        "x4_column_vertical_variance": column_variance_metrics(pixels, TEXTURE_SCALE),
        "world_column_vertical_variance": column_variance_metrics(world, 1),
        "x4_mirror_correlation": mirror_metrics(pixels, TEXTURE_SCALE),
        "world_mirror_correlation": mirror_metrics(world, 1),
        "x4_luma": luma_metrics(pixels, TEXTURE_SCALE),
        "world_luma": luma_metrics(world, 1),
        "x4_center_detail": center_detail_metrics(pixels, TEXTURE_SCALE),
        "world_center_detail": center_detail_metrics(world, 1),
    }


def reverse_counterproof(metrics: dict[str, object]) -> dict[str, object]:
    x4 = metrics["x4_mirror_correlation"]
    world = metrics["world_mirror_correlation"]
    x4_correlation = float(x4["mirrored_counterfactual_correlation"])
    world_correlation = float(world["mirrored_counterfactual_correlation"])
    return {
        "construction": REVERSE_COUNTERFACTUAL_CONSTRUCTION,
        "assignment": "counterfactual[-rows:] = sample[:rows][::-1]",
        "production_mirror": False,
        "maximum_allowed_mirror_correlation": MAXIMUM_MIRROR_CORRELATION,
        "x4_maximum_absolute_correlation": x4_correlation,
        "world_maximum_absolute_correlation": world_correlation,
        "mirror_gate_red": (
            x4_correlation > MAXIMUM_MIRROR_CORRELATION
            and world_correlation > MAXIMUM_MIRROR_CORRELATION
        ),
    }


def validate_metrics(output: str, metrics: dict[str, object]) -> None:
    for scale in ("x4", "world"):
        variance = metrics[f"{scale}_column_vertical_variance"]
        for key in ("mean_ratio", "median_ratio"):
            value = float(variance[key])
            if not MINIMUM_VARIANCE_RATIO <= value <= MAXIMUM_VARIANCE_RATIO:
                raise RuntimeError(f"{output}: {scale} {key} failed: {value}")
        mirror = metrics[f"{scale}_mirror_correlation"]
        if float(mirror["maximum_absolute_correlation"]) > MAXIMUM_MIRROR_CORRELATION:
            raise RuntimeError(f"{output}: {scale} mirror correlation failed: {mirror}")
        if mirror.get("counterfactual_construction") != REVERSE_COUNTERFACTUAL_CONSTRUCTION:
            raise RuntimeError(f"{output}: {scale} mirror RED construction drifted")
        if float(mirror["mirrored_counterfactual_correlation"]) < 0.95:
            raise RuntimeError(f"{output}: {scale} mirror RED control failed")
        luminance = metrics[f"{scale}_luma"]
        for key in ("top_absolute_delta", "bottom_absolute_delta", "absolute_delta"):
            if float(luminance[key]) > MAXIMUM_LUMA_DELTA:
                raise RuntimeError(
                    f"{output}: {scale} {key} failed: {luminance}"
                )
        center_detail = metrics[f"{scale}_center_detail"]
        ratio = float(center_detail["center_to_neighbor_detail_ratio"])
        if not MINIMUM_CENTER_DETAIL_RATIO <= ratio <= MAXIMUM_CENTER_DETAIL_RATIO:
            raise RuntimeError(f"{output}: {scale} center detail failed: {center_detail}")


def mask_metrics(top: np.ndarray, bottom: np.ndarray) -> dict[str, object]:
    def front_metrics(mask: np.ndarray, top_edge: bool) -> dict[str, float | int]:
        outward = mask if top_edge else mask[::-1]
        row_indices = np.arange(EDGE_PATCH_HEIGHT, dtype=np.int64)[:, None]
        front = np.max(np.where(outward >= 0.5, row_indices, -1), axis=0)
        return {
            "opacity_threshold": 0.5,
            "minimum_depth_texture_px": int(front.min()),
            "maximum_depth_texture_px": int(front.max()),
            "depth_std_texture_px": float(front.std()),
        }

    top_core = top[:CORE_ROWS]
    bottom_core = bottom[-CORE_ROWS:]
    core = np.concatenate((top_core.ravel(), bottom_core.ravel()))
    top_covered = top[:COVERED_ROWS]
    bottom_covered = bottom[-COVERED_ROWS:]
    top_feather = top[CORE_ROWS:]
    bottom_feather = bottom[:-CORE_ROWS]
    feather = np.concatenate((top_feather, bottom_feather), axis=0)
    profile_residual = feather - feather.mean(axis=1, keepdims=True)
    return {
        "core_minimum": float(core.min()),
        "core_maximum": float(core.max()),
        "core_mean": float(core.mean()),
        "minimum_opacity_through_world_px_26": min(
            float(top_covered.min()), float(bottom_covered.min())
        ),
        "feather_column_profile_residual_std": float(profile_residual.std()),
        "top_feather_front": front_metrics(top, True),
        "bottom_feather_front": front_metrics(bottom, False),
        "top_mask_float32_sha256": sha256_bytes(np.ascontiguousarray(top.astype(np.float32)).tobytes()),
        "bottom_mask_float32_sha256": sha256_bytes(np.ascontiguousarray(bottom.astype(np.float32)).tobytes()),
    }


def build_band(base: np.ndarray, source: np.ndarray, spec: BandSpec) -> tuple[np.ndarray, dict[str, object]]:
    if rgb_sha256(base) != spec.base_rgb_sha256:
        raise RuntimeError(f"{spec.output}: Z13 base RGB SHA-256 drifted")
    if body_rgb_sha256(base) != spec.immutable_body_rgb_sha256:
        raise RuntimeError(f"{spec.output}: Z13 immutable body drifted")
    strip, strip_provenance = crop_strip(source, spec.strip)
    bottom_patch = strip[:EDGE_PATCH_HEIGHT]
    top_patch = strip[EDGE_PATCH_HEIGHT - 1 :]
    bottom_mask = opacity_mask(bottom_patch, False)
    top_mask = opacity_mask(top_patch, True)
    butt, tone = tone_and_composite_strip(
        base,
        strip,
        bottom_mask,
        top_mask,
        spec.strip.detail_gain,
        float(strip_provenance["approved_source_alpha_weighted_luma_std"]),
    )
    bottom = butt[:EDGE_ROWS]
    top = butt[EDGE_ROWS:]
    if not np.array_equal(bottom[-1], top[0]):
        raise RuntimeError(f"{spec.output}: shared textured seam row lost x4 C0")
    result = base.copy()
    result[:EDGE_ROWS] = top
    result[-EDGE_ROWS:] = bottom
    if body_rgb_sha256(result) != spec.immutable_body_rgb_sha256:
        raise RuntimeError(f"{spec.output}: bake touched RGB outside 35 world px")
    masks = mask_metrics(top_mask, bottom_mask)
    if float(masks["core_minimum"]) < MINIMUM_CORE_OPACITY:
        raise RuntimeError(f"{spec.output}: core opacity fell below 0.9")
    if float(masks["core_maximum"]) > MAXIMUM_CORE_OPACITY:
        raise RuntimeError(f"{spec.output}: core opacity exceeded 1.0")
    if float(masks["minimum_opacity_through_world_px_26"]) < MINIMUM_COVERAGE_THROUGH_26:
        raise RuntimeError(f"{spec.output}: rejected fill remains exposed before 26px")
    if float(masks["feather_column_profile_residual_std"]) < MINIMUM_RAGGED_MASK_RESIDUAL_STD:
        raise RuntimeError(f"{spec.output}: cloud-brush feather became a straight gradient")
    for edge_name in ("top", "bottom"):
        front = masks[f"{edge_name}_feather_front"]
        if float(front["depth_std_texture_px"]) < MINIMUM_FEATHER_FRONT_STD_TEXTURE_PX:
            raise RuntimeError(f"{spec.output}: {edge_name} mist front lost brush irregularity")
    metrics = measure_metrics(result)
    if float(tone["mist_tone_maximum_luma"]) > MAXIMUM_MIST_TONE_LUMA + 1.0e-6:
        raise RuntimeError(f"{spec.output}: mist tone exceeded paper-safe luma cap")
    validate_metrics(spec.output, metrics)
    rejected_metrics = measure_metrics(base)
    for scale in ("x4", "world"):
        rejected_variance = rejected_metrics[f"{scale}_column_vertical_variance"]
        rejected_is_red = any(
            float(rejected_variance[key]) < MINIMUM_VARIANCE_RATIO
            or float(rejected_variance[key]) > MAXIMUM_VARIANCE_RATIO
            for key in ("mean_ratio", "median_ratio")
        )
        if not rejected_is_red:
            raise RuntimeError(
                f"{spec.output}: pinned rejected Z13 no longer proves {scale} RED"
            )
    contract = {
        "method": METHOD,
        "base_method": BASE_METHOD,
        "base_commit": BASE_COMMIT,
        "texture_scale": TEXTURE_SCALE,
        "source": SOURCE_RELATIVE.as_posix(),
        "source_sha256": SOURCE_SHA256,
        "source_approval_commit": SOURCE_APPROVAL_COMMIT,
        "fixed_seed": FIXED_SEED,
        "fixed_seed_role": FIXED_SEED_ROLE,
        "fixed_seed_strip_table_sha256": canonical_json_sha256(strip_table_payload()),
        "crop_selection_method": strip_provenance["selection_method"],
        "strip": strip_provenance,
        "top_crop": strip_provenance["top_crop"],
        "bottom_crop": strip_provenance["bottom_crop"],
        "vertical_scale": 1.0,
        "mirror": False,
        "reverse": False,
        "row_equalization": False,
        "column_equalization": False,
        "endpoint_equalization": False,
        "one_pixel_column_operations": False,
        "gaussian_blur_texture_px": GAUSSIAN_BLUR_TEXTURE_PX,
        "core_world_px": CORE_WORLD_PX,
        "feather_world_px": EDGE_WORLD_PX - CORE_WORLD_PX,
        "guaranteed_coverage_subzone_world_px": [CORE_WORLD_PX, COVERED_WORLD_PX],
        "active_ragged_fade_world_px": [COVERED_WORLD_PX, EDGE_WORLD_PX],
        "edge_zone_world_px": EDGE_WORLD_PX,
        "covered_prior_fill_through_world_px": COVERED_WORLD_PX,
        "feather_mask": "approved_2d_brush_alpha_dense_lobe_and_wisps_v2",
        "tone": tone,
        "mask_metrics": masks,
        "shared_textured_seam": {
            "method": "overlap_one_natural_row_from_contiguous_279_row_strip",
            "strip_row": EDGE_PATCH_HEIGHT - 1,
            "bottom_output_row": EXPECTED_SIZE[1] - 1,
            "top_output_row": 0,
            "x4_rows_equal": True,
            "rgb_sha256": sha256_bytes(np.ascontiguousarray(bottom[-1]).tobytes()),
            "per_column_adjustment": False,
        },
        "metrics": metrics,
        "reverse_counterproof": reverse_counterproof(metrics),
        "rejected_z13_counterproof": {
            "base_output_sha256": spec.base_output_sha256,
            "base_rgb_sha256": spec.base_rgb_sha256,
            "metrics": rejected_metrics,
            "vertical_variance_gate_red": True,
        },
        "base_output_sha256": spec.base_output_sha256,
        "base_rgb_sha256": spec.base_rgb_sha256,
        "base_edge_bleed_method": BASE_METHOD,
        "base_edge_bleed_sha256": spec.base_edge_bleed_sha256,
        "immutable_body_rect": [0, EDGE_ROWS, EXPECTED_SIZE[0], EXPECTED_SIZE[1] - EDGE_ROWS * 2],
        "immutable_body_rgb_sha256": spec.immutable_body_rgb_sha256,
        "outside_35_world_px_changed_pixels": 0,
        "validation_thresholds": {
            "minimum_column_vertical_variance_ratio": MINIMUM_VARIANCE_RATIO,
            "maximum_column_vertical_variance_ratio": MAXIMUM_VARIANCE_RATIO,
            "maximum_mirror_correlation": MAXIMUM_MIRROR_CORRELATION,
            "maximum_seam_body_luma_delta": MAXIMUM_LUMA_DELTA,
            "maximum_mist_tone_luma": MAXIMUM_MIST_TONE_LUMA,
            "maximum_mist_to_source_contrast_ratio": MAXIMUM_MIST_TONE_CONTRAST_RATIO,
            "minimum_core_opacity": MINIMUM_CORE_OPACITY,
            "minimum_opacity_through_world_px_26": MINIMUM_COVERAGE_THROUGH_26,
            "minimum_ragged_mask_residual_std": MINIMUM_RAGGED_MASK_RESIDUAL_STD,
            "minimum_feather_front_std_texture_px": MINIMUM_FEATHER_FRONT_STD_TEXTURE_PX,
            "minimum_center_detail_ratio": MINIMUM_CENTER_DETAIL_RATIO,
            "maximum_center_detail_ratio": MAXIMUM_CENTER_DETAIL_RATIO,
            "endpoint_row_mean_jump": "diagnostic_only_natural_shared_row",
        },
        "wrapped_rgb_sha256": rgb_sha256(result),
        "output_sha256": png_sha256(result),
    }
    return result, contract


def write_png(path: Path, pixels: np.ndarray) -> None:
    temporary = path.with_suffix(path.suffix + ".z13c.tmp")
    Image.fromarray(pixels).save(temporary, format="PNG", compress_level=9, optimize=False)
    temporary.replace(path)


def write_butt(evidence_dir: Path, output: str, pixels: np.ndarray) -> Path:
    evidence_dir.mkdir(parents=True, exist_ok=True)
    path = evidence_dir / output.replace(".png", "_butt_bottom200_top200.png")
    write_png(path, np.concatenate((pixels[-200:], pixels[:200]), axis=0))
    return path


def update_manifest(asset_root: Path, contracts: dict[str, dict[str, object]]) -> None:
    path = asset_root / MANIFEST_NAME
    manifest = json.loads(path.read_text(encoding="utf-8"))
    records = {str(record["output"]): record for record in manifest["assets"]}
    for spec in BAND_SPECS:
        contract = contracts[spec.output]
        if canonical_json_sha256(records[spec.output].get("edge_bleed", {})) != spec.base_edge_bleed_sha256:
            raise RuntimeError(f"{spec.output}: refusing to mutate drifted Z13 edge_bleed provenance")
        records[spec.output]["output_sha256"] = contract["output_sha256"]
        records[spec.output]["edge_mist_bake"] = contract
    temporary = path.with_suffix(path.suffix + ".z13c.tmp")
    temporary.write_bytes(
        (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    )
    temporary.replace(path)


def metric_line(output: str, contract: dict[str, object]) -> str:
    metrics = contract["metrics"]
    x4v = metrics["x4_column_vertical_variance"]
    worldv = metrics["world_column_vertical_variance"]
    x4m = metrics["x4_mirror_correlation"]
    worldm = metrics["world_mirror_correlation"]
    x4l = metrics["x4_luma"]
    worldl = metrics["world_luma"]
    x4c = metrics["x4_center_detail"]
    worldc = metrics["world_center_detail"]
    tone = contract["tone"]
    masks = contract["mask_metrics"]
    top_front = masks["top_feather_front"]
    bottom_front = masks["bottom_feather_front"]
    return (
        f"{output} variance=x4:{x4v['mean_ratio']:.6f}/{x4v['median_ratio']:.6f},"
        f"world:{worldv['mean_ratio']:.6f}/{worldv['median_ratio']:.6f} "
        f"mirror=x4:{x4m['maximum_absolute_correlation']:.6f},"
        f"world:{worldm['maximum_absolute_correlation']:.6f} "
        f"luma=x4:{x4l['top_absolute_delta']:.6f}/"
        f"{x4l['bottom_absolute_delta']:.6f}/{x4l['absolute_delta']:.6f},"
        f"world:{worldl['top_absolute_delta']:.6f}/"
        f"{worldl['bottom_absolute_delta']:.6f}/{worldl['absolute_delta']:.6f} "
        f"center_detail=x4:{x4c['center_to_neighbor_detail_ratio']:.6f},"
        f"world:{worldc['center_to_neighbor_detail_ratio']:.6f} "
        f"tone_contrast={tone['mist_to_source_contrast_ratio']:.6f} "
        f"opacity=core:{masks['core_minimum']:.6f},"
        f"through26:{masks['minimum_opacity_through_world_px_26']:.6f},"
        f"ragged:{masks['feather_column_profile_residual_std']:.6f} "
        f"front_std=top:{top_front['depth_std_texture_px']:.6f},"
        f"bottom:{bottom_front['depth_std_texture_px']:.6f} "
        f"body_sha256={contract['immutable_body_rgb_sha256']} "
        f"output_sha256={contract['output_sha256']}"
    )


def validate_final_record(path: Path, pixels: np.ndarray, record: dict[str, object], spec: BandSpec) -> dict[str, object]:
    contract = record.get("edge_mist_bake", {})
    if not isinstance(contract, dict) or contract.get("method") != METHOD:
        raise RuntimeError(f"{spec.output}: final Z13-c manifest contract missing")
    strip = contract.get("strip", {})
    expected_rect = [spec.strip.x, spec.strip.y, spec.strip.width, STRIP_HEIGHT]
    if (
        contract.get("base_commit") != BASE_COMMIT
        or contract.get("base_output_sha256") != spec.base_output_sha256
        or contract.get("base_rgb_sha256") != spec.base_rgb_sha256
        or contract.get("source_sha256") != SOURCE_SHA256
        or contract.get("source_approval_commit") != SOURCE_APPROVAL_COMMIT
        or contract.get("fixed_seed") != FIXED_SEED
        or contract.get("fixed_seed_role") != FIXED_SEED_ROLE
        or contract.get("fixed_seed_strip_table_sha256")
        != canonical_json_sha256(strip_table_payload())
        or not isinstance(strip, dict)
        or strip.get("rect") != expected_rect
        or float(strip.get("detail_gain", -1.0)) != spec.strip.detail_gain
    ):
        raise RuntimeError(f"{spec.output}: final Z13-c source/table provenance drifted")
    if canonical_json_sha256(record.get("edge_bleed", {})) != spec.base_edge_bleed_sha256:
        raise RuntimeError(f"{spec.output}: final Z13 edge_bleed provenance drifted")
    if file_sha256(path) != record.get("output_sha256"):
        raise RuntimeError(f"{spec.output}: final PNG SHA-256 drifted")
    if rgb_sha256(pixels) != contract.get("wrapped_rgb_sha256"):
        raise RuntimeError(f"{spec.output}: final RGB SHA-256 drifted")
    if body_rgb_sha256(pixels) != spec.immutable_body_rgb_sha256:
        raise RuntimeError(f"{spec.output}: final immutable body drifted")
    tone = contract.get("tone", {})
    masks = contract.get("mask_metrics", {})
    if not isinstance(tone, dict) or not isinstance(masks, dict):
        raise RuntimeError(f"{spec.output}: final tone/mask provenance missing")
    if (
        float(tone.get("mist_tone_maximum_luma", float("inf")))
        > MAXIMUM_MIST_TONE_LUMA + 1.0e-6
        or float(tone.get("mist_to_source_contrast_ratio", float("inf")))
        > MAXIMUM_MIST_TONE_CONTRAST_RATIO
        or float(masks.get("core_minimum", -1.0)) < MINIMUM_CORE_OPACITY
        or float(masks.get("core_maximum", float("inf"))) > MAXIMUM_CORE_OPACITY
        or float(masks.get("minimum_opacity_through_world_px_26", -1.0))
        < MINIMUM_COVERAGE_THROUGH_26
        or float(masks.get("feather_column_profile_residual_std", -1.0))
        < MINIMUM_RAGGED_MASK_RESIDUAL_STD
    ):
        raise RuntimeError(f"{spec.output}: final tone/mask thresholds drifted")
    for edge_name in ("top", "bottom"):
        front = masks.get(f"{edge_name}_feather_front", {})
        if (
            not isinstance(front, dict)
            or float(front.get("depth_std_texture_px", -1.0))
            < MINIMUM_FEATHER_FRONT_STD_TEXTURE_PX
        ):
            raise RuntimeError(f"{spec.output}: final {edge_name} mist front drifted")
    metrics = measure_metrics(pixels)
    validate_metrics(spec.output, metrics)
    if metrics != contract.get("metrics"):
        raise RuntimeError(f"{spec.output}: manifest metrics drifted")
    if reverse_counterproof(metrics) != contract.get("reverse_counterproof"):
        raise RuntimeError(f"{spec.output}: manifest reverse counterproof drifted")
    return contract


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--base-asset-root", type=Path)
    parser.add_argument("--preview-from-base", action="store_true")
    parser.add_argument("--evidence-dir", type=Path)
    args = parser.parse_args()
    if args.preview_from_base and (args.apply or args.base_asset_root is None):
        raise RuntimeError("--preview-from-base requires --base-asset-root without --apply")

    repo_root = args.repo_root.resolve()
    validate_strip_table()
    asset_root = repo_root / MAP_SCROLL_RELATIVE
    source = load_source(repo_root)
    manifest_path = asset_root / MANIFEST_NAME
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    records = {str(record["output"]): record for record in manifest["assets"]}
    for spec in BAND_SPECS:
        if canonical_json_sha256(records[spec.output].get("edge_bleed", {})) != spec.base_edge_bleed_sha256:
            raise RuntimeError(f"{spec.output}: pinned Z13 edge_bleed provenance drifted")
    current = {spec.output: load_rgb(asset_root / spec.output) for spec in BAND_SPECS}
    current_contract_flags = [
        isinstance(records[spec.output].get("edge_mist_bake"), dict)
        and records[spec.output]["edge_mist_bake"].get("method") == METHOD
        for spec in BAND_SPECS
    ]
    if any(current_contract_flags) and not all(current_contract_flags):
        raise RuntimeError("refusing mixed Z13-c manifest contract state")
    base_root = args.base_asset_root.resolve() if args.base_asset_root else None
    base_flags = [file_sha256(asset_root / spec.output) == spec.base_output_sha256 for spec in BAND_SPECS]
    if any(base_flags) and not all(base_flags):
        raise RuntimeError("refusing mixed Z13 base/Z13-c final inputs")
    final_already_present = all(current_contract_flags) and not all(base_flags)
    if args.apply and not all(base_flags) and base_root is None and not final_already_present:
        raise RuntimeError(
            "--apply requires the exact six-file 4739 Z13 base or an already-valid final"
        )

    build_from_base = all(base_flags) or base_root is not None
    expected: dict[str, np.ndarray] = {}
    contracts: dict[str, dict[str, object]] = {}
    if build_from_base:
        for spec in BAND_SPECS:
            base_path = (base_root / spec.output) if base_root else (asset_root / spec.output)
            if file_sha256(base_path) != spec.base_output_sha256:
                raise RuntimeError(f"{spec.output}: preserved Z13 base PNG drifted")
            pixels, contract = build_band(load_rgb(base_path), source, spec)
            expected[spec.output] = pixels
            contracts[spec.output] = contract
            if (
                base_root is not None
                and all(current_contract_flags)
                and not args.apply
                and not args.preview_from_base
                and not np.array_equal(current[spec.output], pixels)
            ):
                raise RuntimeError(f"{spec.output}: current output is not reproducible from 4739")
        if args.apply:
            for spec in BAND_SPECS:
                path = asset_root / spec.output
                write_png(path, expected[spec.output])
                if file_sha256(path) != contracts[spec.output]["output_sha256"]:
                    raise RuntimeError(f"{spec.output}: deterministic PNG write drifted")
            update_manifest(asset_root, contracts)
    else:
        for spec in BAND_SPECS:
            path = asset_root / spec.output
            contract = validate_final_record(path, current[spec.output], records[spec.output], spec)
            expected[spec.output] = current[spec.output]
            contracts[spec.output] = contract

    if args.evidence_dir:
        for spec in BAND_SPECS:
            print(f"butt_evidence={write_butt(args.evidence_dir.resolve(), spec.output, expected[spec.output])}")
    for spec in BAND_SPECS:
        print(metric_line(spec.output, contracts[spec.output]))
    ready_to_apply = (
        build_from_base
        and not args.apply
        and (args.preview_from_base or not all(current_contract_flags))
    )
    if args.apply and not build_from_base:
        print("tower_map_band_cloud_mist_z13c: apply_noop_final_already_valid")
    elif ready_to_apply:
        print("tower_map_band_cloud_mist_z13c: ready_to_apply")
    else:
        print("tower_map_band_cloud_mist_z13c: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
