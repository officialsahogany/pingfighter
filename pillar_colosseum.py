# -*- coding: utf-8 -*-
"""
고대 투기장 스타일 필러 배경 (Stage 30 - Colosseum Arena)
로마 콜로세움 테마: 석조 기둥, 횃불, 월계수 장식
"""

import math
import random
import pygame


class ColosseumFrame:
    """고대 투기장 스타일 액자 테두리"""

    # 콜로세움 색상 팔레트
    COLORS = {
        'stone': (140, 130, 115),       # 석조 색상
        'dark_stone': (90, 85, 75),     # 어두운 돌
        'light_stone': (180, 170, 155), # 밝은 돌
        'gold': (200, 160, 60),         # 금색 (장식)
        'bronze': (180, 120, 60),       # 청동색
        'sand': (194, 158, 108),        # 모래색
        'torch_orange': (255, 140, 40), # 횃불 주황
        'torch_yellow': (255, 220, 100),# 횃불 노랑
        'shadow': (40, 35, 30),         # 그림자
        'laurel': (80, 120, 60),        # 월계수 녹색
    }

    def __init__(self, screen_width: int, screen_height: int,
                 game_width: int, game_height: int,
                 offset_x: int = None, offset_y: int = None,
                 original_game_width: int = None, original_game_height: int = None):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        self.original_game_width = original_game_width if original_game_width else game_width
        self.original_game_height = original_game_height if original_game_height else game_height

        self.scale_factor = game_width / self.original_game_width if self.original_game_width > 0 else 1.0

        self.game_x = offset_x if offset_x is not None else (screen_width - game_width) // 2
        self.game_y = offset_y if offset_y is not None else (screen_height - game_height) // 2

        # 애니메이션
        self.time = 0.0

        # 횃불
        self.torches = self._create_torches()

        # 먼지 파티클
        self.dust_particles = []
        self._create_dust_particles()

        # 캐시된 프레임
        self._frame_surface = None
        self._create_frame()

        # 검투사 실루엣 애니메이션
        self._gladiator_animation_timer = 0.0

    def _create_torches(self):
        """횃불 생성"""
        torches = []
        # 좌측 필러 횃불
        left_x = self.game_x // 2
        # 우측 필러 횃불
        right_x = self.game_x + self.game_width + (self.screen_width - self.game_x - self.game_width) // 2

        positions = [
            (left_x, self.screen_height * 0.2),
            (left_x, self.screen_height * 0.5),
            (left_x, self.screen_height * 0.8),
            (right_x, self.screen_height * 0.2),
            (right_x, self.screen_height * 0.5),
            (right_x, self.screen_height * 0.8),
        ]

        for x, y in positions:
            torches.append({
                'x': x,
                'y': y,
                'flicker_phase': random.uniform(0, math.pi * 2),
                'intensity': random.uniform(0.8, 1.0),
                'flame_height': random.uniform(25, 35),
            })
        return torches

    def _create_dust_particles(self):
        """먼지 파티클 생성"""
        for _ in range(15):
            side = random.choice(['left', 'right'])
            if side == 'left':
                x = random.randint(5, self.game_x - 5)
            else:
                x = random.randint(self.game_x + self.game_width + 5, self.screen_width - 5)

            self.dust_particles.append({
                'x': x,
                'y': random.randint(50, self.screen_height - 50),
                'vx': random.uniform(-0.2, 0.2),
                'vy': random.uniform(-0.3, 0.1),
                'size': random.uniform(1, 2),
                'alpha': random.randint(30, 60),
                'life': random.randint(200, 400),
                'side': side
            })

    def _create_frame(self):
        """프레임 캐시 생성"""
        self._frame_surface = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        # 배경 (어두운 석조)
        self._frame_surface.fill(self.COLORS['dark_stone'])

        # 게임 영역 투명하게 (구멍 뚫기)
        pygame.draw.rect(self._frame_surface, (0, 0, 0, 0),
                        (self.game_x, self.game_y, self.game_width, self.game_height))

        # 좌측 필러 그리기
        self._draw_pillar_column(self._frame_surface, 0, self.game_x, 'left')
        # 우측 필러 그리기
        self._draw_pillar_column(self._frame_surface, self.game_x + self.game_width,
                                self.screen_width - self.game_x - self.game_width, 'right')

        # 상단/하단 테두리
        self._draw_horizontal_border(self._frame_surface, 'top')
        self._draw_horizontal_border(self._frame_surface, 'bottom')

    def _draw_pillar_column(self, surface, x_start, width, side):
        """필러 기둥 그리기"""
        stone = self.COLORS['stone']
        dark = self.COLORS['dark_stone']
        light = self.COLORS['light_stone']
        gold = self.COLORS['gold']

        # 기본 배경
        pygame.draw.rect(surface, stone, (x_start, 0, width, self.screen_height))

        # 세로 기둥 효과 (3D 느낌)
        column_width = width * 0.6
        column_x = x_start + (width - column_width) // 2

        # 기둥 메인
        pygame.draw.rect(surface, light, (column_x, 30, column_width, self.screen_height - 60))

        # 기둥 그림자 (왼쪽)
        shadow_width = 8
        pygame.draw.rect(surface, dark, (column_x, 30, shadow_width, self.screen_height - 60))

        # 기둥 하이라이트 (오른쪽)
        pygame.draw.rect(surface, (200, 190, 175),
                        (column_x + column_width - 6, 30, 6, self.screen_height - 60))

        # 기둥 머리 (상단 장식)
        cap_h = 40
        pygame.draw.rect(surface, light, (x_start + 5, 20, width - 10, cap_h))
        pygame.draw.rect(surface, gold, (x_start + 8, 25, width - 16, 5))

        # 기둥 베이스 (하단 장식)
        pygame.draw.rect(surface, light,
                        (x_start + 5, self.screen_height - 60, width - 10, cap_h))
        pygame.draw.rect(surface, gold,
                        (x_start + 8, self.screen_height - 55, width - 16, 5))

        # 기둥 세로 홈 (채널링)
        groove_count = 3
        groove_width = 4
        for i in range(groove_count):
            gx = column_x + 15 + i * (column_width - 30) // (groove_count - 1) if groove_count > 1 else column_x + column_width // 2
            pygame.draw.line(surface, dark, (gx, 70), (gx, self.screen_height - 90), groove_width)

        # 월계수 장식 (중앙에 작은 장식)
        laurel_y = self.screen_height // 2
        self._draw_laurel_wreath(surface, x_start + width // 2, laurel_y, 20)

    def _draw_laurel_wreath(self, surface, cx, cy, radius):
        """월계수 화관 그리기"""
        laurel = self.COLORS['laurel']
        gold = self.COLORS['gold']

        # 원형 베이스
        pygame.draw.circle(surface, gold, (cx, cy), radius + 3, 2)

        # 잎사귀들
        leaf_count = 12
        for i in range(leaf_count):
            angle = (i / leaf_count) * math.pi * 2
            lx = cx + int(radius * math.cos(angle))
            ly = cy + int(radius * math.sin(angle))

            # 잎 모양 (타원)
            leaf_surf = pygame.Surface((12, 6), pygame.SRCALPHA)
            pygame.draw.ellipse(leaf_surf, laurel, (0, 0, 12, 6))

            # 회전
            rotated = pygame.transform.rotate(leaf_surf, -math.degrees(angle))
            rect = rotated.get_rect(center=(lx, ly))
            surface.blit(rotated, rect)

    def _draw_horizontal_border(self, surface, position):
        """상단/하단 테두리 그리기"""
        stone = self.COLORS['stone']
        gold = self.COLORS['gold']
        dark = self.COLORS['dark_stone']

        if position == 'top':
            y = 0
            h = self.game_y
        else:
            y = self.game_y + self.game_height
            h = self.screen_height - y

        # 기본 배경
        pygame.draw.rect(surface, stone, (self.game_x, y, self.game_width, h))

        # 금색 라인
        if position == 'top':
            pygame.draw.rect(surface, gold, (self.game_x, self.game_y - 5, self.game_width, 5))
            pygame.draw.rect(surface, dark, (self.game_x, self.game_y - 8, self.game_width, 3))
        else:
            pygame.draw.rect(surface, gold, (self.game_x, y, self.game_width, 5))
            pygame.draw.rect(surface, dark, (self.game_x, y + 5, self.game_width, 3))

    def update(self, dt: float, player_rect=None):
        """업데이트"""
        self.time += dt
        self._gladiator_animation_timer += dt

        # 횃불 업데이트
        for torch in self.torches:
            torch['intensity'] = 0.7 + 0.3 * math.sin(self.time * 8 + torch['flicker_phase'])
            torch['flame_height'] = 28 + 7 * math.sin(self.time * 6 + torch['flicker_phase'])

        # 먼지 파티클 업데이트
        for particle in self.dust_particles:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1

            if particle['life'] <= 0:
                # 재생성
                idx = self.dust_particles.index(particle)
                side = particle['side']
                if side == 'left':
                    particle['x'] = random.randint(5, self.game_x - 5)
                else:
                    particle['x'] = random.randint(self.game_x + self.game_width + 5,
                                                   self.screen_width - 5)
                particle['y'] = random.randint(50, self.screen_height - 50)
                particle['life'] = random.randint(200, 400)
                particle['alpha'] = random.randint(30, 60)

    def draw(self, screen: pygame.Surface):
        """프레임 그리기"""
        # 캐시된 프레임
        if self._frame_surface:
            screen.blit(self._frame_surface, (0, 0))

        # 횃불 (애니메이션)
        for torch in self.torches:
            self._draw_torch(screen, torch)

        # 먼지 파티클
        for particle in self.dust_particles:
            color = (180, 160, 130)
            pygame.draw.circle(screen, color, (int(particle['x']), int(particle['y'])),
                             int(particle['size']))

    def _draw_torch(self, screen, torch):
        """횃불 그리기"""
        tx, ty = int(torch['x']), int(torch['y'])
        intensity = torch['intensity']
        flame_h = int(torch['flame_height'])

        # 횃불 받침대
        holder_color = (60, 50, 40)
        pygame.draw.rect(screen, holder_color, (tx - 5, ty, 10, 25))

        # 외부 불꽃
        outer_color = (255, int(120 * intensity), 0)
        points = [
            (tx, ty),
            (tx - 10, ty - flame_h // 2),
            (tx, ty - flame_h),
            (tx + 10, ty - flame_h // 2)
        ]
        pygame.draw.polygon(screen, outer_color, points)

        # 내부 불꽃
        inner_color = (255, int(220 * intensity), int(100 * intensity))
        inner_h = int(flame_h * 0.6)
        inner_points = [
            (tx, ty - 5),
            (tx - 5, ty - flame_h // 3),
            (tx, ty - inner_h),
            (tx + 5, ty - flame_h // 3)
        ]
        pygame.draw.polygon(screen, inner_color, inner_points)

        # 글로우 효과
        glow_radius = int(40 * intensity)
        glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
        for r in range(glow_radius, 0, -3):
            alpha = int(25 * (r / glow_radius) * intensity)
            pygame.draw.circle(glow_surf, (255, 150, 50, alpha),
                             (glow_radius, glow_radius), r)
        screen.blit(glow_surf, (tx - glow_radius, ty - flame_h - glow_radius),
                   special_flags=pygame.BLEND_ADD)

    def draw_foreground(self, screen: pygame.Surface):
        """전경 효과 (게임 위에 그려짐)"""
        # 게임 영역 주변 비네팅 효과
        vignette_size = 30

        # 상단 그림자
        for i in range(vignette_size):
            alpha = int(60 * (1 - i / vignette_size))
            pygame.draw.line(screen, (0, 0, 0),
                           (self.game_x, self.game_y + i),
                           (self.game_x + self.game_width, self.game_y + i))

        # 하단 그림자
        for i in range(vignette_size):
            alpha = int(60 * (i / vignette_size))
            pygame.draw.line(screen, (0, 0, 0),
                           (self.game_x, self.game_y + self.game_height - vignette_size + i),
                           (self.game_x + self.game_width, self.game_y + self.game_height - vignette_size + i))
