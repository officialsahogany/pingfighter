#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Stage 3 쿠로미 각성 효과 테스트
화면 지진과 돌 파편 효과를 시각적으로 확인
"""

import pygame
import sys
import os
import math

# 게임 디렉토리를 Python 경로에 추가
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from ui.stage3_menhera_world import Stage3MenheraWorld

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH = 600
HEIGHT = 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Stage 3 Awakening Effect Test")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
RED = (255, 0, 0)

# 시계
clock = pygame.time.Clock()

# Stage 3 배경 초기화
stage3_bg = Stage3MenheraWorld()

# 화면 흔들림 변수
screen_shake_timer = 0
screen_shake_intensity = 0

# 폰트 설정
font = pygame.font.Font(None, 36)
small_font = pygame.font.Font(None, 24)

# 메인 루프
running = True
awakening_triggered = False

while running:
    dt = clock.tick(60) / 1000.0  # 60 FPS
    
    # 이벤트 처리
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE and not awakening_triggered:
                # 스페이스바로 각성 시작
                stage3_bg.kuromi_awakening = True
                stage3_bg.kuromi_awakening_timer = 180
                screen_shake_timer = 180
                screen_shake_intensity = 15
                awakening_triggered = True
                print("각성 시작! 화면 지진 효과 활성화")
            elif event.key == pygame.K_r:
                # R키로 리셋
                stage3_bg = Stage3MenheraWorld()
                awakening_triggered = False
                screen_shake_timer = 0
                screen_shake_intensity = 0
                print("리셋됨")
    
    # 배경 업데이트
    stage3_bg.update(dt)
    
    # 화면 흔들림 업데이트
    if screen_shake_timer > 0:
        screen_shake_timer -= 1
        # 시간에 따라 강도 감소
        if screen_shake_timer < 60:
            screen_shake_intensity = 15 * (screen_shake_timer / 60)
    
    # 화면 그리기
    screen.fill(BLACK)
    
    # 화면 흔들림 오프셋 계산
    shake_offset_x = 0
    shake_offset_y = 0
    if screen_shake_timer > 0:
        import random
        shake_offset_x = random.randint(-int(screen_shake_intensity), int(screen_shake_intensity))
        shake_offset_y = random.randint(-int(screen_shake_intensity), int(screen_shake_intensity))
    
    # 임시 서페이스에 그리기
    temp_surface = pygame.Surface((WIDTH, HEIGHT))
    temp_surface.fill(BLACK)
    
    # Stage 3 배경 그리기
    stage3_bg.draw(temp_surface, None)  # ball_pos는 None으로 전달
    
    # 화면 흔들림 적용
    screen.blit(temp_surface, (shake_offset_x, shake_offset_y))
    
    # UI 정보 표시
    if not awakening_triggered:
        text = font.render("Press SPACE to trigger awakening", True, WHITE)
        screen.blit(text, (WIDTH//2 - text.get_width()//2, HEIGHT//2 - 100))
    else:
        if stage3_bg.kuromi_awakening:
            status_text = f"Awakening... Timer: {stage3_bg.kuromi_awakening_timer}"
        else:
            status_text = "Awakening Complete!"
        text = small_font.render(status_text, True, WHITE)
        screen.blit(text, (10, 10))
        
        particle_text = f"Particles: {len(stage3_bg.crack_particles)}"
        text2 = small_font.render(particle_text, True, WHITE)
        screen.blit(text2, (10, 40))
        
        shake_text = f"Shake: {screen_shake_timer} (Intensity: {screen_shake_intensity:.1f})"
        text3 = small_font.render(shake_text, True, WHITE)
        screen.blit(text3, (10, 70))
    
    reset_text = small_font.render("Press R to reset", True, WHITE)
    screen.blit(reset_text, (WIDTH - 150, HEIGHT - 30))
    
    # 화면 업데이트
    pygame.display.flip()

# 종료
pygame.quit()
sys.exit()