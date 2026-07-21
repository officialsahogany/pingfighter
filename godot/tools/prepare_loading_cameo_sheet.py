#!/usr/bin/env python3
"""Repack one AutoSprite 4x4 cameo sheet with one fixed transform."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


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
    result = np.dstack((np.clip(straight_rgb, 0, 255), resized_alpha))
    return Image.fromarray(result.astype(np.uint8))


def _alpha_bbox(image: Image.Image, threshold: int = 8) -> tuple[int, int, int, int] | None:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha > threshold)
    if xs.size == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _edge_alpha_count(image: Image.Image, threshold: int = 0) -> int:
    alpha = np.asarray(image.getchannel("A"))
    return int(
        np.count_nonzero(alpha[0, :] > threshold)
        + np.count_nonzero(alpha[-1, :] > threshold)
        + np.count_nonzero(alpha[:, 0] > threshold)
        + np.count_nonzero(alpha[:, -1] > threshold)
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("runtime", type=Path)
    parser.add_argument("preview", type=Path)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--cols", type=int, default=4)
    parser.add_argument("--rows", type=int, default=4)
    parser.add_argument("--runtime-cell", type=int, default=256)
    parser.add_argument("--runtime-margin", type=int, default=8)
    parser.add_argument("--source-padding", type=int, default=6)
    parser.add_argument("--job-id", default="")
    parser.add_argument("--sheet-id", default="")
    parser.add_argument("--video-id", default="")
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGBA")
    if source.width % args.cols or source.height % args.rows:
        raise SystemExit("source dimensions are not divisible by the requested grid")
    source_cell_w = source.width // args.cols
    source_cell_h = source.height // args.rows
    frames: list[Image.Image] = []
    frame_bboxes: list[tuple[int, int, int, int]] = []
    for index in range(args.cols * args.rows):
        col = index % args.cols
        row = index // args.cols
        frame = source.crop(
            (
                col * source_cell_w,
                row * source_cell_h,
                (col + 1) * source_cell_w,
                (row + 1) * source_cell_h,
            )
        )
        bbox = _alpha_bbox(frame)
        if bbox is None:
            raise SystemExit(f"frame {index} has no visible alpha")
        frames.append(frame)
        frame_bboxes.append(bbox)

    union = (
        max(0, min(box[0] for box in frame_bboxes) - args.source_padding),
        max(0, min(box[1] for box in frame_bboxes) - args.source_padding),
        min(source_cell_w, max(box[2] for box in frame_bboxes) + args.source_padding),
        min(source_cell_h, max(box[3] for box in frame_bboxes) + args.source_padding),
    )
    crop_w = union[2] - union[0]
    crop_h = union[3] - union[1]
    available = args.runtime_cell - args.runtime_margin * 2
    scale = min(available / crop_w, available / crop_h)
    resized_size = (max(1, round(crop_w * scale)), max(1, round(crop_h * scale)))
    paste_x = (args.runtime_cell - resized_size[0]) // 2
    paste_y = args.runtime_cell - args.runtime_margin - resized_size[1]

    runtime = Image.new(
        "RGBA",
        (args.runtime_cell * args.cols, args.runtime_cell * args.rows),
        (0, 0, 0, 0),
    )
    runtime_bboxes: list[tuple[int, int, int, int]] = []
    edge_counts: list[int] = []
    runtime_frames: list[Image.Image] = []
    for index, frame in enumerate(frames):
        fixed_crop = frame.crop(union)
        resized = _premultiplied_resize(fixed_crop, resized_size)
        output_cell = Image.new("RGBA", (args.runtime_cell, args.runtime_cell), (0, 0, 0, 0))
        output_cell.alpha_composite(resized, (paste_x, paste_y))
        bbox = _alpha_bbox(output_cell)
        if bbox is None:
            raise SystemExit(f"runtime frame {index} has no visible alpha")
        runtime_frames.append(output_cell)
        runtime_bboxes.append(bbox)
        edge_counts.append(_edge_alpha_count(output_cell))
        runtime.alpha_composite(
            output_cell,
            ((index % args.cols) * args.runtime_cell, (index // args.cols) * args.runtime_cell),
        )

    args.runtime.parent.mkdir(parents=True, exist_ok=True)
    runtime.save(args.runtime, optimize=True)

    visible_union = (
        min(box[0] for box in runtime_bboxes),
        min(box[1] for box in runtime_bboxes),
        max(box[2] for box in runtime_bboxes),
        max(box[3] for box in runtime_bboxes),
    )
    visible_height = visible_union[3] - visible_union[1]
    qa_scale = 65.0 / max(1, visible_height)
    qa_cell_size = (
        max(1, round(args.runtime_cell * qa_scale)),
        max(1, round(args.runtime_cell * qa_scale)),
    )
    preview_cols = 8
    preview_rows = 2
    tile_w = max(112, qa_cell_size[0] + 16)
    tile_h = max(88, qa_cell_size[1] + 8)
    preview = Image.new("RGB", (tile_w * preview_cols, tile_h * preview_rows), (0, 0, 0))
    for index, frame in enumerate(runtime_frames):
        mask = frame.getchannel("A").resize(qa_cell_size, Image.Resampling.LANCZOS)
        silhouette = Image.new("RGBA", qa_cell_size, (255, 255, 255, 0))
        silhouette.putalpha(mask)
        x = (index % preview_cols) * tile_w + (tile_w - qa_cell_size[0]) // 2
        y = (index // preview_cols) * tile_h + (tile_h - qa_cell_size[1]) // 2
        preview.paste(silhouette.convert("RGB"), (x, y), silhouette)
    args.preview.parent.mkdir(parents=True, exist_ok=True)
    preview.save(args.preview, optimize=True)

    manifest = {
        "source": str(args.source).replace("\\", "/"),
        "runtime": str(args.runtime).replace("\\", "/"),
        "autosprite": {
            "job_id": args.job_id,
            "spritesheet_id": args.sheet_id,
            "video_id": args.video_id,
        },
        "grid": {"cols": args.cols, "rows": args.rows, "frame_count": len(frames)},
        "source_cell_px": [source_cell_w, source_cell_h],
        "fixed_transform": {
            "source_union_crop": list(union),
            "scale": scale,
            "resized_px": list(resized_size),
            "paste_px": [paste_x, paste_y],
        },
        "runtime_cell_px": args.runtime_cell,
        "runtime_visible_union_bbox": list(visible_union),
        "runtime_visible_height_px": visible_height,
        "per_frame_edge_alpha_count": edge_counts,
        "qa_preview_visible_height_px": 65,
        "sha256": {"source": _sha256(args.source), "runtime": _sha256(args.runtime)},
    }
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
