#!/usr/bin/env python3
"""Build the fixed-shell 양의회천 seal icon and its 8-frame gold-light sheet."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


FRAME_SIZE = 128
CONTENT_SIZE = 120
FRAME_COUNT = 8


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha > 8)
    if xs.size == 0:
        raise ValueError("source image has no visible alpha")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _premultiplied_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    alpha = rgba[:, :, 3:4] / 255.0
    premultiplied = rgba[:, :, :3] * alpha
    rgb = np.asarray(
        Image.fromarray(np.clip(premultiplied, 0, 255).astype(np.uint8)).resize(
            size, Image.Resampling.LANCZOS
        ),
        dtype=np.float32,
    )
    resized_alpha = np.asarray(
        Image.fromarray(rgba[:, :, 3].astype(np.uint8)).resize(
            size, Image.Resampling.LANCZOS
        ),
        dtype=np.float32,
    )
    alpha_unit = resized_alpha[:, :, None] / 255.0
    straight_rgb = np.zeros_like(rgb)
    np.divide(
        rgb,
        np.maximum(alpha_unit, 1.0 / 255.0),
        out=straight_rgb,
        where=alpha_unit > 0.0,
    )
    return Image.fromarray(
        np.dstack((np.clip(straight_rgb, 0, 255), resized_alpha)).astype(np.uint8)
    )


def _build_static(source: Image.Image) -> Image.Image:
    cropped = source.crop(_alpha_bbox(source))
    scale = min(CONTENT_SIZE / cropped.width, CONTENT_SIZE / cropped.height)
    size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    resized = _premultiplied_resize(cropped, size)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    offset = ((FRAME_SIZE - size[0]) // 2, (FRAME_SIZE - size[1]) // 2)
    canvas.alpha_composite(resized, offset)
    return canvas


def _build_motion_frames(anchor: Image.Image) -> tuple[list[Image.Image], dict[str, object]]:
    base = np.asarray(anchor, dtype=np.float32)
    rgb = base[:, :, :3]
    alpha = base[:, :, 3] / 255.0
    yy, xx = np.mgrid[0:FRAME_SIZE, 0:FRAME_SIZE]
    distance = np.sqrt((xx - 63.5) ** 2 + (yy - 63.5) ** 2)
    # The collection seal test treats radius >= 48 px as the fixed hanji shell.
    inner = np.clip((47.0 - distance) / 7.0, 0.0, 1.0)
    gold = (
        (rgb[:, :, 0] > 145.0)
        & (rgb[:, :, 1] > 85.0)
        & (rgb[:, :, 2] < 150.0)
        & ((rgb[:, :, 0] - rgb[:, :, 2]) > 48.0)
    ).astype(np.float32)
    raw_mask = gold * inner * alpha
    glow_mask = np.asarray(
        Image.fromarray(np.clip(raw_mask * 255.0, 0, 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(2.2)
        ),
        dtype=np.float32,
    ) / 255.0
    pulse_values = [0.0, 0.38, 0.78, 0.48, 0.12, 0.58, 0.86, 0.32]
    frames: list[Image.Image] = []
    changed_pixels: list[int] = []
    outer_max_delta: list[int] = []
    alpha_max_delta: list[int] = []
    for frame_index, pulse in enumerate(pulse_values):
        phase = frame_index * np.pi * 2.0 / FRAME_COUNT
        shimmer = 0.72 + 0.28 * np.sin(xx * 0.17 - yy * 0.045 + phase)
        weight = glow_mask * shimmer * pulse
        output = base.copy()
        target = np.array([255.0, 225.0, 92.0], dtype=np.float32)
        output[:, :, :3] = np.clip(
            rgb + (target - rgb) * weight[:, :, None] * 0.58,
            0,
            255,
        )
        output[:, :, 3] = base[:, :, 3]
        frame = Image.fromarray(output.astype(np.uint8))
        frames.append(frame)
        delta = np.abs(output[:, :, :3] - rgb)
        changed_pixels.append(int(np.count_nonzero(np.max(delta, axis=2) >= 3.0)))
        outer = distance >= 48.0
        outer_max_delta.append(int(np.max(delta[outer])) if np.any(outer) else 0)
        alpha_max_delta.append(int(np.max(np.abs(output[:, :, 3] - base[:, :, 3]))))
    return frames, {
        "motion": "deterministic inner antique-gold shimmer over a fixed hanji shell",
        "pulse_values": pulse_values,
        "changed_pixels_vs_static": changed_pixels,
        "outer_max_rgb_delta": outer_max_delta,
        "alpha_max_delta": alpha_max_delta,
    }


def _save_sheet(frames: list[Image.Image], path: Path) -> None:
    sheet = Image.new("RGBA", (FRAME_SIZE * FRAME_COUNT, FRAME_SIZE), (0, 0, 0, 0))
    for frame_index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (frame_index * FRAME_SIZE, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("static_output", type=Path)
    parser.add_argument("sheet_output", type=Path)
    parser.add_argument("report_output", type=Path)
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGBA")
    anchor = _build_static(source)
    frames, motion_qa = _build_motion_frames(anchor)
    args.static_output.parent.mkdir(parents=True, exist_ok=True)
    anchor.save(args.static_output, optimize=True)
    _save_sheet(frames, args.sheet_output)
    report = {
        "perk_id": "yangui_hoechun",
        "static_size": list(anchor.size),
        "sheet_size": [FRAME_SIZE * FRAME_COUNT, FRAME_SIZE],
        "frame_count": FRAME_COUNT,
        "frame_interval_msec": 250,
        "source_sha256": _sha256(args.source),
        "static_sha256": _sha256(args.static_output),
        "sheet_sha256": _sha256(args.sheet_output),
        "motion_qa": motion_qa,
    }
    args.report_output.parent.mkdir(parents=True, exist_ok=True)
    args.report_output.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
