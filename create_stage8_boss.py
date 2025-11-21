#!/usr/bin/env python3
"""Generate a top-down stage 8 ninja boss sprite with shuriken and black paddle."""

from math import cos, sin, pi
from typing import List, Tuple

from PIL import Image, ImageDraw


CANVAS = 512
CENTER = CANVAS // 2

# Palette tuned for a stealthy ninja with a few vivid accents
NINJA_DARK = (20, 24, 34, 255)
NINJA_MID = (36, 44, 64, 255)
NINJA_LIGHT = (60, 76, 112, 255)
ACCENT_RED = (200, 36, 48, 255)
ACCENT_TRIM = (92, 180, 200, 255)
GLOVE = (74, 92, 128, 255)
PADDLE_FACE = (22, 22, 26, 255)
PADDLE_RING = (58, 60, 70, 255)
PADDLE_HANDLE = (161, 116, 78, 255)
SHURIKEN_METAL = (200, 210, 225, 255)
SHURIKEN_EDGE = (120, 132, 148, 255)
EYE = (240, 246, 255, 255)
SHADOW_COLOR = (0, 0, 0)


def rotated_rect(cx: float, cy: float, w: float, h: float, deg: float) -> List[Tuple[float, float]]:
    """Return corner points for a rotated rectangle."""
    rad = deg * pi / 180
    dx, dy = w / 2, h / 2
    corners = [(-dx, -dy), (dx, -dy), (dx, dy), (-dx, dy)]
    return [
        (cx + x * cos(rad) - y * sin(rad), cy + x * sin(rad) + y * cos(rad))
        for x, y in corners
    ]


def star_points(cx: float, cy: float, outer: float, inner: float, spikes: int, rotation_deg: float) -> List[Tuple[float, float]]:
    """Build alternating outer/inner points for a shuriken-style star."""
    rotation = rotation_deg * pi / 180
    pts = []
    for i in range(spikes * 2):
        ang = rotation + i * pi / spikes
        r = outer if i % 2 == 0 else inner
        pts.append((cx + cos(ang) * r, cy + sin(ang) * r))
    return pts


def add_shadow(draw: ImageDraw.ImageDraw) -> None:
    for rw, rh, alpha in [(180, 62, 38), (150, 54, 30), (124, 46, 22), (96, 40, 14)]:
        draw.ellipse(
            (CENTER - rw, 356 - rh // 2, CENTER + rw, 356 + rh // 2),
            fill=SHADOW_COLOR + (alpha,),
        )


def draw_body(draw: ImageDraw.ImageDraw) -> None:
    draw.ellipse((CENTER - 92, 200, CENTER + 92, 360), fill=NINJA_DARK)
    draw.ellipse((CENTER - 82, 214, CENTER + 82, 350), fill=NINJA_MID)
    draw.rectangle((CENTER - 24, 214, CENTER + 24, 320), fill=NINJA_LIGHT)
    draw.rectangle((CENTER - 20, 214, CENTER - 6, 320), fill=NINJA_MID)
    draw.rectangle((CENTER + 6, 214, CENTER + 20, 320), fill=NINJA_MID)
    draw.rectangle((CENTER - 40, 310, CENTER + 40, 326), fill=ACCENT_TRIM)
    draw.rectangle((CENTER - 42, 316, CENTER + 42, 330), outline=NINJA_LIGHT, width=2)


def draw_head(draw: ImageDraw.ImageDraw) -> None:
    draw.ellipse((CENTER - 70, 126, CENTER + 70, 262), fill=NINJA_DARK)
    draw.ellipse((CENTER - 60, 138, CENTER + 60, 250), fill=NINJA_MID)

    # Headband
    draw.rectangle((CENTER - 72, 150, CENTER + 72, 178), fill=ACCENT_RED)
    draw.rectangle((CENTER - 72, 170, CENTER + 72, 180), fill=(140, 20, 30, 255))
    draw.polygon([(CENTER - 64, 178), (CENTER - 102, 198), (CENTER - 74, 184)], fill=ACCENT_RED)
    draw.polygon([(CENTER - 86, 196), (CENTER - 122, 214), (CENTER - 94, 200)], fill=(150, 28, 38, 255))

    # Mask slit with eyes
    draw.rectangle((CENTER - 46, 186, CENTER + 46, 210), fill=NINJA_DARK)
    draw.rectangle((CENTER - 42, 190, CENTER + 42, 206), fill=PADDLE_RING)
    draw.rectangle((CENTER - 32, 192, CENTER - 8, 204), fill=EYE)
    draw.rectangle((CENTER + 8, 192, CENTER + 32, 204), fill=EYE)

    # Top highlight
    draw.ellipse((CENTER - 46, 152, CENTER + 46, 196), outline=NINJA_LIGHT, width=3)


def draw_arms(draw: ImageDraw.ImageDraw) -> Tuple[Tuple[int, int], Tuple[int, int]]:
    left_center = (CENTER - 140, 260)
    right_center = (CENTER + 140, 260)

    draw.ellipse((left_center[0] - 46, left_center[1] - 34, left_center[0] + 46, left_center[1] + 42), fill=NINJA_MID)
    draw.ellipse((left_center[0] - 38, left_center[1] - 30, left_center[0] + 38, left_center[1] + 36), fill=NINJA_LIGHT)
    draw.ellipse((right_center[0] - 46, right_center[1] - 34, right_center[0] + 46, right_center[1] + 42), fill=NINJA_MID)
    draw.ellipse((right_center[0] - 38, right_center[1] - 30, right_center[0] + 38, right_center[1] + 36), fill=NINJA_LIGHT)

    # Gloves
    draw.ellipse((left_center[0] - 22, left_center[1] + 28, left_center[0] + 22, left_center[1] + 64), fill=GLOVE)
    draw.ellipse((right_center[0] - 22, right_center[1] + 28, right_center[0] + 22, right_center[1] + 64), fill=GLOVE)

    return left_center, right_center


def draw_shuriken(draw: ImageDraw.ImageDraw, hand_center: Tuple[int, int]) -> None:
    cx, cy = hand_center[0] - 4, hand_center[1] + 60
    points = star_points(cx, cy, outer=34, inner=14, spikes=4, rotation_deg=-12)
    draw.polygon(points, fill=SHURIKEN_METAL, outline=SHURIKEN_EDGE)
    draw.ellipse((cx - 8, cy - 8, cx + 8, cy + 8), fill=SHURIKEN_EDGE)
    draw.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=SHURIKEN_METAL)


def draw_paddle(draw: ImageDraw.ImageDraw, hand_center: Tuple[int, int]) -> None:
    handle_poly = rotated_rect(hand_center[0] + 10, hand_center[1] + 80, w=20, h=74, deg=28)
    draw.polygon(handle_poly, fill=PADDLE_HANDLE, outline=PADDLE_RING)

    blade_center = (hand_center[0] + 40, hand_center[1] + 44)
    draw.ellipse(
        (blade_center[0] - 58, blade_center[1] - 68, blade_center[0] + 58, blade_center[1] + 68),
        fill=PADDLE_FACE,
        outline=PADDLE_RING,
        width=6,
    )
    draw.ellipse(
        (blade_center[0] - 38, blade_center[1] - 44, blade_center[0] + 38, blade_center[1] + 44),
        outline=NINJA_LIGHT,
        width=3,
    )
    draw.rectangle(
        (blade_center[0] - 12, blade_center[1] - 18, blade_center[0] + 12, blade_center[1] - 10),
        fill=(52, 52, 58, 255),
    )


def draw_straps(draw: ImageDraw.ImageDraw) -> None:
    draw.polygon(
        [(CENTER - 24, 214), (CENTER - 78, 280), (CENTER - 58, 288), (CENTER + 6, 222)],
        fill=NINJA_DARK,
        outline=NINJA_LIGHT,
    )
    draw.polygon(
        [(CENTER + 24, 214), (CENTER + 78, 280), (CENTER + 58, 288), (CENTER - 6, 222)],
        fill=NINJA_DARK,
        outline=NINJA_LIGHT,
    )
    draw.rectangle((CENTER - 16, 330, CENTER + 16, 352), fill=ACCENT_TRIM)
    draw.rectangle((CENTER - 18, 334, CENTER + 18, 356), outline=NINJA_LIGHT, width=2)


def build_sprite() -> Image.Image:
    base = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(base, "RGBA")

    add_shadow(draw)
    draw_body(draw)
    draw_straps(draw)
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
