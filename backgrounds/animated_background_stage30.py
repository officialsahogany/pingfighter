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
        """고대 제우스 석상 - 고전 그리스 조각상 스타일 (고급 디테일)"""
        # 색상 팔레트 (청동+대리석 혼합)
        marble = (190, 180, 165)
        marble_hi = (210, 200, 185)
        marble_mid = (165, 155, 140)
        marble_dark = (135, 125, 112)
        marble_shadow = (108, 98, 88)
        bronze = (160, 130, 85)
        bronze_hi = (185, 155, 105)
        bronze_dk = (120, 95, 60)
        pedestal = (118, 108, 95)
        ped_hi = (140, 130, 115)
        ped_dk = (90, 82, 72)
        gold = self.colors['gold']
        gold_light = self.colors['gold_light']

        # ── 그림자 (부드러운 타원) ──
        for i in range(3):
            sh_w, sh_h = 52 - i * 6, 14 - i * 2
            sh_a = 30 + i * 15
            sh_s = pygame.Surface((sh_w, sh_h), pygame.SRCALPHA)
            pygame.draw.ellipse(sh_s, (35, 30, 22, sh_a), (0, 0, sh_w, sh_h))
            surface.blit(sh_s, (cx - sh_w // 2, cy + 15 + i))

        # ── 3단 받침대 (클래식 기둥 양식) ──
        # 1단 (최하단) - 넓은 베이스
        pygame.draw.rect(surface, ped_dk, (cx - 20, cy + 16, 40, 5))
        pygame.draw.line(surface, ped_hi, (cx - 20, cy + 16), (cx + 19, cy + 16), 1)
        # 2단 (중간)
        pygame.draw.rect(surface, pedestal, (cx - 17, cy + 10, 34, 7))
        pygame.draw.line(surface, ped_hi, (cx - 17, cy + 10), (cx + 16, cy + 10), 1)
        pygame.draw.line(surface, ped_dk, (cx - 17, cy + 16), (cx + 16, cy + 16), 1)
        # 3단 (상단) - 좁은 대좌
        pygame.draw.rect(surface, ped_hi, (cx - 13, cy + 3, 26, 8))
        pygame.draw.line(surface, marble_mid, (cx - 13, cy + 3), (cx + 12, cy + 3), 1)
        # 금색 트림 2줄
        pygame.draw.line(surface, gold, (cx - 15, cy + 9), (cx + 14, cy + 9), 1)
        pygame.draw.line(surface, bronze_hi, (cx - 13, cy + 6), (cx + 12, cy + 6), 1)
        # 받침대 면 그라데이션 (미세한 음영)
        pygame.draw.line(surface, ped_dk, (cx - 20, cy + 20), (cx + 19, cy + 20), 1)

        # ── 하체 토가 (곡선 드레이프) ──
        robe_pts = [
            (cx - 10, cy + 3), (cx + 10, cy + 3),
            (cx + 8, cy - 3), (cx + 7, cy - 7),
            (cx - 7, cy - 7), (cx - 8, cy - 3),
        ]
        pygame.draw.polygon(surface, marble, robe_pts)
        # 토가 주름 (곡선감)
        pygame.draw.line(surface, marble_dark, (cx - 5, cy + 2), (cx - 4, cy - 6), 1)
        pygame.draw.line(surface, marble_dark, (cx + 1, cy + 2), (cx + 2, cy - 6), 1)
        pygame.draw.line(surface, marble_dark, (cx + 5, cy + 2), (cx + 5, cy - 6), 1)
        pygame.draw.line(surface, marble_hi, (cx - 2, cy + 1), (cx - 1, cy - 5), 1)
        # 허리 벨트
        pygame.draw.line(surface, bronze, (cx - 7, cy - 7), (cx + 7, cy - 7), 1)
        pygame.draw.line(surface, bronze_hi, (cx - 6, cy - 8), (cx + 6, cy - 8), 1)

        # ── 상체 (넓은 어깨, 가슴 디테일) ──
        torso_pts = [
            (cx - 7, cy - 8), (cx + 7, cy - 8),
            (cx + 11, cy - 16), (cx + 10, cy - 19),
            (cx - 10, cy - 19), (cx - 11, cy - 16),
        ]
        pygame.draw.polygon(surface, marble, torso_pts)
        # 근육 라인 (가슴 중앙선 + 어깨)
        pygame.draw.line(surface, marble_mid, (cx, cy - 9), (cx, cy - 17), 1)
        pygame.draw.line(surface, marble_mid, (cx - 4, cy - 15), (cx - 8, cy - 18), 1)
        pygame.draw.line(surface, marble_mid, (cx + 4, cy - 15), (cx + 8, cy - 18), 1)
        # 토가 사선 드레이프 (왼어깨→오른허리)
        pygame.draw.line(surface, marble_dark, (cx - 10, cy - 18), (cx + 4, cy - 10), 2)
        pygame.draw.line(surface, marble_mid, (cx - 8, cy - 17), (cx + 5, cy - 9), 1)
        # 목
        pygame.draw.line(surface, marble, (cx - 2, cy - 19), (cx - 2, cy - 22), 2)
        pygame.draw.line(surface, marble, (cx + 1, cy - 19), (cx + 1, cy - 22), 2)

        # ── 왼팔 (아래로, 팔꿈치 굴곡) ──
        pygame.draw.line(surface, marble, (cx - 11, cy - 17), (cx - 14, cy - 10), 3)
        pygame.draw.line(surface, marble_mid, (cx - 14, cy - 10), (cx - 13, cy - 4), 2)
        pygame.draw.circle(surface, marble_dark, (cx - 13, cy - 3), 2)  # 주먹

        # ── 오른팔 (위로, 번개 파지) ──
        pygame.draw.line(surface, marble, (cx + 11, cy - 17), (cx + 14, cy - 24), 3)
        pygame.draw.line(surface, marble_mid, (cx + 14, cy - 24), (cx + 13, cy - 30), 2)
        pygame.draw.circle(surface, marble_dark, (cx + 13, cy - 31), 2)  # 주먹

        # ── 머리 (얼굴 디테일) ──
        head_y = cy - 25
        # 머리 본체
        pygame.draw.circle(surface, marble, (cx, head_y), 6)
        # 얼굴 윤곽 하이라이트
        pygame.draw.arc(surface, marble_hi, (cx - 5, head_y - 5, 10, 10), 0.5, 2.6, 1)
        # 눈 라인
        pygame.draw.line(surface, marble_dark, (cx - 3, head_y - 1), (cx - 1, head_y - 1), 1)
        pygame.draw.line(surface, marble_dark, (cx + 1, head_y - 1), (cx + 3, head_y - 1), 1)
        # 코
        pygame.draw.line(surface, marble_mid, (cx, head_y - 1), (cx, head_y + 1), 1)
        # 수염 (풍성한 삼각형)
        beard_pts = [
            (cx - 4, head_y + 3), (cx + 4, head_y + 3),
            (cx + 2, head_y + 9), (cx, head_y + 10), (cx - 2, head_y + 9),
        ]
        pygame.draw.polygon(surface, marble_mid, beard_pts)
        pygame.draw.line(surface, marble_dark, (cx - 1, head_y + 4), (cx - 1, head_y + 8), 1)
        pygame.draw.line(surface, marble_dark, (cx + 1, head_y + 4), (cx + 1, head_y + 8), 1)
        # 머리카락 (볼륨감)
        pygame.draw.arc(surface, marble_dark,
                        (cx - 7, head_y - 7, 14, 10), 0.2, math.pi - 0.2, 2)
        pygame.draw.arc(surface, marble_shadow,
                        (cx - 8, head_y - 8, 16, 11), 0.3, math.pi - 0.3, 1)

        # ── 월계관 (잎사귀 모양) ──
        wreath = (140, 145, 80)
        wreath_hi = (170, 175, 105)
        wreath_dk = (110, 115, 60)
        for angle_deg in range(-80, 81, 18):
            a = math.radians(angle_deg - 90)
            lx = cx + int(8 * math.cos(a))
            ly = head_y + int(7 * math.sin(a))
            # 잎 모양 (타원)
            leaf_a = a + math.pi / 2
            dx, dy = int(2 * math.cos(leaf_a)), int(2 * math.sin(leaf_a))
            pygame.draw.line(surface, wreath, (lx - dx, ly - dy), (lx + dx, ly + dy), 1)
            pygame.draw.circle(surface, wreath_hi if angle_deg % 36 == 0 else wreath, (lx, ly), 1)

        # ── 번개 (지그재그 + 글로우) ──
        bolt_x, bolt_y = cx + 13, cy - 33
        bolt_segs = [
            (bolt_x, bolt_y),
            (bolt_x - 3, bolt_y - 4),
            (bolt_x + 2, bolt_y - 7),
            (bolt_x - 2, bolt_y - 10),
            (bolt_x + 1, bolt_y - 13),
            (bolt_x - 1, bolt_y - 17),
        ]
        # 외곽 글로우
        for i in range(len(bolt_segs) - 1):
            pygame.draw.line(surface, (180, 150, 60), bolt_segs[i], bolt_segs[i + 1], 3)
        # 핵심 번개
        for i in range(len(bolt_segs) - 1):
            pygame.draw.line(surface, gold_light, bolt_segs[i], bolt_segs[i + 1], 1)
        # 스파크 (십자)
        tip = bolt_segs[-1]
        pygame.draw.line(surface, gold_light, (tip[0] - 3, tip[1]), (tip[0] + 3, tip[1]), 1)
        pygame.draw.line(surface, gold_light, (tip[0], tip[1] - 3), (tip[0], tip[1] + 2), 1)
        # 작은 광점
        pygame.draw.circle(surface, (255, 240, 180), (bolt_x - 1, bolt_y - 10), 1)

        self.zeus_bolt_tip = (bolt_x - 1, bolt_y - 10)

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
        # 합체 파티클 생성 (석조 파편 + 에너지 위스프)
        cx = self.GAME_AREA_X + self.GAME_AREA_WIDTH // 2
        cy = self.height // 2
        # 석조 파편 (불규칙 다각형)
        for i in range(8):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(120, 250)
            # 파편 꼭짓점 (3~5각형)
            n_verts = random.randint(3, 5)
            verts = []
            frag_size = random.uniform(6, 14)
            for v in range(n_verts):
                va = (v / n_verts) * math.pi * 2 + random.uniform(-0.4, 0.4)
                vr = frag_size * random.uniform(0.5, 1.0)
                verts.append((math.cos(va) * vr, math.sin(va) * vr))
            col_idx = random.randint(0, 2)
            colors = [(190, 180, 165), (165, 155, 140), (140, 130, 115)]
            self.judgment_merge_particles.append({
                'type': 'stone',
                'x': cx + math.cos(angle) * dist,
                'y': cy + math.sin(angle) * dist,
                'tx': cx + random.uniform(-10, 10),
                'ty': cy + random.uniform(-15, 5),
                'verts': verts,
                'color': colors[col_idx],
                'alpha': 220,
                'speed': random.uniform(0.8, 1.2),
                'rot': random.uniform(0, math.pi * 2),
                'rot_speed': random.uniform(-3, 3),
            })
        # 에너지 위스프 (곡선 빛 줄기)
        for i in range(10):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(100, 220)
            self.judgment_merge_particles.append({
                'type': 'wisp',
                'x': cx + math.cos(angle) * dist,
                'y': cy + math.sin(angle) * dist,
                'tx': cx + random.uniform(-8, 8),
                'ty': cy + random.uniform(-12, 4),
                'prev_x': cx + math.cos(angle) * (dist + 10),
                'prev_y': cy + math.sin(angle) * (dist + 10),
                'alpha': random.randint(120, 200),
                'speed': random.uniform(1.0, 1.6),
                'width': random.uniform(1.0, 2.5),
                'color_type': random.choice(['warm', 'bronze', 'white']),
            })
        # 미세 광점 (시머 스파클)
        for i in range(15):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(60, 200)
            self.judgment_merge_particles.append({
                'type': 'spark',
                'x': cx + math.cos(angle) * dist,
                'y': cy + math.sin(angle) * dist,
                'tx': cx + random.uniform(-20, 20),
                'ty': cy + random.uniform(-25, 10),
                'alpha': random.randint(150, 255),
                'speed': random.uniform(1.2, 2.0),
                'size': random.uniform(0.5, 1.5),
                'flicker': random.uniform(0, math.pi * 2),
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
            # 합체 파티클 이동 (타입별 처리)
            for p in self.judgment_merge_particles:
                old_x, old_y = p['x'], p['y']
                lerp_speed = dt * 2.2 * p['speed']
                p['x'] += (p['tx'] - p['x']) * lerp_speed
                p['y'] += (p['ty'] - p['y']) * lerp_speed
                if p['type'] == 'stone':
                    p['rot'] += p['rot_speed'] * dt
                    p['alpha'] = max(0, p['alpha'] - dt * 30)
                elif p['type'] == 'wisp':
                    p['prev_x'] = old_x
                    p['prev_y'] = old_y
                    p['alpha'] = max(0, p['alpha'] - dt * 20)
                elif p['type'] == 'spark':
                    p['flicker'] += dt * 12
                    p['alpha'] = max(0, p['alpha'] - dt * 25)
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
        """신의심판 이벤트 비주얼 오버레이 (프리미엄)"""
        if self.judgment_phase == self.JUDGMENT_IDLE:
            return

        cx = self.GAME_AREA_X + self.GAME_AREA_WIDTH // 2 + offset_x
        cy = self.height // 2 + offset_y
        s = self.judgment_scale

        # 정적 석상 위를 부드럽게 덮기 (스케일에 비례하는 알파 페이드)
        if s > 1.0:
            cover_r = int(55 * max(1.2, s))
            # s=1.0→알파0, s=1.5→알파255 (매끄러운 전환)
            cover_alpha = min(255, int(255 * (s - 1.0) / 0.5))
            if cover_alpha > 0 and cover_r > 5:
                sand = self.colors['sand']
                cover_s = pygame.Surface((cover_r * 2, cover_r * 2), pygame.SRCALPHA)
                pygame.draw.circle(cover_s, (*sand, cover_alpha), (cover_r, cover_r), cover_r)
                screen.blit(cover_s, (cx - cover_r, cy - cover_r))

        # ── 합체 파티클 (MERGE 페이즈) ──
        for p in self.judgment_merge_particles:
            px, py = int(p['x']) + offset_x, int(p['y']) + offset_y
            alpha = max(0, min(255, int(p['alpha'])))
            if alpha <= 0:
                continue

            if p['type'] == 'stone':
                # 석조 파편: 회전하는 불규칙 다각형
                rot = p['rot']
                cos_r, sin_r = math.cos(rot), math.sin(rot)
                pts = []
                for vx, vy in p['verts']:
                    rx = vx * cos_r - vy * sin_r
                    ry = vx * sin_r + vy * cos_r
                    pts.append((px + int(rx), py + int(ry)))
                if len(pts) >= 3:
                    col = p['color']
                    faded = (col[0], col[1], col[2], alpha)
                    # 파편 그리기 (알파 포함)
                    frag_sz = max(int(max(abs(v[0]) for v in p['verts'])) * 2 + 4, 8)
                    frag_surf = pygame.Surface((frag_sz * 2, frag_sz * 2), pygame.SRCALPHA)
                    shifted = [(x - px + frag_sz, y - py + frag_sz) for x, y in pts]
                    pygame.draw.polygon(frag_surf, faded, shifted)
                    # 밝은 모서리 하이라이트
                    hi_col = (min(255, col[0] + 30), min(255, col[1] + 25), min(255, col[2] + 20), alpha // 2)
                    pygame.draw.polygon(frag_surf, hi_col, shifted, 1)
                    screen.blit(frag_surf, (px - frag_sz, py - frag_sz))

            elif p['type'] == 'wisp':
                # 에너지 위스프: 빛 줄기 트레일
                prev_x = int(p['prev_x']) + offset_x
                prev_y = int(p['prev_y']) + offset_y
                w = max(1, int(p['width']))
                if p['color_type'] == 'warm':
                    col = (220, 190, 130, alpha)
                elif p['color_type'] == 'bronze':
                    col = (185, 155, 105, alpha)
                else:
                    col = (240, 235, 220, alpha)
                # 트레일 (이전 위치 → 현재 위치)
                trail_surf = pygame.Surface((abs(px - prev_x) + 20, abs(py - prev_y) + 20), pygame.SRCALPHA)
                t_ox = min(px, prev_x) - 10
                t_oy = min(py, prev_y) - 10
                pygame.draw.line(trail_surf, col,
                                 (prev_x - t_ox, prev_y - t_oy),
                                 (px - t_ox, py - t_oy), w)
                # 앞부분 밝은 점
                tip_col = (min(255, col[0] + 35), min(255, col[1] + 30), min(255, col[2] + 25), min(255, alpha))
                pygame.draw.circle(trail_surf, tip_col, (px - t_ox, py - t_oy), max(1, w))
                screen.blit(trail_surf, (t_ox, t_oy))

            elif p['type'] == 'spark':
                # 미세 광점: 깜빡이는 작은 빛
                flicker = 0.5 + 0.5 * math.sin(p['flicker'])
                sa = int(alpha * flicker)
                if sa > 10:
                    sz = max(1, int(p['size'] * (0.5 + flicker * 0.5)))
                    spark_col = (245, 235, 210, sa)
                    if sz <= 1:
                        screen.set_at((px, py), (245, 235, 210))
                    else:
                        sp_s = pygame.Surface((sz * 4, sz * 4), pygame.SRCALPHA)
                        pygame.draw.circle(sp_s, spark_col, (sz * 2, sz * 2), sz)
                        # 십자 광선
                        line_col = (255, 248, 230, sa // 2)
                        pygame.draw.line(sp_s, line_col, (sz * 2 - sz * 2, sz * 2), (sz * 2 + sz * 2, sz * 2), 1)
                        pygame.draw.line(sp_s, line_col, (sz * 2, sz * 2 - sz * 2), (sz * 2, sz * 2 + sz * 2), 1)
                        screen.blit(sp_s, (px - sz * 2, py - sz * 2), special_flags=pygame.BLEND_ADD)

        # ── 동적 제우스 석상 그리기 ──
        self._draw_judgment_statue_scaled(screen, cx, cy, s)

        # ── 오라 이펙트 (성장/합체 중) ──
        if self.judgment_phase in (self.JUDGMENT_MERGE, self.JUDGMENT_ARM_RAISE):
            pulse = 0.5 + 0.5 * math.sin(self.time * 4.5)
            # 방사형 라이트 레이 (원형 배치)
            ray_count = 12
            for i in range(ray_count):
                ray_angle = (i / ray_count) * math.pi * 2 + self.time * 0.8
                inner_r = int(20 * s)
                outer_r = int((35 + 10 * pulse) * s)
                x1 = cx + int(inner_r * math.cos(ray_angle))
                y1 = cy + int(inner_r * math.sin(ray_angle))
                x2 = cx + int(outer_r * math.cos(ray_angle))
                y2 = cy + int(outer_r * math.sin(ray_angle))
                ray_alpha = int(40 * pulse)
                if ray_alpha > 5:
                    ray_s = pygame.Surface((abs(x2 - x1) + 10, abs(y2 - y1) + 10), pygame.SRCALPHA)
                    ro = (min(x1, x2) - 5, min(y1, y2) - 5)
                    pygame.draw.line(ray_s, (230, 210, 160, ray_alpha),
                                     (x1 - ro[0], y1 - ro[1]), (x2 - ro[0], y2 - ro[1]),
                                     max(1, int(1.5 * s)))
                    screen.blit(ray_s, ro, special_flags=pygame.BLEND_ADD)
            # 내부 코어 글로우 (은은한 백색~금색)
            core_r = int(15 * s)
            if core_r > 2:
                core_s = pygame.Surface((core_r * 2, core_r * 2), pygame.SRCALPHA)
                for r in range(core_r, 0, -2):
                    a = int(18 * (r / core_r) * pulse)
                    if a > 0:
                        pygame.draw.circle(core_s, (240, 230, 210, a), (core_r, core_r), r)
                screen.blit(core_s, (cx - core_r, cy - core_r), special_flags=pygame.BLEND_ADD)

        # ── 슬램 파편 (불규칙 형태) ──
        for d in self.judgment_slam_debris:
            dx, dy = int(d['x']) + offset_x, int(d['y']) + offset_y
            ds = max(1, int(d['size'] * min(1, d['life'])))
            # 파편을 작은 사각형으로
            col = d['color']
            a = max(0, min(255, int(255 * d['life'])))
            if ds <= 2:
                pygame.draw.circle(screen, col, (dx, dy), ds)
            else:
                dsf = pygame.Surface((ds * 2, ds * 2), pygame.SRCALPHA)
                rect_pts = [(ds - ds // 2, ds - ds), (ds + ds // 2, ds - ds // 3),
                            (ds + ds // 3, ds + ds // 2), (ds - ds, ds + ds // 3)]
                pygame.draw.polygon(dsf, (*col, a), rect_pts)
                screen.blit(dsf, (dx - ds, dy - ds))

        # ── 먼지 비 (세로 줄기) ──
        for d in self.judgment_dust_rain:
            dx, dy = int(d['x']) + offset_x, int(d['y']) + offset_y
            a = max(0, min(255, int(d['alpha'] * min(1, d['life']))))
            if a > 5:
                # 수직 줄기 형태
                streak_len = max(2, int(d['vy'] * 1.5))
                ds = pygame.Surface((3, streak_len + 2), pygame.SRCALPHA)
                pygame.draw.line(ds, (190, 170, 145, a), (1, 0), (1, streak_len), 1)
                pygame.draw.line(ds, (170, 150, 125, a // 2), (2, 1), (2, streak_len - 1), 1)
                screen.blit(ds, (dx - 1, dy - streak_len // 2))

        # ── RETURN 페이즈: 수축 에너지 링 ──
        if self.judgment_phase == self.JUDGMENT_RETURN:
            ret_progress = min(1.0, self.judgment_timer / self.RETURN_DURATION)
            ring_r = int((50 + 30 * (1.0 - ret_progress)) * s)
            ring_a = int(60 * (1.0 - ret_progress))
            if ring_r > 5 and ring_a > 3:
                ring_s = pygame.Surface((ring_r * 2 + 4, ring_r * 2 + 4), pygame.SRCALPHA)
                rc = ring_r + 2
                # 외곽 링
                pygame.draw.circle(ring_s, (210, 195, 160, ring_a), (rc, rc), ring_r, max(1, int(2 * s)))
                # 내부 링 (더 밝게)
                inner_r = int(ring_r * 0.6)
                if inner_r > 3:
                    pygame.draw.circle(ring_s, (235, 225, 200, ring_a // 2), (rc, rc), inner_r, max(1, int(2 * s)))
                screen.blit(ring_s, (cx - rc, cy - rc), special_flags=pygame.BLEND_ADD)

        # ── 충격 플래시 (방사형 그라데이션) ──
        if self.judgment_flash_alpha > 0:
            fa = min(255, self.judgment_flash_alpha)
            flash_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            # 중앙에서 방사형으로 밝아지는 플래시
            flash_r = int(self.width * 0.7)
            for r in range(flash_r, 0, -8):
                ring_a = int(fa * (r / flash_r) * 0.6)
                if ring_a > 0:
                    pygame.draw.circle(flash_surf, (255, 245, 220, ring_a), (cx - offset_x, cy - offset_y), r)
            screen.blit(flash_surf, (offset_x, offset_y), special_flags=pygame.BLEND_ADD)

    def _draw_judgment_statue_scaled(self, screen, cx, cy, scale):
        """신의심판 동안 스케일된 제우스 석상 (고급 디테일)"""
        s = scale
        marble = (190, 180, 165)
        marble_hi = (210, 200, 185)
        marble_mid = (165, 155, 140)
        marble_dark = (135, 125, 112)
        marble_shadow = (108, 98, 88)
        bronze = (160, 130, 85)
        bronze_hi = (185, 155, 105)
        ped = (118, 108, 95)
        ped_hi = (140, 130, 115)
        ped_dk = (90, 82, 72)
        gold = self.colors['gold']
        gold_light = self.colors['gold_light']
        lw = max(1, int(s))  # 기본 라인 굵기

        # 발 흔들림 (하체 오프셋)
        feet_ox = int(math.sin(self.judgment_feet_swing) * 8 * s) if s > 1.5 else 0
        # 호흡/미세 흔들림 (살아있는 느낌)
        if s > 1.5 and self.judgment_phase in (self.JUDGMENT_ARM_RAISE, self.JUDGMENT_EARTHQUAKE):
            breath = math.sin(self.time * 2.5) * 0.5 * s
            cy = cy + int(breath)

        # ── 그림자 (다중 레이어) ──
        for layer in range(3):
            sw = int((54 - layer * 8) * s)
            sh = int((16 - layer * 3) * s)
            sa = 25 + layer * 18
            if sw > 2 and sh > 2:
                ss = pygame.Surface((sw, sh), pygame.SRCALPHA)
                pygame.draw.ellipse(ss, (35, 30, 22, sa), (0, 0, sw, sh))
                screen.blit(ss, (cx - sw // 2, cy + int((16 + layer) * s)))

        # ── 3단 받침대 ──
        # 1단 (최하단)
        bw1 = int(20 * s)
        bh1 = max(1, int(5 * s))
        by1 = cy + int(16 * s)
        pygame.draw.rect(screen, ped_dk, (cx - bw1 + feet_ox, by1, bw1 * 2, bh1))
        pygame.draw.line(screen, ped_hi, (cx - bw1 + feet_ox, by1), (cx + bw1 - 1 + feet_ox, by1), lw)
        pygame.draw.line(screen, ped_dk, (cx - bw1 + feet_ox, by1 + bh1 - 1),
                         (cx + bw1 - 1 + feet_ox, by1 + bh1 - 1), lw)
        # 2단
        bw2 = int(17 * s)
        bh2 = max(1, int(7 * s))
        by2 = cy + int(10 * s)
        pygame.draw.rect(screen, ped, (cx - bw2 + feet_ox, by2, bw2 * 2, bh2))
        pygame.draw.line(screen, ped_hi, (cx - bw2 + feet_ox, by2), (cx + bw2 - 1 + feet_ox, by2), lw)
        # 3단 (대좌)
        bw3 = int(13 * s)
        bh3 = max(1, int(8 * s))
        by3 = cy + int(3 * s)
        pygame.draw.rect(screen, ped_hi, (cx - bw3 + feet_ox, by3, bw3 * 2, bh3))
        pygame.draw.line(screen, marble_mid, (cx - bw3 + feet_ox, by3), (cx + bw3 - 1 + feet_ox, by3), lw)
        # 금색 트림
        pygame.draw.line(screen, gold, (cx - int(15 * s) + feet_ox, cy + int(9 * s)),
                         (cx + int(14 * s) + feet_ox, cy + int(9 * s)), lw)
        pygame.draw.line(screen, bronze_hi, (cx - bw3 + feet_ox, cy + int(6 * s)),
                         (cx + bw3 - 1 + feet_ox, cy + int(6 * s)), lw)

        # ── 하체 토가 (곡선 드레이프, 발 흔들림) ──
        robe_pts = [
            (cx - int(10 * s) + feet_ox, cy + int(3 * s)),
            (cx + int(10 * s) + feet_ox, cy + int(3 * s)),
            (cx + int(8 * s) + feet_ox // 2, cy - int(3 * s)),
            (cx + int(7 * s), cy - int(7 * s)),
            (cx - int(7 * s), cy - int(7 * s)),
            (cx - int(8 * s) + feet_ox // 2, cy - int(3 * s)),
        ]
        pygame.draw.polygon(screen, marble, robe_pts)
        # 주름선 (곡선감)
        for fold_x in [-5, 0, 1, 5]:
            col = marble_dark if fold_x in [-5, 5] else marble_mid
            x1 = cx + int(fold_x * s) + feet_ox // 2
            x2 = cx + int((fold_x + 0.5) * s)
            pygame.draw.line(screen, col, (x1, cy + int(2 * s)), (x2, cy - int(6 * s)), lw)
        # 허리 벨트
        pygame.draw.line(screen, bronze, (cx - int(7 * s), cy - int(7 * s)),
                         (cx + int(7 * s), cy - int(7 * s)), max(1, int(1.5 * s)))
        pygame.draw.line(screen, bronze_hi, (cx - int(6 * s), cy - int(8 * s)),
                         (cx + int(6 * s), cy - int(8 * s)), lw)

        # ── 상체 (넓은 어깨, 근육) ──
        torso_pts = [
            (cx - int(7 * s), cy - int(8 * s)),
            (cx + int(7 * s), cy - int(8 * s)),
            (cx + int(11 * s), cy - int(16 * s)),
            (cx + int(10 * s), cy - int(19 * s)),
            (cx - int(10 * s), cy - int(19 * s)),
            (cx - int(11 * s), cy - int(16 * s)),
        ]
        pygame.draw.polygon(screen, marble, torso_pts)
        # 근육 라인
        pygame.draw.line(screen, marble_mid, (cx, cy - int(9 * s)), (cx, cy - int(17 * s)), lw)
        # 가슴 아치
        if s >= 2:
            pygame.draw.arc(screen, marble_mid,
                            (cx - int(5 * s), cy - int(16 * s), int(5 * s), int(4 * s)),
                            0.2, math.pi - 0.2, lw)
            pygame.draw.arc(screen, marble_mid,
                            (cx, cy - int(16 * s), int(5 * s), int(4 * s)),
                            0.2, math.pi - 0.2, lw)
        # 어깨 하이라이트
        pygame.draw.line(screen, marble_hi, (cx - int(10 * s), cy - int(19 * s)),
                         (cx + int(10 * s), cy - int(19 * s)), lw)
        # 토가 사선 드레이프
        pygame.draw.line(screen, marble_dark, (cx - int(10 * s), cy - int(18 * s)),
                         (cx + int(4 * s), cy - int(10 * s)), max(1, int(2 * s)))
        pygame.draw.line(screen, marble_mid, (cx - int(8 * s), cy - int(17 * s)),
                         (cx + int(5 * s), cy - int(9 * s)), lw)
        # 목
        nw = max(1, int(2.5 * s))
        pygame.draw.line(screen, marble, (cx - int(2 * s), cy - int(19 * s)),
                         (cx - int(2 * s), cy - int(22 * s)), nw)
        pygame.draw.line(screen, marble_hi, (cx + int(1 * s), cy - int(19 * s)),
                         (cx + int(1 * s), cy - int(22 * s)), nw)

        # ── 팔 ──
        self._draw_judgment_arms(screen, cx, cy, s, marble, marble_mid, marble_dark, gold, gold_light)

        # ── 머리 (고급 디테일) ──
        head_y = cy - int(25 * s)
        head_r = max(2, int(6 * s))
        # 머리 본체
        pygame.draw.circle(screen, marble, (cx, head_y), head_r)
        # 하이라이트 아크
        if head_r > 3:
            pygame.draw.arc(screen, marble_hi,
                            (cx - head_r + 1, head_y - head_r + 1, head_r * 2 - 2, head_r * 2 - 2),
                            0.4, 2.7, lw)
        # 눈 (스케일 ≥ 2일 때 디테일)
        if s >= 1.5:
            ey = head_y - int(1 * s)
            pygame.draw.line(screen, marble_dark, (cx - int(3 * s), ey), (cx - int(1 * s), ey), lw)
            pygame.draw.line(screen, marble_dark, (cx + int(1 * s), ey), (cx + int(3 * s), ey), lw)
            # 코
            pygame.draw.line(screen, marble_mid, (cx, ey), (cx, head_y + int(1 * s)), lw)
        # 수염 (풍성)
        br = int(4 * s)
        beard_pts = [
            (cx - br, head_y + int(3 * s)),
            (cx + br, head_y + int(3 * s)),
            (cx + int(2 * s), head_y + int(9 * s)),
            (cx, head_y + int(10 * s)),
            (cx - int(2 * s), head_y + int(9 * s)),
        ]
        pygame.draw.polygon(screen, marble_mid, beard_pts)
        # 수염 텍스처
        pygame.draw.line(screen, marble_dark, (cx - int(1 * s), head_y + int(4 * s)),
                         (cx - int(1 * s), head_y + int(8 * s)), lw)
        pygame.draw.line(screen, marble_dark, (cx + int(1 * s), head_y + int(4 * s)),
                         (cx + int(1 * s), head_y + int(8 * s)), lw)
        # 머리카락 (볼륨)
        hr = int(7 * s)
        pygame.draw.arc(screen, marble_dark,
                        (cx - hr, head_y - hr, hr * 2, int(10 * s)),
                        0.2, math.pi - 0.2, max(1, int(2 * s)))
        if s >= 2:
            pygame.draw.arc(screen, marble_shadow,
                            (cx - hr - lw, head_y - hr - lw, hr * 2 + lw * 2, int(11 * s)),
                            0.3, math.pi - 0.3, lw)

        # ── 월계관 (잎사귀 형태) ──
        wreath = (140, 145, 80)
        wreath_hi = (170, 175, 105)
        wr = int(8 * s)
        for angle_deg in range(-80, 81, 16):
            a = math.radians(angle_deg - 90)
            lx = cx + int(wr * math.cos(a))
            ly = head_y + int((wr - int(s)) * math.sin(a))
            # 잎사귀 (방향성 타원)
            leaf_a = a + math.pi / 2
            leaf_len = max(1, int(2.5 * s))
            dx_l, dy_l = int(leaf_len * math.cos(leaf_a)), int(leaf_len * math.sin(leaf_a))
            col = wreath_hi if angle_deg % 32 == 0 else wreath
            pygame.draw.line(screen, col, (lx - dx_l, ly - dy_l), (lx + dx_l, ly + dy_l), lw)
            pygame.draw.circle(screen, wreath_hi if angle_deg % 48 == 0 else wreath, (lx, ly), lw)

    def _draw_judgment_arms(self, screen, cx, cy, s, marble, marble_mid, marble_dark, gold, gold_light):
        """신의심판 석상의 팔 (상완+전완 2세그먼트, 애니메이션)"""
        upper_w = max(2, int(3.5 * s))
        fore_w = max(1, int(2.5 * s))
        upper_len = int(10 * s)
        fore_len = int(10 * s)
        lw = max(1, int(s))

        # 어깨 위치
        l_shoulder = (cx - int(11 * s), cy - int(17 * s))
        r_shoulder = (cx + int(11 * s), cy - int(17 * s))

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
