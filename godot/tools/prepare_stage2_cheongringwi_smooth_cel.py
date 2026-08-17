from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt


GODOT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = GODOT_ROOT / "assets" / "sprites" / "stage2" / "source"
OUTPUT_DIR = GODOT_ROOT / "assets" / "sprites" / "stage2"
CELL_SIZE = 512
GRID_SIZE = 4
FIT_SCALE = 0.90
FIT_SIZE = round(CELL_SIZE * FIT_SCALE)
FIT_X = (CELL_SIZE - FIT_SIZE) // 2
SOURCE_FOOT_Y = 474.0
TARGET_FOOT_Y = 454.0
FIT_Y = round(TARGET_FOOT_Y - SOURCE_FOOT_Y * FIT_SCALE)

SHEETS = {
    "idle": (
        "stage2_cheongringwi_idle_autosprite_smooth_cel_candidate_v1_16f.png",
        "stage2_cheongringwi_idle_autosprite_v5_smooth_cel_16f.png",
    ),
    "walk_left": (
        "stage2_cheongringwi_walk_left_autosprite_smooth_cel_strict_front_candidate_v2_16f.png",
        "stage2_cheongringwi_walk_left_autosprite_v6_strict_front_smooth_cel_16f.png",
    ),
    # The accepted walk is intentionally direction-neutral: gameplay position
    # communicates left/right while the boss keeps facing the player. Reusing
    # the same AutoSprite-derived frames also preserves the paddle's body side.
    "walk_right": (
        "stage2_cheongringwi_walk_left_autosprite_smooth_cel_strict_front_candidate_v2_16f.png",
        "stage2_cheongringwi_walk_right_autosprite_v6_strict_front_smooth_cel_16f.png",
    ),
    "attack": (
        "stage2_cheongringwi_attack_autosprite_smooth_cel_candidate_v1_16f.png",
        "stage2_cheongringwi_attack_autosprite_v4_smooth_cel_16f.png",
    ),
    "earth_stomp": (
        "stage2_cheongringwi_earth_stomp_autosprite_smooth_cel_candidate_v1_16f.png",
        "stage2_cheongringwi_earth_stomp_autosprite_v4_smooth_cel_16f.png",
    ),
    "victory": (
        "stage2_cheongringwi_victory_autosprite_smooth_cel_candidate_v1_16f.png",
        "stage2_cheongringwi_victory_autosprite_v4_smooth_cel_16f.png",
    ),
    "defeat": (
        "stage2_cheongringwi_defeat_autosprite_smooth_cel_candidate_v1_16f.png",
        "stage2_cheongringwi_defeat_autosprite_v4_smooth_cel_16f.png",
    ),
}


def _unmatte_white_edge(cell: np.ndarray) -> np.ndarray:
    result = cell.copy()
    rgb = result[:, :, :3]
    alpha = result[:, :, 3]
    opaque = alpha >= 200
    if not np.any(opaque):
        return result
    distance, nearest = distance_transform_edt(~opaque, return_indices=True)
    value = rgb.max(axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    replace = (
        (alpha > 0)
        & (alpha < 250)
        & (value >= 190)
        & (chroma <= 90)
        & (distance <= 4.0)
    )
    nearest_rgb = rgb[nearest[0], nearest[1]]
    rgb[replace] = nearest_rgb[replace]
    return result


def _resize_premultiplied(cell: np.ndarray) -> np.ndarray:
    rgba = cell.astype(np.float32)
    alpha = rgba[:, :, 3]
    premultiplied = rgba[:, :, :3] * (alpha[:, :, None] / 255.0)

    resized_alpha = np.asarray(
        Image.fromarray(alpha).resize(
            (FIT_SIZE, FIT_SIZE), Image.Resampling.LANCZOS
        ),
        dtype=np.float32,
    )
    resized_premultiplied = np.stack(
        [
            np.asarray(
                Image.fromarray(premultiplied[:, :, channel]).resize(
                    (FIT_SIZE, FIT_SIZE), Image.Resampling.LANCZOS
                ),
                dtype=np.float32,
            )
            for channel in range(3)
        ],
        axis=2,
    )

    resized_rgb = np.zeros_like(resized_premultiplied)
    visible = resized_alpha > 0.5
    resized_rgb[visible] = (
        resized_premultiplied[visible] * 255.0 / resized_alpha[visible, None]
    )
    return np.dstack(
        (
            np.clip(resized_rgb, 0.0, 255.0),
            np.clip(resized_alpha, 0.0, 255.0),
        )
    ).astype(np.uint8)


def _prepare_sheet(source_path: Path, output_path: Path) -> None:
    source = np.asarray(Image.open(source_path).convert("RGBA"))
    expected_size = CELL_SIZE * GRID_SIZE
    if source.shape[:2] != (expected_size, expected_size):
        raise ValueError(f"unexpected sheet size for {source_path}: {source.shape}")

    output = np.zeros_like(source)
    for row in range(GRID_SIZE):
        for column in range(GRID_SIZE):
            left = column * CELL_SIZE
            top = row * CELL_SIZE
            cell = source[top : top + CELL_SIZE, left : left + CELL_SIZE]
            cell = _resize_premultiplied(_unmatte_white_edge(cell))
            output[
                top + FIT_Y : top + FIT_Y + FIT_SIZE,
                left + FIT_X : left + FIT_X + FIT_SIZE,
            ] = cell

    output_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(output).save(output_path, optimize=True)


def _alpha_metrics(path: Path) -> str:
    image = Image.open(path).convert("RGBA")
    boxes: list[tuple[int, int, int, int]] = []
    edge_alpha = 0
    for row in range(GRID_SIZE):
        for column in range(GRID_SIZE):
            cell = image.crop(
                (
                    column * CELL_SIZE,
                    row * CELL_SIZE,
                    (column + 1) * CELL_SIZE,
                    (row + 1) * CELL_SIZE,
                )
            )
            bbox = cell.getchannel("A").getbbox()
            if bbox is not None:
                boxes.append(bbox)
            alpha = np.asarray(cell.getchannel("A"))
            edge_alpha += int(np.count_nonzero(alpha[0, :]))
            edge_alpha += int(np.count_nonzero(alpha[-1, :]))
            edge_alpha += int(np.count_nonzero(alpha[:, 0]))
            edge_alpha += int(np.count_nonzero(alpha[:, -1]))
    heights = [bottom - top for _, top, _, bottom in boxes]
    bottoms = [bottom for _, _, _, bottom in boxes]
    return (
        f"height={min(heights)}..{max(heights)} "
        f"bottom={min(bottoms)}..{max(bottoms)} edge_alpha={edge_alpha}"
    )


def main() -> None:
    for key, (source_name, output_name) in SHEETS.items():
        source_path = SOURCE_DIR / source_name
        output_path = OUTPUT_DIR / output_name
        _prepare_sheet(source_path, output_path)
        print(f"{key}: {output_path.name} {_alpha_metrics(output_path)}")

    idle_path = OUTPUT_DIR / SHEETS["idle"][1]
    idle = Image.open(idle_path).convert("RGBA")
    still_path = (
        OUTPUT_DIR
        / "stage2_cheongringwi_scale_ward_still_autosprite_v4_smooth_cel.png"
    )
    idle.crop((0, 0, CELL_SIZE, CELL_SIZE)).save(still_path, optimize=True)
    print(f"scale_ward: {still_path.name}")


if __name__ == "__main__":
    main()
