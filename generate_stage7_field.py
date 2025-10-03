"""Stage 7(테트리서) 맵 배경 생성 스크립트.

고전 테트리스 UI 감성을 살린 전자식 경기장 배경을 생성한다.
실행하면 600x750 사이즈의 `stage7_field.png`를 덮어쓴다.
"""

from __future__ import annotations

from pathlib import Path
from typing import Iterable, Sequence, Tuple

from PIL import Image, ImageDraw, ImageFont

WIDTH = 600
HEIGHT = 750
OUTPUT_PATH = Path(__file__).resolve().parent / "stage7_field.png"

TOP_COLOR = (62, 130, 210)
MIDDLE_COLOR = (88, 162, 240)
BOTTOM_COLOR = (18, 48, 98)
SIDE_GLOW_COLOR = (74, 148, 226, 82)
GRID_PRIMARY_COLOR = (42, 88, 142, 32)
GRID_SECONDARY_COLOR = (28, 64, 108, 18)
PANEL_BORDER_COLOR = (108, 168, 240)
PANEL_FILL_TOP = (46, 94, 156, 248)
PANEL_FILL_BOTTOM = (32, 66, 120, 236)
INNER_BORDER_COLOR = (18, 44, 86, 160)
LINE_COLOR = (182, 236, 255)
LINE_GLOW_COLOR = (64, 150, 240, 95)

BLOCK_COLORS: Sequence[Tuple[int, int, int]] = (
    (84, 188, 255),  # I
    (94, 228, 198),  # S
    (248, 158, 90),  # L
    (196, 148, 244),  # T
    (255, 122, 160),  # Z
)

FONT_PATH = Path(__file__).resolve().parent / "NeoDunggeunmoPro.ttf"
try:
    FONT_LABEL = ImageFont.truetype(str(FONT_PATH), 18)
    FONT_DIGIT = ImageFont.truetype(str(FONT_PATH), 24)
    FONT_TINY = ImageFont.truetype(str(FONT_PATH), 14)
except OSError:
    fallback_font = ImageFont.load_default()
    FONT_LABEL = FONT_DIGIT = FONT_TINY = fallback_font

TETRIMINO_SHAPES = {
    "T": [(0, 1), (1, 0), (1, 1), (2, 1)],
    "J": [(0, 0), (0, 1), (1, 1), (2, 1)],
    "I": [(0, 1), (1, 1), (2, 1), (3, 1)],
    "S": [(0, 1), (1, 1), (1, 0), (2, 0)],
}


def _clamp(value: int, low: int = 0, high: int = 255) -> int:
    return max(low, min(high, value))


def _lerp(start: int, end: int, t: float) -> int:
    return int(round(start + (end - start) * t))


def _lerp_color(c1: Sequence[int], c2: Sequence[int], t: float) -> Tuple[int, int, int]:
    return tuple(_lerp(a, b, t) for a, b in zip(c1, c2))


def _text_size(font: ImageFont.FreeTypeFont | ImageFont.ImageFont, text: str) -> Tuple[int, int]:
    if hasattr(font, "getbbox"):
        bbox = font.getbbox(text)
        return bbox[2] - bbox[0], bbox[3] - bbox[1]
    return font.getsize(text)


def _draw_gradient(image: Image.Image) -> None:
    pixels = image.load()
    center_top = HEIGHT * 0.38
    center_bottom = HEIGHT * 0.64
    for y in range(HEIGHT):
        ratio = y / (HEIGHT - 1)
        base = _lerp_color(TOP_COLOR, BOTTOM_COLOR, ratio)
        glow_top = max(0.0, 1.0 - ((y - center_top) / (HEIGHT * 0.42)) ** 2)
        glow_bottom = max(0.0, 1.0 - ((y - center_bottom) / (HEIGHT * 0.55)) ** 2)
        highlight = int(glow_top * 36 + glow_bottom * 24)
        for x in range(WIDTH):
            lateral = abs(x - WIDTH / 2) / (WIDTH / 2)
            shadow = int(lateral ** 1.9 * 60)
            r = _clamp(base[0] + highlight - shadow)
            g = _clamp(base[1] + highlight - shadow)
            b = _clamp(base[2] + int(highlight * 0.6) - int(shadow * 0.6))
            pixels[x, y] = (r, g, b, 255)


def _add_vignette(image: Image.Image) -> None:
    vignette = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    pixels = vignette.load()
    cx = WIDTH / 2
    cy = HEIGHT / 2
    max_dist = (cx**2 + cy**2) ** 0.5
    for y in range(HEIGHT):
        for x in range(WIDTH):
            dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            t = dist / max_dist
            alpha = int(max(0.0, t ** 1.6 - 0.25) * 165)
            if alpha > 0:
                pixels[x, y] = (6, 14, 32, alpha)
    image.alpha_composite(vignette)


def _draw_pixel_grid(image: Image.Image) -> None:
    grid = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(grid)
    for y in range(0, HEIGHT, 4):
        color = GRID_PRIMARY_COLOR if y % 8 == 0 else GRID_SECONDARY_COLOR
        draw.line((0, y, WIDTH, y), fill=color, width=1)
    for x in range(0, WIDTH, 6):
        color = GRID_PRIMARY_COLOR if x % 12 == 0 else GRID_SECONDARY_COLOR
        draw.line((x, 0, x, HEIGHT), fill=color, width=1)
    image.alpha_composite(grid)


def _draw_side_glow(image: Image.Image) -> None:
    glow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    for i in range(10):
        inset = i * 5
        alpha = max(0, SIDE_GLOW_COLOR[3] - i * 7)
        color = (*SIDE_GLOW_COLOR[:3], alpha)
        draw.rounded_rectangle(
            (inset + 6, inset + 48, WIDTH - inset - 6, HEIGHT - inset - 48),
            radius=max(12, 36 - i * 2),
            outline=color,
            width=2,
        )
    image.alpha_composite(glow)


def _draw_gradient_rect(draw: ImageDraw.ImageDraw, rect: Tuple[int, int, int, int], top_color: Tuple[int, int, int], bottom_color: Tuple[int, int, int], *, alpha: int = 255) -> None:
    x0, y0, x1, y1 = rect
    height = max(1, y1 - y0)
    for i in range(height):
        ratio = i / (height - 1)
        color = _lerp_color(top_color, bottom_color, ratio)
        draw.line((x0, y0 + i, x1, y0 + i), fill=(*color, alpha))


def _draw_module_box(draw: ImageDraw.ImageDraw, rect: Tuple[int, int, int, int], label: str) -> Tuple[int, int, int, int]:
    x0, y0, x1, y1 = rect
    _draw_gradient_rect(draw, rect, (38, 82, 142), (18, 46, 98), alpha=235)
    draw.rounded_rectangle(rect, radius=10, outline=(120, 190, 255), width=2)
    label_w, label_h = _text_size(FONT_TINY, label)
    label_x = x0 + (x1 - x0 - label_w) // 2
    draw.text((label_x, y0 + 6), label, font=FONT_TINY, fill=(208, 232, 255))
    return (x0 + 10, y0 + label_h + 14, x1 - 10, y1 - 12)


def _draw_scoreboard(draw: ImageDraw.ImageDraw, rect: Tuple[int, int, int, int]) -> None:
    _draw_gradient_rect(draw, rect, (28, 68, 132), (14, 36, 84), alpha=236)
    draw.rounded_rectangle(rect, radius=12, outline=(110, 176, 250), width=2)
    inner_rect = (rect[0] + 8, rect[1] + 8, rect[2] - 8, rect[3] - 8)
    draw.rounded_rectangle(inner_rect, radius=8, outline=(40, 88, 150, 120), width=1)
    labels = ["SCORE", "LEVEL", "LINES"]
    values = ["000268", "07", "18"]
    for idx, (label, value) in enumerate(zip(labels, values)):
        y = rect[1] + 8 + idx * 16
        draw.text((rect[0] + 16, y), label, font=FONT_TINY, fill=(198, 224, 255))
        font = FONT_DIGIT if idx == 0 else FONT_LABEL
        value_w, value_h = _text_size(font, value)
        draw.text((rect[2] - 18 - value_w, y - 2), value, font=font, fill=(132, 212, 255))
        if idx < len(labels) - 1:
            draw.line((rect[0] + 12, y + 18, rect[2] - 12, y + 18), fill=(54, 108, 172, 160), width=1)
    # 하단 LED 바
    led_y = rect[3] - 10
    for i in range(14):
        led_x = rect[0] + 18 + i * 18
        led_color = (70 + i * 6, 140 + i * 4 % 30, 240, 190)
        draw.rounded_rectangle((led_x, led_y, led_x + 8, led_y + 4), radius=2, fill=led_color)


def _draw_status_panel(draw: ImageDraw.ImageDraw, rect: Tuple[int, int, int, int]) -> None:
    _draw_gradient_rect(draw, rect, (24, 64, 126), (16, 38, 86), alpha=232)
    draw.rounded_rectangle(rect, radius=10, outline=(120, 190, 255), width=2)
    status_label = "ARENA STABILITY"
    status_value = "97%"
    secondary = "BONUS READY"
    label_w, _ = _text_size(FONT_TINY, status_label)
    draw.text((rect[0] + 16, rect[1] + 8), status_label, font=FONT_TINY, fill=(198, 224, 255))
    val_w, _ = _text_size(FONT_DIGIT, status_value)
    draw.text((rect[2] - 18 - val_w, rect[1] + 4), status_value, font=FONT_DIGIT, fill=(138, 216, 255))
    draw.text((rect[0] + 16, rect[1] + 26), secondary, font=FONT_TINY, fill=(166, 210, 255))
    led_y = rect[1] + 36
    for i in range(9):
        led_x = rect[0] + 20 + i * 36
        color = (52 + i * 6, 176, 255, 180)
        draw.ellipse((led_x, led_y, led_x + 6, led_y + 6), fill=color, outline=(12, 42, 92))


def _draw_tetrimino(draw: ImageDraw.ImageDraw, origin: Tuple[int, int], cells: Iterable[Tuple[int, int]], color: Tuple[int, int, int], block: int = 26) -> None:
    ox, oy = origin
    for cx, cy in cells:
        x0 = ox + cx * block
        y0 = oy + cy * block
        rect = (x0, y0, x0 + block, y0 + block)
        radius = max(3, block // 3)
        draw.rounded_rectangle(rect, radius=radius, fill=color + (235,), outline=(255, 255, 255), width=max(1, block // 8))
        inner = (x0 + block * 0.28, y0 + block * 0.28, x0 + block * 0.72, y0 + block * 0.72)
        draw.rounded_rectangle(inner, radius=max(2, block // 4), outline=(255, 255, 255, 90), width=1)


def _draw_hold_next(draw: ImageDraw.ImageDraw, hold_rect: Tuple[int, int, int, int], next_main: Tuple[int, int, int, int], next_sub: Tuple[int, int, int, int]) -> None:
    hold_inner = _draw_module_box(draw, hold_rect, "HOLD")
    hold_piece_origin = (hold_inner[0] + 6, hold_inner[1] + 12)
    _draw_tetrimino(draw, hold_piece_origin, TETRIMINO_SHAPES["T"], BLOCK_COLORS[3], block=16)

    next_inner_main = _draw_module_box(draw, next_main, "NEXT")
    nm_origin = (next_inner_main[0] + 4, next_inner_main[1] + 8)
    _draw_tetrimino(draw, nm_origin, TETRIMINO_SHAPES["J"], BLOCK_COLORS[2], block=14)

    next_inner_sub = _draw_module_box(draw, next_sub, "QUEUE")
    ns_origin = (next_inner_sub[0] + 2, next_inner_sub[1] + 6)
    _draw_tetrimino(draw, ns_origin, TETRIMINO_SHAPES["I"], BLOCK_COLORS[0], block=12)
    ghost_color = (116, 210, 244, 120)
    draw.rectangle((next_inner_sub[0], next_inner_sub[3] - 14, next_inner_sub[2], next_inner_sub[3] - 10), fill=ghost_color)


def _draw_playfield_panel(image: Image.Image) -> None:
    panel = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(panel)
    padding_x = 96
    padding_y_top = 118
    padding_y_bottom = 96
    left = padding_x
    top = padding_y_top
    right = WIDTH - padding_x
    bottom = HEIGHT - padding_y_bottom

    for i in range(bottom - top):
        ratio = i / max(1, (bottom - top - 1))
        color = _lerp_color(PANEL_FILL_TOP[:3], PANEL_FILL_BOTTOM[:3], ratio)
        draw.line((left, top + i, right, top + i), fill=(*color, PANEL_FILL_BOTTOM[3]))

    draw.rounded_rectangle((left, top, right, bottom), radius=28, outline=PANEL_BORDER_COLOR, width=3)
    draw.rounded_rectangle((left + 6, top + 6, right - 6, bottom - 6), radius=22, outline=INNER_BORDER_COLOR, width=2)

    # 세부 스트라이프 및 포인트 라이트
    for idx in range(1, 4):
        stripe_x = left + idx * ((right - left) // 4)
        draw.line((stripe_x, top + 16, stripe_x, bottom - 16), fill=(34, 96, 162, 110), width=1)
    for offset in range(0, right - left, 48):
        draw.line((left + offset, top + 10, left + offset + 12, top + 10), fill=(150, 210, 255, 130), width=1)
        draw.line((left + offset, bottom - 10, left + offset + 12, bottom - 10), fill=(90, 160, 230, 130), width=1)

    scoreboard_rect = (left + 60, top - 72, right - 60, top - 16)
    _draw_scoreboard(draw, scoreboard_rect)

    hold_rect = (left - 74, top + 24, left - 18, top + 168)
    next_main_rect = (right + 18, top + 24, right + 74, top + 166)
    next_sub_rect = (right + 18, top + 176, right + 74, top + 236)
    _draw_hold_next(draw, hold_rect, next_main_rect, next_sub_rect)

    status_rect = (left + 48, bottom + 28, right - 48, bottom + 64)
    _draw_status_panel(draw, status_rect)

    for y in range(top + 28, bottom - 20, 48):
        draw.line((left - 10, y, left - 4, y), fill=(132, 208, 255, 200), width=2)
        draw.line((right + 4, y, right + 10, y), fill=(132, 208, 255, 200), width=2)

    image.alpha_composite(panel)


def _draw_center_lines(image: Image.Image) -> None:
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    center_y = HEIGHT // 2
    center_x = WIDTH // 2
    radius = 96

    glow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for spread in range(7):
        alpha = max(0, LINE_GLOW_COLOR[3] - spread * 12)
        color = (LINE_GLOW_COLOR[0], LINE_GLOW_COLOR[1], LINE_GLOW_COLOR[2], alpha)
        glow_draw.line((0, center_y - spread, center_x - radius - 4, center_y - spread), fill=color)
        glow_draw.line((center_x + radius + 4, center_y - spread, WIDTH, center_y - spread), fill=color)
        glow_draw.ellipse(
            (
                center_x - radius - spread,
                center_y - radius - spread,
                center_x + radius + spread,
                center_y + radius + spread,
            ),
            outline=color,
            width=1,
        )
    image.alpha_composite(glow)

    shadow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(
        (center_x - radius - 6, center_y - radius - 6, center_x + radius + 6, center_y + radius + 6),
        outline=(8, 18, 38, 80),
        width=6,
    )
    image.alpha_composite(shadow)

    draw.line((0, center_y, center_x - radius, center_y), fill=LINE_COLOR, width=4)
    draw.line((center_x + radius, center_y, WIDTH, center_y), fill=LINE_COLOR, width=4)
    draw.ellipse(
        (center_x - radius, center_y - radius, center_x + radius, center_y + radius),
        outline=LINE_COLOR,
        width=4,
    )

    image.alpha_composite(overlay)


def _add_corner_details(image: Image.Image) -> None:
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    accent_color = (94, 168, 240, 140)
    accent_shadow = (18, 42, 92, 150)
    corner_shapes = [
        ((34, 118, 152, 164), 18),
        ((WIDTH - 152, 118, WIDTH - 34, 164), 18),
        ((48, HEIGHT - 186, 164, HEIGHT - 138), 20),
        ((WIDTH - 164, HEIGHT - 186, WIDTH - 48, HEIGHT - 138), 20),
    ]
    for rect, radius in corner_shapes:
        draw.rounded_rectangle(rect, radius=radius, fill=accent_shadow)
        inset = (rect[0] + 4, rect[1] + 4, rect[2] - 4, rect[3] - 4)
        draw.rounded_rectangle(inset, radius=max(6, radius - 6), outline=(130, 210, 255, 180), width=2)
        draw.rounded_rectangle((inset[0] + 4, inset[1] + 4, inset[2] - 4, inset[3] - 4), radius=max(4, radius - 8), fill=accent_color)
    image.alpha_composite(overlay)


def create_stage7_background() -> Image.Image:
    base = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    _draw_gradient(base)
    _add_vignette(base)
    _draw_pixel_grid(base)
    _draw_side_glow(base)
    _draw_playfield_panel(base)
    _draw_center_lines(base)
    _add_corner_details(base)
    return base


def main() -> None:
    image = create_stage7_background()
    image.save(OUTPUT_PATH)
    print(f"Stage 7 배경이 '{OUTPUT_PATH.name}' 파일로 생성되었습니다.")


if __name__ == "__main__":
    main()
