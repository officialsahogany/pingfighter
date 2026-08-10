"""Build the self-contained R1 active runtime set from workspace-local art masters.

The approved 1254px masters currently live under gitignored ``tmp/imagegen``.
They are preserved in this workspace but are not available in a clean clone.
Archive them through a separately approved LFS source-art change before treating
this helper as a clean-checkout-reproducible production pipeline.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


REPO_ROOT = Path(__file__).resolve().parents[2]
CANDIDATE_ROOT = REPO_ROOT / "tmp" / "imagegen" / "plaza_hwangyeok_building_layers_v1"
OUTPUT_ROOT = REPO_ROOT / "godot" / "assets" / "ui" / "plaza" / "buildings" / "hwangyeok"
OUTPUT_RES_ROOT = "res://assets/ui/plaza/buildings/hwangyeok"
SOURCE_RETENTION_POLICY = {
    "source_root": "tmp/imagegen",
    "workspace_masters_preserved": True,
    "gitignored": True,
    "clean_checkout_rebuild_supported": False,
    "runtime_outputs_self_contained": True,
    "durable_archive_requires_separate_lfs_promotion": True,
}
TARGET_SIZE = (512, 512)
BUILDING_TYPES = (
    "bank",
    "shop",
    "gacha",
    "lingpet_store",
    "blacksmith",
    "tavern",
    "academy",
)
LAYER_OUTPUT_SUFFIXES = {
    "base": "building_base.png",
    "sign_emissive": "sign_emissive_mask.png",
    "window_glow_mask": "window_glow_mask.png",
}
EXPECTED_RESIZE_CHROMA_CLEANUP_COORDINATES = {
    "bank": [],
    "shop": [],
    "gacha": [[46, 275]],
    "lingpet_store": [[486, 287], [486, 288]],
    "blacksmith": [],
    "tavern": [],
    "academy": [],
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def md5(path: Path) -> str:
    digest = hashlib.md5(usedforsecurity=False)
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: dict) -> None:
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def candidate_manifest_path(building_type: str) -> Path:
    return CANDIDATE_ROOT / building_type / f"plaza_hwangyeok_{building_type}_3q_v1_candidate_manifest.json"


def load_approved_rgba(path: Path, expected_sha256: str) -> np.ndarray:
    actual_sha256 = sha256(path)
    if actual_sha256 != expected_sha256:
        raise RuntimeError(f"Approved source hash drift: {path} ({actual_sha256} != {expected_sha256})")
    image = Image.open(path).convert("RGBA")
    if image.size != (1254, 1254):
        raise RuntimeError(f"Approved source canvas drift: {path} ({image.size})")
    return np.asarray(image, dtype=np.uint8)


def resize_float_channel(channel: np.ndarray) -> np.ndarray:
    image = Image.fromarray(channel.astype(np.float32))
    resized = image.resize(TARGET_SIZE, resample=Image.Resampling.LANCZOS)
    return np.clip(np.asarray(resized, dtype=np.float32), 0.0, 1.0)


def resize_base_premultiplied(rgba: np.ndarray) -> tuple[np.ndarray, dict]:
    source = rgba.astype(np.float32) / 255.0
    source_alpha = source[..., 3]
    resized_alpha = resize_float_channel(source_alpha)
    resized_premultiplied = np.stack(
        [resize_float_channel(source[..., channel] * source_alpha) for channel in range(3)],
        axis=2,
    )
    resized_rgb = np.zeros_like(resized_premultiplied)
    visible = resized_alpha > (0.5 / 255.0)
    resized_rgb[visible] = resized_premultiplied[visible] / resized_alpha[visible, None]
    resized_rgb = np.clip(resized_rgb, 0.0, 1.0)

    output = np.zeros((TARGET_SIZE[1], TARGET_SIZE[0], 4), dtype=np.uint8)
    output[..., :3] = np.rint(resized_rgb * 255.0).astype(np.uint8)
    output[..., 3] = np.rint(resized_alpha * 255.0).astype(np.uint8)
    # Lanczos may ring a source fringe into the final pixel even though the
    # approved 1254px canvas has a transparent perimeter. Preserve that
    # non-contact contract explicitly at the physical runtime boundary.
    output[[0, -1], :, :] = 0
    output[:, [0, -1], :] = 0
    output[output[..., 3] == 0, :3] = 0
    # Downsampling can create one-pixel chroma-colored ringing that was not
    # exterior-connected in the approved source. Remove only components that
    # touch the canonical exterior band; never despill the interior palette.
    removed_pixels = []
    cleanup_iterations = 0
    for iteration in range(8):
        exterior_connected, _, _ = exterior_connected_magenta_mask(output)
        if not np.any(exterior_connected):
            break
        cleanup_iterations += 1
        ys, xs = np.where(exterior_connected)
        for y, x in zip(ys.tolist(), xs.tolist()):
            removed_pixels.append({
                "xy": [int(x), int(y)],
                "rgba_before": [int(value) for value in output[y, x]],
                "iteration": iteration + 1,
            })
        output[exterior_connected] = 0
    remaining_exterior_connected, _, _ = exterior_connected_magenta_mask(output)
    cleanup_qa = {
        "material_edit": bool(removed_pixels),
        "method": "remove_only_exterior_connected_near_magenta_components_created_by_runtime_downscale",
        "removed_pixel_count": len(removed_pixels),
        "removed_runtime_pixel_coordinates_xy": [entry["xy"] for entry in removed_pixels],
        "removed_pixels": removed_pixels,
        "cleanup_iterations": cleanup_iterations,
        "remaining_exterior_connected_magenta_pixels": int(np.count_nonzero(remaining_exterior_connected)),
    }
    return output, cleanup_qa


def resize_white_mask(mask_rgba: np.ndarray, resized_base_alpha: np.ndarray) -> np.ndarray:
    resized_alpha = resize_float_channel(mask_rgba[..., 3].astype(np.float32) / 255.0)
    resized_alpha_u8 = np.rint(resized_alpha * 255.0).astype(np.uint8)
    resized_alpha_u8 = np.minimum(resized_alpha_u8, resized_base_alpha)

    output = np.zeros((TARGET_SIZE[1], TARGET_SIZE[0], 4), dtype=np.uint8)
    visible = resized_alpha_u8 > 0
    output[visible, :3] = 255
    output[..., 3] = resized_alpha_u8
    return output


def save_rgba(path: Path, rgba: np.ndarray) -> None:
    Image.fromarray(rgba).save(path, format="PNG", compress_level=9, optimize=False)


def enforce_vram_import_policy(png_path: Path) -> dict:
    import_path = Path(f"{png_path}.import")
    if not import_path.exists():
        return {
            "status": "pending_godot_source_scan",
            "import_path": import_path.relative_to(REPO_ROOT).as_posix(),
        }

    current = import_path.read_text(encoding="utf-8-sig")
    uid_match = re.search(r'^uid="([^"]+)"$', current, flags=re.MULTILINE)
    destination_match = re.search(r'^path(?:\.bptc|\.astc)?="([^"]+\.ctex)"$', current, flags=re.MULTILINE)
    if uid_match is None or destination_match is None:
        raise RuntimeError(f"Unrecognized Godot texture import sidecar: {import_path}")

    destination = destination_match.group(1)
    if destination.endswith(".bptc.ctex"):
        destination_base = destination[: -len(".bptc.ctex")]
    elif destination.endswith(".astc.ctex"):
        destination_base = destination[: -len(".astc.ctex")]
    elif destination.endswith(".ctex"):
        destination_base = destination[: -len(".ctex")]
    else:
        raise RuntimeError(f"Unexpected Godot texture destination: {destination}")

    source_res_path = "res://" + png_path.relative_to(REPO_ROOT / "godot").as_posix()
    bptc_path = f"{destination_base}.bptc.ctex"
    astc_path = f"{destination_base}.astc.ctex"
    rewritten = f'''[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid_match.group(1)}"
path.bptc="{bptc_path}"
path.astc="{astc_path}"
metadata={{
"imported_formats": ["s3tc_bptc", "etc2_astc"],
"vram_texture": true
}}

[deps]

source_file="{source_res_path}"
dest_files=["{bptc_path}", "{astc_path}"]

[params]

compress/mode=2
compress/high_quality=true
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
'''
    import_path.write_text(rewritten, encoding="utf-8", newline="\n")
    bptc_local_path = REPO_ROOT / "godot" / bptc_path.removeprefix("res://")
    astc_local_path = REPO_ROOT / "godot" / astc_path.removeprefix("res://")
    import_md5_path = Path(f"{REPO_ROOT / 'godot' / destination_base.removeprefix('res://')}.md5")
    imported_source_md5 = ""
    if import_md5_path.exists():
        imported_md5_match = re.search(
            r'^source_md5="([0-9a-f]+)"$',
            import_md5_path.read_text(encoding="utf-8-sig"),
            flags=re.MULTILINE,
        )
        if imported_md5_match is not None:
            imported_source_md5 = imported_md5_match.group(1)
    source_md5_matches = imported_source_md5 == md5(png_path)
    imported_pair_ready = (
        bptc_local_path.exists()
        and astc_local_path.exists()
        and source_md5_matches
    )
    return {
        "status": "vram_policy_ready" if imported_pair_ready else "vram_policy_authored_reimport_required",
        "import_path": import_path.relative_to(REPO_ROOT).as_posix(),
        "uid": uid_match.group(1),
        "bptc_path": bptc_path,
        "astc_path": astc_path,
        "source_md5_matches_import": source_md5_matches,
        "imported_pair_ready": imported_pair_ready,
    }


def alpha_bbox(alpha: np.ndarray) -> list[int]:
    ys, xs = np.where(alpha > 0)
    if xs.size == 0:
        return [0, 0, 0, 0]
    return [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]


def exact_ff00ff_pixels(rgba: np.ndarray) -> int:
    return int(
        np.count_nonzero(
            (rgba[..., 3] > 0)
            & (rgba[..., 0] == 255)
            & (rgba[..., 1] == 0)
            & (rgba[..., 2] == 255)
        )
    )


def exterior_connected_magenta_mask(rgba: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    rgb = rgba[..., :3].astype(np.int16)
    alpha = rgba[..., 3]
    minimum_rb = np.minimum(rgb[..., 0], rgb[..., 2])
    maximum_rb = np.maximum(rgb[..., 0], rgb[..., 2])
    near_magenta = (
        (alpha >= 16)
        & (minimum_rb >= 96)
        & (rgb[..., 1] <= 0.55 * minimum_rb)
        & (np.abs(rgb[..., 0] - rgb[..., 2]) <= 0.35 * np.maximum(maximum_rb, 1))
    )
    transparent_labels, _ = ndimage.label(alpha < 16, structure=np.ones((3, 3), dtype=np.uint8))
    edge_ids = np.unique(
        np.concatenate(
            (
                transparent_labels[0, :],
                transparent_labels[-1, :],
                transparent_labels[:, 0],
                transparent_labels[:, -1],
            )
        )
    )
    exterior = np.isin(transparent_labels, edge_ids[edge_ids != 0])
    boundary_band = (
        ndimage.binary_dilation(exterior, structure=np.ones((3, 3), dtype=bool), iterations=4)
        & (alpha >= 16)
    )
    magenta_labels, _ = ndimage.label(near_magenta, structure=np.ones((3, 3), dtype=np.uint8))
    touching_ids = np.unique(magenta_labels[boundary_band & near_magenta])
    touching_ids = touching_ids[touching_ids != 0]
    exterior_connected = np.isin(magenta_labels, touching_ids)
    return exterior_connected, boundary_band, near_magenta


def exterior_chroma_qa(rgba: np.ndarray) -> dict:
    exterior_connected, boundary_band, near_magenta = exterior_connected_magenta_mask(rgba)
    return {
        "gate_method": "alpha_lt_16_canvas_edge_flood_fill_then_4px_dilation_touching_near_magenta_8_connected_components",
        "boundary_4px_near_magenta_touch_pixels": int(np.count_nonzero(boundary_band & near_magenta)),
        "exterior_connected_magenta_pixels": int(np.count_nonzero(exterior_connected)),
        "gate_pass": int(np.count_nonzero(exterior_connected)) == 0,
    }


def base_qa(rgba: np.ndarray) -> dict:
    alpha = rgba[..., 3]
    bbox = alpha_bbox(alpha)
    corners = [int(alpha[0, 0]), int(alpha[0, -1]), int(alpha[-1, 0]), int(alpha[-1, -1])]
    return {
        "mode": "RGBA",
        "size": list(TARGET_SIZE),
        "corner_alpha": corners,
        "alpha_bbox_exclusive": bbox,
        "alpha_bbox_clear_of_canvas_edge": bool(
            bbox != [0, 0, 0, 0]
            and bbox[0] > 0
            and bbox[1] > 0
            and bbox[2] < TARGET_SIZE[0]
            and bbox[3] < TARGET_SIZE[1]
        ),
        "visible_pixels": int(np.count_nonzero(alpha)),
        "hidden_rgb_payload_pixels": int(np.count_nonzero((alpha == 0) & np.any(rgba[..., :3] != 0, axis=2))),
        "exact_ff00ff_pixels_diagnostic": exact_ff00ff_pixels(rgba),
        "exterior_chroma": exterior_chroma_qa(rgba),
    }


def mask_qa(rgba: np.ndarray, base_alpha: np.ndarray) -> dict:
    alpha = rgba[..., 3]
    visible = alpha > 0
    return {
        "mode": "RGBA",
        "size": list(TARGET_SIZE),
        "corner_alpha": [int(alpha[0, 0]), int(alpha[0, -1]), int(alpha[-1, 0]), int(alpha[-1, -1])],
        "alpha_bbox_exclusive": alpha_bbox(alpha),
        "visible_pixels": int(np.count_nonzero(visible)),
        "visible_nonwhite_rgb_pixels": int(np.count_nonzero(visible & np.any(rgba[..., :3] != 255, axis=2))),
        "hidden_rgb_payload_pixels": int(np.count_nonzero((~visible) & np.any(rgba[..., :3] != 0, axis=2))),
        "alpha_outside_resized_base_pixels": int(np.count_nonzero(visible & (base_alpha == 0))),
        "alpha_exceeding_resized_base_pixels": int(np.count_nonzero(alpha > base_alpha)),
    }


def prepare_building(building_type: str) -> tuple[Path, dict]:
    source_manifest_path = candidate_manifest_path(building_type)
    source_manifest = read_json(source_manifest_path)
    expected_asset_id = f"plaza_hwangyeok_{building_type}_3q_v1"
    if source_manifest.get("asset_id") != expected_asset_id:
        raise RuntimeError(f"Asset id drift in {source_manifest_path}")
    if source_manifest.get("source_size") != [1254, 1254]:
        raise RuntimeError(f"Source-size contract drift in {source_manifest_path}")

    source_layers: dict[str, tuple[Path, np.ndarray, dict]] = {}
    for layer_name in LAYER_OUTPUT_SUFFIXES:
        source_entry = source_manifest["layers"][layer_name]
        source_path = REPO_ROOT / source_entry["candidate_path"]
        source_layers[layer_name] = (
            source_path,
            load_approved_rgba(source_path, source_entry["sha256"]),
            source_entry,
        )

    resized_base, base_resize_cleanup = resize_base_premultiplied(source_layers["base"][1])
    expected_cleanup_coordinates = EXPECTED_RESIZE_CHROMA_CLEANUP_COORDINATES[building_type]
    base_resize_cleanup["expected_removed_pixel_count"] = len(expected_cleanup_coordinates)
    base_resize_cleanup["expected_removed_runtime_pixel_coordinates_xy"] = expected_cleanup_coordinates
    base_resize_cleanup["expected_cleanup_snapshot_matches"] = (
        base_resize_cleanup["removed_runtime_pixel_coordinates_xy"] == expected_cleanup_coordinates
    )
    resized_layers = {"base": resized_base}
    resized_base_alpha = resized_layers["base"][..., 3]
    resized_layers["sign_emissive"] = resize_white_mask(
        source_layers["sign_emissive"][1], resized_base_alpha
    )
    resized_layers["window_glow_mask"] = resize_white_mask(
        source_layers["window_glow_mask"][1], resized_base_alpha
    )

    runtime_manifest = dict(source_manifest)
    runtime_manifest["status"] = "r1_active_runtime"
    runtime_manifest["runtime_texture_size"] = list(TARGET_SIZE)
    runtime_manifest["runtime_usage"] = "production_active_hwangyeok_plaza_2d_retained_building_layers"
    runtime_manifest["runtime_import_policy"] = {
        "physical_downscale": True,
        "compress_mode": 2,
        "compress_high_quality": True,
        "metadata_vram_texture": True,
        "mipmaps_generate": True,
        "process_size_limit": 0,
    }
    runtime_manifest["runtime_prep_provenance"] = {
        "source_manifest_path": source_manifest_path.relative_to(REPO_ROOT).as_posix(),
        "source_manifest_sha256": sha256(source_manifest_path),
        "prep_script_path": Path(__file__).resolve().relative_to(REPO_ROOT).as_posix(),
        "prep_script_sha256": sha256(Path(__file__).resolve()),
        "algorithm": {
            "base": "premultiplied_srgb_rgba_lanczos_then_unpremultiply_zero_transparent_rgb_and_remove_only_exterior_connected_near_magenta_resize_ringing",
            "masks": "lanczos_alpha_then_clamp_to_resized_base_alpha_with_visible_rgb_white_and_hidden_rgb_black",
            "png": "Pillow_RGBA_compress_level_9_optimize_false",
        },
        "authoring_coordinates_remain_in_source_pixel_space": True,
        "source_retention_policy": SOURCE_RETENTION_POLICY,
    }
    runtime_manifest["runtime_material_edits"] = {
        "base_resize_exterior_chroma_cleanup": base_resize_cleanup,
    }

    runtime_layer_entries = {}
    layer_qa = {}
    for layer_name, suffix in LAYER_OUTPUT_SUFFIXES.items():
        output_name = f"{expected_asset_id}_{suffix}"
        output_path = OUTPUT_ROOT / output_name
        save_rgba(output_path, resized_layers[layer_name])
        source_path, _, source_entry = source_layers[layer_name]
        runtime_layer_entries[layer_name] = {
            "res_path": f"{OUTPUT_RES_ROOT}/{output_name}",
            "sha256": sha256(output_path),
            "source_candidate_path": source_path.relative_to(REPO_ROOT).as_posix(),
            "source_sha256": source_entry["sha256"],
        }
        if layer_name == "base":
            layer_qa[layer_name] = base_qa(resized_layers[layer_name])
            layer_qa[layer_name]["resize_exterior_chroma_cleanup"] = base_resize_cleanup
        else:
            layer_qa[layer_name] = mask_qa(resized_layers[layer_name], resized_base_alpha)

    runtime_manifest["layers"] = runtime_layer_entries
    runtime_manifest["runtime_qa"] = {
        "all_corner_alpha_zero": all(
            max(entry["corner_alpha"]) == 0 for entry in layer_qa.values()
        ),
        "base_alpha_bbox_clear_of_canvas_edge": layer_qa["base"]["alpha_bbox_clear_of_canvas_edge"],
        "base_hidden_rgb_payload_pixels": layer_qa["base"]["hidden_rgb_payload_pixels"],
        "all_masks_neutral_white": all(
            layer_qa[name]["visible_nonwhite_rgb_pixels"] == 0
            for name in ("sign_emissive", "window_glow_mask")
        ),
        "all_masks_inside_resized_base": all(
            layer_qa[name]["alpha_outside_resized_base_pixels"] == 0
            and layer_qa[name]["alpha_exceeding_resized_base_pixels"] == 0
            for name in ("sign_emissive", "window_glow_mask")
        ),
        "layers": layer_qa,
    }

    output_manifest_path = OUTPUT_ROOT / f"{expected_asset_id}_manifest.json"
    write_json(output_manifest_path, runtime_manifest)
    return output_manifest_path, runtime_manifest


def main() -> int:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    results = {}
    output_manifests = []
    for building_type in BUILDING_TYPES:
        manifest_path, manifest = prepare_building(building_type)
        output_manifests.append(manifest_path)
        results[building_type] = {
            "manifest": manifest_path.relative_to(REPO_ROOT).as_posix(),
            "manifest_sha256": sha256(manifest_path),
            "runtime_qa": manifest["runtime_qa"],
        }

    failures = []
    for building_type, entry in results.items():
        qa = entry["runtime_qa"]
        if not qa["all_corner_alpha_zero"]:
            failures.append(f"{building_type}: nontransparent corner")
        if not qa["base_alpha_bbox_clear_of_canvas_edge"]:
            failures.append(f"{building_type}: base alpha touches runtime canvas edge")
        if qa["base_hidden_rgb_payload_pixels"] != 0:
            failures.append(f"{building_type}: hidden base RGB payload")
        if not qa["layers"]["base"]["exterior_chroma"]["gate_pass"]:
            failures.append(f"{building_type}: exterior-connected magenta fringe")
        if not qa["layers"]["base"]["resize_exterior_chroma_cleanup"]["expected_cleanup_snapshot_matches"]:
            failures.append(f"{building_type}: resize chroma cleanup count/coordinate drift")
        if not qa["all_masks_neutral_white"]:
            failures.append(f"{building_type}: non-neutral mask RGB")
        if not qa["all_masks_inside_resized_base"]:
            failures.append(f"{building_type}: mask escapes resized base alpha")

    png_paths = sorted(OUTPUT_ROOT.glob("*.png"))
    import_sidecars = {
        path.name: enforce_vram_import_policy(path)
        for path in png_paths
    }
    for png_name, import_entry in import_sidecars.items():
        if import_entry["status"] == "pending_godot_source_scan":
            failures.append(f"{png_name}: Godot import sidecar pending source scan")
        elif not import_entry.get("imported_pair_ready", False):
            failures.append(f"{png_name}: VRAM import pair missing or stale; Godot reimport required")
    report = {
        "status": "PASS" if not failures else "FAIL",
        "failures": failures,
        "pipeline": "hwangyeok_plaza_r1_active_runtime_asset_prep",
        "source_retention_policy": SOURCE_RETENTION_POLICY,
        "runtime_texture_size": list(TARGET_SIZE),
        "building_count": len(results),
        "layer_count": len(png_paths),
        "runtime_rgba_uncompressed_bytes": len(png_paths) * TARGET_SIZE[0] * TARGET_SIZE[1] * 4,
        "runtime_png_disk_bytes": sum(path.stat().st_size for path in png_paths),
        "import_sidecars_vram_policy_written": sum(
            entry["status"] in ("vram_policy_ready", "vram_policy_authored_reimport_required")
            for entry in import_sidecars.values()
        ),
        "imported_vram_pairs_ready": sum(
            entry.get("imported_pair_ready", False)
            for entry in import_sidecars.values()
        ),
        "import_sidecars_pending_source_scan": sum(
            entry["status"] == "pending_godot_source_scan"
            for entry in import_sidecars.values()
        ),
        "import_policy": import_sidecars,
        "manifests": [path.relative_to(REPO_ROOT).as_posix() for path in output_manifests],
        "runtime_material_edits": {
            building_type: entry["runtime_qa"]["layers"]["base"]["resize_exterior_chroma_cleanup"]
            for building_type, entry in results.items()
        },
        "buildings": results,
    }
    report_path = OUTPUT_ROOT / "plaza_hwangyeok_3q_v1_runtime_asset_qa.json"
    write_json(report_path, report)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
