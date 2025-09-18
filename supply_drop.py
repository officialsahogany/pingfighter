from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Callable, Sequence

import pygame


@dataclass
class SupplyDropConfig:
    """Configuration values for the supply drop system."""

    persist_across_rounds: bool = True
    hold_required: int = 60
    hold_threshold: int = 18
    gauge_cost: int = 350
    items: Sequence[str] = (
        "grenade",
        "molotov",
        "flare",
        "bazooka",
        "ak47",
        "ammo_box",
    )


@dataclass
class SupplyDropState:
    """Mutable state container for the supply drop system."""

    config: SupplyDropConfig = field(default_factory=SupplyDropConfig)
    active: bool = False
    aircraft: object | None = None
    items: list = field(default_factory=list)
    timer: int = 0
    radio_motion: bool = False
    radio_timer: int = 0
    hold_time: int = 0

    def reset(self) -> None:
        """Reset runtime state while preserving configuration."""
        self.active = False
        self.aircraft = None
        self.items.clear()
        self.timer = 0
        self.radio_motion = False
        self.radio_timer = 0
        self.hold_time = 0


def update_items(
    state: SupplyDropState,
    *,
    player_rect: pygame.Rect,
    width: int,
    height: int,
    activate_item: Callable[[str], None],
    proximity_debug: bool = False,
) -> None:
    """Update falling supply-drop items."""

    for item in state.items[:]:
        if not item["active"]:
            continue

        # 좌우 흔들림 + 기본 이동
        item["sway"] += 0.1
        base_vx = item.get("base_vx", item["vx"])
        if "base_vx" not in item:
            item["base_vx"] = base_vx
        item["vx"] = base_vx + math.sin(item["sway"]) * 0.3

        item["x"] += item["vx"]
        safe_margin = 32
        if item["x"] < safe_margin or item["x"] > width - safe_margin:
            item["x"] = max(safe_margin, min(width - safe_margin, item["x"]))
        item["y"] += item["vy"]
        item["rotation"] += 2

        # 화면 밖으로 떨어지면 제거
        if item["y"] > height + 50:
            state.items.remove(item)
            continue

        # 플레이어 충돌 검사
        item_rect = pygame.Rect(item["x"] - 24, item["y"] - 20, 48, 40)

        if proximity_debug:
            distance = abs(player_rect.centerx - item["x"]) + abs(player_rect.centery - item["y"])
            if distance < 100:
                print(
                    f"🔍 근접 감지: 플레이어({player_rect.centerx}, {player_rect.centery}) "
                    f"vs 아이템({item['x']}, {item['y']}) 거리:{distance}"
                )

        if player_rect.colliderect(item_rect):
            activate_item(item["name"])
            state.items.remove(item)


def draw_supply_item_icon(screen, item_name: str, x: int, y: int, rotation: float) -> None:
    """Render a single supply item icon."""

    box_width = 36
    box_height = 28
    main_color = (85, 90, 65)
    box_rect = pygame.Rect(x - box_width // 2, y - box_height // 2, box_width, box_height)
    pygame.draw.rect(screen, main_color, box_rect)

    border_color = (60, 65, 45)
    pygame.draw.rect(screen, border_color, box_rect, 3)

    lid_color = (100, 105, 80)
    lid_rect = pygame.Rect(x - box_width // 2, y - box_height // 2, box_width, 9)
    pygame.draw.rect(screen, lid_color, lid_rect)

    strap_color = (50, 50, 40)
    pygame.draw.rect(
        screen,
        strap_color,
        (x - box_width // 2 - 2, y - box_height // 2 + 3, 4, box_height - 6),
    )
    pygame.draw.rect(
        screen,
        strap_color,
        (x + box_width // 2 - 2, y - box_height // 2 + 3, 4, box_height - 6),
    )
    pygame.draw.rect(
        screen,
        strap_color,
        (x - box_width // 2 + 4, y - 2, box_width - 8, 4),
    )

    # 상자 중앙에 간단한 장식 (아이콘 느낌)
    pygame.draw.rect(
        screen,
        (120, 125, 95),
        (x - box_width // 2 + 6, y - 2, box_width - 12, 4),
    )
    pygame.draw.rect(
        screen,
        (140, 145, 110),
        (x - 6, y - box_height // 2 + 4, 12, 6),
    )


def draw_items(screen, state: SupplyDropState) -> None:
    """Draw all falling supply items."""

    for item in state.items:
        if not item["active"]:
            continue

        x, y = int(item["x"]), int(item["y"])

        parachute_color = (200, 200, 200)
        parachute_radius = 12
        pygame.draw.circle(screen, parachute_color, (x, y - 20), parachute_radius)
        pygame.draw.circle(screen, (150, 150, 150), (x, y - 20), parachute_radius, 2)
        pygame.draw.line(screen, (100, 100, 100), (x - 8, y - 8), (x - 4, y + 8), 1)
        pygame.draw.line(screen, (100, 100, 100), (x + 8, y - 8), (x + 4, y + 8), 1)
        pygame.draw.line(screen, (100, 100, 100), (x, y - 12), (x, y + 8), 1)

        draw_supply_item_icon(screen, item["name"], x, y, item["rotation"])


def draw_radio_motion(screen, state: SupplyDropState) -> None:
    """Draw the walkie-talkie activation animation."""

    if not state.radio_motion or state.radio_timer <= 0:
        state.radio_motion = False
        return

    overlay = pygame.Surface((WIDTH := screen.get_width(), HEIGHT := screen.get_height()), pygame.SRCALPHA)

    led_color = (0, 255, 0) if state.radio_timer % 10 < 5 else (0, 150, 0)
    pygame.draw.circle(overlay, (*led_color, 180), (WIDTH // 2, HEIGHT // 2 - 120), 6)

    signal_alpha = int(255 * (state.radio_timer / 30))
    for radius in (40, 70, 100):
        pygame.draw.circle(overlay, (0, 255, 0, signal_alpha), (WIDTH // 2, HEIGHT // 2 - 140), radius, 2)

    screen.blit(overlay, (0, 0))
