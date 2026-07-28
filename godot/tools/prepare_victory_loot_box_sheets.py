#!/usr/bin/env python3
"""Prepare the accepted AutoSprite victory-loot chest sheets for Godot.

The source animations already have the required 4x4 / 16-frame layout.  This
script only performs deterministic, whole-sheet-safe finishing:

* apply one fixed integer translation per sheet so the closed chest is centred;
* align the closed contact baseline to the same cell y coordinate;
* emit runtime PNGs, compact QA previews, and a provenance/QC manifest.

No frame is interpolated, reordered, redrawn, or independently re-centred.
"""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


COLS = 4
ROWS = 4
FRAME_COUNT = 16
CELL_SIZE = 256
SHEET_SIZE = CELL_SIZE * COLS
TARGET_CENTER_X = 128
TARGET_CLOSED_BASELINE_Y = 233
DISPLAY_SIZE = 78
CELL_SAFE_MARGIN = 8

REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = REPO_ROOT / "images" / "victory_loot_boxes_hwangyeokjeon"
RAW_ROOT = SOURCE_ROOT / "autosprite_raw"
PROCESSED_ROOT = SOURCE_ROOT / "processed"
QA_ROOT = SOURCE_ROOT / "qa"
RUNTIME_ROOT = REPO_ROOT / "godot" / "assets" / "sprites" / "result_boxes"

SHEETS = (
    {
        "kind": "normal",
        "source": RAW_ROOT / "normal_open_16f_autosprite_raw.png",
        "processed": PROCESSED_ROOT / "result_box_common_open_16f.png",
        "runtime": RUNTIME_ROOT / "result_box_common_open_16f.png",
        "concept": SOURCE_ROOT / "concepts" / "normal_concept_autosprite_v2.png",
        "asset_id": "cms4gwdsp006pau1iamoab4xd",
        "job_id": "wf_3ae9d6df-bb16-4256-8f50-8ecfb9212762",
        "spritesheet_id": "cms4gyhvg00cbcpjekm04tn9g",
        "animation_prompt": (
            "Fixed camera and base. Hemp knot loosens, lid opens, soft amber "
            "light leaks then settles. Ends fully open and still. No chest "
            "bounce, morphing, rotation, text, or coins."
        ),
        "trim_below_closed_baseline": False,
    },
    {
        "kind": "advanced",
        "source": RAW_ROOT / "advanced_open_16f_autosprite_raw.png",
        "processed": PROCESSED_ROOT / "result_box_mythic_open_16f.png",
        "runtime": RUNTIME_ROOT / "result_box_mythic_open_16f.png",
        "concept": SOURCE_ROOT / "concepts" / "advanced_concept_autosprite_v2.png",
        "asset_id": "cms4gwf6l006rau1i0m4q8f2n",
        "job_id": "wf_90ad16dc-7147-401e-b870-06c11d48f160",
        "spritesheet_id": "cms4h0cjo000h13stpal7yc0p",
        "animation_prompt": (
            "Fixed camera and base. Tassel lock loosens, lid opens, cyan-gold "
            "light blooms, pearl glints. Ends fully open and still. No chest "
            "bounce, morphing, rotation, text, or coins."
        ),
        "trim_below_closed_baseline": False,
    },
    {
        "kind": "guaranteed_mythic",
        "source": RAW_ROOT / "guaranteed_mythic_open_16f_autosprite_v3_raw.png",
        "processed": PROCESSED_ROOT / "result_box_guaranteed_mythic_open_16f.png",
        "runtime": RUNTIME_ROOT / "result_box_guaranteed_mythic_open_16f.png",
        "concept": SOURCE_ROOT / "concepts" / "guaranteed_mythic_concept_autosprite_v2.png",
        "asset_id": "cms4gwgo9006tau1iy07gk21t",
        "job_id": "wf_b1d551cd-1350-4a61-a626-f14e3f5f9e16",
        "spritesheet_id": "cms4hf6nn006a12vhdct3bq38",
        "animation_prompt": (
            "Fixed camera/base. Seal dissolves upward; nothing falls below. "
            "Lid opens; contained gold-white glow rises inside. Ends open and "
            "still. No debris, floor spill, forward beam, bounce, morph, text."
        ),
        "trim_below_closed_baseline": False,
    },
)


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("frame has no visible alpha")
    return bbox


def frame_at(sheet: Image.Image, index: int) -> Image.Image:
    x = (index % COLS) * CELL_SIZE
    y = (index // COLS) * CELL_SIZE
    return sheet.crop((x, y, x + CELL_SIZE, y + CELL_SIZE))


def edge_alpha_count(frame: Image.Image) -> int:
    alpha = frame.getchannel("A")
    count = 0
    for x in range(CELL_SIZE):
        count += int(alpha.getpixel((x, 0)) > 0)
        count += int(alpha.getpixel((x, CELL_SIZE - 1)) > 0)
    for y in range(1, CELL_SIZE - 1):
        count += int(alpha.getpixel((0, y)) > 0)
        count += int(alpha.getpixel((CELL_SIZE - 1, y)) > 0)
    return count


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def prepare_sheet(spec: dict[str, object]) -> dict[str, object]:
    source_path = Path(spec["source"])
    processed_path = Path(spec["processed"])
    runtime_path = Path(spec["runtime"])
    source = Image.open(source_path).convert("RGBA")
    if source.size != (SHEET_SIZE, SHEET_SIZE):
        raise ValueError(f"{source_path}: expected 1024x1024, got {source.size}")

    closed = frame_at(source, 0)
    closed_bbox = alpha_bbox(closed)
    closed_center_x = (closed_bbox[0] + closed_bbox[2] - 1) / 2.0
    closed_baseline_y = closed_bbox[3] - 1
    offset_x = round(TARGET_CENTER_X - closed_center_x)
    offset_y = TARGET_CLOSED_BASELINE_Y - closed_baseline_y
    source_bboxes = [alpha_bbox(frame_at(source, index)) for index in range(FRAME_COUNT)]
    union_min_x = min(bbox[0] for bbox in source_bboxes)
    union_max_x = max(bbox[2] for bbox in source_bboxes)
    min_safe_offset_x = CELL_SAFE_MARGIN - union_min_x
    max_safe_offset_x = CELL_SIZE - CELL_SAFE_MARGIN - union_max_x
    offset_x = max(min_safe_offset_x, min(offset_x, max_safe_offset_x))

    prepared = Image.new("RGBA", source.size, (0, 0, 0, 0))
    frame_bboxes: list[list[int]] = []
    frame_edge_counts: list[int] = []
    frame_baselines: list[int] = []
    for index in range(FRAME_COUNT):
        frame = frame_at(source, index)
        if bool(spec["trim_below_closed_baseline"]):
            # The accepted mythic take keeps its broken seal, but the video
            # model also scattered fragments below the closed chest's contact
            # line.  Clearing only that below-baseline region is deterministic
            # alpha cleanup and preserves all source animation above it.
            frame.paste(
                (0, 0, 0, 0),
                (0, closed_baseline_y + 1, CELL_SIZE, CELL_SIZE),
            )
        finished = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
        finished.alpha_composite(frame, (offset_x, offset_y))
        bbox = alpha_bbox(finished)
        edge_count = edge_alpha_count(finished)
        if edge_count != 0:
            raise ValueError(
                f"{source_path.name} frame {index}: {edge_count} edge-alpha pixels"
            )
        frame_bboxes.append(list(bbox))
        frame_edge_counts.append(edge_count)
        frame_baselines.append(bbox[3] - 1)
        target_x = (index % COLS) * CELL_SIZE
        target_y = (index // COLS) * CELL_SIZE
        prepared.alpha_composite(finished, (target_x, target_y))

    if len(set(frame_baselines)) != 1:
        raise ValueError(
            f"{source_path.name}: contact baseline drifted: {frame_baselines}"
        )

    processed_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    prepared.save(processed_path, optimize=True)
    shutil.copyfile(processed_path, runtime_path)
    return {
        "kind": spec["kind"],
        "concept_path": str(Path(spec["concept"]).relative_to(REPO_ROOT)).replace("\\", "/"),
        "source_path": str(source_path.relative_to(REPO_ROOT)).replace("\\", "/"),
        "processed_path": str(processed_path.relative_to(REPO_ROOT)).replace("\\", "/"),
        "runtime_path": str(runtime_path.relative_to(REPO_ROOT)).replace("\\", "/"),
        "asset_id": spec["asset_id"],
        "job_id": spec["job_id"],
        "spritesheet_id": spec["spritesheet_id"],
        "animation_prompt": spec["animation_prompt"],
        "postprocess": {
            "fixed_transform_all_frames": True,
            "offset_xy": [offset_x, offset_y],
            "target_closed_baseline_y": TARGET_CLOSED_BASELINE_Y,
            "trim_below_source_closed_baseline": bool(spec["trim_below_closed_baseline"]),
            "frame_reorder": False,
            "interpolation": False,
        },
        "qa": {
            "sheet_size": list(prepared.size),
            "grid": [COLS, ROWS],
            "frame_count": FRAME_COUNT,
            "cell_size": [CELL_SIZE, CELL_SIZE],
            "closed_frame_bbox": frame_bboxes[0],
            "frame_bboxes": frame_bboxes,
            "frame_baselines": frame_baselines,
            "edge_alpha_counts": frame_edge_counts,
        },
        "sha256": {
            "concept": sha256(Path(spec["concept"])),
            "source": sha256(source_path),
            "processed": sha256(processed_path),
            "runtime": sha256(runtime_path),
        },
    }


def build_preview(results: list[dict[str, object]], background: tuple[int, int, int, int], name: str) -> None:
    label_h = 22
    gap = 10
    indices = (0, 4, 8, 12, 15)
    width = gap + len(indices) * (DISPLAY_SIZE + gap)
    height = gap + len(results) * (label_h + DISPLAY_SIZE + gap)
    preview = Image.new("RGBA", (width, height), background)
    draw = ImageDraw.Draw(preview)
    font = ImageFont.load_default()
    for row, result in enumerate(results):
        sheet = Image.open(REPO_ROOT / str(result["processed_path"])).convert("RGBA")
        y = gap + row * (label_h + DISPLAY_SIZE + gap)
        fill = (245, 230, 185, 255) if sum(background[:3]) < 300 else (35, 25, 20, 255)
        draw.text((gap, y), str(result["kind"]), fill=fill, font=font)
        for col, frame_index in enumerate(indices):
            frame = frame_at(sheet, frame_index)
            frame.thumbnail((DISPLAY_SIZE, DISPLAY_SIZE), Image.Resampling.LANCZOS)
            x = gap + col * (DISPLAY_SIZE + gap)
            preview.alpha_composite(frame, (x, y + label_h))
    QA_ROOT.mkdir(parents=True, exist_ok=True)
    preview.convert("RGB").save(QA_ROOT / name, quality=94)


def main() -> None:
    results = [prepare_sheet(spec) for spec in SHEETS]
    build_preview(results, (18, 24, 30, 255), "victory_loot_boxes_78px_dark_preview.jpg")
    build_preview(results, (238, 232, 214, 255), "victory_loot_boxes_78px_light_preview.jpg")
    manifest = {
        "schema_version": 1,
        "generated_at": "2026-07-28",
        "source_policy": "AutoSprite MCP final frames; deterministic finishing only",
        "runtime_contract": {
            "grid": [COLS, ROWS],
            "frame_count": FRAME_COUNT,
            "cell_size": [CELL_SIZE, CELL_SIZE],
            "frame_order": "left-to-right, top-to-bottom",
            "frame_0": "fully closed",
            "safe_last_frame": 15,
            "display_size_px": DISPLAY_SIZE,
        },
        "accepted": results,
        "rejected": [
            {
                "kind": "guaranteed_mythic",
                "job_id": "wf_1fa22c11-c102-48b4-8644-0ef8cc316f9c",
                "spritesheet_id": "cms4h07io000813ste2csttpk",
                "reason": "forward beam and particles touched cell edges and crossed the floor line",
            },
            {
                "kind": "guaranteed_mythic",
                "job_id": "wf_401f7372-9ef8-4cd2-b3a1-5e551b8a1b78",
                "spritesheet_id": "cms4h4eb9001x13st00gjwf4e",
                "reason": "broken seal and fragments remained on the floor through the final hold",
            }
        ],
    }
    manifest_path = SOURCE_ROOT / "victory_loot_box_autosprite_manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    runtime_manifest_path = RUNTIME_ROOT / "victory_loot_box_autosprite_manifest.json"
    shutil.copyfile(manifest_path, runtime_manifest_path)
    print(f"prepared {len(results)} sheets")
    print(f"manifest: {manifest_path}")
    print(f"runtime manifest: {runtime_manifest_path}")
    for result in results:
        print(f"{result['kind']}: {result['sha256']['runtime']}")


if __name__ == "__main__":
    main()
