#!/usr/bin/env python3
"""Build deterministic, forward-textured vertical laps for Tower map bands.

The approved interior starts where the downsampled world row first has both
mean luminance below 200 and horizontal detail sigma above 18. Only the rows
outside that boundary are replaced. Each replacement is a contiguous forward
exemplar copied from the approved body. Its two seam-adjacent spans receive a
bounded paired lap while retaining independent ink residuals; the remaining
edge rows carry smooth additive endpoint corrections back to the untouched
body. No source row is reflected, reversed, or vertically stretched.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image


TEXTURE_SCALE = 4
EXPECTED_SIZE = (2768, 1280)
BODY_LUMA_THRESHOLD = 200.0
BODY_DETAIL_THRESHOLD = 18.0
MAP_SCROLL_RELATIVE = Path("godot/assets/sprites/tower/map_scroll")
MANIFEST_NAME = "tower_map_scroll_x4_manifest.json"
COMMON_PAPER_NAME = "common_hanji_paper_x4.png"
WRAP_METHOD = "forward_exemplar_residual_lap_v2"
WRAP_BASE_METHOD = "approved_interior_forward_exemplar"
WRAP_WEIGHT_CURVE = "paired_12_1_lap_with_smoothstep_endpoint_residual"
WRAP_ROUNDING = "signed_round_half_up"
WRAP_LAP_DIVISOR = 2
WRAP_PAIR_WEIGHT_DENOMINATOR = 13
WRAP_PAIR_OPPOSITE_WEIGHT = 1
WRAP_PAIR_RAMP_TEXTURE_ROWS = TEXTURE_SCALE
WRAP_MIN_WORLD_ROW_DETAIL = 18.0
WRAP_SELECTION_MIN_WORLD_ROW_DETAIL = 18.1
WRAP_MIN_PAIRED_MEAN_IMPROVEMENT_FRACTION = 0.35
WRAP_X4_MAX_PAIRED_MEAN_ABS_RGB_DELTA = 29.0
WRAP_X4_MAX_PAIRED_P95_ABS_RGB_DELTA = 105.0
WRAP_X4_MAX_PAIRED_CHANNEL_DELTA = 220
WRAP_WORLD_MAX_PAIRED_MEAN_ABS_RGB_DELTA = 25.0
WRAP_SELECTION_WORLD_MAX_PAIRED_MEAN_ABS_RGB_DELTA = 26.0
WRAP_SELECTION_WORLD_MAX_PAIRED_P95_ABS_RGB_DELTA = 90.0
WRAP_SELECTION_WORLD_MAX_PAIRED_CHANNEL_DELTA = 240
WRAP_WORLD_MAX_PAIRED_P95_ABS_RGB_DELTA = 87.0
WRAP_WORLD_MAX_PAIRED_CHANNEL_DELTA = 200
WRAP_X4_MAX_SEAM_MEAN_ABS_RGB_DELTA = 13.0
WRAP_X4_MAX_SEAM_P95_ABS_RGB_DELTA = 52.0
WRAP_X4_MAX_SEAM_CHANNEL_DELTA = 160
WRAP_WORLD_MAX_SEAM_MEAN_ABS_RGB_DELTA = 14.0
WRAP_WORLD_MAX_SEAM_P95_ABS_RGB_DELTA = 52.0
WRAP_WORLD_MAX_SEAM_CHANNEL_DELTA = 150
WRAP_SELECTION_WORLD_MAX_SEAM_MEAN_ABS_RGB_DELTA = 18.0
WRAP_SELECTION_WORLD_MAX_SEAM_P95_ABS_RGB_DELTA = 72.0
WRAP_SELECTION_WORLD_MAX_SEAM_CHANNEL_DELTA = 192
WRAP_X4_MAX_DERIVATIVE_MEAN_ABS_RGB_DELTA = 20.0
WRAP_X4_MAX_DERIVATIVE_P95_ABS_RGB_DELTA = 72.0
WRAP_X4_MAX_DERIVATIVE_CHANNEL_DELTA = 220
WRAP_WORLD_MAX_DERIVATIVE_MEAN_ABS_RGB_DELTA = 22.0
WRAP_WORLD_MAX_DERIVATIVE_P95_ABS_RGB_DELTA = 80.0
WRAP_WORLD_MAX_DERIVATIVE_CHANNEL_DELTA = 250
WRAP_X4_MAX_BODY_BOUNDARY_MEAN_ABS_RGB_DELTA = 0.0
WRAP_X4_MAX_BODY_BOUNDARY_P95_ABS_RGB_DELTA = 0.0
WRAP_X4_MAX_BODY_BOUNDARY_CHANNEL_DELTA = 0
WRAP_WORLD_MAX_BODY_BOUNDARY_MEAN_ABS_RGB_DELTA = 12.0
WRAP_WORLD_MAX_BODY_BOUNDARY_P95_ABS_RGB_DELTA = 42.0
WRAP_WORLD_MAX_BODY_BOUNDARY_CHANNEL_DELTA = 130
WRAP_X4_MAX_BODY_DERIVATIVE_MEAN_ABS_RGB_DELTA = 6.0
WRAP_X4_MAX_BODY_DERIVATIVE_P95_ABS_RGB_DELTA = 30.0
WRAP_X4_MAX_BODY_DERIVATIVE_CHANNEL_DELTA = 135
WRAP_WORLD_MAX_BODY_DERIVATIVE_MEAN_ABS_RGB_DELTA = 18.0
WRAP_WORLD_MAX_BODY_DERIVATIVE_P95_ABS_RGB_DELTA = 66.0
WRAP_WORLD_MAX_BODY_DERIVATIVE_CHANNEL_DELTA = 215
WRAP_X4_MAX_SEAM_ROW_MEAN_LUMA_JUMP = 0.01
WRAP_WORLD_MAX_SEAM_ROW_MEAN_LUMA_JUMP = 0.01
WRAP_MAX_DIRECT_CORRELATION_EXCESS = 0.16
WRAP_MAX_MIRROR_CORRELATION_EXCESS = 0.12
WRAP_SELECTION_DIRECT_CORRELATION_MARGIN = 0.005
WRAP_SELECTION_MIRROR_CORRELATION_MARGIN = 0.02
WRAP_VALUE_CLOSURE_TEXTURE_ROWS = TEXTURE_SCALE * 2
WRAP_VALUE_CLOSURE_MAX_ITERATIONS = 10
WRAP_VALUE_CLOSURE_DITHER_DENOMINATOR = 4096
WRAP_EXEMPLAR_SELECTION_METHOD = (
    "world64_min_gutter_detail_similarity_and_paired_delta_v1"
)
BRIGHT_GUTTER_GUARD_METHOD = "lanczos_phase16_and_cyclic_profile_local_luma_clamp_v3"
BRIGHT_GUTTER_SEARCH_RADIUS_WORLD_PX = 16
BRIGHT_GUTTER_DETAIL_SAMPLE_WIDTH = 64
BRIGHT_GUTTER_LUMA_THRESHOLD = 200.0
BRIGHT_GUTTER_DETAIL_THRESHOLD = 18.0
BRIGHT_GUTTER_MIN_RUN_WORLD_PX = 2
BRIGHT_GUTTER_TARGET_LUMA = 198.0


@dataclass(frozen=True)
class BandSpec:
    output: str
    top_world_px: int
    bottom_world_px: int
    original_output_sha256: str
    z11_output_sha256: str
    z11_rgb_sha256: str
    interior_rgb_sha256: str


BAND_SPECS = (
    BandSpec(
        "human_realm_01_mountain_rev2_x4.png",
        21,
        15,
        "8d88d76c81c76a452f764535e059f9d563f3a46f856678bba256d4935477cdac",
        "88f9413000e98aec3cf2c431a9f9452f8145d010f0423ffbb9bc75236df269d8",
        "be67fdc6b888bd2024e345535b7c10ec45306bd9c9d73716b1bfaa3543303ee4",
        "20695482b205d14ff674903db86c02c60ce66a87d9daa3d031eec5d13632bb29",
    ),
    BandSpec(
        "human_realm_02_village_rev2_x4.png",
        24,
        22,
        "bd3688eb35b7ef3ee16b2baf71d29e7619e5ac171a2856f55df9fabc1339924d",
        "d7b2f40cb89cf8a51e3294e1621759ea107399b99e6e8e467152507c8c3283fd",
        "c97538734fc623be0e042a8fd8515e7eba1dfc9c350800a1f0c714bcf9c9627b",
        "aadcd25cf3a5ae0de5ef354f39352145d803efac503665a67986e7e53d1acfba",
    ),
    BandSpec(
        "human_realm_03_river_rev2_x4.png",
        21,
        15,
        "7aaafbf79d395d6f373bef900ebbe1ab55941bbc2f9950117d58701fa33eb881",
        "5c0e47be941c09fec192d7822c478f7f7536b98741629a65bab79cdcaaaad378",
        "a207f48c481253436548e49bb33ae13f839ad4a7acb3131da0d215a04dd6b340",
        "c05f1f7e01f3c250e0426dc44a1a5c263b8ff42861c2b3eaac2428a47197f178",
    ),
    BandSpec(
        "immortal_realm_01_islands_rev2_x4.png",
        26,
        23,
        "a203575517828b8f3ad46e784a5bef43451cb9536b5079283cbbf6bcc65ea672",
        "6e3650de556f57161211147caf9ce91da6f4a4c21e25b822ca9b0ce013930f84",
        "0716fa3f8538c3d3e67288e2d0ba2cc1b5163a11f1664a5ceed6d6d3ca342346",
        "afd3d6c79bf204485951f4d0a82f7aca539828cf0540bb6791e1bc40e66f1e53",
    ),
    BandSpec(
        "immortal_realm_02_cloud_cranes_rev2_x4.png",
        18,
        15,
        "81d6c70f6d2fdd4b47559a4ffce4acd3e6ea0a158e11cb8b613ee5649f178878",
        "2357db8f36db1b3cb1185bfe91f547459e47ae3821575e4c626dd411b4c1506d",
        "34eef24d176e52d662b8d82dea24eef8cafe34a1ad211781442e6d09df717c5b",
        "1ecb7b2c440a4cff74772f7479f2beea7066878d548563acd57c54c84b365279",
    ),
    BandSpec(
        "immortal_realm_03_pavilions_rev2_x4.png",
        25,
        26,
        "e37ac5043817d3dde22a779c0a99d47bf295503eec26f779cbb53f0a50126a3f",
        "41f70e8535fdbdf44bf077b8065d493084335f3aafcb8eb36b7cf063d29c8ecf",
        "79035d54ad59daed5c945931fcbc1e4dc6ea92fc712641f6b5702a2e3c1ce359",
        "b31c67b46fc81b2d5ae3be99af9cb3d240110217787c3d8593fa416a0ea9119e",
    ),
)


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _file_sha256(path: Path) -> str:
    return _sha256_bytes(path.read_bytes())


def _load_rgb(path: Path) -> np.ndarray:
    with Image.open(path) as image:
        if image.mode != "RGB" or image.size != EXPECTED_SIZE:
            raise RuntimeError(
                f"{path.name}: expected RGB {EXPECTED_SIZE[0]}x{EXPECTED_SIZE[1]}, "
                f"got {image.mode} {image.size[0]}x{image.size[1]}"
            )
        return np.asarray(image, dtype=np.uint8).copy()


def _edge_rows(spec: BandSpec) -> tuple[int, int]:
    return spec.top_world_px * TEXTURE_SCALE, spec.bottom_world_px * TEXTURE_SCALE


def _interior_sha256(pixels: np.ndarray, spec: BandSpec) -> str:
    top_rows, bottom_rows = _edge_rows(spec)
    return _sha256_bytes(pixels[top_rows : pixels.shape[0] - bottom_rows].tobytes())


def _rgb_sha256(pixels: np.ndarray) -> str:
    return _sha256_bytes(np.ascontiguousarray(pixels).tobytes())


def _png_sha256(pixels: np.ndarray) -> str:
    encoded = io.BytesIO()
    Image.fromarray(pixels).save(
        encoded,
        format="PNG",
        compress_level=9,
        optimize=False,
    )
    return _sha256_bytes(encoded.getvalue())


def _mirrored_edge_bleed(pixels: np.ndarray, spec: BandSpec) -> np.ndarray:
    top_rows, bottom_rows = _edge_rows(spec)
    result = pixels.copy()
    result[:top_rows] = result[top_rows : top_rows * 2][::-1]
    height = result.shape[0]
    result[height - bottom_rows :] = result[
        height - bottom_rows * 2 : height - bottom_rows
    ][::-1]
    return result


def _round_signed_ratio(numerators: np.ndarray, denominator: int) -> np.ndarray:
    if denominator <= 0:
        raise RuntimeError("signed ratio denominator must be positive")
    result = np.empty_like(numerators, dtype=np.int64)
    positive = numerators >= 0
    result[positive] = (numerators[positive] + denominator // 2) // denominator
    negative = ~positive
    result[negative] = -(
        (-numerators[negative] + denominator // 2) // denominator
    )
    return result


def _lap_world_px(spec: BandSpec) -> int:
    lap_world_px = min(spec.top_world_px, spec.bottom_world_px) // WRAP_LAP_DIVISOR
    if lap_world_px < 2:
        raise RuntimeError(f"{spec.output}: vertical lap is too narrow")
    return lap_world_px


def _smoothstep_numerator(distance: np.ndarray, denominator: int) -> np.ndarray:
    if denominator <= 0:
        raise RuntimeError("smoothstep denominator must be positive")
    return distance * distance * (3 * denominator - 2 * distance)


def _paired_lap_weight_profile(row_count: int, ramp_rows: int) -> np.ndarray:
    if row_count < 2 or ramp_rows <= 0:
        raise RuntimeError("paired lap requires at least two rows and a positive ramp")
    distance = np.minimum(
        np.arange(row_count, dtype=np.int64),
        np.arange(row_count - 1, -1, -1, dtype=np.int64),
    )
    clamped = np.minimum(distance, ramp_rows)
    smooth = _smoothstep_numerator(clamped, ramp_rows)
    return _round_signed_ratio(
        smooth * WRAP_PAIR_OPPOSITE_WEIGHT,
        ramp_rows**3,
    )


def _apply_endpoint_residual(
    bridge: np.ndarray,
    start: int,
    row_count: int,
    target: np.ndarray,
    rising: bool,
) -> None:
    if row_count < 2:
        raise RuntimeError("endpoint residual needs at least two transition rows")
    distance = np.arange(row_count, dtype=np.int64)
    denominator = row_count - 1
    weight = _smoothstep_numerator(distance, denominator)
    if not rising:
        weight = denominator**3 - weight
    anchor = bridge[start + row_count - 1] if rising else bridge[start]
    error = target.astype(np.int64) - anchor.astype(np.int64)
    bridge[start : start + row_count] += _round_signed_ratio(
        weight[:, None, None] * error[None, :, :],
        denominator**3,
    )


def _apply_forward_exemplar_lap(
    exemplar: np.ndarray,
    bottom_rows: int,
    lap_rows: int,
    bottom_body_anchor: np.ndarray,
    top_body_anchor: np.ndarray,
    ramp_rows: int,
) -> np.ndarray:
    row_count = exemplar.shape[0]
    top_rows = row_count - bottom_rows
    bottom_transition_rows = bottom_rows - lap_rows
    top_transition_rows = top_rows - lap_rows
    if min(bottom_transition_rows, top_transition_rows) < 2:
        raise RuntimeError("approved edge bands leave no exemplar transition budget")

    bridge = exemplar.astype(np.int64).copy()
    bottom_lap = bridge[bottom_rows - lap_rows : bottom_rows].copy()
    top_lap = bridge[bottom_rows : bottom_rows + lap_rows].copy()
    opposite_weight = _paired_lap_weight_profile(lap_rows, ramp_rows)[
        :, None, None
    ]
    own_weight = WRAP_PAIR_WEIGHT_DENOMINATOR - opposite_weight
    bridge[bottom_rows - lap_rows : bottom_rows] = _round_signed_ratio(
        own_weight * bottom_lap + opposite_weight * top_lap,
        WRAP_PAIR_WEIGHT_DENOMINATOR,
    )
    bridge[bottom_rows : bottom_rows + lap_rows] = _round_signed_ratio(
        opposite_weight * bottom_lap + own_weight * top_lap,
        WRAP_PAIR_WEIGHT_DENOMINATOR,
    )

    _apply_endpoint_residual(
        bridge,
        0,
        bottom_transition_rows,
        bottom_body_anchor,
        False,
    )
    _apply_endpoint_residual(
        bridge,
        bottom_rows + lap_rows,
        top_transition_rows,
        top_body_anchor,
        True,
    )
    return np.clip(bridge, 0, 255).astype(np.uint8)


def _seam_row_mean_luma_jump(
    pixels: np.ndarray,
    texture_scale: int,
    signed: bool = False,
) -> float:
    sample = _resized_for_scale(pixels, texture_scale)
    luminance = _image_luminance(sample)
    delta = float(luminance[0].mean() - luminance[-1].mean())
    return delta if signed else abs(delta)


def _apply_fractional_rgb_row_offsets(
    pixels: np.ndarray,
    rows: list[int],
    offsets: np.ndarray,
    salt: int,
) -> np.ndarray:
    if len(rows) != int(offsets.size):
        raise RuntimeError("fractional RGB row offsets are incomplete")
    result = pixels.astype(np.int16).copy()
    width = result.shape[1]
    x = np.arange(width, dtype=np.int64)
    for row, offset in zip(rows, offsets):
        sign = 1 if float(offset) >= 0.0 else -1
        magnitude = abs(float(offset))
        whole = int(math.floor(magnitude))
        fraction = magnitude - whole
        delta = np.full(width, whole, dtype=np.int16)
        cutoff = int(round(fraction * WRAP_VALUE_CLOSURE_DITHER_DENOMINATOR))
        phase = (
            x * 1559 + row * 811 + salt * 3571
        ) % WRAP_VALUE_CLOSURE_DITHER_DENOMINATOR
        delta += (phase < cutoff).astype(np.int16)
        if sign < 0:
            allowed = result[row].min(axis=1) >= delta
        else:
            allowed = result[row].max(axis=1) <= 255 - delta
        result[row, allowed] += sign * delta[allowed, None]
    return np.clip(result, 0, 255).astype(np.uint8)


def _close_x4_and_world_seam_luma(
    pixels: np.ndarray,
    spec: BandSpec,
) -> tuple[np.ndarray, dict[str, object]]:
    top_rows, bottom_rows = _edge_rows(spec)
    closure_rows = WRAP_VALUE_CLOSURE_TEXTURE_ROWS
    if closure_rows > min(top_rows, bottom_rows):
        raise RuntimeError(f"{spec.output}: value closure exceeds approved edge bands")
    denominator = closure_rows - 1
    distance = np.arange(denominator, -1, -1, dtype=np.int64)
    weights = (
        _smoothstep_numerator(distance, denominator).astype(np.float64)
        / float(denominator**3)
    )
    top_indices = list(range(closure_rows))
    bottom_indices = list(range(pixels.shape[0] - closure_rows, pixels.shape[0]))
    result = pixels.copy()
    before_x4 = _seam_row_mean_luma_jump(result, TEXTURE_SCALE)
    before_world = _seam_row_mean_luma_jump(result, 1)
    coarse_world_iterations = 0
    for iteration in range(WRAP_VALUE_CLOSURE_MAX_ITERATIONS):
        signed_jump = _seam_row_mean_luma_jump(result, 1, signed=True)
        if abs(signed_jump) <= WRAP_WORLD_MAX_SEAM_ROW_MEAN_LUMA_JUMP:
            break
        top_offsets = -0.5 * signed_jump * weights
        bottom_offsets = 0.5 * signed_jump * weights[::-1]
        result = _apply_fractional_rgb_row_offsets(
            result,
            top_indices,
            top_offsets,
            iteration * 2,
        )
        result = _apply_fractional_rgb_row_offsets(
            result,
            bottom_indices,
            bottom_offsets,
            iteration * 2 + 1,
        )
        coarse_world_iterations += 1
    after_coarse_world = _seam_row_mean_luma_jump(result, 1)
    if after_coarse_world > WRAP_WORLD_MAX_SEAM_ROW_MEAN_LUMA_JUMP:
        raise RuntimeError(
            f"{spec.output}: coarse world seam luma closure did not converge: "
            f"{after_coarse_world}"
        )

    before_x4_endpoint = _seam_row_mean_luma_jump(result, TEXTURE_SCALE)
    x4_iterations = 0
    for iteration in range(WRAP_VALUE_CLOSURE_MAX_ITERATIONS):
        signed_jump = _seam_row_mean_luma_jump(
            result,
            TEXTURE_SCALE,
            signed=True,
        )
        if abs(signed_jump) <= WRAP_X4_MAX_SEAM_ROW_MEAN_LUMA_JUMP:
            break
        result = _apply_fractional_rgb_row_offsets(
            result,
            [0],
            np.asarray([-0.5 * signed_jump]),
            100 + iteration * 2,
        )
        result = _apply_fractional_rgb_row_offsets(
            result,
            [result.shape[0] - 1],
            np.asarray([0.5 * signed_jump]),
            101 + iteration * 2,
        )
        x4_iterations += 1
    after_x4_endpoint = _seam_row_mean_luma_jump(result, TEXTURE_SCALE)
    if after_x4_endpoint > WRAP_X4_MAX_SEAM_ROW_MEAN_LUMA_JUMP:
        raise RuntimeError(
            f"{spec.output}: x4 seam luma closure did not converge: "
            f"{after_x4_endpoint}"
        )

    inner_rows = closure_rows - 1
    inner_denominator = inner_rows - 1
    if inner_denominator <= 0:
        raise RuntimeError(f"{spec.output}: world inner closure is too narrow")
    inner_distance = np.arange(
        inner_denominator,
        -1,
        -1,
        dtype=np.int64,
    )
    inner_weights = (
        _smoothstep_numerator(inner_distance, inner_denominator).astype(np.float64)
        / float(inner_denominator**3)
    )
    inner_top_indices = list(range(1, closure_rows))
    inner_bottom_indices = list(range(
        pixels.shape[0] - closure_rows,
        pixels.shape[0] - 1,
    ))
    before_world_inner = _seam_row_mean_luma_jump(result, 1)
    world_inner_iterations = 0
    for iteration in range(WRAP_VALUE_CLOSURE_MAX_ITERATIONS):
        signed_jump = _seam_row_mean_luma_jump(result, 1, signed=True)
        if abs(signed_jump) <= WRAP_WORLD_MAX_SEAM_ROW_MEAN_LUMA_JUMP:
            break
        result = _apply_fractional_rgb_row_offsets(
            result,
            inner_top_indices,
            -0.5 * signed_jump * inner_weights,
            200 + iteration * 2,
        )
        result = _apply_fractional_rgb_row_offsets(
            result,
            inner_bottom_indices,
            0.5 * signed_jump * inner_weights[::-1],
            201 + iteration * 2,
        )
        world_inner_iterations += 1
    after_x4 = _seam_row_mean_luma_jump(result, TEXTURE_SCALE)
    after_world = _seam_row_mean_luma_jump(result, 1)
    if after_x4 > WRAP_X4_MAX_SEAM_ROW_MEAN_LUMA_JUMP:
        raise RuntimeError(
            f"{spec.output}: world inner closure disturbed x4 luma: {after_x4}"
        )
    if after_world > WRAP_WORLD_MAX_SEAM_ROW_MEAN_LUMA_JUMP:
        raise RuntimeError(
            f"{spec.output}: world inner seam luma closure did not converge: "
            f"{after_world}"
        )
    total_iterations = (
        coarse_world_iterations + x4_iterations + world_inner_iterations
    )
    return result, {
        "method": (
            "coarse_world_then_x4_endpoint_then_world_inner_dc_dither_v2"
        ),
        "texture_rows_per_side": closure_rows,
        "world_rows_per_side": closure_rows / TEXTURE_SCALE,
        "x4_endpoint_texture_rows_per_side": 1,
        "world_inner_texture_rows_per_side": inner_rows,
        "world_inner_excludes_x4_endpoint_rows": True,
        "iterations": total_iterations,
        "coarse_world_iterations": coarse_world_iterations,
        "x4_endpoint_iterations": x4_iterations,
        "world_inner_iterations": world_inner_iterations,
        "before_x4_seam_row_mean_luma_jump": before_x4,
        "before_world_seam_row_mean_luma_jump": before_world,
        "after_coarse_world_seam_row_mean_luma_jump": after_coarse_world,
        "before_x4_endpoint_seam_row_mean_luma_jump": before_x4_endpoint,
        "after_x4_endpoint_seam_row_mean_luma_jump": after_x4_endpoint,
        "before_world_inner_seam_row_mean_luma_jump": before_world_inner,
        "after_x4_seam_row_mean_luma_jump": after_x4,
        "after_world_seam_row_mean_luma_jump": after_world,
        "maximum_x4_seam_row_mean_luma_jump": (
            WRAP_X4_MAX_SEAM_ROW_MEAN_LUMA_JUMP
        ),
        "maximum_world_seam_row_mean_luma_jump": (
            WRAP_WORLD_MAX_SEAM_ROW_MEAN_LUMA_JUMP
        ),
        "dither_denominator": WRAP_VALUE_CLOSURE_DITHER_DENOMINATOR,
        "channel_offset": "equal_rgb_preserves_local_chroma_and_ink_residual",
        "render_proxy_source_scales": ["x4", "x4_to_world_lanczos"],
        "render_proxy_boundary_rows": "last_then_first_at_each_source_scale",
        "projected_boundary_snap": "round",
        "projected_snap_invariant": True,
    }


def _image_luminance(pixels: np.ndarray) -> np.ndarray:
    return (
        pixels[..., 0].astype(np.float64) * 0.2126
        + pixels[..., 1].astype(np.float64) * 0.7152
        + pixels[..., 2].astype(np.float64) * 0.0722
    )


def _qa_world_row_profile(pixels: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    world_size = (
        EXPECTED_SIZE[0] // TEXTURE_SCALE,
        EXPECTED_SIZE[1] // TEXTURE_SCALE,
    )
    world = Image.fromarray(pixels).resize(world_size, Image.Resampling.LANCZOS)
    luma_sample = np.asarray(
        world.resize((1, world_size[1]), Image.Resampling.LANCZOS),
        dtype=np.uint8,
    )
    detail_sample = np.asarray(
        world.resize(
            (BRIGHT_GUTTER_DETAIL_SAMPLE_WIDTH, world_size[1]),
            Image.Resampling.LANCZOS,
        ),
        dtype=np.uint8,
    )
    row_luma = _image_luminance(luma_sample)[:, 0]
    row_detail = _image_luminance(detail_sample).std(axis=1)
    return row_luma, row_detail


def _delta_summary(delta: np.ndarray) -> dict[str, float | int]:
    absolute = np.abs(delta.astype(np.int16))
    return {
        "mean_abs_rgb_delta": float(absolute.mean()),
        "p95_abs_rgb_delta": float(
            np.percentile(absolute, 95, method="higher")
        ),
        "max_channel_delta": int(absolute.max()),
    }


def _pearson_luma(first: np.ndarray, second: np.ndarray) -> float:
    if first.shape != second.shape or first.size == 0:
        raise RuntimeError("correlation samples must have the same non-empty shape")
    first_values = _image_luminance(first).ravel()
    second_values = _image_luminance(second).ravel()
    first_values -= first_values.mean()
    second_values -= second_values.mean()
    denominator = math.sqrt(
        float(np.square(first_values).sum())
        * float(np.square(second_values).sum())
    )
    if denominator <= 1.0e-9:
        return 0.0
    return float(np.dot(first_values, second_values) / denominator)


def _resized_for_scale(pixels: np.ndarray, texture_scale: int) -> np.ndarray:
    if texture_scale == TEXTURE_SCALE:
        return pixels
    if texture_scale != 1:
        raise RuntimeError(f"unsupported metric texture scale: {texture_scale}")
    return np.asarray(
        Image.fromarray(pixels).resize(
            (EXPECTED_SIZE[0] // TEXTURE_SCALE, EXPECTED_SIZE[1] // TEXTURE_SCALE),
            Image.Resampling.LANCZOS,
        ),
        dtype=np.uint8,
    )


def _lap_metrics(
    pixels: np.ndarray,
    spec: BandSpec,
    texture_scale: int,
) -> dict[str, object]:
    sample = _resized_for_scale(pixels, texture_scale)
    lap_rows = _lap_world_px(spec) * texture_scale
    top_rows = spec.top_world_px * texture_scale
    bottom_rows = spec.bottom_world_px * texture_scale
    top_lap = sample[:lap_rows]
    bottom_lap = sample[-lap_rows:]
    seam_left_step = (
        bottom_lap[-1].astype(np.int16) - bottom_lap[-2].astype(np.int16)
    )
    seam_right_step = (
        top_lap[1].astype(np.int16) - top_lap[0].astype(np.int16)
    )
    bottom_boundary_step = (
        sample[-bottom_rows].astype(np.int16)
        - sample[-bottom_rows - 1].astype(np.int16)
    )
    top_boundary_step = (
        sample[top_rows].astype(np.int16)
        - sample[top_rows - 1].astype(np.int16)
    )
    bottom_body_step = (
        sample[-bottom_rows - 1].astype(np.int16)
        - sample[-bottom_rows - 2].astype(np.int16)
    )
    top_body_step = (
        sample[top_rows + 1].astype(np.int16)
        - sample[top_rows].astype(np.int16)
    )
    detail_width = min(BRIGHT_GUTTER_DETAIL_SAMPLE_WIDTH, sample.shape[1])
    detail_sample = np.asarray(
        Image.fromarray(sample).resize(
            (detail_width, sample.shape[0]),
            Image.Resampling.LANCZOS,
        ),
        dtype=np.uint8,
    )
    detail = _image_luminance(detail_sample).std(axis=1)
    lap_detail = np.concatenate((detail[-lap_rows:], detail[:lap_rows]))
    return {
        "texture_scale": texture_scale,
        "comparison_rows": lap_rows,
        "seam_row_mean_luma_jump": abs(
            float(_image_luminance(sample)[0].mean())
            - float(_image_luminance(sample)[-1].mean())
        ),
        "paired": _delta_summary(
            top_lap.astype(np.int16) - bottom_lap.astype(np.int16)
        ),
        "seam": _delta_summary(
            top_lap[0].astype(np.int16) - bottom_lap[-1].astype(np.int16)
        ),
        "derivative": _delta_summary(seam_right_step - seam_left_step),
        "body_boundary": _delta_summary(
            np.stack((bottom_boundary_step, top_boundary_step))
        ),
        "body_boundary_derivative": _delta_summary(
            np.stack((
                bottom_boundary_step - bottom_body_step,
                top_body_step - top_boundary_step,
            ))
        ),
        "minimum_row_detail": float(lap_detail.min()),
    }


def _self_similarity(
    pixels: np.ndarray,
    spec: BandSpec,
    texture_scale: int,
    source_world_row: int,
) -> dict[str, float | int]:
    sample = _resized_for_scale(pixels, texture_scale)
    source_texture_row = source_world_row * texture_scale
    exemplar_rows = (spec.top_world_px + spec.bottom_world_px) * texture_scale
    exemplar = sample[
        source_texture_row : source_texture_row + exemplar_rows
    ]
    if exemplar.shape[0] != exemplar_rows:
        raise RuntimeError(f"{spec.output}: similarity control exemplar is incomplete")
    lap_rows = _lap_world_px(spec) * texture_scale
    bottom_rows = spec.bottom_world_px * texture_scale
    actual_bottom = sample[-lap_rows:]
    actual_top = sample[:lap_rows]
    control_bottom = exemplar[bottom_rows - lap_rows : bottom_rows]
    control_top = exemplar[bottom_rows : bottom_rows + lap_rows]
    direct = _pearson_luma(actual_bottom, actual_top)
    direct_control = _pearson_luma(control_bottom, control_top)
    mirror = _pearson_luma(actual_bottom[::-1], actual_top)
    mirror_control = _pearson_luma(control_bottom[::-1], control_top)
    return {
        "texture_scale": texture_scale,
        "direct_correlation": direct,
        "direct_control": direct_control,
        "direct_excess": direct - direct_control,
        "mirror_correlation": mirror,
        "mirror_control": mirror_control,
        "mirror_excess": mirror - mirror_control,
    }


def _validation_thresholds() -> dict[str, object]:
    return {
        "x4_paired": {
            "mean_abs_rgb_delta": WRAP_X4_MAX_PAIRED_MEAN_ABS_RGB_DELTA,
            "p95_abs_rgb_delta": WRAP_X4_MAX_PAIRED_P95_ABS_RGB_DELTA,
            "max_channel_delta": WRAP_X4_MAX_PAIRED_CHANNEL_DELTA,
        },
        "world_paired": {
            "mean_abs_rgb_delta": WRAP_WORLD_MAX_PAIRED_MEAN_ABS_RGB_DELTA,
            "p95_abs_rgb_delta": WRAP_WORLD_MAX_PAIRED_P95_ABS_RGB_DELTA,
            "max_channel_delta": WRAP_WORLD_MAX_PAIRED_CHANNEL_DELTA,
        },
        "x4_seam": {
            "mean_abs_rgb_delta": WRAP_X4_MAX_SEAM_MEAN_ABS_RGB_DELTA,
            "p95_abs_rgb_delta": WRAP_X4_MAX_SEAM_P95_ABS_RGB_DELTA,
            "max_channel_delta": WRAP_X4_MAX_SEAM_CHANNEL_DELTA,
        },
        "world_seam": {
            "mean_abs_rgb_delta": WRAP_WORLD_MAX_SEAM_MEAN_ABS_RGB_DELTA,
            "p95_abs_rgb_delta": WRAP_WORLD_MAX_SEAM_P95_ABS_RGB_DELTA,
            "max_channel_delta": WRAP_WORLD_MAX_SEAM_CHANNEL_DELTA,
        },
        "x4_derivative": {
            "mean_abs_rgb_delta": WRAP_X4_MAX_DERIVATIVE_MEAN_ABS_RGB_DELTA,
            "p95_abs_rgb_delta": WRAP_X4_MAX_DERIVATIVE_P95_ABS_RGB_DELTA,
            "max_channel_delta": WRAP_X4_MAX_DERIVATIVE_CHANNEL_DELTA,
        },
        "world_derivative": {
            "mean_abs_rgb_delta": WRAP_WORLD_MAX_DERIVATIVE_MEAN_ABS_RGB_DELTA,
            "p95_abs_rgb_delta": WRAP_WORLD_MAX_DERIVATIVE_P95_ABS_RGB_DELTA,
            "max_channel_delta": WRAP_WORLD_MAX_DERIVATIVE_CHANNEL_DELTA,
        },
        "x4_body_boundary": {
            "mean_abs_rgb_delta": WRAP_X4_MAX_BODY_BOUNDARY_MEAN_ABS_RGB_DELTA,
            "p95_abs_rgb_delta": WRAP_X4_MAX_BODY_BOUNDARY_P95_ABS_RGB_DELTA,
            "max_channel_delta": WRAP_X4_MAX_BODY_BOUNDARY_CHANNEL_DELTA,
        },
        "world_body_boundary": {
            "mean_abs_rgb_delta": WRAP_WORLD_MAX_BODY_BOUNDARY_MEAN_ABS_RGB_DELTA,
            "p95_abs_rgb_delta": WRAP_WORLD_MAX_BODY_BOUNDARY_P95_ABS_RGB_DELTA,
            "max_channel_delta": WRAP_WORLD_MAX_BODY_BOUNDARY_CHANNEL_DELTA,
        },
        "x4_body_boundary_derivative": {
            "mean_abs_rgb_delta": WRAP_X4_MAX_BODY_DERIVATIVE_MEAN_ABS_RGB_DELTA,
            "p95_abs_rgb_delta": WRAP_X4_MAX_BODY_DERIVATIVE_P95_ABS_RGB_DELTA,
            "max_channel_delta": WRAP_X4_MAX_BODY_DERIVATIVE_CHANNEL_DELTA,
        },
        "world_body_boundary_derivative": {
            "mean_abs_rgb_delta": WRAP_WORLD_MAX_BODY_DERIVATIVE_MEAN_ABS_RGB_DELTA,
            "p95_abs_rgb_delta": WRAP_WORLD_MAX_BODY_DERIVATIVE_P95_ABS_RGB_DELTA,
            "max_channel_delta": WRAP_WORLD_MAX_BODY_DERIVATIVE_CHANNEL_DELTA,
        },
        "x4_seam_row_mean_luma_jump": WRAP_X4_MAX_SEAM_ROW_MEAN_LUMA_JUMP,
        "world_seam_row_mean_luma_jump": (
            WRAP_WORLD_MAX_SEAM_ROW_MEAN_LUMA_JUMP
        ),
        "minimum_world_row_detail": WRAP_MIN_WORLD_ROW_DETAIL,
        "minimum_paired_mean_improvement_fraction": (
            WRAP_MIN_PAIRED_MEAN_IMPROVEMENT_FRACTION
        ),
        "maximum_direct_correlation_excess": WRAP_MAX_DIRECT_CORRELATION_EXCESS,
        "maximum_mirror_correlation_excess": WRAP_MAX_MIRROR_CORRELATION_EXCESS,
    }


def _validate_metric_summary(
    output: str,
    label: str,
    actual: dict[str, float | int],
    limits: dict[str, float | int],
) -> None:
    for key, limit in limits.items():
        if float(actual[key]) > float(limit):
            raise RuntimeError(
                f"{output}: {label} {key}={actual[key]} exceeds {limit}"
            )


def _validate_vertical_wrap(
    spec: BandSpec,
    x4_metrics: dict[str, object],
    world_metrics: dict[str, object],
    x4_similarity: dict[str, float | int],
    world_similarity: dict[str, float | int],
    z11_x4_metrics: dict[str, object],
    z11_world_metrics: dict[str, object],
) -> None:
    thresholds = _validation_thresholds()
    for label, actual, limit_key in (
        ("x4 paired lap", x4_metrics["paired"], "x4_paired"),
        ("world paired lap", world_metrics["paired"], "world_paired"),
        ("x4 seam", x4_metrics["seam"], "x4_seam"),
        ("world seam", world_metrics["seam"], "world_seam"),
        ("x4 seam derivative", x4_metrics["derivative"], "x4_derivative"),
        ("world seam derivative", world_metrics["derivative"], "world_derivative"),
        ("x4 body boundary", x4_metrics["body_boundary"], "x4_body_boundary"),
        (
            "world body boundary",
            world_metrics["body_boundary"],
            "world_body_boundary",
        ),
        (
            "x4 body boundary derivative",
            x4_metrics["body_boundary_derivative"],
            "x4_body_boundary_derivative",
        ),
        (
            "world body boundary derivative",
            world_metrics["body_boundary_derivative"],
            "world_body_boundary_derivative",
        ),
    ):
        _validate_metric_summary(
            spec.output,
            label,
            actual,
            thresholds[limit_key],
        )
    if float(world_metrics["minimum_row_detail"]) < WRAP_MIN_WORLD_ROW_DETAIL:
        raise RuntimeError(
            f"{spec.output}: lap row detail "
            f"{world_metrics['minimum_row_detail']:.6f} is below "
            f"{WRAP_MIN_WORLD_ROW_DETAIL:.6f}"
        )
    if (
        float(x4_metrics["seam_row_mean_luma_jump"])
        > WRAP_X4_MAX_SEAM_ROW_MEAN_LUMA_JUMP
    ):
        raise RuntimeError(f"{spec.output}: x4 seam row-mean luma jump is excessive")
    if (
        float(world_metrics["seam_row_mean_luma_jump"])
        > WRAP_WORLD_MAX_SEAM_ROW_MEAN_LUMA_JUMP
    ):
        raise RuntimeError(f"{spec.output}: world seam row-mean luma jump is excessive")
    for scale_label, similarity in (
        ("x4", x4_similarity),
        ("world", world_similarity),
    ):
        if float(similarity["direct_excess"]) > WRAP_MAX_DIRECT_CORRELATION_EXCESS:
            raise RuntimeError(
                f"{spec.output}: {scale_label} periodic direct self-correlation "
                "is excessive"
            )
        if float(similarity["mirror_excess"]) > WRAP_MAX_MIRROR_CORRELATION_EXCESS:
            raise RuntimeError(
                f"{spec.output}: {scale_label} seam mirror correlation is excessive"
            )
    for scale_label, metrics, z11_metrics in (
        ("x4", x4_metrics, z11_x4_metrics),
        ("world", world_metrics, z11_world_metrics),
    ):
        actual_mean = float(metrics["paired"]["mean_abs_rgb_delta"])
        z11_mean = float(z11_metrics["paired"]["mean_abs_rgb_delta"])
        improvement = 1.0 - actual_mean / z11_mean
        if improvement < WRAP_MIN_PAIRED_MEAN_IMPROVEMENT_FRACTION:
            raise RuntimeError(
                f"{spec.output}: {scale_label} paired mean improvement "
                f"{improvement:.6f} is below "
                f"{WRAP_MIN_PAIRED_MEAN_IMPROVEMENT_FRACTION:.6f}"
            )


def _bright_gutter_diagnostic_from_profiles(
    row_luma: np.ndarray,
    row_detail: np.ndarray,
    probe_source_rows: list[int],
) -> dict[str, object]:
    local_luma = np.sort(row_luma[probe_source_rows])
    reference_index = int(math.floor(float(local_luma.size - 1) * 0.25))
    local_reference = float(local_luma[reference_index])
    adaptive_threshold = max(
        BRIGHT_GUTTER_LUMA_THRESHOLD,
        local_reference + 12.0,
    )
    runs: list[tuple[int, int]] = []
    run_start = -1
    for probe_index in range(len(probe_source_rows) + 1):
        bright = (
            probe_index < len(probe_source_rows)
            and float(row_luma[probe_source_rows[probe_index]]) >= adaptive_threshold
            and float(row_detail[probe_source_rows[probe_index]])
                <= BRIGHT_GUTTER_DETAIL_THRESHOLD
        )
        if bright and run_start < 0:
            run_start = probe_index
        elif not bright and run_start >= 0:
            if probe_index - run_start >= BRIGHT_GUTTER_MIN_RUN_WORLD_PX:
                runs.append((run_start, probe_index))
            run_start = -1
    return {
        "row_luma": row_luma,
        "row_detail": row_detail,
        "local_reference": local_reference,
        "adaptive_threshold": adaptive_threshold,
        "probe_source_rows": probe_source_rows,
        "runs": runs,
        "maximum_run_world_px": max(
            (end - start for start, end in runs),
            default=0,
        ),
    }


def _bright_gutter_diagnostic_for_source_rows(
    pixels: np.ndarray,
    probe_source_rows: list[int],
) -> dict[str, object]:
    row_luma, row_detail = _qa_world_row_profile(pixels)
    return _bright_gutter_diagnostic_from_profiles(
        row_luma,
        row_detail,
        probe_source_rows,
    )


def _phase16_bright_gutter_diagnostic(pixels: np.ndarray) -> dict[str, object]:
    return _bright_gutter_diagnostic_for_source_rows(
        pixels,
        list(range(BRIGHT_GUTTER_SEARCH_RADIUS_WORLD_PX * 2 + 1)),
    )


def _cyclic_bright_gutter_diagnostic(pixels: np.ndarray) -> dict[str, object]:
    world_height = EXPECTED_SIZE[1] // TEXTURE_SCALE
    return _bright_gutter_diagnostic_for_source_rows(
        pixels,
        list(range(
            world_height - BRIGHT_GUTTER_SEARCH_RADIUS_WORLD_PX,
            world_height,
        )) + list(range(BRIGHT_GUTTER_SEARCH_RADIUS_WORLD_PX + 1)),
    )


def _remove_bright_gutter_runs(
    pixels: np.ndarray,
    spec: BandSpec,
) -> tuple[np.ndarray, dict[str, object]]:
    result = pixels.copy()
    corrections: list[dict[str, object]] = []
    maximum_attempts = spec.top_world_px + spec.bottom_world_px
    world_height = EXPECTED_SIZE[1] // TEXTURE_SCALE
    bottom_edge_start = world_height - spec.bottom_world_px
    for _attempt in range(maximum_attempts):
        diagnostics = [
            ("forward_body_phase16", _phase16_bright_gutter_diagnostic(result)),
            ("cyclic_bottom_then_top", _cyclic_bright_gutter_diagnostic(result)),
        ]
        failing_probes = [
            (probe_name, diagnostic)
            for probe_name, diagnostic in diagnostics
            if diagnostic["runs"]
        ]
        if not failing_probes:
            return result, {
                "method": BRIGHT_GUTTER_GUARD_METHOD,
                "probes": [
                    "forward_body_phase16",
                    "cyclic_bottom_then_top",
                ],
                "search_radius_world_px": BRIGHT_GUTTER_SEARCH_RADIUS_WORLD_PX,
                "detail_sample_width": BRIGHT_GUTTER_DETAIL_SAMPLE_WIDTH,
                "luma_threshold": BRIGHT_GUTTER_LUMA_THRESHOLD,
                "detail_threshold": BRIGHT_GUTTER_DETAIL_THRESHOLD,
                "minimum_run_world_px": BRIGHT_GUTTER_MIN_RUN_WORLD_PX,
                "target_luma": BRIGHT_GUTTER_TARGET_LUMA,
                "corrections": corrections,
                "phase16_maximum_run_world_px": 0,
                "cyclic_maximum_run_world_px": 0,
                "maximum_run_world_px": 0,
            }
        probe_name, diagnostic = max(
            failing_probes,
            key=lambda entry: (
                int(entry[1]["maximum_run_world_px"]),
                entry[0],
            ),
        )
        runs = diagnostic["runs"]
        run_start, run_end = max(
            runs,
            key=lambda run: (run[1] - run[0], run[1]),
        )
        probe_source_rows = diagnostic["probe_source_rows"]
        run_source_rows = probe_source_rows[run_start:run_end]
        modifiable_rows = []
        for world_y in run_source_rows:
            if 0 < world_y < spec.top_world_px:
                modifiable_rows.append((world_y, "top", spec.top_world_px - 1 - world_y))
            elif bottom_edge_start <= world_y < world_height - 1:
                modifiable_rows.append((world_y, "bottom", world_y - bottom_edge_start))
        if not modifiable_rows:
            raise RuntimeError(
                f"{spec.output}: {probe_name} bright gutter run {run_source_rows} "
                "does not intersect an approved edge band"
            )
        world_y, edge_name, _distance = min(
            modifiable_rows,
            key=lambda candidate: (candidate[2], candidate[0]),
        )
        row_luma = diagnostic["row_luma"]
        subtract_rgb = max(
            1,
            int(math.ceil(float(row_luma[world_y]) - BRIGHT_GUTTER_TARGET_LUMA)),
        )
        texture_start = world_y * TEXTURE_SCALE
        texture_end = texture_start + TEXTURE_SCALE
        corrected = result[texture_start:texture_end].astype(np.int16) - subtract_rgb
        result[texture_start:texture_end] = np.clip(corrected, 0, 255).astype(np.uint8)
        corrections.append({
            "probe": probe_name,
            "edge": edge_name,
            "world_row": world_y,
            "subtract_rgb": subtract_rgb,
        })
    final_phase16 = _phase16_bright_gutter_diagnostic(result)
    final_cyclic = _cyclic_bright_gutter_diagnostic(result)
    raise RuntimeError(
        f"{spec.output}: bright gutter guard did not converge: "
        f"phase16={final_phase16['runs']} cyclic={final_cyclic['runs']}"
    )


def _world_detail_sample(pixels: np.ndarray) -> np.ndarray:
    return np.asarray(
        Image.fromarray(pixels).resize(
            (
                BRIGHT_GUTTER_DETAIL_SAMPLE_WIDTH,
                EXPECTED_SIZE[1] // TEXTURE_SCALE,
            ),
            Image.Resampling.LANCZOS,
        ),
        dtype=np.uint8,
    )


def _world_full_sample(pixels: np.ndarray) -> np.ndarray:
    return np.asarray(
        Image.fromarray(pixels).resize(
            (
                EXPECTED_SIZE[0] // TEXTURE_SCALE,
                EXPECTED_SIZE[1] // TEXTURE_SCALE,
            ),
            Image.Resampling.LANCZOS,
        ),
        dtype=np.uint8,
    )


def _profiles_from_world_detail_sample(
    pixels: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    height = pixels.shape[0]
    luma_sample = np.asarray(
        Image.fromarray(pixels).resize((1, height), Image.Resampling.LANCZOS),
        dtype=np.uint8,
    )
    return _image_luminance(luma_sample)[:, 0], _image_luminance(pixels).std(axis=1)


def _assemble_bridge(
    pixels: np.ndarray,
    bridge: np.ndarray,
    top_rows: int,
    bottom_rows: int,
) -> np.ndarray:
    result = pixels.copy()
    result[-bottom_rows:] = bridge[:bottom_rows]
    result[:top_rows] = bridge[bottom_rows:]
    return result


def _select_forward_exemplar(
    pixels: np.ndarray,
    spec: BandSpec,
) -> tuple[int, dict[str, object]]:
    world = _world_detail_sample(pixels)
    world_full = _world_full_sample(pixels)
    world_height = world.shape[0]
    bridge_rows = spec.top_world_px + spec.bottom_world_px
    lap_rows = _lap_world_px(spec)
    bottom_anchor = world[world_height - spec.bottom_world_px - 1]
    top_anchor = world[spec.top_world_px]
    first_start = spec.top_world_px
    last_start = world_height - spec.bottom_world_px - bridge_rows
    if last_start < first_start:
        raise RuntimeError(f"{spec.output}: approved body is too short for an exemplar")

    best: tuple[tuple[float, ...], int, dict[str, object]] | None = None
    for source_world_row in range(first_start, last_start + 1):
        raw_exemplar = world[
            source_world_row : source_world_row + bridge_rows
        ]
        raw_exemplar_full = world_full[
            source_world_row : source_world_row + bridge_rows
        ]
        bridge = _apply_forward_exemplar_lap(
            raw_exemplar,
            spec.bottom_world_px,
            lap_rows,
            bottom_anchor,
            top_anchor,
            1,
        )
        candidate = _assemble_bridge(
            world,
            bridge,
            spec.top_world_px,
            spec.bottom_world_px,
        )
        bridge_full = _apply_forward_exemplar_lap(
            raw_exemplar_full,
            spec.bottom_world_px,
            lap_rows,
            world_full[world_height - spec.bottom_world_px - 1],
            world_full[spec.top_world_px],
            1,
        )
        candidate_full = _assemble_bridge(
            world_full,
            bridge_full,
            spec.top_world_px,
            spec.bottom_world_px,
        )
        row_luma, row_detail = _profiles_from_world_detail_sample(candidate)
        phase = _bright_gutter_diagnostic_from_profiles(
            row_luma,
            row_detail,
            list(range(BRIGHT_GUTTER_SEARCH_RADIUS_WORLD_PX * 2 + 1)),
        )
        cyclic_rows = list(range(
            world_height - BRIGHT_GUTTER_SEARCH_RADIUS_WORLD_PX,
            world_height,
        )) + list(range(BRIGHT_GUTTER_SEARCH_RADIUS_WORLD_PX + 1))
        cyclic = _bright_gutter_diagnostic_from_profiles(
            row_luma,
            row_detail,
            cyclic_rows,
        )
        actual_bottom = candidate_full[-lap_rows:]
        actual_top = candidate_full[:lap_rows]
        control_bottom = raw_exemplar_full[
            spec.bottom_world_px - lap_rows : spec.bottom_world_px
        ]
        control_top = raw_exemplar_full[
            spec.bottom_world_px : spec.bottom_world_px + lap_rows
        ]
        paired = _delta_summary(
            actual_top.astype(np.int16) - actual_bottom.astype(np.int16)
        )
        seam = _delta_summary(
            actual_top[0].astype(np.int16) - actual_bottom[-1].astype(np.int16)
        )
        direct = _pearson_luma(actual_bottom, actual_top)
        direct_control = _pearson_luma(control_bottom, control_top)
        mirror = _pearson_luma(actual_bottom[::-1], actual_top)
        mirror_control = _pearson_luma(control_bottom[::-1], control_top)
        lap_detail = np.concatenate((row_detail[-lap_rows:], row_detail[:lap_rows]))
        minimum_detail = float(lap_detail.min())
        gutter_width = max(
            int(phase["maximum_run_world_px"]),
            int(cyclic["maximum_run_world_px"]),
        )
        direct_excess = direct - direct_control
        mirror_excess = mirror - mirror_control
        score = (
            float(gutter_width),
            max(
                0.0,
                WRAP_SELECTION_MIN_WORLD_ROW_DETAIL - minimum_detail,
            ),
            max(
                0.0,
                float(paired["mean_abs_rgb_delta"])
                    - WRAP_SELECTION_WORLD_MAX_PAIRED_MEAN_ABS_RGB_DELTA,
            ),
            max(
                0.0,
                float(paired["p95_abs_rgb_delta"])
                    - WRAP_SELECTION_WORLD_MAX_PAIRED_P95_ABS_RGB_DELTA,
            ),
            max(
                0.0,
                float(paired["max_channel_delta"])
                    - WRAP_SELECTION_WORLD_MAX_PAIRED_CHANNEL_DELTA,
            ),
            max(
                0.0,
                float(seam["mean_abs_rgb_delta"])
                    - WRAP_SELECTION_WORLD_MAX_SEAM_MEAN_ABS_RGB_DELTA,
            ),
            max(
                0.0,
                float(seam["p95_abs_rgb_delta"])
                    - WRAP_SELECTION_WORLD_MAX_SEAM_P95_ABS_RGB_DELTA,
            ),
            max(
                0.0,
                float(seam["max_channel_delta"])
                    - WRAP_SELECTION_WORLD_MAX_SEAM_CHANNEL_DELTA,
            ),
            max(
                0.0,
                direct_excess
                    - (
                        WRAP_MAX_DIRECT_CORRELATION_EXCESS
                        - WRAP_SELECTION_DIRECT_CORRELATION_MARGIN
                    ),
            ),
            max(
                0.0,
                mirror_excess
                    - (
                        WRAP_MAX_MIRROR_CORRELATION_EXCESS
                        - WRAP_SELECTION_MIRROR_CORRELATION_MARGIN
                    ),
            ),
            float(paired["mean_abs_rgb_delta"])
                + float(seam["mean_abs_rgb_delta"]) * 0.25,
            float(source_world_row),
        )
        selection = {
            "source_world_row": source_world_row,
            "world_paired": paired,
            "world_seam": seam,
            "minimum_world_row_detail": minimum_detail,
            "direct_correlation": direct,
            "direct_control": direct_control,
            "direct_excess": direct_excess,
            "mirror_correlation": mirror,
            "mirror_control": mirror_control,
            "mirror_excess": mirror_excess,
            "maximum_gutter_run_world_px": gutter_width,
        }
        if best is None or score < best[0]:
            best = score, source_world_row, selection
    if best is None:
        raise RuntimeError(f"{spec.output}: no forward exemplar candidate was evaluated")
    if any(value > 0.0 for value in best[0][:10]):
        raise RuntimeError(
            f"{spec.output}: no forward exemplar met the sealed constraints: "
            f"score={best[0]} selection={best[2]}"
        )
    return best[1], best[2]


def _forward_exemplar_wrap(
    pixels: np.ndarray,
    spec: BandSpec,
) -> tuple[np.ndarray, np.ndarray, dict[str, object]]:
    top_rows, bottom_rows = _edge_rows(spec)
    lap_world_px = _lap_world_px(spec)
    lap_rows = lap_world_px * TEXTURE_SCALE
    bridge_rows = top_rows + bottom_rows
    source_world_row, selection = _select_forward_exemplar(pixels, spec)
    source_texture_row = source_world_row * TEXTURE_SCALE
    raw_exemplar = pixels[
        source_texture_row : source_texture_row + bridge_rows
    ].copy()
    if raw_exemplar.shape[0] != bridge_rows:
        raise RuntimeError(f"{spec.output}: selected exemplar is incomplete")
    bridge = _apply_forward_exemplar_lap(
        raw_exemplar,
        bottom_rows,
        lap_rows,
        pixels[pixels.shape[0] - bottom_rows - 1],
        pixels[top_rows],
        WRAP_PAIR_RAMP_TEXTURE_ROWS,
    )
    result = _assemble_bridge(pixels, bridge, top_rows, bottom_rows)
    contract = {
        "selection_method": WRAP_EXEMPLAR_SELECTION_METHOD,
        "source_world_row": source_world_row,
        "source_texture_row": source_texture_row,
        "bridge_world_px": spec.top_world_px + spec.bottom_world_px,
        "lap_world_px": lap_world_px,
        "orientation": "forward",
        "paired_weights": [
            WRAP_PAIR_WEIGHT_DENOMINATOR - WRAP_PAIR_OPPOSITE_WEIGHT,
            WRAP_PAIR_OPPOSITE_WEIGHT,
        ],
        "pair_weight_denominator": WRAP_PAIR_WEIGHT_DENOMINATOR,
        "pair_ramp_texture_rows": WRAP_PAIR_RAMP_TEXTURE_ROWS,
        "bottom_transition_texture_rows": bottom_rows - lap_rows,
        "top_transition_texture_rows": top_rows - lap_rows,
        "endpoint_correction": "additive_integer_smoothstep_residual",
        "selection_proxy_limits": {
            "minimum_world_row_detail": WRAP_SELECTION_MIN_WORLD_ROW_DETAIL,
            "world_paired": {
                "mean_abs_rgb_delta": (
                    WRAP_SELECTION_WORLD_MAX_PAIRED_MEAN_ABS_RGB_DELTA
                ),
                "p95_abs_rgb_delta": (
                    WRAP_SELECTION_WORLD_MAX_PAIRED_P95_ABS_RGB_DELTA
                ),
                "max_channel_delta": WRAP_SELECTION_WORLD_MAX_PAIRED_CHANNEL_DELTA,
            },
            "world_seam": {
                "mean_abs_rgb_delta": (
                    WRAP_SELECTION_WORLD_MAX_SEAM_MEAN_ABS_RGB_DELTA
                ),
                "p95_abs_rgb_delta": (
                    WRAP_SELECTION_WORLD_MAX_SEAM_P95_ABS_RGB_DELTA
                ),
                "max_channel_delta": WRAP_SELECTION_WORLD_MAX_SEAM_CHANNEL_DELTA,
            },
            "maximum_direct_correlation_excess": (
                WRAP_MAX_DIRECT_CORRELATION_EXCESS
                - WRAP_SELECTION_DIRECT_CORRELATION_MARGIN
            ),
            "maximum_mirror_correlation_excess": (
                WRAP_MAX_MIRROR_CORRELATION_EXCESS
                - WRAP_SELECTION_MIRROR_CORRELATION_MARGIN
            ),
        },
        "selection_metrics": selection,
    }
    return result, raw_exemplar, contract


def _validate_provenance(
    asset_root: Path,
    record: dict[str, object],
    pixels: np.ndarray,
    z11_base: np.ndarray,
    spec: BandSpec,
) -> None:
    edge_bleed = record.get("edge_bleed", {})
    if not isinstance(edge_bleed, dict):
        raise RuntimeError(f"{spec.output}: manifest edge provenance is missing")
    if edge_bleed.get("original_output_sha256") != spec.original_output_sha256:
        raise RuntimeError(f"{spec.output}: original output provenance drifted")
    if edge_bleed.get("z11_output_sha256") != spec.z11_output_sha256:
        raise RuntimeError(f"{spec.output}: Z11 output provenance drifted")
    if _rgb_sha256(z11_base) != spec.z11_rgb_sha256:
        raise RuntimeError(f"{spec.output}: reconstructed Z11 RGB provenance drifted")
    if _png_sha256(z11_base) != spec.z11_output_sha256:
        raise RuntimeError(f"{spec.output}: reconstructed Z11 PNG provenance drifted")
    source_name = str(record.get("source", ""))
    source_path = asset_root / source_name
    if not source_name or not source_path.is_file():
        raise RuntimeError(f"{spec.output}: manifest source is missing")
    if _file_sha256(source_path) != str(record.get("source_sha256", "")):
        raise RuntimeError(f"{spec.output}: source SHA-256 provenance drifted")
    if _interior_sha256(pixels, spec) != spec.interior_rgb_sha256:
        raise RuntimeError(f"{spec.output}: approved interior provenance drifted")


def _validate_bleed(pixels: np.ndarray, spec: BandSpec) -> None:
    top_rows, bottom_rows = _edge_rows(spec)
    expected_top = pixels[top_rows : top_rows * 2][::-1]
    height = pixels.shape[0]
    expected_bottom = pixels[height - bottom_rows * 2 : height - bottom_rows][::-1]
    if not np.array_equal(pixels[:top_rows], expected_top):
        raise RuntimeError(f"{spec.output}: top mirrored edge-bleed contract failed")
    if not np.array_equal(pixels[height - bottom_rows :], expected_bottom):
        raise RuntimeError(f"{spec.output}: bottom mirrored edge-bleed contract failed")


def _world_row_profile(pixels: np.ndarray, from_bottom: bool = False) -> tuple[np.ndarray, np.ndarray]:
    luminance = (
        pixels[..., 0].astype(np.float64) * 0.2126
        + pixels[..., 1].astype(np.float64) * 0.7152
        + pixels[..., 2].astype(np.float64) * 0.0722
    )
    world_rows = np.stack(
        [luminance[row : row + TEXTURE_SCALE] for row in range(0, luminance.shape[0], TEXTURE_SCALE)]
    )
    if from_bottom:
        world_rows = world_rows[::-1]
    return world_rows.mean(axis=(1, 2)), world_rows.std(axis=(1, 2))


def _profile_summary(pixels: np.ndarray, edge_world_px: int, from_bottom: bool) -> str:
    means, details = _world_row_profile(pixels, from_bottom)
    samples = sorted({0, 8, max(0, edge_world_px - 1), edge_world_px})
    return " ".join(
        f"{index}:L{means[index]:.1f}/D{details[index]:.1f}" for index in samples
    )


def _write_png(path: Path, pixels: np.ndarray) -> None:
    temporary = path.with_suffix(path.suffix + ".z13.tmp")
    Image.fromarray(pixels).save(
        temporary,
        format="PNG",
        compress_level=9,
        optimize=False,
    )
    temporary.replace(path)


def _update_manifest(
    asset_root: Path,
    wrapped_contract_by_name: dict[str, dict[str, object]],
) -> None:
    manifest_path = asset_root / MANIFEST_NAME
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    records = {str(record["output"]): record for record in manifest["assets"]}
    for spec in BAND_SPECS:
        record = records[spec.output]
        contract = wrapped_contract_by_name[spec.output]
        record["output_sha256"] = contract["output_sha256"]
        record["edge_bleed"] = {
            "method": WRAP_METHOD,
            "base_method": WRAP_BASE_METHOD,
            "texture_scale": TEXTURE_SCALE,
            "top_world_px": spec.top_world_px,
            "bottom_world_px": spec.bottom_world_px,
            "body_luma_threshold": BODY_LUMA_THRESHOLD,
            "body_detail_threshold": BODY_DETAIL_THRESHOLD,
            "original_output_sha256": spec.original_output_sha256,
            "z11_output_sha256": spec.z11_output_sha256,
            "z11_rgb_sha256": spec.z11_rgb_sha256,
            "interior_rgb_sha256": spec.interior_rgb_sha256,
            "wrapped_rgb_sha256": contract["wrapped_rgb_sha256"],
            "weight_curve": WRAP_WEIGHT_CURVE,
            "rounding": WRAP_ROUNDING,
            "lap_world_px": contract["lap_world_px"],
            "comparison_texture_rows": contract["comparison_texture_rows"],
            "mean_abs_rgb_delta": contract["mean_abs_rgb_delta"],
            "p95_abs_rgb_delta": contract["p95_abs_rgb_delta"],
            "max_channel_delta": contract["max_channel_delta"],
            "forward_exemplar": contract["forward_exemplar"],
            "x4_lap_metrics": contract["x4_lap_metrics"],
            "world_lap_metrics": contract["world_lap_metrics"],
            "z11_x4_paired": contract["z11_x4_paired"],
            "z11_world_paired": contract["z11_world_paired"],
            "paired_mean_improvement_fraction": (
                contract["paired_mean_improvement_fraction"]
            ),
            "self_similarity": contract["self_similarity"],
            "value_closure": contract["value_closure"],
            "validation_thresholds": contract["validation_thresholds"],
            "bright_gutter_guard": contract["bright_gutter_guard"],
        }
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
    )
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    asset_root = args.repo_root / MAP_SCROLL_RELATIVE
    manifest_path = asset_root / MANIFEST_NAME
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    records = {
        str(record["output"]): record
        for record in manifest.get("assets", [])
        if isinstance(record, dict) and "output" in record
    }
    wrapped_contract_by_name: dict[str, dict[str, object]] = {}
    for spec in BAND_SPECS:
        path = asset_root / spec.output
        pixels = _load_rgb(path)
        record = records.get(spec.output)
        if not isinstance(record, dict):
            raise RuntimeError(f"{spec.output}: manifest record is missing")
        interior_before = _interior_sha256(pixels, spec)
        if interior_before != spec.interior_rgb_sha256:
            raise RuntimeError(
                f"{spec.output}: approved interior hash drifted: {interior_before}"
            )
        z11_base = _mirrored_edge_bleed(pixels, spec)
        _validate_bleed(z11_base, spec)
        _validate_provenance(asset_root, record, pixels, z11_base, spec)
        expected, _raw_exemplar, forward_exemplar = _forward_exemplar_wrap(
            pixels,
            spec,
        )
        expected, bright_gutter_guard = _remove_bright_gutter_runs(expected, spec)
        expected, value_closure = _close_x4_and_world_seam_luma(expected, spec)
        post_closure_phase16 = _phase16_bright_gutter_diagnostic(expected)
        post_closure_cyclic = _cyclic_bright_gutter_diagnostic(expected)
        if post_closure_phase16["runs"] or post_closure_cyclic["runs"]:
            raise RuntimeError(
                f"{spec.output}: value closure introduced a bright gutter: "
                f"phase16={post_closure_phase16['runs']} "
                f"cyclic={post_closure_cyclic['runs']}"
            )
        if _interior_sha256(expected, spec) != interior_before:
            raise RuntimeError(f"{spec.output}: vertical wrap touched interior pixels")
        if args.apply:
            pixels = expected
            if _interior_sha256(pixels, spec) != interior_before:
                raise RuntimeError(f"{spec.output}: vertical wrap touched interior pixels")
            _write_png(path, pixels)
            pixels = _load_rgb(path)
        if not np.array_equal(pixels, expected):
            raise RuntimeError(
                f"{spec.output}: pixels do not match the reproducible vertical wrap"
            )
        x4_metrics = _lap_metrics(pixels, spec, TEXTURE_SCALE)
        world_metrics = _lap_metrics(pixels, spec, 1)
        x4_similarity = _self_similarity(
            pixels,
            spec,
            TEXTURE_SCALE,
            int(forward_exemplar["source_world_row"]),
        )
        world_similarity = _self_similarity(
            pixels,
            spec,
            1,
            int(forward_exemplar["source_world_row"]),
        )
        z11_x4_metrics = _lap_metrics(z11_base, spec, TEXTURE_SCALE)
        z11_world_metrics = _lap_metrics(z11_base, spec, 1)
        _validate_vertical_wrap(
            spec,
            x4_metrics,
            world_metrics,
            x4_similarity,
            world_similarity,
            z11_x4_metrics,
            z11_world_metrics,
        )
        output_sha = _file_sha256(path)
        wrapped_rgb_sha = _rgb_sha256(pixels)
        x4_paired = x4_metrics["paired"]
        x4_improvement = 1.0 - (
            float(x4_paired["mean_abs_rgb_delta"])
            / float(z11_x4_metrics["paired"]["mean_abs_rgb_delta"])
        )
        world_improvement = 1.0 - (
            float(world_metrics["paired"]["mean_abs_rgb_delta"])
            / float(z11_world_metrics["paired"]["mean_abs_rgb_delta"])
        )
        lap_world_px = _lap_world_px(spec)
        wrapped_contract_by_name[spec.output] = {
            "output_sha256": output_sha,
            "wrapped_rgb_sha256": wrapped_rgb_sha,
            "lap_world_px": lap_world_px,
            "comparison_texture_rows": lap_world_px * TEXTURE_SCALE,
            "mean_abs_rgb_delta": x4_paired["mean_abs_rgb_delta"],
            "p95_abs_rgb_delta": x4_paired["p95_abs_rgb_delta"],
            "max_channel_delta": x4_paired["max_channel_delta"],
            "forward_exemplar": forward_exemplar,
            "x4_lap_metrics": x4_metrics,
            "world_lap_metrics": world_metrics,
            "z11_x4_paired": z11_x4_metrics["paired"],
            "z11_world_paired": z11_world_metrics["paired"],
            "paired_mean_improvement_fraction": {
                "x4": x4_improvement,
                "world": world_improvement,
            },
            "self_similarity": {
                "x4": x4_similarity,
                "world": world_similarity,
            },
            "value_closure": value_closure,
            "validation_thresholds": _validation_thresholds(),
            "bright_gutter_guard": bright_gutter_guard,
        }
        print(
            f"{spec.output} top={spec.top_world_px}px "
            f"[{_profile_summary(pixels, spec.top_world_px, False)}] "
            f"bottom={spec.bottom_world_px}px "
            f"[{_profile_summary(pixels, spec.bottom_world_px, True)}] "
            f"lap={lap_world_px}px "
            f"exemplar_world_row={forward_exemplar['source_world_row']} "
            f"x4_pair={x4_paired} "
            f"world_pair={world_metrics['paired']} "
            f"world_seam={world_metrics['seam']} "
            f"world_derivative={world_metrics['derivative']} "
            f"x4_seam_luma_jump="
            f"{x4_metrics['seam_row_mean_luma_jump']:.9f} "
            f"world_seam_luma_jump="
            f"{world_metrics['seam_row_mean_luma_jump']:.9f} "
            f"world_detail_min={world_metrics['minimum_row_detail']:.6f} "
            f"paired_improvement=x4:{x4_improvement:.6f}/"
            f"world:{world_improvement:.6f} "
            f"world_similarity={world_similarity} "
            f"gutter_corrections={bright_gutter_guard['corrections']} "
            f"gutter_max_run={bright_gutter_guard['maximum_run_world_px']} "
            f"interior_sha256={interior_before} "
            f"wrapped_rgb_sha256={wrapped_rgb_sha} output_sha256={output_sha}"
        )

    common_path = asset_root / COMMON_PAPER_NAME
    common = _load_rgb(common_path)
    print(
        f"{COMMON_PAPER_NAME} unchanged output_sha256={_file_sha256(common_path)} "
        f"top=[{_profile_summary(common, 8, False)}] "
        f"bottom=[{_profile_summary(common, 8, True)}]"
    )
    if args.apply:
        _update_manifest(asset_root, wrapped_contract_by_name)
    print("tower_map_band_vertical_wrap: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
