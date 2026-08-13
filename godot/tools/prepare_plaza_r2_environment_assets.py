"""Prepare the self-contained R2 plaza environment art candidate.

The approved source masters live under the gitignored ``tmp/imagegen`` tree.
This helper verifies their pinned hashes, extracts the six generated road
pieces and two plot pads deterministically, and emits self-contained runtime
textures plus a fail-closed provenance/QA manifest.  Production routing
remains an R3 concern.
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
SOURCE_ROOT = REPO_ROOT / "tmp" / "imagegen"
ENVIRONMENT_SOURCE_ROOT = SOURCE_ROOT / "plaza_r2_environment_v1"
DECOR_SOURCE_ROOT = SOURCE_ROOT / "plaza_r2_decor"
OUTPUT_ROOT = REPO_ROOT / "godot" / "assets" / "ui" / "plaza" / "environment" / "hwangyeok_r2"
OUTPUT_RES_ROOT = "res://assets/ui/plaza/environment/hwangyeok_r2"

TARGET_SIZE = (512, 512)
CONTENT_MARGIN = 16
ROAD_COMPONENT_MIN_PIXELS = 10_000
ROAD_COMPONENT_ALPHA_THRESHOLD = 1
PLOT_PAD_COMPONENT_MIN_PIXELS = 40_000
PLOT_PAD_LUMINANCE_MIN = 75.0
PLOT_PAD_LUMINANCE_MAX = 90.0

GROUND_SOURCE = {
    "path": SOURCE_ROOT / "plaza_hwangyeok_ground_30deg_ortho_candidate_v3_rectified_clean.png",
    "sha256": "7d7d3f99055c3406c68fe0960dc5c43598053fce23ec28f32cea844171a7c900",
    "output": "plaza_hwangyeok_map_ground_v1.png",
}
ROAD_ATLAS_SOURCE = {
    "path": ENVIRONMENT_SOURCE_ROOT / "plaza_hwangyeok_road_pieces_v2_rectified_alpha.png",
    "sha256": "ae2f9b97cf0c1cf7d50000ff240309244e0c028eb49893bb8d4e3720e25d30f8",
}
ROAD_CHROMAKEY_SOURCE = {
    "path": ENVIRONMENT_SOURCE_ROOT / "plaza_hwangyeok_road_pieces_v2_rectified_chromakey.png",
    "sha256": "853714031ad46c4eaf7a58eba10dfe542c1051ea4b1b0ed77fb2a66476f417ff",
}
ROAD_GEOMETRY_SOURCE = {
    "path": ENVIRONMENT_SOURCE_ROOT / "plaza_hwangyeok_road_pieces_v2_rectified_geometry_guide.png",
    "sha256": "b4b48b2dfbb19e514a3bb28bc4e55b6ed6c8fe64f3679bd428746b7335657e44",
}
PLOT_PAD_ATLAS_SOURCE = {
    "path": ENVIRONMENT_SOURCE_ROOT / "plaza_hwangyeok_plot_pads_v2_alpha.png",
    "sha256": "5ede38b97ed7fb042b00b4f9dc0a7b0702bad31ca554b4f672dc6a6127bb1363",
}
PLOT_PAD_CHROMAKEY_SOURCE = {
    "path": ENVIRONMENT_SOURCE_ROOT / "plaza_hwangyeok_plot_pads_v2_chromakey.png",
    "sha256": "e1a7a2dd81c9999dd4efedcbd07e1837c8af4002ad8f826be2d5d8657c82ccf9",
}
PLOT_PAD_GEOMETRY_SOURCE = {
    "path": ENVIRONMENT_SOURCE_ROOT / "plaza_hwangyeok_plot_pads_v1_geometry_guide.png",
    "sha256": "a47fe0259ecfbb1a79e03940ba709006bdc1a6c264c7d7b2d9e7e8a1e267bae0",
}

# Connected components are sorted by row and then x.  This order is part of
# the approved six-piece source contract and prevents silent semantic swaps.
ROAD_PIECES = (
    ("straight_positive", "plaza_hwangyeok_road_straight_positive_v1.png"),
    ("straight_negative", "plaza_hwangyeok_road_straight_negative_v1.png"),
    ("three_way", "plaza_hwangyeok_road_three_way_v1.png"),
    ("plot_spur", "plaza_hwangyeok_road_plot_spur_v1.png"),
    ("terminus", "plaza_hwangyeok_road_terminus_v1.png"),
    ("entrance_forecourt", "plaza_hwangyeok_road_entrance_forecourt_v1.png"),
)

# Components are ordered left-to-right in the approved source atlas.  Both use
# one shared runtime scale so the large/small footprint distinction survives
# extraction instead of being normalized away by per-component fitting.
PLOT_PAD_PIECES = (
    ("plot_pad_large", "plaza_hwangyeok_plot_pad_large_v1.png"),
    ("plot_pad_small", "plaza_hwangyeok_plot_pad_small_v1.png"),
)

DECOR_SOURCES = (
    (
        "wayfinder",
        "plaza_hwangyeok_decor_wayfinder_lantern_v1_alpha.png",
        "ffaa85a378d4fd17c32f61bd4828cb0cb1c53ad9fa2657f87f37c756d06b2576",
    ),
    (
        "market",
        "plaza_hwangyeok_decor_market_stall_double_v1_alpha.png",
        "8f6b603911f574063fb7c3ca831a3927ecdbafa0161896ef75b3f52586887c4d",
    ),
    (
        "pond",
        "plaza_hwangyeok_decor_rock_pond_v1_alpha.png",
        "ecfe3bed8781bcccd306d4e4a9e6638dd45bf4e62f9aee8725aa2fc1f4c9aca8",
    ),
    (
        "pine",
        "plaza_hwangyeok_decor_pine_lantern_waymarker_v1_alpha.png",
        "1f187262001895f09205f60f7a5258c69275ac26651f1e09767e5d9131fe14c5",
    ),
    (
        "supply",
        "plaza_hwangyeok_decor_supply_rest_v1_alpha.png",
        "6896b5afb0d29a0fabba4f8959f42a2efcf5960b31ddb178666f69f238111cad",
    ),
)

SOURCE_RETENTION_POLICY = {
    "source_root": "tmp/imagegen",
    "workspace_masters_preserved": True,
    "gitignored": True,
    "clean_checkout_rebuild_supported": False,
    "runtime_outputs_self_contained": True,
    "durable_archive_requires_separate_lfs_promotion": True,
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path: Path, value: dict) -> None:
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def require_source(source: dict) -> Image.Image:
    path = source["path"]
    if not path.exists():
        raise RuntimeError(f"Required approved source is missing: {path}")
    actual_sha = sha256(path)
    if actual_sha != source["sha256"]:
        raise RuntimeError(f"Approved source hash drift: {path} ({actual_sha} != {source['sha256']})")
    return Image.open(path).convert("RGBA")


def premultiplied_resize(rgba: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    source = rgba.astype(np.float32) / 255.0
    source_alpha = source[..., 3]
    resized_alpha = np.asarray(
        Image.fromarray(source_alpha).resize(size, resample=Image.Resampling.LANCZOS),
        dtype=np.float32,
    )
    resized_premultiplied = np.stack(
        [
            np.asarray(
                Image.fromarray(source[..., channel] * source_alpha).resize(
                    size,
                    resample=Image.Resampling.LANCZOS,
                ),
                dtype=np.float32,
            )
            for channel in range(3)
        ],
        axis=2,
    )
    resized_rgb = np.zeros_like(resized_premultiplied)
    visible = resized_alpha > (0.5 / 255.0)
    resized_rgb[visible] = resized_premultiplied[visible] / resized_alpha[visible, None]

    result = np.zeros((size[1], size[0], 4), dtype=np.uint8)
    result[..., :3] = np.rint(np.clip(resized_rgb, 0.0, 1.0) * 255.0).astype(np.uint8)
    result[..., 3] = np.rint(np.clip(resized_alpha, 0.0, 1.0) * 255.0).astype(np.uint8)
    result[result[..., 3] == 0, :3] = 0
    return result


def fit_transparent_source(
    image: Image.Image,
    *,
    bottom_align: bool,
    scale_override: float | None = None,
) -> tuple[np.ndarray, dict]:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    alpha = rgba[..., 3]
    ys, xs = np.where(alpha > 0)
    if xs.size == 0:
        raise RuntimeError("Approved source is fully transparent")
    bbox = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    crop = rgba[bbox[1] : bbox[3], bbox[0] : bbox[2]]
    available = TARGET_SIZE[0] - (CONTENT_MARGIN * 2)
    scale = min(available / crop.shape[1], available / crop.shape[0]) if scale_override is None else scale_override
    if crop.shape[1] * scale > available + 0.5 or crop.shape[0] * scale > available + 0.5:
        raise RuntimeError("Shared transparent-source scale exceeds the runtime canvas")
    scaled_size = (
        max(1, int(round(crop.shape[1] * scale))),
        max(1, int(round(crop.shape[0] * scale))),
    )
    resized = premultiplied_resize(crop, scaled_size)
    canvas = np.zeros((TARGET_SIZE[1], TARGET_SIZE[0], 4), dtype=np.uint8)
    x = (TARGET_SIZE[0] - scaled_size[0]) // 2
    y = TARGET_SIZE[1] - CONTENT_MARGIN - scaled_size[1] if bottom_align else (TARGET_SIZE[1] - scaled_size[1]) // 2
    canvas[y : y + scaled_size[1], x : x + scaled_size[0]] = resized
    canvas[[0, -1], :, :] = 0
    canvas[:, [0, -1], :] = 0
    canvas[canvas[..., 3] == 0, :3] = 0
    return canvas, {
        "source_bbox_xyxy": list(bbox),
        "source_crop_size": [int(crop.shape[1]), int(crop.shape[0])],
        "runtime_content_rect": [x, y, scaled_size[0], scaled_size[1]],
        "runtime_scale": scale,
        "runtime_anchor": [TARGET_SIZE[0] // 2, TARGET_SIZE[1] - CONTENT_MARGIN if bottom_align else TARGET_SIZE[1] // 2],
        "anchor_kind": "bottom_center" if bottom_align else "center",
    }


def extract_road_components(image: Image.Image) -> list[tuple[Image.Image, dict]]:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    labels, count = ndimage.label(rgba[..., 3] >= ROAD_COMPONENT_ALPHA_THRESHOLD)
    components: list[dict] = []
    for label_id in range(1, count + 1):
        ys, xs = np.where(labels == label_id)
        if xs.size < ROAD_COMPONENT_MIN_PIXELS:
            continue
        components.append(
            {
                "label_id": label_id,
                "pixels": int(xs.size),
                "bbox": (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1),
                "center": (float(xs.mean()), float(ys.mean())),
            }
        )
    if len(components) != len(ROAD_PIECES):
        raise RuntimeError(f"Road atlas component count drift: {len(components)} != {len(ROAD_PIECES)}")

    top = sorted((item for item in components if item["center"][1] < image.height / 2), key=lambda item: item["center"][0])
    bottom = sorted((item for item in components if item["center"][1] >= image.height / 2), key=lambda item: item["center"][0])
    if len(top) != 3 or len(bottom) != 3:
        raise RuntimeError(f"Road atlas row contract drift: top={len(top)} bottom={len(bottom)}")

    result: list[tuple[Image.Image, dict]] = []
    for item in top + bottom:
        x0, y0, x1, y1 = item["bbox"]
        # Include the antialiased fringe around the thresholded component.
        padding = 4
        crop_box = (
            max(0, x0 - padding),
            max(0, y0 - padding),
            min(image.width, x1 + padding),
            min(image.height, y1 + padding),
        )
        component_rgba = rgba[crop_box[1] : crop_box[3], crop_box[0] : crop_box[2]].copy()
        component_labels = labels[crop_box[1] : crop_box[3], crop_box[0] : crop_box[2]]
        component_rgba[component_labels != item["label_id"]] = 0
        result.append(
            (
                Image.fromarray(component_rgba),
                {
                    "atlas_component_pixels": item["pixels"],
                    "atlas_component_bbox_xyxy": list(item["bbox"]),
                    "atlas_crop_bbox_xyxy": list(crop_box),
                    "atlas_component_center": [item["center"][0], item["center"][1]],
                },
            )
        )
    return result


def extract_plot_pad_components(image: Image.Image) -> list[tuple[Image.Image, dict]]:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    labels, count = ndimage.label(rgba[..., 3] >= ROAD_COMPONENT_ALPHA_THRESHOLD)
    components: list[dict] = []
    for label_id in range(1, count + 1):
        ys, xs = np.where(labels == label_id)
        if xs.size < PLOT_PAD_COMPONENT_MIN_PIXELS:
            continue
        components.append(
            {
                "label_id": label_id,
                "pixels": int(xs.size),
                "bbox": (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1),
                "center": (float(xs.mean()), float(ys.mean())),
            }
        )
    components.sort(key=lambda item: item["center"][0])
    if len(components) != len(PLOT_PAD_PIECES):
        raise RuntimeError(f"Plot-pad atlas component count drift: {len(components)} != {len(PLOT_PAD_PIECES)}")

    result: list[tuple[Image.Image, dict]] = []
    for item in components:
        x0, y0, x1, y1 = item["bbox"]
        padding = 4
        crop_box = (
            max(0, x0 - padding),
            max(0, y0 - padding),
            min(image.width, x1 + padding),
            min(image.height, y1 + padding),
        )
        component_rgba = rgba[crop_box[1] : crop_box[3], crop_box[0] : crop_box[2]].copy()
        component_labels = labels[crop_box[1] : crop_box[3], crop_box[0] : crop_box[2]]
        component_rgba[component_labels != item["label_id"]] = 0
        result.append(
            (
                Image.fromarray(component_rgba),
                {
                    "atlas_component_pixels": item["pixels"],
                    "atlas_component_bbox_xyxy": list(item["bbox"]),
                    "atlas_crop_bbox_xyxy": list(crop_box),
                    "atlas_component_center": [item["center"][0], item["center"][1]],
                },
            )
        )
    return result


def compare_road_geometry(road_image: Image.Image, guide_image: Image.Image) -> list[dict]:
    road_rgba = np.asarray(road_image.convert("RGBA"), dtype=np.uint8)
    guide_rgb = np.asarray(guide_image.convert("RGB"), dtype=np.uint8)
    road_labels, road_count = ndimage.label(road_rgba[..., 3] >= ROAD_COMPONENT_ALPHA_THRESHOLD)
    guide_mask = ~(
        (guide_rgb[..., 0] >= 240)
        & (guide_rgb[..., 1] <= 20)
        & (guide_rgb[..., 2] >= 240)
    )
    guide_labels, guide_count = ndimage.label(guide_mask)

    def ordered_masks(labels: np.ndarray, count: int) -> list[np.ndarray]:
        records: list[tuple[bool, float, np.ndarray]] = []
        for label_id in range(1, count + 1):
            mask = labels == label_id
            ys, xs = np.where(mask)
            if xs.size < ROAD_COMPONENT_MIN_PIXELS:
                continue
            records.append((float(ys.mean()) >= road_image.height / 2, float(xs.mean()), mask))
        records.sort(key=lambda record: (record[0], record[1]))
        return [record[2] for record in records]

    road_masks = ordered_masks(road_labels, road_count)
    guide_masks = ordered_masks(guide_labels, guide_count)
    if len(road_masks) != len(ROAD_PIECES) or len(guide_masks) != len(ROAD_PIECES):
        raise RuntimeError(
            f"Road geometry comparison component drift: art={len(road_masks)} guide={len(guide_masks)}"
        )

    metrics: list[dict] = []
    for (asset_id, _), road_mask, guide_component in zip(ROAD_PIECES, road_masks, guide_masks, strict=True):
        intersection = int(np.count_nonzero(road_mask & guide_component))
        union = int(np.count_nonzero(road_mask | guide_component))
        road_pixels = int(np.count_nonzero(road_mask))
        guide_pixels = int(np.count_nonzero(guide_component))
        iou = intersection / max(1, union)
        guide_coverage = intersection / max(1, guide_pixels)
        art_spill_ratio = (road_pixels - intersection) / max(1, road_pixels)
        if iou < 0.94 or guide_coverage < 0.985 or art_spill_ratio > 0.05:
            raise RuntimeError(
                f"Road geometry drift for {asset_id}: iou={iou:.6f} coverage={guide_coverage:.6f} spill={art_spill_ratio:.6f}"
            )
        metrics.append(
            {
                "asset_id": asset_id,
                "intersection_pixels": intersection,
                "union_pixels": union,
                "guide_pixels": guide_pixels,
                "art_pixels": road_pixels,
                "iou": iou,
                "guide_coverage": guide_coverage,
                "art_spill_ratio": art_spill_ratio,
            }
        )
    return metrics


def compare_plot_pad_geometry_and_luminance(pad_image: Image.Image, guide_image: Image.Image) -> list[dict]:
    pad_rgba = np.asarray(pad_image.convert("RGBA"), dtype=np.uint8)
    guide_rgb = np.asarray(guide_image.convert("RGB"), dtype=np.uint8)
    pad_labels, pad_count = ndimage.label(pad_rgba[..., 3] >= ROAD_COMPONENT_ALPHA_THRESHOLD)
    guide_mask = ~(
        (guide_rgb[..., 0] >= 240)
        & (guide_rgb[..., 1] <= 20)
        & (guide_rgb[..., 2] >= 240)
    )
    guide_labels, guide_count = ndimage.label(guide_mask)

    def ordered_masks(labels: np.ndarray, count: int, minimum_pixels: int) -> list[np.ndarray]:
        records: list[tuple[float, np.ndarray]] = []
        for label_id in range(1, count + 1):
            mask = labels == label_id
            _, xs = np.where(mask)
            if xs.size < minimum_pixels:
                continue
            records.append((float(xs.mean()), mask))
        records.sort(key=lambda record: record[0])
        return [record[1] for record in records]

    pad_masks = ordered_masks(pad_labels, pad_count, PLOT_PAD_COMPONENT_MIN_PIXELS)
    guide_masks = ordered_masks(guide_labels, guide_count, PLOT_PAD_COMPONENT_MIN_PIXELS)
    if len(pad_masks) != len(PLOT_PAD_PIECES) or len(guide_masks) != len(PLOT_PAD_PIECES):
        raise RuntimeError(
            f"Plot-pad geometry comparison component drift: art={len(pad_masks)} guide={len(guide_masks)}"
        )

    rgb = pad_rgba[..., :3].astype(np.float32)
    luminance = (0.2126 * rgb[..., 0]) + (0.7152 * rgb[..., 1]) + (0.0722 * rgb[..., 2])
    metrics: list[dict] = []
    for (asset_id, _), pad_mask, guide_component in zip(PLOT_PAD_PIECES, pad_masks, guide_masks, strict=True):
        intersection = int(np.count_nonzero(pad_mask & guide_component))
        union = int(np.count_nonzero(pad_mask | guide_component))
        pad_pixels = int(np.count_nonzero(pad_mask))
        guide_pixels = int(np.count_nonzero(guide_component))
        iou = intersection / max(1, union)
        guide_coverage = intersection / max(1, guide_pixels)
        art_spill_ratio = (pad_pixels - intersection) / max(1, pad_pixels)
        opaque_component = pad_mask & (pad_rgba[..., 3] >= 128)
        mean_luminance = float(np.mean(luminance[opaque_component]))
        if iou < 0.96 or guide_coverage < 0.98 or art_spill_ratio > 0.02:
            raise RuntimeError(
                f"Plot-pad geometry drift for {asset_id}: iou={iou:.6f} coverage={guide_coverage:.6f} spill={art_spill_ratio:.6f}"
            )
        if not PLOT_PAD_LUMINANCE_MIN <= mean_luminance <= PLOT_PAD_LUMINANCE_MAX:
            raise RuntimeError(f"Plot-pad luminance drift for {asset_id}: {mean_luminance:.6f}")
        metrics.append(
            {
                "asset_id": asset_id,
                "intersection_pixels": intersection,
                "union_pixels": union,
                "guide_pixels": guide_pixels,
                "art_pixels": pad_pixels,
                "iou": iou,
                "guide_coverage": guide_coverage,
                "art_spill_ratio": art_spill_ratio,
                "mean_luminance_8bit": mean_luminance,
            }
        )
    return metrics


def save_rgba(path: Path, rgba: np.ndarray) -> None:
    Image.fromarray(rgba).save(path, format="PNG", compress_level=9, optimize=False)


def image_qa(path: Path, *, expect_opaque: bool) -> dict:
    rgba = np.asarray(Image.open(path).convert("RGBA"), dtype=np.uint8)
    alpha = rgba[..., 3]
    visible = alpha > 0
    hidden_rgb = np.any(rgba[..., :3] != 0, axis=2) & ~visible
    near_magenta = (
        (rgba[..., 0].astype(np.int16) - rgba[..., 2].astype(np.int16)).__abs__() <= 20
    ) & (rgba[..., 0] >= 220) & (rgba[..., 1] <= 45) & visible
    qa = {
        "size": [int(rgba.shape[1]), int(rgba.shape[0])],
        "sha256": sha256(path),
        "visible_pixels": int(np.count_nonzero(visible)),
        "opaque_pixels": int(np.count_nonzero(alpha == 255)),
        "partial_alpha_pixels": int(np.count_nonzero((alpha > 0) & (alpha < 255))),
        "hidden_rgb_pixels": int(np.count_nonzero(hidden_rgb)),
        "visible_near_magenta_pixels": int(np.count_nonzero(near_magenta)),
        "corner_alpha": [
            int(alpha[0, 0]),
            int(alpha[0, -1]),
            int(alpha[-1, 0]),
            int(alpha[-1, -1]),
        ],
    }
    if qa["hidden_rgb_pixels"] != 0:
        raise RuntimeError(f"Hidden RGB outside alpha: {path}")
    if qa["visible_near_magenta_pixels"] != 0:
        raise RuntimeError(f"Visible chroma spill in runtime asset: {path}")
    if expect_opaque:
        if qa["opaque_pixels"] != rgba.shape[0] * rgba.shape[1]:
            raise RuntimeError(f"Ground source must remain fully opaque: {path}")
    else:
        if qa["visible_pixels"] < 1_000:
            raise RuntimeError(f"Runtime cutout is unexpectedly empty: {path}")
        if any(qa["corner_alpha"]):
            raise RuntimeError(f"Runtime cutout touches a canvas corner: {path}")
    return qa


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
    for suffix in (".bptc.ctex", ".astc.ctex", ".ctex"):
        if destination.endswith(suffix):
            destination_base = destination[: -len(suffix)]
            break
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
    if current != rewritten:
        import_path.write_text(rewritten, encoding="utf-8", newline="\n")

    destination_files = [REPO_ROOT / "godot" / bptc_path.removeprefix("res://"), REPO_ROOT / "godot" / astc_path.removeprefix("res://")]
    return {
        "status": "ready" if all(path.exists() for path in destination_files) else "pending_vram_reimport",
        "import_path": import_path.relative_to(REPO_ROOT).as_posix(),
        "uid": uid_match.group(1),
        "bptc_path": bptc_path,
        "astc_path": astc_path,
        "destination_files_exist": [path.exists() for path in destination_files],
        "vram_texture": True,
        "compress_mode": 2,
        "high_quality": True,
        "mipmaps": True,
    }


def main() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    ground_image = require_source(GROUND_SOURCE)
    road_image = require_source(ROAD_ATLAS_SOURCE)
    require_source(ROAD_CHROMAKEY_SOURCE)
    road_geometry_image = require_source(ROAD_GEOMETRY_SOURCE)
    plot_pad_image = require_source(PLOT_PAD_ATLAS_SOURCE)
    require_source(PLOT_PAD_CHROMAKEY_SOURCE)
    plot_pad_geometry_image = require_source(PLOT_PAD_GEOMETRY_SOURCE)

    outputs: list[dict] = []

    ground_output = OUTPUT_ROOT / GROUND_SOURCE["output"]
    ground_image.save(ground_output, format="PNG", compress_level=9, optimize=False)
    outputs.append(
        {
            "kind": "ground",
            "asset_id": "map_ground",
            "res_path": f"{OUTPUT_RES_ROOT}/{ground_output.name}",
            "source_path": GROUND_SOURCE["path"].relative_to(REPO_ROOT).as_posix(),
            "source_sha256": GROUND_SOURCE["sha256"],
            "projection": {
                "kind": "orthographic_oblique",
                "elevation_degrees": 30,
                "azimuth_degrees": 45,
                "basis_slopes": [0.5, -0.5],
                "world_size": [2400.0, 1500.0],
            },
            "qa": image_qa(ground_output, expect_opaque=True),
            "import": enforce_vram_import_policy(ground_output),
        }
    )

    road_components = extract_road_components(road_image)
    road_geometry_metrics = compare_road_geometry(road_image, road_geometry_image)
    for (asset_id, output_name), (component_image, component_qa) in zip(ROAD_PIECES, road_components, strict=True):
        runtime_rgba, placement = fit_transparent_source(component_image, bottom_align=False)
        output_path = OUTPUT_ROOT / output_name
        save_rgba(output_path, runtime_rgba)
        outputs.append(
            {
                "kind": "road_piece",
                "asset_id": asset_id,
                "res_path": f"{OUTPUT_RES_ROOT}/{output_name}",
                "source_path": ROAD_ATLAS_SOURCE["path"].relative_to(REPO_ROOT).as_posix(),
                "source_sha256": ROAD_ATLAS_SOURCE["sha256"],
                "component": component_qa,
                "placement": placement,
                "qa": image_qa(output_path, expect_opaque=False),
                "import": enforce_vram_import_policy(output_path),
            }
        )

    plot_pad_components = extract_plot_pad_components(plot_pad_image)
    plot_pad_geometry_metrics = compare_plot_pad_geometry_and_luminance(plot_pad_image, plot_pad_geometry_image)
    largest_pad_crop = max(
        max(component_image.width, component_image.height)
        for component_image, _ in plot_pad_components
    )
    shared_plot_pad_scale = (TARGET_SIZE[0] - (CONTENT_MARGIN * 2)) / largest_pad_crop
    for (asset_id, output_name), (component_image, component_qa) in zip(
        PLOT_PAD_PIECES,
        plot_pad_components,
        strict=True,
    ):
        runtime_rgba, placement = fit_transparent_source(
            component_image,
            bottom_align=False,
            scale_override=shared_plot_pad_scale,
        )
        output_path = OUTPUT_ROOT / output_name
        save_rgba(output_path, runtime_rgba)
        outputs.append(
            {
                "kind": "plot_pad",
                "asset_id": asset_id,
                "res_path": f"{OUTPUT_RES_ROOT}/{output_name}",
                "source_path": PLOT_PAD_ATLAS_SOURCE["path"].relative_to(REPO_ROOT).as_posix(),
                "source_sha256": PLOT_PAD_ATLAS_SOURCE["sha256"],
                "component": component_qa,
                "placement": placement,
                "qa": image_qa(output_path, expect_opaque=False),
                "import": enforce_vram_import_policy(output_path),
            }
        )

    for asset_id, source_name, expected_sha in DECOR_SOURCES:
        source_path = DECOR_SOURCE_ROOT / source_name
        source_image = require_source({"path": source_path, "sha256": expected_sha})
        runtime_rgba, placement = fit_transparent_source(source_image, bottom_align=True)
        output_name = f"plaza_hwangyeok_decor_{asset_id}_v1.png"
        output_path = OUTPUT_ROOT / output_name
        save_rgba(output_path, runtime_rgba)
        outputs.append(
            {
                "kind": "decor_cluster",
                "asset_id": asset_id,
                "res_path": f"{OUTPUT_RES_ROOT}/{output_name}",
                "source_path": source_path.relative_to(REPO_ROOT).as_posix(),
                "source_sha256": expected_sha,
                "placement": placement,
                "qa": image_qa(output_path, expect_opaque=False),
                "import": enforce_vram_import_policy(output_path),
            }
        )

    output_pngs = sorted(OUTPUT_ROOT.glob("*.png"))
    aggregate = hashlib.sha256()
    for path in output_pngs:
        aggregate.update(path.name.encode("utf-8"))
        aggregate.update(b"\0")
        aggregate.update(bytes.fromhex(sha256(path)))

    import_statuses = [item["import"]["status"] for item in outputs]
    qa_manifest = {
        "status": "pass",
        "failure_count": 0,
        "pipeline": "hwangyeok_plaza_r2_environment_art_candidate_prep",
        "candidate_only": True,
        "production_connected": False,
        "world_size": [2400.0, 1500.0],
        "asset_counts": {"ground": 1, "road_piece": 6, "plot_pad": 2, "decor_cluster": 5, "total": len(outputs)},
        "road_component_count": len(road_components),
        "road_geometry_metrics": road_geometry_metrics,
        "road_geometry_contract": {
            "projection": "orthographic_oblique",
            "elevation_degrees": 30,
            "azimuth_degrees": 45,
            "basis_slopes": [0.5, -0.5],
            "minimum_component_iou": 0.94,
            "minimum_guide_coverage": 0.985,
            "maximum_art_spill_ratio": 0.05,
        },
        "plot_pad_component_count": len(plot_pad_components),
        "plot_pad_geometry_metrics": plot_pad_geometry_metrics,
        "plot_pad_geometry_contract": {
            "projection": "orthographic_oblique",
            "elevation_degrees": 30,
            "azimuth_degrees": 45,
            "basis_slopes": [0.5, -0.5],
            "minimum_component_iou": 0.96,
            "minimum_guide_coverage": 0.98,
            "maximum_art_spill_ratio": 0.02,
            "minimum_mean_luminance_8bit": PLOT_PAD_LUMINANCE_MIN,
            "maximum_mean_luminance_8bit": PLOT_PAD_LUMINANCE_MAX,
            "shared_runtime_scale": shared_plot_pad_scale,
        },
        "runtime_png_count": len(output_pngs),
        "aggregate_runtime_sha256": aggregate.hexdigest(),
        "import_status_counts": {status: import_statuses.count(status) for status in sorted(set(import_statuses))},
        "source_retention_policy": SOURCE_RETENTION_POLICY,
    }
    manifest = {
        "schema_version": 1,
        "status": "r2_candidate_runtime_art_ready",
        "runtime_usage": "candidate_only_hwangyeok_plaza_2d_ground_road_plot_pad_and_decor",
        "candidate_only": True,
        "production_connected": False,
        "source_retention_policy": SOURCE_RETENTION_POLICY,
        "approved_source_hashes": {
            "ground": GROUND_SOURCE["sha256"],
            "road_chromakey": ROAD_CHROMAKEY_SOURCE["sha256"],
            "road_alpha": ROAD_ATLAS_SOURCE["sha256"],
            "road_geometry_guide": ROAD_GEOMETRY_SOURCE["sha256"],
            "plot_pad_chromakey": PLOT_PAD_CHROMAKEY_SOURCE["sha256"],
            "plot_pad_alpha": PLOT_PAD_ATLAS_SOURCE["sha256"],
            "plot_pad_geometry_guide": PLOT_PAD_GEOMETRY_SOURCE["sha256"],
            "decor": {asset_id: source_sha for asset_id, _, source_sha in DECOR_SOURCES},
        },
        "assets": outputs,
        "qa": qa_manifest,
    }
    write_json(OUTPUT_ROOT / "plaza_hwangyeok_r2_environment_manifest.json", manifest)
    write_json(OUTPUT_ROOT / "plaza_hwangyeok_r2_environment_qa.json", qa_manifest)
    print(json.dumps(qa_manifest, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
