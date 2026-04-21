# -*- coding: utf-8 -*-
"""Build a dense Menhera identity board for AutoSprite reference uploads."""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
WALK_PATH = ROOT / "items" / "menhera_boss_sheet.png"
VICTORY_PATH = ROOT / "items" / "menhera_boss_victory.png"
OUTPUT_PATH = ROOT / ".tmp" / "menhera_autosprite_reference_board_v2.png"


def load_sheet_frames(sheet_path: Path, cols: int = 4, rows: int = 2) -> list[Image.Image]:
    sheet = Image.open(sheet_path).convert("RGBA")
    cell_w = sheet.width // cols
    cell_h = sheet.height // rows
    frames: list[Image.Image] = []
    for row in range(rows):
        for col in range(cols):
            box = (
                col * cell_w,
                row * cell_h,
                (col + 1) * cell_w,
                (row + 1) * cell_h,
            )
            frames.append(sheet.crop(box))
    return frames


def trim_visible(frame: Image.Image, alpha_threshold: int = 8) -> Image.Image:
    alpha = frame.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > alpha_threshold else 0).getbbox()
    if not bbox:
        return frame
    return frame.crop(bbox)


def crop_region(frame: Image.Image, left_ratio: float, top_ratio: float, right_ratio: float, bottom_ratio: float) -> Image.Image:
    left = int(frame.width * left_ratio)
    top = int(frame.height * top_ratio)
    right = int(frame.width * right_ratio)
    bottom = int(frame.height * bottom_ratio)
    return frame.crop((left, top, right, bottom))


def paste_center(canvas: Image.Image, image: Image.Image, x: int, y: int, box_w: int, box_h: int) -> None:
    scale = min(box_w / image.width, box_h / image.height)
    target_size = (
        max(1, int(round(image.width * scale))),
        max(1, int(round(image.height * scale))),
    )
    resized = image.resize(target_size, Image.Resampling.NEAREST)
    paste_x = x + (box_w - resized.width) // 2
    paste_y = y + (box_h - resized.height) // 2
    canvas.alpha_composite(resized, (paste_x, paste_y))


def build_board() -> Path:
    walk_frames = [trim_visible(frame) for frame in load_sheet_frames(WALK_PATH)]
    victory_frames = [trim_visible(frame) for frame in load_sheet_frames(VICTORY_PATH)]

    # Use the most front-readable walk frame as the main identity anchor and
    # add a second nearby walk frame plus one victory frame to reinforce that
    # the model should preserve the same character across motion states.
    walk_anchor = walk_frames[3]
    walk_alt = walk_frames[4]
    victory_anchor = victory_frames[0]

    face_crop = trim_visible(crop_region(walk_anchor, 0.18, 0.02, 0.82, 0.44))
    cap_crop = trim_visible(crop_region(walk_anchor, 0.18, 0.00, 0.84, 0.22))
    torso_crop = trim_visible(crop_region(walk_anchor, 0.20, 0.24, 0.82, 0.72))
    accessory_crop = trim_visible(crop_region(walk_anchor, 0.44, 0.28, 0.98, 0.90))

    board = Image.new("RGBA", (2048, 2048), (255, 255, 255, 255))

    # Left column: full-body anchors. Right column: dense identity detail callouts.
    paste_center(board, walk_anchor, 90, 90, 780, 900)
    paste_center(board, walk_alt, 90, 1048, 360, 760)
    paste_center(board, victory_anchor, 510, 1048, 360, 760)

    paste_center(board, cap_crop, 1080, 120, 780, 300)
    paste_center(board, face_crop, 1040, 450, 860, 420)
    paste_center(board, torso_crop, 1080, 900, 780, 440)
    paste_center(board, accessory_crop, 1080, 1410, 780, 480)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    board.save(OUTPUT_PATH)
    return OUTPUT_PATH


def main() -> None:
    output_path = build_board()
    print(os.fspath(output_path))


if __name__ == "__main__":
    main()
