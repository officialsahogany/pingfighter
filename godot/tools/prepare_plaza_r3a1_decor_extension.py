"""Prepare the workspace-only R3-A1 semantic decor extension.

The generated source masters remain under the gitignored ``tmp/imagegen``
tree.  This helper pins their hashes, produces two self-contained 512px
runtime cutouts, and records the same source-retention/import contract as the
approved R2 environment set.  It never mutates the R2 base manifest.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

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


SOURCE_ROOT = REPO_ROOT / "tmp" / "imagegen" / "plaza_r3a1_decor"
ROAD_SOURCE_ROOT = REPO_ROOT / "tmp" / "imagegen" / "plaza_r3a1_axis_roads"
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

DECOR_EXTENSION_SOURCES = (
    {
        "asset_id": "ritual_stone_garden",
        "source_name": "plaza_hwangyeok_decor_ritual_stone_garden_v1_alpha.png",
        "source_sha256": "3a564dd8268cc579f2c1223e382664749a3e38f89c75bf387a1ef826b213b91a",
        "output_name": "plaza_hwangyeok_decor_ritual_stone_garden_v1.png",
        "semantic_cluster_types": ["seal_stone_court", "jade_rock_garden"],
        "generation_intent": "ritual seal court plus jade scholar-rock garden",
    },
    {
        "asset_id": "stone_lantern_rest",
        "source_name": "plaza_hwangyeok_decor_stone_lantern_rest_v1_alpha.png",
        "source_sha256": "e43770f2fed088931ba10f903704105c198477a4e951fe06dc134e93481d8b9c",
        "output_name": "plaza_hwangyeok_decor_stone_lantern_rest_v1.png",
        "semantic_cluster_types": ["bench_and_lanterns", "stone_lantern_gate"],
        "generation_intent": "paired stone-lantern gate plus two-bench resting court",
    },
)

AXIS_ROAD_EXTENSION_SOURCES = (
    {
        "asset_id": "straight_horizontal",
        "source_name": "plaza_hwangyeok_road_straight_horizontal_v1_alpha.png",
        "source_sha256": "b9c894e3f48001611fa5bd245abea66f0be7c13bc2c5b7dc2559c07494873a90",
        "output_name": "plaza_hwangyeok_road_straight_horizontal_v1.png",
        "basis": "horizontal",
    },
    {
        "asset_id": "straight_vertical",
        "source_name": "plaza_hwangyeok_road_straight_vertical_v1_alpha.png",
        "source_sha256": "147dc9268bbc6c1c329837a7294edc26f18ec4f73ed0dd3abdc2889a02b753ad",
        "output_name": "plaza_hwangyeok_road_straight_vertical_v1.png",
        "basis": "vertical",
    },
)


def require_source(spec: dict) -> Path:
    source_path = SOURCE_ROOT / spec["source_name"]
    if not source_path.exists():
        raise RuntimeError(f"Required generated decor master is missing: {source_path}")
    actual_sha = sha256(source_path)
    if actual_sha != spec["source_sha256"]:
        raise RuntimeError(
            f"Generated decor master hash drift: {source_path} "
            f"({actual_sha} != {spec['source_sha256']})"
        )
    return source_path


def require_road_source(spec: dict) -> Path:
    source_path = ROAD_SOURCE_ROOT / spec["source_name"]
    if not source_path.exists():
        raise RuntimeError(f"Required generated axis-road master is missing: {source_path}")
    actual_sha = sha256(source_path)
    if actual_sha != spec["source_sha256"]:
        raise RuntimeError(
            f"Generated axis-road master hash drift: {source_path} "
            f"({actual_sha} != {spec['source_sha256']})"
        )
    return source_path


def main() -> None:
    from PIL import Image

    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    outputs: list[dict] = []
    for spec in AXIS_ROAD_EXTENSION_SOURCES:
        source_path = require_road_source(spec)
        source_image = Image.open(source_path).convert("RGBA")
        runtime_rgba, placement = fit_transparent_source(
            source_image,
            bottom_align=False,
        )
        output_path = OUTPUT_ROOT / spec["output_name"]
        save_rgba(output_path, runtime_rgba)
        outputs.append(
            {
                "kind": "road_piece",
                "asset_id": spec["asset_id"],
                "basis": spec["basis"],
                "res_path": f"{OUTPUT_RES_ROOT}/{spec['output_name']}",
                "source_path": source_path.relative_to(REPO_ROOT).as_posix(),
                "source_sha256": spec["source_sha256"],
                "placement": placement,
                "qa": image_qa(output_path, expect_opaque=False),
                "import": enforce_vram_import_policy(output_path),
            }
        )
    for spec in DECOR_EXTENSION_SOURCES:
        source_path = require_source(spec)
        source_image = Image.open(source_path).convert("RGBA")
        runtime_rgba, placement = fit_transparent_source(
            source_image,
            bottom_align=True,
        )
        output_path = OUTPUT_ROOT / spec["output_name"]
        save_rgba(output_path, runtime_rgba)
        outputs.append(
            {
                "kind": "decor_cluster",
                "asset_id": spec["asset_id"],
                "res_path": f"{OUTPUT_RES_ROOT}/{spec['output_name']}",
                "source_path": source_path.relative_to(REPO_ROOT).as_posix(),
                "source_sha256": spec["source_sha256"],
                "semantic_cluster_types": list(spec["semantic_cluster_types"]),
                "generation_intent": spec["generation_intent"],
                "placement": placement,
                "qa": image_qa(output_path, expect_opaque=False),
                "import": enforce_vram_import_policy(output_path),
            }
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
        "pipeline": "hwangyeok_plaza_r3a1_semantic_decor_extension_prep",
        "candidate_only": True,
        "production_connected": False,
        "asset_counts": {"road_piece": 2, "decor_cluster": 2, "total": len(outputs)},
        "aggregate_runtime_sha256": aggregate.hexdigest(),
        "import_status_counts": {
            status: import_statuses.count(status)
            for status in sorted(set(import_statuses))
        },
        "source_retention_policy": SOURCE_RETENTION_POLICY,
    }
    manifest = {
        "schema_version": 1,
        "status": "r3a1_candidate_runtime_art_ready",
        "runtime_usage": "candidate_only_hwangyeok_plaza_2d_axis_road_and_semantic_decor_extension",
        "candidate_only": True,
        "production_connected": False,
        "source_retention_policy": SOURCE_RETENTION_POLICY,
        "approved_source_hashes": {
            spec["asset_id"]: spec["source_sha256"]
            for spec in AXIS_ROAD_EXTENSION_SOURCES + DECOR_EXTENSION_SOURCES
        },
        "assets": outputs,
        "qa": qa_manifest,
    }
    write_json(
        OUTPUT_ROOT / "plaza_hwangyeok_r3a1_decor_extension_manifest.json",
        manifest,
    )
    write_json(
        OUTPUT_ROOT / "plaza_hwangyeok_r3a1_decor_extension_qa.json",
        qa_manifest,
    )
    print(json.dumps(qa_manifest, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
