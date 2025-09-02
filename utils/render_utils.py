"""
렌더링 관련 유틸리티 함수
중복 코드 제거를 위한 렌더링 헬퍼
"""
import pygame
import math
import random

def draw_gradient_background(surface, start_color, end_color, width, height):
    """그라데이션 배경 그리기"""
    for y in range(height):
        ratio = y / height
        r = int(start_color[0] + ratio * (end_color[0] - start_color[0]))
        g = int(start_color[1] + ratio * (end_color[1] - start_color[1]))
        b = int(start_color[2] + ratio * (end_color[2] - start_color[2]))
        pygame.draw.line(surface, (r, g, b), (0, y), (width, y))

def draw_grid_pattern(surface, color, width, height, grid_size=30):
    """격자 패턴 그리기"""
    for x in range(0, width, grid_size):
        pygame.draw.line(surface, color, (x, 0), (x, height), 1)
    for y in range(0, height, grid_size):
        pygame.draw.line(surface, color, (0, y), (width, y), 1)

def draw_scanlines(surface, color, width, height, spacing=2, alpha=30):
    """스캔라인 효과"""
    scanline_surface = pygame.Surface((width, height), pygame.SRCALPHA)
    for y in range(0, height, spacing):
        pygame.draw.line(scanline_surface, (*color, alpha), (0, y), (width, y))
    surface.blit(scanline_surface, (0, 0))

def create_cyberpunk_background(width, height):
    """사이버펑크 스타일 배경 생성"""
    surface = pygame.Surface((width, height))
    # 그라데이션
    draw_gradient_background(surface, (10, 20, 50), (30, 70, 50), width, height)
    # 격자
    draw_grid_pattern(surface, (0, 255, 255, 50), width, height, 40)
    # 스캔라인
    draw_scanlines(surface, (0, 255, 0), width, height, 2, 20)
    return surface

def create_fire_background(width, height):
    """불꽃 스타일 배경 생성"""
    surface = pygame.Surface((width, height))
    draw_gradient_background(surface, (50, 0, 0), (255, 100, 0), width, height)
    return surface

def create_ice_background(width, height):
    """얼음 스타일 배경 생성"""
    surface = pygame.Surface((width, height))
    draw_gradient_background(surface, (100, 150, 200), (200, 230, 255), width, height)
    return surface

def create_electric_background(width, height):
    """전기 스타일 배경 생성"""
    surface = pygame.Surface((width, height))
    draw_gradient_background(surface, (20, 0, 40), (100, 50, 150), width, height)
    return surface

def create_shadow_background(width, height):
    """그림자 스타일 배경 생성"""
    surface = pygame.Surface((width, height))
    draw_gradient_background(surface, (10, 10, 10), (30, 30, 30), width, height)
    return surface

def draw_glow_effect(surface, pos, radius, color, intensity=0.5):
    """빛나는 효과 그리기"""
    glow_surface = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
    for i in range(radius, 0, -2):
        alpha = int((1 - i/radius) * 255 * intensity)
        pygame.draw.circle(glow_surface, (*color, alpha), (radius, radius), i)
    surface.blit(glow_surface, (pos[0] - radius, pos[1] - radius), special_flags=pygame.BLEND_ADD)

def draw_particle(surface, x, y, size, color, alpha=255):
    """파티클 그리기"""
    particle_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
    pygame.draw.circle(particle_surface, (*color, alpha), (size, size), size)
    surface.blit(particle_surface, (x - size, y - size))

def draw_trail_effect(surface, positions, color, max_alpha=255, width=3):
    """잔상 효과 그리기"""
    if len(positions) < 2:
        return
    
    for i in range(1, len(positions)):
        alpha = int((i / len(positions)) * max_alpha)
        start_pos = positions[i-1]
        end_pos = positions[i]
        
        # 알파 블렌딩을 위한 임시 서페이스
        temp = pygame.Surface((abs(end_pos[0] - start_pos[0]) + width, 
                              abs(end_pos[1] - start_pos[1]) + width), pygame.SRCALPHA)
        pygame.draw.line(temp, (*color, alpha), 
                        (0, 0), 
                        (end_pos[0] - start_pos[0], end_pos[1] - start_pos[1]), 
                        width)
        surface.blit(temp, start_pos)