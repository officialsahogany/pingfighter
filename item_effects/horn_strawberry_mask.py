"""
뿔딸기 변신가면 (Horn Strawberry Mask) - 전설 아이템 효과 모듈

머리 부위 전설 아이템.
커맨드 입력(A→W→D, 1.5초 이내)으로 게이지 소모 후 60초간 뿔딸기로 변신.
변신 중: 패들 30% 크기 증가, 이동속도 8, 공 타격 시 게이지 +30
전용 스킬 3종: 뿔박치기(W), 딸기장판(S홀드), 딸기먹기(Space/클릭)
"""

import math
import os
import random
import pygame

from resource_path import resource_path

try:
    from downtown.hero_skills import BoneBarrier as HeroBoneBarrier
    from downtown.hero_skills import HornCharge as HeroHornCharge
except Exception:
    HeroBoneBarrier = None
    HeroHornCharge = None

# 사운드 캐시 (한 번만 로드)
_sound_stem_fire = None   # 꼭지 발사 사운드
_sound_stem_hit = None    # 꼭지 명중 사운드
_sound_transform = None   # 변신 사운드


def _load_stem_sounds():
    """딸기 꼭지 발사/명중 사운드 로드 (lazy)"""
    global _sound_stem_fire, _sound_stem_hit
    if not pygame.mixer.get_init():
        return
    if _sound_stem_fire is None:
        try:
            _sound_stem_fire = pygame.mixer.Sound(resource_path(os.path.join("sounds", "arrow.wav")))
            _sound_stem_fire.set_volume(0.5)
        except Exception:
            _sound_stem_fire = False
    if _sound_stem_hit is None:
        try:
            _sound_stem_hit = pygame.mixer.Sound(resource_path(os.path.join("sounds", "bullethit.wav")))
            _sound_stem_hit.set_volume(0.4)
        except Exception:
            _sound_stem_hit = False


def _play_transform_sound():
    """변신 사운드 재생 (lazy 로드)"""
    global _sound_transform
    if not pygame.mixer.get_init():
        return
    if _sound_transform is None:
        try:
            _sound_transform = pygame.mixer.Sound(resource_path(os.path.join("sounds", "strawberrychange.wav")))
            _sound_transform.set_volume(0.7)
        except Exception:
            _sound_transform = False
    if _sound_transform and _sound_transform is not False:
        try:
            _sound_transform.play()
        except Exception:
            pass

# ── 상수 ──────────────────────────────────────────────────
COMMAND_SEQUENCE = [pygame.K_a, pygame.K_w, pygame.K_d]  # A→W→D
COMMAND_TIMEOUT = 1.5  # 커맨드 입력 허용 시간 (초)
TRANSFORM_GAUGE_COST = 500  # 게이지 소모 (고정)
TRANSFORM_DURATION = 60.0  # 기본 변신 지속시간 (초, 롤옵션으로 변동)
TRANSFORM_START_EVENT_DURATION = 4.5  # 변신 시작 이벤트 시간 (초) — 화려한 4단계 연출
TRANSFORM_END_EVENT_DURATION = 2.0  # 변신 해제 이벤트 시간 (초)

# 변신 중 능력치
TRANSFORM_MOVE_SPEED = 8  # 이동속도
TRANSFORM_GAUGE_ON_HIT = 80  # 공 타격 시 게이지 회복 (단독 충전, 기본 캐릭터 충전 대체)

# 스킬: 뿔박치기 (W)
HORN_CHARGE_GAUGE_COST = 300
HORN_CHARGE_COOLDOWN = 20.0  # 초
HORN_CHARGE_PHASES = {
    "CHARGING": 0.43,   # 돌진
    "IMPACT": 0.2,      # 충돌
    "RETURNING": 0.5,   # 복귀
    "STUN": 1.5,        # 경직
}

# 스킬: 딸기장판 (S 홀드)
STRAWBERRY_FIELD_GAUGE_COST = 100  # 홀딩 중 총 소모
STRAWBERRY_FIELD_COOLDOWN = 10.0
STRAWBERRY_FIELD_HOLD_MIN = 1.0  # 최소 홀드 시간 (초)
STRAWBERRY_FIELD_WIDTH = 180
STRAWBERRY_FIELD_HEIGHT = 12

# 스킬: 딸기먹기 (Space/클릭)
STRAWBERRY_EAT_DURATION = 0.8  # 먹는 시간 (초)
STRAWBERRY_EAT_GAUGE_COST = 50
STRAWBERRY_EAT_PADDLE_GROWTH_BONUS = 0.20
STRAWBERRY_STEM_BURST_COUNT = 3
STRAWBERRY_STEM_BURST_INTERVAL = 0.08
STRAWBERRY_STEM_SPREAD_DEGREES = 10.0
STRAWBERRY_EAT_COOLDOWN = 0.8
STRAWBERRY_STEM_SPEED_MULT = 2.5  # 권총 대비 250% 속도 (빠른 투사체)
STRAWBERRY_STEM_KNOCKBACK = 32.2  # 현재 권총급 넉백(14)의 2.3배

# 스킬: 딸기폭탄 (A+D 동시 홀드 0.5초)
STRAWBERRY_BOMB_GAUGE_COST = 400
STRAWBERRY_BOMB_COOLDOWN = 30.0
STRAWBERRY_BOMB_COUNT = 30  # 1초간 투척 개수
STRAWBERRY_BOMB_THROW_DURATION = 1.0  # 투척 시간 (초)
STRAWBERRY_BOMB_HOP_INTERVAL = 0.38  # 점프 궤적 변경 간격 (초) — 넓직한 포물선
STRAWBERRY_BOMB_BASE_SPEED = 3.2  # 기본 이동 속도
STRAWBERRY_BOMB_HOP_HEIGHT = 55.0  # 점프 높이 (넓은 포물선)
STRAWBERRY_BOMB_STUN_DURATION = 1.0  # 폭발 시 스턴 (초)
STRAWBERRY_BOMB_KNOCKBACK = 50.0  # 폭발 시 넉백
STRAWBERRY_BOMB_PAINT_DURATION = 5.0  # 페인트 지속시간 (초)
STRAWBERRY_BOMB_PAINT_SLOW = 0.30  # 이동속도 30% 감소
STRAWBERRY_BOMB_PAINT_RADIUS = 28  # 페인트 반경
STRAWBERRY_BOMB_HOLD_TIME = 0.5  # A+D 동시 홀드 필요 시간 (초)

# ── 색상 팔레트 ──────────────────────────────────────────
STRAWBERRY_RED = (220, 40, 50)
STRAWBERRY_DARK = (180, 20, 30)
STRAWBERRY_LIGHT = (240, 70, 70)
STRAWBERRY_HIGHLIGHT = (255, 120, 120)
GREEN_DARK = (30, 100, 20)
GREEN_MID = (50, 150, 40)
GREEN_BRIGHT = (80, 200, 60)
SEED_COLOR = (240, 220, 100)

# ── 변신 연출 전용 상큼 파스텔 팔레트 ──
_TF_PINK_SOFT = (255, 180, 200)      # 부드러운 분홍
_TF_PINK_HOT = (255, 100, 140)       # 진한 핑크
_TF_CORAL = (255, 130, 110)          # 코랄
_TF_CREAM = (255, 240, 210)          # 크림색
_TF_MINT = (160, 240, 200)           # 민트
_TF_LEAF = (100, 200, 80)            # 상큼한 잎
_TF_GOLD_SPARK = (255, 230, 120)     # 금빛 반짝
_TF_WHITE_GLOW = (255, 250, 245)     # 따스한 화이트


def _build_bottom_skill_context(player_rect, boss_rect, ball_rect, ball_vel):
    """Build lightweight wrappers that match downtown.hero_skills expectations."""

    class _PaddleProxy:
        def __init__(self, rect, is_top):
            # x를 centerx로 설정 — HornCharge가 caster_original_x = paddle.x로 저장하는데
            # 이걸 패들 중앙으로 해야 돌진 후 원래 위치로 정확히 복귀한다
            self.x = float(rect.centerx) if rect is not None else 0.0
            self.y = float(rect.y) if rect is not None else 0.0
            self.width = int(rect.width) if rect is not None else 0
            self.height = int(rect.height) if rect is not None else 0
            self.is_top = is_top

    class _BallProxy:
        def __init__(self, rect, vel):
            self.x = float(rect.x) if rect is not None else 0.0
            self.y = float(rect.y) if rect is not None else 0.0
            self.width = int(rect.width) if rect is not None else 0
            self.height = int(rect.height) if rect is not None else 0
            self.vx = float(vel[0]) if vel is not None else 0.0
            self.vy = float(vel[1]) if vel is not None else 0.0

        def sync_velocity(self, vel):
            if vel is None:
                return
            vel[0] = self.vx
            vel[1] = self.vy

    return _PaddleProxy(player_rect, False), _PaddleProxy(boss_rect, True), _BallProxy(ball_rect, ball_vel)


def _draw_strawberry_sprite(screen, cx, cy, size, alpha=255, tilt=0.0):
    """Draw a small strawberry sprite with optional alpha/tilt."""
    size = max(6, int(size))
    alpha = max(0, min(255, int(alpha)))
    if alpha <= 0:
        return

    surf_size = size * 4
    surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
    center = surf_size // 2

    body_w = max(8, int(size * 1.25))
    body_h = max(10, int(size * 1.55))
    body_rect = pygame.Rect(center - body_w // 2, center - body_h // 2 + int(size * 0.1), body_w, body_h)

    shadow_rect = body_rect.move(2, 3)
    pygame.draw.ellipse(surf, (90, 12, 20, min(alpha, 90)), shadow_rect)
    pygame.draw.ellipse(surf, (*STRAWBERRY_RED, alpha), body_rect)
    pygame.draw.ellipse(surf, (*STRAWBERRY_LIGHT, int(alpha * 0.85)),
                        (body_rect.x + 2, body_rect.y + 1, max(4, body_rect.w - 4), max(4, body_rect.h // 2)))
    pygame.draw.ellipse(surf, (*STRAWBERRY_HIGHLIGHT, int(alpha * 0.55)),
                        (body_rect.x + 3, body_rect.y + 2, max(3, body_rect.w - 8), max(2, body_rect.h // 5)))
    pygame.draw.ellipse(surf, (*STRAWBERRY_DARK, alpha), body_rect, 1)

    seed_positions = (
        (-0.22, -0.08), (0.18, -0.04), (-0.28, 0.18), (0.0, 0.2), (0.27, 0.14)
    )
    for sx_mul, sy_mul in seed_positions:
        sx = int(center + sx_mul * body_w)
        sy = int(center + sy_mul * body_h)
        pygame.draw.ellipse(surf, (*SEED_COLOR, int(alpha * 0.95)), (sx - 1, sy - 1, 3, 2))

    leaf_base_y = body_rect.y + 2
    leaf_span = max(4, body_w // 3)
    for side in (-1, 1):
        hx = center + side * leaf_span
        leaf_tip_x = hx + side * max(2, size // 6)
        leaf_tip_y = leaf_base_y - max(6, int(size * 0.55))
        pygame.draw.polygon(
            surf,
            (*GREEN_MID, alpha),
            [(hx - 3, leaf_base_y + 1), (hx + 3, leaf_base_y + 1), (leaf_tip_x, leaf_tip_y)],
        )
        pygame.draw.polygon(
            surf,
            (*GREEN_BRIGHT, int(alpha * 0.7)),
            [(hx - 1, leaf_base_y), (hx + 1, leaf_base_y), (leaf_tip_x, leaf_tip_y + 2)],
        )

    stem_h = max(4, int(size * 0.35))
    pygame.draw.line(
        surf,
        (*GREEN_DARK, alpha),
        (center, leaf_base_y + 1),
        (center, leaf_base_y - stem_h),
        2,
    )

    if abs(tilt) > 0.05:
        surf = pygame.transform.rotozoom(surf, tilt, 1.0)

    rect = surf.get_rect(center=(int(cx), int(cy)))
    screen.blit(surf, rect)


class HornStrawberryTransformState:
    """뿔딸기 변신 상태 관리"""

    # 상태 머신
    IDLE = 0               # 미변신
    TRANSFORM_EVENT = 1    # 변신 이벤트 연출 중 (3초)
    TRANSFORMED = 2        # 변신 상태
    DETRANSFORM_EVENT = 3  # 변신 해제 이벤트 연출 중 (2초)

    def __init__(self):
        self.active = False  # 아이템 장착 중
        self.state = self.IDLE
        self.transform_timer = 0.0  # 변신 남은 시간
        self.event_timer = 0.0  # 이벤트 연출 타이머
        self._used_this_stage = False  # 이번 스테이지에서 이미 변신했는지

        # 커맨드 입력 추적
        self.command_buffer = []  # 입력된 키 시퀀스
        self.command_timer = 0.0  # 커맨드 입력 타이머
        self.prev_keys = {}  # 이전 프레임 키 상태

        # 스킬 상태
        self.horn_charge = _HornChargeSkillCore()
        self.strawberry_field = _StrawberryFieldSkillCore()
        self.strawberry_eat = StrawberryEatSkill()
        self.strawberry_bomb = StrawberryBombSkill()

        # 변신 연출 파티클
        self.event_particles = []
        self.flash_alpha = 0

        # ── 화려한 변신 연출용 상태 ──
        self._tf_swirl_particles = []   # 소용돌이 딸기 파티클
        self._tf_energy_radius = 0.0    # 중앙 에너지 광원 반지름
        self._tf_spin_angle = 0.0       # 캐릭터 Y축 회전 각도
        self._tf_levitate_y = 0.0       # 부양 높이 오프셋
        self._tf_burst_alpha = 0        # 폭발 플래시 알파
        self._tf_descend_y = 0.0        # 착지 높이 (뿔딸기 등장)
        self._tf_light_rays = []        # 빛줄기 각도 목록
        self._tf_flash_triggered = False  # 번쩍임 트리거 여부
        self._tf_paddle_snapshot = None  # 실제 패들 서피스 캡처 (회전 연출용)

        # 롤옵션 캐시 (장착 시 동기화)
        self._transform_duration = TRANSFORM_DURATION
        self._gauge_cost = TRANSFORM_GAUGE_COST
        self._paddle_size_bonus = 0.0  # 기본 패들 보너스 없음 (딸기먹기 성장만)
        self._eat_paddle_growth_bonus = 0.0
        self._eat_input_prev_down = False

    def sync_roll_options(self, legendary_item):
        """전설 아이템 인스턴스에서 롤옵션 값 동기화 (변신 지속시간만)"""
        if legendary_item:
            self._transform_duration = legendary_item.transform_duration
            self._gauge_cost = TRANSFORM_GAUGE_COST  # 고정 500
            self._paddle_size_bonus = 0.0  # 없음

    def deactivate(self):
        """장착 해제 시 변신 상태만 해제 (_used_this_stage는 유지)"""
        used = self._used_this_stage
        self.state = self.IDLE
        self.transform_timer = 0.0
        self.event_timer = 0.0
        self._eat_paddle_growth_bonus = 0.0
        self.command_buffer.clear()
        self.command_timer = 0.0
        self.prev_keys.clear()
        self.horn_charge.reset()
        self.strawberry_field.reset()
        self.strawberry_eat.reset()
        self.strawberry_bomb.reset()
        self.event_particles.clear()
        self.flash_alpha = 0
        self._eat_input_prev_down = False
        self._tf_swirl_particles = []
        self._tf_energy_radius = 0.0
        self._tf_spin_angle = 0.0
        self._tf_levitate_y = 0.0
        self._tf_burst_alpha = 0
        self._tf_descend_y = 0.0
        self._tf_light_rays = []
        self._tf_flash_triggered = False
        self._tf_paddle_snapshot = None
        self._used_this_stage = used  # 스테이지당 1회 제한 유지

    def reset(self):
        """게임 종료/메뉴 복귀 시 완전 초기화"""
        self.deactivate()
        self._used_this_stage = False

    @property
    def is_transformed(self):
        return self.state == self.TRANSFORMED

    @property
    def is_event_playing(self):
        return self.state in (self.TRANSFORM_EVENT, self.DETRANSFORM_EVENT)

    def update_command_input(self, keys, dt):
        """커맨드 입력 감지 (A→W→D)"""
        if self.state != self.IDLE or not self.active or self._used_this_stage:
            return False

        # 커맨드 타이머 업데이트
        if self.command_buffer:
            self.command_timer += dt
            if self.command_timer > COMMAND_TIMEOUT:
                self.command_buffer.clear()
                self.command_timer = 0.0

        # 키 트리거 감지 (눌림 순간만)
        for key in COMMAND_SEQUENCE:
            was_pressed = self.prev_keys.get(key, False)
            is_pressed = keys[key]
            if is_pressed and not was_pressed:
                expected_idx = len(self.command_buffer)
                if expected_idx < len(COMMAND_SEQUENCE) and COMMAND_SEQUENCE[expected_idx] == key:
                    self.command_buffer.append(key)
                    if expected_idx == 0:
                        self.command_timer = 0.0  # 첫 입력 시 타이머 시작
                else:
                    # 잘못된 키 → 리셋
                    self.command_buffer.clear()
                    self.command_timer = 0.0

        # 키 상태 저장
        for key in COMMAND_SEQUENCE:
            self.prev_keys[key] = keys[key]

        # 커맨드 완성 확인
        if len(self.command_buffer) >= len(COMMAND_SEQUENCE):
            self.command_buffer.clear()
            self.command_timer = 0.0
            return True  # 커맨드 완성!

        return False

    def try_transform(self, current_gauge, consume_gauge_fn):
        """변신 시도 (게이지 충분하면 변신 시작, 스테이지당 1회)"""
        if self._used_this_stage:
            return False
        cost = self._gauge_cost
        if current_gauge >= cost:
            consume_gauge_fn(cost)
            self.state = self.TRANSFORM_EVENT
            self.event_timer = TRANSFORM_START_EVENT_DURATION
            self.flash_alpha = 255
            self._used_this_stage = True
            self._spawn_transform_particles()
            self._init_transform_cinema()
            _play_transform_sound()
            return True
        return False

    def update(self, dt):
        """매 프레임 업데이트"""
        if self.state == self.TRANSFORM_EVENT:
            self.event_timer -= dt
            self.flash_alpha = max(0, int(255 * (self.event_timer / TRANSFORM_START_EVENT_DURATION)))
            if self.event_timer <= 0:
                self.state = self.TRANSFORMED
                self.transform_timer = self._transform_duration
                self._eat_paddle_growth_bonus = 0.0
                self._eat_input_prev_down = False
                self.horn_charge.reset()
                self.strawberry_field.reset()
                self.strawberry_eat.reset()
                self.strawberry_bomb.reset()

        elif self.state == self.TRANSFORMED:
            self.transform_timer -= dt
            # 스킬 쿨타임 업데이트
            self.horn_charge.update_cooldown(dt)
            self.strawberry_field.update_cooldown(dt)
            self.strawberry_eat.update_cooldown(dt)
            self.strawberry_bomb.update_cooldown(dt)

            if self.transform_timer <= 0:
                self._eat_paddle_growth_bonus = 0.0
                self._eat_input_prev_down = False
                self.horn_charge.reset()
                # strawberry_field는 리셋하지 않음 — 변신 종료 후에도 장판 유지
                self.strawberry_eat.reset()
                # strawberry_bomb: 투척 중단, 페인트는 유지
                self.strawberry_bomb.throwing = False
                self.strawberry_bomb.active = False
                self.strawberry_bomb._anchor_player_centerx = None
                self.state = self.DETRANSFORM_EVENT
                self.event_timer = TRANSFORM_END_EVENT_DURATION
                self.flash_alpha = 255
                self._spawn_transform_particles()

        elif self.state == self.DETRANSFORM_EVENT:
            self.event_timer -= dt
            self.flash_alpha = max(0, int(255 * (self.event_timer / TRANSFORM_END_EVENT_DURATION)))
            if self.event_timer <= 0:
                self.state = self.IDLE
                self.flash_alpha = 0
                self._eat_input_prev_down = False

        # 이벤트 파티클 업데이트 (항상)
        self._update_event_particles(dt)

    def _init_transform_cinema(self):
        """화려한 변신 연출 초기화"""
        self._tf_swirl_particles = []
        self._tf_energy_radius = 0.0
        self._tf_spin_angle = 0.0
        self._tf_levitate_y = 0.0
        self._tf_burst_alpha = 0
        self._tf_descend_y = -60.0  # 공중에서 시작
        self._tf_light_rays = [random.uniform(0, 360) for _ in range(12)]
        self._tf_flash_triggered = False

    def _spawn_transform_particles(self):
        """변신 이벤트 파티클 생성"""
        self.event_particles.clear()
        for _ in range(60):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 8)
            self.event_particles.append({
                "x": 0, "y": 0,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed,
                "life": random.uniform(1.0, 3.5),
                "max_life": 3.5,
                "color": random.choice([
                    STRAWBERRY_RED, STRAWBERRY_LIGHT, GREEN_MID,
                    GREEN_BRIGHT, SEED_COLOR, STRAWBERRY_HIGHLIGHT
                ]),
                "size": random.uniform(3, 10),
            })

    def _update_event_particles(self, dt):
        """이벤트 파티클 업데이트"""
        alive = []
        for p in self.event_particles:
            p["life"] -= dt
            p["x"] += p["vx"]
            p["y"] += p["vy"]
            p["vy"] += 0.15  # 중력
            if p["life"] > 0:
                alive.append(p)
        self.event_particles = alive

    def _update_swirl_particles(self, dt, cx, cy, progress):
        """소용돌이 딸기 파티클 업데이트 (Phase 2)"""
        # 새 파티클 지속 생성
        if progress < 0.75 and random.random() < 0.6:
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(60, 140)
            self._tf_swirl_particles.append({
                "angle": angle,
                "dist": dist,
                "y_off": random.uniform(-30, 30),
                "speed": random.uniform(2.5, 5.0),
                "life": random.uniform(1.0, 2.0),
                "max_life": 2.0,
                "size": random.uniform(5, 14),
                "color": random.choice([
                    STRAWBERRY_RED, STRAWBERRY_LIGHT, STRAWBERRY_DARK,
                    (255, 80, 100), (255, 50, 70), STRAWBERRY_HIGHLIGHT
                ]),
                "is_strawberry": random.random() < 0.35,
            })
        alive = []
        for p in self._tf_swirl_particles:
            p["life"] -= dt
            p["angle"] += p["speed"] * dt
            # 소용돌이: 점점 안으로 빨려들어감
            p["dist"] *= (1.0 - dt * 0.8)
            if p["life"] > 0 and p["dist"] > 5:
                alive.append(p)
        self._tf_swirl_particles = alive

    def _draw_paddle_spinning(self, screen, cx, cy, spin_angle, alpha=255):
        """Y축 회전 중인 실제 패들 캐릭터 (머리를 축으로 발레리노 회전)

        캡처된 _tf_paddle_snapshot을 수평 스케일링하여 Y축 회전을 시뮬레이션.
        스냅샷이 없으면 폴백 실루엣 사용.
        cy는 패들의 시각적 중심 Y 좌표 (호출부에서 보정하여 전달).
        """
        # Y축 회전: cos(angle)으로 수평 폭 결정
        h_scale = math.cos(spin_angle)
        abs_h = max(0.08, abs(h_scale))

        snapshot = self._tf_paddle_snapshot
        if snapshot is not None:
            orig_w, orig_h = snapshot.get_size()
            # 수평 스케일링으로 Y축 회전 시뮬레이션
            new_w = max(4, int(orig_w * abs_h))
            new_h = orig_h
            try:
                scaled = pygame.transform.smoothscale(snapshot, (new_w, new_h))
            except Exception:
                scaled = pygame.transform.scale(snapshot, (new_w, new_h))

            if alpha < 255:
                scaled.set_alpha(alpha)

            # 캐릭터 중심에 배치 (center 기준)
            rect = scaled.get_rect(center=(int(cx), int(cy)))
            screen.blit(scaled, rect)

            # 회전 잔상 (반대편에 희미하게)
            if alpha > 60:
                ghost_alpha = max(20, alpha // 5)
                ghost_offset = int(8 * h_scale)  # 회전 방향에 따라 좌우 오프셋
                ghost = scaled.copy()
                ghost.set_alpha(ghost_alpha)
                ghost_rect = ghost.get_rect(center=(int(cx) + ghost_offset, int(cy)))
                screen.blit(ghost, ghost_rect)
        else:
            # 스냅샷 없으면 폴백: 타원 실루엣
            pw = int(80 * abs_h)
            ph = 20
            if pw < 2:
                return
            surf = pygame.Surface((pw + 20, ph + 30), pygame.SRCALPHA)
            scx = (pw + 20) // 2
            scy = (ph + 30) // 2
            pygame.draw.ellipse(surf, (200, 180, 160, min(255, alpha)),
                                (scx - pw // 2, scy - ph // 2, pw, ph))
            rect = surf.get_rect(center=(int(cx), int(cy)))
            screen.blit(surf, rect)

        # 글로우 후광 — 캐릭터 중심에 맞춤
        glow_r = max(40, int(60 * abs_h)) + 12
        glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
        glow_alpha = min(50, alpha // 4)
        pygame.draw.circle(glow_surf, (255, 200, 200, glow_alpha), (glow_r, glow_r), glow_r)
        screen.blit(glow_surf, (int(cx) - glow_r, int(cy) - glow_r))

    def draw_transform_event(self, screen, player_x, player_y):
        """변신/해제 이벤트 연출 그리기 — 4단계 시네마틱"""
        if self.state not in (self.TRANSFORM_EVENT, self.DETRANSFORM_EVENT):
            return

        w, h = screen.get_size()
        is_transforming = self.state == self.TRANSFORM_EVENT

        if not is_transforming:
            # ── 변신 해제 연출 (기존과 유사, 간단) ──
            if self.flash_alpha > 0:
                flash_surf = pygame.Surface((w, h), pygame.SRCALPHA)
                flash_surf.fill((200, 200, 255, min(150, self.flash_alpha)))
                screen.blit(flash_surf, (0, 0))
            progress = 1.0 - (self.event_timer / TRANSFORM_END_EVENT_DURATION)
            base_size = 48
            if progress < 0.3:
                text_scale = progress / 0.3
            elif progress > 0.8:
                text_scale = (1.0 - progress) / 0.2
            else:
                text_scale = 1.0
            font_size = max(16, int(base_size * text_scale))
            try:
                font = pygame.font.SysFont("malgungothic", font_size)
                shadow_surf = font.render("변신해제...", True, (0, 0, 0))
                screen.blit(shadow_surf, shadow_surf.get_rect(center=(w // 2 + 2, h // 2 - 40 + 2)))
                text_surf = font.render("변신해제...", True, (150, 150, 200))
                screen.blit(text_surf, text_surf.get_rect(center=(w // 2, h // 2 - 40)))
            except Exception:
                pass
            for p in self.event_particles:
                alpha = max(0, min(255, int(255 * p["life"] / p["max_life"])))
                px, py = int(player_x + p["x"]), int(player_y + p["y"])
                sz = max(1, int(p["size"] * (p["life"] / p["max_life"])))
                ps = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
                pygame.draw.circle(ps, (*p["color"], alpha), (sz, sz), sz)
                screen.blit(ps, (px - sz, py - sz))
            return

        # ════════════════════════════════════════════════════════
        # ── 변신 시작 연출: 4단계 시네마틱 (귀엽고 상큼한 마법소녀 테마) ──
        # ════════════════════════════════════════════════════════
        dt = 1.0 / 60.0
        total = TRANSFORM_START_EVENT_DURATION
        progress = 1.0 - (self.event_timer / total)  # 0 → 1
        t_ms = pygame.time.get_ticks()

        cx = player_x
        base_y = player_y

        # 패들 시각적 중심 오프셋
        _snap = self._tf_paddle_snapshot
        _half_h = (_snap.get_height() // 2) if _snap is not None else 50

        # ── Phase 1 (0~35%): 반짝이는 상승 — 발레리노 회전 + 꽃잎/별빛 부양 ──
        if progress < 0.35:
            p1 = progress / 0.35

            # 회전 가속 (부드럽게)
            self._tf_spin_angle += dt * (1.5 + p1 * 8.0)
            target_lev = -80.0 - _half_h
            self._tf_levitate_y = target_lev * (1.0 - (1.0 - p1) ** 2)
            center_y = base_y + self._tf_levitate_y + _half_h

            # 부드러운 비네트 (핑크 틴트)
            dim_alpha = int(25 * p1)
            if dim_alpha > 0:
                dim_surf = pygame.Surface((w, h), pygame.SRCALPHA)
                dim_surf.fill((30, 0, 15, dim_alpha))
                screen.blit(dim_surf, (0, 0))

            # ★ 상승 기류 — 아래에서 위로 올라오는 부드러운 빛 줄기
            for i in range(3):
                stream_x = cx + (i - 1) * 25
                stream_a = int(35 * p1)
                if stream_a > 0:
                    stream_h = int(60 + 80 * p1)
                    ss = pygame.Surface((12, stream_h), pygame.SRCALPHA)
                    for sy in range(stream_h):
                        sa = int(stream_a * (1.0 - sy / stream_h) * (0.5 + 0.5 * math.sin(t_ms * 0.005 + i)))
                        sa = max(0, min(255, sa))
                        pygame.draw.line(ss, (*_TF_PINK_SOFT, sa), (4, sy), (8, sy))
                    screen.blit(ss, (stream_x - 6, int(center_y)))

            # ★ 캐릭터 그리기 (회전)
            paddle_alpha = max(80, int(255 * (1.0 - p1 * 0.3)))
            self._draw_paddle_spinning(screen, cx, center_y, self._tf_spin_angle, paddle_alpha)

            # ★ 반짝이 별빛 파티클 (위로 부유)
            if random.random() < 0.4 + p1 * 0.6:
                sp_angle = random.uniform(0, math.pi * 2)
                sp_dist = random.uniform(15, 50)
                self.event_particles.append({
                    "x": math.cos(sp_angle) * sp_dist,
                    "y": math.sin(sp_angle) * sp_dist * 0.4,
                    "vx": random.uniform(-0.8, 0.8),
                    "vy": random.uniform(-2.5, -1.0),
                    "life": random.uniform(0.8, 1.8),
                    "max_life": 1.8,
                    "color": random.choice([_TF_GOLD_SPARK, _TF_PINK_SOFT, _TF_CREAM,
                                            _TF_WHITE_GLOW, _TF_MINT]),
                    "size": random.uniform(2, 6),
                    "shape": random.choice(["star", "circle", "circle"]),
                })
            # ★ 꽃잎 파티클 (느리게 흩날림)
            if random.random() < 0.15 + p1 * 0.3:
                self.event_particles.append({
                    "x": random.uniform(-40, 40),
                    "y": random.uniform(-20, 20),
                    "vx": random.uniform(-1.5, 1.5),
                    "vy": random.uniform(-1.0, 0.3),
                    "life": random.uniform(1.2, 2.5),
                    "max_life": 2.5,
                    "color": random.choice([_TF_PINK_SOFT, _TF_CORAL, STRAWBERRY_HIGHLIGHT,
                                            _TF_LEAF]),
                    "size": random.uniform(4, 8),
                    "shape": "petal",
                })

        # ── Phase 2 (35~60%): 딸기 소용돌이 — 코랄/핑크 에너지 응집 ──
        elif progress < 0.60:
            p2 = (progress - 0.35) / 0.25
            center_y = base_y + self._tf_levitate_y + _half_h
            self._tf_spin_angle += dt * 12.0

            # 배경: 따스한 핑크 비네트
            dim_surf = pygame.Surface((w, h), pygame.SRCALPHA)
            dim_surf.fill((40, 0, 20, int(50 + 50 * p2)))
            screen.blit(dim_surf, (0, 0))

            # ★ 소용돌이 파티클
            self._update_swirl_particles(dt, cx, center_y, progress)
            for p in self._tf_swirl_particles:
                alpha = max(0, min(255, int(255 * p["life"] / p["max_life"])))
                px = int(cx + math.cos(p["angle"]) * p["dist"])
                py = int(center_y + math.sin(p["angle"]) * p["dist"] * 0.5 + p["y_off"])
                sz = max(2, int(p["size"] * (p["life"] / p["max_life"])))
                if p["is_strawberry"]:
                    _draw_strawberry_sprite(screen, px, py, sz * 1.5, alpha,
                                           tilt=math.degrees(p["angle"]) * 0.3)
                else:
                    # 꼬리 트레일 (소용돌이 방향)
                    trail_a = max(0, alpha // 3)
                    if trail_a > 0 and p["dist"] > 15:
                        tx = int(cx + math.cos(p["angle"] - 0.3) * (p["dist"] + 5))
                        ty = int(center_y + math.sin(p["angle"] - 0.3) * (p["dist"] + 5) * 0.5 + p["y_off"])
                        ts2 = max(1, sz - 1)
                        tsurf = pygame.Surface((ts2 * 2, ts2 * 2), pygame.SRCALPHA)
                        pygame.draw.circle(tsurf, (*p["color"], trail_a), (ts2, ts2), ts2)
                        screen.blit(tsurf, (tx - ts2, ty - ts2))
                    ps = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
                    pygame.draw.circle(ps, (*p["color"], alpha), (sz, sz), sz)
                    screen.blit(ps, (px - sz, py - sz))

            # ★ 다중 에너지 링 (펄싱, 코랄~핑크 그라데이션)
            self._tf_energy_radius = 15 + p2 * 55
            energy_r = int(self._tf_energy_radius)
            pulse = 0.5 + 0.5 * math.sin(t_ms * 0.012)
            for layer in range(5, 0, -1):
                r = energy_r + layer * 10
                a = max(3, int(35 * pulse / layer * (0.4 + p2 * 0.6)))
                glow = pygame.Surface((r * 2, r * 2), pygame.SRCALPHA)
                # 바깥 → 안쪽: 핑크 → 코랄 → 크림
                lr = min(255, 255)
                lg = min(255, 120 + layer * 25)
                lb = min(255, 140 + layer * 20)
                pygame.draw.circle(glow, (lr, lg, lb, a), (r, r), r)
                screen.blit(glow, (int(cx) - r, int(center_y) - r))

            # ★ 회전하는 에너지 링 테두리 (마법진 느낌)
            ring_a = int(80 + 60 * pulse)
            ring_r = energy_r + 5
            ring_surf = pygame.Surface((ring_r * 2 + 4, ring_r * 2 + 4), pygame.SRCALPHA)
            pygame.draw.circle(ring_surf, (*_TF_PINK_HOT, ring_a),
                               (ring_r + 2, ring_r + 2), ring_r, 2)
            # 링 위에 작은 장식 점 (회전)
            for dot_i in range(6):
                dot_angle = self._tf_spin_angle * 0.5 + dot_i * math.pi / 3
                dx = int(ring_r + 2 + math.cos(dot_angle) * ring_r)
                dy = int(ring_r + 2 + math.sin(dot_angle) * ring_r)
                pygame.draw.circle(ring_surf, (*_TF_GOLD_SPARK, min(255, ring_a + 40)),
                                   (dx, dy), 3)
            screen.blit(ring_surf, (int(cx) - ring_r - 2, int(center_y) - ring_r - 2))

            # ★ 코어: 부드러운 크림~핑크 중심
            core_a = int(100 + 120 * p2)
            core_s = pygame.Surface((energy_r * 2, energy_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(core_s, (*_TF_CORAL, core_a), (energy_r, energy_r), energy_r)
            inner_r = max(4, energy_r // 2)
            pygame.draw.circle(core_s, (*_TF_CREAM, min(255, core_a + 30)),
                               (energy_r, energy_r), inner_r)
            screen.blit(core_s, (int(cx) - energy_r, int(center_y) - energy_r))

            # ★ 씨앗 파티클 (중심 주위 궤도)
            for seed_i in range(4):
                sa = self._tf_spin_angle * 1.5 + seed_i * math.pi * 0.5
                sr = energy_r * 0.6
                sx = int(cx + math.cos(sa) * sr)
                sy = int(center_y + math.sin(sa) * sr * 0.5)
                seed_alpha = int(180 * (0.6 + 0.4 * math.sin(t_ms * 0.01 + seed_i)))
                seed_s = pygame.Surface((8, 6), pygame.SRCALPHA)
                pygame.draw.ellipse(seed_s, (*SEED_COLOR, seed_alpha), (0, 0, 8, 6))
                screen.blit(seed_s, (sx - 4, sy - 3))

            # 패들 (에너지에 가려지며 페이드아웃)
            sil_alpha = max(0, int(200 * (1.0 - p2)))
            if sil_alpha > 0:
                self._draw_paddle_spinning(screen, cx, center_y, self._tf_spin_angle, sil_alpha)

        # ── Phase 3 (60~75%): 상큼 폭발 — 핑크 플래시 + 씨앗/꽃잎 산란 ──
        elif progress < 0.75:
            p3 = (progress - 0.60) / 0.15
            center_y = base_y + self._tf_levitate_y + _half_h

            # ★ 에너지 터짐 (부드러운 확장)
            explode_r = int(self._tf_energy_radius + p3 * 180)
            for layer in range(4, 0, -1):
                r = explode_r + layer * 15
                a = max(3, int(60 * (1.0 - p3) / layer))
                glow = pygame.Surface((r * 2, r * 2), pygame.SRCALPHA)
                lr = 255
                lg = min(255, 160 + layer * 20)
                lb = min(255, 170 + layer * 15)
                pygame.draw.circle(glow, (lr, lg, lb, a), (r, r), r)
                screen.blit(glow, (int(cx) - r, int(center_y) - r))

            # ★ 충격파 링 (동심원, 확장)
            for ring_i in range(3):
                ring_delay = ring_i * 0.15
                ring_p = max(0.0, p3 - ring_delay) / (1.0 - ring_delay) if p3 > ring_delay else 0.0
                if ring_p > 0:
                    rr = int(20 + ring_p * (120 + ring_i * 50))
                    ra = max(0, int(160 * (1.0 - ring_p)))
                    if ra > 0:
                        rs = pygame.Surface((rr * 2 + 4, rr * 2 + 4), pygame.SRCALPHA)
                        c = _TF_PINK_HOT if ring_i == 0 else (_TF_CORAL if ring_i == 1 else _TF_PINK_SOFT)
                        pygame.draw.circle(rs, (*c, ra), (rr + 2, rr + 2), rr, max(2, 4 - ring_i))
                        screen.blit(rs, (int(cx) - rr - 2, int(center_y) - rr - 2))

            # ★ 화면 플래시 (화이트 → 핑크, 부드럽게)
            flash_i = 1.0 - p3
            if flash_i > 0:
                flash_surf = pygame.Surface((w, h), pygame.SRCALPHA)
                fa = int(220 * flash_i ** 0.6)
                if p3 < 0.25:
                    flash_surf.fill((255, 250, 245, fa))
                else:
                    flash_surf.fill((255, 190, 200, int(fa * 0.6)))
                screen.blit(flash_surf, (0, 0))

            # ★ 폭발 파티클 — 씨앗, 꽃잎, 별빛, 딸기가 사방으로
            if not self._tf_flash_triggered:
                self._tf_flash_triggered = True
                for _ in range(50):
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(3, 12)
                    self.event_particles.append({
                        "x": 0, "y": self._tf_levitate_y + _half_h,
                        "vx": math.cos(angle) * speed,
                        "vy": math.sin(angle) * speed,
                        "life": random.uniform(1.0, 3.0),
                        "max_life": 3.0,
                        "color": random.choice([
                            _TF_PINK_SOFT, _TF_CORAL, _TF_CREAM, _TF_GOLD_SPARK,
                            STRAWBERRY_RED, STRAWBERRY_HIGHLIGHT, _TF_MINT,
                        ]),
                        "size": random.uniform(4, 10),
                        "shape": random.choice(["circle", "star", "petal", "petal",
                                                 "seed", "strawberry"]),
                    })
                # 잎사귀 전용 (더 크고 느리게)
                for _ in range(12):
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(1.5, 5)
                    self.event_particles.append({
                        "x": 0, "y": self._tf_levitate_y + _half_h,
                        "vx": math.cos(angle) * speed,
                        "vy": math.sin(angle) * speed - 1,
                        "life": random.uniform(1.5, 3.5),
                        "max_life": 3.5,
                        "color": random.choice([_TF_LEAF, GREEN_MID, GREEN_BRIGHT]),
                        "size": random.uniform(5, 9),
                        "shape": "leaf",
                    })

            # ★ 방사형 빛줄기 (부드러운 핑크/크림)
            for ray_angle in self._tf_light_rays:
                ray_len = int(100 + 250 * p3)
                ray_a = max(0, int(80 * (1.0 - p3)))
                if ray_a > 0:
                    end_x = cx + math.cos(math.radians(ray_angle)) * ray_len
                    end_y = center_y + math.sin(math.radians(ray_angle)) * ray_len
                    ray_surf = pygame.Surface((w, h), pygame.SRCALPHA)
                    ray_c = _TF_CREAM if int(ray_angle) % 60 < 30 else _TF_PINK_SOFT
                    pygame.draw.line(ray_surf, (*ray_c, ray_a),
                                    (int(cx), int(center_y)), (int(end_x), int(end_y)),
                                    2 + int(2 * (1.0 - p3)))
                    screen.blit(ray_surf, (0, 0))

        # ── Phase 4 (75~100%): 뿔딸기 등장 — 반짝이며 통통 착지 ──
        else:
            p4 = (progress - 0.75) / 0.25

            # 배경 복원
            dim_fade = max(0, int(50 * (1.0 - p4)))
            if dim_fade > 0:
                dim_surf = pygame.Surface((w, h), pygame.SRCALPHA)
                dim_surf.fill((30, 0, 15, dim_fade))
                screen.blit(dim_surf, (0, 0))

            # ★ 통통 바운스 착지 (2번 튕김)
            if p4 < 0.5:
                ease = (p4 / 0.5) ** 0.5
                descend_y = self._tf_levitate_y * (1.0 - ease)
            elif p4 < 0.65:
                bounce = math.sin((p4 - 0.5) / 0.15 * math.pi) * 12
                descend_y = -bounce
            elif p4 < 0.78:
                bounce2 = math.sin((p4 - 0.65) / 0.13 * math.pi) * 5
                descend_y = -bounce2
            else:
                descend_y = 0.0

            draw_y = base_y + descend_y

            # ★ 캐릭터 후광 — 부드러운 핑크/크림 다중 레이어
            aura_alpha = max(0, int(200 * (1.0 - p4 * 0.7)))
            if aura_alpha > 0:
                for layer in range(4, 0, -1):
                    ar = 35 + layer * 15
                    a = max(3, aura_alpha // layer)
                    aura_s = pygame.Surface((ar * 2, ar * 2), pygame.SRCALPHA)
                    ac = _TF_PINK_SOFT if layer % 2 == 0 else _TF_CREAM
                    pygame.draw.circle(aura_s, (*ac, a), (ar, ar), ar)
                    screen.blit(aura_s, (int(cx) - ar, int(draw_y) - 15 - ar))

            # ★ 반짝이 별 (착지 주변에서 톡톡 튀어나옴)
            if p4 < 0.7 and random.random() < 0.5:
                sp_angle = random.uniform(0, math.pi * 2)
                sp_dist = random.uniform(20, 60)
                self.event_particles.append({
                    "x": math.cos(sp_angle) * sp_dist,
                    "y": math.sin(sp_angle) * sp_dist * 0.3 + (descend_y - self._tf_levitate_y),
                    "vx": random.uniform(-1, 1),
                    "vy": random.uniform(-2, -0.5),
                    "life": random.uniform(0.5, 1.2),
                    "max_life": 1.2,
                    "color": random.choice([_TF_GOLD_SPARK, _TF_PINK_SOFT, _TF_WHITE_GLOW]),
                    "size": random.uniform(3, 6),
                    "shape": "star",
                })

            # ★ 부드러운 빛줄기 (점점 페이드)
            ray_alpha = max(0, int(70 * (1.0 - p4)))
            if ray_alpha > 0:
                for ray_angle in self._tf_light_rays:
                    ray_len = int(60 + 100 * (1.0 - p4))
                    end_x = cx + math.cos(math.radians(ray_angle)) * ray_len
                    end_y = draw_y - 15 + math.sin(math.radians(ray_angle)) * ray_len
                    ray_surf = pygame.Surface((w, h), pygame.SRCALPHA)
                    pygame.draw.line(ray_surf, (*_TF_CREAM, ray_alpha),
                                    (int(cx), int(draw_y) - 15), (int(end_x), int(end_y)), 2)
                    screen.blit(ray_surf, (0, 0))

            # ★ 뿔딸기 캐릭터 등장 (실제 draw_strawberry_paddle)
            try:
                pw = 80 if not hasattr(self, '_last_paddle_w') else self._last_paddle_w
                ph = 20 if not hasattr(self, '_last_paddle_h') else self._last_paddle_h
                char_alpha = min(255, int(255 * min(1.0, p4 / 0.25)))

                _saved_state = self.state
                self.state = self.TRANSFORMED
                buf_w = max(pw + 80, 200)
                buf_h = max(ph + 100, 160)
                temp_surf = pygame.Surface((buf_w, buf_h), pygame.SRCALPHA)
                self.draw_strawberry_paddle(
                    temp_surf,
                    buf_w // 2 - pw // 2,
                    buf_h - ph - 10,
                    pw, ph
                )
                self.state = _saved_state

                if char_alpha < 255:
                    temp_surf.set_alpha(char_alpha)
                screen.blit(temp_surf,
                            (int(cx) - buf_w // 2, int(draw_y) - buf_h + ph + 10))
            except Exception:
                pass

            # ★ "뿔딸기변신!" 텍스트 (통통 바운스 등장)
            if p4 > 0.35:
                text_p = (p4 - 0.35) / 0.65
                # 바운스 스케일
                if text_p < 0.3:
                    t_scale = (text_p / 0.3) * 1.2
                elif text_p < 0.5:
                    t_scale = 1.2 - 0.2 * ((text_p - 0.3) / 0.2)
                else:
                    t_scale = 1.0
                font_size = max(16, int(48 * t_scale))
                text_alpha = min(255, int(255 * min(1.0, text_p / 0.2)))
                try:
                    font = pygame.font.SysFont("malgungothic", font_size)
                    # 외곽선 효과 (흰색 테두리 + 핑크 본문)
                    text_y = int(draw_y) - 80
                    for ox, oy in [(-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, 1)]:
                        outline = font.render("뿔딸기변신!", True, (255, 255, 255))
                        if text_alpha < 255:
                            outline.set_alpha(text_alpha)
                        screen.blit(outline, outline.get_rect(center=(w // 2 + ox, text_y + oy)))
                    text_surf = font.render("뿔딸기변신!", True, _TF_PINK_HOT)
                    if text_alpha < 255:
                        text_surf.set_alpha(text_alpha)
                    screen.blit(text_surf, text_surf.get_rect(center=(w // 2, text_y)))
                except Exception:
                    pass

            # ★ 착지 충격파 — 핑크 동심원 2중 링
            if 0.45 < p4 < 0.85:
                wave_p = (p4 - 0.45) / 0.40
                for wi in range(2):
                    wp = max(0.0, wave_p - wi * 0.12) / (1.0 - wi * 0.12) if wave_p > wi * 0.12 else 0.0
                    if wp > 0:
                        wr = int(15 + wp * (90 + wi * 40))
                        wa = max(0, int((100 - wi * 30) * (1.0 - wp)))
                        ws = pygame.Surface((wr * 2, 24), pygame.SRCALPHA)
                        wc = _TF_PINK_SOFT if wi == 0 else _TF_CORAL
                        pygame.draw.ellipse(ws, (*wc, wa), (0, 4, wr * 2, 16))
                        screen.blit(ws, (int(cx) - wr, int(base_y) + 3))

            # ★ 착지 시 꽃잎 파바박 (바닥 도달 순간)
            if 0.48 < p4 < 0.55:
                for _ in range(8):
                    angle = random.uniform(-math.pi, 0)  # 위쪽으로만
                    speed = random.uniform(2, 6)
                    self.event_particles.append({
                        "x": random.uniform(-15, 15),
                        "y": 0,
                        "vx": math.cos(angle) * speed,
                        "vy": math.sin(angle) * speed,
                        "life": random.uniform(0.6, 1.5),
                        "max_life": 1.5,
                        "color": random.choice([_TF_PINK_SOFT, _TF_LEAF, _TF_CORAL,
                                                STRAWBERRY_HIGHLIGHT]),
                        "size": random.uniform(3, 7),
                        "shape": random.choice(["petal", "leaf"]),
                    })

        # ── 공통: 파티클 렌더 (모양별 분기) ──
        anchor_y = base_y + self._tf_levitate_y + _half_h
        for p in self.event_particles:
            alpha = max(0, min(255, int(255 * p["life"] / p["max_life"])))
            px = int(cx + p["x"])
            py = int(anchor_y + p["y"])
            sz = max(1, int(p["size"] * (p["life"] / p["max_life"])))
            shape = p.get("shape", "circle")

            if shape == "star" and sz >= 2:
                # ★ 4각 별 모양
                star_s = pygame.Surface((sz * 3, sz * 3), pygame.SRCALPHA)
                sc = sz * 3 // 2
                pts = []
                for si in range(8):
                    a2 = si * math.pi / 4 + (p["life"] * 2)
                    r2 = sz if si % 2 == 0 else sz * 0.4
                    pts.append((int(sc + math.cos(a2) * r2), int(sc + math.sin(a2) * r2)))
                pygame.draw.polygon(star_s, (*p["color"], alpha), pts)
                screen.blit(star_s, (px - sc, py - sc))
            elif shape == "petal" and sz >= 2:
                # 꽃잎 모양 (타원 + 회전)
                pw2 = max(3, sz)
                ph2 = max(2, sz // 2)
                pet_s = pygame.Surface((pw2 * 2 + 2, ph2 * 2 + 2), pygame.SRCALPHA)
                pygame.draw.ellipse(pet_s, (*p["color"], alpha), (1, 1, pw2 * 2, ph2 * 2))
                rot_angle = p["life"] * 120
                pet_r = pygame.transform.rotate(pet_s, rot_angle)
                pr = pet_r.get_rect(center=(px, py))
                screen.blit(pet_r, pr)
            elif shape == "leaf" and sz >= 2:
                # 잎 모양 (녹색 타원 + 중앙선)
                lw = max(4, sz + 2)
                lh = max(2, sz // 2)
                leaf_s = pygame.Surface((lw * 2 + 2, lh * 2 + 2), pygame.SRCALPHA)
                pygame.draw.ellipse(leaf_s, (*p["color"], alpha), (1, 1, lw * 2, lh * 2))
                pygame.draw.line(leaf_s, (*GREEN_DARK, max(0, alpha - 40)),
                                 (1, lh + 1), (lw * 2, lh + 1), 1)
                rot_a = p["life"] * 90 + hash(id(p)) % 60
                leaf_r = pygame.transform.rotate(leaf_s, rot_a)
                lr = leaf_r.get_rect(center=(px, py))
                screen.blit(leaf_r, lr)
            elif shape == "seed":
                # 씨앗 (작은 타원)
                seed_s = pygame.Surface((6, 4), pygame.SRCALPHA)
                pygame.draw.ellipse(seed_s, (*SEED_COLOR, alpha), (0, 0, 6, 4))
                screen.blit(seed_s, (px - 3, py - 2))
            elif shape == "strawberry" and sz >= 4:
                # 미니 딸기 스프라이트
                _draw_strawberry_sprite(screen, px, py, sz, alpha,
                                        tilt=p["life"] * 60)
            else:
                # 기본 원형 + 글로우
                if sz >= 3:
                    gs = pygame.Surface((sz * 3, sz * 3), pygame.SRCALPHA)
                    ga = max(0, alpha // 4)
                    pygame.draw.circle(gs, (*p["color"], ga), (sz * 3 // 2, sz * 3 // 2), sz * 3 // 2)
                    screen.blit(gs, (px - sz * 3 // 2, py - sz * 3 // 2))
                ps = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
                pygame.draw.circle(ps, (*p["color"], alpha), (sz, sz), sz)
                screen.blit(ps, (px - sz, py - sz))

    def _draw_mini_strawberry_char(self, surf, cx, cy, pw, ph):
        """변신 연출용 간이 뿔딸기 캐릭터 (등장 시)"""
        r = max(16, int(pw * 0.25))

        # 그림자
        shadow_w = int(r * 1.8)
        pygame.draw.ellipse(surf, (0, 0, 0, 40),
                            (cx - shadow_w, cy + r - 3, shadow_w * 2, 8))

        # 몸통 (딸기 빨강)
        pygame.draw.circle(surf, STRAWBERRY_RED, (cx, cy - r // 3), r)
        # 하이라이트
        pygame.draw.circle(surf, STRAWBERRY_LIGHT, (cx - r // 4, cy - r // 2), r // 3)
        pygame.draw.circle(surf, STRAWBERRY_HIGHLIGHT, (cx - r // 4, cy - r // 2 - 2), r // 5)

        # 씨앗
        for sx, sy in [(-0.3, 0.0), (0.2, -0.1), (0.0, 0.25), (-0.25, 0.25), (0.3, 0.2)]:
            pygame.draw.circle(surf, SEED_COLOR,
                               (int(cx + sx * r), int(cy - r // 3 + sy * r)), 2)

        # 눈 (뒷모습이므로 없음, 대신 뿔)
        # 뿔 (초록 줄기)
        horn_base_y = cy - r // 3 - r
        pygame.draw.line(surf, GREEN_DARK, (cx - 4, horn_base_y + 4), (cx - 8, horn_base_y - 12), 3)
        pygame.draw.line(surf, GREEN_DARK, (cx + 4, horn_base_y + 4), (cx + 8, horn_base_y - 12), 3)
        # 잎
        pygame.draw.circle(surf, GREEN_MID, (cx - 10, horn_base_y - 14), 4)
        pygame.draw.circle(surf, GREEN_MID, (cx + 10, horn_base_y - 14), 4)
        pygame.draw.circle(surf, GREEN_BRIGHT, (cx - 10, horn_base_y - 15), 2)
        pygame.draw.circle(surf, GREEN_BRIGHT, (cx + 10, horn_base_y - 15), 2)

    def draw_strawberry_paddle(self, screen, x, y, width, height):
        """변신 상태 패들 - 둥글둥글 아기자기 딸기 캐릭터 (뒷모습)"""
        if not self.is_transformed:
            return

        t = pygame.time.get_ticks()
        cx = x + width // 2
        eat_skill = getattr(self, "strawberry_eat", None)
        is_eating = bool(getattr(eat_skill, "eating", False))
        field_skill = getattr(self, "strawberry_field", None)
        is_holding_field = bool(getattr(field_skill, "holding", False))
        bomb_skill = getattr(self, "strawberry_bomb", None)
        is_holding_bomb = bool(getattr(bomb_skill, "_ad_hold_timer", 0.0) > 0.05 and not getattr(bomb_skill, "throwing", False))

        # ── 걷기 모션 ──
        prev_x = getattr(self, '_prev_paddle_x', cx)
        move_dir = cx - prev_x
        self._prev_paddle_x = cx
        is_moving = abs(move_dir) > 0.5
        walk_timer = getattr(self, '_walk_timer', 0.0)
        if is_moving:
            walk_timer += 0.15
        self._walk_timer = walk_timer

        if is_eating:
            chew_timer = t * 0.028
            chew_bob = abs(math.sin(chew_timer))
            bounce_y = 2.0 + chew_bob * 5.0
            squash = 0.92 + chew_bob * 0.14
            lean = math.sin(chew_timer * 0.55) * 2.4
            foot_bob = math.sin(chew_timer * 1.8) * 1.6
            leaf_drop = 2 + int(chew_bob * 3.0)
        elif is_holding_field or is_holding_bomb:
            # 딸기장판/딸기폭탄 홀드 중 — 부들부들 떨리는 집중 모션
            shake_t = t * 0.04  # 빠른 떨림
            if is_holding_field:
                _hold_time = getattr(field_skill, "hold_timer", 0.0)
            else:
                _hold_time = getattr(bomb_skill, "_ad_hold_timer", 0.0)
            shake_intensity = min(1.0, _hold_time / 0.5)  # 점점 강해짐
            bounce_y = 1.0 + abs(math.sin(shake_t * 3.0)) * 2.0 * shake_intensity
            squash = 1.0 + math.sin(shake_t * 5.7) * 0.05 * shake_intensity
            lean = math.sin(shake_t * 4.3) * 3.0 * shake_intensity
            foot_bob = math.sin(shake_t * 6.0) * 1.5 * shake_intensity
            leaf_drop = 0
        elif is_moving:
            bounce_y = abs(math.sin(walk_timer * 3.5)) * 5
            squash = 1.0 + math.sin(walk_timer * 7.0) * 0.06
            lean = min(6, max(-6, move_dir * 1.2)) if is_moving else 0
            foot_bob = math.sin(walk_timer * 7) * 2.5
            leaf_drop = 0
        else:
            bounce_y = math.sin(t * 0.003) * 1.5
            squash = 1.0 + math.sin(t * 0.004) * 0.02
            lean = 0
            foot_bob = 0
            leaf_drop = 0

        # ── 꼭지 발사 머리 숙임 모션 ──
        head_bob_offset = 0.0
        _hb = getattr(eat_skill, "head_bob_timer", 0.0) if eat_skill else 0.0
        if _hb > 0:
            # 0.4→0: 앞쪽 0.2초 숙임(sin 올라감), 뒤쪽 0.2초 올림(sin 내려감)
            bob_progress = 1.0 - (_hb / 0.4)  # 0→1
            head_bob_offset = math.sin(bob_progress * math.pi) * 14  # 최대 14px 아래로
            # 숙일 때 살짝 찌그러짐
            squash *= (1.0 + math.sin(bob_progress * math.pi) * 0.08)

        # ── 크기 (둥글둥글) ──
        r = max(20, int(width * 0.28))
        body_cx = cx
        # 발바닥이 패들 하단(y+height)에 맞닿도록 — 딸기 중심을 위로
        bh_est = int(r * 2.2)  # 딸기 높이 추정
        body_cy = int(y + height - bh_est // 2 - 8 - bounce_y + (1 if is_eating else 0) + head_bob_offset)

        # ── 서피스 ──
        pad = 30
        sz = r * 2 + pad * 2
        surf = pygame.Surface((sz, sz), pygame.SRCALPHA)
        sc = sz // 2

        # ── 그림자 ──
        sh_w, sh_h = int(r * 1.4), 5
        pygame.draw.ellipse(surf, (0, 0, 0, 40),
                           (sc - sh_w // 2, sc + r + 3, sh_w, sh_h))

        # ── 발 (정교한 아장아장 걷기 모션) ──
        ground_y = sc + r + 2  # 바닥 기준선
        for side in [-1, 1]:
            fx_base = sc + side * int(r * 0.4)
            phase_offset = 0 if side == 1 else math.pi
            step_phase = walk_timer * 3.5 + phase_offset

            if is_moving:
                # 걸음 사이클: 올림(0~π) → 내림(π~2π)
                cycle = math.sin(step_phase)
                lift = max(0, cycle) * 6          # 최대 6px 들어올림
                fwd = math.sin(step_phase) * 3    # 앞뒤로 3px 스윙
                # 발 회전 (들릴 때 앞쪽이 올라감)
                foot_tilt = max(0, cycle) * 12     # 최대 12도 기울기
                # 이동방향 반영: 이동 방향으로 벌어짐
                spread = move_dir * 0.3 * side
                # 찍는 순간 찌그러짐 (내려올 때)
                land_squash = max(0, -math.sin(step_phase + 0.3)) * 0.15
            elif is_eating:
                lift = abs(math.sin(t * 0.014 + phase_offset)) * 2
                fwd = 0
                foot_tilt = 0
                spread = 0
                land_squash = 0
            else:
                # 정지 시 살짝 좌우 흔들림
                lift = 0
                fwd = 0
                foot_tilt = 0
                spread = math.sin(t * 0.002 + phase_offset) * 0.3
                land_squash = 0

            fx_draw = fx_base + fwd + spread
            fy_draw = ground_y - lift

            # 발 크기 (찌그러짐 반영)
            fw = int(10 + land_squash * 6)   # 착지 시 살짝 넓어짐
            fh = int(7 - land_squash * 3)    # 착지 시 살짝 납작해짐

            # 발 서피스 (회전 가능)
            foot_surf = pygame.Surface((fw + 4, fh + 4), pygame.SRCALPHA)
            fc = (fw // 2 + 2, fh // 2 + 2)
            # 발 본체
            pygame.draw.ellipse(foot_surf, (210, 45, 55), (2, 2, fw, fh))
            # 하이라이트
            pygame.draw.ellipse(foot_surf, (250, 115, 125), (4, 3, max(2, fw - 4), max(2, fh - 3)))
            # 외곽
            pygame.draw.ellipse(foot_surf, (170, 25, 35), (2, 2, fw, fh), 1)

            # 회전 적용 (들릴 때 기울어짐)
            if abs(foot_tilt) > 0.5:
                foot_surf = pygame.transform.rotozoom(foot_surf, foot_tilt * side, 1.0)

            # 그림자 (들린 높이에 비례하여 작아짐)
            shadow_alpha = max(10, int(40 - lift * 4))
            shadow_w = max(4, int(fw * (1.0 - lift * 0.06)))
            pygame.draw.ellipse(surf, (0, 0, 0, shadow_alpha),
                               (int(fx_draw) - shadow_w // 2, ground_y, shadow_w, 3))

            # 발 그리기
            foot_rect = foot_surf.get_rect(center=(int(fx_draw), int(fy_draw)))
            surf.blit(foot_surf, foot_rect)

        # ── 딸기 몸통 (딸기형 — 폴리곤으로 위 넓고 아래 좁은 매끈한 곡선) ──
        bw = int(r * 2 * (2.0 - squash))
        bh = int(r * 2.2 * squash)
        if is_eating:
            bw = int(bw * 1.06)
            bh = int(bh * 0.96)
        top_y = sc - bh // 2

        # 딸기 실루엣을 폴리곤 점들로 구성 (위 넓고 아래 좁은 곡선)
        num_pts = 24
        body_pts = []
        for i in range(num_pts):
            angle = 2 * math.pi * i / num_pts - math.pi / 2  # 상단부터 시계방향
            # Y 위치에 따라 폭 조절: 위(넓음) → 아래(좁음)
            norm_y = math.sin(angle)  # -1(위) ~ 1(아래)
            # 딸기 폭 함수: 위쪽 1.0, 중간 1.05(가장 넓음), 아래쪽 0.5
            if norm_y < 0:
                w_scale = 1.0 + abs(norm_y) * 0.05  # 위→중간: 약간 볼록
            else:
                w_scale = 1.0 - norm_y * 0.45  # 중간→아래: 점점 좁아짐
            px = sc + math.cos(angle) * bw // 2 * w_scale
            py = sc + math.sin(angle) * bh // 2
            body_pts.append((int(px), int(py)))

        pygame.draw.polygon(surf, STRAWBERRY_RED, body_pts)

        # 그라데이션 (아래쪽 살짝 어두움)
        _grad_surf = pygame.Surface((bw, bh), pygame.SRCALPHA)
        for gy in range(bh):
            dark = int(30 * (gy / bh))
            pygame.draw.line(_grad_surf, (0, 0, 0, dark),
                            (0, gy), (bw, gy))
        # 딸기 형태로 클리핑 (폴리곤 마스크)
        _mask_surf = pygame.Surface((sz, sz), pygame.SRCALPHA)
        pygame.draw.polygon(_mask_surf, (255, 255, 255, 255), body_pts)
        _grad_full = pygame.Surface((sz, sz), pygame.SRCALPHA)
        _grad_full.blit(_grad_surf, (sc - bw // 2, top_y))
        _grad_full.blit(_mask_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
        surf.blit(_grad_full, (0, 0))

        # 광택 (좌상단 부드러운 하이라이트 + 반짝)
        _hi_surf = pygame.Surface((sz, sz), pygame.SRCALPHA)
        _hi_cx = sc - int(bw * 0.15)
        _hi_cy = sc - int(bh * 0.2)
        _hi_r1 = max(3, r // 3)
        pygame.draw.circle(_hi_surf, (*STRAWBERRY_LIGHT, 70), (_hi_cx, _hi_cy), _hi_r1)
        pygame.draw.circle(_hi_surf, (255, 220, 225, 50), (_hi_cx, _hi_cy), _hi_r1 + 2)
        # 작은 반짝 점 2개
        pygame.draw.circle(_hi_surf, (255, 255, 255, 180),
                          (_hi_cx - 2, _hi_cy - 2), max(1, _hi_r1 // 4))
        pygame.draw.circle(_hi_surf, (255, 255, 255, 120),
                          (_hi_cx + 3, _hi_cy + 1), 1)
        surf.blit(_hi_surf, (0, 0))

        # 외곽선 (살짝 두껍게)
        pygame.draw.polygon(surf, STRAWBERRY_DARK, body_pts, 2)

        # ── 씨앗 (물방울형, 가지런히 배치) ──
        seed_rng = random.Random(77)
        # 3줄로 가지런하게 배치
        seed_rows = [(-0.25, 5), (0.05, 6), (0.35, 4)]
        for row_y_norm, count in seed_rows:
            if row_y_norm < 0:
                ws = 1.0 + abs(row_y_norm) * 0.05
            else:
                ws = 1.0 - row_y_norm * 0.45
            row_w = bw // 2 * ws * 0.7
            for j in range(count):
                frac = (j + 0.5) / count
                sx = int(sc - row_w + frac * row_w * 2)
                sy = int(sc + row_y_norm * bh // 2)
                # 약간 랜덤 오프셋
                sx += seed_rng.randint(-1, 1)
                sy += seed_rng.randint(-1, 1)
                # 씨앗 홈 (타원형 움푹)
                pygame.draw.ellipse(surf, (150, 12, 22), (sx - 2, sy - 1, 5, 4))
                # 씨앗 알맹이 (황금색)
                pygame.draw.ellipse(surf, (220, 185, 60), (sx - 1, sy, 4, 3))
                # 하이라이트 점
                pygame.draw.rect(surf, (245, 220, 90), (sx, sy, 2, 1))

        # ── 잎사귀 (상단 — 좌우 작은 장식 잎만, 중앙 잎 없음) ──
        leaf_y = sc - bh // 2 + 2 + leaf_drop
        sway = math.sin(t * 0.004) * 2.5

        # 뒤쪽 작은 잎 2장 (먼저 그려서 뒤에 깔림)
        for s in [-1, 1]:
            bx = sc + s * int(r * 0.25)
            pygame.draw.polygon(surf, (45, 130, 32), [
                (bx - 2 * s, leaf_y + 5), (bx + 4 * s, leaf_y + 5),
                (bx + s * 7 + sway * 0.3, leaf_y - 3)])

        # 좌우 잎 (옆으로 넓게 펼침 — 뿔 밑동 장식)
        for s in [-1, 1]:
            lx = sc + s * int(r * 0.35)
            tip_x = lx + s * 14 + sway * 0.7
            # 잎 본체
            pygame.draw.polygon(surf, (50, 150, 38), [
                (lx - 5 * s, leaf_y + 5), (lx + 7 * s, leaf_y + 5),
                (int(tip_x), leaf_y - 9)])
            # 잎맥
            pygame.draw.line(surf, (75, 185, 50), (lx + s * 2, leaf_y + 4),
                            (int(tip_x - s), leaf_y - 6), 1)
            # 외곽선
            pygame.draw.polygon(surf, (35, 110, 25), [
                (lx - 5 * s, leaf_y + 5), (lx + 7 * s, leaf_y + 5),
                (int(tip_x), leaf_y - 9)], 1)

        # ── 뿔 2개 (고퀄리티 — 두꺼운 베이스에서 뾰족한 끝으로 이어지는 곡선 뿔) ──
        for s in [-1, 1]:
            hw = math.sin(t * 0.005 + s * 0.8) * 2.5
            hbx = sc + s * int(r * 0.45)
            hby = leaf_y + 2
            # 뿔 끝점 (바깥 위로 곡선)
            htx = hbx + s * 12 + hw
            hty = hby - 26

            # --- 뿔 본체 (폴리곤 곡선으로 부드럽게) ---
            horn_pts = []
            horn_hi_pts = []  # 하이라이트용
            num_seg = 10
            for i in range(num_seg + 1):
                t_frac = i / num_seg
                # 베지어 곡선: base → control → tip
                ctrl_x = hbx + s * 3  # 컨트롤 포인트 (안쪽으로 살짝 휘어짐)
                ctrl_y = hby - 14
                # quadratic bezier
                ix = (1 - t_frac) ** 2 * hbx + 2 * (1 - t_frac) * t_frac * ctrl_x + t_frac ** 2 * htx
                iy = (1 - t_frac) ** 2 * hby + 2 * (1 - t_frac) * t_frac * ctrl_y + t_frac ** 2 * hty
                # 뿔 두께 (아래 두꺼움 → 위 뾰족)
                thickness = 5.5 * (1.0 - t_frac * 0.82)
                # 법선 방향 (대략 수직)
                if i < num_seg:
                    nx_frac = (i + 1) / num_seg
                    nx = (1 - nx_frac) ** 2 * hbx + 2 * (1 - nx_frac) * nx_frac * ctrl_x + nx_frac ** 2 * htx
                    ny = (1 - nx_frac) ** 2 * hby + 2 * (1 - nx_frac) * nx_frac * ctrl_y + nx_frac ** 2 * hty
                    dx, dy = nx - ix, ny - iy
                else:
                    dx, dy = htx - ix, hty - iy
                length = max(0.01, math.sqrt(dx * dx + dy * dy))
                perp_x, perp_y = -dy / length, dx / length
                horn_pts.append((int(ix + perp_x * thickness), int(iy + perp_y * thickness)))
                horn_hi_pts.append((int(ix + perp_x * thickness * 0.3), int(iy + perp_y * thickness * 0.3)))
            # 반대쪽 (역순)
            for i in range(num_seg, -1, -1):
                t_frac = i / num_seg
                ctrl_x = hbx + s * 3
                ctrl_y = hby - 14
                ix = (1 - t_frac) ** 2 * hbx + 2 * (1 - t_frac) * t_frac * ctrl_x + t_frac ** 2 * htx
                iy = (1 - t_frac) ** 2 * hby + 2 * (1 - t_frac) * t_frac * ctrl_y + t_frac ** 2 * hty
                thickness = 5.5 * (1.0 - t_frac * 0.82)
                if i < num_seg:
                    nx_frac = (i + 1) / num_seg
                    nx = (1 - nx_frac) ** 2 * hbx + 2 * (1 - nx_frac) * nx_frac * ctrl_x + nx_frac ** 2 * htx
                    ny = (1 - nx_frac) ** 2 * hby + 2 * (1 - nx_frac) * nx_frac * ctrl_y + nx_frac ** 2 * hty
                    dx, dy = nx - ix, ny - iy
                else:
                    dx, dy = htx - ix, hty - iy
                length = max(0.01, math.sqrt(dx * dx + dy * dy))
                perp_x, perp_y = -dy / length, dx / length
                horn_pts.append((int(ix - perp_x * thickness), int(iy - perp_y * thickness)))

            # 뿔 그림자 (약간 오프셋으로 깊이감)
            shadow_pts = [(px + 1, py + 1) for px, py in horn_pts]
            pygame.draw.polygon(surf, (25, 80, 15), shadow_pts)

            # 뿔 본체 (짙은 초록 → 밝은 초록 그라데이션 느낌)
            pygame.draw.polygon(surf, GREEN_MID, horn_pts)

            # 뿔 내부 하이라이트 (중심선 따라 밝은 띠)
            hi_inner = []
            for i in range(num_seg + 1):
                t_frac = i / num_seg
                ctrl_x = hbx + s * 3
                ctrl_y = hby - 14
                ix = (1 - t_frac) ** 2 * hbx + 2 * (1 - t_frac) * t_frac * ctrl_x + t_frac ** 2 * htx
                iy = (1 - t_frac) ** 2 * hby + 2 * (1 - t_frac) * t_frac * ctrl_y + t_frac ** 2 * hty
                thickness = 2.5 * (1.0 - t_frac * 0.9)
                hi_inner.append((int(ix - s * thickness * 0.5), int(iy)))
            for i in range(num_seg, -1, -1):
                t_frac = i / num_seg
                ctrl_x = hbx + s * 3
                ctrl_y = hby - 14
                ix = (1 - t_frac) ** 2 * hbx + 2 * (1 - t_frac) * t_frac * ctrl_x + t_frac ** 2 * htx
                iy = (1 - t_frac) ** 2 * hby + 2 * (1 - t_frac) * t_frac * ctrl_y + t_frac ** 2 * hty
                thickness = 2.5 * (1.0 - t_frac * 0.9)
                hi_inner.append((int(ix - s * thickness * 0.5 + s * thickness), int(iy)))
            if len(hi_inner) >= 3:
                pygame.draw.polygon(surf, GREEN_BRIGHT, hi_inner)

            # 뿔 외곽선
            pygame.draw.polygon(surf, GREEN_DARK, horn_pts, 2)

            # 뿔 끝 광택 (둥글게 빛나는 끝)
            pygame.draw.circle(surf, (120, 235, 100), (int(htx), int(hty)), 4)
            pygame.draw.circle(surf, (170, 250, 145), (int(htx) - 1, int(hty) - 1), 2)
            pygame.draw.circle(surf, (210, 255, 200), (int(htx) - 1, int(hty) - 2), 1)

            # 뿔 세로 줄무늬 (입체감)
            for si in range(1, 4):
                st = si / 4.0
                ctrl_x = hbx + s * 3
                ctrl_y = hby - 14
                sx_s = (1 - st) ** 2 * hbx + 2 * (1 - st) * st * ctrl_x + st ** 2 * htx
                sy_s = (1 - st) ** 2 * hby + 2 * (1 - st) * st * ctrl_y + st ** 2 * hty
                stripe_r = max(1, int(3 * (1.0 - st * 0.7)))
                pygame.draw.circle(surf, (40, 130, 30, 60), (int(sx_s + s * 1), int(sy_s)), stripe_r)

            # 베이스 연결부 (뿔 밑동 두꺼운 링)
            pygame.draw.ellipse(surf, (40, 130, 30),
                               (hbx - 6, hby - 2, 12, 5))
            pygame.draw.ellipse(surf, GREEN_MID,
                               (hbx - 5, hby - 1, 10, 4))
            pygame.draw.ellipse(surf, GREEN_DARK,
                               (hbx - 6, hby - 2, 12, 5), 1)

        # ── 기울기 + 그리기 ──
        if abs(lean) > 0.3:
            surf = pygame.transform.rotozoom(surf, -lean, 1.0)

        # ── 딸기폭탄 투척 중 발레리나 회전 (X축 기준 회전 = 가로 스케일 oscillation) ──
        bomb_skill = getattr(self, "strawberry_bomb", None)
        is_bomb_throwing = bool(getattr(bomb_skill, "throwing", False))
        if is_bomb_throwing:
            spin_speed = 12.0  # 빠른 회전
            spin_phase = t * 0.001 * spin_speed * math.pi * 2
            # cos로 가로 스케일: 1.0 → 0.15(얇게) → -1.0(뒤집힘) → 0.15 → 1.0
            x_scale = math.cos(spin_phase)
            abs_scale = max(0.12, abs(x_scale))  # 최소 12% (완전히 안 사라지게)
            orig_w = surf.get_width()
            orig_h = surf.get_height()
            new_w = max(2, int(orig_w * abs_scale))
            surf = pygame.transform.smoothscale(surf, (new_w, orig_h))
            # x_scale < 0이면 좌우 반전 (뒤쪽 보임)
            if x_scale < 0:
                surf = pygame.transform.flip(surf, True, False)

        rect = surf.get_rect(center=(body_cx, body_cy))
        screen.blit(surf, rect)


class HornChargeSkill:
    """뿔박치기 스킬 (오니마루 뿔박치기 기반 + 딸기잔상 트레일)"""

    PHASE_CHARGING = 0
    PHASE_IMPACT = 1
    PHASE_RETURNING = 2
    PHASE_STUN = 3

    def __init__(self):
        self.active = False
        self.phase = self.PHASE_CHARGING
        self.phase_timer = 0.0
        self.cooldown = 0.0
        self.start_y = 0
        self.target_y = 65  # 보스 패들 하단
        self.current_y_offset = 0
        self.current_x_offset = 0
        self.trail_positions = []  # 딸기 잔상 위치들
        self.knockback_applied = False
        self.impact_particles = []

    def reset(self):
        self.active = False
        self.phase = self.PHASE_CHARGING
        self.phase_timer = 0.0
        self.cooldown = 0.0
        self.current_y_offset = 0
        self.current_x_offset = 0
        self.trail_positions.clear()
        self.knockback_applied = False
        self.impact_particles.clear()

    def can_use(self, current_gauge):
        return not self.active and self.cooldown <= 0 and current_gauge >= HORN_CHARGE_GAUGE_COST

    def activate(self, player_y, consume_gauge_fn):
        if consume_gauge_fn(HORN_CHARGE_GAUGE_COST):
            self.active = True
            self.phase = self.PHASE_CHARGING
            self.phase_timer = HORN_CHARGE_PHASES["CHARGING"]
            self.start_y = player_y
            self.current_y_offset = 0
            self.current_x_offset = 0
            self.trail_positions.clear()
            self.knockback_applied = False
            self.impact_particles.clear()
            return True
        return False

    def update(self, dt, player_x, player_y):
        """스킬 업데이트. 반환: (y_offset, x_offset, apply_knockback, is_stunned)"""
        if not self.active:
            return 0, 0, False, False

        self.phase_timer -= dt
        apply_kb = False
        is_stunned = False

        if self.phase == self.PHASE_CHARGING:
            # 상대방 쪽으로 돌진
            progress = 1.0 - (self.phase_timer / HORN_CHARGE_PHASES["CHARGING"])
            progress = min(1.0, max(0.0, progress))
            # 이징 (ease-in)
            eased = progress * progress
            target_offset = -(player_y - self.target_y)
            self.current_y_offset = target_offset * eased
            # 딸기 잔상 추가
            if len(self.trail_positions) < 20:
                self.trail_positions.append({
                    "x": player_x, "y": player_y + self.current_y_offset,
                    "alpha": 200, "size": 1.0
                })
            if self.phase_timer <= 0:
                self.phase = self.PHASE_IMPACT
                self.phase_timer = HORN_CHARGE_PHASES["IMPACT"]

        elif self.phase == self.PHASE_IMPACT:
            if not self.knockback_applied:
                apply_kb = True
                self.knockback_applied = True
                # 충돌 파티클 생성
                for _ in range(15):
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(2, 6)
                    self.impact_particles.append({
                        "x": 0, "y": 0,
                        "vx": math.cos(angle) * speed,
                        "vy": math.sin(angle) * speed,
                        "life": random.uniform(0.3, 0.8),
                        "color": random.choice([STRAWBERRY_RED, GREEN_MID, SEED_COLOR]),
                        "size": random.uniform(2, 5),
                    })
            if self.phase_timer <= 0:
                self.phase = self.PHASE_RETURNING
                self.phase_timer = HORN_CHARGE_PHASES["RETURNING"]

        elif self.phase == self.PHASE_RETURNING:
            progress = 1.0 - (self.phase_timer / HORN_CHARGE_PHASES["RETURNING"])
            progress = min(1.0, max(0.0, progress))
            eased = 1.0 - (1.0 - progress) * (1.0 - progress)  # ease-out
            target_offset = -(player_y - self.target_y)
            self.current_y_offset = target_offset * (1.0 - eased)
            if self.phase_timer <= 0:
                self.phase = self.PHASE_STUN
                self.phase_timer = HORN_CHARGE_PHASES["STUN"]
                self.current_y_offset = 0

        elif self.phase == self.PHASE_STUN:
            is_stunned = True
            self.current_y_offset = 0
            if self.phase_timer <= 0:
                self.active = False
                self.cooldown = HORN_CHARGE_COOLDOWN
                self.current_y_offset = 0

        # 잔상 페이드아웃
        for trail in self.trail_positions:
            trail["alpha"] = max(0, trail["alpha"] - 8)
            trail["size"] *= 0.97

        # 충돌 파티클 업데이트
        alive = []
        for p in self.impact_particles:
            p["life"] -= dt
            p["x"] += p["vx"]
            p["y"] += p["vy"]
            if p["life"] > 0:
                alive.append(p)
        self.impact_particles = alive

        return self.current_y_offset, self.current_x_offset, apply_kb, is_stunned

    def update_cooldown(self, dt):
        if self.cooldown > 0:
            self.cooldown -= dt

    def draw_trail(self, screen, player_x, player_y):
        """딸기 잔상 트레일 그리기"""
        for trail in self.trail_positions:
            if trail["alpha"] <= 5:
                continue
            sz = max(4, int(20 * trail["size"]))
            s = pygame.Surface((sz, sz), pygame.SRCALPHA)
            alpha = min(255, trail["alpha"])
            pygame.draw.ellipse(s, (*STRAWBERRY_RED, alpha), (0, 0, sz, sz))
            # 작은 뿔
            horn_h = max(2, sz // 4)
            pygame.draw.polygon(s, (*GREEN_MID, alpha),
                              [(sz // 3, 0), (sz // 3 + 2, 0), (sz // 3 + 1, -horn_h)])
            pygame.draw.polygon(s, (*GREEN_MID, alpha),
                              [(sz * 2 // 3, 0), (sz * 2 // 3 + 2, 0), (sz * 2 // 3 + 1, -horn_h)])
            screen.blit(s, (int(trail["x"]) - sz // 2, int(trail["y"]) - sz // 2))

        # 충돌 파티클
        for p in self.impact_particles:
            alpha = max(0, min(255, int(255 * p["life"] / 0.8)))
            px = int(player_x + p["x"])
            py = int(player_y + self.current_y_offset + p["y"])
            sz = max(1, int(p["size"]))
            ps = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
            pygame.draw.circle(ps, (*p["color"], alpha), (sz, sz), sz)
            screen.blit(ps, (px - sz, py - sz))


class StrawberryFieldSkill:
    """딸기장판 스킬 (네크로 뼈장막 기반, 딸기 비주얼)"""

    def __init__(self):
        self.holding = False
        self.hold_timer = 0.0
        self.cooldown = 0.0
        self.gauge_consumed = 0
        self.barriers = []  # 활성 장판 리스트

    def reset(self):
        self.holding = False
        self.hold_timer = 0.0
        self.cooldown = 0.0
        self.gauge_consumed = 0
        self.barriers.clear()

    def can_use(self):
        return not self.holding and self.cooldown <= 0

    def start_hold(self):
        if self.can_use():
            self.holding = True
            self.hold_timer = 0.0
            self.gauge_consumed = 0
            return True
        return False

    def update_hold(self, dt, current_gauge, consume_gauge_fn, player_x, player_y):
        """홀딩 업데이트. 반환: True면 장판 설치 완료"""
        if not self.holding:
            return False

        self.hold_timer += dt
        # 프레임당 게이지 소모 (총 100을 1초에 걸쳐)
        gauge_per_sec = STRAWBERRY_FIELD_GAUGE_COST / STRAWBERRY_FIELD_HOLD_MIN
        consume_amount = gauge_per_sec * dt
        if current_gauge >= consume_amount and self.gauge_consumed < STRAWBERRY_FIELD_GAUGE_COST:
            consume_gauge_fn(consume_amount)
            self.gauge_consumed += consume_amount
        else:
            # 게이지 부족 → 홀드 종료
            self.holding = False
            self.hold_timer = 0.0
            return False

        # 1초 이상 홀드 시 장판 설치
        if self.hold_timer >= STRAWBERRY_FIELD_HOLD_MIN:
            self.holding = False
            self.cooldown = STRAWBERRY_FIELD_COOLDOWN
            # 장판 생성 (플레이어 앞에)
            barrier_x = player_x - STRAWBERRY_FIELD_WIDTH // 2
            barrier_y = player_y - 40  # 패들 앞쪽
            # 기존 장판과 간격 체크
            min_spacing = 110
            for b in self.barriers:
                if abs(b["y"] - barrier_y) < min_spacing and b["alive"]:
                    barrier_y = b["y"] - min_spacing
            self.barriers.append({
                "x": barrier_x, "y": barrier_y,
                "w": STRAWBERRY_FIELD_WIDTH, "h": STRAWBERRY_FIELD_HEIGHT,
                "alive": True, "build_timer": 0.0, "built": False,
                "hp": 1,  # 공 1회 반사 후 파괴
                "death_timer": 0.0, "dying": False,
                "seeds": self._generate_seeds(STRAWBERRY_FIELD_WIDTH, STRAWBERRY_FIELD_HEIGHT),
            })
            return True
        return False

    def release_hold(self):
        """홀드 해제 (S키 뗌 - 1초 미만이면 취소)"""
        if self.holding and self.hold_timer < STRAWBERRY_FIELD_HOLD_MIN:
            self.holding = False
            self.hold_timer = 0.0

    @staticmethod
    def _generate_seeds(w, h):
        """장판 위 씨앗 위치 생성"""
        seeds = []
        rng = random.Random(42)
        for _ in range(w // 8):
            seeds.append((rng.randint(4, w - 4), rng.randint(2, h - 2)))
        return seeds

    def update_cooldown(self, dt):
        if self.cooldown > 0:
            self.cooldown -= dt
        # 장판 업데이트
        alive = []
        for b in self.barriers:
            if b["dying"]:
                b["death_timer"] += dt
                if b["death_timer"] > 0.6:
                    continue  # 파괴 완료
            elif not b["built"]:
                b["build_timer"] += dt
                if b["build_timer"] >= 0.5:
                    b["built"] = True
            alive.append(b)
        self.barriers = alive

    def check_ball_collision(self, ball_rect):
        """공과 장판 충돌 체크. 반환: True면 공 반사 필요"""
        for b in self.barriers:
            if not b["alive"] or not b["built"] or b["dying"]:
                continue
            barrier_rect = pygame.Rect(b["x"], b["y"], b["w"], b["h"])
            if barrier_rect.colliderect(ball_rect):
                b["hp"] -= 1
                if b["hp"] <= 0:
                    b["alive"] = False
                    b["dying"] = True
                    b["death_timer"] = 0.0
                return True
        return False

    def draw_barriers(self, screen):
        """딸기장판 그리기"""
        for b in self.barriers:
            if b["dying"]:
                # 파괴 애니메이션 (딸기 파편 흩어짐)
                progress = b["death_timer"] / 0.6
                alpha = max(0, int(255 * (1.0 - progress)))
                for sx, sy in b["seeds"]:
                    scatter_x = sx + (random.random() - 0.5) * 30 * progress
                    scatter_y = sy + progress * 20
                    s = pygame.Surface((4, 3), pygame.SRCALPHA)
                    pygame.draw.ellipse(s, (*SEED_COLOR, alpha), (0, 0, 4, 3))
                    screen.blit(s, (int(b["x"] + scatter_x), int(b["y"] + scatter_y)))
                continue

            if not b["built"]:
                # 건설 중 (반투명)
                progress = b["build_timer"] / 0.5
                alpha = int(180 * progress)
            else:
                alpha = 220

            # 장판 본체 (딸기 젤리 느낌)
            surf = pygame.Surface((b["w"], b["h"]), pygame.SRCALPHA)
            pygame.draw.rect(surf, (*STRAWBERRY_RED, alpha),
                           (0, 0, b["w"], b["h"]), border_radius=4)
            pygame.draw.rect(surf, (*STRAWBERRY_DARK, alpha),
                           (0, 0, b["w"], b["h"]), 1, border_radius=4)
            # 씨앗
            for sx, sy in b["seeds"]:
                pygame.draw.circle(surf, (*SEED_COLOR, alpha), (sx, sy), 2)
            # 빛 반사
            pygame.draw.rect(surf, (*STRAWBERRY_HIGHLIGHT, alpha // 2),
                           (3, 2, b["w"] - 6, 3), border_radius=2)
            screen.blit(surf, (int(b["x"]), int(b["y"])))


class _HornChargeSkillCore:
    """Wrapper that reuses downtown.hero_skills.HornCharge."""

    def __init__(self):
        self._skill = HeroHornCharge() if HeroHornCharge is not None else None
        if self._skill is not None:
            self._skill.cooldown = HORN_CHARGE_COOLDOWN
        self._game_state = self._create_game_state()
        self._trail_nodes = []
        self._trail_spawn_timer = 0.0
        self._anchor_player_centerx = None

    @staticmethod
    def _create_game_state():
        return {
            "horn_charge_active": False,
            "horn_charge_y_offset": 0.0,
            "horn_charge_x_offset": 0.0,
            "horn_charge_apply_knockback": False,
            "horn_charge_knockback_dir": 0,
            "horn_charge_knockback_vel": 0.0,
            "horn_charge_target_is_top": True,
            "horn_charge_caster_is_top": False,
            "horn_charge_impact_shockwave": None,
            "horn_charge_explosion": None,
            "top_paddle_stunned": False,
            "bottom_paddle_stunned": False,
        }

    @property
    def active(self):
        return bool(self._skill is not None and self._skill.is_active)

    @property
    def cooldown(self):
        if self._skill is None:
            return 0.0
        return max(0.0, self._skill.current_cooldown)

    @property
    def game_state(self):
        return self._game_state

    def get_target_stun_frames(self, fps=60):
        """메인 게임 런타임에서 사용할 대상 스턴 프레임 수."""
        try:
            stun_seconds = float(HORN_CHARGE_PHASES.get("STUN", 1.0))
        except Exception:
            stun_seconds = 1.0
        return max(1, int(round(stun_seconds * fps)))

    def reset(self):
        if self._skill is not None:
            self._skill.reset()
            self._skill.cooldown = HORN_CHARGE_COOLDOWN
        self._game_state = self._create_game_state()
        self._trail_nodes.clear()
        self._trail_spawn_timer = 0.0
        self._anchor_player_centerx = None

    def can_use(self, current_gauge):
        return (
            self._skill is not None
            and self._skill.can_use()
            and current_gauge >= HORN_CHARGE_GAUGE_COST
        )

    def activate(self, player_rect, boss_rect, ball_rect, ball_vel, consume_gauge_fn, play_sound_fn=None):
        if self._skill is None or player_rect is None or boss_rect is None:
            return False
        if not self.can_use(HORN_CHARGE_GAUGE_COST):
            return False
        if not consume_gauge_fn(HORN_CHARGE_GAUGE_COST):
            return False

        self._trail_nodes.clear()
        self._trail_spawn_timer = 0.0
        self._anchor_player_centerx = float(player_rect.centerx)
        caster, target, ball = _build_bottom_skill_context(player_rect, boss_rect, ball_rect, ball_vel)
        self._skill.caster_is_top = False
        self._skill.cooldown = HORN_CHARGE_COOLDOWN
        effect = self._skill.use(caster, target, ball, self._game_state)
        ball.sync_velocity(ball_vel)

        if play_sound_fn is not None and effect.get("sound") == "horncharge":
            try:
                play_sound_fn("sounds/horncharge.wav", 0.65)
            except Exception:
                pass
        return True

    def update_cooldown(self, dt):
        if self._skill is not None and not self._skill.is_active and self._skill.current_cooldown > 0:
            self._skill.current_cooldown = max(0.0, self._skill.current_cooldown - dt)

    def needs_runtime_update(self):
        if self._skill is None:
            return False
        shockwave = self._game_state.get("horn_charge_impact_shockwave")
        return bool(
            self._skill.is_active
            or self._game_state.get("horn_charge_active")
            or self._game_state.get("top_paddle_stunned")
            or self._game_state.get("bottom_paddle_stunned")
            or (shockwave and shockwave.get("active"))
        )

    def is_control_locked(self):
        if self._skill is None or not self._skill.is_active:
            return False
        _phase = getattr(self._skill, "phase", None)
        return _phase in (
            getattr(self._skill, "PHASE_CHARGING", -999),
            getattr(self._skill, "PHASE_IMPACT", -998),
        )

    def update(self, dt, player_rect, boss_rect, ball_rect, ball_vel):
        if self._skill is None or player_rect is None or boss_rect is None:
            return
        caster, target, ball = _build_bottom_skill_context(player_rect, boss_rect, ball_rect, ball_vel)
        self._skill.update(dt, caster, target, ball, self._game_state)
        ball.sync_velocity(ball_vel)
        _stun_phase = getattr(self._skill, "PHASE_STUN", 3)
        if self._skill.is_active and self._skill.phase == _stun_phase:
            self._game_state["top_paddle_stunned"] = False
            self._game_state["bottom_paddle_stunned"] = False
            self._game_state["horn_charge_active"] = False
            self._game_state["horn_charge_x_offset"] = 0.0
            self._game_state["horn_charge_y_offset"] = 0.0
            # 딸기뿔박치기는 복귀가 끝나는 즉시 이동권을 돌려줘야 한다.
            # STUN 페이즈에서 centerx를 앵커로 다시 덮어쓰면
            # 사용자가 잠깐 움직였다가 다음 프레임에 제자리로 끌려오는 버그가 난다.
            self._anchor_player_centerx = None
            self._skill.phase_timer = 1.0
        # 딸기뿔박치기: 플레이어 STUN 페이즈를 0.5초로 단축 (원본 1.0초)
        if self._skill.is_active and self._skill.phase == 3:  # PHASE_STUN
            if self._skill.phase_timer >= 0.5:
                # 0.5초에 강제 종료 — phase_timer를 1.0으로 밀어서 원본 종료 로직 트리거
                self._skill.phase_timer = 1.0
        self._update_trail(dt, player_rect)

    def get_draw_offsets(self):
        if not self._game_state.get("horn_charge_active"):
            return 0.0, 0.0
        return (
            float(self._game_state.get("horn_charge_x_offset", 0.0)),
            float(self._game_state.get("horn_charge_y_offset", 0.0)),
        )

    def get_anchor_centerx(self):
        return self._anchor_player_centerx

    def _update_trail(self, dt, player_rect):
        _phase = getattr(self._skill, "phase", None)
        _charging_phase = getattr(self._skill, "PHASE_CHARGING", -999)
        _returning_phase = getattr(self._skill, "PHASE_RETURNING", -998)

        if self._game_state.get("horn_charge_active") and _phase == _charging_phase:
            self._trail_spawn_timer += dt
            _trail_interval = 0.028
            _x_offset, _y_offset = self.get_draw_offsets()
            _center_x = float(player_rect.centerx) + _x_offset
            _center_y = float(player_rect.centery) + _y_offset

            while self._trail_spawn_timer >= _trail_interval:
                self._trail_spawn_timer -= _trail_interval
                self._trail_nodes.append({
                    "x": _center_x,
                    "y": _center_y,
                    "life": 0.38,
                    "max_life": 0.38,
                    "size": random.uniform(0.8, 1.25),
                    "tilt": random.uniform(-24, 24),
                    "scatter": random.uniform(5, 11),
                })
            self._trail_nodes = self._trail_nodes[-16:]
        elif not self._game_state.get("horn_charge_active") or _phase == _returning_phase:
            self._trail_spawn_timer = 0.0

        alive = []
        for node in self._trail_nodes:
            node["life"] -= dt
            node["y"] += 8.0 * dt
            if node["life"] > 0:
                alive.append(node)
        self._trail_nodes = alive

    def draw_trail(self, screen):
        for idx, node in enumerate(self._trail_nodes):
            life_ratio = max(0.0, min(1.0, node["life"] / node["max_life"]))
            alpha = int(210 * life_ratio)
            berry_size = 11 + int(9 * node["size"] * life_ratio)
            scatter = node["scatter"]
            wobble = math.sin((pygame.time.get_ticks() * 0.01) + idx * 0.7) * 2.2

            _draw_strawberry_sprite(
                screen,
                node["x"] - scatter,
                node["y"] + wobble,
                berry_size,
                alpha=alpha,
                tilt=node["tilt"],
            )
            _draw_strawberry_sprite(
                screen,
                node["x"] + scatter * 0.8,
                node["y"] - wobble * 0.7,
                max(8, int(berry_size * 0.82)),
                alpha=int(alpha * 0.85),
                tilt=-node["tilt"] * 0.75,
            )

            seed_alpha = max(0, min(255, int(alpha * 0.65)))
            if seed_alpha > 0:
                for spark_idx in range(2):
                    spark_x = int(node["x"] + (spark_idx * 2 - 1) * scatter * 0.55)
                    spark_y = int(node["y"] - 6 + spark_idx * 4)
                    pygame.draw.ellipse(screen, (*SEED_COLOR, seed_alpha), (spark_x, spark_y, 4, 2))


class _StrawberryFieldSkillCore:
    """Hold-to-cast wrapper that reuses downtown.hero_skills.BoneBarrier."""

    def __init__(self):
        self.holding = False
        self.hold_timer = 0.0
        self.gauge_consumed = 0.0
        self._skill = HeroBoneBarrier() if HeroBoneBarrier is not None else None
        self._game_state = {}
        if self._skill is not None:
            self._skill.cooldown = STRAWBERRY_FIELD_COOLDOWN

    @property
    def cooldown(self):
        if self._skill is None:
            return 0.0
        return max(0.0, self._skill.current_cooldown)

    @property
    def barriers(self):
        if self._skill is None:
            return []
        return self._skill.barriers

    def reset(self):
        self.holding = False
        self.hold_timer = 0.0
        self.gauge_consumed = 0.0
        self._game_state = {}
        if self._skill is not None:
            self._skill.reset()
            self._skill.cooldown = STRAWBERRY_FIELD_COOLDOWN
            self._skill.barriers = []
            self._skill.dying_barriers = []
            self._skill._next_id = 0

    def can_use(self):
        return (
            self._skill is not None
            and not self.holding
            and self._skill.current_cooldown <= 0
        )

    def start_hold(self):
        if self.can_use():
            self.holding = True
            self.hold_timer = 0.0
            self.gauge_consumed = 0.0
            return True
        return False

    def update_hold(self, dt, current_gauge, consume_gauge_fn, player_rect, boss_rect, ball_rect, ball_vel):
        if not self.holding:
            return False

        self.hold_timer += dt
        gauge_per_sec = STRAWBERRY_FIELD_GAUGE_COST / STRAWBERRY_FIELD_HOLD_MIN
        consume_amount = gauge_per_sec * dt
        remaining_cost = max(0.0, STRAWBERRY_FIELD_GAUGE_COST - self.gauge_consumed)
        consume_amount = min(consume_amount, remaining_cost)
        if current_gauge >= consume_amount and consume_amount > 0:
            consume_gauge_fn(consume_amount)
            self.gauge_consumed += consume_amount
        elif remaining_cost > 0:
            self.holding = False
            self.hold_timer = 0.0
            self.gauge_consumed = 0.0
            return False

        if self.hold_timer >= STRAWBERRY_FIELD_HOLD_MIN and self._skill is not None:
            self.holding = False
            caster, target, ball = _build_bottom_skill_context(player_rect, boss_rect, ball_rect, ball_vel)
            self._skill.cooldown = STRAWBERRY_FIELD_COOLDOWN
            self._skill.use(caster, target, ball, self._game_state)
            self._snap_latest_barrier_to_paddle(player_rect)
            ball.sync_velocity(ball_vel)
            return True
        return False

    def _snap_latest_barrier_to_paddle(self, player_rect):
        if self._skill is None or player_rect is None or not self._skill.barriers:
            return

        barrier = self._skill.barriers[-1]
        width = float(barrier.get("width", getattr(self._skill, "BARRIER_WIDTH", 120)))
        height = float(barrier.get("height", getattr(self._skill, "BARRIER_HEIGHT", 12)))
        min_x = float(getattr(self._skill, "GAME_LEFT", 0))
        max_x = float(getattr(self._skill, "GAME_RIGHT", 760) - width)

        desired_x = float(player_rect.centerx - width / 2.0)
        desired_x = max(min_x, min(max_x, desired_x))
        if barrier.get("is_top", False):
            desired_y = float(player_rect.top - height / 2.0)
        else:
            desired_y = float(player_rect.bottom + height / 2.0)

        dx = desired_x - float(barrier.get("x", desired_x))
        dy = desired_y - float(barrier.get("y", desired_y))

        barrier["x"] = desired_x
        barrier["y"] = desired_y

        for segment in barrier.get("bone_segments", []):
            if "start_x" in segment:
                segment["start_x"] = float(segment["start_x"]) + dx
            if "final_x" in segment:
                segment["final_x"] = float(segment["final_x"]) + dx
            if "start_y" in segment:
                segment["start_y"] = float(segment["start_y"]) + dy
            if "final_y" in segment:
                segment["final_y"] = float(segment["final_y"]) + dy

    def release_hold(self):
        if self.holding and self.hold_timer < STRAWBERRY_FIELD_HOLD_MIN:
            self.holding = False
            self.hold_timer = 0.0
            self.gauge_consumed = 0.0

    def update_cooldown(self, dt):
        if (
            self._skill is not None
            and not self.holding
            and not self._skill.is_active
            and not self._skill.barriers
            and not self._skill.dying_barriers
            and self._skill.current_cooldown > 0
        ):
            self._skill.current_cooldown = max(0.0, self._skill.current_cooldown - dt)

    def needs_runtime_update(self):
        return bool(
            self._skill is not None
            and (
                self._skill.is_active
                or self._skill.barriers
                or self._skill.dying_barriers
            )
        )

    def update(self, dt, player_rect, boss_rect, ball_rect, ball_vel):
        if self._skill is None or player_rect is None or boss_rect is None:
            return
        caster, target, ball = _build_bottom_skill_context(player_rect, boss_rect, ball_rect, ball_vel)
        self._skill.update(dt, caster, target, ball, self._game_state)
        ball.sync_velocity(ball_vel)

    def draw_barriers(self, screen):
        if self._skill is None:
            return
        for barrier in self._skill.barriers:
            self._draw_barrier(screen, barrier)
        for dying in self._skill.dying_barriers:
            self._draw_dying_barrier(screen, dying)

    def _draw_barrier(self, screen, barrier):
        if not barrier.get("alive", False):
            return

        x = int(barrier["x"])
        y = int(barrier["y"])
        w = int(barrier["width"])
        built = bool(barrier.get("built", False))
        is_top = bool(barrier.get("is_top", False))
        build_time = max(0.001, float(getattr(self._skill, "BUILD_TIME", 3.0)))
        build_progress = min(1.0, float(barrier.get("build_timer", 0.0)) / build_time)
        t_now = pygame.time.get_ticks() / 180.0

        berry_row_y = y + 16 if is_top else y - 16
        vine_y = berry_row_y - 12
        glow_alpha = 55 if built else int(45 * build_progress)

        vine_shadow = pygame.Surface((w + 18, 18), pygame.SRCALPHA)
        pygame.draw.line(vine_shadow, (20, 65, 18, max(20, glow_alpha // 2)), (8, 11), (w + 8, 11), 6)
        pygame.draw.line(vine_shadow, (55, 150, 45, max(40, glow_alpha)), (8, 9), (w + 8, 9), 4)
        pygame.draw.line(vine_shadow, (120, 230, 100, max(20, glow_alpha // 2)), (10, 7), (w + 6, 7), 1)
        screen.blit(vine_shadow, (x - 9, vine_y - 9))

        berry_count = max(4, w // 26)
        span = w - 20
        for idx in range(berry_count):
            local_progress = 1.0 if built else max(0.0, min(1.0, build_progress * berry_count - idx + 0.35))
            if local_progress <= 0:
                continue

            cx = x + 10 + (span * idx / max(1, berry_count - 1))
            bob = math.sin(t_now + idx * 0.9) * 1.4
            cy = berry_row_y + bob
            berry_size = max(8, int((17 + (idx % 2) * 2) * local_progress))
            alpha = int((230 if built else 190) * local_progress)

            pygame.draw.line(
                screen,
                (*GREEN_DARK, alpha),
                (int(cx), int(vine_y + 2)),
                (int(cx), int(cy - berry_size * 0.55)),
                2,
            )
            _draw_strawberry_sprite(
                screen,
                cx,
                cy,
                berry_size,
                alpha=alpha,
                tilt=(-10 if idx % 2 == 0 else 10) * (0.6 + 0.4 * local_progress),
            )

        if built:
            for idx in range(berry_count - 1):
                bridge_x = x + 10 + (span * (idx + 0.5) / max(1, berry_count - 1))
                bridge_y = berry_row_y + math.sin(t_now + idx * 0.9 + 0.45) * 1.2
                _draw_strawberry_sprite(
                    screen,
                    bridge_x,
                    bridge_y + (5 if idx % 2 == 0 else -3),
                    11,
                    alpha=205,
                    tilt=18 if idx % 2 == 0 else -18,
                )

    def _draw_dying_barrier(self, screen, dying):
        death_duration = max(0.001, float(getattr(self._skill, "DEATH_DURATION", 0.6)))
        progress = float(dying.get("death_time", 0.0)) / death_duration
        if progress >= 1.0:
            return

        alpha = max(0, int(255 * (1.0 - progress)))
        for idx, frag in enumerate(dying.get("fragments", [])):
            fx = frag["x"] + frag["vx"] * dying["death_time"]
            fy = frag["y"] + frag["vy"] * dying["death_time"] + 120 * dying["death_time"] * dying["death_time"]
            frag_size = max(5, int(frag.get("length", 6) * (0.9 - progress * 0.35)))
            _draw_strawberry_sprite(
                screen,
                fx,
                fy,
                frag_size,
                alpha=int(alpha * 0.78),
                tilt=((idx % 2) * 2 - 1) * (14 + idx % 5 * 5),
            )
            seed_alpha = int(alpha * 0.55)
            if seed_alpha > 0:
                pygame.draw.ellipse(
                    screen,
                    (*SEED_COLOR, seed_alpha),
                    (int(fx - 2), int(fy + frag_size * 0.25), 4, 2),
                )


class StrawberryEatSkill:
    """딸기먹기 스킬 - 딸기를 먹고 꼭지 투척"""

    def __init__(self):
        self.eating = False
        self.eat_timer = 0.0
        self.cooldown = 0.0
        self.gauge_cost = STRAWBERRY_EAT_GAUGE_COST
        self.paddle_growth_bonus = STRAWBERRY_EAT_PADDLE_GROWTH_BONUS
        self.projectiles = []  # 발사된 꼭지 투사체
        self._anchor_player_centerx = None
        self._queued_stem_shots = 0
        self._stem_burst_timer = 0.0
        self._stem_burst_origin_x = 0.0
        self._stem_burst_origin_y = 0.0
        self._sound_channel = None  # pingfighter에서 설정하는 사운드 채널 참조
        self.head_bob_timer = 0.0  # 꼭지 발사 시 머리 숙임 모션 타이머

    def reset(self):
        self.eating = False
        self.eat_timer = 0.0
        self.cooldown = 0.0
        self.projectiles.clear()
        self._anchor_player_centerx = None
        self._queued_stem_shots = 0
        self._stem_burst_timer = 0.0
        self._stem_burst_origin_x = 0.0
        self._stem_burst_origin_y = 0.0
        self.head_bob_timer = 0.0
        # 사운드 정지
        if self._sound_channel is not None:
            try:
                self._sound_channel.stop()
            except Exception:
                pass
            self._sound_channel = None

    def can_use(self):
        return not self.eating and self.cooldown <= 0

    def activate(self):
        if self.can_use():
            self.eating = True
            self.eat_timer = STRAWBERRY_EAT_DURATION
            return True
        return False

    def update(self, dt, player_x, player_y, recover_gauge_fn, recover_dash_fn):
        """딸기먹기 및 후속 3연사 투사체를 업데이트한다."""
        if self.eating:
            self.eat_timer -= dt
            if self.eat_timer <= 0:
                self.eating = False
                self.cooldown = STRAWBERRY_EAT_COOLDOWN
                recover_dash_fn(1)
                self._anchor_player_centerx = None
                self._start_stem_burst(player_x, player_y)
                self.head_bob_timer = 0.4  # 머리 숙임→올림 모션 시작
            return True

        # 머리 숙임 타이머 감소
        if self.head_bob_timer > 0:
            self.head_bob_timer -= dt

        if self._queued_stem_shots > 0:
            self._stem_burst_timer -= dt
            while self._queued_stem_shots > 0 and self._stem_burst_timer <= 0:
                self._fire_stem(self._stem_burst_origin_x, self._stem_burst_origin_y)
                self._queued_stem_shots -= 1
                self._stem_burst_timer += STRAWBERRY_STEM_BURST_INTERVAL

        alive = []
        for p in self.projectiles:
            p["x"] += p["vx"] * dt * 60
            p["y"] += p["vy"] * dt * 60
            p["rotation"] += p["rot_speed"] * dt * 60
            p["life"] -= dt
            if p["life"] > 0 and p["y"] > -20:
                alive.append(p)
        self.projectiles = alive

        return False

    def _start_stem_burst(self, player_x, player_y):
        self._stem_burst_origin_x = float(player_x)
        self._stem_burst_origin_y = float(player_y)
        self._fire_stem(self._stem_burst_origin_x, self._stem_burst_origin_y)
        self._queued_stem_shots = max(0, STRAWBERRY_STEM_BURST_COUNT - 1)
        self._stem_burst_timer = STRAWBERRY_STEM_BURST_INTERVAL

    def _fire_stem(self, player_x, player_y):
        """딸기 꼭지 투사체 발사"""
        # 코만도 권총 속도의 120%
        base_speed = 7  # 권총 기본 속도
        speed = base_speed * STRAWBERRY_STEM_SPEED_MULT
        angle_deg = random.uniform(-STRAWBERRY_STEM_SPREAD_DEGREES, STRAWBERRY_STEM_SPREAD_DEGREES)
        angle_rad = math.radians(angle_deg)
        self.projectiles.append({
            "x": player_x, "y": player_y - 20,
            "speed": speed,
            "vx": math.sin(angle_rad) * speed,
            "vy": -math.cos(angle_rad) * speed,
            "rotation": angle_rad,
            "rot_speed": 5,
            "life": 3.0,
            "damage": 1,
            "stun_duration": 0.75,  # 코만도 권총과 동일한 스턴 (45프레임)
            "knockback": 120,  # 코만도 권총과 동일한 넉백
        })
        self.projectiles[-1]["stun_duration"] = 0.3
        self.projectiles[-1]["knockback"] = STRAWBERRY_STEM_KNOCKBACK

        # 꼭지 발사 사운드
        _load_stem_sounds()
        if _sound_stem_fire and _sound_stem_fire is not False:
            _sound_stem_fire.play()

    def update_cooldown(self, dt):
        if self.cooldown > 0:
            self.cooldown -= dt

    def check_boss_collision(self, boss_rect):
        """보스와 꼭지 투사체 충돌 체크. 반환: hit된 투사체 or None"""
        for p in self.projectiles:
            proj_rect = pygame.Rect(int(p["x"]) - 10, int(p["y"]) - 10, 20, 20)
            if proj_rect.colliderect(boss_rect):
                self.projectiles.remove(p)
                return p
        return None

    def draw(self, screen, player_x, player_y):
        """먹기 모션 + 투사체 그리기"""
        # 먹기 모션 (패들 위에 딸기 아이콘 + 먹기 이펙트)
        if self.eating:
            progress = 1.0 - (self.eat_timer / STRAWBERRY_EAT_DURATION)
            progress = max(0.0, min(1.0, progress))
            self._draw_eating_fragments(screen, player_x, player_y, progress)
            self._draw_eating_strawberry(screen, player_x, player_y, progress)
            for p in self.projectiles:
                self._draw_stem_projectile(screen, p)
            return
            # 딸기 아이콘 (줄어듦)
            size = max(4, int(16 * (1.0 - progress)))
            s = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.ellipse(s, STRAWBERRY_RED, (0, 0, size, size))
            screen.blit(s, (int(player_x) - size // 2, int(player_y) - 25 - size // 2))
            # 먹기 파티클 (빨간 입자)
            if progress > 0.3:
                for _ in range(2):
                    px = player_x + random.randint(-10, 10)
                    py = player_y - 20 + random.randint(-5, 5)
                    ps = pygame.Surface((3, 3), pygame.SRCALPHA)
                    pygame.draw.circle(ps, (*STRAWBERRY_LIGHT, 180), (1, 1), 1)
                    screen.blit(ps, (int(px), int(py)))

        # 꼭지 투사체
        for p in self.projectiles:
            self._draw_stem_projectile(screen, p)

    @staticmethod
    def _draw_eating_strawberry(screen, player_x, player_y, progress):
        t = pygame.time.get_ticks() * 0.001
        chew_wave = math.sin(t * 17.0)
        chew_bob = abs(chew_wave)
        strawberry_x = float(player_x + math.sin(t * 12.0) * 1.4)
        strawberry_y = float(player_y - 28 - chew_bob * 4.0)
        size = max(10, int(16 - progress * 3))

        surf_size = max(52, size * 4)
        surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
        center = surf_size // 2
        _draw_strawberry_sprite(surf, center, center, size, alpha=255, tilt=0.0)

        bite_radius = max(4, int(size * 0.22))
        bite_offsets = (
            (size * 0.36, -size * 0.18),
            (size * 0.34, size * 0.05),
            (size * 0.24, size * 0.30),
        )
        bite_count = min(len(bite_offsets), 1 + int((0.25 + progress * 0.95) * 2.2))
        for bite_x, bite_y in bite_offsets[:bite_count]:
            pygame.draw.circle(
                surf,
                (0, 0, 0, 0),
                (int(center + bite_x), int(center + bite_y)),
                bite_radius,
            )

        if abs(chew_wave) > 0.01:
            surf = pygame.transform.rotozoom(surf, chew_wave * 5.5, 1.0)

        rect = surf.get_rect(center=(int(strawberry_x), int(strawberry_y)))
        screen.blit(surf, rect)

    @staticmethod
    def _draw_eating_fragments(screen, player_x, player_y, progress):
        t = pygame.time.get_ticks() * 0.001
        chew_power = 0.45 + 0.55 * abs(math.sin(t * 17.0))
        spray = pygame.Surface((180, 96), pygame.SRCALPHA)
        origin_x = spray.get_width() // 2
        origin_y = spray.get_height() // 2
        base_alpha = int(140 + chew_power * 80)

        for side in (-1, 1):
            side_phase = 0.35 if side > 0 else 0.0
            for idx in range(4):
                phase = t * 10.5 + idx * 0.78 + side_phase
                chunk_x = origin_x + side * (14 + progress * 10 + idx * 10 + math.sin(phase) * 2.8)
                chunk_y = origin_y - 4 + math.cos(phase * 1.25) * 4.0 - idx * 1.8
                chunk_size = max(6, int(10 - idx + chew_power * 2.0))
                chunk_alpha = max(70, base_alpha - idx * 25)
                _draw_strawberry_sprite(
                    spray,
                    chunk_x,
                    chunk_y,
                    chunk_size,
                    alpha=chunk_alpha,
                    tilt=side * (18 + idx * 10 + math.sin(phase) * 12),
                )

                for seed_idx in range(2 if idx < 2 else 1):
                    seed_x = origin_x + side * (
                        20 + progress * 18 + idx * 12 + seed_idx * 6 + math.cos(phase + seed_idx) * 2.0
                    )
                    seed_y = origin_y + math.sin(phase * 1.8 + seed_idx) * 5.0 - idx * 2.4
                    seed_alpha = max(80, chunk_alpha)
                    juice_alpha = max(60, chunk_alpha - 25)
                    pygame.draw.ellipse(
                        spray,
                        (*SEED_COLOR, seed_alpha),
                        (int(seed_x), int(seed_y), 4, 2),
                    )
                    juice_x = seed_x - side * (4 + seed_idx)
                    juice_y = seed_y + 3 + math.cos(phase * 1.4 + seed_idx) * 1.6
                    pygame.draw.ellipse(
                        spray,
                        (*STRAWBERRY_LIGHT, juice_alpha),
                        (int(juice_x), int(juice_y), 5, 3),
                    )

        rect = spray.get_rect(center=(int(player_x), int(player_y - 24 - chew_power * 2.0)))
        screen.blit(spray, rect)

    @staticmethod
    def _draw_stem_projectile(screen, proj):
        """딸기 꼭지 투사체 그리기 (큰 크기)"""
        x, y = int(proj["x"]), int(proj["y"])
        rot = proj["rotation"]
        # 꼭지 본체 (초록 + 갈색 줄기) — 크게
        sz = 20
        s = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
        center = sz
        # 잎사귀 (3개, 크고 두꺼운)
        for i in range(3):
            angle = rot + i * (math.pi * 2 / 3)
            lx = center + math.cos(angle) * 12
            ly = center + math.sin(angle) * 12
            pts = [
                (center, center),
                (int(lx - 4), int(ly)),
                (int(lx + 4), int(ly)),
            ]
            pygame.draw.polygon(s, GREEN_MID, pts)
            # 잎맥 하이라이트
            pygame.draw.line(s, GREEN_BRIGHT, (center, center), (int(lx), int(ly)), 1)
        # 중앙 (줄기 — 크게)
        pygame.draw.circle(s, GREEN_DARK, (center, center), 6)
        pygame.draw.circle(s, (100, 70, 30), (center, center), 4)
        pygame.draw.circle(s, (130, 90, 40), (center - 1, center - 1), 2)
        screen.blit(s, (x - sz, y - sz))


# ── 딸기폭탄 스킬 ──────────────────────────────────────
class StrawberryBombSkill:
    """딸기폭탄 스킬 - A+D 동시 홀드 0.5초로 발동, 30개 딸기폭탄 투척"""

    def __init__(self):
        self.cooldown = 0.0
        self.active = False  # 투척 중
        self.throwing = False  # 투척 모션 중 (이동 불가)
        self.throw_timer = 0.0  # 투척 남은 시간
        self._throw_interval = 0.0  # 다음 폭탄까지 남은 시간
        self._thrown_count = 0
        self._anchor_player_centerx = None

        # A+D 동시 홀드 감지
        self._ad_hold_timer = 0.0  # A+D 동시 누른 시간
        self._ad_held_prev = False

        # 폭탄 투사체 목록
        self.bombs = []  # 날아가는 폭탄들
        self.explosions = []  # 폭발 이펙트
        self.paint_splatters = []  # 바닥 페인트 (슬로우)

    def reset(self):
        self.cooldown = 0.0
        self.active = False
        self.throwing = False
        self.throw_timer = 0.0
        self._throw_interval = 0.0
        self._thrown_count = 0
        self._anchor_player_centerx = None
        self._ad_hold_timer = 0.0
        self._ad_held_prev = False
        self.bombs.clear()
        self.explosions.clear()
        self.paint_splatters.clear()

    def can_use(self):
        return not self.active and not self.throwing and self.cooldown <= 0

    def update_cooldown(self, dt):
        if self.cooldown > 0:
            self.cooldown -= dt

    def check_ad_hold(self, keys, dt):
        """A+D 동시 홀드 감지. 0.5초 이상이면 True 반환"""
        a_pressed = keys[pygame.K_a]
        d_pressed = keys[pygame.K_d]
        both = a_pressed and d_pressed

        if both:
            self._ad_hold_timer += dt
            if self._ad_hold_timer >= STRAWBERRY_BOMB_HOLD_TIME:
                return True
        else:
            self._ad_hold_timer = 0.0
        return False

    def activate(self, player_centerx):
        """폭탄 투척 시작"""
        if not self.can_use():
            return False
        self.active = True
        self.throwing = True
        self.throw_timer = STRAWBERRY_BOMB_THROW_DURATION
        self._throw_interval = 0.0
        self._thrown_count = 0
        self._anchor_player_centerx = float(player_centerx)
        self._ad_hold_timer = 0.0
        return True

    def update(self, dt, player_x, player_y, screen_width, boss_y=25):
        """매 프레임 업데이트: 투척 + 폭탄 물리 + 폭발 + 페인트"""
        hits = []  # 이번 프레임에 터진 폭탄 정보

        # 1) 투척 중 - 일정 간격으로 폭탄 발사
        if self.throwing:
            self.throw_timer -= dt
            self._throw_interval -= dt

            interval = STRAWBERRY_BOMB_THROW_DURATION / STRAWBERRY_BOMB_COUNT
            while self._throw_interval <= 0 and self._thrown_count < STRAWBERRY_BOMB_COUNT:
                self._spawn_bomb(player_x, player_y, screen_width)
                self._thrown_count += 1
                self._throw_interval += interval

            if self.throw_timer <= 0 or self._thrown_count >= STRAWBERRY_BOMB_COUNT:
                self.throwing = False
                self._anchor_player_centerx = None

        # 2) 폭탄 물리 업데이트
        alive_bombs = []
        for b in self.bombs:
            b["age"] += dt
            # 점프(홉) 궤적
            b["hop_timer"] -= dt
            if b["hop_timer"] <= 0:
                b["hop_timer"] = STRAWBERRY_BOMB_HOP_INTERVAL
                # 궤적 변경: 약간 랜덤한 좌우 + 위쪽 방향 변경
                b["vx"] += random.uniform(-2.0, 2.0)
                b["vy"] = -(STRAWBERRY_BOMB_BASE_SPEED + random.uniform(0, 2.0))
                b["hop_phase"] = 0.0  # 새 홉 시작

            b["hop_phase"] += dt
            # 포물선 홉: 위로 갔다 아래로
            hop_t = b["hop_phase"] / STRAWBERRY_BOMB_HOP_INTERVAL
            hop_offset = -STRAWBERRY_BOMB_HOP_HEIGHT * math.sin(hop_t * math.pi)

            b["x"] += b["vx"] * dt * 60
            b["base_y"] += b["vy"] * dt * 60
            b["visual_y"] = b["base_y"] + hop_offset

            # 벽 반사
            if b["x"] <= 6:
                b["x"] = 6
                b["vx"] = abs(b["vx"]) * 0.9
            elif b["x"] >= screen_width - 6:
                b["x"] = screen_width - 6
                b["vx"] = -abs(b["vx"]) * 0.9

            # 보스쪽 벽(상단)에 도달하면 폭발
            if b["base_y"] <= boss_y + 40:
                hits.append({"x": b["x"], "y": b["base_y"], "hit_boss": False})
                self._create_explosion(b["x"], b["base_y"])
                continue

            # 수명 초과
            if b["age"] > 4.0:
                self._create_explosion(b["x"], b["base_y"])
                continue

            alive_bombs.append(b)

        self.bombs = alive_bombs

        # 3) 폭발 이펙트 업데이트
        alive_explosions = []
        for e in self.explosions:
            e["timer"] -= dt
            if e["timer"] > 0:
                alive_explosions.append(e)
        self.explosions = alive_explosions

        # 4) 페인트 업데이트 (서서히 사라짐)
        alive_paint = []
        for p in self.paint_splatters:
            p["timer"] -= dt
            if p["timer"] > 0:
                p["alpha"] = max(0, int(255 * (p["timer"] / STRAWBERRY_BOMB_PAINT_DURATION)))
                alive_paint.append(p)
        self.paint_splatters = alive_paint

        # 5) 투척 완료 + 모든 폭탄 소진 → 쿨타임 시작
        if not self.throwing and len(self.bombs) == 0 and self.active:
            self.active = False
            self.cooldown = STRAWBERRY_BOMB_COOLDOWN

        return hits

    def check_boss_collision(self, boss_rect):
        """보스와 폭탄 충돌 체크. 히트된 폭탄 목록 반환"""
        hits = []
        remaining = []
        for b in self.bombs:
            bomb_rect = pygame.Rect(int(b["x"]) - 6, int(b["base_y"]) - 6, 12, 12)
            if bomb_rect.colliderect(boss_rect):
                hits.append({"x": b["x"], "y": b["base_y"], "hit_boss": True})
                self._create_explosion(b["x"], b["base_y"])
            else:
                remaining.append(b)
        self.bombs = remaining
        return hits

    def _spawn_bomb(self, player_x, player_y, screen_width):
        """폭탄 하나 생성 — 왼쪽→오른쪽으로 촤라락 뿌리기"""
        # 진행률 0~1: 왼쪽(-1)→오른쪽(+1)으로 스윕
        progress = self._thrown_count / max(1, STRAWBERRY_BOMB_COUNT - 1)
        sweep_angle = -1.0 + 2.0 * progress  # -1 ~ +1
        sweep_vx = sweep_angle * 4.0 + random.uniform(-0.8, 0.8)
        spawn_offset_x = sweep_angle * 25 + random.uniform(-5, 5)
        self.bombs.append({
            "x": float(player_x) + spawn_offset_x,
            "base_y": float(player_y) - 10,
            "visual_y": float(player_y) - 10,
            "vx": sweep_vx,
            "vy": -(STRAWBERRY_BOMB_BASE_SPEED + random.uniform(0, 1.5)),
            "hop_timer": random.uniform(0.05, STRAWBERRY_BOMB_HOP_INTERVAL * 0.5),
            "hop_phase": 0.0,
            "age": 0.0,
            "rotation": random.uniform(0, math.pi * 2),
            "rot_speed": random.uniform(3, 8),
        })

    def _create_explosion(self, x, y):
        """폭발 이펙트 + 페인트 생성"""
        self.explosions.append({
            "x": x, "y": y, "timer": 0.5,
            "max_timer": 0.5,
            "particles": [
                {
                    "dx": random.uniform(-20, 20),
                    "dy": random.uniform(-20, 20),
                    "size": random.randint(3, 7),
                    "color": random.choice([
                        STRAWBERRY_RED, STRAWBERRY_LIGHT, SEED_COLOR,
                        (255, 100, 80), (200, 40, 40),
                    ]),
                }
                for _ in range(12)
            ],
        })
        # 페인트 (슬로우 장판)
        self.paint_splatters.append({
            "x": x, "y": y,
            "radius": STRAWBERRY_BOMB_PAINT_RADIUS + random.randint(-4, 4),
            "timer": STRAWBERRY_BOMB_PAINT_DURATION,
            "alpha": 255,
            "blobs": [
                {
                    "dx": random.uniform(-18, 18),
                    "dy": random.uniform(-12, 12),
                    "r": random.randint(5, 12),
                }
                for _ in range(random.randint(4, 7))
            ],
        })

    def is_boss_in_paint(self, boss_rect):
        """보스가 페인트 위에 있는지 체크"""
        for p in self.paint_splatters:
            if p["timer"] <= 0:
                continue
            paint_rect = pygame.Rect(
                int(p["x"]) - p["radius"],
                int(p["y"]) - p["radius"],
                p["radius"] * 2,
                p["radius"] * 2,
            )
            if paint_rect.colliderect(boss_rect):
                return True
        return False

    def needs_runtime_update(self):
        return self.active or self.throwing or self.bombs or self.explosions or self.paint_splatters

    def draw(self, screen, screen_width):
        """폭탄, 폭발 이펙트, 페인트 전부 그리기"""
        # 페인트 (바닥에 먼저)
        for p in self.paint_splatters:
            if p["alpha"] <= 0:
                continue
            for blob in p["blobs"]:
                bx = int(p["x"] + blob["dx"])
                by = int(p["y"] + blob["dy"])
                br = blob["r"]
                surf = pygame.Surface((br * 2, br * 2), pygame.SRCALPHA)
                a = min(255, int(p["alpha"] * 0.7))
                pygame.draw.ellipse(surf, (180, 20, 20, a), (0, 0, br * 2, br * 2))
                # 하이라이트
                pygame.draw.ellipse(surf, (220, 60, 50, a // 2),
                                    (br // 3, br // 4, br, int(br * 0.6)))
                screen.blit(surf, (bx - br, by - br))

        # 폭탄
        for b in self.bombs:
            self._draw_bomb(screen, b)

        # 폭발 이펙트
        for e in self.explosions:
            progress = 1.0 - (e["timer"] / e["max_timer"])
            alpha = int(255 * (1.0 - progress))
            for part in e["particles"]:
                px = int(e["x"] + part["dx"] * progress * 2)
                py = int(e["y"] + part["dy"] * progress * 2)
                sz = max(1, int(part["size"] * (1.0 - progress * 0.5)))
                c = part["color"]
                s = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
                pygame.draw.circle(s, (*c, max(0, alpha)), (sz, sz), sz)
                screen.blit(s, (px - sz, py - sz))
            # 폭발 중심 플래시
            if progress < 0.3:
                flash_r = int(25 * (1.0 - progress / 0.3))
                flash_s = pygame.Surface((flash_r * 2, flash_r * 2), pygame.SRCALPHA)
                pygame.draw.circle(flash_s, (255, 255, 200, int(200 * (1.0 - progress / 0.3))),
                                   (flash_r, flash_r), flash_r)
                screen.blit(flash_s, (int(e["x"]) - flash_r, int(e["y"]) - flash_r))

    @staticmethod
    def _draw_bomb(screen, bomb):
        """딸기폭탄 하나 그리기 (작은 딸기 + 도화선)"""
        x, y = int(bomb["x"]), int(bomb["visual_y"])
        rot = bomb["rotation"]
        sz = 7  # 반지름

        s = pygame.Surface((sz * 4, sz * 4), pygame.SRCALPHA)
        cx, cy = sz * 2, sz * 2
        # 딸기 몸체
        pygame.draw.ellipse(s, STRAWBERRY_RED, (cx - sz, cy - sz + 1, sz * 2, int(sz * 2.2)))
        pygame.draw.ellipse(s, STRAWBERRY_LIGHT, (cx - sz + 2, cy - sz + 2, sz * 2 - 4, int(sz * 0.8)))
        # 씨앗
        for sx, sy in [(cx - 2, cy), (cx + 2, cy), (cx, cy + 3)]:
            pygame.draw.circle(s, SEED_COLOR, (sx, sy), 1)
        # 잎
        pygame.draw.ellipse(s, GREEN_MID, (cx - 4, cy - sz - 2, 8, 4))
        # 도화선 (불꽃)
        fuse_x = cx
        fuse_y = cy - sz - 3
        t = pygame.time.get_ticks() * 0.01
        spark_col = (255, int(180 + 50 * math.sin(t + bomb["rotation"])), 50)
        pygame.draw.line(s, (80, 60, 40), (fuse_x, fuse_y + 2), (fuse_x, fuse_y - 2), 1)
        pygame.draw.circle(s, spark_col, (fuse_x, fuse_y - 3), 2)
        pygame.draw.circle(s, (255, 255, 200), (fuse_x, fuse_y - 3), 1)

        # 회전 적용
        rotated = pygame.transform.rotozoom(s, -math.degrees(rot), 1.0)
        rect = rotated.get_rect(center=(x, y))
        screen.blit(rotated, rect)


# ── 싱글톤 인스턴스 ──────────────────────────────────────
_transform_state = None

def get_transform_state():
    """뿔딸기 변신 상태 싱글톤"""
    global _transform_state
    if _transform_state is None:
        _transform_state = HornStrawberryTransformState()
    return _transform_state

def reset_transform_state():
    """변신 상태 완전 초기화 (게임 종료/메뉴 복귀)"""
    global _transform_state
    if _transform_state:
        _transform_state.reset()

def reset_stage_transform():
    """새 스테이지 시작 시 변신 횟수만 리셋 (장착 상태 유지)"""
    global _transform_state
    if _transform_state:
        _transform_state._used_this_stage = False
