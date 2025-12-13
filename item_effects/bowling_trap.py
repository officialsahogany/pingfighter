"""볼링트랩 - 코만도 전용 바닥 트랩 화기류.

플레이어 진영에 설치하여 보스의 공을 포획 후 4배 속도로 발사.
보스가 가드 시 라그나로크 해머 수준의 긴 넉백과 스턴 효과 발생.
"""
from __future__ import annotations

import math
import random
import sys
from typing import Callable, Dict, List, Optional, Tuple

import pygame

from config.constants import WIDTH, HEIGHT, TARGET_FPS

# 프레임 상수
FPS = TARGET_FPS


class BowlingTrap:
    """볼링트랩 화기류 클래스.

    - 탄환: 3개
    - 설치 시간: 0.8초 (48프레임)
    - 포획 후 발사 준비: 1.5초 (90프레임)
    - 발사 속도: 공 속도 4배
    - 보스 가드 시: 라그나로크급 넉백 + 스턴
    """

    MAX_AMMO = 3
    INSTALL_FRAMES = 48  # 0.8초 설치 시간
    CAPTURE_LAUNCH_FRAMES = 90  # 1.5초 포획→발사 애니메이션
    LAUNCH_SPEED_MULTIPLIER = 4.0  # 4배 빠른 속도
    COOLDOWN_FRAMES = 120  # 2초 쿨다운
    CONTROL_LOCK_FRAMES = 30  # 0.5초 조작 불능

    # 트랩 크기
    TRAP_WIDTH = 60
    TRAP_HEIGHT = 20

    # 집게 크기
    CLAW_WIDTH = 15
    CLAW_HEIGHT = 25

    # 넉백/스턴 설정 (라그나로크 해머 수준)
    KNOCKBACK_POWER = 22.0  # 라그나로크 수준의 긴 넉백
    STUN_DURATION = 60  # 1초 스턴
    GUARD_SPEED_REDUCTION = 0.7  # 보스가 막았을 때 공 속도 30% 감소 (원래 속도의 70%)

    def __init__(self) -> None:
        self.equipped: bool = False
        self.active: bool = False
        self.ammo_count: int = self.MAX_AMMO
        self.cooldown_timer: int = 0
        self.control_lock_timer: int = 0

        # 설치 상태
        self.installing: bool = False
        self.install_timer: int = 0
        self.install_target_x: float = 0
        self.install_target_y: float = 0

        # 트랩 목록 (설치된 트랩들)
        self.traps: List[Dict] = []

        # 발사된 공 추적 (볼링트랩에서 발사된 공인지 확인용)
        self.launched_ball_active: bool = False
        self.launched_ball_speed_backup: float = 0

        # 공 포획 상태 (포획 중일 때 공은 트랩 위치에 고정)
        self.ball_captured: bool = False
        self.captured_ball_position: Optional[Tuple[float, float]] = None

        # 폭발 이펙트
        self.explosions: List[Dict] = []

        # 화염 궤적 (발사된 공 추적)
        self.flame_trails: List[Dict] = []
        self.flame_trail_active: bool = False

        # 디버그
        self.debug_enabled: bool = True

    def _debug(self, message: str) -> None:
        if self.debug_enabled:
            print(f"[BowlingTrap] {message}")

    def reset(self) -> None:
        """상태 초기화."""
        self.traps.clear()
        self.cooldown_timer = 0
        self.control_lock_timer = 0
        self.installing = False
        self.install_timer = 0
        self.launched_ball_active = False
        self.launched_ball_speed_backup = 0
        self.ball_captured = False
        self.captured_ball_position = None
        self.explosions.clear()
        self.flame_trails.clear()
        self.flame_trail_active = False

    def equip(self) -> None:
        """볼링트랩 장착."""
        self.equipped = True
        self.active = True
        self._debug("equip → 볼링트랩 장착!")

    def unequip(self) -> None:
        """볼링트랩 해제."""
        self.equipped = False
        self.active = False
        self._debug("unequip → 볼링트랩 해제")

    def reload(self, *, track_reload: bool = False) -> None:
        """재장전."""
        self.ammo_count = self.MAX_AMMO
        self.active = True
        self._debug(f"reload → ammo={self.ammo_count}/{self.MAX_AMMO}")

        if track_reload:
            tracker = self._get_reload_tracker()
            if tracker:
                tracker("bowling_trap")

    def can_install(self) -> bool:
        """설치 가능 여부."""
        return (
            self.equipped
            and self.active
            and self.ammo_count > 0
            and self.cooldown_timer <= 0
            and self.control_lock_timer <= 0
            and not self.installing
        )

    def start_install(self, player_rect: pygame.Rect) -> bool:
        """트랩 설치 시작."""
        if not self.can_install():
            return False

        # 플레이어 발 아래에 설치
        self.install_target_x = player_rect.centerx
        self.install_target_y = player_rect.bottom + 5

        # 설치 범위 제한 (플레이어 진영 = 화면 하단 40%)
        min_y = HEIGHT * 0.6
        if self.install_target_y < min_y:
            self._debug("install failed → 플레이어 진영 밖")
            return False

        self.installing = True
        self.install_timer = self.INSTALL_FRAMES
        self.control_lock_timer = self.INSTALL_FRAMES + 10

        # 설치 사운드 재생
        self._play_install_sound()

        self._debug(f"install started → pos=({self.install_target_x:.1f}, {self.install_target_y:.1f})")
        return True

    def _complete_install(self) -> None:
        """설치 완료 처리."""
        trap = {
            "x": self.install_target_x,
            "y": self.install_target_y,
            "active": True,
            "state": "waiting",  # waiting, capturing, launching
            "timer": 0,
            "captured_ball": None,
            "claw_angle": 0,  # 집게 열림 각도 (0=닫힘, 1=완전열림)
            "launch_direction": 0,  # 발사 방향 (-1=좌, 0=직진, 1=우)
        }
        self.traps.append(trap)
        self.ammo_count -= 1
        self.cooldown_timer = self.COOLDOWN_FRAMES
        self.installing = False

        if self.ammo_count <= 0:
            self.active = False

        self._debug(f"install complete → ammo={self.ammo_count}, traps={len(self.traps)}")
        print(f"🎳 볼링트랩 설치 완료! 남은 트랩: {self.ammo_count}")

    def update(
        self,
        player_rect: Optional[pygame.Rect],
        ball_rect: Optional[pygame.Rect],
        ball_vel: Optional[Tuple[float, float]],
    ) -> Optional[Dict]:
        """매 프레임 업데이트.

        Returns:
            발사 이벤트 딕셔너리 (발사 발생 시) 또는 None
        """
        # 타이머 업데이트
        if self.cooldown_timer > 0:
            self.cooldown_timer -= 1
        if self.control_lock_timer > 0:
            self.control_lock_timer -= 1

        # 설치 진행
        if self.installing:
            self.install_timer -= 1
            if self.install_timer <= 0:
                self._complete_install()

        # 트랩 업데이트
        launch_event = None
        for trap in self.traps[:]:
            if not trap["active"]:
                self.traps.remove(trap)
                continue

            if trap["state"] == "waiting":
                # 공 포획 체크
                if ball_rect and ball_vel:
                    trap_rect = pygame.Rect(
                        trap["x"] - self.TRAP_WIDTH // 2,
                        trap["y"] - self.TRAP_HEIGHT // 2,
                        self.TRAP_WIDTH,
                        self.TRAP_HEIGHT + 20  # 위쪽 감지 영역 확장
                    )

                    # 공이 아래로 내려오고 있을 때만 포획 (보스가 친 공)
                    if trap_rect.colliderect(ball_rect) and ball_vel[1] > 0:
                        self._capture_ball(trap, ball_rect, ball_vel)

            elif trap["state"] == "capturing":
                # 포획→발사 애니메이션
                trap["timer"] -= 1
                progress = 1.0 - (trap["timer"] / self.CAPTURE_LAUNCH_FRAMES)

                # 집게 닫힘 애니메이션 (0~0.3초 구간)
                if progress < 0.2:
                    trap["claw_angle"] = 1.0 - (progress / 0.2)  # 열림→닫힘
                elif progress < 0.5:
                    trap["claw_angle"] = 0  # 닫힌 상태 유지
                else:
                    # 발사 준비 (집게가 뒤로 당겨지는 느낌)
                    trap["claw_angle"] = -0.3 * ((progress - 0.5) / 0.5)

                if trap["timer"] <= 0:
                    launch_event = self._launch_ball(trap)
                    trap["active"] = False

            elif trap["state"] == "launching":
                # 발사 후 트랩 제거
                trap["active"] = False

        return launch_event

    def _capture_ball(
        self,
        trap: Dict,
        ball_rect: pygame.Rect,
        ball_vel: Tuple[float, float],
    ) -> None:
        """공 포획 처리."""
        trap["state"] = "capturing"
        trap["timer"] = self.CAPTURE_LAUNCH_FRAMES
        trap["captured_ball"] = {
            "original_speed": math.hypot(ball_vel[0], ball_vel[1]),
            "original_vel": ball_vel,
        }
        trap["claw_angle"] = 1.0  # 집게 완전 열림

        # 발사 방향 결정 (랜덤하게 좌/직진/우)
        trap["launch_direction"] = random.choice([-1, 0, 0, 0, 1])  # 직진 확률 높음

        # 공 포획 상태 설정 - 공이 트랩 위치에 고정됨
        self.ball_captured = True
        self.captured_ball_position = (trap["x"], trap["y"] - 15)  # 트랩 위쪽에 공 고정

        # 포획 사운드 재생
        self._play_capture_sound()

        self._debug(f"ball captured → speed={trap['captured_ball']['original_speed']:.1f}")
        print("🎳 볼링트랩이 공을 포획!")

    def _launch_ball(self, trap: Dict) -> Dict:
        """공 발사 처리."""
        captured = trap["captured_ball"]
        original_speed = captured["original_speed"]

        # 4배 빠른 속도
        launch_speed = original_speed * self.LAUNCH_SPEED_MULTIPLIER

        # 발사 각도 계산 (위쪽으로, 약간 좌우 변동 가능)
        base_angle = -math.pi / 2  # 위쪽
        angle_offset = trap["launch_direction"] * (math.pi / 8)  # 최대 ±22.5도
        launch_angle = base_angle + angle_offset

        vel_x = math.cos(launch_angle) * launch_speed
        vel_y = math.sin(launch_angle) * launch_speed

        self.launched_ball_active = True
        self.launched_ball_speed_backup = original_speed

        # 공 포획 상태 해제 - 공이 다시 움직임
        self.ball_captured = False
        self.captured_ball_position = None

        trap["state"] = "launching"

        # 폭발 이펙트 생성
        self._create_explosion(trap["x"], trap["y"])

        # 화염 궤적 활성화
        self.flame_trail_active = True

        self._debug(f"ball launched → speed={launch_speed:.1f} (4x), angle={math.degrees(launch_angle):.1f}°")
        print(f"🎳 볼링트랩 발사! 속도 {self.LAUNCH_SPEED_MULTIPLIER}배!")

        return {
            "type": "bowling_trap_launch",
            "vel_x": vel_x,
            "vel_y": vel_y,
            "speed": launch_speed,
            "from_trap": True,
            "knockback_power": self.KNOCKBACK_POWER,
            "stun_duration": self.STUN_DURATION,
        }

    def on_boss_guard(self) -> Dict:
        """보스가 볼링트랩 발사 공을 가드했을 때 호출.

        Returns:
            넉백/스턴 효과 정보
        """
        if not self.launched_ball_active:
            return {}

        self.launched_ball_active = False
        self.flame_trail_active = False  # 화염 궤적 비활성화

        self._debug("boss guarded → applying ragnarok-level knockback")
        print("🎳 볼링트랩 가드! 보스에게 강력한 넉백!")

        # 보스가 막았을 때 공 속도 감소 적용
        reduced_speed = self.launched_ball_speed_backup * self.GUARD_SPEED_REDUCTION

        return {
            "knockback_power": self.KNOCKBACK_POWER,
            "stun_duration": self.STUN_DURATION,
            "restore_speed": reduced_speed,
        }

    def on_ball_returned(self) -> float:
        """보스가 공을 쳤을 때 (가드 성공) 감소된 속도로 복원.

        Returns:
            감소된 공 속도 (원래 속도의 70%)
        """
        if self.launched_ball_active:
            self.launched_ball_active = False
            self.flame_trail_active = False  # 화염 궤적 비활성화
            return self.launched_ball_speed_backup * self.GUARD_SPEED_REDUCTION
        return 0

    def is_installing(self) -> bool:
        """설치 중인지 여부."""
        return self.installing

    def is_ball_captured(self) -> bool:
        """공이 트랩에 포획되어 있는지 여부."""
        return self.ball_captured

    def get_captured_ball_position(self) -> Optional[Tuple[float, float]]:
        """포획된 공의 위치 반환. 포획 중이 아니면 None."""
        if self.ball_captured and self.captured_ball_position:
            return self.captured_ball_position
        return None

    def get_install_progress(self) -> float:
        """설치 진행률 (0.0~1.0)."""
        if not self.installing:
            return 0.0
        return 1.0 - (self.install_timer / self.INSTALL_FRAMES)

    # -------------------------------------------------------------------------
    # 렌더링
    # -------------------------------------------------------------------------
    def draw_install_gauge(self, screen: pygame.Surface, player_rect: pygame.Rect) -> None:
        """설치 게이지 바 그리기 (플레이어 상단)."""
        if not self.installing:
            return

        progress = self.get_install_progress()

        # 게이지 바 위치 (플레이어 상단)
        gauge_width = 50
        gauge_height = 8
        gauge_x = player_rect.centerx - gauge_width // 2
        gauge_y = player_rect.top - 20

        # 배경
        pygame.draw.rect(screen, (40, 40, 40), (gauge_x, gauge_y, gauge_width, gauge_height))

        # 진행 바
        fill_width = int(gauge_width * progress)
        pygame.draw.rect(screen, (100, 200, 100), (gauge_x, gauge_y, fill_width, gauge_height))

        # 테두리
        pygame.draw.rect(screen, (150, 150, 150), (gauge_x, gauge_y, gauge_width, gauge_height), 1)

        # 텍스트 (한글 폰트 사용)
        try:
            import os
            font_path = os.path.join(
                os.path.dirname(os.path.dirname(__file__)),
                "NanumSquareB.ttf"
            )
            font = pygame.font.Font(font_path, 14)
            text = font.render("설치중...", True, (255, 255, 200))
            text_rect = text.get_rect(center=(gauge_x + gauge_width // 2, gauge_y - 10))
            screen.blit(text, text_rect)
        except Exception:
            pass

    def draw_install_pose(self, screen: pygame.Surface, player_rect: pygame.Rect) -> None:
        """설치 모션 그리기 - 고퀄리티 버전."""
        if not self.installing:
            return

        progress = self.get_install_progress()
        current_time = pygame.time.get_ticks()

        # 플레이어가 웅크리는 모션 (더 부드럽게)
        crouch_offset = int(8 * math.sin(progress * math.pi))

        # 손 위치 (바닥을 향함)
        hand_x = player_rect.centerx
        hand_y = player_rect.bottom + crouch_offset

        # === 설치 도구 그리기 (드릴/렌치 형태) ===
        tool_body_color = (100, 100, 110)
        tool_handle_color = (139, 90, 43)
        tool_metal_color = (180, 180, 190)

        # 도구 손잡이
        pygame.draw.rect(screen, tool_handle_color, (hand_x - 4, hand_y - 15, 8, 12))
        pygame.draw.rect(screen, (100, 60, 30), (hand_x - 4, hand_y - 15, 8, 12), 1)

        # 도구 몸체 (회전하는 드릴 느낌)
        rotation_angle = (current_time * 0.02) % (2 * math.pi)
        drill_x = hand_x
        drill_y = hand_y - 2

        # 드릴 비트 (회전 효과)
        for i in range(3):
            angle_offset = rotation_angle + i * (2 * math.pi / 3)
            bit_x = drill_x + int(3 * math.cos(angle_offset))
            bit_y = drill_y + int(2 * math.sin(angle_offset))
            pygame.draw.circle(screen, tool_metal_color, (bit_x, bit_y), 2)

        pygame.draw.circle(screen, tool_body_color, (drill_x, drill_y), 5)
        pygame.draw.circle(screen, (60, 60, 70), (drill_x, drill_y), 5, 1)

        # === 설치 진행 이펙트 ===
        # 1단계 (0~30%): 바닥 파기 - 먼지 파티클
        if progress < 0.3:
            dust_intensity = int(progress / 0.3 * 8) + 2
            for _ in range(dust_intensity):
                dust_x = hand_x + random.randint(-15, 15)
                dust_y = hand_y + random.randint(-3, 8)
                dust_size = random.randint(1, 3)
                dust_alpha = random.randint(100, 200)
                dust_color = (150 + random.randint(-20, 20), 130 + random.randint(-20, 20), 100 + random.randint(-20, 20))
                pygame.draw.circle(screen, dust_color, (dust_x, dust_y), dust_size)

        # 2단계 (30~70%): 트랩 조립 - 스파크
        elif progress < 0.7:
            spark_intensity = int((progress - 0.3) / 0.4 * 6) + 3
            for _ in range(spark_intensity):
                spark_x = hand_x + random.randint(-12, 12)
                spark_y = hand_y + random.randint(-5, 5)
                spark_size = random.randint(1, 3)
                # 노란색~주황색 스파크
                spark_color = (255, 200 + random.randint(-50, 50), 50 + random.randint(0, 100))
                pygame.draw.circle(screen, spark_color, (spark_x, spark_y), spark_size)

            # 금속 조립 선
            if int(current_time * 0.01) % 3 == 0:
                line_y = hand_y + random.randint(-3, 3)
                pygame.draw.line(screen, (200, 200, 210), (hand_x - 10, line_y), (hand_x + 10, line_y), 1)

        # 3단계 (70~100%): 완료 - 완성 글로우
        else:
            glow_intensity = int((progress - 0.7) / 0.3 * 255)
            glow_color = (100, 255, 100, min(glow_intensity, 150))

            # 글로우 서클
            glow_surface = pygame.Surface((40, 40), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, glow_color, (20, 20), 15)
            screen.blit(glow_surface, (hand_x - 20, hand_y - 15))

            # 완료 체크마크 (마지막 10%)
            if progress > 0.9:
                check_alpha = int((progress - 0.9) / 0.1 * 255)
                check_color = (100, 255, 100)
                pygame.draw.line(screen, check_color, (hand_x - 5, hand_y - 8), (hand_x, hand_y - 3), 2)
                pygame.draw.line(screen, check_color, (hand_x, hand_y - 3), (hand_x + 8, hand_y - 12), 2)

    def draw_traps(self, screen: pygame.Surface) -> None:
        """설치된 트랩들 그리기."""
        for trap in self.traps:
            if not trap["active"]:
                continue

            x = int(trap["x"])
            y = int(trap["y"])
            state = trap["state"]
            claw_angle = trap.get("claw_angle", 0)

            self._draw_single_trap(screen, x, y, state, claw_angle, trap)

    def _draw_single_trap(
        self,
        screen: pygame.Surface,
        x: int,
        y: int,
        state: str,
        claw_angle: float,
        trap_data: dict = None,
    ) -> None:
        """개별 트랩 그리기 - 고퀄리티 3D 스타일."""
        current_time = pygame.time.get_ticks()

        # === 그림자 (입체감) ===
        shadow_surface = pygame.Surface((self.TRAP_WIDTH + 10, 15), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surface, (0, 0, 0, 60), (5, 5, self.TRAP_WIDTH, 8))
        screen.blit(shadow_surface, (x - self.TRAP_WIDTH // 2 - 5, y + 2))

        # === 베이스 플레이트 (3D 효과) ===
        # 하단 (어두운 부분)
        base_dark = (50, 50, 60) if state == "waiting" else (70, 55, 40)
        base_rect_bottom = pygame.Rect(x - self.TRAP_WIDTH // 2, y - 2, self.TRAP_WIDTH, 8)
        pygame.draw.rect(screen, base_dark, base_rect_bottom)

        # 상단 (밝은 부분)
        base_color = (90, 90, 100) if state == "waiting" else (120, 95, 70)
        base_rect_top = pygame.Rect(x - self.TRAP_WIDTH // 2, y - 6, self.TRAP_WIDTH, 6)
        pygame.draw.rect(screen, base_color, base_rect_top)

        # 금속 테두리
        pygame.draw.rect(screen, (140, 140, 150), (x - self.TRAP_WIDTH // 2, y - 6, self.TRAP_WIDTH, 12), 1)

        # 볼링 레인 무늬 (나무 질감)
        for i in range(5):
            lane_x = x - 24 + i * 12
            lane_color = (110 + i * 5, 95 + i * 3, 75 + i * 2)
            pygame.draw.line(screen, lane_color, (lane_x, y - 5), (lane_x, y + 4), 2)

        # 볼트/리벳 디테일
        bolt_color = (70, 70, 80)
        bolt_highlight = (100, 100, 110)
        for bx in [x - 25, x + 25]:
            pygame.draw.circle(screen, bolt_color, (bx, y - 1), 3)
            pygame.draw.circle(screen, bolt_highlight, (bx - 1, y - 2), 1)

        # === 메커니즘 하우징 (중앙) ===
        # 메인 하우징 (3D 실린더 효과)
        housing_colors = [(45, 45, 55), (65, 65, 75), (85, 85, 95), (65, 65, 75)]
        for i, color in enumerate(housing_colors):
            offset = i - 1.5
            pygame.draw.circle(screen, color, (x + int(offset), y - 12), 10 - abs(i - 1))

        # 중앙 코어 (발광)
        if state == "waiting":
            core_color = (80, 200, 80)  # 녹색 대기
            pulse = int(20 * math.sin(current_time * 0.005))
            core_glow = (80 + pulse, 200 + pulse // 2, 80 + pulse)
        elif state == "capturing":
            core_color = (255, 150, 50)  # 주황색 포획
            pulse = int(40 * math.sin(current_time * 0.02))
            core_glow = (255, 150 + pulse, 50 + pulse)
        else:
            core_color = (200, 50, 50)  # 빨간색 발사
            core_glow = core_color

        pygame.draw.circle(screen, core_glow, (x, y - 12), 5)
        pygame.draw.circle(screen, (255, 255, 255), (x - 1, y - 13), 2)  # 하이라이트

        # === 집게 (고급 디자인) ===
        claw_open = max(0, claw_angle) * 28  # 열림 정도
        claw_back = min(0, claw_angle) * -18  # 뒤로 당겨짐

        # 집게 색상 (상태에 따라)
        if state == "capturing":
            claw_base = (200, 120, 60)
            claw_highlight = (240, 160, 100)
            claw_shadow = (140, 80, 40)
        else:
            claw_base = (130, 130, 140)
            claw_highlight = (170, 170, 180)
            claw_shadow = (90, 90, 100)

        # 좌측 집게 (다중 레이어)
        # 뒷면 (어두운)
        left_back = [
            (x - 28 - claw_open, y - 22 + claw_back),
            (x - 16 - claw_open * 0.6, y - 28 + claw_back),
            (x - 12, y - 8),
            (x - 22, y - 8),
        ]
        pygame.draw.polygon(screen, claw_shadow, left_back)

        # 앞면 (밝은)
        left_front = [
            (x - 26 - claw_open, y - 20 + claw_back),
            (x - 14 - claw_open * 0.5, y - 26 + claw_back),
            (x - 10, y - 6),
            (x - 20, y - 6),
        ]
        pygame.draw.polygon(screen, claw_base, left_front)
        pygame.draw.polygon(screen, claw_shadow, left_front, 2)

        # 집게 끝 톱니
        claw_tip_y = y - 20 + claw_back
        for i in range(3):
            tip_x = x - 24 - claw_open + i * 4
            tip_y = claw_tip_y - 3 + i * 2
            pygame.draw.polygon(screen, claw_highlight, [
                (tip_x, tip_y),
                (tip_x - 2, tip_y + 4),
                (tip_x + 2, tip_y + 4),
            ])

        # 우측 집게 (대칭)
        right_back = [
            (x + 28 + claw_open, y - 22 + claw_back),
            (x + 16 + claw_open * 0.6, y - 28 + claw_back),
            (x + 12, y - 8),
            (x + 22, y - 8),
        ]
        pygame.draw.polygon(screen, claw_shadow, right_back)

        right_front = [
            (x + 26 + claw_open, y - 20 + claw_back),
            (x + 14 + claw_open * 0.5, y - 26 + claw_back),
            (x + 10, y - 6),
            (x + 20, y - 6),
        ]
        pygame.draw.polygon(screen, claw_base, right_front)
        pygame.draw.polygon(screen, claw_shadow, right_front, 2)

        # 우측 톱니
        for i in range(3):
            tip_x = x + 24 + claw_open - i * 4
            tip_y = claw_tip_y - 3 + i * 2
            pygame.draw.polygon(screen, claw_highlight, [
                (tip_x, tip_y),
                (tip_x - 2, tip_y + 4),
                (tip_x + 2, tip_y + 4),
            ])

        # 집게 관절 (피벗 포인트)
        pygame.draw.circle(screen, (50, 50, 60), (x - 15, y - 8), 4)
        pygame.draw.circle(screen, (80, 80, 90), (x - 15, y - 8), 4, 1)
        pygame.draw.circle(screen, (50, 50, 60), (x + 15, y - 8), 4)
        pygame.draw.circle(screen, (80, 80, 90), (x + 15, y - 8), 4, 1)

        # === 대기 상태: 볼링핀 홀로그램 ===
        if state == "waiting":
            hologram_alpha = int(100 + 50 * math.sin(current_time * 0.008))
            hologram_surface = pygame.Surface((20, 30), pygame.SRCALPHA)

            # 핀 형태 (반투명 청록색)
            pin_color = (100, 255, 255, hologram_alpha)
            # 핀 머리
            pygame.draw.circle(hologram_surface, pin_color, (10, 6), 5)
            # 핀 목
            pygame.draw.rect(hologram_surface, pin_color, (8, 10, 4, 6))
            # 핀 몸통
            pygame.draw.polygon(hologram_surface, pin_color, [
                (6, 15), (14, 15), (16, 28), (4, 28)
            ])

            screen.blit(hologram_surface, (x - 10, y - 38))

            # 스캔 라인 효과
            scan_y = (current_time // 30) % 30
            pygame.draw.line(screen, (100, 255, 255, 80), (x - 10, y - 38 + scan_y), (x + 10, y - 38 + scan_y), 1)

        # === 포획 중: 공과 에너지 효과 ===
        if state == "capturing":
            # 포획 진행도 계산
            if trap_data:
                capture_progress = 1.0 - (trap_data.get("timer", 0) / self.CAPTURE_LAUNCH_FRAMES)
            else:
                capture_progress = 0.5

            # 공 위치 (떨림 + 압축 효과)
            shake_x = int(3 * math.sin(current_time * 0.05) * (1 - capture_progress))
            shake_y = int(2 * math.cos(current_time * 0.07) * (1 - capture_progress))
            ball_y = y - 18

            # 압축 효과 (발사 준비 시 공이 작아짐)
            ball_scale = 1.0 - capture_progress * 0.3
            ball_radius = int(10 * ball_scale)

            # 에너지 링
            if capture_progress > 0.3:
                ring_alpha = int((capture_progress - 0.3) / 0.7 * 200)
                ring_radius = int(15 + 10 * (1 - capture_progress))
                ring_surface = pygame.Surface((ring_radius * 2 + 10, ring_radius * 2 + 10), pygame.SRCALPHA)
                pygame.draw.circle(ring_surface, (255, 200, 100, ring_alpha), (ring_radius + 5, ring_radius + 5), ring_radius, 2)
                screen.blit(ring_surface, (x - ring_radius - 5 + shake_x, ball_y - ring_radius - 5 + shake_y))

            # 공 본체 (그라데이션 효과)
            ball_colors = [(180, 40, 40), (220, 60, 60), (255, 100, 100)]
            for i, color in enumerate(ball_colors):
                r = ball_radius - i * 2
                if r > 0:
                    pygame.draw.circle(screen, color, (x + shake_x, ball_y + shake_y), r)

            # 공 하이라이트
            pygame.draw.circle(screen, (255, 200, 200), (x - 3 + shake_x, ball_y - 3 + shake_y), max(1, ball_radius // 4))

            # 에너지 파티클
            particle_count = int(capture_progress * 12) + 3
            for i in range(particle_count):
                angle = (current_time * 0.01 + i * (2 * math.pi / particle_count)) % (2 * math.pi)
                dist = 15 + 8 * math.sin(current_time * 0.02 + i)
                px = x + int(math.cos(angle) * dist)
                py = ball_y + int(math.sin(angle) * dist * 0.6)
                particle_size = random.randint(1, 3)
                particle_color = (255, 200 + random.randint(-30, 30), 100 + random.randint(-30, 30))
                pygame.draw.circle(screen, particle_color, (px, py), particle_size)

            # 집게 압력 이펙트
            if capture_progress > 0.5:
                pressure_intensity = (capture_progress - 0.5) / 0.5
                for _ in range(int(pressure_intensity * 5)):
                    spark_x = x + random.randint(-25, 25)
                    spark_y = ball_y + random.randint(-10, 10)
                    pygame.draw.circle(screen, (255, 255, 200), (spark_x, spark_y), 1)

            # 발사 준비 경고
            if capture_progress > 0.8:
                warning_alpha = int((capture_progress - 0.8) / 0.2 * 255 * abs(math.sin(current_time * 0.03)))
                warning_surface = pygame.Surface((60, 20), pygame.SRCALPHA)
                pygame.draw.rect(warning_surface, (255, 100, 100, warning_alpha), (0, 0, 60, 20))
                screen.blit(warning_surface, (x - 30, y - 45))

    # -------------------------------------------------------------------------
    # 폭발 이펙트 & 화염 궤적
    # -------------------------------------------------------------------------
    def _create_explosion(self, x: float, y: float) -> None:
        """폭발 이펙트 생성."""
        explosion = {
            "x": x,
            "y": y,
            "timer": 45,  # 0.75초
            "max_timer": 45,
            "particles": [],
            "type": "launch",  # 발사 폭발
        }

        # 폭발 파티클 생성
        for _ in range(40):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(3, 12)
            explosion["particles"].append({
                "x": x,
                "y": y,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed - 2,  # 약간 위로
                "size": random.randint(3, 8),
                "color_type": random.choice(["fire", "spark", "smoke"]),
                "life": random.randint(25, 45),
            })

        self.explosions.append(explosion)
        self._debug(f"explosion created at ({x:.1f}, {y:.1f})")

    def create_impact_explosion(self, x: float, y: float) -> None:
        """보스 패들 충돌 시 강력한 임팩트 폭발 이펙트 생성."""
        explosion = {
            "x": x,
            "y": y,
            "timer": 60,  # 1초
            "max_timer": 60,
            "particles": [],
            "type": "impact",  # 임팩트 폭발
            "shockwave_radius": 0,
            "shockwave_max_radius": 180,
        }

        # 메인 폭발 파티클 (더 많고 강력하게)
        for _ in range(80):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(5, 20)
            explosion["particles"].append({
                "x": x,
                "y": y,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed,
                "size": random.randint(4, 12),
                "color_type": random.choice(["impact_fire", "impact_spark", "impact_electric"]),
                "life": random.randint(30, 60),
            })

        # 볼링핀 조각 파티클
        for _ in range(15):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(8, 16)
            explosion["particles"].append({
                "x": x,
                "y": y,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed - 3,
                "size": random.randint(6, 14),
                "color_type": "pin_fragment",
                "life": random.randint(40, 70),
                "rotation": random.uniform(0, 360),
                "rotation_speed": random.uniform(-15, 15),
            })

        # 전기 스파크 파티클
        for _ in range(25):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(3, 8)
            explosion["particles"].append({
                "x": x,
                "y": y,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed,
                "size": random.randint(2, 5),
                "color_type": "electric",
                "life": random.randint(10, 25),
            })

        self.explosions.append(explosion)
        self._debug(f"impact explosion created at ({x:.1f}, {y:.1f})")
        print("💥🎳 볼링트랩 임팩트 폭발!")

    def update_effects(self, ball_rect: Optional[pygame.Rect] = None) -> None:
        """이펙트 업데이트 (매 프레임 호출)."""
        # 폭발 이펙트 업데이트
        for explosion in self.explosions[:]:
            explosion["timer"] -= 1

            # 임팩트 폭발의 쇼크웨이브 업데이트
            if explosion.get("type") == "impact":
                max_radius = explosion.get("shockwave_max_radius", 180)
                current_radius = explosion.get("shockwave_radius", 0)
                if current_radius < max_radius:
                    explosion["shockwave_radius"] = min(max_radius, current_radius + 12)

            for particle in explosion["particles"][:]:
                particle["x"] += particle["vx"]
                particle["y"] += particle["vy"]

                # 임팩트 폭발은 중력 약하게, 일반 폭발은 중력 강하게
                if explosion.get("type") == "impact":
                    particle["vy"] += 0.15
                    particle["vx"] *= 0.97
                else:
                    particle["vy"] += 0.3
                    particle["vx"] *= 0.96

                particle["life"] -= 1
                particle["size"] = max(1, particle["size"] - 0.1)

                # 회전 파티클 업데이트
                if "rotation" in particle:
                    particle["rotation"] += particle.get("rotation_speed", 0)

                if particle["life"] <= 0:
                    explosion["particles"].remove(particle)

            if explosion["timer"] <= 0:
                self.explosions.remove(explosion)

        # 화염 궤적 업데이트
        if self.flame_trail_active and ball_rect:
            # 새 화염 파티클 추가
            for _ in range(3):
                self.flame_trails.append({
                    "x": ball_rect.centerx + random.randint(-5, 5),
                    "y": ball_rect.centery + random.randint(-3, 3),
                    "vx": random.uniform(-1, 1),
                    "vy": random.uniform(1, 3),  # 아래로 떨어짐
                    "size": random.randint(4, 10),
                    "life": random.randint(15, 30),
                    "max_life": 30,
                })

        # 화염 궤적 파티클 업데이트
        for trail in self.flame_trails[:]:
            trail["x"] += trail["vx"]
            trail["y"] += trail["vy"]
            trail["vy"] += 0.1  # 약한 중력
            trail["life"] -= 1
            trail["size"] = max(1, trail["size"] - 0.3)

            if trail["life"] <= 0:
                self.flame_trails.remove(trail)

    def draw_effects(self, screen: pygame.Surface) -> None:
        """이펙트 그리기."""
        self._draw_explosions(screen)
        self._draw_flame_trails(screen)

    def _draw_explosions(self, screen: pygame.Surface) -> None:
        """폭발 이펙트 그리기."""
        for explosion in self.explosions:
            progress = 1.0 - (explosion["timer"] / explosion["max_timer"])
            is_impact = explosion.get("type") == "impact"

            # === 임팩트 폭발 전용 이펙트 ===
            if is_impact:
                ex, ey = int(explosion["x"]), int(explosion["y"])

                # 쇼크웨이브 링 (확장되는 원형 파동)
                shockwave_radius = int(explosion.get("shockwave_radius", 0))
                if shockwave_radius > 0:
                    max_radius = explosion.get("shockwave_max_radius", 180)
                    wave_progress = shockwave_radius / max_radius
                    wave_alpha = int(200 * (1 - wave_progress))
                    wave_width = max(3, int(12 * (1 - wave_progress)))

                    # 외부 쇼크웨이브 (주황색)
                    if wave_alpha > 0:
                        wave_surface = pygame.Surface((shockwave_radius * 2 + 20, shockwave_radius * 2 + 20), pygame.SRCALPHA)
                        pygame.draw.circle(wave_surface, (255, 150, 50, wave_alpha),
                                         (shockwave_radius + 10, shockwave_radius + 10), shockwave_radius, wave_width)
                        # 내부 링 (노란색)
                        inner_radius = max(1, shockwave_radius - 15)
                        inner_alpha = int(150 * (1 - wave_progress))
                        pygame.draw.circle(wave_surface, (255, 255, 100, inner_alpha),
                                         (shockwave_radius + 10, shockwave_radius + 10), inner_radius, max(2, wave_width - 2))
                        screen.blit(wave_surface, (ex - shockwave_radius - 10, ey - shockwave_radius - 10))

                # 강력한 중심 플래시 (초반)
                if progress < 0.25:
                    flash_progress = progress / 0.25
                    flash_radius = int(80 * (1 - flash_progress * 0.5))
                    flash_alpha = int(255 * (1 - flash_progress))

                    # 다중 레이어 플래시
                    flash_surface = pygame.Surface((flash_radius * 2 + 20, flash_radius * 2 + 20), pygame.SRCALPHA)
                    # 외부 글로우 (빨강)
                    pygame.draw.circle(flash_surface, (255, 100, 50, flash_alpha // 2),
                                     (flash_radius + 10, flash_radius + 10), flash_radius)
                    # 중간 글로우 (주황)
                    pygame.draw.circle(flash_surface, (255, 180, 80, flash_alpha),
                                     (flash_radius + 10, flash_radius + 10), int(flash_radius * 0.7))
                    # 중심 코어 (흰색)
                    pygame.draw.circle(flash_surface, (255, 255, 220, min(255, flash_alpha + 50)),
                                     (flash_radius + 10, flash_radius + 10), int(flash_radius * 0.4))
                    screen.blit(flash_surface, (ex - flash_radius - 10, ey - flash_radius - 10))

                # 볼링 스트라이크 텍스트 이펙트
                if 0.1 < progress < 0.5:
                    text_alpha = int(255 * (1 - (progress - 0.1) / 0.4))
                    text_scale = 1.0 + (progress - 0.1) * 0.5
                    try:
                        font_size = int(28 * text_scale)
                        import os
                        font_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "NanumSquareB.ttf")
                        if os.path.exists(font_path):
                            font = pygame.font.Font(font_path, font_size)
                        else:
                            font = pygame.font.Font(None, font_size)
                        text_surface = font.render("STRIKE!", True, (255, 220, 100))
                        text_surface.set_alpha(text_alpha)
                        text_rect = text_surface.get_rect(center=(ex, ey - 40))
                        screen.blit(text_surface, text_rect)
                    except Exception:
                        pass

            else:
                # === 일반 발사 폭발 ===
                # 중심 플래시 (초반)
                if progress < 0.3:
                    flash_radius = int(40 * (1 - progress / 0.3))
                    flash_alpha = int(255 * (1 - progress / 0.3))
                    flash_surface = pygame.Surface((flash_radius * 2, flash_radius * 2), pygame.SRCALPHA)
                    pygame.draw.circle(flash_surface, (255, 255, 200, flash_alpha), (flash_radius, flash_radius), flash_radius)
                    screen.blit(flash_surface, (int(explosion["x"]) - flash_radius, int(explosion["y"]) - flash_radius))

                # 폭발 링 (중반)
                if 0.1 < progress < 0.6:
                    ring_progress = (progress - 0.1) / 0.5
                    ring_radius = int(20 + 50 * ring_progress)
                    ring_alpha = int(200 * (1 - ring_progress))
                    ring_width = max(2, int(8 * (1 - ring_progress)))

                    ring_surface = pygame.Surface((ring_radius * 2 + 10, ring_radius * 2 + 10), pygame.SRCALPHA)
                    pygame.draw.circle(ring_surface, (255, 150, 50, ring_alpha), (ring_radius + 5, ring_radius + 5), ring_radius, ring_width)
                    screen.blit(ring_surface, (int(explosion["x"]) - ring_radius - 5, int(explosion["y"]) - ring_radius - 5))

            # 파티클 그리기
            for particle in explosion["particles"]:
                max_life = 60 if is_impact else 45
                life_ratio = particle["life"] / max_life
                size = int(particle["size"])
                color_type = particle["color_type"]

                # 색상 결정 (모든 값은 0-255 범위로 클램핑)
                def clamp(v): return max(0, min(255, int(v)))

                if color_type == "fire":
                    r, g, b = 255, clamp(200 * life_ratio), clamp(50 * life_ratio)
                    alpha = clamp(255 * life_ratio)
                elif color_type == "spark":
                    r, g, b = 255, 255, clamp(150 + 105 * life_ratio)
                    alpha = clamp(255 * life_ratio)
                elif color_type == "smoke":
                    gray = clamp(100 + 80 * life_ratio)
                    r, g, b = gray, gray, gray
                    alpha = clamp(150 * life_ratio)
                elif color_type == "impact_fire":
                    # 임팩트 불꽃 (더 밝은 주황)
                    r, g, b = 255, clamp(180 * life_ratio + 50), clamp(30 * life_ratio)
                    alpha = clamp(255 * life_ratio)
                elif color_type == "impact_spark":
                    # 임팩트 스파크 (밝은 노랑)
                    r, g, b = 255, 255, clamp(200 * life_ratio)
                    alpha = clamp(255 * life_ratio)
                elif color_type == "impact_electric":
                    # 전기 스파크 (청백색)
                    r, g, b = clamp(200 + 55 * life_ratio), clamp(220 + 35 * life_ratio), 255
                    alpha = clamp(255 * life_ratio)
                elif color_type == "electric":
                    # 전기 (밝은 청색)
                    r, g, b = 150, 200, 255
                    alpha = clamp(255 * life_ratio * 1.2)
                elif color_type == "pin_fragment":
                    # 볼링핀 조각 (흰색/크림색)
                    r, g, b = 245, 240, 230
                    alpha = clamp(255 * life_ratio)
                else:
                    gray = clamp(100 + 80 * life_ratio)
                    r, g, b = gray, gray, gray
                    alpha = clamp(150 * life_ratio)

                if size > 0 and alpha > 0:
                    # 볼링핀 조각은 사각형으로 그리기
                    if color_type == "pin_fragment":
                        frag_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                        # 회전된 사각형
                        rotation = particle.get("rotation", 0)
                        points = []
                        for i in range(4):
                            angle = math.radians(rotation + i * 90 + 45)
                            px = size + math.cos(angle) * size * 0.8
                            py = size + math.sin(angle) * size * 0.8
                            points.append((px, py))
                        pygame.draw.polygon(frag_surface, (r, g, b, alpha), points)
                        # 빨간 줄무늬
                        pygame.draw.line(frag_surface, (200, 50, 50, alpha),
                                       (size - 3, size - size // 2), (size - 3, size + size // 2), 2)
                        screen.blit(frag_surface, (int(particle["x"]) - size, int(particle["y"]) - size))
                    else:
                        particle_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(particle_surface, (r, g, b, alpha), (size, size), size)
                        screen.blit(particle_surface, (int(particle["x"]) - size, int(particle["y"]) - size))

    def _draw_flame_trails(self, screen: pygame.Surface) -> None:
        """화염 궤적 그리기."""
        def clamp(v): return max(0, min(255, int(v)))

        for trail in self.flame_trails:
            life_ratio = trail["life"] / trail["max_life"]
            size = int(trail["size"])

            if size <= 0:
                continue

            # 화염 색상 그라데이션 (노랑 → 주황 → 빨강)
            if life_ratio > 0.6:
                # 노랑~주황
                r = 255
                g = clamp(255 - 100 * (1 - (life_ratio - 0.6) / 0.4))
                b = clamp(100 * (life_ratio - 0.6) / 0.4)
            elif life_ratio > 0.3:
                # 주황~빨강
                r = 255
                g = clamp(155 * ((life_ratio - 0.3) / 0.3))
                b = 0
            else:
                # 빨강~어두운 빨강
                r = clamp(255 * (life_ratio / 0.3))
                g = 0
                b = 0

            alpha = clamp(255 * life_ratio)

            # 화염 코어
            flame_surface = pygame.Surface((size * 2 + 4, size * 2 + 4), pygame.SRCALPHA)
            pygame.draw.circle(flame_surface, (r, g, b, alpha), (size + 2, size + 2), size)

            # 글로우 효과
            glow_size = size + 3
            glow_alpha = clamp(alpha * 0.4)
            pygame.draw.circle(flame_surface, (255, 200, 100, glow_alpha), (size + 2, size + 2), glow_size)

            screen.blit(flame_surface, (int(trail["x"]) - size - 2, int(trail["y"]) - size - 2))

    # -------------------------------------------------------------------------
    # 사운드
    # -------------------------------------------------------------------------
    def _play_install_sound(self) -> None:
        """설치 사운드 재생."""
        try:
            import os
            sound_path = os.path.join(
                os.path.dirname(os.path.dirname(__file__)),
                "sounds",
                "ballingtrapsetup.wav"
            )
            if os.path.exists(sound_path):
                install_sound = pygame.mixer.Sound(sound_path)
                install_sound.set_volume(0.7)
                install_sound.play()
                self._debug(f"install sound played → {sound_path}")
            else:
                self._debug(f"install sound not found → {sound_path}")
        except Exception as e:
            self._debug(f"install sound error → {e}")

    def _play_capture_sound(self) -> None:
        """포획 사운드 재생."""
        try:
            import os
            sound_path = os.path.join(
                os.path.dirname(os.path.dirname(__file__)),
                "sounds",
                "ballingtrapgrap.wav"
            )
            if os.path.exists(sound_path):
                capture_sound = pygame.mixer.Sound(sound_path)
                capture_sound.set_volume(0.7)
                capture_sound.play()
                self._debug(f"capture sound played → {sound_path}")
            else:
                self._debug(f"capture sound not found → {sound_path}")
        except Exception as e:
            self._debug(f"capture sound error → {e}")

    # -------------------------------------------------------------------------
    # 유틸리티
    # -------------------------------------------------------------------------
    def _get_reload_tracker(self) -> Callable[[str], None] | None:
        """노후화 추적 함수 획득."""
        for module_name in ("__main__", "pingfighter"):
            module = sys.modules.get(module_name)
            if not module:
                continue
            candidate = getattr(module, "register_weapon_reload", None)
            if callable(candidate):
                return candidate
            controller = getattr(module, "soldier_controller", None)
            name_resolver = getattr(module, "get_item_name_korean", None)
            if controller and hasattr(controller, "register_reload"):
                def fallback(weapon: str, *, _controller=controller, _resolver=name_resolver) -> None:
                    if weapon == "pistol":
                        return
                    try:
                        degraded = _controller.register_reload(weapon)
                    except Exception:
                        return
                    if degraded:
                        try:
                            label = _resolver(weapon) if callable(_resolver) else weapon
                            print(f"⚠️ {label} 노후화!")
                        except Exception:
                            print(f"⚠️ {weapon} 노후화!")

                return fallback
        return None


# 싱글톤 인스턴스
_bowling_trap_instance: Optional[BowlingTrap] = None


def get_bowling_trap_instance() -> BowlingTrap:
    """볼링트랩 싱글톤 인스턴스 반환."""
    global _bowling_trap_instance
    if _bowling_trap_instance is None:
        _bowling_trap_instance = BowlingTrap()
    return _bowling_trap_instance
