# -*- coding: utf-8 -*-
"""
Stage 5: 중국 전통시장 + 화염 테마 맵
Stage 2의 테두리 구조를 유지하면서 중국 전통시장 느낌으로 변경
"""

import pygame
import math
import random
from typing import Tuple, List

# 화면 크기 - config에서 가져오기
try:
    from config.constants import SCREEN_WIDTH, SCREEN_HEIGHT, PILLAR_UI_WIDTH, GAME_PLAY_WIDTH
    WIDTH = SCREEN_WIDTH  # 760px
    HEIGHT = SCREEN_HEIGHT  # 750px
    PILLAR_OFFSET = PILLAR_UI_WIDTH  # 80px
    GAME_WIDTH = GAME_PLAY_WIDTH  # 600px
except ImportError:
    WIDTH = 760
    HEIGHT = 750
    PILLAR_OFFSET = 80
    GAME_WIDTH = 600

# 색상 정의 - 중국 전통 색상 팔레트
CHINA_RED = (220, 38, 38)          # 중국 붉은색
GOLD = (255, 215, 0)                # 금색
DARK_RED = (139, 0, 0)             # 진한 붉은색
ORANGE = (255, 140, 0)              # 주황색 (화염)
YELLOW = (255, 255, 0)              # 노란색 (화염)
BLACK = (20, 20, 20)                # 검은색
WHITE = (255, 255, 255)             # 흰색
FIRE_GRADIENT = [(255, 0, 0), (255, 100, 0), (255, 200, 0), (255, 255, 100)]

class Stage5ChineseMarket:
    def __init__(self, width: int = None, height: int = None):
        self.width = width if width is not None else WIDTH
        self.height = height if height is not None else HEIGHT
        self.time = 0
        self.fire_particles = []  # 이제 충돌 시에만 생성됨
        self.lanterns = []
        self.init_decorations()

        # 프로시저럴 바닥 캐시 생성
        self._floor_cache = pygame.Surface((self.width, self.height))
        self._generate_floor(self.width, self.height)
        
        # 불타는 스타디움 라인 애니메이션
        self.fire_line_particles = []  # 불꽃 파티클들
        self.fire_glow_phase = 0  # 불꽃 빛나는 애니메이션 위상
        self.fire_colors = [
            (255, 100, 50),   # 밝은 주황
            (255, 80, 30),    # 진한 주황
            (200, 60, 20),    # 붉은 주황
            (150, 40, 10),    # 어두운 빨강
        ]
        
        # 불꽃탄 충돌 애니메이션
        self.impact_fire_zones = []  # 충돌 지점의 불꽃 애니메이션들
        
        # 홍련꽃 홀로그램 애니메이션 (단일 패턴)
        self.lotus_fade_phase = 0  # 맥동 효과 위상
        self.spiral_burst_timer = 0  # 화염탄 발사시 나선 회전 효과
        self.spiral_burst_max_timer = 1300  # 타이머 최대값 (기본 1.3초)
        self.spiral_burst_intensity = 0  # 나선 회전 강도 (0~1)
        self.is_inferno_mode = False  # 홍련폭염 모드 상태
        
        # 제3의 눈 애니메이션 관련
        self.third_eye_opening = 0  # 제3의 눈 열림 정도 (0~1)
        self.third_eye_glow = 0  # 제3의 눈 빛나기 강도
        self.spiritual_rings = []  # 영적 고리들
        
    def init_decorations(self):
        """중국 등롱 위치 초기화"""
        # 등롱 제거 - 빈 리스트로 초기화
        pass
    
    def update(self, dt):
        """애니메이션 업데이트"""
        self.time += dt
        self.fire_glow_phase += 0.05  # 불꽃 맥동 애니메이션
        
        # 홀로그램 맥동 효과 업데이트 - 화염탄 발사시 속도 변화
        if self.spiral_burst_timer > 0 and hasattr(self, 'spiral_burst_max_timer'):
            # 화염탄 발사 중: ease-in-out 속도 변화
            progress = 1.0 - (self.spiral_burst_timer / self.spiral_burst_max_timer)  # 0에서 1로 증가
            # easing 함수를 통한 속도 변조
            speed_multiplier = self._get_rotation_speed_multiplier(progress)
            self.lotus_fade_phase += 0.02 * speed_multiplier  # 속도 변화 적용 (0.05 -> 0.02로 감소)
        else:
            # 평소: 일정한 속도 (천천히)
            self.lotus_fade_phase += 0.02  # 0.05 -> 0.02로 감소 (60% 느리게)
        
        # 나선 폭발 효과 업데이트 (부드러운 감소)
        if self.spiral_burst_timer > 0:
            self.spiral_burst_timer = max(0, self.spiral_burst_timer - dt)  # 음수 방지
            # 부드러운 감속 (easing out)
            if self.spiral_burst_timer > 0 and hasattr(self, 'spiral_burst_max_timer'):
                # 최대 타이머 값으로 정규화 (0~1 범위)
                self.spiral_burst_intensity = (self.spiral_burst_timer / self.spiral_burst_max_timer) ** 0.5  # 제곱근으로 부드럽게
                
                # 홍련폭염 모드에서 제3의 눈 애니메이션 업데이트
                if self.is_inferno_mode and self.spiral_burst_max_timer == 4000:
                    progress = 1.0 - (self.spiral_burst_timer / self.spiral_burst_max_timer)
                    
                    # 0~2초: 제3의 눈이 천천히 열림
                    if progress < 0.5:
                        self.third_eye_opening = progress * 2  # 0~1로 증가
                        self.third_eye_glow = progress * 2 * 0.5  # 빛나기도 증가
                    else:
                        # 2초 이후: 완전히 열린 상태 유지
                        self.third_eye_opening = 1.0
                        self.third_eye_glow = 0.5 + 0.5 * math.sin(progress * 10)  # 맥동 효과
                        
                    # 영적 고리 생성 (2초 이후)
                    if progress >= 0.5 and random.random() < 0.1:
                        self.spiritual_rings.append({
                            'radius': 30,
                            'alpha': 255,
                            'expanding': True
                        })
                    
                    # 영적 고리 업데이트
                    for ring in self.spiritual_rings[:]:
                        ring['radius'] += 2
                        ring['alpha'] -= 5
                        if ring['alpha'] <= 0:
                            self.spiritual_rings.remove(ring)
            else:
                self.spiral_burst_intensity = 0
        else:
            self.spiral_burst_timer = 0  # 확실히 0으로 설정
            self.spiral_burst_intensity = 0
            self.third_eye_opening = 0
            self.third_eye_glow = 0
            self.spiritual_rings = []
        
        # 등롱 흔들림 업데이트
        for lantern in self.lanterns:
            lantern['swing'] += lantern['speed']
        
        # 충돌 지점 불꽃 애니메이션 업데이트
        for zone in self.impact_fire_zones[:]:
            zone['duration'] -= dt
            
            # 이 지점에서 불꽃 파티클 생성 (바닥에서 시작)
            if zone['duration'] > 0 and random.random() < 0.5:
                for _ in range(2):  # 여러 개의 파티클 생성
                    self.fire_particles.append({
                        'x': zone['x'] + random.randint(-30, 30),
                        'y': zone['y'],  # 이미 HEIGHT - 10으로 설정됨
                        'vy': -random.uniform(2, 5),  # 위로 올라가는 속도 증가
                        'vx': random.uniform(-1, 1),
                        'life': 60,
                        'size': random.randint(3, 8)
                    })
            
            # 지속시간이 끝난 zone 제거
            if zone['duration'] <= 0:
                self.impact_fire_zones.remove(zone)
        
        # 화염 파티클 업데이트
        self.fire_particles = [
            {**p, 'y': p['y'] + p['vy'], 'x': p['x'] + p['vx'], 'life': p['life'] - 1}
            for p in self.fire_particles if p['life'] > 0
        ]
        
        # 불타는 스타디움 라인 파티클 업데이트
        self._update_fire_lines()
    
    def draw_border(self, screen):
        """Stage 2와 동일한 두께의 중국 전통 테두리"""
        border_thickness = 10  # Stage 2와 동일
        # SCREEN Surface 전체를 감싸는 테두리 (SCREEN은 이미 게임 전체 영역)
        x_offset = 0
        game_w = self.width
        game_h = self.height

        # 기본 테두리 - 진한 붉은색 (게임 영역에만)
        pygame.draw.rect(screen, DARK_RED, (x_offset, 0, game_w, border_thickness))
        pygame.draw.rect(screen, DARK_RED, (x_offset, game_h - border_thickness, game_w, border_thickness))
        pygame.draw.rect(screen, DARK_RED, (x_offset, 0, border_thickness, game_h))
        pygame.draw.rect(screen, DARK_RED, (x_offset + game_w - border_thickness, 0, border_thickness, game_h))

        # 내부 금색 테두리
        inner_thickness = 2
        pygame.draw.rect(screen, GOLD,
                        (x_offset + border_thickness - inner_thickness, border_thickness - inner_thickness,
                         game_w - 2*(border_thickness - inner_thickness), inner_thickness))
        pygame.draw.rect(screen, GOLD,
                        (x_offset + border_thickness - inner_thickness, game_h - border_thickness,
                         game_w - 2*(border_thickness - inner_thickness), inner_thickness))
        pygame.draw.rect(screen, GOLD,
                        (x_offset + border_thickness - inner_thickness, border_thickness - inner_thickness,
                         inner_thickness, game_h - 2*(border_thickness - inner_thickness)))
        pygame.draw.rect(screen, GOLD,
                        (x_offset + game_w - border_thickness, border_thickness - inner_thickness,
                         inner_thickness, game_h - 2*(border_thickness - inner_thickness)))

        # 중국 전통 문양 (간단한 기하학 패턴)
        pattern_size = 20
        for i in range(0, game_w, pattern_size * 2):
            # 상단 문양
            self.draw_chinese_pattern(screen, x_offset + i + pattern_size//2, border_thickness//2, 4, GOLD)
            # 하단 문양
            self.draw_chinese_pattern(screen, x_offset + i + pattern_size//2, game_h - border_thickness//2, 4, GOLD)

        for i in range(0, game_h, pattern_size * 2):
            # 좌측 문양
            self.draw_chinese_pattern(screen, x_offset + border_thickness//2, i + pattern_size//2, 4, GOLD)
            # 우측 문양
            self.draw_chinese_pattern(screen, x_offset + game_w - border_thickness//2, i + pattern_size//2, 4, GOLD)

        # 코너 장식 (중국 동전 모양)
        corner_radius = 6
        # 좌상단
        self.draw_chinese_coin(screen, x_offset + border_thickness//2, border_thickness//2, corner_radius, GOLD)
        # 우상단
        self.draw_chinese_coin(screen, x_offset + game_w - border_thickness//2, border_thickness//2, corner_radius, GOLD)
        # 좌하단
        self.draw_chinese_coin(screen, x_offset + border_thickness//2, game_h - border_thickness//2, corner_radius, GOLD)
        # 우하단
        self.draw_chinese_coin(screen, x_offset + game_w - border_thickness//2, game_h - border_thickness//2, corner_radius, GOLD)
    
    def draw_chinese_pattern(self, screen, x, y, size, color):
        """간단한 중국 전통 문양"""
        # 십자 패턴
        pygame.draw.line(screen, color, (x - size, y), (x + size, y), 1)
        pygame.draw.line(screen, color, (x, y - size), (x, y + size), 1)
        # 대각선 장식
        half_size = size // 2
        pygame.draw.line(screen, color, (x - half_size, y - half_size), (x - half_size//2, y - half_size//2), 1)
        pygame.draw.line(screen, color, (x + half_size, y - half_size), (x + half_size//2, y - half_size//2), 1)
        pygame.draw.line(screen, color, (x - half_size, y + half_size), (x - half_size//2, y + half_size//2), 1)
        pygame.draw.line(screen, color, (x + half_size, y + half_size), (x + half_size//2, y + half_size//2), 1)
    
    def draw_chinese_coin(self, screen, x, y, radius, color):
        """중국 동전 모양 장식"""
        # 외부 원
        pygame.draw.circle(screen, color, (x, y), radius, 2)
        # 내부 사각형 (동전 구멍)
        square_size = radius // 2
        pygame.draw.rect(screen, color, 
                        (x - square_size//2, y - square_size//2, square_size, square_size), 1)
    
    def _ease_in_out_cubic(self, t):
        """Cubic ease-in-out 함수 - 부드러운 가속과 감속"""
        if t < 0.5:
            return 4 * t * t * t
        else:
            p = 2 * t - 2
            return 1 + p * p * p / 2
    
    def _get_rotation_speed_multiplier(self, progress):
        """회전 속도 배수 계산"""
        if self.is_inferno_mode and self.spiral_burst_max_timer == 4000:
            # 홍련폭염 모드 - 4초 애니메이션
            # 0~2초: 천천히 가속 (0~0.5)
            # 2~3초: 매우 빠름 (0.5~0.75)  
            # 3~4초: 매우 빠름 유지 (0.75~1.0)
            
            if progress < 0.5:  # 처음 2초 (천천히 가속)
                # 0.2배속에서 시작하여 6배속까지 가속
                normalized = progress / 0.5
                # 지수 함수로 가속도 증가
                return 0.2 + 5.8 * (normalized * normalized * normalized)
            else:  # 2초 이후 (매우 빠름)
                # 6배속 유지
                return 6.0
        else:
            # 일반 화염탄 모드 - 1.3초 기준
            if progress < 0.154:  # 처음 0.2초 (느림)
                normalized = progress / 0.154
                return 0.3 + 0.7 * (normalized * normalized)
            elif progress < 0.538:  # 중간 0.5초 (빠름)
                return 3.0
            else:  # 마지막 0.6초 (느림)
                normalized = (progress - 0.538) / (1.0 - 0.538)
                return 3.0 - 2.7 * (normalized * normalized)
    
    def draw_stadium_line_background(self, screen):
        """중앙 스타디움 라인 - 배경 부분만 (공 아래에 그려짐)"""
        center_y = HEIGHT // 2
        # 게임 영역 중앙 (필러 오프셋 적용)
        center_x = PILLAR_OFFSET + GAME_WIDTH // 2
        game_left = PILLAR_OFFSET
        game_right = PILLAR_OFFSET + GAME_WIDTH

        # 메인 중앙선 (점선) - 원 밖에서만 그리기
        dash_length = 20
        gap_length = 15

        # 왼쪽 선 (원 밖)
        for x in range(game_left, center_x - 120, dash_length + gap_length):
            end_x = min(x + dash_length, center_x - 120)
            pygame.draw.line(screen, WHITE, (x, center_y), (end_x, center_y), 3)

        # 오른쪽 선 (원 밖)
        for x in range(center_x + 120, game_right, dash_length + gap_length):
            end_x = min(x + dash_length, game_right)
            pygame.draw.line(screen, WHITE, (x, center_y), (end_x, center_y), 3)

        # 중앙 점
        pygame.draw.circle(screen, CHINA_RED, (center_x, center_y), 8)
        pygame.draw.circle(screen, GOLD, (center_x, center_y), 5)

    def draw_stadium_line(self, screen):
        """중앙 스타디움 라인 - 전체 (호환성 유지)"""
        center_y = HEIGHT // 2
        # 게임 영역 중앙 (필러 오프셋 적용)
        center_x = PILLAR_OFFSET + GAME_WIDTH // 2

        # 불타는 애니메이션 효과 그리기
        self._draw_fire_lines(screen, center_x, center_y)

        # 중앙 점
        pygame.draw.circle(screen, CHINA_RED, (center_x, center_y), 8)
        pygame.draw.circle(screen, GOLD, (center_x, center_y), 5)
    
    def draw_stadium_line_foreground(self, screen):
        """중앙 스타디움 라인 - 전경 부분만 (공 위에 그려짐) - 현재 비활성화"""
        # Stage 5에서는 중앙 원을 공 위에 그리지 않음
        pass
    
    def draw_lanterns(self, screen):
        """중국 등롱 그리기"""
        for lantern in self.lanterns:
            # 흔들림 계산
            swing_offset = math.sin(lantern['swing']) * 5
            x = lantern['x'] + swing_offset
            y = lantern['y']
            
            # 줄
            pygame.draw.line(screen, BLACK, (lantern['x'], y - 20), (x, y), 1)
            
            # 등롱 본체
            lantern_color = CHINA_RED if random.random() > 0.1 else ORANGE
            pygame.draw.ellipse(screen, lantern_color, (x - 15, y - 10, 30, 35))
            pygame.draw.ellipse(screen, GOLD, (x - 15, y - 10, 30, 35), 2)
            
            # 등롱 장식
            pygame.draw.line(screen, GOLD, (x - 10, y + 5), (x + 10, y + 5), 1)
            pygame.draw.line(screen, GOLD, (x - 10, y + 15), (x + 10, y + 15), 1)
            
            # 술 장식
            for i in range(-2, 3):
                tassel_x = x + i * 3
                tassel_y = y + 25
                pygame.draw.line(screen, GOLD, (x, y + 25), (tassel_x, tassel_y + 8), 1)
    
    def draw_fire_effects(self, screen):
        """화염 효과"""
        for particle in self.fire_particles:
            alpha = particle['life'] / 100
            color_index = min(3, int((1 - alpha) * 4))
            color = FIRE_GRADIENT[color_index]
            
            # 화염 파티클
            size = int(particle['size'] * alpha)
            if size > 0:
                pygame.draw.circle(screen, color, (int(particle['x']), int(particle['y'])), size)
                
                # 광휘 효과
                if size > 3:
                    glow_surface = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surface, (*color, int(50 * alpha)), 
                                     (size * 2, size * 2), size * 2)
                    screen.blit(glow_surface, 
                              (particle['x'] - size * 2, particle['y'] - size * 2))
    
    # ================================================================
    # 프로시저럴 중국 전통 석재 바닥 생성 (12레이어)
    # ================================================================
    def _generate_floor(self, W, H):
        """고퀄리티 중국 전통 사원 석재 바닥 텍스처 생성"""
        _sin = math.sin
        cx, cy = W // 2, H // 2

        # 색상 팔레트 (중국 사원 붉은 석재)
        stone = (42, 18, 14)          # 기본 어두운 적갈색
        stone_light = (60, 28, 22)    # 밝은 적갈색
        stone_warm = (55, 22, 15)     # 따뜻한 톤
        grout = (25, 10, 8)           # 줄눈 (어두운)
        grout_light = (32, 14, 11)    # 줄눈 밝은

        clamp = lambda v: max(0, min(255, int(v)))

        def noise(x, y, seed=0):
            """연속적인 유사 노이즈"""
            v = 0.0
            v += 0.35 * _sin(x * 0.081 + y * 0.057 + seed * 1.7)
            v += 0.25 * _sin(x * 0.137 - y * 0.098 + seed * 3.1)
            v += 0.20 * _sin(x * 0.203 + y * 0.173 + seed * 5.3)
            v += 0.12 * _sin(x * 0.311 - y * 0.261 + seed * 7.9)
            v += 0.08 * _sin(x * 0.419 + y * 0.347 + seed * 11.3)
            return max(-1.0, min(1.0, v))

        floor = self._floor_cache

        # ═══════════════════════════════════════════════════════════
        # 1. 베이스 석재 + 2px 연속 노이즈
        # ═══════════════════════════════════════════════════════════
        floor.fill(stone)
        noise_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        step = 2
        for gy in range(0, H, step):
            for gx in range(0, W, step):
                n = noise(gx, gy, 0)
                bright = n * 12
                warm = noise(gx, gy, 2.5) * 8
                sat = noise(gx, gy, 5.0) * 5
                r = clamp(stone[0] + bright + warm * 0.6)
                g = clamp(stone[1] + bright * 0.5 + warm * 0.2 + sat * 0.15)
                b = clamp(stone[2] + bright * 0.3 - warm * 0.1 + sat * 0.3)
                pygame.draw.rect(noise_surf, (r, g, b, 90), (gx, gy, step, step))
        floor.blit(noise_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 2. 방사형 그라데이션 (중앙 은은한 붉은 빛)
        # ═══════════════════════════════════════════════════════════
        grad_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        vig_max = int(max(W, H) * 0.75)
        for ring in range(35):
            frac = ring / 35
            radius = int(vig_max * (1.0 - frac * 0.7))
            pygame.draw.circle(grad_surf, (80, 25, 15, int(3 * (1.0 - frac))),
                               (cx, cy), radius)
        floor.blit(grad_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 3. 석재 타일 그리드 (중국식 정사각 타일 + 줄눈)
        # ═══════════════════════════════════════════════════════════
        tile_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(7777)  # 결정론적
        tile_data = []
        tile_size_base = 52
        grout_w = 3
        y_pos = 0
        row = 0
        while y_pos < H + tile_size_base:
            x_pos = (row % 2) * (tile_size_base // 2) - tile_size_base // 4
            while x_pos < W + tile_size_base:
                tw = tile_size_base + random.randint(-4, 4)
                th = tile_size_base + random.randint(-4, 4)
                tile_data.append((x_pos, y_pos, tw, th))

                # 줄눈 (수평 + 수직)
                jitter = random.randint(-1, 1)
                pygame.draw.rect(tile_surf, (*grout, 120),
                                 (x_pos + jitter, y_pos, tw, grout_w))
                pygame.draw.rect(tile_surf, (*grout, 120),
                                 (x_pos, y_pos + jitter, grout_w, th))
                # 줄눈 밝은 쪽 (깊이감)
                pygame.draw.rect(tile_surf, (*grout_light, 50),
                                 (x_pos + jitter + 1, y_pos + 1, tw - 1, 1))
                pygame.draw.rect(tile_surf, (*grout_light, 50),
                                 (x_pos + 1, y_pos + jitter + 1, 1, th - 1))
                x_pos += tw + grout_w
            y_pos += tile_size_base + grout_w
            row += 1
        random.seed()
        floor.blit(tile_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 4. 타일별 색상 변화 (각 타일마다 미세한 붉은 색조 차이)
        # ═══════════════════════════════════════════════════════════
        tilecolor_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(8888)
        for tx, ty, tw, th in tile_data:
            r_shift = random.randint(-8, 12)
            g_shift = random.randint(-4, 5)
            b_shift = random.randint(-3, 4)
            tc = (clamp(stone[0] + r_shift),
                  clamp(stone[1] + g_shift),
                  clamp(stone[2] + b_shift))
            ta = random.randint(18, 42)
            pygame.draw.rect(tilecolor_surf, (*tc, ta),
                             (tx + grout_w, ty + grout_w, tw - grout_w, th - grout_w))
        random.seed()
        floor.blit(tilecolor_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 5. 대규모 색상 패치 (화염 그을음, 습기, 풍화 영역)
        # ═══════════════════════════════════════════════════════════
        patch_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(9999)
        patch_colors = [
            (22, 8, 5, 25),      # 그을음 (어두운)
            (65, 20, 10, 20),     # 화염 자국 (붉은)
            (50, 35, 20, 15),     # 풍화 (갈색)
            (30, 15, 25, 12),     # 오래된 자국 (자줏빛)
            (70, 30, 15, 18),     # 따뜻한 반점 (주황)
        ]
        for _ in range(18):
            pc = random.choice(patch_colors)
            px = random.randint(0, W)
            py = random.randint(0, H)
            mr = random.randint(40, 120)
            for r in range(mr, 0, -3):
                frac = 1.0 - r / mr
                pygame.draw.circle(patch_surf,
                                   (pc[0], pc[1], pc[2], int(pc[3] * frac * frac)),
                                   (px, py), r)
        random.seed()
        floor.blit(patch_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 6. 석재 알갱이 텍스처 (화강암/적사암 입자)
        # ═══════════════════════════════════════════════════════════
        grain_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(1111)
        # 6a. 어두운 입자 (구멍)
        for _ in range(W * H // 20):
            gx = random.randint(0, W - 1)
            gy = random.randint(0, H - 1)
            grain_surf.set_at((gx, gy), (18, 8, 5, random.randint(25, 65)))
        # 6b. 밝은 입자 (결정/반사)
        for _ in range(W * H // 30):
            gx = random.randint(0, W - 1)
            gy = random.randint(0, H - 1)
            grain_surf.set_at((gx, gy), (75, 35, 25, random.randint(20, 50)))
        # 6c. 붉은 입자 (적사암 결)
        for _ in range(W * H // 40):
            gx = random.randint(0, W - 1)
            gy = random.randint(0, H - 1)
            grain_surf.set_at((gx, gy), (90, 25, 12, random.randint(30, 60)))
        random.seed()
        floor.blit(grain_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 7. 중국 문양 임프린트 (은은한 회문/뇌문 패턴)
        # ═══════════════════════════════════════════════════════════
        motif_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(3333)
        motif_color = (55, 22, 16, 18)  # 매우 은은하게
        # 격자형 회문 패턴 (줄눈 교차점에)
        for tx, ty, tw, th in tile_data:
            if random.random() < 0.12:
                mcx = tx + tw // 2
                mcy = ty + th // 2
                ms = min(tw, th) // 3
                # 중국 전통 회문 (사각 나선)
                for ring in range(3):
                    off = ring * 4
                    rect = (mcx - ms + off, mcy - ms + off,
                            (ms - off) * 2, (ms - off) * 2)
                    if rect[2] > 4 and rect[3] > 4:
                        pygame.draw.rect(motif_surf, motif_color, rect, 1)
            # 가끔 작은 십자 무늬
            if random.random() < 0.08:
                mcx = tx + tw // 2
                mcy = ty + th // 2
                cs = min(tw, th) // 5
                pygame.draw.line(motif_surf, motif_color,
                                 (mcx - cs, mcy), (mcx + cs, mcy), 1)
                pygame.draw.line(motif_surf, motif_color,
                                 (mcx, mcy - cs), (mcx, mcy + cs), 1)
        random.seed()
        floor.blit(motif_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 8. 풍화 균열
        # ═══════════════════════════════════════════════════════════
        crack_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(4444)
        cr_dark = (20, 8, 5)
        for _ in range(25):
            sx = random.randint(0, W)
            sy = random.randint(0, H)
            angle = random.uniform(0, 6.283)
            seg_count = random.randint(4, 12)
            pts = [(sx, sy)]
            for _ in range(seg_count):
                angle += random.uniform(-0.8, 0.8)
                seg_len = random.uniform(5, 18)
                nx = pts[-1][0] + math.cos(angle) * seg_len
                ny = pts[-1][1] + _sin(angle) * seg_len
                pts.append((int(nx), int(ny)))
            if len(pts) >= 2:
                pygame.draw.lines(crack_surf, (*cr_dark, random.randint(30, 65)),
                                  False, pts, 1)
                # 분기 균열
                if len(pts) > 3 and random.random() < 0.5:
                    bi = random.randint(1, len(pts) - 2)
                    bp = pts[bi]
                    ba = angle + random.uniform(-1.2, 1.2)
                    b_pts = [bp]
                    for _ in range(random.randint(2, 5)):
                        ba += random.uniform(-0.5, 0.5)
                        bl = random.uniform(4, 12)
                        b_pts.append((int(b_pts[-1][0] + math.cos(ba) * bl),
                                      int(b_pts[-1][1] + _sin(ba) * bl)))
                    pygame.draw.lines(crack_surf, (*cr_dark, random.randint(20, 45)),
                                      False, b_pts, 1)
        random.seed()
        floor.blit(crack_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 9. 미세 그림자 노이즈 (깊이감)
        # ═══════════════════════════════════════════════════════════
        shadow_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(5555)
        # 어두운 점 (미세 구멍)
        for _ in range(200):
            sx = random.randint(0, W - 1)
            sy = random.randint(0, H - 1)
            sr = random.randint(1, 3)
            sa = random.randint(15, 40)
            pygame.draw.circle(shadow_surf, (12, 5, 3, sa), (sx, sy), sr)
        # 밝은 점 (반사 입자)
        for _ in range(120):
            sx = random.randint(0, W - 1)
            sy = random.randint(0, H - 1)
            sr = random.randint(1, 2)
            sa = random.randint(10, 30)
            pygame.draw.circle(shadow_surf, (stone_light[0] + 8, stone_light[1] + 5,
                                             stone_light[2] + 3, sa), (sx, sy), sr)
        random.seed()
        floor.blit(shadow_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 10. 닳은 바닥 (전투 마모 + 중앙 화염 자국)
        # ═══════════════════════════════════════════════════════════
        wear_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        # 중앙 마모 (밝게)
        for r in range(70, 0, -2):
            frac = 1.0 - r / 70
            pygame.draw.circle(wear_surf, (65, 28, 18, int(6 * frac)),
                               (cx, cy), r)
        # 화염 자국 반점들
        random.seed(6666)
        for _ in range(10):
            fx = random.randint(PILLAR_OFFSET + 30, PILLAR_OFFSET + GAME_WIDTH - 30)
            fy = random.randint(50, H - 50)
            fr = random.randint(15, 35)
            fc = random.choice([(60, 18, 8), (50, 15, 10), (45, 20, 12)])
            for r in range(fr, 0, -2):
                frac = 1.0 - r / fr
                pygame.draw.circle(wear_surf, (*fc, int(10 * frac * frac)),
                                   (fx, fy), r)
        # 이동 흔적 (가로 줄)
        for _ in range(8):
            sx = random.randint(PILLAR_OFFSET, PILLAR_OFFSET + GAME_WIDTH)
            sy = random.randint(0, H)
            sw = random.randint(30, 80)
            sh = random.randint(1, 2)
            pygame.draw.rect(wear_surf, (stone_light[0], stone_light[1], stone_light[2],
                                          random.randint(8, 18)), (sx, sy, sw, sh))
        random.seed()
        floor.blit(wear_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 11. 잔불/숯 흔적 (화염 테마)
        # ═══════════════════════════════════════════════════════════
        ember_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(7770)
        ember_colors = [
            (100, 30, 10),   # 어두운 잔불
            (80, 20, 8),     # 숯
            (120, 40, 15),   # 밝은 잔불
        ]
        for _ in range(30):
            ex = random.randint(0, W)
            ey = random.randint(0, H)
            er = random.randint(2, 6)
            ec = random.choice(ember_colors)
            pygame.draw.circle(ember_surf, (*ec, random.randint(15, 40)), (ex, ey), er)
            # 주변 미세한 불티
            for _ in range(random.randint(2, 5)):
                ox = ex + random.randint(-8, 8)
                oy = ey + random.randint(-8, 8)
                pygame.draw.circle(ember_surf, (*ec, random.randint(8, 22)),
                                   (ox, oy), random.randint(1, 2))
        random.seed()
        floor.blit(ember_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 12. 비네트 (가장자리 어둡게)
        # ═══════════════════════════════════════════════════════════
        vignette_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        vig_max2 = int(max(W, H) * 0.7)
        for ring in range(30):
            radius = int(vig_max2 * (1.0 - ring * 0.025))
            pygame.draw.circle(vignette_surf, (8, 3, 2, int(2.5 + ring * 1.8)),
                               (cx, cy), radius)
        floor.blit(vignette_surf, (0, 0))

    def draw_background_pattern(self, screen):
        """배경 패턴 - 중국 전통 사원 석재 바닥 (캐시된 고퀄리티 텍스처)"""
        screen.blit(self._floor_cache, (0, 0))
    
    def add_fire_impact(self, x, y):
        """불꽃탄이 바닥에 닿았을 때 호출되는 메소드"""
        # 완전 바닥에서 시작하도록 y 좌표를 HEIGHT로 설정
        y = HEIGHT - 10  # 화면 완전 바닥 (약간의 여유 10픽셀)
        
        self.impact_fire_zones.append({
            'x': x,
            'y': y,
            'duration': 700  # 0.7초 (밀리초 단위)
        })
        pass  # print(f"💥 불꽃 충돌 지점 추가: ({x}, {y}), 현재 총 {len(self.impact_fire_zones)}개")  # 디버그 비활성화
    
    def trigger_spiral_burst(self, inferno=False):
        """화염탄 발사시 나선 폭발 효과 트리거"""
        if inferno:
            self.spiral_burst_timer = 4000  # 홍련폭염시 4초간 지속 (밀리초)
            self.spiral_burst_max_timer = 4000  # 최대값 저장
            self.is_inferno_mode = True
            # 제3의 눈 초기화
            self.third_eye_opening = 0
            self.third_eye_glow = 0
            self.spiritual_rings = []
        else:
            self.spiral_burst_timer = 1300  # 일반 화염탄시 1.3초간 지속 (밀리초)
            self.spiral_burst_max_timer = 1300  # 최대값 저장
            self.is_inferno_mode = False
        self.spiral_burst_intensity = 1.0  # 최대 강도로 시작
    
    def set_inferno_mode(self, active):
        """홍련폭염 모드 설정"""
        self.is_inferno_mode = active
        if active:
            self.spiral_burst_timer = 4000  # 홍련폭염 활성화시 더 긴 효과 (4초)
            self.spiral_burst_max_timer = 4000  # 최대값 저장
            # 제3의 눈 초기화
            self.third_eye_opening = 0
            self.third_eye_glow = 0
            self.spiritual_rings = []
    
    def _update_fire_lines(self):
        """불타는 라인 애니메이션 업데이트"""
        # 새로운 불꽃 파티클 생성 (원형 라인과 가로 라인에서)
        if random.random() < 0.3:  # 30% 확률로 생성
            center_x = PILLAR_OFFSET + GAME_WIDTH // 2
            center_y = HEIGHT // 2
            game_left = PILLAR_OFFSET
            game_right = PILLAR_OFFSET + GAME_WIDTH

            # 중앙 원형 라인에서 불꽃 생성
            angle = random.uniform(0, math.pi * 2)
            x = center_x + math.cos(angle) * 120  # 반지름 120
            y = center_y + math.sin(angle) * 120
            self._create_fire_particle(x, y)

            # 가로 스타디움 라인에서 불꽃 생성 (점선 부분에서만)
            if random.random() < 0.5:
                # 왼쪽 또는 오른쪽 선택
                if random.random() < 0.5:
                    # 왼쪽 선
                    x = random.randint(game_left, center_x - 120)
                else:
                    # 오른쪽 선
                    x = random.randint(center_x + 120, game_right)
                self._create_fire_particle(x, center_y)
        
        # 파티클 업데이트
        for particle in self.fire_line_particles[:]:
            particle['y'] -= particle['vy']  # 위로 올라감
            particle['x'] += particle['vx']  # 약간 좌우로 흔들림
            particle['life'] -= 1
            particle['size'] *= 0.95  # 점점 작아짐
            
            if particle['life'] <= 0 or particle['size'] < 0.5:
                self.fire_line_particles.remove(particle)
    
    def _create_fire_particle(self, x, y):
        """불꽃 파티클 생성"""
        if len(self.fire_line_particles) < 100:  # 최대 파티클 수 제한
            particle = {
                'x': x,
                'y': y,
                'vx': random.uniform(-0.5, 0.5),  # 좌우 속도
                'vy': random.uniform(0.5, 2.0),   # 위로 올라가는 속도
                'size': random.uniform(2, 4),
                'life': random.randint(20, 40),
                'color': random.choice(self.fire_colors),
                'glow': random.uniform(0.6, 1.0),
            }
            self.fire_line_particles.append(particle)
    
    def draw_lotus_hologram(self, screen):
        """중앙 원 안에 일루미나티 스타일 신비로운 홀로그램 그리기"""
        center_x = PILLAR_OFFSET + GAME_WIDTH // 2
        center_y = HEIGHT // 2

        # spiral_burst_intensity가 복소수가 아닌지 확인하고 수정
        if isinstance(self.spiral_burst_intensity, complex):
            self.spiral_burst_intensity = 0
        
        # 맥동 효과
        pulse = math.sin(self.lotus_fade_phase) * 0.3 + 0.7  # 0.4 ~ 1.0
        glow_pulse = math.sin(self.lotus_fade_phase * 2) * 0.2 + 0.8  # 더 빠른 맥동
        
        # 평소에는 등속 운동
        rotation_speed = self.lotus_fade_phase
        
        # 화염탄 발사시 밝기 증가
        brightness_boost = 0
        if self.spiral_burst_timer > 0 and hasattr(self, 'spiral_burst_max_timer'):
            # 회전 중일 때 밝기 부스트 (0~50)
            progress = 1.0 - (self.spiral_burst_timer / self.spiral_burst_max_timer)
            # 중간 부분(0.2~0.7초)에서 최대 밝기
            if progress < 0.154:  # 0~0.2초
                brightness_boost = int(30 * (progress / 0.154))
            elif progress < 0.538:  # 0.2~0.7초 (최대 밝기)
                brightness_boost = 50
            else:  # 0.7~1.3초
                brightness_boost = int(50 * (1 - (progress - 0.538) / (1.0 - 0.538)))
        
        # 1. 외부 원 - 신성한 기하학 패턴
        for i in range(3):  # 3겹의 원
            radius = 100 - i * 5
            alpha = int(60 * pulse * (1 - i * 0.2))
            # 어두운 붉은색 원 (밝기 부스트 적용)
            dark_red = (120 + brightness_boost, 30 + brightness_boost//3, 20 + brightness_boost//4)
            pygame.draw.circle(screen, dark_red, (center_x, center_y), radius, 1)
            # 글로우 효과 - 어두운 붉은색 그라데이션
            for j in range(3):
                glow_alpha = int(20 * pulse * (1 - j * 0.3))
                # 어두운 붉은색 그라데이션
                glow_color = (100 + brightness_boost - j * 10, 20 + brightness_boost//4 - j * 5, 15)
                pygame.draw.circle(screen, glow_color, (center_x, center_y), radius + j, 1)
        
        # 2. 삼각형 (피라미드) - 일루미나티의 상징
        triangle_size = 70
        # 회전하는 삼각형 좌표 계산
        triangle_points = []
        for i in range(3):
            angle = rotation_speed + (i * 2 * math.pi / 3)
            x = center_x + triangle_size * math.cos(angle)
            y = center_y + triangle_size * math.sin(angle)
            triangle_points.append((x, y))
        
        # 삼각형 그리기 - 여러 겹으로
        for i in range(3):
            scale = 1 - i * 0.15
            scaled_points = []
            for px, py in triangle_points:
                sx = center_x + (px - center_x) * scale
                sy = center_y + (py - center_y) * scale
                scaled_points.append((sx, sy))
            
            # 어두운 붉은색 테두리 (밝기 부스트 적용)
            dark_red_triangle = (110 + brightness_boost, 25 + brightness_boost//3, 20 + brightness_boost//4)
            pygame.draw.polygon(screen, dark_red_triangle, scaled_points, 2 - i)
            
        # 3. 중앙의 눈 (All-Seeing Eye)
        eye_radius = 20
        # 눈 외곽 - 어두운 붉은색
        pygame.draw.ellipse(screen, (100 + brightness_boost, 20 + brightness_boost//4, 15 + brightness_boost//5), 
                          (center_x - eye_radius, center_y - eye_radius//2, 
                           eye_radius * 2, eye_radius), 2)
        
        # 홍채 - 맥동하는 효과 (어두운 붉은색)
        iris_size = int(10 + 5 * glow_pulse)
        # 여러 겹의 홍채 - 어두운 붉은색 그라데이션
        for i in range(3):
            # 어두운 붉은색 (진한 -> 연한)
            iris_color = (140 + brightness_boost - i * 20, 30 + brightness_boost//4 - i * 10, 20 - i * 5)
            pygame.draw.circle(screen, iris_color, (center_x, center_y), iris_size - i * 3, 0)
        
        # 동공 - 깊이감 있는 검은색
        pupil_size = int(5 + 2 * math.sin(self.lotus_fade_phase * 3))
        pygame.draw.circle(screen, (20, 0, 0), (center_x, center_y), pupil_size, 0)
        pygame.draw.circle(screen, (255, 255, 255), (center_x - 2, center_y - 2), 2, 0)  # 빛 반사
        
        # 홍련폭염 모드: 제3의 눈 (원의 중심에 위치)
        if self.is_inferno_mode and self.third_eye_opening > 0:
            # 제3의 눈 위치 (원의 정중앙)
            third_eye_x = center_x
            third_eye_y = center_y
            
            # 눈꺼풀 열림 애니메이션 (세로로 열림)
            eye_height = int(35 * self.third_eye_opening)  # 더 크게
            eye_width = int(20 * self.third_eye_opening)
            
            if eye_height > 0:
                # 제3의 눈 외곽 (세로로 긴 타원) - 기존 눈 위에 겹쳐서
                third_eye_color = (
                    min(255, 220 + int(35 * self.third_eye_glow)),
                    min(255, 180 + int(30 * self.third_eye_glow)), 
                    min(255, 100 + int(20 * self.third_eye_glow))
                )
                
                # 세로 눈 모양 그리기
                pygame.draw.ellipse(screen, third_eye_color,
                                  (third_eye_x - eye_width//2, third_eye_y - eye_height//2,
                                   eye_width, eye_height), 3)
                
                # 제3의 눈 홍채 (황금색 빛) - 더 크고 밝게
                if eye_height > 15:
                    iris_third = int(12 * self.third_eye_opening)
                    for i in range(3):
                        glow_color = (
                            min(255, 255 - i * 20),
                            min(255, 220 - i * 30),
                            min(255, 150 - i * 30)
                        )
                        pygame.draw.circle(screen, glow_color, (third_eye_x, third_eye_y), 
                                         iris_third - i * 3, 0)
                    
                    # 제3의 눈 동공 (빛나는 흰색) - 맥동
                    pupil_third = int(4 + 3 * self.third_eye_glow)
                    pygame.draw.circle(screen, (255, 255, 255), (third_eye_x, third_eye_y), pupil_third, 0)
                    
                    # 추가 빛 효과
                    for i in range(2):
                        glow_radius = pupil_third + 3 + i * 2
                        glow_alpha = int(100 * self.third_eye_glow * (1 - i * 0.3))
                        if glow_alpha > 0:
                            pygame.draw.circle(screen, (255, 250, 200), (third_eye_x, third_eye_y), glow_radius, 1)
            
            # 영적 고리들 (중심에서 퍼져나감)
            for ring in self.spiritual_rings:
                if ring['alpha'] > 0:
                    ring_color = (
                        min(255, 230), 
                        min(255, 180),
                        min(255, 100)
                    )
                    # 반투명 효과를 위해 여러 겹으로 그리기
                    for j in range(3):
                        alpha_adjusted = max(0, ring['alpha'] - j * 40)
                        if alpha_adjusted > 0:
                            pygame.draw.circle(screen, ring_color, 
                                             (third_eye_x, third_eye_y),
                                             ring['radius'] + j * 3, 1)
        
        # 4. 방사형 광선 (Divine Light)
        ray_count = 12
        for i in range(ray_count):
            angle = rotation_speed / 3 + (i * 2 * math.pi / ray_count)
            
            # 광선 길이 맥동
            ray_length = 90 + 20 * math.sin(self.lotus_fade_phase + i * 0.5)
            
            # 시작점과 끝점
            start_x = center_x + 25 * math.cos(angle)
            start_y = center_y + 25 * math.sin(angle)
            end_x = center_x + ray_length * math.cos(angle)
            end_y = center_y + ray_length * math.sin(angle)
            
            # 광선 그리기 (그라데이션 효과)
            alpha = int(40 * pulse * (1 + math.sin(self.lotus_fade_phase * 2 + i)))
            if alpha > 0:
                # 얇은 광선 - 어두운 붉은색 (밝기 부스트 적용)
                ray_color = (90 + brightness_boost, 20 + brightness_boost//4, 15 + brightness_boost//5)
                pygame.draw.line(screen, ray_color, (start_x, start_y), (end_x, end_y), 1)
        
        # 5. 신성한 기하학 심볼 - 작은 삼각형들
        small_triangles = 6
        for i in range(small_triangles):
            angle = rotation_speed * 2 + (i * 2 * math.pi / small_triangles)
            distance = 50
            tx = center_x + distance * math.cos(angle)
            ty = center_y + distance * math.sin(angle)
            
            # 작은 삼각형 그리기
            mini_size = 8
            mini_points = []
            for j in range(3):
                mini_angle = -rotation_speed + angle + (j * 2 * math.pi / 3)
                mx = tx + mini_size * math.cos(mini_angle)
                my = ty + mini_size * math.sin(mini_angle)
                mini_points.append((mx, my))
            
            # 작은 삼각형 - 어두운 붉은색 (밝기 부스트 적용)
            pygame.draw.polygon(screen, (80 + brightness_boost, 20 + brightness_boost//5, 15 + brightness_boost//6), mini_points, 1)
        
        # 6. 화염탄 발사시 추가 효과 (추가 밝기는 이미 brightness_boost로 적용됨)
        if self.spiral_burst_intensity > 0:
            # 강렬한 후광 효과 - 붉은색
            for i in range(5):
                halo_radius = 120 + i * 10 * self.spiral_burst_intensity
                halo_alpha = int(30 * self.spiral_burst_intensity * (1 - i * 0.2))
                if halo_alpha > 0:
                    # 붉은색 후광
                    halo_color = (180 - i * 15, 40 - i * 8, 30 - i * 5)
                    pygame.draw.circle(screen, halo_color, (center_x, center_y), int(halo_radius), 1)
            
            # 중앙 눈이 더 밝게 빛남 - 붉은 빛
            glow_size = int(30 * self.spiral_burst_intensity)
            for i in range(3):
                glow_alpha = int(50 * self.spiral_burst_intensity * (1 - i * 0.3))
                if glow_alpha > 0:
                    # 붉은 글로우
                    glow_color = (160 - i * 10, 35 - i * 5, 25 - i * 3)
                    pygame.draw.circle(screen, glow_color, (center_x, center_y), glow_size + i * 5, 1)
    
    def _draw_fire_lines(self, screen, center_x, center_y):
        """불타는 스타디움 라인 그리기"""
        # 불꽃 빛나기 효과 계산
        glow_intensity = (math.sin(self.fire_glow_phase) + 1) * 0.3 + 0.4  # 0.4 ~ 1.0
        
        # 중앙 원형 라인 (은은한 불꽃 효과)
        # 여러 겹의 글로우 효과로 불타는 느낌
        for i in range(3):
            alpha = int(25 * glow_intensity * (1 - i * 0.3))
            radius = 120 + i * 2  # 기본 반지름 120
            color = (200 + int(55 * glow_intensity), 
                    60 + int(40 * glow_intensity), 
                    20)
            
            # 글로우 원 그리기
            pygame.draw.circle(screen, color, (center_x, center_y), radius, 2 + i)
        
        # 메인 원형 라인 (얇고 밝은 불꽃색)
        main_color = (255, int(100 + 50 * glow_intensity), 50)
        pygame.draw.circle(screen, main_color, (center_x, center_y), 120, 1)
        
        # 가로 스타디움 라인 (점선 효과로 은은한 불꽃)
        dash_length = 20
        gap_length = 15
        
        # 왼쪽 점선
        for x in range(0, center_x - 120, dash_length + gap_length):
            end_x = min(x + dash_length, center_x - 120)
            
            # 글로우 효과
            for i in range(2):
                thickness = 3 - i
                color = (200 + int(55 * glow_intensity),
                        60 + int(40 * glow_intensity),
                        20)
                pygame.draw.line(screen, color, (x, center_y), (end_x, center_y), thickness)
            
            # 메인 점선
            pygame.draw.line(screen, main_color, (x, center_y), (end_x, center_y), 1)
        
        # 오른쪽 점선
        for x in range(center_x + 120, WIDTH, dash_length + gap_length):
            end_x = min(x + dash_length, WIDTH)
            
            # 글로우 효과
            for i in range(2):
                thickness = 3 - i
                color = (200 + int(55 * glow_intensity),
                        60 + int(40 * glow_intensity),
                        20)
                pygame.draw.line(screen, color, (x, center_y), (end_x, center_y), thickness)
            
            # 메인 점선
            pygame.draw.line(screen, main_color, (x, center_y), (end_x, center_y), 1)
        
        # 불꽃 파티클 그리기
        for particle in self.fire_line_particles:
            # 파티클 글로우 효과
            glow_alpha = int(particle['glow'] * particle['life'] * 1.5)
            if glow_alpha > 0:
                glow_size = particle['size'] * 1.5
                pygame.draw.circle(screen, particle['color'],
                                 (int(particle['x']), int(particle['y'])),
                                 int(particle['size']))

    def draw(self, screen):
        """전체 스테이지 5 맵 그리기"""
        # 배경 패턴
        self.draw_background_pattern(screen)
        
        # 화염 효과 (배경)
        self.draw_fire_effects(screen)
        
        # 홍련꽃 홀로그램 엠블럼 (중앙 원 안에)
        self.draw_lotus_hologram(screen)
        
        # 중앙 스타디움 라인 (원래대로 복구)
        self.draw_stadium_line(screen)
        
        # 등롱 장식 제거
        # self.draw_lanterns(screen)
        
        # 테두리 (마지막에 그려서 위에 표시)
        self.draw_border(screen)


# 테스트 코드
if __name__ == "__main__":
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Stage 5 - 중국 전통시장 화염 테마")
    clock = pygame.time.Clock()
    
    stage5 = Stage5ChineseMarket()
    
    running = True
    while running:
        dt = clock.tick(60)
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
        
        # 업데이트
        stage5.update(dt)
        
        # 그리기
        screen.fill((20, 5, 5))
        stage5.draw(screen)
        
        pygame.display.flip()
    
    pygame.quit()