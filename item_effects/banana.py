"""바나나 - 투척형 액티브 아이템.

보스 진영에 던지면 바나나가 떨어지고, 보스가 밟으면 미끄러집니다.
스테이지 2 원숭이 바나나와 동일한 미끄러짐 효과 적용.
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
        safe_msg = msg.encode('cp949', errors='ignore').decode('cp949')
        print(safe_msg)


class Banana:
    """바나나 액티브 아이템 클래스.

    - 투척 후 보스 진영에 도달하면 바닥에 착지
    - 보스가 밟으면 미끄러짐 효과 발동 (1.5초간 통제 불능)
    - 착지 후 3초간 유지되다가 사라짐
    - 준비 동작: 0.3초 (투척류 무기 공통)
    """

    # 기본 상수
    THROW_SPEED = 20  # 투척 속도 (증가)
    SLIP_DURATION = 48  # 미끄러짐 지속 시간 (0.8초 = 48프레임)
    SLIP_SPEED = 15  # 미끄러짐 속도 (투기장 바나나 슬라이스와 동일)
    LAND_DURATION = 180  # 착지 후 유지 시간 (3초 = 180프레임)
    PREPARE_TIME = 18  # 준비 동작 시간 (0.3초 = 18프레임)
    GRAVITY = 0.0  # 중력 없음 - 직선 비행

    # 보스 진영 경계선 (보스 패들 Y=25~65)
    # 바나나는 보스 패들과 같은 높이에 착지해야 밟을 수 있음
    BOSS_AREA_Y = 45  # 보스 패들 중앙 높이에 착지 (Y=25~65의 중간)

    # 게임 영역 오프셋
    GAME_AREA_OFFSET_X = 80
    GAME_AREA_LEFT = GAME_AREA_OFFSET_X  # 80px
    GAME_AREA_RIGHT = GAME_AREA_OFFSET_X + 600  # 680px

    def __init__(self) -> None:
        self.active: bool = False
        self.equipped: bool = False

        # 투척된 바나나들 (비행 중)
        self.projectiles: List[Dict] = []

        # 착지한 바나나들 (보스가 밟을 수 있음)
        self.landed_bananas: List[Dict] = []

        # 미끄러짐 효과
        self.boss_slipping: bool = False
        self.boss_slip_timer: int = 0
        self.boss_slip_direction: int = 0  # -1: 왼쪽, 1: 오른쪽

        # 터지는 파티클
        self.burst_particles: List[Dict] = []

        # 준비 동작 상태
        self.preparing: bool = False
        self.prepare_timer: int = 0
        self.pending_throw: Optional[Dict] = None

        # 준비 중 표시용 위치
        self.prepare_display_x: float = 0
        self.prepare_display_y: float = 0

        # 디버그
        self.debug_enabled: bool = False  # 성능 영향으로 비활성화

    def _debug(self, message: str) -> None:
        if self.debug_enabled:
            _safe_print(f"[Banana] {message}")

    def reset(self) -> None:
        """상태 초기화."""
        self.projectiles.clear()
        self.landed_bananas.clear()
        self.burst_particles.clear()
        self.boss_slipping = False
        self.boss_slip_timer = 0
        self.boss_slip_direction = 0
        self.preparing = False
        self.prepare_timer = 0
        self.pending_throw = None
        self.active = False
        self.equipped = False

    def equip(self) -> None:
        """바나나 장착."""
        self.equipped = True
        self.active = True
        self._debug("equip -> 바나나 장착!")

    def unequip(self) -> None:
        """바나나 해제."""
        self.equipped = False
        self.active = False
        self._debug("unequip -> 바나나 해제")

    def start_throw(self, player_rect: pygame.Rect, target_x: Optional[float] = None) -> bool:
        """바나나 투척 준비 시작 (준비 동작).

        Args:
            player_rect: 플레이어 위치
            target_x: 목표 X 좌표 (None이면 플레이어 위치 기준)

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
        # 준비 중 바나나 표시 위치 설정
        self.prepare_display_x = player_rect.centerx
        self.prepare_display_y = player_rect.top - 10
        self._debug(f"start_throw -> 준비 동작 시작")
        return True

    def _execute_throw(self) -> bool:
        """실제 투척 실행 (준비 동작 완료 후)."""
        if not self.pending_throw:
            return False

        start_x = self.pending_throw["player_x"]
        start_y = self.pending_throw["player_y"] - 10
        target_x = self.pending_throw["target_x"]

        # 목표 방향 계산 (기본: 위쪽)
        if target_x is not None:
            dx = target_x - start_x
            angle = math.atan2(-1, dx / max(1, abs(dx))) if dx != 0 else -math.pi / 2
        else:
            angle = -math.pi / 2  # 수직 상방향

        projectile = {
            "x": float(start_x),
            "y": float(start_y),
            "vel_x": math.cos(angle) * self.THROW_SPEED * 0.3,
            "vel_y": -self.THROW_SPEED,
            "rotation": 0,
            "rotation_speed": random.uniform(8, 15) * random.choice([-1, 1]),
            "active": True,
        }

        self.projectiles.append(projectile)
        self._debug(f"_execute_throw -> pos=({start_x:.1f}, {start_y:.1f})")
        _safe_print("[Banana] 바나나 투척!")

        # 투척 사운드 재생
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

        Args:
            boss_rect: 보스 히트박스
            screen_width: 화면 너비
            boss_move_direction: 보스 이동 방향 (-1: 왼쪽, 0: 정지, 1: 오른쪽)

        Returns:
            미끄러짐 상태 정보
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

            # 중력 적용 (0이면 직선 비행)
            proj["vel_y"] += self.GRAVITY

            # 위치 업데이트
            proj["x"] += proj["vel_x"]
            proj["y"] += proj["vel_y"]

            # 회전 업데이트
            proj["rotation"] += proj["rotation_speed"]

            # 좌우 벽 충돌
            if proj["x"] <= self.GAME_AREA_LEFT + 10:
                proj["x"] = self.GAME_AREA_LEFT + 10
                proj["vel_x"] = abs(proj["vel_x"]) * 0.7
            elif proj["x"] >= self.GAME_AREA_RIGHT - 10:
                proj["x"] = self.GAME_AREA_RIGHT - 10
                proj["vel_x"] = -abs(proj["vel_x"]) * 0.7

            # 보스 진영 도달 체크
            if proj["y"] <= self.BOSS_AREA_Y and proj["vel_y"] < 0:
                # 착지 상태로 전환
                landed_x = max(self.GAME_AREA_LEFT + 30, min(self.GAME_AREA_RIGHT - 30, proj["x"]))
                landed = {
                    "x": landed_x,
                    "y": self.BOSS_AREA_Y,  # 보스 패들 높이(45)에 고정 착지
                    "timer": self.LAND_DURATION,
                    "active": True,
                    "slip_triggered": False,
                }
                self.landed_bananas.append(landed)
                proj["active"] = False
                self._play_land_sound()
                self._debug(f"landed at boss area -> ({landed['x']:.1f}, {landed['y']:.1f})")
                _safe_print("[Banana] 바나나 착지!")
                continue

            # 화면 하단으로 떨어지면 제거
            if proj["y"] > 700:
                proj["active"] = False

        # 착지한 바나나 업데이트
        for landed in self.landed_bananas[:]:
            if not landed["active"]:
                self.landed_bananas.remove(landed)
                continue

            landed["timer"] -= 1

            # 보스와 충돌 체크
            if boss_rect and not landed["slip_triggered"]:
                # 바나나 히트박스: 보스 패들(Y=25~65)이 지나갈 때 충돌하도록 설정
                # X 범위: 바나나 중심에서 좌우 40px (총 80px 너비)
                # Y 범위: 보스 패들 전체 영역을 커버하도록 Y=20~70
                banana_rect = pygame.Rect(
                    landed["x"] - 40,  # X 중심에서 좌로 40px
                    20,  # 보스 패들 위쪽 (Y=25)보다 약간 위
                    80,  # 총 너비 80px
                    50   # 높이 50px (Y=20~70)
                )
                if boss_rect.colliderect(banana_rect):
                    landed["slip_triggered"] = True
                    landed["active"] = False  # 밟힌 즉시 바나나 제거
                    self.boss_slipping = True
                    self.boss_slip_timer = self.SLIP_DURATION
                    # 미끄러지는 방향 결정 (보스 이동 방향으로, 정지 시 랜덤)
                    if boss_move_direction != 0:
                        self.boss_slip_direction = boss_move_direction
                    else:
                        self.boss_slip_direction = random.choice([-1, 1])
                    self._create_burst_particles(landed["x"], landed["y"])
                    self._play_slip_sound()
                    self._debug(f"boss stepped on banana -> slip start! boss_rect={boss_rect}, banana_rect={banana_rect}")
                    _safe_print("[Banana] 보스가 바나나를 밟았다! 미끄러짐!")
                    continue  # 바나나 제거 후 다음 바나나로

            # 시간 초과 시 제거
            if landed["timer"] <= 0:
                landed["active"] = False

        # 미끄러짐 상태 업데이트
        if self.boss_slipping:
            self.boss_slip_timer -= 1
            if self.boss_slip_timer <= 0:
                self.boss_slipping = False
                self.boss_slip_direction = 0

        # 터지는 파티클 업데이트
        for particle in self.burst_particles[:]:
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            particle["vy"] += 0.5  # 중력
            particle["life"] -= 1
            if particle["life"] <= 0:
                self.burst_particles.remove(particle)

        return {
            "slipping": self.boss_slipping,
            "slip_direction": self.boss_slip_direction,
            "slip_speed": self.SLIP_SPEED if self.boss_slipping else 0
        }

    def _create_burst_particles(self, x: float, y: float) -> None:
        """바나나 터지는 파티클 생성."""
        colors = [
            (255, 225, 50),   # 밝은 노랑
            (227, 189, 52),   # 중간 노랑
            (198, 156, 41),   # 어두운 노랑
            (255, 255, 200),  # 바나나 속 흰색
            (139, 90, 43),    # 꼭지 갈색
        ]
        for _ in range(12):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(3, 8)
            self.burst_particles.append({
                "x": x,
                "y": y,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed - 3,
                "size": random.randint(3, 7),
                "color": random.choice(colors),
                "life": random.randint(20, 40),
            })

    def get_boss_slip_offset(self) -> float:
        """보스 미끄러짐 오프셋 반환 (선형 감속 - 투기장 바나나 슬라이스와 동일)."""
        if self.boss_slipping:
            # 선형 감속: 시작 시 최대 속도, 끝날 때 0
            strength = self.boss_slip_timer / self.SLIP_DURATION  # 1.0 → 0.0
            return self.boss_slip_direction * self.SLIP_SPEED * strength
        return 0

    def is_boss_slipping(self) -> bool:
        """보스가 미끄러지는 중인지 반환."""
        return self.boss_slipping

    def is_preparing(self) -> bool:
        """준비 동작 중인지 반환."""
        return self.preparing

    # -------------------------------------------------------------------------
    # 렌더링
    # -------------------------------------------------------------------------
    def draw(self, screen: pygame.Surface) -> None:
        """모든 바나나와 파티클 그리기."""
        self._draw_preparing_banana(screen)
        self._draw_projectiles(screen)
        self._draw_landed_bananas(screen)
        self._draw_burst_particles(screen)

    def _draw_preparing_banana(self, screen: pygame.Surface) -> None:
        """준비 동작 중인 바나나 그리기."""
        if not self.preparing:
            return

        x, y = int(self.prepare_display_x), int(self.prepare_display_y)

        # 준비 동작 진행률 (0 -> 1)
        progress = 1.0 - (self.prepare_timer / self.PREPARE_TIME)

        # 바나나가 위로 올라가는 애니메이션 (0 ~ -20px)
        offset_y = int(-20 * progress)

        # 바나나 서피스 생성
        banana_surf = self._create_banana_surface(64)

        # 살짝 회전 (준비 동작 느낌)
        rotation = -15 + progress * 30  # -15도 -> 15도
        rotated = pygame.transform.rotate(banana_surf, rotation)
        rect = rotated.get_rect(center=(x, y + offset_y))
        screen.blit(rotated, rect)

    def _draw_projectiles(self, screen: pygame.Surface) -> None:
        """비행 중인 바나나 그리기."""
        for proj in self.projectiles:
            if not proj["active"]:
                continue

            x, y = int(proj["x"]), int(proj["y"])
            rotation = proj["rotation"]

            # 바나나 서피스 생성 (비행 중)
            banana_surf = self._create_banana_surface(64)

            # 회전 적용
            rotated = pygame.transform.rotate(banana_surf, rotation)
            rect = rotated.get_rect(center=(x, y))
            screen.blit(rotated, rect)

    def _draw_landed_bananas(self, screen: pygame.Surface) -> None:
        """착지한 바나나 그리기."""
        for landed in self.landed_bananas:
            if not landed["active"]:
                continue

            x, y = int(landed["x"]), int(landed["y"])

            # 남은 시간에 따라 깜빡임
            if landed["timer"] < 60:  # 1초 미만
                if (landed["timer"] // 5) % 2 == 0:
                    continue

            # 바나나 서피스 생성 (착지한 바나나, 더 크게)
            banana_surf = self._create_banana_surface(72)
            # 살짝 기울어진 느낌
            rotated = pygame.transform.rotate(banana_surf, 15)
            rect = rotated.get_rect(center=(x, y))
            screen.blit(rotated, rect)

            # 위험 표시 (밟으면 미끄러짐)
            if not landed["slip_triggered"]:
                warning_surf = pygame.Surface((60, 20), pygame.SRCALPHA)
                pygame.draw.ellipse(warning_surf, (255, 255, 0, 80), (0, 5, 60, 10))
                screen.blit(warning_surf, (x - 30, y + 5))

    def _draw_burst_particles(self, screen: pygame.Surface) -> None:
        """터지는 파티클 그리기."""
        for particle in self.burst_particles:
            life_ratio = particle["life"] / 40
            size = max(1, int(particle["size"] * life_ratio))
            alpha = int(255 * life_ratio)

            if size > 0 and alpha > 0:
                particle_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                color_with_alpha = (*particle["color"], alpha)
                pygame.draw.circle(particle_surf, color_with_alpha, (size, size), size)
                screen.blit(particle_surf, (int(particle["x"]) - size, int(particle["y"]) - size))

    def _create_banana_surface(self, size: int) -> pygame.Surface:
        """바나나 서피스 생성."""
        surf = pygame.Surface((size, size), pygame.SRCALPHA)
        cx, cy = size // 2, size // 2

        # 바나나 색상 팔레트
        peel_dark = (198, 156, 41)
        peel_mid = (227, 189, 52)
        peel_light = (247, 220, 89)
        peel_highlight = (255, 239, 143)
        stem_green = (154, 165, 67)
        tip_dark = (89, 60, 31)

        scale = size / 48

        # 바나나 본체 (초승달 모양)
        body_points = []
        for i in range(15):
            t = i / 14
            x = cx - 15 * scale + t * 30 * scale
            curve = -10 * scale * math.sin(t * math.pi)
            y = cy + curve
            body_points.append((x, y))

        # 아래쪽 곡선
        for i in range(14, -1, -1):
            t = i / 14
            x = cx - 15 * scale + t * 30 * scale
            curve = -5 * scale * math.sin(t * math.pi) + 6 * scale
            y = cy + curve
            body_points.append((x, y))

        if len(body_points) >= 3:
            # 어두운 부분
            pygame.draw.polygon(surf, peel_dark, body_points)
            # 메인 색상
            inner_points = [(p[0], p[1] - scale) for p in body_points]
            pygame.draw.polygon(surf, peel_mid, inner_points)
            # 밝은 부분
            highlight_points = []
            for i in range(8):
                t = i / 7
                x = cx - 10 * scale + t * 20 * scale
                y = cy - 7 * scale * math.sin(t * math.pi)
                highlight_points.append((x, y))
            for i in range(7, -1, -1):
                t = i / 7
                x = cx - 10 * scale + t * 20 * scale
                y = cy - 4 * scale * math.sin(t * math.pi) + 2 * scale
                highlight_points.append((x, y))
            if len(highlight_points) >= 3:
                pygame.draw.polygon(surf, peel_light, highlight_points)

        # 꼭지
        stem_x = cx - 16 * scale
        stem_y = cy
        pygame.draw.ellipse(surf, stem_green,
                           (stem_x - 3 * scale, stem_y - 2 * scale, 5 * scale, 4 * scale))

        # 끝부분
        tip_x = cx + 16 * scale
        tip_y = cy + 2 * scale
        pygame.draw.ellipse(surf, tip_dark,
                           (tip_x - 2 * scale, tip_y - 2 * scale, 4 * scale, 3 * scale))

        return surf

    # -------------------------------------------------------------------------
    # 사운드
    # -------------------------------------------------------------------------
    def _play_throw_sound(self) -> None:
        """투척 사운드 재생 (스테이지2와 동일)."""
        try:
            import os
            sound_path = os.path.join(
                os.path.dirname(os.path.dirname(__file__)),
                "sounds",
                "throwingbanana.wav"  # 스테이지2와 동일
            )
            if os.path.exists(sound_path):
                throw_sound = pygame.mixer.Sound(sound_path)
                throw_sound.set_volume(0.6)
                throw_sound.play()
        except Exception:
            pass

    def _play_land_sound(self) -> None:
        """착지 사운드 재생."""
        # 부드러운 착지음 (없으면 무시)
        pass

    def _play_slip_sound(self) -> None:
        """미끄러짐 사운드 재생 (스테이지2와 동일)."""
        try:
            import os
            sound_path = os.path.join(
                os.path.dirname(os.path.dirname(__file__)),
                "sounds",
                "bananastep.wav"  # 스테이지2와 동일
            )
            if os.path.exists(sound_path):
                slip_sound = pygame.mixer.Sound(sound_path)
                slip_sound.set_volume(0.7)
                slip_sound.play()
        except Exception:
            pass


# 싱글톤 인스턴스
_banana_instance: Optional[Banana] = None


def get_banana_instance() -> Banana:
    """바나나 싱글톤 인스턴스 반환."""
    global _banana_instance
    if _banana_instance is None:
        _banana_instance = Banana()
    return _banana_instance