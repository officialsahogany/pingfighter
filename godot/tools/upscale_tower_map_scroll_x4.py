#!/usr/bin/env python3
"""Build identity-preserving x4 Tower map scroll candidates with Real-ESRGAN."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt


# The general x4plus model is intentionally less line-inventive than the anime
# variants. The three-model art gate showed that it preserves hanji grain and
# low-contrast ink washes without turning them into hard synthetic contours.
MODEL_NAME = "realesrgan-x4plus"
SCALE = 4
ASSETS = (
    ("common_hanji_paper.png", "common_hanji_paper_x4.png"),
    ("floor_gate_plaque.png", "floor_gate_plaque_x4.png"),
    ("route_brush_unselected.png", "route_brush_unselected_x4.png"),
    ("route_brush_available.png", "route_brush_available_x4.png"),
    ("route_brush_completed_gold.png", "route_brush_completed_gold_x4.png"),
    ("human_realm_01_mountain_rev2.png", "human_realm_01_mountain_rev2_x4.png"),
    ("human_realm_02_village_rev2.png", "human_realm_02_village_rev2_x4.png"),
    ("human_realm_03_river_rev2.png", "human_realm_03_river_rev2_x4.png"),
    ("immortal_realm_01_islands_rev2.png", "immortal_realm_01_islands_rev2_x4.png"),
    ("immortal_realm_02_cloud_cranes_rev2.png", "immortal_realm_02_cloud_cranes_rev2_x4.png"),
    ("immortal_realm_03_pavilions_rev2.png", "immortal_realm_03_pavilions_rev2_x4.png"),
)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _alpha_bleed_rgb(image: Image.Image) -> tuple[Image.Image, Image.Image | None, dict]:
    rgba = image.convert("RGBA")
    source = np.asarray(rgba, dtype=np.uint8)
    alpha = source[:, :, 3]
    has_alpha = "A" in image.getbands()
    alpha_stats = {
        "present": has_alpha,
        "minimum": int(alpha.min()) if has_alpha else 255,
        "maximum": int(alpha.max()) if has_alpha else 255,
        "transparent_pixels": int(np.count_nonzero(alpha == 0)) if has_alpha else 0,
        "partial_pixels": int(np.count_nonzero((alpha > 0) & (alpha < 255))) if has_alpha else 0,
    }
    if not has_alpha:
        return image.convert("RGB"), None, alpha_stats

    rgb = source[:, :, :3].copy()
    transparent = alpha == 0
    visible = ~transparent
    if transparent.any() and visible.any():
        # distance_transform_edt returns the nearest zero-valued input index.
        # Feed the transparent mask so every fully transparent texel receives
        # the RGB of its nearest visible source texel. Partial RGB is untouched.
        nearest = distance_transform_edt(
            transparent,
            return_distances=False,
            return_indices=True,
        )
        rgb[transparent] = rgb[nearest[0][transparent], nearest[1][transparent]]
    return Image.fromarray(rgb), Image.fromarray(alpha), alpha_stats


def _run_realesrgan(executable: Path, models_dir: Path, source: Path, output: Path) -> None:
    command = [
        str(executable),
        "-i",
        str(source),
        "-o",
        str(output),
        "-m",
        str(models_dir),
        "-n",
        MODEL_NAME,
        "-s",
        str(SCALE),
        "-t",
        "256",
        "-f",
        "png",
    ]
    completed = subprocess.run(command, check=False, capture_output=True, text=True)
    if completed.returncode != 0:
        raise RuntimeError(
            "Real-ESRGAN failed for %s\nstdout:\n%s\nstderr:\n%s"
            % (source, completed.stdout, completed.stderr)
        )


def build(project_root: Path, executable: Path, models_dir: Path) -> None:
    asset_dir = project_root / "assets" / "sprites" / "tower" / "map_scroll"
    records: list[dict] = []
    with tempfile.TemporaryDirectory(prefix="tower_map_scroll_x4_") as temp_value:
        temp_dir = Path(temp_value)
        for source_name, output_name in ASSETS:
            source_path = asset_dir / source_name
            output_path = asset_dir / output_name
            source_image = Image.open(source_path)
            rgb_input, source_alpha, alpha_stats = _alpha_bleed_rgb(source_image)
            rgb_path = temp_dir / f"{source_path.stem}_rgb.png"
            upscaled_rgb_path = temp_dir / f"{source_path.stem}_rgb_x4.png"
            rgb_input.save(rgb_path, format="PNG", optimize=False)
            _run_realesrgan(executable, models_dir, rgb_path, upscaled_rgb_path)
            upscaled_rgb = Image.open(upscaled_rgb_path).convert("RGB")
            expected_size = (source_image.width * SCALE, source_image.height * SCALE)
            if upscaled_rgb.size != expected_size:
                raise RuntimeError(
                    f"{source_name}: expected {expected_size}, got {upscaled_rgb.size}"
                )
            if source_alpha is None:
                final_image = upscaled_rgb
            else:
                resized_alpha = source_alpha.resize(expected_size, Image.Resampling.LANCZOS)
                final_image = upscaled_rgb.convert("RGBA")
                final_image.putalpha(resized_alpha)
            final_image.save(output_path, format="PNG", optimize=True)
            records.append(
                {
                    "source": source_name,
                    "output": output_name,
                    "source_size": [source_image.width, source_image.height],
                    "output_size": [expected_size[0], expected_size[1]],
                    "source_mode": source_image.mode,
                    "output_mode": final_image.mode,
                    "alpha": alpha_stats,
                    "source_sha256": _sha256(source_path),
                    "output_sha256": _sha256(output_path),
                }
            )
            print(
                f"{source_name} -> {output_name} {expected_size[0]}x{expected_size[1]} "
                f"alpha={alpha_stats['present']}"
            )

    manifest = {
        "pipeline": "Real-ESRGAN RGB and source-alpha recombination",
        "model": MODEL_NAME,
        "scale": SCALE,
        "alpha_resize": "Pillow LANCZOS from reviewed source alpha",
        "transparent_rgb": "nearest visible source RGB bleed before Real-ESRGAN",
        "world_size_policy": "catalog size remains authored world geometry; texture_size is x4 density",
        "assets": records,
    }
    manifest_path = asset_dir / "tower_map_scroll_x4_manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"manifest={manifest_path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--models-dir", type=Path, required=True)
    args = parser.parse_args()
    build(args.project_root.resolve(), args.executable.resolve(), args.models_dir.resolve())


if __name__ == "__main__":
    main()
