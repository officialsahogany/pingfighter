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
        self.judgment_quake_sound_playing = False

        # 페이즈 지속시간 (초)
        self.MERGE_DURATION = 2.0
        self.ARM_RAISE_DURATION = 2.0
        self.SLAM_DURATION = 0.5
        self.EARTHQUAKE_DURATION = 4.0
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

        # 중앙 제우스 석상
        self._draw_zeus_statue(self.arena_surface, center_x, center_y)

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

    def _draw_zeus_statue(self, surface, cx, cy):
        """고대 제우스 석상 - 원형 경기장 중앙 장식"""
        # 석상 색상 팔레트 (풍화된 대리석)
        marble = (185, 175, 160)
        marble_mid = (160, 150, 135)
        marble_dark = (130, 120, 108)
        marble_shadow = (105, 95, 85)
        pedestal_col = (115, 105, 92)
        pedestal_light = (135, 125, 112)
        gold = self.colors['gold']
        gold_light = self.colors['gold_light']

        # ── 그림자 (석상 아래 바닥) ──
        shadow_surf = pygame.Surface((50, 14), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (40, 35, 25, 50), (0, 0, 50, 14))
        surface.blit(shadow_surf, (cx - 25, cy + 16))

        # ── 받침대 (하단 베이스) ──
        # 넓은 하단
        pygame.draw.rect(surface, pedestal_col, (cx - 17, cy + 12, 34, 7))
        pygame.draw.line(surface, pedestal_light, (cx - 17, cy + 12), (cx + 16, cy + 12), 1)
        pygame.draw.line(surface, marble_shadow, (cx - 17, cy + 18), (cx + 16, cy + 18), 1)
        # 좁은 상단
        pygame.draw.rect(surface, pedestal_light, (cx - 13, cy + 4, 26, 9))
        pygame.draw.line(surface, marble_mid, (cx - 13, cy + 4), (cx + 12, cy + 4), 1)
        # 받침대 금색 장식선
        pygame.draw.line(surface, gold, (cx - 13, cy + 8), (cx + 12, cy + 8), 1)

        # ── 하체 토가 (치마 부분) ──
        robe_pts = [
            (cx - 9, cy + 4),
            (cx + 9, cy + 4),
            (cx + 7, cy - 8),
            (cx - 7, cy - 8),
        ]
        pygame.draw.polygon(surface, marble, robe_pts)
        # 토가 주름
        pygame.draw.line(surface, marble_dark, (cx - 3, cy + 3), (cx - 2, cy - 7), 1)
        pygame.draw.line(surface, marble_dark, (cx + 3, cy + 3), (cx + 4, cy - 7), 1)
        pygame.draw.line(surface, marble_mid, (cx, cy + 3), (cx + 1, cy - 7), 1)

        # ── 상체 (어깨~허리) ──
        torso_pts = [
            (cx - 7, cy - 8),
            (cx + 7, cy - 8),
            (cx + 10, cy - 18),
            (cx - 10, cy - 18),
        ]
        pygame.draw.polygon(surface, marble, torso_pts)
        pygame.draw.polygon(surface, marble_dark, torso_pts, 1)
        # 토가 드레이프 (가슴 가로지르는 천)
        pygame.draw.line(surface, marble_mid, (cx - 9, cy - 17), (cx + 5, cy - 10), 2)
        pygame.draw.line(surface, marble_mid, (cx - 7, cy - 15), (cx + 6, cy - 9), 1)

        # ── 왼팔 (아래로 내림) ──
        pygame.draw.line(surface, marble, (cx - 10, cy - 16), (cx - 14, cy - 6), 3)
        pygame.draw.line(surface, marble_mid, (cx - 14, cy - 6), (cx - 13, cy - 2), 2)

        # ── 오른팔 (위로 번개를 들고) ──
        pygame.draw.line(surface, marble, (cx + 10, cy - 16), (cx + 13, cy - 28), 3)
        pygame.draw.circle(surface, marble_mid, (cx + 13, cy - 29), 2)

        # ── 머리 ──
        head_y = cy - 23
        pygame.draw.circle(surface, marble, (cx, head_y), 6)
        pygame.draw.circle(surface, marble_dark, (cx, head_y), 6, 1)
        # 수염
        beard_pts = [
            (cx - 3, head_y + 4),
            (cx + 3, head_y + 4),
            (cx + 1, head_y + 8),
            (cx - 1, head_y + 8),
        ]
        pygame.draw.polygon(surface, marble_mid, beard_pts)
        # 머리카락 윤곽
        pygame.draw.arc(surface, marble_dark,
                       (cx - 7, head_y - 7, 14, 10), 0.3, math.pi - 0.3, 2)

        # 월계관
        wreath_color = (155, 150, 95)
        wreath_light = (175, 170, 110)
        for angle_deg in range(-70, 71, 25):
            a = math.radians(angle_deg - 90)
            lx = cx + int(7 * math.cos(a))
            ly = head_y + int(7 * math.sin(a))
            pygame.draw.circle(surface, wreath_color, (lx, ly), 1)
            # 잎사귀 하이라이트
            if angle_deg % 50 == 0:
                pygame.draw.circle(surface, wreath_light, (lx, ly), 1)

        # ── 번개 (제우스의 상징) ──
        bolt_x = cx + 13
        bolt_y = cy - 31
        bolt_segs = [
            (bolt_x, bolt_y),
            (bolt_x - 3, bolt_y - 5),
            (bolt_x + 2, bolt_y - 7),
            (bolt_x - 2, bolt_y - 11),
            (bolt_x + 1, bolt_y - 14),
            (bolt_x - 1, bolt_y - 18),
        ]
        for i in range(len(bolt_segs) - 1):
            pygame.draw.line(surface, gold, bolt_segs[i], bolt_segs[i + 1], 2)
        # 번개 끝 스파크
        tip = bolt_segs[-1]
        pygame.draw.line(surface, gold_light, (tip[0] - 3, tip[1]), (tip[0] + 3, tip[1]), 1)
        pygame.draw.line(surface, gold_light, (tip[0], tip[1] - 3), (tip[0], tip[1] + 2), 1)

        # 번개 위치 저장 (애니메이션 글로우용)
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
        self.judgment_quake_sound_playing = False
        # 합체 파티클 생성
        cx = self.GAME_AREA_X + self.GAME_AREA_WIDTH // 2
        cy = self.height // 2
        for i in range(12):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(150, 280)
            self.judgment_merge_particles.append({
                'x': cx + math.cos(angle) * dist,
                'y': cy + math.sin(angle) * dist,
                'tx': cx + random.uniform(-15, 15),
                'ty': cy + random.uniform(-20, 10),
                'size': random.uniform(8, 20),
                'alpha': 200,
                'speed': random.uniform(0.6, 1.0),
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
            # 2초간 1x → 4x 성장 (ease-out)
            progress = min(1.0, self.judgment_timer / self.MERGE_DURATION)
            ease = 1.0 - (1.0 - progress) ** 3  # ease-out cubic
            self.judgment_scale = 1.0 + (self.judgment_target_scale - 1.0) * ease
            # 합체 파티클 이동
            for p in self.judgment_merge_particles:
                p['x'] += (p['tx'] - p['x']) * dt * 2.0 * p['speed']
                p['y'] += (p['ty'] - p['y']) * dt * 2.0 * p['speed']
                p['size'] *= (1.0 - dt * 0.3)
            if progress >= 1.0:
                self.judgment_phase = self.JUDGMENT_ARM_RAISE
                self.judgment_timer = 0.0
                self.judgment_merge_particles.clear()

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
                self.judgment_flash_alpha = 255
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
            self.judgment_flash_alpha = max(0, int(255 * (1.0 - progress * 3)))
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
        intensity = 12 * self.judgment_shake_intensity  # 8px → 12px (1.5배)
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
        """신의심판 이벤트 비주얼 오버레이"""
        if self.judgment_phase == self.JUDGMENT_IDLE:
            return

        cx = self.GAME_AREA_X + self.GAME_AREA_WIDTH // 2 + offset_x
        cy = self.height // 2 + offset_y
        s = self.judgment_scale

        # 정적 석상 위를 덮기 위한 모래색 커버 (스케일 > 1.2일 때만)
        if s > 1.2:
            cover_r = int(55 * s)
            sand = self.colors['sand']
            pygame.draw.circle(screen, sand, (cx, cy), cover_r)

        # 합체 파티클 (MERGE 페이즈)
        for p in self.judgment_merge_particles:
            px, py = int(p['x']) + offset_x, int(p['y']) + offset_y
            ps = max(1, int(p['size']))
            alpha = max(0, min(255, int(p['alpha'])))
            psurf = pygame.Surface((ps * 2, ps * 2), pygame.SRCALPHA)
            pygame.draw.circle(psurf, (185, 175, 160, alpha), (ps, ps), ps)
            screen.blit(psurf, (px - ps, py - ps))
            # 금색 글로우
            if ps > 3:
                gsurf = pygame.Surface((ps * 4, ps * 4), pygame.SRCALPHA)
                pygame.draw.circle(gsurf, (212, 175, 85, alpha // 3), (ps * 2, ps * 2), ps * 2)
                screen.blit(gsurf, (px - ps * 2, py - ps * 2), special_flags=pygame.BLEND_ADD)

        # 동적 제우스 석상 그리기
        self._draw_judgment_statue_scaled(screen, cx, cy, s)

        # 에너지 글로우 (성장/합체 중)
        if self.judgment_phase in (self.JUDGMENT_MERGE, self.JUDGMENT_ARM_RAISE):
            glow_r = int(40 * s)
            glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
            pulse = 0.5 + 0.5 * math.sin(self.time * 6)
            for r in range(glow_r, 0, -3):
                alpha = int(20 * (r / glow_r) * pulse)
                if alpha > 0:
                    pygame.draw.circle(glow_surf, (212, 175, 85, alpha), (glow_r, glow_r), r)
            screen.blit(glow_surf, (cx - glow_r, cy - glow_r), special_flags=pygame.BLEND_ADD)

        # 슬램 파편
        for d in self.judgment_slam_debris:
            dx, dy = int(d['x']) + offset_x, int(d['y']) + offset_y
            ds = max(1, int(d['size'] * d['life']))
            pygame.draw.circle(screen, d['color'], (dx, dy), ds)

        # 먼지 비
        for d in self.judgment_dust_rain:
            dx, dy = int(d['x']) + offset_x, int(d['y']) + offset_y
            ds = max(1, int(d['size']))
            alpha = max(0, min(255, int(d['alpha'] * min(1, d['life']))))
            pygame.draw.circle(screen, (180, 160, 130), (dx, dy), ds)

        # 충격 플래시 (슬램/지진 시작)
        if self.judgment_flash_alpha > 0:
            flash_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            flash_surf.fill((255, 240, 200, min(255, self.judgment_flash_alpha)))
            screen.blit(flash_surf, (offset_x, offset_y))

    def _draw_judgment_statue_scaled(self, screen, cx, cy, scale):
        """신의심판 동안 스케일된 제우스 석상 그리기"""
        s = scale
        marble = (185, 175, 160)
        marble_mid = (160, 150, 135)
        marble_dark = (130, 120, 108)
        marble_shadow = (105, 95, 85)
        pedestal_col = (115, 105, 92)
        pedestal_light = (135, 125, 112)
        gold = self.colors['gold']
        gold_light = self.colors['gold_light']

        # 발 흔들림 적용 (하체 오프셋)
        feet_ox = int(math.sin(self.judgment_feet_swing) * 8 * s) if s > 1.5 else 0

        # ── 그림자 ──
        sw, sh = int(50 * s), int(14 * s)
        if sw > 2 and sh > 2:
            shadow_s = pygame.Surface((sw, sh), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_s, (40, 35, 25, 50), (0, 0, sw, sh))
            screen.blit(shadow_s, (cx - sw // 2, cy + int(16 * s)))

        # ── 받침대 ──
        pw = int(17 * s)
        pygame.draw.rect(screen, pedestal_col,
                         (cx - pw + feet_ox, cy + int(12 * s), pw * 2, max(1, int(7 * s))))
        pygame.draw.line(screen, pedestal_light,
                         (cx - pw + feet_ox, cy + int(12 * s)),
                         (cx + pw - 1 + feet_ox, cy + int(12 * s)), max(1, int(s)))
        # 금색 장식
        pygame.draw.rect(screen, pedestal_light,
                         (cx - int(13 * s) + feet_ox, cy + int(4 * s), int(26 * s), max(1, int(9 * s))))
        pygame.draw.line(screen, gold,
                         (cx - int(13 * s) + feet_ox, cy + int(8 * s)),
                         (cx + int(12 * s) + feet_ox, cy + int(8 * s)), max(1, int(s)))

        # ── 하체 토가 (발 흔들림 적용) ──
        robe_pts = [
            (cx - int(9 * s) + feet_ox, cy + int(4 * s)),
            (cx + int(9 * s) + feet_ox, cy + int(4 * s)),
            (cx + int(7 * s), cy - int(8 * s)),
            (cx - int(7 * s), cy - int(8 * s)),
        ]
        pygame.draw.polygon(screen, marble, robe_pts)
        pygame.draw.line(screen, marble_dark,
                         (cx - int(3 * s), cy + int(3 * s)),
                         (cx - int(2 * s), cy - int(7 * s)), max(1, int(s)))
        pygame.draw.line(screen, marble_dark,
                         (cx + int(3 * s), cy + int(3 * s)),
                         (cx + int(4 * s), cy - int(7 * s)), max(1, int(s)))

        # ── 상체 ──
        torso_pts = [
            (cx - int(7 * s), cy - int(8 * s)),
            (cx + int(7 * s), cy - int(8 * s)),
            (cx + int(10 * s), cy - int(18 * s)),
            (cx - int(10 * s), cy - int(18 * s)),
        ]
        pygame.draw.polygon(screen, marble, torso_pts)
        pygame.draw.polygon(screen, marble_dark, torso_pts, max(1, int(s)))
        # 토가 드레이프
        pygame.draw.line(screen, marble_mid,
                         (cx - int(9 * s), cy - int(17 * s)),
                         (cx + int(5 * s), cy - int(10 * s)), max(1, int(2 * s)))

        # ── 팔 그리기 ──
        self._draw_judgment_arms(screen, cx, cy, s, marble, marble_mid, marble_dark, gold, gold_light)

        # ── 머리 ──
        head_y = cy - int(23 * s)
        head_r = max(2, int(6 * s))
        pygame.draw.circle(screen, marble, (cx, head_y), head_r)
        pygame.draw.circle(screen, marble_dark, (cx, head_y), head_r, max(1, int(s)))
        # 수염
        br = int(3 * s)
        beard_pts = [
            (cx - br, head_y + int(4 * s)),
            (cx + br, head_y + int(4 * s)),
            (cx + int(1 * s), head_y + int(8 * s)),
            (cx - int(1 * s), head_y + int(8 * s)),
        ]
        pygame.draw.polygon(screen, marble_mid, beard_pts)
        # 머리카락
        pygame.draw.arc(screen, marble_dark,
                        (cx - int(7 * s), head_y - int(7 * s), int(14 * s), int(10 * s)),
                        0.3, math.pi - 0.3, max(1, int(2 * s)))
        # 월계관
        wreath_color = (155, 150, 95)
        wreath_light = (175, 170, 110)
        wr = int(7 * s)
        for angle_deg in range(-70, 71, 25):
            a = math.radians(angle_deg - 90)
            lx = cx + int(wr * math.cos(a))
            ly = head_y + int(wr * math.sin(a))
            pygame.draw.circle(screen, wreath_color, (lx, ly), max(1, int(s)))
            if angle_deg % 50 == 0:
                pygame.draw.circle(screen, wreath_light, (lx, ly), max(1, int(s)))

    def _draw_judgment_arms(self, screen, cx, cy, s, marble, marble_mid, marble_dark, gold, gold_light):
        """신의심판 석상의 팔 그리기 (애니메이션 적용)"""
        arm_w = max(1, int(3 * s))

        # 어깨 위치
        l_shoulder = (cx - int(10 * s), cy - int(16 * s))
        r_shoulder = (cx + int(10 * s), cy - int(16 * s))
        arm_len = int(18 * s)

        # 왼팔 각도: 기본(아래) → 올린 상태 → 내려침
        # 기본: ~140도(아래), 올림: ~-80도(위), 내려침: ~160도(아래 강타)
        la_base = math.radians(140)   # 아래로 향함
        la_raised = math.radians(-80)  # 위로 향함
        la_slammed = math.radians(170) # 강타 (아래로 더 깊게)

        if self.judgment_slam_progress > 0:
            # 내려치기 중
            la_angle = la_raised + (la_slammed - la_raised) * self.judgment_slam_progress
        else:
            la_angle = la_base + (la_raised - la_base) * self.judgment_left_arm_progress

        la_end = (l_shoulder[0] + int(arm_len * math.sin(la_angle)),
                  l_shoulder[1] + int(arm_len * math.cos(la_angle)))
        pygame.draw.line(screen, marble, l_shoulder, la_end, arm_w)
        # 주먹
        fist_r = max(2, int(3 * s))
        pygame.draw.circle(screen, marble_mid, la_end, fist_r)

        # 오른팔 각도: 기본(위 번개) → 올린 상태 → 내려침
        ra_base = math.radians(-60)    # 위로 번개 들고
        ra_raised = math.radians(-80)  # 위로 더 올림
        ra_slammed = math.radians(170) # 강타

        if self.judgment_slam_progress > 0:
            ra_angle = ra_raised + (ra_slammed - ra_raised) * self.judgment_slam_progress
        else:
            ra_angle = ra_base + (ra_raised - ra_base) * self.judgment_right_arm_progress

        ra_end = (r_shoulder[0] + int(arm_len * math.sin(ra_angle)),
                  r_shoulder[1] + int(arm_len * math.cos(ra_angle)))
        pygame.draw.line(screen, marble, r_shoulder, ra_end, arm_w)
        # 주먹
        pygame.draw.circle(screen, marble_mid, ra_end, fist_r)

        # 번개 (기본 상태일 때만, 슬램 진행 중이면 숨김)
        if self.judgment_slam_progress < 0.3 and self.judgment_left_arm_progress < 0.5:
            bolt_x = ra_end[0]
            bolt_y = ra_end[1] - int(3 * s)
            bolt_len = int(18 * s)
            segs = [
                (bolt_x, bolt_y),
                (bolt_x - int(3 * s), bolt_y - int(bolt_len * 0.28)),
                (bolt_x + int(2 * s), bolt_y - int(bolt_len * 0.39)),
                (bolt_x - int(2 * s), bolt_y - int(bolt_len * 0.61)),
                (bolt_x + int(1 * s), bolt_y - int(bolt_len * 0.78)),
                (bolt_x - int(1 * s), bolt_y - bolt_len),
            ]
            for i in range(len(segs) - 1):
                pygame.draw.line(screen, gold, segs[i], segs[i + 1], max(1, int(2 * s)))
            tip = segs[-1]
            spark_len = max(1, int(3 * s))
            pygame.draw.line(screen, gold_light, (tip[0] - spark_len, tip[1]), (tip[0] + spark_len, tip[1]), 1)
            pygame.draw.line(screen, gold_light, (tip[0], tip[1] - spark_len), (tip[0], tip[1] + spark_len), 1)

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
        if scale_x != 1.0 or scale_y != 1.0:
            scaled_arena = pygame.transform.scale(
                self.arena_surface,
                (int(self.width * scale_x), int(self.height * scale_y))
            )
            screen.blit(scaled_arena, (offset_x, offset_y))
        else:
            screen.blit(self.arena_surface, (offset_x, offset_y))

        # 신의심판 이벤트 오버레이 (동적 석상)
        if self.judgment_phase != self.JUDGMENT_IDLE:
            self._draw_judgment_overlay(screen, offset_x, offset_y)
        else:
            # 제우스 번개 글로우 애니메이션 (평상시에만)
            self._draw_zeus_bolt_glow(screen, scale_x, scale_y, offset_x, offset_y)

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
