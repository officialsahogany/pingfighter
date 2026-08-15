"""Prepare candidate-only R3-A1 secondary, trail, and turn-court materials.

The seven workspace masters are image-generation edits of the approved road
road silhouettes.  They remain under the ignored ``tmp/imagegen`` tree.  This
helper pins every master hash, fits it onto the existing 512px runtime canvas,
checks the alpha silhouette against its approved main-road counterpart, and
publishes a self-contained manifest without touching the R2 art manifest.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from prepare_plaza_r2_environment_assets import (
    REPO_ROOT,
    SOURCE_RETENTION_POLICY,
    enforce_vram_import_policy,
    fit_transparent_source,
    image_qa,
    save_rgba,
    sha256,
    write_json,
)


SOURCE_ROOT = REPO_ROOT / "tmp" / "imagegen" / "plaza_r3a1_road_hierarchy"
OUTPUT_ROOT = (
    REPO_ROOT
    / "godot"
    / "assets"
    / "ui"
    / "plaza"
    / "environment"
    / "hwangyeok_r2"
)
OUTPUT_RES_ROOT = "res://assets/ui/plaza/environment/hwangyeok_r2"

# This is an authored navigation surface, not a value inferred from the R3
# generator.  Runtime generation carries the same polygon and contract id, while
# focused QA compares the two authorities so a code-only drift cannot self-pass.
CENTRAL_PLAZA_WALKABLE_HUB = {
    "id": "hwangyeok_r3a1_central_plaza_hub_v1",
    "layout_record_id": "approved_ground_central_plaza_walkable_hub",
    "polygon_world": [
        [214.0, 576.0],
        [1006.0, 190.0],
        [2286.0, 951.0],
        [1462.0, 1347.0],
    ],
    "navigation_policy": "full_body_walkable_union_member",
    "road_render_policy": "no_straight_stamp_inside_hub",
}


def polygon_token(points: list[list[float]]) -> str:
    return ";".join(f"{float(x):.3f},{float(y):.3f}" for x, y in points)

ROAD_VARIANTS = (
    {
        "asset_id": "secondary_horizontal",
        "edge_kind": "secondary",
        "basis": "horizontal",
        "source_name": "plaza_hwangyeok_road_secondary_horizontal_v1_alpha.png",
        "source_sha256": "5214676bc74ed5b8871786dc4e6882796bbec669e85e733c42860ab29df765d0",
        "output_name": "plaza_hwangyeok_road_secondary_horizontal_v1.png",
        "reference_name": "plaza_hwangyeok_road_straight_horizontal_v1.png",
        "minimum_alpha_iou": 0.72,
        "intent": "trimless worn stone secondary road",
    },
    {
        "asset_id": "secondary_positive",
        "edge_kind": "secondary",
        "basis": "positive",
        "source_name": "plaza_hwangyeok_road_secondary_positive_v1_alpha.png",
        "source_sha256": "1d59e7971898b1edef18a4a3aea48d5d2dbb197d26aee5793da2dbca13c268b4",
        "output_name": "plaza_hwangyeok_road_secondary_positive_v1.png",
        "reference_name": "plaza_hwangyeok_road_straight_positive_v1.png",
        "minimum_alpha_iou": 0.70,
        "intent": "trimless worn stone secondary road",
    },
    {
        "asset_id": "secondary_negative",
        "edge_kind": "secondary",
        "basis": "negative",
        "source_name": "plaza_hwangyeok_road_secondary_negative_v1_alpha.png",
        "source_sha256": "a0c3e64ed7ca925e97cfeba7a07d7afa8be10fa09792b175ebb5cb482144b849",
        "output_name": "plaza_hwangyeok_road_secondary_negative_v1.png",
        "reference_name": "plaza_hwangyeok_road_straight_negative_v1.png",
        "minimum_alpha_iou": 0.70,
        "intent": "trimless worn stone secondary road",
    },
    {
        "asset_id": "trail_horizontal",
        "edge_kind": "trail",
        "basis": "horizontal",
        "source_name": "plaza_hwangyeok_road_trail_horizontal_v1_alpha.png",
        "source_sha256": "1f862dd654a43af85ff43c2c4b9d0608a41151c6ba6781375f351a04cd798e0c",
        "output_name": "plaza_hwangyeok_road_trail_horizontal_v1.png",
        "reference_name": "plaza_hwangyeok_road_straight_horizontal_v1.png",
        "minimum_alpha_iou": 0.68,
        "intent": "compacted earth and gravel trail",
    },
    {
        "asset_id": "trail_positive",
        "edge_kind": "trail",
        "basis": "positive",
        "source_name": "plaza_hwangyeok_road_trail_positive_v1_alpha.png",
        "source_sha256": "65aa460e84275f63a866d447518f8a4c06fc716a62d24f3e6b8e68fee24a17bd",
        "output_name": "plaza_hwangyeok_road_trail_positive_v1.png",
        "reference_name": "plaza_hwangyeok_road_straight_positive_v1.png",
        "minimum_alpha_iou": 0.66,
        "intent": "compacted earth and gravel trail",
    },
    {
        "asset_id": "trail_negative",
        "edge_kind": "trail",
        "basis": "negative",
        "source_name": "plaza_hwangyeok_road_trail_negative_v1_alpha.png",
        "source_sha256": "30fa7c17899bb46fda48d60d67165ae2b4d3e25bed5fbddc637b56c87e9dd79a",
        "output_name": "plaza_hwangyeok_road_trail_negative_v1.png",
        "reference_name": "plaza_hwangyeok_road_straight_negative_v1.png",
        "minimum_alpha_iou": 0.66,
        "intent": "compacted earth and gravel trail",
    },
    {
        "asset_id": "turn_court",
        "edge_kind": "junction",
        "basis": "rotation_symmetric",
        "source_name": "plaza_hwangyeok_road_turn_court_v1_alpha.png",
        "source_sha256": "2ee3a75f9a0f351c7768461bc618d27d9d7b62fed570c76796029d415ec4c76e",
        "output_name": "plaza_hwangyeok_road_turn_court_v1.png",
        "intent": "direction-neutral paved court covering authored degree-two road turns",
    },
)


def require_source(spec: dict) -> Path:
    source_path = SOURCE_ROOT / spec["source_name"]
    if not source_path.exists():
        raise RuntimeError(f"Required generated road material is missing: {source_path}")
    actual_sha = sha256(source_path)
    if actual_sha != spec["source_sha256"]:
        raise RuntimeError(
            f"Generated road material hash drift: {source_path} "
            f"({actual_sha} != {spec['source_sha256']})"
        )
    return source_path


def alpha_geometry_qa(runtime_rgba: np.ndarray, reference_path: Path, minimum_iou: float) -> dict:
    reference = np.asarray(Image.open(reference_path).convert("RGBA"), dtype=np.uint8)
    candidate_mask = runtime_rgba[..., 3] >= 24
    reference_mask = reference[..., 3] >= 24
    intersection = int(np.count_nonzero(candidate_mask & reference_mask))
    union = int(np.count_nonzero(candidate_mask | reference_mask))
    iou = intersection / max(1, union)
    if iou < minimum_iou:
        raise RuntimeError(
            f"Road material silhouette IoU {iou:.6f} is below {minimum_iou:.6f}: {reference_path}"
        )
    visible_rgb = runtime_rgba[candidate_mask, :3].astype(np.float32)
    luminance = (
        visible_rgb[:, 0] * 0.2126
        + visible_rgb[:, 1] * 0.7152
        + visible_rgb[:, 2] * 0.0722
    )
    return {
        "alpha_iou_against_main": iou,
        "alpha_intersection_pixels": intersection,
        "alpha_union_pixels": union,
        "visible_mean_luminance_8bit": float(luminance.mean()),
    }


def turn_court_geometry_qa(runtime_rgba: np.ndarray) -> dict:
    mask = runtime_rgba[..., 3] >= 24
    rotated = np.rot90(mask, 2)
    intersection = int(np.count_nonzero(mask & rotated))
    union = int(np.count_nonzero(mask | rotated))
    symmetry_iou = intersection / max(1, union)
    if symmetry_iou < 0.96:
        raise RuntimeError(
            f"Turn-court 180-degree alpha symmetry {symmetry_iou:.6f} is below 0.960000"
        )
    visible_rgb = runtime_rgba[mask, :3].astype(np.float32)
    luminance = (
        visible_rgb[:, 0] * 0.2126
        + visible_rgb[:, 1] * 0.7152
        + visible_rgb[:, 2] * 0.0722
    )
    return {
        "alpha_rotation_180_iou": symmetry_iou,
        "alpha_intersection_pixels": intersection,
        "alpha_union_pixels": union,
        "visible_mean_luminance_8bit": float(luminance.mean()),
        "directional_arm_count": 0,
    }


def isolate_primary_sprite(image: Image.Image) -> Image.Image:
    """Discard faint image-generation residue outside the authored road body."""
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    labels, count = ndimage.label(rgba[..., 3] >= 32)
    if count < 1:
        raise RuntimeError("Generated road material has no opaque component")
    component_sizes = ndimage.sum(
        np.ones(labels.shape, dtype=np.uint8), labels, range(1, count + 1)
    )
    primary_label = int(np.argmax(component_sizes)) + 1
    ys, xs = np.where(labels == primary_label)
    if xs.size < 1_000:
        raise RuntimeError("Generated road material primary component is unexpectedly small")
    padding = 5
    x0 = max(0, int(xs.min()) - padding)
    y0 = max(0, int(ys.min()) - padding)
    x1 = min(rgba.shape[1], int(xs.max()) + 1 + padding)
    y1 = min(rgba.shape[0], int(ys.max()) + 1 + padding)
    isolated = np.zeros_like(rgba)
    isolated[y0:y1, x0:x1] = rgba[y0:y1, x0:x1]
    isolated[isolated[..., 3] < 3] = 0
    return Image.fromarray(isolated)


def main() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    outputs: list[dict] = []
    for spec in ROAD_VARIANTS:
        source_path = require_source(spec)
        source_image = isolate_primary_sprite(Image.open(source_path).convert("RGBA"))
        runtime_rgba, placement = fit_transparent_source(source_image, bottom_align=False)
        output_path = OUTPUT_ROOT / spec["output_name"]
        if spec["asset_id"] == "turn_court":
            geometry_qa = turn_court_geometry_qa(runtime_rgba)
        else:
            geometry_qa = alpha_geometry_qa(
                runtime_rgba,
                OUTPUT_ROOT / spec["reference_name"],
                spec["minimum_alpha_iou"],
            )
        save_rgba(output_path, runtime_rgba)
        qa = image_qa(output_path, expect_opaque=False)
        qa.update(geometry_qa)
        outputs.append(
            {
                "kind": "road_piece",
                "asset_id": spec["asset_id"],
                "edge_kind": spec["edge_kind"],
                "basis": spec["basis"],
                "res_path": f"{OUTPUT_RES_ROOT}/{spec['output_name']}",
                "source_path": source_path.relative_to(REPO_ROOT).as_posix(),
                "source_sha256": spec["source_sha256"],
                "generation_intent": spec["intent"],
                "placement": placement,
                "qa": qa,
                "import": enforce_vram_import_policy(output_path),
            }
        )

    means = {
        item["asset_id"]: float(item["qa"]["visible_mean_luminance_8bit"])
        for item in outputs
    }
    for basis in ("horizontal", "positive", "negative"):
        secondary = means[f"secondary_{basis}"]
        trail = means[f"trail_{basis}"]
        if secondary <= trail + 3.0:
            raise RuntimeError(
                f"Road hierarchy lacks material luminance separation for {basis}: "
                f"secondary={secondary:.3f} trail={trail:.3f}"
            )

    aggregate = hashlib.sha256()
    for item in sorted(outputs, key=lambda value: value["asset_id"]):
        aggregate.update(item["asset_id"].encode("utf-8"))
        aggregate.update(b"\0")
        aggregate.update(bytes.fromhex(item["qa"]["sha256"]))
    import_statuses = [item["import"]["status"] for item in outputs]
    qa_manifest = {
        "status": "pass",
        "failure_count": 0,
        "pipeline": "hwangyeok_plaza_r3a1_road_hierarchy_extension_prep",
        "candidate_only": True,
        "production_connected": False,
        "asset_counts": {"road_piece": len(outputs), "turn_court": 1, "total": len(outputs)},
        "aggregate_runtime_sha256": aggregate.hexdigest(),
        "material_mean_luminance_8bit": means,
        "import_status_counts": {
            status: import_statuses.count(status)
            for status in sorted(set(import_statuses))
        },
        "source_retention_policy": SOURCE_RETENTION_POLICY,
        "approved_layout_geometry_count": 1,
    }
    hub_contract = dict(CENTRAL_PLAZA_WALKABLE_HUB)
    hub_contract["polygon_sha256"] = hashlib.sha256(
        polygon_token(hub_contract["polygon_world"]).encode("utf-8")
    ).hexdigest()
    manifest = {
        "schema_version": 1,
        "status": "r3a1_candidate_road_hierarchy_art_ready",
        "runtime_usage": "candidate_only_hwangyeok_plaza_2d_road_material_hierarchy",
        "candidate_only": True,
        "production_connected": False,
        "source_retention_policy": SOURCE_RETENTION_POLICY,
        "approved_source_hashes": {
            spec["asset_id"]: spec["source_sha256"] for spec in ROAD_VARIANTS
        },
        "assets": outputs,
        "approved_layout_geometry": {
            "central_plaza_walkable_hub": hub_contract,
        },
        "qa": qa_manifest,
    }
    write_json(
        OUTPUT_ROOT / "plaza_hwangyeok_r3a1_road_hierarchy_manifest.json",
        manifest,
    )
    write_json(
        OUTPUT_ROOT / "plaza_hwangyeok_r3a1_road_hierarchy_qa.json",
        qa_manifest,
    )
    print(json.dumps(qa_manifest, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
