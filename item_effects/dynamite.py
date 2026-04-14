"""다이너마이트 - 투척형 액티브 아이템.

보스쪽 진영에 도달하면 7초 카운트 후 폭발.
폭발 시 범위 350, 보스 넉백 속도 13, 스턴 3초.
"""
from __future__ import annotations

import math
import random
import sys
from typing import Dict, List, Optional, Tuple

import pygame


def _safe_print(msg: str) -> None:
    """Windows cp949 인코딩에서도 안전하게 출력."""
    try:
        print(msg)
    except UnicodeEncodeError:
        # 이모지 등 인코딩 불가 문자 제거 후 출력
        safe_msg = msg.encode('cp949', errors='ignore').decode('cp949')
        print(safe_msg)


class Dynamite:
    """다이너마이트 액티브 아이템 클래스.

    - 투척 후 보스 진영에 도달하면 7초 카운트
    - 폭발 범위: 350px
    - 보스 넉백 속도: 13
    - 스턴 시간: 3초 (180프레임)
    - 벽에 부딪힌 경우 반대로 튕겨남
    """

    # 기본 상수
    THROW_SPEED = 18  # 투척 속도 (증가: 보스 진영까지 도달)
    COUNTDOWN_FRAMES = 420  # 7초 카운트다운 (60fps * 7)
    EXPLOSION_RADIUS = 350  # 폭발 범위
    KNOCKBACK_SPEED = 52  # 넉백 속도 (4배 증가: 13 → 26 → 52)
    STUN_DURATION = 180  # 스턴 시간 3초 (60fps * 3)
    # 보스 진영 경계선 (config/constants.py의 BOSS_AREA_BOUNDARY_Y 참조)
    # 화면 규격: 760x750, 보스 Y=25, 보스 진영은 Y < 120
    BOSS_AREA_Y = 120  # 보스 진영 하단 경계 Y 좌표
    # 게임 물리 영역 경계 (전체 너비 0~760)
    GAME_AREA_OFFSET_X = 0
    GAME_AREA_LEFT = 0  # 0px (물리 영역 왼쪽 경계)
    GAME_AREA_RIGHT = 760  # 760px (물리 영역 오른쪽 경계, WIDTH)

    def __init__(self) -> None:
        self.active: bool = False
        self.equipped: bool = False

        # 투척된 다이너마이트들
        self.projectiles: List[Dict] = []

        # 설치된 다이너마이트들 (보스 진영에 도달한 것들)
        self.placed_dynamites: List[Dict] = []

        # 폭발 이펙트
        self.explosions: List[Dict] = []

        # 넉백 처리용
        self.pending_knockbacks: List[Dict] = []

        # 디버그
        self.debug_enabled: bool = True

    def _debug(self, message: str) -> None:
        if self.debug_enabled:
            print(f"[Dynamite] {message}")

    def reset(self) -> None:
        """상태 초기화."""
        self.projectiles.clear()
        self.placed_dynamites.clear()
        self.explosions.clear()
        self.pending_knockbacks.clear()
        self.active = False
        self.equipped = False

    def equip(self) -> None:
        """다이너마이트 장착."""
        self.equipped = True
        self.active = True
        self._debug("equip → 다이너마이트 장착!")

    def unequip(self) -> None:
        """다이너마이트 해제."""
        self.equipped = False
        self.active = False
        self._debug("unequip → 다이너마이트 해제")

    def throw(self, player_rect: pygame.Rect, target_x: Optional[float] = None) -> bool:
        """다이너마이트 투척.

        Args:
            player_rect: 플레이어 위치
            target_x: 목표 X 좌표 (None이면 플레이어 위치 기준)

        Returns:
            투척 성공 여부
        """
        # 투척체 생성
        start_x = player_rect.centerx
        start_y = player_rect.top - 10

        # 목표 방향 계산 (기본: 위쪽)
        if target_x is not None:
            dx = target_x - start_x
            angle = math.atan2(-1, dx / max(1, abs(dx))) if dx != 0 else -math.pi / 2
        else:
            angle = -math.pi / 2  # 수직 상방향

        projectile = {
            "x": float(start_x),
            "y": float(start_y),
            "vel_x": math.cos(angle) * self.THROW_SPEED * 0.3,  # 약간의 수평 이동
            "vel_y": -self.THROW_SPEED,  # 위쪽으로 던짐
            "rotation": 0,
            "rotation_speed": random.uniform(5, 15),  # 회전 속도
            "active": True,
            "fuse_lit": False,  # 심지 점화 여부
        }

        self.projectiles.append(projectile)
        self._debug(f"throw -> pos=({start_x:.1f}, {start_y:.1f})")
        _safe_print("[Dynamite] 다이너마이트 투척!")

        # 투척 사운드 재생
        self._play_throw_sound()

        return True

    def update(
        self,
        ball_rect: Optional[pygame.Rect] = None,
        boss_rect: Optional[pygame.Rect] = None,
        screen_width: int = 800,
    ) -> List[Dict]:
        """매 프레임 업데이트.

        Args:
            ball_rect: 공 히트박스
            boss_rect: 보스 히트박스
            screen_width: 화면 너비

        Returns:
            발생한 폭발 이벤트 리스트
        """
        explosion_events = []

        # 투척체 업데이트
        for proj in self.projectiles[:]:
            if not proj["active"]:
                self.projectiles.remove(proj)
                continue

            # 중력 적용 (낮은 중력으로 멀리 던짐)
            proj["vel_y"] += 0.15

            # 위치 업데이트
            proj["x"] += proj["vel_x"]
            proj["y"] += proj["vel_y"]

            # 회전 업데이트
            proj["rotation"] += proj["rotation_speed"]

            # 좌우 벽 충돌 (게임 영역 경계 기준으로 튕김)
            left_boundary = self.GAME_AREA_LEFT + 10  # 게임 영역 왼쪽 + 여백
            right_boundary = self.GAME_AREA_RIGHT - 10  # 게임 영역 오른쪽 - 여백
            if proj["x"] <= left_boundary:
                proj["x"] = left_boundary
                proj["vel_x"] = abs(proj["vel_x"]) * 0.8
            elif proj["x"] >= right_boundary:
                proj["x"] = right_boundary
                proj["vel_x"] = -abs(proj["vel_x"]) * 0.8

            # 보스 진영 도달 체크 (화면 상단)
            if proj["y"] <= self.BOSS_AREA_Y:
                # 설치 상태로 전환 - X 좌표를 게임 영역 내로 제한
                placed_x = max(self.GAME_AREA_LEFT + 20, min(self.GAME_AREA_RIGHT - 20, proj["x"]))
                # 보스 패들(Y=25) 근처에 설치 (Y=40~65)
                placed = {
                    "x": placed_x,
                    "y": random.randint(40, 65),  # 보스 패들 바로 아래쪽
                    "countdown": self.COUNTDOWN_FRAMES,
                    "active": True,
                    "pulse_timer": 0,
                }
                self.placed_dynamites.append(placed)
                proj["active"] = False
                self._play_place_sound()
                self._debug(f"placed at boss area → ({placed['x']:.1f}, {placed['y']:.1f}), countdown={self.COUNTDOWN_FRAMES}")
                _safe_print("[Dynamite] 다이너마이트 설치! 7초 후 폭발!")
                continue

            # 화면 하단으로 떨어지면 제거
            if proj["y"] > 700:
                proj["active"] = False

        # 설치된 다이너마이트 업데이트
        for placed in self.placed_dynamites[:]:
            if not placed["active"]:
                self.placed_dynamites.remove(placed)
                continue

            # ═══ 보스 패들 근접 시 물리 반응 (살짝 뒹구름) ═══
            if boss_rect is not None:
                # 물리 상태 초기화 (최초 1회)
                if "nudge_vx" not in placed:
                    placed["nudge_vx"] = 0.0
                    placed["wobble_angle"] = 0.0
                    placed["wobble_vel"] = 0.0

                # X축 거리만으로 판정 (Y는 보스와 다이너마이트가 다른 높이라 무시)
                prox_dx = boss_rect.centerx - placed["x"]
                abs_dx = abs(prox_dx)
                push_range = 80  # X축 밀림 감지 반경
                if abs_dx < push_range and abs_dx > 1:
                    push_strength = (1.0 - abs_dx / push_range) * 1.8
                    push_dir_x = -1.0 if prox_dx > 0 else 1.0
                    placed["nudge_vx"] += push_dir_x * push_strength
                    placed["wobble_vel"] += push_dir_x * push_strength * 2.5

                # 밀림 속도 상한
                placed["nudge_vx"] = max(-3.0, min(3.0, placed["nudge_vx"]))

                # 밀림 적용 + 마찰 (뒹구르다 멈춤)
                if abs(placed["nudge_vx"]) > 0.05:
                    placed["x"] += placed["nudge_vx"]
                    placed["nudge_vx"] *= 0.80
                    placed["x"] = max(self.GAME_AREA_LEFT + 20, min(self.GAME_AREA_RIGHT - 20, placed["x"]))
                else:
                    placed["nudge_vx"] = 0.0

                # 흔들림 스프링 (뒹구르는 느낌)
                placed["wobble_vel"] += -placed["wobble_angle"] * 0.2
                placed["wobble_vel"] *= 0.85
                placed["wobble_angle"] += placed["wobble_vel"]
                placed["wobble_angle"] = max(-12, min(12, placed["wobble_angle"]))
                if abs(placed["wobble_angle"]) < 0.3 and abs(placed["wobble_vel"]) < 0.3:
                    placed["wobble_angle"] = 0.0
                    placed["wobble_vel"] = 0.0

            # 카운트다운 감소
            placed["countdown"] -= 1
            placed["pulse_timer"] += 1

            # 카운트다운 완료 - 폭발
            if placed["countdown"] <= 0:
                explosion = self._create_explosion(placed["x"], placed["y"])
                explosion_events.append(explosion)
                placed["active"] = False
                self._debug(f"countdown complete → explosion at ({placed['x']:.1f}, {placed['y']:.1f})")
                _safe_print("[Dynamite] 다이너마이트 폭발!")

        # 폭발 이펙트 업데이트
        for explosion in self.explosions[:]:
            explosion["timer"] -= 1
            explosion["progress"] = 1.0 - (explosion["timer"] / explosion["max_timer"])
            frames_elapsed = explosion["max_timer"] - explosion["timer"]

            # 메인 쇼크웨이브 업데이트 (더 빠르게 퍼짐)
            if explosion["shockwave_radius"] < self.EXPLOSION_RADIUS:
                explosion["shockwave_radius"] += 30  # 2배 빠르게

            # 2차 쇼크웨이브 업데이트
            for wave in explosion.get("secondary_waves", []):
                if frames_elapsed >= wave["delay"]:
                    wave["radius"] += wave["speed"]

            # 메인 파티클 업데이트
            for particle in explosion["particles"][:]:
                particle["x"] += particle["vx"]
                particle["y"] += particle["vy"]
                particle["vy"] += 0.4  # 강한 중력
                particle["vx"] *= 0.95  # 빠른 감속
                particle["vy"] *= 0.97
                particle["life"] -= 1
                particle["size"] = max(0.5, particle["size"] - 0.3)

                if particle["life"] <= 0:
                    explosion["particles"].remove(particle)

            # 스파크 업데이트
            for spark in explosion.get("sparks", [])[:]:
                spark["x"] += spark["vx"]
                spark["y"] += spark["vy"]
                spark["vy"] += 0.8  # 매우 강한 중력
                spark["vx"] *= 0.92
                spark["life"] -= 1

                if spark["life"] <= 0:
                    explosion["sparks"].remove(spark)

            # 연기 구름 업데이트
            for cloud in explosion.get("smoke_clouds", [])[:]:
                cloud["x"] += cloud["vx"]
                cloud["y"] += cloud["vy"]
                cloud["size"] += 0.8  # 점점 커짐
                cloud["life"] -= 1

                if cloud["life"] <= 0:
                    explosion["smoke_clouds"].remove(cloud)

            if explosion["timer"] <= 0:
                self.explosions.remove(explosion)

        return explosion_events

    def _create_explosion(self, x: float, y: float) -> Dict:
        """폭발 생성 - 고퀄리티 빠른 폭발."""
        explosion = {
            "x": x,
            "y": y,
            "timer": 36,  # 0.6초 지속 (더 빠르게)
            "max_timer": 36,
            "progress": 0,
            "shockwave_radius": 0,
            "particles": [],
            "knockback_power": self.KNOCKBACK_SPEED,
            "knockback_radius": self.EXPLOSION_RADIUS,
            "stun_duration": self.STUN_DURATION,
            # 추가 이펙트용
            "secondary_waves": [],
            "sparks": [],
            "smoke_clouds": [],
        }

        # 메인 폭발 파티클 (더 많이, 더 빠르게)
        for _ in range(100):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(12, 35)  # 더 빠른 속도
            explosion["particles"].append({
                "x": x,
                "y": y,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed - 5,  # 더 강한 상승
                "size": random.uniform(3, 14),
                "color_type": random.choice(["fire", "fire", "spark", "ember"]),  # 불꽃 위주
                "life": random.randint(15, 30),  # 더 짧은 수명
                "max_life": 30,
            })

        # 스파크 파티클 (빠르게 튀는 불꽃)
        for _ in range(40):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(25, 50)
            explosion["sparks"].append({
                "x": x,
                "y": y,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed - 8,
                "life": random.randint(10, 20),
                "max_life": 20,
            })

        # 연기 구름 (느리게 퍼지는)
        for _ in range(15):
            angle = random.uniform(0, 2 * math.pi)
            dist = random.uniform(20, 60)
            explosion["smoke_clouds"].append({
                "x": x + math.cos(angle) * dist,
                "y": y + math.sin(angle) * dist,
                "vx": math.cos(angle) * 2,
                "vy": -random.uniform(1, 3),  # 위로 상승
                "size": random.uniform(20, 40),
                "life": random.randint(20, 36),
                "max_life": 36,
            })

        # 2차 쇼크웨이브들
        explosion["secondary_waves"] = [
            {"radius": 0, "speed": 25, "delay": 0},
            {"radius": 0, "speed": 20, "delay": 3},
            {"radius": 0, "speed": 15, "delay": 6},
        ]

        # 폭발 사운드 재생
        self._play_explosion_sound()

        self.explosions.append(explosion)
        return explosion

    def check_boss_in_explosion(self, boss_rect: pygame.Rect) -> Optional[Dict]:
        """보스가 폭발 범위 내에 있는지 확인.

        Returns:
            넉백 정보 또는 None
        """
        if boss_rect is None:
            return None

        for explosion in self.explosions:
            if explosion["progress"] < 0.2:  # 폭발 초반에만 넉백 적용 (0.1 → 0.2로 확대)
                ex, ey = explosion["x"], explosion["y"]
                boss_center = boss_rect.center

                # 거리 계산
                dist = math.hypot(boss_center[0] - ex, boss_center[1] - ey)
                self._debug(f"check_boss → explosion({ex:.1f}, {ey:.1f}), boss({boss_center[0]:.1f}, {boss_center[1]:.1f}), dist={dist:.1f}, radius={self.EXPLOSION_RADIUS}")

                if dist <= self.EXPLOSION_RADIUS:
                    # 넉백 방향 계산 (폭발 중심에서 보스 방향)
                    if dist > 0:
                        dir_x = (boss_center[0] - ex) / dist
                        dir_y = (boss_center[1] - ey) / dist
                    else:
                        dir_x, dir_y = 0, -1  # 기본: 위로

                    knockback_info = {
                        "knockback_speed": self.KNOCKBACK_SPEED,
                        "knockback_dir_x": dir_x,
                        "knockback_dir_y": dir_y,
                        "stun_duration": self.STUN_DURATION,
                        "remaining_distance": self.KNOCKBACK_SPEED * 30,  # 넉백 거리
                    }

                    self._debug(f"boss in explosion → knockback applied, dir=({dir_x:.2f}, {dir_y:.2f})")
                    return knockback_info

        return None

    # -------------------------------------------------------------------------
    # 렌더링
    # -------------------------------------------------------------------------
    def draw(self, screen: pygame.Surface) -> None:
        """모든 다이너마이트와 폭발 그리기."""
        self._draw_projectiles(screen)
        self._draw_placed_dynamites(screen)
        self._draw_explosions(screen)

    def _draw_projectiles(self, screen: pygame.Surface) -> None:
        """투척 중인 다이너마이트 그리기."""
        for proj in self.projectiles:
            if not proj["active"]:
                continue

            x, y = int(proj["x"]), int(proj["y"])
            rotation = proj["rotation"]

            # 다이너마이트 본체 그리기 (회전 효과)
            self._draw_dynamite_body(screen, x, y, rotation, fuse_lit=False)

    def _draw_placed_dynamites(self, screen: pygame.Surface) -> None:
        """설치된 다이너마이트 그리기."""
        for placed in self.placed_dynamites:
            if not placed["active"]:
                continue

            x, y = int(placed["x"]), int(placed["y"])
            countdown = placed["countdown"]
            pulse_timer = placed["pulse_timer"]

            # 다이너마이트 본체 (물리 흔들림 각도 반영)
            wobble = placed.get("wobble_angle", 0.0)
            self._draw_dynamite_body(screen, x, y, wobble, fuse_lit=True, countdown=countdown)

            # 카운트다운 표시
            seconds_left = countdown // 60

            # 깜빡임 효과 (남은 시간이 적을수록 빠르게)
            if countdown < 180:  # 3초 이하
                blink_speed = 0.2 if countdown < 60 else 0.1
                if int(pulse_timer * blink_speed) % 2 == 0:
                    # 경고 원
                    warning_radius = 20 + int(5 * math.sin(pulse_timer * 0.3))
                    warning_surface = pygame.Surface((warning_radius * 2 + 10, warning_radius * 2 + 10), pygame.SRCALPHA)
                    pygame.draw.circle(warning_surface, (255, 50, 50, 150), (warning_radius + 5, warning_radius + 5), warning_radius, 3)
                    screen.blit(warning_surface, (x - warning_radius - 5, y - warning_radius - 5))

            # 카운트다운 텍스트
            try:
                font = pygame.font.Font(None, 24)
                count_text = font.render(f"{seconds_left + 1}", True, (255, 255, 255))
                text_rect = count_text.get_rect(center=(x, y - 30))

                # 텍스트 배경
                bg_rect = text_rect.inflate(10, 6)
                pygame.draw.rect(screen, (50, 50, 50, 200), bg_rect)
                pygame.draw.rect(screen, (255, 100, 100), bg_rect, 2)

                screen.blit(count_text, text_rect)
            except Exception:
                pass

    def _draw_dynamite_body(
        self,
        screen: pygame.Surface,
        x: int,
        y: int,
        rotation: float,
        fuse_lit: bool = False,
        countdown: int = 0,
    ) -> None:
        """다이너마이트 본체 그리기."""
        # 다이너마이트 묶음 (3개의 빨간 막대)
        dynamite_surface = pygame.Surface((40, 40), pygame.SRCALPHA)

        # 중심 좌표
        cx, cy = 20, 20

        # 빨간 막대 3개 (묶음)
        stick_color = (200, 50, 50)
        stick_highlight = (240, 80, 80)
        stick_shadow = (150, 30, 30)

        # 왼쪽 막대
        pygame.draw.ellipse(dynamite_surface, stick_color, (8, 10, 8, 22))
        pygame.draw.ellipse(dynamite_surface, stick_highlight, (9, 11, 4, 20))

        # 중앙 막대 (앞)
        pygame.draw.ellipse(dynamite_surface, stick_color, (15, 8, 10, 26))
        pygame.draw.ellipse(dynamite_surface, stick_highlight, (17, 9, 4, 24))

        # 오른쪽 막대
        pygame.draw.ellipse(dynamite_surface, stick_color, (24, 10, 8, 22))
        pygame.draw.ellipse(dynamite_surface, stick_highlight, (25, 11, 4, 20))

        # 묶는 밧줄/테이프
        rope_color = (139, 90, 43)
        pygame.draw.rect(dynamite_surface, rope_color, (8, 14, 24, 4))
        pygame.draw.rect(dynamite_surface, rope_color, (8, 24, 24, 4))

        # 심지
        fuse_color = (60, 60, 60)
        pygame.draw.line(dynamite_surface, fuse_color, (20, 8), (20, 0), 2)

        # 심지 불꽃 (점화된 경우)
        if fuse_lit:
            # 불꽃 위치 (카운트다운에 따라 심지가 짧아짐)
            fuse_progress = countdown / self.COUNTDOWN_FRAMES
            fuse_y = int(8 - fuse_progress * 8)

            # 불꽃 색상 (깜빡임)
            flame_intensity = 0.5 + 0.5 * math.sin(pygame.time.get_ticks() * 0.02)
            flame_r = int(255 * flame_intensity)
            flame_g = int(150 * flame_intensity)

            # 불꽃 그리기
            pygame.draw.circle(dynamite_surface, (flame_r, flame_g, 50), (20, max(2, fuse_y)), 4)
            pygame.draw.circle(dynamite_surface, (255, 255, 150), (20, max(2, fuse_y)), 2)

            # 스파크 효과
            for _ in range(2):
                spark_x = 20 + random.randint(-3, 3)
                spark_y = fuse_y + random.randint(-2, 2)
                spark_y = max(0, min(spark_y, 39))
                spark_x = max(0, min(spark_x, 39))
                pygame.draw.circle(dynamite_surface, (255, 200, 100), (spark_x, spark_y), 1)

        # 회전 적용
        if rotation != 0:
            rotated = pygame.transform.rotate(dynamite_surface, rotation)
            rect = rotated.get_rect(center=(x, y))
            screen.blit(rotated, rect)
        else:
            screen.blit(dynamite_surface, (x - 20, y - 20))

    def _draw_explosions(self, screen: pygame.Surface) -> None:
        """고퀄리티 폭발 이펙트 그리기 (캐싱 오버레이 + gfxdraw)."""
        if not self.explosions:
            return
        import pygame.gfxdraw
        w, h = screen.get_size()
        # 캐싱된 SRCALPHA 오버레이 (프레임당 fill만)
        if not hasattr(self, '_exp_overlay') or self._exp_overlay.get_size() != (w, h):
            self._exp_overlay = pygame.Surface((w, h), pygame.SRCALPHA)
        self._exp_overlay.fill((0, 0, 0, 0))
        _has = False
        for explosion in self.explosions:
            ex, ey = int(explosion["x"]), int(explosion["y"])
            progress = explosion["progress"]
            sw_r = int(explosion["shockwave_radius"])

            # ── 연기 구름 (gfxdraw 직접) ──
            for cloud in explosion.get("smoke_clouds", []):
                lr = cloud["life"] / cloud["max_life"]
                sz = int(cloud["size"])
                a = int(120 * lr)
                if sz > 1 and a > 3:
                    cx, cy = int(cloud["x"]), int(cloud["y"])
                    # 3층 그라데이션 (바깥→안쪽)
                    for i in range(3):
                        r = max(1, sz - i * sz // 3)
                        gray = 60 + i * 25
                        _a = max(0, a // (i + 1))
                        if _a > 2:
                            try:
                                pygame.gfxdraw.filled_circle(self._exp_overlay, cx, cy, r, (gray, gray, gray, _a))
                            except Exception:
                                pass
                    _has = True

            # ── 다층 충격파 (3겹 링, Surface 할당 0) ──
            if sw_r > 5 and progress < 0.6:
                _sw_life = max(0.0, 1.0 - progress / 0.6)
                _sw_width = max(2, int(20 * (1 - progress)))
                # 외곽 글로우
                _a1 = int(60 * _sw_life)
                if _a1 > 2:
                    pygame.draw.circle(self._exp_overlay, (255, 100, 30, _a1),
                        (ex, ey), sw_r + 8, _sw_width + 8)
                # 메인 링 (주황)
                _a2 = int(180 * _sw_life)
                if _a2 > 2:
                    pygame.draw.circle(self._exp_overlay, (255, 150, 50, _a2),
                        (ex, ey), sw_r, _sw_width)
                # 내부 링 (노란)
                _a3 = int(140 * _sw_life)
                _inner = max(3, sw_r - 30)
                if _a3 > 2:
                    pygame.draw.circle(self._exp_overlay, (255, 230, 120, _a3),
                        (ex, ey), _inner, max(2, _sw_width - 5))
                _has = True

            # ── 2차 충격파 (gfxdraw 링) ──
            for wave in explosion.get("secondary_waves", []):
                wr = int(wave["radius"])
                if 0 < wr < self.EXPLOSION_RADIUS:
                    _wa = int(150 * (1 - wr / self.EXPLOSION_RADIUS))
                    _ww = max(1, 8 - wr // 40)
                    if _wa > 2:
                        pygame.draw.circle(self._exp_overlay, (255, 180, 80, _wa),
                            (ex, ey), wr, _ww)
                        _has = True

            # ── 중심 플래시 ──
            if progress < 0.25:
                fp = progress / 0.25
                fr = int(150 * (1 - fp * 0.7))
                fa = int(255 * (1 - fp))
                if fr > 3 and fa > 5:
                    pygame.draw.circle(self._exp_overlay, (255, 150, 50, fa // 2), (ex, ey), fr)
                    pygame.draw.circle(self._exp_overlay, (255, 220, 100, fa), (ex, ey), int(fr * 0.7))
                    pygame.draw.circle(self._exp_overlay, (255, 255, 240, min(255, fa + 30)), (ex, ey), int(fr * 0.35))
                    _has = True

            # ── 스파크 (잔상 트레일 + 글로우) ──
            for spark in explosion.get("sparks", []):
                lr = spark["life"] / spark["max_life"]
                _sa = int(255 * lr)
                if _sa < 5:
                    continue
                sx, sy = int(spark["x"]), int(spark["y"])
                intensity = 0.7 + 0.3 * math.sin(spark["life"] * 0.8)
                _sr = int(255 * intensity)
                _sg = int(220 * intensity)
                _sb = int(150 * intensity)
                # 잔상 트레일
                tx = sx - int(spark["vx"] * 0.3)
                ty = sy - int(spark["vy"] * 0.3)
                pygame.draw.line(self._exp_overlay, (_sr, _sg, _sb, _sa // 2),
                    (sx, sy), (tx, ty), 1)
                # 글로우
                try:
                    pygame.gfxdraw.filled_circle(self._exp_overlay, sx, sy, 4, (_sr, _sg, _sb, _sa // 3))
                    pygame.gfxdraw.filled_circle(self._exp_overlay, sx, sy, 2, (_sr, _sg, _sb, _sa))
                except Exception:
                    pass
                _has = True

            # ── 메인 파티클 (불꽃 + 글로우) ──
            for particle in explosion["particles"]:
                ml = particle.get("max_life", 30)
                lr = particle["life"] / ml
                sz = max(1, int(particle["size"]))
                ct = particle["color_type"]
                if ct == "fire":
                    _r, _g, _b = 255, int(120 + 100 * lr), int(30 * lr)
                elif ct == "spark":
                    _r, _g, _b = 255, int(230 + 25 * lr), int(180 + 75 * lr)
                elif ct == "ember":
                    _r, _g, _b = int(200 + 55 * lr), int(60 + 60 * lr), int(20 * lr)
                else:
                    _r, _g, _b = 255, int(150 * lr), int(50 * lr)
                _pa = int(255 * lr * lr)
                if sz > 0 and _pa > 3:
                    px, py = int(particle["x"]), int(particle["y"])
                    # 글로우
                    if sz > 2:
                        try:
                            pygame.gfxdraw.filled_circle(self._exp_overlay, px, py,
                                sz + 2, (_r, _g // 2, _b // 2, _pa // 3))
                        except Exception:
                            pass
                    # 메인
                    try:
                        pygame.gfxdraw.filled_circle(self._exp_overlay, px, py,
                            sz, (_r, _g, _b, _pa))
                    except Exception:
                        pass
                    _has = True

        if _has:
            screen.blit(self._exp_overlay, (0, 0))

    # -------------------------------------------------------------------------
    # 사운드
    # -------------------------------------------------------------------------
    def _play_throw_sound(self) -> None:
        """투척 사운드 재생."""
        try:
            import os
            sound_path = os.path.join(
                os.path.dirname(os.path.dirname(__file__)),
                "sounds",
                "throw.wav"
            )
            if os.path.exists(sound_path):
                throw_sound = pygame.mixer.Sound(sound_path)
                throw_sound.set_volume(0.6)
                throw_sound.play()
        except Exception:
            pass

    def _play_place_sound(self) -> None:
        """설치 사운드 재생."""
        try:
            import os
            sound_path = os.path.join(
                os.path.dirname(os.path.dirname(__file__)),
                "sounds",
                "fuse_lit.wav"
            )
            if os.path.exists(sound_path):
                place_sound = pygame.mixer.Sound(sound_path)
                place_sound.set_volume(0.7)
                place_sound.play()
        except Exception:
            pass

    def _play_explosion_sound(self) -> None:
        """폭발 사운드 재생 (수류탄과 동일한 grenade.wav 사용)."""
        try:
            import os
            # 수류탄과 동일한 폭발 사운드 사용
            sound_path = os.path.join(
                os.path.dirname(os.path.dirname(__file__)),
                "sounds",
                "grenade.wav"
            )
            if os.path.exists(sound_path):
                explosion_sound = pygame.mixer.Sound(sound_path)
                explosion_sound.set_volume(0.8)
                explosion_sound.play()
        except Exception:
            pass


# 싱글톤 인스턴스
_dynamite_instance: Optional[Dynamite] = None


def get_dynamite_instance() -> Dynamite:
    """다이너마이트 싱글톤 인스턴스 반환."""
    global _dynamite_instance
    if _dynamite_instance is None:
        _dynamite_instance = Dynamite()
    return _dynamite_instance