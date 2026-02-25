# -*- coding: utf-8 -*-
"""
두더지왕 (Mole King) 프로시저럴 보스 스프라이트
투기장 영웅 스타일 고퀄리티 프로시저럴 렌더링
- 이동 애니메이션 (좌/우/아이들) — 뒤뚱뒤뚱 두더지 걸음
- 히트 애니메이션 — 날카로운 발톱 후려치기
- Stage1BossSprite / PododaejangBossSprite 와 동일한 인터페이스
"""

import pygame
import math

_sin = math.sin
_cos = math.cos


class MolewangBossSprite:
    """
    두더지왕 프로시저럴 보스 스프라이트
    땅속 왕국의 왕 — 벨벳 갈색 모피, 별코, 거대한 삽 손, 날카로운 발톱, 보석 왕관
    """

    def __init__(self):
        # 애니메이션 상태
        self.direction = 0       # -1: 왼쪽, 0: 정지, 1: 오른쪽
        self.prev_x = 0.0
        self.time = 0.0

        # 걷기 애니메이션
        self.step_phase = 0.0    # 걷기 사이클 위상
        self.lean = 0.0          # 몸 기울기
        self.body_bob = 0.0      # 상하 흔들림
        self.velocity = 0.0      # 이동 속도 (방향 감지용)

        # 방향 전환 안정화
        self.direction_change_cooldown = 0.0
        self.direction_change_threshold = 0.15
        self.movement_accumulator = 0.0

        # 히트 애니메이션 (발톱 후려치기)
        self.is_hit = False
        self.hit_timer = 0.0
        self.hit_duration = 0.40   # 히트 애니메이션 지속시간
        self.hit_direction = 1     # 공이 날아온 방향
        self.hit_intensity = 0.0   # 0~1 히트 강도

        # 코 킁킁 애니메이션 (아이들)
        self.sniff_phase = 0.0

        # 흙 파편 파티클
        self._dirt_particles = []
        self._dirt_spawn_timer = 0.0

        # 프레임 캐시
        self._cache_key = None
        self._cached_frame = None
        self._surface_cache = {}

    def _get_surface(self, w, h):
        """크기별 SRCALPHA Surface 캐시 재사용"""
        key = (w, h)
        if key not in self._surface_cache:
            self._surface_cache[key] = pygame.Surface((w, h), pygame.SRCALPHA)
        else:
            self._surface_cache[key].fill((0, 0, 0, 0))
        return self._surface_cache[key]

    def update(self, current_x, dt=1/60):
        """애니메이션 상태 업데이트 (Stage1BossSprite 호환)"""
        self.time += dt

        # 이동 방향 감지
        dx = current_x - self.prev_x

        # 방향 전환 쿨다운
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
            # 정지 상태로 전환
            self.movement_accumulator *= 0.9
            if abs(self.movement_accumulator) < 1.0:
                self.direction = 0

        # 속도 계산
        self.velocity = abs(dx) / max(dt, 0.001)

        # 걷기 애니메이션 업데이트 — 두더지 특유의 느린 뒤뚱걸음
        if self.direction != 0:
            speed_factor = min(self.velocity / 80.0, 2.0)
            self.step_phase += dt * 7.0 * max(speed_factor, 0.5)
            target_lean = self.direction * 0.20 * min(speed_factor, 1.0)
            self.lean += (target_lean - self.lean) * min(dt * 6.0, 1.0)
            # 두더지 뒤뚱걸음 — 좌우 흔들림 크게
            self.body_bob = _sin(self.step_phase * 2) * 0.12 * speed_factor
        else:
            # 아이들 애니메이션
            self.step_phase *= 0.95
            self.lean *= 0.92
            self.body_bob = _sin(self.time * 1.5) * 0.025  # 미세한 호흡
            # 코 킁킁
            self.sniff_phase += dt * 6.0

        # 히트 애니메이션 업데이트
        if self.is_hit:
            self.hit_timer += dt
            progress = self.hit_timer / self.hit_duration
            if progress >= 1.0:
                self.is_hit = False
                self.hit_timer = 0.0
                self.hit_intensity = 0.0
            else:
                self.hit_intensity = max(0, 1.0 - progress * progress)

        # 흙 파편 업데이트
        self._update_dirt_particles(dt)

        self.prev_x = current_x

    def _update_dirt_particles(self, dt):
        """흙 파편 파티클 업데이트"""
        # 이동 시 파티클 생성
        if self.direction != 0:
            self._dirt_spawn_timer += dt
            if self._dirt_spawn_timer >= 0.08:
                self._dirt_spawn_timer = 0.0
                import random
                self._dirt_particles.append({
                    "x": random.uniform(-0.3, 0.3),
                    "y": random.uniform(0.0, 0.2),
                    "vx": random.uniform(-0.5, 0.5) - self.direction * 0.3,
                    "vy": random.uniform(-1.5, -0.5),
                    "life": 1.0,
                    "size": random.uniform(0.04, 0.10),
                })

        # 파티클 업데이트
        alive = []
        for p in self._dirt_particles:
            p["life"] -= dt * 2.5
            p["x"] += p["vx"] * dt
            p["y"] += p["vy"] * dt
            p["vy"] += 3.0 * dt  # 중력
            if p["life"] > 0:
                alive.append(p)
        self._dirt_particles = alive[-20:]  # 최대 20개

    def trigger_hit(self, ball_x, boss_x):
        """히트 애니메이션 트리거 — 발톱 후려치기 (Stage1BossSprite 호환)"""
        self.is_hit = True
        self.hit_timer = 0.0
        self.hit_intensity = 1.0
        self.hit_direction = 1 if ball_x > boss_x else -1

    def get_current_frame(self, scale_size=None):
        """현재 프레임 Surface 반환 (Stage1BossSprite 호환)"""
        w, h = scale_size or (96, 192)
        w, h = max(20, int(w)), max(40, int(h))

        surface = pygame.Surface((w, h), pygame.SRCALPHA)
        b = w / 10.0  # 블록 단위
        cx = w // 2
        cy = int(h * 0.48)  # 두더지는 땅딸막 → 약간 아래 중심

        self._draw_character(surface, cx, cy, b, w, h)
        return surface

    def draw(self, surface, x, y, width=None, height=None, center=True):
        """화면에 그리기 (Stage1BossSprite 호환)"""
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
    #  프로시저럴 렌더링 — 두더지왕 캐릭터
    # ===================================================================

    def _draw_character(self, surface, cx, cy, b, w, h):
        """두더지왕 전체 캐릭터 렌더링"""

        lean = self.lean
        body_bob = self.body_bob
        step = self.step_phase

        # 히트 시 밀리는 효과
        hit_push = 0.0
        hit_shake_x = 0
        hit_shake_y = 0
        hit_color_flash = 0.0
        if self.is_hit:
            hit_push = self.hit_intensity * 0.35
            hit_shake_x = int(_sin(self.time * 45) * self.hit_intensity * 2.5)
            hit_shake_y = int(_cos(self.time * 38) * self.hit_intensity * 1.8)
            hit_color_flash = self.hit_intensity * 0.35

        lean_offset = int(lean * 2.5 * b) + hit_shake_x
        bob_offset = int(body_bob * 2.0 * b) + hit_shake_y
        torso_y = cy - int(0.8 * b) + bob_offset + int(hit_push * b)

        # 팔레트
        p = self._get_palette(hit_color_flash)

        # 레이어 순서로 그리기
        self._draw_shadow(surface, cx, cy, b, lean_offset)
        self._draw_dirt_fx(surface, cx, cy, b, lean_offset, bob_offset, p)
        self._draw_legs(surface, cx, cy, b, lean_offset, bob_offset, step, p)
        self._draw_body(surface, cx, cy, b, lean_offset, torso_y, step, p)
        self._draw_arms(surface, cx, cy, b, lean_offset, torso_y, step, p)
        self._draw_claw_effect(surface, cx, cy, b, lean_offset, torso_y, p)
        self._draw_neck_head(surface, cx, b, lean_offset, torso_y, p)
        self._draw_face(surface, cx, b, lean_offset, torso_y, p)
        self._draw_crown(surface, cx, b, lean_offset, torso_y, p)

    def _get_palette(self, flash=0.0):
        """두더지왕 색상 팔레트"""
        def _f(base):
            return tuple(min(255, int(c + (255 - c) * flash)) for c in base)

        return {
            # 모피 (벨벳 갈색)
            "fur": _f((95, 65, 35)),
            "fur_light": _f((125, 90, 55)),
            "fur_dark": _f((65, 42, 22)),
            "fur_edge": _f((80, 55, 30)),
            "fur_belly": _f((165, 140, 110)),
            "fur_belly_light": _f((185, 160, 130)),
            # 피부 (분홍)
            "skin_pink": _f((235, 175, 155)),
            "skin_pink_light": _f((248, 200, 185)),
            "skin_pink_dark": _f((200, 140, 120)),
            # 코 (별코 — 진한 분홍)
            "nose": _f((220, 120, 110)),
            "nose_light": _f((240, 155, 145)),
            "nose_dark": _f((180, 90, 80)),
            "nose_tip": _f((255, 140, 130)),
            # 발톱 (날카로운 흰색)
            "claw": _f((240, 235, 225)),
            "claw_edge": _f((200, 195, 185)),
            "claw_shine": _f((255, 255, 255)),
            "claw_shadow": _f((170, 160, 145)),
            # 눈 (작고 찡그린)
            "eye_black": _f((15, 10, 8)),
            "eye_shine": _f((255, 255, 255)),
            "eye_ring": _f((45, 30, 20)),
            # 이빨
            "tooth": _f((250, 245, 235)),
            "tooth_shadow": _f((210, 200, 185)),
            # 왕관 (흙속 보석)
            "crown_gold": _f((210, 175, 55)),
            "crown_gold_light": _f((240, 210, 90)),
            "crown_gold_dark": _f((170, 135, 35)),
            "gem_red": _f((200, 45, 40)),
            "gem_green": _f((45, 180, 65)),
            "gem_blue": _f((55, 90, 200)),
            "gem_shine": _f((255, 255, 255)),
            # 흙/파편
            "dirt": _f((120, 85, 50)),
            "dirt_light": _f((155, 115, 70)),
            "dirt_dark": _f((80, 55, 30)),
            # 귀
            "ear_outer": _f((90, 60, 32)),
            "ear_inner": _f((210, 155, 135)),
            # 수염 (비브리사)
            "whisker": _f((180, 170, 155)),
            # 발톱 궤적 (히트 이펙트)
            "scratch_white": (255, 255, 240),
            "scratch_yellow": (255, 230, 100),
            "scratch_red": (255, 120, 80),
        }

    # ------- 그림자 -------
    def _draw_shadow(self, surface, cx, cy, b, lean_offset):
        """바닥 그림자 — 두더지 넓적한 체형"""
        shadow_w = int(3.2 * b)
        shadow_h = int(0.7 * b)
        shadow_y = cy + int(3.5 * b)
        shadow_surf = self._get_surface(shadow_w, shadow_h)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 45), (0, 0, shadow_w, shadow_h))
        surface.blit(shadow_surf, (cx - shadow_w // 2 + lean_offset // 2, shadow_y))

    # ------- 흙 파편 이펙트 -------
    def _draw_dirt_fx(self, surface, cx, cy, b, lean_offset, bob_offset, p):
        """이동 시 흙 파편 파티클"""
        base_x = cx + lean_offset
        base_y = cy + int(3.2 * b) + bob_offset
        for dp in self._dirt_particles:
            alpha = max(0, min(255, int(dp["life"] * 180)))
            px = int(base_x + dp["x"] * b * 3)
            py = int(base_y + dp["y"] * b * 3)
            sz = max(1, int(dp["size"] * b))
            dirt_color = p["dirt"] if dp["life"] > 0.5 else p["dirt_dark"]
            if alpha > 50:
                dirt_surf = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
                pygame.draw.circle(dirt_surf, (*dirt_color, alpha), (sz, sz), sz)
                surface.blit(dirt_surf, (px - sz, py - sz))

    # ------- 다리 -------
    def _draw_legs(self, surface, cx, cy, b, lean_offset, bob_offset, step, p):
        """짧고 굵은 다리 + 뒷발톱"""
        leg_base_y = cy + int(2.6 * b) + bob_offset
        speed_factor = min(self.velocity / 80.0, 1.5) if self.direction != 0 else 0

        for side in [-1, 1]:
            phase_offset = 0 if side == -1 else math.pi
            leg_sway = _sin(step + phase_offset) * speed_factor * 0.5 * b
            leg_lift = max(0, _sin(step + phase_offset)) * speed_factor * 0.2 * b

            leg_x = cx + side * int(0.55 * b) + lean_offset + int(leg_sway)
            leg_y = leg_base_y - int(leg_lift)

            # 짧은 다리 (통통)
            leg_w = int(0.65 * b)
            leg_h = int(0.9 * b)
            pygame.draw.ellipse(surface, p["fur_dark"],
                              (int(leg_x - leg_w / 2), int(leg_y - 0.1 * b),
                               leg_w, leg_h))
            pygame.draw.ellipse(surface, p["fur"],
                              (int(leg_x - leg_w / 2 + 1), int(leg_y - 0.1 * b + 1),
                               leg_w - 2, leg_h - 2))

            # 뒷발 (넓적)
            foot_w = int(0.8 * b)
            foot_h = int(0.3 * b)
            foot_y = int(leg_y + 0.65 * b)
            pygame.draw.ellipse(surface, p["skin_pink_dark"],
                              (int(leg_x - foot_w / 2), foot_y, foot_w, foot_h))
            pygame.draw.ellipse(surface, p["skin_pink"],
                              (int(leg_x - foot_w / 2 + 1), foot_y + 1,
                               foot_w - 2, foot_h - 2))

            # 뒷발톱 (3개 작은 발톱)
            for ci in range(3):
                claw_x = int(leg_x + (ci - 1) * 0.22 * b)
                claw_y = foot_y + foot_h - 1
                claw_len = int(0.15 * b)
                pygame.draw.line(surface, p["claw"],
                               (claw_x, claw_y),
                               (claw_x + side * int(0.03 * b), claw_y + claw_len), 2)
                pygame.draw.line(surface, p["claw_shine"],
                               (claw_x, claw_y),
                               (claw_x + side * int(0.03 * b), claw_y + claw_len), 1)

    # ------- 몸통 -------
    def _draw_body(self, surface, cx, cy, b, lean_offset, torso_y, step, p):
        """통통한 원통형 몸통 — 벨벳 모피 질감"""
        # 몸통 메인 (넓적한 타원)
        body_w = int(3.0 * b)
        body_h = int(2.8 * b)
        body_cx = cx + lean_offset
        body_top = torso_y - int(0.4 * b)

        body_rect = pygame.Rect(body_cx - body_w // 2, body_top, body_w, body_h)

        # 그림자
        pygame.draw.ellipse(surface, p["fur_dark"], body_rect.move(2, 2))
        # 본체
        pygame.draw.ellipse(surface, p["fur"], body_rect)

        # 모피 질감 — 세로 줄무늬 패턴
        speed_factor = min(self.velocity / 80.0, 1.0) if self.direction != 0 else 0
        for i in range(7):
            fx = body_cx + (i - 3) * int(0.35 * b)
            fy_top = body_top + int(0.3 * b)
            fy_bot = body_top + body_h - int(0.3 * b)
            wave = _sin(self.time * 1.5 + i * 0.8) * speed_factor * 0.1 * b
            pygame.draw.line(surface, p["fur_light"],
                           (int(fx + wave), fy_top),
                           (int(fx + wave * 0.5), fy_bot), 1)

        # 배 부분 (밝은 색 — 타원)
        belly_w = int(1.8 * b)
        belly_h = int(1.6 * b)
        belly_rect = pygame.Rect(
            body_cx - belly_w // 2, body_top + int(0.7 * b),
            belly_w, belly_h
        )
        pygame.draw.ellipse(surface, p["fur_belly"], belly_rect)
        # 배 하이라이트
        belly_hl = belly_rect.inflate(-int(0.4 * b), -int(0.3 * b))
        belly_hl.move_ip(0, -int(0.1 * b))
        pygame.draw.ellipse(surface, p["fur_belly_light"], belly_hl)

        # 배 가운데 V자 모피 경계
        v_top = body_top + int(0.5 * b)
        v_bottom = body_top + int(1.5 * b)
        pygame.draw.line(surface, p["fur_edge"],
                        (body_cx, v_top),
                        (body_cx - int(0.6 * b), v_bottom), 1)
        pygame.draw.line(surface, p["fur_edge"],
                        (body_cx, v_top),
                        (body_cx + int(0.6 * b), v_bottom), 1)

        # 모피 테두리
        pygame.draw.ellipse(surface, p["fur_edge"], body_rect, 1)

    # ------- 팔 -------
    def _draw_arms(self, surface, cx, cy, b, lean_offset, torso_y, step, p):
        """짧고 굵은 팔 + 거대한 삽 손 + 날카로운 발톱 5개"""
        speed_factor = min(self.velocity / 80.0, 1.5) if self.direction != 0 else 0

        for side in [-1, 1]:
            shoulder_x = cx + side * int(1.4 * b) + lean_offset
            shoulder_y = torso_y + int(0.1 * b)

            # 삽질하듯 팔 스윙
            phase_offset = 0 if side == -1 else math.pi
            arm_swing = _sin(step + phase_offset) * speed_factor * 0.4

            # === 히트 시 발톱 후려치기 모션 ===
            hit_arm_angle = 0.0
            hit_arm_extend = 0.0
            hit_claw_spread = 0.0  # 발톱 펼침 정도
            is_striking_arm = False

            if self.is_hit:
                # 히트 방향에 따라 해당 팔만 사용
                is_striking_arm = (side == self.hit_direction)
                if is_striking_arm:
                    progress = self.hit_timer / self.hit_duration
                    if progress < 0.25:
                        # Phase 1: 팔 치켜들기 (windup)
                        t = progress / 0.25
                        hit_arm_angle = -1.2 * t
                        hit_arm_extend = -0.8 * t * b  # 위로 들기
                        hit_claw_spread = 0.5 * t
                    elif progress < 0.50:
                        # Phase 2: 내려치기 (strike)
                        t = (progress - 0.25) / 0.25
                        hit_arm_angle = -1.2 + 2.0 * t
                        hit_arm_extend = -0.8 * b + 2.8 * t * b
                        hit_claw_spread = 0.5 + 0.5 * t
                    elif progress < 0.75:
                        # Phase 3: 임팩트 유지
                        t = (progress - 0.50) / 0.25
                        hit_arm_angle = 0.8 * (1.0 - t * 0.3)
                        hit_arm_extend = 2.0 * b * (1.0 - t * 0.2)
                        hit_claw_spread = 1.0 - t * 0.3
                    else:
                        # Phase 4: 복귀
                        t = (progress - 0.75) / 0.25
                        hit_arm_angle = 0.8 * 0.7 * (1.0 - t)
                        hit_arm_extend = 2.0 * b * 0.8 * (1.0 - t)
                        hit_claw_spread = 0.7 * (1.0 - t)

            # 팔꿈치
            elbow_x = shoulder_x + side * int(0.2 * b)
            elbow_y = shoulder_y + int(0.8 * b) + int(arm_swing * 0.3 * b)

            # 손목
            wrist_x = elbow_x + side * int(0.15 * b)
            wrist_y = elbow_y + int(0.6 * b) + int(arm_swing * 0.4 * b)

            # 히트 모션 적용
            if is_striking_arm:
                wrist_y += int(hit_arm_extend * _cos(hit_arm_angle * 0.5))
                wrist_x += int(hit_arm_extend * 0.4 * side)
                elbow_y += int(hit_arm_extend * 0.3)

            # 상완 (짧고 굵은 팔)
            arm_pts = [
                (shoulder_x - int(0.32 * b), shoulder_y),
                (shoulder_x + int(0.32 * b), shoulder_y),
                (elbow_x + int(0.28 * b), elbow_y),
                (elbow_x - int(0.28 * b), elbow_y),
            ]
            pygame.draw.polygon(surface, p["fur"], arm_pts)
            pygame.draw.polygon(surface, p["fur_edge"], arm_pts, 1)

            # 하완 (팔뚝)
            forearm_pts = [
                (elbow_x - int(0.25 * b), elbow_y),
                (elbow_x + int(0.25 * b), elbow_y),
                (int(wrist_x) + int(0.3 * b), int(wrist_y)),
                (int(wrist_x) - int(0.3 * b), int(wrist_y)),
            ]
            pygame.draw.polygon(surface, p["fur_light"], forearm_pts)
            pygame.draw.polygon(surface, p["fur_edge"], forearm_pts, 1)

            # === 거대한 삽 손 (넓적한 타원) ===
            hand_w = int(0.75 * b)
            hand_h = int(0.55 * b)
            hand_cx = int(wrist_x)
            hand_cy = int(wrist_y) + int(0.15 * b)

            # 손바닥 (분홍색)
            pygame.draw.ellipse(surface, p["skin_pink_dark"],
                              (hand_cx - hand_w // 2, hand_cy - hand_h // 2,
                               hand_w, hand_h))
            pygame.draw.ellipse(surface, p["skin_pink"],
                              (hand_cx - hand_w // 2 + 1, hand_cy - hand_h // 2 + 1,
                               hand_w - 2, hand_h - 2))
            # 손바닥 패드 (두더지 특유의 두꺼운 패드)
            pad_r = max(2, int(0.12 * b))
            pygame.draw.circle(surface, p["skin_pink_light"],
                             (hand_cx, hand_cy - int(0.05 * b)), pad_r)

            # === 날카로운 발톱 5개 ===
            claw_base_spread = 0.6 + hit_claw_spread * 0.4  # 히트시 더 펼침
            for ci in range(5):
                # 부채꼴 배치
                angle_range = claw_base_spread * math.pi * 0.4
                angle = -angle_range / 2 + ci * (angle_range / 4)
                # 발톱 시작점 (손 가장자리)
                claw_start_x = hand_cx + int(_sin(angle) * hand_w * 0.45)
                claw_start_y = hand_cy + hand_h // 2 - int(0.05 * b)
                # 발톱 끝점 — 곡선으로 뻗음
                claw_len = int(0.35 * b) + int(hit_claw_spread * 0.2 * b)
                if is_striking_arm:
                    claw_len = int(claw_len * (1.0 + hit_claw_spread * 0.5))
                claw_end_x = claw_start_x + int(_sin(angle * 1.3) * claw_len * 0.5)
                claw_end_y = claw_start_y + claw_len

                # 발톱 그리기 (두꺼운→가늘어지는)
                # 발톱 그림자
                pygame.draw.line(surface, p["claw_shadow"],
                               (claw_start_x + 1, claw_start_y + 1),
                               (claw_end_x + 1, claw_end_y + 1),
                               max(1, int(0.08 * b)))
                # 발톱 본체
                pygame.draw.line(surface, p["claw"],
                               (claw_start_x, claw_start_y),
                               (claw_end_x, claw_end_y),
                               max(2, int(0.09 * b)))
                # 발톱 하이라이트 (빛 반사)
                mid_x = (claw_start_x + claw_end_x) // 2
                mid_y = (claw_start_y + claw_end_y) // 2
                pygame.draw.line(surface, p["claw_shine"],
                               (claw_start_x, claw_start_y),
                               (mid_x, mid_y), 1)
                # 발톱 끝 뾰족 포인트
                pygame.draw.circle(surface, p["claw_shine"],
                                 (claw_end_x, claw_end_y),
                                 max(1, int(0.025 * b)))

    # ------- 발톱 궤적 이펙트 -------
    def _draw_claw_effect(self, surface, cx, cy, b, lean_offset, torso_y, p):
        """히트 시 발톱 긁힘 궤적 (3줄 스크래치)"""
        if not self.is_hit:
            return

        progress = self.hit_timer / self.hit_duration
        if progress < 0.25 or progress > 0.85:
            return  # 내려치기 중~임팩트 시에만

        # 스크래치 알파
        if progress < 0.50:
            scratch_alpha = int(255 * ((progress - 0.25) / 0.25))
        else:
            scratch_alpha = int(255 * (1.0 - (progress - 0.50) / 0.35))
        scratch_alpha = max(0, min(255, scratch_alpha))

        if scratch_alpha < 10:
            return

        # 스크래치 위치 (공이 맞은 쪽)
        scratch_cx = cx + self.hit_direction * int(1.5 * b) + lean_offset
        scratch_cy = torso_y + int(2.2 * b)

        # 3줄 긁힘 자국
        scratch_surf = pygame.Surface((int(3 * b), int(2.5 * b)), pygame.SRCALPHA)
        sw, sh = scratch_surf.get_size()

        for i in range(3):
            sx = sw // 2 + (i - 1) * int(0.35 * b)
            # 위에서 아래로 긁힌 자국
            line_len = int(1.8 * b)
            start_y = int(0.2 * b)

            # 에너지 라인 (빛나는 효과)
            # 외곽 (붉은 빛)
            pygame.draw.line(scratch_surf, (*p["scratch_red"], scratch_alpha // 2),
                           (sx - 1, start_y), (sx - 1 + int(0.05 * b * i), start_y + line_len), 3)
            # 중앙 (노란 빛)
            pygame.draw.line(scratch_surf, (*p["scratch_yellow"], scratch_alpha),
                           (sx, start_y), (sx + int(0.05 * b * i), start_y + line_len), 2)
            # 코어 (흰색)
            pygame.draw.line(scratch_surf, (*p["scratch_white"], scratch_alpha),
                           (sx, start_y), (sx + int(0.05 * b * i), start_y + line_len), 1)

        surface.blit(scratch_surf,
                    (scratch_cx - sw // 2, scratch_cy - sh // 2))

    # ------- 목 + 머리 -------
    def _draw_neck_head(self, surface, cx, b, lean_offset, torso_y, p):
        """짧은 목 + 둥글고 큰 두더지 머리"""
        head_cx = cx + lean_offset
        # 두더지는 목이 거의 없음 — 몸통에 머리가 바로 붙음
        neck_y = torso_y - int(0.3 * b)

        # 짧은 목 (살짝 보이는 정도)
        neck_w = int(0.8 * b)
        neck_h = int(0.3 * b)
        pygame.draw.ellipse(surface, p["fur"],
                          (head_cx - neck_w // 2, neck_y, neck_w, neck_h))

        # === 머리 (큰 둥근 타원) ===
        head_w = int(2.4 * b)
        head_h = int(2.0 * b)
        head_top = neck_y - int(1.4 * b)
        head_rect = pygame.Rect(head_cx - head_w // 2, head_top, head_w, head_h)

        # 머리 그림자
        pygame.draw.ellipse(surface, p["fur_dark"], head_rect.move(2, 2))
        # 머리 본체
        pygame.draw.ellipse(surface, p["fur"], head_rect)
        # 머리 상단 하이라이트
        hl_rect = head_rect.inflate(-int(0.6 * b), -int(0.5 * b))
        hl_rect.move_ip(0, -int(0.2 * b))
        pygame.draw.ellipse(surface, p["fur_light"], hl_rect)

        # 모피 질감 (머리 위 세밀한 선)
        for i in range(5):
            hx = head_cx + (i - 2) * int(0.3 * b)
            hy_top = head_top + int(0.15 * b)
            hy_bot = head_top + int(0.6 * b)
            pygame.draw.line(surface, p["fur_edge"],
                           (hx, hy_top), (hx, hy_bot), 1)

        # === 귀 (둥근 반원, 머리 양옆) ===
        for side in [-1, 1]:
            ear_cx = head_cx + side * int(1.0 * b)
            ear_cy = head_top + int(0.5 * b)
            ear_r = int(0.35 * b)
            # 귀 외곽
            pygame.draw.circle(surface, p["ear_outer"], (ear_cx, ear_cy), ear_r)
            # 귀 안쪽 (분홍)
            pygame.draw.circle(surface, p["ear_inner"],
                             (ear_cx, ear_cy), max(1, int(ear_r * 0.6)))
            # 귀 테두리
            pygame.draw.circle(surface, p["fur_dark"],
                             (ear_cx, ear_cy), ear_r, 1)

    # ------- 얼굴 -------
    def _draw_face(self, surface, cx, b, lean_offset, torso_y, p):
        """작은 눈, 별코, 이빨, 수염"""
        head_cx = cx + lean_offset
        neck_y = torso_y - int(0.3 * b)
        head_top = neck_y - int(1.4 * b)
        face_cy = head_top + int(1.0 * b)

        # === 눈 (작고 찡그린 — 두더지 특유의 작은 눈) ===
        for side in [-1, 1]:
            eye_x = head_cx + side * int(0.45 * b)
            eye_y = face_cy - int(0.15 * b)

            # 눈 (아주 작은 타원)
            ew = max(2, int(0.15 * b))
            eh = max(1, int(0.08 * b))
            # 눈 주변 움푹 패인 그림자
            pygame.draw.ellipse(surface, p["fur_dark"],
                              (eye_x - ew - 1, eye_y - eh - 1,
                               ew * 2 + 2, eh * 2 + 2))
            # 눈 본체 (거의 점)
            pygame.draw.ellipse(surface, p["eye_black"],
                              (eye_x - ew, eye_y - eh, ew * 2, eh * 2))
            # 하이라이트
            pygame.draw.circle(surface, p["eye_shine"],
                             (eye_x - max(1, int(0.04 * b)),
                              eye_y - max(1, int(0.02 * b))),
                             max(1, int(0.03 * b)))

            # 찡그린 눈썹 (약간 화난 표정)
            brow_inner = eye_x - side * int(0.1 * b)
            brow_outer = eye_x + side * int(0.15 * b)
            pygame.draw.line(surface, p["fur_dark"],
                           (int(brow_inner), int(eye_y - 0.12 * b)),
                           (int(brow_outer), int(eye_y - 0.18 * b)), 2)

        # === 별코 (star-nosed mole 스타일) ===
        nose_cx = head_cx
        nose_cy = face_cy + int(0.25 * b)

        # 코 킁킁 애니메이션 (아이들 시)
        sniff_offset = 0
        if self.direction == 0:
            sniff_offset = int(_sin(self.sniff_phase) * 0.06 * b)

        # 코 본체 (큰 둥근 코)
        nose_r = max(3, int(0.25 * b))
        pygame.draw.circle(surface, p["nose_dark"],
                         (nose_cx + 1, nose_cy + sniff_offset + 1), nose_r)
        pygame.draw.circle(surface, p["nose"],
                         (nose_cx, nose_cy + sniff_offset), nose_r)
        # 코 하이라이트
        pygame.draw.circle(surface, p["nose_light"],
                         (nose_cx - int(0.05 * b), nose_cy + sniff_offset - int(0.05 * b)),
                         max(1, int(nose_r * 0.4)))

        # 별코 촉수 (star-nosed mole 특유의 분홍 돌기들)
        num_tendrils = 8
        for ti in range(num_tendrils):
            angle = (ti / num_tendrils) * math.pi * 2
            # 코 가장자리에서 짧게 뻗은 돌기
            t_start_x = nose_cx + int(_cos(angle) * nose_r * 0.7)
            t_start_y = nose_cy + sniff_offset + int(_sin(angle) * nose_r * 0.7)
            t_len = int(0.12 * b)
            # 킁킁 시 떨림
            t_wave = _sin(self.time * 8.0 + ti * 1.5) * 0.03 * b if self.direction == 0 else 0
            t_end_x = t_start_x + int(_cos(angle) * t_len + t_wave)
            t_end_y = t_start_y + int(_sin(angle) * t_len)
            pygame.draw.line(surface, p["nose_tip"],
                           (t_start_x, t_start_y),
                           (t_end_x, t_end_y), max(1, int(0.04 * b)))
            pygame.draw.circle(surface, p["nose_tip"],
                             (t_end_x, t_end_y), max(1, int(0.025 * b)))

        # 코 콧구멍
        for side in [-1, 1]:
            nx = nose_cx + side * int(0.08 * b)
            ny = nose_cy + sniff_offset + int(0.03 * b)
            pygame.draw.circle(surface, p["nose_dark"],
                             (nx, ny), max(1, int(0.04 * b)))

        # === 입 + 이빨 ===
        mouth_y = nose_cy + sniff_offset + int(0.35 * b)
        mouth_w = int(0.35 * b)

        # 입 (약간 벌린 — 이빨 보임)
        pygame.draw.line(surface, p["fur_dark"],
                        (head_cx - mouth_w, mouth_y),
                        (head_cx + mouth_w, mouth_y), 2)
        # 입 곡선 (약간 아래로)
        pygame.draw.arc(surface, p["fur_dark"],
                       (head_cx - mouth_w, mouth_y - int(0.05 * b),
                        mouth_w * 2, int(0.15 * b)),
                       0, math.pi, 1)

        # 뾰족한 이빨 2개 (아래로 돌출)
        for side in [-1, 1]:
            tooth_x = head_cx + side * int(0.12 * b)
            tooth_top = mouth_y
            tooth_bot = mouth_y + int(0.15 * b)
            # 이빨 삼각형
            tooth_pts = [
                (tooth_x - int(0.04 * b), tooth_top),
                (tooth_x + int(0.04 * b), tooth_top),
                (tooth_x, tooth_bot),
            ]
            pygame.draw.polygon(surface, p["tooth"], tooth_pts)
            pygame.draw.polygon(surface, p["tooth_shadow"], tooth_pts, 1)

        # === 수염 (비브리사 — 양쪽 3개씩) ===
        whisker_base_y = nose_cy + sniff_offset + int(0.1 * b)
        for side in [-1, 1]:
            for wi in range(3):
                w_start_x = nose_cx + side * int(0.2 * b)
                w_angle = (wi - 1) * 0.2  # -0.2, 0, 0.2
                w_len = int(0.7 * b)
                # 수염 떨림 (킁킁)
                w_wave = _sin(self.time * 4.0 + wi * 2.0) * 0.04 * b
                w_end_x = w_start_x + side * int(w_len * _cos(w_angle))
                w_end_y = whisker_base_y + int(w_len * _sin(w_angle)) + int(w_wave)
                pygame.draw.line(surface, p["whisker"],
                               (w_start_x, whisker_base_y),
                               (int(w_end_x), int(w_end_y)), 1)

    # ------- 왕관 -------
    def _draw_crown(self, surface, cx, b, lean_offset, torso_y, p):
        """흙 속 보석으로 만든 러프한 왕관"""
        head_cx = cx + lean_offset
        neck_y = torso_y - int(0.3 * b)
        head_top = neck_y - int(1.4 * b)

        crown_y = head_top - int(0.15 * b)

        # 히트 시 왕관 흔들림
        crown_tilt = 0
        crown_bob = 0
        if self.is_hit:
            crown_tilt = int(self.hit_intensity * self.hit_direction * 0.25 * b)
            crown_bob = int(_sin(self.time * 30) * self.hit_intensity * 0.1 * b)
        # 걸을 때 미세한 흔들림
        if self.direction != 0:
            speed_f = min(self.velocity / 80.0, 1.0)
            crown_bob += int(_sin(self.step_phase * 2) * speed_f * 0.06 * b)

        crown_cx = head_cx + crown_tilt
        crown_top = crown_y + crown_bob

        # === 왕관 밴드 (금색 타원) ===
        band_w = int(1.8 * b)
        band_h = int(0.4 * b)
        band_rect = pygame.Rect(crown_cx - band_w // 2, crown_top,
                               band_w, band_h)
        # 밴드 그림자
        pygame.draw.ellipse(surface, p["crown_gold_dark"], band_rect.move(1, 1))
        # 밴드 본체
        pygame.draw.ellipse(surface, p["crown_gold"], band_rect)
        # 밴드 하이라이트
        pygame.draw.ellipse(surface, p["crown_gold_light"],
                          band_rect.inflate(-int(0.3 * b), -int(0.1 * b)), 1)

        # === 왕관 삐죽한 꼭대기 (5개) ===
        num_points = 5
        for pi in range(num_points):
            t = (pi - (num_points - 1) / 2) / ((num_points - 1) / 2)  # -1 ~ 1
            point_x = crown_cx + int(t * band_w * 0.4)
            point_base_y = crown_top + int(0.05 * b)
            # 중앙이 가장 높음
            height_factor = 1.0 - abs(t) * 0.4
            point_tip_y = point_base_y - int(0.55 * b * height_factor)

            # 삼각형 꼭대기
            pw = int(0.18 * b)
            spike_pts = [
                (point_x - pw, point_base_y),
                (point_x + pw, point_base_y),
                (point_x, point_tip_y),
            ]
            pygame.draw.polygon(surface, p["crown_gold"], spike_pts)
            pygame.draw.polygon(surface, p["crown_gold_light"], spike_pts, 1)

        # === 보석 3개 (밴드 위) ===
        gems = [
            (-0.35 * b, p["gem_red"]),
            (0, p["gem_green"]),
            (0.35 * b, p["gem_blue"]),
        ]
        for gx_offset, gem_color in gems:
            gx = crown_cx + int(gx_offset)
            gy = crown_top + int(0.15 * b)
            gem_r = max(2, int(0.1 * b))

            # 보석 본체
            pygame.draw.circle(surface, gem_color, (gx, gy), gem_r)
            # 보석 하이라이트
            pygame.draw.circle(surface, p["gem_shine"],
                             (gx - max(1, int(0.02 * b)),
                              gy - max(1, int(0.02 * b))),
                             max(1, int(gem_r * 0.35)))
            # 보석 테두리
            pygame.draw.circle(surface, p["crown_gold_dark"],
                             (gx, gy), gem_r, 1)

        # 왕관에 묻은 흙 얼룩 (러프함 표현)
        dirt_spots = [(-0.5, 0.1), (0.3, -0.05), (0.6, 0.15)]
        for dx, dy in dirt_spots:
            spot_x = crown_cx + int(dx * b)
            spot_y = crown_top + int(dy * b)
            spot_r = max(1, int(0.06 * b))
            spot_surf = pygame.Surface((spot_r * 2, spot_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(spot_surf, (*p["dirt"], 60), (spot_r, spot_r), spot_r)
            surface.blit(spot_surf, (spot_x - spot_r, spot_y - spot_r))


# ===================================================================
#  싱글톤 패턴 (Stage1BossSprite와 동일)
# ===================================================================

_molewang_instance = None


def init_molewang_boss_sprite():
    """두더지왕 보스 스프라이트 초기화"""
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
    """두더지왕 보스 스프라이트 싱글톤 반환"""
    global _molewang_instance
    if _molewang_instance is None:
        init_molewang_boss_sprite()
    return _molewang_instance


def reset_molewang_boss_sprite():
    """두더지왕 보스 스프라이트 리셋"""
    global _molewang_instance
    if _molewang_instance:
        _molewang_instance.direction = 0
        _molewang_instance.is_hit = False
        _molewang_instance.hit_timer = 0.0
        _molewang_instance.time = 0.0
        _molewang_instance.step_phase = 0.0
        _molewang_instance.lean = 0.0
        _molewang_instance.body_bob = 0.0
        _molewang_instance.sniff_phase = 0.0
        _molewang_instance._dirt_particles = []
