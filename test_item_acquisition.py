#!/usr/bin/env python3
"""
아이템 획득 애니메이션 테스트
실행: python test_item_acquisition.py
"""

import pygame
import sys
import os
import random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from effects.item_acquisition import (
    show_item_acquisition,
    update_item_effects,
    draw_item_effects,
    initialize_item_effects
)
from effects.legendary_integration import (
    trigger_legendary_acquisition,
    update_legendary_effect,
    draw_legendary_effect,
    should_pause_for_legendary,
    initialize_legendary_effects
)

def main():
    """테스트 메인 함수"""
    pygame.init()
    
    # 화면 설정
    WIDTH, HEIGHT = 600, 750
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("아이템 획득 애니메이션 테스트")
    clock = pygame.time.Clock()
    
    # 폰트 설정
    font_small = pygame.font.Font(None, 24)
    font_medium = pygame.font.Font(None, 32)
    font_large = pygame.font.Font(None, 48)
    font_huge = pygame.font.Font(None, 72)
    
    # 효과 시스템 초기화
    initialize_item_effects(WIDTH, HEIGHT)
    initialize_legendary_effects(WIDTH, HEIGHT)
    
    # 테스트용 아이템 아이콘 생성
    def create_item_icon(color, shape='circle', size=60):
        """테스트용 아이템 아이콘 생성"""
        icon_surf = pygame.Surface((size, size), pygame.SRCALPHA)
        center = size // 2
        
        if shape == 'circle':
            pygame.draw.circle(icon_surf, color, (center, center), size // 2 - 5)
            pygame.draw.circle(icon_surf, (255, 255, 255), (center, center), size // 2 - 5, 3)
        elif shape == 'rect':
            margin = size // 6
            pygame.draw.rect(icon_surf, color, (margin, margin, size - margin * 2, size - margin * 2))
            pygame.draw.rect(icon_surf, (255, 255, 255), (margin, margin, size - margin * 2, size - margin * 2), 3)
        elif shape == 'diamond':
            points = [(center, 5), (size - 5, center), (center, size - 5), (5, center)]
            pygame.draw.polygon(icon_surf, color, points)
            pygame.draw.polygon(icon_surf, (255, 255, 255), points, 3)
        elif shape == 'star':
            # 별 모양
            import math
            points = []
            for i in range(10):
                angle = math.pi * i / 5
                if i % 2 == 0:
                    r = size // 2 - 5
                else:
                    r = size // 4
                x = center + r * math.cos(angle - math.pi / 2)
                y = center + r * math.sin(angle - math.pi / 2)
                points.append((x, y))
            pygame.draw.polygon(icon_surf, color, points)
            pygame.draw.polygon(icon_surf, (255, 255, 255), points, 2)
            
        return icon_surf
    
    # 테스트 아이템 목록
    normal_items = [
        ('health_potion', '체력 포션', create_item_icon((255, 100, 100), 'circle')),
        ('mana_potion', '마나 포션', create_item_icon((100, 100, 255), 'circle')),
        ('speed_boost', '속도 부스트', create_item_icon((100, 255, 100), 'diamond')),
        ('shield', '방패', create_item_icon((200, 200, 200), 'rect')),
        ('power_up', '파워 업', create_item_icon((255, 200, 50), 'star'))
    ]
    
    legendary_items = [
        ('ragnarok_hammer', '라그나로크', create_item_icon((255, 50, 50), 'rect', 80)),
        ('infinity_gauntlet', '인피니티 건틀릿', create_item_icon((150, 100, 255), 'star', 80)),
        ('phoenix_feather', '불사조의 깃털', create_item_icon((255, 150, 50), 'diamond', 80))
    ]
    
    # 게임 상태
    running = True
    effect_cooldown = 0
    legendary_cooldown = 0
    auto_spawn = False
    auto_spawn_timer = 0
    
    print("=" * 50)
    print("아이템 획득 애니메이션 테스트")
    print("=" * 50)
    print("1-5: 일반 아이템 획득")
    print("Q: 랜덤 일반 아이템")
    print("W: 랜덤 전설 아이템 (플로팅)")
    print("E: 전설 아이템 (극적인 애니메이션)")
    print("A: 자동 스폰 토글")
    print("ESC: 종료")
    print("=" * 50)
    
    while running:
        dt = clock.tick(60)
        
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                    
                # 숫자 키로 일반 아이템 획득
                elif event.key >= pygame.K_1 and event.key <= pygame.K_5:
                    index = event.key - pygame.K_1
                    if index < len(normal_items):
                        item = normal_items[index]
                        # 랜덤 위치에서 시작
                        pos_x = random.randint(100, WIDTH - 100)
                        show_item_acquisition(item[0], item[1], item[2], False, (pos_x, HEIGHT - 50))
                        
                # Q: 랜덤 일반 아이템
                elif event.key == pygame.K_q and effect_cooldown <= 0:
                    item = random.choice(normal_items)
                    pos_x = random.randint(100, WIDTH - 100)
                    show_item_acquisition(item[0], item[1], item[2], False, (pos_x, HEIGHT - 50))
                    effect_cooldown = 30
                    
                # W: 랜덤 전설 아이템 (플로팅)
                elif event.key == pygame.K_w and effect_cooldown <= 0:
                    item = random.choice(legendary_items)
                    pos_x = random.randint(100, WIDTH - 100)
                    show_item_acquisition(item[0], item[1], item[2], True, (pos_x, HEIGHT - 50))
                    effect_cooldown = 30
                    
                # E: 전설 아이템 (극적인 애니메이션)
                elif event.key == pygame.K_e and legendary_cooldown <= 0:
                    item = random.choice(legendary_items)
                    trigger_legendary_acquisition(item[0], item[1], item[2])
                    legendary_cooldown = 180
                    
                # A: 자동 스폰 토글
                elif event.key == pygame.K_a:
                    auto_spawn = not auto_spawn
                    print(f"자동 스폰: {'ON' if auto_spawn else 'OFF'}")
        
        # 쿨다운 감소
        if effect_cooldown > 0:
            effect_cooldown -= 1
        if legendary_cooldown > 0:
            legendary_cooldown -= 1
            
        # 자동 스폰
        if auto_spawn:
            auto_spawn_timer += 1
            if auto_spawn_timer >= 60:  # 1초마다
                auto_spawn_timer = 0
                if random.random() < 0.7:  # 70% 일반 아이템
                    item = random.choice(normal_items)
                    pos_x = random.randint(100, WIDTH - 100)
                    show_item_acquisition(item[0], item[1], item[2], False, (pos_x, HEIGHT - 50))
                else:  # 30% 전설 아이템
                    item = random.choice(legendary_items)
                    pos_x = random.randint(100, WIDTH - 100)
                    show_item_acquisition(item[0], item[1], item[2], True, (pos_x, HEIGHT - 50))
        
        # 전설 아이템 효과로 인한 일시정지 체크
        legendary_pause = should_pause_for_legendary()
        
        # 업데이트 (일시정지가 아닐 때만)
        if not legendary_pause:
            # 아이템 획득 효과 업데이트
            update_item_effects(dt)
        
        # 전설 아이템 효과 업데이트
        update_legendary_effect(dt)
        
        # 화면 그리기
        screen.fill((20, 20, 30))
        
        # 배경 격자
        for x in range(0, WIDTH, 50):
            pygame.draw.line(screen, (30, 30, 40), (x, 0), (x, HEIGHT), 1)
        for y in range(0, HEIGHT, 50):
            pygame.draw.line(screen, (30, 30, 40), (0, y), (WIDTH, y), 1)
        
        # 아이템 획득 효과 그리기
        draw_item_effects(screen, font_medium)
        
        # UI 그리기
        instructions = [
            "1-5: 일반 아이템 | Q: 랜덤 일반",
            "W: 랜덤 전설(플로팅) | E: 전설(극적)",
            f"A: 자동 스폰 {'ON' if auto_spawn else 'OFF'}"
        ]
        
        for i, text in enumerate(instructions):
            inst_text = font_small.render(text, True, (200, 200, 200))
            screen.blit(inst_text, (10, 10 + i * 25))
        
        # 쿨다운 표시
        if effect_cooldown > 0:
            cd_text = font_small.render(f"쿨다운: {effect_cooldown // 60 + 1}초", True, (255, 100, 100))
            screen.blit(cd_text, (WIDTH - 150, 10))
        
        if legendary_cooldown > 0:
            lcd_text = font_small.render(f"전설 쿨다운: {legendary_cooldown // 60 + 1}초", True, (255, 215, 0))
            screen.blit(lcd_text, (WIDTH - 150, 35))
        
        # 전설 아이템 획득 효과 그리기 (최상단 레이어)
        draw_legendary_effect(screen, font_large, font_huge)
        
        # FPS 표시
        fps_text = font_small.render(f"FPS: {int(clock.get_fps())}", True, (150, 150, 150))
        screen.blit(fps_text, (WIDTH - 100, HEIGHT - 30))
        
        pygame.display.flip()
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()