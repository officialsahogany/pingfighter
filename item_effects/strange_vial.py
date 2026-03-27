"""
기묘한 약병 (Strange Vial) - 액티브 아이템
50% 확률로 거대화(패들 220% + 이속 -50%) 또는 축소(패들 -50% + 이속 +170%)
지속시간: 30초 (1800 프레임 @ 60fps)
"""
import random
import math
import pygame

# 상수
STRANGE_VIAL_DURATION_FRAMES = 1800  # 30초
STRANGE_VIAL_ENLARGE_PADDLE_MULT = 2.2   # 패들 220% (2.2배)
STRANGE_VIAL_ENLARGE_SPEED_MULT = 0.5    # 이속 -50% (50%만 적용)
STRANGE_VIAL_SHRINK_PADDLE_MULT = 0.5    # 패들 -50% (50%만 적용)
STRANGE_VIAL_SHRINK_SPEED_MULT = 2.7     # 이속 +170% (2.7배)

# 싱글톤 인스턴스
strange_vial_instance = None

# ─── 이펙트 색상 팔레트 ───
# 거대화: 독/연금술 느낌 (에메랄드 그린 + 독성 노란)
_ENLARGE_COLORS = [
    (50, 220, 120),   # 에메랄드 그린
    (80, 255, 160),   # 밝은 민트
    (180, 255, 60),   # 라임 옐로
    (40, 180, 100),   # 다크 그린
]
# 축소화: 신비/수은 느낌 (보라 + 시안 + 은빛)
_SHRINK_COLORS = [
    (180, 80, 255),   # 바이올렛
    (100, 200, 255),  # 시안
    (220, 160, 255),  # 라벤더
    (140, 120, 255),  # 퍼플 블루
]


class StrangeVial:
    def __init__(self):
        self.active = False
        self.timer = 0
        self.initial_timer = 0
        self.effect_type = None  # "enlarge" 또는 "shrink"
        self.paddle_multiplier = 1.0
        self.speed_multiplier = 1.0
        # 원본 값 백업
        self._original_paddle_width = None
        self._original_player_speed = None
        # 이펙트 상태
        self._bubbles = []          # 거품/방울 파티클
        self._ripples = []          # 파문 링
        self._spirals = []          # 소용돌이 파티클
        self._drips = []            # 액체 방울 (패들에서 떨어짐)
        self._effect_tick = 0       # 이펙트 글로벌 틱

    def activate(self, game_state=None, current_stage=None):
        """기묘한 약병 효과 발동 - 50% 확률로 거대화 또는 축소"""
        frames = STRANGE_VIAL_DURATION_FRAMES

        # 카페인 스킬 보너스 (아카데미)
        try:
            import academy
            caffeine_multiplier = academy.get_caffeine_duration_multiplier()
            frames = int(frames * caffeine_multiplier)
        except (ImportError, AttributeError):
            pass

        # 런타임 스킬 보너스
        try:
            import pingfighter
            runtime_level = pingfighter.runtime_skill_levels.get("item_caffeine", 0)
            if runtime_level > 0:
                runtime_bonus = runtime_level * 0.25
                frames = int(frames * (1 + runtime_bonus))
        except (ImportError, AttributeError):
            pass

        self.active = True
        self.timer = frames
        self.initial_timer = frames
        self._effect_tick = 0
        self._bubbles.clear()
        self._ripples.clear()
        self._spirals.clear()
        self._drips.clear()

        # 50% 확률로 효과 결정
        if random.random() < 0.5:
            self.effect_type = "enlarge"
            self.paddle_multiplier = STRANGE_VIAL_ENLARGE_PADDLE_MULT
            self.speed_multiplier = STRANGE_VIAL_ENLARGE_SPEED_MULT
        else:
            self.effect_type = "shrink"
            self.paddle_multiplier = STRANGE_VIAL_SHRINK_PADDLE_MULT
            self.speed_multiplier = STRANGE_VIAL_SHRINK_SPEED_MULT

    def deactivate(self):
        """효과 해제 및 원본 값 복원"""
        self.active = False
        self.timer = 0
        self.initial_timer = 0
        self.effect_type = None
        self.paddle_multiplier = 1.0
        self.speed_multiplier = 1.0
        self._original_paddle_width = None
        self._original_player_speed = None
        self._bubbles.clear()
        self._ripples.clear()
        self._spirals.clear()
        self._drips.clear()

    def update(self, current_stage=None):
        """매 프레임 업데이트"""
        if not self.active:
            return
        self.timer -= 1
        if self.timer <= 0:
            self.deactivate()

    def get_remaining_ratio(self):
        """타이머 게이지 비율 (0.0 ~ 1.0)"""
        if not self.active or self.initial_timer <= 0:
            return 0.0
        return self.timer / self.initial_timer

    def get_paddle_multiplier(self):
        """현재 패들 크기 배율"""
        if not self.active:
            return 1.0
        return self.paddle_multiplier

    def get_speed_multiplier(self):
        """현재 이동속도 배율"""
        if not self.active:
            return 1.0
        return self.speed_multiplier

    def is_enlarge(self):
        """거대화 효과 여부"""
        return self.active and self.effect_type == "enlarge"

    def is_shrink(self):
        """축소 효과 여부"""
        return self.active and self.effect_type == "shrink"

    # ─── 비주얼 이펙트 시스템 ───

    def draw_effects(self, screen, paddle_rect):
        """기묘한 약병 이펙트 렌더링 (매 프레임 호출)"""
        if not self.active or paddle_rect is None:
            return

        self._effect_tick += 1
        colors = _ENLARGE_COLORS if self.effect_type == "enlarge" else _SHRINK_COLORS

        # 1) 파티클 생성
        self._spawn_particles(paddle_rect, colors)
        # 2) 파티클 업데이트 & 렌더
        self._update_and_draw_bubbles(screen, colors)
        self._update_and_draw_ripples(screen, colors)
        self._update_and_draw_spirals(screen, paddle_rect, colors)
        self._update_and_draw_drips(screen, colors)
        # 3) 패들 오버레이 글로우
        self._draw_paddle_glow(screen, paddle_rect, colors)

    def _spawn_particles(self, pr, colors):
        """매 프레임 파티클 스폰"""
        cx, cy = pr.centerx, pr.centery
        hw = pr.width // 2

        if self.effect_type == "enlarge":
            # 거대화: 거품(bubble) 올라감 + 파문(ripple) 확장
            if random.random() < 0.45:
                self._bubbles.append({
                    'x': cx + random.randint(-hw, hw),
                    'y': cy + random.randint(-4, 4),
                    'vx': random.uniform(-0.3, 0.3),
                    'vy': random.uniform(-2.5, -1.0),
                    'r': random.uniform(2.5, 6.0),
                    'life': random.randint(30, 55),
                    'max_life': 55,
                    'wobble_phase': random.uniform(0, math.pi * 2),
                })
            if self._effect_tick % 18 == 0:
                self._ripples.append({
                    'x': cx + random.randint(-hw // 2, hw // 2),
                    'y': cy,
                    'r': 4.0,
                    'max_r': random.uniform(30, 55),
                    'life': 0,
                    'max_life': 35,
                })
        else:
            # 축소화: 소용돌이 파티클 수렴 + 스피드 잔상 드립
            if random.random() < 0.50:
                angle = random.uniform(0, math.pi * 2)
                dist = random.uniform(35, 70)
                self._spirals.append({
                    'angle': angle,
                    'dist': dist,
                    'target_dist': random.uniform(3, 8),
                    'y_offset': random.uniform(-10, 10),
                    'r': random.uniform(2.0, 4.5),
                    'life': random.randint(25, 45),
                    'max_life': 45,
                    'speed': random.uniform(0.08, 0.15),
                })
            if random.random() < 0.25:
                self._drips.append({
                    'x': cx + random.randint(-hw, hw),
                    'y': cy,
                    'vy': random.uniform(1.5, 3.5),
                    'length': random.randint(8, 18),
                    'life': random.randint(15, 30),
                    'max_life': 30,
                })

    def _update_and_draw_bubbles(self, screen, colors):
        """거품 파티클 (거대화) - 위로 올라가며 흔들리는 방울"""
        for b in self._bubbles[:]:
            b['life'] -= 1
            if b['life'] <= 0:
                self._bubbles.remove(b)
                continue

            # 움직임: 위로 + 좌우 wobble
            b['wobble_phase'] += 0.15
            b['x'] += b['vx'] + math.sin(b['wobble_phase']) * 0.8
            b['y'] += b['vy']
            b['vy'] *= 0.99  # 약간 감속
            b['r'] *= 0.995  # 약간 줄어듦

            alpha_ratio = b['life'] / b['max_life']
            alpha = int(180 * alpha_ratio)
            color = random.choice(colors) if random.random() < 0.02 else colors[0]
            r = max(1, int(b['r']))
            bx, by = int(b['x']), int(b['y'])

            # 외곽 글로우
            glow_r = r + 4
            glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*color, int(alpha * 0.25)), (glow_r, glow_r), glow_r)
            screen.blit(glow_surf, (bx - glow_r, by - glow_r))

            # 방울 본체 (반투명 원 + 하이라이트)
            bubble_surf = pygame.Surface((r * 2 + 2, r * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(bubble_surf, (*color, alpha), (r + 1, r + 1), r)
            # 하이라이트 점
            if r > 2:
                hl_r = max(1, r // 3)
                pygame.draw.circle(bubble_surf, (255, 255, 255, int(alpha * 0.6)),
                                   (r + 1 - r // 3, r + 1 - r // 3), hl_r)
            screen.blit(bubble_surf, (bx - r - 1, by - r - 1))

    def _update_and_draw_ripples(self, screen, colors):
        """파문 링 (거대화) - 패들에서 확장되는 동심원"""
        for rp in self._ripples[:]:
            rp['life'] += 1
            if rp['life'] >= rp['max_life']:
                self._ripples.remove(rp)
                continue

            progress = rp['life'] / rp['max_life']
            rp['r'] = 4.0 + (rp['max_r'] - 4.0) * progress
            alpha = int(120 * (1.0 - progress))
            r = max(1, int(rp['r']))
            thickness = max(1, int(2.5 * (1.0 - progress)))
            color = colors[1]

            ring_size = r * 2 + 4
            ring_surf = pygame.Surface((ring_size, ring_size), pygame.SRCALPHA)
            pygame.draw.circle(ring_surf, (*color, alpha),
                               (ring_size // 2, ring_size // 2), r, thickness)
            screen.blit(ring_surf, (int(rp['x']) - ring_size // 2,
                                    int(rp['y']) - ring_size // 2))

    def _update_and_draw_spirals(self, screen, paddle_rect, colors):
        """소용돌이 파티클 (축소화) - 주변에서 패들로 수렴하며 회전"""
        cx, cy = paddle_rect.centerx, paddle_rect.centery

        for sp in self._spirals[:]:
            sp['life'] -= 1
            if sp['life'] <= 0:
                self._spirals.remove(sp)
                continue

            # 회전하며 수렴
            sp['angle'] += sp['speed']
            sp['dist'] += (sp['target_dist'] - sp['dist']) * 0.06

            alpha_ratio = sp['life'] / sp['max_life']
            px = cx + math.cos(sp['angle']) * sp['dist']
            py = cy + math.sin(sp['angle']) * sp['dist'] * 0.45 + sp['y_offset']
            alpha = int(200 * alpha_ratio)
            r = max(1, int(sp['r'] * alpha_ratio))
            color = colors[int(self._effect_tick * 0.05 + sp['angle']) % len(colors)]

            # 꼬리 트레일 (이전 위치)
            trail_angle = sp['angle'] - sp['speed'] * 3
            trail_dist = sp['dist'] + 5
            tx = cx + math.cos(trail_angle) * trail_dist
            ty = cy + math.sin(trail_angle) * trail_dist * 0.45 + sp['y_offset']
            trail_alpha = int(alpha * 0.3)
            if trail_alpha > 0:
                trail_surf = pygame.Surface((max(1, r * 2), max(1, r * 2)), pygame.SRCALPHA)
                pygame.draw.circle(trail_surf, (*color, trail_alpha),
                                   (max(1, r), max(1, r)), max(1, r))
                screen.blit(trail_surf, (int(tx) - r, int(ty) - r))

            # 본체
            glow_r = r + 3
            glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*color, int(alpha * 0.3)),
                               (glow_r, glow_r), glow_r)
            screen.blit(glow_surf, (int(px) - glow_r, int(py) - glow_r))

            dot_surf = pygame.Surface((r * 2 + 2, r * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(dot_surf, (*color, alpha), (r + 1, r + 1), r)
            screen.blit(dot_surf, (int(px) - r - 1, int(py) - r - 1))

    def _update_and_draw_drips(self, screen, colors):
        """액체 잔상 (축소화) - 패들에서 아래로 떨어지는 빠른 선"""
        for d in self._drips[:]:
            d['life'] -= 1
            if d['life'] <= 0:
                self._drips.remove(d)
                continue

            d['y'] += d['vy']
            d['vy'] += 0.1  # 중력

            alpha_ratio = d['life'] / d['max_life']
            alpha = int(140 * alpha_ratio)
            color = colors[2]
            x, y = int(d['x']), int(d['y'])
            length = int(d['length'] * alpha_ratio)

            if length > 0 and alpha > 0:
                line_surf = pygame.Surface((3, length + 2), pygame.SRCALPHA)
                pygame.draw.line(line_surf, (*color, alpha), (1, 0), (1, length), 2)
                screen.blit(line_surf, (x - 1, y))

    def _draw_paddle_glow(self, screen, pr, colors):
        """패들 주변 은은한 맥동 글로우 오버레이"""
        pulse = 0.5 + 0.5 * math.sin(self._effect_tick * 0.08)
        alpha = int(35 + 25 * pulse)
        color = colors[0] if self.effect_type == "enlarge" else colors[1]

        # 패들보다 살짝 큰 글로우
        gw = pr.width + 16
        gh = pr.height + 12
        glow_surf = pygame.Surface((gw, gh), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_surf, (*color, alpha), (0, 0, gw, gh))
        screen.blit(glow_surf, (pr.centerx - gw // 2, pr.centery - gh // 2))

        # 두 번째 레이어 (더 큰, 더 희미한)
        alpha2 = int(15 + 10 * pulse)
        gw2 = pr.width + 36
        gh2 = pr.height + 24
        glow_surf2 = pygame.Surface((gw2, gh2), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_surf2, (*color, alpha2), (0, 0, gw2, gh2))
        screen.blit(glow_surf2, (pr.centerx - gw2 // 2, pr.centery - gh2 // 2))


def get_strange_vial_instance():
    """싱글톤 인스턴스 반환"""
    global strange_vial_instance
    if strange_vial_instance is None:
        strange_vial_instance = StrangeVial()
    return strange_vial_instance


def activate_strange_vial(game_state=None, current_stage=None):
    """기묘한 약병 효과 활성화"""
    vial = get_strange_vial_instance()
    vial.activate(game_state, current_stage)
    return True


def deactivate_strange_vial():
    """기묘한 약병 효과 비활성화"""
    vial = get_strange_vial_instance()
    vial.deactivate()


def update_strange_vial(current_stage=None):
    """기묘한 약병 업데이트"""
    vial = get_strange_vial_instance()
    vial.update(current_stage)


def draw_strange_vial_effects(screen, paddle_rect):
    """기묘한 약병 이펙트 그리기 (pingfighter.py에서 호출)"""
    vial = get_strange_vial_instance()
    vial.draw_effects(screen, paddle_rect)
