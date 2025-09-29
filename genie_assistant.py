import math
import random
from typing import List, Tuple

import pygame

from pixel_font_manager import FontStyle, get_font

ANIMATION_DURATION_MS = 2000
SMOKE_PARTICLE_COUNT = 18
COLOR_OVERLAY_BG = (12, 20, 35, 220)
COLOR_MENU_BG = (26, 36, 62, 220)
COLOR_MENU_BORDER = (80, 110, 170, 255)
COLOR_MENU_ACTIVE = (115, 160, 255, 235)
COLOR_DETAIL_BG = (18, 24, 40, 235)
COLOR_TEXT_MAIN = (235, 240, 255)
COLOR_TEXT_DIM = (170, 185, 210)
COLOR_KEY_BG = (255, 215, 120)
COLOR_KEY_TEXT = (20, 30, 50)

CHARACTER_LABELS = {
    "soldier": "코만도",
    "blacksmith": "발토르",
    "smasher": "스매셔",
    "optimus": "옵티머스",
    "normal": "일반 플레이어",
}

TUTORIAL_LIBRARY: dict[str, List[dict]] = {
    "soldier": [
        {
            "id": "firearms",
            "title": "화기류 사용법",
            "summary": "주무기 발사와 안전 제한",
            "keys": ["SPACE"],
            "details": [
                "SPACE 키를 눌러 현재 장비한 화기를 발사합니다.",
                "코만도는 기본 화기류로 권총이 지급되며 다른 화기류들은 물자보급을 통하여 얻을 수 있습니다",
                "현재 사용중인 화기류는 왼쪽 하단에 화기류박스를 통해 확인할 수 있으며 하단에 남은 탄환도 표시됩니다",
            ],
            "animation": "fire",
        },
        {
            "id": "reload",
            "title": "권총 재장전",
            "summary": "빈 탄창을 SPACE로 채우기",
            "keys": ["SPACE"],
            "details": [
                "탄약이 0이 된 상태에서 SPACE를 누르면 2초간 재장전이 진행되며 스킬 게이지 150을 소비합니다.",
                "재장전 중에는 사격이 불가능하고 총알을 재장전하는 모션이 표시됩니다.",
                "권총을 제외한 다른 화기류들은 물자보급에서 획득한 탄약상자, 비상보급스킬로만 재장전이 가능합니다."
                
            ],
            "animation": "reload",
        },
        {
            "id": "weapon_switch",
            "title": "화기류 교체",
            "summary": "짧게 눌러 순환, 길게 눌러 메뉴",
            "keys": ["↑"],
            "details": [
                "↑ 키를 입력하면 보유 중인 화기가 순서대로 순환합니다. 전투 중 급히 무기를 바꿀 때 가장 빠른 방법입니다.",
                "↑ 키를 약 0.3초 이상 누르고 있으면 무기 선택 메뉴가 열립니다. 숫자키 1~5으로 원하는 무기를 고르세요.",
                
            ],
            "animation": "switch",
        },
        {
            "id": "supply_drop",
            "title": "물자보급 요청",
            "summary": "↓키 홀드로 보급상자 호출",
            "keys": ["↓ (1초 홀드)", "게이지 350"],
            "details": [
                "↓ 키를 1초 이상 누르면 무전기가 켜지고, 스킬 게이지 350을 소비해 보급 비행기를 호출합니다.",
                "호출 도중에는 플레이어가 잠시 움직일 수 없습니다",
                "보급상자에서 탄약상자, 화기류, 아이템 등 전투에 유용한 다양한 물자를 획득할 수 있습니다.",
            ],
            "animation": "supply",
        },
        {
            "id": "emergency",
            "title": "비상보급",
            "summary": "↓ ↓ 더블탭으로 즉시 장전",
            "keys": ["↓ ↓", "게이지 500"],
            "details": [
                "↓ 키를 빠르게 두 번 입력하면 스킬 게이지 500을 소비해 현재 착용중인 화기류의 탄약을 즉시 가득 채웁니다.",
                "스테이지마다 1회만 사용할 수 있습니다",
                
                
            ],
            "animation": "emergency",
        },
    ],
    "blacksmith": [
        {
            "id": "thor_shield",
            "title": "토르쉴드",
            "summary": "↑로 전개, SPACE+방향으로 반격",
            "keys": ["↑", "SPACE+←/→"],
            "details": [
                "↑ 키를 눌러 토르쉴드를 펼치거나 접습니다. 내구도 5칸으로 적 투사체를 막을 때마다 1칸씩 소모되며 0이 되면 자동으로 접힙니다.",
                "가드 중 이동 속도는 기본의 25%가 되고 건설·아이템·포탑 입력이 잠시 잠금됩니다. 내구도는 기본 7초, 디바인스톤 활성 시 5초 주기로 1칸씩 회복됩니다.",
                "토르쉴드를 펼친 상태에서 SPACE와 ←/→를 동시에 누르면 반대 방향으로 스윙하며, 넉백과 충격파로 공을 밀어냅니다.",
            ],
            "animation": "thor_shield",
        },
        {
            "id": "build_menu",
            "title": "건설 메뉴",
            "summary": "↓ 홀드로 청사진 선택",
            "keys": ["↓ (0.5초 홀드)", "1/2", "ESC/↓"],
            "details": [
                "↓ 키를 약 0.5초 동안 누르면 발토르 건설 메뉴가 열리며 현재 설치 가능한 설비를 확인할 수 있습니다.",
                "숫자 1은 포탑, 2는 디바인스톤을 선택합니다. 선택 즉시 플레이어 발밑에 청사진이 생성됩니다.",
                "ESC 또는 ↓ 키로 메뉴를 닫을 수 있으며, 건설 메뉴가 열린 동안에는 스페이스·아이템 입력이 잠시 비활성화됩니다.",
            ],
            "animation": "blacksmith_build",
        },
        {
            "id": "turret",
            "title": "포탑",
            "summary": "↓ 유지로 건설, SPACE로 수동 발사",
            "keys": ["건설→1", "↓ 유지", "SPACE"],
            "details": [
                "포탑 청사진 위에서 ↓ 키를 계속 누르면 해머질이 진행되며 스킬 게이지가 초당 45씩 소모되어 약 4초(180 게이지) 만에 완성됩니다.",
                "건설 범위는 플레이어 기준 좌우 70px이므로 청사진 중앙에 맞춰 서야 진행도가 올라갑니다. 완성 후에는 5초 간격으로 자동 미사일을 발사합니다.",
                "포탑 위에서 SPACE를 짧게 누르면 게이지 60을 소모해 즉시 미사일을 발사합니다(쿨다운 0.6초). 토르쉴드가 열린 동안에는 수동 발사가 막힙니다.",
            ],
            "animation": "blacksmith_turret",
        },
        {
            "id": "divine_stone",
            "title": "디바인스톤",
            "summary": "공 튕기고 토르쉴드 지원",
            "keys": ["건설→2", "↓ 유지"],
            "details": [
                "청사진 위에서 ↓ 키를 유지하면 스킬 게이지가 초당 45씩 소모되어 약 6초(270 게이지) 만에 디바인스톤이 완성됩니다.",
                "완성된 디바인스톤은 공을 튕겨내고 체력이 3칸입니다. 파괴되면 다시 건설해야 하며, 전투 중 자동으로 맵 중앙 근처에 고정됩니다.",
                "활성 상태에서는 토르쉴드 회복 주기가 7초→5초로 단축되고 해머쇼크 사용 조건을 충족시킵니다.",
            ],
            "animation": "blacksmith_divine",
        },
        {
            "id": "hammer_shock",
            "title": "해머쇼크",
            "summary": "디바인스톤 + SPACE 홀드",
            "keys": ["SPACE 홀드", "SPACE 릴리즈", "(디바인스톤 활성)"],
            "details": [
                "디바인스톤이 살아 있고 스킬 게이지가 200 이상이면 SPACE를 누르는 순간 해머쇼크 차지가 시작됩니다. 토르쉴드가 열려 있으면 차지가 막힙니다.",
                "SPACE를 유지한 시간에 따라 단계가 상승합니다: 1초(200 게이지), 2초(260), 3초(320). 게이지가 부족하면 해당 단계로 넘어가지 않습니다.",
                "SPACE를 놓으면 해머를 투척해 충격파를 일으키며 큰 피해와 넉백을 줍니다. 포탑 옆에서 수동 발사를 건너뛰고 해머쇼크를 쓰려면 SPACE를 누를 때 ↓ 키를 함께 눌러 주세요.",
            ],
            "animation": "blacksmith_hammer_shock",
        },
    ],
    "default": [
        {
            "id": "coming_soon",
            "title": "튜토리얼 준비 중",
            "summary": "지니 데이터가 곧 업데이트됩니다",
            "keys": [],
            "details": [
                "선택한 캐릭터에 대한 전용 튜토리얼이 아직 준비되지 않았습니다.",
                "최신 패치 노트를 확인하거나 기본 조작법을 다시 살펴보세요.",
            ],
            "animation": "idle",
        }
    ],
}


def _create_local_surface(rect: pygame.Rect) -> pygame.Surface:
    return pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)


def _draw_small_turret_icon(target: pygame.Surface, rect: pygame.Rect, glow: float) -> None:
    icon = _create_local_surface(rect)
    w, h = icon.get_size()
    cx = w / 2
    base_y = h * 0.82

    base_points = [
        (cx - w * 0.42, base_y - h * 0.05),
        (cx + w * 0.42, base_y - h * 0.05),
        (cx + w * 0.32, base_y + h * 0.08),
        (cx - w * 0.32, base_y + h * 0.08),
    ]
    pygame.draw.polygon(icon, (70, 66, 104), [(int(x), int(y)) for x, y in base_points])
    pygame.draw.lines(icon, (130, 122, 180), True, [(int(x), int(y)) for x, y in base_points], max(1, int(w * 0.03)))

    leg_color = (178, 182, 206)
    outline_color = (80, 82, 120)
    leg_width = w * 0.18
    leg_height = h * 0.46
    for direction in (-1, 1):
        x0 = cx + direction * w * 0.38
        points = [
            (x0, base_y - h * 0.15),
            (x0 + direction * leg_width * 0.4, base_y - leg_height * 0.6),
            (x0 + direction * leg_width * 0.2, base_y - leg_height),
            (cx + direction * w * 0.18, base_y - leg_height * 0.45),
        ]
        pygame.draw.polygon(icon, leg_color, [(int(x), int(y)) for x, y in points])
        pygame.draw.lines(icon, outline_color, False, [(int(x), int(y)) for x, y in points], max(1, int(w * 0.025)))

    body_rect = pygame.Rect(0, 0, int(w * 0.42), int(h * 0.34))
    body_rect.center = (int(cx), int(base_y - h * 0.38))
    body_color = (116, 120, 158)
    highlight = int(30 * glow)
    body_color = tuple(min(255, c + highlight) for c in body_color)
    pygame.draw.rect(icon, body_color, body_rect, border_radius=int(w * 0.1))
    pygame.draw.rect(icon, (220, 224, 250), body_rect.inflate(-int(w * 0.12), -int(h * 0.16)), border_radius=int(w * 0.06))

    head_rect = pygame.Rect(0, 0, int(w * 0.36), int(h * 0.18))
    head_rect.center = (int(cx), int(body_rect.top + head_rect.height * 0.6))
    pygame.draw.rect(icon, (86, 88, 136), head_rect, border_radius=int(w * 0.08))

    barrel_width = max(2, int(w * 0.12))
    barrel_length = int(h * 0.32)
    barrel_rect = pygame.Rect(0, 0, barrel_width, barrel_length)
    barrel_rect.centerx = int(cx)
    barrel_rect.top = int(body_rect.top - barrel_length * 0.85)
    pygame.draw.rect(icon, (190, 198, 220), barrel_rect)
    pygame.draw.rect(icon, (110, 118, 150), barrel_rect.inflate(-max(1, barrel_width // 3), -max(1, barrel_width // 3)))

    muzzle_radius = max(2, int(barrel_width * 0.8))
    muzzle_center = (barrel_rect.centerx, barrel_rect.top - muzzle_radius)
    glow_scale = 0.4 + 0.6 * glow
    muzzle_color = (255, 200, int(120 + 80 * glow_scale))
    pygame.draw.circle(icon, muzzle_color, muzzle_center, int(muzzle_radius * (1.0 + 0.2 * glow_scale)))
    pygame.draw.circle(icon, (255, 255, 220), muzzle_center, max(1, muzzle_radius // 2))

    target.blit(icon, rect.topleft)


def _draw_small_divine_icon(target: pygame.Surface, rect: pygame.Rect, pulse: float) -> None:
    icon = _create_local_surface(rect)
    w, h = icon.get_size()
    cx = w / 2
    base_y = h * 0.8

    base_rect = pygame.Rect(0, 0, int(w * 0.78), int(h * 0.26))
    base_rect.center = (int(cx), int(base_y))
    pygame.draw.ellipse(icon, (94, 76, 58, 220), base_rect)
    pygame.draw.ellipse(icon, (160, 134, 108, 160), base_rect.inflate(-int(w * 0.12), -int(h * 0.12)))

    body_rect = pygame.Rect(0, 0, int(w * 0.52), int(h * 0.5))
    body_rect.midbottom = (int(cx), int(base_rect.top + h * 0.08))
    stone_color = (170, 186, 210)
    pulse_strength = 25 + int(35 * pulse)
    stone_highlight = tuple(min(255, c + pulse_strength) for c in stone_color)
    pygame.draw.rect(icon, stone_color, body_rect, border_radius=int(w * 0.12))
    inner_rect = body_rect.inflate(-int(w * 0.2), -int(h * 0.2))
    pygame.draw.rect(icon, stone_highlight, inner_rect, border_radius=int(w * 0.08))

    rune_count = 3
    for idx in range(rune_count):
        offset = (idx - (rune_count - 1) / 2) * (inner_rect.width / rune_count)
        x = int(inner_rect.centerx + offset)
        pygame.draw.line(icon, (80, 110, 200), (x, inner_rect.top + 4), (x, inner_rect.bottom - 4), max(1, int(w * 0.04)))
        pygame.draw.circle(icon, (240, 250, 255), (x, inner_rect.top + int(inner_rect.height * 0.3)), max(1, int(w * 0.04)))

    aura_radius = int(max(w, h) * 0.46)
    aura_surf = pygame.Surface((aura_radius * 2, aura_radius * 2), pygame.SRCALPHA)
    for r in range(aura_radius, 0, -1):
        alpha = max(0, int(120 * (r / aura_radius) ** 2 * pulse))
        pygame.draw.circle(aura_surf, (180, 220, 255, alpha), (aura_radius, aura_radius), r, 1)
    icon.blit(aura_surf, (int(cx - aura_radius), int(body_rect.centery - aura_radius)), special_flags=pygame.BLEND_PREMULTIPLIED)

    target.blit(icon, rect.topleft)


def _draw_small_hammer_icon(target: pygame.Surface, rect: pygame.Rect, glow: float) -> None:
    icon = _create_local_surface(rect)
    w, h = icon.get_size()
    cx = w / 2
    cy = h / 2

    handle_color = (110, 70, 46)
    handle_width = max(2, int(w * 0.14))
    handle_rect = pygame.Rect(0, 0, handle_width, int(h * 0.72))
    handle_rect.center = (int(cx - w * 0.08), int(cy + h * 0.08))
    pygame.draw.rect(icon, handle_color, handle_rect, border_radius=int(handle_width * 0.4))

    head_width = int(w * 0.6)
    head_height = int(h * 0.34)
    head_rect = pygame.Rect(0, 0, head_width, head_height)
    head_rect.midleft = (handle_rect.right - int(handle_width * 0.3), int(cy))
    pulse = 30 + int(50 * glow)
    head_color = (156 + pulse // 2, 164 + pulse // 3, 180 + pulse // 4)
    pygame.draw.rect(icon, head_color, head_rect, border_radius=int(head_height * 0.3))
    pygame.draw.rect(icon, (255, 255, 255), head_rect.inflate(-int(head_width * 0.2), -int(head_height * 0.5)), border_radius=int(head_height * 0.2))

    spark_surface = pygame.Surface((w, h), pygame.SRCALPHA)
    for angle in (-35, -10, 15, 35):
        length = h * (0.45 + 0.15 * glow)
        end_x = cx + length * math.cos(math.radians(angle))
        end_y = cy + length * math.sin(math.radians(angle))
        pygame.draw.line(
            spark_surface,
            (255, 220, 140, 160),
            (cx + w * 0.12, cy - h * 0.05),
            (end_x, end_y),
            max(1, int(w * 0.04)),
        )
    icon.blit(spark_surface, (0, 0), special_flags=pygame.BLEND_PREMULTIPLIED)

    target.blit(icon, rect.topleft)


def _draw_thor_shield_preview(surface: pygame.Surface, rect: pygame.Rect, ticks: int) -> None:
    preview = _create_local_surface(rect)
    w, h = preview.get_size()
    center = (w // 2, int(h * 0.58))

    outer_rect = pygame.Rect(0, 0, int(w * 0.7), int(h * 0.74))
    outer_rect.center = center
    pulse = 0.5 + 0.5 * math.sin(ticks / 320.0)
    base_color = (72, 112, 168)
    base_color = tuple(min(255, int(c + 40 * pulse)) for c in base_color)
    pygame.draw.ellipse(preview, base_color, outer_rect)

    inner_rect = outer_rect.inflate(-int(w * 0.14), -int(h * 0.16))
    inner_color = (120, 170, 220)
    pygame.draw.ellipse(preview, inner_color, inner_rect)
    pygame.draw.ellipse(preview, (230, 238, 250), inner_rect, max(1, int(w * 0.02)))

    brace_width = max(2, int(w * 0.06))
    vertical_brace = pygame.Rect(0, 0, brace_width, inner_rect.height)
    vertical_brace.center = center
    pygame.draw.rect(preview, (50, 60, 90), vertical_brace, border_radius=brace_width // 2)
    horizontal_brace = pygame.Rect(0, 0, inner_rect.width, brace_width)
    horizontal_brace.center = (center[0], center[1] - int(h * 0.1))
    pygame.draw.rect(preview, (50, 60, 90), horizontal_brace, border_radius=brace_width // 2)

    arc_rect = outer_rect.inflate(int(w * 0.24), int(h * 0.2))
    sweep = math.pi * (0.4 + 1.0 * pulse)
    pygame.draw.arc(preview, (255, 210, 90), arc_rect, math.pi * 1.1, math.pi * 1.1 + sweep, max(2, int(w * 0.04)))

    for angle in (220, 250, 290, 320):
        radians = math.radians(angle)
        radius = outer_rect.width / 2
        start = (
            center[0] + radius * math.cos(radians),
            center[1] + radius * math.sin(radians),
        )
        end = (
            center[0] + (radius + w * 0.12) * math.cos(radians + 0.12 * math.sin(ticks / 200.0)),
            center[1] + (radius + w * 0.12) * math.sin(radians + 0.12 * math.sin(ticks / 200.0)),
        )
        pygame.draw.line(preview, (180, 220, 255), (int(start[0]), int(start[1])), (int(end[0]), int(end[1])), max(1, int(w * 0.025)))

    rim_rect = outer_rect.inflate(int(w * 0.08), int(h * 0.08))
    pygame.draw.ellipse(preview, (40, 56, 86, 180), rim_rect, max(1, int(w * 0.03)))

    surface.blit(preview, rect.topleft)


def _draw_blacksmith_build_preview(surface: pygame.Surface, rect: pygame.Rect, ticks: int, font: pygame.font.Font) -> None:
    preview = _create_local_surface(rect)
    w, h = preview.get_size()

    board_rect = pygame.Rect(0, 0, int(w * 0.9), int(h * 0.72))
    board_rect.center = (w // 2, int(h * 0.55))
    pygame.draw.rect(preview, (32, 52, 84), board_rect, border_radius=16)
    pygame.draw.rect(preview, (90, 120, 180), board_rect, width=2, border_radius=16)

    grid_spacing = max(8, int(board_rect.width / 8))
    for x in range(board_rect.left + grid_spacing, board_rect.right, grid_spacing):
        pygame.draw.line(preview, (60, 80, 130), (x, board_rect.top + 6), (x, board_rect.bottom - 6))
    for y in range(board_rect.top + grid_spacing, board_rect.bottom, grid_spacing):
        pygame.draw.line(preview, (60, 80, 130), (board_rect.left + 6, y), (board_rect.right - 6, y))

    hammer_rect = pygame.Rect(0, 0, int(w * 0.22), int(h * 0.42))
    hammer_rect.midleft = (board_rect.left + int(board_rect.width * 0.16), board_rect.centery)
    hammer_glow = 0.5 + 0.5 * math.sin(ticks / 220.0)
    _draw_small_hammer_icon(preview, hammer_rect, hammer_glow)

    icon_spacing = int(board_rect.width * 0.3)
    icon_size = pygame.Rect(0, 0, int(w * 0.26), int(h * 0.48))
    icon_size.center = (board_rect.centerx + icon_spacing // 2, board_rect.centery)
    turret_glow = 0.5 + 0.5 * math.sin((ticks + 120) / 260.0)
    _draw_small_turret_icon(preview, icon_size, turret_glow)

    divine_rect = icon_size.copy()
    divine_rect.midright = (board_rect.right - icon_spacing // 4, board_rect.centery)
    divine_pulse = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(ticks / 300.0))
    _draw_small_divine_icon(preview, divine_rect, divine_pulse)

    if font:
        tips = [
            ("1", icon_size.midbottom),
            ("2", divine_rect.midbottom),
        ]
        for label, pos in tips:
            text_surface = font.render(label, True, (235, 240, 255))
            text_rect = text_surface.get_rect(center=(int(pos[0]), int(pos[1] + h * 0.08)))
            preview.blit(text_surface, text_rect)

    surface.blit(preview, rect.topleft)


def _draw_blacksmith_turret_preview(surface: pygame.Surface, rect: pygame.Rect, ticks: int) -> None:
    preview = _create_local_surface(rect)
    w, h = preview.get_size()
    turret_rect = pygame.Rect(0, 0, int(w * 0.68), int(h * 0.7))
    turret_rect.center = (int(w * 0.5), int(h * 0.6))
    glow = 0.5 + 0.5 * math.sin(ticks / 240.0)
    _draw_small_turret_icon(preview, turret_rect, glow)

    muzzle_time = (ticks % 900) / 900.0
    if muzzle_time < 0.18:
        muzzle_phase = muzzle_time / 0.18
        flash_radius = int(max(4, w * 0.12 * (1.2 - muzzle_phase)))
        flash_center = (turret_rect.centerx, int(turret_rect.top - flash_radius * 0.6))
        pygame.draw.circle(
            preview,
            (255, 220, 140, int(200 * (1.0 - muzzle_phase))),
            flash_center,
            flash_radius,
        )

    particle_count = 6
    for idx in range(particle_count):
        angle = (ticks / 80.0) + (idx / particle_count) * math.tau
        radius = w * 0.34
        alpha = int(80 + 60 * math.sin(ticks / 200.0 + idx))
        point = (
            turret_rect.centerx + radius * math.cos(angle),
            turret_rect.centery + radius * math.sin(angle * 0.6),
        )
        pygame.draw.circle(preview, (120, 180, 240, alpha), (int(point[0]), int(point[1])), max(1, int(w * 0.02)))

    surface.blit(preview, rect.topleft)


def _draw_blacksmith_divine_preview(surface: pygame.Surface, rect: pygame.Rect, ticks: int) -> None:
    preview = _create_local_surface(rect)
    w, h = preview.get_size()
    stone_rect = pygame.Rect(0, 0, int(w * 0.62), int(h * 0.68))
    stone_rect.center = (int(w * 0.52), int(h * 0.6))
    pulse = 0.5 + 0.5 * math.sin(ticks / 260.0)
    _draw_small_divine_icon(preview, stone_rect, pulse)

    orbit_radius = int(max(w, h) * 0.44)
    orbit_surface = pygame.Surface((orbit_radius * 2, orbit_radius * 2), pygame.SRCALPHA)
    for idx in range(3):
        progress = ((ticks / 900.0) + idx / 3) % 1.0
        angle = progress * math.tau
        x = orbit_radius + orbit_radius * 0.8 * math.cos(angle)
        y = orbit_radius + orbit_radius * 0.4 * math.sin(angle)
        pygame.draw.circle(
            orbit_surface,
            (200, 240, 255, int(160 * (1.0 - progress))),
            (int(x), int(y)),
            max(2, int(w * 0.04)),
        )
    preview.blit(orbit_surface, (stone_rect.centerx - orbit_radius, stone_rect.centery - orbit_radius), special_flags=pygame.BLEND_PREMULTIPLIED)

    surface.blit(preview, rect.topleft)


def _draw_blacksmith_hammer_shock_preview(surface: pygame.Surface, rect: pygame.Rect, ticks: int) -> None:
    preview = _create_local_surface(rect)
    w, h = preview.get_size()
    hammer_rect = pygame.Rect(0, 0, int(w * 0.6), int(h * 0.48))
    hammer_rect.center = (int(w * 0.44), int(h * 0.55))
    glow = 0.5 + 0.5 * math.sin(ticks / 200.0)
    _draw_small_hammer_icon(preview, hammer_rect, glow)

    trail_surface = pygame.Surface((w, h), pygame.SRCALPHA)
    center = (hammer_rect.centerx + w * 0.18, hammer_rect.centery - h * 0.2)
    max_radius = int(max(w, h) * 0.5)
    for idx in range(3):
        stage = idx + 1
        factor = stage / 3.0
        radius = int(max_radius * (0.45 + 0.22 * factor))
        alpha = int(90 + 80 * (0.5 + 0.5 * math.sin((ticks / 240.0) + factor * math.pi)))
        pygame.draw.circle(trail_surface, (120, 200, 255, alpha), center, radius, max(1, int(w * 0.03)))
    preview.blit(trail_surface, (0, 0), special_flags=pygame.BLEND_PREMULTIPLIED)

    gauge_width = int(w * 0.65)
    gauge_height = int(h * 0.1)
    gauge_rect = pygame.Rect(0, 0, gauge_width, gauge_height)
    gauge_rect.midbottom = (int(w * 0.56), int(h * 0.92))
    pygame.draw.rect(preview, (44, 52, 80), gauge_rect.inflate(4, 4), border_radius=6)

    stage_time = (ticks % 1800) / 1800.0
    active_stage = min(3, int(stage_time * 3) + 1)
    bar_width = gauge_rect.width // 3
    for idx in range(3):
        bar_rect = pygame.Rect(
            gauge_rect.left + idx * bar_width,
            gauge_rect.top,
            bar_width - 4,
            gauge_rect.height,
        )
        filled = idx < active_stage
        color = (255, 210, 120) if filled else (120, 130, 150)
        pygame.draw.rect(preview, color, bar_rect, border_radius=4)
        pygame.draw.rect(preview, (30, 36, 60), bar_rect, width=1, border_radius=4)

    surface.blit(preview, rect.topleft)

def _wrap_text(font: pygame.font.Font, text: str, max_width: int) -> List[str]:
    words = text.split()
    if not words:
        return [""]
    lines: List[str] = []
    current = words[0]
    for word in words[1:]:
        candidate = f"{current} {word}"
        if font.size(candidate)[0] <= max_width:
            current = candidate
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


class GenieAssistant:
    """지니 애니메이션을 포함한 캐릭터별 튜토리얼 오버레이."""

    def __init__(self) -> None:
        self.active: bool = False
        self.phase: str = "inactive"  # inactive, animation, menu
        self.elapsed_ms: float = 0.0
        self.screen_size: Tuple[int, int] = (0, 0)
        self.overlay_surface: pygame.Surface | None = None
        self.smoke_particles: List[dict] = []

        self.character_type: str = "normal"
        self.tutorial_items: List[dict] = []
        self.selected_index: int = 0
        self.menu_item_rects: List[pygame.Rect] = []

        self.title_font = FontStyle.large()
        self.menu_font = FontStyle.body()
        self.detail_font = get_font(20)
        self.small_font = get_font(16)
        self.key_font = get_font(18)

        self.detail_scroll_offset: float = 0.0
        self.detail_scroll_direction: int = 1
        self.detail_scroll_wait: float = 0.0
        self.detail_scroll_pause: float = 4000.0  # ms 대기
        self.detail_scroll_speed: float = 26.0  # px/sec
        self._detail_lines: List[dict] = []
        self._detail_total_height: float = 0.0
        self._detail_view_height: float = 0.0
        self._detail_layout_key: Tuple[str | None, int] | None = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def is_active(self) -> bool:
        return self.active

    def activate(self, screen: pygame.Surface, character_type: str | None) -> None:
        if self.active:
            self.deactivate()
        self.active = True
        self.phase = "animation"
        self.elapsed_ms = 0.0
        self.screen_size = screen.get_size()
        self.overlay_surface = pygame.Surface(self.screen_size, pygame.SRCALPHA)
        self.character_type = character_type or "normal"
        self.tutorial_items = self._resolve_tutorials(self.character_type)
        self.selected_index = 0
        self.menu_item_rects = []
        self._init_smoke_particles()
        self._reset_detail_scroll(reset_layout=True)

    def deactivate(self) -> None:
        self.active = False
        self.phase = "inactive"
        self.overlay_surface = None
        self.smoke_particles.clear()

    def update(self, dt_ms: float) -> None:
        if not self.active:
            return
        self.elapsed_ms += dt_ms

        if self.phase == "animation" and self.elapsed_ms >= ANIMATION_DURATION_MS:
            self._enter_menu_phase()

        self._update_smoke_particles(dt_ms)

        if self.phase == "menu" and self._detail_total_height > 0 and self._detail_view_height > 0:
            overflow = self._detail_total_height - self._detail_view_height
            if overflow > 4:
                if self.detail_scroll_wait < self.detail_scroll_pause:
                    self.detail_scroll_wait = min(self.detail_scroll_pause, self.detail_scroll_wait + dt_ms)
                else:
                    step = self.detail_scroll_speed * (dt_ms / 1000.0) * self.detail_scroll_direction
                    self.detail_scroll_offset += step
                    max_offset = max(0.0, overflow)
                    if self.detail_scroll_offset >= max_offset:
                        self.detail_scroll_offset = max_offset
                        self.detail_scroll_direction = -1
                        self.detail_scroll_wait = 0.0
                    elif self.detail_scroll_offset <= 0.0:
                        self.detail_scroll_offset = 0.0
                        self.detail_scroll_direction = 1
                        self.detail_scroll_wait = 0.0
            else:
                if self.detail_scroll_offset != 0.0:
                    self.detail_scroll_offset = 0.0
                self.detail_scroll_direction = 1
                self.detail_scroll_wait = 0.0
        else:
            if self.detail_scroll_offset != 0.0:
                self.detail_scroll_offset = 0.0
            self.detail_scroll_direction = 1
            self.detail_scroll_wait = 0.0

    def draw(self, surface: pygame.Surface) -> None:
        if not self.active or self.overlay_surface is None:
            return

        bg_surface = self.overlay_surface
        bg_surface.fill(COLOR_OVERLAY_BG)

        lamp_center = (self.screen_size[0] // 2, self.screen_size[1] // 2 + 160)
        progress = min(1.0, self.elapsed_ms / ANIMATION_DURATION_MS) if ANIMATION_DURATION_MS else 1.0
        self._draw_lamp(bg_surface, lamp_center, progress)
        self._draw_smoke(bg_surface, lamp_center, progress)

        if self.phase == "animation":
            self._draw_animation_intro(bg_surface)
        else:
            self._draw_tutorial_menu(bg_surface)

        surface.blit(bg_surface, (0, 0))

    def handle_event(self, event: pygame.event.Event) -> bool:
        if not self.active:
            return False

        if event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_ESCAPE, pygame.K_t):
                self.deactivate()
                return True
            if self.phase == "animation" and event.key in (pygame.K_RETURN, pygame.K_SPACE):
                self._enter_menu_phase()
                return True
            if self.phase == "menu":
                if event.key in (pygame.K_UP, pygame.K_w):
                    self._move_selection(-1)
                    return True
                if event.key in (pygame.K_DOWN, pygame.K_s):
                    self._move_selection(1)
                    return True
                if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                    # 메뉴에서는 상세 패널이 항상 열려 있으므로 입력을 소비만 한다.
                    return True
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if self.phase == "animation":
                self._enter_menu_phase()
                return True
            if self.phase == "menu" and event.button == 1:
                pos = event.pos
                for idx, rect in enumerate(self.menu_item_rects):
                    if rect.collidepoint(pos):
                        if idx != self.selected_index:
                            self.selected_index = idx
                            self._reset_detail_scroll(reset_layout=True)
                        return True
                # 메뉴 밖 클릭은 닫기
                self.deactivate()
                return True

        elif event.type == pygame.MOUSEMOTION and self.phase == "menu":
            for idx, rect in enumerate(self.menu_item_rects):
                if rect.collidepoint(event.pos):
                    if idx != self.selected_index:
                        self.selected_index = idx
                        self._reset_detail_scroll(reset_layout=True)
                    break
        return True

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    def _resolve_tutorials(self, character_type: str) -> List[dict]:
        if character_type in TUTORIAL_LIBRARY:
            return list(TUTORIAL_LIBRARY[character_type])
        return list(TUTORIAL_LIBRARY["default"])

    def _enter_menu_phase(self) -> None:
        self.phase = "menu"
        self.elapsed_ms = max(self.elapsed_ms, float(ANIMATION_DURATION_MS))

    def _move_selection(self, delta: int) -> None:
        if not self.tutorial_items:
            return
        self.selected_index = (self.selected_index + delta) % len(self.tutorial_items)
        self._reset_detail_scroll(reset_layout=True)

    def _init_smoke_particles(self) -> None:
        self.smoke_particles = []
        for _ in range(SMOKE_PARTICLE_COUNT):
            self.smoke_particles.append(
                {
                    "delay": random.uniform(0, ANIMATION_DURATION_MS * 0.8),
                    "life": random.uniform(750, 1400),
                    "born": 0.0,
                    "x": random.uniform(-30, 30),
                    "radius": random.uniform(8, 22),
                }
            )

    def _update_smoke_particles(self, dt_ms: float) -> None:
        for particle in self.smoke_particles:
            particle["born"] += dt_ms
            total_life = particle["delay"] + particle["life"]
            if particle["born"] > total_life:
                particle["born"] = 0.0
                particle["delay"] = random.uniform(0, ANIMATION_DURATION_MS * 0.5)
                particle["life"] = random.uniform(750, 1400)
                particle["x"] = random.uniform(-30, 30)
                particle["radius"] = random.uniform(8, 22)

    def _draw_animation_intro(self, surface: pygame.Surface) -> None:
        width, height = self.screen_size
        title = self.title_font.render("지니 전술 훈련", True, COLOR_TEXT_MAIN)
        title_rect = title.get_rect(center=(width // 2, height // 2 - 120))
        surface.blit(title, title_rect)

        character_label = CHARACTER_LABELS.get(self.character_type, "전투원")
        subtitle_font = FontStyle.body()
        subtitle = subtitle_font.render(f"{character_label}용 지침을 준비합니다...", True, COLOR_TEXT_DIM)
        subtitle_rect = subtitle.get_rect(center=(width // 2, height // 2 - 70))
        surface.blit(subtitle, subtitle_rect)

        hint = self.small_font.render("SPACE/ENTER로 건너뛰기", True, COLOR_TEXT_DIM)
        hint_rect = hint.get_rect(center=(width // 2, height // 2 - 20))
        surface.blit(hint, hint_rect)

    def _draw_tutorial_menu(self, surface: pygame.Surface) -> None:
        width, height = self.screen_size
        header_y = 70

        header = self.title_font.render("지니 전술 훈련", True, COLOR_TEXT_MAIN)
        surface.blit(header, header.get_rect(midtop=(width // 2, header_y)))

        character_label = CHARACTER_LABELS.get(self.character_type, "전투원")
        sub = self.small_font.render(f"코만도 지침" if self.character_type == "soldier" else f"{character_label} 지침", True, COLOR_TEXT_DIM)
        surface.blit(sub, sub.get_rect(midtop=(width // 2, header_y + 48)))

        spacing = 36
        min_padding = 40
        menu_width = max(300, int(width * 0.3))
        detail_width = max(420, int(width * 0.4))
        total_width = menu_width + detail_width + spacing

        if total_width > width - 2 * min_padding:
            detail_width = width - 2 * min_padding - menu_width - spacing
            if detail_width < 360:
                detail_width = 360
                menu_width = width - 2 * min_padding - spacing - detail_width
                menu_width = max(260, menu_width)
                detail_width = width - 2 * min_padding - spacing - menu_width

        container_left = max(min_padding, (width - (menu_width + detail_width + spacing)) // 2)
        menu_rect = pygame.Rect(container_left, header_y + 90, menu_width, height - (header_y + 180))
        detail_rect = pygame.Rect(menu_rect.right + spacing, menu_rect.top, detail_width, menu_rect.height)

        pygame.draw.rect(surface, COLOR_MENU_BG, menu_rect, border_radius=18)
        pygame.draw.rect(surface, COLOR_MENU_BORDER, menu_rect, width=2, border_radius=18)

        pygame.draw.rect(surface, COLOR_DETAIL_BG, detail_rect, border_radius=18)
        pygame.draw.rect(surface, (90, 120, 190, 140), detail_rect, width=2, border_radius=18)

        self._draw_menu_items(surface, menu_rect)
        self._draw_detail_panel(surface, detail_rect)

        footer_text = self.small_font.render("ESC 또는 U: 닫기", True, COLOR_TEXT_DIM)
        surface.blit(footer_text, footer_text.get_rect(midbottom=(width // 2, height - 40)))

    def _draw_menu_items(self, surface: pygame.Surface, menu_rect: pygame.Rect) -> None:
        items = self.tutorial_items
        self.menu_item_rects = []
        if not items:
            empty_text = self.menu_font.render("튜토리얼이 없습니다", True, COLOR_TEXT_DIM)
            surface.blit(empty_text, empty_text.get_rect(center=menu_rect.center))
            return

        item_height = 72
        padding_y = 12
        start_y = menu_rect.top + 24
        inner_x = menu_rect.left + 20
        inner_width = menu_rect.width - 40

        for idx, item in enumerate(items):
            rect = pygame.Rect(inner_x, start_y + idx * (item_height + padding_y), inner_width, item_height)
            if rect.bottom > menu_rect.bottom - 24:
                break
            is_selected = idx == self.selected_index
            bg_color = COLOR_MENU_ACTIVE if is_selected else (20, 28, 48, 210)
            pygame.draw.rect(surface, bg_color, rect, border_radius=14)
            pygame.draw.rect(surface, COLOR_MENU_BORDER, rect, width=1, border_radius=14)

            index_text = self.small_font.render(f"{idx + 1:02}", True, COLOR_TEXT_DIM)
            surface.blit(index_text, index_text.get_rect(midleft=(rect.left + 12, rect.centery)))

            title_surface = self.menu_font.render(item["title"], True, COLOR_TEXT_MAIN if is_selected else COLOR_TEXT_DIM)
            surface.blit(title_surface, title_surface.get_rect(midleft=(rect.left + 58, rect.centery - 12)))

            keys = item.get("keys", [])
            if keys:
                key_x = rect.left + 58
                key_y = rect.centery + 16
                for key in keys[:2]:
                    key_rect = pygame.Rect(key_x, key_y, self.key_font.size(key)[0] + 16, 24)
                    pygame.draw.rect(surface, COLOR_KEY_BG, key_rect, border_radius=8)
                    pygame.draw.rect(surface, (255, 255, 255), key_rect, width=1, border_radius=8)
                    key_surface = self.key_font.render(key, True, COLOR_KEY_TEXT)
                    surface.blit(key_surface, key_surface.get_rect(center=key_rect.center))
                    key_x += key_rect.width + 8

            self.menu_item_rects.append(rect)

    def _draw_detail_panel(self, surface: pygame.Surface, detail_rect: pygame.Rect) -> None:
        if not self.tutorial_items:
            info = self.menu_font.render("지침이 준비되지 않았습니다", True, COLOR_TEXT_DIM)
            surface.blit(info, info.get_rect(center=detail_rect.center))
            return

        item = self.tutorial_items[self.selected_index]
        title_surface = self.menu_font.render(item["title"], True, COLOR_TEXT_MAIN)
        surface.blit(title_surface, title_surface.get_rect(topleft=(detail_rect.left + 24, detail_rect.top + 24)))

        summary_surface = self.small_font.render(item.get("summary", ""), True, COLOR_TEXT_DIM)
        surface.blit(summary_surface, summary_surface.get_rect(topleft=(detail_rect.left + 24, detail_rect.top + 60)))

        keys = item.get("keys", [])
        if keys:
            key_x = detail_rect.left + 24
            key_y = detail_rect.top + 92
            for key in keys:
                badge_width = self.key_font.size(key)[0] + 20
                badge_rect = pygame.Rect(key_x, key_y, badge_width, 28)
                pygame.draw.rect(surface, COLOR_KEY_BG, badge_rect, border_radius=10)
                pygame.draw.rect(surface, (255, 255, 255), badge_rect, width=1, border_radius=10)
                key_surface = self.key_font.render(key, True, COLOR_KEY_TEXT)
                surface.blit(key_surface, key_surface.get_rect(center=badge_rect.center))
                key_x += badge_rect.width + 10

        animation_height = 140
        animation_rect = pygame.Rect(
            detail_rect.left + 24,
            detail_rect.top + 132,
            detail_rect.width - 48,
            animation_height,
        )
        self._draw_animation_preview(surface, animation_rect, item.get("animation"))

        text_top = animation_rect.bottom + 20
        text_rect = pygame.Rect(detail_rect.left + 28, text_top, detail_rect.width - 56, detail_rect.bottom - text_top - 24)
        self._detail_view_height = text_rect.height
        self._update_detail_layout(item, text_rect.width)
        self._draw_detail_text(surface, text_rect)

    def _draw_detail_text(self, surface: pygame.Surface, text_rect: pygame.Rect) -> None:
        if not self._detail_lines:
            return

        y = text_rect.top - self.detail_scroll_offset
        fade_top = 36
        fade_bottom = 48
        top_bound = text_rect.top - fade_top
        bottom_bound = text_rect.bottom + fade_bottom

        for entry in self._detail_lines:
            text = entry["text"]
            height = entry["height"]

            if text is None:
                y += height
                continue

            if y + height < top_bound:
                y += height
                continue

            if y > bottom_bound:
                break

            line_surface = self.detail_font.render(text, True, COLOR_TEXT_MAIN)

            alpha = 255
            if y < text_rect.top:
                if y <= top_bound:
                    y += height
                    continue
                ratio = (y - top_bound) / max(1.0, (text_rect.top - top_bound))
                alpha = int(255 * max(0.0, min(1.0, ratio)))
            elif y + height > text_rect.bottom:
                if y + height >= bottom_bound:
                    y += height
                    continue
                ratio = (bottom_bound - (y + height)) / max(1.0, (bottom_bound - text_rect.bottom))
                alpha = int(255 * max(0.0, min(1.0, ratio)))

            if alpha < 255:
                line_surface = line_surface.copy()
                line_surface.set_alpha(alpha)

            surface.blit(line_surface, (text_rect.left, y))
            y += height

    def _draw_animation_preview(self, surface: pygame.Surface, rect: pygame.Rect, animation_id: str | None) -> None:
        pygame.draw.rect(surface, (40, 52, 80, 200), rect, border_radius=16)
        pygame.draw.rect(surface, (90, 120, 190, 120), rect, width=1, border_radius=16)
        center_x = rect.centerx
        center_y = rect.centery
        ticks = pygame.time.get_ticks()

        if animation_id == "fire":
            gun_rect = pygame.Rect(rect.left + 24, center_y - 20, 110, 40)
            pygame.draw.rect(surface, (70, 90, 120), gun_rect, border_radius=8)
            muzzle_x = gun_rect.right + 10
            muzzle_y = center_y
            travel = rect.width - (gun_rect.width + 60)
            t = (ticks % 1200) / 1200.0
            bullet_x = muzzle_x + travel * t
            bullet_rect = pygame.Rect(int(bullet_x), muzzle_y - 6, 18, 12)
            pygame.draw.rect(surface, (255, 180, 90), bullet_rect, border_radius=4)
            pygame.draw.circle(surface, (255, 230, 160), (muzzle_x, muzzle_y), 16)
        elif animation_id == "reload":
            radius = min(rect.width, rect.height) // 3
            pygame.draw.circle(surface, (60, 80, 120), (center_x, center_y), radius, width=4)
            progress = (ticks % 2000) / 2000.0
            end_angle = -math.pi / 2 + progress * 2 * math.pi
            pygame.draw.arc(
                surface,
                (255, 200, 80),
                pygame.Rect(center_x - radius, center_y - radius, radius * 2, radius * 2),
                -math.pi / 2,
                end_angle,
                6,
            )
            text = self.small_font.render("스킬 게이지 150 소모", True, COLOR_TEXT_DIM)
            surface.blit(text, text.get_rect(center=(center_x, center_y + radius + 18)))
        elif animation_id == "supply":
            drop_height = rect.height - 40
            t = (ticks % 1600) / 1600.0
            crate_y = rect.top + 20 + drop_height * t
            crate_rect = pygame.Rect(center_x - 36, int(crate_y), 72, 48)
            pygame.draw.rect(surface, (120, 90, 60), crate_rect, border_radius=8)
            pygame.draw.rect(surface, (255, 225, 150), crate_rect, width=2, border_radius=8)
            rope_y = rect.top + 20
            pygame.draw.line(surface, (200, 200, 220), (center_x - 10, rope_y), (center_x - 10, crate_rect.top), 2)
            pygame.draw.line(surface, (200, 200, 220), (center_x + 10, rope_y), (center_x + 10, crate_rect.top), 2)
            plane = pygame.Rect(center_x - 70, rect.top + 10, 140, 16)
            pygame.draw.rect(surface, (160, 180, 220), plane, border_radius=6)
            label = self.small_font.render("스킬 게이지 350", True, COLOR_TEXT_DIM)
            surface.blit(label, label.get_rect(center=(center_x, rect.bottom - 18)))
        elif animation_id == "emergency":
            arrow_color = (255, 180, 120)
            base_y = center_y
            phase = math.sin(ticks / 160.0)
            for offset in (-1, 1):
                points = [
                    (center_x + offset * 80, base_y - 20),
                    (center_x + offset * 40, base_y - 20),
                    (center_x + offset * 40, base_y - 40),
                    (center_x + offset * 10, base_y),
                    (center_x + offset * 40, base_y + 40),
                    (center_x + offset * 40, base_y + 20),
                    (center_x + offset * 80, base_y + 20),
                ]
                jittered = [(x, y + phase * 4) for x, y in points]
                pygame.draw.polygon(surface, arrow_color, jittered)
            tap_text = self.small_font.render("0.25초 이내로 더블탭!", True, COLOR_TEXT_DIM)
            surface.blit(tap_text, tap_text.get_rect(center=(center_x, rect.bottom - 18)))
        elif animation_id == "switch":
            panel_rect = pygame.Rect(rect.left + 24, center_y - 40, rect.width - 48, 80)
            pygame.draw.rect(surface, (55, 70, 110), panel_rect, border_radius=12)
            pygame.draw.rect(surface, (120, 150, 210), panel_rect, width=1, border_radius=12)

            slots = ["권총", "바주카", "AK-47"]
            slot_width = (panel_rect.width - 40) // len(slots)
            base_y = panel_rect.centery
            highlight = (ticks // 400) % len(slots)
            for idx, label in enumerate(slots):
                slot_rect = pygame.Rect(panel_rect.left + 20 + idx * slot_width, base_y - 22, slot_width - 10, 44)
                is_active = idx == highlight
                pygame.draw.rect(
                    surface,
                    (200, 220, 255) if is_active else (90, 110, 150),
                    slot_rect,
                    border_radius=10,
                )
                pygame.draw.rect(surface, (255, 255, 255), slot_rect, width=1, border_radius=10)
                text_surface = self.small_font.render(label, True, (20, 30, 50) if is_active else (220, 230, 255))
                surface.blit(text_surface, text_surface.get_rect(center=slot_rect.center))

            arrow_surface = self.small_font.render("↑ 홀드", True, COLOR_TEXT_DIM)
            surface.blit(arrow_surface, arrow_surface.get_rect(center=(center_x, rect.bottom - 20)))
        else:
            idle_text = self.small_font.render("자료 수집 중...", True, COLOR_TEXT_DIM)
            surface.blit(idle_text, idle_text.get_rect(center=rect.center))

    def _reset_detail_scroll(self, *, reset_layout: bool = False) -> None:
        self.detail_scroll_offset = 0.0
        self.detail_scroll_direction = 1
        self.detail_scroll_wait = 0.0
        self._detail_view_height = 0.0
        if reset_layout:
            self._detail_lines = []
            self._detail_total_height = 0.0
            self._detail_layout_key = None

    def _update_detail_layout(self, item: dict, text_width: int) -> None:
        key = (item.get("id"), text_width)
        if self._detail_layout_key == key:
            return

        base_height = self.detail_font.get_height() + 6
        lines: List[dict] = []
        total_height = 0

        paragraphs = item.get("details", [])
        for idx, paragraph in enumerate(paragraphs):
            wrapped = _wrap_text(self.detail_font, paragraph, text_width)
            if not wrapped:
                wrapped = [""]
            for line in wrapped:
                entry = {"text": line, "height": base_height}
                lines.append(entry)
                total_height += entry["height"]
            if idx < len(paragraphs) - 1:
                gap = {"text": None, "height": 12}
                lines.append(gap)
                total_height += gap["height"]

        if not lines:
            entry = {"text": "", "height": base_height}
            lines = [entry]
            total_height = entry["height"]

        self._detail_lines = lines
        self._detail_total_height = total_height
        self.detail_scroll_offset = 0.0
        self.detail_scroll_direction = 1
        self.detail_scroll_wait = 0.0
        self._detail_layout_key = key

    def _draw_lamp(self, surface: pygame.Surface, center: Tuple[int, int], progress: float) -> None:
        wiggle = math.sin(self.elapsed_ms / 180.0) * 6
        base_color = (210, 170, 20)
        accent_color = (235, 200, 60)
        x, y = center

        body_rect = pygame.Rect(0, 0, 200, 70)
        body_rect.center = (x + wiggle, y)
        pygame.draw.ellipse(surface, base_color, body_rect)
        pygame.draw.ellipse(surface, (255, 240, 160), body_rect, 3)

        handle_rect = pygame.Rect(0, 0, 70, 42)
        handle_rect.center = (body_rect.left - 28, body_rect.centery)
        pygame.draw.ellipse(surface, base_color, handle_rect, 5)

        spout_points = [
            (body_rect.right - 20, body_rect.centery - 10),
            (body_rect.right + 70, body_rect.centery - 4 + wiggle * 0.1),
            (body_rect.right - 20, body_rect.centery + 10),
        ]
        pygame.draw.polygon(surface, accent_color, spout_points)
        pygame.draw.polygon(surface, (255, 240, 200), spout_points, 2)

        lid_rect = pygame.Rect(0, 0, 110, 24)
        lid_rect.center = (body_rect.centerx + wiggle, body_rect.top - 8)
        pygame.draw.ellipse(surface, accent_color, lid_rect)
        pygame.draw.ellipse(surface, (255, 240, 200), lid_rect, 2)

        if self.phase == "animation":
            glow_ratio = min(1.0, progress)
            glow_surface = pygame.Surface((body_rect.width + 80, body_rect.height + 80), pygame.SRCALPHA)
            pygame.draw.circle(
                glow_surface,
                (120, 180, 255, int(120 * glow_ratio)),
                (glow_surface.get_width() // 2, glow_surface.get_height() // 2),
                int(140 * glow_ratio),
            )
            surface.blit(glow_surface, glow_surface.get_rect(center=(x, y - 20)))

    def _draw_smoke(self, surface: pygame.Surface, center: Tuple[int, int], progress: float) -> None:
        x, y = center
        ticks = self.elapsed_ms
        for particle in self.smoke_particles:
            delay = particle["delay"]
            life = particle["life"]
            age = particle["born"]
            if age < delay:
                continue
            smoke_age = age - delay
            t = min(1.0, smoke_age / life)
            alpha = int(180 * (1.0 - t))
            radius = particle["radius"] * (0.7 + 0.5 * (1 - t))
            offset_y = y - 70 - 110 * t
            offset_x = x + particle["x"] + math.sin(ticks / 260.0 + particle["x"]) * (14 * (1 - t))

            circle_surface = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
            pygame.draw.circle(circle_surface, (150, 200, 255, alpha), (radius, radius), radius)
            surface.blit(circle_surface, (offset_x - radius, offset_y - radius))
