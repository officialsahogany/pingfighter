"""Deterministically rotate only the approved red gauge-band pixels to blue."""

from __future__ import annotations

import argparse
import colorsys
import hashlib
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = (
    PROJECT_ROOT
    / "assets/ui/tower_training_gauge/tower_training_gauge_tick_imagegen_v1.png"
)
DEFAULT_OUTPUT = (
    PROJECT_ROOT
    / "assets/ui/tower_training_gauge/tower_training_gauge_tick_blue_v1.png"
)
EXPECTED_SOURCE_SHA256 = (
    "ce4f992983ac8cc9b8a01e64736ca64dd206dbac6c9e2576044fb976c6d17eb4"
)
EXPECTED_SIZE = (123, 517)
EXPECTED_CHANGED_PIXEL_COUNT = 7218
EXPECTED_CHANGED_BOUNDS = (18, 208, 103, 317)
MIN_SATURATION = 0.30
MIN_VALUE = 20.0 / 255.0
RED_HUE_MAX_DEGREES = 18.0
RED_HUE_MIN_DEGREES = 342.0
RED_TO_BLUE_ROTATION_DEGREES = 220.0


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _is_approved_red_pixel(
    x: int,
    y: int,
    red: int,
    green: int,
    blue: int,
    alpha: int,
) -> bool:
    min_x, min_y, max_x, max_y = EXPECTED_CHANGED_BOUNDS
    if not (min_x <= x <= max_x and min_y <= y <= max_y):
        return False
    if alpha == 0:
        return False
    hue, saturation, value = colorsys.rgb_to_hsv(
        red / 255.0,
        green / 255.0,
        blue / 255.0,
    )
    hue_degrees = hue * 360.0
    return (
        saturation >= MIN_SATURATION
        and value >= MIN_VALUE
        and (
            hue_degrees <= RED_HUE_MAX_DEGREES
            or hue_degrees >= RED_HUE_MIN_DEGREES
        )
    )


def _rotate_red_to_blue(red: int, green: int, blue: int) -> tuple[int, int, int]:
    hue, saturation, value = colorsys.rgb_to_hsv(
        red / 255.0,
        green / 255.0,
        blue / 255.0,
    )
    rotated_hue = (hue + RED_TO_BLUE_ROTATION_DEGREES / 360.0) % 1.0
    rotated = colorsys.hsv_to_rgb(rotated_hue, saturation, value)
    return tuple(round(channel * 255.0) for channel in rotated)


def recolor(source_path: Path, output_path: Path) -> None:
    source_hash = _sha256(source_path)
    if source_hash != EXPECTED_SOURCE_SHA256:
        raise RuntimeError(
            f"source SHA-256 drifted: expected {EXPECTED_SOURCE_SHA256}, got {source_hash}"
        )

    source = Image.open(source_path).convert("RGBA")
    if source.size != EXPECTED_SIZE:
        raise RuntimeError(f"source size drifted: expected {EXPECTED_SIZE}, got {source.size}")

    output = source.copy()
    changed_points: list[tuple[int, int]] = []
    for y in range(source.height):
        for x in range(source.width):
            pixel = source.getpixel((x, y))
            red, green, blue, alpha = pixel
            if not _is_approved_red_pixel(x, y, red, green, blue, alpha):
                continue
            rotated_red, rotated_green, rotated_blue = _rotate_red_to_blue(
                red,
                green,
                blue,
            )
            output.putpixel(
                (x, y),
                (rotated_red, rotated_green, rotated_blue, alpha),
            )
            changed_points.append((x, y))

    changed_bounds = (
        min(point[0] for point in changed_points),
        min(point[1] for point in changed_points),
        max(point[0] for point in changed_points),
        max(point[1] for point in changed_points),
    )
    if len(changed_points) != EXPECTED_CHANGED_PIXEL_COUNT:
        raise RuntimeError(
            "red-band mask drifted: "
            f"expected {EXPECTED_CHANGED_PIXEL_COUNT} pixels, got {len(changed_points)}"
        )
    if changed_bounds != EXPECTED_CHANGED_BOUNDS:
        raise RuntimeError(
            "red-band bounds drifted: "
            f"expected {EXPECTED_CHANGED_BOUNDS}, got {changed_bounds}"
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output.save(output_path, format="PNG", compress_level=9, optimize=False)
    decoded = Image.open(output_path).convert("RGBA")
    if decoded.size != source.size:
        raise RuntimeError("saved blue tick did not retain the source canvas")
    for y in range(source.height):
        for x in range(source.width):
            source_pixel = source.getpixel((x, y))
            output_pixel = decoded.getpixel((x, y))
            if source_pixel[3] != output_pixel[3]:
                raise RuntimeError(f"alpha changed at {(x, y)}")
            if (
                not _is_approved_red_pixel(x, y, *source_pixel)
                and source_pixel != output_pixel
            ):
                raise RuntimeError(f"non-red gold/wood pixel changed at {(x, y)}")

    print(
        "recolor_tower_training_gauge_tick_blue: "
        f"changed={len(changed_points)} bounds={changed_bounds} "
        f"sha256={_sha256(output_path)}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    recolor(args.source.resolve(), args.output.resolve())


if __name__ == "__main__":
    main()
