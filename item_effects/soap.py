"""비누 - 투척형 트랩 액티브 아이템.

보스 진영에 던지면 비누가 떨어지고, 보스가 밟으면 5초간 미끄러짐 디버프 발동.
바나나와 다르게 AI는 유지되지만 가속/감속 능력이 크게 감소하여
방향 전환이 매우 느려진다. 좌우 왕복 공격에 매우 취약해짐.
"""
from __future__ import annotations

import math
import random
import sys
import os
from typing import Dict, List, Optional, Tuple

import pygame


def _safe_print(msg: str) -> None:
    """Windows cp949 인코딩에서도 안전하게 출력."""
    try:
        print(msg)
    except UnicodeEncodeError:
        safe_msg = msg.encode('cp949', errors='ignore').decode('cp949')
        print(safe_msg)


class Soap:
    """비누 액티브 아이템 클래스.

    - 투척 후 보스 진영에 도달하면 바닥에 착지
    - 보스가 밟으면 5초간 '미끄러움' 디버프 (가속/감속 능력 70% 감소)
    - AI는 유지되므로 보스가 공을 치려 하지만 방향전환이 매우 느림
    - 착지 후 4초간 유지되다가 사라짐
    - 준비 동작: 0.3초 (투척류 무기 공통)
    """

    # 기본 상수
    THROW_SPEED = 18              # 투척 속도
    DEBUFF_DURATION = 300         # 미끄러움 지속 시간 (5초 = 300프레임 @60fps)
    # 미끄러움 물리 파라미터 (빙판 위 느낌)
    DECEL_MULT = 0.12             # 감속 능력 88% 감소 → 브레이크 거의 안 걸림 (관성 유지)
    ACCEL_MULT_MIN = 0.10         # 가속 초기값: 90% 감소 → 방향전환 직후 거의 안 움직임
    ACCEL_MULT_MAX = 0.55         # 가속 최종값: 45% 감소 → 서서히 가속도 붙음
    ACCEL_RAMPUP_FRAMES = 90      # 가속 램프업 시간 (1.5초에 걸쳐 MIN → MAX)
    LAND_DURATION = 240           # 착지 후 유지 시간 (4초 = 240프레임)
    PREPARE_TIME = 18             # 준비 동작 시간 (0.3초)

    # 보스 진영 경계선
    BOSS_AREA_Y = 45              # 보스 패들 중앙 높이에 착지

    # 게임 물리 영역 경계
    GAME_AREA_LEFT = 0
    GAME_AREA_RIGHT = 760         # WIDTH

    def __init__(self) -> None:
        self.active: bool = False
        self.equipped: bool = False

        # 투척된 비누들 (비행 중)
        self.projectiles: List[Dict] = []

        # 착지한 비누들 (보스가 밟을 수 있음)
        self.landed_soaps: List[Dict] = []

        # 미끄러움 디버프 상태
        self.boss_soaped: bool = False
        self.boss_soap_timer: int = 0

        # 가속 램프업 추적 (방향전환 후 서서히 가속)
        self._rampup_counter: int = 0
        self._last_boss_direction: int = 0  # 마지막 보스 이동 방향

        # 터지는 파티클 (비누 거품)
        self.burst_particles: List[Dict] = []

        # 준비 동작 상태
        self.preparing: bool = False
        self.prepare_timer: int = 0
        self.pending_throw: Optional[Dict] = None

        # 준비 중 표시용 위치
        self.prepare_display_x: float = 0
        self.prepare_display_y: float = 0

    def reset(self) -> None:
        """상태 초기화."""
        self.projectiles.clear()
        self.landed_soaps.clear()
        self.burst_particles.clear()
        self.boss_soaped = False
        self.boss_soap_timer = 0
        self._rampup_counter = 0
        self._last_boss_direction = 0
        self.preparing = False
        self.prepare_timer = 0
        self.pending_throw = None
        self.active = False
        self.equipped = False

    def equip(self) -> None:
        """비누 장착."""
        self.equipped = True
        self.active = True

    def unequip(self) -> None:
        """비누 해제."""
        self.equipped = False
        self.active = False

    def start_throw(self, player_rect: pygame.Rect, target_x: Optional[float] = None) -> bool:
        """비누 투척 준비 시작.

        Args:
            player_rect: 플레이어 위치
            target_x: 목표 X 좌표

        Returns:
            준비 시작 성공 여부
        """
        if self.preparing:
            return False

        self.preparing = True
        self.prepare_timer = self.PREPARE_TIME
        self.pending_throw = {
            "player_x": player_rect.centerx,
            "player_y": player_rect.top,
            "target_x": target_x
        }
        self.prepare_display_x = player_rect.centerx
        self.prepare_display_y = player_rect.top - 10
        return True

    def _execute_throw(self) -> bool:
        """실제 투척 실행 (준비 동작 완료 후)."""
        if not self.pending_throw:
            return False

        start_x = self.pending_throw["player_x"]
        start_y = self.pending_throw["player_y"] - 10
        target_x = self.pending_throw["target_x"]

        # 목표 방향 계산
        if target_x is not None:
            dx = target_x - start_x
            angle = math.atan2(-1, dx / max(1, abs(dx))) if dx != 0 else -math.pi / 2
        else:
            angle = -math.pi / 2

        projectile = {
            "x": float(start_x),
            "y": float(start_y),
            "vel_x": math.cos(angle) * self.THROW_SPEED * 0.3,
            "vel_y": -self.THROW_SPEED,
            "rotation": 0,
            "rotation_speed": random.uniform(5, 10) * random.choice([-1, 1]),
            "active": True,
        }

        self.projectiles.append(projectile)
        _safe_print("[Soap] 비누 투척!")
        self._play_throw_sound()
        self.pending_throw = None
        return True

    def update(
        self,
        boss_rect: Optional[pygame.Rect] = None,
        screen_width: int = 760,
        boss_move_direction: int = 0,
    ) -> Dict:
        """매 프레임 업데이트.

        Returns:
            미끄러움 디버프 상태 정보
        """
        # 준비 동작 업데이트
        if self.preparing:
            self.prepare_timer -= 1
            if self.prepare_timer <= 0:
                self.preparing = False
                self._execute_throw()

        # 투척체 업데이트
        for proj in self.projectiles[:]:
            if not proj["active"]:
                self.projectiles.remove(proj)
                continue

            proj["x"] += proj["vel_x"]
            proj["y"] += proj["vel_y"]
            proj["rotation"] += proj["rotation_speed"]

            # 좌우 벽 충돌
            if proj["x"] <= self.GAME_AREA_LEFT + 10:
                proj["x"] = self.GAME_AREA_LEFT + 10
                proj["vel_x"] = abs(proj["vel_x"]) * 0.7
            elif proj["x"] >= self.GAME_AREA_RIGHT - 10:
                proj["x"] = self.GAME_AREA_RIGHT - 10
                proj["vel_x"] = -abs(proj["vel_x"]) * 0.7

            # 보스 진영 도달 → 착지
            if proj["y"] <= self.BOSS_AREA_Y and proj["vel_y"] < 0:
                landed_x = max(self.GAME_AREA_LEFT + 30, min(self.GAME_AREA_RIGHT - 30, proj["x"]))
                landed = {
                    "x": landed_x,
                    "y": self.BOSS_AREA_Y,
                    "timer": self.LAND_DURATION,
                    "active": True,
                    "triggered": False,
                    "wobble_phase": random.uniform(0, math.pi * 2),
                }
                self.landed_soaps.append(landed)
                proj["active"] = False
                self._play_land_sound()
                _safe_print(f"[Soap] 비누 착지! ({landed['x']:.0f}, {landed['y']:.0f})")
                continue

            # 화면 밖 제거
            if proj["y"] > 700:
                proj["active"] = False

        # 착지한 비누 업데이트
        for landed in self.landed_soaps[:]:
            if not landed["active"]:
                self.landed_soaps.remove(landed)
                continue

            landed["timer"] -= 1
            landed["wobble_phase"] += 0.08  # 비누 흔들림 애니메이션

            # 보스와 충돌 체크
            if boss_rect and not landed["triggered"]:
                soap_rect = pygame.Rect(
                    landed["x"] - 35,
                    20,
                    70,
                    50
                )
                if boss_rect.colliderect(soap_rect):
                    landed["triggered"] = True
                    landed["active"] = False
                    self.boss_soaped = True
                    self.boss_soap_timer = self.DEBUFF_DURATION
                    self._create_burst_particles(landed["x"], landed["y"])
                    self._play_slip_sound()
                    _safe_print("[Soap] 보스가 비누를 밟았다! 5초간 미끄러움!")
                    continue

            # 시간 초과 시 제거
            if landed["timer"] <= 0:
                landed["active"] = False

        # 미끄러움 디버프 업데이트
        if self.boss_soaped:
            self.boss_soap_timer -= 1

            # 방향전환 감지 → 램프업 카운터 리셋
            current_dir = boss_move_direction
            if current_dir != 0 and current_dir != self._last_boss_direction:
                # 방향이 바뀜 → 가속 리셋 (다시 느리게 시작)
                _safe_print(f"[Soap] 방향전환! {self._last_boss_direction} → {current_dir} | 램프업 리셋 (was {self._rampup_counter})")
                self._rampup_counter = 0
            if current_dir != 0:
                self._last_boss_direction = current_dir

            # 램프업 카운터 증가 (같은 방향으로 갈수록 가속 붙음)
            if self._rampup_counter < self.ACCEL_RAMPUP_FRAMES:
                self._rampup_counter += 1

            # 디버그 로그 (매 30프레임 = 0.5초마다)
            if self.boss_soap_timer % 30 == 0:
                accel_m = self.get_accel_multiplier()
                decel_m = self.get_decel_multiplier()
                _safe_print(
                    f"[Soap DEBUG] remain={self.boss_soap_timer/60:.1f}s | "
                    f"dir={current_dir} | rampup={self._rampup_counter}/{self.ACCEL_RAMPUP_FRAMES} | "
                    f"accel_mult={accel_m:.2f} | decel_mult={decel_m:.2f}"
                )

            if self.boss_soap_timer <= 0:
                self.boss_soaped = False
                self._rampup_counter = 0
                self._last_boss_direction = 0
                _safe_print("[Soap] 미끄러움 효과 종료!")

        # 거품 파티클 업데이트
        for particle in self.burst_particles[:]:
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            particle["vy"] += 0.15  # 약한 중력 (거품은 천천히 떨어짐)
            particle["life"] -= 1
            particle["size"] *= 0.98  # 거품 수축
            if particle["life"] <= 0:
                self.burst_particles.remove(particle)

        return {
            "soaped": self.boss_soaped,
            "accel_multiplier": self.get_accel_multiplier(),
            "decel_multiplier": self.get_decel_multiplier(),
            "remaining_frames": self.boss_soap_timer,
        }

    def is_boss_soaped(self) -> bool:
        """보스가 비누 디버프 상태인지 반환."""
        return self.boss_soaped

    def get_accel_multiplier(self) -> float:
        """보스 가속에 적용할 배율 (방향전환 후 서서히 증가).

        방향전환 직후: 0.10 (거의 안 움직임)
        1.5초 후:      0.55 (서서히 가속도 붙음)
        """
        if not self.boss_soaped:
            return 1.0
        # 램프업: MIN → MAX (선형 보간)
        t = min(1.0, self._rampup_counter / max(1, self.ACCEL_RAMPUP_FRAMES))
        return self.ACCEL_MULT_MIN + (self.ACCEL_MULT_MAX - self.ACCEL_MULT_MIN) * t

    def get_decel_multiplier(self) -> float:
        """보스 감속에 적용할 배율 (브레이크 거의 안 걸림 → 관성으로 밀림)."""
        if not self.boss_soaped:
            return 1.0
        return self.DECEL_MULT  # 0.12 (88% 감소)

    def get_remaining_seconds(self) -> float:
        """남은 디버프 시간(초) 반환."""
        return self.boss_soap_timer / 60.0 if self.boss_soaped else 0.0

    def is_preparing(self) -> bool:
        """준비 동작 중인지 반환."""
        return self.preparing

    def _create_burst_particles(self, x: float, y: float) -> None:
        """비누 거품 파티클 생성."""
        colors = [
            (200, 230, 255),   # 하늘색 거품
            (220, 240, 255),   # 밝은 하늘
            (180, 220, 255),   # 진한 하늘
            (255, 255, 255),   # 흰 거품
            (200, 255, 240),   # 민트 거품
        ]
        for _ in range(18):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(1.5, 5)
            self.burst_particles.append({
                "x": x + random.uniform(-10, 10),
                "y": y + random.uniform(-5, 5),
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed - 2,
                "size": random.uniform(3, 8),
                "color": random.choice(colors),
                "life": random.randint(30, 60),
            })

    # -------------------------------------------------------------------------
    # 렌더링
    # -------------------------------------------------------------------------
    def draw(self, screen: pygame.Surface) -> None:
        """모든 비누와 파티클 그리기."""
        self._draw_preparing_soap(screen)
        self._draw_projectiles(screen)
        self._draw_landed_soaps(screen)
        self._draw_burst_particles(screen)
        self._draw_debuff_indicator(screen)

    def _draw_preparing_soap(self, screen: pygame.Surface) -> None:
        """준비 동작 중인 비누 그리기."""
        if not self.preparing:
            return

        x, y = int(self.prepare_display_x), int(self.prepare_display_y)
        progress = 1.0 - (self.prepare_timer / self.PREPARE_TIME)
        offset_y = int(-20 * progress)

        soap_surf = self._create_soap_surface(48)
        rotation = -10 + progress * 20
        rotated = pygame.transform.rotate(soap_surf, rotation)
        rect = rotated.get_rect(center=(x, y + offset_y))
        screen.blit(rotated, rect)

    def _draw_projectiles(self, screen: pygame.Surface) -> None:
        """비행 중인 비누 그리기."""
        for proj in self.projectiles:
            if not proj["active"]:
                continue

            x, y = int(proj["x"]), int(proj["y"])
            soap_surf = self._create_soap_surface(48)
            rotated = pygame.transform.rotate(soap_surf, proj["rotation"])
            rect = rotated.get_rect(center=(x, y))
            screen.blit(rotated, rect)

    def _draw_landed_soaps(self, screen: pygame.Surface) -> None:
        """착지한 비누 그리기."""
        for landed in self.landed_soaps:
            if not landed["active"]:
                continue

            x, y = int(landed["x"]), int(landed["y"])

            # 남은 시간 < 1초: 깜빡임
            if landed["timer"] < 60:
                if (landed["timer"] // 5) % 2 == 0:
                    continue

            # 비누 흔들림 (좌우로 살짝)
            wobble = math.sin(landed["wobble_phase"]) * 3
            soap_surf = self._create_soap_surface(56)
            rotated = pygame.transform.rotate(soap_surf, wobble * 2)
            rect = rotated.get_rect(center=(x + wobble, y))
            screen.blit(rotated, rect)

            # 물기 표시 (미끄러운 바닥)
            if not landed["triggered"]:
                puddle_surf = pygame.Surface((70, 16), pygame.SRCALPHA)
                pygame.draw.ellipse(puddle_surf, (180, 220, 255, 60), (0, 0, 70, 16))
                pygame.draw.ellipse(puddle_surf, (200, 235, 255, 40), (10, 3, 50, 10))
                screen.blit(puddle_surf, (x - 35, y + 8))

    def _draw_burst_particles(self, screen: pygame.Surface) -> None:
        """거품 파티클 그리기."""
        for particle in self.burst_particles:
            life_ratio = particle["life"] / 60
            size = max(1, int(particle["size"]))
            alpha = int(200 * life_ratio)

            if size > 0 and alpha > 0:
                bubble_surf = pygame.Surface((size * 2 + 2, size * 2 + 2), pygame.SRCALPHA)
                # 거품 외곽선
                color_with_alpha = (*particle["color"], alpha)
                pygame.draw.circle(bubble_surf, color_with_alpha, (size + 1, size + 1), size, 1)
                # 거품 하이라이트
                highlight_alpha = min(255, int(alpha * 0.6))
                pygame.draw.circle(bubble_surf, (255, 255, 255, highlight_alpha),
                                   (size - 1, size - 1), max(1, size // 3))
                screen.blit(bubble_surf, (int(particle["x"]) - size - 1,
                                          int(particle["y"]) - size - 1))

    def _draw_debuff_indicator(self, screen: pygame.Surface) -> None:
        """보스 미끄러움 디버프 표시 (보스 위에 비누 아이콘 + 타이머)."""
        if not self.boss_soaped:
            return

        # 디버프 표시는 pingfighter.py에서 BOSS 좌표를 기반으로 그림
        # 여기서는 화면 상단에 간단한 인디케이터만 표시
        remaining = self.boss_soap_timer / 60.0
        bar_width = 60
        bar_height = 4
        bar_x = 380 - bar_width // 2  # 화면 중앙
        bar_y = 8

        # 남은 시간 비율
        ratio = self.boss_soap_timer / self.DEBUFF_DURATION
        fill_width = int(bar_width * ratio)

        # 배경
        pygame.draw.rect(screen, (40, 40, 60), (bar_x - 1, bar_y - 1, bar_width + 2, bar_height + 2))
        # 채움 (하늘색 → 진파랑 변화)
        r = int(100 + 100 * ratio)
        g = int(180 + 60 * ratio)
        b = 255
        pygame.draw.rect(screen, (r, g, b), (bar_x, bar_y, fill_width, bar_height))

        # 거품 아이콘 (바 왼쪽)
        bubble_x = bar_x - 12
        bubble_y = bar_y + 2
        # 깜빡임 (1초 미만일 때)
        if remaining > 1.0 or (int(remaining * 4) % 2 == 0):
            pygame.draw.circle(screen, (200, 230, 255), (bubble_x, bubble_y), 5, 1)
            pygame.draw.circle(screen, (255, 255, 255), (bubble_x - 1, bubble_y - 1), 2)

    def _create_soap_surface(self, size: int) -> pygame.Surface:
        """비누 서피스 생성 (둥근 사각형 + 거품)."""
        surf = pygame.Surface((size, size), pygame.SRCALPHA)
        cx, cy = size // 2, size // 2
        scale = size / 48

        # 비누 본체 (둥근 직사각형)
        body_w = int(24 * scale)
        body_h = int(16 * scale)
        body_rect = pygame.Rect(cx - body_w // 2, cy - body_h // 2, body_w, body_h)

        # 그림자
        shadow_rect = body_rect.copy()
        shadow_rect.move_ip(2, 2)
        pygame.draw.rect(surf, (100, 140, 180, 80), shadow_rect, border_radius=int(5 * scale))

        # 본체 색상 (하늘색 비누)
        soap_base = (140, 200, 240)
        soap_light = (180, 225, 255)
        soap_dark = (100, 160, 210)

        # 비누 본체
        pygame.draw.rect(surf, soap_base, body_rect, border_radius=int(5 * scale))

        # 하이라이트 (윗부분)
        highlight_rect = pygame.Rect(
            body_rect.left + int(3 * scale),
            body_rect.top + int(2 * scale),
            body_w - int(6 * scale),
            body_h // 3
        )
        pygame.draw.rect(surf, soap_light, highlight_rect, border_radius=int(3 * scale))

        # 아랫부분 그림자
        dark_rect = pygame.Rect(
            body_rect.left + int(2 * scale),
            body_rect.bottom - int(5 * scale),
            body_w - int(4 * scale),
            int(4 * scale)
        )
        pygame.draw.rect(surf, soap_dark, dark_rect, border_radius=int(3 * scale))

        # 비누 표면 줄무늬 (장식)
        stripe_y1 = cy - int(2 * scale)
        stripe_y2 = cy + int(1 * scale)
        pygame.draw.line(surf, (160, 215, 250),
                         (cx - int(8 * scale), stripe_y1),
                         (cx + int(8 * scale), stripe_y1), max(1, int(1 * scale)))
        pygame.draw.line(surf, (160, 215, 250),
                         (cx - int(6 * scale), stripe_y2),
                         (cx + int(6 * scale), stripe_y2), max(1, int(1 * scale)))

        # 거품들 (비누 주변)
        bubble_positions = [
            (cx + int(10 * scale), cy - int(6 * scale), int(3 * scale)),
            (cx - int(11 * scale), cy - int(4 * scale), int(2 * scale)),
            (cx + int(8 * scale), cy + int(7 * scale), int(2.5 * scale)),
            (cx - int(7 * scale), cy + int(8 * scale), int(2 * scale)),
            (cx + int(13 * scale), cy + int(2 * scale), int(1.5 * scale)),
        ]
        for bx, by, br in bubble_positions:
            br = max(1, int(br))
            pygame.draw.circle(surf, (220, 240, 255, 180), (int(bx), int(by)), br, 1)
            # 거품 하이라이트
            pygame.draw.circle(surf, (255, 255, 255, 150),
                               (int(bx) - max(1, br // 3), int(by) - max(1, br // 3)),
                               max(1, br // 3))

        return surf

    # -------------------------------------------------------------------------
    # 사운드
    # -------------------------------------------------------------------------
    def _play_throw_sound(self) -> None:
        """투척 사운드 재생."""
        try:
            sound_path = os.path.join(
                os.path.dirname(os.path.dirname(__file__)),
                "sounds",
                "oil.wav"  # 미끄러운 느낌의 사운드
            )
            if os.path.exists(sound_path):
                throw_sound = pygame.mixer.Sound(sound_path)
                throw_sound.set_volume(0.5)
                throw_sound.play()
        except Exception:
            pass

    def _play_land_sound(self) -> None:
        """착지 사운드 재생."""
        try:
            sound_path = os.path.join(
                os.path.dirname(os.path.dirname(__file__)),
                "sounds",
                "shootoil.wav"
            )
            if os.path.exists(sound_path):
                land_sound = pygame.mixer.Sound(sound_path)
                land_sound.set_volume(0.4)
                land_sound.play()
        except Exception:
            pass

    def _play_slip_sound(self) -> None:
        """미끄러짐 사운드 재생."""
        try:
            sound_path = os.path.join(
                os.path.dirname(os.path.dirname(__file__)),
                "sounds",
                "bananastep.wav"  # 미끄러지는 효과음
            )
            if os.path.exists(sound_path):
                slip_sound = pygame.mixer.Sound(sound_path)
                slip_sound.set_volume(0.7)
                slip_sound.play()
        except Exception:
            pass


# 싱글톤 인스턴스
_soap_instance: Optional[Soap] = None


def get_soap_instance() -> Soap:
    """비누 싱글톤 인스턴스 반환."""
    global _soap_instance
    if _soap_instance is None:
        _soap_instance = Soap()
    return _soap_instance
