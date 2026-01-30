# -*- coding: utf-8 -*-
"""
Stage 1: 한국 전통 용 기둥 배경 (코드 기반)
Gemini API가 생성한 코드를 게임에 맞게 수정
- 전통 용 문양
- 단청 패턴
- 구름 효과
- 은은한 애니메이션
"""

import pygame
import math
import random


class DragonPillarBackground:
    """한국 전통 용 기둥 배경 (코드로 직접 그림)"""

    def __init__(self, screen_width, screen_height, game_width, game_height):
        self.sw = screen_width
        self.sh = screen_height

        # 게임 영역 계산
        self.game_x = (screen_width - game_width) // 2
        self.game_y = 0
        self.game_w = game_width
        self.game_h = game_height

        # 필러 영역 정의
        self.left_rect = pygame.Rect(0, 0, self.game_x, screen_height)
        self.right_rect = pygame.Rect(self.game_x + game_width, 0,
                                       screen_width - (self.game_x + game_width), screen_height)

        # 한국 전통 색상 팔레트 (오방색 + 변형)
        self.colors = {
            'dancheong_green': (66, 149, 117),    # 녹색
            'dancheong_red': (186, 43, 43),       # 진홍
            'dancheong_blue': (47, 65, 133),      # 청색
            'gold': (218, 165, 32),               # 황금
            'white': (245, 245, 245),             # 백색
            'wood': (101, 67, 33),                # 목재
            'roof_grey': (70, 75, 80),            # 기와색
            'glow': (255, 200, 50),               # 빛
            'pillar_red': (130, 40, 40),          # 기둥 붉은색
            'dark_bg': (20, 20, 25),              # 어두운 배경
        }

        # 애니메이션 상태
        self.time = 0
        self.breath_offset = 0
        self.eye_alpha = 0
        self.clouds = self._init_clouds()
        self.sparkles = []

        # 눈 위치 저장
        self.left_eye_pos = None
        self.right_eye_pos = None

        # 정적 요소 캐시
        self.left_pillar_surf = pygame.Surface(
            (self.left_rect.width, self.left_rect.height), pygame.SRCALPHA)
        self.right_pillar_surf = pygame.Surface(
            (self.right_rect.width, self.right_rect.height), pygame.SRCALPHA)

        # 정적 요소 그리기
        self._render_pillar(self.left_pillar_surf, is_left=True)
        self._render_pillar(self.right_pillar_surf, is_left=False)

        # 반짝임 위치 초기화
        self._init_sparkles()

    def _init_clouds(self):
        """구름 파티클 초기화"""
        clouds = []
        for _ in range(6):
            clouds.append({
                'x': random.randint(-50, self.sw),
                'y': random.randint(50, self.sh // 3),
                'speed': random.uniform(0.3, 0.6),
                'size': random.uniform(0.4, 0.8),
                'alpha': random.randint(30, 60)
            })
        return clouds

    def _init_sparkles(self):
        """용 비늘 반짝임 위치 초기화"""
        self.sparkles = []

        for is_left in [True, False]:
            rect = self.left_rect if is_left else self.right_rect
            center_x = rect.width // 2

            # 용 몸통 따라 반짝임 배치
            for y in range(150, self.sh - 150, 40):
                wave = math.sin(y * 0.012) * (rect.width * 0.2)
                x = center_x + wave
                if random.random() > 0.6:
                    self.sparkles.append({
                        'base_x': x + (0 if is_left else self.right_rect.x),
                        'y': y,
                        'phase': random.uniform(0, 6.28),
                        'speed': random.uniform(1.5, 3.0),
                        'is_left': is_left
                    })

    def _draw_dancheong_pattern(self, surface, x, y, size):
        """단청 패턴 그리기 (동심원 + 마름모)"""
        colors = [
            self.colors['dancheong_green'],
            self.colors['dancheong_red'],
            self.colors['dancheong_blue'],
            self.colors['gold']
        ]

        # 마름모 (외곽)
        points = [(x, y - size), (x + size, y), (x, y + size), (x - size, y)]
        pygame.draw.polygon(surface, colors[0], points)

        # 동심원
        radii = [size * 0.75, size * 0.55, size * 0.35, size * 0.15]
        for i, r in enumerate(radii):
            if r > 0:
                pygame.draw.circle(surface, colors[(i + 1) % 4], (int(x), int(y)), int(r))

    def _draw_dragon_body(self, surface, w, h, is_left):
        """용 몸통 그리기 (원 연속으로 사인파 형태)"""
        center_x = w // 2
        segment_radius = w * 0.12

        phase_offset = 0 if is_left else 3.14
        amplitude = w * 0.22
        frequency = 0.012

        # 몸통 그리기 (아래에서 위로)
        for y in range(h - 120, 120, -8):
            x_offset = math.sin(y * frequency + phase_offset) * amplitude
            cx = center_x + x_offset

            # 색상 그라데이션 (녹색 → 청색)
            progress = (h - y) / h
            r = int(self.colors['dancheong_green'][0] * (1 - progress) +
                   self.colors['dancheong_blue'][0] * progress)
            g = int(self.colors['dancheong_green'][1] * (1 - progress) +
                   self.colors['dancheong_blue'][1] * progress)
            b = int(self.colors['dancheong_green'][2] * (1 - progress) +
                   self.colors['dancheong_blue'][2] * progress)
            col = (r, g, b)

            # 몸통 세그먼트
            pygame.draw.circle(surface, col, (int(cx), int(y)), int(segment_radius))

            # 비늘 디테일 (황금 테두리)
            if y % 24 == 0:
                pygame.draw.circle(surface, self.colors['gold'],
                                 (int(cx), int(y)), int(segment_radius), 1)

        # 머리 그리기
        head_y = 130
        head_x_offset = math.sin(head_y * frequency + phase_offset) * amplitude
        head_x = center_x + head_x_offset
        self._draw_dragon_head(surface, head_x, head_y, w, is_left)

    def _draw_dragon_head(self, surface, head_x, head_y, pillar_width, is_left):
        """용 머리 그리기"""
        head_size = pillar_width * 0.28
        direction = 1 if is_left else -1

        # 갈기 (붉은색)
        for i in range(4):
            offset_y = (i - 2) * 8
            mane_points = [
                (head_x, head_y + offset_y),
                (head_x - (40 * direction), head_y - 20 + offset_y),
                (head_x - (55 * direction), head_y + 5 + offset_y)
            ]
            pygame.draw.lines(surface, self.colors['dancheong_red'], False, mane_points, 3)

        # 머리 본체
        pygame.draw.circle(surface, self.colors['dancheong_green'],
                          (int(head_x), int(head_y)), int(head_size))

        # 주둥이
        snout_w = head_size * 1.0
        snout_h = head_size * 0.8
        if direction == 1:
            snout_rect = pygame.Rect(head_x, head_y - snout_h // 2, snout_w, snout_h)
        else:
            snout_rect = pygame.Rect(head_x - snout_w, head_y - snout_h // 2, snout_w, snout_h)
        pygame.draw.ellipse(surface, self.colors['dancheong_blue'], snout_rect)

        # 뿔
        horn_points = [
            (head_x - 5 * direction, head_y - head_size * 0.7),
            (head_x - 15 * direction, head_y - head_size * 1.3),
            (head_x + 8 * direction, head_y - head_size * 0.7)
        ]
        pygame.draw.polygon(surface, self.colors['wood'], horn_points)

        # 수염
        whisker_start = (head_x + (head_size * 0.8 * direction), head_y + 5)
        whisker_mid = (head_x + (head_size * 1.4 * direction), head_y + 25)
        whisker_end = (head_x + (head_size * 1.1 * direction), head_y + 50)
        pygame.draw.lines(surface, self.colors['white'], False,
                         [whisker_start, whisker_mid, whisker_end], 2)

        # 눈 위치 저장
        eye_x = head_x + (head_size * 0.3 * direction)
        eye_y = head_y - 3
        if is_left:
            self.left_eye_pos = (int(eye_x), int(eye_y))
        else:
            self.right_eye_pos = (int(eye_x), int(eye_y))

    def _render_pillar(self, surface, is_left):
        """정적 필러 요소 렌더링"""
        w, h = surface.get_size()

        # 배경
        surface.fill(self.colors['dark_bg'])

        # 기둥 본체
        pillar_margin = w * 0.1
        pillar_rect = pygame.Rect(pillar_margin, 40, w - pillar_margin * 2, h - 40)
        pygame.draw.rect(surface, self.colors['pillar_red'], pillar_rect)
        pygame.draw.rect(surface, self.colors['gold'], pillar_rect, 2)

        # 상단 단청
        top_block = pygame.Rect(pillar_margin, 40, w - pillar_margin * 2, 80)
        pygame.draw.rect(surface, self.colors['dancheong_green'], top_block)
        self._draw_dancheong_pattern(surface, w // 2, 80, 12)

        # 하단 단청
        bottom_block = pygame.Rect(pillar_margin, h - 100, w - pillar_margin * 2, 100)
        pygame.draw.rect(surface, self.colors['dancheong_blue'], bottom_block)
        self._draw_dancheong_pattern(surface, w // 2, h - 50, 18)

        # 기와 지붕
        pygame.draw.arc(surface, self.colors['roof_grey'],
                       (-w * 0.1, 10, w * 1.2, 50), 0, 3.14, 15)
        for i in range(0, int(w), 12):
            pygame.draw.line(surface, (50, 50, 55), (i, 10), (i, 40), 2)

        # 용 그리기
        self._draw_dragon_body(surface, w, h, is_left)

    def _draw_korean_cloud(self, surface, x, y, size, alpha):
        """한국 전통 구름 그리기"""
        cloud_surf = pygame.Surface((int(80 * size), int(40 * size)), pygame.SRCALPHA)
        color = (*self.colors['white'], alpha)

        # 구름 형태 (겹친 원들)
        centers = [(20, 20), (35, 15), (50, 20)]
        radii = [15, 18, 15]

        for (cx, cy), r in zip(centers, radii):
            pygame.draw.circle(cloud_surf, color,
                             (int(cx * size), int(cy * size)), int(r * size))

        surface.blit(cloud_surf, (int(x), int(y)))

    def _draw_glowing_eye(self, surface, x, y, alpha):
        """빛나는 용 눈 그리기"""
        if x is None or y is None:
            return

        # 글로우 효과
        glow_surf = pygame.Surface((16, 16), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*self.colors['dancheong_red'], alpha // 3), (8, 8), 6)
        pygame.draw.circle(glow_surf, (*self.colors['gold'], alpha), (8, 8), 3)
        pygame.draw.circle(glow_surf, self.colors['glow'], (8, 8), 2)

        surface.blit(glow_surf, (x - 8, y - 8))

    def update(self, dt, excitement=0.0):
        """애니메이션 업데이트"""
        self.time += dt

        # 숨쉬기 애니메이션
        breath_speed = 1.5 + (excitement * 2.0)
        self.breath_offset = math.sin(self.time * breath_speed) * 2

        # 눈 빛 맥동
        self.eye_alpha = int(120 + 80 * math.sin(self.time * 2.5))

        # 구름 업데이트
        for cloud in self.clouds:
            cloud['x'] += cloud['speed'] * (1 + excitement * 0.5)
            if cloud['x'] > self.sw + 50:
                cloud['x'] = -80 * cloud['size']
                cloud['y'] = random.randint(30, self.sh // 3)

    def draw(self, surface):
        """배경 그리기"""
        # 1. 구름 (배경 레이어)
        for cloud in self.clouds:
            self._draw_korean_cloud(surface, cloud['x'], cloud['y'],
                                   cloud['size'], cloud['alpha'])

        # 2. 캐시된 필러 (숨쉬기 오프셋 적용)
        left_y = int(self.breath_offset)
        surface.blit(self.left_pillar_surf, (0, left_y))

        right_y = int(math.sin(self.time * 1.5 + 1.2) * 2)
        surface.blit(self.right_pillar_surf, (self.right_rect.x, right_y))

        # 3. 반짝임 효과
        for sp in self.sparkles:
            intensity = math.sin(self.time * sp['speed'] + sp['phase'])
            if intensity > 0.85:
                y_adj = sp['y'] + (left_y if sp['is_left'] else right_y)
                cx, cy = int(sp['base_x']), int(y_adj)

                # 작은 십자 모양
                pygame.draw.line(surface, self.colors['gold'],
                               (cx - 2, cy), (cx + 2, cy), 1)
                pygame.draw.line(surface, self.colors['gold'],
                               (cx, cy - 2), (cx, cy + 2), 1)

        # 4. 빛나는 눈
        if self.left_eye_pos:
            self._draw_glowing_eye(surface, self.left_eye_pos[0],
                                  self.left_eye_pos[1] + left_y, self.eye_alpha)
        if self.right_eye_pos:
            ex = self.right_rect.x + self.right_eye_pos[0]
            self._draw_glowing_eye(surface, ex,
                                  self.right_eye_pos[1] + right_y, self.eye_alpha)


# 싱글톤 인스턴스
_dragon_pillar_bg = None


def get_dragon_pillar_background(screen_width=760, screen_height=750,
                                  game_width=600, game_height=750):
    """용 기둥 배경 싱글톤 반환"""
    global _dragon_pillar_bg
    if _dragon_pillar_bg is None:
        _dragon_pillar_bg = DragonPillarBackground(
            screen_width, screen_height, game_width, game_height)
    return _dragon_pillar_bg


def reset_dragon_pillar_background():
    """배경 초기화"""
    global _dragon_pillar_bg
    _dragon_pillar_bg = None
