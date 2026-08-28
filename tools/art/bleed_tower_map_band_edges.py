#!/usr/bin/env python3
"""Measure and replace generated bright edge bleed in Tower map band x4 PNGs.

The approved interior starts where the downsampled world row first has both
mean luminance below 200 and horizontal detail sigma above 18. Only the rows
outside that boundary are replaced. They receive a reflected copy of the
adjacent interior block, so the operation creates no new art pixels and does
not introduce a single-row vertical smear.
"""

from __future__ import annotations

import argparse
import hashlib
import json
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


@dataclass(frozen=True)
class BandSpec:
    output: str
    top_world_px: int
    bottom_world_px: int
    original_output_sha256: str
    interior_rgb_sha256: str


BAND_SPECS = (
    BandSpec(
        "human_realm_01_mountain_rev2_x4.png",
        21,
        15,
        "8d88d76c81c76a452f764535e059f9d563f3a46f856678bba256d4935477cdac",
        "20695482b205d14ff674903db86c02c60ce66a87d9daa3d031eec5d13632bb29",
    ),
    BandSpec(
        "human_realm_02_village_rev2_x4.png",
        24,
        22,
        "bd3688eb35b7ef3ee16b2baf71d29e7619e5ac171a2856f55df9fabc1339924d",
        "aadcd25cf3a5ae0de5ef354f39352145d803efac503665a67986e7e53d1acfba",
    ),
    BandSpec(
        "human_realm_03_river_rev2_x4.png",
        21,
        15,
        "7aaafbf79d395d6f373bef900ebbe1ab55941bbc2f9950117d58701fa33eb881",
        "c05f1f7e01f3c250e0426dc44a1a5c263b8ff42861c2b3eaac2428a47197f178",
    ),
    BandSpec(
        "immortal_realm_01_islands_rev2_x4.png",
        26,
        23,
        "a203575517828b8f3ad46e784a5bef43451cb9536b5079283cbbf6bcc65ea672",
        "afd3d6c79bf204485951f4d0a82f7aca539828cf0540bb6791e1bc40e66f1e53",
    ),
    BandSpec(
        "immortal_realm_02_cloud_cranes_rev2_x4.png",
        18,
        15,
        "81d6c70f6d2fdd4b47559a4ffce4acd3e6ea0a158e11cb8b613ee5649f178878",
        "1ecb7b2c440a4cff74772f7479f2beea7066878d548563acd57c54c84b365279",
    ),
    BandSpec(
        "immortal_realm_03_pavilions_rev2_x4.png",
        25,
        26,
        "e37ac5043817d3dde22a779c0a99d47bf295503eec26f779cbb53f0a50126a3f",
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


def _mirrored_edge_bleed(pixels: np.ndarray, spec: BandSpec) -> np.ndarray:
    top_rows, bottom_rows = _edge_rows(spec)
    result = pixels.copy()
    result[:top_rows] = result[top_rows : top_rows * 2][::-1]
    height = result.shape[0]
    result[height - bottom_rows :] = result[
        height - bottom_rows * 2 : height - bottom_rows
    ][::-1]
    return result


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
    temporary = path.with_suffix(path.suffix + ".z11.tmp")
    Image.fromarray(pixels).save(
        temporary,
        format="PNG",
        compress_level=9,
        optimize=False,
    )
    temporary.replace(path)


def _update_manifest(asset_root: Path, cleaned_sha_by_name: dict[str, str]) -> None:
    manifest_path = asset_root / MANIFEST_NAME
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    records = {str(record["output"]): record for record in manifest["assets"]}
    for spec in BAND_SPECS:
        record = records[spec.output]
        record["output_sha256"] = cleaned_sha_by_name[spec.output]
        record["edge_bleed"] = {
            "method": "mirrored_adjacent_inner_rows",
            "texture_scale": TEXTURE_SCALE,
            "top_world_px": spec.top_world_px,
            "bottom_world_px": spec.bottom_world_px,
            "body_luma_threshold": BODY_LUMA_THRESHOLD,
            "body_detail_threshold": BODY_DETAIL_THRESHOLD,
            "original_output_sha256": spec.original_output_sha256,
            "interior_rgb_sha256": spec.interior_rgb_sha256,
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
    cleaned_sha_by_name: dict[str, str] = {}
    for spec in BAND_SPECS:
        path = asset_root / spec.output
        pixels = _load_rgb(path)
        interior_before = _interior_sha256(pixels, spec)
        if interior_before != spec.interior_rgb_sha256:
            raise RuntimeError(
                f"{spec.output}: approved interior hash drifted: {interior_before}"
            )
        if args.apply:
            pixels = _mirrored_edge_bleed(pixels, spec)
            if _interior_sha256(pixels, spec) != interior_before:
                raise RuntimeError(f"{spec.output}: edge bleed touched interior pixels")
            _write_png(path, pixels)
            pixels = _load_rgb(path)
        _validate_bleed(pixels, spec)
        cleaned_sha = _file_sha256(path)
        cleaned_sha_by_name[spec.output] = cleaned_sha
        print(
            f"{spec.output} top={spec.top_world_px}px "
            f"[{_profile_summary(pixels, spec.top_world_px, False)}] "
            f"bottom={spec.bottom_world_px}px "
            f"[{_profile_summary(pixels, spec.bottom_world_px, True)}] "
            f"interior_sha256={interior_before} output_sha256={cleaned_sha}"
        )

    common_path = asset_root / COMMON_PAPER_NAME
    common = _load_rgb(common_path)
    print(
        f"{COMMON_PAPER_NAME} unchanged output_sha256={_file_sha256(common_path)} "
        f"top=[{_profile_summary(common, 8, False)}] "
        f"bottom=[{_profile_summary(common, 8, True)}]"
    )
    if args.apply:
        _update_manifest(asset_root, cleaned_sha_by_name)
    print("tower_map_band_edge_bleed: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
