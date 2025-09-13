#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""옛날 아이템 획득 애니메이션 테스트"""

import pygame
import sys
import os

# pingfighter 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_old_animation():
    """옛날 아이템 획득 애니메이션 테스트"""
    pygame.init()
    
    # 화면 설정
    WIDTH = 1024
    HEIGHT = 768
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("아이템 획득 애니메이션 테스트 (옛날 버전)")
    clock = pygame.time.Clock()
    
    print("=" * 50)
    print("아이템 획득 애니메이션 테스트 (옛날 버전)")
    print("=" * 50)
    print("\n스페이스바를 눌러 아이템 획득 효과를 확인하세요!")
    print("ESC를 눌러 종료")
    
    # 테스트용 아이템 데이터
    test_items = [
        {"name": "speedboots", "color": (255, 100, 100), "icon": None},
        {"name": "battery", "color": (100, 255, 100), "icon": None},
        {"name": "master", "color": (100, 100, 255), "icon": None},
    ]
    current_item = 0
    
    # 애니메이션 상태
    item_obtained_effect = None
    item_effect_duration = 120  # 2초 (60fps)
    
    # 간단한 effects_manager 모킹
    class EffectsManager:
        def create_balloon_pop_effect(self, x, y, color):
            print(f"풍선 터지는 효과: 위치({x}, {y}), 색상{color}")
    
    effects_manager = EffectsManager()
    
    def show_item_obtained_effect(item_data, item_x=None, item_y=None):
        """옛날 버전 아이템 획득 효과"""
        nonlocal item_obtained_effect
        
        # 시작 위치
        start_x = item_x if item_x else WIDTH // 2
        start_y = item_y if item_y else HEIGHT // 2
        
        # 목표 위치 (플레이어 쪽)
        target_x = 100
        target_y = HEIGHT // 2
        
        # 풍선 터지는 효과
        item_color = item_data.get("color", (255, 255, 255))
        effects_manager.create_balloon_pop_effect(start_x, start_y, item_color)
        
        item_obtained_effect = {
            "name": item_data.get("name"),
            "timer": item_effect_duration,
            "alpha": 180,
            "x": start_x,
            "y": start_y,
            "target_x": target_x,
            "target_y": target_y,
            "start_x": start_x,
            "start_y": start_y,
            "color": item_color
        }
        print(f"\n아이템 획득: {item_data['name']}")
    
    def update_item_obtained_effect():
        """아이템 획득 효과 업데이트"""
        nonlocal item_obtained_effect
        if item_obtained_effect:
            item_obtained_effect["timer"] -= 1
            
            # 위치 업데이트 (플레이어 쪽으로 이동)
            progress = 1 - (item_obtained_effect["timer"] / item_effect_duration)
            ease_progress = 1 - (1 - progress) ** 2  # easing
            
            item_obtained_effect["x"] = item_obtained_effect["start_x"] + \
                (item_obtained_effect["target_x"] - item_obtained_effect["start_x"]) * ease_progress
            item_obtained_effect["y"] = item_obtained_effect["start_y"] + \
                (item_obtained_effect["target_y"] - item_obtained_effect["start_y"]) * ease_progress
            
            # 페이드 아웃
            if item_obtained_effect["timer"] < 60:
                fade_ratio = item_obtained_effect["timer"] / 60
                item_obtained_effect["alpha"] = int(180 * fade_ratio)
            
            if item_obtained_effect["timer"] <= 0:
                item_obtained_effect = None
    
    def draw_item_obtained_effect():
        """아이템 획득 효과 그리기"""
        if item_obtained_effect:
            # 큰 원 그리기
            radius = 30 + (item_effect_duration - item_obtained_effect["timer"]) // 2
            if radius > 60:
                radius = 60
            
            # 반투명 서페이스 생성
            s = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
            pygame.draw.circle(s, (*item_obtained_effect["color"], item_obtained_effect["alpha"]), 
                             (radius, radius), radius)
            
            screen.blit(s, (item_obtained_effect["x"] - radius, 
                           item_obtained_effect["y"] - radius))
            
            # 아이템 이름 표시
            font = pygame.font.Font(None, 36)
            text = font.render(item_obtained_effect["name"], True, (255, 255, 255))
            text_rect = text.get_rect(center=(item_obtained_effect["x"], 
                                             item_obtained_effect["y"] - 50))
            screen.blit(text, text_rect)
    
    # 메인 루프
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 아이템 획득 효과 트리거
                    if not item_obtained_effect:
                        test_item = test_items[current_item]
                        # 랜덤 위치에서 시작
                        import random
                        start_x = random.randint(200, WIDTH - 200)
                        start_y = random.randint(200, HEIGHT - 200)
                        show_item_obtained_effect(test_item, start_x, start_y)
                        current_item = (current_item + 1) % len(test_items)
        
        # 업데이트
        update_item_obtained_effect()
        
        # 그리기
        screen.fill((30, 30, 30))
        
        # 플레이어 위치 표시 (목표 지점)
        pygame.draw.rect(screen, (255, 255, 255), (50, HEIGHT // 2 - 40, 100, 80), 2)
        font = pygame.font.Font(None, 24)
        text = font.render("Player", True, (255, 255, 255))
        screen.blit(text, (75, HEIGHT // 2 - 10))
        
        # 아이템 효과 그리기
        draw_item_obtained_effect()
        
        # 안내 텍스트
        if not item_obtained_effect:
            help_text = font.render("Press SPACE to trigger item pickup animation", True, (200, 200, 200))
            screen.blit(help_text, (WIDTH // 2 - 200, 50))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    print("\n테스트 종료")

if __name__ == "__main__":
    test_old_animation()