# -*- coding: utf-8 -*-
"""Test script for holy light particle effects"""

import pygame
import math
import random
import sys

# Initialize Pygame
pygame.init()
SCREEN_WIDTH, SCREEN_HEIGHT = 800, 600
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Holy Light Particle Test - 성스러운 빛 파티클 테스트")

# Global variables
holy_light_particles = []
screen_shake_offset_x = 0
screen_shake_offset_y = 0

# Mock rect class
class MockRect:
    def __init__(self, x, y, w, h):
        self.x = x
        self.y = y
        self.width = w
        self.height = h
        self.centerx = x + w // 2
        self.centery = y + h // 2

def create_holy_light_particles(rect, count=8):
    """반딧불 같은 작은 별빛 파티클 생성"""
    global holy_light_particles
    for i in range(count):
        # 건물 주위를 도는 초기 각도와 거리
        angle = (i / count) * 2 * math.pi
        distance = random.uniform(30, 50)  # 건물에서의 거리
        size = random.uniform(1.5, 3)  # 아주 작은 별빛
        alpha = random.randint(150, 255)
        
        # 별빛 색상들 (따뜻한 노란빛, 하얀빛)
        color = random.choice([
            (255, 255, 200),   # 따뜻한 노란색
            (255, 250, 150),   # 밝은 노란색
            (255, 255, 255),   # 순백색
            (250, 250, 200),   # 연한 노란색
        ])
        
        # 회전 속도 (랜덤하게 설정)
        orbit_speed = random.uniform(0.01, 0.03)
        life = random.randint(180, 300)  # 3~5초
        
        holy_light_particles.append([rect, angle, distance, size, alpha, life, color, orbit_speed])


def update_holy_light_particles():
    """반딧불 별빛 파티클 업데이트"""
    global holy_light_particles
    new_particles = []
    
    for particle in holy_light_particles:
        rect, angle, distance, size, alpha, life, color, orbit_speed = particle
        
        # 각도 업데이트 (회전)
        angle += orbit_speed
        
        # 거리 약간의 변화 (호흡하는 듯한 효과)
        distance += math.sin(angle * 3) * 0.5
        
        # 생명력과 투명도
        life -= 1
        if life > 60:  # 대부분의 시간 동안 밝게 유지
            alpha = min(255, alpha + 2)
        else:  # 마지막에 페이드 아웃
            alpha = int(alpha * 0.97)
        
        # 크기도 약간 변화 (반짝이는 효과)
        size = size * (1 + math.sin(life * 0.1) * 0.2)
        
        if life > 0 and alpha > 10:
            new_particles.append([rect, angle, distance, size, alpha, life, color, orbit_speed])
    
    holy_light_particles = new_particles


def draw_holy_light_particles(surface):
    """반딧불 별빛 파티클 그리기"""
    for particle in holy_light_particles:
        rect, angle, distance, size, alpha, life, color, orbit_speed = particle
        
        # 건물 중심 기준으로 회전하는 위치 계산
        center_x = rect.centerx + screen_shake_offset_x
        center_y = rect.centery + screen_shake_offset_y
        
        x = center_x + math.cos(angle) * distance
        y = center_y + math.sin(angle) * distance
        
        # 작은 별빛 그리기 (여러 레이어로 글로우 효과)
        for i in range(3):
            layer_size = size * (3 - i)
            layer_alpha = alpha // (i + 1)
            if i == 0:
                # 중심은 더 밝게
                layer_alpha = min(255, layer_alpha * 1.5)
            
            glow_surface = pygame.Surface((layer_size * 4, layer_size * 4), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, (*color, layer_alpha), 
                             (layer_size * 2, layer_size * 2), layer_size)
            surface.blit(glow_surface, (x - layer_size * 2, y - layer_size * 2), 
                        special_flags=pygame.BLEND_ADD)


# Test setup
building_rect = MockRect(300, 200, 200, 200)
clock = pygame.time.Clock()
font = pygame.font.Font(None, 36)

# Create initial particles
create_holy_light_particles(building_rect, 10)

running = True
particle_timer = 0

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                # Add more particles
                create_holy_light_particles(building_rect, 10)
    
    # Clear screen
    screen.fill((20, 20, 40))  # Dark blue background
    
    # Draw mock building
    pygame.draw.rect(screen, (100, 100, 100), (building_rect.x, building_rect.y, building_rect.width, building_rect.height))
    pygame.draw.rect(screen, (150, 150, 150), (building_rect.x, building_rect.y, building_rect.width, building_rect.height), 2)
    
    # Update and draw particles
    update_holy_light_particles()
    draw_holy_light_particles(screen)
    
    # Periodically add new particles to simulate healing
    particle_timer += 1
    if particle_timer >= 300:  # Every 5 seconds
        create_holy_light_particles(building_rect, 8)
        particle_timer = 0
    
    # Draw instructions
    text = font.render("Press SPACE to add more particles", True, (255, 255, 255))
    screen.blit(text, (50, 50))
    
    text2 = font.render(f"Particles: {len(holy_light_particles)}", True, (255, 255, 255))
    screen.blit(text2, (50, 90))
    
    pygame.display.flip()
    clock.tick(60)

pygame.quit()
sys.exit()