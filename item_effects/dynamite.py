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
                placed = {
                    "x": placed_x,
                    "y": max(30, proj["y"]),  # 화면 밖으로 나가지 않게
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

            # 다이너마이트 본체
            self._draw_dynamite_body(screen, x, y, 0, fuse_lit=True, countdown=countdown)

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
        """고퀄리티 폭발 이펙트 그리기."""
        for explosion in self.explosions:
            ex, ey = int(explosion["x"]), int(explosion["y"])
            progress = explosion["progress"]
            shockwave_radius = int(explosion["shockwave_radius"])

            # 연기 구름 (먼저 그려서 뒤에 배치)
            for cloud in explosion.get("smoke_clouds", []):
                life_ratio = cloud["life"] / cloud["max_life"]
                size = int(cloud["size"])
                alpha = int(120 * life_ratio)

                if size > 0 and alpha > 0:
                    cloud_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    # 그라데이션 연기 (바깥 어둡고 안쪽 밝게)
                    for i in range(3):
                        r = size - i * size // 3
                        if r > 0:
                            gray = 60 + i * 25
                            a = alpha // (i + 1)
                            pygame.draw.circle(cloud_surface, (gray, gray, gray, a), (size, size), r)
                    screen.blit(cloud_surface, (int(cloud["x"]) - size, int(cloud["y"]) - size))

            # 2차 쇼크웨이브들
            for wave in explosion.get("secondary_waves", []):
                if wave["radius"] > 0 and wave["radius"] < self.EXPLOSION_RADIUS:
                    wave_alpha = int(150 * (1 - wave["radius"] / self.EXPLOSION_RADIUS))
                    if wave_alpha > 0:
                        r = int(wave["radius"])
                        wave_surface = pygame.Surface((r * 2 + 10, r * 2 + 10), pygame.SRCALPHA)
                        pygame.draw.circle(wave_surface, (255, 180, 80, wave_alpha),
                                         (r + 5, r + 5), r, max(2, 8 - int(wave["radius"] / 40)))
                        screen.blit(wave_surface, (ex - r - 5, ey - r - 5))

            # 메인 쇼크웨이브 (더 굵고 화려하게)
            if shockwave_radius > 0 and progress < 0.6:
                wave_alpha = int(220 * (1 - progress / 0.6))
                wave_width = max(4, int(20 * (1 - progress)))

                wave_surface = pygame.Surface((shockwave_radius * 2 + 30, shockwave_radius * 2 + 30), pygame.SRCALPHA)
                center = shockwave_radius + 15

                # 외부 글로우
                pygame.draw.circle(wave_surface, (255, 100, 30, wave_alpha // 3),
                                 (center, center), shockwave_radius + 8, wave_width + 8)
                # 메인 쇼크웨이브 (주황)
                pygame.draw.circle(wave_surface, (255, 150, 50, wave_alpha),
                                 (center, center), shockwave_radius, wave_width)
                # 내부 링 (노란-흰)
                inner_radius = max(1, shockwave_radius - 30)
                pygame.draw.circle(wave_surface, (255, 230, 120, wave_alpha),
                                 (center, center), inner_radius, max(2, wave_width - 5))

                screen.blit(wave_surface, (ex - shockwave_radius - 15, ey - shockwave_radius - 15))

            # 중심 플래시 (더 밝고 빠르게)
            if progress < 0.25:
                flash_progress = progress / 0.25
                flash_radius = int(150 * (1 - flash_progress * 0.7))
                flash_alpha = int(255 * (1 - flash_progress))

                flash_surface = pygame.Surface((flash_radius * 2 + 30, flash_radius * 2 + 30), pygame.SRCALPHA)
                center = flash_radius + 15

                # 외부 글로우 (주황)
                pygame.draw.circle(flash_surface, (255, 150, 50, flash_alpha // 2),
                                 (center, center), flash_radius)
                # 중간층 (노란)
                pygame.draw.circle(flash_surface, (255, 220, 100, flash_alpha),
                                 (center, center), int(flash_radius * 0.7))
                # 중심 (흰색)
                pygame.draw.circle(flash_surface, (255, 255, 240, min(255, flash_alpha + 30)),
                                 (center, center), int(flash_radius * 0.35))

                screen.blit(flash_surface, (ex - flash_radius - 15, ey - flash_radius - 15))

            # 스파크 (빠르게 튀는 작은 불꽃)
            for spark in explosion.get("sparks", []):
                life_ratio = spark["life"] / spark["max_life"]
                # 스파크는 밝은 노란-흰색으로 깜빡임
                intensity = 0.7 + 0.3 * math.sin(spark["life"] * 0.8)
                r = int(255 * intensity)
                g = int(220 * intensity)
                b = int(150 * intensity)
                alpha = int(255 * life_ratio)

                if alpha > 0:
                    # 스파크는 선으로 그림 (속도 방향)
                    sx, sy = int(spark["x"]), int(spark["y"])
                    tail_x = sx - int(spark["vx"] * 0.3)
                    tail_y = sy - int(spark["vy"] * 0.3)

                    spark_surface = pygame.Surface((abs(spark["vx"]) + 10, abs(spark["vy"]) + 10), pygame.SRCALPHA)
                    # 간단한 점으로 표현
                    pygame.draw.circle(spark_surface, (r, g, b, alpha), (5, 5), 2)
                    screen.blit(spark_surface, (sx - 5, sy - 5))

            # 메인 파티클 (불꽃)
            for particle in explosion["particles"]:
                max_life = particle.get("max_life", 30)
                life_ratio = particle["life"] / max_life
                size = max(1, int(particle["size"]))
                color_type = particle["color_type"]

                # 색상 결정 (더 화려하게)
                if color_type == "fire":
                    # 주황-빨강 불꽃
                    r = 255
                    g = int(120 + 100 * life_ratio)
                    b = int(30 * life_ratio)
                elif color_type == "spark":
                    # 밝은 노란-흰색
                    r = 255
                    g = int(230 + 25 * life_ratio)
                    b = int(180 + 75 * life_ratio)
                elif color_type == "ember":
                    # 빨간 잔불
                    r = int(200 + 55 * life_ratio)
                    g = int(60 + 60 * life_ratio)
                    b = int(20 * life_ratio)
                else:
                    # 기본 불꽃
                    r = 255
                    g = int(150 * life_ratio)
                    b = int(50 * life_ratio)

                alpha = int(255 * life_ratio * life_ratio)  # 페이드아웃 가속

                if size > 0 and alpha > 0:
                    particle_surface = pygame.Surface((size * 2 + 4, size * 2 + 4), pygame.SRCALPHA)
                    center = size + 2
                    # 글로우 효과
                    if size > 2:
                        pygame.draw.circle(particle_surface, (r, g // 2, b // 2, alpha // 3),
                                         (center, center), size + 2)
                    pygame.draw.circle(particle_surface, (r, g, b, alpha), (center, center), size)
                    screen.blit(particle_surface, (int(particle["x"]) - size - 2, int(particle["y"]) - size - 2))

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