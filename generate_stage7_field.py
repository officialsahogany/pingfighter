"""Stage 7(테트리서) 맵 배경 생성 스크립트.

테트리스 조각을 모티브로 한 미니멀한 전자식 경기장을 구현한다.
실행하면 600x750 사이즈의 `stage7_field.png`를 생성한다.
"""

from __future__ import annotations

from pathlib import Path
from typing import Iterable, Sequence, Tuple

from PIL import Image, ImageDraw

WIDTH = 600
HEIGHT = 750
OUTPUT_PATH = Path(__file__).resolve().parent / "stage7_field.png"

TOP_COLOR = (190, 202, 230)
BOTTOM_COLOR = (156, 170, 210)
SIDE_GLOW_COLOR = (150, 168, 214, 70)
GRID_LINE_COLOR = (170, 185, 210, 110)
PANEL_BORDER_COLOR = (140, 152, 188)
PANEL_FILL_TOP = (188, 198, 226, 245)
PANEL_FILL_BOTTOM = (170, 184, 214, 240)
LINE_COLOR = (60, 82, 148)
LINE_GLOW_COLOR = (110, 138, 200, 60)

BLOCK_COLORS: Sequence[Tuple[int, int, int]] = (
    (115, 180, 255),  # I
    (128, 220, 200),  # Z
    (248, 196, 120),  # L
    (200, 164, 240),  # T
    (255, 148, 160),  # S
)


def _lerp(start: int, end: int, t: float) -> int:
    return int(round(start + (end - start) * t))


def _lerp_color(c1: Sequence[int], c2: Sequence[int], t: float) -> Tuple[int, int, int]:
    return tuple(_lerp(a, b, t) for a, b in zip(c1, c2))


def _draw_gradient(image: Image.Image) -> None:
    pixels = image.load()
    for y in range(HEIGHT):
        ratio = y / (HEIGHT - 1)
        base_color = _lerp_color(TOP_COLOR, BOTTOM_COLOR, ratio)
        for x in range(WIDTH):
            lateral = (abs(x - WIDTH / 2) / (WIDTH / 2)) ** 1.8
            shadow = int(14 * lateral)
            pixels[x, y] = (
                max(0, base_color[0] - shadow),
                max(0, base_color[1] - shadow),
                max(0, base_color[2] - shadow),
                255,
            )


def _draw_side_glow(image: Image.Image) -> None:
    glow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for i in range(12):
        inset = i * 4
        alpha = max(0, SIDE_GLOW_COLOR[3] - i * 6)
        color = (*SIDE_GLOW_COLOR[:3], alpha)
        glow_draw.rounded_rectangle(
            (inset, inset + 40, WIDTH - inset, HEIGHT - inset - 40),
            radius=40 - i,
            outline=color,
            width=2,
        )
    image.alpha_composite(glow)


def _draw_tetris_panel(image: Image.Image) -> None:
    panel = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(panel)
    padding_x = 90
    padding_y_top = 110
    padding_y_bottom = 90
    left = padding_x
    top = padding_y_top
    right = WIDTH - padding_x
    bottom = HEIGHT - padding_y_bottom

    # 그라데이션 패널
    for i in range(bottom - top):
        ratio = i / max(1, (bottom - top - 1))
        color = _lerp_color(PANEL_FILL_TOP[:3], PANEL_FILL_BOTTOM[:3], ratio)
        draw.line((left, top + i, right, top + i), fill=(*color, 235))

    draw.rounded_rectangle(
        (left, top, right, bottom),
        radius=28,
        outline=PANEL_BORDER_COLOR,
        width=3,
    )

    # 내부 그리드
    grid_spacing = 30
    for gx in range(left + grid_spacing, right, grid_spacing):
        draw.line((gx, top + 8, gx, bottom - 8), fill=GRID_LINE_COLOR, width=1)
    for gy in range(top + grid_spacing, bottom, grid_spacing):
        draw.line((left + 8, gy, right - 8, gy), fill=GRID_LINE_COLOR, width=1)

    # 윗부분 미니 헤더
    header_height = 40
    header_rect = (left - 40, top - 70, right + 40, top - 30)
    draw.rounded_rectangle(header_rect, radius=18, fill=(168, 178, 208, 215))
    draw.rounded_rectangle(header_rect, radius=18, outline=(148, 158, 188), width=2)

    # 아래 상태 표시 바
    footer_rect = (left - 30, bottom + 25, right + 30, bottom + 55)
    draw.rounded_rectangle(footer_rect, radius=16, fill=(176, 186, 212, 230))
    draw.rounded_rectangle(footer_rect, radius=16, outline=(150, 160, 186), width=2)

    image.alpha_composite(panel)


def _draw_tetrimino(draw: ImageDraw.ImageDraw, origin: Tuple[int, int], cells: Iterable[Tuple[int, int]], color: Tuple[int, int, int], block: int = 26) -> None:
    ox, oy = origin
    for cx, cy in cells:
        x0 = ox + cx * block
        y0 = oy + cy * block
        rect = (x0, y0, x0 + block, y0 + block)
        draw.rounded_rectangle(rect, radius=6, fill=color + (230,), outline=(255, 255, 255), width=2)
        inner = (x0 + 6, y0 + 6, x0 + block - 6, y0 + block - 6)
        highlight = tuple(min(255, int(c * 1.15)) for c in color)
        draw.rounded_rectangle(inner, radius=4, outline=highlight + (160,), width=1)


def _draw_tetris_pieces(image: Image.Image) -> None:
    # 더 이상 블록을 그리지 않음 (요청에 따라 바닥 장식 제거)


def _draw_center_lines(image: Image.Image) -> None:
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    center_y = HEIGHT // 2
    center_x = WIDTH // 2
    radius = 95

    # 라인 글로우
    glow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for spread in range(6):
        alpha = max(0, LINE_GLOW_COLOR[3] - spread * 10)
        if alpha <= 0:
            continue
        color = (LINE_GLOW_COLOR[0], LINE_GLOW_COLOR[1], LINE_GLOW_COLOR[2], alpha)
        glow_draw.line((0, center_y - spread, center_x - radius - 6, center_y - spread), fill=color, width=1)
        glow_draw.line((center_x + radius + 6, center_y - spread, WIDTH, center_y - spread), fill=color, width=1)
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

    line_width = 4
    draw.line((0, center_y, center_x - radius, center_y), fill=LINE_COLOR, width=line_width)
    draw.line((center_x + radius, center_y, WIDTH, center_y), fill=LINE_COLOR, width=line_width)
    draw.ellipse(
        (center_x - radius, center_y - radius, center_x + radius, center_y + radius),
        outline=LINE_COLOR,
        width=line_width,
    )

    image.alpha_composite(overlay)


def _add_corner_details(image: Image.Image) -> None:
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    accent_color = (170, 188, 226, 180)
    accent_shadow = (140, 155, 200, 90)

    corner_shapes = [
        ((36, 120, 140, 160), 16),
        ((WIDTH - 140, 120, WIDTH - 36, 160), 16),
        ((48, HEIGHT - 180, 160, HEIGHT - 140), 20),
        ((WIDTH - 160, HEIGHT - 180, WIDTH - 48, HEIGHT - 140), 20),
    ]

    for rect, radius in corner_shapes:
        draw.rounded_rectangle(rect, radius=radius, fill=accent_shadow)
        inset = (rect[0] + 4, rect[1] + 4, rect[2] - 4, rect[3] - 4)
        draw.rounded_rectangle(inset, radius=max(6, radius - 4), fill=accent_color)

    image.alpha_composite(overlay)


def create_stage7_background() -> Image.Image:
    base = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    _draw_gradient(base)
    _draw_side_glow(base)
    _draw_tetris_panel(base)
    _draw_center_lines(base)
    _add_corner_details(base)
    return base


def main() -> None:
    image = create_stage7_background()
    image.save(OUTPUT_PATH)
    print(f"Stage 7 배경이 '{OUTPUT_PATH.name}' 파일로 생성되었습니다.")


if __name__ == "__main__":
    main()
