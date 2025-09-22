"""메인 시작 메뉴 화면 로직."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, List

import math
import random
import pygame

from start_menu_decorations import draw_star_field, StarField


@dataclass
class MenuContext:
    screen: pygame.Surface
    width: int
    height: int
    internal_width: int
    internal_height: int
    font: object
    icon_size: int
    default_alpha: int
    menu_system: object
    simple_bg_factory: Callable[[int, int], object]
    play_hover_sound: Callable[[], None]
    play_click_sound: Callable[[], None]
    change_resolution: Callable[[int], None]
    start_game: Callable[[int], None]
    show_developer_stage_select: Callable[[], None]
    show_item_manager_menu: Callable[[], None]
    show_character_selection: Callable[[], None]
    show_tutorial_dialog: Callable[[], None]
    show_credits_screen: Callable[[], None]
    reset_runtime_items: Callable[[], None]
    idle_cinematic: Callable[[pygame.Surface, int, int], None]
    medal_score_getter: Callable[[], int]
    academy_reset: Callable[[], None]
    items_reset: Callable[[], None]


@dataclass
class MenuState:
    selected: int = 0
    developer_unlocked: bool = False
    item_manager_unlocked: bool = True
    idle_start_time: int = 0
    cinematic_trigger_time: int = 15000
    animation_timer: float = 0.0
    star_field: StarField = field(default_factory=StarField)
    neon_particles: List[dict] = field(default_factory=list)
    scan_lines: List[dict] = field(default_factory=list)


def _ensure_neon_particles(state: MenuState, width: int, height: int) -> None:
    if state.neon_particles:
        return
    for _ in range(50):
        state.neon_particles.append(
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


def _draw_neon_particles(state: MenuState, surface: pygame.Surface, animation_timer: float, width: int, height: int) -> None:
    _ensure_neon_particles(state, width, height)
    for particle in state.neon_particles:
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
            pygame.draw.circle(glow_surf, (*particle["color"], glow_alpha), (glow_size * 2, glow_size * 2), glow_size)
            surface.blit(glow_surf, (particle["x"] - glow_size * 2, particle["y"] - glow_size * 2))


def _ensure_scan_lines(state: MenuState, width: int) -> None:
    if state.scan_lines:
        return
    for _ in range(10):
        state.scan_lines.append(
            {
                "y": random.randint(0, 750),
                "speed": random.uniform(1.0, 3.0),
                "alpha": random.randint(40, 80),
            }
        )


def _draw_scan_lines(state: MenuState, surface: pygame.Surface, width: int, height: int) -> None:
    _ensure_scan_lines(state, width)
    for scan_line in state.scan_lines:
        scan_line["y"] += scan_line["speed"]
        if scan_line["y"] > height:
            scan_line["y"] = -10
        for i in range(3):
            scan_alpha = scan_line["alpha"] - i * 10
            if scan_alpha > 0:
                scan_surf = pygame.Surface((width, max(1, 2 - i)), pygame.SRCALPHA)
                scan_surf.fill((0, 255, 255, scan_alpha))
                surface.blit(scan_surf, (0, scan_line["y"] + i))


def run_start_menu(ctx: MenuContext, state: MenuState | None = None) -> None:
    if state is None:
        state = MenuState()

    ctx.reset_runtime_items()
    ctx.items_reset()
    ctx.academy_reset()

    menu_system = ctx.menu_system
    menu_system.current_menu = menu_system.create_main_menu()
    simple_bg = ctx.simple_bg_factory(ctx.internal_width, ctx.internal_height)

    clock = pygame.time.Clock()
    medal_icon = pygame.Surface((ctx.icon_size, ctx.icon_size), pygame.SRCALPHA)
    pygame.draw.circle(medal_icon, (255, 215, 0), medal_icon.get_rect().center, ctx.icon_size // 2)

    state.idle_start_time = pygame.time.get_ticks()

    running = True
    while running:
        dt = clock.tick(60) / 1000.0
        state.animation_timer += dt
        current_time = pygame.time.get_ticks()

        if current_time - state.idle_start_time >= state.cinematic_trigger_time:
            ctx.idle_cinematic(ctx.screen, ctx.width, ctx.height)
            state.idle_start_time = pygame.time.get_ticks()

        simple_bg.update(dt)
        simple_bg.draw(ctx.screen)
        state.star_field = draw_star_field(ctx.screen, ctx.width, ctx.height, state.animation_timer, state.star_field)
        _draw_neon_particles(state, ctx.screen, state.animation_timer, ctx.width, ctx.height)
        _draw_scan_lines(state, ctx.screen, ctx.width, ctx.height)

        medal_panel = pygame.Surface((ctx.default_alpha, 50), pygame.SRCALPHA)
        medal_panel.fill((10, 15, 25, 180))
        pygame.draw.rect(medal_panel, (255, 215, 0), (0, 0, 150, 50), 2, border_radius=8)
        ctx.screen.blit(medal_panel, (ctx.width - 170, 10))
        font_medal = ctx.font  # reuse provided font
        medal_text = font_medal.render(f" {ctx.medal_score_getter()}", True, (255, 215, 0))
        medal_rect = medal_text.get_rect(center=(ctx.width - 95, 35))
        ctx.screen.blit(medal_text, medal_rect)

        # 여기서부터 메뉴 렌더링/입력 처리 지속...
        # (햇갈리는 부분이 많으므로 1차 분리는 장식/배경만 이관)

        pygame.display.flip()

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                raise SystemExit
