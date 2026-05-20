# -*- coding: utf-8 -*-
"""Deterministic postprocess helper for character-select Live2D-style sheets.

This tool is intentionally conservative: it preserves frame count, canvas
size, alpha, and per-frame placement by default, then applies a mild
color/contrast/sharpness cleanup pass. It can read either an existing packed
sheet or a directory of PNG frames and can write a packed sheet, a frame
sequence, a QA GIF, and a small manifest.
"""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import asdict, dataclass
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter


Image.MAX_IMAGE_PIXELS = None


@dataclass(frozen=True)
class Preset:
    color: float
    contrast: float
    brightness: float
    sharpness: float
    unsharp_radius: float
    unsharp_percent: int
    unsharp_threshold: int


PRESETS: dict[str, Preset] = {
    "none": Preset(1.0, 1.0, 1.0, 1.0, 0.0, 0, 0),
    # A light cleanup matching the external retouch direction without
    # changing identity, posture, or animation timing.
    "soft_cleanup": Preset(1.02, 1.035, 1.0, 1.04, 0.7, 45, 3),
    "crisp_cleanup": Preset(1.035, 1.06, 1.0, 1.08, 0.85, 70, 3),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Postprocess Live2D-style PNG sheets or frame sequences.",
    )
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--sheet", type=Path, help="Input packed PNG sheet.")
    source.add_argument("--sequence-dir", type=Path, help="Input PNG frame directory.")
    parser.add_argument("--cols", type=int, help="Sheet columns.")
    parser.add_argument("--rows", type=int, help="Sheet rows.")
    parser.add_argument("--count", type=int, help="Frame count to read/write.")
    parser.add_argument(
        "--target-count",
        type=int,
        help="Pad by duplicating the last frame until this count is reached.",
    )
    parser.add_argument(
        "--preset",
        choices=sorted(PRESETS),
        default="soft_cleanup",
        help="Cleanup preset. Default: soft_cleanup.",
    )
    parser.add_argument("--color", type=float, help="Override preset color multiplier.")
    parser.add_argument("--contrast", type=float, help="Override preset contrast multiplier.")
    parser.add_argument("--brightness", type=float, help="Override preset brightness multiplier.")
    parser.add_argument("--sharpness", type=float, help="Override preset sharpness multiplier.")
    parser.add_argument("--out-sheet", type=Path, help="Output packed PNG sheet.")
    parser.add_argument("--out-dir", type=Path, help="Output PNG frame directory.")
    parser.add_argument("--gif", type=Path, help="Output preview GIF.")
    parser.add_argument("--gif-size", type=int, default=512, help="Preview GIF square size.")
    parser.add_argument("--gif-ms", type=int, default=33, help="Preview GIF frame duration.")
    parser.add_argument("--manifest", type=Path, help="Output manifest JSON.")
    return parser.parse_args()


def require_sheet_shape(args: argparse.Namespace) -> tuple[int, int, int]:
    if args.cols is None or args.rows is None:
        raise SystemExit("--cols and --rows are required when reading or writing sheets")
    max_count = args.cols * args.rows
    count = args.count if args.count is not None else max_count
    if count < 1 or count > max_count:
        raise SystemExit(f"--count must be between 1 and cols*rows ({max_count})")
    return args.cols, args.rows, count


def load_sheet_frames(path: Path, cols: int, rows: int, count: int) -> list[Image.Image]:
    sheet = Image.open(path).convert("RGBA")
    cell_w = sheet.width // cols
    cell_h = sheet.height // rows
    frames: list[Image.Image] = []
    for index in range(count):
        col = index % cols
        row = index // cols
        frames.append(
            sheet.crop(
                (
                    col * cell_w,
                    row * cell_h,
                    (col + 1) * cell_w,
                    (row + 1) * cell_h,
                )
            )
        )
    return frames


def load_sequence_frames(path: Path, count: int | None) -> list[Image.Image]:
    files = sorted(path.glob("*.png"))
    if not files:
        raise SystemExit(f"No PNG frames found in {path}")
    if count is not None:
        files = files[:count]
    return [Image.open(file_path).convert("RGBA") for file_path in files]


def padded_frames(frames: list[Image.Image], target_count: int | None) -> list[Image.Image]:
    if target_count is None:
        return frames
    if target_count < len(frames):
        raise SystemExit("--target-count cannot be smaller than the loaded frame count")
    if not frames:
        raise SystemExit("Cannot pad an empty frame list")
    output = list(frames)
    while len(output) < target_count:
        output.append(output[-1].copy())
    return output


def apply_cleanup(frame: Image.Image, preset: Preset) -> Image.Image:
    rgba = frame.convert("RGBA")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=rgba.getchannel("A"))
    if preset.color != 1.0:
        rgb = ImageEnhance.Color(rgb).enhance(preset.color)
    if preset.contrast != 1.0:
        rgb = ImageEnhance.Contrast(rgb).enhance(preset.contrast)
    if preset.brightness != 1.0:
        rgb = ImageEnhance.Brightness(rgb).enhance(preset.brightness)
    if preset.sharpness != 1.0:
        rgb = ImageEnhance.Sharpness(rgb).enhance(preset.sharpness)
    if preset.unsharp_percent > 0 and preset.unsharp_radius > 0.0:
        rgb = rgb.filter(
            ImageFilter.UnsharpMask(
                radius=preset.unsharp_radius,
                percent=preset.unsharp_percent,
                threshold=preset.unsharp_threshold,
            )
        )
    output = Image.merge("RGBA", (*rgb.split(), rgba.getchannel("A")))
    return output


def pack_sheet(frames: list[Image.Image], cols: int, rows: int) -> Image.Image:
    if not frames:
        raise SystemExit("No frames to pack")
    cell_size = frames[0].size
    for index, frame in enumerate(frames):
        if frame.size != cell_size:
            raise SystemExit(f"Frame {index + 1} has size {frame.size}; expected {cell_size}")
    sheet = Image.new("RGBA", (cell_size[0] * cols, cell_size[1] * rows), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        col = index % cols
        row = index // cols
        sheet.alpha_composite(frame, (col * cell_size[0], row * cell_size[1]))
    return sheet


def save_sequence(frames: list[Image.Image], out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames):
        frame.save(out_dir / f"frame_{index + 1:03d}.png")


def checker(size: tuple[int, int], cell: int = 24) -> Image.Image:
    image = Image.new("RGB", size, (244, 244, 244))
    pixels = image.load()
    for y in range(size[1]):
        for x in range(size[0]):
            if ((x // cell) + (y // cell)) % 2:
                pixels[x, y] = (222, 226, 232)
    return image


def save_gif(frames: list[Image.Image], path: Path, size: int, duration_ms: int) -> None:
    gif_frames: list[Image.Image] = []
    for frame in frames:
        scaled = frame.resize((size, size), Image.Resampling.LANCZOS)
        bg = checker((size, size)).convert("RGBA")
        bg.alpha_composite(scaled)
        gif_frames.append(bg.convert("P", palette=Image.Palette.ADAPTIVE, colors=256))
    path.parent.mkdir(parents=True, exist_ok=True)
    gif_frames[0].save(
        path,
        save_all=True,
        append_images=gif_frames[1:],
        duration=duration_ms,
        loop=0,
        optimize=False,
        disposal=2,
    )


def manifest_data(args: argparse.Namespace, preset: Preset, frames: list[Image.Image]) -> dict[str, object]:
    first_size = list(frames[0].size) if frames else [0, 0]
    return {
        "tool": "tools/live2d_postprocess.py",
        "source_sheet": os.fspath(args.sheet) if args.sheet else "",
        "source_sequence_dir": os.fspath(args.sequence_dir) if args.sequence_dir else "",
        "preset": args.preset,
        "preset_values": asdict(preset),
        "frame_count": len(frames),
        "frame_size": first_size,
        "target_count": args.target_count,
        "outputs": {
            "sheet": os.fspath(args.out_sheet) if args.out_sheet else "",
            "sequence_dir": os.fspath(args.out_dir) if args.out_dir else "",
            "gif": os.fspath(args.gif) if args.gif else "",
        },
        "notes": [
            "Alpha channel and frame canvas are preserved.",
            "target_count pads only by duplicating the final processed frame.",
        ],
    }


def main() -> None:
    args = parse_args()
    preset = PRESETS[args.preset]
    preset = Preset(
        args.color if args.color is not None else preset.color,
        args.contrast if args.contrast is not None else preset.contrast,
        args.brightness if args.brightness is not None else preset.brightness,
        args.sharpness if args.sharpness is not None else preset.sharpness,
        preset.unsharp_radius,
        preset.unsharp_percent,
        preset.unsharp_threshold,
    )

    if args.sheet:
        cols, rows, count = require_sheet_shape(args)
        frames = load_sheet_frames(args.sheet, cols, rows, count)
    else:
        frames = load_sequence_frames(args.sequence_dir, args.count)
        if args.out_sheet:
            require_sheet_shape(args)

    frames = padded_frames(frames, args.target_count)
    processed = [apply_cleanup(frame, preset) for frame in frames]

    if args.out_sheet:
        cols, rows, _count = require_sheet_shape(args)
        if len(processed) > cols * rows:
            raise SystemExit("Processed frame count exceeds cols*rows")
        args.out_sheet.parent.mkdir(parents=True, exist_ok=True)
        pack_sheet(processed, cols, rows).save(args.out_sheet)
    if args.out_dir:
        save_sequence(processed, args.out_dir)
    if args.gif:
        save_gif(processed, args.gif, args.gif_size, args.gif_ms)
    if args.manifest:
        args.manifest.parent.mkdir(parents=True, exist_ok=True)
        with args.manifest.open("w", encoding="utf-8") as handle:
            json.dump(manifest_data(args, preset, processed), handle, ensure_ascii=False, indent=2)

    print(f"processed {len(processed)} frames")


if __name__ == "__main__":
    main()
