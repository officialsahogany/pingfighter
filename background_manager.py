"""배경 이미지 로딩 및 폴백 생성 유틸."""

from __future__ import annotations

import math
import random
from dataclasses import dataclass
from typing import Callable, Optional

import pygame


@dataclass
class BackgroundFactory:
    resource_path: Callable[[str], str]
    animated_stage1: Callable[[str], object]
    animated_stage2: Callable[[str], object]
    animated_stage3: Callable[[], object]
    animated_stage4: Callable[[], object]
    animated_stage5: Callable[[], object]
    animated_stage6: Callable[[int, int], object]
    animated_stage7: Optional[Callable[[int, int], object]] = None
    animated_stage8: Optional[Callable[[int, int], object]] = None


@dataclass
class StageBackgrounds:
    stage1: pygame.Surface
    stage2: pygame.Surface
    stage3: pygame.Surface
    stage4: pygame.Surface
    stage5: pygame.Surface
    stage6: pygame.Surface
    stage7: pygame.Surface
    stage8: pygame.Surface
    animated_bg: Optional[object]
    animated_bg_stage2: Optional[object]
    animated_bg_stage3: Optional[object]
    animated_bg_stage4: Optional[object]
    animated_bg_stage5: Optional[object]
    animated_bg_stage6: Optional[object]
    animated_bg_stage7: Optional[object]
    animated_bg_stage8: Optional[object]


def _scaled_surface(surface: pygame.Surface, width: int, height: int) -> pygame.Surface:
    return pygame.transform.scale(surface, (width, height))


def _fallback_stage_surface(width: int, height: int, palette: Callable[[float], tuple]) -> pygame.Surface:
    surface = pygame.Surface((width, height))
    for y in range(height):
        surface.fill(palette(y / height), rect=pygame.Rect(0, y, width, 1))
    return surface


def load_stage_backgrounds(
    *,
    width: int,
    height: int,
    tile_size: int,
    factories: BackgroundFactory,
) -> StageBackgrounds:
    rp = factories.resource_path

    try:
        stage1 = pygame.image.load(rp("stage1_field.png")).convert()
        stage1 = _scaled_surface(stage1, width, height)
        border = 10
        top_tile = stage1.subsurface((0, border, width, border)).copy()
        stage1.blit(top_tile, (0, 0))
        bottom_tile = stage1.subsurface((0, height - border * 2, width, border)).copy()
        stage1.blit(bottom_tile, (0, height - border))
        left_tile = stage1.subsurface((border, 0, border, height)).copy()
        stage1.blit(left_tile, (0, 0))
        right_tile = stage1.subsurface((width - border * 2, 0, border, height)).copy()
        stage1.blit(right_tile, (width - border, 0))
        animated_bg = factories.animated_stage1("stage1_field.png")
    except Exception:
        stage1 = pygame.Surface((width, height))
        for y in range(height):
            ratio = y / height
            color = (10 + int(ratio * 20), 50 + int(ratio * 50), 20 + int(ratio * 30))
            pygame.draw.line(stage1, color, (0, y), (width, y))
        for x in range(0, width, tile_size):
            pygame.draw.line(stage1, (0, 150, 100, tile_size), (x, 0), (x, height))
        for y in range(0, height, tile_size):
            pygame.draw.line(stage1, (0, 150, 100, tile_size), (0, y), (width, y))
        animated_bg = None

    try:
        stage2 = pygame.image.load(rp("stage2_field.png")).convert()
        stage2 = _scaled_surface(stage2, width, height)
        animated_bg_stage2 = factories.animated_stage2("stage2_field.png")
    except Exception:
        stage2 = pygame.Surface((width, height))
        animated_bg_stage2 = None
        for y in range(height):
            ratio = y / height
            r = int(5 + ratio * 15)
            g = int(10 + ratio * 30)
            b = int(40 + ratio * 60)
            pygame.draw.line(stage2, (r, g, b), (0, y), (width, y))
        for y in range(0, height, 30):
            wave_color = (0, 100, 200, 40)
            for x in range(width):
                wave_y = y + math.sin(x * 0.02) * 10
                if 0 <= wave_y < height:
                    pygame.draw.circle(stage2, wave_color, (x, int(wave_y)), 2)

    try:
        stage3 = pygame.image.load(rp("stage3_field.png")).convert()
        stage3 = _scaled_surface(stage3, width, height)
        animated_bg_stage3 = factories.animated_stage3()
    except Exception:
        stage3 = pygame.Surface((width, height))
        animated_bg_stage3 = None
        for y in range(height):
            ratio = y / height
            r = int(80 + ratio * 40)
            g = int(10 + ratio * 30)
            b = int(80 + ratio * 40)
            pygame.draw.line(stage3, (r, g, b), (0, y), (width, y))
        for x in range(0, width, tile_size):
            for y in range(0, height, tile_size):
                pygame.draw.rect(stage3, (255, 0, 128, 30), (x, y, 45, 45), 1)

    try:
        animated_bg_stage4 = factories.animated_stage4()
        stage4 = pygame.Surface((width, height))
        animated_bg_stage4.draw(stage4)
    except Exception:
        stage4 = pygame.Surface((width, height))
        animated_bg_stage4 = None
        for y in range(height):
            ratio = y / height
            r = int(60 + ratio * 60)
            g = int(50 + ratio * 40)
            b = int(20 + ratio * 20)
            pygame.draw.line(stage4, (r, g, b), (0, y), (width, y))
        for x in range(0, width, 60):
            for y in range(0, height, 52):
                points = []
                for i in range(6):
                    angle = math.radians(60 * i)
                    px = x + 25 * math.cos(angle)
                    py = y + 25 * math.sin(angle)
                    points.append((px, py))
                pygame.draw.polygon(stage4, (255, 215, 0, 20), points, 1)

    try:
        stage5 = pygame.image.load(rp("stage5_field.png")).convert()
        stage5 = _scaled_surface(stage5, width, height)
        animated_bg_stage5 = factories.animated_stage5()
    except Exception:
        stage5 = pygame.Surface((width, height))
        animated_bg_stage5 = None
        for y in range(height):
            ratio = y / height
            r = int(100 + ratio * 55)
            g = int(20 + ratio * 20)
            b = int(0 + ratio * 10)
            pygame.draw.line(stage5, (r, g, b), (0, y), (width, y))
        for _ in range(30):
            flame_x = random.randint(0, width)
            flame_y = random.randint(height // 2, height)
            flame_size = random.randint(20, 40)
            for i in range(flame_size, 0, -5):
                color = (255, max(0, 100 - i * 2), 0)
                pygame.draw.circle(stage5, color, (flame_x, flame_y), i)

    try:
        stage6 = pygame.image.load(rp("stage6_field.png")).convert()
        stage6 = _scaled_surface(stage6, width, height)
        animated_bg_stage6 = factories.animated_stage6(width, height)
    except Exception:
        stage6 = pygame.Surface((width, height))
        animated_bg_stage6 = factories.animated_stage6(width, height)
        for y in range(height):
            depth_factor = y / height
            red = int(0 + 30 * depth_factor)
            green = int(10 + 20 * depth_factor)
            blue = int(25 + 35 * depth_factor)
            pygame.draw.line(stage6, (red, green, blue), (0, y), (width, y))

    try:
        stage7 = pygame.image.load(rp("stage7_field.png")).convert()
        stage7 = _scaled_surface(stage7, width, height)
    except Exception:
        stage7 = pygame.Surface((width, height))
        for y in range(height):
            ratio = y / max(1, height - 1)
            base = 200 - int(ratio * 40)
            pygame.draw.line(stage7, (base, base + 10, 255), (0, y), (width, y))

    animated_bg_stage7 = None
    if factories.animated_stage7 is not None:
        try:
            animated_bg_stage7 = factories.animated_stage7(width, height)
        except Exception:
            animated_bg_stage7 = None

    # Stage 8: 닌자 저택 배경
    try:
        stage8 = pygame.image.load(rp("stage8_field.png")).convert()
        stage8 = _scaled_surface(stage8, width, height)
    except Exception:
        # 폴백: 어두운 일본풍 배경
        stage8 = pygame.Surface((width, height))
        for y in range(height):
            ratio = y / height
            r = int(15 + ratio * 20)
            g = int(12 + ratio * 18)
            b = int(18 + ratio * 15)
            pygame.draw.line(stage8, (r, g, b), (0, y), (width, y))
        # 스타디움 라인
        center_y = height // 2
        pygame.draw.line(stage8, (100, 40, 40), (0, center_y), (width, center_y), 2)
        pygame.draw.circle(stage8, (100, 40, 40), (width // 2, center_y), 80, 3)

    animated_bg_stage8 = None
    if factories.animated_stage8 is not None:
        try:
            animated_bg_stage8 = factories.animated_stage8(width, height)
        except Exception:
            animated_bg_stage8 = None

    return StageBackgrounds(
        stage1=stage1,
        stage2=stage2,
        stage3=stage3,
        stage4=stage4,
        stage5=stage5,
        stage6=stage6,
        stage7=stage7,
        stage8=stage8,
        animated_bg=animated_bg,
        animated_bg_stage2=animated_bg_stage2,
        animated_bg_stage3=animated_bg_stage3,
        animated_bg_stage4=animated_bg_stage4,
        animated_bg_stage5=animated_bg_stage5,
        animated_bg_stage6=animated_bg_stage6,
        animated_bg_stage7=animated_bg_stage7,
        animated_bg_stage8=animated_bg_stage8,
    )
