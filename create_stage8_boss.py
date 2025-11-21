#!/usr/bin/env python3
"""Generate a top-down stage 8 boss (탁닌자) with more realistic proportions."""

from math import cos, sin, pi
from typing import Iterable, List, Tuple

from PIL import Image, ImageDraw, ImageFilter


CANVAS = 512
CENTER = CANVAS // 2

# Palette aimed at a grounded, gritty ninja look
NINJA_BASE = (18, 22, 30, 255)
NINJA_MID = (32, 40, 58, 255)
NINJA_LIGHT = (62, 80, 116, 255)
GEAR_TRIM = (96, 172, 196, 255)
BAND_RED = (192, 38, 42, 255)
GLOVE = (78, 86, 110, 255)
SKIN = (214, 186, 150, 255)
SKIN_SHADOW = (172, 144, 112, 255)
PADDLE_FACE = (18, 18, 22, 255)
PADDLE_EDGE = (70, 70, 78, 255)
PADDLE_HANDLE = (158, 116, 84, 255)
SHURIKEN_CORE = (196, 210, 224, 255)
SHURIKEN_EDGE = (120, 132, 148, 255)
EYE_WHITE = (238, 244, 250, 255)
EYE_SHADOW = (32, 38, 52, 255)
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
    # Slight V-shape upper body instead of round blob
    torso_poly = [
        (CENTER - 68, 192),
        (CENTER + 68, 192),
        (CENTER + 86, 270),
        (CENTER + 54, 352),
        (CENTER - 54, 352),
        (CENTER - 86, 270),
    ]
    draw.polygon(torso_poly, fill=NINJA_MID, outline=(20, 24, 30, 180))
    inner_poly = [(x * 0.94 + CENTER * 0.06, y + 6) for x, y in torso_poly]
    draw.polygon(inner_poly, fill=NINJA_BASE)
    # chest panel
    draw.polygon(
        [
            (CENTER - 28, 206),
            (CENTER + 28, 206),
            (CENTER + 34, 312),
            (CENTER - 34, 312),
        ],
        fill=NINJA_LIGHT,
    )
    # belt
    draw.rectangle((CENTER - 54, 306, CENTER + 54, 334), fill=GEAR_TRIM, outline=NINJA_LIGHT, width=3)
    draw.rectangle((CENTER - 16, 312, CENTER + 16, 330), fill=(220, 230, 240, 255), outline=NINJA_MID, width=2)


def draw_head(draw: ImageDraw.ImageDraw) -> None:
    # neck
    draw.rectangle((CENTER - 18, 186, CENTER + 18, 214), fill=NINJA_MID, outline=(18, 22, 30, 180), width=2)
    gradient_ellipse(draw, (CENTER - 70, 122, CENTER + 70, 258), NINJA_LIGHT, NINJA_BASE)
    draw.ellipse((CENTER - 68, 120, CENTER + 68, 256), outline=(10, 12, 18, 180), width=3)
    # angular jaw hint
    jaw = [
        (CENTER - 52, 226),
        (CENTER + 52, 226),
        (CENTER + 42, 246),
        (CENTER - 42, 246),
    ]
    draw.polygon(jaw, fill=NINJA_MID)
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
    # More human proportions: tapered upper arm + slimmer forearm
    left_shoulder = (CENTER - 116, 218)
    right_shoulder = (CENTER + 116, 218)
    upper_len = 78
    fore_len = 74
    shoulder_width = 34
    fore_width = 24

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
            (wrist[0] - 18, wrist[1] - 6, wrist[0] + 18, wrist[1] + 34),
            fill=GLOVE,
            outline=(42, 48, 62, 200),
            width=2,
        )
        return wrist

    left_wrist = limb(left_shoulder, -1)
    right_wrist = limb(right_shoulder, 1)
    return left_wrist, right_wrist


def draw_shuriken(draw: ImageDraw.ImageDraw, hand_center: Tuple[int, int]) -> None:
    cx, cy = hand_center[0] - 6, hand_center[1] + 70
    pts = star_points(cx, cy, outer=40, inner=16, spikes=4, rotation_deg=-6)
    draw.polygon(pts, fill=SHURIKEN_EDGE, outline=(60, 70, 82, 255))
    draw.polygon([(cx, cy - 10), (cx + 10, cy), (cx, cy + 10), (cx - 10, cy)], fill=SHURIKEN_CORE)
    draw.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), fill=(90, 96, 112, 255))


def draw_paddle(draw: ImageDraw.ImageDraw, hand_center: Tuple[int, int]) -> None:
    handle = rotated_rect(hand_center[0] + 14, hand_center[1] + 90, w=22, h=86, deg=28)
    draw.polygon(handle, fill=PADDLE_HANDLE, outline=PADDLE_EDGE)
    blade_center = (hand_center[0] + 46, hand_center[1] + 46)
    draw.ellipse(
        (blade_center[0] - 64, blade_center[1] - 78, blade_center[0] + 64, blade_center[1] + 78),
        fill=PADDLE_FACE,
        outline=PADDLE_EDGE,
        width=6,
    )
    draw.ellipse(
        (blade_center[0] - 44, blade_center[1] - 58, blade_center[0] + 44, blade_center[1] + 58),
        outline=(110, 114, 128, 255),
        width=3,
    )
    # surface texture lines
    for i in range(5):
        y = blade_center[1] - 46 + i * 18
        draw.line([(blade_center[0] - 36, y), (blade_center[0] + 36, y)], fill=(46, 46, 52, 160), width=2)


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
