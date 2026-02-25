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

        # 레이어 순서 — 몸체는 절대 안 보임! 땅+팔+이펙트만
        # 1. 흙 파편 (땅 위로 튀는 것)
        self._draw_dirt_fx(surface, cx, ground_y, b, lean_offset, bob_offset, p)
        # 2. 히트 시 팔+발톱만 땅에서 직접 솟아나옴 (몸체 없음)
        if self.is_hit and emerge > 0.05:
            self._draw_arms_from_ground(surface, cx, ground_y, b,
                                        lean_offset, bob_offset, p)
        # 3. 땅 표면 (항상 그림)
        self._draw_ground(surface, cx, ground_y, b, lean_offset, bob_offset, p)
        # 4. 발톱 스크래치 이펙트 (히트 시)
        if self.is_hit:
            self._draw_claw_effect(surface, cx, ground_y, b, lean_offset, p)

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

    # ------- 땅 표면 (항상 표시) -------
    def _draw_ground(self, surface, cx, ground_y, b, lean_offset, bob_offset, p):
        """땅 표면 — 보스 위치에서 울렁거리는 흙더미 + 돌덩이"""
        gcx = cx + lean_offset
        gy = ground_y + bob_offset

        speed_factor = min(self.velocity / 80.0, 1.5) if self.direction != 0 else 0

        # === 흙 울렁거림 (보스가 이동할 때 땅이 출렁) ===
        num_mounds = 9
        mound_half_w = int(2.2 * b)

        # 솟아오를 때 구멍이 더 벌어짐
        hole_expand = self.emerge_amount * 0.8 * b

        for i in range(num_mounds):
            t = (i / (num_mounds - 1)) * 2.0 - 1.0  # -1 ~ 1
            mx = gcx + int(t * mound_half_w)

            # 이동 시 웨이브 울렁거림
            wave_amp = (0.15 + speed_factor * 0.25) * b
            wave = _sin(self.time * 5.0 + t * 3.0 + self.step_phase) * wave_amp
            # 가장자리가 더 크게 울렁
            edge_factor = 0.5 + abs(t) * 0.5
            wave *= edge_factor

            # 솟아오를 때 양옆이 솟음
            emerge_bump = 0.0
            if self.emerge_amount > 0.05:
                dist_from_center = abs(t)
                # 중앙은 구멍 (몸체가 나옴), 양옆은 솟음
                if dist_from_center > 0.3:
                    emerge_bump = self.emerge_amount * 0.5 * b * (dist_from_center - 0.3)

            my = gy + int(wave) - int(emerge_bump)

            # 흙덩이 (타원)
            mound_w = max(4, int(0.6 * b))
            mound_h = max(3, int(0.35 * b + abs(wave) * 0.3))
            pygame.draw.ellipse(surface, p["ground"],
                              (mx - mound_w // 2, my - mound_h // 2,
                               mound_w, mound_h))
            pygame.draw.ellipse(surface, p["ground_light"],
                              (mx - mound_w // 2 + 1, my - mound_h // 2,
                               mound_w - 2, max(2, mound_h // 2)))

        # === 돌덩이 (디그다 특유의 바위들) ===
        rocks = [
            (-1.5, 0.1, 0.4), (-0.8, -0.05, 0.35), (-0.3, 0.08, 0.3),
            (0.3, 0.05, 0.32), (0.9, -0.03, 0.38), (1.6, 0.1, 0.36),
            (-1.1, 0.15, 0.25), (0.0, 0.12, 0.28), (1.2, 0.13, 0.27),
        ]
        for rx, ry, rsize in rocks:
            rock_x = gcx + int(rx * b)
            rock_y = gy + int(ry * b) + int(
                _sin(self.time * 3.0 + rx * 2.5 + self.step_phase * 0.5)
                * speed_factor * 0.12 * b)
            rock_r = max(2, int(rsize * b))

            # 돌 그림자
            pygame.draw.circle(surface, p["rock_dark"],
                             (rock_x + 1, rock_y + 1), rock_r)
            # 돌 본체 — 다각형으로 울퉁불퉁하게
            rock_pts = []
            num_verts = 6
            for vi in range(num_verts):
                angle = (vi / num_verts) * math.pi * 2
                # 불규칙한 반경
                r_var = rock_r * (0.75 + 0.25 * _sin(angle * 3 + rx * 7))
                rock_pts.append((
                    rock_x + int(_cos(angle) * r_var),
                    rock_y + int(_sin(angle) * r_var * 0.7)
                ))
            if len(rock_pts) >= 3:
                pygame.draw.polygon(surface, p["rock"], rock_pts)
                pygame.draw.polygon(surface, p["rock_dark"], rock_pts, 1)
            # 하이라이트
            pygame.draw.circle(surface, p["rock_light"],
                             (rock_x - max(1, rock_r // 4),
                              rock_y - max(1, rock_r // 4)),
                             max(1, rock_r // 3))

        # 땅 아래 영역 채우기 (몸체 하반신 가리기용)
        fill_rect = pygame.Rect(gcx - int(2.5 * b), gy + int(0.15 * b),
                               int(5.0 * b), int(3.0 * b))
        pygame.draw.rect(surface, p["ground_dark"], fill_rect)
        # 위쪽 경계를 울퉁불퉁하게
        for i in range(int(5.0 * b)):
            fx = gcx - int(2.5 * b) + i
            fy_wave = _sin(i * 0.3 + self.time * 2.0) * 0.08 * b
            pygame.draw.line(surface, p["ground"],
                           (fx, gy + int(0.1 * b + fy_wave)),
                           (fx, gy + int(0.3 * b)), 1)

    # ------- 솟아오르는 몸체 -------
    def _draw_body_emerging(self, surface, cx, ground_y, b, lean_offset,
                             bob_offset, emerge, p):
        """디그다 스타일 몸체 — emerge 양에 따라 땅에서 나옴"""
        gcx = cx + lean_offset
        gy = ground_y + bob_offset

        # emerge=1.0일 때 완전히 보이는 몸체 높이
        full_body_h = int(4.5 * b)
        body_w = int(2.6 * b)

        # 현재 보이는 높이
        visible_h = int(full_body_h * emerge)
        if visible_h < 3:
            return

        # 몸체 상단 Y (emerge에 따라 위로 올라감)
        body_top = gy - visible_h

        # === 클리핑: 땅 위 부분만 그리기 ===
        clip_surf = pygame.Surface((int(body_w + 4 * b), visible_h + int(0.5 * b)),
                                   pygame.SRCALPHA)
        clip_cx = clip_surf.get_width() // 2
        clip_body_top = 0

        # 히트 시 흔들림
        hit_shake_x = 0
        if self.is_hit:
            hit_shake_x = int(_sin(self.time * 50) * self.hit_intensity * 1.5)

        # === 몸통 (둥근 돔형 — 디그다 스타일) ===
        # 상단: 둥근 돔
        dome_rect = pygame.Rect(
            clip_cx - body_w // 2 + hit_shake_x,
            clip_body_top,
            body_w, int(body_w * 1.1)
        )
        # 하단: 직선 (땅에 묻힌 부분)
        lower_rect = pygame.Rect(
            clip_cx - body_w // 2 + hit_shake_x,
            clip_body_top + int(body_w * 0.5),
            body_w, visible_h - int(body_w * 0.5)
        )

        # 그림자
        pygame.draw.ellipse(clip_surf, p["body_dark"], dome_rect.move(2, 2))
        pygame.draw.rect(clip_surf, p["body_dark"], lower_rect.move(2, 2))
        # 본체
        pygame.draw.ellipse(clip_surf, p["body"], dome_rect)
        pygame.draw.rect(clip_surf, p["body"], lower_rect)
        # 이음새 부분 부드럽게
        seam_rect = pygame.Rect(
            clip_cx - body_w // 2 + hit_shake_x,
            clip_body_top + int(body_w * 0.4),
            body_w, int(body_w * 0.3)
        )
        pygame.draw.rect(clip_surf, p["body"], seam_rect)

        # 하이라이트 (왼쪽 상단 빛)
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

        # === 얼굴 (emerge > 0.4일 때부터) ===
        if emerge > 0.4:
            face_alpha = min(1.0, (emerge - 0.4) / 0.3)
            face_cy = clip_body_top + int(body_w * 0.42)
            face_cx_adj = clip_cx + hit_shake_x

            # --- 눈 (큰 동그란 눈 — 디그다 스타일) ---
            for side in [-1, 1]:
                eye_x = face_cx_adj + side * int(0.45 * b)
                eye_y = face_cy - int(0.15 * b)

                # 눈 전체 (검정 타원)
                ew = max(3, int(0.22 * b))
                eh = max(3, int(0.25 * b))
                pygame.draw.ellipse(clip_surf, p["eye_black"],
                                  (eye_x - ew, eye_y - eh, ew * 2, eh * 2))
                # 하이라이트 (눈동자 반사)
                sh_r = max(1, int(0.08 * b))
                pygame.draw.circle(clip_surf, p["eye_shine"],
                                 (eye_x - int(0.05 * b),
                                  eye_y - int(0.06 * b)), sh_r)

            # --- 코 (큰 분홍 타원 — 디그다의 핵심 특징) ---
            nose_cx_local = face_cx_adj
            nose_cy_local = face_cy + int(0.35 * b)
            nose_w = max(4, int(0.45 * b))
            nose_h = max(3, int(0.3 * b))

            # 코 그림자
            pygame.draw.ellipse(clip_surf, p["nose_dark"],
                              (nose_cx_local - nose_w // 2 + 1,
                               nose_cy_local - nose_h // 2 + 1,
                               nose_w, nose_h))
            # 코 본체
            pygame.draw.ellipse(clip_surf, p["nose"],
                              (nose_cx_local - nose_w // 2,
                               nose_cy_local - nose_h // 2,
                               nose_w, nose_h))
            # 코 하이라이트
            nh_r = max(1, int(0.1 * b))
            pygame.draw.circle(clip_surf, p["nose_light"],
                             (nose_cx_local - int(0.08 * b),
                              nose_cy_local - int(0.06 * b)), nh_r)

            # --- 입 (히트 시에만 벌어짐) ---
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

                    # 입 안 (어두운 원)
                    mouth_rect = pygame.Rect(
                        nose_cx_local - mouth_w // 2,
                        mouth_y - mouth_h // 2,
                        mouth_w, mouth_h
                    )
                    pygame.draw.ellipse(clip_surf, p["mouth"], mouth_rect)

                    # 이빨 (위쪽 2개)
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

        # === 왕관 (emerge > 0.6일 때부터) ===
        if emerge > 0.6:
            crown_alpha = min(1.0, (emerge - 0.6) / 0.2)
            crown_cx_local = clip_cx + hit_shake_x
            crown_y = clip_body_top + int(0.05 * b)

            # 히트 시 왕관 기울어짐
            crown_tilt = 0
            if self.is_hit:
                crown_tilt = int(self.hit_intensity * self.hit_direction * 0.2 * b)

            self._draw_crown_on(clip_surf, crown_cx_local + crown_tilt,
                               crown_y, b, p)

        # === 팔 + 발톱 (히트 시 양쪽에서 솟아나옴) ===
        if self.is_hit and emerge > 0.3:
            self._draw_striking_arms(clip_surf, clip_cx, clip_body_top,
                                     body_w, visible_h, b, p, hit_shake_x)

        # 클리핑 서피스를 메인에 블릿
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
        _molewang_instance._dirt_particles = []
