"""
Teddy Bear Boss Sprite v8 — Dark Realistic Plush Teddy Bear

- 3D 부피감: 노멀맵 유사 구면 음영 + 좌상단 광원(-1,-1,1) + 강화된 림 라이트
- 퍼(Fur) 질감: 노이즈 텍스처 합성 + 가장자리 퍼즈(fuzz) 실루엣
- 멘헤라/호러 디테일:
  · 터진 솔기(Burst Seam) — 어깨/옆구리에서 솜 삐져나옴
  · 짝짝이 눈 — 왼쪽 얀데레 하트, 오른쪽 단추 떨어져 실밥+덜렁거림
  · 안전핀 — 왼쪽 귀에 거대한 안전핀
  · 붕대 — 오른팔에 감긴 붕대
- 이동 시 기괴한 파르르 떨림(Jitter) 애니메이션
- 서피스 캐싱 최적화 (노이즈/퍼즈 텍스처 사전 생성)
- 3x SSAA 슈퍼샘플링
"""

import pygame
import math
import random

_sin = math.sin
_cos = math.cos
_pi = math.pi
_tau = math.pi * 2
_sqrt = math.sqrt

# SSAA 배율
_SSAA = 3

# 광원 방향 (정규화: 왼쪽 위에서 비춤)
_LIGHT_DIR = (-0.577, -0.577, 0.577)  # normalize(-1, -1, 1)


class TeddyBearBossSprite:
    """리얼리스틱 봉제 곰인형 보스 스프라이트 v8 (3x SSAA + 호러 디테일)"""

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

        # 히트 스윙 애니메이션 (공 칠 때 팔 휘두르기)
        self.hit_swing_active = False
        self.hit_swing_timer = 0.0
        self.hit_swing_duration = 0.35  # 0.35초 동안 스윙
        self.hit_swing_direction = 1  # 1=오른팔, -1=왼팔 (공 방향에 따라)
        self.hit_swing_phase = 0.0  # 0~1 스윙 진행도

        # v8: 호러 떨림(Jitter) 상태
        self.jitter_x = 0.0
        self.jitter_y = 0.0
        self.jitter_intensity = 0.0

        # v8: 오른쪽 눈 덜렁거림 (단추가 실에 매달려 흔들림)
        self.dangling_eye_angle = 0.0
        self.dangling_eye_vel = 0.0

        # 서피스 캐시
        self._surface_cache = {}
        self._ssaa_cache_key = None
        self._ssaa_cache_surf = None

        # v8: 노이즈/퍼즈 텍스처 캐시
        self._noise_cache = {}  # key: (w, h, seed) → Surface
        self._fuzz_cache = {}   # key: (rx, ry, seed) → Surface
        self._noise_seed = random.randint(0, 99999)

    def _get_surface(self, w, h):
        w = max(4, ((w + 3) // 4) * 4)
        h = max(4, ((h + 3) // 4) * 4)
        key = (w, h)
        if key not in self._surface_cache:
            self._surface_cache[key] = pygame.Surface((w, h), pygame.SRCALPHA)
        else:
            self._surface_cache[key].fill((0, 0, 0, 0))
        return self._surface_cache[key]

    # ═══════════════════════ v8: 노이즈 텍스처 생성 (캐시) ═══════════════════════

    def _get_noise_texture(self, w, h, base_color, intensity=15, seed=0):
        """퍼 질감 노이즈 텍스처 (캐시됨)"""
        w = max(4, ((w + 3) // 4) * 4)
        h = max(4, ((h + 3) // 4) * 4)
        cache_key = (w, h, base_color, intensity, seed)
        if cache_key in self._noise_cache:
            return self._noise_cache[cache_key]

        surf = pygame.Surface((w, h), pygame.SRCALPHA)
        rng = random.Random(seed + self._noise_seed)
        step = max(2, _SSAA)
        for ny in range(0, h, step):
            for nx in range(0, w, step):
                noise_val = rng.randint(-intensity, intensity)
                r = max(0, min(255, base_color[0] + noise_val))
                g = max(0, min(255, base_color[1] + noise_val))
                b_c = max(0, min(255, base_color[2] + noise_val))
                alpha = rng.randint(20, 50)
                pygame.draw.rect(surf, (r, g, b_c, alpha), (nx, ny, step, step))

        self._noise_cache[cache_key] = surf
        return surf

    def _get_fuzz_edge(self, rx, ry, color, seed=0):
        """가장자리 퍼즈(삐져나온 털) 텍스처 (캐시됨)"""
        cache_key = (rx, ry, color, seed)
        if cache_key in self._fuzz_cache:
            return self._fuzz_cache[cache_key]

        w = rx * 2 + 16
        h = ry * 2 + 16
        surf = pygame.Surface((w, h), pygame.SRCALPHA)
        cx_l, cy_l = w // 2, h // 2
        rng = random.Random(seed + self._noise_seed + 777)
        num_fuzz = max(16, int((rx + ry) * 0.4))
        for i in range(num_fuzz):
            angle = rng.uniform(0, _tau)
            # 타원 위 좌표
            ex = rx * _cos(angle)
            ey = ry * _sin(angle)
            # 바깥으로 삐져나오는 길이
            fuzz_len = rng.uniform(1.5, 4.5)
            dx = _cos(angle) * fuzz_len
            dy = _sin(angle) * fuzz_len
            sx = cx_l + int(ex)
            sy = cy_l + int(ey)
            fx = sx + int(dx)
            fy = sy + int(dy)
            alpha = rng.randint(40, 90)
            pygame.draw.line(surf, (*color[:3], alpha), (sx, sy), (fx, fy), 1)

        self._fuzz_cache[cache_key] = surf
        return surf

    # ═══════════════════════ v8: 구면 음영 계산 ═══════════════════════

    @staticmethod
    def _sphere_shade(nx, ny, nz=None):
        """노멀 벡터 기반 음영 계산 (0.0~1.0), 광원: 좌상단"""
        if nz is None:
            r_sq = nx * nx + ny * ny
            if r_sq >= 1.0:
                return 0.0
            nz = _sqrt(1.0 - r_sq)
        lx, ly, lz = _LIGHT_DIR
        dot = nx * lx + ny * ly + nz * lz
        return max(0.0, min(1.0, dot * 0.5 + 0.5))

    @staticmethod
    def _rim_light(nx, ny):
        """림 라이트 강도 (가장자리에서 강함)"""
        r_sq = nx * nx + ny * ny
        if r_sq >= 1.0:
            return 1.0
        rim = 1.0 - _sqrt(1.0 - r_sq)
        return rim * rim  # 제곱으로 가장자리 집중

    def _draw_shaded_ellipse(self, screen, rect, base_color, dark_color, light_color,
                             rim_color=None, rim_alpha=45, noise=True):
        """구면 음영이 적용된 타원 렌더링"""
        x, y, w, h = rect
        if w < 4 or h < 4:
            pygame.draw.ellipse(screen, base_color, rect)
            return

        # 기본 타원 레이어링 (기존 방식 + 향상)
        # 깊은 그림자
        pygame.draw.ellipse(screen, dark_color,
                            (x + 2, y + 2, w, h))
        # 베이스
        pygame.draw.ellipse(screen, base_color, (x, y, w, h))

        # 구면 음영 그라데이션 (3단계 타원 겹침)
        cx_e = x + w // 2
        cy_e = y + h // 2

        # 좌상단 밝은 영역 (광원 쪽)
        hl_w = int(w * 0.55)
        hl_h = int(h * 0.50)
        hl_x = cx_e - int(hl_w * 0.65)
        hl_y = cy_e - int(hl_h * 0.65)
        pygame.draw.ellipse(screen, light_color, (hl_x, hl_y, hl_w, hl_h))

        # 우하단 어두운 영역 (광원 반대)
        sh_w = int(w * 0.5)
        sh_h = int(h * 0.45)
        sh_x = cx_e + int(w * 0.05)
        sh_y = cy_e + int(h * 0.08)
        shade_surf = self._get_surface(sh_w + 4, sh_h + 4)
        pygame.draw.ellipse(shade_surf, (*dark_color[:3], 60),
                            (2, 2, sh_w, sh_h))
        screen.blit(shade_surf, (sh_x, sh_y))

        # 노이즈 텍스처 오버레이
        if noise and w > 8 and h > 8:
            noise_surf = self._get_noise_texture(w, h, base_color, intensity=12, seed=hash((x, y)) & 0xFFFF)
            # 타원 마스크 적용
            mask_surf = self._get_surface(w, h)
            pygame.draw.ellipse(mask_surf, (255, 255, 255, 255), (0, 0, w, h))
            noise_clipped = self._get_surface(w, h)
            noise_clipped.blit(noise_surf, (0, 0))
            noise_clipped.blit(mask_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
            screen.blit(noise_clipped, (x, y))

        # 림 라이트
        if rim_color:
            rim_w = w + 6
            rim_h = h + 6
            rim_surf = self._get_surface(rim_w, rim_h)
            pygame.draw.ellipse(rim_surf, (*rim_color[:3], rim_alpha),
                                (0, 0, rim_w, rim_h))
            inner_w = w - max(2, int(w * 0.08))
            inner_h = h - max(2, int(h * 0.08))
            if inner_w > 2 and inner_h > 2:
                inner_rim = pygame.Surface((inner_w, inner_h), pygame.SRCALPHA)
                inner_rim.fill((0, 0, 0, 255))
                rim_surf.blit(inner_rim, (3 + (w - inner_w) // 2, 3 + (h - inner_h) // 2),
                              special_flags=pygame.BLEND_RGBA_SUB)
            screen.blit(rim_surf, (x - 3, y - 3))

    def update(self, boss_x, dt=1 / 60):
        """보스 위치 기반 애니메이션 업데이트"""
        self.time += dt

        if self.prev_x is not None:
            dx = boss_x - self.prev_x
            self.velocity = self.velocity * 0.75 + dx * 0.25
        self.prev_x = boss_x

        speed = abs(self.velocity)
        moving = speed > 0.3
        speed_ratio = min(1.0, speed / 10.0)

        if moving:
            self.move_dir = 1 if self.velocity > 0 else -1
            step_delta = (0.018 + speed_ratio * 0.035) * _tau
            self.step_phase = (self.step_phase + step_delta) % _tau
        else:
            self.step_phase *= 0.94
            if abs(self.step_phase) < 0.01:
                self.step_phase = 0.0

        self.lean = 0.0
        self.lean_velocity = 0.0

        if moving:
            self.body_roll = _sin(self.step_phase) * 2.0 * speed_ratio
        else:
            self.body_roll *= 0.92

        if moving:
            self.body_bob = _sin(self.step_phase) * 2.0 * speed_ratio
        else:
            self.body_bob = _sin(self.time * 0.8) * 0.4

        if moving:
            self.arm_swing = _sin(self.step_phase) * 0.40 * speed_ratio
        else:
            self.arm_swing = _sin(self.time * 0.6) * 0.03

        self.head_tilt = 0.0

        if moving:
            self.ear_bounce = abs(_sin(self.step_phase)) * 2.0 * speed_ratio
        else:
            self.ear_bounce = _sin(self.time * 1.0) * 0.3

        self.ribbon_flutter = _sin(self.time * 2.0 + self.step_phase) * 4.0

        if moving:
            self.face_dir_target = float(self.move_dir)
        self.face_dir += (self.face_dir_target - self.face_dir) * 0.08

        # v8: 호러 떨림 (이동 시 기괴한 파르르 떨림)
        if moving:
            self.jitter_intensity = min(1.0, self.jitter_intensity + dt * 4.0)
        else:
            self.jitter_intensity *= 0.92
            if self.jitter_intensity < 0.01:
                self.jitter_intensity = 0.0

        if self.jitter_intensity > 0.01:
            freq = 18.0 + speed_ratio * 12.0
            amp = 0.6 * self.jitter_intensity
            self.jitter_x = _sin(self.time * freq) * amp + _sin(self.time * freq * 2.3) * amp * 0.4
            self.jitter_y = _cos(self.time * freq * 1.7) * amp * 0.5 + _sin(self.time * freq * 3.1) * amp * 0.2
        else:
            self.jitter_x = 0.0
            self.jitter_y = 0.0

        # v8: 덜렁거리는 오른쪽 눈 물리
        gravity_torque = _sin(self.dangling_eye_angle) * -15.0
        swing_force = self.velocity * 2.0
        self.dangling_eye_vel += (gravity_torque + swing_force) * dt
        self.dangling_eye_vel *= 0.94  # 감쇠
        self.dangling_eye_angle += self.dangling_eye_vel * dt
        self.dangling_eye_angle = max(-0.6, min(0.6, self.dangling_eye_angle))

        # 히트 스윙 애니메이션 업데이트
        if self.hit_swing_active:
            self.hit_swing_timer += dt
            t = self.hit_swing_timer / self.hit_swing_duration
            if t >= 1.0:
                self.hit_swing_active = False
                self.hit_swing_timer = 0.0
                self.hit_swing_phase = 0.0
            else:
                # ease-out 커브: 빠르게 휘두르고 천천히 복귀
                if t < 0.3:
                    # 0~0.3: 빠르게 아래로 휘두르기 (0→1)
                    self.hit_swing_phase = (t / 0.3)
                else:
                    # 0.3~1.0: 천천히 원위치로 복귀 (1→0)
                    self.hit_swing_phase = 1.0 - ((t - 0.3) / 0.7)

    def trigger_hit(self, ball_x, boss_x):
        """공을 칠 때 팔 휘두르기 애니메이션 시작"""
        self.hit_swing_active = True
        self.hit_swing_timer = 0.0
        self.hit_swing_phase = 0.0
        # 공이 보스 기준 어느 쪽에 있는지로 휘두르는 팔 결정
        if ball_x > boss_x:
            self.hit_swing_direction = 1  # 오른팔(앞팔)로 휘두르기
        else:
            self.hit_swing_direction = -1  # 왼팔(뒷팔)로 휘두르기

    def draw(self, screen, x, y, w, h):
        """3x SSAA 렌더링"""
        sw = w * _SSAA
        sh = h * _SSAA

        cache_key = (sw, sh)
        if self._ssaa_cache_key != cache_key:
            self._ssaa_cache_surf = pygame.Surface((sw, sh), pygame.SRCALPHA)
            self._ssaa_cache_key = cache_key
        hi_surf = self._ssaa_cache_surf
        hi_surf.fill((0, 0, 0, 0))

        self._draw_internal(hi_surf, 0, 0, sw, sh)

        lo_surf = pygame.transform.smoothscale(hi_surf, (w, h))
        screen.blit(lo_surf, (x, y))

    # ═══════════════════════ 팔레트 ═══════════════════════

    @staticmethod
    def _palette():
        return {
            # 메인 퍼 (따뜻한 카라멜 브라운)
            "fur_base": (168, 120, 78),
            "fur_mid": (185, 140, 98),
            "fur_light": (210, 175, 135),
            "fur_highlight": (232, 210, 178),
            "fur_dark": (130, 88, 55),
            "fur_shadow": (90, 58, 32),
            "fur_deep": (65, 40, 22),
            "fur_rim": (235, 215, 190),
            # 머즐/배 (크림색 패브릭)
            "cream": (240, 225, 200),
            "cream_light": (250, 242, 228),
            "cream_shadow": (215, 195, 168),
            "cream_dark": (190, 168, 140),
            # 코 (가죽 질감)
            "nose_base": (42, 28, 18),
            "nose_mid": (65, 45, 30),
            "nose_shine": (95, 75, 58),
            "nose_gloss": (140, 120, 100),
            # 눈 (유리 단추)
            "eye_base": (15, 8, 5),
            "eye_ring": (45, 30, 20),
            "eye_shine": (255, 255, 255),
            # 멘헤라 핑크
            "pink": (255, 105, 150),
            "pink_light": (255, 160, 195),
            "pink_dark": (210, 70, 115),
            "pink_deep": (175, 45, 85),
            "pink_glow": (255, 180, 210),
            # 발바닥 패드
            "pad": (195, 155, 125),
            "pad_dark": (160, 120, 88),
            "pad_light": (220, 190, 160),
            # 이음새/스티치
            "stitch": (120, 80, 48),
            "stitch_light": (155, 115, 78),
            # 입
            "mouth": (100, 62, 38),
            # v8: 솜 (터진 솔기에서 나오는 충전재)
            "stuffing": (245, 240, 235),
            "stuffing_shadow": (215, 208, 198),
            # v8: 안전핀
            "pin_metal": (192, 192, 200),
            "pin_shine": (230, 230, 240),
            "pin_dark": (120, 120, 130),
            # v8: 붕대
            "bandage": (235, 225, 210),
            "bandage_shadow": (200, 188, 170),
            "bandage_stain": (210, 185, 170),
            # v8: 실밥 (덜렁거리는 눈)
            "thread": (85, 55, 35),
            "thread_light": (110, 80, 55),
        }

    # ═══════════════════════ 내부 렌더링 ═══════════════════════

    def _draw_internal(self, screen, x, y, w, h):
        cx = x + w // 2
        cy = y + h // 2
        b = min(w, h) / 20.0
        S = _SSAA

        bob_offset = int(self.body_bob * S)
        roll_offset = self.body_roll * S
        fd = self.face_dir

        # v8: 호러 떨림 오프셋
        jx = int(self.jitter_x * S)
        jy = int(self.jitter_y * S)

        p = self._palette()

        torso_y = cy + bob_offset

        self._draw_ground_shadow(screen, cx + jx, torso_y, b)
        self._draw_legs(screen, cx + jx, torso_y + jy, b, p, roll_offset)
        self._draw_body(screen, cx + jx, torso_y + jy, b, p, roll_offset)
        self._draw_arm(screen, cx + jx, torso_y + jy, b, p, is_back=True, roll=roll_offset)
        self._draw_head(screen, cx + jx, torso_y + jy, b, p, fd, roll_offset)
        self._draw_arm(screen, cx + jx, torso_y + jy, b, p, is_back=False, roll=roll_offset)

    # ═══════════════════════ 바닥 그림자 ═══════════════════════

    def _draw_ground_shadow(self, screen, cx, torso_y, b):
        shadow_y = torso_y + int(6.8 * b)
        rx = int(4.2 * b)
        ry = int(0.7 * b)
        surf = self._get_surface(rx * 2 + 8, ry * 2 + 8)
        scx, scy = rx + 4, ry + 4
        for ring in range(6):
            alpha = max(0, 50 - ring * 9)
            r_x = max(3, rx - ring * int(0.28 * b))
            r_y = max(2, ry - ring * int(0.06 * b))
            pygame.draw.ellipse(surf, (15, 8, 4, alpha),
                                (scx - r_x, scy - r_y, r_x * 2, r_y * 2))
        screen.blit(surf, (cx - scx, shadow_y - scy))

    # ═══════════════════════ 다리 ═══════════════════════

    def _draw_legs(self, screen, cx, torso_y, b, p, roll):
        leg_base_y = torso_y + int(2.8 * b)
        leg_w = int(2.6 * b)
        leg_h = int(3.5 * b)
        speed_factor = min(1.0, abs(self.velocity) / 8.0)

        for side in [-1, 1]:
            phase = self.step_phase + (0 if side == -1 else _pi)
            swing_x = _sin(phase) * 1.8 * b * speed_factor
            roll_y = int(roll * 0.3 * side)

            lx = cx + int(side * 2.0 * b) + int(roll * 0.4 * side) + int(swing_x)
            ly = leg_base_y + roll_y

            lift = max(0.0, _sin(phase)) * speed_factor
            ly -= int(lift * 0.8 * b)

            # v8: 구면 음영 적용된 다리
            self._draw_shaded_ellipse(
                screen,
                (lx - leg_w // 2, ly, leg_w, leg_h),
                p["fur_base"], p["fur_shadow"], p["fur_mid"],
                rim_color=p["fur_rim"], rim_alpha=30
            )
            # 추가 하이라이트
            hl_w = int(leg_w * 0.45)
            hl_h = int(leg_h * 0.5)
            pygame.draw.ellipse(screen, p["fur_light"],
                                (lx - int(hl_w * 0.35) - int(0.1 * b * side),
                                 ly + int(0.2 * b),
                                 int(hl_w * 0.7), int(hl_h * 0.45)))

            # 퍼즈 가장자리
            fuzz_surf = self._get_fuzz_edge(leg_w // 2, leg_h // 2, p["fur_base"],
                                            seed=hash(("leg", side)))
            screen.blit(fuzz_surf, (lx - leg_w // 2 - 8, ly - 8))

            # 솔기(seam) — 다리 앞면 중앙 세로선
            seam_x = lx
            seam_top = ly + int(0.3 * b)
            seam_bot = ly + int(leg_h * 0.7)
            seam_w = max(1, int(0.06 * b))
            for seg_y in range(int(seam_top), int(seam_bot), max(2, int(0.25 * b))):
                dash_end = min(seg_y + max(1, int(0.12 * b)), int(seam_bot))
                pygame.draw.line(screen, p["stitch"],
                                 (seam_x, seg_y), (seam_x, dash_end), seam_w)

            # ── 발바닥 패드 (콩 모양) ──
            foot_y = ly + int(leg_h * 0.72)
            foot_w = int(leg_w * 1.1)
            foot_h = int(leg_h * 0.32)

            pygame.draw.ellipse(screen, p["fur_dark"],
                                (lx - foot_w // 2, foot_y, foot_w, foot_h))
            pygame.draw.ellipse(screen, p["fur_base"],
                                (lx - foot_w // 2 + 1, foot_y + 1, foot_w - 2, foot_h - 2))

            # 큰 패드 (중앙)
            main_pad_w = int(foot_w * 0.65)
            main_pad_h = int(foot_h * 0.6)
            pad_cx = lx
            pad_cy = foot_y + int(foot_h * 0.5)
            pygame.draw.ellipse(screen, p["pad_dark"],
                                (pad_cx - main_pad_w // 2 - 1, pad_cy - main_pad_h // 2 - 1,
                                 main_pad_w + 2, main_pad_h + 2))
            pygame.draw.ellipse(screen, p["pad"],
                                (pad_cx - main_pad_w // 2, pad_cy - main_pad_h // 2,
                                 main_pad_w, main_pad_h))
            pygame.draw.ellipse(screen, p["pad_light"],
                                (pad_cx - int(main_pad_w * 0.3), pad_cy - int(main_pad_h * 0.35),
                                 int(main_pad_w * 0.5), int(main_pad_h * 0.4)))

            # 발가락 패드 (3개)
            for ti, tx_off in enumerate([-0.32, 0.0, 0.32]):
                toe_x = lx + int(tx_off * foot_w * 0.7)
                toe_y = foot_y + int(foot_h * 0.12)
                toe_rx = max(2, int(0.28 * b))
                toe_ry = max(2, int(0.22 * b))
                pygame.draw.ellipse(screen, p["pad_dark"],
                                    (toe_x - toe_rx - 1, toe_y - toe_ry - 1,
                                     toe_rx * 2 + 2, toe_ry * 2 + 2))
                pygame.draw.ellipse(screen, p["pad"],
                                    (toe_x - toe_rx, toe_y - toe_ry,
                                     toe_rx * 2, toe_ry * 2))
                pygame.draw.ellipse(screen, p["pad_light"],
                                    (toe_x - int(toe_rx * 0.4), toe_y - int(toe_ry * 0.5),
                                     int(toe_rx * 0.7), int(toe_ry * 0.6)))

    # ═══════════════════════ 몸통 ═══════════════════════

    def _draw_body(self, screen, cx, torso_y, b, p, roll):
        body_w = int(8.0 * b)
        body_h = int(6.0 * b)
        body_top = torso_y - int(1.0 * b)
        roll_x = int(roll * 0.5)
        bcx = cx + roll_x

        # v8: 구면 음영 적용된 몸통
        self._draw_shaded_ellipse(
            screen,
            (bcx - body_w // 2, body_top, body_w, body_h),
            p["fur_base"], p["fur_deep"], p["fur_mid"],
            rim_color=p["fur_rim"], rim_alpha=45
        )

        # 좌우 암부 (롤링 반영한 음영)
        edge_w = int(body_w * 0.22)
        edge_h = int(body_h * 0.75)
        la = max(0.7, min(1.3, 1.0 + roll / _SSAA * 0.02))
        ra = max(0.7, min(1.3, 1.0 - roll / _SSAA * 0.02))
        ld = tuple(max(0, min(255, int(c * la))) for c in p["fur_dark"])
        rd = tuple(max(0, min(255, int(c * ra))) for c in p["fur_dark"])
        pygame.draw.ellipse(screen, ld,
                            (bcx - body_w // 2 - int(0.05 * b), body_top + int(0.6 * b),
                             edge_w, edge_h))
        pygame.draw.ellipse(screen, rd,
                            (bcx + body_w // 2 - edge_w + int(0.05 * b), body_top + int(0.6 * b),
                             edge_w, edge_h))

        # 피크 하이라이트 (광택)
        pk_w = int(body_w * 0.15)
        pk_h = int(body_h * 0.12)
        pygame.draw.ellipse(screen, p["fur_highlight"],
                            (bcx - pk_w // 2 - int(0.6 * b), body_top + int(1.0 * b),
                             pk_w, pk_h))

        # 퍼즈 가장자리
        fuzz_surf = self._get_fuzz_edge(body_w // 2, body_h // 2, p["fur_base"], seed=42)
        screen.blit(fuzz_surf, (bcx - body_w // 2 - 8, body_top - 8))

        # ── 배 (크림색 패브릭 패치 — 타원형) ──
        belly_w = int(4.8 * b)
        belly_h = int(3.8 * b)
        belly_top = body_top + int(1.2 * b)
        belly_cx = bcx

        # 배 음영
        pygame.draw.ellipse(screen, p["cream_dark"],
                            (belly_cx - belly_w // 2 + 1, belly_top + 2,
                             belly_w, belly_h))
        pygame.draw.ellipse(screen, p["cream"],
                            (belly_cx - belly_w // 2, belly_top, belly_w, belly_h))
        pygame.draw.ellipse(screen, p["cream_light"],
                            (belly_cx - int(belly_w * 0.3) - int(0.2 * b),
                             belly_top + int(0.3 * b),
                             int(belly_w * 0.5), int(belly_h * 0.45)))

        # 배-몸통 경계 스티치 (점선 타원)
        self._draw_stitch_ellipse(screen, belly_cx, belly_top + belly_h // 2,
                                  belly_w // 2, belly_h // 2, b, p)

        # ── 배꼽 하트 자수 (멘헤라 테마 — v8: 깨진 하트) ──
        heart_cx = belly_cx
        heart_cy = belly_top + int(belly_h * 0.52)
        hr = max(3, int(0.8 * b))

        # 하트 글로우
        glow_sz = hr * 5
        glow_surf = self._get_surface(glow_sz, glow_sz)
        pulse = (_sin(self.time * 1.5) + 1) * 0.5
        glow_alpha = int(22 + 18 * pulse)
        pygame.draw.circle(glow_surf, (*p["pink_glow"][:3], glow_alpha),
                           (glow_sz // 2, glow_sz // 2), int(hr * 2.2))
        screen.blit(glow_surf, (heart_cx - glow_sz // 2, heart_cy - glow_sz // 2),
                    special_flags=pygame.BLEND_ADD)

        # 자수 하트 (스티치 스타일)
        lobe_r = int(hr * 0.55)
        self._draw_heart_shape(screen, heart_cx, heart_cy, hr, lobe_r, p["pink_dark"], 2)
        self._draw_heart_shape(screen, heart_cx, heart_cy, hr, lobe_r, p["pink"], 0)
        self._draw_heart_shape(screen, heart_cx, heart_cy - int(hr * 0.15),
                               int(hr * 0.6), int(lobe_r * 0.5), p["pink_light"], 0)

        # v8: 하트에 균열선 (깨진 하트)
        crack_w = max(1, int(0.05 * b))
        crack_cx = heart_cx + int(0.1 * b)
        crack_top = heart_cy - int(hr * 0.3)
        crack_mid = heart_cy + int(hr * 0.2)
        crack_bot = heart_cy + int(hr * 0.7)
        pygame.draw.line(screen, p["fur_shadow"],
                         (crack_cx, crack_top),
                         (crack_cx - int(0.2 * b), crack_mid), crack_w)
        pygame.draw.line(screen, p["fur_shadow"],
                         (crack_cx - int(0.2 * b), crack_mid),
                         (crack_cx + int(0.1 * b), crack_bot), crack_w)

        # 봉제 중앙 세로 솔기
        seam_top = body_top + int(0.4 * b)
        seam_bot = body_top + body_h - int(0.5 * b)
        seam_w = max(1, int(0.07 * b))
        for seg_y in range(int(seam_top), int(seam_bot), max(3, int(0.3 * b))):
            dy = min(seg_y + max(1, int(0.14 * b)), int(seam_bot))
            pygame.draw.line(screen, (*p["stitch"], 80),
                             (bcx, seg_y), (bcx, dy), seam_w)

        # ═══ v8: 터진 솔기 — 왼쪽 옆구리에서 솜 삐져나옴 ═══
        self._draw_burst_seam(screen, bcx, body_top, body_w, body_h, b, p)

    # ═══════════════════════ v8: 터진 솔기 + 솜 ═══════════════════════

    def _draw_burst_seam(self, screen, bcx, body_top, body_w, body_h, b, p):
        """어깨/옆구리 터진 솔기에서 솜이 삐져나오는 디테일"""
        # 왼쪽 옆구리 위치
        burst_x = bcx - int(body_w * 0.42)
        burst_y = body_top + int(body_h * 0.3)

        # 터진 솔기선 (지그재그)
        seam_len = int(2.0 * b)
        seam_w = max(1, int(0.08 * b))
        points = []
        rng = random.Random(12345)
        for i in range(6):
            sx = burst_x + int(i * seam_len / 5)
            sy = burst_y + rng.randint(-int(0.15 * b), int(0.15 * b))
            points.append((sx, sy))

        # 벌어진 틈 (어두운 선)
        for i in range(len(points) - 1):
            pygame.draw.line(screen, p["fur_deep"], points[i], points[i + 1], seam_w + 1)

        # 벌어진 틈 양옆 스티치 자국 (끊어진 실)
        for i in range(len(points) - 1):
            mx = (points[i][0] + points[i + 1][0]) // 2
            my = (points[i][1] + points[i + 1][1]) // 2
            stitch_len = int(0.3 * b)
            pygame.draw.line(screen, p["stitch"],
                             (mx, my - stitch_len), (mx, my + stitch_len),
                             max(1, int(0.04 * b)))

        # 솜 삐져나옴 (불규칙한 흰 덩어리)
        rng2 = random.Random(54321)
        for _ in range(5):
            cx_s = burst_x + rng2.randint(0, int(seam_len * 0.8))
            cy_s = burst_y + rng2.randint(-int(0.4 * b), int(0.4 * b))
            sr = max(2, int(rng2.uniform(0.2, 0.5) * b))

            # 솜 음영
            pygame.draw.circle(screen, p["stuffing_shadow"],
                               (cx_s + 1, cy_s + 1), sr)
            # 솜 메인
            pygame.draw.circle(screen, p["stuffing"], (cx_s, cy_s), sr)
            # 솜 하이라이트
            pygame.draw.circle(screen, (255, 252, 248),
                               (cx_s - int(sr * 0.25), cy_s - int(sr * 0.25)),
                               max(1, int(sr * 0.45)))

        # 오른쪽 어깨에도 작은 터진 부분
        burst_x2 = bcx + int(body_w * 0.35)
        burst_y2 = body_top + int(body_h * 0.15)
        tiny_seam_w = max(1, int(0.06 * b))

        # 짧은 균열
        pygame.draw.line(screen, p["fur_deep"],
                         (burst_x2, burst_y2),
                         (burst_x2 + int(0.8 * b), burst_y2 + int(0.2 * b)),
                         tiny_seam_w + 1)
        # 솜 한 덩이
        for dx_s, dy_s in [(0.3, -0.15), (0.5, 0.1)]:
            sx = burst_x2 + int(dx_s * b)
            sy = burst_y2 + int(dy_s * b)
            sr = max(2, int(0.25 * b))
            pygame.draw.circle(screen, p["stuffing_shadow"], (sx + 1, sy + 1), sr)
            pygame.draw.circle(screen, p["stuffing"], (sx, sy), sr)

    # ═══════════════════════ 팔 ═══════════════════════

    def _draw_arm(self, screen, cx, torso_y, b, p, is_back, roll):
        arm_w = int(2.8 * b)
        arm_h = int(4.2 * b)
        side = -1 if is_back else 1

        shoulder_x = cx + int(side * 4.0 * b) + int(roll * 0.3 * side)
        shoulder_y = torso_y - int(0.2 * b)

        swing_angle = self.arm_swing * (-1 if is_back else 1)

        # 히트 스윙: 해당 방향 팔이면 크게 아래로 휘두르기
        if self.hit_swing_active and self.hit_swing_phase > 0:
            is_swing_arm = (
                (self.hit_swing_direction > 0 and not is_back) or  # 오른팔
                (self.hit_swing_direction < 0 and is_back)         # 왼팔
            )
            if is_swing_arm:
                # 팔을 앞(아래)으로 크게 휘두르는 각도 (최대 1.2 라디안 ≈ 70도)
                hit_angle = self.hit_swing_phase * 1.2 * side
                swing_angle = hit_angle

        end_x = shoulder_x + int(_sin(swing_angle) * arm_h)
        end_y = shoulder_y + int(_cos(swing_angle) * arm_h)

        ax = (shoulder_x + end_x) // 2
        ay = (shoulder_y + end_y) // 2

        # v8: 구면 음영 적용된 팔
        self._draw_shaded_ellipse(
            screen,
            (ax - arm_w // 2, ay - arm_h // 2, arm_w, arm_h),
            p["fur_base"], p["fur_shadow"], p["fur_mid"],
            rim_color=p["fur_rim"], rim_alpha=30
        )
        # 추가 하이라이트
        hl_w = int(arm_w * 0.45)
        hl_h = int(arm_h * 0.4)
        hl_x_off = int(-0.15 * b) if side < 0 else int(0.15 * b)
        pygame.draw.ellipse(screen, p["fur_light"],
                            (ax - int(hl_w * 0.4) + hl_x_off, ay - int(hl_h * 0.35) - int(0.3 * b),
                             int(hl_w * 0.55), int(hl_h * 0.45)))

        # 퍼즈 가장자리
        fuzz_surf = self._get_fuzz_edge(arm_w // 2, arm_h // 2, p["fur_base"],
                                        seed=hash(("arm", side)))
        screen.blit(fuzz_surf, (ax - arm_w // 2 - 8, ay - arm_h // 2 - 8))

        # 팔 솔기 (세로)
        seam_w_v = max(1, int(0.06 * b))
        seam_t = ay - int(arm_h * 0.3)
        seam_b = ay + int(arm_h * 0.3)
        for sy in range(int(seam_t), int(seam_b), max(2, int(0.25 * b))):
            dy = min(sy + max(1, int(0.1 * b)), int(seam_b))
            pygame.draw.line(screen, (*p["stitch"], 60),
                             (ax, sy), (ax, dy), seam_w_v)

        # ── 손(발) 패드 ──
        pad_r = max(3, int(0.55 * b))
        pygame.draw.circle(screen, p["fur_dark"], (end_x + 1, end_y + 1), pad_r + 2)
        pygame.draw.circle(screen, p["fur_base"], (end_x, end_y), pad_r + 1)
        pygame.draw.circle(screen, p["pad_dark"], (end_x, end_y), pad_r)
        pygame.draw.circle(screen, p["pad"], (end_x, end_y), pad_r - 1)
        pygame.draw.circle(screen, p["pad_light"],
                           (end_x - int(0.1 * b), end_y - int(0.1 * b)),
                           max(1, pad_r // 2))

        # ═══ v8: 오른팔(앞쪽) 붕대 ═══
        if not is_back:
            self._draw_bandage(screen, ax, ay, arm_w, arm_h, b, p)

    # ═══════════════════════ v8: 붕대 ═══════════════════════

    def _draw_bandage(self, screen, ax, ay, arm_w, arm_h, b, p):
        """오른팔에 감긴 붕대"""
        band_count = 4
        band_h = max(2, int(0.28 * b))
        band_gap = int(arm_h * 0.12)
        start_y = ay - int(arm_h * 0.2)

        for i in range(band_count):
            by = start_y + i * band_gap
            # 팔 타원 내부에 있는지 대략 확인
            dy_norm = (by - ay) / (arm_h * 0.5) if arm_h > 0 else 0
            if abs(dy_norm) > 0.85:
                continue
            # 이 y에서 팔의 x 범위
            x_ratio = _sqrt(max(0.01, 1.0 - dy_norm * dy_norm))
            half_w = int(arm_w * 0.5 * x_ratio)
            if half_w < 2:
                continue

            bx = ax - half_w
            bw = half_w * 2

            # 약간 비뚤어진 각도 (사선 감기)
            slant = int(0.15 * b * (1 if i % 2 == 0 else -1))

            pts = [
                (bx, by + slant),
                (bx + bw, by - slant),
                (bx + bw, by - slant + band_h),
                (bx, by + slant + band_h),
            ]

            # 붕대 그림자
            shadow = [(x + 1, y + 1) for x, y in pts]
            pygame.draw.polygon(screen, p["bandage_shadow"], shadow)
            # 붕대 메인
            pygame.draw.polygon(screen, p["bandage"], pts)

            # 붕대 얼룩 (더러운 느낌)
            if i == 1 or i == 3:
                stain_x = ax + int(0.1 * b * (-1 if i == 1 else 1))
                stain_y = by + slant // 2
                stain_r = max(1, int(0.12 * b))
                stain_surf = self._get_surface(stain_r * 2 + 4, stain_r * 2 + 4)
                pygame.draw.circle(stain_surf, (*p["bandage_stain"], 50),
                                   (stain_r + 2, stain_r + 2), stain_r)
                screen.blit(stain_surf, (stain_x - stain_r - 2, stain_y - stain_r - 2))

    # ═══════════════════════ 머리 ═══════════════════════

    def _draw_head(self, screen, cx, torso_y, b, p, fd, roll):
        head_rx = int(4.2 * b)
        head_ry = int(3.8 * b)
        head_cx = cx + int(roll * 0.3)
        head_cy = torso_y - int(3.5 * b)

        face_shift = int(fd * 0.6 * b)

        # ── 귀 (반원형, 리얼 봉제) ──
        ear_bounce = self.ear_bounce * _SSAA
        for side in [-1, 1]:
            ear_cx = head_cx + int(side * 3.0 * b) + int(face_shift * 0.25)
            ear_cy = head_cy - int(2.6 * b) - int(ear_bounce * (0.5 if side == -1 else 0.3))
            ear_rx = int(1.6 * b)
            ear_ry = int(1.8 * b)

            # v8: 구면 음영 적용된 귀
            self._draw_shaded_ellipse(
                screen,
                (ear_cx - ear_rx, ear_cy - ear_ry, ear_rx * 2, ear_ry * 2),
                p["fur_base"], p["fur_shadow"], p["fur_mid"],
                rim_color=p["fur_rim"], rim_alpha=25, noise=False
            )

            # 귀 안쪽 (핑크 — 멘헤라 테마)
            in_rx = int(ear_rx * 0.62)
            in_ry = int(ear_ry * 0.62)
            pygame.draw.ellipse(screen, p["pink_dark"],
                                (ear_cx - in_rx, ear_cy - in_ry + int(0.15 * b),
                                 in_rx * 2, in_ry * 2))
            pygame.draw.ellipse(screen, p["pink"],
                                (ear_cx - in_rx + 1, ear_cy - in_ry + int(0.2 * b),
                                 in_rx * 2 - 2, in_ry * 2 - 2))
            pygame.draw.ellipse(screen, p["pink_light"],
                                (ear_cx - int(in_rx * 0.45) - int(0.08 * b * side),
                                 ear_cy - int(in_ry * 0.4),
                                 int(in_rx * 0.6), int(in_ry * 0.45)))

            # ═══ v8: 왼쪽 귀 안전핀 ═══
            if side == -1:
                self._draw_safety_pin(screen, ear_cx, ear_cy, ear_rx, ear_ry, b, p)

        # ── 머리 본체 ──
        # v8: 구면 음영 적용된 머리
        self._draw_shaded_ellipse(
            screen,
            (head_cx - head_rx, head_cy - head_ry, head_rx * 2, head_ry * 2),
            p["fur_base"], p["fur_deep"], p["fur_mid"],
            rim_color=p["fur_rim"], rim_alpha=40
        )

        # 하단 음영 (턱 아래)
        chin_h = int(1.8 * b)
        pygame.draw.ellipse(screen, p["fur_dark"],
                            (head_cx - head_rx + int(0.3 * b),
                             head_cy + int(0.8 * b),
                             head_rx * 2 - int(0.6 * b), chin_h))

        # 이마 하이라이트
        pygame.draw.ellipse(screen, p["fur_light"],
                            (head_cx - int(head_rx * 0.4), head_cy - int(head_ry * 0.75),
                             int(head_rx * 0.8), int(head_ry * 0.5)))
        # 이마 피크 광택
        pygame.draw.ellipse(screen, p["fur_highlight"],
                            (head_cx - int(head_rx * 0.22) - int(0.4 * b),
                             head_cy - int(head_ry * 0.65),
                             int(head_rx * 0.35), int(head_ry * 0.22)))

        # 글로시 (이마 상단)
        gw = int(3.0 * b)
        gh = int(1.0 * b)
        gloss_surf = self._get_surface(gw, gh)
        pygame.draw.ellipse(gloss_surf, (255, 255, 255, 20), (0, 0, gw, gh))
        screen.blit(gloss_surf, (head_cx - gw // 2, head_cy - int(head_ry * 0.85)))

        # 퍼즈 가장자리 (머리)
        fuzz_surf = self._get_fuzz_edge(head_rx, head_ry, p["fur_base"], seed=99)
        screen.blit(fuzz_surf, (head_cx - head_rx - 8, head_cy - head_ry - 8))

        # ── 머리 중앙 세로 솔기 ──
        seam_top = head_cy - int(head_ry * 0.8)
        seam_bot = head_cy + int(head_ry * 0.15)
        seam_w = max(1, int(0.06 * b))
        for sy in range(int(seam_top), int(seam_bot), max(3, int(0.3 * b))):
            dy = min(sy + max(1, int(0.12 * b)), int(seam_bot))
            pygame.draw.line(screen, (*p["stitch"], 55),
                             (head_cx, sy), (head_cx, dy), seam_w)

        # === 얼굴 ===
        face_cx = head_cx + face_shift
        face_cy = head_cy + int(0.15 * b)

        # ── 머즐 (주둥이 — 크림색 돌출 타원) ──
        muzzle_w = int(3.0 * b)
        muzzle_h = int(2.2 * b)
        muzzle_cx = face_cx
        muzzle_cy = face_cy + int(0.8 * b)

        pygame.draw.ellipse(screen, p["cream_dark"],
                            (muzzle_cx - muzzle_w // 2 + 1, muzzle_cy - muzzle_h // 2 + 2,
                             muzzle_w, muzzle_h))
        pygame.draw.ellipse(screen, p["cream"],
                            (muzzle_cx - muzzle_w // 2, muzzle_cy - muzzle_h // 2,
                             muzzle_w, muzzle_h))
        pygame.draw.ellipse(screen, p["cream_light"],
                            (muzzle_cx - int(muzzle_w * 0.3) - int(0.15 * b),
                             muzzle_cy - int(muzzle_h * 0.35),
                             int(muzzle_w * 0.5), int(muzzle_h * 0.4)))

        # ── 코 (역삼각형 가죽 코) ──
        nose_cx = muzzle_cx
        nose_cy = muzzle_cy - int(0.2 * b)
        nose_w = int(1.1 * b)
        nose_h = int(0.75 * b)

        nose_pts = [
            (nose_cx - nose_w // 2, nose_cy - nose_h // 3),
            (nose_cx + nose_w // 2, nose_cy - nose_h // 3),
            (nose_cx, nose_cy + int(nose_h * 0.65)),
        ]
        shadow_pts = [(x + 1, y + 2) for x, y in nose_pts]
        pygame.draw.polygon(screen, p["fur_shadow"], shadow_pts)
        pygame.draw.polygon(screen, p["nose_base"], nose_pts)
        nose_top_r = max(2, int(nose_w * 0.32))
        pygame.draw.circle(screen, p["nose_base"],
                           (nose_cx - int(nose_w * 0.2), nose_cy - nose_h // 4), nose_top_r)
        pygame.draw.circle(screen, p["nose_base"],
                           (nose_cx + int(nose_w * 0.2), nose_cy - nose_h // 4), nose_top_r)
        pygame.draw.circle(screen, p["nose_mid"],
                           (nose_cx - int(nose_w * 0.15), nose_cy - nose_h // 5),
                           max(1, int(nose_top_r * 0.6)))
        pygame.draw.circle(screen, p["nose_shine"],
                           (nose_cx - int(nose_w * 0.15), nose_cy - int(nose_h * 0.3)),
                           max(1, int(nose_top_r * 0.35)))
        gloss_r = max(1, int(0.15 * b))
        pygame.draw.circle(screen, p["nose_gloss"],
                           (nose_cx - int(0.15 * b), nose_cy - int(0.15 * b)), gloss_r)

        # ── 입 (코에서 Y자로 내려가는 선) ──
        mouth_start_y = nose_cy + int(nose_h * 0.65)
        mouth_mid_y = muzzle_cy + int(0.35 * b)
        mouth_lw = max(1, int(0.08 * b))

        pygame.draw.line(screen, p["mouth"],
                         (nose_cx, mouth_start_y), (nose_cx, mouth_mid_y), mouth_lw)
        mouth_spread = int(0.6 * b)
        pygame.draw.arc(screen, p["mouth"],
                        (nose_cx - mouth_spread, mouth_mid_y - int(0.15 * b),
                         mouth_spread, int(0.6 * b)),
                        _pi * 1.6, _tau, mouth_lw)
        pygame.draw.arc(screen, p["mouth"],
                        (nose_cx, mouth_mid_y - int(0.15 * b),
                         mouth_spread, int(0.6 * b)),
                        _pi, _pi * 1.4, mouth_lw)

        # ═══ v8: 짝짝이 눈 ═══
        # 왼쪽: 얀데레 하트 단추 눈  |  오른쪽: 단추 빠진 실밥 + 덜렁거리는 단추
        for side_i in [-1, 1]:
            eye_cx = face_cx + int(side_i * 1.5 * b)
            eye_cy = face_cy - int(0.15 * b)
            eye_r = max(3, int(1.15 * b))

            if side_i == -1:
                # ── 왼쪽 눈: 얀데레 하트 단추 (기존 유지) ──
                socket_r = eye_r + max(1, int(0.2 * b))
                pygame.draw.circle(screen, p["fur_dark"], (eye_cx, eye_cy), socket_r)
                pygame.draw.circle(screen, p["eye_ring"], (eye_cx, eye_cy),
                                   eye_r + max(1, int(0.1 * b)))
                pygame.draw.circle(screen, p["eye_base"], (eye_cx, eye_cy), eye_r)

                hr = max(3, int(eye_r * 0.85))
                lobe_r = int(hr * 0.52)
                outline = max(1, int(0.08 * b))
                self._draw_heart_shape(screen, eye_cx, eye_cy, hr, lobe_r + outline,
                                       p["pink_dark"], outline)
                self._draw_heart_shape(screen, eye_cx, eye_cy, hr, lobe_r, p["pink"], 0)
                self._draw_heart_shape(screen, eye_cx, eye_cy - int(hr * 0.12),
                                       int(hr * 0.65), int(lobe_r * 0.55),
                                       p["pink_light"], 0)

                # 단추 구멍
                hole_r = max(1, int(0.08 * b))
                stitch_col = (*p["pink_deep"], 120)
                for dx, dy in [(-0.25, -0.15), (0.25, -0.15), (-0.15, 0.25), (0.15, 0.25)]:
                    hx = eye_cx + int(dx * hr)
                    hy = eye_cy + int(dy * hr)
                    hole_surf = self._get_surface(hole_r * 2 + 4, hole_r * 2 + 4)
                    pygame.draw.circle(hole_surf, stitch_col,
                                       (hole_r + 2, hole_r + 2), hole_r)
                    screen.blit(hole_surf, (hx - hole_r - 2, hy - hole_r - 2))
            else:
                # ── 오른쪽 눈: 단추 빠진 실밥 + 덜렁거리는 단추 ──
                self._draw_dangling_eye(screen, eye_cx, eye_cy, eye_r, b, p)

        # ── 볼 홍조 (7단계 소프트 그라데이션) ──
        for side_b in [-1, 1]:
            blush_cx = face_cx + int(side_b * 2.3 * b)
            blush_cy = face_cy + int(0.65 * b)
            blush_rx = int(1.2 * b)
            blush_ry = int(0.65 * b)
            blush_surf = self._get_surface(blush_rx * 2 + 8, blush_ry * 2 + 8)

            for layer in range(7):
                alpha = max(0, 50 - layer * 7)
                rx = max(2, blush_rx - layer * int(0.08 * b))
                ry = max(1, blush_ry - layer * int(0.04 * b))
                pygame.draw.ellipse(blush_surf, (255, 140, 165, alpha),
                                    (blush_rx + 4 - rx, blush_ry + 4 - ry,
                                     rx * 2, ry * 2))

            screen.blit(blush_surf, (blush_cx - blush_rx - 4, blush_cy - blush_ry - 4))

        # ── 리본 ──
        ribbon_side = -1 if fd > 0.3 else 1
        self._draw_ribbon(screen, head_cx, head_cy, head_ry, b, p, face_shift, ribbon_side)

    # ═══════════════════════ v8: 덜렁거리는 오른쪽 눈 ═══════════════════════

    def _draw_dangling_eye(self, screen, eye_cx, eye_cy, eye_r, b, p):
        """단추가 빠져서 실에 매달려 덜렁거리는 오른쪽 눈"""
        socket_r = eye_r + max(1, int(0.2 * b))

        # 눈 소켓 (빈 홈) — 어두운 구멍
        pygame.draw.circle(screen, p["fur_deep"], (eye_cx, eye_cy), socket_r)
        # 홈 안쪽 어두운 음영
        pygame.draw.circle(screen, (35, 20, 12), (eye_cx, eye_cy), int(socket_r * 0.85))

        # 실밥 X자 (구멍에 남은 실 자국)
        thread_w = max(1, int(0.07 * b))
        cross_r = int(eye_r * 0.7)
        pygame.draw.line(screen, p["thread"],
                         (eye_cx - cross_r, eye_cy - cross_r),
                         (eye_cx + cross_r, eye_cy + cross_r), thread_w)
        pygame.draw.line(screen, p["thread"],
                         (eye_cx + cross_r, eye_cy - cross_r),
                         (eye_cx - cross_r, eye_cy + cross_r), thread_w)
        # 실밥 하이라이트
        pygame.draw.line(screen, p["thread_light"],
                         (eye_cx - cross_r + 1, eye_cy - cross_r - 1),
                         (eye_cx + cross_r + 1, eye_cy + cross_r - 1), max(1, thread_w - 1))

        # 실 (소켓에서 단추까지 늘어진 실)
        thread_len = int(2.0 * b)
        angle = self.dangling_eye_angle
        btn_cx = eye_cx + int(_sin(angle) * thread_len)
        btn_cy = eye_cy + int(_cos(angle) * thread_len * 0.6) + int(thread_len * 0.5)

        # 실 곡선 (3점 베지어 근사)
        mid_x = (eye_cx + btn_cx) // 2 + int(_sin(angle) * 0.4 * b)
        mid_y = (eye_cy + btn_cy) // 2 + int(0.3 * b)
        thread_w2 = max(1, int(0.05 * b))
        # 직선 근사 (3세그먼트)
        pygame.draw.line(screen, p["thread"], (eye_cx, eye_cy), (mid_x, mid_y), thread_w2)
        pygame.draw.line(screen, p["thread"], (mid_x, mid_y), (btn_cx, btn_cy), thread_w2)

        # 덜렁거리는 단추 (검은 유리 단추)
        btn_r = max(2, int(eye_r * 0.55))
        # 그림자
        pygame.draw.circle(screen, (20, 10, 5), (btn_cx + 1, btn_cy + 1), btn_r + 1)
        # 단추 링
        pygame.draw.circle(screen, p["eye_ring"], (btn_cx, btn_cy), btn_r + max(1, int(0.06 * b)))
        # 단추 본체
        pygame.draw.circle(screen, p["eye_base"], (btn_cx, btn_cy), btn_r)
        # 단추 광택
        spec_r = max(1, int(btn_r * 0.3))
        pygame.draw.circle(screen, (60, 50, 40),
                           (btn_cx - int(btn_r * 0.2), btn_cy - int(btn_r * 0.2)), spec_r)
        # 작은 반짝임
        pygame.draw.circle(screen, p["eye_shine"],
                           (btn_cx - int(btn_r * 0.25), btn_cy - int(btn_r * 0.3)),
                           max(1, int(btn_r * 0.15)))
        # 단추 구멍 2개
        hole_r = max(1, int(0.06 * b))
        for hdy in [-0.2, 0.2]:
            pygame.draw.circle(screen, (50, 35, 25),
                               (btn_cx, btn_cy + int(hdy * btn_r)),
                               hole_r)

    # ═══════════════════════ v8: 안전핀 ═══════════════════════

    def _draw_safety_pin(self, screen, ear_cx, ear_cy, ear_rx, ear_ry, b, p):
        """왼쪽 귀에 꽂힌 거대한 안전핀"""
        pin_cx = ear_cx + int(ear_rx * 0.3)
        pin_cy = ear_cy + int(ear_ry * 0.1)
        pin_len = int(2.2 * b)
        pin_w_half = int(0.4 * b)
        pin_thick = max(1, int(0.09 * b))

        # 안전핀 몸체 (직선 바)
        bar_top = pin_cy - int(pin_len * 0.4)
        bar_bot = pin_cy + int(pin_len * 0.4)

        # 닫힌 쪽 (상단 둥근 루프)
        loop_r = max(2, int(0.25 * b))
        pygame.draw.arc(screen, p["pin_dark"],
                        (pin_cx - loop_r, bar_top - loop_r, loop_r * 2, loop_r * 2),
                        0, _pi, pin_thick + 1)
        pygame.draw.arc(screen, p["pin_metal"],
                        (pin_cx - loop_r, bar_top - loop_r, loop_r * 2, loop_r * 2),
                        0, _pi, pin_thick)
        # 루프 광택
        pygame.draw.arc(screen, p["pin_shine"],
                        (pin_cx - loop_r + 1, bar_top - loop_r - 1, loop_r * 2 - 2, loop_r * 2 - 2),
                        _pi * 0.3, _pi * 0.7, max(1, pin_thick - 1))

        # 왼쪽 바 (고정 바)
        pygame.draw.line(screen, p["pin_dark"],
                         (pin_cx - loop_r + 1, bar_top + 1),
                         (pin_cx - loop_r + 1, bar_bot + 1), pin_thick + 1)
        pygame.draw.line(screen, p["pin_metal"],
                         (pin_cx - loop_r, bar_top),
                         (pin_cx - loop_r, bar_bot), pin_thick)
        # 광택
        pygame.draw.line(screen, p["pin_shine"],
                         (pin_cx - loop_r - 1, bar_top),
                         (pin_cx - loop_r - 1, bar_bot), max(1, pin_thick // 2))

        # 오른쪽 바 (잠금 바 — 살짝 열린 느낌)
        pygame.draw.line(screen, p["pin_dark"],
                         (pin_cx + loop_r + 1, bar_top + 1),
                         (pin_cx + loop_r + 1, bar_bot - int(0.2 * b) + 1), pin_thick + 1)
        pygame.draw.line(screen, p["pin_metal"],
                         (pin_cx + loop_r, bar_top),
                         (pin_cx + loop_r, bar_bot - int(0.2 * b)), pin_thick)

        # 하단 잠금 장치 (작은 삼각형)
        clasp_y = bar_bot
        clasp_w = int(0.35 * b)
        clasp_pts = [
            (pin_cx - loop_r - clasp_w // 2, clasp_y),
            (pin_cx - loop_r + clasp_w // 2, clasp_y),
            (pin_cx - loop_r, clasp_y + int(0.25 * b)),
        ]
        pygame.draw.polygon(screen, p["pin_metal"], clasp_pts)
        # 잠금 장치 하이라이트
        pygame.draw.polygon(screen, p["pin_shine"],
                            [(x - 1, y - 1) for x, y in clasp_pts[:2]] + [clasp_pts[2]])

        # 핀 꽂힌 부분 (귀를 관통하는 느낌 — 어두운 점)
        pierce_r = max(1, int(0.07 * b))
        pygame.draw.circle(screen, p["fur_deep"],
                           (pin_cx - loop_r, pin_cy), pierce_r + 1)
        pygame.draw.circle(screen, p["fur_deep"],
                           (pin_cx + loop_r, pin_cy - int(0.1 * b)), pierce_r)

    # ═══════════════════════ 리본 ═══════════════════════

    def _draw_ribbon(self, screen, head_cx, head_cy, head_ry, b, p, face_shift, ribbon_side):
        ribbon_cx = head_cx + int(ribbon_side * 2.6 * b) + int(face_shift * 0.2)
        ribbon_cy = head_cy - int(head_ry * 0.75)
        flutter = self.ribbon_flutter * _SSAA

        bow_w = int(1.6 * b)
        bow_h = int(1.0 * b)

        # 리본 날개 (좌우)
        left_pts = [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx - bow_w + int(flutter * 0.3), ribbon_cy - bow_h),
            (ribbon_cx - int(bow_w * 0.35), ribbon_cy - int(bow_h * 0.1)),
            (ribbon_cx - bow_w - int(flutter * 0.2), ribbon_cy + bow_h),
        ]
        right_pts = [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx + bow_w - int(flutter * 0.2), ribbon_cy - bow_h + int(flutter * 0.15)),
            (ribbon_cx + int(bow_w * 0.35), ribbon_cy - int(bow_h * 0.1)),
            (ribbon_cx + bow_w + int(flutter * 0.3), ribbon_cy + bow_h - int(flutter * 0.1)),
        ]

        for pts in [left_pts, right_pts]:
            shadow = [(x + 2, y + 2) for x, y in pts]
            pygame.draw.polygon(screen, p["pink_deep"], shadow)
            pygame.draw.polygon(screen, p["pink"], pts)

        # 새틴 하이라이트
        for sign in [-1, 1]:
            hl = [
                (ribbon_cx, ribbon_cy),
                (ribbon_cx + int(sign * bow_w * 0.55), ribbon_cy - int(bow_h * 0.55)),
                (ribbon_cx + int(sign * bow_w * 0.15), ribbon_cy - int(bow_h * 0.05)),
            ]
            pygame.draw.polygon(screen, p["pink_light"], hl)
            hl2 = [
                (ribbon_cx + int(sign * bow_w * 0.1), ribbon_cy),
                (ribbon_cx + int(sign * bow_w * 0.45), ribbon_cy - int(bow_h * 0.35)),
                (ribbon_cx + int(sign * bow_w * 0.2), ribbon_cy - int(bow_h * 0.05)),
            ]
            hl2_surf = self._get_surface(int(bow_w * 2), int(bow_h * 2))
            local_pts = [(x - ribbon_cx + bow_w, y - ribbon_cy + bow_h) for x, y in hl2]
            pygame.draw.polygon(hl2_surf, (*p["pink_light"], 60), local_pts)
            screen.blit(hl2_surf, (ribbon_cx - bow_w, ribbon_cy - bow_h))

        # 매듭
        knot_r = max(3, int(0.35 * b))
        pygame.draw.circle(screen, p["pink_dark"], (ribbon_cx + 1, ribbon_cy + 1), knot_r + 1)
        pygame.draw.circle(screen, p["pink"], (ribbon_cx, ribbon_cy), knot_r)
        pygame.draw.circle(screen, p["pink_light"],
                           (ribbon_cx - int(0.06 * b), ribbon_cy - int(0.06 * b)),
                           max(1, knot_r // 2))

        # 꼬리
        tail_len = int(1.8 * b)
        tail_f = int(_sin(self.time * 1.5) * 0.35 * b)
        for s, sx_off in [(-1, -int(0.18 * b)), (1, int(0.18 * b))]:
            tx = ribbon_cx + sx_off
            pts = [
                (tx, ribbon_cy + knot_r),
                (tx + int(s * 0.35 * b) + tail_f, ribbon_cy + knot_r + tail_len),
                (tx + int(s * 0.12 * b) + int(tail_f * 0.5),
                 ribbon_cy + knot_r + int(tail_len * 0.6)),
                (tx + int(s * 0.05 * b), ribbon_cy + knot_r + int(tail_len * 0.3)),
            ]
            pygame.draw.polygon(screen, p["pink"], pts)
            pygame.draw.line(screen, p["pink_light"],
                             pts[0], pts[3], max(1, int(0.07 * b)))

    # ═══════════════════════ 유틸리티 ═══════════════════════

    def _draw_heart_shape(self, screen, cx, cy, hr, lobe_r, color, expand):
        """하트 형태 그리기 (원 2개 + 역삼각형)"""
        e = expand
        pygame.draw.circle(screen, color,
                           (cx - lobe_r, cy - int(hr * 0.15)), lobe_r + e)
        pygame.draw.circle(screen, color,
                           (cx + lobe_r, cy - int(hr * 0.15)), lobe_r + e)
        pygame.draw.polygon(screen, color, [
            (cx - hr - e, cy - int(hr * 0.05)),
            (cx + hr + e, cy - int(hr * 0.05)),
            (cx, cy + int(hr * 1.1) + e)
        ])

    def _draw_stitch_ellipse(self, screen, cx, cy, rx, ry, b, p):
        """타원형 점선 스티치 (봉제 이음새)"""
        stitch_col = (*p["stitch"], 65)
        stitch_w = max(1, int(0.06 * b))
        num_stitches = max(12, int(rx * 0.8))
        for i in range(num_stitches):
            if i % 2 == 1:
                continue
            angle1 = (i / num_stitches) * _tau
            angle2 = ((i + 0.7) / num_stitches) * _tau
            x1 = cx + int(rx * _cos(angle1))
            y1 = cy + int(ry * _sin(angle1))
            x2 = cx + int(rx * _cos(angle2))
            y2 = cy + int(ry * _sin(angle2))
            surf = self._get_surface(abs(x2 - x1) + 8, abs(y2 - y1) + 8)
            ox = min(x1, x2) - 4
            oy = min(y1, y2) - 4
            pygame.draw.line(surf, stitch_col,
                             (x1 - ox, y1 - oy), (x2 - ox, y2 - oy), stitch_w)
            screen.blit(surf, (ox, oy))

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
