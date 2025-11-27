#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# downtown/building_interior.py
# 건물 내부 시스템

import pygame
import pygame.freetype
import math
import random
from .constants import (
    SCREEN_WIDTH, SCREEN_HEIGHT, BuildingType, Colors, resource_path
)

class InteriorNPC:
    """건물 내부 NPC"""
    def __init__(self, x, y, name, role, color, dialogue=None):
        self.x = x
        self.y = y
        self.name = name
        self.role = role  # "customer", "staff", "main"
        self.color = color
        self.dialogue = dialogue or []
        self.size = 25 if role == "main" else 20
        self.animation_offset = random.random() * math.pi * 2

    def update(self, dt, animation_timer):
        """NPC 애니메이션 업데이트"""
        pass

    def draw(self, screen, animation_timer):
        """NPC 그리기"""
        # 간단한 원형 NPC (나중에 스프라이트로 교체 가능)
        bob_offset = int(3 * math.sin(animation_timer * 2 + self.animation_offset))

        # 그림자
        shadow_color = (50, 50, 50, 100)
        shadow_surf = pygame.Surface((self.size + 10, 8), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, shadow_color, (0, 0, self.size + 10, 8))
        screen.blit(shadow_surf, (self.x - (self.size + 10) // 2, self.y + self.size // 2))

        # NPC 몸체
        pygame.draw.circle(screen, self.color, (self.x, self.y + bob_offset), self.size)
        pygame.draw.circle(screen, (255, 255, 255), (self.x, self.y + bob_offset), self.size, 2)

        # 메인 NPC는 왕관 표시
        if self.role == "main":
            crown_points = [
                (self.x, self.y + bob_offset - self.size - 5),
                (self.x - 8, self.y + bob_offset - self.size + 2),
                (self.x - 4, self.y + bob_offset - self.size - 2),
                (self.x, self.y + bob_offset - self.size + 2),
                (self.x + 4, self.y + bob_offset - self.size - 2),
                (self.x + 8, self.y + bob_offset - self.size + 2),
            ]
            pygame.draw.polygon(screen, (255, 215, 0), crown_points)
            pygame.draw.polygon(screen, (200, 180, 0), crown_points, 2)

class BuildingInterior:
    """건물 내부"""
    def __init__(self, building_type, freetype_fonts):
        self.building_type = building_type
        self.fonts = freetype_fonts
        self.animation_timer = 0

        # 건물별 설정
        self.config = self._get_building_config()

        # 출구 버튼
        self.exit_button = pygame.Rect(
            SCREEN_WIDTH - 120, SCREEN_HEIGHT - 60, 100, 40
        )

        # NPC 생성
        self.npcs = self._create_npcs()

    def _get_building_config(self):
        """건물별 설정"""
        configs = {
            BuildingType.MAGIC_STORE: {
                "name": "마법 상점",
                "name_en": "Magic Store",
                "bg_color": (30, 20, 50),
                "accent_color": (138, 43, 226),
                "secondary_color": (255, 0, 255),
                "floor_color": (50, 30, 70),
                "wall_style": "mystical",
                "decorations": ["crystals", "floating_orbs", "magic_circles"],
                "main_npc": {
                    "name": "마법사 메를린",
                    "color": (138, 43, 226),
                    "position": (SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 50),
                    "dialogue": [
                        "환영하오, 여행자여!",
                        "이곳은 신비로운 마법의 상점이오.",
                        "필요한 물건이 있으신가?"
                    ]
                },
                "customer_count": 3,
                "staff_count": 1
            },
            BuildingType.ITEM_SHOP: {
                "name": "네온 마켓",
                "name_en": "Neon Market",
                "bg_color": (20, 20, 30),
                "accent_color": (0, 255, 255),
                "secondary_color": (255, 20, 147),
                "floor_color": (40, 40, 50),
                "wall_style": "cyberpunk",
                "decorations": ["neon_signs", "holographic_displays", "led_strips"],
                "main_npc": {
                    "name": "점주 사이버",
                    "color": (0, 255, 255),
                    "position": (SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 50),
                    "dialogue": [
                        "어서오세요, 고객님!",
                        "최신 아이템이 입고되었습니다.",
                        "뭘 찾으시나요?"
                    ]
                },
                "customer_count": 4,
                "staff_count": 2
            },
            BuildingType.BLACKSMITH: {
                "name": "대장간",
                "name_en": "Blacksmith",
                "bg_color": (60, 30, 20),
                "accent_color": (255, 140, 0),
                "secondary_color": (255, 69, 0),
                "floor_color": (80, 50, 30),
                "wall_style": "industrial",
                "decorations": ["anvil", "forge", "weapons"],
                "main_npc": {
                    "name": "대장장이 헤파이토스",
                    "color": (255, 140, 0),
                    "position": (SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 50),
                    "dialogue": [
                        "무기를 강화하러 왔나?",
                        "내 솜씨는 보장하지!",
                        "뭘 만들어줄까?"
                    ]
                },
                "customer_count": 2,
                "staff_count": 1
            },
            BuildingType.CASINO: {
                "name": "카지노",
                "name_en": "Casino",
                "bg_color": (40, 10, 10),
                "accent_color": (220, 20, 60),
                "secondary_color": (255, 215, 0),
                "floor_color": (60, 20, 20),
                "wall_style": "luxury",
                "decorations": ["slot_machines", "card_tables", "roulette"],
                "main_npc": {
                    "name": "딜러 포춘",
                    "color": (220, 20, 60),
                    "position": (SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 50),
                    "dialogue": [
                        "행운을 시험해보시겠습니까?",
                        "이 테이블은 항상 열려있습니다.",
                        "승부를 걸어보세요!"
                    ]
                },
                "customer_count": 5,
                "staff_count": 2
            },
            BuildingType.TAVERN: {
                "name": "주점",
                "name_en": "Tavern",
                "bg_color": (50, 35, 20),
                "accent_color": (210, 180, 140),
                "secondary_color": (160, 82, 45),
                "floor_color": (70, 50, 30),
                "wall_style": "wooden",
                "decorations": ["barrels", "bottles", "tables"],
                "main_npc": {
                    "name": "주인 바커스",
                    "color": (210, 180, 140),
                    "position": (SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 50),
                    "dialogue": [
                        "어서오게! 뭘 마시겠나?",
                        "여기선 최고의 술을 팔지.",
                        "피곤한 하루였나보군."
                    ]
                },
                "customer_count": 6,
                "staff_count": 1
            },
            # 기타 건물들 (추후 확장)
        }

        return configs.get(self.building_type, {
            "name": "건물",
            "name_en": "Building",
            "bg_color": (40, 40, 40),
            "accent_color": (100, 100, 100),
            "secondary_color": (150, 150, 150),
            "floor_color": (60, 60, 60),
            "wall_style": "plain",
            "decorations": [],
            "main_npc": {
                "name": "주인",
                "color": (100, 100, 100),
                "position": (SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 50),
                "dialogue": ["안녕하세요."]
            },
            "customer_count": 2,
            "staff_count": 1
        })

    def _create_npcs(self):
        """NPC 생성"""
        npcs = []

        # 메인 NPC
        main_config = self.config["main_npc"]
        main_npc = InteriorNPC(
            main_config["position"][0],
            main_config["position"][1],
            main_config["name"],
            "main",
            main_config["color"],
            main_config["dialogue"]
        )
        npcs.append(main_npc)

        # 고객 NPC들 (랜덤 배치)
        customer_colors = [
            (100, 150, 200),
            (200, 150, 100),
            (150, 200, 100),
            (200, 100, 150),
            (150, 100, 200),
            (100, 200, 150)
        ]

        for i in range(self.config["customer_count"]):
            x = random.randint(100, SCREEN_WIDTH - 100)
            y = random.randint(200, SCREEN_HEIGHT - 150)
            # 메인 NPC와 너무 가까우면 재배치
            while abs(x - main_config["position"][0]) < 80 and abs(y - main_config["position"][1]) < 80:
                x = random.randint(100, SCREEN_WIDTH - 100)
                y = random.randint(200, SCREEN_HEIGHT - 150)

            customer = InteriorNPC(
                x, y,
                f"고객 {i+1}",
                "customer",
                customer_colors[i % len(customer_colors)],
                ["..."]
            )
            npcs.append(customer)

        # 직원 NPC들
        staff_color = tuple(int(c * 0.8) for c in self.config["accent_color"])
        for i in range(self.config["staff_count"]):
            x = 100 + i * 150
            y = SCREEN_HEIGHT - 200
            staff = InteriorNPC(
                x, y,
                f"직원 {i+1}",
                "staff",
                staff_color,
                ["어서오세요!"]
            )
            npcs.append(staff)

        return npcs

    def update(self, dt):
        """업데이트"""
        self.animation_timer += dt

        for npc in self.npcs:
            npc.update(dt, self.animation_timer)

    def draw(self, screen):
        """건물 내부 그리기"""
        # 배경
        screen.fill(self.config["bg_color"])

        # 바닥 패턴
        self._draw_floor(screen)

        # 벽 장식
        self._draw_walls(screen)

        # 인테리어 장식
        self._draw_decorations(screen)

        # NPC들
        for npc in self.npcs:
            npc.draw(screen, self.animation_timer)

        # NPC 이름 표시 (메인 NPC만)
        for npc in self.npcs:
            if npc.role == "main":
                self._draw_npc_name(screen, npc)

        # 출구 버튼
        self._draw_exit_button(screen)

        # 건물 이름
        self._draw_building_name(screen)

    def _draw_floor(self, screen):
        """바닥 그리기"""
        tile_size = 50
        floor_color = self.config["floor_color"]

        for y in range(0, SCREEN_HEIGHT, tile_size):
            for x in range(0, SCREEN_WIDTH, tile_size):
                # 체크 패턴
                if (x // tile_size + y // tile_size) % 2 == 0:
                    color = floor_color
                else:
                    color = tuple(max(0, c - 10) for c in floor_color)

                pygame.draw.rect(screen, color, (x, y, tile_size, tile_size))
                pygame.draw.rect(screen, tuple(max(0, c - 20) for c in floor_color),
                               (x, y, tile_size, tile_size), 1)

    def _draw_walls(self, screen):
        """벽 그리기"""
        wall_height = 80
        accent_color = self.config["accent_color"]

        # 상단 벽
        pygame.draw.rect(screen, tuple(c // 2 for c in self.config["bg_color"]),
                        (0, 0, SCREEN_WIDTH, wall_height))

        # 벽 장식 라인
        for i in range(3):
            y = wall_height - 10 - i * 15
            alpha = int(150 - i * 40)
            line_surf = pygame.Surface((SCREEN_WIDTH, 2), pygame.SRCALPHA)
            line_surf.fill((*accent_color, alpha))
            screen.blit(line_surf, (0, y))

    def _draw_decorations(self, screen):
        """인테리어 장식 그리기"""
        decorations = self.config["decorations"]
        accent_color = self.config["accent_color"]
        secondary_color = self.config["secondary_color"]

        # 벽 스타일별 장식
        if self.config["wall_style"] == "mystical":
            # 마법진
            for i in range(3):
                x = 150 + i * 300
                y = 100
                radius = 30
                for r in range(3):
                    alpha = int(150 * abs(math.sin(self.animation_timer + r)))
                    pygame.draw.circle(screen, (*accent_color, alpha), (x, y), radius - r * 10, 2)

        elif self.config["wall_style"] == "cyberpunk":
            # 네온 스트립
            for i in range(5):
                x = 50 + i * 200
                y = 50
                w = 150
                h = 10
                glow_alpha = int(200 * abs(math.sin(self.animation_timer * 2 + i)))
                pygame.draw.rect(screen, (*accent_color, glow_alpha), (x, y, w, h))
                pygame.draw.rect(screen, secondary_color, (x, y, w, h), 2)

        elif self.config["wall_style"] == "industrial":
            # 연장 걸이
            for i in range(4):
                x = 100 + i * 250
                y = 80
                pygame.draw.line(screen, accent_color, (x, y), (x, y + 30), 3)
                pygame.draw.circle(screen, secondary_color, (x, y + 35), 8)

        elif self.config["wall_style"] == "luxury":
            # 샹들리에 효과
            x = SCREEN_WIDTH // 2
            y = 100
            for i in range(8):
                angle = i * 45 + self.animation_timer * 20
                px = x + int(40 * math.cos(math.radians(angle)))
                py = y + int(20 * math.sin(math.radians(angle)))
                alpha = int(200 * abs(math.sin(self.animation_timer * 2 + i)))
                pygame.draw.circle(screen, (*secondary_color, alpha), (px, py), 5)

        elif self.config["wall_style"] == "wooden":
            # 나무 기둥
            for i in range(3):
                x = 200 + i * 300
                y = 80
                w = 30
                h = SCREEN_HEIGHT - 80
                pygame.draw.rect(screen, (101, 67, 33), (x, y, w, h))
                pygame.draw.rect(screen, (80, 50, 20), (x, y, w, h), 2)

    def _draw_npc_name(self, screen, npc):
        """NPC 이름 표시"""
        font = self.fonts.get('small')
        if font:
            name_surf, name_rect = font.render(npc.name, Colors.TEXT_WHITE)
            name_x = npc.x - name_rect.width // 2
            name_y = npc.y - npc.size - 30

            # 배경
            bg_rect = pygame.Rect(name_x - 5, name_y - 3, name_rect.width + 10, name_rect.height + 6)
            bg_surf = pygame.Surface(bg_rect.size, pygame.SRCALPHA)
            bg_surf.fill((0, 0, 0, 180))
            screen.blit(bg_surf, bg_rect.topleft)

            # 텍스트
            screen.blit(name_surf, (name_x, name_y))

    def _draw_exit_button(self, screen):
        """나가기 버튼"""
        # 버튼 배경
        pygame.draw.rect(screen, (50, 50, 60), self.exit_button, border_radius=8)
        pygame.draw.rect(screen, (100, 100, 120), self.exit_button, 2, border_radius=8)

        # 텍스트
        font = self.fonts.get('medium')
        if font:
            text_surf, text_rect = font.render("나가기", Colors.TEXT_WHITE)
            text_x = self.exit_button.centerx - text_rect.width // 2
            text_y = self.exit_button.centery - text_rect.height // 2
            screen.blit(text_surf, (text_x, text_y))

    def _draw_building_name(self, screen):
        """건물 이름"""
        font = self.fonts.get('large')
        if font:
            name_surf, name_rect = font.render(self.config["name"], self.config["accent_color"])
            name_x = SCREEN_WIDTH // 2 - name_rect.width // 2
            name_y = 25
            screen.blit(name_surf, (name_x, name_y))

    def handle_click(self, pos):
        """클릭 처리"""
        # 나가기 버튼 클릭
        if self.exit_button.collidepoint(pos):
            return "exit"

        # NPC 클릭 (메인 NPC만)
        for npc in self.npcs:
            if npc.role == "main":
                dist = math.sqrt((pos[0] - npc.x)**2 + (pos[1] - npc.y)**2)
                if dist < npc.size + 10:
                    return ("talk", npc)

        return None
