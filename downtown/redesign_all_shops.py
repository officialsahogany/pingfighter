#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 5개 상점 건물을 완전히 새로 디자인하는 스크립트 (사이버펑크 스타일로 통일)

import re

# 새로운 4개 함수 정의 (Fantasy, Steampunk, Nature, Luxury)

NEW_FANTASY = '''    def _draw_fantasy_shop(self, screen, x, y, w, h, design, pulse, glow):
        """마법 탑 상점 - 완전히 새로운 실제 상점 디자인"""
        color = design["color"]
        secondary = design["secondary_color"]

        # === 원형 탑 구조 ===
        tower_cx, tower_cy = x + w // 2, y + h // 2 + 10
        tower_radius = min(w, h) // 2 - 5

        # 탑 본체 그라데이션 (돌 질감)
        for r in range(tower_radius, 0, -1):
            ratio = r / tower_radius
            stone_color = (
                int(80 + 40 * ratio),
                int(60 + 40 * ratio),
                int(100 + 50 * ratio)
            )
            pygame.draw.circle(screen, stone_color, (tower_cx, tower_cy), r)

        # 탑 돌 질감 (8방향)
        for i in range(8):
            angle = i * 45 * math.pi / 180
            stone_x = tower_cx + int((tower_radius - 5) * math.cos(angle))
            stone_y = tower_cy + int((tower_radius - 5) * math.sin(angle))
            pygame.draw.circle(screen, (70, 50, 90), (stone_x, stone_y), 3)

        pygame.draw.circle(screen, color, (tower_cx, tower_cy), tower_radius, 3)

        # === 마법 크리스탈 지붕 (뾰족한 지붕) ===
        roof_points = [
            (tower_cx, y + 5),  # 꼭대기
            (tower_cx - 20, tower_cy - tower_radius + 10),  # 좌측
            (tower_cx + 20, tower_cy - tower_radius + 10)   # 우측
        ]

        # 지붕 레이어 (5층)
        for layer in range(5):
            layer_alpha = int(180 - layer * 30)
            layer_color = (
                int(secondary[0] * (1 - layer * 0.1)),
                int(secondary[1] * (1 - layer * 0.1)),
                int(secondary[2] * (1 - layer * 0.1))
            )
            layer_points = [
                (roof_points[0][0], roof_points[0][1] + layer * 2),
                (roof_points[1][0] + layer, roof_points[1][1] + layer * 2),
                (roof_points[2][0] - layer, roof_points[2][1] + layer * 2)
            ]
            pygame.draw.polygon(screen, layer_color, layer_points)

        pygame.draw.polygon(screen, secondary, roof_points, 2)

        # 크리스탈 반짝임 (지붕 위)
        crystal_alpha = int(255 * abs(math.sin(self.animation_timer * 2)))
        for i in range(3):
            sparkle_y = y + 8 + i * 3
            pygame.draw.line(screen, (*secondary, crystal_alpha),
                           (tower_cx - 3, sparkle_y), (tower_cx + 3, sparkle_y), 2)

        # === 회전하는 마법진 (중앙, 3중) ===
        for ring in range(3):
            ring_radius = 15 + ring * 8
            ring_alpha = int(200 * pulse / (ring + 1))

            # 마법진 회전 (6개 점)
            for i in range(6):
                angle = (self.animation_timer * (1 + ring * 0.5) + i * 60) * math.pi / 180
                mx = tower_cx + int(ring_radius * math.cos(angle))
                my = tower_cy + int(ring_radius * math.sin(angle))
                pygame.draw.circle(screen, (*secondary, ring_alpha), (mx, my), 2)

            pygame.draw.circle(screen, (*secondary, ring_alpha), (tower_cx, tower_cy), ring_radius, 2)

        # === "SHOP" 마법 룬 간판 (목재 현판) ===
        sign_w, sign_h = w - 20, 18
        sign_x, sign_y = x + 10, y + h - 25
        pygame.draw.rect(screen, (100, 70, 40), (sign_x, sign_y, sign_w, sign_h), border_radius=5)
        pygame.draw.rect(screen, secondary, (sign_x, sign_y, sign_w, sign_h), 2, border_radius=5)

        # 마법 룬 "SHOP" (단순화된 룬 문자)
        rune_letters = [
            [(1,1),(2,1),(1,2),(2,3),(1,4),(2,4)],  # S 룬
            [(0,1),(0,2),(0,3),(0,4),(1,2),(1,3),(2,1),(2,2),(2,3),(2,4)],  # H 룬
            [(1,1),(0,2),(0,3),(2,2),(2,3),(1,4)],  # O 룬
            [(0,1),(0,2),(0,3),(0,4),(1,1),(2,1),(1,2),(2,2)]  # P 룬
        ]

        letter_x, letter_y = sign_x + 10, sign_y + 4
        for i, letter in enumerate(rune_letters):
            lx = letter_x + i * 12
            rune_alpha = int(255 * pulse)
            for px, py in letter:
                pygame.draw.circle(screen, (*secondary, rune_alpha), (lx + px * 2, letter_y + py * 2), 2)

        # === 아치형 문 (하단 중앙) ===
        door_w, door_h = w // 3, h // 4
        door_x, door_y = tower_cx - door_w // 2, tower_cy + tower_radius - door_h - 5
        pygame.draw.rect(screen, (70, 50, 80), (door_x, door_y, door_w, door_h), border_radius=5)

        # 아치 상단
        arch_points = [
            (door_x, door_y + 5),
            (door_x + door_w // 2, door_y - 8),
            (door_x + door_w, door_y + 5)
        ]
        pygame.draw.polygon(screen, (90, 70, 110), arch_points)
        pygame.draw.polygon(screen, secondary, arch_points, 2)

        # 마법 보석 손잡이
        handle_alpha = int(255 * abs(math.sin(self.animation_timer * 1.5)))
        pygame.draw.circle(screen, (*secondary, handle_alpha), (door_x + door_w // 2, door_y + door_h // 2), 4)
'''

NEW_STEAMPUNK = '''    def _draw_steampunk_shop(self, screen, x, y, w, h, design, pulse, glow):
        """증기펑크 공방 - 완전히 새로운 실제 상점 디자인"""
        color = design["color"]
        secondary = design["secondary_color"]

        # === 벽돌 건물 구조 (금속 보강재) ===
        # 벽돌 질감
        for i in range(h - 15):
            brick_shade = 70 + int(20 * math.sin(i * 0.1))
            pygame.draw.line(screen, (brick_shade, brick_shade - 10, brick_shade - 30),
                           (x, y + 15 + i), (x + w, y + 15 + i))

        # 건물 테두리 (금속 보강재)
        pygame.draw.rect(screen, (80, 80, 90), (x, y + 15, w, h - 15), 3, border_radius=5)

        # 리벳 패턴 (4x8 그리드)
        for row in range(4):
            for col in range(8):
                rivet_x = x + 8 + col * 11
                rivet_y = y + 20 + row * 18
                pygame.draw.circle(screen, secondary, (rivet_x, rivet_y), 2)
                pygame.draw.circle(screen, (150, 140, 130), (rivet_x - 1, rivet_y - 1), 1)

        # === 대형 쇼윈도우 (증기 효과) ===
        window_w, window_h = w - 16, h // 2
        window_x, window_y = x + 8, y + h - window_h - 8

        # 유리창 (약간 어두운 색)
        glass_surf = pygame.Surface((window_w, window_h), pygame.SRCALPHA)
        for i in range(window_h):
            glass_alpha = int(90 + 40 * math.sin(i * 0.05))
            pygame.draw.line(glass_surf, (100, 100, 110, glass_alpha), (0, i), (window_w, i))
        screen.blit(glass_surf, (window_x, window_y))
        pygame.draw.rect(screen, (80, 80, 90), (window_x, window_y, window_w, window_h), 3, border_radius=3)

        # 창문 내부 기어 디스플레이 (3개 회전하는 기어)
        gear_angle = self.animation_timer * 50
        for i in range(3):
            gear_x = window_x + 20 + i * 25
            gear_y = window_y + window_h // 2
            gear_radius = 8
            gear_teeth = 8

            # 기어 본체
            pygame.draw.circle(screen, (60, 50, 30), (gear_x, gear_y), gear_radius)
            pygame.draw.circle(screen, secondary, (gear_x, gear_y), gear_radius, 2)

            # 기어 톱니 (8개)
            for tooth_idx in range(gear_teeth):
                angle = (gear_angle + tooth_idx * 45 + i * 120) * math.pi / 180
                tooth_x1 = gear_x + int((gear_radius - 1) * math.cos(angle))
                tooth_y1 = gear_y + int((gear_radius - 1) * math.sin(angle))
                tooth_x2 = gear_x + int((gear_radius + 3) * math.cos(angle))
                tooth_y2 = gear_y + int((gear_radius + 3) * math.sin(angle))
                pygame.draw.line(screen, secondary, (tooth_x1, tooth_y1), (tooth_x2, tooth_y2), 2)

            # 중앙 축
            pygame.draw.circle(screen, color, (gear_x, gear_y), 3)

        # === 황동 명판 "SHOP" 간판 (상단) ===
        sign_h, sign_w = 18, w - 10
        sign_x, sign_y = x + 5, y + 3
        pygame.draw.rect(screen, (184, 134, 11), (sign_x, sign_y, sign_w, sign_h), border_radius=3)
        pygame.draw.rect(screen, secondary, (sign_x, sign_y, sign_w, sign_h), 2, border_radius=3)

        # 리벳 장식 (4개 모서리)
        for rivet_pos in [(sign_x + 3, sign_y + 3), (sign_x + sign_w - 3, sign_y + 3),
                         (sign_x + 3, sign_y + sign_h - 3), (sign_x + sign_w - 3, sign_y + sign_h - 3)]:
            pygame.draw.circle(screen, (100, 80, 60), rivet_pos, 2)
            pygame.draw.circle(screen, (150, 120, 90), (rivet_pos[0] - 1, rivet_pos[1] - 1), 1)

        # "SHOP" 텍스트 (기계식 각인)
        shop_letters = [
            [(0,0),(1,0),(2,0),(3,0),(4,0),(0,1),(0,2),(1,2),(2,2),(3,2),(4,2),(4,3),(4,4),(0,4),(1,4),(2,4),(3,4),(4,4)],  # S
            [(0,0),(0,1),(0,2),(0,3),(0,4),(2,2),(4,0),(4,1),(4,2),(4,3),(4,4)],  # H
            [(0,0),(1,0),(2,0),(3,0),(4,0),(0,1),(0,2),(0,3),(0,4),(4,1),(4,2),(4,3),(4,4),(1,4),(2,4),(3,4),(4,4)],  # O
            [(0,0),(1,0),(2,0),(3,0),(4,0),(0,1),(0,2),(0,3),(0,4),(4,1),(4,2),(2,2),(3,2)]  # P
        ]

        letter_x, letter_y = sign_x + 8, sign_y + 6
        for i, letter in enumerate(shop_letters):
            for px, py in letter:
                draw_x = letter_x + i * 9 + px
                draw_y = letter_y + py
                pygame.draw.rect(screen, (60, 50, 30), (draw_x, draw_y, 1, 1))

        # === 산업용 문 (증기 배출구) ===
        door_w, door_h = w // 3, h // 4
        door_x, door_y = x + (w - door_w) // 2, y + h - door_h - 5
        pygame.draw.rect(screen, (40, 40, 40), (door_x, door_y, door_w, door_h), border_radius=3)
        pygame.draw.rect(screen, secondary, (door_x, door_y, door_w, door_h), 3, border_radius=3)

        # 문 리벳 (2x3 패턴)
        for row in range(2):
            for col in range(3):
                rivet_x = door_x + 7 + col * (door_w - 14) // 2
                rivet_y = door_y + 5 + row * (door_h - 10)
                pygame.draw.circle(screen, (100, 80, 60), (rivet_x, rivet_y), 2)

        # 증기 배출구 (문 상단)
        steam_alpha = int(120 * abs(math.sin(self.animation_timer * 2)))
        for i in range(3):
            steam_x = door_x + door_w // 2 - 6 + i * 6
            steam_y = door_y - 3
            pygame.draw.circle(screen, (180, 180, 180, steam_alpha), (steam_x, steam_y), 2)

        # 기계식 손잡이
        handle_x, handle_y = door_x + door_w // 2, door_y + door_h // 2
        pygame.draw.circle(screen, (80, 70, 50), (handle_x, handle_y), 4)
        pygame.draw.circle(screen, secondary, (handle_x, handle_y), 3, 2)
'''

NEW_NATURE = '''    def _draw_nature_shop(self, screen, x, y, w, h, design, pulse, glow):
        """자연 오두막 - 완전히 새로운 실제 상점 디자인"""
        color = design["color"]
        secondary = design["secondary_color"]

        # === 나무 오두막 구조 ===
        # 나무 벽 질감
        for i in range(h - 15):
            wood_pattern = abs(math.sin(i * 0.2)) * 20
            wood_color = (
                int(139 + wood_pattern),
                int(90 + wood_pattern * 0.6),
                int(43 + wood_pattern * 0.4)
            )
            pygame.draw.line(screen, wood_color, (x, y + 15 + i), (x + w, y + 15 + i))

        pygame.draw.rect(screen, (100, 70, 30), (x, y + 15, w, h - 15), 3, border_radius=8)

        # === 초가 지붕 (여러 레이어) ===
        for layer in range(4):
            layer_offset = layer * 3
            roof_color = (
                int(secondary[0] * (1 - layer * 0.12)),
                int(secondary[1] * (1 - layer * 0.12)),
                int(secondary[2] * (1 - layer * 0.12))
            )
            roof_points = [
                (x + layer_offset, y + 15 - layer_offset),
                (x + w // 2, y - layer * 2),
                (x + w - layer_offset, y + 15 - layer_offset)
            ]
            pygame.draw.polygon(screen, roof_color, roof_points)
            if layer > 0:
                pygame.draw.lines(screen, color, False, roof_points, 1)

        # === 대형 창문 (2개, 따뜻한 빛) ===
        for i in range(2):
            window_x = x + 15 + i * 40
            window_y = y + 30
            window_w, window_h = 25, 20

            # 창문 글로우 (따뜻한 노란빛)
            window_alpha = int(180 * pulse)
            pygame.draw.rect(screen, (*color, window_alpha // 3),
                           (window_x - 2, window_y - 2, window_w + 4, window_h + 4), border_radius=4)
            pygame.draw.rect(screen, (255, 240, 200), (window_x, window_y, window_w, window_h), border_radius=3)
            pygame.draw.rect(screen, (100, 70, 30), (window_x, window_y, window_w, window_h), 2, border_radius=3)

            # 십자 창틀
            pygame.draw.line(screen, (100, 70, 30),
                           (window_x + window_w // 2, window_y),
                           (window_x + window_w // 2, window_y + window_h), 2)
            pygame.draw.line(screen, (100, 70, 30),
                           (window_x, window_y + window_h // 2),
                           (window_x + window_w, window_y + window_h // 2), 2)

        # === 덩굴 식물 (양옆 장식) ===
        for side in [-1, 1]:
            vine_x = x + w // 2 + side * (w // 2 - 5)
            for i in range(8):
                vine_y = y + 25 + i * 8
                vine_offset = int(3 * math.sin(self.animation_timer * 2 + i * 0.5))
                leaf_alpha = int(200 * abs(math.cos(self.animation_timer + i * 0.3)))

                # 줄기
                pygame.draw.circle(screen, (50, 100, 50), (vine_x + vine_offset * side, vine_y), 1)

                # 잎
                if i % 2 == 0:
                    pygame.draw.circle(screen, (*color, leaf_alpha),
                                     (vine_x + vine_offset * side + side * 5, vine_y), 3)

        # === "SHOP" 나무 간판 (목재 조각판) ===
        sign_h, sign_w = 18, w - 20
        sign_x, sign_y = x + 10, y + 20
        pygame.draw.rect(screen, (139, 90, 43), (sign_x, sign_y, sign_w, sign_h), border_radius=5)
        pygame.draw.rect(screen, (100, 70, 30), (sign_x, sign_y, sign_w, sign_h), 2, border_radius=5)

        # 나무 질감 선 (2줄)
        for line_offset in [sign_h // 3, 2 * sign_h // 3]:
            pygame.draw.line(screen, (120, 80, 40),
                           (sign_x + 2, sign_y + line_offset),
                           (sign_x + sign_w - 2, sign_y + line_offset), 1)

        # 잎 장식 (좌우)
        for side_x in [sign_x + 3, sign_x + sign_w - 6]:
            pygame.draw.circle(screen, (*color, 180), (side_x, sign_y + sign_h // 2), 3)

        # "SHOP" 텍스트 (새긴 글씨)
        shop_letters = [
            [(0,0),(1,0),(2,0),(3,0),(0,1),(0,2),(1,2),(2,2),(3,2),(3,3),(3,4),(0,4),(1,4),(2,4),(3,4)],  # S
            [(0,0),(0,1),(0,2),(0,3),(0,4),(1,2),(2,2),(3,0),(3,1),(3,2),(3,3),(3,4)],  # H
            [(0,0),(1,0),(2,0),(3,0),(0,1),(0,2),(0,3),(0,4),(1,4),(2,4),(3,4),(3,1),(3,2),(3,3)],  # O
            [(0,0),(0,1),(0,2),(0,3),(0,4),(1,0),(2,0),(3,0),(3,1),(3,2),(1,2),(2,2)]  # P
        ]

        letter_x, letter_y = sign_x + 12, sign_y + 6
        for i, letter in enumerate(shop_letters):
            for px, py in letter:
                draw_x = letter_x + i * 7 + px
                draw_y = letter_y + py
                pygame.draw.rect(screen, (50, 80, 30), (draw_x, draw_y, 1, 1))

        # === 나무 문 (판자 문) ===
        door_w, door_h = w // 3, h // 4
        door_x, door_y = x + (w - door_w) // 2, y + h - door_h - 8
        pygame.draw.rect(screen, (120, 80, 40), (door_x, door_y, door_w, door_h), border_radius=4)
        pygame.draw.rect(screen, (100, 70, 30), (door_x, door_y, door_w, door_h), 2, border_radius=4)

        # 세로 판자 질감 (3개)
        for plank_offset in [door_w // 4, door_w // 2, 3 * door_w // 4]:
            pygame.draw.line(screen, (100, 70, 30),
                           (door_x + plank_offset, door_y),
                           (door_x + plank_offset, door_y + door_h), 1)

        # 나뭇잎 손잡이
        handle_x, handle_y = door_x + door_w // 2, door_y + door_h // 2
        handle_alpha = int(200 * abs(math.sin(self.animation_timer * 1.5)))
        leaf_points = [
            (handle_x, handle_y - 4),
            (handle_x + 3, handle_y),
            (handle_x, handle_y + 4),
            (handle_x - 3, handle_y)
        ]
        pygame.draw.polygon(screen, (*color, handle_alpha), leaf_points)
        pygame.draw.polygon(screen, (50, 100, 50), leaf_points, 1)
'''

NEW_LUXURY = '''    def _draw_luxury_shop(self, screen, x, y, w, h, design, pulse, glow):
        """럭셔리 부티크 - 완전히 새로운 실제 상점 디자인"""
        color = design["color"]
        secondary = design["secondary_color"]

        # === 대리석 건물 구조 ===
        # 대리석 그라데이션
        for i in range(h):
            gradient_ratio = i / h
            shimmer = abs(math.sin((gradient_ratio * 3 + self.animation_timer * 2) * math.pi)) * 20
            marble_color = (
                int(240 - gradient_ratio * 30 + shimmer),
                int(235 - gradient_ratio * 25 + shimmer),
                int(230 - gradient_ratio * 20 + shimmer)
            )
            pygame.draw.line(screen, marble_color, (x, y + i), (x + w, y + i))

        # 황금 테두리 (3중)
        for i in range(3):
            offset = i * 2
            pygame.draw.rect(screen, color,
                           (x + offset, y + offset, w - offset * 2, h - offset * 2),
                           2, border_radius=8 - i)

        # === 대형 쇼윈도우 (하단 60%) ===
        window_w, window_h = w - 12, int(h * 0.6)
        window_x, window_y = x + 6, y + h - window_h - 6

        # 고급 유리 반사
        glass_surf = pygame.Surface((window_w, window_h), pygame.SRCALPHA)
        for i in range(window_h):
            glass_alpha = int(100 + 60 * math.sin(i * 0.04 + self.animation_timer * 0.4))
            pygame.draw.line(glass_surf, (200, 200, 220, glass_alpha), (0, i), (window_w, i))
        screen.blit(glass_surf, (window_x, window_y))
        pygame.draw.rect(screen, color, (window_x, window_y, window_w, window_h), 3, border_radius=4)

        # 창문 내부 고급 상품 디스플레이 (4개 회전하는 다이아몬드)
        for i in range(4):
            item_x = window_x + 15 + i * 18
            item_y = window_y + window_h // 2
            diamond_rotation = self.animation_timer * 50 + i * 90

            # 다이아몬드 모양
            diamond_points = [
                (item_x + int(6 * math.cos(math.radians(diamond_rotation + 90))),
                 item_y + int(6 * math.sin(math.radians(diamond_rotation + 90)))),
                (item_x + int(4 * math.cos(math.radians(diamond_rotation))),
                 item_y + int(4 * math.sin(math.radians(diamond_rotation)))),
                (item_x + int(6 * math.cos(math.radians(diamond_rotation + 270))),
                 item_y + int(6 * math.sin(math.radians(diamond_rotation + 270)))),
                (item_x + int(4 * math.cos(math.radians(diamond_rotation + 180))),
                 item_y + int(4 * math.sin(math.radians(diamond_rotation + 180))))
            ]

            item_alpha = int(200 * abs(math.sin(self.animation_timer * 2 + i * 0.7)))
            pygame.draw.polygon(screen, (*secondary, item_alpha), diamond_points)
            pygame.draw.polygon(screen, color, diamond_points, 1)

        # === 황금 명판 "SHOP" 간판 (상단) ===
        sign_h, sign_w = 20, w - 10
        sign_x, sign_y = x + 5, y + 5

        # 황금 그라데이션 배경
        for i in range(sign_h):
            gradient_ratio = i / sign_h
            shimmer = abs(math.sin((gradient_ratio * 2 + self.animation_timer * 3) * math.pi)) * 30
            gold_color = (
                min(255, int(255 - gradient_ratio * 40 + shimmer)),
                min(255, int(215 - gradient_ratio * 25 + shimmer * 0.8)),
                max(0, int(shimmer * 0.3))
            )
            pygame.draw.line(screen, gold_color, (sign_x, sign_y + i), (sign_x + sign_w, sign_y + i))

        pygame.draw.rect(screen, color, (sign_x, sign_y, sign_w, sign_h), 3, border_radius=4)
        pygame.draw.rect(screen, secondary, (sign_x + 2, sign_y + 2, sign_w - 4, sign_h - 4), 1, border_radius=3)

        # 보석 장식 (4개 모서리)
        for gem_pos in [(sign_x + 4, sign_y + 4), (sign_x + sign_w - 4, sign_y + 4),
                       (sign_x + 4, sign_y + sign_h - 4), (sign_x + sign_w - 4, sign_y + sign_h - 4)]:
            gem_alpha = int(255 * abs(math.sin(self.animation_timer * 2)))
            gem_points = [
                (gem_pos[0], gem_pos[1] - 2),
                (gem_pos[0] + 2, gem_pos[1]),
                (gem_pos[0], gem_pos[1] + 2),
                (gem_pos[0] - 2, gem_pos[1])
            ]
            pygame.draw.polygon(screen, (*secondary, gem_alpha), gem_points)

        # "SHOP" 텍스트 (황금 각인, 5x7 픽셀)
        shop_letters = [
            [(0,0),(1,0),(2,0),(3,0),(4,0),(0,1),(0,2),(0,3),(1,3),(2,3),(3,3),(4,3),(4,4),(4,5),(4,6),(0,6),(1,6),(2,6),(3,6),(4,6)],  # S
            [(0,0),(0,1),(0,2),(0,3),(0,4),(0,5),(0,6),(1,3),(2,3),(3,3),(4,0),(4,1),(4,2),(4,3),(4,4),(4,5),(4,6)],  # H
            [(0,0),(1,0),(2,0),(3,0),(4,0),(0,1),(0,2),(0,3),(0,4),(0,5),(4,1),(4,2),(4,3),(4,4),(4,5),(0,6),(1,6),(2,6),(3,6),(4,6)],  # O
            [(0,0),(0,1),(0,2),(0,3),(0,4),(0,5),(0,6),(1,0),(2,0),(3,0),(4,0),(4,1),(4,2),(4,3),(1,3),(2,3),(3,3)]  # P
        ]

        letter_x, letter_y = sign_x + 10, sign_y + 6
        for i, letter in enumerate(shop_letters):
            for px, py in letter:
                draw_x = letter_x + i * 9 + px
                draw_y = letter_y + py
                pygame.draw.rect(screen, (200, 150, 0), (draw_x, draw_y, 1, 1))
                # 하이라이트
                if px == 0 or py == 0:
                    pygame.draw.rect(screen, (255, 220, 100), (draw_x, draw_y, 1, 1))

        # === 프리미엄 문 (대칭 디자인) ===
        door_w, door_h = w // 3, h // 4
        door_x, door_y = x + (w - door_w) // 2, y + h - door_h - 5

        # 문 배경 (화려한 그라데이션)
        for i in range(door_h):
            gradient_ratio = i / door_h
            door_color = (
                int(250 - gradient_ratio * 30),
                int(245 - gradient_ratio * 25),
                int(240 - gradient_ratio * 20)
            )
            pygame.draw.line(screen, door_color, (door_x, door_y + i), (door_x + door_w, door_y + i))

        pygame.draw.rect(screen, color, (door_x, door_y, door_w, door_h), 3, border_radius=4)
        pygame.draw.rect(screen, secondary, (door_x + 2, door_y + 2, door_w - 4, door_h - 4), 1, border_radius=3)

        # 황금 손잡이 (중앙, 보석 장식)
        handle_x, handle_y = door_x + door_w // 2, door_y + door_h // 2
        handle_alpha = int(255 * abs(math.sin(self.animation_timer * 1.5)))

        # 손잡이 글로우 (5 레이어)
        for glow_r in range(7, 2, -1):
            glow_alpha = int(handle_alpha / (8 - glow_r))
            pygame.draw.circle(screen, (*color, glow_alpha), (handle_x, handle_y), glow_r)

        # 메인 손잡이
        pygame.draw.circle(screen, color, (handle_x, handle_y), 4)
        pygame.draw.circle(screen, secondary, (handle_x, handle_y), 3)
        pygame.draw.circle(screen, (255, 240, 200), (handle_x - 1, handle_y - 1), 2)
'''

# 파일 읽기
print("building_designs.py 파일 읽는 중...")
with open('downtown/building_designs.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 함수 교체를 위한 패턴
def replace_function(content, func_name, new_func):
    """함수 전체를 교체"""
    # 함수 시작부터 다음 함수 시작 전까지 찾기
    pattern = rf'(    def {func_name}\(self.*?\n)(.*?)(\n    def )'

    def replacer(match):
        # 새 함수로 교체 (들여쓰기 유지)
        return match.group(1) + new_func.strip() + '\n\n' + match.group(3)

    result = re.sub(pattern, replacer, content, flags=re.DOTALL)

    # 마지막 함수인 경우 (다음 def가 없음)
    if result == content:
        pattern = rf'(    def {func_name}\(self.*?\n)(.*?)(\n\n# 싱글톤)'
        result = re.sub(pattern, replacer, content, flags=re.DOTALL)

    return result

print("\n=== 함수 교체 시작 ===")

# Fantasy 교체
print("1/4: Fantasy 함수 교체 중...")
content = replace_function(content, '_draw_fantasy_shop', NEW_FANTASY)

# Steampunk 교체
print("2/4: Steampunk 함수 교체 중...")
content = replace_function(content, '_draw_steampunk_shop', NEW_STEAMPUNK)

# Nature 교체
print("3/4: Nature 함수 교체 중...")
content = replace_function(content, '_draw_nature_shop', NEW_NATURE)

# Luxury 교체
print("4/4: Luxury 함수 교체 중...")
content = replace_function(content, '_draw_luxury_shop', NEW_LUXURY)

print("\n=== 함수 교체 완료! ===")
print("새 파일로 저장 중...")

# 저장
with open('downtown/building_designs.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("\n✅ 완료!")
print("\n변경된 함수:")
print("  1. _draw_fantasy_shop - 마법 탑 상점")
print("  2. _draw_steampunk_shop - 증기펑크 공방")
print("  3. _draw_nature_shop - 자연 오두막")
print("  4. _draw_luxury_shop - 럭셔리 부티크")
print("\n미리보기를 실행하려면:")
print("  python3 downtown/preview_shop_designs.py")
