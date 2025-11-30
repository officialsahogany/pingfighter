#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# downtown/building_interior.py
# 건물 내부 시스템 - 광장 확장 스타일 (플레이어 이동, 문 입출구, NPC 대화)

import pygame
import pygame.freetype
import math
import random

# Allow running as a module or as a script
try:
    from .constants import (
        SCREEN_WIDTH, SCREEN_HEIGHT, BuildingType, Colors, resource_path,
        TILE_SIZE, PLAYER_SPEED, PLAYER_SIZE
    )
except ImportError:  # pragma: no cover - fallback for direct execution
    import sys
    from pathlib import Path

    # Add project root (parent of 'downtown') to sys.path so 'downtown' becomes importable
    project_root = Path(__file__).resolve().parents[1]
    if str(project_root) not in sys.path:
        sys.path.insert(0, str(project_root))

    from downtown.constants import (  # type: ignore
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
        # 아카데미 학장(교관)은 상호작용 영역을 위로 더 길게
        if self.building_type == BuildingType.ACADEMY and self.role == "main":
            # 교관 스타일 NPC는 군모까지 포함하여 위로 더 길게
            return pygame.Rect(
                self.x - self.size - 8,
                self.y - self.size - 60,  # 위로 60픽셀 더 확장 (군모 + 마커까지)
                (self.size + 8) * 2,
                self.size + 70  # 전체 높이
            )
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
        """아카데미 NPC 그리기 - 학장(교관 스타일) / 견습생(로브 스타일)"""
        npc_id = hash(self.name)
        is_main = self.role == "main"  # 학장 아르카나

        # 메인 NPC(학장)는 더 크고 특별한 색상
        scale = 1.2 if is_main else 1.0

        # 피부톤
        skin_tones = [
            (255, 224, 189), (255, 205, 148), (234, 192, 134),
            (198, 134, 66), (255, 219, 172)
        ]
        skin_color = skin_tones[npc_id % len(skin_tones)] if not is_main else (255, 224, 189)
        skin_dark = tuple(max(0, c - 25) for c in skin_color)

        # 위치 계산
        center_x = int(draw_x)
        feet_y = int(draw_y)

        if is_main:
            # ============================================================
            # 학장 아르카나 - 고퀄리티 군사 교관 스타일
            # ============================================================

            # 색상 팔레트 (군복 스타일)
            UNIFORM_COLOR = (25, 35, 60)          # 진한 네이비 유니폼
            UNIFORM_DARK = (15, 22, 40)           # 어두운 네이비
            UNIFORM_LIGHT = (45, 55, 85)          # 밝은 네이비
            ACCENT_COLOR = (255, 200, 80)         # 금색 장식
            ACCENT_LIGHT = (255, 225, 150)        # 밝은 금색
            BELT_COLOR = (80, 50, 30)             # 가죽 벨트 갈색
            BELT_DARK = (50, 30, 15)              # 어두운 벨트
            BUTTON_COLOR = (220, 180, 60)         # 금색 버튼
            EPAULETTE_COLOR = (255, 200, 80)      # 견장 금색
            MEDAL_GOLD = (255, 215, 0)            # 메달 금색
            MEDAL_RED = (180, 40, 40)             # 메달 리본 빨강

            # 애니메이션
            breath_offset = int(0.8 * math.sin(animation_timer * 1.2 + npc_id))
            arm_swing = int(1.5 * math.sin(animation_timer * 0.8 + npc_id))

            # === 그림자 ===
            shadow_w = int(32 * scale)
            shadow_h = int(10 * scale)
            shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_surf, (0, 0, 0, 50), (0, 0, shadow_w, shadow_h))
            screen.blit(shadow_surf, (center_x - shadow_w // 2, feet_y - 5))

            # === 부츠 (군용 정장 부츠) ===
            boot_h = int(14 * scale)
            boot_w = int(8 * scale)
            boot_y = feet_y - boot_h

            # 왼쪽 부츠
            pygame.draw.rect(screen, (30, 25, 20), (center_x - 10, boot_y, boot_w, boot_h), border_radius=2)
            pygame.draw.rect(screen, (50, 40, 30), (center_x - 10, boot_y, boot_w, 3))
            pygame.draw.line(screen, (70, 55, 40), (center_x - 10, boot_y + boot_h - 2),
                           (center_x - 10 + boot_w, boot_y + boot_h - 2), 2)

            # 오른쪽 부츠
            pygame.draw.rect(screen, (30, 25, 20), (center_x + 2, boot_y, boot_w, boot_h), border_radius=2)
            pygame.draw.rect(screen, (50, 40, 30), (center_x + 2, boot_y, boot_w, 3))
            pygame.draw.line(screen, (70, 55, 40), (center_x + 2, boot_y + boot_h - 2),
                           (center_x + 2 + boot_w, boot_y + boot_h - 2), 2)

            # === 바지 (군복 정장 바지) ===
            pants_h = int(22 * scale)
            pants_top_y = boot_y - pants_h + 5
            pants_w = int(24 * scale)

            pants_points = [
                (center_x - pants_w // 2 + 3, pants_top_y),
                (center_x - 11, boot_y),
                (center_x + 11, boot_y),
                (center_x + pants_w // 2 - 3, pants_top_y),
            ]
            pygame.draw.polygon(screen, UNIFORM_COLOR, pants_points)
            pygame.draw.polygon(screen, UNIFORM_DARK, pants_points, 1)

            # 바지 중심선 (다림질 자국)
            pygame.draw.line(screen, UNIFORM_LIGHT, (center_x - 5, pants_top_y + 5),
                           (center_x - 6, boot_y - 3), 1)
            pygame.draw.line(screen, UNIFORM_LIGHT, (center_x + 5, pants_top_y + 5),
                           (center_x + 6, boot_y - 3), 1)

            # 측면 금색 스트라이프
            pygame.draw.line(screen, ACCENT_COLOR, (center_x - pants_w // 2 + 4, pants_top_y + 2),
                           (center_x - 10, boot_y - 2), 2)
            pygame.draw.line(screen, ACCENT_COLOR, (center_x + pants_w // 2 - 4, pants_top_y + 2),
                           (center_x + 10, boot_y - 2), 2)

            # === 벨트 ===
            belt_y = pants_top_y - 2
            belt_h = int(6 * scale)
            belt_w = int(28 * scale)

            pygame.draw.rect(screen, BELT_COLOR,
                           (center_x - belt_w // 2, belt_y, belt_w, belt_h), border_radius=1)
            pygame.draw.rect(screen, BELT_DARK,
                           (center_x - belt_w // 2, belt_y, belt_w, belt_h), 1, border_radius=1)

            # 벨트 버클 (금색)
            buckle_w = int(10 * scale)
            buckle_h = int(8 * scale)
            pygame.draw.rect(screen, BUTTON_COLOR,
                           (center_x - buckle_w // 2, belt_y - 1, buckle_w, buckle_h), border_radius=2)
            pygame.draw.rect(screen, (180, 140, 40),
                           (center_x - buckle_w // 2, belt_y - 1, buckle_w, buckle_h), 1, border_radius=2)
            pygame.draw.circle(screen, UNIFORM_DARK, (center_x, belt_y + belt_h // 2), 2)

            # === 상의 (더블 브레스트 군복 재킷) ===
            jacket_h = int(30 * scale)
            jacket_top_y = belt_y - jacket_h + breath_offset
            jacket_w = int(30 * scale)

            jacket_points = [
                (center_x - jacket_w // 2 + 2, jacket_top_y + 5),
                (center_x - jacket_w // 2, belt_y + 3),
                (center_x + jacket_w // 2, belt_y + 3),
                (center_x + jacket_w // 2 - 2, jacket_top_y + 5),
            ]
            pygame.draw.polygon(screen, UNIFORM_COLOR, jacket_points)

            # 재킷 앞판 라인 (더블 브레스트)
            pygame.draw.line(screen, UNIFORM_DARK, (center_x - 4, jacket_top_y + 8),
                           (center_x - 4, belt_y), 2)
            pygame.draw.line(screen, UNIFORM_DARK, (center_x + 4, jacket_top_y + 8),
                           (center_x + 4, belt_y), 2)

            # 금색 버튼 2열
            for row in range(3):
                btn_y = jacket_top_y + 10 + row * 7
                pygame.draw.circle(screen, BUTTON_COLOR, (center_x - 6, btn_y), 3)
                pygame.draw.circle(screen, ACCENT_LIGHT, (center_x - 7, btn_y - 1), 1)
                pygame.draw.circle(screen, BUTTON_COLOR, (center_x + 6, btn_y), 3)
                pygame.draw.circle(screen, ACCENT_LIGHT, (center_x + 5, btn_y - 1), 1)

            # 재킷 테두리 장식 (금색)
            pygame.draw.polygon(screen, ACCENT_COLOR, jacket_points, 2)

            # === 견장 (Epaulettes) ===
            epaulette_w = int(12 * scale)
            epaulette_h = int(6 * scale)
            epaulette_y = jacket_top_y + 4

            # 왼쪽 견장
            pygame.draw.rect(screen, EPAULETTE_COLOR,
                           (center_x - jacket_w // 2 - 2, epaulette_y, epaulette_w, epaulette_h), border_radius=2)
            pygame.draw.rect(screen, (200, 160, 40),
                           (center_x - jacket_w // 2 - 2, epaulette_y, epaulette_w, epaulette_h), 1, border_radius=2)
            for f in range(4):
                fx = center_x - jacket_w // 2 - 1 + f * 3
                pygame.draw.line(screen, ACCENT_LIGHT, (fx, epaulette_y + epaulette_h),
                               (fx, epaulette_y + epaulette_h + 4), 1)

            # 오른쪽 견장
            pygame.draw.rect(screen, EPAULETTE_COLOR,
                           (center_x + jacket_w // 2 - epaulette_w + 2, epaulette_y, epaulette_w, epaulette_h), border_radius=2)
            pygame.draw.rect(screen, (200, 160, 40),
                           (center_x + jacket_w // 2 - epaulette_w + 2, epaulette_y, epaulette_w, epaulette_h), 1, border_radius=2)
            for f in range(4):
                fx = center_x + jacket_w // 2 - epaulette_w + 3 + f * 3
                pygame.draw.line(screen, ACCENT_LIGHT, (fx, epaulette_y + epaulette_h),
                               (fx, epaulette_y + epaulette_h + 4), 1)

            # === 훈장/메달 (가슴 왼쪽) ===
            medal_x = center_x - 10
            medal_y = jacket_top_y + 12

            for m in range(3):
                mx = medal_x + m * 6
                pygame.draw.rect(screen, MEDAL_RED, (mx - 2, medal_y, 4, 5))
                pygame.draw.rect(screen, (150, 30, 30), (mx - 2, medal_y, 4, 5), 1)
                pygame.draw.circle(screen, MEDAL_GOLD, (mx, medal_y + 7), 3)
                pygame.draw.circle(screen, (200, 170, 0), (mx, medal_y + 7), 3, 1)
                pygame.draw.circle(screen, ACCENT_LIGHT, (mx - 1, medal_y + 6), 1)

            # === 팔 / 소매 ===
            arm_y = jacket_top_y + int(8 * scale)
            sleeve_w = int(10 * scale)
            sleeve_h = int(20 * scale)

            # 왼팔
            left_arm_x = center_x - jacket_w // 2 - 2
            pygame.draw.ellipse(screen, UNIFORM_COLOR,
                              (left_arm_x - 3, arm_y + arm_swing, sleeve_w, sleeve_h))
            pygame.draw.ellipse(screen, UNIFORM_DARK,
                              (left_arm_x - 3, arm_y + arm_swing, sleeve_w, sleeve_h), 1)
            pygame.draw.line(screen, ACCENT_COLOR, (left_arm_x - 1, arm_y + sleeve_h - 6 + arm_swing),
                           (left_arm_x + sleeve_w - 3, arm_y + sleeve_h - 6 + arm_swing), 2)
            pygame.draw.line(screen, ACCENT_COLOR, (left_arm_x - 1, arm_y + sleeve_h - 10 + arm_swing),
                           (left_arm_x + sleeve_w - 3, arm_y + sleeve_h - 10 + arm_swing), 2)
            # 손 (흰 장갑)
            pygame.draw.ellipse(screen, (250, 248, 245),
                              (left_arm_x, arm_y + sleeve_h - 3 + arm_swing, 7, 7))
            pygame.draw.ellipse(screen, (220, 218, 215),
                              (left_arm_x, arm_y + sleeve_h - 3 + arm_swing, 7, 7), 1)

            # 오른팔
            right_arm_x = center_x + jacket_w // 2 - sleeve_w + 2
            pygame.draw.ellipse(screen, UNIFORM_COLOR,
                              (right_arm_x + 3, arm_y - arm_swing, sleeve_w, sleeve_h))
            pygame.draw.ellipse(screen, UNIFORM_DARK,
                              (right_arm_x + 3, arm_y - arm_swing, sleeve_w, sleeve_h), 1)
            pygame.draw.line(screen, ACCENT_COLOR, (right_arm_x + 5, arm_y + sleeve_h - 6 - arm_swing),
                           (right_arm_x + sleeve_w + 1, arm_y + sleeve_h - 6 - arm_swing), 2)
            pygame.draw.line(screen, ACCENT_COLOR, (right_arm_x + 5, arm_y + sleeve_h - 10 - arm_swing),
                           (right_arm_x + sleeve_w + 1, arm_y + sleeve_h - 10 - arm_swing), 2)
            pygame.draw.ellipse(screen, (250, 248, 245),
                              (right_arm_x + 5, arm_y + sleeve_h - 3 - arm_swing, 7, 7))
            pygame.draw.ellipse(screen, (220, 218, 215),
                              (right_arm_x + 5, arm_y + sleeve_h - 3 - arm_swing, 7, 7), 1)

            # 지휘봉 (교관 특유)
            baton_x = right_arm_x + sleeve_w + 6
            baton_top = arm_y + 5 - arm_swing
            baton_bottom = arm_y + sleeve_h + 10 - arm_swing
            pygame.draw.line(screen, (60, 40, 25), (baton_x, baton_top), (baton_x, baton_bottom), 3)
            pygame.draw.line(screen, (90, 65, 40), (baton_x - 1, baton_top), (baton_x - 1, baton_bottom), 1)
            pygame.draw.circle(screen, ACCENT_COLOR, (baton_x, baton_top - 2), 4)
            pygame.draw.circle(screen, ACCENT_LIGHT, (baton_x - 1, baton_top - 3), 2)

            # === 높은 칼라 (스탠드 칼라) ===
            collar_y = jacket_top_y - 3 + breath_offset
            collar_h = int(8 * scale)
            collar_w = int(22 * scale)

            pygame.draw.rect(screen, UNIFORM_COLOR,
                           (center_x - collar_w // 2, collar_y, collar_w, collar_h), border_radius=2)
            pygame.draw.rect(screen, UNIFORM_DARK,
                           (center_x - collar_w // 2, collar_y, collar_w, collar_h), 1, border_radius=2)
            pygame.draw.line(screen, ACCENT_COLOR, (center_x - collar_w // 2 + 2, collar_y + 1),
                           (center_x + collar_w // 2 - 2, collar_y + 1), 2)

            # === 목 ===
            neck_h = int(4 * scale)
            pygame.draw.rect(screen, skin_color, (center_x - 4, collar_y - neck_h, 8, neck_h + 2))

            # === 머리 ===
            head_w = int(16 * scale)
            head_h = int(16 * scale)
            head_y = collar_y - neck_h - head_h + 5 + breath_offset
            head_x = center_x - head_w // 2

            pygame.draw.ellipse(screen, skin_color, (head_x, head_y, head_w, head_h))
            pygame.draw.ellipse(screen, skin_dark, (head_x, head_y, head_w, head_h), 1)

            # 볼 터치
            pygame.draw.circle(screen, (255, 210, 200), (head_x + 3, head_y + head_h // 2 + 2), 2)
            pygame.draw.circle(screen, (255, 210, 200), (head_x + head_w - 3, head_y + head_h // 2 + 2), 2)

            # === 머리카락 (짧은 군인 스타일) ===
            hair_color = (50, 35, 25)
            hair_dark = (35, 22, 15)

            pygame.draw.ellipse(screen, hair_color, (head_x - 1, head_y - 2, head_w + 2, head_h // 2 + 4))
            pygame.draw.ellipse(screen, hair_color, (head_x - 2, head_y + 1, 6, 8))
            pygame.draw.ellipse(screen, hair_color, (head_x + head_w - 4, head_y + 1, 6, 8))
            pygame.draw.arc(screen, hair_color, (head_x, head_y - 3, head_w, 10),
                          math.pi * 0.2, math.pi * 0.8, 3)
            pygame.draw.line(screen, hair_dark, (center_x - 3, head_y + 1), (center_x + 5, head_y), 2)

            # === 군모 (정모/제모) ===
            cap_w = int(22 * scale)
            cap_h = int(10 * scale)
            cap_y = head_y - 4

            pygame.draw.ellipse(screen, UNIFORM_COLOR,
                              (center_x - cap_w // 2, cap_y, cap_w, cap_h))
            pygame.draw.ellipse(screen, UNIFORM_DARK,
                              (center_x - cap_w // 2, cap_y, cap_w, cap_h), 1)

            # 모자 챙 (검은색)
            visor_w = int(18 * scale)
            visor_h = int(5 * scale)
            pygame.draw.ellipse(screen, (20, 20, 25),
                              (center_x - visor_w // 2, cap_y + cap_h - 3, visor_w, visor_h))
            pygame.draw.arc(screen, (60, 60, 70),
                          (center_x - visor_w // 2 + 2, cap_y + cap_h - 2, visor_w - 4, visor_h - 2),
                          math.pi, math.pi * 2, 1)

            # 모자 밴드 (금색)
            pygame.draw.line(screen, ACCENT_COLOR,
                           (center_x - cap_w // 2 + 3, cap_y + cap_h // 2),
                           (center_x + cap_w // 2 - 3, cap_y + cap_h // 2), 3)

            # 모자 엠블럼 (중앙 금장)
            emblem_x = center_x
            emblem_y_cap = cap_y + cap_h // 2
            pygame.draw.circle(screen, MEDAL_GOLD, (emblem_x, emblem_y_cap), 5)
            pygame.draw.circle(screen, ACCENT_LIGHT, (emblem_x, emblem_y_cap), 5, 1)
            for i in range(5):
                angle = -math.pi / 2 + (i * 2 * math.pi / 5)
                sx = emblem_x + int(3 * math.cos(angle))
                sy = emblem_y_cap + int(3 * math.sin(angle))
                pygame.draw.circle(screen, ACCENT_LIGHT, (sx, sy), 1)

            # 모자 꼭대기
            pygame.draw.ellipse(screen, UNIFORM_LIGHT,
                              (center_x - cap_w // 3, cap_y - 2, cap_w // 3 * 2, 6))

            # === 눈 (날카롭고 위엄있는) ===
            eye_y = head_y + head_h // 2 - 1
            eye_offset = 1 if self.direction == 2 else (-1 if self.direction == 1 else 0)

            # 눈썹 (굵고 날카로운)
            pygame.draw.line(screen, hair_dark, (center_x - 6 + eye_offset, eye_y - 4),
                           (center_x - 1 + eye_offset, eye_y - 5), 2)
            pygame.draw.line(screen, hair_dark, (center_x + 1 + eye_offset, eye_y - 5),
                           (center_x + 6 + eye_offset, eye_y - 4), 2)

            # 눈 흰자
            pygame.draw.ellipse(screen, (255, 255, 255),
                              (center_x - 5 + eye_offset, eye_y - 2, 5, 4))
            pygame.draw.ellipse(screen, (255, 255, 255),
                              (center_x + 1 + eye_offset, eye_y - 2, 5, 4))

            # 눈동자
            pygame.draw.circle(screen, (40, 50, 70), (center_x - 3 + eye_offset, eye_y), 2)
            pygame.draw.circle(screen, (40, 50, 70), (center_x + 3 + eye_offset, eye_y), 2)

            # 눈 하이라이트
            pygame.draw.circle(screen, (255, 255, 255), (center_x - 3 + eye_offset, eye_y - 1), 1)
            pygame.draw.circle(screen, (255, 255, 255), (center_x + 3 + eye_offset, eye_y - 1), 1)

            # === 코 ===
            pygame.draw.line(screen, skin_dark, (center_x, eye_y + 2), (center_x, eye_y + 5), 1)
            pygame.draw.circle(screen, skin_dark, (center_x, eye_y + 5), 1)

            # === 입 (위엄있는 미소) ===
            mouth_y = head_y + head_h - 5
            if self.is_talking:
                mouth_open = int(abs(math.sin(animation_timer * 8)) * 2)
                pygame.draw.ellipse(screen, (80, 50, 50),
                                  (center_x - 3, mouth_y, 6, 2 + mouth_open))
            else:
                pygame.draw.arc(screen, skin_dark,
                              (center_x - 4, mouth_y - 2, 8, 6),
                              0, math.pi, 1)

            # === 학장 마커 (위엄있는 금색 화살표) ===
            marker_y = cap_y - 18
            glow_alpha = int(150 + 80 * math.sin(animation_timer * 2))
            marker_surf = pygame.Surface((24, 14), pygame.SRCALPHA)
            pygame.draw.polygon(marker_surf, (*ACCENT_COLOR, glow_alpha), [
                (12, 12), (4, 2), (20, 2)
            ])
            pygame.draw.polygon(marker_surf, (*ACCENT_LIGHT, glow_alpha // 2), [
                (12, 12), (4, 2), (20, 2)
            ], 2)
            screen.blit(marker_surf, (center_x - 12, marker_y))

            # 글로우 효과
            glow_surf = pygame.Surface((30, 20), pygame.SRCALPHA)
            pygame.draw.ellipse(glow_surf, (*ACCENT_COLOR, glow_alpha // 3), (0, 0, 30, 20))
            screen.blit(glow_surf, (center_x - 15, marker_y - 3))

        else:
            # ============================================================
            # 견습생 (기존 로브 스타일 유지)
            # ============================================================
            robe_colors = [
                ((60, 90, 140), (40, 60, 100), (90, 120, 170)),
                ((80, 120, 80), (50, 80, 50), (110, 150, 110)),
                ((140, 80, 80), (100, 50, 50), (170, 110, 110)),
                ((100, 100, 120), (70, 70, 90), (130, 130, 150)),
                ((120, 100, 60), (80, 70, 40), (150, 130, 90)),
            ]
            robe_set = robe_colors[npc_id % len(robe_colors)]
            ROBE_COLOR, ROBE_DARK, ROBE_LIGHT = robe_set
            ACCENT_COLOR = (180, 180, 200)

            hover_offset = int(1.5 * math.sin(animation_timer * 1.5 + npc_id))
            robe_sway = math.sin(animation_timer * 2 + npc_id) * 2
            feet_y += hover_offset

            # === 그림자 ===
            shadow_w = int((self.width + 12) * scale)
            shadow_h = int(8 * scale)
            shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40), (0, 0, shadow_w, shadow_h))
            screen.blit(shadow_surf, (center_x - shadow_w // 2, feet_y - 4 - hover_offset))

            # === 로브 하단 ===
            robe_bottom_w = int(28 * scale)
            robe_bottom_h = int(12 * scale)
            robe_bottom_y = feet_y - robe_bottom_h

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

            robe_points = [
                (center_x - robe_w // 3, robe_y),
                (center_x - robe_w // 2, robe_bottom_y),
                (center_x + robe_w // 2, robe_bottom_y),
                (center_x + robe_w // 3, robe_y),
            ]
            pygame.draw.polygon(screen, ROBE_COLOR, robe_points)
            pygame.draw.polygon(screen, ROBE_LIGHT, robe_points, 2)
            pygame.draw.line(screen, ACCENT_COLOR, (center_x, robe_y + 5), (center_x, robe_bottom_y - 5), 2)

            # === 소매/팔 ===
            arm_y = robe_y + int(10 * scale)
            arm_swing = int(2 * math.sin(animation_timer * 1.2 + npc_id))
            sleeve_w = int(10 * scale)
            sleeve_h = int(16 * scale)

            pygame.draw.ellipse(screen, ROBE_DARK,
                              (robe_x - sleeve_w + 6, arm_y + arm_swing, sleeve_w, sleeve_h))
            pygame.draw.ellipse(screen, skin_color,
                              (robe_x - 2, arm_y + sleeve_h - 5 + arm_swing, 6, 6))

            pygame.draw.ellipse(screen, ROBE_COLOR,
                              (robe_x + robe_w - 6, arm_y - arm_swing, sleeve_w, sleeve_h))
            pygame.draw.ellipse(screen, skin_color,
                              (robe_x + robe_w - 2, arm_y + sleeve_h - 5 - arm_swing, 6, 6))

            # === 목/칼라 ===
            collar_y = robe_y - 2
            pygame.draw.ellipse(screen, ROBE_DARK, (center_x - 8, collar_y, 16, 8))
            pygame.draw.ellipse(screen, ACCENT_COLOR, (center_x - 8, collar_y, 16, 8), 1)

            # === 머리 ===
            head_w = int(14 * scale)
            head_h = int(14 * scale)
            head_y = collar_y - head_h + 4
            head_x = center_x - head_w // 2

            pygame.draw.ellipse(screen, skin_color, (head_x, head_y, head_w, head_h))
            pygame.draw.circle(screen, (255, 200, 190), (head_x + 2, head_y + head_h // 2 + 1), 2)
            pygame.draw.circle(screen, (255, 200, 190), (head_x + head_w - 2, head_y + head_h // 2 + 1), 2)

            # 후드
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

            pygame.draw.ellipse(screen, (255, 255, 255), (center_x - 4 + eye_offset, eye_y - 2, 4, 4))
            pygame.draw.ellipse(screen, (255, 255, 255), (center_x + 1 + eye_offset, eye_y - 2, 4, 4))
            pygame.draw.circle(screen, (40, 30, 20), (center_x - 2 + eye_offset, eye_y), 2)
            pygame.draw.circle(screen, (40, 30, 20), (center_x + 3 + eye_offset, eye_y), 2)
            pygame.draw.circle(screen, (255, 255, 255), (center_x - 2 + eye_offset, eye_y - 1), 1)
            pygame.draw.circle(screen, (255, 255, 255), (center_x + 3 + eye_offset, eye_y - 1), 1)

            # === 입 ===
            mouth_y = head_y + head_h - 4
            if self.is_talking:
                mouth_open = int(abs(math.sin(animation_timer * 8)) * 2)
                pygame.draw.ellipse(screen, (60, 40, 40), (center_x - 2, mouth_y, 4, 2 + mouth_open))
            else:
                pygame.draw.line(screen, skin_dark, (center_x - 2, mouth_y), (center_x + 2, mouth_y), 1)

            # === 아카데미 활동 이펙트 ===
            if self.academy_activity:
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

    def reset_input_state(self):
        """모달 화면 복귀 시 입력이 고정되지 않도록 상태 초기화."""
        self.pressed_keys.clear()
        self._scancode_map.clear()
        self.velocity_x = 0
        self.velocity_y = 0
        self.is_moving = False

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
        "map_size": (20, 20),  # 2배 확대 (10x10 → 20x20)
        "bg_color": (25, 15, 35),  # 사이버펑크 어두운 보라
        "floor_color": (60, 30, 80),  # 핑크빛 보라 바닥
        "floor_pattern": "cyberpunk_tiles",  # 사이버펑크 타일 패턴
        "wall_color": (35, 20, 50),  # 어두운 벽
        "accent_color": (255, 50, 150),  # 네온 핑크/마젠타
        "secondary_color": (0, 255, 255),  # 네온 시안
        "decorations": [],  # 커스텀 인테리어 사용
        "main_npc": {
            "name": "가챠 마스터",
            "color": (255, 100, 200),  # 핑크빛
            "position": (0.5, 0.2),  # 맵이 커졌으므로 위치 조정
            "dialogue": [
                "스타 가챠샵에 오신 것을 환영해요!",
                "오늘의 운세는 어떨까요?",
                "희귀 아이템이 기다리고 있어요!",
                "준비 중... 조금만 기다려주세요!"
            ]
        },
        "customer_range": (6, 12),  # 넓어져서 손님 증가
        "staff_count": 3,  # 직원 증가
        "special_interior": "cyberpunk_gacha",  # 사이버펑크 가챠샵 특수 인테리어
    },
    BuildingType.ACADEMY: {
        "name": "아카데미",
        "map_size": (32, 24),  # 2배 확대 (16x12 → 32x24)
        "bg_color": (35, 35, 40),  # 어두운 금속/콘크리트 색상
        "floor_color": (55, 55, 60),  # 훈련장 바닥
        "floor_pattern": "training_emblem",  # 창과방패 엠블럼 바닥
        "wall_color": (45, 45, 50),  # 금속 벽
        "accent_color": (255, 180, 80),  # 주황/골드 엑센트
        "secondary_color": (180, 100, 50),  # 보조 색상 (따뜻한 톤)
        "decorations": [],  # 커스텀 인테리어 사용
        "main_npc": {
            "name": "교관 타이탄",
            "color": (200, 150, 80),  # 골드/브론즈 색상
            "position": (0.5, 0.18),  # 맵이 커졌으므로 위치 조정
            "dialogue": [
                "훈련소에 온 것을 환영한다, 신병!",
                "강해지고 싶다면 땀을 흘려라.",
                "오늘의 훈련 메뉴는 대쉬와 회피다.",
                "실전에서 살아남으려면 여기서 먼저 죽어라!"
            ]
        },
        "customer_range": (4, 8),  # 훈련생 수
        "staff_count": 3,  # 교관/의무병
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
        # 상점 거래창 스크롤 상태
        self.shop_player_scroll = 0
        self.shop_shop_scroll = 0
        self._shop_player_max_scroll = 0
        self._shop_shop_max_scroll = 0
        self._shop_player_visible_rows = 0
        self._shop_shop_visible_rows = 0
        self.shop_confirm_dialog = None  # {"action":..., ...}

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

        # 상점 장애물 영역들 (ITEM_SHOP에서만 사용)
        self.shop_obstacle_rects = []

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
        self.exchange_slider_dragging = False  # 슬라이더 드래그 중 여부
        self.exchange_slider_rect = None  # 슬라이더 트랙 영역 (draw에서 설정)

        # 예금 창 상태
        self.deposit_menu_open = False
        self.deposit_tab = 0  # 0: 예금 탭, 1: 설명 탭
        self.deposit_amount = 0  # 예금할 금액
        self.withdraw_mode = False  # False: 예금, True: 출금

        # 아카데미 메뉴 상태 (ACADEMY 전용)
        self.academy_dialog_open = False  # 학장 대화 미니창
        self.academy_dialog_selection = 0  # 0: 예, 1: 아니오
        self.open_skill_menu_requested = False  # 스킬 메뉴 열기 요청 플래그

        # 상점 거래 시스템 (ITEM_SHOP 전용)
        self.shop_trade_open = False  # 거래 창 열림 여부
        self.shop_inventory = []  # 상점 인벤토리 (랜덤 생성)
        self.shop_hover_item = None  # 마우스 호버 중인 아이템 (source, idx, item, rect)
        self.shop_tooltip_item = None  # 툴팁 표시할 아이템
        self.shop_item_rects = {"player": {}, "shop": {}}  # 클릭 영역 저장

        # 드래그 앤 드롭 시스템
        self.shop_dragging_item = None  # {'source': 'player'|'shop', 'idx': int, 'item': dict}
        self.shop_drag_start_pos = None  # 드래그 시작 위치
        self.shop_drag_offset = (0, 0)  # 아이템 중심에서 마우스 오프셋

        # 골드 변동 애니메이션 시스템
        self.gold_float_animations = []  # {'amount': int, 'is_gain': bool, 'x': int, 'y': int, 'timer': float, 'alpha': int}

        # 상점/환전 효과음 로드
        self.trade_sound = None
        self.star_exchange_sound = None
        self.crane_bgm_path = None  # 크레인 게임 BGM 경로
        try:
            import os
            trade_sound_path = resource_path(os.path.join("sounds", "trade.wav"))
            if os.path.exists(trade_sound_path):
                self.trade_sound = pygame.mixer.Sound(trade_sound_path)
                self.trade_sound.set_volume(0.6)  # 볼륨 60%

            star_sound_path = resource_path(os.path.join("sounds", "star.wav"))
            if os.path.exists(star_sound_path):
                self.star_exchange_sound = pygame.mixer.Sound(star_sound_path)
                self.star_exchange_sound.set_volume(0.6)

            # 크레인 게임 BGM 경로 설정
            crane_bgm_path = resource_path(os.path.join("bgm", "crane.wav"))
            if os.path.exists(crane_bgm_path):
                self.crane_bgm_path = crane_bgm_path
        except Exception as e:
            print(f"Warning: Could not load trade/star sound: {e}")

        self._init_shop_inventory()  # 상점 인벤토리 초기화

        # 가챠 머신 상호작용 영역 (GACHA 전용)
        self.gacha_machine_rects = []  # 가챠 머신 상호작용 영역들
        self.gacha_interact_requested = False  # 가챠 실행 요청 플래그
        self.nearby_gacha_machine = None  # 근처 가챠 머신 인덱스
        self._init_gacha_machine_zones()  # 가챠 머신 영역 초기화

        # 크레인 게임(인형뽑기) 상호작용 영역 (GACHA 전용)
        self.crane_game_rects = []  # 크레인 게임 상호작용 영역들
        self.crane_interact_requested = False  # 크레인 게임 실행 요청 플래그
        self.nearby_crane_game = None  # 근처 크레인 게임 인덱스
        self._init_crane_game_zones()  # 크레인 게임 영역 초기화

        # 크레인 게임 확인 다이얼로그 상태
        self.crane_confirm_dialog_open = False  # 확인 다이얼로그 열림 여부
        self.crane_confirm_selection = 0  # 0: 예, 1: 아니오
        self.crane_game_cost = 300  # 크레인 게임 비용 (골드)

        # 크레인 게임 플레이 화면 상태
        self.crane_game_playing = False  # 크레인 게임 플레이 중
        self.crane_x = 0.5  # 크레인 X 위치 (0.0 ~ 1.0)
        self.crane_y = 0.0  # 크레인 Y 위치 (0.0 = 상단, 1.0 = 하단)
        self.crane_state = "idle"  # idle, moving_left, moving_right, dropping, grabbing, rising, returning, releasing, item_falling
        self.crane_direction = 1  # 1 = 오른쪽, -1 = 왼쪽
        self.crane_speed = 0.008  # 크레인 이동 속도
        self.crane_grab_timer = 0  # 그랩 타이머
        self.crane_time_limit = 20.0  # 크레인 게임 제한 시간 (초)
        self.crane_time_remaining = 20.0  # 남은 시간
        self.crane_attempts = 5  # 남은 시도 횟수
        self.crane_prizes = []  # 인형들 위치와 종류 [{x, y, type, grabbed}]
        self.crane_grabbed_prize = None  # 잡은 인형
        self.crane_result = None  # 게임 결과 {"success": bool, "prize": ...}
        self._init_crane_prizes()  # 인형 초기화

        # 크레인 배출 애니메이션 변수
        self.crane_claw_open = 0.0  # 집게 벌림 정도 (0.0: 닫힘, 1.0: 열림)
        self.crane_drop_y = 0.0  # 배출구에서 떨어지는 아이템 Y 위치
        self.crane_drop_speed = 0.0  # 낙하 속도
        self.crane_drop_bounce = 0  # 튕김 횟수

        # 아카데미 학장 상호작용 (ACADEMY 전용)
        self.nearby_headmaster = False  # 학장 근처 여부

        # 일반 NPC 상호작용 힌트
        self.nearby_npc = None  # 근처에 있는 NPC (100픽셀 이내)

    def _init_shop_inventory(self):
        """상점 인벤토리 초기화 (랜덤 패시브 아이템 1~7개 + 5% 전설)"""
        if self.building_type != BuildingType.ITEM_SHOP:
            return

        self.shop_inventory = []

        # pingfighter 함수들 가져오기
        try:
            import pingfighter
            roll_passive_options = getattr(pingfighter, 'roll_passive_options', None)
            assign_item_prefix = getattr(pingfighter, 'assign_item_prefix', None)
        except:
            roll_passive_options = None
            assign_item_prefix = None

        # 패시브 아이템 목록 (판매 가능한 아이템들)
        passive_items = [
            {"name": "speedboots", "base_price": 1100, "korean": "스피드부츠"},
            {"name": "speedgear", "base_price": 800, "korean": "스피드기어"},
            {"name": "battery", "base_price": 1300, "korean": "배터리"},
            {"name": "revival", "base_price": 3000, "korean": "부활"},
            {"name": "master", "base_price": 900, "korean": "토르의 망치"},
            {"name": "cooltime", "base_price": 700, "korean": "쿨타임"},
            {"name": "chargebag", "base_price": 1500, "korean": "충전가방"},
            {"name": "spikeboots", "base_price": 1200, "korean": "스파이크부츠"},
            {"name": "dashgear", "base_price": 1200, "korean": "대쉬기어"},
            {"name": "bulkup", "base_price": 1100, "korean": "벌크업"},
            {"name": "sensor", "base_price": 1800, "korean": "위험감지센서"},
            {"name": "gravitybelt", "base_price": 2500, "korean": "무중력벨트"},
            {"name": "dashholder", "base_price": 1800, "korean": "대쉬홀더"},
            {"name": "dowsing_pendulum", "base_price": 700, "korean": "다우징팬들럼"},
            {"name": "smartphone", "base_price": 800, "korean": "스마트폰"},
            {"name": "commando_arm", "base_price": 1100, "korean": "코만도암"},
            {"name": "technical_vest", "base_price": 1200, "korean": "테크니컬조끼"},
            {"name": "fuel_pouch", "base_price": 700, "korean": "연료파우치"},
            {"name": "slot_add", "base_price": 900, "korean": "가방"},
            {"name": "bluetooth_ring", "base_price": 1200, "korean": "블루투스링"},
            {"name": "star_detector", "base_price": 900, "korean": "별탐지기"},
            {"name": "foul_whistle", "base_price": 1300, "korean": "반칙호루라기"},
            {"name": "bulletproof_hat", "base_price": 800, "korean": "방탄모자"},
            {"name": "spiked_helmet", "base_price": 1000, "korean": "가시투구"},
            {"name": "knee_pads", "base_price": 800, "korean": "킥차져"},
        ]

        # 전설 아이템 목록 (5% 확률)
        legendary_items = [
            {"name": "ragnarok_hammer", "base_price": 6500, "korean": "라그나로크 해머", "type": "legendary"},
            {"name": "hermes_shoes", "base_price": 5500, "korean": "헤르메스의 신발", "type": "legendary"},
            {"name": "poseidon_trident", "base_price": 5500, "korean": "포세이돈의 삼지창", "type": "legendary"},
            {"name": "angel_blessing", "base_price": 6000, "korean": "천사의 가호", "type": "legendary"},
            {"name": "sacred_laurel", "base_price": 5800, "korean": "신성 월계수", "type": "legendary"},
        ]

        # 랜덤 아이템 개수 (1~7개)
        item_count = random.randint(1, 7)

        # 사용 가능한 아이템 풀에서 랜덤 선택
        available_pool = passive_items.copy()

        for _ in range(item_count):
            if not available_pool:
                break

            # 5% 확률로 전설 아이템
            if random.random() < 0.05 and legendary_items:
                selected = random.choice(legendary_items)
                legendary_items.remove(selected)  # 중복 방지
                is_legendary = True
            else:
                selected = random.choice(available_pool)
                available_pool.remove(selected)  # 중복 방지
                is_legendary = False

            # 기본 아이템 데이터 생성
            shop_item = {
                "name": selected["name"],
                "korean": selected["korean"],
                "type": "legendary" if is_legendary else "passive",
                "icon": None
            }

            # 전설 아이템이 아닌 경우 롤옵션 생성
            if not is_legendary and roll_passive_options:
                rolled_options = roll_passive_options(selected["name"])
                if rolled_options:
                    shop_item["rolled_options"] = rolled_options
                    # 품질 등급 및 수식어 설정
                    if assign_item_prefix:
                        assign_item_prefix(shop_item, force=True)

            # 최종 가격 계산 (기본가 + 품질/롤옵션 보너스)
            base_price = selected["base_price"]
            # 품질 등급과 롤옵션 세부 수치에 따른 가격 보너스
            quality_roll_bonus = self._get_quality_and_roll_bonus(shop_item, base_price)

            # 랜덤 변동 제거 - 일관된 가격 유지 (사고팔아도 가격 변동 없음)
            final_price = int(base_price + quality_roll_bonus)
            shop_item["price"] = final_price

            self.shop_inventory.append(shop_item)

    def _init_gacha_machine_zones(self):
        """가챠 머신 상호작용 영역 초기화 (GACHA 전용)"""
        if self.building_type != BuildingType.GACHA:
            return

        self.gacha_machine_rects = []

        # 사이버펑크 가챠샵 레이아웃에서 가챠 머신 위치 계산
        # _draw_gacha_interior()와 동일한 값 사용 (중요!)
        wall_h = int(TILE_SIZE * 5)  # _draw_gacha_interior와 동일!
        machine_y = wall_h + int(TILE_SIZE * 0.5)  # 실제 머신 Y 위치
        machine_h = int(TILE_SIZE * 3.5)  # _draw_gacha_machine_row와 동일!
        machine_w = int(TILE_SIZE * 1.5)
        spacing = int(TILE_SIZE * 0.1)  # _draw_gacha_machine_row와 동일!

        # 머신 하단 (bottom) = machine_y + machine_h
        machine_bottom = machine_y + machine_h

        # 왼쪽 가챠 머신들 (3대) - _draw_gacha_machine_row와 동일한 위치
        left_x = int(TILE_SIZE * 1.5)
        for i in range(3):
            mx = left_x + i * (machine_w + spacing)
            # 상호작용 영역: 머신 몸통 + 아래쪽까지 포함
            # 마우스 클릭은 머신 전체에서 가능
            interact_rect = pygame.Rect(
                mx - 10,                    # 머신 X보다 약간 왼쪽
                machine_y,                  # 머신 상단부터 시작 (몸통 포함)
                machine_w + 20,             # 머신 너비 + 양쪽 여유
                machine_h + TILE_SIZE       # 머신 높이 + 아래 1타일
            )
            self.gacha_machine_rects.append({
                "rect": interact_rect,
                "machine_rect": pygame.Rect(mx, machine_y, machine_w, machine_h),
                "side": "left",
                "index": i
            })

        # 오른쪽 가챠 머신들 (3대) - _draw_gacha_machine_row와 동일한 위치
        right_x = self.pixel_width - int(TILE_SIZE * 6)
        for i in range(3):
            mx = right_x + i * (machine_w + spacing)
            # 상호작용 영역: 머신 몸통 + 아래쪽까지 포함
            # 마우스 클릭은 머신 전체에서 가능
            interact_rect = pygame.Rect(
                mx - 10,                    # 머신 X보다 약간 왼쪽
                machine_y,                  # 머신 상단부터 시작 (몸통 포함)
                machine_w + 20,             # 머신 너비 + 양쪽 여유
                machine_h + TILE_SIZE       # 머신 높이 + 아래 1타일
            )
            self.gacha_machine_rects.append({
                "rect": interact_rect,
                "machine_rect": pygame.Rect(mx, machine_y, machine_w, machine_h),
                "side": "right",
                "index": i + 3
            })

    def _init_crane_game_zones(self):
        """크레인 게임(인형뽑기) 상호작용 영역 초기화 (GACHA 전용)"""
        if self.building_type != BuildingType.GACHA:
            return

        self.crane_game_rects = []

        # _draw_cyberpunk_gacha_interior와 동일한 값 사용
        wall_h = int(TILE_SIZE * 5)
        prize_y = wall_h + int(TILE_SIZE * 6)  # 크레인 게임 Y 위치
        machine_w = int(TILE_SIZE * 2)  # _draw_prize_machines에서 사용하는 크기
        machine_h = int(TILE_SIZE * 3)

        # 머신 하단 (bottom)
        machine_bottom = prize_y + machine_h

        # 왼쪽 크레인 게임들 (2대)
        left_x = int(TILE_SIZE * 1.5)
        for i in range(2):
            mx = left_x + i * (machine_w + 10)
            # 상호작용 영역: 머신 몸통 + 아래쪽까지 포함
            interact_rect = pygame.Rect(
                mx - 10,
                prize_y,                    # 머신 상단부터 시작
                machine_w + 20,
                machine_h + TILE_SIZE       # 머신 높이 + 아래 1타일
            )
            self.crane_game_rects.append({
                "rect": interact_rect,
                "machine_rect": pygame.Rect(mx, prize_y, machine_w, machine_h),
                "side": "left",
                "index": i
            })

        # 오른쪽 크레인 게임들 (2대)
        right_x = self.pixel_width - int(TILE_SIZE * 6)
        for i in range(2):
            mx = right_x + i * (machine_w + 10)
            # 상호작용 영역: 머신 몸통 + 아래쪽까지 포함
            interact_rect = pygame.Rect(
                mx - 10,
                prize_y,                    # 머신 상단부터 시작
                machine_w + 20,
                machine_h + TILE_SIZE       # 머신 높이 + 아래 1타일
            )
            self.crane_game_rects.append({
                "rect": interact_rect,
                "machine_rect": pygame.Rect(mx, prize_y, machine_w, machine_h),
                "side": "right",
                "index": i + 2
            })

    def _check_nearby_crane_game(self):
        """플레이어 근처에 크레인 게임이 있는지 확인"""
        if self.building_type != BuildingType.GACHA:
            return None

        player_rect = pygame.Rect(
            self.player.x - 30, self.player.y - 30, 60, 60
        )

        for i, crane_info in enumerate(self.crane_game_rects):
            if player_rect.colliderect(crane_info["rect"]):
                return i

        return None

    def _check_crane_game_click(self, world_x, world_y):
        """크레인 게임이 클릭되었는지 확인 (플레이어가 근처에 있어야 함)"""
        if self.building_type != BuildingType.GACHA:
            return None

        # 플레이어가 근처에 있는 크레인만 클릭 가능
        nearby_crane = self._check_nearby_crane_game()
        if nearby_crane is None:
            return None

        # 근처에 있는 크레인을 클릭했는지 확인
        crane_info = self.crane_game_rects[nearby_crane]
        if crane_info["rect"].collidepoint(world_x, world_y):
            return nearby_crane

        return None

    def _init_crane_prizes(self):
        """크레인 게임 아이템 캡슐 초기화 - 액티브 70% + 패시브 30%"""
        self.crane_prizes = []

        # 현재 캐릭터 타입 확인 (발토르 전용 아이템 필터링용)
        import sys
        is_blacksmith = False
        if 'pingfighter' in sys.modules:
            pingfighter = sys.modules['pingfighter']
            is_blacksmith = getattr(pingfighter, 'selected_character_type', '') == 'blacksmith'

        # === 액티브 아이템 풀 (70% 비율) - 전부 커먼 ===
        active_items = [
            {"name": "long_boost", "korean": "거대화포션", "rarity": "common", "type": "active"},
            {"name": "gauge_charge", "korean": "에너지드링크", "rarity": "common", "type": "active"},
            {"name": "wall", "korean": "벽돌", "rarity": "common", "type": "active"},
            {"name": "flare", "korean": "섬광탄", "rarity": "common", "type": "active"},
            {"name": "smoke_grenade", "korean": "연막탄", "rarity": "common", "type": "active"},
            {"name": "vitamin_pill", "korean": "비타민약", "rarity": "common", "type": "active"},
            {"name": "molotov", "korean": "화염병", "rarity": "common", "type": "active"},
            {"name": "grenade", "korean": "수류탄", "rarity": "common", "type": "active"},
            {"name": "spider_mine", "korean": "스파이더지뢰", "rarity": "common", "type": "active"},
            {"name": "stopwatch", "korean": "스톱워치", "rarity": "common", "type": "active"},
            {"name": "aipill", "korean": "AI알약", "rarity": "common", "type": "active"},
            {"name": "pandora_box", "korean": "판도라상자", "rarity": "epic", "type": "active"},
            {"name": "life_elixir", "korean": "생명수", "rarity": "epic", "type": "active"},
            {"name": "devil_dice", "korean": "악마의주사위", "rarity": "common", "type": "active"},
            {"name": "laser_scope", "korean": "레이저스코프", "rarity": "common", "type": "active"},
        ]

        # 발토르 전용 아이템 추가 (발토르로 플레이 시에만)
        if is_blacksmith:
            active_items.append({"name": "repair_kit", "korean": "수리키트", "rarity": "common", "type": "active"})
            active_items.append({"name": "berserk_potion", "korean": "광포화물약", "rarity": "common", "type": "active"})

        # === 패시브 아이템 풀 (30% 비율) ===
        passive_items = [
            # 레어 패시브 (기본)
            {"name": "speedboots", "korean": "스피드부츠", "rarity": "rare", "type": "passive"},
            {"name": "speedgear", "korean": "스피드기어", "rarity": "rare", "type": "passive"},
            {"name": "battery", "korean": "배터리", "rarity": "rare", "type": "passive"},
            {"name": "cooltime", "korean": "쿨타임", "rarity": "rare", "type": "passive"},
            {"name": "fuel_pouch", "korean": "연료파우치", "rarity": "rare", "type": "passive"},
            {"name": "dowsing_pendulum", "korean": "다우징팬들럼", "rarity": "rare", "type": "passive"},
            {"name": "smartphone", "korean": "스마트폰", "rarity": "rare", "type": "passive"},
            {"name": "bulletproof_hat", "korean": "방탄모자", "rarity": "rare", "type": "passive"},
            {"name": "knee_pads", "korean": "킥차져", "rarity": "rare", "type": "passive"},
            {"name": "slot_add", "korean": "배낭", "rarity": "rare", "type": "passive"},
            {"name": "spikeboots", "korean": "스파이크부츠", "rarity": "rare", "type": "passive"},
            {"name": "dashgear", "korean": "대쉬기어", "rarity": "rare", "type": "passive"},
            {"name": "bulkup", "korean": "벌크업", "rarity": "rare", "type": "passive"},
            {"name": "commando_arm", "korean": "코만도암", "rarity": "rare", "type": "passive"},
            {"name": "technical_vest", "korean": "테크니컬조끼", "rarity": "rare", "type": "passive"},
            {"name": "chargebag", "korean": "충전가방", "rarity": "rare", "type": "passive"},
            {"name": "spiked_helmet", "korean": "가시투구", "rarity": "rare", "type": "passive"},
            {"name": "bluetooth_ring", "korean": "블루투스링", "rarity": "rare", "type": "passive"},
            {"name": "foul_whistle", "korean": "반칙호루라기", "rarity": "rare", "type": "passive"},
            {"name": "star_detector", "korean": "스타감지기", "rarity": "rare", "type": "passive"},
            {"name": "dashholder", "korean": "대쉬홀더", "rarity": "rare", "type": "passive"},
            {"name": "master", "korean": "토르의망치", "rarity": "rare", "type": "passive"},
            # 에픽 패시브 (3개만)
            {"name": "sensor", "korean": "위험감지센서", "rarity": "epic", "type": "passive"},
            {"name": "gravitybelt", "korean": "무중력벨트", "rarity": "epic", "type": "passive"},
            {"name": "revival", "korean": "부활", "rarity": "epic", "type": "passive"},
            # 전설 패시브 - 완성된 5개 전설 아이템
            {"name": "ragnarok_hammer", "korean": "라그나로크해머", "rarity": "legendary", "type": "passive"},
            {"name": "hermes_shoes", "korean": "헤르메스의신발", "rarity": "legendary", "type": "passive"},
            {"name": "poseidon_trident", "korean": "포세이돈의삼지창", "rarity": "legendary", "type": "passive"},
            {"name": "angel_blessing", "korean": "천사의가호", "rarity": "legendary", "type": "passive"},
            {"name": "sacred_laurel", "korean": "신성월계수", "rarity": "legendary", "type": "passive"},
        ]

        # 캡슐 색상 (레어리티별)
        capsule_colors = {
            "common": (150, 200, 255),    # 파란색 캡슐
            "rare": (255, 215, 100),      # 금색 캡슐
            "epic": (200, 100, 255),      # 보라색 캡슐
            "legendary": (255, 100, 100), # 빨간색 캡슐 (전설)
        }

        # 12~18개의 랜덤 캡슐 배치
        num_prizes = random.randint(12, 18)
        used_items = set()

        for _ in range(num_prizes):
            # 1단계: 액티브(70%) vs 패시브(30%) 결정
            is_active = random.random() < 0.70

            if is_active:
                # 액티브 아이템 풀에서 선택
                item_pool = active_items
                # 액티브 레어리티 확률: 커먼 97%, 에픽 3% (판도라상자)
                roll = random.random()
                if roll < 0.03:  # 3% 에픽
                    rarity = "epic"
                else:  # 97% 커먼
                    rarity = "common"
            else:
                # 패시브 아이템 풀에서 선택
                item_pool = passive_items
                # 패시브 레어리티 확률: 레어 92%, 에픽 6%, 전설 2%
                roll = random.random()
                if roll < 0.02:  # 2% 전설
                    rarity = "legendary"
                elif roll < 0.08:  # 6% 에픽
                    rarity = "epic"
                else:  # 92% 레어
                    rarity = "rare"

            # 해당 레어리티의 아이템 선택
            available = [item for item in item_pool if item["rarity"] == rarity and item["name"] not in used_items]
            if not available:
                available = [item for item in item_pool if item["rarity"] == rarity]
            if not available:
                # 해당 레어리티가 없으면 레어에서 선택
                available = [item for item in item_pool if item["rarity"] == "rare"]
            if not available:
                # 레어도 없으면 커먼에서 선택
                available = [item for item in item_pool if item["rarity"] == "common"]
            if not available:
                continue

            selected_item = random.choice(available)
            used_items.add(selected_item["name"])

            # 캡슐 초기 위치 및 움직임 설정
            self.crane_prizes.append({
                "x": random.uniform(0.1, 0.9),
                "y": random.uniform(0.55, 0.85),
                "vx": random.uniform(-0.002, 0.002),  # X 속도
                "vy": random.uniform(-0.001, 0.001),  # Y 속도
                "item": selected_item,
                "capsule_color": capsule_colors[rarity],
                "grabbed": False,
                "wobble": random.uniform(0, 6.28),
                "rotation": random.uniform(0, 360),  # 회전 각도
            })

    def _reset_crane_game(self):
        """크레인 게임 상태 초기화 - 1회 시스템"""
        self.crane_x = 0.5
        self.crane_y = 0.0
        self.crane_state = "idle"
        self.crane_direction = 1
        self.crane_grab_timer = 0
        self.crane_time_remaining = self.crane_time_limit  # 타이머 초기화
        self.crane_attempts = 1  # 1회 시스템으로 변경
        self.crane_grabbed_prize = None
        self.crane_result = None
        self._init_crane_prizes()

    def _start_crane_game(self):
        """크레인 게임 시작 (골드 차감 후)"""
        current_gold = self.player_data.get('gold', 0)
        if current_gold < self.crane_game_cost:
            return False

        # 골드 차감
        self.player_data['gold'] = current_gold - self.crane_game_cost

        # 골드 감소 애니메이션
        self._add_gold_float_animation(self.crane_game_cost, is_gain=False)

        # 거래 효과음
        if self.trade_sound:
            self.trade_sound.play()

        # 크레인 게임 BGM 재생
        if self.crane_bgm_path:
            try:
                pygame.mixer.music.load(self.crane_bgm_path)
                pygame.mixer.music.set_volume(0.5)
                pygame.mixer.music.play(-1)  # 무한 반복
            except Exception as e:
                print(f"[크레인] BGM 재생 실패: {e}")

        # 게임 상태 초기화 및 시작
        self._reset_crane_game()
        self.crane_game_playing = True
        self.crane_confirm_dialog_open = False

        return True

    def _stop_crane_bgm(self):
        """크레인 게임 BGM 중지 및 광장 BGM 복구"""
        try:
            pygame.mixer.music.stop()
            # 광장 BGM 복구 (bgm_manager 사용)
            import bgm_manager
            bgm_manager.play_downtown_bgm()
        except Exception as e:
            print(f"[크레인] BGM 복구 실패: {e}")

    def _update_crane_game(self, dt):
        """크레인 게임 업데이트"""
        if not self.crane_game_playing:
            return

        # 캡슐 움직임 및 애니메이션
        for prize in self.crane_prizes:
            if not prize["grabbed"]:
                # 흔들림 애니메이션
                prize["wobble"] += dt * 2

                # 캡슐 위치 이동 (vx, vy 속도로 움직임)
                prize["x"] += prize["vx"]
                prize["y"] += prize["vy"]

                # 회전 애니메이션
                prize["rotation"] += dt * 30  # 천천히 회전

                # 벽에 부딪히면 방향 반전 (X축)
                if prize["x"] <= 0.1:
                    prize["x"] = 0.1
                    prize["vx"] = abs(prize["vx"])
                elif prize["x"] >= 0.9:
                    prize["x"] = 0.9
                    prize["vx"] = -abs(prize["vx"])

                # 벽에 부딪히면 방향 반전 (Y축)
                if prize["y"] <= 0.55:
                    prize["y"] = 0.55
                    prize["vy"] = abs(prize["vy"])
                elif prize["y"] >= 0.85:
                    prize["y"] = 0.85
                    prize["vy"] = -abs(prize["vy"])

                # 랜덤하게 방향 약간 변경 (자연스러운 움직임)
                if random.random() < 0.01:  # 1% 확률로
                    prize["vx"] += random.uniform(-0.001, 0.001)
                    prize["vy"] += random.uniform(-0.0005, 0.0005)
                    # 속도 제한
                    prize["vx"] = max(-0.004, min(0.004, prize["vx"]))
                    prize["vy"] = max(-0.002, min(0.002, prize["vy"]))

        if self.crane_state == "idle":
            # 타이머 감소
            self.crane_time_remaining -= dt
            if self.crane_time_remaining <= 0:
                # 시간 초과 - 자동으로 집기 시작
                self.crane_time_remaining = 0
                self.crane_state = "dropping"
                print("[크레인] 시간 초과! 자동으로 집기 시작")

            # 자동 좌우 이동
            self.crane_x += self.crane_direction * self.crane_speed
            if self.crane_x >= 0.9:
                self.crane_direction = -1
            elif self.crane_x <= 0.1:
                self.crane_direction = 1

        elif self.crane_state == "dropping":
            # 크레인 내려가기
            self.crane_y += 0.015
            if self.crane_y >= 0.85:
                self.crane_state = "grabbing"
                self.crane_grab_timer = 0.5  # 0.5초 대기

        elif self.crane_state == "grabbing":
            # 집기 시도
            self.crane_grab_timer -= dt
            if self.crane_grab_timer <= 0:
                # 인형 잡기 시도
                self._try_grab_prize()
                self.crane_state = "rising"

        elif self.crane_state == "rising":
            # 크레인 올라가기
            self.crane_y -= 0.012
            if self.crane_y <= 0.0:
                self.crane_y = 0.0
                self.crane_state = "returning"

        elif self.crane_state == "returning":
            # 배출구로 이동 (왼쪽 끝)
            if self.crane_x > 0.05:
                self.crane_x -= 0.01
            else:
                # 배출구 도착 - 집게 벌림 애니메이션 시작
                self.crane_state = "releasing"
                self.crane_claw_open = 0.0  # 닫힌 상태에서 시작
                self.crane_drop_y = 0.0
                self.crane_drop_speed = 0.0
                self.crane_drop_bounce = 0

        elif self.crane_state == "releasing":
            # 집게 벌림 애니메이션
            self.crane_claw_open += 0.05  # 천천히 열림
            if self.crane_claw_open >= 1.0:
                self.crane_claw_open = 1.0
                # 아이템 낙하 시작
                if self.crane_grabbed_prize:
                    self.crane_state = "item_falling"
                else:
                    # 빈 손이면 바로 결과
                    self.crane_result = {"success": False, "prize": None}
                    self.crane_attempts -= 1
                    self.crane_state = "result"
                    self.crane_grab_timer = 2.0

        elif self.crane_state == "item_falling":
            # 아이템 낙하 애니메이션
            self.crane_drop_speed += 0.015  # 중력 (더 빠르게)
            self.crane_drop_y += self.crane_drop_speed

            # 바닥에 닿으면 튀어오름
            ground_y = 1.0  # 바닥 위치
            if self.crane_drop_y >= ground_y and self.crane_drop_speed > 0:
                self.crane_drop_y = ground_y  # 바닥에 고정
                self.crane_drop_speed = -self.crane_drop_speed * 0.4  # 튀어오름 (감쇠)
                self.crane_drop_bounce += 1

                # 속도가 너무 작으면 멈춤
                if abs(self.crane_drop_speed) < 0.02:
                    self.crane_drop_speed = 0
                    self.crane_drop_bounce = 3  # 강제로 종료 조건 충족

            # 2번 이상 튀어오른 후 결과 처리
            if self.crane_drop_bounce >= 2 and self.crane_drop_speed >= -0.01:
                # 성공! 캡슐 획득
                self.crane_result = {
                    "success": True,
                    "prize": self.crane_grabbed_prize
                }

                # 실제 아이템을 플레이어 인벤토리에 추가
                item_info = self.crane_grabbed_prize.get("item", {})
                item_name = item_info.get("name", "")
                if item_name:
                    self._give_crane_item_to_player(item_name)

                # 캡슐 제거
                self.crane_prizes = [p for p in self.crane_prizes if p != self.crane_grabbed_prize]
                self.crane_grabbed_prize = None

                self.crane_attempts -= 1
                self.crane_state = "result"
                self.crane_grab_timer = 2.0  # 결과 표시 시간

        elif self.crane_state == "result":
            self.crane_grab_timer -= dt
            if self.crane_grab_timer <= 0:
                if self.crane_attempts <= 0:
                    # 게임 종료
                    self.crane_game_playing = False
                    self.crane_state = "idle"
                    # 크레인 BGM 중지 및 광장 BGM 복구
                    self._stop_crane_bgm()
                else:
                    # 다음 시도
                    self.crane_x = 0.5
                    self.crane_y = 0.0
                    self.crane_state = "idle"
                    self.crane_result = None

    def _give_crane_item_to_player(self, item_name):
        """크레인 게임에서 획득한 아이템을 플레이어 인벤토리에 추가"""
        try:
            import sys
            if 'pingfighter' in sys.modules:
                pingfighter = sys.modules['pingfighter']

                # items 모듈에서 ITEM_TYPES 가져오기
                if 'items' in sys.modules:
                    items_module = sys.modules['items']

                    # 패시브 아이템 목록 (store_passive_item으로 처리해야 하는 아이템들)
                    passive_items = [
                        # 커먼 패시브
                        "speedboots", "speedgear", "battery", "cooltime", "fuel_pouch",
                        "dowsing_pendulum", "smartphone", "bulletproof_hat", "knee_pads", "slot_add",
                        # 레어 패시브
                        "spikeboots", "dashgear", "bulkup", "commando_arm", "technical_vest",
                        "chargebag", "spiked_helmet", "bluetooth_ring", "foul_whistle", "star_detector",
                        # 에픽 패시브
                        "sensor", "gravitybelt", "dashholder", "revival", "master",
                        "angel_blessing", "sacred_laurel",
                        # 전설 패시브
                        "ragnarok_hammer", "hermes_shoes", "poseidon_trident",
                        "zeus_lightning", "hades_helm"
                    ]

                    # ITEM_TYPES에서 해당 아이템 찾기
                    for item_data in items_module.ITEM_TYPES:
                        if item_data.get("name") == item_name:
                            # 아이템 데이터 복사
                            item_copy = item_data.copy()

                            # 패시브 아이템인지 확인
                            if item_name in passive_items:
                                # store_passive_item 함수 호출
                                if hasattr(pingfighter, 'store_passive_item'):
                                    pingfighter.store_passive_item(item_copy)
                                    print(f"[크레인 게임] 패시브 아이템 획득: {item_name}")
                            else:
                                # store_active_item 함수 호출 (액티브 아이템)
                                if hasattr(pingfighter, 'store_active_item'):
                                    pingfighter.store_active_item(item_copy)
                                    print(f"[크레인 게임] 액티브 아이템 획득: {item_name}")

                            # 효과음 재생
                            if hasattr(pingfighter, 'item_sound') and pingfighter.item_sound:
                                pingfighter.item_sound.play()
                            break
        except Exception as e:
            print(f"[크레인 게임] 아이템 획득 오류: {e}")

    def _try_grab_prize(self):
        """캡슐 잡기 시도 - 크레인 중심에 정확히 위치해야 잡힘"""
        # 크레인 집게 중심부에 캡슐이 정확히 있어야 잡힘 (매우 좁은 범위)
        grab_range_x = 0.025  # 가로 범위 (집게 중심부만)
        grab_range_y = 0.08   # 세로 범위 (집게가 내려가는 방향)

        # 가장 가까운 캡슐 찾기
        closest_prize = None
        closest_distance = float('inf')

        for prize in self.crane_prizes:
            if prize["grabbed"]:
                continue

            dx = abs(self.crane_x - prize["x"])
            dy = abs(self.crane_y - prize["y"])
            distance = (dx ** 2 + dy ** 2) ** 0.5

            # 크레인 중심에 정확히 있어야만 잡힘 (가장자리는 불가)
            if dx < grab_range_x and dy < grab_range_y and distance < closest_distance:
                closest_distance = distance
                closest_prize = prize

        # 정확한 위치에 캡슐이 있으면 100% 성공
        if closest_prize:
            closest_prize["grabbed"] = True
            self.crane_grabbed_prize = closest_prize
        else:
            self.crane_grabbed_prize = None

    def _check_nearby_gacha_machine(self):
        """플레이어 근처에 가챠 머신이 있는지 확인"""
        if self.building_type != BuildingType.GACHA:
            return None

        player_rect = pygame.Rect(
            self.player.x - 30, self.player.y - 30, 60, 60
        )

        # 디버그 출력 (숨김)
        # print(f"[DEBUG] Player pos: ({self.player.x}, {self.player.y}), rect: {player_rect}")
        # for i, machine_info in enumerate(self.gacha_machine_rects):
        #     print(f"[DEBUG] Machine {i}: interact={machine_info['rect']}, machine={machine_info['machine_rect']}")

        for i, machine_info in enumerate(self.gacha_machine_rects):
            if player_rect.colliderect(machine_info["rect"]):
                return i

        return None

    def _check_nearby_headmaster(self):
        """아카데미 학장(교관) 근처에 있는지 확인"""
        if self.building_type != BuildingType.ACADEMY:
            return False

        # 학장 NPC 찾기
        headmaster = None
        for npc in self.npcs:
            if npc.role == "main":
                headmaster = npc
                break

        if headmaster is None:
            return False

        # 플레이어와 학장 사이 거리 계산
        player_x = self.player.x
        player_y = self.player.y
        npc_x = headmaster.x
        npc_y = headmaster.y
        distance = math.sqrt((player_x - npc_x) ** 2 + (player_y - npc_y) ** 2)

        # 100픽셀 이내에 있으면 True
        return distance <= 100

    def _check_gacha_machine_click(self, world_x, world_y):
        """가챠 머신이 클릭되었는지 확인 (플레이어가 근처에 있어야 함)"""
        if self.building_type != BuildingType.GACHA:
            return None

        # 플레이어가 근처에 있는 머신만 클릭 가능
        nearby_machine = self._check_nearby_gacha_machine()
        if nearby_machine is None:
            return None

        # 근처에 있는 머신을 클릭했는지 확인
        machine_info = self.gacha_machine_rects[nearby_machine]
        if machine_info["rect"].collidepoint(world_x, world_y):
            return nearby_machine

        return None

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
        """전투 아카데미 전용 NPC 생성 - 훈련생들 (프리스매셔, 프리발토르, 프리코만도)"""
        npcs = []

        # === 교관 타이탄 (메인 NPC) - 미래전사 스타일 ===
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
        # 교관 특수 속성 - 미래전사 느낌
        main_npc.is_commander = True
        npcs.append(main_npc)

        # === 훈련생 NPC 배치 (8~12명) ===
        trainee_count = random.randint(8, 12)

        # 훈련생 유형별 이름과 색상
        # 프리스매셔 (힘/근육형) - 빨강/주황 계열
        pre_smasher_names = ["록키", "타이슨", "브루스"]
        pre_smasher_color = (255, 120, 80)  # 주황-빨강

        # 프리발토르 (속도/민첩형) - 파랑/시안 계열
        pre_baltor_names = ["스위프트", "블레이즈", "제트"]
        pre_baltor_color = (100, 180, 255)  # 밝은 파랑

        # 프리코만도 (정확/사격형) - 초록/카키 계열
        pre_commando_names = ["헌터", "스나이퍼", "레인저"]
        pre_commando_color = (120, 180, 100)  # 카키/초록

        trainee_dialogues = {
            "pre_smasher": [
                ["하! 파워 훈련 중이다!", "더 강해질 거야!"],
                ["이 타이어 100개 넘는다!", "근육이 불타!"],
                ["스매셔 선배처럼 되고 싶어!", "포기란 없다!"],
            ],
            "pre_baltor": [
                ["속도가 생명이지!", "대쉬, 또 대쉬!"],
                ["발토르 선배의 스피드에 도전!", "바람보다 빠르게!"],
                ["민첩성 훈련 중!", "번개처럼 움직여!"],
            ],
            "pre_commando": [
                ["조준... 발사!", "정확도가 전부야."],
                ["코만도 선배의 사격술을 배우는 중.", "한 발, 한 명."],
                ["침착하게, 정확하게.", "훈련이 실력을 만든다."],
            ],
            "ping_pong": [
                ["탁구로 반사신경 훈련!", "좋아, 좋은 랠리야!"],
                ["손목 스냅이 중요해!", "이기면 아이스크림!"],
            ],
        }

        wall_h = int(TILE_SIZE * 3.5)
        center_x = self.pixel_width // 2
        center_y = (wall_h + self.pixel_height) // 2

        # 탁구대 위치 (장애물 영역과 일치 - 분산 배치)
        table_w, table_h = 140, 85
        table1_x, table1_y = 100, wall_h + 180  # 왼쪽 상단
        table2_x, table2_y = self.pixel_width - 280, self.pixel_height - 200  # 오른쪽 하단

        trainee_idx = 0

        # === 탁구대 1 (프리발토르 vs 프리스매셔) - 왼쪽 상단 ===
        if trainee_idx < trainee_count:
            # 프리발토르 (왼쪽 - 탁구대 왼쪽)
            pp1 = InteriorNPC(
                table1_x - 25, table1_y + table_h // 2,
                random.choice(pre_baltor_names), "customer",
                pre_baltor_color, random.choice(trainee_dialogues["ping_pong"]), self.building_type
            )
            pp1.academy_activity = "ping_pong"
            pp1.trainee_type = "pre_baltor"
            pp1.direction = 2  # 오른쪽 보기
            pp1.ping_pong_timer = 0
            npcs.append(pp1)
            trainee_idx += 1

        if trainee_idx < trainee_count:
            # 프리스매셔 (오른쪽 - 탁구대 오른쪽)
            pp2 = InteriorNPC(
                table1_x + table_w + 25, table1_y + table_h // 2,
                random.choice(pre_smasher_names), "customer",
                pre_smasher_color, random.choice(trainee_dialogues["ping_pong"]), self.building_type
            )
            pp2.academy_activity = "ping_pong"
            pp2.trainee_type = "pre_smasher"
            pp2.direction = 1  # 왼쪽 보기
            pp2.ping_pong_timer = 0.5
            if trainee_idx > 0:
                pp2.ping_pong_partner = pp1
                pp1.ping_pong_partner = pp2
            npcs.append(pp2)
            trainee_idx += 1

        # === 탁구대 2 (프리코만도 vs 프리발토르) - 오른쪽 하단 ===
        if trainee_idx < trainee_count:
            # 프리코만도 (왼쪽 - 탁구대 왼쪽)
            pp3 = InteriorNPC(
                table2_x - 25, table2_y + table_h // 2,
                random.choice(pre_commando_names), "customer",
                pre_commando_color, random.choice(trainee_dialogues["ping_pong"]), self.building_type
            )
            pp3.academy_activity = "ping_pong"
            pp3.trainee_type = "pre_commando"
            pp3.direction = 2  # 오른쪽 보기
            pp3.ping_pong_timer = 0.3
            npcs.append(pp3)
            trainee_idx += 1

        if trainee_idx < trainee_count:
            # 프리발토르 (오른쪽 - 탁구대 오른쪽)
            pp4 = InteriorNPC(
                table2_x + table_w + 25, table2_y + table_h // 2,
                random.choice(pre_baltor_names), "customer",
                pre_baltor_color, random.choice(trainee_dialogues["ping_pong"]), self.building_type
            )
            pp4.academy_activity = "ping_pong"
            pp4.trainee_type = "pre_baltor"
            pp4.direction = 1  # 왼쪽 보기
            pp4.ping_pong_timer = 0.8
            pp4.ping_pong_partner = pp3
            pp3.ping_pong_partner = pp4
            npcs.append(pp4)
            trainee_idx += 1

        # === 대쉬 연습 프리발토르 (2명, 러닝 트랙) ===
        if trainee_idx < trainee_count:
            dash_trainee = InteriorNPC(
                220, center_y + 80,
                random.choice(pre_baltor_names), "customer",
                pre_baltor_color, random.choice(trainee_dialogues["pre_baltor"]), self.building_type
            )
            dash_trainee.academy_activity = "dash_practice"
            dash_trainee.trainee_type = "pre_baltor"
            dash_trainee.direction = 0  # 위쪽
            dash_trainee.dash_state = "running"
            dash_trainee.dash_timer = random.uniform(0, 1.5)
            npcs.append(dash_trainee)
            trainee_idx += 1

        # === 타이어/수류탄 훈련 프리스매셔 (2명) ===
        strength_positions = [
            (60, wall_h + 120),  # 타이어 근처
            (130, wall_h + 100),  # 수류탄 상자 근처
        ]
        for i, (px, py) in enumerate(strength_positions):
            if trainee_idx >= trainee_count:
                break
            strength_trainee = InteriorNPC(
                px, py,
                random.choice(pre_smasher_names), "customer",
                pre_smasher_color, random.choice(trainee_dialogues["pre_smasher"]), self.building_type
            )
            strength_trainee.academy_activity = "strength_training" if i == 0 else "grenade_practice"
            strength_trainee.trainee_type = "pre_smasher"
            strength_trainee.direction = 0
            strength_trainee.practice_timer = random.uniform(0, 2)
            npcs.append(strength_trainee)
            trainee_idx += 1

        # === 사격 연습 프리코만도 (1명, 사격장) ===
        if trainee_idx < trainee_count:
            shooter = InteriorNPC(
                self.pixel_width - 90, wall_h + 150,
                random.choice(pre_commando_names), "customer",
                pre_commando_color, random.choice(trainee_dialogues["pre_commando"]), self.building_type
            )
            shooter.academy_activity = "shooting_practice"
            shooter.trainee_type = "pre_commando"
            shooter.direction = 0  # 위쪽 (과녁 방향)
            shooter.practice_timer = random.uniform(0, 3)
            shooter.is_aiming = True
            npcs.append(shooter)
            trainee_idx += 1

        # === 대기/휴식 중인 훈련생들 ===
        rest_positions = [
            (center_x - 100, center_y + 150),
            (center_x + 150, center_y + 130),
            (center_x - 50, center_y + 180),
        ]
        trainee_types = [
            ("pre_smasher", pre_smasher_names, pre_smasher_color, trainee_dialogues["pre_smasher"]),
            ("pre_baltor", pre_baltor_names, pre_baltor_color, trainee_dialogues["pre_baltor"]),
            ("pre_commando", pre_commando_names, pre_commando_color, trainee_dialogues["pre_commando"]),
        ]

        rest_idx = 0
        while trainee_idx < trainee_count and rest_idx < len(rest_positions):
            px, py = rest_positions[rest_idx]
            px += random.randint(-20, 20)
            py += random.randint(-10, 10)

            t_type, t_names, t_color, t_dialogues = trainee_types[rest_idx % len(trainee_types)]

            resting_trainee = InteriorNPC(
                px, py,
                random.choice(t_names), "customer",
                t_color, random.choice(t_dialogues), self.building_type
            )
            resting_trainee.academy_activity = "standing"
            resting_trainee.trainee_type = t_type
            resting_trainee.direction = random.choice([0, 1, 2, 3])
            npcs.append(resting_trainee)
            trainee_idx += 1
            rest_idx += 1

        # === 걸어다니는 훈련생 (나머지) ===
        walking_positions = [
            (center_x - 80, center_y + 120),
            (center_x + 80, center_y + 100),
        ]

        walk_idx = 0
        while trainee_idx < trainee_count:
            px, py = walking_positions[walk_idx % len(walking_positions)]
            px += random.randint(-30, 30)
            py += random.randint(-20, 20)

            t_type, t_names, t_color, t_dialogues = trainee_types[walk_idx % len(trainee_types)]

            walking_trainee = InteriorNPC(
                px, py,
                random.choice(t_names), "customer",
                t_color, random.choice(t_dialogues), self.building_type
            )
            walking_trainee.academy_activity = "walking"
            walking_trainee.trainee_type = t_type
            walking_trainee.is_walking = False
            walking_trainee.walk_timer = random.uniform(1, 4)
            walking_trainee.walk_range = 60
            npcs.append(walking_trainee)
            trainee_idx += 1
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

        # 상점 장애물 충돌 체크 (ITEM_SHOP 전용)
        if hasattr(self, 'shop_obstacle_rects') and self.shop_obstacle_rects:
            for obstacle_rect in self.shop_obstacle_rects:
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

        # 골드 변동 애니메이션 업데이트
        self._update_gold_float_animations(dt)

        # 크레인 게임 업데이트
        if self.crane_game_playing:
            self._update_crane_game(dt)
            return  # 크레인 게임 중에는 다른 업데이트 차단

        # 환전 슬라이더 드래그 중이면 마우스 위치로 값 업데이트
        if self.exchange_menu_open and self.exchange_slider_dragging:
            mouse_pos = pygame.mouse.get_pos()
            self._handle_exchange_slider_drag(mouse_pos)

        # 입장 쿨다운 감소
        if self.entry_cooldown > 0:
            self.entry_cooldown -= dt

        # 메뉴가 열려있으면 플레이어 입력 차단
        if self.bank_menu_open or self.exchange_menu_open or self.academy_dialog_open or self.crane_confirm_dialog_open:
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

        # 가챠 건물에서 근처 머신 체크
        if self.building_type == BuildingType.GACHA:
            self.nearby_gacha_machine = self._check_nearby_gacha_machine()
            self.nearby_crane_game = self._check_nearby_crane_game()

        # 아카데미 건물에서 학장 근처 체크
        if self.building_type == BuildingType.ACADEMY:
            self.nearby_headmaster = self._check_nearby_headmaster()

        # 일반 NPC 근처 체크 (상호작용 힌트용)
        self.nearby_npc = self._check_nearby_npc()

    def _check_nearby_npc(self):
        """근처에 있는 대화 가능한 NPC 찾기 (100픽셀 이내)"""
        player_x = self.player.x
        player_y = self.player.y

        closest_npc = None
        closest_distance = float('inf')

        for npc in self.npcs:
            # 거리 계산
            distance = math.sqrt((player_x - npc.x) ** 2 + (player_y - npc.y) ** 2)

            # 100픽셀 이내이고 가장 가까운 NPC 선택
            if distance <= 100 and distance < closest_distance:
                closest_npc = npc
                closest_distance = distance

        return closest_npc

    def handle_click(self, pos, button=1):
        """클릭 처리 (button: 1=좌클릭, 3=우클릭)"""
        # 크레인 게임 플레이 중일 때
        if self.crane_game_playing:
            if self.crane_state == "idle":
                # 클릭으로 크레인 내리기
                self.crane_state = "dropping"
                return ("crane_drop", None)
            elif self.crane_state == "result":
                # 결과 화면에서 클릭시 다음으로
                self.crane_grab_timer = 0
                return ("crane_next", None)
            return None

        # 크레인 게임 확인 다이얼로그가 열려있으면
        if self.crane_confirm_dialog_open:
            return self._handle_crane_confirm_click(pos)

        # 상점 거래창이 열려있으면 거래 처리
        if self.shop_trade_open:
            if button == 3:  # 우클릭 = 판매/구매
                return self._handle_shop_trade_click(pos)
            else:  # 좌클릭 = 닫기 체크 (UI 바깥 클릭시)
                return self._handle_shop_trade_left_click(pos)

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

        # 가챠 건물에서 가챠 머신 클릭 체크
        if self.building_type == BuildingType.GACHA:
            clicked_machine = self._check_gacha_machine_click(world_x, world_y)
            if clicked_machine is not None:
                self.gacha_interact_requested = True
                self.nearby_gacha_machine = clicked_machine
                return ("gacha_interact", clicked_machine)

            # 크레인 게임 클릭 체크 -> 확인 다이얼로그 열기
            clicked_crane = self._check_crane_game_click(world_x, world_y)
            if clicked_crane is not None:
                self.crane_interact_requested = True
                self.nearby_crane_game = clicked_crane
                self.crane_confirm_dialog_open = True  # 확인 다이얼로그 열기
                self.crane_confirm_selection = 0  # 기본: 예
                return ("crane_confirm_dialog", clicked_crane)

        # NPC 클릭 체크 (플레이어가 가까이 있어야 함)
        for npc in self.npcs:
            npc_rect = npc.get_rect()
            if npc_rect.collidepoint(world_x, world_y):
                # 플레이어와 NPC 사이 거리 체크 (100픽셀 이내)
                player_x = self.player.x
                player_y = self.player.y
                npc_x = npc.x
                npc_y = npc.y
                distance = math.sqrt((player_x - npc_x) ** 2 + (player_y - npc_y) ** 2)

                # 거리가 100픽셀 초과면 상호작용 불가
                if distance > 100:
                    return None

                # 은행 메인 NPC인 경우 메뉴 열기
                if self.building_type == BuildingType.BANK and npc.role == "main":
                    self.bank_menu_open = True
                    self.bank_menu_selection = 0
                    return ("bank_menu", npc)
                # 아카데미 메인 NPC(학장 아르카나)인 경우 대화창 열기
                elif self.building_type == BuildingType.ACADEMY and npc.role == "main":
                    self.academy_dialog_open = True
                    self.academy_dialog_selection = 0
                    return ("academy_dialog", npc)
                # 상점 인간 상인 (점주 그린)인 경우 거래창 열기
                elif self.building_type == BuildingType.ITEM_SHOP and getattr(npc, 'is_shop_human', False):
                    self.shop_trade_open = True
                    self.shop_hover_item = None
                    return ("shop_trade", npc)
                else:
                    dialogue = npc.start_dialogue()
                    if dialogue:
                        return ("talk", npc)

        return None

    def handle_mouse_up(self, pos, button=1):
        """마우스 버튼 릴리즈 처리"""
        # 환전 슬라이더 드래그 종료
        if self.exchange_menu_open and button == 1:
            if self._handle_exchange_slider_release():
                return ("exchange_drag_end", None)

        # 상점 거래창에서 드래그 앤 드롭 처리
        if self.shop_trade_open and button == 1:  # 좌클릭 릴리즈
            if self.shop_dragging_item:
                return self._handle_shop_drag_release(pos)
        return None

    def _handle_shop_trade_click(self, pos):
        """상점 거래창 우클릭 처리 (판매/구매) - 아이콘 그리드 방식"""
        # 확인 창이 열려있다면 먼저 처리
        if self.shop_confirm_dialog:
            return self._handle_shop_confirm_click(pos)

        # shop_item_rects를 사용하여 클릭된 아이템 확인
        if not hasattr(self, 'shop_item_rects'):
            return None

        # 플레이어 인벤토리 클릭 확인
        for idx, rect in self.shop_item_rects.get("player", {}).items():
            if rect.collidepoint(pos):
                return self._sell_player_item(idx, pos)

        # 상점 인벤토리 클릭 확인
        for idx, rect in self.shop_item_rects.get("shop", {}).items():
            if rect.collidepoint(pos):
                return self._buy_shop_item(idx, pos)

        return None

    def _handle_shop_trade_left_click(self, pos):
        """상점 거래창 좌클릭 처리 (드래그 시작 또는 UI 바깥 클릭시 닫기)"""
        # 확인 다이얼로그가 열려있으면 버튼 처리 우선
        if self.shop_confirm_dialog:
            result = self._handle_shop_confirm_click(pos)
            if result:
                return result

        # UI 영역 및 스크롤바 계산 (draw와 동일)
        total_w, total_h = 620, 420
        ui_x = (SCREEN_WIDTH - total_w) // 2
        ui_y = (SCREEN_HEIGHT - total_h) // 2
        panel_w = 280
        gap = 20
        panel_h = total_h - 100

        left_x = ui_x + 20
        left_y = ui_y + 50
        right_x = ui_x + panel_w + gap + 20
        right_y = ui_y + 50

        grid_y_left = left_y + 35
        grid_y_right = right_y + 35
        grid_h = panel_h - 60

        left_track = pygame.Rect(left_x + panel_w - 12, grid_y_left, 8, grid_h)
        right_track = pygame.Rect(right_x + panel_w - 12, grid_y_right, 8, grid_h)

        def _apply_scroll(click_pos, track_rect, max_scroll, visible_rows):
            if max_scroll <= 0:
                return None
            thumb_h = max(18, int(track_rect.height * (visible_rows / max(visible_rows + max_scroll, 1))))
            rel = max(0, min(track_rect.height - thumb_h, click_pos[1] - track_rect.y - thumb_h // 2))
            ratio = 0 if (track_rect.height - thumb_h) == 0 else rel / (track_rect.height - thumb_h)
            return max(0, min(max_scroll, int(round(ratio * max_scroll))))

        # 좌측 스크롤바 클릭
        if left_track.collidepoint(pos):
            new_scroll = _apply_scroll(pos, left_track, self._shop_player_max_scroll, self._shop_player_visible_rows)
            if new_scroll is not None:
                self.shop_player_scroll = new_scroll
                return ("shop_player_scroll", new_scroll)

        # 우측 스크롤바 클릭
        if right_track.collidepoint(pos):
            new_scroll = _apply_scroll(pos, right_track, self._shop_shop_max_scroll, self._shop_shop_visible_rows)
            if new_scroll is not None:
                self.shop_shop_scroll = new_scroll
                return ("shop_shop_scroll", new_scroll)

        # 아이템 드래그 시작 체크
        try:
            import pingfighter
            player_items = getattr(pingfighter, 'passive_item_list', [])
        except:
            player_items = []

        # 플레이어 인벤토리에서 드래그 시작
        for idx, rect in self.shop_item_rects.get("player", {}).items():
            if rect.collidepoint(pos) and idx < len(player_items):
                item = player_items[idx]
                self.shop_dragging_item = {
                    'source': 'player',
                    'idx': idx,
                    'item': item.copy()
                }
                self.shop_drag_start_pos = pos
                self.shop_drag_offset = (pos[0] - rect.centerx, pos[1] - rect.centery)
                return ("drag_start", {"source": "player", "idx": idx})

        # 상점 인벤토리에서 드래그 시작
        for idx, rect in self.shop_item_rects.get("shop", {}).items():
            if rect.collidepoint(pos) and idx < len(self.shop_inventory):
                item = self.shop_inventory[idx]
                self.shop_dragging_item = {
                    'source': 'shop',
                    'idx': idx,
                    'item': item.copy()
                }
                self.shop_drag_start_pos = pos
                self.shop_drag_offset = (pos[0] - rect.centerx, pos[1] - rect.centery)
                return ("drag_start", {"source": "shop", "idx": idx})

        # UI 바깥 클릭시 닫기
        ui_rect = pygame.Rect(ui_x, ui_y, total_w, total_h)
        if not ui_rect.collidepoint(pos):
            self.shop_trade_open = False
            return ("shop_close", None)

        return None

    def _handle_shop_drag_release(self, pos):
        """드래그 놓기 처리 (구매/판매/위치 교환)"""
        if not self.shop_dragging_item:
            return None

        drag_source = self.shop_dragging_item['source']
        drag_idx = self.shop_dragging_item['idx']
        drag_item = self.shop_dragging_item['item']

        # 드래그 상태 초기화
        self.shop_dragging_item = None
        self.shop_drag_start_pos = None

        try:
            import pingfighter
            player_items = getattr(pingfighter, 'passive_item_list', [])
        except:
            player_items = []

        # UI 영역 계산
        total_w, total_h = 620, 420
        ui_x = (SCREEN_WIDTH - total_w) // 2
        ui_y = (SCREEN_HEIGHT - total_h) // 2
        panel_w = 280
        gap = 20

        left_panel = pygame.Rect(ui_x + 20, ui_y + 50, panel_w, total_h - 100)
        right_panel = pygame.Rect(ui_x + panel_w + gap + 20, ui_y + 50, panel_w, total_h - 100)

        # 플레이어 인벤토리에서 시작한 드래그
        if drag_source == 'player':
            # 상점 패널에 놓으면 판매
            if right_panel.collidepoint(pos):
                return self._sell_player_item(drag_idx, pos)

            # 플레이어 패널 내에서 위치 교환
            if left_panel.collidepoint(pos):
                for idx, rect in self.shop_item_rects.get("player", {}).items():
                    if rect.collidepoint(pos) and idx != drag_idx and idx < len(player_items):
                        # 위치 교환
                        player_items[drag_idx], player_items[idx] = player_items[idx], player_items[drag_idx]
                        return ("swap_player", {"from": drag_idx, "to": idx})
                return None

        # 상점 인벤토리에서 시작한 드래그
        elif drag_source == 'shop':
            # 플레이어 패널에 놓으면 구매
            if left_panel.collidepoint(pos):
                return self._buy_shop_item(drag_idx, pos)

            # 상점 패널 내에서 위치 교환
            if right_panel.collidepoint(pos):
                for idx, rect in self.shop_item_rects.get("shop", {}).items():
                    if rect.collidepoint(pos) and idx != drag_idx and idx < len(self.shop_inventory):
                        # 위치 교환
                        self.shop_inventory[drag_idx], self.shop_inventory[idx] = self.shop_inventory[idx], self.shop_inventory[drag_idx]
                        return ("swap_shop", {"from": drag_idx, "to": idx})
                return None

        return None

    def _sell_player_item(self, idx, mouse_pos=None):
        """플레이어 아이템 판매"""
        try:
            import pingfighter
            player_items = getattr(pingfighter, 'passive_item_list', [])

            if idx >= len(player_items):
                return None

            item = player_items[idx]
            item_name = item.get("name", "")
            is_equipped = bool(item.get("_equipped_slot"))

            # 판매가 계산 (품질 + 롤옵션 수치 반영 가격의 30%)
            base_price = self._get_item_base_price(item_name)
            quality_roll_bonus = self._get_quality_and_roll_bonus(item, base_price)
            sell_price = int((base_price + quality_roll_bonus) * 0.3)
            shop_price = int((base_price + quality_roll_bonus) * 1.0)

            # 장착 중이면 판매 확인 팝업 띄우기
            if is_equipped:
                self.shop_confirm_dialog = {
                    "action": "sell_equipped",
                    "item": item,
                    "item_name": item_name,
                    "sell_price": sell_price,
                    "shop_price": shop_price,
                }
                return ("confirm_sell_equipped", {"item": item_name, "price": sell_price})

            # 플레이어 골드 증가
            current_gold = self.player_data.get('gold', 0)
            self.player_data['gold'] = current_gold + sell_price

            # 골드 획득 애니메이션 추가 (초록색, + 표시, 마우스 위치)
            self._add_gold_float_animation(sell_price, is_gain=True, pos=mouse_pos)

            # 거래 효과음 재생
            if self.trade_sound:
                self.trade_sound.play()

            # 플레이어 인벤토리에서 제거
            removed_item = pingfighter.passive_item_list.pop(idx)

            # 상점 인벤토리에 추가 (롤옵션, 품질 정보 유지)
            korean_name = self._get_item_korean_name(item_name)
            shop_item = {
                "name": item_name,
                "korean": korean_name,
                "price": shop_price,  # 상점은 원가+품질보너스로 판매
                "type": removed_item.get("type", "passive"),
                "icon": None,
                # 롤옵션 및 품질 정보 유지
                "rolled_options": removed_item.get("rolled_options", []),
                "quality_tier": removed_item.get("quality_tier"),
                "name_prefix": removed_item.get("name_prefix"),
                "quality_color": removed_item.get("quality_color"),
            }
            self.shop_inventory.append(shop_item)

            return ("sold", {"item": item_name, "price": sell_price})

        except Exception as e:
            print(f"아이템 판매 실패: {e}")
            return None

    def _buy_shop_item(self, idx, mouse_pos=None):
        """상점 아이템 구매"""
        if idx >= len(self.shop_inventory):
            return None

        item = self.shop_inventory[idx]
        price = item.get("price", 0)
        item_name = item.get("name", "")

        # 골드 확인
        current_gold = self.player_data.get('gold', 0)
        if current_gold < price:
            return ("not_enough_gold", {"need": price, "have": current_gold})

        # 골드 차감
        self.player_data['gold'] = current_gold - price

        # 골드 소모 애니메이션 추가 (빨간색, - 표시, 마우스 위치)
        self._add_gold_float_animation(price, is_gain=False, pos=mouse_pos)

        # 거래 효과음 재생
        if self.trade_sound:
            self.trade_sound.play()

        # 상점 인벤토리에서 제거
        removed_item = self.shop_inventory.pop(idx)

        # 플레이어 인벤토리에 추가
        try:
            import pingfighter

            # 아이템 데이터 생성 (롤옵션, 품질 정보 유지)
            item_data = {
                "name": item_name,
                "type": removed_item.get("type", "passive"),
                "icon": None,
                # 롤옵션 및 품질 정보 유지
                "rolled_options": removed_item.get("rolled_options", []),
                "quality_tier": removed_item.get("quality_tier"),
                "name_prefix": removed_item.get("name_prefix"),
                "quality_color": removed_item.get("quality_color"),
            }

            # 롤옵션이 없는 경우 새로 생성
            if not item_data.get("rolled_options") and item_data.get("type") == "passive":
                ensure_passive_rolls = getattr(pingfighter, 'ensure_passive_rolls', None)
                if ensure_passive_rolls:
                    ensure_passive_rolls(item_data)

            # passive_item_list에 추가
            pingfighter.passive_item_list.append(item_data)

            # 전설 아이템인 경우 획득 플래그 설정
            if removed_item.get("type") == "legendary":
                if item_name == "ragnarok_hammer":
                    import items
                    items.ragnarok_hammer_obtained = True
                elif item_name == "hermes_shoes":
                    import items
                    items.hermes_shoes_obtained = True
                elif item_name == "poseidon_trident":
                    import items
                    items.poseidon_trident_obtained = True
                elif item_name == "angel_blessing":
                    import items
                    items.angel_blessing_obtained = True
                elif item_name == "sacred_laurel":
                    import items
                    items.sacred_laurel_obtained = True

            return ("bought", {"item": item_name, "price": price})

        except Exception as e:
            print(f"아이템 구매 실패: {e}")
            # 실패시 골드 복구
            self.player_data['gold'] = current_gold
            return None

    def _handle_shop_confirm_click(self, pos):
        """장착 아이템 판매 확인 다이얼로그 클릭 처리"""
        if not self.shop_confirm_dialog:
            return None

        dialog_rect, yes_rect, no_rect = self._get_shop_confirm_rects()
        if yes_rect.collidepoint(pos):
            result = self._execute_shop_confirm()
            self.shop_confirm_dialog = None
            return result
        if no_rect.collidepoint(pos):
            # '아니오' 클릭 또는 다이얼로그 내부 다른 곳은 취소
            self.shop_confirm_dialog = None
            return ("cancel_confirm", None)
        # 다이얼로그 내부 빈 공간 클릭은 무시
        if dialog_rect.collidepoint(pos):
            return None
        return None

    def _get_shop_confirm_rects(self):
        """확인 다이얼로그 영역 반환"""
        dialog_w, dialog_h = 260, 140
        dialog_x = (SCREEN_WIDTH - dialog_w) // 2
        dialog_y = (SCREEN_HEIGHT - dialog_h) // 2
        dialog_rect = pygame.Rect(dialog_x, dialog_y, dialog_w, dialog_h)
        btn_w, btn_h = 90, 34
        btn_y = dialog_y + dialog_h - btn_h - 16
        yes_rect = pygame.Rect(dialog_x + 24, btn_y, btn_w, btn_h)
        no_rect = pygame.Rect(dialog_x + dialog_w - btn_w - 24, btn_y, btn_w, btn_h)
        return dialog_rect, yes_rect, no_rect

    def _execute_shop_confirm(self):
        """확인된 판매 실행"""
        data = self.shop_confirm_dialog or {}
        if data.get("action") != "sell_equipped":
            return None
        try:
            import pingfighter
            player_items = getattr(pingfighter, 'passive_item_list', [])
        except Exception:
            return None

        item = data.get("item")
        if item not in player_items:
            return None
        idx = player_items.index(item)
        item_name = data.get("item_name", item.get("name", ""))
        sell_price = data.get("sell_price", 0)
        shop_price = data.get("shop_price", 0)

        # 골드 증가
        current_gold = self.player_data.get('gold', 0)
        self.player_data['gold'] = current_gold + sell_price

        # 효과 표시
        self._add_gold_float_animation(sell_price, is_gain=True, pos=pygame.mouse.get_pos())

        # 인벤토리에서 제거
        removed_item = pingfighter.passive_item_list.pop(idx)

        # 상점에 추가
        korean_name = self._get_item_korean_name(item_name)
        shop_item = {
            "name": item_name,
            "korean": korean_name,
            "price": shop_price,
            "type": removed_item.get("type", "passive"),
            "icon": None,
            "rolled_options": removed_item.get("rolled_options", []),
            "quality_tier": removed_item.get("quality_tier"),
            "name_prefix": removed_item.get("name_prefix"),
            "quality_color": removed_item.get("quality_color"),
        }
        self.shop_inventory.append(shop_item)
        return ("sold", {"item": item_name, "price": sell_price})

    def _add_gold_float_animation(self, amount, is_gain=True, pos=None):
        """골드 변동 플로팅 애니메이션 추가"""
        # 마우스 위치가 있으면 오른쪽 상단 오프셋 적용, 없으면 화면 중앙
        if pos:
            x = pos[0] + 20  # 마우스 오른쪽으로 20px
            y = pos[1] - 30  # 마우스 위로 30px
        else:
            x = SCREEN_WIDTH // 2
            y = 80

        anim = {
            'amount': amount,
            'is_gain': is_gain,  # True: 획득(초록), False: 소모(빨강)
            'x': x,
            'y': y,
            'start_y': y,
            'timer': 0,
            'duration': 1.2,  # 1.2초 동안 표시
            'alpha': 255
        }
        self.gold_float_animations.append(anim)

    def _add_star_float_animation(self, amount, pos=None):
        """스타포인트 획득 플로팅 애니메이션 추가"""
        # 위치 설정
        if pos:
            x = pos[0] + 20
            y = pos[1] - 30
        else:
            x = SCREEN_WIDTH // 2
            y = 80

        anim = {
            'amount': amount,
            'is_gain': True,  # 스타포인트는 항상 획득
            'is_star': True,  # 스타포인트 표시용 플래그
            'x': x,
            'y': y,
            'start_y': y,
            'timer': 0,
            'duration': 1.2,
            'alpha': 255
        }
        self.gold_float_animations.append(anim)

    def _update_gold_float_animations(self, dt):
        """골드 변동 애니메이션 업데이트"""
        animations_to_remove = []

        for anim in self.gold_float_animations:
            anim['timer'] += dt

            # 위로 떠오르는 효과 (총 30픽셀 상승)
            progress = anim['timer'] / anim['duration']
            anim['y'] = anim['start_y'] - int(30 * progress)

            # 페이드아웃 (후반 50%에서 시작)
            if progress > 0.5:
                fade_progress = (progress - 0.5) / 0.5  # 0 ~ 1
                anim['alpha'] = int(255 * (1 - fade_progress))

            # 애니메이션 완료
            if anim['timer'] >= anim['duration']:
                animations_to_remove.append(anim)

        # 완료된 애니메이션 제거
        for anim in animations_to_remove:
            self.gold_float_animations.remove(anim)

    def _draw_gold_float_animations(self, screen):
        """골드 변동 플로팅 애니메이션 그리기"""
        if not self.gold_float_animations:
            return

        font_small = self.fonts.get('small')
        if not font_small:
            return

        for anim in self.gold_float_animations:
            amount = anim['amount']
            is_gain = anim['is_gain']
            is_star = anim.get('is_star', False)  # 스타포인트 여부
            x = anim['x']
            y = anim['y']
            alpha = anim['alpha']

            # 스타포인트 애니메이션
            if is_star:
                text_color = (100, 220, 255)  # 시안색
                sign = "+"
                text = f"{sign} {amount}★"
                icon_char = "★"
                icon_color = (100, 200, 255, alpha)
                icon_dark = (60, 150, 200, alpha)
            else:
                # 골드 애니메이션
                if is_gain:
                    text_color = (50, 255, 100)  # 초록색
                    sign = "+"
                else:
                    text_color = (255, 80, 80)  # 빨간색
                    sign = "-"
                text = f"{sign} {amount}G"
                icon_char = "G"
                icon_color = (255, 215, 0, alpha)  # 금색
                icon_dark = (200, 160, 0, alpha)

            # 반투명 서피스 생성
            text_surf, text_rect = font_small.render(text, text_color)

            # 아이콘 크기
            coin_size = 16

            # 전체 너비 계산
            total_width = coin_size + 4 + text_rect.width
            start_x = x - total_width // 2

            # 알파값이 있는 서피스 생성
            anim_surface = pygame.Surface((total_width + 10, max(coin_size, text_rect.height) + 10), pygame.SRCALPHA)

            # 아이콘 그리기
            coin_center_x = coin_size // 2 + 5
            coin_center_y = anim_surface.get_height() // 2

            if is_star:
                # 스타 아이콘 (별 모양)
                star_surf, _ = font_small.render("★", (100, 220, 255))
                star_surf.set_alpha(alpha)
                anim_surface.blit(star_surf, (coin_center_x - star_surf.get_width() // 2, coin_center_y - star_surf.get_height() // 2))
            else:
                # 골드 아이콘 (금화)
                pygame.draw.circle(anim_surface, icon_color, (coin_center_x, coin_center_y), coin_size // 2)
                pygame.draw.circle(anim_surface, icon_dark, (coin_center_x, coin_center_y), coin_size // 2, 2)
                g_surf, _ = font_small.render("G", (180, 140, 0))
                g_surf.set_alpha(alpha)
                anim_surface.blit(g_surf, (coin_center_x - g_surf.get_width() // 2, coin_center_y - g_surf.get_height() // 2))

            # 텍스트 그리기
            text_surf.set_alpha(alpha)
            text_x = coin_size + 8
            text_y = (anim_surface.get_height() - text_rect.height) // 2
            anim_surface.blit(text_surf, (text_x, text_y))

            # 화면에 그리기
            screen.blit(anim_surface, (start_x, y - anim_surface.get_height() // 2))

    def _draw_dragging_item(self, screen, mouse_pos):
        """드래그 중인 아이템 그리기 (마우스 위치에)"""
        if not self.shop_dragging_item:
            return

        item = self.shop_dragging_item['item']
        item_name = item.get("name", "")

        # 아이콘 크기
        icon_size = 40

        # 마우스 위치 중심으로 그리기 (드래그 오프셋 적용)
        draw_x = mouse_pos[0] - icon_size // 2
        draw_y = mouse_pos[1] - icon_size // 2

        # 반투명 배경
        bg_surface = pygame.Surface((icon_size + 4, icon_size + 4), pygame.SRCALPHA)
        bg_surface.fill((40, 50, 70, 200))
        pygame.draw.rect(bg_surface, (150, 200, 255, 200), bg_surface.get_rect(), 2, border_radius=4)
        screen.blit(bg_surface, (draw_x - 2, draw_y - 2))

        # 아이템 아이콘 그리기
        icon = None
        try:
            import pingfighter
            get_item_icon = getattr(pingfighter, 'get_item_icon', None)
            if get_item_icon:
                icon = get_item_icon(item_name)
        except:
            pass

        if icon:
            # 아이콘을 적절한 크기로 스케일
            scaled_icon = pygame.transform.scale(icon, (icon_size, icon_size))
            screen.blit(scaled_icon, (draw_x, draw_y))
        else:
            # 아이콘이 없으면 색상 사각형으로 표시
            color = item.get("color", (100, 150, 200))
            pygame.draw.rect(screen, color, (draw_x, draw_y, icon_size, icon_size), border_radius=4)
            pygame.draw.rect(screen, (200, 200, 200), (draw_x, draw_y, icon_size, icon_size), 2, border_radius=4)

        # 품질 테두리
        quality_tier = item.get("quality_tier")
        if quality_tier:
            quality_colors = {
                "top": (255, 215, 0),      # 금색
                "high": (180, 100, 255),   # 보라색
                "mid": (100, 180, 255),    # 파란색
                "low": (150, 150, 150)     # 회색
            }
            qcolor = quality_colors.get(quality_tier, (150, 150, 150))
            pygame.draw.rect(screen, qcolor, (draw_x - 2, draw_y - 2, icon_size + 4, icon_size + 4), 2, border_radius=4)

    def handle_key(self, event):
        """키 입력 처리 (이벤트 기반)"""
        if event.type != pygame.KEYDOWN:
            return None

        # 상점 거래창이 열려있을 때
        if self.shop_trade_open:
            if event.key == pygame.K_ESCAPE:
                self.shop_trade_open = False
                return ("shop_close", None)
            return None  # 다른 키는 무시

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

        # 크레인 게임 확인 다이얼로그가 열려있을 때
        if self.crane_confirm_dialog_open:
            if event.key == pygame.K_LEFT or event.key == pygame.K_a:
                self.crane_confirm_selection = 0  # 예
                return ("crane_dialog_move", None)
            elif event.key == pygame.K_RIGHT or event.key == pygame.K_d:
                self.crane_confirm_selection = 1  # 아니오
                return ("crane_dialog_move", None)
            elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                if self.crane_confirm_selection == 0:  # 예
                    # 골드 체크 후 게임 시작
                    current_gold = self.player_data.get('gold', 0)
                    if current_gold >= self.crane_game_cost:
                        self._start_crane_game()
                        return ("crane_game_start", None)
                    else:
                        # 골드 부족
                        self.crane_confirm_dialog_open = False
                        return ("not_enough_gold", {"need": self.crane_game_cost, "have": current_gold})
                else:  # 아니오
                    self.crane_confirm_dialog_open = False
                    self.crane_interact_requested = False
                    return ("crane_dialog_cancel", None)
            elif event.key == pygame.K_ESCAPE:
                self.crane_confirm_dialog_open = False
                self.crane_interact_requested = False
                return ("crane_dialog_cancel", None)
            return None

        # 크레인 게임 플레이 중일 때
        if self.crane_game_playing:
            if self.crane_state == "idle":
                # 스페이스/엔터로 크레인 내리기
                if event.key == pygame.K_SPACE or event.key == pygame.K_RETURN:
                    self.crane_state = "dropping"
                    return ("crane_drop", None)
            elif self.crane_state == "result":
                # 아무 키나 누르면 다음으로
                if event.key == pygame.K_SPACE or event.key == pygame.K_RETURN or event.key == pygame.K_ESCAPE:
                    self.crane_grab_timer = 0  # 즉시 다음으로
                    return ("crane_next", None)
            # ESC로 게임 종료
            if event.key == pygame.K_ESCAPE:
                self.crane_game_playing = False
                self.crane_state = "idle"
                # 크레인 BGM 중지 및 광장 BGM 복구
                self._stop_crane_bgm()
                return ("crane_game_exit", None)
            return None

        # 메뉴가 닫혀있을 때 - Space로 상호작용
        if event.key == pygame.K_SPACE:
            # 가챠 건물에서는 먼저 가챠 머신 상호작용 확인
            if self.building_type == BuildingType.GACHA:
                nearby_machine = self._check_nearby_gacha_machine()
                if nearby_machine is not None:
                    self.gacha_interact_requested = True
                    self.nearby_gacha_machine = nearby_machine
                    return ("gacha_interact", nearby_machine)

                # 크레인 게임 상호작용 확인 -> 확인 다이얼로그 열기
                nearby_crane = self._check_nearby_crane_game()
                if nearby_crane is not None:
                    self.crane_interact_requested = True
                    self.nearby_crane_game = nearby_crane
                    self.crane_confirm_dialog_open = True  # 확인 다이얼로그 열기
                    self.crane_confirm_selection = 0  # 기본: 예
                    return ("crane_confirm_dialog", nearby_crane)

            # NPC 상호작용
            return self._try_interact_with_npc()

        return None

    def handle_scroll(self, event, mouse_pos=None):
        """마우스 휠 스크롤 처리 (슬라이더 위에서만 작동)"""
        if event.type == pygame.MOUSEWHEEL:
            # 상점 거래창 스크롤
            if self.shop_trade_open:
                if self.shop_confirm_dialog:
                    return None  # 확인창 열려있을 땐 스크롤 무시
                if mouse_pos:
                    total_w, total_h = 620, 420
                    ui_x = (SCREEN_WIDTH - total_w) // 2
                    ui_y = (SCREEN_HEIGHT - total_h) // 2
                    panel_w = 280
                    gap = 20
                    left_x = ui_x + 20
                    left_y = ui_y + 50
                    right_x = ui_x + panel_w + gap + 20
                    right_y = ui_y + 50
                    panel_h = total_h - 100

                    grid_y_left = left_y + 35
                    grid_h_left = panel_h - 60
                    grid_y_right = right_y + 35
                    grid_h_right = panel_h - 60

                    left_rect = pygame.Rect(left_x, left_y, panel_w, panel_h)
                    right_rect = pygame.Rect(right_x, right_y, panel_w, panel_h)

                    delta = -event.y  # 휠 위로: y=1, 스크롤 감소

                    if left_rect.collidepoint(mouse_pos):
                        if self._shop_player_max_scroll > 0:
                            self.shop_player_scroll = max(0, min(self._shop_player_max_scroll, self.shop_player_scroll + delta))
                            return ("shop_player_scroll", self.shop_player_scroll)
                    if right_rect.collidepoint(mouse_pos):
                        if self._shop_shop_max_scroll > 0:
                            self.shop_shop_scroll = max(0, min(self._shop_shop_max_scroll, self.shop_shop_scroll + delta))
                            return ("shop_shop_scroll", self.shop_shop_scroll)
                # 바깥에서 스크롤한 경우 무시
                return None

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
            # 스타포인트 → 골드: 스타포인트가 0이면 0 반환
            return star_points
        else:
            # 골드 → 스타포인트: 골드가 환율보다 적으면 0 반환
            if self.current_exchange_rate > 0:
                return gold // self.current_exchange_rate
            return 0

    def _adjust_exchange_amount(self, delta):
        """환전 양 조절"""
        max_amount = self._get_max_exchange_amount()

        # 소지량이 없으면 0으로 유지
        if max_amount <= 0:
            self.exchange_amount = 0
            return

        self.exchange_amount = max(1, self.exchange_amount + delta)
        self.exchange_amount = min(self.exchange_amount, max_amount)

    def _update_exchange_slider_from_pos(self, mouse_x):
        """마우스 X 위치로 환전 슬라이더 값 업데이트"""
        if not self.exchange_slider_rect:
            return

        # 최대값 계산
        max_amount = self._get_max_exchange_amount()

        # 소지량이 없으면 0으로 유지
        if max_amount <= 0:
            self.exchange_amount = 0
            return

        slider_x = self.exchange_slider_rect.x
        slider_w = self.exchange_slider_rect.width

        # 마우스 위치를 0~1 비율로 변환
        ratio = (mouse_x - slider_x) / slider_w
        ratio = max(0, min(1, ratio))

        # 비율에 따른 양 계산 (최소 1)
        self.exchange_amount = max(1, int(ratio * max_amount))

    def _handle_exchange_slider_drag(self, pos):
        """환전 슬라이더 드래그 처리"""
        if self.exchange_slider_dragging:
            self._update_exchange_slider_from_pos(pos[0])
            return True
        return False

    def _handle_exchange_slider_release(self):
        """환전 슬라이더 드래그 종료"""
        if self.exchange_slider_dragging:
            self.exchange_slider_dragging = False
            return True
        return False

    def _execute_exchange(self):
        """환전 실행"""
        # 애니메이션 위치 (환전 버튼 근처)
        menu_w, menu_h = 340, 270
        menu_x = (SCREEN_WIDTH - menu_w) // 2
        menu_y = (SCREEN_HEIGHT - menu_h) // 2
        anim_pos = (menu_x + menu_w // 2, menu_y + 200)

        if self.exchange_direction == 0:
            # 스타포인트 → 골드
            star_points = self._get_current_star_points()
            if star_points >= self.exchange_amount:
                gold_gained = self.exchange_amount * self.current_exchange_rate
                new_star_points = star_points - self.exchange_amount
                self._set_star_points(new_star_points)
                self.player_data['gold'] = self.player_data.get('gold', 0) + gold_gained
                # 골드 획득 애니메이션 (초록색)
                self._add_gold_float_animation(gold_gained, is_gain=True, pos=anim_pos)
                # 거래 효과음
                if self.trade_sound:
                    self.trade_sound.play()
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
                # 스타포인트 획득 애니메이션 (시안색) - 커스텀
                self._add_star_float_animation(self.exchange_amount, pos=anim_pos)
                # 거래 효과음 (골드 → 스타포인트 전용)
                if self.star_exchange_sound:
                    self.star_exchange_sound.play()
                elif self.trade_sound:
                    self.trade_sound.play()
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
                # 아카데미 메인 NPC (학장 아르카나)인 경우 - 마우스 클릭으로만 상호작용
                # 스페이스바로는 상호작용 불가 (마우스 클릭 필요)
                elif self.building_type == BuildingType.ACADEMY and npc.role == "main":
                    # 스페이스바 대신 마우스 클릭 안내 (상호작용 불가)
                    return None
                # 상점 인간 상인 (점주 그린)인 경우 거래창 열기
                elif self.building_type == BuildingType.ITEM_SHOP and getattr(npc, 'is_shop_human', False):
                    self.shop_trade_open = True
                    self.shop_hover_item = None
                    return ("shop_trade", npc)
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
            self.exchange_direction = 0
            # 소지량에 따라 초기값 설정
            max_amount = self._get_max_exchange_amount()
            self.exchange_amount = 1 if max_amount > 0 else 0
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

    def _handle_crane_confirm_click(self, pos):
        """크레인 게임 확인 다이얼로그 클릭 처리"""
        # 다이얼로그 영역 계산 (화면 중앙)
        dialog_w, dialog_h = 320, 180
        dialog_x = (SCREEN_WIDTH - dialog_w) // 2
        dialog_y = (SCREEN_HEIGHT - dialog_h) // 2

        # 버튼 영역
        btn_w, btn_h = 80, 32
        btn_y = dialog_y + dialog_h - 50
        yes_btn = pygame.Rect(dialog_x + dialog_w // 2 - btn_w - 20, btn_y, btn_w, btn_h)
        no_btn = pygame.Rect(dialog_x + dialog_w // 2 + 20, btn_y, btn_w, btn_h)

        if yes_btn.collidepoint(pos):
            # 예 선택 - 게임 시작
            current_gold = self.player_data.get('gold', 0)
            if current_gold >= self.crane_game_cost:
                self._start_crane_game()
                return ("crane_game_start", None)
            else:
                # 골드 부족
                self.crane_confirm_dialog_open = False
                return ("not_enough_gold", {"need": self.crane_game_cost, "have": current_gold})
        elif no_btn.collidepoint(pos):
            # 아니오 선택 - 다이얼로그 닫기
            self.crane_confirm_dialog_open = False
            self.crane_interact_requested = False
            return ("crane_dialog_cancel", None)

        # 다이얼로그 바깥 클릭시 닫기
        dialog_rect = pygame.Rect(dialog_x, dialog_y, dialog_w, dialog_h)
        if not dialog_rect.collidepoint(pos):
            self.crane_confirm_dialog_open = False
            self.crane_interact_requested = False
            return ("crane_dialog_cancel", None)

        return None

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
            # 소지량에 따라 초기값 설정
            max_amount = self._get_max_exchange_amount()
            self.exchange_amount = 1 if max_amount > 0 else 0
            return ("exchange_direction", None)
        elif right_btn.collidepoint(pos):
            self.exchange_direction = 1  # 골드 → 스타포인트
            # 소지량에 따라 초기값 설정
            max_amount = self._get_max_exchange_amount()
            self.exchange_amount = 1 if max_amount > 0 else 0
            return ("exchange_direction", None)

        # +/- 버튼 클릭 처리
        slider_y = menu_y + 135
        slider_w = 240
        minus_btn = pygame.Rect(menu_x + 15, slider_y - 2, 30, 32)
        plus_btn = pygame.Rect(menu_x + slider_w + 61, slider_y - 2, 30, 32)

        if minus_btn.collidepoint(pos):
            # 10% 감소 또는 최소 1 감소
            max_amount = self._get_max_exchange_amount()
            if max_amount <= 0:
                self.exchange_amount = 0
            else:
                decrement = max(1, max_amount // 10)
                self.exchange_amount = max(1, self.exchange_amount - decrement)
            return ("exchange_minus", None)

        if plus_btn.collidepoint(pos):
            # 10% 증가
            max_amount = self._get_max_exchange_amount()
            if max_amount <= 0:
                self.exchange_amount = 0
            else:
                increment = max(1, max_amount // 10)
                self.exchange_amount = min(max_amount, self.exchange_amount + increment)
            return ("exchange_plus", None)

        # 슬라이더 드래그 시작 처리
        slider_x = menu_x + 50
        slider_w = 240
        slider_h = 28
        slider_rect = pygame.Rect(slider_x, slider_y - 10, slider_w, slider_h + 20)  # 클릭 영역 확장

        if slider_rect.collidepoint(pos):
            # 드래그 시작
            self.exchange_slider_dragging = True
            self.exchange_slider_rect = pygame.Rect(slider_x, slider_y, slider_w, slider_h)
            # 클릭 위치로 양 즉시 계산
            self._update_exchange_slider_from_pos(pos[0])
            return ("exchange_drag_start", None)

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

        # === 개선된 슬라이더 UI ===
        slider_y = menu_y + 135
        slider_x = menu_x + 50  # 좌우 버튼 공간 확보
        slider_w = 240
        slider_h = 28

        # 최대값 계산
        if self.exchange_direction == 0:
            max_amount = max(1, star_points)
        else:
            max_amount = max(1, gold // self.current_exchange_rate) if self.current_exchange_rate > 0 else 1

        # 슬라이더 영역 저장 (드래그 처리용)
        self._slider_rect = pygame.Rect(slider_x, slider_y, slider_w, slider_h)
        self._slider_max = max_amount
        self.exchange_slider_rect = pygame.Rect(slider_x, slider_y, slider_w, slider_h)

        # - 버튼 (좌측)
        minus_btn = pygame.Rect(menu_x + 15, slider_y - 2, 30, 32)
        mouse_pos = pygame.mouse.get_pos()
        minus_hover = minus_btn.collidepoint(mouse_pos)
        minus_color = (80, 60, 60) if minus_hover else (50, 40, 40)
        pygame.draw.rect(screen, minus_color, minus_btn, border_radius=6)
        pygame.draw.rect(screen, (180, 100, 100), minus_btn, 2, border_radius=6)
        pygame.draw.line(screen, (220, 150, 150), (minus_btn.x + 8, minus_btn.centery), (minus_btn.x + 22, minus_btn.centery), 3)

        # + 버튼 (우측) - 슬라이더 바로 오른쪽
        plus_btn = pygame.Rect(menu_x + slider_w + 61, slider_y - 2, 30, 32)
        plus_hover = plus_btn.collidepoint(mouse_pos)
        plus_color = (60, 80, 60) if plus_hover else (40, 50, 40)
        pygame.draw.rect(screen, plus_color, plus_btn, border_radius=6)
        pygame.draw.rect(screen, (100, 180, 100), plus_btn, 2, border_radius=6)
        pygame.draw.line(screen, (150, 220, 150), (plus_btn.x + 8, plus_btn.centery), (plus_btn.x + 22, plus_btn.centery), 3)
        pygame.draw.line(screen, (150, 220, 150), (plus_btn.centerx, plus_btn.y + 8), (plus_btn.centerx, plus_btn.y + 24), 3)

        # 저장 (클릭 처리용)
        self._exchange_minus_btn = minus_btn
        self._exchange_plus_btn = plus_btn

        # 슬라이더 트랙 배경 (어두운 색상으로 채움과 구분)
        track_rect = pygame.Rect(slider_x, slider_y, slider_w, slider_h)
        pygame.draw.rect(screen, (15, 18, 25), track_rect, border_radius=14)
        pygame.draw.rect(screen, (25, 30, 40), (slider_x + 2, slider_y + 2, slider_w - 4, slider_h - 4), border_radius=12)

        # 눈금 표시 (10%, 25%, 50%, 75% 위치)
        for pct in [0.25, 0.5, 0.75]:
            tick_x = slider_x + int(slider_w * pct)
            pygame.draw.line(screen, (60, 70, 90), (tick_x, slider_y + 6), (tick_x, slider_y + slider_h - 6), 1)

        # 슬라이더 채움 (그라데이션 효과)
        fill_ratio = min(1.0, self.exchange_amount / max_amount) if max_amount > 0 else 0
        fill_w = int((slider_w - 8) * fill_ratio)
        if fill_w > 4:
            # 채움 색상 (방향에 따라 다른 색상)
            if self.exchange_direction == 0:
                fill_color = (80, 180, 220)  # 시안 (스타포인트)
                glow_color = (100, 200, 240)
            else:
                fill_color = (220, 180, 80)  # 골드
                glow_color = (240, 200, 100)
            pygame.draw.rect(screen, fill_color, (slider_x + 4, slider_y + 4, fill_w, slider_h - 8), border_radius=10)
            # 상단 하이라이트
            pygame.draw.rect(screen, glow_color, (slider_x + 4, slider_y + 4, fill_w, 4), border_radius=10)

        # 슬라이더 핸들 (크고 눈에 띄게)
        handle_x = slider_x + 4 + fill_w
        handle_y = slider_y + slider_h // 2
        handle_radius = 14 if self.exchange_slider_dragging else 12

        # 드래그 중일 때 글로우 효과
        if self.exchange_slider_dragging:
            glow_surf = pygame.Surface((40, 40), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (100, 200, 255, 80), (20, 20), 18)
            screen.blit(glow_surf, (handle_x - 20, handle_y - 20))

        # 핸들 외곽 (그림자)
        pygame.draw.circle(screen, (20, 30, 40), (handle_x + 1, handle_y + 1), handle_radius)
        # 핸들 본체
        handle_color = (200, 220, 255) if self.exchange_slider_dragging else (180, 200, 230)
        pygame.draw.circle(screen, handle_color, (handle_x, handle_y), handle_radius)
        # 핸들 내부 (입체감)
        pygame.draw.circle(screen, (220, 235, 255), (handle_x - 2, handle_y - 2), handle_radius - 4)
        # 핸들 중앙 점
        pygame.draw.circle(screen, (100, 130, 180), (handle_x, handle_y), 3)

        # 양 표시 (슬라이더 위, 더 크게)
        if font_medium:
            amt_text = f"{self.exchange_amount:,}"
            amt_surf, amt_rect = font_medium.render(amt_text, TEXT_WHITE)
            screen.blit(amt_surf, (slider_x + slider_w // 2 - amt_rect.width // 2, slider_y - 26))

        # 최소/최대 라벨 (버튼 아래)
        if font_small:
            min_surf, _ = font_small.render("MIN", (80, 90, 110))
            screen.blit(min_surf, (minus_btn.centerx - 12, slider_y + slider_h + 6))
            max_surf, _ = font_small.render("MAX", (80, 90, 110))
            screen.blit(max_surf, (plus_btn.centerx - 14, slider_y + slider_h + 6))

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

        # 환전 실행 버튼 (호버 효과)
        confirm_btn = pygame.Rect(menu_x + 30, menu_y + 218, 280, 38)
        confirm_hover = confirm_btn.collidepoint(mouse_pos)
        if confirm_hover:
            # 호버 시 밝은 색상
            btn_bg_color = (60, 120, 90)
            btn_border_color = (150, 255, 150)
            btn_text_color = (200, 255, 200)
        else:
            btn_bg_color = (40, 80, 60)
            btn_border_color = TEXT_GREEN
            btn_text_color = TEXT_GREEN
        pygame.draw.rect(screen, btn_bg_color, confirm_btn, border_radius=6)
        pygame.draw.rect(screen, btn_border_color, confirm_btn, 2, border_radius=6)
        if font_medium:
            btn_surf, btn_rect = font_medium.render("환전하기", btn_text_color)
            screen.blit(btn_surf, (confirm_btn.centerx - btn_rect.width // 2, confirm_btn.centery - btn_rect.height // 2))

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
        elif special_interior == "cyberpunk_gacha":
            # 사이버펑크 가챠샵 전용 인테리어
            self._draw_cyberpunk_gacha_interior(screen)
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

        # 크레인 게임 확인 다이얼로그 (맨 위에)
        if self.crane_confirm_dialog_open:
            self._draw_crane_confirm_dialog(screen)

        # 크레인 게임 플레이 화면 (최상위)
        if self.crane_game_playing:
            self._draw_crane_game_screen(screen)

        # 아카데미 학장 상호작용 힌트 (대화창 닫혀있고 근처일 때만)
        if self.building_type == BuildingType.ACADEMY:
            self._draw_headmaster_interact_hint(screen)

        # 일반 NPC 상호작용 힌트 (근처일 때만)
        self._draw_npc_interact_hint(screen)

        # 상점 거래창 (맨 위에)
        if self.shop_trade_open:
            self._draw_shop_trade_ui(screen)

        # 골드 변동 애니메이션 (최상위 레이어)
        self._draw_gold_float_animations(screen)

        # 드래그 중인 아이템 그리기 (최상위)
        if self.shop_trade_open and self.shop_dragging_item:
            mouse_pos = pygame.mouse.get_pos()
            self._draw_dragging_item(screen, mouse_pos)

    def _draw_shop_trade_ui(self, screen):
        """상점 거래 UI 그리기 - 아이콘 그리드 방식 (캐릭터 정보창 스타일)"""
        # UI 크기 및 위치 (더 넓게)
        total_w, total_h = 620, 420
        ui_x = (SCREEN_WIDTH - total_w) // 2
        ui_y = (SCREEN_HEIGHT - total_h) // 2

        panel_w = 280
        gap = 20  # 두 패널 사이 간격

        # 색상 정의 (캐릭터 정보창 스타일)
        BG_DARK = (22, 26, 40)
        PANEL_BG = (30, 36, 54)
        BORDER_MAIN = (90, 130, 200)
        BORDER_GOLD = (200, 170, 100)
        BORDER_CYAN = (100, 180, 200)
        TEXT_WHITE = (240, 240, 240)
        TEXT_GOLD = (255, 215, 100)
        TEXT_GRAY = (150, 150, 150)
        CELL_BG = (30, 36, 54)
        CELL_BORDER = (80, 110, 150)
        CELL_HOVER = (150, 200, 255)

        mouse_pos = pygame.mouse.get_pos()

        # 반투명 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        screen.blit(overlay, (0, 0))

        # 메인 배경
        pygame.draw.rect(screen, BG_DARK, (ui_x, ui_y, total_w, total_h), border_radius=10)
        pygame.draw.rect(screen, BORDER_MAIN, (ui_x, ui_y, total_w, total_h), 2, border_radius=10)

        # 폰트
        font_medium = self.fonts.get('medium')
        font_small = self.fonts.get('small')

        # === 플레이어 골드 표시 (상단) ===
        player_gold = self.player_data.get('gold', 0)
        gold_text = f"보유 골드: {player_gold:,}G"
        if font_medium:
            gold_surf, gold_rect = font_medium.render(gold_text, TEXT_GOLD)
            screen.blit(gold_surf, (ui_x + total_w // 2 - gold_rect.width // 2, ui_y + 12))

        # 아이템 목록 - pingfighter 가져오기
        try:
            import pingfighter
            player_items = getattr(pingfighter, 'passive_item_list', [])
            get_item_icon = getattr(pingfighter, 'get_item_icon', None)
            get_item_description = getattr(pingfighter, 'get_item_description', None)
        except:
            player_items = []
            get_item_icon = None
            get_item_description = None

        # 그리드 설정 (패널 높이에 맞춰 가변)
        cell_size = 42
        cell_gap = 6
        cols = 5

        self.shop_hover_item = None  # 매 프레임 리셋
        self.shop_item_rects = {"player": {}, "shop": {}}  # 클릭 영역 저장

        # === 좌측: 플레이어 인벤토리 (아이콘 그리드) ===
        left_x = ui_x + 20
        left_y = ui_y + 50

        # 패널 배경
        panel_h = total_h - 100
        pygame.draw.rect(screen, PANEL_BG, (left_x, left_y, panel_w, panel_h), border_radius=8)
        pygame.draw.rect(screen, BORDER_CYAN, (left_x, left_y, panel_w, panel_h), 2, border_radius=8)

        # 제목
        if font_small:
            title_surf, title_rect = font_small.render("내 인벤토리 (판매)", TEXT_WHITE)
            screen.blit(title_surf, (left_x + 10, left_y + 8))

        # 아이콘 그리드 시작 위치
        grid_x = left_x + 12
        grid_y = left_y + 35

        # 가시 영역 계산 (스크롤)
        grid_height = panel_h - 60  # 제목/힌트 제외
        visible_rows = max(1, (grid_height + cell_gap) // (cell_size + cell_gap))
        total_rows = max(1, math.ceil(len(player_items) / cols))
        self._shop_player_visible_rows = visible_rows
        self._shop_player_max_scroll = max(0, total_rows - visible_rows)
        self.shop_player_scroll = max(0, min(self.shop_player_scroll, self._shop_player_max_scroll))
        start_idx = self.shop_player_scroll * cols

        # 플레이어 아이템 그리드 그리기 (스크롤 적용)
        for vis_row in range(visible_rows):
            for col in range(cols):
                idx = start_idx + vis_row * cols + col
                cell_rect = pygame.Rect(
                    grid_x + col * (cell_size + cell_gap),
                    grid_y + vis_row * (cell_size + cell_gap),
                    cell_size,
                    cell_size
                )
                # 인덱스가 실제 아이템에 매핑될 때만 클릭/호버 처리
                if idx < len(player_items):
                    self.shop_item_rects["player"][idx] = cell_rect
                # 셀 배경
                pygame.draw.rect(screen, CELL_BG, cell_rect, border_radius=8)

                if idx >= len(player_items):
                    pygame.draw.rect(screen, (50, 60, 80), cell_rect, 1, border_radius=8)
                    continue

                item = player_items[idx]

                # 호버 체크
                is_hover = cell_rect.collidepoint(mouse_pos)
                if is_hover:
                    self.shop_hover_item = ("player", idx, item, cell_rect)
                    pygame.draw.rect(screen, CELL_HOVER, cell_rect, 2, border_radius=8)
                else:
                    pygame.draw.rect(screen, CELL_BORDER, cell_rect, 1, border_radius=8)

                # 아이콘 그리기
                item_name = item.get("name", "")
                icon = None
                if get_item_icon:
                    icon = get_item_icon(item_name)
                if not icon:
                    icon = item.get("icon")

                if icon:
                    scaled_icon = pygame.transform.scale(icon, (cell_size - 8, cell_size - 8))
                    screen.blit(scaled_icon, (cell_rect.x + 4, cell_rect.y + 4))
                # 장착 배지
                if item.get("_equipped_slot"):
                    badge_rect = pygame.Rect(cell_rect.right - 18, cell_rect.bottom - 14, 16, 12)
                    pygame.draw.rect(screen, (70, 160, 255), badge_rect, border_radius=3)
                    badge_surf = None
                    badge_font = self.fonts.get('tiny') or self.fonts.get('small')
                    if badge_font and hasattr(badge_font, "render"):
                        badge_surf, badge_rect_txt = badge_font.render("E", (255, 255, 255))
                    if badge_surf:
                        badge_pos = badge_surf.get_rect(center=badge_rect.center)
                        screen.blit(badge_surf, badge_pos)

        # 판매 안내 텍스트
        if font_small:
            hint_surf, _ = font_small.render("우클릭으로 판매 (30%)", (120, 180, 200))
            screen.blit(hint_surf, (left_x + 10, left_y + panel_h - 25))

        # === 우측: 상점 인벤토리 (아이콘 그리드) ===
        right_x = ui_x + panel_w + gap + 20
        right_y = ui_y + 50

        # 패널 배경
        pygame.draw.rect(screen, PANEL_BG, (right_x, right_y, panel_w, panel_h), border_radius=8)
        pygame.draw.rect(screen, BORDER_GOLD, (right_x, right_y, panel_w, panel_h), 2, border_radius=8)

        # 제목
        if font_small:
            title_surf, title_rect = font_small.render("상점 물품 (구매)", TEXT_WHITE)
            screen.blit(title_surf, (right_x + 10, right_y + 8))

        # 상점 아이콘 그리드 시작 위치
        shop_grid_x = right_x + 12
        shop_grid_y = right_y + 35

        grid_height_shop = panel_h - 60
        visible_rows_shop = max(1, (grid_height_shop + cell_gap) // (cell_size + cell_gap))
        total_rows_shop = max(1, math.ceil(len(self.shop_inventory) / cols))
        self._shop_shop_visible_rows = visible_rows_shop
        self._shop_shop_max_scroll = max(0, total_rows_shop - visible_rows_shop)
        self.shop_shop_scroll = max(0, min(self.shop_shop_scroll, self._shop_shop_max_scroll))
        start_idx_shop = self.shop_shop_scroll * cols

        # 상점 아이템 그리드 그리기 (스크롤 적용)
        for vis_row in range(visible_rows_shop):
            for col in range(cols):
                idx = start_idx_shop + vis_row * cols + col
                cell_rect = pygame.Rect(
                    shop_grid_x + col * (cell_size + cell_gap),
                    shop_grid_y + vis_row * (cell_size + cell_gap),
                    cell_size,
                    cell_size
                )
                if idx < len(self.shop_inventory):
                    self.shop_item_rects["shop"][idx] = cell_rect
                is_legendary = False
                if idx < len(self.shop_inventory):
                    item = self.shop_inventory[idx]
                    is_legendary = item.get("type") == "legendary"
                # 셀 배경
                if is_legendary:
                    pygame.draw.rect(screen, (60, 50, 80), cell_rect, border_radius=8)
                else:
                    pygame.draw.rect(screen, CELL_BG, cell_rect, border_radius=8)

                if idx >= len(self.shop_inventory):
                    pygame.draw.rect(screen, (50, 60, 80), cell_rect, 1, border_radius=8)
                    continue

                item = self.shop_inventory[idx]

                # 호버 체크
                is_hover = cell_rect.collidepoint(mouse_pos)
                if is_hover:
                    self.shop_hover_item = ("shop", idx, item, cell_rect)
                    pygame.draw.rect(screen, CELL_HOVER, cell_rect, 2, border_radius=8)
                elif is_legendary:
                    pygame.draw.rect(screen, BORDER_GOLD, cell_rect, 2, border_radius=8)
                else:
                    pygame.draw.rect(screen, CELL_BORDER, cell_rect, 1, border_radius=8)

                # 아이콘 그리기
                item_name = item.get("name", "")
                icon = None
                if get_item_icon:
                    icon = get_item_icon(item_name)

                if icon:
                    scaled_icon = pygame.transform.scale(icon, (cell_size - 8, cell_size - 8))
                    screen.blit(scaled_icon, (cell_rect.x + 4, cell_rect.y + 4))

        # 구매 안내 텍스트
        if font_small:
            hint_surf, _ = font_small.render("우클릭으로 구매", (200, 180, 120))
            screen.blit(hint_surf, (right_x + 10, right_y + panel_h - 25))

        # === 하단: 조작 안내 ===
        if font_small:
            hint_text = "ESC: 닫기"
            hint_surf, hint_rect = font_small.render(hint_text, TEXT_GRAY)
            screen.blit(hint_surf, (ui_x + total_w // 2 - hint_rect.width // 2, ui_y + total_h - 25))

        # === 스크롤바 표시 ===
        def _draw_scrollbar(x, y, h, total_rows, visible_rows, current_scroll, color):
            if total_rows <= visible_rows:
                return
            track_rect = pygame.Rect(x, y, 8, h)
            pygame.draw.rect(screen, (40, 50, 70), track_rect, border_radius=3)
            thumb_h = max(18, int(h * (visible_rows / total_rows)))
            scrollable = total_rows - visible_rows
            thumb_y = track_rect.y if scrollable == 0 else track_rect.y + int((current_scroll / scrollable) * (h - thumb_h))
            thumb_rect = pygame.Rect(track_rect.x, thumb_y, track_rect.width, thumb_h)
            pygame.draw.rect(screen, color, thumb_rect, border_radius=3)

        _draw_scrollbar(
            left_x + panel_w - 12,
            grid_y,
            grid_height,
            total_rows,
            visible_rows,
            self.shop_player_scroll,
            (140, 200, 255)
        )
        _draw_scrollbar(
            right_x + panel_w - 12,
            shop_grid_y,
            grid_height_shop,
            total_rows_shop,
            visible_rows_shop,
            self.shop_shop_scroll,
            (255, 215, 120)
        )

        # === 툴팁 표시 (맨 위에) ===
        if self.shop_hover_item:
            self._draw_shop_tooltip(screen, mouse_pos, get_item_description)

        # === 장착 아이템 판매 확인 다이얼로그 ===
        if self.shop_confirm_dialog:
            self._draw_shop_confirm_dialog(screen)

    def _draw_shop_tooltip(self, screen, mouse_pos, get_item_description=None):
        """상점 아이템 툴팁 그리기 - 캐릭터 정보창 스타일(폰트/배치 동일) + 가격"""
        if not self.shop_hover_item or len(self.shop_hover_item) < 4:
            return

        source, idx, item, cell_rect = self.shop_hover_item
        item_name = item.get("name", "")
        is_legendary = item.get("type") == "legendary"

        # pingfighter 함수들 가져오기
        try:
            import pingfighter
            format_item_display_name = getattr(pingfighter, 'format_item_display_name', None)
            get_item_quality_color = getattr(pingfighter, 'get_item_quality_color', None)
            get_item_slot_label = getattr(pingfighter, 'get_item_slot_label', None)
            get_item_description_func = getattr(pingfighter, 'get_item_description', None)
            ensure_passive_rolls = getattr(pingfighter, 'ensure_passive_rolls', None)
            assign_item_prefix = getattr(pingfighter, 'assign_item_prefix', None)
            wrap_text = getattr(pingfighter, 'wrap_text', None)
            clean_description = getattr(pingfighter, 'clean_description', None)
            strip_name_prefix = getattr(pingfighter, 'strip_name_prefix', None)
            is_name_line = getattr(pingfighter, 'is_name_line', None)
            get_item_name_korean = getattr(pingfighter, 'get_item_name_korean', None)
        except Exception:
            format_item_display_name = None
            get_item_quality_color = None
            get_item_slot_label = None
            get_item_description_func = get_item_description
            ensure_passive_rolls = None
            assign_item_prefix = None
            wrap_text = None
            clean_description = None
            strip_name_prefix = None
            is_name_line = None
            get_item_name_korean = None

        # 롤옵션/수식어 보정: 저장 데이터에 없던 수식어 누락을 방지
        if not is_legendary and ensure_passive_rolls:
            if not item.get("rolled_options"):
                item["type"] = item.get("type") or "passive"
                ensure_passive_rolls(item)
        if not is_legendary and assign_item_prefix:
            if item.get("rolled_options") and (not item.get("name_prefix") or not item.get("quality_tier")):
                assign_item_prefix(item, force=True)
        # 일부 저장본에서 name_prefix가 빠진 경우 quality_tier 기반으로 복원
        if not item.get("name_prefix") and item.get("quality_tier"):
            try:
                from pingfighter import QUALITY_PREFIXES  # type: ignore
                cand = QUALITY_PREFIXES.get(item.get("quality_tier") or "", [])
                if cand:
                    item["name_prefix"] = cand[0]
            except Exception:
                pass

        # 아이템 이름 (수식어 포함)
        if format_item_display_name:
            display_name = format_item_display_name(item)
        else:
            # 핑파이터 모듈이 없을 때도 수식어가 보이도록 폴백 (None 억제)
            prefix = item.get("name_prefix") or ""
            base_name = self._get_item_korean_name(item_name)
            display_name = f"{prefix} {base_name}".strip()

        # 품질 색상
        if get_item_quality_color:
            name_color = get_item_quality_color(item)
        else:
            name_color = None
        if not name_color:
            name_color = (255, 215, 0) if is_legendary else (240, 240, 240)

        # 슬롯 라벨
        if get_item_slot_label:
            slot_label = get_item_slot_label(item_name)
        else:
            slot_label = self._get_item_slot_label(item_name)

        # 가격
        if source == "player":
            base_price = self._get_item_base_price(item_name)
            # 품질 + 롤옵션 수치 보너스 계산 (실제 판매가와 동일하게)
            quality_roll_bonus = self._get_quality_and_roll_bonus(item, base_price)
            price = int((base_price + quality_roll_bonus) * 0.3)
        else:
            price = item.get("price", 0)
        price_text = f"{price:,}G"

        # 설명
        description = ""
        if get_item_description_func:
            description = get_item_description_func(item_name)
        elif get_item_description:
            description = get_item_description(item_name)
        description = description or ""
        # 설명에 이름이 다시 붙어있는 경우 제거 (예: "배터리: 게이지 유지...")
        base_name_local = self._get_item_korean_name(item_name)
        for nm in (display_name, base_name_local, item_name):
            if not nm:
                continue
            lowered = nm.lower()
            desc_lower = description.lower()
            if desc_lower.startswith(lowered + ":"):
                description = description[len(nm) + 1 :].lstrip()
                break
            if desc_lower.startswith(lowered + " :"):
                description = description[len(nm) + 2 :].lstrip()
                break

        if clean_description and description:
            try:
                base_name = get_item_name_korean(item_name) if get_item_name_korean else item_name
                description = clean_description(description, display_name, base_name, item_name)
            except Exception:
                pass

        # 롤 옵션
        rolled_options = item.get("rolled_options") or []
        option_entries = []
        for opt in rolled_options:
            opt_text = opt.get("text", "") if isinstance(opt, dict) else str(opt)
            if not opt_text:
                continue
            option_entries.append({
                "text": opt_text,
                "color": opt.get("color", (200, 210, 230)) if isinstance(opt, dict) else (200, 210, 230)
            })

        # 폰트
        font_small = self.fonts.get('small')
        font_tiny = self.fonts.get('tiny') or font_small
        if not font_small or not font_tiny:
            return

        # 색상 정의 (캐릭터 정보창과 동일)
        BG_LEFT = (16, 20, 34, 235)
        BG_RIGHT = (18, 22, 40, 235)
        BORDER_COLOR = (120, 180, 255)
        TEXT_DESC = (200, 210, 230)
        SLOT_COLOR = (255, 220, 160)
        PRICE_COLOR = (255, 215, 120)

        def _font_height(f):
            return f.get_sized_height() if hasattr(f, "get_sized_height") else f.get_height()

        line_height = _font_height(font_tiny) + 2
        wrap_width = 240

        def _measure_width(text: str) -> int:
            """글자 폭을 freetype/font 모두 호환되게 측정."""
            try:
                rect = font_tiny.get_rect(text)
                return rect.width if hasattr(rect, "width") else rect[2]
            except Exception:
                pass
            try:
                return font_tiny.size(text)[0]  # pygame.font.Font 용
            except Exception:
                return 0

        def _calc_width(entries):
            widths = []
            for entry in entries:
                text = entry.get("text", "")
                if text:
                    widths.append(_measure_width(text))
            return max(widths) if widths else 0

        def _wrap_text_local(text: str, max_width: int) -> list[str]:
            lines = []
            for paragraph in text.split("\n"):
                words = paragraph.split()
                current = ""
                for word in words:
                    trial = word if not current else current + " " + word
                    if _measure_width(trial) <= max_width:
                        current = trial
                        continue
                    if current:
                        lines.append(current)
                        current = ""
                    # 단일 단어가 한 줄을 초과하면 글자 단위로 쪼갠다
                    chunk = ""
                    for ch in word:
                        trial2 = chunk + ch
                        if _measure_width(trial2) <= max_width:
                            chunk = trial2
                        else:
                            if chunk:
                                lines.append(chunk)
                            chunk = ch
                    current = chunk
                if current:
                    lines.append(current)
            return lines

        def _wrap_entries(entries, max_width):
            wrapped = []
            for entry in entries:
                text = entry.get("text", "")
                color = entry.get("color", TEXT_DESC)
                if not text:
                    continue
                lines = _wrap_text_local(text, max_width)
                for ln in lines:
                    wrapped.append({"text": ln, "color": color})
            return wrapped

        # 표면 준비
        name_surf, name_rect = font_small.render(display_name, name_color)
        slot_surf = None
        slot_rect = None
        if slot_label:
            slot_surf, slot_rect = font_small.render(slot_label, SLOT_COLOR)

        desc_entries = []
        if description:
            # 이름 중복 제거
            if strip_name_prefix:
                try:
                    base_name = get_item_name_korean(item_name) if get_item_name_korean else item_name
                    description = strip_name_prefix(description, display_name, base_name, item_name)
                except Exception:
                    pass
            desc_entries.append({"text": description.strip(), "color": TEXT_DESC})

        name_height = name_rect.height
        slot_height = slot_rect.height if slot_rect else 0
        name_slot_width = name_rect.width + (slot_rect.width + 14 if slot_rect else 0)
        content_width = max(_calc_width(desc_entries), name_slot_width)
        desc_width = min(240, max(180, min(content_width + 20, wrap_width + 20)))
        slot_below = slot_surf and (name_rect.width + slot_rect.width + 24 > desc_width - 12)
        top_row_height = name_height if slot_below else max(name_height, slot_height)
        desc_wrapped = _wrap_entries(desc_entries, desc_width - 20)
        extra_slot = slot_height + 4 if slot_below else 0
        desc_height = 20 + top_row_height + extra_slot + 8 + len(desc_wrapped) * line_height

        coin_size = 16
        price_width = _measure_width(price_text) + coin_size + 6
        roll_content_w = max(_calc_width(option_entries), price_width)
        roll_width = min(260, max(180, roll_content_w + 20))
        roll_wrapped = _wrap_entries(option_entries, roll_width - 20)
        roll_height = 16 + len(roll_wrapped) * line_height
        if roll_wrapped:
            roll_height += 4
        roll_height += line_height  # 가격 줄

        gap = 12
        total_w = desc_width + gap + roll_width
        total_h = max(desc_height, roll_height)

        tooltip_x = max(8, min(SCREEN_WIDTH - total_w - 8, cell_rect.x + 10))
        tooltip_y = cell_rect.top - total_h - 12
        if tooltip_y < 8:
            tooltip_y = cell_rect.bottom + 12
        if tooltip_y + total_h + 4 > SCREEN_HEIGHT:
            tooltip_y = max(8, SCREEN_HEIGHT - total_h - 4)

        desc_rect = pygame.Rect(tooltip_x, tooltip_y, desc_width, desc_height)
        roll_rect = pygame.Rect(tooltip_x + desc_width + gap, tooltip_y, roll_width, roll_height)

        # 좌측 박스
        left_surf = pygame.Surface((desc_width, desc_height), pygame.SRCALPHA)
        pygame.draw.rect(left_surf, BG_LEFT, (0, 0, desc_width, desc_height), border_radius=8)
        screen.blit(left_surf, desc_rect.topleft)
        pygame.draw.rect(screen, BORDER_COLOR, desc_rect, 2, border_radius=8)

        name_y = desc_rect.y + 10 + (top_row_height - name_rect.height) // 2
        screen.blit(name_surf, (desc_rect.x + 10, name_y))
        if slot_surf:
            if slot_below:
                slot_y = name_y + name_height + 2
                slot_x = desc_rect.x + 10
            else:
                slot_y = desc_rect.y + 10 + (top_row_height - slot_rect.height) // 2
                slot_x = desc_rect.right - slot_rect.width - 10
            screen.blit(slot_surf, (slot_x, slot_y))

        desc_text_y = desc_rect.y + 10 + top_row_height + extra_slot + 6
        for entry in desc_wrapped:
            line_surf, _ = font_tiny.render(entry.get("text", ""), entry.get("color", TEXT_DESC))
            screen.blit(line_surf, (desc_rect.x + 10, desc_text_y))
            desc_text_y += line_height

        # 우측 박스 (옵션 + 가격)
        right_surf = pygame.Surface((roll_width, roll_height), pygame.SRCALPHA)
        pygame.draw.rect(right_surf, BG_RIGHT, (0, 0, roll_width, roll_height), border_radius=8)
        screen.blit(right_surf, roll_rect.topleft)
        pygame.draw.rect(screen, BORDER_COLOR, roll_rect, 2, border_radius=8)

        roll_text_y = roll_rect.y + 10
        for entry in roll_wrapped:
            opt_surf, _ = font_tiny.render(entry.get("text", ""), entry.get("color", TEXT_DESC))
            screen.blit(opt_surf, (roll_rect.x + 10, roll_text_y))
            roll_text_y += line_height
        if roll_wrapped:
            roll_text_y += 4

        coin_y = roll_text_y + (line_height - coin_size) // 2
        self._draw_gold_coin_icon(screen, roll_rect.x + 10, coin_y, coin_size)
        price_surf, _ = font_tiny.render(price_text, PRICE_COLOR)
        screen.blit(price_surf, (roll_rect.x + 10 + coin_size + 6, roll_text_y))

    def _draw_gold_coin_icon(self, screen, x, y, size):
        """금화 아이콘 그리기"""
        # 동전 배경 (금색)
        pygame.draw.circle(screen, (255, 200, 50), (x + size // 2, y + size // 2), size // 2)
        # 동전 테두리 (어두운 금색)
        pygame.draw.circle(screen, (180, 140, 30), (x + size // 2, y + size // 2), size // 2, 2)
        # 동전 하이라이트
        pygame.draw.circle(screen, (255, 230, 120), (x + size // 2 - 2, y + size // 2 - 2), size // 4)
        # G 문자
        font_tiny = self.fonts.get('tiny')
        if font_tiny and size >= 14:
            g_surf, g_rect = font_tiny.render("G", (120, 80, 20))
            screen.blit(g_surf, (x + size // 2 - g_rect.width // 2, y + size // 2 - g_rect.height // 2))

    def _get_item_slot_label(self, item_name):
        """아이템 슬롯 라벨 반환 (pingfighter 연동 안될 때 폴백)"""
        slot_map = {
            "speedboots": "신발",
            "spikeboots": "신발",
            "hermes_shoes": "신발",
            "speedgear": "장신구",
            "battery": "장신구",
            "revival": "장신구",
            "master": "장신구",
            "cooltime": "장신구",
            "chargebag": "가방",
            "dashgear": "장신구",
            "bulkup": "상의",
            "sensor": "장신구",
            "gravitybelt": "허리",
            "dashholder": "허리",
            "dowsing_pendulum": "장신구",
            "smartphone": "장신구",
            "commando_arm": "팔",
            "technical_vest": "상의",
            "fuel_pouch": "가방",
            "slot_add": "가방",
            "bluetooth_ring": "장신구",
            "star_detector": "장신구",
            "foul_whistle": "장신구",
            "bulletproof_hat": "머리",
            "spiked_helmet": "머리",
            "knee_pads": "무릎",
            "ragnarok_hammer": "전설",
            "poseidon_trident": "전설",
            "angel_blessing": "전설",
            "sacred_laurel": "전설",
        }
        return slot_map.get(item_name, "패시브")

    def _get_item_korean_name(self, item_name):
        """아이템 영문명을 한글명으로 변환"""
        name_map = {
            "speedboots": "스피드부츠",
            "speedgear": "스피드기어",
            "battery": "배터리",
            "revival": "부활",
            "master": "장인",
            "cooltime": "쿨타임",
            "chargebag": "충전가방",
            "spikeboots": "스파이크부츠",
            "dashgear": "대쉬기어",
            "bulkup": "벌크업",
            "sensor": "감지센서",
            "gravitybelt": "무중력벨트",
            "dashholder": "대쉬홀더",
            "dowsing_pendulum": "다우징팬들럼",
            "smartphone": "스마트폰",
            "commando_arm": "코만도암",
            "technical_vest": "테크니컬조끼",
            "fuel_pouch": "연료파우치",
            "slot_add": "슬롯추가",
            "ragnarok_hammer": "라그나로크 해머",
            "hermes_shoes": "헤르메스의 신발",
            "poseidon_trident": "포세이돈의 삼지창",
            "angel_blessing": "천사의 가호",
            "sacred_laurel": "신성 월계수",
            "foul_whistle": "반칙호루라기",
            "spiked_helmet": "가시투구",
            "star_detector": "별탐지기",
            "knee_pads": "킥차져",
            "bluetooth_ring": "블루투스링",
            "bulletproof_hat": "방탄모자",
        }
        return name_map.get(item_name, item_name)

    def _get_item_base_price(self, item_name):
        """아이템 기본 가격 반환 (상점 판매가와 동기화)"""
        price_map = {
            # 패시브 아이템
            "speedboots": 900,
            "speedgear": 800,
            "battery": 1000,
            "revival": 3000,
            "master": 900,
            "cooltime": 700,
            "chargebag": 1500,
            "spikeboots": 1100,
            "dashgear": 1000,
            "bulkup": 800,
            "sensor": 1800,
            "gravitybelt": 2500,
            "dashholder": 1200,
            "dowsing_pendulum": 700,
            "smartphone": 800,
            "commando_arm": 1100,
            "technical_vest": 1000,
            "fuel_pouch": 700,
            "slot_add": 900,
            # 전설 아이템
            "ragnarok_hammer": 6500,
            "hermes_shoes": 5500,
            "poseidon_trident": 5500,
            "angel_blessing": 6000,
            "sacred_laurel": 5800,
            # 기타 아이템
            "foul_whistle": 2000,
            "spiked_helmet": 1100,
            "star_detector": 1400,
            "knee_pads": 900,
            "bluetooth_ring": 1200,
            "bulletproof_hat": 1000,
        }
        return price_map.get(item_name, 500)

    def _calculate_roll_option_bonus(self, item):
        """롤옵션 세부 수치에 따른 가격 보너스 계산 (0.0 ~ 1.0)"""
        try:
            import pingfighter
            PASSIVE_OPTION_RANGES = getattr(pingfighter, 'PASSIVE_OPTION_RANGES', {})
        except Exception:
            return 0.0

        rolled_options = item.get("rolled_options") or []
        if not rolled_options:
            return 0.0

        item_name = item.get("name", "")
        ranges = PASSIVE_OPTION_RANGES.get(item_name, [])
        if not ranges:
            return 0.0

        # 각 옵션의 퍼센타일 평균 계산
        percentiles = []
        for opt in rolled_options:
            key = opt.get("key")
            value = opt.get("value")
            if key is None or value is None:
                continue

            # 해당 옵션의 범위 찾기
            for range_def in ranges:
                if range_def.get("key") == key:
                    v_min = range_def.get("min", 0)
                    v_max = range_def.get("max", 100)
                    reverse = range_def.get("reverse", False)

                    if v_max == v_min:
                        pct = 1.0
                    else:
                        pct = (value - v_min) / (v_max - v_min)
                        if reverse:
                            pct = 1.0 - pct

                    percentiles.append(pct)
                    break

        if not percentiles:
            return 0.0

        # 평균 퍼센타일 반환 (0.0 ~ 1.0)
        return sum(percentiles) / len(percentiles)

    def _get_quality_and_roll_bonus(self, item, base_price):
        """품질과 롤옵션 수치에 따른 가격 보너스 계산"""
        quality_tier = item.get("quality_tier", "low")

        # 품질 등급별 기본 배수 (low=1.0 기준)
        quality_multipliers = {
            "top": 1.8,    # 1.8배 ~ 2.3배
            "high": 1.5,   # 1.5배 ~ 1.8배
            "mid": 1.2,    # 1.2배 ~ 1.5배
            "low": 1.0,    # 1.0배
        }

        # 품질 등급별 롤옵션 추가 배수 범위 (최대치)
        roll_bonus_ranges = {
            "top": 0.5,    # 롤옵션 퍼센타일에 따라 +0% ~ +50%
            "high": 0.3,   # 롤옵션 퍼센타일에 따라 +0% ~ +30%
            "mid": 0.3,    # 롤옵션 퍼센타일에 따라 +0% ~ +30%
            "low": 0.0,    # low 등급은 롤옵션 보너스 없음
        }

        base_mult = quality_multipliers.get(quality_tier, 1.0)
        roll_range = roll_bonus_ranges.get(quality_tier, 0.0)

        # 롤옵션 퍼센타일 (0.0 ~ 1.0)
        roll_pct = self._calculate_roll_option_bonus(item)

        # 최종 배수 = 기본 배수 + (롤옵션 범위 * 롤옵션 퍼센타일)
        final_mult = base_mult + (roll_range * roll_pct)

        # 가격 보너스 = (최종 배수 - 1) * 기본가
        return int(base_price * (final_mult - 1))

    def _draw_shop_confirm_dialog(self, screen):
        """장착 아이템 판매 확인 다이얼로그"""
        dialog_rect, yes_rect, no_rect = self._get_shop_confirm_rects()

        # 배경 흐림
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 140))
        screen.blit(overlay, (0, 0))

        # 다이얼로그
        pygame.draw.rect(screen, (26, 32, 52), dialog_rect, border_radius=10)
        pygame.draw.rect(screen, (120, 180, 255), dialog_rect, 2, border_radius=10)

        font_small = self.fonts.get('small')
        font_tiny = self.fonts.get('tiny') or font_small
        if font_small:
            title = "현재 착용중인 아이템입니다"
            title_surf, title_rect = font_small.render(title, (255, 230, 180))
            screen.blit(title_surf, (dialog_rect.x + (dialog_rect.width - title_rect.width) // 2, dialog_rect.y + 18))
        if font_tiny:
            msg = "판매하시겠습니까?"
            msg_surf, msg_rect = font_tiny.render(msg, (210, 215, 230))
            screen.blit(msg_surf, (dialog_rect.x + (dialog_rect.width - msg_rect.width) // 2, dialog_rect.y + 54))

        # 버튼
        def _draw_btn(rect, text, base_fill, base_border, hover_fill, hover_border):
            is_hover = rect.collidepoint(pygame.mouse.get_pos())
            fill = hover_fill if is_hover else base_fill
            border = hover_border if is_hover else base_border
            pygame.draw.rect(screen, fill, rect, border_radius=6)
            pygame.draw.rect(screen, border, rect, 2, border_radius=6)
            if font_tiny:
                txt_surf, txt_rect = font_tiny.render(text, (15, 18, 26))
                # 버튼 중앙에 텍스트 정렬 (y축 약간 위로 조정)
                txt_x = rect.x + (rect.width - txt_rect.width) // 2
                txt_y = rect.y + (rect.height - txt_rect.height) // 2 - 3
                screen.blit(txt_surf, (txt_x, txt_y))

        _draw_btn(yes_rect, "예",
                  (120, 200, 140), (80, 160, 110),
                  (140, 220, 160), (90, 170, 120))
        _draw_btn(no_rect, "아니오",
                  (200, 140, 120), (160, 110, 90),
                  (220, 160, 140), (180, 130, 110))

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

    def _draw_crane_confirm_dialog(self, screen):
        """크레인 게임 확인 다이얼로그 그리기"""
        import math

        # 대화창 크기 및 위치
        dialog_w, dialog_h = 320, 180
        dialog_x = (SCREEN_WIDTH - dialog_w) // 2
        dialog_y = (SCREEN_HEIGHT - dialog_h) // 2

        # 색상 정의 (네온 아케이드 테마)
        BG_DARK = (25, 15, 45)
        BORDER_YELLOW = (255, 220, 100)
        BORDER_GLOW = (180, 150, 60)
        TEXT_WHITE = (240, 245, 255)
        TEXT_GOLD = (255, 215, 100)
        TEXT_YELLOW = (255, 255, 150)
        BUTTON_BG = (50, 40, 70)
        BUTTON_SELECTED = (100, 80, 130)
        BUTTON_BORDER = (255, 220, 100)

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
        pygame.draw.rect(screen, BORDER_YELLOW, (dialog_x, dialog_y, dialog_w, dialog_h), 2, border_radius=8)

        # 크레인 아이콘 (간단한 픽셀 아트)
        crane_x = dialog_x + 20
        crane_y = dialog_y + 20
        # 크레인 집게 그리기
        pygame.draw.rect(screen, (255, 200, 50), (crane_x + 10, crane_y, 4, 30))  # 줄
        pygame.draw.polygon(screen, (255, 200, 50), [
            (crane_x, crane_y + 30), (crane_x + 12, crane_y + 40),
            (crane_x + 24, crane_y + 30), (crane_x + 12, crane_y + 25)
        ])  # 집게

        # 제목 텍스트
        title_text = "🎮 인형뽑기 게임"
        cost_text = f"비용: {self.crane_game_cost} 골드"
        current_gold = self.player_data.get('gold', 0)
        gold_text = f"보유 골드: {current_gold}"

        # 폰트
        font_medium = self.fonts.get('medium')
        font_small = self.fonts.get('small')

        # 제목 렌더링
        if font_medium:
            # 이모지 제거하고 텍스트만
            title_surf, title_rect = font_medium.render("인형뽑기 게임", TEXT_WHITE)
            screen.blit(title_surf, (dialog_x + 60, dialog_y + 25))

        # 비용 및 골드 정보
        if font_small:
            cost_surf, cost_rect = font_small.render(cost_text, TEXT_GOLD)
            screen.blit(cost_surf, (dialog_x + dialog_w // 2 - cost_rect.width // 2, dialog_y + 60))

            # 골드가 부족하면 빨간색으로 표시
            gold_color = TEXT_YELLOW if current_gold >= self.crane_game_cost else (255, 100, 100)
            gold_surf, gold_rect = font_small.render(gold_text, gold_color)
            screen.blit(gold_surf, (dialog_x + dialog_w // 2 - gold_rect.width // 2, dialog_y + 85))

            # 질문
            question_text = "플레이 하시겠습니까?"
            q_surf, q_rect = font_small.render(question_text, TEXT_WHITE)
            screen.blit(q_surf, (dialog_x + dialog_w // 2 - q_rect.width // 2, dialog_y + 110))

        # 버튼 영역
        btn_w, btn_h = 80, 32
        btn_y = dialog_y + dialog_h - 50
        yes_btn_x = dialog_x + dialog_w // 2 - btn_w - 20
        no_btn_x = dialog_x + dialog_w // 2 + 20

        yes_btn = pygame.Rect(yes_btn_x, btn_y, btn_w, btn_h)
        no_btn = pygame.Rect(no_btn_x, btn_y, btn_w, btn_h)

        # 예 버튼
        yes_hover = yes_btn.collidepoint(mouse_pos)
        yes_selected = self.crane_confirm_selection == 0
        yes_bg = BUTTON_SELECTED if (yes_selected or yes_hover) else BUTTON_BG
        pygame.draw.rect(screen, yes_bg, yes_btn, border_radius=5)
        pygame.draw.rect(screen, BUTTON_BORDER if yes_selected else BORDER_GLOW, yes_btn, 2, border_radius=5)
        if font_medium:
            yes_color = TEXT_WHITE if yes_selected else TEXT_YELLOW
            yes_surf, yes_rect = font_medium.render("예", yes_color)
            screen.blit(yes_surf, (yes_btn.centerx - yes_rect.width // 2, yes_btn.centery - yes_rect.height // 2))

        # 아니오 버튼
        no_hover = no_btn.collidepoint(mouse_pos)
        no_selected = self.crane_confirm_selection == 1
        no_bg = BUTTON_SELECTED if (no_selected or no_hover) else BUTTON_BG
        pygame.draw.rect(screen, no_bg, no_btn, border_radius=5)
        pygame.draw.rect(screen, BUTTON_BORDER if no_selected else BORDER_GLOW, no_btn, 2, border_radius=5)
        if font_medium:
            no_color = TEXT_WHITE if no_selected else TEXT_YELLOW
            no_surf, no_rect = font_medium.render("아니오", no_color)
            screen.blit(no_surf, (no_btn.centerx - no_rect.width // 2, no_btn.centery - no_rect.height // 2))

        # 선택 힌트
        if font_small:
            hint_text = "← → 선택  |  Enter 확인  |  ESC 닫기"
            hint_surf, hint_rect = font_small.render(hint_text, (150, 150, 180))
            screen.blit(hint_surf, (dialog_x + dialog_w // 2 - hint_rect.width // 2, dialog_y + dialog_h - 18))

    def _draw_crane_game_screen(self, screen):
        """크레인 게임 플레이 화면 그리기 - 고퀄리티 실제 크레인 게임 스타일"""
        import math

        # 게임 화면 크기 (확대)
        game_w, game_h = 520, 420
        game_x = (SCREEN_WIDTH - game_w) // 2
        game_y = (SCREEN_HEIGHT - game_h) // 2 - 10

        # === 고급 색상 팔레트 ===
        # 머신 프레임 색상 (메탈릭 레드/골드)
        FRAME_RED = (180, 40, 50)
        FRAME_RED_LIGHT = (220, 70, 80)
        FRAME_RED_DARK = (120, 25, 35)
        FRAME_GOLD = (255, 200, 80)
        FRAME_GOLD_DARK = (200, 150, 50)

        # 내부 조명 색상
        INNER_BG_TOP = (20, 35, 60)
        INNER_BG_BOTTOM = (10, 20, 40)
        NEON_PINK = (255, 100, 180)
        NEON_BLUE = (80, 200, 255)
        NEON_PURPLE = (180, 100, 255)

        # 크레인 색상 (메탈릭)
        CRANE_CHROME = (220, 225, 235)
        CRANE_CHROME_LIGHT = (245, 248, 255)
        CRANE_CHROME_DARK = (160, 165, 180)
        CRANE_STEEL = (100, 105, 120)

        # LED 색상
        LED_GREEN = (50, 255, 100)
        LED_RED = (255, 60, 60)
        LED_YELLOW = (255, 230, 50)

        # === 배경 암전 + 스포트라이트 효과 ===
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 220))
        screen.blit(overlay, (0, 0))

        # 스포트라이트 효과 (중앙에 빛)
        spotlight = pygame.Surface((game_w + 100, game_h + 150), pygame.SRCALPHA)
        for i in range(50, 0, -1):
            alpha = int(3 * (50 - i))
            pygame.draw.ellipse(spotlight, (255, 250, 240, alpha),
                               (50 - i, 75 - i * 1.5, game_w + i * 2, game_h + i * 3))
        screen.blit(spotlight, (game_x - 50, game_y - 75))

        # === 크레인 머신 외형 (3D 효과) ===
        frame_x = game_x - 30
        frame_y = game_y - 60
        frame_w = game_w + 60
        frame_h = game_h + 130

        # 머신 그림자 (깊이감)
        shadow_surf = pygame.Surface((frame_w + 20, frame_h + 20), pygame.SRCALPHA)
        pygame.draw.rect(shadow_surf, (0, 0, 0, 100), (10, 10, frame_w, frame_h), border_radius=15)
        screen.blit(shadow_surf, (frame_x, frame_y))

        # 머신 본체 (그라데이션 효과)
        machine_surf = pygame.Surface((frame_w, frame_h), pygame.SRCALPHA)
        for i in range(frame_h):
            ratio = i / frame_h
            r = int(FRAME_RED[0] * (1 - ratio * 0.3))
            g = int(FRAME_RED[1] * (1 - ratio * 0.3))
            b = int(FRAME_RED[2] * (1 - ratio * 0.3))
            pygame.draw.line(machine_surf, (r, g, b), (0, i), (frame_w, i))

        # 둥근 모서리 마스크 적용
        mask_surf = pygame.Surface((frame_w, frame_h), pygame.SRCALPHA)
        pygame.draw.rect(mask_surf, (255, 255, 255, 255), (0, 0, frame_w, frame_h), border_radius=15)
        machine_surf.blit(mask_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
        screen.blit(machine_surf, (frame_x, frame_y))

        # 프레임 하이라이트 (왼쪽 상단 빛)
        highlight_surf = pygame.Surface((frame_w, frame_h), pygame.SRCALPHA)
        pygame.draw.rect(highlight_surf, (255, 255, 255, 40), (0, 0, frame_w // 3, frame_h), border_radius=15)
        screen.blit(highlight_surf, (frame_x, frame_y))

        # 메탈릭 테두리 (3중 레이어)
        pygame.draw.rect(screen, FRAME_RED_DARK, (frame_x, frame_y, frame_w, frame_h), 6, border_radius=15)
        pygame.draw.rect(screen, FRAME_GOLD, (frame_x + 3, frame_y + 3, frame_w - 6, frame_h - 6), 3, border_radius=12)
        pygame.draw.rect(screen, FRAME_RED_LIGHT, (frame_x + 6, frame_y + 6, frame_w - 12, frame_h - 12), 2, border_radius=10)

        # === 상단 장식 (아케이드 스타일) ===
        top_decor_y = frame_y + 5
        # 중앙 금색 장식 패널
        decor_w = 200
        decor_x = frame_x + (frame_w - decor_w) // 2
        pygame.draw.rect(screen, FRAME_GOLD, (decor_x, top_decor_y, decor_w, 25), border_radius=5)
        pygame.draw.rect(screen, FRAME_GOLD_DARK, (decor_x, top_decor_y, decor_w, 25), 2, border_radius=5)

        # "CRANE GAME" 네온 텍스트 효과
        font_medium = self.fonts.get('medium')
        if font_medium:
            # 글로우 효과
            glow_intensity = int(200 + 55 * math.sin(self.animation_timer * 4))
            for offset in range(3, 0, -1):
                glow_surf, _ = font_medium.render("CRANE GAME", (255, 100, 150, glow_intensity // (offset + 1)))
                screen.blit(glow_surf, (decor_x + 28 - offset, top_decor_y + 4 - offset))
            title_surf, _ = font_medium.render("CRANE GAME", (255, 255, 255))
            screen.blit(title_surf, (decor_x + 28, top_decor_y + 4))

        # 상단 LED 라이트 (깜빡이는 효과)
        led_colors = [LED_RED, LED_YELLOW, LED_GREEN, LED_YELLOW, LED_RED]
        for i, color in enumerate(led_colors):
            led_x = frame_x + 40 + i * 30
            blink = math.sin(self.animation_timer * 6 + i * 0.8) > 0
            led_color = color if blink else (color[0] // 3, color[1] // 3, color[2] // 3)
            # LED 글로우
            glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
            if blink:
                pygame.draw.circle(glow_surf, (*color, 80), (10, 10), 10)
            pygame.draw.circle(glow_surf, led_color, (10, 10), 5)
            screen.blit(glow_surf, (led_x - 10, top_decor_y + 30))

        # 오른쪽 LED도
        for i, color in enumerate(led_colors):
            led_x = frame_x + frame_w - 40 - i * 30
            blink = math.sin(self.animation_timer * 6 + i * 0.8 + 3.14) > 0
            led_color = color if blink else (color[0] // 3, color[1] // 3, color[2] // 3)
            glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
            if blink:
                pygame.draw.circle(glow_surf, (*color, 80), (10, 10), 10)
            pygame.draw.circle(glow_surf, led_color, (10, 10), 5)
            screen.blit(glow_surf, (led_x - 10, top_decor_y + 30))

        # === 유리창 영역 (내부 조명 효과) ===
        glass_x = game_x
        glass_y = game_y
        glass_rect = pygame.Rect(glass_x, glass_y, game_w, game_h)

        # 내부 배경 (그라데이션)
        inner_surf = pygame.Surface((game_w, game_h))
        for y in range(game_h):
            ratio = y / game_h
            r = int(INNER_BG_TOP[0] * (1 - ratio) + INNER_BG_BOTTOM[0] * ratio)
            g = int(INNER_BG_TOP[1] * (1 - ratio) + INNER_BG_BOTTOM[1] * ratio)
            b = int(INNER_BG_TOP[2] * (1 - ratio) + INNER_BG_BOTTOM[2] * ratio)
            pygame.draw.line(inner_surf, (r, g, b), (0, y), (game_w, y))
        screen.blit(inner_surf, (glass_x, glass_y))

        # 네온 조명 바 (상단, 측면)
        neon_pulse = int(180 + 75 * math.sin(self.animation_timer * 3))
        # 상단 네온
        neon_bar = pygame.Surface((game_w - 20, 4), pygame.SRCALPHA)
        pygame.draw.rect(neon_bar, (*NEON_PINK[:3], neon_pulse), (0, 0, game_w - 20, 4))
        screen.blit(neon_bar, (glass_x + 10, glass_y + 8))
        # 하단 네온
        pygame.draw.rect(neon_bar, (*NEON_BLUE[:3], neon_pulse), (0, 0, game_w - 20, 4))
        screen.blit(neon_bar, (glass_x + 10, glass_y + game_h - 12))

        # 바닥 펠트 (녹색 계열, 진짜 크레인 게임처럼)
        floor_y = glass_y + int(game_h * 0.55)
        floor_h = game_h - int(game_h * 0.55)
        floor_surf = pygame.Surface((game_w, floor_h), pygame.SRCALPHA)
        for y in range(floor_h):
            green_val = int(60 + (y / floor_h) * 30)
            pygame.draw.line(floor_surf, (30, green_val, 50), (0, y), (game_w, y))
        screen.blit(floor_surf, (glass_x, floor_y))

        # 바닥 질감 (점선 패턴)
        for i in range(0, game_w, 20):
            for j in range(0, floor_h, 20):
                if (i + j) % 40 == 0:
                    pygame.draw.circle(screen, (40, 90, 60, 50), (glass_x + i + 10, floor_y + j + 10), 2)

        # === 캡슐들 그리기 (고퀄리티) ===
        for prize in self.crane_prizes:
            if prize["grabbed"]:
                continue

            px = glass_x + int(prize["x"] * game_w)
            py = glass_y + int(prize["y"] * game_h)
            wobble = math.sin(prize["wobble"]) * 2
            capsule_color = prize.get("capsule_color", (150, 200, 255))

            # 캡슐 크기 증가
            cap_w, cap_h = 28, 36

            # 그림자 (부드러운)
            shadow_surf = pygame.Surface((cap_w + 10, cap_h + 10), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_surf, (0, 0, 0, 60), (5, 8, cap_w, cap_h - 4))
            screen.blit(shadow_surf, (px - cap_w // 2 - 3, py - cap_h // 2 + int(wobble)))

            # 캡슐 하단부 (진한색)
            bottom_color = (capsule_color[0] * 7 // 10, capsule_color[1] * 7 // 10, capsule_color[2] * 7 // 10)
            pygame.draw.ellipse(screen, bottom_color,
                               (px - cap_w // 2, py + int(wobble), cap_w, cap_h // 2))

            # 캡슐 상단부 (투명 느낌)
            top_color = (min(255, capsule_color[0] + 30), min(255, capsule_color[1] + 30), min(255, capsule_color[2] + 30))
            pygame.draw.ellipse(screen, top_color,
                               (px - cap_w // 2, py - cap_h // 2 + int(wobble), cap_w, cap_h // 2 + 8))

            # 캡슐 중간 분리선
            pygame.draw.line(screen, (255, 255, 255, 150),
                            (px - cap_w // 2 + 3, py + int(wobble)),
                            (px + cap_w // 2 - 3, py + int(wobble)), 2)

            # 상단 하이라이트 (반사광)
            highlight_surf = pygame.Surface((cap_w, cap_h), pygame.SRCALPHA)
            pygame.draw.ellipse(highlight_surf, (255, 255, 255, 120),
                               (cap_w // 4, 4, cap_w // 3, cap_h // 5))
            screen.blit(highlight_surf, (px - cap_w // 2, py - cap_h // 2 + int(wobble)))

            # 캡슐 테두리
            pygame.draw.ellipse(screen, (capsule_color[0] // 2, capsule_color[1] // 2, capsule_color[2] // 2),
                               (px - cap_w // 2, py - cap_h // 2 + int(wobble), cap_w, cap_h), 2)

            # 아이템 아이콘
            item_name = prize.get("item", {}).get("name", "")
            if item_name:
                try:
                    import sys
                    if 'pingfighter' in sys.modules:
                        pingfighter = sys.modules['pingfighter']
                        if hasattr(pingfighter, 'get_item_icon'):
                            item_icon = pingfighter.get_item_icon(item_name)
                            if item_icon:
                                icon_size = 22
                                scaled_icon = pygame.transform.scale(item_icon, (icon_size, icon_size))
                                screen.blit(scaled_icon, (px - icon_size // 2, py - icon_size // 2 + int(wobble)))
                except Exception:
                    pygame.draw.circle(screen, (255, 255, 255), (px, py + int(wobble)), 8)

            # 레어리티 효과 (더 화려하게)
            item_rarity = prize.get("item", {}).get("rarity", "common")
            if item_rarity == "rare":
                glow_alpha = int(100 + 80 * math.sin(self.animation_timer * 5))
                glow_surf = pygame.Surface((cap_w * 2, cap_h * 2), pygame.SRCALPHA)
                pygame.draw.ellipse(glow_surf, (255, 215, 0, glow_alpha),
                                   (cap_w // 2, cap_h // 2, cap_w, cap_h))
                screen.blit(glow_surf, (px - cap_w, py - cap_h + int(wobble)))
            elif item_rarity == "epic":
                glow_alpha = int(120 + 80 * math.sin(self.animation_timer * 7))
                glow_surf = pygame.Surface((cap_w * 2, cap_h * 2), pygame.SRCALPHA)
                pygame.draw.ellipse(glow_surf, (180, 80, 255, glow_alpha),
                                   (cap_w // 2, cap_h // 2, cap_w, cap_h))
                screen.blit(glow_surf, (px - cap_w, py - cap_h + int(wobble)))
                # 파티클 효과
                for i in range(4):
                    p_angle = self.animation_timer * 3 + i * 1.57
                    p_x = px + int(math.cos(p_angle) * 20)
                    p_y = py + int(math.sin(p_angle) * 15) + int(wobble)
                    p_alpha = int(200 + 55 * math.sin(self.animation_timer * 10 + i))
                    pygame.draw.circle(screen, (200, 150, 255, p_alpha), (p_x, p_y), 3)
            elif item_rarity == "legendary":
                # 전설: 무지개 오라 + 별 반짝임
                for ring in range(3):
                    ring_alpha = int(80 + 60 * math.sin(self.animation_timer * 8 + ring))
                    hue_shift = (self.animation_timer * 50 + ring * 30) % 360
                    # 무지개 색상
                    r = int(255 * (1 + math.sin(math.radians(hue_shift))) / 2)
                    g = int(255 * (1 + math.sin(math.radians(hue_shift + 120))) / 2)
                    b = int(255 * (1 + math.sin(math.radians(hue_shift + 240))) / 2)
                    glow_surf = pygame.Surface((cap_w * 3, cap_h * 3), pygame.SRCALPHA)
                    pygame.draw.ellipse(glow_surf, (r, g, b, ring_alpha),
                                       (cap_w // 2 + ring * 5, cap_h // 2 + ring * 5,
                                        cap_w * 2 - ring * 10, cap_h * 2 - ring * 10))
                    screen.blit(glow_surf, (px - cap_w * 1.5, py - cap_h * 1.5 + int(wobble)))
                # 별 효과
                for i in range(5):
                    star_angle = self.animation_timer * 2 + i * 1.26
                    star_dist = 25 + 5 * math.sin(self.animation_timer * 5 + i)
                    star_x = px + int(math.cos(star_angle) * star_dist)
                    star_y = py + int(math.sin(star_angle) * star_dist * 0.7) + int(wobble)
                    star_size = int(3 + 2 * math.sin(self.animation_timer * 12 + i * 2))
                    # 별 그리기 (4방향)
                    pygame.draw.line(screen, (255, 255, 200), (star_x - star_size, star_y), (star_x + star_size, star_y), 2)
                    pygame.draw.line(screen, (255, 255, 200), (star_x, star_y - star_size), (star_x, star_y + star_size), 2)

        # === 크레인 그리기 (고퀄리티 메탈릭) ===
        crane_px = glass_x + int(self.crane_x * game_w)
        crane_py = glass_y + int(self.crane_y * game_h * 0.85)

        # 크레인 레일 (3D 효과)
        rail_y = glass_y + 20
        rail_h = 12
        # 레일 그림자
        pygame.draw.rect(screen, (30, 30, 40), (glass_x + 15, rail_y + 3, game_w - 30, rail_h))
        # 레일 본체 (그라데이션)
        rail_surf = pygame.Surface((game_w - 30, rail_h), pygame.SRCALPHA)
        for y in range(rail_h):
            brightness = int(150 + 50 * (1 - abs(y - rail_h // 2) / (rail_h // 2)))
            pygame.draw.line(rail_surf, (brightness, brightness, brightness + 20), (0, y), (game_w - 30, y))
        screen.blit(rail_surf, (glass_x + 15, rail_y))
        pygame.draw.rect(screen, CRANE_STEEL, (glass_x + 15, rail_y, game_w - 30, rail_h), 2)

        # 레일 볼트
        for i in range(5):
            bolt_x = glass_x + 30 + i * (game_w - 60) // 4
            pygame.draw.circle(screen, (80, 80, 90), (bolt_x, rail_y + rail_h // 2), 4)
            pygame.draw.circle(screen, (120, 120, 130), (bolt_x, rail_y + rail_h // 2), 3)

        # 크레인 캐리지 (본체)
        carriage_w, carriage_h = 50, 35
        carriage_x = crane_px - carriage_w // 2
        carriage_y = rail_y - 8

        # 캐리지 그림자
        pygame.draw.rect(screen, (40, 40, 50), (carriage_x + 3, carriage_y + 3, carriage_w, carriage_h), border_radius=5)

        # 캐리지 본체 (메탈릭 그라데이션)
        carriage_surf = pygame.Surface((carriage_w, carriage_h), pygame.SRCALPHA)
        for y in range(carriage_h):
            ratio = y / carriage_h
            brightness = int(CRANE_CHROME[0] * (1 - ratio * 0.4))
            pygame.draw.line(carriage_surf, (brightness, brightness, brightness + 15), (0, y), (carriage_w, y))
        pygame.draw.rect(carriage_surf, (0, 0, 0, 0), (0, 0, carriage_w, carriage_h), border_radius=5)
        screen.blit(carriage_surf, (carriage_x, carriage_y))
        pygame.draw.rect(screen, CRANE_STEEL, (carriage_x, carriage_y, carriage_w, carriage_h), 2, border_radius=5)

        # 캐리지 장식
        pygame.draw.rect(screen, CRANE_CHROME_LIGHT, (carriage_x + 5, carriage_y + 5, carriage_w - 10, 4), border_radius=2)

        # 모터 표시등
        motor_blink = math.sin(self.animation_timer * 8) > 0 if self.crane_state != "idle" else False
        motor_color = LED_GREEN if motor_blink else (50, 80, 50)
        pygame.draw.circle(screen, motor_color, (carriage_x + carriage_w - 10, carriage_y + 10), 4)

        # 크레인 줄 (체인 효과)
        rope_start_y = carriage_y + carriage_h
        rope_length = crane_py - rope_start_y
        if rope_length > 0:
            chain_segments = int(rope_length / 8)
            for i in range(chain_segments):
                seg_y = rope_start_y + i * 8
                seg_width = 3 if i % 2 == 0 else 5
                seg_color = CRANE_CHROME if i % 2 == 0 else CRANE_CHROME_DARK
                pygame.draw.line(screen, seg_color, (crane_px - 1, seg_y), (crane_px - 1, seg_y + 8), seg_width)

        # 크레인 집게 본체 (메탈릭 박스)
        claw_box_w, claw_box_h = 30, 18
        claw_box_x = crane_px - claw_box_w // 2
        claw_box_y = crane_py - 5

        # 집게 박스 그림자
        pygame.draw.rect(screen, (40, 40, 50), (claw_box_x + 2, claw_box_y + 2, claw_box_w, claw_box_h), border_radius=3)

        # 집게 박스 본체
        claw_surf = pygame.Surface((claw_box_w, claw_box_h), pygame.SRCALPHA)
        for y in range(claw_box_h):
            brightness = int(200 + 40 * (1 - y / claw_box_h))
            pygame.draw.line(claw_surf, (brightness, brightness, brightness + 10), (0, y), (claw_box_w, y))
        screen.blit(claw_surf, (claw_box_x, claw_box_y))
        pygame.draw.rect(screen, CRANE_STEEL, (claw_box_x, claw_box_y, claw_box_w, claw_box_h), 2, border_radius=3)

        # 집게 (3발, 곡선형)
        # 집게 벌림 정도 계산 (상태에 따라)
        if self.crane_state in ["idle", "dropping"]:
            claw_open = 18
        elif self.crane_state == "releasing":
            # releasing 상태에서는 점점 벌어짐
            claw_open = 6 + int(self.crane_claw_open * 20)
        elif self.crane_state == "item_falling":
            claw_open = 26  # 완전히 벌린 상태
        else:
            claw_open = 6
        claw_length = 30
        claw_base_y = claw_box_y + claw_box_h

        # 집게 발 (두꺼운 메탈)
        for offset in [-1, 0, 1]:
            claw_end_x = crane_px + offset * claw_open
            # 집게 몸체 (그라데이션 효과)
            claw_points = [
                (crane_px + offset * 5, claw_base_y),
                (claw_end_x - 4, claw_base_y + claw_length),
                (claw_end_x + 4, claw_base_y + claw_length),
                (crane_px + offset * 5, claw_base_y)
            ]
            pygame.draw.polygon(screen, CRANE_CHROME, claw_points)
            pygame.draw.polygon(screen, CRANE_STEEL, claw_points, 2)

            # 집게 끝 (고무 패드)
            pygame.draw.ellipse(screen, (60, 60, 70),
                               (claw_end_x - 5, claw_base_y + claw_length - 3, 10, 8))
            pygame.draw.ellipse(screen, (40, 40, 50),
                               (claw_end_x - 5, claw_base_y + claw_length - 3, 10, 8), 1)

        # 잡은 캡슐 (집게에 매달린 상태)
        if self.crane_grabbed_prize and self.crane_state in ["rising", "returning", "releasing"]:
            prize = self.crane_grabbed_prize
            capsule_color = prize.get("capsule_color", (150, 200, 255))
            grab_y = claw_base_y + claw_length + 10

            # releasing 상태에서 캡슐이 점점 아래로 떨어지기 시작
            if self.crane_state == "releasing":
                grab_y += int(self.crane_claw_open * 30)  # 집게가 벌어질수록 아래로

            cap_w, cap_h = 26, 34

            # 캡슐 그리기 (위와 동일한 스타일)
            bottom_color = (capsule_color[0] * 7 // 10, capsule_color[1] * 7 // 10, capsule_color[2] * 7 // 10)
            pygame.draw.ellipse(screen, bottom_color,
                               (crane_px - cap_w // 2, grab_y, cap_w, cap_h // 2))
            top_color = (min(255, capsule_color[0] + 30), min(255, capsule_color[1] + 30), min(255, capsule_color[2] + 30))
            pygame.draw.ellipse(screen, top_color,
                               (crane_px - cap_w // 2, grab_y - cap_h // 2, cap_w, cap_h // 2 + 8))
            pygame.draw.line(screen, (255, 255, 255, 150),
                            (crane_px - cap_w // 2 + 3, grab_y),
                            (crane_px + cap_w // 2 - 3, grab_y), 2)
            pygame.draw.ellipse(screen, (capsule_color[0] // 2, capsule_color[1] // 2, capsule_color[2] // 2),
                               (crane_px - cap_w // 2, grab_y - cap_h // 2, cap_w, cap_h), 2)

            # 아이콘
            item_name = prize.get("item", {}).get("name", "")
            if item_name:
                try:
                    import sys
                    if 'pingfighter' in sys.modules:
                        pingfighter = sys.modules['pingfighter']
                        if hasattr(pingfighter, 'get_item_icon'):
                            item_icon = pingfighter.get_item_icon(item_name)
                            if item_icon:
                                icon_size = 20
                                scaled_icon = pygame.transform.scale(item_icon, (icon_size, icon_size))
                                screen.blit(scaled_icon, (crane_px - icon_size // 2, grab_y - icon_size // 2))
                except Exception:
                    pygame.draw.circle(screen, (255, 255, 255), (crane_px, grab_y), 7)

        # === 유리 효과 (반사, 틴트) ===
        glass_overlay = pygame.Surface((game_w, game_h), pygame.SRCALPHA)
        # 대각선 반사광
        for i in range(3):
            pygame.draw.line(glass_overlay, (255, 255, 255, 25 - i * 8),
                            (-50 + i * 80, 0), (game_w - 100 + i * 80, game_h), 40 - i * 10)
        # 상단 밝은 부분
        pygame.draw.rect(glass_overlay, (255, 255, 255, 15), (0, 0, game_w, 60))
        screen.blit(glass_overlay, (glass_x, glass_y))

        # 유리창 프레임 (두꺼운 메탈)
        pygame.draw.rect(screen, (60, 50, 45), glass_rect, 6)
        pygame.draw.rect(screen, (100, 85, 70), glass_rect, 3)
        pygame.draw.rect(screen, (40, 35, 30), glass_rect, 1)

        # === 배출구 (유리창 내부 왼쪽 하단) ===
        # 크레인이 x=0.05 (5%) 위치까지 이동하므로 배출구도 그 위치에 맞춤
        chute_x = glass_x + int(game_w * 0.05) - 20  # 크레인 위치에 맞춤
        chute_y = glass_y + game_h - 60
        chute_w, chute_h = 40, 80

        # 배출구 프레임
        pygame.draw.rect(screen, (50, 45, 40), (chute_x, chute_y, chute_w, chute_h), border_radius=5)
        # 배출구 내부 (어두운 구멍)
        pygame.draw.rect(screen, (20, 20, 25), (chute_x + 5, chute_y + 5, chute_w - 10, chute_h - 30), border_radius=3)
        # 고무 플랩
        pygame.draw.rect(screen, (30, 30, 35), (chute_x + 8, chute_y + chute_h - 25, chute_w - 16, 20), border_radius=2)
        pygame.draw.rect(screen, FRAME_GOLD_DARK, (chute_x, chute_y, chute_w, chute_h), 2, border_radius=5)

        # === 배출구에서 떨어지는 캡슐 (item_falling 상태) ===
        if self.crane_state == "item_falling" and self.crane_grabbed_prize:
            prize = self.crane_grabbed_prize
            capsule_color = prize.get("capsule_color", (150, 200, 255))

            # 배출구 위쪽에서 시작해서 아래로 떨어짐
            drop_start_y = chute_y + 15  # 배출구 내부 상단
            drop_end_y = chute_y + chute_h + 20  # 배출구 아래 바닥
            # crane_drop_y는 0.0 ~ 1.0 범위
            drop_y = drop_start_y + int(min(self.crane_drop_y, 1.0) * (drop_end_y - drop_start_y))
            drop_x = chute_x + chute_w // 2

            cap_w, cap_h = 24, 32

            # 캡슐 그리기
            bottom_color = (capsule_color[0] * 7 // 10, capsule_color[1] * 7 // 10, capsule_color[2] * 7 // 10)
            pygame.draw.ellipse(screen, bottom_color,
                               (drop_x - cap_w // 2, drop_y, cap_w, cap_h // 2))
            top_color = (min(255, capsule_color[0] + 30), min(255, capsule_color[1] + 30), min(255, capsule_color[2] + 30))
            pygame.draw.ellipse(screen, top_color,
                               (drop_x - cap_w // 2, drop_y - cap_h // 2, cap_w, cap_h // 2 + 8))
            # 캡슐 중앙 라인
            pygame.draw.line(screen, (255, 255, 255, 180),
                            (drop_x - cap_w // 2 + 3, drop_y),
                            (drop_x + cap_w // 2 - 3, drop_y), 2)
            # 캡슐 외곽선
            pygame.draw.ellipse(screen, (capsule_color[0] // 2, capsule_color[1] // 2, capsule_color[2] // 2),
                               (drop_x - cap_w // 2, drop_y - cap_h // 2, cap_w, cap_h), 2)

            # 아이콘
            item_name = prize.get("item", {}).get("name", "")
            if item_name:
                try:
                    import sys
                    if 'pingfighter' in sys.modules:
                        pingfighter = sys.modules['pingfighter']
                        if hasattr(pingfighter, 'get_item_icon'):
                            item_icon = pingfighter.get_item_icon(item_name)
                            if item_icon:
                                icon_size = 18
                                scaled_icon = pygame.transform.scale(item_icon, (icon_size, icon_size))
                                screen.blit(scaled_icon, (drop_x - icon_size // 2, drop_y - icon_size // 2))
                except Exception:
                    pygame.draw.circle(screen, (255, 255, 255), (drop_x, drop_y), 6)

            # 튕김 효과 파티클 (바닥에 닿을 때)
            if self.crane_drop_bounce > 0 and abs(self.crane_drop_y - 1.0) < 0.05:
                for i in range(3):
                    particle_x = drop_x + random.randint(-10, 10)
                    particle_y = drop_end_y + random.randint(-3, 3)
                    pygame.draw.circle(screen, (255, 255, 200), (particle_x, particle_y), 2)

        # === 조이스틱 & 버튼 영역 (하단) ===
        control_y = frame_y + frame_h - 50
        control_panel = pygame.Rect(frame_x + 20, control_y, frame_w - 40, 40)
        pygame.draw.rect(screen, (50, 45, 40), control_panel, border_radius=5)
        pygame.draw.rect(screen, FRAME_GOLD_DARK, control_panel, 2, border_radius=5)

        # 조이스틱 (왼쪽)
        joy_x = frame_x + 80
        joy_y = control_y + 20
        pygame.draw.circle(screen, (30, 30, 35), (joy_x, joy_y), 15)
        pygame.draw.circle(screen, (60, 60, 70), (joy_x, joy_y), 12)
        pygame.draw.circle(screen, (80, 80, 90), (joy_x, joy_y - 2), 10)
        # 조이스틱 하이라이트
        pygame.draw.circle(screen, (120, 120, 130), (joy_x - 3, joy_y - 5), 4)

        # 버튼 (오른쪽)
        btn_x = frame_x + frame_w - 80
        btn_pressed = self.crane_state != "idle"
        btn_y_offset = 3 if btn_pressed else 0
        # 버튼 그림자
        pygame.draw.ellipse(screen, (20, 20, 25), (btn_x - 18, joy_y - 12, 36, 28))
        # 버튼 본체
        btn_color = (200, 60, 60) if not btn_pressed else (150, 40, 40)
        pygame.draw.ellipse(screen, btn_color, (btn_x - 15, joy_y - 10 + btn_y_offset, 30, 22))
        pygame.draw.ellipse(screen, (255, 100, 100), (btn_x - 12, joy_y - 8 + btn_y_offset, 24, 14))
        pygame.draw.ellipse(screen, (180, 50, 50), (btn_x - 15, joy_y - 10 + btn_y_offset, 30, 22), 2)

        # === UI 패널 (하단 정보) ===
        ui_panel_y = frame_y + frame_h + 10
        ui_panel = pygame.Rect(game_x - 20, ui_panel_y, game_w + 40, 45)
        pygame.draw.rect(screen, (30, 28, 35), ui_panel, border_radius=8)
        pygame.draw.rect(screen, FRAME_GOLD, ui_panel, 2, border_radius=8)

        font_small = self.fonts.get('small')
        if font_small:
            # 골드 표시
            gold_text = f"💰 {self.player_data.get('gold', 0):,}"
            gold_surf, gold_rect = font_small.render(gold_text, (255, 215, 100))
            screen.blit(gold_surf, (game_x, ui_panel_y + 14))

            # 조작 힌트
            if self.crane_state == "idle":
                hint_text = "SPACE - 크레인 내리기  |  ESC - 나가기"
            elif self.crane_state == "result":
                hint_text = "SPACE - 계속  |  ESC - 나가기"
            else:
                hint_text = "▶ 크레인 작동 중..."

            hint_surf, hint_rect = font_small.render(hint_text, (180, 180, 190))
            screen.blit(hint_surf, (game_x + game_w - hint_rect.width, ui_panel_y + 14))

        # === 타이머 표시 (상단 오른쪽) ===
        if self.crane_state == "idle" and hasattr(self, 'crane_time_remaining'):
            time_remaining = max(0, self.crane_time_remaining)
            time_int = int(time_remaining)

            # 타이머 배경
            timer_w, timer_h = 80, 40
            timer_x = frame_x + frame_w - timer_w - 15
            timer_y = frame_y + 35
            timer_rect = pygame.Rect(timer_x, timer_y, timer_w, timer_h)

            # 시간에 따른 색상 변경
            if time_remaining <= 5:
                timer_bg = (100, 30, 30)  # 빨간 배경 (위험)
                timer_color = (255, 80, 80)  # 빨간색
                # 깜빡임 효과
                if int(time_remaining * 2) % 2 == 0:
                    timer_color = (255, 255, 255)
            elif time_remaining <= 10:
                timer_bg = (80, 60, 20)  # 노란 배경 (경고)
                timer_color = (255, 220, 80)  # 노란색
            else:
                timer_bg = (20, 50, 30)  # 녹색 배경 (안전)
                timer_color = (100, 255, 150)  # 녹색

            # 타이머 박스 그리기
            pygame.draw.rect(screen, timer_bg, timer_rect, border_radius=8)
            pygame.draw.rect(screen, FRAME_GOLD, timer_rect, 2, border_radius=8)

            # 타이머 숫자 표시
            if font_medium:
                timer_text = f"{time_int}"
                timer_surf, timer_text_rect = font_medium.render(timer_text, timer_color)
                screen.blit(timer_surf, (timer_x + timer_w // 2 - timer_text_rect.width // 2,
                                        timer_y + timer_h // 2 - timer_text_rect.height // 2))

        # === 결과 표시 (화려한 효과) ===
        if self.crane_state == "result" and self.crane_result:
            # 결과 오버레이
            result_surf = pygame.Surface((game_w, 120), pygame.SRCALPHA)
            result_surf.fill((0, 0, 0, 200))
            screen.blit(result_surf, (glass_x, glass_y + game_h // 2 - 60))

            if self.crane_result["success"]:
                prize = self.crane_result["prize"]
                item_info = prize.get("item", {})
                item_korean = item_info.get("korean", item_info.get("name", "아이템"))

                # 성공 텍스트 (글로우 효과)
                if font_medium:
                    result_text = f"🎉 {item_korean} 획득!"
                    for offset in range(3, 0, -1):
                        glow_surf, _ = font_medium.render(result_text, (100, 255, 100, 150 // offset))
                        screen.blit(glow_surf, (glass_x + game_w // 2 - glow_surf.get_width() // 2 - offset,
                                               glass_y + game_h // 2 + 15 - offset))
                    result_surf, _ = font_medium.render(result_text, (150, 255, 150))
                    screen.blit(result_surf, (glass_x + game_w // 2 - result_surf.get_width() // 2,
                                             glass_y + game_h // 2 + 15))

                # 아이템 아이콘 (크게)
                item_name = item_info.get("name", "")
                if item_name:
                    try:
                        import sys
                        if 'pingfighter' in sys.modules:
                            pingfighter = sys.modules['pingfighter']
                            if hasattr(pingfighter, 'get_item_icon'):
                                item_icon = pingfighter.get_item_icon(item_name)
                                if item_icon:
                                    icon_size = 48
                                    scaled_icon = pygame.transform.scale(item_icon, (icon_size, icon_size))
                                    # 아이콘 글로우
                                    glow_surf = pygame.Surface((icon_size + 20, icon_size + 20), pygame.SRCALPHA)
                                    pygame.draw.circle(glow_surf, (255, 255, 200, 80),
                                                      (icon_size // 2 + 10, icon_size // 2 + 10), icon_size // 2 + 8)
                                    screen.blit(glow_surf, (glass_x + game_w // 2 - icon_size // 2 - 10,
                                                          glass_y + game_h // 2 - 55))
                                    screen.blit(scaled_icon, (glass_x + game_w // 2 - icon_size // 2,
                                                             glass_y + game_h // 2 - 45))
                    except Exception:
                        pass
            else:
                if font_medium:
                    result_text = "😢 아쉽네요... 다시 도전!"
                    result_surf, _ = font_medium.render(result_text, (255, 150, 150))
                    screen.blit(result_surf, (glass_x + game_w // 2 - result_surf.get_width() // 2,
                                             glass_y + game_h // 2 - 5))

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

    def _draw_headmaster_interact_hint(self, screen):
        """아카데미 학장 근처일 때 상호작용 힌트 표시 (마우스 클릭 전용)"""
        if not self.nearby_headmaster:
            return

        # 대화창이 열려있으면 힌트 숨기기
        if self.academy_dialog_open:
            return

        # 화면 하단에 힌트 박스 표시
        hint_text = "CLICK - 학장과 대화"
        pulse = abs(math.sin(self.animation_timer * 4))

        # 색상 팔레트 (군사/골드 테마)
        ACCENT_GOLD = (255, 180, 80)
        ACCENT_BRONZE = (180, 120, 70)
        NAVY_BLUE = (30, 40, 70)

        # 힌트 박스 크기
        box_w = 220
        box_h = 40
        box_x = (SCREEN_WIDTH - box_w) // 2
        box_y = SCREEN_HEIGHT - 80

        # 글로우 효과 (골드)
        for glow in range(3, 0, -1):
            glow_alpha = int((60 - glow * 15) * pulse)
            glow_surf = pygame.Surface((box_w + glow * 6, box_h + glow * 6), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*ACCENT_GOLD, glow_alpha),
                           (0, 0, box_w + glow * 6, box_h + glow * 6), border_radius=8)
            screen.blit(glow_surf, (box_x - glow * 3, box_y - glow * 3))

        # 박스 배경 (네이비)
        box_surf = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
        pygame.draw.rect(box_surf, (*NAVY_BLUE, 230), (0, 0, box_w, box_h), border_radius=6)
        screen.blit(box_surf, (box_x, box_y))

        # 테두리 (골드)
        pygame.draw.rect(screen, ACCENT_GOLD, (box_x, box_y, box_w, box_h), 2, border_radius=6)

        # 텍스트
        if self.fonts:
            font = self.fonts.get("small") or self.fonts.get("main")
            if font:
                text_color = (255, 255, 255)
                text_surf, text_rect = font.render(hint_text, text_color)
                text_x = box_x + (box_w - text_rect.width) // 2 + 10
                text_y = box_y + (box_h - text_rect.height) // 2
                screen.blit(text_surf, (text_x, text_y))

        # 마우스 클릭 아이콘 (좌측)
        mouse_x = box_x + 20
        mouse_y = box_y + (box_h - 28) // 2
        # 마우스 본체
        pygame.draw.ellipse(screen, (60, 50, 80), (mouse_x, mouse_y, 22, 28))
        pygame.draw.ellipse(screen, ACCENT_GOLD, (mouse_x, mouse_y, 22, 28), 2)
        # 왼쪽 버튼 강조 (클릭 표시)
        click_alpha = int(200 + 55 * pulse)
        pygame.draw.rect(screen, ACCENT_GOLD, (mouse_x + 2, mouse_y + 2, 8, 10), border_radius=2)
        # 버튼 구분선
        pygame.draw.line(screen, (40, 30, 60), (mouse_x + 11, mouse_y + 2), (mouse_x + 11, mouse_y + 12), 1)

        # 별 마크 (우측 - 군사 느낌)
        star_x = box_x + box_w - 30
        star_y = box_y + box_h // 2
        # 5각 별 그리기
        star_points = []
        for i in range(5):
            # 외곽 점
            angle_outer = math.radians(-90 + i * 72)
            star_points.append((star_x + 10 * math.cos(angle_outer), star_y + 10 * math.sin(angle_outer)))
            # 내곽 점
            angle_inner = math.radians(-90 + i * 72 + 36)
            star_points.append((star_x + 4 * math.cos(angle_inner), star_y + 4 * math.sin(angle_inner)))
        pygame.draw.polygon(screen, ACCENT_GOLD, star_points)

    def _draw_npc_interact_hint(self, screen):
        """일반 NPC 근처일 때 상호작용 힌트 표시"""
        # 학장 힌트가 표시 중이면 스킵 (중복 방지)
        if self.building_type == BuildingType.ACADEMY and self.nearby_headmaster:
            return

        if not self.nearby_npc:
            return

        # 대화창/메뉴가 열려있으면 힌트 숨기기
        if self.academy_dialog_open or self.bank_menu_open or self.shop_trade_open:
            return

        # NPC 이름 가져오기
        npc_name = getattr(self.nearby_npc, 'name', '주민')
        hint_text = f"CLICK - {npc_name}과(와) 대화"

        # 애니메이션 펄스
        pulse = abs(math.sin(self.animation_timer * 4))

        # 색상 팔레트 (건물 타입별)
        if self.building_type == BuildingType.BANK:
            ACCENT_COLOR = (70, 180, 255)  # 시안 (은행)
            DARK_BG = (18, 25, 38)
        elif self.building_type == BuildingType.ITEM_SHOP:
            ACCENT_COLOR = (100, 255, 150)  # 그린 (상점)
            DARK_BG = (20, 35, 25)
        else:
            ACCENT_COLOR = (180, 100, 255)  # 퍼플 (기본)
            DARK_BG = (25, 20, 35)

        # 힌트 박스 크기
        box_w = 260
        box_h = 40
        box_x = (SCREEN_WIDTH - box_w) // 2
        box_y = SCREEN_HEIGHT - 80

        # 글로우 효과
        for glow in range(3, 0, -1):
            glow_alpha = int((60 - glow * 15) * pulse)
            glow_surf = pygame.Surface((box_w + glow * 6, box_h + glow * 6), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*ACCENT_COLOR, glow_alpha),
                           (0, 0, box_w + glow * 6, box_h + glow * 6), border_radius=8)
            screen.blit(glow_surf, (box_x - glow * 3, box_y - glow * 3))

        # 박스 배경
        box_surf = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
        pygame.draw.rect(box_surf, (*DARK_BG, 230), (0, 0, box_w, box_h), border_radius=6)
        screen.blit(box_surf, (box_x, box_y))

        # 테두리
        pygame.draw.rect(screen, ACCENT_COLOR, (box_x, box_y, box_w, box_h), 2, border_radius=6)

        # 텍스트
        if self.fonts:
            font = self.fonts.get("small") or self.fonts.get("main")
            if font:
                text_color = (255, 255, 255)
                text_surf, text_rect = font.render(hint_text, text_color)
                text_x = box_x + (box_w - text_rect.width) // 2 + 15
                text_y = box_y + (box_h - text_rect.height) // 2
                screen.blit(text_surf, (text_x, text_y))

        # 마우스 클릭 아이콘 (좌측)
        mouse_x = box_x + 20
        mouse_y = box_y + (box_h - 26) // 2
        # 마우스 본체
        pygame.draw.ellipse(screen, (50, 55, 70), (mouse_x, mouse_y, 20, 26))
        pygame.draw.ellipse(screen, ACCENT_COLOR, (mouse_x, mouse_y, 20, 26), 2)
        # 왼쪽 버튼 강조 (클릭 표시)
        pygame.draw.rect(screen, ACCENT_COLOR, (mouse_x + 2, mouse_y + 2, 7, 9), border_radius=2)
        # 버튼 구분선
        pygame.draw.line(screen, DARK_BG, (mouse_x + 10, mouse_y + 2), (mouse_x + 10, mouse_y + 11), 1)

    def _draw_academy_interior(self, screen):
        """아카데미 전용 인테리어 - 훈련소/전투 아카데미 스타일"""
        import math

        # 색상 팔레트 (금속/콘크리트 훈련소 테마)
        BG_DARK = (30, 30, 35)           # 어두운 금속 배경
        FLOOR_A = (50, 50, 55)           # 바닥 타일 A (콘크리트)
        FLOOR_B = (60, 60, 65)           # 바닥 타일 B
        WALL_COLOR = (40, 40, 45)        # 금속 벽
        ACCENT_GOLD = (255, 180, 80)     # 골드 엑센트
        ACCENT_GOLD_DIM = (180, 120, 50) # 어두운 골드
        METAL_LIGHT = (80, 85, 90)       # 밝은 금속
        METAL_DARK = (45, 48, 52)        # 어두운 금속
        WARNING_ORANGE = (255, 150, 50)  # 경고 주황
        WHITE = (240, 245, 250)
        GREEN_HEAL = (100, 255, 150)     # 힐링 캡슐 색상

        cam_x, cam_y = self.camera_offset
        cx = self.pixel_width // 2  # 중앙 X
        cy = self.pixel_height // 2  # 중앙 Y

        # 장애물 영역 설정 (플레이어/NPC 이동 불가)
        wall_h = int(TILE_SIZE * 3.5)

        # 장애물 영역 리스트 초기화
        self.academy_obstacle_rects = []

        # 1) 상단 벽 영역
        self.academy_obstacle_rects.append(pygame.Rect(0, 0, self.pixel_width, wall_h))

        # 2) 왼쪽 훈련 장비들 (타이어, 수류탄 상자) - 가장자리에서 떨어뜨림
        equip_y = wall_h + 40
        self.academy_obstacle_rects.append(pygame.Rect(40, equip_y, 80, 100))  # 타이어
        self.academy_obstacle_rects.append(pygame.Rect(140, equip_y + 20, 70, 80))  # 수류탄 상자

        # 3) 사격장 - 오른쪽 상단, 가장자리에서 떨어뜨림
        shoot_range_x = self.pixel_width - 180
        self.academy_obstacle_rects.append(pygame.Rect(shoot_range_x, equip_y, 140, 160))

        # 4) 탁구대들 (2개) - 분산 배치, 더 큰 크기
        table_w, table_h = 140, 85
        table_positions = [
            (100, wall_h + 180),  # 왼쪽 상단
            (self.pixel_width - 280, self.pixel_height - 200),  # 오른쪽 하단
        ]
        for tx, ty in table_positions:
            self.academy_obstacle_rects.append(pygame.Rect(tx, ty, table_w, table_h + 25))

        # 5) 힐링 캡슐 - 중앙 오른쪽, 가장자리에서 떨어뜨림
        capsule_x, capsule_y = self.pixel_width - 130, wall_h + 240
        self.academy_obstacle_rects.append(pygame.Rect(capsule_x, capsule_y, 80, 110))

        # 6) 도서관 책장들 (3개 가로 배치 - 학장 아르카나 왼쪽)
        shelf_w, shelf_h = 55, 90
        # 학장 위치 (약 x=512, y=138) 왼쪽에 배치
        headmaster_x = int(self.pixel_width * 0.5)  # 약 512
        shelf_start_x = headmaster_x - 250  # 학장보다 250픽셀 왼쪽
        shelf_y = wall_h + 60  # 벽 바로 아래 (학장과 비슷한 y 위치)
        for i in range(3):
            shelf_x = shelf_start_x + i * (shelf_w + 15)  # 가로로 간격 두고 배치
            self.academy_obstacle_rects.append(pygame.Rect(shelf_x, shelf_y, shelf_w, shelf_h))

        # 1. 배경
        screen.fill(BG_DARK)

        # 2. 바닥 타일 (콘크리트 격자)
        for ty in range(self.map_height):
            for tx in range(self.map_width):
                tile_x = tx * TILE_SIZE - cam_x
                tile_y = ty * TILE_SIZE - cam_y
                color = FLOOR_A if (tx + ty) % 2 == 0 else FLOOR_B
                pygame.draw.rect(screen, color, (tile_x, tile_y, TILE_SIZE, TILE_SIZE))
                # 콘크리트 금이 간 느낌
                if (tx + ty) % 5 == 0:
                    pygame.draw.line(screen, (40, 40, 45),
                                   (tile_x, tile_y),
                                   (tile_x + TILE_SIZE, tile_y + TILE_SIZE), 1)

        # 3. 창과방패 엠블럼 (중앙 바닥)
        self._draw_training_emblem(screen, cx - cam_x, cy - cam_y, self.animation_timer)

        # 4. 상단 벽 (금속 패널)
        wall_h = int(TILE_SIZE * 3.5)
        pygame.draw.rect(screen, WALL_COLOR, (-cam_x, -cam_y, self.pixel_width, wall_h))

        # 금속 리벳 라인
        for rx in range(0, self.pixel_width, 60):
            pygame.draw.circle(screen, METAL_LIGHT, (rx - cam_x, int(-cam_y + wall_h - 15)), 4)
        pygame.draw.rect(screen, ACCENT_GOLD_DIM, (-cam_x, -cam_y + wall_h - 4, self.pixel_width, 4))

        # 5. 훈련소 창문 (철창 스타일)
        self._draw_training_windows(screen, cam_x, cam_y, wall_h, self.animation_timer)

        # 6. 건물 이름 표시 (훈련소)
        sign_y = -cam_y + 15
        sign_x = cx - cam_x

        # 군사 스타일 로고 패널
        panel_w, panel_h = 160, 36
        pygame.draw.rect(screen, (35, 35, 40), (sign_x - panel_w//2, sign_y - 3, panel_w, panel_h), border_radius=3)
        pygame.draw.rect(screen, ACCENT_GOLD, (sign_x - panel_w//2, sign_y - 3, panel_w, panel_h), 2, border_radius=3)

        # 로고 글로우
        glow_intensity = int(40 + 25 * math.sin(self.animation_timer * 1.5))
        glow_surf = pygame.Surface((panel_w + 16, panel_h + 16), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*ACCENT_GOLD, glow_intensity), (0, 0, panel_w + 16, panel_h + 16), border_radius=6)
        screen.blit(glow_surf, (sign_x - panel_w//2 - 8, sign_y - 11))

        # 로고 텍스트
        font_large = self.fonts.get('large')
        if font_large:
            text_surf, text_rect = font_large.render("전투 아카데미", ACCENT_GOLD)
            screen.blit(text_surf, (sign_x - text_rect.width // 2, sign_y + 4))

        # 7. 왼쪽: 훈련 장비 (타이어, 수류탄 상자)
        self._draw_training_equipment(screen, cam_x, cam_y, wall_h)

        # 8. 오른쪽: 사격 연습장
        self._draw_shooting_range(screen, cam_x, cam_y, wall_h, self.animation_timer)

        # 9. 탁구대들 (분산 배치)
        self._draw_ping_pong_tables(screen, cam_x, cam_y)

        # 10. 힐링 캡슐 (부상자 치료) - 오른쪽 위치
        self._draw_healing_capsule(screen, cam_x, cam_y, self.animation_timer)

        # 11. 도서관 책장들 (전술 매뉴얼)
        self._draw_tactical_bookshelves(screen, cam_x, cam_y, wall_h)

        # 13. 문 그리기
        self._draw_door(screen)

    def _draw_training_emblem(self, screen, cx, cy, anim_timer):
        """창과방패 엠블럼 그리기 (바닥 중앙) - 고퀄리티 버전"""
        import math

        # 색상 팔레트 (더 풍부한 색상)
        GOLD_BRIGHT = (255, 215, 120)
        GOLD_MID = (255, 190, 80)
        GOLD_DIM = (180, 140, 60)
        GOLD_DARK = (120, 90, 40)
        SHIELD_BLUE = (70, 90, 120)
        SHIELD_BLUE_LIGHT = (100, 130, 170)
        SHIELD_BLUE_DARK = (40, 55, 80)
        SPEAR_WOOD = (120, 85, 50)
        SPEAR_WOOD_LIGHT = (160, 120, 75)
        SPEAR_WOOD_DARK = (80, 55, 35)
        SPEAR_METAL = (200, 210, 220)
        SPEAR_METAL_DARK = (140, 150, 165)
        RED_ACCENT = (180, 60, 60)
        WHITE = (240, 245, 250)

        # 엠블럼 크기
        outer_radius = 160
        inner_radius = 140
        shield_w = 100
        shield_h = 120

        # === 1. 배경 글로우 효과 (다중 레이어) ===
        glow_pulse = math.sin(anim_timer * 1.2)
        for layer in range(4):
            r = outer_radius + 40 - layer * 10
            alpha = int(15 + 8 * glow_pulse) - layer * 3
            if alpha > 0:
                glow_surf = pygame.Surface((r * 2, r * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*GOLD_DIM, alpha), (r, r), r)
                screen.blit(glow_surf, (int(cx - r), int(cy - r)))

        # === 2. 외곽 원형 장식 ===
        # 가장 바깥 원 (두꺼운 금색)
        pygame.draw.circle(screen, GOLD_DARK, (int(cx), int(cy)), outer_radius, 8)
        pygame.draw.circle(screen, GOLD_MID, (int(cx), int(cy)), outer_radius - 2, 4)

        # 내부 원 (장식선)
        pygame.draw.circle(screen, GOLD_DIM, (int(cx), int(cy)), inner_radius, 2)
        pygame.draw.circle(screen, GOLD_DIM, (int(cx), int(cy)), inner_radius - 8, 1)

        # 장식 점들 (외부 원 - 큰 점과 작은 점 번갈아)
        for i in range(24):
            angle = (i * math.pi / 12) + anim_timer * 0.1
            rx = cx + (outer_radius - 4) * math.cos(angle)
            ry = cy + (outer_radius - 4) * math.sin(angle)
            dot_size = 4 if i % 2 == 0 else 2
            pulse = dot_size + int(1 * math.sin(anim_timer * 2.5 + i * 0.3))
            pygame.draw.circle(screen, GOLD_BRIGHT, (int(rx), int(ry)), pulse)

        # 내부 장식선 (방사형)
        for i in range(8):
            angle = (i * math.pi / 4) + math.pi / 8
            inner_x = cx + (inner_radius - 10) * math.cos(angle)
            inner_y = cy + (inner_radius - 10) * math.sin(angle)
            outer_x = cx + (outer_radius - 12) * math.cos(angle)
            outer_y = cy + (outer_radius - 12) * math.sin(angle)
            pygame.draw.line(screen, GOLD_DIM, (int(inner_x), int(inner_y)),
                           (int(outer_x), int(outer_y)), 2)

        # === 3. 방패 (중앙 - 고디테일) ===
        # 방패 그림자
        shadow_offset = 4
        shield_points_shadow = [
            (cx + shadow_offset, cy - shield_h * 0.45 + shadow_offset),
            (cx + shield_w * 0.5 + shadow_offset, cy - shield_h * 0.3 + shadow_offset),
            (cx + shield_w * 0.5 + shadow_offset, cy + shield_h * 0.25 + shadow_offset),
            (cx + shadow_offset, cy + shield_h * 0.55 + shadow_offset),
            (cx - shield_w * 0.5 + shadow_offset, cy + shield_h * 0.25 + shadow_offset),
            (cx - shield_w * 0.5 + shadow_offset, cy - shield_h * 0.3 + shadow_offset),
        ]
        shadow_surf = pygame.Surface((shield_w + 20, shield_h + 20), pygame.SRCALPHA)
        pygame.draw.polygon(shadow_surf, (0, 0, 0, 40),
                          [(p[0] - cx + shield_w//2 + 10, p[1] - cy + shield_h//2 + 10) for p in shield_points_shadow])
        screen.blit(shadow_surf, (int(cx - shield_w//2 - 10), int(cy - shield_h//2 - 10)))

        # 방패 본체 (다각형)
        shield_points = [
            (cx, cy - shield_h * 0.45),              # 상단
            (cx + shield_w * 0.5, cy - shield_h * 0.3),  # 우상단
            (cx + shield_w * 0.5, cy + shield_h * 0.25), # 우하단
            (cx, cy + shield_h * 0.55),              # 하단 (뾰족)
            (cx - shield_w * 0.5, cy + shield_h * 0.25), # 좌하단
            (cx - shield_w * 0.5, cy - shield_h * 0.3),  # 좌상단
        ]

        # 방패 본체 (그라데이션 효과 - 왼쪽 밝게)
        pygame.draw.polygon(screen, SHIELD_BLUE, shield_points)

        # 방패 하이라이트 (왼쪽)
        highlight_points = [
            (cx - shield_w * 0.45, cy - shield_h * 0.28),
            (cx - shield_w * 0.15, cy - shield_h * 0.35),
            (cx - shield_w * 0.15, cy + shield_h * 0.15),
            (cx - shield_w * 0.45, cy + shield_h * 0.2),
        ]
        pygame.draw.polygon(screen, SHIELD_BLUE_LIGHT, highlight_points)

        # 방패 어두운 부분 (오른쪽)
        dark_points = [
            (cx + shield_w * 0.15, cy - shield_h * 0.35),
            (cx + shield_w * 0.45, cy - shield_h * 0.28),
            (cx + shield_w * 0.45, cy + shield_h * 0.2),
            (cx + shield_w * 0.15, cy + shield_h * 0.15),
        ]
        pygame.draw.polygon(screen, SHIELD_BLUE_DARK, dark_points)

        # 방패 테두리 (다중 선)
        pygame.draw.polygon(screen, GOLD_MID, shield_points, 4)
        pygame.draw.polygon(screen, GOLD_BRIGHT, shield_points, 2)

        # 방패 내부 장식 - 십자 (더 디테일)
        cross_w = 12
        # 세로 십자
        pygame.draw.rect(screen, GOLD_DIM, (cx - cross_w//2, cy - shield_h * 0.35,
                                            cross_w, shield_h * 0.75))
        pygame.draw.rect(screen, GOLD_MID, (cx - cross_w//2 + 2, cy - shield_h * 0.35 + 2,
                                           cross_w - 4, shield_h * 0.75 - 4))
        # 가로 십자
        pygame.draw.rect(screen, GOLD_DIM, (cx - shield_w * 0.35, cy - cross_w//2,
                                            shield_w * 0.7, cross_w))
        pygame.draw.rect(screen, GOLD_MID, (cx - shield_w * 0.35 + 2, cy - cross_w//2 + 2,
                                           shield_w * 0.7 - 4, cross_w - 4))

        # 방패 중앙 보석 (빨간색)
        gem_radius = 10
        pygame.draw.circle(screen, RED_ACCENT, (int(cx), int(cy)), gem_radius)
        pygame.draw.circle(screen, (220, 100, 100), (int(cx - 2), int(cy - 2)), gem_radius - 3)
        pygame.draw.circle(screen, GOLD_BRIGHT, (int(cx), int(cy)), gem_radius, 2)

        # 방패 모서리 리벳
        rivet_positions = [
            (cx, cy - shield_h * 0.38),
            (cx + shield_w * 0.4, cy - shield_h * 0.22),
            (cx + shield_w * 0.4, cy + shield_h * 0.15),
            (cx - shield_w * 0.4, cy + shield_h * 0.15),
            (cx - shield_w * 0.4, cy - shield_h * 0.22),
        ]
        for rx, ry in rivet_positions:
            pygame.draw.circle(screen, GOLD_DARK, (int(rx), int(ry)), 5)
            pygame.draw.circle(screen, GOLD_BRIGHT, (int(rx), int(ry)), 3)
            pygame.draw.circle(screen, GOLD_MID, (int(rx - 1), int(ry - 1)), 1)

        # === 4. 창 두 자루 (X자 교차 - 고디테일) ===
        spear_length = 200

        for spear_idx, base_angle in enumerate([math.pi * 0.72, math.pi * 0.28]):
            # 창 위치 계산
            sx1 = cx + spear_length * 0.55 * math.cos(base_angle)
            sy1 = cy + spear_length * 0.55 * math.sin(base_angle)
            sx2 = cx - spear_length * 0.55 * math.cos(base_angle)
            sy2 = cy - spear_length * 0.55 * math.sin(base_angle)

            # 창대 (나무 - 그라데이션)
            # 메인 창대
            pygame.draw.line(screen, SPEAR_WOOD_DARK, (int(sx1), int(sy1)),
                           (int(sx2), int(sy2)), 10)
            pygame.draw.line(screen, SPEAR_WOOD, (int(sx1), int(sy1)),
                           (int(sx2), int(sy2)), 7)
            pygame.draw.line(screen, SPEAR_WOOD_LIGHT, (int(sx1 + 1), int(sy1 + 1)),
                           (int(sx2 + 1), int(sy2 + 1)), 2)

            # 창대 장식 밴드 (금속)
            band_positions = [0.3, 0.5, 0.7]
            for bp in band_positions:
                bx = sx1 + (sx2 - sx1) * bp
                by = sy1 + (sy2 - sy1) * bp
                pygame.draw.circle(screen, GOLD_DIM, (int(bx), int(by)), 6)
                pygame.draw.circle(screen, GOLD_MID, (int(bx), int(by)), 4)

            # 창끝 (금속 - 더 디테일한 형태)
            tip_length = 35
            tip_angle = base_angle + math.pi

            # 창끝 본체
            tip_base_x = sx2 + 5 * math.cos(tip_angle)
            tip_base_y = sy2 + 5 * math.sin(tip_angle)
            tip_end_x = tip_base_x + tip_length * math.cos(tip_angle)
            tip_end_y = tip_base_y + tip_length * math.sin(tip_angle)

            # 창날 외곽 (다이아몬드 형태)
            perp_angle = tip_angle + math.pi / 2
            tip_width = 12
            blade_points = [
                (tip_end_x, tip_end_y),  # 끝점
                (tip_base_x + tip_width * 0.6 * math.cos(perp_angle),
                 tip_base_y + tip_width * 0.6 * math.sin(perp_angle)),
                (tip_base_x + tip_length * 0.3 * math.cos(tip_angle) + tip_width * math.cos(perp_angle),
                 tip_base_y + tip_length * 0.3 * math.sin(tip_angle) + tip_width * math.sin(perp_angle)),
                (tip_base_x + tip_length * 0.3 * math.cos(tip_angle),
                 tip_base_y + tip_length * 0.3 * math.sin(tip_angle)),
                (tip_base_x + tip_length * 0.3 * math.cos(tip_angle) - tip_width * math.cos(perp_angle),
                 tip_base_y + tip_length * 0.3 * math.sin(tip_angle) - tip_width * math.sin(perp_angle)),
                (tip_base_x - tip_width * 0.6 * math.cos(perp_angle),
                 tip_base_y - tip_width * 0.6 * math.sin(perp_angle)),
            ]
            pygame.draw.polygon(screen, SPEAR_METAL_DARK, blade_points)
            pygame.draw.polygon(screen, SPEAR_METAL, blade_points, 0)

            # 창날 중앙선 (하이라이트)
            pygame.draw.line(screen, WHITE, (int(tip_end_x), int(tip_end_y)),
                           (int(tip_base_x + tip_length * 0.3 * math.cos(tip_angle)),
                            int(tip_base_y + tip_length * 0.3 * math.sin(tip_angle))), 2)

            # 창날 테두리
            pygame.draw.polygon(screen, GOLD_DIM, blade_points, 2)

            # 창끝 기부 장식 (금속 밴드)
            pygame.draw.circle(screen, SPEAR_METAL_DARK, (int(sx2), int(sy2)), 8)
            pygame.draw.circle(screen, GOLD_MID, (int(sx2), int(sy2)), 6)

            # 창 반대쪽 끝 (뭉툭한 끝)
            pygame.draw.circle(screen, SPEAR_WOOD_DARK, (int(sx1), int(sy1)), 6)
            pygame.draw.circle(screen, GOLD_DIM, (int(sx1), int(sy1)), 4)

        # === 5. 하단 배너/리본 ===
        banner_y = cy + outer_radius - 10
        banner_w = 180
        banner_h = 28

        # 리본 본체
        ribbon_points = [
            (cx - banner_w//2 - 15, banner_y + 5),
            (cx - banner_w//2, banner_y),
            (cx + banner_w//2, banner_y),
            (cx + banner_w//2 + 15, banner_y + 5),
            (cx + banner_w//2 + 10, banner_y + banner_h),
            (cx + banner_w//2, banner_y + banner_h - 5),
            (cx - banner_w//2, banner_y + banner_h - 5),
            (cx - banner_w//2 - 10, banner_y + banner_h),
        ]
        pygame.draw.polygon(screen, RED_ACCENT, ribbon_points)
        pygame.draw.polygon(screen, GOLD_MID, ribbon_points, 2)

        # 리본 그림자
        pygame.draw.line(screen, (120, 40, 40), (int(cx - banner_w//2), int(banner_y + banner_h - 8)),
                        (int(cx + banner_w//2), int(banner_y + banner_h - 8)), 2)

        # 텍스트 "COMBAT ACADEMY"
        font_small = self.fonts.get('small')
        if font_small:
            text_surf, text_rect = font_small.render("COMBAT ACADEMY", GOLD_BRIGHT)
            screen.blit(text_surf, (int(cx - text_rect.width // 2), int(banner_y + 5)))

        # === 6. 상단 왕관 장식 ===
        crown_y = cy - outer_radius + 5
        crown_w = 60
        crown_h = 25

        # 왕관 본체
        crown_points = [
            (cx - crown_w//2, crown_y + crown_h),
            (cx - crown_w//2, crown_y + crown_h * 0.4),
            (cx - crown_w//3, crown_y),
            (cx - crown_w//6, crown_y + crown_h * 0.3),
            (cx, crown_y - 5),
            (cx + crown_w//6, crown_y + crown_h * 0.3),
            (cx + crown_w//3, crown_y),
            (cx + crown_w//2, crown_y + crown_h * 0.4),
            (cx + crown_w//2, crown_y + crown_h),
        ]
        pygame.draw.polygon(screen, GOLD_MID, crown_points)
        pygame.draw.polygon(screen, GOLD_BRIGHT, crown_points, 2)

        # 왕관 보석들
        gem_positions = [(cx - crown_w//3, crown_y + 3), (cx, crown_y - 2), (cx + crown_w//3, crown_y + 3)]
        for gx, gy in gem_positions:
            pygame.draw.circle(screen, RED_ACCENT, (int(gx), int(gy)), 4)
            pygame.draw.circle(screen, (220, 100, 100), (int(gx - 1), int(gy - 1)), 2)

    def _draw_magic_circle(self, screen, cx, cy, anim_timer):
        """마법진 그리기 (바닥 중앙) - 레거시, 훈련소에서는 사용 안함"""
        pass  # _draw_training_emblem으로 대체됨

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

    # ========== 훈련소 전용 인테리어 함수들 ==========

    def _draw_training_windows(self, screen, cam_x, cam_y, wall_h, anim_timer):
        """훈련소 창문들 (철창 스타일)"""
        import math

        FRAME_COLOR = (70, 75, 80)       # 금속 창틀
        GLASS_COLOR = (40, 50, 60)       # 어두운 유리
        LIGHT_COLOR = (200, 180, 150)    # 따뜻한 빛
        BAR_COLOR = (90, 95, 100)        # 철창

        # 창문 설정
        window_w = 55
        window_h = 65
        window_y = -cam_y + 25

        # 창문 개수와 간격
        num_windows = 5
        spacing = self.pixel_width // (num_windows + 1)

        for i in range(num_windows):
            wx = -cam_x + spacing * (i + 1) - window_w // 2

            # 창문 배경 (유리)
            pygame.draw.rect(screen, GLASS_COLOR, (wx, window_y, window_w, window_h))

            # 빛 효과 (약간의 애니메이션)
            light_intensity = int(80 + 40 * math.sin(anim_timer * 0.8 + i * 0.3))
            light_surf = pygame.Surface((window_w - 8, window_h - 8), pygame.SRCALPHA)
            light_surf.fill((*LIGHT_COLOR, light_intensity))
            screen.blit(light_surf, (wx + 4, window_y + 4))

            # 철창 (세로 바)
            for bar in range(4):
                bar_x = wx + 10 + bar * 12
                pygame.draw.rect(screen, BAR_COLOR, (bar_x, window_y, 4, window_h))

            # 창틀
            pygame.draw.rect(screen, FRAME_COLOR, (wx, window_y, window_w, window_h), 4)

    def _draw_training_equipment(self, screen, cam_x, cam_y, wall_h):
        """훈련 장비 그리기 (타이어, 수류탄 상자) - 고퀄리티 3D 버전"""
        import math

        # 색상 팔레트
        TIRE_BLACK = (25, 25, 30)
        TIRE_DARK = (35, 35, 40)
        TIRE_MID = (50, 50, 55)
        TIRE_LIGHT = (70, 70, 75)
        TIRE_TREAD = (40, 40, 45)

        BOX_WOOD = (130, 95, 55)
        BOX_WOOD_LIGHT = (160, 125, 80)
        BOX_WOOD_DARK = (90, 65, 35)
        BOX_WOOD_SHADOW = (60, 45, 25)
        METAL_BAND = (80, 85, 90)
        METAL_LIGHT = (120, 125, 130)

        GRENADE_BODY = (75, 95, 65)
        GRENADE_LIGHT = (100, 125, 85)
        GRENADE_DARK = (50, 65, 40)
        GRENADE_METAL = (160, 165, 170)
        PIN_GOLD = (200, 180, 100)

        WARNING_YELLOW = (255, 200, 50)
        WARNING_BLACK = (30, 30, 35)

        equip_y = wall_h + 40 - cam_y

        # ========== 타이어 스택 (왼쪽) - 3D 입체 ==========
        tire_x = 40 - cam_x
        tire_w, tire_h = 70, 35

        # 타이어 3개 쌓기 (아래서 위로)
        for t in range(3):
            ty = equip_y + (2 - t) * 28  # 위에서 아래로 그리기

            # 타이어 그림자
            shadow_surf = pygame.Surface((tire_w + 10, tire_h + 5), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40), (5, 5, tire_w, tire_h))
            screen.blit(shadow_surf, (tire_x - 2, ty + 3))

            # 타이어 측면 (3D 두께)
            pygame.draw.ellipse(screen, TIRE_BLACK, (tire_x, ty + 8, tire_w, tire_h))

            # 타이어 본체 (상단면)
            pygame.draw.ellipse(screen, TIRE_DARK, (tire_x, ty, tire_w, tire_h))

            # 타이어 트레드 패턴 (바깥쪽)
            for i in range(8):
                angle = i * math.pi / 4
                px = tire_x + tire_w // 2 + int((tire_w // 2 - 8) * math.cos(angle))
                py = ty + tire_h // 2 + int((tire_h // 2 - 4) * math.sin(angle))
                pygame.draw.circle(screen, TIRE_TREAD, (px, py), 3)

            # 타이어 테두리 하이라이트
            pygame.draw.ellipse(screen, TIRE_MID, (tire_x + 3, ty + 2, tire_w - 6, tire_h - 4), 2)

            # 타이어 내부 구멍 (림)
            rim_x = tire_x + tire_w // 2 - 15
            rim_y = ty + tire_h // 2 - 8
            pygame.draw.ellipse(screen, TIRE_BLACK, (rim_x, rim_y, 30, 16))
            pygame.draw.ellipse(screen, TIRE_MID, (rim_x + 3, rim_y + 2, 24, 12))
            pygame.draw.ellipse(screen, TIRE_LIGHT, (rim_x + 8, rim_y + 4, 14, 8))

            # 림 볼트
            for b in range(4):
                bolt_angle = b * math.pi / 2 + math.pi / 4
                bx = tire_x + tire_w // 2 + int(8 * math.cos(bolt_angle))
                by = ty + tire_h // 2 + int(4 * math.sin(bolt_angle))
                pygame.draw.circle(screen, METAL_LIGHT, (bx, by), 2)

        # ========== 수류탄 상자 - 3D 입체 ==========
        box_x = int(140 - cam_x)
        box_y = int(equip_y + 25)
        box_w, box_h, box_d = 65, 55, 15  # 너비, 높이, 깊이

        # 상자 그림자
        shadow_surf = pygame.Surface((box_w + 15, box_h + 10), pygame.SRCALPHA)
        pygame.draw.rect(shadow_surf, (0, 0, 0, 50), (8, 8, box_w, box_h), border_radius=3)
        screen.blit(shadow_surf, (box_x - 3, box_y))

        # 상자 측면 (3D - 오른쪽)
        side_points = [
            (box_x + box_w, box_y + 5),
            (box_x + box_w + box_d, box_y - 5),
            (box_x + box_w + box_d, box_y + box_h - 10),
            (box_x + box_w, box_y + box_h),
        ]
        pygame.draw.polygon(screen, BOX_WOOD_DARK, side_points)
        pygame.draw.polygon(screen, BOX_WOOD_SHADOW, side_points, 2)

        # 상자 상단면 (3D - 열린 뚜껑)
        top_points = [
            (box_x, box_y),
            (box_x + box_d, box_y - box_d),
            (box_x + box_w + box_d, box_y - box_d),
            (box_x + box_w, box_y),
        ]
        pygame.draw.polygon(screen, BOX_WOOD_LIGHT, top_points)
        pygame.draw.polygon(screen, BOX_WOOD, top_points, 2)

        # 상자 정면
        pygame.draw.rect(screen, BOX_WOOD, (box_x, box_y, box_w, box_h), border_radius=3)

        # 나무 결 텍스처
        for line_y in range(box_y + 8, box_y + box_h - 5, 12):
            pygame.draw.line(screen, BOX_WOOD_DARK, (box_x + 5, line_y), (box_x + box_w - 5, line_y), 1)

        # 상자 테두리
        pygame.draw.rect(screen, BOX_WOOD_DARK, (box_x, box_y, box_w, box_h), 3, border_radius=3)

        # 금속 보강 밴드
        pygame.draw.rect(screen, METAL_BAND, (box_x, box_y + 10, box_w, 6))
        pygame.draw.rect(screen, METAL_LIGHT, (box_x, box_y + 10, box_w, 2))
        pygame.draw.rect(screen, METAL_BAND, (box_x, box_y + box_h - 16, box_w, 6))
        pygame.draw.rect(screen, METAL_LIGHT, (box_x, box_y + box_h - 16, box_w, 2))

        # 경고 스트라이프 (대각선)
        for stripe in range(0, box_w + 20, 10):
            sx = box_x + stripe
            if stripe % 20 == 0:
                pygame.draw.line(screen, WARNING_YELLOW, (sx, box_y + box_h - 8), (sx - 8, box_y + box_h), 4)
            else:
                pygame.draw.line(screen, WARNING_BLACK, (sx, box_y + box_h - 8), (sx - 8, box_y + box_h), 4)

        # 모서리 리벳
        rivet_positions = [(box_x + 8, box_y + 8), (box_x + box_w - 8, box_y + 8),
                          (box_x + 8, box_y + box_h - 8), (box_x + box_w - 8, box_y + box_h - 8)]
        for rx, ry in rivet_positions:
            pygame.draw.circle(screen, METAL_BAND, (rx, ry), 4)
            pygame.draw.circle(screen, METAL_LIGHT, (rx - 1, ry - 1), 2)

        # ========== 수류탄들 (상자 안에 보이는) - 고디테일 ==========
        for g in range(3):
            gx = int(box_x + 12 + g * 18)
            gy = int(box_y - 15)

            # 수류탄 그림자
            pygame.draw.ellipse(screen, (0, 0, 0, 60), (gx + 2, gy + 2, 16, 24))

            # 수류탄 몸체 (파인애플 형태)
            pygame.draw.ellipse(screen, GRENADE_BODY, (gx, gy, 16, 24))

            # 몸체 하이라이트
            pygame.draw.ellipse(screen, GRENADE_LIGHT, (gx + 2, gy + 2, 8, 12))

            # 파인애플 패턴 (격자)
            for py in range(gy + 6, gy + 20, 5):
                pygame.draw.line(screen, GRENADE_DARK, (gx + 3, py), (gx + 13, py), 1)
            for px in range(gx + 4, gx + 14, 4):
                pygame.draw.line(screen, GRENADE_DARK, (px, gy + 5), (px, gy + 20), 1)

            # 수류탄 상단 (퓨즈 어셈블리)
            pygame.draw.rect(screen, GRENADE_METAL, (gx + 5, gy - 6, 6, 8), border_radius=2)
            pygame.draw.rect(screen, (180, 185, 190), (gx + 5, gy - 6, 6, 3), border_radius=1)

            # 안전핀과 링
            pygame.draw.rect(screen, PIN_GOLD, (gx + 7, gy - 10, 2, 5))
            pygame.draw.circle(screen, PIN_GOLD, (gx + 8, gy - 12), 4, 2)

            # 스푼 (레버)
            pygame.draw.rect(screen, GRENADE_METAL, (gx + 11, gy - 4, 3, 12), border_radius=1)

    def _draw_shooting_range(self, screen, cam_x, cam_y, wall_h, anim_timer):
        """사격 연습장 그리기 - 고품질 3D 버전"""
        import math

        # === 색상 팔레트 ===
        BOOTH_DARK = (35, 40, 48)
        BOOTH_MID = (55, 62, 72)
        BOOTH_LIGHT = (75, 85, 98)

        METAL_DARK = (50, 55, 60)
        METAL_MID = (90, 100, 110)
        METAL_LIGHT = (140, 155, 170)

        TARGET_PAPER = (235, 225, 200)
        TARGET_PAPER_DARK = (200, 190, 165)
        TARGET_RED = (180, 40, 40)
        TARGET_RED_DARK = (130, 25, 25)
        TARGET_RING = (50, 50, 55)

        LIGHT_YELLOW = (255, 240, 180)

        # 위치 계산 (가장자리에서 떨어뜨림)
        range_x = self.pixel_width - 180 - cam_x
        range_y = wall_h + 40 - cam_y
        booth_w, booth_h = 140, 160

        # === 바닥 그림자 ===
        shadow_surf = pygame.Surface((booth_w + 30, 20), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 50), (0, 0, booth_w + 30, 20))
        screen.blit(shadow_surf, (range_x - 15, range_y + booth_h - 5))

        # === 뒷벽 (3D 깊이감) ===
        pygame.draw.rect(screen, BOOTH_DARK, (range_x, range_y, booth_w, booth_h))

        # 뒷벽 3D 효과 (왼쪽 측면)
        back_points = [
            (range_x, range_y),
            (range_x - 15, range_y + 10),
            (range_x - 15, range_y + booth_h + 10),
            (range_x, range_y + booth_h)
        ]
        pygame.draw.polygon(screen, BOOTH_MID, back_points)

        # 뒷벽 상단 면
        top_points = [
            (range_x, range_y),
            (range_x - 15, range_y + 10),
            (range_x + booth_w - 15, range_y + 10),
            (range_x + booth_w, range_y)
        ]
        pygame.draw.polygon(screen, BOOTH_LIGHT, top_points)

        # === 사격 레인 (2개) ===
        lane_w = booth_w // 2 - 8
        for lane_idx in range(2):
            lane_x = range_x + 4 + lane_idx * (lane_w + 8)

            # 레인 바닥
            pygame.draw.rect(screen, (25, 28, 35), (lane_x, range_y + 90, lane_w, booth_h - 95))

            # 레인 벽
            pygame.draw.rect(screen, BOOTH_MID, (lane_x - 3, range_y, 6, booth_h), border_radius=2)
            pygame.draw.rect(screen, BOOTH_LIGHT, (lane_x - 1, range_y, 2, booth_h))

            # === 과녁 레일 시스템 ===
            rail_y = range_y + 12
            pygame.draw.rect(screen, METAL_DARK, (lane_x + 5, rail_y, lane_w - 10, 8))
            pygame.draw.rect(screen, METAL_LIGHT, (lane_x + 5, rail_y, lane_w - 10, 3))

            # 과녁 행거 (움직이는 효과)
            hanger_offset = int(8 * math.sin(anim_timer * 1.5 + lane_idx * math.pi))
            hanger_x = lane_x + lane_w // 2 + hanger_offset

            pygame.draw.line(screen, METAL_MID, (hanger_x, rail_y + 8), (hanger_x, rail_y + 25), 2)
            pygame.draw.circle(screen, METAL_LIGHT, (hanger_x, rail_y + 10), 3)

            # === 인체 과녁 ===
            target_x = hanger_x - 18
            target_y = rail_y + 25
            target_w, target_h = 36, 55
            tilt = hanger_offset / 20

            # 과녁 종이
            target_points = [
                (target_x + tilt, target_y),
                (target_x + target_w + tilt, target_y),
                (target_x + target_w - tilt, target_y + target_h),
                (target_x - tilt, target_y + target_h)
            ]
            pygame.draw.polygon(screen, TARGET_PAPER, target_points)
            pygame.draw.polygon(screen, TARGET_PAPER_DARK, target_points, 2)

            # 인체 실루엣
            head_x = target_x + target_w // 2
            head_y = target_y + 10
            pygame.draw.circle(screen, (60, 60, 65), (int(head_x), int(head_y)), 8)

            body_points = [
                (head_x - 10, head_y + 8), (head_x + 10, head_y + 8),
                (head_x + 12, head_y + 35), (head_x + 6, head_y + 45),
                (head_x - 6, head_y + 45), (head_x - 12, head_y + 35)
            ]
            pygame.draw.polygon(screen, (60, 60, 65), body_points)

            # 점수 링
            ring_x, ring_y = int(head_x), int(head_y + 22)
            pygame.draw.circle(screen, TARGET_RING, (ring_x, ring_y), 14, 2)
            pygame.draw.circle(screen, TARGET_RING, (ring_x, ring_y), 10, 2)
            pygame.draw.circle(screen, TARGET_RED_DARK, (ring_x, ring_y), 7)
            pygame.draw.circle(screen, TARGET_RED, (ring_x, ring_y), 5)
            pygame.draw.circle(screen, (255, 255, 200), (ring_x, ring_y), 2)

            # 총알 구멍들
            holes = [(ring_x - 3, ring_y + 2), (ring_x + 4, ring_y - 1)] if lane_idx == 0 else [(ring_x - 2, ring_y - 3)]
            for hx, hy in holes:
                pygame.draw.circle(screen, (20, 20, 25), (hx, hy), 2)
                pygame.draw.circle(screen, TARGET_PAPER_DARK, (hx, hy), 3, 1)

            # === 조명 ===
            light_x = lane_x + lane_w // 2
            light_y = range_y + 5
            pygame.draw.rect(screen, METAL_DARK, (light_x - 8, light_y, 16, 6), border_radius=2)
            pygame.draw.rect(screen, METAL_LIGHT, (light_x - 6, light_y + 1, 12, 2))

            glow_alpha = int(40 + 20 * math.sin(anim_timer * 4 + lane_idx))
            glow_surf = pygame.Surface((40, 80), pygame.SRCALPHA)
            pygame.draw.polygon(glow_surf, (*LIGHT_YELLOW[:3], glow_alpha), [(20, 0), (35, 70), (5, 70)])
            screen.blit(glow_surf, (light_x - 20, light_y + 5))

        # === 선반 (하단) ===
        shelf_y = range_y + booth_h - 35
        pygame.draw.rect(screen, BOOTH_MID, (range_x + 5, shelf_y, booth_w - 10, 8))
        pygame.draw.rect(screen, BOOTH_LIGHT, (range_x + 5, shelf_y, booth_w - 10, 3))

        # === 총 거치대 ===
        gun_x, gun_y = range_x + 15, shelf_y - 20
        pygame.draw.rect(screen, (40, 42, 48), (gun_x, gun_y, 25, 12), border_radius=2)
        pygame.draw.rect(screen, (60, 65, 75), (gun_x + 2, gun_y + 1, 20, 4))
        pygame.draw.rect(screen, (35, 30, 28), (gun_x + 5, gun_y + 10, 10, 15), border_radius=2)
        for gy in [11, 15, 19]:
            pygame.draw.rect(screen, (50, 45, 40), (gun_x + 6, gun_y + gy, 8, 2))
        pygame.draw.rect(screen, (30, 32, 38), (gun_x + 23, gun_y + 3, 8, 6), border_radius=1)

        # === 탄창 ===
        mag_x = range_x + 55
        pygame.draw.rect(screen, (45, 48, 55), (mag_x, shelf_y - 18, 8, 18), border_radius=1)
        pygame.draw.rect(screen, (70, 75, 85), (mag_x + 1, shelf_y - 17, 6, 3))
        pygame.draw.rect(screen, (45, 48, 55), (mag_x + 12, shelf_y - 18, 8, 18), border_radius=1)

        # === 귀마개 ===
        ear_x, ear_y = range_x + 95, shelf_y - 12
        pygame.draw.arc(screen, (40, 40, 45), (ear_x, ear_y - 8, 30, 20), 0, math.pi, 3)
        pygame.draw.ellipse(screen, (60, 60, 65), (ear_x - 2, ear_y, 14, 18))
        pygame.draw.ellipse(screen, (80, 80, 90), (ear_x, ear_y + 2, 10, 14))
        pygame.draw.ellipse(screen, (60, 60, 65), (ear_x + 20, ear_y, 14, 18))
        pygame.draw.ellipse(screen, (80, 80, 90), (ear_x + 22, ear_y + 2, 10, 14))

        # === 프레임 테두리 ===
        pygame.draw.rect(screen, METAL_DARK, (range_x - 2, range_y - 2, booth_w + 4, booth_h + 4), 3, border_radius=3)

    def _draw_ping_pong_tables(self, screen, cam_x, cam_y):
        """탁구대들 그리기 - 더 크고 분산된 위치, 탁구공 애니메이션 포함"""
        import math

        TABLE_GREEN = (40, 100, 60)
        TABLE_DARK = (30, 70, 45)
        TABLE_LIGHT = (60, 130, 80)
        NET_WHITE = (220, 220, 220)
        NET_SHADOW = (180, 180, 180)
        LINE_WHITE = (240, 240, 240)
        LEG_GRAY = (70, 70, 75)
        LEG_DARK = (50, 50, 55)
        BALL_WHITE = (255, 255, 255)
        BALL_ORANGE = (255, 180, 100)
        PADDLE_RED = (200, 60, 60)
        PADDLE_BLACK = (40, 40, 45)

        wall_h = int(TILE_SIZE * 3.5)

        # 탁구대 위치들 - 분산 배치 (왼쪽 상단, 오른쪽 하단)
        table_w, table_h = 140, 85  # 더 큰 탁구대
        table_positions = [
            (100, wall_h + 180),  # 왼쪽 상단
            (self.pixel_width - 280, self.pixel_height - 200),  # 오른쪽 하단
        ]

        for table_idx, (tx, ty) in enumerate(table_positions):
            table_x = tx - cam_x
            table_y = ty - cam_y

            # === 테이블 그림자 ===
            pygame.draw.rect(screen, (25, 25, 30), (table_x + 5, table_y + 5, table_w, table_h))

            # === 테이블 상판 ===
            pygame.draw.rect(screen, TABLE_GREEN, (table_x, table_y, table_w, table_h))

            # 상판 하이라이트 (위쪽)
            pygame.draw.rect(screen, TABLE_LIGHT, (table_x + 2, table_y + 2, table_w - 4, 8))

            # 테두리
            pygame.draw.rect(screen, TABLE_DARK, (table_x, table_y, table_w, table_h), 4)

            # === 테이블 라인 (흰색 테두리) ===
            pygame.draw.rect(screen, LINE_WHITE, (table_x + 6, table_y + 6, table_w - 12, table_h - 12), 3)

            # 중앙선 (세로)
            pygame.draw.line(screen, LINE_WHITE, (table_x + table_w // 2, table_y + 8),
                           (table_x + table_w // 2, table_y + table_h - 8), 3)

            # === 네트 (세로 중앙 배치) ===
            net_x = table_x + table_w // 2

            # 네트 지지대 (위아래)
            pygame.draw.rect(screen, (90, 90, 95), (net_x - 4, table_y + 2, 8, 8))
            pygame.draw.rect(screen, (90, 90, 95), (net_x - 4, table_y + table_h - 10, 8, 8))

            # 네트 세로 바 (중앙선 위)
            pygame.draw.rect(screen, (120, 120, 125), (net_x - 2, table_y + 8, 4, table_h - 16))

            # 네트 메쉬 (가로선들)
            for ny in range(12, table_h - 12, 6):
                pygame.draw.line(screen, NET_SHADOW, (net_x - 8, table_y + ny), (net_x + 8, table_y + ny), 1)

            # 네트 세로선 (중앙)
            pygame.draw.line(screen, NET_WHITE, (net_x, table_y + 10), (net_x, table_y + table_h - 10), 2)

            # === 테이블 다리 (4개) ===
            leg_w, leg_h = 10, 25
            leg_positions = [
                (table_x + 12, table_y + table_h),
                (table_x + table_w - 22, table_y + table_h),
                (table_x + 12, table_y + table_h),  # 앞쪽 다리
                (table_x + table_w - 22, table_y + table_h),
            ]
            for lx, ly in leg_positions[:2]:
                pygame.draw.rect(screen, LEG_GRAY, (lx, ly, leg_w, leg_h))
                pygame.draw.rect(screen, LEG_DARK, (lx, ly, leg_w, leg_h), 2)

            # === 탁구공 애니메이션 ===
            ball_phase = (self.animation_timer * 3 + table_idx * 1.5) % (2 * math.pi)
            ball_x_offset = int(50 * math.sin(ball_phase))  # 좌우로 왕복
            ball_y_offset = int(-15 * abs(math.sin(ball_phase * 2)))  # 위아래 튀는 효과

            ball_x = table_x + table_w // 2 + ball_x_offset
            ball_y = table_y + table_h // 2 - 25 + ball_y_offset

            # 공 그림자
            shadow_y = table_y + table_h // 2 - 5
            shadow_size = max(2, 5 - abs(ball_y_offset) // 3)
            pygame.draw.ellipse(screen, (30, 30, 35), (ball_x - shadow_size, shadow_y - 2, shadow_size * 2, 4))

            # 탁구공 (주황색 또는 흰색)
            ball_color = BALL_ORANGE if table_idx == 0 else BALL_WHITE
            pygame.draw.circle(screen, ball_color, (int(ball_x), int(ball_y)), 6)
            # 하이라이트
            pygame.draw.circle(screen, (255, 255, 255), (int(ball_x) - 2, int(ball_y) - 2), 2)

            # === 플레이어 위치 표시 (좌우) ===
            # 왼쪽 플레이어 위치
            left_player_x = table_x - 25
            left_player_y = table_y + table_h // 2

            # 오른쪽 플레이어 위치
            right_player_x = table_x + table_w + 25
            right_player_y = table_y + table_h // 2

            # 탁구채 그리기 (플레이어 손에)
            # 왼쪽 탁구채 (공이 오른쪽에 있을 때 스윙)
            left_swing = ball_x_offset < -20
            left_paddle_angle = 0.3 if left_swing else -0.2

            # 왼쪽 탁구채
            paddle_x = left_player_x + 20
            paddle_y = left_player_y - 10 + (5 if left_swing else 0)
            # 손잡이
            pygame.draw.rect(screen, PADDLE_BLACK, (paddle_x - 3, paddle_y + 8, 6, 15))
            # 라켓 면
            pygame.draw.ellipse(screen, PADDLE_RED, (paddle_x - 10, paddle_y - 5, 20, 25))
            pygame.draw.ellipse(screen, (180, 50, 50), (paddle_x - 10, paddle_y - 5, 20, 25), 2)

            # 오른쪽 탁구채 (공이 왼쪽에 있을 때 스윙)
            right_swing = ball_x_offset > 20
            paddle_x = right_player_x - 20
            paddle_y = right_player_y - 10 + (5 if right_swing else 0)
            # 손잡이
            pygame.draw.rect(screen, PADDLE_BLACK, (paddle_x - 3, paddle_y + 8, 6, 15))
            # 라켓 면 (검정색)
            pygame.draw.ellipse(screen, PADDLE_BLACK, (paddle_x - 10, paddle_y - 5, 20, 25))
            pygame.draw.ellipse(screen, (60, 60, 65), (paddle_x - 10, paddle_y - 5, 20, 25), 2)

    def _draw_healing_capsule(self, screen, cam_x, cam_y, anim_timer):
        """힐링 캡슐 그리기 - 고품질 3D SF 버전"""
        import math

        # === 색상 팔레트 ===
        # 금속 프레임
        FRAME_DARK = (40, 50, 65)
        FRAME_MID = (70, 85, 105)
        FRAME_LIGHT = (110, 130, 155)
        FRAME_SHINE = (160, 180, 210)

        # 유리/액체
        GLASS_OUTER = (80, 160, 200, 100)
        GLASS_INNER = (100, 200, 240, 80)
        LIQUID_GREEN = (60, 220, 140, 120)
        LIQUID_DARK = (40, 160, 100, 150)

        # 힐링 효과
        HEAL_GLOW = (80, 255, 160)
        HEAL_PARTICLE = (120, 255, 180)
        HEAL_RING = (100, 255, 200, 80)

        # 인체
        SKIN_BASE = (200, 160, 135)
        SKIN_SHADOW = (170, 130, 105)
        BANDAGE = (240, 240, 235)

        # 위치 계산 (가장자리에서 떨어뜨림)
        wall_h = int(TILE_SIZE * 3.5)
        capsule_x = self.pixel_width - 130 - cam_x
        capsule_y = wall_h + 240 - cam_y
        capsule_w, capsule_h = 80, 110

        # === 바닥 그림자 ===
        shadow_surf = pygame.Surface((capsule_w + 40, 25), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 60), (0, 0, capsule_w + 40, 25))
        screen.blit(shadow_surf, (capsule_x - 20, capsule_y + capsule_h - 8))

        # === 베이스 플랫폼 (3D) ===
        base_h = 22

        # 베이스 상단면
        base_top_points = [
            (capsule_x - 8, capsule_y + capsule_h - base_h),
            (capsule_x + capsule_w + 8, capsule_y + capsule_h - base_h),
            (capsule_x + capsule_w + 3, capsule_y + capsule_h - base_h + 5),
            (capsule_x - 3, capsule_y + capsule_h - base_h + 5)
        ]
        pygame.draw.polygon(screen, FRAME_LIGHT, base_top_points)

        # 베이스 전면
        base_front_points = [
            (capsule_x - 3, capsule_y + capsule_h - base_h + 5),
            (capsule_x + capsule_w + 3, capsule_y + capsule_h - base_h + 5),
            (capsule_x + capsule_w + 3, capsule_y + capsule_h),
            (capsule_x - 3, capsule_y + capsule_h)
        ]
        pygame.draw.polygon(screen, FRAME_MID, base_front_points)

        # 베이스 테두리
        pygame.draw.polygon(screen, FRAME_DARK, base_front_points, 2)

        # 베이스 환기구 (디테일)
        for i in range(4):
            vent_x = capsule_x + 8 + i * 18
            pygame.draw.rect(screen, FRAME_DARK, (vent_x, capsule_y + capsule_h - 12, 12, 6), border_radius=1)
            pygame.draw.rect(screen, (30, 40, 50), (vent_x + 2, capsule_y + capsule_h - 10, 8, 2))

        # === 캡슐 프레임 (3D 원통형) ===
        tube_y = capsule_y + 8
        tube_h = capsule_h - base_h - 8

        # 프레임 측면 (왼쪽)
        pygame.draw.rect(screen, FRAME_MID, (capsule_x - 2, tube_y, 8, tube_h), border_radius=2)
        pygame.draw.rect(screen, FRAME_LIGHT, (capsule_x - 2, tube_y, 4, tube_h), border_radius=2)
        pygame.draw.rect(screen, FRAME_SHINE, (capsule_x - 1, tube_y + 5, 2, tube_h - 10))

        # 프레임 측면 (오른쪽)
        pygame.draw.rect(screen, FRAME_MID, (capsule_x + capsule_w - 6, tube_y, 8, tube_h), border_radius=2)
        pygame.draw.rect(screen, FRAME_DARK, (capsule_x + capsule_w - 2, tube_y, 4, tube_h), border_radius=2)

        # 상단 아치
        pygame.draw.arc(screen, FRAME_MID, (capsule_x - 2, tube_y - 15, capsule_w + 4, 30), 0, math.pi, 6)
        pygame.draw.arc(screen, FRAME_LIGHT, (capsule_x, tube_y - 13, capsule_w, 26), 0.1, math.pi - 0.1, 3)

        # 상단 캡
        pygame.draw.ellipse(screen, FRAME_MID, (capsule_x + 5, tube_y - 8, capsule_w - 10, 16))
        pygame.draw.ellipse(screen, FRAME_LIGHT, (capsule_x + 10, tube_y - 5, capsule_w - 20, 10))

        # === 유리 튜브 (투명 효과) ===
        glass_surf = pygame.Surface((capsule_w - 12, tube_h - 5), pygame.SRCALPHA)

        # 외부 유리
        pygame.draw.rect(glass_surf, GLASS_OUTER, (0, 0, capsule_w - 12, tube_h - 5), border_radius=8)

        # 내부 하이라이트
        pygame.draw.rect(glass_surf, GLASS_INNER, (4, 4, capsule_w - 20, tube_h - 13), border_radius=6)

        # 반사 효과
        pygame.draw.rect(glass_surf, (255, 255, 255, 40), (6, 8, 8, tube_h - 25), border_radius=3)

        screen.blit(glass_surf, (capsule_x + 6, tube_y + 3))

        # === 치료액 (애니메이션) ===
        liquid_level = int(tube_h * 0.75)
        liquid_wave = int(3 * math.sin(anim_timer * 2))

        liquid_surf = pygame.Surface((capsule_w - 20, liquid_level), pygame.SRCALPHA)

        # 액체 메인
        pygame.draw.rect(liquid_surf, LIQUID_GREEN, (0, 5 + liquid_wave, capsule_w - 20, liquid_level - 10), border_radius=5)

        # 액체 표면 파동
        for wx in range(0, capsule_w - 20, 8):
            wave_y = int(3 * math.sin(anim_timer * 3 + wx * 0.2))
            pygame.draw.ellipse(liquid_surf, LIQUID_DARK, (wx, wave_y, 10, 6))

        screen.blit(liquid_surf, (capsule_x + 10, tube_y + tube_h - liquid_level - 5))

        # === 부상자 (더 상세하게) ===
        person_x = capsule_x + capsule_w // 2
        person_y = tube_y + 20

        # 머리
        pygame.draw.circle(screen, SKIN_BASE, (person_x, person_y), 11)
        pygame.draw.circle(screen, SKIN_SHADOW, (person_x + 3, person_y + 2), 9)  # 그림자
        pygame.draw.circle(screen, SKIN_BASE, (person_x - 1, person_y - 1), 9)  # 하이라이트

        # 눈 (감은 상태)
        pygame.draw.line(screen, (80, 60, 50), (person_x - 5, person_y - 1), (person_x - 2, person_y - 1), 1)
        pygame.draw.line(screen, (80, 60, 50), (person_x + 2, person_y - 1), (person_x + 5, person_y - 1), 1)

        # 몸통 (의료 가운)
        gown_color = (180, 200, 210)
        pygame.draw.rect(screen, gown_color, (person_x - 10, person_y + 10, 20, 40), border_radius=3)
        pygame.draw.rect(screen, (160, 180, 190), (person_x - 10, person_y + 10, 20, 40), 1, border_radius=3)

        # 팔
        pygame.draw.rect(screen, SKIN_BASE, (person_x - 14, person_y + 15, 6, 20), border_radius=2)
        pygame.draw.rect(screen, SKIN_BASE, (person_x + 8, person_y + 15, 6, 20), border_radius=2)

        # 붕대 (가슴)
        pygame.draw.rect(screen, BANDAGE, (person_x - 8, person_y + 18, 16, 12), border_radius=2)
        pygame.draw.line(screen, (200, 60, 60), (person_x - 5, person_y + 24), (person_x + 5, person_y + 24), 2)
        pygame.draw.line(screen, (200, 60, 60), (person_x, person_y + 20), (person_x, person_y + 28), 2)

        # 머리 붕대
        pygame.draw.arc(screen, BANDAGE, (person_x - 12, person_y - 14, 24, 20), 0.5, 2.6, 3)

        # === 힐링 이펙트 (상세) ===
        # 힐링 링 (회전)
        ring_phase = anim_timer * 2
        ring_y = tube_y + tube_h - liquid_level + int(10 * math.sin(anim_timer))

        ring_surf = pygame.Surface((capsule_w, 20), pygame.SRCALPHA)
        ring_w = int(capsule_w * 0.6 + 5 * math.sin(ring_phase))
        pygame.draw.ellipse(ring_surf, HEAL_RING, ((capsule_w - ring_w) // 2, 5, ring_w, 10), 2)
        screen.blit(ring_surf, (capsule_x, ring_y))

        # 힐링 파티클 (상승)
        for i in range(8):
            p_phase = (anim_timer * 40 + i * 30) % tube_h
            p_x_offset = int(12 * math.sin(anim_timer * 2 + i * 0.8))
            p_alpha = int(255 - p_phase * 2.5)

            if p_alpha > 0:
                p_size = max(2, 4 - int(p_phase / 25))
                p_surf = pygame.Surface((p_size * 2 + 4, p_size * 2 + 4), pygame.SRCALPHA)

                # 파티클 글로우
                pygame.draw.circle(p_surf, (*HEAL_PARTICLE[:3], p_alpha // 3), (p_size + 2, p_size + 2), p_size + 2)
                pygame.draw.circle(p_surf, (*HEAL_PARTICLE[:3], p_alpha), (p_size + 2, p_size + 2), p_size)

                screen.blit(p_surf, (person_x - p_size + p_x_offset, tube_y + tube_h - 15 - p_phase))

        # === 컨트롤 패널 (베이스 우측) ===
        panel_x = capsule_x + capsule_w - 25
        panel_y = capsule_y + capsule_h - base_h + 2

        # 패널 배경
        pygame.draw.rect(screen, FRAME_DARK, (panel_x, panel_y, 20, 15), border_radius=2)

        # LED 표시등
        led_glow = int(200 + 55 * math.sin(anim_timer * 4))
        pygame.draw.circle(screen, (50, led_glow, 100), (panel_x + 6, panel_y + 5), 3)
        pygame.draw.circle(screen, (200, 200, 60), (panel_x + 14, panel_y + 5), 3)

        # 미니 디스플레이
        pygame.draw.rect(screen, (20, 40, 30), (panel_x + 2, panel_y + 9, 16, 4))
        bar_width = int(10 + 4 * math.sin(anim_timer * 1.5))
        pygame.draw.rect(screen, (80, 255, 150), (panel_x + 3, panel_y + 10, bar_width, 2))

        # === 글로우 이펙트 (전체) ===
        glow_intensity = int(30 + 15 * math.sin(anim_timer * 1.5))
        glow_surf = pygame.Surface((capsule_w + 30, capsule_h + 30), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*HEAL_GLOW[:3], glow_intensity), (0, 0, capsule_w + 30, capsule_h + 30), border_radius=20)
        screen.blit(glow_surf, (capsule_x - 15, capsule_y - 15))

    def _draw_running_track(self, screen, cam_x, cam_y, wall_h):
        """러닝 트랙 라인 그리기 (바닥)"""
        TRACK_LINE = (255, 200, 100, 80)  # 반투명 골드

        # 트랙 시작/끝
        track_start_y = wall_h + 250
        track_end_y = self.pixel_height - 50

        # 트랙 라인들 (좌우 경계)
        track_surf = pygame.Surface((self.pixel_width, self.pixel_height), pygame.SRCALPHA)

        # 왼쪽 트랙 (세로)
        pygame.draw.line(track_surf, TRACK_LINE, (200, track_start_y), (200, track_end_y), 3)
        pygame.draw.line(track_surf, TRACK_LINE, (250, track_start_y), (250, track_end_y), 3)

        # 시작/결승선 (가로)
        pygame.draw.line(track_surf, TRACK_LINE, (200, track_end_y - 20), (250, track_end_y - 20), 5)

        # 화살표 마커 (방향 표시)
        for i in range(3):
            arrow_y = track_start_y + 50 + i * 80
            # 위쪽 화살표
            pygame.draw.polygon(track_surf, TRACK_LINE, [
                (225, arrow_y - 10),
                (215, arrow_y + 5),
                (235, arrow_y + 5)
            ])

        screen.blit(track_surf, (-cam_x, -cam_y))

    def _draw_tactical_bookshelves(self, screen, cam_x, cam_y, wall_h):
        """전술 매뉴얼 책장들 그리기 (도서관 영역)"""
        import math

        # 색상
        WOOD_DARK = (70, 50, 35)
        WOOD_MID = (100, 75, 50)
        WOOD_LIGHT = (130, 100, 70)
        BOOK_COLORS = [
            (180, 60, 60),    # 빨강
            (60, 100, 180),   # 파랑
            (60, 140, 80),    # 초록
            (180, 140, 60),   # 노랑
            (140, 80, 140),   # 보라
            (80, 80, 80),     # 회색
            (180, 120, 80),   # 주황
            (100, 150, 180),  # 하늘
        ]
        GOLD_ACCENT = (255, 200, 100)
        LABEL_BG = (40, 35, 30)

        # 책장 위치들 (3개 가로 배치 - 학장 아르카나 왼쪽)
        shelf_w, shelf_h = 55, 90
        headmaster_x = int(self.pixel_width * 0.5)  # 학장 위치 약 512
        shelf_start_x = headmaster_x - 250  # 학장보다 250픽셀 왼쪽
        shelf_y = wall_h + 60  # 학장과 비슷한 y 위치
        shelf_positions = [
            (shelf_start_x, shelf_y),
            (shelf_start_x + shelf_w + 15, shelf_y),
            (shelf_start_x + (shelf_w + 15) * 2, shelf_y),
        ]
        shelf_labels = ["전술", "기록", "역사"]

        for idx, (shelf_x, shelf_y) in enumerate(shelf_positions):
            sx = shelf_x - cam_x
            sy = shelf_y - cam_y

            # 책장 프레임 (나무 느낌)
            # 뒷판
            pygame.draw.rect(screen, WOOD_DARK, (sx, sy, shelf_w, shelf_h))
            # 테두리
            pygame.draw.rect(screen, WOOD_LIGHT, (sx, sy, shelf_w, shelf_h), 3)

            # 선반 4개 (수평)
            num_shelves = 4
            shelf_spacing = shelf_h // (num_shelves + 1)
            for s in range(1, num_shelves + 1):
                shelf_row_y = sy + s * shelf_spacing
                # 선반 판
                pygame.draw.rect(screen, WOOD_MID, (sx + 3, shelf_row_y - 2, shelf_w - 6, 6))
                pygame.draw.rect(screen, WOOD_LIGHT, (sx + 3, shelf_row_y - 2, shelf_w - 6, 6), 1)

                # 책들 그리기 (각 선반에)
                book_x = sx + 6
                row_idx = s - 1
                num_books = 5 + (row_idx % 3)  # 선반마다 다른 개수

                for b in range(num_books):
                    book_w = 6 + (b % 3) * 2  # 책 두께 다양
                    book_h = shelf_spacing - 12  # 선반 높이에 맞춤

                    if book_x + book_w > sx + shelf_w - 6:
                        break  # 선반 넘어가면 중단

                    # 책 색상 (다양하게)
                    color_idx = (idx * 7 + row_idx * 3 + b) % len(BOOK_COLORS)
                    book_color = BOOK_COLORS[color_idx]

                    book_top_y = shelf_row_y - book_h - 2

                    # 책 본체
                    pygame.draw.rect(screen, book_color, (book_x, book_top_y, book_w, book_h))

                    # 책 테두리 (어두운 색)
                    darker = tuple(max(0, c - 40) for c in book_color)
                    pygame.draw.rect(screen, darker, (book_x, book_top_y, book_w, book_h), 1)

                    # 일부 책에 금색 제목 라인
                    if b % 3 == 0:
                        title_y = book_top_y + book_h // 3
                        pygame.draw.line(screen, GOLD_ACCENT,
                                       (book_x + 2, title_y),
                                       (book_x + book_w - 2, title_y), 1)

                    # 일부 책 기울어진 느낌 (세로선)
                    if b % 4 == 2 and book_w > 8:
                        pygame.draw.line(screen, darker,
                                       (book_x + book_w - 2, book_top_y),
                                       (book_x + book_w - 2, book_top_y + book_h), 1)

                    book_x += book_w + 1

            # 책장 상단 장식 (금속 라벨)
            label_w, label_h = 40, 12
            label_x = sx + (shelf_w - label_w) // 2
            label_y = sy + 8

            pygame.draw.rect(screen, LABEL_BG, (label_x, label_y, label_w, label_h), border_radius=2)
            pygame.draw.rect(screen, GOLD_ACCENT, (label_x, label_y, label_w, label_h), 1, border_radius=2)

            # 라벨 텍스트
            font_small = self.fonts.get('small')
            if font_small:
                label_text = shelf_labels[idx] if idx < len(shelf_labels) else "기타"
                text_surf, text_rect = font_small.render(label_text, GOLD_ACCENT)
                screen.blit(text_surf, (label_x + (label_w - text_rect.width) // 2, label_y + 1))

            # 책장 하단 받침대
            base_h = 8
            pygame.draw.rect(screen, WOOD_MID, (sx - 2, sy + shelf_h, shelf_w + 4, base_h))
            pygame.draw.rect(screen, WOOD_LIGHT, (sx - 2, sy + shelf_h, shelf_w + 4, base_h), 1)

            # 발 (2개)
            foot_w, foot_h = 10, 5
            pygame.draw.rect(screen, WOOD_DARK, (sx + 5, sy + shelf_h + base_h, foot_w, foot_h))
            pygame.draw.rect(screen, WOOD_DARK, (sx + shelf_w - 15, sy + shelf_h + base_h, foot_w, foot_h))

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

        # 9. 충돌 영역 설정 (벽, 카운터, 진열대)
        self.shop_obstacle_rects = []

        # 상단 벽 영역 (상인들 뒤)
        self.shop_obstacle_rects.append(pygame.Rect(0, 0, self.pixel_width, wall_h))

        # 메인 카운터 충돌 영역
        self.shop_obstacle_rects.append(pygame.Rect(counter_x, counter_y, counter_w, counter_h))

        # 좌측 진열대 충돌 영역
        left_shelf_w = int(TILE_SIZE * 2.5)
        self.shop_obstacle_rects.append(pygame.Rect(left_shelf_x, counter_y, left_shelf_w, shelf_h))

        # 우측 진열대 충돌 영역
        right_shelf_w = int(TILE_SIZE * 2.5)
        self.shop_obstacle_rects.append(pygame.Rect(right_shelf_x, counter_y, right_shelf_w, shelf_h))

        # 10. 문 그리기
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
        """고급 유리 진열대 그리기 - 프리미엄 디자인"""
        import math

        # === 색상 팔레트 ===
        FRAME_DARK = (35, 25, 20)
        FRAME_MID = (55, 40, 30)
        FRAME_LIGHT = (75, 55, 40)
        FRAME_HIGHLIGHT = (95, 70, 50)
        GLASS_BASE = (200, 220, 240, 40)
        SHELF_WOOD = (90, 65, 45)
        SHELF_WOOD_DARK = (70, 50, 35)
        SHELF_WOOD_LIGHT = (110, 80, 55)
        METAL_DARK = (60, 65, 70)
        METAL_LIGHT = (120, 130, 140)

        frame_thickness = 8

        # === 1. 외곽 그림자 ===
        shadow_surf = pygame.Surface((w + 12, h + 12), pygame.SRCALPHA)
        pygame.draw.rect(shadow_surf, (0, 0, 0, 60), (6, 6, w, h), border_radius=6)
        screen.blit(shadow_surf, (x - 3, y - 3))

        # === 2. 프레임 ===
        pygame.draw.rect(screen, FRAME_DARK, (x - 2, y - 2, w + 4, h + 4), border_radius=5)
        pygame.draw.rect(screen, FRAME_MID, (x, y, w, h), border_radius=4)
        pygame.draw.line(screen, FRAME_LIGHT, (x + 2, y + 2), (x + w - 4, y + 2), 2)
        pygame.draw.line(screen, FRAME_LIGHT, (x + 2, y + 2), (x + 2, y + h - 4), 2)
        pygame.draw.line(screen, FRAME_DARK, (x + 4, y + h - 3), (x + w - 2, y + h - 3), 2)
        pygame.draw.line(screen, FRAME_DARK, (x + w - 3, y + 4), (x + w - 3, y + h - 2), 2)

        # === 3. 유리 내부 ===
        glass_rect = pygame.Rect(x + frame_thickness, y + frame_thickness,
                                 w - frame_thickness * 2, h - frame_thickness * 2)
        pygame.draw.rect(screen, (25, 20, 18), glass_rect, border_radius=3)
        glass_surf = pygame.Surface((glass_rect.width, glass_rect.height), pygame.SRCALPHA)
        pygame.draw.rect(glass_surf, GLASS_BASE, (0, 0, glass_rect.width, glass_rect.height), border_radius=3)
        screen.blit(glass_surf, glass_rect.topleft)

        # === 4. 선반 (4단) ===
        shelf_count = 4
        inner_h = glass_rect.height
        shelf_spacing = inner_h // (shelf_count + 1)
        shelf_thickness = 6

        for i in range(shelf_count):
            shelf_y = glass_rect.y + shelf_spacing * (i + 1)
            bracket_w, bracket_h = 6, 12

            # 브라켓
            pygame.draw.rect(screen, METAL_DARK, (glass_rect.x + 2, shelf_y - bracket_h + 3, bracket_w, bracket_h))
            pygame.draw.rect(screen, METAL_LIGHT, (glass_rect.x + 2, shelf_y - bracket_h + 3, bracket_w - 1, 2))
            pygame.draw.rect(screen, METAL_DARK, (glass_rect.right - bracket_w - 2, shelf_y - bracket_h + 3, bracket_w, bracket_h))
            pygame.draw.rect(screen, METAL_LIGHT, (glass_rect.right - bracket_w - 2, shelf_y - bracket_h + 3, bracket_w - 1, 2))

            # 선반
            shelf_x = glass_rect.x + bracket_w + 2
            shelf_w = glass_rect.width - bracket_w * 2 - 4
            pygame.draw.rect(screen, (20, 15, 12), (shelf_x, shelf_y + 1, shelf_w, shelf_thickness + 2), border_radius=1)
            pygame.draw.rect(screen, SHELF_WOOD, (shelf_x, shelf_y - shelf_thickness // 2, shelf_w, shelf_thickness), border_radius=1)
            pygame.draw.line(screen, SHELF_WOOD_LIGHT, (shelf_x + 2, shelf_y - shelf_thickness // 2 + 1), (shelf_x + shelf_w - 2, shelf_y - shelf_thickness // 2 + 1), 1)
            pygame.draw.line(screen, SHELF_WOOD_DARK, (shelf_x + 2, shelf_y + shelf_thickness // 2 - 1), (shelf_x + shelf_w - 2, shelf_y + shelf_thickness // 2 - 1), 1)

        # === 5. 아이템 배치 ===
        # 양쪽 진열대 모두 장식용 도구/장비 표시
        if side == "left":
            self._draw_premium_deco_items_left(screen, glass_rect, shelf_count, shelf_spacing, accent)
        else:
            self._draw_premium_deco_items(screen, glass_rect, shelf_count, shelf_spacing, accent)

        # === 6. 유리 반사 효과 ===
        shine_surf = pygame.Surface((glass_rect.width, glass_rect.height), pygame.SRCALPHA)
        for i in range(3):
            alpha = 40 - i * 12
            pygame.draw.line(shine_surf, (255, 255, 255, alpha), (i * 15, 0), (0, i * 15 + 30), 2)
        screen.blit(shine_surf, glass_rect.topleft)

        # === 7. 네온 글로우 ===
        glow_pulse = math.sin(self.animation_timer * 2.5)
        glow_alpha = int(50 + 30 * glow_pulse)
        glow_surf = pygame.Surface((w + 16, h + 16), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*accent, glow_alpha), (0, 0, w + 16, h + 16), 4, border_radius=8)
        screen.blit(glow_surf, (x - 8, y - 8))

        # === 8. 상단 라벨 ===
        label_w, label_h = 50, 14
        label_x = x + (w - label_w) // 2
        label_y = y - label_h - 2
        pygame.draw.rect(screen, FRAME_DARK, (label_x - 2, label_y - 1, label_w + 4, label_h + 2), border_radius=3)
        pygame.draw.rect(screen, FRAME_MID, (label_x, label_y, label_w, label_h), border_radius=2)
        if self.fonts and self.fonts.get('small'):
            try:
                label_text = "장비" if side == "left" else "소품"
                text_surf, text_rect = self.fonts['small'].render(label_text, accent)
                screen.blit(text_surf, (label_x + (label_w - text_rect.width) // 2, label_y + (label_h - text_rect.height) // 2))
            except:
                pass

        # === 9. 하단 받침대 ===
        base_h = 10
        base_y = y + h
        pygame.draw.rect(screen, (20, 15, 12), (x - 4, base_y + 2, w + 8, base_h), border_radius=2)
        pygame.draw.rect(screen, FRAME_DARK, (x - 3, base_y, w + 6, base_h), border_radius=2)
        pygame.draw.rect(screen, FRAME_MID, (x - 2, base_y, w + 4, base_h - 2), border_radius=2)
        pygame.draw.line(screen, FRAME_HIGHLIGHT, (x, base_y + 1), (x + w - 2, base_y + 1), 1)

    def _draw_premium_shop_items(self, screen, glass_rect, shelf_count, shelf_spacing, accent):
        """프리미엄 스타일 상점 아이템 표시"""
        import math
        try:
            import pingfighter
            get_item_icon = getattr(pingfighter, 'get_item_icon', None)
        except:
            get_item_icon = None

        items_per_shelf = 2
        icon_size = 28
        item_slot_w = (glass_rect.width - 24) // items_per_shelf

        for shelf_idx in range(shelf_count):
            shelf_y = glass_rect.y + shelf_spacing * (shelf_idx + 1)
            start_idx = shelf_idx * items_per_shelf

            for slot_idx in range(items_per_shelf):
                item_idx = start_idx + slot_idx
                if item_idx >= len(self.shop_inventory):
                    break

                item = self.shop_inventory[item_idx]
                item_name = item.get("name", "")
                item_type = item.get("type", "passive")

                # 위치 계산 (균등 정렬)
                slot_center_x = glass_rect.x + 12 + slot_idx * item_slot_w + item_slot_w // 2
                item_x = slot_center_x - icon_size // 2
                item_y = shelf_y - icon_size - 8

                # 받침대
                platform_w, platform_h = icon_size + 10, 4
                platform_x = slot_center_x - platform_w // 2
                pygame.draw.rect(screen, (50, 40, 35), (platform_x, shelf_y - platform_h - 2, platform_w, platform_h), border_radius=1)
                pygame.draw.line(screen, (70, 55, 45), (platform_x + 1, shelf_y - platform_h - 2), (platform_x + platform_w - 2, shelf_y - platform_h - 2), 1)

                # 품질 색상
                if item_type == "legendary":
                    bg_colors = [(180, 140, 50), (220, 180, 80), (255, 215, 100)]
                    border_color = (255, 215, 0)
                    glow_color = (255, 200, 50)
                else:
                    quality = item.get("quality", "normal")
                    if quality == "epic":
                        bg_colors = [(100, 50, 150), (130, 70, 180), (160, 100, 210)]
                        border_color, glow_color = (180, 100, 255), (150, 80, 220)
                    elif quality == "rare":
                        bg_colors = [(40, 80, 150), (60, 100, 180), (80, 130, 210)]
                        border_color, glow_color = (100, 150, 255), (80, 130, 220)
                    elif quality == "uncommon":
                        bg_colors = [(40, 120, 60), (60, 150, 80), (80, 180, 100)]
                        border_color, glow_color = (100, 200, 130), (80, 180, 100)
                    else:
                        bg_colors = [(60, 60, 65), (80, 80, 85), (100, 100, 105)]
                        border_color, glow_color = (140, 140, 145), (120, 120, 130)

                # 슬롯 배경 (그라데이션)
                slot_size = icon_size + 8
                slot_x, slot_y = item_x - 4, item_y - 4
                for i in range(3):
                    pygame.draw.rect(screen, bg_colors[min(i, len(bg_colors)-1)],
                                   (slot_x + i, slot_y + i, slot_size - i * 2, slot_size - i * 2), border_radius=4)

                # 하이라이트
                highlight_surf = pygame.Surface((slot_size - 4, slot_size - 4), pygame.SRCALPHA)
                pygame.draw.rect(highlight_surf, (255, 255, 255, 30), (0, 0, slot_size - 4, (slot_size - 4) // 2), border_radius=3)
                screen.blit(highlight_surf, (slot_x + 2, slot_y + 2))

                # 테두리
                pygame.draw.rect(screen, border_color, (slot_x, slot_y, slot_size, slot_size), 2, border_radius=4)

                # 아이콘
                icon = get_item_icon(item_name) if get_item_icon else None
                if icon:
                    try:
                        scaled_icon = pygame.transform.smoothscale(icon, (icon_size, icon_size))
                        screen.blit(scaled_icon, (item_x, item_y))
                    except:
                        pygame.draw.rect(screen, glow_color, (item_x, item_y, icon_size, icon_size), border_radius=3)
                else:
                    pygame.draw.rect(screen, glow_color, (item_x, item_y, icon_size, icon_size), border_radius=3)
                    if self.fonts and self.fonts.get('small'):
                        try:
                            q_surf, q_rect = self.fonts['small'].render("?", (255, 255, 255))
                            screen.blit(q_surf, (item_x + icon_size // 2 - q_rect.width // 2, item_y + icon_size // 2 - q_rect.height // 2))
                        except:
                            pass

                # 전설 효과
                if item_type == "legendary":
                    pulse = math.sin(self.animation_timer * 4 + item_idx * 0.5)
                    glow_alpha = int(80 + 60 * pulse)
                    glow_surf = pygame.Surface((slot_size + 12, slot_size + 12), pygame.SRCALPHA)
                    pygame.draw.rect(glow_surf, (255, 215, 0, glow_alpha), (0, 0, slot_size + 12, slot_size + 12), 3, border_radius=6)
                    screen.blit(glow_surf, (slot_x - 6, slot_y - 6))

    def _draw_premium_deco_items_left(self, screen, glass_rect, shelf_count, shelf_spacing, accent):
        """프리미엄 장식 아이템 (왼쪽 진열대 - 도구/장비)"""
        # 왼쪽 진열대용 장비/도구 패턴
        deco_patterns = [
            [("sword", (180, 180, 200)), ("shield", (100, 150, 200))],
            [("helmet", (160, 140, 120)), ("gloves", (140, 100, 70))],
            [("axe", (150, 150, 160)), ("bow", (160, 120, 80))],
            [("boots", (100, 80, 60)), ("dagger", (200, 200, 210))]
        ]
        items_per_shelf = 2
        item_slot_w = (glass_rect.width - 24) // items_per_shelf

        for shelf_idx in range(shelf_count):
            shelf_y = glass_rect.y + shelf_spacing * (shelf_idx + 1)
            pattern = deco_patterns[shelf_idx % len(deco_patterns)]

            for slot_idx, (item_type, color) in enumerate(pattern):
                slot_center_x = glass_rect.x + 12 + slot_idx * item_slot_w + item_slot_w // 2
                item_y = shelf_y - 28

                # 받침대
                platform_w, platform_h = 30, 4
                pygame.draw.rect(screen, (50, 40, 35), (slot_center_x - platform_w // 2, shelf_y - platform_h - 2, platform_w, platform_h), border_radius=1)

                if item_type == "sword":
                    self._draw_deco_sword(screen, slot_center_x, item_y, color)
                elif item_type == "shield":
                    self._draw_deco_shield(screen, slot_center_x, item_y + 2, color)
                elif item_type == "helmet":
                    self._draw_deco_helmet(screen, slot_center_x, item_y + 4, color)
                elif item_type == "gloves":
                    self._draw_deco_gloves(screen, slot_center_x, item_y + 6, color)
                elif item_type == "axe":
                    self._draw_deco_axe(screen, slot_center_x, item_y, color)
                elif item_type == "bow":
                    self._draw_deco_bow(screen, slot_center_x, item_y + 2, color)
                elif item_type == "boots":
                    self._draw_deco_boots(screen, slot_center_x, item_y + 6, color)
                elif item_type == "dagger":
                    self._draw_deco_dagger(screen, slot_center_x, item_y + 4, color)

    def _draw_deco_sword(self, screen, cx, y, color):
        """장식용 검"""
        # 검날
        blade_w, blade_h = 4, 22
        darker = tuple(max(0, c - 40) for c in color)
        lighter = tuple(min(255, c + 40) for c in color)
        pygame.draw.rect(screen, darker, (cx - blade_w // 2, y, blade_w, blade_h))
        pygame.draw.rect(screen, color, (cx - blade_w // 2 + 1, y, blade_w - 2, blade_h))
        pygame.draw.line(screen, lighter, (cx - 1, y + 2), (cx - 1, y + blade_h - 2), 1)
        # 검끝
        pygame.draw.polygon(screen, color, [(cx - blade_w // 2, y), (cx, y - 5), (cx + blade_w // 2, y)])
        # 가드
        guard_w, guard_h = 12, 4
        pygame.draw.rect(screen, (180, 150, 50), (cx - guard_w // 2, y + blade_h, guard_w, guard_h), border_radius=1)
        # 손잡이
        handle_w, handle_h = 3, 8
        pygame.draw.rect(screen, (100, 70, 40), (cx - handle_w // 2, y + blade_h + guard_h, handle_w, handle_h))
        # 폼멜
        pygame.draw.circle(screen, (180, 150, 50), (cx, y + blade_h + guard_h + handle_h + 2), 3)

    def _draw_deco_shield(self, screen, cx, y, color):
        """장식용 방패"""
        shield_w, shield_h = 18, 22
        darker = tuple(max(0, c - 30) for c in color)
        lighter = tuple(min(255, c + 30) for c in color)
        # 방패 본체
        points = [
            (cx, y),
            (cx + shield_w // 2, y + 4),
            (cx + shield_w // 2, y + shield_h - 6),
            (cx, y + shield_h),
            (cx - shield_w // 2, y + shield_h - 6),
            (cx - shield_w // 2, y + 4)
        ]
        pygame.draw.polygon(screen, darker, points)
        inner_points = [(p[0] * 0.85 + cx * 0.15, p[1] * 0.9 + y * 0.1 + 2) for p in points]
        pygame.draw.polygon(screen, color, inner_points)
        # 장식
        pygame.draw.circle(screen, (200, 170, 50), (cx, y + shield_h // 2), 4)
        pygame.draw.line(screen, lighter, (cx - 4, y + 6), (cx - 4, y + shield_h - 8), 1)

    def _draw_deco_helmet(self, screen, cx, y, color):
        """장식용 헬멧"""
        helmet_w, helmet_h = 16, 18
        darker = tuple(max(0, c - 30) for c in color)
        lighter = tuple(min(255, c + 40) for c in color)
        # 헬멧 본체
        pygame.draw.ellipse(screen, darker, (cx - helmet_w // 2, y, helmet_w, helmet_h - 4))
        pygame.draw.ellipse(screen, color, (cx - helmet_w // 2 + 1, y + 1, helmet_w - 2, helmet_h - 6))
        # 얼굴 가리개
        pygame.draw.rect(screen, darker, (cx - helmet_w // 2 + 2, y + helmet_h - 8, helmet_w - 4, 8), border_radius=2)
        # 눈 슬릿
        pygame.draw.rect(screen, (20, 20, 25), (cx - 5, y + helmet_h - 6, 10, 3))
        # 상단 장식
        pygame.draw.polygon(screen, lighter, [(cx, y - 4), (cx - 3, y + 2), (cx + 3, y + 2)])
        # 하이라이트
        pygame.draw.arc(screen, lighter, (cx - helmet_w // 2 + 2, y + 2, helmet_w - 4, helmet_h - 8), 0.5, 2.5, 1)

    def _draw_deco_gloves(self, screen, cx, y, color):
        """장식용 장갑"""
        glove_w, glove_h = 14, 16
        darker = tuple(max(0, c - 25) for c in color)
        lighter = tuple(min(255, c + 30) for c in color)
        # 장갑 본체
        pygame.draw.rect(screen, darker, (cx - glove_w // 2, y + 4, glove_w, glove_h - 4), border_radius=3)
        pygame.draw.rect(screen, color, (cx - glove_w // 2 + 1, y + 5, glove_w - 2, glove_h - 6), border_radius=2)
        # 손가락
        finger_w = 3
        for i in range(4):
            fx = cx - 5 + i * 3
            pygame.draw.rect(screen, color, (fx, y, finger_w, 6), border_radius=1)
        # 손목 부분
        pygame.draw.rect(screen, darker, (cx - glove_w // 2 - 1, y + glove_h - 2, glove_w + 2, 4), border_radius=1)
        # 금속 장식
        pygame.draw.circle(screen, (180, 170, 140), (cx, y + 10), 2)

    def _draw_deco_axe(self, screen, cx, y, color):
        """장식용 도끼"""
        # 자루
        handle_w, handle_h = 3, 26
        pygame.draw.rect(screen, (120, 85, 50), (cx - handle_w // 2, y + 4, handle_w, handle_h))
        pygame.draw.line(screen, (150, 110, 70), (cx - 1, y + 5), (cx - 1, y + handle_h + 2), 1)
        # 도끼날
        darker = tuple(max(0, c - 30) for c in color)
        axe_points = [
            (cx + 2, y + 2),
            (cx + 12, y - 2),
            (cx + 14, y + 8),
            (cx + 12, y + 16),
            (cx + 2, y + 14)
        ]
        pygame.draw.polygon(screen, darker, axe_points)
        pygame.draw.polygon(screen, color, [(p[0] - 1, p[1] + 1) for p in axe_points[:4]] + [axe_points[4]])
        # 날 하이라이트
        pygame.draw.line(screen, (220, 220, 230), (cx + 11, y), (cx + 13, y + 7), 1)

    def _draw_deco_bow(self, screen, cx, y, color):
        """장식용 활"""
        bow_h = 24
        darker = tuple(max(0, c - 20) for c in color)
        # 활 몸체 (곡선)
        pygame.draw.arc(screen, darker, (cx - 12, y, 14, bow_h), 1.2, 5.1, 4)
        pygame.draw.arc(screen, color, (cx - 11, y + 1, 12, bow_h - 2), 1.2, 5.1, 3)
        # 활시위
        pygame.draw.line(screen, (200, 190, 170), (cx - 5, y + 2), (cx - 5, y + bow_h - 2), 1)
        # 손잡이 부분
        pygame.draw.rect(screen, (100, 70, 45), (cx - 8, y + bow_h // 2 - 3, 5, 6), border_radius=1)

    def _draw_deco_boots(self, screen, cx, y, color):
        """장식용 부츠"""
        boot_w, boot_h = 12, 16
        darker = tuple(max(0, c - 25) for c in color)
        lighter = tuple(min(255, c + 25) for c in color)
        # 부츠 본체
        pygame.draw.rect(screen, darker, (cx - boot_w // 2, y, boot_w, boot_h - 4), border_radius=2)
        pygame.draw.rect(screen, color, (cx - boot_w // 2 + 1, y + 1, boot_w - 2, boot_h - 6), border_radius=1)
        # 발 부분
        pygame.draw.ellipse(screen, darker, (cx - boot_w // 2 - 2, y + boot_h - 6, boot_w + 6, 6))
        pygame.draw.ellipse(screen, color, (cx - boot_w // 2 - 1, y + boot_h - 5, boot_w + 4, 4))
        # 버클
        pygame.draw.rect(screen, (180, 160, 100), (cx - 2, y + 4, 4, 3))
        # 하이라이트
        pygame.draw.line(screen, lighter, (cx - boot_w // 2 + 2, y + 2), (cx - boot_w // 2 + 2, y + boot_h - 8), 1)

    def _draw_deco_dagger(self, screen, cx, y, color):
        """장식용 단검"""
        # 검날
        blade_h = 14
        darker = tuple(max(0, c - 30) for c in color)
        lighter = tuple(min(255, c + 50) for c in color)
        blade_points = [(cx, y), (cx + 3, y + blade_h), (cx - 3, y + blade_h)]
        pygame.draw.polygon(screen, darker, blade_points)
        pygame.draw.polygon(screen, color, [(cx, y + 2), (cx + 2, y + blade_h - 1), (cx - 2, y + blade_h - 1)])
        pygame.draw.line(screen, lighter, (cx, y + 3), (cx, y + blade_h - 2), 1)
        # 가드
        pygame.draw.rect(screen, (160, 130, 50), (cx - 5, y + blade_h, 10, 3), border_radius=1)
        # 손잡이
        pygame.draw.rect(screen, (80, 55, 35), (cx - 2, y + blade_h + 3, 4, 8))
        # 폼멜
        pygame.draw.circle(screen, (160, 130, 50), (cx, y + blade_h + 12), 2)

    def _draw_premium_deco_items(self, screen, glass_rect, shelf_count, shelf_spacing, accent):
        """프리미엄 장식 아이템 (오른쪽 진열대)"""
        deco_patterns = [
            [("potion", (255, 80, 100)), ("gem", (100, 200, 255))],
            [("scroll", None), ("chest", accent)],
            [("gem", (100, 255, 150)), ("potion", (150, 100, 255))],
            [("chest", accent), ("scroll", None)]
        ]
        items_per_shelf = 2
        item_slot_w = (glass_rect.width - 24) // items_per_shelf

        for shelf_idx in range(shelf_count):
            shelf_y = glass_rect.y + shelf_spacing * (shelf_idx + 1)
            pattern = deco_patterns[shelf_idx % len(deco_patterns)]

            for slot_idx, (item_type, color) in enumerate(pattern):
                slot_center_x = glass_rect.x + 12 + slot_idx * item_slot_w + item_slot_w // 2
                item_y = shelf_y - 28

                # 받침대
                platform_w, platform_h = 30, 4
                pygame.draw.rect(screen, (50, 40, 35), (slot_center_x - platform_w // 2, shelf_y - platform_h - 2, platform_w, platform_h), border_radius=1)

                if item_type == "potion":
                    self._draw_premium_potion(screen, slot_center_x, item_y, color)
                elif item_type == "gem":
                    self._draw_premium_gem(screen, slot_center_x, item_y + 5, color)
                elif item_type == "chest":
                    self._draw_premium_chest(screen, slot_center_x - 12, item_y, color)
                elif item_type == "scroll":
                    self._draw_premium_scroll(screen, slot_center_x - 10, item_y + 5)

    def _draw_premium_potion(self, screen, cx, y, color):
        """고급 포션 병"""
        neck_w, neck_h = 6, 8
        pygame.draw.rect(screen, (180, 180, 190), (cx - neck_w // 2, y, neck_w, neck_h), border_radius=1)
        pygame.draw.rect(screen, (160, 120, 80), (cx - neck_w // 2 + 1, y - 4, neck_w - 2, 5), border_radius=1)
        body_w, body_h = 14, 16
        body_y = y + neck_h
        darker = tuple(max(0, c - 40) for c in color)
        pygame.draw.ellipse(screen, darker, (cx - body_w // 2, body_y, body_w, body_h))
        pygame.draw.ellipse(screen, color, (cx - body_w // 2 + 1, body_y + 1, body_w - 3, body_h - 3))
        pygame.draw.circle(screen, (255, 255, 255), (cx - 2, body_y + body_h // 2), 2)

    def _draw_premium_gem(self, screen, cx, cy, color):
        """고급 보석"""
        size = 10
        points = [(cx, cy - size), (cx + size, cy), (cx + size // 2, cy + size), (cx - size // 2, cy + size), (cx - size, cy)]
        darker = tuple(max(0, c - 60) for c in color)
        pygame.draw.polygon(screen, darker, points)
        inner_points = [(cx, cy - size + 3), (cx + size - 3, cy), (cx + size // 2 - 1, cy + size - 3), (cx - size // 2 + 1, cy + size - 3), (cx - size + 3, cy)]
        pygame.draw.polygon(screen, color, inner_points)
        lighter = tuple(min(255, c + 60) for c in color)
        pygame.draw.polygon(screen, lighter, [(cx, cy - size + 3), (cx + size - 5, cy - 2), (cx, cy + 2), (cx - size + 5, cy - 2)])
        pygame.draw.circle(screen, (255, 255, 255), (cx - 3, cy - 4), 2)
        pygame.draw.polygon(screen, (255, 255, 255), points, 1)

    def _draw_premium_chest(self, screen, x, y, accent):
        """고급 상자"""
        chest_w, chest_h = 24, 18
        pygame.draw.rect(screen, (30, 20, 15), (x + 2, y + 2, chest_w, chest_h), border_radius=2)
        pygame.draw.rect(screen, (120, 75, 35), (x, y, chest_w, chest_h), border_radius=2)
        pygame.draw.rect(screen, (150, 100, 55), (x + 1, y + 1, chest_w - 2, chest_h // 2), border_radius=2)
        pygame.draw.rect(screen, (140, 90, 45), (x - 2, y - 4, chest_w + 4, 8), border_radius=2)
        pygame.draw.rect(screen, (80, 70, 60), (x + 2, y + chest_h // 2 - 2, chest_w - 4, 4))
        pygame.draw.circle(screen, accent, (x + chest_w // 2, y + chest_h // 2 + 1), 3)

    def _draw_premium_scroll(self, screen, x, y):
        """고급 두루마리"""
        scroll_w, scroll_h = 20, 12
        pygame.draw.rect(screen, (230, 215, 180), (x + 4, y + 2, scroll_w - 8, scroll_h - 4))
        roll_r = 6
        pygame.draw.circle(screen, (200, 180, 140), (x + roll_r, y + scroll_h // 2), roll_r)
        pygame.draw.circle(screen, (180, 160, 120), (x + roll_r, y + scroll_h // 2), roll_r - 2)
        pygame.draw.circle(screen, (200, 180, 140), (x + scroll_w - roll_r, y + scroll_h // 2), roll_r)
        pygame.draw.circle(screen, (180, 160, 120), (x + scroll_w - roll_r, y + scroll_h // 2), roll_r - 2)
        for i in range(3):
            pygame.draw.line(screen, (180, 160, 130), (x + 7 + i, y + 3 + i * 3), (x + 7 + scroll_w - 14 - i * 2, y + 3 + i * 3), 1)
        pygame.draw.rect(screen, (180, 50, 50), (x + scroll_w // 2 - 2, y - 2, 4, scroll_h + 4))

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

    # =========================================================================
    # 사이버펑크 가챠샵 인테리어 (Cyberpunk Arcade Style)
    # =========================================================================
    def _draw_cyberpunk_gacha_interior(self, screen):
        """사이버펑크 가챠샵 전용 인테리어 그리기 - 일본 아케이드 스타일"""
        import math

        # 색상 정의 (네온 사이버펑크)
        BG_DARK = (25, 15, 35)  # 어두운 보라 배경
        FLOOR_PINK = (80, 40, 90)  # 핑크빛 바닥
        FLOOR_PINK_DARK = (60, 30, 70)  # 어두운 핑크 바닥
        FLOOR_STRIPE = (120, 60, 130)  # 바닥 스트라이프
        WALL_PURPLE = (45, 25, 60)  # 보라색 벽
        NEON_PINK = (255, 50, 150)  # 네온 핑크/마젠타
        NEON_CYAN = (0, 255, 255)  # 네온 시안
        NEON_GREEN = (50, 255, 100)  # 네온 그린
        NEON_YELLOW = (255, 255, 0)  # 네온 옐로우
        NEON_BLUE = (100, 150, 255)  # 네온 블루
        MACHINE_PURPLE = (100, 60, 140)  # 가챠 머신 보라
        MACHINE_PINK = (180, 80, 160)  # 가챠 머신 핑크
        ESCALATOR_GRAY = (80, 80, 100)  # 에스컬레이터 회색
        ESCALATOR_GREEN = (100, 200, 150)  # 에스컬레이터 녹색 레일

        cam_x, cam_y = self.camera_offset

        # 1. 배경 채우기
        screen.fill(BG_DARK)

        # 2. 사이버펑크 바닥 그리기 (대각선 스트라이프 패턴)
        self._draw_cyberpunk_floor(screen, cam_x, cam_y, FLOOR_PINK, FLOOR_PINK_DARK, FLOOR_STRIPE)

        # 3. 상단 벽 (네온 간판 포함)
        wall_h = int(TILE_SIZE * 5)  # 벽 높이
        wall_rect = pygame.Rect(-cam_x, -cam_y, self.pixel_width, wall_h)
        pygame.draw.rect(screen, WALL_PURPLE, wall_rect)

        # 4. 네온 간판들 (상단)
        self._draw_neon_signs_gacha(screen, cam_x, cam_y, wall_h, NEON_PINK, NEON_CYAN, NEON_GREEN)

        # 5. 중앙 에스컬레이터
        escalator_x = self.pixel_width // 2 - int(TILE_SIZE * 3)
        escalator_y = wall_h + int(TILE_SIZE * 1)
        escalator_w = int(TILE_SIZE * 6)
        escalator_h = int(TILE_SIZE * 8)
        self._draw_escalator(screen, escalator_x - cam_x, escalator_y - cam_y,
                            escalator_w, escalator_h, ESCALATOR_GRAY, ESCALATOR_GREEN, NEON_CYAN)

        # 6. 좌측 가챠 머신 구역
        left_x = int(TILE_SIZE * 1.5)
        machine_y = wall_h + int(TILE_SIZE * 0.5)
        self._draw_gacha_machine_row(screen, left_x - cam_x, machine_y - cam_y,
                                     3, MACHINE_PURPLE, MACHINE_PINK, NEON_PINK, "left")

        # 7. 우측 가챠 머신 구역
        right_x = self.pixel_width - int(TILE_SIZE * 6)
        self._draw_gacha_machine_row(screen, right_x - cam_x, machine_y - cam_y,
                                     3, MACHINE_PURPLE, MACHINE_PINK, NEON_CYAN, "right")

        # 8. 하단 크레인 게임 / 프라이즈 머신
        prize_y = wall_h + int(TILE_SIZE * 6)
        self._draw_prize_machines(screen, left_x - cam_x, prize_y - cam_y,
                                  int(TILE_SIZE * 4), NEON_YELLOW, NEON_BLUE)
        self._draw_prize_machines(screen, right_x - cam_x, prize_y - cam_y,
                                  int(TILE_SIZE * 4), NEON_GREEN, NEON_PINK)

        # 9. 바닥 네온 라인 장식
        self._draw_floor_neon_lines(screen, cam_x, cam_y, wall_h, NEON_PINK, NEON_CYAN)

        # 10. 천장 네온 튜브
        self._draw_ceiling_neon_tubes(screen, cam_x, cam_y, NEON_PINK, NEON_CYAN)

        # 11. 충돌 영역 설정
        self.shop_obstacle_rects = []
        # 상단 벽
        self.shop_obstacle_rects.append(pygame.Rect(0, 0, self.pixel_width, wall_h))
        # 에스컬레이터
        self.shop_obstacle_rects.append(pygame.Rect(escalator_x, escalator_y, escalator_w, escalator_h))
        # 좌측 가챠 머신들
        self.shop_obstacle_rects.append(pygame.Rect(left_x, machine_y, int(TILE_SIZE * 4.5), int(TILE_SIZE * 4)))
        # 우측 가챠 머신들
        self.shop_obstacle_rects.append(pygame.Rect(right_x, machine_y, int(TILE_SIZE * 4.5), int(TILE_SIZE * 4)))
        # 좌측 프라이즈 머신
        self.shop_obstacle_rects.append(pygame.Rect(left_x, prize_y, int(TILE_SIZE * 4), int(TILE_SIZE * 3)))
        # 우측 프라이즈 머신
        self.shop_obstacle_rects.append(pygame.Rect(right_x, prize_y, int(TILE_SIZE * 4), int(TILE_SIZE * 3)))

        # 12. 문 그리기
        self._draw_door(screen)

        # 13. 가챠 머신 / 크레인 게임 상호작용 힌트 표시
        self._draw_gacha_interact_hint(screen, NEON_PINK, NEON_CYAN)
        self._draw_crane_interact_hint(screen, NEON_YELLOW, NEON_GREEN)

        # ===== 디버그: 상호작용 영역 표시 (숨김) =====
        # cam_x, cam_y = self.camera_offset
        # # 가챠 머신 (빨간색/파란색)
        # for machine_info in self.gacha_machine_rects:
        #     rect = machine_info["rect"]
        #     debug_rect = pygame.Rect(
        #         rect.x - cam_x, rect.y - cam_y,
        #         rect.width, rect.height
        #     )
        #     pygame.draw.rect(screen, (255, 0, 0), debug_rect, 2)
        #     m_rect = machine_info["machine_rect"]
        #     debug_m_rect = pygame.Rect(
        #         m_rect.x - cam_x, m_rect.y - cam_y,
        #         m_rect.width, m_rect.height
        #     )
        #     pygame.draw.rect(screen, (0, 0, 255), debug_m_rect, 2)
        # # 크레인 게임 (노란색/시안색)
        # for crane_info in self.crane_game_rects:
        #     rect = crane_info["rect"]
        #     debug_rect = pygame.Rect(
        #         rect.x - cam_x, rect.y - cam_y,
        #         rect.width, rect.height
        #     )
        #     pygame.draw.rect(screen, (255, 255, 0), debug_rect, 2)
        #     m_rect = crane_info["machine_rect"]
        #     debug_m_rect = pygame.Rect(
        #         m_rect.x - cam_x, m_rect.y - cam_y,
        #         m_rect.width, m_rect.height
        #     )
        #     pygame.draw.rect(screen, (0, 255, 255), debug_m_rect, 2)
        # # 플레이어 위치 (녹색)
        # player_rect = pygame.Rect(
        #     self.player.x - cam_x - 30, self.player.y - cam_y - 30, 60, 60
        # )
        # pygame.draw.rect(screen, (0, 255, 0), player_rect, 2)
        # ===== 디버그 끝 =====

    def _draw_gacha_interact_hint(self, screen, neon_pink, neon_cyan):
        """가챠 머신 근처일 때 상호작용 힌트 표시"""
        if self.nearby_gacha_machine is None:
            return

        # 화면 하단에 힌트 박스 표시
        hint_text = "E / CLICK - 가챠 뽑기"
        pulse = abs(math.sin(self.animation_timer * 4))

        # 힌트 박스 크기 (텍스트가 잘리지 않도록 충분히 넓게)
        box_w = 280
        box_h = 36
        box_x = (SCREEN_WIDTH - box_w) // 2
        box_y = SCREEN_HEIGHT - 80

        # 글로우 효과
        for glow in range(3, 0, -1):
            glow_alpha = int((60 - glow * 15) * pulse)
            glow_surf = pygame.Surface((box_w + glow * 6, box_h + glow * 6), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*neon_pink, glow_alpha),
                           (0, 0, box_w + glow * 6, box_h + glow * 6), border_radius=8)
            screen.blit(glow_surf, (box_x - glow * 3, box_y - glow * 3))

        # 박스 배경
        box_surf = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
        pygame.draw.rect(box_surf, (30, 20, 40, 230), (0, 0, box_w, box_h), border_radius=6)
        screen.blit(box_surf, (box_x, box_y))

        # 테두리
        border_color = (
            int(neon_pink[0] * 0.7 + neon_cyan[0] * 0.3),
            int(neon_pink[1] * 0.7 + neon_cyan[1] * 0.3),
            int(neon_pink[2] * 0.7 + neon_cyan[2] * 0.3),
        )
        pygame.draw.rect(screen, border_color, (box_x, box_y, box_w, box_h), 2, border_radius=6)

        # E 키 아이콘 (좌측)
        key_x = box_x + 12
        key_y = box_y + (box_h - 20) // 2
        key_w = 24
        key_h = 20

        # 키 배경
        pygame.draw.rect(screen, (60, 50, 80), (key_x, key_y, key_w, key_h), border_radius=3)
        pygame.draw.rect(screen, neon_cyan, (key_x, key_y, key_w, key_h), 1, border_radius=3)

        # 마우스 아이콘 (우측)
        mouse_x = box_x + box_w - 32
        mouse_y = box_y + (box_h - 24) // 2
        # 마우스 본체
        pygame.draw.ellipse(screen, (60, 50, 80), (mouse_x, mouse_y, 20, 24))
        pygame.draw.ellipse(screen, neon_cyan, (mouse_x, mouse_y, 20, 24), 1)
        # 클릭 영역 (왼쪽 버튼 강조)
        pygame.draw.rect(screen, neon_pink, (mouse_x + 2, mouse_y + 2, 7, 8), border_radius=2)

        # 텍스트 (아이콘 사이에 배치)
        if self.fonts:
            font = self.fonts.get("small") or self.fonts.get("main")
            if font:
                text_color = (255, 255, 255)
                text_surf, text_rect = font.render(hint_text, text_color)
                # 텍스트를 아이콘 사이 중앙에 배치
                text_area_start = key_x + key_w + 10
                text_area_end = mouse_x - 10
                text_x = text_area_start + (text_area_end - text_area_start - text_rect.width) // 2
                text_y = box_y + (box_h - text_rect.height) // 2
                screen.blit(text_surf, (text_x, text_y))

    def _draw_crane_interact_hint(self, screen, neon_yellow, neon_green):
        """크레인 게임 근처일 때 상호작용 힌트 표시"""
        if self.nearby_crane_game is None:
            return

        # 가챠 힌트가 이미 표시 중이면 표시 안함 (겹침 방지)
        if self.nearby_gacha_machine is not None:
            return

        # 화면 하단에 힌트 박스 표시
        hint_text = "E / CLICK - 인형뽑기"
        pulse = abs(math.sin(self.animation_timer * 4))

        # 힌트 박스 크기 (텍스트가 잘리지 않도록 충분히 넓게)
        box_w = 280
        box_h = 36
        box_x = (SCREEN_WIDTH - box_w) // 2
        box_y = SCREEN_HEIGHT - 80

        # 글로우 효과
        for glow in range(3, 0, -1):
            glow_alpha = int((60 - glow * 15) * pulse)
            glow_surf = pygame.Surface((box_w + glow * 6, box_h + glow * 6), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*neon_yellow, glow_alpha),
                           (0, 0, box_w + glow * 6, box_h + glow * 6), border_radius=8)
            screen.blit(glow_surf, (box_x - glow * 3, box_y - glow * 3))

        # 박스 배경
        box_surf = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
        pygame.draw.rect(box_surf, (30, 35, 20, 230), (0, 0, box_w, box_h), border_radius=6)
        screen.blit(box_surf, (box_x, box_y))

        # 테두리
        border_color = (
            int(neon_yellow[0] * 0.7 + neon_green[0] * 0.3),
            int(neon_yellow[1] * 0.7 + neon_green[1] * 0.3),
            int(neon_yellow[2] * 0.7 + neon_green[2] * 0.3),
        )
        pygame.draw.rect(screen, border_color, (box_x, box_y, box_w, box_h), 2, border_radius=6)

        # E 키 아이콘 (좌측)
        key_x = box_x + 12
        key_y = box_y + (box_h - 20) // 2
        key_w = 24
        key_h = 20

        # 키 배경
        pygame.draw.rect(screen, (60, 60, 40), (key_x, key_y, key_w, key_h), border_radius=3)
        pygame.draw.rect(screen, neon_green, (key_x, key_y, key_w, key_h), 1, border_radius=3)

        # 마우스 아이콘 (우측)
        mouse_x = box_x + box_w - 32
        mouse_y = box_y + (box_h - 24) // 2
        # 마우스 본체
        pygame.draw.ellipse(screen, (60, 60, 40), (mouse_x, mouse_y, 20, 24))
        pygame.draw.ellipse(screen, neon_green, (mouse_x, mouse_y, 20, 24), 1)
        # 클릭 영역 (왼쪽 버튼 강조)
        pygame.draw.rect(screen, neon_yellow, (mouse_x + 2, mouse_y + 2, 7, 8), border_radius=2)

        # 텍스트 (아이콘 사이에 배치)
        if self.fonts:
            font = self.fonts.get("small") or self.fonts.get("main")
            if font:
                text_color = (255, 255, 255)
                text_surf, text_rect = font.render(hint_text, text_color)
                # 텍스트를 아이콘 사이 중앙에 배치
                text_area_start = key_x + key_w + 10
                text_area_end = mouse_x - 10
                text_x = text_area_start + (text_area_end - text_area_start - text_rect.width) // 2
                text_y = box_y + (box_h - text_rect.height) // 2
                screen.blit(text_surf, (text_x, text_y))

    def _draw_cyberpunk_floor(self, screen, cam_x, cam_y, floor_color, floor_dark, stripe_color):
        """사이버펑크 바닥 그리기 (대각선 스트라이프 + 네온 라인)"""
        tile_w = TILE_SIZE
        tile_h = TILE_SIZE

        start_x = max(0, int(cam_x // tile_w) - 1)
        start_y = max(0, int(cam_y // tile_h) - 1)
        end_x = min(self.map_width + 2, start_x + SCREEN_WIDTH // tile_w + 3)
        end_y = min(self.map_height + 2, start_y + SCREEN_HEIGHT // tile_h + 3)

        for ty in range(start_y, end_y):
            for tx in range(start_x, end_x):
                tile_x = tx * tile_w - cam_x
                tile_y = ty * tile_h - cam_y

                # 대각선 스트라이프 패턴
                if (tx + ty) % 4 < 2:
                    color = floor_color
                else:
                    color = floor_dark
                pygame.draw.rect(screen, color, (tile_x, tile_y, tile_w, tile_h))

                # 스트라이프 라인 (대각선)
                if (tx + ty) % 4 == 0:
                    pygame.draw.line(screen, stripe_color,
                                   (tile_x, tile_y),
                                   (tile_x + tile_w, tile_y + tile_h), 2)
                    pygame.draw.line(screen, stripe_color,
                                   (tile_x + tile_w, tile_y),
                                   (tile_x, tile_y + tile_h), 2)

    def _draw_neon_signs_gacha(self, screen, cam_x, cam_y, wall_h, neon_pink, neon_cyan, neon_green):
        """네온 간판들 그리기 (일본어 스타일)"""
        center_x = self.pixel_width // 2

        # 좌측 간판 "龍城" 스타일
        sign1_x = center_x - 200 - cam_x
        sign1_y = 20 - cam_y
        self._draw_neon_sign_box(screen, sign1_x, sign1_y, 60, 40, neon_cyan, "龍城")

        # 중앙 간판들
        sign2_x = center_x - 80 - cam_x
        self._draw_neon_sign_box(screen, sign2_x, sign1_y, 50, 35, (255, 255, 100), "天岩")

        sign3_x = center_x - 20 - cam_x
        self._draw_neon_sign_box(screen, sign3_x, sign1_y, 50, 35, neon_pink, "ラヂ")

        # 우측 대형 간판 "ブタケコン" 스타일
        sign4_x = center_x + 80 - cam_x
        sign4_y = 15 - cam_y
        self._draw_neon_sign_large(screen, sign4_x, sign4_y, 120, 50, neon_cyan, "スターガチャ")

        # 중간 행 - 작은 간판들
        row2_y = 70 - cam_y

        # 유리 진열장 간판들
        for i, offset in enumerate([-180, -120, -60, 0, 60, 120, 180]):
            sign_x = center_x + offset - cam_x
            colors = [neon_pink, neon_cyan, neon_green, (255, 200, 100), neon_pink, neon_cyan, neon_green]
            self._draw_small_display_case(screen, sign_x, row2_y, colors[i % len(colors)])

        # 화면/모니터 디스플레이 (우측 상단)
        monitor_x = self.pixel_width - 120 - cam_x
        monitor_y = 30 - cam_y
        self._draw_monitor_display(screen, monitor_x, monitor_y, 90, 60, neon_cyan)

    def _draw_neon_sign_box(self, screen, x, y, w, h, color, text=""):
        """네온 사인 박스 그리기"""
        # 배경 박스
        bg_color = (30, 20, 40)
        pygame.draw.rect(screen, bg_color, (x, y, w, h), border_radius=5)

        # 네온 테두리 글로우
        glow_pulse = abs(math.sin(self.animation_timer * 3))
        for offset in range(3):
            alpha = int((80 - offset * 25) * glow_pulse)
            glow_surf = pygame.Surface((w + offset * 4, h + offset * 4), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*color, alpha), (0, 0, w + offset * 4, h + offset * 4), 2, border_radius=5)
            screen.blit(glow_surf, (x - offset * 2, y - offset * 2))

        # 테두리
        pygame.draw.rect(screen, color, (x, y, w, h), 2, border_radius=5)

        # 텍스트 (간단한 사각형으로 대체 - 실제로는 폰트 필요)
        if text:
            text_w = min(w - 10, len(text) * 10)
            text_h = h - 15
            text_x = x + (w - text_w) // 2
            text_y = y + (h - text_h) // 2
            pygame.draw.rect(screen, color, (text_x, text_y, text_w, text_h), border_radius=2)

    def _draw_neon_sign_large(self, screen, x, y, w, h, color, text=""):
        """대형 네온 사인 그리기"""
        # 배경
        bg_color = (20, 15, 30)
        pygame.draw.rect(screen, bg_color, (x, y, w, h), border_radius=8)

        # 이중 테두리 글로우
        glow_pulse = abs(math.sin(self.animation_timer * 2.5))
        for offset in range(4):
            alpha = int((100 - offset * 20) * glow_pulse)
            glow_surf = pygame.Surface((w + offset * 6, h + offset * 6), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*color, alpha), (0, 0, w + offset * 6, h + offset * 6), 3, border_radius=8)
            screen.blit(glow_surf, (x - offset * 3, y - offset * 3))

        # 내부 패널
        inner_margin = 8
        pygame.draw.rect(screen, (40, 30, 60), (x + inner_margin, y + inner_margin,
                                                 w - inner_margin * 2, h - inner_margin * 2), border_radius=4)
        pygame.draw.rect(screen, color, (x + inner_margin, y + inner_margin,
                                         w - inner_margin * 2, h - inner_margin * 2), 2, border_radius=4)

    def _draw_small_display_case(self, screen, x, y, color):
        """작은 유리 진열장 그리기"""
        case_w, case_h = 35, 50

        # 케이스 프레임
        pygame.draw.rect(screen, (60, 50, 80), (x, y, case_w, case_h), border_radius=3)
        pygame.draw.rect(screen, color, (x, y, case_w, case_h), 2, border_radius=3)

        # 유리 부분 (반투명)
        glass_surf = pygame.Surface((case_w - 6, case_h - 12), pygame.SRCALPHA)
        glass_surf.fill((100, 150, 200, 60))
        screen.blit(glass_surf, (x + 3, y + 3))

        # 내부 캐릭터/아이템 실루엣
        item_y = y + case_h // 2
        item_colors = [(255, 150, 200), (150, 200, 255), (200, 255, 150), (255, 200, 150)]
        item_color = item_colors[int(x) % len(item_colors)]

        # 귀여운 캐릭터 실루엣 (머리 + 몸)
        head_y = item_y - 8
        pygame.draw.circle(screen, item_color, (x + case_w // 2, head_y), 8)
        pygame.draw.ellipse(screen, item_color, (x + case_w // 2 - 6, head_y + 6, 12, 15))

        # 케이스 하단 선반 장식
        shelf_y = y + case_h - 8
        pygame.draw.rect(screen, (80, 70, 100), (x + 2, shelf_y, case_w - 4, 6))

    def _draw_monitor_display(self, screen, x, y, w, h, color):
        """모니터/화면 디스플레이 그리기"""
        # float을 int로 변환
        x, y, w, h = int(x), int(y), int(w), int(h)

        # 모니터 프레임
        frame_color = (50, 45, 70)
        pygame.draw.rect(screen, frame_color, (x, y, w, h), border_radius=5)
        pygame.draw.rect(screen, (80, 70, 100), (x, y, w, h), 3, border_radius=5)

        # 화면 (내부)
        screen_margin = 6
        screen_rect = (x + screen_margin, y + screen_margin,
                      w - screen_margin * 2, h - screen_margin * 2)

        # 화면 배경 (어두운 청록)
        pygame.draw.rect(screen, (20, 40, 50), screen_rect, border_radius=3)

        # 화면에 캐릭터들 표시 (작은 픽셀 캐릭터)
        char_colors = [(255, 150, 200), (150, 255, 200), (200, 150, 255), (255, 200, 150)]
        char_x_start = x + screen_margin + 10
        char_y = y + screen_margin + h // 2 - 10

        for i in range(4):
            char_x = char_x_start + i * 18
            # 머리
            pygame.draw.circle(screen, char_colors[i], (int(char_x), int(char_y - 5)), 5)
            # 몸
            pygame.draw.rect(screen, char_colors[i], (int(char_x - 4), int(char_y), 8, 10))

        # 스캔라인 효과
        for scan_y in range(y + screen_margin, y + h - screen_margin, 4):
            alpha = 30
            scan_surf = pygame.Surface((w - screen_margin * 2, 1), pygame.SRCALPHA)
            scan_surf.fill((0, 0, 0, alpha))
            screen.blit(scan_surf, (x + screen_margin, scan_y))

    def _draw_escalator(self, screen, x, y, w, h, gray_color, rail_color, accent_color):
        """에스컬레이터 그리기"""
        # 에스컬레이터 베이스
        pygame.draw.rect(screen, gray_color, (x, y, w, h))

        # 좌우 레일 (녹색 발광)
        rail_w = 15
        # 좌측 레일
        pygame.draw.rect(screen, rail_color, (x, y, rail_w, h))
        # 우측 레일
        pygame.draw.rect(screen, rail_color, (x + w - rail_w, y, rail_w, h))

        # 레일 네온 글로우
        glow_pulse = abs(math.sin(self.animation_timer * 2))
        for offset in range(2):
            alpha = int((60 - offset * 25) * glow_pulse)
            # 좌측
            glow_surf = pygame.Surface((rail_w + 4, h + 4), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*rail_color, alpha), (0, 0, rail_w + 4, h + 4))
            screen.blit(glow_surf, (x - 2, y - 2))
            # 우측
            screen.blit(glow_surf, (x + w - rail_w - 2, y - 2))

        # 계단 (애니메이션)
        step_count = int(h / 20)
        step_h = h / step_count
        step_offset = (self.animation_timer * 30) % step_h  # 계단 이동 애니메이션

        for i in range(step_count + 1):
            step_y = y + i * step_h - step_offset
            if y <= step_y < y + h:
                # 계단 면
                step_color = (100, 90, 120) if i % 2 == 0 else (90, 80, 110)
                pygame.draw.rect(screen, step_color, (x + rail_w + 5, step_y, w - rail_w * 2 - 10, step_h - 2))

                # 계단 라인
                pygame.draw.line(screen, (70, 65, 90),
                               (x + rail_w + 5, step_y),
                               (x + w - rail_w - 5, step_y), 1)

        # 상단/하단 플랫폼
        platform_h = 25
        # 상단
        pygame.draw.rect(screen, (60, 55, 80), (x - 10, y - platform_h, w + 20, platform_h))
        pygame.draw.rect(screen, accent_color, (x - 10, y - platform_h, w + 20, 3))
        # 하단
        pygame.draw.rect(screen, (60, 55, 80), (x - 10, y + h, w + 20, platform_h))
        pygame.draw.rect(screen, accent_color, (x - 10, y + h + platform_h - 3, w + 20, 3))

        # 중앙 핸드레일 분리선
        center_x = x + w // 2
        pygame.draw.line(screen, (50, 45, 70), (center_x, y), (center_x, y + h), 4)

    def _draw_gacha_machine_row(self, screen, x, y, count, machine_color, top_color, accent, side):
        """가챠 머신 한 줄 그리기"""
        machine_w = int(TILE_SIZE * 1.5)
        machine_h = int(TILE_SIZE * 3.5)
        spacing = int(TILE_SIZE * 0.1)

        for i in range(count):
            mx = x + i * (machine_w + spacing)
            self._draw_single_gacha_machine(screen, mx, y, machine_w, machine_h,
                                           machine_color, top_color, accent, i)

    def _draw_single_gacha_machine(self, screen, x, y, w, h, machine_color, top_color, accent, index):
        """단일 가챠 머신 그리기 - 고퀄리티 버전"""
        x, y, w, h = int(x), int(y), int(w), int(h)

        # 머신 본체 (하단) - 3D 효과 추가
        body_h = int(h * 0.4)
        body_y = y + h - body_h

        # 본체 그림자 (깊이감)
        shadow_color = tuple(max(0, c - 50) for c in machine_color)
        pygame.draw.rect(screen, shadow_color, (x + 3, body_y + 3, w, body_h), border_radius=5)

        # 본체 메인
        pygame.draw.rect(screen, machine_color, (x, body_y, w, body_h), border_radius=5)

        # 본체 상단 하이라이트 (입체감)
        highlight_color = tuple(min(255, c + 30) for c in machine_color)
        pygame.draw.rect(screen, highlight_color, (x + 2, body_y + 2, w - 4, 8), border_radius=3)

        # 본체 패널 라인들 (메탈릭 디테일)
        panel_color = tuple(max(0, c - 20) for c in machine_color)
        pygame.draw.line(screen, panel_color, (x + 5, body_y + 12), (x + w - 5, body_y + 12), 1)
        pygame.draw.line(screen, panel_color, (x + 5, body_y + body_h - 15), (x + w - 5, body_y + body_h - 15), 1)

        # 테두리
        pygame.draw.rect(screen, tuple(max(0, c - 40) for c in machine_color), (x, body_y, w, body_h), 2, border_radius=5)

        # ===== 캡슐 돔 (상단) - 더 정교한 유리 효과 =====
        dome_h = int(h * 0.6)
        dome_y = y

        # 돔 베이스 (금속 링)
        ring_h = 8
        ring_color = (120, 100, 140)
        pygame.draw.ellipse(screen, ring_color, (x, dome_y + dome_h - ring_h, w, ring_h * 2))
        pygame.draw.ellipse(screen, tuple(min(255, c + 30) for c in ring_color),
                           (x + 2, dome_y + dome_h - ring_h + 2, w - 4, ring_h), 2)

        # 돔 내부 배경 (어두운 공간)
        pygame.draw.ellipse(screen, (25, 20, 35), (x + 4, dome_y + 4, w - 8, dome_h - 12))

        # 돔 유리 (다층 반투명 효과)
        dome_surf = pygame.Surface((w, dome_h), pygame.SRCALPHA)
        # 외부 유리층
        pygame.draw.ellipse(dome_surf, (80, 120, 180, 40), (2, 2, w - 4, dome_h - 8))
        # 내부 유리층
        pygame.draw.ellipse(dome_surf, (100, 150, 200, 60), (6, 6, w - 12, dome_h - 16))
        screen.blit(dome_surf, (x, dome_y))

        # 돔 반사광 (왼쪽 상단)
        reflect_surf = pygame.Surface((w // 3, dome_h // 3), pygame.SRCALPHA)
        pygame.draw.ellipse(reflect_surf, (255, 255, 255, 60), (0, 0, w // 3, dome_h // 3))
        screen.blit(reflect_surf, (x + 8, dome_y + 8))

        # 돔 테두리 (이중 링)
        pygame.draw.ellipse(screen, top_color, (x + 2, dome_y + 2, w - 4, dome_h - 8), 3)
        pygame.draw.ellipse(screen, tuple(min(255, c + 50) for c in top_color),
                           (x + 4, dome_y + 4, w - 8, dome_h - 12), 1)

        # ===== 캡슐들 (더 디테일한 캡슐) =====
        capsule_colors = [
            (255, 100, 150), (100, 200, 255), (255, 255, 100),
            (150, 255, 150), (255, 150, 100), (200, 150, 255),
            (255, 200, 150), (150, 255, 255)
        ]
        capsule_count = 8
        center_x = x + w // 2
        center_y = dome_y + dome_h // 2 - 5

        for i in range(capsule_count):
            # 다양한 궤도와 속도
            orbit = 0.8 + (i % 3) * 0.15
            speed = 0.8 + (i % 2) * 0.4
            angle = self.animation_timer * speed * (1 + index * 0.15) + i * (math.pi * 2 / capsule_count)

            radius_x = int((w - 24) // 3 * orbit)
            radius_y = int((dome_h - 30) // 3 * orbit * 0.7)
            cx = center_x + math.cos(angle) * radius_x
            cy = center_y + math.sin(angle) * radius_y

            capsule_color = capsule_colors[i % len(capsule_colors)]
            darker_color = tuple(max(0, c - 50) for c in capsule_color)

            # 캡슐 그림자
            pygame.draw.ellipse(screen, (30, 25, 40), (cx - 4, cy - 5, 10, 14))

            # 캡슐 본체 (상하 분리된 캡슐)
            # 상단 반구
            pygame.draw.ellipse(screen, capsule_color, (cx - 5, cy - 7, 10, 8))
            # 하단 반구 (약간 어둡게)
            pygame.draw.ellipse(screen, darker_color, (cx - 5, cy - 1, 10, 8))
            # 중앙 분리선
            pygame.draw.line(screen, tuple(max(0, c - 30) for c in capsule_color),
                           (int(cx - 4), int(cy)), (int(cx + 4), int(cy)), 1)

            # 하이라이트 (반짝임)
            pygame.draw.circle(screen, (255, 255, 255), (int(cx - 2), int(cy - 4)), 2)
            pygame.draw.circle(screen, (255, 255, 255, 150), (int(cx + 1), int(cy - 2)), 1)

        # ===== 배출구 (더 정교한 디자인) =====
        outlet_y = body_y + 12
        outlet_w, outlet_h = 28, 22

        # 배출구 외부 프레임
        pygame.draw.rect(screen, (50, 45, 65), (x + w // 2 - outlet_w // 2 - 2, outlet_y - 2,
                                                 outlet_w + 4, outlet_h + 4), border_radius=6)
        # 배출구 내부 (어두운 구멍)
        pygame.draw.rect(screen, (20, 15, 25), (x + w // 2 - outlet_w // 2, outlet_y,
                                                 outlet_w, outlet_h), border_radius=4)
        # 배출구 테두리 (네온)
        pygame.draw.rect(screen, accent, (x + w // 2 - outlet_w // 2 - 2, outlet_y - 2,
                                          outlet_w + 4, outlet_h + 4), 2, border_radius=6)
        # 내부 그라데이션 효과
        for i in range(3):
            alpha = 40 - i * 12
            inner_surf = pygame.Surface((outlet_w - 4, 3), pygame.SRCALPHA)
            inner_surf.fill((*accent, alpha))
            screen.blit(inner_surf, (x + w // 2 - outlet_w // 2 + 2, outlet_y + 2 + i * 3))

        # ===== 코인 투입구 (디테일 추가) =====
        coin_y = body_y + 42
        coin_w, coin_h = 20, 12

        # 코인 투입구 베이스
        pygame.draw.rect(screen, (60, 55, 75), (x + w // 2 - coin_w // 2 - 2, coin_y - 2,
                                                 coin_w + 4, coin_h + 4), border_radius=4)
        # 슬롯
        pygame.draw.rect(screen, (30, 25, 35), (x + w // 2 - coin_w // 2, coin_y, coin_w, coin_h), border_radius=2)
        # 금색 테두리
        pygame.draw.rect(screen, (220, 190, 100), (x + w // 2 - coin_w // 2, coin_y, coin_w, coin_h), 1, border_radius=2)
        # 코인 아이콘
        pygame.draw.circle(screen, (255, 215, 0), (x + w // 2, coin_y + coin_h // 2), 3)
        pygame.draw.circle(screen, (200, 170, 50), (x + w // 2, coin_y + coin_h // 2), 3, 1)

        # ===== 가격 표시 LED =====
        price_y = body_y + 58
        pygame.draw.rect(screen, (20, 20, 30), (x + w // 2 - 12, price_y, 24, 10), border_radius=2)
        # LED 숫자 효과 (100)
        led_color = (0, 255, 100)
        for i, digit_x in enumerate([x + w // 2 - 8, x + w // 2 - 2, x + w // 2 + 4]):
            pygame.draw.rect(screen, led_color, (digit_x, price_y + 2, 4, 6), border_radius=1)

        # ===== 손잡이 (회전 레버) =====
        handle_x = x + w - 8
        handle_y = body_y + body_h // 2
        handle_angle = self.animation_timer * 0.5 + index

        # 레버 베이스
        pygame.draw.circle(screen, (80, 70, 100), (handle_x, handle_y), 6)
        pygame.draw.circle(screen, (100, 90, 120), (handle_x, handle_y), 4)

        # 레버 암
        lever_len = 12
        lever_end_x = handle_x + math.cos(handle_angle) * lever_len
        lever_end_y = handle_y + math.sin(handle_angle) * lever_len
        pygame.draw.line(screen, (150, 140, 170), (handle_x, handle_y),
                        (int(lever_end_x), int(lever_end_y)), 3)
        # 레버 손잡이 (빨간 공)
        pygame.draw.circle(screen, (255, 80, 80), (int(lever_end_x), int(lever_end_y)), 5)
        pygame.draw.circle(screen, (255, 150, 150), (int(lever_end_x - 1), int(lever_end_y - 1)), 2)

        # ===== 장식 라인 및 라벨 =====
        # 하단 장식 라인 (이중)
        pygame.draw.line(screen, accent, (x + 5, body_y + body_h - 12), (x + w - 5, body_y + body_h - 12), 2)
        pygame.draw.line(screen, tuple(min(255, c + 50) for c in accent),
                        (x + 8, body_y + body_h - 9), (x + w - 8, body_y + body_h - 9), 1)

        # 측면 장식 볼트
        for bolt_y in [body_y + 20, body_y + body_h - 20]:
            pygame.draw.circle(screen, (100, 95, 115), (x + 6, bolt_y), 3)
            pygame.draw.circle(screen, (70, 65, 85), (x + 6, bolt_y), 2)
            pygame.draw.circle(screen, (100, 95, 115), (x + w - 6, bolt_y), 3)
            pygame.draw.circle(screen, (70, 65, 85), (x + w - 6, bolt_y), 2)

        # ===== 네온 글로우 (더 화려하게) =====
        glow_pulse = abs(math.sin(self.animation_timer * 3 + index))
        for offset in range(3):
            alpha = int((70 - offset * 20) * glow_pulse)
            glow_surf = pygame.Surface((w + 12, dome_h + 12), pygame.SRCALPHA)
            pygame.draw.ellipse(glow_surf, (*accent, alpha), (0, 0, w + 12, dome_h + 8), 2)
            screen.blit(glow_surf, (x - 6, dome_y - 4))

        # 상단 스타 라이트
        star_pulse = abs(math.sin(self.animation_timer * 5 + index * 0.7))
        star_x, star_y = x + w // 2, dome_y - 3
        star_size = int(4 + star_pulse * 2)
        self._draw_mini_star(screen, star_x, star_y, star_size, accent)

    def _draw_mini_star(self, screen, x, y, size, color):
        """작은 별 그리기"""
        points = []
        for i in range(10):
            angle = i * math.pi / 5 - math.pi / 2
            r = size if i % 2 == 0 else size * 0.4
            px = x + r * math.cos(angle)
            py = y + r * math.sin(angle)
            points.append((px, py))
        if len(points) >= 3:
            pygame.draw.polygon(screen, color, points)
            pygame.draw.polygon(screen, (255, 255, 255), points, 1)

    def _draw_prize_machines(self, screen, x, y, w, accent1, accent2):
        """프라이즈/크레인 게임 머신들 그리기"""
        machine_w = w // 2 - 5
        machine_h = int(TILE_SIZE * 2.5)

        # 크레인 게임 1
        self._draw_crane_game(screen, x, y, machine_w, machine_h, accent1)

        # 크레인 게임 2
        self._draw_crane_game(screen, x + machine_w + 10, y, machine_w, machine_h, accent2)

    def _draw_crane_game(self, screen, x, y, w, h, accent):
        """단일 크레인 게임 그리기 - 업그레이드 버전"""
        x, y, w, h = int(x), int(y), int(w), int(h)

        # === 3D 그림자 효과 ===
        shadow_offset = 4
        shadow_color = (20, 15, 30)
        pygame.draw.rect(screen, shadow_color,
                        (x + shadow_offset, y + shadow_offset, w, h),
                        border_radius=6)

        # === 본체 (메탈릭 그라데이션) ===
        body_base = (70, 60, 90)
        body_highlight = (90, 80, 120)
        body_dark = (50, 40, 70)

        # 본체 배경
        pygame.draw.rect(screen, body_base, (x, y, w, h), border_radius=6)

        # 상단 하이라이트
        highlight_surf = pygame.Surface((w, h // 4), pygame.SRCALPHA)
        for i in range(h // 4):
            alpha = int(60 * (1 - i / (h // 4)))
            pygame.draw.line(highlight_surf, (*body_highlight, alpha),
                           (0, i), (w, i), 1)
        screen.blit(highlight_surf, (x, y))

        # 본체 테두리 (이중 테두리)
        pygame.draw.rect(screen, body_dark, (x, y, w, h), 3, border_radius=6)
        pygame.draw.rect(screen, accent, (x + 2, y + 2, w - 4, h - 4), 1, border_radius=5)

        # === 상단 장식 프레임 ===
        top_frame_h = 12
        pygame.draw.rect(screen, accent, (x + 3, y + 3, w - 6, top_frame_h), border_radius=3)

        # "CRANE" 텍스트 영역 (LED 스타일)
        text_bg = pygame.Surface((w - 12, top_frame_h - 4), pygame.SRCALPHA)
        pygame.draw.rect(text_bg, (0, 0, 0, 180), (0, 0, w - 12, top_frame_h - 4), border_radius=2)
        screen.blit(text_bg, (x + 6, y + 5))

        # LED 도트 텍스트 (CRANE)
        dot_color = (255, 255, 100)
        dot_start_x = x + 10
        dot_y = y + 8
        # 간단한 도트 패턴
        for i in range(5):
            pygame.draw.circle(screen, dot_color, (dot_start_x + i * 6, dot_y), 2)

        # === 유리 케이스 부분 ===
        glass_margin = 6
        glass_x = x + glass_margin
        glass_y = y + top_frame_h + 5
        glass_w = w - glass_margin * 2
        glass_h = int(h * 0.55)

        # 유리 케이스 배경 (깊이감 있는 내부)
        inner_bg = (20, 15, 35)
        pygame.draw.rect(screen, inner_bg, (glass_x, glass_y, glass_w, glass_h), border_radius=4)

        # 내부 바닥 (인형이 놓이는 곳)
        floor_y = glass_y + glass_h - 15
        floor_color = (40, 35, 55)
        pygame.draw.rect(screen, floor_color, (glass_x + 3, floor_y, glass_w - 6, 12), border_radius=2)

        # 바닥 그리드 패턴
        grid_color = (50, 45, 70)
        for gx in range(glass_x + 8, glass_x + glass_w - 5, 8):
            pygame.draw.line(screen, grid_color, (gx, floor_y + 2), (gx, floor_y + 10), 1)

        # === 인형들 (더 귀엽고 다양하게) ===
        plush_types = [
            {"body": (255, 180, 200), "cheek": (255, 150, 170), "type": "bear"},
            {"body": (180, 200, 255), "cheek": (150, 170, 255), "type": "bunny"},
            {"body": (200, 255, 200), "cheek": (170, 255, 170), "type": "frog"},
            {"body": (255, 255, 180), "cheek": (255, 255, 150), "type": "chick"},
            {"body": (220, 180, 255), "cheek": (200, 150, 255), "type": "cat"},
        ]

        plush_count = 5
        plush_spacing = (glass_w - 20) // plush_count

        for i in range(plush_count):
            plush_info = plush_types[i % len(plush_types)]
            plush_x = glass_x + 12 + i * plush_spacing
            plush_y = floor_y - 5

            body_color = plush_info["body"]
            cheek_color = plush_info["cheek"]
            plush_type = plush_info["type"]

            # 인형 그림자
            pygame.draw.ellipse(screen, (15, 10, 25),
                              (plush_x - 7, plush_y + 2, 14, 5))

            # 인형 몸
            pygame.draw.ellipse(screen, body_color,
                              (plush_x - 6, plush_y - 8, 12, 10))

            # 인형 머리
            head_y = plush_y - 15
            pygame.draw.circle(screen, body_color, (plush_x, head_y), 8)

            # 귀 (타입별로 다르게)
            if plush_type == "bear":
                pygame.draw.circle(screen, body_color, (plush_x - 6, head_y - 6), 4)
                pygame.draw.circle(screen, body_color, (plush_x + 6, head_y - 6), 4)
                pygame.draw.circle(screen, cheek_color, (plush_x - 6, head_y - 6), 2)
                pygame.draw.circle(screen, cheek_color, (plush_x + 6, head_y - 6), 2)
            elif plush_type == "bunny":
                pygame.draw.ellipse(screen, body_color, (plush_x - 5, head_y - 16, 4, 10))
                pygame.draw.ellipse(screen, body_color, (plush_x + 1, head_y - 16, 4, 10))
                pygame.draw.ellipse(screen, cheek_color, (plush_x - 4, head_y - 14, 2, 6))
                pygame.draw.ellipse(screen, cheek_color, (plush_x + 2, head_y - 14, 2, 6))
            elif plush_type == "cat":
                pygame.draw.polygon(screen, body_color, [
                    (plush_x - 7, head_y - 4), (plush_x - 5, head_y - 10), (plush_x - 2, head_y - 4)
                ])
                pygame.draw.polygon(screen, body_color, [
                    (plush_x + 2, head_y - 4), (plush_x + 5, head_y - 10), (plush_x + 7, head_y - 4)
                ])

            # 볼터치
            pygame.draw.circle(screen, cheek_color, (plush_x - 4, head_y + 2), 2)
            pygame.draw.circle(screen, cheek_color, (plush_x + 4, head_y + 2), 2)

            # 눈 (반짝이는 효과)
            pygame.draw.circle(screen, (30, 30, 30), (plush_x - 3, head_y - 1), 2)
            pygame.draw.circle(screen, (30, 30, 30), (plush_x + 3, head_y - 1), 2)
            pygame.draw.circle(screen, (255, 255, 255), (plush_x - 2, head_y - 2), 1)
            pygame.draw.circle(screen, (255, 255, 255), (plush_x + 4, head_y - 2), 1)

            # 입 (미소)
            if plush_type == "frog":
                pygame.draw.arc(screen, (30, 30, 30), (plush_x - 4, head_y - 1, 8, 6),
                              3.14, 0, 1)
            else:
                pygame.draw.circle(screen, (30, 30, 30), (plush_x, head_y + 3), 1)

        # === 크레인 시스템 ===
        crane_track_y = glass_y + 8
        crane_track_color = (100, 95, 120)

        # 크레인 레일
        pygame.draw.rect(screen, crane_track_color,
                        (glass_x + 5, crane_track_y, glass_w - 10, 4), border_radius=2)
        pygame.draw.rect(screen, (60, 55, 80),
                        (glass_x + 5, crane_track_y, glass_w - 10, 4), 1, border_radius=2)

        # 크레인 위치 (애니메이션)
        crane_offset = int(15 * math.sin(self.animation_timer * 1.5))
        crane_x = x + w // 2 + crane_offset

        # 크레인 캐리지
        carriage_w = 16
        carriage_h = 8
        pygame.draw.rect(screen, (150, 145, 170),
                        (crane_x - carriage_w // 2, crane_track_y - 2, carriage_w, carriage_h),
                        border_radius=2)

        # 크레인 로프
        rope_length = 20 + int(5 * abs(math.sin(self.animation_timer * 3)))
        rope_end_y = crane_track_y + carriage_h + rope_length
        pygame.draw.line(screen, (180, 175, 200),
                        (crane_x, crane_track_y + carriage_h),
                        (crane_x, rope_end_y), 2)

        # 크레인 집게 (더 디테일하게)
        claw_color = (200, 195, 220)
        claw_w = 12
        claw_open = 3 + int(2 * abs(math.sin(self.animation_timer * 4)))

        # 집게 본체
        pygame.draw.rect(screen, claw_color,
                        (crane_x - 4, rope_end_y, 8, 6), border_radius=1)

        # 왼쪽 집게
        pygame.draw.polygon(screen, claw_color, [
            (crane_x - 4, rope_end_y + 4),
            (crane_x - 4 - claw_open, rope_end_y + 12),
            (crane_x - 2, rope_end_y + 10),
        ])

        # 오른쪽 집게
        pygame.draw.polygon(screen, claw_color, [
            (crane_x + 4, rope_end_y + 4),
            (crane_x + 4 + claw_open, rope_end_y + 12),
            (crane_x + 2, rope_end_y + 10),
        ])

        # === 유리 반사 효과 ===
        glass_surf = pygame.Surface((glass_w, glass_h), pygame.SRCALPHA)

        # 반투명 유리 색상
        pygame.draw.rect(glass_surf, (100, 150, 200, 25), (0, 0, glass_w, glass_h), border_radius=4)

        # 광택 하이라이트 (대각선)
        for i in range(0, glass_w, 20):
            pygame.draw.line(glass_surf, (255, 255, 255, 30),
                           (i, 0), (i + 15, glass_h), 2)

        # 좌상단 광택
        pygame.draw.ellipse(glass_surf, (255, 255, 255, 40),
                           (5, 5, 20, 10))

        screen.blit(glass_surf, (glass_x, glass_y))

        # 유리 테두리 (이중)
        pygame.draw.rect(screen, (40, 35, 60), (glass_x, glass_y, glass_w, glass_h), 2, border_radius=4)
        pygame.draw.rect(screen, accent, (glass_x + 1, glass_y + 1, glass_w - 2, glass_h - 2), 1, border_radius=3)

        # === 하단 컨트롤 패널 ===
        panel_y = int(glass_y + glass_h + 5)
        panel_h = int(h - (panel_y - y) - 8)

        # 패널 배경 (그라데이션)
        panel_base = (55, 50, 75)
        panel_highlight = (70, 65, 95)
        pygame.draw.rect(screen, panel_base, (x + 4, panel_y, w - 8, panel_h), border_radius=4)

        # 패널 상단 하이라이트
        pygame.draw.rect(screen, panel_highlight, (x + 4, panel_y, w - 8, 4), border_radius=2)

        # 패널 테두리
        pygame.draw.rect(screen, (40, 35, 55), (x + 4, panel_y, w - 8, panel_h), 1, border_radius=4)

        # === 조이스틱 (더 3D로) ===
        joy_x = x + w // 3
        joy_y = panel_y + panel_h // 2

        # 조이스틱 베이스
        pygame.draw.circle(screen, (40, 35, 55), (joy_x, joy_y), 12)
        pygame.draw.circle(screen, (60, 55, 80), (joy_x, joy_y), 10)

        # 조이스틱 스틱 (기울어진 상태)
        stick_tilt_x = int(3 * math.sin(self.animation_timer * 2))
        stick_tilt_y = int(2 * math.cos(self.animation_timer * 2))

        pygame.draw.line(screen, (100, 95, 120),
                        (joy_x, joy_y),
                        (joy_x + stick_tilt_x, joy_y - 10 + stick_tilt_y), 4)

        # 조이스틱 볼
        pygame.draw.circle(screen, accent, (joy_x + stick_tilt_x, joy_y - 12 + stick_tilt_y), 6)
        pygame.draw.circle(screen, (255, 255, 255, 100),
                          (joy_x + stick_tilt_x - 2, joy_y - 14 + stick_tilt_y), 2)

        # === 버튼 (빛나는 효과) ===
        btn_x = int(x + w * 2 // 3)

        # 버튼 베이스
        pygame.draw.circle(screen, (40, 35, 55), (btn_x, joy_y), 12)

        # 버튼 (펄스 효과)
        pulse = abs(math.sin(self.animation_timer * 4))
        btn_color_r = int(200 + 55 * pulse)
        btn_color = (btn_color_r, 60, 60)

        pygame.draw.circle(screen, btn_color, (btn_x, joy_y), 10)
        pygame.draw.circle(screen, (255, 120, 120), (btn_x, joy_y), 7)

        # 버튼 광택
        pygame.draw.circle(screen, (255, 200, 200), (btn_x - 2, joy_y - 3), 3)

        # === 코인 투입구 ===
        coin_x = x + w - 20
        coin_y = panel_y + 8

        # 투입구 베이스
        pygame.draw.rect(screen, (40, 35, 55), (coin_x - 8, coin_y, 16, 20), border_radius=2)
        pygame.draw.rect(screen, (80, 75, 100), (coin_x - 6, coin_y + 2, 12, 16), border_radius=1)

        # 투입구 슬롯
        pygame.draw.rect(screen, (25, 20, 35), (coin_x - 4, coin_y + 6, 8, 3), border_radius=1)

        # 가격 표시 LED
        price_y = coin_y + 22
        pygame.draw.rect(screen, (0, 0, 0), (coin_x - 10, price_y, 20, 10), border_radius=2)

        # LED 숫자 "100"
        led_color = (0, 255, 100)
        for i, char in enumerate("100"):
            char_x = coin_x - 8 + i * 6
            pygame.draw.circle(screen, led_color, (char_x + 2, price_y + 5), 1)

        # === 출구 슬롯 ===
        exit_y = panel_y + panel_h - 15
        exit_w = w // 3
        exit_x = x + (w - exit_w) // 2

        # 출구 배경
        pygame.draw.rect(screen, (20, 15, 30), (exit_x, exit_y, exit_w, 12), border_radius=3)
        pygame.draw.rect(screen, (60, 55, 80), (exit_x, exit_y, exit_w, 12), 1, border_radius=3)

        # 출구 라벨 (작은 점들)
        for i in range(3):
            pygame.draw.circle(screen, accent, (exit_x + 8 + i * 8, exit_y + 6), 2)

        # === 모서리 장식 볼트 ===
        bolt_color = (120, 115, 140)
        bolt_positions = [
            (x + 8, y + 8),
            (x + w - 8, y + 8),
            (x + 8, y + h - 8),
            (x + w - 8, y + h - 8),
        ]
        for bx, by in bolt_positions:
            pygame.draw.circle(screen, bolt_color, (bx, by), 3)
            pygame.draw.circle(screen, (80, 75, 100), (bx, by), 2)
            # 볼트 십자
            pygame.draw.line(screen, (60, 55, 80), (bx - 1, by), (bx + 1, by), 1)
            pygame.draw.line(screen, (60, 55, 80), (bx, by - 1), (bx, by + 1), 1)

    def _draw_floor_neon_lines(self, screen, cam_x, cam_y, wall_h, neon_pink, neon_cyan):
        """바닥 네온 라인 장식 그리기 - 업그레이드 버전"""
        floor_y = wall_h + int(TILE_SIZE * 10)  # 바닥 영역

        # === 가로 네온 라인들 (더 많고 복잡하게) ===
        line_spacing = TILE_SIZE * 3
        for i in range(5):
            line_y = floor_y + i * line_spacing - cam_y

            # 펄스 애니메이션 (시간차 적용)
            glow_pulse = abs(math.sin(self.animation_timer * 2.5 + i * 0.7))

            # 메인 라인
            color = neon_pink if i % 2 == 0 else neon_cyan
            line_h = 3 + int(2 * glow_pulse)

            # 외부 글로우 (넓은 범위)
            for glow_layer in range(3):
                glow_alpha = int((60 - glow_layer * 18) * glow_pulse)
                glow_h = line_h + (glow_layer + 1) * 4
                glow_surf = pygame.Surface((self.pixel_width, glow_h), pygame.SRCALPHA)
                pygame.draw.rect(glow_surf, (*color, glow_alpha), (0, 0, self.pixel_width, glow_h))
                screen.blit(glow_surf, (-cam_x, line_y - glow_layer * 2))

            # 코어 라인 (밝은 중심)
            core_alpha = int(180 + 75 * glow_pulse)
            line_surf = pygame.Surface((self.pixel_width, line_h), pygame.SRCALPHA)
            pygame.draw.rect(line_surf, (*color, min(255, core_alpha)), (0, 0, self.pixel_width, line_h))
            screen.blit(line_surf, (-cam_x, line_y))

            # 중심 하이라이트 (흰색)
            highlight_surf = pygame.Surface((self.pixel_width, 1), pygame.SRCALPHA)
            highlight_alpha = int(100 * glow_pulse)
            pygame.draw.rect(highlight_surf, (255, 255, 255, highlight_alpha), (0, 0, self.pixel_width, 1))
            screen.blit(highlight_surf, (-cam_x, line_y + line_h // 2))

        # === 세로 네온 라인 (교차 그리드) ===
        v_line_spacing = TILE_SIZE * 4
        for j in range(int(self.pixel_width // v_line_spacing) + 1):
            line_x = j * v_line_spacing - cam_x

            # 교차 색상 (가로와 반대)
            color = neon_cyan if j % 2 == 0 else neon_pink
            pulse = abs(math.sin(self.animation_timer * 2 + j * 0.5))

            # 세로 라인 (짧은 세그먼트로)
            for seg in range(5):
                seg_y = floor_y + seg * line_spacing - cam_y
                seg_h = line_spacing - 10

                # 글로우
                for glow in range(2):
                    glow_alpha = int((40 - glow * 15) * pulse)
                    glow_w = 3 + glow * 2
                    glow_surf = pygame.Surface((glow_w, seg_h), pygame.SRCALPHA)
                    pygame.draw.rect(glow_surf, (*color, glow_alpha), (0, 0, glow_w, seg_h))
                    screen.blit(glow_surf, (line_x - glow, seg_y))

                # 코어
                core_surf = pygame.Surface((2, seg_h), pygame.SRCALPHA)
                core_alpha = int(120 * pulse)
                pygame.draw.rect(core_surf, (*color, core_alpha), (0, 0, 2, seg_h))
                screen.blit(core_surf, (line_x, seg_y))

        # === 교차점 발광 노드 ===
        for i in range(5):
            for j in range(int(self.pixel_width // v_line_spacing) + 1):
                node_x = j * v_line_spacing - cam_x
                node_y = floor_y + i * line_spacing - cam_y

                # 노드 펄스 (교차하는 색상 혼합)
                pulse = abs(math.sin(self.animation_timer * 3 + i * 0.5 + j * 0.3))

                # 글로우 원
                for radius in range(3, 0, -1):
                    glow_alpha = int((80 - (3 - radius) * 25) * pulse)
                    node_surf = pygame.Surface((radius * 6, radius * 6), pygame.SRCALPHA)
                    # 색상 혼합 (핑크 + 시안 = 흰색 계열)
                    blend_color = (
                        min(255, neon_pink[0] // 2 + neon_cyan[0] // 2),
                        min(255, neon_pink[1] // 2 + neon_cyan[1] // 2),
                        min(255, neon_pink[2] // 2 + neon_cyan[2] // 2),
                    )
                    pygame.draw.circle(node_surf, (*blend_color, glow_alpha),
                                      (radius * 3, radius * 3), radius * 3)
                    screen.blit(node_surf, (node_x - radius * 3, node_y - radius * 3))

    def _draw_ceiling_neon_tubes(self, screen, cam_x, cam_y, neon_pink, neon_cyan):
        """천장 네온 튜브 그리기 - 업그레이드 버전"""
        tube_y = -cam_y - 5
        tube_h = 10
        tube_spacing = TILE_SIZE * 3

        for i in range(int(self.pixel_width // tube_spacing) + 1):
            tube_x = i * tube_spacing - cam_x
            tube_w = tube_spacing - 25

            # 교차 색상
            color = neon_pink if i % 2 == 0 else neon_cyan

            # 펄스 애니메이션
            glow_pulse = abs(math.sin(self.animation_timer * 4 + i * 0.4))
            flicker = 0.8 + 0.2 * abs(math.sin(self.animation_timer * 15 + i * 2.1))

            # === 외부 대형 글로우 (분위기 조명) ===
            for glow_layer in range(4):
                glow_expand = (glow_layer + 1) * 6
                glow_alpha = int((50 - glow_layer * 12) * glow_pulse * flicker)
                glow_surf = pygame.Surface((tube_w + glow_expand * 2, tube_h + glow_expand * 2), pygame.SRCALPHA)
                pygame.draw.rect(glow_surf, (*color, glow_alpha),
                               (0, 0, tube_w + glow_expand * 2, tube_h + glow_expand * 2),
                               border_radius=6)
                screen.blit(glow_surf, (tube_x - glow_expand, tube_y - glow_expand))

            # === 튜브 마운트 (금속 고정 장치) ===
            mount_color = (80, 75, 100)
            mount_w = 8
            mount_h = tube_h + 6
            # 왼쪽 마운트
            pygame.draw.rect(screen, mount_color, (tube_x - 2, tube_y - 3, mount_w, mount_h), border_radius=2)
            pygame.draw.rect(screen, (100, 95, 120), (tube_x, tube_y - 1, mount_w - 4, mount_h - 4), border_radius=1)
            # 오른쪽 마운트
            pygame.draw.rect(screen, mount_color, (tube_x + tube_w - mount_w + 2, tube_y - 3, mount_w, mount_h), border_radius=2)
            pygame.draw.rect(screen, (100, 95, 120), (tube_x + tube_w - mount_w + 4, tube_y - 1, mount_w - 4, mount_h - 4), border_radius=1)

            # === 튜브 본체 (유리관 효과) ===
            # 어두운 배경 (튜브 내부)
            pygame.draw.rect(screen, (20, 15, 30), (tube_x + 5, tube_y, tube_w - 10, tube_h), border_radius=4)

            # 빛나는 가스 (코어)
            core_brightness = int(200 + 55 * glow_pulse * flicker)
            bright_color = (
                min(255, color[0] + 30),
                min(255, color[1] + 30),
                min(255, color[2] + 30),
            )
            pygame.draw.rect(screen, bright_color, (tube_x + 7, tube_y + 2, tube_w - 14, tube_h - 4), border_radius=3)

            # 중심 하이라이트 (가장 밝은 부분)
            highlight_alpha = int(180 * glow_pulse * flicker)
            highlight_surf = pygame.Surface((tube_w - 18, 3), pygame.SRCALPHA)
            pygame.draw.rect(highlight_surf, (255, 255, 255, highlight_alpha), (0, 0, tube_w - 18, 3), border_radius=1)
            screen.blit(highlight_surf, (tube_x + 9, tube_y + tube_h // 2 - 1))

            # 유리관 테두리 (반투명)
            glass_surf = pygame.Surface((tube_w - 10, tube_h), pygame.SRCALPHA)
            pygame.draw.rect(glass_surf, (200, 220, 255, 40), (0, 0, tube_w - 10, tube_h), border_radius=4)
            pygame.draw.rect(glass_surf, (255, 255, 255, 60), (0, 0, tube_w - 10, tube_h), 1, border_radius=4)
            screen.blit(glass_surf, (tube_x + 5, tube_y))

            # === 광선 효과 (아래로 내려오는 빛) ===
            ray_count = 3
            for r in range(ray_count):
                ray_x = tube_x + 10 + r * (tube_w - 20) // ray_count
                ray_alpha = int(30 * glow_pulse * flicker)
                ray_surf = pygame.Surface((6, 30), pygame.SRCALPHA)

                # 그라데이션 광선
                for ry in range(30):
                    fade = 1 - ry / 30
                    pygame.draw.line(ray_surf, (*color, int(ray_alpha * fade)), (0, ry), (6, ry), 1)

                screen.blit(ray_surf, (ray_x, tube_y + tube_h))

        # === 추가: 중앙 대형 샹들리에 효과 ===
        chandelier_x = self.pixel_width // 2 - cam_x
        chandelier_y = tube_y + 20

        # 대형 글로우 볼
        for glow_r in range(5, 0, -1):
            glow_alpha = int((60 - glow_r * 10) * abs(math.sin(self.animation_timer * 2)))
            glow_size = glow_r * 15
            glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            # 핑크-시안 그라데이션
            blend = (
                int(neon_pink[0] * 0.6 + neon_cyan[0] * 0.4),
                int(neon_pink[1] * 0.6 + neon_cyan[1] * 0.4),
                int(neon_pink[2] * 0.6 + neon_cyan[2] * 0.4),
            )
            pygame.draw.circle(glow_surf, (*blend, glow_alpha), (glow_size, glow_size), glow_size)
            screen.blit(glow_surf, (chandelier_x - glow_size, chandelier_y - glow_size))

        # 샹들리에 중심부
        pygame.draw.circle(screen, (255, 220, 255), (chandelier_x, chandelier_y), 8)
        pygame.draw.circle(screen, (255, 255, 255), (chandelier_x, chandelier_y), 4)

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
