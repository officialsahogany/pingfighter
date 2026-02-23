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
        self.JUDGMENT_FAN_SWING = 10      # 1.2초: 부채 휘두르기
        self.JUDGMENT_SANDSTORM = 11      # 4초: 모래 소용돌이 비행 (끌어당김/포획)

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
        self.judgment_text_display_paused = False  # show_fade_text 중 judgment 타이머 일시정지
        # 바람의 분노 (Wind variant) 상태
        self.judgment_wind_sandstorms = []          # 모래바람 투사체 리스트
        self.judgment_wind_particles = []           # 바람 파티클
        self.judgment_fan_swing_progress = 0.0      # 부채 휘두르기 진행도
        self.judgment_wind_charge_intensity = 0.0   # 바람 충전 강도
        self.judgment_fan_energy_particles = []      # 부채 주변 바람 에너지 파티클
        # 이벤트 플래그 (핸들러에서 consume 방식으로 사용)
        self.judgment_bolt_throw_started = False   # BOLT_THROW 진입 시 True → 핸들러가 읽고 False
        self.judgment_bolt_explosion_started = False  # BOLT_EXPLOSION 진입 시 True → 핸들러가 읽고 False
        self.judgment_fan_swing_started = False     # FAN_SWING 진입 시 True → 핸들러가 읽고 False
        self.judgment_sandstorm_hit_top = False     # 모래바람 상단 히트 플래그
        self.judgment_sandstorm_hit_bottom = False  # 모래바람 하단 히트 플래그
        self.judgment_sandstorm_captured = None     # 모래바람 포획 정보 (pingfighter.py에서 consume)

        # 페이즈 지속시간 (초)
        self.MERGE_DURATION = 2.0
        self.ARM_RAISE_DURATION = 2.0
        self.SLAM_DURATION = 0.5
        self.EARTHQUAKE_DURATION = 5.2
        self.RETURN_DURATION = 3.0
        self.HOLE_FADE_DURATION = 1.5
        self.BOLT_THROW_DURATION = 0.6
        self.BOLT_FLIGHT_DURATION = 0.8
        self.BOLT_EXPLOSION_DURATION = 1.05  # 1.5 * 0.7 (-30% 단축)
        self.FAN_SWING_DURATION = 1.2
        self.SANDSTORM_DURATION = 7.0  # 나선형 소용돌이 (1개, 달팽이 궤적)

        # 테두리 서피스
        self.border_surface = pygame.Surface((width, height), pygame.SRCALPHA)

        # 금빛 먼지 (프리미엄 분위기 - 크기 다양화)
        self.golden_dust = []
        for _ in range(6):
            self.golden_dust.append({
                'x': random.randint(60, self.width - 60),
                'y': random.randint(120, self.height - 120),
                'vx': random.uniform(-0.15, 0.15),
                'vy': random.uniform(-0.08, 0.08),
                'size': random.uniform(1.0, 3.0),
                'alpha': random.randint(12, 35),
                'phase': random.uniform(0, math.pi * 2),
            })

        # 열기류 파티클 (횃불 근처 위로 올라가는 아지랑이)
        self.heat_shimmers = []
        for torch in self.torches:
            for _ in range(2):
                self.heat_shimmers.append({
                    'base_x': torch['x'],
                    'base_y': torch['y'],
                    'rx': random.uniform(-6, 6),
                    'ry': random.uniform(-20, -50),
                    'life': random.randint(40, 90),
                    'max_life': 90,
                    'drift': random.uniform(-0.2, 0.2),
                    'size': random.uniform(1.5, 3.0),
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
        """횃불 위치 초기화 - 게임 영역 내 양쪽 가장자리에 대칭 배치 (고퀄리티)"""
        torches = []
        left_x = self.GAME_AREA_X + 25
        right_x = self.GAME_AREA_END_X - 25
        positions = [
            (left_x, 150), (left_x, 375), (left_x, 600),
            (right_x, 150), (right_x, 375), (right_x, 600),
        ]
        for x, y in positions:
            # 엠버(불씨) 파티클 초기화
            embers = []
            for _ in range(6):
                embers.append({
                    'rx': random.uniform(-4, 4),
                    'ry': random.uniform(-10, -30),
                    'life': random.randint(20, 60),
                    'max_life': 60,
                    'vx': random.uniform(-0.3, 0.3),
                    'vy': random.uniform(-0.5, -1.2),
                    'size': random.uniform(1.0, 2.5),
                })
            torches.append({
                'x': x, 'y': y,
                'flame_height': random.uniform(18, 28),
                'flicker_offset': random.uniform(0, math.pi * 2),
                'flicker_offset2': random.uniform(0, math.pi * 2),
                'flicker_offset3': random.uniform(0, math.pi * 2),
                'intensity': random.uniform(0.8, 1.0),
                'sway': 0.0,
                'embers': embers,
            })
        # 글로우 캐시 초기화
        self._torch_glow_cache = {}
        self._torch_base_glow_cache = {}
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
        """바닥 프리렌더 - 맥시멈 고퀄리티 리얼 모래 아레나 텍스처"""
        sand = self.colors['sand']              # (155, 130, 95)
        sand_dark = self.colors['sand_dark']    # (125, 105, 75)
        sand_light = self.colors['sand_light']  # (175, 150, 115)
        sand_warm = self.colors['sand_warm']    # (165, 140, 105)
        W, H = self.width, self.height
        cx, cy = W // 2, H // 2

        def clamp(v):
            return max(0, min(255, int(v)))

        # 6-옥타브 사인파 노이즈 (고해상도 Perlin-like)
        _sin = math.sin  # 로컬 참조로 속도 향상
        def multi_noise(x, y, seed=0):
            v = 0.0
            v += 0.30 * _sin(x * 0.019 + y * 0.014 + seed)
            v += 0.22 * _sin(x * 0.038 - y * 0.027 + seed * 1.7)
            v += 0.18 * _sin(x * 0.071 + y * 0.058 + seed * 2.3)
            v += 0.14 * _sin(x * 0.127 - y * 0.098 + seed * 3.1)
            v += 0.10 * _sin(x * 0.211 + y * 0.173 + seed * 4.7)
            v += 0.06 * _sin(x * 0.347 - y * 0.289 + seed * 6.1)
            return max(-1.0, min(1.0, v))

        # ═══════════════════════════════════════════════════════════
        # 1. 베이스 + 2px 연속 노이즈 (밝기 + 색온도 + 채도 3채널)
        # ═══════════════════════════════════════════════════════════
        self.floor_surface.fill(sand)
        noise_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        step = 2
        for gy in range(0, H, step):
            for gx in range(0, W, step):
                n1 = multi_noise(gx, gy, seed=0)        # 밝기
                n2 = multi_noise(gx, gy, seed=50.0)      # 색온도
                n3 = multi_noise(gx, gy, seed=120.0)     # 채도/질감
                bright = n1 * 14.0
                warm = n2 * 7.0
                sat = n3 * 4.0
                r = clamp(sand[0] + bright + warm + sat)
                g = clamp(sand[1] + bright + warm * 0.5 + sat * 0.3)
                b = clamp(sand[2] + bright - warm * 0.4 - sat * 0.5)
                pygame.draw.rect(noise_surf, (r, g, b, 85),
                                 (gx, gy, step, step))
        self.floor_surface.blit(noise_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 2. 방사형 그라데이션 (28링 - 더 부드러움)
        # ═══════════════════════════════════════════════════════════
        grad_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        max_dist = _sin(0) + math.sqrt(cx ** 2 + cy ** 2)
        for ring in range(28, 0, -1):
            frac = ring / 28.0
            radius = int(max_dist * frac)
            pygame.draw.circle(grad_surf, (32, 22, 10, int(5 * (1.0 - frac))),
                               (cx, cy), radius)
        for ring in range(12, 0, -1):
            frac = ring / 12.0
            radius = int(220 * frac)
            pygame.draw.circle(grad_surf, (255, 238, 195, int(3.5 * (1.0 - frac))),
                               (cx, cy), radius)
        self.floor_surface.blit(grad_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 3. 대규모 색상 패치 (6종 색조 영역 - 총 42개)
        # ═══════════════════════════════════════════════════════════
        patch_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(301)
        patch_types = [
            (sand_light, 10, 18, 45, 100, 10),   # 건조 밝은
            (sand_dark, 12, 22, 35, 80, 10),      # 습기 어두운
            ((170, 140, 90), 8, 14, 40, 70, 6),   # 황토
            ((135, 120, 100), 8, 14, 30, 60, 5),  # 회갈색
            ((160, 125, 85), 6, 12, 35, 65, 5),   # 붉은 모래
            ((145, 135, 110), 6, 10, 25, 50, 6),  # 풍화 회색
        ]
        for pc, a_min, a_max, r_min, r_max, count in patch_types:
            for _ in range(count):
                px = random.randint(30, W-30)
                py = random.randint(30, H-30)
                pr = random.randint(r_min, r_max)
                pa = random.randint(a_min, a_max)
                for r in range(pr, 0, -2):
                    frac = r / pr
                    pygame.draw.circle(patch_surf,
                                       (pc[0], pc[1], pc[2], int(pa * frac * frac)),
                                       (px, py), r)
        random.seed()
        self.floor_surface.blit(patch_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 4. 습기 스며든 얼룩 (비정형 다각형 패치)
        # ═══════════════════════════════════════════════════════════
        stain_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(188)
        for _ in range(8):
            scx = random.randint(100, W-100)
            scy = random.randint(100, H-100)
            num_pts = random.randint(6, 10)
            s_radius = random.randint(15, 40)
            pts = []
            for i in range(num_pts):
                a = (i / num_pts) * math.pi * 2
                r = s_radius * random.uniform(0.6, 1.0)
                pts.append((int(scx + r * math.cos(a)), int(scy + r * math.sin(a))))
            sa = random.randint(8, 18)
            # 어두운 습기 얼룩
            pygame.draw.polygon(stain_surf, (sand_dark[0]-8, sand_dark[1]-8,
                                             sand_dark[2]-5, sa), pts)
            # 가장자리 더 어둡게
            pygame.draw.polygon(stain_surf, (sand_dark[0]-15, sand_dark[1]-15,
                                             sand_dark[2]-10, sa // 2), pts, 1)
        random.seed()
        self.floor_surface.blit(stain_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 5. 미세 그림자 노이즈 (불규칙 음영 얼룩 - 깊이감)
        # ═══════════════════════════════════════════════════════════
        shadow_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(777)
        for _ in range(120):
            sx = random.randint(0, W-1)
            sy = random.randint(0, H-1)
            sr = random.randint(3, 12)
            sa = random.randint(4, 12)
            is_dark = random.random() < 0.6
            if is_dark:
                pygame.draw.circle(shadow_surf, (sand_dark[0]-10, sand_dark[1]-10,
                                                  sand_dark[2]-8, sa), (sx, sy), sr)
            else:
                pygame.draw.circle(shadow_surf, (sand_light[0]+5, sand_light[1]+5,
                                                  sand_light[2]+3, sa), (sx, sy), sr)
        random.seed()
        self.floor_surface.blit(shadow_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 6. 모래 알갱이 (5-레이어: 대형 클러스터 + 타원형 + 중간 + 미세 + 석영)
        # ═══════════════════════════════════════════════════════════
        grain_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(42)
        # A: 대형 클러스터 (군집) - 바람 방향으로 타원형
        cluster_centers = [(random.randint(20, W-20), random.randint(20, H-20))
                           for _ in range(40)]
        for ccx, ccy in cluster_centers:
            wind_dir = random.uniform(-0.3, 0.3)  # 바람 방향
            for _ in range(random.randint(6, 14)):
                dx = random.randint(-30, 30)
                dy = random.randint(-20, 20)
                gx = ccx + dx + int(dy * wind_dir)
                gy = ccy + dy
                if 2 <= gx < W-2 and 2 <= gy < H-2:
                    gs = random.randint(2, 4)
                    shade = random.randint(-15, 15)
                    ga = random.randint(35, 70)
                    gc = (clamp(sand[0]+shade), clamp(sand[1]+shade-2),
                          clamp(sand[2]+shade-4), ga)
                    # 타원형 알갱이 (바람에 눕힌 형태)
                    ew = gs + random.randint(0, 2)
                    eh = max(1, gs - random.randint(0, 1))
                    pygame.draw.ellipse(grain_surf, gc,
                                        (gx - ew, gy - eh, ew*2, eh*2))
                    # 하이라이트
                    if gs >= 3:
                        hl = (clamp(sand_light[0]+shade+10), clamp(sand_light[1]+shade+8),
                              clamp(sand_light[2]+shade+5), ga // 3)
                        pygame.draw.ellipse(grain_surf, hl,
                                            (gx - ew + 1, gy - eh, ew, eh))
        # B: 중간 모래 (색온도 변화)
        for _ in range(1000):
            gx = random.randint(1, W-2)
            gy = random.randint(1, H-2)
            gs = random.randint(1, 2)
            shade = random.randint(-22, 22)
            warm_shift = random.randint(-6, 6)
            ga = random.randint(35, 75)
            gc = (clamp(sand[0]+shade+warm_shift), clamp(sand[1]+shade+warm_shift//2),
                  clamp(sand[2]+shade-warm_shift//2), ga)
            pygame.draw.circle(grain_surf, gc, (gx, gy), gs)
        # C: 미세 모래 (고밀도 1px)
        for _ in range(3500):
            gx = random.randint(0, W-1)
            gy = random.randint(0, H-1)
            shade = random.randint(-25, 25)
            ga = random.randint(25, 65)
            grain_surf.set_at((gx, gy), (clamp(sand[0]+shade),
                                         clamp(sand[1]+shade),
                                         clamp(sand[2]+shade), ga))
        # D: 석영/운모 반짝임 클러스터
        mica_centers = [(random.randint(30, W-30), random.randint(30, H-30))
                        for _ in range(20)]
        for mcx, mcy in mica_centers:
            for _ in range(random.randint(3, 8)):
                mx = mcx + random.randint(-15, 15)
                my = mcy + random.randint(-15, 15)
                if 0 <= mx < W and 0 <= my < H:
                    grain_surf.set_at((mx, my),
                                      (random.randint(220, 245),
                                       random.randint(205, 225),
                                       random.randint(165, 185),
                                       random.randint(50, 120)))
        # 개별 산란 석영
        for _ in range(200):
            gx = random.randint(0, W-1)
            gy = random.randint(0, H-1)
            grain_surf.set_at((gx, gy), (235, 220, 180, random.randint(40, 90)))
        random.seed()
        self.floor_surface.blit(grain_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 7. 바람 물결 (밝/어두 쌍 리플 + 그라데이션 폭 밴드 + 흐름선)
        # ═══════════════════════════════════════════════════════════
        wind_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(77)
        # 리플 그룹 (밝은면/어두운면 쌍)
        for group in range(15):
            base_x = random.randint(40, W-130)
            base_y = random.randint(40, H-40)
            angle = random.uniform(-0.3, 0.3)
            length = random.randint(80, 200)
            num_lines = random.randint(5, 10)
            spacing = random.uniform(3.0, 6.5)
            for i in range(num_lines):
                offset_y = (i - num_lines / 2) * spacing
                wave_amp = random.uniform(1.5, 4.5)
                wave_freq = random.uniform(2.0, 4.0)
                # 중심이 두껍고 끝이 가늘어지는 리플
                pts_l, pts_d = [], []
                for seg in range(16):
                    t = seg / 15.0
                    px = base_x + length * t * math.cos(angle)
                    py = base_y + length * t * math.sin(angle) + offset_y
                    wave = _sin(t * math.pi * wave_freq + group * 0.7) * wave_amp
                    pts_l.append((int(px), int(py + wave)))
                    pts_d.append((int(px), int(py + wave + 1.5)))
                # 알파 페이드 (끝으로 갈수록 투명)
                la_base = random.randint(16, 30)
                da_base = random.randint(12, 24)
                # 밝은 능선
                if len(pts_l) >= 2:
                    # 중심부는 두꺼운 선, 양 끝은 가느다란 선
                    mid = len(pts_l) // 2
                    q1, q3 = mid // 2, mid + mid // 2
                    if q1 > 0:
                        pygame.draw.lines(wind_surf,
                                          (clamp(sand_light[0]+5), clamp(sand_light[1]+5),
                                           sand_light[2], la_base // 2),
                                          False, pts_l[:q1+1], 1)
                    if q1 < q3:
                        pygame.draw.lines(wind_surf,
                                          (clamp(sand_light[0]+8), clamp(sand_light[1]+8),
                                           clamp(sand_light[2]+3), la_base),
                                          False, pts_l[q1:q3+1], 2)
                    if q3 < len(pts_l) - 1:
                        pygame.draw.lines(wind_surf,
                                          (clamp(sand_light[0]+5), clamp(sand_light[1]+5),
                                           sand_light[2], la_base // 2),
                                          False, pts_l[q3:], 1)
                # 어두운 골
                if len(pts_d) >= 2:
                    pygame.draw.lines(wind_surf,
                                      (clamp(sand_dark[0]-5), clamp(sand_dark[1]-5),
                                       clamp(sand_dark[2]-3), da_base), False, pts_d, 1)
        # 넓은 흐름선
        for _ in range(25):
            sx = random.randint(10, W-10)
            sy = random.randint(10, H-10)
            l = random.randint(100, 280)
            a = random.uniform(-0.15, 0.15)
            wa = random.randint(8, 18)
            shade = random.randint(-4, 4)
            points = []
            for seg in range(18):
                t = seg / 17.0
                px = sx + l * t
                py = sy + l * t * math.tan(a) + _sin(t * math.pi * 4.5) * 1.8
                points.append((int(px), int(py)))
            if len(points) >= 2:
                pygame.draw.lines(wind_surf,
                                  (clamp(sand[0]+shade), clamp(sand[1]+shade),
                                   clamp(sand[2]+shade), wa), False, points, 1)
        random.seed()
        self.floor_surface.blit(wind_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 8. 모래 소용돌이 자국 (원형 바람 흔적)
        # ═══════════════════════════════════════════════════════════
        swirl_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(444)
        for _ in range(4):
            swx = random.randint(120, W-120)
            swy = random.randint(120, H-120)
            sw_r = random.randint(20, 45)
            num_arcs = random.randint(8, 14)
            for i in range(num_arcs):
                start_a = random.uniform(0, math.pi * 2)
                arc_len = random.uniform(math.pi * 0.5, math.pi * 1.5)
                arc_r = sw_r * random.uniform(0.3, 1.0)
                arc_pts = []
                for seg in range(10):
                    t = seg / 9.0
                    a = start_a + arc_len * t
                    spiral_r = arc_r * (1.0 + t * 0.3)
                    arc_pts.append((int(swx + spiral_r * math.cos(a)),
                                    int(swy + spiral_r * _sin(a))))
                sa = random.randint(10, 20)
                if random.random() < 0.5:
                    sc = (clamp(sand_light[0]+3), clamp(sand_light[1]+3),
                          sand_light[2], sa)
                else:
                    sc = (clamp(sand_dark[0]-3), clamp(sand_dark[1]-3),
                          clamp(sand_dark[2]-2), sa)
                if len(arc_pts) >= 2:
                    pygame.draw.lines(swirl_surf, sc, False, arc_pts, 1)
        random.seed()
        self.floor_surface.blit(swirl_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 9. 모래 언덕 능선 (그라데이션 폭 + 빛/그림자)
        # ═══════════════════════════════════════════════════════════
        dune_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(133)
        for _ in range(8):
            dx = random.randint(50, W-50)
            dy = random.randint(60, H-60)
            d_len = random.randint(100, 320)
            d_angle = random.uniform(-0.25, 0.25)
            d_curve = random.uniform(-25, 25)
            # 능선: 밝은면 (2px) + 어두운면 (1px) + 확산 글로우
            pts_top, pts_mid, pts_bot = [], [], []
            for seg in range(24):
                t = seg / 23.0
                px = dx + d_len * t * math.cos(d_angle)
                base_py = dy + d_len * t * _sin(d_angle) + d_curve * _sin(t * math.pi)
                pts_top.append((int(px), int(base_py - 2)))
                pts_mid.append((int(px), int(base_py)))
                pts_bot.append((int(px), int(base_py + 2)))
            la = random.randint(12, 20)
            da = random.randint(8, 16)
            # 확산 글로우 (넓은 밝은 밴드)
            if len(pts_top) >= 2:
                pygame.draw.lines(dune_surf,
                                  (sand_light[0], sand_light[1], sand_light[2], la // 3),
                                  False, pts_top, 4)
            # 밝은 능선
            if len(pts_mid) >= 2:
                pygame.draw.lines(dune_surf,
                                  (sand_light[0], sand_light[1], sand_light[2], la),
                                  False, pts_mid, 2)
            # 어두운 골
            if len(pts_bot) >= 2:
                pygame.draw.lines(dune_surf,
                                  (sand_dark[0], sand_dark[1], sand_dark[2], da),
                                  False, pts_bot, 1)
        random.seed()
        self.floor_surface.blit(dune_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 10. 자갈/돌 (다각형 불규칙 + 캐스트 섀도우 + 하이라이트)
        # ═══════════════════════════════════════════════════════════
        pebble_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(55)
        stone_pal = [
            (110,95,70), (130,115,85), (120,108,82), (140,125,100),
            (100,88,65), (135,120,95), (115,105,80), (145,130,105),
            (125,100,72), (118,112,90), (142,128,98),
        ]
        # 중/대형 자갈 (다각형)
        for _ in range(35):
            px = random.randint(90, W-90)
            py = random.randint(20, H-20)
            ps = random.randint(3, 5)
            pc = random.choice(stone_pal)
            pa = random.randint(60, 110)
            num_verts = random.randint(5, 8)
            verts = []
            for i in range(num_verts):
                a = (i / num_verts) * math.pi * 2
                r = ps * random.uniform(0.6, 1.0)
                verts.append((int(px + r * math.cos(a)), int(py + r * _sin(a))))
            # 캐스트 섀도우
            sh_verts = [(v[0]+1, v[1]+2) for v in verts]
            pygame.draw.polygon(pebble_surf,
                                (max(0,pc[0]-35), max(0,pc[1]-35),
                                 max(0,pc[2]-30), pa//4), sh_verts)
            # 본체
            pygame.draw.polygon(pebble_surf, (*pc, pa), verts)
            # 밝은 상단면
            top_verts = [(v[0]-1, v[1]-1) for v in verts[:num_verts//2+1]]
            if len(top_verts) >= 2:
                pygame.draw.lines(pebble_surf,
                                  (min(255,pc[0]+40), min(255,pc[1]+40),
                                   min(255,pc[2]+35), pa//2), False, top_verts, 1)
        # 소형 자갈 (원/타원형)
        for _ in range(50):
            px = random.randint(85, W-85)
            py = random.randint(15, H-15)
            ps = random.randint(1, 2)
            pc = random.choice(stone_pal)
            pa = random.randint(50, 90)
            if ps >= 2:
                pygame.draw.ellipse(pebble_surf,
                                    (max(0,pc[0]-30), max(0,pc[1]-30),
                                     max(0,pc[2]-25), pa//4),
                                    (px-ps, py+ps-1, ps*2+1, ps))
            pygame.draw.circle(pebble_surf, (*pc, pa), (px, py), ps)
            if ps >= 2:
                pygame.draw.circle(pebble_surf,
                                   (min(255,pc[0]+35), min(255,pc[1]+35),
                                    min(255,pc[2]+30), pa//2),
                                   (px-1, py-1), max(1, ps-1))
        # 미세 자갈 점
        for _ in range(100):
            px = random.randint(85, W-85)
            py = random.randint(15, H-15)
            pc = random.choice(stone_pal)
            pebble_surf.set_at((px, py), (*pc, random.randint(40, 80)))
        random.seed()
        self.floor_surface.blit(pebble_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 11. 마른 균열 (두께 변화 + 깊이 그림자 + 밝은 엣지 + 분기)
        # ═══════════════════════════════════════════════════════════
        crack_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(99)
        cr_deep = (clamp(sand_dark[0]-20), clamp(sand_dark[1]-20), clamp(sand_dark[2]-15))
        cr_dark = (clamp(sand_dark[0]-12), clamp(sand_dark[1]-12), clamp(sand_dark[2]-10))
        cr_light = (clamp(sand_light[0]+5), clamp(sand_light[1]+5), clamp(sand_light[2]+3))
        for _ in range(14):
            start_x = random.randint(90, W-90)
            start_y = random.randint(70, H-70)
            angle = random.uniform(0, math.pi * 2)
            seg_count = random.randint(5, 12)
            pts = [(start_x, start_y)]
            for _ in range(seg_count):
                seg_len = random.randint(7, 24)
                angle += random.uniform(-0.5, 0.5)
                pts.append((pts[-1][0] + int(seg_len * math.cos(angle)),
                            pts[-1][1] + int(seg_len * _sin(angle))))
            ca = random.randint(24, 42)
            if len(pts) >= 2:
                # 깊이 그림자 (2px 폭)
                deep_pts = [(p[0], p[1]+1) for p in pts]
                pygame.draw.lines(crack_surf, (*cr_deep, ca // 2), False, deep_pts, 2)
                # 메인 균열
                pygame.draw.lines(crack_surf, (*cr_dark, ca), False, pts, 1)
                # 밝은 엣지 (위쪽)
                light_pts = [(p[0], p[1]-1) for p in pts]
                pygame.draw.lines(crack_surf, (*cr_light, ca // 3), False, light_pts, 1)
            # 분기 균열 (더 많은 가지)
            for _ in range(random.randint(2, 4)):
                if len(pts) < 3:
                    break
                bi = random.randint(1, len(pts)-1)
                bx, by = pts[bi]
                ba = angle + random.uniform(-1.3, 1.3)
                b_pts = [(bx, by)]
                for _ in range(random.randint(2, 6)):
                    bl = random.randint(4, 16)
                    ba += random.uniform(-0.7, 0.7)
                    b_pts.append((b_pts[-1][0]+int(bl*math.cos(ba)),
                                  b_pts[-1][1]+int(bl*_sin(ba))))
                if len(b_pts) >= 2:
                    pygame.draw.lines(crack_surf, (*cr_dark, random.randint(15, 30)),
                                      False, b_pts, 1)
        random.seed()
        self.floor_surface.blit(crack_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 12. 닳은 바닥 + 발자국 + 끌린 자국
        # ═══════════════════════════════════════════════════════════
        wear_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        # 중앙 전투 영역 마모
        for r in range(85, 0, -2):
            frac = r / 85.0
            pygame.draw.ellipse(wear_surf,
                                (sand_dark[0], sand_dark[1], sand_dark[2], int(4*(1.0-frac))),
                                (cx-r, cy-int(r*0.55), r*2, int(r*1.1)))
        # 패들 영역 마모
        for pad_y in [55, H-55]:
            for r in range(60, 0, -2):
                frac = r / 60.0
                pygame.draw.ellipse(wear_surf,
                                    (sand_light[0], sand_light[1], sand_light[2], int(3*(1.0-frac))),
                                    (cx-r, pad_y-int(r*0.35), r*2, int(r*0.7)))
        random.seed(222)
        # 발자국 흔적
        for _ in range(20):
            fx = random.randint(110, W-110)
            fy = random.randint(70, H-70)
            fw, fh = random.randint(4, 9), random.randint(3, 6)
            pygame.draw.ellipse(wear_surf,
                                (sand_dark[0], sand_dark[1], sand_dark[2], random.randint(6, 16)),
                                (fx-fw, fy-fh, fw*2, fh*2))
        # 끌린 자국 (짧은 직선 마모)
        for _ in range(8):
            dx = random.randint(120, W-120)
            dy = random.randint(100, H-100)
            dl = random.randint(15, 40)
            da = random.uniform(-0.4, 0.4)
            d_alpha = random.randint(6, 14)
            pts = [(dx, dy), (dx + int(dl * math.cos(da)), dy + int(dl * _sin(da)))]
            pygame.draw.line(wear_surf,
                             (sand_dark[0]-5, sand_dark[1]-5, sand_dark[2]-3, d_alpha),
                             pts[0], pts[1], 2)
        random.seed()
        self.floor_surface.blit(wear_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 13. 비네트 (28링)
        # ═══════════════════════════════════════════════════════════
        vignette_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        vig_max = math.sqrt(cx**2 + cy**2)
        for ring in range(28):
            radius = int(vig_max * (1.0 - ring * 0.028))
            pygame.draw.circle(vignette_surf, (28, 20, 10, int(2 + ring * 1.3)),
                               (cx, cy), radius)
        self.floor_surface.blit(vignette_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 14. 투기장 원형 마킹
        # ═══════════════════════════════════════════════════════════
        mark_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        pygame.draw.circle(mark_surf,
                           (sand_dark[0]+5, sand_dark[1]+5, sand_dark[2]+5, 40),
                           (cx, cy), 280, 2)
        pygame.draw.circle(mark_surf,
                           (sand_dark[0], sand_dark[1], sand_dark[2], 25),
                           (cx, cy), 276, 1)
        self.floor_surface.blit(mark_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 15. 횃불 조명 풀
        # ═══════════════════════════════════════════════════════════
        torch_light_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        left_x = self.GAME_AREA_X + 25
        right_x = self.GAME_AREA_END_X - 25
        for tx, ty in [(left_x,150),(left_x,375),(left_x,600),
                        (right_x,150),(right_x,375),(right_x,600)]:
            for r in range(35, 0, -2):
                frac = r / 35.0
                pygame.draw.circle(torch_light_surf, (255, 200, 100, int(8*frac*frac)),
                                   (tx, ty+10), r)
        self.floor_surface.blit(torch_light_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 16. 석재 타일 경계선
        # ═══════════════════════════════════════════════════════════
        tile_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        tc = (sand_dark[0], sand_dark[1], sand_dark[2], 30)
        ga_x, ga_ex = self.GAME_AREA_X, self.GAME_AREA_END_X
        for inset in [12, 24]:
            pygame.draw.line(tile_surf, tc, (ga_x+inset, 20), (ga_x+inset, H-20), 1)
            pygame.draw.line(tile_surf, tc, (ga_ex-inset, 20), (ga_ex-inset, H-20), 1)
            pygame.draw.line(tile_surf, tc, (ga_x+5, inset), (ga_ex-5, inset), 1)
            pygame.draw.line(tile_surf, tc, (ga_x+5, H-inset), (ga_ex-5, H-inset), 1)
        for ix in [12, 24]:
            for iy in [12, 24]:
                for pt in [(ga_x+ix,iy),(ga_ex-ix,iy),(ga_x+ix,H-iy),(ga_ex-ix,H-iy)]:
                    pygame.draw.circle(tile_surf, tc, pt, 1)
        self.floor_surface.blit(tile_surf, (0, 0))

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

        # ===== 중앙원 (4중 링 + 내부 문양) =====
        # 외곽 큰 원
        pygame.draw.circle(self.arena_surface, line_color, (center_x, center_y), 85, 3)
        # 외곽 이중 원 (새로 추가)
        pygame.draw.circle(self.arena_surface, gold_dark, (center_x, center_y), 90, 1)
        # 중간 장식 링
        pygame.draw.circle(self.arena_surface, ornate, (center_x, center_y), 68, 1)
        # 내부 작은 원
        pygame.draw.circle(self.arena_surface, gold, (center_x, center_y), 50, 2)
        # 최내부 링 (새로 추가)
        pygame.draw.circle(self.arena_surface, gold_dark, (center_x, center_y), 45, 1)

        # ── 중앙원 내부 문양 (은은한 방사형 + 별 모양) ──
        # 방사형 라인 (12방향, 매우 연하게)
        inner_pattern_color = (*gold_dark, 60)  # 반투명
        pattern_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        for angle_deg in range(0, 360, 30):
            a = math.radians(angle_deg)
            ix1 = center_x + int(18 * math.cos(a))
            iy1 = center_y + int(18 * math.sin(a))
            ix2 = center_x + int(43 * math.cos(a))
            iy2 = center_y + int(43 * math.sin(a))
            pygame.draw.line(pattern_surf, inner_pattern_color,
                             (ix1, iy1), (ix2, iy2), 1)
        # 중앙 동심원 (작은 원 2개)
        pygame.draw.circle(pattern_surf, inner_pattern_color,
                           (center_x, center_y), 30, 1)
        pygame.draw.circle(pattern_surf, inner_pattern_color,
                           (center_x, center_y), 15, 1)
        # 중앙 다이아몬드 문양
        cd_sz = 8
        center_diamond = [
            (center_x, center_y - cd_sz),
            (center_x + cd_sz, center_y),
            (center_x, center_y + cd_sz),
            (center_x - cd_sz, center_y),
        ]
        pygame.draw.polygon(pattern_surf, (*gold, 50), center_diamond)
        pygame.draw.polygon(pattern_surf, (*gold_light, 70), center_diamond, 1)
        # 중앙 점
        pygame.draw.circle(pattern_surf, (*gold_light, 80),
                           (center_x, center_y), 3)
        self.arena_surface.blit(pattern_surf, (0, 0))

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

        # 외곽원과 이중원 사이 장식 점 (8방향, 대각선)
        for angle_deg in [45, 135, 225, 315]:
            a = math.radians(angle_deg)
            dot_x = center_x + int(87 * math.cos(a))
            dot_y = center_y + int(87 * math.sin(a))
            pygame.draw.circle(self.arena_surface, gold, (dot_x, dot_y), 1)

        # ===== 코너 L자 장식 (디테일 강화) =====
        corner_size = 28
        margin = 5
        border_y_top = 5
        border_y_bot = self.height - 5

        corners = [
            (margin, border_y_top, 1, 1),           # 좌상
            (self.width - margin, border_y_top, -1, 1),   # 우상
            (margin, border_y_bot, 1, -1),           # 좌하
            (self.width - margin, border_y_bot, -1, -1),  # 우하
        ]
        for cx, cy, dx, dy in corners:
            # 메인 L자
            pygame.draw.line(self.arena_surface, gold,
                             (cx, cy), (cx + corner_size * dx, cy), 2)
            pygame.draw.line(self.arena_surface, gold,
                             (cx, cy), (cx, cy + corner_size * dy), 2)
            # 내부 이중선
            pygame.draw.line(self.arena_surface, gold_dark,
                             (cx + 3 * dx, cy + 3 * dy),
                             (cx + (corner_size - 3) * dx, cy + 3 * dy), 1)
            pygame.draw.line(self.arena_surface, gold_dark,
                             (cx + 3 * dx, cy + 3 * dy),
                             (cx + 3 * dx, cy + (corner_size - 3) * dy), 1)
            # 꼭짓점 다이아몬드 장식
            d_sz = 3
            d_pts = [
                (cx, cy - d_sz * dy),
                (cx + d_sz * dx, cy),
                (cx, cy + d_sz * dy),
                (cx - d_sz * dx, cy),
            ]
            pygame.draw.polygon(self.arena_surface, gold_light, d_pts)
            # 팔 끝 작은 점 장식
            pygame.draw.circle(self.arena_surface, gold_light,
                               (cx + corner_size * dx, cy), 2)
            pygame.draw.circle(self.arena_surface, gold_light,
                               (cx, cy + corner_size * dy), 2)

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

        # ===== 1. 다층 테두리 프레임 (두꺼운 파피루스 스타일 ~18px) =====
        t = 18  # 테두리 총 두께

        # 파피루스 색상
        papyrus = (145, 125, 85)
        papyrus_light = (165, 145, 105)
        papyrus_dark = (115, 95, 65)

        # 파피루스 밴드 채움 (4변)
        pygame.draw.rect(surf, papyrus, (bx, by, bw, t))
        pygame.draw.rect(surf, papyrus, (bx, bb - t, bw, t))
        pygame.draw.rect(surf, papyrus, (bx, by + t, t, bh - t * 2))
        pygame.draw.rect(surf, papyrus, (br - t, by + t, t, bh - t * 2))

        # 외곽 어두운 테두리 (바깥 2줄)
        pygame.draw.rect(surf, border_outer, (bx, by, bw, bh), 2)
        pygame.draw.rect(surf, papyrus_dark, (bx + 2, by + 2, bw - 4, bh - 4), 1)
        # 금동 외곽선
        pygame.draw.rect(surf, border_mid, (bx + 3, by + 3, bw - 6, bh - 6), 2)
        # 중간 파피루스 질감선
        pygame.draw.rect(surf, papyrus_light, (bx + 6, by + 6, bw - 12, bh - 12), 1)
        pygame.draw.rect(surf, papyrus_dark, (bx + 9, by + 9, bw - 18, bh - 18), 1)
        # 내부 금선 (안쪽 경계)
        pygame.draw.rect(surf, border_mid, (bx + t - 4, by + t - 4, bw - (t - 4) * 2, bh - (t - 4) * 2), 2)
        # 가장 안쪽 밝은 금 하이라이트
        pygame.draw.rect(surf, border_inner, (bx + t - 1, by + t - 1, bw - (t - 1) * 2, bh - (t - 1) * 2), 1)

        # 파피루스 섬유 질감 (미세한 수평/수직선)
        random.seed(333)
        for _ in range(40):
            side = random.randint(0, 3)
            if side == 0:  # 상단
                fx = random.randint(bx + 8, br - 8)
                fy = random.randint(by + 3, by + t - 4)
                fl = random.randint(10, 35)
                pygame.draw.line(surf, papyrus_light, (fx, fy), (fx + fl, fy + random.randint(-1, 1)), 1)
            elif side == 1:  # 하단
                fx = random.randint(bx + 8, br - 8)
                fy = random.randint(bb - t + 3, bb - 4)
                fl = random.randint(10, 35)
                pygame.draw.line(surf, papyrus_light, (fx, fy), (fx + fl, fy + random.randint(-1, 1)), 1)
            elif side == 2:  # 좌측
                fx = random.randint(bx + 3, bx + t - 4)
                fy = random.randint(by + t + 5, bb - t - 5)
                fl = random.randint(10, 30)
                pygame.draw.line(surf, papyrus_light, (fx, fy), (fx + random.randint(-1, 1), fy + fl), 1)
            else:  # 우측
                fx = random.randint(br - t + 3, br - 4)
                fy = random.randint(by + t + 5, bb - t - 5)
                fl = random.randint(10, 30)
                pygame.draw.line(surf, papyrus_light, (fx, fy), (fx + random.randint(-1, 1), fy + fl), 1)
        random.seed()

        # ===== 2. 이집트 문양 패턴 (4종 심볼 순환 배치) =====
        pattern_spacing = 36
        band_mid = t // 2  # 밴드 중심 (9px)
        # 심볼 종류: 0=로터스, 1=호루스의눈, 2=앙크, 3=스카라베

        def draw_hiero_symbol(sx, sy, sym_type, facing):
            """히에로글리프 심볼 그리기. facing: 'up','down','left','right'"""
            if sym_type == 0:
                # 로터스 (3잎 부채꼴)
                base_angle = {'up': -90, 'down': 90, 'left': 0, 'right': 180}[facing]
                for leaf in [-30, 0, 30]:
                    a = math.radians(leaf + base_angle)
                    pygame.draw.line(surf, hiero, (sx, sy),
                                     (sx + int(5 * math.cos(a)), sy + int(5 * math.sin(a))), 1)
                pygame.draw.circle(surf, hiero_dark, (sx, sy), 1)
            elif sym_type == 1:
                # 호루스의 눈 (아몬드형 눈 + 눈물방울)
                if facing in ('up', 'down'):
                    # 수평 눈
                    pygame.draw.ellipse(surf, hiero, (sx - 5, sy - 2, 10, 4), 1)
                    pygame.draw.circle(surf, hiero_dark, (sx, sy), 1)  # 동공
                    # 눈물방울 (아래쪽 꼬리)
                    dy = 1 if facing == 'up' else -1
                    pygame.draw.line(surf, hiero, (sx + 2, sy + dy), (sx + 4, sy + 4 * dy), 1)
                    pygame.draw.line(surf, hiero, (sx + 4, sy + 4 * dy), (sx + 3, sy + 5 * dy), 1)
                else:
                    # 수직 눈
                    pygame.draw.ellipse(surf, hiero, (sx - 2, sy - 5, 4, 10), 1)
                    pygame.draw.circle(surf, hiero_dark, (sx, sy), 1)
                    dx = 1 if facing == 'left' else -1
                    pygame.draw.line(surf, hiero, (sx + dx, sy + 2), (sx + 4 * dx, sy + 4), 1)
                    pygame.draw.line(surf, hiero, (sx + 4 * dx, sy + 4), (sx + 5 * dx, sy + 3), 1)
            elif sym_type == 2:
                # 앙크 (생명의 십자가)
                if facing in ('up', 'down'):
                    # 수직 앙크
                    d = -1 if facing == 'up' else 1
                    pygame.draw.ellipse(surf, hiero, (sx - 2, sy - 5 * d, 5, 4), 1)  # 고리
                    pygame.draw.line(surf, hiero, (sx, sy - 2 * d), (sx, sy + 5 * d), 1)  # 세로줄
                    pygame.draw.line(surf, hiero, (sx - 3, sy), (sx + 3, sy), 1)  # 가로줄
                else:
                    # 수평 앙크
                    d = -1 if facing == 'left' else 1
                    pygame.draw.ellipse(surf, hiero, (sx - 5 * d, sy - 2, 4, 5), 1)
                    pygame.draw.line(surf, hiero, (sx - 2 * d, sy), (sx + 5 * d, sy), 1)
                    pygame.draw.line(surf, hiero, (sx, sy - 3), (sx, sy + 3), 1)
            elif sym_type == 3:
                # 스카라베 (풍뎅이 실루엣)
                if facing in ('up', 'down'):
                    pygame.draw.ellipse(surf, hiero_dark, (sx - 3, sy - 2, 6, 5))  # 몸통
                    pygame.draw.ellipse(surf, hiero, (sx - 3, sy - 2, 6, 5), 1)   # 외곽선
                    pygame.draw.circle(surf, hiero, (sx, sy - 4), 2, 1)             # 머리
                    # 날개 (좌우 짧은 선)
                    pygame.draw.line(surf, hiero, (sx - 3, sy - 1), (sx - 6, sy - 3), 1)
                    pygame.draw.line(surf, hiero, (sx + 3, sy - 1), (sx + 6, sy - 3), 1)
                else:
                    pygame.draw.ellipse(surf, hiero_dark, (sx - 2, sy - 3, 5, 6))
                    pygame.draw.ellipse(surf, hiero, (sx - 2, sy - 3, 5, 6), 1)
                    dx = -1 if facing == 'left' else 1
                    pygame.draw.circle(surf, hiero, (sx - 4 * dx, sy), 2, 1)
                    pygame.draw.line(surf, hiero, (sx - dx, sy - 3), (sx - 3 * dx, sy - 6), 1)
                    pygame.draw.line(surf, hiero, (sx - dx, sy + 3), (sx - 3 * dx, sy + 6), 1)

        # 상단 변
        idx = 0
        for px in range(bx + 25, br - 25, pattern_spacing):
            draw_hiero_symbol(px, by + band_mid, idx % 4, 'up')
            idx += 1
            # 심볼 사이 구분 점선
            if px + pattern_spacing // 2 < br - 25:
                for dot in range(3):
                    dx = px + pattern_spacing // 2 - 4 + dot * 4
                    pygame.draw.circle(surf, hiero_dark, (dx, by + band_mid), 0)

        # 하단 변
        idx = 2  # 상단과 다른 심볼부터 시작
        for px in range(bx + 25, br - 25, pattern_spacing):
            draw_hiero_symbol(px, bb - band_mid, idx % 4, 'down')
            idx += 1
            if px + pattern_spacing // 2 < br - 25:
                for dot in range(3):
                    dx = px + pattern_spacing // 2 - 4 + dot * 4
                    pygame.draw.circle(surf, hiero_dark, (dx, bb - band_mid), 0)

        # 좌측 변
        idx = 1
        for py in range(by + 25, bb - 25, pattern_spacing):
            draw_hiero_symbol(bx + band_mid, py, idx % 4, 'left')
            idx += 1

        # 우측 변
        idx = 3
        for py in range(by + 25, bb - 25, pattern_spacing):
            draw_hiero_symbol(br - band_mid, py, idx % 4, 'right')
            idx += 1

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

        # 횃불 업데이트 (고퀄리티 멀티 레이어 애니메이션)
        for torch in self.torches:
            off1 = torch['flicker_offset']
            off2 = torch['flicker_offset2']
            off3 = torch['flicker_offset3']
            # 다중 사인파 합성으로 자연스러운 불꽃 흔들림
            torch['intensity'] = (0.7
                + 0.15 * math.sin(self.time * 8 + off1)
                + 0.10 * math.sin(self.time * 13 + off2)
                + 0.05 * math.sin(self.time * 21 + off3))
            torch['flame_height'] = (22
                + 5 * math.sin(self.time * 6 + off1)
                + 3 * math.sin(self.time * 10 + off2)
                + 2 * math.sin(self.time * 17 + off3))
            # 좌우 흔들림 (바람 효과)
            torch['sway'] = (
                2.0 * math.sin(self.time * 3.5 + off1)
                + 1.0 * math.sin(self.time * 7 + off2))
            # 엠버 파티클 업데이트
            for ember in torch['embers']:
                ember['ry'] += ember['vy']
                ember['rx'] += ember['vx'] + 0.1 * math.sin(self.time * 5 + ember['rx'])
                ember['life'] -= 1
                if ember['life'] <= 0:
                    ember['rx'] = random.uniform(-4, 4)
                    ember['ry'] = random.uniform(-8, -14)
                    ember['life'] = random.randint(25, 60)
                    ember['max_life'] = ember['life']
                    ember['vx'] = random.uniform(-0.3, 0.3)
                    ember['vy'] = random.uniform(-0.5, -1.2)
                    ember['size'] = random.uniform(1.0, 2.5)

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

        # 열기류 파티클 업데이트 (횃불 근처 아지랑이)
        for hs in self.heat_shimmers:
            hs['ry'] -= 0.4  # 위로 상승
            hs['rx'] += hs['drift'] + 0.15 * math.sin(self.time * 4 + hs['rx'])
            hs['life'] -= 1
            if hs['life'] <= 0:
                hs['rx'] = random.uniform(-6, 6)
                hs['ry'] = random.uniform(-15, -22)
                hs['life'] = random.randint(40, 90)
                hs['max_life'] = hs['life']
                hs['drift'] = random.uniform(-0.2, 0.2)
                hs['size'] = random.uniform(1.5, 3.0)

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
    def trigger_gods_judgment(self, forced_variant=None):
        """신의심판 이벤트 시작. forced_variant로 변형 지정 가능 ('earthquake'/'lightning'/'wind')"""
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
        # 변형 초기화
        if forced_variant and forced_variant in ('earthquake', 'lightning', 'wind'):
            self.judgment_variant = forced_variant
        else:
            self.judgment_variant = random.choice(['earthquake', 'lightning', 'wind'])
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
        # 바람의 분노 상태 초기화
        self.judgment_wind_sandstorms = []
        self.judgment_wind_particles = []
        self.judgment_fan_swing_progress = 0.0
        self.judgment_wind_charge_intensity = 0.0
        self.judgment_fan_energy_particles = []
        self.judgment_fan_swing_started = False
        self.judgment_sandstorm_hit_top = False
        self.judgment_sandstorm_hit_bottom = False
        self.judgment_sandstorm_captured = None
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

        # 라운드 전환 또는 텍스트 표시 중에는 페이즈 타이머 동결 (애니메이션 일시정지)
        if self.judgment_logic_paused or self.judgment_text_display_paused:
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
            # 상승 중 화면 흔들림 (초반 강하고 후반 약해짐, 땅을 뚫고 올라오는 진동)
            if progress < 0.8:
                self.judgment_shake_intensity = 0.2 * (1.0 - progress * 0.8)
            else:
                fade_p = (progress - 0.8) / 0.2
                self.judgment_shake_intensity = 0.2 * 0.36 * (1.0 - fade_p)
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
                self.judgment_shake_intensity = 0.0
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
            # ── 충전 이펙트 (팔 다 올린 후 70%부터만 발동) ──
            s = self.judgment_scale
            if progress > 0.7:
                charge_p = (progress - 0.7) / 0.3
                if self.judgment_variant == 'wind':
                    # 바람 충전: 모래색 소용돌이 파티클
                    self.judgment_wind_charge_intensity = min(1.0, charge_p)
                    r_shoulder_x = cx + int(10 * s)
                    r_shoulder_y = cy - int(19 * s)
                    spark_rate = int(charge_p * 4) + (1 if random.random() < charge_p * 0.6 else 0)
                    for _ in range(spark_rate):
                        angle = random.uniform(0, math.pi * 2)
                        dist = random.uniform(5, 20) * s
                        speed = random.uniform(2.0, 5.0) * s
                        self.judgment_wind_particles.append({
                            'x': r_shoulder_x + math.cos(angle) * dist,
                            'y': r_shoulder_y + math.sin(angle) * dist,
                            'vx': math.cos(angle + 1.5) * speed,
                            'vy': math.sin(angle + 1.5) * speed,
                            'size': random.uniform(1.0, 3.0) * s * 0.4,
                            'life': random.uniform(0.3, 0.7),
                            'color': random.choice([
                                (210, 180, 105), (220, 190, 120),
                                (195, 170, 110), (180, 155, 95),
                            ]),
                        })
                else:
                    # 번개/대지 충전: 기존 번개 스파크
                    base_intensity = charge_p * 0.7
                    flash_freq = 6.0 + charge_p * 14.0
                    flash_wave = max(0, math.sin(self.judgment_timer * flash_freq * math.pi))
                    flash_boost = flash_wave * charge_p * 0.3
                    self.judgment_bolt_intensity = min(1.0, base_intensity + flash_boost)
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
                self.judgment_wind_charge_intensity = 0.0
            # 스파크/바람 파티클 업데이트
            for sp in self.judgment_bolt_sparks:
                sp['x'] += sp['vx'] * dt * 60
                sp['y'] += sp['vy'] * dt * 60
                sp['life'] -= dt
                sp['size'] = max(0, sp['size'] - dt * 2)
            self.judgment_bolt_sparks = [sp for sp in self.judgment_bolt_sparks if sp['life'] > 0]
            for wp in self.judgment_wind_particles:
                wp['x'] += wp['vx'] * dt * 60
                wp['y'] += wp['vy'] * dt * 60
                wp['life'] -= dt
                wp['size'] = max(0, wp['size'] - dt * 1.5)
            self.judgment_wind_particles = [wp for wp in self.judgment_wind_particles if wp['life'] > 0]
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
                elif self.judgment_variant == 'wind':
                    # 바람의 분노: 부채 휘두르기 페이즈로
                    self.judgment_phase = self.JUDGMENT_FAN_SWING
                    self.judgment_timer = 0.0
                    self.judgment_fan_swing_progress = 0.0
                    self.judgment_fan_swing_started = True  # 핸들러에서 텍스트 표시용
                    self.judgment_wind_charge_intensity = 1.0
                    print(f"[신의심판] ARM_RAISE → FAN_SWING 전환")
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
                self.judgment_shake_intensity = 0.8
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
            # 화면 흔들림 (폭발 전체 구간에 걸쳐 강하게)
            if progress < 0.3:
                # 초반: 최대 강도 (감전 충격)
                self.judgment_shake_intensity = 0.8
            elif progress < 0.7:
                # 중반: 강한 진동 유지
                mid_p = (progress - 0.3) / 0.4
                self.judgment_shake_intensity = 0.8 - mid_p * 0.3
            else:
                # 후반: 점차 감소
                fade_p = (progress - 0.7) / 0.3
                self.judgment_shake_intensity = 0.5 * (1.0 - fade_p)
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

        elif self.judgment_phase == self.JUDGMENT_FAN_SWING:
            # 1.2초: 부채 휘두르기 → 모래바람 발사
            progress = min(1.0, self.judgment_timer / self.FAN_SWING_DURATION)
            s = self.judgment_scale
            # 팔 애니메이션: 준비(0~15%) → 와인드업(15~40%) → 스윙(40~75%) → 팔로우스루(75~100%)
            if progress < 0.15:
                # 준비: 미세한 긴장감 (ease-in, 양팔에서 서서히 기운 모으기)
                prep_p = progress / 0.15
                ease_prep = prep_p * prep_p  # ease-in
                self.judgment_right_arm_progress = 1.0 + ease_prep * 0.05
                self.judgment_left_arm_progress = 1.0
                self.judgment_fan_swing_progress = 0.0
            elif progress < 0.4:
                # 와인드업: 오른팔 뒤로 당기기 (ease-in-out)
                wind_p = (progress - 0.15) / 0.25
                ease_wind = wind_p * wind_p * (3.0 - 2.0 * wind_p)
                self.judgment_right_arm_progress = 1.05 + ease_wind * 0.15
                self.judgment_left_arm_progress = 1.0
                self.judgment_fan_swing_progress = 0.0
            elif progress < 0.75:
                # 스윙: 큰 휘두르기
                swing_p = (progress - 0.4) / 0.35
                ease_swing = swing_p * swing_p * (3.0 - 2.0 * swing_p)
                self.judgment_right_arm_progress = 1.2 - ease_swing * 1.8
                self.judgment_left_arm_progress = max(0, 1.0 - swing_p * 1.2)
                self.judgment_fan_swing_progress = ease_swing
            else:
                # 팔로우스루: 관성으로 흘러감
                follow_p = (progress - 0.75) / 0.25
                self.judgment_right_arm_progress = max(-0.2, -0.6 + follow_p * 0.4)
                self.judgment_left_arm_progress = 0.0
                self.judgment_fan_swing_progress = 1.0
            # 바람 충전 강도 감소 (에너지 방출)
            if progress > 0.5:
                self.judgment_wind_charge_intensity = max(0, 1.0 - (progress - 0.5) * 3.0)
            # 바람 파티클 생성 (스윙 중)
            if 0.3 < progress < 0.8:
                for _ in range(int(3 * s)):
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(3, 8) * s
                    self.judgment_wind_particles.append({
                        'x': float(cx) + random.uniform(-10 * s, 10 * s),
                        'y': float(cy) + random.uniform(-15 * s, 5 * s),
                        'vx': math.cos(angle) * speed,
                        'vy': math.sin(angle) * speed,
                        'size': random.uniform(1.5, 3.5) * s * 0.3,
                        'life': random.uniform(0.3, 0.8),
                        'color': random.choice([
                            (210, 180, 105), (220, 190, 120),
                            (195, 170, 110), (240, 210, 140),
                        ]),
                    })
            # 50% 시점에서 나선형 소용돌이 1개 발사 (달팽이처럼 원으로 퍼져나감)
            if progress >= 0.5 and len(self.judgment_wind_sandstorms) == 0:
                start_angle = random.uniform(0, math.pi * 2)
                self.judgment_wind_sandstorms.append({
                    'x': float(cx),
                    'y': float(cy),
                    # 나선형 궤적 파라미터
                    'spiral_cx': float(cx),          # 나선 중심 X
                    'spiral_cy': float(cy),          # 나선 중심 Y
                    'spiral_angle': start_angle,     # 현재 각도 (rad)
                    'spiral_radius': 15.0,           # 현재 반경 (작게 시작)
                    'spiral_angular_speed': 3.2,     # 각속도 (rad/s)
                    'spiral_expansion_rate': 42.0,   # 반경 확장 속도 (px/s)
                    'spiral_max_radius': 310.0,      # 최대 반경
                    # 기존 호환용 (info 반환 등)
                    'base_vx': 0.0,
                    'base_vy': 0.0,
                    'vx': 0.0,
                    'vy': 0.0,
                    'drift_vx': 0.0,
                    'angle_deg': 0,
                    'rotation': random.uniform(0, 360),
                    'spin_speed': random.uniform(320, 450),
                    'base_size': 50.0 * s,           # 약간 더 큰 시작 크기
                    'size': 50.0 * s,
                    'growth_scale': 1.0,
                    'alpha': 255,
                    'age': 0.0,
                    'dead': False,
                    'fading': False,
                    'hit_top': False,
                    'hit_bottom': False,
                    'has_captured': False,
                    'capture_cooldown': 0.0,
                    'wobble_phase': random.uniform(0, math.pi * 2),
                    'wobble_speed': random.uniform(3.0, 4.5),
                    'drift_target': 0.0,
                    'drift_timer': 0.0,
                    'drift_interval': 0.5,
                    'jitter_x': 0.0,
                    'trail_particles': [],
                })
                # 발사 시 화면 흔들림 + 플래시
                self.judgment_shake_intensity = 0.4
                self.judgment_flash_alpha = 100
            # 화면 흔들림 감쇠 (스윙 후)
            if progress > 0.5:
                self.judgment_shake_intensity = max(0, 0.4 * (1.0 - (progress - 0.5) * 4.0))
            # 바람 파티클 업데이트
            for wp in self.judgment_wind_particles:
                wp['x'] += wp['vx'] * dt * 60
                wp['y'] += wp['vy'] * dt * 60
                wp['life'] -= dt
                wp['size'] = max(0, wp['size'] - dt * 1.5)
            self.judgment_wind_particles = [wp for wp in self.judgment_wind_particles if wp['life'] > 0]
            # 플래시 감소
            self.judgment_flash_alpha = max(0, self.judgment_flash_alpha - int(dt * 400))
            if progress >= 1.0:
                self.judgment_phase = self.JUDGMENT_SANDSTORM
                self.judgment_timer = 0.0
                self.judgment_shake_intensity = 0.0
                self.judgment_flash_alpha = 0
                self.judgment_wind_charge_intensity = 0.0
                print(f"[신의심판] FAN_SWING → SANDSTORM 전환")

        elif self.judgment_phase == self.JUDGMENT_SANDSTORM:
            # 7초: 나선형 소용돌이 1개가 달팽이처럼 원으로 퍼져나감
            progress = min(1.0, self.judgment_timer / self.SANDSTORM_DURATION)
            s = self.judgment_scale
            # 천천히 부채질 (FAN_SWING 끝에서 자연스럽게 이어지는 왕복)
            self.judgment_left_arm_progress = 0.0
            # FAN_SWING 종료 시 값: right_arm=-0.2, fan_swing=1.0
            # 부채질 목표 범위: right_arm=0.3~0.9, fan_swing=0.5
            BLEND_TIME = 1.2  # 블렌드 시간 (초)
            blend_t = min(1.0, self.judgment_timer / BLEND_TIME)
            blend_ease = blend_t * blend_t * (3.0 - 2.0 * blend_t)  # smoothstep
            # 부채질 오실레이션 (sin 파형, ~1.8초 주기)
            fan_osc = math.sin(self.judgment_timer * 3.5)
            target_arm = 0.6 + 0.3 * fan_osc
            target_fan = 0.5
            if progress < 0.85:
                # FAN_SWING 끝값에서 부채질로 블렌딩
                self.judgment_right_arm_progress = -0.2 + (target_arm - (-0.2)) * blend_ease
                self.judgment_fan_swing_progress = 1.0 + (target_fan - 1.0) * blend_ease
                # 바람 충전 강도: 부채질 리듬 (블렌드 후 시작)
                self.judgment_wind_charge_intensity = blend_ease * (0.3 + 0.2 * max(0, fan_osc))
            else:
                # 85~100%: 부채질 멈추고 팔 원위치
                stop_p = (progress - 0.85) / 0.15
                ease_stop = stop_p * stop_p  # ease-in
                last_arm = -0.2 + (target_arm - (-0.2)) * blend_ease
                self.judgment_right_arm_progress = last_arm * (1.0 - ease_stop)
                self.judgment_fan_swing_progress = target_fan * (1.0 - ease_stop)
                self.judgment_wind_charge_intensity = 0.3 * (1.0 - ease_stop)

            # ── 부채 주변 바람 에너지 파티클 생성/업데이트 ──
            if progress < 0.85 and blend_ease > 0.3:
                # 부채질 중: 부채 주변에 바람 에너지 생성
                spawn_rate = 2 + int(3 * blend_ease)
                for _ in range(spawn_rate):
                    orbit_angle = random.uniform(0, math.pi * 2)
                    orbit_dist = random.uniform(6, 18) * s
                    orbit_speed = random.uniform(3.0, 6.0) * random.choice([-1, 1])
                    self.judgment_fan_energy_particles.append({
                        'angle': orbit_angle,
                        'dist': orbit_dist,
                        'speed': orbit_speed,         # 공전 속도 (rad/s)
                        'size': random.uniform(1.0, 3.0) * s * 0.3,
                        'life': random.uniform(0.4, 1.0),
                        'alpha': random.randint(140, 220),
                        'color': random.choice([
                            (210, 195, 130), (230, 210, 150),
                            (190, 175, 120), (255, 240, 180),
                        ]),
                        'sparkle_phase': random.uniform(0, math.pi * 2),
                    })
            # 에너지 파티클 업데이트
            for ep in self.judgment_fan_energy_particles:
                ep['angle'] += ep['speed'] * dt
                ep['life'] -= dt
                # 반짝거림 (alpha가 사인파로 맥동)
                sparkle = 0.5 + 0.5 * math.sin(ep['sparkle_phase'] + self.time * 12)
                ep['alpha'] = int(ep['alpha'] * 0.98) if ep['life'] > 0.2 else int(ep['alpha'] * 0.9)
                ep['current_alpha'] = max(0, int(ep['alpha'] * sparkle))
                ep['size'] = max(0, ep['size'] - dt * 0.3)
            self.judgment_fan_energy_particles = [
                ep for ep in self.judgment_fan_energy_particles if ep['life'] > 0 and ep['size'] > 0
            ]

            # ── 나선형 소용돌이 상수 ──
            VORTEX_GROWTH_RATE = 0.15    # 초당 15% 크기 성장
            VORTEX_LIFETIME = 7.0        # 수명 (SANDSTORM_DURATION과 동일)
            VORTEX_FADE_DURATION = 1.5   # 소멸 페이드 시간
            GAME_LEFT = 80
            GAME_RIGHT = 680
            GAME_TOP = 0
            GAME_BOTTOM = 750

            # 모래바람 업데이트
            all_dead = True
            for storm in self.judgment_wind_sandstorms:
                if storm['dead']:
                    continue
                all_dead = False
                storm['age'] += dt

                # ── 크기 성장 ──
                storm['growth_scale'] = 1.0 + VORTEX_GROWTH_RATE * storm['age']
                grown_size = storm['base_size'] * storm['growth_scale']

                # ── 수명 관리 ──
                fade_start = VORTEX_LIFETIME - VORTEX_FADE_DURATION
                if storm['age'] >= VORTEX_LIFETIME:
                    storm['dead'] = True
                    continue
                elif storm['age'] >= fade_start:
                    storm['fading'] = True
                    fade_progress = (storm['age'] - fade_start) / VORTEX_FADE_DURATION
                    storm['alpha'] = max(0, int(255 * (1 - fade_progress)))
                    storm['spin_speed'] *= (1 - 0.5 * dt)
                    storm['size'] = max(8, grown_size * (1 - fade_progress * 0.4))
                else:
                    storm['size'] = grown_size

                # 포획 쿨다운 감소
                if storm['capture_cooldown'] > 0:
                    storm['capture_cooldown'] -= dt

                # ── 나선형 궤적 업데이트 (달팽이처럼 원으로 퍼져나감) ──
                speed_mult = 1.0
                if storm.get('fading'):
                    fp = (storm['age'] - fade_start) / VORTEX_FADE_DURATION
                    speed_mult = max(0.2, 1 - fp * 0.6)

                # 각도 증가 (일정한 각속도로 회전)
                storm['spiral_angle'] += storm['spiral_angular_speed'] * dt * speed_mult
                # 반경 확장 (점점 넓어지는 원)
                if storm['spiral_radius'] < storm['spiral_max_radius']:
                    storm['spiral_radius'] += storm['spiral_expansion_rate'] * dt * speed_mult
                    storm['spiral_radius'] = min(storm['spiral_radius'], storm['spiral_max_radius'])

                # 나선 위치 계산
                new_x = storm['spiral_cx'] + math.cos(storm['spiral_angle']) * storm['spiral_radius']
                new_y = storm['spiral_cy'] + math.sin(storm['spiral_angle']) * storm['spiral_radius']

                # 벽 클램핑 (나선이 게임 영역 안에 유지)
                margin = storm['size'] * 0.5
                new_x = max(GAME_LEFT + margin, min(GAME_RIGHT - margin, new_x))
                new_y = max(GAME_TOP + margin, min(GAME_BOTTOM - margin, new_y))

                # 속도 계산 (info 반환 + 트레일 파티클용)
                if dt > 0:
                    storm['vx'] = (new_x - storm['x']) / dt
                    storm['vy'] = (new_y - storm['y']) / dt
                    storm['base_vx'] = storm['vx']
                    storm['base_vy'] = storm['vy']

                storm['x'] = new_x
                storm['y'] = new_y

                # 회전 (시각적)
                storm['rotation'] += storm['spin_speed'] * dt

                # 트레일 파티클 생성 (나선 궤적을 따라 모래 흔적)
                particle_count = 2 if storm.get('fading') else 6
                for _ in range(particle_count):
                    t_angle = random.uniform(0, math.pi * 2)
                    t_dist = random.uniform(4, storm['size'] * 1.2)
                    orbit_speed = random.uniform(80, 180)
                    storm['trail_particles'].append({
                        'x': storm['x'] + math.cos(t_angle) * t_dist,
                        'y': storm['y'] + math.sin(t_angle) * t_dist,
                        'vx': math.cos(t_angle + math.pi / 2) * orbit_speed + random.uniform(-30, 30),
                        'vy': math.sin(t_angle + math.pi / 2) * orbit_speed * 0.5 + random.uniform(-20, 20),
                        'size': random.uniform(2, 7),
                        'life': random.uniform(0.5, 1.2),
                        'color': random.choice([
                            (210, 180, 105), (195, 170, 110),
                            (220, 190, 120), (160, 130, 80),
                        ]),
                    })
                # 큰 먼지 덩어리 (나선 경로에 흩뿌림)
                dust_chance = 0.15 if storm.get('fading') else 0.45
                if random.random() < dust_chance:
                    d_angle = random.uniform(0, math.pi * 2)
                    d_dist = random.uniform(storm['size'] * 0.5, storm['size'] * 1.8)
                    storm['trail_particles'].append({
                        'x': storm['x'] + math.cos(d_angle) * d_dist,
                        'y': storm['y'] + math.sin(d_angle) * d_dist,
                        'vx': random.uniform(-50, 50),
                        'vy': random.uniform(-30, 30),
                        'size': random.uniform(6, 14),
                        'life': random.uniform(0.6, 1.2),
                        'color': (195, 170, 110),
                    })
                # 트레일 업데이트
                for tp in storm['trail_particles']:
                    tp['x'] += tp['vx'] * dt
                    tp['y'] += tp['vy'] * dt
                    tp['life'] -= dt
                storm['trail_particles'] = [tp for tp in storm['trail_particles'] if tp['life'] > 0]

                # 히트 판정: 상단 패들 영역 (Y < 65)
                if storm['y'] < 65 and not storm['hit_top']:
                    storm['hit_top'] = True
                    self.judgment_sandstorm_hit_top = True
                # 히트 판정: 하단 패들 영역 (Y > 710)
                if storm['y'] > 710 and not storm['hit_bottom']:
                    storm['hit_bottom'] = True
                    self.judgment_sandstorm_hit_bottom = True

            # 나선 회전 중 지속적 화면 흔들림
            if not all_dead and progress < 0.85:
                # 나선 반경이 커질수록 흔들림 강해짐
                storm_ref = self.judgment_wind_sandstorms[0] if self.judgment_wind_sandstorms else None
                if storm_ref and not storm_ref['dead']:
                    radius_ratio = storm_ref.get('spiral_radius', 0) / storm_ref.get('spiral_max_radius', 310)
                    self.judgment_shake_intensity = 0.05 + 0.15 * radius_ratio
                else:
                    self.judgment_shake_intensity = 0.05
            else:
                self.judgment_shake_intensity = max(0, self.judgment_shake_intensity - dt * 0.5)
            if progress >= 1.0 or all_dead:
                self.judgment_phase = self.JUDGMENT_RETURN
                self.judgment_timer = 0.0
                self.judgment_shake_intensity = 0.0
                self.judgment_slam_progress = 0.0
                self.judgment_left_arm_progress = 0.0
                self.judgment_right_arm_progress = 0.0
                self.judgment_wind_sandstorms.clear()
                self.judgment_wind_particles.clear()
                self.judgment_fan_energy_particles.clear()
                self.judgment_wind_charge_intensity = 0.0
                print(f"[신의심판] SANDSTORM → RETURN 전환")

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
            # 하강 중 화면 흔들림 (번개의 분노는 폭발 후 흔들림 불필요)
            if self.judgment_variant == 'lightning':
                self.judgment_shake_intensity = 0.0
            elif progress < 0.5:
                # 초반~중반: 강한 진동 (무게감 있는 하강)
                self.judgment_shake_intensity = 0.25 * (1.0 - progress * 0.6)
            else:
                # 후반: 점차 약해지며 사라짐
                fade_p = (progress - 0.5) / 0.5
                self.judgment_shake_intensity = 0.25 * 0.7 * (1.0 - fade_p)
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
                # 바람 상태 초기화
                self.judgment_wind_sandstorms.clear()
                self.judgment_wind_particles.clear()
                self.judgment_fan_swing_progress = 0.0
                self.judgment_wind_charge_intensity = 0.0
                self.judgment_fan_swing_started = False
                self.judgment_sandstorm_hit_top = False
                self.judgment_sandstorm_hit_bottom = False
                self.judgment_sandstorm_captured = None

    def get_judgment_shake_offset(self):
        """신의심판 화면 흔들림 오프셋 반환 (정글지진의 1.5배 강도)"""
        if self.judgment_phase not in (self.JUDGMENT_EARTHQUAKE, self.JUDGMENT_SLAM,
                                       self.JUDGMENT_BOLT_EXPLOSION, self.JUDGMENT_RETURN,
                                       self.JUDGMENT_FAN_SWING, self.JUDGMENT_SANDSTORM):
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

    def get_wind_sandstorm_info(self):
        """바람 모래바람 정보 반환 (pingfighter.py 끌어당김/포획 판정용)"""
        if self.judgment_phase == self.JUDGMENT_SANDSTORM and self.judgment_variant == 'wind':
            active_storms = [s for s in self.judgment_wind_sandstorms if not s['dead']]
            return {
                'active': True,
                'storms': [{
                    'x': s['x'], 'y': s['y'], 'size': s['size'],
                    'vx': s['vx'], 'vy': s['vy'],
                    'base_vx': s['base_vx'], 'base_vy': s['base_vy'],
                    'drift_vx': s['drift_vx'],
                    'growth_scale': s['growth_scale'],
                    'has_captured': s['has_captured'],
                    'capture_cooldown': s['capture_cooldown'],
                    'fading': s.get('fading', False),
                    'age': s['age'],
                    'idx': i,  # 인덱스 (포획 시 상태 업데이트용)
                } for i, s in enumerate(active_storms)],
                'hit_top': self.judgment_sandstorm_hit_top,
                'hit_bottom': self.judgment_sandstorm_hit_bottom,
                'captured': self.judgment_sandstorm_captured,
            }
        return {'active': False}

    def set_sandstorm_captured(self, storm_idx, capture_cooldown=2.0):
        """모래바람 포획 상태 설정 (pingfighter.py에서 호출)"""
        active_storms = [s for s in self.judgment_wind_sandstorms if not s['dead']]
        if 0 <= storm_idx < len(active_storms):
            active_storms[storm_idx]['has_captured'] = True
            active_storms[storm_idx]['capture_cooldown'] = capture_cooldown

    def is_judgment_earthquake_active(self):
        """신의심판 지진 효과 활성화 여부"""
        return self.judgment_phase == self.JUDGMENT_EARTHQUAKE

    def is_judgment_active(self):
        """신의심판 이벤트 진행 중 여부"""
        return self.judgment_phase != self.JUDGMENT_IDLE

    def reset_judgment(self):
        """신의심판 이벤트 강제 초기화 (라운드 전환 시 호출)"""
        self.judgment_phase = self.JUDGMENT_IDLE
        self.judgment_timer = 0.0
        self.judgment_scale = 1.0
        self.judgment_left_arm_progress = 0.0
        self.judgment_right_arm_progress = 0.0
        self.judgment_slam_progress = 0.0
        self.judgment_feet_swing = 0.0
        self.judgment_shake_intensity = 0.0
        self.judgment_flash_alpha = 0
        self.judgment_rise_offset = 0.0
        self.judgment_hole_fade_scale = 0.0
        self.judgment_bolt_intensity = 0.0
        self.judgment_quake_sound_playing = False
        # 파티클 정리
        self.judgment_merge_particles.clear()
        self.judgment_slam_debris.clear()
        self.judgment_dust_rain.clear()
        self.judgment_rise_debris.clear()
        self.judgment_hole_crumble.clear()
        self.judgment_bolt_sparks.clear()
        self.judgment_bolt_proj_trail.clear()
        self.judgment_explosion_sparks.clear()
        # 번개 상태 초기화
        self.judgment_variant = 'earthquake'
        self.judgment_bolt_hidden = False
        self.judgment_bolt_thrown = False
        self.judgment_lightning_stun_top = False
        self.judgment_lightning_stun_bottom = False
        self.judgment_lightning_stun_timer = 0.0
        self.judgment_lightning_active = False
        # 바람 상태 초기화
        self.judgment_wind_sandstorms.clear()
        self.judgment_wind_particles.clear()
        self.judgment_fan_swing_progress = 0.0
        self.judgment_wind_charge_intensity = 0.0
        self.judgment_fan_energy_particles.clear()
        self.judgment_fan_swing_started = False
        self.judgment_sandstorm_hit_top = False
        self.judgment_sandstorm_hit_bottom = False
        self.judgment_sandstorm_captured = None
        self.judgment_bolt_throw_started = False
        self.judgment_bolt_explosion_started = False
        # 쿨타임 리셋 (다음 라운드에서 새로 카운트)
        self.judgment_cooldown = random.uniform(50.0, 100.0)

    def is_judgment_slam_impact(self):
        """슬램이 바닥에 충돌하는 순간인지 (사운드 타이밍용)"""
        return (self.judgment_phase == self.JUDGMENT_SLAM and
                self.judgment_timer / self.SLAM_DURATION > 0.9)

    def get_judgment_phase_name(self):
        """현재 페이즈 이름 (디버그용)"""
        names = {0: "IDLE", 1: "MERGE", 2: "ARM_RAISE", 3: "SLAM", 4: "EARTHQUAKE",
                 5: "RETURN", 6: "HOLE_FADE", 7: "BOLT_THROW", 8: "BOLT_FLIGHT", 9: "BOLT_EXPLOSION",
                 10: "FAN_SWING", 11: "SANDSTORM"}
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
                    hole_surf = _get_cached_surface(hole_w, hole_h)
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
                    edge_surf = _get_cached_surface(self.width, self.height)
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
                hole_surf = _get_cached_surface(hole_w, hole_h)
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
                    dust_surf = _get_cached_surface(dust_w, dust_h)
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
                        wide_surf = _get_cached_surface(wide_w, wide_h)
                        pygame.draw.ellipse(wide_surf, (170, 150, 120, wide_alpha),
                                            (0, 0, wide_w, wide_h))
                        screen.blit(wide_surf, (cx + rise_shake_x - wide_w // 2,
                                                ground_y - wide_h + int(2 * s)))
                    # 깊은 함몰부 그림자 강화 (하강할수록 진해짐)
                    deep_alpha = int(100 * min(1.0, sink_ratio))
                    deep_w = int(16 * s)
                    deep_h = int(5 * s)
                    if deep_w > 3 and deep_h > 1:
                        deep_surf = _get_cached_surface(deep_w, deep_h)
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
            # 동상 손 번개와 동일한 방향 컨벤션: sin/cos (Y축 기준 각도)
            bdir_x, bdir_y = math.sin(ang), math.cos(ang)
            # 수직 방향 (동상 번개와 동일)
            perp_x, perp_y = bdir_y, -bdir_x
            # 동상 번개와 동일한 지그재그 패턴
            zigzag = [
                (0, 0),
                (-3, 0.25), (2, 0.4), (-2, 0.6), (1, 0.78), (-1, 1.0),
            ]
            bolt_segs = []
            for zx, zt in zigzag:
                rx = bx + int(zx * ps * perp_x) + int(bolt_len * zt * bdir_x)
                ry = by + int(zx * ps * perp_y) + int(bolt_len * zt * bdir_y)
                bolt_segs.append((rx, ry))
            # 글로우 (금색 반투명)
            glow_r = int(12 * ps)
            glow_surf = _get_cached_surface(glow_r * 2, glow_r * 2)
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
                ring_surf = _get_cached_surface(r * 2 + 4, r * 2 + 4)
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
                fl_surf = _get_cached_surface(flash_size * 2, flash_size * 2)
                pygame.draw.circle(fl_surf, (212, 175, 85, fa), (flash_size, flash_size), flash_size)
                pygame.draw.circle(fl_surf, (255, 245, 200, min(255, fa + 30)), (flash_size, flash_size), flash_size // 3)
                screen.blit(fl_surf, (ex - flash_size, ey - flash_size), special_flags=pygame.BLEND_ADD)

        # ── 바람 충전 파티클 (ARM_RAISE wind variant) ──
        for wp in self.judgment_wind_particles:
            wx, wy = int(wp['x']) + offset_x, int(wp['y']) + offset_y
            ws = max(1, int(wp['size'] * min(1.0, wp['life'] * 3)))
            if ws > 0:
                pygame.draw.circle(screen, wp['color'], (wx, wy), ws)

        # ── 모래 소용돌이 투사체 (FAN_SWING / SANDSTORM 페이즈) - 모래회오리 세트 비주얼 ──
        for storm in self.judgment_wind_sandstorms:
            if storm['dead'] or storm['alpha'] <= 5:
                continue
            sx = int(storm['x']) + offset_x
            sy = int(storm['y']) + offset_y
            sz = max(4, int(storm['size']))
            alpha = storm['alpha']
            rot = storm['rotation']
            age = storm.get('age', 0)

            # 트레일 파티클
            for tp in storm['trail_particles']:
                tx, ty = int(tp['x']) + offset_x, int(tp['y']) + offset_y
                ts = max(1, int(tp['size'] * min(1.0, tp['life'] * 3)))
                if ts > 0:
                    tp_a = max(0, min(255, int(180 * min(1.0, tp['life'] * 2))))
                    tp_surf = _get_cached_surface(ts * 2, ts * 2)
                    pygame.draw.circle(tp_surf, (*tp['color'], tp_a), (ts, ts), ts)
                    screen.blit(tp_surf, (tx - ts, ty - ts))

            # 메인 소용돌이 서피스 (모래회오리 세트와 동일한 렌더링)
            surf_size = int(sz * 3.5)
            if surf_size < 4:
                continue
            vortex_surf = pygame.Surface((surf_size * 2, surf_size * 2), pygame.SRCALPHA)
            cx_s, cy_s = surf_size, surf_size

            # 1) 바깥쪽 모래구름 (8개 반투명 대형 원)
            for i in range(8):
                cloud_angle = math.radians(rot * 0.5 + i * 45 + age * 60)
                cloud_dist = sz * (0.6 + 0.4 * math.sin(age * 2 + i))
                cloud_x = cx_s + math.cos(cloud_angle) * cloud_dist
                cloud_y = cy_s + math.sin(cloud_angle) * cloud_dist
                cloud_r = int(sz * random.uniform(0.35, 0.6))
                cloud_alpha = max(0, min(255, int(alpha * 0.25)))
                r_c = min(255, 180 + int(30 * math.sin(i * 0.7)))
                g_c = min(255, 145 + int(20 * math.sin(i * 1.1)))
                b_c = max(40, 70 + int(15 * math.sin(i * 0.5)))
                pygame.draw.circle(vortex_surf, (r_c, g_c, b_c, cloud_alpha),
                                   (int(cloud_x), int(cloud_y)), cloud_r)

            # 2) 중간층 빠른 회전 나선 (8겹, 모래회오리 세트와 동일)
            for layer in range(8):
                radius = sz - layer * 4
                if radius < 4:
                    break
                layer_alpha = max(0, min(255, int(alpha * 0.7) - layer * 20))
                r_c = min(255, 200 + layer * 6)
                g_c = max(90, 155 - layer * 7)
                b_c = max(35, 75 - layer * 6)
                color = (r_c, g_c, b_c, layer_alpha)
                points = []
                angle_start = math.radians(rot * 1.3 + layer * 40)
                for a_deg in range(0, 420, 8):
                    rad = math.radians(a_deg) + angle_start
                    r = radius * (1 - a_deg / 1400)
                    if r < 2:
                        break
                    px = cx_s + math.cos(rad) * r
                    py = cy_s + math.sin(rad) * r
                    points.append((int(px), int(py)))
                if len(points) > 2:
                    line_w = max(1, 4 - layer // 2)
                    pygame.draw.lines(vortex_surf, color, False, points, line_w)

            # 3) 내부 밝은 코어
            core_alpha = max(0, min(255, int(alpha * 0.5)))
            pygame.draw.circle(vortex_surf, (230, 200, 130, core_alpha), (cx_s, cy_s), int(sz * 0.35))
            pygame.draw.circle(vortex_surf, (245, 225, 165, max(0, min(255, int(alpha * 0.7)))),
                               (cx_s, cy_s), int(sz * 0.2))
            pygame.draw.circle(vortex_surf, (255, 240, 190, min(255, int(alpha * 0.9))),
                               (cx_s, cy_s), 6)

            # 4) 모래알갱이 노이즈 (12개)
            for _ in range(12):
                grain_angle = random.uniform(0, math.pi * 2)
                grain_dist = random.uniform(4, sz * 0.9)
                gx = cx_s + math.cos(grain_angle) * grain_dist
                gy = cy_s + math.sin(grain_angle) * grain_dist
                grain_alpha = max(0, min(255, int(alpha * random.uniform(0.3, 0.7))))
                grain_size = random.randint(1, 3)
                pygame.draw.circle(vortex_surf, (210, 175, 95, grain_alpha),
                                   (int(gx), int(gy)), grain_size)

            screen.blit(vortex_surf, (sx - surf_size, sy - surf_size))

            # 5) 끌어당김 범위 표시 (매우 연한 원)
            pull_r = int(200 * storm.get('growth_scale', 1.0))
            if pull_r > 10:
                pull_surf = _get_cached_surface(pull_r * 2, pull_r * 2)
                pygame.draw.circle(pull_surf, (210, 180, 100, 10), (pull_r, pull_r), pull_r, 1)
                screen.blit(pull_surf, (sx - pull_r, sy - pull_r))

        # ── 충격 플래시 (단순 전체 플래시) - 캐시된 서피스 사용 ──
        if self.judgment_flash_alpha > 0:
            fa = min(180, self.judgment_flash_alpha)
            flash_surf = _get_cached_surface(self.width, self.height)
            flash_surf.fill((255, 245, 220, fa))
            screen.blit(flash_surf, (offset_x, offset_y), special_flags=pygame.BLEND_ADD)

    def _draw_judgment_statue_scaled(self, screen, cx, cy, scale):
        """신의심판 동안 스케일된 제우스 석상 (프리미엄 고퀄리티 상반신)"""
        s = scale
        # ══ 확장 대리석 컬러 팔레트 ══
        marble = (185, 175, 160)
        marble_light = (200, 192, 178)
        marble_bright = (218, 210, 198)
        marble_mid = (160, 150, 135)
        marble_dark = (130, 120, 108)
        marble_shadow = (105, 95, 85)
        marble_deep = (82, 74, 65)
        marble_vein = (170, 162, 148)
        earth_dark = (85, 70, 50)
        gold = self.colors['gold']
        gold_light = self.colors['gold_light']
        gold_dark = (155, 130, 40)
        gold_deep = (130, 105, 25)
        stone_gray = (140, 130, 115)
        lw = max(1, int(s))
        thick = max(1, int(2 * s))
        thin = max(1, int(0.7 * s))
        extra_thick = max(2, int(3 * s))

        # ════════════════════════════════════════
        # 1. 흙 마운드 & 잔해 (석상 기단부 - 고퀄리티)
        # ════════════════════════════════════════
        ground_y = cy + int(2 * s)
        sand = (155, 130, 95)
        sand_dark = (125, 105, 75)
        sand_light = (175, 150, 115)
        sand_shadow = (105, 85, 60)
        sand_mid = (140, 118, 85)

        # 1a) 불규칙 흙 마운드 (더 넓고 자연스러운 폴리곤)
        mound_pts = [
            (cx - int(18 * s), ground_y + int(4 * s)),
            (cx - int(16 * s), ground_y + int(1 * s)),
            (cx - int(13 * s), ground_y - int(2 * s)),
            (cx - int(10 * s), ground_y - int(3 * s)),
            (cx - int(7 * s), ground_y - int(1 * s)),
            (cx - int(4 * s), ground_y - int(4 * s)),
            (cx - int(1 * s), ground_y - int(2 * s)),
            (cx + int(2 * s), ground_y - int(4 * s)),
            (cx + int(5 * s), ground_y - int(3 * s)),
            (cx + int(8 * s), ground_y - int(1 * s)),
            (cx + int(11 * s), ground_y - int(3 * s)),
            (cx + int(14 * s), ground_y - int(2 * s)),
            (cx + int(17 * s), ground_y + int(1 * s)),
            (cx + int(18 * s), ground_y + int(4 * s)),
        ]
        pygame.draw.polygon(screen, sand_dark, mound_pts)
        # 마운드 윗면 하이라이트 (밝은 능선)
        hl_pts = [
            (cx - int(13 * s), ground_y - int(2 * s)),
            (cx - int(10 * s), ground_y - int(3 * s)),
            (cx - int(4 * s), ground_y - int(4 * s)),
            (cx - int(1 * s), ground_y - int(2 * s)),
            (cx + int(2 * s), ground_y - int(4 * s)),
            (cx + int(5 * s), ground_y - int(3 * s)),
            (cx + int(11 * s), ground_y - int(3 * s)),
            (cx + int(8 * s), ground_y - int(1 * s)),
            (cx + int(2 * s), ground_y - int(2 * s)),
            (cx - int(7 * s), ground_y - int(1 * s)),
        ]
        pygame.draw.polygon(screen, sand, hl_pts)
        # 마운드 중간 톤 (깊이감)
        mid_pts = [
            (cx - int(16 * s), ground_y + int(2 * s)),
            (cx - int(13 * s), ground_y),
            (cx - int(7 * s), ground_y + int(1 * s)),
            (cx + int(8 * s), ground_y + int(1 * s)),
            (cx + int(14 * s), ground_y),
            (cx + int(17 * s), ground_y + int(2 * s)),
            (cx + int(18 * s), ground_y + int(4 * s)),
            (cx - int(18 * s), ground_y + int(4 * s)),
        ]
        pygame.draw.polygon(screen, sand_mid, mid_pts)
        # 마운드 하단 그림자
        pygame.draw.lines(screen, sand_shadow, False, [
            (cx - int(17 * s), ground_y + int(3 * s)),
            (cx - int(10 * s), ground_y + int(4 * s)),
            (cx - int(3 * s), ground_y + int(3 * s)),
            (cx + int(4 * s), ground_y + int(4 * s)),
            (cx + int(11 * s), ground_y + int(3 * s)),
            (cx + int(17 * s), ground_y + int(3 * s)),
        ], lw)

        # 1b) 몸통 주변 솟아오른 흙 테두리
        rim_pts = [
            (cx - int(11 * s), ground_y + int(1 * s)),
            (cx - int(9 * s), ground_y - int(2 * s)),
            (cx - int(5 * s), ground_y - int(1 * s)),
            (cx - int(2 * s), ground_y - int(3 * s)),
            (cx + int(2 * s), ground_y - int(2 * s)),
            (cx + int(5 * s), ground_y - int(3 * s)),
            (cx + int(9 * s), ground_y - int(1 * s)),
            (cx + int(11 * s), ground_y + int(1 * s)),
        ]
        pygame.draw.lines(screen, sand_light, False, rim_pts, lw)

        # 1c) 돌 잔해 (각진 돌 파편 - 다양한 크기와 형태)
        rubble_data = [
            (-20, 5, 3.0, sand_dark), (-16, 4, 2.0, sand_shadow),
            (-14, 6, 1.5, stone_gray), (-22, 5, 1.2, sand_shadow),
            (-11, 7, 1.8, sand), (-24, 6, 1.0, sand_dark),
            (12, 5, 2.5, sand_dark), (16, 4, 2.2, stone_gray),
            (19, 6, 1.5, sand), (14, 7, 1.8, sand_dark),
            (22, 5, 1.3, sand_shadow), (24, 6, 1.0, sand_dark),
            (-8, 6, 1.0, sand), (9, 7, 1.2, sand),
            (-3, 5, 0.8, stone_gray), (6, 6, 0.8, stone_gray),
        ]
        for rx, ry, rsz, rcol in rubble_data:
            px = cx + int(rx * s)
            py = ground_y + int(ry * s)
            r = max(1, int(rsz * s * 0.4))
            pygame.draw.circle(screen, rcol, (px, py), r)
            if r > 1:
                pygame.draw.circle(screen, sand_light, (px - 1, py - 1), max(1, r - 1))

        # 1d) 바닥 갈라짐 (석상 주변 방사형 크랙)
        if s >= 2:
            crack_col = sand_shadow
            crack_data = [
                ((-18, 4), (-24, 7)), ((17, 4), (23, 7)),
                ((-10, 5), (-14, 9)), ((10, 5), (14, 9)),
                ((-5, 4), (-6, 8)), ((5, 4), (6, 8)),
            ]
            for (x1, y1), (x2, y2) in crack_data:
                p1 = (cx + int(x1 * s), ground_y + int(y1 * s))
                p2 = (cx + int(x2 * s), ground_y + int(y2 * s))
                pygame.draw.line(screen, crack_col, p1, p2, 1)

        # ════════════════════════════════════════
        # 2. 상체 메인 바디 (영웅적 체형 - V자 실루엣)
        # ════════════════════════════════════════
        torso_pts = [
            # 하단 파단면 (더 복잡한 깨짐 패턴)
            (cx - int(9 * s), cy - int(2 * s)),
            (cx - int(7 * s), cy - int(5 * s)),
            (cx - int(5 * s), cy - int(3 * s)),
            (cx - int(3 * s), cy - int(1 * s)),
            (cx - int(1 * s), cy - int(4 * s)),
            (cx + int(1 * s), cy - int(2 * s)),
            (cx + int(3 * s), cy),
            (cx + int(5 * s), cy - int(3 * s)),
            (cx + int(7 * s), cy - int(5 * s)),
            (cx + int(9 * s), cy - int(1 * s)),
            # 오른쪽 옆구리 (허리→삼각근, V자 실루엣)
            (cx + int(8 * s), cy - int(8 * s)),
            (cx + int(10 * s), cy - int(12 * s)),
            (cx + int(13 * s), cy - int(15 * s)),  # 넓은 광배근
            (cx + int(14 * s), cy - int(17 * s)),   # 더 넓은 어깨
            (cx + int(13 * s), cy - int(19 * s)),
            # 상단 어깨선 (둥근 승모근 형태)
            (cx + int(12 * s), cy - int(20.5 * s)),  # 어깨 끝
            (cx + int(6 * s), cy - int(21 * s)),     # 승모근 정점
            (cx, cy - int(20 * s)),                   # 승모근 중앙 (살짝 내려감)
            (cx - int(6 * s), cy - int(21 * s)),
            (cx - int(12 * s), cy - int(20.5 * s)),
            # 왼쪽 어깨→옆구리
            (cx - int(13 * s), cy - int(19 * s)),
            (cx - int(14 * s), cy - int(17 * s)),
            (cx - int(13 * s), cy - int(15 * s)),
            (cx - int(10 * s), cy - int(12 * s)),
            (cx - int(8 * s), cy - int(8 * s)),
        ]
        pygame.draw.polygon(screen, marble, torso_pts)
        pygame.draw.polygon(screen, marble_dark, torso_pts, lw)

        # 2b) 좌측 전면 그림자 (입체감 - 빛이 우상단에서 옴)
        l_shadow_pts = [
            (cx - int(13 * s), cy - int(19 * s)),
            (cx - int(14 * s), cy - int(17 * s)),
            (cx - int(13 * s), cy - int(15 * s)),
            (cx - int(10 * s), cy - int(12 * s)),
            (cx - int(8 * s), cy - int(8 * s)),
            (cx - int(9 * s), cy - int(2 * s)),
            (cx - int(7 * s), cy - int(5 * s)),
            (cx - int(5 * s), cy - int(6 * s)),
            (cx - int(6 * s), cy - int(14 * s)),
            (cx - int(9 * s), cy - int(18 * s)),
            (cx - int(12 * s), cy - int(20.5 * s)),
        ]
        if len(l_shadow_pts) >= 3:
            pygame.draw.polygon(screen, marble_mid, l_shadow_pts)

        # 2c) 오른쪽 림라이트 (빛 반사 - 넓은 광배근)
        if s >= 1.5:
            rim_light_pts = [
                (cx + int(13 * s), cy - int(19 * s)),
                (cx + int(14 * s), cy - int(17 * s)),
                (cx + int(13 * s), cy - int(15 * s)),
                (cx + int(11 * s), cy - int(15 * s)),
                (cx + int(12 * s), cy - int(17 * s)),
                (cx + int(12 * s), cy - int(19 * s)),
            ]
            pygame.draw.polygon(screen, marble_light, rim_light_pts)

        # 2d) 중앙 흉골 라인 (가슴 분리선 하이라이트)
        if s >= 2:
            pygame.draw.line(screen, marble_bright,
                             (cx, cy - int(20 * s)),
                             (cx, cy - int(13 * s)), 1)

        # ═══ 3. 근육 디테일 (강화된 해부학적 디테일) ═══

        # 3a) 쇄골 (collarbone - 넓어진 어깨에 맞춤)
        pygame.draw.line(screen, marble_mid,
                         (cx - int(2 * s), cy - int(20 * s)),
                         (cx - int(10 * s), cy - int(19 * s)), lw)
        pygame.draw.line(screen, marble_mid,
                         (cx + int(2 * s), cy - int(20 * s)),
                         (cx + int(10 * s), cy - int(19 * s)), lw)
        if s >= 2:
            # 쇄골 상단 하이라이트 (뼈가 돌출된 느낌)
            pygame.draw.line(screen, marble_bright,
                             (cx - int(2 * s), cy - int(20.5 * s)),
                             (cx - int(9 * s), cy - int(19.5 * s)), 1)
            pygame.draw.line(screen, marble_bright,
                             (cx + int(2 * s), cy - int(20.5 * s)),
                             (cx + int(9 * s), cy - int(19.5 * s)), 1)
            # 쇄골 하단 그림자
            pygame.draw.line(screen, marble_shadow,
                             (cx - int(3 * s), cy - int(19.5 * s)),
                             (cx - int(9 * s), cy - int(18.5 * s)), 1)
            pygame.draw.line(screen, marble_shadow,
                             (cx + int(3 * s), cy - int(19.5 * s)),
                             (cx + int(9 * s), cy - int(18.5 * s)), 1)

        # 3b) 삼각근 (deltoid) 윤곽 - 넓어진 어깨
        pygame.draw.arc(screen, marble_dark,
                        (cx - int(15 * s), cy - int(21 * s), int(7 * s), int(9 * s)),
                        -0.3, math.pi * 0.5, lw)
        pygame.draw.arc(screen, marble_dark,
                        (cx + int(9 * s), cy - int(21 * s), int(7 * s), int(9 * s)),
                        math.pi * 0.5, math.pi + 0.3, lw)
        # 삼각근 내부 분리선 (전면/측면/후면)
        if s >= 2:
            pygame.draw.line(screen, marble_mid,
                             (cx - int(12 * s), cy - int(20 * s)),
                             (cx - int(11 * s), cy - int(16 * s)), 1)
            pygame.draw.line(screen, marble_mid,
                             (cx + int(12 * s), cy - int(20 * s)),
                             (cx + int(11 * s), cy - int(16 * s)), 1)

        # 3c) 대흉근 (pectoral muscles - 더 크고 입체적)
        chest_w = int(9 * s)
        chest_h = int(6 * s)
        if chest_w > 3 and chest_h > 2:
            # 왼쪽 대흉근 (채워진 형태)
            l_pec_pts = [
                (cx - int(1 * s), cy - int(19 * s)),
                (cx - int(9 * s), cy - int(17 * s)),
                (cx - int(10 * s), cy - int(15 * s)),
                (cx - int(8 * s), cy - int(13 * s)),
                (cx - int(1 * s), cy - int(13.5 * s)),
            ]
            pygame.draw.polygon(screen, marble, l_pec_pts)
            pygame.draw.polygon(screen, marble_dark, l_pec_pts, lw)
            # 왼쪽 대흉근 하부 그림자 (하이라이트/그림자 분리)
            pygame.draw.arc(screen, marble_shadow,
                            (cx - int(9 * s), cy - int(16 * s), int(8 * s), int(4 * s)),
                            0.0, math.pi * 0.7, lw)
            # 왼쪽 대흉근 상부 하이라이트
            if s >= 2:
                pygame.draw.line(screen, marble_bright,
                                 (cx - int(2 * s), cy - int(18 * s)),
                                 (cx - int(7 * s), cy - int(17 * s)), 1)

            # 오른쪽 대흉근 (채워진 형태)
            r_pec_pts = [
                (cx + int(1 * s), cy - int(19 * s)),
                (cx + int(9 * s), cy - int(17 * s)),
                (cx + int(10 * s), cy - int(15 * s)),
                (cx + int(8 * s), cy - int(13 * s)),
                (cx + int(1 * s), cy - int(13.5 * s)),
            ]
            pygame.draw.polygon(screen, marble, r_pec_pts)
            pygame.draw.polygon(screen, marble_dark, r_pec_pts, lw)
            pygame.draw.arc(screen, marble_shadow,
                            (cx + int(2 * s), cy - int(16 * s), int(8 * s), int(4 * s)),
                            math.pi * 0.3, math.pi * 1.0, lw)
            if s >= 2:
                pygame.draw.line(screen, marble_bright,
                                 (cx + int(2 * s), cy - int(18 * s)),
                                 (cx + int(7 * s), cy - int(17 * s)), 1)

            # 가슴 중앙 골 (흉골 - 깊은 V홈)
            pygame.draw.line(screen, marble_shadow,
                             (cx, cy - int(19 * s)),
                             (cx, cy - int(13 * s)), thick)
            if s >= 2:
                pygame.draw.line(screen, marble_deep,
                                 (cx, cy - int(18 * s)),
                                 (cx, cy - int(14 * s)), 1)

        # 3d) 복부 근육 (abdominals - 8-pack 강화)
        pygame.draw.line(screen, marble_mid,
                         (cx, cy - int(13 * s)), (cx, cy - int(5 * s)), lw)
        if s >= 2:
            # 복근 수평 분리선 (8-pack: 4단 좌우)
            for ab_y_off in [-12.5, -10.5, -8.5, -6.5]:
                ab_y = cy + int(ab_y_off * s)
                # 좌측 복근 분리선
                pygame.draw.line(screen, marble_mid,
                                 (cx - int(4 * s), ab_y),
                                 (cx - int(0.5 * s), ab_y), 1)
                # 우측 복근 분리선
                pygame.draw.line(screen, marble_mid,
                                 (cx + int(0.5 * s), ab_y),
                                 (cx + int(4 * s), ab_y), 1)
            # 복근 블록 하이라이트 (각 블록 중앙에 밝은 점)
            for ab_y_off in [-13, -11, -9, -7]:
                ab_y = cy + int(ab_y_off * s)
                # 좌측 하이라이트
                pygame.draw.line(screen, marble_light,
                                 (cx - int(2.5 * s), ab_y + int(0.5 * s)),
                                 (cx - int(1 * s), ab_y + int(0.5 * s)), 1)
                # 우측 하이라이트
                pygame.draw.line(screen, marble_light,
                                 (cx + int(1 * s), ab_y + int(0.5 * s)),
                                 (cx + int(2.5 * s), ab_y + int(0.5 * s)), 1)
            # 복근 외곽선 (복직근 테두리)
            pygame.draw.line(screen, marble_mid,
                             (cx - int(4 * s), cy - int(13 * s)),
                             (cx - int(4 * s), cy - int(6 * s)), 1)
            pygame.draw.line(screen, marble_mid,
                             (cx + int(4 * s), cy - int(13 * s)),
                             (cx + int(4 * s), cy - int(6 * s)), 1)

        # 3e) 외복사근 / 전거근 (oblique / serratus - 톱니 형태)
        if s >= 1.5:
            # 전거근 (serratus anterior) - 갈비뼈 위 톱니 형태
            for ob_i in range(4):
                ob_y = cy - int((15 - ob_i * 2) * s)
                # 좌측 (톱니 모양)
                pygame.draw.line(screen, marble_mid,
                                 (cx - int(4.5 * s), ob_y),
                                 (cx - int(8 * s), ob_y - int(1.5 * s)), 1)
                # 좌측 하이라이트
                if s >= 2.5:
                    pygame.draw.line(screen, marble_light,
                                     (cx - int(5 * s), ob_y - int(0.3 * s)),
                                     (cx - int(7 * s), ob_y - int(1 * s)), 1)
                # 우측
                pygame.draw.line(screen, marble_mid,
                                 (cx + int(4.5 * s), ob_y),
                                 (cx + int(8 * s), ob_y - int(1.5 * s)), 1)
                if s >= 2.5:
                    pygame.draw.line(screen, marble_light,
                                     (cx + int(5 * s), ob_y - int(0.3 * s)),
                                     (cx + int(7 * s), ob_y - int(1 * s)), 1)
            # 외복사근 V라인 (골반 위)
            if s >= 2:
                pygame.draw.line(screen, marble_mid,
                                 (cx - int(4 * s), cy - int(6 * s)),
                                 (cx - int(7 * s), cy - int(3 * s)), 1)
                pygame.draw.line(screen, marble_mid,
                                 (cx + int(4 * s), cy - int(6 * s)),
                                 (cx + int(7 * s), cy - int(3 * s)), 1)

        # ═══ 4. 토가 (의상) 디테일 ═══

        # 4a) 메인 토가 드레이프 (깊은 주름 + 하이라이트)
        pygame.draw.line(screen, marble_shadow,
                         (cx - int(10 * s), cy - int(19 * s)),
                         (cx + int(5 * s), cy - int(6 * s)), extra_thick)
        pygame.draw.line(screen, marble_light,
                         (cx - int(10 * s), cy - int(19.5 * s)),
                         (cx + int(5 * s), cy - int(6.5 * s)), lw)

        # 4b) 보조 주름들
        pygame.draw.line(screen, marble_dark,
                         (cx - int(8 * s), cy - int(16 * s)),
                         (cx + int(3 * s), cy - int(5 * s)), thick)
        pygame.draw.line(screen, marble_mid,
                         (cx - int(6 * s), cy - int(14 * s)),
                         (cx + int(1 * s), cy - int(5 * s)), lw)
        pygame.draw.line(screen, marble_mid,
                         (cx + int(4 * s), cy - int(18 * s)),
                         (cx + int(8 * s), cy - int(8 * s)), lw)
        pygame.draw.line(screen, marble_dark,
                         (cx + int(6 * s), cy - int(17 * s)),
                         (cx + int(7 * s), cy - int(10 * s)), lw)
        if s >= 2:
            pygame.draw.line(screen, marble_shadow,
                             (cx - int(9 * s), cy - int(17.5 * s)),
                             (cx + int(4 * s), cy - int(5.5 * s)), 1)

        # 4c) 어깨 핀/브로치 (토가 고정 - 넓어진 어깨 좌표)
        brooch_x = cx - int(11 * s)
        brooch_y = cy - int(20 * s)
        br_r = max(1, int(1.5 * s))
        pygame.draw.circle(screen, gold, (brooch_x, brooch_y), br_r)
        pygame.draw.circle(screen, gold_light, (brooch_x, brooch_y), max(1, br_r - 1))
        if s >= 2:
            pygame.draw.circle(screen, gold_dark, (brooch_x, brooch_y), br_r, 1)

        # ═══ 5. 허리 장식 벨트 (그리스풍 - 고퀄리티) ═══
        belt_y = cy - int(7 * s)
        belt_hw = int(7 * s)
        belt_h = max(2, int(2 * s))
        # 벨트 그림자 (아래)
        pygame.draw.line(screen, gold_dark,
                         (cx - belt_hw, belt_y + 1),
                         (cx + belt_hw, belt_y + 1), belt_h)
        # 벨트 본체
        pygame.draw.line(screen, gold,
                         (cx - belt_hw, belt_y),
                         (cx + belt_hw, belt_y), belt_h)
        # 벨트 상단 하이라이트
        pygame.draw.line(screen, gold_light,
                         (cx - belt_hw, belt_y - max(1, int(0.5 * s))),
                         (cx + belt_hw, belt_y - max(1, int(0.5 * s))), 1)
        # 그리스 미앤더 패턴 (스케일 충분시)
        if s >= 2.5:
            for mx in range(-5, 6, 3):
                px = cx + int(mx * s)
                pygame.draw.line(screen, gold_deep,
                                 (px, belt_y - int(0.5 * s)),
                                 (px + int(1 * s), belt_y - int(0.5 * s)), 1)
                pygame.draw.line(screen, gold_deep,
                                 (px + int(1 * s), belt_y - int(0.5 * s)),
                                 (px + int(1 * s), belt_y + int(0.5 * s)), 1)
        # 장식 스터드
        stud_r = max(1, int(0.8 * s))
        for stud_x_off in [-5, -3, 3, 5]:
            sx = cx + int(stud_x_off * s)
            pygame.draw.circle(screen, gold_light, (sx, belt_y), stud_r)
            if stud_r > 1:
                pygame.draw.circle(screen, gold_dark, (sx, belt_y), stud_r, 1)
        # 중앙 버클 (장식형)
        buckle_r = max(2, int(2 * s))
        pygame.draw.circle(screen, gold_light, (cx, belt_y), buckle_r)
        pygame.draw.circle(screen, gold, (cx, belt_y), buckle_r, max(1, int(0.5 * s)))
        # 버클 보석
        gem_r = max(1, int(0.8 * s))
        pygame.draw.circle(screen, (120, 180, 220), (cx, belt_y), gem_r)
        if gem_r > 1:
            pygame.draw.circle(screen, (180, 220, 255), (cx - 1, belt_y - 1), max(1, gem_r - 1))

        # ═══ 6. 파단면 디테일 (깨진 돌 단면) ═══
        fracture_pts = [
            (cx - int(9 * s), cy - int(2 * s)),
            (cx - int(7 * s), cy - int(5 * s)),
            (cx - int(5 * s), cy - int(3 * s)),
            (cx - int(3 * s), cy - int(1 * s)),
            (cx - int(1 * s), cy - int(4 * s)),
            (cx + int(1 * s), cy - int(2 * s)),
            (cx + int(3 * s), cy),
            (cx + int(5 * s), cy - int(3 * s)),
            (cx + int(7 * s), cy - int(5 * s)),
            (cx + int(9 * s), cy - int(1 * s)),
            (cx + int(9 * s), cy + int(1 * s)),
            (cx - int(9 * s), cy + int(1 * s)),
        ]
        pygame.draw.polygon(screen, marble_shadow, fracture_pts)
        # 파단면 하이라이트 (깨진 면 윗면)
        pygame.draw.line(screen, marble_light,
                         (cx - int(7 * s), cy - int(5 * s)),
                         (cx - int(5 * s), cy - int(3 * s)), lw)
        pygame.draw.line(screen, marble_bright,
                         (cx - int(1 * s), cy - int(4 * s)),
                         (cx + int(1 * s), cy - int(2 * s)), lw)
        pygame.draw.line(screen, marble_light,
                         (cx + int(5 * s), cy - int(3 * s)),
                         (cx + int(7 * s), cy - int(5 * s)), lw)
        # 파단면 깊은 그림자
        pygame.draw.line(screen, marble_deep,
                         (cx - int(3 * s), cy - int(1 * s)),
                         (cx - int(1 * s), cy - int(4 * s)), lw)
        pygame.draw.line(screen, marble_deep,
                         (cx + int(1 * s), cy - int(2 * s)),
                         (cx + int(3 * s), cy), lw)
        pygame.draw.line(screen, marble_deep,
                         (cx + int(3 * s), cy),
                         (cx + int(5 * s), cy - int(3 * s)), lw)
        # 파단면에서 올라오는 크랙
        if s >= 2:
            pygame.draw.line(screen, marble_shadow,
                             (cx - int(5 * s), cy - int(3 * s)),
                             (cx - int(4 * s), cy - int(6 * s)), 1)
            pygame.draw.line(screen, marble_shadow,
                             (cx + int(3 * s), cy),
                             (cx + int(2 * s), cy - int(3 * s)), 1)
            pygame.draw.line(screen, marble_shadow,
                             (cx + int(7 * s), cy - int(5 * s)),
                             (cx + int(6 * s), cy - int(8 * s)), 1)

        # ═══ 7. 대리석 텍스처 (프리미엄 - 균열, 결, 풍화) ═══
        if s >= 2:
            # 7a) 대리석 결 (veins) - 더 복잡하고 자연스러운 패턴
            vein_data = [
                # 좌측 가슴~복부 관통 결
                ((-7, -17), (-5, -15), (-3, -12), (-2, -10), (0, -8)),
                # 우측 상부 결
                ((3, -18), (5, -16), (7, -14), (6, -11)),
                # 복부 가로 결
                ((-4, -10), (-2, -8), (1, -7), (3, -8)),
                # 좌측 옆구리 결
                ((-9, -14), (-7, -12), (-6, -9)),
                # 우측 하부 결
                ((4, -7), (6, -5), (7, -3)),
            ]
            for vein in vein_data:
                pts = [(cx + int(vx * s), cy + int(vy * s)) for vx, vy in vein]
                if len(pts) >= 2:
                    pygame.draw.lines(screen, marble_vein, False, pts, 1)

            # 7b) 풍화 자국 (크랙, 칩, 반점)
            # 크랙 (깊은 갈라짐)
            crack_data = [
                ((-5, -16), (-4.5, -14.5), (-5.5, -13), (-4, -11)),  # 좌측 대각선 크랙
                ((6, -15), (5.5, -13), (6.5, -11)),                  # 우측 크랙
                ((0, -5), (1, -3.5), (-0.5, -2)),                    # 하단 중앙 크랙
            ]
            for crack in crack_data:
                pts = [(cx + int(cx2 * s), cy + int(cy2 * s)) for cx2, cy2 in crack]
                if len(pts) >= 2:
                    pygame.draw.lines(screen, marble_shadow, False, pts, 1)
                    # 크랙 옆 밝은 선 (빛에 의한 엣지 하이라이트)
                    hl_pts = [(px + 1, py - 1) for px, py in pts]
                    pygame.draw.lines(screen, marble_vein, False, hl_pts, 1)

            # 반점 (풍화된 부분)
            weather_spots = [
                (-3, -14, 0.4), (5, -16, 0.3), (-7, -10, 0.5),
                (4, -8, 0.3), (-1, -6, 0.4), (8, -12, 0.3),
                (-8, -15, 0.3), (2, -4, 0.35), (-6, -7, 0.3),
            ]
            for wx, wy, wr in weather_spots:
                spot_r = max(1, int(wr * s))
                pygame.draw.circle(screen, marble_mid,
                                   (cx + int(wx * s), cy + int(wy * s)), spot_r)
                # 반점 하이라이트 (볼록한 느낌)
                if spot_r > 1:
                    pygame.draw.circle(screen, marble_light,
                                       (cx + int(wx * s) - 1, cy + int(wy * s) - 1),
                                       max(1, spot_r - 1))

            # 7c) 칩/파임 (깨진 돌 조각이 떨어져나간 흔적)
            if s >= 3:
                chip_data = [
                    (-10, -16, 1.5), (9, -13, 1.2), (-3, -3, 1.0),
                    (7, -17, 0.8), (-11, -12, 1.0),
                ]
                for chip_x, chip_y, chip_sz in chip_data:
                    cpx = cx + int(chip_x * s)
                    cpy = cy + int(chip_y * s)
                    cr = max(1, int(chip_sz * s * 0.3))
                    # 파인 부분 (어두운 그림자)
                    pygame.draw.circle(screen, marble_shadow, (cpx, cpy), cr)
                    # 파인 부분 엣지 하이라이트
                    pygame.draw.arc(screen, marble_light,
                                    (cpx - cr, cpy - cr, cr * 2, cr * 2),
                                    math.pi * 0.8, math.pi * 1.5, 1)

        # ═══ 8. 목 (강화된 디테일) ═══
        neck_w = max(3, int(4 * s))
        neck_top = cy - int(22 * s)
        neck_bot = cy - int(20 * s)
        # 목 본체 (두꺼운 원통형)
        neck_w2 = max(4, int(5 * s))
        pygame.draw.line(screen, marble, (cx, neck_bot), (cx, neck_top), neck_w2)
        # 목 좌측 그림자
        pygame.draw.line(screen, marble_mid,
                         (cx - int(2 * s), neck_bot),
                         (cx - int(1.5 * s), neck_top), lw)
        # 목 우측 하이라이트
        pygame.draw.line(screen, marble_light,
                         (cx + int(1.5 * s), neck_bot),
                         (cx + int(1 * s), neck_top), lw)
        # 목 근육 디테일 (흉쇄유돌근)
        if s >= 2:
            pygame.draw.line(screen, marble_mid,
                             (cx - int(1 * s), neck_bot + int(0.5 * s)),
                             (cx - int(2.5 * s), neck_top - int(0.5 * s)), 1)
            pygame.draw.line(screen, marble_mid,
                             (cx + int(1 * s), neck_bot + int(0.5 * s)),
                             (cx + int(2.5 * s), neck_top - int(0.5 * s)), 1)
        # 승모근 연결 (목→어깨, 넓은 어깨에 맞춤)
        if s >= 1.5:
            # 승모근 폴리곤 (목에서 어깨로 넓어지는 형태)
            trap_l_pts = [
                (cx - int(2 * s), cy - int(21 * s)),
                (cx - int(6 * s), cy - int(21 * s)),
                (cx - int(10 * s), cy - int(20 * s)),
                (cx - int(5 * s), cy - int(20 * s)),
            ]
            trap_r_pts = [
                (cx + int(2 * s), cy - int(21 * s)),
                (cx + int(6 * s), cy - int(21 * s)),
                (cx + int(10 * s), cy - int(20 * s)),
                (cx + int(5 * s), cy - int(20 * s)),
            ]
            pygame.draw.polygon(screen, marble, trap_l_pts)
            pygame.draw.polygon(screen, marble_mid, trap_l_pts, 1)
            pygame.draw.polygon(screen, marble, trap_r_pts)
            pygame.draw.polygon(screen, marble_light, trap_r_pts, 1)

        # ── 팔 ──
        self._draw_judgment_arms(screen, cx, cy, s, marble, marble_mid, marble_dark, gold, gold_light)

        # ════════════════════════════════════════
        # 10. 머리 (고퀄리티 조각상 - 조각된 두상 폴리곤)
        # ════════════════════════════════════════
        head_y = cy - int(24 * s)
        head_r = max(3, int(6.5 * s))

        # 10a) 조각된 두상 형태 (원형 → 크라니움+광대뼈+턱선 폴리곤)
        hw = head_r  # 머리 반폭
        # 두개골 상단은 넓고 둥글게, 하단은 턱으로 좁아지는 형태
        head_pts = [
            # 정수리~이마 (넓은 두개골)
            (cx - int(hw * 0.35), head_y - int(hw * 0.95)),
            (cx - int(hw * 0.7), head_y - int(hw * 0.8)),
            (cx - int(hw * 0.92), head_y - int(hw * 0.5)),
            (cx - int(hw * 1.0), head_y - int(hw * 0.15)),
            # 좌측 관자놀이~광대뼈 (측두부)
            (cx - int(hw * 1.0), head_y + int(hw * 0.15)),
            (cx - int(hw * 0.95), head_y + int(hw * 0.4)),
            (cx - int(hw * 0.85), head_y + int(hw * 0.55)),  # 광대뼈 돌출
            # 좌측 턱선 (jaw)
            (cx - int(hw * 0.7), head_y + int(hw * 0.72)),
            (cx - int(hw * 0.45), head_y + int(hw * 0.88)),
            # 턱 끝 (chin)
            (cx - int(hw * 0.15), head_y + int(hw * 0.98)),
            (cx, head_y + int(hw * 1.02)),
            (cx + int(hw * 0.15), head_y + int(hw * 0.98)),
            # 우측 턱선
            (cx + int(hw * 0.45), head_y + int(hw * 0.88)),
            (cx + int(hw * 0.7), head_y + int(hw * 0.72)),
            # 우측 광대뼈
            (cx + int(hw * 0.85), head_y + int(hw * 0.55)),
            (cx + int(hw * 0.95), head_y + int(hw * 0.4)),
            (cx + int(hw * 1.0), head_y + int(hw * 0.15)),
            # 우측 두개골
            (cx + int(hw * 1.0), head_y - int(hw * 0.15)),
            (cx + int(hw * 0.92), head_y - int(hw * 0.5)),
            (cx + int(hw * 0.7), head_y - int(hw * 0.8)),
            (cx + int(hw * 0.35), head_y - int(hw * 0.95)),
        ]
        # 두상 기본 채우기
        pygame.draw.polygon(screen, marble, head_pts)
        # 좌측 그림자 (입체감 - 빛이 우측 상단에서 옴)
        head_shadow_pts = [
            (cx - int(hw * 1.0), head_y - int(hw * 0.15)),
            (cx - int(hw * 1.0), head_y + int(hw * 0.15)),
            (cx - int(hw * 0.95), head_y + int(hw * 0.4)),
            (cx - int(hw * 0.85), head_y + int(hw * 0.55)),
            (cx - int(hw * 0.7), head_y + int(hw * 0.72)),
            (cx - int(hw * 0.45), head_y + int(hw * 0.88)),
            (cx - int(hw * 0.15), head_y + int(hw * 0.98)),
            (cx, head_y + int(hw * 0.6)),
            (cx - int(hw * 0.5), head_y),
            (cx - int(hw * 0.92), head_y - int(hw * 0.5)),
        ]
        if len(head_shadow_pts) >= 3:
            pygame.draw.polygon(screen, marble_mid, head_shadow_pts)
        # 우측 상단 하이라이트 (이마~관자놀이)
        if s >= 1.5:
            head_hl_pts = [
                (cx + int(hw * 0.1), head_y - int(hw * 0.85)),
                (cx + int(hw * 0.6), head_y - int(hw * 0.75)),
                (cx + int(hw * 0.85), head_y - int(hw * 0.4)),
                (cx + int(hw * 0.9), head_y),
                (cx + int(hw * 0.5), head_y - int(hw * 0.2)),
                (cx + int(hw * 0.2), head_y - int(hw * 0.55)),
            ]
            if len(head_hl_pts) >= 3:
                pygame.draw.polygon(screen, marble_light, head_hl_pts)
        # 턱선 하이라이트 (강조)
        if s >= 2:
            pygame.draw.lines(screen, marble_bright, False, [
                (cx + int(hw * 0.7), head_y + int(hw * 0.72)),
                (cx + int(hw * 0.45), head_y + int(hw * 0.88)),
                (cx + int(hw * 0.15), head_y + int(hw * 0.98)),
                (cx, head_y + int(hw * 1.02)),
            ], 1)
        # 윤곽선
        pygame.draw.polygon(screen, marble_dark, head_pts, lw)

        # 10b) 눈두덩 (brow ridge) - 두꺼운 돌출형 능선
        brow_y = head_y - int(1.5 * s)
        if s >= 1.5:
            # 능선 폴리곤 (두꺼운 입체형)
            brow_pts_l = [
                (cx - int(1 * s), brow_y - int(1.2 * s)),
                (cx - int(4.8 * s), brow_y - int(0.8 * s)),
                (cx - int(5 * s), brow_y + int(0.3 * s)),
                (cx - int(1 * s), brow_y + int(0.6 * s)),
            ]
            brow_pts_r = [
                (cx + int(1 * s), brow_y - int(1.2 * s)),
                (cx + int(4.8 * s), brow_y - int(0.8 * s)),
                (cx + int(5 * s), brow_y + int(0.3 * s)),
                (cx + int(1 * s), brow_y + int(0.6 * s)),
            ]
            pygame.draw.polygon(screen, marble, brow_pts_l)
            pygame.draw.polygon(screen, marble, brow_pts_r)
            # 능선 상단 하이라이트
            pygame.draw.line(screen, marble_bright,
                             (cx - int(4.5 * s), brow_y - int(0.8 * s)),
                             (cx - int(1 * s), brow_y - int(1.2 * s)), lw)
            pygame.draw.line(screen, marble_bright,
                             (cx + int(1 * s), brow_y - int(1.2 * s)),
                             (cx + int(4.5 * s), brow_y - int(0.8 * s)), lw)
            # 능선 하단 깊은 그림자 (눈구멍 위 드리운 그림자)
            pygame.draw.line(screen, marble_shadow,
                             (cx - int(4.5 * s), brow_y + int(0.5 * s)),
                             (cx - int(1 * s), brow_y + int(0.7 * s)), thick)
            pygame.draw.line(screen, marble_shadow,
                             (cx + int(1 * s), brow_y + int(0.7 * s)),
                             (cx + int(4.5 * s), brow_y + int(0.5 * s)), thick)
            # 미간 주름 (찌푸린 표정)
            if s >= 2:
                pygame.draw.line(screen, marble_dark,
                                 (cx - int(1.2 * s), brow_y - int(1 * s)),
                                 (cx - int(0.5 * s), brow_y + int(0.3 * s)), 1)
                pygame.draw.line(screen, marble_dark,
                                 (cx + int(1.2 * s), brow_y - int(1 * s)),
                                 (cx + int(0.5 * s), brow_y + int(0.3 * s)), 1)

        # 10c) 눈 (신성한 빛나는 눈 - 석상의 핵심 포인트)
        eye_y = head_y - int(0.5 * s)
        if s >= 2:
            for eye_side in [-1, 1]:
                ex = cx + int(eye_side * 2.5 * s)
                # 깊은 눈구멍 (다층 그림자)
                socket_r = max(1, int(1.8 * s))
                pygame.draw.circle(screen, marble_deep, (ex, eye_y), socket_r)
                pygame.draw.circle(screen, marble_shadow, (ex, eye_y), max(1, int(1.4 * s)))
                # 눈알 형태 (타원형)
                eye_w = max(2, int(2.2 * s))
                eye_h = max(1, int(1.2 * s))
                eye_rect = (ex - eye_w // 2, eye_y - eye_h // 2, eye_w, eye_h)
                pygame.draw.ellipse(screen, marble_mid, eye_rect)
                # ★ 신성한 눈빛 글로우 (황금빛)
                glow_pulse = 0.6 + 0.4 * math.sin(self.time * 3.5 + eye_side * 0.5)
                eye_glow_r = max(2, int(2.5 * s * glow_pulse))
                eye_glow_surf = _get_cached_surface(eye_glow_r * 2 + 4, eye_glow_r * 2 + 4)
                eye_glow_alpha = int(40 * glow_pulse)
                pygame.draw.circle(eye_glow_surf,
                                   (255, 220, 100, min(255, eye_glow_alpha)),
                                   (eye_glow_r + 2, eye_glow_r + 2), eye_glow_r)
                screen.blit(eye_glow_surf,
                            (ex - eye_glow_r - 2, eye_y - eye_glow_r - 2),
                            special_flags=pygame.BLEND_ADD)
                # 동공 (밝은 빛으로 대체)
                pupil_r = max(1, int(0.6 * s))
                pupil_col = (
                    min(255, int(200 + 55 * glow_pulse)),
                    min(255, int(180 + 50 * glow_pulse)),
                    min(255, int(80 + 40 * glow_pulse))
                )
                pygame.draw.circle(screen, pupil_col, (ex, eye_y), pupil_r)
                # 눈빛 하이라이트 점
                pygame.draw.circle(screen, (255, 255, 230),
                                   (ex - int(0.3 * s * eye_side), eye_y - int(0.3 * s)),
                                   max(1, int(0.3 * s)))
                # 눈꺼풀 라인 (위아래 모두)
                pygame.draw.arc(screen, marble_dark,
                                (ex - socket_r, eye_y - socket_r, socket_r * 2, socket_r * 2),
                                0.15, math.pi - 0.15, lw)
                pygame.draw.arc(screen, marble_shadow,
                                (ex - socket_r, eye_y - int(socket_r * 0.5),
                                 socket_r * 2, socket_r),
                                math.pi + 0.3, 2 * math.pi - 0.3, 1)
        elif s >= 1:
            # 작은 스케일에서도 빛나는 점으로 표시
            for eye_side in [-1, 1]:
                ex = cx + int(eye_side * 2.5 * s)
                pygame.draw.line(screen, marble_dark,
                                 (cx + int(eye_side * 3.5 * s), eye_y),
                                 (cx + int(eye_side * 1.5 * s), eye_y), lw)
                # 작은 글로우 점
                glow_p = 0.5 + 0.5 * math.sin(self.time * 3)
                pygame.draw.circle(screen, (int(200 * glow_p), int(180 * glow_p), int(80 * glow_p)),
                                   (ex, eye_y), max(1, int(0.5 * s)))

        # 10d) 코 (상세 - 브릿지 + 끝 + 콧볼)
        nose_top = head_y + int(0.5 * s)
        nose_tip = head_y + int(3 * s)
        pygame.draw.line(screen, marble_dark,
                         (cx, nose_top), (cx, nose_tip), lw)
        if s >= 2:
            nose_w = max(1, int(1.2 * s))
            pygame.draw.line(screen, marble_mid,
                             (cx - nose_w, nose_tip),
                             (cx + nose_w, nose_tip), lw)
            # 콧볼 그림자
            pygame.draw.circle(screen, marble_shadow,
                               (cx - int(1 * s), nose_tip + int(0.3 * s)),
                               max(1, int(0.5 * s)))
            pygame.draw.circle(screen, marble_shadow,
                               (cx + int(1 * s), nose_tip + int(0.3 * s)),
                               max(1, int(0.5 * s)))
            # 코 브릿지 하이라이트
            pygame.draw.line(screen, marble_light,
                             (cx + 1, nose_top + int(0.5 * s)),
                             (cx + 1, nose_tip - int(0.5 * s)), 1)

        # 10e) 광대뼈 하이라이트
        if s >= 2:
            cheek_y = head_y + int(1.5 * s)
            pygame.draw.line(screen, marble_light,
                             (cx - int(4 * s), cheek_y),
                             (cx - int(2.5 * s), cheek_y + int(1 * s)), 1)
            pygame.draw.line(screen, marble_light,
                             (cx + int(2.5 * s), cheek_y + int(1 * s)),
                             (cx + int(4 * s), cheek_y), 1)

        # 10f) 입 (미묘한 표현)
        mouth_y = head_y + int(4 * s)
        if s >= 2:
            pygame.draw.line(screen, marble_dark,
                             (cx - int(2 * s), mouth_y),
                             (cx, mouth_y - int(0.3 * s)), lw)
            pygame.draw.line(screen, marble_dark,
                             (cx, mouth_y - int(0.3 * s)),
                             (cx + int(2 * s), mouth_y), lw)
            pygame.draw.line(screen, marble_shadow,
                             (cx - int(1.5 * s), mouth_y + int(0.8 * s)),
                             (cx + int(1.5 * s), mouth_y + int(0.8 * s)), 1)
        # ════════════════════════════════════════
        # 11. 수염 (고퀄리티 - 다층 구조 + 웨이브)
        # ════════════════════════════════════════
        beard_top = head_y + int(4.5 * s)
        beard_bottom = head_y + int(11 * s)

        # 11a) 수염 메인 형태 (복잡한 폴리곤)
        beard_pts = [
            (cx - int(5 * s), beard_top),
            (cx - int(4.5 * s), beard_top - int(0.5 * s)),
            (cx, beard_top - int(1 * s)),
            (cx + int(4.5 * s), beard_top - int(0.5 * s)),
            (cx + int(5 * s), beard_top),
            (cx + int(5 * s), beard_top + int(2 * s)),
            (cx + int(4 * s), beard_top + int(4 * s)),
            (cx + int(3 * s), beard_bottom - int(2 * s)),
            (cx + int(1.5 * s), beard_bottom - int(0.5 * s)),
            (cx, beard_bottom),
            (cx - int(1.5 * s), beard_bottom - int(0.5 * s)),
            (cx - int(3 * s), beard_bottom - int(2 * s)),
            (cx - int(4 * s), beard_top + int(4 * s)),
            (cx - int(5 * s), beard_top + int(2 * s)),
        ]
        pygame.draw.polygon(screen, marble_mid, beard_pts)
        pygame.draw.polygon(screen, marble_dark, beard_pts, lw)

        # 11b) 수염 웨이브 텍스처 (물결 모양 결)
        wave_count = max(3, int(5 * s / 2))
        for wi in range(wave_count):
            t = (wi + 1) / (wave_count + 1)
            wy = beard_top + int((beard_bottom - beard_top) * t)
            bw = int((5 - 3 * t) * s)
            wave_pts = []
            seg_count = max(3, int(4 * s / 2))
            for si in range(seg_count + 1):
                st = si / seg_count
                wx = cx - bw + int(2 * bw * st)
                wave_off = math.sin(st * math.pi * 2 + wi * 1.3) * s * 0.5
                wave_pts.append((wx, wy + int(wave_off)))
            if len(wave_pts) >= 2:
                pygame.draw.lines(screen, marble_dark, False, wave_pts, 1)

        # 11c) 수염 중앙 깊은 그림자
        pygame.draw.line(screen, marble_shadow,
                         (cx, beard_top + int(1 * s)),
                         (cx, beard_bottom - int(1 * s)), lw)
        # 양옆 볼륨 하이라이트
        if s >= 2:
            pygame.draw.line(screen, marble_light,
                             (cx + int(3 * s), beard_top + int(1 * s)),
                             (cx + int(2 * s), beard_bottom - int(2 * s)), 1)
            pygame.draw.line(screen, marble_light,
                             (cx - int(3 * s), beard_top + int(1 * s)),
                             (cx - int(2 * s), beard_bottom - int(2 * s)), 1)

        # 11d) 콧수염 (수염 위 부분)
        if s >= 1.5:
            mustache_y = beard_top - int(0.5 * s)
            pygame.draw.arc(screen, marble_dark,
                            (cx - int(4 * s), mustache_y - int(1.5 * s),
                             int(4 * s), int(3 * s)),
                            -0.3, math.pi * 0.5, lw)
            pygame.draw.arc(screen, marble_dark,
                            (cx, mustache_y - int(1.5 * s),
                             int(4 * s), int(3 * s)),
                            math.pi * 0.5, math.pi + 0.3, lw)
        # ════════════════════════════════════════
        # 12. 머리카락 (프리미엄 곱슬 - 다층 볼륨 + 흐르는 컬)
        # ════════════════════════════════════════
        hr = int(7.5 * s)
        hair_dark = (75, 68, 58)
        hair_mid = marble_shadow
        hair_light = marble_mid
        hair_hl = marble_light

        # 12a) 헤어 매스 (두꺼운 볼륨 - 폴리곤으로 풍성하게)
        hair_mass_pts = [
            # 왼쪽 사이드번 시작
            (cx - int(6.5 * s), head_y + int(3 * s)),
            (cx - int(7 * s), head_y + int(1 * s)),
            (cx - int(7.5 * s), head_y - int(1 * s)),
            # 왼쪽 상단 볼륨
            (cx - int(7.2 * s), head_y - int(4 * s)),
            (cx - int(6.5 * s), head_y - int(6 * s)),
            # 정수리
            (cx - int(4.5 * s), head_y - int(7.5 * s)),
            (cx - int(2 * s), head_y - int(8 * s)),
            (cx, head_y - int(8.2 * s)),
            (cx + int(2 * s), head_y - int(8 * s)),
            (cx + int(4.5 * s), head_y - int(7.5 * s)),
            # 오른쪽 상단 볼륨
            (cx + int(6.5 * s), head_y - int(6 * s)),
            (cx + int(7.2 * s), head_y - int(4 * s)),
            (cx + int(7.5 * s), head_y - int(1 * s)),
            (cx + int(7 * s), head_y + int(1 * s)),
            # 오른쪽 사이드번
            (cx + int(6.5 * s), head_y + int(3 * s)),
            # 아래쪽 (머리 안쪽 곡선)
            (cx + int(5.5 * s), head_y + int(1 * s)),
            (cx + int(5 * s), head_y - int(2 * s)),
            (cx + int(3 * s), head_y - int(5 * s)),
            (cx, head_y - int(6 * s)),
            (cx - int(3 * s), head_y - int(5 * s)),
            (cx - int(5 * s), head_y - int(2 * s)),
            (cx - int(5.5 * s), head_y + int(1 * s)),
        ]
        pygame.draw.polygon(screen, hair_mid, hair_mass_pts)
        pygame.draw.polygon(screen, hair_dark, hair_mass_pts, lw)

        # 12b) 헤어 볼륨 하이라이트 (윗면 밝은 톤)
        hair_hl_pts = [
            (cx - int(4 * s), head_y - int(7.2 * s)),
            (cx - int(1 * s), head_y - int(7.8 * s)),
            (cx + int(2 * s), head_y - int(7.5 * s)),
            (cx + int(5 * s), head_y - int(6 * s)),
            (cx + int(3 * s), head_y - int(5.5 * s)),
            (cx, head_y - int(6.5 * s)),
            (cx - int(3 * s), head_y - int(5.8 * s)),
        ]
        if len(hair_hl_pts) >= 3:
            pygame.draw.polygon(screen, hair_light, hair_hl_pts)

        # 12c) 개별 곱슬 컬 (정수리~이마 라인 따라 - 대형 곱슬)
        if s >= 1.5:
            curl_count = max(5, int(8 * s / 2))
            for ci in range(curl_count):
                t = ci / max(1, curl_count - 1)
                # 정수리 아크를 따라 위치
                ca = math.pi * 0.12 + (math.pi * 0.76) * t
                cr = hr + int(0.5 * s)
                curl_cx = cx + int(cr * math.cos(ca))
                curl_cy = head_y - int((cr - int(2 * s)) * math.sin(ca))
                curl_r = max(2, int(2.2 * s))
                # 곱슬 볼륨 (채워진 원 + 그림자)
                pygame.draw.circle(screen, hair_mid, (curl_cx, curl_cy), curl_r)
                # 곱슬 내부 하이라이트
                pygame.draw.circle(screen, hair_light,
                                   (curl_cx - int(0.3 * s), curl_cy - int(0.4 * s)),
                                   max(1, curl_r - int(0.8 * s)))
                # 곱슬 윤곽 아크
                pygame.draw.arc(screen, hair_dark,
                                (curl_cx - curl_r, curl_cy - curl_r,
                                 curl_r * 2, curl_r * 2),
                                ca - 0.3, ca + math.pi * 0.8, lw)

        # 12d) 머리결 흐름선 (볼륨 방향을 따라 흐르는 선)
        if s >= 2:
            for fi in range(5):
                t = (fi + 1) / 6
                flow_start_a = math.pi * 0.85 - t * 0.3
                flow_pts = []
                for seg in range(6):
                    st = seg / 5
                    a = flow_start_a - st * (math.pi * 0.55)
                    fr = hr - int(1 * s) + int(fi * 0.4 * s)
                    fx = cx + int(fr * math.cos(a))
                    fy = head_y - int((fr - int(2.5 * s)) * math.sin(a))
                    flow_pts.append((fx, fy))
                if len(flow_pts) >= 2:
                    flow_col = hair_dark if fi % 2 == 0 else hair_mid
                    pygame.draw.lines(screen, flow_col, False, flow_pts, 1)

        # 12e) 사이드번 (옆머리 → 수염 연결, 두껍고 입체적)
        if s >= 1.5:
            for side in [-1, 1]:
                sb_pts = [
                    (cx + int(side * 6.2 * s), head_y + int(0.5 * s)),
                    (cx + int(side * 6.8 * s), head_y + int(1.5 * s)),
                    (cx + int(side * 6.5 * s), head_y + int(3.5 * s)),
                    (cx + int(side * 5.5 * s), head_y + int(4.5 * s)),
                    (cx + int(side * 5 * s), head_y + int(3 * s)),
                    (cx + int(side * 5.5 * s), head_y + int(1 * s)),
                ]
                pygame.draw.polygon(screen, hair_mid, sb_pts)
                pygame.draw.polygon(screen, hair_dark, sb_pts, 1)
                # 사이드번 내부 컬 디테일
                if s >= 2.5:
                    for sb_i in range(2):
                        sb_y = head_y + int((1.5 + sb_i * 1.5) * s)
                        sb_x = cx + int(side * 6 * s)
                        pygame.draw.arc(screen, hair_dark,
                                        (sb_x - int(s), sb_y - int(s),
                                         int(2 * s), int(2 * s)),
                                        0, math.pi, 1)

        # ════════════════════════════════════════
        # 13. 월계관 (고퀄리티 올리브 잎 + 베리)
        # ════════════════════════════════════════
        wreath_color = (130, 135, 70)
        wreath_light = (160, 165, 95)
        wreath_dark = (100, 105, 50)
        wreath_gold = (195, 180, 85)
        wr = int(8 * s)

        # 13a) 줄기 (가지)
        if s >= 2:
            stem_pts = []
            for angle_deg in range(-85, 86, 5):
                a = math.radians(angle_deg - 90)
                sx = cx + int(wr * math.cos(a))
                sy = head_y + int(wr * math.sin(a))
                stem_pts.append((sx, sy))
            if len(stem_pts) >= 2:
                pygame.draw.lines(screen, wreath_dark, False, stem_pts, 1)

        # 13b) 개별 올리브 잎
        for angle_deg in range(-80, 81, 15):
            a = math.radians(angle_deg - 90)
            lx = cx + int(wr * math.cos(a))
            ly = head_y + int(wr * math.sin(a))
            leaf_outward = a + math.pi * 0.5
            leaf_len = max(2, int(3.5 * s))
            leaf_w = max(1, int(1.2 * s))
            ex = lx + int(leaf_len * math.cos(leaf_outward))
            ey = ly + int(leaf_len * math.sin(leaf_outward))

            if s >= 2:
                # 고해상도: 타원형 잎 (4점 폴리곤)
                perp = leaf_outward + math.pi * 0.5
                mid_x = (lx + ex) // 2
                mid_y = (ly + ey) // 2
                side1 = (mid_x + int(leaf_w * math.cos(perp)),
                         mid_y + int(leaf_w * math.sin(perp)))
                side2 = (mid_x - int(leaf_w * math.cos(perp)),
                         mid_y - int(leaf_w * math.sin(perp)))
                leaf_poly = [(lx, ly), side1, (ex, ey), side2]
                pygame.draw.polygon(screen, wreath_color, leaf_poly)
                pygame.draw.polygon(screen, wreath_dark, leaf_poly, 1)
                # 잎맥 (중심선)
                pygame.draw.line(screen, wreath_light, (lx, ly), (ex, ey), 1)
            else:
                pygame.draw.line(screen, wreath_color, (lx, ly), (ex, ey), lw)
                pygame.draw.circle(screen, wreath_light, (lx, ly), max(1, int(0.8 * s)))

        # 13c) 올리브 열매
        if s >= 2:
            for ba_deg in [-60, -20, 20, 60]:
                ba = math.radians(ba_deg - 90)
                bx = cx + int((wr - int(1 * s)) * math.cos(ba))
                by = head_y + int((wr - int(1 * s)) * math.sin(ba))
                berry_r = max(1, int(0.7 * s))
                pygame.draw.circle(screen, wreath_dark, (bx, by), berry_r)
                if berry_r > 1:
                    pygame.draw.circle(screen, wreath_light, (bx - 1, by - 1), max(1, berry_r - 1))

        # 13d) 정수리 보석 (화려하게)
        top_y = head_y - int(7.5 * s)
        gem_r = max(2, int(2 * s))
        # 보석 글로우
        if s >= 2:
            glow_r = gem_r + max(1, int(1 * s))
            glow_surf = _get_cached_surface(glow_r * 2 + 4, glow_r * 2 + 4)
            pygame.draw.circle(glow_surf, (200, 185, 80, 60),
                               (glow_r + 2, glow_r + 2), glow_r)
            screen.blit(glow_surf, (cx - glow_r - 2, top_y - glow_r - 2),
                        special_flags=pygame.BLEND_ADD)
        # 보석 본체
        pygame.draw.circle(screen, wreath_gold, (cx, top_y), gem_r)
        pygame.draw.circle(screen, gold_light, (cx, top_y), max(1, gem_r - 1))
        pygame.draw.circle(screen, gold_dark, (cx, top_y), gem_r, 1)
        # 보석 하이라이트 반사
        if gem_r >= 2:
            pygame.draw.circle(screen, (255, 250, 220),
                               (cx - 1, top_y - 1), max(1, int(gem_r * 0.4)))

    def _draw_judgment_arms(self, screen, cx, cy, s, marble, marble_mid, marble_dark, gold, gold_light):
        """신의심판 석상의 팔 (고퀄리티 근육 디테일, 2세그먼트 애니메이션)"""
        marble_light = (200, 192, 178)
        marble_shadow = (105, 95, 85)
        marble_bright = (218, 210, 198)
        upper_w = max(3, int(5 * s))
        fore_w = max(2, int(4 * s))
        upper_len = int(11 * s)
        fore_len = int(10 * s)
        lw = max(1, int(s))
        thick = max(1, int(2 * s))
        bicep_r = max(1, int(2.5 * s))
        elbow_r = max(2, int(2.5 * s))

        # 어깨 위치 (넓어진 어깨에 맞춤)
        l_shoulder = (cx - int(12 * s), cy - int(20 * s))
        r_shoulder = (cx + int(12 * s), cy - int(20 * s))

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

        la_elbow = (l_shoulder[0] + int(upper_len * math.sin(la_angle)),
                    l_shoulder[1] + int(upper_len * math.cos(la_angle)))
        fore_angle = la_angle + la_elbow_bend
        la_hand = (la_elbow[0] + int(fore_len * math.sin(fore_angle)),
                   la_elbow[1] + int(fore_len * math.cos(fore_angle)))

        # 상완 그림자 (입체감)
        shadow_ox = int(1 * s * math.cos(la_angle))
        shadow_oy = -int(1 * s * math.sin(la_angle))
        pygame.draw.line(screen, marble_dark,
                         (l_shoulder[0] + shadow_ox, l_shoulder[1] + shadow_oy),
                         (la_elbow[0] + shadow_ox, la_elbow[1] + shadow_oy),
                         max(1, upper_w - 1))
        # 상완 본체
        pygame.draw.line(screen, marble, l_shoulder, la_elbow, upper_w)
        # 상완 하이라이트
        hl_ox = -shadow_ox
        hl_oy = -shadow_oy
        pygame.draw.line(screen, marble_light,
                         (l_shoulder[0] + hl_ox, l_shoulder[1] + hl_oy),
                         (la_elbow[0] + hl_ox, la_elbow[1] + hl_oy), 1)
        # 이두근 벌지
        if s >= 2:
            mid_x = (l_shoulder[0] + la_elbow[0]) // 2
            mid_y = (l_shoulder[1] + la_elbow[1]) // 2
            pygame.draw.circle(screen, marble, (mid_x, mid_y), bicep_r)
            pygame.draw.arc(screen, marble_dark,
                            (mid_x - bicep_r, mid_y - bicep_r,
                             bicep_r * 2, bicep_r * 2),
                            la_angle - 0.5, la_angle + 0.5, 1)

        # 전완 그림자 + 본체 + 하이라이트
        pygame.draw.line(screen, marble_dark,
                         (la_elbow[0] + shadow_ox, la_elbow[1] + shadow_oy),
                         (la_hand[0] + shadow_ox, la_hand[1] + shadow_oy),
                         max(1, fore_w - 1))
        pygame.draw.line(screen, marble_mid, la_elbow, la_hand, fore_w)
        pygame.draw.line(screen, marble_light,
                         (la_elbow[0] + hl_ox, la_elbow[1] + hl_oy),
                         (la_hand[0] + hl_ox, la_hand[1] + hl_oy), 1)

        # 팔꿈치 관절 (디테일)
        pygame.draw.circle(screen, marble, la_elbow, elbow_r)
        pygame.draw.circle(screen, marble_dark, la_elbow, elbow_r, lw)

        # 주먹 (디테일)
        fist_r = max(2, int(3 * s))
        pygame.draw.circle(screen, marble, la_hand, fist_r)
        pygame.draw.circle(screen, marble_mid, la_hand, fist_r, lw)
        pygame.draw.circle(screen, marble_light,
                           (la_hand[0] - int(0.5 * s), la_hand[1] - int(0.5 * s)),
                           max(1, fist_r - int(1 * s)))
        # 손가락 힌트
        if s >= 2.5:
            for fi in range(-1, 2):
                fx = la_hand[0] + int(fi * 1.2 * s * math.cos(fore_angle))
                fy = la_hand[1] + int(fi * 1.2 * s * math.sin(fore_angle))
                pygame.draw.line(screen, marble_dark,
                                 (fx, fy),
                                 (fx + int(1.5 * s * math.sin(fore_angle)),
                                  fy + int(1.5 * s * math.cos(fore_angle))), 1)

        # 삼각근 덮개 (어깨 근육)
        if s >= 1.5:
            delt_pts = [
                l_shoulder,
                (l_shoulder[0] - int(2 * s), l_shoulder[1] + int(3 * s)),
                (l_shoulder[0] + int(upper_len * 0.3 * math.sin(la_angle)),
                 l_shoulder[1] + int(upper_len * 0.3 * math.cos(la_angle))),
            ]
            pygame.draw.polygon(screen, marble, delt_pts)
            pygame.draw.polygon(screen, marble_dark, delt_pts, 1)

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

        # 오른팔 그림자
        r_sox = -int(1 * s * math.cos(ra_angle))
        r_soy = int(1 * s * math.sin(ra_angle))
        pygame.draw.line(screen, marble_dark,
                         (r_shoulder[0] + r_sox, r_shoulder[1] + r_soy),
                         (ra_elbow[0] + r_sox, ra_elbow[1] + r_soy),
                         max(1, upper_w - 1))
        # 상완 본체 + 하이라이트
        pygame.draw.line(screen, marble, r_shoulder, ra_elbow, upper_w)
        r_hlx = -r_sox
        r_hly = -r_soy
        pygame.draw.line(screen, marble_light,
                         (r_shoulder[0] + r_hlx, r_shoulder[1] + r_hly),
                         (ra_elbow[0] + r_hlx, ra_elbow[1] + r_hly), 1)
        # 이두근 벌지 (오른팔)
        if s >= 2:
            r_mid_x = (r_shoulder[0] + ra_elbow[0]) // 2
            r_mid_y = (r_shoulder[1] + ra_elbow[1]) // 2
            pygame.draw.circle(screen, marble, (r_mid_x, r_mid_y), bicep_r)
            pygame.draw.arc(screen, marble_dark,
                            (r_mid_x - bicep_r, r_mid_y - bicep_r,
                             bicep_r * 2, bicep_r * 2),
                            ra_angle - 0.5, ra_angle + 0.5, 1)

        # 전완 그림자 + 본체 + 하이라이트
        pygame.draw.line(screen, marble_dark,
                         (ra_elbow[0] + r_sox, ra_elbow[1] + r_soy),
                         (ra_hand[0] + r_sox, ra_hand[1] + r_soy),
                         max(1, fore_w - 1))
        pygame.draw.line(screen, marble_mid, ra_elbow, ra_hand, fore_w)
        pygame.draw.line(screen, marble_light,
                         (ra_elbow[0] + r_hlx, ra_elbow[1] + r_hly),
                         (ra_hand[0] + r_hlx, ra_hand[1] + r_hly), 1)

        # 팔꿈치 + 주먹
        pygame.draw.circle(screen, marble, ra_elbow, elbow_r)
        pygame.draw.circle(screen, marble_dark, ra_elbow, elbow_r, lw)
        pygame.draw.circle(screen, marble, ra_hand, fist_r)
        pygame.draw.circle(screen, marble_mid, ra_hand, fist_r, lw)
        pygame.draw.circle(screen, marble_light,
                           (ra_hand[0] + int(0.5 * s), ra_hand[1] - int(0.5 * s)),
                           max(1, fist_r - int(1 * s)))
        # 오른쪽 손가락 힌트
        if s >= 2.5:
            for fi in range(-1, 2):
                fx = ra_hand[0] + int(fi * 1.2 * s * math.cos(fore_angle_r))
                fy = ra_hand[1] + int(fi * 1.2 * s * math.sin(fore_angle_r))
                pygame.draw.line(screen, marble_dark,
                                 (fx, fy),
                                 (fx + int(1.5 * s * math.sin(fore_angle_r)),
                                  fy + int(1.5 * s * math.cos(fore_angle_r))), 1)

        # 삼각근 덮개 (오른쪽)
        if s >= 1.5:
            r_delt_pts = [
                r_shoulder,
                (r_shoulder[0] + int(2 * s), r_shoulder[1] + int(3 * s)),
                (r_shoulder[0] + int(upper_len * 0.3 * math.sin(ra_angle)),
                 r_shoulder[1] + int(upper_len * 0.3 * math.cos(ra_angle))),
            ]
            pygame.draw.polygon(screen, marble, r_delt_pts)
            pygame.draw.polygon(screen, marble_dark, r_delt_pts, 1)

        # ── 오른손 무기 (variant에 따라 번개/해머/부채) ──
        if self.judgment_variant == 'wind':
            # ══════ 천상의 화초선 (바람의 분노 전용 - 고퀄리티) ══════
            fan_angle = fore_angle_r
            fx, fy = ra_hand
            handle_len = int(13 * s)
            fdir_x = math.sin(fan_angle)
            fdir_y = math.cos(fan_angle)
            perp_fx, perp_fy = fdir_y, -fdir_x

            tip_x = fx + int(handle_len * fdir_x)
            tip_y = fy + int(handle_len * fdir_y)

            # ── 색상 팔레트 (고급 옻칠+비단) ──
            bamboo = (160, 130, 70)
            bamboo_dark = (120, 95, 50)
            bamboo_light = (195, 165, 100)
            bamboo_bright = (210, 180, 120)
            lacquer = (80, 30, 25)
            lacquer_light = (120, 50, 35)
            silk = (200, 170, 100)
            silk_dark = (170, 140, 75)
            silk_light = (235, 210, 150)
            silk_cream = (245, 230, 190)
            gold_trim = (218, 185, 95)
            gold_bright = (240, 210, 130)
            gold_dark = (170, 140, 60)
            jade = (120, 180, 130)

            # ── 자루 (옻칠 대나무 - 3층 입체) ──
            handle_w = max(2, int(2.5 * s))
            pygame.draw.line(screen, (60, 40, 30),
                             (fx + 2, fy + 2), (tip_x + 2, tip_y + 2), handle_w + 1)
            pygame.draw.line(screen, bamboo_dark,
                             (fx + 1, fy + 1), (tip_x + 1, tip_y + 1), handle_w)
            pygame.draw.line(screen, bamboo, (fx, fy), (tip_x, tip_y), handle_w)
            hl_off = max(1, int(0.5 * s))
            pygame.draw.line(screen, bamboo_bright,
                             (fx - int(hl_off * perp_fx), fy - int(hl_off * perp_fy)),
                             (tip_x - int(hl_off * perp_fx), tip_y - int(hl_off * perp_fy)), 1)

            # ── 자루 마디 (대나무 매듭 + 옻칠 장식) ──
            for ti, t in enumerate((0.25, 0.50, 0.75)):
                bx = fx + int(handle_len * t * fdir_x)
                by = fy + int(handle_len * t * fdir_y)
                knot_half = max(1, int(2 * s))
                k1 = (bx - int(knot_half * perp_fx), by - int(knot_half * perp_fy))
                k2 = (bx + int(knot_half * perp_fx), by + int(knot_half * perp_fy))
                k_col = lacquer if ti == 1 else bamboo_dark
                pygame.draw.line(screen, k_col, k1, k2, max(1, int(1.2 * s)))
                if s >= 2:
                    pygame.draw.line(screen, bamboo_light,
                                     (bx - int(knot_half * 0.5 * perp_fx),
                                      by - int(knot_half * 0.5 * perp_fy)),
                                     (bx + int(knot_half * 0.5 * perp_fx),
                                      by + int(knot_half * 0.5 * perp_fy)), 1)

            # ── 자루 끝 옥 장식 (폼멜) ──
            pommel_r = max(1, int(1.5 * s))
            pommel_x = fx - int(2 * s * fdir_x)
            pommel_y = fy - int(2 * s * fdir_y)
            pygame.draw.circle(screen, jade, (pommel_x, pommel_y), pommel_r)
            if s >= 2:
                pygame.draw.circle(screen, (150, 210, 160),
                                   (pommel_x - int(0.3 * s), pommel_y - int(0.3 * s)),
                                   max(1, pommel_r - 1))

            # ── 핸들-부채 금속 피봇 ──
            pivot_r = max(2, int(2.5 * s))
            pygame.draw.circle(screen, gold_dark, (tip_x, tip_y), pivot_r + 1)
            pygame.draw.circle(screen, gold_trim, (tip_x, tip_y), pivot_r)
            pygame.draw.circle(screen, gold_bright,
                               (tip_x - int(0.3 * s), tip_y - int(0.3 * s)),
                               max(1, pivot_r - 1))

            # ── 부채 본체 (확대 + 더 넓은 펼침) ──
            fan_center_x = tip_x + int(2 * s * fdir_x)
            fan_center_y = tip_y + int(2 * s * fdir_y)
            fan_radius = int(16 * s)
            fan_spread = math.pi * 0.72
            base_ang = math.atan2(fdir_x, fdir_y)

            # ── 비단 면 (다층 - 외곽 반투명) ──
            rib_count = 11
            fan_pts_outer = [(fan_center_x, fan_center_y)]
            for i in range(rib_count + 6):
                t = i / (rib_count + 5)
                rib_ang = base_ang - fan_spread / 2 + fan_spread * t
                r_val = fan_radius * (0.97 + 0.03 * math.sin(t * 8))
                px = fan_center_x + int(r_val * math.sin(rib_ang))
                py = fan_center_y + int(r_val * math.cos(rib_ang))
                fan_pts_outer.append((px, py))
            if len(fan_pts_outer) >= 3:
                fan_surf = _get_cached_surface(self.width, self.height)
                pygame.draw.polygon(fan_surf, (*silk, 190), fan_pts_outer)
                screen.blit(fan_surf, (0, 0))

            # 내부 비단 (밝은 크림 톤)
            if s >= 1.5:
                inner_pts = [(fan_center_x, fan_center_y)]
                for i in range(rib_count + 4):
                    t = i / (rib_count + 3)
                    rib_ang = base_ang - fan_spread / 2 + fan_spread * t
                    r_val = fan_radius * 0.7
                    px = fan_center_x + int(r_val * math.sin(rib_ang))
                    py = fan_center_y + int(r_val * math.cos(rib_ang))
                    inner_pts.append((px, py))
                if len(inner_pts) >= 3:
                    inner_surf = _get_cached_surface(self.width, self.height)
                    pygame.draw.polygon(inner_surf, (*silk_cream, 60), inner_pts)
                    screen.blit(inner_surf, (0, 0))

            # ── 부채살 (입체감 강화 - 그림자+본체+하이라이트) ──
            for i in range(rib_count):
                t = i / max(1, rib_count - 1)
                rib_ang = base_ang - fan_spread / 2 + fan_spread * t
                rx = fan_center_x + int(fan_radius * math.sin(rib_ang))
                ry = fan_center_y + int(fan_radius * math.cos(rib_ang))
                pygame.draw.line(screen, bamboo_dark,
                                 (fan_center_x + 1, fan_center_y + 1),
                                 (rx + 1, ry + 1), max(1, int(0.9 * s)))
                if i == 0 or i == rib_count - 1:
                    rib_col = lacquer
                elif i % 3 == 0:
                    rib_col = bamboo_light
                else:
                    rib_col = bamboo
                pygame.draw.line(screen, rib_col,
                                 (fan_center_x, fan_center_y), (rx, ry),
                                 max(1, int(0.9 * s)))
                if s >= 2.5 and i % 2 == 0:
                    mid_rx = (fan_center_x + rx) // 2
                    mid_ry = (fan_center_y + ry) // 2
                    pygame.draw.line(screen, bamboo_bright,
                                     (fan_center_x, fan_center_y), (mid_rx, mid_ry), 1)

            # ── 비단 테두리 ──
            if len(fan_pts_outer) >= 3:
                pygame.draw.polygon(screen, silk_dark, fan_pts_outer, max(1, int(s)))

            # ── 장식 패턴 (동심원호 4중 + 구름 문양) ──
            for ring in range(4):
                ring_r = int(fan_radius * (0.3 + ring * 0.17))
                if ring_r > 3:
                    arc_start = base_ang - fan_spread / 2
                    arc_end = base_ang + fan_spread / 2
                    arc_rect = (fan_center_x - ring_r, fan_center_y - ring_r,
                                ring_r * 2, ring_r * 2)
                    a1 = -(arc_end - math.pi / 2)
                    a2 = -(arc_start - math.pi / 2)
                    col = gold_trim if ring in (1, 3) else silk_dark
                    pygame.draw.arc(screen, col, arc_rect, a1, a2, 1)

            # 구름 문양 (S자 소용돌이)
            if s >= 2:
                for ci in range(3):
                    cloud_t = 0.25 + ci * 0.25
                    cloud_ang = base_ang - fan_spread / 2 + fan_spread * cloud_t
                    cloud_r_base = fan_radius * 0.55
                    cloud_cx = fan_center_x + int(cloud_r_base * math.sin(cloud_ang))
                    cloud_cy = fan_center_y + int(cloud_r_base * math.cos(cloud_ang))
                    swirl_r = max(2, int(2 * s))
                    pygame.draw.arc(screen, silk_dark,
                                    (int(cloud_cx) - swirl_r, int(cloud_cy) - swirl_r,
                                     swirl_r * 2, swirl_r * 2),
                                    cloud_ang, cloud_ang + math.pi, 1)
                    pygame.draw.circle(screen, gold_trim,
                                       (int(cloud_cx), int(cloud_cy)), max(1, int(0.6 * s)))

            # ── 금 테두리 (2중 라인 - 외곽+내곽) ──
            prev_ox, prev_oy = None, None
            for i in range(rib_count + 6):
                t = i / (rib_count + 5)
                rib_ang = base_ang - fan_spread / 2 + fan_spread * t
                ox = fan_center_x + int(fan_radius * math.sin(rib_ang))
                oy = fan_center_y + int(fan_radius * math.cos(rib_ang))
                if prev_ox is not None:
                    pygame.draw.line(screen, gold_trim, (prev_ox, prev_oy), (ox, oy),
                                     max(1, int(1.2 * s)))
                    inner_frac = 0.95
                    prev_ang = base_ang - fan_spread / 2 + fan_spread * ((i - 1) / (rib_count + 5))
                    iox1 = fan_center_x + int(fan_radius * inner_frac * math.sin(prev_ang))
                    ioy1 = fan_center_y + int(fan_radius * inner_frac * math.cos(prev_ang))
                    iox2 = fan_center_x + int(fan_radius * inner_frac * math.sin(rib_ang))
                    ioy2 = fan_center_y + int(fan_radius * inner_frac * math.cos(rib_ang))
                    pygame.draw.line(screen, gold_bright, (iox1, ioy1), (iox2, ioy2), 1)
                prev_ox, prev_oy = ox, oy

            # ── 양 끝 옥 구슬 장식 ──
            if s >= 2:
                for end_t in (0.0, 1.0):
                    end_ang = base_ang - fan_spread / 2 + fan_spread * end_t
                    bead_x = fan_center_x + int((fan_radius + 2 * s) * math.sin(end_ang))
                    bead_y = fan_center_y + int((fan_radius + 2 * s) * math.cos(end_ang))
                    bead_r = max(1, int(1.5 * s))
                    pygame.draw.circle(screen, jade, (int(bead_x), int(bead_y)), bead_r)
                    pygame.draw.circle(screen, (160, 220, 170),
                                       (int(bead_x) - int(0.3 * s), int(bead_y) - int(0.3 * s)),
                                       max(1, bead_r - 1))

            # ── 바람 충전 글로우 (다층 + 소용돌이 라인) ──
            intensity = self.judgment_wind_charge_intensity
            if intensity > 0.1:
                sparkle = 0.5 + 0.5 * math.sin(self.time * 8)
                flash = max(0, math.sin(self.time * 15)) * 0.3
                glow_intensity = intensity * (0.5 + 0.5 * sparkle + flash)

                for gi, (g_frac, g_alpha_base) in enumerate([
                    (1.0, 15), (0.6, 25), (0.3, 40)
                ]):
                    glow_r = max(3, int((fan_radius * 0.35 + glow_intensity * 7) * g_frac))
                    if glow_r > 2:
                        g_pulse = sparkle if gi == 0 else 1.0
                        glow_col = (min(255, int((160 + 80 * glow_intensity) * g_pulse)),
                                    min(255, int((180 + 60 * glow_intensity) * g_pulse)),
                                    min(255, int((100 + 50 * glow_intensity) * g_pulse)))
                        glow_alpha = min(80, int(g_alpha_base * glow_intensity))
                        glow_surf = _get_cached_surface(glow_r * 2 + 4, glow_r * 2 + 4)
                        pygame.draw.circle(glow_surf, (*glow_col, glow_alpha),
                                           (glow_r + 2, glow_r + 2), glow_r)
                        screen.blit(glow_surf,
                                    (fan_center_x - glow_r - 2, fan_center_y - glow_r - 2),
                                    special_flags=pygame.BLEND_ADD)

                # 소용돌이 바람 라인
                if intensity > 0.3 and s >= 2:
                    swirl_count = int(2 + intensity * 3)
                    for si in range(swirl_count):
                        sw_base = (si / swirl_count) * math.pi * 2 + self.time * 4
                        sw_r_start = fan_radius * 0.3
                        sw_r_end = fan_radius * 0.8
                        sw_pts = []
                        for step in range(6):
                            sw_t = step / 5
                            sw_ang = sw_base + sw_t * math.pi * 0.8
                            sw_r = sw_r_start + (sw_r_end - sw_r_start) * sw_t
                            sw_x = fan_center_x + int(sw_r * math.cos(sw_ang))
                            sw_y = fan_center_y + int(sw_r * math.sin(sw_ang))
                            sw_pts.append((sw_x, sw_y))
                        sw_col = (min(255, int(180 + 60 * glow_intensity)),
                                  min(255, int(200 + 40 * glow_intensity)),
                                  min(255, int(140 + 50 * glow_intensity)))
                        for spi in range(len(sw_pts) - 1):
                            pygame.draw.line(screen, sw_col, sw_pts[spi], sw_pts[spi + 1], 1)

            # ── 공전 바람 스트릭 (얇은 바람 선) ──
            for ep in self.judgment_fan_energy_particles:
                if ep.get('current_alpha', 0) < 5:
                    continue
                px = fan_center_x + int(ep['dist'] * math.cos(ep['angle']))
                py = fan_center_y + int(ep['dist'] * math.sin(ep['angle']))
                ep_alpha = ep.get('current_alpha', ep['alpha'])
                # 바람 방향 (공전 접선 방향 = 각도 + 90도)
                tang_ang = ep['angle'] + math.pi * 0.5
                streak_len = max(2, int(ep['size'] * 3.5))
                # 선 시작/끝점
                sx1 = px - int(streak_len * math.cos(tang_ang))
                sy1 = py - int(streak_len * math.sin(tang_ang))
                sx2 = px + int(streak_len * math.cos(tang_ang))
                sy2 = py + int(streak_len * math.sin(tang_ang))
                streak_col = (min(255, ep['color'][0]),
                              min(255, ep['color'][1]),
                              min(255, ep['color'][2]))
                pygame.draw.line(screen, streak_col, (sx1, sy1), (sx2, sy2), 1)
        elif self.judgment_variant == 'lightning':
            # ══════ 제우스의 번개 (번개의 분노 전용 - 고퀄리티) ══════
            if self.judgment_bolt_hidden:
                for sp in self.judgment_bolt_sparks:
                    sx, sy = int(sp['x']), int(sp['y'])
                    sp_size = max(1, int(sp['size'] * min(1.0, sp['life'] * 3)))
                    if sp_size > 0:
                        # 스파크 글로우 레이어
                        if sp_size >= 2:
                            sp_surf = _get_cached_surface(sp_size * 4, sp_size * 4)
                            pygame.draw.circle(sp_surf, (*sp['color'], 120),
                                               (sp_size * 2, sp_size * 2), sp_size * 2)
                            pygame.draw.circle(sp_surf, (255, 255, 220, 200),
                                               (sp_size * 2, sp_size * 2), sp_size)
                            screen.blit(sp_surf, (sx - sp_size * 2, sy - sp_size * 2),
                                        special_flags=pygame.BLEND_ADD)
                        pygame.draw.circle(screen, sp['color'], (sx, sy), sp_size)
                return
            bolt_angle = fore_angle_r
            bolt_x, bolt_y = ra_hand
            bolt_len = int(20 * s)  # 더 길게
            bdir_x = math.sin(bolt_angle)
            bdir_y = math.cos(bolt_angle)
            perp_x, perp_y = bdir_y, -bdir_x

            intensity = self.judgment_bolt_intensity
            pulse = 0.5 + 0.5 * math.sin(self.time * 6)

            # ── 메인 지그재그 (더 복잡한 경로 - 8세그먼트) ──
            zigzag = [
                (0, 0),
                (-3.5, 0.15), (3, 0.28), (-2.5, 0.42),
                (2, 0.55), (-3, 0.68), (1.5, 0.82), (-1.5, 1.0),
            ]
            segs = []
            for zx, zt in zigzag:
                px = bolt_x + int(zx * s * perp_x) + int(bolt_len * zt * bdir_x)
                py = bolt_y + int(zx * s * perp_y) + int(bolt_len * zt * bdir_y)
                segs.append((px, py))

            # ── 분기 번개 (메인 경로에서 갈라지는 작은 번개) ──
            if intensity > 0.1:
                # 분기 번개 (세그먼트에서 파생)
                branch_count = int(2 + intensity * 5)
                for _ in range(branch_count):
                    seg_idx = random.randint(1, len(segs) - 2)
                    bx, by = segs[seg_idx]
                    b_angle = random.uniform(0, math.pi * 2)
                    b_len = random.uniform(3, 10) * s * intensity
                    b_pts = [(bx, by)]
                    for step in range(3):
                        b_angle += random.uniform(-1.0, 1.0)
                        step_l = b_len * (0.5 - step * 0.12)
                        if step_l < 1:
                            break
                        nx = b_pts[-1][0] + int(math.cos(b_angle) * step_l)
                        ny = b_pts[-1][1] + int(math.sin(b_angle) * step_l)
                        b_pts.append((nx, ny))
                    b_col = (min(255, int(180 + random.random() * 75)),
                             min(255, int(200 + random.random() * 55)),
                             min(255, int(220 + random.random() * 35)))
                    for bi in range(len(b_pts) - 1):
                        pygame.draw.line(screen, b_col, b_pts[bi], b_pts[bi + 1], 1)

                # 코로나 아크 (번개 주변의 전기 아크)
                if s >= 2:
                    arc_count = int(intensity * 4)
                    for _ in range(arc_count):
                        seg_idx = random.randint(0, len(segs) - 1)
                        ax, ay = segs[seg_idx]
                        arc_angle = random.uniform(0, math.pi * 2)
                        arc_len_val = random.uniform(4, 12) * s * intensity
                        a_pts = [(ax, ay)]
                        for step in range(3):
                            arc_angle += random.uniform(-0.9, 0.9)
                            step_l = arc_len_val * (0.4 + step * 0.2)
                            nx = a_pts[-1][0] + int(math.cos(arc_angle) * step_l)
                            ny = a_pts[-1][1] + int(math.sin(arc_angle) * step_l)
                            a_pts.append((nx, ny))
                        a_col = (255, int(220 + random.random() * 35),
                                 int(80 + random.random() * 80))
                        for ai in range(len(a_pts) - 1):
                            pygame.draw.line(screen, a_col, a_pts[ai], a_pts[ai + 1], 1)

            # ── 4층 렌더링: 외곽 글로우 → 중간 글로우 → 코어 → 핫코어 ──

            # 레이어 1: 외곽 글로우 (넓고 어두운 블루)
            outer_glow_w = max(2, int(4 * s)) + int(intensity * 3 * s)
            outer_col = (min(255, 80 + int(60 * intensity)),
                         min(255, 100 + int(80 * intensity)),
                         min(255, 200 + int(55 * intensity)))
            for i in range(len(segs) - 1):
                pygame.draw.line(screen, outer_col, segs[i], segs[i + 1], outer_glow_w)

            # 레이어 2: 중간 글로우 (밝은 골드)
            mid_glow_w = max(1, int(3 * s)) + int(intensity * 2 * s)
            glow_r_val = min(255, 180 + int(75 * intensity))
            glow_g_val = min(255, 160 + int(80 * intensity))
            glow_b_val = min(255, 60 + int(100 * intensity))
            for i in range(len(segs) - 1):
                pygame.draw.line(screen, (glow_r_val, glow_g_val, glow_b_val),
                                 segs[i], segs[i + 1], mid_glow_w)

            # 레이어 3: 코어 (밝은 화이트-옐로우)
            core_r_val = min(255, 220 + int(35 * intensity))
            core_g_val = min(255, 195 + int(60 * intensity))
            core_b_val = min(255, 100 + int(100 * intensity))
            bolt_core_w = max(1, lw + int(intensity * 1.2 * s))
            for i in range(len(segs) - 1):
                pygame.draw.line(screen, (core_r_val, core_g_val, core_b_val),
                                 segs[i], segs[i + 1], bolt_core_w)

            # 레이어 4: 핫코어 (눈부신 화이트, 고intensity에서만)
            if intensity > 0.5:
                white_frac = (intensity - 0.5) * 2
                white_col = (min(255, int(220 + 35 * white_frac)),
                             min(255, int(220 + 35 * white_frac)),
                             min(255, int(200 + 55 * white_frac)))
                for i in range(len(segs) - 1):
                    pygame.draw.line(screen, white_col, segs[i], segs[i + 1], max(1, lw))

            # ── 번개 끝 스파크 스타 (확대 + 방사형 광선) ──
            tip = segs[-1]
            sl = max(1, int((4 + 4 * intensity) * s))
            spark_col = (min(255, int(230 + 25 * intensity)),
                         min(255, int(210 + 45 * intensity)),
                         min(255, int(120 + 80 * intensity)))
            # 메인 십자
            pygame.draw.line(screen, spark_col, (tip[0] - sl, tip[1]), (tip[0] + sl, tip[1]), max(1, int(0.8 * s)))
            pygame.draw.line(screen, spark_col, (tip[0], tip[1] - sl), (tip[0], tip[1] + sl), max(1, int(0.8 * s)))
            # 대각선 십자
            dsl = max(1, int(sl * 0.75))
            pygame.draw.line(screen, spark_col,
                             (tip[0] - dsl, tip[1] - dsl), (tip[0] + dsl, tip[1] + dsl), 1)
            pygame.draw.line(screen, spark_col,
                             (tip[0] + dsl, tip[1] - dsl), (tip[0] - dsl, tip[1] + dsl), 1)
            # 추가 방사선 (8방향 - intensity 높을 때)
            if intensity > 0.3 and s >= 2:
                for ri in range(8):
                    ray_ang = ri * math.pi / 4 + self.time * 2
                    ray_l = int((2 + 4 * intensity) * s)
                    ray_alpha_mod = 0.5 + 0.5 * math.sin(self.time * 10 + ri)
                    rx1 = tip[0] + int(2 * s * math.cos(ray_ang))
                    ry1 = tip[1] + int(2 * s * math.sin(ray_ang))
                    rx2 = tip[0] + int(ray_l * math.cos(ray_ang))
                    ry2 = tip[1] + int(ray_l * math.sin(ray_ang))
                    rc = (min(255, int(spark_col[0] * ray_alpha_mod)),
                          min(255, int(spark_col[1] * ray_alpha_mod)),
                          min(255, int(spark_col[2] * ray_alpha_mod)))
                    pygame.draw.line(screen, rc, (rx1, ry1), (rx2, ry2), 1)
            # 끝 글로우 점
            tip_glow_r = max(2, int(3 * s * (0.5 + 0.5 * intensity)))
            tip_surf = _get_cached_surface(tip_glow_r * 2 + 4, tip_glow_r * 2 + 4)
            pygame.draw.circle(tip_surf, (255, 240, 180, min(100, int(40 + 60 * intensity))),
                               (tip_glow_r + 2, tip_glow_r + 2), tip_glow_r)
            screen.blit(tip_surf, (tip[0] - tip_glow_r - 2, tip[1] - tip_glow_r - 2),
                        special_flags=pygame.BLEND_ADD)

            # ── 시작점 (손) 에너지 노드 ──
            start_glow_r = max(2, int(2.5 * s * (0.3 + 0.7 * intensity)))
            s_surf = _get_cached_surface(start_glow_r * 2 + 4, start_glow_r * 2 + 4)
            pygame.draw.circle(s_surf, (200, 190, 255, min(60, int(20 + 40 * intensity))),
                               (start_glow_r + 2, start_glow_r + 2), start_glow_r)
            screen.blit(s_surf, (bolt_x - start_glow_r - 2, bolt_y - start_glow_r - 2),
                        special_flags=pygame.BLEND_ADD)

            # ── 중간 에너지 노드 (번개 중앙 광점) ──
            mid = segs[len(segs) // 2]
            mid_r = max(2, int(2 * s) + int(intensity * 2.5 * s))
            mid_surf = _get_cached_surface(mid_r * 2 + 4, mid_r * 2 + 4)
            pygame.draw.circle(mid_surf, (255, 245, 200, min(80, int(30 + 50 * intensity * pulse))),
                               (mid_r + 2, mid_r + 2), mid_r)
            pygame.draw.circle(mid_surf, (255, 255, 240, min(120, int(60 + 60 * intensity))),
                               (mid_r + 2, mid_r + 2), max(1, mid_r // 2))
            screen.blit(mid_surf, (mid[0] - mid_r - 2, mid[1] - mid_r - 2),
                        special_flags=pygame.BLEND_ADD)

            # ── 스파크 파티클 (고퀄리티 멀티레이어) ──
            for sp in self.judgment_bolt_sparks:
                sx, sy = int(sp['x']), int(sp['y'])
                sp_size = max(1, int(sp['size'] * min(1.0, sp['life'] * 3)))
                if sp_size > 0:
                    # 외곽 글로우
                    if sp_size >= 2:
                        sp_surf = _get_cached_surface(sp_size * 4, sp_size * 4)
                        pygame.draw.circle(sp_surf, (*sp['color'][:3], 80),
                                           (sp_size * 2, sp_size * 2), sp_size * 2)
                        pygame.draw.circle(sp_surf, (255, 255, 230, 150),
                                           (sp_size * 2, sp_size * 2), sp_size)
                        screen.blit(sp_surf, (sx - sp_size * 2, sy - sp_size * 2),
                                    special_flags=pygame.BLEND_ADD)
                    pygame.draw.circle(screen, sp['color'], (sx, sy), sp_size)
                    if sp_size > 1:
                        pygame.draw.circle(screen, (255, 255, 230),
                                           (sx, sy), max(1, sp_size - 1))
        else:
            # ══════ 고대 토르 해머 (땅의 분노 전용 - 고퀄리티) ══════
            hammer_angle = fore_angle_r
            hx, hy = ra_hand
            handle_len = int(18 * s)
            hdir_x = math.sin(hammer_angle)
            hdir_y = math.cos(hammer_angle)
            perp_hx, perp_hy = hdir_y, -hdir_x

            tip_x = hx + int(handle_len * hdir_x)
            tip_y = hy + int(handle_len * hdir_y)

            # ── 색상 팔레트 (고급 대리석+철) ──
            wood = (120, 90, 55)
            wood_dark = (95, 70, 40)
            wood_light = (155, 125, 80)
            leather = (85, 65, 40)
            leather_light = (110, 85, 55)
            iron = (105, 95, 80)
            iron_light = (150, 138, 118)
            iron_bright = (175, 162, 140)
            iron_dark = (70, 60, 50)
            iron_edge = (55, 48, 38)
            rune_glow = (200, 160, 60)
            rune_dim = (150, 130, 90)

            intensity = self.judgment_bolt_intensity
            pulse = 0.5 + 0.5 * math.sin(self.time * 3)

            # ── 핸들 (나무 자루 - 3층 입체) ──
            handle_w = max(2, int(2.5 * s))
            # 드롭 섀도우
            pygame.draw.line(screen, (60, 45, 30),
                             (hx + 2, hy + 2), (tip_x + 2, tip_y + 2), handle_w + 1)
            # 핸들 그림자 면
            pygame.draw.line(screen, wood_dark,
                             (hx + 1, hy + 1), (tip_x + 1, tip_y + 1), handle_w)
            # 핸들 본체
            pygame.draw.line(screen, wood, (hx, hy), (tip_x, tip_y), handle_w)
            # 핸들 하이라이트 (나무결 느낌)
            hl_offset = max(1, int(0.5 * s))
            hhl_x1 = hx - int(hl_offset * perp_hx)
            hhl_y1 = hy - int(hl_offset * perp_hy)
            hhl_x2 = tip_x - int(hl_offset * perp_hx)
            hhl_y2 = tip_y - int(hl_offset * perp_hy)
            pygame.draw.line(screen, wood_light, (hhl_x1, hhl_y1), (hhl_x2, hhl_y2), 1)
            # 나무결 라인 (2줄)
            if s >= 2:
                for grain_off in (0.3, -0.3):
                    gx1 = hx + int(grain_off * s * perp_hx)
                    gy1 = hy + int(grain_off * s * perp_hy)
                    gx2 = tip_x + int(grain_off * s * perp_hx)
                    gy2 = tip_y + int(grain_off * s * perp_hy)
                    pygame.draw.line(screen, wood_dark, (gx1, gy1), (gx2, gy2), 1)

            # ── 가죽 감기 (크로스 패턴 - 그립감 표현) ──
            band_w = max(1, int(1.5 * s))
            band_half = max(1, int(2 * s))
            for t in (0.2, 0.35, 0.50, 0.65, 0.80):
                bx = hx + int(handle_len * t * hdir_x)
                by = hy + int(handle_len * t * hdir_y)
                b1 = (bx - int(band_half * perp_hx), by - int(band_half * perp_hy))
                b2 = (bx + int(band_half * perp_hx), by + int(band_half * perp_hy))
                pygame.draw.line(screen, leather, b1, b2, band_w)
                # X자 크로스 스티치 (2번째, 4번째)
                if s >= 2 and t in (0.35, 0.65):
                    bx2 = hx + int(handle_len * (t + 0.05) * hdir_x)
                    by2 = hy + int(handle_len * (t + 0.05) * hdir_y)
                    pygame.draw.line(screen, leather_light,
                                     (bx - int(1 * s * perp_hx), by - int(1 * s * perp_hy)),
                                     (bx2 + int(1 * s * perp_hx), by2 + int(1 * s * perp_hy)), 1)
                    pygame.draw.line(screen, leather_light,
                                     (bx + int(1 * s * perp_hx), by + int(1 * s * perp_hy)),
                                     (bx2 - int(1 * s * perp_hx), by2 - int(1 * s * perp_hy)), 1)

            # ── 핸들-헤드 금속 칼라 (2중 링) ──
            collar_half = max(2, int(3.5 * s))
            for ci, ct in enumerate((0.0, -0.03)):
                cx_c = tip_x + int(handle_len * ct * hdir_x)
                cy_c = tip_y + int(handle_len * ct * hdir_y)
                c1 = (cx_c - int(collar_half * perp_hx), cy_c - int(collar_half * perp_hy))
                c2 = (cx_c + int(collar_half * perp_hx), cy_c + int(collar_half * perp_hy))
                col = iron_bright if ci == 0 else iron_light
                pygame.draw.line(screen, col, c1, c2, max(1, int(1.5 * s)))

            # ── 해머 헤드 (확대된 블록 + 경사면 + 타격면) ──
            head_half_w = int(8 * s)   # 좌우 폭 (확대)
            head_half_h = int(3 * s)   # 진행방향 두께 (확대)
            hcx = tip_x + int(1.5 * s * hdir_x)
            hcy = tip_y + int(1.5 * s * hdir_y)
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
            # 드롭 섀도우
            shadow_pts = [(p[0] + 2, p[1] + 2) for p in h_pts]
            pygame.draw.polygon(screen, (40, 35, 28), shadow_pts)
            # 본체
            pygame.draw.polygon(screen, iron, h_pts)
            # 테두리 (2중)
            pygame.draw.polygon(screen, iron_dark, h_pts, max(1, int(s)))

            # ── 해머 헤드 3D 면 표현 ──
            # 상면 하이라이트 (윗면 밝게)
            hl_pts = [h_pts[0], h_pts[1],
                      (h_pts[1][0] + int(0.8 * s * hdir_x),
                       h_pts[1][1] + int(0.8 * s * hdir_y)),
                      (h_pts[0][0] + int(0.8 * s * hdir_x),
                       h_pts[0][1] + int(0.8 * s * hdir_y))]
            pygame.draw.polygon(screen, iron_light, hl_pts)
            # 하면 그림자 (아랫면 어둡게)
            bot_pts = [h_pts[2], h_pts[3],
                       (h_pts[3][0] - int(0.8 * s * hdir_x),
                        h_pts[3][1] - int(0.8 * s * hdir_y)),
                       (h_pts[2][0] - int(0.8 * s * hdir_x),
                        h_pts[2][1] - int(0.8 * s * hdir_y))]
            pygame.draw.polygon(screen, iron_edge, bot_pts)

            # ── 양 끝 경사면 (bevel - 확대) ──
            bevel_d = int(2 * s)
            # 왼쪽 타격면
            lbevel = [
                h_pts[0], h_pts[3],
                (h_pts[3][0] + int(bevel_d * perp_hx),
                 h_pts[3][1] + int(bevel_d * perp_hy)),
                (h_pts[0][0] + int(bevel_d * perp_hx),
                 h_pts[0][1] + int(bevel_d * perp_hy)),
            ]
            pygame.draw.polygon(screen, iron_edge, lbevel)
            # 왼쪽 타격면 엣지 하이라이트
            pygame.draw.line(screen, iron_light, h_pts[0],
                             (h_pts[0][0] + int(bevel_d * perp_hx),
                              h_pts[0][1] + int(bevel_d * perp_hy)), 1)
            # 오른쪽 타격면
            rbevel = [
                h_pts[1], h_pts[2],
                (h_pts[2][0] - int(bevel_d * perp_hx),
                 h_pts[2][1] - int(bevel_d * perp_hy)),
                (h_pts[1][0] - int(bevel_d * perp_hx),
                 h_pts[1][1] - int(bevel_d * perp_hy)),
            ]
            pygame.draw.polygon(screen, iron_edge, rbevel)
            # 오른쪽 타격면 엣지 하이라이트
            pygame.draw.line(screen, iron_light, h_pts[1],
                             (h_pts[1][0] - int(bevel_d * perp_hx),
                              h_pts[1][1] - int(bevel_d * perp_hy)), 1)

            # ── 타격면 흔적 (사용감 표현) ──
            if s >= 2:
                for side in (-1, 1):
                    for di in range(3):
                        dent_t = 0.3 + di * 0.2
                        dent_x = hcx + int(side * (head_half_w + bevel_d * 0.5) * perp_hx) + \
                                 int((-head_half_h + head_half_h * 2 * dent_t) * hdir_x)
                        dent_y = hcy + int(side * (head_half_w + bevel_d * 0.5) * perp_hy) + \
                                 int((-head_half_h + head_half_h * 2 * dent_t) * hdir_y)
                        pygame.draw.circle(screen, iron_dark, (int(dent_x), int(dent_y)),
                                           max(1, int(0.5 * s)))

            # ── 룬 문양 (고대 북유럽 각인 - 다중 심볼) ──
            rune_pulse = 0.3 + 0.7 * pulse
            rune_active = (min(255, int(rune_glow[0] * rune_pulse)),
                           min(255, int(rune_glow[1] * rune_pulse)),
                           min(255, int(rune_glow[2] * rune_pulse)))
            rune_col = rune_active if intensity > 0.3 else rune_dim
            # 중앙 수직 룬 (페후 - 힘의 룬)
            r1 = (hcx - int(1.5 * s * perp_hx), hcy - int(1.5 * s * perp_hy))
            r2 = (hcx + int(1.5 * s * perp_hx), hcy + int(1.5 * s * perp_hy))
            pygame.draw.line(screen, rune_col, r1, r2, max(1, int(0.8 * s)))
            # 룬 가지 (양쪽 대각선)
            r_mid = ((r1[0] + r2[0]) // 2, (r1[1] + r2[1]) // 2)
            for br_sign in (1, -1):
                r_branch = (r_mid[0] + int(2 * s * hdir_x) + int(br_sign * 1.2 * s * perp_hx),
                            r_mid[1] + int(2 * s * hdir_y) + int(br_sign * 1.2 * s * perp_hy))
                pygame.draw.line(screen, rune_col, r_mid, r_branch, 1)
            # 좌우 보조 룬 (투리사즈 - 천둥의 룬)
            if s >= 2:
                for side_off in (-0.5, 0.5):
                    rx = hcx + int(side_off * head_half_w * perp_hx)
                    ry = hcy + int(side_off * head_half_w * perp_hy)
                    # 작은 삼각 룬
                    tr1 = (rx, ry - int(1 * s))
                    tr2 = (rx - int(0.8 * s), ry + int(0.5 * s))
                    tr3 = (rx + int(0.8 * s), ry + int(0.5 * s))
                    pygame.draw.line(screen, rune_col, tr1, tr2, 1)
                    pygame.draw.line(screen, rune_col, tr1, tr3, 1)
            # 룬 글로우 (충전 시 빛남)
            if intensity > 0.3 and s >= 1.5:
                rune_glow_r = max(2, int(3 * s * intensity))
                rune_surf = _get_cached_surface(rune_glow_r * 2 + 4, rune_glow_r * 2 + 4)
                pygame.draw.circle(rune_surf, (*rune_glow, min(40, int(25 * intensity * pulse))),
                                   (rune_glow_r + 2, rune_glow_r + 2), rune_glow_r)
                screen.blit(rune_surf, (hcx - rune_glow_r - 2, hcy - rune_glow_r - 2),
                            special_flags=pygame.BLEND_ADD)

            # ── 핸들 끝 장식 (폼멜 - 둥근 철구) ──
            pommel_r = max(2, int(2.5 * s))
            pommel_x = hx - int(2 * s * hdir_x)
            pommel_y = hy - int(2 * s * hdir_y)
            pygame.draw.circle(screen, iron_dark, (pommel_x, pommel_y), pommel_r + 1)
            pygame.draw.circle(screen, iron, (pommel_x, pommel_y), pommel_r)
            pygame.draw.circle(screen, iron_bright,
                               (pommel_x - int(0.5 * s), pommel_y - int(0.5 * s)),
                               max(1, pommel_r - int(1 * s)))

            # ── 대지 에너지 글로우 (다층 + 크랙 발광) ──
            if intensity > 0.1:
                # 다층 글로우 (내부 밝고 외부 어두운)
                for gi, (g_frac, g_alpha_base) in enumerate([
                    (1.0, 25), (0.65, 40), (0.35, 60)
                ]):
                    glow_r = int((head_half_w * 0.4 + intensity * 7) * s * g_frac)
                    if glow_r > 2:
                        g_pulse = pulse if gi == 0 else 1.0
                        glow_col = (min(255, int((140 + 100 * intensity) * g_pulse)),
                                    min(255, int((80 + 80 * intensity) * g_pulse)),
                                    min(255, int((20 + 50 * intensity) * g_pulse)))
                        glow_alpha = min(120, int(g_alpha_base * intensity))
                        glow_surf = _get_cached_surface(glow_r * 2 + 4, glow_r * 2 + 4)
                        pygame.draw.circle(glow_surf, (*glow_col, glow_alpha),
                                           (glow_r + 2, glow_r + 2), glow_r)
                        screen.blit(glow_surf, (hcx - glow_r - 2, hcy - glow_r - 2),
                                    special_flags=pygame.BLEND_ADD)
                # 대지 균열 에너지 라인 (헤드에서 방사)
                if intensity > 0.4 and s >= 2:
                    crack_count = int(3 + intensity * 4)
                    for ci in range(crack_count):
                        c_angle = (ci / crack_count) * math.pi * 2 + self.time * 0.5
                        c_len = int((4 + 6 * intensity) * s)
                        c_x1 = hcx + int(3 * s * math.cos(c_angle))
                        c_y1 = hcy + int(3 * s * math.sin(c_angle))
                        c_x2 = hcx + int(c_len * math.cos(c_angle))
                        c_y2 = hcy + int(c_len * math.sin(c_angle))
                        c_col = (min(255, int(200 + 55 * pulse)),
                                 min(255, int(130 + 50 * pulse)),
                                 min(255, int(30 + 30 * pulse)))
                        pygame.draw.line(screen, c_col, (c_x1, c_y1), (c_x2, c_y2), 1)
                # 대지 파티클 (돌 파편 + 불꽃 파편)
                for _ in range(int(intensity * 3)):
                    p_angle = random.uniform(0, math.pi * 2)
                    p_dist = random.uniform(2, head_half_w) * s
                    px = hcx + int(math.cos(p_angle) * p_dist)
                    py = hcy + int(math.sin(p_angle) * p_dist)
                    p_size = max(1, int(random.uniform(0.5, 2) * s))
                    p_col = random.choice([
                        (200, 160, 80), (180, 130, 50), (220, 170, 70),
                        (240, 180, 60), (160, 110, 40),
                    ])
                    pygame.draw.circle(screen, p_col, (px, py), p_size)

    def set_crowd_excitement(self, level):
        """관중 흥분도 설정 (0.0 ~ 1.0)"""
        self.crowd_noise_level = max(0.0, min(1.0, level))

    def draw(self, screen, scale_x=1.0, scale_y=1.0, offset_x=0, offset_y=0):
        """배경 그리기"""
        # 스케일 캐시 (매 프레임 transform.scale 방지)
        scale_key = (round(scale_x, 4), round(scale_y, 4))
        if not hasattr(self, '_scaled_cache'):
            self._scaled_cache = {}

        # 1. 바닥 (모래 + 비네트 + 바람무늬)
        if scale_x != 1.0 or scale_y != 1.0:
            cache_key = ('floor', scale_key)
            if cache_key not in self._scaled_cache:
                self._scaled_cache[cache_key] = pygame.transform.scale(
                    self.floor_surface,
                    (int(self.width * scale_x), int(self.height * scale_y))
                )
            screen.blit(self._scaled_cache[cache_key], (offset_x, offset_y))
        else:
            screen.blit(self.floor_surface, (offset_x, offset_y))

        # 2. 먼지 파티클 (바닥 위)
        for particle in self.dust_particles:
            px = int(particle['x'] * scale_x + offset_x)
            py = int(particle['y'] * scale_y + offset_y)
            size = max(1, int(particle['size'] * scale_x))
            color = (200, 175, 140)
            pygame.draw.circle(screen, color, (px, py), size)

        # 3. 금빛 먼지 (프리미엄 분위기) - 캐시된 서피스 사용
        for gd in self.golden_dust:
            gx = int(gd['x'] * scale_x + offset_x)
            gy = int(gd['y'] * scale_y + offset_y)
            gsize = max(1, int(gd['size'] * scale_x))
            pulse = 0.6 + 0.4 * math.sin(self.time * 1.5 + gd['phase'])
            galpha = int(gd['alpha'] * pulse)
            surf_sz = gsize * 2 + 2
            gd_surf = _get_cached_surface(surf_sz, surf_sz)
            pygame.draw.circle(gd_surf, (210, 180, 80, galpha),
                             (gsize + 1, gsize + 1), gsize)
            screen.blit(gd_surf, (gx - gsize - 1, gy - gsize - 1))

        # 3.5 열기류 파티클 (횃불 근처 아지랑이)
        for hs in self.heat_shimmers:
            if hs['life'] <= 0:
                continue
            life_ratio = hs['life'] / hs['max_life']
            hx = int((hs['base_x'] + hs['rx']) * scale_x + offset_x)
            hy = int((hs['base_y'] + hs['ry']) * scale_y + offset_y)
            h_alpha = int(18 * life_ratio * life_ratio)
            h_size = max(1, int(hs['size'] * scale_x * (0.5 + 0.5 * life_ratio)))
            if h_size >= 1 and h_alpha > 0:
                hs_sz = h_size * 2 + 2
                hs_surf = _get_cached_surface(hs_sz, hs_sz)
                pygame.draw.circle(hs_surf, (255, 220, 140, h_alpha),
                                   (h_size + 1, h_size + 1), h_size)
                screen.blit(hs_surf, (hx - h_size - 1, hy - h_size - 1),
                            special_flags=pygame.BLEND_ADD)

        # 4. 경기장 라인 (중앙선, 중앙원, 코너)
        arena = self.arena_surface
        if scale_x != 1.0 or scale_y != 1.0:
            cache_key = ('arena', scale_key)
            if cache_key not in self._scaled_cache:
                self._scaled_cache[cache_key] = pygame.transform.scale(
                    arena, (int(self.width * scale_x), int(self.height * scale_y))
                )
            screen.blit(self._scaled_cache[cache_key], (offset_x, offset_y))
        else:
            screen.blit(arena, (offset_x, offset_y))

        # 5. 장식 테두리 + 석상 (프리렌더)
        if scale_x != 1.0 or scale_y != 1.0:
            cache_key = ('border', scale_key)
            if cache_key not in self._scaled_cache:
                self._scaled_cache[cache_key] = pygame.transform.scale(
                    self.border_surface,
                    (int(self.width * scale_x), int(self.height * scale_y))
                )
            screen.blit(self._scaled_cache[cache_key], (offset_x, offset_y))
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

        # 글로우 서피스 캐시 (반경별)
        if not hasattr(self, '_zeus_glow_cache'):
            self._zeus_glow_cache = {}
        if glow_radius not in self._zeus_glow_cache:
            gs = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
            for r in range(glow_radius, 0, -2):
                alpha = int(30 * (r / glow_radius))
                if alpha > 0:
                    pygame.draw.circle(gs, (255, 210, 80, alpha),
                                     (glow_radius, glow_radius), r)
            self._zeus_glow_cache[glow_radius] = gs
        # intensity 변조: .copy() 제거 → 풀 Surface에 캐시 blit 후 mult
        cached_glow = self._zeus_glow_cache[glow_radius]
        if intensity < 0.95:
            glow_surf = _get_cached_surface(glow_radius * 2, glow_radius * 2)
            glow_surf.blit(cached_glow, (0, 0))
            alpha_s = _get_cached_surface(glow_radius * 2, glow_radius * 2)
            alpha_s.fill((255, 255, 255, int(255 * intensity)))
            glow_surf.blit(alpha_s, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
            screen.blit(glow_surf, (bx - glow_radius, by - glow_radius),
                       special_flags=pygame.BLEND_ADD)
        else:
            screen.blit(cached_glow, (bx - glow_radius, by - glow_radius),
                       special_flags=pygame.BLEND_ADD)

        # 스파크일 때 작은 빛줄기 추가
        if spark > 0.5:
            spark_len = int(6 * spark * scale_x)
            spark_alpha = int(100 * spark)
            spark_color = (255, 230, 120, spark_alpha)
            sz_s = spark_len * 2 + 2
            spark_surf = _get_cached_surface(sz_s, sz_s)
            sc = spark_len + 1
            pygame.draw.line(spark_surf, spark_color, (sc - spark_len, sc), (sc + spark_len, sc), 1)
            pygame.draw.line(spark_surf, spark_color, (sc, sc - spark_len), (sc, sc + spark_len), 1)
            screen.blit(spark_surf, (bx - sc, by - sc), special_flags=pygame.BLEND_ADD)

    def _draw_torches(self, screen, scale_x, scale_y, offset_x, offset_y):
        """횃불 그리기 (고퀄리티 - 다층 불꽃 + 엠버 + 금속 거치대)"""
        for torch in self.torches:
            tx = int(torch['x'] * scale_x + offset_x)
            ty = int(torch['y'] * scale_y + offset_y)
            intensity = torch['intensity']
            sway = torch['sway'] * scale_x
            flame_h = int(torch['flame_height'] * scale_y)
            sway_i = int(sway)

            # ── 1. 금속 거치대 (입체감 있는 브래킷) ──
            sx = lambda v: int(v * scale_x)
            sy = lambda v: int(v * scale_y)

            # 기둥 본체 (그라디언트 효과 - 3단 음영)
            dark_metal = (50, 40, 30)
            mid_metal = (75, 60, 45)
            light_metal = (100, 85, 65)
            # 그림자 면 (왼쪽)
            pygame.draw.rect(screen, dark_metal,
                             (tx - sx(4), ty + sy(1), sx(3), sy(20)))
            # 본체 면
            pygame.draw.rect(screen, mid_metal,
                             (tx - sx(1), ty + sy(1), sx(3), sy(20)))
            # 하이라이트 면 (오른쪽)
            pygame.draw.rect(screen, light_metal,
                             (tx + sx(2), ty + sy(1), sx(1), sy(20)))

            # 상단 화구 (불을 담는 그릇 모양)
            bowl_pts = [
                (tx - sx(7), ty + sy(2)),
                (tx - sx(5), ty - sy(3)),
                (tx + sx(5), ty - sy(3)),
                (tx + sx(7), ty + sy(2)),
                (tx + sx(4), ty + sy(4)),
                (tx - sx(4), ty + sy(4)),
            ]
            pygame.draw.polygon(screen, mid_metal, bowl_pts)
            # 화구 테두리 (금속 광택)
            pygame.draw.lines(screen, light_metal, False, [
                (tx - sx(7), ty + sy(2)),
                (tx - sx(5), ty - sy(3)),
                (tx + sx(5), ty - sy(3)),
                (tx + sx(7), ty + sy(2)),
            ], max(1, sx(1)))
            # 화구 안쪽 어두운 면
            pygame.draw.polygon(screen, dark_metal, [
                (tx - sx(4), ty + sy(1)),
                (tx - sx(3), ty - sy(1)),
                (tx + sx(3), ty - sy(1)),
                (tx + sx(4), ty + sy(1)),
            ])

            # 하단 리벳 장식 2개
            rivet_color = (120, 105, 80)
            pygame.draw.circle(screen, rivet_color,
                               (tx, ty + sy(7)), max(1, sx(2)))
            pygame.draw.circle(screen, rivet_color,
                               (tx, ty + sy(14)), max(1, sx(2)))
            # 리벳 하이라이트
            pygame.draw.circle(screen, (150, 135, 110),
                               (tx - sx(1), ty + sy(6)), max(1, sx(1)))
            pygame.draw.circle(screen, (150, 135, 110),
                               (tx - sx(1), ty + sy(13)), max(1, sx(1)))

            # ── 3. 메인 글로우 (불꽃 상단에만 은은한 발광) ──
            glow_radius = int(18 * intensity * scale_x)
            if glow_radius > 2:
                glow_key = glow_radius
                if glow_key not in self._torch_glow_cache:
                    gs = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
                    for r in range(glow_radius, 0, -2):
                        frac = r / glow_radius
                        a = int(15 * frac * frac)
                        rr = 255
                        gg = int(210 * frac + 140 * (1 - frac))
                        bb = int(80 * frac + 20 * (1 - frac))
                        pygame.draw.circle(gs, (rr, gg, bb, a),
                                           (glow_radius, glow_radius), r)
                    self._torch_glow_cache[glow_key] = gs
                screen.blit(self._torch_glow_cache[glow_key],
                            (tx + sway_i - glow_radius,
                             ty - flame_h - glow_radius),
                            special_flags=pygame.BLEND_ADD)

            # ── 4. 외부 불꽃 (가장 바깥 - 따뜻한 앰버) ──
            outer_dark = (210, int(130 * intensity), 25)
            od_pts = [
                (tx - sx(1) + sway_i // 2, ty - sy(1)),
                (tx - sx(9) + sway_i // 3, ty - flame_h * 0.35),
                (tx - sx(6) + sway_i // 2, ty - flame_h * 0.6),
                (tx - sx(3) + sway_i, ty - flame_h * 0.85),
                (tx + sway_i, ty - flame_h - sy(3)),
                (tx + sx(3) + sway_i, ty - flame_h * 0.85),
                (tx + sx(6) + sway_i // 2, ty - flame_h * 0.6),
                (tx + sx(9) + sway_i // 3, ty - flame_h * 0.35),
                (tx + sx(1) + sway_i // 2, ty - sy(1)),
            ]
            pygame.draw.polygon(screen, outer_dark, od_pts)

            # ── 5. 중간 불꽃 (따뜻한 오렌지) ──
            mid_color = (255, int(185 * intensity), 45)
            mid_pts = [
                (tx + sway_i // 2, ty - sy(2)),
                (tx - sx(7) + sway_i // 2, ty - flame_h * 0.4),
                (tx - sx(3) + sway_i, ty - flame_h * 0.65),
                (tx - sx(1) + sway_i, ty - flame_h * 0.85),
                (tx + sway_i, ty - flame_h),
                (tx + sx(1) + sway_i, ty - flame_h * 0.85),
                (tx + sx(3) + sway_i, ty - flame_h * 0.65),
                (tx + sx(7) + sway_i // 2, ty - flame_h * 0.4),
                (tx + sway_i // 2, ty - sy(2)),
            ]
            pygame.draw.polygon(screen, mid_color, mid_pts)

            # ── 6. 내부 불꽃 (밝은 골든 옐로) ──
            inner_color = (255, int(240 * intensity), int(120 * intensity))
            inner_h = flame_h * 0.65
            in_pts = [
                (tx + sway_i // 2, ty - sy(4)),
                (tx - sx(4) + sway_i, ty - inner_h * 0.45),
                (tx - sx(1) + sway_i, ty - inner_h * 0.8),
                (tx + sway_i, ty - int(inner_h)),
                (tx + sx(1) + sway_i, ty - inner_h * 0.8),
                (tx + sx(4) + sway_i, ty - inner_h * 0.45),
                (tx + sway_i // 2, ty - sy(4)),
            ]
            pygame.draw.polygon(screen, inner_color, in_pts)

            # ── 7. 코어 불꽃 (크림 화이트 - 가장 뜨거운 중심부) ──
            core_color = (255, 255, int(200 * intensity + 50))
            core_h = flame_h * 0.35
            core_pts = [
                (tx + sway_i, ty - sy(5)),
                (tx - sx(2) + sway_i, ty - core_h * 0.5),
                (tx + sway_i, ty - int(core_h)),
                (tx + sx(2) + sway_i, ty - core_h * 0.5),
            ]
            pygame.draw.polygon(screen, core_color, core_pts)

            # ── 8. 엠버(불씨) 파티클 ──
            for ember in torch['embers']:
                if ember['life'] <= 0:
                    continue
                life_ratio = ember['life'] / ember['max_life']
                ex = tx + int(ember['rx'] * scale_x) + sway_i
                ey = ty + int(ember['ry'] * scale_y)
                e_alpha = min(255, int(220 * life_ratio))
                e_size = max(1, int(ember['size'] * scale_x * life_ratio))
                # 불씨 색상: 밝은 노랑 → 앰버 → 어두운 오렌지로 은은하게 페이드
                if life_ratio > 0.6:
                    e_col = (255, int(230 * life_ratio), int(90 * life_ratio))
                elif life_ratio > 0.3:
                    e_col = (240, int(170 * life_ratio), int(40 * life_ratio))
                else:
                    e_col = (200, int(120 * life_ratio), 20)
                if e_size >= 2:
                    es = pygame.Surface((e_size * 2, e_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(es, (*e_col, e_alpha),
                                       (e_size, e_size), e_size)
                    screen.blit(es, (ex - e_size, ey - e_size),
                                special_flags=pygame.BLEND_ADD)
                else:
                    try:
                        screen.set_at((ex, ey), e_col)
                    except (IndexError, TypeError):
                        pass

            # ── 9. 불꽃 끝단 하이라이트 (팁 글로우) ──
            tip_y = ty - flame_h + sway_i
            tip_r = max(2, int(4 * intensity * scale_x))
            tip_surf = pygame.Surface((tip_r * 2, tip_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(tip_surf, (255, 255, 200, int(60 * intensity)),
                               (tip_r, tip_r), tip_r)
            screen.blit(tip_surf,
                        (tx + sway_i - tip_r, tip_y - tip_r),
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
        """전경 효과 (패들/공 위에 그려짐) - 알파 비네트 (프리렌더 캐시)"""
        vignette_size = 50
        sw = int(self.width * scale_x)

        # 프리렌더 캐시 (최초 1회만 생성)
        cache_key = f"_fg_vignette_{sw}"
        if not hasattr(self, cache_key):
            v_top = pygame.Surface((sw, vignette_size), pygame.SRCALPHA)
            for i in range(vignette_size):
                alpha = int(35 * (1 - i / vignette_size))
                pygame.draw.line(v_top, (20, 15, 10, alpha), (0, i), (sw, i))
            v_bot = pygame.Surface((sw, vignette_size), pygame.SRCALPHA)
            for i in range(vignette_size):
                alpha = int(35 * (i / vignette_size))
                pygame.draw.line(v_bot, (20, 15, 10, alpha), (0, i), (sw, i))
            setattr(self, cache_key, (v_top, v_bot))

        v_top, v_bot = getattr(self, cache_key)
        screen.blit(v_top, (offset_x, offset_y + int(50 * scale_y)))
        screen.blit(v_bot, (offset_x, offset_y + int((self.height - 50) * scale_y) - vignette_size))
