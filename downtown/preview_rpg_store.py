#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RPG 스타일 상점 디자인 미리보기
- 무기/방어구/장신구 판매 상점 컨셉
- 5가지 고퀄리티 디자인
"""

import pygame
import math
import random
import sys

# 화면 설정
SCREEN_WIDTH = 1200
SCREEN_HEIGHT = 800

# RPG 상점 디자인 정의
RPG_STORE_DESIGNS = {
    1: {
        "name": "용사의 무기점",
        "style": "hero_armory",
        "description": "전설의 무기들이 전시된 영웅의 무기점",
        "colors": {
            "primary": (139, 69, 19),      # 진한 갈색 (목재)
            "secondary": (218, 165, 32),    # 골든로드 (황금 장식)
            "accent": (192, 192, 192),      # 은색 (금속)
            "glow": (255, 215, 0),          # 금빛 글로우
        }
    },
    2: {
        "name": "드래곤 포지",
        "style": "dragon_forge",
        "description": "드래곤 불로 단련된 무기를 만드는 대장간",
        "colors": {
            "primary": (50, 50, 60),        # 다크 메탈
            "secondary": (255, 100, 50),    # 용암 오렌지
            "accent": (255, 200, 100),      # 불꽃 노란색
            "glow": (255, 80, 30),          # 붉은 글로우
        }
    },
    3: {
        "name": "엘프 공방",
        "style": "elven_workshop",
        "description": "정교한 엘프 장인의 마법 장신구 공방",
        "colors": {
            "primary": (34, 85, 51),        # 포레스트 그린
            "secondary": (173, 216, 230),   # 라이트 블루 (마법)
            "accent": (255, 255, 200),      # 페어리 라이트
            "glow": (100, 255, 150),        # 녹색 글로우
        }
    },
    4: {
        "name": "왕립 무기고",
        "style": "royal_arsenal",
        "description": "왕국 최고의 갑옷과 무기를 갖춘 무기고",
        "colors": {
            "primary": (70, 70, 100),       # 로얄 블루 그레이
            "secondary": (255, 215, 0),     # 골드
            "accent": (255, 255, 255),      # 화이트
            "glow": (100, 150, 255),        # 블루 글로우
        }
    },
    5: {
        "name": "암흑 상인",
        "style": "dark_merchant",
        "description": "희귀한 저주받은 아이템을 파는 암흑 상점",
        "colors": {
            "primary": (30, 20, 40),        # 다크 퍼플
            "secondary": (150, 50, 200),    # 보라색
            "accent": (0, 255, 200),        # 시안
            "glow": (180, 100, 255),        # 퍼플 글로우
        }
    }
}


class RPGStoreRenderer:
    """RPG 상점 렌더러"""

    def __init__(self):
        self.animation_timer = 0
        self.particles = {i: [] for i in range(1, 6)}

    def update(self, dt):
        self.animation_timer += dt

        # 파티클 업데이트
        for design_id in self.particles:
            # 파티클 업데이트
            for p in self.particles[design_id][:]:
                p['life'] -= dt
                p['y'] += p['vy'] * dt
                p['x'] += p.get('vx', 0) * dt
                if p['life'] <= 0:
                    self.particles[design_id].remove(p)

    def draw_store(self, screen, design_id, x, y, w, h):
        """상점 그리기"""
        design = RPG_STORE_DESIGNS[design_id]
        style = design["style"]

        if style == "hero_armory":
            self._draw_hero_armory(screen, design, x, y, w, h, design_id)
        elif style == "dragon_forge":
            self._draw_dragon_forge(screen, design, x, y, w, h, design_id)
        elif style == "elven_workshop":
            self._draw_elven_workshop(screen, design, x, y, w, h, design_id)
        elif style == "royal_arsenal":
            self._draw_royal_arsenal(screen, design, x, y, w, h, design_id)
        elif style == "dark_merchant":
            self._draw_dark_merchant(screen, design, x, y, w, h, design_id)

    def _draw_hero_armory(self, screen, design, x, y, w, h, design_id):
        """용사의 무기점 - 클래식 RPG 무기점"""
        colors = design["colors"]
        color = colors["primary"]
        secondary = colors["secondary"]
        accent = colors["accent"]
        glow = colors["glow"]

        pulse = 0.8 + 0.2 * math.sin(self.animation_timer * 2)
        swing = math.sin(self.animation_timer * 1.5) * 3

        # === 배경 글로우 ===
        glow_surf = pygame.Surface((w + 40, h + 40), pygame.SRCALPHA)
        glow_alpha = int(60 * pulse)
        pygame.draw.rect(glow_surf, (*glow, glow_alpha), (0, 0, w + 40, h + 40), border_radius=15)
        screen.blit(glow_surf, (x - 20, y - 20))

        # === 메인 건물 (목조 건물) ===
        # 목재 패턴
        for i in range(h - 20):
            wood_shade = max(0, min(255, color[0] + int(10 * math.sin(i * 0.3))))
            wood_color = (wood_shade, max(0, color[1] - 10), max(0, color[2] - 5))
            pygame.draw.line(screen, wood_color, (x, y + 20 + i), (x + w, y + 20 + i))

        # 건물 테두리 (금속 프레임)
        pygame.draw.rect(screen, accent, (x, y + 20, w, h - 20), 3, border_radius=3)

        # === 삼각형 지붕 (기와) ===
        roof_points = [
            (x - 15, y + 25),
            (x + w // 2, y - 25),
            (x + w + 15, y + 25)
        ]

        # 지붕 그라데이션
        for i in range(5):
            roof_color = (
                max(0, 100 - i * 15),
                max(0, 60 - i * 10),
                max(0, 40 - i * 8)
            )
            offset_points = [
                (roof_points[0][0] + i * 3, roof_points[0][1] - i * 2),
                (roof_points[1][0], roof_points[1][1] + i * 5),
                (roof_points[2][0] - i * 3, roof_points[2][1] - i * 2)
            ]
            pygame.draw.polygon(screen, roof_color, offset_points)

        # 지붕 테두리
        pygame.draw.polygon(screen, secondary, roof_points, 3)

        # === 교차 검 장식 (지붕 위) ===
        sword_x = x + w // 2
        sword_y = y - 15
        sword_len = 25

        # 검 1 (왼쪽으로 기울어짐)
        s1_start = (sword_x - 12, sword_y - sword_len)
        s1_end = (sword_x + 8, sword_y + sword_len // 2)
        pygame.draw.line(screen, accent, s1_start, s1_end, 4)
        pygame.draw.circle(screen, secondary, s1_start, 5)  # 검 손잡이

        # 검 2 (오른쪽으로 기울어짐)
        s2_start = (sword_x + 12, sword_y - sword_len)
        s2_end = (sword_x - 8, sword_y + sword_len // 2)
        pygame.draw.line(screen, accent, s2_start, s2_end, 4)
        pygame.draw.circle(screen, secondary, s2_start, 5)

        # 검 빛남 효과
        glow_alpha = int(150 * pulse)
        for s_pos in [s1_start, s2_start]:
            glow_s = pygame.Surface((20, 20), pygame.SRCALPHA)
            pygame.draw.circle(glow_s, (*glow, glow_alpha), (10, 10), 8)
            screen.blit(glow_s, (s_pos[0] - 10, s_pos[1] - 10))

        # === 방패 디스플레이 (좌우) ===
        for side in [-1, 1]:
            shield_x = x + (w // 4 if side == -1 else w * 3 // 4)
            shield_y = y + h // 3
            shield_w, shield_h = 25, 30

            # 방패 모양
            shield_points = [
                (shield_x, shield_y - shield_h // 2),
                (shield_x - shield_w // 2, shield_y - shield_h // 4),
                (shield_x - shield_w // 2, shield_y + shield_h // 4),
                (shield_x, shield_y + shield_h // 2),
                (shield_x + shield_w // 2, shield_y + shield_h // 4),
                (shield_x + shield_w // 2, shield_y - shield_h // 4),
            ]
            pygame.draw.polygon(screen, accent, shield_points)
            pygame.draw.polygon(screen, secondary, shield_points, 2)

            # 방패 문양 (십자)
            pygame.draw.line(screen, secondary,
                           (shield_x, shield_y - shield_h // 3),
                           (shield_x, shield_y + shield_h // 3), 3)
            pygame.draw.line(screen, secondary,
                           (shield_x - shield_w // 3, shield_y),
                           (shield_x + shield_w // 3, shield_y), 3)

        # === 창문 (진열창) ===
        window_w, window_h = w // 3, h // 4
        window_x = x + (w - window_w) // 2
        window_y = y + h // 3

        # 창문 배경 (어두운 내부)
        pygame.draw.rect(screen, (30, 25, 20),
                        (window_x, window_y, window_w, window_h), border_radius=3)

        # 창문 안 무기 실루엣
        silhouette_color = (60, 50, 40)
        # 도끼
        pygame.draw.rect(screen, silhouette_color,
                        (window_x + 8, window_y + 5, 6, window_h - 15))
        pygame.draw.polygon(screen, silhouette_color, [
            (window_x + 5, window_y + 5),
            (window_x + 18, window_y + 10),
            (window_x + 18, window_y + 25),
            (window_x + 5, window_y + 20)
        ])
        # 검
        pygame.draw.rect(screen, silhouette_color,
                        (window_x + window_w // 2 - 2, window_y + 3, 4, window_h - 10))
        # 창
        pygame.draw.rect(screen, silhouette_color,
                        (window_x + window_w - 15, window_y + 2, 3, window_h - 8))
        pygame.draw.polygon(screen, silhouette_color, [
            (window_x + window_w - 18, window_y + 2),
            (window_x + window_w - 8, window_y + 2),
            (window_x + window_w - 13, window_y + 12)
        ])

        # 창문 프레임
        pygame.draw.rect(screen, secondary, (window_x, window_y, window_w, window_h), 2, border_radius=3)
        pygame.draw.line(screen, secondary,
                        (window_x + window_w // 2, window_y),
                        (window_x + window_w // 2, window_y + window_h), 2)

        # === 문 ===
        door_w, door_h = w // 3, h // 2.5
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h

        # 문 (진한 나무)
        door_color = (80, 50, 30)
        pygame.draw.rect(screen, door_color, (door_x, door_y, door_w, door_h), border_radius=3)

        # 문 패널
        panel_margin = 4
        panel_color = (60, 35, 20)
        pygame.draw.rect(screen, panel_color,
                        (door_x + panel_margin, door_y + panel_margin,
                         door_w - panel_margin * 2, door_h // 2 - panel_margin), border_radius=2)
        pygame.draw.rect(screen, panel_color,
                        (door_x + panel_margin, door_y + door_h // 2 + 2,
                         door_w - panel_margin * 2, door_h // 2 - panel_margin - 2), border_radius=2)

        # 문 손잡이
        pygame.draw.circle(screen, secondary,
                          (door_x + door_w - 10, int(door_y + door_h // 2)), 4)

        # 문 프레임
        pygame.draw.rect(screen, secondary, (door_x, door_y, door_w, door_h), 2, border_radius=3)

        # === STORE 간판 ===
        sign_w, sign_h = w - 20, 28
        sign_x = x + 10
        sign_y = y + 25

        # 간판 배경 (나무)
        pygame.draw.rect(screen, (60, 40, 25), (sign_x, sign_y, sign_w, sign_h), border_radius=5)
        pygame.draw.rect(screen, secondary, (sign_x, sign_y, sign_w, sign_h), 2, border_radius=5)

        # STORE 텍스트
        self._draw_pixel_text(screen, "STORE", sign_x + sign_w // 2, sign_y + sign_h // 2,
                             secondary, scale=2, center=True)

        # === 횃불 애니메이션 (좌우) ===
        for side in [-1, 1]:
            torch_x = x + (10 if side == -1 else w - 10)
            torch_y = y + h // 2

            # 횃불 막대
            pygame.draw.rect(screen, (80, 50, 30), (torch_x - 3, torch_y, 6, 30))

            # 불꽃
            flame_offset = int(swing)
            flame_colors = [(255, 200, 50), (255, 150, 30), (255, 100, 20)]
            for i, fc in enumerate(flame_colors):
                flame_h = 15 - i * 3
                pygame.draw.ellipse(screen, fc,
                                   (torch_x - 6 + i + flame_offset * (i * 0.3),
                                    torch_y - flame_h - 5 + i * 2,
                                    12 - i * 2, flame_h))

            # 불꽃 글로우
            glow_s = pygame.Surface((30, 30), pygame.SRCALPHA)
            pygame.draw.circle(glow_s, (255, 150, 50, int(80 * pulse)), (15, 15), 12)
            screen.blit(glow_s, (torch_x - 15, torch_y - 25))

    def _draw_dragon_forge(self, screen, design, x, y, w, h, design_id):
        """드래곤 포지 - 용암 대장간"""
        colors = design["colors"]
        color = colors["primary"]
        secondary = colors["secondary"]
        accent = colors["accent"]
        glow = colors["glow"]

        pulse = 0.7 + 0.3 * math.sin(self.animation_timer * 3)
        lava_flow = self.animation_timer * 2

        # === 용암 글로우 배경 ===
        glow_surf = pygame.Surface((w + 60, h + 60), pygame.SRCALPHA)
        glow_alpha = int(100 * pulse)
        pygame.draw.rect(glow_surf, (*glow, glow_alpha), (0, 0, w + 60, h + 60), border_radius=20)
        screen.blit(glow_surf, (x - 30, y - 30))

        # === 메인 건물 (검은 돌/금속) ===
        # 돌 텍스처
        for i in range(h - 15):
            stone_var = int(15 * math.sin(i * 0.5 + lava_flow * 0.1))
            stone_color = (
                max(0, min(255, color[0] + stone_var)),
                max(0, min(255, color[1] + stone_var)),
                max(0, min(255, color[2] + stone_var))
            )
            pygame.draw.line(screen, stone_color, (x, y + 15 + i), (x + w, y + 15 + i))

        # 용암 균열 (건물에)
        crack_points = [
            [(x + 10, y + h - 10), (x + 15, y + h - 40), (x + 20, y + h - 30)],
            [(x + w - 15, y + h - 15), (x + w - 20, y + h - 50), (x + w - 10, y + h - 35)]
        ]
        for crack in crack_points:
            crack_alpha = int(200 * pulse)
            for i, pt in enumerate(crack[:-1]):
                pygame.draw.line(screen, (*secondary, crack_alpha), pt, crack[i + 1], 3)
                # 글로우
                glow_s = pygame.Surface((20, 20), pygame.SRCALPHA)
                pygame.draw.circle(glow_s, (*glow, int(100 * pulse)), (10, 10), 8)
                screen.blit(glow_s, (pt[0] - 10, pt[1] - 10))

        # 건물 테두리
        pygame.draw.rect(screen, (80, 80, 90), (x, y + 15, w, h - 15), 3, border_radius=5)

        # === 드래곤 머리 지붕 ===
        # 지붕 베이스
        roof_points = [
            (x - 10, y + 20),
            (x + w // 2, y - 30),
            (x + w + 10, y + 20)
        ]
        pygame.draw.polygon(screen, (40, 40, 50), roof_points)

        # 드래곤 머리 (중앙)
        dragon_x = x + w // 2
        dragon_y = y - 20

        # 머리 형태
        head_points = [
            (dragon_x - 20, dragon_y + 10),
            (dragon_x - 25, dragon_y - 5),
            (dragon_x - 15, dragon_y - 20),
            (dragon_x, dragon_y - 30),
            (dragon_x + 15, dragon_y - 20),
            (dragon_x + 25, dragon_y - 5),
            (dragon_x + 20, dragon_y + 10),
        ]
        pygame.draw.polygon(screen, (60, 60, 70), head_points)
        pygame.draw.polygon(screen, (80, 80, 90), head_points, 2)

        # 드래곤 눈 (빛나는)
        eye_glow = int(255 * pulse)
        for ex in [-10, 10]:
            pygame.draw.circle(screen, (eye_glow, int(eye_glow * 0.3), 0),
                             (dragon_x + ex, dragon_y - 10), 5)
            pygame.draw.circle(screen, (255, 255, 200), (dragon_x + ex - 1, dragon_y - 11), 2)

        # 드래곤 입에서 나오는 불
        fire_y = dragon_y + 5
        for i in range(8):
            fire_alpha = max(0, int(200 - i * 25))
            fire_w = 15 - i
            fire_h = 20 + int(10 * math.sin(lava_flow + i))
            fire_color = (
                255,
                max(0, 200 - i * 20),
                max(0, 50 - i * 5)
            )
            fire_surf = pygame.Surface((fire_w * 2, fire_h), pygame.SRCALPHA)
            pygame.draw.ellipse(fire_surf, (*fire_color, fire_alpha), (0, 0, fire_w * 2, fire_h))
            screen.blit(fire_surf, (dragon_x - fire_w, fire_y + i * 3))

        # === 모루와 해머 (창문 대신) ===
        anvil_x = x + w // 2
        anvil_y = y + h // 2

        # 모루
        anvil_points = [
            (anvil_x - 20, anvil_y + 15),
            (anvil_x - 15, anvil_y),
            (anvil_x + 15, anvil_y),
            (anvil_x + 20, anvil_y + 15),
        ]
        pygame.draw.polygon(screen, (70, 70, 80), anvil_points)
        pygame.draw.rect(screen, (60, 60, 70), (anvil_x - 10, anvil_y + 15, 20, 10))

        # 해머 (흔들림)
        hammer_angle = math.sin(self.animation_timer * 4) * 0.3
        hammer_x = anvil_x + int(15 * math.sin(hammer_angle))
        hammer_y = anvil_y - 20 + int(5 * abs(math.sin(self.animation_timer * 4)))

        # 해머 자루
        pygame.draw.line(screen, (100, 70, 40), (hammer_x, hammer_y), (hammer_x + 15, hammer_y - 25), 4)
        # 해머 머리
        pygame.draw.rect(screen, (80, 80, 90), (hammer_x - 8, hammer_y - 8, 16, 12))
        pygame.draw.rect(screen, accent, (hammer_x - 8, hammer_y - 8, 16, 12), 1)

        # 불꽃 파티클
        if random.random() < 0.3:
            self.particles[design_id].append({
                'x': anvil_x + random.randint(-20, 20),
                'y': anvil_y,
                'vy': -random.uniform(30, 60),
                'vx': random.uniform(-15, 15),
                'life': random.uniform(0.5, 1.0),
                'color': random.choice([secondary, accent, glow])
            })

        # 파티클 그리기
        for p in self.particles[design_id]:
            alpha = int(255 * (p['life'] / 1.0))
            size = int(4 * p['life'])
            if size > 0:
                spark_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(spark_surf, (*p['color'], alpha), (size, size), size)
                screen.blit(spark_surf, (int(p['x']) - size, int(p['y']) - size))

        # === 문 (용암 테두리) ===
        door_w, door_h = w // 3, h // 2.5
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h

        # 문
        pygame.draw.rect(screen, (40, 35, 45), (door_x, door_y, door_w, door_h), border_radius=3)

        # 용암 테두리
        for i in range(3):
            lava_alpha = int(180 * pulse / (i + 1))
            pygame.draw.rect(screen, (*secondary, lava_alpha),
                           (door_x - i * 2, door_y - i * 2, door_w + i * 4, door_h + i * 4),
                           2, border_radius=5)

        # 금속 손잡이 (뜨거운)
        handle_glow = int(200 * pulse)
        pygame.draw.circle(screen, (handle_glow, int(handle_glow * 0.4), 0),
                          (door_x + door_w - 12, int(door_y + door_h // 2)), 5)

        # === STORE 간판 (금속판) ===
        sign_w, sign_h = w - 20, 28
        sign_x = x + 10
        sign_y = y + 20

        pygame.draw.rect(screen, (50, 50, 60), (sign_x, sign_y, sign_w, sign_h), border_radius=3)

        # 뜨거운 글자 효과
        text_glow = int(255 * pulse)
        self._draw_pixel_text(screen, "STORE", sign_x + sign_w // 2, sign_y + sign_h // 2,
                             (text_glow, int(text_glow * 0.5), 0), scale=2, center=True)

        # 테두리
        pygame.draw.rect(screen, accent, (sign_x, sign_y, sign_w, sign_h), 2, border_radius=3)

    def _draw_elven_workshop(self, screen, design, x, y, w, h, design_id):
        """엘프 공방 - 마법 장신구점"""
        colors = design["colors"]
        color = colors["primary"]
        secondary = colors["secondary"]
        accent = colors["accent"]
        glow = colors["glow"]

        pulse = 0.8 + 0.2 * math.sin(self.animation_timer * 1.5)
        magic_flow = self.animation_timer * 2

        # === 마법 글로우 배경 ===
        glow_surf = pygame.Surface((w + 50, h + 50), pygame.SRCALPHA)
        glow_alpha = int(50 * pulse)
        pygame.draw.rect(glow_surf, (*glow, glow_alpha), (0, 0, w + 50, h + 50), border_radius=15)
        screen.blit(glow_surf, (x - 25, y - 25))

        # === 메인 건물 (나무와 덩굴) ===
        # 기본 건물
        for i in range(h - 10):
            green_var = int(20 * math.sin(i * 0.2))
            wood_color = (
                max(0, min(255, color[0] + green_var)),
                max(0, min(255, color[1] + green_var // 2)),
                max(0, min(255, color[2] + green_var // 3))
            )
            pygame.draw.line(screen, wood_color, (x, y + 10 + i), (x + w, y + 10 + i))

        # 덩굴 장식
        vine_color = (50, 120, 60)
        for vine_x in [x + 5, x + w - 5]:
            for i in range(8):
                vy = y + 20 + i * 15
                vx_offset = int(8 * math.sin(i * 0.8 + magic_flow * 0.3))
                pygame.draw.circle(screen, vine_color, (vine_x + vx_offset, vy), 4)
                # 잎
                if i % 2 == 0:
                    leaf_pts = [
                        (vine_x + vx_offset, vy),
                        (vine_x + vx_offset + 8, vy - 3),
                        (vine_x + vx_offset + 6, vy + 3)
                    ]
                    pygame.draw.polygon(screen, (60, 140, 70), leaf_pts)

        # 테두리
        pygame.draw.rect(screen, (80, 140, 90), (x, y + 10, w, h - 10), 2, border_radius=8)

        # === 아치형 지붕 (엘프 스타일) ===
        # 지붕 곡선
        roof_surf = pygame.Surface((w + 30, 50), pygame.SRCALPHA)
        for i in range(45):
            roof_alpha = max(0, 255 - i * 5)
            roof_color = (
                max(0, 45 - i),
                max(0, 100 - i * 2),
                max(0, 60 - i)
            )
            # 아치 형태
            arc_rect = (i // 2, i, w + 30 - i, 50 - i)
            if arc_rect[2] > 0 and arc_rect[3] > 0:
                pygame.draw.ellipse(roof_surf, (*roof_color, roof_alpha), arc_rect)
        screen.blit(roof_surf, (x - 15, y - 35))

        # 지붕 테두리
        pygame.draw.arc(screen, secondary, (x - 15, y - 35, w + 30, 50), 0, math.pi, 3)

        # === 마법 크리스탈 (지붕 위) ===
        crystal_x = x + w // 2
        crystal_y = y - 25

        # 크리스탈 모양
        crystal_pts = [
            (crystal_x, crystal_y - 20),
            (crystal_x - 10, crystal_y),
            (crystal_x - 5, crystal_y + 15),
            (crystal_x + 5, crystal_y + 15),
            (crystal_x + 10, crystal_y)
        ]

        # 글로우
        glow_s = pygame.Surface((40, 50), pygame.SRCALPHA)
        pygame.draw.polygon(glow_s, (*secondary, int(100 * pulse)), [
            (20, 5), (8, 25), (12, 40), (28, 40), (32, 25)
        ])
        screen.blit(glow_s, (crystal_x - 20, crystal_y - 25))

        pygame.draw.polygon(screen, secondary, crystal_pts)
        pygame.draw.polygon(screen, accent, crystal_pts, 2)

        # 빛 반사
        pygame.draw.line(screen, accent, (crystal_x - 3, crystal_y - 10), (crystal_x - 3, crystal_y + 5), 2)

        # 마법 파티클
        if random.random() < 0.15:
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(5, 20)
            self.particles[design_id].append({
                'x': crystal_x + math.cos(angle) * dist,
                'y': crystal_y + math.sin(angle) * dist,
                'vy': -random.uniform(10, 30),
                'vx': random.uniform(-5, 5),
                'life': random.uniform(0.8, 1.5),
                'color': random.choice([secondary, accent, glow])
            })

        # 파티클 그리기
        for p in self.particles[design_id]:
            alpha = int(200 * (p['life'] / 1.5))
            size = int(3 * p['life'])
            if size > 0:
                spark_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(spark_surf, (*p['color'], alpha), (size, size), size)
                screen.blit(spark_surf, (int(p['x']) - size, int(p['y']) - size))

        # === 장신구 디스플레이 창 ===
        window_w, window_h = w // 2.5, h // 3
        window_x = x + (w - window_w) // 2
        window_y = y + h // 4

        # 창문 (둥근 아치)
        pygame.draw.rect(screen, (20, 40, 30),
                        (window_x, window_y + 10, window_w, window_h - 10), border_radius=5)
        pygame.draw.ellipse(screen, (20, 40, 30),
                           (window_x, window_y - 5, window_w, 30))

        # 장신구 진열 (반지, 목걸이, 팔찌)
        items = [
            (window_x + 12, window_y + 25, 'ring'),
            (window_x + window_w // 2, window_y + 20, 'necklace'),
            (window_x + window_w - 15, window_y + 25, 'bracelet')
        ]
        for ix, iy, item_type in items:
            item_glow = int(150 + 50 * math.sin(magic_flow + hash(item_type)))
            if item_type == 'ring':
                pygame.draw.circle(screen, (item_glow, int(item_glow * 0.8), 50), (ix, iy), 6, 2)
                pygame.draw.circle(screen, secondary, (ix, iy - 4), 3)
            elif item_type == 'necklace':
                pygame.draw.arc(screen, (item_glow, int(item_glow * 0.6), 50),
                              (ix - 10, iy - 5, 20, 15), math.pi, 0, 2)
                pygame.draw.circle(screen, secondary, (ix, iy + 8), 4)
            else:  # bracelet
                pygame.draw.ellipse(screen, (item_glow, int(item_glow * 0.7), 50),
                                   (ix - 8, iy - 3, 16, 10), 2)

        # 창문 프레임
        pygame.draw.rect(screen, accent, (window_x, window_y + 10, window_w, window_h - 10), 2, border_radius=5)
        pygame.draw.ellipse(screen, accent, (window_x, window_y - 5, window_w, 30), 2)

        # === 아치형 문 ===
        door_w, door_h = w // 3, h // 2.2
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h

        pygame.draw.rect(screen, (30, 50, 35), (door_x, door_y + 15, door_w, door_h - 15), border_radius=3)
        pygame.draw.ellipse(screen, (30, 50, 35), (door_x, door_y, door_w, 30))

        # 문 장식 (나뭇잎 문양)
        pygame.draw.ellipse(screen, vine_color, (door_x + door_w // 2 - 8, door_y + 10, 16, 20))

        # 문 프레임
        pygame.draw.rect(screen, accent, (door_x, door_y + 15, door_w, door_h - 15), 2, border_radius=3)
        pygame.draw.ellipse(screen, accent, (door_x, door_y, door_w, 30), 2)

        # === STORE 간판 (나무 조각) ===
        sign_w, sign_h = w - 15, 26
        sign_x = x + 7
        sign_y = y + 15

        pygame.draw.rect(screen, (45, 80, 50), (sign_x, sign_y, sign_w, sign_h), border_radius=8)
        pygame.draw.rect(screen, accent, (sign_x, sign_y, sign_w, sign_h), 2, border_radius=8)

        self._draw_pixel_text(screen, "STORE", sign_x + sign_w // 2, sign_y + sign_h // 2,
                             accent, scale=2, center=True)

    def _draw_royal_arsenal(self, screen, design, x, y, w, h, design_id):
        """왕립 무기고 - 고급 갑옷/무기점"""
        colors = design["colors"]
        color = colors["primary"]
        secondary = colors["secondary"]
        accent = colors["accent"]
        glow = colors["glow"]

        pulse = 0.85 + 0.15 * math.sin(self.animation_timer * 1.5)
        banner_wave = math.sin(self.animation_timer * 2) * 5

        # === 왕실 글로우 ===
        glow_surf = pygame.Surface((w + 40, h + 40), pygame.SRCALPHA)
        glow_alpha = int(40 * pulse)
        pygame.draw.rect(glow_surf, (*glow, glow_alpha), (0, 0, w + 40, h + 40), border_radius=10)
        screen.blit(glow_surf, (x - 20, y - 20))

        # === 메인 건물 (석조) ===
        # 돌 블록 패턴
        block_h = 12
        for row in range((h - 20) // block_h):
            row_offset = (row % 2) * 15
            for col in range((w // 25) + 1):
                bx = x + col * 25 - row_offset
                by = y + 20 + row * block_h
                if bx >= x and bx + 20 <= x + w:
                    stone_var = random.Random(row * 100 + col).randint(-10, 10)
                    stone_color = (
                        max(0, min(255, color[0] + stone_var)),
                        max(0, min(255, color[1] + stone_var)),
                        max(0, min(255, color[2] + stone_var))
                    )
                    pygame.draw.rect(screen, stone_color, (bx, by, 23, block_h - 1), border_radius=1)

        # 건물 테두리
        pygame.draw.rect(screen, secondary, (x, y + 20, w, h - 20), 3, border_radius=3)

        # === 왕관 지붕 ===
        roof_y = y + 5
        roof_h = 20

        # 메인 지붕
        pygame.draw.rect(screen, (50, 50, 70), (x - 5, roof_y, w + 10, roof_h), border_radius=3)

        # 왕관 뾰족이
        crown_points = 5
        for i in range(crown_points):
            cx = x + (w // (crown_points - 1)) * i
            # 뾰족이
            pygame.draw.polygon(screen, secondary, [
                (cx - 8, roof_y),
                (cx, roof_y - 15),
                (cx + 8, roof_y)
            ])
            # 보석
            gem_colors = [(255, 50, 50), (50, 50, 255), (50, 200, 50), (255, 200, 50), (200, 50, 200)]
            pygame.draw.circle(screen, gem_colors[i], (cx, roof_y - 8), 4)
            # 보석 글로우
            glow_s = pygame.Surface((12, 12), pygame.SRCALPHA)
            pygame.draw.circle(glow_s, (*gem_colors[i], int(100 * pulse)), (6, 6), 5)
            screen.blit(glow_s, (cx - 6, roof_y - 14))

        # 지붕 테두리
        pygame.draw.rect(screen, secondary, (x - 5, roof_y, w + 10, roof_h), 2, border_radius=3)

        # === 깃발 (좌우) ===
        for side in [-1, 1]:
            flag_x = x + (5 if side == -1 else w - 5)
            pole_top = y - 20

            # 깃대
            pygame.draw.line(screen, (150, 120, 80), (flag_x, y + 30), (flag_x, pole_top), 3)

            # 깃발
            flag_w, flag_h = 25, 35
            wave_offset = banner_wave * side
            flag_pts = [
                (flag_x, pole_top),
                (flag_x + flag_w * side + wave_offset, pole_top + 5),
                (flag_x + flag_w * side + wave_offset * 0.5, pole_top + flag_h // 2),
                (flag_x + flag_w * side + wave_offset, pole_top + flag_h - 5),
                (flag_x, pole_top + flag_h)
            ]
            pygame.draw.polygon(screen, (150, 30, 30), flag_pts)
            pygame.draw.polygon(screen, secondary, flag_pts, 2)

            # 문양 (왕관)
            crown_cx = flag_x + (flag_w // 2) * side + int(wave_offset * 0.5)
            crown_cy = pole_top + flag_h // 2
            pygame.draw.polygon(screen, secondary, [
                (crown_cx - 6, crown_cy + 3),
                (crown_cx - 4, crown_cy - 3),
                (crown_cx, crown_cy + 1),
                (crown_cx + 4, crown_cy - 3),
                (crown_cx + 6, crown_cy + 3)
            ])

        # === 갑옷 진열 창 ===
        window_w, window_h = w // 2.8, h // 2.5
        window_x = x + (w - window_w) // 2
        window_y = y + h // 4

        # 창문 배경
        pygame.draw.rect(screen, (30, 30, 45), (window_x, window_y, window_w, window_h), border_radius=3)

        # 갑옷 실루엣
        armor_x = window_x + window_w // 2
        armor_y = window_y + 10

        # 투구
        pygame.draw.ellipse(screen, (80, 80, 100),
                           (armor_x - 12, armor_y, 24, 18))
        # 몸통
        pygame.draw.rect(screen, (70, 70, 90),
                        (armor_x - 15, armor_y + 16, 30, 35))
        # 어깨 보호대
        pygame.draw.ellipse(screen, (75, 75, 95),
                           (armor_x - 22, armor_y + 14, 15, 12))
        pygame.draw.ellipse(screen, (75, 75, 95),
                           (armor_x + 7, armor_y + 14, 15, 12))

        # 글로우 효과
        armor_glow = pygame.Surface((40, 60), pygame.SRCALPHA)
        pygame.draw.rect(armor_glow, (*glow, int(50 * pulse)), (0, 0, 40, 60), border_radius=5)
        screen.blit(armor_glow, (armor_x - 20, armor_y - 5))

        # 창문 프레임
        pygame.draw.rect(screen, secondary, (window_x, window_y, window_w, window_h), 3, border_radius=3)

        # 십자 프레임
        pygame.draw.line(screen, secondary,
                        (window_x + window_w // 2, window_y),
                        (window_x + window_w // 2, window_y + window_h), 2)
        pygame.draw.line(screen, secondary,
                        (window_x, window_y + window_h // 2),
                        (window_x + window_w, window_y + window_h // 2), 2)

        # === 아치형 문 ===
        door_w, door_h = w // 2.8, h // 2.2
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h

        # 문
        pygame.draw.rect(screen, (45, 45, 60), (door_x, door_y + 10, door_w, door_h - 10), border_radius=3)
        pygame.draw.ellipse(screen, (45, 45, 60), (door_x, door_y - 5, door_w, 30))

        # 금장식 문 프레임
        for i in range(3):
            frame_alpha = max(0, 200 - i * 50)
            pygame.draw.rect(screen, (*secondary, frame_alpha),
                           (door_x - i, door_y + 10 - i, door_w + i * 2, door_h - 10 + i * 2),
                           2, border_radius=5)

        # 문 손잡이 (금)
        handle_y = int(door_y + door_h // 2)
        pygame.draw.circle(screen, secondary, (door_x + 12, handle_y), 5)
        pygame.draw.circle(screen, secondary, (door_x + door_w - 12, handle_y), 5)

        # === STORE 간판 (금속 현판) ===
        sign_w, sign_h = w - 30, 26
        sign_x = x + 15
        sign_y = y + 25

        pygame.draw.rect(screen, (60, 60, 80), (sign_x, sign_y, sign_w, sign_h), border_radius=3)
        pygame.draw.rect(screen, secondary, (sign_x, sign_y, sign_w, sign_h), 3, border_radius=3)

        self._draw_pixel_text(screen, "STORE", sign_x + sign_w // 2, sign_y + sign_h // 2,
                             secondary, scale=2, center=True)

    def _draw_dark_merchant(self, screen, design, x, y, w, h, design_id):
        """암흑 상인 - 저주받은 아이템 상점"""
        colors = design["colors"]
        color = colors["primary"]
        secondary = colors["secondary"]
        accent = colors["accent"]
        glow = colors["glow"]

        pulse = 0.7 + 0.3 * math.sin(self.animation_timer * 2.5)
        dark_flow = self.animation_timer * 1.5

        # === 어둠의 오라 ===
        for i in range(4):
            aura_size = w + 60 + i * 20
            aura_alpha = max(0, int(30 - i * 8) * pulse)
            aura_surf = pygame.Surface((aura_size, h + 60 + i * 20), pygame.SRCALPHA)
            pygame.draw.rect(aura_surf, (*secondary, aura_alpha),
                           (0, 0, aura_size, h + 60 + i * 20), border_radius=20)
            screen.blit(aura_surf, (x - 30 - i * 10, y - 30 - i * 10))

        # === 메인 건물 (어두운 석조) ===
        for i in range(h - 15):
            dark_var = int(10 * math.sin(i * 0.3 + dark_flow))
            dark_color = (
                max(0, min(255, color[0] + dark_var)),
                max(0, min(255, color[1] + dark_var // 2)),
                max(0, min(255, color[2] + dark_var))
            )
            pygame.draw.line(screen, dark_color, (x, y + 15 + i), (x + w, y + 15 + i))

        # 균열과 부식
        crack_color = (60, 40, 80)
        for _ in range(5):
            cx = x + random.Random(42 + _).randint(10, w - 10)
            cy = y + random.Random(43 + _).randint(30, h - 20)
            for j in range(3):
                pygame.draw.line(screen, crack_color,
                               (cx, cy),
                               (cx + random.Random(44 + _ + j).randint(-15, 15),
                                cy + random.Random(45 + _ + j).randint(-15, 15)), 1)

        # 테두리 (보라빛)
        pygame.draw.rect(screen, secondary, (x, y + 15, w, h - 15), 2, border_radius=5)

        # === 뾰족한 고딕 지붕 ===
        roof_points = [
            (x - 10, y + 20),
            (x + w // 2, y - 40),
            (x + w + 10, y + 20)
        ]

        # 지붕 그라데이션
        for i in range(6):
            roof_color = (
                max(0, 40 - i * 5),
                max(0, 25 - i * 3),
                max(0, 50 - i * 6)
            )
            offset = i * 3
            layer_pts = [
                (roof_points[0][0] + offset, roof_points[0][1] - offset // 2),
                (roof_points[1][0], roof_points[1][1] + offset * 2),
                (roof_points[2][0] - offset, roof_points[2][1] - offset // 2)
            ]
            pygame.draw.polygon(screen, roof_color, layer_pts)

        pygame.draw.polygon(screen, secondary, roof_points, 2)

        # === 악마의 눈 (지붕 위) ===
        eye_x = x + w // 2
        eye_y = y - 20

        # 눈 배경
        pygame.draw.ellipse(screen, (80, 40, 100), (eye_x - 15, eye_y - 10, 30, 20))

        # 동공 (움직임)
        pupil_offset_x = int(5 * math.sin(dark_flow))
        pupil_offset_y = int(3 * math.cos(dark_flow * 1.3))
        pygame.draw.ellipse(screen, accent,
                           (eye_x - 5 + pupil_offset_x, eye_y - 5 + pupil_offset_y, 10, 10))
        pygame.draw.ellipse(screen, (0, 0, 0),
                           (eye_x - 2 + pupil_offset_x, eye_y - 2 + pupil_offset_y, 4, 4))

        # 눈 글로우
        eye_glow = pygame.Surface((50, 40), pygame.SRCALPHA)
        pygame.draw.ellipse(eye_glow, (*accent, int(80 * pulse)), (0, 0, 50, 40))
        screen.blit(eye_glow, (eye_x - 25, eye_y - 20))

        # === 부유하는 저주 파티클 ===
        if random.random() < 0.2:
            self.particles[design_id].append({
                'x': x + random.randint(10, w - 10),
                'y': y + h - 10,
                'vy': -random.uniform(20, 40),
                'vx': random.uniform(-10, 10),
                'life': random.uniform(1.0, 2.0),
                'color': random.choice([secondary, accent, glow])
            })

        # 파티클 그리기
        for p in self.particles[design_id]:
            alpha = int(180 * (p['life'] / 2.0))
            size = int(4 * (p['life'] / 2.0))
            if size > 0:
                # 소용돌이 효과
                spiral_x = p['x'] + math.sin(dark_flow + p['life'] * 3) * 5
                spark_surf = pygame.Surface((size * 2 + 4, size * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(spark_surf, (*p['color'], alpha), (size + 2, size + 2), size)
                screen.blit(spark_surf, (int(spiral_x) - size - 2, int(p['y']) - size - 2))

        # === 진열 창 (마법진) ===
        window_w, window_h = w // 2.5, h // 3
        window_x = x + (w - window_w) // 2
        window_y = y + h // 4

        # 창문 배경
        pygame.draw.rect(screen, (15, 10, 25), (window_x, window_y, window_w, window_h), border_radius=5)

        # 마법진
        circle_x = window_x + window_w // 2
        circle_y = window_y + window_h // 2
        circle_r = min(window_w, window_h) // 2 - 5

        # 회전하는 마법진
        for i in range(6):
            angle = dark_flow + i * (math.pi / 3)
            x1 = circle_x + int(circle_r * math.cos(angle))
            y1 = circle_y + int(circle_r * math.sin(angle))
            x2 = circle_x + int(circle_r * math.cos(angle + math.pi))
            y2 = circle_y + int(circle_r * math.sin(angle + math.pi))
            line_alpha = int(150 + 50 * math.sin(dark_flow * 2 + i))
            pygame.draw.line(screen, (*secondary, line_alpha), (x1, y1), (x2, y2), 1)

        # 외곽 원
        pygame.draw.circle(screen, secondary, (circle_x, circle_y), circle_r, 2)
        pygame.draw.circle(screen, (*accent, int(150 * pulse)), (circle_x, circle_y), circle_r - 5, 1)

        # 창문 프레임
        pygame.draw.rect(screen, accent, (window_x, window_y, window_w, window_h), 2, border_radius=5)

        # === 아치형 문 (고딕) ===
        door_w, door_h = w // 3, h // 2.3
        door_x = x + (w - door_w) // 2
        door_y = y + h - door_h

        # 문 배경
        pygame.draw.rect(screen, (20, 15, 30), (door_x, door_y + 15, door_w, door_h - 15), border_radius=3)

        # 고딕 아치
        arch_pts = [
            (door_x, door_y + 15),
            (door_x + door_w // 4, door_y - 5),
            (door_x + door_w // 2, door_y - 10),
            (door_x + door_w * 3 // 4, door_y - 5),
            (door_x + door_w, door_y + 15)
        ]
        pygame.draw.polygon(screen, (20, 15, 30), arch_pts)
        pygame.draw.lines(screen, secondary, False, arch_pts, 2)

        # 문 손잡이 (해골)
        skull_x = door_x + door_w // 2
        skull_y = int(door_y + door_h // 2)
        pygame.draw.circle(screen, (200, 200, 180), (skull_x, skull_y), 6)
        pygame.draw.circle(screen, (30, 30, 30), (skull_x - 2, skull_y - 1), 2)
        pygame.draw.circle(screen, (30, 30, 30), (skull_x + 2, skull_y - 1), 2)
        pygame.draw.line(screen, (30, 30, 30), (skull_x - 2, skull_y + 3), (skull_x + 2, skull_y + 3), 1)

        # === STORE 간판 (저주받은 현판) ===
        sign_w, sign_h = w - 20, 28
        sign_x = x + 10
        sign_y = y + 20

        pygame.draw.rect(screen, (25, 15, 35), (sign_x, sign_y, sign_w, sign_h), border_radius=5)

        # 글자 글로우
        text_glow_alpha = int(200 * pulse)
        self._draw_pixel_text(screen, "STORE", sign_x + sign_w // 2, sign_y + sign_h // 2,
                             (*accent[:2], max(0, min(255, accent[2] + int(55 * pulse)))), scale=2, center=True)

        pygame.draw.rect(screen, secondary, (sign_x, sign_y, sign_w, sign_h), 2, border_radius=5)

    def _draw_pixel_text(self, screen, text, x, y, color, scale=1, center=False):
        """픽셀 폰트 텍스트 그리기"""
        # 간단한 픽셀 문자 정의
        chars = {
            'S': [(0,0),(1,0),(2,0),(0,1),(0,2),(1,2),(2,2),(2,3),(0,4),(1,4),(2,4)],
            'T': [(0,0),(1,0),(2,0),(1,1),(1,2),(1,3),(1,4)],
            'O': [(0,0),(1,0),(2,0),(0,1),(2,1),(0,2),(2,2),(0,3),(2,3),(0,4),(1,4),(2,4)],
            'R': [(0,0),(1,0),(2,0),(0,1),(2,1),(0,2),(1,2),(2,2),(0,3),(2,3),(0,4),(2,4)],
            'E': [(0,0),(1,0),(2,0),(0,1),(0,2),(1,2),(0,3),(0,4),(1,4),(2,4)],
        }

        char_width = 4 * scale
        total_width = len(text) * char_width
        start_x = x - total_width // 2 if center else x

        for i, char in enumerate(text):
            if char in chars:
                for px, py in chars[char]:
                    rect_x = start_x + i * char_width + px * scale
                    rect_y = y - 2 * scale + py * scale
                    pygame.draw.rect(screen, color, (rect_x, rect_y, scale, scale))


def main():
    """메인 함수"""
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("RPG 상점 디자인 미리보기 - 숫자키로 선택, Enter로 확정")

    clock = pygame.time.Clock()
    renderer = RPGStoreRenderer()

    selected = 1
    confirmed = False

    # 폰트
    try:
        font = pygame.font.Font(None, 36)
        small_font = pygame.font.Font(None, 28)
        title_font = pygame.font.Font(None, 48)
    except:
        font = pygame.font.SysFont('arial', 28)
        small_font = pygame.font.SysFont('arial', 22)
        title_font = pygame.font.SysFont('arial', 38)

    running = True
    while running:
        dt = clock.tick(60) / 1000.0

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key in [pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4, pygame.K_5]:
                    selected = event.key - pygame.K_0
                elif event.key == pygame.K_RETURN:
                    print(f"\n✅ 선택된 디자인: {selected} - {RPG_STORE_DESIGNS[selected]['name']}")
                    print(f"   스타일: {RPG_STORE_DESIGNS[selected]['style']}")
                    print(f"   설명: {RPG_STORE_DESIGNS[selected]['description']}")
                    confirmed = True
                    running = False

        # 업데이트
        renderer.update(dt)

        # 배경
        screen.fill((25, 25, 35))

        # 제목
        title = title_font.render("RPG 상점 디자인 선택", True, (255, 215, 0))
        screen.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, 20))

        subtitle = small_font.render("무기 / 방어구 / 장신구 상점", True, (180, 180, 180))
        screen.blit(subtitle, (SCREEN_WIDTH // 2 - subtitle.get_width() // 2, 60))

        # 5개 디자인 그리기
        panel_w = 200
        panel_h = 280
        start_x = (SCREEN_WIDTH - (panel_w * 5 + 40 * 4)) // 2

        for i, (design_id, design) in enumerate(RPG_STORE_DESIGNS.items()):
            px = start_x + i * (panel_w + 40)
            py = 120

            # 선택 표시
            if design_id == selected:
                # 선택 글로우
                glow_surf = pygame.Surface((panel_w + 20, panel_h + 20), pygame.SRCALPHA)
                pygame.draw.rect(glow_surf, (255, 215, 0, 100), (0, 0, panel_w + 20, panel_h + 20), border_radius=15)
                screen.blit(glow_surf, (px - 10, py - 10))

                pygame.draw.rect(screen, (255, 215, 0), (px - 5, py - 5, panel_w + 10, panel_h + 10), 3, border_radius=12)

            # 패널 배경
            pygame.draw.rect(screen, (40, 40, 50), (px, py, panel_w, panel_h), border_radius=10)
            pygame.draw.rect(screen, (80, 80, 90), (px, py, panel_w, panel_h), 2, border_radius=10)

            # 상점 그리기
            renderer.draw_store(screen, design_id, px + 25, py + 40, 150, 180)

            # 번호
            num_text = font.render(str(design_id), True, (255, 215, 0) if design_id == selected else (150, 150, 150))
            screen.blit(num_text, (px + 10, py + 10))

            # 이름
            name_text = small_font.render(design['name'], True, (255, 255, 255))
            name_x = px + (panel_w - name_text.get_width()) // 2
            screen.blit(name_text, (name_x, py + panel_h - 30))

        # 선택된 디자인 정보
        info_y = 430
        selected_design = RPG_STORE_DESIGNS[selected]

        pygame.draw.rect(screen, (35, 35, 45), (50, info_y, SCREEN_WIDTH - 100, 120), border_radius=10)
        pygame.draw.rect(screen, (100, 100, 120), (50, info_y, SCREEN_WIDTH - 100, 120), 2, border_radius=10)

        info_title = font.render(f"선택: {selected_design['name']}", True, (255, 215, 0))
        screen.blit(info_title, (70, info_y + 15))

        info_desc = small_font.render(selected_design['description'], True, (200, 200, 200))
        screen.blit(info_desc, (70, info_y + 50))

        info_style = small_font.render(f"스타일: {selected_design['style']}", True, (150, 150, 150))
        screen.blit(info_style, (70, info_y + 80))

        # 안내 텍스트
        help_text = small_font.render("1-5: 디자인 선택  |  Enter: 확정  |  ESC: 취소", True, (120, 120, 120))
        screen.blit(help_text, (SCREEN_WIDTH // 2 - help_text.get_width() // 2, SCREEN_HEIGHT - 40))

        pygame.display.flip()

    pygame.quit()

    if confirmed:
        return selected
    return None


if __name__ == "__main__":
    result = main()
    if result:
        print(f"\n최종 선택: {result}")
