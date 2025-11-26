# downtown/gacha_designs.py
# 가챠샵 5가지 디자인 모음

import pygame
import math

# 디자인 1: 캡슐 가챠머신 (일본 전통 가챠)
def draw_gacha_capsule_machine(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 1: 캡슐 가챠머신 - 일본 스타일 전통 가챠머신"""
    w, h = building.width, building.height

    # 색상 정의
    MACHINE_RED = (220, 50, 50)
    MACHINE_CHROME = (200, 200, 220)
    GLASS_BLUE = (100, 180, 255, 120)
    CAPSULE_COLORS = [(255, 100, 100), (100, 255, 100), (100, 100, 255), (255, 255, 100)]

    # 기계 베이스 (하단)
    base_h = h * 0.35
    pygame.draw.rect(screen, MACHINE_RED, (x, y + h - base_h, w, base_h), border_radius=8)
    pygame.draw.rect(screen, (180, 40, 40), (x, y + h - base_h, w, base_h), 3, border_radius=8)

    # 유리 돔 (상단)
    dome_h = h * 0.65
    dome_surf = pygame.Surface((w, dome_h), pygame.SRCALPHA)
    pygame.draw.ellipse(dome_surf, GLASS_BLUE, (5, 5, w - 10, dome_h - 10))
    pygame.draw.ellipse(dome_surf, (150, 220, 255, 100), (8, 8, w - 16, dome_h - 16), 2)
    screen.blit(dome_surf, (x, y))

    # 돔 안의 캡슐들 (애니메이션)
    capsule_count = 8
    for i in range(capsule_count):
        angle = animation_timer * 0.5 + i * (math.pi * 2 / capsule_count)
        cx = x + w // 2 + math.cos(angle) * (w * 0.25)
        cy = y + dome_h // 2 + math.sin(angle) * (dome_h * 0.25)
        capsule_color = CAPSULE_COLORS[i % len(CAPSULE_COLORS)]

        # 캡슐 (타원형)
        pygame.draw.ellipse(screen, capsule_color, (cx - 6, cy - 8, 12, 16))
        pygame.draw.ellipse(screen, (255, 255, 255, 150), (cx - 5, cy - 7, 10, 14), 1)
        # 하이라이트
        pygame.draw.circle(screen, (255, 255, 255, 200), (int(cx - 2), int(cy - 3)), 2)

    # 배출구
    outlet_y = y + h - base_h + 10
    pygame.draw.rect(screen, (50, 50, 50), (x + w // 2 - 12, outlet_y, 24, 15), border_radius=4)
    pygame.draw.rect(screen, (100, 100, 100), (x + w // 2 - 12, outlet_y, 24, 15), 2, border_radius=4)

    # 손잡이 (회전 애니메이션)
    handle_x = x + w - 15
    handle_y = y + h - base_h + base_h // 2
    handle_angle = animation_timer * 2
    handle_len = 12
    handle_end_x = handle_x + math.cos(handle_angle) * handle_len
    handle_end_y = handle_y + math.sin(handle_angle) * handle_len
    pygame.draw.line(screen, MACHINE_CHROME, (handle_x, handle_y), (handle_end_x, handle_end_y), 4)
    pygame.draw.circle(screen, (255, 50, 50), (int(handle_end_x), int(handle_end_y)), 5)

    # 로고 플레이트
    logo_y = y + h - base_h + 5
    pygame.draw.rect(screen, (255, 215, 0), (x + 10, logo_y, w - 20, 8), border_radius=2)
    pygame.draw.rect(screen, (200, 170, 0), (x + 10, logo_y, w - 20, 8), 1, border_radius=2)


# 디자인 2: 네온 슬롯머신 (라스베가스 스타일)
def draw_gacha_neon_slot(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 2: 네온 슬롯머신 - 화려한 라스베가스 스타일"""
    w, h = building.width, building.height

    # 색상
    NEON_PINK = (255, 20, 147)
    NEON_CYAN = (0, 255, 255)
    NEON_GOLD = (255, 215, 0)
    DARK_BG = (30, 10, 50)

    # 본체 (어두운 배경)
    pygame.draw.rect(screen, DARK_BG, (x, y, w, h), border_radius=10)
    pygame.draw.rect(screen, NEON_PINK, (x, y, w, h), 3, border_radius=10)

    # 네온 프레임 글로우 (펄스 효과)
    glow_pulse = abs(math.sin(animation_timer * 3))
    for offset in range(3):
        alpha = int(60 * glow_pulse * (1 - offset / 3))
        glow_surf = pygame.Surface((w + offset * 4, h + offset * 4), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*NEON_PINK, alpha), (0, 0, w + offset * 4, h + offset * 4), 2, border_radius=10)
        screen.blit(glow_surf, (x - offset * 2, y - offset * 2))

    # 슬롯 디스플레이 (3개의 릴)
    reel_width = w // 4
    reel_height = h * 0.4
    reel_y = y + h * 0.2
    symbols = ["★", "◆", "♥", "7"]

    for i in range(3):
        reel_x = x + w // 2 - reel_width * 1.5 + i * reel_width

        # 릴 배경
        pygame.draw.rect(screen, (10, 10, 30), (reel_x, reel_y, reel_width - 5, reel_height), border_radius=5)
        pygame.draw.rect(screen, NEON_CYAN, (reel_x, reel_y, reel_width - 5, reel_height), 2, border_radius=5)

        # 회전하는 심볼 (각 릴마다 다른 속도)
        symbol_index = int(animation_timer * (2 + i * 0.5)) % len(symbols)
        font = pygame.font.Font(None, 24)
        symbol_surf = font.render(symbols[symbol_index], True, NEON_GOLD)
        symbol_rect = symbol_surf.get_rect(center=(reel_x + (reel_width - 5) // 2, reel_y + reel_height // 2))
        screen.blit(symbol_surf, symbol_rect)

    # 하단 투입구
    coin_slot_y = y + h - h * 0.25
    pygame.draw.rect(screen, (100, 100, 100), (x + w // 2 - 15, coin_slot_y, 30, 12), border_radius=3)
    pygame.draw.rect(screen, NEON_GOLD, (x + w // 2 - 15, coin_slot_y, 30, 12), 2, border_radius=3)

    # 상단 네온 별 장식
    for i in range(3):
        star_x = x + w // 2 + (i - 1) * 20
        star_y = y + 10
        draw_neon_star(screen, star_x, star_y, 4, NEON_GOLD, animation_timer + i)


# 디자인 3: 마법 보물상자 (판타지 RPG 스타일)
def draw_gacha_magic_chest(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 3: 마법 보물상자 - 판타지 RPG 보물상자"""
    w, h = building.width, building.height

    # 색상
    WOOD_DARK = (101, 67, 33)
    WOOD_LIGHT = (139, 90, 43)
    GOLD = (255, 215, 0)
    MAGIC_PURPLE = (138, 43, 226)
    MAGIC_CYAN = (0, 255, 255)

    # 상자 본체 (나무 질감)
    chest_h = h * 0.7
    chest_y = y + h - chest_h
    pygame.draw.rect(screen, WOOD_DARK, (x, chest_y, w, chest_h), border_radius=5)

    # 나무 판자 효과
    for i in range(5):
        plank_y = chest_y + i * (chest_h // 5)
        pygame.draw.line(screen, WOOD_LIGHT, (x, plank_y), (x + w, plank_y), 2)

    # 금속 장식 띠
    pygame.draw.rect(screen, GOLD, (x, chest_y + chest_h // 3, w, 6))
    pygame.draw.rect(screen, GOLD, (x, chest_y + chest_h * 2 // 3, w, 6))

    # 상자 뚜껑 (반열림 상태 - 애니메이션)
    lid_h = h * 0.35
    lid_angle = math.sin(animation_timer * 2) * 0.1 + 0.2  # 살짝 열린 각도

    # 뚜껑 표면
    lid_points = [
        (x, chest_y),
        (x + w, chest_y),
        (x + w, chest_y - lid_h + lid_angle * 20),
        (x, chest_y - lid_h + lid_angle * 10)
    ]
    pygame.draw.polygon(screen, WOOD_LIGHT, lid_points)
    pygame.draw.polygon(screen, WOOD_DARK, lid_points, 2)

    # 뚜껑 금속 띠
    pygame.draw.line(screen, GOLD, (x, chest_y - lid_h // 2), (x + w, chest_y - lid_h // 2), 4)

    # 자물쇠
    lock_x = x + w // 2
    lock_y = chest_y + chest_h // 2
    pygame.draw.circle(screen, GOLD, (lock_x, lock_y), 8)
    pygame.draw.circle(screen, (200, 170, 0), (lock_x, lock_y), 8, 2)
    pygame.draw.circle(screen, (50, 50, 50), (lock_x, lock_y), 4)

    # 상자에서 나오는 마법 입자들
    particle_count = 12
    for i in range(particle_count):
        angle = animation_timer * 3 + i * (math.pi * 2 / particle_count)
        radius = 15 + math.sin(animation_timer * 4 + i) * 8
        px = lock_x + math.cos(angle) * radius
        py = chest_y - 10 + math.sin(angle) * radius

        # 교차하는 보라색/청록색 입자
        particle_color = MAGIC_PURPLE if i % 2 == 0 else MAGIC_CYAN
        alpha = int(150 * (1 - abs(math.sin(animation_timer * 4 + i))))
        particle_surf = pygame.Surface((6, 6), pygame.SRCALPHA)
        pygame.draw.circle(particle_surf, (*particle_color, alpha), (3, 3), 3)
        screen.blit(particle_surf, (int(px - 3), int(py - 3)))

    # 마법 글로우 (상자 위)
    glow_pulse = abs(math.sin(animation_timer * 4))
    glow_surf = pygame.Surface((w, lid_h + 20), pygame.SRCALPHA)
    glow_alpha = int(60 * glow_pulse)
    pygame.draw.ellipse(glow_surf, (*MAGIC_PURPLE, glow_alpha), (5, 0, w - 10, lid_h + 20))
    screen.blit(glow_surf, (x, chest_y - lid_h - 10))


# 디자인 4: 우주 포탈 (SF 차원문 스타일)
def draw_gacha_space_portal(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 4: 우주 포탈 - SF 차원문 가챠"""
    w, h = building.width, building.height

    # 색상
    PORTAL_BLUE = (0, 100, 255)
    PORTAL_CYAN = (0, 255, 255)
    PORTAL_PURPLE = (150, 0, 255)
    TECH_GRAY = (80, 80, 100)

    # 프레임 베이스
    frame_padding = 8
    pygame.draw.rect(screen, TECH_GRAY, (x, y, w, h), border_radius=12)
    pygame.draw.rect(screen, (120, 120, 140), (x, y, w, h), 3, border_radius=12)

    # 테크 패널 디테일
    for i in range(4):
        corner_size = 10
        corners = [
            (x + 2, y + 2),  # 좌상단
            (x + w - corner_size - 2, y + 2),  # 우상단
            (x + 2, y + h - corner_size - 2),  # 좌하단
            (x + w - corner_size - 2, y + h - corner_size - 2)  # 우하단
        ]
        corner_x, corner_y = corners[i]
        pygame.draw.rect(screen, (150, 150, 170), (corner_x, corner_y, corner_size, corner_size), 1)

    # 포탈 중심 (회전하는 에너지 소용돌이)
    center_x = x + w // 2
    center_y = y + h // 2
    portal_radius = min(w, h) // 3

    # 배경 어두운 원 (차원의 틈)
    pygame.draw.circle(screen, (10, 10, 30), (center_x, center_y), portal_radius + 5)

    # 다층 회전 링
    num_rings = 5
    for ring in range(num_rings):
        ring_radius = portal_radius * (1 - ring * 0.15)
        ring_speed = 1 + ring * 0.3
        ring_angle = animation_timer * ring_speed * (1 if ring % 2 == 0 else -1)

        # 링 색상 (그라데이션)
        ring_progress = ring / num_rings
        r = int(PORTAL_BLUE[0] * (1 - ring_progress) + PORTAL_PURPLE[0] * ring_progress)
        g = int(PORTAL_BLUE[1] * (1 - ring_progress) + PORTAL_PURPLE[1] * ring_progress)
        b = int(PORTAL_BLUE[2] * (1 - ring_progress) + PORTAL_PURPLE[2] * ring_progress)
        ring_color = (r, g, b)

        # 링 세그먼트 (불완전한 원)
        segments = 6
        for seg in range(segments):
            start_angle = ring_angle + seg * (math.pi * 2 / segments)
            end_angle = start_angle + (math.pi * 2 / segments) * 0.7  # 70% 호

            # 호 그리기
            points = [(center_x, center_y)]
            for angle in [start_angle + i * 0.1 for i in range(int((end_angle - start_angle) / 0.1))]:
                px = center_x + math.cos(angle) * ring_radius
                py = center_y + math.sin(angle) * ring_radius
                points.append((px, py))

            if len(points) > 2:
                pygame.draw.lines(screen, ring_color, False, points, 2)

    # 중심 에너지 코어 (펄스)
    core_pulse = abs(math.sin(animation_timer * 5))
    core_size = int(8 + core_pulse * 5)
    core_surf = pygame.Surface((core_size * 2, core_size * 2), pygame.SRCALPHA)
    pygame.draw.circle(core_surf, (*PORTAL_CYAN, 200), (core_size, core_size), core_size)
    pygame.draw.circle(core_surf, (255, 255, 255, 255), (core_size, core_size), core_size // 2)
    screen.blit(core_surf, (center_x - core_size, center_y - core_size))

    # 에너지 파티클 (포탈 주변)
    particle_count = 16
    for i in range(particle_count):
        angle = animation_timer * 4 + i * (math.pi * 2 / particle_count)
        distance = portal_radius + 10 + math.sin(animation_timer * 6 + i) * 8
        px = center_x + math.cos(angle) * distance
        py = center_y + math.sin(angle) * distance

        particle_alpha = int(200 * abs(math.sin(animation_timer * 3 + i)))
        particle_surf = pygame.Surface((4, 4), pygame.SRCALPHA)
        pygame.draw.circle(particle_surf, (*PORTAL_CYAN, particle_alpha), (2, 2), 2)
        screen.blit(particle_surf, (int(px - 2), int(py - 2)))


# 디자인 5: 무지개 분수대 (테마파크 스타일)
def draw_gacha_rainbow_fountain(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 5: 무지개 분수대 - 화려한 테마파크 가챠"""
    w, h = building.width, building.height

    # 색상
    FOUNTAIN_BASE = (220, 220, 240)
    WATER_BLUE = (100, 180, 255, 150)
    RAINBOW_COLORS = [
        (255, 0, 0),    # 빨강
        (255, 165, 0),  # 주황
        (255, 255, 0),  # 노랑
        (0, 255, 0),    # 초록
        (0, 127, 255),  # 파랑
        (148, 0, 211)   # 보라
    ]

    # 분수대 베이스 (3단 구조)
    for tier in range(3):
        tier_w = w * (1 - tier * 0.2)
        tier_h = h // 4
        tier_x = x + (w - tier_w) // 2
        tier_y = y + h - tier_h * (tier + 1)

        pygame.draw.ellipse(screen, FOUNTAIN_BASE, (tier_x, tier_y, tier_w, tier_h))
        pygame.draw.ellipse(screen, (180, 180, 200), (tier_x, tier_y, tier_w, tier_h), 2)

        # 물 표면 (반투명)
        water_surf = pygame.Surface((tier_w, tier_h // 2), pygame.SRCALPHA)
        pygame.draw.ellipse(water_surf, WATER_BLUE, (0, 0, tier_w, tier_h // 2))
        screen.blit(water_surf, (tier_x, tier_y + tier_h // 4))

    # 중앙 분수 기둥
    pillar_w = w // 5
    pillar_h = h * 0.6
    pillar_x = x + w // 2 - pillar_w // 2
    pillar_y = y + h - pillar_h
    pygame.draw.rect(screen, FOUNTAIN_BASE, (pillar_x, pillar_y, pillar_w, pillar_h))
    pygame.draw.rect(screen, (180, 180, 200), (pillar_x, pillar_y, pillar_w, pillar_h), 2)

    # 무지개 물줄기 (위로 솟아오름)
    fountain_jets = 6
    for i in range(fountain_jets):
        angle = animation_timer * 2 + i * (math.pi * 2 / fountain_jets)

        # 물줄기 궤적
        start_x = x + w // 2 + math.cos(angle) * (pillar_w // 2)
        start_y = pillar_y

        # 포물선 궤적
        for step in range(15):
            t = step / 15
            jet_x = start_x + math.cos(angle) * t * 20
            jet_y = start_y - (h * 0.3) * (1 - (t - 0.5) ** 2 * 4)  # 포물선

            # 무지개 색상 (높이에 따라)
            color_index = int(t * len(RAINBOW_COLORS)) % len(RAINBOW_COLORS)
            jet_color = RAINBOW_COLORS[color_index]

            # 물방울 크기 (아래가 크고 위가 작음)
            droplet_size = int(3 * (1 - t) + 1)
            alpha = int(200 * (1 - t))

            droplet_surf = pygame.Surface((droplet_size * 2, droplet_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(droplet_surf, (*jet_color, alpha), (droplet_size, droplet_size), droplet_size)
            screen.blit(droplet_surf, (int(jet_x - droplet_size), int(jet_y - droplet_size)))

    # 상단 무지개 글로우 링
    glow_pulse = abs(math.sin(animation_timer * 3))
    for i, color in enumerate(RAINBOW_COLORS):
        ring_radius = 15 + i * 3 + glow_pulse * 3
        ring_alpha = int(80 * (1 - i / len(RAINBOW_COLORS)))
        ring_surf = pygame.Surface((ring_radius * 2 + 4, ring_radius * 2 + 4), pygame.SRCALPHA)
        pygame.draw.circle(ring_surf, (*color, ring_alpha), (ring_radius + 2, ring_radius + 2), ring_radius, 2)
        screen.blit(ring_surf, (x + w // 2 - ring_radius - 2, y + 10 - ring_radius - 2))

    # 상단 골드 스타
    star_x = x + w // 2
    star_y = y + 10
    draw_neon_star(screen, star_x, star_y, 6, (255, 215, 0), animation_timer)


# 헬퍼 함수: 네온 별 그리기
def draw_neon_star(screen, x, y, size, color, animation_timer):
    """네온 스타일 별 그리기"""
    rotation = animation_timer * 2
    points = []
    for i in range(10):
        angle = rotation + i * math.pi / 5 - math.pi / 2
        r = size if i % 2 == 0 else size * 0.4
        px = x + r * math.cos(angle)
        py = y + r * math.sin(angle)
        points.append((px, py))

    # 글로우 효과
    glow_pulse = abs(math.sin(animation_timer * 4))
    for layer in range(3):
        glow_alpha = int((80 - layer * 20) * glow_pulse)
        glow_surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*color, glow_alpha), (size * 3 // 2, size * 3 // 2), size + layer * 2)
        screen.blit(glow_surf, (x - size * 3 // 2, y - size * 3 // 2))

    # 별 본체
    pygame.draw.polygon(screen, color, points)
    pygame.draw.polygon(screen, (255, 255, 255), points, 1)


# 디자인 딕셔너리 (1-5번)
GACHA_DESIGNS = {
    1: draw_gacha_capsule_machine,
    2: draw_gacha_neon_slot,
    3: draw_gacha_magic_chest,
    4: draw_gacha_space_portal,
    5: draw_gacha_rainbow_fountain
}
