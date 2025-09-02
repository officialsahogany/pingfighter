#!/usr/bin/env python3
"""
전설 아이템 획득 애니메이션 테스트
실행: python test_legendary_effect.py
"""

import pygame
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from effects.legendary_acquisition import LegendaryAcquisitionEffect
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
    pygame.display.set_caption("전설 아이템 획득 효과 테스트")
    clock = pygame.time.Clock()
    
    # 폰트 설정
    font_small = pygame.font.Font(None, 24)
    font_large = pygame.font.Font(None, 48)
    font_huge = pygame.font.Font(None, 72)
    
    # 효과 시스템 초기화
    initialize_legendary_effects(WIDTH, HEIGHT)
    
    # 테스트용 게임 객체
    player = pygame.Rect(WIDTH//2 - 50, HEIGHT - 100, 100, 20)
    ball = pygame.Rect(WIDTH//2 - 10, HEIGHT//2 - 10, 20, 20)
    ball_dx, ball_dy = 5, 5
    
    # 테스트용 아이템 아이콘 생성
    def create_test_icon(color, shape='circle'):
        """테스트용 아이템 아이콘 생성"""
        icon_surf = pygame.Surface((60, 60), pygame.SRCALPHA)
        if shape == 'circle':
            pygame.draw.circle(icon_surf, color, (30, 30), 25)
            pygame.draw.circle(icon_surf, (255, 255, 255), (30, 30), 25, 3)
        elif shape == 'rect':
            pygame.draw.rect(icon_surf, color, (10, 10, 40, 40))
            pygame.draw.rect(icon_surf, (255, 255, 255), (10, 10, 40, 40), 3)
        elif shape == 'triangle':
            pygame.draw.polygon(icon_surf, color, [(30, 10), (10, 50), (50, 50)])
            pygame.draw.polygon(icon_surf, (255, 255, 255), [(30, 10), (10, 50), (50, 50)], 3)
        return icon_surf
    
    # 테스트 아이템 목록 (아이콘 포함)
    test_items = [
        ('ragnarok_hammer', '라그나로크', create_test_icon((255, 100, 100), 'rect')),
        ('infinity_gauntlet', '인피니티 건틀릿', create_test_icon((150, 100, 255), 'circle')),
        ('phoenix_feather', '불사조의 깃털', create_test_icon((255, 150, 50), 'triangle')),
        ('chronos_clock', '크로노스의 시계', create_test_icon((100, 255, 255), 'circle')),
        ('excalibur_blade', '엑스칼리버', create_test_icon((255, 215, 0), 'rect'))
    ]
    current_item = 0
    
    running = True
    game_paused = False
    effect_cooldown = 0
    
    print("=" * 50)
    print("전설 아이템 획득 효과 테스트")
    print("=" * 50)
    print("SPACE: 다음 전설 아이템 획득 효과 재생")
    print("P: 일시정지")
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
                elif event.key == pygame.K_p:
                    game_paused = not game_paused
                elif event.key == pygame.K_SPACE and effect_cooldown <= 0:
                    # 전설 아이템 획득 효과 트리거 (아이콘 포함)
                    item_name, korean_name, item_icon = test_items[current_item]
                    trigger_legendary_acquisition(item_name, korean_name, item_icon)
                    current_item = (current_item + 1) % len(test_items)
                    effect_cooldown = 100  # 쿨다운 설정
        
        # 쿨다운 감소
        if effect_cooldown > 0:
            effect_cooldown -= 1
        
        # 전설 아이템 효과로 인한 일시정지 체크
        legendary_pause = should_pause_for_legendary()
        
        # 게임 업데이트 (일시정지가 아닐 때만)
        if not game_paused and not legendary_pause:
            # 플레이어 이동
            keys = pygame.key.get_pressed()
            if keys[pygame.K_LEFT]:
                player.x = max(0, player.x - 8)
            if keys[pygame.K_RIGHT]:
                player.x = min(WIDTH - player.width, player.x + 8)
            
            # 공 이동
            ball.x += ball_dx
            ball.y += ball_dy
            
            # 벽 충돌
            if ball.left <= 0 or ball.right >= WIDTH:
                ball_dx = -ball_dx
            if ball.top <= 0 or ball.bottom >= HEIGHT:
                ball_dy = -ball_dy
            
            # 플레이어 충돌
            if ball.colliderect(player):
                ball_dy = -abs(ball_dy)
        
        # 전설 아이템 효과 업데이트
        update_legendary_effect(dt)
        
        # 화면 그리기
        screen.fill((20, 20, 30))
        
        # 게임 객체 그리기
        pygame.draw.rect(screen, (100, 100, 255), player)
        pygame.draw.circle(screen, (255, 255, 255), ball.center, 10)
        
        # UI 그리기
        instruction_text = font_small.render("SPACE: 전설 아이템 획득 효과 재생", True, (200, 200, 200))
        screen.blit(instruction_text, (10, 10))
        
        if effect_cooldown > 0:
            cooldown_text = font_small.render(f"쿨다운: {effect_cooldown // 60 + 1}초", True, (255, 100, 100))
            screen.blit(cooldown_text, (10, 40))
        else:
            ready_text = font_small.render("준비 완료!", True, (100, 255, 100))
            screen.blit(ready_text, (10, 40))
        
        next_item_name = test_items[current_item][1]
        next_item_text = font_small.render(f"다음 아이템: {next_item_name}", True, (255, 255, 100))
        screen.blit(next_item_text, (10, 70))
        
        # 일시정지 표시
        if game_paused:
            pause_text = font_large.render("PAUSED", True, (255, 255, 255))
            pause_rect = pause_text.get_rect(center=(WIDTH//2, HEIGHT//2))
            screen.blit(pause_text, pause_rect)
        
        # 전설 아이템 획득 효과 그리기 (최상단 레이어)
        draw_legendary_effect(screen, font_large, font_huge)
        
        # FPS 표시
        fps_text = font_small.render(f"FPS: {int(clock.get_fps())}", True, (150, 150, 150))
        screen.blit(fps_text, (WIDTH - 100, 10))
        
        pygame.display.flip()
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()