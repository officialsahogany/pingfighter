#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# downtown/building_interior.py
# 건물 내부 시스템 - 광장 확장 스타일 (플레이어 이동, 문 입출구, NPC 대화)

import pygame
import pygame.freetype
import math
import random
from .constants import (
    SCREEN_WIDTH, SCREEN_HEIGHT, BuildingType, Colors, resource_path,
    TILE_SIZE, PLAYER_SPEED, PLAYER_SIZE
)


# =============================================================================
# 건물 내부 NPC
# =============================================================================
class InteriorNPC:
    """건물 내부 NPC - 클릭으로 대화 가능"""

    NPC_NAMES = {
        "customer": [
            "여행자", "모험가", "상인", "기사", "학자", "마법사 견습생",
            "수집가", "탐험가", "음유시인", "대장장이 도제"
        ],
        "staff": [
            "점원", "보조", "경비원", "관리인", "배달부"
        ]
    }

    CUSTOMER_DIALOGUES = [
        ["음... 뭘 살까?", "이건 너무 비싸군."],
        ["좋은 물건이 있네!", "오늘 운이 좋을 것 같아."],
        ["여기 처음 왔는데...", "물건이 다양하네요."],
        ["혹시 할인 되나요?", "조금만 깎아주세요~"],
        ["이거 인기 많은 건가요?", "추천 좀 해주세요."],
        ["...구경만 할게요.", "아직 결정 못했어요."],
    ]

    STAFF_DIALOGUES = [
        ["어서오세요!", "필요한 게 있으시면 말씀하세요."],
        ["좋은 하루 되세요~", "또 오세요!"],
        ["이쪽으로 오세요.", "도움이 필요하시면 불러주세요."],
    ]

    def __init__(self, x, y, name, role, color, dialogue=None, building_type=None):
        self.x = x
        self.y = y
        self.name = name
        self.role = role  # "customer", "staff", "main"
        self.color = color
        self.dialogue = dialogue or []
        self.building_type = building_type

        # 크기 설정 (메인 NPC는 더 큼)
        if role == "main":
            self.size = 30
        elif role == "staff":
            self.size = 22
        else:
            self.size = 18

        self.animation_offset = random.random() * math.pi * 2

        # 말풍선 상태
        self.is_talking = False
        self.current_dialogue_idx = 0
        self.talk_timer = 0

        # 랜덤 동작
        self.idle_timer = random.random() * 3
        self.idle_action = None  # "look_around", "think", None

    def update(self, dt):
        """NPC 업데이트"""
        # 말풍선 타이머
        if self.is_talking:
            self.talk_timer -= dt
            if self.talk_timer <= 0:
                self.current_dialogue_idx += 1
                if self.current_dialogue_idx >= len(self.dialogue):
                    self.is_talking = False
                    self.current_dialogue_idx = 0
                else:
                    self.talk_timer = 3.0  # 다음 대사 3초

        # 랜덤 아이들 동작
        self.idle_timer -= dt
        if self.idle_timer <= 0:
            self.idle_timer = random.uniform(2, 5)
            self.idle_action = random.choice([None, None, "look_around", "think"])

    def start_dialogue(self):
        """대화 시작"""
        if self.dialogue:
            self.is_talking = True
            self.current_dialogue_idx = 0
            self.talk_timer = 3.0
            return self.dialogue[0]
        return None

    def get_rect(self):
        """NPC 클릭 영역"""
        return pygame.Rect(
            self.x - self.size - 5,
            self.y - self.size - 5,
            (self.size + 5) * 2,
            (self.size + 5) * 2
        )

    def draw(self, screen, camera_offset, animation_timer):
        """NPC 그리기"""
        draw_x = self.x - camera_offset[0]
        draw_y = self.y - camera_offset[1]

        # 간단한 원형 NPC
        bob_offset = int(2 * math.sin(animation_timer * 2 + self.animation_offset))

        # 그림자
        shadow_surf = pygame.Surface((self.size + 10, 8), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 60), (0, 0, self.size + 10, 8))
        screen.blit(shadow_surf, (draw_x - (self.size + 10) // 2, draw_y + self.size // 2))

        # NPC 몸체
        pygame.draw.circle(screen, self.color, (int(draw_x), int(draw_y + bob_offset)), self.size)
        pygame.draw.circle(screen, (255, 255, 255), (int(draw_x), int(draw_y + bob_offset)), self.size, 2)

        # 메인 NPC는 왕관 표시
        if self.role == "main":
            crown_points = [
                (draw_x, draw_y + bob_offset - self.size - 8),
                (draw_x - 10, draw_y + bob_offset - self.size),
                (draw_x - 5, draw_y + bob_offset - self.size - 4),
                (draw_x, draw_y + bob_offset - self.size),
                (draw_x + 5, draw_y + bob_offset - self.size - 4),
                (draw_x + 10, draw_y + bob_offset - self.size),
            ]
            pygame.draw.polygon(screen, (255, 215, 0), crown_points)
            pygame.draw.polygon(screen, (200, 180, 0), crown_points, 2)

        # 아이들 동작 표시
        if self.idle_action == "look_around":
            # 물음표 표시
            pygame.draw.circle(screen, (255, 255, 100),
                             (int(draw_x + self.size), int(draw_y + bob_offset - self.size)), 6)
        elif self.idle_action == "think":
            # 생각 표시 (점 3개)
            for i in range(3):
                pygame.draw.circle(screen, (200, 200, 200),
                                 (int(draw_x + self.size + 5 + i * 8),
                                  int(draw_y + bob_offset - self.size - 5)), 3 - i)

    def draw_speech_bubble(self, screen, camera_offset, fonts):
        """말풍선 그리기"""
        if not self.is_talking or self.current_dialogue_idx >= len(self.dialogue):
            return

        draw_x = self.x - camera_offset[0]
        draw_y = self.y - camera_offset[1]

        current_text = self.dialogue[self.current_dialogue_idx]

        font = fonts.get('small')
        if not font:
            return

        # 텍스트 크기 계산
        text_surf, text_rect = font.render(current_text, Colors.TEXT_WHITE)

        # 말풍선 배경
        bubble_w = text_rect.width + 20
        bubble_h = text_rect.height + 16
        bubble_x = draw_x - bubble_w // 2
        bubble_y = draw_y - self.size - bubble_h - 15

        # 말풍선 그리기
        bubble_rect = pygame.Rect(bubble_x, bubble_y, bubble_w, bubble_h)
        pygame.draw.rect(screen, (40, 40, 50), bubble_rect, border_radius=8)
        pygame.draw.rect(screen, self.color, bubble_rect, 2, border_radius=8)

        # 말풍선 꼬리
        tail_points = [
            (draw_x - 8, bubble_y + bubble_h),
            (draw_x + 8, bubble_y + bubble_h),
            (draw_x, bubble_y + bubble_h + 10)
        ]
        pygame.draw.polygon(screen, (40, 40, 50), tail_points)
        pygame.draw.line(screen, self.color, tail_points[0], tail_points[2], 2)
        pygame.draw.line(screen, self.color, tail_points[1], tail_points[2], 2)

        # 텍스트
        screen.blit(text_surf, (bubble_x + 10, bubble_y + 8))

        # 이름 (작게)
        name_surf, name_rect = font.render(self.name, self.color)
        name_x = bubble_x + bubble_w - name_rect.width - 5
        name_y = bubble_y - name_rect.height - 2

        # 이름 배경
        name_bg = pygame.Rect(name_x - 3, name_y - 2, name_rect.width + 6, name_rect.height + 4)
        pygame.draw.rect(screen, (30, 30, 40), name_bg, border_radius=3)
        screen.blit(name_surf, (name_x, name_y))


# =============================================================================
# 건물 내부 인테리어 플레이어 (광장 플레이어와 유사)
# =============================================================================
class InteriorPlayer:
    """건물 내부에서 이동하는 플레이어"""

    def __init__(self, x, y, sprite=None):
        self.x = float(x)
        self.y = float(y)
        self.width = 40  # 내부용 크기 (작게)
        self.height = 50
        self.speed = PLAYER_SPEED * 0.8  # 내부는 조금 느리게

        self.velocity_x = 0
        self.velocity_y = 0
        self.is_moving = False

        # 방향 (0: 하, 1: 좌, 2: 우, 3: 상)
        self.direction = 0

        # 애니메이션
        self.animation_frame = 0
        self.animation_timer = 0

        # 스프라이트 (광장에서 사용하던 것 공유)
        self.sprite = sprite
        self.sprite_flipped = None
        if self.sprite:
            # 스프라이트를 내부용 크기로 스케일
            scale_factor = 0.3
            new_w = int(self.sprite.get_width() * scale_factor)
            new_h = int(self.sprite.get_height() * scale_factor)
            self.sprite = pygame.transform.smoothscale(self.sprite, (new_w, new_h))
            self.sprite_flipped = pygame.transform.flip(self.sprite, True, False)
            self.width = new_w
            self.height = new_h

        # 키 입력 상태
        self.pressed_keys = set()

    def handle_input(self, keys, dt):
        """입력 처리"""
        self.velocity_x = 0
        self.velocity_y = 0

        # WASD 및 화살표 키
        is_left = keys[pygame.K_LEFT] or keys[pygame.K_a] or pygame.K_a in self.pressed_keys
        is_right = keys[pygame.K_RIGHT] or keys[pygame.K_d] or pygame.K_d in self.pressed_keys
        is_up = keys[pygame.K_UP] or keys[pygame.K_w] or pygame.K_w in self.pressed_keys
        is_down = keys[pygame.K_DOWN] or keys[pygame.K_s] or pygame.K_s in self.pressed_keys

        if is_left:
            self.velocity_x = -self.speed
            self.direction = 1
        elif is_right:
            self.velocity_x = self.speed
            self.direction = 2

        if is_up:
            self.velocity_y = -self.speed
            self.direction = 3
        elif is_down:
            self.velocity_y = self.speed
            self.direction = 0

        # 대각선 정규화
        if self.velocity_x != 0 and self.velocity_y != 0:
            factor = 0.707
            self.velocity_x *= factor
            self.velocity_y *= factor

        self.is_moving = (self.velocity_x != 0 or self.velocity_y != 0)

    def update(self, dt, interior):
        """위치 업데이트"""
        if self.is_moving:
            new_x = self.x + self.velocity_x * dt * 60
            new_y = self.y + self.velocity_y * dt * 60

            # 충돌 체크
            if interior.can_move_to(new_x, self.y):
                self.x = new_x
            if interior.can_move_to(self.x, new_y):
                self.y = new_y

        # 애니메이션
        if self.is_moving:
            self.animation_timer += dt
            if self.animation_timer >= 0.15:
                self.animation_timer = 0
                self.animation_frame = (self.animation_frame + 1) % 4
        else:
            self.animation_frame = 0

    def draw(self, screen, camera_offset):
        """플레이어 그리기"""
        draw_x = self.x - camera_offset[0]
        draw_y = self.y - camera_offset[1]

        # 그림자
        shadow_w = int(self.width * 0.5)
        shadow_h = int(shadow_w * 0.3)
        shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 50), (0, 0, shadow_w, shadow_h))
        screen.blit(shadow_surf, (draw_x - shadow_w // 2, draw_y + self.height // 3))

        # 바운스 효과
        offset_y = 0
        if self.is_moving:
            bounce = math.sin(self.animation_frame * math.pi / 2) * 2
            offset_y = -abs(bounce)

        # 스프라이트 그리기
        if self.sprite:
            if self.direction == 1:
                current = self.sprite_flipped
            else:
                current = self.sprite
            sprite_x = draw_x - self.width // 2
            sprite_y = draw_y - self.height // 2 + offset_y
            screen.blit(current, (sprite_x, sprite_y))
        else:
            # 폴백 도형
            pygame.draw.ellipse(screen, Colors.NEON_CYAN,
                              (draw_x - self.width // 3, draw_y - self.height // 3 + offset_y,
                               self.width * 2 // 3, self.height // 2))
            pygame.draw.ellipse(screen, (255, 220, 180),
                              (draw_x - self.width // 4, draw_y - self.height // 2 + offset_y,
                               self.width // 2, self.height // 3))


# =============================================================================
# 건물 내부 맵 설정
# =============================================================================
INTERIOR_CONFIGS = {
    BuildingType.MAGIC_STORE: {
        "name": "마법 상점",
        "map_size": (12, 10),  # 타일 개수 (가로 x 세로)
        "bg_color": (30, 20, 50),
        "floor_color": (50, 35, 70),
        "floor_pattern": "mystic_circle",  # 바닥 패턴
        "wall_color": (40, 25, 60),
        "accent_color": (138, 43, 226),
        "secondary_color": (255, 0, 255),
        "decorations": ["crystal_stand", "potion_shelf", "magic_orb", "bookshelf"],
        "main_npc": {
            "name": "마법사 메를린",
            "color": (138, 43, 226),
            "position": (0.5, 0.3),  # 비율로 위치 지정 (맵 중앙 위쪽)
            "dialogue": [
                "환영하오, 여행자여!",
                "이곳은 신비로운 마법의 상점이오.",
                "마법 아이템이 필요하신가?",
                "아직 준비중이라네..."
            ]
        },
        "customer_range": (2, 4),  # 랜덤 고객 수 범위
        "staff_count": 1,
    },
    BuildingType.ITEM_SHOP: {
        "name": "네온 마켓",
        "map_size": (14, 12),
        "bg_color": (20, 20, 35),
        "floor_color": (40, 40, 55),
        "floor_pattern": "neon_grid",
        "wall_color": (30, 30, 45),
        "accent_color": (0, 255, 255),
        "secondary_color": (255, 20, 147),
        "decorations": ["neon_sign", "display_case", "hologram", "led_shelf"],
        "main_npc": {
            "name": "점주 사이버",
            "color": (0, 255, 255),
            "position": (0.5, 0.25),
            "dialogue": [
                "어서오세요, 고객님!",
                "최신 아이템이 입고되었습니다.",
                "뭘 찾으시나요?",
                "천천히 구경하세요~"
            ]
        },
        "customer_range": (3, 5),
        "staff_count": 2,
    },
    BuildingType.BLACKSMITH: {
        "name": "대장간",
        "map_size": (10, 10),
        "bg_color": (50, 30, 20),
        "floor_color": (70, 45, 30),
        "floor_pattern": "stone_brick",
        "wall_color": (60, 35, 25),
        "accent_color": (255, 140, 0),
        "secondary_color": (255, 69, 0),
        "decorations": ["anvil", "forge", "weapon_rack", "tool_wall"],
        "main_npc": {
            "name": "대장장이 헤파이토스",
            "color": (255, 140, 0),
            "position": (0.5, 0.35),
            "dialogue": [
                "무기를 강화하러 왔나?",
                "내 솜씨는 최고지!",
                "뭘 만들어줄까?",
                "...준비 중이야."
            ]
        },
        "customer_range": (1, 3),
        "staff_count": 1,
    },
    BuildingType.CASINO: {
        "name": "네온 카지노",
        "map_size": (16, 14),
        "bg_color": (40, 15, 25),
        "floor_color": (60, 25, 35),
        "floor_pattern": "carpet_luxury",
        "wall_color": (50, 20, 30),
        "accent_color": (255, 20, 147),
        "secondary_color": (255, 215, 0),
        "decorations": ["slot_machine", "card_table", "roulette", "chandelier"],
        "main_npc": {
            "name": "딜러 포춘",
            "color": (255, 20, 147),
            "position": (0.5, 0.3),
            "dialogue": [
                "행운을 시험해보시겠습니까?",
                "이 테이블은 항상 열려있습니다.",
                "승부를 걸어보세요!",
                "아직 오픈 준비 중..."
            ]
        },
        "customer_range": (4, 6),
        "staff_count": 3,
    },
    BuildingType.TAVERN: {
        "name": "모험가의 선술집",
        "map_size": (14, 11),
        "bg_color": (45, 35, 25),
        "floor_color": (70, 55, 40),
        "floor_pattern": "wood_plank",
        "wall_color": (55, 42, 30),
        "accent_color": (210, 180, 140),
        "secondary_color": (160, 82, 45),
        "decorations": ["barrel", "bar_counter", "table_chair", "fireplace"],
        "main_npc": {
            "name": "주인 바커스",
            "color": (210, 180, 140),
            "position": (0.5, 0.25),
            "dialogue": [
                "어서오게! 뭘 마시겠나?",
                "여기선 최고의 술을 팔지.",
                "피곤한 하루였나보군.",
                "천천히 쉬어가게나."
            ]
        },
        "customer_range": (4, 7),
        "staff_count": 1,
    },
    BuildingType.BANK: {
        "name": "스타뱅크",
        "map_size": (12, 10),
        "bg_color": (25, 30, 45),
        "floor_color": (45, 50, 70),
        "floor_pattern": "marble",
        "wall_color": (35, 40, 55),
        "accent_color": (255, 215, 0),
        "secondary_color": (192, 192, 192),
        "decorations": ["vault_door", "counter", "safe_box", "gold_display"],
        "main_npc": {
            "name": "은행장 골드맨",
            "color": (255, 215, 0),
            "position": (0.5, 0.3),
            "dialogue": [
                "스타뱅크에 오신 것을 환영합니다.",
                "어떤 업무를 도와드릴까요?",
                "현재 시스템 점검 중입니다.",
                "곧 서비스를 이용하실 수 있습니다."
            ]
        },
        "customer_range": (2, 4),
        "staff_count": 2,
    },
    BuildingType.GACHA: {
        "name": "스타 가챠샵",
        "map_size": (10, 10),
        "bg_color": (35, 25, 50),
        "floor_color": (55, 40, 75),
        "floor_pattern": "star_pattern",
        "wall_color": (45, 35, 60),
        "accent_color": (255, 215, 0),
        "secondary_color": (255, 100, 255),
        "decorations": ["gacha_machine", "prize_display", "star_lamp", "banner"],
        "main_npc": {
            "name": "가챠 마스터",
            "color": (255, 200, 100),
            "position": (0.5, 0.35),
            "dialogue": [
                "스타 가챠샵에 오신 것을 환영해요!",
                "오늘의 운세는 어떨까요?",
                "희귀 아이템이 기다리고 있어요!",
                "준비 중... 조금만 기다려주세요!"
            ]
        },
        "customer_range": (2, 5),
        "staff_count": 1,
    },
    BuildingType.ACADEMY: {
        "name": "마법 학원",
        "map_size": (16, 12),
        "bg_color": (30, 25, 55),
        "floor_color": (50, 45, 80),
        "floor_pattern": "academy_tile",
        "wall_color": (40, 35, 65),
        "accent_color": (150, 100, 255),
        "secondary_color": (100, 200, 255),
        "decorations": ["bookshelf_large", "study_desk", "globe", "potion_lab"],
        "main_npc": {
            "name": "학장 아르카나",
            "color": (150, 100, 255),
            "position": (0.5, 0.25),
            "dialogue": [
                "마법 학원에 오신 것을 환영합니다.",
                "새로운 스킬을 배우고 싶으신가요?",
                "현재 강의 준비 중입니다.",
                "곧 수업이 시작될 거예요."
            ]
        },
        "customer_range": (3, 6),
        "staff_count": 2,
    },
    BuildingType.MYSTERY: {
        "name": "???",
        "map_size": (8, 8),
        "bg_color": (15, 10, 30),
        "floor_color": (25, 15, 50),
        "floor_pattern": "void_ripple",
        "wall_color": (20, 12, 40),
        "accent_color": (150, 50, 255),
        "secondary_color": (100, 0, 200),
        "decorations": ["portal", "crystal_cluster", "floating_orb", "void_crack"],
        "main_npc": {
            "name": "???",
            "color": (150, 50, 255),
            "position": (0.5, 0.4),
            "dialogue": [
                "... ... ...",
                "이곳은... 아직... 준비가...",
                "다시... 오세요...",
            ]
        },
        "customer_range": (0, 2),
        "staff_count": 0,
    },
    BuildingType.COLOSSEUM: {
        "name": "고대 투기장",
        "map_size": (18, 14),
        "bg_color": (40, 35, 30),
        "floor_color": (120, 100, 80),
        "floor_pattern": "arena_sand",
        "wall_color": (90, 80, 70),
        "accent_color": (200, 170, 140),
        "secondary_color": (180, 50, 50),
        "decorations": ["pillar", "statue", "torch", "weapon_stand"],
        "main_npc": {
            "name": "투기장 관리인",
            "color": (200, 170, 140),
            "position": (0.5, 0.25),
            "dialogue": [
                "고대 투기장에 오신 것을 환영하오.",
                "이곳에서 전사들이 싸우게 되지.",
                "아직 대회 준비 중이라오.",
                "곧 투기가 시작될 거요."
            ]
        },
        "customer_range": (2, 4),
        "staff_count": 2,
    },
    BuildingType.PET_SHOP: {
        "name": "숲의 펫샵",
        "map_size": (12, 10),
        "bg_color": (30, 45, 30),
        "floor_color": (60, 90, 55),
        "floor_pattern": "grass_indoor",
        "wall_color": (50, 75, 45),
        "accent_color": (100, 200, 100),
        "secondary_color": (200, 180, 140),
        "decorations": ["pet_cage", "feeding_bowl", "tree_pot", "hay_stack"],
        "main_npc": {
            "name": "펫 마스터 루나",
            "color": (100, 200, 100),
            "position": (0.5, 0.3),
            "dialogue": [
                "어머, 귀여운 손님이시네요!",
                "동물 친구를 찾으시나요?",
                "아직 펫들이 준비 중이에요~",
                "조금만 기다려주세요!"
            ]
        },
        "customer_range": (2, 4),
        "staff_count": 1,
    },
    BuildingType.ELDER: {
        "name": "피라미드 현자",
        "map_size": (10, 10),
        "bg_color": (50, 40, 25),
        "floor_color": (120, 100, 70),
        "floor_pattern": "hieroglyph",
        "wall_color": (100, 85, 55),
        "accent_color": (255, 215, 0),
        "secondary_color": (200, 160, 100),
        "decorations": ["sarcophagus", "hieroglyph_wall", "torch_ancient", "treasure"],
        "main_npc": {
            "name": "현자 오시리스",
            "color": (255, 215, 0),
            "position": (0.5, 0.35),
            "dialogue": [
                "고대의 지혜를 찾아왔군...",
                "나는 수천 년을 살아온 자...",
                "아직 그대에게 전할 지혜가...",
                "준비되지 않았노라..."
            ]
        },
        "customer_range": (0, 2),
        "staff_count": 0,
    },
    BuildingType.MINIGAME: {
        "name": "레트로 아케이드",
        "map_size": (14, 12),
        "bg_color": (20, 25, 35),
        "floor_color": (40, 45, 60),
        "floor_pattern": "arcade_carpet",
        "wall_color": (30, 35, 50),
        "accent_color": (57, 255, 20),
        "secondary_color": (255, 100, 255),
        "decorations": ["arcade_cabinet", "prize_claw", "pinball", "neon_tube"],
        "main_npc": {
            "name": "아케이드 마스터",
            "color": (57, 255, 20),
            "position": (0.5, 0.3),
            "dialogue": [
                "레트로 아케이드에 온 걸 환영해!",
                "추억의 게임을 즐겨봐!",
                "아직 기계 점검 중이야~",
                "곧 플레이할 수 있을 거야!"
            ]
        },
        "customer_range": (3, 6),
        "staff_count": 1,
    },
}

# 기본 설정 (정의되지 않은 건물용)
DEFAULT_INTERIOR_CONFIG = {
    "name": "건물",
    "map_size": (10, 8),
    "bg_color": (40, 40, 50),
    "floor_color": (60, 60, 75),
    "floor_pattern": "plain",
    "wall_color": (50, 50, 65),
    "accent_color": (150, 150, 180),
    "secondary_color": (120, 120, 150),
    "decorations": [],
    "main_npc": {
        "name": "관리인",
        "color": (150, 150, 180),
        "position": (0.5, 0.4),
        "dialogue": ["안녕하세요.", "아직 준비 중입니다."]
    },
    "customer_range": (1, 3),
    "staff_count": 1,
}


# =============================================================================
# 건물 내부 메인 클래스
# =============================================================================
class BuildingInterior:
    """건물 내부 - 광장 확장 스타일"""

    TILE_SIZE = 32  # 내부 타일 크기

    def __init__(self, building_type, freetype_fonts, player_sprite=None):
        self.building_type = building_type
        self.fonts = freetype_fonts
        self.animation_timer = 0

        # 건물별 설정
        self.config = INTERIOR_CONFIGS.get(building_type, DEFAULT_INTERIOR_CONFIG)

        # 맵 크기
        self.map_width, self.map_height = self.config["map_size"]
        self.pixel_width = self.map_width * self.TILE_SIZE
        self.pixel_height = self.map_height * self.TILE_SIZE

        # 문 위치 (맵 하단 중앙)
        self.door_rect = pygame.Rect(
            (self.pixel_width - 64) // 2,
            self.pixel_height - 48,
            64, 48
        )

        # 내부 영역 (벽 제외한 이동 가능 구역)
        self.walkable_rect = pygame.Rect(
            self.TILE_SIZE,  # 왼쪽 벽
            self.TILE_SIZE * 2,  # 위쪽 벽 (이름/카운터 공간)
            self.pixel_width - self.TILE_SIZE * 2,  # 양쪽 벽 제외
            self.pixel_height - self.TILE_SIZE * 3  # 위아래 벽 제외
        )

        # 플레이어 (문 앞에서 시작)
        spawn_x = self.pixel_width // 2
        spawn_y = self.pixel_height - self.TILE_SIZE * 2
        self.player = InteriorPlayer(spawn_x, spawn_y, player_sprite)

        # 카메라 오프셋 (화면 중앙 정렬)
        self.camera_offset = (0, 0)
        self._update_camera()

        # NPC들 생성
        self.npcs = self._create_npcs()

        # 장식물 생성
        self.decorations = self._create_decorations()

        # 나가기 상태
        self.exit_requested = False
        self.exit_timer = 0

    def _create_npcs(self):
        """NPC들 생성"""
        npcs = []

        # 메인 NPC
        main_cfg = self.config["main_npc"]
        main_x = int(self.pixel_width * main_cfg["position"][0])
        main_y = int(self.pixel_height * main_cfg["position"][1])

        main_npc = InteriorNPC(
            main_x, main_y,
            main_cfg["name"],
            "main",
            main_cfg["color"],
            main_cfg["dialogue"],
            self.building_type
        )
        npcs.append(main_npc)

        # 랜덤 고객 NPC
        customer_min, customer_max = self.config.get("customer_range", (2, 4))
        customer_count = random.randint(customer_min, customer_max)

        customer_colors = [
            (100, 150, 200), (200, 150, 100), (150, 200, 100),
            (200, 100, 150), (150, 100, 200), (100, 200, 150),
            (180, 180, 100), (100, 180, 180)
        ]

        for i in range(customer_count):
            # 랜덤 위치 (walkable 영역 내)
            x = random.randint(
                self.walkable_rect.left + 30,
                self.walkable_rect.right - 30
            )
            y = random.randint(
                self.walkable_rect.top + 30,
                self.walkable_rect.bottom - 50
            )

            # 메인 NPC와 너무 가까우면 재배치
            while abs(x - main_x) < 60 and abs(y - main_y) < 60:
                x = random.randint(self.walkable_rect.left + 30, self.walkable_rect.right - 30)
                y = random.randint(self.walkable_rect.top + 30, self.walkable_rect.bottom - 50)

            # 랜덤 이름과 대화
            name = random.choice(InteriorNPC.NPC_NAMES["customer"])
            dialogue = random.choice(InteriorNPC.CUSTOMER_DIALOGUES)

            customer = InteriorNPC(
                x, y, name, "customer",
                customer_colors[i % len(customer_colors)],
                dialogue, self.building_type
            )
            npcs.append(customer)

        # 직원 NPC
        staff_count = self.config.get("staff_count", 1)
        staff_color = tuple(int(c * 0.7) for c in self.config["accent_color"])

        for i in range(staff_count):
            # 카운터 근처에 배치
            x = self.walkable_rect.left + 50 + i * 100
            y = self.walkable_rect.top + 50

            name = random.choice(InteriorNPC.NPC_NAMES["staff"])
            dialogue = random.choice(InteriorNPC.STAFF_DIALOGUES)

            staff = InteriorNPC(
                x, y, name, "staff",
                staff_color, dialogue, self.building_type
            )
            npcs.append(staff)

        return npcs

    def _create_decorations(self):
        """장식물 생성"""
        decorations = []
        deco_types = self.config.get("decorations", [])

        # 장식물 위치 미리 계산
        for i, deco_type in enumerate(deco_types):
            if i >= 4:  # 최대 4개
                break

            # 4분면에 배치
            if i == 0:  # 좌상
                x = self.walkable_rect.left + 20
                y = self.walkable_rect.top + 20
            elif i == 1:  # 우상
                x = self.walkable_rect.right - 40
                y = self.walkable_rect.top + 20
            elif i == 2:  # 좌하
                x = self.walkable_rect.left + 20
                y = self.walkable_rect.bottom - 60
            else:  # 우하
                x = self.walkable_rect.right - 40
                y = self.walkable_rect.bottom - 60

            decorations.append({
                "type": deco_type,
                "x": x,
                "y": y,
                "size": (40, 40)
            })

        return decorations

    def can_move_to(self, x, y):
        """이동 가능 여부 체크"""
        # 플레이어 충돌 박스
        half_w = self.player.width // 3
        half_h = self.player.height // 3

        player_rect = pygame.Rect(
            x - half_w, y - half_h,
            half_w * 2, half_h * 2
        )

        # 이동 가능 영역 체크
        if not self.walkable_rect.contains(player_rect):
            # 문 영역 예외 (나갈 수 있음)
            if self.door_rect.colliderect(player_rect):
                return True
            return False

        # NPC와 충돌 체크
        for npc in self.npcs:
            npc_rect = pygame.Rect(
                npc.x - npc.size, npc.y - npc.size,
                npc.size * 2, npc.size * 2
            )
            if player_rect.colliderect(npc_rect):
                return False

        # 장식물과 충돌 체크
        for deco in self.decorations:
            deco_rect = pygame.Rect(deco["x"], deco["y"], *deco["size"])
            if player_rect.colliderect(deco_rect):
                return False

        return True

    def _update_camera(self):
        """카메라 업데이트 (화면 중앙에 맵 배치)"""
        # 화면 크기와 맵 크기 차이
        offset_x = (SCREEN_WIDTH - self.pixel_width) // 2
        offset_y = (SCREEN_HEIGHT - self.pixel_height) // 2

        # 음수면 맵이 화면보다 큼 -> 플레이어 따라가기
        if offset_x < 0 or offset_y < 0:
            # 플레이어 중심으로 카메라 이동
            cam_x = self.player.x - SCREEN_WIDTH // 2
            cam_y = self.player.y - SCREEN_HEIGHT // 2

            # 카메라 범위 제한
            cam_x = max(0, min(cam_x, self.pixel_width - SCREEN_WIDTH))
            cam_y = max(0, min(cam_y, self.pixel_height - SCREEN_HEIGHT))

            self.camera_offset = (cam_x, cam_y)
        else:
            # 맵이 화면보다 작으면 중앙 정렬
            self.camera_offset = (-offset_x, -offset_y)

    def update(self, dt):
        """업데이트"""
        self.animation_timer += dt

        # 플레이어 업데이트
        keys = pygame.key.get_pressed()
        self.player.handle_input(keys, dt)
        self.player.update(dt, self)

        # 카메라 업데이트
        self._update_camera()

        # NPC 업데이트
        for npc in self.npcs:
            npc.update(dt)

        # 문 근처에서 나가기 체크
        player_rect = pygame.Rect(
            self.player.x - 20, self.player.y - 20, 40, 40
        )
        if self.door_rect.colliderect(player_rect):
            # 문 근처 + 아래쪽 방향
            if self.player.direction == 0:  # 아래쪽
                self.exit_timer += dt
                if self.exit_timer >= 0.5:  # 0.5초 후 나가기
                    self.exit_requested = True
            else:
                self.exit_timer = 0
        else:
            self.exit_timer = 0

    def handle_click(self, pos):
        """클릭 처리"""
        # 화면 좌표를 월드 좌표로 변환
        world_x = pos[0] + self.camera_offset[0]
        world_y = pos[1] + self.camera_offset[1]

        # NPC 클릭 체크
        for npc in self.npcs:
            npc_rect = npc.get_rect()
            if npc_rect.collidepoint(world_x, world_y):
                dialogue = npc.start_dialogue()
                if dialogue:
                    return ("talk", npc)

        return None

    def draw(self, screen):
        """건물 내부 그리기"""
        # 배경
        screen.fill(self.config["bg_color"])

        # 바닥 타일
        self._draw_floor(screen)

        # 벽
        self._draw_walls(screen)

        # 장식물
        self._draw_decorations(screen)

        # 문
        self._draw_door(screen)

        # NPC들 (Y 정렬)
        all_entities = [(npc.y, "npc", npc) for npc in self.npcs]
        all_entities.append((self.player.y, "player", self.player))
        all_entities.sort(key=lambda e: e[0])

        for _, entity_type, entity in all_entities:
            if entity_type == "npc":
                entity.draw(screen, self.camera_offset, self.animation_timer)
            else:
                entity.draw(screen, self.camera_offset)

        # NPC 말풍선 (맨 위에)
        for npc in self.npcs:
            npc.draw_speech_bubble(screen, self.camera_offset, self.fonts)

        # 건물 이름
        self._draw_building_name(screen)

        # 나가기 힌트
        self._draw_exit_hint(screen)

        # UI
        self._draw_ui(screen)

    def _draw_floor(self, screen):
        """바닥 타일 그리기"""
        floor_color = self.config["floor_color"]
        pattern = self.config.get("floor_pattern", "plain")

        # 화면에 보이는 타일만 그리기
        start_x = max(0, int(self.camera_offset[0] // self.TILE_SIZE))
        start_y = max(0, int(self.camera_offset[1] // self.TILE_SIZE))
        end_x = min(self.map_width, start_x + SCREEN_WIDTH // self.TILE_SIZE + 2)
        end_y = min(self.map_height, start_y + SCREEN_HEIGHT // self.TILE_SIZE + 2)

        for ty in range(start_y, end_y):
            for tx in range(start_x, end_x):
                tile_x = tx * self.TILE_SIZE - self.camera_offset[0]
                tile_y = ty * self.TILE_SIZE - self.camera_offset[1]

                # 패턴별 색상 변화
                if pattern == "mystic_circle":
                    # 마법진 패턴
                    dist = abs(tx - self.map_width // 2) + abs(ty - self.map_height // 2)
                    if dist % 3 == 0:
                        color = tuple(min(255, c + 15) for c in floor_color)
                    else:
                        color = floor_color
                elif pattern == "neon_grid":
                    # 네온 그리드
                    if tx % 4 == 0 or ty % 4 == 0:
                        color = tuple(min(255, c + 20) for c in floor_color)
                    else:
                        color = floor_color
                elif pattern == "wood_plank":
                    # 나무 판자
                    if tx % 2 == 0:
                        color = tuple(max(0, c - 10) for c in floor_color)
                    else:
                        color = floor_color
                elif pattern == "marble":
                    # 대리석
                    if (tx + ty) % 2 == 0:
                        color = tuple(min(255, c + 15) for c in floor_color)
                    else:
                        color = floor_color
                elif pattern == "stone_brick":
                    # 돌 벽돌
                    if (tx + ty) % 3 == 0:
                        color = tuple(max(0, c - 15) for c in floor_color)
                    else:
                        color = floor_color
                else:
                    # 체크 패턴 (기본)
                    if (tx + ty) % 2 == 0:
                        color = floor_color
                    else:
                        color = tuple(max(0, c - 8) for c in floor_color)

                pygame.draw.rect(screen, color,
                               (tile_x, tile_y, self.TILE_SIZE, self.TILE_SIZE))
                pygame.draw.rect(screen, tuple(max(0, c - 15) for c in floor_color),
                               (tile_x, tile_y, self.TILE_SIZE, self.TILE_SIZE), 1)

    def _draw_walls(self, screen):
        """벽 그리기"""
        wall_color = self.config["wall_color"]
        accent = self.config["accent_color"]

        # 상단 벽 (카운터/이름 영역)
        wall_h = self.TILE_SIZE * 2
        wall_y = -self.camera_offset[1]

        wall_rect = pygame.Rect(
            -self.camera_offset[0], wall_y,
            self.pixel_width, wall_h
        )
        pygame.draw.rect(screen, wall_color, wall_rect)

        # 벽 장식 라인
        for i in range(3):
            line_y = wall_y + wall_h - 5 - i * 8
            alpha = 180 - i * 40
            line_surf = pygame.Surface((self.pixel_width, 2), pygame.SRCALPHA)
            line_surf.fill((*accent, alpha))
            screen.blit(line_surf, (-self.camera_offset[0], line_y))

        # 좌우 벽
        side_wall_w = self.TILE_SIZE

        # 왼쪽 벽
        left_wall = pygame.Rect(
            -self.camera_offset[0], -self.camera_offset[1],
            side_wall_w, self.pixel_height
        )
        pygame.draw.rect(screen, wall_color, left_wall)

        # 오른쪽 벽
        right_wall = pygame.Rect(
            self.pixel_width - side_wall_w - self.camera_offset[0], -self.camera_offset[1],
            side_wall_w, self.pixel_height
        )
        pygame.draw.rect(screen, wall_color, right_wall)

    def _draw_decorations(self, screen):
        """장식물 그리기 (간단한 도형으로)"""
        accent = self.config["accent_color"]
        secondary = self.config["secondary_color"]

        for deco in self.decorations:
            x = deco["x"] - self.camera_offset[0]
            y = deco["y"] - self.camera_offset[1]
            w, h = deco["size"]

            deco_type = deco["type"]

            # 장식물 타입별 그리기
            if "shelf" in deco_type or "rack" in deco_type:
                # 선반/랙
                pygame.draw.rect(screen, secondary, (x, y, w, h))
                pygame.draw.rect(screen, accent, (x, y, w, h), 2)
                # 선반 칸
                for i in range(3):
                    pygame.draw.line(screen, accent, (x, y + h // 3 * i), (x + w, y + h // 3 * i), 2)
            elif "machine" in deco_type or "cabinet" in deco_type:
                # 기계/캐비닛
                pygame.draw.rect(screen, (60, 60, 70), (x, y, w, h), border_radius=5)
                pygame.draw.rect(screen, accent, (x, y, w, h), 2, border_radius=5)
                # 화면/버튼
                pygame.draw.rect(screen, (30, 30, 40), (x + 5, y + 5, w - 10, h // 2), border_radius=3)
                pygame.draw.circle(screen, accent, (x + w // 2, y + h - 10), 5)
            elif "table" in deco_type or "counter" in deco_type or "desk" in deco_type:
                # 테이블/카운터
                pygame.draw.rect(screen, secondary, (x, y + h // 3, w, h * 2 // 3))
                pygame.draw.rect(screen, tuple(c - 20 for c in secondary), (x, y + h // 3, w, h * 2 // 3), 2)
            elif "torch" in deco_type or "lamp" in deco_type:
                # 횃불/램프 (빛 효과)
                glow_alpha = int(100 + 50 * math.sin(self.animation_timer * 3))
                glow_surf = pygame.Surface((w * 2, h * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*accent, glow_alpha), (w, h), w)
                screen.blit(glow_surf, (x - w // 2, y - h // 2))
                pygame.draw.rect(screen, secondary, (x + w // 3, y, w // 3, h))
            elif "portal" in deco_type or "orb" in deco_type:
                # 포탈/오브 (회전 효과)
                angle = self.animation_timer * 2
                for i in range(3):
                    offset_x = int(8 * math.cos(angle + i * 2))
                    offset_y = int(8 * math.sin(angle + i * 2))
                    alpha = 150 - i * 30
                    pygame.draw.circle(screen, (*accent, alpha),
                                      (x + w // 2 + offset_x, y + h // 2 + offset_y),
                                      w // 3 - i * 2)
            else:
                # 기본 박스
                pygame.draw.rect(screen, secondary, (x, y, w, h), border_radius=3)
                pygame.draw.rect(screen, accent, (x, y, w, h), 2, border_radius=3)

    def _draw_door(self, screen):
        """문 그리기"""
        door_x = self.door_rect.x - self.camera_offset[0]
        door_y = self.door_rect.y - self.camera_offset[1]
        door_w = self.door_rect.width
        door_h = self.door_rect.height

        # 문 배경
        pygame.draw.rect(screen, (40, 35, 30), (door_x, door_y, door_w, door_h))

        # 문틀
        pygame.draw.rect(screen, (80, 60, 40), (door_x, door_y, door_w, door_h), 4)

        # 문 손잡이
        pygame.draw.circle(screen, (200, 180, 100), (door_x + door_w - 15, door_y + door_h // 2), 5)

        # 나가기 표시 (화살표)
        arrow_x = door_x + door_w // 2
        arrow_y = door_y + 15
        arrow_points = [
            (arrow_x, arrow_y),
            (arrow_x - 10, arrow_y + 15),
            (arrow_x + 10, arrow_y + 15)
        ]
        pygame.draw.polygon(screen, Colors.NEON_ORANGE, arrow_points)

        # "EXIT" 텍스트
        font_small = self.fonts.get('small')
        if font_small:
            exit_surf, exit_rect = font_small.render("EXIT", Colors.NEON_ORANGE)
            screen.blit(exit_surf, (door_x + (door_w - exit_rect.width) // 2, door_y + door_h - 18))

    def _draw_building_name(self, screen):
        """건물 이름 표시"""
        font_large = self.fonts.get('large')
        if not font_large:
            return

        name = self.config["name"]
        accent = self.config["accent_color"]

        name_surf, name_rect = font_large.render(name, accent)
        name_x = SCREEN_WIDTH // 2 - name_rect.width // 2
        name_y = 15

        # 배경
        bg_rect = pygame.Rect(name_x - 15, name_y - 5, name_rect.width + 30, name_rect.height + 10)
        bg_surf = pygame.Surface(bg_rect.size, pygame.SRCALPHA)
        bg_surf.fill((0, 0, 0, 150))
        screen.blit(bg_surf, bg_rect.topleft)
        pygame.draw.rect(screen, accent, bg_rect, 2, border_radius=5)

        screen.blit(name_surf, (name_x, name_y))

    def _draw_exit_hint(self, screen):
        """나가기 힌트 표시"""
        # 문 근처일 때
        player_rect = pygame.Rect(
            self.player.x - 30, self.player.y - 30, 60, 60
        )

        if self.door_rect.colliderect(player_rect):
            font_small = self.fonts.get('small')
            if font_small:
                hint = "↓ 아래로 이동해서 나가기"
                hint_surf, hint_rect = font_small.render(hint, Colors.NEON_ORANGE)
                hint_x = SCREEN_WIDTH // 2 - hint_rect.width // 2
                hint_y = SCREEN_HEIGHT - 50

                # 깜빡임
                alpha = int(180 + 75 * math.sin(self.animation_timer * 4))
                hint_surf.set_alpha(alpha)
                screen.blit(hint_surf, (hint_x, hint_y))

                # 진행 바 (나가기까지)
                if self.exit_timer > 0:
                    progress = min(1.0, self.exit_timer / 0.5)
                    bar_w = 100
                    bar_h = 8
                    bar_x = SCREEN_WIDTH // 2 - bar_w // 2
                    bar_y = hint_y + 25

                    pygame.draw.rect(screen, (50, 50, 60), (bar_x, bar_y, bar_w, bar_h), border_radius=4)
                    pygame.draw.rect(screen, Colors.NEON_ORANGE,
                                   (bar_x, bar_y, int(bar_w * progress), bar_h), border_radius=4)

    def _draw_ui(self, screen):
        """UI 그리기"""
        font_small = self.fonts.get('small')
        if not font_small:
            return

        # 조작 안내
        hints = [
            "WASD/방향키: 이동",
            "마우스 클릭: NPC 대화",
            "문으로 나가기"
        ]

        hint_y = SCREEN_HEIGHT - 20 - len(hints) * 18
        for hint in hints:
            hint_surf, hint_rect = font_small.render(hint, (150, 150, 160))
            screen.blit(hint_surf, (15, hint_y))
            hint_y += 18
