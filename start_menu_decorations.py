"""시작 메뉴 장식(별 등)을 관리하는 유틸."""

from __future__ import annotations

from dataclasses import dataclass, field
import math
import random
import pygame


@dataclass
class StarField:
    stars: list = field(default_factory=list)
    count: int = 100

    def ensure_initialized(self, width: int, height: int) -> None:
        if self.stars:
            return
        for _ in range(self.count):
            self.stars.append(
                {
                    "x": random.randint(0, width),
                    "y": random.randint(0, height),
                    "size": random.uniform(0.5, 2.0),
                    "twinkle": random.uniform(0, math.pi * 2),
                }
            )

    def update_and_draw(self, surface: pygame.Surface, animation_timer: float) -> None:
        for star in self.stars:
            twinkle = abs(math.sin(star["twinkle"] + animation_timer * 0.05))
            star_alpha = int(twinkle * 100)
            star_color = (255, 255, 255, star_alpha)
            size = int(star["size"] * 4)
            star_surf = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.circle(
                star_surf,
                star_color,
                (size // 2, size // 2),
                max(1, int(star["size"])),
            )
            surface.blit(star_surf, (star["x"] - star["size"] * 2, star["y"] - star["size"] * 2))


def draw_star_field(surface: pygame.Surface, width: int, height: int, animation_timer: float, star_field: StarField | None = None) -> StarField:
    if star_field is None:
        star_field = StarField()
    star_field.ensure_initialized(width, height)
    star_field.update_and_draw(surface, animation_timer)
    return star_field
