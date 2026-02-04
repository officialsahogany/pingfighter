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
        """이동 상태 업데이트 - 관절 애니메이션 포함 (발토르 스타일 강화)"""
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
        # 속도 계산 (부드럽게)
        velocity = (current_x - state["last_x"]) / max(dt, 0.001)
        state["velocity"] = velocity * 0.3 + state["velocity"] * 0.7  # 더 부드러운 반응 (0.5→0.3)

        # 기울기 (이동 방향) - 완화된 조정
        target_lean = max(-1.0, min(1.0, state["velocity"] / 200.0))  # 200으로 높임 (덜 기울어짐)
        state["lean"] = state["lean"] * 0.85 + target_lean * 0.15  # 더 부드러운 보간 (0.75→0.85)

        # 걷기 애니메이션 (속도에 비례)
        move_speed = abs(state["velocity"])
        if move_speed > 5:
            # 애니메이션 속도
            state["step_phase"] += dt * 12.0
            state["shoulder_phase"] += dt * 12.0
            # 어깨 들썩임 (미세하게 - 촐싹거림 방지)
            speed_factor = min(1.0, move_speed / 150.0)
            state["body_bob"] = math.sin(state["step_phase"] * 2) * speed_factor * 0.3  # 1.2 → 0.3 (대폭 감소)
            # 팔 스윙
            state["arm_swing"] = math.sin(state["step_phase"]) * min(1.0, move_speed / 100.0) * 1.0
            # 머리 미세 흔들림
            state["head_tilt"] = math.sin(state["step_phase"] * 1.5) * 0.3 * speed_factor
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
        """애니메이션 값 계산 (발토르 스타일 걷기 모션)"""
        step = state.get("step_phase", 0)
        lean = state.get("lean", 0)
        arm_swing = state.get("arm_swing", 0)
        body_bob = state.get("body_bob", 0)
        head_tilt = state.get("head_tilt", 0)
        velocity = abs(state.get("velocity", 0))

        # 이동 중일 때 다리/팔 애니메이션 강화
        leg_intensity = min(1.0, velocity / 80.0) if velocity > 5 else 0

        # 자연스러운 걷기: 왼팔-오른다리, 오른팔-왼다리가 함께 움직임
        arm_intensity = arm_swing * (0.6 + leg_intensity * 0.4)

        # 발토르 스타일 다리 스윙 (좌우 X 방향 움직임)
        # step의 sin 값으로 왼다리/오른다리가 교대로 앞뒤로 움직임
        leg_sway = math.sin(step) * leg_intensity * 0.8  # -0.8 ~ 0.8 범위
        left_leg_sway = -leg_sway   # 왼다리 X 오프셋 (오른다리 반대)
        right_leg_sway = leg_sway   # 오른다리 X 오프셋

        # 발토르 스타일 어깨 들썩임 (팔과 함께 위아래)
        shoulder_bob = math.sin(step * 2) * leg_intensity * 0.3

        return {
            "wave": math.sin(step) * (1.0 + leg_intensity * 0.3),
            "lean": lean,
            "arm_swing": arm_swing,  # 기존 호환성 유지
            "left_arm_swing": -math.sin(step) * arm_intensity,   # 오른다리와 함께
            "right_arm_swing": math.sin(step) * arm_intensity,   # 왼다리와 함께
            "body_bob": body_bob,
            "head_tilt": head_tilt,
            # 다리 들어올림 (Y 방향)
            "left_leg": max(0, math.sin(step)) * (0.8 + leg_intensity * 0.5),
            "right_leg": max(0, -math.sin(step)) * (0.8 + leg_intensity * 0.5),
            # 다리 좌우 스윙 (X 방향) - 발토르 스타일
            "left_leg_sway": left_leg_sway,
            "right_leg_sway": right_leg_sway,
            # 어깨 움직임
            "left_shoulder": math.sin(step + 0.5) * (0.4 + leg_intensity * 0.3),
            "right_shoulder": math.sin(step - 0.5) * (0.4 + leg_intensity * 0.3),
            "shoulder_bob": shoulder_bob,  # 어깨 위아래 들썩임
        }

    def draw_hero_paddle(self, screen: pygame.Surface, hero_id: str,
                         x: float, y: float, width: int, height: int,
                         facing: str = "down", color: Tuple[int, int, int] = (200, 200, 200),
                         scale_mode: str = "paddle", stun_effect: bool = False):
        """
        영웅 패들 그리기
        facing="down": 정면 (아래를 바라봄, 얼굴이 보임) - 상단 영웅
        facing="up": 뒷모습 (위를 바라봄, 뒷통수가 보임) - 하단 영웅
        scale_mode="paddle": 투기장 모드 - 패들 크기에 맞게 캐릭터 축소
        scale_mode="preview": 미리보기 모드 - 기존 크기
        stun_effect: 대쉬 후딜 상태 (보라색 틴트 효과)
        """
        # 후딜 상태일 때 색상 변경 (보라색 틴트)
        if stun_effect:
            # 보라색 틴트 적용 (원래 색상에 보라색 혼합)
            pulse = 0.6 + 0.4 * math.sin(pygame.time.get_ticks() * 0.02)
            r = int(color[0] * 0.5 + 180 * pulse * 0.5)
            g = int(color[1] * 0.3 + 120 * pulse * 0.3)
            b_color = int(color[2] * 0.5 + 200 * pulse * 0.5)
            color = (min(255, r), min(255, g), min(255, b_color))
        show_back = (facing == "up")
        state = self._get_state(hero_id)
        anim = self._get_anim(state)

        # 스케일 계산 (기본 블록 단위)
        if scale_mode == "paddle":
            # 투기장 모드: 캐릭터 크기 확대 (기본 b=8, 패들 크기에 따라 스케일)
            # 기본 패들 너비 130px 기준, width에 따라 비례 스케일
            base_b = 8
            scale_ratio = width / 130.0 if width > 0 else 1.0  # 패들 축소 시 캐릭터도 축소
            b = max(4, int(base_b * scale_ratio))  # 최소 4 유지
            # 이동 애니메이션 (기울기 완화, 상하 움직임 최소화)
            anim = {
                "wave": anim["wave"] * 0.5,
                "lean": anim["lean"] * 0.7,  # 1.2 → 0.7 (기울기 완화)
                "arm_swing": anim["arm_swing"] * 0.6,  # 0.9 → 0.6 (팔 흔들림 감소)
                "body_bob": anim["body_bob"] * 0.15,  # 0.25 → 0.15 (상하 움직임 더 감소)
                "head_tilt": anim["head_tilt"] * 0.3,  # 0.5 → 0.3 (머리 흔들림 감소)
                "left_leg": anim["left_leg"] * 0.5,  # 0.7 → 0.5 (다리 움직임 감소)
                "right_leg": anim["right_leg"] * 0.5,
                "left_shoulder": anim["left_shoulder"] * 0.4,  # 0.6 → 0.4 (어깨 움직임 감소)
                "right_shoulder": anim["right_shoulder"] * 0.4,
            }
        else:
            # 기존 미리보기 모드 (크게 표시)
            b = max(3, width // 12)

        cx = int(x)

        # Y 위치 보정 (캐릭터가 바닥에 붙도록)
        # 캐릭터 높이 = 약 6*b (머리~발), 중심(torso)은 cy에서 그려짐
        # 캐릭터 발 위치 = cy + 약 3*b
        if scale_mode == "paddle":
            if facing == "down":
                # 상단 영웅: 패들 아래쪽에서 캐릭터 그리기
                cy = int(y) + int(3.5 * b)
            else:
                # 하단 영웅: 발이 패들 위치(바닥)에 붙도록
                # 발 위치가 y에 오려면 cy = y - 3*b가 아니라 cy를 더 아래로
                cy = int(y) + int(2.0 * b)  # 더 아래로 이동 (0.5 → 2.0)
        else:
            cy = int(y)

        # 영웅별 그리기
        draw_func = getattr(self, f"_draw_{hero_id}", None)
        if draw_func:
            draw_func(screen, cx, cy, b, color, show_back, anim)
        else:
            self._draw_default(screen, cx, cy, b, color, show_back, anim)

    # =========================================================================
    # 무겐 - 귀검사 (어둠의 검객) - 동양풍 사무라이 [고퀄리티]
    # =========================================================================
    def _draw_mugen(self, screen, cx, cy, b, color, show_back, anim):
        """무겐 - 귀검사 (보라색 검기를 다루는 동양 검객) [HD 버전]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        left_arm_swing = anim.get("left_arm_swing", 0)
        right_arm_swing = anim.get("right_arm_swing", 0)
        left_leg_lift = anim["left_leg"]
        right_leg_lift = anim["right_leg"]
        # 발토르 스타일 다리/어깨 애니메이션
        left_leg_sway = anim.get("left_leg_sway", 0)
        right_leg_sway = anim.get("right_leg_sway", 0)
        shoulder_bob = anim.get("shoulder_bob", 0)
        left_shoulder = anim.get("left_shoulder", 0)
        right_shoulder = anim.get("right_shoulder", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2.5 * b)

        p = {
            "hair": (25, 18, 35),
            "hair_highlight": (50, 35, 70),
            "hair_shine": (80, 60, 100),
            "skin": (240, 215, 190),
            "skin_shadow": (210, 180, 155),
            "armor": color,
            "armor_light": tuple(min(255, c + 50) for c in color),
            "armor_dark": tuple(max(0, c - 45) for c in color),
            "armor_edge": tuple(min(255, c + 80) for c in color),
            "kimono": (35, 28, 55),
            "kimono_light": (55, 45, 80),
            "kimono_pattern": (75, 50, 110),
            "kimono_gold": (180, 150, 80),
            "sash": (200, 160, 60),
            "sash_knot": (170, 130, 40),
            "sword_blade": (210, 195, 255),
            "sword_edge": (255, 250, 255),
            "sword_glow": (180, 120, 255),
            "sword_core": (255, 200, 255),
            "sword_hilt": (70, 55, 40),
            "sword_wrap": (120, 100, 80),
            "sword_guard": (160, 140, 100),
            "eye_glow": (200, 100, 255),
            "eye_core": (255, 180, 255),
            "aura": (150, 80, 200),
        }

        # === 귀기 오라 (뒤에서 발산) ===
        aura_pulse = 0.7 + 0.3 * math.sin(self.time * 4)
        for i in range(3):
            aura_size = int((2.5 + i * 0.5) * b * aura_pulse)
            aura_surf = pygame.Surface((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
            aura_alpha = int(25 - i * 8)
            pygame.draw.ellipse(aura_surf, (*p["aura"], aura_alpha), (0, 0, aura_size * 2, aura_size * 2))
            screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - aura_size + int(0.5 * b)), special_flags=pygame.BLEND_ADD)

        # === 다리 (하카마 스타일 - 디테일 강화) ===
        hip_y = torso_y + int(2.0 * b)
        # 하카마 그림자
        hakama_shadow = [
            (cx - int(1.25 * b) + lean_offset + 2, hip_y - int(0.15 * b) + 2),
            (cx + int(1.25 * b) + lean_offset + 2, hip_y - int(0.15 * b) + 2),
            (cx + int(1.55 * b) + lean_offset + int(wave * 0.2 * b) + 2, cy + int(2.85 * b) + 2),
            (cx - int(1.55 * b) + lean_offset - int(wave * 0.2 * b) + 2, cy + int(2.85 * b) + 2),
        ]
        pygame.draw.polygon(screen, (20, 15, 30), hakama_shadow)
        # 하카마 본체
        hakama_points = [
            (cx - int(1.2 * b) + lean_offset, hip_y - int(0.2 * b)),
            (cx + int(1.2 * b) + lean_offset, hip_y - int(0.2 * b)),
            (cx + int(1.5 * b) + lean_offset + int(wave * 0.2 * b), cy + int(2.8 * b)),
            (cx - int(1.5 * b) + lean_offset - int(wave * 0.2 * b), cy + int(2.8 * b)),
        ]
        pygame.draw.polygon(screen, p["kimono"], hakama_points)
        # 하카마 주름 (5개)
        for i in range(5):
            fx = cx + (i - 2) * int(0.45 * b) + lean_offset
            fold_wave = int(wave * 0.08 * b * (1 + abs(i - 2) * 0.2))
            pygame.draw.line(screen, p["kimono_light"],
                           (fx, hip_y + int(0.1 * b)), (fx + fold_wave, cy + int(2.6 * b)), 1)
        # 하카마 허리 주름
        pygame.draw.line(screen, p["kimono_light"],
                        (cx - int(1.1 * b) + lean_offset, hip_y - int(0.1 * b)),
                        (cx + int(1.1 * b) + lean_offset, hip_y - int(0.1 * b)), 1)
        # 다리 움직임 (발토르 스타일 - 좌우 스윙 + 들어올림)
        left_leg_y = int(left_leg_lift * 0.2 * b)  # Y 들어올림
        right_leg_y = int(right_leg_lift * 0.2 * b)
        left_leg_x = int(left_leg_sway * 0.4 * b)  # X 좌우 스윙
        right_leg_x = int(right_leg_sway * 0.4 * b)
        # 왼쪽 다리 (하카마 아래로 보이는 발)
        pygame.draw.ellipse(screen, p["kimono_light"],
                          (cx - int(0.55 * b) + lean_offset + left_leg_x, cy + int(2.5 * b) - left_leg_y, int(0.45 * b), int(0.28 * b)))
        pygame.draw.ellipse(screen, p["skin"],
                          (cx - int(0.5 * b) + lean_offset + left_leg_x, cy + int(2.65 * b) - left_leg_y, int(0.35 * b), int(0.2 * b)))
        # 오른쪽 다리
        pygame.draw.ellipse(screen, p["kimono_light"],
                          (cx + int(0.1 * b) + lean_offset + right_leg_x, cy + int(2.5 * b) - right_leg_y, int(0.45 * b), int(0.28 * b)))
        pygame.draw.ellipse(screen, p["skin"],
                          (cx + int(0.15 * b) + lean_offset + right_leg_x, cy + int(2.65 * b) - right_leg_y, int(0.35 * b), int(0.2 * b)))

        # === 몸통 (사무라이 갑옷 - 고디테일) ===
        chest_w, chest_h = int(2.6 * b), int(2.0 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.3 * b), chest_w, chest_h)
        # 갑옷 그림자
        pygame.draw.rect(screen, p["armor_dark"], chest_rect.move(2, 2), border_radius=int(0.4 * b))
        # 갑옷 본체
        pygame.draw.rect(screen, p["armor"], chest_rect, border_radius=int(0.4 * b))
        # 갑옷 하이라이트
        pygame.draw.rect(screen, p["armor_light"], chest_rect.inflate(-int(0.5 * b), -int(0.4 * b)), border_radius=3)
        # 갑옷 테두리
        pygame.draw.rect(screen, p["armor_edge"], chest_rect, 1, border_radius=int(0.4 * b))
        # 가슴 문양 (음양 스타일)
        emblem_cx, emblem_cy = chest_rect.centerx, chest_rect.centery - int(0.1 * b)
        pygame.draw.circle(screen, p["kimono_gold"], (emblem_cx, emblem_cy), max(2, int(0.35 * b)))
        pygame.draw.circle(screen, p["armor"], (emblem_cx, emblem_cy), max(1, int(0.25 * b)))
        pygame.draw.arc(screen, p["kimono_gold"],
                       (emblem_cx - int(0.2 * b), emblem_cy - int(0.2 * b), int(0.4 * b), int(0.4 * b)),
                       0, math.pi, 1)
        # V자 기모노 깃
        pygame.draw.line(screen, p["kimono"], (chest_rect.centerx, chest_rect.top + int(0.15 * b)),
                        (chest_rect.left + int(0.35 * b), chest_rect.bottom - int(0.25 * b)), 2)
        pygame.draw.line(screen, p["kimono"], (chest_rect.centerx, chest_rect.top + int(0.15 * b)),
                        (chest_rect.right - int(0.35 * b), chest_rect.bottom - int(0.25 * b)), 2)
        pygame.draw.line(screen, p["kimono_light"], (chest_rect.centerx, chest_rect.top + int(0.2 * b)),
                        (chest_rect.left + int(0.4 * b), chest_rect.bottom - int(0.3 * b)), 1)
        pygame.draw.line(screen, p["kimono_light"], (chest_rect.centerx, chest_rect.top + int(0.2 * b)),
                        (chest_rect.right - int(0.4 * b), chest_rect.bottom - int(0.3 * b)), 1)

        # 사시 (허리띠 - 매듭 포함)
        belt_rect = pygame.Rect(cx - int(1.3 * b) + lean_offset, chest_rect.bottom - 2, int(2.6 * b), int(0.7 * b))
        pygame.draw.rect(screen, p["sash"], belt_rect, border_radius=2)
        pygame.draw.rect(screen, p["sash_knot"], belt_rect.inflate(-int(0.2 * b), -int(0.1 * b)), 1, border_radius=1)
        # 허리띠 매듭
        knot_x = belt_rect.right - int(0.5 * b)
        pygame.draw.circle(screen, p["sash_knot"], (knot_x, belt_rect.centery), max(2, int(0.2 * b)))
        pygame.draw.circle(screen, p["sash"], (knot_x, belt_rect.centery), max(1, int(0.12 * b)))

        # === 어깨 갑옷 (소데 - 사무라이 어깨보호대) ===
        for side in [-1, 1]:
            # 소데 그림자
            sode_shadow = [
                (cx + side * int(1.45 * b) + lean_offset + side, torso_y - int(0.55 * b) + 2),
                (cx + side * int(0.65 * b) + lean_offset, torso_y - int(0.25 * b) + 2),
                (cx + side * int(0.75 * b) + lean_offset, torso_y + int(0.55 * b) + 2),
                (cx + side * int(1.55 * b) + lean_offset + side, torso_y + int(0.35 * b) + 2),
            ]
            pygame.draw.polygon(screen, (20, 15, 30), sode_shadow)
            # 소데 본체
            pauldron = [
                (cx + side * int(1.4 * b) + lean_offset, torso_y - int(0.6 * b)),
                (cx + side * int(0.7 * b) + lean_offset, torso_y - int(0.3 * b)),
                (cx + side * int(0.8 * b) + lean_offset, torso_y + int(0.5 * b)),
                (cx + side * int(1.5 * b) + lean_offset, torso_y + int(0.3 * b)),
            ]
            pygame.draw.polygon(screen, p["armor_dark"], pauldron)
            # 소데 레이어
            for layer in range(3):
                layer_y = torso_y - int(0.5 * b) + layer * int(0.25 * b)
                pygame.draw.line(screen, p["armor_light"],
                               (cx + side * int(0.75 * b) + lean_offset, layer_y),
                               (cx + side * int(1.45 * b) + lean_offset, layer_y - int(0.05 * b)), 1)
            pygame.draw.polygon(screen, p["armor_edge"], pauldron, 1)

        # === 팔 (발토르 스타일 - 어깨 들썩임 + 팔 교대 스윙) ===
        for side in [-1, 1]:
            # 왼팔(-1)은 left_arm_swing, 오른팔(1)은 right_arm_swing 사용
            current_swing = left_arm_swing if side == -1 else right_arm_swing
            current_shoulder_bob = left_shoulder if side == -1 else right_shoulder
            arm_swing = int(current_swing * 2.5 * b)
            # 어깨 들썩임 (Y 위치 변화)
            shoulder_y_offset = int(current_shoulder_bob * 0.3 * b + shoulder_bob * 0.2 * b)
            shoulder = (cx + side * int(1.2 * b) + lean_offset, torso_y + int(0.1 * b) + shoulder_y_offset)
            # 팔이 앞뒤로 흔들리도록 X 위치 조정 (양팔이 반대 방향)
            elbow = (shoulder[0] + side * int(0.5 * b) + arm_swing, torso_y + int(0.8 * b) + shoulder_y_offset)
            wrist = (elbow[0] + side * int(0.4 * b) + int(arm_swing * 0.5), torso_y + int(1.4 * b) + int(shoulder_y_offset * 0.5))
            # 상완 (기모노 소매)
            pygame.draw.line(screen, p["kimono"], shoulder, elbow, max(3, int(0.55 * b)))
            pygame.draw.line(screen, p["kimono_light"], shoulder, elbow, max(1, int(0.35 * b)))
            # 팔꿈치 관절
            pygame.draw.circle(screen, p["skin_shadow"], elbow, max(2, int(0.2 * b)))
            # 전완 (피부)
            pygame.draw.line(screen, p["skin"], elbow, wrist, max(2, int(0.45 * b)))
            pygame.draw.line(screen, p["skin_shadow"], (elbow[0] + 1, elbow[1] + 1), (wrist[0] + 1, wrist[1] + 1), 1)
            # 손목 밴드
            pygame.draw.circle(screen, p["kimono"], wrist, max(3, int(0.32 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.25 * b)))

        # === 머리 (더 정교한 얼굴) ===
        head_y = torso_y - int(2.8 * b)
        head_w, head_h = int(2.0 * b), int(1.8 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        if show_back:
            # 뒷모습 - 상투
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            pygame.draw.ellipse(screen, p["hair_highlight"], head_rect.inflate(-int(0.3 * b), -int(0.2 * b)))
            # 상투 (더 정교하게)
            topknot_y = head_rect.top + int(0.25 * b)
            pygame.draw.circle(screen, p["hair"], (head_rect.centerx, topknot_y), int(0.45 * b))
            pygame.draw.circle(screen, p["hair_highlight"], (head_rect.centerx, topknot_y), int(0.3 * b))
            # 상투 묶음
            pygame.draw.ellipse(screen, p["sash"],
                              (head_rect.centerx - int(0.15 * b), topknot_y - int(0.1 * b), int(0.3 * b), int(0.15 * b)))
            # 뒷머리 결
            for i in range(4):
                hx = head_rect.centerx + (i - 1.5) * int(0.3 * b)
                pygame.draw.line(screen, p["hair_highlight"], (hx, head_rect.top + int(0.5 * b)),
                               (hx, head_rect.bottom - int(0.1 * b)), 1)
        else:
            # 정면 - 더 정교한 얼굴
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            face_rect = head_rect.inflate(-int(0.4 * b), -int(0.3 * b))
            face_rect.move_ip(0, int(0.2 * b))
            pygame.draw.ellipse(screen, p["skin"], face_rect)
            pygame.draw.ellipse(screen, p["skin_shadow"], face_rect.inflate(-int(0.1 * b), -int(0.1 * b)), 1)

            # 귀기 눈 (글로우 + 동공)
            eye_y = face_rect.centery - int(0.1 * b)
            for side in [-1, 1]:
                eye_x = face_rect.centerx + side * int(0.25 * b)
                # 눈 글로우
                glow_pulse = 0.8 + 0.2 * math.sin(self.time * 6 + side)
                glow_surf = pygame.Surface((int(0.4 * b), int(0.3 * b)), pygame.SRCALPHA)
                pygame.draw.ellipse(glow_surf, (*p["eye_glow"], int(80 * glow_pulse)), (0, 0, int(0.4 * b), int(0.3 * b)))
                screen.blit(glow_surf, (eye_x - int(0.2 * b), eye_y - int(0.15 * b)), special_flags=pygame.BLEND_ADD)
                # 눈 본체
                pygame.draw.ellipse(screen, p["eye_glow"],
                                  (eye_x - int(0.12 * b), eye_y - int(0.08 * b), int(0.24 * b), int(0.16 * b)))
                pygame.draw.circle(screen, p["eye_core"], (eye_x, eye_y), max(1, int(0.06 * b)))

            # 코 힌트
            pygame.draw.line(screen, p["skin_shadow"],
                           (face_rect.centerx, face_rect.centery),
                           (face_rect.centerx, face_rect.centery + int(0.15 * b)), 1)
            # 입 (굳은 표정)
            pygame.draw.line(screen, p["skin_shadow"],
                           (face_rect.centerx - int(0.15 * b), face_rect.bottom - int(0.25 * b)),
                           (face_rect.centerx + int(0.15 * b), face_rect.bottom - int(0.25 * b)), 1)

            # 앞머리 (더 자연스럽게)
            for i in range(5):
                hx = face_rect.centerx + (i - 2) * int(0.2 * b)
                hy_start = head_rect.top + int(0.08 * b)
                hy_end = face_rect.top + int(0.15 * b) + abs(i - 2) * int(0.05 * b)
                curve_offset = (i - 2) * int(0.08 * b)
                pygame.draw.line(screen, p["hair"], (hx, hy_start), (hx + curve_offset, hy_end), 2)
                pygame.draw.line(screen, p["hair_shine"], (hx + 1, hy_start), (hx + curve_offset + 1, hy_end), 1)

            # 이마 보호대 (하치마키)
            headband_rect = pygame.Rect(head_rect.left + int(0.1 * b), head_rect.top + int(0.55 * b),
                                        head_rect.width - int(0.2 * b), int(0.2 * b))
            pygame.draw.rect(screen, p["sash"], headband_rect, border_radius=1)
            pygame.draw.rect(screen, p["sash_knot"], headband_rect, 1, border_radius=1)

        # === 귀검 (보라색 검기 - 고퀄리티 효과) ===
        sword_x = cx + int(2.2 * b) + lean_offset
        sword_top = head_y - int(0.8 * b)
        sword_bottom = cy + int(2.0 * b)

        # 검기 오라 (검 주변)
        for i in range(4):
            aura_offset = int(math.sin(self.time * 10 + i * 0.5) * 0.15 * b)
            aura_surf = pygame.Surface((int(b), sword_bottom - sword_top + int(b)), pygame.SRCALPHA)
            aura_alpha = 40 - i * 10
            for y in range(0, sword_bottom - sword_top, 3):
                wave_x = int(0.5 * b) + int(math.sin(self.time * 8 + y * 0.05) * 0.1 * b)
                pygame.draw.circle(aura_surf, (*p["sword_glow"], aura_alpha), (wave_x, y), 2 + i)
            screen.blit(aura_surf, (sword_x - int(0.5 * b), sword_top), special_flags=pygame.BLEND_ADD)

        # 검신 그림자
        pygame.draw.line(screen, (60, 50, 80), (sword_x + 2, sword_top + 2), (sword_x + 2, sword_bottom + 2), max(2, int(0.3 * b)))
        # 검신 본체
        pygame.draw.line(screen, p["sword_blade"], (sword_x, sword_top), (sword_x, sword_bottom), max(2, int(0.3 * b)))
        # 검신 하이라이트
        pygame.draw.line(screen, p["sword_edge"], (sword_x - 1, sword_top), (sword_x - 1, sword_bottom), 1)

        # 검날 (더 날카롭게)
        blade_points = [
            (sword_x, sword_top - int(0.7 * b)),
            (sword_x - int(0.25 * b), sword_top + int(0.1 * b)),
            (sword_x + int(0.25 * b), sword_top + int(0.1 * b)),
        ]
        pygame.draw.polygon(screen, p["sword_blade"], blade_points)
        pygame.draw.polygon(screen, p["sword_edge"], blade_points, 1)
        # 검날 빛
        pygame.draw.line(screen, p["sword_core"], (sword_x, sword_top - int(0.6 * b)), (sword_x, sword_top - int(0.2 * b)), 1)

        # 츠바 (검 가드)
        guard_y = sword_bottom
        pygame.draw.ellipse(screen, p["sword_guard"],
                          (sword_x - int(0.35 * b), guard_y - int(0.08 * b), int(0.7 * b), int(0.16 * b)))
        pygame.draw.ellipse(screen, p["kimono_gold"],
                          (sword_x - int(0.3 * b), guard_y - int(0.05 * b), int(0.6 * b), int(0.1 * b)))
        # 손잡이
        pygame.draw.rect(screen, p["sword_hilt"], (sword_x - int(0.12 * b), guard_y + int(0.05 * b), int(0.24 * b), int(0.55 * b)))
        # 손잡이 감기
        for i in range(4):
            wrap_y = guard_y + int(0.1 * b) + i * int(0.12 * b)
            pygame.draw.line(screen, p["sword_wrap"],
                           (sword_x - int(0.1 * b), wrap_y), (sword_x + int(0.1 * b), wrap_y + int(0.05 * b)), 1)
        # 카시라 (손잡이 끝)
        pygame.draw.ellipse(screen, p["sword_guard"],
                          (sword_x - int(0.15 * b), guard_y + int(0.55 * b), int(0.3 * b), int(0.12 * b)))

    # =========================================================================
    # 크라켄 - 심해의 포식자 (촉수 괴물 하이브리드)
    # =========================================================================
    def _draw_kraken(self, screen, cx, cy, b, color, show_back, anim):
        """크라켄 - 심해의 포식자 (촉수 괴물 하이브리드) [고퀄리티 업그레이드]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        shoulder_bob = anim.get("shoulder_bob", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        # 심해 생물 발광 펄스
        biolum_pulse = (math.sin(self.time * 2) + 1) * 0.5
        water_shimmer = math.sin(self.time * 4) * 0.3

        p = {
            "body": color,
            "body_light": tuple(min(255, c + 40) for c in color),
            "body_dark": tuple(max(0, c - 50) for c in color),
            "body_highlight": tuple(min(255, c + 70) for c in color),
            "tentacle": tuple(max(0, c - 20) for c in color),
            "tentacle_inner": tuple(max(0, c - 40) for c in color),
            "tentacle_sucker": (180, 140, 160),
            "sucker_inner": (140, 100, 120),
            "sucker_highlight": (220, 180, 200),
            "eye": (200, 255, 200),
            "eye_glow": (150, 255, 200),
            "eye_pupil": (20, 80, 60),
            "eye_highlight": (255, 255, 255),
            "glow": (100, 200, 180),
            "biolum": (80, 255, 200),  # 생물 발광
            "biolum_soft": (60, 200, 160),
            "teeth": (220, 220, 200),
            "teeth_tip": (255, 255, 240),
            "barnacle": (140, 130, 120),
            "barnacle_light": (180, 170, 160),
            "water_drop": (180, 220, 255),
            "slime": (100, 180, 150),
        }

        # === 배경 심해 오라 (물속 느낌) ===
        aura_size = int(6 * b)
        aura_surf = pygame.Surface((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
        for i in range(3):
            aura_alpha = int(20 - i * 6)
            aura_r = int((2.5 - i * 0.6) * b)
            pygame.draw.circle(aura_surf, (*p["glow"], aura_alpha), (aura_size, aura_size), aura_r)
        screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - int(1.5 * b) - aura_size // 2), special_flags=pygame.BLEND_ADD)

        # === 물방울 파티클 효과 ===
        for i in range(6):
            drop_x = cx + int(math.sin(self.time * 2 + i * 1.2) * 2.5 * b) + lean_offset
            drop_y = torso_y - int(2 * b) + int((self.time * 0.5 + i * 0.3) % 1 * 4 * b)
            drop_alpha = int(150 * (1 - ((self.time * 0.5 + i * 0.3) % 1)))
            drop_size = max(1, int(0.12 * b))
            drop_surf = pygame.Surface((drop_size * 4, drop_size * 4), pygame.SRCALPHA)
            pygame.draw.circle(drop_surf, (*p["water_drop"], drop_alpha), (drop_size * 2, drop_size * 2), drop_size)
            screen.blit(drop_surf, (int(drop_x) - drop_size * 2, int(drop_y) - drop_size * 2))

        # === 촉수 다리 (6개, 더 상세한 세그먼트) ===
        hip_y = torso_y + int(1.8 * b)
        tentacle_positions = [-1.8, -1.1, -0.4, 0.4, 1.1, 1.8]
        for i, side in enumerate(tentacle_positions):
            base_x = cx + int(side * 0.4 * b) + lean_offset
            thickness_base = max(3, int(0.5 * b))

            # 촉수 세그먼트 (8개로 증가)
            points = []
            for seg in range(8):
                seg_y = hip_y + seg * int(0.4 * b)
                wave_amp = 0.4 * (seg / 4)  # 끝으로 갈수록 진폭 증가
                seg_x = base_x + int(math.sin(self.time * 4 + i * 0.8 + seg * 0.6) * wave_amp * b)
                points.append((int(seg_x), int(seg_y)))

            # 촉수 그리기 (두께 변화)
            if len(points) >= 2:
                for seg_idx in range(len(points) - 1):
                    thickness = max(2, thickness_base - seg_idx // 2)
                    seg_color = p["tentacle"] if seg_idx % 2 == 0 else p["tentacle_inner"]
                    pygame.draw.line(screen, seg_color, points[seg_idx], points[seg_idx + 1], thickness)

            # 빨판 (더 상세한 디테일)
            for seg in range(1, 7):
                sx, sy = points[seg]
                sucker_size = max(1, int(0.18 * b) - seg // 3)
                # 빨판 외곽
                pygame.draw.circle(screen, p["tentacle_sucker"], (int(sx), int(sy)), sucker_size)
                # 빨판 내부 홈
                inner_size = max(1, sucker_size - 2)
                pygame.draw.circle(screen, p["sucker_inner"], (int(sx), int(sy)), inner_size)
                # 빨판 하이라이트
                if sucker_size > 2:
                    pygame.draw.circle(screen, p["sucker_highlight"], (int(sx) - 1, int(sy) - 1), max(1, sucker_size // 3))

        # === 몸통 (불규칙한 형태, 층층이 렌더링) ===
        chest_w, chest_h = int(3.2 * b), int(2.4 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.3 * b), chest_w, chest_h)

        # 몸통 그림자 레이어
        shadow_rect = chest_rect.inflate(int(0.3 * b), int(0.2 * b))
        shadow_rect.move_ip(int(0.1 * b), int(0.15 * b))
        pygame.draw.ellipse(screen, p["body_dark"], shadow_rect)

        # 몸통 베이스
        pygame.draw.ellipse(screen, p["body"], chest_rect)

        # 몸통 하이라이트 레이어들
        pygame.draw.ellipse(screen, p["body_light"], chest_rect.inflate(-int(0.6 * b), -int(0.5 * b)))
        highlight_rect = chest_rect.inflate(-int(1.2 * b), -int(1.0 * b))
        highlight_rect.move_ip(-int(0.2 * b), -int(0.2 * b))
        pygame.draw.ellipse(screen, p["body_highlight"], highlight_rect)

        # 물결/비늘 무늬 패턴
        for row in range(3):
            for col in range(5):
                spot_x = chest_rect.left + int((col + 0.5) * 0.55 * b)
                spot_y = chest_rect.top + int(0.5 * b) + row * int(0.5 * b)
                spot_offset = math.sin(self.time * 3 + col + row) * 0.05 * b
                pygame.draw.ellipse(screen, p["body_dark"],
                    (int(spot_x + spot_offset), int(spot_y), max(2, int(0.25 * b)), max(1, int(0.15 * b))))

        # 슬라임/점액질 효과
        slime_y = chest_rect.bottom - int(0.3 * b)
        for i in range(4):
            slime_x = chest_rect.left + int(0.4 * b) + i * int(0.6 * b)
            drip_length = int(math.sin(self.time * 2 + i) * 0.2 * b + 0.3 * b)
            pygame.draw.line(screen, p["slime"], (int(slime_x), int(slime_y)),
                           (int(slime_x), int(slime_y + drip_length)), max(1, int(0.08 * b)))

        # 따개비 장식 (더 디테일)
        barnacle_positions = [(0.4, 0.7), (1.0, 0.85), (1.6, 0.65), (2.2, 0.8), (2.6, 0.7)]
        for bx_off, by_off in barnacle_positions:
            bx = chest_rect.left + int(bx_off * b)
            by = chest_rect.top + int(by_off * b)
            barn_size = max(2, int(0.18 * b))
            # 따개비 베이스
            pygame.draw.circle(screen, p["barnacle"], (int(bx), int(by)), barn_size)
            # 따개비 하이라이트
            pygame.draw.circle(screen, p["barnacle_light"], (int(bx) - 1, int(by) - 1), max(1, barn_size // 2))
            # 따개비 입구
            pygame.draw.circle(screen, p["body_dark"], (int(bx), int(by)), max(1, barn_size // 3))

        # === 팔 촉수 (양쪽, 더 역동적 + 어깨 들썩임) ===
        for side in [-1, 1]:
            shoulder_bob_offset = int(shoulder_bob * 0.3 * b)
            shoulder = (cx + side * int(1.4 * b) + lean_offset, torso_y + int(0.2 * b) + shoulder_bob_offset)

            # 팔 촉수 웨이브 (8개 세그먼트)
            arm_points = []
            for seg in range(8):
                wave_x = math.sin(self.time * 5 + seg * 0.8) * 0.25 * b * (seg / 4)
                wave_y = math.cos(self.time * 4 + seg * 0.6) * 0.15 * b
                ax = shoulder[0] + side * seg * int(0.28 * b) + wave_x
                ay = shoulder[1] + seg * int(0.22 * b) + wave_y
                arm_points.append((int(ax), int(ay)))

            if len(arm_points) >= 2:
                # 촉수 두께 변화
                for seg_idx in range(len(arm_points) - 1):
                    thickness = max(2, int(0.5 * b) - seg_idx // 2)
                    pygame.draw.line(screen, p["tentacle"], arm_points[seg_idx], arm_points[seg_idx + 1], thickness)

            # 팔 빨판들
            for seg in range(1, 7):
                sx, sy = arm_points[seg]
                sucker_size = max(2, int(0.2 * b) - seg // 3)
                pygame.draw.circle(screen, p["tentacle_sucker"], (int(sx), int(sy)), sucker_size)
                pygame.draw.circle(screen, p["sucker_inner"], (int(sx), int(sy)), max(1, sucker_size - 1))

            # 팔 끝 (잡는 형태)
            if len(arm_points) >= 2:
                end_x, end_y = arm_points[-1]
                # 끝 부분 갈라짐
                for finger in range(3):
                    f_angle = (finger - 1) * 0.4 + side * 0.5
                    f_len = int(0.35 * b)
                    fx = end_x + int(math.cos(self.time * 3 + finger) * f_len * 0.3 + f_angle * f_len)
                    fy = end_y + int(f_len * 0.8)
                    pygame.draw.line(screen, p["tentacle"], (int(end_x), int(end_y)), (int(fx), int(fy)), max(2, int(0.15 * b)))

        # === 머리 (오징어/문어 형태, 고퀄리티) ===
        head_y = torso_y - int(3.4 * b)
        head_w, head_h = int(2.8 * b), int(2.6 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        # 머리 그림자
        head_shadow = head_rect.inflate(int(0.2 * b), int(0.15 * b))
        head_shadow.move_ip(int(0.1 * b), int(0.1 * b))
        pygame.draw.ellipse(screen, p["body_dark"], head_shadow)

        # 머리 본체 (둥근 돔 형태)
        pygame.draw.ellipse(screen, p["body"], head_rect)

        # 머리 하이라이트 레이어
        pygame.draw.ellipse(screen, p["body_light"], head_rect.inflate(-int(0.5 * b), -int(0.4 * b)))
        head_highlight = head_rect.inflate(-int(1.0 * b), -int(0.8 * b))
        head_highlight.move_ip(-int(0.15 * b), -int(0.15 * b))
        pygame.draw.ellipse(screen, p["body_highlight"], head_highlight)

        # 머리 입체감 주름
        for i in range(4):
            wrinkle_y = head_rect.top + int((i + 1) * 0.5 * b)
            wrinkle_w = head_w - int(i * 0.3 * b)
            pygame.draw.arc(screen, p["body_dark"],
                          (head_rect.centerx - wrinkle_w // 2, wrinkle_y, wrinkle_w, int(0.3 * b)),
                          0, math.pi, max(1, int(0.05 * b)))

        # === 생물 발광 점들 (머리에) ===
        biolum_positions = [
            (-0.6, -0.3), (0.6, -0.3), (-0.8, 0.2), (0.8, 0.2),
            (-0.4, 0.5), (0.4, 0.5), (0, -0.5), (0, 0.6)
        ]
        for bx_off, by_off in biolum_positions:
            bx = head_rect.centerx + int(bx_off * b)
            by = head_rect.centery + int(by_off * b)
            glow_size = int(0.15 * b * (0.7 + biolum_pulse * 0.3))
            # 발광 글로우
            glow_surf = pygame.Surface((int(0.6 * b), int(0.6 * b)), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*p["biolum"], int(60 * biolum_pulse)),
                             (int(0.3 * b), int(0.3 * b)), int(0.25 * b))
            screen.blit(glow_surf, (int(bx - 0.3 * b), int(by - 0.3 * b)), special_flags=pygame.BLEND_ADD)
            # 발광 점
            pygame.draw.circle(screen, p["biolum"], (int(bx), int(by)), max(1, glow_size))

        if show_back:
            # 뒷모습 - 머리 뒷면 패턴 (더 상세)
            for i in range(4):
                for j in range(3):
                    px = head_rect.centerx + (i - 1.5) * int(0.45 * b)
                    py = head_rect.centery + (j - 1) * int(0.4 * b)
                    pattern_size = max(1, int(0.12 * b))
                    pygame.draw.circle(screen, p["body_dark"], (int(px), int(py)), pattern_size)
            # 머리 뒤 지느러미
            fin_points = [
                (head_rect.centerx - int(0.3 * b), head_rect.top + int(0.3 * b)),
                (head_rect.centerx, head_rect.top - int(0.4 * b)),
                (head_rect.centerx + int(0.3 * b), head_rect.top + int(0.3 * b)),
            ]
            pygame.draw.polygon(screen, p["body_light"], fin_points)
        else:
            # 정면 - 큰 눈 (발광, 고퀄리티)
            eye_y = head_rect.centery - int(0.15 * b)
            for side in [-1, 1]:
                eye_x = head_rect.centerx + side * int(0.55 * b)
                eye_w, eye_h = int(0.7 * b), int(0.6 * b)

                # 눈 글로우 (다층 레이어)
                for glow_layer in range(3):
                    glow_size = int((1.2 - glow_layer * 0.3) * b)
                    glow_alpha = int(40 - glow_layer * 12)
                    glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surf, (*p["eye_glow"], glow_alpha),
                                     (glow_size // 2, glow_size // 2), glow_size // 2)
                    screen.blit(glow_surf, (eye_x - glow_size // 2, eye_y - glow_size // 2),
                              special_flags=pygame.BLEND_ADD)

                # 눈 외곽 테두리
                pygame.draw.ellipse(screen, p["body_dark"],
                                   (eye_x - eye_w // 2 - 2, eye_y - eye_h // 2 - 2, eye_w + 4, eye_h + 4))
                # 눈 본체
                pygame.draw.ellipse(screen, p["eye"], (eye_x - eye_w // 2, eye_y - eye_h // 2, eye_w, eye_h))

                # 동공 (가로로 긴 형태, 움직임)
                pupil_move = math.sin(self.time * 2) * 0.05 * b
                pupil_w, pupil_h = int(0.35 * b), int(0.2 * b)
                pygame.draw.ellipse(screen, p["eye_pupil"],
                                   (eye_x - pupil_w // 2 + int(pupil_move), eye_y - pupil_h // 2, pupil_w, pupil_h))

                # 눈 하이라이트 (반짝임)
                highlight_x = eye_x - int(0.15 * b)
                highlight_y = eye_y - int(0.12 * b)
                pygame.draw.circle(screen, p["eye_highlight"], (int(highlight_x), int(highlight_y)), max(1, int(0.1 * b)))
                # 작은 서브 하이라이트
                pygame.draw.circle(screen, p["eye_highlight"],
                                 (int(highlight_x + 0.15 * b), int(highlight_y + 0.1 * b)), max(1, int(0.05 * b)))

            # === 입 (이빨이 있는 부리, 더 디테일) ===
            mouth_y = head_rect.bottom - int(0.6 * b)
            # 부리 외곽
            beak_points = [
                (head_rect.centerx - int(0.4 * b), mouth_y - int(0.1 * b)),
                (head_rect.centerx + int(0.4 * b), mouth_y - int(0.1 * b)),
                (head_rect.centerx, mouth_y + int(0.4 * b)),
            ]
            pygame.draw.polygon(screen, p["body_dark"], beak_points)
            # 부리 내부
            inner_beak = [
                (head_rect.centerx - int(0.25 * b), mouth_y),
                (head_rect.centerx + int(0.25 * b), mouth_y),
                (head_rect.centerx, mouth_y + int(0.25 * b)),
            ]
            pygame.draw.polygon(screen, (40, 30, 50), inner_beak)

            # 이빨 (더 상세)
            for i in range(5):
                tx = head_rect.centerx + (i - 2) * int(0.12 * b)
                tooth_len = int(0.18 * b) if i % 2 == 0 else int(0.12 * b)
                pygame.draw.line(screen, p["teeth"], (tx, mouth_y), (tx, mouth_y + tooth_len), max(1, int(0.04 * b)))
                # 이빨 끝 하이라이트
                pygame.draw.circle(screen, p["teeth_tip"], (tx, mouth_y + tooth_len), max(1, int(0.03 * b)))

            # === 턱 촉수 (입 주변) ===
            for i in range(4):
                whisker_x = head_rect.centerx + (i - 1.5) * int(0.25 * b)
                whisker_y = mouth_y + int(0.35 * b)
                # 촉수 웨이브
                whisker_points = []
                for seg in range(4):
                    wx = whisker_x + int(math.sin(self.time * 6 + i + seg) * 0.1 * b)
                    wy = whisker_y + seg * int(0.2 * b)
                    whisker_points.append((int(wx), int(wy)))
                if len(whisker_points) >= 2:
                    pygame.draw.lines(screen, p["tentacle"], False, whisker_points, max(1, int(0.1 * b)))

    # =========================================================================
    # 크로노스 - 시간술사 (시계/톱니바퀴 테마) [고퀄리티 업그레이드]
    # =========================================================================
    def _draw_chronos(self, screen, cx, cy, b, color, show_back, anim):
        """크로노스 - 시간술사 (시간을 조종하는 마법사) [고퀄리티]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        shoulder_bob = anim.get("shoulder_bob", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        # 시간 왜곡 펄스
        time_pulse = (math.sin(self.time * 1.5) + 1) * 0.5
        gear_spin = self.time * 2

        p = {
            "robe": (50, 40, 70),  # 어두운 보라 로브
            "robe_mid": (70, 55, 95),
            "robe_light": (90, 70, 120),
            "robe_highlight": (120, 95, 155),
            "gold": color,
            "gold_light": tuple(min(255, c + 60) for c in color),
            "gold_mid": tuple(min(255, c + 30) for c in color),
            "gold_dark": tuple(max(0, c - 50) for c in color),
            "gold_shadow": tuple(max(0, c - 80) for c in color),
            "skin": (200, 185, 170),
            "skin_shadow": (170, 155, 140),
            "eye": (180, 200, 255),
            "eye_glow": (200, 220, 255),
            "clock_face": (235, 225, 200),
            "clock_rim": (200, 180, 140),
            "gear": (180, 160, 120),
            "gear_dark": (140, 120, 90),
            "gear_light": (210, 190, 150),
            "glow": (255, 220, 150),
            "time_aura": (180, 150, 255),
            "sand": (230, 210, 170),
            "beard": (220, 220, 230),
            "beard_shadow": (180, 180, 195),
        }

        # === 시간 왜곡 오라 (배경 효과) ===
        aura_size = int(5 * b)
        aura_surf = pygame.Surface((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
        for i in range(4):
            aura_alpha = int(25 - i * 6)
            aura_r = int((2.2 - i * 0.4) * b)
            pygame.draw.circle(aura_surf, (*p["time_aura"], aura_alpha), (aura_size, aura_size), aura_r)
        screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - int(1.2 * b) - aura_size // 2), special_flags=pygame.BLEND_ADD)

        # 시간 입자 (떠다니는 모래/빛 입자)
        for i in range(8):
            particle_angle = self.time * 0.8 + i * math.pi / 4
            particle_r = int(2.5 * b + math.sin(self.time * 2 + i) * 0.3 * b)
            px = cx + int(math.cos(particle_angle) * particle_r) + lean_offset
            py = torso_y - int(0.5 * b) + int(math.sin(particle_angle * 2 + self.time) * 0.8 * b)
            particle_alpha = int(100 + 50 * math.sin(self.time * 3 + i))
            particle_surf = pygame.Surface((int(0.3 * b), int(0.3 * b)), pygame.SRCALPHA)
            pygame.draw.circle(particle_surf, (*p["sand"], particle_alpha), (int(0.15 * b), int(0.15 * b)), max(1, int(0.1 * b)))
            screen.blit(particle_surf, (int(px - 0.15 * b), int(py - 0.15 * b)))

        # === 로브 하단 (시계추 장식) ===
        robe_points = [
            (cx - int(1.4 * b) + lean_offset, torso_y + int(1.6 * b)),
            (cx + int(1.4 * b) + lean_offset, torso_y + int(1.6 * b)),
            (cx + int(2.0 * b) + lean_offset + int(wave * 0.25 * b), cy + int(3.2 * b)),
            (cx - int(2.0 * b) + lean_offset - int(wave * 0.25 * b), cy + int(3.2 * b)),
        ]
        pygame.draw.polygon(screen, p["robe"], robe_points)

        # 로브 주름 디테일
        for i in range(5):
            fold_x = cx + (i - 2) * int(0.5 * b) + lean_offset
            fold_top_y = torso_y + int(1.8 * b)
            fold_bot_y = cy + int(3.0 * b)
            pygame.draw.line(screen, p["robe_mid"], (fold_x, fold_top_y), (fold_x + int(wave * 0.05 * b), fold_bot_y), 1)

        # 로브 금색 테두리 (이중선)
        pygame.draw.line(screen, p["gold_dark"], robe_points[0], robe_points[3], max(2, int(0.12 * b)))
        pygame.draw.line(screen, p["gold"], robe_points[0], robe_points[3], max(1, int(0.06 * b)))
        pygame.draw.line(screen, p["gold_dark"], robe_points[1], robe_points[2], max(2, int(0.12 * b)))
        pygame.draw.line(screen, p["gold"], robe_points[1], robe_points[2], max(1, int(0.06 * b)))

        # 로브 하단 시계 패턴
        for i in range(3):
            clock_x = cx + (i - 1) * int(0.9 * b) + lean_offset
            clock_y = cy + int(2.4 * b)
            clock_r = max(2, int(0.25 * b))
            pygame.draw.circle(screen, p["gold_dark"], (int(clock_x), int(clock_y)), clock_r)
            pygame.draw.circle(screen, p["clock_face"], (int(clock_x), int(clock_y)), clock_r - 1)
            # 시계 바늘
            hand_angle = self.time * (2 + i)
            hx = clock_x + int(math.cos(hand_angle) * clock_r * 0.6)
            hy = clock_y + int(math.sin(hand_angle) * clock_r * 0.6)
            pygame.draw.line(screen, p["gold_dark"], (int(clock_x), int(clock_y)), (int(hx), int(hy)), 1)

        # 시계추 (로브 아래에 흔들림) - 더 정교함
        pendulum_swing = math.sin(self.time * 2) * 0.5
        pendulum_x = cx + lean_offset + int(pendulum_swing * b)
        pendulum_y = cy + int(2.8 * b)
        chain_segments = 5
        for seg in range(chain_segments):
            seg_y = torso_y + int(2.0 * b) + seg * int(0.18 * b)
            seg_x = cx + lean_offset + int(pendulum_swing * (seg / chain_segments) * b)
            pygame.draw.circle(screen, p["gold_dark"], (int(seg_x), int(seg_y)), max(1, int(0.06 * b)))
        # 시계추 본체
        pygame.draw.circle(screen, p["gold_shadow"], (int(pendulum_x + 1), int(pendulum_y + 1)), max(3, int(0.32 * b)))
        pygame.draw.circle(screen, p["gold"], (int(pendulum_x), int(pendulum_y)), max(3, int(0.3 * b)))
        pygame.draw.circle(screen, p["gold_light"], (int(pendulum_x - 1), int(pendulum_y - 1)), max(1, int(0.15 * b)))

        # === 몸통 (톱니바퀴 장식 로브) ===
        chest_w, chest_h = int(3.0 * b), int(2.2 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.3 * b), chest_w, chest_h)

        # 몸통 그림자
        shadow_rect = chest_rect.inflate(int(0.15 * b), int(0.1 * b))
        shadow_rect.move_ip(int(0.1 * b), int(0.12 * b))
        pygame.draw.rect(screen, (30, 25, 45), shadow_rect, border_radius=int(0.45 * b))

        pygame.draw.rect(screen, p["robe"], chest_rect, border_radius=int(0.45 * b))
        pygame.draw.rect(screen, p["robe_mid"], chest_rect.inflate(-int(0.35 * b), -int(0.25 * b)), border_radius=int(0.35 * b))
        pygame.draw.rect(screen, p["robe_light"], chest_rect.inflate(-int(0.7 * b), -int(0.5 * b)), border_radius=int(0.25 * b))

        # 로브 무늬 (세로줄)
        for i in range(3):
            line_x = chest_rect.left + int((i + 1) * 0.7 * b)
            pygame.draw.line(screen, p["robe_highlight"], (line_x, chest_rect.top + int(0.3 * b)),
                           (line_x, chest_rect.bottom - int(0.2 * b)), 1)

        # === 가슴 대형 톱니바퀴 ===
        gear_cx, gear_cy = chest_rect.centerx, chest_rect.centery
        gear_r = int(0.65 * b)

        # 톱니바퀴 글로우
        glow_surf = pygame.Surface((int(1.8 * b), int(1.8 * b)), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*p["glow"], int(40 * time_pulse)), (int(0.9 * b), int(0.9 * b)), int(0.8 * b))
        screen.blit(glow_surf, (gear_cx - int(0.9 * b), gear_cy - int(0.9 * b)), special_flags=pygame.BLEND_ADD)

        # 톱니바퀴 외곽 (이빨 포함)
        tooth_count = 12
        for i in range(tooth_count):
            angle = gear_spin + i * 2 * math.pi / tooth_count
            inner_r = gear_r * 0.75
            outer_r = gear_r
            # 이빨 꼭짓점
            t1_angle = angle - 0.15
            t2_angle = angle + 0.15
            points = [
                (gear_cx + int(math.cos(t1_angle) * inner_r), gear_cy + int(math.sin(t1_angle) * inner_r)),
                (gear_cx + int(math.cos(angle) * outer_r), gear_cy + int(math.sin(angle) * outer_r)),
                (gear_cx + int(math.cos(t2_angle) * inner_r), gear_cy + int(math.sin(t2_angle) * inner_r)),
            ]
            pygame.draw.polygon(screen, p["gear"], points)
            pygame.draw.polygon(screen, p["gear_dark"], points, 1)

        # 톱니바퀴 중심
        pygame.draw.circle(screen, p["gear_dark"], (gear_cx, gear_cy), int(gear_r * 0.6))
        pygame.draw.circle(screen, p["gold"], (gear_cx, gear_cy), int(gear_r * 0.5))
        pygame.draw.circle(screen, p["gold_light"], (gear_cx, gear_cy), int(gear_r * 0.35))
        pygame.draw.circle(screen, p["gold_mid"], (gear_cx, gear_cy), int(gear_r * 0.2))

        # 내부 작은 톱니바퀴 (반대 방향 회전)
        small_gear_r = int(0.25 * b)
        for offset_x, offset_y in [(-0.35, -0.35), (0.35, -0.35), (-0.35, 0.35), (0.35, 0.35)]:
            sg_cx = gear_cx + int(offset_x * b)
            sg_cy = gear_cy + int(offset_y * b)
            for i in range(6):
                angle = -gear_spin * 1.5 + i * math.pi / 3
                tx = sg_cx + int(math.cos(angle) * small_gear_r)
                ty = sg_cy + int(math.sin(angle) * small_gear_r)
                pygame.draw.circle(screen, p["gear_light"], (tx, ty), max(1, int(0.06 * b)))
            pygame.draw.circle(screen, p["gear"], (sg_cx, sg_cy), max(1, int(0.12 * b)))

        # === 허리띠 (시계 장식) ===
        belt_rect = pygame.Rect(cx - int(1.4 * b) + lean_offset, chest_rect.bottom - 3, int(2.8 * b), int(0.8 * b))
        pygame.draw.rect(screen, p["gold_shadow"], belt_rect, border_radius=3)
        pygame.draw.rect(screen, p["gold_dark"], belt_rect.inflate(-2, -2), border_radius=2)
        # 벨트 버클 (시계)
        buckle_cx = belt_rect.centerx
        buckle_cy = belt_rect.centery
        pygame.draw.circle(screen, p["gold"], (buckle_cx, buckle_cy), max(3, int(0.3 * b)))
        pygame.draw.circle(screen, p["clock_face"], (buckle_cx, buckle_cy), max(2, int(0.22 * b)))
        # 시계 숫자 표시
        for i in range(4):
            num_angle = -math.pi / 2 + i * math.pi / 2
            num_r = int(0.16 * b)
            nx = buckle_cx + int(math.cos(num_angle) * num_r)
            ny = buckle_cy + int(math.sin(num_angle) * num_r)
            pygame.draw.circle(screen, p["gold_dark"], (int(nx), int(ny)), 1)
        # 시계 바늘
        hour_angle = self.time * 0.5 - math.pi / 2
        min_angle = self.time * 3 - math.pi / 2
        pygame.draw.line(screen, p["gold_dark"], (buckle_cx, buckle_cy),
                        (buckle_cx + int(math.cos(hour_angle) * 0.12 * b), buckle_cy + int(math.sin(hour_angle) * 0.12 * b)), 2)
        pygame.draw.line(screen, p["gold_shadow"], (buckle_cx, buckle_cy),
                        (buckle_cx + int(math.cos(min_angle) * 0.18 * b), buckle_cy + int(math.sin(min_angle) * 0.18 * b)), 1)

        # === 어깨 장식 (시계 모양, 더 정교함) ===
        for side in [-1, 1]:
            shoulder_x = cx + side * int(1.3 * b) + lean_offset
            shoulder_y = torso_y - int(0.1 * b)
            shoulder_r = max(4, int(0.55 * b))

            # 시계 테두리
            pygame.draw.circle(screen, p["gold_shadow"], (shoulder_x + 1, shoulder_y + 1), shoulder_r)
            pygame.draw.circle(screen, p["gold"], (shoulder_x, shoulder_y), shoulder_r)
            pygame.draw.circle(screen, p["gold_dark"], (shoulder_x, shoulder_y), shoulder_r, 2)
            pygame.draw.circle(screen, p["clock_face"], (shoulder_x, shoulder_y), shoulder_r - 3)

            # 시계 숫자 (로마 숫자 느낌)
            for i in range(12):
                mark_angle = -math.pi / 2 + i * math.pi / 6
                mark_r = shoulder_r - 5 if i % 3 == 0 else shoulder_r - 4
                mark_len = 3 if i % 3 == 0 else 2
                mx1 = shoulder_x + int(math.cos(mark_angle) * (mark_r - mark_len))
                my1 = shoulder_y + int(math.sin(mark_angle) * (mark_r - mark_len))
                mx2 = shoulder_x + int(math.cos(mark_angle) * mark_r)
                my2 = shoulder_y + int(math.sin(mark_angle) * mark_r)
                pygame.draw.line(screen, p["gold_dark"], (mx1, my1), (mx2, my2), 1)

            # 시계 바늘
            hour_angle = self.time * 0.3 * side - math.pi / 2
            min_angle = self.time * 2 * side - math.pi / 2
            sec_angle = self.time * 6 * side - math.pi / 2
            # 시침
            pygame.draw.line(screen, p["gold_dark"], (shoulder_x, shoulder_y),
                           (shoulder_x + int(math.cos(hour_angle) * (shoulder_r - 8)), shoulder_y + int(math.sin(hour_angle) * (shoulder_r - 8))), 2)
            # 분침
            pygame.draw.line(screen, p["gold_shadow"], (shoulder_x, shoulder_y),
                           (shoulder_x + int(math.cos(min_angle) * (shoulder_r - 5)), shoulder_y + int(math.sin(min_angle) * (shoulder_r - 5))), 1)
            # 초침 (빨간색 느낌)
            pygame.draw.line(screen, (200, 150, 100), (shoulder_x, shoulder_y),
                           (shoulder_x + int(math.cos(sec_angle) * (shoulder_r - 4)), shoulder_y + int(math.sin(sec_angle) * (shoulder_r - 4))), 1)
            # 중심 점
            pygame.draw.circle(screen, p["gold"], (shoulder_x, shoulder_y), max(1, int(0.08 * b)))

        # === 팔 (로브 소매 + 어깨 들썩임) ===
        for side in [-1, 1]:
            shoulder_bob_offset = int(shoulder_bob * 0.3 * b)
            shoulder = (cx + side * int(1.2 * b) + lean_offset, torso_y + int(0.3 * b) + shoulder_bob_offset)
            elbow = (shoulder[0] + side * int(0.5 * b), torso_y + int(1.0 * b))
            wrist = (elbow[0] + side * int(0.4 * b) + int(wave * side * 0.1 * b), torso_y + int(1.6 * b))

            # 상완
            pygame.draw.line(screen, p["robe"], shoulder, elbow, max(3, int(0.55 * b)))
            pygame.draw.line(screen, p["robe_mid"], shoulder, elbow, max(2, int(0.4 * b)))
            # 하완
            pygame.draw.line(screen, p["robe_mid"], elbow, wrist, max(3, int(0.5 * b)))
            pygame.draw.line(screen, p["robe_light"], elbow, wrist, max(2, int(0.35 * b)))
            # 소매 끝 장식
            pygame.draw.circle(screen, p["gold_dark"], wrist, max(2, int(0.22 * b)))
            # 손
            pygame.draw.circle(screen, p["skin"], (wrist[0], wrist[1] + int(0.15 * b)), max(2, int(0.25 * b)))
            pygame.draw.circle(screen, p["skin_shadow"], (wrist[0] + 1, wrist[1] + int(0.15 * b) + 1), max(2, int(0.25 * b)))

        # === 머리 (후드 + 시간의 눈) ===
        head_y = torso_y - int(3.0 * b)
        head_w, head_h = int(2.4 * b), int(2.2 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        # 후드 (더 입체감)
        hood_outer = [
            (head_rect.left - int(0.3 * b), head_rect.bottom + int(0.1 * b)),
            (head_rect.left + int(0.2 * b), head_rect.top - int(0.3 * b)),
            (head_rect.centerx, head_rect.top - int(0.7 * b)),
            (head_rect.right - int(0.2 * b), head_rect.top - int(0.3 * b)),
            (head_rect.right + int(0.3 * b), head_rect.bottom + int(0.1 * b)),
        ]
        pygame.draw.polygon(screen, p["robe"], hood_outer)
        # 후드 내부 음영
        hood_inner = [
            (head_rect.left + int(0.1 * b), head_rect.bottom),
            (head_rect.left + int(0.4 * b), head_rect.top + int(0.2 * b)),
            (head_rect.centerx, head_rect.top),
            (head_rect.right - int(0.4 * b), head_rect.top + int(0.2 * b)),
            (head_rect.right - int(0.1 * b), head_rect.bottom),
        ]
        pygame.draw.polygon(screen, p["robe_mid"], hood_inner)
        # 후드 테두리
        pygame.draw.lines(screen, p["gold_dark"], False, hood_outer, 2)

        if show_back:
            # 뒷모습 - 후드 뒷면 패턴
            pygame.draw.polygon(screen, p["robe_light"], hood_inner, 1)
            # 모래시계 문양 (더 상세)
            hg_cx, hg_cy = head_rect.centerx, head_rect.centery
            hg_w, hg_h = int(0.5 * b), int(0.7 * b)
            # 상단 삼각형
            pygame.draw.polygon(screen, p["gold_dark"], [
                (hg_cx - int(0.25 * b), hg_cy - int(0.35 * b)),
                (hg_cx + int(0.25 * b), hg_cy - int(0.35 * b)),
                (hg_cx, hg_cy),
            ])
            pygame.draw.polygon(screen, p["gold"], [
                (hg_cx - int(0.2 * b), hg_cy - int(0.3 * b)),
                (hg_cx + int(0.2 * b), hg_cy - int(0.3 * b)),
                (hg_cx, hg_cy - int(0.05 * b)),
            ])
            # 하단 삼각형
            pygame.draw.polygon(screen, p["gold_dark"], [
                (hg_cx, hg_cy),
                (hg_cx - int(0.25 * b), hg_cy + int(0.35 * b)),
                (hg_cx + int(0.25 * b), hg_cy + int(0.35 * b)),
            ])
            pygame.draw.polygon(screen, p["gold"], [
                (hg_cx, hg_cy + int(0.05 * b)),
                (hg_cx - int(0.2 * b), hg_cy + int(0.3 * b)),
                (hg_cx + int(0.2 * b), hg_cy + int(0.3 * b)),
            ])
            # 프레임
            pygame.draw.rect(screen, p["gold_dark"], (hg_cx - int(0.28 * b), hg_cy - int(0.38 * b), int(0.56 * b), int(0.76 * b)), 1)
        else:
            # 정면 - 얼굴
            face_rect = head_rect.inflate(-int(0.6 * b), -int(0.5 * b))
            face_rect.move_ip(0, int(0.25 * b))
            # 얼굴 그림자
            pygame.draw.ellipse(screen, p["skin_shadow"], face_rect.inflate(2, 2))
            pygame.draw.ellipse(screen, p["skin"], face_rect)
            # 주름 (나이든 느낌)
            for i in range(2):
                wrinkle_y = face_rect.top + int(0.25 * b) + i * int(0.2 * b)
                pygame.draw.arc(screen, p["skin_shadow"],
                              (face_rect.centerx - int(0.4 * b), wrinkle_y, int(0.8 * b), int(0.15 * b)),
                              0, math.pi, 1)

            # 시간의 눈 (시계 무늬 홍채, 더 정교함)
            eye_y = face_rect.centery - int(0.05 * b)
            for side in [-1, 1]:
                eye_x = face_rect.centerx + side * int(0.28 * b)
                eye_r = max(2, int(0.18 * b))

                # 눈 글로우
                glow_surf = pygame.Surface((int(0.6 * b), int(0.6 * b)), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*p["eye_glow"], int(50 * time_pulse)), (int(0.3 * b), int(0.3 * b)), int(0.25 * b))
                screen.blit(glow_surf, (eye_x - int(0.3 * b), eye_y - int(0.3 * b)), special_flags=pygame.BLEND_ADD)

                # 눈 외곽
                pygame.draw.circle(screen, (100, 90, 80), (eye_x, eye_y), eye_r + 1)
                # 눈 본체
                pygame.draw.circle(screen, p["eye"], (eye_x, eye_y), eye_r)
                # 시계 바늘 홍채
                needle_angle1 = self.time * 4
                needle_angle2 = self.time * 1.5
                n1x = eye_x + int(math.cos(needle_angle1) * eye_r * 0.6)
                n1y = eye_y + int(math.sin(needle_angle1) * eye_r * 0.6)
                n2x = eye_x + int(math.cos(needle_angle2) * eye_r * 0.4)
                n2y = eye_y + int(math.sin(needle_angle2) * eye_r * 0.4)
                pygame.draw.line(screen, p["gold_dark"], (eye_x, eye_y), (n1x, n1y), 1)
                pygame.draw.line(screen, p["gold_shadow"], (eye_x, eye_y), (n2x, n2y), 1)
                # 하이라이트
                pygame.draw.circle(screen, (255, 255, 255), (eye_x - 1, eye_y - 1), max(1, eye_r // 3))

            # 콧대
            pygame.draw.line(screen, p["skin_shadow"], (face_rect.centerx, eye_y + int(0.1 * b)),
                           (face_rect.centerx, face_rect.bottom - int(0.3 * b)), 1)

            # 긴 수염 (더 상세)
            beard_top_y = face_rect.bottom - int(0.25 * b)
            beard_points = [
                (face_rect.centerx - int(0.35 * b), beard_top_y),
                (face_rect.centerx + int(0.35 * b), beard_top_y),
                (face_rect.centerx + int(0.25 * b), beard_top_y + int(0.4 * b)),
                (face_rect.centerx, beard_top_y + int(0.8 * b) + int(wave * 0.1 * b)),
                (face_rect.centerx - int(0.25 * b), beard_top_y + int(0.4 * b)),
            ]
            pygame.draw.polygon(screen, p["beard_shadow"], beard_points)
            # 수염 하이라이트
            beard_inner = [
                (face_rect.centerx - int(0.25 * b), beard_top_y + int(0.05 * b)),
                (face_rect.centerx + int(0.25 * b), beard_top_y + int(0.05 * b)),
                (face_rect.centerx, beard_top_y + int(0.6 * b) + int(wave * 0.08 * b)),
            ]
            pygame.draw.polygon(screen, p["beard"], beard_inner)
            # 수염 결
            for i in range(3):
                bx = face_rect.centerx + (i - 1) * int(0.12 * b)
                pygame.draw.line(screen, p["beard_shadow"], (bx, beard_top_y + int(0.1 * b)),
                               (bx, beard_top_y + int(0.5 * b)), 1)

        # === 시간의 지팡이 (모래시계 장식, 고퀄리티) ===
        staff_x = cx + int(2.5 * b) + lean_offset
        staff_top = head_y - int(0.5 * b)
        staff_bottom = cy + int(2.8 * b)

        # 지팡이 그림자
        pygame.draw.line(screen, p["gold_shadow"], (staff_x + 2, staff_top + 2), (staff_x + 2, staff_bottom + 2), max(3, int(0.3 * b)))
        # 지팡이 본체
        pygame.draw.line(screen, p["gold_dark"], (staff_x, staff_top), (staff_x, staff_bottom), max(3, int(0.28 * b)))
        pygame.draw.line(screen, p["gold"], (staff_x - 1, staff_top), (staff_x - 1, staff_bottom), max(2, int(0.18 * b)))
        # 지팡이 장식 링
        for ring_y in [staff_top + int(0.5 * b), staff_bottom - int(0.5 * b), (staff_top + staff_bottom) // 2]:
            pygame.draw.circle(screen, p["gold_light"], (staff_x, ring_y), max(2, int(0.18 * b)))
            pygame.draw.circle(screen, p["gold_dark"], (staff_x, ring_y), max(2, int(0.18 * b)), 1)

        # 모래시계 장식 (더 정교함)
        hourglass_y = staff_top - int(0.8 * b)
        hourglass_h = int(1.0 * b)
        hourglass_w = int(0.45 * b)

        # 모래시계 프레임
        pygame.draw.rect(screen, p["gold_dark"], (staff_x - hourglass_w, hourglass_y - int(0.1 * b), hourglass_w * 2, hourglass_h + int(0.2 * b)), 2)
        # 상단 삼각형 (유리)
        pygame.draw.polygon(screen, p["clock_face"], [
            (staff_x - hourglass_w + 3, hourglass_y),
            (staff_x + hourglass_w - 3, hourglass_y),
            (staff_x, hourglass_y + hourglass_h // 2 - 2),
        ])
        # 하단 삼각형 (유리)
        pygame.draw.polygon(screen, p["clock_face"], [
            (staff_x, hourglass_y + hourglass_h // 2 + 2),
            (staff_x - hourglass_w + 3, hourglass_y + hourglass_h),
            (staff_x + hourglass_w - 3, hourglass_y + hourglass_h),
        ])
        # 모래 (상단 - 비워지는 중)
        sand_level = (self.time * 0.3) % 1
        sand_top_h = int((1 - sand_level) * hourglass_h * 0.35)
        if sand_top_h > 2:
            pygame.draw.polygon(screen, p["sand"], [
                (staff_x - int(hourglass_w * 0.6), hourglass_y + 3),
                (staff_x + int(hourglass_w * 0.6), hourglass_y + 3),
                (staff_x, hourglass_y + 3 + sand_top_h),
            ])
        # 모래 (하단 - 쌓이는 중)
        sand_bot_h = int(sand_level * hourglass_h * 0.35)
        if sand_bot_h > 2:
            sand_bot_y = hourglass_y + hourglass_h - 3 - sand_bot_h
            pygame.draw.polygon(screen, p["sand"], [
                (staff_x, sand_bot_y),
                (staff_x - int(hourglass_w * 0.5), hourglass_y + hourglass_h - 3),
                (staff_x + int(hourglass_w * 0.5), hourglass_y + hourglass_h - 3),
            ])
        # 떨어지는 모래 입자
        for i in range(3):
            sand_particle_y = hourglass_y + hourglass_h // 2 + int(((self.time * 2 + i * 0.3) % 1) * hourglass_h * 0.4)
            pygame.draw.circle(screen, p["sand"], (staff_x, int(sand_particle_y)), 1)

        # 모래시계 글로우
        glow_surf = pygame.Surface((int(1.5 * b), int(1.8 * b)), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_surf, (*p["glow"], int(30 * time_pulse)), (0, 0, int(1.5 * b), int(1.8 * b)))
        screen.blit(glow_surf, (staff_x - int(0.75 * b), hourglass_y - int(0.2 * b)), special_flags=pygame.BLEND_ADD)

    # =========================================================================
    # 오니마루 - 지옥의 요괴무사 (뿔 달린 도깨비) [고퀄리티 업그레이드]
    # =========================================================================
    def _draw_onimaru(self, screen, cx, cy, b, color, show_back, anim):
        """오니마루 - 지옥의 요괴무사 (동양풍 도깨비 전사) [고퀄리티]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        left_arm_swing = anim.get("left_arm_swing", 0)
        right_arm_swing = anim.get("right_arm_swing", 0)
        # 발토르 스타일 다리/어깨 애니메이션
        left_leg_sway = anim.get("left_leg_sway", 0)
        right_leg_sway = anim.get("right_leg_sway", 0)
        left_leg_lift = anim.get("left_leg", 0)
        right_leg_lift = anim.get("right_leg", 0)
        shoulder_bob = anim.get("shoulder_bob", 0)
        left_shoulder = anim.get("left_shoulder", 0)
        right_shoulder = anim.get("right_shoulder", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        # 분노 펄스 (눈/오라 효과)
        rage_pulse = (math.sin(self.time * 3) + 1) * 0.5
        breath_cycle = math.sin(self.time * 1.5) * 0.1

        p = {
            "skin": color,  # 붉은 피부
            "skin_light": tuple(min(255, c + 50) for c in color),
            "skin_mid": tuple(min(255, c + 25) for c in color),
            "skin_dark": tuple(max(0, c - 50) for c in color),
            "skin_shadow": tuple(max(0, c - 80) for c in color),
            "horn": (70, 60, 50),
            "horn_mid": (100, 85, 70),
            "horn_light": (130, 110, 90),
            "horn_tip": (50, 40, 35),
            "armor": (50, 45, 60),
            "armor_mid": (70, 60, 85),
            "armor_light": (90, 80, 110),
            "armor_gold": (200, 165, 90),
            "armor_gold_light": (230, 195, 120),
            "armor_gold_dark": (150, 120, 60),
            "hair": (15, 15, 25),
            "hair_highlight": (40, 35, 55),
            "eye": (255, 230, 60),
            "eye_glow": (255, 160, 50),
            "eye_inner": (255, 100, 30),
            "pupil": (80, 30, 20),
            "fangs": (255, 255, 245),
            "fangs_shadow": (220, 215, 200),
            "club": (90, 70, 50),
            "club_dark": (60, 45, 35),
            "club_light": (120, 95, 70),
            "club_metal": (210, 180, 90),
            "club_metal_light": (240, 210, 130),
            "flame": (255, 120, 40),
            "flame_inner": (255, 200, 100),
            "tiger": (200, 160, 90),  # 호피 베이스
            "tiger_dark": (90, 70, 40),  # 호피 무늬
            "tiger_light": (230, 190, 120),
            "tattoo": (40, 30, 50),  # 문신
        }

        # === 지옥의 오라 (배경 효과) ===
        aura_size = int(5 * b)
        aura_surf = pygame.Surface((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
        for i in range(3):
            aura_alpha = int((20 - i * 6) * (0.7 + rage_pulse * 0.3))
            aura_r = int((2.0 - i * 0.5) * b)
            pygame.draw.circle(aura_surf, (*p["flame"], aura_alpha), (aura_size, aura_size), aura_r)
        screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - int(1 * b) - aura_size // 2), special_flags=pygame.BLEND_ADD)

        # 불꽃 파티클 (어깨 주변)
        for i in range(5):
            flame_x = cx + int(math.sin(self.time * 4 + i * 1.3) * 1.8 * b) + lean_offset
            flame_y = torso_y - int(0.5 * b) - int(((self.time * 2 + i * 0.4) % 1) * 1.5 * b)
            flame_alpha = int(180 * (1 - ((self.time * 2 + i * 0.4) % 1)))
            flame_size = max(1, int(0.15 * b * (1 - ((self.time * 2 + i * 0.4) % 1))))
            flame_surf = pygame.Surface((flame_size * 4, flame_size * 4), pygame.SRCALPHA)
            pygame.draw.circle(flame_surf, (*p["flame_inner"], flame_alpha), (flame_size * 2, flame_size * 2), flame_size)
            screen.blit(flame_surf, (int(flame_x) - flame_size * 2, int(flame_y) - flame_size * 2), special_flags=pygame.BLEND_ADD)

        # === 다리 (근육질 다리 + 호피 천) - 발토르 스타일 스윙 ===
        hip_y = torso_y + int(2.0 * b)
        for side in [-1, 1]:
            # 발토르 스타일 다리 움직임
            current_leg_sway = left_leg_sway if side == -1 else right_leg_sway
            current_leg_lift = left_leg_lift if side == -1 else right_leg_lift
            leg_sway_x = int(current_leg_sway * 0.5 * b)  # X 방향 스윙
            leg_lift_y = int(current_leg_lift * 0.2 * b)  # Y 방향 들어올림
            thigh_x = cx + side * int(0.55 * b) + lean_offset + leg_sway_x

            # 다리 움직임 페이즈 (걷기 애니메이션)
            leg_phase = int(current_leg_lift * 0.3 * b)

            # 허벅지 (근육 + 호피무늬 천)
            thigh_rect = pygame.Rect(thigh_x - int(0.55 * b), hip_y - leg_lift_y, int(1.1 * b), int(2.0 * b))

            # 근육 (아래쪽 드러남)
            muscle_rect = pygame.Rect(thigh_x - int(0.45 * b), hip_y + int(1.0 * b) + leg_phase, int(0.9 * b), int(1.0 * b))
            pygame.draw.ellipse(screen, p["skin_dark"], muscle_rect)
            pygame.draw.ellipse(screen, p["skin"], muscle_rect.inflate(-int(0.15 * b), -int(0.1 * b)))

            # 호피 천 (윗부분)
            tiger_rect = pygame.Rect(thigh_x - int(0.55 * b), hip_y + leg_phase - int(0.1 * b), int(1.1 * b), int(1.2 * b))
            pygame.draw.rect(screen, p["tiger"], tiger_rect, border_radius=4)
            pygame.draw.rect(screen, p["tiger_light"], tiger_rect.inflate(-int(0.2 * b), -int(0.15 * b)), border_radius=3)

            # 호피 무늬 (더 상세)
            tiger_patterns = [(0.2, 0.25), (-0.15, 0.5), (0.1, 0.75), (-0.2, 0.9)]
            for px_off, py_off in tiger_patterns:
                spot_x = tiger_rect.centerx + int(px_off * b)
                spot_y = tiger_rect.top + int(py_off * b)
                # 불규칙한 무늬
                pygame.draw.ellipse(screen, p["tiger_dark"],
                                   (spot_x - int(0.15 * b), spot_y - int(0.08 * b), int(0.3 * b), int(0.16 * b)))

            # 천 하단 찢어진 가장자리
            for i in range(4):
                tear_x = tiger_rect.left + int((i + 0.5) * 0.28 * b)
                tear_y = tiger_rect.bottom
                pygame.draw.polygon(screen, p["tiger"], [
                    (tear_x, tear_y - 2),
                    (tear_x + int(0.1 * b), tear_y + int(0.15 * b)),
                    (tear_x - int(0.1 * b), tear_y + int(0.12 * b)),
                ])

            # 맨발 (발가락 포함)
            foot_x = thigh_x
            foot_y = thigh_rect.bottom + int(0.1 * b)
            pygame.draw.ellipse(screen, p["skin_shadow"], (foot_x - int(0.45 * b), foot_y, int(0.9 * b), int(0.55 * b)))
            pygame.draw.ellipse(screen, p["skin_dark"], (foot_x - int(0.4 * b), foot_y - int(0.05 * b), int(0.8 * b), int(0.5 * b)))
            # 발가락
            for toe in range(3):
                toe_x = foot_x - int(0.2 * b) + toe * int(0.2 * b)
                pygame.draw.circle(screen, p["skin"], (int(toe_x), int(foot_y)), max(1, int(0.1 * b)))

        # === 몸통 (근육질 상체) ===
        chest_w, chest_h = int(3.2 * b), int(2.4 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.4 * b), chest_w, chest_h)

        # 몸통 그림자
        shadow_rect = chest_rect.inflate(int(0.15 * b), int(0.1 * b))
        shadow_rect.move_ip(int(0.1 * b), int(0.12 * b))
        pygame.draw.rect(screen, p["skin_shadow"], shadow_rect, border_radius=int(0.55 * b))

        pygame.draw.rect(screen, p["skin"], chest_rect, border_radius=int(0.5 * b))
        pygame.draw.rect(screen, p["skin_mid"], chest_rect.inflate(-int(0.4 * b), -int(0.35 * b)), border_radius=int(0.4 * b))
        pygame.draw.rect(screen, p["skin_light"], chest_rect.inflate(-int(0.9 * b), -int(0.7 * b)), border_radius=int(0.3 * b))

        # 근육 디테일 (복근, 가슴근육)
        # 중앙선
        pygame.draw.line(screen, p["skin_dark"], (chest_rect.centerx, chest_rect.top + int(0.35 * b)),
                        (chest_rect.centerx, chest_rect.bottom - int(0.2 * b)), max(2, int(0.08 * b)))

        # 가슴근육 (양쪽)
        for side in [-1, 1]:
            pec_cx = chest_rect.centerx + side * int(0.55 * b)
            pec_cy = chest_rect.top + int(0.6 * b)
            pygame.draw.arc(screen, p["skin_dark"],
                          (pec_cx - int(0.5 * b), pec_cy - int(0.25 * b), int(1.0 * b), int(0.7 * b)),
                          math.radians(0), math.radians(180), 2)
            # 가슴근육 하이라이트
            pygame.draw.arc(screen, p["skin_light"],
                          (pec_cx - int(0.4 * b), pec_cy - int(0.15 * b), int(0.6 * b), int(0.4 * b)),
                          math.radians(30), math.radians(150), 1)

        # 복근 라인
        for row in range(2):
            for col in [-1, 1]:
                ab_x = chest_rect.centerx + col * int(0.25 * b)
                ab_y = chest_rect.centery + int(0.3 * b) + row * int(0.35 * b)
                pygame.draw.ellipse(screen, p["skin_dark"],
                                   (ab_x - int(0.2 * b), ab_y - int(0.12 * b), int(0.4 * b), int(0.28 * b)), 1)

        # 문신 (도깨비 문양) - 왼쪽 가슴
        tattoo_cx = chest_rect.centerx - int(0.6 * b)
        tattoo_cy = chest_rect.top + int(0.7 * b)
        # 소용돌이 문양
        for i in range(8):
            angle = i * math.pi / 4 + self.time * 0.5
            t_r = int(0.2 * b) + i * int(0.03 * b)
            tx = tattoo_cx + int(math.cos(angle) * t_r * 0.8)
            ty = tattoo_cy + int(math.sin(angle) * t_r * 0.6)
            pygame.draw.circle(screen, p["tattoo"], (tx, ty), max(1, int(0.04 * b)))

        # 허리 천 (호피무늬 + 금장식)
        belt_rect = pygame.Rect(cx - int(1.5 * b) + lean_offset, chest_rect.bottom - 4, int(3.0 * b), int(0.9 * b))
        pygame.draw.rect(screen, p["tiger"], belt_rect, border_radius=3)
        # 호피 무늬
        for i in range(5):
            bspot_x = belt_rect.left + int((i + 0.5) * 0.55 * b)
            bspot_y = belt_rect.centery
            pygame.draw.ellipse(screen, p["tiger_dark"],
                               (bspot_x - int(0.12 * b), bspot_y - int(0.1 * b), int(0.24 * b), int(0.2 * b)))
        # 금장식 버클
        buckle_cx = belt_rect.centerx
        pygame.draw.circle(screen, p["armor_gold_dark"], (buckle_cx, belt_rect.centery), max(3, int(0.3 * b)))
        pygame.draw.circle(screen, p["armor_gold"], (buckle_cx, belt_rect.centery), max(2, int(0.25 * b)))
        pygame.draw.circle(screen, p["armor_gold_light"], (buckle_cx - 1, belt_rect.centery - 1), max(1, int(0.12 * b)))
        # 테두리
        pygame.draw.rect(screen, p["armor_gold_dark"], belt_rect, 2, border_radius=3)

        # === 어깨 갑옷 (스파이크, 더 정교함) ===
        for side in [-1, 1]:
            shoulder_x = cx + side * int(1.45 * b) + lean_offset
            shoulder_y = torso_y - int(0.25 * b)
            shoulder_r = max(4, int(0.6 * b))

            # 어깨 갑옷 베이스
            pygame.draw.circle(screen, p["armor"], (shoulder_x + 1, shoulder_y + 1), shoulder_r + 2)
            pygame.draw.circle(screen, p["armor_mid"], (shoulder_x, shoulder_y), shoulder_r)
            pygame.draw.circle(screen, p["armor_light"], (shoulder_x - 2, shoulder_y - 2), int(shoulder_r * 0.6))

            # 갑옷 문양 (원형)
            pygame.draw.circle(screen, p["armor_gold"], (shoulder_x, shoulder_y), int(shoulder_r * 0.4), 2)

            # 스파이크 (5개)
            for i in range(5):
                spike_angle = side * math.pi / 4 + (i - 2) * 0.35
                spike_len = int(0.7 * b)
                spike_base_w = int(0.15 * b)

                # 스파이크 꼭짓점
                spike_tip_x = shoulder_x + int(math.cos(spike_angle) * (shoulder_r + spike_len))
                spike_tip_y = shoulder_y + int(math.sin(spike_angle) * (shoulder_r + spike_len))
                spike_base1_x = shoulder_x + int(math.cos(spike_angle + 0.3) * shoulder_r)
                spike_base1_y = shoulder_y + int(math.sin(spike_angle + 0.3) * shoulder_r)
                spike_base2_x = shoulder_x + int(math.cos(spike_angle - 0.3) * shoulder_r)
                spike_base2_y = shoulder_y + int(math.sin(spike_angle - 0.3) * shoulder_r)

                # 스파이크 그리기
                spike_points = [(spike_base1_x, spike_base1_y), (spike_tip_x, spike_tip_y), (spike_base2_x, spike_base2_y)]
                pygame.draw.polygon(screen, p["armor_gold_dark"], spike_points)
                # 하이라이트
                mid_x = (spike_base1_x + spike_tip_x) // 2
                mid_y = (spike_base1_y + spike_tip_y) // 2
                pygame.draw.line(screen, p["armor_gold_light"], (spike_base1_x, spike_base1_y), (spike_tip_x, spike_tip_y), 1)

        # === 팔 (근육질, 팔찌 장식) - 발토르 스타일 어깨 들썩임 ===
        for side in [-1, 1]:
            current_swing = left_arm_swing if side == -1 else right_arm_swing
            current_shoulder_bob = left_shoulder if side == -1 else right_shoulder
            arm_swing = int(current_swing * 2.5 * b)
            # 어깨 들썩임
            shoulder_y_offset = int(current_shoulder_bob * 0.35 * b + shoulder_bob * 0.25 * b)
            shoulder = (cx + side * int(1.5 * b) + lean_offset, torso_y + int(0.25 * b) + shoulder_y_offset)
            elbow = (shoulder[0] + side * int(0.65 * b) + arm_swing, torso_y + int(1.1 * b) + shoulder_y_offset)
            wrist = (elbow[0] + side * int(0.45 * b) + int(arm_swing * 0.5), torso_y + int(1.75 * b) + int(shoulder_y_offset * 0.5))

            # 상완 (근육)
            pygame.draw.line(screen, p["skin_shadow"], (shoulder[0] + 1, shoulder[1] + 1), (elbow[0] + 1, elbow[1] + 1), max(4, int(0.8 * b)))
            pygame.draw.line(screen, p["skin"], shoulder, elbow, max(4, int(0.75 * b)))
            pygame.draw.line(screen, p["skin_light"], (shoulder[0] - 1, shoulder[1] - 1), (elbow[0] - 1, elbow[1] - 1), max(2, int(0.4 * b)))

            # 이두근 돌출
            bicep_cx = (shoulder[0] + elbow[0]) // 2
            bicep_cy = (shoulder[1] + elbow[1]) // 2 - int(0.1 * b)
            pygame.draw.ellipse(screen, p["skin_light"],
                              (bicep_cx - int(0.25 * b), bicep_cy - int(0.15 * b), int(0.5 * b), int(0.3 * b)))

            # 하완
            pygame.draw.line(screen, p["skin_shadow"], (elbow[0] + 1, elbow[1] + 1), (wrist[0] + 1, wrist[1] + 1), max(3, int(0.7 * b)))
            pygame.draw.line(screen, p["skin"], elbow, wrist, max(3, int(0.65 * b)))
            pygame.draw.line(screen, p["skin_mid"], elbow, wrist, max(2, int(0.4 * b)))

            # 팔찌 (금속)
            bracelet_y = elbow[1] + int(0.2 * b)
            bracelet_x = elbow[0] + side * int(0.1 * b)
            pygame.draw.ellipse(screen, p["armor_gold_dark"],
                              (bracelet_x - int(0.35 * b), bracelet_y - int(0.12 * b), int(0.7 * b), int(0.24 * b)))
            pygame.draw.ellipse(screen, p["armor_gold"],
                              (bracelet_x - int(0.3 * b), bracelet_y - int(0.1 * b), int(0.6 * b), int(0.2 * b)))

            # 손 (주먹)
            pygame.draw.circle(screen, p["skin_shadow"], (wrist[0] + 1, wrist[1] + 1), max(3, int(0.42 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(3, int(0.4 * b)))
            pygame.draw.circle(screen, p["skin_light"], (wrist[0] - 1, wrist[1] - 1), max(2, int(0.22 * b)))

        # === 머리 (오니 마스크) ===
        head_y = torso_y - int(3.2 * b)
        head_w, head_h = int(2.6 * b), int(2.4 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        # 머리카락 (거친 검은 머리)
        hair_rect = head_rect.inflate(int(0.4 * b), int(0.3 * b))
        pygame.draw.ellipse(screen, p["hair"], hair_rect)
        # 머리카락 하이라이트
        pygame.draw.ellipse(screen, p["hair_highlight"], hair_rect.inflate(-int(0.5 * b), -int(0.4 * b)))
        # 머리카락 결
        for i in range(7):
            strand_x = hair_rect.left + int((i + 0.5) * hair_rect.width / 7)
            pygame.draw.line(screen, p["hair"], (strand_x, hair_rect.top + int(0.2 * b)),
                           (strand_x + int((i - 3) * 0.1 * b), hair_rect.bottom - int(0.3 * b)), 2)

        # 뿔 (좌우 양쪽, 더 상세함)
        for side in [-1, 1]:
            horn_base_x = head_rect.centerx + side * int(0.55 * b)
            horn_base_y = head_rect.top + int(0.25 * b)
            horn_tip_x = horn_base_x + side * int(0.75 * b)
            horn_tip_y = horn_base_y - int(1.0 * b)

            # 뿔 그림자
            shadow_points = [
                (horn_base_x - side * int(0.2 * b) + 2, horn_base_y + 2),
                (horn_base_x + side * int(0.2 * b) + 2, horn_base_y + 2),
                (horn_tip_x + 2, horn_tip_y + 2),
            ]
            pygame.draw.polygon(screen, (30, 25, 20), shadow_points)

            # 뿔 본체
            horn_points = [
                (horn_base_x - side * int(0.18 * b), horn_base_y),
                (horn_base_x + side * int(0.18 * b), horn_base_y),
                (horn_tip_x, horn_tip_y),
            ]
            pygame.draw.polygon(screen, p["horn"], horn_points)

            # 뿔 하이라이트 (그라데이션 느낌)
            inner_points = [
                (horn_base_x - side * int(0.1 * b), horn_base_y - int(0.1 * b)),
                (horn_base_x + side * int(0.05 * b), horn_base_y - int(0.1 * b)),
                (horn_tip_x - side * int(0.05 * b), horn_tip_y + int(0.2 * b)),
            ]
            pygame.draw.polygon(screen, p["horn_mid"], inner_points)
            # 뿔 끝 (어두운 색)
            pygame.draw.circle(screen, p["horn_tip"], (horn_tip_x, horn_tip_y), max(1, int(0.08 * b)))

            # 뿔 고리 무늬 (3개)
            for i in range(3):
                ring_ratio = (i + 1) / 4
                ring_x = horn_base_x + side * int(ring_ratio * 0.6 * b)
                ring_y = horn_base_y - int(ring_ratio * 0.8 * b)
                ring_w = int(0.25 * b * (1 - ring_ratio * 0.5))
                pygame.draw.line(screen, p["horn_light"],
                               (ring_x - ring_w // 2, ring_y),
                               (ring_x + ring_w // 2, ring_y), 2)

        if show_back:
            # 뒷모습 - 머리카락 상세
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            # 머리카락 줄기 (더 많이)
            for i in range(9):
                hx = head_rect.centerx + (i - 4) * int(0.25 * b)
                wave_off = math.sin(self.time * 2 + i) * 0.05 * b
                pygame.draw.line(screen, p["hair_highlight"],
                               (hx, head_rect.top + int(0.15 * b)),
                               (hx + (i - 4) * int(0.12 * b) + int(wave_off), head_rect.bottom - int(0.05 * b)), 2)
        else:
            # 정면 - 오니 얼굴
            face_rect = head_rect.inflate(-int(0.35 * b), -int(0.25 * b))
            face_rect.move_ip(0, int(0.18 * b))

            # 얼굴 그림자
            pygame.draw.ellipse(screen, p["skin_shadow"], face_rect.inflate(2, 2))
            pygame.draw.ellipse(screen, p["skin"], face_rect)
            pygame.draw.ellipse(screen, p["skin_mid"], face_rect.inflate(-int(0.3 * b), -int(0.25 * b)))

            # 이마 주름 (분노 표현)
            for i in range(3):
                wrinkle_y = face_rect.top + int(0.15 * b) + i * int(0.08 * b)
                pygame.draw.line(screen, p["skin_dark"],
                               (face_rect.centerx - int(0.3 * b), wrinkle_y),
                               (face_rect.centerx + int(0.3 * b), wrinkle_y - int(0.05 * b)), 1)

            # 눈 (노란 빛, 사나운 표정, 발광)
            eye_y = face_rect.centery - int(0.12 * b)
            for side in [-1, 1]:
                eye_x = face_rect.centerx + side * int(0.38 * b)
                eye_r = max(3, int(0.22 * b))

                # 눈 글로우 (다층)
                for glow_layer in range(3):
                    glow_r = int((1.5 - glow_layer * 0.4) * eye_r)
                    glow_alpha = int((40 - glow_layer * 12) * (0.7 + rage_pulse * 0.3))
                    glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surf, (*p["eye_glow"], glow_alpha), (glow_r, glow_r), glow_r)
                    screen.blit(glow_surf, (eye_x - glow_r, eye_y - glow_r), special_flags=pygame.BLEND_ADD)

                # 눈 외곽
                pygame.draw.circle(screen, p["skin_shadow"], (eye_x, eye_y), eye_r + 2)
                # 눈 본체
                pygame.draw.circle(screen, p["eye"], (eye_x, eye_y), eye_r)
                pygame.draw.circle(screen, p["eye_inner"], (eye_x, eye_y), int(eye_r * 0.7))
                # 동공
                pygame.draw.circle(screen, p["pupil"], (eye_x, eye_y), max(1, int(eye_r * 0.35)))
                # 하이라이트
                pygame.draw.circle(screen, (255, 255, 255), (eye_x - 2, eye_y - 2), max(1, int(eye_r * 0.25)))

                # 눈썹 (사나운, 두꺼움)
                brow_start = (eye_x - side * int(0.25 * b), eye_y - int(0.28 * b))
                brow_mid = (eye_x, eye_y - int(0.18 * b))
                brow_end = (eye_x + side * int(0.18 * b), eye_y - int(0.12 * b))
                pygame.draw.line(screen, p["hair"], brow_start, brow_mid, 3)
                pygame.draw.line(screen, p["hair"], brow_mid, brow_end, 2)

            # 코 (넓고 크게)
            nose_cx = face_rect.centerx
            nose_cy = face_rect.centery + int(0.15 * b)
            pygame.draw.ellipse(screen, p["skin_dark"],
                              (nose_cx - int(0.15 * b), nose_cy - int(0.1 * b), int(0.3 * b), int(0.2 * b)))
            # 콧구멍
            for side in [-1, 1]:
                pygame.draw.circle(screen, p["skin_shadow"],
                                 (nose_cx + side * int(0.08 * b), nose_cy + int(0.05 * b)), max(1, int(0.05 * b)))

            # 입 (크게 벌린 입, 이빨)
            mouth_y = face_rect.bottom - int(0.4 * b)
            mouth_w = int(0.7 * b)
            mouth_h = int(0.35 * b)
            # 입 내부 (어두운)
            pygame.draw.ellipse(screen, (40, 20, 30),
                              (face_rect.centerx - mouth_w // 2, mouth_y - mouth_h // 4, mouth_w, mouth_h))

            # 위 이빨 (작은 것들)
            for i in range(5):
                tooth_x = face_rect.centerx + (i - 2) * int(0.12 * b)
                tooth_size = max(1, int(0.06 * b))
                pygame.draw.rect(screen, p["fangs_shadow"],
                               (tooth_x - tooth_size, mouth_y - int(0.05 * b), tooth_size * 2, int(0.12 * b)))
                pygame.draw.rect(screen, p["fangs"],
                               (tooth_x - tooth_size + 1, mouth_y - int(0.05 * b), tooth_size * 2 - 2, int(0.1 * b)))

            # 송곳니 (큰 것, 양쪽)
            for side in [-1, 1]:
                fang_x = face_rect.centerx + side * int(0.28 * b)
                fang_w = int(0.1 * b)
                fang_h = int(0.28 * b)
                fang_points = [
                    (fang_x - fang_w // 2, mouth_y - int(0.08 * b)),
                    (fang_x + fang_w // 2, mouth_y - int(0.08 * b)),
                    (fang_x, mouth_y + fang_h),
                ]
                pygame.draw.polygon(screen, p["fangs_shadow"], fang_points)
                inner_fang = [
                    (fang_x - fang_w // 3, mouth_y - int(0.06 * b)),
                    (fang_x + fang_w // 4, mouth_y - int(0.06 * b)),
                    (fang_x, mouth_y + fang_h - 2),
                ]
                pygame.draw.polygon(screen, p["fangs"], inner_fang)

        # === 금봉 (쇠몽둥이, 고퀄리티) ===
        club_x = cx + int(2.7 * b) + lean_offset
        club_top = head_y + int(0.6 * b)
        club_bottom = cy + int(2.8 * b)

        # 몽둥이 자루 그림자
        pygame.draw.line(screen, p["club_dark"], (club_x + 2, club_top + 2), (club_x + 2, club_bottom + 2), max(3, int(0.35 * b)))
        # 몽둥이 자루
        pygame.draw.line(screen, p["club"], (club_x, club_top), (club_x, club_bottom), max(3, int(0.32 * b)))
        pygame.draw.line(screen, p["club_light"], (club_x - 2, club_top), (club_x - 2, club_bottom), max(1, int(0.15 * b)))

        # 자루 장식 링
        for ring_y in [club_top + int(0.3 * b), (club_top + club_bottom) // 2, club_bottom - int(0.3 * b)]:
            pygame.draw.circle(screen, p["armor_gold_dark"], (club_x, ring_y), max(2, int(0.2 * b)))
            pygame.draw.circle(screen, p["armor_gold"], (club_x, ring_y), max(1, int(0.15 * b)))

        # 몽둥이 머리 (타원형 + 스파이크)
        club_head_y = club_top - int(0.65 * b)
        club_head_w = int(1.0 * b)
        club_head_h = int(1.1 * b)

        # 머리 그림자
        pygame.draw.ellipse(screen, p["club_dark"],
                          (club_x - club_head_w // 2 + 2, club_head_y + 2, club_head_w, club_head_h))
        # 머리 본체
        pygame.draw.ellipse(screen, p["club"], (club_x - club_head_w // 2, club_head_y, club_head_w, club_head_h))
        # 하이라이트
        inner_rect = (club_x - int(club_head_w * 0.35), club_head_y + int(0.15 * b), int(club_head_w * 0.7), int(club_head_h * 0.7))
        pygame.draw.ellipse(screen, p["club_light"], inner_rect)

        # 금속 장식
        pygame.draw.ellipse(screen, p["club_metal"],
                          (club_x - int(club_head_w * 0.3), club_head_y + int(0.2 * b), int(club_head_w * 0.6), int(club_head_h * 0.6)))
        pygame.draw.ellipse(screen, p["club_metal_light"],
                          (club_x - int(club_head_w * 0.2), club_head_y + int(0.25 * b), int(club_head_w * 0.35), int(club_head_h * 0.4)))

        # 스파이크 (6개, 더 크고 날카로움)
        club_head_cx = club_x
        club_head_cy = club_head_y + club_head_h // 2
        for i in range(6):
            angle = i * math.pi / 3 + math.pi / 6
            spike_base_r = club_head_w // 2 - 2
            spike_len = int(0.4 * b)

            spike_base_x = club_head_cx + int(math.cos(angle) * spike_base_r)
            spike_base_y = club_head_cy + int(math.sin(angle) * spike_base_r * 0.9)
            spike_tip_x = club_head_cx + int(math.cos(angle) * (spike_base_r + spike_len))
            spike_tip_y = club_head_cy + int(math.sin(angle) * (spike_base_r + spike_len) * 0.9)

            # 스파이크 (원뿔형)
            pygame.draw.circle(screen, p["club_metal_light"], (spike_tip_x, spike_tip_y), max(2, int(0.12 * b)))
            pygame.draw.line(screen, p["club_metal"], (spike_base_x, spike_base_y), (spike_tip_x, spike_tip_y), max(2, int(0.15 * b)))
            pygame.draw.circle(screen, p["club_metal"], (spike_base_x, spike_base_y), max(2, int(0.1 * b)))

    # =========================================================================
    # 마리아 - 인형사 (마리오네트를 조종하는 소녀) [고퀄리티 업그레이드]
    # =========================================================================
    def _draw_maria(self, screen, cx, cy, b, color, show_back, anim):
        """마리아 - 인형사 (기묘한 인형들을 조종하는 소녀) [고퀄리티]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        shoulder_bob = anim.get("shoulder_bob", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        # 기묘한 분위기 펄스
        eerie_pulse = (math.sin(self.time * 1.5) + 1) * 0.5
        string_sway = math.sin(self.time * 2.5) * 0.15

        p = {
            "dress": color,
            "dress_light": tuple(min(255, c + 50) for c in color),
            "dress_mid": tuple(min(255, c + 25) for c in color),
            "dress_dark": tuple(max(0, c - 40) for c in color),
            "dress_shadow": tuple(max(0, c - 70) for c in color),
            "lace": (250, 245, 240),
            "lace_shadow": (220, 210, 205),
            "skin": (250, 238, 228),
            "skin_shadow": (230, 215, 205),
            "skin_blush": (255, 210, 210),
            "hair": (35, 25, 45),
            "hair_mid": (55, 40, 70),
            "hair_light": (75, 55, 95),
            "hair_highlight": (100, 75, 125),
            "eye": (180, 100, 160),
            "eye_light": (210, 140, 190),
            "eye_dark": (130, 60, 110),
            "eye_white": (255, 252, 255),
            "ribbon": (200, 75, 115),
            "ribbon_light": (230, 110, 145),
            "ribbon_dark": (160, 50, 85),
            "string": (200, 195, 190),
            "string_shadow": (150, 145, 140),
            "puppet_body": (190, 170, 150),
            "puppet_light": (220, 200, 180),
            "puppet_dark": (140, 120, 100),
            "puppet_shadow": (100, 85, 70),
            "puppet_joint": (160, 140, 120),
            "puppet_eye": (30, 25, 35),
            "aura": (180, 120, 200),
        }

        # === 기묘한 오라 효과 ===
        aura_size = int(4.5 * b)
        aura_surf = pygame.Surface((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
        for i in range(3):
            aura_alpha = int((18 - i * 5) * eerie_pulse)
            aura_r = int((1.8 - i * 0.4) * b)
            pygame.draw.circle(aura_surf, (*p["aura"], aura_alpha), (aura_size, aura_size), aura_r)
        screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - int(0.8 * b) - aura_size // 2), special_flags=pygame.BLEND_ADD)

        # === 드레스 하단 (고딕 빅토리안 프릴) ===
        dress_points = [
            (cx - int(1.3 * b) + lean_offset, torso_y + int(1.65 * b)),
            (cx + int(1.3 * b) + lean_offset, torso_y + int(1.65 * b)),
            (cx + int(2.0 * b) + lean_offset + int(wave * 0.18 * b), cy + int(3.0 * b)),
            (cx - int(2.0 * b) + lean_offset - int(wave * 0.18 * b), cy + int(3.0 * b)),
        ]
        # 드레스 그림자
        shadow_points = [(p[0] + 2, p[1] + 2) for p in dress_points]
        pygame.draw.polygon(screen, p["dress_shadow"], shadow_points)
        pygame.draw.polygon(screen, p["dress"], dress_points)

        # 드레스 세로 주름
        for i in range(7):
            fold_x = cx + (i - 3) * int(0.4 * b) + lean_offset
            fold_top = torso_y + int(1.7 * b)
            fold_bot = cy + int(2.8 * b) + int(wave * 0.05 * (i - 3) * b)
            pygame.draw.line(screen, p["dress_mid"], (fold_x, fold_top), (fold_x, fold_bot), 1)

        # 프릴 레이어 (5단계)
        for layer in range(5):
            frill_y = torso_y + int(1.85 * b) + layer * int(0.32 * b)
            frill_w = int(1.35 * b) + layer * int(0.15 * b)
            wave_offset = int(wave * 0.03 * layer * b)

            # 프릴 물결 패턴
            frill_points = []
            segments = 12
            for seg in range(segments + 1):
                fx = cx - frill_w + int(seg * frill_w * 2 / segments) + lean_offset
                fy = frill_y + int(math.sin(seg * 0.8 + self.time * 3) * 0.08 * b)
                frill_points.append((fx, fy))

            for seg in range(len(frill_points) - 1):
                pygame.draw.line(screen, p["lace"], frill_points[seg], frill_points[seg + 1], 1)

            # 레이스 장식
            if layer % 2 == 0:
                pygame.draw.arc(screen, p["dress_light"],
                              (cx - frill_w + lean_offset + wave_offset, frill_y - int(0.05 * b), frill_w * 2, int(0.35 * b)),
                              math.radians(180), math.radians(360), 2)

        # 발끝 (발레 슈즈)
        for side in [-1, 1]:
            foot_x = cx + side * int(0.55 * b) + lean_offset
            foot_y = cy + int(2.6 * b)
            # 슈즈 그림자
            pygame.draw.ellipse(screen, (40, 35, 50),
                              (foot_x - int(0.28 * b) + 1, foot_y + 1, int(0.56 * b), int(0.32 * b)))
            # 슈즈
            pygame.draw.ellipse(screen, (55, 45, 65),
                              (foot_x - int(0.26 * b), foot_y - int(0.02 * b), int(0.52 * b), int(0.3 * b)))
            # 리본 장식
            pygame.draw.ellipse(screen, p["ribbon"],
                              (foot_x - int(0.1 * b), foot_y - int(0.08 * b), int(0.2 * b), int(0.12 * b)))

        # === 몸통 (빅토리안 코르셋 드레스) ===
        chest_w, chest_h = int(2.6 * b), int(2.0 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.25 * b), chest_w, chest_h)

        # 드레스 그림자
        pygame.draw.rect(screen, p["dress_shadow"], chest_rect.inflate(2, 2), border_radius=int(0.45 * b))
        pygame.draw.rect(screen, p["dress"], chest_rect, border_radius=int(0.42 * b))
        pygame.draw.rect(screen, p["dress_mid"], chest_rect.inflate(-int(0.35 * b), -int(0.28 * b)), border_radius=int(0.35 * b))
        pygame.draw.rect(screen, p["dress_light"], chest_rect.inflate(-int(0.7 * b), -int(0.55 * b)), border_radius=int(0.25 * b))

        # 코르셋 라인 (X자 레이싱)
        corset_cx = chest_rect.centerx
        for i in range(5):
            lace_y = chest_rect.top + int(0.3 * b) + i * int(0.3 * b)
            # X자 크로스
            pygame.draw.line(screen, p["lace_shadow"],
                           (corset_cx - int(0.25 * b), lace_y), (corset_cx + int(0.25 * b), lace_y + int(0.2 * b)), 1)
            pygame.draw.line(screen, p["lace_shadow"],
                           (corset_cx + int(0.25 * b), lace_y), (corset_cx - int(0.25 * b), lace_y + int(0.2 * b)), 1)
            # 중앙 고리
            pygame.draw.circle(screen, p["lace"], (corset_cx, lace_y + int(0.1 * b)), max(1, int(0.04 * b)))

        # 레이스 칼라
        collar_y = chest_rect.top + int(0.05 * b)
        for i in range(7):
            collar_x = chest_rect.left + int(0.3 * b) + i * int(0.3 * b)
            pygame.draw.ellipse(screen, p["lace"],
                              (collar_x, collar_y - int(0.1 * b), int(0.25 * b), int(0.2 * b)))
            pygame.draw.ellipse(screen, p["lace_shadow"],
                              (collar_x + 1, collar_y - int(0.08 * b), int(0.2 * b), int(0.15 * b)), 1)

        # 목 리본 (대형)
        bow_cx, bow_cy = chest_rect.centerx, chest_rect.top + int(0.25 * b)
        # 리본 꼬리
        for side in [-1, 1]:
            tail_points = [
                (bow_cx + side * int(0.15 * b), bow_cy + int(0.05 * b)),
                (bow_cx + side * int(0.45 * b), bow_cy + int(0.5 * b)),
                (bow_cx + side * int(0.35 * b), bow_cy + int(0.55 * b)),
            ]
            pygame.draw.polygon(screen, p["ribbon_dark"], tail_points)
        # 리본 날개
        pygame.draw.ellipse(screen, p["ribbon_dark"],
                          (bow_cx - int(0.5 * b), bow_cy - int(0.18 * b), int(0.42 * b), int(0.36 * b)))
        pygame.draw.ellipse(screen, p["ribbon"],
                          (bow_cx - int(0.48 * b), bow_cy - int(0.16 * b), int(0.38 * b), int(0.32 * b)))
        pygame.draw.ellipse(screen, p["ribbon_dark"],
                          (bow_cx + int(0.08 * b), bow_cy - int(0.18 * b), int(0.42 * b), int(0.36 * b)))
        pygame.draw.ellipse(screen, p["ribbon"],
                          (bow_cx + int(0.1 * b), bow_cy - int(0.16 * b), int(0.38 * b), int(0.32 * b)))
        # 리본 중심
        pygame.draw.circle(screen, p["ribbon_dark"], (bow_cx, bow_cy), max(2, int(0.14 * b)))
        pygame.draw.circle(screen, p["ribbon"], (bow_cx, bow_cy), max(2, int(0.11 * b)))
        pygame.draw.circle(screen, p["ribbon_light"], (bow_cx - 1, bow_cy - 1), max(1, int(0.05 * b)))

        # 허리띠 (금속 버클)
        belt_rect = pygame.Rect(cx - int(1.2 * b) + lean_offset, chest_rect.bottom - 4, int(2.4 * b), int(0.55 * b))
        pygame.draw.rect(screen, p["dress_shadow"], belt_rect, border_radius=3)
        pygame.draw.rect(screen, p["dress_dark"], belt_rect.inflate(-2, -2), border_radius=2)
        # 버클
        buckle_size = max(3, int(0.2 * b))
        pygame.draw.rect(screen, (180, 165, 140), (belt_rect.centerx - buckle_size, belt_rect.centery - buckle_size // 2, buckle_size * 2, buckle_size), border_radius=1)
        pygame.draw.rect(screen, (220, 205, 180), (belt_rect.centerx - buckle_size + 2, belt_rect.centery - buckle_size // 2 + 1, buckle_size * 2 - 4, buckle_size - 2), border_radius=1)

        # === 어깨 퍼프 (레이스 장식) ===
        for side in [-1, 1]:
            puff_x = cx + side * int(0.95 * b) + lean_offset
            puff_y = torso_y - int(0.15 * b)
            puff_w, puff_h = int(0.9 * b), int(0.8 * b)

            # 퍼프 본체
            puff_rect = pygame.Rect(puff_x - puff_w // 2, puff_y, puff_w, puff_h)
            pygame.draw.ellipse(screen, p["dress_dark"], puff_rect.inflate(2, 2))
            pygame.draw.ellipse(screen, p["dress_light"], puff_rect)
            pygame.draw.ellipse(screen, p["dress_mid"], puff_rect.inflate(-int(0.2 * b), -int(0.15 * b)))

            # 레이스 테두리
            for i in range(5):
                angle = math.pi + side * i * 0.3
                lx = puff_x + int(math.cos(angle) * puff_w * 0.5)
                ly = puff_y + puff_h // 2 + int(math.sin(angle) * puff_h * 0.4)
                pygame.draw.circle(screen, p["lace"], (lx, ly), max(1, int(0.08 * b)))

        # === 팔 + 마리오네트 실 (어깨 들썩임) ===
        for side in [-1, 1]:
            shoulder_bob_offset = int(shoulder_bob * 0.3 * b)
            shoulder = (cx + side * int(1.05 * b) + lean_offset, torso_y + int(0.15 * b) + shoulder_bob_offset)
            elbow = (shoulder[0] + side * int(0.45 * b), torso_y + int(0.75 * b))
            # 손 위치 (인형 조종 포즈)
            hand_wave_x = math.sin(self.time * 2 + side) * 0.22 * b
            hand_wave_y = math.cos(self.time * 2 + side) * 0.12 * b
            wrist = (elbow[0] + side * int(0.35 * b) + int(hand_wave_x),
                    torso_y + int(1.25 * b) + int(hand_wave_y))

            # 드레스 소매
            pygame.draw.line(screen, p["dress_dark"], (shoulder[0] + 1, shoulder[1] + 1), (elbow[0] + 1, elbow[1] + 1), max(3, int(0.48 * b)))
            pygame.draw.line(screen, p["dress"], shoulder, elbow, max(3, int(0.45 * b)))
            pygame.draw.line(screen, p["dress_light"], shoulder, elbow, max(2, int(0.28 * b)))

            # 레이스 커프스
            cuff_y = elbow[1] - int(0.1 * b)
            pygame.draw.ellipse(screen, p["lace"],
                              (elbow[0] - int(0.28 * b), cuff_y, int(0.56 * b), int(0.25 * b)))
            for i in range(4):
                lace_x = elbow[0] - int(0.2 * b) + i * int(0.13 * b)
                pygame.draw.line(screen, p["lace_shadow"], (lace_x, cuff_y), (lace_x, cuff_y + int(0.12 * b)), 1)

            # 팔
            pygame.draw.line(screen, p["skin_shadow"], (elbow[0] + 1, elbow[1] + 1), (wrist[0] + 1, wrist[1] + 1), max(2, int(0.38 * b)))
            pygame.draw.line(screen, p["skin"], elbow, wrist, max(2, int(0.35 * b)))

            # 손 (섬세한 손가락)
            pygame.draw.circle(screen, p["skin_shadow"], (wrist[0] + 1, wrist[1] + 1), max(2, int(0.28 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.26 * b)))
            # 손가락 (5개)
            for finger in range(5):
                finger_angle = -0.4 + finger * 0.2 + side * 0.3
                finger_len = int(0.18 * b) if finger == 2 else int(0.14 * b)
                fx = wrist[0] + int(math.cos(finger_angle + self.time * 0.5) * finger_len)
                fy = wrist[1] + int(math.sin(finger_angle) * finger_len) + int(0.1 * b)
                pygame.draw.line(screen, p["skin"], wrist, (fx, fy), max(1, int(0.06 * b)))

            # === 마리오네트 실 (손가락에서 인형으로) ===
            puppet_base_y = torso_y + int(2.15 * b)
            puppet_base_x = wrist[0] + side * int(0.6 * b)

            # 실 (5개, 각 손가락에서)
            for j in range(5):
                string_start_x = wrist[0] + (j - 2) * int(0.06 * b)
                string_start_y = wrist[1] + int(0.12 * b)
                target_x = puppet_base_x + (j - 2) * int(0.12 * b)
                target_y = puppet_base_y - int(0.35 * b) + int(math.sin(self.time * 3 + j) * 0.05 * b)

                # 실 흔들림 (곡선)
                mid_x = (string_start_x + target_x) // 2 + int(string_sway * b * (j - 2))
                mid_y = (string_start_y + target_y) // 2

                pygame.draw.line(screen, p["string_shadow"], (string_start_x, string_start_y), (mid_x, mid_y), 1)
                pygame.draw.line(screen, p["string"], (mid_x, mid_y), (target_x, target_y), 1)

        # === 마리오네트 인형 (양쪽 아래, 더 상세) ===
        for side in [-1, 1]:
            puppet_x = cx + side * int(1.95 * b) + lean_offset
            puppet_bob = math.sin(self.time * 3 + side * 2) * 0.25 * b
            puppet_y = torso_y + int(2.1 * b) + int(puppet_bob)
            puppet_tilt = math.sin(self.time * 2.5 + side) * 0.15

            # 인형 그림자
            shadow_surf = pygame.Surface((int(0.8 * b), int(0.4 * b)), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40), (0, 0, int(0.8 * b), int(0.4 * b)))
            screen.blit(shadow_surf, (puppet_x - int(0.4 * b), puppet_y + int(0.7 * b)))

            # 인형 다리 (관절)
            for leg_side in [-1, 1]:
                leg_x = puppet_x + leg_side * int(0.1 * b)
                leg_phase = math.sin(self.time * 4 + leg_side + side) * 0.1 * b
                # 허벅지
                pygame.draw.line(screen, p["puppet_dark"], (leg_x, puppet_y + int(0.35 * b)),
                               (leg_x + int(leg_phase), puppet_y + int(0.55 * b)), max(2, int(0.1 * b)))
                # 정강이
                pygame.draw.line(screen, p["puppet_body"], (leg_x + int(leg_phase), puppet_y + int(0.55 * b)),
                               (leg_x, puppet_y + int(0.75 * b)), max(2, int(0.08 * b)))
                # 관절
                pygame.draw.circle(screen, p["puppet_joint"], (int(leg_x + leg_phase), int(puppet_y + int(0.55 * b))), max(1, int(0.05 * b)))

            # 인형 몸체
            body_rect = (puppet_x - int(0.22 * b), puppet_y + int(0.05 * b), int(0.44 * b), int(0.35 * b))
            pygame.draw.ellipse(screen, p["puppet_shadow"], (body_rect[0] + 1, body_rect[1] + 1, body_rect[2], body_rect[3]))
            pygame.draw.ellipse(screen, p["puppet_body"], body_rect)
            pygame.draw.ellipse(screen, p["puppet_light"], (body_rect[0] + 3, body_rect[1] + 2, body_rect[2] - 6, body_rect[3] - 4))

            # 인형 팔 (관절)
            for arm_side in [-1, 1]:
                arm_x = puppet_x + arm_side * int(0.2 * b)
                arm_wave = math.sin(self.time * 5 + arm_side * side) * 0.08 * b
                pygame.draw.line(screen, p["puppet_dark"], (arm_x, puppet_y + int(0.1 * b)),
                               (arm_x + arm_side * int(0.15 * b) + int(arm_wave), puppet_y + int(0.3 * b)), max(1, int(0.06 * b)))
                # 손
                pygame.draw.circle(screen, p["puppet_body"],
                                 (int(arm_x + arm_side * int(0.15 * b) + arm_wave), int(puppet_y + int(0.32 * b))), max(1, int(0.04 * b)))

            # 인형 머리 (구체관절)
            head_x = puppet_x + int(puppet_tilt * 0.2 * b)
            head_y = puppet_y - int(0.12 * b)
            head_r = max(3, int(0.22 * b))

            pygame.draw.circle(screen, p["puppet_shadow"], (head_x + 1, head_y + 1), head_r)
            pygame.draw.circle(screen, p["puppet_body"], (head_x, head_y), head_r)
            pygame.draw.circle(screen, p["puppet_light"], (head_x - 2, head_y - 2), int(head_r * 0.5))

            # 인형 얼굴 (기묘한 X눈)
            for eye_side in [-1, 1]:
                eye_x = head_x + eye_side * int(0.08 * b)
                eye_y = head_y - int(0.02 * b)
                eye_size = max(2, int(0.05 * b))
                # X자 눈
                pygame.draw.line(screen, p["puppet_eye"], (eye_x - eye_size, eye_y - eye_size), (eye_x + eye_size, eye_y + eye_size), 1)
                pygame.draw.line(screen, p["puppet_eye"], (eye_x - eye_size, eye_y + eye_size), (eye_x + eye_size, eye_y - eye_size), 1)

            # 입 (작은 미소)
            pygame.draw.arc(screen, p["puppet_eye"],
                          (head_x - int(0.08 * b), head_y + int(0.02 * b), int(0.16 * b), int(0.1 * b)),
                          math.radians(200), math.radians(340), 1)

            # 관절 이음새 (목)
            pygame.draw.circle(screen, p["puppet_joint"], (int(head_x), int(puppet_y + int(0.02 * b))), max(1, int(0.04 * b)))

        # === 머리 (긴 물결 머리 + 리본) ===
        head_y = torso_y - int(2.8 * b)
        head_w, head_h = int(2.2 * b), int(2.0 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        # 긴 머리카락 (양쪽으로 늘어짐, 물결)
        for side in [-1, 1]:
            hair_x = head_rect.centerx + side * int(0.75 * b)
            hair_wave = math.sin(self.time * 2 + side) * 0.08 * b

            # 머리카락 여러 가닥
            for strand in range(3):
                strand_offset = (strand - 1) * int(0.15 * b)
                hair_points = [
                    (hair_x + strand_offset - int(0.25 * b), head_rect.centery - int(0.1 * b)),
                    (hair_x + strand_offset + int(0.25 * b), head_rect.centery),
                    (hair_x + strand_offset + side * int(0.12 * b) + int(hair_wave), torso_y + int(1.2 * b) + strand * int(0.15 * b)),
                ]
                hair_color = p["hair"] if strand == 1 else p["hair_mid"]
                pygame.draw.polygon(screen, hair_color, hair_points)

        if show_back:
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            # 머리카락 결
            for i in range(7):
                hx = head_rect.left + int(0.25 * b) + i * int(0.25 * b)
                wave_off = math.sin(self.time * 1.5 + i * 0.5) * 0.03 * b
                pygame.draw.line(screen, p["hair_highlight"],
                               (hx, head_rect.top + int(0.15 * b)),
                               (hx + int(wave_off), head_rect.bottom - int(0.1 * b)), 2)
            # 리본 (뒤에서 보이는 꼬리)
            ribbon_tail_y = head_rect.top + int(0.4 * b)
            for side in [-1, 1]:
                tail_wave = math.sin(self.time * 3 + side) * 0.1 * b
                tail_points = [
                    (head_rect.centerx + side * int(0.1 * b), ribbon_tail_y),
                    (head_rect.centerx + side * int(0.4 * b) + int(tail_wave), ribbon_tail_y + int(0.8 * b)),
                    (head_rect.centerx + side * int(0.3 * b) + int(tail_wave), ribbon_tail_y + int(0.85 * b)),
                ]
                pygame.draw.polygon(screen, p["ribbon"], tail_points)
            pygame.draw.circle(screen, p["ribbon"], (head_rect.centerx, ribbon_tail_y - int(0.05 * b)), max(2, int(0.15 * b)))
        else:
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            pygame.draw.ellipse(screen, p["hair_mid"], head_rect.inflate(-int(0.3 * b), -int(0.25 * b)))

            # 얼굴
            face_rect = head_rect.inflate(-int(0.45 * b), -int(0.35 * b))
            face_rect.move_ip(0, int(0.18 * b))
            pygame.draw.ellipse(screen, p["skin_shadow"], face_rect.inflate(2, 2))
            pygame.draw.ellipse(screen, p["skin"], face_rect)

            # 볼터치
            for side in [-1, 1]:
                blush_x = face_rect.centerx + side * int(0.28 * b)
                blush_y = face_rect.centery + int(0.15 * b)
                blush_surf = pygame.Surface((int(0.25 * b), int(0.15 * b)), pygame.SRCALPHA)
                pygame.draw.ellipse(blush_surf, (*p["skin_blush"][0:3], 80), (0, 0, int(0.25 * b), int(0.15 * b)))
                screen.blit(blush_surf, (blush_x - int(0.125 * b), blush_y - int(0.075 * b)))

            # 큰 눈 (인형같은, 반짝임)
            eye_y = face_rect.centery - int(0.08 * b)
            for side in [-1, 1]:
                eye_x = face_rect.centerx + side * int(0.28 * b)
                eye_w, eye_h = int(0.35 * b), int(0.3 * b)

                # 눈 흰자
                pygame.draw.ellipse(screen, p["eye_white"],
                                   (eye_x - eye_w // 2, eye_y - eye_h // 2, eye_w, eye_h))
                # 홍채
                iris_r = max(2, int(0.12 * b))
                pygame.draw.circle(screen, p["eye_dark"], (eye_x, eye_y), iris_r + 1)
                pygame.draw.circle(screen, p["eye"], (eye_x, eye_y), iris_r)
                pygame.draw.circle(screen, p["eye_light"], (eye_x - 1, eye_y - 1), max(1, iris_r // 2))
                # 동공
                pygame.draw.circle(screen, (30, 20, 40), (eye_x, eye_y), max(1, int(0.04 * b)))
                # 반짝임 (2개)
                pygame.draw.circle(screen, (255, 255, 255), (eye_x - 2, eye_y - 2), max(1, int(0.04 * b)))
                pygame.draw.circle(screen, (255, 255, 255), (eye_x + 1, eye_y + 1), max(1, int(0.02 * b)))

                # 속눈썹
                for lash in range(3):
                    lash_angle = -0.5 + lash * 0.25 + side * 0.3
                    lash_len = int(0.08 * b)
                    lx = eye_x + side * int(0.05 * b) + int(math.cos(lash_angle) * eye_w * 0.4)
                    ly = eye_y - int(eye_h * 0.4)
                    pygame.draw.line(screen, p["hair"], (lx, ly), (lx + int(math.cos(lash_angle - 0.5) * lash_len), ly - lash_len), 1)

            # 코
            pygame.draw.line(screen, p["skin_shadow"],
                           (face_rect.centerx, face_rect.centery + int(0.05 * b)),
                           (face_rect.centerx, face_rect.centery + int(0.15 * b)), 1)

            # 작은 입 (살짝 미소)
            mouth_y = face_rect.bottom - int(0.28 * b)
            pygame.draw.arc(screen, (190, 140, 150),
                          (face_rect.centerx - int(0.12 * b), mouth_y - int(0.03 * b), int(0.24 * b), int(0.1 * b)),
                          math.radians(200), math.radians(340), 1)

            # 앞머리 (물결)
            for i in range(7):
                hx = face_rect.left + int(0.1 * b) + i * int(0.22 * b)
                strand_wave = math.sin(self.time * 2 + i * 0.8) * 0.02 * b
                pygame.draw.line(screen, p["hair"],
                               (hx, head_rect.top + int(0.12 * b)),
                               (hx + (i - 3) * int(0.04 * b) + int(strand_wave), face_rect.top + int(0.25 * b)), 2)
                pygame.draw.line(screen, p["hair_highlight"],
                               (hx + 1, head_rect.top + int(0.14 * b)),
                               (hx + (i - 3) * int(0.04 * b) + int(strand_wave) + 1, face_rect.top + int(0.22 * b)), 1)

            # 머리 리본 (크고 화려하게)
            ribbon_y = head_rect.top - int(0.05 * b)
            # 리본 꼬리
            for side in [-1, 1]:
                tail_wave = math.sin(self.time * 2.5 + side) * 0.08 * b
                tail_points = [
                    (head_rect.centerx + side * int(0.2 * b), ribbon_y + int(0.3 * b)),
                    (head_rect.centerx + side * int(0.55 * b) + int(tail_wave), ribbon_y + int(0.7 * b)),
                    (head_rect.centerx + side * int(0.45 * b) + int(tail_wave), ribbon_y + int(0.75 * b)),
                ]
                pygame.draw.polygon(screen, p["ribbon_dark"], tail_points)

            # 리본 날개
            pygame.draw.ellipse(screen, p["ribbon_dark"],
                              (head_rect.centerx - int(0.58 * b), ribbon_y - int(0.12 * b), int(0.5 * b), int(0.4 * b)))
            pygame.draw.ellipse(screen, p["ribbon"],
                              (head_rect.centerx - int(0.55 * b), ribbon_y - int(0.1 * b), int(0.45 * b), int(0.35 * b)))
            pygame.draw.ellipse(screen, p["ribbon_light"],
                              (head_rect.centerx - int(0.5 * b), ribbon_y - int(0.05 * b), int(0.25 * b), int(0.2 * b)))

            pygame.draw.ellipse(screen, p["ribbon_dark"],
                              (head_rect.centerx + int(0.08 * b), ribbon_y - int(0.12 * b), int(0.5 * b), int(0.4 * b)))
            pygame.draw.ellipse(screen, p["ribbon"],
                              (head_rect.centerx + int(0.1 * b), ribbon_y - int(0.1 * b), int(0.45 * b), int(0.35 * b)))
            pygame.draw.ellipse(screen, p["ribbon_light"],
                              (head_rect.centerx + int(0.25 * b), ribbon_y - int(0.05 * b), int(0.25 * b), int(0.2 * b)))

            # 리본 중심
            pygame.draw.circle(screen, p["ribbon_dark"], (head_rect.centerx, ribbon_y + int(0.1 * b)), max(2, int(0.14 * b)))
            pygame.draw.circle(screen, p["ribbon"], (head_rect.centerx, ribbon_y + int(0.1 * b)), max(2, int(0.11 * b)))
            pygame.draw.circle(screen, p["ribbon_light"], (head_rect.centerx - 1, ribbon_y + int(0.08 * b)), max(1, int(0.05 * b)))

    # =========================================================================
    # 이그니스 - 드래곤 나이트 (드래곤의 힘을 갑옷에 담은 용기사) [고퀄리티 업그레이드]
    # =========================================================================
    def _draw_ignis(self, screen, cx, cy, b, color, show_back, anim):
        """이그니스 - 드래곤 나이트 (드래곤 갑옷 + 불꽃) [고퀄리티]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        left_arm_swing = anim.get("left_arm_swing", 0)
        right_arm_swing = anim.get("right_arm_swing", 0)
        # 발토르 스타일 다리/어깨 애니메이션
        left_leg_sway = anim.get("left_leg_sway", 0)
        right_leg_sway = anim.get("right_leg_sway", 0)
        left_leg_lift = anim.get("left_leg", 0)
        right_leg_lift = anim.get("right_leg", 0)
        shoulder_bob = anim.get("shoulder_bob", 0)
        left_shoulder = anim.get("left_shoulder", 0)
        right_shoulder = anim.get("right_shoulder", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        # 불꽃 펄스
        flame_pulse = (math.sin(self.time * 4) + 1) * 0.5
        heat_wave = math.sin(self.time * 6) * 0.1

        p = {
            "armor": color,
            "armor_light": tuple(min(255, c + 50) for c in color),
            "armor_mid": tuple(min(255, c + 25) for c in color),
            "armor_dark": tuple(max(0, c - 50) for c in color),
            "armor_shadow": tuple(max(0, c - 80) for c in color),
            "scale": tuple(max(0, c - 30) for c in color),
            "scale_light": tuple(min(255, c + 15) for c in color),
            "flame": (255, 150, 50),
            "flame_core": (255, 230, 120),
            "flame_mid": (255, 180, 70),
            "flame_edge": (255, 80, 30),
            "flame_dark": (200, 50, 20),
            "eye": (255, 210, 60),
            "eye_glow": (255, 120, 40),
            "eye_core": (255, 255, 200),
            "horn": (70, 55, 45),
            "horn_mid": (100, 80, 65),
            "horn_light": (130, 105, 85),
            "horn_tip": (50, 40, 35),
            "cape": (35, 25, 45),
            "cape_mid": (55, 40, 65),
            "cape_light": (75, 55, 85),
            "cape_edge": (120, 70, 40),
            "gold": (220, 180, 80),
            "gold_light": (250, 215, 120),
            "gold_dark": (170, 130, 50),
        }

        # === 용의 오라 (불꽃 배경) ===
        aura_size = int(5 * b)
        aura_surf = pygame.Surface((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
        for i in range(4):
            aura_alpha = int((25 - i * 6) * (0.6 + flame_pulse * 0.4))
            aura_r = int((2.2 - i * 0.4) * b)
            pygame.draw.circle(aura_surf, (*p["flame_edge"], aura_alpha), (aura_size, aura_size), aura_r)
        screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - int(1.2 * b) - aura_size // 2), special_flags=pygame.BLEND_ADD)

        # 불씨 파티클
        for i in range(8):
            ember_x = cx + int(math.sin(self.time * 3 + i * 1.1) * 2 * b) + lean_offset
            ember_y = torso_y + int(1 * b) - int(((self.time * 1.5 + i * 0.3) % 1) * 3 * b)
            ember_alpha = int(200 * (1 - ((self.time * 1.5 + i * 0.3) % 1)))
            ember_size = max(1, int(0.1 * b * (1 - ((self.time * 1.5 + i * 0.3) % 1))))
            ember_surf = pygame.Surface((ember_size * 4, ember_size * 4), pygame.SRCALPHA)
            ember_color = p["flame_core"] if i % 2 == 0 else p["flame"]
            pygame.draw.circle(ember_surf, (*ember_color, ember_alpha), (ember_size * 2, ember_size * 2), ember_size)
            screen.blit(ember_surf, (int(ember_x) - ember_size * 2, int(ember_y) - ember_size * 2), special_flags=pygame.BLEND_ADD)

        # === 망토 (드래곤 날개처럼 펄럭임) ===
        cape_wave = math.sin(self.time * 3) * 0.25
        cape_wave2 = math.sin(self.time * 4.5) * 0.15

        # 망토 그림자
        cape_shadow_points = [
            (cx - int(1.1 * b) + lean_offset + 2, torso_y - int(0.45 * b) + 2),
            (cx + int(1.1 * b) + lean_offset + 2, torso_y - int(0.45 * b) + 2),
            (cx + int(1.5 * b) + lean_offset + int((cape_wave + cape_wave2) * b) + 2, cy + int(2.7 * b) + 2),
            (cx - int(1.5 * b) + lean_offset - int((cape_wave + cape_wave2) * b) + 2, cy + int(2.7 * b) + 2),
        ]
        pygame.draw.polygon(screen, (20, 15, 30), cape_shadow_points)

        # 망토 본체
        cape_points = [
            (cx - int(1.1 * b) + lean_offset, torso_y - int(0.45 * b)),
            (cx + int(1.1 * b) + lean_offset, torso_y - int(0.45 * b)),
            (cx + int(1.5 * b) + lean_offset + int((cape_wave + cape_wave2) * b), cy + int(2.7 * b)),
            (cx - int(1.5 * b) + lean_offset - int((cape_wave + cape_wave2) * b), cy + int(2.7 * b)),
        ]
        pygame.draw.polygon(screen, p["cape"], cape_points)

        # 망토 내부 하이라이트
        inner_cape = [
            (cx - int(0.9 * b) + lean_offset, torso_y - int(0.35 * b)),
            (cx + int(0.9 * b) + lean_offset, torso_y - int(0.35 * b)),
            (cx + int(1.2 * b) + lean_offset + int(cape_wave * 0.8 * b), cy + int(2.4 * b)),
            (cx - int(1.2 * b) + lean_offset - int(cape_wave * 0.8 * b), cy + int(2.4 * b)),
        ]
        pygame.draw.polygon(screen, p["cape_mid"], inner_cape)

        # 망토 주름
        for i in range(5):
            fold_x = cx + (i - 2) * int(0.4 * b) + lean_offset
            fold_wave = math.sin(self.time * 3 + i * 0.5) * 0.1 * b
            fold_start = (fold_x, torso_y - int(0.3 * b))
            fold_end = (fold_x + int(fold_wave) + int((i - 2) * cape_wave * 0.3 * b), cy + int(2.5 * b))
            pygame.draw.line(screen, p["cape_light"], fold_start, fold_end, 1)

        # 망토 불꽃 테두리
        pygame.draw.line(screen, p["cape_edge"], cape_points[2], cape_points[3], max(2, int(0.12 * b)))

        # === 다리 (드래곤 비늘 갑옷) - 발토르 스타일 스윙 ===
        hip_y = torso_y + int(2.0 * b)
        for side in [-1, 1]:
            # 발토르 스타일 다리 움직임
            current_leg_sway = left_leg_sway if side == -1 else right_leg_sway
            current_leg_lift = left_leg_lift if side == -1 else right_leg_lift
            leg_sway_x = int(current_leg_sway * 0.5 * b)
            leg_lift_y = int(current_leg_lift * 0.2 * b)
            thigh_x = cx + side * int(0.55 * b) + lean_offset + leg_sway_x

            # 허벅지 그림자
            thigh_shadow = pygame.Rect(thigh_x - int(0.48 * b) + 1, hip_y - leg_lift_y + 1, int(0.96 * b), int(1.9 * b))
            pygame.draw.rect(screen, p["armor_shadow"], thigh_shadow, border_radius=4)

            # 허벅지
            thigh_rect = pygame.Rect(thigh_x - int(0.48 * b), hip_y - leg_lift_y, int(0.96 * b), int(1.9 * b))
            pygame.draw.rect(screen, p["armor"], thigh_rect, border_radius=4)
            pygame.draw.rect(screen, p["armor_mid"], thigh_rect.inflate(-int(0.15 * b), -int(0.1 * b)), border_radius=3)

            # 비늘 패턴 (더 상세)
            for i in range(5):
                scale_y = thigh_rect.top + int(0.2 * b) + i * int(0.35 * b)
                scale_w = thigh_rect.width - 6
                pygame.draw.arc(screen, p["scale"],
                              (thigh_rect.left + 3, scale_y, scale_w, int(0.28 * b)),
                              math.radians(0), math.radians(180), 2)
                # 비늘 하이라이트
                pygame.draw.arc(screen, p["scale_light"],
                              (thigh_rect.left + 4, scale_y + 1, scale_w - 2, int(0.2 * b)),
                              math.radians(20), math.radians(160), 1)

            # 무릎 (드래곤 얼굴 장식)
            knee_y = thigh_rect.bottom - int(0.25 * b)
            knee_rect = pygame.Rect(thigh_x - int(0.45 * b), knee_y, int(0.9 * b), int(0.55 * b))
            pygame.draw.rect(screen, p["armor_dark"], knee_rect, border_radius=3)
            pygame.draw.rect(screen, p["armor"], knee_rect.inflate(-int(0.1 * b), -int(0.08 * b)), border_radius=2)
            # 드래곤 눈 장식
            knee_eye_y = knee_rect.centery
            pygame.draw.circle(screen, p["gold_dark"], (knee_rect.centerx, knee_eye_y), max(2, int(0.12 * b)))
            pygame.draw.circle(screen, p["eye"], (knee_rect.centerx, knee_eye_y), max(1, int(0.08 * b)))

            # 부츠 (드래곤 발)
            boot_rect = pygame.Rect(thigh_x - int(0.45 * b), knee_rect.bottom - 2, int(0.9 * b), int(0.9 * b))
            pygame.draw.rect(screen, p["armor_shadow"], boot_rect.inflate(2, 2), border_radius=4)
            pygame.draw.rect(screen, p["armor_dark"], boot_rect, border_radius=4)
            pygame.draw.rect(screen, p["armor"], boot_rect.inflate(-int(0.12 * b), -int(0.1 * b)), border_radius=3)

            # 발톱 (더 날카롭게)
            for i in range(3):
                claw_x = boot_rect.left + int(0.2 * b) + i * int(0.25 * b)
                claw_len = int(0.2 * b) if i == 1 else int(0.15 * b)
                claw_points = [
                    (claw_x - int(0.06 * b), boot_rect.bottom),
                    (claw_x + int(0.06 * b), boot_rect.bottom),
                    (claw_x, boot_rect.bottom + claw_len),
                ]
                pygame.draw.polygon(screen, p["horn"], claw_points)
                pygame.draw.polygon(screen, p["horn_light"], claw_points, 1)

        # === 몸통 (드래곤 비늘 갑옷) ===
        chest_w, chest_h = int(3.0 * b), int(2.2 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.35 * b), chest_w, chest_h)

        # 갑옷 그림자
        pygame.draw.rect(screen, p["armor_shadow"], chest_rect.inflate(2, 2), border_radius=int(0.45 * b))
        pygame.draw.rect(screen, p["armor"], chest_rect, border_radius=int(0.42 * b))
        pygame.draw.rect(screen, p["armor_mid"], chest_rect.inflate(-int(0.35 * b), -int(0.28 * b)), border_radius=int(0.35 * b))
        pygame.draw.rect(screen, p["armor_light"], chest_rect.inflate(-int(0.7 * b), -int(0.55 * b)), border_radius=int(0.25 * b))

        # 가슴 비늘 패턴 (더 상세)
        for row in range(3):
            for col in range(5):
                scale_x = chest_rect.left + int(0.35 * b) + col * int(0.45 * b)
                scale_y = chest_rect.top + int(0.35 * b) + row * int(0.45 * b)
                scale_w, scale_h = int(0.38 * b), int(0.28 * b)
                pygame.draw.arc(screen, p["scale"],
                              (scale_x, scale_y, scale_w, scale_h),
                              math.radians(0), math.radians(180), 2)
                pygame.draw.arc(screen, p["scale_light"],
                              (scale_x + 1, scale_y + 1, scale_w - 2, scale_h - 2),
                              math.radians(20), math.radians(160), 1)

        # 가슴 드래곤 문양 (불꽃 + 드래곤 눈, 발광)
        emblem_cx, emblem_cy = chest_rect.centerx, chest_rect.centery + int(0.1 * b)

        # 문양 글로우
        emblem_glow_size = int(1.2 * b)
        emblem_glow = pygame.Surface((emblem_glow_size, emblem_glow_size), pygame.SRCALPHA)
        pygame.draw.circle(emblem_glow, (*p["flame_edge"], int(50 * flame_pulse)), (emblem_glow_size // 2, emblem_glow_size // 2), emblem_glow_size // 2)
        screen.blit(emblem_glow, (emblem_cx - emblem_glow_size // 2, emblem_cy - emblem_glow_size // 2), special_flags=pygame.BLEND_ADD)

        # 불꽃 문양 (다층)
        flame_emblem_outer = [
            (emblem_cx, emblem_cy - int(0.5 * b)),
            (emblem_cx - int(0.35 * b), emblem_cy + int(0.25 * b)),
            (emblem_cx - int(0.15 * b), emblem_cy + int(0.1 * b)),
            (emblem_cx, emblem_cy + int(0.35 * b)),
            (emblem_cx + int(0.15 * b), emblem_cy + int(0.1 * b)),
            (emblem_cx + int(0.35 * b), emblem_cy + int(0.25 * b)),
        ]
        pygame.draw.polygon(screen, p["flame_dark"], flame_emblem_outer)
        flame_emblem_inner = [
            (emblem_cx, emblem_cy - int(0.35 * b)),
            (emblem_cx - int(0.22 * b), emblem_cy + int(0.15 * b)),
            (emblem_cx, emblem_cy + int(0.22 * b)),
            (emblem_cx + int(0.22 * b), emblem_cy + int(0.15 * b)),
        ]
        pygame.draw.polygon(screen, p["flame"], flame_emblem_inner)
        pygame.draw.polygon(screen, p["flame_core"], [
            (emblem_cx, emblem_cy - int(0.2 * b)),
            (emblem_cx - int(0.1 * b), emblem_cy + int(0.05 * b)),
            (emblem_cx, emblem_cy + int(0.1 * b)),
            (emblem_cx + int(0.1 * b), emblem_cy + int(0.05 * b)),
        ])

        # 허리 벨트 (금장식)
        belt_rect = pygame.Rect(cx - int(1.5 * b) + lean_offset, chest_rect.bottom - 4, int(3.0 * b), int(0.65 * b))
        pygame.draw.rect(screen, p["armor_shadow"], belt_rect, border_radius=3)
        pygame.draw.rect(screen, p["armor_dark"], belt_rect.inflate(-2, -2), border_radius=2)
        # 벨트 금장식
        for i in range(5):
            dec_x = belt_rect.left + int(0.3 * b) + i * int(0.55 * b)
            pygame.draw.circle(screen, p["gold_dark"], (dec_x, belt_rect.centery), max(1, int(0.08 * b)))
        # 벨트 버클 (드래곤 눈)
        buckle_r = max(3, int(0.25 * b))
        pygame.draw.circle(screen, p["gold_dark"], (belt_rect.centerx, belt_rect.centery), buckle_r + 2)
        pygame.draw.circle(screen, p["gold"], (belt_rect.centerx, belt_rect.centery), buckle_r)
        pygame.draw.circle(screen, p["eye"], (belt_rect.centerx, belt_rect.centery), max(2, int(buckle_r * 0.6)))
        pygame.draw.circle(screen, p["eye_core"], (belt_rect.centerx - 1, belt_rect.centery - 1), max(1, int(buckle_r * 0.25)))

        # === 어깨 갑옷 (드래곤 날개 형태, 더 정교함) ===
        for side in [-1, 1]:
            shoulder_x = cx + side * int(1.35 * b) + lean_offset
            shoulder_y = torso_y - int(0.25 * b)
            shoulder_w, shoulder_h = int(1.15 * b), int(0.95 * b)

            # 어깨 본체 그림자
            pygame.draw.ellipse(screen, p["armor_shadow"],
                              (shoulder_x - shoulder_w // 2 + 2, shoulder_y - int(0.35 * b) + 2, shoulder_w, shoulder_h))
            # 어깨 본체
            pygame.draw.ellipse(screen, p["armor"],
                              (shoulder_x - shoulder_w // 2, shoulder_y - int(0.35 * b), shoulder_w, shoulder_h))
            pygame.draw.ellipse(screen, p["armor_mid"],
                              (shoulder_x - shoulder_w // 2 + 3, shoulder_y - int(0.3 * b), shoulder_w - 6, shoulder_h - 6))
            pygame.draw.ellipse(screen, p["armor_light"],
                              (shoulder_x - shoulder_w // 2 + 6, shoulder_y - int(0.25 * b), shoulder_w - 12, shoulder_h - 12))

            # 어깨 비늘
            for i in range(3):
                scale_y = shoulder_y - int(0.2 * b) + i * int(0.2 * b)
                pygame.draw.arc(screen, p["scale"],
                              (shoulder_x - int(0.35 * b), scale_y, int(0.7 * b), int(0.2 * b)),
                              math.radians(0), math.radians(180), 1)

            # 스파이크/뿔 장식 (3개)
            for spike_idx in range(3):
                spike_offset = (spike_idx - 1) * 0.25
                spike_base_x = shoulder_x + side * int(0.3 * b) + int(spike_offset * side * b)
                spike_base_y = shoulder_y - int(0.3 * b) + abs(spike_idx - 1) * int(0.1 * b)
                spike_len = int(0.55 * b) if spike_idx == 1 else int(0.4 * b)
                spike_tip_x = spike_base_x + side * int(spike_len * 0.7)
                spike_tip_y = spike_base_y - spike_len

                # 스파이크 그림자
                pygame.draw.polygon(screen, p["horn_tip"], [
                    (spike_base_x - int(0.08 * b) + 1, spike_base_y + 1),
                    (spike_base_x + int(0.08 * b) + 1, spike_base_y + 1),
                    (spike_tip_x + 1, spike_tip_y + 1),
                ])
                # 스파이크
                pygame.draw.polygon(screen, p["horn"], [
                    (spike_base_x - int(0.08 * b), spike_base_y),
                    (spike_base_x + int(0.08 * b), spike_base_y),
                    (spike_tip_x, spike_tip_y),
                ])
                pygame.draw.polygon(screen, p["horn_mid"], [
                    (spike_base_x - int(0.04 * b), spike_base_y - int(0.05 * b)),
                    (spike_base_x + int(0.02 * b), spike_base_y - int(0.05 * b)),
                    (spike_tip_x - side * int(0.02 * b), spike_tip_y + int(0.1 * b)),
                ], 0)

        # === 팔 (드래곤 비늘) - 발토르 스타일 어깨 들썩임 ===
        for side in [-1, 1]:
            current_swing = left_arm_swing if side == -1 else right_arm_swing
            current_shoulder_bob = left_shoulder if side == -1 else right_shoulder
            arm_swing = int(current_swing * 2.5 * b)
            # 어깨 들썩임
            shoulder_y_offset = int(current_shoulder_bob * 0.35 * b + shoulder_bob * 0.25 * b)
            shoulder = (cx + side * int(1.4 * b) + lean_offset, torso_y + int(0.25 * b) + shoulder_y_offset)
            elbow = (shoulder[0] + side * int(0.55 * b) + arm_swing, torso_y + int(1.0 * b) + shoulder_y_offset)
            wrist = (elbow[0] + side * int(0.45 * b) + int(arm_swing * 0.5), torso_y + int(1.6 * b) + int(shoulder_y_offset * 0.5))

            # 상완
            pygame.draw.line(screen, p["armor_shadow"], (shoulder[0] + 1, shoulder[1] + 1), (elbow[0] + 1, elbow[1] + 1), max(4, int(0.7 * b)))
            pygame.draw.line(screen, p["armor"], shoulder, elbow, max(4, int(0.65 * b)))
            pygame.draw.line(screen, p["armor_mid"], shoulder, elbow, max(2, int(0.4 * b)))

            # 팔꿈치 조인트
            pygame.draw.circle(screen, p["armor_dark"], elbow, max(3, int(0.28 * b)))
            pygame.draw.circle(screen, p["armor"], elbow, max(2, int(0.22 * b)))

            # 하완
            pygame.draw.line(screen, p["armor_shadow"], (elbow[0] + 1, elbow[1] + 1), (wrist[0] + 1, wrist[1] + 1), max(3, int(0.58 * b)))
            pygame.draw.line(screen, p["armor_light"], elbow, wrist, max(3, int(0.55 * b)))
            pygame.draw.line(screen, p["armor_mid"], elbow, wrist, max(2, int(0.35 * b)))

            # 드래곤 발톱 장갑
            pygame.draw.circle(screen, p["armor_shadow"], (wrist[0] + 1, wrist[1] + 1), max(3, int(0.4 * b)))
            pygame.draw.circle(screen, p["armor_dark"], wrist, max(3, int(0.38 * b)))
            pygame.draw.circle(screen, p["armor"], wrist, max(2, int(0.3 * b)))

            # 발톱 (5개)
            for i in range(5):
                claw_angle = side * (0.2 + i * 0.18) - 0.3
                claw_len = int(0.25 * b) if i == 2 else int(0.18 * b)
                claw_x = wrist[0] + int(math.cos(claw_angle) * 0.35 * b)
                claw_y = wrist[1] + int(math.sin(claw_angle + math.pi / 2) * 0.25 * b) + int(0.18 * b)
                claw_tip_x = claw_x + int(math.cos(claw_angle) * claw_len)
                claw_tip_y = claw_y + claw_len
                pygame.draw.line(screen, p["horn"], wrist, (claw_x, claw_y), max(2, int(0.08 * b)))
                pygame.draw.line(screen, p["horn_light"], (claw_x, claw_y), (claw_tip_x, claw_tip_y), max(1, int(0.05 * b)))

        # === 드래곤 헬멧 (더 정교함) ===
        head_y = torso_y - int(3.2 * b)
        head_w, head_h = int(2.6 * b), int(2.4 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        # 헬멧 그림자
        pygame.draw.ellipse(screen, p["armor_shadow"], head_rect.inflate(2, 2))
        # 헬멧 본체
        pygame.draw.ellipse(screen, p["armor"], head_rect)
        pygame.draw.ellipse(screen, p["armor_mid"], head_rect.inflate(-int(0.35 * b), -int(0.28 * b)))
        pygame.draw.ellipse(screen, p["armor_light"], head_rect.inflate(-int(0.7 * b), -int(0.55 * b)))

        # 헬멧 비늘 패턴
        for i in range(4):
            scale_y = head_rect.top + int(0.3 * b) + i * int(0.4 * b)
            scale_w = head_w - int(i * 0.2 * b)
            pygame.draw.arc(screen, p["scale"],
                          (head_rect.centerx - scale_w // 2, scale_y, scale_w, int(0.25 * b)),
                          math.radians(0), math.radians(180), 1)

        # 드래곤 뿔 (양쪽, 더 정교함)
        for side in [-1, 1]:
            horn_base_x = head_rect.centerx + side * int(0.65 * b)
            horn_base_y = head_rect.top + int(0.38 * b)
            horn_tip_x = horn_base_x + side * int(0.6 * b)
            horn_tip_y = horn_base_y - int(0.85 * b)

            # 뿔 그림자
            pygame.draw.polygon(screen, p["horn_tip"], [
                (horn_base_x - int(0.12 * b) + 1, horn_base_y + 1),
                (horn_base_x + int(0.12 * b) + 1, horn_base_y + 1),
                (horn_tip_x + 1, horn_tip_y + 1),
            ])
            # 뿔 본체
            pygame.draw.polygon(screen, p["horn"], [
                (horn_base_x - int(0.12 * b), horn_base_y),
                (horn_base_x + int(0.12 * b), horn_base_y),
                (horn_tip_x, horn_tip_y),
            ])
            # 뿔 하이라이트
            pygame.draw.polygon(screen, p["horn_mid"], [
                (horn_base_x - int(0.06 * b), horn_base_y - int(0.08 * b)),
                (horn_base_x + int(0.03 * b), horn_base_y - int(0.08 * b)),
                (horn_tip_x - side * int(0.03 * b), horn_tip_y + int(0.15 * b)),
            ])
            # 뿔 고리
            for ring in range(3):
                ring_ratio = (ring + 1) / 4
                ring_x = horn_base_x + side * int(ring_ratio * 0.45 * b)
                ring_y = horn_base_y - int(ring_ratio * 0.65 * b)
                pygame.draw.line(screen, p["horn_light"],
                               (ring_x - int(0.08 * b), ring_y),
                               (ring_x + int(0.08 * b), ring_y), 1)

        if show_back:
            # 뒷모습 - 헬멧 뒷면
            pygame.draw.ellipse(screen, p["armor_dark"], head_rect.inflate(-int(0.18 * b), -int(0.12 * b)))
            # 비늘 패턴
            for i in range(4):
                scale_y = head_rect.centery + (i - 1.5) * int(0.32 * b)
                pygame.draw.arc(screen, p["scale"],
                              (head_rect.centerx - int(0.45 * b), scale_y, int(0.9 * b), int(0.22 * b)),
                              math.radians(0), math.radians(180), 2)
        else:
            # 정면 - 드래곤 눈 바이저
            visor_rect = pygame.Rect(
                head_rect.centerx - int(0.8 * b),
                head_rect.centery - int(0.22 * b),
                int(1.6 * b), int(0.55 * b)
            )
            pygame.draw.rect(screen, p["armor_shadow"], visor_rect.inflate(2, 2), border_radius=3)
            pygame.draw.rect(screen, p["armor_dark"], visor_rect, border_radius=3)

            # 빛나는 눈 (더 강렬)
            for side in [-1, 1]:
                eye_x = visor_rect.centerx + side * int(0.35 * b)
                eye_y = visor_rect.centery
                eye_w, eye_h = int(0.35 * b), int(0.25 * b)

                # 눈 글로우 (다층)
                for glow_layer in range(3):
                    glow_w = int((0.6 - glow_layer * 0.15) * b)
                    glow_h = int((0.45 - glow_layer * 0.12) * b)
                    glow_alpha = int((80 - glow_layer * 25) * (0.6 + flame_pulse * 0.4))
                    glow_surf = pygame.Surface((glow_w, glow_h), pygame.SRCALPHA)
                    pygame.draw.ellipse(glow_surf, (*p["eye_glow"], glow_alpha), (0, 0, glow_w, glow_h))
                    screen.blit(glow_surf, (eye_x - glow_w // 2, eye_y - glow_h // 2), special_flags=pygame.BLEND_ADD)

                # 눈 본체
                pygame.draw.ellipse(screen, p["eye"], (eye_x - eye_w // 2, eye_y - eye_h // 2, eye_w, eye_h))
                pygame.draw.ellipse(screen, p["eye_core"], (eye_x - eye_w // 3, eye_y - eye_h // 3, eye_w * 2 // 3, eye_h * 2 // 3))

            # 코/입 부분 (드래곤 주둥이)
            snout_points = [
                (head_rect.centerx - int(0.25 * b), visor_rect.bottom),
                (head_rect.centerx + int(0.25 * b), visor_rect.bottom),
                (head_rect.centerx + int(0.15 * b), head_rect.bottom - int(0.08 * b)),
                (head_rect.centerx - int(0.15 * b), head_rect.bottom - int(0.08 * b)),
            ]
            pygame.draw.polygon(screen, p["armor_dark"], snout_points)
            # 콧구멍
            for side in [-1, 1]:
                nostril_x = head_rect.centerx + side * int(0.08 * b)
                nostril_y = visor_rect.bottom + int(0.15 * b)
                pygame.draw.circle(screen, p["armor_shadow"], (nostril_x, nostril_y), max(1, int(0.04 * b)))

        # === 불꽃 효과 (손 주변, 더 화려함) ===
        flame_x = cx + int(2.4 * b) + lean_offset
        flame_y = torso_y + int(1.2 * b)

        # 불꽃 오라
        flame_aura = pygame.Surface((int(1.5 * b), int(2 * b)), pygame.SRCALPHA)
        pygame.draw.ellipse(flame_aura, (*p["flame_edge"], int(40 * flame_pulse)), (0, 0, int(1.5 * b), int(2 * b)))
        screen.blit(flame_aura, (flame_x - int(0.75 * b), flame_y - int(1.5 * b)), special_flags=pygame.BLEND_ADD)

        # 불꽃 파티클
        for i in range(8):
            f_angle = self.time * 6 + i * 0.7
            f_radius = 0.35 * b * (0.5 + (i % 3) * 0.2)
            f_x = flame_x + int(math.cos(f_angle) * f_radius)
            f_y = flame_y - int(0.4 * b) + int(math.sin(f_angle * 2) * 0.25 * b) - i * int(0.18 * b)
            f_size = max(2, int(0.22 * b) - i)

            if f_size > 0:
                # 불꽃 글로우
                if i < 3:
                    glow_size = f_size * 3
                    glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surf, (*p["flame_mid"], 100), (glow_size // 2, glow_size // 2), glow_size // 2)
                    screen.blit(glow_surf, (f_x - glow_size // 2, f_y - glow_size // 2), special_flags=pygame.BLEND_ADD)

                # 불꽃 본체
                flame_color = p["flame_core"] if i < 2 else (p["flame_mid"] if i < 4 else p["flame"])
                pygame.draw.circle(screen, flame_color, (f_x, f_y), f_size)

    # =========================================================================
    # 기어 - 스팀펑크 메카닉 (기계 팔과 톱니바퀴) [고퀄리티 업그레이드]
    # =========================================================================
    def _draw_gear(self, screen, cx, cy, b, color, show_back, anim):
        """기어 - 스팀펑크 메카닉 (증기 기관과 톱니바퀴로 무장) [고퀄리티]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        left_arm_swing = anim.get("left_arm_swing", 0)
        right_arm_swing = anim.get("right_arm_swing", 0)
        shoulder_bob = anim.get("shoulder_bob", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        # 기계 작동 펄스
        mech_pulse = (math.sin(self.time * 4) + 1) * 0.5
        gear_spin = self.time * 3

        p = {
            "metal": color,
            "metal_light": tuple(min(255, c + 60) for c in color),
            "metal_mid": tuple(min(255, c + 30) for c in color),
            "metal_dark": tuple(max(0, c - 50) for c in color),
            "metal_shadow": tuple(max(0, c - 80) for c in color),
            "copper": (190, 110, 65),
            "copper_light": (230, 155, 100),
            "copper_mid": (210, 130, 80),
            "copper_dark": (140, 75, 45),
            "brass": (210, 180, 90),
            "brass_light": (240, 210, 130),
            "brass_dark": (160, 130, 55),
            "leather": (75, 55, 45),
            "leather_mid": (95, 72, 58),
            "leather_light": (125, 95, 75),
            "leather_dark": (50, 38, 32),
            "skin": (225, 200, 180),
            "skin_shadow": (195, 170, 150),
            "hair": (95, 75, 55),
            "hair_light": (130, 105, 80),
            "eye": (160, 210, 230),  # 고글 렌즈
            "eye_glow": (120, 200, 255),
            "steam": (230, 230, 240),
            "steam_hot": (255, 220, 200),
            "gear": (170, 150, 110),
            "gear_light": (200, 180, 140),
            "gear_dark": (130, 115, 85),
            "rivet": (180, 170, 160),
            "glass": (200, 220, 230),
            "gauge_green": (80, 200, 100),
            "gauge_red": (255, 100, 80),
        }

        # === 증기 오라 효과 ===
        aura_size = int(4 * b)
        aura_surf = pygame.Surface((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
        for i in range(3):
            aura_alpha = int((15 - i * 4) * mech_pulse)
            aura_r = int((1.6 - i * 0.4) * b)
            pygame.draw.circle(aura_surf, (*p["steam"], aura_alpha), (aura_size, aura_size), aura_r)
        screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - int(0.8 * b) - aura_size // 2), special_flags=pygame.BLEND_ADD)

        # === 다리 (스팀펑크 레깅스) ===
        hip_y = torso_y + int(2.0 * b)
        for side in [-1, 1]:
            leg_phase = int(abs(wave) * 1.5) if side == 1 else 0
            thigh_x = cx + side * int(0.52 * b) + lean_offset

            # 허벅지 (가죽 + 금속 스트랩)
            thigh_rect = pygame.Rect(thigh_x - int(0.44 * b), hip_y + leg_phase, int(0.88 * b), int(1.7 * b))
            pygame.draw.rect(screen, p["leather_dark"], thigh_rect.inflate(2, 2), border_radius=4)
            pygame.draw.rect(screen, p["leather"], thigh_rect, border_radius=4)
            pygame.draw.rect(screen, p["leather_mid"], thigh_rect.inflate(-int(0.12 * b), -int(0.1 * b)), border_radius=3)

            # 금속 스트랩/버클
            for i in range(3):
                strap_y = thigh_rect.top + int(0.25 * b) + i * int(0.5 * b)
                pygame.draw.rect(screen, p["brass_dark"], (thigh_rect.left + 1, strap_y, thigh_rect.width - 2, int(0.12 * b)), border_radius=1)
                pygame.draw.rect(screen, p["brass"], (thigh_rect.left + 2, strap_y + 1, thigh_rect.width - 4, int(0.08 * b)), border_radius=1)
                # 버클
                buckle_x = thigh_rect.centerx + side * int(0.15 * b)
                pygame.draw.rect(screen, p["brass_light"], (buckle_x - int(0.06 * b), strap_y - 1, int(0.12 * b), int(0.14 * b)), border_radius=1)

            # 무릎 조인트 (복잡한 기계)
            knee_y = thigh_rect.bottom - int(0.22 * b)
            knee_rect = pygame.Rect(thigh_x - int(0.4 * b), knee_y, int(0.8 * b), int(0.58 * b))
            pygame.draw.rect(screen, p["copper_dark"], knee_rect.inflate(2, 2), border_radius=3)
            pygame.draw.rect(screen, p["copper"], knee_rect, border_radius=3)
            pygame.draw.rect(screen, p["copper_light"], knee_rect.inflate(-int(0.1 * b), -int(0.08 * b)), border_radius=2)

            # 무릎 톱니바퀴
            knee_cx, knee_cy = knee_rect.centerx, knee_rect.centery
            knee_gear_r = int(0.18 * b)
            for tooth in range(8):
                angle = gear_spin * side + tooth * math.pi / 4
                gx = knee_cx + int(math.cos(angle) * knee_gear_r)
                gy = knee_cy + int(math.sin(angle) * knee_gear_r * 0.8)
                pygame.draw.circle(screen, p["brass"], (gx, gy), max(1, int(0.05 * b)))
            pygame.draw.circle(screen, p["brass_dark"], (knee_cx, knee_cy), max(2, int(0.12 * b)))
            pygame.draw.circle(screen, p["brass"], (knee_cx, knee_cy), max(1, int(0.08 * b)))

            # 부츠 (철제, 리벳 장식)
            boot_rect = pygame.Rect(thigh_x - int(0.44 * b), knee_rect.bottom - 2, int(0.88 * b), int(0.9 * b))
            pygame.draw.rect(screen, p["metal_shadow"], boot_rect.inflate(2, 2), border_radius=3)
            pygame.draw.rect(screen, p["metal_dark"], boot_rect, border_radius=3)
            pygame.draw.rect(screen, p["metal"], boot_rect.inflate(-int(0.1 * b), -int(0.08 * b)), border_radius=2)

            # 부츠 리벳
            for row in range(2):
                for col in range(3):
                    rivet_x = boot_rect.left + int(0.15 * b) + col * int(0.28 * b)
                    rivet_y = boot_rect.top + int(0.15 * b) + row * int(0.35 * b)
                    pygame.draw.circle(screen, p["rivet"], (rivet_x, rivet_y), max(1, int(0.04 * b)))

            # 부츠 발끝 금속판
            toe_rect = (boot_rect.left + int(0.08 * b), boot_rect.bottom - int(0.2 * b), boot_rect.width - int(0.16 * b), int(0.22 * b))
            pygame.draw.rect(screen, p["metal_light"], toe_rect, border_radius=2)

        # === 몸통 (스팀펑크 조끼) ===
        chest_w, chest_h = int(3.0 * b), int(2.15 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.32 * b), chest_w, chest_h)

        # 조끼 그림자
        pygame.draw.rect(screen, p["leather_dark"], chest_rect.inflate(2, 2), border_radius=int(0.45 * b))
        pygame.draw.rect(screen, p["leather"], chest_rect, border_radius=int(0.42 * b))
        pygame.draw.rect(screen, p["leather_mid"], chest_rect.inflate(-int(0.35 * b), -int(0.28 * b)), border_radius=int(0.35 * b))
        pygame.draw.rect(screen, p["leather_light"], chest_rect.inflate(-int(0.7 * b), -int(0.55 * b)), border_radius=int(0.25 * b))

        # 조끼 바느질 라인
        pygame.draw.line(screen, p["leather_dark"], (chest_rect.centerx, chest_rect.top + int(0.15 * b)),
                        (chest_rect.centerx, chest_rect.bottom - int(0.1 * b)), 2)
        for i in range(4):
            stitch_y = chest_rect.top + int(0.3 * b) + i * int(0.4 * b)
            pygame.draw.line(screen, p["leather_dark"], (chest_rect.centerx - int(0.08 * b), stitch_y),
                           (chest_rect.centerx + int(0.08 * b), stitch_y), 1)

        # 가슴 기계 장치 (더 복잡함)
        device_rect = pygame.Rect(chest_rect.centerx - int(0.6 * b), chest_rect.centery - int(0.45 * b),
                                  int(1.2 * b), int(0.9 * b))
        # 장치 베이스
        pygame.draw.rect(screen, p["copper_dark"], device_rect.inflate(4, 4), border_radius=5)
        pygame.draw.rect(screen, p["copper"], device_rect, border_radius=4)
        pygame.draw.rect(screen, p["copper_light"], device_rect.inflate(-int(0.15 * b), -int(0.12 * b)), border_radius=3)

        # 장치 테두리 리벳
        for corner in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
            rx = device_rect.centerx + corner[0] * int(0.45 * b)
            ry = device_rect.centery + corner[1] * int(0.32 * b)
            pygame.draw.circle(screen, p["brass_dark"], (rx, ry), max(2, int(0.06 * b)))
            pygame.draw.circle(screen, p["brass"], (rx - 1, ry - 1), max(1, int(0.04 * b)))

        # 메인 게이지 (압력계)
        gauge_cx = device_rect.centerx - int(0.25 * b)
        gauge_cy = device_rect.centery
        gauge_r = max(3, int(0.28 * b))
        pygame.draw.circle(screen, p["brass_dark"], (gauge_cx, gauge_cy), gauge_r + 2)
        pygame.draw.circle(screen, p["brass"], (gauge_cx, gauge_cy), gauge_r)
        pygame.draw.circle(screen, p["glass"], (gauge_cx, gauge_cy), gauge_r - 2)
        # 게이지 눈금
        for i in range(8):
            mark_angle = -math.pi / 2 + i * math.pi / 4
            mx1 = gauge_cx + int(math.cos(mark_angle) * (gauge_r - 4))
            my1 = gauge_cy + int(math.sin(mark_angle) * (gauge_r - 4))
            mx2 = gauge_cx + int(math.cos(mark_angle) * (gauge_r - 6))
            my2 = gauge_cy + int(math.sin(mark_angle) * (gauge_r - 6))
            pygame.draw.line(screen, p["copper_dark"], (mx1, my1), (mx2, my2), 1)
        # 게이지 바늘
        needle_angle = math.sin(self.time * 2) * 0.8 - math.pi / 4
        needle_len = gauge_r - 5
        nx = gauge_cx + int(math.cos(needle_angle) * needle_len)
        ny = gauge_cy + int(math.sin(needle_angle) * needle_len)
        pygame.draw.line(screen, p["gauge_red"], (gauge_cx, gauge_cy), (nx, ny), 2)
        pygame.draw.circle(screen, p["brass_dark"], (gauge_cx, gauge_cy), max(1, int(0.05 * b)))

        # 보조 장치 (톱니바퀴)
        aux_cx = device_rect.centerx + int(0.28 * b)
        aux_cy = device_rect.centery
        aux_r = int(0.2 * b)
        # 회전하는 톱니바퀴
        tooth_count = 10
        for i in range(tooth_count):
            angle = gear_spin * 1.5 + i * 2 * math.pi / tooth_count
            inner_r = aux_r * 0.7
            outer_r = aux_r
            pygame.draw.line(screen, p["gear_dark"],
                           (aux_cx + int(math.cos(angle) * inner_r), aux_cy + int(math.sin(angle) * inner_r)),
                           (aux_cx + int(math.cos(angle) * outer_r), aux_cy + int(math.sin(angle) * outer_r)), 2)
        pygame.draw.circle(screen, p["gear"], (aux_cx, aux_cy), int(aux_r * 0.6))
        pygame.draw.circle(screen, p["gear_light"], (aux_cx, aux_cy), int(aux_r * 0.4))
        pygame.draw.circle(screen, p["brass_dark"], (aux_cx, aux_cy), max(1, int(0.05 * b)))

        # 파이프 연결
        pipe_y = device_rect.bottom - int(0.12 * b)
        pygame.draw.line(screen, p["copper_dark"], (device_rect.left + int(0.15 * b), pipe_y),
                        (device_rect.left - int(0.2 * b), pipe_y + int(0.15 * b)), max(2, int(0.08 * b)))
        pygame.draw.line(screen, p["copper_dark"], (device_rect.right - int(0.15 * b), pipe_y),
                        (device_rect.right + int(0.2 * b), pipe_y + int(0.15 * b)), max(2, int(0.08 * b)))

        # 허리 벨트 (도구 벨트)
        belt_rect = pygame.Rect(cx - int(1.5 * b) + lean_offset, chest_rect.bottom - 4, int(3.0 * b), int(0.75 * b))
        pygame.draw.rect(screen, p["leather_dark"], belt_rect.inflate(2, 2), border_radius=3)
        pygame.draw.rect(screen, p["leather"], belt_rect, border_radius=3)

        # 도구/파우치 (더 상세)
        pouch_positions = [(-0.9, 0.35), (-0.3, 0.4), (0.3, 0.35), (0.9, 0.4)]
        for px_off, pw in pouch_positions:
            pouch_x = belt_rect.centerx + int(px_off * b)
            pouch_w = int(pw * b)
            pouch_h = belt_rect.height - 6
            pygame.draw.rect(screen, p["metal_shadow"], (pouch_x - pouch_w // 2, belt_rect.top + 3, pouch_w, pouch_h), border_radius=2)
            pygame.draw.rect(screen, p["metal_dark"], (pouch_x - pouch_w // 2 + 1, belt_rect.top + 4, pouch_w - 2, pouch_h - 2), border_radius=1)
            # 버클
            pygame.draw.rect(screen, p["brass"], (pouch_x - int(0.05 * b), belt_rect.top + 2, int(0.1 * b), int(0.08 * b)), border_radius=1)

        # 벨트 버클
        buckle_w, buckle_h = int(0.35 * b), int(0.35 * b)
        buckle_rect = (belt_rect.centerx - buckle_w // 2, belt_rect.centery - buckle_h // 2, buckle_w, buckle_h)
        pygame.draw.rect(screen, p["brass_dark"], buckle_rect, border_radius=3)
        pygame.draw.rect(screen, p["brass"], (buckle_rect[0] + 2, buckle_rect[1] + 2, buckle_w - 4, buckle_h - 4), border_radius=2)
        # 톱니바퀴 문양
        pygame.draw.circle(screen, p["gear"], (belt_rect.centerx, belt_rect.centery), max(2, int(0.1 * b)))

        # === 어깨 (기계 장치, 더 정교함) ===
        for side in [-1, 1]:
            shoulder_x = cx + side * int(1.3 * b) + lean_offset
            shoulder_y = torso_y - int(0.25 * b)
            shoulder_w, shoulder_h = int(1.1 * b), int(0.9 * b)

            # 어깨 패드 베이스
            pygame.draw.ellipse(screen, p["metal_shadow"],
                              (shoulder_x - shoulder_w // 2 + 2, shoulder_y - int(0.32 * b) + 2, shoulder_w, shoulder_h))
            pygame.draw.ellipse(screen, p["metal"],
                              (shoulder_x - shoulder_w // 2, shoulder_y - int(0.32 * b), shoulder_w, shoulder_h))
            pygame.draw.ellipse(screen, p["metal_mid"],
                              (shoulder_x - shoulder_w // 2 + 4, shoulder_y - int(0.28 * b), shoulder_w - 8, shoulder_h - 8))

            # 어깨 리벳
            for i in range(4):
                rivet_angle = math.pi + side * (0.3 + i * 0.35)
                rx = shoulder_x + int(math.cos(rivet_angle) * (shoulder_w * 0.35))
                ry = shoulder_y + int(math.sin(rivet_angle) * (shoulder_h * 0.25))
                pygame.draw.circle(screen, p["rivet"], (rx, ry), max(1, int(0.04 * b)))

            # 톱니바퀴 장식 (회전)
            gear_r = int(0.35 * b)
            tooth_count = 8
            for i in range(tooth_count):
                angle = gear_spin * side + i * 2 * math.pi / tooth_count
                inner_r = gear_r * 0.65
                outer_r = gear_r
                gx_inner = shoulder_x + int(math.cos(angle) * inner_r)
                gy_inner = shoulder_y + int(math.sin(angle) * inner_r)
                gx_outer = shoulder_x + int(math.cos(angle) * outer_r)
                gy_outer = shoulder_y + int(math.sin(angle) * outer_r)
                pygame.draw.line(screen, p["brass_dark"], (gx_inner, gy_inner), (gx_outer, gy_outer), max(2, int(0.08 * b)))

            pygame.draw.circle(screen, p["copper_dark"], (shoulder_x, shoulder_y), max(3, int(0.25 * b)))
            pygame.draw.circle(screen, p["copper"], (shoulder_x, shoulder_y), max(2, int(0.2 * b)))
            pygame.draw.circle(screen, p["copper_light"], (shoulder_x - 1, shoulder_y - 1), max(1, int(0.1 * b)))

        # === 팔 (하나는 기계팔, 더 정교함 + 어깨 들썩임) ===
        for side in [-1, 1]:
            shoulder_bob_offset = int(shoulder_bob * 0.3 * b)
            shoulder = (cx + side * int(1.4 * b) + lean_offset, torso_y + int(0.25 * b) + shoulder_bob_offset)
            elbow = (shoulder[0] + side * int(0.55 * b), torso_y + int(0.95 * b))
            wrist = (elbow[0] + side * int(0.45 * b), torso_y + int(1.6 * b))

            if side == 1:  # 오른팔 - 기계팔
                # 상완 (피스톤 구조)
                # 외부 파이프
                pygame.draw.line(screen, p["copper_dark"], (shoulder[0] + 2, shoulder[1] + 2), (elbow[0] + 2, elbow[1] + 2), max(4, int(0.65 * b)))
                pygame.draw.line(screen, p["copper"], shoulder, elbow, max(4, int(0.62 * b)))
                # 내부 파이프
                pygame.draw.line(screen, p["brass_dark"], shoulder, elbow, max(2, int(0.35 * b)))
                pygame.draw.line(screen, p["brass"], shoulder, elbow, max(1, int(0.25 * b)))
                # 피스톤 링
                for i in range(3):
                    ring_ratio = (i + 1) / 4
                    ring_x = shoulder[0] + int((elbow[0] - shoulder[0]) * ring_ratio)
                    ring_y = shoulder[1] + int((elbow[1] - shoulder[1]) * ring_ratio)
                    pygame.draw.circle(screen, p["brass_dark"], (ring_x, ring_y), max(2, int(0.15 * b)))

                # 팔꿈치 조인트 (복잡한 기계)
                pygame.draw.circle(screen, p["metal_shadow"], (elbow[0] + 2, elbow[1] + 2), max(4, int(0.32 * b)))
                pygame.draw.circle(screen, p["metal"], elbow, max(4, int(0.3 * b)))
                pygame.draw.circle(screen, p["metal_mid"], elbow, max(3, int(0.22 * b)))
                # 조인트 톱니
                for i in range(6):
                    angle = gear_spin * 2 + i * math.pi / 3
                    jx = elbow[0] + int(math.cos(angle) * 0.22 * b)
                    jy = elbow[1] + int(math.sin(angle) * 0.22 * b)
                    pygame.draw.circle(screen, p["brass"], (jx, jy), max(1, int(0.04 * b)))
                pygame.draw.circle(screen, p["brass_dark"], elbow, max(2, int(0.12 * b)))
                pygame.draw.circle(screen, p["brass"], elbow, max(1, int(0.08 * b)))

                # 전완 (기계, 여러 세그먼트)
                pygame.draw.line(screen, p["metal_shadow"], (elbow[0] + 2, elbow[1] + 2), (wrist[0] + 2, wrist[1] + 2), max(4, int(0.6 * b)))
                pygame.draw.line(screen, p["metal"], elbow, wrist, max(4, int(0.58 * b)))
                pygame.draw.line(screen, p["metal_mid"], elbow, wrist, max(2, int(0.38 * b)))
                # 전완 플레이트
                for i in range(2):
                    plate_ratio = (i + 1) / 3
                    plate_x = elbow[0] + int((wrist[0] - elbow[0]) * plate_ratio)
                    plate_y = elbow[1] + int((wrist[1] - elbow[1]) * plate_ratio)
                    pygame.draw.circle(screen, p["copper"], (plate_x, plate_y), max(2, int(0.12 * b)))

                # 기계 손 (더 정교함)
                pygame.draw.circle(screen, p["metal_shadow"], (wrist[0] + 2, wrist[1] + 2), max(4, int(0.4 * b)))
                pygame.draw.circle(screen, p["metal_dark"], wrist, max(4, int(0.38 * b)))
                pygame.draw.circle(screen, p["metal"], wrist, max(3, int(0.3 * b)))
                pygame.draw.circle(screen, p["metal_light"], (wrist[0] - 2, wrist[1] - 2), max(1, int(0.15 * b)))

                # 손가락 (집게, 4개)
                finger_grip = math.sin(self.time * 4) * 0.12
                for i in range(4):
                    finger_angle = 0.25 + i * 0.25 + finger_grip
                    finger_len = int(0.45 * b) if i == 1 or i == 2 else int(0.35 * b)
                    fx1 = wrist[0] + int(math.cos(finger_angle) * 0.2 * b)
                    fy1 = wrist[1] + int(math.sin(finger_angle) * 0.15 * b) + int(0.1 * b)
                    fx2 = fx1 + int(math.cos(finger_angle + 0.2) * finger_len * 0.6)
                    fy2 = fy1 + int(finger_len * 0.4)
                    fx3 = fx2 + int(math.cos(finger_angle + 0.1) * finger_len * 0.4)
                    fy3 = fy2 + int(finger_len * 0.3)
                    # 손가락 세그먼트
                    pygame.draw.line(screen, p["copper_dark"], (wrist[0], wrist[1] + int(0.08 * b)), (fx1, fy1), max(2, int(0.1 * b)))
                    pygame.draw.line(screen, p["copper"], (fx1, fy1), (fx2, fy2), max(2, int(0.08 * b)))
                    pygame.draw.line(screen, p["copper_light"], (fx2, fy2), (fx3, fy3), max(1, int(0.06 * b)))
                    # 관절
                    pygame.draw.circle(screen, p["brass"], (fx1, fy1), max(1, int(0.04 * b)))
                    pygame.draw.circle(screen, p["brass"], (fx2, fy2), max(1, int(0.03 * b)))
            else:  # 왼팔 - 일반 팔 (가죽 장갑)
                pygame.draw.line(screen, p["leather_dark"], (shoulder[0] + 1, shoulder[1] + 1), (elbow[0] + 1, elbow[1] + 1), max(3, int(0.55 * b)))
                pygame.draw.line(screen, p["leather"], shoulder, elbow, max(3, int(0.52 * b)))
                pygame.draw.line(screen, p["leather_light"], shoulder, elbow, max(2, int(0.32 * b)))

                pygame.draw.line(screen, p["skin_shadow"], (elbow[0] + 1, elbow[1] + 1), (wrist[0] + 1, wrist[1] + 1), max(2, int(0.45 * b)))
                pygame.draw.line(screen, p["skin"], elbow, wrist, max(2, int(0.42 * b)))

                pygame.draw.circle(screen, p["skin_shadow"], (wrist[0] + 1, wrist[1] + 1), max(3, int(0.35 * b)))
                pygame.draw.circle(screen, p["skin"], wrist, max(3, int(0.32 * b)))
                # 가죽 장갑
                pygame.draw.circle(screen, p["leather"], wrist, max(2, int(0.25 * b)))

        # === 머리 (고글 + 모자) ===
        head_y = torso_y - int(3.0 * b)
        head_w, head_h = int(2.2 * b), int(2.0 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        if show_back:
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            pygame.draw.ellipse(screen, p["hair_light"], head_rect.inflate(-int(0.3 * b), -int(0.25 * b)))
            # 고글 끈
            pygame.draw.line(screen, p["leather_dark"], (head_rect.left + int(0.18 * b), head_rect.centery - int(0.05 * b)),
                           (head_rect.right - int(0.18 * b), head_rect.centery - int(0.05 * b)), max(2, int(0.1 * b)))
            pygame.draw.line(screen, p["leather"], (head_rect.left + int(0.2 * b), head_rect.centery - int(0.05 * b)),
                           (head_rect.right - int(0.2 * b), head_rect.centery - int(0.05 * b)), max(1, int(0.06 * b)))
        else:
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            pygame.draw.ellipse(screen, p["hair_light"], head_rect.inflate(-int(0.35 * b), -int(0.28 * b)))

            # 얼굴
            face_rect = head_rect.inflate(-int(0.45 * b), -int(0.35 * b))
            face_rect.move_ip(0, int(0.18 * b))
            pygame.draw.ellipse(screen, p["skin_shadow"], face_rect.inflate(2, 2))
            pygame.draw.ellipse(screen, p["skin"], face_rect)

            # 고글 (더 정교함)
            for side in [-1, 1]:
                goggle_x = face_rect.centerx + side * int(0.38 * b)
                goggle_y = face_rect.centery - int(0.1 * b)
                goggle_r = max(4, int(0.28 * b))

                # 고글 프레임
                pygame.draw.circle(screen, p["copper_dark"], (goggle_x + 1, goggle_y + 1), goggle_r + 3)
                pygame.draw.circle(screen, p["copper"], (goggle_x, goggle_y), goggle_r + 2)
                pygame.draw.circle(screen, p["copper_light"], (goggle_x, goggle_y), goggle_r + 1, 2)
                # 렌즈
                pygame.draw.circle(screen, p["eye"], (goggle_x, goggle_y), goggle_r - 2)
                # 렌즈 글로우
                glow_surf = pygame.Surface((goggle_r * 2, goggle_r * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*p["eye_glow"], int(40 * mech_pulse)), (goggle_r, goggle_r), goggle_r - 3)
                screen.blit(glow_surf, (goggle_x - goggle_r, goggle_y - goggle_r), special_flags=pygame.BLEND_ADD)
                # 반사광
                pygame.draw.circle(screen, (255, 255, 255), (goggle_x - 3, goggle_y - 3), max(1, int(0.06 * b)))
                pygame.draw.circle(screen, (255, 255, 255), (goggle_x - 1, goggle_y + 2), 1)

            # 고글 브릿지
            pygame.draw.line(screen, p["copper_dark"],
                           (face_rect.centerx - int(0.12 * b), face_rect.centery - int(0.1 * b)),
                           (face_rect.centerx + int(0.12 * b), face_rect.centery - int(0.1 * b)), max(3, int(0.1 * b)))
            pygame.draw.line(screen, p["copper"],
                           (face_rect.centerx - int(0.1 * b), face_rect.centery - int(0.11 * b)),
                           (face_rect.centerx + int(0.1 * b), face_rect.centery - int(0.11 * b)), max(2, int(0.06 * b)))

            # 콧수염
            for side in [-1, 1]:
                mustache_points = [
                    (face_rect.centerx + side * int(0.05 * b), face_rect.centery + int(0.2 * b)),
                    (face_rect.centerx + side * int(0.25 * b), face_rect.centery + int(0.18 * b)),
                    (face_rect.centerx + side * int(0.35 * b), face_rect.centery + int(0.22 * b)),
                ]
                pygame.draw.lines(screen, p["hair"], False, mustache_points, 2)

            # 모자 (가죽 + 고글)
            hat_rect = pygame.Rect(head_rect.left + int(0.08 * b), head_rect.top - int(0.12 * b),
                                   head_rect.width - int(0.16 * b), int(0.55 * b))
            pygame.draw.rect(screen, p["leather_dark"], hat_rect.inflate(2, 2), border_radius=3)
            pygame.draw.rect(screen, p["leather"], hat_rect, border_radius=3)
            pygame.draw.rect(screen, p["leather_mid"], hat_rect.inflate(-int(0.1 * b), -int(0.08 * b)), border_radius=2)
            # 모자 밴드
            pygame.draw.rect(screen, p["brass_dark"], (hat_rect.left + int(0.1 * b), hat_rect.bottom - int(0.12 * b), hat_rect.width - int(0.2 * b), int(0.1 * b)), border_radius=1)

            # 모자 위 고글 (올려져 있음)
            for side in [-1, 1]:
                raised_goggle_x = head_rect.centerx + side * int(0.22 * b)
                raised_goggle_y = head_rect.top + int(0.05 * b)
                pygame.draw.ellipse(screen, p["copper_dark"],
                                  (raised_goggle_x - int(0.2 * b), raised_goggle_y - int(0.08 * b), int(0.4 * b), int(0.3 * b)))
                pygame.draw.ellipse(screen, p["copper"],
                                  (raised_goggle_x - int(0.18 * b), raised_goggle_y - int(0.06 * b), int(0.36 * b), int(0.26 * b)))
                pygame.draw.ellipse(screen, p["eye"],
                                  (raised_goggle_x - int(0.12 * b), raised_goggle_y - int(0.02 * b), int(0.24 * b), int(0.18 * b)))

        # === 증기 효과 (더 역동적) ===
        steam_base_x = cx + int(2.0 * b) + lean_offset
        steam_base_y = torso_y + int(0.3 * b)
        for burst in range(2):
            burst_offset = burst * int(0.5 * b)
            for i in range(5):
                sx = steam_base_x + int(math.sin(self.time * 6 + i + burst) * 0.2 * b)
                sy = steam_base_y - burst_offset - i * int(0.22 * b) - int((self.time * 2.5) % 1 * 0.4 * b)
                steam_size = max(1, int((0.18 - i * 0.03) * b))
                steam_alpha = max(0, int(120 - i * 25 - ((self.time * 2.5) % 1) * 50))

                if steam_size > 0 and steam_alpha > 0:
                    steam_surf = pygame.Surface((steam_size * 3, steam_size * 3), pygame.SRCALPHA)
                    steam_color = p["steam_hot"] if i < 2 else p["steam"]
                    pygame.draw.circle(steam_surf, (*steam_color, steam_alpha), (steam_size * 3 // 2, steam_size * 3 // 2), steam_size)
                    screen.blit(steam_surf, (sx - steam_size * 3 // 2, sy - steam_size * 3 // 2))

    # =========================================================================
    # 쿠로카게 - 그림자 닌자 (어둠 속에서 나타나는 암살자)
    # =========================================================================
    def _draw_kurokage(self, screen, cx, cy, b, color, show_back, anim):
        """쿠로카게 - 그림자 닌자 (빠르고 은밀한 닌자 암살자) [고퀄리티 버전]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        left_arm_swing = anim.get("left_arm_swing", 0)
        right_arm_swing = anim.get("right_arm_swing", 0)
        # 발토르 스타일 다리/어깨 애니메이션
        left_leg_sway = anim.get("left_leg_sway", 0)
        right_leg_sway = anim.get("right_leg_sway", 0)
        left_leg_lift = anim.get("left_leg", 0)
        right_leg_lift = anim.get("right_leg", 0)
        shoulder_bob = anim.get("shoulder_bob", 0)
        left_shoulder = anim.get("left_shoulder", 0)
        right_shoulder = anim.get("right_shoulder", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2.5 * b)
        lean_offset = int(lean * 2.5 * b)

        # 고급 컬러 팔레트
        p = {
            "cloth": color,
            "cloth_light": tuple(min(255, c + 25) for c in color),
            "cloth_mid": tuple(min(255, c + 12) for c in color),
            "cloth_dark": tuple(max(0, c - 25) for c in color),
            "cloth_shadow": tuple(max(0, c - 45) for c in color),
            "skin": (200, 180, 160),
            "skin_shadow": (160, 140, 120),
            "eye": (220, 40, 40),
            "eye_bright": (255, 80, 80),
            "eye_glow": (255, 100, 100),
            "eye_core": (255, 200, 200),
            "metal": (90, 90, 110),
            "metal_light": (150, 150, 175),
            "metal_bright": (190, 190, 210),
            "metal_dark": (60, 60, 80),
            "scarf": (35, 35, 55),
            "scarf_light": (55, 50, 75),
            "scarf_flow": (70, 60, 95),
            "shadow": (15, 15, 30),
            "shadow_deep": (8, 8, 20),
            "shuriken": (170, 170, 195),
            "shuriken_edge": (220, 220, 240),
            "chakra": (120, 80, 180),  # 차크라/닌술 에너지
            "chakra_glow": (160, 100, 220),
            "smoke": (40, 40, 55),
        }

        # === 그림자 오라 (닌술 에너지) ===
        shadow_pulse = math.sin(self.time * 3) * 0.15 + 0.85
        aura_size = int(5.5 * b * shadow_pulse)
        aura_surf = pygame.Surface((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
        # 다중 레이어 그림자 오라
        for i in range(4):
            layer_size = aura_size - i * int(0.4 * b)
            alpha = 25 - i * 5
            pygame.draw.ellipse(aura_surf, (*p["shadow"], alpha),
                              (aura_size - layer_size, aura_size - layer_size + int(0.5 * b),
                               layer_size * 2, int(layer_size * 1.6)))
        screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - int(1.5 * b)))

        # === 그림자 파티클 (연기처럼 피어오름) ===
        for i in range(6):
            particle_phase = (self.time * 2 + i * 1.2) % 4
            particle_y = torso_y + int(2.5 * b) - int(particle_phase * 0.8 * b)
            particle_x = cx + lean_offset + int(math.sin(self.time * 3 + i * 1.5) * 0.8 * b)
            particle_alpha = int(60 * (1 - particle_phase / 4))
            particle_size = int(0.3 * b * (1 - particle_phase / 6))
            if particle_size > 0 and particle_alpha > 0:
                ps = pygame.Surface((particle_size * 2, particle_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(ps, (*p["smoke"], particle_alpha), (particle_size, particle_size), particle_size)
                screen.blit(ps, (particle_x - particle_size, particle_y - particle_size))

        # === 스카프 (다중 레이어 펄럭임) ===
        scarf_wave = math.sin(self.time * 4) * 0.35
        scarf_wave2 = math.sin(self.time * 5 + 1) * 0.25
        # 스카프 레이어 1 (뒤)
        scarf_back = [
            (cx + int(0.25 * b) + lean_offset, torso_y - int(0.85 * b)),
            (cx + int(0.9 * b) + lean_offset, torso_y - int(0.55 * b)),
            (cx + int(2.3 * b) + lean_offset + int(scarf_wave * 1.2 * b), torso_y + int(0.7 * b) + int(wave * 0.35 * b)),
            (cx + int(2.1 * b) + lean_offset + int(scarf_wave * b), torso_y + int(1.3 * b) + int(wave * 0.45 * b)),
            (cx + int(1.6 * b) + lean_offset + int(scarf_wave2 * 0.6 * b), torso_y + int(0.9 * b) + int(wave * 0.3 * b)),
            (cx + int(0.55 * b) + lean_offset, torso_y - int(0.35 * b)),
        ]
        pygame.draw.polygon(screen, p["scarf"], scarf_back)
        # 스카프 레이어 2 (앞)
        scarf_front = [
            (cx + int(0.3 * b) + lean_offset, torso_y - int(0.75 * b)),
            (cx + int(0.75 * b) + lean_offset, torso_y - int(0.45 * b)),
            (cx + int(1.9 * b) + lean_offset + int(scarf_wave * 0.9 * b), torso_y + int(0.55 * b) + int(wave * 0.3 * b)),
            (cx + int(1.7 * b) + lean_offset + int(scarf_wave * 0.7 * b), torso_y + int(1.05 * b) + int(wave * 0.4 * b)),
            (cx + int(0.6 * b) + lean_offset, torso_y - int(0.25 * b)),
        ]
        pygame.draw.polygon(screen, p["scarf_light"], scarf_front)
        pygame.draw.polygon(screen, p["scarf_flow"], scarf_front, 1)
        # 스카프 주름선
        for i in range(3):
            fold_t = 0.3 + i * 0.25
            fx = int(scarf_front[1][0] + (scarf_front[2][0] - scarf_front[1][0]) * fold_t)
            fy = int(scarf_front[1][1] + (scarf_front[2][1] - scarf_front[1][1]) * fold_t)
            pygame.draw.circle(screen, p["scarf"], (fx, fy), max(1, int(0.08 * b)))

        # === 다리 (닌자 스타일 + 디테일) - 발토르 스타일 스윙 ===
        hip_y = torso_y + int(1.8 * b)
        for side in [-1, 1]:
            # 발토르 스타일 다리 움직임
            current_leg_sway = left_leg_sway if side == -1 else right_leg_sway
            current_leg_lift = left_leg_lift if side == -1 else right_leg_lift
            leg_sway_x = int(current_leg_sway * 0.5 * b)
            leg_lift_y = int(current_leg_lift * 0.25 * b)
            thigh_x = cx + side * int(0.4 * b) + lean_offset + leg_sway_x
            # 허벅지 (다중 레이어)
            thigh_rect = pygame.Rect(thigh_x - int(0.38 * b), hip_y - leg_lift_y, int(0.76 * b), int(1.55 * b))
            pygame.draw.rect(screen, p["cloth_shadow"], thigh_rect, border_radius=3)
            pygame.draw.rect(screen, p["cloth"], thigh_rect.inflate(-2, -2), border_radius=2)
            pygame.draw.rect(screen, p["cloth_light"],
                           pygame.Rect(thigh_rect.left + 2, thigh_rect.top + 2, int(0.25 * b), thigh_rect.height - 4),
                           border_radius=1)
            # 밴디지/붕대 (더 세밀하게)
            for i in range(4):
                band_y = thigh_rect.top + int(0.15 * b) + i * int(0.35 * b)
                pygame.draw.line(screen, p["cloth_mid"], (thigh_rect.left + 1, band_y),
                               (thigh_rect.right - 1, band_y), 2)
                pygame.draw.line(screen, p["cloth_light"], (thigh_rect.left + 1, band_y + 1),
                               (thigh_rect.right - 1, band_y + 1), 1)
            # 정강이 보호대
            shin_rect = pygame.Rect(thigh_x - int(0.3 * b), thigh_rect.bottom - int(0.3 * b), int(0.6 * b), int(0.5 * b))
            pygame.draw.rect(screen, p["metal_dark"], shin_rect, border_radius=2)
            pygame.draw.rect(screen, p["metal"], shin_rect.inflate(-2, -2), border_radius=1)
            pygame.draw.line(screen, p["metal_light"], (shin_rect.left + 2, shin_rect.top + 2),
                           (shin_rect.right - 2, shin_rect.top + 2), 1)
            # 타비 (갈라진 신발 - 더 세밀)
            tabi_rect = pygame.Rect(thigh_x - int(0.4 * b), shin_rect.bottom - 2, int(0.8 * b), int(0.55 * b))
            pygame.draw.rect(screen, p["cloth_shadow"], tabi_rect, border_radius=2)
            pygame.draw.rect(screen, p["cloth_dark"], tabi_rect.inflate(-2, -1), border_radius=2)
            # 갈라진 발가락 + 디테일
            pygame.draw.line(screen, p["shadow"], (tabi_rect.centerx, tabi_rect.bottom - 3),
                           (tabi_rect.centerx, tabi_rect.bottom + int(0.18 * b)), 2)
            # 발가락 라인
            pygame.draw.arc(screen, p["cloth_mid"],
                          (tabi_rect.left + 2, tabi_rect.bottom - int(0.15 * b), int(0.35 * b), int(0.2 * b)),
                          0, math.pi, 1)
            pygame.draw.arc(screen, p["cloth_mid"],
                          (tabi_rect.right - int(0.37 * b), tabi_rect.bottom - int(0.15 * b), int(0.35 * b), int(0.2 * b)),
                          0, math.pi, 1)

        # === 몸통 (닌자 상의 - 고급 디테일) ===
        chest_w, chest_h = int(2.5 * b), int(1.9 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset, torso_y - int(0.25 * b), chest_w, chest_h)
        # 기본 옷 레이어
        pygame.draw.rect(screen, p["cloth_shadow"], chest_rect, border_radius=int(0.35 * b))
        pygame.draw.rect(screen, p["cloth"], chest_rect.inflate(-2, -2), border_radius=int(0.3 * b))
        # 옷 주름/하이라이트
        pygame.draw.rect(screen, p["cloth_light"],
                        pygame.Rect(chest_rect.left + int(0.15 * b), chest_rect.top + int(0.1 * b),
                                   int(0.4 * b), chest_rect.height - int(0.2 * b)), border_radius=2)
        # X자 붕대 (더 두껍고 세밀)
        bandage_width = max(3, int(0.12 * b))
        pygame.draw.line(screen, p["cloth_dark"],
                        (chest_rect.left + int(0.25 * b), chest_rect.top + int(0.25 * b)),
                        (chest_rect.right - int(0.25 * b), chest_rect.bottom - int(0.15 * b)), bandage_width)
        pygame.draw.line(screen, p["cloth_mid"],
                        (chest_rect.left + int(0.27 * b), chest_rect.top + int(0.22 * b)),
                        (chest_rect.right - int(0.27 * b), chest_rect.bottom - int(0.18 * b)), 1)
        pygame.draw.line(screen, p["cloth_dark"],
                        (chest_rect.right - int(0.25 * b), chest_rect.top + int(0.25 * b)),
                        (chest_rect.left + int(0.25 * b), chest_rect.bottom - int(0.15 * b)), bandage_width)
        pygame.draw.line(screen, p["cloth_mid"],
                        (chest_rect.right - int(0.27 * b), chest_rect.top + int(0.22 * b)),
                        (chest_rect.left + int(0.27 * b), chest_rect.bottom - int(0.18 * b)), 1)
        # 가슴 포켓/도구 주머니
        pocket_rect = pygame.Rect(chest_rect.left + int(0.2 * b), chest_rect.centery, int(0.45 * b), int(0.35 * b))
        pygame.draw.rect(screen, p["cloth_dark"], pocket_rect, border_radius=1)
        pygame.draw.rect(screen, p["cloth_mid"], pocket_rect, 1, border_radius=1)

        # 허리띠 + 수리검 홀더 (업그레이드)
        belt_rect = pygame.Rect(cx - int(1.25 * b) + lean_offset, chest_rect.bottom - 2, int(2.5 * b), int(0.55 * b))
        pygame.draw.rect(screen, p["cloth_shadow"], belt_rect, border_radius=2)
        pygame.draw.rect(screen, p["cloth_dark"], belt_rect.inflate(-2, -1), border_radius=1)
        # 벨트 버클
        buckle_rect = pygame.Rect(belt_rect.centerx - int(0.2 * b), belt_rect.top + 1, int(0.4 * b), belt_rect.height - 2)
        pygame.draw.rect(screen, p["metal"], buckle_rect, border_radius=1)
        pygame.draw.rect(screen, p["metal_light"], buckle_rect, 1, border_radius=1)
        # 도구 파우치
        for side in [-1, 1]:
            pouch_x = belt_rect.centerx + side * int(0.55 * b)
            pouch_rect = pygame.Rect(pouch_x - int(0.18 * b), belt_rect.top + 2, int(0.36 * b), belt_rect.height - 3)
            pygame.draw.rect(screen, p["cloth_shadow"], pouch_rect, border_radius=1)

        # 수리검 (회전 + 글로우 효과)
        shuriken_x = belt_rect.right - int(0.45 * b)
        shuriken_y = belt_rect.centery
        shuriken_rotation = self.time * 3
        # 수리검 글로우
        shuriken_glow = pygame.Surface((int(0.8 * b), int(0.8 * b)), pygame.SRCALPHA)
        pygame.draw.circle(shuriken_glow, (*p["metal_light"], 30), (int(0.4 * b), int(0.4 * b)), int(0.35 * b))
        screen.blit(shuriken_glow, (shuriken_x - int(0.4 * b), shuriken_y - int(0.4 * b)), special_flags=pygame.BLEND_ADD)
        # 수리검 날 (4개)
        for i in range(4):
            angle = i * math.pi / 2 + shuriken_rotation
            sx = shuriken_x + int(math.cos(angle) * 0.28 * b)
            sy = shuriken_y + int(math.sin(angle) * 0.28 * b)
            # 각 날
            pygame.draw.line(screen, p["shuriken"], (shuriken_x, shuriken_y), (sx, sy), max(2, int(0.08 * b)))
            pygame.draw.line(screen, p["shuriken_edge"], (shuriken_x, shuriken_y), (sx, sy), 1)
        # 수리검 중앙
        pygame.draw.circle(screen, p["metal"], (shuriken_x, shuriken_y), max(2, int(0.12 * b)))
        pygame.draw.circle(screen, p["metal_light"], (shuriken_x, shuriken_y), max(1, int(0.08 * b)))

        # === 어깨 보호대 (더 세밀) ===
        for side in [-1, 1]:
            shoulder_rect = pygame.Rect(
                cx + side * int(0.95 * b) + lean_offset - int(0.45 * b),
                torso_y - int(0.3 * b),
                int(0.9 * b), int(0.65 * b)
            )
            pygame.draw.ellipse(screen, p["metal_dark"], shoulder_rect)
            pygame.draw.ellipse(screen, p["metal"], shoulder_rect.inflate(-2, -2))
            pygame.draw.ellipse(screen, p["metal_light"], shoulder_rect.inflate(-4, -4), 1)
            # 어깨 리벳
            for i in range(2):
                rivet_x = shoulder_rect.left + int(0.25 * b) + i * int(0.4 * b)
                pygame.draw.circle(screen, p["metal_bright"], (rivet_x, shoulder_rect.centery), max(1, int(0.06 * b)))

        # === 팔 + 쿠나이 (자연스러운 교대 모션 + 어깨 들썩임) ===
        for side in [-1, 1]:
            current_swing = left_arm_swing if side == -1 else right_arm_swing
            arm_swing = int(current_swing * 3 * b)
            shoulder_bob_offset = int(shoulder_bob * 0.3 * b)
            shoulder = (cx + side * int(1.05 * b) + lean_offset, torso_y + int(0.1 * b) + shoulder_bob_offset)
            elbow = (int(shoulder[0] + side * int(0.55 * b) + arm_swing * 0.5), torso_y + int(0.65 * b))
            wrist = (int(elbow[0] + side * int(0.45 * b) + arm_swing * 0.3), torso_y + int(1.25 * b))

            # 상완
            pygame.draw.line(screen, p["cloth_shadow"], shoulder, elbow, max(3, int(0.5 * b)))
            pygame.draw.line(screen, p["cloth"], shoulder, elbow, max(2, int(0.42 * b)))
            # 팔 붕대 (여러 줄)
            arm_len = math.sqrt((elbow[0] - shoulder[0])**2 + (elbow[1] - shoulder[1])**2)
            for i in range(3):
                t = 0.2 + i * 0.25
                bx = int(shoulder[0] + (elbow[0] - shoulder[0]) * t)
                by = int(shoulder[1] + (elbow[1] - shoulder[1]) * t)
                pygame.draw.circle(screen, p["cloth_light"], (bx, by), max(1, int(0.08 * b)))
            # 전완
            pygame.draw.line(screen, p["cloth_shadow"], elbow, wrist, max(3, int(0.45 * b)))
            pygame.draw.line(screen, p["cloth_dark"], elbow, wrist, max(2, int(0.38 * b)))
            # 손목 보호대
            pygame.draw.circle(screen, p["metal_dark"], wrist, max(3, int(0.3 * b)))
            pygame.draw.circle(screen, p["metal"], wrist, max(2, int(0.25 * b)))
            pygame.draw.circle(screen, p["skin"], wrist, max(2, int(0.18 * b)))

            # 쿠나이 (오른손) - 차크라 에너지 추가
            if side == 1:
                kunai_handle = wrist
                kunai_tip = (int(wrist[0] + int(0.75 * b)), int(wrist[1] + int(0.25 * b)))
                # 쿠나이 글로우
                kunai_glow = pygame.Surface((int(1.2 * b), int(0.6 * b)), pygame.SRCALPHA)
                pygame.draw.ellipse(kunai_glow, (*p["chakra_glow"], 35), (0, 0, int(1.2 * b), int(0.6 * b)))
                screen.blit(kunai_glow, (wrist[0] - int(0.1 * b), wrist[1] - int(0.15 * b)), special_flags=pygame.BLEND_ADD)
                # 쿠나이 본체
                pygame.draw.line(screen, p["metal_dark"], kunai_handle, kunai_tip, max(2, int(0.12 * b)))
                pygame.draw.line(screen, p["metal"], kunai_handle, kunai_tip, max(1, int(0.08 * b)))
                # 쿠나이 날
                blade_points = [
                    kunai_tip,
                    (kunai_tip[0] - int(0.15 * b), kunai_tip[1] - int(0.08 * b)),
                    (kunai_tip[0] - int(0.12 * b), kunai_tip[1]),
                    (kunai_tip[0] - int(0.15 * b), kunai_tip[1] + int(0.08 * b)),
                ]
                pygame.draw.polygon(screen, p["metal_light"], blade_points)
                pygame.draw.polygon(screen, p["metal_bright"], blade_points, 1)
                # 쿠나이 손잡이 끝 고리
                ring_x = int(wrist[0] - int(0.1 * b))
                ring_y = int(wrist[1] - int(0.05 * b))
                pygame.draw.circle(screen, p["metal"], (ring_x, ring_y), max(2, int(0.1 * b)), 1)

        # === 머리 (닌자 마스크 - 고퀄리티) ===
        head_y = torso_y - int(2.7 * b)
        head_w, head_h = int(2.1 * b), int(1.9 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        # 머리 (두건) - 다중 레이어
        pygame.draw.ellipse(screen, p["cloth_shadow"], head_rect.inflate(2, 2))
        pygame.draw.ellipse(screen, p["cloth"], head_rect)
        pygame.draw.ellipse(screen, p["cloth_light"], head_rect.inflate(-int(0.25 * b), -int(0.2 * b)))
        # 두건 주름선
        for i in range(3):
            fold_angle = -0.3 + i * 0.2
            fx1 = head_rect.left + int(0.2 * b)
            fy1 = int(head_rect.centery + fold_angle * head_h * 0.3)
            fx2 = head_rect.right - int(0.2 * b)
            fy2 = int(head_rect.centery + fold_angle * head_h * 0.3 + int(0.1 * b))
            pygame.draw.line(screen, p["cloth_mid"], (fx1, fy1), (fx2, fy2), 1)

        if show_back:
            # 뒷모습 - 두건 뒷면
            pygame.draw.ellipse(screen, p["cloth_dark"], head_rect.inflate(-int(0.15 * b), -int(0.15 * b)))
            # 두건 묶음 (여러 줄기)
            for i in range(3):
                tail_base_y = head_rect.bottom - int(0.15 * b)
                tail_end_y = tail_base_y + int(0.45 * b) + i * int(0.2 * b)
                tail_wave = math.sin(self.time * 5 + i * 0.8) * 0.25
                tail_x_offset = (i - 1) * int(0.15 * b)
                tail_color = p["cloth"] if i == 1 else p["cloth_dark"]
                pygame.draw.line(screen, tail_color,
                               (head_rect.centerx + tail_x_offset, tail_base_y),
                               (head_rect.centerx + tail_x_offset + int(tail_wave * b), tail_end_y), 2)
        else:
            # 정면 - 눈만 보이는 마스크
            # 이마 보호대 (더 세밀)
            headband_rect = pygame.Rect(head_rect.left + int(0.12 * b), head_rect.centery - int(0.35 * b),
                                        head_rect.width - int(0.24 * b), int(0.45 * b))
            pygame.draw.rect(screen, p["metal_dark"], headband_rect, border_radius=2)
            pygame.draw.rect(screen, p["metal"], headband_rect.inflate(-2, -2), border_radius=2)
            pygame.draw.rect(screen, p["metal_light"], headband_rect.inflate(-4, -4), 1, border_radius=2)
            # 닌자 마을 문양 (더 정교)
            emblem_x, emblem_y = headband_rect.centerx, headband_rect.centery
            emblem_r = max(3, int(0.18 * b))
            pygame.draw.circle(screen, p["shadow_deep"], (emblem_x, emblem_y), emblem_r)
            pygame.draw.circle(screen, p["metal_dark"], (emblem_x, emblem_y), emblem_r - 1)
            # 소용돌이 문양
            for i in range(3):
                angle = i * 2 * math.pi / 3 + self.time
                sx = emblem_x + int(math.cos(angle) * 0.08 * b)
                sy = emblem_y + int(math.sin(angle) * 0.08 * b)
                pygame.draw.line(screen, p["metal_light"], (emblem_x, emblem_y), (sx, sy), 1)

            # 눈 (날카로운 눈빛 - 다중 레이어 글로우)
            eye_y = head_rect.centery + int(0.08 * b)
            for side in [-1, 1]:
                eye_x = head_rect.centerx + side * int(0.35 * b)
                # 눈 배경 (마스크 구멍) - 깊은 그림자
                pygame.draw.ellipse(screen, p["shadow_deep"],
                                  (eye_x - int(0.25 * b), eye_y - int(0.12 * b), int(0.5 * b), int(0.24 * b)))
                pygame.draw.ellipse(screen, p["shadow"],
                                  (eye_x - int(0.22 * b), eye_y - int(0.1 * b), int(0.44 * b), int(0.2 * b)))
                # 붉은 눈 (다중 레이어)
                pygame.draw.ellipse(screen, p["eye"],
                                  (eye_x - int(0.16 * b), eye_y - int(0.07 * b), int(0.32 * b), int(0.14 * b)))
                pygame.draw.ellipse(screen, p["eye_bright"],
                                  (eye_x - int(0.1 * b), eye_y - int(0.04 * b), int(0.2 * b), int(0.08 * b)))
                # 눈 하이라이트
                pygame.draw.circle(screen, p["eye_core"],
                                 (eye_x + int(0.05 * b), eye_y - int(0.02 * b)), max(1, int(0.04 * b)))
                # 눈 글로우 (다중 레이어)
                for glow_i in range(3):
                    glow_size = int((0.4 + glow_i * 0.15) * b)
                    glow_alpha = 45 - glow_i * 12
                    glow_surf = pygame.Surface((glow_size, int(glow_size * 0.6)), pygame.SRCALPHA)
                    pygame.draw.ellipse(glow_surf, (*p["eye_glow"], glow_alpha), (0, 0, glow_size, int(glow_size * 0.6)))
                    screen.blit(glow_surf, (eye_x - glow_size // 2, eye_y - int(glow_size * 0.3)), special_flags=pygame.BLEND_ADD)

            # 마스크 (코, 입 가림) - 더 입체적
            mask_points = [
                (head_rect.centerx - int(0.55 * b), eye_y + int(0.18 * b)),
                (head_rect.centerx + int(0.55 * b), eye_y + int(0.18 * b)),
                (head_rect.centerx + int(0.35 * b), head_rect.bottom - int(0.12 * b)),
                (head_rect.centerx - int(0.35 * b), head_rect.bottom - int(0.12 * b)),
            ]
            pygame.draw.polygon(screen, p["scarf"], mask_points)
            # 마스크 하이라이트
            mask_highlight = [
                (head_rect.centerx - int(0.45 * b), eye_y + int(0.22 * b)),
                (head_rect.centerx - int(0.1 * b), eye_y + int(0.22 * b)),
                (head_rect.centerx - int(0.15 * b), head_rect.bottom - int(0.2 * b)),
                (head_rect.centerx - int(0.35 * b), head_rect.bottom - int(0.18 * b)),
            ]
            pygame.draw.polygon(screen, p["scarf_light"], mask_highlight)
            # 마스크 주름 (더 많이)
            for i in range(3):
                fold_y = eye_y + int(0.28 * b) + i * int(0.18 * b)
                pygame.draw.line(screen, p["scarf_flow"],
                               (head_rect.centerx - int(0.4 * b), fold_y),
                               (head_rect.centerx + int(0.4 * b), fold_y), 1)
            # 마스크 가장자리 스티치
            for i in range(4):
                stitch_y = eye_y + int(0.2 * b) + i * int(0.15 * b)
                for side in [-1, 1]:
                    stitch_x = head_rect.centerx + side * int(0.48 * b) - side * i * int(0.03 * b)
                    pygame.draw.circle(screen, p["cloth_dark"], (stitch_x, stitch_y), 1)

        # === 그림자 효과 (발 아래) - 더 풍부 ===
        shadow_y = cy + int(2.85 * b)
        shadow_w = int(1.8 * b) + int(abs(wave) * 0.35 * b)
        shadow_h = int(0.4 * b)
        shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
        # 다중 레이어 그림자
        pygame.draw.ellipse(shadow_surf, (*p["shadow_deep"], 50), (0, 0, shadow_w, shadow_h))
        pygame.draw.ellipse(shadow_surf, (*p["shadow"], 70),
                          (int(0.1 * b), int(0.05 * b), shadow_w - int(0.2 * b), shadow_h - int(0.1 * b)))
        screen.blit(shadow_surf, (cx - shadow_w // 2 + lean_offset, shadow_y))

        # === 잔상 효과 (고속 이동 느낌) ===
        if abs(wave) > 0.3:
            afterimage_alpha = int(abs(wave) * 40)
            afterimage_offset = -int(wave * 0.5 * b)
            afterimage_surf = pygame.Surface((int(2.5 * b), int(5 * b)), pygame.SRCALPHA)
            # 실루엣만 그리기 (간략화)
            pygame.draw.ellipse(afterimage_surf, (*p["shadow"], afterimage_alpha),
                              (int(0.25 * b), 0, int(2 * b), int(1.8 * b)))  # 머리
            pygame.draw.rect(afterimage_surf, (*p["shadow"], afterimage_alpha),
                           (int(0.15 * b), int(1.5 * b), int(2.2 * b), int(2 * b)), border_radius=3)  # 몸통
            screen.blit(afterimage_surf,
                       (cx - int(1.25 * b) + lean_offset + afterimage_offset, head_y - int(0.2 * b)))

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
