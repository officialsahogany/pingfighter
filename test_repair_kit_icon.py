#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
수리키트 아이콘 테스트
발토르의 수리키트 아이템 - 천사가 수리해주는 엠블럼 디자인 테스트
"""

import pygame
import sys
import os

# 상위 디렉토리 import를 위한 path 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# pingfighter에서 get_item_icon 함수 import
from pingfighter import get_item_icon, resource_path

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("수리키트 아이콘 테스트 - 천사가 수리해주는 엠블럼")
clock = pygame.time.Clock()

# 배경색
BG_COLOR = (50, 50, 50)

# 폰트 설정
try:
    font = pygame.font.Font(resource_path("fonts/NanumSquareB.ttf"), 24)
    small_font = pygame.font.Font(resource_path("fonts/NanumSquareB.ttf"), 18)
except:
    font = pygame.font.Font(None, 24)
    small_font = pygame.font.Font(None, 18)

# 아이템 정보
item_info = {
    "name": "repair_kit",
    "korean_name": "수리키트",
    "description": "발토르의 포탑과 디바인스톤을 즉시 완전 수리",
    "character": "발토르 전용"
}

# 메인 루프
running = True
scale = 1.0
scale_step = 0.1

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_PLUS or event.key == pygame.K_EQUALS:
                scale = min(scale + scale_step, 5.0)
            elif event.key == pygame.K_MINUS:
                scale = max(scale - scale_step, 0.5)
            elif event.key == pygame.K_SPACE:
                scale = 1.0
    
    # 화면 클리어
    screen.fill(BG_COLOR)
    
    # 아이콘 가져오기
    icon = get_item_icon(item_info["name"])
    
    # 다양한 크기로 아이콘 표시
    sizes = [32, 64, 128, 256]
    x_offset = 50
    y_offset = 50
    
    # 타이틀
    title_text = font.render("수리키트 아이콘 - 천사가 수리해주는 엠블럼", True, (255, 255, 255))
    screen.blit(title_text, (screen.get_width()//2 - title_text.get_width()//2, 10))
    
    # 아이템 설명
    desc_texts = [
        f"아이템명: {item_info['korean_name']} ({item_info['name']})",
        f"설명: {item_info['description']}",
        f"캐릭터: {item_info['character']}"
    ]
    
    for i, text in enumerate(desc_texts):
        desc_surface = small_font.render(text, True, (200, 200, 200))
        screen.blit(desc_surface, (50, 450 + i * 25))
    
    # 다양한 크기로 아이콘 표시
    for i, size in enumerate(sizes):
        x = x_offset + i * (max(sizes) + 20)
        y = y_offset + 50
        
        # 배경 사각형
        bg_rect = pygame.Rect(x - 5, y - 5, size + 10, size + 10)
        pygame.draw.rect(screen, (100, 100, 100), bg_rect, 1)
        
        # 아이콘 크기 조정 및 표시
        if icon:
            scaled_icon = pygame.transform.smoothscale(icon, (int(size * scale), int(size * scale)))
            icon_rect = scaled_icon.get_rect(center=(x + size//2, y + size//2))
            screen.blit(scaled_icon, icon_rect)
        
        # 크기 레이블
        size_text = small_font.render(f"{size}x{size}", True, (150, 150, 150))
        screen.blit(size_text, (x + size//2 - size_text.get_width()//2, y + size + 10))
    
    # 스케일 정보
    scale_info = small_font.render(f"스케일: {scale:.1f}x ('+'/'-'키로 조정, Space: 리셋)", True, (255, 255, 100))
    screen.blit(scale_info, (50, 400))
    
    # 컨트롤 안내
    controls = [
        "ESC: 종료",
        "+/-: 크기 조정",
        "Space: 크기 리셋"
    ]
    for i, control in enumerate(controls):
        control_text = small_font.render(control, True, (150, 150, 150))
        screen.blit(control_text, (screen.get_width() - 200, 450 + i * 25))
    
    # 디자인 특징 설명
    features = [
        "✦ 천사 모습: 아이보리색 천사와 흰색 날개",
        "✦ 황금 후광: 천사 머리 위의 타원형 후광",
        "✦ 수리 도구: 천사가 들고 있는 렌치",
        "✦ 톱니바퀴: 하단의 기계 장식",
        "✦ 반짝임: 신성한 효과를 나타내는 별빛"
    ]
    
    for i, feature in enumerate(features):
        feature_text = small_font.render(feature, True, (180, 180, 180))
        screen.blit(feature_text, (400, 100 + i * 30))
    
    pygame.display.flip()
    clock.tick(60)

pygame.quit()