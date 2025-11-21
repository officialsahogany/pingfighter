#!/usr/bin/env python3
"""Generate a top-down stage 8 boss (탁닌자) in chunky ninja style (hood + bold eyes)."""

from math import cos, sin, pi
from typing import Iterable, List, Tuple

from PIL import Image, ImageDraw, ImageFilter


CANVAS = 512
CENTER = CANVAS // 2

# Palette inspired by chunky cartoon ninja
INK = (10, 12, 16, 255)
NINJA_BASE = (26, 32, 44, 255)
NINJA_MID = (42, 50, 64, 255)
NINJA_LIGHT = (72, 88, 118, 255)
NINJA_GLOSS = (114, 136, 170, 180)
BAND_RED = (176, 34, 46, 255)
BAND_SHADOW = (122, 22, 30, 255)
GLOVE = (68, 78, 100, 255)
GEAR_TRIM = (88, 110, 142, 255)
SKIN = (230, 198, 156, 255)
SKIN_SHADOW = (188, 152, 112, 255)
PADDLE_FACE = (14, 14, 18, 255)
PADDLE_EDGE = (78, 82, 96, 255)
PADDLE_HANDLE = (170, 120, 92, 255)
SHURIKEN_CORE = (210, 220, 232, 255)
SHURIKEN_EDGE = (124, 136, 148, 255)
EYE_WHITE = (248, 250, 255, 255)
EYE_IRIS = (54, 124, 214, 255)
EYE_SHADOW = (26, 30, 42, 255)
SHADOW_COLOR = (0, 0, 0)


def rotated_rect(cx: float, cy: float, w: float, h: float, deg: float) -> List[Tuple[float, float]]:
    rad = deg * pi / 180
    dx, dy = w / 2, h / 2
    corners = [(-dx, -dy), (dx, -dy), (dx, dy), (-dx, dy)]
    return [
        (cx + x * cos(rad) - y * sin(rad), cy + x * sin(rad) + y * cos(rad))
        for x, y in corners
    ]


def star_points(cx: float, cy: float, outer: float, inner: float, spikes: int, rotation_deg: float) -> List[Tuple[float, float]]:
    rotation = rotation_deg * pi / 180
    pts: List[Tuple[float, float]] = []
    for i in range(spikes * 2):
        ang = rotation + i * pi / spikes
        r = outer if i % 2 == 0 else inner
        pts.append((cx + cos(ang) * r, cy + sin(ang) * r))
    return pts


def soft_shadow(base: Image.Image, bbox: Tuple[int, int, int, int], alpha: int) -> None:
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.ellipse(bbox, fill=(0, 0, 0, alpha))
    blur = shadow.filter(ImageFilter.GaussianBlur(radius=10))
    base.alpha_composite(blur)


def add_ground_shadow(canvas: Image.Image) -> None:
    offsets = [(0, 10, 160), (-8, 6, 120), (12, 0, 90)]
    for ox, oy, a in offsets:
        soft_shadow(
            canvas,
            (
                CENTER - 140 + ox,
                340 + oy,
                CENTER + 140 + ox,
                400 + oy,
            ),
            a,
        )


def gradient_ellipse(draw: ImageDraw.ImageDraw, bbox: Tuple[int, int, int, int], inner: Iterable[int], outer: Iterable[int]) -> None:
    ix1, iy1, ix2, iy2 = bbox
    w, h = ix2 - ix1, iy2 - iy1
    steps = 40
    for i in range(steps):
        t = i / (steps - 1)
        r = int(inner[0] * (1 - t) + outer[0] * t)
        g = int(inner[1] * (1 - t) + outer[1] * t)
        b = int(inner[2] * (1 - t) + outer[2] * t)
        a = int(inner[3] * (1 - t) + outer[3] * t)
        margin_x = int((w / 2) * (t * 0.6))
        margin_y = int((h / 2) * (t * 0.6))
        draw.ellipse((ix1 + margin_x, iy1 + margin_y, ix2 - margin_x, iy2 - margin_y), fill=(r, g, b, a))


def draw_torso(draw: ImageDraw.ImageDraw) -> None:
    # Compact chibi torso with belt and folds
    torso = [
        (CENTER - 70, 194),
        (CENTER + 70, 194),
        (CENTER + 92, 272),
        (CENTER + 66, 348),
        (CENTER - 66, 348),
        (CENTER - 92, 272),
    ]
    draw.polygon(torso, fill=NINJA_MID, outline=INK)

    inner = [(x * 0.94 + CENTER * 0.06, y + 8) for x, y in torso]
    draw.polygon(inner, fill=NINJA_BASE)

    # rib folds
    for i, xoff in enumerate((-30, 0, 30)):
        y1 = 230 + i * 18
        draw.line([(CENTER - 16 + xoff, y1), (CENTER + 16 + xoff, y1)], fill=NINJA_GLOSS, width=2)

    # chest panel & belt
    draw.polygon(
        [
            (CENTER - 30, 210),
            (CENTER + 30, 210),
            (CENTER + 38, 314),
            (CENTER - 38, 314),
        ],
        fill=NINJA_LIGHT,
        outline=INK,
    )
    draw.rectangle((CENTER - 60, 304, CENTER + 60, 338), fill=BAND_SHADOW, outline=INK, width=3)
    draw.rectangle((CENTER - 22, 310, CENTER + 22, 332), fill=GEAR_TRIM, outline=INK, width=3)


def draw_head(draw: ImageDraw.ImageDraw) -> None:
    # neck
    draw.rectangle((CENTER - 18, 186, CENTER + 18, 214), fill=NINJA_MID, outline=INK, width=2)
    # hood (large, chunky)
    gradient_ellipse(draw, (CENTER - 90, 108, CENTER + 90, 270), NINJA_LIGHT, NINJA_BASE)
    draw.ellipse((CENTER - 94, 104, CENTER + 94, 274), outline=INK, width=6)
    # hood inner shadow
    draw.ellipse((CENTER - 80, 132, CENTER + 80, 254), outline=(0, 0, 0, 140), width=8)
    # eye slit
    draw.rectangle((CENTER - 64, 196, CENTER + 64, 222), fill=EYE_SHADOW, outline=INK, width=3)
    draw.rectangle((CENTER - 60, 200, CENTER + 60, 214), fill=(56, 64, 82, 255))
    for offset in (-28, 28):
        draw.ellipse((CENTER + offset - 16, 200, CENTER + offset + 16, 220), fill=EYE_WHITE, outline=INK, width=2)
        draw.ellipse((CENTER + offset - 10, 204, CENTER + offset + 2, 218), fill=EYE_IRIS)
        draw.ellipse((CENTER + offset - 6, 208, CENTER + offset + 0, 216), fill=EYE_SHADOW)
    # brow hint
    draw.arc((CENTER - 68, 188, CENTER + 68, 210), 200, 340, fill=INK, width=4)
    # band wrap
    draw.rectangle((CENTER - 86, 172, CENTER + 86, 192), fill=BAND_RED, outline=INK, width=3)
    draw.rectangle((CENTER - 86, 188, CENTER + 86, 196), fill=BAND_SHADOW)
    # band
    draw.rectangle((CENTER - 78, 160, CENTER + 78, 188), fill=BAND_RED)
    draw.rectangle((CENTER - 78, 182, CENTER + 78, 192), fill=(120, 24, 30, 255))
    draw.polygon([(CENTER - 66, 188), (CENTER - 110, 204), (CENTER - 78, 196)], fill=BAND_RED)
    draw.polygon([(CENTER - 98, 210), (CENTER - 138, 222), (CENTER - 106, 206)], fill=(140, 26, 34, 255))
    # eye slit
    draw.rectangle((CENTER - 54, 194, CENTER + 54, 214), fill=EYE_SHADOW)
    draw.rectangle((CENTER - 48, 198, CENTER + 48, 210), fill=(58, 64, 80, 255))
    for offset in (-24, 24):
        draw.ellipse((CENTER + offset - 14, 198, CENTER + offset + 14, 214), fill=EYE_WHITE)
        draw.ellipse((CENTER + offset - 14, 198, CENTER + offset + 14, 214), outline=(180, 200, 220, 255), width=1)
        draw.ellipse((CENTER + offset - 8, 202, CENTER + offset + 2, 212), fill=(40, 54, 82, 255))
    # nasal bridge hint
    draw.line([(CENTER, 200), (CENTER, 214)], fill=(90, 96, 112, 200), width=2)
    # subtle highlight on crown
    draw.arc((CENTER - 52, 138, CENTER + 52, 184), start=200, end=340, fill=NINJA_LIGHT, width=3)


def draw_arms(draw: ImageDraw.ImageDraw) -> Tuple[Tuple[int, int], Tuple[int, int]]:
    # Chibi arms with clear forearm/hand separation
    left_shoulder = (CENTER - 130, 228)
    right_shoulder = (CENTER + 130, 228)
    upper_len = 74
    fore_len = 70
    shoulder_width = 36
    fore_width = 26

    def limb(shoulder: Tuple[int, int], side: int):
        sx, sy = shoulder
        elbow = (sx + side * 24, sy + upper_len)
        wrist = (elbow[0] + side * 10, elbow[1] + fore_len)
        # upper arm
        draw.polygon(
            [
                (sx - shoulder_width // 2, sy),
                (sx + shoulder_width // 2, sy),
                (elbow[0] + side * 10, elbow[1]),
                (elbow[0] - side * 10, elbow[1]),
            ],
            fill=NINJA_MID,
            outline=(18, 22, 28, 180),
        )
        # forearm
        draw.polygon(
            [
                (elbow[0] - side * (fore_width // 2), elbow[1]),
                (elbow[0] + side * (fore_width // 2), elbow[1]),
                (wrist[0] + side * 6, wrist[1]),
                (wrist[0] - side * 6, wrist[1]),
            ],
            fill=NINJA_LIGHT,
            outline=(18, 22, 28, 180),
        )
        # glove
        draw.rectangle(
            (wrist[0] - 18, wrist[1] - 4, wrist[0] + 18, wrist[1] + 36),
            fill=GLOVE,
            outline=(42, 48, 62, 220),
            width=3,
        )
        return wrist

    left_wrist = limb(left_shoulder, -1)
    right_wrist = limb(right_shoulder, 1)
    return left_wrist, right_wrist


def draw_shuriken(draw: ImageDraw.ImageDraw, hand_center: Tuple[int, int]) -> None:
    cx, cy = hand_center[0] - 10, hand_center[1] + 78
    pts = star_points(cx, cy, outer=42, inner=16, spikes=4, rotation_deg=-2)
    draw.polygon(pts, fill=SHURIKEN_EDGE, outline=INK)
    draw.ellipse((cx - 8, cy - 8, cx + 8, cy + 8), fill=SHURIKEN_CORE, outline=INK, width=2)


def draw_paddle(draw: ImageDraw.ImageDraw, hand_center: Tuple[int, int]) -> None:
    handle = rotated_rect(hand_center[0] + 18, hand_center[1] + 96, w=22, h=88, deg=30)
    draw.polygon(handle, fill=PADDLE_HANDLE, outline=PADDLE_EDGE)
    blade_center = (hand_center[0] + 54, hand_center[1] + 50)
    draw.ellipse(
        (blade_center[0] - 70, blade_center[1] - 84, blade_center[0] + 70, blade_center[1] + 84),
        fill=PADDLE_FACE,
        outline=PADDLE_EDGE,
        width=6,
    )
    draw.ellipse(
        (blade_center[0] - 48, blade_center[1] - 64, blade_center[0] + 48, blade_center[1] + 64),
        outline=(110, 114, 128, 255),
        width=4,
    )
    # surface texture lines
    for i in range(5):
        y = blade_center[1] - 48 + i * 20
        draw.line([(blade_center[0] - 42, y), (blade_center[0] + 42, y)], fill=(46, 46, 52, 160), width=2)


def draw_harness(draw: ImageDraw.ImageDraw) -> None:
    draw.polygon(
        [(CENTER - 24, 206), (CENTER - 92, 286), (CENTER - 66, 296), (CENTER + 4, 218)],
        fill=NINJA_BASE,
        outline=NINJA_LIGHT,
    )
    draw.polygon(
        [(CENTER + 24, 206), (CENTER + 92, 286), (CENTER + 66, 296), (CENTER - 4, 218)],
        fill=NINJA_BASE,
        outline=NINJA_LIGHT,
    )
    draw.rectangle((CENTER - 18, 332, CENTER + 18, 360), fill=GEAR_TRIM, outline=NINJA_LIGHT, width=2)


def draw_trap_shadow(draw: ImageDraw.ImageDraw) -> None:
    oval = (CENTER - 110, 178, CENTER + 110, 214)
    draw.ellipse(oval, outline=(0, 0, 0, 40), width=1)


def build_sprite() -> Image.Image:
    base = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(base, "RGBA")
    add_ground_shadow(base)
    draw_trap_shadow(draw)
    draw_torso(draw)
    draw_harness(draw)
    left_hand, right_hand = draw_arms(draw)
    draw_paddle(draw, right_hand)
    draw_shuriken(draw, left_hand)
    draw_head(draw)
    return base


def main() -> None:
    sprite = build_sprite()
    sprite.save("boss_stage8.png")


if __name__ == "__main__":
    main()
