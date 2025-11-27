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
    """건물 내부 NPC - 클릭으로 대화 가능 (광장 NPC와 동일한 스타일)"""

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

    # NPC 색상 프리셋 (광장 NPC와 동일한 스타일)
    NPC_COLORS = [
        {"body": (70, 130, 180), "skin": (255, 220, 180), "hair": (60, 40, 20)},
        {"body": (100, 100, 100), "skin": (255, 200, 160), "hair": (30, 30, 30)},
        {"body": (180, 100, 100), "skin": (240, 200, 170), "hair": (80, 50, 30)},
        {"body": (60, 120, 60), "skin": (255, 210, 170), "hair": (150, 100, 50)},
        {"body": (255, 150, 180), "skin": (255, 220, 190), "hair": (80, 40, 20)},
        {"body": (150, 100, 200), "skin": (255, 210, 180), "hair": (30, 30, 30)},
        {"body": (100, 180, 180), "skin": (240, 200, 170), "hair": (200, 150, 100)},
        {"body": (255, 200, 100), "skin": (255, 200, 160), "hair": (150, 80, 50)},
    ]

    def __init__(self, x, y, name, role, color, dialogue=None, building_type=None):
        self.x = x
        self.y = y
        self.name = name
        self.role = role  # "customer", "staff", "main"
        self.accent_color = color  # 강조색
        self.dialogue = dialogue or []
        self.building_type = building_type

        # 광장 NPC와 동일한 크기 (24x40 기준)
        if role == "main":
            self.width = 26
            self.height = 42
        elif role == "staff":
            self.width = 24
            self.height = 40
        else:
            self.width = 22
            self.height = 38

        # 호환성을 위한 size 속성
        self.size = self.width

        # NPC 색상 (랜덤 선택)
        self.colors = random.choice(self.NPC_COLORS)

        self.animation_offset = random.random() * math.pi * 2
        self.animation_frame = 0
        self.direction = random.randint(0, 3)  # 0:하, 1:좌, 2:우, 3:상

        # 말풍선 상태
        self.is_talking = False
        self.current_dialogue_idx = 0
        self.talk_timer = 0

        # 랜덤 동작
        self.idle_timer = random.random() * 3
        self.idle_action = None  # "look_around", "think", None

        # 걸어다니기 상태 (고객 NPC만)
        self.is_walking = False
        self.walk_timer = random.uniform(5, 15)  # 5~15초마다 걷기
        self.walk_target_x = None
        self.walk_target_y = None
        self.walk_speed = 30  # 느린 걸음
        self.original_x = x
        self.original_y = y
        self.walk_range = 60  # 원래 위치에서 최대 60픽셀 범위

    def update(self, dt, walkable_rect=None):
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

        # 고객 NPC만 걸어다니기 (메인, 스태프 제외)
        if self.role == "customer" and walkable_rect:
            self._update_walking(dt, walkable_rect)

    def _update_walking(self, dt, walkable_rect):
        """걸어다니기 업데이트 (드물게, 몇 걸음씩)"""
        # 대화 중이면 걷지 않음
        if self.is_talking:
            self.is_walking = False
            self.walk_target_x = None
            self.walk_target_y = None
            return

        # 걷고 있는 중
        if self.is_walking and self.walk_target_x is not None:
            # 목표 지점으로 이동
            dx = self.walk_target_x - self.x
            dy = self.walk_target_y - self.y
            dist = math.sqrt(dx * dx + dy * dy)

            if dist < 5:  # 목표 도달
                self.is_walking = False
                self.walk_target_x = None
                self.walk_target_y = None
                self.walk_timer = random.uniform(8, 20)  # 다음 걷기까지 8~20초 대기
            else:
                # 이동
                move_dist = self.walk_speed * dt
                if move_dist > dist:
                    move_dist = dist
                self.x += (dx / dist) * move_dist
                self.y += (dy / dist) * move_dist

                # 방향 업데이트
                if abs(dx) > abs(dy):
                    self.direction = 2 if dx > 0 else 1  # 좌우
                else:
                    self.direction = 0 if dy > 0 else 3  # 상하
        else:
            # 걷기 타이머 감소
            self.walk_timer -= dt
            if self.walk_timer <= 0:
                # 새로운 목표 지점 설정 (원래 위치 근처, 몇 걸음)
                target_x = self.original_x + random.uniform(-self.walk_range, self.walk_range)
                target_y = self.original_y + random.uniform(-self.walk_range, self.walk_range)

                # walkable 영역 내로 제한
                target_x = max(walkable_rect.left + 20, min(walkable_rect.right - 20, target_x))
                target_y = max(walkable_rect.top + 20, min(walkable_rect.bottom - 60, target_y))

                self.walk_target_x = target_x
                self.walk_target_y = target_y
                self.is_walking = True

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
        """NPC 그리기 (고퀄리티 - 다양한 얼굴/자연스러운 걸음걸이)"""
        draw_x = self.x - camera_offset[0]
        draw_y = self.y - camera_offset[1]

        # 은행 로봇 NPC인 경우 로봇 스타일로 그리기
        if self.building_type == BuildingType.BANK:
            self._draw_robot(screen, draw_x, draw_y, animation_timer)
            return

        # NPC 고유 ID로 외모 특성 결정
        npc_id = hash(self.name)

        # === 다양한 피부톤 (6가지) ===
        skin_tones = [
            (255, 224, 189),  # 밝은 피부
            (255, 205, 148),  # 중간 밝은 피부
            (234, 192, 134),  # 올리브
            (198, 134, 66),   # 중간 어두운 피부
            (141, 85, 36),    # 어두운 피부
            (255, 219, 172),  # 복숭아빛
        ]
        skin_color = self.colors.get("skin", skin_tones[npc_id % len(skin_tones)])

        # === 다양한 얼굴형 (4가지) ===
        face_types = ["round", "oval", "square", "long"]
        face_type = face_types[(npc_id // 3) % len(face_types)]

        # === 다양한 표정 (5가지) ===
        expressions = ["neutral", "happy", "serious", "shy", "cheerful"]
        expression = expressions[(npc_id // 7) % len(expressions)]

        # === 다양한 눈 크기/모양 ===
        eye_sizes = ["normal", "big", "small"]
        eye_size = eye_sizes[(npc_id // 11) % len(eye_sizes)]

        # 걷기/정지 애니메이션 (단순하고 자연스러운 걸음걸이)
        if self.is_walking:
            # 연속적인 걸음 사이클
            walk_phase = animation_timer * 6 + self.animation_offset

            # 핵심: 다리 스윙 (왼발 앞 = 오른발 뒤)
            leg_swing = math.sin(walk_phase) * 2.5

            # 상하 움직임
            bob_offset = int(abs(math.sin(walk_phase * 2)) * 1.0)

            # 몸통 살짝 기울기
            body_lean = math.sin(walk_phase) * 0.5
        else:
            bob_offset = int(0.5 * math.sin(animation_timer * 1.2 + self.animation_offset))
            leg_swing = 0
            body_lean = 0

        # 색상
        body_color = self.colors.get("body", (100, 100, 100))
        hair_color = self.colors.get("hair", (60, 40, 20))

        # 메인 NPC는 강조색 사용
        if self.role == "main":
            body_color = self.accent_color

        # 어두운/밝은 색상 계산
        body_dark = tuple(max(0, c - 30) for c in body_color)
        body_light = tuple(min(255, c + 30) for c in body_color)
        skin_dark = tuple(max(0, c - 25) for c in skin_color)
        skin_light = tuple(min(255, c + 15) for c in skin_color)

        # 위치 계산 (발 위치 기준)
        center_x = int(draw_x + body_lean)
        feet_y = int(draw_y)

        # === 그림자 (타원형, 반투명) ===
        shadow_w = self.width + 10
        shadow_h = 6
        shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40), (0, 0, shadow_w, shadow_h))
        screen.blit(shadow_surf, (center_x - shadow_w // 2, feet_y - 3))

        # === 신발/발 (자연스러운 걸음걸이) ===
        shoe_colors = [(40, 30, 25), (60, 50, 40), (30, 30, 35), (80, 40, 20)]
        shoe_color = shoe_colors[npc_id % len(shoe_colors)]
        shoe_w, shoe_h = 8, 5

        # 걷기 애니메이션: 왼발이 앞으로 가면 오른발은 뒤로
        if self.is_walking:
            left_foot_forward = int(leg_swing)
            right_foot_forward = -int(leg_swing)
            left_lift = int(max(0, leg_swing) * 0.8)
            right_lift = int(max(0, -leg_swing) * 0.8)
        else:
            left_foot_forward = 0
            right_foot_forward = 0
            left_lift = 0
            right_lift = 0

        # 왼발
        left_foot_x = center_x - 3 + left_foot_forward
        left_foot_y = feet_y - shoe_h - left_lift
        pygame.draw.ellipse(screen, shoe_color, (left_foot_x - shoe_w // 2, left_foot_y, shoe_w, shoe_h))

        # 오른발
        right_foot_x = center_x + 3 + right_foot_forward
        right_foot_y = feet_y - shoe_h - right_lift
        pygame.draw.ellipse(screen, shoe_color, (right_foot_x - shoe_w // 2, right_foot_y, shoe_w, shoe_h))

        # === 다리 (바지) ===
        leg_w, leg_h = 6, 14
        pants_color = body_dark if self.role != "staff" else (50, 50, 60)

        # 왼쪽 다리
        left_leg_y = feet_y - shoe_h - leg_h - left_lift
        pygame.draw.rect(screen, pants_color, (left_foot_x - leg_w // 2, left_leg_y, leg_w, leg_h), border_radius=2)

        # 오른쪽 다리
        right_leg_y = feet_y - shoe_h - leg_h - right_lift
        pygame.draw.rect(screen, pants_color, (right_foot_x - leg_w // 2, right_leg_y, leg_w, leg_h), border_radius=2)

        # === 상체/몸통 ===
        torso_w, torso_h = self.width - 4, 16
        torso_y = feet_y - shoe_h - leg_h - torso_h + bob_offset + 2
        torso_x = center_x - torso_w // 2

        # 몸통 배경
        pygame.draw.rect(screen, body_color, (torso_x, torso_y, torso_w, torso_h), border_radius=4)
        pygame.draw.rect(screen, body_light, (torso_x + 1, torso_y + 2, 3, torso_h - 4), border_radius=1)

        # === 팔 (걸을 때 다리와 반대로 흔들림) ===
        arm_w, arm_h = 5, 12
        arm_y = torso_y + 2

        if self.is_walking:
            # 팔은 다리와 반대로
            left_arm_swing = int(leg_swing * 0.6)
            right_arm_swing = int(-leg_swing * 0.6)
        else:
            left_arm_swing = int(1.5 * math.sin(animation_timer * 1.0))
            right_arm_swing = int(1.5 * math.sin(animation_timer * 1.0 + 0.8))

        # 왼팔
        pygame.draw.rect(screen, body_dark, (torso_x - arm_w + 1, arm_y + left_arm_swing, arm_w, arm_h - 2), border_radius=2)
        pygame.draw.ellipse(screen, skin_color, (torso_x - arm_w + 2, arm_y + arm_h - 4 + left_arm_swing, 4, 4))

        # 오른팔
        pygame.draw.rect(screen, body_color, (torso_x + torso_w - 2, arm_y + right_arm_swing, arm_w, arm_h - 2), border_radius=2)
        pygame.draw.ellipse(screen, skin_color, (torso_x + torso_w - 1, arm_y + arm_h - 4 + right_arm_swing, 4, 4))

        # === 목 ===
        neck_w, neck_h = 6, 4
        neck_y = torso_y - neck_h + 2
        pygame.draw.rect(screen, skin_color, (center_x - neck_w // 2, neck_y, neck_w, neck_h + 2))

        # === 머리 (얼굴형에 따라 다름) ===
        if face_type == "round":
            head_w, head_h = 15, 15
        elif face_type == "oval":
            head_w, head_h = 13, 17
        elif face_type == "square":
            head_w, head_h = 14, 14
        else:  # long
            head_w, head_h = 12, 18

        head_y = neck_y - head_h + 4 + bob_offset
        head_x = center_x - head_w // 2

        # 얼굴 그리기
        pygame.draw.ellipse(screen, skin_color, (head_x, head_y, head_w, head_h))

        # 볼 터치 (표정에 따라 다름)
        if expression in ["happy", "cheerful", "shy"]:
            cheek_color = (255, 180, 180) if expression == "shy" else (255, 200, 190)
            cheek_size = 3 if expression == "shy" else 2
            pygame.draw.circle(screen, cheek_color, (head_x + 3, head_y + head_h // 2 + 2), cheek_size)
            pygame.draw.circle(screen, cheek_color, (head_x + head_w - 3, head_y + head_h // 2 + 2), cheek_size)

        # === 머리카락 (5가지 스타일) ===
        hair_styles = ["short", "medium", "long", "spiky", "curly"]
        hair_style = hair_styles[npc_id % len(hair_styles)]

        if hair_style == "short":
            pygame.draw.ellipse(screen, hair_color, (head_x - 1, head_y - 2, head_w + 2, head_h // 2 + 4))
            pygame.draw.rect(screen, hair_color, (head_x, head_y, head_w, 6), border_radius=3)
        elif hair_style == "medium":
            pygame.draw.ellipse(screen, hair_color, (head_x - 2, head_y - 3, head_w + 4, head_h // 2 + 5))
            pygame.draw.ellipse(screen, hair_color, (head_x - 3, head_y + 2, 5, 10))
            pygame.draw.ellipse(screen, hair_color, (head_x + head_w - 2, head_y + 2, 5, 10))
        elif hair_style == "long":
            pygame.draw.ellipse(screen, hair_color, (head_x - 2, head_y - 3, head_w + 4, head_h // 2 + 5))
            pygame.draw.ellipse(screen, hair_color, (head_x - 4, head_y + 2, 6, 16))
            pygame.draw.ellipse(screen, hair_color, (head_x + head_w - 2, head_y + 2, 6, 16))
        elif hair_style == "spiky":
            pygame.draw.ellipse(screen, hair_color, (head_x - 1, head_y - 1, head_w + 2, head_h // 2 + 3))
            for i in range(5):
                spike_x = head_x + 2 + i * 3
                pygame.draw.polygon(screen, hair_color, [
                    (spike_x, head_y + 2), (spike_x + 2, head_y - 4 - i % 2 * 2), (spike_x + 4, head_y + 2)
                ])
        else:  # curly
            pygame.draw.ellipse(screen, hair_color, (head_x - 2, head_y - 3, head_w + 4, head_h // 2 + 6))
            for i in range(4):
                curl_x = head_x - 1 + i * 4
                pygame.draw.circle(screen, hair_color, (curl_x + 2, head_y + 1), 3)

        # === 눈 (크기/모양에 따라 다름) ===
        eye_y_pos = head_y + head_h // 2 - 1
        eye_offset = 2 if self.direction == 2 else (-2 if self.direction == 1 else 0)
        eye_spacing = 4

        if eye_size == "big":
            eye_w, eye_h = 6, 5
        elif eye_size == "small":
            eye_w, eye_h = 4, 3
        else:
            eye_w, eye_h = 5, 4

        # 눈 흰자
        pygame.draw.ellipse(screen, (255, 255, 255), (center_x - eye_spacing - eye_w // 2 + eye_offset, eye_y_pos - eye_h // 2, eye_w, eye_h))
        pygame.draw.ellipse(screen, (255, 255, 255), (center_x + eye_spacing - eye_w // 2 + eye_offset, eye_y_pos - eye_h // 2, eye_w, eye_h))

        # 눈동자 색상 (다양화)
        pupil_colors = [(40, 30, 20), (60, 40, 30), (30, 50, 70), (50, 30, 20)]
        pupil_color = pupil_colors[npc_id % len(pupil_colors)]
        pupil_offset_x = 1 if self.direction == 2 else (-1 if self.direction == 1 else 0)

        # 표정에 따른 눈 모양
        if expression == "happy" or expression == "cheerful":
            # 웃는 눈 (반달 모양)
            pygame.draw.arc(screen, pupil_color, (center_x - eye_spacing - 2 + eye_offset, eye_y_pos - 2, 4, 4), 0, 3.14, 2)
            pygame.draw.arc(screen, pupil_color, (center_x + eye_spacing - 2 + eye_offset, eye_y_pos - 2, 4, 4), 0, 3.14, 2)
        elif expression == "shy":
            # 아래를 보는 눈
            pygame.draw.circle(screen, pupil_color, (center_x - eye_spacing + eye_offset, eye_y_pos + 1), 2)
            pygame.draw.circle(screen, pupil_color, (center_x + eye_spacing + eye_offset, eye_y_pos + 1), 2)
        else:
            # 일반 눈동자
            pygame.draw.circle(screen, pupil_color, (center_x - eye_spacing + eye_offset + pupil_offset_x, eye_y_pos), 2)
            pygame.draw.circle(screen, pupil_color, (center_x + eye_spacing + eye_offset + pupil_offset_x, eye_y_pos), 2)
            # 눈 하이라이트
            pygame.draw.circle(screen, (255, 255, 255), (center_x - eye_spacing + eye_offset + pupil_offset_x, eye_y_pos - 1), 1)
            pygame.draw.circle(screen, (255, 255, 255), (center_x + eye_spacing + 1 + eye_offset + pupil_offset_x, eye_y_pos - 1), 1)

        # === 눈썹 (표정에 따라 다름) ===
        brow_y = eye_y_pos - 4
        brow_color = tuple(max(0, c - 20) for c in hair_color)

        if expression == "serious":
            pygame.draw.line(screen, brow_color, (center_x - eye_spacing - 2 + eye_offset, brow_y + 1), (center_x - eye_spacing + 2 + eye_offset, brow_y - 1), 1)
            pygame.draw.line(screen, brow_color, (center_x + eye_spacing - 1 + eye_offset, brow_y - 1), (center_x + eye_spacing + 3 + eye_offset, brow_y + 1), 1)
        elif expression == "happy" or expression == "cheerful":
            pygame.draw.line(screen, brow_color, (center_x - eye_spacing - 2 + eye_offset, brow_y), (center_x - eye_spacing + 2 + eye_offset, brow_y - 2), 1)
            pygame.draw.line(screen, brow_color, (center_x + eye_spacing - 1 + eye_offset, brow_y - 2), (center_x + eye_spacing + 3 + eye_offset, brow_y), 1)
        else:
            pygame.draw.line(screen, brow_color, (center_x - eye_spacing - 2 + eye_offset, brow_y), (center_x - eye_spacing + 2 + eye_offset, brow_y - 1), 1)
            pygame.draw.line(screen, brow_color, (center_x + eye_spacing - 1 + eye_offset, brow_y - 1), (center_x + eye_spacing + 3 + eye_offset, brow_y), 1)

        # === 코 (다양한 모양) ===
        nose_types = ["small", "normal", "pointed"]
        nose_type = nose_types[(npc_id // 5) % len(nose_types)]
        nose_y = eye_y_pos + 3

        if nose_type == "small":
            pygame.draw.circle(screen, skin_dark, (center_x, nose_y + 1), 1)
        elif nose_type == "pointed":
            pygame.draw.polygon(screen, skin_dark, [(center_x, nose_y - 1), (center_x - 2, nose_y + 3), (center_x + 2, nose_y + 3)])
        else:
            pygame.draw.line(screen, skin_dark, (center_x, nose_y), (center_x, nose_y + 2), 1)

        # === 입 (표정에 따라 다름) ===
        mouth_y = head_y + head_h - 4

        if self.is_talking:
            mouth_open = int(2 * abs(math.sin(animation_timer * 6)))
            pygame.draw.ellipse(screen, (180, 80, 80), (center_x - 2, mouth_y, 4, 2 + mouth_open))
        elif expression == "happy" or expression == "cheerful":
            pygame.draw.arc(screen, (180, 80, 80), (center_x - 4, mouth_y - 2, 8, 5), 3.14, 0, 2)
        elif expression == "serious":
            pygame.draw.line(screen, (150, 80, 80), (center_x - 3, mouth_y), (center_x + 3, mouth_y), 1)
        elif expression == "shy":
            pygame.draw.arc(screen, (180, 100, 100), (center_x - 2, mouth_y - 1, 4, 3), 3.14, 0, 1)
        else:
            pygame.draw.arc(screen, (180, 100, 100), (center_x - 3, mouth_y - 2, 6, 4), 3.14, 0, 1)

        # === 메인 NPC 왕관/모자 ===
        if self.role == "main":
            crown_y = head_y - 6
            pygame.draw.rect(screen, (255, 215, 0), (center_x - 7, crown_y + 4, 14, 4), border_radius=1)
            crown_points = [
                (center_x - 7, crown_y + 4), (center_x - 5, crown_y), (center_x - 2, crown_y + 3),
                (center_x, crown_y - 2), (center_x + 2, crown_y + 3), (center_x + 5, crown_y), (center_x + 7, crown_y + 4),
            ]
            pygame.draw.polygon(screen, (255, 215, 0), crown_points)
            pygame.draw.polygon(screen, (200, 160, 0), crown_points, 1)
            pygame.draw.circle(screen, (255, 50, 50), (center_x, crown_y + 2), 2)
            pygame.draw.circle(screen, (50, 150, 255), (center_x - 4, crown_y + 3), 1)
            pygame.draw.circle(screen, (50, 150, 255), (center_x + 4, crown_y + 3), 1)

        # === 스태프 앞치마/유니폼 표시 ===
        if self.role == "staff":
            apron_color = (240, 240, 230)
            pygame.draw.rect(screen, apron_color, (torso_x + 2, torso_y + 4, torso_w - 4, torso_h - 2), border_radius=2)
            pygame.draw.rect(screen, (200, 200, 190), (torso_x + 2, torso_y + 4, torso_w - 4, torso_h - 2), 1, border_radius=2)

        # === 아이들 동작 이펙트 ===
        if self.idle_action == "look_around":
            mark_x = center_x + head_w // 2 + 5
            mark_y = head_y - 5
            pygame.draw.circle(screen, (255, 255, 200), (mark_x, mark_y + 5), 7)
            pygame.draw.circle(screen, (255, 220, 100), (mark_x, mark_y + 5), 5)
            pygame.draw.rect(screen, (80, 60, 40), (mark_x - 1, mark_y + 2, 2, 4))
            pygame.draw.circle(screen, (80, 60, 40), (mark_x, mark_y + 8), 1)
        elif self.idle_action == "think":
            bubble_x = center_x + head_w // 2 + 3
            bubble_y = head_y - 8
            pygame.draw.circle(screen, (255, 255, 255), (bubble_x, bubble_y + 12), 2)
            pygame.draw.circle(screen, (255, 255, 255), (bubble_x + 4, bubble_y + 8), 3)
            pygame.draw.circle(screen, (255, 255, 255), (bubble_x + 8, bubble_y + 2), 5)
            pygame.draw.circle(screen, (230, 230, 230), (bubble_x + 8, bubble_y + 2), 5, 1)

    def _draw_robot(self, screen, draw_x, draw_y, animation_timer):
        """은행 로봇 NPC 그리기 - sci-fi 스타일 로봇"""
        npc_id = hash(self.name)
        is_main = self.role == "main"

        # 메인 NPC는 더 크고 특별한 색상
        scale = 1.2 if is_main else 1.0

        # 로봇 색상 팔레트
        if is_main:
            # 메인 NPC: 프리미엄 골드/화이트 색상
            METAL_GRAY = (200, 205, 215)
            METAL_DARK = (150, 160, 175)
            METAL_LIGHT = (235, 240, 250)
            led_color = (255, 200, 80)  # 골드 LED
            ACCENT_COLOR = (80, 180, 255)  # 시안 액센트
        else:
            METAL_GRAY = (140, 150, 165)
            METAL_DARK = (90, 100, 115)
            METAL_LIGHT = (180, 190, 205)
            led_colors = [(100, 255, 150), (100, 180, 255), (100, 200, 255)]
            led_color = led_colors[npc_id % len(led_colors)]
            ACCENT_COLOR = led_color

        # 애니메이션 (살짝 위아래 움직임)
        hover_offset = int(2 * math.sin(animation_timer * 2 + npc_id))

        # 위치 계산 (발 위치 기준)
        center_x = int(draw_x)
        feet_y = int(draw_y) + hover_offset

        # === 그림자 (타원형, 반투명) ===
        shadow_w = int((self.width + 10) * scale)
        shadow_h = int(6 * scale)
        shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 50), (0, 0, shadow_w, shadow_h))
        screen.blit(shadow_surf, (center_x - shadow_w // 2, feet_y - 3 - hover_offset))

        # === 로봇 발/바퀴 ===
        wheel_w, wheel_h = int(16 * scale), int(8 * scale)
        pygame.draw.ellipse(screen, METAL_DARK, (center_x - wheel_w // 2, feet_y - wheel_h, wheel_w, wheel_h))
        pygame.draw.ellipse(screen, METAL_GRAY, (center_x - wheel_w // 2, feet_y - wheel_h, wheel_w, wheel_h), 2)
        pygame.draw.ellipse(screen, led_color, (center_x - wheel_w // 2 + 2, feet_y - wheel_h + 2, wheel_w - 4, wheel_h - 4), 1)

        # === 로봇 다리 (기둥) ===
        leg_w, leg_h = int(8 * scale), int(16 * scale)
        leg_y = feet_y - wheel_h - leg_h
        pygame.draw.rect(screen, METAL_DARK, (center_x - leg_w // 2, leg_y, leg_w, leg_h), border_radius=2)
        pygame.draw.rect(screen, METAL_GRAY, (center_x - leg_w // 2, leg_y, leg_w, leg_h), 1, border_radius=2)
        pygame.draw.line(screen, led_color, (center_x - leg_w // 2 + 1, leg_y + leg_h // 2), (center_x + leg_w // 2 - 1, leg_y + leg_h // 2), 1)

        # === 로봇 몸통 ===
        torso_w, torso_h = int((self.width + 4) * scale), int(22 * scale)
        torso_y = leg_y - torso_h + 2
        torso_x = center_x - torso_w // 2

        pygame.draw.rect(screen, METAL_GRAY, (torso_x, torso_y, torso_w, torso_h), border_radius=5)
        pygame.draw.rect(screen, METAL_LIGHT, (torso_x, torso_y, torso_w, torso_h), 2, border_radius=5)

        # 메인 NPC: 가슴에 뱃지/엠블럼
        if is_main:
            badge_x = center_x
            badge_y = torso_y + torso_h // 2
            # 별 모양 뱃지
            pygame.draw.circle(screen, (40, 60, 90), (badge_x, badge_y), 8)
            pygame.draw.circle(screen, led_color, (badge_x, badge_y), 6)
            # 작은 별
            for i in range(5):
                angle = -math.pi / 2 + (i * 2 * math.pi / 5)
                px = badge_x + int(4 * math.cos(angle))
                py = badge_y + int(4 * math.sin(angle))
                pygame.draw.circle(screen, (255, 255, 255), (px, py), 1)
        else:
            # 일반 로봇: LED 패널
            panel_w, panel_h = torso_w - 8, 10
            panel_x = torso_x + 4
            panel_y = torso_y + 5
            pygame.draw.rect(screen, METAL_DARK, (panel_x, panel_y, panel_w, panel_h), border_radius=2)
            led_blink = int(animation_timer * 3) % 3
            for i in range(3):
                led_x = panel_x + 3 + i * 6
                if i == led_blink:
                    pygame.draw.circle(screen, led_color, (led_x + 2, panel_y + panel_h // 2), 3)
                else:
                    pygame.draw.circle(screen, (50, 60, 70), (led_x + 2, panel_y + panel_h // 2), 2)

        # === 로봇 팔 ===
        arm_w, arm_h = int(6 * scale), int(14 * scale)
        arm_y = torso_y + 4
        arm_swing = int(2 * math.sin(animation_timer * 1.5 + npc_id))

        pygame.draw.rect(screen, METAL_DARK, (torso_x - arm_w + 2, arm_y + arm_swing, arm_w, arm_h), border_radius=2)
        pygame.draw.rect(screen, METAL_GRAY, (torso_x - arm_w + 2, arm_y + arm_swing, arm_w, arm_h), 1, border_radius=2)
        pygame.draw.ellipse(screen, METAL_LIGHT, (torso_x - arm_w + 3, arm_y + arm_h - 2 + arm_swing, 4, 4))

        pygame.draw.rect(screen, METAL_DARK, (torso_x + torso_w - 2, arm_y - arm_swing, arm_w, arm_h), border_radius=2)
        pygame.draw.rect(screen, METAL_GRAY, (torso_x + torso_w - 2, arm_y - arm_swing, arm_w, arm_h), 1, border_radius=2)
        pygame.draw.ellipse(screen, METAL_LIGHT, (torso_x + torso_w - 1, arm_y + arm_h - 2 - arm_swing, 4, 4))

        # === 로봇 목 ===
        neck_w, neck_h = int(6 * scale), int(5 * scale)
        neck_y = torso_y - neck_h + 2
        pygame.draw.rect(screen, METAL_DARK, (center_x - neck_w // 2, neck_y, neck_w, neck_h + 2))
        pygame.draw.rect(screen, METAL_GRAY, (center_x - neck_w // 2, neck_y, neck_w, neck_h + 2), 1)

        # === 로봇 머리 ===
        head_w, head_h = int(18 * scale), int(16 * scale)
        head_y = neck_y - head_h + 4
        head_x = center_x - head_w // 2

        pygame.draw.rect(screen, METAL_GRAY, (head_x, head_y, head_w, head_h), border_radius=4)
        pygame.draw.rect(screen, METAL_LIGHT, (head_x, head_y, head_w, head_h), 2, border_radius=4)

        # 메인 NPC: 이마에 심볼
        if is_main:
            pygame.draw.rect(screen, led_color, (center_x - 4, head_y + 2, 8, 3), border_radius=1)

        # === 안테나 ===
        antenna_x = center_x
        antenna_y = head_y - int(6 * scale)
        pygame.draw.line(screen, METAL_DARK, (antenna_x, head_y), (antenna_x, antenna_y), 2)

        # 메인 NPC: 더 큰 안테나 글로우
        glow_pulse = int(180 + 75 * math.sin(animation_timer * 4 + npc_id))
        ant_size = 5 if is_main else 4
        pygame.draw.circle(screen, led_color, (antenna_x, antenna_y), ant_size)
        glow_r = 8 if is_main else 6
        glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*led_color, glow_pulse // 2), (glow_r, glow_r), glow_r)
        screen.blit(glow_surf, (antenna_x - glow_r, antenna_y - glow_r))

        # === 로봇 눈 (LED 바이저) ===
        visor_y = head_y + int(5 * scale)
        visor_w, visor_h = head_w - 4, int(6 * scale)
        visor_x = head_x + 2

        pygame.draw.rect(screen, (20, 30, 40), (visor_x, visor_y, visor_w, visor_h), border_radius=2)
        pygame.draw.rect(screen, METAL_DARK, (visor_x, visor_y, visor_w, visor_h), 1, border_radius=2)

        eye_offset = int(2 * math.sin(animation_timer * 2))
        eye_y = visor_y + visor_h // 2
        eye_size = 3 if is_main else 2

        pygame.draw.circle(screen, led_color, (visor_x + 4 + eye_offset, eye_y), eye_size)
        pygame.draw.circle(screen, led_color, (visor_x + visor_w - 4 + eye_offset, eye_y), eye_size)

        # 눈 글로우 효과
        glow_size = (5 if is_main else 4) + int(math.sin(animation_timer * 3) * 1)
        glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*led_color, 80), (glow_size, glow_size), glow_size)
        screen.blit(glow_surf, (visor_x + 4 + eye_offset - glow_size, eye_y - glow_size))
        screen.blit(glow_surf, (visor_x + visor_w - 4 + eye_offset - glow_size, eye_y - glow_size))

        # === 입 (LED 바) ===
        mouth_y = head_y + head_h - int(5 * scale)
        mouth_w = int(8 * scale)
        mouth_x = center_x - mouth_w // 2

        if self.is_talking:
            mouth_h = 2 + int(abs(math.sin(animation_timer * 8)) * 2)
            pygame.draw.rect(screen, led_color, (mouth_x, mouth_y, mouth_w, mouth_h), border_radius=1)
        else:
            pygame.draw.rect(screen, METAL_DARK, (mouth_x, mouth_y, mouth_w, 2), border_radius=1)
            pygame.draw.line(screen, led_color, (mouth_x + 1, mouth_y + 1), (mouth_x + mouth_w - 1, mouth_y + 1), 1)

        # === 메인 NPC 표시: 머리 위 타이틀 마커 ===
        if is_main:
            marker_y = antenna_y - 12
            # 아래쪽 화살표 + 글로우
            glow_alpha = int(150 + 80 * math.sin(animation_timer * 3))
            marker_surf = pygame.Surface((20, 12), pygame.SRCALPHA)
            pygame.draw.polygon(marker_surf, (*led_color, glow_alpha), [
                (10, 10), (4, 2), (16, 2)
            ])
            screen.blit(marker_surf, (center_x - 10, marker_y))

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
        pygame.draw.rect(screen, self.accent_color, bubble_rect, 2, border_radius=8)

        # 말풍선 꼬리
        tail_points = [
            (draw_x - 8, bubble_y + bubble_h),
            (draw_x + 8, bubble_y + bubble_h),
            (draw_x, bubble_y + bubble_h + 10)
        ]
        pygame.draw.polygon(screen, (40, 40, 50), tail_points)
        pygame.draw.line(screen, self.accent_color, tail_points[0], tail_points[2], 2)
        pygame.draw.line(screen, self.accent_color, tail_points[1], tail_points[2], 2)

        # 텍스트
        screen.blit(text_surf, (bubble_x + 10, bubble_y + 8))

        # 이름 (작게)
        name_surf, name_rect = font.render(self.name, self.accent_color)
        name_x = bubble_x + bubble_w - name_rect.width - 5
        name_y = bubble_y - name_rect.height - 2

        # 이름 배경
        name_bg = pygame.Rect(name_x - 3, name_y - 2, name_rect.width + 6, name_rect.height + 4)
        pygame.draw.rect(screen, (30, 30, 40), name_bg, border_radius=3)
        screen.blit(name_surf, (name_x, name_y))


# =============================================================================
# 건물 내부 인테리어 플레이어 (광장 플레이어와 동일한 스타일)
# =============================================================================
class InteriorPlayer:
    """건물 내부에서 이동하는 플레이어 (광장과 동일한 크기/스프라이트)"""

    def __init__(self, x, y, sprite=None):
        self.x = float(x)
        self.y = float(y)
        self.width = PLAYER_SIZE  # 광장과 동일한 크기
        self.height = PLAYER_SIZE
        self.speed = PLAYER_SPEED  # 광장과 동일한 속도

        self.velocity_x = 0
        self.velocity_y = 0
        self.is_moving = False

        # 방향 (0: 하, 1: 좌, 2: 우, 3: 상) - 입장 시 위쪽을 바라봄
        self.direction = 3

        # 애니메이션
        self.animation_frame = 0
        self.animation_timer = 0

        # 스프라이트 (광장에서 사용하던 것 그대로 사용 - 스케일 안 함)
        self.sprite = sprite
        self.sprite_flipped = None
        if self.sprite:
            # 스프라이트를 복사해서 사용 (원본 손상 방지)
            self.sprite = self.sprite.copy()
            self.sprite_flipped = pygame.transform.flip(self.sprite, True, False)
            self.width = self.sprite.get_width()
            self.height = self.sprite.get_height()

        # 한글 키보드 지원 (광장 플레이어와 동일)
        self.pressed_keys = set()
        self._scancode_map = {}

        # 이동키 매핑 (WASD + 화살표)
        self._movement_keys = {
            pygame.K_a, pygame.K_s, pygame.K_d, pygame.K_w,
            pygame.K_LEFT, pygame.K_RIGHT, pygame.K_UP, pygame.K_DOWN
        }
        self._unicode_movement_map = {
            'ㅁ': pygame.K_a,  # A 키 위치
            'ㄴ': pygame.K_s,  # S 키 위치
            'ㅇ': pygame.K_d,  # D 키 위치
            'ㅈ': pygame.K_w   # W 키 위치
        }
        # 화살표 키 → WASD 매핑
        self._arrow_to_wasd = {
            pygame.K_LEFT: pygame.K_a,
            pygame.K_RIGHT: pygame.K_d,
            pygame.K_UP: pygame.K_w,
            pygame.K_DOWN: pygame.K_s
        }
        self._movement_scancode_map = self._build_movement_scancode_map()

    def _build_movement_scancode_map(self):
        """키보드 레이아웃과 무관한 물리 스캔코드 → pygame 키 매핑"""
        fallback_scancodes = {
            'SCANCODE_A': 4, 'SCANCODE_S': 22,
            'SCANCODE_D': 7, 'SCANCODE_W': 26,
        }
        scancode_map = {}
        for attr, keycode in [
            ("SCANCODE_A", pygame.K_a), ("SCANCODE_S", pygame.K_s),
            ("SCANCODE_D", pygame.K_d), ("SCANCODE_W", pygame.K_w),
        ]:
            sc_value = getattr(pygame, attr, fallback_scancodes.get(attr))
            if sc_value:
                scancode_map[sc_value] = keycode
        return scancode_map

    def handle_movement_key_event(self, pressed, scancode=None, keycode=None, unicode_char=None):
        """레이아웃 상관없이 이동키 입력을 처리 (광장 플레이어와 동일)"""
        target_key = None

        # 1) 물리 스캔코드 우선
        if scancode is not None and scancode in self._movement_scancode_map:
            target_key = self._movement_scancode_map[scancode]

        # 2) 유니코드 문자 매핑 (한글)
        if target_key is None and unicode_char:
            target_key = self._unicode_movement_map.get(unicode_char)

        # 3) 화살표 키 → WASD 변환
        if target_key is None and keycode in self._arrow_to_wasd:
            target_key = self._arrow_to_wasd[keycode]

        # 4) WASD 키코드 직접 매핑
        if target_key is None and keycode in {pygame.K_a, pygame.K_s, pygame.K_d, pygame.K_w}:
            target_key = keycode

        if target_key is None:
            return

        if pressed:
            self.pressed_keys.add(target_key)
            if scancode is not None:
                self._scancode_map[scancode] = target_key
        else:
            self.pressed_keys.discard(target_key)
            if scancode is not None:
                self._scancode_map.pop(scancode, None)

    def handle_input(self, keys, dt):
        """입력 처리 (광장 플레이어와 동일한 방식)"""
        self.velocity_x = 0
        self.velocity_y = 0

        # WASD 및 화살표 키 + 한글 키보드
        is_left = keys[pygame.K_LEFT] or keys[pygame.K_a] or (pygame.K_a in self.pressed_keys)
        is_right = keys[pygame.K_RIGHT] or keys[pygame.K_d] or (pygame.K_d in self.pressed_keys)
        is_up = keys[pygame.K_UP] or keys[pygame.K_w] or (pygame.K_w in self.pressed_keys)
        is_down = keys[pygame.K_DOWN] or keys[pygame.K_s] or (pygame.K_s in self.pressed_keys)

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
        "name": "STARBANK",
        "map_size": (14, 10),
        "bg_color": (20, 30, 45),  # 어두운 네이비
        "floor_color": (35, 50, 70),  # 청회색 바닥
        "floor_pattern": "bank_tile",  # 은행 전용 타일 패턴
        "wall_color": (25, 38, 55),
        "accent_color": (80, 180, 255),  # 시안 네온
        "secondary_color": (60, 80, 110),  # 금속 회색
        "decorations": [],  # 커스텀 인테리어 사용
        "main_npc": {
            "name": "로봇지점장",
            "color": (140, 155, 175),  # 로봇 회색
            "position": (0.5, 0.32),  # 카운터 뒤
            "dialogue": [
                "STARBANK에 오신 것을 환영합니다.",
                "무엇을 도와드릴까요?",
                "안전한 거래를 약속드립니다."
            ]
        },
        "customer_range": (0, 0),  # 고객 없음
        "staff_count": 0,  # 메인 NPC만 (로봇지점장)
        "special_interior": "bank",  # 특수 인테리어 플래그
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
    """건물 내부 - 광장 확장 스타일 (광장과 동일한 타일/스프라이트 크기)"""

    # 광장과 동일한 타일 크기 사용 (constants.py의 TILE_SIZE = 40)

    def __init__(self, building_type, freetype_fonts, player_sprite=None,
                 player_data=None, academy=None, ap_system=None):
        self.building_type = building_type
        self.fonts = freetype_fonts
        self.animation_timer = 0

        # 광장 UI 표시용 데이터
        self.player_data = player_data or {'gold': 0, 'star_points': 0}
        self.academy = academy
        self.ap_system = ap_system

        # 건물별 설정
        self.config = INTERIOR_CONFIGS.get(building_type, DEFAULT_INTERIOR_CONFIG)

        # 맵 크기
        self.map_width, self.map_height = self.config["map_size"]
        self.pixel_width = self.map_width * TILE_SIZE
        self.pixel_height = self.map_height * TILE_SIZE

        # 문 위치 (맵 하단 중앙)
        self.door_rect = pygame.Rect(
            (self.pixel_width - 64) // 2,
            self.pixel_height - 48,
            64, 48
        )

        # 내부 영역 (벽 제외한 이동 가능 구역)
        self.walkable_rect = pygame.Rect(
            TILE_SIZE,  # 왼쪽 벽
            TILE_SIZE * 2,  # 위쪽 벽 (이름/카운터 공간)
            self.pixel_width - TILE_SIZE * 2,  # 양쪽 벽 제외
            self.pixel_height - TILE_SIZE * 3  # 위아래 벽 제외
        )

        # 플레이어 시작 위치 (문 바로 앞, 안전 구역)
        self.spawn_x = self.pixel_width // 2
        self.spawn_y = self.pixel_height - TILE_SIZE * 2  # 문 근처 (나중에 이동 가능)
        self.player = InteriorPlayer(self.spawn_x, self.spawn_y, player_sprite)

        # 카메라 오프셋 (화면 중앙 정렬)
        self.camera_offset = (0, 0)
        self._update_camera()

        # NPC들 생성 (플레이어 위치 피해서)
        self.npcs = self._create_npcs()

        # 장식물 생성
        self.decorations = self._create_decorations()

        # 은행 카운터 충돌 영역 (BANK에서만 사용, draw에서 설정됨)
        self.bank_counter_rect = None

        # 환율 시스템 (STARBANK 전용)
        # 기본 환율: 1 스타포인트 = 500 골드
        # 일일 변동: -15% ~ +15%
        self.base_exchange_rate = 500
        self.exchange_rate_variance = random.uniform(-0.15, 0.15)  # -15% ~ +15%
        self.current_exchange_rate = int(self.base_exchange_rate * (1 + self.exchange_rate_variance))

        # 예금 이자율 시스템 (STARBANK 전용)
        # 일일 이자율: 5% ~ 20% 랜덤
        self.deposit_interest_rate = random.uniform(0.05, 0.20)  # 5% ~ 20%

        # 나가기 상태
        self.exit_requested = False
        self.exit_timer = 0
        self.entry_cooldown = 1.0  # 입장 후 1초간 나가기 방지

        # 은행 메뉴 상태 (STARBANK 전용)
        self.bank_menu_open = False
        self.bank_menu_selection = 0  # 0: 환전, 1: 예금, 2: 나가기
        self.bank_menu_items = ["환전", "예금", "나가기"]

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

        # 랜덤 고객 NPC (1~2명으로 제한 - 건물 내부가 붐비지 않게)
        # 기존 config의 customer_range 무시하고 1~2명으로 고정
        customer_count = random.randint(1, 2)

        customer_colors = [
            (100, 150, 200), (200, 150, 100), (150, 200, 100),
            (200, 100, 150), (150, 100, 200), (100, 200, 150),
            (180, 180, 100), (100, 180, 180)
        ]

        for i in range(customer_count):
            # 랜덤 위치 (walkable 영역 내, 하단 1/3 제외 - 플레이어 안전 구역)
            x = random.randint(
                self.walkable_rect.left + 30,
                self.walkable_rect.right - 30
            )
            # 하단 영역을 피해서 배치 (플레이어 시작 위치 근처 피함)
            y = random.randint(
                self.walkable_rect.top + 30,
                self.walkable_rect.top + (self.walkable_rect.height * 2 // 3)  # 상위 2/3 영역만
            )

            # 메인 NPC와 너무 가까우면 재배치
            attempts = 0
            while (abs(x - main_x) < 60 and abs(y - main_y) < 60) and attempts < 10:
                x = random.randint(self.walkable_rect.left + 30, self.walkable_rect.right - 30)
                y = random.randint(self.walkable_rect.top + 30, self.walkable_rect.top + (self.walkable_rect.height * 2 // 3))
                attempts += 1

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
        # 플레이어 발 위치 기준 충돌 박스 (더 작게)
        half_w = 15
        half_h = 10

        player_rect = pygame.Rect(
            x - half_w, y - half_h,
            half_w * 2, half_h * 2
        )

        # 이동 가능 영역 체크 (colliderect 사용 - contains보다 관대함)
        # 맵 경계 내에 있는지만 확인
        map_bounds = pygame.Rect(
            TILE_SIZE,  # 왼쪽 벽
            TILE_SIZE,  # 위쪽 (더 관대하게)
            self.pixel_width - TILE_SIZE * 2,
            self.pixel_height - TILE_SIZE  # 아래쪽도 관대하게
        )

        if not map_bounds.colliderect(player_rect):
            # 문 영역 예외 (나갈 수 있음)
            if self.door_rect.colliderect(player_rect):
                return True
            return False

        # NPC와 충돌 체크 (작은 충돌 박스 사용)
        # 현재 위치에서 이미 NPC와 겹쳐있으면 빠져나가기 허용
        current_rect = pygame.Rect(
            self.player.x - half_w, self.player.y - half_h,
            half_w * 2, half_h * 2
        )

        for npc in self.npcs:
            # NPC 충돌 박스를 작게 (중심 10픽셀만)
            npc_rect = pygame.Rect(
                npc.x - 10, npc.y - 10,
                20, 20
            )

            # 현재 이미 겹쳐있으면 이동 허용 (빠져나갈 수 있도록)
            if current_rect.colliderect(npc_rect):
                continue

            if player_rect.colliderect(npc_rect):
                return False

        # 장식물과 충돌 체크
        for deco in self.decorations:
            deco_rect = pygame.Rect(deco["x"], deco["y"], *deco["size"])
            if player_rect.colliderect(deco_rect):
                return False

        # 은행 카운터 충돌 체크 (BANK 전용)
        if hasattr(self, 'bank_counter_rect') and self.bank_counter_rect:
            if player_rect.colliderect(self.bank_counter_rect):
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

        # 입장 쿨다운 감소
        if self.entry_cooldown > 0:
            self.entry_cooldown -= dt

        # 은행 메뉴가 열려있으면 플레이어 입력 차단
        if self.bank_menu_open:
            return

        # 플레이어 업데이트
        keys = pygame.key.get_pressed()
        self.player.handle_input(keys, dt)
        self.player.update(dt, self)

        # 카메라 업데이트
        self._update_camera()

        # NPC 업데이트 (걸어다니기용 walkable_rect 전달)
        for npc in self.npcs:
            npc.update(dt, self.walkable_rect)

        # 문 근처에서 나가기 체크 (입장 쿨다운 후에만)
        if self.entry_cooldown <= 0:
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
        # 은행 메뉴가 열려있으면 메뉴 클릭 처리
        if self.bank_menu_open:
            return self._handle_bank_menu_click(pos)

        # 화면 좌표를 월드 좌표로 변환
        world_x = pos[0] + self.camera_offset[0]
        world_y = pos[1] + self.camera_offset[1]

        # NPC 클릭 체크
        for npc in self.npcs:
            npc_rect = npc.get_rect()
            if npc_rect.collidepoint(world_x, world_y):
                # 은행 메인 NPC인 경우 메뉴 열기
                if self.building_type == BuildingType.BANK and npc.role == "main":
                    self.bank_menu_open = True
                    self.bank_menu_selection = 0
                    return ("bank_menu", npc)
                else:
                    dialogue = npc.start_dialogue()
                    if dialogue:
                        return ("talk", npc)

        return None

    def handle_key(self, event):
        """키 입력 처리 (이벤트 기반)"""
        if event.type != pygame.KEYDOWN:
            return None

        # 은행 메뉴가 열려있을 때
        if self.bank_menu_open:
            if event.key == pygame.K_UP or event.key == pygame.K_w:
                self.bank_menu_selection = (self.bank_menu_selection - 1) % len(self.bank_menu_items)
                return ("menu_move", None)
            elif event.key == pygame.K_DOWN or event.key == pygame.K_s:
                self.bank_menu_selection = (self.bank_menu_selection + 1) % len(self.bank_menu_items)
                return ("menu_move", None)
            elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                return self._select_bank_menu_item()
            elif event.key == pygame.K_ESCAPE:
                self.bank_menu_open = False
                return ("menu_close", None)
            return None

        # 메뉴가 닫혀있을 때 - Space로 NPC 상호작용
        if event.key == pygame.K_SPACE:
            return self._try_interact_with_npc()

        return None

    def _try_interact_with_npc(self):
        """플레이어 근처 NPC와 상호작용 시도"""
        player_rect = pygame.Rect(
            self.player.x - 40, self.player.y - 40, 80, 80
        )

        for npc in self.npcs:
            npc_rect = npc.get_rect()
            if player_rect.colliderect(npc_rect):
                # 은행 메인 NPC인 경우 메뉴 열기
                if self.building_type == BuildingType.BANK and npc.role == "main":
                    self.bank_menu_open = True
                    self.bank_menu_selection = 0
                    return ("bank_menu", npc)
                else:
                    dialogue = npc.start_dialogue()
                    if dialogue:
                        return ("talk", npc)

        return None

    def _handle_bank_menu_click(self, pos):
        """은행 메뉴 클릭 처리"""
        # 메뉴 영역 계산 (화면 중앙)
        menu_w, menu_h = 200, 160
        menu_x = (SCREEN_WIDTH - menu_w) // 2
        menu_y = (SCREEN_HEIGHT - menu_h) // 2

        # 메뉴 아이템 클릭 체크
        item_h = 32
        item_start_y = menu_y + 50

        for i, item in enumerate(self.bank_menu_items):
            item_rect = pygame.Rect(menu_x + 20, item_start_y + i * item_h, menu_w - 40, item_h - 4)
            if item_rect.collidepoint(pos):
                self.bank_menu_selection = i
                return self._select_bank_menu_item()

        # 메뉴 바깥 클릭시 닫기
        menu_rect = pygame.Rect(menu_x, menu_y, menu_w, menu_h)
        if not menu_rect.collidepoint(pos):
            self.bank_menu_open = False
            return ("menu_close", None)

        return None

    def _select_bank_menu_item(self):
        """은행 메뉴 아이템 선택"""
        selected = self.bank_menu_items[self.bank_menu_selection]

        if selected == "환전":
            self.bank_menu_open = False
            return ("bank_exchange", None)
        elif selected == "예금":
            self.bank_menu_open = False
            return ("bank_deposit", None)
        elif selected == "나가기":
            self.bank_menu_open = False
            return ("menu_close", None)

        return None

    def draw(self, screen):
        """건물 내부 그리기"""
        # 특수 인테리어 체크
        special_interior = self.config.get("special_interior")

        if special_interior == "bank":
            # 은행 전용 인테리어
            self._draw_bank_interior(screen)
        else:
            # 기본 인테리어
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

        # 은행 메뉴 (맨 위에)
        if self.bank_menu_open:
            self._draw_bank_menu(screen)

    def _draw_bank_menu(self, screen):
        """은행 메뉴창 그리기 - SF 스타일"""
        import math

        # 메뉴 크기 및 위치 (화면 중앙)
        menu_w, menu_h = 220, 180
        menu_x = (SCREEN_WIDTH - menu_w) // 2
        menu_y = (SCREEN_HEIGHT - menu_h) // 2

        # 색상
        BG_DARK = (15, 22, 35)
        BORDER_CYAN = (70, 180, 255)
        BORDER_GLOW = (50, 120, 180)
        HIGHLIGHT = (40, 60, 90)
        TEXT_WHITE = (240, 245, 255)
        TEXT_CYAN = (100, 200, 255)
        TEXT_GOLD = (255, 210, 100)

        # 배경 어둡게 (반투명 오버레이)
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 150))
        screen.blit(overlay, (0, 0))

        # 글로우 효과
        glow_intensity = int(20 + 10 * math.sin(self.animation_timer * 3))
        glow_surf = pygame.Surface((menu_w + 20, menu_h + 20), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*BORDER_CYAN, glow_intensity), (0, 0, menu_w + 20, menu_h + 20), border_radius=12)
        screen.blit(glow_surf, (menu_x - 10, menu_y - 10))

        # 메뉴 배경
        pygame.draw.rect(screen, BG_DARK, (menu_x, menu_y, menu_w, menu_h), border_radius=8)
        pygame.draw.rect(screen, BORDER_CYAN, (menu_x, menu_y, menu_w, menu_h), 2, border_radius=8)

        # 상단 바
        pygame.draw.rect(screen, (25, 35, 55), (menu_x + 2, menu_y + 2, menu_w - 4, 36), border_radius=6)
        pygame.draw.line(screen, BORDER_GLOW, (menu_x + 10, menu_y + 40), (menu_x + menu_w - 10, menu_y + 40), 1)

        font_small = self.fonts.get('small')
        font_medium = self.fonts.get('medium')

        # 타이틀
        if font_medium:
            title_surf, title_rect = font_medium.render("무엇을 도와드릴까요?", TEXT_WHITE)
            screen.blit(title_surf, (menu_x + menu_w // 2 - title_rect.width // 2, menu_y + 10))

        # 메뉴 아이템
        item_h = 36
        item_start_y = menu_y + 52

        for i, item in enumerate(self.bank_menu_items):
            item_y = item_start_y + i * item_h
            item_rect = pygame.Rect(menu_x + 15, item_y, menu_w - 30, item_h - 4)

            # 선택된 아이템 하이라이트
            if i == self.bank_menu_selection:
                # 선택 배경
                pygame.draw.rect(screen, HIGHLIGHT, item_rect, border_radius=4)
                pygame.draw.rect(screen, BORDER_CYAN, item_rect, 2, border_radius=4)

                # 선택 표시 (▶)
                if font_small:
                    arrow_surf, _ = font_small.render("▶", TEXT_CYAN)
                    screen.blit(arrow_surf, (item_rect.x + 8, item_rect.y + 8))

                text_color = TEXT_CYAN
            else:
                # 비선택 배경
                pygame.draw.rect(screen, (25, 35, 50), item_rect, border_radius=4)
                text_color = TEXT_WHITE

            # 아이템 텍스트
            if font_small:
                # 아이콘
                if item == "환전":
                    icon = "💱"
                elif item == "예금":
                    icon = "💰"
                else:
                    icon = "🚪"

                icon_surf, _ = font_small.render(icon, text_color)
                screen.blit(icon_surf, (item_rect.x + 30, item_rect.y + 8))

                item_surf, _ = font_small.render(item, text_color)
                screen.blit(item_surf, (item_rect.x + 55, item_rect.y + 8))

        # 하단 조작 힌트
        hint_y = menu_y + menu_h - 25
        if font_small:
            hint_surf, _ = font_small.render("↑↓ 이동  Space/Enter 선택  ESC 닫기", (100, 120, 150))
            screen.blit(hint_surf, (menu_x + menu_w // 2 - 95, hint_y))

    def _draw_bank_interior(self, screen):
        """스타뱅크 전용 인테리어 - 깔끔한 SF 은행 스타일"""
        import math

        # 색상 팔레트 (미니멀 & 프로페셔널)
        BG_DARK = (18, 25, 38)
        FLOOR_A = (30, 42, 58)
        FLOOR_B = (38, 52, 72)
        WALL_COLOR = (22, 32, 48)
        ACCENT_CYAN = (70, 180, 255)
        ACCENT_CYAN_DIM = (50, 120, 180)
        GOLD = (255, 200, 100)
        WHITE = (240, 245, 250)
        GRAY_LIGHT = (180, 190, 205)
        GRAY_MID = (120, 135, 155)
        GRAY_DARK = (70, 85, 105)

        cam_x, cam_y = self.camera_offset
        cx = self.pixel_width // 2  # 중앙 X

        # 1. 배경
        screen.fill(BG_DARK)

        # 2. 바닥 타일 (깔끔한 격자)
        for ty in range(self.map_height):
            for tx in range(self.map_width):
                tile_x = tx * TILE_SIZE - cam_x
                tile_y = ty * TILE_SIZE - cam_y
                color = FLOOR_A if (tx + ty) % 2 == 0 else FLOOR_B
                pygame.draw.rect(screen, color, (tile_x, tile_y, TILE_SIZE, TILE_SIZE))

        # 3. 상단 벽 (깔끔한 패널)
        wall_h = int(TILE_SIZE * 2.8)
        pygame.draw.rect(screen, WALL_COLOR, (-cam_x, -cam_y, self.pixel_width, wall_h))

        # 벽 하단 라인 (시안 액센트)
        pygame.draw.rect(screen, ACCENT_CYAN_DIM, (-cam_x, -cam_y + wall_h - 3, self.pixel_width, 3))

        # 4. STARBANK 로고 (상단 중앙)
        sign_y = -cam_y + 25
        sign_x = cx - cam_x

        # 로고 배경 패널
        panel_w, panel_h = 160, 36
        pygame.draw.rect(screen, (15, 22, 35), (sign_x - panel_w//2, sign_y - 5, panel_w, panel_h), border_radius=6)
        pygame.draw.rect(screen, ACCENT_CYAN, (sign_x - panel_w//2, sign_y - 5, panel_w, panel_h), 2, border_radius=6)

        # 로고 글로우
        glow_intensity = int(40 + 20 * math.sin(self.animation_timer * 2))
        glow_surf = pygame.Surface((panel_w + 20, panel_h + 20), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*ACCENT_CYAN, glow_intensity), (0, 0, panel_w + 20, panel_h + 20), border_radius=10)
        screen.blit(glow_surf, (sign_x - panel_w//2 - 10, sign_y - 15))

        # 로고 텍스트
        font_large = self.fonts.get('large')
        if font_large:
            text_surf, text_rect = font_large.render("STARBANK", ACCENT_CYAN)
            screen.blit(text_surf, (sign_x - text_rect.width // 2, sign_y + 2))

        # 5. 은행 카운터 (메인 - 플레이어 통과 불가)
        counter_w = self.pixel_width - 100
        counter_h = 40
        counter_x = -cam_x + 50
        counter_y = -cam_y + wall_h + 15

        # 카운터 저장 (충돌 체크용)
        self.bank_counter_rect = pygame.Rect(50, wall_h + 15, counter_w, counter_h)

        # 카운터 그림자
        shadow_surf = pygame.Surface((counter_w + 10, 8), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40), (0, 0, counter_w + 10, 8))
        screen.blit(shadow_surf, (counter_x - 5, counter_y + counter_h))

        # 카운터 본체
        pygame.draw.rect(screen, WHITE, (counter_x, counter_y, counter_w, counter_h), border_radius=4)
        pygame.draw.rect(screen, GRAY_LIGHT, (counter_x, counter_y, counter_w, counter_h), 2, border_radius=4)

        # 카운터 상단 LED 라인
        pygame.draw.rect(screen, ACCENT_CYAN, (counter_x + 2, counter_y + 2, counter_w - 4, 4), border_radius=2)

        # 카운터 중앙 심볼 (별)
        star_cx = counter_x + counter_w // 2
        star_cy = counter_y + counter_h // 2 + 3
        self._draw_star_symbol(screen, star_cx, star_cy, 10, GOLD)

        # 6. 데스크 뒤 로봇 2대 (장식용 - 다른 스타일)
        robot_y = counter_y - 5  # 카운터 바로 위

        # 왼쪽 로봇 (둥근 타입)
        robot1_x = counter_x + counter_w // 3
        self._draw_desk_robot_round(screen, robot1_x, robot_y, self.animation_timer, 0)

        # 오른쪽 로봇 (각진 타입)
        robot2_x = counter_x + counter_w * 2 // 3
        self._draw_desk_robot_angular(screen, robot2_x, robot_y, self.animation_timer, 1)

        # 7. 사이드 전광판 (좌우 벽) - 주식 전광판 스타일
        # 왼쪽: 환율 전광판
        exchange_x = -cam_x + 8
        exchange_y = -cam_y + 15
        self._draw_exchange_rate_board(screen, exchange_x, exchange_y, self.animation_timer)

        # 오른쪽: 예금 이자율 전광판
        interest_x = self.pixel_width - cam_x - 120
        interest_y = -cam_y + 15
        self._draw_interest_rate_board(screen, interest_x, interest_y, self.animation_timer)

        # 8. 바닥 가이드 라인 (미니멀)
        line_y = self.pixel_height - cam_y - 80
        pygame.draw.line(screen, ACCENT_CYAN_DIM, (-cam_x + 60, line_y), (self.pixel_width - cam_x - 60, line_y), 1)

        # 9. 문 그리기
        self._draw_door(screen)

    def _draw_star_symbol(self, screen, cx, cy, size, color):
        """별 심볼 그리기"""
        points = []
        for i in range(10):
            angle = -math.pi / 2 + (i * math.pi / 5)
            r = size if i % 2 == 0 else size * 0.4
            points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
        pygame.draw.polygon(screen, color, points)

    def _draw_desk_robot_round(self, screen, x, y, anim_timer, robot_id):
        """둥근 타입 로봇 (데스크 뒤)"""
        # 색상
        BODY = (160, 175, 195)
        BODY_DARK = (120, 135, 155)
        BODY_LIGHT = (200, 210, 225)
        LED = (100, 220, 180)  # 초록 계열

        hover = int(1.5 * math.sin(anim_timer * 2.5 + robot_id))

        # 몸통 (둥근)
        pygame.draw.ellipse(screen, BODY, (x - 12, y - 28 + hover, 24, 22))
        pygame.draw.ellipse(screen, BODY_LIGHT, (x - 12, y - 28 + hover, 24, 22), 2)

        # 가슴 LED
        led_glow = int(200 + 55 * math.sin(anim_timer * 4))
        pygame.draw.circle(screen, LED, (x, y - 18 + hover), 4)

        # 머리 (구형)
        head_y = y - 38 + hover
        pygame.draw.circle(screen, BODY, (x, head_y), 10)
        pygame.draw.circle(screen, BODY_LIGHT, (x, head_y), 10, 2)

        # 눈 (바이저)
        pygame.draw.rect(screen, (20, 30, 40), (x - 7, head_y - 2, 14, 5), border_radius=2)
        eye_off = int(2 * math.sin(anim_timer * 1.5))
        pygame.draw.circle(screen, LED, (x - 3 + eye_off, head_y), 2)
        pygame.draw.circle(screen, LED, (x + 3 + eye_off, head_y), 2)

        # 안테나
        pygame.draw.line(screen, BODY_DARK, (x, head_y - 10), (x, head_y - 16), 2)
        pygame.draw.circle(screen, LED, (x, head_y - 17), 3)

    def _draw_desk_robot_angular(self, screen, x, y, anim_timer, robot_id):
        """각진 타입 로봇 (데스크 뒤)"""
        # 색상
        BODY = (140, 150, 170)
        BODY_DARK = (100, 110, 130)
        BODY_LIGHT = (180, 190, 210)
        LED = (255, 180, 80)  # 오렌지 계열

        hover = int(1.5 * math.sin(anim_timer * 2.5 + robot_id + 1))

        # 몸통 (각진 박스)
        pygame.draw.rect(screen, BODY, (x - 10, y - 28 + hover, 20, 20), border_radius=3)
        pygame.draw.rect(screen, BODY_LIGHT, (x - 10, y - 28 + hover, 20, 20), 2, border_radius=3)

        # 가슴 패널
        pygame.draw.rect(screen, BODY_DARK, (x - 6, y - 24 + hover, 12, 8), border_radius=2)
        # LED 바
        for i in range(3):
            blink = (int(anim_timer * 5) + i) % 3
            c = LED if blink == 0 else (60, 70, 80)
            pygame.draw.rect(screen, c, (x - 4 + i * 4, y - 22 + hover, 3, 4))

        # 머리 (직사각형)
        head_y = y - 40 + hover
        pygame.draw.rect(screen, BODY, (x - 8, head_y, 16, 12), border_radius=2)
        pygame.draw.rect(screen, BODY_LIGHT, (x - 8, head_y, 16, 12), 2, border_radius=2)

        # 눈 (단일 바이저)
        pygame.draw.rect(screen, (15, 20, 30), (x - 6, head_y + 3, 12, 4), border_radius=1)
        scan_x = int(4 * math.sin(anim_timer * 2))
        pygame.draw.rect(screen, LED, (x - 2 + scan_x, head_y + 4, 4, 2))

        # 안테나 (2개)
        pygame.draw.line(screen, BODY_DARK, (x - 4, head_y), (x - 6, head_y - 6), 2)
        pygame.draw.line(screen, BODY_DARK, (x + 4, head_y), (x + 6, head_y - 6), 2)
        pygame.draw.circle(screen, LED, (x - 6, head_y - 7), 2)
        pygame.draw.circle(screen, LED, (x + 6, head_y - 7), 2)

    def _draw_wall_monitor(self, screen, x, y, accent_color, anim_timer):
        """벽면 모니터 패널"""
        w, h = 60, 45
        # 프레임
        pygame.draw.rect(screen, (40, 50, 65), (x, y, w, h), border_radius=4)
        pygame.draw.rect(screen, (80, 95, 115), (x, y, w, h), 2, border_radius=4)

        # 스크린
        pygame.draw.rect(screen, (15, 20, 30), (x + 4, y + 4, w - 8, h - 8), border_radius=2)

        # 그래프 라인 (애니메이션)
        for i in range(5):
            lx = x + 8 + i * 10
            ly = y + h - 12 - int(8 * math.sin(anim_timer * 2 + i * 0.8))
            pygame.draw.line(screen, accent_color, (lx, y + h - 10), (lx, ly), 2)

        # 상태 LED
        pygame.draw.circle(screen, accent_color, (x + w - 10, y + 10), 3)

    def _draw_exchange_rate_board(self, screen, x, y, anim_timer):
        """환율 전광판 - 주식 전광판 스타일 (LED 도트 매트릭스)"""
        import math

        # 전광판 크기
        board_w, board_h = 130, 85

        # 색상 (어두운 배경 + 밝은 LED)
        BG_BLACK = (5, 8, 12)
        FRAME_DARK = (20, 25, 35)
        GRID_DIM = (15, 20, 30)
        LED_GREEN = (50, 255, 120)
        LED_RED = (255, 70, 70)
        LED_YELLOW = (255, 220, 50)
        LED_CYAN = (60, 200, 255)
        LED_DIM_GREEN = (15, 60, 35)
        LED_DIM_RED = (60, 20, 20)

        # 환율 변동 색상 결정
        if self.exchange_rate_variance >= 0:
            rate_color = LED_GREEN
            dim_color = LED_DIM_GREEN
            arrow_char = "▲"
        else:
            rate_color = LED_RED
            dim_color = LED_DIM_RED
            arrow_char = "▼"

        # 외부 프레임 (두꺼운 금속 느낌)
        pygame.draw.rect(screen, FRAME_DARK, (x - 2, y - 2, board_w + 4, board_h + 4))
        pygame.draw.rect(screen, (40, 50, 65), (x - 2, y - 2, board_w + 4, board_h + 4), 2)

        # 메인 스크린 배경 (완전 검정)
        pygame.draw.rect(screen, BG_BLACK, (x, y, board_w, board_h))

        # 그리드 라인 (주식 전광판 특유의 격자)
        for gx in range(0, board_w, 8):
            pygame.draw.line(screen, GRID_DIM, (x + gx, y), (x + gx, y + board_h), 1)
        for gy in range(0, board_h, 8):
            pygame.draw.line(screen, GRID_DIM, (x, y + gy), (x + board_w, y + gy), 1)

        # 스캔라인 효과 (움직이는 밝은 라인)
        scan_y = int((anim_timer * 30) % board_h)
        scan_surf = pygame.Surface((board_w, 2), pygame.SRCALPHA)
        pygame.draw.rect(scan_surf, (100, 120, 150, 30), (0, 0, board_w, 2))
        screen.blit(scan_surf, (x, y + scan_y))

        # 상단 타이틀 바 (빨간색 배경)
        pygame.draw.rect(screen, (80, 15, 15), (x + 2, y + 2, board_w - 4, 16))

        font_small = self.fonts.get('small')
        if font_small:
            # 타이틀: "환율" (노란색 LED)
            title_surf, title_rect = font_small.render("환율", LED_YELLOW)
            screen.blit(title_surf, (x + 8, y + 4))

            # 오른쪽에 "RATE"
            rate_label, _ = font_small.render("RATE", LED_YELLOW)
            screen.blit(rate_label, (x + board_w - 40, y + 4))

        # 메인 환율 표시 영역
        main_y = y + 22

        # 스타포인트 심볼 (★) - 시안색
        if font_small:
            star_surf, _ = font_small.render("★", LED_CYAN)
            screen.blit(star_surf, (x + 8, main_y + 2))

            # "1"
            one_surf, _ = font_small.render("1", LED_CYAN)
            screen.blit(one_surf, (x + 22, main_y + 2))

        # 화살표 (→)
        arrow_x = x + 38
        pygame.draw.polygon(screen, LED_YELLOW, [
            (arrow_x, main_y + 10),
            (arrow_x + 12, main_y + 10),
            (arrow_x + 12, main_y + 6),
            (arrow_x + 18, main_y + 12),
            (arrow_x + 12, main_y + 18),
            (arrow_x + 12, main_y + 14),
            (arrow_x, main_y + 14)
        ])

        # 골드 아이콘 (●) - 노란색
        if font_small:
            gold_surf, _ = font_small.render("●", LED_YELLOW)
            screen.blit(gold_surf, (x + 62, main_y + 2))

        # 환율 숫자 (큰 LED 숫자 느낌)
        rate_text = str(self.current_exchange_rate)
        if font_small:
            rate_surf, rate_rect = font_small.render(rate_text, rate_color)
            screen.blit(rate_surf, (x + 78, main_y + 2))

        # 하단 변동률 표시
        bottom_y = y + 45

        # 구분선
        pygame.draw.line(screen, GRID_DIM, (x + 4, bottom_y - 2), (x + board_w - 4, bottom_y - 2), 1)

        # 변동률
        variance_pct = f"{self.exchange_rate_variance * 100:+.1f}%"
        if font_small:
            # 화살표
            arrow_surf, _ = font_small.render(arrow_char, rate_color)
            screen.blit(arrow_surf, (x + 10, bottom_y + 2))

            # 퍼센트
            var_surf, _ = font_small.render(variance_pct, rate_color)
            screen.blit(var_surf, (x + 28, bottom_y + 2))

        # 미니 그래프 (오른쪽 하단) - 주식 차트 느낌
        graph_x = x + 75
        graph_y = bottom_y
        graph_w = 50
        graph_h = 25

        # 그래프 배경
        pygame.draw.rect(screen, (10, 15, 25), (graph_x, graph_y, graph_w, graph_h))
        pygame.draw.rect(screen, GRID_DIM, (graph_x, graph_y, graph_w, graph_h), 1)

        # 그래프 라인 (랜덤하게 움직이는 느낌)
        prev_py = graph_y + graph_h // 2
        for i in range(graph_w // 4):
            px = graph_x + i * 4
            py = graph_y + graph_h // 2 + int(8 * math.sin(anim_timer * 2 + i * 0.7))
            if i > 0:
                pygame.draw.line(screen, rate_color, (px - 4, prev_py), (px, py), 1)
            prev_py = py

        # 우측 하단 상태 LED
        led_blink = int(anim_timer * 3) % 2 == 0
        led_c = LED_GREEN if led_blink else LED_DIM_GREEN
        pygame.draw.circle(screen, led_c, (x + board_w - 8, y + board_h - 8), 3)

    def _draw_star_icon_small(self, screen, cx, cy, size, color):
        """작은 스타포인트 아이콘 (별)"""
        import math
        points = []
        for i in range(10):
            angle = -math.pi / 2 + (i * math.pi / 5)
            r = size if i % 2 == 0 else size * 0.4
            points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
        pygame.draw.polygon(screen, color, points)
        # 하이라이트
        pygame.draw.polygon(screen, tuple(min(255, c + 50) for c in color), points, 1)

    def _draw_gold_icon_small(self, screen, cx, cy, size, color):
        """작은 골드 아이콘 (동전)"""
        # 동전 본체
        pygame.draw.circle(screen, color, (cx, cy), size)
        # 테두리
        pygame.draw.circle(screen, tuple(max(0, c - 50) for c in color), (cx, cy), size, 1)
        # 중앙 심볼 ($)
        pygame.draw.line(screen, tuple(max(0, c - 80) for c in color), (cx, cy - size // 2), (cx, cy + size // 2), 1)

    def _draw_interest_rate_board(self, screen, x, y, anim_timer):
        """예금 이자율 전광판 - 주식 전광판 스타일 (LED 도트 매트릭스)"""
        import math

        # 전광판 크기
        board_w, board_h = 110, 85

        # 색상 (어두운 배경 + 밝은 LED)
        BG_BLACK = (5, 8, 12)
        FRAME_DARK = (20, 25, 35)
        GRID_DIM = (15, 20, 30)
        LED_GREEN = (50, 255, 120)
        LED_YELLOW = (255, 220, 50)
        LED_ORANGE = (255, 160, 50)
        LED_CYAN = (60, 200, 255)
        LED_DIM = (15, 60, 35)

        # 이자율에 따른 색상 (높을수록 초록)
        rate_pct = self.deposit_interest_rate * 100
        if rate_pct >= 15:
            rate_color = LED_GREEN
            rating = "HOT"
        elif rate_pct >= 10:
            rate_color = LED_YELLOW
            rating = "MID"
        else:
            rate_color = LED_ORANGE
            rating = "LOW"

        # 외부 프레임 (두꺼운 금속 느낌)
        pygame.draw.rect(screen, FRAME_DARK, (x - 2, y - 2, board_w + 4, board_h + 4))
        pygame.draw.rect(screen, (40, 50, 65), (x - 2, y - 2, board_w + 4, board_h + 4), 2)

        # 메인 스크린 배경 (완전 검정)
        pygame.draw.rect(screen, BG_BLACK, (x, y, board_w, board_h))

        # 그리드 라인 (주식 전광판 특유의 격자)
        for gx in range(0, board_w, 8):
            pygame.draw.line(screen, GRID_DIM, (x + gx, y), (x + gx, y + board_h), 1)
        for gy in range(0, board_h, 8):
            pygame.draw.line(screen, GRID_DIM, (x, y + gy), (x + board_w, y + gy), 1)

        # 스캔라인 효과 (움직이는 밝은 라인)
        scan_y = int((anim_timer * 25) % board_h)
        scan_surf = pygame.Surface((board_w, 2), pygame.SRCALPHA)
        pygame.draw.rect(scan_surf, (100, 120, 150, 25), (0, 0, board_w, 2))
        screen.blit(scan_surf, (x, y + scan_y))

        # 상단 타이틀 바 (진한 파랑 배경)
        pygame.draw.rect(screen, (15, 40, 80), (x + 2, y + 2, board_w - 4, 16))

        font_small = self.fonts.get('small')
        if font_small:
            # 타이틀: "이자율" (노란색 LED)
            title_surf, _ = font_small.render("이자율", LED_YELLOW)
            screen.blit(title_surf, (x + 8, y + 4))

            # 오른쪽에 등급 표시
            rating_surf, _ = font_small.render(rating, rate_color)
            screen.blit(rating_surf, (x + board_w - 35, y + 4))

        # 메인 이자율 표시
        main_y = y + 24

        # "예금" 라벨
        if font_small:
            label_surf, _ = font_small.render("예금", LED_CYAN)
            screen.blit(label_surf, (x + 8, main_y))

        # 큰 이자율 숫자
        rate_text = f"{rate_pct:.1f}%"
        if font_small:
            rate_surf, rate_rect = font_small.render(rate_text, rate_color)
            screen.blit(rate_surf, (x + board_w // 2 - rate_rect.width // 2 + 10, main_y + 18))

        # 하단 영역 - 바 그래프
        bar_y = y + 58

        # 구분선
        pygame.draw.line(screen, GRID_DIM, (x + 4, bar_y - 4), (x + board_w - 4, bar_y - 4), 1)

        # 이자율 바 그래프 (5%~20%)
        bar_x = x + 8
        bar_w = board_w - 16
        bar_h = 10

        # 바 배경
        pygame.draw.rect(screen, (20, 25, 35), (bar_x, bar_y, bar_w, bar_h))
        pygame.draw.rect(screen, GRID_DIM, (bar_x, bar_y, bar_w, bar_h), 1)

        # 세그먼트 바 (LED 스타일)
        fill_ratio = (self.deposit_interest_rate - 0.05) / 0.15
        num_segments = 15
        active_segments = int(num_segments * fill_ratio)
        seg_w = (bar_w - 4) // num_segments

        for i in range(num_segments):
            seg_x = bar_x + 2 + i * seg_w
            if i < active_segments:
                # 그라데이션 색상 (낮음:주황 → 높음:초록)
                if i < 5:
                    seg_color = LED_ORANGE
                elif i < 10:
                    seg_color = LED_YELLOW
                else:
                    seg_color = LED_GREEN
            else:
                seg_color = (25, 30, 40)  # 비활성 세그먼트

            pygame.draw.rect(screen, seg_color, (seg_x, bar_y + 2, seg_w - 1, bar_h - 4))

        # 최소/최대 라벨
        if font_small:
            min_surf, _ = font_small.render("5%", (80, 90, 110))
            screen.blit(min_surf, (bar_x, bar_y + 12))

            max_surf, _ = font_small.render("20%", (80, 90, 110))
            screen.blit(max_surf, (bar_x + bar_w - 22, bar_y + 12))

        # 우측 하단 상태 LED
        led_blink = int(anim_timer * 2.5) % 2 == 0
        led_c = rate_color if led_blink else LED_DIM
        pygame.draw.circle(screen, led_c, (x + board_w - 8, y + board_h - 8), 3)

    def _draw_floor(self, screen):
        """바닥 타일 그리기"""
        floor_color = self.config["floor_color"]
        pattern = self.config.get("floor_pattern", "plain")

        # 화면에 보이는 타일만 그리기
        start_x = max(0, int(self.camera_offset[0] // TILE_SIZE))
        start_y = max(0, int(self.camera_offset[1] // TILE_SIZE))
        end_x = min(self.map_width, start_x + SCREEN_WIDTH // TILE_SIZE + 2)
        end_y = min(self.map_height, start_y + SCREEN_HEIGHT // TILE_SIZE + 2)

        for ty in range(start_y, end_y):
            for tx in range(start_x, end_x):
                tile_x = tx * TILE_SIZE - self.camera_offset[0]
                tile_y = ty * TILE_SIZE - self.camera_offset[1]

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
                elif pattern == "bank_tile":
                    # 은행 타일 (청색 계열 격자)
                    if (tx + ty) % 2 == 0:
                        color = tuple(min(255, c + 10) for c in floor_color)
                    else:
                        color = tuple(max(0, c - 5) for c in floor_color)
                else:
                    # 체크 패턴 (기본)
                    if (tx + ty) % 2 == 0:
                        color = floor_color
                    else:
                        color = tuple(max(0, c - 8) for c in floor_color)

                pygame.draw.rect(screen, color,
                               (tile_x, tile_y, TILE_SIZE, TILE_SIZE))
                pygame.draw.rect(screen, tuple(max(0, c - 15) for c in floor_color),
                               (tile_x, tile_y, TILE_SIZE, TILE_SIZE), 1)

    def _draw_walls(self, screen):
        """벽 그리기"""
        wall_color = self.config["wall_color"]
        accent = self.config["accent_color"]

        # 상단 벽 (카운터/이름 영역)
        wall_h = TILE_SIZE * 2
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
        side_wall_w = TILE_SIZE

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
                border_color = tuple(max(0, c - 20) for c in secondary)
                pygame.draw.rect(screen, border_color, (x, y + h // 3, w, h * 2 // 3), 2)
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
        """UI 그리기 - 광장과 동일한 상단 UI + 하단 조작 안내"""
        font_small = self.fonts.get('small')
        font_medium = self.fonts.get('medium')

        # === 좌측 상단: 열쇠 (AP) ===
        if self.ap_system:
            self.ap_system.draw(screen, 35, 30, font_medium)

        # === 좌측 상단: 금화 (열쇠 아래) ===
        self._draw_gold(screen)

        # === 우측 상단: 스타 포인트 ===
        self._draw_star_points(screen)

        # === 하단: 조작 안내 ===
        if font_small:
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

    def _draw_gold(self, screen):
        """골드 표시 - 광장과 동일"""
        gold = self.player_data.get('gold', 0)

        # 금화 아이콘 그리기 (열쇠 아래 위치)
        coin_x, coin_y = 35, 75
        coin_size = 18
        self._draw_gold_coin(screen, coin_x, coin_y, coin_size)

        # 골드 숫자
        font_medium = self.fonts.get('medium')
        if font_medium:
            gold_text = f"{gold:,}"
            text_surface, _ = font_medium.render(gold_text, Colors.UI_ACCENT)
            screen.blit(text_surface, (coin_x + coin_size + 8, coin_y - 4))

    def _draw_gold_coin(self, screen, x, y, size):
        """금화 아이콘 그리기 - 광장과 동일 (입체감 있는 동전)"""
        import math

        # 금화 서피스 생성
        coin_surf = pygame.Surface((size + 4, size + 4), pygame.SRCALPHA)

        cx, cy = size // 2 + 2, size // 2 + 2
        radius = size // 2

        # 색상 정의
        gold_dark = (180, 130, 20)      # 어두운 금색 (테두리/그림자)
        gold_main = (255, 200, 50)       # 메인 금색
        gold_light = (255, 235, 120)     # 밝은 금색 (하이라이트)
        gold_shine = (255, 250, 200)     # 반짝임

        # 그림자 (약간 아래 오른쪽)
        pygame.draw.circle(coin_surf, (0, 0, 0, 80), (cx + 2, cy + 2), radius)

        # 외곽 테두리 (어두운 금색)
        pygame.draw.circle(coin_surf, gold_dark, (cx, cy), radius)

        # 메인 금화
        pygame.draw.circle(coin_surf, gold_main, (cx, cy), radius - 2)

        # 내부 테두리 (입체감)
        pygame.draw.circle(coin_surf, gold_dark, (cx, cy), radius - 3, 1)

        # 상단 하이라이트 (반원)
        highlight_rect = (cx - radius + 4, cy - radius + 3, (radius - 4) * 2, radius - 2)
        pygame.draw.arc(coin_surf, gold_light, highlight_rect, 0.5, 2.6, 2)

        # 중앙에 별 무늬
        star_size = radius // 2
        star_points = []
        for i in range(5):
            # 바깥 점
            angle = math.pi / 2 + i * 2 * math.pi / 5
            px = cx + int(star_size * math.cos(angle))
            py = cy - int(star_size * math.sin(angle))
            star_points.append((px, py))
            # 안쪽 점
            angle += math.pi / 5
            px = cx + int(star_size * 0.4 * math.cos(angle))
            py = cy - int(star_size * 0.4 * math.sin(angle))
            star_points.append((px, py))

        if len(star_points) >= 3:
            pygame.draw.polygon(coin_surf, gold_dark, star_points)
            # 별 하이라이트
            inner_star = [(int(cx + (p[0] - cx) * 0.7), int(cy + (p[1] - cy) * 0.7)) for p in star_points]
            if len(inner_star) >= 3:
                pygame.draw.polygon(coin_surf, gold_light, inner_star)

        # 반짝임 효과 (우상단)
        pygame.draw.circle(coin_surf, gold_shine, (cx + radius // 3, cy - radius // 3), 2)

        screen.blit(coin_surf, (x - size // 2, y - size // 2))

    def _draw_star_points(self, screen):
        """스타 포인트 표시 - 광장과 동일 (우측 상단)"""
        # Academy에서 실제 스킬 포인트 가져오기
        star_points = 0
        if self.academy and hasattr(self.academy, 'skill_system'):
            star_points = self.academy.skill_system.skill_points
        else:
            star_points = self.player_data.get('star_points', 0)

        # 우측 상단 위치
        star_x = SCREEN_WIDTH - 100
        star_y = 30

        # 별 아이콘 그리기
        star_size = 16
        self._draw_star_icon(screen, star_x, star_y, star_size)

        # 스타 포인트 숫자
        font_medium = self.fonts.get('medium')
        if font_medium:
            star_text = f"{star_points}"
            text_surface, _ = font_medium.render(star_text, (255, 220, 100))
            screen.blit(text_surface, (star_x + star_size + 10, star_y - 6))

    def _draw_star_icon(self, screen, cx, cy, size):
        """5각 별 아이콘 그리기 - 광장과 동일"""
        import math

        # 메인 별 포인트 계산
        star_points = []
        for i in range(10):
            angle = -math.pi / 2 + (i * math.pi / 5)  # 위쪽부터 시작
            radius = size if i % 2 == 0 else size * 0.5
            px = cx + radius * math.cos(angle)
            py = cy + radius * math.sin(angle)
            star_points.append((px, py))

        # 메인 별 그리기 (노란색)
        pygame.draw.polygon(screen, (255, 255, 100), star_points)

        # 외곽선 그리기 (금색)
        pygame.draw.polygon(screen, (255, 215, 0), star_points, 2)

        # 광택 효과 (작은 별)
        gloss_points = []
        for i in range(10):
            angle = -math.pi / 2 + (i * math.pi / 5)
            radius = size * 0.3 if i % 2 == 0 else size * 0.15
            px = cx + radius * math.cos(angle)
            py = cy - 2 + radius * math.sin(angle)  # 약간 위로
            gloss_points.append((px, py))

        # 광택 별 그리기 (밝은 노란색, 반투명)
        gloss_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
        gloss_offset_x = size * 2 - cx
        gloss_offset_y = size * 2 - cy
        adjusted_gloss_points = [(px + gloss_offset_x, py + gloss_offset_y) for px, py in gloss_points]
        pygame.draw.polygon(gloss_surf, (255, 255, 200, 180), adjusted_gloss_points)
        screen.blit(gloss_surf, (cx - size * 2, cy - size * 2))
