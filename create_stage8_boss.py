#!/usr/bin/env python3
"""Generate a top-down chibi ninja boss (탁닌자): full mask, sharp eyes, slim arms."""

from math import cos, sin, pi
from typing import Iterable, List, Tuple

from PIL import Image, ImageDraw, ImageFilter

CANVAS = 512
CENTER = CANVAS // 2

# Palette
INK = (12, 14, 18, 255)
SUIT_DARK = (26, 30, 42, 255)
SUIT_MID = (40, 46, 62, 255)
SUIT_LIGHT = (70, 84, 110, 255)
GLOSS = (118, 136, 168, 180)
MASK_SHADOW = (18, 20, 30, 230)
BAND = (180, 38, 50, 255)
BAND_SHADOW = (120, 26, 34, 255)
EYE_WHITE = (246, 248, 255, 255)
EYE_IRIS = (58, 126, 214, 255)
EYE_PUPIL = (22, 28, 42, 255)
GLOVE = (64, 74, 92, 255)
PADDLE_FACE = (16, 16, 20, 255)
PADDLE_EDGE = (88, 92, 108, 255)
PADDLE_HANDLE = (168, 120, 90, 255)
SHURIKEN_CORE = (210, 220, 232, 255)
SHURIKEN_EDGE = (126, 138, 150, 255)
SHADOW_COLOR = (0, 0, 0, 140)


def soft_shadow(canvas: Image.Image, bbox: Tuple[int, int, int, int], blur: int = 12) -> None:
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(bbox, fill=SHADOW_COLOR)
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(radius=blur)))


def ring_ellipse(draw: ImageDraw.ImageDraw, bbox: Tuple[int, int, int, int], inner: Iterable[int], outer: Iterable[int], steps: int = 32) -> None:
    x1, y1, x2, y2 = bbox
    for i in range(steps):
        t = i / (steps - 1)
        r = int(inner[0] * (1 - t) + outer[0] * t)
        g = int(inner[1] * (1 - t) + outer[1] * t)
        b = int(inner[2] * (1 - t) + outer[2] * t)
        a = int(inner[3] * (1 - t) + outer[3] * t)
        mx = int((x2 - x1) * 0.35 * t)
        my = int((y2 - y1) * 0.35 * t)
        draw.ellipse((x1 + mx, y1 + my, x2 - mx, y2 - my), fill=(r, g, b, a))


def star_points(cx: float, cy: float, outer: float, inner: float, spikes: int, rotation_deg: float) -> List[Tuple[float, float]]:
    rot = rotation_deg * pi / 180
    pts: List[Tuple[float, float]] = []
    for i in range(spikes * 2):
        ang = rot + i * pi / spikes
        r = outer if i % 2 == 0 else inner
        pts.append((cx + cos(ang) * r, cy + sin(ang) * r))
    return pts


def draw_head(draw: ImageDraw.ImageDraw) -> None:
    hood_bbox = (CENTER - 110, 104, CENTER + 110, 268)
    ring_ellipse(draw, hood_bbox, SUIT_LIGHT + (255,), SUIT_DARK + (255,), steps=40)
    draw.ellipse((hood_bbox[0] - 4, hood_bbox[1] - 4, hood_bbox[2] + 4, hood_bbox[3] + 6), outline=INK, width=6)

    # Face opening fully masked; only narrow eye slit
    slit_outer = (CENTER - 82, 190, CENTER + 82, 222)
    draw.rectangle(slit_outer, fill=MASK_SHADOW, outline=INK, width=3)
    slit_inner = (CENTER - 76, 194, CENTER + 76, 214)
    draw.rectangle(slit_inner, fill=SUIT_MID)

    for offset in (-30, 30):
        eye = (CENTER + offset - 18, 196, CENTER + offset + 18, 216)
        draw.ellipse(eye, fill=EYE_WHITE, outline=INK, width=2)
        draw.ellipse((eye[0] + 8, eye[1] + 4, eye[2] - 4, eye[3] - 2), fill=EYE_IRIS)
        draw.ellipse((eye[0] + 12, eye[1] + 6, eye[0] + 18, eye[1] + 14), fill=EYE_PUPIL)

    # Brow tension
    draw.arc((CENTER - 74, 182, CENTER + 74, 204), 200, 340, fill=INK, width=5)

    # Head band on back of hood
    draw.rectangle((CENTER - 96, 166, CENTER + 96, 182), fill=BAND, outline=INK, width=3)
    draw.rectangle((CENTER - 96, 180, CENTER + 96, 188), fill=BAND_SHADOW)


def draw_torso(draw: ImageDraw.ImageDraw) -> None:
    torso = [
        (CENTER - 76, 198),
        (CENTER + 76, 198),
        (CENTER + 96, 280),
        (CENTER + 68, 356),
        (CENTER - 68, 356),
        (CENTER - 96, 280),
    ]
    draw.polygon(torso, fill=SUIT_MID, outline=INK)
    inner = [(x * 0.95 + CENTER * 0.05, y + 6) for x, y in torso]
    draw.polygon(inner, fill=SUIT_DARK)
    # folds
    for i, xoff in enumerate((-26, 0, 26)):
        y = 232 + i * 18
        draw.line([(CENTER - 18 + xoff, y), (CENTER + 18 + xoff, y)], fill=GLOSS, width=2)
    # belt and buckle
    draw.rectangle((CENTER - 62, 306, CENTER + 62, 336), fill=BAND_SHADOW, outline=INK, width=3)
    draw.rectangle((CENTER - 26, 312, CENTER + 26, 332), fill=SUIT_LIGHT, outline=INK, width=3)


def draw_arms(draw: ImageDraw.ImageDraw) -> Tuple[Tuple[int, int], Tuple[int, int]]:
    left_shoulder = (CENTER - 138, 232)
    right_shoulder = (CENTER + 138, 232)
    upper_len = 70
    fore_len = 72
    shoulder_w = 30
    fore_w = 22

    def limb(shoulder: Tuple[int, int], side: int) -> Tuple[int, int]:
        sx, sy = shoulder
        elbow = (sx + side * 18, sy + upper_len)
        wrist = (elbow[0] + side * 10, elbow[1] + fore_len)
        draw.polygon(
            [
                (sx - shoulder_w // 2, sy),
                (sx + shoulder_w // 2, sy),
                (elbow[0] + side * 8, elbow[1]),
                (elbow[0] - side * 8, elbow[1]),
            ],
            fill=SUIT_DARK,
            outline=INK,
        )
        draw.polygon(
            [
                (elbow[0] - side * (fore_w // 2), elbow[1]),
                (elbow[0] + side * (fore_w // 2), elbow[1]),
                (wrist[0] + side * 6, wrist[1]),
                (wrist[0] - side * 6, wrist[1]),
            ],
            fill=SUIT_MID,
            outline=INK,
        )
        draw.rectangle((wrist[0] - 16, wrist[1] - 4, wrist[0] + 16, wrist[1] + 32), fill=GLOVE, outline=INK, width=2)
        return wrist

    left_w = limb(left_shoulder, -1)
    right_w = limb(right_shoulder, 1)
    return left_w, right_w


def draw_weapons(draw: ImageDraw.ImageDraw, left_hand: Tuple[int, int], right_hand: Tuple[int, int]) -> None:
    # Shuriken in left
    cx, cy = left_hand[0] - 8, left_hand[1] + 72
    pts = star_points(cx, cy, outer=40, inner=14, spikes=4, rotation_deg=0)
    draw.polygon(pts, fill=SHURIKEN_EDGE, outline=INK)
    draw.ellipse((cx - 8, cy - 8, cx + 8, cy + 8), fill=SHURIKEN_CORE, outline=INK, width=2)

    # Black paddle in right
    handle_poly = [
        (right_hand[0] + 6, right_hand[1] + 16),
        (right_hand[0] + 20, right_hand[1] + 102),
        (right_hand[0] + 6, right_hand[1] + 112),
        (right_hand[0] - 10, right_hand[1] + 28),
    ]
    draw.polygon(handle_poly, fill=PADDLE_HANDLE, outline=PADDLE_EDGE)
    blade_cx, blade_cy = right_hand[0] + 52, right_hand[1] + 52
    draw.ellipse(
        (blade_cx - 70, blade_cy - 82, blade_cx + 70, blade_cy + 82),
        fill=PADDLE_FACE,
        outline=PADDLE_EDGE,
        width=6,
    )
    draw.ellipse(
        (blade_cx - 48, blade_cy - 60, blade_cx + 48, blade_cy + 60),
        outline=SUIT_LIGHT,
        width=3,
    )


def draw_leg_stub(draw: ImageDraw.ImageDraw) -> None:
    # Subtle leg hint at bottom to break roundness
    draw.rectangle((CENTER - 32, 348, CENTER + 32, 378), fill=SUIT_DARK, outline=INK, width=2)
    draw.rectangle((CENTER - 18, 378, CENTER + 18, 398), fill=SUIT_MID, outline=INK, width=2)


def build_sprite() -> Image.Image:
    base = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    soft_shadow(base, (CENTER - 140, 360, CENTER + 140, 420), blur=14)
    draw = ImageDraw.Draw(base, "RGBA")
    draw_leg_stub(draw)
    draw_torso(draw)
    left_hand, right_hand = draw_arms(draw)
    draw_weapons(draw, left_hand, right_hand)
    draw_head(draw)
    return base


def main() -> None:
    sprite = build_sprite()
    sprite.save("boss_stage8.png")


if __name__ == "__main__":
    main()
