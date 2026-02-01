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
        # Smasher/Valtor 캐릭터 기준: b=5~6이 인게임 패들 크기에 적합
        # 캐릭터 전체 높이 = 약 8*b (헬멧~다리)
        if scale_mode == "paddle":
            # 투기장 모드: Smasher/보스 캐릭터와 비슷한 크기
            # 패들 높이(40~50)에 맞춰 b=5~6 정도가 적당
            b = 5  # 고정 스케일 (캐릭터 높이 약 40픽셀)
            # 투기장 모드에서는 애니메이션 적당히 축소 (모션 유지 + 크기 변동 방지)
            anim = {
                "wave": anim["wave"] * 0.6,
                "lean": anim["lean"] * 0.5,  # 기울기는 좀 더 억제
                "arm_swing": anim["arm_swing"] * 0.6,
                "body_bob": anim["body_bob"] * 0.5,
                "head_tilt": anim["head_tilt"] * 0.6,
                "left_leg": anim["left_leg"] * 0.6,
                "right_leg": anim["right_leg"] * 0.6,
                "left_shoulder": anim["left_shoulder"] * 0.6,
                "right_shoulder": anim["right_shoulder"] * 0.6,
            }
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
    # 무겐 - 귀검사 (어둠의 검객) - 동양풍 사무라이
    # =========================================================================
    def _draw_mugen(self, screen, cx, cy, b, color, show_back, anim):
        """무겐 - 귀검사 (보라색 검기를 다루는 동양 검객)"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        arm_swing_anim = anim["arm_swing"]
        left_leg_lift = anim["left_leg"]
        right_leg_lift = anim["right_leg"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2.5 * b)

        p = {
            "hair": (30, 20, 40),  # 검은 머리
            "hair_highlight": (60, 40, 80),
            "skin": (235, 210, 185),
            "armor": color,
            "armor_light": tuple(min(255, c + 40) for c in color),
            "armor_dark": tuple(max(0, c - 40) for c in color),
            "kimono": (40, 30, 60),  # 어두운 기모노
            "kimono_pattern": (80, 50, 120),
            "sash": (200, 160, 60),  # 허리띠
            "sword_blade": (200, 180, 255),  # 보라빛 검
            "sword_glow": (180, 120, 255),
            "sword_hilt": (80, 60, 40),
            "eye_glow": (200, 100, 255),  # 귀기 눈
        }

        # === 다리 (하카마 스타일) ===
        hip_y = torso_y + int(2.0 * b)
        hakama_points = [
            (cx - int(1.2 * b) + lean_offset, hip_y - int(0.2 * b)),
            (cx + int(1.2 * b) + lean_offset, hip_y - int(0.2 * b)),
            (cx + int(1.5 * b) + lean_offset + int(wave * 0.2 * b), cy + int(2.8 * b)),
            (cx - int(1.5 * b) + lean_offset - int(wave * 0.2 * b), cy + int(2.8 * b)),
        ]
        pygame.draw.polygon(screen, p["kimono"], hakama_points)
        # 하카마 주름
        for i in range(3):
            fx = cx + (i - 1) * int(0.6 * b) + lean_offset
            pygame.draw.line(screen, p["kimono_pattern"],
                           (fx, hip_y), (fx + int(wave * 0.1 * b), cy + int(2.5 * b)), 1)

        # === 몸통 (기모노 상의) ===
        chest_w, chest_h = int(2.6 * b), int(2.0 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.3 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["armor"], chest_rect, border_radius=int(0.4 * b))
        # 갑옷 디테일
        pygame.draw.rect(screen, p["armor_light"], chest_rect.inflate(-int(0.5 * b), -int(0.4 * b)), border_radius=3)
        # V자 기모노 깃
        pygame.draw.line(screen, p["kimono"], (chest_rect.centerx, chest_rect.top + int(0.2 * b)),
                        (chest_rect.left + int(0.4 * b), chest_rect.bottom - int(0.3 * b)), 2)
        pygame.draw.line(screen, p["kimono"], (chest_rect.centerx, chest_rect.top + int(0.2 * b)),
                        (chest_rect.right - int(0.4 * b), chest_rect.bottom - int(0.3 * b)), 2)

        # 사시 (허리띠)
        belt_rect = pygame.Rect(cx - int(1.3 * b) + lean_offset, chest_rect.bottom - 2, int(2.6 * b), int(0.7 * b))
        pygame.draw.rect(screen, p["sash"], belt_rect, border_radius=2)

        # === 어깨 갑옷 (사무라이 스타일) ===
        for side in [-1, 1]:
            pauldron = [
                (cx + side * int(1.4 * b) + lean_offset, torso_y - int(0.6 * b)),
                (cx + side * int(0.7 * b) + lean_offset, torso_y - int(0.3 * b)),
                (cx + side * int(0.8 * b) + lean_offset, torso_y + int(0.5 * b)),
                (cx + side * int(1.5 * b) + lean_offset, torso_y + int(0.3 * b)),
            ]
            pygame.draw.polygon(screen, p["armor_dark"], pauldron)
            pygame.draw.polygon(screen, p["armor"], pauldron, 1)

        # === 팔 ===
        arm_swing = int(arm_swing_anim * 3 * b)
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.2 * b) + lean_offset, torso_y + int(0.1 * b))
            elbow = (shoulder[0] + side * int(0.5 * b) + arm_swing * side, torso_y + int(0.8 * b))
            wrist = (elbow[0] + side * int(0.4 * b), torso_y + int(1.4 * b))
            pygame.draw.line(screen, p["kimono"], shoulder, elbow, max(2, int(0.5 * b)))
            pygame.draw.line(screen, p["skin"], elbow, wrist, max(2, int(0.45 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.3 * b)))

        # === 머리 ===
        head_y = torso_y - int(2.8 * b)
        head_w, head_h = int(2.0 * b), int(1.8 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        if show_back:
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            # 상투/묶은 머리
            pygame.draw.circle(screen, p["hair"], (head_rect.centerx, head_rect.top + int(0.3 * b)), int(0.4 * b))
        else:
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            face_rect = head_rect.inflate(-int(0.4 * b), -int(0.3 * b))
            face_rect.move_ip(0, int(0.2 * b))
            pygame.draw.ellipse(screen, p["skin"], face_rect)
            # 귀기 눈 (보라색 빛)
            eye_y = face_rect.centery - int(0.1 * b)
            pygame.draw.circle(screen, p["eye_glow"], (face_rect.centerx - int(0.25 * b), eye_y), max(1, int(0.12 * b)))
            pygame.draw.circle(screen, p["eye_glow"], (face_rect.centerx + int(0.25 * b), eye_y), max(1, int(0.12 * b)))
            # 앞머리
            for i in range(3):
                hx = face_rect.centerx + (i - 1) * int(0.25 * b)
                pygame.draw.line(screen, p["hair"], (hx, head_rect.top + int(0.1 * b)),
                               (hx + (i - 1) * int(0.1 * b), face_rect.top + int(0.2 * b)), 2)

        # === 귀검 (보라색 검기) ===
        sword_x = cx + int(2.2 * b) + lean_offset
        sword_top = head_y - int(0.5 * b)
        sword_bottom = cy + int(2.0 * b)
        # 검신
        pygame.draw.line(screen, p["sword_blade"], (sword_x, sword_top), (sword_x, sword_bottom), max(2, int(0.3 * b)))
        # 검기 글로우
        glow_offset = int(math.sin(self.time * 8) * 3)
        for i in range(3):
            alpha_surf = pygame.Surface((int(0.6 * b), sword_bottom - sword_top), pygame.SRCALPHA)
            glow_alpha = 80 - i * 25
            pygame.draw.line(alpha_surf, (*p["sword_glow"], glow_alpha),
                           (int(0.3 * b) + glow_offset, 0), (int(0.3 * b) - glow_offset, sword_bottom - sword_top), 2 + i)
            screen.blit(alpha_surf, (sword_x - int(0.3 * b), sword_top), special_flags=pygame.BLEND_ADD)
        # 검 끝
        pygame.draw.polygon(screen, p["sword_blade"], [
            (sword_x, sword_top - int(0.5 * b)),
            (sword_x - int(0.2 * b), sword_top),
            (sword_x + int(0.2 * b), sword_top),
        ])
        # 손잡이
        pygame.draw.rect(screen, p["sword_hilt"], (sword_x - int(0.15 * b), sword_bottom, int(0.3 * b), int(0.5 * b)))

    # =========================================================================
    # 크라켄 - 심해의 포식자 (촉수 괴물 하이브리드)
    # =========================================================================
    def _draw_kraken(self, screen, cx, cy, b, color, show_back, anim):
        """크라켄 - 심해의 포식자 (촉수 괴물 하이브리드)"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        p = {
            "body": color,
            "body_light": tuple(min(255, c + 40) for c in color),
            "body_dark": tuple(max(0, c - 40) for c in color),
            "tentacle": tuple(max(0, c - 20) for c in color),
            "tentacle_sucker": (180, 140, 160),
            "eye": (200, 255, 200),  # 발광 눈
            "eye_pupil": (20, 80, 60),
            "glow": (100, 200, 180),
            "teeth": (220, 220, 200),
            "barnacle": (140, 130, 120),
        }

        # === 촉수 다리 (4개) ===
        hip_y = torso_y + int(1.8 * b)
        for i, side in enumerate([-1.5, -0.5, 0.5, 1.5]):
            tentacle_wave = math.sin(self.time * 3 + i) * 0.3
            base_x = cx + int(side * 0.5 * b) + lean_offset
            # 촉수 세그먼트
            points = []
            for seg in range(5):
                seg_y = hip_y + seg * int(0.5 * b)
                seg_x = base_x + int(math.sin(self.time * 4 + i + seg * 0.5) * 0.3 * b * (seg / 3))
                points.append((seg_x, seg_y))
            # 촉수 그리기
            if len(points) >= 2:
                pygame.draw.lines(screen, p["tentacle"], False, points, max(2, int(0.5 * b) - i // 2))
            # 빨판
            for seg in range(1, 4):
                sx, sy = points[seg]
                pygame.draw.circle(screen, p["tentacle_sucker"], (int(sx), int(sy)), max(1, int(0.15 * b)))

        # === 몸통 (불규칙한 형태) ===
        chest_w, chest_h = int(3.0 * b), int(2.2 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.3 * b), chest_w, chest_h)
        pygame.draw.ellipse(screen, p["body"], chest_rect)
        pygame.draw.ellipse(screen, p["body_light"], chest_rect.inflate(-int(0.5 * b), -int(0.4 * b)))
        # 반점/물결 무늬
        for i in range(4):
            spot_x = chest_rect.left + int((i + 0.5) * 0.6 * b)
            spot_y = chest_rect.centery + int(math.sin(i) * 0.3 * b)
            pygame.draw.circle(screen, p["body_dark"], (spot_x, spot_y), max(2, int(0.2 * b)))

        # 따개비 장식
        for i in range(3):
            bx = chest_rect.left + int(0.5 * b) + i * int(0.8 * b)
            by = chest_rect.bottom - int(0.4 * b)
            pygame.draw.circle(screen, p["barnacle"], (bx, by), max(2, int(0.15 * b)))

        # === 팔 촉수 (양쪽) ===
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.3 * b) + lean_offset, torso_y + int(0.2 * b))
            # 팔 촉수 웨이브
            arm_points = []
            for seg in range(6):
                ax = shoulder[0] + side * seg * int(0.3 * b) + int(math.sin(self.time * 5 + seg) * 0.2 * b)
                ay = shoulder[1] + seg * int(0.25 * b) + int(math.cos(self.time * 4 + seg) * 0.1 * b)
                arm_points.append((int(ax), int(ay)))
            if len(arm_points) >= 2:
                pygame.draw.lines(screen, p["tentacle"], False, arm_points, max(3, int(0.6 * b)))
            # 팔 끝 빨판
            if arm_points:
                last = arm_points[-1]
                pygame.draw.circle(screen, p["tentacle_sucker"], last, max(2, int(0.25 * b)))

        # === 머리 (오징어/문어 형태) ===
        head_y = torso_y - int(3.2 * b)
        head_w, head_h = int(2.6 * b), int(2.4 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        # 머리 본체 (둥근 돔 형태)
        pygame.draw.ellipse(screen, p["body"], head_rect)
        pygame.draw.ellipse(screen, p["body_light"], head_rect.inflate(-int(0.4 * b), -int(0.3 * b)))

        if show_back:
            # 뒷모습 - 머리 뒷면 패턴
            for i in range(3):
                for j in range(2):
                    px = head_rect.centerx + (i - 1) * int(0.5 * b)
                    py = head_rect.centery + (j - 0.5) * int(0.4 * b)
                    pygame.draw.circle(screen, p["body_dark"], (px, py), max(1, int(0.15 * b)))
        else:
            # 정면 - 큰 눈 (발광)
            eye_y = head_rect.centery - int(0.1 * b)
            for side in [-1, 1]:
                eye_x = head_rect.centerx + side * int(0.5 * b)
                # 눈 글로우
                glow_surf = pygame.Surface((int(0.8 * b), int(0.8 * b)), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*p["glow"], 60), (int(0.4 * b), int(0.4 * b)), int(0.4 * b))
                screen.blit(glow_surf, (eye_x - int(0.4 * b), eye_y - int(0.4 * b)), special_flags=pygame.BLEND_ADD)
                # 눈 본체
                pygame.draw.ellipse(screen, p["eye"], (eye_x - int(0.3 * b), eye_y - int(0.25 * b), int(0.6 * b), int(0.5 * b)))
                # 동공 (가로로 긴 형태)
                pygame.draw.ellipse(screen, p["eye_pupil"], (eye_x - int(0.15 * b), eye_y - int(0.1 * b), int(0.3 * b), int(0.2 * b)))

            # 입 (이빨이 있는 부리)
            mouth_y = head_rect.bottom - int(0.5 * b)
            pygame.draw.polygon(screen, p["body_dark"], [
                (head_rect.centerx - int(0.3 * b), mouth_y),
                (head_rect.centerx + int(0.3 * b), mouth_y),
                (head_rect.centerx, mouth_y + int(0.3 * b)),
            ])
            # 이빨
            for i in range(3):
                tx = head_rect.centerx + (i - 1) * int(0.15 * b)
                pygame.draw.line(screen, p["teeth"], (tx, mouth_y), (tx, mouth_y + int(0.15 * b)), 1)

    # =========================================================================
    # 크로노스 - 시간술사 (시계/톱니바퀴 테마)
    # =========================================================================
    def _draw_chronos(self, screen, cx, cy, b, color, show_back, anim):
        """크로노스 - 시간술사 (시간을 조종하는 마법사)"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        p = {
            "robe": (60, 50, 80),  # 어두운 보라 로브
            "robe_light": (90, 70, 120),
            "gold": color,
            "gold_light": tuple(min(255, c + 50) for c in color),
            "gold_dark": tuple(max(0, c - 50) for c in color),
            "skin": (200, 185, 170),  # 창백한 피부
            "eye": (180, 200, 255),  # 시간의 눈
            "clock": (220, 210, 180),
            "gear": (180, 160, 120),
            "glow": (255, 220, 150),
        }

        # === 로브 하단 (시계추 장식) ===
        robe_points = [
            (cx - int(1.3 * b) + lean_offset, torso_y + int(1.6 * b)),
            (cx + int(1.3 * b) + lean_offset, torso_y + int(1.6 * b)),
            (cx + int(1.8 * b) + lean_offset + int(wave * 0.2 * b), cy + int(3.0 * b)),
            (cx - int(1.8 * b) + lean_offset - int(wave * 0.2 * b), cy + int(3.0 * b)),
        ]
        pygame.draw.polygon(screen, p["robe"], robe_points)
        # 로브 금색 테두리
        pygame.draw.line(screen, p["gold"], robe_points[0], robe_points[3], 2)
        pygame.draw.line(screen, p["gold"], robe_points[1], robe_points[2], 2)
        # 시계추 (로브 아래에 흔들림)
        pendulum_x = cx + lean_offset + int(math.sin(self.time * 2) * 0.4 * b)
        pendulum_y = cy + int(2.5 * b)
        pygame.draw.line(screen, p["gold_dark"], (cx + lean_offset, torso_y + int(2.0 * b)), (pendulum_x, pendulum_y), 1)
        pygame.draw.circle(screen, p["gold"], (pendulum_x, pendulum_y), max(2, int(0.25 * b)))

        # === 몸통 (톱니바퀴 장식 로브) ===
        chest_w, chest_h = int(2.8 * b), int(2.0 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.3 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["robe"], chest_rect, border_radius=int(0.4 * b))
        pygame.draw.rect(screen, p["robe_light"], chest_rect.inflate(-int(0.4 * b), -int(0.3 * b)), border_radius=3)

        # 가슴 톱니바퀴 장식
        gear_cx, gear_cy = chest_rect.centerx, chest_rect.centery
        gear_r = int(0.5 * b)
        # 회전하는 톱니바퀴
        gear_angle = self.time * 2
        for i in range(8):
            angle = gear_angle + i * math.pi / 4
            tx = gear_cx + int(math.cos(angle) * gear_r * 0.8)
            ty = gear_cy + int(math.sin(angle) * gear_r * 0.8)
            pygame.draw.circle(screen, p["gear"], (tx, ty), max(1, int(0.1 * b)))
        pygame.draw.circle(screen, p["gold"], (gear_cx, gear_cy), max(2, int(0.35 * b)))
        pygame.draw.circle(screen, p["gold_light"], (gear_cx, gear_cy), max(1, int(0.2 * b)))

        # 허리띠 (시계 장식)
        belt_rect = pygame.Rect(cx - int(1.3 * b) + lean_offset, chest_rect.bottom - 2, int(2.6 * b), int(0.7 * b))
        pygame.draw.rect(screen, p["gold_dark"], belt_rect, border_radius=2)

        # === 어깨 (시계 모양) ===
        for side in [-1, 1]:
            shoulder_x = cx + side * int(1.2 * b) + lean_offset
            shoulder_y = torso_y - int(0.2 * b)
            pygame.draw.circle(screen, p["gold"], (shoulder_x, shoulder_y), max(3, int(0.5 * b)))
            pygame.draw.circle(screen, p["clock"], (shoulder_x, shoulder_y), max(2, int(0.35 * b)))
            # 시계 바늘
            hand_angle = self.time * 3 * side
            hx = shoulder_x + int(math.cos(hand_angle) * 0.25 * b)
            hy = shoulder_y + int(math.sin(hand_angle) * 0.25 * b)
            pygame.draw.line(screen, p["gold_dark"], (shoulder_x, shoulder_y), (hx, hy), 1)

        # === 팔 (늙은 현자) ===
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.1 * b) + lean_offset, torso_y + int(0.2 * b))
            elbow = (shoulder[0] + side * int(0.4 * b), torso_y + int(0.9 * b))
            wrist = (elbow[0] + side * int(0.3 * b), torso_y + int(1.5 * b))
            pygame.draw.line(screen, p["robe"], shoulder, elbow, max(2, int(0.5 * b)))
            pygame.draw.line(screen, p["robe_light"], elbow, wrist, max(2, int(0.45 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.3 * b)))

        # === 머리 (후드 + 시간의 눈) ===
        head_y = torso_y - int(2.8 * b)
        head_w, head_h = int(2.2 * b), int(2.0 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        # 후드
        hood_points = [
            (head_rect.left - int(0.2 * b), head_rect.bottom),
            (head_rect.left + int(0.3 * b), head_rect.top - int(0.2 * b)),
            (head_rect.centerx, head_rect.top - int(0.5 * b)),
            (head_rect.right - int(0.3 * b), head_rect.top - int(0.2 * b)),
            (head_rect.right + int(0.2 * b), head_rect.bottom),
        ]
        pygame.draw.polygon(screen, p["robe"], hood_points)

        if show_back:
            # 뒷모습 - 후드 뒷면
            pygame.draw.polygon(screen, p["robe_light"], hood_points, 1)
            # 모래시계 문양
            hg_cx, hg_cy = head_rect.centerx, head_rect.centery
            pygame.draw.polygon(screen, p["gold"], [
                (hg_cx - int(0.2 * b), hg_cy - int(0.3 * b)),
                (hg_cx + int(0.2 * b), hg_cy - int(0.3 * b)),
                (hg_cx, hg_cy),
            ])
            pygame.draw.polygon(screen, p["gold"], [
                (hg_cx, hg_cy),
                (hg_cx - int(0.2 * b), hg_cy + int(0.3 * b)),
                (hg_cx + int(0.2 * b), hg_cy + int(0.3 * b)),
            ])
        else:
            # 정면 - 얼굴
            face_rect = head_rect.inflate(-int(0.5 * b), -int(0.4 * b))
            face_rect.move_ip(0, int(0.2 * b))
            pygame.draw.ellipse(screen, p["skin"], face_rect)
            # 시간의 눈 (시계 무늬 홍채)
            eye_y = face_rect.centery - int(0.1 * b)
            for side in [-1, 1]:
                eye_x = face_rect.centerx + side * int(0.25 * b)
                pygame.draw.circle(screen, p["eye"], (eye_x, eye_y), max(2, int(0.15 * b)))
                # 시계 바늘 홍채
                needle_angle = self.time * 4
                nx = eye_x + int(math.cos(needle_angle) * 0.08 * b)
                ny = eye_y + int(math.sin(needle_angle) * 0.08 * b)
                pygame.draw.line(screen, p["gold_dark"], (eye_x, eye_y), (nx, ny), 1)
            # 긴 수염
            beard_points = [
                (face_rect.centerx - int(0.3 * b), face_rect.bottom - int(0.2 * b)),
                (face_rect.centerx + int(0.3 * b), face_rect.bottom - int(0.2 * b)),
                (face_rect.centerx, face_rect.bottom + int(0.6 * b)),
            ]
            pygame.draw.polygon(screen, (200, 200, 210), beard_points)

        # === 시간의 지팡이 (모래시계 장식) ===
        staff_x = cx + int(2.3 * b) + lean_offset
        staff_top = head_y - int(0.3 * b)
        staff_bottom = cy + int(2.5 * b)
        pygame.draw.line(screen, p["gold_dark"], (staff_x, staff_top), (staff_x, staff_bottom), max(2, int(0.25 * b)))
        # 모래시계 장식
        hourglass_y = staff_top - int(0.6 * b)
        hourglass_h = int(0.8 * b)
        # 상단 삼각형
        pygame.draw.polygon(screen, p["clock"], [
            (staff_x - int(0.3 * b), hourglass_y),
            (staff_x + int(0.3 * b), hourglass_y),
            (staff_x, hourglass_y + hourglass_h // 2),
        ])
        # 하단 삼각형
        pygame.draw.polygon(screen, p["clock"], [
            (staff_x, hourglass_y + hourglass_h // 2),
            (staff_x - int(0.3 * b), hourglass_y + hourglass_h),
            (staff_x + int(0.3 * b), hourglass_y + hourglass_h),
        ])
        # 모래 입자 애니메이션
        sand_y = hourglass_y + int((self.time % 1) * hourglass_h * 0.4) + hourglass_h // 2
        pygame.draw.circle(screen, p["glow"], (staff_x, int(sand_y)), 1)

    # =========================================================================
    # 오니마루 - 지옥의 요괴무사 (뿔 달린 도깨비)
    # =========================================================================
    def _draw_onimaru(self, screen, cx, cy, b, color, show_back, anim):
        """오니마루 - 지옥의 요괴무사 (동양풍 도깨비 전사)"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        arm_swing_anim = anim["arm_swing"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        p = {
            "skin": color,  # 붉은 피부
            "skin_light": tuple(min(255, c + 40) for c in color),
            "skin_dark": tuple(max(0, c - 50) for c in color),
            "horn": (80, 70, 60),  # 뿔 색
            "horn_light": (120, 100, 80),
            "armor": (60, 50, 70),  # 어두운 갑옷
            "armor_gold": (180, 150, 80),
            "hair": (20, 20, 30),  # 검은 머리
            "eye": (255, 220, 50),  # 노란 눈
            "eye_glow": (255, 150, 50),
            "fangs": (255, 255, 240),
            "club": (100, 80, 60),  # 금봉
            "club_metal": (200, 170, 80),
            "flame": (255, 100, 50),
        }

        # === 다리 (근육질 다리) ===
        hip_y = torso_y + int(2.0 * b)
        for side in [-1, 1]:
            leg_phase = int(abs(wave) * 1.5) if side == 1 else 0
            thigh_x = cx + side * int(0.5 * b) + lean_offset
            # 허벅지 (호피무늬 천)
            thigh_rect = pygame.Rect(thigh_x - int(0.5 * b), hip_y + leg_phase, int(1.0 * b), int(1.8 * b))
            pygame.draw.rect(screen, (180, 150, 80), thigh_rect, border_radius=3)
            # 호피 무늬
            for i in range(2):
                spot_x = thigh_rect.centerx + (i - 0.5) * int(0.3 * b)
                spot_y = thigh_rect.centery + i * int(0.4 * b)
                pygame.draw.circle(screen, (100, 80, 50), (int(spot_x), int(spot_y)), max(1, int(0.15 * b)))
            # 맨발
            foot_rect = pygame.Rect(thigh_x - int(0.4 * b), thigh_rect.bottom - 2, int(0.8 * b), int(0.5 * b))
            pygame.draw.ellipse(screen, p["skin_dark"], foot_rect)

        # === 몸통 (근육질 상체) ===
        chest_w, chest_h = int(3.0 * b), int(2.2 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.3 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["skin"], chest_rect, border_radius=int(0.5 * b))
        pygame.draw.rect(screen, p["skin_light"], chest_rect.inflate(-int(0.5 * b), -int(0.4 * b)), border_radius=4)
        # 근육 라인
        pygame.draw.line(screen, p["skin_dark"], (chest_rect.centerx, chest_rect.top + int(0.3 * b)),
                        (chest_rect.centerx, chest_rect.bottom - int(0.3 * b)), 2)
        pygame.draw.arc(screen, p["skin_dark"],
                       (chest_rect.left + int(0.3 * b), chest_rect.top + int(0.2 * b), int(1.0 * b), int(0.8 * b)),
                       math.radians(0), math.radians(180), 1)
        pygame.draw.arc(screen, p["skin_dark"],
                       (chest_rect.right - int(1.3 * b), chest_rect.top + int(0.2 * b), int(1.0 * b), int(0.8 * b)),
                       math.radians(0), math.radians(180), 1)

        # 허리 천 (호피무늬)
        belt_rect = pygame.Rect(cx - int(1.3 * b) + lean_offset, chest_rect.bottom - 2, int(2.6 * b), int(0.8 * b))
        pygame.draw.rect(screen, (180, 150, 80), belt_rect, border_radius=2)
        pygame.draw.rect(screen, p["armor_gold"], belt_rect, 1, border_radius=2)

        # === 어깨 갑옷 (스파이크) ===
        for side in [-1, 1]:
            shoulder_x = cx + side * int(1.3 * b) + lean_offset
            shoulder_y = torso_y - int(0.3 * b)
            pygame.draw.circle(screen, p["armor"], (shoulder_x, shoulder_y), max(3, int(0.5 * b)))
            # 스파이크
            for i in range(3):
                spike_angle = (side * 0.5 + (i - 1) * 0.4) * math.pi / 2
                spike_x = shoulder_x + int(math.cos(spike_angle) * 0.6 * b)
                spike_y = shoulder_y + int(math.sin(spike_angle) * 0.6 * b)
                pygame.draw.line(screen, p["armor_gold"], (shoulder_x, shoulder_y), (spike_x, spike_y), 2)

        # === 팔 (근육질) ===
        arm_swing = int(arm_swing_anim * 3 * b)
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.4 * b) + lean_offset, torso_y + int(0.2 * b))
            elbow = (shoulder[0] + side * int(0.6 * b) + arm_swing * side, torso_y + int(1.0 * b))
            wrist = (elbow[0] + side * int(0.4 * b), torso_y + int(1.6 * b))
            pygame.draw.line(screen, p["skin"], shoulder, elbow, max(3, int(0.7 * b)))
            pygame.draw.line(screen, p["skin_light"], elbow, wrist, max(3, int(0.6 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(3, int(0.4 * b)))

        # === 머리 (오니 마스크) ===
        head_y = torso_y - int(3.0 * b)
        head_w, head_h = int(2.4 * b), int(2.2 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        # 머리카락 (거친 검은 머리)
        pygame.draw.ellipse(screen, p["hair"], head_rect.inflate(int(0.3 * b), int(0.2 * b)))

        # 뿔 (좌우 양쪽)
        for side in [-1, 1]:
            horn_base_x = head_rect.centerx + side * int(0.5 * b)
            horn_base_y = head_rect.top + int(0.3 * b)
            horn_tip_x = horn_base_x + side * int(0.6 * b)
            horn_tip_y = horn_base_y - int(0.8 * b)
            # 뿔 본체
            horn_points = [
                (horn_base_x - side * int(0.15 * b), horn_base_y),
                (horn_base_x + side * int(0.15 * b), horn_base_y),
                (horn_tip_x, horn_tip_y),
            ]
            pygame.draw.polygon(screen, p["horn"], horn_points)
            pygame.draw.polygon(screen, p["horn_light"], horn_points, 1)
            # 뿔 고리 무늬
            for i in range(2):
                ring_y = horn_base_y - int((i + 1) * 0.25 * b)
                ring_x = horn_base_x + side * int((i + 1) * 0.2 * b)
                pygame.draw.line(screen, p["horn_light"], (ring_x - int(0.1 * b), ring_y),
                               (ring_x + int(0.1 * b), ring_y), 1)

        if show_back:
            # 뒷모습 - 머리카락
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            # 머리카락 줄기
            for i in range(5):
                hx = head_rect.centerx + (i - 2) * int(0.3 * b)
                pygame.draw.line(screen, (40, 40, 50), (hx, head_rect.top + int(0.2 * b)),
                               (hx + (i - 2) * int(0.1 * b), head_rect.bottom - int(0.1 * b)), 2)
        else:
            # 정면 - 오니 얼굴
            face_rect = head_rect.inflate(-int(0.3 * b), -int(0.2 * b))
            face_rect.move_ip(0, int(0.15 * b))
            pygame.draw.ellipse(screen, p["skin"], face_rect)
            # 눈 (노란 빛, 사나운 표정)
            eye_y = face_rect.centery - int(0.15 * b)
            for side in [-1, 1]:
                eye_x = face_rect.centerx + side * int(0.35 * b)
                # 눈 글로우
                pygame.draw.circle(screen, p["eye_glow"], (eye_x, eye_y), max(2, int(0.2 * b)))
                pygame.draw.circle(screen, p["eye"], (eye_x, eye_y), max(2, int(0.15 * b)))
                # 눈썹 (사나운)
                brow_start = (eye_x - side * int(0.2 * b), eye_y - int(0.2 * b))
                brow_end = (eye_x + side * int(0.15 * b), eye_y - int(0.1 * b))
                pygame.draw.line(screen, p["hair"], brow_start, brow_end, 2)
            # 코
            pygame.draw.circle(screen, p["skin_dark"], (face_rect.centerx, face_rect.centery + int(0.1 * b)), max(1, int(0.1 * b)))
            # 입 (이빨 드러냄)
            mouth_y = face_rect.bottom - int(0.35 * b)
            pygame.draw.arc(screen, p["skin_dark"],
                          (face_rect.centerx - int(0.4 * b), mouth_y - int(0.1 * b), int(0.8 * b), int(0.4 * b)),
                          math.radians(200), math.radians(340), 2)
            # 송곳니
            for side in [-1, 1]:
                fang_x = face_rect.centerx + side * int(0.25 * b)
                pygame.draw.polygon(screen, p["fangs"], [
                    (fang_x - int(0.05 * b), mouth_y),
                    (fang_x + int(0.05 * b), mouth_y),
                    (fang_x, mouth_y + int(0.2 * b)),
                ])

        # === 금봉 (쇠몽둥이) ===
        club_x = cx + int(2.5 * b) + lean_offset
        club_top = head_y + int(0.5 * b)
        club_bottom = cy + int(2.5 * b)
        # 몽둥이 자루
        pygame.draw.line(screen, p["club"], (club_x, club_top), (club_x, club_bottom), max(2, int(0.3 * b)))
        # 몽둥이 머리 (타원형 + 스파이크)
        club_head_y = club_top - int(0.5 * b)
        pygame.draw.ellipse(screen, p["club"], (club_x - int(0.4 * b), club_head_y, int(0.8 * b), int(0.9 * b)))
        pygame.draw.ellipse(screen, p["club_metal"], (club_x - int(0.3 * b), club_head_y + int(0.1 * b), int(0.6 * b), int(0.7 * b)))
        # 스파이크
        for i in range(4):
            angle = i * math.pi / 2 + math.pi / 4
            spike_x = club_x + int(math.cos(angle) * 0.5 * b)
            spike_y = club_head_y + int(0.45 * b) + int(math.sin(angle) * 0.4 * b)
            pygame.draw.circle(screen, p["club_metal"], (spike_x, spike_y), max(1, int(0.1 * b)))

    # =========================================================================
    # 마리아 - 인형사 (마리오네트를 조종하는 소녀)
    # =========================================================================
    def _draw_maria(self, screen, cx, cy, b, color, show_back, anim):
        """마리아 - 인형사 (기묘한 인형들을 조종하는 소녀)"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        p = {
            "dress": color,
            "dress_light": tuple(min(255, c + 40) for c in color),
            "dress_dark": tuple(max(0, c - 40) for c in color),
            "skin": (250, 235, 225),  # 창백한 피부
            "hair": (40, 30, 50),  # 어두운 보라 머리
            "hair_light": (70, 50, 90),
            "eye": (180, 100, 160),  # 보라색 눈
            "ribbon": (200, 80, 120),
            "string": (200, 200, 200),  # 마리오네트 실
            "puppet": (180, 160, 140),  # 인형 색
            "puppet_dark": (120, 100, 80),
        }

        # === 드레스 하단 (프릴) ===
        dress_points = [
            (cx - int(1.2 * b) + lean_offset, torso_y + int(1.6 * b)),
            (cx + int(1.2 * b) + lean_offset, torso_y + int(1.6 * b)),
            (cx + int(1.8 * b) + lean_offset + int(wave * 0.15 * b), cy + int(2.8 * b)),
            (cx - int(1.8 * b) + lean_offset - int(wave * 0.15 * b), cy + int(2.8 * b)),
        ]
        pygame.draw.polygon(screen, p["dress"], dress_points)
        # 프릴 레이어
        for i in range(3):
            frill_y = torso_y + int(1.8 * b) + i * int(0.4 * b)
            frill_w = int(1.4 * b) + i * int(0.2 * b)
            pygame.draw.arc(screen, p["dress_light"],
                          (cx - frill_w + lean_offset, frill_y, frill_w * 2, int(0.4 * b)),
                          math.radians(180), math.radians(360), 1)
        # 발끝
        for side in [-1, 1]:
            foot_x = cx + side * int(0.5 * b) + lean_offset
            pygame.draw.ellipse(screen, (60, 50, 70),
                              (foot_x - int(0.25 * b), cy + int(2.5 * b), int(0.5 * b), int(0.3 * b)))

        # === 몸통 (빅토리안 드레스) ===
        chest_w, chest_h = int(2.4 * b), int(1.8 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.2 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["dress"], chest_rect, border_radius=int(0.4 * b))
        pygame.draw.rect(screen, p["dress_light"], chest_rect.inflate(-int(0.4 * b), -int(0.3 * b)), border_radius=3)
        # 코르셋 라인
        for i in range(4):
            lace_y = chest_rect.top + int(0.3 * b) + i * int(0.35 * b)
            pygame.draw.line(screen, p["dress_dark"],
                           (chest_rect.centerx - int(0.3 * b), lace_y),
                           (chest_rect.centerx + int(0.3 * b), lace_y), 1)
        # 리본
        bow_cx, bow_cy = chest_rect.centerx, chest_rect.top + int(0.2 * b)
        pygame.draw.ellipse(screen, p["ribbon"], (bow_cx - int(0.4 * b), bow_cy - int(0.15 * b), int(0.35 * b), int(0.3 * b)))
        pygame.draw.ellipse(screen, p["ribbon"], (bow_cx + int(0.05 * b), bow_cy - int(0.15 * b), int(0.35 * b), int(0.3 * b)))
        pygame.draw.circle(screen, p["ribbon"], (bow_cx, bow_cy), max(1, int(0.1 * b)))

        # 허리띠
        belt_rect = pygame.Rect(cx - int(1.1 * b) + lean_offset, chest_rect.bottom - 2, int(2.2 * b), int(0.5 * b))
        pygame.draw.rect(screen, p["dress_dark"], belt_rect, border_radius=2)

        # === 어깨 퍼프 ===
        for side in [-1, 1]:
            puff_rect = pygame.Rect(
                cx + side * int(0.9 * b) + lean_offset - int(0.4 * b),
                torso_y - int(0.2 * b),
                int(0.8 * b), int(0.7 * b)
            )
            pygame.draw.ellipse(screen, p["dress_light"], puff_rect)

        # === 팔 + 마리오네트 실 ===
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.0 * b) + lean_offset, torso_y + int(0.1 * b))
            elbow = (shoulder[0] + side * int(0.4 * b), torso_y + int(0.7 * b))
            # 손 위치 (인형 조종 포즈)
            wrist = (elbow[0] + side * int(0.3 * b) + int(math.sin(self.time * 2 + side) * 0.2 * b),
                    torso_y + int(1.2 * b) + int(math.cos(self.time * 2 + side) * 0.1 * b))
            pygame.draw.line(screen, p["dress"], shoulder, elbow, max(2, int(0.4 * b)))
            pygame.draw.line(screen, p["skin"], elbow, wrist, max(2, int(0.35 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.25 * b)))

            # 마리오네트 실 (손가락에서 인형으로)
            puppet_y = torso_y + int(2.2 * b)
            puppet_x = wrist[0] + side * int(0.5 * b)
            for j in range(3):
                string_x = wrist[0] + (j - 1) * int(0.1 * b)
                target_x = puppet_x + (j - 1) * int(0.15 * b)
                pygame.draw.line(screen, p["string"], (string_x, wrist[1]), (target_x, puppet_y - int(0.3 * b)), 1)

        # === 작은 마리오네트 인형 (양쪽 아래) ===
        for side in [-1, 1]:
            puppet_x = cx + side * int(1.8 * b) + lean_offset
            puppet_y = torso_y + int(2.0 * b) + int(math.sin(self.time * 3 + side * 2) * 0.2 * b)
            # 인형 몸체
            pygame.draw.ellipse(screen, p["puppet"],
                              (puppet_x - int(0.25 * b), puppet_y, int(0.5 * b), int(0.6 * b)))
            # 인형 머리
            pygame.draw.circle(screen, p["puppet"], (puppet_x, puppet_y - int(0.15 * b)), max(2, int(0.2 * b)))
            pygame.draw.circle(screen, p["puppet_dark"], (puppet_x, puppet_y - int(0.15 * b)), max(1, int(0.15 * b)))
            # 인형 눈 (X자 - 무서운 느낌)
            eye_x, eye_y = puppet_x, puppet_y - int(0.15 * b)
            pygame.draw.line(screen, (30, 30, 30), (eye_x - 2, eye_y - 2), (eye_x + 2, eye_y + 2), 1)
            pygame.draw.line(screen, (30, 30, 30), (eye_x - 2, eye_y + 2), (eye_x + 2, eye_y - 2), 1)

        # === 머리 (긴 머리 + 리본) ===
        head_y = torso_y - int(2.6 * b)
        head_w, head_h = int(2.0 * b), int(1.8 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        # 긴 머리카락 (양쪽으로 늘어짐)
        for side in [-1, 1]:
            hair_x = head_rect.centerx + side * int(0.7 * b)
            hair_points = [
                (hair_x - int(0.3 * b), head_rect.centery),
                (hair_x + int(0.3 * b), head_rect.centery),
                (hair_x + side * int(0.1 * b) + int(wave * 0.1 * b * side), torso_y + int(1.0 * b)),
            ]
            pygame.draw.polygon(screen, p["hair"], hair_points)

        if show_back:
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            # 리본 (뒤에서 보이는 부분)
            pygame.draw.circle(screen, p["ribbon"], (head_rect.centerx, head_rect.top + int(0.3 * b)), max(2, int(0.2 * b)))
        else:
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            # 얼굴
            face_rect = head_rect.inflate(-int(0.4 * b), -int(0.3 * b))
            face_rect.move_ip(0, int(0.15 * b))
            pygame.draw.ellipse(screen, p["skin"], face_rect)
            # 큰 눈 (인형같은)
            eye_y = face_rect.centery - int(0.1 * b)
            for side in [-1, 1]:
                eye_x = face_rect.centerx + side * int(0.25 * b)
                pygame.draw.ellipse(screen, (255, 255, 255),
                                   (eye_x - int(0.15 * b), eye_y - int(0.12 * b), int(0.3 * b), int(0.25 * b)))
                pygame.draw.circle(screen, p["eye"], (eye_x, eye_y), max(1, int(0.1 * b)))
                pygame.draw.circle(screen, (255, 255, 255), (eye_x - 1, eye_y - 1), 1)
            # 작은 입
            pygame.draw.line(screen, (180, 130, 140),
                           (face_rect.centerx - int(0.1 * b), face_rect.bottom - int(0.25 * b)),
                           (face_rect.centerx + int(0.1 * b), face_rect.bottom - int(0.25 * b)), 1)
            # 앞머리
            for i in range(5):
                hx = face_rect.left + int(0.2 * b) + i * int(0.3 * b)
                pygame.draw.line(screen, p["hair"], (hx, head_rect.top + int(0.1 * b)),
                               (hx + (i - 2) * int(0.05 * b), face_rect.top + int(0.3 * b)), 2)
            # 머리 리본
            pygame.draw.ellipse(screen, p["ribbon"],
                              (head_rect.centerx - int(0.5 * b), head_rect.top - int(0.1 * b), int(0.4 * b), int(0.3 * b)))
            pygame.draw.ellipse(screen, p["ribbon"],
                              (head_rect.centerx + int(0.1 * b), head_rect.top - int(0.1 * b), int(0.4 * b), int(0.3 * b)))
            pygame.draw.circle(screen, p["ribbon"], (head_rect.centerx, head_rect.top + int(0.05 * b)), max(1, int(0.1 * b)))

    # =========================================================================
    # 이그니스 - 드래곤 나이트 (드래곤의 힘을 갑옷에 담은 용기사)
    # =========================================================================
    def _draw_ignis(self, screen, cx, cy, b, color, show_back, anim):
        """이그니스 - 드래곤 나이트 (드래곤 갑옷 + 불꽃)"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        arm_swing_anim = anim["arm_swing"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        p = {
            "armor": color,
            "armor_light": tuple(min(255, c + 40) for c in color),
            "armor_dark": tuple(max(0, c - 50) for c in color),
            "scale": tuple(max(0, c - 30) for c in color),
            "flame": (255, 150, 50),
            "flame_core": (255, 220, 100),
            "flame_edge": (255, 80, 30),
            "eye": (255, 200, 50),
            "eye_glow": (255, 100, 30),
            "horn": (80, 60, 50),
            "horn_light": (120, 90, 70),
            "cape": (40, 30, 50),
            "cape_edge": (100, 60, 30),
        }

        # === 망토 (뒤에서 펄럭임) ===
        cape_wave = math.sin(self.time * 3) * 0.2
        cape_points = [
            (cx - int(1.0 * b) + lean_offset, torso_y - int(0.5 * b)),
            (cx + int(1.0 * b) + lean_offset, torso_y - int(0.5 * b)),
            (cx + int(1.3 * b) + lean_offset + int(cape_wave * b), cy + int(2.5 * b)),
            (cx - int(1.3 * b) + lean_offset - int(cape_wave * b), cy + int(2.5 * b)),
        ]
        pygame.draw.polygon(screen, p["cape"], cape_points)
        pygame.draw.polygon(screen, p["cape_edge"], cape_points, 1)

        # === 다리 (드래곤 비늘 갑옷) ===
        hip_y = torso_y + int(2.0 * b)
        for side in [-1, 1]:
            leg_phase = int(abs(wave) * 1.5) if side == 1 else 0
            thigh_x = cx + side * int(0.5 * b) + lean_offset
            # 허벅지
            thigh_rect = pygame.Rect(thigh_x - int(0.45 * b), hip_y + leg_phase, int(0.9 * b), int(1.8 * b))
            pygame.draw.rect(screen, p["armor"], thigh_rect, border_radius=3)
            # 비늘 패턴
            for i in range(3):
                scale_y = thigh_rect.top + int(0.3 * b) + i * int(0.5 * b)
                pygame.draw.arc(screen, p["scale"],
                              (thigh_rect.left + 2, scale_y, thigh_rect.width - 4, int(0.3 * b)),
                              math.radians(0), math.radians(180), 1)
            # 무릎 (드래곤 발톱 장식)
            knee_rect = pygame.Rect(thigh_x - int(0.4 * b), thigh_rect.bottom - int(0.2 * b), int(0.8 * b), int(0.5 * b))
            pygame.draw.rect(screen, p["armor_dark"], knee_rect, border_radius=2)
            # 부츠
            boot_rect = pygame.Rect(thigh_x - int(0.4 * b), knee_rect.bottom, int(0.8 * b), int(0.8 * b))
            pygame.draw.rect(screen, p["armor_dark"], boot_rect, border_radius=3)
            # 발톱
            for i in range(3):
                claw_x = boot_rect.left + int(0.2 * b) + i * int(0.2 * b)
                pygame.draw.polygon(screen, p["horn"], [
                    (claw_x, boot_rect.bottom),
                    (claw_x - int(0.05 * b), boot_rect.bottom + int(0.15 * b)),
                    (claw_x + int(0.05 * b), boot_rect.bottom + int(0.15 * b)),
                ])

        # === 몸통 (드래곤 비늘 갑옷) ===
        chest_w, chest_h = int(2.8 * b), int(2.0 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.3 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["armor"], chest_rect, border_radius=int(0.4 * b))
        pygame.draw.rect(screen, p["armor_light"], chest_rect.inflate(-int(0.4 * b), -int(0.3 * b)), border_radius=4)
        # 가슴 비늘 패턴
        for i in range(4):
            for j in range(2):
                scale_x = chest_rect.left + int(0.5 * b) + i * int(0.5 * b)
                scale_y = chest_rect.top + int(0.4 * b) + j * int(0.5 * b)
                pygame.draw.arc(screen, p["scale"],
                              (scale_x, scale_y, int(0.4 * b), int(0.3 * b)),
                              math.radians(0), math.radians(180), 1)
        # 가슴 드래곤 문양 (불꽃 모양)
        emblem_cx, emblem_cy = chest_rect.centerx, chest_rect.centery
        pygame.draw.polygon(screen, p["flame"], [
            (emblem_cx, emblem_cy - int(0.4 * b)),
            (emblem_cx - int(0.25 * b), emblem_cy + int(0.2 * b)),
            (emblem_cx, emblem_cy),
            (emblem_cx + int(0.25 * b), emblem_cy + int(0.2 * b)),
        ])

        # 허리 벨트
        belt_rect = pygame.Rect(cx - int(1.4 * b) + lean_offset, chest_rect.bottom - 2, int(2.8 * b), int(0.6 * b))
        pygame.draw.rect(screen, p["armor_dark"], belt_rect, border_radius=2)
        # 벨트 버클 (드래곤 눈)
        pygame.draw.circle(screen, p["eye"], (belt_rect.centerx, belt_rect.centery), max(2, int(0.2 * b)))

        # === 어깨 갑옷 (드래곤 날개 형태) ===
        for side in [-1, 1]:
            shoulder_x = cx + side * int(1.2 * b) + lean_offset
            shoulder_y = torso_y - int(0.3 * b)
            # 어깨 본체
            pygame.draw.ellipse(screen, p["armor"],
                              (shoulder_x - int(0.5 * b), shoulder_y - int(0.3 * b), int(1.0 * b), int(0.8 * b)))
            # 스파이크/뿔 장식
            spike_angle = side * 0.3
            spike_x = shoulder_x + side * int(0.5 * b)
            spike_y = shoulder_y - int(0.4 * b)
            pygame.draw.polygon(screen, p["horn"], [
                (shoulder_x, shoulder_y - int(0.1 * b)),
                (spike_x + side * int(0.2 * b), spike_y - int(0.3 * b)),
                (spike_x, spike_y),
            ])

        # === 팔 ===
        arm_swing = int(arm_swing_anim * 2.5 * b)
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.3 * b) + lean_offset, torso_y + int(0.2 * b))
            elbow = (shoulder[0] + side * int(0.5 * b) + arm_swing * side, torso_y + int(0.9 * b))
            wrist = (elbow[0] + side * int(0.4 * b), torso_y + int(1.5 * b))
            pygame.draw.line(screen, p["armor"], shoulder, elbow, max(3, int(0.6 * b)))
            pygame.draw.line(screen, p["armor_light"], elbow, wrist, max(2, int(0.5 * b)))
            # 드래곤 발톱 장갑
            pygame.draw.circle(screen, p["armor_dark"], wrist, max(2, int(0.35 * b)))
            for i in range(3):
                claw_angle = side * (0.3 + i * 0.2)
                claw_x = wrist[0] + int(math.cos(claw_angle) * 0.3 * b)
                claw_y = wrist[1] + int(math.sin(claw_angle + math.pi/2) * 0.2 * b) + int(0.15 * b)
                pygame.draw.line(screen, p["horn"], wrist, (claw_x, claw_y), 1)

        # === 드래곤 헬멧 ===
        head_y = torso_y - int(3.0 * b)
        head_w, head_h = int(2.4 * b), int(2.2 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        # 헬멧 본체
        pygame.draw.ellipse(screen, p["armor"], head_rect)
        pygame.draw.ellipse(screen, p["armor_light"], head_rect.inflate(-int(0.4 * b), -int(0.3 * b)))

        # 드래곤 뿔 (양쪽)
        for side in [-1, 1]:
            horn_base_x = head_rect.centerx + side * int(0.6 * b)
            horn_base_y = head_rect.top + int(0.4 * b)
            horn_tip_x = horn_base_x + side * int(0.5 * b)
            horn_tip_y = horn_base_y - int(0.7 * b)
            pygame.draw.polygon(screen, p["horn"], [
                (horn_base_x - int(0.1 * b), horn_base_y),
                (horn_base_x + int(0.1 * b), horn_base_y),
                (horn_tip_x, horn_tip_y),
            ])
            pygame.draw.polygon(screen, p["horn_light"], [
                (horn_base_x - int(0.1 * b), horn_base_y),
                (horn_base_x + int(0.1 * b), horn_base_y),
                (horn_tip_x, horn_tip_y),
            ], 1)

        if show_back:
            # 뒷모습 - 헬멧 뒷면
            pygame.draw.ellipse(screen, p["armor_dark"], head_rect.inflate(-int(0.2 * b), -int(0.15 * b)))
            # 비늘 패턴
            for i in range(3):
                scale_y = head_rect.centery + (i - 1) * int(0.35 * b)
                pygame.draw.arc(screen, p["scale"],
                              (head_rect.centerx - int(0.4 * b), scale_y, int(0.8 * b), int(0.25 * b)),
                              math.radians(0), math.radians(180), 1)
        else:
            # 정면 - 드래곤 눈 바이저
            visor_rect = pygame.Rect(
                head_rect.centerx - int(0.7 * b),
                head_rect.centery - int(0.2 * b),
                int(1.4 * b), int(0.5 * b)
            )
            pygame.draw.rect(screen, p["armor_dark"], visor_rect, border_radius=2)
            # 빛나는 눈
            for side in [-1, 1]:
                eye_x = visor_rect.centerx + side * int(0.3 * b)
                eye_y = visor_rect.centery
                # 눈 글로우
                glow_surf = pygame.Surface((int(0.5 * b), int(0.4 * b)), pygame.SRCALPHA)
                pygame.draw.ellipse(glow_surf, (*p["eye_glow"], 100), (0, 0, int(0.5 * b), int(0.4 * b)))
                screen.blit(glow_surf, (eye_x - int(0.25 * b), eye_y - int(0.2 * b)), special_flags=pygame.BLEND_ADD)
                pygame.draw.ellipse(screen, p["eye"],
                                  (eye_x - int(0.15 * b), eye_y - int(0.1 * b), int(0.3 * b), int(0.2 * b)))
            # 코/입 부분 (드래곤 주둥이)
            pygame.draw.polygon(screen, p["armor_dark"], [
                (head_rect.centerx - int(0.2 * b), visor_rect.bottom),
                (head_rect.centerx + int(0.2 * b), visor_rect.bottom),
                (head_rect.centerx, head_rect.bottom - int(0.1 * b)),
            ])

        # === 불꽃 효과 (손 주변) ===
        flame_x = cx + int(2.2 * b) + lean_offset
        flame_y = torso_y + int(1.0 * b)
        for i in range(5):
            f_angle = self.time * 5 + i * 0.8
            f_x = flame_x + int(math.cos(f_angle) * 0.3 * b)
            f_y = flame_y - int(0.3 * b) + int(math.sin(f_angle * 2) * 0.2 * b) - i * int(0.15 * b)
            f_size = max(2, int(0.2 * b) - i)
            if f_size > 0:
                pygame.draw.circle(screen, p["flame_core"] if i < 2 else p["flame"], (f_x, f_y), f_size)

    # =========================================================================
    # 기어 - 스팀펑크 메카닉 (기계 팔과 톱니바퀴)
    # =========================================================================
    def _draw_gear(self, screen, cx, cy, b, color, show_back, anim):
        """기어 - 스팀펑크 메카닉 (증기 기관과 톱니바퀴로 무장)"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        arm_swing_anim = anim["arm_swing"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        p = {
            "metal": color,
            "metal_light": tuple(min(255, c + 50) for c in color),
            "metal_dark": tuple(max(0, c - 50) for c in color),
            "copper": (180, 100, 60),
            "copper_light": (220, 140, 90),
            "brass": (200, 170, 80),
            "brass_dark": (150, 120, 50),
            "leather": (80, 60, 50),
            "leather_light": (120, 90, 70),
            "skin": (220, 195, 175),
            "hair": (100, 80, 60),
            "eye": (150, 200, 220),  # 고글 렌즈
            "steam": (220, 220, 230),
            "gear": (160, 140, 100),
        }

        # === 다리 (기계식 다리) ===
        hip_y = torso_y + int(2.0 * b)
        for side in [-1, 1]:
            leg_phase = int(abs(wave) * 1.5) if side == 1 else 0
            thigh_x = cx + side * int(0.5 * b) + lean_offset
            # 허벅지 (가죽)
            thigh_rect = pygame.Rect(thigh_x - int(0.4 * b), hip_y + leg_phase, int(0.8 * b), int(1.6 * b))
            pygame.draw.rect(screen, p["leather"], thigh_rect, border_radius=3)
            pygame.draw.line(screen, p["leather_light"], (thigh_rect.left + 2, thigh_rect.centery),
                           (thigh_rect.right - 2, thigh_rect.centery), 1)
            # 무릎 조인트 (금속)
            knee_rect = pygame.Rect(thigh_x - int(0.35 * b), thigh_rect.bottom - int(0.2 * b), int(0.7 * b), int(0.5 * b))
            pygame.draw.rect(screen, p["copper"], knee_rect, border_radius=2)
            pygame.draw.circle(screen, p["brass"], (knee_rect.centerx, knee_rect.centery), max(2, int(0.15 * b)))
            # 부츠 (철제)
            boot_rect = pygame.Rect(thigh_x - int(0.4 * b), knee_rect.bottom, int(0.8 * b), int(0.8 * b))
            pygame.draw.rect(screen, p["metal_dark"], boot_rect, border_radius=2)
            # 톱니 장식
            for i in range(3):
                gear_x = boot_rect.left + int(0.15 * b) + i * int(0.25 * b)
                pygame.draw.circle(screen, p["gear"], (gear_x, boot_rect.centery), max(1, int(0.08 * b)))

        # === 몸통 (기계식 조끼) ===
        chest_w, chest_h = int(2.8 * b), int(2.0 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.3 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["leather"], chest_rect, border_radius=int(0.4 * b))
        pygame.draw.rect(screen, p["leather_light"], chest_rect.inflate(-int(0.4 * b), -int(0.3 * b)), border_radius=4)

        # 가슴 기계 장치
        device_rect = pygame.Rect(chest_rect.centerx - int(0.5 * b), chest_rect.centery - int(0.4 * b),
                                  int(1.0 * b), int(0.8 * b))
        pygame.draw.rect(screen, p["copper"], device_rect, border_radius=3)
        pygame.draw.rect(screen, p["copper_light"], device_rect.inflate(-4, -4), border_radius=2)
        # 게이지
        pygame.draw.circle(screen, p["brass"], (device_rect.centerx, device_rect.centery), max(2, int(0.25 * b)))
        pygame.draw.circle(screen, (60, 80, 60), (device_rect.centerx, device_rect.centery), max(1, int(0.18 * b)))
        # 게이지 바늘
        needle_angle = self.time * 2
        nx = device_rect.centerx + int(math.cos(needle_angle) * 0.12 * b)
        ny = device_rect.centery + int(math.sin(needle_angle) * 0.12 * b)
        pygame.draw.line(screen, (255, 100, 50), (device_rect.centerx, device_rect.centery), (nx, ny), 1)

        # 허리 벨트 (도구 벨트)
        belt_rect = pygame.Rect(cx - int(1.4 * b) + lean_offset, chest_rect.bottom - 2, int(2.8 * b), int(0.7 * b))
        pygame.draw.rect(screen, p["leather"], belt_rect, border_radius=2)
        # 도구/파우치
        for i in range(3):
            pouch_x = belt_rect.left + int(0.4 * b) + i * int(0.9 * b)
            pygame.draw.rect(screen, p["metal_dark"], (pouch_x, belt_rect.top + 2, int(0.4 * b), belt_rect.height - 4), border_radius=1)

        # === 어깨 (기계 장치) ===
        for side in [-1, 1]:
            shoulder_x = cx + side * int(1.2 * b) + lean_offset
            shoulder_y = torso_y - int(0.3 * b)
            # 어깨 패드
            pygame.draw.ellipse(screen, p["metal"],
                              (shoulder_x - int(0.5 * b), shoulder_y - int(0.3 * b), int(1.0 * b), int(0.8 * b)))
            # 톱니바퀴 장식
            gear_angle = self.time * 3 * side
            for i in range(6):
                angle = gear_angle + i * math.pi / 3
                gx = shoulder_x + int(math.cos(angle) * 0.35 * b)
                gy = shoulder_y + int(math.sin(angle) * 0.35 * b)
                pygame.draw.circle(screen, p["brass"], (gx, gy), max(1, int(0.08 * b)))
            pygame.draw.circle(screen, p["copper"], (shoulder_x, shoulder_y), max(2, int(0.2 * b)))

        # === 팔 (하나는 기계팔) ===
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.3 * b) + lean_offset, torso_y + int(0.2 * b))
            elbow = (shoulder[0] + side * int(0.5 * b), torso_y + int(0.9 * b))
            wrist = (elbow[0] + side * int(0.4 * b), torso_y + int(1.5 * b))

            if side == 1:  # 오른팔 - 기계팔
                # 상완 (피스톤)
                pygame.draw.line(screen, p["copper"], shoulder, elbow, max(3, int(0.6 * b)))
                pygame.draw.line(screen, p["brass"], shoulder, elbow, max(2, int(0.4 * b)))
                # 조인트
                pygame.draw.circle(screen, p["metal"], elbow, max(3, int(0.25 * b)))
                pygame.draw.circle(screen, p["brass"], elbow, max(2, int(0.15 * b)))
                # 전완 (기계)
                pygame.draw.line(screen, p["metal"], elbow, wrist, max(3, int(0.55 * b)))
                # 기계 손
                pygame.draw.circle(screen, p["metal_dark"], wrist, max(3, int(0.35 * b)))
                # 손가락 (집게)
                for i in range(3):
                    finger_angle = 0.3 + i * 0.3 + math.sin(self.time * 4) * 0.1
                    fx = wrist[0] + int(math.cos(finger_angle) * 0.4 * b)
                    fy = wrist[1] + int(math.sin(finger_angle) * 0.3 * b) + int(0.1 * b)
                    pygame.draw.line(screen, p["copper"], wrist, (fx, fy), max(1, int(0.1 * b)))
            else:  # 왼팔 - 일반 팔
                pygame.draw.line(screen, p["leather"], shoulder, elbow, max(2, int(0.5 * b)))
                pygame.draw.line(screen, p["skin"], elbow, wrist, max(2, int(0.4 * b)))
                pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.3 * b)))

        # === 머리 (고글) ===
        head_y = torso_y - int(2.8 * b)
        head_w, head_h = int(2.0 * b), int(1.8 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        if show_back:
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            # 고글 끈
            pygame.draw.line(screen, p["leather"], (head_rect.left + int(0.2 * b), head_rect.centery),
                           (head_rect.right - int(0.2 * b), head_rect.centery), 2)
        else:
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            # 얼굴
            face_rect = head_rect.inflate(-int(0.4 * b), -int(0.3 * b))
            face_rect.move_ip(0, int(0.15 * b))
            pygame.draw.ellipse(screen, p["skin"], face_rect)

            # 고글
            for side in [-1, 1]:
                goggle_x = face_rect.centerx + side * int(0.35 * b)
                goggle_y = face_rect.centery - int(0.1 * b)
                # 고글 프레임
                pygame.draw.circle(screen, p["copper"], (goggle_x, goggle_y), max(3, int(0.25 * b)))
                pygame.draw.circle(screen, p["brass"], (goggle_x, goggle_y), max(2, int(0.2 * b)), 1)
                # 렌즈
                pygame.draw.circle(screen, p["eye"], (goggle_x, goggle_y), max(2, int(0.18 * b)))
                # 반사광
                pygame.draw.circle(screen, (255, 255, 255), (goggle_x - 1, goggle_y - 1), 1)
            # 고글 브릿지
            pygame.draw.line(screen, p["copper"],
                           (face_rect.centerx - int(0.1 * b), face_rect.centery - int(0.1 * b)),
                           (face_rect.centerx + int(0.1 * b), face_rect.centery - int(0.1 * b)), 2)
            # 수염/턱 디테일
            pygame.draw.arc(screen, p["hair"],
                          (face_rect.centerx - int(0.3 * b), face_rect.bottom - int(0.4 * b), int(0.6 * b), int(0.3 * b)),
                          math.radians(200), math.radians(340), 1)
            # 모자
            hat_rect = pygame.Rect(head_rect.left + int(0.1 * b), head_rect.top - int(0.1 * b),
                                   head_rect.width - int(0.2 * b), int(0.5 * b))
            pygame.draw.rect(screen, p["leather"], hat_rect, border_radius=2)
            # 모자 고글 (올려져 있음)
            pygame.draw.ellipse(screen, p["copper"],
                              (head_rect.centerx - int(0.4 * b), head_rect.top - int(0.05 * b), int(0.35 * b), int(0.25 * b)))
            pygame.draw.ellipse(screen, p["copper"],
                              (head_rect.centerx + int(0.05 * b), head_rect.top - int(0.05 * b), int(0.35 * b), int(0.25 * b)))

        # === 증기 효과 ===
        steam_x = cx + int(1.8 * b) + lean_offset
        steam_y = torso_y
        for i in range(3):
            sx = steam_x + int(math.sin(self.time * 5 + i) * 0.15 * b)
            sy = steam_y - i * int(0.25 * b) - int((self.time * 2) % 1 * 0.3 * b)
            steam_size = max(1, int(0.15 * b) - i)
            if steam_size > 0:
                steam_surf = pygame.Surface((steam_size * 2, steam_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(steam_surf, (*p["steam"], 100 - i * 30), (steam_size, steam_size), steam_size)
                screen.blit(steam_surf, (sx - steam_size, sy - steam_size))

    # =========================================================================
    # 쿠로카게 - 그림자 닌자 (어둠 속에서 나타나는 암살자)
    # =========================================================================
    def _draw_kurokage(self, screen, cx, cy, b, color, show_back, anim):
        """쿠로카게 - 그림자 닌자 (빠르고 은밀한 닌자 암살자)"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        arm_swing_anim = anim["arm_swing"]

        torso_y = cy - int(1.5 * b) + int(body_bob * 2.5 * b)
        lean_offset = int(lean * 2.5 * b)

        p = {
            "cloth": color,
            "cloth_light": tuple(min(255, c + 30) for c in color),
            "cloth_dark": tuple(max(0, c - 30) for c in color),
            "skin": (220, 200, 180),
            "eye": (200, 50, 50),  # 붉은 눈
            "eye_glow": (255, 100, 100),
            "metal": (100, 100, 120),
            "metal_light": (140, 140, 160),
            "scarf": (40, 40, 60),
            "scarf_flow": (60, 50, 80),
            "shadow": (20, 20, 35),
            "shuriken": (160, 160, 180),
        }

        # === 스카프 (펄럭임) ===
        scarf_wave = math.sin(self.time * 4) * 0.3
        scarf_points = [
            (cx + int(0.3 * b) + lean_offset, torso_y - int(0.8 * b)),
            (cx + int(0.8 * b) + lean_offset, torso_y - int(0.5 * b)),
            (cx + int(2.0 * b) + lean_offset + int(scarf_wave * b), torso_y + int(0.5 * b) + int(wave * 0.3 * b)),
            (cx + int(1.8 * b) + lean_offset + int(scarf_wave * 0.8 * b), torso_y + int(1.0 * b) + int(wave * 0.4 * b)),
            (cx + int(0.6 * b) + lean_offset, torso_y - int(0.3 * b)),
        ]
        pygame.draw.polygon(screen, p["scarf"], scarf_points)
        pygame.draw.polygon(screen, p["scarf_flow"], scarf_points, 1)

        # === 다리 (닌자 스타일) ===
        hip_y = torso_y + int(1.8 * b)
        for side in [-1, 1]:
            leg_phase = int(abs(wave) * 2.5) if side == 1 else -int(abs(wave) * 1)
            thigh_x = cx + side * int(0.4 * b) + lean_offset
            # 허벅지
            thigh_rect = pygame.Rect(thigh_x - int(0.35 * b), hip_y + leg_phase, int(0.7 * b), int(1.5 * b))
            pygame.draw.rect(screen, p["cloth"], thigh_rect, border_radius=2)
            # 밴디지/붕대
            for i in range(3):
                band_y = thigh_rect.top + int(0.2 * b) + i * int(0.4 * b)
                pygame.draw.line(screen, p["cloth_light"], (thigh_rect.left + 1, band_y),
                               (thigh_rect.right - 1, band_y), 1)
            # 타비 (갈라진 신발)
            tabi_rect = pygame.Rect(thigh_x - int(0.35 * b), thigh_rect.bottom - 2, int(0.7 * b), int(0.5 * b))
            pygame.draw.rect(screen, p["cloth_dark"], tabi_rect, border_radius=2)
            # 갈라진 발가락
            pygame.draw.line(screen, p["shadow"], (tabi_rect.centerx, tabi_rect.bottom - 2),
                           (tabi_rect.centerx, tabi_rect.bottom + int(0.15 * b)), 1)

        # === 몸통 (닌자 상의) ===
        chest_w, chest_h = int(2.4 * b), int(1.8 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.2 * b), chest_w, chest_h)
        pygame.draw.rect(screen, p["cloth"], chest_rect, border_radius=int(0.3 * b))
        pygame.draw.rect(screen, p["cloth_light"], chest_rect.inflate(-int(0.3 * b), -int(0.25 * b)), border_radius=2)
        # X자 붕대
        pygame.draw.line(screen, p["cloth_dark"],
                        (chest_rect.left + int(0.2 * b), chest_rect.top + int(0.2 * b)),
                        (chest_rect.right - int(0.2 * b), chest_rect.bottom - int(0.1 * b)), 2)
        pygame.draw.line(screen, p["cloth_dark"],
                        (chest_rect.right - int(0.2 * b), chest_rect.top + int(0.2 * b)),
                        (chest_rect.left + int(0.2 * b), chest_rect.bottom - int(0.1 * b)), 2)

        # 허리띠 + 수리검 홀더
        belt_rect = pygame.Rect(cx - int(1.2 * b) + lean_offset, chest_rect.bottom - 2, int(2.4 * b), int(0.5 * b))
        pygame.draw.rect(screen, p["cloth_dark"], belt_rect, border_radius=1)
        # 수리검 (허리에 차고 있음)
        shuriken_x = belt_rect.right - int(0.4 * b)
        shuriken_y = belt_rect.centery
        for i in range(4):
            angle = i * math.pi / 2 + self.time * 2
            sx = shuriken_x + int(math.cos(angle) * 0.2 * b)
            sy = shuriken_y + int(math.sin(angle) * 0.2 * b)
            pygame.draw.line(screen, p["shuriken"], (shuriken_x, shuriken_y), (sx, sy), 1)
        pygame.draw.circle(screen, p["metal"], (shuriken_x, shuriken_y), max(1, int(0.08 * b)))

        # === 어깨 보호대 ===
        for side in [-1, 1]:
            shoulder_rect = pygame.Rect(
                cx + side * int(0.9 * b) + lean_offset - int(0.4 * b),
                torso_y - int(0.25 * b),
                int(0.8 * b), int(0.6 * b)
            )
            pygame.draw.ellipse(screen, p["metal"], shoulder_rect)
            pygame.draw.ellipse(screen, p["metal_light"], shoulder_rect.inflate(-2, -2), 1)

        # === 팔 + 쿠나이 ===
        arm_swing = int(arm_swing_anim * 4 * b)
        for side in [-1, 1]:
            shoulder = (cx + side * int(1.0 * b) + lean_offset, torso_y + int(0.1 * b))
            elbow = (shoulder[0] + side * int(0.5 * b) + arm_swing * side * 0.5, torso_y + int(0.6 * b))
            wrist = (elbow[0] + side * int(0.4 * b) + arm_swing * side * 0.3, torso_y + int(1.2 * b))

            pygame.draw.line(screen, p["cloth"], shoulder, elbow, max(2, int(0.45 * b)))
            # 팔 붕대
            pygame.draw.line(screen, p["cloth_light"], shoulder, elbow, 1)
            pygame.draw.line(screen, p["cloth_dark"], elbow, wrist, max(2, int(0.4 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.25 * b)))

            # 쿠나이 (한 손에)
            if side == 1:
                kunai_tip = (wrist[0] + int(0.6 * b), wrist[1] + int(0.2 * b))
                pygame.draw.line(screen, p["metal"], wrist, kunai_tip, max(1, int(0.1 * b)))
                pygame.draw.polygon(screen, p["metal_light"], [
                    kunai_tip,
                    (kunai_tip[0] - int(0.1 * b), kunai_tip[1] - int(0.05 * b)),
                    (kunai_tip[0] - int(0.1 * b), kunai_tip[1] + int(0.05 * b)),
                ])

        # === 머리 (닌자 마스크) ===
        head_y = torso_y - int(2.6 * b)
        head_w, head_h = int(2.0 * b), int(1.8 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        # 머리 (두건)
        pygame.draw.ellipse(screen, p["cloth"], head_rect)
        pygame.draw.ellipse(screen, p["cloth_light"], head_rect.inflate(-int(0.2 * b), -int(0.15 * b)))

        if show_back:
            # 뒷모습 - 두건 뒷면
            pygame.draw.ellipse(screen, p["cloth_dark"], head_rect.inflate(-int(0.1 * b), -int(0.1 * b)))
            # 두건 묶음
            for i in range(2):
                tail_y = head_rect.bottom + i * int(0.3 * b)
                tail_wave = math.sin(self.time * 5 + i) * 0.2
                pygame.draw.line(screen, p["cloth"],
                               (head_rect.centerx - int(0.1 * b), head_rect.bottom - int(0.1 * b)),
                               (head_rect.centerx + int(tail_wave * b), tail_y), 2)
        else:
            # 정면 - 눈만 보이는 마스크
            # 이마 보호대
            headband_rect = pygame.Rect(head_rect.left + int(0.1 * b), head_rect.centery - int(0.3 * b),
                                        head_rect.width - int(0.2 * b), int(0.4 * b))
            pygame.draw.rect(screen, p["metal"], headband_rect, border_radius=2)
            pygame.draw.rect(screen, p["metal_light"], headband_rect, 1, border_radius=2)
            # 닌자 마을 문양
            pygame.draw.circle(screen, p["shadow"], (headband_rect.centerx, headband_rect.centery), max(2, int(0.15 * b)))
            pygame.draw.line(screen, p["metal_light"],
                           (headband_rect.centerx - int(0.1 * b), headband_rect.centery),
                           (headband_rect.centerx + int(0.1 * b), headband_rect.centery), 1)

            # 눈 (날카로운 눈빛)
            eye_y = head_rect.centery + int(0.05 * b)
            for side in [-1, 1]:
                eye_x = head_rect.centerx + side * int(0.3 * b)
                # 눈 배경 (마스크 구멍)
                pygame.draw.ellipse(screen, p["shadow"],
                                  (eye_x - int(0.2 * b), eye_y - int(0.1 * b), int(0.4 * b), int(0.2 * b)))
                # 붉은 눈
                pygame.draw.ellipse(screen, p["eye"],
                                  (eye_x - int(0.12 * b), eye_y - int(0.06 * b), int(0.24 * b), int(0.12 * b)))
                # 눈 글로우
                glow_surf = pygame.Surface((int(0.3 * b), int(0.2 * b)), pygame.SRCALPHA)
                pygame.draw.ellipse(glow_surf, (*p["eye_glow"], 60), (0, 0, int(0.3 * b), int(0.2 * b)))
                screen.blit(glow_surf, (eye_x - int(0.15 * b), eye_y - int(0.1 * b)), special_flags=pygame.BLEND_ADD)

            # 마스크 (코, 입 가림)
            mask_points = [
                (head_rect.centerx - int(0.5 * b), eye_y + int(0.15 * b)),
                (head_rect.centerx + int(0.5 * b), eye_y + int(0.15 * b)),
                (head_rect.centerx + int(0.3 * b), head_rect.bottom - int(0.1 * b)),
                (head_rect.centerx - int(0.3 * b), head_rect.bottom - int(0.1 * b)),
            ]
            pygame.draw.polygon(screen, p["scarf"], mask_points)
            # 마스크 주름
            for i in range(2):
                fold_y = eye_y + int(0.25 * b) + i * int(0.2 * b)
                pygame.draw.line(screen, p["scarf_flow"],
                               (head_rect.centerx - int(0.35 * b), fold_y),
                               (head_rect.centerx + int(0.35 * b), fold_y), 1)

        # === 그림자 효과 (발 아래) ===
        shadow_y = cy + int(2.8 * b)
        shadow_w = int(1.5 * b) + int(abs(wave) * 0.3 * b)
        shadow_surf = pygame.Surface((shadow_w, int(0.3 * b)), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (*p["shadow"], 80), (0, 0, shadow_w, int(0.3 * b)))
        screen.blit(shadow_surf, (cx - shadow_w // 2 + lean_offset, shadow_y))

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
