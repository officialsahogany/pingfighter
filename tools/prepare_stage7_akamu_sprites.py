# -*- coding: utf-8 -*-
"""Prepare accepted AutoSprite Akamu sheets for the Godot runtime.

AutoSprite exports eight 512x512 frames in a 3x3 atlas.  The live renderer
uses deterministic 4x2 atlases with 256x256 cells so battle entry never has
to scan alpha, crop images, or build textures.  This script applies one fixed
transform per animation, locks every animation's first-frame body scale to the
accepted walk-right anchor, and emits a machine-readable QA report.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE_DIR = ROOT / ".tmp" / "stage7_akamu_sprite"
DEFAULT_OUTPUT_DIR = ROOT / "godot" / "assets" / "sprites" / "bosses" / "stage7_akamu"
DEFAULT_QA_PATH = DEFAULT_SOURCE_DIR / "stage7_akamu_runtime_qa.json"

FRAME_COUNT = 8
SOURCE_CELL_SIZE = 512
OUTPUT_CELL_SIZE = 256
OUTPUT_COLS = 4
OUTPUT_ROWS = 2
ALPHA_THRESHOLD = 8
OUTPUT_EDGE_MARGIN = 4
TARGET_ANCHOR_HEIGHT = 220
TARGET_ANCHOR_CENTER_X = OUTPUT_CELL_SIZE // 2
TARGET_GROUND_Y = 238
IDENTITY_SCALE_TOLERANCE = 0.05
# Collapse frames naturally change their source-frame floor coordinate.  Keep
# one identity scale, but normalize each defeat frame to the shared foot/floor
# anchor so seated frames neither clip the 256px cell nor make the actor jump.
PER_FRAME_GROUND_ANCHORED_KEYS = {"defeat"}

# 런타임 계약은 9장(dash는 native left/right 분리 — 미러 금지). 단일 dash
# 소스로 재실행하면 존재하지 않는 stage7_akamu_boss_dash.png와 8장 manifest를
# 되살리므로, L/R 소스가 준비된 경우에만 dash 키를 채워 재실행할 것.
SOURCE_FILES = {
    "idle": "akamu_idle_front_source_v2.png",
    "walk_left": "akamu_walk_left_front_source_v2.png",
    "walk_right": "akamu_walk_right_front_source_v2.png",
    "attack": "akamu_attack_front_source_v1.png",
    "dash_left": "akamu_dash_left_front_source_v1.png",
    "dash_right": "akamu_dash_right_front_source_v1.png",
    "victory": "akamu_victory_front_source_v1.png",
    "defeat": "akamu_defeat_front_source_v1.png",
    "stun": "akamu_stun_front_source_v1.png",
}

AUTOSPRITE_CHARACTER_ID = "cmreqsh82000bhoupp5a34bvh"
AUTOSPRITE_FRONT_POSE_ID = "cmreqxeb1000ja7xk79ts747m"
PROVENANCE = {
    "idle": {
        "job_id": "wf_14321fe2-9964-45e7-a34f-f75f2e610b35",
        "spritesheet_id": "cmrerfet80002yp137xbphu43",
        "source_video_id": "cmrer9mxs000zhoupo2pu2dr9",
        "loop": True,
    },
    "walk_left": {
        "job_id": "wf_23338dc8-c19b-4f50-aded-6bc92a2ff479",
        "spritesheet_id": "cmrerbfxe000j5teul6r9x9ou",
        "source_video_id": "cmrer6vm7005ixycvmyp06iqm",
        "loop": True,
    },
    "walk_right": {
        "job_id": "wf_6a105cee-7686-4a68-8c92-1224606ff49b",
        "spritesheet_id": "cmres0win0013mbfw9lkwbrgq",
        "source_video_id": "cmreryso5001vhnnxbsqywd5o",
        "loop": True,
    },
    "attack": {
        "job_id": "wf_15953fb0-da82-4bc6-b2a8-7722bf73187a",
        "spritesheet_id": "cmrer5n4v0005uepfljczfgxp",
        "source_video_id": "cmrer47zk004bxycv33fb515g",
        "loop": False,
    },
    "dash": {
        "job_id": "wf_a4324566-654f-485b-9853-1b3998297858",
        "spritesheet_id": "cmrer732y001ouepf39p2im3u",
        "source_video_id": "cmrer48el004pxycvblxdcpeg",
        "loop": False,
    },
    "victory": {
        "job_id": "wf_0afbadc8-9b7b-4df5-a11c-20431e4a297a",
        "spritesheet_id": "cmrer5m5a005bxycv634y0bld",
        "source_video_id": "cmrer47yd0049xycvkimu3gat",
        "loop": False,
    },
    "defeat": {
        "job_id": "wf_e8c1d842-ed19-4b36-a17a-eeb8148eeec8",
        "spritesheet_id": "cmrer5lkg0001uepfletmkvr1",
        "source_video_id": "cmrer4817004fxycvs2qmvex0",
        "loop": False,
    },
    "stun": {
        "job_id": "wf_570df83d-ae8b-478e-a257-e991194de236",
        "spritesheet_id": "cmrer6zks0002bp54gzp5jcza",
        "source_video_id": "cmrer48kt004txycvgmynh8i9",
        "loop": True,
    },
}

REJECTED_CANDIDATES = [
    {
        "state": "idle",
        "job_id": "wf_6d9b919c-56c4-4d78-9bbe-9c39a97b0805",
        "spritesheet_id": "cmreqw41w00062f5xwj3u25qb",
        "source_video_id": "cmreqt1r80028ho2m0r5nlc7a",
        "reason": "Rejected: 3/4 profile idle violated the front-facing boss contract.",
    },
    {
        "state": "walk_right",
        "job_id": "wf_053ddaca-b84a-489e-973e-ccd09ff62844",
        "spritesheet_id": "cmrequvoy000khoupht30hcz4",
        "source_video_id": "cmreqt1t8002aho2m9r144k76",
        "reason": "Rejected: initial unanchored walk read as a side/profile character.",
    },
    {
        "state": "walk_right",
        "job_id": "wf_3b7d8de0-18bb-4499-8e4e-9a29f36f175b",
        "spritesheet_id": "cmrer1kdu001ua7xkdk4kjuv7",
        "source_video_id": "cmreqyxom0018a7xkntm9rfgq",
        "reason": "Rejected at final 4x2 QA: several middle frames yawed into a 3/4 walk.",
    },
    {
        "state": "walk_left",
        "job_id": "wf_056209b9-2091-443b-81b1-5267838ffc59",
        "spritesheet_id": "cmrer4ja20009b8vunwwk7ohm",
        "source_video_id": "cmrer2lcz002ba7xk227atlsh",
        "reason": "Rejected: identity passed but the eight-frame walk cycle had too little leg motion.",
    },
    {
        "state": "idle",
        "job_id": "wf_8de2426a-4155-4e22-bbc5-d6fd8bca967c",
        "spritesheet_id": "cmrer5wcl000cuepf53tbvulr",
        "source_video_id": "cmrer48lp004vxycv81jc5j21",
        "reason": "Rejected: middle idle frames rotated into a right-facing 3/4 pose.",
    },
]


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _visible_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value > ALPHA_THRESHOLD else 0)
    return mask.getbbox()


def _bbox_size(bbox: tuple[int, int, int, int]) -> tuple[int, int]:
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def _bbox_touches_source_edge(bbox: tuple[int, int, int, int]) -> bool:
    return bbox[0] <= 1 or bbox[1] <= 1 or bbox[2] >= SOURCE_CELL_SIZE - 1 or bbox[3] >= SOURCE_CELL_SIZE - 1


def _bbox_touches_output_edge(bbox: tuple[int, int, int, int]) -> bool:
    return (
        bbox[0] < OUTPUT_EDGE_MARGIN
        or bbox[1] < OUTPUT_EDGE_MARGIN
        or bbox[2] > OUTPUT_CELL_SIZE - OUTPUT_EDGE_MARGIN
        or bbox[3] > OUTPUT_CELL_SIZE - OUTPUT_EDGE_MARGIN
    )


def _load_source_frames(path: Path) -> list[Image.Image]:
    image = Image.open(path).convert("RGBA")
    expected_width = SOURCE_CELL_SIZE * 3
    expected_height = SOURCE_CELL_SIZE * 3
    if image.size != (expected_width, expected_height):
        raise ValueError(f"{path}: expected {expected_width}x{expected_height}, got {image.width}x{image.height}")
    frames: list[Image.Image] = []
    for frame_index in range(FRAME_COUNT):
        col = frame_index % 3
        row = frame_index // 3
        frames.append(image.crop((
            col * SOURCE_CELL_SIZE,
            row * SOURCE_CELL_SIZE,
            (col + 1) * SOURCE_CELL_SIZE,
            (row + 1) * SOURCE_CELL_SIZE,
        )))
    return frames


def _transform_frame(
    frame: Image.Image,
    scale: float,
    offset_x: int,
    offset_y: int,
) -> Image.Image:
    resized_size = (
        max(1, int(round(frame.width * scale))),
        max(1, int(round(frame.height * scale))),
    )
    resized = frame.resize(resized_size, Image.Resampling.NEAREST)
    output = Image.new("RGBA", (OUTPUT_CELL_SIZE, OUTPUT_CELL_SIZE), (0, 0, 0, 0))
    output.alpha_composite(resized, (offset_x, offset_y))
    return output


def _prepare_animation(
    key: str,
    source_path: Path,
    output_path: Path,
    reference_anchor_size: tuple[int, int],
) -> dict[str, Any]:
    frames = _load_source_frames(source_path)
    source_bboxes: list[tuple[int, int, int, int]] = []
    for frame_index, frame in enumerate(frames):
        bbox = _visible_bbox(frame)
        if bbox is None:
            raise ValueError(f"{source_path}: frame {frame_index} has no visible pixels")
        if _bbox_touches_source_edge(bbox):
            raise ValueError(f"{source_path}: frame {frame_index} touches the source cell edge: {bbox}")
        source_bboxes.append(bbox)

    anchor_bbox = source_bboxes[0]
    anchor_size = _bbox_size(anchor_bbox)
    for axis, current, reference in zip(("width", "height"), anchor_size, reference_anchor_size):
        drift = abs(float(current) / max(1.0, float(reference)) - 1.0)
        if drift > IDENTITY_SCALE_TOLERANCE:
            raise ValueError(
                f"{source_path}: first-frame {axis} drift {drift:.3%} exceeds "
                f"{IDENTITY_SCALE_TOLERANCE:.1%} identity lock"
            )

    scale = TARGET_ANCHOR_HEIGHT / float(anchor_size[1])
    anchor_center_x = (anchor_bbox[0] + anchor_bbox[2]) * 0.5
    offset_x = int(round(TARGET_ANCHOR_CENTER_X - anchor_center_x * scale))
    offset_y = int(round(TARGET_GROUND_Y - anchor_bbox[3] * scale))

    output_frames: list[Image.Image] = []
    output_bboxes: list[tuple[int, int, int, int]] = []
    frame_offsets: list[tuple[int, int]] = []
    for frame_index, frame in enumerate(frames):
        frame_offset_x = offset_x
        frame_offset_y = offset_y
        if key in PER_FRAME_GROUND_ANCHORED_KEYS:
            frame_bbox = source_bboxes[frame_index]
            frame_center_x = (frame_bbox[0] + frame_bbox[2]) * 0.5
            frame_offset_x = int(round(TARGET_ANCHOR_CENTER_X - frame_center_x * scale))
            frame_offset_y = int(round(TARGET_GROUND_Y - frame_bbox[3] * scale))
        frame_offsets.append((frame_offset_x, frame_offset_y))
        output_frame = _transform_frame(frame, scale, frame_offset_x, frame_offset_y)
        bbox = _visible_bbox(output_frame)
        if bbox is None:
            raise ValueError(f"{source_path}: transformed frame {frame_index} has no visible pixels")
        if _bbox_touches_output_edge(bbox):
            raise ValueError(f"{source_path}: transformed frame {frame_index} violates output margin: {bbox}")
        output_frames.append(output_frame)
        output_bboxes.append(bbox)

    sheet = Image.new(
        "RGBA",
        (OUTPUT_CELL_SIZE * OUTPUT_COLS, OUTPUT_CELL_SIZE * OUTPUT_ROWS),
        (0, 0, 0, 0),
    )
    for frame_index, frame in enumerate(output_frames):
        col = frame_index % OUTPUT_COLS
        row = frame_index // OUTPUT_COLS
        sheet.alpha_composite(frame, (col * OUTPUT_CELL_SIZE, row * OUTPUT_CELL_SIZE))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, optimize=True)
    return {
        "key": key,
        "source": source_path.relative_to(ROOT).as_posix(),
        "output": output_path.relative_to(ROOT).as_posix(),
        "source_sha256": _sha256(source_path),
        "output_sha256": _sha256(output_path),
        "source_anchor_bbox": list(anchor_bbox),
        "source_anchor_size": list(anchor_size),
        "scale": scale,
        "alignment": "per_frame_ground" if key in PER_FRAME_GROUND_ANCHORED_KEYS else "fixed_sheet",
        "fixed_offset": [offset_x, offset_y],
        "frame_offsets": [list(value) for value in frame_offsets],
        "source_frame_bboxes": [list(bbox) for bbox in source_bboxes],
        "output_frame_bboxes": [list(bbox) for bbox in output_bboxes],
        "source_edge_touch": False,
        "output_edge_touch": False,
    }


def _write_runtime_manifest(report: dict[str, Any], output_dir: Path) -> Path:
    assets: list[dict[str, Any]] = []
    for animation in report["animations"]:
        key = str(animation["key"])
        provenance = PROVENANCE[key]
        assets.append({
            "state": key,
            "path": f"res://assets/sprites/bosses/stage7_akamu/stage7_akamu_boss_{key}.png",
            "cols": OUTPUT_COLS,
            "rows": OUTPUT_ROWS,
            "frames": FRAME_COUNT,
            "cell_width": OUTPUT_CELL_SIZE,
            "cell_height": OUTPUT_CELL_SIZE,
            "width": OUTPUT_CELL_SIZE * OUTPUT_COLS,
            "height": OUTPUT_CELL_SIZE * OUTPUT_ROWS,
            "image_mode": "RGBA",
            "job_id": provenance["job_id"],
            "spritesheet_id": provenance["spritesheet_id"],
            "source_video_id": provenance["source_video_id"],
            "loop": provenance["loop"],
            "source_sha256": animation["source_sha256"],
            "sha256": animation["output_sha256"],
            "corner_alpha": [0, 0, 0, 0],
            "identity_anchor_size": animation["source_anchor_size"],
            "alignment": animation["alignment"],
            "source_edge_touch": animation["source_edge_touch"],
            "output_edge_touch": animation["output_edge_touch"],
        })

    manifest: dict[str, Any] = {
        "boss_id": "stage7_akamu_rigo",
        "display_name_ko": "아카무 리고",
        "stage": 7,
        "legacy_stage": 8,
        "autosprite_character_id": AUTOSPRITE_CHARACTER_ID,
        "autosprite_front_pose_id": AUTOSPRITE_FRONT_POSE_ID,
        "workflow_mode": "precise",
        "accepted_at": "2026-07-10",
        "asset_root": "res://assets/sprites/bosses/stage7_akamu/",
        "identity_lock": (
            "long scarlet high ponytail, silver hairpin, red eyes, pale face, dark plum wrap ninja jacket, "
            "black neck guard, olive shorts, thigh bands, cream tabi boots, chibi thick-outline pixel art"
        ),
        "runtime_priority": [
            "defeat",
            "victory",
            "stun",
            "dash",
            "attack",
            "walk_left/walk_right",
            "idle",
        ],
        "grid_authority_note": "All eight accepted runtime sheets are deterministic 4x2 exports with 256px cells and eight row-major frames.",
        "postprocess": "tools/prepare_stage7_akamu_sprites.py; one fixed NEAREST transform per sheet, with defeat-only per-frame ground anchoring; no runtime slicing or alpha scan.",
        "result_reuse": "The Stage 7 clear-result actor loads the same stage7_akamu_boss_defeat.png sheet.",
        "native_direction_policy": "walk_left and walk_right are separate accepted AutoSprite motions; runtime horizontal mirroring is forbidden.",
        "assets": assets,
        "rejected_candidates": REJECTED_CANDIDATES,
    }
    manifest_path = output_dir / "stage7_akamu_boss_sprite_manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest_path


def prepare(source_dir: Path, output_dir: Path, qa_path: Path) -> dict[str, Any]:
    source_paths = {key: source_dir / file_name for key, file_name in SOURCE_FILES.items()}
    missing = [path for path in source_paths.values() if not path.is_file()]
    if missing:
        formatted = "\n".join(f"- {path}" for path in missing)
        raise FileNotFoundError(f"Missing accepted AutoSprite source sheets:\n{formatted}")

    reference_frames = _load_source_frames(source_paths["walk_right"])
    reference_bbox = _visible_bbox(reference_frames[0])
    if reference_bbox is None:
        raise ValueError("Accepted walk-right anchor frame has no visible pixels")
    reference_anchor_size = _bbox_size(reference_bbox)

    reports: list[dict[str, Any]] = []
    for key in SOURCE_FILES:
        output_path = output_dir / f"stage7_akamu_boss_{key}.png"
        reports.append(_prepare_animation(
            key,
            source_paths[key],
            output_path,
            reference_anchor_size,
        ))

    report: dict[str, Any] = {
        "character": "Akamu Rigo",
        "runtime_grid": {"columns": OUTPUT_COLS, "rows": OUTPUT_ROWS, "frame_count": FRAME_COUNT},
        "source_cell_size": SOURCE_CELL_SIZE,
        "output_cell_size": OUTPUT_CELL_SIZE,
        "target_anchor_height": TARGET_ANCHOR_HEIGHT,
        "target_ground_y": TARGET_GROUND_Y,
        "identity_scale_tolerance": IDENTITY_SCALE_TOLERANCE,
        "reference_anchor_size": list(reference_anchor_size),
        "animations": reports,
    }
    qa_path.parent.mkdir(parents=True, exist_ok=True)
    qa_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    manifest_path = _write_runtime_manifest(report, output_dir)
    report["manifest"] = manifest_path.relative_to(ROOT).as_posix()
    return report


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE_DIR)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--qa-output", type=Path, default=DEFAULT_QA_PATH)
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    report = prepare(args.source_dir.resolve(), args.output_dir.resolve(), args.qa_output.resolve())
    print(json.dumps({
        "animations": len(report["animations"]),
        "output_dir": args.output_dir.resolve().as_posix(),
        "qa_output": args.qa_output.resolve().as_posix(),
        "manifest": report["manifest"],
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
