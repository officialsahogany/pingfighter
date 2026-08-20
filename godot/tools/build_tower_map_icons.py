"""Promote the approved tower-map icon candidates to runtime PNGs.

Every output is a transparent 256x256 RGBA image whose visible content fits a
240x240 box.  The mapping is explicit so candidate provenance and runtime names
cannot drift independently.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[2]
CANDIDATE_ROOT = REPO_ROOT / "docs" / "art_candidates" / "tower_map_iconography"
OUTPUT_ROOT = PROJECT_ROOT / "assets" / "sprites" / "tower" / "map_icons"
CANVAS_SIZE = 256
CONTENT_SIZE = 240

SOURCE_BY_OUTPUT = {
    "node_shop_imagegen_v1.png": "s2_v2_shop_alpha.png",
    "node_training_imagegen_v1.png": "s2_v2_training_alpha.png",
    "node_fallen_monk_imagegen_v1.png": "s2_v2_fallen_monk_alpha.png",
    "node_guardian_spring_imagegen_v1.png": "s2_v2_guardian_spring_alpha.png",
    "node_rest_imagegen_v1.png": "s2_v2_rest_alpha.png",
    "map_hint_imagegen_v1.png": "s2_v2_map_hint_alpha.png",
    "boss_dalji_imagegen_v1.png": "s2_v3_boss_dalji_alpha.png",
    "boss_gaksital_imagegen_v1.png": "s2_v3_boss_gaksital_alpha.png",
    "boss_podo_imagegen_v1.png": "s2_v3_boss_podo_alpha.png",
    "boss_cheongringwi_imagegen_v1.png": "s2_v3_boss_cheongringwi_alpha.png",
    "boss_molewang_imagegen_v1.png": "s2_v3_boss_molewang_alpha.png",
    "boss_arachne_imagegen_v1.png": "s2_v3_boss_arachne_alpha.png",
    "boss_yeonmyo_imagegen_v1.png": "s2_v3_boss_yeonmyo_alpha.png",
    "boss_teddy_bear_imagegen_v1.png": "s2_v3_boss_teddy_bear_alpha.png",
    "boss_alice_imagegen_v1.png": "s2_v3_boss_alice_alpha.png",
    "boss_ponk_imagegen_v1.png": "s2_v3_boss_ponk_alpha.png",
    "boss_hongryun_imagegen_v1.png": "s2_v3_boss_hongryun_alpha.png",
    "boss_tetriser_imagegen_v1.png": "s2_v3_boss_tetriser_alpha.png",
    "boss_akamu_rigo_imagegen_v1.png": "s2_v3_boss_akamu_rigo_alpha.png",
    "boss_minotaur_imagegen_v1.png": "s2_v3_boss_minotaur_alpha.png",
}


def _fit_icon(source: Image.Image) -> Image.Image:
    rgba = source.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("candidate has no visible pixels")
    cropped = rgba.crop(bbox)
    scale = min(CONTENT_SIZE / cropped.width, CONTENT_SIZE / cropped.height)
    target_size = (
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    )
    resized = cropped.resize(target_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(
        resized,
        ((CANVAS_SIZE - target_size[0]) // 2, (CANVAS_SIZE - target_size[1]) // 2),
    )
    return canvas


def _edge_alpha_count(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    edge = []
    edge.extend(alpha.crop((0, 0, CANVAS_SIZE, 1)).getdata())
    edge.extend(alpha.crop((0, CANVAS_SIZE - 1, CANVAS_SIZE, CANVAS_SIZE)).getdata())
    edge.extend(alpha.crop((0, 1, 1, CANVAS_SIZE - 1)).getdata())
    edge.extend(alpha.crop((CANVAS_SIZE - 1, 1, CANVAS_SIZE, CANVAS_SIZE - 1)).getdata())
    return sum(value != 0 for value in edge)


def main() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    for output_name, source_name in SOURCE_BY_OUTPUT.items():
        source_path = CANDIDATE_ROOT / source_name
        if not source_path.is_file():
            raise FileNotFoundError(source_path)
        output = _fit_icon(Image.open(source_path))
        if output.size != (CANVAS_SIZE, CANVAS_SIZE):
            raise ValueError(f"unexpected output size for {output_name}: {output.size}")
        bbox = output.getchannel("A").getbbox()
        if bbox is None:
            raise ValueError(f"empty output: {output_name}")
        if bbox[2] - bbox[0] > CONTENT_SIZE or bbox[3] - bbox[1] > CONTENT_SIZE:
            raise ValueError(f"content box overflow: {output_name} {bbox}")
        if _edge_alpha_count(output) != 0:
            raise ValueError(f"nontransparent outer edge: {output_name}")
        output_path = OUTPUT_ROOT / output_name
        output.save(output_path, "PNG", optimize=True)
        print(f"wrote {output_path.relative_to(PROJECT_ROOT)} {output.size} bbox={bbox}")
    print(f"tower map runtime icon promotion: ok ({len(SOURCE_BY_OUTPUT)} files)")


if __name__ == "__main__":
    main()
