# -*- coding: utf-8 -*-
"""
용 기둥 애니메이션 효과 (Dragon Pillar Animator)
은은하고 세련된 버전 - 배경을 방해하지 않는 미묘한 효과
"""

import pygame
import random
import math


class DragonPillarAnimator:
    """
    한국 전통 용 기둥 배경을 위한 은은한 애니메이션 효과

    효과 목록:
    1. 용 비늘 반짝임 - 작은 별 모양 파티클
    2. 신비로운 안개 - 하단에 은은한 안개
    3. 황금 테두리 맥동 - 게임 영역 경계선 빛남
    """

    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.timer = 0.0

        # --- 1. 비늘 반짝임 (작은 별 파티클) ---
        self.sparkles = []
        self.sparkle_spawn_rate = 0.08  # 8% 확률 (적당히)

        # --- 2. 신비로운 안개 (은은하게) ---
        self.fog_particles = []
        self.fog_color = (80, 50, 120)  # 어두운 보라색
        self._init_fog()

    def _init_fog(self):
        """안개 초기 생성 - 작고 은은하게"""
        for _ in range(8):  # 적은 개수
            self.fog_particles.append({
                'x': random.randint(0, self.width),
                'y': random.randint(self.height - 100, self.height),
                'size': random.randint(20, 40),  # 작게
                'speed': random.uniform(3, 8),
                'offset': random.uniform(0, 6.28)
            })

    def update(self, dt):
        """애니메이션 업데이트"""
        self.timer += dt

        # --- 반짝임 업데이트 ---
        if random.random() < self.sparkle_spawn_rate:
            self.sparkles.append({
                'x': random.randint(10, self.width - 10),
                'y': random.randint(50, self.height - 100),
                'timer': 0,
                'max_life': random.uniform(0.5, 1.0),
                'size': random.randint(2, 4)  # 작은 크기
            })

        # 반짝임 갱신
        for s in self.sparkles[:]:
            s['timer'] += dt
            if s['timer'] >= s['max_life']:
                self.sparkles.remove(s)

        # --- 안개 업데이트 ---
        for f in self.fog_particles:
            f['x'] += f['speed'] * dt
            if f['x'] > self.width + f['size']:
                f['x'] = -f['size']

    def draw(self, surface, pillar_rect):
        """효과 그리기"""
        ox, oy = pillar_rect.x, pillar_rect.y

        # --- 1. 반짝임 그리기 (작은 별) ---
        for s in self.sparkles:
            life_pct = s['timer'] / s['max_life']

            # 페이드 인/아웃
            if life_pct < 0.3:
                alpha = int(life_pct / 0.3 * 200)
            elif life_pct > 0.7:
                alpha = int((1 - life_pct) / 0.3 * 200)
            else:
                alpha = 200

            # 작은 십자 모양 별
            size = s['size']
            cx, cy = ox + s['x'], oy + s['y']
            color = (255, 230, 180, alpha)

            # 십자선
            pygame.draw.line(surface, color, (cx - size, cy), (cx + size, cy), 1)
            pygame.draw.line(surface, color, (cx, cy - size), (cx, cy + size), 1)

            # 중심점
            if alpha > 100:
                pygame.draw.circle(surface, (255, 255, 255, min(alpha, 150)), (cx, cy), 1)

        # --- 2. 안개 그리기 (은은하게) ---
        for f in self.fog_particles:
            pulse = (math.sin(self.timer * 1.5 + f['offset']) + 1) / 2
            alpha = int(15 + 15 * pulse)  # 15~30 범위 (매우 은은)

            pygame.draw.circle(
                surface,
                (*self.fog_color, alpha),
                (int(ox + f['x']), int(oy + f['y'])),
                f['size']
            )

        # --- 3. 황금 테두리 맥동 (게임 영역 쪽 가장자리) ---
        self._draw_golden_edge(surface, pillar_rect)

    def _draw_golden_edge(self, surface, pillar_rect):
        """게임 영역 쪽 가장자리에 은은한 황금빛"""
        ox, oy = pillar_rect.x, pillar_rect.y

        # 맥동
        pulse = (math.sin(self.timer * 2) + 1) / 2
        base_alpha = int(30 + 40 * pulse)  # 30~70 범위

        # 왼쪽 필러의 오른쪽 가장자리 OR 오른쪽 필러의 왼쪽 가장자리
        # 필러 위치에 따라 결정
        if ox < 100:  # 왼쪽 필러
            edge_x = ox + self.width - 2
        else:  # 오른쪽 필러
            edge_x = ox + 1

        # 그라데이션 선 (3픽셀 너비)
        for i in range(3):
            line_alpha = int(base_alpha * (1 - i * 0.3))
            if line_alpha > 0:
                color = (255, 200, 100, line_alpha)
                if ox < 100:
                    pygame.draw.line(surface, color,
                                   (edge_x - i, oy + 30),
                                   (edge_x - i, oy + self.height - 30), 1)
                else:
                    pygame.draw.line(surface, color,
                                   (edge_x + i, oy + 30),
                                   (edge_x + i, oy + self.height - 30), 1)


# 싱글톤 인스턴스 관리
_left_animator = None
_right_animator = None


def get_dragon_animators(left_width, left_height, right_width, right_height):
    """좌우 필러용 애니메이터 인스턴스 반환"""
    global _left_animator, _right_animator

    if _left_animator is None or _left_animator.width != left_width:
        _left_animator = DragonPillarAnimator(left_width, left_height)

    if _right_animator is None or _right_animator.width != right_width:
        _right_animator = DragonPillarAnimator(right_width, right_height)

    return _left_animator, _right_animator


def reset_dragon_animators():
    """애니메이터 초기화"""
    global _left_animator, _right_animator
    _left_animator = None
    _right_animator = None
