"""
간단한 발토르(Blacksmith) 전용 플레이어 AI.

목표:
 - 공 차단 중심의 안전 운용(패들 위치 보정 + 기본 스윙 입력)
 - 최소한의 게이지/대쉬 사용으로 안정적인 라운드 진행
 - 스페이스 입력 한 가지에 여러 행동이 매핑되어 있으므로, 타이밍을 공 근접 시점에 한정한다.

환경 변수
 - PINGF_BS_AI_DEBUG=1 설정 시 디버그 로그 출력.
"""

from __future__ import annotations

import math
import os
import pygame


FRAME_MS = 1000 / 60.0
PLAYER_WALK_PX_PER_FRAME = 14.5  # 경험치 기반 기본 이동 속도(60fps 기준 px/frame)
SHIELD_WINDUP_FRAMES = 11  # 토르쉴드 전개까지 여유 프레임(약 180ms)
SHIELD_MIN_HOLD_MS = 260  # 최소 유지 시간으로 토글 난조 방지
SHIELD_ALIGN_MARGIN = 1.65  # 패들 폭 대비 허용 폭
SHIELD_PREDICT_PADDING = 28  # 예측 오차 여유 px

AI_BS_DEBUG = os.environ.get("PINGF_BS_AI_DEBUG", "0").lower() not in ("0", "false", "off")


class BlacksmithAIController:
    def __init__(self) -> None:
        self.last_space_ms = 0
        self.last_dash_ms = 0
        self.last_shield_ms = 0
        self.mode = "guard"  # guard | build
        self.mode_changed_ms = 0
        self.build_plan: str | None = None  # "turret" | None
        self.MIN_GAUGE = {
            "turret": 120,
            "upgrade_turret": 120,
            "divine": 200,
            "upgrade_divine": 200,
        }
        self.hammer_charge_until_ms = 0
        self.hammer_charging = False
        self.last_action_ms = 0
        self.last_debug_ms = 0
        self.idle_frames = 0
        self.shield_hold_until_ms = 0
        self.initial_build_pending = False

    def on_stage_start(self) -> None:
        self.last_space_ms = 0
        self.last_dash_ms = 0
        self.last_shield_ms = 0
        self.mode = "build"  # 시작부터 청사진 우선
        self.mode_changed_ms = 0
        self.build_plan = "turret"
        self.hammer_charging = False
        self.hammer_charge_until_ms = 0
        self.last_action_ms = 0
        self.last_debug_ms = 0
        self.idle_frames = 0
        self.shield_hold_until_ms = 0
        self.initial_build_pending = True

    # 외부에서 빌드 청사진 강제 생성이 필요한지 확인할 때 사용
    def wants_blueprint(self, state: dict) -> bool:
        if self.mode != "build":
            return False
        plan = self.build_plan or "turret"
        min_g = self.MIN_GAUGE.get(plan, 0)
        gauge_ok = state.get("special_gauge", 0) >= min_g
        if plan == "turret":
            if state.get("turret_active", False):
                return False
            if state.get("blueprint_active", False):
                return False
            return gauge_ok
        elif plan == "divine":
            if state.get("divine_active", False):
                return False
            if state.get("divine_blueprint_active", False):
                return False
            return gauge_ok
        return False

    def decide(self, state: dict) -> set[int]:
        """단순 규칙 기반 입력 결정.

        state keys:
            now_ms, player_rect, ball_rect, ball_vel, width, height,
            is_waiting_for_serve, rolling_charges, rolling_active, rolling_stun,
        """

        now = state.get("now_ms", 0)
        player = state["player_rect"]
        ball = state["ball_rect"]
        vx, vy = state.get("ball_vel", (0.0, 0.0))
        width = state.get("width", 600)
        height = state.get("height", 800)
        stage_num = state.get("current_stage", -1)
        pressed: set[int] = set()
        margin = 24
        # 건설/쉴드 상태 플래그
        umbrella_open = state.get("umbrella_open", False)
        turret_active = state.get("turret_active", False)
        blueprint_active = state.get("blueprint_active", False)
        build_progress = state.get("build_progress", 0)
        build_needed = state.get("build_needed", 0)
        shield_open_need = False  # 기본값: 가드 모드에서 계산
        shield_can_toggle = False
        ball_moving_away = False
        if turret_active or blueprint_active:
            self.initial_build_pending = False
        distance_to_paddle = player.top - ball.centery
        time_to_paddle_frames = float("inf")
        if vy > 0 and distance_to_paddle > 0:
            time_to_paddle_frames = distance_to_paddle / max(vy, 1e-3)
        # 공이 패들선에 도달할 때의 예상 X 좌표와 이동/전개에 필요한 시간 계산
        predicted_x_at_paddle = ball.centerx
        if vy > 0 and time_to_paddle_frames != float("inf"):
            predicted_x_at_paddle = ball.centerx + vx * time_to_paddle_frames
        predicted_x_at_paddle = max(margin, min(width - margin, predicted_x_at_paddle))
        horizontal_gap = abs(predicted_x_at_paddle - player.centerx)
        walk_frames_needed = horizontal_gap / PLAYER_WALK_PX_PER_FRAME
        reaction_frames = SHIELD_WINDUP_FRAMES + max(0.0, walk_frames_needed - 4.0)
        predict_aligned = horizontal_gap <= player.width * SHIELD_ALIGN_MARGIN + SHIELD_PREDICT_PADDING
        time_to_paddle_ms = time_to_paddle_frames * FRAME_MS
        ball_moving_away = (
            vy <= 0
            or distance_to_paddle > height * 0.52
            or abs(predicted_x_at_paddle - player.centerx) > player.width * 1.9
        )

        # --- 모드 전환 로직 -------------------------------------------------
        # 포탑/디바인스톤 관련 자동 모드 전환.
        now_ms = state.get("now_ms", 0)
        gauge = state.get("special_gauge", 0)
        # 우선순위: 포탑 없으면 포탑, 포탑 있으면 디바인스톤
        turret_level = state.get("turret_level", 1)
        turret_overdrive = state.get("turret_overdrive_ready", False)
        divine_reinforced = state.get("divine_reinforced", False)
        early_stage = stage_num >= 0 and stage_num <= 1
        early_phase_two = stage_num >= 0 and stage_num <= 2
        # 건설을 시도하기에 안전한 창: 공이 위로 올라가거나, 내려오는 중이어도 여유 프레임이 충분하고 높이가 높을 때만 허용
        recent_launch_build = early_phase_two and vy < 0 and ball.centery < height * 0.82
        build_window_safe = (
            state.get("is_waiting_for_serve", False)
            or recent_launch_build
            or (vy < 0 and ball.centery < height * 0.6)
            or (vy > 0 and time_to_paddle_frames > 70 and ball.centery < height * 0.45)
        )
        early_stage_build_ok = (
            state.get("is_waiting_for_serve", False)
            or (vy <= 0 and ball.centery < height * 0.5)
            or ball.centery < height * 0.35
            or recent_launch_build
        )
        allow_build_stage = ((not early_stage) or early_stage_build_ok) and build_window_safe
        gauge_goal = self.MIN_GAUGE["turret"]
        if turret_active:
            gauge_goal = self.MIN_GAUGE["divine"]
            if state.get("divine_active", False):
                gauge_goal = max(100, int(self.MIN_GAUGE["turret"] * 0.9))

        if allow_build_stage and self.mode == "guard" and not turret_active and gauge >= 120:
            self.mode = "build"
            self.mode_changed_ms = now_ms
            self.build_plan = "turret"
            if AI_BS_DEBUG:
                print(f"[BS_AI] switch→build(turret) gauge={gauge}")
        elif allow_build_stage and self.mode == "guard" and turret_active and not state.get("divine_active", False) and gauge >= 200:
            self.mode = "build"
            self.mode_changed_ms = now_ms
            self.build_plan = "divine"
            if AI_BS_DEBUG:
                print(f"[BS_AI] switch→build(divine) gauge={gauge}")
        elif (not early_stage) and self.mode == "guard" and turret_active and not turret_overdrive and turret_level < state.get("turret_level_max", 3) and gauge >= 120:
            # 포탑 강화(레벨업) 목적
            self.mode = "build"
            self.mode_changed_ms = now_ms
            self.build_plan = "upgrade_turret"
            if AI_BS_DEBUG:
                print(f"[BS_AI] switch→build(upgrade turret) lvl={turret_level} gauge={gauge}")
        elif (not early_stage) and self.mode == "guard" and state.get("divine_active", False) and not divine_reinforced and gauge >= 200:
            self.mode = "build"
            self.mode_changed_ms = now_ms
            self.build_plan = "upgrade_divine"
            if AI_BS_DEBUG:
                print(f"[BS_AI] switch→build(upgrade divine) gauge={gauge}")

        # 게이지가 부족해지면 빌드 모드 중단 (예: 긴교전 중)
        plan_min_g = self.MIN_GAUGE.get(self.build_plan, 0)
        if (
            self.mode == "build"
            and not self.initial_build_pending
            and gauge < max(40, plan_min_g * 0.6)
            and not state.get("blueprint_active", False)
            and not state.get("divine_blueprint_active", False)
        ):
            self.mode = "guard"
            self.build_plan = None
            self.mode_changed_ms = now_ms
            if AI_BS_DEBUG:
                print(f"[BS_AI] abort build (gauge low {gauge}) → guard")

        # build 모드 종료 조건: 포탑 완성 or 블루프린트 실패/시간 초과
        if self.mode == "build":
            timeout_ms = 6000 if early_stage else (12000 if (self.build_plan in ("upgrade_turret", "upgrade_divine")) else 8000)
            done = False
            if self.build_plan == "turret" and turret_active:
                done = True
            elif self.build_plan == "divine" and state.get("divine_active", False):
                done = True
            elif self.build_plan == "upgrade_turret" and (turret_level >= state.get("turret_level_max", 3) or turret_overdrive):
                done = True
            elif self.build_plan == "upgrade_divine" and divine_reinforced:
                done = True

            if done:
                self.mode = "guard"
                self.mode_changed_ms = now_ms
                self.build_plan = None
                if AI_BS_DEBUG:
                    print("[BS_AI] build/upgrade done → guard")
            elif now_ms - self.mode_changed_ms > timeout_ms:
                self.mode = "guard"
                self.mode_changed_ms = now_ms
                self.build_plan = None
                if AI_BS_DEBUG:
                    print("[BS_AI] build timeout → guard")

        # 방패로 한 차례 반격한 직후, 공이 멀어졌을 때 초반 건설 가속
        if (
            self.mode == "guard"
            and early_phase_two
            and umbrella_open
            and ball_moving_away
            and not turret_active
            and not blueprint_active
            and gauge >= self.MIN_GAUGE.get("turret", 120)
            and allow_build_stage
        ):
            self.mode = "build"
            self.mode_changed_ms = now_ms
            self.build_plan = "turret"
            if AI_BS_DEBUG:
                print("[BS_AI] shield reflect → build window")

        # 1) 서브 대기 시: 청사진을 먼저 시도하고 동시에 서브 입력도 넣어 지연 방지
        if state.get("is_waiting_for_serve", False):
            if self.initial_build_pending and not turret_active and not blueprint_active:
                pressed.update((pygame.K_DOWN, pygame.K_SPACE))
                return pressed
            pressed.add(pygame.K_SPACE)
            return pressed

        # 2) 기본 위치 목표: 공 예상 X
        target_x = ball.centerx
        if abs(vy) > 1e-3:
            dist_y = (player.top - ball.centery) if vy > 0 else (player.bottom - ball.centery)
            t = max(0.0, dist_y / vy) if vy != 0 else 0.0
            target_x = ball.centerx + vx * t
        target_x = max(margin, min(width - margin, target_x))

        # 디바인쉴드 발동 준비 시 스톤 위치로 이동 우선
        if state.get("divine_shield_ready", False) and state.get("divine_rect") is not None:
            target_x = state["divine_rect"].centerx
        # 포탑 오버드라이브 준비 시 포탑 근처 이동
        elif state.get("turret_overdrive_ready", False) and state.get("turret_rect") is not None:
            target_x = state["turret_rect"].centerx

        # 빌드/업그레이드 플랜일 때는 건물 위치를 우선 목표로 잡아 이동 안정화
        if self.mode == "build":
            if self.build_plan in ("turret", "upgrade_turret"):
                tx = state.get("blueprint_rect") or state.get("turret_rect")
                if tx is not None:
                    target_x = tx.centerx
            elif self.build_plan in ("divine", "upgrade_divine"):
                dx_rect = state.get("divine_blueprint_rect") or state.get("divine_rect")
                if dx_rect is not None:
                    target_x = dx_rect.centerx

        if player.centerx < target_x - 8:
            pressed.update((pygame.K_RIGHT, pygame.K_d))
        elif player.centerx > target_x + 8:
            pressed.update((pygame.K_LEFT, pygame.K_a))

        # 3) 스윙/방어 타이밍: 공이 패들 가까이 내려올 때 Space
        paddle_half = player.width * 0.5
        ball_radius = getattr(ball, "width", player.width) * 0.5
        perfect_window = (
            0 < distance_to_paddle <= 22
            and vy > 0
            and abs(ball.centerx - player.centerx) <= paddle_half + ball_radius + 18
        )
        # 공이 급락하면 건설 모드 즉시 중단하고 방어로 전환
        incoming_fast = vy > 0 and (time_to_paddle_frames < 40 or distance_to_paddle < height * 0.28)
        if self.mode == "build" and incoming_fast:
            self.mode = "guard"
            self.build_plan = None
            self.mode_changed_ms = now_ms
            if AI_BS_DEBUG:
                print(f"[BS_AI] abort build (ball close t={time_to_paddle_frames:.1f}f dy={distance_to_paddle:.1f})")

        # --- 행동: 모드에 따른 Space/DOWN 입력 ---------------------------
        # 해머쇼크 차지 유지/해제 관리 (build 모드 제외)
        if self.hammer_charging:
            if now < self.hammer_charge_until_ms:
                pressed.add(pygame.K_SPACE)
            else:
                # 홀드 해제 → 다음 프레임에서 space_just_released 처리되도록 입력 중단
                self.hammer_charging = False
            # 차지 중에는 방어/스윙 자동 입력을 최소화
            if pressed:
                self.last_action_ms = now
            return pressed

        if self.mode == "guard":
            # 토르쉴드 우선: 공이 근접·고속 하강 또는 X 근접 시 즉시 전개, 0.5초는 유지
            gauge_hungry = gauge < gauge_goal
            gauge_shield_window = (
                gauge_hungry
                and vy > 0
                and distance_to_paddle < 320
                and abs(ball.centerx - player.centerx) <= player.width * 1.6
            )
            # 공이 다른 방향으로 향하거나 너무 멀리 떨어지면 빠르게 쉴드 해제
            ball_moving_away = (
                vy <= 0
                or distance_to_paddle > height * 0.52
                or abs(predicted_x_at_paddle - player.centerx) > player.width * 1.9
            )
            predictive_guard_window = (
                vy > 0
                and predict_aligned
                and time_to_paddle_frames < 120
                and (
                    time_to_paddle_frames <= reaction_frames + 8
                    or distance_to_paddle < height * 0.42
                    or vy > 10
                )
            )
            need_windup_open = vy > 0 and predict_aligned and time_to_paddle_frames <= reaction_frames + 6
            fast_lane_threat = distance_to_paddle < 200 and vy > 7 and predict_aligned
            shield_open_need = gauge_shield_window or predictive_guard_window or need_windup_open or fast_lane_threat
            # 가까운 낙하에 대한 보수적 보정
            if not shield_open_need and distance_to_paddle < 130 and abs(ball.centerx - player.centerx) < player.width * 1.2:
                shield_open_need = True
            shield_can_toggle = now - self.last_shield_ms > 150
            if shield_open_need and not umbrella_open and shield_can_toggle:
                pressed.update((pygame.K_UP, pygame.K_w))
                self.last_space_ms = now
                self.last_shield_ms = now
                hold_ms = SHIELD_MIN_HOLD_MS + int(min(320, time_to_paddle_ms * 0.6))
                self.shield_hold_until_ms = max(self.shield_hold_until_ms, now + hold_ms)
                if AI_BS_DEBUG:
                    print(f"[BS_AI] shield OPEN stage={stage_num} dy={distance_to_paddle:.1f} dx={ball.centerx-player.centerx:.1f} vy={vy:.2f}")
            elif (
                umbrella_open
                and now > self.shield_hold_until_ms
                and (ball_moving_away or not shield_open_need)
                and shield_can_toggle
                and (now - self.last_shield_ms > 180)
            ):
                pressed.update((pygame.K_UP, pygame.K_w))
                self.last_space_ms = now
                self.last_shield_ms = now
                self.shield_hold_until_ms = 0
                if AI_BS_DEBUG:
                    print(f"[BS_AI] shield CLOSE stage={stage_num} away={ball_moving_away}")
            elif umbrella_open and shield_open_need:
                # 위협이 지속되면 최소 유지 시간을 갱신해 미리 닫히지 않도록 함
                extra_hold_ms = SHIELD_MIN_HOLD_MS + int(min(260, time_to_paddle_ms * 0.4))
                self.shield_hold_until_ms = max(self.shield_hold_until_ms, now + extra_hold_ms)

            # 쉴드가 열렸으면 스윙은 생략해 중복 Space를 줄인다.
            allow_swing = not umbrella_open

            # 기본 스윙
            if allow_swing and perfect_window and now - self.last_space_ms > 80:
                pressed.add(pygame.K_SPACE)
                if ball.centerx < player.centerx:
                    pressed.add(pygame.K_LEFT)
                else:
                    pressed.add(pygame.K_RIGHT)
                self.last_space_ms = now
                if AI_BS_DEBUG:
                    print(
                        f"[BS_AI] swing dy={distance_to_paddle:.1f} dx={ball.centerx-player.centerx:.1f} "
                        f"vx={vx:.2f} vy={vy:.2f}"
                    )

            # 강화디바인스톤 이후: 토르쉴드 검기 사용 (쉴드 열린 상태에서 스페이스 스윙)
            if (
                divine_reinforced
                and umbrella_open
                and now - self.last_space_ms > 220
                and distance_to_paddle < 320
            ):
                pressed.add(pygame.K_SPACE)
                dir_key = pygame.K_LEFT if ball.centerx < player.centerx else pygame.K_RIGHT
                pressed.add(dir_key)
                self.last_space_ms = now

            # 쉴드가 열려 있어도 공으로 이동하도록 좌우 입력 유지
            if umbrella_open:
                if player.centerx < target_x - 6:
                    pressed.update((pygame.K_RIGHT, pygame.K_d))
                elif player.centerx > target_x + 6:
                    pressed.update((pygame.K_LEFT, pygame.K_a))

            # 디바인쉴드 발동: 준비 완료 + 스톤 근처일 때 스페이스
            if (
                state.get("divine_shield_ready", False)
                and state.get("divine_rect") is not None
            ):
                dx = abs(player.centerx - state["divine_rect"].centerx)
                dy_front = player.bottom - state["divine_rect"].top
                if dx <= state.get("build_radius", 80) and dy_front >= -12:
                    pressed.add(pygame.K_SPACE)

            # 포탑 오버드라이브 준비 시 가까우면 Space로 점화
            if (
                state.get("turret_overdrive_ready", False)
                and state.get("turret_rect") is not None
                and abs(player.centerx - state["turret_rect"].centerx) <= state.get("build_radius", 80)
                and not umbrella_open
                and now - self.last_space_ms > 250
            ):
                pressed.add(pygame.K_SPACE)
                self.last_space_ms = now
                if AI_BS_DEBUG:
                    print("[BS_AI] trigger overdrive")

            # 해머쇼크: 모든 건물 강화 후 여유 게이지가 충분하면 차지 시작
            fully_upgraded = (
                state.get("divine_reinforced", False)
                and turret_level >= state.get("turret_level_max", 3)
            )
            if (
                fully_upgraded
                and not umbrella_open
                and not blueprint_active
                and not state.get("divine_blueprint_active", False)
                and state.get("divine_active", False)
                and gauge >= 260
                and now - self.last_space_ms > 300
                and not state.get("rolling_active", False)
                and stage_num >= 3  # 초기 라운드에서는 차지 금지
            ):
                # 스테이지 3 차지를 노릴 여유(게이지 320 이상)이면 2800ms, 아니면 1900ms 홀드
                hold_ms = 2800 if gauge >= 320 else 1900
                self.hammer_charging = True
                self.hammer_charge_until_ms = now + hold_ms
                pressed.add(pygame.K_SPACE)
                self.last_space_ms = now
                if AI_BS_DEBUG:
                    print(f"[BS_AI] hammer shock charge start (hold {hold_ms}ms, gauge={gauge})")

        else:  # build 모드
            if self.build_plan == "turret":
                if not blueprint_active and not turret_active:
                    pressed.update((pygame.K_DOWN, pygame.K_SPACE))
                    if AI_BS_DEBUG and now - self.mode_changed_ms < 400:
                        print("[BS_AI] open build HUD (turret)")
                else:
                    pressed.add(pygame.K_DOWN)
                    # 청사진이 있으면 그 위치로 정렬해 떨림 방지
                    if blueprint_active and state.get("blueprint_rect") is not None:
                        bx = state["blueprint_rect"].centerx
                        if player.centerx < bx - 4:
                            pressed.update((pygame.K_RIGHT, pygame.K_d))
                        elif player.centerx > bx + 4:
                            pressed.update((pygame.K_LEFT, pygame.K_a))
                if umbrella_open and now - self.last_space_ms > 200:
                    pressed.add(pygame.K_SPACE)
                    self.last_space_ms = now
                    if AI_BS_DEBUG:
                        print("[BS_AI] close shield for build")
            elif self.build_plan == "divine":
                if not state.get("divine_blueprint_active", False) and not state.get("divine_active", False):
                    pressed.update((pygame.K_DOWN, pygame.K_SPACE))
                    if AI_BS_DEBUG and now - self.mode_changed_ms < 400:
                        print("[BS_AI] open build HUD (divine)")
                else:
                    pressed.add(pygame.K_DOWN)
                if umbrella_open and now - self.last_space_ms > 200:
                    pressed.add(pygame.K_SPACE)
                    self.last_space_ms = now
            elif self.build_plan == "upgrade_turret":
                pressed.add(pygame.K_DOWN)
                if state.get("turret_rect"):
                    if player.centerx < state["turret_rect"].centerx - 6:
                        pressed.add(pygame.K_RIGHT)
                    elif player.centerx > state["turret_rect"].centerx + 6:
                        pressed.add(pygame.K_LEFT)
                if umbrella_open and now - self.last_space_ms > 200:
                    pressed.add(pygame.K_SPACE)
                    self.last_space_ms = now
                    if AI_BS_DEBUG:
                        print("[BS_AI] close shield for upgrade")
            elif self.build_plan == "upgrade_divine":
                pressed.add(pygame.K_DOWN)
                if state.get("divine_rect"):
                    if player.centerx < state["divine_rect"].centerx - 6:
                        pressed.add(pygame.K_RIGHT)
                    elif player.centerx > state["divine_rect"].centerx + 6:
                        pressed.add(pygame.K_LEFT)
                if umbrella_open and now - self.last_space_ms > 200:
                    pressed.add(pygame.K_SPACE)
                    self.last_space_ms = now
                    if AI_BS_DEBUG:
                        print("[BS_AI] close shield for divine upgrade")


        # 4) 위험 시 간단 대쉬(게이지 아낀다: 최소 조건)
        can_dash = (
            state.get("rolling_charges", 0) > 0
            and not state.get("rolling_active", False)
            and state.get("rolling_stun", 0) <= 0
            and now - self.last_dash_ms > 900
        )
        danger = distance_to_paddle < height * 0.35 and abs(ball.centerx - player.centerx) > 120 and vy > 8
        conserve_dash = early_phase_two and gauge >= 140
        panic_lane = distance_to_paddle < height * 0.22 and abs(ball.centerx - player.centerx) > player.width * 0.9 and vy > 10
        wants_dash = can_dash and danger and self.mode == "guard"
        if wants_dash and conserve_dash and not panic_lane:
            wants_dash = False  # 초반에는 게이지가 충분해도 풀 대쉬 자제
        if wants_dash and (umbrella_open or shield_open_need):
            wants_dash = False  # 쉴드로 막을 수 있으면 우선 사용
        if wants_dash:
            dir_key = pygame.K_RIGHT if ball.centerx > player.centerx else pygame.K_LEFT
            pressed.update((pygame.K_DOWN, dir_key))
            self.last_dash_ms = now
            if AI_BS_DEBUG:
                print(f"[BS_AI] dash dir={'R' if dir_key==pygame.K_RIGHT else 'L'} dy={distance_to_paddle:.1f}")
        # 쉴드 펼친 상태에서 공이 멀어지고 빠르게 하강하면 즉시 쉴드 닫고 대쉬(하프대쉬 포함) 시도
        if umbrella_open and ball_moving_away and can_dash and danger and panic_lane:
            if shield_can_toggle:
                pressed.update((pygame.K_UP, pygame.K_w))
                self.last_shield_ms = now
            pressed.update((pygame.K_DOWN, pygame.K_RIGHT if ball.centerx > player.centerx else pygame.K_LEFT))

        # 5) 무행동 안전망: 1.2초 이상 입력이 없으면 기본 이동/스윙 보정
        if not pressed and not state.get("is_waiting_for_serve", False):
            inactive_ms = now - self.last_action_ms
            if inactive_ms > 1200:
                if player.centerx < target_x - 4:
                    pressed.update((pygame.K_RIGHT, pygame.K_d))
                elif player.centerx > target_x + 4:
                    pressed.update((pygame.K_LEFT, pygame.K_a))
                if distance_to_paddle < 140 and vy > 0:
                    pressed.add(pygame.K_SPACE)
                    self.last_space_ms = now
                if AI_BS_DEBUG:
                    print(f"[BS_AI] idle failsafe inject (inactive {inactive_ms}ms stage={stage_num})")

        # 6) 디버그: 초반(스테이지1) 관찰용 간이 로그 – 0.8초마다 한 번
        if AI_BS_DEBUG and stage_num == 1:
            if now - self.last_debug_ms > 800:
                self.last_debug_ms = now
                print(
                    f"[BS_AI] tick stage1 mode={self.mode} shield={umbrella_open} "
                    f"gauge={gauge:.0f} pos=({player.centerx},{player.centery}) "
                    f"ball=({ball.centerx},{ball.centery}) v=({vx:.1f},{vy:.1f})"
                )

        if pressed:
            self.last_action_ms = now
        return pressed


_controller: BlacksmithAIController | None = None


def get_blacksmith_ai_controller() -> BlacksmithAIController:
    global _controller
    if _controller is None:
        _controller = BlacksmithAIController()
    return _controller
