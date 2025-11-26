# downtown/npc.py
# 번화가 NPC 시스템 - 주민, 로봇, 강아지, 고양이 등

import pygame
import pygame.freetype
import math
import random
import os
from .constants import (
    TILE_SIZE, SCREEN_WIDTH, SCREEN_HEIGHT,
    MAP_WIDTH, MAP_HEIGHT, Colors, TileType,
    resource_path
)


class NPCType:
    """NPC 타입 정의"""
    CITIZEN_MALE = "citizen_male"
    CITIZEN_FEMALE = "citizen_female"
    ROBOT = "robot"
    DOG = "dog"
    CAT = "cat"
    CHILD = "child"
    OLD_MAN = "old_man"
    MERCHANT = "merchant"


# ============================================================================
# NPC 대화 데이터베이스
# ============================================================================
NPC_DIALOGUES = {
    # 게임 팁 관련 대화
    "game_tips": [
        "대쉬 손맛이 짜릿해서 핑파이터를 못끊겠어.",
        "빨간색 이름으로 된 옵션이 가장 좋다고 하더군.",
        "스테이지4에서 연막탄을 쓰면 조상들이 도와준다는 전설이 있네.",
        "코만도의 그물덫총이 무서운게 좌우로 마구 움직이니까 그물이 쪼여지더군.",
        "보스가 패턴을 바꾸기 직전에 대쉬하면 회피가 쉬워.",
        "아이템을 잘 조합하면 시너지 효과가 엄청나더라.",
        "가끔 노란색 별이 떨어지니까 놓치지 마.",
        "전설 아이템은 운이 좋아야 얻을 수 있대.",
        "스매셔는 근접전에 특화되어 있어서 공격력이 높아.",
        "스테이지 클리어 시간이 빠를수록 보상이 좋다던데.",
        "체력이 적을 때 더 강해지는 아이템도 있더라.",
        "롤링 대쉬로 무적 프레임을 잘 활용해봐.",
    ],

    # 세계관 관련 대화
    "world_lore": [
        "내 원래 몸은 지구에 있어. 여긴 가상현실이지.",
        "이 행성의 중력이 지구랑 달라서 공이 이상하게 움직여.",
        "여기 있는 건물들은 전부 데이터로 이루어져 있대.",
        "행성마다 분위기가 다른 건 테마 설정 때문이래.",
        "콜로세움에서는 매일 치열한 경기가 열린다더군.",
        "이 세계에서 죽어도 리스폰되니까 걱정 마.",
        "대장장이 기술은 고대 AI 문명에서 전해진 거래.",
        "도박장은 확률 조작이 없다고 관리자가 보증했어.",
        "이 번화가는 스테이지 사이에 있는 안식처야.",
        "가상현실이라도 여기서 느끼는 감정은 진짜야.",
    ],

    # 일상 대화
    "daily_life": [
        "날씨가 좋네. 오늘도 좋은 하루 보내.",
        "요즘 번화가에 사람이 많아졌어.",
        "나도 예전엔 핑파이터 선수였지...",
        "오늘 상점에서 세일한다던데 확인해봤어?",
        "피곤해. 오늘 하루가 너무 길었어.",
        "저기 지나가는 로봇 봤어? 신기하지?",
        "이 근처에 맛집이 있는데 알려줄까?",
        "운동 좀 해야 하는데 귀찮아서...",
        "요즘 젊은 선수들 실력이 대단하더라.",
        "가끔은 지구가 그리워.",
    ],

    # 어린이 전용 대화
    "child": [
        "나도 커서 핑파이터가 될 거야!",
        "아저씨 진짜 강해 보여요!",
        "엄마가 늦게까지 놀면 안 된대...",
        "저 강아지 귀엽지 않아요?",
        "숨바꼭질하자!",
        "나 대쉬하는 법 알아! 휙!",
    ],

    # 노인 전용 대화
    "old_man": [
        "요즘 젊은이들은 참 대단해...",
        "내 젊었을 때도 핑파이터를 했지.",
        "허리가 아파서 오래 서있기 힘들구나.",
        "세월이 참 빠르구나.",
        "건강이 제일 중요한 거야.",
        "옛날엔 이런 가상현실이 없었는데...",
    ],

    # 상인 전용 대화
    "merchant": [
        "뭐 필요한 거 있으신가요?",
        "좋은 물건 많이 있어요!",
        "오늘만 특가 세일 중이에요!",
        "다른 데서 이 가격에 못 사요.",
        "단골은 깎아 드릴게요.",
        "이거 진짜 좋은 거예요. 믿어봐요.",
    ],

    # 로봇 전용 대화
    "robot": [
        "삐빅. 인사합니다. 인간.",
        "저의 배터리 잔량은 87%입니다.",
        "감정 모듈을 업데이트 중입니다.",
        "이 구역의 치안을 담당하고 있습니다.",
        "질문이 있으시면 말씀하세요.",
        "오류 감지됨... 아, 농담입니다.",
    ],
}


# NPC 타입별 설정
NPC_CONFIG = {
    NPCType.CITIZEN_MALE: {
        "name": "남성 주민",
        "size": (24, 40),
        "speed": 1.2,
        "colors": [
            {"body": (70, 130, 180), "skin": (255, 220, 180), "hair": (60, 40, 20)},
            {"body": (100, 100, 100), "skin": (255, 200, 160), "hair": (30, 30, 30)},
            {"body": (180, 100, 100), "skin": (240, 200, 170), "hair": (80, 50, 30)},
            {"body": (60, 120, 60), "skin": (255, 210, 170), "hair": (150, 100, 50)},
        ],
        "idle_chance": 0.02,
        "chat_chance": 0.01,
    },
    NPCType.CITIZEN_FEMALE: {
        "name": "여성 주민",
        "size": (22, 38),
        "speed": 1.3,
        "colors": [
            {"body": (255, 150, 180), "skin": (255, 220, 190), "hair": (80, 40, 20)},
            {"body": (150, 100, 200), "skin": (255, 210, 180), "hair": (30, 30, 30)},
            {"body": (100, 180, 180), "skin": (240, 200, 170), "hair": (200, 150, 100)},
            {"body": (255, 200, 100), "skin": (255, 200, 160), "hair": (150, 80, 50)},
        ],
        "idle_chance": 0.025,
        "chat_chance": 0.015,
    },
    NPCType.ROBOT: {
        "name": "로봇",
        "size": (28, 42),
        "speed": 1.5,
        "colors": [
            {"body": (150, 150, 160), "accent": (0, 200, 255), "eye": (255, 50, 50)},
            {"body": (200, 200, 210), "accent": (255, 100, 255), "eye": (0, 255, 100)},
            {"body": (100, 100, 120), "accent": (255, 200, 0), "eye": (0, 150, 255)},
        ],
        "idle_chance": 0.01,
        "chat_chance": 0.005,
        "has_glow": True,
    },
    NPCType.DOG: {
        "name": "강아지",
        "size": (30, 22),
        "speed": 2.0,
        "colors": [
            {"body": (180, 140, 100), "belly": (240, 220, 200), "nose": (40, 30, 30)},
            {"body": (255, 255, 255), "belly": (255, 255, 255), "nose": (30, 30, 30)},
            {"body": (60, 50, 40), "belly": (100, 80, 60), "nose": (20, 20, 20)},
            {"body": (200, 150, 80), "belly": (255, 230, 180), "nose": (50, 40, 30)},
        ],
        "idle_chance": 0.03,
        "wag_tail": True,
        "can_bark": True,
    },
    NPCType.CAT: {
        "name": "고양이",
        "size": (26, 20),
        "speed": 1.8,
        "colors": [
            {"body": (100, 100, 100), "belly": (200, 200, 200), "eyes": (100, 200, 100)},
            {"body": (255, 200, 150), "belly": (255, 240, 220), "eyes": (100, 150, 255)},
            {"body": (50, 50, 50), "belly": (80, 80, 80), "eyes": (255, 200, 50)},
            {"body": (255, 255, 255), "belly": (255, 255, 255), "eyes": (100, 200, 255)},
            {"body": (200, 100, 50), "belly": (255, 200, 150), "eyes": (150, 255, 100)},
        ],
        "idle_chance": 0.04,
        "can_meow": True,
        "can_sit": True,
    },
    NPCType.CHILD: {
        "name": "어린이",
        "size": (18, 28),
        "speed": 2.2,
        "colors": [
            {"body": (255, 100, 100), "skin": (255, 220, 190), "hair": (60, 40, 20)},
            {"body": (100, 150, 255), "skin": (255, 210, 180), "hair": (80, 50, 30)},
            {"body": (255, 200, 50), "skin": (255, 200, 160), "hair": (30, 30, 30)},
        ],
        "idle_chance": 0.015,
        "can_run": True,
    },
    NPCType.OLD_MAN: {
        "name": "노인",
        "size": (24, 36),
        "speed": 0.8,
        "colors": [
            {"body": (120, 100, 80), "skin": (255, 210, 170), "hair": (200, 200, 200)},
            {"body": (80, 80, 100), "skin": (240, 200, 160), "hair": (180, 180, 180)},
        ],
        "idle_chance": 0.05,
        "has_cane": True,
    },
    NPCType.MERCHANT: {
        "name": "상인",
        "size": (26, 40),
        "speed": 0.5,
        "colors": [
            {"body": (150, 100, 50), "skin": (255, 200, 160), "hair": (60, 40, 20), "apron": (255, 255, 255)},
            {"body": (100, 80, 60), "skin": (240, 190, 150), "hair": (40, 30, 20), "apron": (200, 200, 200)},
        ],
        "idle_chance": 0.08,
        "stationary": True,
    },
}


class NPC:
    """개별 NPC 클래스"""

    def __init__(self, npc_type, x, y):
        self.type = npc_type
        self.config = NPC_CONFIG[npc_type]

        # 위치
        self.x = float(x)
        self.y = float(y)

        # 크기
        self.width, self.height = self.config["size"]

        # 이동
        self.speed = self.config["speed"] * random.uniform(0.8, 1.2)
        self.vx = 0
        self.vy = 0
        self.direction = random.randint(0, 3)  # 0:하, 1:좌, 2:우, 3:상

        # 색상 (랜덤 선택)
        self.colors = random.choice(self.config["colors"])

        # 상태
        self.state = "walking"  # walking, idle, sitting, chatting
        self.state_timer = 0
        self.idle_duration = 0

        # 애니메이션
        self.animation_frame = 0
        self.animation_timer = 0
        self.animation_speed = 0.15

        # 경로
        self.target_x = None
        self.target_y = None
        self.path_timer = 0
        self.wander_range = 200  # 배회 범위

        # 특수 효과
        self.effect_timer = 0
        self.speech_bubble = None
        self.speech_timer = 0

        # 대화 시스템
        self.is_talking = False
        self.dialogue_timer = 0
        self.last_dialogue = None  # 마지막 대화 내용 (중복 방지)

        # 초기 목표 설정
        self._set_new_target()

    def _set_new_target(self):
        """새로운 이동 목표 설정"""
        if self.config.get("stationary"):
            self.target_x = self.x
            self.target_y = self.y
            return

        # 현재 위치 기준 랜덤 목표
        angle = random.uniform(0, 2 * math.pi)
        distance = random.uniform(50, self.wander_range)

        self.target_x = self.x + math.cos(angle) * distance
        self.target_y = self.y + math.sin(angle) * distance

        # 맵 경계 제한
        self.target_x = max(TILE_SIZE * 2, min(MAP_WIDTH * TILE_SIZE - TILE_SIZE * 2, self.target_x))
        self.target_y = max(TILE_SIZE * 2, min(MAP_HEIGHT * TILE_SIZE - TILE_SIZE * 2, self.target_y))

    def update(self, dt, downtown_map):
        """NPC 업데이트"""
        self.animation_timer += dt
        self.effect_timer += dt
        self.state_timer += dt
        self.path_timer += dt

        # 대화 타이머 업데이트
        if self.is_talking:
            self.dialogue_timer -= dt
            if self.dialogue_timer <= 0:
                self.end_dialogue()

        # 말풍선 타이머
        if self.speech_bubble:
            self.speech_timer -= dt
            if self.speech_timer <= 0:
                self.speech_bubble = None

        # 상태별 업데이트
        if self.state == "idle":
            self._update_idle(dt)
        elif self.state == "sitting":
            self._update_sitting(dt)
        elif self.state == "chatting":
            self._update_chatting(dt)
        else:
            self._update_walking(dt, downtown_map)

        # 애니메이션 업데이트
        if self.vx != 0 or self.vy != 0:
            if self.animation_timer >= self.animation_speed:
                self.animation_timer = 0
                self.animation_frame = (self.animation_frame + 1) % 4
        else:
            self.animation_frame = 0

    def _update_walking(self, dt, downtown_map):
        """걷기 상태 업데이트"""
        # 목표 도달 확인
        if self.target_x is None or self.target_y is None:
            self._set_new_target()
            return

        dx = self.target_x - self.x
        dy = self.target_y - self.y
        dist = math.sqrt(dx * dx + dy * dy)

        if dist < 10 or self.path_timer > 5:
            # 목표 도달 또는 시간 초과
            self.path_timer = 0

            # 일정 확률로 멈춤
            if random.random() < self.config.get("idle_chance", 0.02):
                self.state = "idle"
                self.idle_duration = random.uniform(1, 4)
                self.state_timer = 0
                self.vx = 0
                self.vy = 0

                # 고양이는 앉을 수 있음
                if self.config.get("can_sit") and random.random() < 0.3:
                    self.state = "sitting"
                    self.idle_duration = random.uniform(2, 6)
                return

            self._set_new_target()
            return

        # 이동
        self.vx = (dx / dist) * self.speed
        self.vy = (dy / dist) * self.speed

        # 방향 설정
        if abs(dx) > abs(dy):
            self.direction = 1 if dx < 0 else 2
        else:
            self.direction = 3 if dy < 0 else 0

        # 어린이는 가끔 뛰기
        speed_mult = 1.0
        if self.config.get("can_run") and random.random() < 0.01:
            speed_mult = 1.8

        # 새 위치 계산
        new_x = self.x + self.vx * dt * 60 * speed_mult
        new_y = self.y + self.vy * dt * 60 * speed_mult

        # 충돌 체크
        if self._can_move_to(new_x, self.y, downtown_map):
            self.x = new_x
        else:
            self._set_new_target()

        if self._can_move_to(self.x, new_y, downtown_map):
            self.y = new_y
        else:
            self._set_new_target()

    def _update_idle(self, dt):
        """대기 상태 업데이트"""
        self.vx = 0
        self.vy = 0

        if self.state_timer >= self.idle_duration:
            self.state = "walking"
            self._set_new_target()

        # 강아지 짖기
        if self.config.get("can_bark") and random.random() < 0.005:
            self.speech_bubble = "멍멍!"
            self.speech_timer = 1.5

        # 고양이 울음
        if self.config.get("can_meow") and random.random() < 0.003:
            self.speech_bubble = "야옹~"
            self.speech_timer = 1.5

    def _update_sitting(self, dt):
        """앉기 상태 업데이트 (고양이)"""
        self.vx = 0
        self.vy = 0

        if self.state_timer >= self.idle_duration:
            self.state = "walking"
            self._set_new_target()

    def _update_chatting(self, dt):
        """대화 상태 업데이트"""
        self.vx = 0
        self.vy = 0

        if self.state_timer >= self.idle_duration:
            self.state = "walking"
            self._set_new_target()

    def _can_move_to(self, new_x, new_y, downtown_map):
        """이동 가능 여부 체크"""
        # 4개 코너 체크
        half_w = self.width // 4
        half_h = self.height // 4

        corners = [
            (new_x - half_w, new_y - half_h),
            (new_x + half_w, new_y - half_h),
            (new_x - half_w, new_y + half_h),
            (new_x + half_w, new_y + half_h),
        ]

        for cx, cy in corners:
            if not downtown_map.is_walkable(cx, cy):
                return False

        return True

    def draw(self, screen, camera_offset=(0, 0)):
        """NPC 그리기"""
        draw_x = self.x - camera_offset[0]
        draw_y = self.y - camera_offset[1]

        # 화면 밖이면 건너뜀
        if draw_x < -50 or draw_x > SCREEN_WIDTH + 50:
            return
        if draw_y < -50 or draw_y > SCREEN_HEIGHT + 50:
            return

        # 그림자
        self._draw_shadow(screen, draw_x, draw_y)

        # NPC 본체
        if self.type == NPCType.DOG:
            self._draw_dog(screen, draw_x, draw_y)
        elif self.type == NPCType.CAT:
            self._draw_cat(screen, draw_x, draw_y)
        elif self.type == NPCType.ROBOT:
            self._draw_robot(screen, draw_x, draw_y)
        elif self.type in [NPCType.CITIZEN_MALE, NPCType.CITIZEN_FEMALE,
                          NPCType.CHILD, NPCType.OLD_MAN, NPCType.MERCHANT]:
            self._draw_human(screen, draw_x, draw_y)

        # 말풍선
        if self.speech_bubble:
            self._draw_speech_bubble(screen, draw_x, draw_y)

    def _draw_shadow(self, screen, x, y):
        """그림자 그리기"""
        shadow_w = int(self.width * 0.6)
        shadow_h = int(shadow_w * 0.3)
        shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40), (0, 0, shadow_w, shadow_h))
        screen.blit(shadow_surf, (x - shadow_w // 2, y + self.height // 3))

    def _draw_human(self, screen, x, y):
        """사람형 NPC 그리기"""
        colors = self.colors
        bounce = 0

        if self.vx != 0 or self.vy != 0:
            bounce = math.sin(self.animation_frame * math.pi / 2) * 2

        # 몸통
        body_rect = pygame.Rect(
            x - self.width // 2,
            y - self.height // 2 + 12 - bounce,
            self.width,
            self.height - 12
        )
        pygame.draw.ellipse(screen, colors["body"], body_rect)
        pygame.draw.ellipse(screen, tuple(max(0, c - 30) for c in colors["body"]), body_rect, 2)

        # 머리
        head_size = int(self.width * 0.8)
        head_rect = pygame.Rect(
            x - head_size // 2,
            y - self.height // 2 - bounce,
            head_size,
            head_size
        )
        pygame.draw.ellipse(screen, colors["skin"], head_rect)
        pygame.draw.ellipse(screen, tuple(max(0, c - 30) for c in colors["skin"]), head_rect, 1)

        # 머리카락 (hair 키가 없으면 기본 색상 사용)
        hair_color = colors.get("hair", (60, 40, 20))
        hair_rect = pygame.Rect(
            x - head_size // 2,
            y - self.height // 2 - bounce,
            head_size,
            head_size // 2
        )
        pygame.draw.ellipse(screen, hair_color, hair_rect)

        # 눈
        eye_offset = 0
        if self.direction == 1:
            eye_offset = -3
        elif self.direction == 2:
            eye_offset = 3

        if self.direction != 3:  # 위쪽 아닐 때
            eye_y = y - self.height // 2 + head_size // 2 - bounce
            pygame.draw.circle(screen, (40, 40, 40), (int(x - 4 + eye_offset), int(eye_y)), 2)
            pygame.draw.circle(screen, (40, 40, 40), (int(x + 4 + eye_offset), int(eye_y)), 2)

        # 노인 지팡이
        if self.config.get("has_cane"):
            cane_x = x + self.width // 2 + 3
            pygame.draw.line(screen, (100, 70, 40),
                           (cane_x, y - 5), (cane_x, y + self.height // 3), 3)
            pygame.draw.circle(screen, (80, 50, 30), (int(cane_x), int(y - 5)), 4)

        # 상인 앞치마
        if self.config.get("stationary") and "apron" in colors:
            apron_rect = pygame.Rect(
                x - self.width // 2 + 3,
                y - self.height // 4,
                self.width - 6,
                self.height // 2
            )
            pygame.draw.rect(screen, colors["apron"], apron_rect)

    def _draw_dog(self, screen, x, y):
        """강아지 그리기"""
        colors = self.colors
        bounce = 0

        if self.vx != 0 or self.vy != 0:
            bounce = math.sin(self.animation_frame * math.pi / 2) * 2

        # 몸통
        body_w = self.width
        body_h = int(self.height * 0.7)
        body_rect = pygame.Rect(
            x - body_w // 2,
            y - body_h // 2 - bounce,
            body_w,
            body_h
        )
        pygame.draw.ellipse(screen, colors["body"], body_rect)

        # 배
        belly_rect = pygame.Rect(
            x - body_w // 3,
            y - body_h // 4 - bounce,
            body_w * 2 // 3,
            body_h // 2
        )
        pygame.draw.ellipse(screen, colors["belly"], belly_rect)

        # 머리
        head_x = x + (body_w // 3 if self.direction == 2 else -body_w // 3 if self.direction == 1 else 0)
        head_y = y - body_h // 2 - bounce
        head_size = int(body_h * 0.8)
        pygame.draw.circle(screen, colors["body"], (int(head_x), int(head_y)), head_size // 2)

        # 귀
        ear_offset = 6
        pygame.draw.ellipse(screen, colors["body"],
                          (head_x - ear_offset - 4, head_y - head_size // 2, 8, 12))
        pygame.draw.ellipse(screen, colors["body"],
                          (head_x + ear_offset - 4, head_y - head_size // 2, 8, 12))

        # 코
        nose_x = head_x + (8 if self.direction == 2 else -8 if self.direction == 1 else 0)
        pygame.draw.circle(screen, colors["nose"], (int(nose_x), int(head_y + 2)), 3)

        # 눈
        eye_x = head_x + (4 if self.direction == 2 else -4 if self.direction == 1 else 0)
        pygame.draw.circle(screen, (40, 40, 40), (int(eye_x - 4), int(head_y - 2)), 2)
        pygame.draw.circle(screen, (40, 40, 40), (int(eye_x + 4), int(head_y - 2)), 2)

        # 꼬리 (흔들림)
        if self.config.get("wag_tail"):
            wag = math.sin(self.effect_timer * 10) * 15
            tail_x = x - body_w // 2 - 5 if self.direction != 1 else x + body_w // 2 + 5
            tail_base = (tail_x, y - bounce)
            tail_end = (tail_x + (-10 if self.direction != 1 else 10),
                       y - body_h // 2 + wag - bounce)
            pygame.draw.line(screen, colors["body"], tail_base, tail_end, 4)

        # 다리 애니메이션
        leg_y = y + body_h // 4 - bounce
        leg_offset = math.sin(self.animation_frame * math.pi / 2) * 3 if (self.vx != 0 or self.vy != 0) else 0
        for i, lx in enumerate([x - 8, x + 8]):
            offset = leg_offset if i % 2 == 0 else -leg_offset
            pygame.draw.line(screen, colors["body"],
                           (lx, leg_y), (lx + offset, leg_y + 8), 4)

    def _draw_cat(self, screen, x, y):
        """고양이 그리기"""
        colors = self.colors
        bounce = 0

        if self.state == "sitting":
            # 앉은 자세
            self._draw_sitting_cat(screen, x, y, colors)
            return

        if self.vx != 0 or self.vy != 0:
            bounce = math.sin(self.animation_frame * math.pi / 2) * 2

        # 몸통
        body_w = self.width
        body_h = int(self.height * 0.7)
        body_rect = pygame.Rect(
            x - body_w // 2,
            y - body_h // 2 - bounce,
            body_w,
            body_h
        )
        pygame.draw.ellipse(screen, colors["body"], body_rect)

        # 배
        belly_rect = pygame.Rect(
            x - body_w // 4,
            y - body_h // 4 - bounce,
            body_w // 2,
            body_h // 2
        )
        pygame.draw.ellipse(screen, colors["belly"], belly_rect)

        # 머리
        dir_offset = 8 if self.direction == 2 else -8 if self.direction == 1 else 0
        head_x = x + dir_offset
        head_y = y - body_h // 2 - 2 - bounce
        head_size = int(body_h * 0.9)
        pygame.draw.circle(screen, colors["body"], (int(head_x), int(head_y)), head_size // 2)

        # 삼각형 귀
        ear_size = 8
        # 왼쪽 귀
        pygame.draw.polygon(screen, colors["body"], [
            (head_x - head_size // 3, head_y - head_size // 4),
            (head_x - head_size // 3 - ear_size // 2, head_y - head_size // 2 - ear_size),
            (head_x - head_size // 3 + ear_size // 2, head_y - head_size // 4),
        ])
        # 오른쪽 귀
        pygame.draw.polygon(screen, colors["body"], [
            (head_x + head_size // 3, head_y - head_size // 4),
            (head_x + head_size // 3 + ear_size // 2, head_y - head_size // 2 - ear_size),
            (head_x + head_size // 3 - ear_size // 2, head_y - head_size // 4),
        ])

        # 귀 안쪽 (핑크)
        pygame.draw.polygon(screen, (255, 180, 180), [
            (head_x - head_size // 3, head_y - head_size // 4 + 2),
            (head_x - head_size // 3, head_y - head_size // 2 - ear_size + 4),
            (head_x - head_size // 3 + 3, head_y - head_size // 4 + 2),
        ])
        pygame.draw.polygon(screen, (255, 180, 180), [
            (head_x + head_size // 3, head_y - head_size // 4 + 2),
            (head_x + head_size // 3, head_y - head_size // 2 - ear_size + 4),
            (head_x + head_size // 3 - 3, head_y - head_size // 4 + 2),
        ])

        # 눈 (고양이 특유의 타원형)
        eye_offset = 3 if self.direction == 2 else -3 if self.direction == 1 else 0
        eye_y = head_y
        pygame.draw.ellipse(screen, colors["eyes"],
                          (head_x - 6 + eye_offset, eye_y - 3, 5, 6))
        pygame.draw.ellipse(screen, colors["eyes"],
                          (head_x + 2 + eye_offset, eye_y - 3, 5, 6))
        # 동공 (세로 슬릿)
        pygame.draw.line(screen, (20, 20, 20),
                        (head_x - 4 + eye_offset, eye_y - 2),
                        (head_x - 4 + eye_offset, eye_y + 2), 1)
        pygame.draw.line(screen, (20, 20, 20),
                        (head_x + 4 + eye_offset, eye_y - 2),
                        (head_x + 4 + eye_offset, eye_y + 2), 1)

        # 코
        pygame.draw.polygon(screen, (255, 150, 150), [
            (head_x + eye_offset, head_y + 3),
            (head_x - 2 + eye_offset, head_y + 6),
            (head_x + 2 + eye_offset, head_y + 6),
        ])

        # 수염
        whisker_y = head_y + 4
        for dy in [-2, 0, 2]:
            pygame.draw.line(screen, (200, 200, 200),
                           (head_x - 8 + eye_offset, whisker_y + dy),
                           (head_x - 15 + eye_offset, whisker_y + dy - 1), 1)
            pygame.draw.line(screen, (200, 200, 200),
                           (head_x + 8 + eye_offset, whisker_y + dy),
                           (head_x + 15 + eye_offset, whisker_y + dy - 1), 1)

        # 꼬리 (S자 곡선)
        tail_wave = math.sin(self.effect_timer * 3) * 5
        tail_x = x - body_w // 2 - 3
        points = []
        for i in range(8):
            t = i / 7
            tx = tail_x - i * 2
            ty = y - bounce + math.sin(t * math.pi + self.effect_timer * 2) * 8
            points.append((tx, ty))
        if len(points) >= 2:
            pygame.draw.lines(screen, colors["body"], False, points, 4)

        # 다리
        leg_y = y + body_h // 4 - bounce
        leg_offset = math.sin(self.animation_frame * math.pi / 2) * 2 if (self.vx != 0 or self.vy != 0) else 0
        for i, lx in enumerate([x - 6, x + 6]):
            offset = leg_offset if i % 2 == 0 else -leg_offset
            pygame.draw.line(screen, colors["body"],
                           (lx, leg_y), (lx + offset, leg_y + 6), 3)

    def _draw_sitting_cat(self, screen, x, y, colors):
        """앉은 고양이 그리기"""
        # 몸통 (원형으로)
        body_size = int(self.width * 0.9)
        pygame.draw.circle(screen, colors["body"], (int(x), int(y)), body_size // 2)

        # 앞발
        pygame.draw.ellipse(screen, colors["body"],
                          (x - body_size // 3, y + body_size // 4, 10, 6))
        pygame.draw.ellipse(screen, colors["body"],
                          (x + body_size // 3 - 10, y + body_size // 4, 10, 6))

        # 머리
        head_size = int(body_size * 0.8)
        head_y = y - body_size // 2
        pygame.draw.circle(screen, colors["body"], (int(x), int(head_y)), head_size // 2)

        # 귀
        ear_size = 7
        pygame.draw.polygon(screen, colors["body"], [
            (x - head_size // 3, head_y - head_size // 4),
            (x - head_size // 3, head_y - head_size // 2 - ear_size),
            (x - head_size // 3 + ear_size, head_y - head_size // 4),
        ])
        pygame.draw.polygon(screen, colors["body"], [
            (x + head_size // 3, head_y - head_size // 4),
            (x + head_size // 3, head_y - head_size // 2 - ear_size),
            (x + head_size // 3 - ear_size, head_y - head_size // 4),
        ])

        # 눈 (감은 눈 - 앉아서 쉬는 중)
        eye_y = head_y - 1
        pygame.draw.arc(screen, (40, 40, 40), (x - 8, eye_y - 2, 6, 4), 0, math.pi, 2)
        pygame.draw.arc(screen, (40, 40, 40), (x + 2, eye_y - 2, 6, 4), 0, math.pi, 2)

        # 코
        pygame.draw.polygon(screen, (255, 150, 150), [
            (x, head_y + 2),
            (x - 2, head_y + 5),
            (x + 2, head_y + 5),
        ])

        # 꼬리 (몸 옆에)
        tail_wave = math.sin(self.effect_timer * 2) * 3
        pygame.draw.arc(screen, colors["body"],
                       (x + body_size // 3, y - body_size // 4, 20, 30 + tail_wave),
                       -0.5, math.pi * 0.8, 4)

    def _draw_robot(self, screen, x, y):
        """로봇 그리기"""
        colors = self.colors
        bounce = 0

        if self.vx != 0 or self.vy != 0:
            bounce = math.sin(self.animation_frame * math.pi) * 1

        # 글로우 효과
        if self.config.get("has_glow"):
            glow_alpha = int(100 + 50 * math.sin(self.effect_timer * 5))
            glow_surf = pygame.Surface((self.width + 20, self.height + 20), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*colors["accent"], glow_alpha // 3),
                           (0, 0, self.width + 20, self.height + 20), border_radius=10)
            screen.blit(glow_surf, (x - self.width // 2 - 10, y - self.height // 2 - 10 - bounce))

        # 몸통 (사각형)
        body_rect = pygame.Rect(
            x - self.width // 2,
            y - self.height // 3 - bounce,
            self.width,
            self.height * 2 // 3
        )
        pygame.draw.rect(screen, colors["body"], body_rect, border_radius=5)
        pygame.draw.rect(screen, colors["accent"], body_rect, 2, border_radius=5)

        # 가슴 패널
        panel_rect = pygame.Rect(
            x - self.width // 3,
            y - self.height // 4 - bounce,
            self.width * 2 // 3,
            self.height // 4
        )
        pygame.draw.rect(screen, (50, 50, 60), panel_rect)
        # 패널 조명
        light_x = x - self.width // 4
        for i in range(3):
            light_color = colors["accent"] if (int(self.effect_timer * 3) + i) % 3 == 0 else (60, 60, 70)
            pygame.draw.circle(screen, light_color,
                             (int(light_x + i * 10), int(y - self.height // 6 - bounce)), 3)

        # 머리 (사각형)
        head_w = int(self.width * 0.8)
        head_h = int(self.height * 0.35)
        head_rect = pygame.Rect(
            x - head_w // 2,
            y - self.height // 2 - head_h // 2 - bounce,
            head_w,
            head_h
        )
        pygame.draw.rect(screen, colors["body"], head_rect, border_radius=3)
        pygame.draw.rect(screen, colors["accent"], head_rect, 2, border_radius=3)

        # 안테나
        antenna_y = y - self.height // 2 - head_h - bounce
        pygame.draw.line(screen, colors["body"],
                        (x, y - self.height // 2 - head_h // 2 - bounce),
                        (x, antenna_y - 5), 2)
        # 안테나 끝 (깜빡임)
        blink = int(self.effect_timer * 5) % 2 == 0
        pygame.draw.circle(screen, colors["accent"] if blink else (100, 100, 100),
                          (int(x), int(antenna_y - 5)), 3)

        # 눈 (LED)
        eye_y = y - self.height // 2 - bounce
        eye_glow = 255 if blink else 150
        pygame.draw.rect(screen, (*colors["eye"][:2], eye_glow),
                        (x - 10, eye_y - 3, 8, 6))
        pygame.draw.rect(screen, (*colors["eye"][:2], eye_glow),
                        (x + 2, eye_y - 3, 8, 6))

        # 다리 (기계식)
        leg_y = y + self.height // 3 - bounce
        leg_offset = math.sin(self.animation_frame * math.pi / 2) * 3 if (self.vx != 0 or self.vy != 0) else 0
        for i, lx in enumerate([x - 6, x + 6]):
            offset = leg_offset if i % 2 == 0 else -leg_offset
            pygame.draw.line(screen, colors["body"],
                           (lx, leg_y), (lx, leg_y + 10), 4)
            pygame.draw.rect(screen, colors["accent"],
                           (lx - 4, leg_y + 10 + abs(offset), 8, 4))

    def _draw_speech_bubble(self, screen, x, y):
        """말풍선 그리기"""
        if not self.speech_bubble:
            return

        # 한글 폰트 로드 (pygame.freetype 사용)
        font = None
        font_size = 14

        # 1차 시도: resource_path로 폰트 로드
        try:
            font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
            if os.path.exists(font_path):
                font = pygame.freetype.Font(font_path, font_size)
        except Exception:
            pass

        # 2차 시도: 시스템 폰트 (macOS/Windows)
        if font is None:
            try:
                # macOS
                if os.path.exists("/System/Library/Fonts/AppleSDGothicNeo.ttc"):
                    font = pygame.freetype.Font("/System/Library/Fonts/AppleSDGothicNeo.ttc", font_size)
                # Windows
                elif os.path.exists("C:/Windows/Fonts/malgun.ttf"):
                    font = pygame.freetype.Font("C:/Windows/Fonts/malgun.ttf", font_size)
            except Exception:
                pass

        # 3차 시도: 기본 폰트
        if font is None:
            try:
                font = pygame.freetype.SysFont("malgungothic", font_size)
            except Exception:
                font = pygame.freetype.SysFont(None, font_size)

        # 텍스트 렌더링
        text_surface, text_rect = font.render(self.speech_bubble, (40, 40, 40))
        text_w = text_rect.width + 16
        text_h = text_rect.height + 10

        bubble_x = x - text_w // 2
        bubble_y = y - self.height - 25

        # 화면 밖으로 나가지 않게 조정
        bubble_x = max(5, min(SCREEN_WIDTH - text_w - 5, bubble_x))

        # 말풍선 배경
        bubble_surf = pygame.Surface((text_w, text_h + 8), pygame.SRCALPHA)
        pygame.draw.rect(bubble_surf, (255, 255, 255, 240),
                        (0, 0, text_w, text_h), border_radius=8)
        pygame.draw.rect(bubble_surf, (80, 80, 80),
                        (0, 0, text_w, text_h), 2, border_radius=8)

        # 꼬리
        pygame.draw.polygon(bubble_surf, (255, 255, 255, 240), [
            (text_w // 2 - 6, text_h),
            (text_w // 2 + 6, text_h),
            (text_w // 2, text_h + 8),
        ])
        pygame.draw.line(bubble_surf, (80, 80, 80),
                        (text_w // 2 - 6, text_h), (text_w // 2, text_h + 8), 2)
        pygame.draw.line(bubble_surf, (80, 80, 80),
                        (text_w // 2 + 6, text_h), (text_w // 2, text_h + 8), 2)

        screen.blit(bubble_surf, (bubble_x, bubble_y))
        screen.blit(text_surface, (bubble_x + 8, bubble_y + 5))

    def get_rect(self):
        """충돌 렉트 반환"""
        return pygame.Rect(
            self.x - self.width // 2,
            self.y - self.height // 2,
            self.width,
            self.height
        )

    def can_talk(self):
        """대화 가능 여부 체크 (사람형 NPC만 대화 가능)"""
        # 동물은 대화 불가
        if self.type in [NPCType.DOG, NPCType.CAT]:
            return False
        # 현재 대화 중이면 불가
        if self.is_talking:
            return False
        return True

    def start_dialogue(self):
        """대화 시작 - 랜덤 대사 선택"""
        if not self.can_talk():
            return None

        self.is_talking = True
        self.dialogue_timer = 4.0  # 4초간 대화 유지

        # NPC 타입별 대사 선택
        dialogue = self._get_random_dialogue()

        if dialogue:
            self.speech_bubble = dialogue
            self.speech_timer = 4.0
            self.last_dialogue = dialogue

            # 대화 중 정지
            self.state = "chatting"
            self.idle_duration = 4.0
            self.state_timer = 0
            self.vx = 0
            self.vy = 0

        return dialogue

    def _get_random_dialogue(self):
        """NPC 타입에 맞는 랜덤 대사 반환"""
        # 타입별 전용 대사가 있는 경우
        type_dialogues = {
            NPCType.CHILD: "child",
            NPCType.OLD_MAN: "old_man",
            NPCType.MERCHANT: "merchant",
            NPCType.ROBOT: "robot",
        }

        dialogue_pool = []

        # 전용 대사가 있으면 전용 대사에서 선택
        if self.type in type_dialogues:
            category = type_dialogues[self.type]
            dialogue_pool = NPC_DIALOGUES.get(category, [])
        else:
            # 일반 주민은 모든 카테고리에서 랜덤
            all_categories = ["game_tips", "world_lore", "daily_life"]
            category = random.choice(all_categories)
            dialogue_pool = NPC_DIALOGUES.get(category, [])

        if not dialogue_pool:
            return "..."

        # 마지막 대화와 다른 것 선택 시도
        available = [d for d in dialogue_pool if d != self.last_dialogue]
        if not available:
            available = dialogue_pool

        return random.choice(available)

    def end_dialogue(self):
        """대화 종료"""
        self.is_talking = False
        self.dialogue_timer = 0


class NPCManager:
    """NPC 관리자"""

    def __init__(self):
        self.npcs = []
        self.max_npcs = 15
        self.spawn_timer = 0
        self.spawn_interval = 2.0

    def initialize(self, downtown_map, stage_number=1):
        """NPC 초기화 - 맵에 맞게 생성"""
        self.npcs.clear()

        # 스테이지에 따른 NPC 수
        base_count = 5 + stage_number
        npc_count = min(base_count, self.max_npcs)

        # NPC 타입 가중치
        type_weights = {
            NPCType.CITIZEN_MALE: 20,
            NPCType.CITIZEN_FEMALE: 20,
            NPCType.DOG: 15,
            NPCType.CAT: 15,
            NPCType.CHILD: 10,
            NPCType.ROBOT: 10,
            NPCType.OLD_MAN: 8,
            NPCType.MERCHANT: 2,
        }

        # 가중치에 따른 타입 리스트
        type_list = []
        for npc_type, weight in type_weights.items():
            type_list.extend([npc_type] * weight)

        # NPC 생성
        for _ in range(npc_count):
            npc_type = random.choice(type_list)

            # 랜덤 위치 (도로나 바닥 위)
            attempts = 0
            while attempts < 50:
                x = random.randint(TILE_SIZE * 2, (MAP_WIDTH - 2) * TILE_SIZE)
                y = random.randint(TILE_SIZE * 2, (MAP_HEIGHT - 2) * TILE_SIZE)

                if downtown_map.is_walkable(x, y):
                    npc = NPC(npc_type, x, y)
                    self.npcs.append(npc)
                    break

                attempts += 1

    def update(self, dt, downtown_map):
        """모든 NPC 업데이트"""
        for npc in self.npcs:
            npc.update(dt, downtown_map)

        # 동적 스폰 (선택적)
        # self._try_spawn(dt, downtown_map)

    def _try_spawn(self, dt, downtown_map):
        """동적 NPC 스폰 시도"""
        if len(self.npcs) >= self.max_npcs:
            return

        self.spawn_timer += dt
        if self.spawn_timer < self.spawn_interval:
            return

        self.spawn_timer = 0

        if random.random() > 0.3:
            return

        # 랜덤 타입과 위치로 스폰
        npc_types = list(NPC_CONFIG.keys())
        npc_type = random.choice(npc_types)

        # 화면 가장자리에서 스폰
        edge = random.randint(0, 3)
        if edge == 0:  # 상단
            x = random.randint(TILE_SIZE * 2, (MAP_WIDTH - 2) * TILE_SIZE)
            y = TILE_SIZE * 2
        elif edge == 1:  # 하단
            x = random.randint(TILE_SIZE * 2, (MAP_WIDTH - 2) * TILE_SIZE)
            y = (MAP_HEIGHT - 2) * TILE_SIZE
        elif edge == 2:  # 좌측
            x = TILE_SIZE * 2
            y = random.randint(TILE_SIZE * 2, (MAP_HEIGHT - 2) * TILE_SIZE)
        else:  # 우측
            x = (MAP_WIDTH - 2) * TILE_SIZE
            y = random.randint(TILE_SIZE * 2, (MAP_HEIGHT - 2) * TILE_SIZE)

        if downtown_map.is_walkable(x, y):
            npc = NPC(npc_type, x, y)
            self.npcs.append(npc)

    def draw(self, screen, camera_offset=(0, 0)):
        """모든 NPC 그리기 (Y좌표 정렬)"""
        # Y좌표 기준 정렬 (깊이 표현)
        sorted_npcs = sorted(self.npcs, key=lambda n: n.y)

        for npc in sorted_npcs:
            npc.draw(screen, camera_offset)

    def get_npcs_in_range(self, x, y, radius):
        """범위 내 NPC 목록"""
        result = []
        for npc in self.npcs:
            dist = math.sqrt((npc.x - x) ** 2 + (npc.y - y) ** 2)
            if dist <= radius:
                result.append(npc)
        return result

    def get_talkable_npc_near(self, x, y, radius=60):
        """대화 가능한 가장 가까운 NPC 반환"""
        nearby = self.get_npcs_in_range(x, y, radius)
        talkable = [npc for npc in nearby if npc.can_talk()]

        if not talkable:
            return None

        # 가장 가까운 NPC 반환
        talkable.sort(key=lambda n: math.sqrt((n.x - x) ** 2 + (n.y - y) ** 2))
        return talkable[0]

    def try_talk_to_npc(self, x, y, radius=60):
        """NPC에게 말 걸기 시도 - 성공 시 대사 반환"""
        npc = self.get_talkable_npc_near(x, y, radius)
        if npc:
            return npc.start_dialogue()
        return None

    def trigger_reactions(self, player_x, player_y, radius=50):
        """플레이어 근처 NPC 반응"""
        nearby = self.get_npcs_in_range(player_x, player_y, radius)

        for npc in nearby:
            # 강아지는 플레이어 쪽으로 다가옴
            if npc.type == NPCType.DOG and random.random() < 0.1:
                npc.target_x = player_x + random.randint(-30, 30)
                npc.target_y = player_y + random.randint(-30, 30)
                if random.random() < 0.3:
                    npc.speech_bubble = "멍멍!"
                    npc.speech_timer = 1.5

            # 고양이는 도망감
            elif npc.type == NPCType.CAT and npc.state != "sitting":
                if random.random() < 0.2:
                    dx = npc.x - player_x
                    dy = npc.y - player_y
                    dist = math.sqrt(dx * dx + dy * dy) or 1
                    npc.target_x = npc.x + (dx / dist) * 100
                    npc.target_y = npc.y + (dy / dist) * 100
