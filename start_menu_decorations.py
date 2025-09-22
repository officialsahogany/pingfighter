"""시작 메뉴 장식(별/네온/스캔라인)을 관리하는 유틸."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import List

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


def draw_neon_particles(
    surface: pygame.Surface,
    width: int,
    height: int,
    animation_timer: float,
    particles: List[dict] | None = None,
) -> List[dict]:
    if particles is None:
        particles = []
    if not particles:
        for _ in range(50):
            particles.append(
                {
                    "x": random.randint(0, width),
                    "y": random.randint(0, height),
                    "vx": random.uniform(-0.5, 0.5),
                    "vy": random.uniform(-0.5, 0.5),
                    "alpha": random.randint(60, 120),
                    "size": random.randint(4, 8),
                    "color": (0, 200, 255),
                    "pulse_speed": random.uniform(1.0, 3.0),
                }
            )

    for particle in particles:
        particle["x"] += particle["vx"]
        particle["y"] += particle["vy"]
        if particle["x"] < 0 or particle["x"] > width:
            particle["vx"] *= -1
        if particle["y"] < 0 or particle["y"] > height:
            particle["vy"] *= -1
        pulse = abs(math.sin(animation_timer * particle["pulse_speed"]))
        current_alpha = int(particle["alpha"] * (0.5 + pulse * 0.5))
        for i in range(2):
            glow_size = particle["size"] + i * 2
            glow_alpha = current_alpha // (i + 1)
            glow_surf = pygame.Surface((glow_size * 4, glow_size * 4), pygame.SRCALPHA)
            pygame.draw.circle(
                glow_surf,
                (*particle["color"], glow_alpha),
                (glow_size * 2, glow_size * 2),
                glow_size,
            )
            surface.blit(glow_surf, (particle["x"] - glow_size * 2, particle["y"] - glow_size * 2))
    return particles


def draw_scan_lines(
    surface: pygame.Surface,
    width: int,
    height: int,
    scan_lines: List[dict] | None = None,
) -> List[dict]:
    if scan_lines is None:
        scan_lines = []
    if not scan_lines:
        for _ in range(10):
            scan_lines.append(
                {
                    "y": random.randint(0, height),
                    "speed": random.uniform(1.0, 3.0),
                    "alpha": random.randint(40, 80),
                }
            )

    for scan_line in scan_lines:
        scan_line["y"] += scan_line["speed"]
        if scan_line["y"] > height:
            scan_line["y"] = -10
        for i in range(3):
            scan_alpha = scan_line["alpha"] - i * 10
            if scan_alpha > 0:
                scan_surf = pygame.Surface((width, max(1, 2 - i)), pygame.SRCALPHA)
                scan_surf.fill((0, 255, 255, scan_alpha))
                surface.blit(scan_surf, (0, scan_line["y"] + i))
    return scan_lines
