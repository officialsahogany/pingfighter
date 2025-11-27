#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
STORE 건물 5가지 고퀄리티 디자인 미리보기
실행: python3 downtown/preview_store_designs.py
"""

import pygame
import math
import sys
import os

# 프로젝트 루트 경로 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

pygame.init()

# UHD 프리뷰용 화면 크기
PREVIEW_WIDTH = 1400
PREVIEW_HEIGHT = 900
screen = pygame.display.set_mode((PREVIEW_WIDTH, PREVIEW_HEIGHT))
pygame.display.set_caption("🏪 STORE 건물 디자인 선택 - 5가지 고퀄리티 디자인")

# 폰트 설정
try:
    font_large = pygame.font.Font(None, 48)
    font_medium = pygame.font.Font(None, 32)
    font_small = pygame.font.Font(None, 24)
except:
    font_large = pygame.font.SysFont('arial', 36)
    font_medium = pygame.font.SysFont('arial', 24)
    font_small = pygame.font.SysFont('arial', 18)


# =============================================================================
# 5가지 STORE 디자인 정의
# =============================================================================
STORE_DESIGNS = {
    1: {
        "name": "네온 메가스토어",
        "name_en": "NEON MEGASTORE",
        "description": "사이버펑크 홀로그램 쇼핑몰",
        "style": "cyberpunk_mega",
        "color": (255, 0, 100),
        "secondary": (0, 255, 200),
        "tertiary": (100, 0, 255),
    },
    2: {
        "name": "크리스탈 부티크",
        "name_en": "CRYSTAL BOUTIQUE",
        "description": "럭셔리 다이아몬드 명품관",
        "style": "crystal_luxury",
        "color": (180, 220, 255),
        "secondary": (255, 215, 0),
        "tertiary": (200, 150, 255),
    },
    3: {
        "name": "스팀펑크 백화점",
        "name_en": "STEAMWORK DEPT.",
        "description": "증기기관 시대의 기계식 상점",
        "style": "steampunk_dept",
        "color": (184, 134, 11),
        "secondary": (205, 127, 50),
        "tertiary": (139, 90, 43),
    },
    4: {
        "name": "마법 엠포리움",
        "name_en": "MAGIC EMPORIUM",
        "description": "고대 마법사의 신비로운 상점",
        "style": "magic_emporium",
        "color": (138, 43, 226),
        "secondary": (255, 100, 255),
        "tertiary": (50, 255, 200),
    },
    5: {
        "name": "플라즈마 허브",
        "name_en": "PLASMA HUB",
        "description": "미래형 에너지 기반 상점",
        "style": "plasma_hub",
        "color": (0, 200, 255),
        "secondary": (255, 100, 0),
        "tertiary": (0, 255, 100),
    },
}


class StoreDesignRenderer:
    """고퀄리티 STORE 디자인 렌더러"""

    def __init__(self):
        self.animation_timer = 0
        self.particles = {i: [] for i in range(1, 6)}

    def update(self, dt):
        self.animation_timer += dt

        # 파티클 업데이트
        for design_id in self.particles:
            for p in self.particles[design_id][:]:
                p['life'] -= dt
                p['x'] += p.get('vx', 0) * dt
                p['y'] += p.get('vy', 0) * dt
                if p['life'] <= 0:
                    self.particles[design_id].remove(p)

    def draw_store(self, screen, design_id, x, y, w, h):
        """디자인별 상점 그리기"""
        design = STORE_DESIGNS[design_id]

        if design["style"] == "cyberpunk_mega":
            self._draw_cyberpunk_mega(screen, design, x, y, w, h, design_id)
        elif design["style"] == "crystal_luxury":
            self._draw_crystal_luxury(screen, design, x, y, w, h, design_id)
        elif design["style"] == "steampunk_dept":
            self._draw_steampunk_dept(screen, design, x, y, w, h, design_id)
        elif design["style"] == "magic_emporium":
            self._draw_magic_emporium(screen, design, x, y, w, h, design_id)
        elif design["style"] == "plasma_hub":
            self._draw_plasma_hub(screen, design, x, y, w, h, design_id)

    # =========================================================================
    # 디자인 1: 네온 메가스토어 (사이버펑크)
    # =========================================================================
    def _draw_cyberpunk_mega(self, screen, design, x, y, w, h, design_id):
        """네온 메가스토어 - 홀로그램 사이버펑크 쇼핑몰"""
        color = design["color"]
        secondary = design["secondary"]
        tertiary = design["tertiary"]

        pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 2.5))
        wave = math.sin(self.animation_timer * 3)

        # === 건물 그림자 (3D 효과) ===
        shadow_surf = pygame.Surface((w + 20, 20), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 80), (0, 0, w + 20, 20))
        screen.blit(shadow_surf, (x - 10, y + h - 5))

        # === 메인 건물 (메탈릭 그라데이션) ===
        for i in range(h - 30):
            metal_r = 25 + int(15 * math.sin(i * 0.03 + self.animation_timer))
            metal_g = 25 + int(15 * math.sin(i * 0.03 + self.animation_timer + 1))
            metal_b = 35 + int(15 * math.sin(i * 0.03 + self.animation_timer + 2))
            pygame.draw.line(screen, (metal_r, metal_g, metal_b),
                           (x, y + 30 + i), (x + w, y + 30 + i))

        # 건물 테두리 (네온 글로우)
        for glow_i in range(5):
            glow_alpha = int(150 * pulse / (glow_i + 1))
            pygame.draw.rect(screen, (*color, glow_alpha),
                           (x - glow_i * 2, y + 28 - glow_i, w + glow_i * 4, h - 28 + glow_i * 2),
                           2, border_radius=8)

        # === 대형 홀로그램 간판 "STORE" ===
        sign_y = y + 5
        sign_h = 28
        sign_w = w - 10
        sign_x = x + 5

        # 간판 배경 (투명 홀로그램)
        sign_surf = pygame.Surface((sign_w, sign_h), pygame.SRCALPHA)
        for i in range(sign_h):
            scan_alpha = int(80 + 40 * math.sin(i * 0.5 + self.animation_timer * 5))
            pygame.draw.line(sign_surf, (20, 20, 40, scan_alpha), (0, i), (sign_w, i))
        screen.blit(sign_surf, (sign_x, sign_y))

        # 스캔라인 효과
        scan_y = int((self.animation_timer * 50) % sign_h)
        pygame.draw.line(screen, (*secondary, 150), (sign_x, sign_y + scan_y), (sign_x + sign_w, sign_y + scan_y), 2)

        # 네온 글로우 테두리
        for glow_i in range(6):
            glow_alpha = int(200 * pulse / (glow_i + 1))
            pygame.draw.rect(screen, (*secondary, glow_alpha),
                           (sign_x - glow_i, sign_y - glow_i, sign_w + glow_i * 2, sign_h + glow_i * 2),
                           1, border_radius=5)

        # "STORE" 글자 (픽셀 네온 폰트)
        self._draw_neon_text_store(screen, sign_x + 10, sign_y + 5, color, secondary, pulse)

        # === 3D 유리 쇼윈도우 ===
        window_y = y + h - 70
        window_h = 50
        window_w = w - 20
        window_x = x + 10

        # 유리 반사 효과
        glass_surf = pygame.Surface((window_w, window_h), pygame.SRCALPHA)
        for i in range(window_h):
            glass_alpha = int(100 + 50 * math.sin(i * 0.1 + self.animation_timer * 2))
            r = int(40 + 20 * (1 - i / window_h))
            g = int(80 + 40 * (1 - i / window_h))
            b = int(120 + 60 * (1 - i / window_h))
            pygame.draw.line(glass_surf, (r, g, b, glass_alpha), (0, i), (window_w, i))
        screen.blit(glass_surf, (window_x, window_y))

        # 홀로그램 상품 디스플레이
        for i in range(5):
            item_x = window_x + 15 + i * 22
            item_y = window_y + window_h // 2
            item_offset = int(3 * math.sin(self.animation_timer * 3 + i * 0.8))
            item_alpha = int(200 + 55 * math.sin(self.animation_timer * 2 + i))

            # 홀로그램 아이템 (회전하는 큐브)
            item_size = 8 + int(2 * abs(math.sin(self.animation_timer * 2 + i)))
            pygame.draw.rect(screen, (*tertiary, item_alpha),
                           (item_x - item_size // 2, item_y + item_offset - item_size // 2,
                            item_size, item_size), border_radius=2)
            # 홀로그램 글로우
            for g in range(3):
                pygame.draw.rect(screen, (*secondary, item_alpha // (g + 2)),
                               (item_x - item_size // 2 - g * 2, item_y + item_offset - item_size // 2 - g * 2,
                                item_size + g * 4, item_size + g * 4), 1, border_radius=3)

        pygame.draw.rect(screen, (*secondary, 200), (window_x, window_y, window_w, window_h), 2, border_radius=5)

        # === 자동 슬라이딩 문 ===
        door_w = w // 3
        door_h = 45
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h - 5

        slide_offset = int(8 * abs(math.sin(self.animation_timer * 0.8)))

        # 문 프레임
        pygame.draw.rect(screen, (40, 40, 50), (door_x - 3, door_y - 3, door_w + 6, door_h + 6), border_radius=3)

        # 슬라이딩 문
        left_door = pygame.Rect(door_x, door_y, door_w // 2 - slide_offset, door_h)
        right_door = pygame.Rect(door_x + door_w // 2 + slide_offset, door_y, door_w // 2 - slide_offset, door_h)

        pygame.draw.rect(screen, (60, 60, 80), left_door, border_radius=2)
        pygame.draw.rect(screen, (60, 60, 80), right_door, border_radius=2)
        pygame.draw.rect(screen, (*color, int(200 * pulse)), left_door, 2, border_radius=2)
        pygame.draw.rect(screen, (*color, int(200 * pulse)), right_door, 2, border_radius=2)

        # 센서
        sensor_alpha = int(255 * abs(math.sin(self.animation_timer * 4)))
        pygame.draw.circle(screen, (*secondary, sensor_alpha), (door_x + door_w // 2, door_y - 5), 4)

        # === 지붕 네온 라인 ===
        for i in range(3):
            line_y = y + 30 + i * 3
            line_alpha = int(180 * pulse / (i + 1))
            pygame.draw.line(screen, (*color, line_alpha), (x + 5, line_y), (x + w - 5, line_y), 2)

        # === 파티클 (떨어지는 네온 입자) ===
        if len(self.particles[design_id]) < 15 and self.animation_timer % 0.2 < 0.05:
            import random
            self.particles[design_id].append({
                'x': x + random.randint(10, w - 10),
                'y': y,
                'vx': random.uniform(-10, 10),
                'vy': random.uniform(30, 60),
                'life': random.uniform(1.5, 2.5),
                'color': secondary if random.random() > 0.5 else color
            })

        for p in self.particles[design_id]:
            p_alpha = int(200 * (p['life'] / 2.5))
            pygame.draw.circle(screen, (*p['color'], p_alpha), (int(p['x']), int(p['y'])), 2)
            pygame.draw.circle(screen, (*p['color'], p_alpha // 2), (int(p['x']), int(p['y'])), 4)

    # =========================================================================
    # 디자인 2: 크리스탈 부티크 (럭셔리)
    # =========================================================================
    def _draw_crystal_luxury(self, screen, design, x, y, w, h, design_id):
        """크리스탈 부티크 - 럭셔리 다이아몬드 명품관"""
        color = design["color"]
        secondary = design["secondary"]
        tertiary = design["tertiary"]

        pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 1.5))
        sparkle = abs(math.sin(self.animation_timer * 5))

        # === 대리석 건물 본체 ===
        marble_surf = pygame.Surface((w, h - 20), pygame.SRCALPHA)
        for i in range(h - 20):
            # 대리석 그라데이션
            marble_r = int(230 + 20 * math.sin(i * 0.02 + self.animation_timer * 0.5))
            marble_g = int(220 + 20 * math.sin(i * 0.02 + self.animation_timer * 0.5 + 1))
            marble_b = int(240 + 15 * math.sin(i * 0.02 + self.animation_timer * 0.5 + 2))
            pygame.draw.line(marble_surf, (marble_r, marble_g, marble_b), (0, i), (w, i))

        # 대리석 무늬
        for _ in range(8):
            vein_x = int((self.animation_timer * 10 + _ * 30) % w)
            vein_y = 20 + int(_ * 15 + 10 * math.sin(self.animation_timer + _))
            if vein_y < h - 20:
                pygame.draw.line(marble_surf, (200, 200, 210, 100),
                               (vein_x, vein_y), (vein_x + 20, vein_y + 30), 1)

        screen.blit(marble_surf, (x, y + 20))

        # 금테두리
        for glow_i in range(4):
            glow_alpha = int(200 * pulse / (glow_i + 1))
            pygame.draw.rect(screen, (*secondary, glow_alpha),
                           (x - glow_i, y + 18 - glow_i, w + glow_i * 2, h - 18 + glow_i * 2),
                           2, border_radius=3)

        # === 크리스탈 지붕 (다이아몬드 컷) ===
        roof_points = [
            (x + w // 2, y),
            (x + w // 4, y + 18),
            (x + w * 3 // 4, y + 18),
        ]

        # 다층 크리스탈
        for layer in range(5):
            layer_offset = layer * 2
            crystal_color = (
                max(0, int(color[0] - layer * 10)),
                max(0, int(color[1] - layer * 10)),
                max(0, int(color[2] - layer * 5))
            )
            layer_points = [
                (roof_points[0][0], roof_points[0][1] + layer_offset),
                (roof_points[1][0] + layer_offset, roof_points[1][1]),
                (roof_points[2][0] - layer_offset, roof_points[2][1]),
            ]
            pygame.draw.polygon(screen, crystal_color, layer_points)

        # 크리스탈 하이라이트
        pygame.draw.line(screen, (255, 255, 255, int(200 * sparkle)),
                        (x + w // 2, y + 3), (x + w // 3, y + 15), 2)

        # === 황금 "STORE" 간판 ===
        sign_y = y + 22
        sign_h = 24
        sign_w = w - 20
        sign_x = x + 10

        # 금색 배경판
        gold_surf = pygame.Surface((sign_w, sign_h), pygame.SRCALPHA)
        for i in range(sign_h):
            gold_r = int(180 + 40 * math.sin(i * 0.3 + self.animation_timer * 2))
            gold_g = int(140 + 40 * math.sin(i * 0.3 + self.animation_timer * 2))
            gold_b = 50
            pygame.draw.line(gold_surf, (gold_r, gold_g, gold_b), (0, i), (sign_w, i))
        screen.blit(gold_surf, (sign_x, sign_y))

        pygame.draw.rect(screen, secondary, (sign_x, sign_y, sign_w, sign_h), 3, border_radius=4)

        # 금색 양각 글자 "STORE"
        self._draw_embossed_text_store(screen, sign_x + 15, sign_y + 4, secondary)

        # === 유리 쇼케이스 ===
        case_y = y + h - 65
        case_h = 45
        case_w = w - 16
        case_x = x + 8

        # 유리 효과
        glass_surf = pygame.Surface((case_w, case_h), pygame.SRCALPHA)
        for i in range(case_h):
            glass_alpha = int(60 + 30 * math.sin(i * 0.2 + self.animation_timer))
            pygame.draw.line(glass_surf, (200, 220, 255, glass_alpha), (0, i), (case_w, i))
        screen.blit(glass_surf, (case_x, case_y))

        # 보석 디스플레이
        gem_colors = [(255, 50, 50), (50, 255, 50), (50, 50, 255), (255, 255, 50)]
        for i, gem_color in enumerate(gem_colors):
            gem_x = case_x + 20 + i * 25
            gem_y = case_y + case_h // 2
            gem_offset = int(2 * math.sin(self.animation_timer * 2 + i))

            # 다이아몬드 형태
            diamond_points = [
                (gem_x, gem_y - 8 + gem_offset),
                (gem_x - 6, gem_y + gem_offset),
                (gem_x, gem_y + 8 + gem_offset),
                (gem_x + 6, gem_y + gem_offset),
            ]
            pygame.draw.polygon(screen, gem_color, diamond_points)
            pygame.draw.polygon(screen, (255, 255, 255), diamond_points, 1)

            # 반짝임
            if int(self.animation_timer * 3) % 4 == i:
                pygame.draw.circle(screen, (255, 255, 255, int(255 * sparkle)), (gem_x, gem_y - 5 + gem_offset), 3)

        pygame.draw.rect(screen, (*secondary, 200), (case_x, case_y, case_w, case_h), 2, border_radius=4)

        # === 황금 아치 문 ===
        door_w = w // 3
        door_h = 40
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h - 5

        # 아치 형태
        pygame.draw.rect(screen, (60, 50, 40), (door_x, door_y + 10, door_w, door_h - 10), border_radius=3)
        pygame.draw.ellipse(screen, (60, 50, 40), (door_x, door_y, door_w, 20))

        # 금테두리
        pygame.draw.rect(screen, secondary, (door_x, door_y + 10, door_w, door_h - 10), 2, border_radius=3)
        pygame.draw.ellipse(screen, secondary, (door_x, door_y, door_w, 20), 2)

        # 금 손잡이
        pygame.draw.circle(screen, secondary, (door_x + door_w // 2, door_y + door_h // 2 + 5), 4)

        # === 스파클 파티클 ===
        if len(self.particles[design_id]) < 12 and self.animation_timer % 0.3 < 0.05:
            import random
            self.particles[design_id].append({
                'x': x + random.randint(5, w - 5),
                'y': y + random.randint(5, h - 5),
                'vx': random.uniform(-5, 5),
                'vy': random.uniform(-20, -5),
                'life': random.uniform(0.5, 1.5),
                'color': (255, 255, 255)
            })

        for p in self.particles[design_id]:
            p_alpha = int(255 * (p['life'] / 1.5))
            size = int(3 * (p['life'] / 1.5))
            pygame.draw.circle(screen, (*p['color'], p_alpha), (int(p['x']), int(p['y'])), size)

    # =========================================================================
    # 디자인 3: 스팀펑크 백화점
    # =========================================================================
    def _draw_steampunk_dept(self, screen, design, x, y, w, h, design_id):
        """스팀펑크 백화점 - 증기기관 시대의 기계식 상점"""
        color = design["color"]
        secondary = design["secondary"]
        tertiary = design["tertiary"]

        pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 1.2))
        gear_rotation = self.animation_timer * 2

        # === 벽돌 건물 본체 ===
        brick_color = (120, 70, 50)
        for row in range(0, h - 25, 10):
            offset = 8 if (row // 10) % 2 else 0
            for col in range(-offset, w, 18):
                bx = x + col
                by = y + 25 + row
                if bx >= x and bx + 16 <= x + w:
                    # 벽돌 그라데이션
                    brick_r = int(brick_color[0] + 20 * math.sin(row * 0.1 + col * 0.05))
                    brick_g = int(brick_color[1] + 15 * math.sin(row * 0.1 + col * 0.05))
                    brick_b = int(brick_color[2] + 10 * math.sin(row * 0.1 + col * 0.05))
                    pygame.draw.rect(screen, (brick_r, brick_g, brick_b), (bx, by, 16, 8), border_radius=1)

        # 건물 테두리
        pygame.draw.rect(screen, tertiary, (x, y + 25, w, h - 25), 3, border_radius=5)

        # === 황동 지붕 ===
        roof_surf = pygame.Surface((w + 20, 30), pygame.SRCALPHA)
        for i in range(25):
            brass_r = max(0, int(color[0] - i * 2))
            brass_g = max(0, int(color[1] - i * 2))
            brass_b = max(0, int(color[2] - i))
            pygame.draw.line(roof_surf, (brass_r, brass_g, brass_b), (0, i), (w + 20, i))
        screen.blit(roof_surf, (x - 10, y))

        # 리벳
        for i in range(0, w, 15):
            pygame.draw.circle(screen, secondary, (x + i + 7, y + 12), 3)
            pygame.draw.circle(screen, (255, 255, 200), (x + i + 6, y + 11), 1)

        # === 회전하는 기어 장식 ===
        gear_positions = [(x + 20, y + 45), (x + w - 20, y + 45), (x + w // 2, y + 35)]
        gear_sizes = [15, 15, 20]

        for (gx, gy), gs in zip(gear_positions, gear_sizes):
            # 기어 그리기
            for tooth in range(8):
                angle = gear_rotation + tooth * (math.pi / 4)
                tooth_x = gx + int(gs * 0.8 * math.cos(angle))
                tooth_y = gy + int(gs * 0.8 * math.sin(angle))
                pygame.draw.rect(screen, color,
                               (tooth_x - 3, tooth_y - 3, 6, 6), border_radius=1)

            pygame.draw.circle(screen, color, (gx, gy), gs // 2)
            pygame.draw.circle(screen, secondary, (gx, gy), gs // 2, 2)
            pygame.draw.circle(screen, tertiary, (gx, gy), gs // 4)

        # === 황동 프레임 "STORE" 간판 ===
        sign_y = y + 50
        sign_h = 22
        sign_w = w - 20
        sign_x = x + 10

        # 황동 플레이트
        pygame.draw.rect(screen, color, (sign_x, sign_y, sign_w, sign_h), border_radius=3)
        pygame.draw.rect(screen, secondary, (sign_x, sign_y, sign_w, sign_h), 2, border_radius=3)

        # 양각 효과
        pygame.draw.line(screen, (255, 220, 150), (sign_x + 2, sign_y + 2), (sign_x + sign_w - 2, sign_y + 2))
        pygame.draw.line(screen, tertiary, (sign_x + 2, sign_y + sign_h - 2), (sign_x + sign_w - 2, sign_y + sign_h - 2))

        # "STORE" 글자 (각인 스타일)
        self._draw_engraved_text_store(screen, sign_x + 20, sign_y + 3, tertiary, (255, 220, 150))

        # === 둥근 창문 ===
        window_y = y + h - 60
        window_r = 20
        window_positions = [x + 25, x + w - 25]

        for wx in window_positions:
            # 창문 프레임
            pygame.draw.circle(screen, secondary, (wx, window_y), window_r + 3)
            pygame.draw.circle(screen, (40, 30, 25), (wx, window_y), window_r)

            # 유리 (따뜻한 빛)
            glow_alpha = int(150 + 100 * pulse)
            pygame.draw.circle(screen, (255, 200, 100, glow_alpha), (wx, window_y), window_r - 3)

            # 십자 프레임
            pygame.draw.line(screen, secondary, (wx - window_r + 3, window_y), (wx + window_r - 3, window_y), 2)
            pygame.draw.line(screen, secondary, (wx, window_y - window_r + 3), (wx, window_y + window_r - 3), 2)

        # === 아치형 문 ===
        door_w = w // 3
        door_h = 40
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h - 5

        pygame.draw.rect(screen, (50, 35, 25), (door_x, door_y + 8, door_w, door_h - 8), border_radius=2)
        pygame.draw.ellipse(screen, (50, 35, 25), (door_x, door_y, door_w, 16))
        pygame.draw.rect(screen, secondary, (door_x, door_y + 8, door_w, door_h - 8), 2, border_radius=2)
        pygame.draw.ellipse(screen, secondary, (door_x, door_y, door_w, 16), 2)

        # 황동 손잡이
        pygame.draw.circle(screen, color, (door_x + door_w // 2, door_y + door_h // 2 + 5), 5)
        pygame.draw.circle(screen, secondary, (door_x + door_w // 2, door_y + door_h // 2 + 5), 5, 2)

        # === 증기 파티클 ===
        if len(self.particles[design_id]) < 10 and self.animation_timer % 0.4 < 0.05:
            import random
            self.particles[design_id].append({
                'x': x + w // 2 + random.randint(-10, 10),
                'y': y + 10,
                'vx': random.uniform(-5, 5),
                'vy': random.uniform(-30, -15),
                'life': random.uniform(1.0, 2.0),
                'color': (200, 200, 200)
            })

        for p in self.particles[design_id]:
            p_alpha = int(150 * (p['life'] / 2.0))
            size = int(5 * (2.0 - p['life']) / 2.0) + 2
            pygame.draw.circle(screen, (*p['color'], p_alpha), (int(p['x']), int(p['y'])), size)

    # =========================================================================
    # 디자인 4: 마법 엠포리움
    # =========================================================================
    def _draw_magic_emporium(self, screen, design, x, y, w, h, design_id):
        """마법 엠포리움 - 고대 마법사의 신비로운 상점"""
        color = design["color"]
        secondary = design["secondary"]
        tertiary = design["tertiary"]

        pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 2))
        magic_flow = self.animation_timer * 3

        # === 마법 오라 배경 ===
        for i in range(5):
            aura_size = 30 - i * 5
            aura_alpha = int(80 * pulse / (i + 1))
            aura_surf = pygame.Surface((w + aura_size * 2, h + aura_size * 2), pygame.SRCALPHA)
            pygame.draw.ellipse(aura_surf, (*color, aura_alpha), (0, 0, w + aura_size * 2, h + aura_size * 2))
            screen.blit(aura_surf, (x - aura_size, y - aura_size))

        # === 고대 석조 건물 ===
        stone_surf = pygame.Surface((w, h - 15), pygame.SRCALPHA)
        for i in range(h - 15):
            stone_r = int(60 + 20 * math.sin(i * 0.05 + self.animation_timer * 0.3))
            stone_g = int(50 + 20 * math.sin(i * 0.05 + self.animation_timer * 0.3))
            stone_b = int(80 + 30 * math.sin(i * 0.05 + self.animation_timer * 0.3))
            pygame.draw.line(stone_surf, (stone_r, stone_g, stone_b), (0, i), (w, i))

        # 돌 무늬
        for row in range(0, h - 15, 20):
            offset = 15 if (row // 20) % 2 else 0
            for col in range(-offset, w, 30):
                if 0 <= col < w - 28:
                    pygame.draw.rect(stone_surf, (50, 40, 70, 100), (col, row, 28, 18), 1)

        screen.blit(stone_surf, (x, y + 15))

        # 마법 빛 테두리
        for glow_i in range(4):
            glow_alpha = int(180 * pulse / (glow_i + 1))
            pygame.draw.rect(screen, (*secondary, glow_alpha),
                           (x - glow_i * 2, y + 13 - glow_i, w + glow_i * 4, h - 13 + glow_i * 2),
                           2, border_radius=8)

        # === 마법사 모자 지붕 ===
        hat_points = [
            (x + w // 2, y - 10),
            (x + 5, y + 15),
            (x + w - 5, y + 15),
        ]

        # 다층 지붕
        for layer in range(4):
            layer_color = (
                max(0, int(color[0] - layer * 15)),
                max(0, int(color[1] - layer * 15)),
                max(0, int(color[2] - layer * 10))
            )
            offset = layer * 3
            layer_points = [
                (hat_points[0][0], hat_points[0][1] + offset),
                (hat_points[1][0] + offset, hat_points[1][1]),
                (hat_points[2][0] - offset, hat_points[2][1]),
            ]
            pygame.draw.polygon(screen, layer_color, layer_points)

        pygame.draw.polygon(screen, secondary, hat_points, 2)

        # 별 장식
        star_x, star_y = x + w // 2, y - 5
        star_alpha = int(255 * pulse)
        for i in range(5):
            angle = magic_flow + i * (math.pi * 2 / 5)
            sx = star_x + int(8 * math.cos(angle))
            sy = star_y + int(8 * math.sin(angle))
            pygame.draw.line(screen, (*secondary, star_alpha), (star_x, star_y), (sx, sy), 2)
        pygame.draw.circle(screen, (*secondary, star_alpha), (star_x, star_y), 4)

        # === 마법 간판 "STORE" ===
        sign_y = y + 20
        sign_h = 22
        sign_w = w - 16
        sign_x = x + 8

        # 고대 양피지 스타일
        parchment_surf = pygame.Surface((sign_w, sign_h), pygame.SRCALPHA)
        for i in range(sign_h):
            parch_r = int(60 + 15 * math.sin(i * 0.3))
            parch_g = int(40 + 10 * math.sin(i * 0.3))
            parch_b = int(70 + 20 * math.sin(i * 0.3))
            pygame.draw.line(parchment_surf, (parch_r, parch_g, parch_b), (0, i), (sign_w, i))
        screen.blit(parchment_surf, (sign_x, sign_y))

        pygame.draw.rect(screen, secondary, (sign_x, sign_y, sign_w, sign_h), 2, border_radius=3)

        # 마법 문자 "STORE"
        self._draw_magic_text_store(screen, sign_x + 12, sign_y + 3, secondary, tertiary, pulse)

        # === 회전하는 마법진 ===
        cx, cy = x + w // 2, y + h // 2 + 10

        for ring in range(3):
            ring_r = 25 + ring * 10
            ring_alpha = int(180 * pulse / (ring + 1))

            # 룬 심볼
            for i in range(6):
                angle = magic_flow * (1 if ring % 2 == 0 else -1) + i * (math.pi / 3) + ring * 0.5
                rx = cx + int(ring_r * math.cos(angle))
                ry = cy + int(ring_r * math.sin(angle))
                pygame.draw.circle(screen, (*secondary, ring_alpha), (rx, ry), 3)

            pygame.draw.circle(screen, (*color, ring_alpha), (cx, cy), ring_r, 1)

        # 중앙 오브
        pygame.draw.circle(screen, (*tertiary, int(255 * pulse)), (cx, cy), 8)
        pygame.draw.circle(screen, (*secondary, int(200 * pulse)), (cx, cy), 5)

        # === 나무 문 ===
        door_w = w // 3
        door_h = 35
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h - 5

        pygame.draw.rect(screen, (70, 50, 40), (door_x, door_y, door_w, door_h), border_radius=3)
        pygame.draw.rect(screen, secondary, (door_x, door_y, door_w, door_h), 2, border_radius=3)

        # 마법 문양
        pygame.draw.circle(screen, (*tertiary, int(200 * pulse)), (door_x + door_w // 2, door_y + door_h // 2), 8)
        pygame.draw.circle(screen, secondary, (door_x + door_w // 2, door_y + door_h // 2), 8, 1)

        # === 마법 파티클 ===
        if len(self.particles[design_id]) < 20 and self.animation_timer % 0.15 < 0.05:
            import random
            angle = random.uniform(0, math.pi * 2)
            radius = random.uniform(30, 50)
            self.particles[design_id].append({
                'x': cx + radius * math.cos(angle),
                'y': cy + radius * math.sin(angle),
                'vx': random.uniform(-20, 20),
                'vy': random.uniform(-30, -10),
                'life': random.uniform(0.8, 1.5),
                'color': secondary if random.random() > 0.5 else tertiary
            })

        for p in self.particles[design_id]:
            p_alpha = int(200 * (p['life'] / 1.5))
            pygame.draw.circle(screen, (*p['color'], p_alpha), (int(p['x']), int(p['y'])), 2)

    # =========================================================================
    # 디자인 5: 플라즈마 허브
    # =========================================================================
    def _draw_plasma_hub(self, screen, design, x, y, w, h, design_id):
        """플라즈마 허브 - 미래형 에너지 기반 상점"""
        color = design["color"]
        secondary = design["secondary"]
        tertiary = design["tertiary"]

        pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 3))
        energy_flow = self.animation_timer * 5

        # === 에너지 필드 배경 ===
        for i in range(4):
            field_size = 20 - i * 4
            field_alpha = int(60 * pulse / (i + 1))
            field_surf = pygame.Surface((w + field_size * 2, h + field_size * 2), pygame.SRCALPHA)
            pygame.draw.rect(field_surf, (*color, field_alpha),
                           (0, 0, w + field_size * 2, h + field_size * 2), border_radius=15)
            screen.blit(field_surf, (x - field_size, y - field_size))

        # === 메인 건물 (반투명 플라즈마) ===
        plasma_surf = pygame.Surface((w, h - 10), pygame.SRCALPHA)
        for i in range(h - 10):
            plasma_r = max(0, min(255, int(20 + 30 * math.sin(i * 0.05 + energy_flow * 0.5))))
            plasma_g = max(0, min(255, int(40 + 50 * math.sin(i * 0.05 + energy_flow * 0.5 + 1))))
            plasma_b = max(0, min(255, int(60 + 40 * math.sin(i * 0.05 + energy_flow * 0.5 + 2))))
            plasma_alpha = max(0, min(255, int(180 + 50 * math.sin(i * 0.1 + energy_flow))))
            pygame.draw.line(plasma_surf, (plasma_r, plasma_g, plasma_b, plasma_alpha), (0, i), (w, i))
        screen.blit(plasma_surf, (x, y + 10))

        # 에너지 테두리
        for glow_i in range(5):
            glow_alpha = int(200 * pulse / (glow_i + 1))
            pygame.draw.rect(screen, (*color, glow_alpha),
                           (x - glow_i * 2, y + 8 - glow_i, w + glow_i * 4, h - 8 + glow_i * 2),
                           2, border_radius=10)

        # === 플라즈마 돔 지붕 ===
        dome_rect = pygame.Rect(x + 10, y - 5, w - 20, 25)

        # 돔 그라데이션
        for i in range(12):
            dome_alpha = max(0, int(200 - i * 15))
            dome_color = (
                max(0, int(color[0] * (1 - i * 0.05))),
                max(0, int(color[1] * (1 - i * 0.05))),
                max(0, int(color[2] * (1 - i * 0.05)))
            )
            pygame.draw.ellipse(screen, (*dome_color, dome_alpha),
                              (dome_rect.x + i, dome_rect.y + i, dome_rect.width - i * 2, dome_rect.height - i))

        # 에너지 아크
        for i in range(3):
            arc_x = x + 20 + i * (w - 40) // 2
            arc_alpha = int(255 * abs(math.sin(energy_flow + i * 0.5)))
            pygame.draw.arc(screen, (*secondary, arc_alpha),
                          (arc_x - 10, y - 3, 20, 15), 0, math.pi, 2)

        # === 홀로그램 "STORE" 간판 ===
        sign_y = y + 15
        sign_h = 25
        sign_w = w - 12
        sign_x = x + 6

        # 홀로그램 배경
        holo_surf = pygame.Surface((sign_w, sign_h), pygame.SRCALPHA)
        for i in range(sign_h):
            holo_alpha = int(100 + 50 * math.sin(i * 0.5 + energy_flow))
            scan_line = int(i + energy_flow * 20) % 3 == 0
            if scan_line:
                pygame.draw.line(holo_surf, (*color, holo_alpha + 50), (0, i), (sign_w, i))
            else:
                pygame.draw.line(holo_surf, (20, 40, 60, holo_alpha), (0, i), (sign_w, i))
        screen.blit(holo_surf, (sign_x, sign_y))

        # 글리치 효과
        if int(energy_flow * 10) % 20 < 2:
            glitch_offset = int(3 * math.sin(energy_flow * 50))
            pygame.draw.rect(screen, (*secondary, 150),
                           (sign_x + glitch_offset, sign_y + 5, sign_w // 3, 3))

        pygame.draw.rect(screen, (*color, int(200 * pulse)), (sign_x, sign_y, sign_w, sign_h), 2, border_radius=5)

        # "STORE" 홀로그램 텍스트
        self._draw_hologram_text_store(screen, sign_x + 10, sign_y + 4, color, secondary, pulse, energy_flow)

        # === 에너지 코어 창문 ===
        core_y = y + h - 55
        core_h = 35
        core_w = w - 20
        core_x = x + 10

        # 에너지 챔버
        pygame.draw.rect(screen, (20, 30, 50), (core_x, core_y, core_w, core_h), border_radius=5)

        # 플라즈마 에너지
        for i in range(3):
            energy_x = core_x + 15 + i * 25
            energy_offset = int(5 * math.sin(energy_flow + i * 0.7))

            # 에너지 구체
            for g in range(4):
                e_alpha = int(200 * pulse / (g + 1))
                pygame.draw.circle(screen, (*tertiary, e_alpha),
                                 (energy_x, core_y + core_h // 2 + energy_offset), 10 - g * 2)

            # 에너지 링
            ring_alpha = int(150 * abs(math.sin(energy_flow * 2 + i)))
            pygame.draw.circle(screen, (*secondary, ring_alpha),
                             (energy_x, core_y + core_h // 2 + energy_offset), 12, 1)

        pygame.draw.rect(screen, (*color, 200), (core_x, core_y, core_w, core_h), 2, border_radius=5)

        # === 에너지 문 ===
        door_w = w // 3
        door_h = 38
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h - 5

        # 에너지 필드 문
        door_surf = pygame.Surface((door_w, door_h), pygame.SRCALPHA)
        for i in range(door_h):
            door_alpha = int(100 + 80 * math.sin(i * 0.2 + energy_flow))
            pygame.draw.line(door_surf, (*color, door_alpha), (0, i), (door_w, i))
        screen.blit(door_surf, (door_x, door_y))

        pygame.draw.rect(screen, (*secondary, int(255 * pulse)), (door_x, door_y, door_w, door_h), 2, border_radius=3)

        # 입장 센서
        sensor_y = door_y - 5
        sensor_alpha = int(255 * abs(math.sin(energy_flow * 2)))
        pygame.draw.line(screen, (*tertiary, sensor_alpha), (door_x + 5, sensor_y), (door_x + door_w - 5, sensor_y), 2)

        # === 에너지 파티클 ===
        if len(self.particles[design_id]) < 15 and self.animation_timer % 0.2 < 0.05:
            import random
            self.particles[design_id].append({
                'x': x + random.randint(10, w - 10),
                'y': y + h - 10,
                'vx': random.uniform(-10, 10),
                'vy': random.uniform(-50, -20),
                'life': random.uniform(1.0, 2.0),
                'color': color if random.random() > 0.5 else tertiary
            })

        for p in self.particles[design_id]:
            p_alpha = int(200 * (p['life'] / 2.0))
            pygame.draw.circle(screen, (*p['color'], p_alpha), (int(p['x']), int(p['y'])), 2)
            pygame.draw.circle(screen, (*p['color'], p_alpha // 2), (int(p['x']), int(p['y'])), 4)

    # =========================================================================
    # 텍스트 렌더링 헬퍼
    # =========================================================================
    def _draw_neon_text_store(self, screen, x, y, color, secondary, pulse):
        """네온 스타일 STORE 텍스트"""
        letters = self._get_store_letters()
        for idx, letter in enumerate(letters):
            lx = x + idx * 14
            for px, py in letter:
                for glow in range(3, 0, -1):
                    glow_alpha = int(255 * pulse / glow)
                    pygame.draw.circle(screen, (*secondary, glow_alpha), (lx + px, y + py), glow)
                pygame.draw.rect(screen, secondary, (lx + px, y + py, 1, 1))

    def _draw_embossed_text_store(self, screen, x, y, color):
        """양각 스타일 STORE 텍스트"""
        letters = self._get_store_letters()
        for idx, letter in enumerate(letters):
            lx = x + idx * 14
            for px, py in letter:
                # 그림자
                pygame.draw.rect(screen, (100, 80, 30), (lx + px + 1, y + py + 1, 2, 2))
                # 하이라이트
                pygame.draw.rect(screen, (255, 240, 200), (lx + px, y + py, 2, 2))

    def _draw_engraved_text_store(self, screen, x, y, dark_color, light_color):
        """각인 스타일 STORE 텍스트"""
        letters = self._get_store_letters()
        for idx, letter in enumerate(letters):
            lx = x + idx * 12
            for px, py in letter:
                pygame.draw.rect(screen, dark_color, (lx + px, y + py, 2, 2))
                pygame.draw.rect(screen, light_color, (lx + px - 1, y + py - 1, 1, 1))

    def _draw_magic_text_store(self, screen, x, y, color, secondary, pulse):
        """마법 스타일 STORE 텍스트"""
        letters = self._get_store_letters()
        for idx, letter in enumerate(letters):
            lx = x + idx * 13
            offset = int(2 * math.sin(self.animation_timer * 3 + idx * 0.5))
            for px, py in letter:
                glow_alpha = int(255 * pulse)
                pygame.draw.circle(screen, (*color, glow_alpha // 2), (lx + px, y + py + offset), 3)
                pygame.draw.rect(screen, color, (lx + px, y + py + offset, 2, 2))

    def _draw_hologram_text_store(self, screen, x, y, color, secondary, pulse, flow):
        """홀로그램 스타일 STORE 텍스트"""
        letters = self._get_store_letters()
        for idx, letter in enumerate(letters):
            lx = x + idx * 13
            # 글리치 오프셋
            glitch = int(2 * math.sin(flow * 5 + idx)) if int(flow * 10) % 30 < 3 else 0
            for px, py in letter:
                text_alpha = int(200 + 55 * math.sin(flow + idx * 0.3))
                pygame.draw.rect(screen, (*secondary, text_alpha), (lx + px + glitch, y + py, 2, 2))

    def _get_store_letters(self):
        """STORE 글자 픽셀 좌표 (5x7 폰트)"""
        return [
            # S
            [(1,0),(2,0),(3,0),(4,0),(0,1),(0,2),(1,3),(2,3),(3,3),(4,4),(4,5),(0,6),(1,6),(2,6),(3,6)],
            # T
            [(0,0),(1,0),(2,0),(3,0),(4,0),(2,1),(2,2),(2,3),(2,4),(2,5),(2,6)],
            # O
            [(1,0),(2,0),(3,0),(0,1),(4,1),(0,2),(4,2),(0,3),(4,3),(0,4),(4,4),(0,5),(4,5),(1,6),(2,6),(3,6)],
            # R
            [(0,0),(1,0),(2,0),(3,0),(0,1),(4,1),(0,2),(4,2),(0,3),(1,3),(2,3),(3,3),(0,4),(3,4),(0,5),(4,5),(0,6),(4,6)],
            # E
            [(0,0),(1,0),(2,0),(3,0),(4,0),(0,1),(0,2),(0,3),(1,3),(2,3),(3,3),(0,4),(0,5),(0,6),(1,6),(2,6),(3,6),(4,6)],
        ]


def main():
    """미리보기 메인 함수"""
    clock = pygame.time.Clock()
    renderer = StoreDesignRenderer()

    # 디자인 배치 (2행 3열, 마지막은 빈칸)
    positions = [
        (100, 100), (540, 100), (980, 100),
        (320, 500), (760, 500)
    ]

    selected = None
    running = True

    while running:
        dt = clock.tick(60) / 1000.0
        renderer.update(dt)

        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key in [pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4, pygame.K_5]:
                    selected = event.key - pygame.K_0
                    print(f"\n✅ 선택된 디자인: {selected} - {STORE_DESIGNS[selected]['name']}")
                elif event.key == pygame.K_RETURN and selected:
                    print(f"\n🎉 최종 선택: {STORE_DESIGNS[selected]['name']}")
                    print(f"   스타일: {STORE_DESIGNS[selected]['style']}")
                    running = False
            elif event.type == pygame.MOUSEBUTTONDOWN:
                mx, my = event.pos
                for i, (px, py) in enumerate(positions):
                    if px <= mx <= px + 200 and py <= my <= py + 300:
                        selected = i + 1
                        print(f"\n✅ 선택된 디자인: {selected} - {STORE_DESIGNS[selected]['name']}")

        # 배경
        screen.fill((15, 15, 30))

        # 제목
        title = font_large.render("STORE 건물 디자인 선택", True, (255, 255, 255))
        screen.blit(title, (PREVIEW_WIDTH // 2 - title.get_width() // 2, 20))

        subtitle = font_medium.render("숫자키 1-5 또는 클릭으로 선택 | Enter로 확정 | ESC로 취소", True, (150, 150, 150))
        screen.blit(subtitle, (PREVIEW_WIDTH // 2 - subtitle.get_width() // 2, 60))

        # 5가지 디자인 그리기
        for i, (px, py) in enumerate(positions):
            design_id = i + 1
            design = STORE_DESIGNS[design_id]

            # 선택 테두리
            if selected == design_id:
                pygame.draw.rect(screen, (255, 215, 0), (px - 10, py - 10, 220, 320), 3, border_radius=10)

            # 건물 렌더링
            renderer.draw_store(screen, design_id, px + 40, py + 50, 120, 150)

            # 번호
            num_text = font_large.render(str(design_id), True, design["color"])
            screen.blit(num_text, (px + 10, py + 10))

            # 이름
            name_text = font_medium.render(design["name"], True, (255, 255, 255))
            screen.blit(name_text, (px + 100 - name_text.get_width() // 2, py + 220))

            # 영문 이름
            en_text = font_small.render(design["name_en"], True, design["secondary"])
            screen.blit(en_text, (px + 100 - en_text.get_width() // 2, py + 245))

            # 설명
            desc_text = font_small.render(design["description"], True, (150, 150, 150))
            screen.blit(desc_text, (px + 100 - desc_text.get_width() // 2, py + 270))

        # 선택 정보
        if selected:
            info = f"선택: {STORE_DESIGNS[selected]['name']} - Enter로 확정"
            info_text = font_medium.render(info, True, (255, 215, 0))
            screen.blit(info_text, (PREVIEW_WIDTH // 2 - info_text.get_width() // 2, PREVIEW_HEIGHT - 50))

        pygame.display.flip()

    pygame.quit()

    if selected:
        return selected, STORE_DESIGNS[selected]
    return None, None


if __name__ == "__main__":
    result = main()
    if result[0]:
        print(f"\n최종 선택: {result[1]['name']}")
