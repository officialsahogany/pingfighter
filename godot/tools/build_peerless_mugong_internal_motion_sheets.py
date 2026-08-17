#!/usr/bin/env python3
"""Build fixed-shell peerless-Mugong icon sheets from AutoSprite frames.

AutoSprite owns the temporal source.  This deterministic finishing pass keeps
the accepted 128 px hanji seal as a motionless identity shell and transfers
only the AutoSprite frame-to-frame colour/light delta into its inner artwork.
The runtime output remains the existing eight-frame horizontal sheet contract.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


PERK_IDS = (
    "megingjord",
    "transcendent_crown",
    "ragnarok_hammer",
    "hermes_shoes",
    "poseidon_trident",
    "sacred_laurel",
    "heavenly_cape",
    "horn_strawberry_mask",
    "odins_eye",
    "celestial_armor",
    "baal_boots",
    "pandora_legacy",
    "angel_blessing",
)

FRAME_SIZE = 128
FRAME_COUNT = 8
SOURCE_COLS = 3
SOURCE_ROWS = 3


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _alpha_bbox(image: Image.Image, threshold: int = 8) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha > threshold)
    if xs.size == 0:
        raise ValueError("image has no visible alpha")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _premultiplied_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    alpha = rgba[:, :, 3:4] / 255.0
    premultiplied = rgba[:, :, :3] * alpha
    resized_rgb = np.asarray(
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
    straight_rgb = np.zeros_like(resized_rgb)
    np.divide(
        resized_rgb,
        np.maximum(alpha_unit, 1.0 / 255.0),
        out=straight_rgb,
        where=alpha_unit > 0.0,
    )
    return Image.fromarray(
        np.dstack((np.clip(straight_rgb, 0, 255), resized_alpha)).astype(np.uint8)
    )


def _extract_source_frames(sheet: Image.Image) -> list[Image.Image]:
    if sheet.size != (FRAME_SIZE * SOURCE_COLS, FRAME_SIZE * SOURCE_ROWS):
        raise ValueError(
            f"expected AutoSprite 3x3 sheet at 384x384, got {sheet.size}"
        )
    frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        column = index % SOURCE_COLS
        row = index // SOURCE_COLS
        frames.append(
            sheet.crop(
                (
                    column * FRAME_SIZE,
                    row * FRAME_SIZE,
                    (column + 1) * FRAME_SIZE,
                    (row + 1) * FRAME_SIZE,
                )
            )
        )
    return frames


def _align_from_frame_zero(
    frames: list[Image.Image], anchor: Image.Image
) -> tuple[list[Image.Image], dict[str, object]]:
    source_bbox = _alpha_bbox(frames[0])
    anchor_bbox = _alpha_bbox(anchor)
    source_width = source_bbox[2] - source_bbox[0]
    source_height = source_bbox[3] - source_bbox[1]
    anchor_width = anchor_bbox[2] - anchor_bbox[0]
    anchor_height = anchor_bbox[3] - anchor_bbox[1]
    scale = min(anchor_width / source_width, anchor_height / source_height)
    resized_size = (
        max(1, round(source_width * scale)),
        max(1, round(source_height * scale)),
    )
    anchor_center = (
        (anchor_bbox[0] + anchor_bbox[2]) * 0.5,
        (anchor_bbox[1] + anchor_bbox[3]) * 0.5,
    )
    paste = (
        round(anchor_center[0] - resized_size[0] * 0.5),
        round(anchor_center[1] - resized_size[1] * 0.5),
    )
    aligned: list[Image.Image] = []
    for frame in frames:
        # One fixed crop/scale/placement derived from frame zero is applied to
        # every frame.  Later excursions are intentionally clipped instead of
        # causing the whole icon to grow and shrink.
        fixed_crop = frame.crop(source_bbox)
        resized = _premultiplied_resize(fixed_crop, resized_size)
        canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        canvas.alpha_composite(resized, paste)
        aligned.append(canvas)
    return aligned, {
        "source_frame_zero_bbox": list(source_bbox),
        "anchor_bbox": list(anchor_bbox),
        "scale": scale,
        "resized_px": list(resized_size),
        "paste_px": list(paste),
    }


def _smootherstep(value: np.ndarray) -> np.ndarray:
    clipped = np.clip(value, 0.0, 1.0)
    return clipped * clipped * (3.0 - 2.0 * clipped)


def _transfer_internal_motion(
    anchor: Image.Image,
    aligned: list[Image.Image],
    inner_full_ratio: float,
    inner_fade_ratio: float,
    delta_strength: float,
    negative_delta_limit: float,
    positive_delta_limit: float,
) -> tuple[list[Image.Image], dict[str, object]]:
    anchor_rgba = np.asarray(anchor.convert("RGBA"), dtype=np.float32)
    base_rgba = np.asarray(aligned[0], dtype=np.float32)
    anchor_bbox = _alpha_bbox(anchor)
    center_x = (anchor_bbox[0] + anchor_bbox[2]) * 0.5
    center_y = (anchor_bbox[1] + anchor_bbox[3]) * 0.5
    radius = min(anchor_bbox[2] - anchor_bbox[0], anchor_bbox[3] - anchor_bbox[1]) * 0.5
    yy, xx = np.mgrid[0:FRAME_SIZE, 0:FRAME_SIZE]
    distance_ratio = np.sqrt((xx - center_x) ** 2 + (yy - center_y) ** 2) / max(radius, 1.0)
    fade_t = (inner_fade_ratio - distance_ratio) / max(
        inner_fade_ratio - inner_full_ratio, 1.0e-6
    )
    radial_weight = _smootherstep(fade_t)[:, :, None]
    anchor_alpha = anchor_rgba[:, :, 3:4] / 255.0
    frames: list[Image.Image] = []
    inner_changed_pixels: list[int] = []
    outer_max_rgb_delta: list[int] = []
    alpha_max_delta: list[int] = []
    for aligned_frame in aligned:
        current = np.asarray(aligned_frame, dtype=np.float32)
        valid_alpha = np.maximum(base_rgba[:, :, 3:4], current[:, :, 3:4]) / 255.0
        delta = np.clip(
            current[:, :, :3] - base_rgba[:, :, :3],
            -negative_delta_limit,
            positive_delta_limit,
        )
        weight = radial_weight * anchor_alpha * valid_alpha
        rgb = np.clip(anchor_rgba[:, :, :3] + delta * weight * delta_strength, 0, 255)
        rgba = np.dstack((rgb, anchor_rgba[:, :, 3]))
        output = Image.fromarray(rgba.astype(np.uint8))
        frames.append(output)

        diff = np.abs(rgba[:, :, :3] - anchor_rgba[:, :, :3])
        inner_changed_pixels.append(
            int(np.count_nonzero(np.max(diff, axis=2) >= 4.0))
        )
        outer = distance_ratio >= inner_fade_ratio
        outer_max_rgb_delta.append(
            int(np.max(diff[outer])) if np.any(outer) else 0
        )
        alpha_max_delta.append(
            int(np.max(np.abs(rgba[:, :, 3] - anchor_rgba[:, :, 3])))
        )
    return frames, {
        "inner_full_ratio": inner_full_ratio,
        "inner_fade_ratio": inner_fade_ratio,
        "delta_strength": delta_strength,
        "negative_delta_limit": negative_delta_limit,
        "positive_delta_limit": positive_delta_limit,
        "inner_changed_pixels_vs_anchor": inner_changed_pixels,
        "outer_max_rgb_delta": outer_max_rgb_delta,
        "alpha_max_delta": alpha_max_delta,
    }


def _frame_delta(left: Image.Image, right: Image.Image) -> float:
    a = np.asarray(left.convert("RGB"), dtype=np.float32)
    b = np.asarray(right.convert("RGB"), dtype=np.float32)
    return float(np.mean(np.abs(a - b)))


def _save_sheet(frames: list[Image.Image], path: Path) -> None:
    sheet = Image.new("RGBA", (FRAME_SIZE * FRAME_COUNT, FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * FRAME_SIZE, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, optimize=True)


def _preview_frame(image: Image.Image, display_size: int) -> Image.Image:
    resized = _premultiplied_resize(image, (display_size, display_size))
    tile = Image.new("RGBA", (display_size + 8, display_size + 8), (10, 8, 6, 255))
    draw = ImageDraw.Draw(tile)
    draw.ellipse((3, 3, display_size + 4, display_size + 4), fill=(36, 24, 12, 255))
    tile.alpha_composite(resized, (4, 4))
    return tile.convert("RGB")


def _save_animated_preview(
    all_frames: dict[str, list[Image.Image]], path: Path, display_size: int
) -> None:
    columns = 4
    rows = (len(PERK_IDS) + columns - 1) // columns
    tile_size = display_size + 8
    preview_frames: list[Image.Image] = []
    for frame_index in range(FRAME_COUNT):
        board = Image.new("RGB", (columns * tile_size, rows * tile_size), (5, 4, 3))
        for perk_index, perk_id in enumerate(PERK_IDS):
            tile = _preview_frame(all_frames[perk_id][frame_index], display_size)
            board.paste(
                tile,
                ((perk_index % columns) * tile_size, (perk_index // columns) * tile_size),
            )
        preview_frames.append(board)
    path.parent.mkdir(parents=True, exist_ok=True)
    preview_frames[0].save(
        path,
        save_all=True,
        append_images=preview_frames[1:],
        duration=250,
        loop=0,
        optimize=False,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("static_dir", type=Path)
    parser.add_argument("runtime_dir", type=Path)
    parser.add_argument("report", type=Path)
    parser.add_argument("--preview-dir", type=Path)
    parser.add_argument("--inner-full-ratio", type=float, default=0.54)
    parser.add_argument("--inner-fade-ratio", type=float, default=0.76)
    parser.add_argument("--delta-strength", type=float, default=1.20)
    parser.add_argument("--negative-delta-limit", type=float, default=36.0)
    parser.add_argument("--positive-delta-limit", type=float, default=112.0)
    args = parser.parse_args()

    report: dict[str, object] = {
        "pipeline": "AutoSprite temporal delta over fixed static hanji shell",
        "runtime_grid": {"cols": 8, "rows": 1, "frames": 8, "cell_px": 128},
        "frame_interval_msec": 250,
        "assets": [],
    }
    all_runtime_frames: dict[str, list[Image.Image]] = {}
    for perk_id in PERK_IDS:
        source_path = args.source_dir / f"{perk_id}_autosprite_raw.png"
        static_path = args.static_dir / f"{perk_id}_perk_icon.png"
        runtime_path = args.runtime_dir / f"{perk_id}_perk_icon_sheet.png"
        source = Image.open(source_path).convert("RGBA")
        anchor = Image.open(static_path).convert("RGBA")
        if anchor.size != (FRAME_SIZE, FRAME_SIZE):
            raise SystemExit(f"{static_path} must be 128x128")
        source_frames = _extract_source_frames(source)
        aligned, fixed_transform = _align_from_frame_zero(source_frames, anchor)
        runtime_frames, motion_qa = _transfer_internal_motion(
            anchor,
            aligned,
            args.inner_full_ratio,
            args.inner_fade_ratio,
            args.delta_strength,
            args.negative_delta_limit,
            args.positive_delta_limit,
        )
        _save_sheet(runtime_frames, runtime_path)
        all_runtime_frames[perk_id] = runtime_frames
        adjacent_deltas = [
            _frame_delta(runtime_frames[index], runtime_frames[index + 1])
            for index in range(FRAME_COUNT - 1)
        ]
        loop_delta = _frame_delta(runtime_frames[-1], runtime_frames[0])
        if max(motion_qa["outer_max_rgb_delta"], default=0) != 0:
            raise SystemExit(f"{perk_id}: outer shell changed")
        if max(motion_qa["alpha_max_delta"], default=0) != 0:
            raise SystemExit(f"{perk_id}: alpha silhouette changed")
        if max(motion_qa["inner_changed_pixels_vs_anchor"], default=0) < 12:
            raise SystemExit(f"{perk_id}: no readable AutoSprite internal motion")
        report["assets"].append(
            {
                "perk_id": perk_id,
                "source": str(source_path).replace("\\", "/"),
                "runtime": str(runtime_path).replace("\\", "/"),
                "source_sha256": _sha256(source_path),
                "runtime_sha256": _sha256(runtime_path),
                "fixed_transform": fixed_transform,
                "motion_qa": motion_qa,
                "adjacent_mean_abs_rgb_delta": adjacent_deltas,
                "loop_seam_mean_abs_rgb_delta": loop_delta,
            }
        )

    if args.preview_dir is not None:
        _save_animated_preview(
            all_runtime_frames,
            args.preview_dir / "peerless_mugong_internal_motion_80px.gif",
            80,
        )
        _save_animated_preview(
            all_runtime_frames,
            args.preview_dir / "peerless_mugong_internal_motion_32px.gif",
            32,
        )

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
