"""
🧸 Teddy Bear Boss Sprite - 고퀄리티 프로시저럴 테디베어 보스 렌더링 (v5 Organic)

- 2x SSAA 슈퍼샘플링 안티앨리어싱 (smoothscale)
- 유기적 폴리곤 기반 렌더링 (타원 탈피)
  · 물방울형 테이퍼드 팔다리 (관절↔발/손)
  · 서양배 체형 몸통 (좁은 가슴 → 넓은 엉덩이)
  · 관절 접합부 앰비언트 오클루전 그림자
  · 윤곽선 퍼 터프트 (머리 꼭대기, 뺨, 어깨)
- 얀데레 하트 눈 + 5단계 볼 홍조
- 묵직한 거대 보스 모션 (50% 감속)
"""

import pygame
import math

_sin = math.sin
_cos = math.cos
_pi = math.pi
_tau = math.pi * 2

# SSAA 배율
_SSAA = 2


def _tapered_polygon(cx, cy, half_w_top, half_w_bot, height, steps=8):
    """물방울형 테이퍼드 폴리곤 꼭짓점 생성 (위쪽 좁고 아래쪽 넓음).
    좌변 위→아래, 우변 아래→위 순서로 폐합 폴리곤 반환."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        y = cy + int(t * height)
        # 큐빅 이징: 위에서 아래로 갈수록 빠르게 넓어짐
        ease = t * t * (3 - 2 * t)
        hw = half_w_top + (half_w_bot - half_w_top) * ease
        pts.append((cx - int(hw), y))
    for i in range(steps, -1, -1):
        t = i / steps
        y = cy + int(t * height)
        ease = t * t * (3 - 2 * t)
        hw = half_w_top + (half_w_bot - half_w_top) * ease
        pts.append((cx + int(hw), y))
    return pts


def _pear_polygon(cx, cy, half_w_top, half_w_bot, height, steps=12):
    """서양배 체형 폴리곤 꼭짓점 생성 (좁은 어깨 → 넓은 엉덩이).
    상단은 라운드, 하단은 넓게 벌어진 유기적 외형."""
    pts = []
    # 왼쪽 윤곽 (위→아래)
    for i in range(steps + 1):
        t = i / steps
        y = cy + int(t * height)
        # 위쪽은 살짝 좁아졌다가 아래로 갈수록 넓어지는 S자 커브
        if t < 0.35:
            # 어깨~가슴: 부드럽게 좁아짐
            local_t = t / 0.35
            hw = half_w_top * (1.0 - 0.08 * _sin(local_t * _pi))
        else:
            # 가슴~엉덩이: 점점 넓어짐
            local_t = (t - 0.35) / 0.65
            ease = local_t * local_t * (3 - 2 * local_t)
            hw = half_w_top + (half_w_bot - half_w_top) * ease
        pts.append((cx - int(hw), y))
    # 오른쪽 윤곽 (아래→위)
    for i in range(steps, -1, -1):
        t = i / steps
        y = cy + int(t * height)
        if t < 0.35:
            local_t = t / 0.35
            hw = half_w_top * (1.0 - 0.08 * _sin(local_t * _pi))
        else:
            local_t = (t - 0.35) / 0.65
            ease = local_t * local_t * (3 - 2 * local_t)
            hw = half_w_top + (half_w_bot - half_w_top) * ease
        pts.append((cx + int(hw), y))
    return pts


def _draw_ao_shadow(screen, cx, cy, rx, ry, alpha=50):
    """관절 접합부 앰비언트 오클루전 — 반투명 타원 그림자"""
    if rx < 2 or ry < 2:
        return
    w = rx * 2
    h = ry * 2
    ao_surf = pygame.Surface((w + 4, h + 4), pygame.SRCALPHA)
    for ring in range(3):
        a = max(0, alpha - ring * 15)
        r_x = max(2, rx - ring * 2)
        r_y = max(2, ry - ring * 2)
        pygame.draw.ellipse(ao_surf, (30, 15, 8, a),
                            (w // 2 + 2 - r_x, h // 2 + 2 - r_y, r_x * 2, r_y * 2))
    screen.blit(ao_surf, (cx - w // 2 - 2, cy - h // 2 - 2))


def _draw_fur_tufts(screen, points, color, tuft_size, spacing=3, seed_offset=0):
    """실루엣 외곽 점 목록에 작은 삼각형 퍼 터프트 렌더링.
    points: 외곽 꼭짓점 리스트, spacing: 몇 개 간격으로 터프트 생성"""
    n = len(points)
    if n < 4:
        return
    for i in range(0, n, spacing):
        j = (i + 1) % n
        ax, ay = points[i]
        bx, by = points[j]
        # 외향 법선 방향
        dx = bx - ax
        dy = by - ay
        length = max(1, (dx * dx + dy * dy) ** 0.5)
        nx = -dy / length
        ny = dx / length
        # 삼각형 터프트 — 약간의 의사-랜덤 변동
        vary = 0.6 + 0.4 * abs(_sin(i * 1.7 + seed_offset))
        ts = tuft_size * vary
        mid_x = (ax + bx) // 2
        mid_y = (ay + by) // 2
        tip_x = int(mid_x + nx * ts)
        tip_y = int(mid_y + ny * ts)
        pygame.draw.polygon(screen, color, [
            (ax, ay), (tip_x, tip_y), (bx, by)
        ])


class TeddyBearBossSprite:
    """고퀄리티 테디베어 보스 프로시저럴 스프라이트 (2x SSAA, 유기적 폴리곤)"""

    def __init__(self):
        self.time = 0.0

        # 이동 애니메이션 상태
        self.prev_x = None
        self.velocity = 0.0
        self.lean = 0.0
        self.lean_velocity = 0.0
        self.step_phase = 0.0
        self.body_bob = 0.0
        self.body_roll = 0.0
        self.arm_swing = 0.0
        self.head_tilt = 0.0
        self.ear_bounce = 0.0
        self.ribbon_flutter = 0.0
        self.move_dir = 0
        self.face_dir = 1.0
        self.face_dir_target = 0.0

        # ── 반격(Counter) 애니메이션 상태 ──
        self.is_countering = False
        self.counter_timer = 0.0
        self.counter_dir = 1        # 타격 방향 (+1: 오른손, -1: 왼손)
        # 반격 시퀀스에서 구동되는 보간값
        self._ct_body_lean = 0.0    # 몸통 기울기
        self._ct_head_lean = 0.0    # 머리 기울기
        self._ct_arm_angle = 0.0    # 때리는 팔 각도 (라디안)
        self._ct_arm_stretch = 1.0  # 팔 길이 배율 (Phase2에서 >1)

        # 서피스 캐시
        self._surface_cache = {}
        self._ssaa_cache_key = None
        self._ssaa_cache_surf = None

    def trigger_counter(self, ball_x=None, boss_cx=None):
        """반격 애니메이션 트리거. ball_x로 타격 방향 결정."""
        if self.is_countering:
            return
        self.is_countering = True
        self.counter_timer = 0.0
        # 공이 오른쪽에서 왔으면 오른손으로, 왼쪽이면 왼손으로
        if ball_x is not None and boss_cx is not None:
            self.counter_dir = 1 if ball_x >= boss_cx else -1
        else:
            self.counter_dir = 1 if self.face_dir >= 0 else -1

    def _get_surface(self, w, h):
        w = max(4, ((w + 3) // 4) * 4)
        h = max(4, ((h + 3) // 4) * 4)
        key = (w, h)
        if key not in self._surface_cache:
            self._surface_cache[key] = pygame.Surface((w, h), pygame.SRCALPHA)
        else:
            self._surface_cache[key].fill((0, 0, 0, 0))
        return self._surface_cache[key]

    def update(self, boss_x, dt=1 / 60):
        """보스 위치 기반 애니메이션 업데이트 (묵직한 속도)"""
        self.time += dt

        if self.prev_x is not None:
            dx = boss_x - self.prev_x
            self.velocity = self.velocity * 0.75 + dx * 0.25
        self.prev_x = boss_x

        speed = abs(self.velocity)
        moving = speed > 0.3
        speed_ratio = min(1.0, speed / 10.0)

        # ★ 걸음 속도 50% 감속 — 묵직한 거대 보스
        if moving:
            self.move_dir = 1 if self.velocity > 0 else -1
            step_delta = (0.018 + speed_ratio * 0.035) * _tau
            self.step_phase = (self.step_phase + step_delta) % _tau
        else:
            self.step_phase *= 0.94
            if abs(self.step_phase) < 0.01:
                self.step_phase = 0.0

        # Lean 비활성화 (추후 히트 애니메이션으로 대체 예정)
        self.lean = 0.0
        self.lean_velocity = 0.0

        # 바디 롤링 — 느린 주기
        if moving:
            self.body_roll = _sin(self.step_phase) * 2.0 * speed_ratio
        else:
            self.body_roll *= 0.92

        # ★ 바디 밥 — 느리고 묵직 (주파수 절반)
        if moving:
            self.body_bob = _sin(self.step_phase) * 2.0 * speed_ratio
        else:
            self.body_bob = _sin(self.time * 0.8) * 0.4

        # ★ 팔 흔들림 — 느린 진자 (주파수 절반, 진폭 약간 감소)
        if moving:
            self.arm_swing = _sin(self.step_phase) * 0.40 * speed_ratio
        else:
            self.arm_swing = _sin(self.time * 0.6) * 0.03

        # 머리 기울기 비활성화
        self.head_tilt = 0.0

        # 귀 바운스
        if moving:
            self.ear_bounce = abs(_sin(self.step_phase)) * 2.0 * speed_ratio
        else:
            self.ear_bounce = _sin(self.time * 1.0) * 0.3

        # 리본 — 느린 펄럭임
        self.ribbon_flutter = _sin(self.time * 2.0 + self.step_phase) * 4.0

        # 얼굴 방향 — 느린 전환
        if moving:
            self.face_dir_target = float(self.move_dir)
        self.face_dir += (self.face_dir_target - self.face_dir) * 0.08

        # ── 반격(Counter) 시퀀스 업데이트 ──
        if self.is_countering:
            self.counter_timer += dt
            t = self.counter_timer
            d = float(self.counter_dir)

            if t < 0.05:
                # Phase 1: 순간 반동 (0.0~0.05s) — 거의 즉시
                p1 = t / 0.05
                ease_in = p1 * p1
                self._ct_body_lean = -d * 1.2 * ease_in
                self._ct_head_lean = -d * 0.8 * ease_in
                self._ct_arm_angle = -d * 0.4 * ease_in
                self._ct_arm_stretch = 1.0 - 0.08 * ease_in
                self.arm_swing *= (1.0 - ease_in)
                self.body_roll *= (1.0 - ease_in)

            elif t < 0.15:
                # Phase 2: 타격 (0.05~0.15s) — 즉각적 스윙
                p2 = (t - 0.05) / 0.10
                strike = p2 * p2 * (3 - 2 * p2)
                self._ct_body_lean = d * (-1.2 + 4.7 * strike)   # -1.2 → +3.5
                self._ct_head_lean = d * (-0.8 + 2.8 * strike)   # -0.8 → +2.0
                self._ct_arm_angle = d * (-0.4 + 1.9 * strike)   # -0.4 → +1.5
                self._ct_arm_stretch = 0.92 + 0.33 * strike      # 0.92 → 1.25
                self.arm_swing = 0.0
                self.body_roll = 0.0

            elif t < 0.50:
                # Phase 3: 팔로우 스루 + 복귀 (0.15~0.50s)
                p3 = (t - 0.15) / 0.35
                ease_out = 1.0 - (1.0 - p3) * (1.0 - p3)
                self._ct_body_lean = d * 3.5 * (1.0 - ease_out)
                self._ct_head_lean = d * 2.0 * (1.0 - ease_out)
                self._ct_arm_angle = d * 1.5 * (1.0 - ease_out)
                self._ct_arm_stretch = 1.25 - 0.25 * ease_out

            else:
                # 시퀀스 종료
                self.is_countering = False
                self._ct_body_lean = 0.0
                self._ct_head_lean = 0.0
                self._ct_arm_angle = 0.0
                self._ct_arm_stretch = 1.0
        else:
            # 반격 중이 아닐 때 보간값 감쇠 (안전장치)
            self._ct_body_lean *= 0.85
            self._ct_head_lean *= 0.85
            self._ct_arm_angle *= 0.85
            self._ct_arm_stretch += (1.0 - self._ct_arm_stretch) * 0.15

    def draw(self, screen, x, y, w, h):
        """2x SSAA 렌더링: 2배 서피스에 그린 후 smoothscale로 축소"""
        sw = w * _SSAA
        sh = h * _SSAA

        # SSAA 서피스 할당 (캐시)
        cache_key = (sw, sh)
        if self._ssaa_cache_key != cache_key:
            self._ssaa_cache_surf = pygame.Surface((sw, sh), pygame.SRCALPHA)
            self._ssaa_cache_key = cache_key
        hi_surf = self._ssaa_cache_surf
        hi_surf.fill((0, 0, 0, 0))

        # 2배 크기로 렌더링
        self._draw_internal(hi_surf, 0, 0, sw, sh)

        # smoothscale로 축소 → 안티앨리어싱
        lo_surf = pygame.transform.smoothscale(hi_surf, (w, h))
        screen.blit(lo_surf, (x, y))

    def _draw_internal(self, screen, x, y, w, h):
        """내부 렌더링 (SSAA 서피스 위에 그림)"""
        cx = x + w // 2
        cy = y + h // 2
        b = min(w, h) / 20.0

        # 반격 몸통/머리 오프셋 반영
        ct_body_px = int(self._ct_body_lean * b * _SSAA * 0.5)
        ct_head_px = int(self._ct_head_lean * b * _SSAA * 0.5)

        lean_offset = int(self.lean * _SSAA)
        bob_offset = int(self.body_bob * _SSAA)
        roll_offset = self.body_roll * _SSAA
        fd = self.face_dir

        p = {
            "fur": (180, 130, 90),
            "fur_light": (215, 178, 140),
            "fur_lighter": (230, 200, 165),
            "fur_dark": (140, 95, 60),
            "fur_shadow": (95, 60, 35),
            # 림 라이트 색상
            "fur_rim": (240, 215, 185),
            "belly": (235, 218, 198),
            "belly_light": (245, 235, 220),
            "belly_shadow": (210, 190, 165),
            "pink": (255, 130, 170),
            "pink_light": (255, 170, 200),
            "pink_dark": (220, 90, 140),
            "pink_glow": (255, 180, 210),
            # 플러시 눈 (짙은 초콜릿)
            "eye_base": (50, 30, 20),
            "eye_base_light": (75, 50, 35),
            "eye_highlight": (255, 255, 255),
            "eye_highlight_s": (255, 250, 252),
            "nose_dark": (55, 35, 25),
            "nose_mid": (80, 55, 40),
            "nose_highlight": (120, 90, 70),
            "pad": (200, 160, 130),
            "pad_dark": (170, 130, 100),
            "mouth": (120, 75, 50),
        }

        torso_y = cy + bob_offset
        body_cx = cx + lean_offset + ct_body_px
        head_cy_off = torso_y + int(self.head_tilt * 0.3 * _SSAA) + ct_head_px

        self._draw_ground_shadow(screen, body_cx, torso_y, b)
        self._draw_legs(screen, body_cx, torso_y, b, p, roll_offset)
        self._draw_body(screen, body_cx, torso_y, b, p, roll_offset)
        self._draw_arm(screen, body_cx, torso_y, b, p, is_back=True, roll=roll_offset)
        self._draw_head(screen, body_cx, head_cy_off, b, p, fd, roll_offset)
        self._draw_arm(screen, body_cx, torso_y, b, p, is_back=False, roll=roll_offset)

    # ──────────────────────── 그림자 ────────────────────────

    def _draw_ground_shadow(self, screen, cx, torso_y, b):
        shadow_y = torso_y + int(6.5 * b)
        shadow_rx = int(4.0 * b)
        shadow_ry = int(0.6 * b)
        shadow_surf = self._get_surface(shadow_rx * 2 + 4, shadow_ry * 2 + 4)
        scx, scy = shadow_rx + 2, shadow_ry + 2
        for ring in range(4):
            alpha = max(0, 40 - ring * 10)
            rx = max(3, shadow_rx - ring * int(0.35 * b))
            ry = max(2, shadow_ry - ring * int(0.08 * b))
            pygame.draw.ellipse(shadow_surf, (20, 10, 5, alpha),
                                (scx - rx, scy - ry, rx * 2, ry * 2))
        screen.blit(shadow_surf, (cx - scx, shadow_y - scy))

    # ──────────────────────── 다리 (테이퍼드 폴리곤) ────────────────────────

    def _draw_legs(self, screen, cx, torso_y, b, p, roll):
        leg_base_y = torso_y + int(3.0 * b)
        speed_factor = min(1.0, abs(self.velocity) / 8.0)

        leg_h = int(3.2 * b)
        hw_top = int(0.9 * b)   # 관절(엉덩이) 쪽 — 좁음
        hw_bot = int(1.4 * b)   # 발 쪽 — 넓음

        for side in [-1, 1]:
            phase = self.step_phase + (0 if side == -1 else _pi)
            swing_x = _sin(phase) * 2.0 * b * speed_factor
            roll_y = int(roll * 0.3 * side)

            lx = cx + int(side * 1.8 * b) + int(roll * 0.4 * side) + int(swing_x)
            ly = leg_base_y + roll_y

            lift = max(0.0, _sin(phase)) * speed_factor
            ly -= int(lift * 0.8 * b)

            bend = lift
            upper_h = int(leg_h * (0.45 + bend * 0.1))
            lower_h = int(leg_h * (0.55 - bend * 0.1))
            knee_y = ly + upper_h

            # ── 앰비언트 오클루전: 엉덩이 접합부 ──
            _draw_ao_shadow(screen, lx, ly + int(0.2 * b),
                            int(1.3 * b), int(0.5 * b), alpha=45)

            # ── 윗다리 (테이퍼드: 엉덩이 넓고 → 무릎 좁음) ──
            upper_hw_top = int(hw_top * 1.2)  # 엉덩이 넓음
            upper_hw_bot = int(hw_top * 0.85)  # 무릎 좁음

            upper_pts = _tapered_polygon(lx, ly, upper_hw_top, upper_hw_bot, upper_h, steps=6)
            # 그림자
            shadow_pts = [(x + 1, y + 1) for x, y in upper_pts]
            pygame.draw.polygon(screen, p["fur_shadow"], shadow_pts)
            # 다크 레이어
            pygame.draw.polygon(screen, p["fur_dark"], upper_pts)
            # 베이스 (안쪽 축소)
            inner_pts = _tapered_polygon(lx, ly + int(0.1 * b),
                                         int(upper_hw_top * 0.8), int(upper_hw_bot * 0.75),
                                         int(upper_h * 0.85), steps=6)
            pygame.draw.polygon(screen, p["fur"], inner_pts)
            # 하이라이트
            hl_pts = _tapered_polygon(lx - int(0.15 * b), ly + int(0.15 * b),
                                      int(upper_hw_top * 0.35), int(upper_hw_bot * 0.3),
                                      int(upper_h * 0.45), steps=4)
            pygame.draw.polygon(screen, p["fur_light"], hl_pts)

            # ── 앰비언트 오클루전: 무릎 접합부 ──
            _draw_ao_shadow(screen, lx, knee_y - int(0.1 * b),
                            int(1.0 * b), int(0.35 * b), alpha=40)

            # ── 아랫다리 (테이퍼드: 무릎 좁음 → 발 넓음) ──
            lower_hw_top = int(hw_top * 0.75)  # 무릎 좁음
            lower_hw_bot = int(hw_bot * 0.85)  # 발 넓음

            lower_pts = _tapered_polygon(lx, knee_y - int(0.2 * b),
                                         lower_hw_top, lower_hw_bot, lower_h, steps=6)
            pygame.draw.polygon(screen, p["fur_dark"], lower_pts)
            inner_lower = _tapered_polygon(lx, knee_y,
                                           int(lower_hw_top * 0.8), int(lower_hw_bot * 0.75),
                                           int(lower_h * 0.8), steps=6)
            pygame.draw.polygon(screen, p["fur"], inner_lower)

            # 발바닥 패드
            pad_y = knee_y + int(lower_h * 0.55)
            pad_r = max(2, int(0.55 * b))
            pygame.draw.circle(screen, p["pad_dark"], (lx, pad_y), pad_r + 1)
            pygame.draw.circle(screen, p["pad"], (lx, pad_y), pad_r)
            pygame.draw.circle(screen, p["belly_light"], (lx - 1, pad_y - 1), max(1, pad_r // 2))
            for tx_off in [-0.5, 0, 0.5]:
                toe_x = lx + int(tx_off * 0.7 * b)
                toe_y = pad_y - int(0.55 * b)
                toe_r = max(1, int(0.24 * b))
                pygame.draw.circle(screen, p["pad_dark"], (toe_x, toe_y), toe_r + 1)
                pygame.draw.circle(screen, p["pad"], (toe_x, toe_y), toe_r)

    # ──────────────────────── 몸통 (서양배 폴리곤) ────────────────────────

    def _draw_body(self, screen, cx, torso_y, b, p, roll):
        body_h = int(5.5 * b)
        body_top = torso_y - int(0.5 * b)
        roll_x = int(roll * 0.5)
        bcx = cx + roll_x

        hw_top = int(3.0 * b)   # 어깨(좁음)
        hw_bot = int(4.0 * b)   # 엉덩이(넓음)

        # ── 서양배 몸통 폴리곤 ──
        body_pts = _pear_polygon(bcx, body_top, hw_top, hw_bot, body_h, steps=10)

        # 그림자
        shadow_pts = [(x + 2, y + 2) for x, y in body_pts]
        pygame.draw.polygon(screen, p["fur_shadow"], shadow_pts)

        # 베이스 색상
        pygame.draw.polygon(screen, p["fur"], body_pts)

        # 다크 에지 (좌우 가장자리 음영) — 롤링 반영
        la = max(0.6, min(1.4, 1.0 + roll / _SSAA * 0.025))
        ra = max(0.6, min(1.4, 1.0 - roll / _SSAA * 0.025))
        ld = tuple(max(0, min(255, int(c * la))) for c in p["fur_dark"])
        rd = tuple(max(0, min(255, int(c * ra))) for c in p["fur_dark"])

        edge_w = int(1.5 * b)
        edge_h = int(body_h * 0.7)
        # 좌측 에지
        left_edge_pts = _tapered_polygon(bcx - hw_top + int(0.5 * b),
                                          body_top + int(0.5 * b),
                                          int(edge_w * 0.6), int(edge_w * 0.8),
                                          edge_h, steps=5)
        pygame.draw.polygon(screen, ld, left_edge_pts)
        # 우측 에지
        right_edge_pts = _tapered_polygon(bcx + hw_top - int(0.5 * b),
                                           body_top + int(0.5 * b),
                                           int(edge_w * 0.6), int(edge_w * 0.8),
                                           edge_h, steps=5)
        pygame.draw.polygon(screen, rd, right_edge_pts)

        # 밝은 레이어 (내부 서양배)
        light_pts = _pear_polygon(bcx, body_top + int(0.4 * b),
                                   int(hw_top * 0.65), int(hw_bot * 0.6),
                                   int(body_h * 0.65), steps=8)
        pygame.draw.polygon(screen, p["fur_light"], light_pts)

        # 스펙큘러 (상단 좌측 하이라이트)
        spec_pts = _pear_polygon(bcx - int(0.5 * b), body_top + int(0.7 * b),
                                  int(hw_top * 0.25), int(hw_bot * 0.2),
                                  int(body_h * 0.3), steps=6)
        pygame.draw.polygon(screen, p["fur_lighter"], spec_pts)

        # ★ 림 라이트 (몸통 가장자리) — 외곽 폴리곤 기반
        body_w = hw_bot * 2 + 4
        rim_surf = self._get_surface(body_w + 8, body_h + 8)
        # 림 폴리곤을 림 서피스 좌표계로 변환
        rim_ox = bcx - body_w // 2 - 4
        rim_oy = body_top - 4
        rim_outer = [(x - rim_ox + 2, y - rim_oy + 2) for x, y in body_pts]
        pygame.draw.polygon(rim_surf, (*p["fur_rim"], 40), rim_outer)
        # 안쪽을 투명하게 파서 테두리만 남김
        inner_body = _pear_polygon(bcx, body_top + int(0.3 * b),
                                    int(hw_top * 0.88), int(hw_bot * 0.88),
                                    int(body_h * 0.9), steps=10)
        inner_pts_local = [(x - rim_ox + 2, y - rim_oy + 2) for x, y in inner_body]
        inner_rim = pygame.Surface((body_w + 8, body_h + 8), pygame.SRCALPHA)
        pygame.draw.polygon(inner_rim, (0, 0, 0, 255), inner_pts_local)
        rim_surf.blit(inner_rim, (0, 0), special_flags=pygame.BLEND_RGBA_SUB)
        screen.blit(rim_surf, (rim_ox, rim_oy))

        # ── 퍼 터프트: 어깨 가장자리 ──
        # 상단 어깨 부분만 추출 (윤곽의 약 상위 30%)
        n_body = len(body_pts)
        shoulder_count = n_body // 3
        shoulder_pts = body_pts[:shoulder_count] + body_pts[-(shoulder_count):]
        _draw_fur_tufts(screen, shoulder_pts, p["fur_light"],
                        int(0.35 * b), spacing=2, seed_offset=self.time * 0.3)

        # ── 배 (서양배 내부 타원 → 유기적 폴리곤) ──
        belly_hw_top = int(1.8 * b)
        belly_hw_bot = int(2.4 * b)
        belly_h = int(3.5 * b)
        belly_top = body_top + int(1.0 * b)

        belly_pts = _pear_polygon(bcx, belly_top, belly_hw_top, belly_hw_bot, belly_h, steps=8)
        # 배 그림자
        belly_shadow_pts = [(x, y + 1) for x, y in belly_pts]
        pygame.draw.polygon(screen, p["belly_shadow"], belly_shadow_pts)
        # 배 베이스
        pygame.draw.polygon(screen, p["belly"], belly_pts)
        # 배 하이라이트
        belly_hl = _pear_polygon(bcx - int(0.3 * b), belly_top + int(0.3 * b),
                                  int(belly_hw_top * 0.45), int(belly_hw_bot * 0.35),
                                  int(belly_h * 0.4), steps=5)
        pygame.draw.polygon(screen, p["belly_light"], belly_hl)

        # 배꼽 하트
        heart_cx = bcx
        heart_cy = belly_top + int(belly_h * 0.55)
        hr = max(3, int(0.7 * b))
        glow_sz = hr * 4
        glow_surf = self._get_surface(glow_sz, glow_sz)
        pulse = (_sin(self.time * 1.5) + 1) * 0.5
        glow_alpha = int(25 + 20 * pulse)
        pygame.draw.circle(glow_surf, (*p["pink_glow"][:3], glow_alpha),
                          (glow_sz // 2, glow_sz // 2), hr * 2)
        screen.blit(glow_surf, (heart_cx - glow_sz // 2, heart_cy - glow_sz // 2),
                   special_flags=pygame.BLEND_ADD)

        pygame.draw.circle(screen, p["pink_dark"], (heart_cx - hr // 2, heart_cy - hr // 3), hr // 2 + 1)
        pygame.draw.circle(screen, p["pink_dark"], (heart_cx + hr // 2, heart_cy - hr // 3), hr // 2 + 1)
        pygame.draw.circle(screen, p["pink"], (heart_cx - hr // 2, heart_cy - hr // 3), hr // 2)
        pygame.draw.circle(screen, p["pink"], (heart_cx + hr // 2, heart_cy - hr // 3), hr // 2)
        pygame.draw.polygon(screen, p["pink"], [
            (heart_cx - hr, heart_cy - hr // 4),
            (heart_cx + hr, heart_cy - hr // 4),
            (heart_cx, heart_cy + hr)
        ])
        pygame.draw.circle(screen, p["pink_light"],
                          (heart_cx - hr // 3, heart_cy - hr // 2), max(1, hr // 4))

    # ──────────────────────── 팔 (테이퍼드 폴리곤) ────────────────────────

    def _draw_arm(self, screen, cx, torso_y, b, p, is_back, roll):
        arm_h = int(4.0 * b)
        side = -1 if is_back else 1

        shoulder_x = cx + int(side * 3.8 * b) + int(roll * 0.3 * side)
        shoulder_y = torso_y

        swing_angle = self.arm_swing * (-1 if is_back else 1)

        # ── 반격 애니메이션: 타격 팔 오버라이드 ──
        # 앞쪽 팔(is_back=False)이 counter_dir 쪽이면 타격 팔
        is_strike_arm = (not is_back and side == self.counter_dir)
        if self.is_countering and is_strike_arm:
            swing_angle = self._ct_arm_angle
            arm_h = int(4.0 * b * self._ct_arm_stretch)
            # 어깨를 약간 앞으로 내밀기
            shoulder_x += int(self._ct_body_lean * b * 0.3)

        end_x = shoulder_x + int(_sin(swing_angle) * arm_h)
        end_y = shoulder_y + int(_cos(swing_angle) * arm_h)

        # 테이퍼드 폴리곤 — 어깨 좁고 → 손 넓음
        hw_shoulder = int(0.9 * b)   # 어깨 (좁음)
        hw_paw = int(1.5 * b)       # 손바닥 (넓음)

        # 타격 순간: 팔을 길고 얇게 (속도감)
        if self.is_countering and is_strike_arm and self._ct_arm_stretch > 1.05:
            hw_shoulder = int(0.7 * b)
            hw_paw = int(1.2 * b)

        # 팔 방향 벡터 계산
        dx = end_x - shoulder_x
        dy = end_y - shoulder_y
        length = max(1.0, (dx * dx + dy * dy) ** 0.5)
        # 수직 벡터 (팔 폭 방향)
        nx = -dy / length
        ny = dx / length

        # 팔 폴리곤 — 어깨에서 손까지 테이퍼
        steps = 6
        left_side = []
        right_side = []
        for i in range(steps + 1):
            t = i / steps
            px = shoulder_x + int(dx * t)
            py = shoulder_y + int(dy * t)
            # 큐빅 이징으로 폭 변화
            ease = t * t * (3 - 2 * t)
            hw = hw_shoulder + (hw_paw - hw_shoulder) * ease
            left_side.append((int(px - nx * hw), int(py - ny * hw)))
            right_side.append((int(px + nx * hw), int(py + ny * hw)))

        arm_pts = left_side + list(reversed(right_side))

        # ── 앰비언트 오클루전: 어깨 접합부 ──
        _draw_ao_shadow(screen, shoulder_x, shoulder_y + int(0.3 * b),
                        int(1.2 * b), int(0.5 * b), alpha=45)

        # 그림자
        shadow_arm = [(x + 1, y + 1) for x, y in arm_pts]
        pygame.draw.polygon(screen, p["fur_shadow"], shadow_arm)

        # 다크 레이어
        pygame.draw.polygon(screen, p["fur_dark"], arm_pts)

        # 베이스 (약간 축소)
        inner_left = []
        inner_right = []
        for i in range(steps + 1):
            t = i / steps
            px = shoulder_x + int(dx * t)
            py = shoulder_y + int(dy * t) + int(0.15 * b)
            ease = t * t * (3 - 2 * t)
            hw = (hw_shoulder + (hw_paw - hw_shoulder) * ease) * 0.82
            inner_left.append((int(px - nx * hw), int(py - ny * hw)))
            inner_right.append((int(px + nx * hw), int(py + ny * hw)))
        inner_pts = inner_left + list(reversed(inner_right))
        pygame.draw.polygon(screen, p["fur"], inner_pts)

        # 하이라이트 (상단 가는 스트라이프)
        hl_left = []
        hl_right = []
        hl_x_bias = int(-0.2 * b) if side < 0 else int(0.2 * b)
        for i in range(steps + 1):
            t = i / steps
            if t > 0.5:
                break
            px = shoulder_x + int(dx * t) + hl_x_bias
            py = shoulder_y + int(dy * t) - int(0.3 * b)
            ease = t * t * (3 - 2 * t)
            hw = (hw_shoulder + (hw_paw - hw_shoulder) * ease) * 0.35
            hl_left.append((int(px - nx * hw), int(py - ny * hw)))
            hl_right.append((int(px + nx * hw), int(py + ny * hw)))
        if len(hl_left) >= 2:
            hl_pts = hl_left + list(reversed(hl_right))
            pygame.draw.polygon(screen, p["fur_light"], hl_pts)

        # 손바닥 패드
        pad_r = max(2, int(0.45 * b))
        pygame.draw.circle(screen, p["pad_dark"], (end_x, end_y), pad_r + 1)
        pygame.draw.circle(screen, p["pad"], (end_x, end_y), pad_r)
        pygame.draw.circle(screen, p["belly_light"], (end_x - 1, end_y - 1), max(1, pad_r // 2))

    # ──────────────────────── 머리 ────────────────────────

    def _draw_head(self, screen, cx, torso_y, b, p, fd, roll):
        head_r = int(3.8 * b)
        head_cx = cx + int(roll * 0.3)
        head_cy = torso_y - int(3.0 * b)

        # ★ 얼굴 중심축만 이동 (내부 요소 변형 없음)
        face_shift = int(fd * 0.6 * b)

        # ── 앰비언트 오클루전: 머리-몸통 접합부 ──
        _draw_ao_shadow(screen, head_cx, head_cy + head_r - int(0.3 * b),
                        int(2.5 * b), int(0.7 * b), alpha=50)

        # 머리 그림자
        pygame.draw.circle(screen, p["fur_shadow"], (head_cx + 2, head_cy + 2), head_r + 2)

        # 귀
        ear_bounce = self.ear_bounce * _SSAA
        for side in [-1, 1]:
            ear_cx = head_cx + int(side * 2.7 * b) + int(face_shift * 0.3)
            ear_cy = head_cy - int(2.5 * b) - int(ear_bounce * (0.5 if side == -1 else 0.3))
            ear_r = int(1.5 * b)

            pygame.draw.circle(screen, p["fur_shadow"], (ear_cx + 1, ear_cy + 1), ear_r + 2)
            pygame.draw.circle(screen, p["fur_dark"], (ear_cx, ear_cy), ear_r + 1)
            pygame.draw.circle(screen, p["fur"], (ear_cx, ear_cy), ear_r)
            pygame.draw.circle(screen, p["fur_light"],
                              (ear_cx - int(0.2 * b * side), ear_cy - int(0.2 * b)),
                              int(ear_r * 0.7))
            inner_r = int(ear_r * 0.6)
            pygame.draw.circle(screen, p["pink_dark"], (ear_cx, ear_cy + int(0.1 * b)), inner_r + 1)
            pygame.draw.circle(screen, p["pink"], (ear_cx, ear_cy + int(0.1 * b)), inner_r)
            pygame.draw.circle(screen, p["pink_light"],
                              (ear_cx - int(0.1 * b * side), ear_cy),
                              max(1, int(inner_r * 0.5)))

            # ── 퍼 터프트: 귀 꼭대기 ──
            tuft_pts = [
                (ear_cx - int(0.4 * b), ear_cy - ear_r),
                (ear_cx, ear_cy - ear_r - int(0.3 * b)),
                (ear_cx + int(0.4 * b), ear_cy - ear_r),
            ]
            pygame.draw.polygon(screen, p["fur_light"], tuft_pts)

        # 머리 베이스
        pygame.draw.circle(screen, p["fur"], (head_cx, head_cy), head_r)

        # 머리 하단 음영
        pygame.draw.ellipse(screen, p["fur_dark"],
                            (head_cx - head_r, head_cy + int(0.5 * b), head_r * 2, int(2.0 * b)))

        # 머리 밝은 영역 (이마~상단만, 눈 영역 침범 방지)
        pygame.draw.circle(screen, p["fur_light"],
                          (head_cx, head_cy - int(1.0 * b)), int(head_r * 0.55))

        # 머리 하이라이트
        pygame.draw.circle(screen, p["fur_lighter"],
                          (head_cx - int(0.8 * b), head_cy - int(1.3 * b)), int(head_r * 0.3))

        # 이마 글로시
        gw = int(2.5 * b)
        gh = int(1.2 * b)
        gloss_surf = self._get_surface(gw, gh)
        pygame.draw.ellipse(gloss_surf, (255, 255, 255, 25), (0, 0, gw, gh))
        screen.blit(gloss_surf, (head_cx - gw // 2, head_cy - int(2.2 * b)))

        # ★ 림 라이트 (머리 가장자리)
        rim_sz = head_r * 2 + 6
        rim_surf = self._get_surface(rim_sz, rim_sz)
        pygame.draw.circle(rim_surf, (*p["fur_rim"], 35),
                          (rim_sz // 2, rim_sz // 2), head_r + 2)
        # 안쪽 투명으로 파기
        inner_r_rim = head_r - int(0.3 * b)
        inner_rim = pygame.Surface((inner_r_rim * 2, inner_r_rim * 2), pygame.SRCALPHA)
        inner_rim.fill((0, 0, 0, 0))
        pygame.draw.circle(inner_rim, (0, 0, 0, 255),
                          (inner_r_rim, inner_r_rim), inner_r_rim)
        rim_surf.blit(inner_rim, (rim_sz // 2 - inner_r_rim, rim_sz // 2 - inner_r_rim),
                      special_flags=pygame.BLEND_RGBA_SUB)
        screen.blit(rim_surf, (head_cx - rim_sz // 2, head_cy - rim_sz // 2))

        # ── 퍼 터프트: 머리 꼭대기 (크라운) ──
        crown_tufts = 5
        for i in range(crown_tufts):
            angle = -_pi * 0.8 + (_pi * 0.6) * i / (crown_tufts - 1)
            base_x = head_cx + int(_cos(angle) * head_r * 0.95)
            base_y = head_cy + int(_sin(angle) * head_r * 0.95)
            tip_x = head_cx + int(_cos(angle) * (head_r + int(0.4 * b)))
            tip_y = head_cy + int(_sin(angle) * (head_r + int(0.4 * b)))
            # 삼각형 양쪽 꼭짓점
            perp_angle = angle + _pi / 2
            half_w = int(0.25 * b)
            lx = base_x + int(_cos(perp_angle) * half_w)
            ly = base_y + int(_sin(perp_angle) * half_w)
            rx = base_x - int(_cos(perp_angle) * half_w)
            ry = base_y - int(_sin(perp_angle) * half_w)
            # 약간의 시간 변동으로 살아있는 느낌
            vary = 0.7 + 0.3 * abs(_sin(i * 2.1 + self.time * 0.5))
            final_tip_x = int(base_x + (tip_x - base_x) * vary)
            final_tip_y = int(base_y + (tip_y - base_y) * vary)
            pygame.draw.polygon(screen, p["fur_light"],
                               [(lx, ly), (final_tip_x, final_tip_y), (rx, ry)])

        # ── 퍼 터프트: 뺨 양옆 ──
        for side in [-1, 1]:
            cheek_angle = _pi * 0.1 * side  # 약간 아래쪽 옆
            for j in range(3):
                a = cheek_angle + (j - 1) * 0.15
                base_x = head_cx + int(_cos(a) * head_r * 0.92) + int(side * 0.2 * b)
                base_y = head_cy + int(_sin(a) * head_r * 0.92) + int(0.5 * b)
                tip_x = base_x + int(side * 0.3 * b)
                tip_y = base_y + int((j - 1) * 0.15 * b)
                hw = int(0.15 * b)
                pygame.draw.polygon(screen, p["fur"],
                                   [(base_x, base_y - hw),
                                    (tip_x, tip_y),
                                    (base_x, base_y + hw)])

        # === 얼굴 (face_cx만 이동, 내부 요소는 고정 형태) ===
        face_cx = head_cx + face_shift
        face_cy = head_cy + int(0.3 * b)

        # ★ 눈 — 큰 하트 모양 (얀데레 핑크 하트)
        for side in [-1, 1]:
            eye_cx = face_cx + int(side * 1.3 * b)
            eye_cy = face_cy - int(0.3 * b)

            hr = max(3, int(1.1 * b))  # 하트 반지름 (눈 전체 크기)

            # 하트 글로우 (배경 빛남)
            glow_r = int(hr * 2.2)
            glow_surf = self._get_surface(glow_r * 2, glow_r * 2)
            pulse = (_sin(self.time * 2.5) + 1) * 0.5
            glow_alpha = int(40 + 35 * pulse)
            pygame.draw.circle(glow_surf, (*p["pink_glow"][:3], glow_alpha),
                              (glow_r, glow_r), glow_r)
            screen.blit(glow_surf, (eye_cx - glow_r, eye_cy - glow_r),
                       special_flags=pygame.BLEND_ADD)

            # 하트 그림자 (약간 오프셋)
            lobe_r = int(hr * 0.55)
            sh_off = max(1, int(0.08 * b))
            pygame.draw.circle(screen, p["fur_shadow"],
                              (eye_cx - lobe_r + sh_off, eye_cy - int(hr * 0.15) + sh_off), lobe_r + 1)
            pygame.draw.circle(screen, p["fur_shadow"],
                              (eye_cx + lobe_r + sh_off, eye_cy - int(hr * 0.15) + sh_off), lobe_r + 1)
            pygame.draw.polygon(screen, p["fur_shadow"], [
                (eye_cx - hr + sh_off, eye_cy - int(hr * 0.05) + sh_off),
                (eye_cx + hr + sh_off, eye_cy - int(hr * 0.05) + sh_off),
                (eye_cx + sh_off, eye_cy + int(hr * 1.15) + sh_off)
            ])

            # 하트 다크 아웃라인
            outline = max(1, int(0.1 * b))
            pygame.draw.circle(screen, p["pink_dark"],
                              (eye_cx - lobe_r, eye_cy - int(hr * 0.15)), lobe_r + outline)
            pygame.draw.circle(screen, p["pink_dark"],
                              (eye_cx + lobe_r, eye_cy - int(hr * 0.15)), lobe_r + outline)
            pygame.draw.polygon(screen, p["pink_dark"], [
                (eye_cx - hr - outline, eye_cy - int(hr * 0.05)),
                (eye_cx + hr + outline, eye_cy - int(hr * 0.05)),
                (eye_cx, eye_cy + int(hr * 1.15) + outline)
            ])

            # 하트 본체 (원 2개 + 역삼각형)
            pygame.draw.circle(screen, p["pink"],
                              (eye_cx - lobe_r, eye_cy - int(hr * 0.15)), lobe_r)
            pygame.draw.circle(screen, p["pink"],
                              (eye_cx + lobe_r, eye_cy - int(hr * 0.15)), lobe_r)
            pygame.draw.polygon(screen, p["pink"], [
                (eye_cx - hr, eye_cy - int(hr * 0.05)),
                (eye_cx + hr, eye_cy - int(hr * 0.05)),
                (eye_cx, eye_cy + int(hr * 1.15))
            ])

            # 하트 밝은 레이어 (내부 상단)
            inner_lobe = int(lobe_r * 0.7)
            pygame.draw.circle(screen, p["pink_light"],
                              (eye_cx - lobe_r, eye_cy - int(hr * 0.3)), inner_lobe)
            pygame.draw.circle(screen, p["pink_light"],
                              (eye_cx + lobe_r, eye_cy - int(hr * 0.3)), inner_lobe)

            # 하이라이트 반짝 (좌상단)
            hl_r = max(1, int(hr * 0.22))
            pygame.draw.circle(screen, (255, 230, 240),
                              (eye_cx - int(hr * 0.4), eye_cy - int(hr * 0.4)), hl_r)

        # 코 (오밀조밀)
        nose_cx = face_cx
        nose_cy = face_cy + int(0.9 * b)
        nose_w = int(0.7 * b)
        nose_h = int(0.5 * b)
        pygame.draw.ellipse(screen, p["nose_dark"],
                            (nose_cx - nose_w // 2 + 1, nose_cy + 1, nose_w + 2, nose_h + 2))
        pygame.draw.ellipse(screen, p["nose_mid"],
                            (nose_cx - nose_w // 2, nose_cy, nose_w, nose_h))
        pygame.draw.ellipse(screen, p["nose_highlight"],
                            (nose_cx - nose_w // 4, nose_cy, nose_w // 2, int(nose_h * 0.5)))
        pygame.draw.circle(screen, (150, 120, 95),
                          (nose_cx - int(0.08 * b), nose_cy + int(0.08 * b)),
                          max(1, int(0.1 * b)))

        # 입 (W자, 코에 붙어서 오밀조밀)
        mouth_y = nose_cy + int(0.4 * b)
        mouth_w = int(0.9 * b)
        pygame.draw.arc(screen, p["mouth"],
                       (face_cx - mouth_w, mouth_y, mouth_w, int(0.4 * b)),
                       _pi, _tau, max(1, int(0.1 * b)))
        pygame.draw.arc(screen, p["mouth"],
                       (face_cx, mouth_y, mouth_w, int(0.4 * b)),
                       _pi, _tau, max(1, int(0.1 * b)))

        # ★ 볼 홍조 — 5단계 그라데이션
        for side in [-1, 1]:
            blush_cx = face_cx + int(side * 2.0 * b)
            blush_cy = face_cy + int(0.6 * b)
            blush_rx = int(1.1 * b)
            blush_ry = int(0.6 * b)
            blush_surf = self._get_surface(blush_rx * 2 + 4, blush_ry * 2 + 4)

            for layer in range(5):
                alpha = max(0, 55 - layer * 11)
                rx = max(2, blush_rx - layer * int(0.1 * b))
                ry = max(1, blush_ry - layer * int(0.05 * b))
                pygame.draw.ellipse(blush_surf, (255, 150, 170, alpha),
                                    (blush_rx + 2 - rx, blush_ry + 2 - ry, rx * 2, ry * 2))

            screen.blit(blush_surf, (blush_cx - blush_rx - 2, blush_cy - blush_ry - 2))

        # 리본
        ribbon_side = -1 if fd > 0.3 else 1
        self._draw_ribbon(screen, head_cx, head_cy, b, p, face_shift, ribbon_side)

    # ──────────────────────── 리본 ────────────────────────

    def _draw_ribbon(self, screen, head_cx, head_cy, b, p, face_shift, ribbon_side):
        ribbon_cx = head_cx + int(ribbon_side * 2.2 * b) + int(face_shift * 0.2)
        ribbon_cy = head_cy - int(2.8 * b)
        flutter = self.ribbon_flutter * _SSAA

        bow_w = int(1.4 * b)
        bow_h = int(0.9 * b)

        left_pts = [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx - bow_w + int(flutter * 0.3), ribbon_cy - bow_h),
            (ribbon_cx - int(bow_w * 0.3), ribbon_cy),
            (ribbon_cx - bow_w - int(flutter * 0.2), ribbon_cy + bow_h),
        ]
        right_pts = [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx + bow_w - int(flutter * 0.2), ribbon_cy - bow_h + int(flutter * 0.15)),
            (ribbon_cx + int(bow_w * 0.3), ribbon_cy),
            (ribbon_cx + bow_w + int(flutter * 0.3), ribbon_cy + bow_h - int(flutter * 0.1)),
        ]

        for pts in [left_pts, right_pts]:
            shadow = [(x + 2, y + 2) for x, y in pts]
            pygame.draw.polygon(screen, p["pink_dark"], shadow)
            pygame.draw.polygon(screen, p["pink"], pts)

        # 하이라이트
        for sign in [-1, 1]:
            hl = [
                (ribbon_cx, ribbon_cy),
                (ribbon_cx + int(sign * bow_w * 0.6), ribbon_cy - int(bow_h * 0.6)),
                (ribbon_cx + int(sign * bow_w * 0.2), ribbon_cy),
            ]
            pygame.draw.polygon(screen, p["pink_light"], hl)

        knot_r = max(2, int(0.3 * b))
        pygame.draw.circle(screen, p["pink_dark"], (ribbon_cx, ribbon_cy), knot_r + 1)
        pygame.draw.circle(screen, p["pink"], (ribbon_cx, ribbon_cy), knot_r)
        pygame.draw.circle(screen, p["pink_light"], (ribbon_cx - 1, ribbon_cy - 1), max(1, knot_r // 2))

        tail_len = int(1.5 * b)
        tail_f = int(_sin(self.time * 1.5) * 0.3 * b)
        for s, sx_off in [(-1, -int(0.15 * b)), (1, int(0.15 * b))]:
            tx = ribbon_cx + sx_off
            pts = [
                (tx, ribbon_cy + knot_r),
                (tx + int(s * 0.3 * b) + tail_f, ribbon_cy + knot_r + tail_len),
                (tx + int(s * 0.15 * b), ribbon_cy + knot_r + int(tail_len * 0.7)),
            ]
            pygame.draw.polygon(screen, p["pink"], pts)
            pygame.draw.line(screen, p["pink_light"], pts[0], pts[2], max(1, int(0.06 * b)))

    # ──────────────────────── 유틸리티 ────────────────────────

    def create_static_image(self, w=160, h=80):
        surf = pygame.Surface((w, h), pygame.SRCALPHA)
        self.draw(surf, 0, 0, w, h)
        return surf


_teddy_sprite_instance = None


def get_teddy_bear_sprite():
    global _teddy_sprite_instance
    if _teddy_sprite_instance is None:
        _teddy_sprite_instance = TeddyBearBossSprite()
    return _teddy_sprite_instance
