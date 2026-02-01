# -*- coding: utf-8 -*-
"""
콜로세움 영웅 패들 렌더러 - 고퀄리티 버전
스매셔/발토르/코만도 수준의 디테일한 캐릭터 렌더링
"""

import pygame
import math
from typing import Dict, Tuple, Optional


class HeroPaddleRenderer:
    """고퀄리티 영웅 패들 렌더러 - 관절 애니메이션 포함"""

    def __init__(self):
        self.hero_states: Dict[str, dict] = {}
        self.time = 0.0

    def update(self, dt: float):
        """애니메이션 업데이트"""
        self.time += dt

    def update_movement(self, hero_id: str, current_x: float, dt: float):
        """이동 상태 업데이트 - 관절 애니메이션 포함"""
        if hero_id not in self.hero_states:
            self.hero_states[hero_id] = {
                "last_x": current_x,
                "velocity": 0.0,
                "lean": 0.0,
                "step_phase": 0.0,
                "shoulder_phase": 0.0,
                "arm_swing": 0.0,
                "head_tilt": 0.0,
                "body_bob": 0.0,
            }

        state = self.hero_states[hero_id]
        velocity = (current_x - state["last_x"]) / max(dt, 0.001)
        state["velocity"] = velocity * 0.3 + state["velocity"] * 0.7

        # 기울기 (이동 방향)
        target_lean = max(-1.0, min(1.0, state["velocity"] / 250.0))
        state["lean"] = state["lean"] * 0.82 + target_lean * 0.18

        # 걷기 애니메이션 (속도에 비례)
        move_speed = abs(state["velocity"])
        if move_speed > 15:
            state["step_phase"] += dt * 10.0
            state["shoulder_phase"] += dt * 10.0
            # 어깨 들썩임
            state["body_bob"] = math.sin(state["step_phase"] * 2) * min(1.0, move_speed / 200.0)
            # 팔 스윙
            state["arm_swing"] = math.sin(state["step_phase"]) * min(1.0, move_speed / 150.0)
            # 머리 미세 흔들림
            state["head_tilt"] = math.sin(state["step_phase"] * 1.5) * 0.3 * min(1.0, move_speed / 200.0)
        else:
            # 정지 시 부드럽게 감쇠
            state["body_bob"] *= 0.9
            state["arm_swing"] *= 0.9
            state["head_tilt"] *= 0.9

        state["last_x"] = current_x

    def _get_state(self, hero_id: str) -> dict:
        """영웅 상태 가져오기"""
        if hero_id not in self.hero_states:
            self.hero_states[hero_id] = {
                "last_x": 0, "velocity": 0, "lean": 0, "step_phase": 0,
                "shoulder_phase": 0, "arm_swing": 0, "head_tilt": 0, "body_bob": 0
            }
        return self.hero_states[hero_id]

    def _get_anim(self, state: dict) -> dict:
        """애니메이션 값 계산"""
        step = state.get("step_phase", 0)
        lean = state.get("lean", 0)
        arm_swing = state.get("arm_swing", 0)
        body_bob = state.get("body_bob", 0)
        head_tilt = state.get("head_tilt", 0)

        return {
            "wave": math.sin(step),
            "lean": lean,
            "arm_swing": arm_swing,
            "body_bob": body_bob,
            "head_tilt": head_tilt,
            "left_leg": max(0, math.sin(step)) * 0.8,
            "right_leg": max(0, -math.sin(step)) * 0.8,
            "left_shoulder": math.sin(step + 0.5) * 0.5,
            "right_shoulder": math.sin(step - 0.5) * 0.5,
        }

    def draw_hero_paddle(self, screen: pygame.Surface, hero_id: str,
                         x: float, y: float, width: int, height: int,
                         facing: str = "down", color: Tuple[int, int, int] = (200, 200, 200),
                         scale_mode: str = "paddle"):
        """
        영웅 패들 그리기
        facing="down": 정면 (아래를 바라봄, 얼굴이 보임)
        facing="up": 뒷모습 (위를 바라봄, 뒷통수가 보임)
        scale_mode="paddle": 투기장 모드 - 패들 크기에 맞게 캐릭터 축소
        scale_mode="preview": 미리보기 모드 - 기존 크기
        """
        show_back = (facing == "up")
        state = self._get_state(hero_id)
        anim = self._get_anim(state)

        # 스케일 계산 (기본 블록 단위)
        if scale_mode == "paddle":
            # 투기장 모드: 캐릭터가 패들 높이의 3배 정도로 맞춤
            # 캐릭터 전체 높이는 약 8*b, 패들 높이에 맞게 조정
            target_height = height * 3.5  # 패들 위에 적당히 올라온 느낌
            b = max(2, int(target_height / 8))  # 캐릭터 높이 = 약 8*b
        else:
            # 기존 미리보기 모드 (크게 표시)
            b = max(3, width // 12)
        cx, cy = int(x), int(y)

        # 영웅별 그리기
        draw_func = getattr(self, f"_draw_{hero_id}", None)
        if draw_func:
            draw_func(screen, cx, cy, b, color, show_back, anim)
        else:
            self._draw_default(screen, cx, cy, b, color, show_back, anim)

    # =========================================================================
    # 갤리타 - 폭풍의 여전사 (번개창) - 관절 애니메이션 포함
    # =========================================================================
    def _draw_gallita(self, screen, cx, cy, b, color, show_back, anim):
        """갤리타 - 폭풍의 여전사 (관절 애니메이션)"""
        # 애니메이션 값 추출
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        arm_swing_anim = anim["arm_swing"]
        left_leg_lift = anim["left_leg"]
        right_leg_lift = anim["right_leg"]
        left_shoulder = anim["left_shoulder"]
        right_shoulder = anim["right_shoulder"]

        # 기본 위치 계산 (어깨 들썩임 적용)
        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2.5 * b)

        # 색상 팔레트
        p = {
            "hair": (255, 220, 100),
            "hair_dark": (220, 180, 60),
            "skin": (235, 200, 175),
            "armor": color,
            "armor_light": tuple(min(255, c + 40) for c in color),
            "armor_dark": tuple(max(0, c - 40) for c in color),
            "gold": (255, 215, 0),
            "gold_dark": (200, 160, 0),
            "cloth": (40, 60, 40),
            "boot": (100, 80, 60),
            "boot_light": (140, 110, 80),
            "spear": (180, 180, 200),
            "spear_glow": (150, 200, 255),
            "lightning": (200, 230, 255),
        }

        # === 다리 (관절 애니메이션) ===
        hip_y = torso_y + int(2.0 * b)
        thigh_w, thigh_h = int(0.7 * b), int(1.8 * b)
        calf_h = int(1.0 * b)

        for side in [-1, 1]:
            # 좌우 다리 교차 움직임
            leg_lift = left_leg_lift if side == -1 else right_leg_lift
            leg_phase = int(leg_lift * 3 * b)
            leg_swing = int(wave * 2 * side)  # 전후 스윙

            thigh_x = cx + side * int(0.5 * b) + lean_offset - thigh_w // 2 + leg_swing
            thigh_rect = pygame.Rect(thigh_x, hip_y - leg_phase, thigh_w, thigh_h)
            pygame.draw.rect(screen, p["cloth"], thigh_rect, border_radius=2)

            # 무릎 보호대 (관절)
            knee_y = thigh_rect.bottom - int(0.3 * b) + int(leg_lift * 1 * b)
            knee_rect = pygame.Rect(thigh_x - 1, knee_y, thigh_w + 2, int(0.5 * b))
            pygame.draw.rect(screen, p["armor_dark"], knee_rect, border_radius=1)

            # 부츠 (발 각도)
            boot_rect = pygame.Rect(thigh_x - 1, knee_rect.bottom, thigh_w + 2, calf_h)
            pygame.draw.rect(screen, p["boot"], boot_rect, border_radius=2)
            pygame.draw.line(screen, p["boot_light"], (boot_rect.left + 1, boot_rect.centery),
                           (boot_rect.right - 1, boot_rect.centery), 1)

        # === 몸통 (살짝 기울기) ===
        chest_w, chest_h = int(2.8 * b), int(2.0 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.3 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["armor"], chest_rect, border_radius=int(0.4 * b))
        pygame.draw.rect(screen, p["armor_light"], chest_rect.inflate(-int(0.4 * b), -int(0.3 * b)), border_radius=3)

        # 가슴 장식 (금색 라인)
        pygame.draw.line(screen, p["gold"], (chest_rect.centerx, chest_rect.top + 3),
                        (chest_rect.centerx, chest_rect.bottom - 3), 2)

        # 벨트
        belt_rect = pygame.Rect(cx - int(1.4 * b) + lean_offset, chest_rect.bottom - 2, int(2.8 * b), int(0.6 * b))
        pygame.draw.rect(screen, p["gold_dark"], belt_rect, border_radius=2)
        pygame.draw.rect(screen, p["gold"], (belt_rect.centerx - int(0.4 * b), belt_rect.top + 1, int(0.8 * b), belt_rect.height - 2), border_radius=1)

        # === 어깨 갑옷 (들썩임 적용) ===
        for side in [-1, 1]:
            shoulder_bob = (left_shoulder if side == -1 else right_shoulder) * b
            pauldron = [
                (cx + side * int(1.6 * b) + lean_offset, torso_y - int(0.5 * b) + int(shoulder_bob)),
                (cx + side * int(0.9 * b) + lean_offset, torso_y - int(0.8 * b) + int(shoulder_bob * 0.5)),
                (cx + side * int(0.8 * b) + lean_offset, torso_y + int(0.6 * b)),
                (cx + side * int(1.5 * b) + lean_offset, torso_y + int(0.7 * b)),
            ]
            pygame.draw.polygon(screen, p["armor"], pauldron)
            pygame.draw.line(screen, p["gold"], pauldron[0], pauldron[1], 2)

        # === 팔 (자연스러운 스윙) ===
        arm_swing = int(arm_swing_anim * 4 * b)
        for side in [-1, 1]:
            shoulder_y_offset = (left_shoulder if side == -1 else right_shoulder) * b
            shoulder = (cx + side * int(1.3 * b) + lean_offset, torso_y + int(shoulder_y_offset))

            # 팔꿈치 - 반대 방향 스윙
            elbow_swing = arm_swing * side
            elbow = (shoulder[0] + side * int(0.7 * b) + elbow_swing,
                    torso_y + int(0.8 * b) - abs(elbow_swing) // 3)

            # 손목
            wrist = (elbow[0] + side * int(0.5 * b) + elbow_swing // 2,
                    torso_y + int(1.5 * b) - abs(elbow_swing) // 4)

            pygame.draw.line(screen, p["skin"], shoulder, elbow, max(2, int(0.6 * b)))
            pygame.draw.line(screen, p["skin"], elbow, wrist, max(2, int(0.5 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.35 * b)))

        # === 머리 ===
        head_y = torso_y - int(2.8 * b)
        head_w, head_h = int(2.0 * b), int(1.8 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        if show_back:
            # 뒷모습 - 머리카락만
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            pygame.draw.ellipse(screen, p["hair_dark"], head_rect.inflate(-int(0.3 * b), -int(0.2 * b)))
            # 머리카락 뒷부분 디테일
            for i in range(3):
                hx = head_rect.centerx + (i - 1) * int(0.4 * b)
                pygame.draw.line(screen, p["hair_dark"], (hx, head_rect.top + int(0.3 * b)),
                               (hx, head_rect.bottom - int(0.2 * b)), 1)
        else:
            # 정면 - 얼굴
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            # 얼굴
            face_rect = head_rect.inflate(-int(0.4 * b), -int(0.3 * b))
            face_rect.move_ip(0, int(0.2 * b))
            pygame.draw.ellipse(screen, p["skin"], face_rect)
            # 눈
            eye_y = face_rect.centery - int(0.1 * b)
            pygame.draw.circle(screen, (60, 120, 60), (face_rect.centerx - int(0.3 * b), eye_y), max(1, int(0.15 * b)))
            pygame.draw.circle(screen, (60, 120, 60), (face_rect.centerx + int(0.3 * b), eye_y), max(1, int(0.15 * b)))
            # 왕관
            crown_points = [
                (head_rect.left + int(0.2 * b), head_rect.top + int(0.4 * b)),
                (head_rect.centerx - int(0.3 * b), head_rect.top - int(0.2 * b)),
                (head_rect.centerx, head_rect.top + int(0.1 * b)),
                (head_rect.centerx + int(0.3 * b), head_rect.top - int(0.2 * b)),
                (head_rect.right - int(0.2 * b), head_rect.top + int(0.4 * b)),
            ]
            pygame.draw.polygon(screen, p["gold"], crown_points)

        # === 번개창 ===
        spear_x = cx + int(2.5 * b) + lean_offset
        spear_top = head_y - int(1.5 * b)
        spear_bottom = cy + int(2.5 * b)
        pygame.draw.line(screen, p["spear"], (spear_x, spear_top), (spear_x, spear_bottom), max(2, int(0.25 * b)))

        # 창날
        blade_points = [
            (spear_x, spear_top - int(1.0 * b)),
            (spear_x - int(0.4 * b), spear_top),
            (spear_x + int(0.4 * b), spear_top),
        ]
        pygame.draw.polygon(screen, p["spear_glow"], blade_points)
        # 번개 효과
        lightning_offset = int(math.sin(self.time * 10) * 2)
        pygame.draw.line(screen, p["lightning"],
                        (spear_x + lightning_offset, spear_top - int(0.8 * b)),
                        (spear_x - lightning_offset, spear_top - int(0.3 * b)), 1)

    # =========================================================================
    # 아르키네스 - 철벽의 수호자 (대형 방패)
    # =========================================================================
    def _draw_archines(self, screen, cx, cy, b, color, show_back, anim):
        """아르키네스 - 철벽의 수호자"""
        # 애니메이션 값 추출
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        arm_swing_anim = anim["arm_swing"]
        left_leg_lift = anim["left_leg"]
        right_leg_lift = anim["right_leg"]
        left_shoulder = anim["left_shoulder"]
        right_shoulder = anim["right_shoulder"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)
        leg_lift = int(abs(wave) * 1.5)

        p = {
            "helmet": color,
            "helmet_light": tuple(min(255, c + 50) for c in color),
            "helmet_dark": tuple(max(0, c - 50) for c in color),
            "visor": (80, 200, 255),
            "visor_core": (150, 230, 255),
            "armor": tuple(max(0, c - 20) for c in color),
            "armor_light": color,
            "trim": (200, 200, 220),
            "undersuit": (40, 50, 60),
            "shield": (70, 100, 160),
            "shield_light": (100, 140, 200),
            "shield_rim": (180, 190, 210),
            "boot": (60, 70, 90),
        }

        # === 다리 ===
        hip_y = torso_y + int(2.0 * b)
        for side in [-1, 1]:
            leg_phase = leg_lift if side == 1 else -leg_lift // 2
            thigh_x = cx + side * int(0.5 * b) + lean_offset
            # 허벅지
            thigh_rect = pygame.Rect(thigh_x - int(0.4 * b), hip_y + leg_phase, int(0.8 * b), int(1.8 * b))
            pygame.draw.rect(screen, p["undersuit"], thigh_rect, border_radius=3)
            # 무릎
            knee_rect = pygame.Rect(thigh_x - int(0.5 * b), thigh_rect.bottom - int(0.3 * b), int(1.0 * b), int(0.6 * b))
            pygame.draw.rect(screen, p["armor"], knee_rect, border_radius=2)
            pygame.draw.line(screen, p["trim"], (knee_rect.left + 2, knee_rect.centery),
                           (knee_rect.right - 2, knee_rect.centery), 1)
            # 부츠
            boot_rect = pygame.Rect(thigh_x - int(0.45 * b), knee_rect.bottom, int(0.9 * b), int(1.0 * b))
            pygame.draw.rect(screen, p["boot"], boot_rect, border_radius=2)
            pygame.draw.line(screen, p["trim"], (boot_rect.left + 2, boot_rect.top + 2),
                           (boot_rect.right - 2, boot_rect.top + 2), 1)

        # === 몸통 (두꺼운 갑옷) ===
        chest_w, chest_h = int(3.2 * b), int(2.2 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.4 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["armor"], chest_rect, border_radius=int(0.5 * b))
        pygame.draw.rect(screen, p["armor_light"], chest_rect.inflate(-int(0.5 * b), -int(0.4 * b)), border_radius=4)
        pygame.draw.rect(screen, p["trim"], chest_rect, 1, border_radius=int(0.5 * b))

        # 가슴 중앙 장식
        pygame.draw.line(screen, p["trim"], (chest_rect.centerx, chest_rect.top + int(0.3 * b)),
                        (chest_rect.centerx, chest_rect.bottom - int(0.3 * b)), 2)

        # 벨트
        belt_rect = pygame.Rect(cx - int(1.6 * b) + lean_offset, chest_rect.bottom - 2, int(3.2 * b), int(0.7 * b))
        pygame.draw.rect(screen, p["helmet_dark"], belt_rect, border_radius=2)

        # === 어깨 갑옷 (큰 사이즈) ===
        for side in [-1, 1]:
            pauldron_rect = pygame.Rect(
                cx + side * int(1.2 * b) + lean_offset - int(0.7 * b),
                torso_y - int(0.8 * b),
                int(1.4 * b), int(1.2 * b)
            )
            pygame.draw.ellipse(screen, p["armor"], pauldron_rect)
            pygame.draw.ellipse(screen, p["armor_light"], pauldron_rect.inflate(-int(0.3 * b), -int(0.2 * b)))
            pygame.draw.ellipse(screen, p["trim"], pauldron_rect, 1)

        # === 팔 ===
        arm_swing = int(wave * 2)
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.4 * b) + lean_offset, torso_y + int(0.2 * b))
            elbow = (shoulder[0] + side * int(0.6 * b) + arm_swing * side, torso_y + int(1.0 * b))
            wrist = (elbow[0] + side * int(0.4 * b), torso_y + int(1.6 * b))

            pygame.draw.line(screen, p["armor"], shoulder, elbow, max(3, int(0.7 * b)))
            pygame.draw.line(screen, p["armor"], elbow, wrist, max(2, int(0.6 * b)))
            pygame.draw.circle(screen, p["armor_light"], wrist, max(2, int(0.35 * b)))

        # === 헬멧 ===
        head_y = torso_y - int(3.0 * b)
        helmet_w, helmet_h = int(2.4 * b), int(2.0 * b)
        helmet_rect = pygame.Rect(cx - helmet_w // 2 + lean_offset, head_y, helmet_w, helmet_h)

        pygame.draw.ellipse(screen, p["helmet"], helmet_rect)
        pygame.draw.ellipse(screen, p["helmet_light"], helmet_rect.inflate(-int(0.6 * b), -int(0.5 * b)))

        if show_back:
            # 뒷모습 - 헬멧 뒷면
            pygame.draw.ellipse(screen, p["helmet_dark"], helmet_rect.inflate(-int(0.3 * b), -int(0.2 * b)))
            # 뒷면 통풍구
            for i in range(3):
                vy = helmet_rect.centery + (i - 1) * int(0.4 * b)
                pygame.draw.line(screen, p["helmet_dark"],
                               (helmet_rect.centerx - int(0.3 * b), vy),
                               (helmet_rect.centerx + int(0.3 * b), vy), 2)
        else:
            # 정면 - T자 바이저
            visor_rect = pygame.Rect(
                helmet_rect.centerx - int(0.8 * b),
                helmet_rect.centery - int(0.2 * b),
                int(1.6 * b), int(0.5 * b)
            )
            pygame.draw.rect(screen, p["visor"], visor_rect, border_radius=2)
            pygame.draw.rect(screen, p["visor_core"], visor_rect.inflate(-int(0.2 * b), -int(0.15 * b)), border_radius=1)

            # T자 세로 부분
            visor_vert = pygame.Rect(helmet_rect.centerx - int(0.2 * b), visor_rect.bottom - 2, int(0.4 * b), int(0.6 * b))
            pygame.draw.rect(screen, p["visor"], visor_vert, border_radius=1)

        # 헬멧 릿지
        pygame.draw.line(screen, p["trim"], (helmet_rect.centerx, helmet_rect.top + int(0.2 * b)),
                        (helmet_rect.centerx, helmet_rect.centery - int(0.1 * b)), 2)

        # === 대형 방패 (왼쪽) ===
        shield_x = cx - int(2.8 * b) + lean_offset
        shield_y = torso_y - int(0.5 * b)
        shield_w, shield_h = int(1.8 * b), int(3.5 * b)

        # 방패 그림자
        pygame.draw.ellipse(screen, (40, 50, 60), (shield_x + 2, shield_y + 3, shield_w, shield_h))
        # 방패 본체
        pygame.draw.ellipse(screen, p["shield"], (shield_x, shield_y, shield_w, shield_h))
        pygame.draw.ellipse(screen, p["shield_light"], (shield_x + int(0.2 * b), shield_y + int(0.3 * b),
                                                        shield_w - int(0.4 * b), shield_h - int(0.6 * b)))
        # 방패 테두리
        pygame.draw.ellipse(screen, p["shield_rim"], (shield_x, shield_y, shield_w, shield_h), 2)
        # 중앙 문양
        pygame.draw.circle(screen, p["shield_rim"], (shield_x + shield_w // 2, shield_y + shield_h // 2), int(0.4 * b))

    # =========================================================================
    # 토키아 - 바위의 거인
    # =========================================================================
    def _draw_chungkia(self, screen, cx, cy, b, color, show_back, anim):
        """토키아 - 바위의 거인 (거대한 체구)"""
        # 애니메이션 값 추출
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        arm_swing_anim = anim["arm_swing"]
        left_leg_lift = anim["left_leg"]
        right_leg_lift = anim["right_leg"]
        left_shoulder = anim["left_shoulder"]
        right_shoulder = anim["right_shoulder"]

        torso_y = cy - int(1.8 * b) + int(body_bob * 1.5 * b)
        lean_offset = int(lean * 1.5 * b)
        leg_lift = int(abs(wave) * 1)

        p = {
            "rock": color,
            "rock_light": tuple(min(255, c + 40) for c in color),
            "rock_dark": tuple(max(0, c - 50) for c in color),
            "crack": tuple(max(0, c - 80) for c in color),
            "skin": (180, 150, 120),
            "eye": (255, 200, 100),
            "cloth": (80, 60, 40),
        }

        # === 다리 (굵은 다리) ===
        hip_y = torso_y + int(2.5 * b)
        for side in [-1, 1]:
            leg_phase = leg_lift if side == 1 else 0
            thigh_x = cx + side * int(0.7 * b) + lean_offset
            # 허벅지 (굵음)
            thigh_rect = pygame.Rect(thigh_x - int(0.6 * b), hip_y + leg_phase, int(1.2 * b), int(2.0 * b))
            pygame.draw.rect(screen, p["cloth"], thigh_rect, border_radius=4)
            # 종아리 (바위)
            calf_rect = pygame.Rect(thigh_x - int(0.7 * b), thigh_rect.bottom - 2, int(1.4 * b), int(1.2 * b))
            pygame.draw.rect(screen, p["rock_dark"], calf_rect, border_radius=4)
            pygame.draw.rect(screen, p["rock"], calf_rect.inflate(-2, -2), border_radius=3)

        # === 몸통 (거대한 상체) ===
        chest_w, chest_h = int(4.0 * b), int(2.8 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.5 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["rock"], chest_rect, border_radius=int(0.6 * b))
        pygame.draw.rect(screen, p["rock_light"], chest_rect.inflate(-int(0.5 * b), -int(0.4 * b)), border_radius=5)

        # 바위 균열 무늬
        pygame.draw.line(screen, p["crack"], (chest_rect.left + int(0.5 * b), chest_rect.centery),
                        (chest_rect.centerx - int(0.3 * b), chest_rect.bottom - int(0.3 * b)), 2)
        pygame.draw.line(screen, p["crack"], (chest_rect.right - int(0.5 * b), chest_rect.centery),
                        (chest_rect.centerx + int(0.5 * b), chest_rect.top + int(0.5 * b)), 2)

        # 복부
        abs_rect = pygame.Rect(cx - int(1.5 * b) + lean_offset, chest_rect.bottom - int(0.2 * b), int(3.0 * b), int(1.0 * b))
        pygame.draw.rect(screen, p["cloth"], abs_rect, border_radius=3)

        # === 어깨 (바위 덩어리) ===
        for side in [-1, 1]:
            shoulder_rect = pygame.Rect(
                cx + side * int(1.6 * b) + lean_offset - int(0.8 * b),
                torso_y - int(0.6 * b),
                int(1.6 * b), int(1.4 * b)
            )
            pygame.draw.ellipse(screen, p["rock"], shoulder_rect)
            pygame.draw.ellipse(screen, p["rock_light"], shoulder_rect.inflate(-int(0.3 * b), -int(0.3 * b)))
            # 균열
            pygame.draw.line(screen, p["crack"],
                           (shoulder_rect.centerx, shoulder_rect.top + int(0.2 * b)),
                           (shoulder_rect.centerx + side * int(0.3 * b), shoulder_rect.bottom - int(0.2 * b)), 1)

        # === 팔 (굵은 바위팔) ===
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.8 * b) + lean_offset, torso_y + int(0.3 * b))
            elbow = (shoulder[0] + side * int(0.8 * b), torso_y + int(1.2 * b))
            wrist = (elbow[0] + side * int(0.5 * b), torso_y + int(2.0 * b))

            pygame.draw.line(screen, p["rock"], shoulder, elbow, max(4, int(0.9 * b)))
            pygame.draw.line(screen, p["rock_light"], shoulder, elbow, max(3, int(0.7 * b)))
            pygame.draw.line(screen, p["rock"], elbow, wrist, max(3, int(0.8 * b)))
            pygame.draw.circle(screen, p["rock_light"], wrist, max(3, int(0.5 * b)))

        # === 머리 (바위 머리) ===
        head_y = torso_y - int(3.2 * b)
        head_w, head_h = int(2.6 * b), int(2.2 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        pygame.draw.ellipse(screen, p["rock"], head_rect)
        pygame.draw.ellipse(screen, p["rock_light"], head_rect.inflate(-int(0.4 * b), -int(0.3 * b)))

        if show_back:
            # 뒷모습 - 바위 질감
            for i in range(2):
                for j in range(2):
                    crack_x = head_rect.centerx + (i - 0.5) * int(0.5 * b)
                    crack_y = head_rect.centery + (j - 0.5) * int(0.4 * b)
                    pygame.draw.line(screen, p["crack"],
                                   (crack_x - int(0.2 * b), crack_y),
                                   (crack_x + int(0.2 * b), crack_y + int(0.1 * b)), 1)
        else:
            # 정면 - 얼굴
            face_rect = head_rect.inflate(-int(0.5 * b), -int(0.4 * b))
            face_rect.move_ip(0, int(0.15 * b))
            pygame.draw.ellipse(screen, p["skin"], face_rect)
            # 눈 (노란 빛)
            eye_y = face_rect.centery - int(0.15 * b)
            pygame.draw.circle(screen, p["eye"], (face_rect.centerx - int(0.35 * b), eye_y), max(2, int(0.2 * b)))
            pygame.draw.circle(screen, p["eye"], (face_rect.centerx + int(0.35 * b), eye_y), max(2, int(0.2 * b)))
            # 입 (굳은 표정)
            pygame.draw.line(screen, p["crack"],
                           (face_rect.centerx - int(0.3 * b), face_rect.bottom - int(0.3 * b)),
                           (face_rect.centerx + int(0.3 * b), face_rect.bottom - int(0.3 * b)), 2)

    # =========================================================================
    # 포이네스 - 그림자 암살자
    # =========================================================================
    def _draw_poineth(self, screen, cx, cy, b, color, show_back, anim):
        """포이네스 - 그림자 암살자"""
        # 애니메이션 값 추출
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        arm_swing_anim = anim["arm_swing"]
        left_leg_lift = anim["left_leg"]
        right_leg_lift = anim["right_leg"]
        left_shoulder = anim["left_shoulder"]
        right_shoulder = anim["right_shoulder"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2.5 * b)
        leg_lift = int(abs(wave) * 2.5)

        p = {
            "cloak": color,
            "cloak_light": tuple(min(255, c + 30) for c in color),
            "cloak_dark": tuple(max(0, c - 40) for c in color),
            "skin": (200, 180, 160),
            "eye": (255, 100, 100),
            "dagger": (180, 190, 200),
            "dagger_edge": (220, 230, 240),
            "shadow": (40, 30, 50),
        }

        # === 다리 (날렵한 다리) ===
        hip_y = torso_y + int(1.8 * b)
        for side in [-1, 1]:
            leg_phase = leg_lift if side == 1 else -leg_lift
            thigh_x = cx + side * int(0.4 * b) + lean_offset
            # 허벅지
            thigh_rect = pygame.Rect(thigh_x - int(0.35 * b), hip_y + leg_phase, int(0.7 * b), int(1.6 * b))
            pygame.draw.rect(screen, p["cloak_dark"], thigh_rect, border_radius=2)
            # 종아리
            calf_rect = pygame.Rect(thigh_x - int(0.3 * b), thigh_rect.bottom - 2, int(0.6 * b), int(1.0 * b))
            pygame.draw.rect(screen, p["shadow"], calf_rect, border_radius=2)

        # === 몸통 (슬림한 체형) ===
        chest_w, chest_h = int(2.4 * b), int(1.8 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.2 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["cloak"], chest_rect, border_radius=int(0.4 * b))
        pygame.draw.rect(screen, p["cloak_light"], chest_rect.inflate(-int(0.4 * b), -int(0.3 * b)), border_radius=3)

        # X자 벨트
        pygame.draw.line(screen, p["cloak_dark"],
                        (chest_rect.left + int(0.3 * b), chest_rect.top + int(0.3 * b)),
                        (chest_rect.right - int(0.3 * b), chest_rect.bottom - int(0.2 * b)), 2)
        pygame.draw.line(screen, p["cloak_dark"],
                        (chest_rect.right - int(0.3 * b), chest_rect.top + int(0.3 * b)),
                        (chest_rect.left + int(0.3 * b), chest_rect.bottom - int(0.2 * b)), 2)

        # === 망토 ===
        cape_points = [
            (cx - int(1.0 * b) + lean_offset, torso_y - int(0.5 * b)),
            (cx + int(1.0 * b) + lean_offset, torso_y - int(0.5 * b)),
            (cx + int(1.5 * b) + lean_offset - int(wave * 0.3 * b), cy + int(2.0 * b)),
            (cx - int(1.5 * b) + lean_offset + int(wave * 0.3 * b), cy + int(2.0 * b)),
        ]
        pygame.draw.polygon(screen, p["cloak_dark"], cape_points)

        # === 팔 + 단검 ===
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.0 * b) + lean_offset, torso_y)
            elbow = (shoulder[0] + side * int(0.6 * b) + int(wave * 2 * side), torso_y + int(0.6 * b))
            wrist = (elbow[0] + side * int(0.4 * b), torso_y + int(1.2 * b) + int(abs(wave) * 1))

            pygame.draw.line(screen, p["cloak_dark"], shoulder, elbow, max(2, int(0.5 * b)))
            pygame.draw.line(screen, p["skin"], elbow, wrist, max(2, int(0.4 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.3 * b)))

            # 단검
            dagger_tip = (wrist[0] + side * int(1.0 * b), wrist[1] - int(0.3 * b))
            pygame.draw.line(screen, p["dagger"], wrist, dagger_tip, max(2, int(0.2 * b)))
            pygame.draw.line(screen, p["dagger_edge"], wrist, dagger_tip, 1)

        # === 후드 머리 ===
        head_y = torso_y - int(2.8 * b)
        hood_w, hood_h = int(2.2 * b), int(2.0 * b)
        hood_rect = pygame.Rect(cx - hood_w // 2 + lean_offset, head_y, hood_w, hood_h)

        # 후드
        pygame.draw.ellipse(screen, p["cloak"], hood_rect)
        pygame.draw.ellipse(screen, p["cloak_dark"], hood_rect.inflate(-int(0.4 * b), -int(0.3 * b)))

        if show_back:
            # 뒷모습 - 후드 뒷면
            pygame.draw.ellipse(screen, p["cloak_dark"], hood_rect.inflate(-int(0.2 * b), -int(0.15 * b)))
            # 후드 주름
            for i in range(3):
                fy = hood_rect.centery + (i - 1) * int(0.3 * b)
                pygame.draw.arc(screen, p["shadow"], hood_rect.inflate(-int(0.5 * b), -int(0.4 * b)),
                               math.radians(30), math.radians(150), 1)
        else:
            # 정면 - 그림자 속 눈
            shadow_rect = hood_rect.inflate(-int(0.6 * b), -int(0.5 * b))
            shadow_rect.move_ip(0, int(0.2 * b))
            pygame.draw.ellipse(screen, p["shadow"], shadow_rect)
            # 붉은 눈
            eye_y = shadow_rect.centery
            pygame.draw.circle(screen, p["eye"], (shadow_rect.centerx - int(0.3 * b), eye_y), max(1, int(0.12 * b)))
            pygame.draw.circle(screen, p["eye"], (shadow_rect.centerx + int(0.3 * b), eye_y), max(1, int(0.12 * b)))

    # =========================================================================
    # 게스탄드 - 현명한 전술가 (마법사)
    # =========================================================================
    def _draw_gestand(self, screen, cx, cy, b, color, show_back, anim):
        """게스탄드 - 현명한 전술가"""
        # 애니메이션 값 추출
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        arm_swing_anim = anim["arm_swing"]
        left_leg_lift = anim["left_leg"]
        right_leg_lift = anim["right_leg"]
        left_shoulder = anim["left_shoulder"]
        right_shoulder = anim["right_shoulder"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)
        leg_lift = int(abs(wave) * 1.5)

        p = {
            "robe": color,
            "robe_light": tuple(min(255, c + 40) for c in color),
            "robe_dark": tuple(max(0, c - 40) for c in color),
            "skin": (220, 195, 170),
            "beard": (200, 200, 210),
            "eye": (70, 130, 180),
            "staff": (120, 90, 60),
            "staff_light": (160, 130, 100),
            "gem": (100, 200, 255),
            "gem_glow": (150, 220, 255),
            "gold": (200, 170, 80),
        }

        # === 로브 하단 (다리 대신) ===
        robe_bottom_points = [
            (cx - int(1.2 * b) + lean_offset, torso_y + int(1.5 * b)),
            (cx + int(1.2 * b) + lean_offset, torso_y + int(1.5 * b)),
            (cx + int(1.8 * b) + lean_offset + int(wave * 0.2 * b), cy + int(3.0 * b)),
            (cx - int(1.8 * b) + lean_offset - int(wave * 0.2 * b), cy + int(3.0 * b)),
        ]
        pygame.draw.polygon(screen, p["robe_dark"], robe_bottom_points)

        # 발끝만 살짝 보임
        for side in [-1, 1]:
            foot_x = cx + side * int(0.6 * b) + lean_offset + int(side * leg_lift * 0.3)
            pygame.draw.ellipse(screen, p["robe_dark"],
                              (foot_x - int(0.3 * b), cy + int(2.6 * b), int(0.6 * b), int(0.3 * b)))

        # === 몸통 (로브) ===
        chest_w, chest_h = int(2.6 * b), int(2.0 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.3 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["robe"], chest_rect, border_radius=int(0.5 * b))
        pygame.draw.rect(screen, p["robe_light"], chest_rect.inflate(-int(0.4 * b), -int(0.3 * b)), border_radius=4)

        # 로브 세로선
        pygame.draw.line(screen, p["robe_dark"], (chest_rect.centerx, chest_rect.top + int(0.2 * b)),
                        (chest_rect.centerx, chest_rect.bottom - int(0.1 * b)), 2)

        # 금색 장식
        pygame.draw.line(screen, p["gold"], (chest_rect.left + int(0.3 * b), chest_rect.centery),
                        (chest_rect.right - int(0.3 * b), chest_rect.centery), 1)

        # === 어깨 ===
        for side in [-1, 1]:
            shoulder_rect = pygame.Rect(
                cx + side * int(1.0 * b) + lean_offset - int(0.5 * b),
                torso_y - int(0.3 * b),
                int(1.0 * b), int(0.8 * b)
            )
            pygame.draw.ellipse(screen, p["robe"], shoulder_rect)

        # === 팔 ===
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.1 * b) + lean_offset, torso_y + int(0.2 * b))
            elbow = (shoulder[0] + side * int(0.5 * b), torso_y + int(0.9 * b))
            wrist = (elbow[0] + side * int(0.3 * b), torso_y + int(1.5 * b))

            pygame.draw.line(screen, p["robe"], shoulder, elbow, max(2, int(0.5 * b)))
            pygame.draw.line(screen, p["robe_light"], elbow, wrist, max(2, int(0.45 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.3 * b)))

        # === 머리 ===
        head_y = torso_y - int(2.8 * b)
        head_w, head_h = int(2.0 * b), int(1.8 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        if show_back:
            # 뒷모습
            pygame.draw.ellipse(screen, p["skin"], head_rect)
            # 머리카락 (회색)
            hair_rect = head_rect.inflate(-int(0.1 * b), int(0.1 * b))
            hair_rect.move_ip(0, -int(0.1 * b))
            pygame.draw.ellipse(screen, p["beard"], hair_rect)
        else:
            # 정면
            pygame.draw.ellipse(screen, p["skin"], head_rect)
            # 눈
            eye_y = head_rect.centery - int(0.15 * b)
            pygame.draw.circle(screen, p["eye"], (head_rect.centerx - int(0.3 * b), eye_y), max(1, int(0.12 * b)))
            pygame.draw.circle(screen, p["eye"], (head_rect.centerx + int(0.3 * b), eye_y), max(1, int(0.12 * b)))
            # 수염
            beard_points = [
                (head_rect.centerx - int(0.4 * b), head_rect.bottom - int(0.3 * b)),
                (head_rect.centerx + int(0.4 * b), head_rect.bottom - int(0.3 * b)),
                (head_rect.centerx + int(0.2 * b), head_rect.bottom + int(0.5 * b)),
                (head_rect.centerx, head_rect.bottom + int(0.7 * b)),
                (head_rect.centerx - int(0.2 * b), head_rect.bottom + int(0.5 * b)),
            ]
            pygame.draw.polygon(screen, p["beard"], beard_points)

        # === 지팡이 ===
        staff_x = cx + int(2.2 * b) + lean_offset
        staff_top = head_y - int(0.5 * b)
        staff_bottom = cy + int(2.5 * b)
        pygame.draw.line(screen, p["staff"], (staff_x, staff_top), (staff_x, staff_bottom), max(2, int(0.3 * b)))
        pygame.draw.line(screen, p["staff_light"], (staff_x - 1, staff_top), (staff_x - 1, staff_bottom), 1)

        # 보석
        gem_y = staff_top - int(0.3 * b)
        gem_r = max(3, int(0.4 * b))
        # 글로우
        pygame.draw.circle(screen, (*p["gem_glow"][:3], 100), (staff_x, gem_y), gem_r + 3)
        pygame.draw.circle(screen, p["gem"], (staff_x, gem_y), gem_r)
        pygame.draw.circle(screen, p["gem_glow"], (staff_x - 1, gem_y - 1), max(1, gem_r // 2))

    # =========================================================================
    # 부칸다이 - 광기의 광대
    # =========================================================================
    def _draw_bukandai(self, screen, cx, cy, b, color, show_back, anim):
        """부칸다이 - 광기의 광대"""
        # 애니메이션 값 추출
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        arm_swing_anim = anim["arm_swing"]
        left_leg_lift = anim["left_leg"]
        right_leg_lift = anim["right_leg"]
        left_shoulder = anim["left_shoulder"]
        right_shoulder = anim["right_shoulder"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2.5 * b)
        lean_offset = int(lean * 2.5 * b)
        leg_lift = int(abs(wave) * 3)

        p = {
            "costume": color,
            "costume_light": tuple(min(255, c + 50) for c in color),
            "costume_dark": tuple(max(0, c - 40) for c in color),
            "skin": (235, 215, 200),
            "hat_tip": (255, 255, 100),
            "hat_tip2": (100, 255, 255),
            "hat_tip3": (255, 100, 255),
            "eye": (255, 255, 0),
            "smile": (200, 50, 50),
            "bomb": (60, 60, 60),
            "fuse": (255, 150, 50),
        }

        # === 다리 (과장된 움직임) ===
        hip_y = torso_y + int(1.8 * b)
        for side in [-1, 1]:
            leg_phase = leg_lift if side == 1 else -leg_lift
            thigh_x = cx + side * int(0.45 * b) + lean_offset
            # 허벅지
            thigh_rect = pygame.Rect(thigh_x - int(0.4 * b), hip_y + leg_phase, int(0.8 * b), int(1.6 * b))
            pygame.draw.rect(screen, p["costume"], thigh_rect, border_radius=3)
            # 무늬
            for i in range(3):
                stripe_y = thigh_rect.top + int(0.3 * b) + i * int(0.5 * b)
                stripe_color = p["costume_light"] if i % 2 == 0 else p["costume_dark"]
                pygame.draw.line(screen, stripe_color, (thigh_rect.left + 2, stripe_y),
                               (thigh_rect.right - 2, stripe_y), 2)
            # 신발 (뾰족)
            shoe_points = [
                (thigh_x - int(0.3 * b), thigh_rect.bottom),
                (thigh_x + int(0.3 * b), thigh_rect.bottom),
                (thigh_x + side * int(0.8 * b), thigh_rect.bottom + int(0.4 * b)),
                (thigh_x, thigh_rect.bottom + int(0.6 * b)),
            ]
            pygame.draw.polygon(screen, p["costume_dark"], shoe_points)

        # === 몸통 ===
        chest_w, chest_h = int(2.4 * b), int(1.8 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.2 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["costume"], chest_rect, border_radius=int(0.4 * b))

        # 다이아몬드 무늬
        diamond_cx, diamond_cy = chest_rect.centerx, chest_rect.centery
        diamond_points = [
            (diamond_cx, diamond_cy - int(0.5 * b)),
            (diamond_cx + int(0.4 * b), diamond_cy),
            (diamond_cx, diamond_cy + int(0.5 * b)),
            (diamond_cx - int(0.4 * b), diamond_cy),
        ]
        pygame.draw.polygon(screen, p["costume_light"], diamond_points)

        # === 어깨 퍼프 ===
        for side in [-1, 1]:
            puff_rect = pygame.Rect(
                cx + side * int(1.0 * b) + lean_offset - int(0.5 * b),
                torso_y - int(0.3 * b),
                int(1.0 * b), int(0.9 * b)
            )
            pygame.draw.ellipse(screen, p["costume_light"], puff_rect)
            pygame.draw.ellipse(screen, p["costume"], puff_rect.inflate(-int(0.2 * b), -int(0.15 * b)))

        # === 팔 ===
        arm_wave = int(wave * 4)
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.1 * b) + lean_offset, torso_y + int(0.1 * b))
            elbow = (shoulder[0] + side * int(0.5 * b) + arm_wave * side, torso_y + int(0.7 * b) - abs(arm_wave) // 2)
            wrist = (elbow[0] + side * int(0.4 * b), torso_y + int(1.3 * b))

            pygame.draw.line(screen, p["costume"], shoulder, elbow, max(2, int(0.5 * b)))
            pygame.draw.line(screen, p["costume_light"], elbow, wrist, max(2, int(0.45 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.3 * b)))

        # === 광대 모자 ===
        head_y = torso_y - int(2.6 * b)
        head_w, head_h = int(1.8 * b), int(1.6 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        if show_back:
            # 뒷모습 - 모자 뒷면
            pygame.draw.ellipse(screen, p["costume"], head_rect)
            # 3개의 뿔 (뒤에서)
            tips = [(-0.6, -0.8, p["hat_tip"]), (0, -1.0, p["hat_tip2"]), (0.6, -0.8, p["hat_tip3"])]
            for dx, dy, tip_color in tips:
                tip_x = head_rect.centerx + int(dx * b)
                tip_y = head_rect.top + int(dy * b)
                pygame.draw.circle(screen, tip_color, (tip_x, tip_y), max(2, int(0.25 * b)))
        else:
            # 정면 - 얼굴
            pygame.draw.ellipse(screen, p["skin"], head_rect)
            # 눈 (미친 눈)
            eye_y = head_rect.centery - int(0.1 * b)
            pygame.draw.circle(screen, (255, 255, 255), (head_rect.centerx - int(0.3 * b), eye_y), max(2, int(0.2 * b)))
            pygame.draw.circle(screen, (255, 255, 255), (head_rect.centerx + int(0.3 * b), eye_y), max(2, int(0.2 * b)))
            pygame.draw.circle(screen, p["eye"], (head_rect.centerx - int(0.3 * b), eye_y), max(1, int(0.1 * b)))
            pygame.draw.circle(screen, p["eye"], (head_rect.centerx + int(0.3 * b), eye_y), max(1, int(0.1 * b)))
            # 미소
            pygame.draw.arc(screen, p["smile"],
                          (head_rect.centerx - int(0.4 * b), head_rect.centery, int(0.8 * b), int(0.5 * b)),
                          math.radians(200), math.radians(340), 2)

            # 3뿔 모자
            tips = [(-0.7, -0.6, p["hat_tip"]), (0, -1.0, p["hat_tip2"]), (0.7, -0.6, p["hat_tip3"])]
            for dx, dy, tip_color in tips:
                tip_base_x = head_rect.centerx + int(dx * 0.3 * b)
                tip_base_y = head_rect.top + int(0.2 * b)
                tip_end_x = head_rect.centerx + int(dx * b)
                tip_end_y = head_rect.top + int(dy * b)
                horn_points = [
                    (tip_base_x - int(0.2 * b), tip_base_y),
                    (tip_base_x + int(0.2 * b), tip_base_y),
                    (tip_end_x, tip_end_y),
                ]
                pygame.draw.polygon(screen, p["costume"], horn_points)
                pygame.draw.circle(screen, tip_color, (tip_end_x, tip_end_y), max(2, int(0.25 * b)))

        # === 폭탄 ===
        bomb_x = cx - int(2.0 * b) + lean_offset
        bomb_y = torso_y + int(0.8 * b)
        bomb_r = max(4, int(0.6 * b))
        pygame.draw.circle(screen, p["bomb"], (bomb_x, bomb_y), bomb_r)
        # 심지
        fuse_end = (bomb_x - int(0.3 * b), bomb_y - bomb_r - int(0.3 * b))
        pygame.draw.line(screen, p["costume_dark"], (bomb_x, bomb_y - bomb_r), fuse_end, 2)
        # 불꽃
        spark_offset = int(math.sin(self.time * 15) * 2)
        pygame.draw.circle(screen, p["fuse"], (fuse_end[0] + spark_offset, fuse_end[1] - int(0.2 * b)), max(2, int(0.2 * b)))

    # =========================================================================
    # 핀조 - 불굴의 검투사
    # =========================================================================
    def _draw_pinjo(self, screen, cx, cy, b, color, show_back, anim):
        """핀조 - 불굴의 검투사 (로마 검투사)"""
        # 애니메이션 값 추출
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        arm_swing_anim = anim["arm_swing"]
        left_leg_lift = anim["left_leg"]
        right_leg_lift = anim["right_leg"]
        left_shoulder = anim["left_shoulder"]
        right_shoulder = anim["right_shoulder"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)
        leg_lift = int(abs(wave) * 2)

        p = {
            "helmet": color,
            "helmet_light": tuple(min(255, c + 50) for c in color),
            "helmet_dark": tuple(max(0, c - 50) for c in color),
            "skin": (200, 160, 130),
            "armor": tuple(max(0, c - 20) for c in color),
            "armor_light": color,
            "armor_dark": tuple(max(0, c - 60) for c in color),
            "plume": (180, 50, 50),
            "plume_light": (220, 100, 100),
            "sword": (180, 190, 200),
            "sword_edge": (230, 240, 250),
            "shield": (140, 100, 60),
            "shield_metal": (180, 180, 190),
            "cloth": (150, 120, 80),
            "sandal": (120, 90, 60),
        }

        # === 다리 (로마 샌들) ===
        hip_y = torso_y + int(1.8 * b)
        for side in [-1, 1]:
            leg_phase = leg_lift if side == 1 else -leg_lift // 2
            thigh_x = cx + side * int(0.5 * b) + lean_offset
            # 허벅지 (맨다리)
            thigh_rect = pygame.Rect(thigh_x - int(0.4 * b), hip_y + leg_phase, int(0.8 * b), int(1.6 * b))
            pygame.draw.rect(screen, p["skin"], thigh_rect, border_radius=3)
            # 정강이 보호대
            shin_rect = pygame.Rect(thigh_x - int(0.35 * b), thigh_rect.bottom - int(0.3 * b), int(0.7 * b), int(1.0 * b))
            pygame.draw.rect(screen, p["armor"], shin_rect, border_radius=2)
            pygame.draw.line(screen, p["armor_light"], (shin_rect.left + 2, shin_rect.centery),
                           (shin_rect.right - 2, shin_rect.centery), 1)
            # 샌들
            sandal_rect = pygame.Rect(thigh_x - int(0.4 * b), shin_rect.bottom - 2, int(0.8 * b), int(0.4 * b))
            pygame.draw.rect(screen, p["sandal"], sandal_rect, border_radius=2)

        # === 몸통 (근육질 + 갑옷) ===
        chest_w, chest_h = int(2.8 * b), int(2.0 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.3 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["armor"], chest_rect, border_radius=int(0.4 * b))
        pygame.draw.rect(screen, p["armor_light"], chest_rect.inflate(-int(0.4 * b), -int(0.3 * b)), border_radius=4)

        # 복근 라인
        for i in range(2):
            ab_y = chest_rect.centery + i * int(0.4 * b)
            pygame.draw.line(screen, p["helmet_dark"],
                           (chest_rect.centerx - int(0.6 * b), ab_y),
                           (chest_rect.centerx + int(0.6 * b), ab_y), 1)
        pygame.draw.line(screen, p["helmet_dark"],
                        (chest_rect.centerx, chest_rect.centery - int(0.2 * b)),
                        (chest_rect.centerx, chest_rect.bottom - int(0.2 * b)), 1)

        # 스커트
        skirt_points = [
            (cx - int(1.2 * b) + lean_offset, chest_rect.bottom - 2),
            (cx + int(1.2 * b) + lean_offset, chest_rect.bottom - 2),
            (cx + int(1.4 * b) + lean_offset, hip_y + int(0.3 * b)),
            (cx - int(1.4 * b) + lean_offset, hip_y + int(0.3 * b)),
        ]
        pygame.draw.polygon(screen, p["cloth"], skirt_points)
        # 스커트 줄무늬
        for i in range(4):
            sx = cx + (i - 1.5) * int(0.5 * b) + lean_offset
            pygame.draw.line(screen, p["armor_dark"], (sx, chest_rect.bottom), (sx, hip_y + int(0.2 * b)), 1)

        # === 어깨 갑옷 ===
        for side in [-1, 1]:
            pauldron_rect = pygame.Rect(
                cx + side * int(1.1 * b) + lean_offset - int(0.6 * b),
                torso_y - int(0.5 * b),
                int(1.2 * b), int(1.0 * b)
            )
            pygame.draw.ellipse(screen, p["armor"], pauldron_rect)
            pygame.draw.ellipse(screen, p["armor_light"], pauldron_rect.inflate(-int(0.3 * b), -int(0.2 * b)))

        # === 팔 ===
        arm_swing = int(wave * 2.5)
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.3 * b) + lean_offset, torso_y + int(0.1 * b))
            elbow = (shoulder[0] + side * int(0.6 * b) + arm_swing * side, torso_y + int(0.9 * b))
            wrist = (elbow[0] + side * int(0.4 * b), torso_y + int(1.5 * b))

            pygame.draw.line(screen, p["skin"], shoulder, elbow, max(3, int(0.6 * b)))
            pygame.draw.line(screen, p["skin"], elbow, wrist, max(2, int(0.5 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.35 * b)))

        # === 투구 ===
        head_y = torso_y - int(3.0 * b)
        helmet_w, helmet_h = int(2.2 * b), int(2.0 * b)
        helmet_rect = pygame.Rect(cx - helmet_w // 2 + lean_offset, head_y, helmet_w, helmet_h)

        pygame.draw.ellipse(screen, p["helmet"], helmet_rect)
        pygame.draw.ellipse(screen, p["helmet_light"], helmet_rect.inflate(-int(0.4 * b), -int(0.3 * b)))

        if show_back:
            # 뒷모습 - 투구 뒷면 + 깃털
            pygame.draw.ellipse(screen, p["helmet_dark"], helmet_rect.inflate(-int(0.2 * b), -int(0.15 * b)))
            # 깃털 (뒤에서)
            for i in range(5):
                feather_x = helmet_rect.centerx + (i - 2) * int(0.2 * b)
                feather_top = helmet_rect.top - int(0.8 * b) - abs(i - 2) * int(0.15 * b)
                pygame.draw.line(screen, p["plume"], (feather_x, helmet_rect.top + int(0.2 * b)),
                               (feather_x, feather_top), 2)
        else:
            # 정면 - 얼굴 + T자 개구부
            face_opening = pygame.Rect(
                helmet_rect.centerx - int(0.6 * b),
                helmet_rect.centery - int(0.1 * b),
                int(1.2 * b), int(0.9 * b)
            )
            pygame.draw.ellipse(screen, p["skin"], face_opening)
            # 눈
            eye_y = face_opening.centery - int(0.1 * b)
            pygame.draw.circle(screen, (60, 40, 30), (face_opening.centerx - int(0.25 * b), eye_y), max(1, int(0.1 * b)))
            pygame.draw.circle(screen, (60, 40, 30), (face_opening.centerx + int(0.25 * b), eye_y), max(1, int(0.1 * b)))

            # 깃털 (정면)
            plume_base_y = helmet_rect.top + int(0.15 * b)
            for i in range(7):
                feather_x = helmet_rect.centerx + (i - 3) * int(0.15 * b)
                feather_top = helmet_rect.top - int(1.0 * b) - abs(i - 3) * int(0.1 * b)
                feather_color = p["plume_light"] if i % 2 == 0 else p["plume"]
                pygame.draw.line(screen, feather_color, (feather_x, plume_base_y), (feather_x, feather_top), 2)

        # === 검 (오른손) ===
        sword_x = cx + int(2.2 * b) + lean_offset
        sword_top = torso_y - int(0.5 * b)
        sword_bottom = cy + int(1.5 * b)
        pygame.draw.line(screen, p["sword"], (sword_x, sword_top), (sword_x, sword_bottom), max(2, int(0.25 * b)))
        pygame.draw.line(screen, p["sword_edge"], (sword_x - 1, sword_top), (sword_x - 1, sword_bottom), 1)
        # 검날
        blade_points = [
            (sword_x, sword_top - int(0.6 * b)),
            (sword_x - int(0.15 * b), sword_top),
            (sword_x + int(0.15 * b), sword_top),
        ]
        pygame.draw.polygon(screen, p["sword_edge"], blade_points)
        # 손잡이
        pygame.draw.line(screen, p["shield"], (sword_x - int(0.3 * b), sword_bottom),
                        (sword_x + int(0.3 * b), sword_bottom), max(2, int(0.2 * b)))

        # === 방패 (왼손) ===
        shield_x = cx - int(2.2 * b) + lean_offset
        shield_y = torso_y + int(0.3 * b)
        shield_w, shield_h = int(1.2 * b), int(1.8 * b)
        pygame.draw.ellipse(screen, p["shield"], (shield_x - shield_w // 2, shield_y, shield_w, shield_h))
        pygame.draw.ellipse(screen, p["shield_metal"], (shield_x - shield_w // 2 + 3, shield_y + 3,
                                                        shield_w - 6, shield_h - 6))
        # 방패 중앙 장식
        pygame.draw.circle(screen, p["armor_light"], (shield_x, shield_y + shield_h // 2), max(2, int(0.25 * b)))

    # =========================================================================
    # 알렉사 - 황금의 창
    # =========================================================================
    def _draw_alexa(self, screen, cx, cy, b, color, show_back, anim):
        """알렉사 - 황금의 창 (귀족 전사)"""
        # 애니메이션 값 추출
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        arm_swing_anim = anim["arm_swing"]
        left_leg_lift = anim["left_leg"]
        right_leg_lift = anim["right_leg"]
        left_shoulder = anim["left_shoulder"]
        right_shoulder = anim["right_shoulder"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)
        leg_lift = int(abs(wave) * 1.5)

        p = {
            "gold": color,
            "gold_light": tuple(min(255, c + 40) for c in color),
            "gold_dark": tuple(max(0, c - 50) for c in color),
            "skin": (235, 210, 185),
            "hair": (80, 60, 40),
            "hair_light": (120, 90, 60),
            "eye": (100, 70, 50),
            "cloth": (180, 160, 140),
            "cloth_dark": (140, 120, 100),
            "spear": (200, 180, 120),
            "spear_blade": (255, 245, 200),
            "boot": (100, 80, 60),
        }

        # === 다리 (우아한 스타일) ===
        hip_y = torso_y + int(1.8 * b)
        for side in [-1, 1]:
            leg_phase = leg_lift if side == 1 else -leg_lift // 2
            thigh_x = cx + side * int(0.45 * b) + lean_offset
            # 허벅지
            thigh_rect = pygame.Rect(thigh_x - int(0.4 * b), hip_y + leg_phase, int(0.8 * b), int(1.6 * b))
            pygame.draw.rect(screen, p["cloth"], thigh_rect, border_radius=3)
            # 무릎 장식
            knee_rect = pygame.Rect(thigh_x - int(0.35 * b), thigh_rect.bottom - int(0.4 * b), int(0.7 * b), int(0.5 * b))
            pygame.draw.rect(screen, p["gold_dark"], knee_rect, border_radius=2)
            # 부츠
            boot_rect = pygame.Rect(thigh_x - int(0.4 * b), knee_rect.bottom, int(0.8 * b), int(0.9 * b))
            pygame.draw.rect(screen, p["boot"], boot_rect, border_radius=3)
            pygame.draw.line(screen, p["gold"], (boot_rect.left + 2, boot_rect.top + 2),
                           (boot_rect.right - 2, boot_rect.top + 2), 1)

        # === 몸통 (황금 갑옷) ===
        chest_w, chest_h = int(2.6 * b), int(2.0 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.3 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["gold"], chest_rect, border_radius=int(0.4 * b))
        pygame.draw.rect(screen, p["gold_light"], chest_rect.inflate(-int(0.4 * b), -int(0.3 * b)), border_radius=4)

        # 가슴 장식
        pygame.draw.line(screen, p["gold_dark"], (chest_rect.centerx, chest_rect.top + int(0.2 * b)),
                        (chest_rect.centerx, chest_rect.bottom - int(0.2 * b)), 2)
        pygame.draw.line(screen, p["gold_dark"],
                        (chest_rect.left + int(0.3 * b), chest_rect.centery),
                        (chest_rect.right - int(0.3 * b), chest_rect.centery), 1)

        # 벨트
        belt_rect = pygame.Rect(cx - int(1.3 * b) + lean_offset, chest_rect.bottom - 2, int(2.6 * b), int(0.6 * b))
        pygame.draw.rect(screen, p["gold_dark"], belt_rect, border_radius=2)
        # 벨트 버클
        pygame.draw.rect(screen, p["gold_light"],
                        (belt_rect.centerx - int(0.3 * b), belt_rect.top + 1, int(0.6 * b), belt_rect.height - 2),
                        border_radius=1)

        # === 어깨 갑옷 ===
        for side in [-1, 1]:
            pauldron_rect = pygame.Rect(
                cx + side * int(1.0 * b) + lean_offset - int(0.5 * b),
                torso_y - int(0.4 * b),
                int(1.0 * b), int(0.9 * b)
            )
            pygame.draw.ellipse(screen, p["gold"], pauldron_rect)
            pygame.draw.ellipse(screen, p["gold_light"], pauldron_rect.inflate(-int(0.2 * b), -int(0.15 * b)))

        # === 팔 ===
        arm_swing = int(wave * 2)
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.1 * b) + lean_offset, torso_y + int(0.1 * b))
            elbow = (shoulder[0] + side * int(0.5 * b) + arm_swing * side, torso_y + int(0.8 * b))
            wrist = (elbow[0] + side * int(0.4 * b), torso_y + int(1.4 * b))

            pygame.draw.line(screen, p["gold_dark"], shoulder, elbow, max(2, int(0.55 * b)))
            pygame.draw.line(screen, p["gold"], elbow, wrist, max(2, int(0.45 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.3 * b)))

        # === 머리 ===
        head_y = torso_y - int(2.8 * b)
        head_w, head_h = int(1.9 * b), int(1.7 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        if show_back:
            # 뒷모습 - 머리카락
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            pygame.draw.ellipse(screen, p["hair_light"], head_rect.inflate(-int(0.3 * b), -int(0.2 * b)))
            # 뒷머리 디테일
            for i in range(4):
                hx = head_rect.centerx + (i - 1.5) * int(0.3 * b)
                pygame.draw.line(screen, p["hair"],
                               (hx, head_rect.top + int(0.4 * b)),
                               (hx, head_rect.bottom - int(0.2 * b)), 1)
            # 왕관 뒷면
            crown_back = pygame.Rect(head_rect.left + int(0.2 * b), head_rect.top - int(0.1 * b),
                                     head_rect.width - int(0.4 * b), int(0.4 * b))
            pygame.draw.rect(screen, p["gold"], crown_back, border_radius=2)
        else:
            # 정면 - 얼굴
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            # 얼굴
            face_rect = head_rect.inflate(-int(0.35 * b), -int(0.25 * b))
            face_rect.move_ip(0, int(0.15 * b))
            pygame.draw.ellipse(screen, p["skin"], face_rect)
            # 눈
            eye_y = face_rect.centery - int(0.1 * b)
            pygame.draw.circle(screen, p["eye"], (face_rect.centerx - int(0.25 * b), eye_y), max(1, int(0.1 * b)))
            pygame.draw.circle(screen, p["eye"], (face_rect.centerx + int(0.25 * b), eye_y), max(1, int(0.1 * b)))

            # 왕관
            crown_points = [
                (head_rect.left + int(0.15 * b), head_rect.top + int(0.35 * b)),
                (head_rect.left + int(0.3 * b), head_rect.top - int(0.15 * b)),
                (head_rect.centerx - int(0.2 * b), head_rect.top + int(0.15 * b)),
                (head_rect.centerx, head_rect.top - int(0.25 * b)),
                (head_rect.centerx + int(0.2 * b), head_rect.top + int(0.15 * b)),
                (head_rect.right - int(0.3 * b), head_rect.top - int(0.15 * b)),
                (head_rect.right - int(0.15 * b), head_rect.top + int(0.35 * b)),
            ]
            pygame.draw.polygon(screen, p["gold"], crown_points)
            pygame.draw.polygon(screen, p["gold_light"], crown_points, 1)
            # 보석
            pygame.draw.circle(screen, (255, 100, 100), (head_rect.centerx, head_rect.top), max(1, int(0.12 * b)))

        # === 황금창 ===
        spear_x = cx + int(2.3 * b) + lean_offset
        spear_top = head_y - int(1.2 * b)
        spear_bottom = cy + int(2.8 * b)
        pygame.draw.line(screen, p["spear"], (spear_x, spear_top), (spear_x, spear_bottom), max(2, int(0.25 * b)))
        pygame.draw.line(screen, p["gold_light"], (spear_x - 1, spear_top), (spear_x - 1, spear_bottom), 1)

        # 창날 (황금)
        blade_points = [
            (spear_x, spear_top - int(1.2 * b)),
            (spear_x - int(0.3 * b), spear_top),
            (spear_x + int(0.3 * b), spear_top),
        ]
        pygame.draw.polygon(screen, p["spear_blade"], blade_points)
        pygame.draw.polygon(screen, p["gold"], blade_points, 1)
        # 빛 효과
        pygame.draw.line(screen, (255, 255, 230), (spear_x, spear_top - int(1.0 * b)),
                        (spear_x, spear_top - int(0.5 * b)), 1)

    # =========================================================================
    # 기본 폴백
    # =========================================================================
    def _draw_default(self, screen, cx, cy, b, color, show_back, anim):
        """기본 캐릭터 (폴백)"""
        # 애니메이션 값 추출
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 1.5 * b)
        lean_offset = int(lean * 2 * b)

        # 다리
        for side in [-1, 1]:
            leg_x = cx + side * int(0.4 * b) + lean_offset
            pygame.draw.rect(screen, color, (leg_x - int(0.3 * b), torso_y + int(1.5 * b), int(0.6 * b), int(2.0 * b)), border_radius=2)

        # 몸통
        chest_rect = pygame.Rect(cx - int(1.2 * b) + lean_offset, torso_y, int(2.4 * b), int(1.8 * b))
        pygame.draw.rect(screen, color, chest_rect, border_radius=4)

        # 머리
        head_rect = pygame.Rect(cx - int(0.8 * b) + lean_offset, torso_y - int(2.2 * b), int(1.6 * b), int(1.6 * b))
        pygame.draw.ellipse(screen, color, head_rect)


# 싱글톤 인스턴스
_hero_paddle_renderer: Optional[HeroPaddleRenderer] = None


def get_hero_paddle_renderer() -> HeroPaddleRenderer:
    """영웅 패들 렌더러 싱글톤 반환"""
    global _hero_paddle_renderer
    if _hero_paddle_renderer is None:
        _hero_paddle_renderer = HeroPaddleRenderer()
    return _hero_paddle_renderer
