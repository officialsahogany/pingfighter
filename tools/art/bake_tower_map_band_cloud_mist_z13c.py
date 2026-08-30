#!/usr/bin/env python3
"""Bake the approved yeouidu cloud mist into six Tower map band edges.

The input is the exact rejected Z13 art from commit 4739e14ce. Each band keeps
    one fixed, contiguous 279-row RGBA strip plus a pinned 13-world-pixel sampling
margin. Fixed-seed low-frequency fields vary the feather thickness, warp the
pigment centerline, thin one broad interval, and extend the feather only where
the adjacent terrain has dark local detail. The whole 2D field is evaluated at
once: there is no column loop, column equalization, reflection, or synthesized
shared row.

The natural strip row 139 remains the single shared butt row for exact x4 C0.
Only the first and last 35 world pixels are written; rows [140:1140) in the x4
files remain byte-identical to the pinned Z13 base.
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

METHOD = "approved_yeouidu_landform_mist_bake_v3"
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
FIXED_SEED_ROLE = "deterministic_low_frequency_shape_and_literal_table_version"
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

ACTIVE_FEATHER_WORLD_PX = EDGE_WORLD_PX - COVERED_WORLD_PX
ACTIVE_FEATHER_ROWS = ACTIVE_FEATHER_WORLD_PX * TEXTURE_SCALE
NOMINAL_SHAPED_FEATHER_WORLD_PX = 6.25
THICKNESS_VARIATION_RATIO = 0.40
THICKNESS_VARIATION_WORLD_PX = (
    NOMINAL_SHAPED_FEATHER_WORLD_PX * THICKNESS_VARIATION_RATIO
)
MINIMUM_SHAPED_FEATHER_WORLD_PX = (
    NOMINAL_SHAPED_FEATHER_WORLD_PX - THICKNESS_VARIATION_WORLD_PX
)
MAXIMUM_SHAPED_FEATHER_WORLD_PX = (
    NOMINAL_SHAPED_FEATHER_WORLD_PX + THICKNESS_VARIATION_WORLD_PX
)
OUTER_ALPHA_GUARD_WORLD_PX = (
    ACTIVE_FEATHER_WORLD_PX - MAXIMUM_SHAPED_FEATHER_WORLD_PX
)
FEATHER_FADE_START_RATIO = 0.76
MEANDER_AMPLITUDE_WORLD_PX = 12.0
MEANDER_SEAM_RESIDUAL_AMPLITUDE_WORLD_PX = 1.5
MEANDER_MARGIN_WORLD_PX = 13
MEANDER_MARGIN_ROWS = MEANDER_MARGIN_WORLD_PX * TEXTURE_SCALE
PRIMARY_FIELD_CYCLES = 1.0
SECONDARY_FIELD_CYCLES = 2.0
MINIMUM_FIELD_WAVELENGTH_WORLD_PX = WORLD_SIZE[0] / SECONDARY_FIELD_CYCLES
MINIMUM_HORIZONTAL_CONTROL_SPAN_WORLD_PX = 16.0
MINIMUM_VERTICAL_CONTROL_SPAN_WORLD_PX = 8.0
HORIZONTAL_CONTROL_CELLS = int(
    WORLD_SIZE[0] // MINIMUM_HORIZONTAL_CONTROL_SPAN_WORLD_PX
)
HORIZONTAL_CONTROL_HALO_CELLS = 3
EDGE_VERTICAL_CONTROL_CELLS = int(
    EDGE_WORLD_PX // MINIMUM_VERTICAL_CONTROL_SPAN_WORLD_PX
)
THINNING_MINIMUM_WIDTH_RATIO = 0.15
THINNING_MAXIMUM_WIDTH_RATIO = 0.25
THINNING_CALIBRATED_MINIMUM_WIDTH_RATIO = 0.16
THINNING_CALIBRATED_MAXIMUM_WIDTH_RATIO = 0.21
THINNING_MINIMUM_OPACITY_MULTIPLIER = 0.34
THINNING_MAXIMUM_OPACITY_MULTIPLIER = 0.48
THINNING_ACTIVE_WINDOW_THRESHOLD = 0.01
TERRAIN_BITE_DARK_DELTA = 7.0
TERRAIN_BITE_DARK_RANGE = 22.0
TERRAIN_BITE_BLUR_WORLD_PX = 5.0
TERRAIN_BITE_OPACITY_GAIN = 0.46
TERRAIN_BITE_MAXIMUM_DEPTH_WORLD_PX = 1.75
MAXIMUM_TERRAIN_ATTACHMENT_ACTIVE_RATIO = 0.35
TERRAIN_CONTROL_QUANTILE = 0.985
MAXIMUM_TERRAIN_CONTROL_ACTIVE_RATIO = 0.05
TERRAIN_MINIMUM_SELECTED_STRENGTH = 0.55
TERRAIN_MINIMUM_SELECTED_FOOT_SCORE = 0.20
TERRAIN_MINIMUM_SELECTED_DIRECTIONAL_DELTA = 0.05
MINIMUM_THICKNESS_P95_HALF_RANGE_WORLD_PX = 2.10
MINIMUM_MEANDER_P95_HALF_RANGE_WORLD_PX = 9.5
MINIMUM_TERRAIN_ATTACHMENT_MAXIMUM_GAIN = 0.04
MINIMUM_TOP_BOTTOM_PHASE_DELTA_RAD = 0.20
MAXIMUM_THINNING_STRONG_OVERLAP_RATIO = 0.05
MAXIMUM_ACTUAL_APPLIED_THINNING_ABSOLUTE_CORRELATION = 0.20
MINIMUM_COLUMN_INTEGRATED_OPACITY_WORLD_PX = 26.0
MINIMUM_WARP_VERTICAL_JACOBIAN = 0.55
MINIMUM_SHARED_SEAM_P95_HALF_RANGE_WORLD_PX = 1.0
MINIMUM_ACTUAL_FRONT_P95_HALF_RANGE_WORLD_PX = 1.75
MAXIMUM_ACTUAL_FRONT_ABSOLUTE_CORRELATION = 0.90
MAXIMUM_SOURCE_SAMPLING_BIAS_WORLD_PX = 2.0

TERRAIN_BRIDGE_ANCHOR_WORLD_PX = 24
TERRAIN_BRIDGE_ANCHOR_ROWS = TERRAIN_BRIDGE_ANCHOR_WORLD_PX * TEXTURE_SCALE
TERRAIN_BRIDGE_VERTICAL_CONTROL_CELLS = 6
TERRAIN_BRIDGE_REVEAL_MINIMUM_WORLD_PX = 0.5
TERRAIN_BRIDGE_REVEAL_MAXIMUM_WORLD_PX = 1.0
TERRAIN_BRIDGE_MAXIMUM_MIX = 0.94
TERRAIN_BRIDGE_WHOLE_ANCHOR_DETAIL_GAIN = 1.82
TERRAIN_BRIDGE_MAXIMUM_WHOLE_ANCHOR_DETAIL_GAIN = 2.0
TERRAIN_BRIDGE_COMPOSITE_LUMA_BIAS = 18.0
VISIBLE_PIGMENT_NOMINAL_HALF_WIDTH_WORLD_PX = 16.0
VISIBLE_PIGMENT_MAXIMUM_MIX = 0.90
VISIBLE_HAZE_FLOOR = 0.14
VISIBLE_THINNING_FACTOR_EXPONENT = 1.25
VISIBLE_ACTIVE_PROFILE_GATE = 0.60
VISIBLE_THINNING_TERRAIN_DETAIL_GAIN = 0.35
VISIBLE_SHARED_REFERENCE_DETAIL_GAIN = 1.50
VISIBLE_CENTERLINE_TARGET_P95_HALF_RANGE_WORLD_PX = 12.0
VISIBLE_CENTERLINE_MAXIMUM_ABSOLUTE_WORLD_PX = 12.5
VISIBLE_SHAPE_SEAM_TRANSITION_WORLD_PX = 1.25
VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX = 1.25
VISIBLE_EDGE_VEIL_MINIMUM_FACTOR = 0.45
VISIBLE_EDGE_CENTERLINE_DIVERGENCE_WORLD_PX = 1.5
VISIBLE_EDGE_CENTERLINE_MAXIMUM_ABSOLUTE_WORLD_PX = 14.0
VISIBLE_LOCAL_LUMA_MAXIMUM_GAIN = 5.5
VISIBLE_FULL_WIDTH_PALE_LUMA_GAIN = 4.0
VISIBLE_FULL_WIDTH_PALE_COLUMN_RATIO = 0.95
VISIBLE_DETAIL_BLUR_WORLD_PX = 2.0
MINIMUM_VISIBLE_CENTERLINE_P95_HALF_RANGE_WORLD_PX = 9.5
MAXIMUM_VISIBLE_CENTERLINE_ABSOLUTE_WORLD_PX = 15.0
MINIMUM_VISIBLE_CENTERLINE_VALID_RATIO = 0.75
MAXIMUM_FULL_WIDTH_PALE_RUN_WORLD_PX = 1.0
MAXIMUM_CORE_LOCAL_LUMA_P95_GAIN = 6.0
MAXIMUM_CORE_LOCAL_LUMA_GAIN = 12.0
MINIMUM_THINNED_TERRAIN_DETAIL_RATIO = 1.15
MINIMUM_VISIBLE_THINNED_PEAK_INK_MIX = 0.30
MINIMUM_VISIBLE_HAZE_FLOOR = 0.12
MAXIMUM_VISIBLE_EDGE_CENTERLINE_RESIDUAL_ABSOLUTE_CORRELATION = 0.10
MAXIMUM_VISIBLE_EDGE_VEIL_ABSOLUTE_CORRELATION = 0.10
MAXIMUM_VISIBLE_EDGE_VEIL_P05 = 0.50
MINIMUM_VISIBLE_EDGE_VEIL_P95 = 0.95

MINIMUM_VARIANCE_RATIO = 0.80
MAXIMUM_VARIANCE_RATIO = 1.25
MAXIMUM_MIRROR_CORRELATION = 0.12
MAXIMUM_LUMA_DELTA = 5.0
MINIMUM_CORE_OPACITY = 1.0
MAXIMUM_CORE_OPACITY = 1.0
MINIMUM_COVERAGE_THROUGH_26 = 1.0
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
class EdgeShapeSpec:
    edge_name: str
    deterministic_seed: int
    thickness_phase_rad: float
    thickness_secondary_phase_rad: float
    meander_phase_rad: float
    meander_secondary_phase_rad: float
    thinning_center_ratio: float
    thinning_width_ratio: float
    thinning_opacity_multiplier: float
    terrain_phase_rad: float


@dataclass(frozen=True)
class BandSpec:
    output: str
    strip: StripSpec
    base_output_sha256: str
    base_rgb_sha256: str
    immutable_body_rgb_sha256: str
    base_edge_bleed_sha256: str
    source_sampling_bias_world_px: float = 0.0
    terrain_bridge_detail_gain: float = TERRAIN_BRIDGE_WHOLE_ANCHOR_DETAIL_GAIN


BAND_SPECS = (
    BandSpec(
        "human_realm_01_mountain_rev2_x4.png",
        StripSpec(6, 209, 1152, 1.65),
        "c9510f9415f44cef8ae9b90e05d67bfc2be3db345b078bae71b20865706a6db6",
        "b85d9a2b4b2616259b58e2c8eac62644dd45323b2b1c534128fa3223fb0edbdd",
        "eaccd05cb5d630bd17dda27441dd0cf9f30ff47f9fa6f09f3371e404a310bb66",
        "3aadc883b559010d57d69fe80f58452cfba30b738ab7490f3ed135b351c49817",
        terrain_bridge_detail_gain=2.0,
    ),
    BandSpec(
        "human_realm_02_village_rev2_x4.png",
        StripSpec(96, 176, 1088, 1.54),
        "4f0fc3b4703f00074b878a5b07f787f2a4896bff85f397b390f493673dc9ebfd",
        "0001e85e2684fe4b4df03567d689d88f5903318dbaff69050dfb7d2f9ee9b84b",
        "225a824f22ca6ae8ad5ec1f759abce948f6c31323763e3e1026e8bad07a8b20c",
        "138fabe29cf6b86a6e06ea2835058b7ad4f5933a2e666555a24077b96769926a",
    ),
    BandSpec(
        "human_realm_03_river_rev2_x4.png",
        StripSpec(1524, 160, 1024, 1.54),
        "29b1f8123863248b4fde779ddcdede592410d79029725f938136cf5784fa5f9e",
        "d08a28b9559a016f5983fe4bc737ead704ded41a355820ff258209814730a9b9",
        "43df9f91774636208273bc8c7a9a8378b004c14959e26f408b163b823b179ed7",
        "699a0d0d8fd0c164ae7297b9d12e6ec12aafa306b1b7670dea060ab526c99fdf",
        terrain_bridge_detail_gain=2.0,
    ),
    BandSpec(
        "immortal_realm_01_islands_rev2_x4.png",
        StripSpec(0, 200, 928, 1.66),
        "1da86fe656698b27f3bf5afe795d869fe201591776ac2799ab05e80cf1901a09",
        "9b225ca73444e4e7d32f4e49a4fa8d41675a2b38bac42dad4526751121bc3d01",
        "c796c5b7d6819e22af1f5b8880e80650edcccaac66c4faff12cd92019ec54a3e",
        "fdbc01744e4dd6ac00650514d5121f97aea735b03cf9e06ad13014ebb32c70a1",
        terrain_bridge_detail_gain=2.0,
    ),
    BandSpec(
        "immortal_realm_02_cloud_cranes_rev2_x4.png",
        StripSpec(102, 235, 1024, 1.44),
        "2f5ed583ee8231a7046f194e9c5089cd84feb5dbff63a9eab443d0a031af83ab",
        "88d3bb57fde05c21ce6f744ac18d229e2626beec92a846ee1ce043e4c3511952",
        "b2e31dfa59b80f3a8e176179d190fe3856af5cd764b519784353a911410336f4",
        "ed5b4cc94363076804320e68184fc25ee5bee4909756f6fcc584a9a98fc77cc6",
        -2.0,
    ),
    BandSpec(
        "immortal_realm_03_pavilions_rev2_x4.png",
        StripSpec(650, 193, 1024, 1.54),
        "72bfd1e06958bfb1c8b073add85fa7ee62185f9955300121c2ac6ea93444cfe5",
        "44275fbc05944fbb4e8efa8fe1668dfa59b0dd4d93ffb876faa95214a3eaf9d9",
        "c9f83853ebf3b9c6a6b5dbcf034f7f00527b891c2ea7dae562b9378c7e1c239e",
        "9bcbf407d9982b2a917032cc6fe0e3d5b314a61c3b15a036574f7f7c4efc897d",
        terrain_bridge_detail_gain=2.0,
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
                "source_sampling_bias_world_px": spec.source_sampling_bias_world_px,
            }
            for spec in BAND_SPECS
        ],
    }


def validate_strip_table() -> None:
    edge_rects: set[tuple[int, int, int, int]] = set()
    for spec in BAND_SPECS:
        strip = spec.strip
        source_sampling_bias_rows = int(
            round(spec.source_sampling_bias_world_px * TEXTURE_SCALE)
        )
        if not np.isclose(
            source_sampling_bias_rows / TEXTURE_SCALE,
            spec.source_sampling_bias_world_px,
        ):
            raise RuntimeError(f"{spec.output}: source sampling bias left x4 lattice")
        rect = (strip.x, strip.y, strip.width, STRIP_HEIGHT)
        if strip.x < 0 or strip.y < 0:
            raise RuntimeError(f"{spec.output}: negative mist strip origin")
        if strip.x + strip.width > SOURCE_SIZE[0] or strip.y + STRIP_HEIGHT > SOURCE_SIZE[1]:
            raise RuntimeError(f"{spec.output}: mist strip escaped approved source")
        if (
            strip.y + source_sampling_bias_rows - MEANDER_MARGIN_ROWS < 0
            or strip.y
            + source_sampling_bias_rows
            + STRIP_HEIGHT
            + MEANDER_MARGIN_ROWS
            > SOURCE_SIZE[1]
        ):
            raise RuntimeError(f"{spec.output}: mist meander margin escaped approved source")
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


def circular_phase_delta(first: float, second: float) -> float:
    return abs((first - second + np.pi) % (2.0 * np.pi) - np.pi)


def deterministic_shape_words(output: str, edge_name: str) -> tuple[int, np.ndarray]:
    digest = hashlib.sha512(
        f"{FIXED_SEED:08x}|{output}|{edge_name}|z13e".encode("utf-8")
    ).digest()
    words = np.frombuffer(digest, dtype=">u4")
    units = words.astype(np.float64) / float(2**32)
    return int(words[0]), units


def edge_shape_specs(output: str) -> dict[str, EdgeShapeSpec]:
    _band_seed, band = deterministic_shape_words(output, "band")
    top_seed, top = deterministic_shape_words(output, "top")
    bottom_seed, bottom = deterministic_shape_words(output, "bottom")
    top_thickness_phase = float(2.0 * np.pi * band[1])
    top_thickness_secondary_phase = float(2.0 * np.pi * top[2])
    top_meander_phase = float(2.0 * np.pi * band[3])
    top_meander_secondary_phase = float(2.0 * np.pi * top[4])
    bottom_meander_phase = float(
        (top_meander_phase + np.pi * (0.60 + 0.20 * bottom[3]))
        % (2.0 * np.pi)
    )
    bottom_meander_secondary_phase = float(
        (
            top_meander_secondary_phase
            + np.pi * (0.55 + 0.25 * bottom[4])
        )
        % (2.0 * np.pi)
    )
    visible_primary_phase = circular_phase_midpoint(
        top_meander_phase,
        bottom_meander_phase,
    )
    top_thinning_center = float(
        (
            0.25
            - visible_primary_phase / (2.0 * np.pi)
            + 0.02 * (top[5] - 0.5)
        )
        % 1.0
    )
    bottom_thinning_center = float(
        (
            0.75
            - visible_primary_phase / (2.0 * np.pi)
            + 0.02 * (bottom[5] - 0.5)
        )
        % 1.0
    )
    return {
        "top": EdgeShapeSpec(
            edge_name="top",
            deterministic_seed=top_seed,
            thickness_phase_rad=top_thickness_phase,
            thickness_secondary_phase_rad=top_thickness_secondary_phase,
            meander_phase_rad=top_meander_phase,
            meander_secondary_phase_rad=top_meander_secondary_phase,
            thinning_center_ratio=top_thinning_center,
            thinning_width_ratio=float(
                THINNING_CALIBRATED_MINIMUM_WIDTH_RATIO
                + (
                    THINNING_CALIBRATED_MAXIMUM_WIDTH_RATIO
                    - THINNING_CALIBRATED_MINIMUM_WIDTH_RATIO
                )
                * top[6]
            ),
            thinning_opacity_multiplier=float(
                THINNING_MINIMUM_OPACITY_MULTIPLIER
                + (
                    THINNING_MAXIMUM_OPACITY_MULTIPLIER
                    - THINNING_MINIMUM_OPACITY_MULTIPLIER
                )
                * top[7]
            ),
            terrain_phase_rad=float(2.0 * np.pi * top[8]),
        ),
        "bottom": EdgeShapeSpec(
            edge_name="bottom",
            deterministic_seed=bottom_seed,
            thickness_phase_rad=float(
                (
                    top_thickness_phase
                    + np.pi * (0.60 + 0.20 * bottom[1])
                )
                % (2.0 * np.pi)
            ),
            thickness_secondary_phase_rad=float(
                (
                    top_thickness_secondary_phase
                    + np.pi * (0.55 + 0.25 * bottom[2])
                )
                % (2.0 * np.pi)
            ),
            meander_phase_rad=bottom_meander_phase,
            meander_secondary_phase_rad=bottom_meander_secondary_phase,
            thinning_center_ratio=bottom_thinning_center,
            thinning_width_ratio=float(
                THINNING_CALIBRATED_MINIMUM_WIDTH_RATIO
                + (
                    THINNING_CALIBRATED_MAXIMUM_WIDTH_RATIO
                    - THINNING_CALIBRATED_MINIMUM_WIDTH_RATIO
                )
                * bottom[6]
            ),
            thinning_opacity_multiplier=float(
                THINNING_MINIMUM_OPACITY_MULTIPLIER
                + (
                    THINNING_MAXIMUM_OPACITY_MULTIPLIER
                    - THINNING_MINIMUM_OPACITY_MULTIPLIER
                )
                * bottom[7]
            ),
            terrain_phase_rad=float(2.0 * np.pi * bottom[8]),
        ),
    }


def edge_shape_payload(shape: EdgeShapeSpec) -> dict[str, object]:
    return {
        "deterministic_seed": shape.deterministic_seed,
        "thickness_phase_rad": float(round(shape.thickness_phase_rad, 12)),
        "thickness_secondary_phase_rad": float(
            round(shape.thickness_secondary_phase_rad, 12)
        ),
        "meander_phase_rad": float(round(shape.meander_phase_rad, 12)),
        "meander_secondary_phase_rad": float(
            round(shape.meander_secondary_phase_rad, 12)
        ),
        "thinning_center_ratio": float(round(shape.thinning_center_ratio, 12)),
        "thinning_width_ratio": float(round(shape.thinning_width_ratio, 12)),
        "thinning_opacity_multiplier": float(
            round(shape.thinning_opacity_multiplier, 12)
        ),
        "terrain_phase_rad": float(round(shape.terrain_phase_rad, 12)),
    }


def shape_table_payload() -> dict[str, object]:
    return {
        "fixed_seed": FIXED_SEED,
        "fixed_seed_role": FIXED_SEED_ROLE,
        "bands": [
            {
                "output": spec.output,
                "source_sampling_bias_world_px": spec.source_sampling_bias_world_px,
                "terrain_bridge_detail_gain": spec.terrain_bridge_detail_gain,
                "edges": {
                    edge_name: edge_shape_payload(shape)
                    for edge_name, shape in edge_shape_specs(spec.output).items()
                },
            }
            for spec in BAND_SPECS
        ],
    }


def validate_shape_table() -> None:
    seeds: set[int] = set()
    signatures: set[str] = set()
    for spec in BAND_SPECS:
        if abs(spec.source_sampling_bias_world_px) > MAXIMUM_SOURCE_SAMPLING_BIAS_WORLD_PX:
            raise RuntimeError(f"{spec.output}: source sampling bias escaped safe margin")
        if not (
            TERRAIN_BRIDGE_WHOLE_ANCHOR_DETAIL_GAIN
            <= spec.terrain_bridge_detail_gain
            <= TERRAIN_BRIDGE_MAXIMUM_WHOLE_ANCHOR_DETAIL_GAIN
        ):
            raise RuntimeError(
                f"{spec.output}: terrain bridge detail gain escaped fixed bounds"
            )
        shapes = edge_shape_specs(spec.output)
        if (
            circular_phase_delta(
                shapes["top"].thickness_phase_rad,
                shapes["bottom"].thickness_phase_rad,
            )
            < MINIMUM_TOP_BOTTOM_PHASE_DELTA_RAD
            or circular_phase_delta(
                shapes["top"].meander_phase_rad,
                shapes["bottom"].meander_phase_rad,
            )
            < MINIMUM_TOP_BOTTOM_PHASE_DELTA_RAD
        ):
            raise RuntimeError(f"{spec.output}: top/bottom shape phases converged")
        for shape in shapes.values():
            if not (
                THINNING_MINIMUM_WIDTH_RATIO
                <= shape.thinning_width_ratio
                <= THINNING_MAXIMUM_WIDTH_RATIO
            ):
                raise RuntimeError(f"{spec.output}: thinning width escaped contract")
            if not (
                THINNING_MINIMUM_OPACITY_MULTIPLIER
                <= shape.thinning_opacity_multiplier
                <= THINNING_MAXIMUM_OPACITY_MULTIPLIER
            ):
                raise RuntimeError(f"{spec.output}: thinning opacity escaped contract")
            seeds.add(shape.deterministic_seed)
            signatures.add(canonical_json_sha256(edge_shape_payload(shape)))
    expected_edges = len(BAND_SPECS) * 2
    if len(seeds) != expected_edges or len(signatures) != expected_edges:
        raise RuntimeError("fixed seed must produce 12 unique band-edge shape signatures")


def horizontal_control_nodes_texture_px() -> np.ndarray:
    return np.rint(
        np.linspace(0.0, DESTINATION_WIDTH, HORIZONTAL_CONTROL_CELLS + 1)
    ).astype(np.int64)


def normalize_signed_field(field: np.ndarray) -> np.ndarray:
    centered = field.astype(np.float64) - float(field.mean())
    positive_scale = max(float(centered.max()), 1.0e-12)
    negative_scale = max(abs(float(centered.min())), 1.0e-12)
    return np.where(
        centered >= 0.0,
        centered / positive_scale,
        centered / negative_scale,
    )


def periodic_control_field(
    primary_phase_rad: float,
    secondary_phase_rad: float,
) -> np.ndarray:
    horizontal_phase = horizontal_control_nodes_texture_px().astype(np.float64) * (
        2.0 * np.pi / DESTINATION_WIDTH
    )
    field = (
        0.78 * np.sin(PRIMARY_FIELD_CYCLES * horizontal_phase + primary_phase_rad)
        + 0.22
        * np.sin(SECONDARY_FIELD_CYCLES * horizontal_phase + secondary_phase_rad)
    )
    return normalize_signed_field(field)


def expand_horizontal_control_field(control_values: np.ndarray) -> np.ndarray:
    if control_values.shape != (HORIZONTAL_CONTROL_CELLS + 1,):
        raise RuntimeError("horizontal macro field escaped its fixed control lattice")
    periodic_core = control_values[:-1]
    halo = HORIZONTAL_CONTROL_HALO_CELLS
    wrapped_control = np.concatenate(
        (periodic_core[-halo:], periodic_core, periodic_core[:halo])
    )
    control_plane = np.stack(
        (wrapped_control, wrapped_control, wrapped_control, wrapped_control),
        axis=0,
    )
    halo_texture_px = int(round(halo * DESTINATION_WIDTH / HORIZONTAL_CONTROL_CELLS))
    expanded_width = DESTINATION_WIDTH + halo_texture_px * 2
    expanded = np.asarray(
        Image.fromarray(control_plane.astype(np.float32)).resize(
            (expanded_width, control_plane.shape[0]),
            Image.Resampling.BICUBIC,
        ),
        dtype=np.float64,
    )
    return expanded[:, halo_texture_px : halo_texture_px + DESTINATION_WIDTH].mean(
        axis=0
    )


def periodic_low_frequency_field(
    primary_phase_rad: float,
    secondary_phase_rad: float,
) -> np.ndarray:
    expanded = expand_horizontal_control_field(
        periodic_control_field(primary_phase_rad, secondary_phase_rad)
    )
    return normalize_signed_field(expanded)


def periodic_thinning_window(shape: EdgeShapeSpec) -> np.ndarray:
    horizontal_ratio = (
        horizontal_control_nodes_texture_px().astype(np.float64) / DESTINATION_WIDTH
    )
    distance = np.abs(horizontal_ratio - shape.thinning_center_ratio)
    wrapped_distance = np.minimum(distance, 1.0 - distance)
    normalized = wrapped_distance / max(shape.thinning_width_ratio * 0.5, 1.0e-12)
    control_window = np.where(
        normalized < 1.0,
        0.5 + 0.5 * np.cos(np.pi * normalized),
        0.0,
    )
    return np.clip(expand_horizontal_control_field(control_window), 0.0, 1.0)


def field_percentile_metrics(field_world_px: np.ndarray) -> dict[str, float]:
    p05, p95 = np.percentile(field_world_px, (5.0, 95.0))
    return {
        "p05_world_px": float(p05),
        "p95_world_px": float(p95),
        "p95_half_range_world_px": float((p95 - p05) * 0.5),
        "maximum_absolute_world_px": float(np.abs(field_world_px).max()),
        "absolute_mean_world_px": float(np.abs(field_world_px).mean()),
    }


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


def circular_phase_midpoint(first: float, second: float) -> float:
    return float(
        np.arctan2(
            np.sin(first) + np.sin(second),
            np.cos(first) + np.cos(second),
        )
    )


def terrain_bridge_from_immutable_body(
    base: np.ndarray,
    whole_anchor_detail_gain: float,
) -> tuple[np.ndarray, dict[str, object]]:
    bottom_anchor = base[
        -EDGE_ROWS - TERRAIN_BRIDGE_ANCHOR_ROWS : -EDGE_ROWS
    ]
    top_anchor = base[
        EDGE_ROWS : EDGE_ROWS + TERRAIN_BRIDGE_ANCHOR_ROWS
    ]
    expected_anchor_shape = (
        TERRAIN_BRIDGE_ANCHOR_ROWS,
        DESTINATION_WIDTH,
        3,
    )
    if (
        bottom_anchor.shape != expected_anchor_shape
        or top_anchor.shape != expected_anchor_shape
    ):
        raise RuntimeError("immutable terrain bridge anchor escaped its fixed bounds")

    def rasterize(anchor: np.ndarray) -> np.ndarray:
        coarse = Image.fromarray(anchor).resize(
            (
                HORIZONTAL_CONTROL_CELLS,
                TERRAIN_BRIDGE_VERTICAL_CONTROL_CELLS,
            ),
            Image.Resampling.BOX,
        )
        coarse_bridge = np.asarray(
            coarse.resize(
                (DESTINATION_WIDTH, EDGE_ROWS),
                Image.Resampling.BICUBIC,
            ),
            dtype=np.float64,
        )
        whole_anchor = Image.fromarray(anchor).resize(
            (DESTINATION_WIDTH, EDGE_ROWS),
            Image.Resampling.BICUBIC,
        )
        whole_anchor_pixels = np.asarray(whole_anchor, dtype=np.float64)
        whole_anchor_low_pass = np.asarray(
            whole_anchor.filter(
                ImageFilter.GaussianBlur(
                    VISIBLE_DETAIL_BLUR_WORLD_PX * TEXTURE_SCALE
                )
            ),
            dtype=np.float64,
        )
        return np.clip(
            coarse_bridge
            + (
                whole_anchor_pixels - whole_anchor_low_pass
            )
            * whole_anchor_detail_gain,
            0.0,
            255.0,
        )

    bridge = np.concatenate(
        (rasterize(bottom_anchor), rasterize(top_anchor)),
        axis=0,
    )
    literal_target_body_luma = float(luma(base[EDGE_ROWS:-EDGE_ROWS]).mean())
    target_body_luma = (
        literal_target_body_luma + TERRAIN_BRIDGE_COMPOSITE_LUMA_BIAS
    )
    edge_luma_calibration: dict[str, object] = {}
    for edge_name, edge_slice in (
        ("bottom", slice(0, EDGE_ROWS)),
        ("top", slice(EDGE_ROWS, EDGE_ROWS * 2)),
    ):
        source_mean = float(luma(bridge[edge_slice]).mean())
        rgb_offset = target_body_luma - source_mean
        bridge[edge_slice] = np.clip(
            bridge[edge_slice] + rgb_offset,
            0.0,
            255.0,
        )
        edge_luma_calibration[edge_name] = {
            "source_mean_luma": source_mean,
            "literal_target_body_mean_luma": literal_target_body_luma,
            "target_body_mean_luma": target_body_luma,
            "whole_edge_rgb_offset": rgb_offset,
            "calibrated_mean_luma": float(luma(bridge[edge_slice]).mean()),
        }
    return bridge, edge_luma_calibration


def scalar_low_pass(field: np.ndarray) -> np.ndarray:
    clipped = np.clip(field, 0.0, 255.0).astype(np.uint8)
    return np.asarray(
        Image.fromarray(clipped).filter(
            ImageFilter.GaussianBlur(VISIBLE_DETAIL_BLUR_WORLD_PX * TEXTURE_SCALE)
        ),
        dtype=np.float64,
    )


def maximum_true_run(flags: np.ndarray) -> int:
    if flags.ndim != 1:
        raise RuntimeError("visible pale-run gate expected one row flag vector")
    padded = np.concatenate(
        (
            np.zeros(1, dtype=np.bool_),
            flags.astype(np.bool_),
            np.zeros(1, dtype=np.bool_),
        )
    )
    transitions = np.flatnonzero(padded[1:] != padded[:-1])
    run_lengths = transitions[1::2] - transitions[::2]
    return int(run_lengths.max(initial=0))


def crop_strip(
    source: np.ndarray,
    strip: StripSpec,
    source_sampling_bias_world_px: float,
) -> tuple[np.ndarray, np.ndarray, dict[str, object]]:
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
    source_sampling_bias_rows = int(
        round(source_sampling_bias_world_px * TEXTURE_SCALE)
    )
    if not np.isclose(
        source_sampling_bias_rows / TEXTURE_SCALE,
        source_sampling_bias_world_px,
    ):
        raise RuntimeError("source sampling bias must align to the x4 lattice")
    extended_source_y = (
        strip.y - MEANDER_MARGIN_ROWS + source_sampling_bias_rows
    )
    effective_source_y = strip.y + source_sampling_bias_rows
    effective_crop = np.ascontiguousarray(
        source[
            effective_source_y : effective_source_y + STRIP_HEIGHT,
            strip.x : strip.x + strip.width,
        ]
    )
    if effective_crop.shape != (STRIP_HEIGHT, strip.width, 4):
        raise RuntimeError(f"mist effective center escaped approved source: {strip}")
    extended_crop = np.ascontiguousarray(
        source[
            extended_source_y : extended_source_y
            + STRIP_HEIGHT
            + MEANDER_MARGIN_ROWS * 2,
            strip.x : strip.x + strip.width,
        ]
    )
    expected_extended_height = STRIP_HEIGHT + MEANDER_MARGIN_ROWS * 2
    if extended_crop.shape != (expected_extended_height, strip.width, 4):
        raise RuntimeError(f"mist meander source escaped approved source: {strip}")
    extended_resized = Image.fromarray(extended_crop).resize(
        (DESTINATION_WIDTH, expected_extended_height),
        Image.Resampling.LANCZOS,
    )
    extended_blurred = extended_resized.filter(
        ImageFilter.GaussianBlur(GAUSSIAN_BLUR_TEXTURE_PX)
    )
    extended_patch = np.asarray(extended_blurred, dtype=np.uint8).copy()
    bottom_crop = np.ascontiguousarray(crop[:EDGE_PATCH_HEIGHT])
    top_crop = np.ascontiguousarray(crop[EDGE_PATCH_HEIGHT - 1 :])
    return patch, extended_patch, {
        "selection_method": "fixed_seed_literal_strip_with_margin_macro_warp_v3",
        "rect": [strip.x, strip.y, strip.width, STRIP_HEIGHT],
        "horizontal_scale": horizontal_scale,
        "vertical_scale": 1.0,
        "detail_gain": strip.detail_gain,
        "crop_rgba_sha256": sha256_bytes(crop.tobytes()),
        "approved_source_alpha_weighted_luma_std": alpha_weighted_luma_std(crop),
        "resized_blurred_rgba_sha256": sha256_bytes(patch.tobytes()),
        "meander_source": {
            "rect": [
                strip.x,
                extended_source_y,
                strip.width,
                expected_extended_height,
            ],
            "margin_world_px": MEANDER_MARGIN_WORLD_PX,
            "source_sampling_bias_world_px": source_sampling_bias_world_px,
            "source_sampling_bias_texture_px": source_sampling_bias_rows,
            "effective_center_rect": [
                strip.x,
                effective_source_y,
                strip.width,
                STRIP_HEIGHT,
            ],
            "effective_center_crop_rgba_sha256": sha256_bytes(
                effective_crop.tobytes()
            ),
            "effective_center_alpha_weighted_luma_std": (
                alpha_weighted_luma_std(effective_crop)
            ),
            "crop_rgba_sha256": sha256_bytes(extended_crop.tobytes()),
            "resized_blurred_rgba_sha256": sha256_bytes(extended_patch.tobytes()),
        },
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


def warp_pigment_strip(
    extended_patch: np.ndarray,
    shapes: dict[str, EdgeShapeSpec],
    meander_amplitude_world_px: float = MEANDER_AMPLITUDE_WORLD_PX,
) -> tuple[np.ndarray, dict[str, object]]:
    edge_control_fields_world_px = {
        edge_name: meander_amplitude_world_px
        * periodic_control_field(
            shape.meander_phase_rad,
            shape.meander_secondary_phase_rad,
        )
        for edge_name, shape in shapes.items()
    }
    seam_primary_phase = circular_phase_midpoint(
        shapes["bottom"].meander_phase_rad,
        shapes["top"].meander_phase_rad,
    )
    seam_secondary_phase = circular_phase_midpoint(
        shapes["bottom"].meander_secondary_phase_rad,
        shapes["top"].meander_secondary_phase_rad,
    )
    seam_residual_amplitude = (
        MEANDER_SEAM_RESIDUAL_AMPLITUDE_WORLD_PX
        * meander_amplitude_world_px
        / max(MEANDER_AMPLITUDE_WORLD_PX, 1.0e-12)
    )
    seam_residual_control = seam_residual_amplitude * periodic_control_field(
        seam_primary_phase + np.pi * 0.38196601125,
        seam_secondary_phase + np.pi * 0.61803398875,
    )
    seam_control_field_world_px = np.clip(
        0.5
        * (
            edge_control_fields_world_px["bottom"]
            + edge_control_fields_world_px["top"]
        )
        + seam_residual_control,
        -meander_amplitude_world_px,
        meander_amplitude_world_px,
    )
    bottom_vertical_nodes = np.rint(
        np.linspace(
            0.0,
            EDGE_PATCH_HEIGHT - 1,
            EDGE_VERTICAL_CONTROL_CELLS + 1,
        )
    ).astype(np.int64)
    top_vertical_nodes = np.rint(
        np.linspace(
            EDGE_PATCH_HEIGHT - 1,
            STRIP_HEIGHT,
            EDGE_VERTICAL_CONTROL_CELLS + 1,
        )
    ).astype(np.int64)
    vertical_nodes = np.concatenate((bottom_vertical_nodes, top_vertical_nodes[1:]))
    displacement_control_rows: list[np.ndarray] = []
    for control_y in vertical_nodes:
        if control_y <= EDGE_PATCH_HEIGHT - 1:
            blend = control_y / (EDGE_PATCH_HEIGHT - 1)
            displacement_world_px = (
                (1.0 - blend) * edge_control_fields_world_px["bottom"]
                + blend * seam_control_field_world_px
            )
        else:
            blend = (control_y - (EDGE_PATCH_HEIGHT - 1)) / EDGE_PATCH_HEIGHT
            displacement_world_px = (
                (1.0 - blend) * seam_control_field_world_px
                + blend * edge_control_fields_world_px["top"]
            )
        displacement_control_rows.append(TEXTURE_SCALE * displacement_world_px)
    displacement_control = np.stack(displacement_control_rows, axis=0)
    source_y_control = (
        MEANDER_MARGIN_ROWS
        + vertical_nodes.astype(np.float64)[:, None]
        + displacement_control
    )
    destination_vertical_spans = np.diff(vertical_nodes).astype(np.float64)
    vertical_jacobian = np.diff(source_y_control, axis=0) / destination_vertical_spans[:, None]
    minimum_vertical_jacobian = float(vertical_jacobian.min())
    if minimum_vertical_jacobian < MINIMUM_WARP_VERTICAL_JACOBIAN:
        raise RuntimeError(
            "pigment meander folded its source mesh: "
            f"{minimum_vertical_jacobian} < {MINIMUM_WARP_VERTICAL_JACOBIAN}"
        )
    if source_y_control.min() < 2.0 or source_y_control.max() > extended_patch.shape[0] - 3.0:
        raise RuntimeError("pigment meander escaped its fixed source margin")
    horizontal_nodes = horizontal_control_nodes_texture_px()
    # Pillow's inverse MESH coordinates use the full output edge as the
    # identity endpoint.  Scaling this to W - 1 compresses the strip and drops
    # information from the final macro cell even when meander is disabled.
    source_x_nodes = horizontal_nodes.astype(np.float64)
    mesh: list[tuple[tuple[int, int, int, int], tuple[float, ...]]] = []
    for control_y_index in range(len(vertical_nodes) - 1):
        y0 = int(vertical_nodes[control_y_index])
        y1 = int(vertical_nodes[control_y_index + 1])
        for control_x_index in range(len(horizontal_nodes) - 1):
            x0 = int(horizontal_nodes[control_x_index])
            x1 = int(horizontal_nodes[control_x_index + 1])
            source_x0 = float(source_x_nodes[control_x_index])
            source_x1 = float(source_x_nodes[control_x_index + 1])
            mesh.append(
                (
                    (x0, y0, x1, y1),
                    (
                        source_x0,
                        float(source_y_control[control_y_index, control_x_index]),
                        source_x0,
                        float(source_y_control[control_y_index + 1, control_x_index]),
                        source_x1,
                        float(source_y_control[control_y_index + 1, control_x_index + 1]),
                        source_x1,
                        float(source_y_control[control_y_index, control_x_index + 1]),
                    ),
                )
            )
    warped = np.asarray(
        Image.fromarray(extended_patch).transform(
            (DESTINATION_WIDTH, STRIP_HEIGHT),
            Image.Transform.MESH,
            mesh,
            resample=Image.Resampling.BICUBIC,
        ),
        dtype=np.uint8,
    ).copy()
    edge_metrics: dict[str, object] = {}
    for edge_name, control_field_world_px in edge_control_fields_world_px.items():
        field_world_px = expand_horizontal_control_field(control_field_world_px)
        percentiles = field_percentile_metrics(field_world_px)
        edge_metrics[edge_name] = {
            "meander_p05_world_px": percentiles["p05_world_px"],
            "meander_p95_world_px": percentiles["p95_world_px"],
            "meander_p95_half_range_world_px": percentiles[
                "p95_half_range_world_px"
            ],
            "meander_maximum_absolute_world_px": percentiles[
                "maximum_absolute_world_px"
            ],
            "meander_absolute_mean_world_px": percentiles[
                "absolute_mean_world_px"
            ],
        }
    seam_field_world_px = expand_horizontal_control_field(seam_control_field_world_px)
    seam_percentiles = field_percentile_metrics(seam_field_world_px)
    minimum_horizontal_span_texture_px = int(np.diff(horizontal_nodes).min())
    minimum_vertical_span_texture_px = int(np.diff(vertical_nodes).min())
    return np.ascontiguousarray(warped), {
        "method": "coarse_16x8_world_px_pillow_mesh_shared_row_v2",
        "margin_world_px": MEANDER_MARGIN_WORLD_PX,
        "horizontal_control_cells": HORIZONTAL_CONTROL_CELLS,
        "vertical_control_cells": len(vertical_nodes) - 1,
        "minimum_horizontal_control_span_texture_px": minimum_horizontal_span_texture_px,
        "minimum_vertical_control_span_texture_px": minimum_vertical_span_texture_px,
        "shared_logical_row": EDGE_PATCH_HEIGHT - 1,
        "shared_seam_primary_phase_rad": seam_primary_phase,
        "shared_seam_secondary_phase_rad": seam_secondary_phase,
        "shared_seam_residual_amplitude_world_px": seam_residual_amplitude,
        "source_y_control_minimum_texture_px": float(source_y_control.min()),
        "source_y_control_maximum_texture_px": float(source_y_control.max()),
        "sampling_offset_sign": "positive_source_y_moves_visible_pigment_upward",
        "shared_row_displacement_p95_half_range_world_px": seam_percentiles[
            "p95_half_range_world_px"
        ],
        "shared_row_displacement_maximum_absolute_world_px": seam_percentiles[
            "maximum_absolute_world_px"
        ],
        "minimum_vertical_jacobian": minimum_vertical_jacobian,
        "one_pixel_column_operations": False,
        "per_column_adjustment": False,
        "warped_rgba_sha256": sha256_bytes(np.ascontiguousarray(warped).tobytes()),
        "edges": edge_metrics,
    }


def terrain_attachment_support(
    base_edge: np.ndarray,
    shape: EdgeShapeSpec,
    thinning_window: np.ndarray,
    thickness_world_px: np.ndarray,
    top_edge: bool,
) -> tuple[np.ndarray, dict[str, object]]:
    base_luma = luma(base_edge)
    blurred_luma = np.asarray(
        Image.fromarray(np.rint(base_luma).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(TERRAIN_BITE_BLUR_WORLD_PX * TEXTURE_SCALE)
        ),
        dtype=np.float64,
    )
    dark_detail = blurred_luma - base_luma
    salience = smootherstep(
        (dark_detail - TERRAIN_BITE_DARK_DELTA) / TERRAIN_BITE_DARK_RANGE
    )
    coarse_rows = EDGE_VERTICAL_CONTROL_CELLS
    coarse_salience = np.asarray(
        Image.fromarray(salience.astype(np.float32)).resize(
            (HORIZONTAL_CONTROL_CELLS, coarse_rows),
            Image.Resampling.BOX,
        ),
        dtype=np.float64,
    )
    # Terrain attachment may only be selected at the mist/land contact zone.
    # Ranking all four coarse rows lets strong detail in the guaranteed core
    # steal the sparse candidate, which produces a plausible number but no
    # visible edge bite.  Top contacts occupy the final coarse row; bottom
    # contacts occupy the first.  The adjacent row points back toward the mist
    # core and supplies a directional lower-foot comparison.
    eligible_row = coarse_rows - 1 if top_edge else 0
    adjacent_row = eligible_row - 1 if top_edge else eligible_row + 1
    eligible_salience = coarse_salience[eligible_row]
    adjacent_salience = coarse_salience[adjacent_row]
    foot_score = eligible_salience * (
        0.65
        + 0.35
        * smootherstep((eligible_salience - adjacent_salience) / 0.15)
    )
    directional_role = (
        "outer_feather_lower_foot_toward_inward_positive_y"
        if top_edge
        else "outer_feather_lower_foot_toward_inward_negative_y"
    )
    coarse_thickness = np.asarray(
        Image.fromarray(thickness_world_px[None, :].astype(np.float32)).resize(
            (HORIZONTAL_CONTROL_CELLS, 1),
            Image.Resampling.BOX,
        ),
        dtype=np.float64,
    )[0]
    available_depth_ratio = np.clip(
        (MAXIMUM_SHAPED_FEATHER_WORLD_PX - coarse_thickness)
        / TERRAIN_BITE_MAXIMUM_DEPTH_WORLD_PX,
        0.0,
        1.0,
    )
    selection_score = foot_score * (
        0.35 + 0.65 * smootherstep(available_depth_ratio)
    )
    maximum_active_cells = max(
        1,
        int(np.ceil(foot_score.size * (1.0 - TERRAIN_CONTROL_QUANTILE))),
    )
    ranked_cells = np.argsort(-selection_score, kind="stable")
    selected_cells = ranked_cells[:maximum_active_cells]
    sparse_control = np.zeros_like(coarse_salience)
    positive_selected = selected_cells[foot_score[selected_cells] > 1.0e-6]
    selected_strength = (
        0.55
        + 0.45
        * smootherstep(np.clip(foot_score[positive_selected] / 0.45, 0.0, 1.0))
    )
    sparse_control[eligible_row, positive_selected] = selected_strength
    selected_directional_delta = (
        eligible_salience[positive_selected] - adjacent_salience[positive_selected]
    )
    softened = np.asarray(
        Image.fromarray(sparse_control.astype(np.float32)).resize(
            (DESTINATION_WIDTH, EDGE_PATCH_HEIGHT),
            Image.Resampling.BICUBIC,
        ),
        dtype=np.float64,
    )
    softened = np.clip(softened, 0.0, 1.0)
    eligible_distance_rows = np.linspace(
        0.0,
        EDGE_PATCH_HEIGHT - 1,
        EDGE_PATCH_HEIGHT,
        dtype=np.float64,
    )
    if not top_edge:
        eligible_distance_rows = EDGE_PATCH_HEIGHT - 1 - eligible_distance_rows
    eligible_distance_world_px = eligible_distance_rows / TEXTURE_SCALE
    outer_feather_support = (
        (eligible_distance_world_px > COVERED_WORLD_PX)
        & (eligible_distance_world_px < EDGE_WORLD_PX - OUTER_ALPHA_GUARD_WORLD_PX)
    ).astype(np.float64)
    terrain_envelope = 0.76 + 0.24 * periodic_low_frequency_field(
        shape.terrain_phase_rad,
        shape.terrain_phase_rad + np.pi * 0.61803398875,
    )
    support = np.clip(
        softened
        * terrain_envelope[None, :]
        * (1.0 - 0.5 * thinning_window[None, :])
        * outer_feather_support[:, None],
        0.0,
        1.0,
    )
    horizontal_active_ratio = float(
        np.mean(np.max(support, axis=0) > 0.01)
    )
    return support, {
        "directional_role": directional_role,
        "control_cells": int(foot_score.size),
        "active_control_cells": int(positive_selected.size),
        "control_active_ratio": float(positive_selected.size / foot_score.size),
        "horizontal_active_ratio": horizontal_active_ratio,
        "eligible_control_row": eligible_row,
        "selected_control_cells": [
            [eligible_row, int(control_x)] for control_x in positive_selected
        ],
        "selected_raw_foot_scores": [
            float(foot_score[control_x]) for control_x in positive_selected
        ],
        "selected_directional_deltas": [
            float(value) for value in selected_directional_delta
        ],
        "selected_applied_strengths": [
            float(value) for value in selected_strength
        ],
        "selected_available_depth_ratios": [
            float(available_depth_ratio[control_x])
            for control_x in positive_selected
        ],
        "selected_distance_minimum_world_px": COVERED_WORLD_PX,
        "selected_distance_maximum_world_px": (
            EDGE_WORLD_PX - OUTER_ALPHA_GUARD_WORLD_PX
        ),
    }


def opacity_mask(
    patch: np.ndarray,
    base_edge: np.ndarray,
    shape: EdgeShapeSpec,
    top_edge: bool,
    thickness_variation_world_px: float = THICKNESS_VARIATION_WORLD_PX,
    thinning_enabled: bool = True,
    terrain_opacity_gain: float = TERRAIN_BITE_OPACITY_GAIN,
) -> tuple[np.ndarray, dict[str, object], np.ndarray]:
    native_alpha = patch[..., 3].astype(np.float64) / 255.0
    brush = smootherstep(
        (native_alpha - 12.0 / 255.0) / ((56.0 - 12.0) / 255.0)
    )
    rows = np.arange(EDGE_PATCH_HEIGHT, dtype=np.float64)
    distance_rows = rows if top_edge else EDGE_PATCH_HEIGHT - 1 - rows
    distance_rows = np.broadcast_to(distance_rows[:, None], brush.shape)
    distance_world_px = distance_rows / TEXTURE_SCALE
    feather_distance_world_px = distance_world_px - COVERED_WORLD_PX

    thickness_control = periodic_low_frequency_field(
        shape.thickness_phase_rad,
        shape.thickness_secondary_phase_rad,
    )
    thickness_world_px = (
        NOMINAL_SHAPED_FEATHER_WORLD_PX
        + thickness_variation_world_px * thickness_control
    )
    thinning_window = (
        periodic_thinning_window(shape)
        if thinning_enabled
        else np.zeros_like(thickness_control)
    )
    terrain_support, terrain_support_metrics = terrain_attachment_support(
        base_edge,
        shape,
        thinning_window,
        thickness_world_px,
        top_edge,
    )
    requested_terrain_depth = TERRAIN_BITE_MAXIMUM_DEPTH_WORLD_PX * terrain_support
    terrain_depth = np.minimum(
        requested_terrain_depth,
        np.maximum(
            MAXIMUM_SHAPED_FEATHER_WORLD_PX - thickness_world_px[None, :],
            0.0,
        ),
    )
    local_brush_depth = 0.42 * (brush - 0.5)
    unattached_depth = np.clip(
        thickness_world_px[None, :] + local_brush_depth,
        0.25,
        MAXIMUM_SHAPED_FEATHER_WORLD_PX,
    )
    attached_depth = np.clip(
        thickness_world_px[None, :] + terrain_depth + local_brush_depth,
        0.25,
        MAXIMUM_SHAPED_FEATHER_WORLD_PX,
    )
    unattached_progress = feather_distance_world_px / unattached_depth
    attached_progress = feather_distance_world_px / attached_depth
    unattached_profile = 1.0 - smootherstep(
        (unattached_progress - FEATHER_FADE_START_RATIO)
        / (1.0 - FEATHER_FADE_START_RATIO)
    )
    raw_attached_profile = 1.0 - smootherstep(
        (attached_progress - FEATHER_FADE_START_RATIO)
        / (1.0 - FEATHER_FADE_START_RATIO)
    )
    attached_profile = unattached_profile + terrain_opacity_gain * (
        raw_attached_profile - unattached_profile
    )
    thinning_activation = smootherstep(feather_distance_world_px / 1.0)
    thinning_factor = 1.0 - (
        thinning_window[None, :]
        * (1.0 - shape.thinning_opacity_multiplier)
        * thinning_activation
    )
    opacity = attached_profile * thinning_factor
    opacity = np.where(distance_rows <= COVERED_ROWS, 1.0, opacity)
    opacity = np.where(
        feather_distance_world_px >= MAXIMUM_SHAPED_FEATHER_WORLD_PX,
        0.0,
        opacity,
    )
    opacity = np.clip(opacity, 0.0, 1.0)
    terrain_opacity_gain = np.maximum(attached_profile - unattached_profile, 0.0)
    active_terrain_gain = terrain_opacity_gain[terrain_opacity_gain > 1.0e-6]
    thickness_percentiles = field_percentile_metrics(thickness_world_px)
    diagnostics = {
        "thickness_minimum_world_px": float(thickness_world_px.min()),
        "thickness_maximum_world_px": float(thickness_world_px.max()),
        "thickness_p05_world_px": thickness_percentiles["p05_world_px"],
        "thickness_p95_world_px": thickness_percentiles["p95_world_px"],
        "thickness_p95_half_range_world_px": thickness_percentiles[
            "p95_half_range_world_px"
        ],
        "thinning_width_ratio": shape.thinning_width_ratio,
        "minimum_outer_opacity_multiplier": shape.thinning_opacity_multiplier,
        "thinning_active_ratio": float(
            np.mean(thinning_window > THINNING_ACTIVE_WINDOW_THRESHOLD)
        ),
        "thinning_strong_ratio": float(np.mean(thinning_window >= 0.5)),
        "minimum_applied_thinning_factor": float(
            thinning_factor[feather_distance_world_px >= 1.0].min(initial=1.0)
        ),
        "minimum_column_integrated_opacity_world_px": float(
            opacity.sum(axis=0).min() / TEXTURE_SCALE
        ),
        "terrain_attachment_mean_gain": (
            float(active_terrain_gain.mean()) if active_terrain_gain.size else 0.0
        ),
        "terrain_attachment_maximum_gain": float(terrain_opacity_gain.max()),
        "terrain_attachment_active_ratio": float(
            np.count_nonzero(terrain_opacity_gain > 1.0e-6)
            / terrain_opacity_gain.size
        ),
        "terrain_attachment_maximum_depth_world_px": float(terrain_depth.max()),
        "terrain_control_cells": terrain_support_metrics["control_cells"],
        "terrain_active_control_cells": terrain_support_metrics[
            "active_control_cells"
        ],
        "terrain_control_active_ratio": terrain_support_metrics[
            "control_active_ratio"
        ],
        "terrain_horizontal_active_ratio": terrain_support_metrics[
            "horizontal_active_ratio"
        ],
        "terrain_directional_role": terrain_support_metrics["directional_role"],
        "terrain_eligible_control_row": terrain_support_metrics[
            "eligible_control_row"
        ],
        "terrain_selected_control_cells": terrain_support_metrics[
            "selected_control_cells"
        ],
        "terrain_selected_raw_foot_scores": terrain_support_metrics[
            "selected_raw_foot_scores"
        ],
        "terrain_selected_directional_deltas": terrain_support_metrics[
            "selected_directional_deltas"
        ],
        "terrain_selected_applied_strengths": terrain_support_metrics[
            "selected_applied_strengths"
        ],
        "terrain_selected_available_depth_ratios": terrain_support_metrics[
            "selected_available_depth_ratios"
        ],
        "terrain_selected_distance_minimum_world_px": terrain_support_metrics[
            "selected_distance_minimum_world_px"
        ],
        "terrain_selected_distance_maximum_world_px": terrain_support_metrics[
            "selected_distance_maximum_world_px"
        ],
        "outer_guard_maximum_opacity": float(
            opacity[feather_distance_world_px >= MAXIMUM_SHAPED_FEATHER_WORLD_PX].max(
                initial=0.0
            )
        ),
    }
    return opacity, diagnostics, thinning_window


def tone_and_composite_strip(
    base: np.ndarray,
    patch: np.ndarray,
    bottom_opacity: np.ndarray,
    top_opacity: np.ndarray,
    shapes: dict[str, EdgeShapeSpec],
    terrain_bridge_detail_gain: float,
    detail_gain: float,
    approved_literal_source_luma_std: float,
    effective_source_luma_std: float,
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
    terrain_bridge, terrain_bridge_luma_calibration = (
        terrain_bridge_from_immutable_body(
            base,
            terrain_bridge_detail_gain,
        )
    )
    bottom_distance_world_px = np.linspace(
        (EDGE_ROWS - 1) / TEXTURE_SCALE,
        0.0,
        EDGE_ROWS,
        dtype=np.float64,
    )
    top_distance_world_px = np.linspace(
        0.0,
        (EDGE_ROWS - 1) / TEXTURE_SCALE,
        EDGE_ROWS,
        dtype=np.float64,
    )
    distance_from_seam_world_px = np.concatenate(
        (bottom_distance_world_px, top_distance_world_px)
    )
    signed_distance_from_seam_world_px = np.concatenate(
        (-bottom_distance_world_px, top_distance_world_px)
    )
    meander_primary_phase = circular_phase_midpoint(
        shapes["bottom"].meander_phase_rad,
        shapes["top"].meander_phase_rad,
    )
    meander_secondary_phase = circular_phase_midpoint(
        shapes["bottom"].meander_secondary_phase_rad,
        shapes["top"].meander_secondary_phase_rad,
    )
    visible_centerline = periodic_low_frequency_field(
        meander_primary_phase,
        meander_secondary_phase,
    )
    centerline_p05, centerline_p95 = np.percentile(
        visible_centerline,
        (5.0, 95.0),
    )
    centerline_half_range = max(
        float((centerline_p95 - centerline_p05) * 0.5),
        1.0e-9,
    )
    shared_visible_centerline = np.clip(
        visible_centerline
        * (
            VISIBLE_CENTERLINE_TARGET_P95_HALF_RANGE_WORLD_PX
            / centerline_half_range
        ),
        -VISIBLE_CENTERLINE_MAXIMUM_ABSOLUTE_WORLD_PX,
        VISIBLE_CENTERLINE_MAXIMUM_ABSOLUTE_WORLD_PX,
    )
    reveal_depth_by_edge: dict[str, np.ndarray] = {}
    for edge_name in ("bottom", "top"):
        reveal_field = periodic_low_frequency_field(
            shapes[edge_name].terrain_phase_rad,
            shapes[edge_name].terrain_phase_rad + np.pi * 0.625,
        )
        reveal_depth_by_edge[edge_name] = (
            TERRAIN_BRIDGE_REVEAL_MINIMUM_WORLD_PX
            + (reveal_field + 1.0)
            * 0.5
            * (
                TERRAIN_BRIDGE_REVEAL_MAXIMUM_WORLD_PX
                - TERRAIN_BRIDGE_REVEAL_MINIMUM_WORLD_PX
            )
        )
    reveal_depth_world_px = np.stack(
        (
            reveal_depth_by_edge["bottom"],
            reveal_depth_by_edge["top"],
        )
    )
    terrain_bridge_mix = TERRAIN_BRIDGE_MAXIMUM_MIX * np.concatenate(
        (
            1.0
            - np.exp(
                -4.0
                * bottom_distance_world_px[:, None]
                / reveal_depth_by_edge["bottom"][None, :]
            ),
            1.0
            - np.exp(
                -4.0
                * top_distance_world_px[:, None]
                / reveal_depth_by_edge["top"][None, :]
            ),
        ),
        axis=0,
    )
    shared_terrain_reference_rgb = 0.5 * (
        terrain_bridge[EDGE_ROWS - 1] + terrain_bridge[EDGE_ROWS]
    )
    shared_reference_mean_rgb = shared_terrain_reference_rgb.mean(
        axis=0,
        keepdims=True,
    )
    shared_terrain_reference_rgb = np.clip(
        shared_reference_mean_rgb
        + (
            shared_terrain_reference_rgb - shared_reference_mean_rgb
        )
        * VISIBLE_SHARED_REFERENCE_DETAIL_GAIN,
        0.0,
        255.0,
    )
    local_reference_rgb = (
        shared_terrain_reference_rgb[None, :, :]
        * (1.0 - terrain_bridge_mix[..., None])
        + terrain_bridge * terrain_bridge_mix[..., None]
    )
    unthinned_local_reference_rgb = local_reference_rgb
    unthinned_local_reference_luma = luma(unthinned_local_reference_rgb)

    bottom_thickness_field = periodic_low_frequency_field(
        shapes["bottom"].thickness_phase_rad,
        shapes["bottom"].thickness_secondary_phase_rad,
    )
    top_thickness_field = periodic_low_frequency_field(
        shapes["top"].thickness_phase_rad,
        shapes["top"].thickness_secondary_phase_rad,
    )
    bottom_visible_half_width = VISIBLE_PIGMENT_NOMINAL_HALF_WIDTH_WORLD_PX * (
        1.0 + THICKNESS_VARIATION_RATIO * bottom_thickness_field
    )
    top_visible_half_width = VISIBLE_PIGMENT_NOMINAL_HALF_WIDTH_WORLD_PX * (
        1.0 + THICKNESS_VARIATION_RATIO * top_thickness_field
    )
    shared_visible_half_width = (
        bottom_visible_half_width + top_visible_half_width
    ) * 0.5
    bottom_seam_transition = smootherstep(
        bottom_distance_world_px / VISIBLE_SHAPE_SEAM_TRANSITION_WORLD_PX
    )
    top_seam_transition = smootherstep(
        top_distance_world_px / VISIBLE_SHAPE_SEAM_TRANSITION_WORLD_PX
    )
    edge_centerline_primary_phase = shapes["bottom"].terrain_phase_rad
    edge_centerline_secondary_phase = (
        shapes["bottom"].thickness_secondary_phase_rad
    )
    edge_centerline_by_edge: dict[str, np.ndarray] = {}
    for edge_name, phase_offset in (
        ("bottom", 0.0),
        ("top", np.pi * 0.5),
    ):
        edge_centerline_by_edge[edge_name] = np.clip(
            shared_visible_centerline
            + VISIBLE_EDGE_CENTERLINE_DIVERGENCE_WORLD_PX
            * periodic_low_frequency_field(
                edge_centerline_primary_phase + phase_offset,
                edge_centerline_secondary_phase + phase_offset,
            ),
            -VISIBLE_EDGE_CENTERLINE_MAXIMUM_ABSOLUTE_WORLD_PX,
            VISIBLE_EDGE_CENTERLINE_MAXIMUM_ABSOLUTE_WORLD_PX,
        )
    visible_centerline = np.concatenate(
        (
            shared_visible_centerline[None, :]
            + (
                edge_centerline_by_edge["bottom"]
                - shared_visible_centerline
            )[None, :]
            * bottom_seam_transition[:, None],
            shared_visible_centerline[None, :]
            + (
                edge_centerline_by_edge["top"]
                - shared_visible_centerline
            )[None, :]
            * top_seam_transition[:, None],
        ),
        axis=0,
    )
    visible_half_width = np.concatenate(
        (
            shared_visible_half_width[None, :]
            + (
                bottom_visible_half_width - shared_visible_half_width
            )[None, :]
            * bottom_seam_transition[:, None],
            shared_visible_half_width[None, :]
            + (
                top_visible_half_width - shared_visible_half_width
            )[None, :]
            * top_seam_transition[:, None],
        ),
        axis=0,
    )
    visible_pigment_distance = np.abs(
        signed_distance_from_seam_world_px[:, None]
        - visible_centerline
    )
    visible_pigment_profile = smootherstep(
        1.0 - visible_pigment_distance / visible_half_width
    )

    bottom_thinning_window = periodic_thinning_window(shapes["bottom"])
    top_thinning_window = periodic_thinning_window(shapes["top"])
    bottom_thinning_factor = (
        1.0
        - bottom_thinning_window
        * (1.0 - shapes["bottom"].thinning_opacity_multiplier)
    )
    top_thinning_factor = (
        1.0
        - top_thinning_window
        * (1.0 - shapes["top"].thinning_opacity_multiplier)
    )
    shared_thinning_window = np.maximum(
        bottom_thinning_window,
        top_thinning_window,
    )
    shared_thinning_factor = np.minimum(
        bottom_thinning_factor,
        top_thinning_factor,
    )
    bottom_thinning_transition = smootherstep(
        bottom_distance_world_px / VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX
    )
    top_thinning_transition = smootherstep(
        top_distance_world_px / VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX
    )
    visible_thinning_window = np.concatenate(
        (
            shared_thinning_window[None, :]
            + (
                bottom_thinning_window - shared_thinning_window
            )[None, :]
            * bottom_thinning_transition[:, None],
            shared_thinning_window[None, :]
            + (
                top_thinning_window - shared_thinning_window
            )[None, :]
            * top_thinning_transition[:, None],
        ),
        axis=0,
    )
    base_visible_thinning_factor = np.concatenate(
        (
            shared_thinning_factor[None, :]
            + (
                bottom_thinning_factor - shared_thinning_factor
            )[None, :]
            * bottom_thinning_transition[:, None],
            shared_thinning_factor[None, :]
            + (
                top_thinning_factor - shared_thinning_factor
            )[None, :]
            * top_thinning_transition[:, None],
        ),
        axis=0,
    )
    minimum_visible_thinning_factor = (
        MINIMUM_VISIBLE_THINNED_PEAK_INK_MIX - VISIBLE_HAZE_FLOOR
    ) / (
        (VISIBLE_PIGMENT_MAXIMUM_MIX - VISIBLE_HAZE_FLOOR)
        * VISIBLE_ACTIVE_PROFILE_GATE
    )
    visible_thinning_factor = np.maximum(
        np.power(
            base_visible_thinning_factor,
            VISIBLE_THINNING_FACTOR_EXPONENT,
        ),
        minimum_visible_thinning_factor,
    )
    edge_veil_by_edge: dict[str, np.ndarray] = {}
    veil_primary_phase = shapes["bottom"].terrain_phase_rad
    veil_secondary_phase = shapes["bottom"].meander_secondary_phase_rad
    for edge_name, phase_offset in (
        ("bottom", 0.0),
        ("top", np.pi * 0.5),
    ):
        edge_veil_field = periodic_low_frequency_field(
            veil_primary_phase + phase_offset,
            veil_secondary_phase + phase_offset,
        )
        edge_veil_by_edge[edge_name] = np.clip(
            0.5
            * (
                1.0
                + VISIBLE_EDGE_VEIL_MINIMUM_FACTOR
                + (1.0 - VISIBLE_EDGE_VEIL_MINIMUM_FACTOR)
                * edge_veil_field
            ),
            VISIBLE_EDGE_VEIL_MINIMUM_FACTOR,
            1.0,
        )
    shared_edge_veil = 0.5 * (
        edge_veil_by_edge["bottom"] + edge_veil_by_edge["top"]
    )
    bottom_veil_transition = smootherstep(
        bottom_distance_world_px / VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX
    )
    top_veil_transition = smootherstep(
        top_distance_world_px / VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX
    )
    visible_edge_veil = np.concatenate(
        (
            shared_edge_veil[None, :]
            + (
                edge_veil_by_edge["bottom"] - shared_edge_veil
            )[None, :]
            * bottom_veil_transition[:, None],
            shared_edge_veil[None, :]
            + (
                edge_veil_by_edge["top"] - shared_edge_veil
            )[None, :]
            * top_veil_transition[:, None],
        ),
        axis=0,
    )
    visible_ink_mix = (
        VISIBLE_HAZE_FLOOR
        + (VISIBLE_PIGMENT_MAXIMUM_MIX - VISIBLE_HAZE_FLOOR)
        * visible_pigment_profile
        * visible_thinning_factor
        * visible_edge_veil
    )
    visible_active_ink_floor = (
        VISIBLE_HAZE_FLOOR
        + (
            MINIMUM_VISIBLE_THINNED_PEAK_INK_MIX
            - VISIBLE_HAZE_FLOOR
        )
        * smootherstep(
            visible_pigment_profile / VISIBLE_ACTIVE_PROFILE_GATE
        )
    )
    visible_ink_mix = np.maximum(
        visible_ink_mix,
        visible_active_ink_floor,
    )
    terrain_bridge_low_pass = np.asarray(
        Image.fromarray(
            np.clip(terrain_bridge, 0.0, 255.0).astype(np.uint8)
        ).filter(
            ImageFilter.GaussianBlur(
                VISIBLE_DETAIL_BLUR_WORLD_PX * TEXTURE_SCALE
            )
        ),
        dtype=np.float64,
    )
    thinning_terrain_detail = (
        (terrain_bridge - terrain_bridge_low_pass)
        * terrain_bridge_mix[..., None]
        * visible_thinning_window[..., None]
        * VISIBLE_THINNING_TERRAIN_DETAIL_GAIN
    )
    local_reference_rgb = np.clip(
        unthinned_local_reference_rgb + thinning_terrain_detail,
        0.0,
        255.0,
    )
    local_reference_luma = luma(local_reference_rgb)

    edge_rows = np.linspace(0.0, EDGE_ROWS - 1, EDGE_ROWS, dtype=np.float64)
    bottom_balance_weight = smootherstep(
        (EDGE_ROWS - 1 - edge_rows) / (EDGE_ROWS - 1)
    )
    top_balance_weight = smootherstep(edge_rows / (EDGE_ROWS - 1))
    bottom_detail_mean = float(
        (butt_detail[:EDGE_ROWS] * bottom_opacity).sum()
        / max(float(bottom_opacity.sum()), 1.0e-9)
    )
    top_detail_mean = float(
        (butt_detail[EDGE_ROWS:] * top_opacity).sum()
        / max(float(top_opacity.sum()), 1.0e-9)
    )

    def compose(
        top_edge_offset: int,
        bottom_edge_offset: int,
        composite_reference_rgb: np.ndarray = local_reference_rgb,
        composite_reference_luma: np.ndarray = local_reference_luma,
        composite_ink_mix: np.ndarray = visible_ink_mix,
    ) -> tuple[np.ndarray, float, float, float, float, float]:
        edge_offset = np.concatenate(
            (
                bottom_edge_offset * bottom_balance_weight,
                top_edge_offset * top_balance_weight,
            )
        )
        cloud_tone = (
            target_rgb[None, None, :]
            + butt_detail[..., None]
        )
        cloud_luma = luma(cloud_tone)
        cloud_tone -= np.maximum(
            cloud_luma - MAXIMUM_MIST_TONE_LUMA,
            0.0,
        )[..., None]
        cloud_tone = np.clip(cloud_tone, 0.0, 255.0)
        cloud_luma = luma(cloud_tone)
        toned = (
            composite_reference_rgb * (1.0 - composite_ink_mix[..., None])
            + cloud_tone * composite_ink_mix[..., None]
            + edge_offset[:, None, None]
        )
        toned_luma = luma(toned)
        toned -= np.maximum(
            toned_luma
            - (composite_reference_luma + VISIBLE_LOCAL_LUMA_MAXIMUM_GAIN),
            0.0,
        )[..., None]
        toned_luma = luma(toned)
        toned -= np.maximum(
            toned_luma - MAXIMUM_MIST_TONE_LUMA,
            0.0,
        )[..., None]
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
            float(cloud_luma.std()),
            top_mean,
            bottom_mean,
        )

    _initial, _initial_luma, _initial_max, _initial_std, _initial_top, _initial_bottom = compose(0, 0)
    top_balance_response = max(
        float(
            (
                top_opacity
                * top_balance_weight[:, None]
            ).mean()
        ),
        1.0e-6,
    )
    bottom_balance_response = max(
        float(
            (
                bottom_opacity
                * bottom_balance_weight[:, None]
            ).mean()
        ),
        1.0e-6,
    )
    estimated_top = int(round((target_luma - _initial_top) / top_balance_response))
    estimated_bottom = int(
        round((target_luma - _initial_bottom) / bottom_balance_response)
    )
    for _iteration in range(2):
        _probe, _probe_luma, _probe_max, _probe_std, probe_top, probe_bottom = compose(
            estimated_top,
            estimated_bottom,
        )
        estimated_top += int(round((target_luma - probe_top) / top_balance_response))
        estimated_bottom += int(
            round((target_luma - probe_bottom) / bottom_balance_response)
        )
    candidates = []
    for top_offset in range(estimated_top - 3, estimated_top + 4):
        for bottom_offset in range(estimated_bottom - 3, estimated_bottom + 4):
            result, result_luma, tone_max, tone_std, top_mean, bottom_mean = compose(
                top_offset,
                bottom_offset,
            )
            top_delta = abs(top_mean - target_luma)
            bottom_delta = abs(bottom_mean - target_luma)
            candidates.append(
                (
                    max(top_delta, bottom_delta),
                    abs(result_luma - target_luma),
                    abs(top_offset) + abs(bottom_offset),
                    top_offset,
                    bottom_offset,
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
        top_offset,
        bottom_offset,
        result,
        tone_max,
        tone_std,
        top_mean,
        bottom_mean,
    ) = min(
        candidates, key=lambda item: item[:4]
    )
    contrast_ratio = tone_std / max(effective_source_luma_std, 1.0e-9)
    if contrast_ratio > MAXIMUM_MIST_TONE_CONTRAST_RATIO:
        raise RuntimeError(
            "mist patch was not low-contrast: "
            f"{contrast_ratio} > {MAXIMUM_MIST_TONE_CONTRAST_RATIO}"
        )

    bottom_applied_rows = (
        bottom_distance_world_px >= VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX
    )
    top_applied_rows = (
        top_distance_world_px >= VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX
    )
    bottom_actual_thinning_profile = visible_thinning_window[
        :EDGE_ROWS
    ][bottom_applied_rows].mean(axis=0)
    top_actual_thinning_profile = visible_thinning_window[
        EDGE_ROWS:
    ][top_applied_rows].mean(axis=0)
    bottom_actual_thinning_signature = sha256_bytes(
        np.ascontiguousarray(
            bottom_actual_thinning_profile.astype(np.float32)
        ).tobytes()
    )
    top_actual_thinning_signature = sha256_bytes(
        np.ascontiguousarray(
            top_actual_thinning_profile.astype(np.float32)
        ).tobytes()
    )
    actual_thinning_shared_seam_rows_exact = bool(
        np.array_equal(
            visible_thinning_window[EDGE_ROWS - 1],
            visible_thinning_window[EDGE_ROWS],
        )
    )
    actual_thinning_strong_overlap_ratio = float(
        np.mean(
            (bottom_actual_thinning_profile >= 0.5)
            & (top_actual_thinning_profile >= 0.5)
        )
    )
    actual_thinning_signatures_unique = (
        bottom_actual_thinning_signature != top_actual_thinning_signature
    )
    actual_thinning_correlation = float(
        np.corrcoef(
            bottom_actual_thinning_profile,
            top_actual_thinning_profile,
        )[0, 1]
    )
    actual_thinning_absolute_correlation = abs(actual_thinning_correlation)
    actual_thinning_profiles = {
        "construction": "mean_applied_rows_outside_veil_transition_v1",
        "transition_world_px": VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX,
        "shared_seam_rows_exact": actual_thinning_shared_seam_rows_exact,
        "bottom": {
            "active_ratio": float(
                np.mean(
                    bottom_actual_thinning_profile
                    > THINNING_ACTIVE_WINDOW_THRESHOLD
                )
            ),
            "p90": float(
                np.percentile(bottom_actual_thinning_profile, 90.0)
            ),
            "float32_sha256": bottom_actual_thinning_signature,
        },
        "top": {
            "active_ratio": float(
                np.mean(
                    top_actual_thinning_profile
                    > THINNING_ACTIVE_WINDOW_THRESHOLD
                )
            ),
            "p90": float(np.percentile(top_actual_thinning_profile, 90.0)),
            "float32_sha256": top_actual_thinning_signature,
        },
        "bottom_top_correlation": actual_thinning_correlation,
        "bottom_top_absolute_correlation": (
            actual_thinning_absolute_correlation
        ),
        "strong_overlap_ratio": actual_thinning_strong_overlap_ratio,
        "signatures_unique": actual_thinning_signatures_unique,
    }
    if (
        not actual_thinning_shared_seam_rows_exact
        or not actual_thinning_signatures_unique
        or actual_thinning_strong_overlap_ratio
        > MAXIMUM_THINNING_STRONG_OVERLAP_RATIO
        or actual_thinning_absolute_correlation
        > MAXIMUM_ACTUAL_APPLIED_THINNING_ABSOLUTE_CORRELATION
        or any(
            float(actual_thinning_profiles[edge_name]["active_ratio"])
            < THINNING_MINIMUM_WIDTH_RATIO
            or float(actual_thinning_profiles[edge_name]["active_ratio"])
            > THINNING_MAXIMUM_WIDTH_RATIO
            for edge_name in ("bottom", "top")
        )
    ):
        raise RuntimeError(
            "actual applied thinning profiles escaped the 2D veil contract: "
            f"{actual_thinning_profiles}"
        )

    edge_centerline_residual_correlation = float(
        np.corrcoef(
            edge_centerline_by_edge["bottom"] - shared_visible_centerline,
            edge_centerline_by_edge["top"] - shared_visible_centerline,
        )[0, 1]
    )
    edge_centerline_residual_absolute_correlation = abs(
        edge_centerline_residual_correlation
    )
    edge_veil_correlation = float(
        np.corrcoef(
            edge_veil_by_edge["bottom"],
            edge_veil_by_edge["top"],
        )[0, 1]
    )
    edge_veil_absolute_correlation = abs(edge_veil_correlation)
    edge_veil_bottom_p05 = float(
        np.percentile(edge_veil_by_edge["bottom"], 5.0)
    )
    edge_veil_bottom_p95 = float(
        np.percentile(edge_veil_by_edge["bottom"], 95.0)
    )
    edge_veil_top_p05 = float(
        np.percentile(edge_veil_by_edge["top"], 5.0)
    )
    edge_veil_top_p95 = float(
        np.percentile(edge_veil_by_edge["top"], 95.0)
    )
    if (
        edge_centerline_residual_absolute_correlation
        > MAXIMUM_VISIBLE_EDGE_CENTERLINE_RESIDUAL_ABSOLUTE_CORRELATION
        or edge_veil_absolute_correlation
        > MAXIMUM_VISIBLE_EDGE_VEIL_ABSOLUTE_CORRELATION
        or max(edge_veil_bottom_p05, edge_veil_top_p05)
        > MAXIMUM_VISIBLE_EDGE_VEIL_P05
        or min(edge_veil_bottom_p95, edge_veil_top_p95)
        < MINIMUM_VISIBLE_EDGE_VEIL_P95
    ):
        raise RuntimeError(
            "visible edge centerline/veil decorrelation gates failed: "
            f"centerline_abs_corr={edge_centerline_residual_absolute_correlation}, "
            f"veil_abs_corr={edge_veil_absolute_correlation}, "
            f"veil_p05={edge_veil_bottom_p05}/{edge_veil_top_p05}, "
            f"veil_p95={edge_veil_bottom_p95}/{edge_veil_top_p95}"
        )

    visible_weight = np.maximum(
        visible_ink_mix - VISIBLE_HAZE_FLOOR,
        0.0,
    )
    visible_weight_sum = visible_weight.sum(axis=0)
    valid_centroid_columns = visible_weight_sum > 1.0e-6
    visible_centerline_centroid = (
        (
            visible_weight
            * signed_distance_from_seam_world_px[:, None]
        ).sum(axis=0)
        / np.maximum(visible_weight_sum, 1.0e-9)
    )
    centroid_p05, centroid_p95 = np.percentile(
        visible_centerline_centroid[valid_centroid_columns],
        (5.0, 95.0),
    )
    centroid_p95_half_range = float((centroid_p95 - centroid_p05) * 0.5)
    centroid_maximum_absolute = float(
        np.abs(visible_centerline_centroid[valid_centroid_columns]).max()
    )
    centroid_valid_ratio = float(valid_centroid_columns.mean())
    result_luma_field = luma(result)
    local_luma_gain = result_luma_field - local_reference_luma
    core_rows = distance_from_seam_world_px <= COVERED_WORLD_PX
    core_positive_luma_gain = np.maximum(local_luma_gain[core_rows], 0.0)
    core_luma_gain_p95 = float(np.percentile(core_positive_luma_gain, 95.0))
    core_luma_gain_maximum = float(core_positive_luma_gain.max(initial=0.0))
    pale_row_fraction = np.mean(
        local_luma_gain >= VISIBLE_FULL_WIDTH_PALE_LUMA_GAIN,
        axis=1,
    )
    full_width_pale_run_world_px = (
        maximum_true_run(
            pale_row_fraction >= VISIBLE_FULL_WIDTH_PALE_COLUMN_RATIO
        )
        / TEXTURE_SCALE
    )
    shared_low_pass_reference_rgb = 0.5 * (
        terrain_bridge_low_pass[EDGE_ROWS - 1]
        + terrain_bridge_low_pass[EDGE_ROWS]
    )
    counterfactual_reference_rgb = (
        shared_low_pass_reference_rgb[None, :, :]
        * (1.0 - terrain_bridge_mix[..., None])
        + terrain_bridge_low_pass * terrain_bridge_mix[..., None]
    )
    counterfactual_reference_luma = luma(counterfactual_reference_rgb)
    (
        counterfactual_result,
        _counterfactual_luma,
        _counterfactual_maximum,
        _counterfactual_std,
        _counterfactual_top,
        _counterfactual_bottom,
    ) = compose(
        top_offset,
        bottom_offset,
        counterfactual_reference_rgb,
        counterfactual_reference_luma,
    )
    terrain_detail_signal = np.abs(
        result_luma_field - luma(counterfactual_result)
    )
    thinning_disabled_ink_mix = (
        VISIBLE_HAZE_FLOOR
        + (VISIBLE_PIGMENT_MAXIMUM_MIX - VISIBLE_HAZE_FLOOR)
        * visible_pigment_profile
        * visible_edge_veil
    )
    thinning_disabled_ink_mix = np.maximum(
        thinning_disabled_ink_mix,
        visible_active_ink_floor,
    )
    thinning_disabled_result = compose(
        top_offset,
        bottom_offset,
        unthinned_local_reference_rgb,
        unthinned_local_reference_luma,
        thinning_disabled_ink_mix,
    )[0]
    thinning_disabled_counterfactual_result = compose(
        top_offset,
        bottom_offset,
        counterfactual_reference_rgb,
        counterfactual_reference_luma,
        thinning_disabled_ink_mix,
    )[0]
    thinning_disabled_terrain_detail_signal = np.abs(
        luma(thinning_disabled_result)
        - luma(thinning_disabled_counterfactual_result)
    )
    terrain_bridge_available_detail = (
        np.abs(luma(terrain_bridge) - luma(terrain_bridge_low_pass))
        * terrain_bridge_mix
    )

    def terrain_detail_retention(
        weight: np.ndarray,
        detail_signal: np.ndarray,
    ) -> float:
        denominator = float(
            (weight * terrain_bridge_available_detail).sum()
        )
        if denominator <= 1.0e-9:
            raise RuntimeError("terrain bridge detail gate lost its reference energy")
        return float(
            (weight * detail_signal).sum() / denominator
        )

    terrain_detail_by_edge: dict[str, object] = {}
    thinning_windows: dict[str, object] = {}
    minimum_thinned_peak_ink_mix = 1.0
    minimum_thinned_terrain_detail_ratio = float("inf")
    for edge_name, source_window in (
        ("bottom", bottom_thinning_window),
        ("top", top_thinning_window),
    ):
        positive_source_window = source_window[
            source_window > THINNING_ACTIVE_WINDOW_THRESHOLD
        ]
        if positive_source_window.size == 0:
            raise RuntimeError(f"{edge_name}: visible thinning window became empty")
        active_top_quintile_threshold = float(
            np.percentile(positive_source_window, 80.0)
        )
        edge_slice = (
            slice(0, EDGE_ROWS)
            if edge_name == "bottom"
            else slice(EDGE_ROWS, EDGE_ROWS * 2)
        )
        edge_window = visible_thinning_window[edge_slice]
        edge_profile = visible_pigment_profile[edge_slice]
        active_window = edge_window >= active_top_quintile_threshold
        active_peak = active_window & (
            edge_profile >= VISIBLE_ACTIVE_PROFILE_GATE
        )
        if not np.any(active_peak):
            raise RuntimeError(
                f"{edge_name}: visible pigment lost its active thinning window: "
                f"threshold={active_top_quintile_threshold}, "
                f"active_profile_max={float(edge_profile[active_window].max(initial=0.0))}, "
                f"profile_max={float(edge_profile.max())}"
            )
        edge_minimum_peak_ink_mix = float(
            visible_ink_mix[edge_slice][active_peak].min()
        )
        minimum_thinned_peak_ink_mix = min(
            minimum_thinned_peak_ink_mix,
            edge_minimum_peak_ink_mix,
        )
        bridge_dominant_rows = (
            core_rows[edge_slice]
            & (
                distance_from_seam_world_px[edge_slice]
                >= TERRAIN_BRIDGE_REVEAL_MAXIMUM_WORLD_PX
            )
        )
        edge_core_weight = bridge_dominant_rows.astype(np.float64)[:, None]
        active_weight = (
            edge_core_weight
            * edge_profile
            * active_window.astype(np.float64)
        )
        full_active_weight = np.zeros_like(visible_pigment_profile)
        full_active_weight[edge_slice] = active_weight
        active_retention = terrain_detail_retention(
            full_active_weight,
            terrain_detail_signal,
        )
        thinning_disabled_retention = terrain_detail_retention(
            full_active_weight,
            thinning_disabled_terrain_detail_signal,
        )
        detail_ratio = active_retention / max(
            thinning_disabled_retention,
            1.0e-9,
        )
        minimum_thinned_terrain_detail_ratio = min(
            minimum_thinned_terrain_detail_ratio,
            detail_ratio,
        )
        thinning_windows[edge_name] = {
            "active_ratio": float(
                np.mean(source_window > THINNING_ACTIVE_WINDOW_THRESHOLD)
            ),
            "p90": float(np.percentile(source_window, 90.0)),
            "maximum": float(source_window.max()),
            "active_top_quintile_threshold": active_top_quintile_threshold,
            "minimum_active_peak_ink_mix": edge_minimum_peak_ink_mix,
        }
        terrain_detail_by_edge[edge_name] = {
            "active_top_quintile_counterfactual_retention": active_retention,
            "same_columns_thinning_disabled_retention": (
                thinning_disabled_retention
            ),
            "enabled_to_disabled_ratio": detail_ratio,
        }
    visible_shape_metrics = {
        "method": "immutable_body_coarse_bridge_and_meandering_pigment_v2",
        "terrain_bridge": {
            "anchor_world_px": TERRAIN_BRIDGE_ANCHOR_WORLD_PX,
            "horizontal_control_cells": HORIZONTAL_CONTROL_CELLS,
            "vertical_control_cells": TERRAIN_BRIDGE_VERTICAL_CONTROL_CELLS,
            "rasterization": (
                "pillow_box_to_bicubic_control_lattice_plus_whole_anchor_residual"
            ),
            "whole_anchor_detail_gain": (
                terrain_bridge_detail_gain
            ),
            "composite_luma_bias": TERRAIN_BRIDGE_COMPOSITE_LUMA_BIAS,
            "edge_luma_calibration": terrain_bridge_luma_calibration,
            "shared_reference_rgb_float32_sha256": sha256_bytes(
                np.ascontiguousarray(
                    shared_terrain_reference_rgb.astype(np.float32)
                ).tobytes()
            ),
            "shared_reference_detail_gain": (
                VISIBLE_SHARED_REFERENCE_DETAIL_GAIN
            ),
            "reveal_depth_minimum_world_px": float(reveal_depth_world_px.min()),
            "reveal_depth_maximum_world_px": float(reveal_depth_world_px.max()),
            "maximum_mix": TERRAIN_BRIDGE_MAXIMUM_MIX,
            "rgb_float32_sha256": sha256_bytes(
                np.ascontiguousarray(terrain_bridge.astype(np.float32)).tobytes()
            ),
            "one_pixel_column_operations": False,
            "per_column_adjustment": False,
        },
        "pigment": {
            "centroid_p05_world_px": float(centroid_p05),
            "centroid_p95_world_px": float(centroid_p95),
            "centroid_p95_half_range_world_px": centroid_p95_half_range,
            "centroid_maximum_absolute_world_px": centroid_maximum_absolute,
            "centroid_valid_column_ratio": centroid_valid_ratio,
            "nominal_half_width_world_px": (
                VISIBLE_PIGMENT_NOMINAL_HALF_WIDTH_WORLD_PX
            ),
            "thickness_variation_ratio": THICKNESS_VARIATION_RATIO,
            "edge_centerline_divergence_world_px": (
                VISIBLE_EDGE_CENTERLINE_DIVERGENCE_WORLD_PX
            ),
            "edge_centerline_cross_edge_correlation": (
                edge_centerline_residual_correlation
            ),
            "edge_centerline_cross_edge_absolute_correlation": (
                edge_centerline_residual_absolute_correlation
            ),
            "haze_floor": VISIBLE_HAZE_FLOOR,
            "maximum_ink_mix": VISIBLE_PIGMENT_MAXIMUM_MIX,
            "thinning_factor_exponent": VISIBLE_THINNING_FACTOR_EXPONENT,
            "active_profile_gate": VISIBLE_ACTIVE_PROFILE_GATE,
            "edge_veil_transition_world_px": (
                VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX
            ),
            "edge_veil_minimum_factor": VISIBLE_EDGE_VEIL_MINIMUM_FACTOR,
            "edge_veil_top_phase_offset_rad": float(np.pi * 0.5),
            "edge_veil_cross_edge_correlation": edge_veil_correlation,
            "edge_veil_cross_edge_absolute_correlation": (
                edge_veil_absolute_correlation
            ),
            "edge_veil_bottom_p05": edge_veil_bottom_p05,
            "edge_veil_bottom_p95": edge_veil_bottom_p95,
            "edge_veil_top_p05": edge_veil_top_p05,
            "edge_veil_top_p95": edge_veil_top_p95,
            "thinning_terrain_detail_gain": (
                VISIBLE_THINNING_TERRAIN_DETAIL_GAIN
            ),
            "minimum_visible_thinning_factor": (
                minimum_visible_thinning_factor
            ),
            "minimum_thinned_peak_ink_mix": minimum_thinned_peak_ink_mix,
            "thinning_windows": thinning_windows,
            "actual_applied_thinning_profiles": actual_thinning_profiles,
            "ink_mix_float32_sha256": sha256_bytes(
                np.ascontiguousarray(visible_ink_mix.astype(np.float32)).tobytes()
            ),
        },
        "full_width_pale_run_world_px": full_width_pale_run_world_px,
        "core_local_luma_positive_gain_p95": core_luma_gain_p95,
        "core_local_luma_positive_gain_maximum": core_luma_gain_maximum,
        "terrain_detail_by_edge": terrain_detail_by_edge,
        "minimum_thinned_terrain_detail_ratio": (
            minimum_thinned_terrain_detail_ratio
        ),
    }
    if (
        centroid_p95_half_range
        < MINIMUM_VISIBLE_CENTERLINE_P95_HALF_RANGE_WORLD_PX
        or centroid_maximum_absolute
        > MAXIMUM_VISIBLE_CENTERLINE_ABSOLUTE_WORLD_PX
        or centroid_valid_ratio < MINIMUM_VISIBLE_CENTERLINE_VALID_RATIO
        or full_width_pale_run_world_px > MAXIMUM_FULL_WIDTH_PALE_RUN_WORLD_PX
        or core_luma_gain_p95 > MAXIMUM_CORE_LOCAL_LUMA_P95_GAIN
        or core_luma_gain_maximum > MAXIMUM_CORE_LOCAL_LUMA_GAIN
        or minimum_thinned_terrain_detail_ratio
        < MINIMUM_THINNED_TERRAIN_DETAIL_RATIO
        or minimum_thinned_peak_ink_mix < MINIMUM_VISIBLE_THINNED_PEAK_INK_MIX
        or VISIBLE_HAZE_FLOOR < MINIMUM_VISIBLE_HAZE_FLOOR
    ):
        raise RuntimeError(
            f"visible mist/terrain integration gates failed: {visible_shape_metrics}"
        )
    return result, {
        "detail_model": "immutable_body_bridge_with_meandering_literal_pigment_v3",
        "source_alpha_weighted_mean_luma": source_luma_mean,
        "target_body_mean_rgb": [float(value) for value in target_rgb],
        "target_body_luma": target_luma,
        "detail_gain": detail_gain,
        "bottom_opacity_weighted_detail_mean": bottom_detail_mean,
        "top_opacity_weighted_detail_mean": top_detail_mean,
        "global_rgb_offset": 0,
        "top_edge_rgb_offset": top_offset,
        "bottom_edge_rgb_offset": bottom_offset,
        "edge_offset_profile": "whole_edge_smootherstep_to_zero_at_shared_seam_v1",
        "global_offset_objective": "minimize_maximum_top_bottom_body_luma_delta",
        "composited_luma": float(luma(result).mean()),
        "top_composited_luma": top_mean,
        "bottom_composited_luma": bottom_mean,
        "maximum_edge_body_luma_delta": max(
            abs(top_mean - target_luma), abs(bottom_mean - target_luma)
        ),
        "mist_tone_maximum_luma": tone_max,
        "approved_literal_source_alpha_weighted_luma_std": (
            approved_literal_source_luma_std
        ),
        "effective_source_alpha_weighted_luma_std": effective_source_luma_std,
        "resized_blurred_source_alpha_weighted_luma_std": source_luma_std,
        "mist_tone_luma_std": tone_std,
        "mist_to_source_contrast_ratio": contrast_ratio,
        "visible_shape_metrics": visible_shape_metrics,
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


def feather_front_depth_profile(mask: np.ndarray, top_edge: bool) -> np.ndarray:
    outward = mask if top_edge else mask[::-1]
    row_indices = np.arange(EDGE_PATCH_HEIGHT, dtype=np.int64)[:, None]
    return np.max(np.where(outward >= 0.5, row_indices, -1), axis=0)


def mask_metrics(top: np.ndarray, bottom: np.ndarray) -> dict[str, object]:
    def front_metrics(mask: np.ndarray, top_edge: bool) -> dict[str, float | int]:
        front = feather_front_depth_profile(mask, top_edge)
        p05, p95 = np.percentile(front.astype(np.float64), (5.0, 95.0))
        return {
            "opacity_threshold": 0.5,
            "minimum_depth_texture_px": int(front.min()),
            "maximum_depth_texture_px": int(front.max()),
            "depth_std_texture_px": float(front.std()),
            "p05_depth_texture_px": float(p05),
            "p95_depth_texture_px": float(p95),
            "p95_half_range_world_px": float(
                (p95 - p05) * 0.5 / TEXTURE_SCALE
            ),
        }

    top_core = top[:CORE_ROWS]
    bottom_core = bottom[-CORE_ROWS:]
    core = np.concatenate((top_core.ravel(), bottom_core.ravel()))
    top_covered = top[: COVERED_ROWS + 1]
    bottom_covered = bottom[-(COVERED_ROWS + 1) :]
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


def shape_gate_failures(shape_modulation: dict[str, object]) -> list[str]:
    failures: list[str] = []
    edges = shape_modulation.get("edges", {})
    if not isinstance(edges, dict) or set(edges) != {"top", "bottom"}:
        return ["band_edge_shape_pair_missing"]
    for edge_name in ("top", "bottom"):
        edge = edges[edge_name]
        metrics = edge.get("metrics", {}) if isinstance(edge, dict) else {}
        selected_terrain_cells = metrics.get("terrain_selected_control_cells", [])
        selected_raw_scores = metrics.get("terrain_selected_raw_foot_scores", [])
        selected_directional_deltas = metrics.get(
            "terrain_selected_directional_deltas",
            [],
        )
        selected_strengths = metrics.get("terrain_selected_applied_strengths", [])
        selected_capacity = metrics.get(
            "terrain_selected_available_depth_ratios",
            [],
        )
        expected_terrain_row = EDGE_VERTICAL_CONTROL_CELLS - 1 if edge_name == "top" else 0
        if (
            float(metrics.get("thickness_p95_half_range_world_px", -1.0))
            < MINIMUM_THICKNESS_P95_HALF_RANGE_WORLD_PX
            or float(metrics.get("actual_front_p95_half_range_world_px", -1.0))
            < MINIMUM_ACTUAL_FRONT_P95_HALF_RANGE_WORLD_PX
        ):
            failures.append(f"{edge_name}_thickness_modulation_disabled")
        if (
            float(metrics.get("meander_p95_half_range_world_px", -1.0))
            < MINIMUM_MEANDER_P95_HALF_RANGE_WORLD_PX
            or not 11.5
            <= float(metrics.get("meander_maximum_absolute_world_px", -1.0))
            <= 12.25
        ):
            failures.append(f"{edge_name}_pigment_meander_disabled")
        if not (
            THINNING_MINIMUM_WIDTH_RATIO
            <= float(edge.get("thinning_width_ratio", -1.0))
            <= THINNING_MAXIMUM_WIDTH_RATIO
            and THINNING_MINIMUM_OPACITY_MULTIPLIER
            <= float(edge.get("thinning_opacity_multiplier", -1.0))
            <= THINNING_MAXIMUM_OPACITY_MULTIPLIER
            and float(metrics.get("minimum_outer_opacity_multiplier", 0.0)) > 0.0
            and THINNING_MINIMUM_WIDTH_RATIO
            <= float(metrics.get("thinning_active_ratio", -1.0))
            <= THINNING_MAXIMUM_WIDTH_RATIO
            and THINNING_MINIMUM_OPACITY_MULTIPLIER
            <= float(metrics.get("minimum_applied_thinning_factor", -1.0))
            <= THINNING_MAXIMUM_OPACITY_MULTIPLIER
        ):
            failures.append(f"{edge_name}_partial_thinning_contract_missing")
        if (
            float(metrics.get("minimum_column_integrated_opacity_world_px", -1.0))
            < MINIMUM_COLUMN_INTEGRATED_OPACITY_WORLD_PX
        ):
            failures.append(f"{edge_name}_full_gap_exposed")
        if (
            float(metrics.get("terrain_attachment_maximum_gain", -1.0))
            < MINIMUM_TERRAIN_ATTACHMENT_MAXIMUM_GAIN
            or not 0.0
            < float(metrics.get("terrain_attachment_active_ratio", 0.0))
            <= MAXIMUM_TERRAIN_ATTACHMENT_ACTIVE_RATIO
            or float(metrics.get("terrain_attachment_mean_gain", float("inf")))
            >= float(metrics.get("terrain_attachment_maximum_gain", -1.0))
            or float(
                metrics.get("terrain_attachment_maximum_depth_world_px", float("inf"))
            )
            > TERRAIN_BITE_MAXIMUM_DEPTH_WORLD_PX
            or not 0.0
            < float(metrics.get("terrain_horizontal_active_ratio", 0.0))
            <= MAXIMUM_TERRAIN_ATTACHMENT_ACTIVE_RATIO
            or not 0.0
            < float(metrics.get("terrain_control_active_ratio", 0.0))
            <= MAXIMUM_TERRAIN_CONTROL_ACTIVE_RATIO
            or not isinstance(selected_terrain_cells, list)
            or len(selected_terrain_cells)
            != int(metrics.get("terrain_active_control_cells", -1))
            or len(selected_terrain_cells) != 1
            or any(
                not isinstance(cell, list)
                or len(cell) != 2
                or int(cell[0]) != expected_terrain_row
                or not 0 <= int(cell[1]) < HORIZONTAL_CONTROL_CELLS
                for cell in selected_terrain_cells
            )
            or not isinstance(selected_raw_scores, list)
            or len(selected_raw_scores) != len(selected_terrain_cells)
            or any(
                float(value) < TERRAIN_MINIMUM_SELECTED_FOOT_SCORE
                for value in selected_raw_scores
            )
            or not isinstance(selected_directional_deltas, list)
            or len(selected_directional_deltas) != len(selected_terrain_cells)
            or any(
                float(value) < TERRAIN_MINIMUM_SELECTED_DIRECTIONAL_DELTA
                for value in selected_directional_deltas
            )
            or not isinstance(selected_strengths, list)
            or len(selected_strengths) != len(selected_terrain_cells)
            or any(
                not TERRAIN_MINIMUM_SELECTED_STRENGTH <= float(value) <= 1.0
                for value in selected_strengths
            )
            or not isinstance(selected_capacity, list)
            or len(selected_capacity) != len(selected_terrain_cells)
            or any(not 0.0 < float(value) <= 1.0 for value in selected_capacity)
            or float(
                metrics.get("terrain_selected_distance_minimum_world_px", -1.0)
            )
            != COVERED_WORLD_PX
            or float(
                metrics.get("terrain_selected_distance_maximum_world_px", -1.0)
            )
            != EDGE_WORLD_PX - OUTER_ALPHA_GUARD_WORLD_PX
        ):
            failures.append(f"{edge_name}_terrain_attachment_disabled")
        if float(metrics.get("outer_guard_maximum_opacity", float("inf"))) > 1.0e-9:
            failures.append(f"{edge_name}_outer_alpha_guard_lost")
    cross = shape_modulation.get("cross_edge_metrics", {})
    if not isinstance(cross, dict):
        failures.append("cross_edge_metrics_missing")
    else:
        if (
            float(cross.get("minimum_primary_phase_delta_rad", -1.0))
            < MINIMUM_TOP_BOTTOM_PHASE_DELTA_RAD
        ):
            failures.append("top_bottom_phase_difference_disabled")
        if (
            float(cross.get("thinning_strong_overlap_ratio", float("inf")))
            > MAXIMUM_THINNING_STRONG_OVERLAP_RATIO
        ):
            failures.append("top_bottom_thinning_overlap_exceeded")
        if not bool(cross.get("parameter_signatures_unique", False)):
            failures.append("top_bottom_shape_signature_collision")
        if (
            float(cross.get("actual_front_absolute_correlation", float("inf")))
            > MAXIMUM_ACTUAL_FRONT_ABSOLUTE_CORRELATION
        ):
            failures.append("top_bottom_actual_fronts_correlated")
    pigment_warp = shape_modulation.get("pigment_warp", {})
    if (
        not isinstance(pigment_warp, dict)
        or float(pigment_warp.get("minimum_vertical_jacobian", -1.0))
        < MINIMUM_WARP_VERTICAL_JACOBIAN
        or int(pigment_warp.get("minimum_horizontal_control_span_texture_px", 0))
        < int(MINIMUM_HORIZONTAL_CONTROL_SPAN_WORLD_PX * TEXTURE_SCALE)
        or int(pigment_warp.get("minimum_vertical_control_span_texture_px", 0))
        < int(MINIMUM_VERTICAL_CONTROL_SPAN_WORLD_PX * TEXTURE_SCALE)
        or float(
            pigment_warp.get(
                "shared_row_displacement_p95_half_range_world_px",
                -1.0,
            )
        )
        < MINIMUM_SHARED_SEAM_P95_HALF_RANGE_WORLD_PX
        or abs(float(pigment_warp.get("source_sampling_bias_world_px", float("inf"))))
        > MAXIMUM_SOURCE_SAMPLING_BIAS_WORLD_PX
        or pigment_warp.get("one_pixel_column_operations") is not False
    ):
        failures.append("pigment_warp_folded")
    return failures


def production_shape_counterproofs(
    extended_patch: np.ndarray,
    shaped_strip: np.ndarray,
    shapes: dict[str, EdgeShapeSpec],
    base: np.ndarray,
    actual_masks: dict[str, np.ndarray],
    actual_warp_metrics: dict[str, object],
) -> dict[str, object]:
    disabled_strip, disabled_warp = warp_pigment_strip(
        extended_patch,
        shapes,
        meander_amplitude_world_px=0.0,
    )
    meander_edges = disabled_warp["edges"]
    identity_alpha = extended_patch[
        MEANDER_MARGIN_ROWS : MEANDER_MARGIN_ROWS + STRIP_HEIGHT,
        :,
        3,
    ]
    disabled_alpha = disabled_strip[..., 3]
    alpha_identity_changed_pixels = int(
        np.count_nonzero(disabled_alpha != identity_alpha)
    )
    alpha_identity_maximum_delta = int(
        np.abs(disabled_alpha.astype(np.int16) - identity_alpha.astype(np.int16)).max(
            initial=0
        )
    )
    meander_red = all(
        float(meander_edges[edge_name]["meander_maximum_absolute_world_px"])
        < MINIMUM_MEANDER_P95_HALF_RANGE_WORLD_PX
        for edge_name in ("top", "bottom")
    )
    effects: dict[str, object] = {
        "meander_disabled": {
            "production_helper": "warp_pigment_strip",
            "gate_red": meander_red,
            "production_output_changed": (
                disabled_warp["warped_rgba_sha256"]
                != actual_warp_metrics["warped_rgba_sha256"]
            ),
            "warped_rgba_sha256": disabled_warp["warped_rgba_sha256"],
            "actual_warped_rgba_sha256": actual_warp_metrics[
                "warped_rgba_sha256"
            ],
            "edges": meander_edges,
            "alpha_identity_changed_pixels": alpha_identity_changed_pixels,
            "alpha_identity_maximum_delta": alpha_identity_maximum_delta,
        }
    }
    edge_inputs = {
        "top": (shaped_strip[EDGE_PATCH_HEIGHT - 1 :], base[:EDGE_ROWS], True),
        "bottom": (shaped_strip[:EDGE_PATCH_HEIGHT], base[-EDGE_ROWS:], False),
    }
    mask_effects = {
        "thickness_disabled": {
            "thickness_variation_world_px": 0.0,
            "thinning_enabled": True,
            "terrain_opacity_gain": TERRAIN_BITE_OPACITY_GAIN,
        },
        "thinning_disabled": {
            "thickness_variation_world_px": THICKNESS_VARIATION_WORLD_PX,
            "thinning_enabled": False,
            "terrain_opacity_gain": TERRAIN_BITE_OPACITY_GAIN,
        },
        "terrain_disabled": {
            "thickness_variation_world_px": THICKNESS_VARIATION_WORLD_PX,
            "thinning_enabled": True,
            "terrain_opacity_gain": 0.0,
        },
    }
    for effect_name, arguments in mask_effects.items():
        edge_records: dict[str, object] = {}
        for edge_name, (patch, base_edge, top_edge) in edge_inputs.items():
            disabled_mask, disabled_metrics, _window = opacity_mask(
                patch,
                base_edge,
                shapes[edge_name],
                top_edge,
                **arguments,
            )
            edge_records[edge_name] = {
                "mask_float32_sha256": sha256_bytes(
                    np.ascontiguousarray(disabled_mask.astype(np.float32)).tobytes()
                ),
                "production_output_changed": not np.array_equal(
                    disabled_mask,
                    actual_masks[edge_name],
                ),
                "thickness_p95_half_range_world_px": disabled_metrics[
                    "thickness_p95_half_range_world_px"
                ],
                "thinning_active_ratio": disabled_metrics[
                    "thinning_active_ratio"
                ],
                "minimum_applied_thinning_factor": disabled_metrics[
                    "minimum_applied_thinning_factor"
                ],
                "terrain_attachment_maximum_gain": disabled_metrics[
                    "terrain_attachment_maximum_gain"
                ],
            }
        if effect_name == "thickness_disabled":
            gate_red = all(
                float(edge_records[edge_name]["thickness_p95_half_range_world_px"])
                < MINIMUM_THICKNESS_P95_HALF_RANGE_WORLD_PX
                for edge_name in ("top", "bottom")
            )
        elif effect_name == "thinning_disabled":
            gate_red = all(
                float(edge_records[edge_name]["thinning_active_ratio"])
                < THINNING_MINIMUM_WIDTH_RATIO
                and float(
                    edge_records[edge_name]["minimum_applied_thinning_factor"]
                )
                > THINNING_MAXIMUM_OPACITY_MULTIPLIER
                for edge_name in ("top", "bottom")
            )
        else:
            gate_red = all(
                float(edge_records[edge_name]["terrain_attachment_maximum_gain"])
                < MINIMUM_TERRAIN_ATTACHMENT_MAXIMUM_GAIN
                for edge_name in ("top", "bottom")
            )
        effects[effect_name] = {
            "production_helper": "opacity_mask",
            "gate_red": gate_red,
            "edges": edge_records,
        }
    expected_effects = {
        "thickness_disabled",
        "meander_disabled",
        "thinning_disabled",
        "terrain_disabled",
    }
    red_effects = sorted(
        effect_name
        for effect_name, record in effects.items()
        if isinstance(record, dict) and record.get("gate_red") is True
    )
    all_outputs_changed = all(
        (
            bool(record.get("production_output_changed", False))
            if effect_name == "meander_disabled"
            else all(
                bool(edge_record.get("production_output_changed", False))
                for edge_record in record.get("edges", {}).values()
            )
        )
        for effect_name, record in effects.items()
        if isinstance(record, dict)
    )
    if (
        set(red_effects) != expected_effects
        or not all_outputs_changed
        or alpha_identity_changed_pixels != 0
        or alpha_identity_maximum_delta != 0
    ):
        raise RuntimeError("production helper shape counterproof stopped proving RED")
    return {
        "construction": "production_helpers_effect_disabled_and_remeasured_v2",
        "shape_gate_red": True,
        "red_effects": red_effects,
        "all_production_outputs_changed": all_outputs_changed,
        "effects": effects,
        "disabled_strip_rgba_sha256": sha256_bytes(
            np.ascontiguousarray(disabled_strip).tobytes()
        ),
    }


def build_band(base: np.ndarray, source: np.ndarray, spec: BandSpec) -> tuple[np.ndarray, dict[str, object]]:
    if rgb_sha256(base) != spec.base_rgb_sha256:
        raise RuntimeError(f"{spec.output}: Z13 base RGB SHA-256 drifted")
    if body_rgb_sha256(base) != spec.immutable_body_rgb_sha256:
        raise RuntimeError(f"{spec.output}: Z13 immutable body drifted")
    _literal_strip, extended_patch, strip_provenance = crop_strip(
        source,
        spec.strip,
        spec.source_sampling_bias_world_px,
    )
    shapes = edge_shape_specs(spec.output)
    strip, pigment_warp_metrics = warp_pigment_strip(extended_patch, shapes)
    pigment_warp_metrics["source_sampling_bias_world_px"] = (
        spec.source_sampling_bias_world_px
    )
    pigment_warp_metrics["source_sampling_bias_texture_px"] = (
        spec.source_sampling_bias_world_px * TEXTURE_SCALE
    )
    bottom_patch = strip[:EDGE_PATCH_HEIGHT]
    top_patch = strip[EDGE_PATCH_HEIGHT - 1 :]
    bottom_mask, bottom_shape_metrics, bottom_thinning_window = opacity_mask(
        bottom_patch,
        base[-EDGE_ROWS:],
        shapes["bottom"],
        False,
    )
    top_mask, top_shape_metrics, top_thinning_window = opacity_mask(
        top_patch,
        base[:EDGE_ROWS],
        shapes["top"],
        True,
    )
    top_front_profile = feather_front_depth_profile(top_mask, True).astype(np.float64)
    bottom_front_profile = feather_front_depth_profile(bottom_mask, False).astype(
        np.float64
    )
    for front_profile, front_metrics in (
        (top_front_profile, top_shape_metrics),
        (bottom_front_profile, bottom_shape_metrics),
    ):
        front_p05, front_p95 = np.percentile(front_profile, (5.0, 95.0))
        front_metrics["actual_front_p05_depth_texture_px"] = float(front_p05)
        front_metrics["actual_front_p95_depth_texture_px"] = float(front_p95)
        front_metrics["actual_front_p95_half_range_world_px"] = float(
            (front_p95 - front_p05) * 0.5 / TEXTURE_SCALE
        )
    shape_edges: dict[str, object] = {}
    for edge_name, mask_shape_metrics in (
        ("top", top_shape_metrics),
        ("bottom", bottom_shape_metrics),
    ):
        payload = edge_shape_payload(shapes[edge_name])
        payload["metrics"] = {
            **mask_shape_metrics,
            **pigment_warp_metrics["edges"][edge_name],
        }
        shape_edges[edge_name] = payload
    thickness_phase_delta = circular_phase_delta(
        shapes["top"].thickness_phase_rad,
        shapes["bottom"].thickness_phase_rad,
    )
    meander_phase_delta = circular_phase_delta(
        shapes["top"].meander_phase_rad,
        shapes["bottom"].meander_phase_rad,
    )
    top_front_centered = top_front_profile - float(top_front_profile.mean())
    bottom_front_centered = bottom_front_profile - float(bottom_front_profile.mean())
    front_correlation_denominator = float(
        np.sqrt(
            float(np.square(top_front_centered).sum())
            * float(np.square(bottom_front_centered).sum())
        )
    )
    actual_front_absolute_correlation = (
        abs(
            float(
                np.dot(top_front_centered, bottom_front_centered)
                / front_correlation_denominator
            )
        )
        if front_correlation_denominator > 1.0e-9
        else 1.0
    )
    cross_edge_metrics = {
        "thickness_primary_phase_delta_rad": thickness_phase_delta,
        "meander_primary_phase_delta_rad": meander_phase_delta,
        "minimum_primary_phase_delta_rad": min(
            thickness_phase_delta,
            meander_phase_delta,
        ),
        "thinning_strong_overlap_ratio": float(
            np.mean(
                (top_thinning_window >= 0.5)
                & (bottom_thinning_window >= 0.5)
            )
        ),
        "parameter_signatures_unique": (
            canonical_json_sha256(edge_shape_payload(shapes["top"]))
            != canonical_json_sha256(edge_shape_payload(shapes["bottom"]))
        ),
        "actual_front_absolute_correlation": actual_front_absolute_correlation,
    }
    shape_counterproof = production_shape_counterproofs(
        extended_patch,
        strip,
        shapes,
        base,
        {"top": top_mask, "bottom": bottom_mask},
        pigment_warp_metrics,
    )
    shape_modulation = {
        "method": "fixed_seed_coarse_mesh_landform_mist_shape_v2",
        "field_construction": {
            "primary_cycles": PRIMARY_FIELD_CYCLES,
            "secondary_cycles": SECONDARY_FIELD_CYCLES,
            "minimum_wavelength_world_px": MINIMUM_FIELD_WAVELENGTH_WORLD_PX,
            "minimum_horizontal_control_span_world_px": (
                MINIMUM_HORIZONTAL_CONTROL_SPAN_WORLD_PX
            ),
            "minimum_vertical_control_span_world_px": (
                MINIMUM_VERTICAL_CONTROL_SPAN_WORLD_PX
            ),
            "horizontal_control_cells": HORIZONTAL_CONTROL_CELLS,
            "edge_vertical_control_cells": EDGE_VERTICAL_CONTROL_CELLS,
            "periodic_halo_control_cells": HORIZONTAL_CONTROL_HALO_CELLS,
            "rasterization": "pillow_bicubic_from_coarse_control_plane",
            "one_pixel_column_operations": False,
            "per_column_adjustment": False,
        },
        "pigment_warp": {
            key: value
            for key, value in pigment_warp_metrics.items()
            if key != "edges"
        },
        "edges": shape_edges,
        "cross_edge_metrics": cross_edge_metrics,
        "parameter_table_sha256": canonical_json_sha256(shape_table_payload()),
        "parallel_band_counterproof": shape_counterproof,
    }
    shape_failures = shape_gate_failures(shape_modulation)
    if shape_failures:
        raise RuntimeError(f"{spec.output}: mist shape gates failed: {shape_failures}")
    butt, tone = tone_and_composite_strip(
        base,
        strip,
        bottom_mask,
        top_mask,
        shapes,
        spec.terrain_bridge_detail_gain,
        spec.strip.detail_gain,
        float(strip_provenance["approved_source_alpha_weighted_luma_std"]),
        float(
            strip_provenance["meander_source"][
                "effective_center_alpha_weighted_luma_std"
            ]
        ),
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
        raise RuntimeError(f"{spec.output}: core opacity fell below 1.0")
    if float(masks["core_maximum"]) > MAXIMUM_CORE_OPACITY:
        raise RuntimeError(f"{spec.output}: core opacity exceeded 1.0")
    if float(masks["minimum_opacity_through_world_px_26"]) < MINIMUM_COVERAGE_THROUGH_26:
        raise RuntimeError(f"{spec.output}: rejected fill remains exposed before 26px")
    if float(masks["feather_column_profile_residual_std"]) < MINIMUM_RAGGED_MASK_RESIDUAL_STD:
        raise RuntimeError(f"{spec.output}: cloud-brush feather became a straight gradient")
    for edge_name in ("top", "bottom"):
        front = masks[f"{edge_name}_feather_front"]
        if float(front["depth_std_texture_px"]) < MINIMUM_FEATHER_FRONT_STD_TEXTURE_PX:
            raise RuntimeError(
                f"{spec.output}: {edge_name} mist front lost brush irregularity: {front}"
            )
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
        "fixed_seed_shape_table_sha256": canonical_json_sha256(shape_table_payload()),
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
        "feather_mask": "fixed_seed_low_frequency_landform_feather_v3",
        "shape_modulation": shape_modulation,
        "tone": tone,
        "mask_metrics": masks,
        "shared_textured_seam": {
            "method": "overlap_one_unified_coarse_mesh_row_from_contiguous_strip",
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
            "thickness_variation_ratio": THICKNESS_VARIATION_RATIO,
            "nominal_shaped_feather_world_px": NOMINAL_SHAPED_FEATHER_WORLD_PX,
            "minimum_shaped_feather_world_px": MINIMUM_SHAPED_FEATHER_WORLD_PX,
            "maximum_shaped_feather_world_px": MAXIMUM_SHAPED_FEATHER_WORLD_PX,
            "outer_alpha_guard_world_px": OUTER_ALPHA_GUARD_WORLD_PX,
            "minimum_thickness_p95_half_range_world_px": (
                MINIMUM_THICKNESS_P95_HALF_RANGE_WORLD_PX
            ),
            "meander_amplitude_world_px": MEANDER_AMPLITUDE_WORLD_PX,
            "minimum_meander_p95_half_range_world_px": (
                MINIMUM_MEANDER_P95_HALF_RANGE_WORLD_PX
            ),
            "minimum_field_wavelength_world_px": MINIMUM_FIELD_WAVELENGTH_WORLD_PX,
            "minimum_horizontal_control_span_world_px": (
                MINIMUM_HORIZONTAL_CONTROL_SPAN_WORLD_PX
            ),
            "minimum_vertical_control_span_world_px": (
                MINIMUM_VERTICAL_CONTROL_SPAN_WORLD_PX
            ),
            "horizontal_control_cells": HORIZONTAL_CONTROL_CELLS,
            "edge_vertical_control_cells": EDGE_VERTICAL_CONTROL_CELLS,
            "periodic_halo_control_cells": HORIZONTAL_CONTROL_HALO_CELLS,
            "meander_source_margin_world_px": MEANDER_MARGIN_WORLD_PX,
            "maximum_source_sampling_bias_world_px": (
                MAXIMUM_SOURCE_SAMPLING_BIAS_WORLD_PX
            ),
            "shared_seam_residual_amplitude_world_px": (
                MEANDER_SEAM_RESIDUAL_AMPLITUDE_WORLD_PX
            ),
            "minimum_shared_seam_p95_half_range_world_px": (
                MINIMUM_SHARED_SEAM_P95_HALF_RANGE_WORLD_PX
            ),
            "minimum_actual_front_p95_half_range_world_px": (
                MINIMUM_ACTUAL_FRONT_P95_HALF_RANGE_WORLD_PX
            ),
            "maximum_actual_front_absolute_correlation": (
                MAXIMUM_ACTUAL_FRONT_ABSOLUTE_CORRELATION
            ),
            "minimum_thinning_width_ratio": THINNING_MINIMUM_WIDTH_RATIO,
            "maximum_thinning_width_ratio": THINNING_MAXIMUM_WIDTH_RATIO,
            "thinning_active_window_threshold": THINNING_ACTIVE_WINDOW_THRESHOLD,
            "minimum_thinning_opacity_multiplier": (
                THINNING_MINIMUM_OPACITY_MULTIPLIER
            ),
            "maximum_thinning_opacity_multiplier": (
                THINNING_MAXIMUM_OPACITY_MULTIPLIER
            ),
            "minimum_terrain_attachment_maximum_gain": (
                MINIMUM_TERRAIN_ATTACHMENT_MAXIMUM_GAIN
            ),
            "maximum_terrain_attachment_active_ratio": (
                MAXIMUM_TERRAIN_ATTACHMENT_ACTIVE_RATIO
            ),
            "maximum_terrain_attachment_depth_world_px": (
                TERRAIN_BITE_MAXIMUM_DEPTH_WORLD_PX
            ),
            "terrain_control_quantile": TERRAIN_CONTROL_QUANTILE,
            "maximum_terrain_control_active_ratio": (
                MAXIMUM_TERRAIN_CONTROL_ACTIVE_RATIO
            ),
            "minimum_terrain_selected_strength": (
                TERRAIN_MINIMUM_SELECTED_STRENGTH
            ),
            "minimum_terrain_selected_foot_score": (
                TERRAIN_MINIMUM_SELECTED_FOOT_SCORE
            ),
            "minimum_terrain_selected_directional_delta": (
                TERRAIN_MINIMUM_SELECTED_DIRECTIONAL_DELTA
            ),
            "terrain_selected_control_cells_per_edge": 1,
            "minimum_top_bottom_phase_delta_rad": (
                MINIMUM_TOP_BOTTOM_PHASE_DELTA_RAD
            ),
            "maximum_thinning_strong_overlap_ratio": (
                MAXIMUM_THINNING_STRONG_OVERLAP_RATIO
            ),
            "minimum_column_integrated_opacity_world_px": (
                MINIMUM_COLUMN_INTEGRATED_OPACITY_WORLD_PX
            ),
            "minimum_warp_vertical_jacobian": MINIMUM_WARP_VERTICAL_JACOBIAN,
            "terrain_bridge_anchor_world_px": TERRAIN_BRIDGE_ANCHOR_WORLD_PX,
            "terrain_bridge_horizontal_control_cells": HORIZONTAL_CONTROL_CELLS,
            "terrain_bridge_vertical_control_cells": (
                TERRAIN_BRIDGE_VERTICAL_CONTROL_CELLS
            ),
            "terrain_bridge_reveal_minimum_world_px": (
                TERRAIN_BRIDGE_REVEAL_MINIMUM_WORLD_PX
            ),
            "terrain_bridge_reveal_maximum_world_px": (
                TERRAIN_BRIDGE_REVEAL_MAXIMUM_WORLD_PX
            ),
            "minimum_terrain_bridge_whole_anchor_detail_gain": (
                TERRAIN_BRIDGE_WHOLE_ANCHOR_DETAIL_GAIN
            ),
            "maximum_terrain_bridge_whole_anchor_detail_gain": (
                TERRAIN_BRIDGE_MAXIMUM_WHOLE_ANCHOR_DETAIL_GAIN
            ),
            "terrain_bridge_composite_luma_bias": (
                TERRAIN_BRIDGE_COMPOSITE_LUMA_BIAS
            ),
            "visible_pigment_nominal_half_width_world_px": (
                VISIBLE_PIGMENT_NOMINAL_HALF_WIDTH_WORLD_PX
            ),
            "visible_pigment_maximum_mix": VISIBLE_PIGMENT_MAXIMUM_MIX,
            "visible_haze_floor": VISIBLE_HAZE_FLOOR,
            "visible_thinning_factor_exponent": (
                VISIBLE_THINNING_FACTOR_EXPONENT
            ),
            "visible_shape_seam_transition_world_px": (
                VISIBLE_SHAPE_SEAM_TRANSITION_WORLD_PX
            ),
            "visible_edge_veil_transition_world_px": (
                VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX
            ),
            "visible_edge_veil_minimum_factor": (
                VISIBLE_EDGE_VEIL_MINIMUM_FACTOR
            ),
            "visible_edge_centerline_divergence_world_px": (
                VISIBLE_EDGE_CENTERLINE_DIVERGENCE_WORLD_PX
            ),
            "visible_edge_centerline_maximum_absolute_world_px": (
                VISIBLE_EDGE_CENTERLINE_MAXIMUM_ABSOLUTE_WORLD_PX
            ),
            "minimum_actual_applied_thinning_active_ratio": (
                THINNING_MINIMUM_WIDTH_RATIO
            ),
            "maximum_actual_applied_thinning_active_ratio": (
                THINNING_MAXIMUM_WIDTH_RATIO
            ),
            "maximum_actual_applied_thinning_strong_overlap_ratio": (
                MAXIMUM_THINNING_STRONG_OVERLAP_RATIO
            ),
            "maximum_actual_applied_thinning_absolute_correlation": (
                MAXIMUM_ACTUAL_APPLIED_THINNING_ABSOLUTE_CORRELATION
            ),
            "actual_applied_thinning_shared_seam_rows_exact": True,
            "actual_applied_thinning_signatures_unique": True,
            "maximum_visible_edge_centerline_residual_absolute_correlation": (
                MAXIMUM_VISIBLE_EDGE_CENTERLINE_RESIDUAL_ABSOLUTE_CORRELATION
            ),
            "maximum_visible_edge_veil_absolute_correlation": (
                MAXIMUM_VISIBLE_EDGE_VEIL_ABSOLUTE_CORRELATION
            ),
            "maximum_visible_edge_veil_p05": MAXIMUM_VISIBLE_EDGE_VEIL_P05,
            "minimum_visible_edge_veil_p95": MINIMUM_VISIBLE_EDGE_VEIL_P95,
            "visible_thinning_terrain_detail_gain": (
                VISIBLE_THINNING_TERRAIN_DETAIL_GAIN
            ),
            "visible_shared_reference_detail_gain": (
                VISIBLE_SHARED_REFERENCE_DETAIL_GAIN
            ),
            "visible_centerline_target_p95_half_range_world_px": (
                VISIBLE_CENTERLINE_TARGET_P95_HALF_RANGE_WORLD_PX
            ),
            "minimum_visible_centerline_p95_half_range_world_px": (
                MINIMUM_VISIBLE_CENTERLINE_P95_HALF_RANGE_WORLD_PX
            ),
            "maximum_visible_centerline_absolute_world_px": (
                MAXIMUM_VISIBLE_CENTERLINE_ABSOLUTE_WORLD_PX
            ),
            "minimum_visible_centerline_valid_ratio": (
                MINIMUM_VISIBLE_CENTERLINE_VALID_RATIO
            ),
            "maximum_full_width_pale_run_world_px": (
                MAXIMUM_FULL_WIDTH_PALE_RUN_WORLD_PX
            ),
            "maximum_core_local_luma_p95_gain": (
                MAXIMUM_CORE_LOCAL_LUMA_P95_GAIN
            ),
            "maximum_core_local_luma_gain": MAXIMUM_CORE_LOCAL_LUMA_GAIN,
            "minimum_thinned_terrain_detail_ratio": (
                MINIMUM_THINNED_TERRAIN_DETAIL_RATIO
            ),
            "minimum_visible_thinned_peak_ink_mix": (
                MINIMUM_VISIBLE_THINNED_PEAK_INK_MIX
            ),
            "minimum_visible_haze_floor": MINIMUM_VISIBLE_HAZE_FLOOR,
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
    expected_sampling_bias_rows = int(
        round(spec.source_sampling_bias_world_px * TEXTURE_SCALE)
    )
    expected_meander_rect = [
        spec.strip.x,
        spec.strip.y - MEANDER_MARGIN_ROWS + expected_sampling_bias_rows,
        spec.strip.width,
        STRIP_HEIGHT + MEANDER_MARGIN_ROWS * 2,
    ]
    expected_effective_center_rect = [
        spec.strip.x,
        spec.strip.y + expected_sampling_bias_rows,
        spec.strip.width,
        STRIP_HEIGHT,
    ]
    meander_source = strip.get("meander_source", {}) if isinstance(strip, dict) else {}
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
        or contract.get("fixed_seed_shape_table_sha256")
        != canonical_json_sha256(shape_table_payload())
        or not isinstance(strip, dict)
        or strip.get("rect") != expected_rect
        or float(strip.get("detail_gain", -1.0)) != spec.strip.detail_gain
        or not isinstance(meander_source, dict)
        or meander_source.get("rect") != expected_meander_rect
        or meander_source.get("effective_center_rect")
        != expected_effective_center_rect
        or float(meander_source.get("source_sampling_bias_world_px", float("inf")))
        != spec.source_sampling_bias_world_px
        or int(meander_source.get("source_sampling_bias_texture_px", 2**31))
        != expected_sampling_bias_rows
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
    shape_modulation = contract.get("shape_modulation", {})
    if not isinstance(shape_modulation, dict):
        raise RuntimeError(f"{spec.output}: final shape modulation missing")
    if (
        shape_modulation.get("parameter_table_sha256")
        != canonical_json_sha256(shape_table_payload())
        or shape_gate_failures(shape_modulation)
    ):
        raise RuntimeError(f"{spec.output}: final shape modulation gates drifted")
    expected_shapes = edge_shape_specs(spec.output)
    pigment_warp = shape_modulation.get("pigment_warp", {})
    if (
        not isinstance(pigment_warp, dict)
        or float(pigment_warp.get("source_sampling_bias_world_px", float("inf")))
        != spec.source_sampling_bias_world_px
        or float(pigment_warp.get("source_sampling_bias_texture_px", float("inf")))
        != expected_sampling_bias_rows
    ):
        raise RuntimeError(f"{spec.output}: final source sampling bias drifted")
    shape_edges = shape_modulation.get("edges", {})
    if not isinstance(shape_edges, dict):
        raise RuntimeError(f"{spec.output}: final shape edge parameters missing")
    for edge_name in ("top", "bottom"):
        edge = shape_edges.get(edge_name, {})
        if not isinstance(edge, dict):
            raise RuntimeError(f"{spec.output}: final {edge_name} shape missing")
        expected_payload = edge_shape_payload(expected_shapes[edge_name])
        if any(edge.get(key) != value for key, value in expected_payload.items()):
            raise RuntimeError(f"{spec.output}: final {edge_name} shape parameters drifted")
    counterproof = shape_modulation.get("parallel_band_counterproof", {})
    expected_counterproof_effects = {
        "thickness_disabled",
        "meander_disabled",
        "thinning_disabled",
        "terrain_disabled",
    }
    counterproof_effects = (
        counterproof.get("effects", {}) if isinstance(counterproof, dict) else {}
    )
    counterproof_red_effects = (
        counterproof.get("red_effects", []) if isinstance(counterproof, dict) else []
    )
    counterproof_effects_valid = (
        isinstance(counterproof_effects, dict)
        and set(counterproof_effects) == expected_counterproof_effects
        and all(
            isinstance(effect, dict) and effect.get("gate_red") is True
            for effect in counterproof_effects.values()
        )
    )
    if counterproof_effects_valid:
        meander_effect = counterproof_effects["meander_disabled"]
        mask_effects = (
            counterproof_effects["thickness_disabled"],
            counterproof_effects["thinning_disabled"],
            counterproof_effects["terrain_disabled"],
        )
        counterproof_effects_valid = (
            meander_effect.get("production_helper") == "warp_pigment_strip"
            and meander_effect.get("production_output_changed") is True
            and int(meander_effect.get("alpha_identity_changed_pixels", -1)) == 0
            and int(meander_effect.get("alpha_identity_maximum_delta", -1)) == 0
            and all(
                effect.get("production_helper") == "opacity_mask"
                and isinstance(effect.get("edges"), dict)
                and set(effect["edges"]) == {"top", "bottom"}
                and all(
                    isinstance(edge, dict)
                    and edge.get("production_output_changed") is True
                    for edge in effect["edges"].values()
                )
                for effect in mask_effects
            )
        )
    if (
        not isinstance(counterproof, dict)
        or counterproof.get("construction")
        != "production_helpers_effect_disabled_and_remeasured_v2"
        or counterproof.get("shape_gate_red") is not True
        or counterproof.get("all_production_outputs_changed") is not True
        or set(counterproof_red_effects) != expected_counterproof_effects
        or not counterproof_effects_valid
    ):
        raise RuntimeError(f"{spec.output}: parallel-band RED counterproof drifted")
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
    validate_shape_table()
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
