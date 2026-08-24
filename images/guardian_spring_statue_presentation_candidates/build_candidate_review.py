from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
RAW = ROOT / "source_raw"
CANDIDATES = ROOT / "candidates"
REVIEW = ROOT / "review"
REPO = ROOT.parents[1]

BACKGROUND_SIZE = (760, 750)
CAPSULE_REVIEW_SIZE = (760, 438)


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/malgunbd.ttf" if bold else "C:/Windows/Fonts/malgun.ttf"),
        Path("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def _open(name: str) -> Image.Image:
    return Image.open(RAW / name).convert("RGBA")


def _cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = max(0, (resized.width - size[0]) // 2)
    top = max(0, (resized.height - size[1]) // 2)
    return resized.crop((left, top, left + size[0], top + size[1]))


def _contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(size, Image.Resampling.LANCZOS)
    return copy


def _checker(size: tuple[int, int], cell: int = 24) -> Image.Image:
    result = Image.new("RGBA", size, (229, 232, 229, 255))
    draw = ImageDraw.Draw(result)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if ((x // cell) + (y // cell)) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(199, 206, 202, 255))
    return result


def _paste_contained(
    canvas: Image.Image,
    image: Image.Image,
    rect: tuple[int, int, int, int],
    align_bottom: bool = False,
) -> tuple[int, int, int, int]:
    left, top, right, bottom = rect
    fitted = _contain(image, (right - left, bottom - top))
    x = left + ((right - left) - fitted.width) // 2
    y = bottom - fitted.height if align_bottom else top + ((bottom - top) - fitted.height) // 2
    canvas.alpha_composite(fitted, (x, y))
    return (x, y, x + fitted.width, y + fitted.height)


def _composite_statue(background: Image.Image, statue: Image.Image, glow: Image.Image | None) -> Image.Image:
    result = background.copy()
    statue_scaled = _contain(statue, (330, 450))
    x = (result.width - statue_scaled.width) // 2
    y = 710 - statue_scaled.height
    result.alpha_composite(statue_scaled, (x, y))
    if glow is not None:
        glow_scaled = glow.resize(statue_scaled.size, Image.Resampling.LANCZOS)
        # The source overlay stays fully bright; the review composite previews a
        # restrained runtime blend so the carved face and palm ledge remain legible.
        alpha = glow_scaled.getchannel("A").point(lambda value: round(value * 0.48))
        glow_scaled.putalpha(alpha)
        result.alpha_composite(glow_scaled, (x, y))
    return result


def _fit_guardian(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    alpha_box = image.getchannel("A").getbbox()
    if alpha_box:
        image = image.crop(alpha_box)
    return _contain(image, size)


def _capsule_three_up(capsule: Image.Image, background: Image.Image) -> Image.Image:
    base = _cover(background, CAPSULE_REVIEW_SIZE).filter(ImageFilter.GaussianBlur(1.2))
    veil = Image.new("RGBA", base.size, (3, 24, 31, 112))
    base = Image.alpha_composite(base, veil)
    cutin_paths = [
        REPO / "godot/assets/sprites/lingpet/nekuring_cutin_art.png",
        REPO / "godot/assets/sprites/lingpet/rabi_cutin_art_sd_identity_v3_clean.png",
        REPO / "godot/assets/sprites/lingpet/baekrin_cutin_art.png",
    ]
    card_w = 205
    gap = 14
    start_x = (base.width - (card_w * 3 + gap * 2)) // 2
    float_offsets = (5, -4, 2)
    for index, cutin_path in enumerate(cutin_paths):
        x = start_x + index * (card_w + gap)
        y = 54 + float_offsets[index]
        frame = _contain(capsule, (card_w, 330))
        frame_x = x + (card_w - frame.width) // 2
        frame_y = y + (330 - frame.height) // 2
        cutin = _fit_guardian(Image.open(cutin_path).convert("RGBA"), (148, 218))
        cutin_x = x + (card_w - cutin.width) // 2
        cutin_y = y + 64 + (210 - cutin.height) // 2
        base.alpha_composite(cutin, (cutin_x, cutin_y))
        base.alpha_composite(frame, (frame_x, frame_y))
    return base


def _stats(image: Image.Image) -> dict[str, object]:
    alpha = image.getchannel("A")
    histogram = alpha.histogram()
    visible = sum(histogram[1:])
    intermediate = sum(histogram[1:255])
    opaque = histogram[255]
    corners = [
        alpha.getpixel((0, 0)),
        alpha.getpixel((image.width - 1, 0)),
        alpha.getpixel((0, image.height - 1)),
        alpha.getpixel((image.width - 1, image.height - 1)),
    ]
    return {
        "size": [image.width, image.height],
        "alpha_bbox": list(alpha.getbbox()) if alpha.getbbox() else None,
        "corner_alpha": corners,
        "transparent_pixels": histogram[0],
        "intermediate_alpha_pixels": intermediate,
        "opaque_pixels": opaque,
        "visible_pixels": visible,
    }


def _labeled_panel(image: Image.Image, title: str, size: tuple[int, int]) -> Image.Image:
    panel = Image.new("RGBA", size, (23, 29, 28, 255))
    draw = ImageDraw.Draw(panel)
    content_h = size[1] - 52
    preview = _contain(image, (size[0] - 20, content_h - 12))
    x = (size[0] - preview.width) // 2
    y = 10 + (content_h - preview.height) // 2
    panel.alpha_composite(preview, (x, y))
    draw.rectangle((0, content_h, size[0], size[1]), fill=(11, 18, 18, 245))
    draw.text((14, content_h + 11), title, font=_font(23, True), fill=(236, 226, 197, 255))
    return panel


def _build_contact_sheet(
    current: Image.Image,
    background_a: Image.Image,
    background_b: Image.Image,
    normal: Image.Image,
    hover: Image.Image,
    statue_b: Image.Image,
    capsule_three: Image.Image,
    capsule_a: Image.Image,
    capsule_b: Image.Image,
) -> Image.Image:
    sheet = Image.new("RGBA", (1800, 2140), (13, 23, 23, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((54, 34), "Guardian Spring Presentation — Stage A Review", font=_font(42, True), fill=(239, 226, 186, 255))
    draw.text(
        (54, 88),
        "Original mood: mystical spring + Joseon garden + clear statue contact focus",
        font=_font(24),
        fill=(147, 205, 191, 255),
    )

    first_row = [
        _labeled_panel(current, "Current v1 reference", (540, 570)),
        _labeled_panel(background_a, "A — recommended background", (540, 570)),
        _labeled_panel(background_b, "B — reject: dark / side-biased", (540, 570)),
    ]
    for index, panel in enumerate(first_row):
        sheet.alpha_composite(panel, (54 + index * 574, 138))

    second_row = [
        _labeled_panel(normal, "Recommended scene — normal", (540, 570)),
        _labeled_panel(hover, "Recommended scene — hover glow", (540, 570)),
        _labeled_panel(statue_b, "Statue B — reject: contact unclear", (540, 570)),
    ]
    for index, panel in enumerate(second_row):
        sheet.alpha_composite(panel, (54 + index * 574, 742))

    capsule_panel = _labeled_panel(capsule_three, "Recommended capsule B — three-up cutin composite", (1114, 570))
    sheet.alpha_composite(capsule_panel, (54, 1346))
    sheet.alpha_composite(_labeled_panel(capsule_a, "Capsule A — reject: baked checker", (540, 570)), (1206, 1346))

    strip_y = 1960
    draw.rounded_rectangle((54, strip_y, 1746, 2092), radius=22, fill=(7, 42, 47, 255), outline=(101, 199, 186, 255), width=3)
    draw.text((84, strip_y + 22), "Recommended set", font=_font(27, True), fill=(236, 226, 197, 255))
    draw.text(
        (84, strip_y + 64),
        "Background A + palm-stele statue A + filled in-silhouette glow + jade-seed capsule B",
        font=_font(24),
        fill=(188, 229, 214, 255),
    )
    capsule_thumb = _contain(capsule_b, (78, 108))
    sheet.alpha_composite(capsule_thumb, (1636, strip_y + 12))
    return sheet


def main() -> None:
    CANDIDATES.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)

    background_a = _cover(_open("background_A_spring_dawn_imagegen_raw.png"), BACKGROUND_SIZE)
    background_b = _cover(_open("background_B_moonlit_imagegen_raw.png"), BACKGROUND_SIZE)
    current = _cover(
        Image.open(
            REPO / "godot/assets/sprites/tower/noncombat/guardian_spring_arena_background_imagegen_v1.png"
        ).convert("RGBA"),
        BACKGROUND_SIZE,
    )

    statue_a = _open("statue_A_palm_stele_imagegen_raw.png")
    statue_b = _open("statue_B_basin_idol_imagegen_raw.png")
    raw_glow = _open("statue_A_glow_imagegen_raw.png")
    if raw_glow.size != statue_a.size:
        raw_glow = raw_glow.resize(statue_a.size, Image.Resampling.LANCZOS)
    glow = raw_glow.copy()
    # The generated glow edit baked a review checker. Reuse only its painted RGB;
    # the accepted statue alpha is the exact alignment/silhouette authority.
    glow.putalpha(statue_a.getchannel("A"))

    capsule_a = _open("capsule_A_glass_dome_imagegen_raw.png")
    capsule_b = _open("capsule_B_jade_seed_imagegen_raw.png")

    background_a.save(CANDIDATES / "guardian_spring_background_A_760x750.png")
    background_b.save(CANDIDATES / "guardian_spring_background_B_760x750.png")
    statue_a.save(CANDIDATES / "guardian_spring_statue_A_palm_stele.png")
    statue_b.save(CANDIDATES / "guardian_spring_statue_B_basin_idol.png")
    glow.save(CANDIDATES / "guardian_spring_statue_A_glow_overlay.png")
    capsule_a.save(CANDIDATES / "guardian_spring_capsule_A_glass_dome_rejected.png")
    capsule_b.save(CANDIDATES / "guardian_spring_capsule_B_jade_seed.png")

    normal = _composite_statue(background_a, statue_a, None)
    hover = _composite_statue(background_a, statue_a, glow)
    capsule_three = _capsule_three_up(capsule_b, background_a)
    normal.save(REVIEW / "02_recommended_scene_normal.png")
    hover.save(REVIEW / "03_recommended_scene_hover.png")
    capsule_three.save(REVIEW / "04_recommended_capsule_three_up.png")

    alpha_a = statue_a.getchannel("A")
    alpha_glow = glow.getchannel("A")
    alpha_diff = ImageChops.difference(alpha_a, alpha_glow)
    hover_diff = ImageChops.difference(normal.convert("RGB"), hover.convert("RGB"))
    hover_hist = hover_diff.convert("L").histogram()
    hover_strong_delta = sum(hover_hist[32:])
    center = capsule_b.crop(
        (
            round(capsule_b.width * 0.28),
            round(capsule_b.height * 0.25),
            round(capsule_b.width * 0.72),
            round(capsule_b.height * 0.70),
        )
    ).getchannel("A")
    center_hist = center.histogram()
    center_pixels = center.width * center.height

    metrics = {
        "stage": "A_candidate_only",
        "runtime_wired": False,
        "base_commit": "c6038daeb198e74b6cebdf269fb254895ebf1d7a",
        "recommended": {
            "background": "guardian_spring_background_A_760x750.png",
            "statue": "guardian_spring_statue_A_palm_stele.png",
            "glow_overlay": "guardian_spring_statue_A_glow_overlay.png",
            "capsule": "guardian_spring_capsule_B_jade_seed.png",
        },
        "assets": {
            "background_A": _stats(background_a),
            "background_B": _stats(background_b),
            "statue_A": _stats(statue_a),
            "statue_B": _stats(statue_b),
            "statue_A_glow": _stats(glow),
            "capsule_A": _stats(capsule_a),
            "capsule_B": _stats(capsule_b),
        },
        "statue_glow_alignment": {
            "alpha_exact_match": alpha_diff.getbbox() is None,
            "alpha_sha256": hashlib.sha256(alpha_a.tobytes()).hexdigest(),
            "strong_hover_delta_pixels_luma_ge_32": hover_strong_delta,
        },
        "capsule_B_center_window": {
            "sample_size": [center.width, center.height],
            "alpha_le_64_ratio": round(sum(center_hist[:65]) / center_pixels, 6),
            "alpha_eq_0_ratio": round(center_hist[0] / center_pixels, 6),
        },
        "rejected_candidates": {
            "background_B": "원문보다 지나치게 어둡고, 누각이 우측으로 치우쳐 중앙 석상 장면의 위계가 약함",
            "statue_B": "샘물 분수대 인상이 강하고 손바닥을 올릴 접촉면이 즉시 읽히지 않음",
            "statue_A_background_extraction": "투명 배경 대신 체크 무늬가 픽셀에 구워져 사용 불가",
            "capsule_A": "투명 중앙창 대신 체크 무늬가 픽셀에 구워져 컷인 합성 불가",
        },
    }
    (REVIEW / "A_STAGE_QA.json").write_text(
        json.dumps(metrics, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    sheet = _build_contact_sheet(
        current,
        background_a,
        background_b,
        normal,
        hover,
        statue_b,
        capsule_three,
        capsule_a,
        capsule_b,
    )
    sheet.save(REVIEW / "01_contact_sheet.png")

    print("BUILD_OK")
    print(json.dumps(metrics["statue_glow_alignment"], ensure_ascii=False))
    print(json.dumps(metrics["capsule_B_center_window"], ensure_ascii=False))


if __name__ == "__main__":
    main()
