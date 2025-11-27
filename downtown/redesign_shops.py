#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 5개 상점 건물을 완전히 새로 디자인하는 스크립트

import re

# 새로운 5개 함수 정의
NEW_CYBERPUNK = '''    def _draw_cyberpunk_shop(self, screen, x, y, w, h, design, pulse, glow):
        """사이버펑크 네온 마켓 - 완전히 새로운 실제 상점 디자인"""
        color = design["color"]
        secondary = design["secondary_color"]

        # === 건물 기본 구조 (금속 벽) ===
        for i in range(h - 15):
            metal_shade = 30 + int(10 * math.sin(i * 0.1 + self.animation_timer))
            pygame.draw.line(screen, (metal_shade, metal_shade, metal_shade + 10),
                           (x, y + 15 + i), (x + w, y + 15 + i))
        pygame.draw.rect(screen, (50, 50, 60), (x, y + 15, w, h - 15), 2, border_radius=5)

        # === 대형 쇼윈도우 (유리창) ===
        window_w, window_h = w - 16, h // 2
        window_x, window_y = x + 8, y + h - window_h - 8

        glass_surf = pygame.Surface((window_w, window_h), pygame.SRCALPHA)
        for i in range(window_h):
            glass_alpha = int(120 + 60 * math.sin(i * 0.05 + self.animation_timer * 0.5))
            pygame.draw.line(glass_surf, (80, 150, 200, glass_alpha), (0, i), (window_w, i))
        screen.blit(glass_surf, (window_x, window_y))
        pygame.draw.rect(screen, (80, 80, 90), (window_x, window_y, window_w, window_h), 3, border_radius=3)

        # 창문 내부 홀로그램 디스플레이
        for i in range(3):
            item_x, item_y = window_x + 15 + i * 25, window_y + window_h // 2
            item_alpha = int(200 * abs(math.sin(self.animation_timer * 2 + i)))
            pygame.draw.circle(screen, (*secondary, item_alpha), (item_x, item_y), 6)
            pygame.draw.circle(screen, (*color, item_alpha // 2), (item_x, item_y), 8)

        # === 네온 간판 "SHOP" (상단, 매우 크게) ===
        sign_h, sign_w = 20, w - 10
        sign_x, sign_y = x + 5, y + 3
        pygame.draw.rect(screen, (15, 15, 25), (sign_x, sign_y, sign_w, sign_h), border_radius=4)

        # 네온 글로우 (5레이어)
        for glow_i in range(5):
            glow_alpha = int(180 * pulse / (glow_i + 1))
            pygame.draw.rect(screen, (*color, glow_alpha),
                           (sign_x - glow_i, sign_y - glow_i, sign_w + glow_i * 2, sign_h + glow_i * 2),
                           1, border_radius=4)

        # "SHOP" 네온 텍스트 (5x7 픽셀)
        neon_letters = [
            [(0,0),(1,0),(2,0),(3,0),(4,0),(0,1),(0,2),(1,3),(2,3),(3,3),(4,3),(4,4),(4,5),(0,6),(1,6),(2,6),(3,6),(4,6)],  # S
            [(0,0),(0,1),(0,2),(0,3),(0,4),(0,5),(0,6),(1,3),(2,3),(3,3),(4,0),(4,1),(4,2),(4,3),(4,4),(4,5),(4,6)],  # H
            [(0,0),(1,0),(2,0),(3,0),(4,0),(0,1),(0,2),(0,3),(0,4),(0,5),(4,1),(4,2),(4,3),(4,4),(4,5),(0,6),(1,6),(2,6),(3,6),(4,6)],  # O
            [(0,0),(0,1),(0,2),(0,3),(0,4),(0,5),(0,6),(1,0),(2,0),(3,0),(4,0),(4,1),(4,2),(1,3),(2,3),(3,3),(4,3)]  # P
        ]

        letter_start_x, letter_y = sign_x + 8, sign_y + 6
        for letter_idx, letter in enumerate(neon_letters):
            letter_x = letter_start_x + letter_idx * 13
            for px, py in letter:
                neon_alpha = int(255 * pulse)
                for glow_size in range(3, 0, -1):
                    glow_alpha = neon_alpha // glow_size
                    pygame.draw.circle(screen, (*secondary, glow_alpha), (letter_x + px, letter_y + py), glow_size)
                pygame.draw.rect(screen, secondary, (letter_x + px, letter_y + py, 1, 1))

        # === 자동문 (슬라이딩 효과) ===
        door_w, door_h = w // 3, (h - 15) // 3
        door_x, door_y = x + (w - door_w) // 2, y + h - door_h - 5
        pygame.draw.rect(screen, (60, 60, 70), (door_x, door_y, door_w, door_h), border_radius=2)

        slide_offset = int(5 * abs(math.sin(self.animation_timer * 0.5)))
        left_door = pygame.Rect(door_x, door_y, door_w // 2 - slide_offset, door_h)
        right_door = pygame.Rect(door_x + door_w // 2 + slide_offset, door_y, door_w // 2 - slide_offset, door_h)
        pygame.draw.rect(screen, (40, 40, 50), left_door)
        pygame.draw.rect(screen, (40, 40, 50), right_door)
        pygame.draw.rect(screen, color, left_door, 2)
        pygame.draw.rect(screen, color, right_door, 2)

        sensor_alpha = int(255 * abs(math.sin(self.animation_timer * 3)))
        pygame.draw.circle(screen, (*secondary, sensor_alpha), (door_x + door_w // 2, door_y + 3), 3)
'''

NEW_FANTASY = '''    def _draw_fantasy_shop(self, screen, x, y, w, h, design, pulse, glow):
        """마법 탑 상점 - 완전히 새로운 탑 구조 디자인"""
        color = design["color"]
        secondary = design["secondary_color"]

        # === 원형 탑 구조 ===
        tower_cx, tower_cy = x + w // 2, y + h // 2 + 10
        tower_radius = min(w, h) // 2 - 5

        # 탑 본체 그라데이션
        for r in range(tower_radius, 0, -1):
            ratio = r / tower_radius
            stone_color = (
                int(80 + 40 * ratio),
                int(60 + 40 * ratio),
                int(100 + 50 * ratio)
            )
            pygame.draw.circle(screen, stone_color, (tower_cx, tower_cy), r)

        # 탑 돌 질감
        for i in range(8):
            angle = i * 45 * math.pi / 180
            stone_x = tower_cx + int((tower_radius - 5) * math.cos(angle))
            stone_y = tower_cy + int((tower_radius - 5) * math.sin(angle))
            pygame.draw.circle(screen, (70, 50, 90), (stone_x, stone_y), 3)

        pygame.draw.circle(screen, color, (tower_cx, tower_cy), tower_radius, 3)

        # === 마법 크리스탈 지붕 ===
        roof_points = [
            (tower_cx, y + 5),
            (tower_cx - 20, tower_cy - tower_radius + 10),
            (tower_cx + 20, tower_cy - tower_radius + 10)
        ]

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

        # 크리스탈 반짝임
        crystal_alpha = int(255 * abs(math.sin(self.animation_timer * 2)))
        for i in range(3):
            sparkle_y = y + 8 + i * 3
            pygame.draw.line(screen, (*secondary, crystal_alpha),
                           (tower_cx - 3, sparkle_y), (tower_cx + 3, sparkle_y), 2)

        # === 회전하는 마법진 (중앙) ===
        for ring in range(3):
            ring_radius = 15 + ring * 8
            ring_alpha = int(200 * pulse / (ring + 1))

            # 마법진 회전
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

        # 마법 룬 "SHOP"
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

        # === 아치형 문 ===
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

# 파일 읽기
with open('building_designs.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 함수 교체를 위한 패턴
def replace_function(content, func_name, new_func):
    # 함수 시작 찾기
    pattern = rf'(    def {func_name}\(self.*?\):.*?\n)(.*?)(\n    def )'

    def replacer(match):
        return match.group(1) + new_func.strip() + '\n\n' + match.group(3)

    return re.sub(pattern, replacer, content, flags=re.DOTALL)

# Cyberpunk 교체
content = replace_function(content, '_draw_cyberpunk_shop', NEW_CYBERPUNK)

# Fantasy 교체
content = replace_function(content, '_draw_fantasy_shop', NEW_FANTASY)

print("함수 교체 완료!")
print("새 파일로 저장 중...")

# 저장
with open('building_designs.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("완료!")
