# downtown/bodyguard_follower.py
# 광장에서 플레이어를 따라다니는 호위무사 팔로워 시스템
# 실제 영웅 스프라이트(HeroPaddleRenderer)를 사용하여 렌더링

import pygame
import math
import random

from .constants import SCREEN_WIDTH, SCREEN_HEIGHT


class BodyguardFollower:
    """투기장 우승 영웅의 인장을 장착하면 광장에서 플레이어 뒤를 따라다니는 호위무사."""

    # 영웅 렌더러 싱글톤 (클래스 레벨 공유)
    _renderer = None

    @classmethod
    def _get_renderer(cls):
        """HeroPaddleRenderer 싱글톤 가져오기."""
        if cls._renderer is None:
            try:
                from .hero_paddles import get_hero_paddle_renderer
                cls._renderer = get_hero_paddle_renderer()
            except Exception as e:
                print(f"[BodyguardFollower] HeroPaddleRenderer 로드 실패: {e}")
        return cls._renderer

    def __init__(self, hero_data: dict, follow_index: int = 0):
        """
        Args:
            hero_data: hero_seal 아이템 딕셔너리 (hero_id, hero_name, hero_color, hero_title 포함)
            follow_index: 0=첫 번째 팔로워(가까움), 1=두 번째 팔로워(멀리)
        """
        # 영웅 정보
        self.hero_id = hero_data.get("hero_id", "")
        self.hero_name = hero_data.get("hero_name", "???")
        raw_color = hero_data.get("hero_color", (200, 200, 200))
        self.hero_color = tuple(raw_color) if isinstance(raw_color, (list, tuple)) else (200, 200, 200)
        self.hero_title = hero_data.get("hero_title", "")
        self.follow_index = follow_index

        # 위치 (월드 좌표)
        self.x = 0.0
        self.y = 0.0

        # 따라가기 파라미터
        self.follow_distance = 50 + follow_index * 40  # 1번: 50px, 2번: 90px
        self.follow_speed = 0.08  # 보간 팩터

        # 이동 상태
        self.is_moving = False
        self.direction = 0  # 0=하, 1=좌, 2=우, 3=상
        self.vx = 0.0
        self.vy = 0.0

        # 영웅 스프라이트 크기 (광장용 축소 스케일)
        self.render_width = 70   # 렌더링 너비
        self.render_height = 40  # 렌더링 높이

        # 플레이어 위치 히스토리 (딜레이 따라가기용)
        self.position_history = []
        self.history_max_length = 30

        # 시각 효과
        self.effect_timer = 0.0
        self.spawn_alpha = 0
        self.is_spawned = False


    def spawn_at(self, x: float, y: float):
        """광장 진입 시 초기 위치 설정."""
        offset_y = self.follow_distance
        self.x = x
        self.y = y + offset_y
        self.position_history = [(x, y)] * self.history_max_length
        self.spawn_alpha = 0
        self.is_spawned = True

    def update(self, dt: float, player_x: float, player_y: float,
               player_direction: int, player_is_moving: bool):
        """팔로워 위치, 애니메이션 업데이트."""
        if not self.is_spawned:
            return

        self.effect_timer += dt

        # 페이드인
        if self.spawn_alpha < 255:
            self.spawn_alpha = min(255, self.spawn_alpha + int(400 * dt))

        # 플레이어 위치 히스토리 기록
        self.position_history.append((player_x, player_y))
        if len(self.position_history) > self.history_max_length:
            self.position_history.pop(0)

        # 히스토리에서 지연된 위치 가져오기
        delay_frames = 10 + self.follow_index * 8
        history_index = max(0, len(self.position_history) - 1 - delay_frames)
        trail_x, trail_y = self.position_history[history_index]

        # 플레이어 방향 기반 오프셋 (항상 뒤에 위치)
        offset_x, offset_y = self._get_direction_offset(player_direction)
        target_x = trail_x + offset_x
        target_y = trail_y + offset_y

        # 스무스 보간
        old_x, old_y = self.x, self.y
        lerp_factor = min(1.0, self.follow_speed * 60 * dt)

        # 너무 멀면 러버밴딩 (빠르게 추격)
        dist = math.sqrt((target_x - self.x) ** 2 + (target_y - self.y) ** 2)
        if dist > self.follow_distance * 3:
            lerp_factor = min(1.0, lerp_factor * 3)

        self.x += (target_x - self.x) * lerp_factor
        self.y += (target_y - self.y) * lerp_factor

        # 속도 계산 (애니메이션용)
        safe_dt = max(dt, 0.001)
        self.vx = (self.x - old_x) / safe_dt
        self.vy = (self.y - old_y) / safe_dt

        # 이동 상태 및 방향 결정
        speed = math.sqrt(self.vx ** 2 + self.vy ** 2)
        self.is_moving = speed > 5.0

        if self.is_moving:
            if abs(self.vx) > abs(self.vy):
                self.direction = 1 if self.vx < 0 else 2
            else:
                self.direction = 3 if self.vy < 0 else 0
        else:
            self.direction = player_direction

        # 영웅 렌더러 애니메이션 업데이트
        renderer = self._get_renderer()
        if renderer:
            renderer.update(dt)
            # update_movement는 X 위치 변화로 좌우 이동/side_blend 계산
            renderer.update_movement(self.hero_id, self.x, dt)

    def _get_direction_offset(self, player_direction: int):
        """플레이어 방향 기준 뒤쪽 오프셋 계산."""
        d = self.follow_distance
        offsets = {
            0: (0, -d),    # 플레이어 아래 향함 → 팔로워 위에
            1: (d, 0),     # 플레이어 왼쪽 향함 → 팔로워 오른쪽에
            2: (-d, 0),    # 플레이어 오른쪽 향함 → 팔로워 왼쪽에
            3: (0, d),     # 플레이어 위 향함 → 팔로워 아래에
        }
        return offsets.get(player_direction, (0, -d))

    # ------------------------------------------------------------------
    # 렌더링
    # ------------------------------------------------------------------

    def draw(self, screen, camera_offset=(0, 0)):
        """호위무사 팔로워 그리기 - 실제 영웅 스프라이트 사용."""
        if not self.is_spawned:
            return

        draw_x = self.x - camera_offset[0]
        draw_y = self.y - camera_offset[1]

        # 화면 밖 컬링
        if draw_x < -100 or draw_x > SCREEN_WIDTH + 100:
            return
        if draw_y < -100 or draw_y > SCREEN_HEIGHT + 100:
            return

        # 그림자
        self._draw_shadow(screen, draw_x, draw_y)

        # 영웅 캐릭터 스프라이트 (HeroPaddleRenderer 사용)
        self._draw_hero_sprite(screen, draw_x, draw_y)


    def _draw_shadow(self, screen, x, y):
        """그림자 그리기."""
        shadow_w = 36
        shadow_h = 10
        shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
        shadow_alpha = min(self.spawn_alpha, 50)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, shadow_alpha),
                            (0, 0, shadow_w, shadow_h))
        screen.blit(shadow_surf, (int(x) - shadow_w // 2, int(y) + 12))

    def _draw_hero_sprite(self, screen, x, y):
        """HeroPaddleRenderer를 사용하여 실제 영웅 스프라이트 그리기."""
        renderer = self._get_renderer()
        if not renderer:
            # 렌더러 없으면 폴백: 심플 컬러 원
            self._draw_fallback(screen, x, y)
            return

        # 방향 → facing 변환
        # HeroPaddleRenderer는 facing="down"(정면), facing="up"(후면)만 지원
        # 좌우 이동은 update_movement의 side_blend로 자동 처리됨
        d = self.direction
        if d == 3:  # 위를 바라봄 = 뒷모습
            facing = "up"
        else:  # 아래/좌/우 = 정면 (좌우는 side_blend로 처리)
            facing = "down"

        # 영웅 스프라이트 렌더링
        renderer.draw_hero_paddle(
            screen,
            self.hero_id,
            x, y,
            self.render_width,
            self.render_height,
            facing=facing,
            color=self.hero_color,
            scale_mode="paddle",
        )

    def _draw_fallback(self, screen, x, y):
        """HeroPaddleRenderer 없을 때 폴백 렌더링."""
        r, g, b = self.hero_color
        # 몸체
        pygame.draw.ellipse(screen, self.hero_color,
                            (int(x) - 12, int(y) - 15, 24, 30), border_radius=4)
        # 외곽선
        pygame.draw.ellipse(screen, (min(255, r + 50), min(255, g + 50), min(255, b + 50)),
                            (int(x) - 12, int(y) - 15, 24, 30), width=2)



class BodyguardFollowerManager:
    """광장에서 최대 2명의 호위무사 팔로워를 관리."""

    def __init__(self):
        self.followers = []
        self._last_seal_ids = []

    def refresh_from_equipped_seals(self):
        """장착된 hero_seal 아이템을 읽어 팔로워 생성/갱신."""
        seals = []
        try:
            import pingfighter
            equipped = pingfighter.get_equipped_passive_items()
            seals = [item for item in equipped
                     if isinstance(item, dict) and item.get("name") == "hero_seal"]
        except Exception:
            pass

        # 변경 여부 확인
        new_ids = [s.get("hero_id", "") for s in seals]
        if new_ids == self._last_seal_ids and self.followers:
            return

        self._last_seal_ids = new_ids

        # 팔로워 재생성
        self.followers.clear()
        for idx, seal in enumerate(seals[:2]):
            follower = BodyguardFollower(seal, follow_index=idx)
            self.followers.append(follower)

    def spawn_all(self, player_x: float, player_y: float):
        """모든 팔로워를 플레이어 근처에 스폰."""
        for follower in self.followers:
            follower.spawn_at(player_x, player_y)

    def update(self, dt: float, player_x: float, player_y: float,
               player_direction: int, player_is_moving: bool):
        """모든 팔로워 업데이트."""
        for follower in self.followers:
            follower.update(dt, player_x, player_y, player_direction, player_is_moving)

    def draw(self, screen, camera_offset=(0, 0)):
        """모든 팔로워 그리기 (Y-sort 없이 단독 사용 시)."""
        for follower in self.followers:
            follower.draw(screen, camera_offset)
