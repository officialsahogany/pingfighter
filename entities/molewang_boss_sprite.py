# -*- coding: utf-8 -*-
"""
두더지왕 (Mole King) 프로시저럴 보스 스프라이트
디그다 스타일 — 평소에는 땅속에 숨어서 땅 울렁거림만 보이고,
공 타격 시에만 바닥에서 솟아올라 발톱으로 후려치고 다시 들어감.
- Stage1BossSprite / PododaejangBossSprite 와 동일한 인터페이스
"""

import pygame
import math

_sin = math.sin
_cos = math.cos


class MolewangBossSprite:
    """
    두더지왕 프로시저럴 보스 스프라이트
    디그다 스타일 — 땅속 보스, 타격 시에만 출현
    """

    def __init__(self):
        # 애니메이션 상태
        self.direction = 0       # -1: 왼쪽, 0: 정지, 1: 오른쪽
        self.prev_x = 0.0
        self.time = 0.0

        # 걷기 (땅 울렁거림)
        self.step_phase = 0.0
        self.lean = 0.0
        self.body_bob = 0.0
        self.velocity = 0.0

        # 방향 전환 안정화
        self.direction_change_cooldown = 0.0
        self.direction_change_threshold = 0.15
        self.movement_accumulator = 0.0

        # 히트 애니메이션 (솟아오르기 → 후려치기 → 들어가기)
        self.is_hit = False
        self.hit_timer = 0.0
        self.hit_duration = 0.65   # 전체 출현~복귀 시간
        self.hit_direction = 1
        self.hit_intensity = 0.0

        # 솟아오르기 높이 (0.0 = 땅속, 1.0 = 완전 출현)
        self.emerge_amount = 0.0

        # 흙 파편 파티클
        self._dirt_particles = []
        self._dirt_spawn_timer = 0.0

        # 회전발톱 모션
        self.spinning_claw_active = False
        self.spinning_claw_timer = 0.0
        self.spinning_claw_duration = 0.5     # 0.5초
        self.spinning_claw_direction = 1      # 스와이프 방향 (-1/1)
        self.spinning_claw_emerge = 0.0       # 별도 솟아오르기

        # 프레임 캐시
        self._surface_cache = {}

    def _get_surface(self, w, h):
        key = (w, h)
        if key not in self._surface_cache:
            self._surface_cache[key] = pygame.Surface((w, h), pygame.SRCALPHA)
        else:
            self._surface_cache[key].fill((0, 0, 0, 0))
        return self._surface_cache[key]

    def update(self, current_x, dt=1/60):
        self.time += dt

        dx = current_x - self.prev_x

        if self.direction_change_cooldown > 0:
            self.direction_change_cooldown -= dt

        if abs(dx) > 2.0:
            new_dir = 1 if dx > 0 else -1
            self.movement_accumulator += dx
            if new_dir != self.direction and self.direction_change_cooldown <= 0:
                if abs(self.movement_accumulator) > 5.0:
                    self.direction = new_dir
                    self.direction_change_cooldown = self.direction_change_threshold
                    self.movement_accumulator = 0.0
            elif new_dir == self.direction:
                self.movement_accumulator = 0.0
        else:
            self.movement_accumulator *= 0.9
            if abs(self.movement_accumulator) < 1.0:
                self.direction = 0

        self.velocity = abs(dx) / max(dt, 0.001)

        # 걷기 → 땅 울렁거림 위상
        if self.direction != 0:
            speed_factor = min(self.velocity / 80.0, 2.0)
            self.step_phase += dt * 8.0 * max(speed_factor, 0.5)
            target_lean = self.direction * 0.15 * min(speed_factor, 1.0)
            self.lean += (target_lean - self.lean) * min(dt * 6.0, 1.0)
            self.body_bob = _sin(self.step_phase * 2) * 0.1 * speed_factor
        else:
            self.step_phase *= 0.95
            self.lean *= 0.92
            self.body_bob = _sin(self.time * 2.0) * 0.02

        # 히트 애니메이션 (솟아오르기 → 후려치기 → 복귀)
        if self.is_hit:
            self.hit_timer += dt
            progress = self.hit_timer / self.hit_duration
            if progress >= 1.0:
                self.is_hit = False
                self.hit_timer = 0.0
                self.hit_intensity = 0.0
                self.emerge_amount = 0.0
            else:
                self.hit_intensity = max(0, 1.0 - progress * progress)
                # 솟아오르기 곡선: 빠르게 올라와서 → 유지 → 서서히 내려감
                if progress < 0.18:
                    # 빠르게 솟아오름
                    self.emerge_amount = (progress / 0.18) ** 0.5
                elif progress < 0.55:
                    # 완전 출현 상태 유지 (후려치기 중)
                    self.emerge_amount = 1.0
                else:
                    # 서서히 내려감
                    t = (progress - 0.55) / 0.45
                    self.emerge_amount = 1.0 - t * t
        else:
            # 히트 끝나면 즉시 숨김 (0.85 감쇠는 0에 도달 못함 → 몸체 잔상 버그)
            self.emerge_amount = 0.0

        # 회전발톱 모션 업데이트
        if self.spinning_claw_active:
            self.spinning_claw_timer += dt
            sc_progress = self.spinning_claw_timer / self.spinning_claw_duration
            if sc_progress >= 1.0:
                self.spinning_claw_active = False
                self.spinning_claw_timer = 0.0
                self.spinning_claw_emerge = 0.0
            else:
                # 솟아오르기: 빠르게 올라와서 유지 후 내려감
                if sc_progress < 0.12:
                    self.spinning_claw_emerge = (sc_progress / 0.12) ** 0.4
                elif sc_progress < 0.75:
                    self.spinning_claw_emerge = 1.0
                else:
                    t = (sc_progress - 0.75) / 0.25
                    self.spinning_claw_emerge = 1.0 - t * t

        self._update_dirt_particles(dt)
        self.prev_x = current_x

    def _update_dirt_particles(self, dt):
        # 솟아오를 때 흙 파편 대량 생성
        if self.is_hit and self.hit_timer < 0.2:
            self._dirt_spawn_timer += dt
            if self._dirt_spawn_timer >= 0.02:
                self._dirt_spawn_timer = 0.0
                import random
                for _ in range(3):
                    self._dirt_particles.append({
                        "x": random.uniform(-1.0, 1.0),
                        "y": 0.0,
                        "vx": random.uniform(-2.0, 2.0),
                        "vy": random.uniform(-3.0, -1.0),
                        "life": 1.0,
                        "size": random.uniform(0.06, 0.14),
                    })
        # 이동 시 작은 파편
        elif self.direction != 0:
            self._dirt_spawn_timer += dt
            if self._dirt_spawn_timer >= 0.10:
                self._dirt_spawn_timer = 0.0
                import random
                self._dirt_particles.append({
                    "x": random.uniform(-0.5, 0.5),
                    "y": random.uniform(-0.1, 0.1),
                    "vx": random.uniform(-0.8, 0.8) - self.direction * 0.4,
                    "vy": random.uniform(-1.5, -0.3),
                    "life": 1.0,
                    "size": random.uniform(0.04, 0.09),
                })

        alive = []
        for p in self._dirt_particles:
            p["life"] -= dt * 2.2
            p["x"] += p["vx"] * dt
            p["y"] += p["vy"] * dt
            p["vy"] += 4.0 * dt
            if p["life"] > 0:
                alive.append(p)
        self._dirt_particles = alive[-30:]

    def trigger_hit(self, ball_x, boss_x):
        self.is_hit = True
        self.hit_timer = 0.0
        self.hit_intensity = 1.0
        self.hit_direction = 1 if ball_x > boss_x else -1

    def trigger_spinning_claw(self, direction):
        """회전발톱 모션 시작 — 0.5초간 솟아올라 강하게 후려침"""
        self.spinning_claw_active = True
        self.spinning_claw_timer = 0.0
        self.spinning_claw_direction = direction
        self.spinning_claw_emerge = 0.0
        # 히트 애니메이션이 동시에 진행될 수 있으므로 별도 관리

    def get_current_frame(self, scale_size=None):
        w, h = scale_size or (96, 192)
        w, h = max(20, int(w)), max(40, int(h))

        surface = pygame.Surface((w, h), pygame.SRCALPHA)
        b = w / 10.0
        cx = w // 2
        # 기준점: 땅 표면 = 패들 위치 부근 (세로 하단 쪽)
        ground_y = int(h * 0.70)

        self._draw_character(surface, cx, ground_y, b, w, h)
        return surface

    def draw(self, surface, x, y, width=None, height=None, center=True):
        if width and height:
            frame = self.get_current_frame((width, height))
        else:
            frame = self.get_current_frame()
        if frame:
            if center:
                rect = frame.get_rect(center=(int(x), int(y)))
            else:
                rect = frame.get_rect(topleft=(int(x), int(y)))
            surface.blit(frame, rect)

    # ===================================================================
    #  렌더링
    # ===================================================================

    def _draw_character(self, surface, cx, ground_y, b, w, h):
        lean_offset = int(self.lean * 2.0 * b)
        bob_offset = int(self.body_bob * 1.5 * b)

        p = self._get_palette(self.hit_intensity * 0.25 if self.is_hit else 0.0)

        # 솟아오른 양만큼 몸체를 그릴지 결정
        emerge = self.emerge_amount

        # 회전발톱 모션 중이면 별도 emerge 사용
        sc_emerge = self.spinning_claw_emerge if self.spinning_claw_active else 0.0
        effective_emerge = max(emerge, sc_emerge)

        # 레이어 순서
        # 0. 지하 흙 융기 (평소 — 히트/회전발톱 아닐 때)
        if not self.is_hit and not self.spinning_claw_active:
            self._draw_underground_ripple(surface, cx, ground_y, b,
                                          lean_offset, bob_offset, w, h)
        # 1. 흙 파편 (땅 위로 튀는 것)
        self._draw_dirt_fx(surface, cx, ground_y, b, lean_offset, bob_offset, p)
        # 2. 몸체 솟아오름 (히트 또는 회전발톱)
        if (self.is_hit or self.spinning_claw_active) and effective_emerge > 0.05:
            self._draw_body_emerging(surface, cx, ground_y, b, lean_offset,
                                     bob_offset, effective_emerge, p)
        # 3. 땅 표면 (현재 미사용)
        self._draw_ground(surface, cx, ground_y, b, lean_offset, bob_offset, p)
        # 4. 발톱 스크래치 이펙트 (히트 시)
        if self.is_hit:
            self._draw_claw_effect(surface, cx, ground_y, b, lean_offset, p)
        # 5. 회전발톱 스와이프 팔 이펙트
        if self.spinning_claw_active and sc_emerge > 0.3:
            self._draw_spinning_claw_arm(surface, cx, ground_y, b,
                                          lean_offset, bob_offset, sc_emerge, p)

    def _get_palette(self, flash=0.0):
        def _f(base):
            return tuple(min(255, int(c + (255 - c) * flash)) for c in base)

        return {
            # 몸체 (갈색 — 디그다풍)
            "body": _f((175, 135, 95)),
            "body_light": _f((200, 165, 120)),
            "body_dark": _f((140, 105, 70)),
            "body_edge": _f((120, 90, 60)),
            # 얼굴
            "face_bg": _f((175, 135, 95)),
            # 눈 (큰 동그란 눈)
            "eye_white": _f((255, 255, 255)),
            "eye_black": _f((20, 15, 10)),
            "eye_shine": _f((255, 255, 255)),
            # 코 (분홍 타원)
            "nose": _f((225, 150, 145)),
            "nose_light": _f((245, 180, 170)),
            "nose_dark": _f((190, 120, 110)),
            # 입
            "mouth": _f((100, 65, 40)),
            # 이빨 (솟아오를 때 보이는 큰 이빨)
            "tooth": _f((250, 245, 235)),
            "tooth_shadow": _f((210, 200, 185)),
            # 발톱
            "claw": _f((240, 235, 225)),
            "claw_shine": _f((255, 255, 255)),
            "claw_shadow": _f((180, 170, 155)),
            # 왕관
            "crown_gold": _f((215, 180, 55)),
            "crown_gold_light": _f((245, 215, 95)),
            "crown_gold_dark": _f((175, 140, 35)),
            "gem_red": _f((205, 50, 45)),
            "gem_green": _f((50, 185, 70)),
            "gem_blue": _f((60, 95, 205)),
            "gem_shine": _f((255, 255, 255)),
            # 땅/흙
            "ground": _f((110, 80, 48)),
            "ground_light": _f((145, 110, 68)),
            "ground_dark": _f((75, 52, 30)),
            "ground_edge": _f((90, 65, 38)),
            "rock": _f((155, 150, 140)),
            "rock_light": _f((185, 180, 170)),
            "rock_dark": _f((120, 115, 105)),
            # 이펙트
            "scratch_white": (255, 255, 240),
            "scratch_yellow": (255, 230, 100),
            "scratch_red": (255, 120, 80),
        }

    # ------- 지하 이동 표면 왜곡 (평소 상태) -------
    def _draw_underground_ripple(self, surface, cx, ground_y, b,
                                  lean_offset, bob_offset, w, h):
        """보스가 땅속에 있을 때 흙 융기 이펙트 — 깜빡임 없이 항상 표시"""
        gcx = cx + lean_offset
        gy = ground_y + bob_offset
        t = self.time

        speed_factor = min(self.velocity / 60.0, 2.0) if self.direction != 0 else 0

        # --- 단일 알파 서피스 (매 프레임 1개만 생성) ---
        fx_surf = pygame.Surface((w, h), pygame.SRCALPHA)

        # === 1. 흙 융기 돔 (두더지 위치를 보여주는 볼록한 흙덩이) ===
        # 숨쉬기: 부드럽게 위아래 (항상 보임)
        breath = _sin(t * 2.0) * 2.0
        mound_w = int(w * 0.45)
        mound_h = int(8 + breath + speed_factor * 3)

        # 어두운 흙 그림자 (아래)
        pygame.draw.ellipse(fx_surf, (90, 65, 40, 100),
                           (gcx - mound_w // 2, gy - mound_h // 2 + 2,
                            mound_w, mound_h))
        # 밝은 흙 융기 (위)
        pygame.draw.ellipse(fx_surf, (145, 110, 70, 120),
                           (gcx - mound_w // 2 + 1, gy - mound_h // 2,
                            mound_w - 2, mound_h - 2))
        # 하이라이트
        hl_w = int(mound_w * 0.5)
        hl_h = max(2, int(mound_h * 0.35))
        pygame.draw.ellipse(fx_surf, (180, 150, 100, 70),
                           (gcx - hl_w // 2, gy - mound_h // 2 + 1,
                            hl_w, hl_h))

        # === 2. 균열선 (융기 주변 갈라진 틈) ===
        crack_col = (60, 45, 30, 90)
        # 좌측 균열
        cl_x = gcx - mound_w // 2 - 3
        cl_y = gy + int(_sin(t * 1.0) * 1)
        pygame.draw.line(fx_surf, crack_col,
                        (cl_x, cl_y - 2), (cl_x - 5, cl_y + 3), 1)
        pygame.draw.line(fx_surf, crack_col,
                        (cl_x - 5, cl_y + 3), (cl_x - 3, cl_y + 7), 1)
        # 우측 균열
        cr_x = gcx + mound_w // 2 + 3
        cr_y = gy + int(_sin(t * 1.0 + 1.5) * 1)
        pygame.draw.line(fx_surf, crack_col,
                        (cr_x, cr_y - 2), (cr_x + 5, cr_y + 3), 1)
        pygame.draw.line(fx_surf, crack_col,
                        (cr_x + 5, cr_y + 3), (cr_x + 3, cr_y + 7), 1)

        # === 3. 이동 시 추가 균열 + 흙 튀김 흔적 ===
        if speed_factor > 0.15:
            move_alpha = int(min(speed_factor, 1.5) * 60)
            trail_dir = -self.direction  # 이동 반대쪽에 흔적
            for ti in range(3):
                tx = gcx + trail_dir * (mound_w // 2 + 6 + ti * 8)
                ty = gy + int(_sin(t * 2.5 + ti * 1.2) * 2)
                sz = max(2, int(4 - ti))
                pygame.draw.ellipse(fx_surf, (120, 90, 55, move_alpha - ti * 15),
                                   (tx - sz, ty - sz // 2, sz * 2, sz))

        surface.blit(fx_surf, (0, 0))

    # ------- 땅 표면 (현재 미사용) -------
    def _draw_ground(self, surface, cx, ground_y, b, lean_offset, bob_offset, p):
        pass

    # ------- 솟아오르는 몸체 -------
    def _draw_body_emerging(self, surface, cx, ground_y, b, lean_offset,
                             bob_offset, emerge, p):
        """디그다 스타일 몸체 — emerge 양에 따라 땅에서 나옴"""
        gcx = cx + lean_offset
        gy = ground_y + bob_offset

        full_body_h = int(4.5 * b)
        body_w = int(2.6 * b)

        visible_h = int(full_body_h * emerge)
        if visible_h < 3:
            return

        body_top = gy - visible_h

        # 클리핑 서피스
        clip_surf = pygame.Surface((int(body_w + 4 * b), visible_h + int(0.5 * b)),
                                   pygame.SRCALPHA)
        clip_cx = clip_surf.get_width() // 2
        clip_body_top = 0

        hit_shake_x = 0
        if self.is_hit:
            hit_shake_x = int(_sin(self.time * 50) * self.hit_intensity * 1.5)

        # === 몸통 (둥근 돔형) ===
        dome_rect = pygame.Rect(
            clip_cx - body_w // 2 + hit_shake_x,
            clip_body_top,
            body_w, int(body_w * 1.1)
        )
        lower_rect = pygame.Rect(
            clip_cx - body_w // 2 + hit_shake_x,
            clip_body_top + int(body_w * 0.5),
            body_w, visible_h - int(body_w * 0.5)
        )
        pygame.draw.ellipse(clip_surf, p["body_dark"], dome_rect.move(2, 2))
        pygame.draw.rect(clip_surf, p["body_dark"], lower_rect.move(2, 2))
        pygame.draw.ellipse(clip_surf, p["body"], dome_rect)
        pygame.draw.rect(clip_surf, p["body"], lower_rect)
        seam_rect = pygame.Rect(
            clip_cx - body_w // 2 + hit_shake_x,
            clip_body_top + int(body_w * 0.4),
            body_w, int(body_w * 0.3)
        )
        pygame.draw.rect(clip_surf, p["body"], seam_rect)

        # 하이라이트
        hl_w = int(body_w * 0.35)
        hl_h = int(body_w * 0.6)
        hl_rect = pygame.Rect(
            clip_cx - body_w // 4 + hit_shake_x - int(0.1 * b),
            clip_body_top + int(0.2 * b),
            hl_w, hl_h
        )
        hl_surf = pygame.Surface((hl_w, hl_h), pygame.SRCALPHA)
        pygame.draw.ellipse(hl_surf, (*p["body_light"], 100), (0, 0, hl_w, hl_h))
        clip_surf.blit(hl_surf, hl_rect.topleft)

        # === 얼굴 (emerge > 0.4) ===
        if emerge > 0.4:
            face_cy = clip_body_top + int(body_w * 0.42)
            face_cx_adj = clip_cx + hit_shake_x

            # 눈
            for side in [-1, 1]:
                eye_x = face_cx_adj + side * int(0.45 * b)
                eye_y = face_cy - int(0.15 * b)
                ew = max(3, int(0.22 * b))
                eh = max(3, int(0.25 * b))
                pygame.draw.ellipse(clip_surf, p["eye_black"],
                                  (eye_x - ew, eye_y - eh, ew * 2, eh * 2))
                sh_r = max(1, int(0.08 * b))
                pygame.draw.circle(clip_surf, p["eye_shine"],
                                 (eye_x - int(0.05 * b),
                                  eye_y - int(0.06 * b)), sh_r)

            # 코
            nose_cx_local = face_cx_adj
            nose_cy_local = face_cy + int(0.35 * b)
            nose_w = max(4, int(0.45 * b))
            nose_h = max(3, int(0.3 * b))
            pygame.draw.ellipse(clip_surf, p["nose_dark"],
                              (nose_cx_local - nose_w // 2 + 1,
                               nose_cy_local - nose_h // 2 + 1,
                               nose_w, nose_h))
            pygame.draw.ellipse(clip_surf, p["nose"],
                              (nose_cx_local - nose_w // 2,
                               nose_cy_local - nose_h // 2,
                               nose_w, nose_h))
            nh_r = max(1, int(0.1 * b))
            pygame.draw.circle(clip_surf, p["nose_light"],
                             (nose_cx_local - int(0.08 * b),
                              nose_cy_local - int(0.06 * b)), nh_r)

            # 입 (히트 시에만 벌어짐)
            if self.is_hit:
                progress = self.hit_timer / self.hit_duration
                mouth_open = 0.0
                if progress < 0.55:
                    mouth_open = min(1.0, progress / 0.15)
                else:
                    mouth_open = max(0.0, 1.0 - (progress - 0.55) / 0.2)

                if mouth_open > 0.05:
                    mouth_y = nose_cy_local + int(0.3 * b)
                    mouth_w = int(0.55 * b * mouth_open)
                    mouth_h = int(0.3 * b * mouth_open)
                    mouth_rect = pygame.Rect(
                        nose_cx_local - mouth_w // 2,
                        mouth_y - mouth_h // 2,
                        mouth_w, mouth_h
                    )
                    pygame.draw.ellipse(clip_surf, p["mouth"], mouth_rect)

                    if mouth_open > 0.3:
                        for side in [-1, 1]:
                            tx = nose_cx_local + side * int(0.12 * b)
                            ty_top = mouth_y - mouth_h // 2
                            ty_bot = ty_top + int(0.18 * b * mouth_open)
                            tooth_pts = [
                                (tx - int(0.05 * b), ty_top),
                                (tx + int(0.05 * b), ty_top),
                                (tx, ty_bot),
                            ]
                            pygame.draw.polygon(clip_surf, p["tooth"], tooth_pts)
                            pygame.draw.polygon(clip_surf, p["tooth_shadow"],
                                              tooth_pts, 1)

        # === 왕관 (emerge > 0.6) ===
        if emerge > 0.6:
            crown_cx_local = clip_cx + hit_shake_x
            crown_y = clip_body_top + int(0.05 * b)
            crown_tilt = 0
            if self.is_hit:
                crown_tilt = int(self.hit_intensity * self.hit_direction * 0.2 * b)
            self._draw_crown_on(clip_surf, crown_cx_local + crown_tilt,
                               crown_y, b, p)

        # === 팔 + 발톱 ===
        if self.is_hit and emerge > 0.3:
            self._draw_striking_arms(clip_surf, clip_cx, clip_body_top,
                                     body_w, visible_h, b, p, hit_shake_x)

        # 회전발톱 모션: 몸 비틀기 (클립서피스 자체를 회전)
        if self.spinning_claw_active:
            sc_prog = self.spinning_claw_timer / self.spinning_claw_duration
            # 페이즈: 0~0.25 역방향 와인드업, 0.25~0.55 강렬한 스와이프, 0.55~1.0 복귀
            if sc_prog < 0.25:
                # 와인드업: 스와이프 반대 방향으로 몸을 비틂
                t = sc_prog / 0.25
                twist_deg = -self.spinning_claw_direction * 18 * (t ** 0.6)
            elif sc_prog < 0.55:
                # 스와이프: 빠르게 반대 방향으로 회전 (120도 궤적감)
                t = (sc_prog - 0.25) / 0.30
                # ease-out-back으로 강렬한 스냅
                overshoot = 1.0 + 0.3 * _sin(t * 3.14159)
                twist_deg = self.spinning_claw_direction * (
                    -18 + (18 + 32) * min(t * overshoot, 1.2))
            else:
                # 복귀: 서서히 원래 자세로
                t = (sc_prog - 0.55) / 0.45
                twist_deg = self.spinning_claw_direction * 32 * (1.0 - t ** 1.5)

            # 몸 떨림 추가 (스와이프 순간)
            if 0.25 <= sc_prog < 0.55:
                shake = _sin(self.time * 80) * 2.5 * (1.0 - (sc_prog - 0.25) / 0.30)
                twist_deg += shake

            rotated = pygame.transform.rotate(clip_surf, twist_deg)
            rot_rect = rotated.get_rect(center=(
                gcx, body_top + clip_surf.get_height() // 2))
            surface.blit(rotated, rot_rect.topleft)
        else:
            surface.blit(clip_surf,
                        (gcx - clip_surf.get_width() // 2,
                         body_top))

    # ------- 땅에서 직접 솟아나는 팔+발톱 (몸체 없음) -------
    def _draw_arms_from_ground(self, surface, cx, ground_y, b,
                                lean_offset, bob_offset, p):
        """히트 시 땅에서 직접 팔+발톱만 솟아나옴 (몸체/얼굴 전혀 없음)"""
        gcx = cx + lean_offset
        gy = ground_y + bob_offset
        hit_shake_x = int(_sin(self.time * 50) * self.hit_intensity * 1.5) if self.is_hit else 0
        progress = self.hit_timer / self.hit_duration

        # 팔 출현 타이밍
        arm_emerge = 0.0
        claw_spread = 0.0
        if progress < 0.15:
            arm_emerge = (progress / 0.15) ** 0.5
            claw_spread = 0.3 * arm_emerge
        elif progress < 0.25:
            arm_emerge = 1.0
            t = (progress - 0.15) / 0.10
            claw_spread = 0.3 + 0.7 * t
        elif progress < 0.50:
            arm_emerge = 1.0
            claw_spread = 1.0
        elif progress < 0.65:
            arm_emerge = 1.0 - (progress - 0.50) / 0.15
            claw_spread = 1.0 * arm_emerge
        else:
            arm_emerge = 0.0

        if arm_emerge < 0.05:
            return

        for side in [-1, 1]:
            is_strike_side = (side == self.hit_direction)
            scale = 1.4 if is_strike_side else 0.95

            # 팔 원점: 땅 표면 양옆에서 솟아나옴
            origin_x = gcx + side * int(1.2 * b) + hit_shake_x
            origin_y = gy  # 땅 표면

            arm_len = int(2.0 * b * arm_emerge * scale)
            arm_angle = side * (0.5 + claw_spread * 0.35)

            # 팔꿈치 (위로 솟아나옴)
            elbow_x = origin_x + int(_sin(arm_angle) * arm_len * 0.45)
            elbow_y = origin_y - int(arm_len * 0.5 * arm_emerge)

            # 손목
            wrist_x = elbow_x + int(_sin(arm_angle * 1.3) * arm_len * 0.45)
            wrist_y = elbow_y - int(arm_len * 0.25)

            # 내려치기 모션
            if is_strike_side and 0.20 < progress < 0.50:
                strike_t = (progress - 0.20) / 0.30
                wrist_y += int(1.8 * b * _sin(strike_t * math.pi))

            # 상완
            arm_thick = max(3, int(0.4 * b * scale))
            pygame.draw.line(surface, p["body_dark"],
                           (origin_x, origin_y),
                           (elbow_x, elbow_y), arm_thick + 2)
            pygame.draw.line(surface, p["body"],
                           (origin_x, origin_y),
                           (elbow_x, elbow_y), arm_thick)

            # 하완
            pygame.draw.line(surface, p["body_dark"],
                           (elbow_x, elbow_y),
                           (int(wrist_x), int(wrist_y)), arm_thick + 1)
            pygame.draw.line(surface, p["body_light"],
                           (elbow_x, elbow_y),
                           (int(wrist_x), int(wrist_y)), arm_thick - 1)

            # 거대한 손
            hand_r = max(4, int(0.5 * b * scale))
            hand_cx = int(wrist_x)
            hand_cy = int(wrist_y)

            pygame.draw.circle(surface, p["body_dark"],
                             (hand_cx + 1, hand_cy + 1), hand_r)
            pygame.draw.circle(surface, p["body"],
                             (hand_cx, hand_cy), hand_r)
            pygame.draw.circle(surface, p["body_light"],
                             (hand_cx - max(1, int(0.06 * b)),
                              hand_cy - max(1, int(0.06 * b))),
                             max(1, int(hand_r * 0.4)))

            # 발톱 5개 (부채꼴 — 위쪽으로 향함)
            num_claws = 5
            spread_angle = (0.4 + claw_spread * 0.5) * math.pi
            for ci in range(num_claws):
                ca = -spread_angle / 2 + ci * (spread_angle / (num_claws - 1))
                ca += side * 0.15

                claw_len = int(0.55 * b * scale * (0.8 + claw_spread * 0.4))
                center_bonus = 1.0 - abs(ci - 2) * 0.12
                claw_len = int(claw_len * center_bonus)

                claw_sx = hand_cx + int(_sin(ca) * hand_r * 0.8)
                claw_sy = hand_cy - int(_cos(ca) * hand_r * 0.5)
                claw_ex = claw_sx + int(_sin(ca) * claw_len)
                claw_ey = claw_sy - int(_cos(ca) * claw_len * 0.6)

                mid_x = (claw_sx + claw_ex) // 2 + int(_sin(ca) * 0.12 * b)
                mid_y = (claw_sy + claw_ey) // 2

                claw_w = max(2, int(0.12 * b * scale))
                pygame.draw.line(surface, p["claw_shadow"],
                               (claw_sx + 1, claw_sy + 1),
                               (claw_ex + 1, claw_ey + 1), claw_w)
                pygame.draw.line(surface, p["claw"],
                               (claw_sx, claw_sy),
                               (mid_x, mid_y), claw_w)
                pygame.draw.line(surface, p["claw"],
                               (mid_x, mid_y),
                               (claw_ex, claw_ey), max(1, claw_w - 1))
                pygame.draw.line(surface, p["claw_shine"],
                               (claw_sx, claw_sy),
                               (mid_x, mid_y), 1)
                pygame.draw.circle(surface, p["claw_shine"],
                                 (claw_ex, claw_ey),
                                 max(1, int(0.04 * b)))

    # ------- 타격 팔 + 발톱 (레거시 — 미사용) -------
    def _draw_striking_arms(self, surf, cx, body_top, body_w, visible_h,
                             b, p, shake_x):
        """히트 시 양쪽에서 뻗어나오는 팔 + 거대한 발톱"""
        progress = self.hit_timer / self.hit_duration

        # 팔 출현 타이밍
        arm_emerge = 0.0
        claw_spread = 0.0
        if progress < 0.15:
            arm_emerge = (progress / 0.15) ** 0.5
            claw_spread = 0.3 * arm_emerge
        elif progress < 0.25:
            arm_emerge = 1.0
            t = (progress - 0.15) / 0.10
            claw_spread = 0.3 + 0.7 * t  # 발톱 펼침
        elif progress < 0.50:
            arm_emerge = 1.0
            claw_spread = 1.0
        elif progress < 0.65:
            arm_emerge = 1.0 - (progress - 0.50) / 0.15
            claw_spread = 1.0 * arm_emerge
        else:
            arm_emerge = 0.0

        if arm_emerge < 0.05:
            return

        for side in [-1, 1]:
            # 타격 방향 팔이 더 크게
            is_strike_side = (side == self.hit_direction)
            scale = 1.3 if is_strike_side else 0.9

            # 어깨 위치 (몸체 양옆)
            shoulder_x = cx + side * int(body_w // 2 + 0.1 * b) + shake_x
            shoulder_y = body_top + int(visible_h * 0.35)

            # 팔 뻗기 정도
            arm_len = int(1.8 * b * arm_emerge * scale)
            arm_angle = side * (0.6 + claw_spread * 0.3)

            # 팔꿈치
            elbow_x = shoulder_x + int(_sin(arm_angle) * arm_len * 0.5)
            elbow_y = shoulder_y + int(_cos(arm_angle) * arm_len * 0.3)

            # 손목
            wrist_x = elbow_x + int(_sin(arm_angle * 1.2) * arm_len * 0.5)
            wrist_y = elbow_y + int(arm_len * 0.4)

            # 히트 시 내려치기 모션
            if is_strike_side and 0.20 < progress < 0.50:
                strike_t = (progress - 0.20) / 0.30
                wrist_y += int(1.5 * b * _sin(strike_t * math.pi))

            # 상완
            arm_thick = max(2, int(0.35 * b * scale))
            pygame.draw.line(surf, p["body_dark"],
                           (shoulder_x, shoulder_y),
                           (elbow_x, elbow_y), arm_thick + 1)
            pygame.draw.line(surf, p["body"],
                           (shoulder_x, shoulder_y),
                           (elbow_x, elbow_y), arm_thick)

            # 하완
            pygame.draw.line(surf, p["body_dark"],
                           (elbow_x, elbow_y),
                           (int(wrist_x), int(wrist_y)), arm_thick)
            pygame.draw.line(surf, p["body_light"],
                           (elbow_x, elbow_y),
                           (int(wrist_x), int(wrist_y)), max(1, arm_thick - 1))

            # === 거대한 손 ===
            hand_r = max(3, int(0.45 * b * scale))
            hand_cx = int(wrist_x)
            hand_cy = int(wrist_y) + int(0.1 * b)

            pygame.draw.circle(surf, p["body_dark"],
                             (hand_cx + 1, hand_cy + 1), hand_r)
            pygame.draw.circle(surf, p["body"],
                             (hand_cx, hand_cy), hand_r)
            pygame.draw.circle(surf, p["body_light"],
                             (hand_cx - int(0.05 * b),
                              hand_cy - int(0.05 * b)),
                             max(1, int(hand_r * 0.4)))

            # === 발톱 5개 (부채꼴) ===
            num_claws = 5
            spread_angle = (0.4 + claw_spread * 0.5) * math.pi
            for ci in range(num_claws):
                ca = -spread_angle / 2 + ci * (spread_angle / (num_claws - 1))
                ca += side * 0.2  # 바깥쪽으로 약간 치우침

                claw_len = int(0.5 * b * scale * (0.8 + claw_spread * 0.4))
                # 중앙 발톱이 가장 김
                center_bonus = 1.0 - abs(ci - 2) * 0.12
                claw_len = int(claw_len * center_bonus)

                claw_sx = hand_cx + int(_sin(ca) * hand_r * 0.8)
                claw_sy = hand_cy + int(_cos(ca) * hand_r * 0.5)
                claw_ex = claw_sx + int(_sin(ca) * claw_len)
                claw_ey = claw_sy + int(_cos(ca) * claw_len * 0.7) + claw_len // 2

                # 발톱 곡선 (약간 휘어짐)
                mid_x = (claw_sx + claw_ex) // 2 + int(_sin(ca) * 0.15 * b)
                mid_y = (claw_sy + claw_ey) // 2

                # 그림자
                claw_w = max(2, int(0.1 * b * scale))
                pygame.draw.line(surf, p["claw_shadow"],
                               (claw_sx + 1, claw_sy + 1),
                               (claw_ex + 1, claw_ey + 1), claw_w)
                # 본체
                pygame.draw.line(surf, p["claw"],
                               (claw_sx, claw_sy),
                               (mid_x, mid_y), claw_w)
                pygame.draw.line(surf, p["claw"],
                               (mid_x, mid_y),
                               (claw_ex, claw_ey), max(1, claw_w - 1))
                # 하이라이트
                pygame.draw.line(surf, p["claw_shine"],
                               (claw_sx, claw_sy),
                               (mid_x, mid_y), 1)
                # 끝 뾰족 점
                pygame.draw.circle(surf, p["claw_shine"],
                                 (claw_ex, claw_ey),
                                 max(1, int(0.03 * b)))

    # ------- 회전발톱 스와이프 팔 -------
    def _draw_spinning_claw_arm(self, surface, cx, ground_y, b,
                                 lean_offset, bob_offset, sc_emerge, p):
        """회전발톱 발동 시 거대한 팔이 120도 호를 그리며 후려치는 모션"""
        sc_prog = self.spinning_claw_timer / self.spinning_claw_duration
        d = self.spinning_claw_direction
        gcx = cx + lean_offset
        gy = ground_y + bob_offset

        # 팔 출현 정도
        arm_emerge = min(1.0, sc_emerge * 1.5)
        if arm_emerge < 0.1:
            return

        # 스와이프 각도 (라디안) — 120도 호 (2π/3)
        # 와인드업(0~0.25): 시작 각도로 이동
        # 스와이프(0.25~0.55): 120도 호를 빠르게 이동
        # 복귀(0.55~1.0): 사라짐
        arc_120 = math.pi * 2.0 / 3.0  # 120도

        if sc_prog < 0.25:
            # 와인드업: 팔이 솟아오르며 반대쪽으로 준비
            t = sc_prog / 0.25
            arm_angle = -d * (arc_120 * 0.3) * (t ** 0.5)
            arm_alpha = int(255 * min(t * 2, 1.0))
        elif sc_prog < 0.55:
            # 스와이프: 120도 호를 빠르게 횡단
            t = (sc_prog - 0.25) / 0.30
            # ease-out-cubic
            et = 1.0 - (1.0 - t) ** 3
            start_angle = -d * (arc_120 * 0.3)
            end_angle = d * (arc_120 * 0.7)
            arm_angle = start_angle + (end_angle - start_angle) * et
            arm_alpha = 255
        else:
            # 복귀: 팔 사라짐
            t = (sc_prog - 0.55) / 0.45
            arm_angle = d * (arc_120 * 0.7) * (1.0 - t)
            arm_alpha = int(255 * (1.0 - t ** 1.5))

        if arm_alpha < 5:
            return

        # 이펙트 서피스
        fx_w = int(10 * b)
        fx_h = int(8 * b)
        fx_surf = pygame.Surface((fx_w, fx_h), pygame.SRCALPHA)
        fx_cx = fx_w // 2
        fx_cy = int(fx_h * 0.45)

        # 어깨 (몸체 옆)
        shoulder_x = fx_cx
        shoulder_y = fx_cy

        # 팔 길이 (거대)
        arm_len = int(3.5 * b * arm_emerge)

        # 팔꿈치 좌표
        elbow_x = shoulder_x + int(_sin(arm_angle) * arm_len * 0.55)
        elbow_y = shoulder_y + int(_cos(arm_angle) * arm_len * 0.35)

        # 손목 좌표
        wrist_x = shoulder_x + int(_sin(arm_angle) * arm_len)
        wrist_y = shoulder_y + int(_cos(arm_angle) * arm_len * 0.5)

        # === 팔 렌더링 ===
        arm_thick = max(3, int(0.45 * b))
        # 상완 (그림자 + 본체)
        pygame.draw.line(fx_surf, (*p["body_dark"], arm_alpha),
                        (shoulder_x, shoulder_y),
                        (elbow_x, elbow_y), arm_thick + 2)
        pygame.draw.line(fx_surf, (*p["body"], arm_alpha),
                        (shoulder_x, shoulder_y),
                        (elbow_x, elbow_y), arm_thick)
        # 하완
        pygame.draw.line(fx_surf, (*p["body_dark"], arm_alpha),
                        (elbow_x, elbow_y),
                        (wrist_x, wrist_y), arm_thick + 1)
        pygame.draw.line(fx_surf, (*p["body_light"], arm_alpha),
                        (elbow_x, elbow_y),
                        (wrist_x, wrist_y), arm_thick)

        # === 거대한 손 ===
        hand_r = max(4, int(0.55 * b))
        pygame.draw.circle(fx_surf, (*p["body_dark"], arm_alpha),
                          (wrist_x + 1, wrist_y + 1), hand_r)
        pygame.draw.circle(fx_surf, (*p["body"], arm_alpha),
                          (wrist_x, wrist_y), hand_r)
        pygame.draw.circle(fx_surf, (*p["body_light"], arm_alpha // 2),
                          (wrist_x - int(0.06 * b),
                           wrist_y - int(0.06 * b)),
                          max(1, int(hand_r * 0.35)))

        # === 발톱 5개 (부채꼴, 스와이프 방향으로 펼침) ===
        num_claws = 5
        claw_spread = 0.7 * math.pi  # 부채꼴 각도
        for ci in range(num_claws):
            ca = arm_angle - claw_spread / 2 + ci * (claw_spread / (num_claws - 1))
            ca += d * 0.15

            claw_len = int(0.65 * b * (0.85 + 0.15 * (1.0 - abs(ci - 2) * 0.15)))
            claw_sx = wrist_x + int(_sin(ca) * hand_r * 0.7)
            claw_sy = wrist_y + int(_cos(ca) * hand_r * 0.5)
            claw_ex = claw_sx + int(_sin(ca) * claw_len)
            claw_ey = claw_sy + int(_cos(ca) * claw_len * 0.6) + claw_len // 3

            claw_w = max(2, int(0.12 * b))
            # 그림자
            pygame.draw.line(fx_surf, (*p["claw_shadow"], arm_alpha),
                            (claw_sx + 1, claw_sy + 1),
                            (claw_ex + 1, claw_ey + 1), claw_w)
            # 본체
            pygame.draw.line(fx_surf, (*p["claw"], arm_alpha),
                            (claw_sx, claw_sy),
                            (claw_ex, claw_ey), claw_w)
            # 하이라이트
            pygame.draw.line(fx_surf, (*p["claw_shine"], arm_alpha),
                            (claw_sx, claw_sy),
                            (claw_ex, claw_ey), 1)
            # 끝 점
            pygame.draw.circle(fx_surf, (*p["claw_shine"], arm_alpha),
                              (claw_ex, claw_ey),
                              max(1, int(0.04 * b)))

        # === 스와이프 궤적 잔상 (스와이프 페이즈에서만) ===
        if 0.25 <= sc_prog < 0.55:
            trail_t = (sc_prog - 0.25) / 0.30
            trail_alpha = int(180 * (1.0 - trail_t))
            for ti in range(4):
                trail_angle = arm_angle - d * 0.18 * (ti + 1)
                trail_ex = shoulder_x + int(_sin(trail_angle) * arm_len * (0.9 - ti * 0.1))
                trail_ey = shoulder_y + int(_cos(trail_angle) * arm_len * 0.5 * (0.9 - ti * 0.1))
                ta = max(0, trail_alpha - ti * 40)
                if ta > 0:
                    pygame.draw.line(fx_surf, (255, 230, 100, ta),
                                    (shoulder_x, shoulder_y),
                                    (trail_ex, trail_ey), max(1, 3 - ti))

        # === 충격파 라인 (스와이프 절정) ===
        if 0.35 <= sc_prog < 0.50:
            impact_t = (sc_prog - 0.35) / 0.15
            impact_alpha = int(200 * (1.0 - impact_t))
            for si in range(3):
                s_angle = arm_angle + d * (0.1 + si * 0.08)
                s_len = int(arm_len * (1.2 + si * 0.15) * impact_t)
                sx = shoulder_x + int(_sin(s_angle) * s_len)
                sy = shoulder_y + int(_cos(s_angle) * s_len * 0.4)
                ia = max(0, impact_alpha - si * 50)
                if ia > 0:
                    pygame.draw.line(fx_surf, (255, 255, 240, ia),
                                    (shoulder_x, shoulder_y),
                                    (sx, sy), max(1, 2 - si))

        # 서피스를 게임 좌표에 블릿
        blit_x = gcx - fx_cx
        blit_y = (gy - int(sc_emerge * 3.0 * b)) - fx_cy
        surface.blit(fx_surf, (blit_x, blit_y))

    # ------- 왕관 -------
    def _draw_crown_on(self, surf, cx, y, b, p):
        """왕관 렌더링 (서피스 위에)"""
        # 밴드
        band_w = int(1.6 * b)
        band_h = int(0.35 * b)
        band_rect = pygame.Rect(cx - band_w // 2, y, band_w, band_h)
        pygame.draw.ellipse(surf, p["crown_gold_dark"], band_rect.move(1, 1))
        pygame.draw.ellipse(surf, p["crown_gold"], band_rect)
        pygame.draw.ellipse(surf, p["crown_gold_light"],
                          band_rect.inflate(-int(0.2 * b), -int(0.08 * b)), 1)

        # 꼭대기 5개
        for pi in range(5):
            t = (pi - 2) / 2.0
            px = cx + int(t * band_w * 0.38)
            base_y = y + int(0.05 * b)
            height_f = 1.0 - abs(t) * 0.35
            tip_y = base_y - int(0.5 * b * height_f)
            pw = int(0.15 * b)
            pts = [
                (px - pw, base_y),
                (px + pw, base_y),
                (px, tip_y),
            ]
            pygame.draw.polygon(surf, p["crown_gold"], pts)
            pygame.draw.polygon(surf, p["crown_gold_light"], pts, 1)

        # 보석 3개
        gems = [(-0.3, p["gem_red"]), (0, p["gem_green"]), (0.3, p["gem_blue"])]
        for gx_off, gc in gems:
            gx = cx + int(gx_off * b)
            gy = y + int(0.13 * b)
            gr = max(2, int(0.09 * b))
            pygame.draw.circle(surf, gc, (gx, gy), gr)
            pygame.draw.circle(surf, p["gem_shine"],
                             (gx - 1, gy - 1), max(1, gr // 2))
            pygame.draw.circle(surf, p["crown_gold_dark"], (gx, gy), gr, 1)

    # ------- 흙 파편 -------
    def _draw_dirt_fx(self, surface, cx, ground_y, b, lean_offset, bob_offset, p):
        base_x = cx + lean_offset
        base_y = ground_y + bob_offset
        for dp in self._dirt_particles:
            alpha = max(0, min(255, int(dp["life"] * 200)))
            px = int(base_x + dp["x"] * b * 2)
            py = int(base_y + dp["y"] * b * 2)
            sz = max(1, int(dp["size"] * b))
            if alpha > 40:
                color = p["ground"] if dp["life"] > 0.5 else p["ground_dark"]
                dirt_s = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
                pygame.draw.circle(dirt_s, (*color, alpha), (sz, sz), sz)
                surface.blit(dirt_s, (px - sz, py - sz))

    # ------- 발톱 스크래치 이펙트 -------
    def _draw_claw_effect(self, surface, cx, ground_y, b, lean_offset, p):
        if not self.is_hit:
            return
        progress = self.hit_timer / self.hit_duration
        if progress < 0.20 or progress > 0.65:
            return

        if progress < 0.35:
            alpha = int(255 * ((progress - 0.20) / 0.15))
        else:
            alpha = int(255 * (1.0 - (progress - 0.35) / 0.30))
        alpha = max(0, min(255, alpha))
        if alpha < 10:
            return

        scx = cx + self.hit_direction * int(1.8 * b) + lean_offset
        scy = ground_y - int(1.5 * b)

        scratch_s = pygame.Surface((int(3 * b), int(3 * b)), pygame.SRCALPHA)
        sw, sh = scratch_s.get_size()

        for i in range(3):
            sx = sw // 2 + (i - 1) * int(0.4 * b)
            line_len = int(2.2 * b)
            sy = int(0.2 * b)
            # 3색 레이어
            pygame.draw.line(scratch_s, (*p["scratch_red"], alpha // 2),
                           (sx - 1, sy), (sx - 1 + int(0.06 * b * i),
                            sy + line_len), 3)
            pygame.draw.line(scratch_s, (*p["scratch_yellow"], alpha),
                           (sx, sy), (sx + int(0.06 * b * i),
                            sy + line_len), 2)
            pygame.draw.line(scratch_s, (*p["scratch_white"], alpha),
                           (sx, sy), (sx + int(0.06 * b * i),
                            sy + line_len), 1)

        surface.blit(scratch_s, (scx - sw // 2, scy - sh // 2))


# ===================================================================
#  싱글톤 패턴
# ===================================================================

_molewang_instance = None


def init_molewang_boss_sprite():
    global _molewang_instance
    try:
        _molewang_instance = MolewangBossSprite()
        print("[Sprite] 두더지왕 프로시저럴 스프라이트 초기화 완료")
        return _molewang_instance
    except Exception as e:
        print(f"[Sprite] 두더지왕 스프라이트 초기화 실패: {e}")
        _molewang_instance = None
        return None


def get_molewang_boss_sprite():
    global _molewang_instance
    if _molewang_instance is None:
        init_molewang_boss_sprite()
    return _molewang_instance


def reset_molewang_boss_sprite():
    global _molewang_instance
    if _molewang_instance:
        _molewang_instance.direction = 0
        _molewang_instance.is_hit = False
        _molewang_instance.hit_timer = 0.0
        _molewang_instance.time = 0.0
        _molewang_instance.step_phase = 0.0
        _molewang_instance.lean = 0.0
        _molewang_instance.body_bob = 0.0
        _molewang_instance.emerge_amount = 0.0
        _molewang_instance.spinning_claw_active = False
        _molewang_instance.spinning_claw_timer = 0.0
        _molewang_instance.spinning_claw_emerge = 0.0
        _molewang_instance._dirt_particles = []
