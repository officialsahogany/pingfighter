# -*- coding: utf-8 -*-
"""
Stage 30 - 고대 투기장 (Ancient Colosseum Arena)
로마 콜로세움 스타일의 투기장 배경 - 심플하고 멋스러운 디자인
"""
import pygame
import math
import random
import threading
import os
import sys

def resource_path(relative_path):
    """PyInstaller 번들과 일반 실행 모두에서 작동하는 리소스 경로 반환"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    return os.path.join(base_path, relative_path)

# ============================================================
# Surface 캐시 시스템
# ============================================================
_stage30_surface_cache = {}
_stage30_cache_lock = threading.Lock()

def _get_cached_surface(width: int, height: int) -> pygame.Surface:
    """캐시된 투명 Surface 반환"""
    key = (width, height)
    with _stage30_cache_lock:
        if key not in _stage30_surface_cache:
            if len(_stage30_surface_cache) > 50:
                _stage30_surface_cache.clear()
            _stage30_surface_cache[key] = pygame.Surface((width, height), pygame.SRCALPHA)
        surface = _stage30_surface_cache[key]
        surface.fill((0, 0, 0, 0))
        return surface


class AnimatedBackgroundStage30:
    """고대 투기장 배경 - 로마 콜로세움 스타일"""

    # 게임 영역 상수 (760x750 전체 화면 기준)
    GAME_AREA_X = 80       # 게임 영역 시작 X
    GAME_AREA_WIDTH = 600  # 게임 영역 너비
    GAME_AREA_END_X = 680  # 게임 영역 끝 X (80 + 600)

    def __init__(self, width=760, height=750):
        self.width = width
        self.height = height
        self.time = 0

        # 배경 레이어 서피스
        self.floor_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        self.arena_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        self.effect_surface = pygame.Surface((width, height), pygame.SRCALPHA)

        # 관중 함성 효과
        self.crowd_noise_level = 0.5
        self.crowd_wave_timer = 0

        # 색상 팔레트 - 로마 콜로세움 테마 (어두운 톤)
        self.colors = {
            'sand': (155, 130, 95),           # 모래 바닥 (어둡게)
            'sand_dark': (125, 105, 75),      # 어두운 모래
            'sand_light': (175, 150, 115),    # 밝은 모래
            'stone': (140, 130, 115),         # 석조
            'stone_dark': (100, 90, 80),      # 어두운 석조
            'stone_light': (170, 160, 145),   # 밝은 석조
            'gold': (212, 175, 85),           # 금색 장식
            'gold_light': (232, 200, 120),    # 밝은 금색
            'line': (230, 210, 170),          # 라인 색상 (밝은 베이지)
            'line_glow': (255, 235, 190),     # 라인 글로우
        }

        # 횃불 데이터
        self.torches = self._init_torches()

        # 먼지 파티클
        self.dust_particles = []
        for _ in range(20):
            self.dust_particles.append(self._create_dust_particle())

        # 관중 실루엣 데이터
        self.spectators = self._init_spectators()

        # 제우스 석상 번개 위치 (애니메이션용)
        self.zeus_bolt_tip = None

        # ========================================
        # 신의심판 (God's Judgment) 이벤트 시스템
        # ========================================
        self.JUDGMENT_IDLE = 0
        self.JUDGMENT_MERGE = 1       # 2초: 동상 합체 + 4배 성장
        self.JUDGMENT_ARM_RAISE = 2   # 2초: 팔 올리기 + 발 흔들기
        self.JUDGMENT_SLAM = 3        # 0.5초: 내려치기
        self.JUDGMENT_EARTHQUAKE = 4  # 4초: 지진 효과
        self.JUDGMENT_RETURN = 5      # 3초: 원래 크기로 복귀

        self.judgment_phase = self.JUDGMENT_IDLE
        self.judgment_timer = 0.0
        self.judgment_scale = 1.0
        self.judgment_target_scale = 4.0
        self.judgment_left_arm_progress = 0.0   # 0=아래, 1=위
        self.judgment_right_arm_progress = 0.0  # 0=번개들기, 1=주먹위
        self.judgment_slam_progress = 0.0       # 0=위, 1=내려침
        self.judgment_feet_swing = 0.0          # 발 흔들림 각도 (라디안)
        self.judgment_shake_intensity = 0.0
        self.judgment_flash_alpha = 0
        self.judgment_cooldown = random.uniform(50.0, 60.0)  # 첫 발동 쿨타임
        self.judgment_enabled = False  # pingfighter.py에서 True로 설정
        self.judgment_merge_particles = []
        self.judgment_slam_debris = []
        self.judgment_dust_rain = []
        self.judgment_rise_debris = []       # 상승 시 떨어지는 흙/돌
        self.judgment_rise_offset = 0.0      # 석상 상승 오프셋 (양수=아래에 묻힘)
        self.judgment_quake_sound_playing = False

        # 페이즈 지속시간 (초)
        self.MERGE_DURATION = 2.0
        self.ARM_RAISE_DURATION = 2.0
        self.SLAM_DURATION = 0.5
        self.EARTHQUAKE_DURATION = 5.2
        self.RETURN_DURATION = 3.0

        # 프리렌더
        self._prerender_floor()
        self._prerender_arena()

    def _init_torches(self):
        """횃불 위치 초기화 - 게임 영역 내 양쪽 가장자리에 대칭 배치"""
        torches = []
        # 게임 영역(80~679) 내에서 좌우 대칭 배치
        # 왼쪽: 80+25=105, 오른쪽: 680-25=655
        left_x = self.GAME_AREA_X + 25
        right_x = self.GAME_AREA_END_X - 25
        positions = [
            (left_x, 150), (left_x, 375), (left_x, 600),   # 왼쪽
            (right_x, 150), (right_x, 375), (right_x, 600),  # 오른쪽
        ]
        for x, y in positions:
            torches.append({
                'x': x, 'y': y,
                'flame_height': random.uniform(18, 28),
                'flicker_offset': random.uniform(0, math.pi * 2),
                'intensity': random.uniform(0.8, 1.0)
            })
        return torches

    def _init_spectators(self):
        """관중 실루엣 초기화 - 비활성화"""
        return []  # 관중 실루엣 제거

    def _create_dust_particle(self):
        """먼지 파티클 생성 - 게임 영역 내에서만"""
        return {
            'x': random.randint(self.GAME_AREA_X + 30, self.GAME_AREA_END_X - 30),
            'y': random.randint(100, self.height - 100),
            'vx': random.uniform(-0.2, 0.2),
            'vy': random.uniform(-0.1, 0.1),
            'size': random.uniform(1, 2.5),
            'alpha': random.randint(20, 50),
            'life': random.randint(150, 400)
        }

    def _prerender_floor(self):
        """바닥 프리렌더 - 모래 아레나"""
        # 메인 모래 바닥
        sand = self.colors['sand']

        # 전체를 모래 색상으로 채움 (필러가 위에 그려지므로 상관없음)
        self.floor_surface.fill(sand)

        # 모래 텍스처 - 미세한 노이즈
        for _ in range(500):
            x = random.randint(5, self.width - 5)
            y = random.randint(5, self.height - 5)
            shade = random.randint(-15, 15)
            color = (
                max(0, min(255, sand[0] + shade)),
                max(0, min(255, sand[1] + shade)),
                max(0, min(255, sand[2] + shade))
            )
            size = random.randint(1, 2)
            pygame.draw.circle(self.floor_surface, color, (x, y), size)

    def _prerender_arena(self):
        """경기장 라인 프리렌더 - 중앙선과 중앙원 (게임 영역 기준)"""
        self.arena_surface.fill((0, 0, 0, 0))

        # 게임 영역 중앙 (80 + 300 = 380)
        center_x = self.GAME_AREA_X + self.GAME_AREA_WIDTH // 2
        center_y = self.height // 2

        line_color = self.colors['line']
        gold = self.colors['gold']

        # ===== 중앙선 =====
        # 메인 중앙선 (굵은 선) - 게임 영역 내에서만
        pygame.draw.line(self.arena_surface, line_color,
                        (self.GAME_AREA_X + 10, center_y), (self.GAME_AREA_END_X - 10, center_y), 3)

        # 중앙선 장식 (얇은 이중선)
        pygame.draw.line(self.arena_surface, gold,
                        (self.GAME_AREA_X + 10, center_y - 6), (self.GAME_AREA_END_X - 10, center_y - 6), 1)
        pygame.draw.line(self.arena_surface, gold,
                        (self.GAME_AREA_X + 10, center_y + 6), (self.GAME_AREA_END_X - 10, center_y + 6), 1)

        # ===== 중앙원 =====
        # 큰 원 (외곽)
        pygame.draw.circle(self.arena_surface, line_color, (center_x, center_y), 85, 3)

        # 작은 원 (내부)
        pygame.draw.circle(self.arena_surface, gold, (center_x, center_y), 50, 2)

        # ===== 코너 장식 (로마 스타일) - 게임 영역 기준 =====
        corner_size = 25
        corners = [
            (self.GAME_AREA_X + 15, 70),                    # 좌상
            (self.GAME_AREA_END_X - 15, 70),                # 우상
            (self.GAME_AREA_X + 15, self.height - 70),      # 좌하
            (self.GAME_AREA_END_X - 15, self.height - 70)   # 우하
        ]

        for cx, cy in corners:
            # L자 장식
            pygame.draw.line(self.arena_surface, gold,
                           (cx - corner_size, cy), (cx, cy), 2)
            pygame.draw.line(self.arena_surface, gold,
                           (cx, cy - corner_size), (cx, cy), 2)

        # 코너 반전 (우상, 우하)
        # 우상
        pygame.draw.line(self.arena_surface, gold,
                        (self.GAME_AREA_END_X - 15, 70), (self.GAME_AREA_END_X - 15 + corner_size, 70), 2)
        # 우하
        pygame.draw.line(self.arena_surface, gold,
                        (self.GAME_AREA_END_X - 15, self.height - 70),
                        (self.GAME_AREA_END_X - 15 + corner_size, self.height - 70), 2)

        # (평소 석상 없음 - 신의심판 시에만 동적으로 등장)

    def _draw_zeus_statue(self, surface, cx, cy):
        """고대 제우스 석상 - 상반신 비석 스타일 (하반신은 땅속에 묻힘)"""
        marble = (185, 175, 160)
        marble_mid = (160, 150, 135)
        marble_dark = (130, 120, 108)
        marble_shadow = (105, 95, 85)
        gold = self.colors['gold']
        gold_light = self.colors['gold_light']

        # ── 돌 받침 (땅에 묻힌 느낌의 거친 석조) ──
        base_pts = [(cx - 12, cy + 6), (cx + 12, cy + 6),
                    (cx + 10, cy - 2), (cx - 10, cy - 2)]
        pygame.draw.polygon(surface, marble_shadow, base_pts)
        pygame.draw.line(surface, marble_dark, (cx - 12, cy + 6), (cx + 12, cy + 6), 1)
        pygame.draw.line(surface, gold, (cx - 10, cy + 1), (cx + 10, cy + 1), 1)

        # ── 상체 ──
        torso_pts = [(cx - 7, cy - 2), (cx + 7, cy - 2),
                     (cx + 10, cy - 18), (cx - 10, cy - 18)]
        pygame.draw.polygon(surface, marble, torso_pts)
        pygame.draw.polygon(surface, marble_dark, torso_pts, 1)
        pygame.draw.line(surface, marble_dark, (cx - 9, cy - 17), (cx + 5, cy - 4), 2)

        # ── 왼팔 (아래) ──
        pygame.draw.line(surface, marble, (cx - 10, cy - 16), (cx - 14, cy - 6), 3)
        pygame.draw.line(surface, marble_mid, (cx - 14, cy - 6), (cx - 13, cy - 2), 2)

        # ── 오른팔 (위로 번개) ──
        pygame.draw.line(surface, marble, (cx + 10, cy - 16), (cx + 13, cy - 28), 3)
        pygame.draw.circle(surface, marble_mid, (cx + 13, cy - 29), 2)

        # ── 머리 ──
        head_y = cy - 23
        pygame.draw.circle(surface, marble, (cx, head_y), 6)
        pygame.draw.circle(surface, marble_dark, (cx, head_y), 6, 1)
        beard_pts = [(cx - 3, head_y + 4), (cx + 3, head_y + 4),
                     (cx + 1, head_y + 8), (cx - 1, head_y + 8)]
        pygame.draw.polygon(surface, marble_mid, beard_pts)
        pygame.draw.arc(surface, marble_dark,
                        (cx - 7, head_y - 7, 14, 10), 0.3, math.pi - 0.3, 2)

        # ── 월계관 ──
        wreath_color = (155, 150, 95)
        wreath_light = (175, 170, 110)
        for angle_deg in range(-70, 71, 25):
            a = math.radians(angle_deg - 90)
            lx = cx + int(7 * math.cos(a))
            ly = head_y + int(7 * math.sin(a))
            pygame.draw.circle(surface, wreath_color, (lx, ly), 1)
            if angle_deg % 50 == 0:
                pygame.draw.circle(surface, wreath_light, (lx, ly), 1)

        # ── 번개 ──
        bolt_x = cx + 13
        bolt_y = cy - 31
        bolt_segs = [
            (bolt_x, bolt_y), (bolt_x - 3, bolt_y - 5),
            (bolt_x + 2, bolt_y - 7), (bolt_x - 2, bolt_y - 11),
            (bolt_x + 1, bolt_y - 14), (bolt_x - 1, bolt_y - 18),
        ]
        for i in range(len(bolt_segs) - 1):
            pygame.draw.line(surface, gold, bolt_segs[i], bolt_segs[i + 1], 2)
        tip = bolt_segs[-1]
        pygame.draw.line(surface, gold_light, (tip[0] - 3, tip[1]), (tip[0] + 3, tip[1]), 1)
        pygame.draw.line(surface, gold_light, (tip[0], tip[1] - 3), (tip[0], tip[1] + 2), 1)

        self.zeus_bolt_tip = (bolt_x - 1, bolt_y - 12)

    def update(self, dt, ball_x=None, ball_y=None):
        """업데이트"""
        self.time += dt

        # 관중 웨이브 타이머
        self.crowd_wave_timer += dt * 2

        # 횃불 업데이트
        for torch in self.torches:
            torch['intensity'] = 0.7 + 0.3 * math.sin(self.time * 8 + torch['flicker_offset'])
            torch['flame_height'] = 20 + 8 * math.sin(self.time * 6 + torch['flicker_offset'])

        # 먼지 파티클 업데이트
        for i, particle in enumerate(self.dust_particles):
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1

            # 범위 벗어나거나 수명 끝나면 재생성 (게임 영역 기준)
            if (particle['life'] <= 0 or
                particle['x'] < self.GAME_AREA_X + 20 or particle['x'] > self.GAME_AREA_END_X - 20 or
                particle['y'] < 70 or particle['y'] > self.height - 70):
                self.dust_particles[i] = self._create_dust_particle()

        # 신의심판 이벤트 업데이트
        self._update_gods_judgment(dt)

    # ========================================
    # 신의심판 이벤트 메서드
    # ========================================
    def trigger_gods_judgment(self):
        """신의심판 이벤트 시작"""
        if self.judgment_phase != self.JUDGMENT_IDLE:
            return False
        self.judgment_phase = self.JUDGMENT_MERGE
        self.judgment_timer = 0.0
        self.judgment_scale = 1.0
        self.judgment_left_arm_progress = 0.0
        self.judgment_right_arm_progress = 0.0
        self.judgment_slam_progress = 0.0
        self.judgment_feet_swing = 0.0
        self.judgment_flash_alpha = 0
        self.judgment_merge_particles = []
        self.judgment_slam_debris = []
        self.judgment_dust_rain = []
        self.judgment_rise_debris = []
        self.judgment_rise_offset = 40.0  # 초기 매몰 깊이 (40px 아래)
        self.judgment_quake_sound_playing = False
        # 합체 파티클 (심플한 대리석 먼지)
        cx = self.GAME_AREA_X + self.GAME_AREA_WIDTH // 2
        cy = self.height // 2
        marble_colors = [(185, 175, 160), (160, 150, 135), (130, 120, 108)]
        for i in range(18):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(80, 220)
            self.judgment_merge_particles.append({
                'x': cx + math.cos(angle) * dist,
                'y': cy + math.sin(angle) * dist,
                'tx': cx + random.uniform(-12, 12),
                'ty': cy + random.uniform(-10, 5),
                'alpha': random.randint(120, 200),
                'speed': random.uniform(0.8, 1.5),
                'size': random.randint(1, 3),
                'color': random.choice(marble_colors),
            })
        return True

    def _update_gods_judgment(self, dt):
        """신의심판 이벤트 상태 업데이트"""
        if self.judgment_phase == self.JUDGMENT_IDLE:
            if self.judgment_enabled:
                self.judgment_cooldown -= dt
                if self.judgment_cooldown <= 0:
                    self.trigger_gods_judgment()
            return

        self.judgment_timer += dt
        cx = self.GAME_AREA_X + self.GAME_AREA_WIDTH // 2
        cy = self.height // 2

        if self.judgment_phase == self.JUDGMENT_MERGE:
            # 2초간 1x → 4x 성장 + 상승 (ease-out)
            progress = min(1.0, self.judgment_timer / self.MERGE_DURATION)
            ease = 1.0 - (1.0 - progress) ** 3  # ease-out cubic
            self.judgment_scale = 1.0 + (self.judgment_target_scale - 1.0) * ease
            # 석상 상승 (40→0, 땅에서 올라옴)
            self.judgment_rise_offset = 40.0 * (1.0 - ease)
            # 합체 파티클 이동 (중심으로 수렴)
            for p in self.judgment_merge_particles:
                lerp_speed = dt * 2.2 * p['speed']
                p['x'] += (p['tx'] - p['x']) * lerp_speed
                p['y'] += (p['ty'] - p['y']) * lerp_speed
                p['alpha'] = max(0, p['alpha'] - dt * 30)
            # 상승 중 떨어지는 흙/돌 파편
            if self.judgment_rise_offset > 2:
                ground_y = cy + 10
                s = self.judgment_scale
                for _ in range(2):
                    self.judgment_rise_debris.append({
                        'x': cx + random.uniform(-12 * s, 12 * s),
                        'y': ground_y + random.uniform(-4, 2),
                        'vx': random.uniform(-1.5, 1.5),
                        'vy': random.uniform(0.5, 3),
                        'size': random.randint(1, 3),
                        'life': random.uniform(0.5, 1.2),
                        'color': random.choice([
                            (155, 130, 95), (125, 105, 75),
                            (130, 120, 108), (160, 150, 135)
                        ]),
                    })
            # 상승 파편 업데이트 (중력)
            for d in self.judgment_rise_debris:
                d['x'] += d['vx'] * dt * 60
                d['y'] += d['vy'] * dt * 60
                d['vy'] += 4 * dt  # 중력
                d['life'] -= dt
            self.judgment_rise_debris = [d for d in self.judgment_rise_debris if d['life'] > 0]
            if progress >= 1.0:
                self.judgment_phase = self.JUDGMENT_ARM_RAISE
                self.judgment_timer = 0.0
                self.judgment_merge_particles.clear()
                self.judgment_rise_offset = 0.0
                self.judgment_rise_debris.clear()

        elif self.judgment_phase == self.JUDGMENT_ARM_RAISE:
            # 2초간 팔 올리기 + 발 흔들기
            progress = min(1.0, self.judgment_timer / self.ARM_RAISE_DURATION)
            ease = 1.0 - (1.0 - progress) ** 2  # ease-out quad
            self.judgment_left_arm_progress = ease
            self.judgment_right_arm_progress = ease
            # 발 흔들림 (사인파)
            self.judgment_feet_swing = math.sin(self.judgment_timer * 5.0) * 0.3 * ease
            if progress >= 1.0:
                self.judgment_phase = self.JUDGMENT_SLAM
                self.judgment_timer = 0.0

        elif self.judgment_phase == self.JUDGMENT_SLAM:
            # 0.5초간 내려치기
            progress = min(1.0, self.judgment_timer / self.SLAM_DURATION)
            ease = progress ** 2  # ease-in (빠르게 내려침)
            self.judgment_slam_progress = ease
            self.judgment_left_arm_progress = 1.0 - ease
            self.judgment_right_arm_progress = 1.0 - ease
            self.judgment_feet_swing = 0
            # 충격 플래시 (내려치는 순간)
            if progress > 0.8:
                self.judgment_flash_alpha = int(180 * ((progress - 0.8) / 0.2))
            if progress >= 1.0:
                self.judgment_phase = self.JUDGMENT_EARTHQUAKE
                self.judgment_timer = 0.0
                self.judgment_flash_alpha = 180
                self.judgment_shake_intensity = 1.0
                # 슬램 파편 생성
                for i in range(20):
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(2, 8)
                    self.judgment_slam_debris.append({
                        'x': float(cx), 'y': float(cy + 40 * self.judgment_scale),
                        'vx': math.cos(angle) * speed,
                        'vy': math.sin(angle) * speed - random.uniform(2, 5),
                        'size': random.uniform(3, 8),
                        'life': random.uniform(0.5, 1.5),
                        'color': random.choice([
                            (185, 175, 160), (160, 150, 135),
                            (130, 120, 108), (212, 175, 85)
                        ])
                    })

        elif self.judgment_phase == self.JUDGMENT_EARTHQUAKE:
            # 4초간 지진
            progress = min(1.0, self.judgment_timer / self.EARTHQUAKE_DURATION)
            # 플래시 빠르게 감소
            self.judgment_flash_alpha = max(0, int(180 * (1.0 - progress * 8)))
            # 흔들림 강도 (시작 강하고 점차 감소, 마지막 1초에 급감)
            if progress < 0.75:
                self.judgment_shake_intensity = 1.0 - progress * 0.3
            else:
                fade = (progress - 0.75) / 0.25
                self.judgment_shake_intensity = 0.775 * (1.0 - fade)
            # 팔은 내려친 상태 유지
            self.judgment_slam_progress = 1.0
            self.judgment_left_arm_progress = 0.0
            self.judgment_right_arm_progress = 0.0
            # 먼지 비 생성
            if random.random() < 0.4:
                self.judgment_dust_rain.append({
                    'x': random.uniform(self.GAME_AREA_X + 10, self.GAME_AREA_END_X - 10),
                    'y': random.uniform(0, 50),
                    'vy': random.uniform(2, 5),
                    'size': random.uniform(1, 3),
                    'alpha': random.randint(60, 120),
                    'life': random.uniform(1.0, 2.5),
                })
            # 슬램 파편 업데이트
            for d in self.judgment_slam_debris:
                d['x'] += d['vx'] * dt * 60
                d['y'] += d['vy'] * dt * 60
                d['vy'] += 5 * dt  # 중력
                d['life'] -= dt
            self.judgment_slam_debris = [d for d in self.judgment_slam_debris if d['life'] > 0]
            # 먼지 비 업데이트
            for d in self.judgment_dust_rain:
                d['y'] += d['vy'] * dt * 60
                d['life'] -= dt
            self.judgment_dust_rain = [d for d in self.judgment_dust_rain if d['life'] > 0 and d['y'] < self.height]
            if progress >= 1.0:
                self.judgment_phase = self.JUDGMENT_RETURN
                self.judgment_timer = 0.0
                self.judgment_shake_intensity = 0.0
                self.judgment_slam_debris.clear()
                self.judgment_dust_rain.clear()

        elif self.judgment_phase == self.JUDGMENT_RETURN:
            # 3초간 원래 크기로 복귀
            progress = min(1.0, self.judgment_timer / self.RETURN_DURATION)
            ease = progress ** 2  # ease-in
            self.judgment_scale = self.judgment_target_scale - (self.judgment_target_scale - 1.0) * ease
            # 팔 원래 위치로
            self.judgment_slam_progress = 1.0 - ease
            self.judgment_left_arm_progress = 0.0
            self.judgment_right_arm_progress = 0.0
            if progress >= 1.0:
                self.judgment_phase = self.JUDGMENT_IDLE
                self.judgment_timer = 0.0
                self.judgment_scale = 1.0
                self.judgment_slam_progress = 0.0
                self.judgment_cooldown = random.uniform(50.0, 60.0)

    def get_judgment_shake_offset(self):
        """신의심판 화면 흔들림 오프셋 반환 (정글지진의 1.5배 강도)"""
        if self.judgment_phase != self.JUDGMENT_EARTHQUAKE and self.judgment_phase != self.JUDGMENT_SLAM:
            return (0, 0)
        intensity = 16 * self.judgment_shake_intensity  # 12px → 16px (+30%)
        ox = (random.random() - 0.5) * intensity * 2
        oy = (random.random() - 0.5) * intensity * 2
        return (int(ox), int(oy))

    def is_judgment_earthquake_active(self):
        """신의심판 지진 효과 활성화 여부"""
        return self.judgment_phase == self.JUDGMENT_EARTHQUAKE

    def is_judgment_active(self):
        """신의심판 이벤트 진행 중 여부"""
        return self.judgment_phase != self.JUDGMENT_IDLE

    def is_judgment_slam_impact(self):
        """슬램이 바닥에 충돌하는 순간인지 (사운드 타이밍용)"""
        return (self.judgment_phase == self.JUDGMENT_SLAM and
                self.judgment_timer / self.SLAM_DURATION > 0.9)

    def get_judgment_phase_name(self):
        """현재 페이즈 이름 (디버그용)"""
        names = {0: "IDLE", 1: "MERGE", 2: "ARM_RAISE", 3: "SLAM", 4: "EARTHQUAKE", 5: "RETURN"}
        return names.get(self.judgment_phase, "UNKNOWN")

    def _draw_judgment_overlay(self, screen, offset_x=0, offset_y=0):
        """신의심판 이벤트 비주얼 오버레이 (깔끔한 스타일)"""
        if self.judgment_phase == self.JUDGMENT_IDLE:
            return

        cx = self.GAME_AREA_X + self.GAME_AREA_WIDTH // 2 + offset_x
        cy = self.height // 2 + offset_y
        s = self.judgment_scale

        # ── 합체 파티클 (심플 대리석 먼지) ──
        for p in self.judgment_merge_particles:
            px, py = int(p['x']) + offset_x, int(p['y']) + offset_y
            alpha = max(0, min(255, int(p['alpha'])))
            if alpha <= 5:
                continue
            col = p['color']
            sz = p['size']
            pygame.draw.circle(screen, col, (px, py), sz)

        # ── 동적 제우스 석상 그리기 (상승 중 지면 클리핑) ──
        rise_y = int(self.judgment_rise_offset)
        # 흔들림 (상승 중에만)
        rise_shake_x = 0
        if rise_y > 2:
            wobble = rise_y / 40.0  # 깊을수록 강하게 흔들림
            rise_shake_x = int(math.sin(self.time * 15) * 3 * wobble * s)

        if rise_y > 2:
            # 지면 레벨 아래 클리핑 (석상 하반신 숨김)
            ground_y = cy + 10
            old_clip = screen.get_clip()
            screen.set_clip(pygame.Rect(0, 0, screen.get_width(), ground_y))
            self._draw_judgment_statue_scaled(screen, cx + rise_shake_x, cy + rise_y, s)
            screen.set_clip(old_clip)
        else:
            self._draw_judgment_statue_scaled(screen, cx, cy, s)

        # ── 상승 파편 (떨어지는 흙/돌) ──
        for d in self.judgment_rise_debris:
            dx, dy = int(d['x']) + offset_x, int(d['y']) + offset_y
            ds = max(1, int(d['size'] * min(1, d['life'] * 2)))
            pygame.draw.circle(screen, d['color'], (dx, dy), ds)

        # ── 슬램 파편 (심플 원형) ──
        for d in self.judgment_slam_debris:
            dx, dy = int(d['x']) + offset_x, int(d['y']) + offset_y
            ds = max(1, int(d['size'] * min(1, d['life'])))
            col = d['color']
            pygame.draw.circle(screen, col, (dx, dy), ds)

        # ── 먼지 비 (작은 점) ──
        for d in self.judgment_dust_rain:
            dx, dy = int(d['x']) + offset_x, int(d['y']) + offset_y
            a = max(0, min(255, int(d['alpha'] * min(1, d['life']))))
            if a > 10:
                sz = max(1, int(d['size']))
                pygame.draw.circle(screen, (180, 165, 140), (dx, dy), sz)

        # ── 충격 플래시 (단순 전체 플래시) ──
        if self.judgment_flash_alpha > 0:
            fa = min(180, self.judgment_flash_alpha)
            flash_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            flash_surf.fill((255, 245, 220, fa))
            screen.blit(flash_surf, (offset_x, offset_y), special_flags=pygame.BLEND_ADD)

    def _draw_judgment_statue_scaled(self, screen, cx, cy, scale):
        """신의심판 동안 스케일된 제우스 석상 (정적 석상과 동일한 깔끔한 스타일)"""
        s = scale
        # 정적 석상과 동일한 4톤 대리석 + 금 2톤
        marble = (185, 175, 160)
        marble_mid = (160, 150, 135)
        marble_dark = (130, 120, 108)
        marble_shadow = (105, 95, 85)
        gold = self.colors['gold']
        gold_light = self.colors['gold_light']
        lw = max(1, int(s))

        # ── 돌 받침 (땅에 묻힌 느낌의 거친 석조) ──
        base_pts = [
            (cx - int(12 * s), cy + int(6 * s)), (cx + int(12 * s), cy + int(6 * s)),
            (cx + int(10 * s), cy - int(2 * s)), (cx - int(10 * s), cy - int(2 * s))
        ]
        pygame.draw.polygon(screen, marble_shadow, base_pts)
        pygame.draw.line(screen, marble_dark,
                         (cx - int(12 * s), cy + int(6 * s)),
                         (cx + int(12 * s), cy + int(6 * s)), lw)
        pygame.draw.line(screen, gold,
                         (cx - int(10 * s), cy + int(1 * s)),
                         (cx + int(10 * s), cy + int(1 * s)), lw)

        # ── 상체 ──
        torso_pts = [
            (cx - int(7 * s), cy - int(8 * s)),
            (cx + int(7 * s), cy - int(8 * s)),
            (cx + int(10 * s), cy - int(18 * s)),
            (cx - int(10 * s), cy - int(18 * s)),
        ]
        pygame.draw.polygon(screen, marble, torso_pts)
        pygame.draw.polygon(screen, marble_dark, torso_pts, lw)
        # 토가 드레이프 (한 줄만)
        pygame.draw.line(screen, marble_dark,
                         (cx - int(9 * s), cy - int(17 * s)),
                         (cx + int(5 * s), cy - int(10 * s)), max(1, int(2 * s)))

        # ── 팔 ──
        self._draw_judgment_arms(screen, cx, cy, s, marble, marble_mid, marble_dark, gold, gold_light)

        # ── 머리 ──
        head_y = cy - int(23 * s)
        head_r = max(2, int(6 * s))
        pygame.draw.circle(screen, marble, (cx, head_y), head_r)
        pygame.draw.circle(screen, marble_dark, (cx, head_y), head_r, lw)
        # 수염
        beard_pts = [
            (cx - int(3 * s), head_y + int(4 * s)),
            (cx + int(3 * s), head_y + int(4 * s)),
            (cx + int(1 * s), head_y + int(8 * s)),
            (cx - int(1 * s), head_y + int(8 * s)),
        ]
        pygame.draw.polygon(screen, marble_mid, beard_pts)
        # 머리카락
        hr = int(7 * s)
        pygame.draw.arc(screen, marble_dark,
                        (cx - hr, head_y - hr, hr * 2, int(10 * s)),
                        0.3, math.pi - 0.3, max(1, int(2 * s)))

        # ── 월계관 ──
        wreath_color = (155, 150, 95)
        wreath_light = (175, 170, 110)
        wr = int(7 * s)
        for angle_deg in range(-70, 71, 25):
            a = math.radians(angle_deg - 90)
            lx = cx + int(wr * math.cos(a))
            ly = head_y + int(wr * math.sin(a))
            pygame.draw.circle(screen, wreath_color, (lx, ly), lw)
            if angle_deg % 50 == 0:
                pygame.draw.circle(screen, wreath_light, (lx, ly), lw)

    def _draw_judgment_arms(self, screen, cx, cy, s, marble, marble_mid, marble_dark, gold, gold_light):
        """신의심판 석상의 팔 (상완+전완 2세그먼트, 애니메이션)"""
        upper_w = max(2, int(3.5 * s))
        fore_w = max(1, int(2.5 * s))
        upper_len = int(10 * s)
        fore_len = int(10 * s)
        lw = max(1, int(s))

        # 어깨 위치 (상체 토가와 일치)
        l_shoulder = (cx - int(10 * s), cy - int(18 * s))
        r_shoulder = (cx + int(10 * s), cy - int(18 * s))

        # ── 왼팔 ──
        la_base = math.radians(140)
        la_raised = math.radians(-80)
        la_slammed = math.radians(170)
        if self.judgment_slam_progress > 0:
            la_angle = la_raised + (la_slammed - la_raised) * self.judgment_slam_progress
            la_elbow_bend = 0.4 + 0.3 * self.judgment_slam_progress
        else:
            la_angle = la_base + (la_raised - la_base) * self.judgment_left_arm_progress
            la_elbow_bend = 0.5

        # 상완 (어깨→팔꿈치)
        la_elbow = (l_shoulder[0] + int(upper_len * math.sin(la_angle)),
                    l_shoulder[1] + int(upper_len * math.cos(la_angle)))
        # 전완 (팔꿈치→손) - 팔꿈치 각도 적용
        fore_angle = la_angle + la_elbow_bend
        la_hand = (la_elbow[0] + int(fore_len * math.sin(fore_angle)),
                   la_elbow[1] + int(fore_len * math.cos(fore_angle)))

        pygame.draw.line(screen, marble, l_shoulder, la_elbow, upper_w)
        pygame.draw.line(screen, marble_mid, la_elbow, la_hand, fore_w)
        # 팔꿈치 관절
        pygame.draw.circle(screen, marble_dark, la_elbow, max(1, int(2 * s)))
        # 주먹 (하이라이트 포함)
        fist_r = max(2, int(3 * s))
        pygame.draw.circle(screen, marble_mid, la_hand, fist_r)
        pygame.draw.circle(screen, marble_dark, la_hand, fist_r, lw)

        # ── 오른팔 ──
        ra_base = math.radians(-60)
        ra_raised = math.radians(-80)
        ra_slammed = math.radians(170)
        if self.judgment_slam_progress > 0:
            ra_angle = ra_raised + (ra_slammed - ra_raised) * self.judgment_slam_progress
            ra_elbow_bend = -0.4 - 0.3 * self.judgment_slam_progress
        else:
            ra_angle = ra_base + (ra_raised - ra_base) * self.judgment_right_arm_progress
            ra_elbow_bend = -0.5

        ra_elbow = (r_shoulder[0] + int(upper_len * math.sin(ra_angle)),
                    r_shoulder[1] + int(upper_len * math.cos(ra_angle)))
        fore_angle_r = ra_angle + ra_elbow_bend
        ra_hand = (ra_elbow[0] + int(fore_len * math.sin(fore_angle_r)),
                   ra_elbow[1] + int(fore_len * math.cos(fore_angle_r)))

        pygame.draw.line(screen, marble, r_shoulder, ra_elbow, upper_w)
        pygame.draw.line(screen, marble_mid, ra_elbow, ra_hand, fore_w)
        pygame.draw.circle(screen, marble_dark, ra_elbow, max(1, int(2 * s)))
        pygame.draw.circle(screen, marble_mid, ra_hand, fist_r)
        pygame.draw.circle(screen, marble_dark, ra_hand, fist_r, lw)

        # ── 번개 (기본 상태일 때만) ──
        if self.judgment_slam_progress < 0.3 and self.judgment_left_arm_progress < 0.5:
            bolt_x, bolt_y = ra_hand[0], ra_hand[1] - int(3 * s)
            bolt_len = int(18 * s)
            segs = [
                (bolt_x, bolt_y),
                (bolt_x - int(3 * s), bolt_y - int(bolt_len * 0.25)),
                (bolt_x + int(2 * s), bolt_y - int(bolt_len * 0.4)),
                (bolt_x - int(2 * s), bolt_y - int(bolt_len * 0.6)),
                (bolt_x + int(1 * s), bolt_y - int(bolt_len * 0.78)),
                (bolt_x - int(1 * s), bolt_y - bolt_len),
            ]
            # 외곽 글로우
            glow_w = max(1, int(3 * s))
            for i in range(len(segs) - 1):
                pygame.draw.line(screen, (180, 150, 60), segs[i], segs[i + 1], glow_w)
            # 핵심 번개
            for i in range(len(segs) - 1):
                pygame.draw.line(screen, gold_light, segs[i], segs[i + 1], lw)
            # 스파크
            tip = segs[-1]
            sl = max(1, int(3 * s))
            pygame.draw.line(screen, gold_light, (tip[0] - sl, tip[1]), (tip[0] + sl, tip[1]), 1)
            pygame.draw.line(screen, gold_light, (tip[0], tip[1] - sl), (tip[0], tip[1] + sl), 1)
            pygame.draw.circle(screen, (255, 240, 180), (bolt_x, bolt_y - bolt_len // 2), lw)

    def set_crowd_excitement(self, level):
        """관중 흥분도 설정 (0.0 ~ 1.0)"""
        self.crowd_noise_level = max(0.0, min(1.0, level))

    def draw(self, screen, scale_x=1.0, scale_y=1.0, offset_x=0, offset_y=0):
        """배경 그리기"""
        # 바닥 (모래 + 석조 프레임)
        if scale_x != 1.0 or scale_y != 1.0:
            scaled_floor = pygame.transform.scale(
                self.floor_surface,
                (int(self.width * scale_x), int(self.height * scale_y))
            )
            screen.blit(scaled_floor, (offset_x, offset_y))
        else:
            screen.blit(self.floor_surface, (offset_x, offset_y))

        # 먼지 파티클 (바닥 위, 라인 아래)
        for particle in self.dust_particles:
            px = int(particle['x'] * scale_x + offset_x)
            py = int(particle['y'] * scale_y + offset_y)
            size = max(1, int(particle['size'] * scale_x))
            alpha = int(particle['alpha'] * (particle['life'] / 400))
            color = (200, 175, 140)
            pygame.draw.circle(screen, color, (px, py), size)

        # 경기장 라인 (중앙선, 중앙원)
        arena = self.arena_surface
        if scale_x != 1.0 or scale_y != 1.0:
            scaled_arena = pygame.transform.scale(
                arena, (int(self.width * scale_x), int(self.height * scale_y))
            )
            screen.blit(scaled_arena, (offset_x, offset_y))
        else:
            screen.blit(arena, (offset_x, offset_y))

        # 신의심판 이벤트 오버레이 (동적 석상)
        if self.judgment_phase != self.JUDGMENT_IDLE:
            self._draw_judgment_overlay(screen, offset_x, offset_y)

        # 횃불
        self._draw_torches(screen, scale_x, scale_y, offset_x, offset_y)

    def _draw_zeus_bolt_glow(self, screen, scale_x, scale_y, offset_x, offset_y):
        """제우스 번개 글로우 애니메이션 - 금색 빛이 주기적으로 반짝임"""
        if self.zeus_bolt_tip is None:
            return

        bx = int(self.zeus_bolt_tip[0] * scale_x + offset_x)
        by = int(self.zeus_bolt_tip[1] * scale_y + offset_y)

        # 맥동하는 글로우 강도 (0.3 ~ 1.0)
        pulse = 0.5 + 0.5 * math.sin(self.time * 3.5)
        # 간헐적 스파크 (2초마다 강한 빛)
        spark = max(0, math.sin(self.time * 5.0)) ** 8

        intensity = 0.3 + 0.4 * pulse + 0.3 * spark

        glow_radius = int((16 + 6 * pulse) * scale_x)
        if glow_radius < 4:
            return

        glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
        for r in range(glow_radius, 0, -2):
            alpha = int(30 * (r / glow_radius) * intensity)
            if alpha > 0:
                pygame.draw.circle(glow_surf, (255, 210, 80, alpha),
                                 (glow_radius, glow_radius), r)
        screen.blit(glow_surf, (bx - glow_radius, by - glow_radius),
                   special_flags=pygame.BLEND_ADD)

        # 스파크일 때 작은 빛줄기 추가
        if spark > 0.5:
            spark_len = int(6 * spark * scale_x)
            spark_alpha = int(100 * spark)
            spark_color = (255, 230, 120, spark_alpha)
            spark_surf = pygame.Surface((spark_len * 2 + 2, spark_len * 2 + 2), pygame.SRCALPHA)
            sc = spark_len + 1
            pygame.draw.line(spark_surf, spark_color, (sc - spark_len, sc), (sc + spark_len, sc), 1)
            pygame.draw.line(spark_surf, spark_color, (sc, sc - spark_len), (sc, sc + spark_len), 1)
            screen.blit(spark_surf, (bx - sc, by - sc), special_flags=pygame.BLEND_ADD)

    def _draw_torches(self, screen, scale_x, scale_y, offset_x, offset_y):
        """횃불 그리기"""
        for torch in self.torches:
            tx = int(torch['x'] * scale_x + offset_x)
            ty = int(torch['y'] * scale_y + offset_y)

            # 횃불 받침대
            holder_color = (70, 55, 40)
            pygame.draw.rect(screen, holder_color,
                           (tx - 3, ty, 6, 18))
            # 받침대 상단 장식
            pygame.draw.rect(screen, (90, 75, 55),
                           (tx - 5, ty - 3, 10, 5))

            # 불꽃
            flame_h = int(torch['flame_height'] * scale_y)
            intensity = torch['intensity']

            # 외부 불꽃 (주황)
            outer_color = (255, int(140 * intensity), 20)
            points = [
                (tx, ty - 2),
                (tx - 7, ty - flame_h // 2),
                (tx - 2, ty - flame_h * 0.7),
                (tx, ty - flame_h),
                (tx + 2, ty - flame_h * 0.7),
                (tx + 7, ty - flame_h // 2)
            ]
            pygame.draw.polygon(screen, outer_color, points)

            # 내부 불꽃 (노랑)
            inner_color = (255, int(230 * intensity), int(80 * intensity))
            inner_h = flame_h * 0.6
            inner_points = [
                (tx, ty - 4),
                (tx - 3, ty - flame_h // 3),
                (tx, ty - int(inner_h)),
                (tx + 3, ty - flame_h // 3)
            ]
            pygame.draw.polygon(screen, inner_color, inner_points)

            # 글로우 효과
            glow_radius = int(25 * intensity * scale_x)
            glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
            for r in range(glow_radius, 0, -3):
                alpha = int(25 * (r / glow_radius) * intensity)
                pygame.draw.circle(glow_surf, (255, 160, 60, alpha),
                                 (glow_radius, glow_radius), r)
            screen.blit(glow_surf, (tx - glow_radius, ty - flame_h // 2 - glow_radius),
                       special_flags=pygame.BLEND_ADD)

    def _draw_spectators(self, screen, scale_x, scale_y, offset_x, offset_y):
        """관중 실루엣 그리기"""
        for spec in self.spectators:
            sx = int(spec['x'] * scale_x + offset_x)
            sy = int(spec['y'] * scale_y + offset_y)
            size = int(spec['size'] * scale_y)

            # 웨이브 애니메이션
            wave_offset = math.sin(self.crowd_wave_timer + spec['wave_offset']) * 2 * self.crowd_noise_level
            sy += int(wave_offset)

            # 실루엣 색상 (어두운 석조색 계열)
            color = (50, 45, 40)

            # 머리
            pygame.draw.circle(screen, color, (sx, sy), size // 2)
            # 몸통
            pygame.draw.ellipse(screen, color, (sx - size // 3, sy + size // 3,
                                            size * 2 // 3, size))

    def draw_foreground(self, screen, scale_x=1.0, scale_y=1.0, offset_x=0, offset_y=0):
        """전경 효과 (패들/공 위에 그려짐) - 비네트 효과"""
        # 미세한 비네트 효과 (모서리 어둡게)
        vignette_size = 60

        # 상단 그라데이션
        for i in range(vignette_size):
            alpha = int(40 * (1 - i / vignette_size))
            if alpha > 0:
                pygame.draw.line(screen, (20, 15, 10),
                               (offset_x, offset_y + int(60 * scale_y) + i),
                               (offset_x + int(self.width * scale_x), offset_y + int(60 * scale_y) + i))

        # 하단 그라데이션
        bottom_start = offset_y + int((self.height - 60) * scale_y) - vignette_size
        for i in range(vignette_size):
            alpha = int(40 * (i / vignette_size))
            if alpha > 0:
                pygame.draw.line(screen, (20, 15, 10),
                               (offset_x, bottom_start + i),
                               (offset_x + int(self.width * scale_x), bottom_start + i))
