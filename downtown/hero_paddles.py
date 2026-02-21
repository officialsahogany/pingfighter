# -*- coding: utf-8 -*-
"""
콜로세움 영웅 패들 렌더러 - 고퀄리티 버전
스매셔/발토르/코만도 수준의 디테일한 캐릭터 렌더링
"""

import pygame
import math
from typing import Dict, Tuple, Optional
_sin = math.sin
_cos = math.cos


class HeroPaddleRenderer:
    """고퀄리티 영웅 패들 렌더러 - 관절 애니메이션 포함"""

    def __init__(self):
        self.hero_states: Dict[str, dict] = {}
        self.time = 0.0
        self._surface_cache: Dict[Tuple[int, int], pygame.Surface] = {}

    def _get_surface(self, w: int, h: int) -> pygame.Surface:
        """크기별 SRCALPHA Surface 캐시 재사용 (매 프레임 재생성 방지)"""
        w = max(4, ((w + 3) // 4) * 4)
        h = max(4, ((h + 3) // 4) * 4)
        key = (w, h)
        if key not in self._surface_cache:
            self._surface_cache[key] = pygame.Surface((w, h), pygame.SRCALPHA)
        else:
            self._surface_cache[key].fill((0, 0, 0, 0))
        return self._surface_cache[key]

    def update(self, dt: float):
        """애니메이션 업데이트"""
        self.time += dt
        # 무기 스윙 타이머 감쇠
        for state in self.hero_states.values():
            if state.get("weapon_swing_timer", 0) > 0:
                state["weapon_swing_timer"] = max(0, state["weapon_swing_timer"] - dt)

    def update_movement(self, hero_id: str, current_x: float, dt: float):
        """이동 상태 업데이트 - 관절 애니메이션 포함 (발토르 스타일 강화 + 옆모습 전환)"""
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
                "move_dir": 0.0,      # 이동 방향 (-1=좌, 0=정지, 1=우)
                "side_blend": 0.0,    # 옆모습 전환 비율 (0=정면, 1=완전 옆모습)
                "weapon_swing_timer": 0.0,     # 남은 스윙 시간(초)
                "weapon_swing_duration": 0.35, # 전체 스윙 시간
            }

        state = self.hero_states[hero_id]
        # 속도 계산 (부드럽게)
        velocity = (current_x - state["last_x"]) / max(dt, 0.001)
        state["velocity"] = velocity * 0.3 + state["velocity"] * 0.7  # 더 부드러운 반응

        # 기울기 (이동 방향) - 완화된 조정
        target_lean = max(-1.0, min(1.0, state["velocity"] / 200.0))
        state["lean"] = state["lean"] * 0.85 + target_lean * 0.15

        # 옆모습 전환 추적 (이동 방향 + 블렌드)
        move_speed = abs(state["velocity"])
        if move_speed > 25:
            target_dir = 1.0 if state["velocity"] > 0 else -1.0
        else:
            target_dir = 0.0
        state["move_dir"] = state["move_dir"] * 0.82 + target_dir * 0.18
        # side_blend: 속도에 따라 0(정면)~1(완전 옆모습) 부드럽게 전환
        target_side = min(1.0, move_speed / 160.0)
        state["side_blend"] = state["side_blend"] * 0.88 + target_side * 0.12

        # 걷기 애니메이션 (속도에 비례, 옆걸음 시 더 역동적)
        side_factor = state["side_blend"]
        if move_speed > 5:
            # 애니메이션 속도 - 옆걸음 시 더 빠르게 (실제 걷는 느낌)
            step_speed = 12.0 + side_factor * 4.0  # 12~16
            state["step_phase"] += dt * step_speed
            state["shoulder_phase"] += dt * step_speed
            # 어깨 들썩임
            speed_factor = min(1.0, move_speed / 150.0)
            state["body_bob"] = _sin(state["step_phase"] * 2) * speed_factor * (0.3 + side_factor * 0.25)
            # 팔 스윙 - 자연스러운 범위 내
            arm_amp = min(1.0, move_speed / 100.0) * (1.0 + side_factor * 0.25)
            state["arm_swing"] = _sin(state["step_phase"]) * arm_amp
            # 머리 미세 흔들림
            state["head_tilt"] = _sin(state["step_phase"] * 1.5) * 0.3 * speed_factor
        else:
            # 정지 시 부드럽게 감쇠
            state["body_bob"] *= 0.9
            state["arm_swing"] *= 0.9
            state["head_tilt"] *= 0.9

        # 벤시 전용: 걷기 대신 부유 모션 (날아다니는 느낌)
        if hero_id == "banshee":
            state["body_bob"] *= 0.15  # 걷기 바운스 거의 제거
            state["arm_swing"] *= 0.25  # 유령은 팔을 크게 안 흔듦
            state["head_tilt"] *= 0.3   # 머리 흔들림 최소화

        # 원숭이왕 전용: 어슬렁거리는 원숭이 걸음 (무게감 있는 좌우 흔들림)
        # 이동 중에만 증폭 (정지 시 0.9 감쇠와 곱해지면 1.44배로 발산하므로)
        if hero_id == "monkeyking" and move_speed > 5:
            state["body_bob"] *= 1.8   # 강한 상하 바운스 (쿵쿵 걷는 느낌)
            state["arm_swing"] *= 1.6  # 긴 팔 크게 흔들기
            state["head_tilt"] *= 1.5  # 머리도 어슬렁 흔들림

        state["last_x"] = current_x

    def _get_state(self, hero_id: str) -> dict:
        """영웅 상태 가져오기"""
        if hero_id not in self.hero_states:
            self.hero_states[hero_id] = {
                "last_x": 0, "velocity": 0, "lean": 0, "step_phase": 0,
                "shoulder_phase": 0, "arm_swing": 0, "head_tilt": 0, "body_bob": 0,
                "move_dir": 0.0, "side_blend": 0.0,
                "weapon_swing_timer": 0.0, "weapon_swing_duration": 0.25,
            }
        return self.hero_states[hero_id]

    def trigger_weapon_swing(self, hero_id: str, duration: float = 0.25):
        """공 타격 시 무기 휘두르기 애니메이션 트리거"""
        state = self._get_state(hero_id)
        if state.get("weapon_swing_timer", 0) <= 0:
            state["weapon_swing_timer"] = duration
            state["weapon_swing_duration"] = duration

    def set_arm_raise_hold(self, hero_id: str, hold: bool):
        """스킬 시전 중 팔 올린 상태 유지 (연화 전용)"""
        state = self._get_state(hero_id)
        state["arm_raise_hold"] = hold

    def set_staff_hold_outward(self, hero_id: str, hold: bool):
        """스킬 시전 중 지팡이를 바깥쪽으로 펼친 상태 유지 (키르케 중력조작 전용)"""
        state = self._get_state(hero_id)
        state["staff_hold_outward"] = hold

    def set_roar_pose(self, hero_id: str, active: bool):
        """야생의 포효 중 양팔 벌리고 무릎 굽힌 포즈 (원숭이왕 전용)"""
        state = self._get_state(hero_id)
        state["roar_pose"] = active

    def _rotate_point(self, px, py, pivot_x, pivot_y, angle):
        """점 (px, py)을 pivot 기준으로 angle(라디안)만큼 회전"""
        dx, dy = px - pivot_x, py - pivot_y
        cos_a, sin_a = _cos(angle), _sin(angle)
        return (pivot_x + int(dx * cos_a - dy * sin_a),
                pivot_y + int(dx * sin_a + dy * cos_a))

    def _get_anim(self, state: dict) -> dict:
        """애니메이션 값 계산 (발토르 스타일 걷기 모션 + 옆걸음 강화)"""
        step = state.get("step_phase", 0)
        lean = state.get("lean", 0)
        arm_swing = state.get("arm_swing", 0)
        body_bob = state.get("body_bob", 0)
        head_tilt = state.get("head_tilt", 0)
        velocity = abs(state.get("velocity", 0))

        # 이동 중일 때 다리/팔 애니메이션 강화
        leg_intensity = min(1.0, velocity / 80.0) if velocity > 5 else 0

        # 옆모습 관련 값
        side_blend = state.get("side_blend", 0)
        move_dir = state.get("move_dir", 0)

        # === 옆걸음 강화: 자연스러운 범위 내에서 모션 증폭 ===
        # 팔 스윙 - 각도만 살짝 흔드는 수준 (길어지지 않도록 최소화)
        arm_intensity = arm_swing * (0.4 + leg_intensity * 0.3)

        # 다리 스윙 (보폭) - 적당히 강화
        stride_boost = 1.0 + side_blend * 0.5  # 최대 1.5배
        leg_sway = _sin(step) * leg_intensity * 0.8 * stride_boost
        left_leg_sway = -leg_sway
        right_leg_sway = leg_sway

        # 어깨 들썩임 - 소폭 강화
        shoulder_boost = 1.0 + side_blend * 0.25
        shoulder_bob = _sin(step * 2) * leg_intensity * 0.3 * shoulder_boost

        # 다리 들어올림 - 소폭 강화
        leg_lift_boost = 0.8 + leg_intensity * 0.5 + side_blend * 0.25

        # 몸통 상하 움직임 - 약간 강화 (걷는 무게감)
        bob_boost = 1.0 + side_blend * 0.2

        # 무기 스윙 각도 계산 (빠르게 휘두르고 천천히 복귀)
        swing_timer = state.get("weapon_swing_timer", 0)
        swing_dur = state.get("weapon_swing_duration", 0.25)
        if swing_timer > 0 and swing_dur > 0:
            progress = 1.0 - (swing_timer / swing_dur)
            # sqrt로 빠른 공격 → 느린 복귀 커브, 최대 ~40도
            weapon_swing_angle = _sin(math.sqrt(progress) * math.pi) * -0.7
            # 연화 양팔 올려치기 (즉각적 반응)
            # 0~15%: 빠르게 올리기, 15~35%: 짧게 유지, 35~55%: 내려치기, 55~100%: 복귀
            if progress < 0.15:
                arm_slam = -(progress / 0.15)
            elif progress < 0.35:
                arm_slam = -1.0
            elif progress < 0.55:
                t = (progress - 0.35) / 0.20
                arm_slam = -1.0 + t * 2.0
            else:
                t = (progress - 0.55) / 0.45
                arm_slam = 1.0 * (1.0 - t)
        else:
            weapon_swing_angle = 0.0
            arm_slam = 0.0

        # 스킬 시전 중 팔 올린 상태 유지 (연화 전용)
        if state.get("arm_raise_hold", False):
            arm_slam = -1.0

        # 키르케 중력조작 시전 중 지팡이를 바깥쪽으로 펼친 상태 유지
        if state.get("staff_hold_outward", False):
            weapon_swing_angle = 0.7  # 스윙 반대 방향 (바깥쪽)

        return {
            "wave": _sin(step) * (1.0 + leg_intensity * 0.3) * stride_boost,
            "lean": lean,
            "arm_swing": arm_swing,
            "left_arm_swing": -_sin(step) * arm_intensity,
            "right_arm_swing": _sin(step) * arm_intensity,
            "body_bob": body_bob * bob_boost,
            "head_tilt": head_tilt,
            # 다리 들어올림 (Y 방향)
            "left_leg": max(0, _sin(step)) * leg_lift_boost,
            "right_leg": max(0, -_sin(step)) * leg_lift_boost,
            # 다리 좌우 스윙 (X 방향)
            "left_leg_sway": left_leg_sway,
            "right_leg_sway": right_leg_sway,
            # 어깨 움직임
            "left_shoulder": _sin(step + 0.5) * (0.4 + leg_intensity * 0.3) * shoulder_boost,
            "right_shoulder": _sin(step - 0.5) * (0.4 + leg_intensity * 0.3) * shoulder_boost,
            "shoulder_bob": shoulder_bob,
            # 옆모습 전환
            "side_blend": side_blend,
            "move_dir": move_dir,
            # 무기 스윙
            "weapon_swing_angle": weapon_swing_angle,
            # 연화 양팔 올려치기
            "arm_slam": arm_slam,
            # 키르케 중력조작 지팡이 펼침
            "staff_hold_outward": state.get("staff_hold_outward", False),
            # 원숭이왕 포효 포즈
            "roar_pose": state.get("roar_pose", False),
        }

    def draw_hero_paddle(self, screen: pygame.Surface, hero_id: str,
                         x: float, y: float, width: int, height: int,
                         facing: str = "down", color: Tuple[int, int, int] = (200, 200, 200),
                         scale_mode: str = "paddle", stun_effect: bool = False,
                         electric_stun: bool = False):
        """
        영웅 패들 그리기
        facing="down": 정면 (아래를 바라봄, 얼굴이 보임) - 상단 영웅
        facing="up": 뒷모습 (위를 바라봄, 뒷통수가 보임) - 하단 영웅
        scale_mode="paddle": 투기장 모드 - 패들 크기에 맞게 캐릭터 축소
        scale_mode="preview": 미리보기 모드 - 기존 크기
        stun_effect: 대쉬 후딜 상태 (보라색 틴트 효과)
        electric_stun: 번개의 분노 감전 상태 (전기 틴트 + 경련 떨림)
        """
        import random as _rand
        # 번개 감전 상태: 전기 색상 틴트 + 경련 오프셋
        if electric_stun:
            t = pygame.time.get_ticks()
            # 빠른 불규칙 경련 (부르르 떨림) - 프레임마다 랜덤 + 고주파 사인 혼합
            tremor_x = _rand.randint(-3, 3) + int(2.0 * _sin(t * 0.07))
            tremor_y = _rand.randint(-2, 2) + int(1.5 * _cos(t * 0.09))
            x += tremor_x
            y += tremor_y
            # 전기 색상 틴트 (노란~하얀 깜빡임)
            flash = 0.5 + 0.5 * _sin(t * 0.03)
            r = min(255, int(color[0] * 0.4 + 255 * flash * 0.6))
            g = min(255, int(color[1] * 0.4 + 255 * flash * 0.5))
            b_color = min(255, int(color[2] * 0.3 + 200 * flash * 0.3))
            color = (r, g, b_color)
        # 후딜 상태일 때 색상 변경 (보라색 틴트)
        elif stun_effect:
            # 보라색 틴트 적용 (원래 색상에 보라색 혼합)
            pulse = 0.6 + 0.4 * _sin(pygame.time.get_ticks() * 0.02)
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
            # 이동 애니메이션 - 패들 모드 스케일링 (자연스러운 범위 내)
            side_blend = anim.get("side_blend", 0)
            move_dir = anim.get("move_dir", 0)
            # 팔/다리 기본 감쇠 + 이동 시 소폭 복원
            motion_scale = 0.5 + side_blend * 0.2  # 정지: 0.5, 이동: 최대 0.7
            anim = {
                "wave": anim["wave"] * motion_scale,
                "lean": anim["lean"] * 0.7,
                "arm_swing": anim["arm_swing"] * 0.6,
                "left_arm_swing": anim.get("left_arm_swing", 0) * motion_scale,
                "right_arm_swing": anim.get("right_arm_swing", 0) * motion_scale,
                "body_bob": 0,
                "head_tilt": anim["head_tilt"] * 0.3,
                "left_leg": anim["left_leg"] * motion_scale,
                "right_leg": anim["right_leg"] * motion_scale,
                "left_leg_sway": anim.get("left_leg_sway", 0) * motion_scale,
                "right_leg_sway": anim.get("right_leg_sway", 0) * motion_scale,
                "left_shoulder": anim["left_shoulder"] * 0.4,
                "right_shoulder": anim["right_shoulder"] * 0.4,
                "shoulder_bob": anim.get("shoulder_bob", 0) * 0.4,
                "side_blend": side_blend,
                "move_dir": move_dir,
                "weapon_swing_angle": anim.get("weapon_swing_angle", 0),
                "arm_slam": anim.get("arm_slam", 0),
            }
        else:
            # 기존 미리보기 모드 (크게 표시)
            b = max(3, width // 12)
            # UI/메뉴용 미리보기: lean, body_bob 감쇠 (캐릭터가 중심에서 벗어나지 않도록)
            # lean → 수평 드리프트, body_bob → 수직 드리프트 원인
            anim = dict(anim)
            anim["lean"] = anim.get("lean", 0) * 0.1
            anim["body_bob"] = 0

        cx = int(x)

        # Y 위치 보정 (캐릭터가 바닥에 붙도록)
        # 캐릭터 높이 = 약 6*b (머리~발), 중심(torso)은 cy에서 그려짐
        # 캐릭터 발 위치 = cy + 약 3*b
        if scale_mode == "paddle":
            # 축소 시에도 캐릭터 위치가 안정적으로 유지되도록 기준 오프셋 사용
            base_b = 8  # 기준 블록 크기 (스케일 1.0 기준)
            if facing == "down":
                # 상단 영웅: 패들 아래쪽에서 캐릭터 그리기
                # 축소 시에도 동일한 Y 오프셋 유지 (캐릭터가 사라지지 않도록)
                y_offset = int(3.5 * base_b)  # 고정 오프셋 (28px)
                cy = int(y) + y_offset
            else:
                # 하단 영웅: 패들 위쪽에 캐릭터 그리기
                y_offset = int(2.0 * base_b) - 30  # 고정 오프셋 (16px - 30px = -14px)
                cy = int(y) + y_offset
        else:
            cy = int(y)

        # 영웅 상태 플래그를 anim에 전달 (스킬 연동 등)
        anim['gatling_firing'] = state.get('gatling_firing', False)
        anim['gatling_recoil'] = state.get('gatling_recoil', 0)
        anim['gatling_mounting'] = state.get('gatling_mounting', False)
        anim['gatling_mount_progress'] = state.get('gatling_mount_progress', 0.0)
        anim['gatling_dismounting'] = state.get('gatling_dismounting', False)
        anim['gatling_dismount_progress'] = state.get('gatling_dismount_progress', 0.0)
        anim['gatling_aim_angle'] = state.get('gatling_aim_angle', None)

        # 영웅별 그리기 (팔/다리 동작으로 자연스러운 옆걸음 표현)
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
        aura_pulse = 0.7 + 0.3 * _sin(self.time * 4)
        for i in range(3):
            aura_size = int((2.5 + i * 0.5) * b * aura_pulse)
            aura_surf = self._get_surface(aura_size * 2, aura_size * 2)
            aura_alpha = int(25 - i * 8)
            pygame.draw.ellipse(aura_surf, (*p["aura"], aura_alpha), (0, 0, aura_size * 2, aura_size * 2))
            screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - aura_size + int(0.5 * b)), special_flags=pygame.BLEND_ADD)

        # === 다리 (하카마 스타일 - 디테일 강화) ===
        hip_y = torso_y + int(2.0 * b)
        # 하카마 넘실거림 - 무거운 천의 둔중한 관성
        side_blend = anim.get("side_blend", 0)
        move_dir = anim.get("move_dir", 0)
        hakama_inertia = -move_dir * side_blend * 0.45 * b  # 두꺼운 천: 관성 약간 약하게
        hakama_sway = _sin(self.time * 2.8) * side_blend * 0.25 * b  # 느린 출렁임 (무거운 천)
        hakama_wave_boost = 1.0 + side_blend * 1.5

        # 하카마 그림자
        hk_drift = int(hakama_inertia + hakama_sway)
        hakama_shadow = [
            (cx - int(1.25 * b) + lean_offset + 2, hip_y - int(0.15 * b) + 2),
            (cx + int(1.25 * b) + lean_offset + 2, hip_y - int(0.15 * b) + 2),
            (cx + int(1.55 * b) + lean_offset + int(wave * 0.2 * hakama_wave_boost * b) + hk_drift + 2, cy + int(2.85 * b) + 2),
            (cx - int(1.55 * b) + lean_offset - int(wave * 0.2 * hakama_wave_boost * b) + hk_drift + 2, cy + int(2.85 * b) + 2),
        ]
        pygame.draw.polygon(screen, (20, 15, 30), hakama_shadow)
        # 하카마 본체
        hakama_points = [
            (cx - int(1.2 * b) + lean_offset, hip_y - int(0.2 * b)),
            (cx + int(1.2 * b) + lean_offset, hip_y - int(0.2 * b)),
            (cx + int(1.5 * b) + lean_offset + int(wave * 0.2 * hakama_wave_boost * b) + hk_drift, cy + int(2.8 * b)),
            (cx - int(1.5 * b) + lean_offset - int(wave * 0.2 * hakama_wave_boost * b) + hk_drift, cy + int(2.8 * b)),
        ]
        pygame.draw.polygon(screen, p["kimono"], hakama_points)
        # 하카마 주름 (5개) - 관성 방향으로 주름 기울어짐
        for i in range(5):
            fold_drift = int((hakama_inertia + hakama_sway) * (i - 2) * 0.1)
            fx = cx + (i - 2) * int(0.45 * b) + lean_offset
            fold_wave = int(wave * 0.08 * hakama_wave_boost * b * (1 + abs(i - 2) * 0.2))
            pygame.draw.line(screen, p["kimono_light"],
                           (fx, hip_y + int(0.1 * b)), (fx + fold_wave + fold_drift, cy + int(2.6 * b)), 1)
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

        # === 팔은 장검과 함께 그림 (양손 그립 - 아래 참조) ===

        # === 목 ===
        neck_bot_w = int(0.7 * b)
        neck_top_w = int(0.5 * b)
        neck_top_y = torso_y - int(0.7 * b)
        neck_bot_y = torso_y - int(0.2 * b)
        neck_cx = cx + lean_offset
        neck_pts = [
            (neck_cx - neck_bot_w // 2, neck_bot_y),
            (neck_cx + neck_bot_w // 2, neck_bot_y),
            (neck_cx + neck_top_w // 2, neck_top_y),
            (neck_cx - neck_top_w // 2, neck_top_y),
        ]
        pygame.draw.polygon(screen, p["skin"], neck_pts)
        pygame.draw.line(screen, p["skin_shadow"],
                        (neck_cx + neck_top_w // 4, neck_top_y + 1),
                        (neck_cx + neck_bot_w // 4, neck_bot_y - 1), 1)

        # === 머리 (더 정교한 얼굴) ===
        head_y = torso_y - int(2.5 * b)
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
                glow_pulse = 0.8 + 0.2 * _sin(self.time * 6 + side)
                glow_surf = self._get_surface(int(0.4 * b), int(0.3 * b))
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

        # === 장검 (양손 그립 카타나) + 양팔 ===
        weapon_swing = anim.get("weapon_swing_angle", 0)
        arm_thick = max(2, int(0.22 * b))

        # 카타나 기준점 (정면: 오른쪽, 뒷모습: 왼쪽 = 캐릭터 앞쪽으로)
        grip_cx = cx + lean_offset
        # 뒷모습이면 검 X좌표와 기울기를 반전 (캐릭터 앞쪽으로 이동)
        _sword_side = -1 if show_back else 1
        tilt_x = 0.35 * _sword_side   # X 기울기 (뒷모습이면 반전)
        tilt_y = 0.94   # Y 기울기 (거의 수직)

        # 자루 전체 길이
        blade_len = int(3.8 * b)   # 블레이드
        tsuka_len = int(1.0 * b)   # 손잡이

        # 츠바(가드) 위치 = 그립 중심
        guard_x = grip_cx + int(0.4 * b) * _sword_side
        guard_y = torso_y + int(0.8 * b)

        # 칼끝 (위쪽) / 카시라 (아래쪽) 좌표
        blade_top_x = guard_x + int(blade_len * tilt_x)
        blade_top_y = guard_y - int(blade_len * tilt_y)
        kashira_x = guard_x - int(tsuka_len * tilt_x)
        kashira_y = guard_y + int(tsuka_len * tilt_y)

        # 그립 위치 (츠카 위에 양손 배치)
        grip_dist_top = int(0.2 * b)    # 츠바에서 가까운 손
        grip_dist_bot = int(0.7 * b)    # 카시라에 가까운 손
        g_top_x = guard_x - int(grip_dist_top * tilt_x)
        g_top_y = guard_y + int(grip_dist_top * tilt_y)
        g_bot_x = guard_x - int(grip_dist_bot * tilt_x)
        g_bot_y = guard_y + int(grip_dist_bot * tilt_y)

        # 피벗 (양손 중간)
        pivot_x = (g_top_x + g_bot_x) // 2
        pivot_y = (g_top_y + g_bot_y) // 2

        # 스윙 회전 (호루스 스타일)
        swing_dir = -1 if show_back else 1
        katana_angle = weapon_swing * 1.8 * swing_dir

        # 회전 함수
        def _rp(x, y):
            if katana_angle != 0:
                return self._rotate_point(x, y, pivot_x, pivot_y, katana_angle)
            return (x, y)

        # 회전 적용된 주요 좌표
        r_blade_top = _rp(blade_top_x, blade_top_y)
        r_guard = _rp(guard_x, guard_y)
        r_kashira = _rp(kashira_x, kashira_y)
        r_g_top = _rp(g_top_x, g_top_y)
        r_g_bot = _rp(g_bot_x, g_bot_y)

        # 카타나 곡률 (뒷모습이면 반전)
        curve_amount = int(0.12 * b) * _sword_side

        # === 스윙 잔상 (보라 검기 궤적) ===
        if abs(weapon_swing) > 0.15:
            trail_pts = []
            t_steps = 6
            for ti in range(t_steps + 1):
                t_frac = ti / float(t_steps)
                t_ang = katana_angle * t_frac
                if t_ang != 0:
                    _tr = self._rotate_point(blade_top_x, blade_top_y, pivot_x, pivot_y, t_ang)
                    trail_pts.append((int(_tr[0]), int(_tr[1])))
                else:
                    trail_pts.append((blade_top_x, blade_top_y))
            if len(trail_pts) >= 2:
                t_all_x = [tp[0] for tp in trail_pts]
                t_all_y = [tp[1] for tp in trail_pts]
                t_pad = int(0.6 * b)
                t_mn_x, t_mn_y = min(t_all_x) - t_pad, min(t_all_y) - t_pad
                t_mx_x, t_mx_y = max(t_all_x) + t_pad, max(t_all_y) + t_pad
                tw = max(4, t_mx_x - t_mn_x)
                th = max(4, t_mx_y - t_mn_y)
                t_surf = self._get_surface(tw, th)
                for ti in range(len(trail_pts) - 1):
                    f_alpha = int(abs(weapon_swing) * 120 * ((ti + 1) / len(trail_pts)))
                    lp1 = (trail_pts[ti][0] - t_mn_x, trail_pts[ti][1] - t_mn_y)
                    lp2 = (trail_pts[ti + 1][0] - t_mn_x, trail_pts[ti + 1][1] - t_mn_y)
                    pygame.draw.line(t_surf, (*p["sword_glow"], f_alpha),
                                   lp1, lp2, max(2, int(0.1 * b)))
                screen.blit(t_surf, (t_mn_x, t_mn_y))

        # === 블레이드 (곡선 폴리곤) ===
        blade_segments = 10
        blade_width = max(2, int(0.2 * b))
        blade_left = []
        blade_right = []
        for si in range(blade_segments + 1):
            st = si / blade_segments
            # 블레이드 직선 보간 + 곡선
            raw_x = guard_x + int((blade_top_x - guard_x) * st) + int(_sin(st * math.pi) * curve_amount)
            raw_y = guard_y + int((blade_top_y - guard_y) * st)
            # 폭 테이퍼 (끝으로 갈수록 좁아짐)
            w = blade_width * (0.3 + 0.7 * (1 - st)) if st > 0.85 else blade_width
            bx_l, by_l = _rp(raw_x - int(w * 0.6), raw_y)
            bx_r, by_r = _rp(raw_x + int(w * 0.4), raw_y)
            blade_left.append((bx_l, by_l))
            blade_right.append((bx_r, by_r))

        # 블레이드 그림자
        shadow_off = 2
        shadow_poly = [(x + shadow_off, y + shadow_off) for x, y in blade_left] + \
                      list(reversed([(x + shadow_off, y + shadow_off) for x, y in blade_right]))
        if len(shadow_poly) >= 3:
            pygame.draw.polygon(screen, (50, 40, 65), shadow_poly)

        # 블레이드 본체
        blade_poly = blade_left + list(reversed(blade_right))
        if len(blade_poly) >= 3:
            pygame.draw.polygon(screen, p["sword_blade"], blade_poly)
            pygame.draw.polygon(screen, p["sword_edge"], blade_poly, 1)

        # 기사키 (칼끝 삼각형)
        kissaki_len = int(0.4 * b)
        tip_raw_x = blade_top_x + int(kissaki_len * tilt_x)
        tip_raw_y = blade_top_y - int(kissaki_len * tilt_y)
        r_tip = _rp(tip_raw_x, tip_raw_y)
        r_tip_l = _rp(blade_top_x - int(0.15 * b) * _sword_side, blade_top_y)
        r_tip_r = _rp(blade_top_x + int(0.08 * b) * _sword_side, blade_top_y)
        pygame.draw.polygon(screen, p["sword_blade"], [r_tip, r_tip_l, r_tip_r])
        pygame.draw.polygon(screen, p["sword_edge"], [r_tip, r_tip_l, r_tip_r], 1)

        # 시노기 (등줄)
        shinogi_pts = []
        for si in range(blade_segments + 1):
            st = si / blade_segments
            raw_x = guard_x + int((blade_top_x - guard_x) * st) + int(_sin(st * math.pi) * curve_amount)
            raw_y = guard_y + int((blade_top_y - guard_y) * st)
            shinogi_pts.append(_rp(raw_x + int(blade_width * 0.1), raw_y))
        if len(shinogi_pts) >= 2:
            pygame.draw.lines(screen, p["sword_edge"], False, shinogi_pts, 1)

        # 하몬 (파상 담금질 무늬)
        hamon_pts = []
        for si in range(blade_segments + 1):
            st = si / blade_segments
            raw_x = guard_x + int((blade_top_x - guard_x) * st) + int(_sin(st * math.pi) * curve_amount)
            raw_y = guard_y + int((blade_top_y - guard_y) * st)
            hamon_wave = int(_sin(st * 18 + 0.5) * 0.04 * b)
            hamon_pts.append(_rp(raw_x - int(blade_width * 0.35) + hamon_wave, raw_y))
        if len(hamon_pts) >= 2:
            hamon_color = tuple(min(255, c + 25) for c in p["sword_blade"])
            pygame.draw.lines(screen, hamon_color, False, hamon_pts, 1)

        # 블레이드 하이라이트
        hl_pts = []
        for si in range(blade_segments + 1):
            st = si / blade_segments
            raw_x = guard_x + int((blade_top_x - guard_x) * st) + int(_sin(st * math.pi) * curve_amount)
            raw_y = guard_y + int((blade_top_y - guard_y) * st)
            hl_pts.append(_rp(raw_x - 1, raw_y))
        if len(hl_pts) >= 2:
            pygame.draw.lines(screen, p["sword_core"], False, hl_pts, 1)

        # === 츠바 (원형 가드) ===
        tsuba_r = max(3, int(0.3 * b))
        r_gx, r_gy = int(r_guard[0]), int(r_guard[1])
        pygame.draw.ellipse(screen, (50, 40, 35),
                          (r_gx - tsuba_r + 1, r_gy - tsuba_r // 2 + 1,
                           tsuba_r * 2, tsuba_r))
        pygame.draw.ellipse(screen, p["sword_guard"],
                          (r_gx - tsuba_r, r_gy - tsuba_r // 2,
                           tsuba_r * 2, tsuba_r))
        pygame.draw.ellipse(screen, p["kimono_gold"],
                          (r_gx - tsuba_r, r_gy - tsuba_r // 2,
                           tsuba_r * 2, tsuba_r), 1)
        # 나카고아나
        pygame.draw.ellipse(screen, p["sword_hilt"],
                          (r_gx - int(0.07 * b), r_gy - int(0.03 * b),
                           int(0.14 * b), int(0.06 * b)))

        # === 츠카 (손잡이) ===
        tsuka_w_val = max(2, int(0.18 * b))
        # 손잡이 본체 (가드 → 카시라)
        pygame.draw.line(screen, p["sword_hilt"],
                        (int(r_guard[0]), int(r_guard[1])),
                        (int(r_kashira[0]), int(r_kashira[1])),
                        tsuka_w_val + 2)
        pygame.draw.line(screen, (90, 75, 55),
                        (int(r_guard[0]), int(r_guard[1])),
                        (int(r_kashira[0]), int(r_kashira[1])),
                        tsuka_w_val)
        # 이토 (마름모 교차 감기)
        wrap_count = max(5, int(tsuka_len / (0.12 * b)))
        for wi in range(wrap_count):
            wt = (wi + 0.5) / wrap_count
            wx_raw = guard_x - int(tsuka_len * tilt_x * wt)
            wy_raw = guard_y + int(tsuka_len * tilt_y * wt)
            rwx, rwy = _rp(wx_raw, wy_raw)
            # 교차 무늬 (짧은 대각선)
            cross_size = max(1, int(0.06 * b))
            if wi % 2 == 0:
                pygame.draw.line(screen, p["sword_wrap"],
                               (int(rwx) - cross_size, int(rwy) - cross_size),
                               (int(rwx) + cross_size, int(rwy) + cross_size), 1)
            else:
                pygame.draw.line(screen, p["sword_wrap"],
                               (int(rwx) + cross_size, int(rwy) - cross_size),
                               (int(rwx) - cross_size, int(rwy) + cross_size), 1)
        # 메누키
        menuki_t = 0.35
        menuki_raw_x = guard_x - int(tsuka_len * tilt_x * menuki_t)
        menuki_raw_y = guard_y + int(tsuka_len * tilt_y * menuki_t)
        r_menuki = _rp(menuki_raw_x, menuki_raw_y)
        pygame.draw.ellipse(screen, p["kimono_gold"],
                          (int(r_menuki[0]) - int(0.05 * b), int(r_menuki[1]) - int(0.03 * b),
                           int(0.1 * b), int(0.06 * b)))

        # 카시라 (끝 마감)
        r_kx, r_ky = int(r_kashira[0]), int(r_kashira[1])
        kashira_r = max(2, int(0.1 * b))
        pygame.draw.circle(screen, p["sword_guard"], (r_kx, r_ky), kashira_r)
        pygame.draw.circle(screen, p["kimono_gold"], (r_kx, r_ky), kashira_r, 1)

        # 자루-블레이드 연결부 금장식
        conn_r = max(2, int(0.1 * b))
        pygame.draw.circle(screen, p["kimono_gold"], (r_gx, r_gy), conn_r)

        # === 양팔 (카타나를 양손으로 잡는 포즈 - 호루스 스타일) ===
        shoulder_y_base = torso_y + int(0.1 * b) + int(shoulder_bob * 0.2 * b)
        for side in [-1, 1]:
            s_x = cx + side * int(1.2 * b) + lean_offset
            s_y = shoulder_y_base
            # 위쪽 그립 (츠바 가까이): 정면=왼손(-1), 후면=오른손(1)
            is_top_grip = (side == -1 and not show_back) or (side == 1 and show_back)
            if is_top_grip:
                target_hx, target_hy = int(r_g_top[0]), int(r_g_top[1])
            else:
                target_hx, target_hy = int(r_g_bot[0]), int(r_g_bot[1])
            # 팔꿈치 (어깨→손 중간, 약간 바깥쪽)
            e_x = (s_x + target_hx) // 2 + side * int(0.3 * b)
            e_y = (s_y + target_hy) // 2 + int(0.15 * b)
            # 상완 (기모노 소매)
            pygame.draw.line(screen, p["kimono"], (s_x, s_y), (e_x, e_y), max(3, int(0.5 * b)))
            pygame.draw.line(screen, p["kimono_light"], (s_x, s_y), (e_x, e_y), max(1, int(0.3 * b)))
            # 팔꿈치 관절
            pygame.draw.circle(screen, p["skin_shadow"], (e_x, e_y), max(2, int(0.18 * b)))
            # 전완 (피부)
            pygame.draw.line(screen, p["skin"], (e_x, e_y), (target_hx, target_hy), max(2, int(0.4 * b)))
            pygame.draw.line(screen, p["skin_shadow"],
                           (e_x + 1, e_y + 1), (target_hx + 1, target_hy + 1), 1)
            # 손목 밴드
            pygame.draw.circle(screen, p["kimono"], (target_hx, target_hy), max(3, int(0.28 * b)))
            # 손 (그립)
            hand_r = max(2, int(0.2 * b))
            pygame.draw.circle(screen, p["skin"], (target_hx, target_hy), hand_r)
            pygame.draw.circle(screen, p["skin_shadow"], (target_hx, target_hy), hand_r, 1)

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
        biolum_pulse = (_sin(self.time * 2) + 1) * 0.5
        water_shimmer = _sin(self.time * 4) * 0.3

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

        # === 발밑 심해 생물발광 글로우 (바닥에 퍼지는 빛) ===
        foot_glow_y = torso_y + int(4.5 * b)
        glow_rx = int(3.0 * b)
        glow_ry = int(0.6 * b)
        glow_surf = self._get_surface(glow_rx * 2 + 4, glow_ry * 2 + 4)
        g_cx, g_cy = glow_rx + 2, glow_ry + 2
        for ring in range(3):
            ring_alpha = int((25 - ring * 7) * (0.6 + biolum_pulse * 0.4))
            rx = max(3, int((3.0 - ring * 0.7) * b))
            ry = max(2, int((0.6 - ring * 0.13) * b))
            glow_color = (
                min(255, p["glow"][0] + int(20 * biolum_pulse)),
                min(255, p["glow"][1] + int(15 * biolum_pulse)),
                min(255, p["glow"][2] + int(10 * biolum_pulse)),
                max(0, ring_alpha)
            )
            pygame.draw.ellipse(glow_surf, glow_color,
                              (g_cx - rx, g_cy - ry, rx * 2, ry * 2))
        screen.blit(glow_surf, (cx - g_cx + lean_offset, foot_glow_y - g_cy),
                   special_flags=pygame.BLEND_ADD)

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
                seg_x = base_x + int(_sin(self.time * 4 + i * 0.8 + seg * 0.6) * wave_amp * b)
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

            # === 촉수 생물발광 트레일 (각 세그먼트를 따라 빛나는 점들) ===
            for seg in range(len(points) - 1):
                trail_t = (self.time * 3.5 + i * 0.9 + seg * 0.45) % 2.0
                if trail_t < 1.2:
                    trail_frac = trail_t / 1.2  # 세그먼트 사이 보간
                    tx = points[seg][0] + int((points[seg + 1][0] - points[seg][0]) * trail_frac)
                    ty = points[seg][1] + int((points[seg + 1][1] - points[seg][1]) * trail_frac)
                    trail_bright = 1.0 - abs(trail_frac - 0.5) * 2  # 중간 지점이 가장 밝음
                    trail_glow_r = max(2, int(0.2 * b * trail_bright))
                    trail_alpha = int(100 * trail_bright * (0.6 + biolum_pulse * 0.4))
                    trail_surf_sz = trail_glow_r * 4
                    if trail_surf_sz > 2:
                        trail_surf = self._get_surface(trail_surf_sz, trail_surf_sz)
                        pygame.draw.circle(trail_surf, (*p["biolum"], trail_alpha),
                            (trail_surf_sz // 2, trail_surf_sz // 2), trail_glow_r)
                        screen.blit(trail_surf, (tx - trail_surf_sz // 2, ty - trail_surf_sz // 2),
                            special_flags=pygame.BLEND_ADD)
                    # 코어 밝은 점
                    core_sz = max(1, int(0.06 * b * trail_bright))
                    pygame.draw.circle(screen, p["biolum"], (tx, ty), core_sz)

            # === 촉수 끝 발광 펄스 (끝이 밝게 빛남) ===
            if len(points) >= 2:
                tip_x, tip_y = points[-1]
                tip_pulse = (0.5 + _sin(self.time * 5 + i * 1.3) * 0.5)
                tip_glow_sz = int(0.3 * b * tip_pulse)
                if tip_glow_sz > 1:
                    tip_surf = self._get_surface(tip_glow_sz * 4, tip_glow_sz * 4)
                    pygame.draw.circle(tip_surf, (*p["biolum"], int(70 * tip_pulse)),
                        (tip_glow_sz * 2, tip_glow_sz * 2), tip_glow_sz)
                    screen.blit(tip_surf, (tip_x - tip_glow_sz * 2, tip_y - tip_glow_sz * 2),
                        special_flags=pygame.BLEND_ADD)
                    pygame.draw.circle(screen, p["biolum_soft"], (tip_x, tip_y), max(1, int(0.05 * b)))

        # === 목/맨틀 연결부 (머리와 몸통 이어줌) ===
        neck_top = torso_y - int(0.8 * b)
        neck_bot = torso_y - int(0.1 * b)
        neck_top_w = int(2.0 * b)
        neck_bot_w = int(3.0 * b)
        neck_pts = [
            (cx - neck_top_w // 2 + lean_offset, neck_top),
            (cx + neck_top_w // 2 + lean_offset, neck_top),
            (cx + neck_bot_w // 2 + lean_offset, neck_bot),
            (cx - neck_bot_w // 2 + lean_offset, neck_bot),
        ]
        pygame.draw.polygon(screen, p["body"], neck_pts)
        # 목 음영
        pygame.draw.polygon(screen, p["body_dark"], [
            (cx - neck_top_w // 2 + lean_offset, neck_top),
            (cx - neck_bot_w // 2 + lean_offset, neck_bot),
            (cx - neck_bot_w // 2 + int(0.4 * b) + lean_offset, neck_bot),
            (cx - neck_top_w // 2 + int(0.3 * b) + lean_offset, neck_top),
        ])
        pygame.draw.polygon(screen, p["body_dark"], [
            (cx + neck_top_w // 2 + lean_offset, neck_top),
            (cx + neck_bot_w // 2 + lean_offset, neck_bot),
            (cx + neck_bot_w // 2 - int(0.4 * b) + lean_offset, neck_bot),
            (cx + neck_top_w // 2 - int(0.3 * b) + lean_offset, neck_top),
        ])

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
                spot_offset = _sin(self.time * 3 + col + row) * 0.05 * b
                pygame.draw.ellipse(screen, p["body_dark"],
                    (int(spot_x + spot_offset), int(spot_y), max(2, int(0.25 * b)), max(1, int(0.15 * b))))

        # 슬라임/점액질 효과
        slime_y = chest_rect.bottom - int(0.3 * b)
        for i in range(4):
            slime_x = chest_rect.left + int(0.4 * b) + i * int(0.6 * b)
            drip_length = int(_sin(self.time * 2 + i) * 0.2 * b + 0.3 * b)
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

        # === 비늘 패턴 (무지개빛 일렁임) ===
        scale_rows = 5
        scale_cols = 7
        for row in range(scale_rows):
            for col in range(scale_cols):
                # 체스판 패턴으로 배치 (자연스러운 비늘 겹침)
                offset_x = int(0.18 * b) if row % 2 == 1 else 0
                sc_x = chest_rect.left + int(0.2 * b) + col * int(0.38 * b) + offset_x
                sc_y = chest_rect.top + int(0.25 * b) + row * int(0.35 * b)
                # 몸통 타원 내부에만 그리기
                dx = (sc_x - chest_rect.centerx) / (chest_w * 0.45)
                dy = (sc_y - chest_rect.centery) / (chest_h * 0.45)
                if dx * dx + dy * dy > 1.0:
                    continue
                sc_w = max(2, int(0.22 * b))
                sc_h = max(1, int(0.14 * b))
                # 무지개빛 색상 (시간과 위치에 따라 변화)
                iridescent_phase = self.time * 2.5 + col * 0.4 + row * 0.6
                iri_r = int(p["body"][0] + 25 * _sin(iridescent_phase))
                iri_g = int(p["body"][1] + 20 * _sin(iridescent_phase + 2.1))
                iri_b_val = int(p["body"][2] + 30 * _sin(iridescent_phase + 4.2))
                iri_color = (max(0, min(255, iri_r)), max(0, min(255, iri_g)), max(0, min(255, iri_b_val)))
                pygame.draw.ellipse(screen, iri_color, (sc_x - sc_w // 2, sc_y - sc_h // 2, sc_w, sc_h))
                # 비늘 윤곽 (아래쪽 호 모양)
                pygame.draw.arc(screen, p["body_dark"],
                    (sc_x - sc_w // 2, sc_y - sc_h // 2, sc_w, sc_h),
                    3.14, 6.28, 1)
                # 하이라이트 (위쪽)
                hi_alpha = int(40 * (0.5 + _sin(iridescent_phase + 1.0) * 0.5))
                if hi_alpha > 10 and sc_w > 3:
                    hi_surf = self._get_surface(sc_w, sc_h)
                    pygame.draw.arc(hi_surf, (*p["body_highlight"], hi_alpha),
                        (0, 0, sc_w, sc_h), 0, 3.14, max(1, int(0.04 * b)))
                    screen.blit(hi_surf, (sc_x - sc_w // 2, sc_y - sc_h // 2),
                        special_flags=pygame.BLEND_ADD)

        # === 촉수 기저부 막질 (몸통과 다리 촉수 사이 웨빙) ===
        web_base_y = chest_rect.bottom - int(0.15 * b)
        web_positions = [-1.8, -1.1, -0.4, 0.4, 1.1, 1.8]
        for wi in range(len(web_positions) - 1):
            left_x = cx + int(web_positions[wi] * 0.4 * b) + lean_offset
            right_x = cx + int(web_positions[wi + 1] * 0.4 * b) + lean_offset
            mid_x = (left_x + right_x) // 2
            web_sag = int(0.35 * b + _sin(self.time * 2.5 + wi * 0.8) * 0.08 * b)
            web_pts = [
                (left_x, web_base_y),
                (mid_x - int(0.05 * b), web_base_y + web_sag),
                (right_x, web_base_y),
            ]
            # 반투명 막 그리기
            web_alpha = int(50 + 15 * _sin(self.time * 3 + wi))
            web_surf_w = abs(right_x - left_x) + int(0.4 * b)
            web_surf_h = web_sag + int(0.3 * b)
            if web_surf_w > 4 and web_surf_h > 4:
                web_surf = self._get_surface(web_surf_w, web_surf_h)
                local_pts = [
                    (web_pts[0][0] - left_x + int(0.2 * b), 0),
                    (web_pts[1][0] - left_x + int(0.2 * b), web_sag),
                    (web_pts[2][0] - left_x + int(0.2 * b), 0),
                ]
                web_color = (
                    min(255, p["tentacle"][0] + 20),
                    min(255, p["tentacle"][1] + 15),
                    min(255, p["tentacle"][2] + 25),
                    web_alpha
                )
                pygame.draw.polygon(web_surf, web_color, local_pts)
                # 막질 혈관 라인
                vein_color = (*p["biolum_soft"], int(web_alpha * 0.5))
                for vi in range(2):
                    vt = (vi + 1) / 3
                    vx1 = local_pts[0][0] + int((local_pts[1][0] - local_pts[0][0]) * vt)
                    vy1 = int(web_sag * vt * 0.7)
                    vx2 = local_pts[1][0] + int((local_pts[2][0] - local_pts[1][0]) * vt)
                    vy2 = int(web_sag * (1 - vt) * 0.7)
                    pygame.draw.line(web_surf, vein_color, (vx1, vy1), (vx2, vy2), 1)
                screen.blit(web_surf, (left_x - int(0.2 * b), web_base_y))

        # === 팔 촉수 (양쪽, 더 역동적 + 어깨 들썩임) ===
        _weapon_swing = anim.get("weapon_swing_angle", 0)
        _hit_react = abs(_weapon_swing) / 0.7 if _weapon_swing != 0 else 0  # 0~1 반응 강도
        for side in [-1, 1]:
            shoulder_bob_offset = int(shoulder_bob * 0.3 * b)
            shoulder = (cx + side * int(1.4 * b) + lean_offset, torso_y + int(0.2 * b) + shoulder_bob_offset)

            # 팔 촉수 웨이브 (8개 세그먼트)
            arm_points = []
            for seg in range(8):
                # 공 타격 시 촉수 격렬 반응 (끝으로 갈수록 증폭)
                react_amp = _hit_react * (seg / 7) * 3.0
                wave_x = _sin(self.time * 5 + seg * 0.8) * (0.25 + react_amp) * b * (seg / 4)
                wave_y = _cos(self.time * 4 + seg * 0.6) * (0.15 + react_amp * 0.6) * b
                # 타격 시 촉수가 안쪽으로 움츠렸다 펴지는 효과
                retract = _hit_react * (seg / 7) * 0.5 * b * side * _weapon_swing / abs(_weapon_swing) if _weapon_swing != 0 else 0
                ax = shoulder[0] + side * seg * int(0.28 * b) + wave_x + retract
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
                    fx = end_x + int(_cos(self.time * 3 + finger) * f_len * 0.3 + f_angle * f_len)
                    fy = end_y + int(f_len * 0.8)
                    pygame.draw.line(screen, p["tentacle"], (int(end_x), int(end_y)), (int(fx), int(fy)), max(2, int(0.15 * b)))

            # === 먹물 구름 파티클 (공격 시 촉수 끝에서 분출) ===
            if abs(_weapon_swing) > 0.05:
                ink_intensity = min(1.0, abs(_weapon_swing) / 0.5)
                if len(arm_points) >= 2:
                    ink_origin_x, ink_origin_y = arm_points[-1]
                    for ink_i in range(5):
                        ink_age = (self.time * 2.0 + ink_i * 0.5 + side * 1.5) % 2.0
                        if ink_age < 1.5:
                            ink_frac = ink_age / 1.5
                            # 먹물이 퍼지면서 하강
                            ink_spread = ink_frac * 2.0 * b
                            ink_x = ink_origin_x + int(_sin(self.time * 7 + ink_i * 2.1) * ink_spread * 0.6)
                            ink_y = ink_origin_y + int(ink_frac * 1.2 * b) + int(_cos(self.time * 5 + ink_i * 1.7) * ink_spread * 0.3)
                            ink_size = int((0.2 + ink_frac * 0.5) * b * ink_intensity)
                            ink_alpha = int(80 * (1.0 - ink_frac) * ink_intensity)
                            if ink_size > 1 and ink_alpha > 5:
                                ink_surf_sz = ink_size * 3
                                ink_surf = self._get_surface(ink_surf_sz, ink_surf_sz)
                                # 검은 먹물 + 보라빛 테두리
                                ink_core = (20, 10, 35, ink_alpha)
                                pygame.draw.circle(ink_surf, ink_core,
                                    (ink_surf_sz // 2, ink_surf_sz // 2), ink_size)
                                ink_edge = (50, 20, 70, int(ink_alpha * 0.5))
                                pygame.draw.circle(ink_surf, ink_edge,
                                    (ink_surf_sz // 2, ink_surf_sz // 2), ink_size, max(1, int(0.04 * b)))
                                screen.blit(ink_surf, (ink_x - ink_surf_sz // 2, ink_y - ink_surf_sz // 2))
                    # 먹물 잔여 필라멘트 (가느다란 실 같은 흔적)
                    for fil_i in range(3):
                        fil_age = (self.time * 1.5 + fil_i * 0.8 + side) % 1.8
                        if fil_age < 1.2:
                            fil_frac = fil_age / 1.2
                            fil_start_x = ink_origin_x + int(_sin(self.time * 4 + fil_i * 3) * 0.4 * b)
                            fil_start_y = ink_origin_y + int(fil_frac * 0.8 * b)
                            fil_end_x = fil_start_x + int(_cos(self.time * 6 + fil_i * 2) * 0.6 * b)
                            fil_end_y = fil_start_y + int(0.5 * b)
                            fil_alpha = int(50 * (1.0 - fil_frac) * ink_intensity)
                            if fil_alpha > 5:
                                fil_surf_w = abs(fil_end_x - fil_start_x) + int(0.4 * b)
                                fil_surf_h = abs(fil_end_y - fil_start_y) + int(0.4 * b)
                                if fil_surf_w > 2 and fil_surf_h > 2:
                                    fil_surf = self._get_surface(fil_surf_w, fil_surf_h)
                                    ox = int(0.2 * b)
                                    oy = int(0.2 * b)
                                    pygame.draw.line(fil_surf, (30, 15, 45, fil_alpha),
                                        (ox, oy), (fil_end_x - fil_start_x + ox, fil_end_y - fil_start_y + oy),
                                        max(1, int(0.03 * b)))
                                    screen.blit(fil_surf, (min(fil_start_x, fil_end_x) - ox,
                                        min(fil_start_y, fil_end_y) - oy))

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

        # === 머리 꼭대기 볏 지느러미 (왕관 크레스트) ===
        crest_base_y = head_rect.top + int(0.1 * b)
        crest_height = int(0.9 * b)
        crest_segments = 7
        crest_width = int(1.6 * b)
        crest_center_x = head_rect.centerx
        crest_spine = []
        for ci in range(crest_segments):
            ct = ci / (crest_segments - 1)
            c_x = crest_center_x + int((ct - 0.5) * crest_width)
            height_factor = 1.0 - (ct - 0.5) ** 2 * 4
            wave_offset = _sin(self.time * 3 + ci * 0.5) * 0.08 * b
            c_y = crest_base_y - int(crest_height * max(0, height_factor)) + int(wave_offset)
            crest_spine.append((c_x, int(c_y)))
        if len(crest_spine) >= 3:
            crest_surf_w = crest_width + int(0.4 * b)
            crest_surf_h = crest_height + int(0.6 * b)
            if crest_surf_w > 4 and crest_surf_h > 4:
                crest_surf = self._get_surface(crest_surf_w, crest_surf_h)
                base_left = (0, crest_surf_h - int(0.3 * b))
                base_right = (crest_surf_w, crest_surf_h - int(0.3 * b))
                local_spine = [(sp[0] - crest_center_x + crest_surf_w // 2,
                               sp[1] - crest_base_y + crest_height + int(0.3 * b)) for sp in crest_spine]
                membrane_pts = [base_left] + local_spine + [base_right]
                membrane_color = (
                    min(255, p["body_light"][0] + 10),
                    min(255, p["body_light"][1] + 15),
                    min(255, p["body_light"][2] + 20),
                    int(60 + 20 * biolum_pulse)
                )
                pygame.draw.polygon(crest_surf, membrane_color, membrane_pts)
                for ci in range(len(local_spine)):
                    base_pt = (local_spine[ci][0], crest_surf_h - int(0.3 * b))
                    spine_color = (*p["body_dark"], int(120 + 30 * biolum_pulse))
                    pygame.draw.line(crest_surf, spine_color, base_pt, local_spine[ci],
                        max(1, int(0.06 * b)))
                if len(local_spine) >= 2:
                    edge_color = (*p["biolum"], int(40 * biolum_pulse))
                    pygame.draw.lines(crest_surf, edge_color, False, local_spine,
                        max(1, int(0.04 * b)))
                screen.blit(crest_surf,
                    (crest_center_x - crest_surf_w // 2, crest_base_y - crest_height - int(0.3 * b)),
                    special_flags=pygame.BLEND_ADD if biolum_pulse > 0.5 else 0)

        # === 머리 표면 맥동 혈관 패턴 ===
        vein_paths = [
            (0.0, -0.4, 0.8), (0.0, 0.4, 0.7),
            (-0.3, -0.6, 0.6), (0.3, -0.6, 0.6),
            (-0.2, 0.3, 0.65), (0.2, 0.3, 0.65),
            (-0.5, -0.1, 0.5), (0.5, -0.1, 0.5),
        ]
        for vi, (vx_off, vy_off, v_len) in enumerate(vein_paths):
            v_pulse = (0.3 + _sin(self.time * 4 + vi * 0.9) * 0.7)
            v_start_x = head_rect.centerx + int(vx_off * 0.3 * b)
            v_start_y = head_rect.centery + int(vy_off * 0.3 * b)
            v_segments = 4
            v_points = [(v_start_x, v_start_y)]
            for vs in range(1, v_segments + 1):
                vt = vs / v_segments
                vsx = v_start_x + int(vx_off * v_len * b * vt) + int(_sin(self.time * 5 + vi + vs) * 0.06 * b)
                vsy = v_start_y + int(vy_off * v_len * b * vt) + int(_cos(self.time * 4 + vi + vs) * 0.04 * b)
                v_points.append((int(vsx), int(vsy)))
            if len(v_points) >= 2:
                v_alpha = int(45 * max(0, v_pulse))
                v_thick = max(1, int(0.05 * b * (0.5 + v_pulse * 0.5)))
                v_surf_w = head_w + int(0.4 * b)
                v_surf_h = head_h + int(0.4 * b)
                if v_surf_w > 4 and v_surf_h > 4:
                    v_surf = self._get_surface(v_surf_w, v_surf_h)
                    local_v = [(vp[0] - head_rect.left + int(0.2 * b),
                               vp[1] - head_rect.top + int(0.2 * b)) for vp in v_points]
                    vein_draw_color = (
                        min(255, p["biolum"][0] + 30),
                        max(0, p["biolum"][1] - 60),
                        min(255, p["biolum"][2] + 10),
                        v_alpha
                    )
                    pygame.draw.lines(v_surf, vein_draw_color, False, local_v, v_thick)
                    screen.blit(v_surf,
                        (head_rect.left - int(0.2 * b), head_rect.top - int(0.2 * b)),
                        special_flags=pygame.BLEND_ADD)

        # === 작은 물고기/플랑크톤 파티클 (배경 심해 생물) ===
        for fish_i in range(8):
            fish_orbit_r = (2.5 + fish_i * 0.4) * b
            fish_speed = 0.6 + fish_i * 0.12
            fish_angle = self.time * fish_speed + fish_i * 0.785
            fish_x = cx + lean_offset + int(_cos(fish_angle) * fish_orbit_r * 0.8)
            fish_y = torso_y - int(0.5 * b) + int(_sin(fish_angle) * fish_orbit_r * 0.5)
            fish_flicker = (0.4 + _sin(self.time * 8 + fish_i * 2.3) * 0.6)
            if fish_flicker > 0.2:
                fish_alpha = int(50 * fish_flicker)
                fish_sz = max(1, int(0.08 * b))
                fish_surf_sz = fish_sz * 6
                if fish_surf_sz > 2:
                    fish_surf = self._get_surface(fish_surf_sz, fish_surf_sz)
                    pygame.draw.circle(fish_surf, (*p["biolum_soft"], int(fish_alpha * 0.4)),
                        (fish_surf_sz // 2, fish_surf_sz // 2), fish_sz * 2)
                    pygame.draw.circle(fish_surf, (*p["biolum"], fish_alpha),
                        (fish_surf_sz // 2, fish_surf_sz // 2), fish_sz)
                    screen.blit(fish_surf, (fish_x - fish_surf_sz // 2, fish_y - fish_surf_sz // 2),
                        special_flags=pygame.BLEND_ADD)
                    tail_dx = int(_sin(fish_angle) * 0.12 * b)
                    tail_dy = int(-_cos(fish_angle) * 0.08 * b)
                    pygame.draw.line(screen, p["biolum_soft"],
                        (fish_x, fish_y), (fish_x + tail_dx, fish_y + tail_dy),
                        max(1, int(0.03 * b)))

        # === 심해 부유 미립자 (느리게 떠다니는 해양 눈) ===
        for snow_i in range(12):
            snow_seed = snow_i * 7.31
            snow_x = cx + lean_offset + int(_sin(self.time * 0.3 + snow_seed) * 4.0 * b)
            snow_y_cycle = (self.time * 0.15 + snow_seed * 0.1) % 1.0
            snow_y = torso_y - int(4 * b) + int(snow_y_cycle * 8 * b)
            snow_alpha = int(35 * (1.0 - abs(snow_y_cycle - 0.5) * 2))
            snow_sz = max(1, int(0.04 * b))
            if snow_alpha > 5:
                pygame.draw.circle(screen, (*p["water_drop"][:2], min(255, p["water_drop"][2] + 20)),
                    (snow_x, snow_y), snow_sz)

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

                # 눈 외곽 테두리
                pygame.draw.ellipse(screen, p["body_dark"],
                                   (eye_x - eye_w // 2 - 2, eye_y - eye_h // 2 - 2, eye_w + 4, eye_h + 4))
                # 눈 본체
                pygame.draw.ellipse(screen, p["eye"], (eye_x - eye_w // 2, eye_y - eye_h // 2, eye_w, eye_h))

                # 동공 (가로로 긴 형태, 움직임)
                pupil_move = _sin(self.time * 2) * 0.05 * b
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

                # === 홍채 링 디테일 (동공 주변 동심원 패턴) ===
                iris_cx = eye_x + int(pupil_move * 0.5)
                iris_cy = eye_y
                for iris_ring in range(3):
                    iris_r = int((0.28 - iris_ring * 0.06) * b)
                    iris_ring_alpha = int(50 - iris_ring * 15)
                    if iris_r > 1:
                        iris_color_shift = _sin(self.time * 2.5 + iris_ring * 1.2 + side) * 20
                        iris_ring_color = (
                            max(0, min(255, int(p["eye"][0] - 40 + iris_color_shift))),
                            max(0, min(255, int(p["eye"][1] - 20 - iris_color_shift * 0.5))),
                            max(0, min(255, int(p["eye"][2] - 30 + iris_color_shift * 0.3)))
                        )
                        pygame.draw.circle(screen, iris_ring_color,
                            (iris_cx, iris_cy), iris_r, max(1, int(0.03 * b)))

                # === 동공 확장/수축 애니메이션 ===
                pupil_dilate = 0.8 + _sin(self.time * 1.2 + side * 0.5) * 0.2
                pupil_w_anim = int(0.35 * b * pupil_dilate)
                pupil_h_anim = int(0.2 * b * (2.0 - pupil_dilate))
                if pupil_w_anim > 1 and pupil_h_anim > 1:
                    for pd_layer in range(3):
                        pd_shrink = pd_layer * int(0.04 * b)
                        pd_w = max(1, pupil_w_anim - pd_shrink * 2)
                        pd_h = max(1, pupil_h_anim - pd_shrink * 2)
                        pd_bright = min(255, p["eye_pupil"][0] + pd_layer * 12)
                        pd_color = (pd_bright, min(255, p["eye_pupil"][1] + pd_layer * 15),
                                   min(255, p["eye_pupil"][2] + pd_layer * 8))
                        pygame.draw.ellipse(screen, pd_color,
                            (iris_cx - pd_w // 2 + int(pupil_move), iris_cy - pd_h // 2, pd_w, pd_h))

                # === 눈 주변 정맥 (눈 흰자위에 혈관) ===
                for ev_i in range(4):
                    ev_angle = ev_i * 1.57 + side * 0.3 + _sin(self.time * 2 + ev_i) * 0.15
                    ev_len = int(0.3 * b)
                    ev_start_x = eye_x + int(_cos(ev_angle) * 0.15 * b)
                    ev_start_y = eye_y + int(_sin(ev_angle) * 0.12 * b)
                    ev_end_x = eye_x + int(_cos(ev_angle) * ev_len)
                    ev_end_y = eye_y + int(_sin(ev_angle) * ev_len * 0.8)
                    ev_color = (max(0, p["eye"][0] - 60), max(0, p["eye"][1] - 40), max(0, p["eye"][2] - 30))
                    pygame.draw.line(screen, ev_color,
                        (ev_start_x, ev_start_y), (ev_end_x, ev_end_y), 1)

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
                    wx = whisker_x + int(_sin(self.time * 6 + i + seg) * 0.1 * b)
                    wy = whisker_y + seg * int(0.2 * b)
                    whisker_points.append((int(wx), int(wy)))
                if len(whisker_points) >= 2:
                    pygame.draw.lines(screen, p["tentacle"], False, whisker_points, max(1, int(0.1 * b)))

            # === 턱에서 떨어지는 물/점액 방울 ===
            drip_base_y = mouth_y + int(0.5 * b)
            for drip_i in range(5):
                drip_x = head_rect.centerx + int((drip_i - 2) * 0.22 * b)
                drip_cycle = (self.time * 0.8 + drip_i * 0.45) % 1.5
                if drip_cycle < 1.2:
                    drip_frac = drip_cycle / 1.2
                    drip_y = drip_base_y + int(drip_frac * 1.5 * b)
                    drip_stretch = 1.0 + drip_frac * 0.8
                    drip_w = max(1, int(0.06 * b * (1.0 - drip_frac * 0.5)))
                    drip_h = max(1, int(0.06 * b * drip_stretch))
                    drip_alpha = int(120 * (1.0 - drip_frac * 0.8))
                    # 점액 실 (방울과 턱 연결)
                    if drip_frac < 0.6:
                        thread_alpha = int(80 * (1.0 - drip_frac / 0.6))
                        thread_color = (*p["slime"], thread_alpha)
                        thread_surf_h = int(drip_frac * 1.5 * b) + int(0.3 * b)
                        if thread_surf_h > 2:
                            thread_surf = self._get_surface(int(0.2 * b), thread_surf_h)
                            pygame.draw.line(thread_surf, thread_color,
                                (int(0.1 * b), 0), (int(0.1 * b), thread_surf_h), 1)
                            screen.blit(thread_surf, (drip_x - int(0.1 * b), drip_base_y))
                    # 방울 본체
                    drip_surf_sz = max(drip_w, drip_h) * 4 + 4
                    if drip_surf_sz > 2:
                        drip_surf = self._get_surface(drip_surf_sz, drip_surf_sz)
                        d_cx, d_cy = drip_surf_sz // 2, drip_surf_sz // 2
                        pygame.draw.ellipse(drip_surf, (*p["slime"], drip_alpha),
                            (d_cx - drip_w, d_cy - drip_h, drip_w * 2, drip_h * 2))
                        pygame.draw.circle(drip_surf, (*p["water_drop"], int(drip_alpha * 0.6)),
                            (d_cx - max(1, drip_w // 2), d_cy - max(1, drip_h // 2)),
                            max(1, drip_w // 2))
                        screen.blit(drip_surf, (drip_x - drip_surf_sz // 2, drip_y - drip_surf_sz // 2))

            # === 상승 기포 파티클 (입 주변에서 올라가는 거품) ===
            for bub_i in range(7):
                bub_seed = bub_i * 3.17 + 1.5
                bub_x_base = head_rect.centerx + int((bub_i - 3) * 0.3 * b)
                bub_cycle = (self.time * 0.6 + bub_seed * 0.2) % 2.0
                if bub_cycle < 1.6:
                    bub_frac = bub_cycle / 1.6
                    bub_x = bub_x_base + int(_sin(self.time * 4 + bub_i * 1.8) * 0.15 * b)
                    bub_y = mouth_y + int(0.3 * b) - int(bub_frac * 2.5 * b)
                    bub_size = max(1, int(0.08 * b * (0.6 + bub_frac * 0.4)))
                    bub_alpha = int(80 * (1.0 - bub_frac) * (0.3 + bub_frac * 0.7))
                    if bub_alpha > 5 and bub_size > 0:
                        pygame.draw.circle(screen, p["water_drop"], (bub_x, bub_y), bub_size, max(1, int(0.02 * b)))
                        hi_x = bub_x - max(1, bub_size // 3)
                        hi_y = bub_y - max(1, bub_size // 3)
                        pygame.draw.circle(screen, p["eye_highlight"], (hi_x, hi_y), max(1, bub_size // 3))

            # === 턱 아래 점액질 막 (양쪽 턱 촉수 사이 웨빙) ===
            jaw_web_y = mouth_y + int(0.35 * b)
            jaw_web_width = int(0.8 * b)
            jaw_web_sag = int(0.2 * b + _sin(self.time * 2.2) * 0.05 * b)
            jaw_web_alpha = int(35 + 10 * _sin(self.time * 3))
            jaw_web_surf_w = jaw_web_width + int(0.2 * b)
            jaw_web_surf_h = jaw_web_sag + int(0.2 * b)
            if jaw_web_surf_w > 3 and jaw_web_surf_h > 3:
                jaw_web_surf = self._get_surface(jaw_web_surf_w, jaw_web_surf_h)
                local_jaw = [
                    (int(0.1 * b), 0),
                    (jaw_web_surf_w // 2, jaw_web_sag),
                    (jaw_web_surf_w - int(0.1 * b), 0),
                ]
                pygame.draw.polygon(jaw_web_surf, (*p["slime"], jaw_web_alpha), local_jaw)
                screen.blit(jaw_web_surf,
                    (head_rect.centerx - jaw_web_surf_w // 2, jaw_web_y))

    # =========================================================================
    # 키르케 - 흑마녀 (흑마법/저주 테마) [고퀄리티 업그레이드] [여성]
    # =========================================================================
    def _draw_chronos(self, screen, cx, cy, b, color, show_back, anim):
        """키르케 - 흑마녀 여성 (금지된 흑마법으로 상대를 압도하는 암흑의 마녀) [고퀄리티]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        shoulder_bob = anim.get("shoulder_bob", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        # 흑마법 펄스
        time_pulse = (_sin(self.time * 1.5) + 1) * 0.5
        gear_spin = self.time * 2

        p = {
            "robe": (30, 20, 45),  # 깊은 암흑 보라 로브
            "robe_mid": (50, 35, 70),
            "robe_light": (70, 50, 95),
            "robe_highlight": (100, 70, 130),
            "gold": color,
            "gold_light": tuple(min(255, c + 60) for c in color),
            "gold_mid": tuple(min(255, c + 30) for c in color),
            "gold_dark": tuple(max(0, c - 50) for c in color),
            "gold_shadow": tuple(max(0, c - 80) for c in color),
            "skin": (215, 200, 210),  # 창백한 피부
            "skin_shadow": (185, 170, 180),
            "eye": (200, 50, 200),  # 보라빛 마안
            "eye_glow": (230, 80, 255),
            "clock_face": (200, 190, 220),  # 마법진 문양용
            "clock_rim": (160, 140, 180),
            "gear": (150, 120, 170),  # 마법 룬 장식
            "gear_dark": (110, 80, 130),
            "gear_light": (180, 155, 200),
            "glow": (180, 80, 255),  # 흑마법 글로우
            "time_aura": (140, 50, 200),  # 암흑 오라
            "sand": (180, 150, 200),  # 마력 입자
            "hair": (20, 10, 35),  # 칠흑 머리카락
            "hair_light": (45, 30, 60),
            "hair_mid": (30, 18, 45),
            "lip": (160, 70, 120),
            "lip_light": (190, 100, 145),
            "eyelash": (20, 10, 30),
        }

        # === 흑마법 오라 (배경 효과) ===
        aura_size = int(5 * b)
        aura_surf = self._get_surface(aura_size * 2, aura_size * 2)
        for i in range(4):
            aura_alpha = int(25 - i * 6)
            aura_r = int((2.2 - i * 0.4) * b)
            pygame.draw.circle(aura_surf, (*p["time_aura"], aura_alpha), (aura_size, aura_size), aura_r)
        screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - int(1.2 * b) - aura_size // 2), special_flags=pygame.BLEND_ADD)

        # 흑마력 입자 (떠다니는 암흑 에너지)
        for i in range(8):
            particle_angle = self.time * 0.8 + i * math.pi / 4
            particle_r = int(2.5 * b + _sin(self.time * 2 + i) * 0.3 * b)
            px = cx + int(_cos(particle_angle) * particle_r) + lean_offset
            py = torso_y - int(0.5 * b) + int(_sin(particle_angle * 2 + self.time) * 0.8 * b)
            particle_alpha = int(100 + 50 * _sin(self.time * 3 + i))
            particle_surf = self._get_surface(int(0.3 * b), int(0.3 * b))
            pygame.draw.circle(particle_surf, (*p["sand"], particle_alpha), (int(0.15 * b), int(0.15 * b)), max(1, int(0.1 * b)))
            screen.blit(particle_surf, (int(px - 0.15 * b), int(py - 0.15 * b)))

        # === 로브 하단 (시계추 장식) ===
        # 로브 넘실거림 - 유령 같은 신비로운 흘러내림
        side_blend = anim.get("side_blend", 0)
        move_dir = anim.get("move_dir", 0)
        robe_drift = -move_dir * side_blend * 0.7 * b  # 가벼운 로브: 관성 강하게
        # 이중 사인파로 유령 같은 불규칙 흔들림
        robe_ghost = (_sin(self.time * 3.2) * 0.2 + _sin(self.time * 5.1) * 0.1) * side_blend * b
        robe_wave_boost = 1.0 + side_blend * 2.5  # 로브는 가벼워서 물결 증폭 크게

        rb_drift = int(robe_drift + robe_ghost)
        robe_points = [
            (cx - int(1.4 * b) + lean_offset, torso_y + int(1.6 * b)),
            (cx + int(1.4 * b) + lean_offset, torso_y + int(1.6 * b)),
            (cx + int(2.0 * b) + lean_offset + int(wave * 0.25 * robe_wave_boost * b) + rb_drift, cy + int(3.2 * b)),
            (cx - int(2.0 * b) + lean_offset - int(wave * 0.25 * robe_wave_boost * b) + rb_drift, cy + int(3.2 * b)),
        ]
        pygame.draw.polygon(screen, p["robe"], robe_points)

        # 로브 주름 디테일 (유령처럼 비대칭으로 흔들림)
        for i in range(5):
            fold_shift = int((robe_drift + robe_ghost) * (i - 2) * 0.12)
            fold_x = cx + (i - 2) * int(0.5 * b) + lean_offset
            fold_top_y = torso_y + int(1.8 * b)
            fold_bot_y = cy + int(3.0 * b)
            pygame.draw.line(screen, p["robe_mid"], (fold_x, fold_top_y), (fold_x + int(wave * 0.05 * robe_wave_boost * b) + fold_shift, fold_bot_y), 1)

        # 로브 금색 테두리 (이중선)
        pygame.draw.line(screen, p["gold_dark"], robe_points[0], robe_points[3], max(2, int(0.12 * b)))
        pygame.draw.line(screen, p["gold"], robe_points[0], robe_points[3], max(1, int(0.06 * b)))
        pygame.draw.line(screen, p["gold_dark"], robe_points[1], robe_points[2], max(2, int(0.12 * b)))
        pygame.draw.line(screen, p["gold"], robe_points[1], robe_points[2], max(1, int(0.06 * b)))

        # 로브 하단 시계 패턴 (넘실거림 연동)
        for i in range(3):
            clock_drift = int((robe_drift + robe_ghost) * (0.5 + i * 0.2))
            clock_x = cx + (i - 1) * int(0.9 * b) + lean_offset + clock_drift
            clock_y = cy + int(2.4 * b)
            clock_r = max(2, int(0.25 * b))
            pygame.draw.circle(screen, p["gold_dark"], (int(clock_x), int(clock_y)), clock_r)
            pygame.draw.circle(screen, p["clock_face"], (int(clock_x), int(clock_y)), clock_r - 1)
            # 시계 바늘
            hand_angle = self.time * (2 + i)
            hx = clock_x + int(_cos(hand_angle) * clock_r * 0.6)
            hy = clock_y + int(_sin(hand_angle) * clock_r * 0.6)
            pygame.draw.line(screen, p["gold_dark"], (int(clock_x), int(clock_y)), (int(hx), int(hy)), 1)

        # 시계추 (로브 아래에 흔들림) - 더 정교함
        pendulum_swing = _sin(self.time * 2) * 0.5
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

        # === 몸통 (톱니바퀴 장식 로브, 여성 실루엣) ===
        chest_w, chest_h = int(2.8 * b), int(2.2 * b)
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
        glow_surf = self._get_surface(int(1.8 * b), int(1.8 * b))
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
                (gear_cx + int(_cos(t1_angle) * inner_r), gear_cy + int(_sin(t1_angle) * inner_r)),
                (gear_cx + int(_cos(angle) * outer_r), gear_cy + int(_sin(angle) * outer_r)),
                (gear_cx + int(_cos(t2_angle) * inner_r), gear_cy + int(_sin(t2_angle) * inner_r)),
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
                tx = sg_cx + int(_cos(angle) * small_gear_r)
                ty = sg_cy + int(_sin(angle) * small_gear_r)
                pygame.draw.circle(screen, p["gear_light"], (tx, ty), max(1, int(0.06 * b)))
            pygame.draw.circle(screen, p["gear"], (sg_cx, sg_cy), max(1, int(0.12 * b)))

        # === 허리띠 (시계 장식, 슬림) ===
        belt_rect = pygame.Rect(cx - int(1.2 * b) + lean_offset, chest_rect.bottom - 3, int(2.4 * b), int(0.8 * b))
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
            nx = buckle_cx + int(_cos(num_angle) * num_r)
            ny = buckle_cy + int(_sin(num_angle) * num_r)
            pygame.draw.circle(screen, p["gold_dark"], (int(nx), int(ny)), 1)
        # 시계 바늘
        hour_angle = self.time * 0.5 - math.pi / 2
        min_angle = self.time * 3 - math.pi / 2
        pygame.draw.line(screen, p["gold_dark"], (buckle_cx, buckle_cy),
                        (buckle_cx + int(_cos(hour_angle) * 0.12 * b), buckle_cy + int(_sin(hour_angle) * 0.12 * b)), 2)
        pygame.draw.line(screen, p["gold_shadow"], (buckle_cx, buckle_cy),
                        (buckle_cx + int(_cos(min_angle) * 0.18 * b), buckle_cy + int(_sin(min_angle) * 0.18 * b)), 1)

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
                mx1 = shoulder_x + int(_cos(mark_angle) * (mark_r - mark_len))
                my1 = shoulder_y + int(_sin(mark_angle) * (mark_r - mark_len))
                mx2 = shoulder_x + int(_cos(mark_angle) * mark_r)
                my2 = shoulder_y + int(_sin(mark_angle) * mark_r)
                pygame.draw.line(screen, p["gold_dark"], (mx1, my1), (mx2, my2), 1)

            # 시계 바늘
            hour_angle = self.time * 0.3 * side - math.pi / 2
            min_angle = self.time * 2 * side - math.pi / 2
            sec_angle = self.time * 6 * side - math.pi / 2
            # 시침
            pygame.draw.line(screen, p["gold_dark"], (shoulder_x, shoulder_y),
                           (shoulder_x + int(_cos(hour_angle) * (shoulder_r - 8)), shoulder_y + int(_sin(hour_angle) * (shoulder_r - 8))), 2)
            # 분침
            pygame.draw.line(screen, p["gold_shadow"], (shoulder_x, shoulder_y),
                           (shoulder_x + int(_cos(min_angle) * (shoulder_r - 5)), shoulder_y + int(_sin(min_angle) * (shoulder_r - 5))), 1)
            # 초침 (빨간색 느낌)
            pygame.draw.line(screen, (200, 150, 100), (shoulder_x, shoulder_y),
                           (shoulder_x + int(_cos(sec_angle) * (shoulder_r - 4)), shoulder_y + int(_sin(sec_angle) * (shoulder_r - 4))), 1)
            # 중심 점
            pygame.draw.circle(screen, p["gold"], (shoulder_x, shoulder_y), max(1, int(0.08 * b)))

        # === 팔 (로브 소매 + 어깨 들썩임) ===
        _staff_outward = anim.get("staff_hold_outward", False)
        _deferred_raised_arm = None  # 중력조작 시 올린 팔은 머리 뒤에 그리기 위해 지연
        for side in [-1, 1]:
            shoulder_bob_offset = int(shoulder_bob * 0.3 * b)
            shoulder = (cx + side * int(1.2 * b) + lean_offset, torso_y + int(0.3 * b) + shoulder_bob_offset)
            # 중력조작 시전 중 왼팔(지팡이 없는 손)은 머리 위로 → 머리 뒤에 그려야 보임
            if _staff_outward and side == -1:
                elbow = (shoulder[0] - int(0.3 * b), torso_y - int(1.8 * b))
                wrist = (elbow[0] - int(0.2 * b), torso_y - int(3.0 * b))
                _deferred_raised_arm = (shoulder, elbow, wrist)
                continue
            else:
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
            # 후드 아래로 흘러나오는 긴 머리카락 (뒷모습)
            for strand in range(5):
                sx = head_rect.left + int(0.25 * b) + strand * int(0.25 * b)
                sy = head_rect.bottom - int(0.1 * b)
                strand_len = int(1.8 * b) + int(strand % 2 * 0.25 * b)
                wave_off = int(_sin(self.time * 1.8 + strand * 0.8) * 0.08 * b)
                h_color = p["hair"] if strand % 2 == 0 else p["hair_light"]
                mid_y = sy + strand_len // 2
                pygame.draw.line(screen, h_color, (sx, sy), (sx + wave_off, mid_y), max(2, int(0.12 * b)))
                pygame.draw.line(screen, h_color, (sx + wave_off, mid_y), (sx - wave_off, sy + strand_len), max(1, int(0.08 * b)))
        else:
            # 정면 - 얼굴 (여성)
            face_rect = head_rect.inflate(-int(0.6 * b), -int(0.5 * b))
            face_rect.move_ip(0, int(0.25 * b))
            # 얼굴 그림자
            pygame.draw.ellipse(screen, p["skin_shadow"], face_rect.inflate(2, 2))
            pygame.draw.ellipse(screen, p["skin"], face_rect)

            # 후드 아래로 흘러나오는 긴 머리카락 (양쪽)
            for side in [-1, 1]:
                hair_base_x = face_rect.centerx + side * int(0.45 * b)
                hair_base_y = face_rect.top + int(0.1 * b)
                for strand in range(3):
                    sx = hair_base_x + side * int(strand * 0.08 * b)
                    sy_top = hair_base_y + int(strand * 0.1 * b)
                    sy_bot = sy_top + int(1.6 * b) + int(strand * 0.15 * b)
                    sw = max(2, int(0.14 * b) - strand)
                    wave_off = int(_sin(self.time * 1.8 + strand * 0.6) * 0.06 * b)
                    h_color = p["hair"] if strand % 2 == 0 else p["hair_light"]
                    mid_y = (sy_top + sy_bot) // 2
                    pygame.draw.line(screen, h_color, (sx, sy_top), (sx + wave_off, mid_y), sw)
                    pygame.draw.line(screen, h_color, (sx + wave_off, mid_y), (sx - wave_off, sy_bot), max(1, sw - 1))

            # 시간의 눈 (시계 무늬 홍채, 더 정교함)
            eye_y = face_rect.centery - int(0.05 * b)
            for side in [-1, 1]:
                eye_x = face_rect.centerx + side * int(0.28 * b)
                eye_r = max(2, int(0.18 * b))

                # 눈 글로우
                glow_surf = self._get_surface(int(0.6 * b), int(0.6 * b))
                pygame.draw.circle(glow_surf, (*p["eye_glow"], int(50 * time_pulse)), (int(0.3 * b), int(0.3 * b)), int(0.25 * b))
                screen.blit(glow_surf, (eye_x - int(0.3 * b), eye_y - int(0.3 * b)), special_flags=pygame.BLEND_ADD)

                # 눈 외곽
                pygame.draw.circle(screen, (100, 90, 80), (eye_x, eye_y), eye_r + 1)
                # 눈 본체
                pygame.draw.circle(screen, p["eye"], (eye_x, eye_y), eye_r)
                # 시계 바늘 홍채
                needle_angle1 = self.time * 4
                needle_angle2 = self.time * 1.5
                n1x = eye_x + int(_cos(needle_angle1) * eye_r * 0.6)
                n1y = eye_y + int(_sin(needle_angle1) * eye_r * 0.6)
                n2x = eye_x + int(_cos(needle_angle2) * eye_r * 0.4)
                n2y = eye_y + int(_sin(needle_angle2) * eye_r * 0.4)
                pygame.draw.line(screen, p["gold_dark"], (eye_x, eye_y), (n1x, n1y), 1)
                pygame.draw.line(screen, p["gold_shadow"], (eye_x, eye_y), (n2x, n2y), 1)
                # 하이라이트
                pygame.draw.circle(screen, (255, 255, 255), (eye_x - 1, eye_y - 1), max(1, eye_r // 3))

                # 속눈썹 (여성)
                for li in range(3):
                    lash_angle = math.pi * 1.1 + side * (0.15 + li * 0.2)
                    lash_len = int(0.1 * b) + li
                    lx = eye_x + int(_cos(lash_angle) * lash_len)
                    ly = (eye_y - eye_r - 1) + int(_sin(lash_angle) * lash_len)
                    pygame.draw.line(screen, p["eyelash"], (eye_x, eye_y - eye_r - 1), (lx, ly), 1)

            # 콧대
            pygame.draw.line(screen, p["skin_shadow"], (face_rect.centerx, eye_y + int(0.1 * b)),
                           (face_rect.centerx, face_rect.bottom - int(0.3 * b)), 1)

            # 입술 (여성)
            lip_y = face_rect.bottom - int(0.18 * b)
            lip_w = int(0.22 * b)
            lip_h = int(0.08 * b)
            pygame.draw.ellipse(screen, p["lip"],
                              (face_rect.centerx - lip_w, lip_y - lip_h // 2, lip_w * 2, lip_h))
            pygame.draw.ellipse(screen, p["lip_light"],
                              (face_rect.centerx - lip_w + 2, lip_y - lip_h // 2, lip_w * 2 - 4, lip_h - 2))

        # === 중력조작 시 올린 왼팔 (머리 위에 그려야 보임) ===
        if _deferred_raised_arm:
            _d_shoulder, _d_elbow, _d_wrist = _deferred_raised_arm
            pygame.draw.line(screen, p["robe"], _d_shoulder, _d_elbow, max(3, int(0.55 * b)))
            pygame.draw.line(screen, p["robe_mid"], _d_shoulder, _d_elbow, max(2, int(0.4 * b)))
            pygame.draw.line(screen, p["robe_mid"], _d_elbow, _d_wrist, max(3, int(0.5 * b)))
            pygame.draw.line(screen, p["robe_light"], _d_elbow, _d_wrist, max(2, int(0.35 * b)))
            pygame.draw.circle(screen, p["gold_dark"], _d_wrist, max(2, int(0.22 * b)))
            pygame.draw.circle(screen, p["skin"], (_d_wrist[0], _d_wrist[1] + int(0.15 * b)), max(2, int(0.25 * b)))
            pygame.draw.circle(screen, p["skin_shadow"], (_d_wrist[0] + 1, _d_wrist[1] + int(0.15 * b) + 1), max(2, int(0.25 * b)))

        # === 시간의 지팡이 (모래시계 장식, 고퀄리티 + 스윙 애니메이션) ===
        swing_angle = anim.get("weapon_swing_angle", 0)
        staff_x = cx + int(2.5 * b) + lean_offset
        staff_top = head_y - int(0.5 * b)
        staff_bottom = cy + int(2.8 * b)
        # 피벗 = 지팡이 중앙(손잡이 위치)
        pv_x, pv_y = staff_x, (staff_top + staff_bottom) // 2
        rp = self._rotate_point

        # 스윙 시 회전 좌표 계산
        if swing_angle != 0:
            r_top = rp(staff_x, staff_top, pv_x, pv_y, swing_angle)
            r_bot = rp(staff_x, staff_bottom, pv_x, pv_y, swing_angle)
            r_top_shadow = rp(staff_x + 2, staff_top + 2, pv_x, pv_y, swing_angle)
            r_bot_shadow = rp(staff_x + 2, staff_bottom + 2, pv_x, pv_y, swing_angle)
            r_top_hl = rp(staff_x - 1, staff_top, pv_x, pv_y, swing_angle)
            r_bot_hl = rp(staff_x - 1, staff_bottom, pv_x, pv_y, swing_angle)
        else:
            r_top = (staff_x, staff_top)
            r_bot = (staff_x, staff_bottom)
            r_top_shadow = (staff_x + 2, staff_top + 2)
            r_bot_shadow = (staff_x + 2, staff_bottom + 2)
            r_top_hl = (staff_x - 1, staff_top)
            r_bot_hl = (staff_x - 1, staff_bottom)

        # 지팡이 그림자
        pygame.draw.line(screen, p["gold_shadow"], r_top_shadow, r_bot_shadow, max(3, int(0.3 * b)))
        # 지팡이 본체
        pygame.draw.line(screen, p["gold_dark"], r_top, r_bot, max(3, int(0.28 * b)))
        pygame.draw.line(screen, p["gold"], r_top_hl, r_bot_hl, max(2, int(0.18 * b)))
        # 지팡이 장식 링
        for ring_y in [staff_top + int(0.5 * b), staff_bottom - int(0.5 * b), (staff_top + staff_bottom) // 2]:
            ring_pos = rp(staff_x, ring_y, pv_x, pv_y, swing_angle) if swing_angle != 0 else (staff_x, ring_y)
            pygame.draw.circle(screen, p["gold_light"], ring_pos, max(2, int(0.18 * b)))
            pygame.draw.circle(screen, p["gold_dark"], ring_pos, max(2, int(0.18 * b)), 1)

        # 모래시계 장식 (더 정교함) - 피벗 기준 회전
        hourglass_y = staff_top - int(0.8 * b)
        hourglass_h = int(1.0 * b)
        hourglass_w = int(0.45 * b)
        # 모래시계 중심 회전
        hg_cx = staff_x
        hg_cy = hourglass_y + hourglass_h // 2
        if swing_angle != 0:
            r_hg = rp(hg_cx, hg_cy, pv_x, pv_y, swing_angle)
            hg_ox, hg_oy = r_hg[0] - hg_cx, r_hg[1] - hg_cy  # 오프셋
        else:
            hg_ox, hg_oy = 0, 0

        # 모래시계 프레임
        frame_rect = (staff_x - hourglass_w + hg_ox, hourglass_y - int(0.1 * b) + hg_oy, hourglass_w * 2, hourglass_h + int(0.2 * b))
        pygame.draw.rect(screen, p["gold_dark"], frame_rect, 2)
        # 상단 삼각형 (유리)
        pygame.draw.polygon(screen, p["clock_face"], [
            (staff_x - hourglass_w + 3 + hg_ox, hourglass_y + hg_oy),
            (staff_x + hourglass_w - 3 + hg_ox, hourglass_y + hg_oy),
            (staff_x + hg_ox, hourglass_y + hourglass_h // 2 - 2 + hg_oy),
        ])
        # 하단 삼각형 (유리)
        pygame.draw.polygon(screen, p["clock_face"], [
            (staff_x + hg_ox, hourglass_y + hourglass_h // 2 + 2 + hg_oy),
            (staff_x - hourglass_w + 3 + hg_ox, hourglass_y + hourglass_h + hg_oy),
            (staff_x + hourglass_w - 3 + hg_ox, hourglass_y + hourglass_h + hg_oy),
        ])
        # 모래 (상단 - 비워지는 중)
        sand_level = (self.time * 0.3) % 1
        sand_top_h = int((1 - sand_level) * hourglass_h * 0.35)
        if sand_top_h > 2:
            pygame.draw.polygon(screen, p["sand"], [
                (staff_x - int(hourglass_w * 0.6) + hg_ox, hourglass_y + 3 + hg_oy),
                (staff_x + int(hourglass_w * 0.6) + hg_ox, hourglass_y + 3 + hg_oy),
                (staff_x + hg_ox, hourglass_y + 3 + sand_top_h + hg_oy),
            ])
        # 모래 (하단 - 쌓이는 중)
        sand_bot_h = int(sand_level * hourglass_h * 0.35)
        if sand_bot_h > 2:
            sand_bot_y = hourglass_y + hourglass_h - 3 - sand_bot_h
            pygame.draw.polygon(screen, p["sand"], [
                (staff_x + hg_ox, sand_bot_y + hg_oy),
                (staff_x - int(hourglass_w * 0.5) + hg_ox, hourglass_y + hourglass_h - 3 + hg_oy),
                (staff_x + int(hourglass_w * 0.5) + hg_ox, hourglass_y + hourglass_h - 3 + hg_oy),
            ])
        # 떨어지는 모래 입자
        for i in range(3):
            sand_particle_y = hourglass_y + hourglass_h // 2 + int(((self.time * 2 + i * 0.3) % 1) * hourglass_h * 0.4)
            pygame.draw.circle(screen, p["sand"], (staff_x + hg_ox, int(sand_particle_y) + hg_oy), 1)

        # 모래시계 글로우
        glow_surf = self._get_surface(int(1.5 * b), int(1.8 * b))
        pygame.draw.ellipse(glow_surf, (*p["glow"], int(30 * time_pulse)), (0, 0, int(1.5 * b), int(1.8 * b)))
        screen.blit(glow_surf, (staff_x - int(0.75 * b) + hg_ox, hourglass_y - int(0.2 * b) + hg_oy), special_flags=pygame.BLEND_ADD)

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
        rage_pulse = (_sin(self.time * 3) + 1) * 0.5
        breath_cycle = _sin(self.time * 1.5) * 0.1

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

        # === 지옥의 오라 (배경 효과 - 강화) ===
        aura_size = int(6 * b)
        aura_surf = self._get_surface(aura_size * 2, aura_size * 2)
        # 외곽 어둠 오라 (검붉은 계열)
        for i in range(5):
            aura_alpha = int((16 - i * 3) * (0.6 + rage_pulse * 0.4))
            aura_r = int((3.0 - i * 0.5) * b)
            dark_r = max(0, min(255, 80 - i * 10))
            pygame.draw.circle(aura_surf, (dark_r, 10, 20, aura_alpha), (aura_size, aura_size), aura_r)
        # 내곽 불꽃 오라
        for i in range(6):
            fl_phase = self.time * 1.5 + i * 0.9
            fl_alpha = int((22 - i * 3) * (0.7 + rage_pulse * 0.3))
            fl_r = int((2.2 - i * 0.3) * b)
            fl_ox = int(_sin(fl_phase) * 0.15 * b)
            fl_oy = int(_cos(fl_phase * 0.8) * 0.1 * b)
            pygame.draw.circle(aura_surf, (*p["flame"], fl_alpha),
                             (aura_size + fl_ox, aura_size + fl_oy), fl_r)
        screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - int(1.5 * b) - aura_size // 2), special_flags=pygame.BLEND_ADD)

        # === 불꽃/불씨 파티클 시스템 (강화) ===
        for i in range(12):
            ember_phase = self.time * 2.5 + i * 0.55
            life = (self.time * 1.8 + i * 0.35) % 1.5
            life_ratio = life / 1.5
            ember_x = cx + int(_sin(ember_phase) * (1.2 + life_ratio * 1.0) * b) + lean_offset
            ember_y = torso_y + int(0.5 * b) - int(life_ratio * 4.0 * b)
            ember_alpha = int(200 * (1.0 - life_ratio) * (0.7 + rage_pulse * 0.3))
            ember_size = max(1, int(0.12 * b * (1.0 - life_ratio * 0.6)))
            if ember_alpha > 10 and ember_size > 0:
                ember_surf = self._get_surface(ember_size * 4, ember_size * 4)
                if life_ratio < 0.3:
                    e_col = p["flame_inner"]
                elif life_ratio < 0.6:
                    e_col = p["flame"]
                else:
                    e_col = (200, 80, 30)
                pygame.draw.circle(ember_surf, (*e_col, ember_alpha),
                                 (ember_size * 2, ember_size * 2), ember_size)
                screen.blit(ember_surf, (int(ember_x) - ember_size * 2, int(ember_y) - ember_size * 2),
                           special_flags=pygame.BLEND_ADD)

        # === 열기 왜곡 (머리 위 아지랑이) ===
        heat_w = int(3 * b)
        heat_h = int(2 * b)
        heat_surf = self._get_surface(heat_w, heat_h)
        for hi in range(4):
            h_phase = self.time * 3.0 + hi * 1.5
            h_y_off = int(_sin(h_phase) * 0.2 * b)
            h_x_off = int(_cos(h_phase * 0.6) * 0.3 * b)
            h_alpha = int((20 - hi * 4) * (0.6 + rage_pulse * 0.4))
            h_len = int((1.0 - hi * 0.15) * b)
            pygame.draw.line(heat_surf, (*p["flame_inner"], h_alpha),
                           (heat_w // 2 - h_len + h_x_off, heat_h // 2 + h_y_off + hi * int(0.2 * b)),
                           (heat_w // 2 + h_len + h_x_off, heat_h // 2 + h_y_off + hi * int(0.2 * b)),
                           max(1, int(0.08 * b)))
        screen.blit(heat_surf, (cx - heat_w // 2 + lean_offset, torso_y - int(5 * b)),
                    special_flags=pygame.BLEND_ADD)

        # === 발밑 그을음 효과 (ground scorch) ===
        scorch_rx = int(2.2 * b)
        scorch_ry = int(0.5 * b)
        scorch_surf = self._get_surface(scorch_rx * 2, scorch_ry * 2)
        scorch_alpha = int(25 + 12 * rage_pulse)
        pygame.draw.ellipse(scorch_surf, (180, 50, 20, scorch_alpha),
                          (0, 0, scorch_rx * 2, scorch_ry * 2))
        pygame.draw.ellipse(scorch_surf, (255, 100, 40, int(scorch_alpha * 0.5)),
                          (scorch_rx // 3, scorch_ry // 3, scorch_rx * 4 // 3, scorch_ry * 4 // 3))
        scorch_foot_y = torso_y + int(4.5 * b)
        screen.blit(scorch_surf, (cx - scorch_rx + lean_offset, scorch_foot_y),
                    special_flags=pygame.BLEND_ADD)

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
            tx = tattoo_cx + int(_cos(angle) * t_r * 0.8)
            ty = tattoo_cy + int(_sin(angle) * t_r * 0.6)
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
                spike_tip_x = shoulder_x + int(_cos(spike_angle) * (shoulder_r + spike_len))
                spike_tip_y = shoulder_y + int(_sin(spike_angle) * (shoulder_r + spike_len))
                spike_base1_x = shoulder_x + int(_cos(spike_angle + 0.3) * shoulder_r)
                spike_base1_y = shoulder_y + int(_sin(spike_angle + 0.3) * shoulder_r)
                spike_base2_x = shoulder_x + int(_cos(spike_angle - 0.3) * shoulder_r)
                spike_base2_y = shoulder_y + int(_sin(spike_angle - 0.3) * shoulder_r)

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
            arm_swing = int(current_swing * 0.5 * b)  # 각도만 살짝 흔드는 수준
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

            # 뿔 뿌리 마그마 글로우 (horn glow)
            horn_glow_r = int(0.4 * b)
            horn_glow_surf = self._get_surface(horn_glow_r * 2, horn_glow_r * 2)
            hg_alpha = int(35 + 20 * rage_pulse)
            pygame.draw.circle(horn_glow_surf, (255, 120, 40, hg_alpha),
                             (horn_glow_r, horn_glow_r), horn_glow_r)
            pygame.draw.circle(horn_glow_surf, (255, 200, 100, int(hg_alpha * 0.6)),
                             (horn_glow_r, horn_glow_r), int(horn_glow_r * 0.5))
            screen.blit(horn_glow_surf,
                       (horn_base_x - horn_glow_r, horn_base_y - horn_glow_r),
                       special_flags=pygame.BLEND_ADD)

        if show_back:
            # 뒷모습 - 머리카락 상세
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            # 머리카락 줄기 (더 많이)
            for i in range(9):
                hx = head_rect.centerx + (i - 4) * int(0.25 * b)
                wave_off = _sin(self.time * 2 + i) * 0.05 * b
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
                    glow_surf = self._get_surface(glow_r * 2, glow_r * 2)
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

        # === 금봉 (쇠몽둥이, 고퀄리티 + 스윙 애니메이션) ===
        swing_angle = anim.get("weapon_swing_angle", 0)
        club_x = cx + int(2.7 * b) + lean_offset
        club_top = head_y + int(0.6 * b)
        club_bottom = cy + int(2.8 * b)
        # 피벗 = 자루 하단(손잡이)
        pivot_x, pivot_y = club_x, club_bottom

        # 스윙 시 회전 좌표 계산
        if swing_angle != 0:
            r = self._rotate_point
            r_top = r(club_x, club_top, pivot_x, pivot_y, swing_angle)
            r_top_shadow = r(club_x + 2, club_top + 2, pivot_x, pivot_y, swing_angle)
            r_bot_shadow = r(club_x + 2, club_bottom + 2, pivot_x, pivot_y, swing_angle)
            r_top_hl = r(club_x - 2, club_top, pivot_x, pivot_y, swing_angle)
            r_bot_hl = r(club_x - 2, club_bottom, pivot_x, pivot_y, swing_angle)
        else:
            r_top = (club_x, club_top)
            r_top_shadow = (club_x + 2, club_top + 2)
            r_bot_shadow = (club_x + 2, club_bottom + 2)
            r_top_hl = (club_x - 2, club_top)
            r_bot_hl = (club_x - 2, club_bottom)

        # 몽둥이 자루 그림자
        pygame.draw.line(screen, p["club_dark"], r_top_shadow, r_bot_shadow, max(3, int(0.35 * b)))
        # 몽둥이 자루
        pygame.draw.line(screen, p["club"], r_top, (pivot_x, pivot_y), max(3, int(0.32 * b)))
        pygame.draw.line(screen, p["club_light"], r_top_hl, r_bot_hl, max(1, int(0.15 * b)))

        # 자루 장식 링
        for ring_y in [club_top + int(0.3 * b), (club_top + club_bottom) // 2, club_bottom - int(0.3 * b)]:
            ring_pos = self._rotate_point(club_x, ring_y, pivot_x, pivot_y, swing_angle) if swing_angle != 0 else (club_x, ring_y)
            pygame.draw.circle(screen, p["armor_gold_dark"], ring_pos, max(2, int(0.2 * b)))
            pygame.draw.circle(screen, p["armor_gold"], ring_pos, max(1, int(0.15 * b)))

        # 몽둥이 머리 (타원형 + 스파이크) - 피벗 기준 회전
        club_head_y = club_top - int(0.65 * b)
        club_head_w = int(1.0 * b)
        club_head_h = int(1.1 * b)
        club_head_cx = club_x
        club_head_cy = club_head_y + club_head_h // 2

        # 머리 중심 회전
        if swing_angle != 0:
            r_head_center = self._rotate_point(club_head_cx, club_head_cy, pivot_x, pivot_y, swing_angle)
            r_head_y = r_head_center[1] - club_head_h // 2
            r_head_cx = r_head_center[0]
        else:
            r_head_center = (club_head_cx, club_head_cy)
            r_head_y = club_head_y
            r_head_cx = club_head_cx

        # 머리 그림자
        pygame.draw.ellipse(screen, p["club_dark"],
                          (r_head_cx - club_head_w // 2 + 2, r_head_y + 2, club_head_w, club_head_h))
        # 머리 본체
        pygame.draw.ellipse(screen, p["club"], (r_head_cx - club_head_w // 2, r_head_y, club_head_w, club_head_h))
        # 하이라이트
        inner_rect = (r_head_cx - int(club_head_w * 0.35), r_head_y + int(0.15 * b), int(club_head_w * 0.7), int(club_head_h * 0.7))
        pygame.draw.ellipse(screen, p["club_light"], inner_rect)

        # 금속 장식
        pygame.draw.ellipse(screen, p["club_metal"],
                          (r_head_cx - int(club_head_w * 0.3), r_head_y + int(0.2 * b), int(club_head_w * 0.6), int(club_head_h * 0.6)))
        pygame.draw.ellipse(screen, p["club_metal_light"],
                          (r_head_cx - int(club_head_w * 0.2), r_head_y + int(0.25 * b), int(club_head_w * 0.35), int(club_head_h * 0.4)))

        # 스파이크 (6개, 더 크고 날카로움) - 회전된 머리 중심 기준
        for i in range(6):
            angle = i * math.pi / 3 + math.pi / 6
            spike_base_r = club_head_w // 2 - 2
            spike_len = int(0.4 * b)

            spike_base_x = r_head_center[0] + int(_cos(angle) * spike_base_r)
            spike_base_y = r_head_center[1] + int(_sin(angle) * spike_base_r * 0.9)
            spike_tip_x = r_head_center[0] + int(_cos(angle) * (spike_base_r + spike_len))
            spike_tip_y = r_head_center[1] + int(_sin(angle) * (spike_base_r + spike_len) * 0.9)

            # 스파이크 (원뿔형)
            pygame.draw.circle(screen, p["club_metal_light"], (spike_tip_x, spike_tip_y), max(2, int(0.12 * b)))
            pygame.draw.line(screen, p["club_metal"], (spike_base_x, spike_base_y), (spike_tip_x, spike_tip_y), max(2, int(0.15 * b)))
            pygame.draw.circle(screen, p["club_metal"], (spike_base_x, spike_base_y), max(2, int(0.1 * b)))

    # =========================================================================
    # 연화 - 인형사 (마리오네트를 조종하는 무녀) [고퀄리티 업그레이드]
    # =========================================================================
    def _draw_maria(self, screen, cx, cy, b, color, show_back, anim):
        """연화 - 인형사 (기묘한 인형들을 조종하는 무녀) [고퀄리티]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        shoulder_bob = anim.get("shoulder_bob", 0)
        # 팔/어깨 교차 스윙 (무겐 스타일)
        left_arm_swing = anim.get("left_arm_swing", 0)
        right_arm_swing = anim.get("right_arm_swing", 0)
        left_shoulder = anim.get("left_shoulder", 0)
        right_shoulder = anim.get("right_shoulder", 0)
        # 다리 애니메이션 변수 추출
        left_leg_lift = anim.get("left_leg", 0)
        right_leg_lift = anim.get("right_leg", 0)
        left_leg_sway = anim.get("left_leg_sway", 0)
        right_leg_sway = anim.get("right_leg_sway", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        # 기묘한 분위기 펄스
        eerie_pulse = (_sin(self.time * 1.5) + 1) * 0.5
        string_sway = _sin(self.time * 2.5) * 0.15

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
        aura_surf = self._get_surface(aura_size * 2, aura_size * 2)
        for i in range(3):
            aura_alpha = int((18 - i * 5) * eerie_pulse)
            aura_r = int((1.8 - i * 0.4) * b)
            pygame.draw.circle(aura_surf, (*p["aura"], aura_alpha), (aura_size, aura_size), aura_r)
        screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - int(0.8 * b) - aura_size // 2), special_flags=pygame.BLEND_ADD)

        # === 에테리얼 오라 (부드러운 핑크/라벤더 펄스 오라) ===
        eth_size = int(5.0 * b)
        eth_surf = self._get_surface(eth_size * 2, eth_size * 2)
        eth_cx_m, eth_cy_m = eth_size, eth_size
        eth_pulse = max(0, 0.4 + 0.6 * _sin(self.time * 2.0))
        for eth_ring in range(3):
            eth_hue = self.time * 1.2 + eth_ring * 0.8
            eth_r_c = int(200 + 55 * _sin(eth_hue))
            eth_g_c = int(140 + 50 * _sin(eth_hue + 1.5))
            eth_b_c = int(210 + 45 * _sin(eth_hue + 3.0))
            eth_alpha = int((20 - eth_ring * 6) * eth_pulse)
            eth_rad = int((2.5 - eth_ring * 0.5) * b)
            pygame.draw.circle(eth_surf, (eth_r_c, eth_g_c, eth_b_c, max(0, eth_alpha)),
                             (eth_cx_m, eth_cy_m), eth_rad)
        screen.blit(eth_surf, (cx - eth_size + lean_offset,
                               torso_y - int(0.8 * b) - eth_size // 2),
                   special_flags=pygame.BLEND_ADD)

        # === 매직 서클 글로우 (캐릭터 아래 소환진) ===
        mc_w = int(3.2 * b)
        mc_h = int(0.8 * b)
        mc_surf = self._get_surface(mc_w * 2, mc_h * 2)
        mc_cx_s, mc_cy_s = mc_w, mc_h
        mc_pulse = max(0, 0.3 + 0.7 * _sin(self.time * 1.8))
        mc_alpha = max(0, int(25 * mc_pulse))
        # 외곽 타원
        pygame.draw.ellipse(mc_surf, (200, 130, 220, mc_alpha),
                          (mc_cx_s - int(1.4 * b), mc_cy_s - int(0.25 * b),
                           int(2.8 * b), int(0.5 * b)), max(1, int(0.06 * b)))
        # 내곽 타원
        pygame.draw.ellipse(mc_surf, (220, 160, 240, int(mc_alpha * 0.7)),
                          (mc_cx_s - int(1.0 * b), mc_cy_s - int(0.18 * b),
                           int(2.0 * b), int(0.36 * b)), max(1, int(0.04 * b)))
        # 글리프 마커 (원 위 작은 점 8개)
        for gi in range(8):
            g_angle = gi * (math.pi / 4) + self.time * 0.8
            gx = mc_cx_s + int(_cos(g_angle) * 1.2 * b)
            gy = mc_cy_s + int(_sin(g_angle) * 0.2 * b)
            pygame.draw.circle(mc_surf, (230, 180, 255, int(mc_alpha * 1.2)),
                             (gx, gy), max(1, int(0.05 * b)))
        screen.blit(mc_surf, (cx - mc_w + lean_offset, cy + int(2.5 * b) - mc_h),
                   special_flags=pygame.BLEND_ADD)

        # === 드레스 하단 (고딕 빅토리안 프릴) ===
        # 치마 넘실거림 - 이동 시 관성으로 반대쪽으로 흔들림
        side_blend = anim.get("side_blend", 0)
        move_dir = anim.get("move_dir", 0)
        skirt_inertia = -move_dir * side_blend * 0.6 * b  # 이동 반대쪽으로 치마가 밀려남
        skirt_flow = _sin(self.time * 4.0) * side_blend * 0.3 * b  # 부드러운 넘실거림
        skirt_wave_boost = 1.0 + side_blend * 2.0  # 이동 시 물결 증폭

        # 다리 움직임에 따른 드레스 자락 들림 (발을 들면 해당 쪽 치마가 올라감)
        left_hem_lift = int(left_leg_lift * 0.2 * b)
        right_hem_lift = int(right_leg_lift * 0.2 * b)

        dress_points = [
            (cx - int(1.3 * b) + lean_offset, torso_y + int(1.65 * b)),
            (cx + int(1.3 * b) + lean_offset, torso_y + int(1.65 * b)),
            (cx + int(2.0 * b) + lean_offset + int(wave * 0.18 * skirt_wave_boost * b) + int(skirt_inertia + skirt_flow), cy + int(3.0 * b) - right_hem_lift),
            (cx - int(2.0 * b) + lean_offset - int(wave * 0.18 * skirt_wave_boost * b) + int(skirt_inertia + skirt_flow), cy + int(3.0 * b) - left_hem_lift),
        ]
        # 드레스 그림자
        shadow_points = [(p[0] + 2, p[1] + 2) for p in dress_points]
        pygame.draw.polygon(screen, p["dress_shadow"], shadow_points)
        pygame.draw.polygon(screen, p["dress"], dress_points)

        # 드레스 세로 주름 (이동 시 관성으로 주름이 비스듬히 흔들림)
        for i in range(7):
            fold_shift = int((skirt_inertia + skirt_flow) * (i - 3) * 0.08)
            fold_x = cx + (i - 3) * int(0.4 * b) + lean_offset + fold_shift
            fold_top = torso_y + int(1.7 * b)
            fold_bot = cy + int(2.8 * b) + int(wave * 0.05 * (i - 3) * skirt_wave_boost * b)
            pygame.draw.line(screen, p["dress_mid"], (fold_x, fold_top), (fold_x, fold_bot), 1)

        # 프릴 레이어 (5단계) - 아래 레이어일수록 넘실거림 강화 (천 물리)
        for layer in range(5):
            frill_y = torso_y + int(1.85 * b) + layer * int(0.32 * b)
            frill_w = int(1.35 * b) + layer * int(0.15 * b)
            wave_offset = int(wave * 0.03 * layer * b)
            # 아래 레이어일수록 관성 영향이 더 강함
            layer_factor = 1.0 + layer * 0.25
            layer_sway = int((skirt_inertia + skirt_flow) * layer_factor)

            # 프릴 물결 패턴 (이동 시 진폭 증폭 + 레이어별 위상 차이)
            frill_points = []
            segments = 12
            frill_wave_amp = 0.08 + side_blend * 0.14  # 정지: 0.08, 이동: 최대 0.22
            layer_phase = layer * 0.3  # 위→아래로 물결 전파 효과
            for seg in range(segments + 1):
                fx = cx - frill_w + int(seg * frill_w * 2 / segments) + lean_offset + layer_sway
                fy = frill_y + int(_sin(seg * 0.8 + self.time * 3 - layer_phase) * frill_wave_amp * b)
                frill_points.append((fx, fy))

            for seg in range(len(frill_points) - 1):
                pygame.draw.line(screen, p["lace"], frill_points[seg], frill_points[seg + 1], 1)

            # 레이스 장식
            if layer % 2 == 0:
                pygame.draw.arc(screen, p["dress_light"],
                              (cx - frill_w + lean_offset + wave_offset + layer_sway, frill_y - int(0.05 * b), frill_w * 2, int(0.35 * b)),
                              math.radians(180), math.radians(360), 2)

        # 발끝 (발레 슈즈) - 걸음 모션 적용
        for side in [-1, 1]:
            # 다리별 애니메이션 오프셋 계산
            leg_lift = left_leg_lift if side == -1 else right_leg_lift
            leg_sway = left_leg_sway if side == -1 else right_leg_sway
            foot_lift_y = int(leg_lift * 0.4 * b)    # 발 들어올림 (Y) - 충분한 높이
            foot_sway_x = int(leg_sway * 0.7 * b)    # 발 앞뒤 스윙 (X) - 넓은 보폭

            # 이동 시 다리 벌림 (정지: 0.55, 이동: 최대 0.85)
            # 들어올린 발은 더 바깥으로 벌어짐 (자연스러운 보행)
            leg_spread = 0.55 + side_blend * 0.3 + leg_lift * 0.08
            # 들어올린 발은 살짝 앞으로 기울어짐 (발레 포인트)
            foot_tilt = leg_lift * 0.18 * b

            foot_x = cx + side * int(leg_spread * b) + lean_offset + foot_sway_x
            foot_y = cy + int(2.6 * b) - foot_lift_y

            # 발목~종아리 (드레스 아래로 살짝 보이는 스타킹)
            if foot_lift_y > int(0.03 * b):
                ankle_x = foot_x
                ankle_top_y = foot_y - int(0.15 * b)
                # 스타킹 (짧은 종아리 라인)
                pygame.draw.line(screen, p["skin_shadow"],
                               (ankle_x, ankle_top_y),
                               (ankle_x, foot_y - int(0.02 * b)), max(1, int(0.18 * b)))
                pygame.draw.line(screen, p["skin"],
                               (ankle_x - 1, ankle_top_y),
                               (ankle_x - 1, foot_y - int(0.02 * b)), max(1, int(0.14 * b)))

            # 슈즈 그림자 (바닥에 고정 - 들어올린 발은 그림자 작아짐)
            shadow_scale = max(0.4, 1.0 - leg_lift * 0.15)
            shadow_w = int(0.56 * b * shadow_scale)
            shadow_x = cx + side * int(leg_spread * b) + lean_offset + foot_sway_x
            shadow_y = cy + int(2.6 * b)
            pygame.draw.ellipse(screen, (40, 35, 50),
                              (shadow_x - shadow_w // 2 + 1, shadow_y + 1, shadow_w, int(0.2 * b * shadow_scale)))

            # 슈즈 본체 (발레 포인트 - 들어올릴수록 세로로 길어짐)
            shoe_w = int(0.52 * b) - int(foot_tilt * 0.3)
            shoe_h = int(0.3 * b) + int(foot_tilt * 0.2)
            pygame.draw.ellipse(screen, (55, 45, 65),
                              (foot_x - shoe_w // 2, foot_y - int(0.02 * b), shoe_w, shoe_h))
            # 슈즈 하이라이트
            pygame.draw.ellipse(screen, (75, 60, 85),
                              (foot_x - shoe_w // 2 + 2, foot_y, shoe_w - 4, shoe_h - 3), 1)

            # 리본 장식 (슈즈 위)
            pygame.draw.ellipse(screen, p["ribbon"],
                              (foot_x - int(0.1 * b), foot_y - int(0.08 * b), int(0.2 * b), int(0.12 * b)))
            # 리본 끈 (발목 감싸기 - 발레리나 스타일)
            if foot_lift_y > int(0.02 * b):
                ribbon_y = foot_y - int(0.12 * b)
                pygame.draw.line(screen, p["ribbon_dark"],
                               (foot_x - int(0.12 * b), ribbon_y),
                               (foot_x + side * int(0.2 * b), ribbon_y - int(0.1 * b)), 1)
                pygame.draw.line(screen, p["ribbon"],
                               (foot_x + int(0.12 * b), ribbon_y),
                               (foot_x - side * int(0.15 * b), ribbon_y - int(0.08 * b)), 1)

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

        # === 팔 + 마리오네트 실 (어깨 교차 들썩임 + 팔 스윙 + 올려치기) ===
        arm_slam = anim.get("arm_slam", 0)
        # arm_slam: -1=양팔 위로, +1=양팔 아래로(내려치기), 0=기본
        slam_active = abs(arm_slam) > 0.05

        for side in [-1, 1]:
            # 어깨 교차 들썩임 (왼/오 각각 다르게 - 무겐 스타일)
            current_shoulder_bob = left_shoulder if side == -1 else right_shoulder
            shoulder_y_offset = int(current_shoulder_bob * 0.35 * b + shoulder_bob * 0.25 * b)
            # 걸을 때 팔 교차 스윙
            current_arm_swing = left_arm_swing if side == -1 else right_arm_swing
            walk_arm_swing_x = int(current_arm_swing * 0.5 * b)

            shoulder = (cx + side * int(1.05 * b) + lean_offset,
                        torso_y + int(0.15 * b) + shoulder_y_offset)

            if slam_active:
                # 기본 팔꿈치/손목 오프셋 (어깨 기준 상대좌표)
                # 기본: 아래+바깥  올림(-1): 바깥+위 (V자)  내침(+1): 아래+안쪽
                t = abs(arm_slam)
                if arm_slam < 0:
                    # 올리기: V자 형태로 바깥+위로 (몸통 밖에서 보이도록)
                    elbow_dx = int(side * 0.45 * b * (1 - t) + side * 1.2 * b * t)
                    elbow_dy = int(0.6 * b * (1 - t) + (-0.7 * b) * t)
                    wrist_dx = int(side * 0.35 * b * (1 - t) + side * 0.4 * b * t)
                    wrist_dy = int(0.5 * b * (1 - t) + (-0.9 * b) * t)
                else:
                    # 내려치기: 아래+안쪽
                    elbow_dx = int(side * 0.45 * b * (1 - t) + side * 0.1 * b * t)
                    elbow_dy = int(0.6 * b * (1 - t) + 1.0 * b * t)
                    wrist_dx = int(side * 0.35 * b * (1 - t) + 0)
                    wrist_dy = int(0.5 * b * (1 - t) + 0.6 * b * t)
                elbow = (shoulder[0] + elbow_dx, shoulder[1] + elbow_dy)
                wrist = (elbow[0] + wrist_dx, elbow[1] + wrist_dy)
            else:
                # 걸을 때: 팔 교차 스윙 + 어깨 들썩임 연동
                elbow = (shoulder[0] + side * int(0.45 * b) + walk_arm_swing_x,
                         torso_y + int(0.75 * b) + shoulder_y_offset)
                hand_wave_x = _sin(self.time * 2 + side) * 0.15 * b
                hand_wave_y = _cos(self.time * 2 + side) * 0.08 * b
                wrist = (elbow[0] + side * int(0.35 * b) + int(walk_arm_swing_x * 0.5) + int(hand_wave_x),
                        torso_y + int(1.25 * b) + int(shoulder_y_offset * 0.5) + int(hand_wave_y))

            # 어깨 퍼프 (레이스 장식) - 팔 방향을 따라감
            puff_cx = (shoulder[0] + elbow[0]) // 2
            puff_cy = (shoulder[1] + elbow[1]) // 2
            puff_w, puff_h = int(0.9 * b), int(0.8 * b)
            puff_rect = pygame.Rect(puff_cx - puff_w // 2, puff_cy - puff_h // 2, puff_w, puff_h)
            pygame.draw.ellipse(screen, p["dress_dark"], puff_rect.inflate(2, 2))
            pygame.draw.ellipse(screen, p["dress_light"], puff_rect)
            pygame.draw.ellipse(screen, p["dress_mid"], puff_rect.inflate(-int(0.2 * b), -int(0.15 * b)))

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
                fx = wrist[0] + int(_cos(finger_angle + self.time * 0.5) * finger_len)
                fy = wrist[1] + int(_sin(finger_angle) * finger_len) + int(0.1 * b)
                pygame.draw.line(screen, p["skin"], wrist, (fx, fy), max(1, int(0.06 * b)))

            # === 핸드 글로우 이펙트 (슬램 활성 시 핑크/퍼플 글로우) ===
            hand_glow_intensity = abs(arm_slam) if slam_active else 0.15
            hand_glow_r = int(0.55 * b)
            hand_glow_surf = self._get_surface(hand_glow_r * 2, hand_glow_r * 2)
            hg_pulse = 0.5 + 0.5 * _sin(self.time * 4.5 + side * 1.5)
            hg_alpha = int(max(8, 40 * hand_glow_intensity) * hg_pulse)
            pygame.draw.circle(hand_glow_surf,
                             (220, 140, 200, min(255, hg_alpha)),
                             (hand_glow_r, hand_glow_r), hand_glow_r)
            pygame.draw.circle(hand_glow_surf,
                             (240, 180, 230, min(255, int(hg_alpha * 0.6))),
                             (hand_glow_r, hand_glow_r), int(hand_glow_r * 0.5))
            screen.blit(hand_glow_surf,
                       (wrist[0] - hand_glow_r, wrist[1] - hand_glow_r),
                       special_flags=pygame.BLEND_ADD)

            # === 마리오네트 실 (손가락에서 인형으로) ===
            puppet_base_y = torso_y + int(2.15 * b)
            puppet_base_x = wrist[0] + side * int(0.6 * b)

            # 실 (5개, 각 손가락에서)
            for j in range(5):
                string_start_x = wrist[0] + (j - 2) * int(0.06 * b)
                string_start_y = wrist[1] + int(0.12 * b)
                target_x = puppet_base_x + (j - 2) * int(0.12 * b)
                target_y = puppet_base_y - int(0.35 * b) + int(_sin(self.time * 3 + j) * 0.05 * b)

                # 실 흔들림 (곡선)
                mid_x = (string_start_x + target_x) // 2 + int(string_sway * b * (j - 2))
                mid_y = (string_start_y + target_y) // 2

                pygame.draw.line(screen, p["string_shadow"], (string_start_x, string_start_y), (mid_x, mid_y), 1)
                pygame.draw.line(screen, p["string"], (mid_x, mid_y), (target_x, target_y), 1)

                # === 퍼펫 스트링 글로우 (실에 은은한 마법빛) ===
                str_glow_pulse = max(0, 0.3 + 0.7 * _sin(self.time * 3.0 + j * 0.9))
                str_glow_alpha = max(0, min(255, int(20 * str_glow_pulse * eerie_pulse)))
                str_gl_r = max(int(0.12 * b), 2)
                str_gl_surf = self._get_surface(str_gl_r * 2, str_gl_r * 2)
                pygame.draw.circle(str_gl_surf, (200, 160, 230, str_glow_alpha),
                                 (str_gl_r, str_gl_r), str_gl_r)
                screen.blit(str_gl_surf,
                           (string_start_x - str_gl_r, string_start_y - str_gl_r),
                           special_flags=pygame.BLEND_ADD)
                # 실 중간점 글로우
                str_gl_surf2 = self._get_surface(str_gl_r * 2, str_gl_r * 2)
                pygame.draw.circle(str_gl_surf2, (210, 170, 240, int(str_glow_alpha * 0.8)),
                                 (str_gl_r, str_gl_r), str_gl_r)
                screen.blit(str_gl_surf2,
                           (mid_x - str_gl_r, mid_y - str_gl_r),
                           special_flags=pygame.BLEND_ADD)

        # === 퍼펫 컨트롤 스트링 (위쪽 조종 실 글로우) ===
        pcs_glow_pulse = max(0, 0.4 + 0.6 * _sin(self.time * 2.2))
        pcs_surf_h = int(3.5 * b)
        pcs_surf_w = int(4.0 * b)
        pcs_surf = self._get_surface(pcs_surf_w, pcs_surf_h)
        pcs_ox, pcs_oy = pcs_surf_w // 2, pcs_surf_h
        for ps_i in range(5):
            ps_x = pcs_ox + (ps_i - 2) * int(0.35 * b)
            ps_sway = int(_sin(self.time * 2.0 + ps_i * 0.7) * 0.12 * b)
            ps_x += ps_sway
            ps_alpha = int(18 * pcs_glow_pulse)
            pygame.draw.line(pcs_surf, (200, 160, 230, ps_alpha),
                           (ps_x, 0), (ps_x + int(ps_sway * 0.5), pcs_oy), max(1, int(0.04 * b)))
            pygame.draw.circle(pcs_surf, (220, 180, 250, int(ps_alpha * 1.3)),
                             (ps_x + int(ps_sway * 0.5), pcs_oy - int(0.1 * b)),
                             max(1, int(0.06 * b)))
        screen.blit(pcs_surf,
                   (cx - pcs_ox + lean_offset, torso_y - int(4.5 * b)),
                   special_flags=pygame.BLEND_ADD)

        # === 마리오네트 인형 (양쪽 아래, 더 상세) ===
        for side in [-1, 1]:
            puppet_x = cx + side * int(1.95 * b) + lean_offset
            puppet_bob = _sin(self.time * 3 + side * 2) * 0.25 * b
            puppet_y = torso_y + int(2.1 * b) + int(puppet_bob)
            puppet_tilt = _sin(self.time * 2.5 + side) * 0.15

            # 인형 그림자
            shadow_surf = self._get_surface(int(0.8 * b), int(0.4 * b))
            pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40), (0, 0, int(0.8 * b), int(0.4 * b)))
            screen.blit(shadow_surf, (puppet_x - int(0.4 * b), puppet_y + int(0.7 * b)))

            # 인형 다리 (관절)
            for leg_side in [-1, 1]:
                leg_x = puppet_x + leg_side * int(0.1 * b)
                leg_phase = _sin(self.time * 4 + leg_side + side) * 0.1 * b
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
                arm_wave = _sin(self.time * 5 + arm_side * side) * 0.08 * b
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
        head_y = torso_y - int(2.5 * b)
        head_w, head_h = int(2.2 * b), int(2.0 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        # 긴 머리카락 (양쪽으로 늘어짐, 물결 + 이동 시 관성으로 흔들림)
        hair_inertia = -move_dir * side_blend * 0.4 * b  # 이동 반대쪽으로 머리카락 밀림
        hair_walk_sway = wave * 0.08 * b  # 걸음 주기에 따른 흔들림

        for side in [-1, 1]:
            hair_x = head_rect.centerx + side * int(0.75 * b)
            hair_wave = _sin(self.time * 2 + side) * 0.08 * b

            # 머리카락 여러 가닥
            for strand in range(3):
                strand_offset = (strand - 1) * int(0.15 * b)
                # 아래로 갈수록 관성 영향이 더 강함
                strand_inertia = hair_inertia * (1.0 + strand * 0.3)
                hair_points = [
                    (hair_x + strand_offset - int(0.25 * b), head_rect.centery - int(0.1 * b)),
                    (hair_x + strand_offset + int(0.25 * b), head_rect.centery),
                    (hair_x + strand_offset + side * int(0.12 * b) + int(hair_wave + strand_inertia + hair_walk_sway), torso_y + int(1.2 * b) + strand * int(0.15 * b)),
                ]
                hair_color = p["hair"] if strand == 1 else p["hair_mid"]
                pygame.draw.polygon(screen, hair_color, hair_points)

        if show_back:
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            # 머리카락 결
            for i in range(7):
                hx = head_rect.left + int(0.25 * b) + i * int(0.25 * b)
                wave_off = _sin(self.time * 1.5 + i * 0.5) * 0.03 * b
                pygame.draw.line(screen, p["hair_highlight"],
                               (hx, head_rect.top + int(0.15 * b)),
                               (hx + int(wave_off), head_rect.bottom - int(0.1 * b)), 2)
            # 리본 (뒤에서 보이는 꼬리)
            ribbon_tail_y = head_rect.top + int(0.4 * b)
            for side in [-1, 1]:
                tail_wave = _sin(self.time * 3 + side) * 0.1 * b
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
                blush_surf = self._get_surface(int(0.25 * b), int(0.15 * b))
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
                    lx = eye_x + side * int(0.05 * b) + int(_cos(lash_angle) * eye_w * 0.4)
                    ly = eye_y - int(eye_h * 0.4)
                    pygame.draw.line(screen, p["hair"], (lx, ly), (lx + int(_cos(lash_angle - 0.5) * lash_len), ly - lash_len), 1)

                # === 돌 아이 스파클 글로우 (눈 반짝임 별 모양) ===
                sparkle_r = max(int(0.18 * b), 3)
                sparkle_surf = self._get_surface(sparkle_r * 2, sparkle_r * 2)
                sp_pulse = max(0, 0.3 + 0.7 * _sin(self.time * 5.0 + side * 2.5))
                sp_alpha = max(0, min(255, int(35 * sp_pulse)))
                sp_cx_s, sp_cy_s = sparkle_r, sparkle_r
                # 별 모양 (4방향 십자 + 대각선)
                sp_len = int(sparkle_r * 0.8)
                sp_short = int(sparkle_r * 0.5)
                for sp_dir in range(4):
                    sp_angle = sp_dir * (math.pi / 2) + self.time * 1.5
                    sp_ex = sp_cx_s + int(_cos(sp_angle) * sp_len)
                    sp_ey = sp_cy_s + int(_sin(sp_angle) * sp_len)
                    pygame.draw.line(sparkle_surf, (255, 230, 255, sp_alpha),
                                   (sp_cx_s, sp_cy_s), (sp_ex, sp_ey), 1)
                for sp_dir in range(4):
                    sp_angle = sp_dir * (math.pi / 2) + math.pi / 4 + self.time * 1.5
                    sp_ex = sp_cx_s + int(_cos(sp_angle) * sp_short)
                    sp_ey = sp_cy_s + int(_sin(sp_angle) * sp_short)
                    pygame.draw.line(sparkle_surf, (240, 200, 255, int(sp_alpha * 0.7)),
                                   (sp_cx_s, sp_cy_s), (sp_ex, sp_ey), 1)
                # 중심 글로우 점
                pygame.draw.circle(sparkle_surf, (255, 240, 255, sp_alpha),
                                 (sp_cx_s, sp_cy_s), max(1, int(0.04 * b)))
                screen.blit(sparkle_surf,
                           (eye_x - 2 - sparkle_r, eye_y - 2 - sparkle_r),
                           special_flags=pygame.BLEND_ADD)

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
                strand_wave = _sin(self.time * 2 + i * 0.8) * 0.02 * b
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
                tail_wave = _sin(self.time * 2.5 + side) * 0.08 * b
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
        flame_pulse = (_sin(self.time * 4) + 1) * 0.5
        heat_wave = _sin(self.time * 6) * 0.1

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
        aura_surf = self._get_surface(aura_size * 2, aura_size * 2)
        for i in range(4):
            aura_alpha = int((25 - i * 6) * (0.6 + flame_pulse * 0.4))
            aura_r = int((2.2 - i * 0.4) * b)
            pygame.draw.circle(aura_surf, (*p["flame_edge"], aura_alpha), (aura_size, aura_size), aura_r)
        screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - int(1.2 * b) - aura_size // 2), special_flags=pygame.BLEND_ADD)

        # 불씨 파티클
        for i in range(8):
            ember_x = cx + int(_sin(self.time * 3 + i * 1.1) * 2 * b) + lean_offset
            ember_y = torso_y + int(1 * b) - int(((self.time * 1.5 + i * 0.3) % 1) * 3 * b)
            ember_alpha = int(200 * (1 - ((self.time * 1.5 + i * 0.3) % 1)))
            ember_size = max(1, int(0.1 * b * (1 - ((self.time * 1.5 + i * 0.3) % 1))))
            ember_surf = self._get_surface(ember_size * 4, ember_size * 4)
            ember_color = p["flame_core"] if i % 2 == 0 else p["flame"]
            pygame.draw.circle(ember_surf, (*ember_color, ember_alpha), (ember_size * 2, ember_size * 2), ember_size)
            screen.blit(ember_surf, (int(ember_x) - ember_size * 2, int(ember_y) - ember_size * 2), special_flags=pygame.BLEND_ADD)

        # === 망토 (드래곤 날개처럼 펄럭임) ===
        cape_wave = _sin(self.time * 3) * 0.25
        cape_wave2 = _sin(self.time * 4.5) * 0.15

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
            fold_wave = _sin(self.time * 3 + i * 0.5) * 0.1 * b
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
        emblem_glow = self._get_surface(emblem_glow_size, emblem_glow_size)
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
        _weapon_swing = anim.get("weapon_swing_angle", 0)
        _right_wrist = None  # 불꽃 효과 위치 추적용
        for side in [-1, 1]:
            current_swing = left_arm_swing if side == -1 else right_arm_swing
            current_shoulder_bob = left_shoulder if side == -1 else right_shoulder
            arm_swing = int(current_swing * 0.5 * b)  # 각도만 살짝 흔드는 수준
            # 어깨 들썩임
            shoulder_y_offset = int(current_shoulder_bob * 0.35 * b + shoulder_bob * 0.25 * b)
            shoulder = (cx + side * int(1.4 * b) + lean_offset, torso_y + int(0.25 * b) + shoulder_y_offset)
            # 오른팔 공 타격 시 안쪽으로 휘두르기
            if side == 1 and _weapon_swing != 0:
                swing_x = int(_weapon_swing * 4.0 * b)
                swing_y = int(abs(_weapon_swing) * 1.5 * b)
                elbow = (int(shoulder[0] + int(0.55 * b) + swing_x), torso_y + int(1.0 * b) + shoulder_y_offset - swing_y)
                wrist = (int(elbow[0] + int(0.45 * b) + int(swing_x * 0.6)), torso_y + int(1.6 * b) + int(shoulder_y_offset * 0.5) - int(swing_y * 0.6))
            else:
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
                claw_x = wrist[0] + int(_cos(claw_angle) * 0.35 * b)
                claw_y = wrist[1] + int(_sin(claw_angle + math.pi / 2) * 0.25 * b) + int(0.18 * b)
                claw_tip_x = claw_x + int(_cos(claw_angle) * claw_len)
                claw_tip_y = claw_y + claw_len
                pygame.draw.line(screen, p["horn"], wrist, (claw_x, claw_y), max(2, int(0.08 * b)))
                pygame.draw.line(screen, p["horn_light"], (claw_x, claw_y), (claw_tip_x, claw_tip_y), max(1, int(0.05 * b)))

            # 오른손 wrist 저장 (불꽃 효과 위치용)
            if side == 1:
                _right_wrist = wrist

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
                    glow_surf = self._get_surface(glow_w, glow_h)
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
        if _right_wrist:
            flame_x = _right_wrist[0]
            flame_y = _right_wrist[1] - int(0.4 * b)
        else:
            flame_x = cx + int(2.4 * b) + lean_offset
            flame_y = torso_y + int(1.2 * b)

        # 불꽃 오라
        flame_aura = self._get_surface(int(1.5 * b), int(2 * b))
        pygame.draw.ellipse(flame_aura, (*p["flame_edge"], int(40 * flame_pulse)), (0, 0, int(1.5 * b), int(2 * b)))
        screen.blit(flame_aura, (flame_x - int(0.75 * b), flame_y - int(1.5 * b)), special_flags=pygame.BLEND_ADD)

        # 불꽃 파티클
        for i in range(8):
            f_angle = self.time * 6 + i * 0.7
            f_radius = 0.35 * b * (0.5 + (i % 3) * 0.2)
            f_x = flame_x + int(_cos(f_angle) * f_radius)
            f_y = flame_y - int(0.4 * b) + int(_sin(f_angle * 2) * 0.25 * b) - i * int(0.18 * b)
            f_size = max(2, int(0.22 * b) - i)

            if f_size > 0:
                # 불꽃 글로우
                if i < 3:
                    glow_size = f_size * 3
                    glow_surf = self._get_surface(glow_size, glow_size)
                    pygame.draw.circle(glow_surf, (*p["flame_mid"], 100), (glow_size // 2, glow_size // 2), glow_size // 2)
                    screen.blit(glow_surf, (f_x - glow_size // 2, f_y - glow_size // 2), special_flags=pygame.BLEND_ADD)

                # 불꽃 본체
                flame_color = p["flame_core"] if i < 2 else (p["flame_mid"] if i < 4 else p["flame"])
                pygame.draw.circle(screen, flame_color, (f_x, f_y), f_size)

    # =========================================================================
    # 마리 - 스팀펑크 메카닉 (기계 팔과 톱니바퀴) [고퀄리티 업그레이드] [여성]
    # =========================================================================
    def _draw_gear(self, screen, cx, cy, b, color, show_back, anim):
        """마리 - 스팀펑크 메카닉 여성 (증기 기관과 톱니바퀴로 무장한 천재 발명가) [고퀄리티]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        left_arm_swing = anim.get("left_arm_swing", 0)
        right_arm_swing = anim.get("right_arm_swing", 0)
        shoulder_bob = anim.get("shoulder_bob", 0)
        # 다리 애니메이션 파라미터 (안드로이드 기계식 걷기 모션)
        left_leg_lift = anim.get("left_leg", 0)
        right_leg_lift = anim.get("right_leg", 0)
        left_leg_sway = anim.get("left_leg_sway", 0)
        right_leg_sway = anim.get("right_leg_sway", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2 * b)

        # 기계 작동 펄스
        mech_pulse = (_sin(self.time * 4) + 1) * 0.5
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
            "skin": (235, 210, 195),
            "skin_shadow": (205, 180, 165),
            "hair": (60, 30, 15),
            "hair_light": (90, 55, 35),
            "hair_mid": (75, 42, 25),
            "lip": (200, 100, 100),
            "lip_light": (220, 130, 130),
            "eyelash": (40, 25, 15),
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
        aura_surf = self._get_surface(aura_size * 2, aura_size * 2)
        for i in range(3):
            aura_alpha = int((15 - i * 4) * mech_pulse)
            aura_r = int((1.6 - i * 0.4) * b)
            pygame.draw.circle(aura_surf, (*p["steam"], aura_alpha), (aura_size, aura_size), aura_r)
        screen.blit(aura_surf, (cx - aura_size + lean_offset, torso_y - int(0.8 * b) - aura_size // 2), special_flags=pygame.BLEND_ADD)

        # === 다리 (스팀펑크 레깅스 - 쿠로카게 스타일 걷기) ===
        hip_y = torso_y + int(2.0 * b)
        for side in [-1, 1]:
            # 쿠로카게 스타일 다리 움직임
            current_leg_sway = left_leg_sway if side == -1 else right_leg_sway
            current_leg_lift = left_leg_lift if side == -1 else right_leg_lift
            leg_sway_x = int(current_leg_sway * 0.5 * b)
            leg_lift_y = int(current_leg_lift * 0.25 * b)
            thigh_x = cx + side * int(0.52 * b) + lean_offset + leg_sway_x

            # 허벅지 (가죽 + 금속 스트랩)
            thigh_rect = pygame.Rect(thigh_x - int(0.44 * b), hip_y - leg_lift_y, int(0.88 * b), int(1.7 * b))
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
                gx = knee_cx + int(_cos(angle) * knee_gear_r)
                gy = knee_cy + int(_sin(angle) * knee_gear_r * 0.8)
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

        # === 몸통 (스팀펑크 코르셋 조끼) ===
        chest_w, chest_h = int(2.8 * b), int(2.15 * b)
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
            mx1 = gauge_cx + int(_cos(mark_angle) * (gauge_r - 4))
            my1 = gauge_cy + int(_sin(mark_angle) * (gauge_r - 4))
            mx2 = gauge_cx + int(_cos(mark_angle) * (gauge_r - 6))
            my2 = gauge_cy + int(_sin(mark_angle) * (gauge_r - 6))
            pygame.draw.line(screen, p["copper_dark"], (mx1, my1), (mx2, my2), 1)
        # 게이지 바늘
        needle_angle = _sin(self.time * 2) * 0.8 - math.pi / 4
        needle_len = gauge_r - 5
        nx = gauge_cx + int(_cos(needle_angle) * needle_len)
        ny = gauge_cy + int(_sin(needle_angle) * needle_len)
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
                           (aux_cx + int(_cos(angle) * inner_r), aux_cy + int(_sin(angle) * inner_r)),
                           (aux_cx + int(_cos(angle) * outer_r), aux_cy + int(_sin(angle) * outer_r)), 2)
        pygame.draw.circle(screen, p["gear"], (aux_cx, aux_cy), int(aux_r * 0.6))
        pygame.draw.circle(screen, p["gear_light"], (aux_cx, aux_cy), int(aux_r * 0.4))
        pygame.draw.circle(screen, p["brass_dark"], (aux_cx, aux_cy), max(1, int(0.05 * b)))

        # 파이프 연결
        pipe_y = device_rect.bottom - int(0.12 * b)
        pygame.draw.line(screen, p["copper_dark"], (device_rect.left + int(0.15 * b), pipe_y),
                        (device_rect.left - int(0.2 * b), pipe_y + int(0.15 * b)), max(2, int(0.08 * b)))
        pygame.draw.line(screen, p["copper_dark"], (device_rect.right - int(0.15 * b), pipe_y),
                        (device_rect.right + int(0.2 * b), pipe_y + int(0.15 * b)), max(2, int(0.08 * b)))

        # 허리 벨트 (도구 벨트, 코르셋 스타일)
        belt_rect = pygame.Rect(cx - int(1.3 * b) + lean_offset, chest_rect.bottom - 4, int(2.6 * b), int(0.75 * b))
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
                rx = shoulder_x + int(_cos(rivet_angle) * (shoulder_w * 0.35))
                ry = shoulder_y + int(_sin(rivet_angle) * (shoulder_h * 0.25))
                pygame.draw.circle(screen, p["rivet"], (rx, ry), max(1, int(0.04 * b)))

            # 톱니바퀴 장식 (회전)
            gear_r = int(0.35 * b)
            tooth_count = 8
            for i in range(tooth_count):
                angle = gear_spin * side + i * 2 * math.pi / tooth_count
                inner_r = gear_r * 0.65
                outer_r = gear_r
                gx_inner = shoulder_x + int(_cos(angle) * inner_r)
                gy_inner = shoulder_y + int(_sin(angle) * inner_r)
                gx_outer = shoulder_x + int(_cos(angle) * outer_r)
                gy_outer = shoulder_y + int(_sin(angle) * outer_r)
                pygame.draw.line(screen, p["brass_dark"], (gx_inner, gy_inner), (gx_outer, gy_outer), max(2, int(0.08 * b)))

            pygame.draw.circle(screen, p["copper_dark"], (shoulder_x, shoulder_y), max(3, int(0.25 * b)))
            pygame.draw.circle(screen, p["copper"], (shoulder_x, shoulder_y), max(2, int(0.2 * b)))
            pygame.draw.circle(screen, p["copper_light"], (shoulder_x - 1, shoulder_y - 1), max(1, int(0.1 * b)))

        # === 팔 (하나는 기계팔, 더 정교함 + 어깨 들썩임) ===
        _weapon_swing = anim.get("weapon_swing_angle", 0)
        for side in [-1, 1]:
            shoulder_bob_offset = int(shoulder_bob * 0.3 * b)
            shoulder = (cx + side * int(1.4 * b) + lean_offset, torso_y + int(0.25 * b) + shoulder_bob_offset)
            # 오른팔(기계팔) 공 타격 시 안쪽으로 휘두르기
            if side == 1 and _weapon_swing != 0:
                swing_x = int(_weapon_swing * 4.0 * b)
                swing_y = int(abs(_weapon_swing) * 1.5 * b)
                elbow = (int(shoulder[0] + int(0.55 * b) + swing_x), torso_y + int(0.95 * b) - swing_y)
                wrist = (int(elbow[0] + int(0.45 * b) + int(swing_x * 0.6)), torso_y + int(1.6 * b) - int(swing_y * 0.6))
            else:
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
                    jx = elbow[0] + int(_cos(angle) * 0.22 * b)
                    jy = elbow[1] + int(_sin(angle) * 0.22 * b)
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
                finger_grip = _sin(self.time * 4) * 0.12
                for i in range(4):
                    finger_angle = 0.25 + i * 0.25 + finger_grip
                    finger_len = int(0.45 * b) if i == 1 or i == 2 else int(0.35 * b)
                    fx1 = wrist[0] + int(_cos(finger_angle) * 0.2 * b)
                    fy1 = wrist[1] + int(_sin(finger_angle) * 0.15 * b) + int(0.1 * b)
                    fx2 = fx1 + int(_cos(finger_angle + 0.2) * finger_len * 0.6)
                    fy2 = fy1 + int(finger_len * 0.4)
                    fx3 = fx2 + int(_cos(finger_angle + 0.1) * finger_len * 0.4)
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

        # === 목 ===
        neck_bot_w = int(0.6 * b)
        neck_top_w = int(0.4 * b)
        neck_top_y = torso_y - int(1.0 * b)
        neck_bot_y = torso_y - int(0.2 * b)
        neck_cx = cx + lean_offset
        neck_pts = [
            (neck_cx - neck_bot_w // 2, neck_bot_y),
            (neck_cx + neck_bot_w // 2, neck_bot_y),
            (neck_cx + neck_top_w // 2, neck_top_y),
            (neck_cx - neck_top_w // 2, neck_top_y),
        ]
        pygame.draw.polygon(screen, p["skin"], neck_pts)
        pygame.draw.line(screen, p["skin_shadow"],
                        (neck_cx + neck_top_w // 4, neck_top_y + 1),
                        (neck_cx + neck_bot_w // 4, neck_bot_y - 1), 1)

        # === 머리 (고글 + 모자) ===
        head_y = torso_y - int(3.0 * b)
        head_w, head_h = int(2.2 * b), int(2.0 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y, head_w, head_h)

        if show_back:
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            pygame.draw.ellipse(screen, p["hair_light"], head_rect.inflate(-int(0.3 * b), -int(0.25 * b)))
            # 긴 머리 (뒤에서 보이는 웨이브)
            for strand in range(6):
                sx = head_rect.left + int(0.2 * b) + strand * int(0.3 * b)
                sy = head_rect.centery
                strand_len = int(2.2 * b) + int(strand % 2 * 0.3 * b)
                wave_off = int(_sin(self.time * 2 + strand * 0.7) * 0.1 * b)
                hair_c = p["hair"] if strand % 2 == 0 else p["hair_light"]
                mid_y = sy + strand_len // 2
                pygame.draw.line(screen, hair_c, (sx, sy), (sx + wave_off, mid_y), max(2, int(0.14 * b)))
                pygame.draw.line(screen, hair_c, (sx + wave_off, mid_y), (sx - wave_off, sy + strand_len), max(1, int(0.1 * b)))
            # 고글 헤드밴드 끈
            pygame.draw.line(screen, p["leather_dark"], (head_rect.left + int(0.18 * b), head_rect.centery - int(0.15 * b)),
                           (head_rect.right - int(0.18 * b), head_rect.centery - int(0.15 * b)), max(2, int(0.1 * b)))
            pygame.draw.line(screen, p["leather"], (head_rect.left + int(0.2 * b), head_rect.centery - int(0.15 * b)),
                           (head_rect.right - int(0.2 * b), head_rect.centery - int(0.15 * b)), max(1, int(0.06 * b)))
        else:
            # 머리 (풍성한 웨이브 헤어)
            hair_rect = head_rect.inflate(int(0.2 * b), int(0.1 * b))
            pygame.draw.ellipse(screen, p["hair"], hair_rect)
            pygame.draw.ellipse(screen, p["hair_light"], hair_rect.inflate(-int(0.35 * b), -int(0.28 * b)))

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
                glow_surf = self._get_surface(goggle_r * 2, goggle_r * 2)
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

            # 입술 (여성)
            lip_y = face_rect.centery + int(0.25 * b)
            lip_w = int(0.28 * b)
            lip_h = int(0.1 * b)
            pygame.draw.ellipse(screen, p["lip"],
                              (face_rect.centerx - lip_w, lip_y - lip_h // 2, lip_w * 2, lip_h))
            pygame.draw.ellipse(screen, p["lip_light"],
                              (face_rect.centerx - lip_w + 2, lip_y - lip_h // 2, lip_w * 2 - 4, lip_h - 2))

            # 속눈썹
            for side in [-1, 1]:
                lash_x = face_rect.centerx + side * int(0.38 * b)
                lash_y = face_rect.centery - int(0.1 * b) - max(4, int(0.28 * b)) - 1
                for li in range(3):
                    lash_angle = math.pi * 1.1 + side * (0.15 + li * 0.2)
                    lash_len = int(0.12 * b) + li
                    lx = lash_x + int(_cos(lash_angle) * lash_len)
                    ly = lash_y + int(_sin(lash_angle) * lash_len)
                    pygame.draw.line(screen, p["eyelash"], (lash_x, lash_y), (lx, ly), 1)

            # 긴 머리카락 (양쪽으로 흘러내리는 웨이브)
            for side in [-1, 1]:
                hair_base_x = head_rect.centerx + side * int(0.85 * b)
                hair_base_y = head_rect.centery - int(0.1 * b)
                for strand in range(4):
                    strand_x = hair_base_x + side * int(strand * 0.12 * b)
                    strand_top = hair_base_y + int(strand * 0.15 * b)
                    strand_bottom = strand_top + int(1.8 * b) + int(strand * 0.2 * b)
                    strand_w = max(2, int(0.18 * b) - strand)
                    wave_offset = int(_sin(self.time * 2 + strand * 0.5) * 0.08 * b)
                    hair_color = p["hair"] if strand % 2 == 0 else p["hair_mid"]
                    mid_x = strand_x + wave_offset + side * int(0.05 * b)
                    mid_y = (strand_top + strand_bottom) // 2
                    pygame.draw.line(screen, hair_color, (strand_x, strand_top), (mid_x, mid_y), strand_w)
                    pygame.draw.line(screen, hair_color, (mid_x, mid_y), (strand_x - wave_offset, strand_bottom), max(1, strand_w - 1))

            # 고글 헤드밴드 (이마에 올려져 있음)
            headband_y = head_rect.top + int(0.15 * b)
            pygame.draw.rect(screen, p["leather_dark"],
                           (head_rect.left + int(0.15 * b), headband_y, head_rect.width - int(0.3 * b), int(0.18 * b)), border_radius=2)
            pygame.draw.rect(screen, p["leather"],
                           (head_rect.left + int(0.17 * b), headband_y + 1, head_rect.width - int(0.34 * b), int(0.14 * b)), border_radius=2)

            # 헤드밴드 위 고글 (올려져 있음)
            for side in [-1, 1]:
                raised_goggle_x = head_rect.centerx + side * int(0.22 * b)
                raised_goggle_y = headband_y - int(0.04 * b)
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
                sx = steam_base_x + int(_sin(self.time * 6 + i + burst) * 0.2 * b)
                sy = steam_base_y - burst_offset - i * int(0.22 * b) - int((self.time * 2.5) % 1 * 0.4 * b)
                steam_size = max(1, int((0.18 - i * 0.03) * b))
                steam_alpha = max(0, int(120 - i * 25 - ((self.time * 2.5) % 1) * 50))

                if steam_size > 0 and steam_alpha > 0:
                    steam_surf = self._get_surface(steam_size * 3, steam_size * 3)
                    steam_color = p["steam_hot"] if i < 2 else p["steam"]
                    pygame.draw.circle(steam_surf, (*steam_color, steam_alpha), (steam_size * 3 // 2, steam_size * 3 // 2), steam_size)
                    screen.blit(steam_surf, (sx - steam_size * 3 // 2, sy - steam_size * 3 // 2))

        # === 추가 증기 제트 파티클 (파이프/조인트에서 분출) ===
        for jet_side in [-1, 1]:
            jet_x = cx + jet_side * int(1.5 * b) + lean_offset
            jet_y = torso_y + int(0.8 * b)
            for ji in range(4):
                j_phase = self.time * 5.0 + ji * 0.8 + jet_side * 2.0
                j_life = (self.time * 3.0 + ji * 0.5) % 1.0
                j_x = jet_x + int(_sin(j_phase) * 0.15 * b) + jet_side * int(j_life * 0.6 * b)
                j_y = jet_y - int(j_life * 1.2 * b)
                j_alpha = max(0, int(100 * (1.0 - j_life) * mech_pulse))
                j_size = max(1, int(0.1 * b * (1.0 - j_life * 0.5)))
                if j_alpha > 5 and j_size > 0:
                    j_surf = self._get_surface(j_size * 3, j_size * 3)
                    j_col = p["steam_hot"] if j_life < 0.3 else p["steam"]
                    pygame.draw.circle(j_surf, (*j_col, j_alpha),
                                     (j_size * 3 // 2, j_size * 3 // 2), j_size)
                    screen.blit(j_surf, (j_x - j_size * 3 // 2, j_y - j_size * 3 // 2))

        # === 톱니/기어 메커니즘 글로우 (따뜻한 앰버 발광) ===
        gear_glow_positions = [
            (cx + lean_offset, chest_rect.centery),  # 가슴 장치
            (cx - int(1.3 * b) + lean_offset, torso_y - int(0.25 * b)),  # 왼쪽 어깨
            (cx + int(1.3 * b) + lean_offset, torso_y - int(0.25 * b)),  # 오른쪽 어깨
        ]
        for gg_x, gg_y in gear_glow_positions:
            gg_r = int(0.5 * b)
            gg_surf = self._get_surface(gg_r * 2, gg_r * 2)
            gg_alpha = int(20 + 15 * mech_pulse)
            pygame.draw.circle(gg_surf, (255, 180, 80, gg_alpha), (gg_r, gg_r), gg_r)
            pygame.draw.circle(gg_surf, (255, 220, 140, int(gg_alpha * 0.5)),
                             (gg_r, gg_r), int(gg_r * 0.5))
            screen.blit(gg_surf, (gg_x - gg_r, gg_y - gg_r), special_flags=pygame.BLEND_ADD)

        # === 전기 스파크 효과 (기계 조인트 근처) ===
        spark_joints = [
            (cx + int(1.95 * b) + lean_offset, torso_y + int(0.95 * b)),  # 오른팔 팔꿈치
            (cx + int(1.3 * b) + lean_offset, torso_y - int(0.25 * b)),  # 오른 어깨
            (cx + lean_offset, chest_rect.centery - int(0.2 * b)),  # 가슴 장치 상단
        ]
        for sp_idx, (sp_x, sp_y) in enumerate(spark_joints):
            spark_chance = _sin(self.time * 12.0 + sp_idx * 4.7)
            if spark_chance > 0.6:
                spark_intensity = (spark_chance - 0.6) / 0.4
                for si in range(3):
                    s_angle = self.time * 20.0 + si * 2.1 + sp_idx * 3.3
                    s_len = int(0.2 * b * spark_intensity)
                    s_x1 = sp_x + int(_cos(s_angle) * 0.05 * b)
                    s_y1 = sp_y + int(_sin(s_angle) * 0.05 * b)
                    s_x2 = s_x1 + int(_cos(s_angle + 0.5) * s_len)
                    s_y2 = s_y1 + int(_sin(s_angle + 0.5) * s_len)
                    s_alpha = int(180 * spark_intensity)
                    s_surf = self._get_surface(abs(s_x2 - s_x1) + 6, abs(s_y2 - s_y1) + 6)
                    ox = min(s_x1, s_x2) - 3
                    oy = min(s_y1, s_y2) - 3
                    pygame.draw.line(s_surf, (200, 230, 255, s_alpha),
                                   (s_x1 - ox, s_y1 - oy), (s_x2 - ox, s_y2 - oy),
                                   max(1, int(0.03 * b)))
                    screen.blit(s_surf, (ox, oy), special_flags=pygame.BLEND_ADD)
                # 스파크 중심 플래시
                fl_r = max(2, int(0.08 * b))
                fl_surf = self._get_surface(fl_r * 2, fl_r * 2)
                pygame.draw.circle(fl_surf, (200, 230, 255, int(120 * spark_intensity)),
                                 (fl_r, fl_r), fl_r)
                screen.blit(fl_surf, (sp_x - fl_r, sp_y - fl_r), special_flags=pygame.BLEND_ADD)

        # === 추가 압력 게이지 (팔/몸통 보조 계기) ===
        sub_gauge_positions = [
            (chest_rect.right - int(0.3 * b), chest_rect.centery + int(0.2 * b)),
            (chest_rect.left + int(0.3 * b), chest_rect.centery + int(0.2 * b)),
        ]
        for sg_x, sg_y in sub_gauge_positions:
            sg_r = max(2, int(0.15 * b))
            pygame.draw.circle(screen, p["brass_dark"], (sg_x, sg_y), sg_r + 1)
            pygame.draw.circle(screen, p["brass"], (sg_x, sg_y), sg_r)
            pygame.draw.circle(screen, p["glass"], (sg_x, sg_y), sg_r - 1)
            # 바늘
            sg_needle_angle = _sin(self.time * 3.5 + sg_x * 0.01) * 0.6 - math.pi / 3
            sg_nx = sg_x + int(_cos(sg_needle_angle) * (sg_r - 2))
            sg_ny = sg_y + int(_sin(sg_needle_angle) * (sg_r - 2))
            needle_color = p["gauge_green"] if _sin(self.time * 3.5 + sg_x * 0.01) > -0.3 else p["gauge_red"]
            pygame.draw.line(screen, needle_color, (sg_x, sg_y), (sg_nx, sg_ny), 1)
            pygame.draw.circle(screen, p["brass_dark"], (sg_x, sg_y), 1)

        # === 배기 글로우 (기계팔 연결부 배기열) ===
        exhaust_x = cx + int(2.0 * b) + lean_offset
        exhaust_y = torso_y + int(0.3 * b)
        exhaust_r = int(0.35 * b)
        exhaust_surf = self._get_surface(exhaust_r * 2, exhaust_r * 2)
        ex_alpha = int(20 + 15 * mech_pulse)
        pygame.draw.circle(exhaust_surf, (255, 160, 100, ex_alpha),
                         (exhaust_r, exhaust_r), exhaust_r)
        pygame.draw.circle(exhaust_surf, (255, 200, 160, int(ex_alpha * 0.5)),
                         (exhaust_r, exhaust_r), int(exhaust_r * 0.5))
        screen.blit(exhaust_surf, (exhaust_x - exhaust_r, exhaust_y - exhaust_r),
                    special_flags=pygame.BLEND_ADD)

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
        shadow_pulse = _sin(self.time * 3) * 0.15 + 0.85
        aura_size = int(5.5 * b * shadow_pulse)
        aura_surf = self._get_surface(aura_size * 2, aura_size * 2)
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
            particle_x = cx + lean_offset + int(_sin(self.time * 3 + i * 1.5) * 0.8 * b)
            particle_alpha = int(60 * (1 - particle_phase / 4))
            particle_size = int(0.3 * b * (1 - particle_phase / 6))
            if particle_size > 0 and particle_alpha > 0:
                ps = self._get_surface(particle_size * 2, particle_size * 2)
                pygame.draw.circle(ps, (*p["smoke"], particle_alpha), (particle_size, particle_size), particle_size)
                screen.blit(ps, (particle_x - particle_size, particle_y - particle_size))

        # === 스카프 (다중 레이어 펄럭임) ===
        scarf_wave = _sin(self.time * 4) * 0.35
        scarf_wave2 = _sin(self.time * 5 + 1) * 0.25
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
        shuriken_glow = self._get_surface(int(0.8 * b), int(0.8 * b))
        pygame.draw.circle(shuriken_glow, (*p["metal_light"], 30), (int(0.4 * b), int(0.4 * b)), int(0.35 * b))
        screen.blit(shuriken_glow, (shuriken_x - int(0.4 * b), shuriken_y - int(0.4 * b)), special_flags=pygame.BLEND_ADD)
        # 수리검 날 (4개)
        for i in range(4):
            angle = i * math.pi / 2 + shuriken_rotation
            sx = shuriken_x + int(_cos(angle) * 0.28 * b)
            sy = shuriken_y + int(_sin(angle) * 0.28 * b)
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
        _weapon_swing = anim.get("weapon_swing_angle", 0)
        for side in [-1, 1]:
            current_swing = left_arm_swing if side == -1 else right_arm_swing
            arm_swing = int(current_swing * 0.5 * b)  # 각도만 살짝 흔드는 수준
            shoulder_bob_offset = int(shoulder_bob * 0.3 * b)
            shoulder = (cx + side * int(1.05 * b) + lean_offset, torso_y + int(0.1 * b) + shoulder_bob_offset)
            # 오른팔(쿠나이) 공 타격 시 안쪽으로 휘두르기
            if side == 1 and _weapon_swing != 0:
                swing_x = int(_weapon_swing * 4.0 * b)
                swing_y = int(abs(_weapon_swing) * 1.5 * b)
                elbow = (int(shoulder[0] + int(0.55 * b) + swing_x), torso_y + int(0.65 * b) - swing_y)
                wrist = (int(elbow[0] + int(0.45 * b) + int(swing_x * 0.6)), torso_y + int(1.25 * b) - int(swing_y * 0.6))
            else:
                elbow = (int(shoulder[0] + side * int(0.55 * b) + arm_swing), torso_y + int(0.65 * b))
                wrist = (int(elbow[0] + side * int(0.45 * b) + int(arm_swing * 0.5)), torso_y + int(1.25 * b))

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
                kunai_glow = self._get_surface(int(1.2 * b), int(0.6 * b))
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

        # === 목 ===
        neck_bot_w = int(0.65 * b)
        neck_top_w = int(0.45 * b)
        neck_top_y = torso_y - int(0.5 * b)
        neck_bot_y = torso_y - int(0.15 * b)
        neck_cx = cx + lean_offset
        neck_pts = [
            (neck_cx - neck_bot_w // 2, neck_bot_y),
            (neck_cx + neck_bot_w // 2, neck_bot_y),
            (neck_cx + neck_top_w // 2, neck_top_y),
            (neck_cx - neck_top_w // 2, neck_top_y),
        ]
        pygame.draw.polygon(screen, p["skin"], neck_pts)

        # === 머리 (닌자 마스크 - 고퀄리티) ===
        head_y = torso_y - int(2.4 * b)
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
                tail_wave = _sin(self.time * 5 + i * 0.8) * 0.25
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
                sx = emblem_x + int(_cos(angle) * 0.08 * b)
                sy = emblem_y + int(_sin(angle) * 0.08 * b)
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
                    glow_surf = self._get_surface(glow_size, int(glow_size * 0.6))
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
        shadow_surf = self._get_surface(shadow_w, shadow_h)
        # 다중 레이어 그림자
        pygame.draw.ellipse(shadow_surf, (*p["shadow_deep"], 50), (0, 0, shadow_w, shadow_h))
        pygame.draw.ellipse(shadow_surf, (*p["shadow"], 70),
                          (int(0.1 * b), int(0.05 * b), shadow_w - int(0.2 * b), shadow_h - int(0.1 * b)))
        screen.blit(shadow_surf, (cx - shadow_w // 2 + lean_offset, shadow_y))

        # === 잔상 효과 (고속 이동 느낌) ===
        if abs(wave) > 0.3:
            afterimage_alpha = int(abs(wave) * 40)
            afterimage_offset = -int(wave * 0.5 * b)
            afterimage_surf = self._get_surface(int(2.5 * b), int(5 * b))
            # 실루엣만 그리기 (간략화)
            pygame.draw.ellipse(afterimage_surf, (*p["shadow"], afterimage_alpha),
                              (int(0.25 * b), 0, int(2 * b), int(1.8 * b)))  # 머리
            pygame.draw.rect(afterimage_surf, (*p["shadow"], afterimage_alpha),
                           (int(0.15 * b), int(1.5 * b), int(2.2 * b), int(2 * b)), border_radius=3)  # 몸통
            screen.blit(afterimage_surf,
                       (cx - int(1.25 * b) + lean_offset + afterimage_offset, head_y - int(0.2 * b)))

    # =========================================================================
    # 벤시 - 유령 여왕 (저주받은 비명의 여왕) [고퀄리티]
    # =========================================================================
    def _draw_banshee(self, screen, cx, cy, b, color, show_back, anim):
        """벤시 - 유령 여왕 (저주받은 비명으로 적을 공포에 빠트리는 유령) [HD 버전]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        shoulder_bob = anim.get("shoulder_bob", 0)

        # 벤시는 떠다니며 날아다님 - 강화된 부유 효과 (다중 사인파)
        float_offset = (_sin(self.time * 1.5) * 0.5 + _sin(self.time * 2.7) * 0.2) * b
        horizontal_drift = _sin(self.time * 1.0) * 0.12 * b  # 수평 부유 드리프트
        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b) + int(float_offset)
        lean_offset = int(lean * 2 * b) + int(horizontal_drift)

        # 유령 펄스 (불규칙한 깜빡임)
        ghost_pulse = (_sin(self.time * 1.8) + 1) * 0.5
        wail_pulse = (_sin(self.time * 3.5) + 1) * 0.5  # 울음소리 효과
        flicker = 0.85 + 0.15 * _sin(self.time * 7.3)  # 유령 깜빡임

        p = {
            "dress": (50, 55, 75),           # 어두운 회청색 드레스
            "dress_light": (80, 90, 115),
            "dress_mid": (65, 72, 95),
            "dress_dark": (35, 38, 55),
            "dress_shadow": (20, 22, 35),
            "dress_edge": (90, 100, 135),     # 드레스 가장자리 (밝은 유령빛)
            "ghost_trail": (100, 140, 180),   # 유령 꼬리 색
            "ghost_fade": (70, 100, 140),     # 유령 꼬리 페이드
            "gold": color,
            "gold_light": tuple(min(255, c + 55) for c in color),
            "gold_mid": tuple(min(255, c + 28) for c in color),
            "gold_dark": tuple(max(0, c - 45) for c in color),
            "gold_shadow": tuple(max(0, c - 75) for c in color),
            "skin": (200, 210, 220),          # 창백한 유령 피부
            "skin_shadow": (170, 180, 195),
            "skin_glow": (210, 225, 240),     # 유령빛 피부 하이라이트
            "skull": (220, 225, 230),         # 해골 (밝은 뼈색)
            "skull_shadow": (180, 185, 195),
            "skull_dark": (140, 145, 160),
            "eye": (80, 220, 255),            # 차가운 시안 눈빛
            "eye_glow": (100, 240, 255),
            "eye_core": (200, 255, 255),      # 눈 중심 (매우 밝음)
            "hair": (25, 20, 40),             # 칠흑 보라 머리카락
            "hair_mid": (40, 32, 58),
            "hair_light": (55, 45, 75),
            "hair_highlight": (80, 65, 105),
            "hair_ghost": (60, 80, 120),      # 머리카락 끝 유령빛
            "crown": (180, 160, 100),         # 고대 왕관
            "crown_light": (220, 200, 140),
            "crown_gem": (80, 200, 240),      # 왕관 보석
            "crown_gem_glow": (120, 230, 255),
            "claw": (200, 185, 130),          # 금색 손톱/건틀릿
            "claw_light": (230, 215, 160),
            "claw_dark": (160, 145, 95),
            "aura": (60, 150, 200),           # 유령 오라
            "aura_inner": (80, 180, 230),
            "wail": (150, 220, 255),          # 비명 이펙트
            "wisp": (100, 180, 220),          # 도깨비불
            "lip": (130, 100, 120),
            "lip_light": (155, 120, 140),
            "eyelash": (30, 25, 45),
        }

        # === 유령 오라 (배경 - 차가운 푸른빛) ===
        aura_size = int(5.5 * b)
        aura_surf = self._get_surface(aura_size * 2, aura_size * 2)
        for i in range(5):
            aura_alpha = int((30 - i * 6) * ghost_pulse * flicker)
            aura_r = int((2.5 - i * 0.4) * b)
            pygame.draw.circle(aura_surf, (*p["aura"], aura_alpha),
                             (aura_size, aura_size), aura_r)
        screen.blit(aura_surf,
                   (cx - aura_size + lean_offset,
                    torso_y - int(1.5 * b) - aura_size // 2),
                   special_flags=pygame.BLEND_ADD)

        # 도깨비불 (떠다니는 유령 파티클)
        for i in range(10):
            wisp_angle = self.time * 0.6 + i * math.pi / 5
            wisp_r = int(2.8 * b + _sin(self.time * 1.5 + i * 1.2) * 0.5 * b)
            wisp_x = cx + int(_cos(wisp_angle) * wisp_r) + lean_offset
            wisp_y = torso_y - int(0.3 * b) + int(_sin(wisp_angle * 1.5 + self.time * 2) * 1.2 * b)
            wisp_alpha = int((60 + 40 * _sin(self.time * 4 + i * 0.7)) * flicker)
            wisp_size = max(2, int(0.15 * b + 0.05 * b * _sin(self.time * 3 + i)))
            wisp_surf = self._get_surface(wisp_size * 4, wisp_size * 4)
            pygame.draw.circle(wisp_surf, (*p["wisp"], wisp_alpha),
                             (wisp_size * 2, wisp_size * 2), wisp_size)
            # 도깨비불 코어 (더 밝게)
            pygame.draw.circle(wisp_surf, (*p["eye_core"], int(wisp_alpha * 0.6)),
                             (wisp_size * 2, wisp_size * 2), max(1, wisp_size // 2))
            screen.blit(wisp_surf,
                       (int(wisp_x - wisp_size * 2), int(wisp_y - wisp_size * 2)),
                       special_flags=pygame.BLEND_ADD)

        # === 유령 하반신 (다리 없음 - 연기처럼 흩어지는 유령 꼬리) ===
        side_blend = anim.get("side_blend", 0)
        move_dir = anim.get("move_dir", 0)
        ghost_drift = -move_dir * side_blend * 1.2 * b
        ghost_flow = (_sin(self.time * 2.0) * 0.4 + _sin(self.time * 3.3) * 0.2) * b
        ghost_wave_boost = 1.0 + side_blend * 3.5

        # 1) 상체에서 아래로 좁아지며 뾰족해지는 유령 꼬리 실루엣
        dress_top_w = int(1.3 * b)
        tail_sway = int((ghost_drift + ghost_flow) * 0.8)
        tail_tip_y = cy + int(4.5 * b)
        dress_points = [
            (cx - dress_top_w + lean_offset, torso_y + int(1.6 * b)),
            (cx + dress_top_w + lean_offset, torso_y + int(1.6 * b)),
            (cx + int(0.7 * b) + lean_offset + int(tail_sway * 0.4), cy + int(2.8 * b)),
            (cx + lean_offset + tail_sway, tail_tip_y),
            (cx - int(0.7 * b) + lean_offset + int(tail_sway * 0.3), cy + int(2.8 * b)),
        ]
        shadow_pts = [(px + 2, py + 2) for px, py in dress_points]
        pygame.draw.polygon(screen, p["dress_shadow"], shadow_pts)
        pygame.draw.polygon(screen, p["dress"], dress_points)

        # 2) 꼬리 세로 주름 (점점 사라지며 짧아짐)
        for i in range(5):
            fold_shift = int((ghost_drift + ghost_flow) * (i - 2) * 0.08)
            fold_x = cx + int((i - 2) * 0.3 * b) + lean_offset + fold_shift
            fold_top = torso_y + int(1.7 * b)
            fold_bot = cy + int(2.3 * b)
            pygame.draw.line(screen, p["dress_mid"], (fold_x, fold_top), (fold_x, fold_bot), 1)

        # 3) 유령 꼬리 투명 그라데이션 (아래로 갈수록 사라짐)
        for layer in range(8):
            tail_y = cy + int(2.6 * b) + layer * int(0.22 * b)
            base_w = int(0.7 * b) - layer * int(0.06 * b)
            tail_w = max(2, base_w + int(_sin(self.time * 2.5 + layer * 0.5) * 0.1 * b))
            layer_factor = 1.0 + layer * 0.5
            layer_sway = int((ghost_drift + ghost_flow) * layer_factor)
            tail_alpha = max(3, int((90 - layer * 11) * flicker))
            tail_surf = self._get_surface(int(tail_w * 2 + 6), int(0.3 * b))
            tail_rect_area = (0, 0, tail_surf.get_width(), tail_surf.get_height())
            pygame.draw.ellipse(tail_surf, (*p["ghost_trail"], tail_alpha), tail_rect_area)
            screen.blit(tail_surf,
                       (cx - tail_w + lean_offset + layer_sway, int(tail_y)))

        # 4) 에테르 가닥 (아래로 흘러내리는 유령 연기)
        for i in range(5):
            tendril_phase = self.time * 1.5 + i * 1.3
            tendril_x = cx + int((i - 2) * 0.28 * b) + lean_offset
            tendril_start_y = cy + int(3.0 * b)
            t_sway = int(_sin(tendril_phase) * 0.3 * b) + int((ghost_drift + ghost_flow) * (0.4 + i * 0.12))
            t_len = int(1.2 * b + _sin(self.time * 2.0 + i * 0.7) * 0.25 * b)
            t_mid_x = tendril_x + int(t_sway * 0.5)
            t_mid_y = tendril_start_y + t_len // 2
            t_end_x = tendril_x + t_sway
            t_end_y = tendril_start_y + t_len
            pygame.draw.line(screen, p["ghost_trail"],
                           (tendril_x, tendril_start_y),
                           (t_mid_x, t_mid_y), max(2, int(0.09 * b)))
            pygame.draw.line(screen, p["ghost_fade"],
                           (t_mid_x, t_mid_y),
                           (t_end_x, t_end_y), max(1, int(0.05 * b)))

        # 5) 바닥 안개 파티클 (둥둥 떠다니는 느낌 강조)
        for i in range(6):
            mist_x = cx + int(_sin(self.time * 1.0 + i * 1.05) * 0.5 * b) + lean_offset + int(ghost_drift * 0.2)
            mist_y = cy + int(3.8 * b) + int(i * 0.12 * b) + int(_sin(self.time * 2.0 + i * 0.6) * 0.08 * b)
            mist_r = max(2, int((0.14 + _sin(self.time * 2.5 + i * 0.4) * 0.05) * b))
            mist_alpha = max(3, int((35 - i * 5) * flicker))
            mist_surf = self._get_surface(mist_r * 4, mist_r * 4)
            pygame.draw.circle(mist_surf, (*p["ghost_fade"], mist_alpha),
                             (mist_r * 2, mist_r * 2), mist_r)
            screen.blit(mist_surf, (mist_x - mist_r * 2, mist_y - mist_r * 2))

        # === 몸통 (찢어진 유령 드레스, 여성 실루엣) ===
        chest_w, chest_h = int(2.8 * b), int(2.2 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset,
                                 torso_y - int(0.3 * b), chest_w, chest_h)

        # 몸통 그림자
        shadow_rect = chest_rect.inflate(int(0.15 * b), int(0.1 * b))
        shadow_rect.move_ip(int(0.1 * b), int(0.12 * b))
        pygame.draw.rect(screen, (25, 28, 40), shadow_rect, border_radius=int(0.45 * b))

        pygame.draw.rect(screen, p["dress"], chest_rect, border_radius=int(0.45 * b))
        pygame.draw.rect(screen, p["dress_mid"],
                        chest_rect.inflate(-int(0.35 * b), -int(0.25 * b)),
                        border_radius=int(0.35 * b))
        pygame.draw.rect(screen, p["dress_light"],
                        chest_rect.inflate(-int(0.7 * b), -int(0.5 * b)),
                        border_radius=int(0.25 * b))

        # 몸통 찢어진 무늬 (비대칭 세로줄)
        for i in range(4):
            line_x = chest_rect.left + int((i + 0.8) * 0.65 * b)
            line_top = chest_rect.top + int(0.3 * b)
            line_bot = chest_rect.bottom - int(0.2 * b)
            # 찢어진 듯한 불규칙 선
            mid_y = (line_top + line_bot) // 2
            mid_offset = int(_sin(self.time * 0.5 + i * 1.3) * 0.05 * b)
            pygame.draw.line(screen, p["dress_edge"],
                           (line_x, line_top),
                           (line_x + mid_offset, mid_y), 1)
            pygame.draw.line(screen, p["dress_dark"],
                           (line_x + mid_offset, mid_y),
                           (line_x, line_bot), 1)

        # === 가슴 장식 (유령 보석 - 영혼의 핵) ===
        gem_cx, gem_cy = chest_rect.centerx, chest_rect.centery - int(0.1 * b)
        gem_r = int(0.5 * b)

        # 보석 글로우
        glow_surf = self._get_surface(int(2.0 * b), int(2.0 * b))
        glow_alpha = int(50 * ghost_pulse + 20)
        pygame.draw.circle(glow_surf, (*p["eye_glow"], glow_alpha),
                         (int(1.0 * b), int(1.0 * b)), int(0.9 * b))
        screen.blit(glow_surf,
                   (gem_cx - int(1.0 * b), gem_cy - int(1.0 * b)),
                   special_flags=pygame.BLEND_ADD)

        # 보석 외곽 (금색 테두리)
        pygame.draw.circle(screen, p["gold_shadow"],
                         (gem_cx + 1, gem_cy + 1), gem_r + 2)
        pygame.draw.circle(screen, p["gold_dark"], (gem_cx, gem_cy), gem_r + 1)
        # 보석 본체
        pygame.draw.circle(screen, p["crown_gem"], (gem_cx, gem_cy), gem_r)
        pygame.draw.circle(screen, p["crown_gem_glow"],
                         (gem_cx, gem_cy), int(gem_r * 0.7))
        # 보석 하이라이트
        pygame.draw.circle(screen, p["eye_core"],
                         (gem_cx - int(0.1 * b), gem_cy - int(0.1 * b)),
                         max(1, int(gem_r * 0.3)))

        # === 허리띠 (고대 금속 벨트) ===
        belt_rect = pygame.Rect(cx - int(1.15 * b) + lean_offset,
                               chest_rect.bottom - 3, int(2.3 * b), int(0.7 * b))
        pygame.draw.rect(screen, p["gold_shadow"], belt_rect, border_radius=3)
        pygame.draw.rect(screen, p["gold_dark"], belt_rect.inflate(-2, -2), border_radius=2)
        # 벨트 문양 (해골 모양)
        belt_cx = belt_rect.centerx
        belt_cy = belt_rect.centery
        pygame.draw.circle(screen, p["gold"], (belt_cx, belt_cy), max(3, int(0.22 * b)))
        pygame.draw.circle(screen, p["skull"],
                         (belt_cx, belt_cy), max(2, int(0.16 * b)))
        # 작은 해골 눈
        for side in [-1, 1]:
            pygame.draw.circle(screen, p["dress_dark"],
                             (belt_cx + side * max(1, int(0.06 * b)),
                              belt_cy - max(1, int(0.02 * b))),
                             max(1, int(0.04 * b)))

        # === 어깨 장식 (유령 견갑) ===
        for side in [-1, 1]:
            sp_x = cx + side * int(1.35 * b) + lean_offset
            sp_y = torso_y - int(0.05 * b)
            sp_r = max(4, int(0.5 * b))

            # 견갑 그림자
            pygame.draw.circle(screen, p["gold_shadow"],
                             (sp_x + 1, sp_y + 1), sp_r + 1)
            # 견갑 본체
            pygame.draw.circle(screen, p["gold_dark"], (sp_x, sp_y), sp_r)
            pygame.draw.circle(screen, p["gold"], (sp_x, sp_y), sp_r - 1)
            # 견갑 하이라이트
            pygame.draw.circle(screen, p["gold_light"],
                             (sp_x - side, sp_y - 1), max(2, sp_r - 3))
            # 견갑 보석
            pygame.draw.circle(screen, p["crown_gem"],
                             (sp_x, sp_y), max(2, int(0.18 * b)))
            gem_glow_alpha = int(40 * ghost_pulse)
            gem_glow_surf = self._get_surface(int(0.6 * b), int(0.6 * b))
            pygame.draw.circle(gem_glow_surf, (*p["crown_gem_glow"], gem_glow_alpha),
                             (int(0.3 * b), int(0.3 * b)), int(0.25 * b))
            screen.blit(gem_glow_surf,
                       (sp_x - int(0.3 * b), sp_y - int(0.3 * b)),
                       special_flags=pygame.BLEND_ADD)

        # === 팔 (로브 소매 + 금색 건틀릿/손톱) ===
        swing_angle = anim.get("weapon_swing_angle", 0)
        arm_slam = anim.get("arm_slam", 0)
        for side in [-1, 1]:
            shoulder_bob_offset = int(shoulder_bob * 0.3 * b)
            shoulder = (cx + side * int(1.2 * b) + lean_offset,
                       torso_y + int(0.3 * b) + shoulder_bob_offset)

            # 팔 스윙: 타격 시 양팔 올려치기 (벤시 비명 공격)
            if arm_slam != 0:
                arm_raise = arm_slam * 1.5 * b
                elbow = (shoulder[0] + side * int(0.3 * b),
                        shoulder[1] - int(1.0 * b) + int(arm_raise * 0.5))
                wrist = (elbow[0] + side * int(0.2 * b),
                        elbow[1] - int(0.8 * b) + int(arm_raise))
            else:
                # 유령처럼 떠다니는 팔 (약간 벌린 자세)
                arm_float = _sin(self.time * 2.2 + side * 1.5) * 0.08 * b
                elbow = (shoulder[0] + side * int(0.6 * b),
                        torso_y + int(0.9 * b) + int(arm_float))
                wrist = (elbow[0] + side * int(0.5 * b) + int(wave * side * 0.12 * b),
                        torso_y + int(1.5 * b) + int(arm_float * 1.3))

            # 상완 (로브 소매)
            pygame.draw.line(screen, p["dress"], shoulder, elbow,
                           max(3, int(0.55 * b)))
            pygame.draw.line(screen, p["dress_mid"], shoulder, elbow,
                           max(2, int(0.4 * b)))
            # 하완 (로브 소매)
            pygame.draw.line(screen, p["dress_mid"], elbow, wrist,
                           max(3, int(0.5 * b)))
            pygame.draw.line(screen, p["dress_light"], elbow, wrist,
                           max(2, int(0.35 * b)))
            # 소매 끝 금색 건틀릿
            pygame.draw.circle(screen, p["gold_dark"], wrist, max(3, int(0.28 * b)))
            pygame.draw.circle(screen, p["gold"], wrist, max(2, int(0.22 * b)))
            pygame.draw.circle(screen, p["gold_light"],
                             (wrist[0] - side, wrist[1] - 1),
                             max(1, int(0.12 * b)))

            # 손톱/발톱 (3개의 금색 클로)
            for claw_i in range(3):
                claw_angle = (claw_i - 1) * 0.25 + side * 0.3
                claw_len = int(0.35 * b)
                claw_tip_x = wrist[0] + int(_cos(claw_angle + math.pi / 2) * claw_len * side)
                claw_tip_y = wrist[1] + int(_sin(claw_angle + math.pi / 2) * claw_len) + int(0.2 * b)
                pygame.draw.line(screen, p["claw_dark"], wrist,
                               (claw_tip_x, claw_tip_y), max(2, int(0.08 * b)))
                pygame.draw.line(screen, p["claw"],
                               (wrist[0], wrist[1] + 1),
                               (claw_tip_x, claw_tip_y), max(1, int(0.05 * b)))

        # === 머리 (해골 + 왕관 + 유령 머리카락) ===
        head_y = torso_y - int(3.0 * b)
        head_w, head_h = int(2.4 * b), int(2.2 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset, head_y,
                               head_w, head_h)

        if show_back:
            # === 뒷모습 ===
            # 뒷머리카락 (길고 흐르는)
            for strand in range(7):
                sx = head_rect.left + int(0.15 * b) + strand * int(0.28 * b)
                sy = head_rect.top + int(0.3 * b)
                strand_len = int(2.5 * b) + int((strand % 3) * 0.3 * b)
                wave_off = int(_sin(self.time * 1.5 + strand * 0.7) * 0.12 * b)
                h_color = p["hair"] if strand % 2 == 0 else p["hair_mid"]
                # 3단계 곡선 머리카락
                mid1_y = sy + strand_len // 3
                mid2_y = sy + strand_len * 2 // 3
                pygame.draw.line(screen, h_color,
                               (sx, sy),
                               (sx + wave_off, mid1_y),
                               max(2, int(0.14 * b)))
                pygame.draw.line(screen, h_color,
                               (sx + wave_off, mid1_y),
                               (sx - wave_off, mid2_y),
                               max(2, int(0.1 * b)))
                # 끝부분은 유령빛으로
                end_color = p["hair_ghost"]
                pygame.draw.line(screen, end_color,
                               (sx - wave_off, mid2_y),
                               (sx + int(wave_off * 0.5), sy + strand_len),
                               max(1, int(0.07 * b)))

            # 뒷머리 (둥근 형태)
            pygame.draw.ellipse(screen, p["hair"], head_rect)
            pygame.draw.ellipse(screen, p["hair_mid"],
                              head_rect.inflate(-int(0.3 * b), -int(0.3 * b)))

            # 왕관 뒷면
            crown_y = head_rect.top - int(0.2 * b)
            crown_w = int(1.8 * b)
            crown_rect = pygame.Rect(cx - crown_w // 2 + lean_offset,
                                    crown_y, crown_w, int(0.6 * b))
            pygame.draw.rect(screen, p["crown"], crown_rect, border_radius=2)
            pygame.draw.rect(screen, p["gold_dark"], crown_rect, 1, border_radius=2)
            # 왕관 뾰족한 부분 (뒷면)
            for i in range(5):
                spike_x = crown_rect.left + int((i + 0.5) * crown_w / 5)
                spike_h = int(0.35 * b) if i % 2 == 0 else int(0.5 * b)
                pygame.draw.polygon(screen, p["crown"], [
                    (spike_x - int(0.1 * b), crown_y),
                    (spike_x, crown_y - spike_h),
                    (spike_x + int(0.1 * b), crown_y),
                ])
        else:
            # === 정면 ===
            # 양옆으로 흘러내리는 긴 머리카락 (먼저 그려서 얼굴 뒤에)
            for side in [-1, 1]:
                hair_base_x = head_rect.centerx + side * int(0.55 * b)
                hair_base_y = head_rect.top + int(0.15 * b)
                for strand in range(4):
                    sx = hair_base_x + side * int(strand * 0.1 * b)
                    sy_top = hair_base_y + int(strand * 0.12 * b)
                    strand_len = int(2.2 * b) + int(strand * 0.2 * b)
                    sw = max(2, int(0.16 * b) - strand)
                    wave_off = int(_sin(self.time * 1.6 + strand * 0.5 + side) * 0.08 * b)
                    h_color = p["hair"] if strand % 2 == 0 else p["hair_light"]

                    mid_y = sy_top + strand_len // 2
                    pygame.draw.line(screen, h_color,
                                   (sx, sy_top),
                                   (sx + wave_off * side, mid_y), sw)
                    # 끝은 유령빛으로 페이드
                    end_color = p["hair_ghost"]
                    pygame.draw.line(screen, end_color,
                                   (sx + wave_off * side, mid_y),
                                   (sx - wave_off * side, sy_top + strand_len),
                                   max(1, sw - 1))

            # 얼굴 (창백한 해골 같은 얼굴)
            face_rect = head_rect.inflate(-int(0.5 * b), -int(0.4 * b))
            face_rect.move_ip(0, int(0.2 * b))
            # 얼굴 그림자
            pygame.draw.ellipse(screen, p["skull_shadow"], face_rect.inflate(2, 2))
            pygame.draw.ellipse(screen, p["skull"], face_rect)
            # 볼 음영 (해골 느낌의 움푹 파인 느낌)
            for side in [-1, 1]:
                cheek_x = face_rect.centerx + side * int(0.25 * b)
                cheek_y = face_rect.centery + int(0.12 * b)
                pygame.draw.circle(screen, p["skull_shadow"],
                                 (cheek_x, cheek_y), max(2, int(0.12 * b)))

            # 금색 턱 마스크 (하관 보호대)
            chin_y = face_rect.centery + int(0.15 * b)
            chin_w = int(0.7 * b)
            chin_h = int(0.45 * b)
            chin_points = [
                (face_rect.centerx - chin_w // 2, chin_y),
                (face_rect.centerx + chin_w // 2, chin_y),
                (face_rect.centerx + int(chin_w * 0.3), chin_y + chin_h),
                (face_rect.centerx - int(chin_w * 0.3), chin_y + chin_h),
            ]
            pygame.draw.polygon(screen, p["gold_dark"], chin_points)
            pygame.draw.polygon(screen, p["gold"], [
                (chin_points[0][0] + 2, chin_points[0][1] + 1),
                (chin_points[1][0] - 2, chin_points[1][1] + 1),
                (chin_points[2][0] - 1, chin_points[2][1] - 1),
                (chin_points[3][0] + 1, chin_points[3][1] - 1),
            ])
            # 마스크 문양 (V자 무늬)
            v_top = chin_y + int(0.05 * b)
            v_bot = chin_y + chin_h - int(0.08 * b)
            pygame.draw.line(screen, p["gold_light"],
                           (face_rect.centerx, v_top),
                           (face_rect.centerx - int(0.12 * b), v_bot), 1)
            pygame.draw.line(screen, p["gold_light"],
                           (face_rect.centerx, v_top),
                           (face_rect.centerx + int(0.12 * b), v_bot), 1)

            # 유령의 눈 (시안 글로우)
            eye_y = face_rect.centery - int(0.1 * b)
            for side in [-1, 1]:
                eye_x = face_rect.centerx + side * int(0.25 * b)
                eye_r = max(2, int(0.18 * b))

                # 눈 글로우 (강한 빛)
                eye_glow_surf = self._get_surface(int(0.8 * b), int(0.8 * b))
                eye_glow_alpha = int(80 * ghost_pulse + 40)
                pygame.draw.circle(eye_glow_surf, (*p["eye_glow"], eye_glow_alpha),
                                 (int(0.4 * b), int(0.4 * b)), int(0.35 * b))
                screen.blit(eye_glow_surf,
                           (eye_x - int(0.4 * b), eye_y - int(0.4 * b)),
                           special_flags=pygame.BLEND_ADD)

                # 눈구멍 (어두운 배경)
                pygame.draw.circle(screen, p["dress_dark"],
                                 (eye_x, eye_y), eye_r + 1)
                # 눈 본체 (발광하는 시안)
                pygame.draw.circle(screen, p["eye"], (eye_x, eye_y), eye_r)
                # 눈 코어 (밝은 중심)
                pygame.draw.circle(screen, p["eye_core"],
                                 (eye_x, eye_y), max(1, eye_r // 2))
                # 하이라이트
                pygame.draw.circle(screen, (255, 255, 255),
                                 (eye_x - 1, eye_y - 1),
                                 max(1, eye_r // 3))

                # 속눈썹 (여성)
                for li in range(3):
                    lash_angle = math.pi * 1.1 + side * (0.15 + li * 0.2)
                    lash_len = int(0.12 * b) + li
                    lx = eye_x + int(_cos(lash_angle) * lash_len)
                    ly = (eye_y - eye_r - 1) + int(_sin(lash_angle) * lash_len)
                    pygame.draw.line(screen, p["eyelash"],
                                   (eye_x, eye_y - eye_r - 1),
                                   (lx, ly), 1)

            # 코 (미세한 선)
            pygame.draw.line(screen, p["skull_dark"],
                           (face_rect.centerx, eye_y + int(0.12 * b)),
                           (face_rect.centerx, chin_y - int(0.02 * b)), 1)

            # === 왕관 (고대 유령 왕관) ===
            crown_y = head_rect.top - int(0.15 * b)
            crown_w = int(2.0 * b)
            crown_h = int(0.5 * b)
            crown_rect = pygame.Rect(cx - crown_w // 2 + lean_offset,
                                    crown_y, crown_w, crown_h)
            # 왕관 밴드
            pygame.draw.rect(screen, p["crown"], crown_rect, border_radius=2)
            pygame.draw.rect(screen, p["gold_dark"], crown_rect, 1, border_radius=2)
            # 왕관 내부 하이라이트
            pygame.draw.rect(screen, p["crown_light"],
                           crown_rect.inflate(-4, -2), border_radius=1)

            # 왕관 뾰족한 부분 (5개)
            for i in range(5):
                spike_x = crown_rect.left + int((i + 0.5) * crown_w / 5)
                spike_h = int(0.4 * b) if i % 2 == 0 else int(0.65 * b)
                spike_pts = [
                    (spike_x - int(0.12 * b), crown_y),
                    (spike_x, crown_y - spike_h),
                    (spike_x + int(0.12 * b), crown_y),
                ]
                pygame.draw.polygon(screen, p["crown"], spike_pts)
                pygame.draw.polygon(screen, p["crown_light"], [
                    (spike_pts[0][0] + 1, spike_pts[0][1]),
                    (spike_pts[1][0], spike_pts[1][1] + 1),
                    (spike_pts[2][0] - 1, spike_pts[2][1]),
                ])
                # 왕관 뾰족 끝 보석 (중앙만)
                if i == 2:
                    pygame.draw.circle(screen, p["crown_gem"],
                                     (spike_x, crown_y - spike_h + int(0.08 * b)),
                                     max(2, int(0.1 * b)))
                    # 보석 글로우
                    g_surf = self._get_surface(int(0.4 * b), int(0.4 * b))
                    pygame.draw.circle(g_surf, (*p["crown_gem_glow"], int(50 * ghost_pulse)),
                                     (int(0.2 * b), int(0.2 * b)), int(0.15 * b))
                    screen.blit(g_surf,
                               (spike_x - int(0.2 * b),
                                crown_y - spike_h + int(0.08 * b) - int(0.2 * b)),
                               special_flags=pygame.BLEND_ADD)

        # === 비명 이펙트 (타격 시 무기 대신 비명 파동) ===
        if swing_angle != 0:
            # 타격 시 입에서 나오는 비명 파동
            wail_progress = abs(swing_angle) / 0.7  # 0~1
            wail_alpha = int(100 * wail_progress * flicker)
            wail_r_base = int(1.5 * b * wail_progress)

            for ring in range(3):
                ring_r = wail_r_base + ring * int(0.4 * b)
                ring_alpha = max(5, wail_alpha - ring * 25)
                wail_surf_size = ring_r * 2 + 4
                if wail_surf_size > 4:
                    wail_surf = self._get_surface(wail_surf_size, wail_surf_size)
                    pygame.draw.circle(wail_surf, (*p["wail"], ring_alpha),
                                     (wail_surf_size // 2, wail_surf_size // 2),
                                     ring_r, max(1, int(0.08 * b)))
                    wail_cx = cx + lean_offset
                    wail_cy = torso_y - int(1.5 * b)  # 머리 높이
                    screen.blit(wail_surf,
                               (wail_cx - wail_surf_size // 2,
                                wail_cy - wail_surf_size // 2),
                               special_flags=pygame.BLEND_ADD)

    # =========================================================================
    # 네크로 - 강령술사 (유령을 조종하는 신비로운 강령술사) [HD 버전]
    # =========================================================================
    def _draw_necro(self, screen, cx, cy, b, color, show_back, anim):
        """네크로 - 해골의 여왕 (스켈레톤 퀸, 해골 치마, 뼈 왕관) [HD 버전]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        shoulder_bob = anim.get("shoulder_bob", 0)

        # 해골 여왕은 위엄있게 떠다님
        float_offset = _sin(self.time * 1.5) * 0.2 * b
        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b) + int(float_offset)
        lean_offset = int(lean * 2 * b)

        # 사령 펄스 (보라빛)
        ghost_pulse = (_sin(self.time * 2.0) + 1) * 0.5
        soul_pulse = (_sin(self.time * 3.2) + 1) * 0.5
        flicker = 0.90 + 0.10 * _sin(self.time * 5.0)
        crown_shimmer = (_sin(self.time * 4.0) + 1) * 0.5

        # 색상 팔레트 - 해골의 여왕
        p = {
            "dress": (25, 8, 35),                # 심연의 보라 드레스
            "dress_light": (45, 18, 60),
            "dress_mid": (35, 12, 48),
            "dress_dark": (15, 4, 22),
            "dress_shadow": (8, 2, 12),
            "dress_edge": (80, 40, 110),         # 드레스 가장자리 (보라 광택)
            "dress_trim": (100, 50, 140),        # 드레스 트림
            "skull_white": (220, 215, 210),      # 해골 흰색
            "skull_light": (240, 235, 230),
            "skull_shadow": (180, 170, 165),
            "skull_dark": (140, 130, 125),
            "skull_cavity": (30, 10, 40),        # 해골 빈 구멍 (어두운 보라)
            "bone": (210, 200, 195),             # 뼈 색
            "bone_light": (235, 228, 222),
            "bone_shadow": (175, 165, 158),
            "bone_joint": (190, 180, 172),
            "gold": color,
            "gold_light": tuple(min(255, c + 50) for c in color),
            "gold_dark": tuple(max(0, c - 40) for c in color),
            "crown_gem": (160, 60, 200),         # 왕관 보석 (보라 보석)
            "crown_gem_glow": (200, 100, 255),
            "crown_bone": (230, 222, 215),       # 왕관 뼈
            "crown_bone_shadow": (195, 185, 178),
            "eye": (160, 60, 220),               # 보라빛 눈
            "eye_glow": (200, 100, 255),
            "eye_core": (240, 180, 255),
            "scepter_bone": (215, 205, 198),     # 뼈 홀(홀셉터)
            "scepter_dark": (175, 165, 155),
            "orb": (140, 50, 200),               # 사령 구슬
            "orb_glow": (180, 80, 255),
            "orb_core": (230, 170, 255),
            "aura": (80, 20, 120),               # 사령 오라 (짙은 보라)
            "aura_inner": (120, 50, 170),
            "wisp": (140, 60, 200),              # 유령불 (보라)
            "wisp_inner": (200, 140, 255),
            "rib_bone": (200, 192, 185),         # 갈비뼈
            "rib_shadow": (165, 155, 148),
            "necklace_chain": (190, 180, 170),   # 목걸이 체인
        }

        # === 사령 오라 (배경 - 짙은 보라빛) ===
        aura_size = int(5.0 * b)
        aura_surf = self._get_surface(aura_size * 2, aura_size * 2)
        for i in range(4):
            aura_alpha = int((22 - i * 5) * ghost_pulse * flicker)
            aura_r = int((2.2 - i * 0.4) * b)
            pygame.draw.circle(aura_surf, (*p["aura"], max(0, aura_alpha)),
                             (aura_size, aura_size), aura_r)
        screen.blit(aura_surf,
                   (cx - aura_size + lean_offset,
                    torso_y - int(1.2 * b) - aura_size // 2),
                   special_flags=pygame.BLEND_ADD)

        # 유령불 파티클 (떠도는 보라빛 영혼)
        for i in range(7):
            wisp_angle = self.time * 0.45 + i * math.pi * 2 / 7
            wisp_r = int(2.5 * b + _sin(self.time * 1.2 + i * 1.1) * 0.4 * b)
            wisp_x = cx + int(_cos(wisp_angle) * wisp_r) + lean_offset
            wisp_y = torso_y - int(0.2 * b) + int(_sin(wisp_angle * 1.3 + self.time * 1.8) * 1.0 * b)
            wisp_alpha = int((45 + 30 * _sin(self.time * 3.5 + i * 0.8)) * flicker)
            wisp_size = max(2, int(0.12 * b + 0.04 * b * _sin(self.time * 2.8 + i)))
            wisp_surf = self._get_surface(wisp_size * 4, wisp_size * 4)
            pygame.draw.circle(wisp_surf, (*p["wisp"], max(0, wisp_alpha)),
                             (wisp_size * 2, wisp_size * 2), wisp_size)
            pygame.draw.circle(wisp_surf, (*p["wisp_inner"], int(max(0, wisp_alpha) * 0.35)),
                             (wisp_size * 2, wisp_size * 2), max(1, wisp_size // 2))
            screen.blit(wisp_surf,
                       (int(wisp_x - wisp_size * 2), int(wisp_y - wisp_size * 2)),
                       special_flags=pygame.BLEND_ADD)

        # === 드레스 하단 (해골 얼굴 장식 치마) ===
        side_blend = anim.get("side_blend", 0)
        move_dir = anim.get("move_dir", 0)
        ghost_drift = -move_dir * side_blend * 0.7 * b
        ghost_flow = (_sin(self.time * 2.2) * 0.2 + _sin(self.time * 3.5) * 0.1) * b
        ghost_wave_boost = 1.0 + side_blend * 2.0

        # 메인 드레스 실루엣 (넓게 퍼지는 A라인)
        skirt_bottom_y = cy + int(3.5 * b)
        skirt_points = [
            (cx - int(1.0 * b) + lean_offset, torso_y + int(1.3 * b)),
            (cx + int(1.0 * b) + lean_offset, torso_y + int(1.3 * b)),
            (cx + int(2.0 * b) + lean_offset + int(wave * 0.2 * ghost_wave_boost * b) + int(ghost_drift + ghost_flow), skirt_bottom_y),
            (cx + int(0.3 * b) + lean_offset + int((ghost_drift + ghost_flow) * 0.5), cy + int(3.8 * b)),
            (cx - int(0.3 * b) + lean_offset + int((ghost_drift + ghost_flow) * 0.5), cy + int(3.8 * b)),
            (cx - int(2.0 * b) + lean_offset - int(wave * 0.2 * ghost_wave_boost * b) + int(ghost_drift + ghost_flow), skirt_bottom_y),
        ]
        shadow_pts = [(px + 2, py + 2) for px, py in skirt_points]
        pygame.draw.polygon(screen, p["dress_shadow"], shadow_pts)
        pygame.draw.polygon(screen, p["dress"], skirt_points)
        # 드레스 가장자리 하이라이트
        pygame.draw.lines(screen, p["dress_edge"], True, skirt_points, 1)

        # 드레스 주름 (우아한 세로 라인)
        for i in range(7):
            fold_shift = int((ghost_drift + ghost_flow) * (i - 3) * 0.07)
            fold_x = cx + int((i - 3) * 0.32 * b) + lean_offset + fold_shift
            fold_top = torso_y + int(1.4 * b)
            fold_bot = cy + int(3.2 * b) + int(wave * 0.05 * (i - 3) * ghost_wave_boost * b)
            pygame.draw.line(screen, p["dress_mid"], (fold_x, fold_top), (fold_x, fold_bot), 1)

        # === 해골 얼굴 장식 (치마 하단에 3개) ===
        num_skulls = 3
        skull_row_y = cy + int(2.2 * b)
        for si in range(num_skulls):
            skull_offset_x = (si - 1) * int(1.1 * b)
            skull_sway = int((ghost_drift + ghost_flow) * 0.3) + int(_sin(self.time * 1.5 + si * 1.2) * 0.08 * b)
            sx = cx + skull_offset_x + lean_offset + skull_sway
            sy = skull_row_y + int(_sin(self.time * 2.0 + si * 0.9) * 0.08 * b)
            sk_size = max(3, int(0.38 * b))

            # 해골 얼굴 본체
            pygame.draw.ellipse(screen, p["skull_shadow"],
                              (sx - sk_size, sy - int(sk_size * 0.9),
                               sk_size * 2, int(sk_size * 1.8)))
            pygame.draw.ellipse(screen, p["skull_white"],
                              (sx - sk_size + 1, sy - int(sk_size * 0.85),
                               sk_size * 2 - 2, int(sk_size * 1.7)))

            # 해골 눈구멍 (어두운 보라 구멍)
            eye_sp = max(1, int(sk_size * 0.28))
            eye_sz = max(2, int(sk_size * 0.28))
            for eside in [-1, 1]:
                ex = sx + eside * eye_sp
                ey = sy - int(sk_size * 0.1)
                pygame.draw.ellipse(screen, p["skull_cavity"],
                                  (ex - eye_sz, ey - int(eye_sz * 0.7),
                                   eye_sz * 2, int(eye_sz * 1.4)))
                # 눈구멍 안쪽 미세 보라빛
                tiny_glow = max(1, eye_sz // 2)
                glow_a = int(30 + 20 * soul_pulse)
                gs = self._get_surface(tiny_glow * 4, tiny_glow * 4)
                pygame.draw.circle(gs, (*p["eye_glow"], glow_a),
                                 (tiny_glow * 2, tiny_glow * 2), tiny_glow)
                screen.blit(gs, (ex - tiny_glow * 2, ey - tiny_glow * 2),
                           special_flags=pygame.BLEND_ADD)

            # 코 구멍 (역삼각형)
            nose_y = sy + int(sk_size * 0.2)
            nose_w = max(1, int(sk_size * 0.15))
            pygame.draw.polygon(screen, p["skull_cavity"], [
                (sx, nose_y - max(1, int(sk_size * 0.08))),
                (sx - nose_w, nose_y + max(1, int(sk_size * 0.1))),
                (sx + nose_w, nose_y + max(1, int(sk_size * 0.1))),
            ])

            # 이빨 (하단 가로줄)
            teeth_y = sy + int(sk_size * 0.45)
            teeth_w = max(2, int(sk_size * 0.5))
            pygame.draw.line(screen, p["skull_dark"],
                           (sx - teeth_w, teeth_y), (sx + teeth_w, teeth_y), 1)
            # 이빨 세로 구분선
            num_teeth = max(2, int(sk_size * 0.3))
            for ti in range(num_teeth):
                tx = sx - teeth_w + int((ti + 0.5) * teeth_w * 2 / num_teeth)
                pygame.draw.line(screen, p["skull_dark"],
                               (tx, teeth_y - max(1, int(sk_size * 0.1))),
                               (tx, teeth_y + max(1, int(sk_size * 0.08))), 1)

        # 치마 하단 유령 페이드 (보라빛 투명 꼬리)
        for layer in range(4):
            tail_y = cy + int(3.1 * b) + layer * int(0.22 * b)
            tail_w = int(1.5 * b) - layer * int(0.15 * b)
            layer_factor = 1.0 + layer * 0.3
            layer_sway = int((ghost_drift + ghost_flow) * layer_factor)
            tail_alpha = max(5, int((80 - layer * 18) * flicker))
            tail_surf = self._get_surface(int(tail_w * 2 + 4), int(0.3 * b))
            tail_rect = (0, 0, tail_surf.get_width(), tail_surf.get_height())
            pygame.draw.ellipse(tail_surf, (*p["aura_inner"], tail_alpha), tail_rect)
            screen.blit(tail_surf,
                       (cx - tail_w + lean_offset + layer_sway, int(tail_y)))

        # 치마 하단 보라 트림 라인
        trim_y = cy + int(3.0 * b)
        trim_left = cx - int(1.8 * b) + lean_offset + int(ghost_drift + ghost_flow)
        trim_right = cx + int(1.8 * b) + lean_offset + int(ghost_drift + ghost_flow)
        pygame.draw.line(screen, p["dress_trim"], (trim_left, trim_y), (trim_right, trim_y), max(1, b // 5))

        # === 몸통 (코르셋 + 갈비뼈 장식) ===
        torso_w = int(1.3 * b)
        torso_h = int(2.3 * b)
        torso_rect = (cx - torso_w // 2 + lean_offset, torso_y - int(0.3 * b),
                     torso_w, torso_h)
        pygame.draw.ellipse(screen, p["dress_dark"], torso_rect)

        # 코르셋 라인 (X 형태)
        corset_top = torso_y + int(0.1 * b)
        corset_bot = torso_y + int(1.2 * b)
        corset_w = int(0.45 * b)
        pygame.draw.line(screen, p["dress_trim"],
                        (cx - corset_w + lean_offset, corset_top),
                        (cx + corset_w + lean_offset, corset_bot), 1)
        pygame.draw.line(screen, p["dress_trim"],
                        (cx + corset_w + lean_offset, corset_top),
                        (cx - corset_w + lean_offset, corset_bot), 1)
        # 코르셋 가운데 세로 라인
        pygame.draw.line(screen, p["dress_trim"],
                        (cx + lean_offset, corset_top - int(0.1 * b)),
                        (cx + lean_offset, corset_bot + int(0.1 * b)), 1)

        # 갈비뼈 패턴 (드레스 위에 뼈 장식)
        for ri in range(3):
            rib_y = torso_y + int(0.2 * b) + ri * int(0.35 * b)
            rib_w = int(0.5 * b) - ri * int(0.05 * b)
            rib_alpha = int((55 + 15 * ghost_pulse) * flicker)
            rib_surf = self._get_surface(int(rib_w * 2 + 4), int(0.2 * b))
            for rside in [-1, 1]:
                rx = rib_w + 2 + rside * int(0.05 * b)
                ry = int(0.1 * b)
                rr_w = int(rib_w * 0.85)
                rr_h = max(2, int(0.08 * b))
                pygame.draw.arc(rib_surf, (*p["rib_bone"], rib_alpha),
                              (rx - rr_w if rside == -1 else rx, ry - rr_h,
                               rr_w, rr_h * 2),
                              0 if rside == 1 else math.pi,
                              math.pi if rside == 1 else math.pi * 2, 1)
            screen.blit(rib_surf,
                       (cx - rib_w - 2 + lean_offset, rib_y),
                       special_flags=pygame.BLEND_ADD)

        # 드레스 상체 엣지
        pygame.draw.ellipse(screen, p["dress_edge"], torso_rect, 1)

        # 허리 벨트 (골드 + 해골 버클)
        belt_y = torso_y + int(1.0 * b)
        belt_w = int(1.4 * b)
        belt_thickness = max(2, int(0.12 * b))
        pygame.draw.line(screen, p["gold_dark"],
                        (cx - belt_w // 2 + lean_offset, belt_y),
                        (cx + belt_w // 2 + lean_offset, belt_y), belt_thickness)
        pygame.draw.line(screen, p["gold"],
                        (cx - belt_w // 2 + lean_offset, belt_y - 1),
                        (cx + belt_w // 2 + lean_offset, belt_y - 1), max(1, belt_thickness - 1))
        # 벨트 해골 버클
        buckle_sz = max(2, int(0.15 * b))
        pygame.draw.circle(screen, p["skull_white"], (cx + lean_offset, belt_y), buckle_sz)
        pygame.draw.circle(screen, p["skull_shadow"], (cx + lean_offset, belt_y), buckle_sz, 1)
        if buckle_sz >= 3:
            for bside in [-1, 1]:
                pygame.draw.circle(screen, p["skull_cavity"],
                                 (cx + lean_offset + bside * max(1, buckle_sz // 3), belt_y - 1),
                                 max(1, buckle_sz // 4))

        # === 어깨 (뼈 숄더 장식) ===
        shoulder_w = int(1.7 * b)
        shoulder_y_val = torso_y - int(0.1 * b) + int(shoulder_bob * b)
        # 어깨 패드 (뼈 장식)
        for sside in [-1, 1]:
            sp_x = cx + sside * int(0.65 * b) + lean_offset
            sp_y = shoulder_y_val + int(0.05 * b)
            sp_w = int(0.55 * b)
            sp_h = int(0.35 * b)
            # 뼈 어깨 패드
            pygame.draw.ellipse(screen, p["bone_shadow"],
                              (sp_x - sp_w // 2, sp_y - sp_h // 2, sp_w, sp_h))
            pygame.draw.ellipse(screen, p["bone"],
                              (sp_x - sp_w // 2 + 1, sp_y - sp_h // 2, sp_w - 2, sp_h - 1))
            # 어깨 뼈 돌기 (작은 뼈 뿔)
            spike_x = sp_x + sside * int(0.2 * b)
            spike_y = sp_y - int(0.15 * b)
            pygame.draw.polygon(screen, p["bone_light"], [
                (spike_x, spike_y - int(0.15 * b)),
                (spike_x - int(0.06 * b), spike_y + int(0.05 * b)),
                (spike_x + int(0.06 * b), spike_y + int(0.05 * b)),
            ])

        # === 팔 (스켈레톤 팔뼈) ===
        weapon_swing = anim.get("weapon_swing_angle", 0)
        left_arm_swing = anim.get("left_arm_swing", 0)
        right_arm_swing = anim.get("right_arm_swing", 0)

        # 지팡이 든 손: 정면=왼손(side==-1), 뒷모습=오른손(side==1)
        _staff_side = -1 if not show_back else 1
        for side in [-1, 1]:
            arm_swing_val = left_arm_swing if side == -1 else right_arm_swing
            shoulder_x = cx + side * int(0.8 * b) + lean_offset
            shoulder_y_arm = torso_y + int(shoulder_bob * b)

            # 지팡이 팔 공 타격 시 안쪽으로 휘두르기 (키르케 스타일)
            if side == _staff_side and weapon_swing != 0:
                swing_x = int(weapon_swing * 4.0 * b)
                swing_y = int(abs(weapon_swing) * 1.5 * b)
                elbow_x = shoulder_x + side * int(0.3 * b) + swing_x
                elbow_y = shoulder_y_arm + int(1.0 * b) - swing_y
                hand_x = elbow_x + side * int(0.2 * b) + int(swing_x * 0.6)
                hand_y = elbow_y + int(0.7 * b) - int(swing_y * 0.6)
            else:
                # 팔꿈치
                elbow_x = shoulder_x + side * int(0.3 * b)
                elbow_y = shoulder_y_arm + int(1.0 * b) + int(arm_swing_val * 0.3 * b)
                # 손
                hand_x = elbow_x + side * int(0.2 * b)
                hand_y = elbow_y + int(0.7 * b) + int(arm_swing_val * 0.2 * b)

            # 상완골 (두꺼운 뼈)
            arm_thick = max(2, int(0.18 * b))
            pygame.draw.line(screen, p["bone_shadow"],
                           (shoulder_x, shoulder_y_arm),
                           (elbow_x, elbow_y), arm_thick + 1)
            pygame.draw.line(screen, p["bone"],
                           (shoulder_x, shoulder_y_arm),
                           (elbow_x, elbow_y), arm_thick)
            # 뼈 하이라이트
            pygame.draw.line(screen, p["bone_light"],
                           (shoulder_x - 1, shoulder_y_arm),
                           (elbow_x - 1, elbow_y), max(1, arm_thick // 2))

            # 팔꿈치 관절
            joint_sz = max(2, int(0.1 * b))
            pygame.draw.circle(screen, p["bone_joint"], (int(elbow_x), int(elbow_y)), joint_sz)
            pygame.draw.circle(screen, p["bone_shadow"], (int(elbow_x), int(elbow_y)), joint_sz, 1)

            # 전완골 (아래팔)
            forearm_thick = max(2, int(0.14 * b))
            pygame.draw.line(screen, p["bone_shadow"],
                           (elbow_x, elbow_y),
                           (hand_x, hand_y), forearm_thick + 1)
            pygame.draw.line(screen, p["bone"],
                           (elbow_x, elbow_y),
                           (hand_x, hand_y), forearm_thick)

            # 해골 손 (5개 손가락 뼈)
            hand_size = max(2, int(0.15 * b))
            pygame.draw.circle(screen, p["bone"], (int(hand_x), int(hand_y)), hand_size)
            pygame.draw.circle(screen, p["bone_shadow"], (int(hand_x), int(hand_y)), hand_size, 1)
            # 손가락 뼈 (3개 표현)
            for fi in range(3):
                f_angle = (fi - 1) * 0.4 + side * 0.2
                f_len = max(2, int(0.12 * b))
                fx = int(hand_x + _cos(f_angle) * f_len * side)
                fy = int(hand_y + _sin(f_angle) * f_len + f_len * 0.5)
                pygame.draw.line(screen, p["bone_light"],
                               (int(hand_x), int(hand_y)), (fx, fy), 1)

            # 왼손에 뼈 홀(셉터) (뒷모습이면 오른손)
            if side == _staff_side:
                staff_bottom_x = hand_x
                staff_bottom_y = hand_y
                # 스윙 시 지팡이 상단도 같이 휘둘러짐
                if weapon_swing != 0:
                    ws_x = int(weapon_swing * 3.0 * b)
                    ws_y = int(abs(weapon_swing) * 2.0 * b)
                    staff_top_x = hand_x + side * int(0.1 * b) + ws_x
                    staff_top_y = torso_y - int(2.5 * b) - ws_y
                else:
                    staff_top_x = hand_x + side * int(0.1 * b)
                    staff_top_y = torso_y - int(2.5 * b)

                # 지팡이 주위 검은 기운 (뼈 셉터를 감싸는 어둠)
                for di in range(4):
                    dt_val = (di + 0.5) / 4.0
                    dark_x = int(staff_bottom_x + (staff_top_x - staff_bottom_x) * dt_val)
                    dark_y = int(staff_bottom_y + (staff_top_y - staff_bottom_y) * dt_val)
                    dark_sway_x = int(_sin(self.time * 1.5 + di * 1.8) * 0.2 * b)
                    dark_sway_y = int(_cos(self.time * 1.2 + di * 2.1) * 0.1 * b)
                    dark_sz = max(3, int(0.15 * b + 0.05 * b * _sin(self.time * 2.0 + di)))
                    dark_a = int((35 + 20 * _sin(self.time * 2.8 + di * 0.9)) * flicker)
                    ds = self._get_surface(dark_sz * 4, dark_sz * 4)
                    pygame.draw.circle(ds, (8, 2, 15, max(0, dark_a)),
                                     (dark_sz * 2, dark_sz * 2), dark_sz)
                    screen.blit(ds, (dark_x + dark_sway_x - dark_sz * 2,
                                    dark_y + dark_sway_y - dark_sz * 2))

                # 뼈 셉터 몸체 (척추뼈 모양)
                seg_count = 8
                for seg in range(seg_count):
                    t0 = seg / seg_count
                    t1 = (seg + 1) / seg_count
                    sx0 = int(staff_bottom_x + (staff_top_x - staff_bottom_x) * t0)
                    sy0 = int(staff_bottom_y + (staff_top_y - staff_bottom_y) * t0)
                    sx1 = int(staff_bottom_x + (staff_top_x - staff_bottom_x) * t1)
                    sy1 = int(staff_bottom_y + (staff_top_y - staff_bottom_y) * t1)
                    seg_thick = max(2, int(0.12 * b))
                    pygame.draw.line(screen, p["scepter_dark"],
                                   (sx0, sy0), (sx1, sy1), seg_thick + 1)
                    pygame.draw.line(screen, p["scepter_bone"],
                                   (sx0, sy0), (sx1, sy1), seg_thick)
                    # 척추 마디 표시
                    if seg < seg_count - 1:
                        node_sz = max(1, int(0.05 * b))
                        pygame.draw.circle(screen, p["bone_joint"], (sx1, sy1), node_sz)

                # 셉터 상단 섬뜩한 대형 해골 장식
                skull_top_x = int(staff_top_x)
                skull_top_y = int(staff_top_y) - int(0.3 * b)  # 해골 중심을 위로 올림
                skull_sz = max(6, int(0.65 * b))

                # 해골 주변 검은 기운 (어둠의 안개)
                for aura_i in range(4):
                    aura_r = skull_sz + int((5 + aura_i * 4) + 4 * soul_pulse)
                    aura_a = int((40 - aura_i * 9) * flicker)
                    aura_s = self._get_surface(aura_r * 4, aura_r * 4)
                    pygame.draw.circle(aura_s, (5, 0, 10, max(0, aura_a)),
                                     (aura_r * 2, aura_r * 2), aura_r)
                    screen.blit(aura_s,
                               (skull_top_x - aura_r * 2, skull_top_y - aura_r * 2))
                # 검은 기운 회오리 파티클 (해골 주위를 감도는)
                for wi in range(5):
                    wisp_angle = self.time * 1.2 + wi * math.pi * 2 / 5
                    wisp_r = skull_sz + int(3 + 4 * _sin(self.time * 0.8 + wi))
                    wisp_x = skull_top_x + int(_cos(wisp_angle) * wisp_r)
                    wisp_y = skull_top_y + int(_sin(wisp_angle) * wisp_r * 0.7)
                    wisp_sz = max(2, int(0.12 * b + 0.04 * b * _sin(self.time * 2.5 + wi)))
                    wisp_a = int((50 + 25 * _sin(self.time * 3.0 + wi * 1.2)) * flicker)
                    ws = self._get_surface(wisp_sz * 4, wisp_sz * 4)
                    pygame.draw.circle(ws, (8, 2, 15, max(0, wisp_a)),
                                     (wisp_sz * 2, wisp_sz * 2), wisp_sz)
                    screen.blit(ws, (wisp_x - wisp_sz * 2, wisp_y - wisp_sz * 2))

                # 두개골 본체 (위쪽 둥근 머리 + 아래쪽 턱)
                cranium_w = int(skull_sz * 2.0)
                cranium_h = int(skull_sz * 1.7)
                jaw_h = int(skull_sz * 0.7)

                # 두개골 그림자
                pygame.draw.ellipse(screen, p["skull_shadow"],
                                  (skull_top_x - cranium_w // 2 + 2,
                                   skull_top_y - cranium_h // 2 + 2,
                                   cranium_w, cranium_h))
                # 두개골 메인
                pygame.draw.ellipse(screen, p["skull_white"],
                                  (skull_top_x - cranium_w // 2,
                                   skull_top_y - cranium_h // 2,
                                   cranium_w, cranium_h))
                # 두개골 하이라이트 (이마 광택)
                pygame.draw.ellipse(screen, p["skull_light"],
                                  (skull_top_x - cranium_w // 4,
                                   skull_top_y - cranium_h // 2 + 1,
                                   cranium_w // 2, cranium_h // 3))

                # 관자놀이 음영 (양쪽 깊은 홈)
                for tside in [-1, 1]:
                    temple_x = skull_top_x + tside * int(skull_sz * 0.65)
                    pygame.draw.ellipse(screen, p["skull_shadow"],
                                      (temple_x - int(skull_sz * 0.25),
                                       skull_top_y - int(skull_sz * 0.15),
                                       int(skull_sz * 0.5), int(skull_sz * 0.6)))

                # 광대뼈 돌출 (양쪽 뾰족하게)
                for cside in [-1, 1]:
                    cheek_x = skull_top_x + cside * int(skull_sz * 0.7)
                    cheek_y = skull_top_y + int(skull_sz * 0.2)
                    cheek_w = max(3, int(skull_sz * 0.4))
                    cheek_h = max(3, int(skull_sz * 0.3))
                    pygame.draw.ellipse(screen, p["skull_shadow"],
                                      (cheek_x - cheek_w // 2, cheek_y - cheek_h // 2,
                                       cheek_w, cheek_h))

                # 눈구멍 (크고 깊고 무서운)
                eye_y = skull_top_y - int(skull_sz * 0.05)
                for meside in [-1, 1]:
                    ex = skull_top_x + meside * int(skull_sz * 0.38)
                    ew = max(4, int(skull_sz * 0.38))
                    eh = max(4, int(skull_sz * 0.35))
                    # 눈구멍 외곽 (위 좁고 아래 넓은 오각형)
                    eye_pts = [
                        (ex - int(ew * 0.35), eye_y - int(eh * 0.55)),
                        (ex + int(ew * 0.35), eye_y - int(eh * 0.55)),
                        (ex + int(ew * 0.6), eye_y + int(eh * 0.15)),
                        (ex, eye_y + int(eh * 0.65)),
                        (ex - int(ew * 0.6), eye_y + int(eh * 0.15)),
                    ]
                    pygame.draw.polygon(screen, p["skull_cavity"], eye_pts)
                    pygame.draw.polygon(screen, (20, 5, 30), eye_pts, 1)

                    # 어둠의 눈빛 (검은 불꽃 + 작은 보라 점)
                    flame_sz = max(3, int(skull_sz * 0.2 + skull_sz * 0.08 * soul_pulse))
                    flame_flicker_x = int(_sin(self.time * 7.0 + meside * 2.0) * skull_sz * 0.05)
                    flame_flicker_y = int(_sin(self.time * 9.0 + meside * 1.5) * skull_sz * 0.04)
                    flame_cx = ex + flame_flicker_x
                    flame_cy = eye_y + flame_flicker_y

                    # 검은 연기 (눈구멍에서 피어오르는)
                    smoke_sz = flame_sz + int(2 + 2 * soul_pulse)
                    sms = self._get_surface(smoke_sz * 4, smoke_sz * 4)
                    smoke_a = int(55 + 30 * soul_pulse)
                    pygame.draw.circle(sms, (10, 3, 18, max(0, smoke_a)),
                                     (smoke_sz * 2, smoke_sz * 2), smoke_sz)
                    screen.blit(sms, (flame_cx - smoke_sz * 2, flame_cy - smoke_sz * 2))
                    # 눈동자 코어 (작은 보라빛 점)
                    core_sz = max(1, flame_sz // 3)
                    pygame.draw.circle(screen, p["eye_glow"],
                                     (flame_cx, flame_cy), core_sz)
                    pygame.draw.circle(screen, p["eye_core"],
                                     (flame_cx, flame_cy), max(1, core_sz // 2))

                # 코 구멍 (역삼각형, 깊은 구멍)
                nose_y = skull_top_y + int(skull_sz * 0.32)
                nose_w = max(3, int(skull_sz * 0.2))
                nose_h = max(3, int(skull_sz * 0.22))
                pygame.draw.polygon(screen, p["skull_cavity"], [
                    (skull_top_x - nose_w, nose_y - int(nose_h * 0.3)),
                    (skull_top_x + nose_w, nose_y - int(nose_h * 0.3)),
                    (skull_top_x + int(nose_w * 0.5), nose_y + nose_h),
                    (skull_top_x - int(nose_w * 0.5), nose_y + nose_h),
                ])
                # 코 중간 뼈 (비중격)
                pygame.draw.line(screen, p["skull_dark"],
                               (skull_top_x, nose_y - int(nose_h * 0.3)),
                               (skull_top_x, nose_y + int(nose_h * 0.8)), 1)

                # 이마 균열 (섬뜩한 갈라진 금)
                crack_start_x = skull_top_x - int(skull_sz * 0.1)
                crack_start_y = skull_top_y - int(skull_sz * 0.6)
                crack_color = (90, 75, 65)
                crack_pts = [
                    (crack_start_x, crack_start_y),
                    (crack_start_x + int(skull_sz * 0.06), crack_start_y + int(skull_sz * 0.22)),
                    (crack_start_x - int(skull_sz * 0.1), crack_start_y + int(skull_sz * 0.4)),
                    (crack_start_x + int(skull_sz * 0.04), crack_start_y + int(skull_sz * 0.55)),
                ]
                if len(crack_pts) >= 2:
                    pygame.draw.lines(screen, crack_color, False, crack_pts, max(1, b // 12))
                # 갈라짐 분기
                pygame.draw.line(screen, crack_color,
                               crack_pts[1],
                               (crack_pts[1][0] + int(skull_sz * 0.15),
                                crack_pts[1][1] + int(skull_sz * 0.1)), max(1, b // 12))
                # 두 번째 분기 (오른쪽 이마)
                crack2_x = skull_top_x + int(skull_sz * 0.2)
                crack2_y = skull_top_y - int(skull_sz * 0.5)
                pygame.draw.lines(screen, crack_color, False, [
                    (crack2_x, crack2_y),
                    (crack2_x + int(skull_sz * 0.08), crack2_y + int(skull_sz * 0.18)),
                    (crack2_x - int(skull_sz * 0.04), crack2_y + int(skull_sz * 0.3)),
                ], max(1, b // 14))

                # 턱뼈 (분리된 하악골 - 미세하게 벌어짐)
                jaw_y = skull_top_y + int(skull_sz * 0.55)
                jaw_w = int(skull_sz * 0.8)
                jaw_bob = int(_sin(self.time * 1.8) * skull_sz * 0.04)
                # 턱 본체
                jaw_pts = [
                    (skull_top_x - jaw_w, jaw_y + jaw_bob),
                    (skull_top_x + jaw_w, jaw_y + jaw_bob),
                    (skull_top_x + int(jaw_w * 0.65), jaw_y + jaw_h + jaw_bob),
                    (skull_top_x - int(jaw_w * 0.65), jaw_y + jaw_h + jaw_bob),
                ]
                pygame.draw.polygon(screen, p["skull_shadow"], jaw_pts)
                jaw_inner = [
                    (skull_top_x - jaw_w + 1, jaw_y + jaw_bob + 1),
                    (skull_top_x + jaw_w - 1, jaw_y + jaw_bob + 1),
                    (skull_top_x + int(jaw_w * 0.6), jaw_y + jaw_h + jaw_bob - 1),
                    (skull_top_x - int(jaw_w * 0.6), jaw_y + jaw_h + jaw_bob - 1),
                ]
                pygame.draw.polygon(screen, p["skull_white"], jaw_inner)

                # 이빨 (위턱 + 아래턱, 삐뚤빼뚤하고 날카로운)
                teeth_y_upper = jaw_y + jaw_bob - 1
                teeth_y_lower = jaw_y + jaw_bob + 2
                teeth_w = int(jaw_w * 0.85)
                num_teeth = max(4, int(skull_sz * 0.45))
                tooth_gap = teeth_w * 2 / num_teeth if num_teeth > 0 else teeth_w
                for ti in range(num_teeth):
                    tx = skull_top_x - teeth_w + int((ti + 0.5) * tooth_gap)
                    # 위 이빨 (아래로 삐죽, 불규칙)
                    tooth_h = max(2, int(skull_sz * 0.14 + _sin(ti * 1.7) * skull_sz * 0.05))
                    tooth_w_half = max(1, int(tooth_gap * 0.32))
                    pygame.draw.polygon(screen, p["skull_light"], [
                        (tx - tooth_w_half, teeth_y_upper),
                        (tx + tooth_w_half, teeth_y_upper),
                        (tx + int(tooth_w_half * 0.3), teeth_y_upper + tooth_h),
                        (tx - int(tooth_w_half * 0.3), teeth_y_upper + tooth_h),
                    ])
                    # 아래 이빨 (위로 삐죽)
                    btooth_h = max(2, int(skull_sz * 0.1 + _sin(ti * 2.3) * skull_sz * 0.04))
                    pygame.draw.polygon(screen, p["skull_light"], [
                        (tx - tooth_w_half, teeth_y_lower + 1),
                        (tx + tooth_w_half, teeth_y_lower + 1),
                        (tx + int(tooth_w_half * 0.25), teeth_y_lower - btooth_h),
                        (tx - int(tooth_w_half * 0.25), teeth_y_lower - btooth_h),
                    ])

                # 이빨 사이 어두운 틈
                for ti in range(num_teeth - 1):
                    gap_x = skull_top_x - teeth_w + int((ti + 1) * tooth_gap)
                    pygame.draw.line(screen, p["skull_cavity"],
                                   (gap_x, teeth_y_upper - 1),
                                   (gap_x, teeth_y_lower + 2), 1)

                # 두개골 테두리 (뼈 음영 강조)
                pygame.draw.ellipse(screen, p["skull_dark"],
                                  (skull_top_x - cranium_w // 2,
                                   skull_top_y - cranium_h // 2,
                                   cranium_w, cranium_h), max(1, b // 10))

        # === 목걸이 (해골 체인) ===
        neck_y = torso_y - int(0.15 * b)
        neck_w = int(0.5 * b)
        # 체인 아크
        chain_pts = []
        for ci in range(7):
            ct = ci / 6.0
            chain_x = cx + lean_offset + int((ct - 0.5) * 2 * neck_w)
            chain_y = neck_y + int(_sin(ct * math.pi) * 0.25 * b)
            chain_pts.append((chain_x, chain_y))
        if len(chain_pts) >= 2:
            pygame.draw.lines(screen, p["necklace_chain"], False, chain_pts, 1)
        # 목걸이 중앙 해골 펜던트
        pendant_x = cx + lean_offset
        pendant_y = neck_y + int(0.25 * b)
        pend_sz = max(2, int(0.16 * b))
        pygame.draw.circle(screen, p["skull_white"], (pendant_x, pendant_y), pend_sz)
        pygame.draw.circle(screen, p["skull_shadow"], (pendant_x, pendant_y), pend_sz, 1)
        if pend_sz >= 3:
            for pside in [-1, 1]:
                pygame.draw.circle(screen, p["skull_cavity"],
                                 (pendant_x + pside * max(1, pend_sz // 3), pendant_y - 1),
                                 max(1, pend_sz // 4))

        # === 머리 (해골 여왕 얼굴 + 뼈 왕관) ===
        head_x = cx + lean_offset
        head_y = torso_y - int(1.3 * b)
        head_r = int(0.85 * b)

        if not show_back:
            # === 정면 - 해골 얼굴 ===

            # 해골 머리 기본 형태
            skull_w = int(1.7 * b)
            skull_h = int(1.6 * b)
            skull_rect = (head_x - skull_w // 2, head_y - int(0.5 * b),
                         skull_w, skull_h)
            pygame.draw.ellipse(screen, p["skull_shadow"], skull_rect)
            inner_skull = (head_x - skull_w // 2 + 1, head_y - int(0.5 * b) + 1,
                          skull_w - 2, skull_h - 2)
            pygame.draw.ellipse(screen, p["skull_white"], inner_skull)

            # 광대뼈 음영
            for cside in [-1, 1]:
                cheek_x = head_x + cside * int(0.4 * b)
                cheek_y = head_y + int(0.25 * b)
                cheek_sz = max(2, int(0.18 * b))
                pygame.draw.ellipse(screen, p["skull_shadow"],
                                  (cheek_x - cheek_sz, cheek_y - cheek_sz // 2,
                                   cheek_sz * 2, cheek_sz))

            # 눈구멍 (크고 깊은)
            eye_y = head_y + int(0.05 * b)
            for eside in [-1, 1]:
                eye_x = head_x + eside * int(0.32 * b)
                eye_w = max(3, int(0.25 * b))
                eye_h = max(3, int(0.22 * b))
                # 깊은 눈구멍
                pygame.draw.ellipse(screen, p["skull_cavity"],
                                  (eye_x - eye_w, eye_y - eye_h,
                                   eye_w * 2, eye_h * 2))
                # 보라빛 영혼의 눈
                soul_eye_sz = max(2, int(0.13 * b + 0.03 * b * soul_pulse))
                eye_glow_surf = self._get_surface(soul_eye_sz * 4, soul_eye_sz * 4)
                eye_glow_a = int(70 + 50 * soul_pulse)
                pygame.draw.circle(eye_glow_surf,
                                 (*p["eye_glow"], eye_glow_a),
                                 (soul_eye_sz * 2, soul_eye_sz * 2), soul_eye_sz)
                screen.blit(eye_glow_surf,
                           (eye_x - soul_eye_sz * 2, eye_y - soul_eye_sz * 2),
                           special_flags=pygame.BLEND_ADD)
                # 눈 코어 (밝은 점)
                core_sz = max(1, int(0.07 * b))
                pygame.draw.circle(screen, p["eye_core"],
                                 (eye_x, eye_y), core_sz)

            # 코 구멍 (역하트 모양)
            nose_y = head_y + int(0.3 * b)
            nose_w = max(1, int(0.1 * b))
            pygame.draw.polygon(screen, p["skull_cavity"], [
                (head_x, nose_y - max(1, int(0.06 * b))),
                (head_x - nose_w, nose_y + max(1, int(0.08 * b))),
                (head_x + nose_w, nose_y + max(1, int(0.08 * b))),
            ])

            # 이빨 (상단 + 하단)
            jaw_y = head_y + int(0.45 * b)
            jaw_w = max(3, int(0.35 * b))
            # 윗니
            teeth_top = jaw_y - max(1, int(0.05 * b))
            pygame.draw.line(screen, p["skull_dark"],
                           (head_x - jaw_w, teeth_top),
                           (head_x + jaw_w, teeth_top), 1)
            # 아랫니
            teeth_bot = jaw_y + max(1, int(0.05 * b))
            pygame.draw.line(screen, p["skull_dark"],
                           (head_x - jaw_w, teeth_bot),
                           (head_x + jaw_w, teeth_bot), 1)
            # 이빨 세로줄
            num_teeth = max(3, int(jaw_w * 0.5))
            for ti in range(num_teeth):
                tx = head_x - jaw_w + int((ti + 0.5) * jaw_w * 2 / num_teeth)
                pygame.draw.line(screen, p["skull_dark"],
                               (tx, teeth_top - 1), (tx, teeth_bot + 1), 1)

            # 턱선
            jaw_bottom = head_y + int(0.55 * b)
            pygame.draw.arc(screen, p["skull_shadow"],
                          (head_x - int(0.5 * b), jaw_y - int(0.1 * b),
                           int(1.0 * b), int(0.4 * b)),
                          math.pi * 0.1, math.pi * 0.9, 1)

            # === 뼈 왕관 (해골의 여왕 상징) ===
            crown_base_y = head_y - int(0.55 * b)
            crown_w = int(0.9 * b)

            # 왕관 베이스 밴드
            band_h = max(2, int(0.12 * b))
            pygame.draw.rect(screen, p["crown_bone_shadow"],
                           (head_x - crown_w, crown_base_y, crown_w * 2, band_h))
            pygame.draw.rect(screen, p["crown_bone"],
                           (head_x - crown_w + 1, crown_base_y, crown_w * 2 - 2, band_h - 1))

            # 왕관 뼈 뿔 (5개 - 뾰족한 뼈 기둥)
            spike_positions = [-0.7, -0.35, 0, 0.35, 0.7]
            spike_heights = [0.35, 0.55, 0.7, 0.55, 0.35]
            for spi, (sp_pos, sp_ht) in enumerate(zip(spike_positions, spike_heights)):
                spike_x = head_x + int(sp_pos * crown_w)
                spike_base = crown_base_y
                spike_top = crown_base_y - int(sp_ht * b)
                spike_w_half = max(1, int(0.06 * b))

                # 뼈 뿔 형태
                spike_pts = [
                    (spike_x - spike_w_half, spike_base),
                    (spike_x, spike_top),
                    (spike_x + spike_w_half, spike_base),
                ]
                pygame.draw.polygon(screen, p["crown_bone_shadow"], spike_pts)
                inner_pts = [
                    (spike_x - spike_w_half + 1, spike_base),
                    (spike_x, spike_top + 1),
                    (spike_x + spike_w_half - 1, spike_base),
                ]
                if spike_w_half > 1:
                    pygame.draw.polygon(screen, p["crown_bone"], inner_pts)

                # 중앙 뿔에 보석
                if spi == 2:
                    gem_y = spike_top + int(0.12 * b)
                    gem_sz = max(2, int(0.08 * b))
                    pygame.draw.circle(screen, p["crown_gem"], (spike_x, gem_y), gem_sz)
                    # 보석 글로우
                    gem_gl_sz = gem_sz + int(1 + 2 * crown_shimmer)
                    gem_gl_surf = self._get_surface(gem_gl_sz * 4, gem_gl_sz * 4)
                    gem_gl_a = int(40 + 30 * crown_shimmer)
                    pygame.draw.circle(gem_gl_surf, (*p["crown_gem_glow"], gem_gl_a),
                                     (gem_gl_sz * 2, gem_gl_sz * 2), gem_gl_sz)
                    screen.blit(gem_gl_surf,
                               (spike_x - gem_gl_sz * 2, gem_y - gem_gl_sz * 2),
                               special_flags=pygame.BLEND_ADD)
                    # 보석 하이라이트
                    pygame.draw.circle(screen, p["eye_core"],
                                     (spike_x - 1, gem_y - 1), max(1, gem_sz // 2))

            # 왕관 골드 트림
            pygame.draw.line(screen, p["gold"],
                           (head_x - crown_w, crown_base_y + band_h - 1),
                           (head_x + crown_w, crown_base_y + band_h - 1), 1)

        else:
            # === 뒷모습 - 해골 뒤통수 + 왕관 뒤 ===

            # 해골 뒤통수
            skull_w = int(1.7 * b)
            skull_h = int(1.6 * b)
            skull_rect = (head_x - skull_w // 2, head_y - int(0.5 * b),
                         skull_w, skull_h)
            pygame.draw.ellipse(screen, p["skull_shadow"], skull_rect)
            pygame.draw.ellipse(screen, p["skull_white"],
                              (head_x - skull_w // 2 + 1, head_y - int(0.5 * b) + 1,
                               skull_w - 2, skull_h - 2))

            # 두개골 뒷면 봉합선 (십자)
            pygame.draw.line(screen, p["skull_dark"],
                           (head_x, head_y - int(0.4 * b)),
                           (head_x, head_y + int(0.4 * b)), 1)
            pygame.draw.line(screen, p["skull_dark"],
                           (head_x - int(0.3 * b), head_y),
                           (head_x + int(0.3 * b), head_y), 1)
            # 봉합선 곡선 디테일
            for bside in [-1, 1]:
                pygame.draw.arc(screen, p["skull_dark"],
                              (head_x + bside * int(0.1 * b) - int(0.15 * b),
                               head_y - int(0.25 * b),
                               int(0.3 * b), int(0.5 * b)),
                              math.pi * (0.3 if bside == 1 else 1.3),
                              math.pi * (0.7 if bside == 1 else 1.7), 1)

            # 뒤쪽 왕관
            crown_base_y = head_y - int(0.55 * b)
            crown_w = int(0.9 * b)
            band_h = max(2, int(0.12 * b))
            pygame.draw.rect(screen, p["crown_bone_shadow"],
                           (head_x - crown_w, crown_base_y, crown_w * 2, band_h))
            pygame.draw.rect(screen, p["crown_bone"],
                           (head_x - crown_w + 1, crown_base_y, crown_w * 2 - 2, band_h - 1))

            # 뒤쪽 뼈 뿔 (보이는 3개)
            back_spikes = [-0.5, 0, 0.5]
            back_heights = [0.4, 0.55, 0.4]
            for sp_pos, sp_ht in zip(back_spikes, back_heights):
                spike_x = head_x + int(sp_pos * crown_w)
                spike_base = crown_base_y
                spike_top = crown_base_y - int(sp_ht * b)
                spike_w_half = max(1, int(0.06 * b))
                spike_pts = [
                    (spike_x - spike_w_half, spike_base),
                    (spike_x, spike_top),
                    (spike_x + spike_w_half, spike_base),
                ]
                pygame.draw.polygon(screen, p["crown_bone_shadow"], spike_pts)
                if spike_w_half > 1:
                    inner_pts = [
                        (spike_x - spike_w_half + 1, spike_base),
                        (spike_x, spike_top + 1),
                        (spike_x + spike_w_half - 1, spike_base),
                    ]
                    pygame.draw.polygon(screen, p["crown_bone"], inner_pts)

            # 골드 트림
            pygame.draw.line(screen, p["gold"],
                           (head_x - crown_w, crown_base_y + band_h - 1),
                           (head_x + crown_w, crown_base_y + band_h - 1), 1)

    # =========================================================================
    # 조커 - 광대 (예측 불가능한 트릭스터) [HD 버전]
    # =========================================================================
    def _draw_joker(self, screen, cx, cy, b, color, show_back, anim):
        """조커 - 광대 (빨강+금 비대칭 코트, 초록 머리, 빨간 코, 제스터 모자) [HD 버전]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        shoulder_bob = anim.get("shoulder_bob", 0)
        left_arm_swing = anim.get("left_arm_swing", 0)
        right_arm_swing = anim.get("right_arm_swing", 0)
        weapon_swing = anim.get("weapon_swing_angle", 0)
        left_leg_sway = anim.get("left_leg_sway", 0)
        right_leg_sway = anim.get("right_leg_sway", 0)

        # 이동 관련 (자연스러운 움직임)
        side_blend = anim.get("side_blend", 0)
        move_dir = anim.get("move_dir", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2.0 * b)
        lean_offset = int(lean * 2.5 * b)

        # 코트 관성 (이동 방향 반대로 나풀거림)
        coat_inertia = -move_dir * side_blend * 0.6 * b
        coat_sway = _sin(self.time * 3.0) * side_blend * 0.3 * b
        coat_wave_boost = 1.0 + side_blend * 2.0

        p = {
            "coat_red": (200, 50, 60),
            "coat_red_light": (230, 80, 90),
            "coat_red_dark": (160, 35, 45),
            "coat_gold": (220, 180, 50),
            "coat_gold_light": (245, 210, 80),
            "coat_gold_dark": (180, 140, 35),
            "coat_purple": (130, 50, 160),
            "coat_purple_light": (160, 80, 200),
            "pants_red": (175, 40, 50),
            "pants_red_light": (200, 65, 75),
            "pants_gold": (195, 155, 40),
            "pants_gold_light": (220, 180, 65),
            "skin": (240, 210, 180),
            "skin_shadow": (210, 180, 150),
            "skin_blush": (255, 180, 170),
            "hair": (50, 170, 55),
            "hair_light": (80, 210, 85),
            "hair_dark": (30, 130, 35),
            "hair_tips": (60, 200, 65),
            "eye_white": (255, 255, 255),
            "eye_iris": (50, 50, 55),
            "eye_pupil": (25, 25, 30),
            "eye_glint": (255, 255, 255),
            "nose_red": (230, 55, 45),
            "nose_shine": (255, 130, 110),
            "lip": (200, 50, 60),
            "lip_dark": (160, 35, 45),
            "bell": (255, 220, 80),
            "bell_shine": (255, 250, 180),
            "bell_dark": (200, 170, 50),
            "collar": (255, 255, 255),
            "collar_shadow": (215, 215, 225),
            "collar_edge": (235, 235, 245),
            "shoe_red": (175, 38, 48),
            "shoe_red_light": (200, 60, 70),
            "shoe_gold": (195, 155, 38),
            "shoe_gold_light": (220, 180, 60),
            "card_white": (255, 255, 255),
            "card_red": (200, 30, 30),
            "card_border": (180, 180, 190),
            "diamond_red": (220, 40, 40),
            "hat_red": (190, 45, 55),
            "hat_gold": (210, 170, 45),
            "hat_purple": (120, 45, 150),
        }

        # === 발밑 카오틱 글로우 (무지개빛 세트 조명) ===
        foot_glow_y = torso_y + int(3.8 * b)
        glow_rx = int(2.5 * b)
        glow_ry = int(0.55 * b)
        glow_surf = self._get_surface(glow_rx * 2 + 4, glow_ry * 2 + 4)
        g_cx, g_cy = glow_rx + 2, glow_ry + 2
        for ring in range(3):
            hue_phase = self.time * 2.5 + ring * 1.2
            r_c = int(127 + 127 * _sin(hue_phase))
            g_c = int(127 + 127 * _sin(hue_phase + 2.094))
            b_c = int(127 + 127 * _sin(hue_phase + 4.189))
            ring_alpha = int((28 - ring * 8) * (0.6 + 0.4 * _sin(self.time * 3.0 + ring)))
            rx = max(3, int((2.5 - ring * 0.6) * b))
            ry = max(2, int((0.55 - ring * 0.12) * b))
            pygame.draw.ellipse(glow_surf, (r_c, g_c, b_c, max(0, ring_alpha)),
                              (g_cx - rx, g_cy - ry, rx * 2, ry * 2))
        screen.blit(glow_surf, (cx - g_cx + lean_offset, foot_glow_y - g_cy),
                   special_flags=pygame.BLEND_ADD)

        # === 코트 꼬리 (뒤에서 나풀거림, 다리 뒤쪽) ===
        coat_tail_drift = int(coat_inertia + coat_sway)
        hip_y = torso_y + int(1.5 * b)
        coat_tail_bottom = hip_y + int(2.2 * b)

        # 왼쪽 코트 꼬리 (빨강)
        tail_l = [
            (cx - int(0.7 * b) + lean_offset, hip_y + int(0.3 * b)),
            (cx - int(0.1 * b) + lean_offset, hip_y + int(0.3 * b)),
            (cx + int(0.1 * b) + lean_offset + coat_tail_drift + int(wave * 0.15 * coat_wave_boost * b), coat_tail_bottom),
            (cx - int(0.9 * b) + lean_offset + coat_tail_drift - int(wave * 0.1 * coat_wave_boost * b), coat_tail_bottom),
        ]
        pygame.draw.polygon(screen, p["coat_red_dark"], tail_l)
        # 꼬리 테두리
        pygame.draw.lines(screen, p["coat_purple"], False,
                         [tail_l[0], tail_l[3], tail_l[2], tail_l[1]], 1)

        # 오른쪽 코트 꼬리 (금색)
        tail_r = [
            (cx + int(0.1 * b) + lean_offset, hip_y + int(0.3 * b)),
            (cx + int(0.7 * b) + lean_offset, hip_y + int(0.3 * b)),
            (cx + int(0.9 * b) + lean_offset + coat_tail_drift + int(wave * 0.1 * coat_wave_boost * b), coat_tail_bottom),
            (cx - int(0.1 * b) + lean_offset + coat_tail_drift - int(wave * 0.15 * coat_wave_boost * b), coat_tail_bottom),
        ]
        pygame.draw.polygon(screen, p["coat_gold_dark"], tail_r)
        pygame.draw.lines(screen, p["coat_purple"], False,
                         [tail_r[0], tail_r[3], tail_r[2], tail_r[1]], 1)

        # 코트 꼬리 끝 지그재그 장식
        for tail, tail_color in [(tail_l, p["coat_gold"]), (tail_r, p["coat_red"])]:
            bx1, by1 = tail[3]
            bx2, by2 = tail[2]
            seg = 5
            for i in range(seg):
                t_r = i / seg
                zx = int(bx1 + (bx2 - bx1) * t_r)
                zy = int(by1 + (by2 - by1) * t_r)
                tri_h = int(0.3 * b)
                if i % 2 == 0:
                    pygame.draw.polygon(screen, tail_color,
                                       [(zx, zy), (zx + int((bx2 - bx1) / seg), zy),
                                        (zx + int((bx2 - bx1) / seg / 2), zy + tri_h)])

        # === 다리 (빨강/금 비대칭, 디테일 강화) ===
        for side in [-1, 1]:
            leg_x = cx + side * int(0.45 * b) + lean_offset
            leg_top = torso_y + int(1.55 * b)
            sway = left_leg_sway if side == -1 else right_leg_sway
            leg_bottom = leg_top + int(1.9 * b) + int(sway * 0.3 * b)
            leg_sway_x = int(sway * 0.5 * b)
            leg_lift = anim.get("left_leg_lift", 0) if side == -1 else anim.get("right_leg_lift", 0)

            # 허벅지
            pants_color = p["pants_red"] if side == -1 else p["pants_gold"]
            pants_light = p["pants_red_light"] if side == -1 else p["pants_gold_light"]
            knee_x = leg_x + int(leg_sway_x * 0.5)
            knee_y = leg_top + int(1.0 * b) + int(sway * 0.15 * b)

            # --- 킥 모션: 기존 다리 한쪽을 들어올려 자연스럽게 차기 ---
            _is_kick = (side == 1 and not show_back) or (side == -1 and show_back)
            _kick_amt = abs(weapon_swing) if _is_kick and weapon_swing != 0 else 0
            _kick_dir = -1 if not show_back else 1  # 하단캐릭: 위로, 상단캐릭: 아래로
            if _kick_amt > 0:
                k = min(1.0, _kick_amt)
                # 허벅지 들어올림: 무릎이 킥 방향으로 자연스럽게 올라감
                knee_y += int(_kick_dir * k * 0.45 * b)
                knee_x += int(k * 0.15 * b * side)

            thigh_w = max(2, int(0.4 * b))
            pygame.draw.line(screen, pants_color,
                           (leg_x, leg_top), (knee_x, knee_y), thigh_w)
            # 하이라이트
            pygame.draw.line(screen, pants_light,
                           (leg_x - 1, leg_top), (knee_x - 1, knee_y), max(1, thigh_w // 3))

            # 정강이
            foot_x = leg_x + leg_sway_x
            foot_y = int(leg_bottom - leg_lift * 0.3 * b)
            if _kick_amt > 0:
                k = min(1.0, _kick_amt)
                # 정강이 스냅: 무릎에서 킥 방향으로 자연스럽게 뻗기
                foot_x = knee_x + int(k * 0.6 * b * side)
                foot_y = knee_y + int((1.0 - k * 0.75) * 0.9 * b)
            shin_w = max(2, int(0.3 * b))
            pygame.draw.line(screen, pants_color,
                           (knee_x, knee_y), (foot_x, foot_y), shin_w)

            # 무릎 관절
            pygame.draw.circle(screen, pants_light, (knee_x, knee_y), max(2, int(0.15 * b)))

            # 뾰족한 어릿광대 신발
            shoe_color = p["shoe_red"] if side == -1 else p["shoe_gold"]
            shoe_light = p["shoe_red_light"] if side == -1 else p["shoe_gold_light"]
            shoe_w = int(0.55 * b)
            shoe_h = max(3, int(0.22 * b))
            # 신발 본체
            shoe_rect = (foot_x - shoe_w // 3, foot_y - shoe_h // 2, shoe_w, shoe_h)
            pygame.draw.ellipse(screen, shoe_color, shoe_rect)
            pygame.draw.ellipse(screen, shoe_light,
                              (shoe_rect[0] + 1, shoe_rect[1] + 1,
                               shoe_rect[2] - 2, shoe_rect[3] // 2))
            # 뾰족한 끝
            tip_x = foot_x + side * int(0.4 * b) + int(move_dir * side_blend * 0.15 * b)
            tip_y = foot_y + int(_sin(self.time * 3 + side) * 0.08 * b)
            if _kick_amt > 0:
                k = min(1.0, _kick_amt)
                tip_x = foot_x + int(k * 0.4 * b * side)
                tip_y = foot_y + int(_kick_dir * k * 0.15 * b)
            pygame.draw.line(screen, shoe_color, (foot_x + side * int(0.15 * b), foot_y),
                           (tip_x, tip_y), max(1, int(0.12 * b)))
            # 끝 방울
            bell_r_shoe = max(2, int(0.1 * b))
            bell_bob_shoe = int(_sin(self.time * 5 + side * 2) * 0.06 * b)
            pygame.draw.circle(screen, p["bell"],
                             (tip_x, tip_y + bell_bob_shoe), bell_r_shoe)
            pygame.draw.circle(screen, p["bell_shine"],
                             (tip_x - 1, tip_y + bell_bob_shoe - 1), max(1, bell_r_shoe // 2))

            # --- 킥 임팩트 이펙트 ---
            if _kick_amt > 0.3:
                _ks = self._get_surface(int(6 * b), int(6 * b))
                _kc_x, _kc_y = _ks.get_width() // 2, _ks.get_height() // 2
                _k_tip_x = _kc_x + (tip_x - cx)
                _k_tip_y = _kc_y + (tip_y - cy)
                # 골드 임팩트 원
                _imp_alpha = int(min(1.0, (_kick_amt - 0.3) * 3.0) * 160)
                _imp_r = int(_kick_amt * 1.2 * b)
                _imp_col = (255, 220, 80, _imp_alpha)
                pygame.draw.circle(_ks, _imp_col, (_k_tip_x, _k_tip_y), _imp_r)
                # 스피드 라인 (발 뒤쪽으로)
                _line_alpha = int(min(1.0, (_kick_amt - 0.3) * 2.5) * 120)
                for _li in range(5):
                    _la = (_li - 2) * 0.15
                    _lx1 = _k_tip_x - int(side * _kick_amt * 1.5 * b) + int(_la * 0.3 * b)
                    _ly1 = _k_tip_y - int(_kick_dir * _kick_amt * 0.5 * b) + int(_li * 0.25 * b)
                    _lx2 = _lx1 - int(side * _kick_amt * 1.8 * b)
                    _ly2 = _ly1 + int(_kick_dir * 0.3 * b)
                    _lcol = (255, 255, 255, max(0, _line_alpha - _li * 15)) if _li != 2 else (255, 200, 60, _line_alpha)
                    pygame.draw.line(_ks, _lcol, (_lx1, _ly1), (_lx2, _ly2), max(1, int(0.06 * b)))
                screen.blit(_ks, (cx - _ks.get_width() // 2, cy - _ks.get_height() // 2))

        # === 몸통 (좌=빨강, 우=금 비대칭 코트) ===
        torso_w = int(2.4 * b)
        torso_h = int(2.0 * b)
        torso_top = torso_y - int(0.2 * b)

        # 코트 그림자
        shadow_rect = pygame.Rect(cx - torso_w // 2 + lean_offset + 2,
                                   torso_top + 2, torso_w, torso_h)
        pygame.draw.rect(screen, (30, 20, 20), shadow_rect, border_radius=max(2, int(0.3 * b)))

        # 왼쪽 반 (빨강)
        left_rect = pygame.Rect(cx - torso_w // 2 + lean_offset, torso_top,
                                torso_w // 2, torso_h)
        pygame.draw.rect(screen, p["coat_red"], left_rect, border_radius=max(2, int(0.25 * b)))
        # 빨강 하이라이트
        hl_rect = pygame.Rect(left_rect.x + int(0.2 * b), left_rect.y + int(0.2 * b),
                               left_rect.width // 3, left_rect.height - int(0.4 * b))
        pygame.draw.rect(screen, p["coat_red_light"], hl_rect, border_radius=2)

        # 오른쪽 반 (금)
        right_rect = pygame.Rect(cx + lean_offset, torso_top,
                                  torso_w // 2 + 1, torso_h)
        pygame.draw.rect(screen, p["coat_gold"], right_rect, border_radius=max(2, int(0.25 * b)))
        # 금 하이라이트
        hl_rect2 = pygame.Rect(right_rect.x + int(0.15 * b), right_rect.y + int(0.2 * b),
                                right_rect.width // 3, right_rect.height - int(0.4 * b))
        pygame.draw.rect(screen, p["coat_gold_light"], hl_rect2, border_radius=2)

        # 중앙 세로 퍼플 라인
        center_x = cx + lean_offset
        line_w = max(2, int(0.12 * b))
        pygame.draw.line(screen, p["coat_purple"],
                        (center_x, torso_top + int(0.1 * b)),
                        (center_x, torso_top + torso_h - int(0.1 * b)), line_w)

        # 다이아몬드 단추 3개
        for i in range(3):
            btn_y = torso_top + int(0.35 * b) + i * int(0.5 * b)
            btn_s = max(3, int(0.12 * b))
            diamond = [
                (center_x, btn_y - btn_s),
                (center_x + btn_s, btn_y),
                (center_x, btn_y + btn_s),
                (center_x - btn_s, btn_y),
            ]
            pygame.draw.polygon(screen, p["bell"], diamond)
            pygame.draw.polygon(screen, p["bell_dark"], diamond, 1)
            # 단추 반짝임
            pygame.draw.circle(screen, p["bell_shine"],
                             (center_x - 1, btn_y - 1), max(1, btn_s // 3))

        # 허리 벨트 (퍼플 + 버클)
        belt_y = torso_top + int(1.15 * b)
        belt_h = max(3, int(0.18 * b))
        belt_rect = pygame.Rect(cx - int(1.2 * b) + lean_offset, belt_y,
                                 int(2.4 * b), belt_h)
        pygame.draw.rect(screen, p["coat_purple"], belt_rect, border_radius=2)
        pygame.draw.rect(screen, p["coat_purple_light"], belt_rect, 1, border_radius=2)
        # 벨트 버클
        buckle_s = max(3, int(0.15 * b))
        buckle_rect = pygame.Rect(center_x - buckle_s, belt_y - 1, buckle_s * 2, belt_h + 2)
        pygame.draw.rect(screen, p["bell"], buckle_rect, border_radius=1)
        pygame.draw.rect(screen, p["bell_dark"], buckle_rect, 1, border_radius=1)

        # === 러플 칼라 (더 풍성하게) ===
        collar_y = torso_top
        for layer in range(2):
            ruffle_count = 9 - layer * 2
            ruffle_r = max(3, int((0.2 - layer * 0.04) * b))
            y_off = -layer * int(0.08 * b)
            col = p["collar"] if layer == 0 else p["collar_edge"]
            border_col = p["collar_shadow"]
            for i in range(ruffle_count):
                ruffle_angle = (i / (ruffle_count - 1)) * math.pi - math.pi / 2
                rx = cx + int(_cos(ruffle_angle) * (0.9 - layer * 0.15) * b) + lean_offset
                ry = collar_y + y_off + int(_sin(ruffle_angle) * 0.2 * b)
                ry += int(_sin(self.time * 2.5 + i * 0.8) * 0.04 * b)
                pygame.draw.circle(screen, col, (rx, ry), ruffle_r)
                pygame.draw.circle(screen, border_col, (rx, ry), ruffle_r, 1)

        # === 어깨 패드 (비대칭, 뾰족한 형태) ===
        for side in [-1, 1]:
            pad_color = p["coat_red"] if side == -1 else p["coat_gold"]
            pad_light = p["coat_red_light"] if side == -1 else p["coat_gold_light"]
            pad_dark = p["coat_red_dark"] if side == -1 else p["coat_gold_dark"]
            pad_x = cx + side * int(1.15 * b) + lean_offset
            pad_y = torso_top + int(0.1 * b) + int(shoulder_bob * 0.5 * b)
            pad_w = int(0.6 * b)
            pad_h = int(0.45 * b)

            # 뾰족한 어깨 패드
            pad_pts = [
                (pad_x - pad_w // 2, pad_y + pad_h // 2),
                (pad_x, pad_y - pad_h // 2),
                (pad_x + pad_w // 2, pad_y + pad_h // 2),
            ]
            pygame.draw.polygon(screen, pad_color, pad_pts)
            pygame.draw.polygon(screen, pad_dark, pad_pts, 1)
            # 하이라이트
            pygame.draw.line(screen, pad_light,
                           (pad_x - int(pad_w * 0.3), pad_y),
                           (pad_x, pad_y - pad_h // 2 + 2), max(1, int(0.08 * b)))

        # === 팔 (소매 디테일 + 커프스) ===
        _front_side = 1 if not show_back else -1  # 전방 손 (카드 들고있는 손)
        for side in [-1, 1]:
            arm_swing_val = left_arm_swing if side == -1 else right_arm_swing
            shoulder_x = cx + side * int(1.0 * b) + lean_offset
            shoulder_y_arm = torso_top + int(0.3 * b) + int(shoulder_bob * 0.5 * b)

            # 전방 팔(카드 손) 공 타격 시 바라보는 방향으로 펀치
            if side == _front_side and weapon_swing != 0:
                forward_dir = 1 if not show_back else -1  # 바라보는 방향 (아래=1, 위=-1)
                punch_fwd = int(abs(weapon_swing) * 4.0 * b)
                elbow_x = shoulder_x + side * int(0.4 * b)
                elbow_y = shoulder_y_arm + int(1.1 * b) + forward_dir * int(punch_fwd * 0.4)
                hand_x = elbow_x + side * int(0.15 * b)
                hand_y = elbow_y + int(0.3 * b) + forward_dir * int(punch_fwd * 0.7)
            else:
                elbow_x = shoulder_x + side * int(0.4 * b) + int(arm_swing_val * 0.3 * b * side)
                elbow_y = shoulder_y_arm + int(1.1 * b) + int(arm_swing_val * 0.3 * b)
                hand_x = elbow_x + side * int(0.25 * b) + int(arm_swing_val * 0.15 * b * side)
                hand_y = elbow_y + int(0.8 * b) + int(arm_swing_val * 0.2 * b)

            sleeve_color = p["coat_red"] if side == -1 else p["coat_gold"]
            sleeve_light = p["coat_red_light"] if side == -1 else p["coat_gold_light"]
            sleeve_dark = p["coat_red_dark"] if side == -1 else p["coat_gold_dark"]
            arm_thick = max(3, int(0.4 * b))

            # 상완
            pygame.draw.line(screen, sleeve_color,
                           (shoulder_x, shoulder_y_arm), (elbow_x, elbow_y), arm_thick)
            pygame.draw.line(screen, sleeve_light,
                           (shoulder_x - 1, shoulder_y_arm),
                           (elbow_x - 1, elbow_y), max(1, arm_thick // 3))

            # 팔꿈치 관절
            pygame.draw.circle(screen, sleeve_dark, (int(elbow_x), int(elbow_y)),
                             max(2, int(0.18 * b)))

            # 하완
            forearm_thick = max(2, int(0.35 * b))
            pygame.draw.line(screen, sleeve_color,
                           (elbow_x, elbow_y), (hand_x, hand_y), forearm_thick)

            # 커프스 (소매 끝 주름)
            cuff_y = hand_y - int(0.15 * b)
            for ci in range(3):
                cr = max(2, int(0.12 * b))
                cuff_angle = (ci / 2) * math.pi * 0.6 - math.pi * 0.3
                crx = int(hand_x) + int(_cos(cuff_angle) * 0.2 * b)
                cry = int(cuff_y) + int(_sin(cuff_angle) * 0.08 * b)
                pygame.draw.circle(screen, p["collar"], (crx, cry), cr)
                pygame.draw.circle(screen, p["collar_shadow"], (crx, cry), cr, 1)

            # 하얀 장갑
            hand_size = max(3, int(0.22 * b))
            pygame.draw.circle(screen, p["collar"], (int(hand_x), int(hand_y)), hand_size)
            pygame.draw.circle(screen, p["collar_shadow"],
                             (int(hand_x), int(hand_y)), hand_size, 1)

            # 카드 (전방 손)
            if side == _front_side:
                card_cx = int(hand_x) + side * int(0.2 * b)
                card_cy = int(hand_y) - int(0.15 * b)
                card_w = max(5, int(0.35 * b))
                card_h = max(7, int(0.5 * b))
                # 카드 그림자
                pygame.draw.rect(screen, (40, 40, 40),
                               (card_cx - card_w // 2 + 1, card_cy - card_h // 2 + 1,
                                card_w, card_h), border_radius=1)
                # 카드 본체
                card_rect = (card_cx - card_w // 2, card_cy - card_h // 2, card_w, card_h)
                pygame.draw.rect(screen, p["card_white"], card_rect, border_radius=1)
                pygame.draw.rect(screen, p["card_border"], card_rect, 1, border_radius=1)
                # 다이아몬드 문양
                d_s = max(2, card_w // 3)
                diamond_pts = [
                    (card_cx, card_cy - d_s),
                    (card_cx + d_s, card_cy),
                    (card_cx, card_cy + d_s),
                    (card_cx - d_s, card_cy),
                ]
                pygame.draw.polygon(screen, p["diamond_red"], diamond_pts)

                # === 카드 글로우 이펙트 ===
                card_glow_sz = max(int(card_w * 1.8), int(card_h * 1.8))
                card_glow_surf = self._get_surface(card_glow_sz * 2, card_glow_sz * 2)
                card_glow_pulse = 0.5 + 0.5 * _sin(self.time * 4.0)
                card_glow_alpha = int(35 * card_glow_pulse)
                # 빨강+금색 이중 글로우
                pygame.draw.circle(card_glow_surf,
                                 (255, 80, 60, card_glow_alpha),
                                 (card_glow_sz, card_glow_sz), card_glow_sz)
                pygame.draw.circle(card_glow_surf,
                                 (255, 220, 80, int(card_glow_alpha * 0.7)),
                                 (card_glow_sz, card_glow_sz), int(card_glow_sz * 0.6))
                screen.blit(card_glow_surf,
                           (card_cx - card_glow_sz, card_cy - card_glow_sz),
                           special_flags=pygame.BLEND_ADD)

        # === 목 ===
        neck_w = max(2, int(0.3 * b))
        pygame.draw.line(screen, p["skin"],
                        (cx + lean_offset, torso_top - int(0.05 * b)),
                        (cx + lean_offset, torso_top - int(0.6 * b)), neck_w)

        # === 머리 ===
        head_x = cx + lean_offset
        head_y = torso_top - int(1.35 * b)
        head_r = max(4, int(0.85 * b))

        if not show_back:
            # ── 정면 ──
            # 머리 그림자
            pygame.draw.circle(screen, p["skin_shadow"], (head_x + 1, head_y + 1), head_r)
            # 머리 본체
            pygame.draw.circle(screen, p["skin"], (head_x, head_y), head_r)

            # 눈 (더 표현력 풍부하게)
            eye_y = head_y - int(0.05 * b)
            for side in [-1, 1]:
                eye_x = head_x + side * int(0.28 * b)
                eye_w = max(4, int(0.2 * b))
                eye_h = max(3, int(0.16 * b))
                # 흰자
                pygame.draw.ellipse(screen, p["eye_white"],
                                  (eye_x - eye_w, eye_y - eye_h, eye_w * 2, eye_h * 2))
                pygame.draw.ellipse(screen, p["eye_iris"],
                                  (eye_x - eye_w, eye_y - eye_h, eye_w * 2, eye_h * 2), 1)
                # 홍채
                iris_r = max(2, int(0.1 * b))
                pygame.draw.circle(screen, p["eye_iris"], (eye_x, eye_y), iris_r)
                # 동공
                pupil_r = max(1, iris_r - 1)
                pygame.draw.circle(screen, p["eye_pupil"], (eye_x, eye_y), pupil_r)
                # 하이라이트 (큰 점 + 작은 점)
                pygame.draw.circle(screen, p["eye_glint"],
                                 (eye_x - max(1, int(0.06 * b)),
                                  eye_y - max(1, int(0.04 * b))),
                                 max(1, int(0.05 * b)))
                pygame.draw.circle(screen, p["eye_glint"],
                                 (eye_x + max(1, int(0.03 * b)),
                                  eye_y + max(1, int(0.03 * b))),
                                 max(1, int(0.025 * b)))

                # 속눈썹 (위쪽으로 삐죽)
                for lash in range(-1, 2):
                    lx = eye_x + lash * max(1, int(0.06 * b))
                    pygame.draw.line(screen, p["eye_iris"],
                                   (lx, eye_y - eye_h),
                                   (lx + lash, eye_y - eye_h - max(1, int(0.06 * b))), 1)

            # 빨간 코 (광택 개선)
            nose_y = head_y + int(0.12 * b)
            nose_r = max(3, int(0.15 * b))
            pygame.draw.circle(screen, p["nose_red"], (head_x, nose_y), nose_r)
            # 광택
            pygame.draw.circle(screen, p["nose_shine"],
                             (head_x - max(1, int(0.04 * b)),
                              nose_y - max(1, int(0.04 * b))),
                             max(1, nose_r // 2))
            # 코 테두리
            pygame.draw.circle(screen, (180, 40, 35), (head_x, nose_y), nose_r, 1)

            # 입 (큰 장난스러운 웃음)
            mouth_y = head_y + int(0.35 * b)
            mouth_w = int(0.55 * b)
            mouth_h = int(0.25 * b)
            # 입 배경
            pygame.draw.arc(screen, p["lip"],
                          (head_x - mouth_w // 2, mouth_y - mouth_h,
                           mouth_w, mouth_h * 2),
                          3.25, 6.15, max(2, int(0.07 * b)))
            # 입꼬리 올라감
            for side in [-1, 1]:
                mx = head_x + side * int(0.25 * b)
                pygame.draw.line(screen, p["lip"],
                               (mx, mouth_y + int(0.02 * b)),
                               (mx + side * int(0.05 * b), mouth_y - int(0.06 * b)), 1)

            # 초록 머리 (스파이키, 더 역동적)
            hair_sway = int(move_dir * side_blend * 0.2 * b)
            # 양쪽 머리카락 다발
            for side in [-1, 1]:
                for j in range(3):
                    base_x = head_x + side * int((0.35 + j * 0.12) * b)
                    base_y = head_y - int(0.4 * b)
                    tip_x = head_x + side * int((0.55 + j * 0.15) * b) + hair_sway
                    tip_y = head_y - int((0.15 - j * 0.12) * b)
                    mid_x = (base_x + tip_x) // 2 + side * int(0.08 * b)
                    mid_y = (base_y + tip_y) // 2 - int(0.1 * b)

                    hair_pts = [
                        (base_x - side * int(0.08 * b), base_y + int(0.1 * b)),
                        (mid_x - side * int(0.05 * b), mid_y),
                        (tip_x, tip_y + int(0.1 * b)),
                        (tip_x + side * int(0.04 * b), tip_y - int(0.05 * b)),
                        (mid_x + side * int(0.05 * b), mid_y - int(0.05 * b)),
                        (base_x + side * int(0.08 * b), base_y),
                    ]
                    col = p["hair"] if j != 1 else p["hair_tips"]
                    pygame.draw.polygon(screen, col, hair_pts)
                    pygame.draw.polygon(screen, p["hair_dark"], hair_pts, 1)

            # 위쪽 뾰족 머리
            for i in range(3):
                off_x = (i - 1) * int(0.2 * b)
                top_pts = [
                    (head_x + off_x - int(0.12 * b), head_y - int(0.55 * b)),
                    (head_x + off_x + hair_sway, head_y - int((1.0 + i * 0.15) * b)),
                    (head_x + off_x + int(0.12 * b), head_y - int(0.55 * b)),
                ]
                col = p["hair_light"] if i == 1 else p["hair"]
                pygame.draw.polygon(screen, col, top_pts)
                pygame.draw.polygon(screen, p["hair_dark"], top_pts, 1)

        else:
            # ── 뒷모습 ──
            pygame.draw.circle(screen, p["hair"], (head_x, head_y), head_r)
            pygame.draw.circle(screen, p["hair_dark"], (head_x, head_y), head_r, 1)

            hair_sway = int(move_dir * side_blend * 0.2 * b)
            # 뒷머리 결
            for i in range(6):
                sx = head_x + int((i - 2.5) * 0.2 * b)
                pygame.draw.line(screen, p["hair_dark"],
                               (sx, head_y - int(0.5 * b)),
                               (sx + int((i - 2.5) * 0.06 * b) + hair_sway,
                                head_y + int(0.45 * b)),
                               1)

            # 뒤쪽 뾰족 머리
            for i in range(3):
                off_x = (i - 1) * int(0.2 * b)
                top_pts = [
                    (head_x + off_x - int(0.12 * b), head_y - int(0.55 * b)),
                    (head_x + off_x + hair_sway, head_y - int((1.0 + i * 0.15) * b)),
                    (head_x + off_x + int(0.12 * b), head_y - int(0.55 * b)),
                ]
                col = p["hair_light"] if i == 1 else p["hair"]
                pygame.draw.polygon(screen, col, top_pts)
                pygame.draw.polygon(screen, p["hair_dark"], top_pts, 1)

            # 뒷목 피부
            pygame.draw.rect(screen, p["skin"],
                           (head_x - int(0.15 * b), head_y + int(0.4 * b),
                            int(0.3 * b), int(0.3 * b)))

        # === 제스터 모자 방울 (머리 양옆에서 늘어지는 방울) ===
        for side in [-1, 1]:
            # 끈
            string_start_x = head_x + side * int(0.5 * b)
            string_start_y = head_y - int(0.4 * b)
            # 방울 위치 (물리적 흔들림)
            bell_swing = _sin(self.time * 3.5 + side * 1.8) * 0.15 * b
            bell_move_swing = move_dir * side_blend * 0.25 * b  # 이동 관성
            bell_end_x = string_start_x + side * int(0.35 * b) + int(bell_swing) + int(bell_move_swing)
            bell_end_y = string_start_y + int(0.6 * b) + int(abs(_sin(self.time * 4 + side)) * 0.08 * b)

            # 곡선 끈
            mid_x = (string_start_x + bell_end_x) // 2
            mid_y = (string_start_y + bell_end_y) // 2 + int(0.1 * b)
            pygame.draw.line(screen, p["coat_purple"],
                           (string_start_x, string_start_y), (mid_x, mid_y), 1)
            pygame.draw.line(screen, p["coat_purple"],
                           (mid_x, mid_y), (bell_end_x, bell_end_y), 1)

            # 방울 (더 크고 빛나게)
            bell_r = max(3, int(0.13 * b))
            pygame.draw.circle(screen, p["bell"], (int(bell_end_x), int(bell_end_y)), bell_r)
            pygame.draw.circle(screen, p["bell_shine"],
                             (int(bell_end_x) - 1, int(bell_end_y) - 1),
                             max(1, bell_r // 2))
            pygame.draw.circle(screen, p["bell_dark"],
                             (int(bell_end_x), int(bell_end_y)), bell_r, 1)
            # 방울 슬릿
            pygame.draw.line(screen, p["bell_dark"],
                           (int(bell_end_x) - bell_r + 1, int(bell_end_y)),
                           (int(bell_end_x) + bell_r - 1, int(bell_end_y)), 1)


    # =========================================================================
    # 세트 - 사막의 환술사 (트릭키) [HD 버전]
    # =========================================================================
    def _draw_mirage(self, screen, cx, cy, b, color, show_back, anim):
        """세트 - 이집트 파라오 (네메스 왕관, 황금 장식, 왕홀) [HD 버전]"""
        # 다른 영웅 평균 체급에 맞추기 위한 스케일 업 (2.0b→2.4b 몸통 등)
        b = int(b * 1.2)
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        shoulder_bob = anim.get("shoulder_bob", 0)
        left_arm_swing = anim.get("left_arm_swing", 0)
        right_arm_swing = anim.get("right_arm_swing", 0)
        weapon_swing = anim.get("weapon_swing_angle", 0)
        # 이동 애니메이션 파라미터 (다리 걸음/로브 관성)
        left_leg_sway = anim.get("left_leg_sway", 0)
        right_leg_sway = anim.get("right_leg_sway", 0)
        left_leg_lift = anim.get("left_leg", 0)
        right_leg_lift = anim.get("right_leg", 0)
        side_blend = anim.get("side_blend", 0)
        move_dir = anim.get("move_dir", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2.5 * b)

        # 로브 관성 (이동 반대 방향으로 나풀거림 - 가벼운 린넨 천)
        robe_inertia = -move_dir * side_blend * 0.5 * b
        robe_sway = _sin(self.time * 3.2) * side_blend * 0.25 * b
        robe_drift = int(robe_inertia + robe_sway)
        robe_wave_boost = 1.0 + side_blend * 1.8

        t = self.time
        gold_pulse = (_sin(t * 2.5) + 1) * 0.5

        # 이집트 파라오 색상 팔레트
        p = {
            "gold": (220, 185, 55),
            "gold_light": (245, 220, 100),
            "gold_dark": (170, 140, 30),
            "gold_trim": (255, 230, 120),
            "nemes_blue": (30, 60, 140),
            "nemes_gold": (210, 180, 60),
            "nemes_dark": (20, 40, 100),
            "skin": (180, 140, 90),
            "skin_light": (200, 160, 110),
            "skin_shadow": (145, 108, 65),
            "robe_white": (235, 230, 215),
            "robe_shadow": (200, 195, 175),
            "robe_fold": (180, 175, 155),
            "collar_blue": (30, 55, 130),
            "collar_light": (60, 100, 200),
            "eye_line": (20, 20, 20),
            "eye_green": (30, 160, 100),
            "staff_gold": (230, 200, 80),
            "staff_gem": (40, 180, 160),
            "gem_glow": (80, 220, 200),
            "sandal": (160, 120, 60),
            "beard_gold": (200, 170, 45),
            "beard_stripe": (30, 55, 120),
        }

        # ─── 신비의 시길 (발밑 비스듬히 눕힌 소환진) ───
        sigil_cx = cx + lean_offset
        sigil_cy = cy + int(2.2 * b) + int(0.6 * b)
        sigil_rx = int(2.2 * b)            # X 반지름 (가로 넓게)
        sigil_ry = int(0.7 * b)            # Y 반지름 (원근 압축)
        sigil_w = sigil_rx * 2 + 4
        sigil_h = sigil_ry * 2 + 4
        sigil_surf = self._get_surface(sigil_w, sigil_h)
        s_cx, s_cy = sigil_w // 2, sigil_h // 2
        sigil_alpha = int(35 + 20 * gold_pulse)
        # 외곽 타원
        pygame.draw.ellipse(sigil_surf, (*p["gold_light"], sigil_alpha),
                          (s_cx - sigil_rx, s_cy - sigil_ry, sigil_rx * 2, sigil_ry * 2),
                          max(1, int(0.06 * b)))
        # 내곽 타원
        inner_rx = int(sigil_rx * 0.65)
        inner_ry = int(sigil_ry * 0.65)
        pygame.draw.ellipse(sigil_surf, (*p["gem_glow"], int(sigil_alpha * 0.7)),
                          (s_cx - inner_rx, s_cy - inner_ry, inner_rx * 2, inner_ry * 2),
                          max(1, int(0.04 * b)))
        # 삼각형 (회전, Y축 원근 압축)
        perspective = sigil_ry / max(1, sigil_rx)  # 압축 비율
        sigil_rot = t * 0.5
        for tri in range(2):
            tri_angle_off = sigil_rot + tri * (math.pi / 3)
            tri_pts_local = []
            for v in range(3):
                va = tri_angle_off + v * (2 * math.pi / 3)
                tri_pts_local.append((
                    s_cx + int(_cos(va) * inner_rx * 0.9),
                    s_cy + int(_sin(va) * inner_ry * 0.9)
                ))
            tri_col = (*p["gold"], int(sigil_alpha * 0.6)) if tri == 0 else (*p["staff_gem"], int(sigil_alpha * 0.5))
            pygame.draw.polygon(sigil_surf, tri_col, tri_pts_local, max(1, int(0.04 * b)))
        screen.blit(sigil_surf, (sigil_cx - s_cx, sigil_cy - s_cy),
                    special_flags=pygame.BLEND_ADD)

        # ─── 모래 파티클 (뒤쪽 - 강화) ───
        for i in range(8):
            phase = t * 1.0 + i * 0.8
            orbit_r = (2.5 + i * 0.4) * b
            px = cx + int(_sin(phase) * orbit_r * 0.7) + lean_offset
            py = torso_y + int(_cos(phase * 0.7 + i * 0.5) * orbit_r * 0.4)
            life = (t * 0.8 + i * 0.3) % 2.0
            sa = int((50 + 25 * _sin(phase * 2)) * max(0, 1.0 - life * 0.5))
            sr = max(1, int((0.25 + life * 0.1) * b))
            if sa > 5:
                ps_surf = self._get_surface(sr * 2, sr * 2)
                sand_c = (220, 195, 120) if i % 3 != 0 else (245, 220, 140)
                pygame.draw.circle(ps_surf, (*sand_c, sa), (sr, sr), sr)
                screen.blit(ps_surf, (px - sr, py - sr))

        # ─── 다리 / 샌들 ───
        leg_base_y = cy + int(2.2 * b)
        for side in [-1, 1]:
            # 걸음 애니메이션 (좌우 스윙 + 들어올림)
            cur_sway = left_leg_sway if side == -1 else right_leg_sway
            cur_lift = left_leg_lift if side == -1 else right_leg_lift
            leg_sway_x = int(cur_sway * 0.5 * b)
            leg_lift_y = int(cur_lift * 0.25 * b)

            leg_x = cx + side * int(0.4 * b) + lean_offset + leg_sway_x
            # 허벅지 (로브 아래 살짝 보임)
            knee_x = leg_x + int(cur_sway * 0.2 * b)
            knee_y = leg_base_y + int(0.1 * b) - leg_lift_y
            pygame.draw.line(screen, p["robe_shadow"],
                           (leg_x, leg_base_y - int(1.0 * b)),
                           (knee_x, knee_y),
                           max(2, int(0.3 * b)))
            # 정강이
            foot_x = knee_x + leg_sway_x
            foot_y = leg_base_y + int(0.5 * b) - int(leg_lift_y * 0.5)
            pygame.draw.line(screen, p["skin_shadow"],
                           (knee_x, knee_y),
                           (foot_x, foot_y),
                           max(2, int(0.25 * b)))
            # 무릎 관절
            pygame.draw.circle(screen, p["skin"], (knee_x, knee_y), max(2, int(0.12 * b)))
            # 샌들
            foot_w = max(3, int(0.5 * b))
            foot_h = max(2, int(0.2 * b))
            pygame.draw.ellipse(screen, p["sandal"],
                              (foot_x - foot_w // 2, foot_y,
                               foot_w, foot_h))
            # 샌들 끈
            pygame.draw.line(screen, p["gold_dark"],
                           (foot_x, foot_y - int(0.15 * b)),
                           (foot_x, foot_y + int(0.1 * b)),
                           max(1, int(0.06 * b)))

        # ─── 로브 (쉔디트 - 파라오 치마) ───
        skirt_top = torso_y + int(1.2 * b)
        skirt_bot = leg_base_y - int(0.5 * b)
        skirt_w_top = int(1.8 * b)
        skirt_w_bot = int(2.4 * b)
        robe_wave = int(wave * 0.2 * robe_wave_boost * b)
        skirt_pts = [
            (cx - skirt_w_top // 2 + lean_offset, skirt_top),
            (cx + skirt_w_top // 2 + lean_offset, skirt_top),
            (cx + skirt_w_bot // 2 + lean_offset + robe_wave + robe_drift, skirt_bot),
            (cx - skirt_w_bot // 2 + lean_offset - robe_wave + robe_drift, skirt_bot),
        ]
        pygame.draw.polygon(screen, p["robe_white"], skirt_pts)
        # 그림자 (로브 좌우 - 이동 방향에 따라 변화)
        shadow_inset = int(0.15 * b)
        # 이동 방향 반대쪽에 더 넓은 그림자
        shadow_side = 1 if move_dir >= 0 else -1
        shadow_pts_l = [
            (cx - skirt_w_top // 2 + lean_offset + shadow_inset, skirt_top),
            (cx - skirt_w_top // 2 + lean_offset, skirt_top),
            (cx - skirt_w_bot // 2 + lean_offset - robe_wave + robe_drift, skirt_bot),
            (cx - skirt_w_bot // 2 + lean_offset - robe_wave + robe_drift + shadow_inset + int(0.1 * b), skirt_bot),
        ]
        pygame.draw.polygon(screen, p["robe_shadow"], shadow_pts_l)
        # 중앙 주름선 (이동 시 살짝 기울어짐)
        fold_drift = int(robe_drift * 0.3)
        pygame.draw.line(screen, p["robe_fold"],
                        (cx + lean_offset, skirt_top + int(0.2 * b)),
                        (cx + lean_offset + fold_drift, skirt_bot - int(0.1 * b)),
                        max(1, int(0.08 * b)))
        # 좌우 주름선 (이동 시 관성으로 흔들림)
        for side in [-1, 1]:
            fold_x = cx + side * int(0.5 * b) + lean_offset
            fold_wave = int(wave * 0.12 * robe_wave_boost * b * side) + int(robe_drift * 0.4)
            pygame.draw.line(screen, p["robe_fold"],
                           (fold_x, skirt_top + int(0.4 * b)),
                           (fold_x + fold_wave, skirt_bot - int(0.2 * b)),
                           max(1, int(0.06 * b)))
        # 로브 하단 금색 테두리 (관성 반영)
        hem_h = max(2, int(0.15 * b))
        pygame.draw.line(screen, p["gold_dark"],
                        (cx - skirt_w_bot // 2 + lean_offset - robe_wave + robe_drift, skirt_bot - hem_h),
                        (cx + skirt_w_bot // 2 + lean_offset + robe_wave + robe_drift, skirt_bot - hem_h),
                        hem_h)
        # 금색 허리띠
        belt_y = skirt_top
        belt_h = max(2, int(0.35 * b))
        belt_w = skirt_w_top + int(0.5 * b)
        pygame.draw.rect(screen, p["gold"],
                        (cx - belt_w // 2 + lean_offset, belt_y, belt_w, belt_h),
                        border_radius=max(1, int(0.1 * b)))
        pygame.draw.rect(screen, p["gold_light"],
                        (cx - belt_w // 2 + lean_offset, belt_y, belt_w, max(1, belt_h // 2)),
                        border_radius=max(1, int(0.1 * b)))
        # 허리 중앙 보석
        gem_belt_r = max(1, int(0.12 * b))
        pygame.draw.circle(screen, p["collar_blue"],
                         (cx + lean_offset, belt_y + belt_h // 2), gem_belt_r)

        # ─── 몸통 (상체) ───
        torso_top = torso_y - int(0.5 * b)
        torso_bot = skirt_top + int(0.1 * b)
        torso_w = int(2.0 * b)
        torso_rect = pygame.Rect(cx - torso_w // 2 + lean_offset, torso_top,
                                  torso_w, torso_bot - torso_top)
        pygame.draw.rect(screen, p["skin"], torso_rect,
                        border_radius=max(1, int(0.2 * b)))
        hl_rect = pygame.Rect(torso_rect.x + int(0.1 * b), torso_rect.y + int(0.1 * b),
                               torso_w // 3, torso_rect.height - int(0.2 * b))
        pygame.draw.rect(screen, p["skin_light"], hl_rect,
                        border_radius=max(1, int(0.1 * b)))

        # ─── 칼라 / 펙토랄 (넓은 목걸이) ───
        collar_cx = cx + lean_offset
        collar_cy = torso_top + int(0.3 * b) + int(shoulder_bob * 0.15 * b)
        collar_w = int(2.2 * b)
        collar_h = int(0.9 * b)
        collar_pts = [
            (collar_cx - collar_w // 2, collar_cy - int(0.1 * b)),
            (collar_cx + collar_w // 2, collar_cy - int(0.1 * b)),
            (collar_cx + int(collar_w * 0.35), collar_cy + collar_h),
            (collar_cx, collar_cy + collar_h + int(0.2 * b)),
            (collar_cx - int(collar_w * 0.35), collar_cy + collar_h),
        ]
        pygame.draw.polygon(screen, p["gold"], collar_pts)
        # 칼라 줄무늬
        for i_s in range(3):
            sy = collar_cy + int(i_s * 0.25 * b)
            hw = int(collar_w * 0.45 * (1 - i_s * 0.15))
            s_col = p["nemes_blue"] if i_s % 2 == 0 else p["gold_light"]
            pygame.draw.line(screen, s_col,
                           (collar_cx - hw, sy), (collar_cx + hw, sy),
                           max(1, int(0.1 * b)))
        # 중앙 보석
        c_gem_r = max(2, int(0.15 * b))
        pygame.draw.circle(screen, p["collar_blue"],
                         (collar_cx, collar_cy + int(0.3 * b)), c_gem_r)
        pygame.draw.circle(screen, p["collar_light"],
                         (collar_cx - 1, collar_cy + int(0.3 * b) - 1),
                         max(1, c_gem_r // 2))

        # ─── 어깨 ───
        shoulder_y = torso_top + int(0.2 * b) + int(shoulder_bob * 0.2 * b)
        for side in [-1, 1]:
            sx = cx + side * int(1.0 * b) + lean_offset
            sy = shoulder_y
            pad_r = max(2, int(0.35 * b))
            pygame.draw.circle(screen, p["gold_dark"], (sx, sy), pad_r)
            pygame.draw.circle(screen, p["gold"], (sx, sy), pad_r - 1)

        # ─── 팔 ───
        arm_thick = max(2, int(0.22 * b))
        for side in [-1, 1]:
            s_x = cx + side * int(1.0 * b) + lean_offset
            s_y = shoulder_y + int(0.2 * b)
            arm_swing = left_arm_swing if side == -1 else right_arm_swing
            e_x = s_x + side * int(0.5 * b) + int(arm_swing * 0.5 * b)
            e_y = s_y + int(1.2 * b)
            h_x = e_x + side * int(0.2 * b) + int(wave * 0.15 * b)
            h_y = e_y + int(0.8 * b)
            if side == -1 and not show_back:
                h_y = e_y + int(0.3 * b)
            # 무기 스윙 시 팔 모션 (스태프 들고있는 팔)
            is_staff_arm = (side == -1 and not show_back) or (side == 1 and show_back)
            if is_staff_arm and weapon_swing != 0:
                ws_x = int(weapon_swing * 4.0 * b * side)
                ws_y = int(abs(weapon_swing) * 2.0 * b)
                e_x += ws_x
                e_y -= ws_y
                h_x += int(ws_x * 0.7)
                h_y -= int(ws_y * 0.5)
            # 팔
            pygame.draw.line(screen, p["skin"], (s_x, s_y), (e_x, e_y), arm_thick + 1)
            pygame.draw.line(screen, p["skin_light"], (s_x, s_y), (e_x, e_y), arm_thick)
            pygame.draw.line(screen, p["skin"], (e_x, e_y), (h_x, h_y), arm_thick)
            # 금 팔찌
            br_r = max(2, int(0.15 * b))
            pygame.draw.circle(screen, p["gold"], (e_x, e_y), br_r)
            # 손
            hand_r = max(2, int(0.18 * b))
            pygame.draw.circle(screen, p["skin"], (h_x, h_y), hand_r)

            # 왕홀 (앙크) - 정면:왼손, 후면:오른손 + 스윙 회전 모션
            if (side == -1 and not show_back) or (side == 1 and show_back):
                staff_bx = h_x
                staff_by = h_y
                raw_end_x = h_x
                raw_end_y = torso_y - int(2.5 * b)
                # 스윙 회전 (정면/후면 방향 보정)
                swing_dir = -1 if show_back else 1
                staff_angle = weapon_swing * 1.8 * swing_dir
                if staff_angle != 0:
                    _rot = self._rotate_point(raw_end_x, raw_end_y, staff_bx, staff_by, staff_angle)
                    staff_tx, staff_ty = int(_rot[0]), int(_rot[1])
                else:
                    staff_tx, staff_ty = raw_end_x, raw_end_y

                # 스윙 잔상 (황금빛 호 궤적)
                if abs(weapon_swing) > 0.15:
                    trail_pts = []
                    t_steps = 5
                    for ti in range(t_steps + 1):
                        t_frac = ti / float(t_steps)
                        t_ang = staff_angle * t_frac
                        if t_ang != 0:
                            _tr = self._rotate_point(raw_end_x, raw_end_y, staff_bx, staff_by, t_ang)
                            trail_pts.append((int(_tr[0]), int(_tr[1])))
                        else:
                            trail_pts.append((raw_end_x, raw_end_y))
                    # 바운딩 박스 계산
                    t_all_x = [tp[0] for tp in trail_pts] + [staff_bx]
                    t_all_y = [tp[1] for tp in trail_pts] + [staff_by]
                    t_pad = int(0.5 * b)
                    t_mn_x, t_mn_y = min(t_all_x) - t_pad, min(t_all_y) - t_pad
                    t_mx_x, t_mx_y = max(t_all_x) + t_pad, max(t_all_y) + t_pad
                    tw = max(4, t_mx_x - t_mn_x)
                    th = max(4, t_mx_y - t_mn_y)
                    t_surf = self._get_surface(tw, th)
                    for ti in range(len(trail_pts) - 1):
                        f_alpha = int(abs(weapon_swing) * 100 * ((ti + 1) / len(trail_pts)))
                        lp1 = (trail_pts[ti][0] - t_mn_x, trail_pts[ti][1] - t_mn_y)
                        lp2 = (trail_pts[ti + 1][0] - t_mn_x, trail_pts[ti + 1][1] - t_mn_y)
                        pygame.draw.line(t_surf, (*p["gold_light"], f_alpha),
                                       lp1, lp2, max(2, int(0.15 * b)))
                    screen.blit(t_surf, (t_mn_x, t_mn_y))

                # 왕홀 몸체
                pygame.draw.line(screen, p["gold_dark"],
                               (staff_bx, staff_by), (staff_tx, staff_ty),
                               max(2, int(0.12 * b)))
                pygame.draw.line(screen, p["staff_gold"],
                               (staff_bx - 1, staff_by), (staff_tx - 1, staff_ty),
                               max(1, int(0.07 * b)))
                # 앙크 상단 (원)
                ankh_x, ankh_y = staff_tx, staff_ty
                ankh_r = max(2, int(0.18 * b))
                pygame.draw.circle(screen, p["staff_gold"],
                                 (ankh_x, ankh_y - ankh_r), ankh_r,
                                 max(1, int(0.06 * b)))
                # 앙크 세로선
                pygame.draw.line(screen, p["staff_gold"],
                               (ankh_x, ankh_y),
                               (ankh_x, ankh_y + int(0.5 * b)),
                               max(1, int(0.08 * b)))
                # 앙크 가로선
                hw = int(0.2 * b)
                pygame.draw.line(screen, p["staff_gold"],
                               (ankh_x - hw, ankh_y + int(0.1 * b)),
                               (ankh_x + hw, ankh_y + int(0.1 * b)),
                               max(1, int(0.08 * b)))
                # 보석
                gem_r = max(2, int(0.1 * b))
                pygame.draw.circle(screen, p["staff_gem"],
                                 (ankh_x, ankh_y - ankh_r), gem_r)
                gr = gem_r + max(2, int(0.15 * b * gold_pulse))
                gs = self._get_surface(gr * 4, gr * 4)
                ga = int(30 + 20 * gold_pulse)
                pygame.draw.circle(gs, (*p["gem_glow"], ga), (gr * 2, gr * 2), gr)
                screen.blit(gs, (ankh_x - gr * 2, ankh_y - ankh_r - gr * 2),
                           special_flags=pygame.BLEND_ADD)
                # 스윙 시 모래/금가루 파티클 버스트
                if abs(weapon_swing) > 0.3:
                    burst_n = int(abs(weapon_swing) * 6)
                    for bi in range(burst_n):
                        bp = self.time * 8.0 + bi * 2.1 + weapon_swing * 10
                        bx = staff_tx + int(_sin(bp) * 1.5 * b)
                        by = staff_ty + int(_cos(bp * 0.7) * 1.0 * b)
                        ba = int(abs(weapon_swing) * 150 * max(0, _sin(bp * 1.5)))
                        br = max(1, int(0.15 * b))
                        if ba > 10:
                            bs = self._get_surface(br * 2, br * 2)
                            pygame.draw.circle(bs, (*p["gold_light"], ba), (br, br), br)
                            screen.blit(bs, (bx - br, by - br))

        # ─── 머리 ───
        head_x = cx + lean_offset
        head_y = torso_y - int(1.5 * b)
        head_r = int(0.8 * b)

        # 네메스 천 관성 (이동 반대방향으로 나풀거림)
        nemes_drift = int(-move_dir * side_blend * 0.3 * b)
        nemes_sway = int(_sin(self.time * 2.5) * side_blend * 0.15 * b)
        nemes_flap = nemes_drift + nemes_sway

        if not show_back:
            # ═══ 정면 ═══
            # 네메스 좌우 늘어뜨린 천 (이동 시 나풀거림)
            for side in [-1, 1]:
                flap_drift = nemes_flap * (1 if side == int(move_dir) else 0.5)
                flap_pts = [
                    (head_x + side * int(0.7 * b), head_y - int(0.1 * b)),
                    (head_x + side * int(1.0 * b) + int(flap_drift * 0.3), head_y + int(1.2 * b)),
                    (head_x + side * int(0.6 * b) + int(flap_drift),
                     head_y + int(1.5 * b) + int(wave * 0.12 * robe_wave_boost * b)),
                    (head_x + side * int(0.3 * b), head_y + int(0.8 * b)),
                ]
                pygame.draw.polygon(screen, p["nemes_gold"], flap_pts)
                for j in range(3):
                    sy = head_y + int(0.2 * b) + int(j * 0.35 * b)
                    x1 = head_x + side * int(0.35 * b + j * 0.08 * b)
                    x2 = head_x + side * int(0.75 * b + j * 0.06 * b)
                    pygame.draw.line(screen, p["nemes_blue"],
                                   (x1, sy), (x2, sy),
                                   max(1, int(0.07 * b)))

            # 얼굴
            pygame.draw.circle(screen, p["skin"], (head_x, head_y), head_r)
            pygame.draw.circle(screen, p["skin_light"],
                             (head_x - int(0.1 * b), head_y - int(0.1 * b)),
                             head_r - max(1, int(0.15 * b)))
            # 네메스 상단
            nemes_pts = [
                (head_x - int(0.85 * b), head_y - int(0.15 * b)),
                (head_x + int(0.85 * b), head_y - int(0.15 * b)),
                (head_x + int(0.7 * b), head_y - int(0.7 * b)),
                (head_x, head_y - int(0.95 * b)),
                (head_x - int(0.7 * b), head_y - int(0.7 * b)),
            ]
            pygame.draw.polygon(screen, p["nemes_gold"], nemes_pts)
            for j in range(2):
                ny = head_y - int(0.55 * b) + int(j * 0.25 * b)
                nw = int(0.6 * b - j * 0.1 * b)
                pygame.draw.line(screen, p["nemes_blue"],
                               (head_x - nw, ny), (head_x + nw, ny),
                               max(1, int(0.07 * b)))
            # 이마 금 밴드
            band_y = head_y - int(0.25 * b)
            band_w = int(0.82 * b)
            pygame.draw.line(screen, p["gold"],
                           (head_x - band_w, band_y),
                           (head_x + band_w, band_y),
                           max(2, int(0.12 * b)))
            # 우라에우스 (코브라)
            cobra_y = band_y - int(0.15 * b)
            cobra_pts = [
                (head_x, cobra_y - int(0.25 * b)),
                (head_x - int(0.1 * b), cobra_y),
                (head_x + int(0.1 * b), cobra_y),
            ]
            pygame.draw.polygon(screen, p["gold_light"], cobra_pts)
            pygame.draw.circle(screen, (200, 50, 50),
                             (head_x, cobra_y - int(0.12 * b)),
                             max(1, int(0.04 * b)))

            # ─── 호루스의 눈 ───
            eye_y = head_y + int(0.1 * b)
            for side in [-1, 1]:
                ex = head_x + side * int(0.3 * b)
                eye_w = max(2, int(0.22 * b))
                eye_h = max(1, int(0.12 * b))
                pygame.draw.ellipse(screen, (235, 230, 215),
                                  (ex - eye_w, eye_y - eye_h,
                                   eye_w * 2, eye_h * 2))
                iris_r = max(1, int(0.09 * b))
                pygame.draw.circle(screen, p["eye_green"], (ex, eye_y), iris_r)
                pygame.draw.circle(screen, (15, 15, 15),
                                 (ex, eye_y), max(1, iris_r // 2))
                pygame.draw.circle(screen, (200, 255, 230),
                                 (ex + max(1, int(0.03 * b)),
                                  eye_y - max(1, int(0.03 * b))),
                                 max(1, int(0.04 * b)))
                # 아이라인 상단
                pygame.draw.line(screen, p["eye_line"],
                               (ex - eye_w - int(0.05 * b), eye_y - int(0.02 * b)),
                               (ex + eye_w + int(0.05 * b), eye_y - int(0.02 * b)),
                               max(1, int(0.06 * b)))
                # 호루스 꼬리
                tail_x = ex + side * int(0.25 * b)
                tail_y = eye_y + int(0.2 * b)
                pygame.draw.line(screen, p["eye_line"],
                               (ex + side * eye_w, eye_y + int(0.05 * b)),
                               (tail_x, tail_y),
                               max(1, int(0.05 * b)))
                pygame.draw.line(screen, p["eye_line"],
                               (tail_x, tail_y),
                               (tail_x, tail_y + int(0.12 * b)),
                               max(1, int(0.04 * b)))

                # ─── 눈 강화 글로우 (황금빛 호루스 발광) ───
                for glow_i in range(3):
                    eg_r = int((0.35 - glow_i * 0.08) * b)
                    eg_alpha = int((35 - glow_i * 10) * (0.6 + gold_pulse * 0.4))
                    eg_surf = self._get_surface(eg_r * 2, eg_r * 2)
                    pygame.draw.circle(eg_surf, (*p["eye_green"], eg_alpha), (eg_r, eg_r), eg_r)
                    screen.blit(eg_surf, (ex - eg_r, eye_y - eg_r), special_flags=pygame.BLEND_ADD)

            # 입
            mouth_y = head_y + int(0.35 * b)
            pygame.draw.line(screen, p["skin_shadow"],
                           (head_x - int(0.15 * b), mouth_y),
                           (head_x + int(0.15 * b), mouth_y), 1)

            # ─── 파라오 턱수염 (이동 시 살짝 흔들림) ───
            beard_top_y = head_y + int(0.5 * b)
            beard_bot_y = beard_top_y + int(0.7 * b)
            beard_w = max(2, int(0.12 * b))
            beard_sway = int(nemes_flap * 0.4)
            pygame.draw.line(screen, p["beard_gold"],
                           (head_x, beard_top_y),
                           (head_x + beard_sway, beard_bot_y), beard_w)
            for j in range(2):
                by = beard_top_y + int((j + 1) * 0.2 * b)
                pygame.draw.line(screen, p["beard_stripe"],
                               (head_x - 1, by), (head_x + 1, by), 1)
            pygame.draw.circle(screen, p["gold_light"],
                             (head_x, beard_bot_y), max(1, int(0.06 * b)))
        else:
            # ═══ 후면 ═══
            # 네메스 뒷면 전체 (이동 시 나풀거림)
            nemes_back_pts = [
                (head_x - int(0.85 * b), head_y - int(0.15 * b)),
                (head_x + int(0.85 * b), head_y - int(0.15 * b)),
                (head_x + int(0.7 * b) + nemes_flap,
                 head_y + int(1.5 * b) + int(wave * 0.1 * robe_wave_boost * b)),
                (head_x - int(0.7 * b) + nemes_flap,
                 head_y + int(1.5 * b) - int(wave * 0.1 * robe_wave_boost * b)),
            ]
            pygame.draw.polygon(screen, p["nemes_gold"], nemes_back_pts)
            for j in range(5):
                sy = head_y + int(j * 0.3 * b)
                w_r = 1.0 - j * 0.05
                hw = int(0.7 * b * w_r)
                pygame.draw.line(screen, p["nemes_blue"],
                               (head_x - hw, sy), (head_x + hw, sy),
                               max(1, int(0.07 * b)))
            # 머리
            pygame.draw.circle(screen, p["nemes_gold"],
                             (head_x, head_y), head_r)
            # 네메스 상단
            nemes_pts = [
                (head_x - int(0.85 * b), head_y - int(0.15 * b)),
                (head_x + int(0.85 * b), head_y - int(0.15 * b)),
                (head_x + int(0.7 * b), head_y - int(0.7 * b)),
                (head_x, head_y - int(0.95 * b)),
                (head_x - int(0.7 * b), head_y - int(0.7 * b)),
            ]
            pygame.draw.polygon(screen, p["nemes_gold"], nemes_pts)
            for j in range(2):
                ny = head_y - int(0.55 * b) + int(j * 0.25 * b)
                nw = int(0.6 * b - j * 0.1 * b)
                pygame.draw.line(screen, p["nemes_blue"],
                               (head_x - nw, ny), (head_x + nw, ny),
                               max(1, int(0.07 * b)))
            # 이마 밴드
            band_y = head_y - int(0.25 * b)
            band_w = int(0.82 * b)
            pygame.draw.line(screen, p["gold"],
                           (head_x - band_w, band_y),
                           (head_x + band_w, band_y),
                           max(2, int(0.12 * b)))
            # 중앙 세로선
            pygame.draw.line(screen, p["nemes_dark"],
                           (head_x, head_y - int(0.2 * b)),
                           (head_x, head_y + int(1.3 * b)),
                           max(1, int(0.05 * b)))

        # ─── 목 ───
        neck_w = max(2, int(0.25 * b))
        pygame.draw.line(screen, p["skin"],
                        (head_x, head_y + head_r - int(0.1 * b)),
                        (head_x, torso_top + int(0.2 * b)), neck_w)

        # ─── 모래 파티클 (앞쪽) ───
        for i in range(2):
            phase2 = t * 1.5 + i * 2.5 + 5
            fx = cx + int(_sin(phase2) * 4 * b) + lean_offset
            fy = torso_y - int(1 * b) + int(_sin(phase2 * 0.6) * 3 * b)
            fa = int(35 + 15 * _sin(phase2 * 1.8))
            fr = max(1, int(0.35 * b))
            fsf = self._get_surface(fr * 2, fr * 2)
            pygame.draw.circle(fsf, (210, 185, 110, fa), (fr, fr), fr)
            screen.blit(fsf, (fx - fr, fy - fr))

        # ─── 발밑 모래 먼지 (이동 시에만) ───
        if side_blend > 0.15:
            dust_count = int(2 + side_blend * 3)
            for i in range(dust_count):
                dp = t * 2.5 + i * 1.3
                # 이동 반대 방향으로 먼지 뿌려짐
                dx = cx + lean_offset + int(-move_dir * (1 + i * 0.8) * b) + int(_sin(dp) * 0.5 * b)
                dy = leg_base_y + int(0.5 * b) + int(_sin(dp * 0.8) * 0.3 * b)
                da = int(30 * side_blend * max(0, _sin(dp * 1.2)))
                dr = max(1, int((0.3 + i * 0.08) * b))
                if da > 5:
                    ds = self._get_surface(dr * 2, dr * 2)
                    pygame.draw.circle(ds, (200, 175, 120, da), (dr, dr), dr)
                    screen.blit(ds, (dx - dr, dy - dr))


    # =========================================================================
    # 호루스 - 천둥의 매 (독수리 가면, 깃털 망토, 번개 낫) [고퀄리티]
    # =========================================================================
    def _draw_ra(self, screen, cx, cy, b, color, show_back, anim):
        """호루스 - 천둥의 매 (독수리/매 가면, 깃털 장식, 번개 낫) [HD 버전]"""
        b = int(b * 1.2)
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        shoulder_bob = anim.get("shoulder_bob", 0)
        left_arm_swing = anim.get("left_arm_swing", 0)
        right_arm_swing = anim.get("right_arm_swing", 0)
        weapon_swing = anim.get("weapon_swing_angle", 0)
        left_leg_sway = anim.get("left_leg_sway", 0)
        right_leg_sway = anim.get("right_leg_sway", 0)
        left_leg_lift = anim.get("left_leg", 0)
        right_leg_lift = anim.get("right_leg", 0)
        side_blend = anim.get("side_blend", 0)
        move_dir = anim.get("move_dir", 0)

        # 부양 효과 (느린 사인파로 위아래 천천히 떠다님)
        hover_offset = int(_sin(self.time * 1.8) * 0.4 * b)
        torso_y = cy - int(1.5 * b) + hover_offset
        lean_offset = int(lean * 2.5 * b)

        # 날개 관성 + 펄럭임
        wing_inertia = -move_dir * side_blend * 0.5 * b
        wing_sway = _sin(self.time * 2.2) * side_blend * 0.2 * b
        cape_drift = int(wing_inertia + wing_sway)
        cape_wave_boost = 1.0 + side_blend * 1.2
        # 날개용 side_blend 스무딩 (데드존 + 부드러운 전환)
        # side_blend < 0.25 구간은 0 취급 → 미세 이동 시 떨림 방지
        wing_blend_raw = max(0.0, (side_blend - 0.25) / 0.75) if side_blend > 0.25 else 0.0
        # hero_states에 부드러운 날개 블렌드 저장/보간
        state = self._get_state("ra")
        prev_wing_blend = state.get("wing_blend_smooth", 0.0)
        wing_blend = prev_wing_blend * 0.92 + wing_blend_raw * 0.08  # 매우 부드러운 보간
        state["wing_blend_smooth"] = wing_blend
        # 날개 펄럭임 (정지: 아주 느린 호흡, 이동: 활공 +20%)
        # 고정 주파수 사인파 (속도에 따라 주파수가 변하지 않음 → 떨림 방지)
        idle_flap = _sin(self.time * 2.5) * 0.138    # 정지 호흡 (+15%)
        move_flap = _sin(self.time * 6.0) * 0.54     # 이동 날갯짓 (+15%)
        wing_flap = idle_flap * (1.0 - wing_blend) + move_flap * wing_blend
        # 날개 2차 모션 (끝부분 지연 - 같은 블렌드 방식)
        idle_flap2 = _sin(self.time * 2.0 - 0.6) * 0.08
        move_flap2 = _sin(self.time * 4.8 - 0.6) * 0.322
        wing_flap2 = idle_flap2 * (1.0 - wing_blend) + move_flap2 * wing_blend

        t = self.time
        sun_pulse = (_sin(t * 3.0) + 1) * 0.5

        # 라 색상 팔레트 (태양의 매)
        p = {
            "gold": (230, 195, 55),
            "gold_light": (255, 230, 100),
            "gold_dark": (175, 145, 30),
            "gold_trim": (255, 235, 130),
            "sun_orange": (255, 160, 40),
            "sun_red": (230, 80, 30),
            "sun_glow": (255, 200, 80),
            "sun_core": (255, 255, 180),
            "feather_brown": (120, 75, 35),
            "feather_light": (170, 120, 60),
            "feather_dark": (80, 50, 20),
            "feather_tip": (200, 155, 75),
            "feather_white": (235, 225, 200),
            "beak_orange": (230, 150, 30),
            "beak_dark": (180, 110, 20),
            "eye_red": (200, 40, 30),
            "eye_gold": (255, 200, 50),
            "eye_pupil": (15, 10, 5),
            "mask_blue": (35, 65, 145),
            "mask_stripe": (25, 45, 110),
            "skin_bronze": (165, 120, 70),
            "skin_light": (190, 145, 95),
            "skin_shadow": (130, 90, 50),
            "loincloth_white": (240, 235, 220),
            "loincloth_shadow": (210, 205, 185),
            "loincloth_fold": (190, 185, 165),
            "sandal": (155, 115, 55),
            "anklet_gold": (215, 185, 60),
            "scythe_shaft": (90, 60, 30),
            "scythe_shaft_light": (120, 85, 45),
            "scythe_blade": (180, 190, 200),
            "scythe_blade_edge": (220, 230, 240),
            "scythe_blade_dark": (100, 110, 130),
            "scythe_glow": (255, 200, 80),
        }

        # ─── 태양 파티클 (뒤쪽 - 불씨 같은 작은 빛 입자들) ───
        for i in range(5):
            phase = t * 1.2 + i * 1.25
            px = cx + int(_sin(phase) * 4.5 * b) + lean_offset
            py = torso_y + int(_sin(phase * 0.8 + i) * 3.5 * b) - int(1.0 * b)
            sa = int(35 + 25 * _sin(phase * 2.2))
            sr = max(1, int(0.35 * b))
            ps_surf = self._get_surface(sr * 2, sr * 2)
            glow_col = (255, int(180 + 40 * _sin(phase)), int(50 + 30 * _sin(phase * 1.5)), sa)
            pygame.draw.circle(ps_surf, glow_col, (sr, sr), sr)
            screen.blit(ps_surf, (px - sr, py - sr))

        # ─── 독수리 날개 (등 뒤, 양쪽 - 3관절 다층 구조) ───
        wing_origin_x = cx + lean_offset
        wing_origin_y = torso_y - int(0.2 * b)
        # 1차 플랩 (어깨~중간)
        w_flap1 = int(wing_flap * 1.5 * b)
        # 2차 플랩 (중간~끝, 지연)
        w_flap2 = int(wing_flap2 * 2.0 * b)

        for side in [-1, 1]:
            # ── 관절 좌표 (어깨 → 팔꿈치 → 손목 → 끝) ──
            w_sh_x = wing_origin_x + side * int(0.8 * b)
            w_sh_y = wing_origin_y
            w_elb_x = wing_origin_x + side * int(2.0 * b)
            w_elb_y = wing_origin_y - int(0.4 * b) + w_flap1
            w_wri_x = wing_origin_x + side * int(3.2 * b) + int(cape_drift * 0.3 * side)
            w_wri_y = wing_origin_y + int(0.1 * b) + w_flap1 + w_flap2
            w_tip_x = wing_origin_x + side * int(4.0 * b) + int(cape_drift * 0.6 * side)
            w_tip_y = wing_origin_y + int(0.5 * b) + int(w_flap1 * 1.2) + int(w_flap2 * 1.4)

            # 날개 아랫가장자리 (덮개깃 하단)
            w_sh_bot_y = wing_origin_y + int(1.6 * b)
            w_elb_bot_y = w_elb_y + int(1.4 * b) + int(w_flap1 * 0.2)
            w_wri_bot_y = w_wri_y + int(1.0 * b) + int(w_flap2 * 0.15)

            # ═══ 1) 날개 그림자 (깊이감) ═══
            shadow_off = int(0.08 * b)
            shd_pts = [
                (w_sh_x + shadow_off, w_sh_y + shadow_off),
                (w_elb_x + shadow_off, w_elb_y + shadow_off),
                (w_wri_x + shadow_off, w_wri_y + shadow_off),
                (w_tip_x + shadow_off, w_tip_y + shadow_off),
                (w_wri_x + shadow_off, w_wri_bot_y + shadow_off),
                (w_elb_x + shadow_off, w_elb_bot_y + shadow_off),
                (w_sh_x + shadow_off, w_sh_bot_y + shadow_off),
            ]
            shd_surf = self._get_surface(int(5 * b), int(4 * b))
            # 오프셋 맞추기
            sx_min = min(sp[0] for sp in shd_pts) - int(0.5 * b)
            sy_min = min(sp[1] for sp in shd_pts) - int(0.5 * b)
            shd_local = [(sx - sx_min, sy - sy_min) for sx, sy in shd_pts]
            if len(shd_local) >= 3:
                sw = max(sp[0] for sp in shd_local) + int(0.5 * b)
                sh = max(sp[1] for sp in shd_local) + int(0.5 * b)
                shd_surf = self._get_surface(max(4, sw), max(4, sh))
                pygame.draw.polygon(shd_surf, (40, 25, 10, 35), shd_local)
                screen.blit(shd_surf, (sx_min, sy_min))

            # ═══ 2) 큰덮개깃 (날개 안쪽 넓은 면 - 밝은 갈색) ═══
            covert_pts = [
                (w_sh_x, w_sh_y + int(0.3 * b)),
                (w_elb_x - side * int(0.1 * b), w_elb_y + int(0.3 * b)),
                (w_wri_x - side * int(0.2 * b), w_wri_y + int(0.25 * b)),
                (w_wri_x - side * int(0.3 * b), w_wri_bot_y),
                (w_elb_x - side * int(0.15 * b), w_elb_bot_y),
                (w_sh_x, w_sh_bot_y),
            ]
            pygame.draw.polygon(screen, p["feather_light"], covert_pts)
            # 덮개깃 줄무늬 (3줄)
            for ci in range(3):
                cr = (ci + 1) / 4.0
                cx1 = int(w_sh_x + (w_elb_x - w_sh_x) * cr)
                cy1 = int((w_sh_y + int(0.3 * b)) + (w_elb_y + int(0.3 * b) - w_sh_y - int(0.3 * b)) * cr)
                cx2 = cx1
                cy2 = int(w_sh_bot_y + (w_elb_bot_y - w_sh_bot_y) * cr)
                pygame.draw.line(screen, p["feather_tip"], (cx1, cy1), (cx2, cy2),
                               max(1, int(0.06 * b)))

            # ═══ 3) 날개 윗면 (주요 면 - 갈색) ═══
            main_pts = [
                (w_sh_x, w_sh_y),
                (w_elb_x, w_elb_y),
                (w_wri_x, w_wri_y),
                (w_tip_x, w_tip_y),
                (w_wri_x, w_wri_y + int(0.3 * b)),
                (w_elb_x, w_elb_y + int(0.35 * b)),
                (w_sh_x, w_sh_y + int(0.35 * b)),
            ]
            pygame.draw.polygon(screen, p["feather_brown"], main_pts)
            # 하이라이트 (윗면 상단 테두리)
            pygame.draw.line(screen, p["feather_tip"],
                           (w_sh_x, w_sh_y), (w_elb_x, w_elb_y),
                           max(1, int(0.06 * b)))
            pygame.draw.line(screen, p["feather_tip"],
                           (w_elb_x, w_elb_y), (w_wri_x, w_wri_y),
                           max(1, int(0.05 * b)))

            # ═══ 4) 중간덮개깃 줄 (날개 면 가로 패턴) ═══
            for mi in range(4):
                mr = (mi + 1) / 5.0
                # 상단 엣지 보간
                t_x = int(w_sh_x + (w_wri_x - w_sh_x) * mr)
                t_y = int(w_sh_y + (w_wri_y - w_sh_y) * mr) + int(0.15 * b)
                # 하단 엣지 보간
                b_x = int(w_sh_x + (w_wri_x - w_sh_x) * mr) - side * int(0.1 * b)
                b_y = int(w_sh_bot_y + (w_wri_bot_y - w_sh_bot_y) * mr)
                row_col = p["feather_white"] if mi % 3 == 0 else p["feather_light"]
                pygame.draw.line(screen, row_col, (t_x, t_y), (b_x, b_y),
                               max(1, int(0.05 * b)))

            # ═══ 5) 비행깃 (Primary feathers - 날개 끝 긴 깃털들) ═══
            prim_count = 8
            for fi in range(prim_count):
                fr = fi / float(prim_count - 1)
                # 날개 뒷가장자리 (손목→끝) 보간
                fb_x = int(w_wri_x + (w_tip_x - w_wri_x) * fr)
                fb_y = int(w_wri_y + (w_tip_y - w_wri_y) * fr)
                # 깃털 길이 (안쪽 짧게, 끝쪽 길게)
                f_len = int((0.8 + fr * 0.7) * b)
                # 개별 깃털 흔들림 (느린 파동)
                f_wave = int(_sin(t * 1.8 + fi * 0.4) * 0.04 * b)
                # 끝점
                fe_x = fb_x - side * int(0.2 * b * fr)
                fe_y = fb_y + f_len + f_wave
                # 깃털 폭 (두꺼운 선 → 가는 선)
                f_thick = max(2, int(0.12 * b * (1.0 - fr * 0.3)))
                f_thin = max(1, int(0.05 * b))
                # 깃털 외곽 (어두운 테두리)
                pygame.draw.line(screen, p["feather_dark"],
                               (fb_x, fb_y), (fe_x, fe_y), f_thick)
                # 깃털 내부 (밝은 갈색)
                pygame.draw.line(screen, p["feather_tip"],
                               (fb_x, fb_y), (fe_x, fe_y), f_thin)
                # 깃털 끝 하이라이트 (맨 끝 밝은 점)
                pygame.draw.circle(screen, p["feather_white"],
                                 (fe_x, fe_y), max(1, int(0.04 * b)))

            # ═══ 6) 차깃 (Secondary feathers - 팔꿈치~손목) ═══
            sec_count = 6
            for si in range(sec_count):
                sr_val = si / float(sec_count - 1)
                sb_x = int(w_elb_x + (w_wri_x - w_elb_x) * sr_val)
                sb_y = int(w_elb_y + (w_wri_y - w_elb_y) * sr_val) + int(0.25 * b)
                s_len = int((0.6 + sr_val * 0.3) * b)
                s_wave = int(_sin(t * 1.5 + si * 0.5 + 1.0) * 0.03 * b)
                se_x = sb_x - side * int(0.1 * b * sr_val)
                se_y = sb_y + s_len + s_wave
                s_thick = max(2, int(0.1 * b))
                pygame.draw.line(screen, p["feather_brown"],
                               (sb_x, sb_y), (se_x, se_y), s_thick)
                pygame.draw.line(screen, p["feather_light"],
                               (sb_x, sb_y), (se_x, se_y), max(1, int(0.04 * b)))

            # ═══ 7) 날개 뼈대 + 관절 (금장식) ═══
            # 뼈대
            bone_w1 = max(2, int(0.1 * b))
            bone_w2 = max(2, int(0.08 * b))
            bone_w3 = max(1, int(0.06 * b))
            pygame.draw.line(screen, p["feather_dark"],
                           (w_sh_x, w_sh_y), (w_elb_x, w_elb_y), bone_w1)
            pygame.draw.line(screen, p["feather_dark"],
                           (w_elb_x, w_elb_y), (w_wri_x, w_wri_y), bone_w2)
            pygame.draw.line(screen, p["feather_dark"],
                           (w_wri_x, w_wri_y), (w_tip_x, w_tip_y), bone_w3)
            # 뼈대 하이라이트
            pygame.draw.line(screen, p["feather_light"],
                           (w_sh_x, w_sh_y - 1), (w_elb_x, w_elb_y - 1),
                           max(1, int(0.04 * b)))
            # 관절 금장식
            jnt_r1 = max(2, int(0.12 * b))
            jnt_r2 = max(2, int(0.1 * b))
            pygame.draw.circle(screen, p["gold_dark"], (w_sh_x, w_sh_y), jnt_r1)
            pygame.draw.circle(screen, p["gold"], (w_sh_x, w_sh_y), max(1, jnt_r1 - 1))
            pygame.draw.circle(screen, p["gold_dark"], (w_elb_x, w_elb_y), jnt_r2)
            pygame.draw.circle(screen, p["gold"], (w_elb_x, w_elb_y), max(1, jnt_r2 - 1))
            # 손목 작은 관절
            pygame.draw.circle(screen, p["gold_dark"], (w_wri_x, w_wri_y), max(1, int(0.07 * b)))

        # ─── 다리 / 샌들 (정지 상태 - 부양에 맞춰 같이 떠오름) ───
        leg_base_y = cy + int(2.2 * b) + hover_offset
        for side in [-1, 1]:
            leg_x = cx + side * int(0.4 * b) + lean_offset
            knee_x = leg_x
            knee_y = leg_base_y + int(0.1 * b)
            # 허벅지
            pygame.draw.line(screen, p["skin_shadow"],
                           (leg_x, leg_base_y - int(1.0 * b)),
                           (knee_x, knee_y),
                           max(2, int(0.3 * b)))
            # 정강이
            foot_x = knee_x
            foot_y = leg_base_y + int(0.5 * b)
            pygame.draw.line(screen, p["skin_bronze"],
                           (knee_x, knee_y),
                           (foot_x, foot_y),
                           max(2, int(0.25 * b)))
            # 무릎 관절
            pygame.draw.circle(screen, p["skin_light"], (knee_x, knee_y), max(2, int(0.12 * b)))
            # 발목 금 장식
            anklet_y = foot_y - int(0.1 * b)
            anklet_w = max(3, int(0.2 * b))
            pygame.draw.line(screen, p["anklet_gold"],
                           (foot_x - anklet_w, anklet_y),
                           (foot_x + anklet_w, anklet_y),
                           max(2, int(0.08 * b)))
            # 샌들
            foot_w = max(3, int(0.5 * b))
            foot_h = max(2, int(0.2 * b))
            pygame.draw.ellipse(screen, p["sandal"],
                              (foot_x - foot_w // 2, foot_y,
                               foot_w, foot_h))

        # ─── 로인클로스 (쉔디트 - 짧은 린넨 치마) ───
        skirt_top = torso_y + int(1.2 * b)
        skirt_bot = leg_base_y - int(0.5 * b)
        skirt_w_top = int(1.8 * b)
        skirt_w_bot = int(2.2 * b)
        robe_wave = int(wave * 0.18 * cape_wave_boost * b)
        skirt_pts = [
            (cx - skirt_w_top // 2 + lean_offset, skirt_top),
            (cx + skirt_w_top // 2 + lean_offset, skirt_top),
            (cx + skirt_w_bot // 2 + lean_offset + robe_wave + int(cape_drift * 0.5), skirt_bot),
            (cx - skirt_w_bot // 2 + lean_offset - robe_wave + int(cape_drift * 0.5), skirt_bot),
        ]
        pygame.draw.polygon(screen, p["loincloth_white"], skirt_pts)
        # 그림자
        shadow_pts_l = [
            (cx - skirt_w_top // 2 + lean_offset + int(0.15 * b), skirt_top),
            (cx - skirt_w_top // 2 + lean_offset, skirt_top),
            (cx - skirt_w_bot // 2 + lean_offset - robe_wave + int(cape_drift * 0.5), skirt_bot),
            (cx - skirt_w_bot // 2 + lean_offset - robe_wave + int(cape_drift * 0.5) + int(0.15 * b), skirt_bot),
        ]
        pygame.draw.polygon(screen, p["loincloth_shadow"], shadow_pts_l)
        # 중앙 주름
        fold_drift_val = int(cape_drift * 0.3)
        pygame.draw.line(screen, p["loincloth_fold"],
                        (cx + lean_offset, skirt_top + int(0.2 * b)),
                        (cx + lean_offset + fold_drift_val, skirt_bot - int(0.1 * b)),
                        max(1, int(0.07 * b)))
        # 하단 깃털 장식 (갈색 테두리)
        hem_h = max(2, int(0.12 * b))
        pygame.draw.line(screen, p["feather_brown"],
                        (cx - skirt_w_bot // 2 + lean_offset - robe_wave + int(cape_drift * 0.5), skirt_bot - hem_h),
                        (cx + skirt_w_bot // 2 + lean_offset + robe_wave + int(cape_drift * 0.5), skirt_bot - hem_h),
                        hem_h)
        # 금색 허리띠
        belt_y = skirt_top
        belt_h = max(2, int(0.35 * b))
        belt_w = skirt_w_top + int(0.5 * b)
        pygame.draw.rect(screen, p["gold"],
                        (cx - belt_w // 2 + lean_offset, belt_y, belt_w, belt_h),
                        border_radius=max(1, int(0.1 * b)))
        pygame.draw.rect(screen, p["gold_light"],
                        (cx - belt_w // 2 + lean_offset, belt_y, belt_w, max(1, belt_h // 2)),
                        border_radius=max(1, int(0.1 * b)))
        # 허리 태양 보석
        gem_r = max(2, int(0.12 * b))
        pygame.draw.circle(screen, p["sun_orange"],
                         (cx + lean_offset, belt_y + belt_h // 2), gem_r)
        pygame.draw.circle(screen, p["sun_glow"],
                         (cx + lean_offset, belt_y + belt_h // 2), max(1, gem_r - 1))

        # ─── 몸통 (상체 - 브론즈 피부) ───
        torso_top = torso_y - int(0.5 * b)
        torso_bot = skirt_top + int(0.1 * b)
        torso_w = int(2.0 * b)
        torso_rect = pygame.Rect(cx - torso_w // 2 + lean_offset, torso_top,
                                  torso_w, torso_bot - torso_top)
        pygame.draw.rect(screen, p["skin_bronze"], torso_rect,
                        border_radius=max(1, int(0.2 * b)))
        hl_rect = pygame.Rect(torso_rect.x + int(0.1 * b), torso_rect.y + int(0.1 * b),
                               torso_w // 3, torso_rect.height - int(0.2 * b))
        pygame.draw.rect(screen, p["skin_light"], hl_rect,
                        border_radius=max(1, int(0.1 * b)))

        # ─── 깃털 칼라 / 펙토랄 (넓은 깃털 목걸이) ───
        collar_cx = cx + lean_offset
        collar_cy = torso_top + int(0.3 * b) + int(shoulder_bob * 0.15 * b)
        collar_w = int(2.4 * b)
        collar_h = int(1.0 * b)
        # 깃털 목걸이 - 여러 층
        for layer in range(3):
            layer_y = collar_cy + int(layer * 0.25 * b)
            layer_w = collar_w - int(layer * 0.3 * b)
            layer_h = int(0.2 * b)
            if layer == 0:
                layer_col = p["feather_brown"]
            elif layer == 1:
                layer_col = p["gold"]
            else:
                layer_col = p["mask_blue"]
            collar_pts = [
                (collar_cx - layer_w // 2, layer_y),
                (collar_cx + layer_w // 2, layer_y),
                (collar_cx + int(layer_w * 0.35), layer_y + layer_h),
                (collar_cx - int(layer_w * 0.35), layer_y + layer_h),
            ]
            pygame.draw.polygon(screen, layer_col, collar_pts)
        # 중앙 태양 장식
        sun_gem_r = max(2, int(0.15 * b))
        pygame.draw.circle(screen, p["sun_orange"],
                         (collar_cx, collar_cy + int(0.5 * b)), sun_gem_r)
        pygame.draw.circle(screen, p["sun_glow"],
                         (collar_cx - 1, collar_cy + int(0.5 * b) - 1),
                         max(1, sun_gem_r // 2))

        # ─── 어깨 + 깃털 패드 ───
        shoulder_y = torso_top + int(0.2 * b) + int(shoulder_bob * 0.2 * b)
        for side in [-1, 1]:
            sx = cx + side * int(1.0 * b) + lean_offset
            sy = shoulder_y
            # 어깨 금 장식
            pad_r = max(2, int(0.35 * b))
            pygame.draw.circle(screen, p["gold_dark"], (sx, sy), pad_r)
            pygame.draw.circle(screen, p["gold"], (sx, sy), pad_r - 1)
            # 어깨 깃털 (2~3개 작은 깃털)
            for fi in range(3):
                f_angle = (fi - 1) * 0.3 + side * 0.2
                f_len = int(0.5 * b)
                ftip_x = sx + int(_sin(f_angle) * f_len) + side * int(0.15 * b)
                ftip_y = sy - int(_cos(f_angle) * f_len) - int(0.1 * b)
                f_sway = int(_sin(t * 2.5 + fi * 1.2) * 0.05 * b * side_blend)
                pygame.draw.line(screen, p["feather_tip"],
                               (sx, sy), (ftip_x + f_sway, ftip_y),
                               max(1, int(0.07 * b)))
                # 깃털 끝 삼각형
                ft_size = max(1, int(0.08 * b))
                pygame.draw.circle(screen, p["feather_light"],
                                 (ftip_x + f_sway, ftip_y), ft_size)

        # ─── 사신의 낫 (양손 그립) + 팔 ───
        arm_thick = max(2, int(0.22 * b))

        # 낫 자루 기준점 계산 (45도 대각선 - 양손 그립)
        # 정면: 왼손(위쪽 그립) + 오른손(아래쪽 그립)
        # 후면: 오른손(위쪽 그립) + 왼손(아래쪽 그립)
        grip_cx = cx + lean_offset
        tilt = 0.7071  # sin(45°) ≈ cos(45°)

        # 자루 전체 (45도 대각선: 오른쪽 위 → 왼쪽 아래)
        shaft_len_top = int(2.5 * b)
        shaft_len_bot = int(2.0 * b)
        shaft_top_x = grip_cx + int(shaft_len_top * tilt)
        shaft_top_y = torso_y - int(shaft_len_top * tilt)
        shaft_bot_x = grip_cx - int(shaft_len_bot * tilt)
        shaft_bot_y = torso_y + int(shaft_len_bot * tilt)

        # 그립 위치도 45도 자루 위에 배치
        grip_dist_top = int(0.4 * b)   # 피벗에서 위쪽 그립까지 거리
        grip_dist_bot = int(1.0 * b)   # 피벗에서 아래쪽 그립까지 거리
        grip_top_x = grip_cx + int(grip_dist_top * tilt)
        grip_top_y = torso_y - int(grip_dist_top * tilt) + int(0.2 * b)
        grip_bot_x = grip_cx - int(grip_dist_bot * tilt)
        grip_bot_y = torso_y + int(grip_dist_bot * tilt) + int(0.2 * b)

        # 자루 피벗 (양손 중간)
        pivot_x = (grip_top_x + grip_bot_x) // 2
        pivot_y = (grip_top_y + grip_bot_y) // 2

        # 스윙 회전
        swing_dir = -1 if show_back else 1
        scythe_angle = weapon_swing * 1.8 * swing_dir

        # 스윙 시 전체 회전
        if scythe_angle != 0:
            _rot_top = self._rotate_point(shaft_top_x, shaft_top_y, pivot_x, pivot_y, scythe_angle)
            s_top_x, s_top_y = int(_rot_top[0]), int(_rot_top[1])
            _rot_bot = self._rotate_point(shaft_bot_x, shaft_bot_y, pivot_x, pivot_y, scythe_angle)
            s_bot_x, s_bot_y = int(_rot_bot[0]), int(_rot_bot[1])
            _rot_gt = self._rotate_point(grip_top_x, grip_top_y, pivot_x, pivot_y, scythe_angle)
            g_top_x, g_top_y = int(_rot_gt[0]), int(_rot_gt[1])
            _rot_gb = self._rotate_point(grip_bot_x, grip_bot_y, pivot_x, pivot_y, scythe_angle)
            g_bot_x, g_bot_y = int(_rot_gb[0]), int(_rot_gb[1])
        else:
            s_top_x, s_top_y = shaft_top_x, shaft_top_y
            s_bot_x, s_bot_y = shaft_bot_x, shaft_bot_y
            g_top_x, g_top_y = grip_top_x, grip_top_y
            g_bot_x, g_bot_y = grip_bot_x, grip_bot_y

        # 스윙 잔상 (번개 궤적)
        if abs(weapon_swing) > 0.15:
            # 번개 끝점 (회전 전)
            blade_tip_raw_x = shaft_top_x - int(0.1 * b)
            blade_tip_raw_y = shaft_top_y + int(1.3 * b)
            trail_pts = []
            t_steps = 6
            for ti in range(t_steps + 1):
                t_frac = ti / float(t_steps)
                t_ang = scythe_angle * t_frac
                if t_ang != 0:
                    _tr = self._rotate_point(blade_tip_raw_x, blade_tip_raw_y, pivot_x, pivot_y, t_ang)
                    trail_pts.append((int(_tr[0]), int(_tr[1])))
                else:
                    trail_pts.append((blade_tip_raw_x, blade_tip_raw_y))
            t_all_x = [tp_i[0] for tp_i in trail_pts] + [s_top_x]
            t_all_y = [tp_i[1] for tp_i in trail_pts] + [s_top_y]
            t_pad = int(0.6 * b)
            t_mn_x, t_mn_y = min(t_all_x) - t_pad, min(t_all_y) - t_pad
            t_mx_x, t_mx_y = max(t_all_x) + t_pad, max(t_all_y) + t_pad
            tw = max(4, t_mx_x - t_mn_x)
            th = max(4, t_mx_y - t_mn_y)
            t_surf = self._get_surface(tw, th)
            for ti in range(len(trail_pts) - 1):
                f_alpha = int(abs(weapon_swing) * 140 * ((ti + 1) / len(trail_pts)))
                lp1 = (trail_pts[ti][0] - t_mn_x, trail_pts[ti][1] - t_mn_y)
                lp2 = (trail_pts[ti + 1][0] - t_mn_x, trail_pts[ti + 1][1] - t_mn_y)
                pygame.draw.line(t_surf, (180, 220, 255, f_alpha),
                               lp1, lp2, max(2, int(0.12 * b)))
            screen.blit(t_surf, (t_mn_x, t_mn_y))

        # 낫 자루 (나무 질감)
        shaft_w = max(2, int(0.12 * b))
        pygame.draw.line(screen, p["scythe_shaft"],
                        (s_top_x, s_top_y), (s_bot_x, s_bot_y), shaft_w + 1)
        pygame.draw.line(screen, p["scythe_shaft_light"],
                        (s_top_x - 1, s_top_y), (s_bot_x - 1, s_bot_y), max(1, shaft_w - 1))
        # 자루 금장식 링 (그립 위치)
        ring_r = max(2, int(0.08 * b))
        pygame.draw.circle(screen, p["gold"], (g_top_x, g_top_y), ring_r)
        pygame.draw.circle(screen, p["gold"], (g_bot_x, g_bot_y), ring_r)

        # ─── 번개 낫날 (자루 상단에서 지그재그 번개 형상) ───
        # 번개 꼭짓점들 (자루 상단 기준, 아래로 지그재그)
        bolt_raw = [
            (shaft_top_x, shaft_top_y),                                          # 0: 시작 (자루 끝)
            (shaft_top_x + int(0.45 * b), shaft_top_y + int(0.35 * b)),          # 1: 오른쪽으로 꺾임
            (shaft_top_x + int(0.05 * b), shaft_top_y + int(0.65 * b)),          # 2: 왼쪽으로 꺾임
            (shaft_top_x + int(0.35 * b), shaft_top_y + int(0.95 * b)),          # 3: 오른쪽으로 꺾임
            (shaft_top_x - int(0.1 * b), shaft_top_y + int(1.3 * b)),           # 4: 끝 (뾰족한 번개 끝)
        ]
        # 번개 두께용 안쪽 라인 (폭을 만들기 위해)
        bolt_w = int(0.2 * b)
        bolt_inner_raw = [
            (shaft_top_x - int(0.1 * b), shaft_top_y + int(0.05 * b)),          # 0i
            (shaft_top_x + int(0.2 * b), shaft_top_y + int(0.4 * b)),           # 1i
            (shaft_top_x - int(0.15 * b), shaft_top_y + int(0.7 * b)),          # 2i
            (shaft_top_x + int(0.1 * b), shaft_top_y + int(1.0 * b)),           # 3i
        ]

        # 회전 적용
        bolt_pts = []
        bolt_inner_pts = []
        if scythe_angle != 0:
            for bx, by in bolt_raw:
                _r = self._rotate_point(bx, by, pivot_x, pivot_y, scythe_angle)
                bolt_pts.append((int(_r[0]), int(_r[1])))
            for bx, by in bolt_inner_raw:
                _r = self._rotate_point(bx, by, pivot_x, pivot_y, scythe_angle)
                bolt_inner_pts.append((int(_r[0]), int(_r[1])))
        else:
            bolt_pts = [(int(x), int(y)) for x, y in bolt_raw]
            bolt_inner_pts = [(int(x), int(y)) for x, y in bolt_inner_raw]

        # 번개 끝점 (파티클용)
        bt_x, bt_y = bolt_pts[4]

        # 번개 글로우 (외부 발광)
        glow_r = max(2, int(0.15 * b))
        glow_a = int(30 + 20 * sun_pulse)
        for i in range(len(bolt_pts) - 1):
            gx = (bolt_pts[i][0] + bolt_pts[i + 1][0]) // 2
            gy = (bolt_pts[i][1] + bolt_pts[i + 1][1]) // 2
            gs = self._get_surface(glow_r * 4, glow_r * 4)
            pygame.draw.circle(gs, (255, 220, 80, glow_a), (glow_r * 2, glow_r * 2), glow_r * 2)
            screen.blit(gs, (gx - glow_r * 2, gy - glow_r * 2))

        # 번개 폴리곤 (외곽 + 안쪽으로 두께감 있는 형태)
        lightning_poly = bolt_pts + list(reversed(bolt_inner_pts))
        if len(lightning_poly) >= 3:
            # 전기 색 (밝은 파란-흰색)
            bolt_color = (180, 210, 255)
            pygame.draw.polygon(screen, bolt_color, lightning_poly)
            # 외곽선 (더 밝은 엣지)
            bolt_edge = (220, 240, 255)
            for i in range(len(bolt_pts) - 1):
                pygame.draw.line(screen, bolt_edge,
                                bolt_pts[i], bolt_pts[i + 1],
                                max(1, int(0.06 * b)))
            # 안쪽 코어 (흰색 - 중심선)
            bolt_core = (255, 255, 255)
            core_pts = []
            for i in range(len(bolt_pts)):
                if i < len(bolt_inner_pts):
                    cx_b = (bolt_pts[i][0] + bolt_inner_pts[i][0]) // 2
                    cy_b = (bolt_pts[i][1] + bolt_inner_pts[i][1]) // 2
                    core_pts.append((cx_b, cy_b))
                else:
                    core_pts.append(bolt_pts[i])
            for i in range(len(core_pts) - 1):
                pygame.draw.line(screen, bolt_core,
                                core_pts[i], core_pts[i + 1],
                                max(1, int(0.04 * b)))

        # 번개 끝 전기 스파크 (끝에서 튀는 전기)
        spark_a = int(50 + 30 * sun_pulse)
        for si in range(3):
            sp_angle = t * 5.0 + si * 2.1
            sp_len = int(0.25 * b)
            spx = bt_x + int(_sin(sp_angle) * sp_len)
            spy = bt_y + int(_cos(sp_angle) * sp_len)
            sp_surf = self._get_surface(4, 4)
            pygame.draw.circle(sp_surf, (200, 230, 255, spark_a), (2, 2), 2)
            screen.blit(sp_surf, (spx - 2, spy - 2))

        # 자루-칼날 연결부 금장식
        conn_r = max(2, int(0.12 * b))
        pygame.draw.circle(screen, p["gold_dark"], (s_top_x, s_top_y), conn_r)
        pygame.draw.circle(screen, p["gold"], (s_top_x, s_top_y), max(1, conn_r - 1))
        # 자루 하단 금 끝장식
        end_r = max(2, int(0.1 * b))
        pygame.draw.circle(screen, p["gold_dark"], (s_bot_x, s_bot_y), end_r)
        pygame.draw.circle(screen, p["gold"], (s_bot_x, s_bot_y), max(1, end_r - 1))

        # 스윙 시 번개 전기 파티클
        if abs(weapon_swing) > 0.3:
            burst_n = int(abs(weapon_swing) * 8)
            for bi in range(burst_n):
                bp = self.time * 8.0 + bi * 2.1 + weapon_swing * 10
                bx = bt_x + int(_sin(bp) * 1.2 * b)
                by = bt_y + int(_cos(bp * 0.7) * 0.8 * b)
                ba = int(abs(weapon_swing) * 150 * max(0, _sin(bp * 1.5)))
                burst_r = max(1, int(0.1 * b))
                if ba > 10:
                    bs = self._get_surface(burst_r * 2, burst_r * 2)
                    pygame.draw.circle(bs, (180, 220, 255, ba), (burst_r, burst_r), burst_r)
                    screen.blit(bs, (bx - burst_r, by - burst_r))

        # ─── 양팔 (낫 자루를 양손으로 잡는 포즈) ───
        for side in [-1, 1]:
            s_x = cx + side * int(1.0 * b) + lean_offset
            s_y = shoulder_y + int(0.2 * b)
            # 위쪽 그립: 정면=왼손(-1), 후면=오른손(1)
            is_top_grip = (side == -1 and not show_back) or (side == 1 and show_back)
            if is_top_grip:
                target_hx, target_hy = g_top_x, g_top_y
            else:
                target_hx, target_hy = g_bot_x, g_bot_y
            # 팔꿈치 (어깨→손 중간, 약간 바깥쪽)
            e_x = (s_x + target_hx) // 2 + side * int(0.3 * b)
            e_y = (s_y + target_hy) // 2 + int(0.2 * b)
            # 윗팔
            pygame.draw.line(screen, p["skin_bronze"], (s_x, s_y), (e_x, e_y), arm_thick + 1)
            pygame.draw.line(screen, p["skin_light"], (s_x, s_y), (e_x, e_y), arm_thick)
            # 아랫팔
            pygame.draw.line(screen, p["skin_bronze"], (e_x, e_y), (target_hx, target_hy), arm_thick)
            # 팔꿈치 금 팔찌
            br_r = max(2, int(0.15 * b))
            pygame.draw.circle(screen, p["gold"], (e_x, e_y), br_r)
            # 손
            hand_r = max(2, int(0.18 * b))
            pygame.draw.circle(screen, p["skin_bronze"], (target_hx, target_hy), hand_r)

        # ─── 머리 (독수리/매 가면) ───
        head_x = cx + lean_offset
        head_y = torso_y - int(1.5 * b)
        head_r = int(0.8 * b)

        # 깃털/가면 관성 (이동 시 머리 깃털 흔들림)
        feather_drift = int(-move_dir * side_blend * 0.25 * b)
        feather_sway = int(_sin(self.time * 2.8) * side_blend * 0.12 * b)
        head_flap = feather_drift + feather_sway

        if not show_back:
            # ═══ 정면 ═══

            # 매 가면 (독수리 머리 형태)
            # 기본 두부 - 갈색 깃털 색
            pygame.draw.circle(screen, p["feather_brown"], (head_x, head_y), head_r)
            # 밝은 하이라이트
            pygame.draw.circle(screen, p["feather_light"],
                             (head_x - int(0.1 * b), head_y - int(0.1 * b)),
                             head_r - max(1, int(0.15 * b)))

            # 가면 상단 (독수리 이마 - 뾰족한 형태)
            mask_pts = [
                (head_x - int(0.75 * b), head_y),
                (head_x + int(0.75 * b), head_y),
                (head_x + int(0.55 * b), head_y - int(0.65 * b)),
                (head_x, head_y - int(0.9 * b)),
                (head_x - int(0.55 * b), head_y - int(0.65 * b)),
            ]
            pygame.draw.polygon(screen, p["feather_brown"], mask_pts)
            # 가면 테두리
            pygame.draw.lines(screen, p["gold_dark"], True, mask_pts, max(1, int(0.06 * b)))

            # 이마 금 밴드
            band_y_pos = head_y - int(0.15 * b)
            band_w = int(0.75 * b)
            pygame.draw.line(screen, p["gold"],
                           (head_x - band_w, band_y_pos),
                           (head_x + band_w, band_y_pos),
                           max(2, int(0.12 * b)))
            # 밴드 위 작은 태양 장식
            mini_sun_r = max(1, int(0.08 * b))
            pygame.draw.circle(screen, p["sun_orange"],
                             (head_x, band_y_pos - int(0.1 * b)), mini_sun_r)

            # ─── 매의 눈 (붉은 눈 + 금색 아이라인) ───
            eye_y = head_y + int(0.08 * b)
            for side in [-1, 1]:
                ex = head_x + side * int(0.28 * b)
                # 눈 형태 (날카로운 삼각형에 가까운 타원)
                eye_w = max(2, int(0.22 * b))
                eye_h = max(1, int(0.14 * b))
                # 눈 배경 (노란색)
                pygame.draw.ellipse(screen, p["eye_gold"],
                                  (ex - eye_w, eye_y - eye_h,
                                   eye_w * 2, eye_h * 2))
                # 홍채 (붉은색)
                iris_r = max(1, int(0.09 * b))
                pygame.draw.circle(screen, p["eye_red"], (ex, eye_y), iris_r)
                # 동공
                pygame.draw.circle(screen, p["eye_pupil"],
                                 (ex, eye_y), max(1, iris_r // 2))
                # 눈빛 하이라이트
                pygame.draw.circle(screen, (255, 230, 180),
                                 (ex + max(1, int(0.03 * b)),
                                  eye_y - max(1, int(0.03 * b))),
                                 max(1, int(0.04 * b)))
                # 아이라인 상단 (날카로운 선)
                pygame.draw.line(screen, p["feather_dark"],
                               (ex - eye_w - int(0.05 * b), eye_y - int(0.04 * b)),
                               (ex + eye_w + int(0.08 * b), eye_y - int(0.04 * b)),
                               max(1, int(0.06 * b)))
                # 아이라인 꼬리 (호루스의 눈 스타일)
                tail_x = ex + side * int(0.3 * b)
                tail_y = eye_y + int(0.18 * b)
                pygame.draw.line(screen, p["feather_dark"],
                               (ex + side * eye_w, eye_y + int(0.05 * b)),
                               (tail_x, tail_y),
                               max(1, int(0.05 * b)))

            # ─── 부리 (독수리 부리 - 아래로 휜 형태) ───
            beak_cx = head_x
            beak_top_y = head_y + int(0.25 * b)
            beak_bot_y = beak_top_y + int(0.4 * b)
            beak_w = max(2, int(0.18 * b))
            # 부리 윗부분
            beak_pts = [
                (beak_cx - beak_w, beak_top_y),
                (beak_cx + beak_w, beak_top_y),
                (beak_cx + int(beak_w * 0.3), beak_bot_y + int(0.1 * b)),
                (beak_cx, beak_bot_y + int(0.15 * b)),
                (beak_cx - int(beak_w * 0.3), beak_bot_y + int(0.1 * b)),
            ]
            pygame.draw.polygon(screen, p["beak_orange"], beak_pts)
            # 부리 끝 (어두운 색)
            beak_tip_pts = [
                (beak_cx - int(beak_w * 0.4), beak_bot_y),
                (beak_cx + int(beak_w * 0.4), beak_bot_y),
                (beak_cx, beak_bot_y + int(0.15 * b)),
            ]
            pygame.draw.polygon(screen, p["beak_dark"], beak_tip_pts)
            # 부리 콧구멍
            pygame.draw.circle(screen, p["feather_dark"],
                             (beak_cx - int(0.05 * b), beak_top_y + int(0.1 * b)),
                             max(1, int(0.03 * b)))
            pygame.draw.circle(screen, p["feather_dark"],
                             (beak_cx + int(0.05 * b), beak_top_y + int(0.1 * b)),
                             max(1, int(0.03 * b)))

            # ─── 머리 위 태양 디스크 (라의 상징 - 항상 떠있음) ───
            crown_sun_x = head_x
            crown_sun_y = head_y - int(1.2 * b)
            crown_sun_r = max(3, int(0.22 * b))
            # 태양 글로우
            c_glow_r = crown_sun_r + max(2, int(0.2 * b * sun_pulse))
            cgs = self._get_surface(c_glow_r * 4, c_glow_r * 4)
            cga = int(35 + 25 * sun_pulse)
            pygame.draw.circle(cgs, (*p["sun_glow"], cga), (c_glow_r * 2, c_glow_r * 2), c_glow_r)
            screen.blit(cgs, (crown_sun_x - c_glow_r * 2, crown_sun_y - c_glow_r * 2),
                       special_flags=pygame.BLEND_ADD)
            # 뿔 (독수리 뿔 형태 - 태양 디스크를 감싸는 초승달)
            horn_h = int(0.5 * b)
            horn_w = int(0.35 * b)
            for side in [-1, 1]:
                horn_pts = [
                    (crown_sun_x + side * int(0.15 * b), crown_sun_y + int(0.1 * b)),
                    (crown_sun_x + side * horn_w, crown_sun_y - horn_h),
                    (crown_sun_x + side * int(horn_w * 0.6), crown_sun_y - horn_h + int(0.1 * b)),
                    (crown_sun_x + side * int(0.08 * b), crown_sun_y - int(0.05 * b)),
                ]
                pygame.draw.polygon(screen, p["gold"], horn_pts)
                pygame.draw.lines(screen, p["gold_dark"], False, horn_pts[:3], max(1, int(0.05 * b)))
            # 태양 본체
            pygame.draw.circle(screen, p["sun_red"], (crown_sun_x, crown_sun_y), crown_sun_r)
            pygame.draw.circle(screen, p["sun_orange"], (crown_sun_x, crown_sun_y), max(2, crown_sun_r - 1))
            pygame.draw.circle(screen, p["sun_core"],
                             (crown_sun_x, crown_sun_y), max(1, crown_sun_r // 2))

        else:
            # ═══ 후면 ═══
            # 뒷머리 (갈색 깃털)
            pygame.draw.circle(screen, p["feather_brown"], (head_x, head_y), head_r)
            # 깃털 무늬
            for j in range(4):
                fy = head_y - int(0.3 * b) + int(j * 0.2 * b)
                fw = int(0.65 * b - j * 0.05 * b)
                f_col = p["feather_light"] if j % 2 == 0 else p["feather_dark"]
                pygame.draw.line(screen, f_col,
                               (head_x - fw, fy), (head_x + fw, fy),
                               max(1, int(0.06 * b)))

            # 가면 상단 (뒤에서 볼 때)
            mask_pts = [
                (head_x - int(0.75 * b), head_y),
                (head_x + int(0.75 * b), head_y),
                (head_x + int(0.55 * b), head_y - int(0.65 * b)),
                (head_x, head_y - int(0.9 * b)),
                (head_x - int(0.55 * b), head_y - int(0.65 * b)),
            ]
            pygame.draw.polygon(screen, p["feather_brown"], mask_pts)
            pygame.draw.lines(screen, p["gold_dark"], True, mask_pts, max(1, int(0.06 * b)))

            # 이마 밴드 (뒤)
            band_y_pos = head_y - int(0.15 * b)
            band_w = int(0.75 * b)
            pygame.draw.line(screen, p["gold"],
                           (head_x - band_w, band_y_pos),
                           (head_x + band_w, band_y_pos),
                           max(2, int(0.12 * b)))

            # 태양 디스크 (뒤에서도 보임)
            crown_sun_x = head_x
            crown_sun_y = head_y - int(1.2 * b)
            crown_sun_r = max(3, int(0.22 * b))
            c_glow_r = crown_sun_r + max(2, int(0.15 * b * sun_pulse))
            cgs = self._get_surface(c_glow_r * 4, c_glow_r * 4)
            cga = int(30 + 20 * sun_pulse)
            pygame.draw.circle(cgs, (*p["sun_glow"], cga), (c_glow_r * 2, c_glow_r * 2), c_glow_r)
            screen.blit(cgs, (crown_sun_x - c_glow_r * 2, crown_sun_y - c_glow_r * 2),
                       special_flags=pygame.BLEND_ADD)
            # 뿔
            horn_h = int(0.5 * b)
            horn_w = int(0.35 * b)
            for side in [-1, 1]:
                horn_pts = [
                    (crown_sun_x + side * int(0.15 * b), crown_sun_y + int(0.1 * b)),
                    (crown_sun_x + side * horn_w, crown_sun_y - horn_h),
                    (crown_sun_x + side * int(horn_w * 0.6), crown_sun_y - horn_h + int(0.1 * b)),
                    (crown_sun_x + side * int(0.08 * b), crown_sun_y - int(0.05 * b)),
                ]
                pygame.draw.polygon(screen, p["gold"], horn_pts)
            pygame.draw.circle(screen, p["sun_red"], (crown_sun_x, crown_sun_y), crown_sun_r)
            pygame.draw.circle(screen, p["sun_orange"], (crown_sun_x, crown_sun_y), max(2, crown_sun_r - 1))

            # 뒷머리 중앙선
            pygame.draw.line(screen, p["feather_dark"],
                           (head_x, head_y - int(0.3 * b)),
                           (head_x + int(head_flap * 0.3), head_y + int(0.5 * b)),
                           max(1, int(0.05 * b)))

        # ─── 목 ───
        neck_w = max(2, int(0.25 * b))
        pygame.draw.line(screen, p["skin_bronze"],
                        (head_x, head_y + head_r - int(0.1 * b)),
                        (head_x, torso_top + int(0.2 * b)), neck_w)

        # ─── 앞쪽 깃털 파티클 (정면 전용) ───
        if not show_back:
            for i in range(2):
                phase2 = t * 1.8 + i * 2.0 + 3
                fx = cx + int(_sin(phase2) * 3.5 * b) + lean_offset
                fy = torso_y - int(1.5 * b) + int(_sin(phase2 * 0.5) * 2.5 * b)
                fa = int(30 + 20 * _sin(phase2 * 1.5))
                fr = max(1, int(0.3 * b))
                fsf = self._get_surface(fr * 2, fr * 2)
                pygame.draw.circle(fsf, (255, 180, 60, fa), (fr, fr), fr)
                screen.blit(fsf, (fx - fr, fy - fr))

        # ─── 발밑 태양빛 먼지 (이동 시에만) ───
        if side_blend > 0.15:
            dust_count = int(2 + side_blend * 3)
            for i in range(dust_count):
                dp = t * 2.5 + i * 1.3
                dx = cx + lean_offset + int(-move_dir * (1 + i * 0.8) * b) + int(_sin(dp) * 0.5 * b)
                dy = leg_base_y + int(0.5 * b) + int(_sin(dp * 0.8) * 0.3 * b)
                da = int(30 * side_blend * max(0, _sin(dp * 1.2)))
                dr = max(1, int((0.3 + i * 0.08) * b))
                if da > 5:
                    ds = self._get_surface(dr * 2, dr * 2)
                    pygame.draw.circle(ds, (255, 190, 80, da), (dr, dr), dr)
                    screen.blit(ds, (dx - dr, dy - dr))

    # =========================================================================
    # 안드로이드 - 전투 병기 (폭탄 + 기관포로 무장한 전투 로봇) [고퀄리티]
    # =========================================================================
    def _draw_android(self, screen, cx, cy, b, color, show_back, anim):
        """안드로이드 - 전투 병기 (왼손에 폭탄, 오른손에 기관포를 장착한 전투 로봇) [HD 버전]"""
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        left_arm_swing = anim.get("left_arm_swing", 0)
        right_arm_swing = anim.get("right_arm_swing", 0)
        shoulder_bob = anim.get("shoulder_bob", 0)
        left_leg_sway = anim.get("left_leg_sway", 0)
        right_leg_sway = anim.get("right_leg_sway", 0)
        left_leg_lift = anim.get("left_leg", 0)
        right_leg_lift = anim.get("right_leg", 0)
        side_blend = anim.get("side_blend", 0)
        move_dir = anim.get("move_dir", 0)
        weapon_swing = anim.get("weapon_swing_angle", 0)

        torso_y = cy - int(1.5 * b) + int(body_bob * 2 * b)
        lean_offset = int(lean * 2.5 * b)

        t = self.time
        gatling_firing = anim.get('gatling_firing', False)
        gatling_recoil = anim.get('gatling_recoil', 0)
        gatling_mounting = anim.get('gatling_mounting', False)
        mount_progress = anim.get('gatling_mount_progress', 0.0)
        gatling_dismounting = anim.get('gatling_dismounting', False)
        dismount_progress = anim.get('gatling_dismount_progress', 0.0)

        # 🔫 반동: 발사 시 몸체 미세 진동 (recoil 값 + 고주파 떨림)
        if gatling_firing:
            recoil_shake_x = int(_sin(t * 45) * 1.2 * b * 0.08)
            # 상단 영웅은 아래로, 하단 영웅은 위로 반동
            recoil_dir = 1 if show_back else -1
            recoil_shake_y = int(gatling_recoil * recoil_dir * 0.4)
            cx += recoil_shake_x
            torso_y += recoil_shake_y

        # LED 펄스 (사이언 계열 빛) - 견착/발사 시 더 빠르게
        is_active = gatling_firing or gatling_mounting
        led_pulse = (_sin(t * (8 if is_active else 3)) + 1) * 0.5
        reactor_pulse = (_sin(t * (12 if is_active else 4.5)) + 1) * 0.5
        # 기관포 배럴 회전 (idle → 견착 시 가속 → 발사 시 최대)
        if gatling_firing:
            barrel_spin = t * 18.0
        elif gatling_mounting:
            barrel_spin = t * (2.0 + 10.0 * mount_progress)  # 점점 빨라짐
        else:
            barrel_spin = t * 2.0

        # 로봇 색상 팔레트
        p = {
            "armor": color,
            "armor_light": tuple(min(255, c + 45) for c in color),
            "armor_mid": tuple(min(255, c + 20) for c in color),
            "armor_dark": tuple(max(0, c - 40) for c in color),
            "armor_shadow": tuple(max(0, c - 70) for c in color),
            "frame": (60, 65, 75),
            "frame_light": (90, 95, 105),
            "frame_dark": (35, 38, 45),
            "joint": (100, 105, 115),
            "joint_light": (140, 145, 155),
            "joint_dark": (65, 68, 78),
            "led_cyan": (0, 220, 255),
            "led_cyan_dim": (0, 120, 160),
            "led_red": (255, 50, 30),
            "reactor_blue": (30, 140, 255),
            "reactor_glow": (80, 180, 255),
            "reactor_white": (200, 230, 255),
            "cannon_dark": (50, 52, 58),
            "cannon_mid": (75, 78, 85),
            "cannon_light": (110, 115, 125),
            "cannon_barrel": (40, 42, 48),
            "bomb_body": (45, 40, 35),
            "bomb_highlight": (80, 72, 60),
            "bomb_fuse": (120, 90, 40),
            "bomb_spark": (255, 200, 50),
            "bomb_glow": (255, 160, 30),
            "visor": (0, 200, 240),
            "visor_glow": (100, 230, 255),
            "visor_dim": (0, 100, 140),
            "antenna": (180, 185, 195),
            "wire_red": (200, 60, 50),
            "wire_blue": (50, 100, 200),
        }

        # === 🔫 탱크 변신 시스템 ===
        is_transforming = gatling_mounting or gatling_dismounting
        is_tank_mode = gatling_firing

        if is_transforming or is_tank_mode:
            # 변환 진행도 계산 (0.0=안드로이드, 1.0=탱크)
            if gatling_mounting:
                transform_progress = mount_progress  # 0→1
            elif gatling_firing:
                transform_progress = 1.0  # 완전 탱크
            else:  # dismounting
                transform_progress = 1.0 - dismount_progress  # 1→0

            _aim_angle = anim.get('gatling_aim_angle', None)
            self._draw_android_tank_transform(
                screen, cx, torso_y, b, p, t, transform_progress,
                barrel_spin, gatling_firing, show_back,
                led_pulse, reactor_pulse, lean_offset,
                gatling_recoil, _aim_angle
            )
            return  # 변신 중에는 일반 안드로이드 그리지 않음

        # === 리액터 오라 (뒤쪽 글로우) ===
        aura_size = int(3.5 * b)
        aura_surf = self._get_surface(aura_size * 2, aura_size * 2)
        for i in range(3):
            aura_alpha = int((18 - i * 5) * reactor_pulse)
            aura_r = int((1.4 - i * 0.35) * b)
            pygame.draw.circle(aura_surf, (*p["reactor_blue"], aura_alpha),
                             (aura_size, aura_size), aura_r)
        screen.blit(aura_surf, (cx - aura_size + lean_offset,
                                torso_y - int(0.5 * b) - aura_size // 2),
                   special_flags=pygame.BLEND_ADD)

        # === 다리 (유압식 기계 다리) ===
        hip_y = torso_y + int(2.0 * b)
        for side in [-1, 1]:
            cur_sway = left_leg_sway if side == -1 else right_leg_sway
            cur_lift = left_leg_lift if side == -1 else right_leg_lift
            leg_sway_x = int(cur_sway * 0.5 * b)
            leg_lift_y = int(cur_lift * 0.3 * b)

            thigh_x = cx + side * int(0.55 * b) + lean_offset + leg_sway_x

            # 허벅지 (장갑판 + 유압 실린더)
            thigh_top = hip_y - leg_lift_y
            thigh_h = int(1.5 * b)
            thigh_rect = pygame.Rect(thigh_x - int(0.48 * b), thigh_top,
                                    int(0.96 * b), thigh_h)
            pygame.draw.rect(screen, p["armor_shadow"],
                           thigh_rect.inflate(2, 2), border_radius=4)
            pygame.draw.rect(screen, p["armor_dark"],
                           thigh_rect, border_radius=4)
            pygame.draw.rect(screen, p["armor"],
                           thigh_rect.inflate(-int(0.1 * b), -int(0.08 * b)),
                           border_radius=3)

            # 유압 실린더 (허벅지 측면)
            cyl_x = thigh_x + side * int(0.28 * b)
            pygame.draw.line(screen, p["joint_dark"],
                           (cyl_x, thigh_rect.top + int(0.15 * b)),
                           (cyl_x, thigh_rect.bottom - int(0.1 * b)),
                           max(2, int(0.08 * b)))
            pygame.draw.line(screen, p["joint_light"],
                           (cyl_x - 1, thigh_rect.top + int(0.18 * b)),
                           (cyl_x - 1, thigh_rect.bottom - int(0.12 * b)),
                           max(1, int(0.04 * b)))

            # 장갑판 볼트
            for i in range(2):
                bolt_y = thigh_rect.top + int(0.3 * b) + i * int(0.6 * b)
                bolt_x = thigh_x - side * int(0.15 * b)
                pygame.draw.circle(screen, p["joint"], (bolt_x, bolt_y),
                                 max(1, int(0.05 * b)))

            # 무릎 관절 (로터리 조인트)
            knee_y = thigh_rect.bottom - int(0.1 * b) - leg_lift_y // 2
            knee_x = thigh_x + int(cur_sway * 0.15 * b)
            knee_r = max(3, int(0.28 * b))
            pygame.draw.circle(screen, p["armor_shadow"],
                             (knee_x + 1, knee_y + 1), knee_r + 2)
            pygame.draw.circle(screen, p["armor_dark"],
                             (knee_x, knee_y), knee_r + 1)
            pygame.draw.circle(screen, p["armor"],
                             (knee_x, knee_y), knee_r)

            # 무릎 LED 링
            for i in range(6):
                angle = t * 2 + i * math.pi / 3
                lx = knee_x + int(_cos(angle) * knee_r * 0.6)
                ly = knee_y + int(_sin(angle) * knee_r * 0.6)
                led_a = int(80 + 60 * _sin(t * 3 + i))
                led_s = self._get_surface(6, 6)
                pygame.draw.circle(led_s, (*p["led_cyan"], led_a), (3, 3), 2)
                screen.blit(led_s, (lx - 3, ly - 3),
                           special_flags=pygame.BLEND_ADD)
            pygame.draw.circle(screen, p["joint"], (knee_x, knee_y),
                             max(2, int(0.14 * b)))

            # 정강이 (프레임 + 장갑)
            shin_x = knee_x + leg_sway_x
            shin_y = knee_y + int(1.1 * b) - int(leg_lift_y * 0.3)
            # 피스톤 (뒤쪽 보강)
            pygame.draw.line(screen, p["joint_dark"],
                           (knee_x + side * int(0.12 * b),
                            knee_y + int(0.2 * b)),
                           (shin_x + side * int(0.08 * b),
                            shin_y - int(0.15 * b)),
                           max(2, int(0.06 * b)))
            # 메인 정강이
            pygame.draw.line(screen, p["armor_shadow"],
                           (knee_x + 1, knee_y + int(0.15 * b) + 1),
                           (shin_x + 1, shin_y + 1),
                           max(3, int(0.45 * b)))
            pygame.draw.line(screen, p["armor_dark"],
                           (knee_x, knee_y + int(0.15 * b)),
                           (shin_x, shin_y),
                           max(3, int(0.42 * b)))
            pygame.draw.line(screen, p["armor"],
                           (knee_x, knee_y + int(0.15 * b)),
                           (shin_x, shin_y),
                           max(2, int(0.3 * b)))

            # 부츠 (중장갑)
            boot_w = max(4, int(0.7 * b))
            boot_h = max(3, int(0.45 * b))
            boot_rect = pygame.Rect(shin_x - boot_w // 2,
                                   shin_y - int(0.05 * b),
                                   boot_w, boot_h)
            pygame.draw.rect(screen, p["armor_shadow"],
                           boot_rect.inflate(3, 3), border_radius=3)
            pygame.draw.rect(screen, p["armor_dark"],
                           boot_rect.inflate(1, 1), border_radius=3)
            pygame.draw.rect(screen, p["armor"], boot_rect, border_radius=3)
            pygame.draw.rect(screen, p["armor_light"],
                           boot_rect.inflate(-int(0.12 * b), -int(0.1 * b)),
                           border_radius=2)

            # 발끝 금속판
            toe_w = boot_w - int(0.1 * b)
            toe_h = max(2, int(0.15 * b))
            pygame.draw.rect(screen, p["armor_mid"],
                           (boot_rect.left + int(0.05 * b),
                            boot_rect.bottom - toe_h,
                            toe_w, toe_h), border_radius=2)
            # 부츠 볼트
            pygame.draw.circle(screen, p["joint"],
                             (boot_rect.centerx - int(0.12 * b),
                              boot_rect.centery),
                             max(1, int(0.04 * b)))
            pygame.draw.circle(screen, p["joint"],
                             (boot_rect.centerx + int(0.12 * b),
                              boot_rect.centery),
                             max(1, int(0.04 * b)))

        # === 몸통 (중장갑 흉부 + 리액터 코어) ===
        chest_w, chest_h = int(3.0 * b), int(2.3 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2 + lean_offset,
                                torso_y - int(0.4 * b),
                                chest_w, chest_h)

        # 장갑판 베이스
        pygame.draw.rect(screen, p["armor_shadow"],
                        chest_rect.inflate(3, 3), border_radius=int(0.4 * b))
        pygame.draw.rect(screen, p["armor_dark"],
                        chest_rect.inflate(1, 1), border_radius=int(0.38 * b))
        pygame.draw.rect(screen, p["armor"], chest_rect,
                        border_radius=int(0.35 * b))

        # 중앙 장갑판 경계선
        pygame.draw.line(screen, p["armor_shadow"],
                        (chest_rect.centerx, chest_rect.top + int(0.1 * b)),
                        (chest_rect.centerx, chest_rect.bottom - int(0.1 * b)),
                        2)

        # 좌우 장갑판 하이라이트
        for side in [-1, 1]:
            plate_x = chest_rect.centerx + side * int(0.5 * b)
            plate_w = int(0.8 * b)
            plate_h = int(1.4 * b)
            plate_rect = pygame.Rect(plate_x - plate_w // 2,
                                   chest_rect.centery - plate_h // 2,
                                   plate_w, plate_h)
            pygame.draw.rect(screen, p["armor_mid"],
                           plate_rect, border_radius=3)
            pygame.draw.rect(screen, p["armor_light"],
                           plate_rect.inflate(-int(0.1 * b), -int(0.1 * b)),
                           border_radius=2)

        # 리액터 코어 (중앙 원형 에너지 코어)
        reactor_cx = chest_rect.centerx
        reactor_cy = chest_rect.centery - int(0.1 * b)
        reactor_r = max(4, int(0.38 * b))

        # 리액터 외부 링
        pygame.draw.circle(screen, p["armor_shadow"],
                         (reactor_cx, reactor_cy), reactor_r + 3)
        pygame.draw.circle(screen, p["frame_dark"],
                         (reactor_cx, reactor_cy), reactor_r + 2)
        pygame.draw.circle(screen, p["frame"],
                         (reactor_cx, reactor_cy), reactor_r)

        # 리액터 에너지 글로우
        glow_r = max(3, int(reactor_r * 0.85))
        glow_surf = self._get_surface(reactor_r * 4, reactor_r * 4)
        glow_center = (reactor_r * 2, reactor_r * 2)
        glow_alpha = int(120 + 100 * reactor_pulse)
        pygame.draw.circle(glow_surf,
                         (*p["reactor_blue"], glow_alpha),
                         glow_center, glow_r)
        pygame.draw.circle(glow_surf,
                         (*p["reactor_glow"], int(glow_alpha * 0.7)),
                         glow_center, int(glow_r * 0.6))
        pygame.draw.circle(glow_surf,
                         (*p["reactor_white"], int(glow_alpha * 0.4)),
                         glow_center, int(glow_r * 0.3))
        screen.blit(glow_surf,
                   (reactor_cx - reactor_r * 2, reactor_cy - reactor_r * 2),
                   special_flags=pygame.BLEND_ADD)

        # 리액터 삼각형 에너지 패턴
        for i in range(3):
            angle = t * 1.5 + i * math.pi * 2 / 3
            tx = reactor_cx + int(_cos(angle) * reactor_r * 0.5)
            ty = reactor_cy + int(_sin(angle) * reactor_r * 0.5)
            pygame.draw.circle(screen, p["reactor_white"], (tx, ty),
                             max(1, int(0.05 * b)))

        # 장갑 모서리 볼트
        for corner_x, corner_y in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
            bx = chest_rect.centerx + corner_x * int(1.15 * b)
            by = chest_rect.centery + corner_y * int(0.75 * b)
            pygame.draw.circle(screen, p["joint_dark"], (bx, by),
                             max(2, int(0.07 * b)))
            pygame.draw.circle(screen, p["joint"], (bx - 1, by - 1),
                             max(1, int(0.05 * b)))

        # 내부 배선 (리액터 → 어깨)
        for side in [-1, 1]:
            wire_start = (reactor_cx + side * int(0.3 * b), reactor_cy)
            wire_end = (cx + side * int(1.3 * b) + lean_offset,
                       torso_y - int(0.1 * b))
            wire_mid = ((wire_start[0] + wire_end[0]) // 2,
                       wire_start[1] - int(0.15 * b))
            pygame.draw.line(screen, p["wire_blue"],
                           wire_start, wire_mid, max(1, int(0.03 * b)))
            pygame.draw.line(screen, p["wire_blue"],
                           wire_mid, wire_end, max(1, int(0.03 * b)))

        # 허리 장갑 벨트
        belt_w = int(2.5 * b)
        belt_h = int(0.5 * b)
        belt_rect = pygame.Rect(cx - belt_w // 2 + lean_offset,
                               chest_rect.bottom - int(0.1 * b),
                               belt_w, belt_h)
        pygame.draw.rect(screen, p["armor_shadow"],
                        belt_rect.inflate(2, 2), border_radius=3)
        pygame.draw.rect(screen, p["armor_dark"],
                        belt_rect, border_radius=3)
        pygame.draw.rect(screen, p["armor"],
                        belt_rect.inflate(-int(0.08 * b), -int(0.06 * b)),
                        border_radius=2)

        # 벨트 LED 스트라이프
        for i in range(5):
            led_x = belt_rect.left + int(0.2 * b) + i * int(0.42 * b)
            led_y = belt_rect.centery
            led_a_val = int(80 + 80 * _sin(t * 4 + i * 0.8))
            led_surf = self._get_surface(6, 6)
            pygame.draw.circle(led_surf,
                             (*p["led_cyan"], led_a_val), (3, 3), 2)
            screen.blit(led_surf, (led_x - 3, led_y - 3),
                       special_flags=pygame.BLEND_ADD)

        # === 어깨 (중장갑 어깨 패드) ===
        for side in [-1, 1]:
            s_bob = int(shoulder_bob * 0.3 * b)
            shoulder_cx = cx + side * int(1.45 * b) + lean_offset
            shoulder_cy = torso_y - int(0.3 * b) + s_bob

            # 어깨 장갑판
            sp_w, sp_h = int(1.2 * b), int(0.95 * b)
            sp_rect = pygame.Rect(shoulder_cx - sp_w // 2,
                                 shoulder_cy - sp_h // 2,
                                 sp_w, sp_h)
            pygame.draw.rect(screen, p["armor_shadow"],
                           sp_rect.inflate(3, 3), border_radius=5)
            pygame.draw.rect(screen, p["armor_dark"],
                           sp_rect.inflate(1, 1), border_radius=4)
            pygame.draw.rect(screen, p["armor"],
                           sp_rect, border_radius=4)
            pygame.draw.rect(screen, p["armor_light"],
                           sp_rect.inflate(-int(0.15 * b), -int(0.12 * b)),
                           border_radius=3)

            # 어깨 LED 스트라이프
            stripe_y = sp_rect.centery
            pygame.draw.line(screen, p["led_cyan_dim"],
                           (sp_rect.left + int(0.1 * b), stripe_y),
                           (sp_rect.right - int(0.1 * b), stripe_y),
                           max(2, int(0.06 * b)))
            stripe_surf = self._get_surface(sp_w, 8)
            stripe_alpha = int(50 + 40 * led_pulse)
            pygame.draw.line(stripe_surf,
                           (*p["led_cyan"], stripe_alpha),
                           (int(0.1 * b), 4),
                           (sp_w - int(0.1 * b), 4),
                           max(2, int(0.08 * b)))
            screen.blit(stripe_surf, (sp_rect.left, stripe_y - 4),
                       special_flags=pygame.BLEND_ADD)

            # 어깨 볼트
            for corner in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
                rx = shoulder_cx + corner[0] * int(0.4 * b)
                ry = shoulder_cy + corner[1] * int(0.3 * b)
                pygame.draw.circle(screen, p["joint_dark"], (rx, ry),
                                 max(2, int(0.06 * b)))
                pygame.draw.circle(screen, p["joint"], (rx - 1, ry - 1),
                                 max(1, int(0.04 * b)))

        # === 팔 (왼팔: 폭탄 손 / 오른팔: 기관포) ===
        for side in [-1, 1]:
            s_bob_offset = int(shoulder_bob * 0.3 * b)
            shoulder = (cx + side * int(1.5 * b) + lean_offset,
                       torso_y + int(0.25 * b) + s_bob_offset)

            # 오른팔(기관포) 공 타격 시 안쪽으로 휘두르기 (쿠로카게 스타일)
            if side == 1 and weapon_swing != 0:
                # 오른팔(기관포) 공 타격 시 안쪽으로 휘두르기 (쿠로카게 스타일)
                swing_x = int(weapon_swing * 4.0 * b)
                swing_y = int(abs(weapon_swing) * 1.5 * b)
                elbow = (shoulder[0] + int(0.5 * b) + swing_x,
                        torso_y + int(0.95 * b) - swing_y)
                wrist = (elbow[0] + int(0.4 * b) + int(swing_x * 0.6),
                        torso_y + int(1.6 * b) - int(swing_y * 0.6))
            else:
                elbow = (shoulder[0] + side * int(0.5 * b),
                        torso_y + int(0.95 * b))
                wrist = (elbow[0] + side * int(0.4 * b),
                        torso_y + int(1.6 * b))

            # 상완 (장갑판)
            pygame.draw.line(screen, p["armor_shadow"],
                           (shoulder[0] + 2, shoulder[1] + 2),
                           (elbow[0] + 2, elbow[1] + 2),
                           max(4, int(0.6 * b)))
            pygame.draw.line(screen, p["armor_dark"],
                           shoulder, elbow, max(4, int(0.58 * b)))
            pygame.draw.line(screen, p["armor"],
                           shoulder, elbow, max(3, int(0.42 * b)))

            # 피스톤 링 (상완 장식)
            for i in range(2):
                ring_ratio = (i + 1) / 3
                ring_x = shoulder[0] + int(
                    (elbow[0] - shoulder[0]) * ring_ratio)
                ring_y = shoulder[1] + int(
                    (elbow[1] - shoulder[1]) * ring_ratio)
                pygame.draw.circle(screen, p["joint_dark"],
                                 (ring_x, ring_y), max(2, int(0.13 * b)))

            # 팔꿈치 관절
            pygame.draw.circle(screen, p["joint_dark"],
                             (elbow[0] + 1, elbow[1] + 1),
                             max(3, int(0.28 * b)))
            pygame.draw.circle(screen, p["joint"],
                             elbow, max(3, int(0.26 * b)))
            pygame.draw.circle(screen, p["joint_light"],
                             elbow, max(2, int(0.16 * b)))
            # 팔꿈치 톱니
            for i in range(6):
                angle = t * 2 * side + i * math.pi / 3
                jx = elbow[0] + int(_cos(angle) * 0.2 * b)
                jy = elbow[1] + int(_sin(angle) * 0.2 * b)
                pygame.draw.circle(screen, p["joint"], (jx, jy),
                                 max(1, int(0.04 * b)))

            # 전완
            pygame.draw.line(screen, p["armor_shadow"],
                           (elbow[0] + 1, elbow[1] + 1),
                           (wrist[0] + 1, wrist[1] + 1),
                           max(3, int(0.55 * b)))
            pygame.draw.line(screen, p["armor_dark"],
                           elbow, wrist, max(3, int(0.52 * b)))
            pygame.draw.line(screen, p["armor"],
                           elbow, wrist, max(2, int(0.38 * b)))
            # 전완 플레이트
            for i in range(2):
                plate_ratio = (i + 1) / 3
                plate_x = elbow[0] + int(
                    (wrist[0] - elbow[0]) * plate_ratio)
                plate_y = elbow[1] + int(
                    (wrist[1] - elbow[1]) * plate_ratio)
                pygame.draw.circle(screen, p["joint"],
                                 (plate_x, plate_y), max(2, int(0.1 * b)))

            if side == -1:
                # === 왼팔 - 폭탄 손 ===
                # 기계 손
                pygame.draw.circle(screen, p["armor_dark"],
                    (wrist[0] + 1, wrist[1] + 1), max(3, int(0.32 * b)))
                pygame.draw.circle(screen, p["armor"],
                    wrist, max(3, int(0.3 * b)))
                pygame.draw.circle(screen, p["armor_light"],
                    (wrist[0] - 1, wrist[1] - 1), max(2, int(0.18 * b)))
                # 기계 손가락 (폭탄 감싸는 형태)
                for fi in range(3):
                    finger_angle = 0.8 + fi * 0.35
                    flen = int(0.25 * b)
                    fx1 = wrist[0] - int(_cos(finger_angle) * 0.15 * b)
                    fy1 = (wrist[1]
                           + int(_sin(finger_angle) * 0.12 * b)
                           + int(0.1 * b))
                    fx2 = fx1 - int(_cos(finger_angle + 0.3) * flen)
                    fy2 = fy1 + int(flen * 0.5)
                    pygame.draw.line(screen, p["armor_dark"],
                        (wrist[0], wrist[1] + int(0.06 * b)),
                        (fx1, fy1), max(2, int(0.08 * b)))
                    pygame.draw.line(screen, p["armor"],
                        (fx1, fy1), (fx2, fy2), max(1, int(0.06 * b)))
                    pygame.draw.circle(screen, p["joint"],
                        (fx1, fy1), max(1, int(0.03 * b)))

                # 폭탄 (둥근 검은 폭탄 + 도화선 + 불꽃)
                bomb_cx = wrist[0] - int(0.15 * b)
                bomb_cy = wrist[1] + int(0.5 * b)
                bomb_r = max(4, int(0.4 * b))

                # 폭탄 본체
                pygame.draw.circle(screen, p["bomb_body"],
                    (bomb_cx + 1, bomb_cy + 1), bomb_r + 1)
                pygame.draw.circle(screen, p["bomb_body"],
                    (bomb_cx, bomb_cy), bomb_r)
                pygame.draw.circle(screen, p["bomb_highlight"],
                    (bomb_cx - int(0.08 * b), bomb_cy - int(0.08 * b)),
                    int(bomb_r * 0.6))
                # 반사광
                pygame.draw.circle(screen, (100, 95, 85),
                    (bomb_cx - int(0.12 * b), bomb_cy - int(0.15 * b)),
                    max(1, int(0.08 * b)))

                # 도화선
                fuse_start = (bomb_cx,
                             bomb_cy - bomb_r + int(0.05 * b))
                fuse_mid = (bomb_cx + int(0.15 * b),
                           bomb_cy - bomb_r - int(0.2 * b))
                fuse_end = (bomb_cx + int(0.08 * b),
                           bomb_cy - bomb_r - int(0.4 * b))
                pygame.draw.line(screen, p["bomb_fuse"],
                    fuse_start, fuse_mid, max(2, int(0.06 * b)))
                pygame.draw.line(screen, p["bomb_fuse"],
                    fuse_mid, fuse_end, max(2, int(0.05 * b)))

                # 불꽃 (도화선 끝 - 깜빡이는 스파크)
                spark_x, spark_y = fuse_end
                spark_r = max(2, int(0.12 * b))
                spark_surf = self._get_surface(spark_r * 4, spark_r * 4)
                spark_alpha = int(150 + 100 * _sin(t * 8))
                pygame.draw.circle(spark_surf,
                    (*p["bomb_glow"], spark_alpha),
                    (spark_r * 2, spark_r * 2), spark_r)
                pygame.draw.circle(spark_surf,
                    (*p["bomb_spark"], int(spark_alpha * 0.7)),
                    (spark_r * 2, spark_r * 2), int(spark_r * 0.5))
                screen.blit(spark_surf,
                    (spark_x - spark_r * 2, spark_y - spark_r * 2),
                    special_flags=pygame.BLEND_ADD)
                # 불꽃 코어
                pygame.draw.circle(screen, p["bomb_spark"],
                    (spark_x, spark_y), max(1, int(0.06 * b)))
                pygame.draw.circle(screen, (255, 255, 200),
                    (spark_x, spark_y), max(1, int(0.03 * b)))

                # 폭탄 위험 X 표시
                pygame.draw.line(screen, p["bomb_fuse"],
                    (bomb_cx - int(0.12 * b), bomb_cy - int(0.12 * b)),
                    (bomb_cx + int(0.12 * b), bomb_cy + int(0.12 * b)),
                    max(1, int(0.03 * b)))
                pygame.draw.line(screen, p["bomb_fuse"],
                    (bomb_cx + int(0.12 * b), bomb_cy - int(0.12 * b)),
                    (bomb_cx - int(0.12 * b), bomb_cy + int(0.12 * b)),
                    max(1, int(0.03 * b)))
            else:
                # === 오른팔 - 기관포 (개틀링 건) ===
                # 기관포 마운트 (견착 시 어깨 장착 / 평상시 손목 장착)
                mount_cx = wrist[0]
                mount_cy = wrist[1]
                mount_r = max(3, int(0.32 * b))
                pygame.draw.circle(screen, p["cannon_dark"],
                    (mount_cx + 1, mount_cy + 1), mount_r + 1)
                pygame.draw.circle(screen, p["cannon_mid"],
                    (mount_cx, mount_cy), mount_r)
                pygame.draw.circle(screen, p["cannon_light"],
                    (mount_cx, mount_cy), int(mount_r * 0.7))

                # 기관포 외부 배럴 가드
                guard_y = mount_cy + int(0.15 * b)
                guard_w = int(0.55 * b)
                guard_h = int(0.65 * b)
                guard_rect = pygame.Rect(mount_cx - guard_w // 2,
                    guard_y, guard_w, guard_h)
                pygame.draw.rect(screen, p["cannon_dark"],
                    guard_rect.inflate(2, 2), border_radius=3)
                pygame.draw.rect(screen, p["cannon_mid"],
                    guard_rect, border_radius=3)
                pygame.draw.rect(screen, p["cannon_light"],
                    guard_rect.inflate(-int(0.08 * b), -int(0.06 * b)),
                    border_radius=2)
                # 환기 슬릿
                for i in range(3):
                    slit_y = (guard_rect.top + int(0.12 * b)
                             + i * int(0.16 * b))
                    pygame.draw.line(screen, p["cannon_barrel"],
                        (guard_rect.left + int(0.06 * b), slit_y),
                        (guard_rect.right - int(0.06 * b), slit_y),
                        max(1, int(0.03 * b)))

                # 기관포 배럴 (3개 총열 - 회전)
                barrel_len = int(0.55 * b)
                barrel_spread = int(0.12 * b)
                for i in range(3):
                    angle = barrel_spin + i * math.pi * 2 / 3
                    bx_off = int(_cos(angle) * barrel_spread)
                    by_off = int(_sin(angle) * barrel_spread * 0.5)
                    bx1 = mount_cx + bx_off
                    by1 = guard_rect.bottom - int(0.05 * b) + by_off
                    bx2 = mount_cx + bx_off
                    by2 = guard_rect.bottom + barrel_len + by_off
                    pygame.draw.line(screen, p["cannon_barrel"],
                        (bx1, by1), (bx2, by2),
                        max(2, int(0.09 * b)))
                    # 총구
                    pygame.draw.circle(screen, p["cannon_dark"],
                        (bx2, by2), max(1, int(0.05 * b)))

                # 배럴 회전부 LED (빨간색 - 발사 시 더 밝게)
                led_surf_gun = self._get_surface(8, 8)
                gun_led_a = int((120 + 100 * _sin(t * 15)) if gatling_firing else (60 + 50 * _sin(t * 5)))
                pygame.draw.circle(led_surf_gun,
                    (*p["led_red"], min(255, gun_led_a)), (4, 4), 3)
                screen.blit(led_surf_gun,
                    (mount_cx - 4, mount_cy - mount_r - 2),
                    special_flags=pygame.BLEND_ADD)

                # 🔫 개틀링 버스트 발사 시 총구 화염 이펙트
                if gatling_firing:
                    flash_sz = int(0.4 * b + 0.15 * b * _sin(t * 30))
                    flash_cx = mount_cx
                    flash_cy = guard_rect.bottom + barrel_len + int(0.15 * b)
                    # 노랑-주황 총구 화염
                    fl_surf = self._get_surface(flash_sz * 3, flash_sz * 3)
                    fl_a = int(140 + 80 * _sin(t * 25))
                    pygame.draw.circle(fl_surf, (255, 200, 50, min(255, fl_a)),
                        (flash_sz * 3 // 2, flash_sz * 3 // 2), flash_sz)
                    pygame.draw.circle(fl_surf, (255, 120, 20, min(255, fl_a - 30)),
                        (flash_sz * 3 // 2, flash_sz * 3 // 2), max(1, flash_sz * 2 // 3))
                    screen.blit(fl_surf,
                        (flash_cx - flash_sz * 3 // 2, flash_cy - flash_sz * 3 // 2),
                        special_flags=pygame.BLEND_ADD)

        # === 목 (기계 프레임 연결부) ===
        neck_bot_w = int(0.8 * b)
        neck_top_w = int(0.6 * b)
        neck_top_y = torso_y - int(1.1 * b)
        neck_bot_y = torso_y - int(0.3 * b)
        neck_cx = cx + lean_offset
        neck_pts = [
            (neck_cx - neck_bot_w // 2, neck_bot_y),
            (neck_cx + neck_bot_w // 2, neck_bot_y),
            (neck_cx + neck_top_w // 2, neck_top_y),
            (neck_cx - neck_top_w // 2, neck_top_y),
        ]
        pygame.draw.polygon(screen, p["frame"], neck_pts)
        pygame.draw.polygon(screen, p["frame_light"], neck_pts, 1)
        # 중앙 프레임 라인
        pygame.draw.line(screen, p["joint"],
                        (neck_cx, neck_top_y + 2),
                        (neck_cx, neck_bot_y - 2), max(1, int(0.08 * b)))

        # === 머리 (로봇 헤드 - 바이저 + 안테나) ===
        head_y = torso_y - int(3.1 * b)
        head_w, head_h = int(2.0 * b), int(2.0 * b)
        head_rect = pygame.Rect(cx - head_w // 2 + lean_offset,
                               head_y, head_w, head_h)

        if show_back:
            # 뒷모습 - 후두부 장갑
            pygame.draw.rect(screen, p["armor_shadow"],
                head_rect.inflate(2, 2), border_radius=int(0.5 * b))
            pygame.draw.rect(screen, p["armor_dark"],
                head_rect, border_radius=int(0.45 * b))
            pygame.draw.rect(screen, p["armor"],
                head_rect.inflate(-int(0.15 * b), -int(0.12 * b)),
                border_radius=int(0.4 * b))
            # 후두부 패널 라인
            pygame.draw.line(screen, p["armor_shadow"],
                (head_rect.centerx, head_rect.top + int(0.2 * b)),
                (head_rect.centerx, head_rect.bottom - int(0.15 * b)), 2)
            # 배기구
            vent_cx = head_rect.centerx
            vent_y = head_rect.centery + int(0.15 * b)
            for i in range(3):
                vent_off = (i - 1) * int(0.25 * b)
                pygame.draw.rect(screen, p["frame_dark"],
                    (vent_cx + vent_off - int(0.08 * b), vent_y,
                     int(0.16 * b), int(0.3 * b)), border_radius=1)
            # 뒤쪽 볼트
            for sx in [-1, 1]:
                pygame.draw.circle(screen, p["joint"],
                    (head_rect.centerx + sx * int(0.55 * b),
                     head_rect.centery), max(1, int(0.05 * b)))
            # 안테나
            ant_x = head_rect.centerx
            ant_y = head_rect.top
            pygame.draw.line(screen, p["antenna"],
                (ant_x, ant_y), (ant_x, ant_y - int(0.6 * b)),
                max(2, int(0.06 * b)))
            pygame.draw.circle(screen, p["led_red"],
                (ant_x, ant_y - int(0.6 * b)), max(2, int(0.08 * b)))
        else:
            # === 정면 - 로봇 페이스 ===
            # 머리 외형
            pygame.draw.rect(screen, p["armor_shadow"],
                head_rect.inflate(3, 3), border_radius=int(0.5 * b))
            pygame.draw.rect(screen, p["armor_dark"],
                head_rect.inflate(1, 1), border_radius=int(0.45 * b))
            pygame.draw.rect(screen, p["armor"],
                head_rect, border_radius=int(0.42 * b))

            # 얼굴 내부 (어두운 프레임)
            face_w = int(1.5 * b)
            face_h = int(1.2 * b)
            face_rect = pygame.Rect(
                head_rect.centerx - face_w // 2,
                head_rect.centery - face_h // 2 + int(0.1 * b),
                face_w, face_h)
            pygame.draw.rect(screen, p["frame_dark"],
                face_rect, border_radius=int(0.2 * b))
            pygame.draw.rect(screen, p["frame"],
                face_rect.inflate(-3, -3), border_radius=int(0.18 * b))

            # 바이저 (가로로 긴 LED 눈)
            visor_w = int(1.2 * b)
            visor_h = max(3, int(0.3 * b))
            visor_rect = pygame.Rect(
                face_rect.centerx - visor_w // 2,
                face_rect.centery - visor_h // 2 - int(0.12 * b),
                visor_w, visor_h)
            # 바이저 글로우
            visor_surf = self._get_surface(visor_w + 8, visor_h + 8)
            visor_alpha = int(140 + 80 * led_pulse)
            pygame.draw.rect(visor_surf,
                (*p["visor"], visor_alpha),
                (4, 4, visor_w, visor_h), border_radius=2)
            pygame.draw.rect(visor_surf,
                (*p["visor_glow"], int(visor_alpha * 0.5)),
                (6, 5, visor_w - 4, visor_h - 2), border_radius=1)
            screen.blit(visor_surf,
                (visor_rect.left - 4, visor_rect.top - 4),
                special_flags=pygame.BLEND_ADD)
            # 바이저 본체
            pygame.draw.rect(screen, p["visor_dim"],
                visor_rect, border_radius=2)
            pygame.draw.rect(screen, p["visor"],
                visor_rect.inflate(-2, -2), border_radius=2)
            # 눈 포인트 (바이저 안에 2개)
            for eye_side in [-1, 1]:
                eye_x = visor_rect.centerx + eye_side * int(0.22 * b)
                eye_y = visor_rect.centery
                pygame.draw.circle(screen, p["visor_glow"],
                    (eye_x, eye_y), max(2, int(0.08 * b)))
                pygame.draw.circle(screen, (255, 255, 255),
                    (eye_x, eye_y), max(1, int(0.04 * b)))

            # 입 (격자형 스피커)
            mouth_y = face_rect.centery + int(0.22 * b)
            mouth_w = int(0.6 * b)
            mouth_h = int(0.25 * b)
            mouth_rect = pygame.Rect(
                face_rect.centerx - mouth_w // 2,
                mouth_y, mouth_w, mouth_h)
            pygame.draw.rect(screen, p["frame_dark"],
                mouth_rect, border_radius=2)
            # 격자
            grid_count = max(3, int(mouth_w / max(1, int(0.1 * b))))
            for i in range(grid_count):
                gx = (mouth_rect.left + int(0.04 * b)
                     + i * max(1, int(mouth_w / grid_count)))
                pygame.draw.line(screen, p["joint_dark"],
                    (gx, mouth_rect.top + 2),
                    (gx, mouth_rect.bottom - 2), 1)

            # 볼 볼트
            for s in [-1, 1]:
                cheek_x = head_rect.centerx + s * int(0.7 * b)
                cheek_y = head_rect.centery + int(0.1 * b)
                pygame.draw.circle(screen, p["joint_dark"],
                    (cheek_x, cheek_y), max(2, int(0.06 * b)))
                pygame.draw.circle(screen, p["joint"],
                    (cheek_x - 1, cheek_y - 1), max(1, int(0.04 * b)))

            # 안테나
            ant_x = head_rect.centerx
            ant_base_y = head_rect.top + int(0.05 * b)
            ant_top_y = head_rect.top - int(0.55 * b)
            # 기둥
            pygame.draw.line(screen, p["antenna"],
                (ant_x, ant_base_y), (ant_x, ant_top_y),
                max(2, int(0.06 * b)))
            pygame.draw.circle(screen, p["joint"],
                (ant_x, ant_base_y), max(2, int(0.08 * b)))
            # 안테나 LED (빨간 점멸)
            ant_led_r = max(2, int(0.1 * b))
            ant_led_alpha = int(120 + 120 * _sin(t * 6))
            ant_led_surf = self._get_surface(ant_led_r * 4, ant_led_r * 4)
            pygame.draw.circle(ant_led_surf,
                (*p["led_red"], ant_led_alpha),
                (ant_led_r * 2, ant_led_r * 2), ant_led_r)
            screen.blit(ant_led_surf,
                (ant_x - ant_led_r * 2, ant_top_y - ant_led_r * 2),
                special_flags=pygame.BLEND_ADD)
            pygame.draw.circle(screen, p["led_red"],
                (ant_x, ant_top_y), max(2, int(0.07 * b)))

            # 머리 측면 라인
            for s in [-1, 1]:
                line_x = head_rect.centerx + s * int(0.75 * b)
                pygame.draw.line(screen, p["armor_shadow"],
                    (line_x, head_rect.top + int(0.3 * b)),
                    (line_x, head_rect.bottom - int(0.2 * b)), 1)

        # === 스파크 이펙트 (관절에서 간헐적으로) ===
        if _sin(t * 7) > 0.85:
            spark_positions = [
                (cx + lean_offset + int(0.5 * b),
                 torso_y + int(0.95 * b)),
                (cx + lean_offset - int(0.5 * b),
                 torso_y + int(0.95 * b)),
            ]
            for sp_x, sp_y in spark_positions:
                for i in range(3):
                    sp_angle = t * 15 + i * 2.1
                    sp_len = (int(0.15 * b)
                             + int(_sin(t * 20 + i) * 0.08 * b))
                    spx2 = sp_x + int(_cos(sp_angle) * sp_len)
                    spy2 = sp_y + int(_sin(sp_angle) * sp_len)
                    sp_surf = self._get_surface(4, 4)
                    pygame.draw.line(sp_surf,
                        (*p["bomb_spark"], 180),
                        (2, 0), (2, 3), 1)
                    screen.blit(sp_surf, (spx2 - 2, spy2 - 2),
                        special_flags=pygame.BLEND_ADD)

    # =========================================================================
    # 안드로이드 탱크 변신 시스템
    # =========================================================================
    def _draw_android_tank_transform(self, screen, cx, torso_y, b, p, t,
                                      progress, barrel_spin, is_firing,
                                      show_back, led_pulse, reactor_pulse,
                                      lean_offset, recoil, aim_angle=None):
        """안드로이드 ↔ 탱크 변환 애니메이션 + 탱크 모드 렌더링

        progress: 0.0=안드로이드 형태, 1.0=탱크 형태
        변환 중 파츠가 해체되어 흩어졌다가 새 형태로 재조립됨
        """
        # 발사 중 미세 반동
        if is_firing and recoil:
            recoil_dir = 1 if show_back else -1
            cx += int(_sin(t * 45) * 1.2 * b * 0.08)
            torso_y += int(recoil * recoil_dir * 0.4)

        # 산개 강도 (progress 0.5일 때 최대)
        scatter = _sin(progress * math.pi) * 1.0
        # 이징 함수 (자연스러운 가감속)
        ease_p = progress * progress * (3 - 2 * progress)  # smoothstep

        # === 파츠 정의 ===
        # (android_x, android_y, tank_x, tank_y, w, h, color_key, scatter_angle)
        # 좌표는 (cx, torso_y) 기준 상대 좌표
        parts = [
            # 머리 → 포탑
            (0, -3.1*b, 0, -1.2*b, 2.0*b, 1.8*b, "armor", -1.57),
            # 흉부 → 차체 상판
            (0, 0, 0, 0.2*b, 3.0*b, 2.0*b, "armor_dark", 0),
            # 왼쪽 어깨 → 차체 좌측
            (-1.45*b, -0.3*b, -1.2*b, 0.8*b, 1.1*b, 0.9*b, "armor", 3.14),
            # 오른쪽 어깨 → 차체 우측
            (1.45*b, -0.3*b, 1.2*b, 0.8*b, 1.1*b, 0.9*b, "armor", 0),
            # 왼쪽 다리 → 왼쪽 무한궤도
            (-0.55*b, 3.0*b, -1.4*b, 2.0*b, 0.9*b, 2.5*b, "armor_shadow", 2.36),
            # 오른쪽 다리 → 오른쪽 무한궤도
            (0.55*b, 3.0*b, 1.4*b, 2.0*b, 0.9*b, 2.5*b, "armor_shadow", 0.79),
            # 왼팔 → 전면 장갑
            (-1.5*b, 1.0*b, -0.6*b, -0.5*b, 0.6*b, 1.2*b, "frame", 3.93),
            # 오른팔+기관포 → 주포
            (1.5*b, 1.0*b, 0, -2.5*b, 0.6*b, 2.0*b, "cannon_mid", -0.79),
        ]

        scatter_dist = 2.5 * b  # 최대 산개 거리

        # 변환 중이면 (0 < progress < 1) 파츠 산개 + 에너지 이펙트
        if progress < 0.98:
            # 리액터 에너지 폭발 이펙트 (변환 중)
            if scatter > 0.1:
                energy_r = int(scatter * 3.0 * b)
                energy_surf = self._get_surface(energy_r * 2, energy_r * 2)
                e_alpha = int(40 * scatter)
                pygame.draw.circle(energy_surf,
                    (*p["reactor_blue"], e_alpha),
                    (energy_r, energy_r), energy_r)
                pygame.draw.circle(energy_surf,
                    (*p["reactor_glow"], int(e_alpha * 0.6)),
                    (energy_r, energy_r), int(energy_r * 0.6))
                screen.blit(energy_surf,
                    (cx + lean_offset - energy_r,
                     torso_y + int(0.5 * b) - energy_r),
                    special_flags=pygame.BLEND_ADD)

                # 에너지 스파크
                for i in range(8):
                    spark_angle = t * 3 + i * math.pi / 4
                    spark_dist = scatter * 2.0 * b * (0.5 + 0.5 * _sin(t * 5 + i))
                    sx = cx + lean_offset + int(_cos(spark_angle) * spark_dist)
                    sy = torso_y + int(0.5 * b) + int(_sin(spark_angle) * spark_dist)
                    spark_s = self._get_surface(6, 6)
                    s_alpha = int(120 * scatter * (0.5 + 0.5 * _sin(t * 8 + i * 1.3)))
                    pygame.draw.circle(spark_s,
                        (*p["led_cyan"], min(255, s_alpha)), (3, 3), 2)
                    screen.blit(spark_s, (sx - 3, sy - 3),
                        special_flags=pygame.BLEND_ADD)

            # 파츠 산개 렌더링
            for (ax, ay, tx, ty, pw, ph, col_key, sa) in parts:
                # 위치 보간 + 산개
                ix = ax * (1 - ease_p) + tx * ease_p + _cos(sa) * scatter * scatter_dist
                iy = ay * (1 - ease_p) + ty * ease_p + _sin(sa) * scatter * scatter_dist
                # 크기 보간 (변환 중 약간 축소)
                size_scale = 1.0 - 0.3 * scatter
                fw = int(pw * size_scale)
                fh = int(ph * size_scale)

                fx = cx + lean_offset + int(ix) - fw // 2
                fy = torso_y + int(iy) - fh // 2

                # 파츠 그리기 (회전 효과 포함)
                rot = scatter * 0.5 * sa  # 산개 중 약간 회전
                part_surf = self._get_surface(fw + 4, fh + 4)
                # 그림자
                pygame.draw.rect(part_surf, p["armor_shadow"],
                    (3, 3, fw, fh), border_radius=max(2, int(0.15 * b)))
                # 본체
                pygame.draw.rect(part_surf, p[col_key],
                    (2, 2, fw, fh), border_radius=max(2, int(0.15 * b)))
                # 하이라이트
                if fw > 4 and fh > 4:
                    hl_color = tuple(min(255, c + 30) for c in p[col_key])
                    pygame.draw.rect(part_surf, hl_color,
                        (4, 4, max(1, fw - 4), max(1, fh - 4)),
                        border_radius=max(1, int(0.1 * b)))

                # LED 포인트 (각 파츠에 사이언 빛)
                led_a = int(80 + 80 * scatter * _sin(t * 6 + sa))
                led_s = self._get_surface(4, 4)
                pygame.draw.circle(led_s,
                    (*p["led_cyan"], min(255, led_a)), (2, 2), 2)
                part_surf.blit(led_s,
                    (fw // 2, fh // 2), special_flags=pygame.BLEND_ADD)

                screen.blit(part_surf, (fx - 2, fy - 2))

            # 리액터 코어 (항상 중앙에 표시)
            r_cx = cx + lean_offset
            r_cy = torso_y + int(0.5 * b * ease_p)
            r_r = max(4, int(0.4 * b))
            # 코어 글로우
            core_surf = self._get_surface(r_r * 4, r_r * 4)
            core_a = int(150 + 100 * reactor_pulse)
            pygame.draw.circle(core_surf,
                (*p["reactor_blue"], core_a),
                (r_r * 2, r_r * 2), r_r)
            pygame.draw.circle(core_surf,
                (*p["reactor_white"], int(core_a * 0.5)),
                (r_r * 2, r_r * 2), int(r_r * 0.4))
            screen.blit(core_surf,
                (r_cx - r_r * 2, r_cy - r_r * 2),
                special_flags=pygame.BLEND_ADD)
            pygame.draw.circle(screen, p["reactor_glow"],
                (r_cx, r_cy), max(2, int(r_r * 0.5)))
        else:
            # === 완전 탱크 모드 ===
            self._draw_android_tank(
                screen, cx, torso_y, b, p, t,
                barrel_spin, is_firing, show_back,
                led_pulse, reactor_pulse, lean_offset,
                aim_angle
            )

    def _draw_android_tank(self, screen, cx, torso_y, b, p, t,
                            barrel_spin, is_firing, show_back,
                            led_pulse, reactor_pulse, lean_offset,
                            aim_angle=None):
        """안드로이드 탱크 모드 렌더링 - 게틀링 발사 중 탱크 형태 (캐논 조준 회전)"""
        cx += lean_offset

        # === 무한궤도 (좌우) ===
        for side in [-1, 1]:
            tread_cx = cx + side * int(1.4 * b)
            tread_y = torso_y + int(2.0 * b)
            tread_w = int(0.9 * b)
            tread_h = int(2.5 * b)
            tread_rect = pygame.Rect(
                tread_cx - tread_w // 2, tread_y - tread_h // 2,
                tread_w, tread_h)

            # 궤도 외곽
            pygame.draw.rect(screen, p["armor_shadow"],
                tread_rect.inflate(3, 3), border_radius=int(0.2 * b))
            pygame.draw.rect(screen, p["armor_dark"],
                tread_rect.inflate(1, 1), border_radius=int(0.18 * b))
            pygame.draw.rect(screen, p["armor_shadow"],
                tread_rect, border_radius=int(0.15 * b))

            # 궤도 패턴 (움직이는 줄무늬)
            tread_offset = int(t * 30) % int(0.4 * b + 1) if b > 0 else 0
            for i in range(7):
                ty = tread_rect.top + int(0.15 * b) + i * int(0.32 * b) + tread_offset
                if tread_rect.top < ty < tread_rect.bottom - int(0.1 * b):
                    pygame.draw.line(screen, p["frame_dark"],
                        (tread_rect.left + int(0.08 * b), ty),
                        (tread_rect.right - int(0.08 * b), ty),
                        max(1, int(0.04 * b)))

            # 구동륜 (상하)
            for wy in [tread_rect.top + int(0.15 * b),
                       tread_rect.bottom - int(0.15 * b)]:
                wheel_r = max(2, int(0.18 * b))
                pygame.draw.circle(screen, p["joint_dark"],
                    (tread_cx, wy), wheel_r + 1)
                pygame.draw.circle(screen, p["joint"],
                    (tread_cx, wy), wheel_r)
                # 구동축 회전
                for i in range(4):
                    angle = barrel_spin * 2 + i * math.pi / 2
                    wx = tread_cx + int(_cos(angle) * wheel_r * 0.5)
                    wy2 = wy + int(_sin(angle) * wheel_r * 0.5)
                    pygame.draw.circle(screen, p["joint_light"],
                        (wx, wy2), max(1, int(0.04 * b)))

        # === 차체 (메인 헐) ===
        hull_w = int(3.2 * b)
        hull_h = int(2.2 * b)
        hull_rect = pygame.Rect(
            cx - hull_w // 2, torso_y - int(0.2 * b),
            hull_w, hull_h)

        # 헐 외곽
        pygame.draw.rect(screen, p["armor_shadow"],
            hull_rect.inflate(3, 3), border_radius=int(0.3 * b))
        pygame.draw.rect(screen, p["armor_dark"],
            hull_rect.inflate(1, 1), border_radius=int(0.25 * b))
        pygame.draw.rect(screen, p["armor"],
            hull_rect, border_radius=int(0.2 * b))

        # 전면/후면 경사 장갑판
        for vy, c in [(hull_rect.top + int(0.15 * b), p["armor_mid"]),
                       (hull_rect.bottom - int(0.15 * b), p["armor_dark"])]:
            pygame.draw.line(screen, c,
                (hull_rect.left + int(0.2 * b), vy),
                (hull_rect.right - int(0.2 * b), vy),
                max(2, int(0.06 * b)))

        # 장갑판 볼트
        for corner_x, corner_y in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
            bx = cx + corner_x * int(1.2 * b)
            by = hull_rect.centery + corner_y * int(0.6 * b)
            pygame.draw.circle(screen, p["joint_dark"], (bx, by),
                max(2, int(0.06 * b)))
            pygame.draw.circle(screen, p["joint"], (bx - 1, by - 1),
                max(1, int(0.04 * b)))

        # 측면 장갑판 (좌우)
        for side in [-1, 1]:
            side_rect = pygame.Rect(
                cx + side * int(0.8 * b) - int(0.4 * b),
                hull_rect.centery - int(0.5 * b),
                int(0.8 * b), int(1.0 * b))
            pygame.draw.rect(screen, p["armor_mid"],
                side_rect, border_radius=3)
            pygame.draw.rect(screen, p["armor_light"],
                side_rect.inflate(-int(0.1 * b), -int(0.1 * b)),
                border_radius=2)

        # 리액터 코어 (차체 중앙)
        reactor_cx = cx
        reactor_cy = hull_rect.centery
        reactor_r = max(4, int(0.35 * b))

        pygame.draw.circle(screen, p["frame_dark"],
            (reactor_cx, reactor_cy), reactor_r + 2)
        pygame.draw.circle(screen, p["frame"],
            (reactor_cx, reactor_cy), reactor_r)

        # 리액터 글로우
        glow_r = max(3, int(reactor_r * 0.85))
        glow_surf = self._get_surface(reactor_r * 4, reactor_r * 4)
        glow_a = int(120 + 100 * reactor_pulse)
        pygame.draw.circle(glow_surf,
            (*p["reactor_blue"], glow_a),
            (reactor_r * 2, reactor_r * 2), glow_r)
        pygame.draw.circle(glow_surf,
            (*p["reactor_white"], int(glow_a * 0.4)),
            (reactor_r * 2, reactor_r * 2), int(glow_r * 0.3))
        screen.blit(glow_surf,
            (reactor_cx - reactor_r * 2, reactor_cy - reactor_r * 2),
            special_flags=pygame.BLEND_ADD)

        # LED 스트라이프 (차체)
        for i in range(4):
            led_x = hull_rect.left + int(0.3 * b) + i * int(0.65 * b)
            led_y = hull_rect.bottom - int(0.25 * b)
            led_a_val = int(60 + 60 * _sin(t * 4 + i * 0.8))
            led_surf = self._get_surface(6, 6)
            pygame.draw.circle(led_surf,
                (*p["led_cyan"], led_a_val), (3, 3), 2)
            screen.blit(led_surf, (led_x - 3, led_y - 3),
                special_flags=pygame.BLEND_ADD)

        # === 포탑 (터렛) ===
        turret_w = int(2.0 * b)
        turret_h = int(1.4 * b)
        turret_rect = pygame.Rect(
            cx - turret_w // 2, torso_y - int(1.6 * b),
            turret_w, turret_h)

        # 포탑 본체
        pygame.draw.rect(screen, p["armor_shadow"],
            turret_rect.inflate(3, 3), border_radius=int(0.25 * b))
        pygame.draw.rect(screen, p["armor_dark"],
            turret_rect.inflate(1, 1), border_radius=int(0.2 * b))
        pygame.draw.rect(screen, p["armor"],
            turret_rect, border_radius=int(0.18 * b))
        pygame.draw.rect(screen, p["armor_light"],
            turret_rect.inflate(-int(0.15 * b), -int(0.12 * b)),
            border_radius=int(0.12 * b))

        # 바이저 (포탑 전면 관측창)
        visor_w = int(1.0 * b)
        visor_h = int(0.3 * b)
        visor_y = turret_rect.centery - int(0.1 * b)
        visor_rect = pygame.Rect(
            cx - visor_w // 2, visor_y, visor_w, visor_h)
        pygame.draw.rect(screen, p["visor_dim"], visor_rect, border_radius=2)
        # 바이저 글로우
        vis_surf = self._get_surface(visor_w + 4, visor_h + 4)
        vis_a = int(80 + 60 * led_pulse)
        pygame.draw.rect(vis_surf,
            (*p["visor"], vis_a),
            (2, 2, visor_w, visor_h), border_radius=2)
        screen.blit(vis_surf,
            (visor_rect.left - 2, visor_rect.top - 2),
            special_flags=pygame.BLEND_ADD)

        # 포탑 볼트
        for corner in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
            bx = cx + corner[0] * int(0.7 * b)
            by = turret_rect.centery + corner[1] * int(0.4 * b)
            pygame.draw.circle(screen, p["joint_dark"], (bx, by),
                max(2, int(0.05 * b)))

        # 안테나
        ant_x = cx + int(0.6 * b)
        ant_y = turret_rect.top
        pygame.draw.line(screen, p["antenna"],
            (ant_x, ant_y),
            (ant_x + int(0.1 * b), ant_y - int(0.6 * b)),
            max(1, int(0.04 * b)))
        # 안테나 끝 빨간 LED
        ant_led = self._get_surface(6, 6)
        ant_a = int(120 + 120 * _sin(t * 4))
        pygame.draw.circle(ant_led,
            (*p["led_red"], min(255, ant_a)), (3, 3), 2)
        screen.blit(ant_led,
            (ant_x + int(0.1 * b) - 3, ant_y - int(0.6 * b) - 3),
            special_flags=pygame.BLEND_ADD)

        # === 주포 (개틀링 캐논) - 조준 방향으로 회전 ===
        gun_dir = -1 if show_back else 1
        default_angle = -math.pi / 2 if show_back else math.pi / 2
        _aim = aim_angle if aim_angle is not None else default_angle
        # 조준 방향 벡터
        aim_dx = _cos(_aim)
        aim_dy = _sin(_aim)
        # 수직 벡터 (포신 너비 방향)
        perp_dx = -aim_dy
        perp_dy = aim_dx

        cannon_mount_x = cx
        mount_r = max(4, int(0.35 * b))
        if gun_dir < 0:
            cannon_mount_y = turret_rect.top - int(0.1 * b)
        else:
            cannon_mount_y = turret_rect.bottom + int(0.1 * b)

        # 포 마운트 (대형 원형 - 회전축)
        pygame.draw.circle(screen, p["cannon_dark"],
            (cannon_mount_x + 1, cannon_mount_y + 1), mount_r + 2)
        pygame.draw.circle(screen, p["cannon_mid"],
            (cannon_mount_x, cannon_mount_y), mount_r)
        pygame.draw.circle(screen, p["cannon_light"],
            (cannon_mount_x, cannon_mount_y), int(mount_r * 0.6))

        # 포신 외장 (조준 방향으로 회전하는 캐논 튜브)
        tube_w = int(1.0 * b)
        tube_h = int(1.8 * b)
        tube_hw = tube_w // 2
        tube_end_x = cannon_mount_x + aim_dx * tube_h
        tube_end_y = cannon_mount_y + aim_dy * tube_h

        def _tube_poly(length, half_w):
            return [
                (int(cannon_mount_x - perp_dx * half_w),
                 int(cannon_mount_y - perp_dy * half_w)),
                (int(cannon_mount_x + perp_dx * half_w),
                 int(cannon_mount_y + perp_dy * half_w)),
                (int(cannon_mount_x + aim_dx * length + perp_dx * half_w),
                 int(cannon_mount_y + aim_dy * length + perp_dy * half_w)),
                (int(cannon_mount_x + aim_dx * length - perp_dx * half_w),
                 int(cannon_mount_y + aim_dy * length - perp_dy * half_w)),
            ]

        pygame.draw.polygon(screen, p["cannon_dark"],
            _tube_poly(tube_h, tube_hw + 2))
        pygame.draw.polygon(screen, p["cannon_mid"],
            _tube_poly(tube_h, tube_hw + 1))
        pygame.draw.polygon(screen, p["cannon_light"],
            _tube_poly(tube_h, max(1, tube_hw - int(0.05 * b))))

        # 포신 보강 링 (2개, 조준 방향 따라 배치)
        for ri in range(2):
            ring_dist = int(0.5 * b) + ri * int(0.7 * b)
            rx = cannon_mount_x + aim_dx * ring_dist
            ry = cannon_mount_y + aim_dy * ring_dist
            ring_hw = tube_hw + 2
            pygame.draw.line(screen, p["joint"],
                (int(rx - perp_dx * ring_hw), int(ry - perp_dy * ring_hw)),
                (int(rx + perp_dx * ring_hw), int(ry + perp_dy * ring_hw)),
                max(2, int(0.08 * b)))

        # 환기 슬릿 (포신 측면, 조준 방향 따라)
        for i in range(4):
            sd = int(0.3 * b) + i * int(0.35 * b)
            if 0 < sd < tube_h:
                sx = cannon_mount_x + aim_dx * sd
                sy = cannon_mount_y + aim_dy * sd
                slit_hw = tube_hw - int(0.1 * b)
                pygame.draw.line(screen, p["cannon_barrel"],
                    (int(sx - perp_dx * slit_hw), int(sy - perp_dy * slit_hw)),
                    (int(sx + perp_dx * slit_hw), int(sy + perp_dy * slit_hw)),
                    max(1, int(0.04 * b)))

        # 3연장 회전 배럴 (포신 끝에서 조준 방향으로 연장)
        barrel_len = int(1.6 * b)
        barrel_spread = int(0.2 * b)
        barrel_thick = max(2, int(0.14 * b))

        for i in range(3):
            angle = barrel_spin + i * math.pi * 2 / 3
            b_off = _cos(angle) * barrel_spread
            # 배럴 시작 (수직 방향 오프셋)
            bx1 = tube_end_x + perp_dx * b_off
            by1 = tube_end_y + perp_dy * b_off
            # 배럴 끝 (조준 방향으로 연장)
            bx2 = bx1 + aim_dx * barrel_len
            by2 = by1 + aim_dy * barrel_len
            # 배럴 그림자
            pygame.draw.line(screen, p["cannon_dark"],
                (int(bx1) + 1, int(by1) + 1),
                (int(bx2) + 1, int(by2) + 1),
                barrel_thick + 1)
            # 배럴 본체
            pygame.draw.line(screen, p["cannon_barrel"],
                (int(bx1), int(by1)), (int(bx2), int(by2)),
                barrel_thick)
            # 배럴 하이라이트 (중심선)
            pygame.draw.line(screen, p["cannon_mid"],
                (int(bx1), int(by1)), (int(bx2), int(by2)),
                max(1, barrel_thick // 2))
            # 총구 팁
            muzzle_r = max(2, int(0.08 * b))
            pygame.draw.circle(screen, p["cannon_dark"],
                (int(bx2), int(by2)), muzzle_r + 1)
            pygame.draw.circle(screen, p["cannon_mid"],
                (int(bx2), int(by2)), muzzle_r)

        # 배럴 LED (포 마운트 근처)
        led_surf_gun = self._get_surface(10, 10)
        gun_led_a = int(
            (140 + 110 * _sin(t * 15)) if is_firing
            else (60 + 50 * _sin(t * 5)))
        pygame.draw.circle(led_surf_gun,
            (*p["led_red"], min(255, gun_led_a)), (5, 5), 4)
        led_px = cannon_mount_x + aim_dx * (mount_r + 2)
        led_py = cannon_mount_y + aim_dy * (mount_r + 2)
        screen.blit(led_surf_gun,
            (int(led_px) - 5, int(led_py) - 5),
            special_flags=pygame.BLEND_ADD)

        # 🔫 발사 시 총구 화염 (대형, 조준 방향)
        if is_firing:
            muzzle_tip_x = tube_end_x + aim_dx * barrel_len
            muzzle_tip_y = tube_end_y + aim_dy * barrel_len
            flash_sz = int(0.8 * b + 0.3 * b * _sin(t * 30))
            flash_cx = muzzle_tip_x + aim_dx * int(0.15 * b)
            flash_cy = muzzle_tip_y + aim_dy * int(0.15 * b)
            fl_surf = self._get_surface(flash_sz * 3, flash_sz * 3)
            fl_a = int(180 + 70 * _sin(t * 25))
            pygame.draw.circle(fl_surf, (255, 220, 60, min(255, fl_a)),
                (flash_sz * 3 // 2, flash_sz * 3 // 2), flash_sz)
            pygame.draw.circle(fl_surf, (255, 140, 30, min(255, fl_a - 20)),
                (flash_sz * 3 // 2, flash_sz * 3 // 2),
                max(1, flash_sz * 3 // 4))
            pygame.draw.circle(fl_surf, (255, 255, 200, min(255, fl_a - 60)),
                (flash_sz * 3 // 2, flash_sz * 3 // 2),
                max(1, flash_sz // 3))
            screen.blit(fl_surf,
                (int(flash_cx) - flash_sz * 3 // 2,
                 int(flash_cy) - flash_sz * 3 // 2),
                special_flags=pygame.BLEND_ADD)

    # =========================================================================
    # 원숭이왕 - 밀림의 패왕 (야생 원숭이 왕, 금관, 긴 팔, 꼬리) [고퀄리티]
    # =========================================================================
    def _draw_monkeyking(self, screen, cx, cy, b, color, show_back, anim):
        """원숭이왕 - 밀림의 패왕 (야생 원숭이 스타일, 금 왕관, 어슬렁 걸음, 팔 휘두르기) [HD 버전]"""
        b = int(b * 1.4)
        lean = anim["lean"]
        wave = anim["wave"]
        body_bob = anim["body_bob"]
        shoulder_bob = anim.get("shoulder_bob", 0)
        left_arm_swing = anim.get("left_arm_swing", 0)
        right_arm_swing = anim.get("right_arm_swing", 0)
        weapon_swing = anim.get("weapon_swing_angle", 0)
        left_leg_sway = anim.get("left_leg_sway", 0)
        right_leg_sway = anim.get("right_leg_sway", 0)
        left_leg_lift = anim.get("left_leg", 0)
        right_leg_lift = anim.get("right_leg", 0)
        side_blend = anim.get("side_blend", 0)
        move_dir = anim.get("move_dir", 0)

        t = self.time

        # 원숭이왕 전용 - 정지 시 호흡 애니메이션 (어깨 들썩임)
        # 이동 중에는 swagger가 담당하므로, 정지 시(side_blend≈0)에만 활성화
        idle_blend = max(0.0, 1.0 - side_blend * 2.5)  # 이동 시 빠르게 사라짐
        idle_breath = _sin(t * 1.8) * 0.18 * b * idle_blend        # 상체 상하 (느린 호흡)
        idle_shoulder_breath = _sin(t * 1.8) * 0.22 * b * idle_blend  # 어깨 상하 (약간 더 큼)

        # 원숭이왕 전용 - 어슬렁거리는 상체 흔들림 (좌우 롤링)
        swagger_roll = _sin(t * 3.5) * side_blend * 0.4 * b
        swagger_bob = abs(_sin(t * 5.0)) * side_blend * 0.3 * b

        torso_y = cy - int(1.2 * b) + int(body_bob * 2.0 * b) + int(swagger_bob) + int(idle_breath)
        lean_offset = int(lean * 2.5 * b) + int(swagger_roll)

        # 꼬리 관성 (이동 반대 방향으로 흔들림)
        tail_inertia = -move_dir * side_blend * 1.2 * b
        tail_sway = _sin(t * 2.0) * 0.8 * b
        tail_drift = int(tail_inertia + tail_sway)

        # ─── 원숭이왕 색상 팔레트 ───
        p = {
            # 몸 털
            "fur_gold": (205, 165, 75),
            "fur_light": (230, 195, 110),
            "fur_dark": (145, 110, 45),
            "fur_deep": (100, 75, 30),
            "fur_highlight": (245, 220, 150),
            "fur_orange": (220, 155, 60),
            # 배/가슴 (밝은 크림)
            "belly": (235, 215, 170),
            "belly_shadow": (210, 190, 145),
            # 얼굴
            "face_red": (200, 85, 65),
            "face_pink": (235, 155, 135),
            "face_light": (240, 195, 165),
            "face_nose": (180, 70, 50),
            "face_shadow": (165, 65, 50),
            # 눈
            "eye_amber": (240, 185, 45),
            "eye_bright": (255, 220, 100),
            "eye_pupil": (20, 15, 10),
            "eye_white": (250, 248, 240),
            # 입/이빨
            "mouth": (120, 55, 40),
            "teeth": (250, 245, 230),
            "gum": (180, 80, 70),
            # 귀
            "ear_outer": (185, 145, 65),
            "ear_inner": (225, 160, 130),
            # 손/발바닥
            "palm": (180, 140, 105),
            "sole": (160, 120, 85),
            # 왕관
            "crown_gold": (255, 215, 0),
            "crown_dark": (200, 165, 0),
            "crown_light": (255, 235, 100),
            "crown_gem": (180, 30, 30),
            "crown_gem_light": (230, 70, 70),
            # 엉덩이/피부 (원숭이 특유의 붉은 엉덩이)
            "butt_red": (210, 90, 75),
            "butt_pink": (235, 140, 120),
            # 젖꼭지
            "nipple": (175, 120, 85),
        }

        # ─── 다리 (짧고 굵은 유인원 다리, 구부러진 자세) ───
        roar_pose = anim.get("roar_pose", False)
        hip_y = torso_y + int(1.5 * b)
        for side_idx, side in enumerate([-1, 1]):
            leg_sway = left_leg_sway if side == -1 else right_leg_sway
            leg_lift = left_leg_lift if side == -1 else right_leg_lift

            hip_x = cx + side * int(0.5 * b) + lean_offset

            if roar_pose:
                # ── 포효 포즈: 다리 넓게 벌리고 무릎 깊이 굽힘 ──
                hip_x = cx + side * int(0.75 * b) + lean_offset
                knee_x = hip_x + side * int(0.4 * b)
                knee_y = hip_y + int(0.5 * b)
                ankle_x = knee_x - side * int(0.15 * b)
                ankle_y = knee_y + int(0.7 * b)
                foot_x = ankle_x + side * int(0.15 * b)
                foot_y = ankle_y + int(0.15 * b)
            else:
                # 무릎 (크게 구부러진)
                knee_x = hip_x + int(leg_sway * 0.6 * b) + side * int(0.15 * b)
                knee_y = hip_y + int(0.8 * b) - int(leg_lift * 0.3 * b) + int(swagger_bob * 0.3)
                # 발목
                ankle_x = knee_x + int(leg_sway * 0.3 * b)
                ankle_y = knee_y + int(0.6 * b) - int(leg_lift * 0.2 * b)
                # 발 (넓고 평평한 유인원 발)
                foot_x = ankle_x + side * int(0.1 * b)
                foot_y = ankle_y + int(0.15 * b)

            thigh_thick = max(3, int(0.35 * b))
            shin_thick = max(2, int(0.28 * b))

            # 허벅지 (두꺼운 근육질)
            pygame.draw.line(screen, p["fur_dark"],
                           (hip_x, hip_y), (knee_x, knee_y), thigh_thick + 2)
            pygame.draw.line(screen, p["fur_gold"],
                           (hip_x, hip_y), (knee_x, knee_y), thigh_thick)
            # 허벅지 하이라이트
            pygame.draw.line(screen, p["fur_light"],
                           (hip_x - side * 1, hip_y), (knee_x - side * 1, knee_y),
                           max(1, thigh_thick // 3))

            # 무릎 관절
            knee_r = max(2, int(0.15 * b))
            pygame.draw.circle(screen, p["fur_dark"], (knee_x, knee_y), knee_r + 1)
            pygame.draw.circle(screen, p["fur_gold"], (knee_x, knee_y), knee_r)

            # 정강이
            pygame.draw.line(screen, p["fur_dark"],
                           (knee_x, knee_y), (ankle_x, ankle_y), shin_thick + 1)
            pygame.draw.line(screen, p["fur_gold"],
                           (knee_x, knee_y), (ankle_x, ankle_y), shin_thick)
            # 다리 털 결
            shin_mid_x = (knee_x + ankle_x) // 2
            shin_mid_y = (knee_y + ankle_y) // 2
            pygame.draw.line(screen, p["fur_dark"],
                           (shin_mid_x - int(0.05 * b), shin_mid_y),
                           (shin_mid_x + int(0.05 * b), shin_mid_y + int(0.04 * b)),
                           max(1, int(0.03 * b)))

            # 발 (넓고 납작한 유인원 발)
            foot_w = max(4, int(0.55 * b))
            foot_h = max(3, int(0.22 * b))
            # 발 그림자
            pygame.draw.ellipse(screen, p["fur_deep"],
                              (foot_x - foot_w // 2, foot_y, foot_w + 2, foot_h + 2))
            # 발 본체
            pygame.draw.ellipse(screen, p["sole"],
                              (foot_x - foot_w // 2, foot_y, foot_w, foot_h))
            # 발가락 (3개 큰 발가락)
            for ti in range(3):
                tx = foot_x - int(0.15 * b) + int(ti * 0.15 * b)
                ty = foot_y - int(0.05 * b)
                toe_r = max(1, int(0.07 * b))
                pygame.draw.circle(screen, p["sole"], (tx, ty), toe_r)
                pygame.draw.circle(screen, p["fur_dark"], (tx, ty), toe_r, 1)

        # ─── 몸통 (넓은 어깨, 통통한 배, 앞으로 약간 숙인 자세) ───
        # 허리/골반
        pelvis_w = int(1.8 * b)
        pelvis_h = int(0.6 * b)
        pelvis_rect = pygame.Rect(cx - pelvis_w // 2 + lean_offset,
                                   hip_y - int(0.3 * b), pelvis_w, pelvis_h)
        pygame.draw.rect(screen, p["fur_gold"], pelvis_rect,
                        border_radius=max(1, int(0.15 * b)))

        # 상체 (넓은 어깨에서 허리로 좁아짐)
        chest_top = torso_y - int(0.5 * b)
        chest_bot = hip_y - int(0.1 * b)
        chest_w_top = int(2.4 * b)
        chest_w_bot = int(1.9 * b)
        chest_pts = [
            (cx - chest_w_top // 2 + lean_offset, chest_top),
            (cx + chest_w_top // 2 + lean_offset, chest_top),
            (cx + chest_w_bot // 2 + lean_offset, chest_bot),
            (cx - chest_w_bot // 2 + lean_offset, chest_bot),
        ]
        # 몸통 그림자 (깊이감)
        shadow_pts = [(px + int(0.05 * b), py + int(0.05 * b)) for px, py in chest_pts]
        pygame.draw.polygon(screen, p["fur_deep"], shadow_pts)
        # 몸통 본체
        pygame.draw.polygon(screen, p["fur_gold"], chest_pts)
        # 몸통 외곽선
        pygame.draw.polygon(screen, p["fur_dark"], chest_pts, max(1, int(0.06 * b)))

        # 가슴/배 디테일 (정면)
        if not show_back:
            # 배 (밝은 크림색 - 원숭이 특유의 밝은 배, 털이 없는 부분)
            belly_cx = cx + lean_offset
            belly_cy = torso_y + int(0.4 * b)
            belly_w = int(1.3 * b)
            belly_h = int(1.5 * b)
            belly_rect = pygame.Rect(belly_cx - belly_w // 2, belly_cy,
                                      belly_w, belly_h)
            pygame.draw.ellipse(screen, p["belly"], belly_rect)
            # 배 아래쪽 그림자 (볼록한 느낌)
            belly_shadow_rect = pygame.Rect(belly_cx - belly_w // 2 + int(0.1 * b),
                                             belly_cy + belly_h // 2,
                                             belly_w - int(0.2 * b),
                                             belly_h // 3)
            pygame.draw.ellipse(screen, p["belly_shadow"], belly_shadow_rect)
            # 배꼽
            navel_x = belly_cx
            navel_y = belly_cy + int(0.7 * b)
            navel_r = max(1, int(0.05 * b))
            pygame.draw.circle(screen, p["belly_shadow"], (navel_x, navel_y), navel_r)

            # 가슴 근육 라인 + 젖꼭지
            for side in [-1, 1]:
                pec_x = cx + side * int(0.35 * b) + lean_offset
                pec_y = torso_y + int(0.1 * b)
                pec_w = int(0.5 * b)
                pec_h = int(0.4 * b)
                pygame.draw.arc(screen, p["fur_dark"],
                              (pec_x - pec_w // 2, pec_y, pec_w, pec_h),
                              0, 3.14, max(1, int(0.04 * b)))
                # 젖꼭지 (원숭이 가슴)
                nip_x = pec_x + side * int(0.05 * b)
                nip_y = pec_y + int(0.25 * b)
                pygame.draw.circle(screen, p["nipple"], (nip_x, nip_y),
                                 max(1, int(0.04 * b)))

            # 가슴~배 경계 털 라인
            for fi in range(3):
                fy = belly_cy + int(fi * 0.15 * b)
                fw = int(0.55 * b - fi * 0.08 * b)
                pygame.draw.line(screen, p["fur_orange"],
                               (belly_cx - fw, fy), (belly_cx + fw, fy),
                               max(1, int(0.03 * b)))

        else:
            # 등 (후면 - 척추 라인 + 등 털 질감)
            spine_x = cx + lean_offset
            # 척추 중앙선
            pygame.draw.line(screen, p["fur_deep"],
                           (spine_x, chest_top + int(0.2 * b)),
                           (spine_x, chest_bot - int(0.2 * b)),
                           max(1, int(0.04 * b)))
            # 등 근육 / 털 무늬 (V자 패턴)
            for si in range(5):
                sy = chest_top + int(si * 0.4 * b) + int(0.2 * b)
                sw = int((0.8 - si * 0.06) * b)
                pygame.draw.line(screen, p["fur_dark"],
                               (spine_x - sw, sy), (spine_x, sy + int(0.15 * b)),
                               max(1, int(0.04 * b)))
                pygame.draw.line(screen, p["fur_dark"],
                               (spine_x + sw, sy), (spine_x, sy + int(0.15 * b)),
                               max(1, int(0.04 * b)))
            # 견갑골 (어깨뼈) 디테일
            for side in [-1, 1]:
                sb_x = spine_x + side * int(0.5 * b)
                sb_y = chest_top + int(0.5 * b)
                sb_w = int(0.4 * b)
                sb_h = int(0.5 * b)
                pygame.draw.ellipse(screen, p["fur_dark"],
                                  (sb_x - sb_w // 2, sb_y, sb_w, sb_h), 1)

            # 빨간 엉덩이 (원숭이 특유 - 후면에서만 보임)
            butt_cx = spine_x
            butt_cy = chest_bot + int(0.2 * b)
            butt_w = int(1.2 * b)
            butt_h = int(0.7 * b)
            butt_rect = pygame.Rect(butt_cx - butt_w // 2, butt_cy, butt_w, butt_h)
            pygame.draw.ellipse(screen, p["butt_red"], butt_rect)
            # 엉덩이 하이라이트 (윤기)
            butt_hl_rect = pygame.Rect(butt_cx - butt_w // 4, butt_cy + int(0.05 * b),
                                        butt_w // 2, butt_h // 2)
            pygame.draw.ellipse(screen, p["butt_pink"], butt_hl_rect)
            # 엉덩이 가운데 홈
            pygame.draw.line(screen, p["face_shadow"],
                           (butt_cx, butt_cy + int(0.08 * b)),
                           (butt_cx, butt_cy + butt_h - int(0.1 * b)),
                           max(1, int(0.04 * b)))

            # ─── 꼬리 (후면에서만 보임 - 엉덩이 위, 대각선 + 끝 말림) ───
            tail_base_x = cx + lean_offset
            tail_base_y = torso_y + int(1.8 * b)
            tail_sway_fast = _sin(t * 3.2) * 0.3 * b
            tail_curl_anim = _sin(t * 1.5) * 0.15 * b

            # 꼬리 방향: 옆으로 대각선 (X 많이, Y 조금)
            # 관절 좌표 (기저부 → 대각선 → 말림)
            t1x = tail_base_x + int(tail_drift * 0.2) + int(0.3 * b)
            t1y = tail_base_y - int(0.1 * b)
            t2x = tail_base_x + int(tail_drift * 0.4) + int(1.0 * b) + int(tail_sway_fast * 0.3)
            t2y = tail_base_y - int(0.5 * b) + int(tail_curl_anim * 0.3)
            t3x = tail_base_x + int(tail_drift * 0.6) + int(1.6 * b) + int(tail_sway_fast * 0.6)
            t3y = tail_base_y - int(0.8 * b) + int(tail_curl_anim * 0.6)
            # 말림 시작 (위쪽으로 꺾임)
            t4x = tail_base_x + int(tail_drift * 0.7) + int(1.8 * b) + int(tail_sway_fast * 0.8)
            t4y = tail_base_y - int(1.2 * b) + int(tail_curl_anim)
            # 말림 끝 (동그랗게 안쪽으로 돌아옴)
            curl_phase = t * 1.8
            t5x = t4x - int(0.3 * b) + int(_sin(curl_phase) * 0.08 * b)
            t5y = t4y - int(0.35 * b) + int(_cos(curl_phase) * 0.06 * b)
            t6x = t5x - int(0.35 * b) + int(_sin(curl_phase) * 0.05 * b)
            t6y = t5y + int(0.1 * b) + int(_cos(curl_phase) * 0.04 * b)

            tail_pts = [(t1x, t1y), (t2x, t2y), (t3x, t3y), (t4x, t4y), (t5x, t5y), (t6x, t6y)]
            seg_count = len(tail_pts) - 1

            # 꼬리 그림자
            tail_shadow_off = int(0.06 * b)
            for i in range(seg_count):
                seg_thick = max(2, int((0.28 - i * 0.04) * b))
                pygame.draw.line(screen, p["fur_deep"],
                               (tail_pts[i][0] + tail_shadow_off, tail_pts[i][1] + tail_shadow_off),
                               (tail_pts[i + 1][0] + tail_shadow_off, tail_pts[i + 1][1] + tail_shadow_off),
                               seg_thick + 1)

            # 꼬리 본체 (굵기 점점 가늘어짐)
            for i in range(seg_count):
                seg_thick = max(2, int((0.28 - i * 0.04) * b))
                # 외곽 (어두운 색)
                pygame.draw.line(screen, p["fur_dark"],
                               tail_pts[i], tail_pts[i + 1], seg_thick + 1)
                # 내부 (밝은 색)
                pygame.draw.line(screen, p["fur_gold"],
                               tail_pts[i], tail_pts[i + 1], seg_thick)
                # 하이라이트 (상단 밝은 줄)
                pygame.draw.line(screen, p["fur_light"],
                               (tail_pts[i][0], tail_pts[i][1] - 1),
                               (tail_pts[i + 1][0], tail_pts[i + 1][1] - 1),
                               max(1, seg_thick // 3))

            # 꼬리 끝 둥근 마감
            tip_r = max(2, int(0.08 * b))
            pygame.draw.circle(screen, p["fur_dark"], (t6x, t6y), tip_r + 1)
            pygame.draw.circle(screen, p["fur_gold"], (t6x, t6y), tip_r)

        # 어깨 근육 (양쪽 둥근 근육 - 알몸 원숭이 어깨)
        shoulder_y_pos = chest_top + int(0.15 * b) + int(shoulder_bob * 0.25 * b) + int(idle_shoulder_breath)
        for side in [-1, 1]:
            sx = cx + side * int(1.15 * b) + lean_offset
            sy = shoulder_y_pos
            # 어깨 근육 (큰 원 - 두꺼운 털)
            sh_r = max(3, int(0.38 * b))
            pygame.draw.circle(screen, p["fur_deep"], (sx, sy), sh_r + 2)
            pygame.draw.circle(screen, p["fur_dark"], (sx, sy), sh_r + 1)
            pygame.draw.circle(screen, p["fur_gold"], (sx, sy), sh_r)
            # 어깨 하이라이트
            pygame.draw.circle(screen, p["fur_light"],
                             (sx - side * int(0.05 * b), sy - int(0.08 * b)),
                             max(1, sh_r // 2))
            # 어깨 위 솟은 털 다발 (야생 느낌)
            for fi in range(3):
                tuft_angle = -0.6 + fi * 0.6 + side * 0.3
                tuft_len = int(0.22 * b) + int(fi % 2 * 0.08 * b)
                tuft_sway = int(_sin(t * 2.0 + fi * 1.0 + side) * 0.03 * b * side_blend)
                tx = sx + int(_sin(tuft_angle) * tuft_len) + tuft_sway
                ty = sy - int(_cos(tuft_angle) * tuft_len)
                pygame.draw.line(screen, p["fur_orange"],
                               (sx, sy - int(0.1 * b)), (tx, ty),
                               max(1, int(0.06 * b)))
                # 털 끝 밝은 점
                pygame.draw.circle(screen, p["fur_light"], (tx, ty),
                                 max(1, int(0.03 * b)))

        # ─── 양팔 (매우 긴 원숭이 팔 - 무릎 아래까지 늘어짐) ───
        arm_thick = max(2, int(0.26 * b))
        roar_pose = anim.get("roar_pose", False)

        for side in [-1, 1]:
            arm_swing = left_arm_swing if side == -1 else right_arm_swing

            # 어깨 시작점
            s_x = cx + side * int(1.15 * b) + lean_offset
            s_y = shoulder_y_pos + int(0.2 * b)

            # ── 야생의 포효 포즈: 양팔 크게 벌리기 ──
            if roar_pose:
                # 팔꿈치를 바깥+위로 크게 벌림
                elbow_x = s_x + side * int(1.6 * b)
                elbow_y = s_y + int(0.4 * b)
                # 손목: 팔꿈치에서 바깥+아래로
                wrist_x = elbow_x + side * int(1.0 * b)
                wrist_y = elbow_y + int(0.9 * b)
            else:
                # 기본 팔 늘어뜨림 (원숭이 특유의 긴 팔)
                # 팔꿈치 (바깥쪽으로 살짝 벌어짐)
                elbow_x = s_x + side * int(0.5 * b) + int(arm_swing * 1.2 * b)
                elbow_y = s_y + int(1.5 * b) + int(arm_swing * 0.3 * b)

                # 손목 (무릎 근처까지 늘어짐)
                wrist_x = elbow_x + side * int(0.15 * b) + int(arm_swing * 0.8 * b)
                wrist_y = elbow_y + int(1.2 * b) + int(arm_swing * 0.2 * b)

            # 타격 모션 - 한쪽 팔 휘두르기
            if not roar_pose and abs(weapon_swing) > 0.05:
                swing_dir = -1 if show_back else 1
                hit_side = 1 if not show_back else -1  # 정면: 오른팔, 후면: 왼팔
                if side == hit_side:
                    # 타격하는 팔: 앞으로 크게 휘두르기
                    swing_power = weapon_swing * swing_dir
                    elbow_x = s_x + side * int(0.3 * b) + int(swing_power * 2.5 * b)
                    elbow_y = s_y + int(0.8 * b) + int(abs(swing_power) * 0.5 * b)
                    wrist_x = elbow_x + int(swing_power * 2.0 * b)
                    wrist_y = elbow_y + int(0.5 * b) - int(abs(swing_power) * 0.3 * b)
                else:
                    # 반대 팔: 뒤로 균형잡기
                    elbow_x = s_x - side * int(0.2 * b) - int(weapon_swing * 0.5 * b * swing_dir)
                    elbow_y = s_y + int(1.2 * b)
                    wrist_x = elbow_x - side * int(0.1 * b)
                    wrist_y = elbow_y + int(0.8 * b)

            # 윗팔 (두꺼운 근육)
            pygame.draw.line(screen, p["fur_deep"],
                           (s_x, s_y), (elbow_x, elbow_y), arm_thick + 3)
            pygame.draw.line(screen, p["fur_gold"],
                           (s_x, s_y), (elbow_x, elbow_y), arm_thick + 1)
            # 윗팔 하이라이트
            pygame.draw.line(screen, p["fur_light"],
                           (s_x, s_y), (elbow_x, elbow_y),
                           max(1, arm_thick // 3))

            # 팔꿈치 관절
            e_r = max(2, int(0.14 * b))
            pygame.draw.circle(screen, p["fur_dark"], (int(elbow_x), int(elbow_y)), e_r + 1)
            pygame.draw.circle(screen, p["fur_gold"], (int(elbow_x), int(elbow_y)), e_r)

            # 아랫팔 (약간 가늘어짐 + 팔 털 질감)
            pygame.draw.line(screen, p["fur_deep"],
                           (int(elbow_x), int(elbow_y)),
                           (int(wrist_x), int(wrist_y)), arm_thick + 1)
            pygame.draw.line(screen, p["fur_gold"],
                           (int(elbow_x), int(elbow_y)),
                           (int(wrist_x), int(wrist_y)), arm_thick)
            # 팔 털 결 (2~3개 짧은 선)
            for fi in range(2):
                fr = 0.3 + fi * 0.35
                fx1 = int(elbow_x + (wrist_x - elbow_x) * fr)
                fy1 = int(elbow_y + (wrist_y - elbow_y) * fr)
                pygame.draw.line(screen, p["fur_dark"],
                               (fx1 - int(0.06 * b), fy1),
                               (fx1 + int(0.06 * b), fy1 + int(0.05 * b)),
                               max(1, int(0.03 * b)))

            # 손 (큰 원숭이 손 - 주먹 또는 펼친 손바닥)
            hand_r = max(3, int(0.22 * b))
            hx, hy = int(wrist_x), int(wrist_y)

            if abs(weapon_swing) > 0.2 and side == (1 if not show_back else -1):
                # 타격 중인 팔: 주먹 (더 큰 주먹)
                pygame.draw.circle(screen, p["fur_dark"], (hx, hy), hand_r + 2)
                pygame.draw.circle(screen, p["palm"], (hx, hy), hand_r)
                # 주먹 쥔 손가락 라인
                for fi in range(3):
                    fy = hy - int(0.06 * b) + int(fi * 0.06 * b)
                    pygame.draw.line(screen, p["fur_dark"],
                                   (hx - hand_r + 1, fy),
                                   (hx + hand_r - 1, fy),
                                   max(1, int(0.03 * b)))
                # 타격 이펙트 (스윙 충격파 - 잔상)
                if abs(weapon_swing) > 0.4:
                    impact_a = int(abs(weapon_swing) * 120)
                    impact_r = int(hand_r * 1.5 + abs(weapon_swing) * b)
                    imp_surf = self._get_surface(impact_r * 2, impact_r * 2)
                    pygame.draw.circle(imp_surf, (255, 220, 120, min(120, impact_a)),
                                     (impact_r, impact_r), impact_r)
                    screen.blit(imp_surf, (hx - impact_r, hy - impact_r))
            else:
                # 일반: 살짝 벌린 손 (너클워킹 느낌)
                pygame.draw.circle(screen, p["fur_dark"], (hx, hy), hand_r + 1)
                pygame.draw.circle(screen, p["palm"], (hx, hy), hand_r)
                # 손가락 (4개 짧은 손가락 + 엄지)
                for fi in range(4):
                    angle = -0.4 + fi * 0.25 + (side * 0.1)
                    f_len = int(0.16 * b)
                    fx = hx + int(_sin(angle) * f_len) + side * int(0.02 * b)
                    fy = hy + int(_cos(angle) * f_len)
                    f_r = max(1, int(0.05 * b))
                    pygame.draw.circle(screen, p["palm"], (fx, fy), f_r)
                    pygame.draw.circle(screen, p["fur_dark"], (fx, fy), f_r, 1)
                # 엄지
                thumb_x = hx + side * int(0.12 * b)
                thumb_y = hy - int(0.1 * b)
                pygame.draw.circle(screen, p["palm"], (thumb_x, thumb_y),
                                 max(1, int(0.06 * b)))

        # ─── 목 (짧고 두꺼운) ───
        neck_x = cx + lean_offset
        neck_top = torso_y - int(0.8 * b)
        neck_bot = chest_top + int(0.2 * b)
        neck_w = max(3, int(0.4 * b))
        pygame.draw.line(screen, p["fur_dark"],
                        (neck_x, neck_top), (neck_x, neck_bot), neck_w + 2)
        pygame.draw.line(screen, p["fur_gold"],
                        (neck_x, neck_top), (neck_x, neck_bot), neck_w)

        # ─── 머리 (원숭이 두상 - 둥글고 넓은 얼굴) ───
        head_x = cx + lean_offset
        head_y = torso_y - int(1.6 * b) + int(anim.get("head_tilt", 0) * 0.15 * b)
        head_r = int(0.85 * b)

        # 머리 털 (뒤쪽 먼저)
        fur_r = head_r + int(0.15 * b)
        pygame.draw.circle(screen, p["fur_dark"], (head_x, head_y), fur_r + 1)
        pygame.draw.circle(screen, p["fur_gold"], (head_x, head_y), fur_r)
        # 머리 상단 하이라이트
        pygame.draw.circle(screen, p["fur_light"],
                         (head_x - int(0.1 * b), head_y - int(0.15 * b)),
                         max(2, fur_r - int(0.2 * b)))

        # 귀 (양쪽 둥근 귀)
        for side in [-1, 1]:
            ear_x = head_x + side * int(0.75 * b)
            ear_y = head_y - int(0.1 * b)
            ear_r_outer = max(3, int(0.25 * b))
            ear_r_inner = max(2, int(0.17 * b))
            # 귀 외곽
            pygame.draw.circle(screen, p["ear_outer"], (ear_x, ear_y), ear_r_outer)
            pygame.draw.circle(screen, p["fur_dark"], (ear_x, ear_y), ear_r_outer, 1)
            # 귀 내부 (분홍)
            pygame.draw.circle(screen, p["ear_inner"],
                             (ear_x + side * int(0.03 * b), ear_y), ear_r_inner)

        if not show_back:
            # ═══ 정면 얼굴 ═══

            # 얼굴 (붉은빛 도는 살색 - 원숭이 특유의 붉은 얼굴)
            face_w = int(1.2 * b)
            face_h = int(1.1 * b)
            face_rect = pygame.Rect(head_x - face_w // 2, head_y - int(0.2 * b),
                                     face_w, face_h)
            pygame.draw.ellipse(screen, p["face_pink"], face_rect)

            # 이마 돌출 (눈두덩이 - 원숭이 특유의 두꺼운 이마뼈)
            brow_y = head_y - int(0.1 * b)
            brow_w = int(0.9 * b)
            brow_h = int(0.2 * b)
            brow_rect = pygame.Rect(head_x - brow_w // 2, brow_y - brow_h,
                                     brow_w, brow_h * 2)
            pygame.draw.ellipse(screen, p["face_red"], brow_rect)
            # 이마 그림자
            pygame.draw.arc(screen, p["face_shadow"], brow_rect,
                          0, 3.14, max(1, int(0.05 * b)))

            # 눈 (날카로운 작은 눈 - 영리한 인상)
            eye_y = head_y + int(0.05 * b)
            for side in [-1, 1]:
                ex = head_x + side * int(0.25 * b)
                # 눈 배경 (흰자)
                eye_w = max(3, int(0.18 * b))
                eye_h = max(2, int(0.12 * b))
                pygame.draw.ellipse(screen, p["eye_white"],
                                  (ex - eye_w, eye_y - eye_h, eye_w * 2, eye_h * 2))
                # 홍채 (호박색)
                iris_r = max(1, int(0.09 * b))
                pygame.draw.circle(screen, p["eye_amber"], (ex, eye_y), iris_r)
                # 동공 (세로로 약간 긴)
                pupil_r = max(1, int(0.05 * b))
                pygame.draw.circle(screen, p["eye_pupil"], (ex, eye_y), pupil_r)
                # 눈빛 하이라이트
                hl_r = max(1, int(0.03 * b))
                pygame.draw.circle(screen, (255, 255, 240),
                                 (ex + int(0.02 * b), eye_y - int(0.03 * b)), hl_r)
                # 눈꺼풀 (위)
                pygame.draw.arc(screen, p["face_shadow"],
                              (ex - eye_w - 1, eye_y - eye_h - 1,
                               eye_w * 2 + 2, eye_h * 2 + 2),
                              0.2, 2.94, max(1, int(0.06 * b)))

            # 코 (납작하고 넓은 원숭이 코)
            nose_y = head_y + int(0.25 * b)
            nose_w = max(3, int(0.22 * b))
            nose_h = max(2, int(0.15 * b))
            # 코 본체
            nose_pts = [
                (head_x, nose_y - int(0.05 * b)),
                (head_x + nose_w // 2, nose_y + nose_h // 2),
                (head_x + int(0.05 * b), nose_y + nose_h),
                (head_x - int(0.05 * b), nose_y + nose_h),
                (head_x - nose_w // 2, nose_y + nose_h // 2),
            ]
            pygame.draw.polygon(screen, p["face_nose"], nose_pts)
            # 콧구멍 (양쪽)
            for side in [-1, 1]:
                nx = head_x + side * int(0.08 * b)
                ny = nose_y + int(0.06 * b)
                nr = max(1, int(0.04 * b))
                pygame.draw.circle(screen, p["fur_deep"], (nx, ny), nr)

            # 입 (넓은 원숭이 입 - 약간 웃는 느낌)
            mouth_y = head_y + int(0.5 * b)
            mouth_w = int(0.35 * b)
            # 입술 라인
            pygame.draw.arc(screen, p["mouth"],
                          (head_x - mouth_w, mouth_y - int(0.05 * b),
                           mouth_w * 2, int(0.2 * b)),
                          3.14, 6.28, max(1, int(0.06 * b)))

            # 볼 주름 (웃는 주름)
            for side in [-1, 1]:
                ch_x = head_x + side * int(0.38 * b)
                ch_y = head_y + int(0.3 * b)
                pygame.draw.arc(screen, p["face_shadow"],
                              (ch_x - int(0.1 * b), ch_y,
                               int(0.2 * b), int(0.25 * b)),
                              0 if side == 1 else 3.14,
                              3.14 if side == 1 else 6.28,
                              max(1, int(0.04 * b)))

            # 턱 수염 (짧은 갈색 수염 - 원숭이왕 위엄)
            chin_y = head_y + int(0.65 * b)
            for bi in range(5):
                bx = head_x - int(0.15 * b) + int(bi * 0.08 * b)
                by = chin_y + int(_sin(t * 1.5 + bi * 0.8) * 0.02 * b)
                b_len = int(0.12 * b) + int(bi % 2 * 0.05 * b)
                pygame.draw.line(screen, p["fur_orange"],
                               (bx, chin_y), (bx, by + b_len),
                               max(1, int(0.03 * b)))

        else:
            # ═══ 후면 머리 ═══
            # 뒷머리 털 (갈색)
            pygame.draw.circle(screen, p["fur_gold"], (head_x, head_y), head_r)
            # 뒷머리 털 무늬
            for j in range(5):
                fy = head_y - int(0.3 * b) + int(j * 0.15 * b)
                fw = int(0.6 * b - abs(j - 2) * 0.08 * b)
                f_col = p["fur_light"] if j % 2 == 0 else p["fur_dark"]
                pygame.draw.line(screen, f_col,
                               (head_x - fw, fy), (head_x + fw, fy),
                               max(1, int(0.05 * b)))
            # 뒷머리 중앙 가르마
            pygame.draw.line(screen, p["fur_deep"],
                           (head_x, head_y - int(0.4 * b)),
                           (head_x, head_y + int(0.3 * b)),
                           max(1, int(0.04 * b)))
            # 목덜미 털 (약간 부풀어오른)
            nape_y = head_y + int(0.5 * b)
            nape_w = int(0.5 * b)
            nape_h = int(0.3 * b)
            pygame.draw.ellipse(screen, p["fur_orange"],
                              (head_x - nape_w // 2, nape_y, nape_w, nape_h))

        # ─── 왕관 (금관 - 원숭이왕의 상징) ───
        crown_x = head_x
        crown_y = head_y - int(0.85 * b)
        crown_w = int(1.0 * b)
        crown_h = int(0.5 * b)

        # 왕관 밴드 (아래쪽 굵은 금 밴드)
        band_h = max(2, int(0.15 * b))
        band_rect = pygame.Rect(crown_x - crown_w // 2, crown_y + crown_h - band_h,
                                 crown_w, band_h)
        pygame.draw.rect(screen, p["crown_dark"], band_rect,
                        border_radius=max(1, int(0.05 * b)))
        pygame.draw.rect(screen, p["crown_gold"], band_rect,
                        border_radius=max(1, int(0.05 * b)))
        # 밴드 하이라이트
        hl_rect = pygame.Rect(band_rect.x, band_rect.y,
                               band_rect.width, max(1, band_h // 2))
        pygame.draw.rect(screen, p["crown_light"], hl_rect,
                        border_radius=max(1, int(0.05 * b)))

        # 왕관 뾰족한 이빨 (5개 삼각형)
        for ci in range(5):
            cx_pos = crown_x - crown_w // 2 + int(ci * crown_w / 4)
            cy_bot = crown_y + crown_h - band_h
            point_h = int(0.35 * b) if ci == 2 else int(0.25 * b)  # 가운데 더 높음
            tri_w = int(crown_w / 5.5)
            tri_pts = [
                (cx_pos - tri_w // 2, cy_bot),
                (cx_pos + tri_w // 2, cy_bot),
                (cx_pos, cy_bot - point_h),
            ]
            pygame.draw.polygon(screen, p["crown_gold"], tri_pts)
            pygame.draw.polygon(screen, p["crown_dark"], tri_pts, 1)
            # 꼭대기 작은 구슬
            dot_r = max(1, int(0.04 * b))
            pygame.draw.circle(screen, p["crown_light"],
                             (cx_pos, cy_bot - point_h), dot_r)

        # 왕관 중앙 보석 (큰 루비)
        gem_x = crown_x
        gem_y = crown_y + crown_h - band_h - int(0.02 * b)
        gem_r = max(2, int(0.1 * b))
        # 보석 글로우
        gem_pulse = 0.6 + 0.4 * _sin(t * 2.5)
        glow_r = gem_r + int(0.08 * b * gem_pulse)
        gs = self._get_surface(glow_r * 4, glow_r * 4)
        ga = int(30 + 20 * gem_pulse)
        pygame.draw.circle(gs, (255, 60, 40, ga), (glow_r * 2, glow_r * 2), glow_r)
        screen.blit(gs, (gem_x - glow_r * 2, gem_y - glow_r * 2))
        # 보석 본체
        pygame.draw.circle(screen, p["crown_gem"], (gem_x, gem_y), gem_r)
        pygame.draw.circle(screen, p["crown_gem_light"],
                         (gem_x - 1, gem_y - 1), max(1, gem_r // 2))

        # 왕관 양쪽 작은 보석
        for side in [-1, 1]:
            sg_x = crown_x + side * int(crown_w * 0.35)
            sg_y = gem_y + int(0.02 * b)
            sg_r = max(1, int(0.06 * b))
            pygame.draw.circle(screen, p["crown_gem"], (sg_x, sg_y), sg_r)
            pygame.draw.circle(screen, p["crown_light"], (sg_x, sg_y), max(1, sg_r - 1))

        # ─── 털 먼지 파티클 (이동 시 발밑에서 뿜어져 나오는 먼지) ───
        if side_blend > 0.2:
            dust_count = int(2 + side_blend * 4)
            for i in range(dust_count):
                dp = t * 3.0 + i * 1.5
                dx = cx + lean_offset + int(-move_dir * (1.2 + i * 0.6) * b) + int(_sin(dp) * 0.4 * b)
                dy = hip_y + int(1.8 * b) + int(_sin(dp * 0.7) * 0.2 * b)
                da = int(25 * side_blend * max(0, _sin(dp * 1.3)))
                dr = max(1, int((0.25 + i * 0.06) * b))
                if da > 5:
                    ds = self._get_surface(dr * 2, dr * 2)
                    pygame.draw.circle(ds, (180, 150, 90, da), (dr, dr), dr)
                    screen.blit(ds, (dx - dr, dy - dr))

        # ─── 타격 시 충격파 이펙트 ───
        if abs(weapon_swing) > 0.5:
            swing_dir_val = 1 if not show_back else -1
            hit_x = cx + lean_offset + int(swing_dir_val * weapon_swing * 3.5 * b)
            hit_y = torso_y + int(0.5 * b)
            # 둥근 충격파
            shock_r = int(abs(weapon_swing) * 1.5 * b)
            shock_a = int(abs(weapon_swing) * 100)
            shock_surf = self._get_surface(shock_r * 2, shock_r * 2)
            pygame.draw.circle(shock_surf, (255, 200, 80, min(80, shock_a)),
                             (shock_r, shock_r), shock_r)
            pygame.draw.circle(shock_surf, (255, 230, 150, min(50, shock_a // 2)),
                             (shock_r, shock_r), max(1, shock_r // 2))
            screen.blit(shock_surf, (hit_x - shock_r, hit_y - shock_r))

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
