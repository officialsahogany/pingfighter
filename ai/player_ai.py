"""
간단한 플레이어 자동 조종 AI.
 - 스매셔 전용으로 설계.
 - 공 위치/속도 기반으로 이동, 필요 시 대쉬 및 스페셜(스페이스) 사용.
 - 주기적으로 스킬 포인트를 자동 분배하고 스매셔 전용 스킬도 투자.
"""

from __future__ import annotations

import math
import os
import pygame

import academy
from skills.smasher_skills import get_smasher_skills

AI_DRIVE_DEBUG = os.environ.get("PINGF_DRIVE_DEBUG", "0").lower() not in ("0", "false", "off")


class PlayerAIKeyState:
    """pygame.key.get_pressed()와 호환되는 얇은 래퍼."""

    def __init__(self, pressed: set[int], base_keys=None):
        self.pressed = set(pressed)
        self.base_keys = base_keys

    def __getitem__(self, key: int) -> bool:
        if key in self.pressed:
            return True
        if self.base_keys is not None:
            try:
                return bool(self.base_keys[key])
            except Exception:
                return False
        return False

    def __len__(self) -> int:
        try:
            return len(self.base_keys)
        except Exception:
            return 512


class PlayerAIController:
    """프레임 단위 의사결정을 담당하는 간단한 규칙 기반 AI."""

    def __init__(self):
        self.last_dash_ms = 0
        self.last_special_ms = 0
        self.last_upgrade_check_ms = 0
        self.last_space_press_ms = 0
        self.space_hold_until_ms = 0
        self.space_hold_dir = 0  # -1: left, 1: right

    def on_stage_start(self):
        self.last_dash_ms = 0
        self.last_special_ms = 0
        self.last_space_press_ms = 0
        self.space_hold_until_ms = 0
        self.space_hold_dir = 0

    # ------------------------------------------------------------------ #
    # 스킬 자동 투자
    # ------------------------------------------------------------------ #
    def _auto_upgrade_skills(self) -> None:
        now = pygame.time.get_ticks()
        if now - self.last_upgrade_check_ms < 500:
            return
        self.last_upgrade_check_ms = now

        skill_system = academy.skill_system

        # 일반 트리(대쉬/아이템) 우선순위
        priority = [
            "dash_lightweight",
            "dash_module_control",
            "dash_jump",
            "dash_battery_pack",
            "dash_acceleration",
            "dash_amplification",
            "dash_spirit",
            "item_luck",
            "item_cooldown_mastery",
            "item_gauge_mastery",
            "item_bag_expansion",
        ]

        # 남아있는 포인트가 있을 때 가능한 만큼 투자
        for _ in range(32):  # 안전 상한
            target = next((sid for sid in priority if skill_system.can_upgrade_skill(sid)), None)
            if target is None:
                break
            skill_system.upgrade_skill(target)

        # 스매셔 전용 스킬도 투자 (같은 TP 풀 사용)
        smasher = get_smasher_skills()
        smasher_priority = [
            "heavy_impact",
            "speed_charge",
            "burst_wave",
            "dual_smash",
            "power_break",
            "impact_zone",
            "ultra_charge",
            "berserker",
            "chain_impact",
            "smash_charge",
            "smash_power",
            "mega_smash",
        ]

        for sid in smasher_priority:
            skill = smasher.skills_dict.get(sid)
            if not skill:
                continue
            if skill["current_level"] >= skill.get("max_level", 0):
                continue
            cost = skill.get("cost", 1)
            if skill_system.skill_points < cost:
                break
            if not smasher.can_upgrade_skill(sid):
                continue
            smasher.upgrade_skill(sid)
            skill_system.skill_points = max(0, skill_system.skill_points - cost)

    def auto_upgrade_now(self) -> None:
        """외부에서 즉시 스킬 투자 실행 요청할 때 사용."""
        # 체크 간격과 무관하게 한 번 실행
        self.last_upgrade_check_ms = 0
        self._auto_upgrade_skills()

    # ------------------------------------------------------------------ #
    # 입력 결정
    # ------------------------------------------------------------------ #
    def decide(self, state: dict) -> set[int]:
        """
        state keys:
            now_ms, player_rect, ball_rect, ball_vel, width, height,
            is_waiting_for_serve, special_ready, special_gauge, special_max,
            rolling_active, rolling_stun, rolling_charges, current_stage
        """
        self._auto_upgrade_skills()

        now = state.get("now_ms", 0)
        player = state["player_rect"]
        ball = state["ball_rect"]
        vx, vy = state.get("ball_vel", (0, 0))
        pressed: set[int] = set()

        # 이전 프레임에 설정된 스페이스/방향 홀드가 남아 있으면 계속 누른다.
        if now < self.space_hold_until_ms and self.space_hold_dir != 0:
            pressed.add(pygame.K_SPACE)
            if self.space_hold_dir < 0:
                pressed.update((pygame.K_LEFT, pygame.K_a))
            else:
                pressed.update((pygame.K_RIGHT, pygame.K_d))
        else:
            # 홀드 만료
            self.space_hold_dir = 0
            self.space_hold_until_ms = 0

        # 1) 서브 대기 → 바로 서브
        if state.get("is_waiting_for_serve", False):
            pressed.add(pygame.K_SPACE)
            return pressed

        # 2) 기본 이동 목표: 공 예상 위치
        target_x = ball.centerx
        if abs(vy) > 1e-3:
            # 패들 상단까지 도달 시간을 rough 계산
            dist_y = (player.top - ball.centery) if vy > 0 else (player.bottom - ball.centery)
            t = max(0.0, dist_y / vy)
            target_x = ball.centerx + vx * t
        target_x = max(20, min(state["width"] - 20, target_x))

        if player.centerx < target_x - 8:
            pressed.update((pygame.K_RIGHT, pygame.K_d))
        elif player.centerx > target_x + 8:
            pressed.update((pygame.K_LEFT, pygame.K_a))

        # 공과 패들 사이의 가로 거리 (이후 여러 곳에서 사용)
        distance_x = target_x - player.centerx
        ball_offset_x = ball.centerx - player.centerx

        # 2-1) 드라이브/파워스매싱 타이밍: 공이 패들 상단 근처로 내려올 때 스페이스 입력
        distance_to_paddle = player.top - ball.centery
        drive_ready = state.get("special_gauge", 0) >= 150
        power_ready = state.get("special_gauge", 0) >= 350 or state.get("special_ready", False)
        # 퍼펙트 타이밍 윈도우는 코드 상 ball_to_paddle_distance <= 20 일 때 열림.
        paddle_half = player.width * 0.5
        ball_radius = getattr(ball, "width", player.width) * 0.5
        x_allow = paddle_half + ball_radius + 20
        perfect_window = (
            0 < distance_to_paddle <= 22  # 메인 로직의 20px 범위에 살짝 여유
            and vy > 0
            and abs(ball_offset_x) <= x_allow + 20  # 실제 공 위치 기준으로 판정해 미스 매칭 방지
        )

        want_power_smash = power_ready and perfect_window
        want_drive = (not want_power_smash) and drive_ready and perfect_window

        if AI_DRIVE_DEBUG and perfect_window:
            print(
                f"[AI_DRIVE] t={now} dy={distance_to_paddle:.1f} dx={ball_offset_x:.1f} "
                f"vx={vx:.2f} vy={vy:.2f} drive_ready={drive_ready} power_ready={power_ready} "
                f"want_drive={want_drive} want_power={want_power_smash} gauge={state.get('special_gauge',0)}"
            )

        if (want_power_smash or want_drive) and now - self.last_space_press_ms > 60:
            # 파워/드라이브 시도: 최소 60ms 간격으로 재시도하며 180ms 동안 홀드
            dir_left = ball.centerx < player.centerx
            pressed.add(pygame.K_SPACE)
            if dir_left:
                pressed.update((pygame.K_LEFT, pygame.K_a))
                self.space_hold_dir = -1
            else:
                pressed.update((pygame.K_RIGHT, pygame.K_d))
                self.space_hold_dir = 1
            self.space_hold_until_ms = now + 180
            self.last_space_press_ms = now
            if AI_DRIVE_DEBUG:
                print(
                    f"[AI_DRIVE] INPUT launch={'POWER' if want_power_smash else 'DRIVE'} "
                    f"dir={'L' if dir_left else 'R'} hold_until={self.space_hold_until_ms}"
                )
        elif perfect_window and now - self.last_space_press_ms > 140:
            # 일반 스윙: 여유 있게 입력
            pressed.add(pygame.K_SPACE)
            self.last_space_press_ms = now

        # 3) 위험 상황에서만 대쉬 시도 (다운+방향) — 위험감지센서처럼 “위기 탈출용”으로 제한
        ball_speed = math.hypot(vx, vy)
        time_to_player = float("inf")
        if vy > 0.01:  # 플레이어(화면 하단) 쪽으로 내려올 때만 계산
            dist_y = max(1.0, player.top - ball.centery)
            time_to_player = dist_y / vy / 60.0  # 초 단위(60fps 기준)

        danger_lateral = abs(distance_x) > 110
        danger_soon = time_to_player < 0.5
        danger_fast = ball_speed > 14 and abs(distance_x) > 90 and ball.centery > state["height"] * 0.6
        # AI가 화면 하단에 있으므로, Y 기준 '위험 높이'를 반대로 적용해 상단(플레이어 기준 위쪽)에서 오는 공에 반응
        danger_low = ball.centery < state["height"] * 0.25 and abs(distance_x) > 60
        should_dash = (danger_lateral and danger_soon) or danger_fast or danger_low

        # 걷기(방향키)만으로 도달 가능한 거리면 대쉬를 아낀다.
        # 경험적으로 기본 패들 이동 속도를 약 900px/s로 추정 (60fps 기준 15px/frame).
        WALK_SPEED_PER_SEC = 900.0
        reachable_by_walk = False
        if time_to_player != float("inf") and time_to_player > 0:
            reachable_by_walk = abs(distance_x) <= WALK_SPEED_PER_SEC * time_to_player
        # 위험하지만 걸어서 충분히 커버 가능하면 대쉬 취소
        if reachable_by_walk:
            should_dash = False

        # 게이지는 최대한 아껴두고, 정말 급할 때만 소모
        gauge = state.get("special_gauge", 0)
        gauge_max = max(1, state.get("special_max", 1))
        gauge_ratio = gauge / gauge_max
        near_cap = gauge_ratio > 0.9 or state.get("special_ready", False)
        # 위험이 임박하면 게이지가 적어도 대쉬 허용, 그 외에는 60% 이상에서만 사용
        allow_dash = danger_soon or near_cap or gauge_ratio >= 0.6

        can_dash = (
            not state.get("rolling_active", False)
            and state.get("rolling_stun", 0) <= 0
            and state.get("rolling_charges", 0) > 0
            and now - self.last_dash_ms > 600
        )
        if can_dash and should_dash and allow_dash:
            direction_key = pygame.K_RIGHT if distance_x > 0 else pygame.K_LEFT
            pressed.update((pygame.K_DOWN, pygame.K_s, direction_key))
            self.last_dash_ms = now

        # 4) 스페셜/스매시 사용: 게이지가 충분히 찼을 때만 사용
        # - 기본: 90% 이상 또는 special_ready
        # - 드라이브용 버퍼 유지: 대쉬로 게이지를 남겨뒀다면 남은 게이지가 다시 70% 이상일 때만 시도
        gauge_ready = state.get("special_ready", False)
        gauge_ratio = state.get("special_gauge", 0) / max(1, state.get("special_max", 1))
        high_enough = gauge_ratio >= 0.9 or (gauge_ratio >= 0.7 and gauge_ready)

        if high_enough and now - self.last_special_ms > 1200:
            pressed.add(pygame.K_SPACE)
            self.last_special_ms = now

        return pressed


_controller: PlayerAIController | None = None


def get_player_ai_controller() -> PlayerAIController:
    global _controller
    if _controller is None:
        _controller = PlayerAIController()
    return _controller
