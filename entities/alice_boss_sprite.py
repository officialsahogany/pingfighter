"""
Alice Boss Sprite — 거울 나라의 앨리스 (Twisted Wonderland Girl) [Premium Edition]

- 파란 드레스 + 하얀 에이프런 (멀티 레이어 프릴)
- 금발 긴 머리 (리본 달린) + 다중 가닥 나부낌
- 손에 든 거울 (반짝이는 애니메이션 + 마법 파티클)
- 이동 시 드레스 넘실거림 (5단 프릴 + 관성 물리) + 머리카락 나부낌
- 상체/하체/얼굴 전문적 분리 + 고급 음영
- 3x SSAA 슈퍼샘플링
"""

import pygame
import math
import random

_sin = math.sin
_cos = math.cos
_pi = math.pi
_tau = math.pi * 2

# SSAA 배율
_SSAA = 3


class AliceBossSprite:
    """거울 나라의 앨리스 보스 스프라이트 (Premium)"""

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
        self.move_dir = 0
        self.side_blend = 0.0  # 이동 블렌드 (0=정지, 1=이동중)
        self.face_dir = 1.0
        self.face_dir_target = 0.0

        # 드레스 넘실거림 (관성 물리)
        self.dress_sway = 0.0
        self.dress_sway_vel = 0.0
        self.skirt_inertia = 0.0
        self.skirt_flow = 0.0

        # 머리카락 나부낌
        self.hair_sway = 0.0
        self.hair_sway_vel = 0.0

        # 리본 흔들림
        self.ribbon_sway = 0.0

        # 거울 반짝임
        self.mirror_sparkle = 0.0

        # 마법 파티클
        self.particles = []

        # 에이프런 리본 흔들림
        self.apron_bow_sway = 0.0

        # 서피스 캐시
        self._surface_cache = {}
        self._ssaa_cache_key = None
        self._ssaa_cache_surf = None

    def _get_surface(self, w, h):
        w = max(4, ((w + 3) // 4) * 4)
        h = max(4, ((h + 3) // 4) * 4)
        key = (w, h)
        if key not in self._surface_cache:
            self._surface_cache[key] = pygame.Surface((w, h), pygame.SRCALPHA)
        else:
            self._surface_cache[key].fill((0, 0, 0, 0))
        return self._surface_cache[key]

    def update(self, boss_x, dt):
        """매 프레임 애니메이션 상태 업데이트"""
        self.time += dt

        # 이동 속도 추정
        if self.prev_x is not None:
            raw_vel = (boss_x - self.prev_x) / max(dt, 0.001)
            self.velocity += (raw_vel - self.velocity) * min(dt * 8, 1.0)
        self.prev_x = boss_x

        speed = abs(self.velocity)
        moving = speed > 5.0

        # side_blend (정지↔이동 블렌드)
        target_blend = min(1.0, speed / 80.0) if moving else 0.0
        self.side_blend += (target_blend - self.side_blend) * min(dt * 5, 1.0)

        # 이동 방향
        if self.velocity > 10:
            self.move_dir = 1
            self.face_dir_target = 1.0
        elif self.velocity < -10:
            self.move_dir = -1
            self.face_dir_target = -1.0
        elif speed < 3:
            self.move_dir = 0

        # 얼굴 방향 부드러운 전환
        self.face_dir += (self.face_dir_target - self.face_dir) * min(dt * 6, 1.0)

        # 기울기 (관성) — 스프링 물리
        target_lean = self.velocity * 0.003
        target_lean = max(-0.15, min(0.15, target_lean))
        spring_k = 30.0
        damp = 8.0
        self.lean_velocity += (target_lean - self.lean) * spring_k * dt - self.lean_velocity * damp * dt
        self.lean += self.lean_velocity * dt

        # 걸음 위상
        if moving:
            self.step_phase += speed * dt * 0.025
        else:
            self.step_phase *= 0.9

        # 상체 흔들림
        self.body_bob = _sin(self.step_phase * 2) * (0.4 if moving else 0.12)
        self.body_roll = _sin(self.step_phase) * (0.025 if moving else 0.006)

        # 팔 흔들림
        self.arm_swing = _sin(self.step_phase * 2) * (0.2 if moving else 0.04)

        # 머리 기울기
        self.head_tilt = _sin(self.time * 1.5) * 0.02 + self.lean * 0.18

        # === 드레스 넘실거림 (투기장 히어로 스타일 관성 물리) ===
        # 이동 반대쪽으로 치마가 밀려남 (관성)
        self.skirt_inertia = -self.move_dir * self.side_blend * 1.0
        # 부드러운 넘실거림 (사인파)
        self.skirt_flow = _sin(self.time * 4.0) * self.side_blend * 0.5

        # 기존 sway (스프링 물리 — 강화)
        dress_target = max(-0.35, min(0.35, self.velocity * 0.004))
        self.dress_sway_vel += (dress_target - self.dress_sway) * 20 * dt - self.dress_sway_vel * 4.5 * dt
        self.dress_sway += self.dress_sway_vel * dt
        self.dress_sway = max(-0.45, min(0.45, self.dress_sway))

        # 머리카락 나부낌 (스프링 + 사인)
        hair_target = max(-0.08, min(0.08, self.velocity * 0.0015))
        self.hair_sway_vel += (hair_target - self.hair_sway) * 18 * dt - self.hair_sway_vel * 5 * dt
        self.hair_sway += self.hair_sway_vel * dt
        self.hair_sway = max(-0.12, min(0.12, self.hair_sway))
        self.hair_sway += _sin(self.time * 2.5) * 0.02

        # 리본 흔들림
        self.ribbon_sway = _sin(self.time * 3.0) * 0.04 + self.lean * 0.3

        # 거울 반짝임
        self.mirror_sparkle = (_sin(self.time * 3.0) + 1.0) * 0.5

        # 에이프런 리본 흔들림
        self.apron_bow_sway = _sin(self.time * 2.2) * 0.03 + self.dress_sway * 0.4

        # 마법 파티클 업데이트
        self._update_particles(dt)

    def _update_particles(self, dt):
        """거울에서 나오는 마법 파티클"""
        # 새 파티클 생성 (프레임당 확률적)
        if random.random() < 0.3:
            self.particles.append({
                'x': 0, 'y': 0,  # draw에서 거울 위치 기준으로 오프셋
                'vx': random.uniform(-15, 15),
                'vy': random.uniform(-25, -5),
                'life': 1.0,
                'size': random.uniform(1.0, 2.5),
                'hue': random.uniform(0, 1),
            })

        # 업데이트
        alive = []
        for p in self.particles:
            p['life'] -= dt * 0.8
            if p['life'] > 0:
                p['x'] += p['vx'] * dt
                p['y'] += p['vy'] * dt
                p['vy'] -= 10 * dt  # 약간 위로 가속
                alive.append(p)
        self.particles = alive[-20:]  # 최대 20개

    def draw(self, surface, x, y, w, h):
        """프로시저럴 앨리스 렌더링 (Premium SSAA)"""
        sw = w * _SSAA
        sh = h * _SSAA
        sf = self._get_surface(sw, sh)

        cx = sw // 2
        cy = sh // 2

        # === 색상 팔레트 (고급) ===
        # 드레스 (로얄 블루 그라데이션)
        dress_blue = (95, 145, 225)
        dress_light = (130, 175, 245)
        dress_mid = (110, 160, 235)
        dress_dark = (65, 105, 185)
        dress_shadow = (45, 80, 155)
        dress_rim = (140, 185, 250)  # 림라이트

        # 에이프런
        apron_white = (245, 243, 252)
        apron_shadow = (225, 220, 235)
        apron_lace = (235, 232, 245)

        # 피부
        skin = (255, 225, 200)
        skin_light = (255, 235, 215)
        skin_shadow = (235, 195, 170)
        skin_deep = (215, 175, 150)

        # 머리카락
        hair_gold = (245, 205, 105)
        hair_light = (255, 225, 140)
        hair_mid = (230, 190, 85)
        hair_dark = (200, 160, 60)
        hair_shadow = (170, 135, 45)

        # 악세서리
        ribbon_blue = (75, 125, 215)
        ribbon_light = (110, 155, 240)
        ribbon_dark = (50, 90, 175)
        eye_blue = (55, 95, 200)
        eye_light = (90, 140, 235)
        eye_dark = (35, 65, 150)
        black = (25, 20, 30)
        white = (255, 255, 255)
        pink = (255, 180, 195)
        pink_light = (255, 200, 215)

        # 거울
        mirror_frame_gold = (195, 165, 80)
        mirror_frame_light = (220, 195, 120)
        mirror_frame_dark = (160, 130, 55)
        mirror_glass = (195, 215, 255)
        mirror_glass_light = (220, 235, 255)

        # 스타킹
        stocking_white = (248, 245, 255)
        stocking_shadow = (230, 225, 240)

        # 구두
        shoe_black = (30, 25, 35)
        shoe_highlight = (60, 55, 70)

        # 스케일 팩터
        s = min(sw, sh) / 200.0

        # body bob 적용
        bob_y = int(self.body_bob * s * 1.8)
        lean_px = int(self.lean * s * 12)

        # === 치마 넘실거림 계산 (투기장 스타일 — 강화) ===
        sway_px = int(self.dress_sway * s * 20)
        skirt_inertia_px = int(self.skirt_inertia * s * 16)
        skirt_flow_px = int(self.skirt_flow * s * 12)
        total_skirt_sway = sway_px + skirt_inertia_px + skirt_flow_px
        skirt_wave_boost = 1.0 + self.side_blend * 3.5

        # ============================================
        # ===  뒷머리카락 (드레스 뒤로 길게)  ===
        # ============================================
        head_cx = cx + int(self.head_tilt * s * 12) + lean_px
        head_cy = cy - int(34 * s) + bob_y
        hair_sway_px = int(self.hair_sway * s * 18)

        # 뒷머리 — 여러 가닥으로 분리
        for strand_i in range(5):
            strand_offset_x = (strand_i - 2) * int(8 * s)
            strand_sway = hair_sway_px + int(_sin(self.time * 2.0 + strand_i * 0.7) * s * 3)
            strand_color = hair_gold if strand_i % 2 == 0 else hair_mid
            hair_strand = [
                (head_cx + strand_offset_x - int(5 * s), head_cy - int(2 * s)),
                (head_cx + strand_offset_x + int(5 * s), head_cy - int(2 * s)),
                (head_cx + strand_offset_x + int(7 * s) + strand_sway, cy + int(18 * s) + bob_y),
                (head_cx + strand_offset_x + int(2 * s) + strand_sway, cy + int(22 * s) + bob_y),
                (head_cx + strand_offset_x - int(2 * s) + strand_sway, cy + int(22 * s) + bob_y),
                (head_cx + strand_offset_x - int(7 * s) + strand_sway, cy + int(18 * s) + bob_y),
            ]
            pygame.draw.polygon(sf, strand_color, hair_strand)

        # 머리카락 하이라이트 라인
        for i in range(7):
            hx = head_cx - int(16 * s) + int(i * 5.5 * s)
            h_sway = hair_sway_px + int(_sin(self.time * 1.8 + i * 0.5) * s * 2)
            pygame.draw.line(sf, hair_light,
                             (hx, head_cy + int(5 * s)),
                             (hx + h_sway, cy + int(20 * s) + bob_y),
                             max(1, int(0.8 * s)))

        # ============================================
        # ===  드레스 하반신 (5단 프릴 넘실거림)  ===
        # ============================================
        dress_top_y = cy + int(6 * s) + bob_y
        dress_bot_y = cy + int(52 * s) + bob_y
        dress_w_top = int(20 * s)
        dress_w_bot = int(42 * s)

        # 메인 드레스 실루엣 (A라인)
        # 핵심: 상단(허리)은 lean_px만, 하단(치맛단)만 넘실거림!
        dress_main = [
            (cx - dress_w_top + lean_px, dress_top_y),
            (cx + dress_w_top + lean_px, dress_top_y),
            (cx + dress_w_bot + total_skirt_sway + lean_px, dress_bot_y),
            (cx - dress_w_bot + total_skirt_sway + lean_px, dress_bot_y),
        ]
        pygame.draw.polygon(sf, dress_blue, dress_main)

        # 드레스 그라데이션 음영 (왼쪽 어둡게)
        shade_pts = [
            (cx - int(12 * s) + lean_px, dress_top_y + int(4 * s)),
            (cx + int(2 * s) + lean_px, dress_top_y + int(2 * s)),
            (cx - int(5 * s) + total_skirt_sway + lean_px, dress_bot_y),
            (cx - dress_w_bot + int(4 * s) + total_skirt_sway + lean_px, dress_bot_y),
        ]
        pygame.draw.polygon(sf, dress_dark, shade_pts)

        # 드레스 림라이트 (오른쪽 밝은 선)
        rim_pts = [
            (cx + dress_w_top - int(3 * s) + lean_px, dress_top_y + int(2 * s)),
            (cx + dress_w_top + lean_px, dress_top_y),
            (cx + dress_w_bot + total_skirt_sway + lean_px, dress_bot_y),
            (cx + dress_w_bot - int(5 * s) + total_skirt_sway + lean_px, dress_bot_y),
        ]
        pygame.draw.polygon(sf, dress_light, rim_pts)

        # 드레스 세로 주름 (관성으로 비스듬히 흔들림)
        for i in range(9):
            fold_shift = int((skirt_inertia_px + skirt_flow_px) * (i - 4) * 0.06)
            fold_x = cx + (i - 4) * int(4.5 * s) + lean_px + fold_shift
            fold_top = dress_top_y + int(3 * s)
            fold_bot = dress_bot_y - int(4 * s) + int(_sin(self.time * 3.5 + i * 0.4) * s * 2.0 * skirt_wave_boost)
            fold_color = dress_mid if i % 2 == 0 else dress_dark
            pygame.draw.line(sf, fold_color, (fold_x, fold_top),
                             (fold_x + fold_shift, fold_bot), max(1, int(0.7 * s)))

        # === 5단 프릴 레이어 (아래일수록 넘실거림 강화) ===
        for layer in range(5):
            frill_y = dress_top_y + int(10 * s) + layer * int(9 * s)
            frill_w = dress_w_top + int(4 * s) + layer * int(4.5 * s)

            # 아래 레이어일수록 관성 영향 크게 강화 (천 물리)
            layer_factor = 1.0 + layer * 0.5
            layer_sway = int((skirt_inertia_px + skirt_flow_px) * layer_factor)

            # 프릴 물결 패턴 (아래일수록 진폭 강화)
            frill_points = []
            segments = 14
            frill_wave_amp = (0.10 + self.side_blend * 0.25) * (1.0 + layer * 0.25)
            layer_phase = layer * 0.4

            for seg in range(segments + 1):
                fx = cx - frill_w + int(seg * frill_w * 2 / segments) + lean_px + layer_sway
                fy = frill_y + int(_sin(seg * 0.75 + self.time * 3.5 - layer_phase) * frill_wave_amp * s * 14)
                frill_points.append((fx, fy))

            # 프릴 라인 그리기
            frill_color = apron_lace if layer % 2 == 0 else dress_light
            for seg in range(len(frill_points) - 1):
                pygame.draw.line(sf, frill_color, frill_points[seg], frill_points[seg + 1],
                                 max(1, int(0.9 * s)))

            # 레이스 아크 장식 (짝수 레이어)
            if layer % 2 == 0:
                arc_w = frill_w * 2
                arc_h = int(4 * s)
                arc_x = cx - frill_w + lean_px + layer_sway
                arc_y = frill_y - int(1 * s)
                if arc_w > 0 and arc_h > 0:
                    pygame.draw.arc(sf, apron_white,
                                    (arc_x, arc_y, arc_w, arc_h),
                                    _pi, _tau, max(1, int(0.8 * s)))

        # === 에이프런 (하반신) ===
        apron_sway = total_skirt_sway
        apron_pts = [
            (cx - int(15 * s) + lean_px, dress_top_y + int(2 * s)),          # 상단: 고정
            (cx + int(15 * s) + lean_px, dress_top_y + int(2 * s)),          # 상단: 고정
            (cx + int(24 * s) + apron_sway + lean_px, dress_bot_y - int(6 * s)),  # 하단: 넘실
            (cx - int(24 * s) + apron_sway + lean_px, dress_bot_y - int(6 * s)),  # 하단: 넘실
        ]
        apron_surf = self._get_surface(sw, sh)
        pygame.draw.polygon(apron_surf, (*apron_white, 200), apron_pts)
        sf.blit(apron_surf, (0, 0))

        # 에이프런 레이스 장식 (하단 스캘럽)
        apron_bot = dress_bot_y - int(6 * s)
        for i in range(8):
            lx = cx - int(22 * s) + int(i * 6.2 * s) + apron_sway + lean_px
            ly = apron_bot - int(3 * s)
            aw = int(6 * s)
            ah = int(5 * s)
            if aw > 0 and ah > 0:
                pygame.draw.arc(sf, apron_lace,
                                (lx, ly, aw, ah),
                                _pi, _tau, max(1, int(0.8 * s)))

        # 에이프런 세로 주름
        for i in range(5):
            ax = cx + (i - 2) * int(6 * s) + lean_px + apron_sway // 2
            pygame.draw.line(sf, apron_shadow,
                             (ax, dress_top_y + int(6 * s)),
                             (ax + apron_sway // 3, apron_bot - int(2 * s)),
                             max(1, int(0.6 * s)))

        # ============================================
        # ===  다리 + 스타킹 + 구두  ===
        # ============================================
        leg_y = dress_bot_y - int(3 * s)
        leg_step_l = _sin(self.step_phase * 2) * (3 if abs(self.velocity) > 5 else 0)
        leg_step_r = _sin(self.step_phase * 2 + _pi) * (3 if abs(self.velocity) > 5 else 0)

        for side, step_offset in [(-1, leg_step_l), (1, leg_step_r)]:
            lx = cx + side * int(8 * s) + lean_px  # 다리는 넘실거림 없이 lean만
            ly = leg_y + int(step_offset * s * 0.5)

            # 스타킹 (하얀 니하이)
            pygame.draw.ellipse(sf, stocking_shadow,
                                (lx - int(5 * s), ly, int(10 * s), int(16 * s)))
            pygame.draw.ellipse(sf, stocking_white,
                                (lx - int(4 * s), ly + int(1 * s), int(8 * s), int(14 * s)))
            # 스타킹 레이스 상단
            pygame.draw.arc(sf, apron_lace,
                            (lx - int(6 * s), ly - int(1 * s), int(12 * s), int(4 * s)),
                            0, _pi, max(1, int(0.7 * s)))

            # 메리제인 구두
            shoe_y = ly + int(12 * s)
            pygame.draw.ellipse(sf, shoe_black,
                                (lx - int(6 * s), shoe_y, int(12 * s), int(6 * s)))
            # 구두 하이라이트
            pygame.draw.ellipse(sf, shoe_highlight,
                                (lx - int(3 * s), shoe_y + int(1 * s), int(5 * s), int(3 * s)))
            # 구두 스트랩
            pygame.draw.line(sf, shoe_highlight,
                             (lx - int(4 * s), shoe_y + int(2 * s)),
                             (lx + int(4 * s), shoe_y + int(2 * s)),
                             max(1, int(0.5 * s)))
            # 버클 (작은 금색 원)
            pygame.draw.circle(sf, mirror_frame_gold,
                               (lx, shoe_y + int(2 * s)), max(1, int(1.2 * s)))

        # ============================================
        # ===  상체 (코르셋 + 퍼프 슬리브)  ===
        # ============================================
        body_top_y = cy - int(16 * s) + bob_y
        body_bot_y = dress_top_y + int(6 * s)
        body_h = body_bot_y - body_top_y

        # 상체 메인 (약간 좁은 코르셋 실루엣)
        torso_w = int(19 * s)
        body_pts = [
            (cx - torso_w + int(2 * s) + lean_px, body_top_y + int(3 * s)),
            (cx + torso_w - int(2 * s) + lean_px, body_top_y + int(3 * s)),
            (cx + torso_w + lean_px, body_bot_y),
            (cx - torso_w + lean_px, body_bot_y),
        ]
        pygame.draw.polygon(sf, dress_blue, body_pts)

        # 코르셋 음영 (입체감)
        corset_shade = [
            (cx - torso_w + int(3 * s) + lean_px, body_top_y + int(4 * s)),
            (cx - int(2 * s) + lean_px, body_top_y + int(3 * s)),
            (cx - int(4 * s) + lean_px, body_bot_y),
            (cx - torso_w + int(2 * s) + lean_px, body_bot_y),
        ]
        pygame.draw.polygon(sf, dress_dark, corset_shade)

        # 코르셋 림라이트
        corset_rim = [
            (cx + torso_w - int(5 * s) + lean_px, body_top_y + int(4 * s)),
            (cx + torso_w - int(2 * s) + lean_px, body_top_y + int(3 * s)),
            (cx + torso_w + lean_px, body_bot_y),
            (cx + torso_w - int(4 * s) + lean_px, body_bot_y),
        ]
        pygame.draw.polygon(sf, dress_light, corset_rim)

        # 코르셋 레이스업 (중앙 X자 라인)
        for i in range(4):
            lace_y = body_top_y + int(5 * s) + i * int(4 * s)
            lace_w = int(3 * s)
            pygame.draw.line(sf, apron_white,
                             (cx - lace_w + lean_px, lace_y),
                             (cx + lace_w + lean_px, lace_y + int(3 * s)),
                             max(1, int(0.6 * s)))
            pygame.draw.line(sf, apron_white,
                             (cx + lace_w + lean_px, lace_y),
                             (cx - lace_w + lean_px, lace_y + int(3 * s)),
                             max(1, int(0.6 * s)))

        # 에이프런 상단 (가슴받이) — 둥근 삼각형
        apron_bib = [
            (cx - int(11 * s) + lean_px, body_top_y + int(5 * s)),
            (cx + int(11 * s) + lean_px, body_top_y + int(5 * s)),
            (cx + int(13 * s) + lean_px, body_bot_y - int(2 * s)),
            (cx - int(13 * s) + lean_px, body_bot_y - int(2 * s)),
        ]
        pygame.draw.polygon(sf, apron_white, apron_bib)

        # 가슴받이 레이스 테두리
        pygame.draw.lines(sf, apron_lace, False, [
            (cx - int(11 * s) + lean_px, body_top_y + int(5 * s)),
            (cx + lean_px, body_top_y + int(3 * s)),
            (cx + int(11 * s) + lean_px, body_top_y + int(5 * s)),
        ], max(1, int(0.8 * s)))

        # 가슴받이 작은 리본
        bow_cx = cx + lean_px
        bow_cy = body_top_y + int(5 * s)
        bow_s = int(4 * s)
        pygame.draw.polygon(sf, ribbon_blue, [
            (bow_cx, bow_cy),
            (bow_cx - bow_s, bow_cy - int(2 * s)),
            (bow_cx - int(1 * s), bow_cy),
            (bow_cx - bow_s, bow_cy + int(2 * s)),
        ])
        pygame.draw.polygon(sf, ribbon_blue, [
            (bow_cx, bow_cy),
            (bow_cx + bow_s, bow_cy - int(2 * s)),
            (bow_cx + int(1 * s), bow_cy),
            (bow_cx + bow_s, bow_cy + int(2 * s)),
        ])
        pygame.draw.circle(sf, ribbon_light, (bow_cx, bow_cy), max(1, int(1.2 * s)))

        # ============================================
        # ===  퍼프 슬리브 + 팔  ===
        # ============================================
        arm_angle_l = self.arm_swing * 0.25
        arm_angle_r = -self.arm_swing * 0.25

        for side, arm_angle in [(-1, arm_angle_l), (1, arm_angle_r)]:
            ax = cx + side * int(22 * s) + lean_px
            ay = body_top_y + int(5 * s)

            # 퍼프 슬리브 (부풀린 소매) — 큰 원 + 리본
            puff_r = int(8 * s)
            puff_cy = ay + int(3 * s) + int(arm_angle * 8)
            pygame.draw.circle(sf, dress_blue, (ax + int(4 * s * side), puff_cy), puff_r)
            # 소매 하이라이트
            pygame.draw.circle(sf, dress_light,
                               (ax + int(4 * s * side) + int(2 * s), puff_cy - int(2 * s)),
                               puff_r - int(3 * s))
            # 소매 하단 레이스
            pygame.draw.arc(sf, apron_lace,
                            (ax + int(4 * s * side) - puff_r, puff_cy + puff_r - int(3 * s),
                             puff_r * 2, int(5 * s)),
                            0, _pi, max(1, int(0.7 * s)))

            # 팔 (피부) — 가늘고 우아하게
            arm_len = int(16 * s)
            arm_w = int(6 * s)
            arm_top = puff_cy + puff_r - int(4 * s)
            pygame.draw.ellipse(sf, skin_shadow,
                                (ax + int(2 * s * side), arm_top + int(arm_angle * 12),
                                 arm_w, arm_len))
            pygame.draw.ellipse(sf, skin,
                                (ax + int(2 * s * side) + int(0.5 * s), arm_top + int(1 * s) + int(arm_angle * 12),
                                 arm_w - int(1 * s), arm_len - int(2 * s)))

            # 손 (작은 원)
            hand_y = arm_top + arm_len - int(3 * s) + int(arm_angle * 12)
            hand_x = ax + int(5 * s * side)
            pygame.draw.circle(sf, skin, (hand_x, hand_y), int(3.5 * s))
            pygame.draw.circle(sf, skin_light, (hand_x - int(0.5 * s), hand_y - int(0.5 * s)), int(2.5 * s))

        # ============================================
        # ===  거울 (오른손에 — 화려한 디자인)  ===
        # ============================================
        mirror_hand_x = cx + int(27 * s) + lean_px
        mirror_hand_y = body_top_y + int(28 * s) + int(arm_angle_r * 12)
        mr = int(10 * s)

        # 거울 손잡이 (장식)
        handle_x = mirror_hand_x
        handle_y = mirror_hand_y + mr + int(2 * s)
        pygame.draw.rect(sf, mirror_frame_dark,
                         (handle_x - int(2.5 * s), handle_y,
                          int(5 * s), int(10 * s)), border_radius=int(1 * s))
        pygame.draw.rect(sf, mirror_frame_gold,
                         (handle_x - int(2 * s), handle_y + int(1 * s),
                          int(4 * s), int(8 * s)), border_radius=int(1 * s))

        # 거울 프레임 (장식적 금테)
        pygame.draw.circle(sf, mirror_frame_dark, (mirror_hand_x, mirror_hand_y), mr + int(3 * s))
        pygame.draw.circle(sf, mirror_frame_gold, (mirror_hand_x, mirror_hand_y), mr + int(2 * s))
        # 프레임 보석 장식 (4개)
        for gem_i in range(4):
            gem_angle = gem_i * _pi / 2 + _pi / 4
            gx = mirror_hand_x + int(_cos(gem_angle) * (mr + int(2 * s)))
            gy = mirror_hand_y + int(_sin(gem_angle) * (mr + int(2 * s)))
            pygame.draw.circle(sf, eye_light, (gx, gy), max(1, int(1.5 * s)))
            pygame.draw.circle(sf, white, (gx - int(0.3 * s), gy - int(0.3 * s)), max(1, int(0.7 * s)))

        # 거울 유리
        pygame.draw.circle(sf, mirror_glass, (mirror_hand_x, mirror_hand_y), mr)
        # 거울 하이라이트 그라데이션
        pygame.draw.circle(sf, mirror_glass_light,
                           (mirror_hand_x - int(2 * s), mirror_hand_y - int(2 * s)), mr - int(3 * s))

        # 거울 반짝임 효과 (다중 레이어)
        sparkle_alpha = int(80 + 175 * self.mirror_sparkle)
        sparkle_surf = self._get_surface(mr * 3, mr * 3)
        # 큰 글로우
        pygame.draw.circle(sparkle_surf, (255, 255, 255, sparkle_alpha // 2),
                           (mr * 3 // 2, mr * 3 // 2), mr)
        # 작은 밝은 점
        pygame.draw.circle(sparkle_surf, (255, 255, 255, sparkle_alpha),
                           (mr * 3 // 2 - int(2 * s), mr * 3 // 2 - int(2 * s)), mr // 3)
        # 십자 반짝임
        cross_len = int(mr * 0.6)
        cross_alpha = int(sparkle_alpha * 0.7)
        for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            pygame.draw.line(sparkle_surf, (255, 255, 255, cross_alpha),
                             (mr * 3 // 2, mr * 3 // 2),
                             (mr * 3 // 2 + dx * cross_len, mr * 3 // 2 + dy * cross_len),
                             max(1, int(0.5 * s)))
        sf.blit(sparkle_surf, (mirror_hand_x - mr * 3 // 2, mirror_hand_y - mr * 3 // 2))

        # 마법 파티클 (거울 주변)
        for p in self.particles:
            px = mirror_hand_x + int(p['x'] * s * 0.5)
            py = mirror_hand_y + int(p['y'] * s * 0.5)
            pa = int(p['life'] * 180)
            pr = max(1, int(p['size'] * s))
            # 파티클 색상 (파란~보라 스펙트럼)
            pr_c = int(150 + 105 * _sin(p['hue'] * _tau))
            pg_c = int(180 + 75 * _sin(p['hue'] * _tau + 2))
            pb_c = 255
            p_surf = self._get_surface(pr * 4, pr * 4)
            pygame.draw.circle(p_surf, (pr_c, pg_c, pb_c, pa), (pr * 2, pr * 2), pr)
            sf.blit(p_surf, (px - pr * 2, py - pr * 2))

        # ============================================
        # ===  머리 (고급 얼굴 디테일)  ===
        # ============================================
        head_r = int(19 * s)

        # 얼굴 베이스 (그라데이션 효과)
        pygame.draw.circle(sf, skin_shadow, (head_cx + int(2 * s), head_cy + int(2 * s)), head_r)
        pygame.draw.circle(sf, skin, (head_cx, head_cy), head_r)
        pygame.draw.circle(sf, skin_light,
                           (head_cx - int(2 * s), head_cy - int(3 * s)), head_r - int(4 * s))

        # 앞머리 (디테일 뱅) — 여러 가닥
        # 베이스 뱅
        bang_base = [
            (head_cx - int(20 * s), head_cy - int(1 * s)),
            (head_cx - int(16 * s), head_cy - int(17 * s)),
            (head_cx - int(8 * s), head_cy - int(20 * s)),
            (head_cx, head_cy - int(21 * s)),
            (head_cx + int(8 * s), head_cy - int(20 * s)),
            (head_cx + int(16 * s), head_cy - int(17 * s)),
            (head_cx + int(20 * s), head_cy - int(1 * s)),
            (head_cx + int(14 * s), head_cy - int(4 * s)),
            (head_cx + int(8 * s), head_cy - int(7 * s)),
            (head_cx, head_cy - int(8 * s)),
            (head_cx - int(8 * s), head_cy - int(7 * s)),
            (head_cx - int(14 * s), head_cy - int(4 * s)),
        ]
        pygame.draw.polygon(sf, hair_gold, bang_base)

        # 뱅 가닥 디테일 (밝은 하이라이트)
        for i in range(5):
            bx = head_cx - int(14 * s) + int(i * 7 * s)
            pygame.draw.line(sf, hair_light,
                             (bx, head_cy - int(18 * s) + abs(i - 2) * int(2 * s)),
                             (bx + int(1 * s), head_cy - int(5 * s)),
                             max(1, int(0.8 * s)))
        # 뱅 음영 라인
        for i in range(3):
            bx = head_cx - int(10 * s) + int(i * 10 * s)
            pygame.draw.line(sf, hair_dark,
                             (bx, head_cy - int(16 * s) + abs(i - 1) * int(3 * s)),
                             (bx, head_cy - int(6 * s)),
                             max(1, int(0.6 * s)))

        # 사이드 머리카락 (얼굴 양옆으로 내려오는 긴 가닥)
        for side in [-1, 1]:
            side_hair = [
                (head_cx + side * int(18 * s), head_cy - int(5 * s)),
                (head_cx + side * int(22 * s), head_cy + int(5 * s)),
                (head_cx + side * int(20 * s) + hair_sway_px // 2, cy + int(5 * s) + bob_y),
                (head_cx + side * int(15 * s) + hair_sway_px // 2, cy + int(8 * s) + bob_y),
                (head_cx + side * int(16 * s), head_cy + int(10 * s)),
            ]
            pygame.draw.polygon(sf, hair_mid, side_hair)
            # 사이드 하이라이트
            pygame.draw.line(sf, hair_light,
                             (head_cx + side * int(19 * s), head_cy),
                             (head_cx + side * int(18 * s) + hair_sway_px // 2, cy + int(6 * s) + bob_y),
                             max(1, int(0.8 * s)))

        # === 눈 (대형 애니메 스타일 — 고급 디테일) ===
        eye_y = head_cy + int(1 * s)
        for side in [-1, 1]:
            ex = head_cx + side * int(7.5 * s)

            # 눈 그림자 (위쪽)
            pygame.draw.ellipse(sf, skin_deep,
                                (ex - int(6 * s), eye_y - int(5.5 * s),
                                 int(12 * s), int(4 * s)))

            # 흰자
            pygame.draw.ellipse(sf, white,
                                (ex - int(5.5 * s), eye_y - int(4.5 * s),
                                 int(11 * s), int(9 * s)))

            # 홍채 (그라데이션)
            iris_r = int(3.5 * s)
            pygame.draw.circle(sf, eye_dark, (ex, eye_y), iris_r)
            pygame.draw.circle(sf, eye_blue, (ex, eye_y), iris_r - int(0.8 * s))
            # 홍채 상단 밝은 부분
            pygame.draw.circle(sf, eye_light,
                               (ex, eye_y - int(1 * s)), iris_r - int(1.5 * s))

            # 동공
            pygame.draw.circle(sf, black, (ex, eye_y + int(0.3 * s)), int(1.8 * s))

            # 하이라이트 (큰 + 작은)
            pygame.draw.circle(sf, white,
                               (ex - int(1.5 * s), eye_y - int(1.5 * s)), int(1.3 * s))
            pygame.draw.circle(sf, white,
                               (ex + int(1 * s), eye_y + int(1 * s)), int(0.7 * s))

            # 속눈썹 (위쪽 3개)
            for lash_i in range(3):
                lash_angle = _pi * 0.6 + lash_i * _pi * 0.15
                lash_x1 = ex + int(_cos(lash_angle) * 5 * s) * side
                lash_y1 = eye_y - int(4 * s)
                lash_x2 = ex + int(_cos(lash_angle) * 7.5 * s) * side
                lash_y2 = eye_y - int(5.5 * s) - lash_i * int(0.5 * s)
                pygame.draw.line(sf, black, (lash_x1, lash_y1), (lash_x2, lash_y2),
                                 max(1, int(0.8 * s)))

        # 볼 홍조 (부드러운 그라데이션)
        for side in [-1, 1]:
            blush_x = head_cx + side * int(10 * s) - int(5 * s)
            blush_y = eye_y + int(4 * s)
            blush_surf = self._get_surface(int(12 * s), int(7 * s))
            pygame.draw.ellipse(blush_surf, (*pink, 70),
                                (0, 0, int(12 * s), int(7 * s)))
            pygame.draw.ellipse(blush_surf, (*pink_light, 40),
                                (int(1 * s), int(1 * s), int(10 * s), int(5 * s)))
            sf.blit(blush_surf, (blush_x, blush_y))

        # 입 (작은 고양이 입)
        mouth_y = head_cy + int(8 * s)
        # 윗입술 라인
        pygame.draw.arc(sf, (200, 100, 110),
                        (head_cx - int(3 * s), mouth_y - int(2 * s),
                         int(6 * s), int(4 * s)),
                        _pi + 0.3, _tau - 0.3, max(1, int(1.2 * s)))
        # 작은 하이라이트 (입술 광택)
        pygame.draw.circle(sf, (*pink_light, 120),
                           (head_cx, mouth_y), max(1, int(0.8 * s)))

        # 코 (미세한 점)
        pygame.draw.circle(sf, skin_shadow,
                           (head_cx, head_cy + int(4 * s)), max(1, int(0.8 * s)))

        # ============================================
        # ===  리본 (머리 위 — 화려하게)  ===
        # ============================================
        ribbon_cx = head_cx + int(13 * s)
        ribbon_cy = head_cy - int(17 * s)
        ribbon_sway_px = int(self.ribbon_sway * s * 6)

        # 리본 꼬리 (뒤로 늘어지는 2개)
        for tail_side in [-1, 1]:
            tail_pts = [
                (ribbon_cx + tail_side * int(3 * s), ribbon_cy + int(2 * s)),
                (ribbon_cx + tail_side * int(6 * s) + ribbon_sway_px, ribbon_cy + int(12 * s)),
                (ribbon_cx + tail_side * int(4 * s) + ribbon_sway_px, ribbon_cy + int(14 * s)),
                (ribbon_cx + tail_side * int(1 * s), ribbon_cy + int(4 * s)),
            ]
            pygame.draw.polygon(sf, ribbon_dark, tail_pts)

        # 리본 좌우 날개 (큰 리본)
        rb_size = int(9 * s)
        # 왼쪽 날개
        pygame.draw.polygon(sf, ribbon_blue, [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx - rb_size, ribbon_cy - int(6 * s)),
            (ribbon_cx - int(3 * s), ribbon_cy),
            (ribbon_cx - rb_size, ribbon_cy + int(6 * s)),
        ])
        pygame.draw.polygon(sf, ribbon_light, [
            (ribbon_cx - int(1 * s), ribbon_cy),
            (ribbon_cx - rb_size + int(2 * s), ribbon_cy - int(4 * s)),
            (ribbon_cx - int(3 * s), ribbon_cy),
        ])
        # 오른쪽 날개
        pygame.draw.polygon(sf, ribbon_blue, [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx + rb_size, ribbon_cy - int(6 * s)),
            (ribbon_cx + int(3 * s), ribbon_cy),
            (ribbon_cx + rb_size, ribbon_cy + int(6 * s)),
        ])
        pygame.draw.polygon(sf, ribbon_light, [
            (ribbon_cx + int(1 * s), ribbon_cy),
            (ribbon_cx + rb_size - int(2 * s), ribbon_cy - int(4 * s)),
            (ribbon_cx + int(3 * s), ribbon_cy),
        ])
        # 리본 중심 보석
        pygame.draw.circle(sf, ribbon_dark, (ribbon_cx, ribbon_cy), int(2.5 * s))
        pygame.draw.circle(sf, ribbon_light, (ribbon_cx, ribbon_cy), int(1.8 * s))
        pygame.draw.circle(sf, white,
                           (ribbon_cx - int(0.5 * s), ribbon_cy - int(0.5 * s)), int(0.8 * s))

        # ============================================
        # ===  에이프런 뒤 리본 (허리 뒤)  ===
        # ============================================
        apron_bow_cx = cx + lean_px
        apron_bow_cy = dress_top_y + int(1 * s)
        apron_bow_sway_px = int(self.apron_bow_sway * s * 10)

        # 큰 나비 리본 (뒤)
        ab_size = int(12 * s)
        for bow_side in [-1, 1]:
            bow_pts = [
                (apron_bow_cx, apron_bow_cy),
                (apron_bow_cx + bow_side * ab_size, apron_bow_cy - int(5 * s)),
                (apron_bow_cx + bow_side * int(4 * s), apron_bow_cy),
                (apron_bow_cx + bow_side * ab_size, apron_bow_cy + int(5 * s)),
            ]
            pygame.draw.polygon(sf, apron_white, bow_pts)
            pygame.draw.polygon(sf, apron_shadow, [
                (apron_bow_cx + bow_side * int(2 * s), apron_bow_cy),
                (apron_bow_cx + bow_side * ab_size, apron_bow_cy + int(3 * s)),
                (apron_bow_cx + bow_side * int(4 * s), apron_bow_cy),
            ])

        # 리본 꼬리 (아래로 흘러내림)
        for tail_s in [-1, 1]:
            tail_pts = [
                (apron_bow_cx + tail_s * int(3 * s), apron_bow_cy + int(3 * s)),
                (apron_bow_cx + tail_s * int(6 * s) + apron_bow_sway_px,
                 apron_bow_cy + int(20 * s)),
                (apron_bow_cx + tail_s * int(4 * s) + apron_bow_sway_px,
                 apron_bow_cy + int(22 * s)),
                (apron_bow_cx + tail_s * int(1 * s), apron_bow_cy + int(5 * s)),
            ]
            pygame.draw.polygon(sf, apron_lace, tail_pts)

        # 리본 중심
        pygame.draw.circle(sf, apron_shadow, (apron_bow_cx, apron_bow_cy), int(2.5 * s))

        # ============================================
        # ===  마법 오라 (거울 주변 글로우)  ===
        # ============================================
        aura_pulse = (_sin(self.time * 2.0) + 1.0) * 0.5
        aura_r = int(16 * s)
        aura_surf = self._get_surface(aura_r * 2, aura_r * 2)
        for ring in range(3):
            ring_alpha = int((25 - ring * 7) * aura_pulse)
            ring_r = aura_r - ring * int(3 * s)
            if ring_r > 0 and ring_alpha > 0:
                pygame.draw.circle(aura_surf, (180, 200, 255, ring_alpha),
                                   (aura_r, aura_r), ring_r)
        sf.blit(aura_surf, (mirror_hand_x - aura_r, mirror_hand_y - aura_r))

        # === SSAA 다운스케일 ===
        result = pygame.transform.smoothscale(sf, (w, h))
        surface.blit(result, (x, y))


# 싱글톤
_alice_sprite_instance = None


def get_alice_sprite():
    """앨리스 보스 스프라이트 싱글톤 반환"""
    global _alice_sprite_instance
    if _alice_sprite_instance is None:
        _alice_sprite_instance = AliceBossSprite()
    return _alice_sprite_instance


def init_alice_boss_sprite():
    """앨리스 보스 스프라이트 초기화 (재생성)"""
    global _alice_sprite_instance
    _alice_sprite_instance = AliceBossSprite()
    return _alice_sprite_instance
