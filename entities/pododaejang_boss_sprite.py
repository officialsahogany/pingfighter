# -*- coding: utf-8 -*-
"""
포도대장 (조선 포도청 대장) 프로시저럴 보스 스프라이트
투기장 영웅 스타일 고퀄리티 프로시저럴 렌더링
- 이동 애니메이션 (좌/우/아이들)
- 히트 애니메이션
- Stage1BossSprite와 동일한 인터페이스
"""

import pygame
import math

_sin = math.sin
_cos = math.cos


class PododaejangBossSprite:
    """
    포도대장 프로시저럴 보스 스프라이트
    조선 포도청 대장 — 갓, 남색 관복, 포승줄, 금색 관직 배지
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

        # 히트 애니메이션
        self.is_hit = False
        self.hit_timer = 0.0
        self.hit_duration = 0.35   # 히트 애니메이션 지속시간
        self.hit_direction = 1     # 공이 날아온 방향
        self.hit_intensity = 0.0   # 0~1 히트 강도 (시간에 따라 감소)

        # 오른팔 좌표 (rope_weapon에서 참조)
        self._right_hand_x = 0
        self._right_hand_y = 0

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

        # 걷기 애니메이션 업데이트
        if self.direction != 0:
            speed_factor = min(self.velocity / 80.0, 2.0)
            self.step_phase += dt * 8.0 * max(speed_factor, 0.5)
            self.lean = 0.0  # Lean 비활성화
            self.body_bob = _sin(self.step_phase * 2) * 0.08 * speed_factor
        else:
            # 아이들 애니메이션
            self.step_phase *= 0.95
            self.lean = 0.0
            self.body_bob = _sin(self.time * 1.5) * 0.02  # 미세한 호흡

        # 히트 애니메이션 업데이트
        if self.is_hit:
            self.hit_timer += dt
            progress = self.hit_timer / self.hit_duration
            if progress >= 1.0:
                self.is_hit = False
                self.hit_timer = 0.0
                self.hit_intensity = 0.0
            else:
                # 빠르게 시작 → 서서히 복귀
                self.hit_intensity = max(0, 1.0 - progress * progress)

        self.prev_x = current_x

    def trigger_hit(self, ball_x, boss_x):
        """히트 애니메이션 트리거 (Stage1BossSprite 호환)"""
        self.is_hit = True
        self.hit_timer = 0.0
        self.hit_intensity = 1.0
        self.hit_direction = 1 if ball_x > boss_x else -1

    def get_current_frame(self, scale_size=None):
        """현재 프레임 Surface 반환 (Stage1BossSprite 호환)"""
        w, h = scale_size or (80, 160)
        w, h = max(20, int(w)), max(40, int(h))

        surface = pygame.Surface((w, h), pygame.SRCALPHA)
        b = w / 10.0  # 블록 단위
        cx = w // 2
        cy = int(h * 0.45)  # 살짝 위쪽에 중심 (다리가 아래로)

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
    #  프로시저럴 렌더링 — 포도대장 캐릭터
    # ===================================================================

    def _draw_character(self, surface, cx, cy, b, w, h):
        """포도대장 전체 캐릭터 렌더링"""

        # 애니메이션 값
        lean = self.lean
        body_bob = self.body_bob
        step = self.step_phase

        # 히트 시 밀리는 효과
        hit_push = 0.0
        hit_shake_x = 0
        hit_shake_y = 0
        hit_color_flash = 0.0
        if self.is_hit:
            hit_push = self.hit_intensity * 0.3
            hit_shake_x = int(_sin(self.time * 40) * self.hit_intensity * 2)
            hit_shake_y = int(_cos(self.time * 35) * self.hit_intensity * 1.5)
            hit_color_flash = self.hit_intensity * 0.4
            # 히트 시 뒤로 밀림
            cy += int(hit_push * b * 2)

        lean_offset = int(lean * 2.0 * b) + hit_shake_x
        bob_offset = int(body_bob * 1.5 * b) + hit_shake_y
        torso_y = cy - int(1.2 * b) + bob_offset

        # 팔레트
        p = self._get_palette(hit_color_flash)

        # 레이어 순서로 그리기
        self._draw_shadow(surface, cx, cy, b, lean_offset)
        self._draw_legs(surface, cx, cy, b, lean_offset, bob_offset, step, p)
        self._draw_robe(surface, cx, cy, b, lean_offset, torso_y, step, p)
        self._draw_torso(surface, cx, cy, b, lean_offset, torso_y, p)
        self._draw_arms(surface, cx, cy, b, lean_offset, torso_y, step, p)
        self._draw_rope_weapon(surface, cx, cy, b, lean_offset, torso_y, p)
        self._draw_neck(surface, cx, b, lean_offset, torso_y, p)
        self._draw_head(surface, cx, b, lean_offset, torso_y, p)
        self._draw_gat(surface, cx, b, lean_offset, torso_y, p)

    def _get_palette(self, flash=0.0):
        """포도대장 색상 팔레트"""
        def _flash(base):
            """히트 시 흰색 플래시"""
            return tuple(min(255, int(c + (255 - c) * flash)) for c in base)

        return {
            # 갓 (전통 모자)
            "gat_brim": _flash((15, 12, 8)),
            "gat_crown": _flash((25, 20, 15)),
            "gat_band": _flash((60, 45, 25)),
            "gat_shine": _flash((50, 40, 30)),
            # 피부
            "skin": _flash((235, 210, 180)),
            "skin_shadow": _flash((200, 175, 145)),
            "skin_highlight": _flash((248, 228, 200)),
            # 관복 (남색 관복)
            "uniform": _flash((35, 45, 75)),
            "uniform_light": _flash((55, 68, 105)),
            "uniform_dark": _flash((22, 30, 55)),
            "uniform_edge": _flash((70, 85, 130)),
            # 허리띠
            "belt": _flash((110, 75, 35)),
            "belt_buckle": _flash((190, 165, 55)),
            # 포승줄
            "rope": _flash((175, 145, 95)),
            "rope_dark": _flash((140, 110, 65)),
            "rope_light": _flash((200, 175, 125)),
            # 관직 배지
            "badge_gold": _flash((210, 180, 60)),
            "badge_inner": _flash((180, 140, 30)),
            # 수염/머리
            "hair": _flash((35, 28, 20)),
            "hair_highlight": _flash((55, 45, 35)),
            "beard": _flash((45, 35, 25)),
            # 눈
            "eye_white": _flash((240, 240, 235)),
            "eye_iris": _flash((40, 30, 20)),
            "eye_pupil": _flash((10, 8, 5)),
            "eyebrow": _flash((30, 22, 15)),
            # 신발
            "shoe": _flash((50, 40, 25)),
            "shoe_light": _flash((75, 60, 40)),
        }

    def _draw_shadow(self, surface, cx, cy, b, lean_offset):
        """바닥 그림자"""
        shadow_w = int(2.8 * b)
        shadow_h = int(0.6 * b)
        shadow_y = cy + int(3.2 * b)
        shadow_surf = self._get_surface(shadow_w, shadow_h)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40), (0, 0, shadow_w, shadow_h))
        surface.blit(shadow_surf, (cx - shadow_w // 2 + lean_offset // 2, shadow_y))

    def _draw_legs(self, surface, cx, cy, b, lean_offset, bob_offset, step, p):
        """다리 (관복 아래로 보이는 바지와 신발)"""
        leg_base_y = cy + int(2.4 * b) + bob_offset
        speed_factor = min(self.velocity / 80.0, 1.5) if self.direction != 0 else 0

        for side in [-1, 1]:
            # 좌우 다리 위상 차이
            phase_offset = 0 if side == -1 else math.pi
            leg_sway = _sin(step + phase_offset) * speed_factor * 0.4 * b
            leg_lift = max(0, _sin(step + phase_offset)) * speed_factor * 0.15 * b

            leg_x = cx + side * int(0.35 * b) + lean_offset + int(leg_sway)
            leg_y = leg_base_y - int(leg_lift)

            # 바지 (관복 하의)
            pygame.draw.rect(surface, p["uniform_dark"],
                           (int(leg_x - 0.25 * b), int(leg_y - 0.3 * b),
                            int(0.5 * b), int(0.8 * b)),
                           border_radius=max(1, int(0.1 * b)))

            # 신발 (흑화)
            shoe_w = int(0.55 * b)
            shoe_h = int(0.25 * b)
            pygame.draw.ellipse(surface, p["shoe"],
                              (int(leg_x - shoe_w / 2), int(leg_y + 0.4 * b),
                               shoe_w, shoe_h))
            pygame.draw.ellipse(surface, p["shoe_light"],
                              (int(leg_x - shoe_w / 2 + 1), int(leg_y + 0.4 * b + 1),
                               shoe_w - 2, shoe_h - 2), 1)

    def _draw_robe(self, surface, cx, cy, b, lean_offset, torso_y, step, p):
        """관복 하단 (치마 부분) — 넓게 펼쳐지는 관복 + 너풀거림"""
        hip_y = torso_y + int(1.6 * b)
        hem_y = cy + int(2.5 * b)

        # 관복 움직임 관성
        speed_factor = min(self.velocity / 80.0, 1.5) if self.direction != 0 else 0
        sway = _sin(self.time * 2.5) * speed_factor * 0.15 * b
        inertia = -self.lean * 2.0 * b

        # === 너풀거림 파라미터 ===
        flutter_amp = speed_factor * 0.35 * b + 0.05 * b  # 이동 시 강하게, 정지 시 미세
        flutter_freq = 5.0 if self.direction != 0 else 1.8  # 이동 시 빠르게

        # 관복 치마 하단 — 물결 포인트 (좌→우 8개 정점)
        num_hem_pts = 8
        hem_left = cx - int(1.5 * b) + lean_offset + int(-sway + inertia * 0.3)
        hem_right = cx + int(1.5 * b) + lean_offset + int(sway + inertia * 0.3)

        # 위쪽 (허리) 2개 정점
        robe_top = [
            (cx - int(1.1 * b) + lean_offset, hip_y),
            (cx + int(1.1 * b) + lean_offset, hip_y),
        ]

        # 아래쪽 물결 정점 (오른쪽→왼쪽)
        robe_bottom = []
        for i in range(num_hem_pts):
            t = i / (num_hem_pts - 1)
            bx = hem_right + int((hem_left - hem_right) * t)
            # 각 정점마다 위상이 다른 물결
            wave = _sin(self.time * flutter_freq + t * math.pi * 2.5 + i * 0.7) * flutter_amp
            # 가장자리가 더 크게 너풀거림
            edge_factor = 1.0 + abs(t - 0.5) * 0.8
            by = hem_y + int(wave * edge_factor)
            robe_bottom.append((bx, by))

        robe_points = robe_top + robe_bottom
        # 그림자
        shadow_pts = [(x + 2, y + 2) for x, y in robe_points]
        pygame.draw.polygon(surface, (15, 18, 35), shadow_pts)
        # 본체
        pygame.draw.polygon(surface, p["uniform"], robe_points)

        # 관복 주름 (5줄) — 주름도 너풀거림 반영
        for i in range(5):
            fx = cx + (i - 2) * int(0.38 * b) + lean_offset
            fold_drift = int((sway + inertia * 0.3) * (i - 2) * 0.08)
            fold_wave = _sin(self.time * flutter_freq * 0.8 + i * 1.2) * flutter_amp * 0.3
            pygame.draw.line(surface, p["uniform_light"],
                           (fx, hip_y + int(0.15 * b)),
                           (fx + fold_drift, hem_y - int(0.1 * b) + int(fold_wave)), 1)

        # 관복 하단 물결 테두리
        for i in range(len(robe_bottom) - 1):
            pygame.draw.line(surface, p["uniform_edge"],
                           robe_bottom[i], robe_bottom[i + 1], 1)

    def _draw_torso(self, surface, cx, cy, b, lean_offset, torso_y, p):
        """상체 (관복 상의 + 배지)"""
        chest_w = int(2.4 * b)
        chest_h = int(1.8 * b)
        chest_rect = pygame.Rect(
            cx - chest_w // 2 + lean_offset,
            torso_y - int(0.2 * b),
            chest_w, chest_h
        )

        # 그림자
        pygame.draw.rect(surface, p["uniform_dark"],
                        chest_rect.move(2, 2), border_radius=int(0.3 * b))
        # 본체
        pygame.draw.rect(surface, p["uniform"], chest_rect,
                        border_radius=int(0.3 * b))
        # 하이라이트 (중앙)
        inner = chest_rect.inflate(-int(0.5 * b), -int(0.4 * b))
        pygame.draw.rect(surface, p["uniform_light"], inner,
                        border_radius=max(1, int(0.15 * b)))
        # 테두리
        pygame.draw.rect(surface, p["uniform_edge"], chest_rect, 1,
                        border_radius=int(0.3 * b))

        # V자 깃 (관복 특유의 여밈)
        collar_top = chest_rect.top + int(0.1 * b)
        collar_bottom = chest_rect.centery + int(0.3 * b)
        pygame.draw.line(surface, p["uniform_edge"],
                        (chest_rect.centerx, collar_top),
                        (chest_rect.left + int(0.3 * b), collar_bottom), 2)
        pygame.draw.line(surface, p["uniform_edge"],
                        (chest_rect.centerx, collar_top),
                        (chest_rect.right - int(0.3 * b), collar_bottom), 2)

        # 안감 (밝은 색 — 관복 안쪽)
        pygame.draw.line(surface, (200, 190, 170),
                        (chest_rect.centerx, collar_top + 1),
                        (chest_rect.left + int(0.35 * b), collar_bottom - 1), 1)
        pygame.draw.line(surface, (200, 190, 170),
                        (chest_rect.centerx, collar_top + 1),
                        (chest_rect.right - int(0.35 * b), collar_bottom - 1), 1)

        # 관직 배지 (흉배 — 가슴 중앙)
        badge_cx = chest_rect.centerx
        badge_cy = chest_rect.centery + int(0.1 * b)
        badge_r = max(2, int(0.35 * b))

        # 배지 사각 배경
        badge_rect = pygame.Rect(badge_cx - badge_r, badge_cy - badge_r,
                                badge_r * 2, badge_r * 2)
        pygame.draw.rect(surface, p["badge_gold"], badge_rect,
                        border_radius=max(1, int(0.08 * b)))
        pygame.draw.rect(surface, p["badge_inner"],
                        badge_rect.inflate(-int(0.15 * b), -int(0.15 * b)),
                        border_radius=max(1, int(0.05 * b)))
        # 배지 문양 (십자)
        pygame.draw.line(surface, p["badge_gold"],
                        (badge_cx, badge_cy - int(0.15 * b)),
                        (badge_cx, badge_cy + int(0.15 * b)), 1)
        pygame.draw.line(surface, p["badge_gold"],
                        (badge_cx - int(0.15 * b), badge_cy),
                        (badge_cx + int(0.15 * b), badge_cy), 1)

        # 허리띠
        belt_y = chest_rect.bottom - int(0.1 * b)
        belt_rect = pygame.Rect(
            cx - int(1.2 * b) + lean_offset, belt_y,
            int(2.4 * b), int(0.5 * b)
        )
        pygame.draw.rect(surface, p["belt"], belt_rect, border_radius=2)
        pygame.draw.rect(surface, p["belt_buckle"],
                        (belt_rect.centerx - int(0.15 * b),
                         belt_rect.centery - int(0.1 * b),
                         int(0.3 * b), int(0.2 * b)),
                        border_radius=1)

    def _draw_arms(self, surface, cx, cy, b, lean_offset, torso_y, step, p):
        """양팔 (관복 소매) — 소매 너풀거림 + 히트 시 후려치기"""
        speed_factor = min(self.velocity / 80.0, 1.5) if self.direction != 0 else 0
        flutter_amp = speed_factor * 0.2 * b + 0.03 * b
        flutter_freq = 4.5 if self.direction != 0 else 1.5

        for side in [-1, 1]:
            # 어깨 위치
            shoulder_x = cx + side * int(1.2 * b) + lean_offset
            shoulder_y = torso_y + int(0.1 * b)

            # 팔 스윙
            phase_offset = 0 if side == -1 else math.pi
            arm_swing = _sin(step + phase_offset) * speed_factor * 0.3

            # === 히트 시 오른팔(side==1) 후려치기 모션 ===
            hit_arm_angle = 0.0
            hit_arm_extend = 0.0
            if self.is_hit and side == 1:
                progress = self.hit_timer / self.hit_duration
                if progress < 0.3:
                    # 0~30%: 팔을 빠르게 앞으로 뻗음 (후려치기)
                    t = progress / 0.3
                    hit_arm_angle = -0.8 * t  # 아래쪽으로 회전
                    hit_arm_extend = 1.5 * t * b  # 앞으로 뻗기
                elif progress < 0.6:
                    # 30~60%: 최대 뻗은 상태 유지 + 약간 떨림
                    t = (progress - 0.3) / 0.3
                    hit_arm_angle = -0.8 + 0.1 * _sin(t * math.pi * 4)
                    hit_arm_extend = 1.5 * b * (1.0 - t * 0.2)
                else:
                    # 60~100%: 서서히 복귀
                    t = (progress - 0.6) / 0.4
                    hit_arm_angle = -0.8 * (1.0 - t)
                    hit_arm_extend = 1.5 * b * 0.8 * (1.0 - t)

            # 팔꿈치
            elbow_x = shoulder_x + side * int(0.3 * b)
            elbow_y = shoulder_y + int(0.9 * b) + int(arm_swing * 0.2 * b)

            # 손 위치 (오른손에 포승줄)
            hand_x = elbow_x + side * int(0.25 * b)
            hand_y = elbow_y + int(0.7 * b) + int(arm_swing * 0.3 * b)

            # 히트 모션 적용 (오른팔만)
            if self.is_hit and side == 1:
                # 팔을 아래쪽+앞쪽으로 뻗기
                hand_y += int(hit_arm_extend * _cos(hit_arm_angle))
                hand_x += int(hit_arm_extend * 0.3 * self.hit_direction)
                elbow_y += int(hit_arm_extend * 0.4)

            # 소매 (상완) — 너풀거림 적용
            sleeve_wave_l = _sin(self.time * flutter_freq + side * 1.5) * flutter_amp
            sleeve_wave_r = _sin(self.time * flutter_freq + side * 1.5 + 1.2) * flutter_amp
            sleeve_pts = [
                (shoulder_x - int(0.3 * b), shoulder_y - int(0.1 * b)),
                (shoulder_x + int(0.3 * b), shoulder_y - int(0.1 * b)),
                (elbow_x + int(0.25 * b) + int(sleeve_wave_r), elbow_y),
                (elbow_x - int(0.25 * b) + int(sleeve_wave_l), elbow_y),
            ]
            pygame.draw.polygon(surface, p["uniform"], sleeve_pts)
            pygame.draw.polygon(surface, p["uniform_edge"], sleeve_pts, 1)

            # 소매 (하완) — 너풀거림
            cuff_wave = _sin(self.time * flutter_freq * 1.2 + side * 2.0) * flutter_amp * 0.7
            forearm_pts = [
                (elbow_x - int(0.22 * b) + int(sleeve_wave_l * 0.5), elbow_y - int(0.05 * b)),
                (elbow_x + int(0.22 * b) + int(sleeve_wave_r * 0.5), elbow_y - int(0.05 * b)),
                (int(hand_x) + int(0.15 * b) + int(cuff_wave), int(hand_y)),
                (int(hand_x) - int(0.15 * b) + int(cuff_wave), int(hand_y)),
            ]
            pygame.draw.polygon(surface, p["uniform_light"], forearm_pts)

            # 손
            hand_r = max(2, int(0.15 * b))
            pygame.draw.circle(surface, p["skin"], (int(hand_x), int(hand_y)), hand_r)
            pygame.draw.circle(surface, p["skin_shadow"],
                             (int(hand_x), int(hand_y)), hand_r, 1)

        # 오른팔 hand 좌표를 저장 (rope_weapon에서 사용)
        self._right_hand_x = hand_x
        self._right_hand_y = hand_y

    def _draw_rope_weapon(self, surface, cx, cy, b, lean_offset, torso_y, p):
        """포승줄 (오른손에 들고 있는 밧줄 무기) — 히트 시 채찍처럼 휘두름"""
        # 오른손 위치 (히트 모션 반영)
        if hasattr(self, '_right_hand_x') and self._right_hand_x:
            hand_x = self._right_hand_x
            hand_y = self._right_hand_y
        else:
            hand_x = cx + int(1.5 * b) + lean_offset
            hand_y = torso_y + int(1.8 * b)

        # 포승줄 코일 (감긴 밧줄)
        coil_cx = int(hand_x + 0.3 * b)
        coil_cy = int(hand_y)
        coil_r = max(3, int(0.5 * b))

        # 밧줄 코일 그림자
        pygame.draw.circle(surface, p["rope_dark"],
                         (coil_cx + 1, coil_cy + 1), coil_r)
        # 밧줄 코일 본체
        pygame.draw.circle(surface, p["rope"], (coil_cx, coil_cy), coil_r)
        # 밧줄 감긴 무늬
        pygame.draw.circle(surface, p["rope_light"],
                         (coil_cx, coil_cy), coil_r, 1)
        # 내부 원 (코일 중심)
        inner_r = max(1, int(0.25 * b))
        pygame.draw.circle(surface, p["rope_dark"],
                         (coil_cx, coil_cy), inner_r)

        # === 히트 시: 포승줄 채찍 궤적 ===
        if self.is_hit:
            progress = self.hit_timer / self.hit_duration
            if progress < 0.6:
                # 채찍 궤적 — 손에서 아래쪽으로 휘두름
                whip_t = min(progress / 0.35, 1.0)
                whip_len = 2.5 * b * whip_t
                whip_dir = self.hit_direction
                # 채찍 끝 위치
                whip_end_x = coil_cx + int(whip_dir * whip_len * 0.4)
                whip_end_y = coil_cy + int(whip_len)
                # 채찍 곡선 (5세그먼트)
                segments = 8
                line_w = max(2, int(0.12 * b))
                for i in range(segments):
                    t = i / segments
                    t2 = (i + 1) / segments
                    # S자 곡선 궤적
                    wave = _sin(t * math.pi * 2 - self.time * 15) * 0.4 * b * t * whip_t
                    wave2 = _sin(t2 * math.pi * 2 - self.time * 15) * 0.4 * b * t2 * whip_t
                    sx = coil_cx + int((whip_end_x - coil_cx) * t + wave)
                    sy = coil_cy + int((whip_end_y - coil_cy) * t)
                    ex = coil_cx + int((whip_end_x - coil_cx) * t2 + wave2)
                    ey = coil_cy + int((whip_end_y - coil_cy) * t2)
                    # 끝으로 갈수록 가늘어짐
                    seg_w = max(1, int(line_w * (1.0 - t * 0.6)))
                    pygame.draw.line(surface, p["rope"], (sx, sy), (ex, ey), seg_w)
                # 채찍 끝 타격 이펙트 (초반에만)
                if progress < 0.35:
                    impact_alpha = int(200 * (1.0 - progress / 0.35))
                    impact_r = max(2, int(0.3 * b * whip_t))
                    impact_surf = pygame.Surface((impact_r * 2, impact_r * 2), pygame.SRCALPHA)
                    pygame.draw.circle(impact_surf, (255, 220, 150, impact_alpha),
                                     (impact_r, impact_r), impact_r)
                    surface.blit(impact_surf,
                               (int(whip_end_x) - impact_r, int(whip_end_y) - impact_r))
            else:
                # 60~100%: 복귀 — 일반 늘어진 밧줄
                self._draw_rope_idle(surface, coil_cx, coil_cy, b, p)
        else:
            # 평상시 늘어진 밧줄
            self._draw_rope_idle(surface, coil_cx, coil_cy, b, p)

    def _draw_rope_idle(self, surface, coil_cx, coil_cy, b, p):
        """포승줄 — 평상시 아래로 늘어진 밧줄"""
        rope_sway = _sin(self.time * 2.0) * 0.15 * b
        rope_end_x = coil_cx + int(rope_sway)
        rope_end_y = coil_cy + int(1.2 * b)

        # 곡선 밧줄 (6세그먼트)
        segments = 6
        for i in range(segments):
            t = i / segments
            t2 = (i + 1) / segments
            sx = coil_cx + int(_sin(t * math.pi + self.time * 1.5) * 0.2 * b + rope_sway * t)
            sy = coil_cy + int(t * 1.2 * b)
            ex = coil_cx + int(_sin(t2 * math.pi + self.time * 1.5) * 0.2 * b + rope_sway * t2)
            ey = coil_cy + int(t2 * 1.2 * b)
            pygame.draw.line(surface, p["rope"], (sx, sy), (ex, ey),
                           max(1, int(0.08 * b)))

        # 밧줄 끝 매듭
        pygame.draw.circle(surface, p["rope_dark"],
                         (int(rope_end_x), int(rope_end_y)),
                         max(1, int(0.1 * b)))

    def _draw_neck(self, surface, cx, b, lean_offset, torso_y, p):
        """목"""
        neck_cx = cx + lean_offset
        neck_bot_y = torso_y - int(0.1 * b)
        neck_top_y = torso_y - int(0.45 * b)
        neck_w_bot = int(0.6 * b)
        neck_w_top = int(0.45 * b)

        neck_pts = [
            (neck_cx - neck_w_bot // 2, neck_bot_y),
            (neck_cx + neck_w_bot // 2, neck_bot_y),
            (neck_cx + neck_w_top // 2, neck_top_y),
            (neck_cx - neck_w_top // 2, neck_top_y),
        ]
        pygame.draw.polygon(surface, p["skin"], neck_pts)
        # 목 그림자 라인
        pygame.draw.line(surface, p["skin_shadow"],
                        (neck_cx + neck_w_top // 3, neck_top_y + 1),
                        (neck_cx + neck_w_bot // 3, neck_bot_y - 1), 1)

    def _draw_head(self, surface, cx, b, lean_offset, torso_y, p):
        """머리 (얼굴, 수염, 눈)"""
        head_cx = cx + lean_offset
        head_y = torso_y - int(2.0 * b)
        head_w = int(1.8 * b)
        head_h = int(1.6 * b)
        head_rect = pygame.Rect(head_cx - head_w // 2, head_y, head_w, head_h)

        # 머리카락 (전체 머리 — 갓 아래)
        pygame.draw.ellipse(surface, p["hair"], head_rect)
        pygame.draw.ellipse(surface, p["hair_highlight"],
                          head_rect.inflate(-int(0.2 * b), -int(0.15 * b)))

        # 얼굴
        face_rect = head_rect.inflate(-int(0.35 * b), -int(0.25 * b))
        face_rect.move_ip(0, int(0.2 * b))
        pygame.draw.ellipse(surface, p["skin"], face_rect)
        # 얼굴 그림자
        pygame.draw.ellipse(surface, p["skin_shadow"],
                          face_rect.inflate(-int(0.05 * b), -int(0.05 * b)), 1)

        # 눈썹 (엄격한 표정 — 찡그린 눈썹)
        eye_y = face_rect.centery - int(0.12 * b)
        for side in [-1, 1]:
            brow_x = face_rect.centerx + side * int(0.22 * b)
            brow_inner = brow_x - side * int(0.12 * b)
            brow_outer = brow_x + side * int(0.15 * b)
            # 안쪽이 약간 내려간 엄격한 눈썹
            pygame.draw.line(surface, p["eyebrow"],
                           (int(brow_inner), int(eye_y - 0.18 * b)),
                           (int(brow_outer), int(eye_y - 0.22 * b)), 2)

        # 눈 (날카로운 눈매)
        for side in [-1, 1]:
            eye_x = face_rect.centerx + side * int(0.22 * b)
            # 눈 흰자 (가로로 긴 타원)
            ew = int(0.22 * b)
            eh = int(0.12 * b)
            pygame.draw.ellipse(surface, p["eye_white"],
                              (int(eye_x - ew), int(eye_y - eh),
                               ew * 2, eh * 2))
            # 홍채
            iris_r = max(1, int(0.07 * b))
            pygame.draw.circle(surface, p["eye_iris"],
                             (int(eye_x), int(eye_y)), iris_r)
            # 동공
            pupil_r = max(1, int(0.03 * b))
            pygame.draw.circle(surface, p["eye_pupil"],
                             (int(eye_x), int(eye_y)), pupil_r)
            # 눈 하이라이트
            pygame.draw.circle(surface, (255, 255, 255),
                             (int(eye_x - 0.03 * b), int(eye_y - 0.03 * b)),
                             max(1, int(0.02 * b)))

        # 코
        nose_x = face_rect.centerx
        nose_y = face_rect.centery + int(0.05 * b)
        pygame.draw.line(surface, p["skin_shadow"],
                        (nose_x, nose_y),
                        (nose_x, nose_y + int(0.12 * b)), 1)
        pygame.draw.line(surface, p["skin_shadow"],
                        (nose_x - int(0.04 * b), nose_y + int(0.12 * b)),
                        (nose_x + int(0.04 * b), nose_y + int(0.12 * b)), 1)

        # 입 (꾹 다문 입)
        mouth_y = face_rect.bottom - int(0.3 * b)
        pygame.draw.line(surface, p["skin_shadow"],
                        (face_rect.centerx - int(0.13 * b), mouth_y),
                        (face_rect.centerx + int(0.13 * b), mouth_y), 1)

        # 수염 (콧수염 — 위엄있는 콧수염)
        mustache_y = mouth_y - int(0.08 * b)
        for side in [-1, 1]:
            # 콧수염 곡선
            start_x = face_rect.centerx + side * int(0.02 * b)
            end_x = face_rect.centerx + side * int(0.2 * b)
            mid_x = (start_x + end_x) // 2
            # 두꺼운 곡선 수염
            pygame.draw.line(surface, p["beard"],
                           (start_x, mustache_y),
                           (mid_x, mustache_y + int(0.04 * b)), 2)
            pygame.draw.line(surface, p["beard"],
                           (mid_x, mustache_y + int(0.04 * b)),
                           (end_x, mustache_y - int(0.02 * b)), 2)

        # 턱수염 (짧은 턱수염)
        chin_y = face_rect.bottom - int(0.15 * b)
        for i in range(3):
            bx = face_rect.centerx + (i - 1) * int(0.06 * b)
            pygame.draw.line(surface, p["beard"],
                           (bx, chin_y),
                           (bx, chin_y + int(0.1 * b)), 1)

        # 구레나룻
        for side in [-1, 1]:
            sx = face_rect.centerx + side * int(0.35 * b)
            sy = eye_y + int(0.1 * b)
            pygame.draw.line(surface, p["beard"],
                           (sx, sy), (sx, sy + int(0.25 * b)), 1)

    def _draw_gat(self, surface, cx, b, lean_offset, torso_y, p):
        """갓 (조선시대 전통 모자) — 둥근 넓은 챙 + 원통형 모자통"""
        head_cx = cx + lean_offset
        head_top = torso_y - int(2.0 * b)

        # 갓 위치 (머리 위)
        gat_y = head_top - int(0.3 * b)

        # 히트 시 갓 기울어짐
        gat_tilt = 0
        if self.is_hit:
            gat_tilt = int(self.hit_intensity * self.hit_direction * 0.3 * b)

        # === 갓 챙 (넓은 타원) ===
        brim_w = int(2.6 * b)
        brim_h = int(0.6 * b)
        brim_rect = pygame.Rect(
            head_cx - brim_w // 2 + gat_tilt,
            gat_y + int(0.2 * b),
            brim_w, brim_h
        )
        # 챙 그림자
        pygame.draw.ellipse(surface, (10, 8, 5, 120),
                          brim_rect.move(2, 3))
        # 챙 본체
        pygame.draw.ellipse(surface, p["gat_brim"], brim_rect)
        # 챙 하이라이트 (상단 엣지)
        pygame.draw.ellipse(surface, p["gat_shine"],
                          brim_rect.inflate(-int(0.3 * b), -int(0.15 * b)), 1)

        # === 갓 모자통 (원통) ===
        crown_w = int(1.0 * b)
        crown_h = int(0.9 * b)
        crown_rect = pygame.Rect(
            head_cx - crown_w // 2 + gat_tilt,
            gat_y - int(0.5 * b),
            crown_w, crown_h
        )
        # 모자통 본체
        pygame.draw.rect(surface, p["gat_crown"], crown_rect,
                        border_radius=max(1, int(0.15 * b)))
        # 모자통 하이라이트
        pygame.draw.rect(surface, p["gat_shine"],
                        crown_rect.inflate(-int(0.15 * b), -int(0.1 * b)), 1,
                        border_radius=max(1, int(0.1 * b)))
        # 모자통 상단 타원 (입체감)
        top_oval = pygame.Rect(
            crown_rect.left + int(0.05 * b),
            crown_rect.top - int(0.05 * b),
            crown_rect.width - int(0.1 * b),
            int(0.2 * b)
        )
        pygame.draw.ellipse(surface, p["gat_shine"], top_oval)

        # === 갓끈 (턱 아래로 내려오는 끈) ===
        chin_y = torso_y - int(0.6 * b)
        # 좌우 갓끈
        for side in [-1, 1]:
            brim_attach_x = head_cx + side * int(0.8 * b) + gat_tilt
            brim_attach_y = brim_rect.centery
            chin_x = head_cx + side * int(0.25 * b)

            pygame.draw.line(surface, p["gat_band"],
                           (int(brim_attach_x), int(brim_attach_y)),
                           (int(chin_x), int(chin_y)), 1)

        # 갓끈 매듭 (턱 아래)
        knot_y = chin_y + int(0.1 * b)
        pygame.draw.circle(surface, p["gat_band"],
                         (head_cx, int(knot_y)),
                         max(1, int(0.08 * b)))


# ===================================================================
#  싱글톤 패턴 (Stage1BossSprite와 동일)
# ===================================================================

_pododaejang_instance = None


def init_pododaejang_boss_sprite():
    """포도대장 보스 스프라이트 초기화"""
    global _pododaejang_instance
    try:
        _pododaejang_instance = PododaejangBossSprite()
        print("[Sprite] 포도대장 프로시저럴 스프라이트 초기화 완료")
        return _pododaejang_instance
    except Exception as e:
        print(f"[Sprite] 포도대장 스프라이트 초기화 실패: {e}")
        _pododaejang_instance = None
        return None


def get_pododaejang_boss_sprite():
    """포도대장 보스 스프라이트 싱글톤 반환"""
    global _pododaejang_instance
    if _pododaejang_instance is None:
        init_pododaejang_boss_sprite()
    return _pododaejang_instance


def reset_pododaejang_boss_sprite():
    """포도대장 보스 스프라이트 리셋"""
    global _pododaejang_instance
    if _pododaejang_instance:
        _pododaejang_instance.direction = 0
        _pododaejang_instance.is_hit = False
        _pododaejang_instance.hit_timer = 0.0
        _pododaejang_instance.time = 0.0
        _pododaejang_instance.step_phase = 0.0
        _pododaejang_instance.lean = 0.0
        _pododaejang_instance.body_bob = 0.0
