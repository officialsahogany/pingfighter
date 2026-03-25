"""
파편갑옷 (Shrapnel Armor) - 패시브 아이템
플레이어 패들이 공에 맞았을 때 일정 확률로 파편을 발사하여
보스 패들을 넉백시킨다.

롤 옵션:
- trigger_chance_pct: 발동 확률 (10~20%)
- shard_count: 파편 개수 (3~6개)
- knockback_level: 넉백 단계 (1~4)
"""

import math
import os
import random

try:
    import pygame
except ImportError:
    pygame = None


def _resource_path(relative_path: str) -> str:
    """PyInstaller 호환 리소스 경로"""
    import sys
    try:
        base_path = sys._MEIPASS
    except AttributeError:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base_path, relative_path.replace('/', os.sep).replace('\\', os.sep))


# 사운드 캐시 (한 번만 로드)
_sound_fire = None
_sound_hit = None


def _load_sounds():
    """파편 발사/명중 사운드 로드 (lazy)"""
    global _sound_fire, _sound_hit
    if not pygame or not pygame.mixer.get_init():
        return
    if _sound_fire is None:
        try:
            _sound_fire = pygame.mixer.Sound(_resource_path(os.path.join("sounds", "arrow.wav")))
            _sound_fire.set_volume(0.5)
        except Exception:
            _sound_fire = False  # 로드 실패 표시
    if _sound_hit is None:
        try:
            _sound_hit = pygame.mixer.Sound(_resource_path(os.path.join("sounds", "bullethit.wav")))
            _sound_hit.set_volume(0.6)
        except Exception:
            _sound_hit = False


class ShrapnelArmor:
    """파편갑옷 패시브 아이템 클래스"""

    def __init__(self):
        self.active = False  # 아이템 장착 여부

        # 롤 옵션 기본값
        self.trigger_chance_pct = 15   # 발동 확률 (10~20%)
        self.shard_count = 4           # 파편 개수 (3~6)
        self.knockback_level = 2       # 넉백 단계 (1~4)

        # 파편 프로젝타일 리스트
        self.shards: list[dict] = []

        # 넉백 상태
        self.boss_knockback_active = False
        self.boss_knockback_timer = 0
        self.boss_knockback_offset = 0.0   # 보스 Y 오프셋
        self.boss_knockback_velocity = 0.0  # 넉백 속도

        # 이펙트
        self._flash_timer = 0  # 발동 순간 플래시

        # 넉백 단계별 설정
        self._KNOCKBACK_CONFIG = {
            1: {"velocity": 3.0, "duration": 12, "max_offset": 15},
            2: {"velocity": 5.0, "duration": 18, "max_offset": 25},
            3: {"velocity": 7.0, "duration": 24, "max_offset": 40},
            4: {"velocity": 10.0, "duration": 30, "max_offset": 60},
        }

    def activate(self):
        """아이템 장착 활성화"""
        self.active = True

    def deactivate(self):
        """아이템 효과 전부 비활성화"""
        self.active = False
        self.shards.clear()
        self.boss_knockback_active = False
        self.boss_knockback_timer = 0
        self.boss_knockback_offset = 0.0
        self.boss_knockback_velocity = 0.0
        self._flash_timer = 0

    def on_player_hit_ball(self, paddle_cx: int, paddle_y: int):
        """플레이어 패들이 공을 쳤을 때 호출 - 파편 발사 확률 체크

        Args:
            paddle_cx: 패들 중심 X 좌표
            paddle_y: 패들 Y 좌표 (상단)

        Returns:
            True if shrapnel was fired, False otherwise
        """
        if not self.active:
            return False

        roll = random.random() * 100
        if roll > self.trigger_chance_pct:
            return False

        # 파편 생성
        count = self.shard_count
        for i in range(count):
            # 부채꼴 형태로 상방 발사 (위쪽으로)
            spread = 60  # 좌우 퍼짐 각도 (도)
            base_angle = -90  # 위쪽
            angle_deg = base_angle + spread * ((i / max(count - 1, 1)) - 0.5)
            angle_rad = math.radians(angle_deg)

            speed = random.uniform(6.0, 9.0)
            vx = math.cos(angle_rad) * speed
            vy = math.sin(angle_rad) * speed

            self.shards.append({
                "x": float(paddle_cx + random.randint(-10, 10)),
                "y": float(paddle_y),
                "vx": vx,
                "vy": vy,
                "life": 90,  # 1.5초
                "size": random.randint(3, 6),
                "rotation": random.uniform(0, 360),
                "rot_speed": random.uniform(-15, 15),
                "color_shift": random.randint(-20, 20),
                "trail": [],
            })

        self._flash_timer = 8  # 발동 플래시 (약 0.13초)

        # 파편 발사 사운드
        _load_sounds()
        if _sound_fire and _sound_fire is not False:
            _sound_fire.play()

        return True

    def check_boss_collision(self, boss_rect) -> bool:
        """파편이 보스 패들과 충돌했는지 체크

        Args:
            boss_rect: 보스 패들의 pygame.Rect

        Returns:
            True if any shard hit the boss
        """
        if not self.active or not boss_rect:
            return False

        hit = False
        remaining = []
        for shard in self.shards:
            sx, sy = int(shard["x"]), int(shard["y"])
            shard_rect = pygame.Rect(sx - 3, sy - 3, 6, 6) if pygame else None
            if shard_rect and boss_rect.colliderect(shard_rect):
                hit = True
                # 히트 이펙트 (파편 제거됨)
            else:
                remaining.append(shard)
        self.shards = remaining

        if hit:
            # 명중 사운드
            _load_sounds()
            if _sound_hit and _sound_hit is not False:
                _sound_hit.play()

            if not self.boss_knockback_active:
                self._apply_knockback()

        return hit

    def _apply_knockback(self):
        """보스에게 넉백 적용"""
        level = max(1, min(4, self.knockback_level))
        config = self._KNOCKBACK_CONFIG[level]
        self.boss_knockback_active = True
        self.boss_knockback_timer = config["duration"]
        self.boss_knockback_velocity = config["velocity"]
        self.boss_knockback_offset = 0.0

    def get_boss_knockback_offset(self) -> float:
        """현재 보스 넉백 Y 오프셋 반환 (양수 = 아래로 밀림)"""
        if self.boss_knockback_active:
            return self.boss_knockback_offset
        return 0.0

    def update(self, dt_frames=1):
        """매 프레임 호출"""
        if not self.active:
            return

        # 파편 업데이트
        alive = []
        for shard in self.shards:
            shard["x"] += shard["vx"]
            shard["y"] += shard["vy"]
            shard["vy"] += 0.08  # 미약한 중력
            shard["life"] -= dt_frames
            shard["rotation"] += shard["rot_speed"]

            # 잔상 추가
            shard["trail"].append((shard["x"], shard["y"]))
            if len(shard["trail"]) > 5:
                shard["trail"].pop(0)

            if shard["life"] > 0 and 0 <= shard["x"] <= 760 and shard["y"] < 760:
                alive.append(shard)
        self.shards = alive

        # 넉백 업데이트
        if self.boss_knockback_active:
            level = max(1, min(4, self.knockback_level))
            config = self._KNOCKBACK_CONFIG[level]

            if self.boss_knockback_timer > config["duration"] // 2:
                # 전반: 아래로 밀림
                self.boss_knockback_offset += self.boss_knockback_velocity
                self.boss_knockback_offset = min(
                    self.boss_knockback_offset, config["max_offset"]
                )
            else:
                # 후반: 원위치로 복귀
                recovery_speed = config["max_offset"] / max(1, config["duration"] // 2)
                self.boss_knockback_offset -= recovery_speed
                self.boss_knockback_offset = max(0.0, self.boss_knockback_offset)

            self.boss_knockback_timer -= dt_frames
            if self.boss_knockback_timer <= 0:
                self.boss_knockback_active = False
                self.boss_knockback_offset = 0.0
                self.boss_knockback_velocity = 0.0

        # 플래시 타이머
        if self._flash_timer > 0:
            self._flash_timer -= dt_frames

    def draw_effects(self, screen, player_rect=None, boss_rect=None):
        """파편 및 이펙트 그리기"""
        if not self.active or not pygame:
            return

        # 발동 플래시 (패들 주변)
        if self._flash_timer > 0 and player_rect:
            flash_alpha = int(120 * (self._flash_timer / 8.0))
            flash_surf = pygame.Surface((100, 30), pygame.SRCALPHA)
            flash_surf.fill((255, 140, 50, flash_alpha))
            screen.blit(flash_surf,
                        (player_rect.centerx - 50, player_rect.top - 15))

        # 파편 그리기
        for shard in self.shards:
            # 잔상
            for i, (tx, ty) in enumerate(shard["trail"]):
                trail_alpha = int(60 * (i / max(len(shard["trail"]), 1)))
                trail_size = max(1, shard["size"] - 2)
                ts = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(ts, (180, 80, 40, trail_alpha),
                                   (trail_size, trail_size), trail_size)
                screen.blit(ts, (int(tx) - trail_size, int(ty) - trail_size))

            # 파편 본체
            sx, sy = int(shard["x"]), int(shard["y"])
            size = shard["size"]
            cs = shard["color_shift"]

            # 금속 파편 색상 (회갈색 계열)
            r = max(0, min(255, 160 + cs))
            g = max(0, min(255, 100 + cs))
            b = max(0, min(255, 60 + cs // 2))

            # 삼각형 파편 (회전)
            angle = math.radians(shard["rotation"])
            points = []
            for k in range(3):
                a = angle + k * (math.pi * 2 / 3)
                px = sx + int(math.cos(a) * size)
                py = sy + int(math.sin(a) * size)
                points.append((px, py))
            pygame.draw.polygon(screen, (r, g, b), points)
            # 하이라이트
            pygame.draw.polygon(screen, (min(255, r + 40), min(255, g + 40), min(255, b + 40)),
                                points, 1)

        # 넉백 히트 이펙트 (보스 위치에 충격파)
        if self.boss_knockback_active and boss_rect and self.boss_knockback_timer > 0:
            level = max(1, min(4, self.knockback_level))
            config = self._KNOCKBACK_CONFIG[level]
            progress = self.boss_knockback_timer / config["duration"]

            if progress > 0.7:
                # 충격파 링
                ring_alpha = int(150 * progress)
                ring_radius = int(20 + (1 - progress) * 30)
                ring_surf = pygame.Surface(
                    (ring_radius * 2, ring_radius * 2), pygame.SRCALPHA
                )
                pygame.draw.circle(
                    ring_surf,
                    (255, 150, 50, ring_alpha),
                    (ring_radius, ring_radius),
                    ring_radius,
                    2,
                )
                screen.blit(
                    ring_surf,
                    (boss_rect.centerx - ring_radius,
                     boss_rect.centery - ring_radius),
                )


# ── 싱글톤 ──
_shrapnel_armor_instance = None


def get_shrapnel_armor_instance():
    """싱글톤 인스턴스 반환"""
    global _shrapnel_armor_instance
    if _shrapnel_armor_instance is None:
        _shrapnel_armor_instance = ShrapnelArmor()
    return _shrapnel_armor_instance


def activate_shrapnel_armor():
    """아이템 획득 시 호출"""
    inst = get_shrapnel_armor_instance()
    inst.activate()


def deactivate_shrapnel_armor():
    """게임 종료/메뉴 복귀 시 호출"""
    inst = get_shrapnel_armor_instance()
    inst.deactivate()


def reset_shrapnel_armor():
    """완전 초기화"""
    inst = get_shrapnel_armor_instance()
    inst.deactivate()


def configure_shrapnel_armor(trigger_chance_pct=None, shard_count=None, knockback_level=None):
    """롤 옵션 값을 인스턴스에 적용"""
    inst = get_shrapnel_armor_instance()
    if trigger_chance_pct is not None:
        inst.trigger_chance_pct = trigger_chance_pct
    if shard_count is not None:
        inst.shard_count = int(shard_count)
    if knockback_level is not None:
        inst.knockback_level = int(knockback_level)
