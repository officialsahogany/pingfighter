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

        # 색상 팔레트 - 고대 이집트/콜로세움 프리미엄 테마
        self.colors = {
            'sand': (155, 130, 95),           # 모래 바닥
            'sand_dark': (125, 105, 75),      # 어두운 모래
            'sand_light': (175, 150, 115),    # 밝은 모래
            'sand_warm': (165, 140, 105),     # 따뜻한 모래 (그라데이션용)
            'stone': (140, 130, 115),         # 석조
            'stone_dark': (100, 90, 80),      # 어두운 석조
            'stone_light': (170, 160, 145),   # 밝은 석조
            'gold': (212, 175, 85),           # 금색 장식
            'gold_light': (232, 200, 120),    # 밝은 금색
            'gold_dark': (170, 140, 60),      # 어두운 금색
            'line': (230, 210, 170),          # 라인 색상 (밝은 베이지)
            'line_glow': (255, 235, 190),     # 라인 글로우
            # 테두리
            'border_outer': (90, 70, 45),     # 테두리 외곽 (어두운 브론즈)
            'border_mid': (160, 130, 70),     # 테두리 중간 (금동)
            'border_inner': (200, 165, 80),   # 테두리 내부 (밝은 금)
            'border_stone': (130, 115, 90),   # 테두리 석조
            # 문양
            'hieroglyph': (175, 145, 80),     # 히에로글리프 (흐릿한 금)
            'hieroglyph_dark': (120, 95, 55), # 어두운 히에로글리프
            # 석상
            'face_stone': (170, 155, 135),    # 석상 얼굴 (밝은 대리석)
            'face_shadow': (120, 105, 85),    # 석상 그림자
            'face_dark': (90, 75, 60),        # 석상 깊은 그림자
            'face_highlight': (195, 180, 160),# 석상 하이라이트
            'eye_glow': (210, 180, 80),       # 석상 눈 금빛
            'center_ornate': (200, 175, 100), # 중앙 장식 금
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
        self.JUDGMENT_HOLE_FADE = 6   # 1.5초: 구멍이 부스러기로 사라짐
        self.JUDGMENT_BOLT_THROW = 7      # 0.6초: 번개 투척 모션
        self.JUDGMENT_BOLT_FLIGHT = 8     # 0.8초: 번개 투사체 비행
        self.JUDGMENT_BOLT_EXPLOSION = 9  # 1.5초: 감전 폭발

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
        self.judgment_cooldown = random.uniform(50.0, 100.0)  # 첫 발동 쿨타임
        self.judgment_enabled = False  # pingfighter.py에서 True로 설정
        self.judgment_merge_particles = []
        self.judgment_slam_debris = []
        self.judgment_dust_rain = []
        self.judgment_rise_debris = []       # 상승 시 떨어지는 흙/돌
        self.judgment_rise_offset = 0.0      # 석상 상승 오프셋 (양수=아래에 묻힘)
        self.judgment_quake_sound_playing = False
        self.judgment_hole_crumble = []      # 구멍 부스러기 파티클
        self.judgment_hole_fade_scale = 0.0  # 구멍 페이드 시 스케일 (RETURN 종료 시 설정)
        self.judgment_bolt_sparks = []       # 번개 스파크 파티클
        self.judgment_bolt_intensity = 0.0   # 번개 발광 강도 (0~1)
        # 번개의 분노 (Lightning variant) 상태
        self.judgment_variant = 'earthquake'  # 'earthquake' 또는 'lightning'
        self.judgment_bolt_hidden = False     # 던진 후 손에서 번개 숨김
        self.judgment_bolt_thrown = False
        self.judgment_bolt_proj_x = 0.0       # 투사체 현재 위치
        self.judgment_bolt_proj_y = 0.0
        self.judgment_bolt_proj_start_x = 0.0 # 투척 시작점 (손 위치)
        self.judgment_bolt_proj_start_y = 0.0
        self.judgment_bolt_proj_target_x = 0.0  # 착탄점
        self.judgment_bolt_proj_target_y = 0.0
        self.judgment_bolt_proj_angle = 0.0     # 투사체 회전 각도
        self.judgment_bolt_proj_trail = []      # 투사체 트레일 파티클
        self.judgment_explosion_x = 0.0
        self.judgment_explosion_y = 0.0
        self.judgment_explosion_radius = 0.0
        self.judgment_explosion_max_radius = 300.0
        self.judgment_explosion_sparks = []
        self.judgment_explosion_flash_alpha = 0
        self.judgment_explosion_ring_alpha = 0
        self.judgment_lightning_stun_top = False
        self.judgment_lightning_stun_bottom = False
        self.judgment_lightning_stun_timer = 0.0
        self.judgment_lightning_active = False
        self.judgment_logic_paused = False  # 라운드 전환 시 judgment 타이머 일시정지
        # 이벤트 플래그 (핸들러에서 consume 방식으로 사용)
        self.judgment_bolt_throw_started = False   # BOLT_THROW 진입 시 True → 핸들러가 읽고 False
        self.judgment_bolt_explosion_started = False  # BOLT_EXPLOSION 진입 시 True → 핸들러가 읽고 False

        # 페이즈 지속시간 (초)
        self.MERGE_DURATION = 2.0
        self.ARM_RAISE_DURATION = 2.0
        self.SLAM_DURATION = 0.5
        self.EARTHQUAKE_DURATION = 5.2
        self.RETURN_DURATION = 3.0
        self.HOLE_FADE_DURATION = 1.5
        self.BOLT_THROW_DURATION = 0.6
        self.BOLT_FLIGHT_DURATION = 0.8
        self.BOLT_EXPLOSION_DURATION = 1.5

        # 테두리 서피스
        self.border_surface = pygame.Surface((width, height), pygame.SRCALPHA)

        # 금빛 먼지 (프리미엄 분위기)
        self.golden_dust = []
        for _ in range(3):
            self.golden_dust.append({
                'x': random.randint(60, self.width - 60),
                'y': random.randint(120, self.height - 120),
                'vx': random.uniform(-0.15, 0.15),
                'vy': random.uniform(-0.08, 0.08),
                'size': random.uniform(1.5, 2.5),
                'alpha': random.randint(15, 35),
                'phase': random.uniform(0, math.pi * 2),
            })

        # 석상 눈 깜빡임
        self.face_eye_positions = []  # _prerender_border에서 채워짐
        self.eye_flicker_timer = 0.0
        self.eye_flicker_index = -1
        self.eye_flicker_cooldown = random.uniform(4.0, 7.0)

        # 프리렌더
        self._prerender_floor()
        self._prerender_arena()
        self._prerender_border()

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
            'x': random.randint(30, self.width - 30),
            'y': random.randint(100, self.height - 100),
            'vx': random.uniform(-0.2, 0.2),
            'vy': random.uniform(-0.1, 0.1),
            'size': random.uniform(1, 2.5),
            'alpha': random.randint(20, 50),
            'life': random.randint(150, 400)
        }

    def _prerender_floor(self):
        """바닥 프리렌더 - 고급 모래 아레나 (이집트 프리미엄)"""
        sand = self.colors['sand']
        sand_dark = self.colors['sand_dark']
        sand_warm = self.colors['sand_warm']

        # 전체를 모래 색상으로 채움
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

        # 방사형 비네트 (가장자리 어둡게)
        center_x = self.width // 2
        center_y = self.height // 2
        max_dist = math.sqrt((self.width / 2) ** 2 + (self.height / 2) ** 2)
        vignette_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        for ring in range(12):
            radius = int(max_dist * (1.0 - ring * 0.06))
            alpha = int(4 + ring * 2)
            pygame.draw.circle(vignette_surf, (40, 30, 20, alpha),
                             (center_x, center_y), radius)
        self.floor_surface.blit(vignette_surf, (0, 0))

        # 희미한 원형 투기장 마킹 (고대 경기장 흔적)
        arena_mark_color = (sand_dark[0] + 5, sand_dark[1] + 5, sand_dark[2] + 5)
        pygame.draw.circle(self.floor_surface, arena_mark_color,
                         (center_x, center_y), 280, 1)
        pygame.draw.circle(self.floor_surface, arena_mark_color,
                         (center_x, center_y), 278, 1)

        # 바람 무늬 (미세한 곡선) - 모래 위 바람 자국
        random.seed(77)  # 일관된 패턴
        for _ in range(25):
            sx = random.randint(30, self.width - 30)
            sy = random.randint(80, self.height - 80)
            wind_shade = random.randint(-6, 6)
            wind_color = (
                max(0, min(255, sand[0] + wind_shade)),
                max(0, min(255, sand[1] + wind_shade)),
                max(0, min(255, sand[2] + wind_shade))
            )
            # 짧은 곡선 (3점으로 근사)
            length = random.randint(40, 100)
            curve = random.uniform(-15, 15)
            mid_x = sx + length // 2
            mid_y = sy + int(curve)
            end_x = sx + length
            end_y = sy + random.randint(-5, 5)
            pygame.draw.line(self.floor_surface, wind_color, (sx, sy), (mid_x, mid_y), 1)
            pygame.draw.line(self.floor_surface, wind_color, (mid_x, mid_y), (end_x, end_y), 1)
        random.seed()

    def _prerender_arena(self):
        """경기장 라인 프리렌더 - 이집트 프리미엄 스타일 (중앙선, 중앙원, 코너)"""
        self.arena_surface.fill((0, 0, 0, 0))

        center_x = self.width // 2
        center_y = self.height // 2
        line_color = self.colors['line']
        gold = self.colors['gold']
        gold_light = self.colors['gold_light']
        gold_dark = self.colors['gold_dark']
        ornate = self.colors['center_ornate']
        hiero = self.colors['hieroglyph']

        line_left = 10
        line_right = self.width - 10

        # ===== 중앙선 =====
        # 메인 중앙선 (굵은 선)
        pygame.draw.line(self.arena_surface, line_color,
                        (line_left, center_y), (line_right, center_y), 3)
        # 이중선 장식
        pygame.draw.line(self.arena_surface, gold,
                        (line_left, center_y - 6), (line_right, center_y - 6), 1)
        pygame.draw.line(self.arena_surface, gold,
                        (line_left, center_y + 6), (line_right, center_y + 6), 1)

        # 중앙선 위 장식 점 (60px 간격)
        for dot_x in range(line_left + 30, line_right - 30, 60):
            # 중앙원 영역(center_x ± 90) 내부는 건너뛰기
            if abs(dot_x - center_x) < 90:
                continue
            pygame.draw.circle(self.arena_surface, gold, (dot_x, center_y), 2)
            # 위아래 이중선에도 작은 점
            pygame.draw.circle(self.arena_surface, hiero, (dot_x, center_y - 6), 1)
            pygame.draw.circle(self.arena_surface, hiero, (dot_x, center_y + 6), 1)

        # 중앙선 양 끝 로터스 문양 (간략한 부채꼴)
        for end_x, direction in [(line_left + 5, 1), (line_right - 5, -1)]:
            # 작은 부채꼴 모양 (3잎)
            for angle_offset in [-25, 0, 25]:
                a = math.radians(90 + angle_offset * direction)
                lx = end_x + int(6 * math.cos(a))
                ly = center_y - int(6 * math.sin(a))
                pygame.draw.line(self.arena_surface, ornate,
                                (end_x, center_y), (lx, ly), 1)
            pygame.draw.circle(self.arena_surface, gold, (end_x, center_y), 2)

        # ===== 중앙원 (3중 링) =====
        # 외곽 큰 원
        pygame.draw.circle(self.arena_surface, line_color, (center_x, center_y), 85, 3)
        # 중간 장식 링
        pygame.draw.circle(self.arena_surface, ornate, (center_x, center_y), 68, 1)
        # 내부 작은 원
        pygame.draw.circle(self.arena_surface, gold, (center_x, center_y), 50, 2)

        # 외곽원 4방향 다이아몬드 (N/S/E/W)
        diamond_size = 4
        for angle_deg in [0, 90, 180, 270]:
            a = math.radians(angle_deg)
            dx = center_x + int(85 * math.cos(a))
            dy = center_y + int(85 * math.sin(a))
            diamond_pts = [
                (dx, dy - diamond_size),
                (dx + diamond_size, dy),
                (dx, dy + diamond_size),
                (dx - diamond_size, dy),
            ]
            pygame.draw.polygon(self.arena_surface, gold_light, diamond_pts)
            pygame.draw.polygon(self.arena_surface, gold_dark, diamond_pts, 1)

        # 외곽원 8방향 눈금 (45도 간격)
        for angle_deg in range(0, 360, 45):
            a = math.radians(angle_deg)
            inner_r = 82
            outer_r = 88
            x1 = center_x + int(inner_r * math.cos(a))
            y1 = center_y + int(inner_r * math.sin(a))
            x2 = center_x + int(outer_r * math.cos(a))
            y2 = center_y + int(outer_r * math.sin(a))
            pygame.draw.line(self.arena_surface, gold, (x1, y1), (x2, y2), 1)

        # ===== 코너 L자 장식 (방향 수정) =====
        corner_size = 28
        margin = 5
        border_y_top = 5
        border_y_bot = self.height - 5

        # 좌상: → ↓ (안쪽을 향함)
        tl_x, tl_y = margin, border_y_top
        pygame.draw.line(self.arena_surface, gold, (tl_x, tl_y), (tl_x + corner_size, tl_y), 2)
        pygame.draw.line(self.arena_surface, gold, (tl_x, tl_y), (tl_x, tl_y + corner_size), 2)
        pygame.draw.line(self.arena_surface, gold_dark, (tl_x + 3, tl_y + 3), (tl_x + corner_size - 3, tl_y + 3), 1)
        pygame.draw.line(self.arena_surface, gold_dark, (tl_x + 3, tl_y + 3), (tl_x + 3, tl_y + corner_size - 3), 1)

        # 우상: ← ↓ (안쪽을 향함)
        tr_x, tr_y = self.width - margin, border_y_top
        pygame.draw.line(self.arena_surface, gold, (tr_x, tr_y), (tr_x - corner_size, tr_y), 2)
        pygame.draw.line(self.arena_surface, gold, (tr_x, tr_y), (tr_x, tr_y + corner_size), 2)
        pygame.draw.line(self.arena_surface, gold_dark, (tr_x - 3, tr_y + 3), (tr_x - corner_size + 3, tr_y + 3), 1)
        pygame.draw.line(self.arena_surface, gold_dark, (tr_x - 3, tr_y + 3), (tr_x - 3, tr_y + corner_size - 3), 1)

        # 좌하: → ↑ (안쪽을 향함)
        bl_x, bl_y = margin, border_y_bot
        pygame.draw.line(self.arena_surface, gold, (bl_x, bl_y), (bl_x + corner_size, bl_y), 2)
        pygame.draw.line(self.arena_surface, gold, (bl_x, bl_y), (bl_x, bl_y - corner_size), 2)
        pygame.draw.line(self.arena_surface, gold_dark, (bl_x + 3, bl_y - 3), (bl_x + corner_size - 3, bl_y - 3), 1)
        pygame.draw.line(self.arena_surface, gold_dark, (bl_x + 3, bl_y - 3), (bl_x + 3, bl_y - corner_size + 3), 1)

        # 우하: ← ↑ (안쪽을 향함)
        br_x, br_y = self.width - margin, border_y_bot
        pygame.draw.line(self.arena_surface, gold, (br_x, br_y), (br_x - corner_size, br_y), 2)
        pygame.draw.line(self.arena_surface, gold, (br_x, br_y), (br_x, br_y - corner_size), 2)
        pygame.draw.line(self.arena_surface, gold_dark, (br_x - 3, br_y - 3), (br_x - corner_size + 3, br_y - 3), 1)
        pygame.draw.line(self.arena_surface, gold_dark, (br_x - 3, br_y - 3), (br_x - 3, br_y - corner_size + 3), 1)

    def _prerender_border(self):
        """인게임 장식 테두리 프리렌더 - 이집트 프리미엄 스타일"""
        self.border_surface.fill((0, 0, 0, 0))
        surf = self.border_surface

        border_outer = self.colors['border_outer']
        border_mid = self.colors['border_mid']
        border_inner = self.colors['border_inner']
        border_stone = self.colors['border_stone']
        hiero = self.colors['hieroglyph']
        hiero_dark = self.colors['hieroglyph_dark']
        gold = self.colors['gold']
        gold_dark = self.colors['gold_dark']

        # 테두리 영역 (전체 서피스 너비 사용 - 필러가 양쪽을 자연스럽게 가림)
        bx = 0
        by = 0
        bw = self.width   # 760
        bh = self.height
        br = bx + bw   # 오른쪽 끝
        bb = by + bh    # 아래쪽 끝

        # ===== 1. 다층 테두리 프레임 =====
        # 외곽 그림자 (가장 바깥)
        pygame.draw.rect(surf, border_outer, (bx - 2, by - 2, bw + 4, bh + 4), 2)
        # 금동 밴드 (메인 프레임)
        pygame.draw.rect(surf, border_mid, (bx, by, bw, bh), 3)
        # 밝은 금 내부선
        pygame.draw.rect(surf, border_inner, (bx + 4, by + 4, bw - 8, bh - 8), 1)
        # 석조 내부선 (가장 안쪽)
        pygame.draw.rect(surf, border_stone, (bx + 6, by + 6, bw - 12, bh - 12), 1)

        # ===== 2. 이집트 문양 패턴 (테두리 밴드 위) =====
        pattern_spacing = 36

        # 상단 변
        for px in range(bx + 25, br - 25, pattern_spacing):
            # 로터스 꽃잎 (위로 3잎)
            for leaf_angle in [-30, 0, 30]:
                a = math.radians(leaf_angle - 90)
                lx = px + int(4 * math.cos(a))
                ly = by + 1 + int(4 * math.sin(a))
                pygame.draw.line(surf, hiero, (px, by + 1), (lx, ly), 1)
            pygame.draw.circle(surf, hiero_dark, (px, by + 1), 1)
            # 로터스 사이 점선
            if px + pattern_spacing // 2 < br - 25:
                for dot in range(4):
                    dx = px + pattern_spacing // 2 - 6 + dot * 4
                    pygame.draw.circle(surf, hiero_dark, (dx, by + 1), 0)

        # 하단 변
        for px in range(bx + 25, br - 25, pattern_spacing):
            for leaf_angle in [-30, 0, 30]:
                a = math.radians(leaf_angle + 90)
                lx = px + int(4 * math.cos(a))
                ly = bb - 1 + int(4 * math.sin(a))
                pygame.draw.line(surf, hiero, (px, bb - 1), (lx, ly), 1)
            pygame.draw.circle(surf, hiero_dark, (px, bb - 1), 1)
            if px + pattern_spacing // 2 < br - 25:
                for dot in range(4):
                    dx = px + pattern_spacing // 2 - 6 + dot * 4
                    pygame.draw.circle(surf, hiero_dark, (dx, bb - 1), 0)

        # 좌측 변
        for py in range(by + 25, bb - 25, pattern_spacing):
            for leaf_angle in [-30, 0, 30]:
                a = math.radians(leaf_angle)
                lx = bx + 1 + int(4 * math.cos(a))
                ly = py + int(4 * math.sin(a))
                pygame.draw.line(surf, hiero, (bx + 1, py), (lx, ly), 1)
            pygame.draw.circle(surf, hiero_dark, (bx + 1, py), 1)

        # 우측 변
        for py in range(by + 25, bb - 25, pattern_spacing):
            for leaf_angle in [-30, 0, 30]:
                a = math.radians(leaf_angle + 180)
                lx = br - 1 + int(4 * math.cos(a))
                ly = py + int(4 * math.sin(a))
                pygame.draw.line(surf, hiero, (br - 1, py), (lx, ly), 1)
            pygame.draw.circle(surf, hiero_dark, (br - 1, py), 1)

        # ===== 3. 코너 꼭지점 장식 (이중 직각 + 다이아몬드) =====
        corner_arm = 18
        corners_data = [
            (bx, by, 1, 1),       # 좌상
            (br, by, -1, 1),      # 우상
            (bx, bb, 1, -1),      # 좌하
            (br, bb, -1, -1),     # 우하
        ]
        for cx, cy, hd, vd in corners_data:
            # 외곽 직각선
            pygame.draw.line(surf, gold, (cx, cy), (cx + corner_arm * hd, cy), 2)
            pygame.draw.line(surf, gold, (cx, cy), (cx, cy + corner_arm * vd), 2)
            # 내부 직각선
            pygame.draw.line(surf, gold_dark,
                           (cx + 4 * hd, cy + 4 * vd),
                           (cx + (corner_arm - 4) * hd, cy + 4 * vd), 1)
            pygame.draw.line(surf, gold_dark,
                           (cx + 4 * hd, cy + 4 * vd),
                           (cx + 4 * hd, cy + (corner_arm - 4) * vd), 1)
            # 꼭지점 다이아몬드
            d = 3
            diamond = [
                (cx, cy - d * vd),
                (cx + d * hd, cy),
                (cx, cy + d * vd),
                (cx - d * hd, cy),
            ]
            pygame.draw.polygon(surf, self.colors['gold_light'], diamond)
            pygame.draw.polygon(surf, gold_dark, diamond, 1)

        # (석상 얼굴은 pillar_colosseum.py에서 필러 바깥쪽에 그림)

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
                particle['x'] < 20 or particle['x'] > self.width - 20 or
                particle['y'] < 70 or particle['y'] > self.height - 70):
                self.dust_particles[i] = self._create_dust_particle()

        # 금빛 먼지 업데이트
        for gd in self.golden_dust:
            gd['x'] += gd['vx']
            gd['y'] += gd['vy']
            # 영역 벗어나면 반대쪽에서 재생성
            if gd['x'] < 50 or gd['x'] > self.width - 50:
                gd['x'] = random.randint(60, self.width - 60)
                gd['vx'] = random.uniform(-0.15, 0.15)
            if gd['y'] < 100 or gd['y'] > self.height - 100:
                gd['y'] = random.randint(120, self.height - 120)
                gd['vy'] = random.uniform(-0.08, 0.08)

        # 석상 눈 깜빡임 업데이트
        self.eye_flicker_cooldown -= dt
        if self.eye_flicker_cooldown <= 0:
            self.eye_flicker_index = random.randint(0, 3)
            self.eye_flicker_timer = 0.0
            self.eye_flicker_cooldown = random.uniform(4.0, 7.0)
        if self.eye_flicker_index >= 0:
            self.eye_flicker_timer += dt
            if self.eye_flicker_timer > 0.5:
                self.eye_flicker_index = -1

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
        self.judgment_bolt_sparks = []
        self.judgment_bolt_intensity = 0.0
        # 번개의 분노 상태 초기화
        self.judgment_variant = random.choice(['earthquake', 'lightning'])
        print(f"[신의심판] 변형 선택: {self.judgment_variant}")
        self.judgment_bolt_hidden = False
        self.judgment_bolt_thrown = False
        self.judgment_bolt_proj_trail = []
        self.judgment_explosion_sparks = []
        self.judgment_lightning_stun_top = False
        self.judgment_lightning_stun_bottom = False
        self.judgment_lightning_stun_timer = 0.0
        self.judgment_lightning_active = False
        self.judgment_bolt_throw_started = False
        self.judgment_bolt_explosion_started = False
        # 합체 파티클 (심플한 대리석 먼지)
        cx = self.width // 2
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
            if self.judgment_enabled and not self.judgment_logic_paused:
                self.judgment_cooldown -= dt
                if self.judgment_cooldown <= 0:
                    self.trigger_gods_judgment()
            return

        # 라운드 전환 중에는 페이즈 타이머 동결 (애니메이션 일시정지)
        if self.judgment_logic_paused:
            return

        self.judgment_timer += dt
        cx = self.width // 2
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
            # ── 번개 충전 이펙트 (팔 다 올린 후 70%부터만 발동) ──
            s = self.judgment_scale
            if progress > 0.7:
                # 70~100% 구간을 0~1로 재매핑
                charge_p = (progress - 0.7) / 0.3
                base_intensity = charge_p * 0.7
                flash_freq = 6.0 + charge_p * 14.0  # 6Hz → 20Hz
                flash_wave = max(0, math.sin(self.judgment_timer * flash_freq * math.pi))
                flash_boost = flash_wave * charge_p * 0.3
                self.judgment_bolt_intensity = min(1.0, base_intensity + flash_boost)
                # 스파크 파티클 생성
                r_shoulder_x = cx + int(10 * s)
                r_shoulder_y = cy - int(19 * s)
                spark_rate = int(charge_p * 3) + (1 if random.random() < charge_p * 0.5 else 0)
                for _ in range(spark_rate):
                    spark_cx = r_shoulder_x + random.uniform(-15 * s, 5 * s)
                    spark_cy = r_shoulder_y + random.uniform(-20 * s, -5 * s)
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(1.5, 5.0) * s
                    self.judgment_bolt_sparks.append({
                        'x': spark_cx,
                        'y': spark_cy,
                        'vx': math.cos(angle) * speed,
                        'vy': math.sin(angle) * speed,
                        'size': random.uniform(1.0, 2.5) * s * 0.4,
                        'life': random.uniform(0.2, 0.6),
                        'color': random.choice([
                            (255, 240, 140), (255, 220, 80),
                            (255, 255, 200), (220, 200, 60),
                        ]),
                    })
            else:
                self.judgment_bolt_intensity = 0.0
            # 스파크 파티클 업데이트
            for sp in self.judgment_bolt_sparks:
                sp['x'] += sp['vx'] * dt * 60
                sp['y'] += sp['vy'] * dt * 60
                sp['life'] -= dt
                sp['size'] = max(0, sp['size'] - dt * 2)
            self.judgment_bolt_sparks = [sp for sp in self.judgment_bolt_sparks if sp['life'] > 0]
            if progress >= 1.0:
                if self.judgment_variant == 'lightning':
                    # 번개의 분노: 투척 페이즈로
                    self.judgment_phase = self.JUDGMENT_BOLT_THROW
                    self.judgment_timer = 0.0
                    self.judgment_bolt_intensity = 1.0
                    self.judgment_bolt_throw_started = True  # 핸들러에서 텍스트 표시용
                    print(f"[신의심판] ARM_RAISE → BOLT_THROW 전환")
                    # 오른손 위치 계산 (투사체 시작점)
                    s = self.judgment_scale
                    r_sh_x = cx + int(10 * s)
                    r_sh_y = cy - int(19 * s)
                    ul = int(10 * s)
                    fl = int(10 * s)
                    ra_ang = math.radians(-80)
                    ra_eb = -0.5
                    r_elb = (r_sh_x + int(ul * math.sin(ra_ang)),
                             r_sh_y + int(ul * math.cos(ra_ang)))
                    fa_r = ra_ang + ra_eb
                    r_hand = (r_elb[0] + int(fl * math.sin(fa_r)),
                              r_elb[1] + int(fl * math.cos(fa_r)))
                    self.judgment_bolt_proj_start_x = float(r_hand[0])
                    self.judgment_bolt_proj_start_y = float(r_hand[1])
                    self.judgment_bolt_proj_x = self.judgment_bolt_proj_start_x
                    self.judgment_bolt_proj_y = self.judgment_bolt_proj_start_y
                    # 착탄점: 상단 또는 하단 끝 (X는 게임영역 내 랜덤)
                    target_x = random.uniform(60, self.width - 60)
                    if random.random() < 0.5:
                        target_y = 25.0     # 상단 끝 (보스 패들 라인)
                    else:
                        target_y = 720.0    # 하단 끝 (플레이어 패들 라인)
                    self.judgment_bolt_proj_target_x = target_x
                    self.judgment_bolt_proj_target_y = target_y
                else:
                    # 땅의 분노: 기존 슬램
                    self.judgment_phase = self.JUDGMENT_SLAM
                    self.judgment_timer = 0.0
                    self.judgment_bolt_intensity = 1.0

        elif self.judgment_phase == self.JUDGMENT_SLAM:
            # 0.5초간 내려치기
            progress = min(1.0, self.judgment_timer / self.SLAM_DURATION)
            ease = progress ** 2  # ease-in (빠르게 내려침)
            self.judgment_slam_progress = ease
            self.judgment_left_arm_progress = 1.0 - ease
            self.judgment_right_arm_progress = 1.0 - ease
            self.judgment_feet_swing = 0
            # 번개 강도 빠르게 감소 (에너지 방출)
            self.judgment_bolt_intensity = max(0, 1.0 - progress * 2.0)
            # 스파크 파티클 업데이트 (잔여)
            for sp in self.judgment_bolt_sparks:
                sp['x'] += sp['vx'] * dt * 60
                sp['y'] += sp['vy'] * dt * 60
                sp['life'] -= dt * 2  # 빠르게 소멸
            self.judgment_bolt_sparks = [sp for sp in self.judgment_bolt_sparks if sp['life'] > 0]
            # 충격 플래시 (내려치는 순간)
            if progress > 0.8:
                self.judgment_flash_alpha = int(180 * ((progress - 0.8) / 0.2))
            if progress >= 1.0:
                self.judgment_phase = self.JUDGMENT_EARTHQUAKE
                self.judgment_timer = 0.0
                self.judgment_flash_alpha = 180
                self.judgment_shake_intensity = 1.0
                self.judgment_bolt_intensity = 0.0
                self.judgment_bolt_sparks.clear()
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
                    'x': random.uniform(10, self.width - 10),
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

        elif self.judgment_phase == self.JUDGMENT_BOLT_THROW:
            # 0.6초: 오른팔 투척 모션
            progress = min(1.0, self.judgment_timer / self.BOLT_THROW_DURATION)
            # 팔 애니메이션: 와인드업 → 투척
            if progress < 0.4:
                # 와인드업: 팔 살짝 더 뒤로
                wind_p = progress / 0.4
                self.judgment_right_arm_progress = 1.0 + wind_p * 0.15
                self.judgment_left_arm_progress = 1.0
            else:
                # 투척: 팔 앞으로 스윙
                throw_p = (progress - 0.4) / 0.6
                self.judgment_right_arm_progress = 1.15 - throw_p * 1.7
                self.judgment_left_arm_progress = max(0, 1.0 - throw_p * 1.5)
            # 40% 시점에서 번개 분리 (실제 팔 위치에서 번개 끝 계산)
            if progress >= 0.4 and not self.judgment_bolt_thrown:
                self.judgment_bolt_thrown = True
                self.judgment_bolt_hidden = True
                # 현재 팔 각도로 번개 끝(tip) 위치 계산
                s = self.judgment_scale
                r_sh_x = cx + int(10 * s)
                r_sh_y = cy - int(19 * s)
                ul = int(10 * s)
                fl = int(10 * s)
                ra_base = math.radians(-60)
                ra_raised = math.radians(-80)
                ra_ang = ra_base + (ra_raised - ra_base) * self.judgment_right_arm_progress
                ra_eb = -0.5
                r_elb = (r_sh_x + int(ul * math.sin(ra_ang)),
                         r_sh_y + int(ul * math.cos(ra_ang)))
                fa_r = ra_ang + ra_eb
                r_hand = (r_elb[0] + int(fl * math.sin(fa_r)),
                          r_elb[1] + int(fl * math.cos(fa_r)))
                # 번개 끝점 (손에서 전완 방향으로 bolt_len만큼 연장)
                bolt_len = int(18 * s)
                bdir_x = math.sin(fa_r)
                bdir_y = math.cos(fa_r)
                tip_x = r_hand[0] + bolt_len * bdir_x
                tip_y = r_hand[1] + bolt_len * bdir_y
                # 투사체 시작점 = 번개 끝, 각도 = 전완 방향
                self.judgment_bolt_proj_start_x = float(tip_x)
                self.judgment_bolt_proj_start_y = float(tip_y)
                self.judgment_bolt_proj_x = float(tip_x)
                self.judgment_bolt_proj_y = float(tip_y)
                self.judgment_bolt_proj_angle = math.degrees(fa_r)
            # 번개 강도 감소
            if self.judgment_bolt_thrown:
                self.judgment_bolt_intensity = max(0, 1.0 - (progress - 0.4) * 2.5)
            else:
                self.judgment_bolt_intensity = 1.0
            # 기존 스파크 정리
            for sp in self.judgment_bolt_sparks:
                sp['x'] += sp['vx'] * dt * 60
                sp['y'] += sp['vy'] * dt * 60
                sp['life'] -= dt
            self.judgment_bolt_sparks = [sp for sp in self.judgment_bolt_sparks if sp['life'] > 0]
            if progress >= 1.0:
                self.judgment_phase = self.JUDGMENT_BOLT_FLIGHT
                self.judgment_timer = 0.0
                self.judgment_bolt_intensity = 0.0
                self.judgment_bolt_sparks.clear()
                print(f"[신의심판] BOLT_THROW → BOLT_FLIGHT 전환 (시작:{self.judgment_bolt_proj_start_x:.0f},{self.judgment_bolt_proj_start_y:.0f} → 목표:{self.judgment_bolt_proj_target_x:.0f},{self.judgment_bolt_proj_target_y:.0f})")

        elif self.judgment_phase == self.JUDGMENT_BOLT_FLIGHT:
            # 0.8초: 번개 투사체 직선 비행 (창 던지기)
            progress = min(1.0, self.judgment_timer / self.BOLT_FLIGHT_DURATION)
            # ease-in: 빠르게 가속 (창 던지기 느낌)
            ease = progress * progress * (3.0 - 2.0 * progress)  # smoothstep
            # 직선 비행 (아크 없음)
            sx, sy = self.judgment_bolt_proj_start_x, self.judgment_bolt_proj_start_y
            tx, ty = self.judgment_bolt_proj_target_x, self.judgment_bolt_proj_target_y
            self.judgment_bolt_proj_x = sx + (tx - sx) * ease
            self.judgment_bolt_proj_y = sy + (ty - sy) * ease
            # 번개 방향: 진행 방향 고정 (창처럼 일직선)
            dx = tx - sx
            dy = ty - sy
            self.judgment_bolt_proj_angle = math.degrees(math.atan2(dx, dy))
            # 트레일 파티클
            if random.random() < 0.7:
                self.judgment_bolt_proj_trail.append({
                    'x': self.judgment_bolt_proj_x + random.uniform(-4, 4),
                    'y': self.judgment_bolt_proj_y + random.uniform(-4, 4),
                    'vx': random.uniform(-1, 1),
                    'vy': random.uniform(-1, 1),
                    'size': random.uniform(1.5, 3.5),
                    'life': random.uniform(0.15, 0.4),
                    'color': random.choice([
                        (255, 240, 140), (255, 220, 80),
                        (230, 200, 110), (212, 175, 85),
                    ]),
                })
            for p in self.judgment_bolt_proj_trail:
                p['x'] += p['vx'] * dt * 60
                p['y'] += p['vy'] * dt * 60
                p['life'] -= dt
                p['size'] = max(0, p['size'] - dt * 5)
            self.judgment_bolt_proj_trail = [p for p in self.judgment_bolt_proj_trail if p['life'] > 0]
            # 팔 원위치
            arm_fold = min(1.0, progress * 2.0)
            self.judgment_left_arm_progress = 0.0
            self.judgment_right_arm_progress = max(0, -0.5 + arm_fold * 0.5)
            if progress >= 1.0:
                self.judgment_phase = self.JUDGMENT_BOLT_EXPLOSION
                self.judgment_timer = 0.0
                self.judgment_explosion_x = self.judgment_bolt_proj_target_x
                self.judgment_explosion_y = self.judgment_bolt_proj_target_y
                self.judgment_explosion_radius = 0.0
                self.judgment_explosion_flash_alpha = 255
                self.judgment_explosion_ring_alpha = 255
                self.judgment_bolt_proj_trail.clear()
                self.judgment_lightning_active = True
                self.judgment_shake_intensity = 0.5
                self.judgment_bolt_explosion_started = True  # 핸들러에서 스턴 판정용
                print(f"[신의심판] BOLT_FLIGHT → BOLT_EXPLOSION 전환 (폭발 위치:{self.judgment_explosion_x:.0f},{self.judgment_explosion_y:.0f})")

        elif self.judgment_phase == self.JUDGMENT_BOLT_EXPLOSION:
            # 1.5초: 감전 폭발 (반경 0→300px 확장)
            progress = min(1.0, self.judgment_timer / self.BOLT_EXPLOSION_DURATION)
            ease = 1.0 - (1.0 - progress) ** 3
            self.judgment_explosion_radius = self.judgment_explosion_max_radius * ease
            # 플래시 빠르게 감소
            self.judgment_explosion_flash_alpha = max(0, int(255 * (1.0 - progress * 4)))
            self.judgment_explosion_ring_alpha = max(0, int(255 * (1.0 - progress)))
            # 화면 흔들림 감소
            if progress < 0.5:
                self.judgment_shake_intensity = 0.5 * (1.0 - progress * 2)
            else:
                self.judgment_shake_intensity = 0.0
            # 전기 아크 스파크 생성
            if progress < 0.8:
                ex, ey = self.judgment_explosion_x, self.judgment_explosion_y
                r = max(1, self.judgment_explosion_radius)
                for _ in range(3):
                    angle = random.uniform(0, math.pi * 2)
                    dist = random.uniform(0, r)
                    self.judgment_explosion_sparks.append({
                        'x': ex + math.cos(angle) * dist,
                        'y': ey + math.sin(angle) * dist,
                        'vx': math.cos(angle) * random.uniform(1, 4),
                        'vy': math.sin(angle) * random.uniform(1, 4),
                        'size': random.uniform(1, 3),
                        'life': random.uniform(0.2, 0.5),
                        'color': random.choice([
                            (255, 240, 140), (255, 220, 80), (255, 255, 200),
                            (230, 200, 110), (212, 175, 85),
                        ]),
                    })
            for sp in self.judgment_explosion_sparks:
                sp['x'] += sp['vx'] * dt * 60
                sp['y'] += sp['vy'] * dt * 60
                sp['life'] -= dt
            self.judgment_explosion_sparks = [sp for sp in self.judgment_explosion_sparks if sp['life'] > 0]
            # 스턴 타이머
            if self.judgment_lightning_stun_timer > 0:
                self.judgment_lightning_stun_timer -= dt
            if progress >= 1.0:
                self.judgment_phase = self.JUDGMENT_RETURN
                self.judgment_timer = 0.0
                self.judgment_shake_intensity = 0.0
                self.judgment_explosion_sparks.clear()
                self.judgment_lightning_active = False
                self.judgment_slam_progress = 0.0
                self.judgment_left_arm_progress = 0.0
                self.judgment_right_arm_progress = 0.0
                print(f"[신의심판] BOLT_EXPLOSION → RETURN 전환")

        elif self.judgment_phase == self.JUDGMENT_RETURN:
            # 3초간 땅속으로 다시 들어감 (무게감 있게)
            progress = min(1.0, self.judgment_timer / self.RETURN_DURATION)
            # 커스텀 이징: 초반 빠르게 빨려들어가다 중반 잠깐 멈칫, 후반 천천히 가라앉기
            if progress < 0.15:
                # 0~15%: 초반 흡입 (ease-out cubic, 빠르게 시작)
                local_p = progress / 0.15
                ease = 0.35 * (1.0 - (1.0 - local_p) ** 3)
            elif progress < 0.5:
                # 15~50%: 중속 하강 (linear)
                local_p = (progress - 0.15) / 0.35
                ease = 0.35 + 0.35 * local_p
            else:
                # 50~100%: 느리게 가라앉기 (ease-out quad)
                local_p = (progress - 0.5) / 0.5
                ease = 0.7 + 0.3 * (1.0 - (1.0 - local_p) ** 2)
            # 스케일 점진적 축소 (4x → 3.6x, 멀어지는 느낌)
            scale_shrink = 1.0 - 0.1 * ease
            self.judgment_scale = self.judgment_target_scale * scale_shrink
            s = self.judgment_scale
            # 석상 하강 (0 → 120px 아래로)
            sink_depth = 120.0 * self.judgment_target_scale
            self.judgment_rise_offset = sink_depth * ease
            # 팔 원래 위치로 (하강 초반에 빠르게)
            arm_fold = min(1.0, progress * 2.5)
            self.judgment_slam_progress = 1.0 - arm_fold
            self.judgment_left_arm_progress = 0.0
            self.judgment_right_arm_progress = 0.0
            # 초반 미세 흔들림 (무게감)
            if progress < 0.3:
                shake_p = 1.0 - progress / 0.3
                self.judgment_shake_intensity = 0.15 * shake_p
            else:
                self.judgment_shake_intensity = 0.0
            # 하강 중 흙/돌 파편 생성 (상승보다 더 많이)
            ground_y = cy + 10
            # 진행도에 따른 파편량 (초반 많고 후반 줄어듦)
            debris_rate = max(0, 3 - int(progress * 4))  # 3→2→1→0개
            for _ in range(debris_rate):
                self.judgment_rise_debris.append({
                    'x': cx + random.uniform(-14 * s, 14 * s),
                    'y': ground_y + random.uniform(-3, 2),
                    'vx': random.uniform(-2.0, 2.0),
                    'vy': random.uniform(0.3, 2.5),
                    'size': random.randint(1, 3),
                    'life': random.uniform(0.4, 1.0),
                    'color': random.choice([
                        (155, 130, 95), (125, 105, 75),
                        (130, 120, 108), (160, 150, 135)
                    ]),
                })
            # 큰 흙덩이 (초반에만, 무게에 의해 밀려나는 느낌)
            if progress < 0.4 and random.random() < 0.15:
                side = random.choice([-1, 1])
                self.judgment_rise_debris.append({
                    'x': cx + side * random.uniform(8 * s, 16 * s),
                    'y': ground_y + random.uniform(-2, 1),
                    'vx': side * random.uniform(1.5, 3.5),
                    'vy': random.uniform(-1.5, 0.5),
                    'size': random.randint(3, 5),
                    'life': random.uniform(0.8, 1.5),
                    'color': random.choice([
                        (125, 105, 75), (105, 85, 60)
                    ]),
                })
            # 구멍 안으로 빨려드는 먼지 파티클 (중반 이후)
            if progress > 0.2 and random.random() < 0.25:
                angle = random.uniform(0, math.pi * 2)
                dist = random.uniform(16, 28) * s
                self.judgment_rise_debris.append({
                    'x': cx + math.cos(angle) * dist,
                    'y': ground_y + math.sin(angle) * dist * 0.3,
                    'vx': -math.cos(angle) * random.uniform(0.8, 2.0),
                    'vy': random.uniform(0.2, 1.0),
                    'size': random.randint(1, 2),
                    'life': random.uniform(0.3, 0.7),
                    'color': (180, 160, 130),
                })
            # 하강 파편 업데이트
            for d in self.judgment_rise_debris:
                d['x'] += d['vx'] * dt * 60
                d['y'] += d['vy'] * dt * 60
                d['vy'] += 4 * dt
                d['life'] -= dt
            self.judgment_rise_debris = [d for d in self.judgment_rise_debris if d['life'] > 0]
            if progress >= 1.0:
                # 구멍 페이드 페이즈로 전환 (석상은 사라지고 구멍만 남음)
                self.judgment_phase = self.JUDGMENT_HOLE_FADE
                self.judgment_timer = 0.0
                self.judgment_hole_fade_scale = self.judgment_target_scale  # 원래 스케일 기준
                self.judgment_slam_progress = 0.0
                self.judgment_rise_offset = 0.0
                self.judgment_shake_intensity = 0.0
                self.judgment_scale = self.judgment_target_scale  # 스케일 복원
                self.judgment_rise_debris.clear()
                # 초기 부스러기 파티클 생성 (구멍 테두리에서)
                ground_y = cy + 10
                for _ in range(15):
                    angle = random.uniform(0, math.pi * 2)
                    dist = random.uniform(6, 14) * self.judgment_scale
                    self.judgment_hole_crumble.append({
                        'x': cx + math.cos(angle) * dist,
                        'y': ground_y + math.sin(angle) * dist * 0.4,
                        'vx': math.cos(angle) * random.uniform(0.3, 1.2),
                        'vy': random.uniform(-0.5, 1.5),
                        'size': random.uniform(1.5, 3.0),
                        'life': random.uniform(0.8, 1.5),
                        'color': random.choice([
                            (155, 130, 95), (125, 105, 75),
                            (175, 150, 115), (105, 85, 60)
                        ]),
                    })

        elif self.judgment_phase == self.JUDGMENT_HOLE_FADE:
            # 1.5초간 구멍이 부스러기로 사라짐
            progress = min(1.0, self.judgment_timer / self.HOLE_FADE_DURATION)
            # 부스러기 파티클 업데이트
            for d in self.judgment_hole_crumble:
                d['x'] += d['vx'] * dt * 60
                d['y'] += d['vy'] * dt * 60
                d['vy'] += 2 * dt  # 약한 중력
                d['life'] -= dt
                d['size'] = max(0, d['size'] - dt * 1.5)  # 점점 작아짐
            self.judgment_hole_crumble = [d for d in self.judgment_hole_crumble if d['life'] > 0]
            # 추가 부스러기 생성 (페이드 중반까지)
            if progress < 0.6 and random.random() < 0.4:
                ground_y = cy + 10
                fade_s = self.judgment_hole_fade_scale * (1.0 - progress)
                angle = random.uniform(0, math.pi * 2)
                dist = random.uniform(4, 10) * fade_s
                self.judgment_hole_crumble.append({
                    'x': cx + math.cos(angle) * dist,
                    'y': ground_y + math.sin(angle) * dist * 0.3,
                    'vx': math.cos(angle) * random.uniform(0.2, 0.8),
                    'vy': random.uniform(-0.3, 1.0),
                    'size': random.uniform(1.0, 2.5),
                    'life': random.uniform(0.5, 1.0),
                    'color': random.choice([
                        (155, 130, 95), (125, 105, 75), (105, 85, 60)
                    ]),
                })
            if progress >= 1.0:
                self.judgment_phase = self.JUDGMENT_IDLE
                self.judgment_timer = 0.0
                self.judgment_scale = 1.0
                self.judgment_hole_fade_scale = 0.0
                self.judgment_hole_crumble.clear()
                self.judgment_cooldown = random.uniform(60.0, 90.0)
                # 번개 상태 초기화
                self.judgment_variant = 'earthquake'
                self.judgment_bolt_hidden = False
                self.judgment_bolt_thrown = False
                self.judgment_bolt_proj_trail.clear()
                self.judgment_explosion_sparks.clear()
                self.judgment_lightning_active = False
                self.judgment_lightning_stun_top = False
                self.judgment_lightning_stun_bottom = False
                self.judgment_lightning_stun_timer = 0.0
                self.judgment_bolt_intensity = 0.0

    def get_judgment_shake_offset(self):
        """신의심판 화면 흔들림 오프셋 반환 (정글지진의 1.5배 강도)"""
        if self.judgment_phase not in (self.JUDGMENT_EARTHQUAKE, self.JUDGMENT_SLAM,
                                       self.JUDGMENT_BOLT_EXPLOSION, self.JUDGMENT_RETURN):
            return (0, 0)
        if self.judgment_shake_intensity <= 0:
            return (0, 0)
        intensity = 16 * self.judgment_shake_intensity
        ox = (random.random() - 0.5) * intensity * 2
        oy = (random.random() - 0.5) * intensity * 2
        return (int(ox), int(oy))

    def get_lightning_explosion_info(self):
        """번개 폭발 정보 반환 (pingfighter.py 스턴 판정용)"""
        if self.judgment_phase == self.JUDGMENT_BOLT_EXPLOSION and self.judgment_variant == 'lightning':
            return {
                'active': True,
                'x': self.judgment_explosion_x,
                'y': self.judgment_explosion_y,
                'radius': self.judgment_explosion_radius,
                'max_radius': self.judgment_explosion_max_radius,
            }
        return {'active': False}

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
        names = {0: "IDLE", 1: "MERGE", 2: "ARM_RAISE", 3: "SLAM", 4: "EARTHQUAKE",
                 5: "RETURN", 6: "HOLE_FADE", 7: "BOLT_THROW", 8: "BOLT_FLIGHT", 9: "BOLT_EXPLOSION"}
        return names.get(self.judgment_phase, "UNKNOWN")

    def _draw_judgment_overlay(self, screen, offset_x=0, offset_y=0):
        """신의심판 이벤트 비주얼 오버레이 (깔끔한 스타일)"""
        if self.judgment_phase == self.JUDGMENT_IDLE:
            return

        cx = self.width // 2 + offset_x
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

        # ── 구멍 페이드 페이즈 (석상 없이 구멍만 사라짐) ──
        if self.judgment_phase == self.JUDGMENT_HOLE_FADE:
            ground_y = cy + 10
            fade_progress = min(1.0, self.judgment_timer / self.HOLE_FADE_DURATION)
            fade_s = self.judgment_hole_fade_scale * (1.0 - fade_progress)
            fade_alpha = int(200 * (1.0 - fade_progress))

            if fade_s > 0.3 and fade_alpha > 5:
                hole_dark = (75, 60, 42)
                sand_dark = (125, 105, 75)
                sand_shadow = (105, 85, 60)
                sand_light = (175, 150, 115)
                lw_g = max(1, int(fade_s))

                # 줄어드는 구멍 (투명도 감소)
                hole_w = int(22 * fade_s)
                hole_h = int(8 * fade_s)
                if hole_w > 3 and hole_h > 1:
                    hole_surf = pygame.Surface((hole_w, hole_h), pygame.SRCALPHA)
                    pygame.draw.ellipse(hole_surf, (*hole_dark, min(160, fade_alpha)),
                                        (0, 0, hole_w, hole_h))
                    screen.blit(hole_surf, (cx - hole_w // 2, ground_y - hole_h // 3))

                # 줄어드는 테두리
                edge_pts = [
                    (cx - int(14 * fade_s), ground_y + int(2 * fade_s)),
                    (cx - int(13 * fade_s), ground_y - int(1 * fade_s)),
                    (cx - int(10 * fade_s), ground_y - int(3 * fade_s)),
                    (cx - int(3 * fade_s), ground_y - int(3 * fade_s)),
                    (cx + int(3 * fade_s), ground_y - int(2 * fade_s)),
                    (cx + int(10 * fade_s), ground_y - int(3 * fade_s)),
                    (cx + int(13 * fade_s), ground_y - int(2 * fade_s)),
                    (cx + int(14 * fade_s), ground_y + int(2 * fade_s)),
                    (cx, ground_y + int(3 * fade_s)),
                ]
                if len(edge_pts) >= 3:
                    edge_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
                    col_a = (*sand_dark, min(200, fade_alpha))
                    pygame.draw.polygon(edge_surf, col_a, edge_pts)
                    screen.blit(edge_surf, (0, 0))

            # 부스러기 파티클
            crumble_hl = (175, 150, 115)
            for d in self.judgment_hole_crumble:
                dx, dy = int(d['x']) + offset_x, int(d['y']) + offset_y
                ds = max(1, int(d['size'] * min(1, d['life'])))
                if ds > 0:
                    pygame.draw.circle(screen, d['color'], (dx, dy), ds)
                    if ds > 1:
                        pygame.draw.circle(screen, crumble_hl, (dx - 1, dy - 1), max(1, ds - 1))
            return  # HOLE_FADE에서는 석상/기타 이펙트 불필요

        # ── 동적 제우스 석상 그리기 (상승/하강 중 지면 클리핑) ──
        rise_y = int(self.judgment_rise_offset)
        is_sinking = self.judgment_phase == self.JUDGMENT_RETURN
        # 흔들림 (상승/하강 중에만)
        rise_shake_x = 0
        if rise_y > 2:
            if is_sinking:
                # 하강: 느리고 무거운 좌우 흔들림 (저주파, 감쇠)
                sink_progress = min(1.0, self.judgment_timer / self.RETURN_DURATION) if self.RETURN_DURATION > 0 else 0
                wobble_decay = max(0, 1.0 - sink_progress * 1.5)  # 빠르게 감쇠
                rise_shake_x = int(math.sin(self.time * 8) * 2 * wobble_decay * s)
            else:
                # 상승: 빠른 흔들림
                wobble = min(1.0, rise_y / 40.0)
                rise_shake_x = int(math.sin(self.time * 15) * 3 * wobble * s)

        if rise_y > 2:
            # 지면 레벨 아래 클리핑 (석상 하반신 숨김)
            ground_y = cy + 10
            old_clip = screen.get_clip()
            screen.set_clip(pygame.Rect(0, 0, screen.get_width(), ground_y))
            self._draw_judgment_statue_scaled(screen, cx + rise_shake_x, cy + rise_y, s)
            screen.set_clip(old_clip)

            # ── 지면 구멍/함몰 효과 (클리핑 해제 후 지면 위에 그림) ──
            sand_dark = (125, 105, 75)
            sand_shadow = (105, 85, 60)
            sand = (155, 130, 95)
            sand_light = (175, 150, 115)
            hole_dark = (75, 60, 42)
            lw_g = max(1, int(s))

            # 구멍 안쪽 어둠 (석상 주변 타원형 구멍)
            hole_w = int(22 * s)
            hole_h = int(8 * s)
            if hole_w > 4 and hole_h > 2:
                hole_surf = pygame.Surface((hole_w, hole_h), pygame.SRCALPHA)
                pygame.draw.ellipse(hole_surf, (*hole_dark, 160), (0, 0, hole_w, hole_h))
                screen.blit(hole_surf, (cx + rise_shake_x - hole_w // 2,
                                        ground_y - hole_h // 3))

            # 구멍 테두리 (솟아오른 땅 가장자리 - 불규칙 폴리곤)
            edge_pts = [
                (cx - int(14 * s), ground_y + int(2 * s)),
                (cx - int(13 * s), ground_y - int(1 * s)),
                (cx - int(10 * s), ground_y - int(3 * s)),
                (cx - int(6 * s), ground_y - int(1 * s)),
                (cx - int(3 * s), ground_y - int(3 * s)),
                (cx + int(3 * s), ground_y - int(2 * s)),
                (cx + int(7 * s), ground_y - int(3 * s)),
                (cx + int(11 * s), ground_y - int(1 * s)),
                (cx + int(13 * s), ground_y - int(2 * s)),
                (cx + int(14 * s), ground_y + int(2 * s)),
                (cx + int(12 * s), ground_y + int(3 * s)),
                (cx, ground_y + int(4 * s)),
                (cx - int(12 * s), ground_y + int(3 * s)),
            ]
            pygame.draw.polygon(screen, sand_dark, edge_pts)
            # 테두리 윗면 하이라이트
            pygame.draw.lines(screen, sand_light, False, edge_pts[:10], lw_g)
            # 테두리 아랫면 그림자
            pygame.draw.lines(screen, sand_shadow, False, edge_pts[9:], lw_g)

            # 구멍 안쪽 내벽 (석상 양쪽에 어두운 호)
            inner_w = int(18 * s)
            inner_h = int(6 * s)
            if inner_w > 4 and inner_h > 2:
                pygame.draw.arc(screen, hole_dark,
                                (cx + rise_shake_x - inner_w // 2,
                                 ground_y - inner_h // 3,
                                 inner_w, inner_h),
                                0.2, math.pi - 0.2, lw_g)

            # 먼지 구름 (구멍 경계에서 피어오르는 느낌)
            sink_ratio = min(1.0, rise_y / (60.0 * s)) if s > 0 else 0
            is_sinking = self.judgment_phase == self.JUDGMENT_RETURN
            if sink_ratio > 0.05:
                # 기본 먼지 구름 (상승/하강 공통)
                dust_alpha = int(80 * min(1.0, sink_ratio * 2))
                dust_w = int(26 * s)
                dust_h = int(5 * s)
                if dust_w > 4 and dust_h > 2:
                    dust_surf = pygame.Surface((dust_w, dust_h), pygame.SRCALPHA)
                    pygame.draw.ellipse(dust_surf, (180, 160, 130, dust_alpha),
                                        (0, 0, dust_w, dust_h))
                    screen.blit(dust_surf, (cx + rise_shake_x - dust_w // 2,
                                            ground_y - dust_h))
                # 하강 전용: 추가 먼지/흡입 효과
                if is_sinking:
                    # 넓은 먼지 구름 (구멍 주변에 확산)
                    wide_alpha = int(50 * min(1.0, sink_ratio * 1.5))
                    wide_w = int(36 * s)
                    wide_h = int(7 * s)
                    if wide_w > 4 and wide_h > 2:
                        wide_surf = pygame.Surface((wide_w, wide_h), pygame.SRCALPHA)
                        pygame.draw.ellipse(wide_surf, (170, 150, 120, wide_alpha),
                                            (0, 0, wide_w, wide_h))
                        screen.blit(wide_surf, (cx + rise_shake_x - wide_w // 2,
                                                ground_y - wide_h + int(2 * s)))
                    # 깊은 함몰부 그림자 강화 (하강할수록 진해짐)
                    deep_alpha = int(100 * min(1.0, sink_ratio))
                    deep_w = int(16 * s)
                    deep_h = int(5 * s)
                    if deep_w > 3 and deep_h > 1:
                        deep_surf = pygame.Surface((deep_w, deep_h), pygame.SRCALPHA)
                        pygame.draw.ellipse(deep_surf, (55, 42, 28, deep_alpha),
                                            (0, 0, deep_w, deep_h))
                        screen.blit(deep_surf, (cx + rise_shake_x - deep_w // 2,
                                                ground_y - deep_h // 2))
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

        # ── 번개 투사체 (BOLT_THROW / BOLT_FLIGHT 페이즈) ──
        # 동상 손의 번개와 동일한 금색 지그재그 스타일
        if self.judgment_phase in (self.JUDGMENT_BOLT_THROW, self.JUDGMENT_BOLT_FLIGHT) and self.judgment_bolt_thrown:
            bx = int(self.judgment_bolt_proj_x) + offset_x
            by = int(self.judgment_bolt_proj_y) + offset_y
            ang = math.radians(self.judgment_bolt_proj_angle)
            ps = self.judgment_scale  # 동상 스케일 (4x)
            bolt_len = int(18 * ps)   # 동상 번개와 동일한 길이
            cos_a, sin_a = math.cos(ang), math.sin(ang)
            # 수직 방향
            perp_cos, perp_sin = -sin_a, cos_a
            # 동상 번개와 동일한 지그재그 패턴
            zigzag = [
                (0, 0),
                (-3, 0.25), (2, 0.4), (-2, 0.6), (1, 0.78), (-1, 1.0),
            ]
            bolt_segs = []
            for zx, zt in zigzag:
                rx = bx + int(zx * ps * perp_cos) + int(bolt_len * zt * cos_a)
                ry = by + int(zx * ps * perp_sin) + int(bolt_len * zt * sin_a)
                bolt_segs.append((rx, ry))
            # 글로우 (금색 반투명)
            glow_r = int(12 * ps)
            glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (180, 150, 60, 40), (glow_r, glow_r), glow_r)
            pygame.draw.circle(glow_surf, (212, 175, 85, 70), (glow_r, glow_r), glow_r // 2)
            screen.blit(glow_surf, (bx - glow_r, by - glow_r), special_flags=pygame.BLEND_ADD)
            # 외곽 글로우 (동상 번개와 동일한 금색 두께)
            glow_w = max(1, int(3 * ps))
            for i in range(len(bolt_segs) - 1):
                pygame.draw.line(screen, (180, 150, 60), bolt_segs[i], bolt_segs[i + 1], glow_w)
            # 핵심 번개 코어 (금색)
            core_w = max(1, int(1.5 * ps))
            for i in range(len(bolt_segs) - 1):
                pygame.draw.line(screen, (230, 200, 110), bolt_segs[i], bolt_segs[i + 1], core_w)
            # 중심 백색 라인
            for i in range(len(bolt_segs) - 1):
                pygame.draw.line(screen, (255, 245, 200), bolt_segs[i], bolt_segs[i + 1], max(1, int(ps * 0.5)))
            # 미니 전기 아크 (비행 중 갈라지는 전류)
            for _ in range(2):
                seg_idx = random.randint(0, len(bolt_segs) - 1)
                ax, ay = bolt_segs[seg_idx]
                arc_a = random.uniform(0, math.pi * 2)
                arc_len = random.uniform(4, 10) * ps
                arc_pts = [(ax, ay)]
                for step in range(2):
                    arc_a += random.uniform(-0.8, 0.8)
                    sl = arc_len * (0.5 + step * 0.3)
                    nx = arc_pts[-1][0] + int(math.cos(arc_a) * sl)
                    ny = arc_pts[-1][1] + int(math.sin(arc_a) * sl)
                    arc_pts.append((nx, ny))
                arc_col = (255, int(220 + random.random() * 35), int(80 + random.random() * 80))
                for ai in range(len(arc_pts) - 1):
                    pygame.draw.line(screen, arc_col, arc_pts[ai], arc_pts[ai + 1], 1)
            # 트레일 파티클 (금색)
            for tp in self.judgment_bolt_proj_trail:
                tx, ty = int(tp['x']) + offset_x, int(tp['y']) + offset_y
                ts = max(1, int(tp['size'] * min(1.0, tp['life'] * 4)))
                pygame.draw.circle(screen, tp['color'], (tx, ty), ts)

        # ── 감전 폭발 (BOLT_EXPLOSION 페이즈) ──
        if self.judgment_phase == self.JUDGMENT_BOLT_EXPLOSION:
            ex = int(self.judgment_explosion_x) + offset_x
            ey = int(self.judgment_explosion_y) + offset_y
            r = max(1, int(self.judgment_explosion_radius))
            ring_a = self.judgment_explosion_ring_alpha
            # 확장 전기 링 (금색 외곽 + 백색 내곽)
            if ring_a > 10 and r > 3:
                ring_surf = pygame.Surface((r * 2 + 4, r * 2 + 4), pygame.SRCALPHA)
                ring_cx, ring_cy = r + 2, r + 2
                a1 = min(255, ring_a)
                a2 = min(180, int(ring_a * 0.6))
                pygame.draw.circle(ring_surf, (212, 175, 85, a2), (ring_cx, ring_cy), r, max(1, r // 8))
                pygame.draw.circle(ring_surf, (255, 240, 180, a1), (ring_cx, ring_cy), max(1, r - 2), max(1, r // 12))
                screen.blit(ring_surf, (ex - r - 2, ey - r - 2))
            # 방사형 전기 아크 (금색 + 백색 번개)
            arc_count = min(10, int(self.judgment_explosion_radius / 25))
            for i in range(arc_count):
                a_ang = (math.pi * 2 / max(1, arc_count)) * i + self.judgment_timer * 3
                arc_len = r * random.uniform(0.5, 1.0)
                pts = [(ex, ey)]
                segs = random.randint(3, 5)
                for j in range(1, segs + 1):
                    frac = j / segs
                    px = ex + int(math.cos(a_ang) * arc_len * frac + random.uniform(-8, 8))
                    py = ey + int(math.sin(a_ang) * arc_len * frac + random.uniform(-8, 8))
                    pts.append((px, py))
                if len(pts) >= 2:
                    arc_alpha = min(255, int(ring_a * 0.8))
                    if arc_alpha > 20:
                        arc_col = random.choice([(255, 220, 80), (230, 200, 110), (255, 245, 200)])
                        pygame.draw.lines(screen, arc_col, False, pts, max(1, int(self.judgment_scale * 0.5)))
            # 스파크 파티클
            for sp in self.judgment_explosion_sparks:
                sx, sy = int(sp['x']) + offset_x, int(sp['y']) + offset_y
                ss = max(1, int(sp['size'] * min(1.0, sp['life'] * 4)))
                pygame.draw.circle(screen, sp['color'], (sx, sy), ss)
            # 착탄 지점 번개볼트 잔상 (초반에만)
            if self.judgment_timer < 0.5:
                bolt_fade = max(0, 1.0 - self.judgment_timer / 0.5)
                bolt_h = int(40 * self.judgment_scale * bolt_fade)
                if bolt_h > 3:
                    for zx, zt in [(-3,0.2),(2,0.4),(-2,0.6),(1,0.8),(-1,1.0)]:
                        px = ex + int(zx * self.judgment_scale * bolt_fade)
                        py = ey - int(bolt_h * zt)
                        pygame.draw.circle(screen, (255, 240, 140, int(200 * bolt_fade)),
                                           (px, py), max(1, int(2 * bolt_fade)))
            # 임팩트 플래시 (금색)
            if self.judgment_explosion_flash_alpha > 10:
                fa = min(200, self.judgment_explosion_flash_alpha)
                flash_size = max(10, int(r * 0.6))
                fl_surf = pygame.Surface((flash_size * 2, flash_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(fl_surf, (212, 175, 85, fa), (flash_size, flash_size), flash_size)
                pygame.draw.circle(fl_surf, (255, 245, 200, min(255, fa + 30)), (flash_size, flash_size), flash_size // 3)
                screen.blit(fl_surf, (ex - flash_size, ey - flash_size), special_flags=pygame.BLEND_ADD)

        # ── 충격 플래시 (단순 전체 플래시) ──
        if self.judgment_flash_alpha > 0:
            fa = min(180, self.judgment_flash_alpha)
            flash_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            flash_surf.fill((255, 245, 220, fa))
            screen.blit(flash_surf, (offset_x, offset_y), special_flags=pygame.BLEND_ADD)

    def _draw_judgment_statue_scaled(self, screen, cx, cy, scale):
        """신의심판 동안 스케일된 제우스 석상 (고퀄리티 상반신)"""
        s = scale
        marble = (185, 175, 160)
        marble_light = (200, 192, 178)
        marble_mid = (160, 150, 135)
        marble_dark = (130, 120, 108)
        marble_shadow = (105, 95, 85)
        earth_dark = (85, 70, 50)
        gold = self.colors['gold']
        gold_light = self.colors['gold_light']
        lw = max(1, int(s))
        thick = max(1, int(2 * s))

        # ── 흙 마운드 (석상이 모래바닥에서 솟아나온 느낌) ──
        ground_y = cy + int(2 * s)
        sand = (155, 130, 95)
        sand_dark = (125, 105, 75)
        sand_light = (175, 150, 115)
        sand_shadow = (105, 85, 60)

        # 1) 불규칙 흙 마운드 (울퉁불퉁한 폴리곤 - 디그다 스타일)
        mound_pts = [
            (cx - int(16 * s), ground_y + int(3 * s)),
            (cx - int(14 * s), ground_y - int(1 * s)),
            (cx - int(11 * s), ground_y - int(3 * s)),
            (cx - int(7 * s), ground_y - int(2 * s)),
            (cx - int(4 * s), ground_y - int(4 * s)),
            (cx, ground_y - int(3 * s)),
            (cx + int(5 * s), ground_y - int(4 * s)),
            (cx + int(8 * s), ground_y - int(2 * s)),
            (cx + int(12 * s), ground_y - int(3 * s)),
            (cx + int(15 * s), ground_y - int(1 * s)),
            (cx + int(16 * s), ground_y + int(3 * s)),
        ]
        pygame.draw.polygon(screen, sand_dark, mound_pts)
        # 마운드 윗면 하이라이트 (밝은 능선)
        hl_pts = [
            (cx - int(11 * s), ground_y - int(3 * s)),
            (cx - int(4 * s), ground_y - int(4 * s)),
            (cx, ground_y - int(3 * s)),
            (cx + int(5 * s), ground_y - int(4 * s)),
            (cx + int(12 * s), ground_y - int(3 * s)),
            (cx + int(8 * s), ground_y - int(2 * s)),
            (cx, ground_y - int(2 * s)),
            (cx - int(7 * s), ground_y - int(2 * s)),
        ]
        pygame.draw.polygon(screen, sand, hl_pts)
        # 마운드 하단 그림자 (바닥과의 경계)
        pygame.draw.lines(screen, sand_shadow, False, [
            (cx - int(15 * s), ground_y + int(2 * s)),
            (cx - int(8 * s), ground_y + int(3 * s)),
            (cx, ground_y + int(2 * s)),
            (cx + int(9 * s), ground_y + int(3 * s)),
            (cx + int(15 * s), ground_y + int(2 * s)),
        ], lw)

        # 2) 몸통 주변 솟아오른 흙 테두리 (석상과 땅 사이 경계)
        rim_pts = [
            (cx - int(10 * s), ground_y),
            (cx - int(8 * s), ground_y - int(2 * s)),
            (cx - int(5 * s), ground_y - int(1 * s)),
            (cx - int(2 * s), ground_y - int(3 * s)),
            (cx + int(2 * s), ground_y - int(2 * s)),
            (cx + int(5 * s), ground_y - int(3 * s)),
            (cx + int(8 * s), ground_y - int(1 * s)),
            (cx + int(10 * s), ground_y),
        ]
        pygame.draw.lines(screen, sand_light, False, rim_pts, lw)

        # 3) 주변 잔해/자갈 (이집트 석상처럼 흩어진 돌 파편)
        rubble = [
            (-18, 5, 2.5, sand_dark), (-15, 3, 1.8, sand_shadow),
            (-12, 6, 1.5, sand), (-20, 4, 1.2, sand_shadow),
            (13, 5, 2.0, sand_dark), (17, 3, 2.2, sand_shadow),
            (19, 6, 1.3, sand), (15, 7, 1.6, sand_dark),
            (-8, 5, 1.0, sand), (9, 6, 1.0, sand),
            (-22, 6, 1.0, sand_shadow), (22, 5, 1.0, sand_shadow),
        ]
        for rx, ry, rsz, rcol in rubble:
            px = cx + int(rx * s)
            py = ground_y + int(ry * s)
            r = max(1, int(rsz * s * 0.35))
            pygame.draw.circle(screen, rcol, (px, py), r)
            if r > 1:
                pygame.draw.circle(screen, sand_light, (px - 1, py - 1), max(1, r - 1))

        # ── 상체 메인 바디 (자연스러운 파단면 하단) ──
        torso_pts = [
            # 하단 파단면 (넓은 곡선 + 자연스러운 돌 깨짐)
            (cx - int(9 * s), cy - int(2 * s)),
            (cx - int(6 * s), cy - int(5 * s)),
            (cx - int(3 * s), cy - int(1 * s)),
            (cx, cy - int(4 * s)),
            (cx + int(4 * s), cy),
            (cx + int(7 * s), cy - int(3 * s)),
            (cx + int(9 * s), cy - int(1 * s)),
            # 옆구리 (허리 곡선)
            (cx + int(8 * s), cy - int(8 * s)),
            # 어깨 (넓게)
            (cx + int(11 * s), cy - int(16 * s)),
            (cx + int(10 * s), cy - int(19 * s)),
            (cx - int(10 * s), cy - int(19 * s)),
            (cx - int(11 * s), cy - int(16 * s)),
            # 왼쪽 옆구리
            (cx - int(8 * s), cy - int(8 * s)),
        ]
        pygame.draw.polygon(screen, marble, torso_pts)
        pygame.draw.polygon(screen, marble_dark, torso_pts, lw)

        # ── 토가 주름 (여러 줄 - 깊이감) ──
        # 메인 드레이프 (어깨→허리 대각선)
        pygame.draw.line(screen, marble_dark,
                         (cx - int(9 * s), cy - int(18 * s)),
                         (cx + int(5 * s), cy - int(6 * s)), thick)
        # 보조 주름
        pygame.draw.line(screen, marble_mid,
                         (cx - int(7 * s), cy - int(15 * s)),
                         (cx + int(2 * s), cy - int(5 * s)), lw)
        pygame.draw.line(screen, marble_mid,
                         (cx + int(3 * s), cy - int(17 * s)),
                         (cx + int(7 * s), cy - int(7 * s)), lw)

        # ── 가슴 근육 음영 ──
        chest_w = int(8 * s)
        chest_h = int(5 * s)
        if chest_w > 3 and chest_h > 2:
            pygame.draw.arc(screen, marble_dark,
                            (cx - int(8 * s), cy - int(17 * s), chest_w, chest_h),
                            -0.2, math.pi * 0.7, lw)
            pygame.draw.arc(screen, marble_dark,
                            (cx + int(1 * s), cy - int(17 * s), chest_w, chest_h),
                            math.pi * 0.3, math.pi * 1.2, lw)

        # ── 복부 중앙선 ──
        pygame.draw.line(screen, marble_mid,
                         (cx, cy - int(12 * s)), (cx, cy - int(5 * s)), lw)

        # ── 허리 띠 (금색 새시) ──
        belt_y = cy - int(7 * s)
        pygame.draw.line(screen, gold,
                         (cx - int(7 * s), belt_y),
                         (cx + int(7 * s), belt_y), thick)
        # 버클
        br = max(1, int(1.5 * s))
        pygame.draw.circle(screen, gold_light, (cx, belt_y), br)
        pygame.draw.circle(screen, gold, (cx, belt_y), br, 1)

        # ── 파단면 하이라이트 (깨진 돌 단면의 밝은 부분) ──
        pygame.draw.line(screen, marble_light,
                         (cx - int(6 * s), cy - int(5 * s)),
                         (cx - int(3 * s), cy - int(1 * s)), lw)
        pygame.draw.line(screen, marble_light,
                         (cx + int(4 * s), cy),
                         (cx + int(7 * s), cy - int(3 * s)), lw)
        # 파단면 그림자 (아래쪽)
        pygame.draw.line(screen, marble_shadow,
                         (cx - int(3 * s), cy - int(1 * s)),
                         (cx, cy - int(4 * s)), lw)
        pygame.draw.line(screen, marble_shadow,
                         (cx, cy - int(4 * s)),
                         (cx + int(4 * s), cy), lw)

        # ── 목 ──
        neck_w = max(2, int(3 * s))
        pygame.draw.line(screen, marble,
                         (cx, cy - int(19 * s)),
                         (cx, cy - int(22 * s)), neck_w)
        pygame.draw.line(screen, marble_mid,
                         (cx + int(1 * s), cy - int(19 * s)),
                         (cx + int(1 * s), cy - int(21 * s)), lw)

        # ── 팔 ──
        self._draw_judgment_arms(screen, cx, cy, s, marble, marble_mid, marble_dark, gold, gold_light)

        # ── 머리 ──
        head_y = cy - int(24 * s)
        head_r = max(2, int(6 * s))
        pygame.draw.circle(screen, marble, (cx, head_y), head_r)
        pygame.draw.circle(screen, marble_dark, (cx, head_y), head_r, lw)
        # 이목구비 (눈, 코 힌트)
        eye_y = head_y - int(1 * s)
        if s >= 2:
            # 눈 (작은 음영)
            pygame.draw.line(screen, marble_dark,
                             (cx - int(3 * s), eye_y),
                             (cx - int(1 * s), eye_y), lw)
            pygame.draw.line(screen, marble_dark,
                             (cx + int(1 * s), eye_y),
                             (cx + int(3 * s), eye_y), lw)
            # 코 (세로 음영)
            pygame.draw.line(screen, marble_mid,
                             (cx, eye_y + int(1 * s)),
                             (cx, eye_y + int(3 * s)), lw)
        # 수염 (풍성한 삼각형)
        beard_pts = [
            (cx - int(4 * s), head_y + int(4 * s)),
            (cx + int(4 * s), head_y + int(4 * s)),
            (cx + int(2 * s), head_y + int(9 * s)),
            (cx, head_y + int(10 * s)),
            (cx - int(2 * s), head_y + int(9 * s)),
        ]
        pygame.draw.polygon(screen, marble_mid, beard_pts)
        pygame.draw.polygon(screen, marble_dark, beard_pts, lw)
        # 수염 결
        pygame.draw.line(screen, marble_dark,
                         (cx - int(1 * s), head_y + int(5 * s)),
                         (cx - int(1 * s), head_y + int(8 * s)), lw)
        pygame.draw.line(screen, marble_dark,
                         (cx + int(1 * s), head_y + int(5 * s)),
                         (cx + int(2 * s), head_y + int(8 * s)), lw)
        # 머리카락 (풍성한 곱슬)
        hr = int(7 * s)
        pygame.draw.arc(screen, marble_dark,
                        (cx - hr, head_y - hr, hr * 2, int(10 * s)),
                        0.2, math.pi - 0.2, thick)
        # 머리카락 볼륨 (추가 아크)
        if s >= 2:
            pygame.draw.arc(screen, marble_shadow,
                            (cx - hr - int(1 * s), head_y - hr - int(1 * s),
                             hr * 2 + int(2 * s), int(8 * s)),
                            0.4, math.pi - 0.4, lw)

        # ── 월계관 (잎사귀 형태) ──
        wreath_color = (145, 140, 85)
        wreath_light = (170, 165, 105)
        wreath_gold = (190, 175, 90)
        wr = int(8 * s)
        for angle_deg in range(-80, 81, 20):
            a = math.radians(angle_deg - 90)
            lx = cx + int(wr * math.cos(a))
            ly = head_y + int(wr * math.sin(a))
            # 잎사귀 방향 (바깥쪽)
            leaf_a = a + math.pi * 0.5
            leaf_len = max(1, int(3 * s))
            ex = lx + int(leaf_len * math.cos(leaf_a))
            ey = ly + int(leaf_len * math.sin(leaf_a))
            pygame.draw.line(screen, wreath_color, (lx, ly), (ex, ey), lw)
            pygame.draw.circle(screen, wreath_light, (lx, ly), max(1, int(0.8 * s)))
        # 월계관 정수리 보석
        top_y = head_y - int(7 * s)
        pygame.draw.circle(screen, wreath_gold, (cx, top_y), max(1, int(1.5 * s)))
        if s >= 2:
            pygame.draw.circle(screen, gold_light, (cx, top_y), max(1, int(1.5 * s)), 1)

    def _draw_judgment_arms(self, screen, cx, cy, s, marble, marble_mid, marble_dark, gold, gold_light):
        """신의심판 석상의 팔 (상완+전완 2세그먼트, 애니메이션)"""
        upper_w = max(2, int(3.5 * s))
        fore_w = max(1, int(2.5 * s))
        upper_len = int(10 * s)
        fore_len = int(10 * s)
        lw = max(1, int(s))

        # 어깨 위치 (상체와 일치)
        l_shoulder = (cx - int(10 * s), cy - int(19 * s))
        r_shoulder = (cx + int(10 * s), cy - int(19 * s))

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

        # ── 오른손 무기 (variant에 따라 번개 또는 해머) ──
        if self.judgment_variant == 'lightning':
            # ══════ 번개 (오른손에 들고 있음, 투척 후 숨김) ══════
            if self.judgment_bolt_hidden:
                for sp in self.judgment_bolt_sparks:
                    sx, sy = int(sp['x']), int(sp['y'])
                    sp_size = max(1, int(sp['size'] * min(1.0, sp['life'] * 3)))
                    if sp_size > 0:
                        pygame.draw.circle(screen, sp['color'], (sx, sy), sp_size)
                return
            bolt_angle = fore_angle_r
            bolt_x, bolt_y = ra_hand
            bolt_len = int(18 * s)
            bdir_x = math.sin(bolt_angle)
            bdir_y = math.cos(bolt_angle)
            perp_x, perp_y = bdir_y, -bdir_x
            zigzag = [
                (0, 0),
                (-3, 0.25), (2, 0.4), (-2, 0.6), (1, 0.78), (-1, 1.0),
            ]
            segs = []
            for zx, zt in zigzag:
                px = bolt_x + int(zx * s * perp_x) + int(bolt_len * zt * bdir_x)
                py = bolt_y + int(zx * s * perp_y) + int(bolt_len * zt * bdir_y)
                segs.append((px, py))

            intensity = self.judgment_bolt_intensity

            if intensity > 0.1:
                arc_count = int(intensity * 3)
                for _ in range(arc_count):
                    seg_idx = random.randint(0, len(segs) - 1)
                    ax, ay = segs[seg_idx]
                    arc_angle = random.uniform(0, math.pi * 2)
                    arc_len = random.uniform(3, 8) * s * intensity
                    arc_pts = [(ax, ay)]
                    for step in range(2):
                        arc_angle += random.uniform(-0.8, 0.8)
                        step_len = arc_len * (0.5 + step * 0.3)
                        nx = arc_pts[-1][0] + int(math.cos(arc_angle) * step_len)
                        ny = arc_pts[-1][1] + int(math.sin(arc_angle) * step_len)
                        arc_pts.append((nx, ny))
                    arc_col = (255, int(220 + random.random() * 35),
                               int(80 + random.random() * 80))
                    for ai in range(len(arc_pts) - 1):
                        pygame.draw.line(screen, arc_col, arc_pts[ai], arc_pts[ai + 1], 1)

            base_glow_w = max(1, int(3 * s))
            glow_w = base_glow_w + int(intensity * 2 * s)
            glow_r_val = min(255, 180 + int(75 * intensity))
            glow_g_val = min(255, 150 + int(80 * intensity))
            glow_b_val = min(255, 60 + int(80 * intensity))
            for i in range(len(segs) - 1):
                pygame.draw.line(screen, (glow_r_val, glow_g_val, glow_b_val),
                                 segs[i], segs[i + 1], glow_w)
            core_r_val = min(255, 212 + int(43 * intensity))
            core_g_val = min(255, 175 + int(70 * intensity))
            core_b_val = min(255, 85 + int(115 * intensity))
            bolt_core_w = lw + int(intensity * s)
            for i in range(len(segs) - 1):
                pygame.draw.line(screen, (core_r_val, core_g_val, core_b_val),
                                 segs[i], segs[i + 1], bolt_core_w)
            if intensity > 0.6:
                white_a = intensity - 0.6
                white_col = (min(255, int(200 + 55 * white_a * 2.5)),
                             min(255, int(200 + 55 * white_a * 2.5)),
                             min(255, int(180 + 75 * white_a * 2.5)))
                for i in range(len(segs) - 1):
                    pygame.draw.line(screen, white_col, segs[i], segs[i + 1], max(1, lw - 1))

            tip = segs[-1]
            sl = max(1, int((3 + 3 * intensity) * s))
            spark_col = (min(255, int(212 + 43 * intensity)),
                         min(255, int(175 + 80 * intensity)),
                         min(255, int(85 + 100 * intensity)))
            pygame.draw.line(screen, spark_col, (tip[0] - sl, tip[1]), (tip[0] + sl, tip[1]), 1)
            pygame.draw.line(screen, spark_col, (tip[0], tip[1] - sl), (tip[0], tip[1] + sl), 1)
            if intensity > 0.3:
                dsl = max(1, int(sl * 0.7))
                pygame.draw.line(screen, spark_col,
                                 (tip[0] - dsl, tip[1] - dsl), (tip[0] + dsl, tip[1] + dsl), 1)
                pygame.draw.line(screen, spark_col,
                                 (tip[0] + dsl, tip[1] - dsl), (tip[0] - dsl, tip[1] + dsl), 1)
            mid = segs[len(segs) // 2]
            mid_r = max(1, lw + int(intensity * 2 * s))
            pygame.draw.circle(screen, (255, 240, 180), mid, mid_r)
            for sp in self.judgment_bolt_sparks:
                sx, sy = int(sp['x']), int(sp['y'])
                sp_size = max(1, int(sp['size'] * min(1.0, sp['life'] * 3)))
                if sp_size > 0:
                    pygame.draw.circle(screen, sp['color'], (sx, sy), sp_size)
                    if sp_size > 1:
                        pygame.draw.circle(screen, (255, 255, 220),
                                           (sx, sy), max(1, sp_size - 1))
        else:
            # ══════ 고대 토르 해머 (땅의 분노 전용) ══════
            hammer_angle = fore_angle_r
            hx, hy = ra_hand
            handle_len = int(18 * s)
            hdir_x = math.sin(hammer_angle)
            hdir_y = math.cos(hammer_angle)
            perp_hx, perp_hy = hdir_y, -hdir_x  # 수직 방향

            # 핸들 끝점 (해머 헤드 중심)
            tip_x = hx + int(handle_len * hdir_x)
            tip_y = hy + int(handle_len * hdir_y)

            # ── 핸들 색상 ──
            wood = (120, 90, 55)
            wood_dark = (95, 70, 40)
            leather = (85, 65, 40)
            iron = (100, 90, 75)
            iron_light = (140, 125, 105)
            iron_dark = (70, 60, 50)
            iron_edge = (55, 48, 38)

            intensity = self.judgment_bolt_intensity

            # ── 핸들 (나무 자루) ──
            handle_w = max(2, int(2.5 * s))
            # 핸들 그림자 (약간 오프셋)
            pygame.draw.line(screen, wood_dark,
                             (hx + 1, hy + 1), (tip_x + 1, tip_y + 1), handle_w)
            # 핸들 본체
            pygame.draw.line(screen, wood, (hx, hy), (tip_x, tip_y), handle_w)
            # 핸들 하이라이트 (얇은 선)
            hl_offset = max(1, int(0.5 * s))
            hhl_x1 = hx - int(hl_offset * perp_hx)
            hhl_y1 = hy - int(hl_offset * perp_hy)
            hhl_x2 = tip_x - int(hl_offset * perp_hx)
            hhl_y2 = tip_y - int(hl_offset * perp_hy)
            pygame.draw.line(screen, (145, 115, 75), (hhl_x1, hhl_y1), (hhl_x2, hhl_y2), 1)

            # ── 가죽 밴드 (핸들 25%, 50%, 75%) ──
            band_w = max(1, int(1.5 * s))
            band_half = max(1, int(1.8 * s))
            for t in (0.25, 0.50, 0.75):
                bx = hx + int(handle_len * t * hdir_x)
                by = hy + int(handle_len * t * hdir_y)
                b1 = (bx - int(band_half * perp_hx), by - int(band_half * perp_hy))
                b2 = (bx + int(band_half * perp_hx), by + int(band_half * perp_hy))
                pygame.draw.line(screen, leather, b1, b2, band_w)

            # ── 해머 헤드 (직사각형 블록) ──
            head_half_w = int(7 * s)   # 좌우 폭
            head_half_h = int(2.5 * s)  # 진행방향 두께 (절반)
            # 해머 헤드 4 꼭짓점
            # 헤드 중심은 핸들 끝에서 약간 더 앞 (+1*s)
            hcx = tip_x + int(1 * s * hdir_x)
            hcy = tip_y + int(1 * s * hdir_y)
            h_pts = [
                (hcx - int(head_half_w * perp_hx) - int(head_half_h * hdir_x),
                 hcy - int(head_half_w * perp_hy) - int(head_half_h * hdir_y)),
                (hcx + int(head_half_w * perp_hx) - int(head_half_h * hdir_x),
                 hcy + int(head_half_w * perp_hy) - int(head_half_h * hdir_y)),
                (hcx + int(head_half_w * perp_hx) + int(head_half_h * hdir_x),
                 hcy + int(head_half_w * perp_hy) + int(head_half_h * hdir_y)),
                (hcx - int(head_half_w * perp_hx) + int(head_half_h * hdir_x),
                 hcy - int(head_half_w * perp_hy) + int(head_half_h * hdir_y)),
            ]
            # 본체
            pygame.draw.polygon(screen, iron, h_pts)
            # 테두리
            pygame.draw.polygon(screen, iron_dark, h_pts, max(1, int(s)))

            # ── 해머 헤드 상면 하이라이트 (윗면 밝게) ──
            hl_pts = [h_pts[0], h_pts[1],
                      (h_pts[1][0] + int(0.5 * s * hdir_x),
                       h_pts[1][1] + int(0.5 * s * hdir_y)),
                      (h_pts[0][0] + int(0.5 * s * hdir_x),
                       h_pts[0][1] + int(0.5 * s * hdir_y))]
            pygame.draw.polygon(screen, iron_light, hl_pts)

            # ── 양 끝 경사면 (bevel) ──
            bevel_d = int(1.5 * s)
            # 왼쪽 끝 경사
            lbevel = [
                h_pts[0], h_pts[3],
                (h_pts[3][0] + int(bevel_d * perp_hx),
                 h_pts[3][1] + int(bevel_d * perp_hy)),
                (h_pts[0][0] + int(bevel_d * perp_hx),
                 h_pts[0][1] + int(bevel_d * perp_hy)),
            ]
            pygame.draw.polygon(screen, iron_edge, lbevel)
            # 오른쪽 끝 경사
            rbevel = [
                h_pts[1], h_pts[2],
                (h_pts[2][0] - int(bevel_d * perp_hx),
                 h_pts[2][1] - int(bevel_d * perp_hy)),
                (h_pts[1][0] - int(bevel_d * perp_hx),
                 h_pts[1][1] - int(bevel_d * perp_hy)),
            ]
            pygame.draw.polygon(screen, iron_edge, rbevel)

            # ── 룬 문양 (헤드 중앙에 고대 각인) ──
            rune_col = (160, 145, 120)
            # 수직 룬 라인
            r1 = (hcx - int(1 * s * perp_hx), hcy - int(1 * s * perp_hy))
            r2 = (hcx + int(1 * s * perp_hx), hcy + int(1 * s * perp_hy))
            pygame.draw.line(screen, rune_col, r1, r2, 1)
            # 대각 룬 가지
            r_mid = ((r1[0] + r2[0]) // 2, (r1[1] + r2[1]) // 2)
            r_branch = (r_mid[0] + int(1.5 * s * hdir_x) + int(1 * s * perp_hx),
                        r_mid[1] + int(1.5 * s * hdir_y) + int(1 * s * perp_hy))
            pygame.draw.line(screen, rune_col, r_mid, r_branch, 1)

            # ── 핸들-헤드 연결부 장식 (금속 칼라) ──
            collar_w = max(1, int(1.5 * s))
            collar_half = max(2, int(3 * s))
            c1 = (tip_x - int(collar_half * perp_hx), tip_y - int(collar_half * perp_hy))
            c2 = (tip_x + int(collar_half * perp_hx), tip_y + int(collar_half * perp_hy))
            pygame.draw.line(screen, iron_light, c1, c2, collar_w)

            # ── 대지 에너지 글로우 (intensity에 따라) ──
            if intensity > 0.1:
                # 해머 헤드 주변 갈색/주황 글로우
                glow_r = int(head_half_w * s * 0.3 + intensity * 6 * s)
                glow_col = (min(255, int(160 + 80 * intensity)),
                            min(255, int(100 + 60 * intensity)),
                            min(255, int(30 + 40 * intensity)))
                glow_surf = pygame.Surface((glow_r * 2 + 4, glow_r * 2 + 4), pygame.SRCALPHA)
                glow_alpha = min(120, int(40 + 80 * intensity))
                pygame.draw.circle(glow_surf, (*glow_col, glow_alpha),
                                   (glow_r + 2, glow_r + 2), glow_r)
                screen.blit(glow_surf, (hcx - glow_r - 2, hcy - glow_r - 2),
                            special_flags=pygame.BLEND_ADD)
                # 미니 대지 파티클 (돌 파편 흩날림)
                for _ in range(int(intensity * 2)):
                    p_angle = random.uniform(0, math.pi * 2)
                    p_dist = random.uniform(2, head_half_w * 0.8) * s
                    px = hcx + int(math.cos(p_angle) * p_dist)
                    py = hcy + int(math.sin(p_angle) * p_dist)
                    p_size = max(1, int(random.uniform(0.5, 1.5) * s))
                    p_col = random.choice([
                        (180, 140, 80), (160, 120, 60), (200, 160, 90),
                    ])
                    pygame.draw.circle(screen, p_col, (px, py), p_size)

    def set_crowd_excitement(self, level):
        """관중 흥분도 설정 (0.0 ~ 1.0)"""
        self.crowd_noise_level = max(0.0, min(1.0, level))

    def draw(self, screen, scale_x=1.0, scale_y=1.0, offset_x=0, offset_y=0):
        """배경 그리기"""
        # 1. 바닥 (모래 + 비네트 + 바람무늬)
        if scale_x != 1.0 or scale_y != 1.0:
            scaled_floor = pygame.transform.scale(
                self.floor_surface,
                (int(self.width * scale_x), int(self.height * scale_y))
            )
            screen.blit(scaled_floor, (offset_x, offset_y))
        else:
            screen.blit(self.floor_surface, (offset_x, offset_y))

        # 2. 먼지 파티클 (바닥 위)
        for particle in self.dust_particles:
            px = int(particle['x'] * scale_x + offset_x)
            py = int(particle['y'] * scale_y + offset_y)
            size = max(1, int(particle['size'] * scale_x))
            color = (200, 175, 140)
            pygame.draw.circle(screen, color, (px, py), size)

        # 3. 금빛 먼지 (프리미엄 분위기)
        for gd in self.golden_dust:
            gx = int(gd['x'] * scale_x + offset_x)
            gy = int(gd['y'] * scale_y + offset_y)
            gsize = max(1, int(gd['size'] * scale_x))
            pulse = 0.6 + 0.4 * math.sin(self.time * 1.5 + gd['phase'])
            galpha = int(gd['alpha'] * pulse)
            gd_surf = pygame.Surface((gsize * 2 + 2, gsize * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(gd_surf, (210, 180, 80, galpha),
                             (gsize + 1, gsize + 1), gsize)
            screen.blit(gd_surf, (gx - gsize - 1, gy - gsize - 1))

        # 4. 경기장 라인 (중앙선, 중앙원, 코너)
        arena = self.arena_surface
        if scale_x != 1.0 or scale_y != 1.0:
            scaled_arena = pygame.transform.scale(
                arena, (int(self.width * scale_x), int(self.height * scale_y))
            )
            screen.blit(scaled_arena, (offset_x, offset_y))
        else:
            screen.blit(arena, (offset_x, offset_y))

        # 5. 장식 테두리 + 석상 (프리렌더)
        if scale_x != 1.0 or scale_y != 1.0:
            scaled_border = pygame.transform.scale(
                self.border_surface,
                (int(self.width * scale_x), int(self.height * scale_y))
            )
            screen.blit(scaled_border, (offset_x, offset_y))
        else:
            screen.blit(self.border_surface, (offset_x, offset_y))

        # 6. 신의심판 이벤트 오버레이 (동적 석상)
        if self.judgment_phase != self.JUDGMENT_IDLE:
            self._draw_judgment_overlay(screen, offset_x, offset_y)

        # 8. 횃불
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
        """전경 효과 (패들/공 위에 그려짐) - 알파 비네트"""
        vignette_size = 50
        sw = int(self.width * scale_x)

        # 상단 비네트
        v_top = pygame.Surface((sw, vignette_size), pygame.SRCALPHA)
        for i in range(vignette_size):
            alpha = int(35 * (1 - i / vignette_size))
            pygame.draw.line(v_top, (20, 15, 10, alpha), (0, i), (sw, i))
        screen.blit(v_top, (offset_x, offset_y + int(50 * scale_y)))

        # 하단 비네트
        v_bot = pygame.Surface((sw, vignette_size), pygame.SRCALPHA)
        for i in range(vignette_size):
            alpha = int(35 * (i / vignette_size))
            pygame.draw.line(v_bot, (20, 15, 10, alpha), (0, i), (sw, i))
        screen.blit(v_bot, (offset_x, offset_y + int((self.height - 50) * scale_y) - vignette_size))
