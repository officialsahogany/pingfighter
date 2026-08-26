from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
REFERENCE = ROOT / "reference_only_stage3_hwangyeokjeon_boss_skill_cards_imagegen_v1.png"
CELL_SIZE = (256, 96)
COLS = 4
ROWS = 3
FRAMES = 11

SKILLS = (
    "cotton_throw",
    "cotton_bomb",
    "deadly_hug",
    "heart_beam",
    "mirror_world",
    "size_shift",
    "rabbit_projectile",
)


def _rgba_hash(image: Image.Image) -> str:
    return hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest()


def _file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _font(size: int) -> ImageFont.ImageFont:
    for path in (
        Path("C:/Windows/Fonts/consola.ttf"),
        Path("C:/Windows/Fonts/arial.ttf"),
    ):
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def _canonical_frame(reference: Image.Image) -> Image.Image:
    # The horizontal rail uses the per-channel median of all four canonical
    # cells. Common frame pixels survive while cell-specific tears, paper,
    # vortex, and cord details cancel out. Cell 0 supplies the exact side rails,
    # corner fittings, and mid-edge ornaments, where its subject does not intrude.
    cells = [
        reference.crop((index * CELL_SIZE[0], 0, (index + 1) * CELL_SIZE[0], CELL_SIZE[1])).convert("RGBA")
        for index in range(4)
    ]
    median_rail = Image.new("RGBA", CELL_SIZE)
    median_rail.putdata(
        tuple(
            tuple((sorted(channels)[1] + sorted(channels)[2]) // 2 for channels in zip(*samples))
            for samples in zip(*(tuple(cell.getdata()) for cell in cells))
        )
    )
    horizontal_mask = Image.new("L", CELL_SIZE, 0)
    horizontal_draw = ImageDraw.Draw(horizontal_mask)
    horizontal_draw.rectangle((0, 0, CELL_SIZE[0] - 1, 6), fill=255)
    horizontal_draw.rectangle((0, CELL_SIZE[1] - 7, CELL_SIZE[0] - 1, CELL_SIZE[1] - 1), fill=255)
    median_rail.putalpha(horizontal_mask)

    frame = Image.new("RGBA", CELL_SIZE, (0, 0, 0, 0))
    frame.alpha_composite(median_rail)
    side_rail = cells[0]
    side_mask = Image.new("L", CELL_SIZE, 0)
    draw = ImageDraw.Draw(side_mask)
    draw.rectangle((0, 0, 17, CELL_SIZE[1] - 1), fill=255)
    draw.rectangle((CELL_SIZE[0] - 18, 0, CELL_SIZE[0] - 1, CELL_SIZE[1] - 1), fill=255)
    for x0, y0 in (
        (0, 0),
        (CELL_SIZE[0] - 24, 0),
        (0, CELL_SIZE[1] - 15),
        (CELL_SIZE[0] - 24, CELL_SIZE[1] - 15),
    ):
        draw.rectangle((x0, y0, x0 + 23, y0 + 14), fill=255)
    side_rail.putalpha(side_mask)
    frame.alpha_composite(side_rail)
    return frame


def _build_cards(reference: Image.Image) -> dict[str, Image.Image]:
    frame = _canonical_frame(reference)
    frame.save(ROOT / "stage3_skillcard_canonical_frame_rev2.png")
    cards: dict[str, Image.Image] = {}
    for skill in SKILLS:
        raw_path = ROOT / f"stage3_{skill}_skillcard_candidate_rev2_raw.png"
        raw = Image.open(raw_path).convert("RGBA")
        if raw.width * CELL_SIZE[1] != raw.height * CELL_SIZE[0]:
            raise ValueError(f"{raw_path.name}: expected 8:3 source, got {raw.size}")
        card = raw.resize(CELL_SIZE, Image.Resampling.LANCZOS)
        card.alpha_composite(frame)
        out_path = ROOT / f"stage3_{skill}_skillcard_candidate_rev2_256x96.png"
        card.save(out_path, optimize=True)
        cards[skill] = card
    return cards


def _build_contact_sheet(cards: dict[str, Image.Image]) -> None:
    tile_size = (512, 192)
    label_h = 34
    sheet = Image.new("RGBA", (tile_size[0] * 4, (tile_size[1] + label_h) * 2), (8, 7, 6, 255))
    draw = ImageDraw.Draw(sheet)
    font = _font(22)
    for index, skill in enumerate(SKILLS):
        x = (index % 4) * tile_size[0]
        y = (index // 4) * (tile_size[1] + label_h)
        enlarged = cards[skill].resize(tile_size, Image.Resampling.NEAREST)
        sheet.alpha_composite(enlarged, (x, y))
        text_box = draw.textbbox((0, 0), skill, font=font)
        text_w = text_box[2] - text_box[0]
        draw.text((x + (tile_size[0] - text_w) / 2, y + tile_size[1] + 5), skill, font=font, fill=(190, 153, 80, 255))
    sheet.save(ROOT / "stage3_variant_skillcard_candidate_rev2_contact_sheet.png", optimize=True)


def _build_comparison(reference: Image.Image, cards: dict[str, Image.Image]) -> None:
    comparison = Image.new("RGBA", (CELL_SIZE[0] * 10, CELL_SIZE[1]), (0, 0, 0, 0))
    for index in range(3):
        comparison.alpha_composite(
            reference.crop((index * CELL_SIZE[0], 0, (index + 1) * CELL_SIZE[0], CELL_SIZE[1])).convert("RGBA"),
            (index * CELL_SIZE[0], 0),
        )
    for offset, skill in enumerate(SKILLS, start=3):
        comparison.alpha_composite(cards[skill], (offset * CELL_SIZE[0], 0))
    comparison.save(ROOT / "stage3_yeonmyo3_plus_variant7_rev2_one_line_comparison.png", optimize=True)

    reduced = Image.new("RGBA", (CELL_SIZE[0] * len(SKILLS), CELL_SIZE[1]), (0, 0, 0, 0))
    for index, skill in enumerate(SKILLS):
        reduced.alpha_composite(cards[skill], (index * CELL_SIZE[0], 0))
    reduced.save(ROOT / "stage3_variant7_rev2_256x96_judgement_strip.png", optimize=True)


def _build_atlas(reference: Image.Image, cards: dict[str, Image.Image]) -> Image.Image:
    atlas = Image.new("RGBA", (CELL_SIZE[0] * COLS, CELL_SIZE[1] * ROWS), (0, 0, 0, 0))
    atlas.alpha_composite(reference, (0, 0))
    for index, skill in enumerate(SKILLS, start=4):
        col = index % COLS
        row = index // COLS
        atlas.alpha_composite(cards[skill], (col * CELL_SIZE[0], row * CELL_SIZE[1]))
    atlas.save(ROOT / "stage3_hwangyeokjeon_boss_skill_cards_candidate_rev2_atlas_4x3_11f.png", optimize=True)
    return atlas


def _build_grid_proof(atlas: Image.Image) -> None:
    proof = Image.new("RGBA", atlas.size, (14, 12, 10, 255))
    draw = ImageDraw.Draw(proof)
    checker = 12
    for y in range(0, proof.height, checker):
        for x in range(0, proof.width, checker):
            tone = 34 if (x // checker + y // checker) % 2 == 0 else 50
            draw.rectangle((x, y, x + checker - 1, y + checker - 1), fill=(tone, tone, tone, 255))
    proof.alpha_composite(atlas)
    draw = ImageDraw.Draw(proof)
    grid_color = (210, 164, 76, 255)
    for col in range(COLS + 1):
        x = min(col * CELL_SIZE[0], proof.width - 1)
        draw.line((x, 0, x, proof.height - 1), fill=grid_color, width=2)
    for row in range(ROWS + 1):
        y = min(row * CELL_SIZE[1], proof.height - 1)
        draw.line((0, y, proof.width - 1, y), fill=grid_color, width=2)
    font = _font(15)
    for index in range(COLS * ROWS):
        col = index % COLS
        row = index // COLS
        label = f"{index}" if index < FRAMES else "11 UNUSED"
        x = col * CELL_SIZE[0] + 7
        y = row * CELL_SIZE[1] + 6
        text_box = draw.textbbox((0, 0), label, font=font)
        draw.rectangle((x - 3, y - 2, x + text_box[2] + 3, y + text_box[3] + 2), fill=(0, 0, 0, 190))
        draw.text((x, y), label, font=font, fill=(245, 211, 138, 255))
    proof.save(ROOT / "stage3_hwangyeokjeon_boss_skill_cards_candidate_rev2_atlas_grid_proof.png", optimize=True)


def _write_contract_and_preservation(reference: Image.Image, atlas: Image.Image) -> None:
    mappings = {
        "tear_shower": 0,
        "curse_chest": 1,
        "psycho_ball": 2,
        "canonical_unindexed_cell": 3,
        **{skill: index for index, skill in enumerate(SKILLS, start=4)},
    }
    contract = {
        "cell_width": CELL_SIZE[0],
        "cell_height": CELL_SIZE[1],
        "cols": COLS,
        "rows": ROWS,
        "frames": FRAMES,
        "atlas_width": CELL_SIZE[0] * COLS,
        "atlas_height": CELL_SIZE[1] * ROWS,
        "unused_cells": [11],
        "mapping": mappings,
    }
    (ROOT / "stage3_variant_skillcard_candidate_rev2_atlas_contract.json").write_text(
        json.dumps(contract, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    cells = []
    for index in range(4):
        box = (index * CELL_SIZE[0], 0, (index + 1) * CELL_SIZE[0], CELL_SIZE[1])
        before = reference.crop(box).convert("RGBA")
        after = atlas.crop(box).convert("RGBA")
        difference = ImageChops.difference(before, after)
        changed_pixels = sum(1 for a, b in zip(before.getdata(), after.getdata()) if a != b)
        cells.append(
            {
                "index": index,
                "before_rgba_sha256": _rgba_hash(before),
                "after_rgba_sha256": _rgba_hash(after),
                "changed_pixels": changed_pixels,
                "difference_bbox": difference.getbbox(),
                "preserved": changed_pixels == 0,
            }
        )
    preservation = {
        "reference_file_sha256": _file_hash(REFERENCE),
        "reference_dimensions": list(reference.size),
        "reference_mode": reference.mode,
        "reference_rgba_sha256": _rgba_hash(reference),
        "atlas_top_row_rgba_sha256": _rgba_hash(atlas.crop((0, 0, reference.width, reference.height))),
        "all_four_existing_cells_preserved": all(cell["preserved"] for cell in cells),
        "cells": cells,
    }
    (ROOT / "stage3_variant_skillcard_candidate_rev2_pixel_preservation.json").write_text(
        json.dumps(preservation, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def _assert_same_pixels(actual: Image.Image, expected: Image.Image, label: str) -> None:
    difference = ImageChops.difference(actual.convert("RGBA"), expected.convert("RGBA"))
    if difference.getbbox() is not None:
        raise AssertionError(f"{label}: pixel mismatch")


def _verify_outputs(reference: Image.Image, cards: dict[str, Image.Image], atlas: Image.Image) -> None:
    comparison = Image.open(ROOT / "stage3_yeonmyo3_plus_variant7_rev2_one_line_comparison.png").convert("RGBA")
    reduced = Image.open(ROOT / "stage3_variant7_rev2_256x96_judgement_strip.png").convert("RGBA")
    contact = Image.open(ROOT / "stage3_variant_skillcard_candidate_rev2_contact_sheet.png")
    grid = Image.open(ROOT / "stage3_hwangyeokjeon_boss_skill_cards_candidate_rev2_atlas_grid_proof.png")
    if comparison.size != (2560, 96) or reduced.size != (1792, 96):
        raise AssertionError("comparison or reduced-strip geometry changed")
    if contact.size != (2048, 452) or grid.size != (1024, 288):
        raise AssertionError("contact-sheet or grid-proof geometry changed")

    for index in range(3):
        box = (index * CELL_SIZE[0], 0, (index + 1) * CELL_SIZE[0], CELL_SIZE[1])
        _assert_same_pixels(comparison.crop(box), reference.crop(box), f"comparison canonical cell {index}")
    for offset, skill in enumerate(SKILLS):
        comparison_box = (
            (offset + 3) * CELL_SIZE[0],
            0,
            (offset + 4) * CELL_SIZE[0],
            CELL_SIZE[1],
        )
        reduced_box = (offset * CELL_SIZE[0], 0, (offset + 1) * CELL_SIZE[0], CELL_SIZE[1])
        atlas_index = offset + 4
        atlas_box = (
            (atlas_index % COLS) * CELL_SIZE[0],
            (atlas_index // COLS) * CELL_SIZE[1],
            (atlas_index % COLS + 1) * CELL_SIZE[0],
            (atlas_index // COLS + 1) * CELL_SIZE[1],
        )
        _assert_same_pixels(comparison.crop(comparison_box), cards[skill], f"comparison {skill}")
        _assert_same_pixels(reduced.crop(reduced_box), cards[skill], f"reduced {skill}")
        _assert_same_pixels(atlas.crop(atlas_box), cards[skill], f"atlas {skill}")

    _assert_same_pixels(atlas.crop((0, 0, 1024, 96)), reference, "atlas canonical top row")
    unused = atlas.crop((768, 192, 1024, 288))
    if unused.getchannel("A").getextrema() != (0, 0):
        raise AssertionError("atlas index 11 must remain fully transparent")


def main() -> None:
    reference = Image.open(REFERENCE).convert("RGBA")
    if reference.size != (1024, 96):
        raise ValueError(f"canonical reference must be 1024x96, got {reference.size}")
    cards = _build_cards(reference)
    _build_contact_sheet(cards)
    _build_comparison(reference, cards)
    atlas = _build_atlas(reference, cards)
    _build_grid_proof(atlas)
    _write_contract_and_preservation(reference, atlas)
    _verify_outputs(reference, cards, atlas)
    print(f"PASS: built and verified {len(cards)} candidates, 4 evidence images, and 4x3/11f atlas contract")


if __name__ == "__main__":
    main()
