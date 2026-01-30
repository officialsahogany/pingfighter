# -*- coding: utf-8 -*-
"""
Stage 1: 한국 전통 용 기둥 배경 (고퀄리티 버전)
- 정교한 용 문양
- 세련된 단청 패턴
- 부드러운 그라데이션
- 은은한 애니메이션
"""

import pygame
import math
import random


class DragonPillarBackground:
    """한국 전통 용 기둥 배경 (고퀄리티)"""

    # 한국 전통 색상 팔레트
    COLORS = {
        # 기둥 기본색
        'pillar_dark': (45, 25, 20),
        'pillar_mid': (75, 35, 28),
        'pillar_light': (100, 50, 38),
        'pillar_highlight': (130, 70, 55),

        # 단청 색상 (오방색)
        'dancheong_red': (180, 50, 45),
        'dancheong_blue': (45, 75, 140),
        'dancheong_green': (50, 120, 80),
        'dancheong_yellow': (200, 160, 60),
        'dancheong_white': (240, 235, 225),

        # 용 색상
        'dragon_body': (55, 100, 130),
        'dragon_dark': (35, 70, 100),
        'dragon_light': (80, 130, 160),
        'dragon_scale': (70, 115, 145),
        'dragon_belly': (180, 160, 130),

        # 황금색
        'gold_dark': (150, 110, 40),
        'gold_mid': (200, 160, 60),
        'gold_light': (230, 195, 90),
        'gold_shine': (255, 230, 150),

        # 배경
        'bg_dark': (20, 18, 22),
        'bg_gradient': (35, 30, 40),
    }

    def __init__(self, screen_width, screen_height, game_width, game_height):
        self.sw = screen_width
        self.sh = screen_height

        self.game_x = (screen_width - game_width) // 2
        self.game_y = 0
        self.game_w = game_width
        self.game_h = game_height

        self.pillar_width = self.game_x
        self.right_pillar_x = self.game_x + game_width

        # 애니메이션 상태
        self.time = 0.0

        # 파티클
        self.sparkles = []
        self.clouds = []
        self._init_particles()

        # 캐시된 서피스
        self._left_pillar = None
        self._right_pillar = None
        self._create_pillars()

    def _init_particles(self):
        """파티클 초기화"""
        # 용 비늘 반짝임
        for _ in range(12):
            self.sparkles.append({
                'x': random.randint(0, self.pillar_width),
                'y': random.randint(100, self.sh - 100),
                'phase': random.uniform(0, 6.28),
                'speed': random.uniform(2, 4),
                'side': random.choice(['left', 'right']),
                'size': random.uniform(1.5, 3),
            })

        # 구름
        for _ in range(4):
            self.clouds.append({
                'x': random.randint(-30, self.sw + 30),
                'y': random.randint(30, 150),
                'speed': random.uniform(0.2, 0.5),
                'size': random.uniform(0.6, 1.0),
                'alpha': random.randint(20, 40),
            })

    def _create_pillars(self):
        """필러 서피스 생성"""
        if self.pillar_width <= 0:
            return

        self._left_pillar = pygame.Surface((self.pillar_width, self.sh), pygame.SRCALPHA)
        self._right_pillar = pygame.Surface((self.pillar_width, self.sh), pygame.SRCALPHA)

        self._draw_pillar(self._left_pillar, is_left=True)
        self._draw_pillar(self._right_pillar, is_left=False)

    def _draw_pillar(self, surface, is_left):
        """개별 필러 그리기"""
        w, h = surface.get_size()

        # 1. 배경 그라데이션
        for y in range(h):
            t = y / h
            r = int(self.COLORS['bg_dark'][0] * (1-t) + self.COLORS['bg_gradient'][0] * t)
            g = int(self.COLORS['bg_dark'][1] * (1-t) + self.COLORS['bg_gradient'][1] * t)
            b = int(self.COLORS['bg_dark'][2] * (1-t) + self.COLORS['bg_gradient'][2] * t)
            pygame.draw.line(surface, (r, g, b), (0, y), (w, y))

        # 2. 기둥 본체 (3D 효과)
        margin = 8
        pillar_rect = pygame.Rect(margin, 0, w - margin * 2, h)

        # 기둥 그라데이션 (세로)
        for x in range(pillar_rect.left, pillar_rect.right):
            rel_x = (x - pillar_rect.left) / pillar_rect.width
            # 볼록한 3D 효과
            brightness = 1.0 - abs(rel_x - 0.4) * 0.8
            r = int(self.COLORS['pillar_mid'][0] * brightness)
            g = int(self.COLORS['pillar_mid'][1] * brightness)
            b = int(self.COLORS['pillar_mid'][2] * brightness)
            pygame.draw.line(surface, (r, g, b), (x, 0), (x, h))

        # 3. 상단 장식 (단청)
        self._draw_top_decoration(surface, w, is_left)

        # 4. 하단 장식 (단청)
        self._draw_bottom_decoration(surface, w, h)

        # 5. 용 그리기
        self._draw_dragon(surface, w, h, is_left)

        # 6. 테두리 금장
        self._draw_gold_border(surface, w, h, margin)

    def _draw_top_decoration(self, surface, w, is_left):
        """상단 단청 장식"""
        # 기와 지붕 모양
        roof_height = 50

        # 기와색 배경
        pygame.draw.rect(surface, (60, 55, 50), (0, 0, w, roof_height))

        # 기와 무늬
        tile_width = 12
        for i in range(0, w, tile_width):
            pygame.draw.arc(surface, (45, 40, 38),
                          (i - tile_width//2, 5, tile_width, 20), 0, 3.14, 2)
            pygame.draw.arc(surface, (75, 70, 65),
                          (i - tile_width//2, 25, tile_width, 20), 0, 3.14, 2)

        # 단청 띠
        colors = [self.COLORS['dancheong_red'], self.COLORS['dancheong_green'],
                  self.COLORS['dancheong_blue'], self.COLORS['gold_mid']]

        y = roof_height
        for i, color in enumerate(colors):
            pygame.draw.rect(surface, color, (5, y + i*6, w-10, 5))
            # 패턴 추가
            if i % 2 == 0:
                for x in range(10, w-10, 15):
                    pygame.draw.circle(surface, self.COLORS['gold_light'],
                                      (x, y + i*6 + 2), 2)

    def _draw_bottom_decoration(self, surface, w, h):
        """하단 단청 장식"""
        base_y = h - 80

        # 단청 띠
        colors = [self.COLORS['dancheong_blue'], self.COLORS['dancheong_green'],
                  self.COLORS['dancheong_red'], self.COLORS['gold_mid']]

        for i, color in enumerate(colors):
            pygame.draw.rect(surface, color, (5, base_y + i*6, w-10, 5))

        # 연꽃 문양
        cx = w // 2
        cy = h - 40
        self._draw_lotus(surface, cx, cy, 25)

    def _draw_lotus(self, surface, cx, cy, size):
        """연꽃 문양"""
        # 꽃잎
        petal_color = self.COLORS['dancheong_red']
        for i in range(8):
            angle = i * (math.pi / 4) - math.pi/2
            px = cx + int(math.cos(angle) * size * 0.7)
            py = cy + int(math.sin(angle) * size * 0.7)

            # 꽃잎 타원
            petal_surf = pygame.Surface((size, size//2), pygame.SRCALPHA)
            pygame.draw.ellipse(petal_surf, (*petal_color, 200), (0, 0, size, size//2))
            rotated = pygame.transform.rotate(petal_surf, -math.degrees(angle) - 90)
            rect = rotated.get_rect(center=(px, py))
            surface.blit(rotated, rect)

        # 중심
        pygame.draw.circle(surface, self.COLORS['gold_mid'], (cx, cy), size//3)
        pygame.draw.circle(surface, self.COLORS['gold_light'], (cx, cy), size//4)

    def _draw_dragon(self, surface, w, h, is_left):
        """용 그리기 (곡선으로 감싸는 형태)"""
        # 용의 경로 (베지어 곡선 기반)
        center_x = w // 2

        # 몸통 경로 점들
        direction = 1 if is_left else -1

        body_points = []
        amplitude = w * 0.25

        for i in range(0, h - 100, 8):
            y = 100 + i
            # S자 곡선
            t = i / (h - 200)
            wave = math.sin(t * math.pi * 2.5 + (0 if is_left else math.pi)) * amplitude
            x = center_x + wave
            body_points.append((x, y))

        # 몸통 그리기 (두꺼운 선으로 여러 레이어)
        body_width = w * 0.18

        if len(body_points) > 1:
            # 그림자
            shadow_points = [(p[0] + 3, p[1] + 3) for p in body_points]
            pygame.draw.lines(surface, (20, 20, 25), False, shadow_points, int(body_width + 4))

            # 몸통 외곽 (어두운 색)
            pygame.draw.lines(surface, self.COLORS['dragon_dark'], False, body_points, int(body_width + 2))

            # 몸통 본체
            pygame.draw.lines(surface, self.COLORS['dragon_body'], False, body_points, int(body_width))

            # 몸통 하이라이트
            highlight_points = [(p[0] - 2, p[1]) for p in body_points]
            pygame.draw.lines(surface, self.COLORS['dragon_light'], False, highlight_points, int(body_width * 0.5))

        # 비늘 패턴
        for i, (x, y) in enumerate(body_points[::3]):
            if 0 < x < w:
                scale_size = int(body_width * 0.3)
                # 비늘 반원
                pygame.draw.arc(surface, self.COLORS['dragon_scale'],
                              (int(x - scale_size//2), int(y - scale_size//2),
                               scale_size, scale_size),
                              0, math.pi, 2)

        # 머리 그리기
        if body_points:
            head_x, head_y = body_points[0]
            self._draw_dragon_head(surface, head_x, head_y - 20, w, is_left)

        # 꼬리
        if body_points:
            tail_x, tail_y = body_points[-1]
            self._draw_dragon_tail(surface, tail_x, tail_y, is_left)

    def _draw_dragon_head(self, surface, cx, cy, pillar_width, is_left):
        """용 머리 그리기"""
        direction = 1 if is_left else -1
        head_size = pillar_width * 0.35

        # 갈기
        for i in range(5):
            mane_angle = math.pi * 0.7 + i * 0.15 - 0.3
            if not is_left:
                mane_angle = math.pi - mane_angle
            mx = cx + math.cos(mane_angle) * head_size * 1.2
            my = cy + math.sin(mane_angle) * head_size * 0.8
            pygame.draw.line(surface, self.COLORS['dancheong_red'],
                           (cx, cy), (int(mx), int(my)), 4)

        # 머리 본체 (타원)
        head_rect = pygame.Rect(cx - head_size//2, cy - head_size//2, head_size, head_size * 0.8)
        pygame.draw.ellipse(surface, self.COLORS['dragon_dark'], head_rect)
        pygame.draw.ellipse(surface, self.COLORS['dragon_body'], head_rect.inflate(-4, -4))

        # 뿔
        horn_x = cx + direction * head_size * 0.2
        horn_y = cy - head_size * 0.4
        horn_points = [
            (horn_x, horn_y + 10),
            (horn_x + direction * 8, horn_y - 20),
            (horn_x + direction * 3, horn_y + 5)
        ]
        pygame.draw.polygon(surface, self.COLORS['gold_dark'], horn_points)

        # 눈 (저장해서 나중에 애니메이션)
        eye_x = cx + direction * head_size * 0.15
        eye_y = cy - 5
        self._dragon_eye_pos = (eye_x, eye_y, is_left)

        # 눈 그리기 (정적)
        pygame.draw.circle(surface, (255, 255, 255), (int(eye_x), int(eye_y)), 6)
        pygame.draw.circle(surface, (30, 30, 30), (int(eye_x), int(eye_y)), 3)

        # 수염
        whisker_start = (cx + direction * head_size * 0.4, cy + 10)
        whisker_end = (cx + direction * head_size * 0.8, cy + 35)
        pygame.draw.line(surface, self.COLORS['dancheong_white'], whisker_start, whisker_end, 2)

    def _draw_dragon_tail(self, surface, tx, ty, is_left):
        """용 꼬리"""
        direction = 1 if is_left else -1

        # 꼬리 지느러미
        tail_points = [
            (tx, ty),
            (tx + direction * 15, ty + 30),
            (tx - direction * 10, ty + 50),
            (tx + direction * 5, ty + 70),
        ]
        pygame.draw.lines(surface, self.COLORS['dragon_body'], False, tail_points, 6)
        pygame.draw.lines(surface, self.COLORS['dragon_light'], False, tail_points, 3)

    def _draw_gold_border(self, surface, w, h, margin):
        """금색 테두리"""
        # 외곽선
        pygame.draw.rect(surface, self.COLORS['gold_dark'],
                        (margin-2, 0, w-margin*2+4, h), 2)

        # 내곽선 (밝은 금색)
        pygame.draw.rect(surface, self.COLORS['gold_light'],
                        (margin, 2, w-margin*2, h-4), 1)

        # 모서리 장식
        corner_size = 12
        corners = [(margin, 50), (w-margin, 50), (margin, h-50), (w-margin, h-50)]
        for cx, cy in corners:
            pygame.draw.circle(surface, self.COLORS['gold_mid'], (cx, cy), corner_size//2)
            pygame.draw.circle(surface, self.COLORS['gold_light'], (cx, cy), corner_size//3)

    def _draw_cloud(self, surface, x, y, size, alpha):
        """구름 그리기"""
        cloud_surf = pygame.Surface((int(60 * size), int(30 * size)), pygame.SRCALPHA)
        color = (255, 255, 255, alpha)

        # 구름 형태
        pygame.draw.ellipse(cloud_surf, color, (0, 10*size, 25*size, 15*size))
        pygame.draw.ellipse(cloud_surf, color, (15*size, 5*size, 30*size, 20*size))
        pygame.draw.ellipse(cloud_surf, color, (35*size, 10*size, 20*size, 15*size))

        surface.blit(cloud_surf, (int(x), int(y)))

    def update(self, dt, excitement=0.0):
        """애니메이션 업데이트"""
        self.time += dt

        # 구름 이동
        for cloud in self.clouds:
            cloud['x'] += cloud['speed']
            if cloud['x'] > self.sw + 50:
                cloud['x'] = -60 * cloud['size']
                cloud['y'] = random.randint(30, 150)

    def draw(self, surface):
        """전체 그리기"""
        # 배경
        surface.fill(self.COLORS['bg_dark'])

        # 구름 (배경)
        for cloud in self.clouds:
            self._draw_cloud(surface, cloud['x'], cloud['y'], cloud['size'], cloud['alpha'])

        # 캐시된 필러 그리기
        if self._left_pillar:
            # 숨쉬기 애니메이션 (미세한 움직임)
            breath_offset = int(math.sin(self.time * 1.5) * 1.5)
            surface.blit(self._left_pillar, (0, breath_offset))

        if self._right_pillar:
            breath_offset = int(math.sin(self.time * 1.5 + 1.0) * 1.5)
            surface.blit(self._right_pillar, (self.right_pillar_x, breath_offset))

        # 반짝임 효과
        for sp in self.sparkles:
            intensity = math.sin(self.time * sp['speed'] + sp['phase'])
            if intensity > 0.7:
                alpha = int((intensity - 0.7) * 3 * 255)
                if sp['side'] == 'left':
                    x = sp['x']
                else:
                    x = self.right_pillar_x + sp['x']

                # 십자 반짝임
                size = int(sp['size'])
                spark_surf = pygame.Surface((size*4, size*4), pygame.SRCALPHA)
                color = (*self.COLORS['gold_light'], min(alpha, 200))
                pygame.draw.line(spark_surf, color, (size*2-size, size*2), (size*2+size, size*2), 1)
                pygame.draw.line(spark_surf, color, (size*2, size*2-size), (size*2, size*2+size), 1)
                surface.blit(spark_surf, (int(x)-size*2, int(sp['y'])-size*2))

        # 용 눈 빛남 효과
        if hasattr(self, '_dragon_eye_pos'):
            eye_glow = int(100 + 50 * math.sin(self.time * 3))
            # 왼쪽 눈
            glow_surf = pygame.Surface((16, 16), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (255, 200, 100, eye_glow), (8, 8), 6)
            pygame.draw.circle(glow_surf, (255, 255, 200, min(eye_glow + 50, 255)), (8, 8), 3)

            ex, ey, is_left = self._dragon_eye_pos
            surface.blit(glow_surf, (int(ex) - 8, int(ey) - 8 + int(math.sin(self.time * 1.5) * 1.5)))
            # 오른쪽 눈 (미러)
            surface.blit(glow_surf, (int(self.right_pillar_x + self.pillar_width - ex) - 8,
                                    int(ey) - 8 + int(math.sin(self.time * 1.5 + 1.0) * 1.5)))


# 싱글톤
_dragon_pillar_bg = None


def get_dragon_pillar_background(screen_width=760, screen_height=750,
                                  game_width=600, game_height=750):
    global _dragon_pillar_bg
    if _dragon_pillar_bg is None:
        _dragon_pillar_bg = DragonPillarBackground(
            screen_width, screen_height, game_width, game_height)
    return _dragon_pillar_bg


def reset_dragon_pillar_background():
    global _dragon_pillar_bg
    _dragon_pillar_bg = None
