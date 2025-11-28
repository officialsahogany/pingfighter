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

        # === 아카데미 활동 시스템 ===
        self.academy_activity = None  # "magic_practice", "dash_practice", "pair_practice", "standing", "walking"
        self.pair_partner = None  # 짝꿍 NPC (pair_practice용)
        self.practice_timer = 0  # 연습 애니메이션 타이머
        self.magic_charge = 0  # 마법 차징 (0~1)
        self.dash_state = "idle"  # "idle", "charging", "dashing", "recovering"
        self.dash_timer = 0
        self.dash_start_x = x
        self.dash_target_x = x
        self.magic_color = random.choice([
            (100, 200, 255),  # 파란 마법
            (255, 150, 100),  # 주황 마법
            (150, 255, 150),  # 초록 마법
            (255, 200, 100),  # 노란 마법
            (200, 150, 255),  # 보라 마법
        ])

    def update(self, dt, walkable_rect=None, obstacle_rects=None):
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

        # 아카데미 활동 업데이트
        if self.academy_activity:
            # walking 활동은 기존 걷기 로직 사용
            if self.academy_activity == "walking" and walkable_rect:
                self._update_walking(dt, walkable_rect, obstacle_rects)
            elif self.academy_activity not in ("standing", "walking"):
                self._update_academy_activity(dt)
        # 고객 NPC만 걸어다니기 (메인, 스태프 제외, 아카데미 활동 중이 아닐 때)
        elif self.role == "customer" and walkable_rect:
            self._update_walking(dt, walkable_rect, obstacle_rects)

    def _update_academy_activity(self, dt):
        """아카데미 활동 업데이트"""
        self.practice_timer += dt

        if self.academy_activity == "magic_practice":
            # 마법 차징 → 발사 → 쿨다운 사이클
            cycle_time = 3.0  # 3초 사이클
            phase = (self.practice_timer % cycle_time) / cycle_time
            if phase < 0.6:  # 차징 (60%)
                self.magic_charge = phase / 0.6
            elif phase < 0.7:  # 발사 (10%)
                self.magic_charge = 1.0
            else:  # 쿨다운 (30%)
                self.magic_charge = 0

        elif self.academy_activity == "pair_practice":
            # 짝꿍과 마법 주고받기
            cycle_time = 4.0  # 4초 사이클
            phase = (self.practice_timer % cycle_time) / cycle_time
            if phase < 0.4:  # 차징
                self.magic_charge = phase / 0.4
            elif phase < 0.5:  # 발사
                self.magic_charge = 1.0
            elif phase < 0.9:  # 대기 (상대방 턴)
                self.magic_charge = 0
            else:  # 받기 준비
                self.magic_charge = 0.3

        elif self.academy_activity == "dash_practice":
            # 대쉬 연습: 충전 → 대쉬 → 회복
            if self.dash_state == "idle":
                self.dash_timer += dt
                if self.dash_timer >= 2.0:  # 2초 대기 후 충전 시작
                    self.dash_state = "charging"
                    self.dash_timer = 0
                    self.dash_start_x = self.x
                    # 대쉬 방향 결정 (왼쪽/오른쪽)
                    dash_dir = 1 if self.direction == 2 else -1
                    self.dash_target_x = self.x + dash_dir * 80

            elif self.dash_state == "charging":
                self.dash_timer += dt
                self.magic_charge = min(1.0, self.dash_timer / 0.8)  # 0.8초 충전
                if self.dash_timer >= 0.8:
                    self.dash_state = "dashing"
                    self.dash_timer = 0

            elif self.dash_state == "dashing":
                self.dash_timer += dt
                # 빠른 이동 (0.2초)
                progress = min(1.0, self.dash_timer / 0.2)
                self.x = self.dash_start_x + (self.dash_target_x - self.dash_start_x) * progress
                if progress >= 1.0:
                    self.dash_state = "recovering"
                    self.dash_timer = 0
                    self.magic_charge = 0

            elif self.dash_state == "recovering":
                self.dash_timer += dt
                if self.dash_timer >= 1.5:  # 1.5초 회복
                    self.dash_state = "idle"
                    self.dash_timer = 0
                    # 방향 전환
                    self.direction = 1 if self.direction == 2 else 2
                    # 원래 위치로 돌아갈 준비
                    self.dash_target_x = self.original_x

    def _update_walking(self, dt, walkable_rect, obstacle_rects=None):
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
                # 이동 전 다음 위치가 장애물과 충돌하는지 체크
                move_dist = self.walk_speed * dt
                if move_dist > dist:
                    move_dist = dist
                next_x = self.x + (dx / dist) * move_dist
                next_y = self.y + (dy / dist) * move_dist

                # 장애물 충돌 체크
                can_move = True
                if obstacle_rects:
                    npc_rect = pygame.Rect(next_x - self.size, next_y - self.size,
                                          self.size * 2, self.size * 2)
                    for obstacle in obstacle_rects:
                        if npc_rect.colliderect(obstacle):
                            can_move = False
                            break

                if can_move:
                    self.x = next_x
                    self.y = next_y

                    # 방향 업데이트
                    if abs(dx) > abs(dy):
                        self.direction = 2 if dx > 0 else 1  # 좌우
                    else:
                        self.direction = 0 if dy > 0 else 3  # 상하
                else:
                    # 장애물에 막히면 걷기 중단
                    self.is_walking = False
                    self.walk_target_x = None
                    self.walk_target_y = None
                    self.walk_timer = random.uniform(3, 8)  # 짧은 대기 후 재시도
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

                # 목표 지점이 장애물 안에 있는지 체크
                target_valid = True
                if obstacle_rects:
                    target_rect = pygame.Rect(target_x - self.size, target_y - self.size,
                                             self.size * 2, self.size * 2)
                    for obstacle in obstacle_rects:
                        if target_rect.colliderect(obstacle):
                            target_valid = False
                            break

                if target_valid:
                    self.walk_target_x = target_x
                    self.walk_target_y = target_y
                    self.is_walking = True
                else:
                    # 장애물 안이면 다음 기회에 다시 시도
                    self.walk_timer = random.uniform(2, 5)

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

        # 아카데미 NPC인 경우 마법사/견습생 스타일로 그리기
        if self.building_type == BuildingType.ACADEMY:
            self._draw_wizard(screen, draw_x, draw_y, animation_timer)
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

    def _draw_wizard(self, screen, draw_x, draw_y, animation_timer):
        """아카데미 마법사/견습생 NPC 그리기"""
        npc_id = hash(self.name)
        is_main = self.role == "main"  # 학장 아르카나

        # 메인 NPC(학장)는 더 크고 특별한 색상
        scale = 1.15 if is_main else 1.0

        # 마법사 색상 팔레트
        if is_main:
            # 학장 아르카나: 보라색 로브 + 금색 장식
            ROBE_COLOR = (100, 50, 140)       # 보라색 로브
            ROBE_DARK = (70, 30, 100)         # 어두운 보라
            ROBE_LIGHT = (140, 80, 180)       # 밝은 보라
            ACCENT_COLOR = (255, 200, 100)    # 금색 장식
            MAGIC_GLOW = (180, 120, 255)      # 마법 발광
        else:
            # 견습생: 다양한 로브 색상
            robe_colors = [
                ((60, 90, 140), (40, 60, 100), (90, 120, 170)),    # 파란 로브
                ((80, 120, 80), (50, 80, 50), (110, 150, 110)),    # 초록 로브
                ((140, 80, 80), (100, 50, 50), (170, 110, 110)),   # 빨간 로브
                ((100, 100, 120), (70, 70, 90), (130, 130, 150)),  # 회색 로브
                ((120, 100, 60), (80, 70, 40), (150, 130, 90)),    # 갈색 로브
            ]
            robe_set = robe_colors[npc_id % len(robe_colors)]
            ROBE_COLOR, ROBE_DARK, ROBE_LIGHT = robe_set
            ACCENT_COLOR = (180, 180, 200)    # 은색 장식
            MAGIC_GLOW = (100, 200, 180)      # 청록 마법

        # 피부톤 (다양화)
        skin_tones = [
            (255, 224, 189), (255, 205, 148), (234, 192, 134),
            (198, 134, 66), (255, 219, 172)
        ]
        skin_color = skin_tones[npc_id % len(skin_tones)]
        skin_dark = tuple(max(0, c - 25) for c in skin_color)

        # 애니메이션
        hover_offset = int(1.5 * math.sin(animation_timer * 1.5 + npc_id))
        robe_sway = math.sin(animation_timer * 2 + npc_id) * 2

        # 위치 계산
        center_x = int(draw_x)
        feet_y = int(draw_y) + hover_offset

        # === 그림자 ===
        shadow_w = int((self.width + 12) * scale)
        shadow_h = int(8 * scale)
        shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40), (0, 0, shadow_w, shadow_h))
        screen.blit(shadow_surf, (center_x - shadow_w // 2, feet_y - 4 - hover_offset))

        # === 로브 하단 (바닥에 닿는 부분) ===
        robe_bottom_w = int(28 * scale)
        robe_bottom_h = int(12 * scale)
        robe_bottom_y = feet_y - robe_bottom_h

        # 로브 하단 (물결 모양)
        points = [
            (center_x - robe_bottom_w // 2 + robe_sway, robe_bottom_y),
            (center_x - robe_bottom_w // 2 - 2 + robe_sway, feet_y),
            (center_x + robe_bottom_w // 2 + 2 - robe_sway, feet_y),
            (center_x + robe_bottom_w // 2 - robe_sway, robe_bottom_y),
        ]
        pygame.draw.polygon(screen, ROBE_DARK, points)

        # === 로브 본체 ===
        robe_w = int(26 * scale)
        robe_h = int(38 * scale)
        robe_y = robe_bottom_y - robe_h + 8
        robe_x = center_x - robe_w // 2

        # 로브 몸통 (사다리꼴 형태)
        robe_points = [
            (center_x - robe_w // 3, robe_y),
            (center_x - robe_w // 2, robe_bottom_y),
            (center_x + robe_w // 2, robe_bottom_y),
            (center_x + robe_w // 3, robe_y),
        ]
        pygame.draw.polygon(screen, ROBE_COLOR, robe_points)

        # 로브 테두리/장식
        pygame.draw.polygon(screen, ROBE_LIGHT, robe_points, 2)

        # 중앙 장식 라인
        pygame.draw.line(screen, ACCENT_COLOR,
                        (center_x, robe_y + 5),
                        (center_x, robe_bottom_y - 5), 2)

        # 학장: 추가 금장식
        if is_main:
            # 가슴 엠블럼
            emblem_y = robe_y + 12
            pygame.draw.circle(screen, ACCENT_COLOR, (center_x, emblem_y), 6)
            pygame.draw.circle(screen, ROBE_DARK, (center_x, emblem_y), 4)
            # 별 모양
            for i in range(5):
                angle = -math.pi / 2 + (i * 2 * math.pi / 5)
                px = center_x + int(3 * math.cos(angle))
                py = emblem_y + int(3 * math.sin(angle))
                pygame.draw.circle(screen, ACCENT_COLOR, (px, py), 1)

        # === 소매/팔 ===
        arm_y = robe_y + int(10 * scale)
        arm_swing = int(2 * math.sin(animation_timer * 1.2 + npc_id))

        # 왼팔 (소매)
        sleeve_w = int(10 * scale)
        sleeve_h = int(16 * scale)
        pygame.draw.ellipse(screen, ROBE_DARK,
                           (robe_x - sleeve_w + 6, arm_y + arm_swing, sleeve_w, sleeve_h))
        # 손
        pygame.draw.ellipse(screen, skin_color,
                           (robe_x - 2, arm_y + sleeve_h - 5 + arm_swing, 6, 6))

        # 오른팔 (소매)
        pygame.draw.ellipse(screen, ROBE_COLOR,
                           (robe_x + robe_w - 6, arm_y - arm_swing, sleeve_w, sleeve_h))
        # 손
        pygame.draw.ellipse(screen, skin_color,
                           (robe_x + robe_w - 2, arm_y + sleeve_h - 5 - arm_swing, 6, 6))

        # 학장: 지팡이
        if is_main:
            staff_x = robe_x + robe_w + 4
            staff_top = arm_y - 20
            staff_bottom = feet_y - 5
            # 지팡이 막대
            pygame.draw.line(screen, (100, 70, 40), (staff_x, staff_bottom), (staff_x, staff_top), 3)
            # 지팡이 보석
            gem_pulse = int(150 + 80 * math.sin(animation_timer * 3))
            pygame.draw.circle(screen, MAGIC_GLOW, (staff_x, staff_top - 5), 6)
            # 보석 글로우
            glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*MAGIC_GLOW, gem_pulse // 2), (10, 10), 10)
            screen.blit(glow_surf, (staff_x - 10, staff_top - 15))

        # === 목/칼라 ===
        collar_y = robe_y - 2
        pygame.draw.ellipse(screen, ROBE_DARK,
                           (center_x - 8, collar_y, 16, 8))
        pygame.draw.ellipse(screen, ACCENT_COLOR,
                           (center_x - 8, collar_y, 16, 8), 1)

        # === 머리 ===
        head_w = int(14 * scale)
        head_h = int(14 * scale)
        head_y = collar_y - head_h + 4
        head_x = center_x - head_w // 2

        pygame.draw.ellipse(screen, skin_color, (head_x, head_y, head_w, head_h))

        # 볼 터치
        pygame.draw.circle(screen, (255, 200, 190), (head_x + 2, head_y + head_h // 2 + 1), 2)
        pygame.draw.circle(screen, (255, 200, 190), (head_x + head_w - 2, head_y + head_h // 2 + 1), 2)

        # === 마법사 모자 (학장) / 후드 (견습생) ===
        if is_main:
            # 마법사 뾰족 모자
            hat_base_y = head_y + 2
            hat_tip_y = head_y - int(25 * scale)
            hat_width = int(20 * scale)

            # 모자 본체
            hat_points = [
                (center_x, hat_tip_y),
                (center_x - hat_width // 2, hat_base_y),
                (center_x + hat_width // 2, hat_base_y),
            ]
            pygame.draw.polygon(screen, ROBE_COLOR, hat_points)
            pygame.draw.polygon(screen, ROBE_LIGHT, hat_points, 2)

            # 모자 챙
            pygame.draw.ellipse(screen, ROBE_DARK,
                              (center_x - hat_width // 2 - 3, hat_base_y - 3, hat_width + 6, 8))

            # 모자 장식 (금색 띠)
            pygame.draw.line(screen, ACCENT_COLOR,
                           (center_x - hat_width // 2 + 2, hat_base_y + 2),
                           (center_x + hat_width // 2 - 2, hat_base_y + 2), 2)

            # 모자 끝 별
            star_x = center_x + int(2 * math.sin(animation_timer * 2))
            pygame.draw.circle(screen, ACCENT_COLOR, (star_x, hat_tip_y), 4)
            # 별 글로우
            glow_alpha = int(100 + 50 * math.sin(animation_timer * 4))
            glow_surf = pygame.Surface((16, 16), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*ACCENT_COLOR, glow_alpha), (8, 8), 8)
            screen.blit(glow_surf, (star_x - 8, hat_tip_y - 8))
        else:
            # 견습생: 후드
            hood_points = [
                (center_x, head_y - 5),
                (center_x - head_w // 2 - 4, head_y + head_h // 2),
                (center_x - head_w // 2 - 2, collar_y + 2),
                (center_x + head_w // 2 + 2, collar_y + 2),
                (center_x + head_w // 2 + 4, head_y + head_h // 2),
            ]
            pygame.draw.polygon(screen, ROBE_DARK, hood_points)
            pygame.draw.polygon(screen, ROBE_COLOR, hood_points, 2)

        # === 눈 ===
        eye_y = head_y + head_h // 2 - 1
        eye_offset = 1 if self.direction == 2 else (-1 if self.direction == 1 else 0)

        # 눈 흰자
        pygame.draw.ellipse(screen, (255, 255, 255),
                           (center_x - 4 + eye_offset, eye_y - 2, 4, 4))
        pygame.draw.ellipse(screen, (255, 255, 255),
                           (center_x + 1 + eye_offset, eye_y - 2, 4, 4))

        # 눈동자
        pupil_color = (60, 40, 100) if is_main else (40, 30, 20)
        pygame.draw.circle(screen, pupil_color, (center_x - 2 + eye_offset, eye_y), 2)
        pygame.draw.circle(screen, pupil_color, (center_x + 3 + eye_offset, eye_y), 2)

        # 눈 하이라이트
        pygame.draw.circle(screen, (255, 255, 255), (center_x - 2 + eye_offset, eye_y - 1), 1)
        pygame.draw.circle(screen, (255, 255, 255), (center_x + 3 + eye_offset, eye_y - 1), 1)

        # === 입 ===
        mouth_y = head_y + head_h - 4
        if self.is_talking:
            mouth_open = int(abs(math.sin(animation_timer * 8)) * 2)
            pygame.draw.ellipse(screen, (60, 40, 40),
                              (center_x - 2, mouth_y, 4, 2 + mouth_open))
        else:
            pygame.draw.line(screen, skin_dark, (center_x - 2, mouth_y), (center_x + 2, mouth_y), 1)

        # === 학장 마커 ===
        if is_main:
            marker_y = head_y - 35
            glow_alpha = int(150 + 80 * math.sin(animation_timer * 3))
            marker_surf = pygame.Surface((20, 12), pygame.SRCALPHA)
            pygame.draw.polygon(marker_surf, (*ACCENT_COLOR, glow_alpha), [
                (10, 10), (4, 2), (16, 2)
            ])
            screen.blit(marker_surf, (center_x - 10, marker_y))

        # === 아카데미 활동 이펙트 ===
        if not is_main and self.academy_activity:
            self._draw_academy_activity_effects(screen, center_x, feet_y, robe_y, animation_timer)

    def _draw_academy_activity_effects(self, screen, center_x, feet_y, robe_y, animation_timer):
        """아카데미 활동 이펙트 그리기"""
        magic_color = getattr(self, 'magic_color', (100, 200, 255))
        charge = getattr(self, 'magic_charge', 0)

        if self.academy_activity == "magic_practice":
            # 혼자 마법 연습: 손 앞에 마법구 차징
            if charge > 0:
                # 손 위치 (로브 앞쪽)
                hand_x = center_x + (15 if self.direction == 2 else -15 if self.direction == 1 else 0)
                hand_y = robe_y + 15

                # 차징 크기
                orb_size = int(5 + charge * 12)
                glow_size = int(orb_size * 1.8)

                # 마법구 글로우
                glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                glow_alpha = int(80 + charge * 100)
                pygame.draw.circle(glow_surf, (*magic_color, glow_alpha), (glow_size, glow_size), glow_size)
                screen.blit(glow_surf, (hand_x - glow_size, hand_y - glow_size))

                # 마법구 코어
                pygame.draw.circle(screen, magic_color, (hand_x, hand_y), orb_size)
                pygame.draw.circle(screen, (255, 255, 255), (hand_x - 2, hand_y - 2), max(1, orb_size // 3))

                # 파티클 이펙트 (차징 중)
                if charge > 0.3:
                    for i in range(3):
                        angle = animation_timer * 3 + i * 2.1
                        particle_dist = orb_size + 5 + int(5 * math.sin(animation_timer * 5 + i))
                        px = hand_x + int(particle_dist * math.cos(angle))
                        py = hand_y + int(particle_dist * math.sin(angle))
                        particle_alpha = int(100 + 50 * math.sin(animation_timer * 7 + i))
                        p_surf = pygame.Surface((6, 6), pygame.SRCALPHA)
                        pygame.draw.circle(p_surf, (*magic_color, particle_alpha), (3, 3), 3)
                        screen.blit(p_surf, (px - 3, py - 3))

        elif self.academy_activity == "pair_practice":
            # 짝꿍 마법 연습: 상대를 향해 마법 발사
            if charge > 0:
                # 방향에 따른 손 위치
                dir_mult = 1 if self.direction == 2 else -1
                hand_x = center_x + dir_mult * 18
                hand_y = robe_y + 12

                # 차징 이펙트
                orb_size = int(4 + charge * 10)

                # 마법구
                glow_surf = pygame.Surface((orb_size * 3, orb_size * 3), pygame.SRCALPHA)
                glow_alpha = int(60 + charge * 120)
                pygame.draw.circle(glow_surf, (*magic_color, glow_alpha),
                                  (orb_size * 3 // 2, orb_size * 3 // 2), orb_size * 3 // 2)
                screen.blit(glow_surf, (hand_x - orb_size * 3 // 2, hand_y - orb_size * 3 // 2))

                pygame.draw.circle(screen, magic_color, (hand_x, hand_y), orb_size)
                pygame.draw.circle(screen, (255, 255, 255), (hand_x, hand_y), max(1, orb_size // 2))

                # 발사 중일 때 (charge == 1) 마법 빔 효과
                if charge >= 0.95:
                    beam_length = 50
                    end_x = hand_x + dir_mult * beam_length
                    # 빔 본체
                    beam_surf = pygame.Surface((abs(beam_length) + 10, 16), pygame.SRCALPHA)
                    for i in range(8):
                        beam_alpha = int(150 - i * 15)
                        y_off = 8 + int(3 * math.sin(animation_timer * 10 + i * 0.5))
                        pygame.draw.line(beam_surf, (*magic_color, beam_alpha),
                                       (5 if dir_mult > 0 else abs(beam_length) + 5, y_off),
                                       (abs(beam_length) + 5 if dir_mult > 0 else 5, y_off), 2)
                    screen.blit(beam_surf, (min(hand_x, end_x) - 5, hand_y - 8))

        elif self.academy_activity == "dash_practice":
            # 대쉬 연습 이펙트
            dash_state = getattr(self, 'dash_state', 'idle')

            if dash_state == "charging":
                # 충전 이펙트: 발 밑에 마법진
                charge_progress = charge
                circle_radius = int(15 + charge_progress * 10)
                glow_alpha = int(50 + charge_progress * 150)

                # 마법진 글로우
                glow_surf = pygame.Surface((circle_radius * 2 + 20, circle_radius * 2 + 20), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (200, 150, 255, glow_alpha // 2),
                                  (circle_radius + 10, circle_radius + 10), circle_radius + 10)
                pygame.draw.circle(glow_surf, (200, 150, 255, glow_alpha),
                                  (circle_radius + 10, circle_radius + 10), circle_radius)
                screen.blit(glow_surf, (center_x - circle_radius - 10, feet_y - 10 - circle_radius - 10))

                # 회전하는 룬 심볼
                for i in range(4):
                    angle = animation_timer * 2 + i * math.pi / 2
                    rx = center_x + int((circle_radius - 5) * math.cos(angle))
                    ry = feet_y - 10 + int((circle_radius - 5) * 0.4 * math.sin(angle))
                    pygame.draw.circle(screen, (255, 200, 255), (rx, ry), 3)

            elif dash_state == "dashing":
                # 대쉬 중: 잔상 이펙트
                dash_timer = getattr(self, 'dash_timer', 0)
                trail_count = 4

                for i in range(trail_count):
                    trail_alpha = int(100 - i * 25)
                    trail_offset = int(i * 15 * (1 if self.direction == 1 else -1))

                    trail_surf = pygame.Surface((20, 40), pygame.SRCALPHA)
                    pygame.draw.ellipse(trail_surf, (200, 150, 255, trail_alpha), (0, 0, 20, 40))
                    screen.blit(trail_surf, (center_x - 10 + trail_offset, robe_y))

                # 스피드 라인
                for i in range(6):
                    line_y = robe_y + 5 + i * 6
                    line_x = center_x + (20 if self.direction == 1 else -20)
                    line_len = 15 + random.randint(0, 10)
                    line_alpha = random.randint(100, 200)
                    line_surf = pygame.Surface((line_len, 2), pygame.SRCALPHA)
                    pygame.draw.rect(line_surf, (255, 255, 255, line_alpha), (0, 0, line_len, 2))
                    if self.direction == 1:
                        screen.blit(line_surf, (line_x, line_y))
                    else:
                        screen.blit(line_surf, (line_x - line_len, line_y))

            elif dash_state == "recovering":
                # 회복 중: 약한 파티클
                for i in range(3):
                    px = center_x + random.randint(-15, 15)
                    py = feet_y - random.randint(10, 30)
                    particle_alpha = random.randint(50, 100)
                    p_surf = pygame.Surface((4, 4), pygame.SRCALPHA)
                    pygame.draw.circle(p_surf, (200, 150, 255, particle_alpha), (2, 2), 2)
                    screen.blit(p_surf, (px - 2, py - 2))

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
        "name": "상점",
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
        "name": "상점",
        "map_size": (21, 18),  # 1.5배 확대 (14x12 → 21x18)
        "bg_color": (20, 20, 35),
        "floor_color": (40, 40, 55),
        "floor_pattern": "neon_grid",
        "wall_color": (30, 30, 45),
        "accent_color": (0, 255, 255),
        "secondary_color": (255, 20, 147),
        "decorations": [],  # 커스텀 인테리어 사용
        "main_npc": {
            "name": "점주 그린",  # 인간 상인
            "color": (0, 255, 100),
            "position": (0.35, 0.32),  # 카운터 뒤 왼쪽
            "dialogue": [
                "어서오세요, 고객님!",
                "오늘은 좋은 물건이 많이 들어왔습니다.",
                "천천히 구경하세요~"
            ]
        },
        "customer_range": (2, 4),
        "staff_count": 0,  # 커스텀 NPC 사용
        "special_interior": "neon_shop",  # 특수 인테리어 플래그
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
        "name": "아카데미",
        "map_size": (32, 24),  # 2배 확대 (16x12 → 32x24)
        "bg_color": (25, 50, 50),  # 청록색 계열 (스크린샷 참조)
        "floor_color": (45, 80, 80),  # 청록색 바닥
        "floor_pattern": "magic_circle_academy",  # 마법진 바닥 타일
        "wall_color": (35, 65, 65),  # 청록색 벽
        "accent_color": (120, 255, 200),  # 발광 청록 (마법진 색상)
        "secondary_color": (80, 150, 130),  # 보조 색상
        "decorations": [],  # 커스텀 인테리어 사용
        "main_npc": {
            "name": "학장 아르카나",
            "color": (150, 100, 255),
            "position": (0.5, 0.18),  # 맵이 커졌으므로 위치 조정
            "dialogue": [
                "아카데미에 오신 것을 환영합니다.",
                "새로운 스킬을 배우고 싶으신가요?",
                "현재 강의 준비 중입니다.",
                "곧 수업이 시작될 거예요."
            ]
        },
        "customer_range": (4, 8),  # 학생 수 증가
        "staff_count": 3,  # 교직원 증가
        "special_interior": "academy",  # 특수 인테리어 플래그
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

        # 아카데미 장애물 영역들 (ACADEMY에서만 사용)
        self.academy_obstacle_rects = []

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
        self.bank_menu_selection = 0  # 0: 환전, 1: 예금/출금, 2: 나가기
        self.bank_menu_items = ["환전", "예금/출금", "나가기"]

        # 환전 창 상태
        self.exchange_menu_open = False
        self.exchange_direction = 0  # 0: 스타포인트→골드, 1: 골드→스타포인트
        self.exchange_amount = 1  # 환전할 양

        # 예금 창 상태
        self.deposit_menu_open = False
        self.deposit_tab = 0  # 0: 예금 탭, 1: 설명 탭
        self.deposit_amount = 0  # 예금할 금액
        self.withdraw_mode = False  # False: 예금, True: 출금

        # 아카데미 메뉴 상태 (ACADEMY 전용)
        self.academy_dialog_open = False  # 학장 대화 미니창
        self.academy_dialog_selection = 0  # 0: 예, 1: 아니오
        self.open_skill_menu_requested = False  # 스킬 메뉴 열기 요청 플래그

    def _create_npcs(self):
        """NPC들 생성"""
        # 아카데미는 전용 NPC 생성 로직 사용
        if self.building_type == BuildingType.ACADEMY:
            return self._create_academy_npcs()
        # 네온 상점은 전용 NPC 생성 로직 사용
        if self.building_type == BuildingType.ITEM_SHOP:
            return self._create_neon_shop_npcs()

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

    def _create_academy_npcs(self):
        """아카데미 전용 NPC 생성 (8~12명 학생, 다양한 활동)"""
        npcs = []

        # === 학장 아르카나 (메인 NPC) ===
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

        # === 학생 NPC 배치 (8~12명) ===
        student_count = random.randint(8, 12)
        student_names = [
            "리나", "카이", "미라", "제이크", "소피아", "루크",
            "에밀리", "노아", "클로이", "이선", "올리비아", "레오"
        ]
        random.shuffle(student_names)

        student_dialogues = [
            ["마법 연습 중이에요!", "집중해야 해요..."],
            ["이 주문이 어려워요...", "선생님께 여쭤봐야겠어요."],
            ["오늘 수업 재밌었어요!", "내일도 열심히 해야지."],
            ["대쉬 연습이 힘들어요.", "하지만 재미있어요!"],
            ["파트너랑 연습 중이에요.", "서로 도와가며 배워요."],
            ["아카데미 최고!", "실력이 늘고 있어요."],
        ]

        # 활동 배치 계획
        # - 짝꿍 연습: 2쌍 (4명) - 서로 마주보고 마법 연습
        # - 대쉬 연습: 1명
        # - 혼자 마법 연습: 2~3명
        # - 서있기: 1~2명
        # - 걸어다니기: 나머지

        wall_h = int(TILE_SIZE * 3.5)  # 상단 벽 높이
        center_x = self.pixel_width // 2
        center_y = (wall_h + self.pixel_height) // 2

        student_idx = 0

        # --- 짝꿍 연습 1조 (왼쪽 영역) ---
        pair1_x = center_x - 120
        pair1_y = center_y + 30
        pair_distance = 70  # 짝꿍 간 거리

        if student_idx < student_count:
            # 왼쪽 학생 (오른쪽 바라봄)
            s1 = InteriorNPC(
                pair1_x - pair_distance // 2, pair1_y,
                student_names[student_idx % len(student_names)], "customer",
                (100, 150, 255), random.choice(student_dialogues), self.building_type
            )
            s1.academy_activity = "pair_practice"
            s1.direction = 2  # 오른쪽 바라봄
            s1.practice_timer = 0
            npcs.append(s1)
            student_idx += 1

        if student_idx < student_count:
            # 오른쪽 학생 (왼쪽 바라봄)
            s2 = InteriorNPC(
                pair1_x + pair_distance // 2, pair1_y,
                student_names[student_idx % len(student_names)], "customer",
                (255, 150, 100), random.choice(student_dialogues), self.building_type
            )
            s2.academy_activity = "pair_practice"
            s2.direction = 1  # 왼쪽 바라봄
            s2.practice_timer = 2.0  # 반 사이클 오프셋 (서로 번갈아 마법)
            s2.pair_partner = s1
            s1.pair_partner = s2
            npcs.append(s2)
            student_idx += 1

        # --- 짝꿍 연습 2조 (오른쪽 영역) ---
        pair2_x = center_x + 100
        pair2_y = center_y - 20

        if student_idx < student_count:
            s3 = InteriorNPC(
                pair2_x - pair_distance // 2, pair2_y,
                student_names[student_idx % len(student_names)], "customer",
                (150, 255, 150), random.choice(student_dialogues), self.building_type
            )
            s3.academy_activity = "pair_practice"
            s3.direction = 2
            s3.practice_timer = 1.0
            npcs.append(s3)
            student_idx += 1

        if student_idx < student_count:
            s4 = InteriorNPC(
                pair2_x + pair_distance // 2, pair2_y,
                student_names[student_idx % len(student_names)], "customer",
                (255, 200, 100), random.choice(student_dialogues), self.building_type
            )
            s4.academy_activity = "pair_practice"
            s4.direction = 1
            s4.practice_timer = 3.0
            s4.pair_partner = s3
            s3.pair_partner = s4
            npcs.append(s4)
            student_idx += 1

        # --- 대쉬 연습 (1명, 하단 중앙) ---
        if student_idx < student_count:
            dash_student = InteriorNPC(
                center_x, center_y + 100,
                student_names[student_idx % len(student_names)], "customer",
                (200, 150, 255), ["대쉬 연습 중!", "으랏차!"], self.building_type
            )
            dash_student.academy_activity = "dash_practice"
            dash_student.direction = 2  # 오른쪽부터 시작
            dash_student.dash_state = "idle"
            dash_student.dash_timer = random.uniform(0, 1.5)  # 랜덤 시작 시간
            npcs.append(dash_student)
            student_idx += 1

        # --- 혼자 마법 연습 (2~3명) ---
        solo_positions = [
            (center_x - 180, center_y + 80),
            (center_x + 180, center_y + 60),
            (center_x - 50, center_y + 150),
        ]
        solo_count = min(3, student_count - student_idx)

        for i in range(solo_count):
            if student_idx >= student_count:
                break
            px, py = solo_positions[i]
            solo_student = InteriorNPC(
                px, py,
                student_names[student_idx % len(student_names)], "customer",
                (150, 200, 255), random.choice(student_dialogues), self.building_type
            )
            solo_student.academy_activity = "magic_practice"
            solo_student.direction = random.choice([0, 1, 2, 3])  # 랜덤 방향
            solo_student.practice_timer = random.uniform(0, 3)  # 랜덤 시작 위상
            npcs.append(solo_student)
            student_idx += 1

        # --- 서있는 학생 (1~2명) ---
        standing_positions = [
            (center_x + 150, center_y + 130),
            (center_x - 150, center_y + 150),
        ]
        standing_count = min(2, student_count - student_idx)

        for i in range(standing_count):
            if student_idx >= student_count:
                break
            px, py = standing_positions[i]
            standing_student = InteriorNPC(
                px, py,
                student_names[student_idx % len(student_names)], "customer",
                (180, 180, 200), random.choice(student_dialogues), self.building_type
            )
            standing_student.academy_activity = "standing"
            standing_student.direction = random.choice([0, 1, 2, 3])
            npcs.append(standing_student)
            student_idx += 1

        # --- 걸어다니는 학생 (나머지) ---
        walking_positions = [
            (center_x - 100, center_y + 180),
            (center_x + 50, center_y + 200),
            (center_x - 30, center_y + 50),
        ]

        walk_idx = 0
        while student_idx < student_count:
            px, py = walking_positions[walk_idx % len(walking_positions)]
            # 약간의 랜덤 오프셋
            px += random.randint(-30, 30)
            py += random.randint(-20, 20)

            walking_student = InteriorNPC(
                px, py,
                student_names[student_idx % len(student_names)], "customer",
                (160, 180, 220), random.choice(student_dialogues), self.building_type
            )
            walking_student.academy_activity = "walking"
            walking_student.is_walking = False
            walking_student.walk_timer = random.uniform(1, 5)  # 곧 걷기 시작
            walking_student.walk_range = 80
            npcs.append(walking_student)
            student_idx += 1
            walk_idx += 1

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

        # 아카데미 장애물 충돌 체크 (ACADEMY 전용)
        if hasattr(self, 'academy_obstacle_rects') and self.academy_obstacle_rects:
            for obstacle_rect in self.academy_obstacle_rects:
                if player_rect.colliderect(obstacle_rect):
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

        # 메뉴가 열려있으면 플레이어 입력 차단
        if self.bank_menu_open or self.exchange_menu_open or self.academy_dialog_open:
            return

        # 플레이어 업데이트
        keys = pygame.key.get_pressed()
        self.player.handle_input(keys, dt)
        self.player.update(dt, self)

        # 카메라 업데이트
        self._update_camera()

        # NPC 업데이트 (걸어다니기용 walkable_rect + 장애물 영역 전달)
        obstacle_rects = getattr(self, 'academy_obstacle_rects', [])
        for npc in self.npcs:
            npc.update(dt, self.walkable_rect, obstacle_rects)

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
        # 아카데미 대화창이 열려있으면 대화창 클릭 처리
        if self.academy_dialog_open:
            return self._handle_academy_dialog_click(pos)

        # 예금 메뉴가 열려있으면 예금 메뉴 클릭 처리
        if self.deposit_menu_open:
            return self._handle_deposit_menu_click(pos)

        # 환전 메뉴가 열려있으면 환전 메뉴 클릭 처리
        if self.exchange_menu_open:
            return self._handle_exchange_menu_click(pos)

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
                # 아카데미 메인 NPC인 경우 대화창 열기
                elif self.building_type == BuildingType.ACADEMY and npc.role == "main":
                    self.academy_dialog_open = True
                    self.academy_dialog_selection = 0
                    return ("academy_dialog", npc)
                else:
                    dialogue = npc.start_dialogue()
                    if dialogue:
                        return ("talk", npc)

        return None

    def handle_key(self, event):
        """키 입력 처리 (이벤트 기반)"""
        if event.type != pygame.KEYDOWN:
            return None

        # 아카데미 대화창이 열려있을 때
        if self.academy_dialog_open:
            if self._handle_academy_dialog_key(event.key):
                if self.open_skill_menu_requested:
                    return ("academy_skill_menu", None)
                return ("academy_dialog_close", None)
            return None

        # 예금 메뉴가 열려있을 때
        if self.deposit_menu_open:
            if event.key == pygame.K_LEFT or event.key == pygame.K_a:
                # 탭 전환
                self.deposit_tab = 0
                return ("deposit_tab", None)
            elif event.key == pygame.K_RIGHT or event.key == pygame.K_d:
                # 탭 전환
                self.deposit_tab = 1
                return ("deposit_tab", None)
            elif event.key == pygame.K_TAB:
                # 예금/출금 모드 전환 (예금 탭에서만)
                if self.deposit_tab == 0:
                    self.withdraw_mode = not self.withdraw_mode
                    self.deposit_amount = 0
                    return ("deposit_mode", None)
            elif event.key == pygame.K_UP or event.key == pygame.K_w:
                # 금액 증가 (예금 탭에서만)
                if self.deposit_tab == 0:
                    if self.withdraw_mode:
                        max_amount = self.player_data.get('deposit_balance', 0)
                    else:
                        max_amount = self.player_data.get('gold', 0)
                    scroll_step = max(1, max_amount // 20)
                    self.deposit_amount = min(max_amount, self.deposit_amount + scroll_step)
                    return ("deposit_amount", None)
            elif event.key == pygame.K_DOWN or event.key == pygame.K_s:
                # 금액 감소 (예금 탭에서만)
                if self.deposit_tab == 0:
                    if self.withdraw_mode:
                        max_amount = self.player_data.get('deposit_balance', 0)
                    else:
                        max_amount = self.player_data.get('gold', 0)
                    scroll_step = max(1, max_amount // 20)
                    self.deposit_amount = max(0, self.deposit_amount - scroll_step)
                    return ("deposit_amount", None)
            elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                if self.deposit_tab == 0:
                    return self._execute_deposit()
            elif event.key == pygame.K_ESCAPE:
                self.deposit_menu_open = False
                return ("menu_close", None)
            return None

        # 환전 메뉴가 열려있을 때
        if self.exchange_menu_open:
            if event.key == pygame.K_LEFT or event.key == pygame.K_a:
                # 방향 전환: 골드→스타포인트
                self.exchange_direction = 1
                self.exchange_amount = 1
                return ("exchange_direction", None)
            elif event.key == pygame.K_RIGHT or event.key == pygame.K_d:
                # 방향 전환: 스타포인트→골드
                self.exchange_direction = 0
                self.exchange_amount = 1
                return ("exchange_direction", None)
            elif event.key == pygame.K_UP or event.key == pygame.K_w:
                self._adjust_exchange_amount(1)
                return ("exchange_amount", None)
            elif event.key == pygame.K_DOWN or event.key == pygame.K_s:
                self._adjust_exchange_amount(-1)
                return ("exchange_amount", None)
            elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                return self._execute_exchange()
            elif event.key == pygame.K_ESCAPE:
                self.exchange_menu_open = False
                return ("menu_close", None)
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

    def handle_scroll(self, event, mouse_pos=None):
        """마우스 휠 스크롤 처리 (슬라이더 위에서만 작동)"""
        if event.type == pygame.MOUSEWHEEL:
            # 예금 메뉴 슬라이더 처리
            if self.deposit_menu_open and self.deposit_tab == 0:
                if mouse_pos:
                    menu_w, menu_h = 420, 340
                    menu_x = (SCREEN_WIDTH - menu_w) // 2
                    menu_y = (SCREEN_HEIGHT - menu_h) // 2
                    slider_rect = pygame.Rect(menu_x + 30, menu_y + 150, 360, 44)  # 확장된 영역

                    if slider_rect.collidepoint(mouse_pos):
                        # 최대값 계산
                        if self.withdraw_mode:
                            max_amount = self.player_data.get('deposit_balance', 0)
                        else:
                            max_amount = self.player_data.get('gold', 0)

                        scroll_step = max(1, max_amount // 20)  # 최대값의 5%씩 조절
                        self.deposit_amount = max(0, min(max_amount, self.deposit_amount + event.y * scroll_step))
                        return ("deposit_amount", None)
                return None

            # 환전 메뉴 슬라이더 처리
            if self.exchange_menu_open:
                # 마우스 위치 확인 (슬라이더 영역 내에서만 작동)
                if mouse_pos:
                    menu_w, menu_h = 340, 270
                    menu_x = (SCREEN_WIDTH - menu_w) // 2
                    menu_y = (SCREEN_HEIGHT - menu_h) // 2
                    slider_rect = pygame.Rect(menu_x + 30, menu_y + 120, 280, 44)  # 확장된 영역

                    if not slider_rect.collidepoint(mouse_pos):
                        return None

                # 최대값에 비례한 스크롤 단위 계산
                max_amount = self._get_max_exchange_amount()
                scroll_step = max(1, max_amount // 20)  # 최대값의 5%씩 조절

                self._adjust_exchange_amount(event.y * scroll_step)
                return ("exchange_amount", None)

        return None

    def _get_max_exchange_amount(self):
        """환전 가능한 최대량 계산"""
        star_points = self._get_current_star_points()
        gold = self.player_data.get('gold', 0)

        if self.exchange_direction == 0:
            return max(1, star_points)
        else:
            return max(1, gold // self.current_exchange_rate) if self.current_exchange_rate > 0 else 1

    def _adjust_exchange_amount(self, delta):
        """환전 양 조절"""
        self.exchange_amount = max(1, self.exchange_amount + delta)

        # 최대값 제한 (보유량 기준)
        max_amount = self._get_max_exchange_amount()
        self.exchange_amount = min(self.exchange_amount, max_amount)

    def _execute_exchange(self):
        """환전 실행"""
        if self.exchange_direction == 0:
            # 스타포인트 → 골드
            star_points = self._get_current_star_points()
            if star_points >= self.exchange_amount:
                gold_gained = self.exchange_amount * self.current_exchange_rate
                new_star_points = star_points - self.exchange_amount
                self._set_star_points(new_star_points)
                self.player_data['gold'] = self.player_data.get('gold', 0) + gold_gained
                self.exchange_menu_open = False
                return ("exchange_success", {"type": "star_to_gold", "amount": self.exchange_amount, "gold": gold_gained})
            else:
                return ("exchange_fail", "스타포인트가 부족합니다")
        else:
            # 골드 → 스타포인트
            gold = self.player_data.get('gold', 0)
            gold_needed = self.exchange_amount * self.current_exchange_rate
            if gold >= gold_needed:
                self.player_data['gold'] = gold - gold_needed
                current_star = self._get_current_star_points()
                self._set_star_points(current_star + self.exchange_amount)
                self.exchange_menu_open = False
                return ("exchange_success", {"type": "gold_to_star", "amount": self.exchange_amount, "gold": gold_needed})
            else:
                return ("exchange_fail", "골드가 부족합니다")

        return None

    def _get_current_star_points(self):
        """현재 스타포인트 가져오기 (academy 우선)"""
        if self.academy:
            if hasattr(self.academy, 'skill_system') and self.academy.skill_system:
                return getattr(self.academy.skill_system, 'skill_points', 0)
            if hasattr(self.academy, 'skill_points'):
                return self.academy.skill_points
        return self.player_data.get('star_points', 0)

    def _set_star_points(self, value):
        """스타포인트 설정 (academy와 player_data 모두 동기화)"""
        self.player_data['star_points'] = value
        # academy의 skill_system 동기화
        if self.academy:
            if hasattr(self.academy, 'skill_system') and self.academy.skill_system:
                self.academy.skill_system.skill_points = value
            # academy 자체에 skill_points 속성이 있는 경우도 처리
            if hasattr(self.academy, 'skill_points'):
                self.academy.skill_points = value

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
                # 아카데미 메인 NPC (학장 아르카나)인 경우 대화창 열기
                elif self.building_type == BuildingType.ACADEMY and npc.role == "main":
                    self.academy_dialog_open = True
                    self.academy_dialog_selection = 0
                    return ("academy_dialog", npc)
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
            self.exchange_menu_open = True
            self.exchange_amount = 1
            self.exchange_direction = 0
            return ("bank_exchange", None)
        elif selected == "예금/출금":
            self.bank_menu_open = False
            self.deposit_menu_open = True
            self.deposit_tab = 0  # 기본: 예금 탭
            self.deposit_amount = 0
            self.withdraw_mode = False
            return ("bank_deposit", None)
        elif selected == "나가기":
            self.bank_menu_open = False
            return ("menu_close", None)

        return None

    def _handle_academy_dialog_click(self, pos):
        """아카데미 대화창 클릭 처리"""
        # 대화창 영역 계산 (화면 중앙)
        dialog_w, dialog_h = 320, 180
        dialog_x = (SCREEN_WIDTH - dialog_w) // 2
        dialog_y = (SCREEN_HEIGHT - dialog_h) // 2

        # 버튼 영역
        btn_w, btn_h = 80, 32
        btn_y = dialog_y + dialog_h - 50
        yes_btn = pygame.Rect(dialog_x + dialog_w // 2 - btn_w - 20, btn_y, btn_w, btn_h)
        no_btn = pygame.Rect(dialog_x + dialog_w // 2 + 20, btn_y, btn_w, btn_h)

        if yes_btn.collidepoint(pos):
            # 예 선택 - 스킬 메뉴 열기 요청
            self.academy_dialog_open = False
            self.open_skill_menu_requested = True
            return ("academy_skill_menu", None)
        elif no_btn.collidepoint(pos):
            # 아니오 선택 - 대화창 닫기
            self.academy_dialog_open = False
            return ("academy_dialog_close", None)

        # 대화창 바깥 클릭시 닫기
        dialog_rect = pygame.Rect(dialog_x, dialog_y, dialog_w, dialog_h)
        if not dialog_rect.collidepoint(pos):
            self.academy_dialog_open = False
            return ("academy_dialog_close", None)

        return None

    def _handle_academy_dialog_key(self, key):
        """아카데미 대화창 키보드 처리"""
        if key == pygame.K_LEFT or key == pygame.K_a:
            self.academy_dialog_selection = 0  # 예
            return True
        elif key == pygame.K_RIGHT or key == pygame.K_d:
            self.academy_dialog_selection = 1  # 아니오
            return True
        elif key == pygame.K_RETURN or key == pygame.K_SPACE:
            if self.academy_dialog_selection == 0:
                # 예 선택
                self.academy_dialog_open = False
                self.open_skill_menu_requested = True
                return True
            else:
                # 아니오 선택
                self.academy_dialog_open = False
                return True
        elif key == pygame.K_ESCAPE:
            self.academy_dialog_open = False
            return True
        return False

    def _handle_exchange_menu_click(self, pos):
        """환전 메뉴 클릭 처리 (슬라이더 지원)"""
        # 메뉴 영역 계산 (화면 중앙)
        menu_w, menu_h = 340, 270
        menu_x = (SCREEN_WIDTH - menu_w) // 2
        menu_y = (SCREEN_HEIGHT - menu_h) // 2

        # 방향 전환 버튼 영역
        dir_btn_y = menu_y + 78
        left_btn = pygame.Rect(menu_x + 30, dir_btn_y, 130, 36)
        right_btn = pygame.Rect(menu_x + 180, dir_btn_y, 130, 36)

        if left_btn.collidepoint(pos):
            self.exchange_direction = 0  # 스타포인트 → 골드
            self.exchange_amount = 1
            return ("exchange_direction", None)
        elif right_btn.collidepoint(pos):
            self.exchange_direction = 1  # 골드 → 스타포인트
            self.exchange_amount = 1
            return ("exchange_direction", None)

        # 슬라이더 클릭 처리
        slider_y = menu_y + 130
        slider_x = menu_x + 30
        slider_w = 280
        slider_h = 24
        slider_rect = pygame.Rect(slider_x, slider_y - 10, slider_w, slider_h + 20)  # 클릭 영역 확장

        if slider_rect.collidepoint(pos):
            # 클릭 위치로 양 계산
            click_x = pos[0] - slider_x
            ratio = max(0, min(1, click_x / slider_w))

            # 최대값 계산
            star_points = self.player_data.get('star_points', 0)
            gold = self.player_data.get('gold', 0)
            if self.exchange_direction == 0:
                max_amount = max(1, star_points)
            else:
                max_amount = max(1, gold // self.current_exchange_rate) if self.current_exchange_rate > 0 else 1

            self.exchange_amount = max(1, int(ratio * max_amount))
            return ("exchange_amount", None)

        # 환전 실행 버튼
        confirm_btn = pygame.Rect(menu_x + 30, menu_y + 218, 280, 38)
        if confirm_btn.collidepoint(pos):
            return self._execute_exchange()

        # 닫기 버튼 (우상단)
        close_btn = pygame.Rect(menu_x + menu_w - 35, menu_y + 8, 26, 26)
        if close_btn.collidepoint(pos):
            self.exchange_menu_open = False
            return ("menu_close", None)

        # 메뉴 바깥 클릭시 닫기
        menu_rect = pygame.Rect(menu_x, menu_y, menu_w, menu_h)
        if not menu_rect.collidepoint(pos):
            self.exchange_menu_open = False
            return ("menu_close", None)

        return None

    def _handle_deposit_menu_click(self, pos):
        """예금 메뉴 클릭 처리"""
        # 메뉴 영역 계산 (화면 중앙, 더 넓은 메뉴)
        menu_w, menu_h = 420, 340
        menu_x = (SCREEN_WIDTH - menu_w) // 2
        menu_y = (SCREEN_HEIGHT - menu_h) // 2

        # 탭 버튼 영역 (상단)
        tab_y = menu_y + 10
        tab_w = 190
        tab_h = 36
        tab1_btn = pygame.Rect(menu_x + 15, tab_y, tab_w, tab_h)
        tab2_btn = pygame.Rect(menu_x + 215, tab_y, tab_w, tab_h)

        if tab1_btn.collidepoint(pos):
            self.deposit_tab = 0
            return ("deposit_tab", None)
        elif tab2_btn.collidepoint(pos):
            self.deposit_tab = 1
            return ("deposit_tab", None)

        # 예금 탭에서만 작동하는 요소들
        if self.deposit_tab == 0:
            # 예금/출금 모드 전환 버튼
            mode_y = menu_y + 70
            deposit_btn = pygame.Rect(menu_x + 30, mode_y, 170, 36)
            withdraw_btn = pygame.Rect(menu_x + 220, mode_y, 170, 36)

            if deposit_btn.collidepoint(pos):
                self.withdraw_mode = False
                self.deposit_amount = 0
                return ("deposit_mode", None)
            elif withdraw_btn.collidepoint(pos):
                self.withdraw_mode = True
                self.deposit_amount = 0
                return ("withdraw_mode", None)

            # 슬라이더 클릭 처리
            slider_y = menu_y + 150
            slider_x = menu_x + 30
            slider_w = 360
            slider_h = 24
            slider_rect = pygame.Rect(slider_x, slider_y - 10, slider_w, slider_h + 20)

            if slider_rect.collidepoint(pos):
                click_x = pos[0] - slider_x
                ratio = max(0, min(1, click_x / slider_w))

                # 최대값 계산
                if self.withdraw_mode:
                    max_amount = self.player_data.get('deposit_balance', 0)
                else:
                    max_amount = self.player_data.get('gold', 0)

                self.deposit_amount = max(0, int(ratio * max_amount))
                return ("deposit_amount", None)

            # 실행 버튼 (예금하기 / 출금하기)
            confirm_btn = pygame.Rect(menu_x + 30, menu_y + 280, 360, 42)
            if confirm_btn.collidepoint(pos):
                return self._execute_deposit()

        # 닫기 버튼 (우상단)
        close_btn = pygame.Rect(menu_x + menu_w - 35, menu_y + 8, 26, 26)
        if close_btn.collidepoint(pos):
            self.deposit_menu_open = False
            return ("menu_close", None)

        # 메뉴 바깥 클릭시 닫기
        menu_rect = pygame.Rect(menu_x, menu_y, menu_w, menu_h)
        if not menu_rect.collidepoint(pos):
            self.deposit_menu_open = False
            return ("menu_close", None)

        return None

    def _execute_deposit(self):
        """예금 또는 출금 실행"""
        import random
        
        gold = self.player_data.get('gold', 0)
        balance = self.player_data.get('deposit_balance', 0)
        current_stage = self.player_data.get('current_stage', 1)

        if self.withdraw_mode:
            # 출금 모드
            if self.deposit_amount <= 0:
                return ("deposit_error", "출금할 금액을 설정하세요")
            if self.deposit_amount > balance:
                return ("deposit_error", "잔액이 부족합니다")

            # 출금 실행
            self.player_data['deposit_balance'] = balance - self.deposit_amount
            self.player_data['gold'] = gold + self.deposit_amount
            
            # 은행 방문 기록 업데이트 (출금했으므로 이 스테이지를 마지막 방문으로 기록)
            self.player_data['last_deposit_stage'] = current_stage
            
            # 다음 스테이지를 위한 새 이자율 생성
            new_rate = random.uniform(0.05, 0.20)
            self.player_data['last_interest_rate'] = new_rate
            
            # 다음 스테이지의 이자율을 pending_rates에 추가
            if 'pending_interest_rates' not in self.player_data:
                self.player_data['pending_interest_rates'] = {}
            self.player_data['pending_interest_rates'][str(current_stage + 1)] = new_rate
            
            withdrawn = self.deposit_amount
            self.deposit_amount = 0
            
            print(f"[DEPOSIT] Withdraw at stage {current_stage}: {withdrawn:,}G")
            print(f"[DEPOSIT] Interest rate for stage {current_stage + 1}: {new_rate*100:.1f}%")
            
            return ("withdraw_success", withdrawn)
        else:
            # 예금 모드
            if self.deposit_amount <= 0:
                return ("deposit_error", "예금할 금액을 설정하세요")
            if self.deposit_amount > gold:
                return ("deposit_error", "골드가 부족합니다")

            # 예금 실행
            self.player_data['gold'] = gold - self.deposit_amount
            self.player_data['deposit_balance'] = balance + self.deposit_amount

            # 은행 방문 기록 업데이트 (예금했으므로 이 스테이지를 마지막 방문으로 기록)
            self.player_data['last_deposit_stage'] = current_stage
            
            # 다음 스테이지를 위한 새 이자율 생성
            new_rate = random.uniform(0.05, 0.20)
            self.player_data['last_interest_rate'] = new_rate
            
            # 다음 스테이지의 이자율을 pending_rates에 추가
            if 'pending_interest_rates' not in self.player_data:
                self.player_data['pending_interest_rates'] = {}
            self.player_data['pending_interest_rates'][str(current_stage + 1)] = new_rate

            deposited = self.deposit_amount
            self.deposit_amount = 0
            
            print(f"[DEPOSIT] Deposit at stage {current_stage}: {deposited:,}G")
            print(f"[DEPOSIT] Interest rate for stage {current_stage + 1}: {new_rate*100:.1f}%")
            
            return ("deposit_success", deposited)

    def _draw_exchange_menu(self, screen):
        """환전 메뉴창 그리기 - SF 스타일 (가로 스크롤바)"""
        import math

        # 메뉴 크기 및 위치 (화면 중앙)
        menu_w, menu_h = 340, 270
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
        TEXT_GREEN = (100, 255, 150)
        TEXT_RED = (255, 100, 100)
        BTN_BG = (30, 45, 65)
        SLIDER_BG = (25, 35, 50)
        SLIDER_FILL = (60, 140, 200)
        SLIDER_HANDLE = (100, 200, 255)

        # 배경 어둡게 (반투명 오버레이)
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 170))
        screen.blit(overlay, (0, 0))

        # 글로우 효과
        glow_intensity = int(25 + 12 * math.sin(self.animation_timer * 3))
        glow_surf = pygame.Surface((menu_w + 20, menu_h + 20), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*BORDER_CYAN, glow_intensity), (0, 0, menu_w + 20, menu_h + 20), border_radius=12)
        screen.blit(glow_surf, (menu_x - 10, menu_y - 10))

        # 메뉴 배경
        pygame.draw.rect(screen, BG_DARK, (menu_x, menu_y, menu_w, menu_h), border_radius=8)
        pygame.draw.rect(screen, BORDER_CYAN, (menu_x, menu_y, menu_w, menu_h), 2, border_radius=8)

        # 상단 바
        pygame.draw.rect(screen, (25, 35, 55), (menu_x + 2, menu_y + 2, menu_w - 4, 40), border_radius=6)
        pygame.draw.line(screen, BORDER_GLOW, (menu_x + 10, menu_y + 44), (menu_x + menu_w - 10, menu_y + 44), 1)

        font_small = self.fonts.get('small')
        font_medium = self.fonts.get('medium')

        # 타이틀
        if font_medium:
            title_surf, title_rect = font_medium.render("환전", TEXT_WHITE)
            screen.blit(title_surf, (menu_x + menu_w // 2 - title_rect.width // 2, menu_y + 12))

        # 닫기 버튼 (X)
        close_btn = pygame.Rect(menu_x + menu_w - 35, menu_y + 8, 26, 26)
        pygame.draw.rect(screen, (60, 40, 40), close_btn, border_radius=4)
        pygame.draw.rect(screen, TEXT_RED, close_btn, 1, border_radius=4)
        pygame.draw.line(screen, TEXT_RED, (close_btn.x + 7, close_btn.y + 7), (close_btn.x + 19, close_btn.y + 19), 2)
        pygame.draw.line(screen, TEXT_RED, (close_btn.x + 19, close_btn.y + 7), (close_btn.x + 7, close_btn.y + 19), 2)

        # 현재 보유량 표시
        star_points = self.player_data.get('star_points', 0)
        gold = self.player_data.get('gold', 0)

        if font_small:
            # 스타포인트 보유량
            star_surf, _ = font_small.render(f"★ {star_points:,}", TEXT_CYAN)
            screen.blit(star_surf, (menu_x + 30, menu_y + 55))
            # 골드 보유량
            gold_surf, _ = font_small.render(f"G {gold:,}", TEXT_GOLD)
            screen.blit(gold_surf, (menu_x + 200, menu_y + 55))

        # 방향 전환 버튼
        dir_btn_y = menu_y + 78
        left_btn = pygame.Rect(menu_x + 30, dir_btn_y, 130, 36)
        right_btn = pygame.Rect(menu_x + 180, dir_btn_y, 130, 36)

        # 왼쪽 버튼 (스타포인트 → 골드)
        btn_color = HIGHLIGHT if self.exchange_direction == 0 else BTN_BG
        border_color = TEXT_CYAN if self.exchange_direction == 0 else BORDER_GLOW
        pygame.draw.rect(screen, btn_color, left_btn, border_radius=6)
        pygame.draw.rect(screen, border_color, left_btn, 2, border_radius=6)
        if font_small:
            txt_surf, txt_rect = font_small.render("★ → G", TEXT_CYAN if self.exchange_direction == 0 else TEXT_WHITE)
            screen.blit(txt_surf, (left_btn.centerx - txt_rect.width // 2, left_btn.centery - txt_rect.height // 2))

        # 오른쪽 버튼 (골드 → 스타포인트)
        btn_color = HIGHLIGHT if self.exchange_direction == 1 else BTN_BG
        border_color = TEXT_GOLD if self.exchange_direction == 1 else BORDER_GLOW
        pygame.draw.rect(screen, btn_color, right_btn, border_radius=6)
        pygame.draw.rect(screen, border_color, right_btn, 2, border_radius=6)
        if font_small:
            txt_surf, txt_rect = font_small.render("G → ★", TEXT_GOLD if self.exchange_direction == 1 else TEXT_WHITE)
            screen.blit(txt_surf, (right_btn.centerx - txt_rect.width // 2, right_btn.centery - txt_rect.height // 2))

        # === 가로 스크롤바 (슬라이더) ===
        slider_y = menu_y + 130
        slider_x = menu_x + 30
        slider_w = 280
        slider_h = 24

        # 최대값 계산
        if self.exchange_direction == 0:
            max_amount = max(1, star_points)
        else:
            max_amount = max(1, gold // self.current_exchange_rate) if self.current_exchange_rate > 0 else 1

        # 슬라이더 영역 저장 (클릭/휠 처리용)
        self._slider_rect = pygame.Rect(slider_x, slider_y, slider_w, slider_h)
        self._slider_max = max_amount

        # 슬라이더 배경
        pygame.draw.rect(screen, SLIDER_BG, (slider_x, slider_y, slider_w, slider_h), border_radius=12)
        pygame.draw.rect(screen, BORDER_GLOW, (slider_x, slider_y, slider_w, slider_h), 1, border_radius=12)

        # 슬라이더 채움 (현재 양 비율)
        fill_ratio = min(1.0, self.exchange_amount / max_amount) if max_amount > 0 else 0
        fill_w = int((slider_w - 4) * fill_ratio)
        if fill_w > 0:
            pygame.draw.rect(screen, SLIDER_FILL, (slider_x + 2, slider_y + 2, fill_w, slider_h - 4), border_radius=10)

        # 슬라이더 핸들 (동그란 노브)
        handle_x = slider_x + 2 + fill_w
        handle_y = slider_y + slider_h // 2
        pygame.draw.circle(screen, SLIDER_HANDLE, (handle_x, handle_y), 10)
        pygame.draw.circle(screen, TEXT_WHITE, (handle_x, handle_y), 6)

        # 양 표시 (슬라이더 위)
        if font_medium:
            amt_text = f"{self.exchange_amount:,}"
            amt_surf, amt_rect = font_medium.render(amt_text, TEXT_WHITE)
            screen.blit(amt_surf, (slider_x + slider_w // 2 - amt_rect.width // 2, slider_y - 22))

        # 최소/최대 라벨
        if font_small:
            min_surf, _ = font_small.render("1", (100, 110, 130))
            screen.blit(min_surf, (slider_x, slider_y + slider_h + 4))
            max_surf, max_rect = font_small.render(f"{max_amount:,}", (100, 110, 130))
            screen.blit(max_surf, (slider_x + slider_w - max_rect.width, slider_y + slider_h + 4))

        # 환전 결과 미리보기
        preview_y = menu_y + 175
        if self.exchange_direction == 0:
            result_gold = self.exchange_amount * self.current_exchange_rate
            if font_small:
                preview_text = f"★ {self.exchange_amount:,} → G {result_gold:,}"
                preview_surf, preview_rect = font_small.render(preview_text, TEXT_GREEN)
                screen.blit(preview_surf, (menu_x + menu_w // 2 - preview_rect.width // 2, preview_y))
        else:
            cost_gold = self.exchange_amount * self.current_exchange_rate
            if font_small:
                preview_text = f"G {cost_gold:,} → ★ {self.exchange_amount:,}"
                preview_surf, preview_rect = font_small.render(preview_text, TEXT_GREEN)
                screen.blit(preview_surf, (menu_x + menu_w // 2 - preview_rect.width // 2, preview_y))

        # 환율 정보
        rate_y = menu_y + 195
        if font_small:
            rate_text = f"환율: 1★ = {self.current_exchange_rate}G"
            rate_surf, rate_rect = font_small.render(rate_text, (120, 130, 150))
            screen.blit(rate_surf, (menu_x + menu_w // 2 - rate_rect.width // 2, rate_y))

        # 환전 실행 버튼
        confirm_btn = pygame.Rect(menu_x + 30, menu_y + 218, 280, 38)
        pygame.draw.rect(screen, (40, 80, 60), confirm_btn, border_radius=6)
        pygame.draw.rect(screen, TEXT_GREEN, confirm_btn, 2, border_radius=6)
        if font_medium:
            btn_surf, btn_rect = font_medium.render("환전하기", TEXT_GREEN)
            screen.blit(btn_surf, (confirm_btn.centerx - btn_rect.width // 2, confirm_btn.centery - btn_rect.height // 2))

        # 휠 힌트
        if font_small:
            hint_surf, _ = font_small.render("슬라이더 위에서 휠로 조절", (90, 100, 120))
            screen.blit(hint_surf, (menu_x + menu_w // 2 - 70, menu_y + menu_h - 16))

    def _draw_deposit_menu(self, screen):
        """예금 메뉴창 그리기 - SF 스타일 (2탭 구조)"""
        import math

        # 메뉴 크기 및 위치 (화면 중앙, 더 넓은 메뉴)
        menu_w, menu_h = 420, 340
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
        TEXT_GREEN = (100, 255, 150)
        TEXT_RED = (255, 100, 100)
        BTN_BG = (30, 45, 65)
        SLIDER_BG = (25, 35, 50)
        SLIDER_FILL = (100, 180, 80)  # 녹색 계열 (예금)
        SLIDER_HANDLE = (150, 220, 120)
        TAB_ACTIVE = (50, 80, 120)
        TAB_INACTIVE = (25, 35, 50)

        # 배경 어둡게 (반투명 오버레이)
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 170))
        screen.blit(overlay, (0, 0))

        # 글로우 효과
        glow_intensity = int(25 + 12 * math.sin(self.animation_timer * 3))
        glow_surf = pygame.Surface((menu_w + 20, menu_h + 20), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*TEXT_GREEN, glow_intensity), (0, 0, menu_w + 20, menu_h + 20), border_radius=12)
        screen.blit(glow_surf, (menu_x - 10, menu_y - 10))

        # 메뉴 배경
        pygame.draw.rect(screen, BG_DARK, (menu_x, menu_y, menu_w, menu_h), border_radius=8)
        pygame.draw.rect(screen, TEXT_GREEN, (menu_x, menu_y, menu_w, menu_h), 2, border_radius=8)

        font_small = self.fonts.get('small')
        font_medium = self.fonts.get('medium')

        # 닫기 버튼 (X)
        close_btn = pygame.Rect(menu_x + menu_w - 35, menu_y + 8, 26, 26)
        pygame.draw.rect(screen, (60, 40, 40), close_btn, border_radius=4)
        pygame.draw.rect(screen, TEXT_RED, close_btn, 1, border_radius=4)
        pygame.draw.line(screen, TEXT_RED, (close_btn.x + 7, close_btn.y + 7), (close_btn.x + 19, close_btn.y + 19), 2)
        pygame.draw.line(screen, TEXT_RED, (close_btn.x + 19, close_btn.y + 7), (close_btn.x + 7, close_btn.y + 19), 2)

        # === 탭 버튼 ===
        tab_y = menu_y + 10
        tab_w = 190
        tab_h = 36

        # 예금 탭
        tab1_color = TAB_ACTIVE if self.deposit_tab == 0 else TAB_INACTIVE
        tab1_border = TEXT_GREEN if self.deposit_tab == 0 else BORDER_GLOW
        tab1_btn = pygame.Rect(menu_x + 15, tab_y, tab_w, tab_h)
        pygame.draw.rect(screen, tab1_color, tab1_btn, border_radius=6)
        pygame.draw.rect(screen, tab1_border, tab1_btn, 2, border_radius=6)
        if font_small:
            txt_surf, txt_rect = font_small.render("예금/출금", TEXT_GREEN if self.deposit_tab == 0 else TEXT_WHITE)
            screen.blit(txt_surf, (tab1_btn.centerx - txt_rect.width // 2, tab1_btn.centery - txt_rect.height // 2))

        # 설명 탭
        tab2_color = TAB_ACTIVE if self.deposit_tab == 1 else TAB_INACTIVE
        tab2_border = TEXT_CYAN if self.deposit_tab == 1 else BORDER_GLOW
        tab2_btn = pygame.Rect(menu_x + 215, tab_y, tab_w, tab_h)
        pygame.draw.rect(screen, tab2_color, tab2_btn, border_radius=6)
        pygame.draw.rect(screen, tab2_border, tab2_btn, 2, border_radius=6)
        if font_small:
            txt_surf, txt_rect = font_small.render("시스템 설명", TEXT_CYAN if self.deposit_tab == 1 else TEXT_WHITE)
            screen.blit(txt_surf, (tab2_btn.centerx - txt_rect.width // 2, tab2_btn.centery - txt_rect.height // 2))

        # 구분선
        pygame.draw.line(screen, BORDER_GLOW, (menu_x + 15, tab_y + tab_h + 8), (menu_x + menu_w - 15, tab_y + tab_h + 8), 1)

        if self.deposit_tab == 0:
            # === 예금/출금 탭 ===
            gold = self.player_data.get('gold', 0)
            balance = self.player_data.get('deposit_balance', 0)
            interest_rate = self.deposit_interest_rate

            # 현재 보유량/잔액 표시
            info_y = menu_y + 58
            if font_small:
                gold_surf, _ = font_small.render(f"보유 골드: G {gold:,}", TEXT_GOLD)
                screen.blit(gold_surf, (menu_x + 30, info_y))
                balance_surf, _ = font_small.render(f"통장 잔액: G {balance:,}", TEXT_GREEN)
                screen.blit(balance_surf, (menu_x + 220, info_y))

            # 예금/출금 모드 전환 버튼
            mode_y = menu_y + 90
            deposit_btn = pygame.Rect(menu_x + 30, mode_y, 170, 36)
            withdraw_btn = pygame.Rect(menu_x + 220, mode_y, 170, 36)

            # 예금 버튼
            btn_color = HIGHLIGHT if not self.withdraw_mode else BTN_BG
            border_color = TEXT_GREEN if not self.withdraw_mode else BORDER_GLOW
            pygame.draw.rect(screen, btn_color, deposit_btn, border_radius=6)
            pygame.draw.rect(screen, border_color, deposit_btn, 2, border_radius=6)
            if font_small:
                txt_surf, txt_rect = font_small.render("예금하기", TEXT_GREEN if not self.withdraw_mode else TEXT_WHITE)
                screen.blit(txt_surf, (deposit_btn.centerx - txt_rect.width // 2, deposit_btn.centery - txt_rect.height // 2))

            # 출금 버튼
            btn_color = HIGHLIGHT if self.withdraw_mode else BTN_BG
            border_color = TEXT_GOLD if self.withdraw_mode else BORDER_GLOW
            pygame.draw.rect(screen, btn_color, withdraw_btn, border_radius=6)
            pygame.draw.rect(screen, border_color, withdraw_btn, 2, border_radius=6)
            if font_small:
                txt_surf, txt_rect = font_small.render("출금하기", TEXT_GOLD if self.withdraw_mode else TEXT_WHITE)
                screen.blit(txt_surf, (withdraw_btn.centerx - txt_rect.width // 2, withdraw_btn.centery - txt_rect.height // 2))

            # === 금액 슬라이더 ===
            slider_y = menu_y + 160
            slider_x = menu_x + 30
            slider_w = 360
            slider_h = 24

            # 최대값 계산
            if self.withdraw_mode:
                max_amount = max(0, balance)
            else:
                max_amount = max(0, gold)

            # 슬라이더 영역 저장
            self._deposit_slider_rect = pygame.Rect(slider_x, slider_y, slider_w, slider_h)
            self._deposit_slider_max = max_amount

            # 슬라이더 배경
            slider_fill_color = SLIDER_FILL if not self.withdraw_mode else (200, 170, 80)
            pygame.draw.rect(screen, SLIDER_BG, (slider_x, slider_y, slider_w, slider_h), border_radius=12)
            pygame.draw.rect(screen, BORDER_GLOW, (slider_x, slider_y, slider_w, slider_h), 1, border_radius=12)

            # 슬라이더 채움
            if max_amount > 0:
                fill_ratio = min(1.0, self.deposit_amount / max_amount)
            else:
                fill_ratio = 0
            fill_w = int((slider_w - 4) * fill_ratio)
            if fill_w > 0:
                pygame.draw.rect(screen, slider_fill_color, (slider_x + 2, slider_y + 2, fill_w, slider_h - 4), border_radius=10)

            # 슬라이더 핸들
            handle_x = slider_x + 2 + fill_w
            handle_y = slider_y + slider_h // 2
            handle_color = SLIDER_HANDLE if not self.withdraw_mode else (220, 190, 100)
            pygame.draw.circle(screen, handle_color, (handle_x, handle_y), 10)
            pygame.draw.circle(screen, TEXT_WHITE, (handle_x, handle_y), 6)

            # 금액 표시
            if font_medium:
                amt_text = f"G {self.deposit_amount:,}"
                amt_surf, amt_rect = font_medium.render(amt_text, TEXT_WHITE)
                screen.blit(amt_surf, (slider_x + slider_w // 2 - amt_rect.width // 2, slider_y - 24))

            # 최소/최대 라벨
            if font_small:
                min_surf, _ = font_small.render("0", (100, 110, 130))
                screen.blit(min_surf, (slider_x, slider_y + slider_h + 4))
                max_surf, max_rect = font_small.render(f"{max_amount:,}", (100, 110, 130))
                screen.blit(max_surf, (slider_x + slider_w - max_rect.width, slider_y + slider_h + 4))

            # 이자율 정보
            rate_y = menu_y + 210
            if font_small:
                rate_text = f"현재 이자율: {interest_rate*100:.1f}%"
                rate_surf, rate_rect = font_small.render(rate_text, TEXT_CYAN)
                screen.blit(rate_surf, (menu_x + menu_w // 2 - rate_rect.width // 2, rate_y))

            # 예상 수익 (예금 모드에서만)
            if not self.withdraw_mode and self.deposit_amount > 0:
                expected_y = menu_y + 232
                expected_balance = balance + self.deposit_amount
                expected_interest = int(expected_balance * interest_rate)
                expected_total = expected_balance + expected_interest
                if font_small:
                    exp_text = f"다음 스테이지 예상: G {expected_total:,} (+{expected_interest:,})"
                    exp_surf, exp_rect = font_small.render(exp_text, TEXT_GREEN)
                    screen.blit(exp_surf, (menu_x + menu_w // 2 - exp_rect.width // 2, expected_y))

            # 실행 버튼
            confirm_btn = pygame.Rect(menu_x + 30, menu_y + 280, 360, 42)
            if self.withdraw_mode:
                pygame.draw.rect(screen, (80, 65, 40), confirm_btn, border_radius=6)
                pygame.draw.rect(screen, TEXT_GOLD, confirm_btn, 2, border_radius=6)
                if font_medium:
                    btn_text = "출금하기"
                    btn_surf, btn_rect = font_medium.render(btn_text, TEXT_GOLD)
                    screen.blit(btn_surf, (confirm_btn.centerx - btn_rect.width // 2, confirm_btn.centery - btn_rect.height // 2))
            else:
                pygame.draw.rect(screen, (40, 80, 60), confirm_btn, border_radius=6)
                pygame.draw.rect(screen, TEXT_GREEN, confirm_btn, 2, border_radius=6)
                if font_medium:
                    btn_text = "예금하기"
                    btn_surf, btn_rect = font_medium.render(btn_text, TEXT_GREEN)
                    screen.blit(btn_surf, (confirm_btn.centerx - btn_rect.width // 2, confirm_btn.centery - btn_rect.height // 2))

        else:
            # === 설명 탭 ===
            desc_y = menu_y + 65
            line_height = 26
            descriptions = [
                "◆ STARBANK 예금 시스템 ◆",
                "",
                "▸ 골드를 예금하면 이자가 붙습니다",
                "▸ 이자는 매 스테이지마다 자동 적용됩니다",
                "",
                "▸ 복리 방식으로 계산됩니다",
                "  예) 1000G 예금, 이자율 10%",
                "      → 다음 스테이지: 1100G",
                "      → 이자율 15% 적용 시: 1265G",
                "",
                "▸ 은행을 건너뛰어도 이자가 쌓입니다!",
                "  스테이지2: 1000G 예금 (이자 10%)",
                "  스테이지3: 은행 안 감 (이자 15%)",
                "  스테이지4: 출금하면",
                "  → 1000 × 1.10 × 1.15 = 1265G",
                "",
                f"▸ 현재 이자율: {self.deposit_interest_rate*100:.1f}%",
                "▸ 이자율은 스테이지마다 변동됩니다",
            ]

            if font_small:
                for i, line in enumerate(descriptions):
                    if line.startswith("◆"):
                        color = TEXT_CYAN
                    elif line.startswith("▸"):
                        color = TEXT_WHITE
                    elif "예)" in line or "→" in line:
                        color = TEXT_GOLD
                    else:
                        color = (150, 160, 180)
                    text_surf, _ = font_small.render(line, color)
                    screen.blit(text_surf, (menu_x + 30, desc_y + i * line_height))

    def draw(self, screen):
        """건물 내부 그리기"""
        # 특수 인테리어 체크
        special_interior = self.config.get("special_interior")

        if special_interior == "bank":
            # 은행 전용 인테리어
            self._draw_bank_interior(screen)
        elif special_interior == "academy":
            # 아카데미 전용 인테리어
            self._draw_academy_interior(screen)
        elif special_interior == "neon_shop":
            # 네온 상점 전용 인테리어
            self._draw_neon_shop_interior(screen)
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

        # 환전 메뉴 (맨 위에)
        if self.exchange_menu_open:
            self._draw_exchange_menu(screen)

        # 예금 메뉴 (맨 위에)
        if self.deposit_menu_open:
            self._draw_deposit_menu(screen)

        # 아카데미 대화창 (맨 위에)
        if self.academy_dialog_open:
            self._draw_academy_dialog(screen)

    def _draw_academy_dialog(self, screen):
        """학장 아르카나와의 대화창 그리기"""
        # 대화창 크기 및 위치
        dialog_w, dialog_h = 320, 180
        dialog_x = (SCREEN_WIDTH - dialog_w) // 2
        dialog_y = (SCREEN_HEIGHT - dialog_h) // 2

        # 색상 정의 (마법학원 테마 - 보라색/금색)
        BG_DARK = (25, 15, 45)
        BORDER_PURPLE = (180, 100, 255)
        BORDER_GLOW = (120, 60, 180)
        TEXT_WHITE = (240, 245, 255)
        TEXT_GOLD = (255, 215, 100)
        TEXT_PURPLE = (200, 150, 255)
        BUTTON_BG = (50, 30, 80)
        BUTTON_SELECTED = (100, 60, 150)
        BUTTON_BORDER = (180, 100, 255)

        # 마우스 위치
        mouse_pos = pygame.mouse.get_pos()

        # 배경 어둡게 (반투명 오버레이)
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 160))
        screen.blit(overlay, (0, 0))

        # 대화창 배경
        dialog_surface = pygame.Surface((dialog_w, dialog_h), pygame.SRCALPHA)
        pygame.draw.rect(dialog_surface, (*BG_DARK, 240), (0, 0, dialog_w, dialog_h), border_radius=8)
        screen.blit(dialog_surface, (dialog_x, dialog_y))

        # 테두리 (글로우 효과)
        pygame.draw.rect(screen, BORDER_GLOW, (dialog_x - 2, dialog_y - 2, dialog_w + 4, dialog_h + 4), 3, border_radius=10)
        pygame.draw.rect(screen, BORDER_PURPLE, (dialog_x, dialog_y, dialog_w, dialog_h), 2, border_radius=8)

        # 제목 텍스트
        title_text = "핑파이터 견습생이시어"
        title2_text = "새로운 기술을 배우러 오셨습니까?"
        subtitle_text = "- 기술을 배우려면 스타포인트가 필요합니다 -"

        # freetype 폰트 사용 (self.fonts - 클래스에서 초기화됨)
        font_medium = self.fonts.get('medium')
        font_small = self.fonts.get('small')

        # 제목 렌더링 (freetype)
        if font_medium:
            title_surf, title_rect = font_medium.render(title_text, TEXT_WHITE)
            screen.blit(title_surf, (dialog_x + dialog_w // 2 - title_rect.width // 2, dialog_y + 25))

            title2_surf, title2_rect = font_medium.render(title2_text, TEXT_WHITE)
            screen.blit(title2_surf, (dialog_x + dialog_w // 2 - title2_rect.width // 2, dialog_y + 50))

        # 부제목 렌더링
        if font_small:
            subtitle_surf, subtitle_rect = font_small.render(subtitle_text, TEXT_GOLD)
            screen.blit(subtitle_surf, (dialog_x + dialog_w // 2 - subtitle_rect.width // 2, dialog_y + 85))

        # 버튼 영역
        btn_w, btn_h = 80, 32
        btn_y = dialog_y + dialog_h - 50
        yes_btn_x = dialog_x + dialog_w // 2 - btn_w - 20
        no_btn_x = dialog_x + dialog_w // 2 + 20

        yes_btn = pygame.Rect(yes_btn_x, btn_y, btn_w, btn_h)
        no_btn = pygame.Rect(no_btn_x, btn_y, btn_w, btn_h)

        # 예 버튼
        yes_hover = yes_btn.collidepoint(mouse_pos)
        yes_selected = self.academy_dialog_selection == 0
        yes_bg = BUTTON_SELECTED if (yes_selected or yes_hover) else BUTTON_BG
        pygame.draw.rect(screen, yes_bg, yes_btn, border_radius=5)
        pygame.draw.rect(screen, BUTTON_BORDER if yes_selected else BORDER_GLOW, yes_btn, 2, border_radius=5)
        if font_medium:
            yes_color = TEXT_WHITE if yes_selected else TEXT_PURPLE
            yes_surf, yes_rect = font_medium.render("예", yes_color)
            screen.blit(yes_surf, (yes_btn.centerx - yes_rect.width // 2, yes_btn.centery - yes_rect.height // 2))

        # 아니오 버튼
        no_hover = no_btn.collidepoint(mouse_pos)
        no_selected = self.academy_dialog_selection == 1
        no_bg = BUTTON_SELECTED if (no_selected or no_hover) else BUTTON_BG
        pygame.draw.rect(screen, no_bg, no_btn, border_radius=5)
        pygame.draw.rect(screen, BUTTON_BORDER if no_selected else BORDER_GLOW, no_btn, 2, border_radius=5)
        if font_medium:
            no_color = TEXT_WHITE if no_selected else TEXT_PURPLE
            no_surf, no_rect = font_medium.render("아니오", no_color)
            screen.blit(no_surf, (no_btn.centerx - no_rect.width // 2, no_btn.centery - no_rect.height // 2))

        # 선택 힌트
        if font_small:
            hint_text = "← → 선택  |  Enter 확인  |  ESC 닫기"
            hint_surf, hint_rect = font_small.render(hint_text, (150, 150, 180))
            screen.blit(hint_surf, (dialog_x + dialog_w // 2 - hint_rect.width // 2, dialog_y + dialog_h - 20))

    def _draw_bank_menu(self, screen):
        """은행 메뉴창 그리기 - SF 스타일 (마우스 호버 효과 포함)"""
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
        HOVER_BG = (35, 50, 70)  # 호버 배경색
        TEXT_WHITE = (240, 245, 255)
        TEXT_CYAN = (100, 200, 255)
        TEXT_GOLD = (255, 210, 100)
        TEXT_HOVER = (180, 220, 255)  # 호버 시 텍스트 색상

        # 마우스 위치 가져오기
        mouse_pos = pygame.mouse.get_pos()

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

            # 마우스 호버 체크
            is_hovered = item_rect.collidepoint(mouse_pos)
            is_selected = (i == self.bank_menu_selection)

            # 호버 시 선택 상태 업데이트
            if is_hovered:
                self.bank_menu_selection = i

            # 선택/호버 아이템 하이라이트
            if is_selected:
                # 선택 배경
                pygame.draw.rect(screen, HIGHLIGHT, item_rect, border_radius=4)
                pygame.draw.rect(screen, BORDER_CYAN, item_rect, 2, border_radius=4)

                # 선택 표시 (▶)
                if font_small:
                    arrow_surf, _ = font_small.render("▶", TEXT_CYAN)
                    screen.blit(arrow_surf, (item_rect.x + 8, item_rect.y + 8))

                text_color = TEXT_CYAN
            elif is_hovered:
                # 호버 배경 (선택은 아니지만 마우스가 위에 있음)
                pygame.draw.rect(screen, HOVER_BG, item_rect, border_radius=4)
                pygame.draw.rect(screen, BORDER_GLOW, item_rect, 1, border_radius=4)
                text_color = TEXT_HOVER
            else:
                # 비선택 배경
                pygame.draw.rect(screen, (25, 35, 50), item_rect, border_radius=4)
                text_color = TEXT_WHITE

            # 아이템 텍스트 및 아이콘
            if font_small:
                # 아이콘 그리기 (도형으로)
                icon_x = item_rect.x + 15
                icon_y = item_rect.y + item_h // 2 - 2

                # 호버/선택 시 아이콘 색상 변경
                icon_color = TEXT_GOLD if (is_selected or is_hovered) else (200, 170, 80)

                if item == "환전":
                    # 환전 아이콘: 양방향 화살표 (↔)
                    pygame.draw.polygon(screen, icon_color, [
                        (icon_x, icon_y), (icon_x + 6, icon_y - 4), (icon_x + 6, icon_y + 4)
                    ])
                    pygame.draw.polygon(screen, icon_color, [
                        (icon_x + 16, icon_y), (icon_x + 10, icon_y - 4), (icon_x + 10, icon_y + 4)
                    ])
                    pygame.draw.rect(screen, icon_color, (icon_x + 4, icon_y - 1, 8, 2))
                elif item == "예금/출금":
                    # 예금/출금 아이콘: 동전 (●)
                    pygame.draw.circle(screen, icon_color, (icon_x + 8, icon_y), 7)
                    pygame.draw.circle(screen, (180, 140, 50), (icon_x + 8, icon_y), 7, 1)
                    pygame.draw.line(screen, (180, 140, 50), (icon_x + 8, icon_y - 4), (icon_x + 8, icon_y + 4), 1)
                else:
                    # 나가기 아이콘: 문 (□→)
                    pygame.draw.rect(screen, text_color, (icon_x, icon_y - 6, 10, 12), 1)
                    pygame.draw.polygon(screen, text_color, [
                        (icon_x + 12, icon_y), (icon_x + 18, icon_y), (icon_x + 15, icon_y - 3)
                    ])
                    pygame.draw.polygon(screen, text_color, [
                        (icon_x + 12, icon_y), (icon_x + 18, icon_y), (icon_x + 15, icon_y + 3)
                    ])

                item_surf, _ = font_small.render(item, text_color)
                screen.blit(item_surf, (item_rect.x + 40, item_rect.y + 8))

    def _draw_academy_interior(self, screen):
        """아카데미 전용 인테리어 - 마법 도서관 스타일"""
        import math

        # 색상 팔레트 (청록색/시안 계열 마법 테마)
        BG_DARK = (15, 35, 35)           # 어두운 청록 배경
        FLOOR_A = (35, 65, 65)           # 바닥 타일 A
        FLOOR_B = (45, 75, 75)           # 바닥 타일 B
        WALL_COLOR = (25, 50, 50)        # 벽 색상
        ACCENT_CYAN = (100, 255, 200)    # 발광 청록 (마법진)
        ACCENT_CYAN_DIM = (60, 150, 120) # 어두운 청록
        MAGIC_GLOW = (120, 255, 220)     # 마법 발광
        WOOD_DARK = (60, 45, 30)         # 어두운 나무
        WOOD_MID = (90, 65, 40)          # 중간 나무
        WOOD_LIGHT = (120, 90, 55)       # 밝은 나무
        GOLD = (255, 200, 100)           # 금색 (장식)
        FLAME_ORANGE = (255, 150, 50)    # 횃불 불꽃
        FLAME_YELLOW = (255, 220, 100)   # 횃불 밝은 불꽃
        WHITE = (240, 245, 250)

        cam_x, cam_y = self.camera_offset
        cx = self.pixel_width // 2  # 중앙 X
        cy = self.pixel_height // 2  # 중앙 Y

        # 장애물 영역 설정 (플레이어/NPC 이동 불가)
        wall_h = int(TILE_SIZE * 3.5)
        shelf_w = 70
        shelf_h = 180
        desk_w = 80
        desk_h = 75  # 책상 + 다리 높이

        # 장애물 영역 리스트 초기화
        self.academy_obstacle_rects = []

        # 1) 상단 벽 영역
        self.academy_obstacle_rects.append(pygame.Rect(0, 0, self.pixel_width, wall_h))

        # 2) 왼쪽 책장들 (3개)
        shelf_y = wall_h + 20
        for i in range(3):
            sx = 15 + i * (shelf_w + 10)
            self.academy_obstacle_rects.append(pygame.Rect(sx, shelf_y - 15, shelf_w, shelf_h + 15))

        # 3) 오른쪽 책장들 (3개)
        for i in range(3):
            sx = self.pixel_width - 15 - (i + 1) * (shelf_w + 10) + 10
            self.academy_obstacle_rects.append(pygame.Rect(sx, shelf_y - 15, shelf_w, shelf_h + 15))

        # 4) 책상들 (4개)
        center_x = self.pixel_width // 2
        center_y = self.pixel_height // 2
        desk_positions = [
            (center_x - 180, center_y - 80),
            (center_x - 180, center_y + 60),
            (center_x + 100, center_y - 80),
            (center_x + 100, center_y + 60),
        ]
        for dx, dy in desk_positions:
            self.academy_obstacle_rects.append(pygame.Rect(dx, dy, desk_w, desk_h))

        # 1. 배경
        screen.fill(BG_DARK)

        # 2. 바닥 타일 (기본 격자)
        for ty in range(self.map_height):
            for tx in range(self.map_width):
                tile_x = tx * TILE_SIZE - cam_x
                tile_y = ty * TILE_SIZE - cam_y
                color = FLOOR_A if (tx + ty) % 2 == 0 else FLOOR_B
                pygame.draw.rect(screen, color, (tile_x, tile_y, TILE_SIZE, TILE_SIZE))

        # 3. 마법진 (중앙 바닥에 큰 원형 룬)
        self._draw_magic_circle(screen, cx - cam_x, cy - cam_y, self.animation_timer)

        # 4. 상단 벽
        wall_h = int(TILE_SIZE * 3.5)
        pygame.draw.rect(screen, WALL_COLOR, (-cam_x, -cam_y, self.pixel_width, wall_h))

        # 벽 하단 장식 라인
        pygame.draw.rect(screen, ACCENT_CYAN_DIM, (-cam_x, -cam_y + wall_h - 4, self.pixel_width, 4))

        # 5. 창문들 (상단 벽)
        self._draw_academy_windows(screen, cam_x, cam_y, wall_h, self.animation_timer)

        # 6. 건물 이름 표시 (아카데미)
        sign_y = -cam_y + 15
        sign_x = cx - cam_x

        # 로고 배경 패널
        panel_w, panel_h = 140, 32
        pygame.draw.rect(screen, (20, 40, 40), (sign_x - panel_w//2, sign_y - 3, panel_w, panel_h), border_radius=6)
        pygame.draw.rect(screen, ACCENT_CYAN, (sign_x - panel_w//2, sign_y - 3, panel_w, panel_h), 2, border_radius=6)

        # 로고 글로우
        glow_intensity = int(40 + 25 * math.sin(self.animation_timer * 1.5))
        glow_surf = pygame.Surface((panel_w + 16, panel_h + 16), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*ACCENT_CYAN, glow_intensity), (0, 0, panel_w + 16, panel_h + 16), border_radius=10)
        screen.blit(glow_surf, (sign_x - panel_w//2 - 8, sign_y - 11))

        # 로고 텍스트
        font_large = self.fonts.get('large')
        if font_large:
            text_surf, text_rect = font_large.render("아카데미", ACCENT_CYAN)
            screen.blit(text_surf, (sign_x - text_rect.width // 2, sign_y + 2))

        # 7. 책장들 (좌우 벽)
        self._draw_bookshelves(screen, cam_x, cam_y, wall_h)

        # 8. 횃불들 (벽면)
        self._draw_wall_torches(screen, cam_x, cam_y, wall_h, self.animation_timer)

        # 9. 책상들 (중앙 영역)
        self._draw_study_desks(screen, cam_x, cam_y, wall_h)

        # 10. 문 그리기
        self._draw_door(screen)

    def _draw_magic_circle(self, screen, cx, cy, anim_timer):
        """마법진 그리기 (바닥 중앙)"""
        import math

        MAGIC_CYAN = (100, 255, 200)
        MAGIC_DIM = (50, 150, 120)
        MAGIC_GLOW = (80, 200, 160)

        # 마법진 크기
        outer_radius = 140
        inner_radius = 100
        center_radius = 40

        # 회전 애니메이션
        rotation = anim_timer * 0.3

        # 글로우 효과 (배경)
        glow_intensity = int(30 + 15 * math.sin(anim_timer * 2))
        for r in range(outer_radius + 30, outer_radius, -5):
            alpha = max(0, glow_intensity - (r - outer_radius) * 2)
            glow_surf = pygame.Surface((r * 2, r * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*MAGIC_DIM, alpha), (r, r), r)
            screen.blit(glow_surf, (cx - r, cy - r))

        # 외부 원
        pygame.draw.circle(screen, MAGIC_CYAN, (int(cx), int(cy)), outer_radius, 3)
        pygame.draw.circle(screen, MAGIC_DIM, (int(cx), int(cy)), outer_radius - 8, 2)

        # 중간 원
        pygame.draw.circle(screen, MAGIC_CYAN, (int(cx), int(cy)), inner_radius, 2)

        # 내부 원
        pygame.draw.circle(screen, MAGIC_GLOW, (int(cx), int(cy)), center_radius, 2)

        # 룬 심볼들 (외부 원 주위)
        for i in range(12):
            angle = rotation + (i * math.pi / 6)
            rx = cx + (outer_radius - 15) * math.cos(angle)
            ry = cy + (outer_radius - 15) * math.sin(angle)

            # 작은 원 (룬 포인트)
            pulse = 3 + int(2 * math.sin(anim_timer * 3 + i))
            pygame.draw.circle(screen, MAGIC_CYAN, (int(rx), int(ry)), pulse)

        # 별 모양 (중앙)
        star_points = []
        for i in range(10):
            angle = -math.pi / 2 + rotation + (i * math.pi / 5)
            r = center_radius - 5 if i % 2 == 0 else (center_radius - 5) * 0.4
            star_points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
        pygame.draw.polygon(screen, MAGIC_CYAN, star_points, 2)

        # 삼각형 패턴 (내부)
        for i in range(3):
            angle1 = rotation * 0.5 + (i * 2 * math.pi / 3)
            angle2 = angle1 + (2 * math.pi / 3)
            angle3 = angle2 + (2 * math.pi / 3)

            tri_r = inner_radius - 15
            points = [
                (cx + tri_r * math.cos(angle1), cy + tri_r * math.sin(angle1)),
                (cx + tri_r * math.cos(angle2), cy + tri_r * math.sin(angle2)),
                (cx + tri_r * math.cos(angle3), cy + tri_r * math.sin(angle3))
            ]
            pygame.draw.polygon(screen, MAGIC_DIM, points, 1)

        # 연결선 (중앙에서 외부로)
        for i in range(6):
            angle = rotation * 0.7 + (i * math.pi / 3)
            x1 = cx + center_radius * math.cos(angle)
            y1 = cy + center_radius * math.sin(angle)
            x2 = cx + inner_radius * math.cos(angle)
            y2 = cy + inner_radius * math.sin(angle)
            pygame.draw.line(screen, MAGIC_DIM, (int(x1), int(y1)), (int(x2), int(y2)), 1)

    def _draw_academy_windows(self, screen, cam_x, cam_y, wall_h, anim_timer):
        """아카데미 창문들 (상단 벽)"""
        import math

        FRAME_COLOR = (80, 100, 90)      # 창틀
        GLASS_COLOR = (60, 100, 110)     # 유리
        LIGHT_COLOR = (150, 200, 180)    # 빛

        # 창문 설정
        window_w = 50
        window_h = 60
        window_y = -cam_y + 30

        # 창문 개수와 간격
        num_windows = 5
        spacing = self.pixel_width // (num_windows + 1)

        for i in range(num_windows):
            wx = -cam_x + spacing * (i + 1) - window_w // 2

            # 창문 배경 (유리)
            pygame.draw.rect(screen, GLASS_COLOR, (wx, window_y, window_w, window_h))

            # 빛 효과 (애니메이션)
            light_intensity = int(100 + 50 * math.sin(anim_timer * 1.2 + i * 0.5))
            light_surf = pygame.Surface((window_w - 8, window_h - 8), pygame.SRCALPHA)
            light_surf.fill((*LIGHT_COLOR, light_intensity))
            screen.blit(light_surf, (wx + 4, window_y + 4))

            # 창틀 (십자)
            pygame.draw.rect(screen, FRAME_COLOR, (wx, window_y, window_w, window_h), 3)
            pygame.draw.line(screen, FRAME_COLOR, (wx + window_w // 2, window_y),
                           (wx + window_w // 2, window_y + window_h), 2)
            pygame.draw.line(screen, FRAME_COLOR, (wx, window_y + window_h // 2),
                           (wx + window_w, window_y + window_h // 2), 2)

            # 상단 아치 장식
            pygame.draw.arc(screen, FRAME_COLOR,
                          (wx - 2, window_y - 15, window_w + 4, 30), 0, math.pi, 3)

    def _draw_bookshelves(self, screen, cam_x, cam_y, wall_h):
        """책장들 그리기 (좌우 벽)"""
        WOOD_DARK = (50, 35, 25)
        WOOD_MID = (80, 55, 35)
        WOOD_LIGHT = (110, 80, 50)

        # 책 색상들
        BOOK_COLORS = [
            (150, 50, 50),    # 빨강
            (50, 100, 150),   # 파랑
            (50, 130, 80),    # 초록
            (130, 100, 50),   # 갈색
            (100, 50, 120),   # 보라
            (150, 120, 50),   # 노랑
            (80, 80, 100),    # 회색
        ]

        # 책장 크기
        shelf_w = 70
        shelf_h = 180
        shelf_y = -cam_y + wall_h + 20

        # 왼쪽 책장들
        for i in range(3):
            sx = -cam_x + 15 + i * (shelf_w + 10)
            self._draw_single_bookshelf(screen, sx, shelf_y, shelf_w, shelf_h,
                                       WOOD_DARK, WOOD_MID, WOOD_LIGHT, BOOK_COLORS, i)

        # 오른쪽 책장들
        for i in range(3):
            sx = self.pixel_width - cam_x - 15 - (i + 1) * (shelf_w + 10) + 10
            self._draw_single_bookshelf(screen, sx, shelf_y, shelf_w, shelf_h,
                                       WOOD_DARK, WOOD_MID, WOOD_LIGHT, BOOK_COLORS, i + 3)

    def _draw_single_bookshelf(self, screen, x, y, w, h, wood_dark, wood_mid, wood_light, book_colors, seed):
        """단일 책장 그리기"""
        import random
        random.seed(seed * 42)  # 일관된 책 배치

        # 책장 프레임
        pygame.draw.rect(screen, wood_dark, (x, y, w, h))
        pygame.draw.rect(screen, wood_mid, (x, y, w, h), 3)

        # 선반 (4개)
        shelf_spacing = h // 4
        for s in range(4):
            sy = y + s * shelf_spacing
            # 선반 판
            pygame.draw.rect(screen, wood_mid, (x + 3, sy, w - 6, 5))
            pygame.draw.rect(screen, wood_light, (x + 3, sy, w - 6, 2))

            # 책들 (각 선반에 랜덤 배치)
            if s < 3:  # 맨 아래 선반은 빈 공간
                book_x = x + 6
                while book_x < x + w - 15:
                    book_w = random.randint(8, 14)
                    book_h = random.randint(25, 38)
                    book_color = random.choice(book_colors)

                    # 책 본체
                    book_y = sy + shelf_spacing - book_h - 3
                    pygame.draw.rect(screen, book_color, (book_x, book_y, book_w, book_h))

                    # 책 등 하이라이트
                    pygame.draw.rect(screen, tuple(min(255, c + 30) for c in book_color),
                                   (book_x, book_y, 2, book_h))

                    book_x += book_w + random.randint(1, 3)

        # 상단 장식 (삼각형 지붕)
        pygame.draw.polygon(screen, wood_mid, [
            (x, y), (x + w // 2, y - 15), (x + w, y)
        ])
        pygame.draw.polygon(screen, wood_light, [
            (x, y), (x + w // 2, y - 15), (x + w, y)
        ], 2)

    def _draw_wall_torches(self, screen, cam_x, cam_y, wall_h, anim_timer):
        """벽면 횃불들"""
        import math
        import random

        TORCH_HOLDER = (60, 50, 40)      # 횃불 거치대
        TORCH_WOOD = (80, 60, 40)        # 횃불 나무
        FLAME_ORANGE = (255, 150, 50)    # 불꽃 오렌지
        FLAME_YELLOW = (255, 220, 100)   # 불꽃 노랑
        FLAME_RED = (255, 100, 50)       # 불꽃 빨강

        # 횃불 위치 (좌우 대칭)
        torch_positions = [
            (-cam_x + 100, -cam_y + wall_h - 40),
            (-cam_x + 220, -cam_y + wall_h - 40),
            (self.pixel_width - cam_x - 100, -cam_y + wall_h - 40),
            (self.pixel_width - cam_x - 220, -cam_y + wall_h - 40),
        ]

        for i, (tx, ty) in enumerate(torch_positions):
            # 거치대
            pygame.draw.rect(screen, TORCH_HOLDER, (tx - 8, ty, 16, 25))
            pygame.draw.rect(screen, (80, 70, 60), (tx - 8, ty, 16, 25), 2)

            # 횃불 막대
            pygame.draw.rect(screen, TORCH_WOOD, (tx - 4, ty - 30, 8, 35))

            # 불꽃 (애니메이션)
            flame_offset = math.sin(anim_timer * 8 + i * 1.5) * 2
            flame_size = 12 + int(4 * math.sin(anim_timer * 6 + i))

            # 불꽃 글로우
            glow_surf = pygame.Surface((flame_size * 4, flame_size * 4), pygame.SRCALPHA)
            glow_alpha = int(60 + 30 * math.sin(anim_timer * 5 + i))
            pygame.draw.circle(glow_surf, (*FLAME_ORANGE, glow_alpha),
                             (flame_size * 2, flame_size * 2), flame_size * 2)
            screen.blit(glow_surf, (tx - flame_size * 2, ty - 45 - flame_size * 2))

            # 불꽃 코어
            flame_points = [
                (tx + flame_offset, ty - 35),
                (tx - 8, ty - 45),
                (tx - 4 + flame_offset * 0.5, ty - 55 - flame_size),
                (tx + 4 + flame_offset * 0.5, ty - 55 - flame_size),
                (tx + 8, ty - 45),
            ]
            pygame.draw.polygon(screen, FLAME_ORANGE, flame_points)

            # 내부 밝은 불꽃
            inner_points = [
                (tx + flame_offset * 0.5, ty - 38),
                (tx - 4, ty - 45),
                (tx + flame_offset * 0.3, ty - 50 - flame_size // 2),
                (tx + 4, ty - 45),
            ]
            pygame.draw.polygon(screen, FLAME_YELLOW, inner_points)

    def _draw_study_desks(self, screen, cam_x, cam_y, wall_h):
        """책상들 그리기 (중앙 영역)"""
        DESK_DARK = (70, 55, 40)
        DESK_MID = (100, 80, 55)
        DESK_LIGHT = (130, 105, 75)
        PAPER_WHITE = (240, 235, 220)

        # 책상 크기
        desk_w = 80
        desk_h = 50

        # 책상 위치 (마법진 주변 - 2열 x 3행)
        center_x = self.pixel_width // 2
        center_y = self.pixel_height // 2

        desk_positions = [
            # 좌측 열
            (center_x - 180, center_y - 80),
            (center_x - 180, center_y + 60),
            # 우측 열
            (center_x + 100, center_y - 80),
            (center_x + 100, center_y + 60),
        ]

        for dx, dy in desk_positions:
            desk_x = dx - cam_x
            desk_y = dy - cam_y

            # 책상 상판
            pygame.draw.rect(screen, DESK_MID, (desk_x, desk_y, desk_w, desk_h))
            pygame.draw.rect(screen, DESK_LIGHT, (desk_x, desk_y, desk_w, 5))
            pygame.draw.rect(screen, DESK_DARK, (desk_x, desk_y, desk_w, desk_h), 2)

            # 책상 다리
            pygame.draw.rect(screen, DESK_DARK, (desk_x + 5, desk_y + desk_h, 8, 25))
            pygame.draw.rect(screen, DESK_DARK, (desk_x + desk_w - 13, desk_y + desk_h, 8, 25))

            # 책상 위 물건들 (책, 종이)
            # 책
            pygame.draw.rect(screen, (100, 60, 60), (desk_x + 10, desk_y + 8, 20, 15))
            pygame.draw.rect(screen, (120, 80, 80), (desk_x + 10, desk_y + 8, 20, 3))

            # 종이
            pygame.draw.rect(screen, PAPER_WHITE, (desk_x + 40, desk_y + 10, 25, 30))
            pygame.draw.rect(screen, (200, 195, 180), (desk_x + 40, desk_y + 10, 25, 30), 1)

            # 종이 위 글씨 (작은 선들)
            for line in range(5):
                pygame.draw.line(screen, (150, 145, 130),
                               (desk_x + 44, desk_y + 15 + line * 5),
                               (desk_x + 60, desk_y + 15 + line * 5), 1)

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

    # ==========================================================================
    # 네온 상점 전용 인테리어
    # ==========================================================================

    def _create_neon_shop_npcs(self):
        """네온 상점 전용 NPC 생성 - 인간 상인 + 로봇 상인"""
        npcs = []

        # 카운터 중앙 위치 계산
        counter_y = int(self.pixel_height * 0.32)  # 카운터 높이
        counter_center_x = self.pixel_width // 2

        # === 1. 인간 상인 (점주 그린) - 카운터 왼쪽 ===
        human_x = counter_center_x - 60
        human_y = counter_y

        human_merchant = InteriorNPC(
            human_x, human_y,
            "점주 그린",
            "main",
            (0, 255, 100),  # 녹색 계열
            [
                "어서오세요, 고객님!",
                "오늘은 좋은 물건이 많이 들어왔습니다.",
                "필요한 게 있으시면 말씀하세요~"
            ],
            self.building_type
        )
        human_merchant.is_shop_human = True  # 인간 상인 표시
        npcs.append(human_merchant)

        # === 2. 로봇 상인 - 카운터 오른쪽 ===
        robot_x = counter_center_x + 60
        robot_y = counter_y

        robot_merchant = InteriorNPC(
            robot_x, robot_y,
            "상점 로봇",
            "staff",
            (100, 200, 255),  # 시안 계열
            [
                "삐빅... 환영합니다, 고객님.",
                "재고 현황 분석 중...",
                "최적의 상품을 추천해 드리겠습니다."
            ],
            self.building_type
        )
        robot_merchant.is_shop_robot = True  # 로봇 상인 표시
        npcs.append(robot_merchant)

        # === 3. 고객 NPC (2~4명) ===
        customer_count = random.randint(2, 4)
        customer_colors = [
            (255, 150, 180), (180, 150, 255), (150, 255, 200),
            (255, 200, 150), (200, 200, 255)
        ]

        # 고객 배치 가능 영역 (하단 2/3)
        customer_zone_top = int(self.pixel_height * 0.45)
        customer_zone_bottom = int(self.pixel_height * 0.85)
        customer_zone_left = int(self.pixel_width * 0.15)
        customer_zone_right = int(self.pixel_width * 0.85)

        for i in range(customer_count):
            x = random.randint(customer_zone_left, customer_zone_right)
            y = random.randint(customer_zone_top, customer_zone_bottom)

            # 다른 NPC와 겹치지 않게
            attempts = 0
            while attempts < 15:
                too_close = False
                for existing in npcs:
                    if abs(x - existing.x) < 50 and abs(y - existing.y) < 50:
                        too_close = True
                        break
                if not too_close:
                    break
                x = random.randint(customer_zone_left, customer_zone_right)
                y = random.randint(customer_zone_top, customer_zone_bottom)
                attempts += 1

            name = random.choice(InteriorNPC.NPC_NAMES["customer"])
            dialogue = random.choice(InteriorNPC.CUSTOMER_DIALOGUES)

            customer = InteriorNPC(
                x, y, name, "customer",
                customer_colors[i % len(customer_colors)],
                dialogue, self.building_type
            )
            npcs.append(customer)

        return npcs

    def _draw_neon_shop_interior(self, screen):
        """네온 상점 전용 인테리어 그리기 - 스타듀밸리 모험가 길드 스타일"""
        import math

        # 색상 정의 (나무/따뜻한 분위기 + 네온 강조)
        BG_DARK = (25, 18, 15)  # 어두운 나무색 배경
        FLOOR_WOOD = (65, 45, 30)  # 나무 바닥
        FLOOR_WOOD_DARK = (50, 35, 22)
        WALL_WOOD = (55, 38, 25)  # 나무 벽
        WALL_WOOD_DARK = (40, 28, 18)
        COUNTER_WOOD = (80, 55, 35)  # 카운터 나무색
        COUNTER_TOP = (100, 75, 50)  # 카운터 상판
        SHELF_WOOD = (70, 50, 32)  # 선반 나무색
        ACCENT_CYAN = (0, 255, 255)  # 네온 시안
        ACCENT_PINK = (255, 50, 150)  # 네온 핑크
        ACCENT_GOLD = (255, 200, 80)  # 금색

        cam_x, cam_y = self.camera_offset

        # 1. 배경 채우기
        screen.fill(BG_DARK)

        # 2. 나무 바닥 그리기 (스타듀밸리 스타일)
        self._draw_wood_floor_neon(screen, cam_x, cam_y, FLOOR_WOOD, FLOOR_WOOD_DARK)

        # 3. 상단 벽 (나무 패널 + 장식)
        wall_h = int(TILE_SIZE * 4.5)  # 벽 높이
        wall_rect = pygame.Rect(-cam_x, -cam_y, self.pixel_width, wall_h)
        pygame.draw.rect(screen, WALL_WOOD, wall_rect)

        # 벽 패널 라인
        for i in range(0, self.pixel_width, 60):
            panel_x = i - cam_x
            pygame.draw.line(screen, WALL_WOOD_DARK, (panel_x, -cam_y), (panel_x, wall_h - cam_y), 2)

        # 4. 벽 상단 장식 - 무기/방패/포션 선반
        self._draw_wall_decorations_neon(screen, cam_x, cam_y, wall_h, ACCENT_CYAN, ACCENT_PINK, ACCENT_GOLD)

        # 5. 메인 카운터 (중앙)
        counter_y = wall_h + int(TILE_SIZE * 0.5)
        counter_h = int(TILE_SIZE * 2)
        counter_w = int(self.pixel_width * 0.6)
        counter_x = (self.pixel_width - counter_w) // 2

        self._draw_main_counter_neon(screen, counter_x - cam_x, counter_y - cam_y,
                                      counter_w, counter_h, COUNTER_WOOD, COUNTER_TOP, ACCENT_CYAN)

        # 6. 좌측 진열대 (가판대)
        left_shelf_x = int(TILE_SIZE * 1.5)
        shelf_h = int(TILE_SIZE * 4)
        self._draw_display_shelf_neon(screen, left_shelf_x - cam_x, counter_y - cam_y,
                                       int(TILE_SIZE * 2.5), shelf_h, SHELF_WOOD, ACCENT_CYAN, "left")

        # 7. 우측 진열대 (가판대)
        right_shelf_x = self.pixel_width - int(TILE_SIZE * 4)
        self._draw_display_shelf_neon(screen, right_shelf_x - cam_x, counter_y - cam_y,
                                       int(TILE_SIZE * 2.5), shelf_h, SHELF_WOOD, ACCENT_PINK, "right")

        # 8. 좌우 벽 장식 횃불/램프
        self._draw_wall_lamps_neon(screen, cam_x, cam_y, wall_h, ACCENT_GOLD)

        # 9. 문 그리기
        self._draw_door(screen)

    def _draw_wood_floor_neon(self, screen, cam_x, cam_y, floor_color, floor_dark):
        """나무 바닥 그리기 (체크 패턴)"""
        tile_w = TILE_SIZE
        tile_h = TILE_SIZE // 2  # 나무 판자 느낌

        start_x = max(0, int(cam_x // tile_w))
        start_y = max(0, int(cam_y // tile_h))
        end_x = min(self.map_width * 2, start_x + SCREEN_WIDTH // tile_w + 3)
        end_y = min(self.map_height * 2, start_y + SCREEN_HEIGHT // tile_h + 3)

        for ty in range(start_y, end_y):
            for tx in range(start_x, end_x):
                tile_x = tx * tile_w - cam_x
                tile_y = ty * tile_h - cam_y

                # 체크 패턴
                color = floor_color if (tx + ty) % 2 == 0 else floor_dark
                pygame.draw.rect(screen, color, (tile_x, tile_y, tile_w, tile_h))

                # 나무결 라인
                if (tx + ty) % 3 == 0:
                    line_y = tile_y + tile_h // 2
                    line_color = tuple(max(0, c - 15) for c in color)
                    pygame.draw.line(screen, line_color, (tile_x + 5, line_y), (tile_x + tile_w - 5, line_y), 1)

    def _draw_wall_decorations_neon(self, screen, cam_x, cam_y, wall_h, accent1, accent2, accent_gold):
        """벽 장식 - 무기, 방패, 포션병 등"""
        center_x = self.pixel_width // 2

        # 상단 중앙: 대형 방패 2개 (좌우)
        shield_y = int(wall_h * 0.15)
        self._draw_shield_decoration(screen, center_x - 100 - cam_x, shield_y - cam_y, (50, 100, 200), accent_gold)
        self._draw_shield_decoration(screen, center_x + 60 - cam_x, shield_y - cam_y, (200, 50, 50), accent_gold)

        # 중앙 상단: 검 진열대
        sword_y = int(wall_h * 0.2)
        for i, offset in enumerate([-180, -120, -60, 0, 60, 120, 180]):
            sword_x = center_x + offset - cam_x
            sword_color = [(150, 180, 200), (200, 150, 100), (180, 200, 180),
                          (200, 180, 220), (150, 200, 200), (220, 180, 150), (180, 150, 200)][i % 7]
            self._draw_sword_decoration(screen, sword_x, sword_y - cam_y, sword_color)

        # 중간: 포션 선반
        potion_y = int(wall_h * 0.55)
        potion_colors = [(255, 100, 100), (100, 255, 100), (100, 150, 255),
                        (255, 255, 100), (255, 150, 255), (150, 255, 255)]
        for i, offset in enumerate(range(-200, 220, 70)):
            potion_x = center_x + offset - cam_x
            self._draw_potion_bottle(screen, potion_x, potion_y - cam_y, potion_colors[i % len(potion_colors)])

        # 하단 선반: 책과 스크롤
        book_y = int(wall_h * 0.75)
        book_colors = [(150, 50, 50), (50, 100, 150), (50, 150, 50),
                      (150, 100, 50), (100, 50, 150)]
        for i, offset in enumerate(range(-250, 270, 40)):
            book_x = center_x + offset - cam_x
            self._draw_book_decoration(screen, book_x, book_y - cam_y, book_colors[i % len(book_colors)])

    def _draw_shield_decoration(self, screen, x, y, color, accent):
        """방패 장식 그리기"""
        # 방패 본체
        shield_w, shield_h = 35, 45
        points = [
            (x + shield_w // 2, y),  # 상단 중앙
            (x + shield_w, y + shield_h // 3),  # 우상단
            (x + shield_w, y + shield_h * 2 // 3),  # 우하단
            (x + shield_w // 2, y + shield_h),  # 하단 뾰족
            (x, y + shield_h * 2 // 3),  # 좌하단
            (x, y + shield_h // 3),  # 좌상단
        ]
        pygame.draw.polygon(screen, color, points)
        pygame.draw.polygon(screen, accent, points, 2)

        # 중앙 엠블럼
        emblem_cx = x + shield_w // 2
        emblem_cy = y + shield_h // 2
        pygame.draw.circle(screen, accent, (emblem_cx, emblem_cy), 8)
        pygame.draw.circle(screen, color, (emblem_cx, emblem_cy), 5)

    def _draw_sword_decoration(self, screen, x, y, color):
        """검 장식 그리기 (세로로 걸림)"""
        blade_color = color
        hilt_color = (80, 60, 40)

        # 검날 (세로)
        pygame.draw.rect(screen, blade_color, (x - 2, y, 4, 50))
        # 검끝
        pygame.draw.polygon(screen, blade_color, [(x - 2, y + 50), (x + 2, y + 50), (x, y + 58)])
        # 손잡이
        pygame.draw.rect(screen, hilt_color, (x - 6, y - 5, 12, 8))
        pygame.draw.rect(screen, (60, 45, 30), (x - 2, y - 12, 4, 10))
        # 하이라이트
        pygame.draw.line(screen, (255, 255, 255, 100), (x, y + 5), (x, y + 45), 1)

    def _draw_potion_bottle(self, screen, x, y, color):
        """포션병 그리기"""
        bottle_color = (200, 200, 220)

        # 병 목
        pygame.draw.rect(screen, bottle_color, (x - 3, y - 8, 6, 8))
        # 병 몸통
        pygame.draw.ellipse(screen, color, (x - 8, y, 16, 20))
        # 코르크
        pygame.draw.rect(screen, (139, 90, 43), (x - 4, y - 12, 8, 5))
        # 반짝임
        pygame.draw.circle(screen, (255, 255, 255), (x - 3, y + 5), 2)

    def _draw_book_decoration(self, screen, x, y, color):
        """책 장식 그리기"""
        book_w, book_h = 12, 20
        pygame.draw.rect(screen, color, (x, y, book_w, book_h))
        # 책등
        pygame.draw.rect(screen, tuple(max(0, c - 30) for c in color), (x, y, 3, book_h))
        # 페이지
        pygame.draw.rect(screen, (240, 235, 220), (x + 3, y + 2, book_w - 5, book_h - 4))

    def _draw_main_counter_neon(self, screen, x, y, w, h, wood_color, top_color, accent):
        """메인 카운터 그리기 (유리 진열대 포함)"""
        # 카운터 본체
        pygame.draw.rect(screen, wood_color, (x, y, w, h))
        pygame.draw.rect(screen, tuple(max(0, c - 20) for c in wood_color), (x, y, w, h), 3)

        # 카운터 상판
        pygame.draw.rect(screen, top_color, (x - 5, y, w + 10, 8))
        pygame.draw.rect(screen, tuple(min(255, c + 20) for c in top_color), (x - 5, y, w + 10, 3))

        # 유리 진열대 (중앙)
        glass_w = w - 60
        glass_h = h - 30
        glass_x = x + 30
        glass_y = y + 15

        # 유리 배경 (반투명 시안)
        glass_surf = pygame.Surface((glass_w, glass_h), pygame.SRCALPHA)
        glass_surf.fill((0, 50, 60, 150))
        screen.blit(glass_surf, (glass_x, glass_y))

        # 유리 테두리
        pygame.draw.rect(screen, accent, (glass_x, glass_y, glass_w, glass_h), 2)

        # 진열대 안 아이템들 (작은 아이콘들)
        item_y = glass_y + glass_h // 2
        item_spacing = glass_w // 6
        item_colors = [(255, 100, 100), (100, 255, 150), (100, 150, 255),
                      (255, 200, 100), (200, 100, 255)]
        for i in range(5):
            item_x = glass_x + item_spacing * (i + 1)
            # 작은 아이템 아이콘
            pygame.draw.rect(screen, item_colors[i], (item_x - 8, item_y - 10, 16, 20), border_radius=3)
            # 반짝임
            pygame.draw.circle(screen, (255, 255, 255), (item_x - 4, item_y - 6), 2)

        # 카운터 하단 서랍
        drawer_y = y + h - 25
        for i in range(4):
            drawer_x = x + 20 + i * (w - 40) // 4
            drawer_w = (w - 50) // 4
            pygame.draw.rect(screen, tuple(max(0, c - 15) for c in wood_color),
                           (drawer_x, drawer_y, drawer_w, 20), border_radius=2)
            # 손잡이
            pygame.draw.circle(screen, (200, 180, 100), (drawer_x + drawer_w // 2, drawer_y + 10), 3)

    def _draw_display_shelf_neon(self, screen, x, y, w, h, wood_color, accent, side):
        """진열대 (가판대) 그리기"""
        # 선반 본체
        pygame.draw.rect(screen, wood_color, (x, y, w, h))
        pygame.draw.rect(screen, tuple(max(0, c - 20) for c in wood_color), (x, y, w, h), 2)

        # 선반 칸 (4단)
        shelf_count = 4
        shelf_h = h // (shelf_count + 1)

        for i in range(shelf_count):
            shelf_y = y + shelf_h * (i + 1)
            # 선반 판
            pygame.draw.rect(screen, tuple(min(255, c + 15) for c in wood_color),
                           (x + 3, shelf_y - 3, w - 6, 6))

            # 선반 위 아이템들
            item_count = random.randint(2, 4)
            for j in range(item_count):
                item_x = x + 10 + j * (w - 20) // item_count
                item_y = shelf_y - 25

                # 랜덤 아이템 타입
                item_type = random.randint(0, 3)
                if item_type == 0:
                    # 포션
                    color = random.choice([(255, 100, 100), (100, 200, 255), (100, 255, 150)])
                    self._draw_potion_bottle(screen, item_x + 8, item_y, color)
                elif item_type == 1:
                    # 보석
                    gem_color = random.choice([(255, 50, 100), (50, 200, 255), (100, 255, 100), (255, 200, 50)])
                    self._draw_gem_item(screen, item_x + 8, item_y + 5, gem_color)
                elif item_type == 2:
                    # 상자
                    self._draw_small_chest(screen, item_x, item_y, accent)
                else:
                    # 두루마리
                    self._draw_scroll_item(screen, item_x + 5, item_y)

        # 네온 테두리 효과
        glow_alpha = int(80 + 40 * math.sin(self.animation_timer * 2))
        glow_surf = pygame.Surface((w + 10, h + 10), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*accent, glow_alpha), (0, 0, w + 10, h + 10), 3, border_radius=5)
        screen.blit(glow_surf, (x - 5, y - 5))

    def _draw_gem_item(self, screen, x, y, color):
        """보석 아이템 그리기"""
        points = [
            (x, y - 6),
            (x + 8, y - 6),
            (x + 10, y),
            (x + 4, y + 8),
            (x - 2, y)
        ]
        pygame.draw.polygon(screen, color, points)
        pygame.draw.polygon(screen, (255, 255, 255), points, 1)
        # 반짝임
        pygame.draw.circle(screen, (255, 255, 255), (x + 2, y - 3), 2)

    def _draw_small_chest(self, screen, x, y, accent):
        """작은 상자 그리기"""
        chest_w, chest_h = 20, 15
        # 상자 본체
        pygame.draw.rect(screen, (139, 90, 43), (x, y, chest_w, chest_h), border_radius=2)
        # 뚜껑
        pygame.draw.rect(screen, (160, 110, 60), (x - 2, y - 3, chest_w + 4, 6), border_radius=2)
        # 자물쇠
        pygame.draw.circle(screen, accent, (x + chest_w // 2, y + chest_h // 2), 3)

    def _draw_scroll_item(self, screen, x, y):
        """두루마리 아이템 그리기"""
        scroll_color = (240, 230, 200)
        # 두루마리 본체
        pygame.draw.rect(screen, scroll_color, (x, y, 15, 8))
        # 양끝 둥근 부분
        pygame.draw.circle(screen, (200, 180, 140), (x, y + 4), 5)
        pygame.draw.circle(screen, (200, 180, 140), (x + 15, y + 4), 5)

    def _draw_wall_lamps_neon(self, screen, cam_x, cam_y, wall_h, accent_gold):
        """벽 횃불/램프 그리기"""
        lamp_y = wall_h // 2

        # 좌측 램프들
        for i, offset_y in enumerate([lamp_y - 30, lamp_y + 50]):
            lamp_x = int(TILE_SIZE * 0.8)
            self._draw_wall_torch(screen, lamp_x - cam_x, offset_y - cam_y, accent_gold)

        # 우측 램프들
        for i, offset_y in enumerate([lamp_y - 30, lamp_y + 50]):
            lamp_x = self.pixel_width - int(TILE_SIZE * 0.8)
            self._draw_wall_torch(screen, lamp_x - cam_x, offset_y - cam_y, accent_gold)

    def _draw_wall_torch(self, screen, x, y, color):
        """벽 횃불 그리기"""
        # 횃불대
        pygame.draw.rect(screen, (80, 60, 40), (x - 3, y, 6, 20))

        # 불꽃 효과
        flame_offset = int(3 * math.sin(self.animation_timer * 8))
        flame_colors = [
            (255, 200, 50),
            (255, 150, 30),
            (255, 100, 20)
        ]
        for i, c in enumerate(flame_colors):
            flame_size = 8 - i * 2
            flame_y = y - 5 - i * 3 + flame_offset
            pygame.draw.ellipse(screen, c, (x - flame_size // 2, flame_y, flame_size, flame_size + 4))

        # 빛 효과 (글로우)
        glow_alpha = int(60 + 30 * math.sin(self.animation_timer * 5))
        glow_surf = pygame.Surface((40, 40), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*color, glow_alpha), (20, 20), 18)
        screen.blit(glow_surf, (x - 20, y - 30))

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
                elif pattern == "magic_circle_academy":
                    # 아카데미 타일 (청록색 격자 기본)
                    if (tx + ty) % 2 == 0:
                        color = floor_color
                    else:
                        color = tuple(max(0, c - 8) for c in floor_color)
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
        # 스타포인트 가져오기 (통합 메서드 사용)
        star_points = self._get_current_star_points()

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
