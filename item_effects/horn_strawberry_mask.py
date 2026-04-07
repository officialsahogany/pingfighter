"""
뿔딸기 변신가면 (Horn Strawberry Mask) - 전설 아이템 효과 모듈

머리 부위 전설 아이템.
커맨드 입력(A→W→D, 1.5초 이내)으로 게이지 소모 후 60초간 뿔딸기로 변신.
변신 중: 패들 30% 크기 증가, 이동속도 8, 공 타격 시 게이지 +30
전용 스킬 3종: 뿔박치기(W), 딸기장판(S홀드), 딸기먹기(Space/클릭)
"""

import math
import random
import pygame

try:
    from downtown.hero_skills import BoneBarrier as HeroBoneBarrier
    from downtown.hero_skills import HornCharge as HeroHornCharge
except Exception:
    HeroBoneBarrier = None
    HeroHornCharge = None

# ── 상수 ──────────────────────────────────────────────────
COMMAND_SEQUENCE = [pygame.K_a, pygame.K_w, pygame.K_d]  # A→W→D
COMMAND_TIMEOUT = 1.5  # 커맨드 입력 허용 시간 (초)
TRANSFORM_GAUGE_COST = 300  # 기본 게이지 소모 (롤옵션으로 변동)
TRANSFORM_DURATION = 60.0  # 기본 변신 지속시간 (초, 롤옵션으로 변동)
TRANSFORM_START_EVENT_DURATION = 3.0  # 변신 시작 이벤트 시간 (초)
TRANSFORM_END_EVENT_DURATION = 2.0  # 변신 해제 이벤트 시간 (초)

# 변신 중 능력치
TRANSFORM_PADDLE_SIZE_BONUS = 0.30  # 패들 크기 30% 증가 (기본)
TRANSFORM_MOVE_SPEED = 8  # 이동속도
TRANSFORM_GAUGE_ON_HIT = 30  # 공 타격 시 게이지 회복

# 스킬: 뿔박치기 (W)
HORN_CHARGE_GAUGE_COST = 300
HORN_CHARGE_COOLDOWN = 20.0  # 초
HORN_CHARGE_PHASES = {
    "CHARGING": 0.43,   # 돌진
    "IMPACT": 0.2,      # 충돌
    "RETURNING": 0.5,   # 복귀
    "STUN": 1.0,        # 경직
}

# 스킬: 딸기장판 (S 홀드)
STRAWBERRY_FIELD_GAUGE_COST = 100  # 홀딩 중 총 소모
STRAWBERRY_FIELD_COOLDOWN = 10.0
STRAWBERRY_FIELD_HOLD_MIN = 1.0  # 최소 홀드 시간 (초)
STRAWBERRY_FIELD_WIDTH = 120
STRAWBERRY_FIELD_HEIGHT = 12

# 스킬: 딸기먹기 (Space/클릭)
STRAWBERRY_EAT_DURATION = 0.8  # 먹는 시간 (초)
STRAWBERRY_EAT_GAUGE_RECOVER = 150
STRAWBERRY_EAT_COOLDOWN = 0.8
STRAWBERRY_STEM_SPEED_MULT = 2.5  # 권총 대비 250% 속도 (빠른 투사체)

# ── 색상 팔레트 ──────────────────────────────────────────
STRAWBERRY_RED = (220, 40, 50)
STRAWBERRY_DARK = (180, 20, 30)
STRAWBERRY_LIGHT = (240, 70, 70)
STRAWBERRY_HIGHLIGHT = (255, 120, 120)
GREEN_DARK = (30, 100, 20)
GREEN_MID = (50, 150, 40)
GREEN_BRIGHT = (80, 200, 60)
SEED_COLOR = (240, 220, 100)


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

        # 커맨드 입력 추적
        self.command_buffer = []  # 입력된 키 시퀀스
        self.command_timer = 0.0  # 커맨드 입력 타이머
        self.prev_keys = {}  # 이전 프레임 키 상태

        # 스킬 상태
        self.horn_charge = _HornChargeSkillCore()
        self.strawberry_field = _StrawberryFieldSkillCore()
        self.strawberry_eat = StrawberryEatSkill()

        # 변신 연출 파티클
        self.event_particles = []
        self.flash_alpha = 0

        # 롤옵션 캐시 (장착 시 동기화)
        self._transform_duration = TRANSFORM_DURATION
        self._gauge_cost = TRANSFORM_GAUGE_COST
        self._paddle_size_bonus = TRANSFORM_PADDLE_SIZE_BONUS

    def sync_roll_options(self, legendary_item):
        """전설 아이템 인스턴스에서 롤옵션 값 동기화"""
        if legendary_item:
            self._transform_duration = legendary_item.transform_duration
            self._gauge_cost = legendary_item.gauge_cost
            self._paddle_size_bonus = legendary_item.paddle_size_bonus / 100.0

    def reset(self):
        """게임 종료/메뉴 복귀 시 완전 초기화"""
        self.state = self.IDLE
        self.transform_timer = 0.0
        self.event_timer = 0.0
        self.command_buffer.clear()
        self.command_timer = 0.0
        self.prev_keys.clear()
        self.horn_charge.reset()
        self.strawberry_field.reset()
        self.strawberry_eat.reset()
        self.event_particles.clear()
        self.flash_alpha = 0

    @property
    def is_transformed(self):
        return self.state == self.TRANSFORMED

    @property
    def is_event_playing(self):
        return self.state in (self.TRANSFORM_EVENT, self.DETRANSFORM_EVENT)

    def update_command_input(self, keys, dt):
        """커맨드 입력 감지 (A→W→D)"""
        if self.state != self.IDLE or not self.active:
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
        """변신 시도 (게이지 충분하면 변신 시작)"""
        cost = self._gauge_cost
        if current_gauge >= cost:
            consume_gauge_fn(cost)
            self.state = self.TRANSFORM_EVENT
            self.event_timer = TRANSFORM_START_EVENT_DURATION
            self.flash_alpha = 255
            self._spawn_transform_particles()
            return True
        return False

    def update(self, dt):
        """매 프레임 업데이트"""
        if self.state == self.TRANSFORM_EVENT:
            self.event_timer -= dt
            self.flash_alpha = max(0, int(255 * (self.event_timer / TRANSFORM_START_EVENT_DURATION)))
            self._update_event_particles(dt)
            if self.event_timer <= 0:
                self.state = self.TRANSFORMED
                self.transform_timer = self._transform_duration
                self.horn_charge.reset()
                self.strawberry_field.reset()
                self.strawberry_eat.reset()

        elif self.state == self.TRANSFORMED:
            self.transform_timer -= dt
            # 스킬 쿨타임 업데이트
            self.horn_charge.update_cooldown(dt)
            self.strawberry_field.update_cooldown(dt)
            self.strawberry_eat.update_cooldown(dt)

            if self.transform_timer <= 0:
                self.horn_charge.reset()
                self.strawberry_field.reset()
                self.strawberry_eat.reset()
                self.state = self.DETRANSFORM_EVENT
                self.event_timer = TRANSFORM_END_EVENT_DURATION
                self.flash_alpha = 255
                self._spawn_transform_particles()

        elif self.state == self.DETRANSFORM_EVENT:
            self.event_timer -= dt
            self.flash_alpha = max(0, int(255 * (self.event_timer / TRANSFORM_END_EVENT_DURATION)))
            self._update_event_particles(dt)
            if self.event_timer <= 0:
                self.state = self.IDLE
                self.flash_alpha = 0

        # 이벤트 파티클 업데이트 (항상)
        self._update_event_particles(dt)

    def _spawn_transform_particles(self):
        """변신 이벤트 파티클 생성"""
        self.event_particles.clear()
        for _ in range(40):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 8)
            self.event_particles.append({
                "x": 0, "y": 0,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed,
                "life": random.uniform(1.0, 2.5),
                "max_life": 2.5,
                "color": random.choice([
                    STRAWBERRY_RED, STRAWBERRY_LIGHT, GREEN_MID,
                    GREEN_BRIGHT, SEED_COLOR, STRAWBERRY_HIGHLIGHT
                ]),
                "size": random.uniform(3, 8),
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

    def draw_transform_event(self, screen, player_x, player_y):
        """변신/해제 이벤트 연출 그리기"""
        if self.state not in (self.TRANSFORM_EVENT, self.DETRANSFORM_EVENT):
            return

        w, h = screen.get_size()

        # 화면 플래시
        if self.flash_alpha > 0:
            flash_surf = pygame.Surface((w, h), pygame.SRCALPHA)
            if self.state == self.TRANSFORM_EVENT:
                flash_surf.fill((255, 100, 100, min(180, self.flash_alpha)))
            else:
                flash_surf.fill((200, 200, 255, min(150, self.flash_alpha)))
            screen.blit(flash_surf, (0, 0))

        # 이벤트 텍스트
        is_transforming = self.state == self.TRANSFORM_EVENT
        text = "뿔딸기변신!" if is_transforming else "변신해제..."
        progress = 1.0 - (self.event_timer / (TRANSFORM_START_EVENT_DURATION if is_transforming else TRANSFORM_END_EVENT_DURATION))

        # 텍스트 크기 애니메이션
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
            # 텍스트 그림자
            shadow_surf = font.render(text, True, (0, 0, 0))
            shadow_rect = shadow_surf.get_rect(center=(w // 2 + 2, h // 2 - 40 + 2))
            screen.blit(shadow_surf, shadow_rect)
            # 메인 텍스트
            text_color = STRAWBERRY_RED if is_transforming else (150, 150, 200)
            text_surf = font.render(text, True, text_color)
            text_rect = text_surf.get_rect(center=(w // 2, h // 2 - 40))
            screen.blit(text_surf, text_rect)
        except Exception:
            pass

        # 파티클 렌더링
        for p in self.event_particles:
            alpha = max(0, min(255, int(255 * p["life"] / p["max_life"])))
            px = int(player_x + p["x"])
            py = int(player_y + p["y"])
            sz = max(1, int(p["size"] * (p["life"] / p["max_life"])))
            ps = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
            c = (*p["color"], alpha)
            pygame.draw.circle(ps, c, (sz, sz), sz)
            screen.blit(ps, (px - sz, py - sz))

    def draw_strawberry_paddle(self, screen, x, y, width, height):
        """변신 상태 패들 - 둥글둥글 아기자기 딸기 캐릭터 (뒷모습)"""
        if not self.is_transformed:
            return

        t = pygame.time.get_ticks()
        cx = x + width // 2

        # ── 걷기 모션 ──
        prev_x = getattr(self, '_prev_paddle_x', cx)
        move_dir = cx - prev_x
        self._prev_paddle_x = cx
        is_moving = abs(move_dir) > 0.5
        walk_timer = getattr(self, '_walk_timer', 0.0)
        if is_moving:
            walk_timer += 0.15
        self._walk_timer = walk_timer

        if is_moving:
            bounce_y = abs(math.sin(walk_timer * 3.5)) * 5
            squash = 1.0 + math.sin(walk_timer * 7.0) * 0.06
        else:
            bounce_y = math.sin(t * 0.003) * 1.5
            squash = 1.0 + math.sin(t * 0.004) * 0.02
        lean = min(6, max(-6, move_dir * 1.2)) if is_moving else 0

        # ── 크기 (둥글둥글) ──
        r = max(20, int(width * 0.28))
        body_cx = cx
        body_cy = int(y - r + 2 - bounce_y)

        # ── 서피스 ──
        pad = 30
        sz = r * 2 + pad * 2
        surf = pygame.Surface((sz, sz), pygame.SRCALPHA)
        sc = sz // 2

        # ── 그림자 ──
        sh_w, sh_h = int(r * 1.4), 5
        pygame.draw.ellipse(surf, (0, 0, 0, 40),
                           (sc - sh_w // 2, sc + r + 3, sh_w, sh_h))

        # ── 발 (동그란 빨간 발) ──
        foot_bob = math.sin(walk_timer * 7) * 2.5 if is_moving else 0
        for side in [-1, 1]:
            fx = sc + side * int(r * 0.45)
            fy = sc + r + 1 + (foot_bob if side == 1 else -foot_bob)
            pygame.draw.ellipse(surf, (210, 45, 55), (fx - 4, int(fy) - 2, 8, 6))
            pygame.draw.ellipse(surf, (250, 100, 110), (fx - 2, int(fy) - 1, 4, 3))

        # ── 딸기 몸통 (딸기형 — 폴리곤으로 위 넓고 아래 좁은 매끈한 곡선) ──
        bw = int(r * 2 * (2.0 - squash))
        bh = int(r * 2.2 * squash)
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

        # 광택 (좌상단)
        hi_r = max(5, r // 2)
        pygame.draw.circle(surf, STRAWBERRY_LIGHT,
                          (sc - int(bw * 0.18), top_y + int(bh * 0.25)), hi_r)
        pygame.draw.circle(surf, (255, 190, 195),
                          (sc - int(bw * 0.2), top_y + int(bh * 0.2)), max(2, hi_r // 2))
        shine_a = int(140 + 60 * math.sin(t * 0.005))
        pygame.draw.circle(surf, (255, 255, 255, shine_a),
                          (sc - int(bw * 0.22), top_y + int(bh * 0.17)), 2)

        # 외곽선
        pygame.draw.polygon(surf, STRAWBERRY_DARK, body_pts, 2)

        # ── 씨앗 (딸기 형태 안에 배치) ──
        seed_rng = random.Random(77)
        for _ in range(14):
            sa = seed_rng.uniform(0, math.pi * 2)
            sd = seed_rng.uniform(0.15, 0.65)
            norm_y = math.sin(sa)
            if norm_y < 0:
                ws = 1.0 + abs(norm_y) * 0.05
            else:
                ws = 1.0 - norm_y * 0.45
            sx = int(sc + math.cos(sa) * bw // 2 * ws * sd)
            sy = int(sc + norm_y * bh // 2 * sd)
            pygame.draw.ellipse(surf, (160, 15, 25), (sx - 2, sy - 1, 5, 4))
            pygame.draw.ellipse(surf, (215, 180, 55), (sx - 1, sy, 4, 3))
            pygame.draw.rect(surf, (240, 215, 85), (sx, sy, 2, 1))

        # ── 잎사귀 (상단 3장) ──
        leaf_y = sc - bh // 2 + 2
        sway = math.sin(t * 0.004) * 2.5
        pygame.draw.polygon(surf, (55, 155, 40), [
            (sc - 8, leaf_y + 3), (sc + 8, leaf_y + 3), (sc + sway, leaf_y - 14)])
        pygame.draw.polygon(surf, (40, 120, 30), [
            (sc - 8, leaf_y + 3), (sc + 8, leaf_y + 3), (sc + sway, leaf_y - 14)], 1)
        pygame.draw.line(surf, (75, 185, 55), (sc, leaf_y + 2),
                        (int(sc + sway * 0.4), leaf_y - 10), 1)
        for s in [-1, 1]:
            lx = sc + s * int(r * 0.4)
            pygame.draw.polygon(surf, (50, 145, 38), [
                (lx - 3 * s, leaf_y + 4), (lx + 5 * s, leaf_y + 4),
                (lx + s * 10 + sway * 0.6, leaf_y - 6)])
            pygame.draw.polygon(surf, (35, 110, 25), [
                (lx - 3 * s, leaf_y + 4), (lx + 5 * s, leaf_y + 4),
                (lx + s * 10 + sway * 0.6, leaf_y - 6)], 1)

        # ── 뿔 2개 (잎사귀 바깥, 귀여운 곡선) ──
        for s in [-1, 1]:
            hw = math.sin(t * 0.005 + s) * 2
            hbx = sc + s * int(r * 0.55)
            hby = leaf_y + 2
            htx = hbx + s * 6 + hw
            hty = hby - 16
            pygame.draw.polygon(surf, GREEN_MID, [
                (hbx - 3, hby), (hbx + 3, hby),
                (int(htx + 1), int(hty)), (int(htx - 1), int(hty))])
            pygame.draw.polygon(surf, GREEN_BRIGHT, [
                (hbx, hby - 1), (hbx + 2, hby - 1), (int(htx), int(hty + 3))])
            pygame.draw.circle(surf, (120, 230, 100), (int(htx), int(hty)), 2)
            pygame.draw.polygon(surf, GREEN_DARK, [
                (hbx - 3, hby), (hbx + 3, hby),
                (int(htx + 1), int(hty)), (int(htx - 1), int(hty))], 1)

        # ── 기울기 + 그리기 ──
        if abs(lean) > 0.3:
            surf = pygame.transform.rotozoom(surf, -lean, 1.0)
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
            getattr(self._skill, "PHASE_RETURNING", -997),
        )

    def update(self, dt, player_rect, boss_rect, ball_rect, ball_vel):
        if self._skill is None or player_rect is None or boss_rect is None:
            return
        caster, target, ball = _build_bottom_skill_context(player_rect, boss_rect, ball_rect, ball_vel)
        self._skill.update(dt, caster, target, ball, self._game_state)
        ball.sync_velocity(ball_vel)
        _stun_phase = getattr(self._skill, "PHASE_STUN", 3)
        if self._skill.is_active and self._skill.phase == _stun_phase:
            self._game_state["bottom_paddle_stunned"] = False
            self._game_state["horn_charge_active"] = False
            self._game_state["horn_charge_x_offset"] = 0.0
            self._game_state["horn_charge_y_offset"] = 0.0
            if self._anchor_player_centerx is not None:
                player_rect.centerx = int(self._anchor_player_centerx)
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
        self.projectiles = []  # 발사된 꼭지 투사체

    def reset(self):
        self.eating = False
        self.eat_timer = 0.0
        self.cooldown = 0.0
        self.projectiles.clear()

    def can_use(self):
        return not self.eating and self.cooldown <= 0

    def activate(self):
        if self.can_use():
            self.eating = True
            self.eat_timer = STRAWBERRY_EAT_DURATION
            return True
        return False

    def update(self, dt, player_x, player_y, recover_gauge_fn, recover_dash_fn):
        """먹기 업데이트. 반환: True면 이동 불가 상태"""
        if self.eating:
            self.eat_timer -= dt
            if self.eat_timer <= 0:
                self.eating = False
                self.cooldown = STRAWBERRY_EAT_COOLDOWN
                # 먹기 완료: 게이지 회복 + 대시 토큰 회복
                recover_gauge_fn(STRAWBERRY_EAT_GAUGE_RECOVER)
                recover_dash_fn(1)
                # 꼭지 투사체 발사
                self._fire_stem(player_x, player_y)
            return True  # 이동 불가

        # 투사체 업데이트
        alive = []
        for p in self.projectiles:
            p["y"] -= p["speed"] * dt * 60  # 프레임 독립
            p["rotation"] += p["rot_speed"] * dt * 60
            p["life"] -= dt
            if p["life"] > 0 and p["y"] > -20:
                alive.append(p)
        self.projectiles = alive

        return False

    def _fire_stem(self, player_x, player_y):
        """딸기 꼭지 투사체 발사"""
        # 코만도 권총 속도의 120%
        base_speed = 7  # 권총 기본 속도
        speed = base_speed * STRAWBERRY_STEM_SPEED_MULT
        self.projectiles.append({
            "x": player_x, "y": player_y - 20,
            "speed": speed,
            "rotation": 0,
            "rot_speed": 5,
            "life": 3.0,
            "damage": 1,
            "stun_duration": 0.75,  # 코만도 권총과 동일한 스턴 (45프레임)
            "knockback": 120,  # 코만도 권총과 동일한 넉백
        })

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
