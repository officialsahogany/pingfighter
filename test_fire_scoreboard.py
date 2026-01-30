# -*- coding: utf-8 -*-
"""화염 점수판 스타일 미리보기 테스트 - 이글이글 버전"""

import pygame
import math
import sys
import os
import random

pygame.init()

# 화면 설정
SCREEN_WIDTH = 1200
SCREEN_HEIGHT = 500
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("🔥 이글이글 Fire Scoreboard Styles Preview 🔥")

clock = pygame.time.Clock()

# 파티클 시스템
class FireParticle:
    def __init__(self, x, y, style=0):
        self.x = x
        self.y = y
        self.style = style
        self.vx = random.uniform(-1, 1)
        self.vy = random.uniform(-3, -1)
        self.life = random.uniform(0.5, 1.0)
        self.max_life = self.life
        self.size = random.uniform(2, 6)

    def update(self, dt):
        self.x += self.vx * dt * 60
        self.y += self.vy * dt * 60
        self.vy -= 0.05  # 위로 가속
        self.vx += random.uniform(-0.1, 0.1)  # 흔들림
        self.life -= dt

    def draw(self, screen):
        if self.life <= 0:
            return
        ratio = self.life / self.max_life
        size = int(self.size * ratio)
        if size < 1:
            return

        alpha = int(255 * ratio)

        # 색상 (수명에 따라 노랑 → 주황 → 빨강)
        if ratio > 0.6:
            r, g, b = 255, 255, int(150 * (ratio - 0.6) / 0.4)
        elif ratio > 0.3:
            r, g, b = 255, int(150 + 105 * (ratio - 0.3) / 0.3), 0
        else:
            r, g, b = int(255 * ratio / 0.3), int(80 * ratio / 0.3), 0

        # 글로우 효과
        glow_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (r, g, 0, alpha // 4), (size * 2, size * 2), size * 2)
        pygame.draw.circle(glow_surf, (r, g, b, alpha // 2), (size * 2, size * 2), size + 1)
        pygame.draw.circle(glow_surf, (255, 255, 200, alpha), (size * 2, size * 2), size)
        screen.blit(glow_surf, (int(self.x - size * 2), int(self.y - size * 2)))


# 각 스타일별 파티클 리스트
particles = {i: [] for i in range(5)}


def spawn_particles(style, x, y, width, count=3):
    """화염 파티클 생성"""
    for _ in range(count):
        px = x + random.uniform(5, width - 5)
        py = y + random.uniform(-5, 5)
        particles[style].append(FireParticle(px, py, style))


def update_particles(dt):
    """모든 파티클 업데이트"""
    for style in particles:
        particles[style] = [p for p in particles[style] if p.life > 0]
        for p in particles[style]:
            p.update(dt)


def draw_style_1(screen, x, y, width, height, time_ms):
    """스타일 1: 맹렬한 화염 - 격렬하게 타오르는 불"""
    # 외곽 열기 글로우 (강렬하게)
    for glow_layer in range(5):
        glow_margin = 20 - glow_layer * 3
        glow_surface = pygame.Surface((width + glow_margin * 2, height + glow_margin * 2), pygame.SRCALPHA)
        pulse = math.sin(time_ms * 0.008) * 0.3 + 0.7
        glow_alpha = int((40 - glow_layer * 7) * pulse)
        pygame.draw.rect(glow_surface, (255, 50 + glow_layer * 20, 0, glow_alpha),
                        glow_surface.get_rect(), border_radius=12)
        screen.blit(glow_surface, (x - glow_margin, y - glow_margin))

    box_surface = pygame.Surface((width, height), pygame.SRCALPHA)

    # 격렬한 화염 그라데이션
    for i in range(height):
        ratio = i / height
        # 빠르고 불규칙한 파동
        wave1 = math.sin(time_ms * 0.012 + ratio * 8) * 0.15
        wave2 = math.sin(time_ms * 0.018 + ratio * 12 + 2) * 0.1
        wave3 = math.sin(time_ms * 0.025 + ratio * 20) * 0.08
        combined = wave1 + wave2 + wave3

        # 강렬한 화염 색상
        if ratio < 0.3:
            r, g, b = 255, int(255 - 55 * ratio / 0.3), int(200 - 150 * ratio / 0.3)
        elif ratio < 0.6:
            r, g, b = 255, int(200 - 100 * (ratio - 0.3) / 0.3), int(50 - 30 * (ratio - 0.3) / 0.3)
        else:
            r, g, b = int(255 - 80 * (ratio - 0.6) / 0.4), int(100 - 70 * (ratio - 0.6) / 0.4), 10

        r = int(min(255, max(0, r + 60 * combined)))
        g = int(min(255, max(0, g + 80 * combined)))
        b = int(min(255, max(0, b + 30 * combined)))

        pygame.draw.line(box_surface, (r, g, b, 245), (0, i), (width, i))

    # 테두리
    pygame.draw.rect(box_surface, (180, 60, 20), (0, 0, width, height), 3, border_radius=8)
    screen.blit(box_surface, (x, y))

    # 맹렬한 상단 화염
    flame_surface = pygame.Surface((width + 20, 60), pygame.SRCALPHA)

    # 다중 레이어 화염
    for layer in range(4):
        layer_height = 45 - layer * 8
        layer_alpha = 200 - layer * 40

        points = [(0, 60)]
        for fx in range(0, width + 21, 2):
            h = layer_height * 0.4
            h += math.sin(time_ms * (0.015 + layer * 0.003) + fx * 0.18) * layer_height * 0.3
            h += math.sin(time_ms * (0.022 + layer * 0.005) + fx * 0.28) * layer_height * 0.2
            h += math.sin(time_ms * (0.035 + layer * 0.008) + fx * 0.45) * layer_height * 0.15
            # 불규칙한 뾰족함 추가
            if random.random() < 0.02:
                h += random.uniform(5, 15)
            points.append((fx, 60 - max(0, h)))
        points.append((width + 20, 60))

        # 화염 색상 (레이어별)
        if layer == 0:
            color = (255, 255, 220, layer_alpha)  # 밝은 중심
        elif layer == 1:
            color = (255, 200, 80, layer_alpha)   # 노랑
        elif layer == 2:
            color = (255, 120, 30, layer_alpha)   # 주황
        else:
            color = (200, 60, 10, layer_alpha)    # 빨강

        pygame.draw.polygon(flame_surface, color, points)

    screen.blit(flame_surface, (x - 10, y - 50))

    # 파티클 생성 및 그리기
    if random.random() < 0.4:
        spawn_particles(0, x, y - 10, width, 2)
    for p in particles[0]:
        p.draw(screen)

    # 점수
    font = pygame.font.Font(None, 42)
    # 떨리는 효과
    shake_x = math.sin(time_ms * 0.02) * 1
    shake_y = math.cos(time_ms * 0.025) * 0.5

    # 글로우
    for gw in range(4, 0, -1):
        glow_text = font.render("4 : 4", True, (255, 100, 0))
        glow_text.set_alpha(int(50 * (5 - gw)))
        glow_rect = glow_text.get_rect(center=(x + width // 2 + shake_x, y + height // 2 + shake_y))
        for ox, oy in [(-gw, 0), (gw, 0), (0, -gw), (0, gw)]:
            screen.blit(glow_text, (glow_rect.x + ox, glow_rect.y + oy))

    text = font.render("4 : 4", True, (255, 255, 230))
    shadow = font.render("4 : 4", True, (100, 30, 5))
    text_rect = text.get_rect(center=(x + width // 2 + shake_x, y + height // 2 + shake_y))
    screen.blit(shadow, (text_rect.x + 2, text_rect.y + 2))
    screen.blit(text, text_rect)

    # 라벨
    label_font = pygame.font.Font(None, 22)
    label = label_font.render("Style 1: Raging Inferno", True, (255, 200, 100))
    screen.blit(label, (x, y + height + 15))


def draw_style_2(screen, x, y, width, height, time_ms):
    """스타일 2: 폭발 화염 - 폭발하듯 타오르는"""
    # 폭발적 글로우
    pulse = abs(math.sin(time_ms * 0.006)) ** 0.5
    for glow_layer in range(6):
        glow_margin = 25 - glow_layer * 4
        glow_surface = pygame.Surface((width + glow_margin * 2, height + glow_margin * 2), pygame.SRCALPHA)
        glow_alpha = int((50 - glow_layer * 8) * pulse)
        color_shift = int(glow_layer * 15)
        pygame.draw.rect(glow_surface, (255, 80 + color_shift, 0, glow_alpha),
                        glow_surface.get_rect(), border_radius=10 + glow_layer)
        screen.blit(glow_surface, (x - glow_margin, y - glow_margin))

    box_surface = pygame.Surface((width, height), pygame.SRCALPHA)

    # 폭발적인 중심 → 외곽 그라데이션
    center_y = height // 2
    for i in range(height):
        dist_from_center = abs(i - center_y) / (height / 2)

        wave = math.sin(time_ms * 0.01 + i * 0.15) * 0.12

        # 중심이 가장 밝음
        brightness = 1 - dist_from_center * 0.5

        if dist_from_center < 0.3:
            r, g, b = 255, int(255 * brightness), int(200 * brightness)
        elif dist_from_center < 0.6:
            r, g, b = 255, int(180 * brightness), int(50 * brightness)
        else:
            r, g, b = int(255 * brightness), int(100 * brightness), int(20 * brightness)

        r = int(min(255, max(0, r + 50 * wave)))
        g = int(min(255, max(0, g + 70 * wave)))

        pygame.draw.line(box_surface, (r, g, b, 250), (0, i), (width, i))

    pygame.draw.rect(box_surface, (200, 80, 20), (0, 0, width, height), 3, border_radius=6)
    screen.blit(box_surface, (x, y))

    # 상하 화염 (위아래로 뿜어져 나오는)
    for direction in [-1, 1]:  # 위, 아래
        flame_y = y - 5 if direction == -1 else y + height - 5

        flame_surface = pygame.Surface((width, 50), pygame.SRCALPHA)

        for fx in range(0, width, 3):
            flame_h = 25 + math.sin(time_ms * 0.012 + fx * 0.2) * 15
            flame_h += math.sin(time_ms * 0.02 + fx * 0.35) * 10

            for fh in range(int(flame_h)):
                ratio = fh / flame_h
                alpha = int(200 * (1 - ratio) ** 1.2)

                if ratio < 0.4:
                    color = (255, 255, int(200 - 150 * ratio / 0.4), alpha)
                elif ratio < 0.7:
                    color = (255, int(200 - 100 * (ratio - 0.4) / 0.3), 50, alpha)
                else:
                    color = (int(255 - 80 * (ratio - 0.7) / 0.3), int(100 - 60 * (ratio - 0.7) / 0.3), 20, alpha)

                fy = fh if direction == -1 else 50 - fh
                pygame.draw.circle(flame_surface, color, (fx, fy), max(1, int(3 * (1 - ratio))))

        if direction == -1:
            screen.blit(flame_surface, (x, y - 45))
        else:
            screen.blit(pygame.transform.flip(flame_surface, False, True), (x, y + height - 5))

    # 폭발 파티클
    if random.random() < 0.5:
        spawn_particles(1, x, y - 10, width, 3)
    for p in particles[1]:
        p.draw(screen)

    # 점수
    font = pygame.font.Font(None, 44)
    scale_pulse = 1 + math.sin(time_ms * 0.008) * 0.05

    text = font.render("4 : 4", True, (255, 255, 240))
    shadow = font.render("4 : 4", True, (120, 40, 10))

    # 스케일 효과 (흉내)
    text_rect = text.get_rect(center=(x + width // 2, y + height // 2))
    screen.blit(shadow, (text_rect.x + 2, text_rect.y + 2))
    screen.blit(text, text_rect)

    label_font = pygame.font.Font(None, 22)
    label = label_font.render("Style 2: Explosive Burst", True, (255, 200, 100))
    screen.blit(label, (x, y + height + 15))


def draw_style_3(screen, x, y, width, height, time_ms):
    """스타일 3: 지옥불 - 어둡고 강렬한 화염"""
    # 어두운 글로우 (빨강/자주색)
    for glow_layer in range(4):
        glow_margin = 18 - glow_layer * 4
        glow_surface = pygame.Surface((width + glow_margin * 2, height + glow_margin * 2), pygame.SRCALPHA)
        pulse = 0.7 + 0.3 * math.sin(time_ms * 0.004 + glow_layer)
        glow_alpha = int((35 - glow_layer * 8) * pulse)
        pygame.draw.rect(glow_surface, (180, 30, 60, glow_alpha),
                        glow_surface.get_rect(), border_radius=10)
        screen.blit(glow_surface, (x - glow_margin, y - glow_margin))

    box_surface = pygame.Surface((width, height), pygame.SRCALPHA)

    # 어두운 화염 그라데이션
    for i in range(height):
        ratio = i / height
        wave = math.sin(time_ms * 0.008 + ratio * 10) * 0.1
        wave += math.sin(time_ms * 0.015 + ratio * 15) * 0.07

        # 어두운 빨강/자주 톤
        if ratio < 0.3:
            r = int(200 + 55 * wave)
            g = int(80 - 50 * ratio / 0.3 + 30 * wave)
            b = int(100 - 60 * ratio / 0.3)
        elif ratio < 0.6:
            r = int(180 - 40 * (ratio - 0.3) / 0.3 + 40 * wave)
            g = int(30 + 20 * wave)
            b = int(40 + 30 * wave)
        else:
            r = int(140 - 80 * (ratio - 0.6) / 0.4 + 30 * wave)
            g = int(20 + 15 * wave)
            b = int(30 + 20 * wave)

        r = min(255, max(0, r))
        g = min(255, max(0, g))
        b = min(255, max(0, b))

        pygame.draw.line(box_surface, (r, g, b, 240), (0, i), (width, i))

    # 어두운 테두리
    pygame.draw.rect(box_surface, (100, 20, 40), (0, 0, width, height), 3, border_radius=8)
    pygame.draw.rect(box_surface, (200, 60, 80, 100), (2, 2, width - 4, height - 4), 1, border_radius=6)
    screen.blit(box_surface, (x, y))

    # 지옥불 화염 (어둡고 뾰족한)
    flame_surface = pygame.Surface((width + 10, 55), pygame.SRCALPHA)

    for layer in range(3):
        points = [(0, 55)]
        for fx in range(0, width + 11, 2):
            h = 35 - layer * 10
            h += math.sin(time_ms * 0.01 + fx * 0.22 + layer) * 12
            h += math.sin(time_ms * 0.018 + fx * 0.35 + layer * 2) * 8
            # 뾰족한 형태
            spike = (math.sin(time_ms * 0.008 + fx * 0.5) + 1) / 2
            h += spike ** 3 * 15
            points.append((fx, 55 - max(0, h)))
        points.append((width + 10, 55))

        if layer == 0:
            color = (255, 150, 100, 180)
        elif layer == 1:
            color = (220, 60, 80, 150)
        else:
            color = (150, 30, 60, 120)

        pygame.draw.polygon(flame_surface, color, points)

    screen.blit(flame_surface, (x - 5, y - 48))

    # 어두운 파티클
    if random.random() < 0.3:
        spawn_particles(2, x, y - 10, width, 2)
    for p in particles[2]:
        p.draw(screen)

    # 점수 (어두운 글로우)
    font = pygame.font.Font(None, 42)

    for gw in range(3, 0, -1):
        glow_text = font.render("4 : 4", True, (200, 50, 70))
        glow_text.set_alpha(int(40 * (4 - gw)))
        glow_rect = glow_text.get_rect(center=(x + width // 2, y + height // 2))
        for ox, oy in [(-gw, 0), (gw, 0), (0, -gw), (0, gw)]:
            screen.blit(glow_text, (glow_rect.x + ox, glow_rect.y + oy))

    text = font.render("4 : 4", True, (255, 220, 200))
    shadow = font.render("4 : 4", True, (60, 10, 20))
    text_rect = text.get_rect(center=(x + width // 2, y + height // 2))
    screen.blit(shadow, (text_rect.x + 2, text_rect.y + 2))
    screen.blit(text, text_rect)

    label_font = pygame.font.Font(None, 22)
    label = label_font.render("Style 3: Hellfire", True, (255, 150, 150))
    screen.blit(label, (x, y + height + 15))


def draw_style_4(screen, x, y, width, height, time_ms):
    """스타일 4: 용광로 - 녹아내리는 듯한 강렬한 열기"""
    # 강렬한 열기 글로우
    for glow_layer in range(5):
        glow_margin = 22 - glow_layer * 4
        glow_surface = pygame.Surface((width + glow_margin * 2, height + glow_margin * 2), pygame.SRCALPHA)
        pulse = 0.8 + 0.2 * math.sin(time_ms * 0.005)
        glow_alpha = int((45 - glow_layer * 9) * pulse)
        pygame.draw.rect(glow_surface, (255, 120, 30, glow_alpha),
                        glow_surface.get_rect(), border_radius=8 + glow_layer * 2)
        screen.blit(glow_surface, (x - glow_margin, y - glow_margin))

    box_surface = pygame.Surface((width, height), pygame.SRCALPHA)

    # 녹아내리는 그라데이션 (위가 가장 밝음)
    for i in range(height):
        ratio = i / height

        # 천천히 흐르는 효과
        flow = math.sin(time_ms * 0.003 + ratio * 6) * 0.08
        flow += math.sin(time_ms * 0.005 + ratio * 10) * 0.05

        # 용광로 색상 (흰색 → 노랑 → 주황 → 빨강)
        if ratio < 0.2:
            r, g, b = 255, 255, int(250 - 100 * ratio / 0.2)
        elif ratio < 0.4:
            r, g, b = 255, int(255 - 55 * (ratio - 0.2) / 0.2), int(150 - 100 * (ratio - 0.2) / 0.2)
        elif ratio < 0.7:
            r, g, b = 255, int(200 - 120 * (ratio - 0.4) / 0.3), int(50 - 30 * (ratio - 0.4) / 0.3)
        else:
            r, g, b = int(255 - 60 * (ratio - 0.7) / 0.3), int(80 - 50 * (ratio - 0.7) / 0.3), 20

        r = int(min(255, max(0, r + 40 * flow)))
        g = int(min(255, max(0, g + 60 * flow)))

        pygame.draw.line(box_surface, (r, g, b, 250), (0, i), (width, i))

    # 녹아내리는 방울 효과
    for drop_x in range(10, width - 10, 20):
        drop_phase = (time_ms * 0.002 + drop_x * 0.1) % 1.0
        drop_y = int(drop_phase * height)
        drop_size = int(4 * (1 - drop_phase * 0.5))
        if drop_size > 0:
            pygame.draw.circle(box_surface, (255, 200, 100, int(200 * (1 - drop_phase))),
                             (drop_x, drop_y), drop_size)

    pygame.draw.rect(box_surface, (200, 100, 30), (0, 0, width, height), 3, border_radius=6)
    screen.blit(box_surface, (x, y))

    # 열기 (상단 아지랑이 + 화염)
    heat_surface = pygame.Surface((width, 50), pygame.SRCALPHA)

    for layer in range(4):
        points = [(0, 50)]
        for fx in range(0, width + 1, 2):
            h = 35 - layer * 7
            h += math.sin(time_ms * 0.008 + fx * 0.15 + layer * 0.5) * 10
            h += math.sin(time_ms * 0.015 + fx * 0.25 + layer) * 7
            h += math.sin(time_ms * 0.025 + fx * 0.4) * 5
            points.append((fx, 50 - max(0, h)))
        points.append((width, 50))

        if layer == 0:
            color = (255, 255, 230, 200)
        elif layer == 1:
            color = (255, 220, 120, 170)
        elif layer == 2:
            color = (255, 150, 50, 140)
        else:
            color = (255, 100, 30, 110)

        pygame.draw.polygon(heat_surface, color, points)

    screen.blit(heat_surface, (x, y - 45))

    # 파티클
    if random.random() < 0.45:
        spawn_particles(3, x, y - 10, width, 2)
    for p in particles[3]:
        p.draw(screen)

    # 점수
    font = pygame.font.Font(None, 44)

    # 열기로 인한 미세한 떨림
    heat_shake_x = math.sin(time_ms * 0.03) * 0.8
    heat_shake_y = math.cos(time_ms * 0.035) * 0.5

    # 밝은 글로우
    for gw in range(5, 0, -1):
        glow_text = font.render("4 : 4", True, (255, 180, 80))
        glow_text.set_alpha(int(35 * (6 - gw)))
        glow_rect = glow_text.get_rect(center=(x + width // 2 + heat_shake_x, y + height // 2 + heat_shake_y))
        for ox, oy in [(-gw, 0), (gw, 0), (0, -gw), (0, gw)]:
            screen.blit(glow_text, (glow_rect.x + ox, glow_rect.y + oy))

    text = font.render("4 : 4", True, (255, 255, 250))
    shadow = font.render("4 : 4", True, (140, 50, 10))
    text_rect = text.get_rect(center=(x + width // 2 + heat_shake_x, y + height // 2 + heat_shake_y))
    screen.blit(shadow, (text_rect.x + 2, text_rect.y + 2))
    screen.blit(text, text_rect)

    label_font = pygame.font.Font(None, 22)
    label = label_font.render("Style 4: Furnace", True, (255, 220, 150))
    screen.blit(label, (x, y + height + 15))


def draw_style_5(screen, x, y, width, height, time_ms):
    """스타일 5: 태양 플레어 - 태양처럼 맹렬하게 타오르는"""
    # 코로나 글로우 (태양 같은)
    for glow_layer in range(7):
        glow_margin = 30 - glow_layer * 4
        glow_surface = pygame.Surface((width + glow_margin * 2, height + glow_margin * 2), pygame.SRCALPHA)
        pulse = 0.6 + 0.4 * math.sin(time_ms * 0.003 + glow_layer * 0.5)
        glow_alpha = int((30 - glow_layer * 4) * pulse)

        # 태양 색상 (중심 = 흰색, 외곽 = 주황/빨강)
        color_r = 255
        color_g = max(0, 200 - glow_layer * 25)
        color_b = max(0, 100 - glow_layer * 15)

        pygame.draw.rect(glow_surface, (color_r, color_g, color_b, glow_alpha),
                        glow_surface.get_rect(), border_radius=12 + glow_layer * 2)
        screen.blit(glow_surface, (x - glow_margin, y - glow_margin))

    box_surface = pygame.Surface((width, height), pygame.SRCALPHA)

    # 태양 표면 그라데이션 (중심에서 외곽으로)
    center_x, center_y = width // 2, height // 2
    max_dist = math.sqrt(center_x ** 2 + center_y ** 2)

    for i in range(height):
        for j in range(width):
            dist = math.sqrt((j - center_x) ** 2 + (i - center_y) ** 2)
            ratio = min(1, dist / max_dist)

            # 태양 패턴
            angle = math.atan2(i - center_y, j - center_x)
            pattern = math.sin(angle * 8 + time_ms * 0.005) * 0.1
            pattern += math.sin(angle * 12 + time_ms * 0.008) * 0.05

            if ratio < 0.3:
                r, g, b = 255, 255, int(255 - 80 * ratio / 0.3)
            elif ratio < 0.6:
                r = 255
                g = int(255 - 100 * (ratio - 0.3) / 0.3)
                b = int(175 - 125 * (ratio - 0.3) / 0.3)
            else:
                r = int(255 - 30 * (ratio - 0.6) / 0.4)
                g = int(155 - 95 * (ratio - 0.6) / 0.4)
                b = int(50 - 30 * (ratio - 0.6) / 0.4)

            r = int(min(255, max(0, r + 50 * pattern)))
            g = int(min(255, max(0, g + 50 * pattern)))
            b = int(min(255, max(0, b + 30 * pattern)))

            box_surface.set_at((j, i), (r, g, b, 250))

    pygame.draw.rect(box_surface, (255, 180, 80), (0, 0, width, height), 3, border_radius=10)
    screen.blit(box_surface, (x, y))

    # 태양 플레어 (여러 방향으로 뿜어져 나오는)
    flare_surface = pygame.Surface((width + 40, 70), pygame.SRCALPHA)

    # 플레어 아크
    for flare_idx in range(5):
        flare_x = 10 + flare_idx * (width / 4)
        flare_offset = math.sin(time_ms * 0.006 + flare_idx) * 10
        flare_height = 40 + math.sin(time_ms * 0.008 + flare_idx * 1.5) * 20

        # 플레어 아크 그리기
        points = []
        for t in range(20):
            progress = t / 19
            arc_x = flare_x + progress * 20 - 10 + flare_offset * progress
            arc_y = 65 - flare_height * math.sin(progress * math.pi)
            points.append((arc_x, arc_y))

        for i in range(len(points) - 1):
            alpha = int(180 * (1 - abs(i / len(points) - 0.5) * 2))
            pygame.draw.line(flare_surface, (255, 200, 100, alpha),
                           points[i], points[i + 1], 3)
            pygame.draw.line(flare_surface, (255, 255, 200, alpha // 2),
                           points[i], points[i + 1], 1)

    screen.blit(flare_surface, (x - 10, y - 60))

    # 일반 화염도 추가
    flame_surf = pygame.Surface((width, 40), pygame.SRCALPHA)
    for layer in range(3):
        points = [(0, 40)]
        for fx in range(0, width + 1, 2):
            h = 25 - layer * 6
            h += math.sin(time_ms * 0.012 + fx * 0.2 + layer) * 8
            h += math.sin(time_ms * 0.02 + fx * 0.35) * 5
            points.append((fx, 40 - max(0, h)))
        points.append((width, 40))

        if layer == 0:
            color = (255, 255, 200, 180)
        elif layer == 1:
            color = (255, 200, 80, 150)
        else:
            color = (255, 140, 40, 120)

        pygame.draw.polygon(flame_surf, color, points)
    screen.blit(flame_surf, (x, y - 35))

    # 파티클 (밝은 색)
    if random.random() < 0.5:
        spawn_particles(4, x, y - 10, width, 3)
    for p in particles[4]:
        p.draw(screen)

    # 점수
    font = pygame.font.Font(None, 46)

    # 태양 글로우
    for gw in range(6, 0, -1):
        glow_text = font.render("4 : 4", True, (255, 200, 100))
        glow_text.set_alpha(int(30 * (7 - gw)))
        glow_rect = glow_text.get_rect(center=(x + width // 2, y + height // 2))
        for ox, oy in [(-gw, 0), (gw, 0), (0, -gw), (0, gw), (-gw, -gw), (gw, gw), (-gw, gw), (gw, -gw)]:
            screen.blit(glow_text, (glow_rect.x + ox, glow_rect.y + oy))

    text = font.render("4 : 4", True, (255, 255, 255))
    shadow = font.render("4 : 4", True, (180, 80, 20))
    text_rect = text.get_rect(center=(x + width // 2, y + height // 2))
    screen.blit(shadow, (text_rect.x + 2, text_rect.y + 2))
    screen.blit(text, text_rect)

    label_font = pygame.font.Font(None, 22)
    label = label_font.render("Style 5: Solar Flare", True, (255, 255, 200))
    screen.blit(label, (x, y + height + 15))


# 메인 루프
running = True
last_time = pygame.time.get_ticks()

while running:
    current_time = pygame.time.get_ticks()
    dt = (current_time - last_time) / 1000.0
    last_time = current_time

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False

    screen.fill((15, 10, 20))

    time_ms = pygame.time.get_ticks()

    # 파티클 업데이트
    update_particles(dt)

    # 타이틀
    title_font = pygame.font.Font(None, 40)
    title = title_font.render("🔥 BLAZING Fire Scoreboard Styles 🔥 - Press ESC to exit", True, (255, 200, 100))
    screen.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, 25))

    # 5가지 스타일 그리기
    box_width = 150
    box_height = 55
    start_x = 70
    spacing = 225
    base_y = 200

    draw_style_1(screen, start_x, base_y, box_width, box_height, time_ms)
    draw_style_2(screen, start_x + spacing, base_y, box_width, box_height, time_ms)
    draw_style_3(screen, start_x + spacing * 2, base_y, box_width, box_height, time_ms)
    draw_style_4(screen, start_x + spacing * 3, base_y, box_width, box_height, time_ms)
    draw_style_5(screen, start_x + spacing * 4, base_y, box_width, box_height, time_ms)

    # 설명
    desc_font = pygame.font.Font(None, 24)
    descriptions = [
        "Raging Inferno - 격렬하게 타오르는",
        "Explosive Burst - 폭발하듯 뿜어져 나오는",
        "Hellfire - 지옥불처럼 어둡고 강렬한",
        "Furnace - 용광로처럼 녹아내리는",
        "Solar Flare - 태양처럼 맹렬한"
    ]
    for i, desc in enumerate(descriptions):
        desc_text = desc_font.render(desc, True, (200, 200, 200))
        screen.blit(desc_text, (start_x + i * spacing, base_y + box_height + 35))

    pygame.display.flip()
    clock.tick(60)

pygame.quit()
