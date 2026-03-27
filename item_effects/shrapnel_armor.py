"""
파편갑옷 (Shrapnel Armor) - 패시브 아이템
플레이어 패들이 공에 맞았을 때 일정 확률로 파편을 발사하여
보스 패들을 넉백시킨다.

롤 옵션:
- trigger_chance_pct: 발동 확률 (15~25%)
- shard_count: 파편 개수 (5~9개)
- knockback_level: 넉백 단계 (1~4)
- gauge_cost: 게이지 소모 (25~50)
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
        self.trigger_chance_pct = 20   # 발동 확률 (15~25%)
        self.shard_count = 7           # 파편 개수 (5~9)
        self.knockback_level = 2       # 넉백 단계 (1~4)
        self.gauge_cost = 35           # 게이지 소모 (25~50)

        # 파편 프로젝타일 리스트
        self.shards: list[dict] = []
        # 소멸 파티클 (가루 증발 이펙트)
        self._dust_particles: list[dict] = []

        # 넉백: boss_fire_knockback_vel 에 주입할 초기 속도 (handle_boss 내부에서 처리)
        self.boss_knockback_active = False  # 이펙트 표시용 플래그
        self.boss_knockback_direction = 0   # 이펙트 표시용
        self._knockback_effect_timer = 0    # 충격파 이펙트용 타이머

        # 이펙트
        self._flash_timer = 0  # 발동 순간 플래시

        # 넉백 단계별 초기 속도 기준값 (레벨 5+ 는 공식으로 계산)
        self._KNOCKBACK_BASE_VELOCITY = {
            1: 6.0,
            2: 9.6,
            3: 14.4,
            4: 19.2,
        }

    def activate(self):
        """아이템 장착 활성화"""
        self.active = True

    def deactivate(self):
        """아이템 효과 전부 비활성화"""
        self.active = False
        self.shards.clear()
        self._dust_particles.clear()
        self.boss_knockback_active = False
        self.boss_knockback_direction = 0
        self._knockback_effect_timer = 0
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

            speed = random.uniform(9.4, 14.0)
            vx = math.cos(angle_rad) * speed
            vy = math.sin(angle_rad) * speed

            self.shards.append({
                "x": float(paddle_cx + random.randint(-10, 10)),
                "y": float(paddle_y),
                "vx": vx,
                "vy": vy,
                "life": 120,  # 2초
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

    def check_boss_collision(self, boss_rect) -> float:
        """파편이 보스 패들과 충돌했는지 체크

        Args:
            boss_rect: 보스 패들의 pygame.Rect

        Returns:
            넉백 초기 속도 (0이면 미명중). boss_fire_knockback_vel에 직접 대입용.
        """
        if not self.active or not boss_rect:
            return 0.0

        hit = False
        hit_direction = 0  # 명중한 파편의 X 방향 합산
        remaining = []
        for shard in self.shards:
            sx, sy = int(shard["x"]), int(shard["y"])
            shard_rect = pygame.Rect(sx - 3, sy - 3, 6, 6) if pygame else None
            if shard_rect and boss_rect.colliderect(shard_rect):
                hit = True
                hit_direction += shard["vx"]
                # 명중 시에도 가루 이펙트
                self._spawn_dust(shard["x"], shard["y"], shard["size"], shard["color_shift"])
            else:
                remaining.append(shard)
        self.shards = remaining

        if hit:
            # 명중 사운드
            _load_sounds()
            if _sound_hit and _sound_hit is not False:
                _sound_hit.play()

            # 넉백 방향: 파편 vx 합산 → 좌(-1) / 우(+1), 0이면 랜덤
            if hit_direction > 0:
                direction = 1
            elif hit_direction < 0:
                direction = -1
            else:
                direction = random.choice([-1, 1])

            # 넉백 속도 계산 (레벨 5+ 는 레벨당 +4.0씩 증가)
            level = max(1, self.knockback_level)
            if level <= 4:
                velocity = self._KNOCKBACK_BASE_VELOCITY.get(level, 8.0)
            else:
                velocity = 19.2 + (level - 4) * 4.8  # Lv5=24, Lv6=28.8, Lv7=33.6 ...
            knockback_vel = velocity * direction

            # 이펙트용 상태 업데이트
            self.boss_knockback_active = True
            self.boss_knockback_direction = direction
            self._knockback_effect_timer = 15  # 충격파 이펙트 약 0.25초

            return knockback_vel

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

            # 벽 충돌 체크 (좌우 벽 또는 상단 벽에 박히면 소멸)
            hit_wall = (shard["x"] <= 0 or shard["x"] >= 760 or shard["y"] <= 0)

            if hit_wall or shard["life"] <= 0:
                # 가루 증발 파티클 생성
                self._spawn_dust(shard["x"], shard["y"], shard["size"], shard["color_shift"])
            elif shard["y"] < 760:
                alive.append(shard)
        self.shards = alive

        # 가루 파티클 업데이트
        dust_alive = []
        for d in self._dust_particles:
            d["x"] += d["vx"]
            d["y"] += d["vy"]
            d["vy"] -= 0.03  # 위로 떠오름
            d["vx"] *= 0.96  # 감속
            d["life"] -= dt_frames
            d["size"] = max(0.3, d["size"] - 0.06)  # 점점 작아짐
            if d["life"] > 0 and d["size"] > 0.3:
                dust_alive.append(d)
        self._dust_particles = dust_alive

        # 넉백 이펙트 타이머 (충격파 표시용, 실제 넉백은 boss_fire_knockback_vel이 처리)
        if self._knockback_effect_timer > 0:
            self._knockback_effect_timer -= dt_frames
            if self._knockback_effect_timer <= 0:
                self.boss_knockback_active = False
                self.boss_knockback_direction = 0

        # 플래시 타이머
        if self._flash_timer > 0:
            self._flash_timer -= dt_frames

    def _spawn_dust(self, x: float, y: float, size: int, color_shift: int):
        """파편이 소멸할 때 가루 파티클 생성"""
        count = random.randint(4, 7)
        for _ in range(count):
            angle = random.uniform(0, math.pi * 2)
            spd = random.uniform(0.3, 1.5)
            self._dust_particles.append({
                "x": x + random.uniform(-3, 3),
                "y": y + random.uniform(-3, 3),
                "vx": math.cos(angle) * spd,
                "vy": math.sin(angle) * spd - random.uniform(0.2, 0.8),
                "life": random.randint(15, 30),
                "max_life": random.randint(15, 30),
                "size": random.uniform(1.5, float(size)),
                "cs": color_shift,
            })

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
            sx, sy = int(shard["x"]), int(shard["y"])
            size = shard["size"] + 1  # 기본 크기 약간 확대
            cs = shard["color_shift"]

            # 밝은 주황~노랑 계열 (눈에 잘 띄는 색)
            r = max(0, min(255, 255))
            g = max(0, min(255, 160 + cs))
            b = max(0, min(255, 40 + cs // 2))

            # 잔상 (밝은 오렌지 트레일)
            for i, (tx, ty) in enumerate(shard["trail"]):
                t = (i + 1) / max(len(shard["trail"]), 1)
                trail_alpha = int(100 * t)
                trail_size = max(1, int(size * t * 0.7))
                ts = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(ts, (255, 140, 30, trail_alpha),
                                   (trail_size, trail_size), trail_size)
                screen.blit(ts, (int(tx) - trail_size, int(ty) - trail_size))

            # 외곽 글로우 (파편보다 큰 반투명 원)
            glow_r = size + 4
            glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (255, 180, 50, 60), (glow_r, glow_r), glow_r)
            screen.blit(glow_surf, (sx - glow_r, sy - glow_r))

            # 뾰족한 다이아몬드형 파편 (회전) — 삼각형보다 가시적
            angle = math.radians(shard["rotation"])
            points = []
            for k in range(4):
                a = angle + k * (math.pi / 2)
                stretch = size * 1.4 if k % 2 == 0 else size * 0.7
                px = sx + int(math.cos(a) * stretch)
                py = sy + int(math.sin(a) * stretch)
                points.append((px, py))
            pygame.draw.polygon(screen, (r, g, b), points)
            # 밝은 중심 하이라이트
            pygame.draw.polygon(screen, (255, 230, 140), points, 1)
            # 중심 빛점
            pygame.draw.circle(screen, (255, 255, 200), (sx, sy), max(1, size // 3))

        # 가루 증발 파티클 그리기
        for d in self._dust_particles:
            alpha = int(200 * (d["life"] / max(d["max_life"], 1)))
            if alpha <= 0:
                continue
            dx, dy = int(d["x"]), int(d["y"])
            sz = max(1, int(d["size"]))
            cs = d["cs"]
            dr = max(0, min(255, 170 + cs))
            dg = max(0, min(255, 120 + cs))
            db = max(0, min(255, 70 + cs // 2))
            ds = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
            pygame.draw.circle(ds, (dr, dg, db, min(alpha, 255)), (sz, sz), sz)
            screen.blit(ds, (dx - sz, dy - sz))

        # 넉백 히트 이펙트 (보스 위치에 충격파)
        if self.boss_knockback_active and boss_rect and self._knockback_effect_timer > 0:
            progress = self._knockback_effect_timer / 15.0

            if progress > 0.3:
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


def configure_shrapnel_armor(trigger_chance_pct=None, shard_count=None, knockback_level=None, gauge_cost=None):
    """롤 옵션 값을 인스턴스에 적용"""
    inst = get_shrapnel_armor_instance()
    if trigger_chance_pct is not None:
        inst.trigger_chance_pct = trigger_chance_pct
    if shard_count is not None:
        inst.shard_count = int(shard_count)
    if knockback_level is not None:
        inst.knockback_level = int(knockback_level)
    if gauge_cost is not None:
        inst.gauge_cost = int(gauge_cost)
