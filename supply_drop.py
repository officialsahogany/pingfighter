from __future__ import annotations

import math
import random
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
        "net_gun",
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
        item_rect = pygame.Rect(item["x"] - 20, item["y"] - 15, 40, 30)

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

    box_width = 40
    box_height = 30
    main_color = (85, 90, 65)
    box_rect = pygame.Rect(x - box_width // 2, y - box_height // 2, box_width, box_height)
    pygame.draw.rect(screen, main_color, box_rect)

    # 상자 음영 효과
    shadow_color = (65, 70, 50)
    pygame.draw.rect(screen, shadow_color, (x - box_width // 2 + 2, y - box_height // 2 + 2, box_width - 2, box_height - 2))
    pygame.draw.rect(screen, main_color, (x - box_width // 2, y - box_height // 2, box_width - 2, box_height - 2))

    border_color = (60, 65, 45)
    pygame.draw.rect(screen, border_color, box_rect, 3)

    # 상자 뚜껑 디테일
    lid_color = (100, 105, 80)
    lid_rect = pygame.Rect(x - box_width // 2, y - box_height // 2, box_width, 10)
    pygame.draw.rect(screen, lid_color, lid_rect)
    pygame.draw.line(screen, (90, 95, 70), (x - box_width // 2, y - box_height // 2 + 10), (x + box_width // 2, y - box_height // 2 + 10), 2)

    # 금속 보강대
    strap_color = (50, 50, 40)
    strap_highlight = (70, 70, 60)
    # 왼쪽 보강대
    pygame.draw.rect(screen, strap_color, (x - box_width // 2 - 2, y - box_height // 2 + 3, 5, box_height - 6))
    pygame.draw.rect(screen, strap_highlight, (x - box_width // 2 - 2, y - box_height // 2 + 3, 3, box_height - 6))
    # 오른쪽 보강대
    pygame.draw.rect(screen, strap_color, (x + box_width // 2 - 3, y - box_height // 2 + 3, 5, box_height - 6))
    pygame.draw.rect(screen, strap_highlight, (x + box_width // 2 - 3, y - box_height // 2 + 3, 3, box_height - 6))
    # 가로 보강대
    pygame.draw.rect(screen, strap_color, (x - box_width // 2 + 4, y - 2, box_width - 8, 4))
    pygame.draw.rect(screen, strap_highlight, (x - box_width // 2 + 4, y - 2, box_width - 8, 2))

    # 고정 나사 디테일
    screw_color = (40, 40, 35)
    screw_positions = [
        (x - box_width // 2 + 3, y - box_height // 2 + 5),
        (x + box_width // 2 - 3, y - box_height // 2 + 5),
        (x - box_width // 2 + 3, y + box_height // 2 - 5),
        (x + box_width // 2 - 3, y + box_height // 2 - 5),
    ]
    for sx, sy in screw_positions:
        pygame.draw.circle(screen, screw_color, (int(sx), int(sy)), 2)
        pygame.draw.circle(screen, (60, 60, 55), (int(sx), int(sy)), 1)

    # 군용 마크 - 더 정교한 미군 스타일 엠블럼
    emblem_x = x
    emblem_y = y + 4
    
    # 원형 배경
    pygame.draw.circle(screen, (70, 75, 55), (emblem_x, emblem_y), 10)
    pygame.draw.circle(screen, (95, 100, 75), (emblem_x, emblem_y), 9)
    
    # 중앙 별 (더 정교하게)
    star_color = (180, 185, 150)
    star_outline = (60, 65, 45)
    outer_radius = 8
    inner_radius = 3
    points = []
    for i in range(10):
        angle = math.pi / 2 + i * math.pi / 5
        radius = outer_radius if i % 2 == 0 else inner_radius
        points.append((int(emblem_x + math.cos(angle) * radius), int(emblem_y + math.sin(angle) * radius)))
    
    # 별 그림자
    shadow_points = [(p[0] + 1, p[1] + 1) for p in points]
    pygame.draw.polygon(screen, (50, 55, 40), shadow_points)
    
    # 별 본체
    pygame.draw.polygon(screen, star_color, points)
    pygame.draw.polygon(screen, star_outline, points, 2)
    
    # 별 중앙에 작은 원
    pygame.draw.circle(screen, (160, 165, 130), (emblem_x, emblem_y), 2)
    pygame.draw.circle(screen, star_outline, (emblem_x, emblem_y), 2, 1)

    # 군용 텍스트 스타일 표시
    text_color = (110, 115, 90)
    # "US" 표시
    font_size = 6
    for i, char in enumerate("US"):
        char_x = x - box_width // 2 + 10 + i * 5
        char_y = y - box_height // 2 + 2
        if char == "U":
            pygame.draw.lines(screen, text_color, False, [(char_x, char_y), (char_x, char_y + 5), (char_x + 3, char_y + 5), (char_x + 3, char_y)], 1)
        else:  # "S"
            pygame.draw.lines(screen, text_color, False, [(char_x + 3, char_y), (char_x, char_y), (char_x, char_y + 2), (char_x + 3, char_y + 2), (char_x + 3, char_y + 5), (char_x, char_y + 5)], 1)
    
    # 상자 측면에 적재 번호와 바코드 스타일
    stripe_color = (110, 115, 90)
    # 적재 번호 바
    pygame.draw.rect(screen, stripe_color, (x - box_width // 2 + 8, y + box_height // 2 - 8, box_width - 16, 5))
    # 바코드 스타일 라인들
    barcode_x = x - box_width // 2 + 10
    for i in range(8):
        bar_width = 1 if i % 2 == 0 else 2
        pygame.draw.rect(screen, (70, 75, 55), (barcode_x + i * 3, y + box_height // 2 - 7, bar_width, 3))


def draw_items(screen, state: SupplyDropState) -> None:
    """Draw all falling supply items."""

    for item in state.items:
        if not item["active"]:
            continue

        x, y = int(item["x"]), int(item["y"])

        canopy_width = 76
        canopy_height = 34
        canopy_top = y - 56
        segments = 6

        top_points = []
        bottom_points = []
        for i in range(segments + 1):
            t = i / segments
            px = x - canopy_width // 2 + t * canopy_width
            top_y = canopy_top - 4 * (math.sin(t * math.pi) ** 1.3)
            bottom_y = canopy_top + canopy_height - 6 + math.sin(t * math.pi) * 6
            top_points.append((int(px), int(top_y)))
            bottom_points.append((int(px), int(bottom_y)))

        canopy_outline = top_points + bottom_points[::-1]

        base_color = (78, 84, 68)
        pygame.draw.polygon(screen, base_color, canopy_outline)
        pygame.draw.polygon(screen, (45, 48, 38), canopy_outline, 2)

        # 디지털 위장 패턴
        rand = random.Random(int(item["x"] * 17) ^ int(item["y"] * 13))
        camo_colors = [
            (92, 98, 80),
            (58, 64, 50),
            (38, 44, 32),
            (108, 114, 92),
        ]
        for _ in range(18):
            patch_w = rand.randint(8, 16)
            patch_h = rand.randint(6, 12)
            px = rand.uniform(x - canopy_width / 2 + patch_w, x + canopy_width / 2 - patch_w)
            py = rand.uniform(canopy_top, canopy_top + canopy_height - 8)
            patch_rect = pygame.Rect(int(px), int(py), patch_w, patch_h)
            pygame.draw.ellipse(screen, rand.choice(camo_colors), patch_rect)

        # 하이라이트
        highlight = pygame.Surface((canopy_width, canopy_height // 2), pygame.SRCALPHA)
        pygame.draw.ellipse(highlight, (255, 255, 255, 50), highlight.get_rect())
        screen.blit(highlight, (x - canopy_width // 2, canopy_top))

        # 패널 분할선
        seam_color = (100, 105, 90)
        for i in range(1, segments):
            seam_x = x - canopy_width // 2 + i * (canopy_width / segments)
            pygame.draw.line(
                screen,
                seam_color,
                (int(seam_x), canopy_top + 6),
                (int(seam_x - 4 * math.sin(i * math.pi / segments)), canopy_top + canopy_height - 6),
                1,
            )

        # 낙하산 끈과 하네스 - 더 디테일하게
        cord_color = (70, 70, 70)
        cord_highlight = (85, 85, 85)
        box_width = 40
        box_height = 30
        canopy_anchor_y = canopy_top + canopy_height - 4
        
        # 더 많은 끈 추가
        canopy_offsets = [-35, -28, -21, -14, -7, 0, 7, 14, 21, 28, 35]
        box_offsets = [-box_width // 2 + 2, -box_width // 2 + 6, -box_width // 2 + 10, -8, -4, 0, 4, 8, box_width // 2 - 10, box_width // 2 - 6, box_width // 2 - 2]
        
        for i, (c_off, b_off) in enumerate(zip(canopy_offsets, box_offsets)):
            start = (x + c_off, canopy_anchor_y)
            end = (x + b_off, y - box_height // 2 + 6)
            
            # 메인 끈
            pygame.draw.line(screen, cord_color, start, end, 2)
            
            # 끈에 하이라이트 추가 (입체감)
            if i % 2 == 0:
                pygame.draw.line(screen, cord_highlight, (start[0] + 1, start[1]), (end[0] + 1, end[1]), 1)
            
            # 끈 중간에 매듭 표현
            mid_x = (start[0] + end[0]) // 2
            mid_y = (start[1] + end[1]) // 2
            if i % 3 == 0:
                pygame.draw.circle(screen, (50, 50, 50), (int(mid_x), int(mid_y)), 2)
                pygame.draw.circle(screen, cord_color, (int(mid_x), int(mid_y)), 1)

        # 중앙 하네스 및 버클 - 더 디테일하게
        harness_rect = pygame.Rect(x - 7, y - box_height // 2 - 10, 14, 18)
        pygame.draw.rect(screen, (66, 66, 66), harness_rect)
        pygame.draw.rect(screen, (40, 40, 40), harness_rect, 2)
        
        # 버클 디테일
        buckle_rect = pygame.Rect(x - 5, y - box_height // 2 - 4, 10, 6)
        pygame.draw.rect(screen, (120, 120, 120), buckle_rect)
        pygame.draw.rect(screen, (90, 90, 90), buckle_rect, 1)
        # 버클 중앙 구멍
        pygame.draw.rect(screen, (60, 60, 60), (x - 2, y - box_height // 2 - 2, 4, 2))
        
        # 하네스 스트랩
        strap_y = y - box_height // 2 - 10
        pygame.draw.line(screen, (50, 50, 50), (x - 7, strap_y + 5), (x - 10, strap_y - 5), 2)
        pygame.draw.line(screen, (50, 50, 50), (x + 7, strap_y + 5), (x + 10, strap_y - 5), 2)

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
