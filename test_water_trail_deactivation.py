#!/usr/bin/env python3
"""
물 궤적 비활성화 테스트
- 회오리에 공이 닿으면 물 궤적이 활성화
- 보스가 공을 치면 물 궤적이 비활성화
"""
import pygame
import sys
import os
import random
import math

# 모듈 임포트를 위한 경로 설정
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from legendary_items import get_legendary_manager

def test_water_trail_deactivation():
    """물 궤적 비활성화 테스트"""
    print("=" * 60)
    print("포세이돈의 삼지창 - 물 궤적 비활성화 테스트")
    print("=" * 60)
    
    # Pygame 초기화
    pygame.init()
    WIDTH, HEIGHT = 800, 600
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Water Trail Deactivation Test")
    clock = pygame.time.Clock()
    
    # 전설 아이템 매니저
    legendary_manager = get_legendary_manager()
    trident = legendary_manager.get_item("poseidon_trident")
    trident.activate({})
    print("✅ 포세이돈의 삼지창 활성화됨")
    
    # 게임 상태
    ball_x = WIDTH // 2
    ball_y = HEIGHT - 150
    ball_vx = 0
    ball_vy = -8  # 위로 향하는 공
    
    boss_x = WIDTH // 2 - 40
    boss_y = 50
    boss_width = 80
    boss_height = 20
    
    player_x = WIDTH // 2 - 40
    player_y = HEIGHT - 50
    player_width = 80
    player_height = 20
    
    # 회오리 생성
    vortex_x = WIDTH // 2
    vortex_y = HEIGHT // 2
    vortex_created = False
    
    font = pygame.font.Font(None, 24)
    
    # 메인 루프
    running = True
    frame_count = 0
    
    while running:
        dt = clock.tick(60) / 1000.0
        frame_count += 1
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 스페이스바로 회오리 활성화
                    if not vortex_created:
                        trident.vortex_active = True
                        trident.vortex_center_x = vortex_x
                        trident.vortex_center_y = vortex_y
                        trident.vortex_timer = 0
                        vortex_created = True
                        print(f"🌊 회오리 활성화! 위치: ({vortex_x}, {vortex_y})")
                elif event.key == pygame.K_r:
                    # R키로 리셋
                    ball_x = WIDTH // 2
                    ball_y = HEIGHT - 150
                    ball_vx = 0
                    ball_vy = -8
                    vortex_created = False
                    trident.vortex_active = False
                    trident.water_trail_active = False
                    trident.water_trail.clear()
                    trident.water_droplets.clear()
                    print("🔄 게임 리셋!")
                elif event.key == pygame.K_b:
                    # B키로 보스가 공을 치는 시뮬레이션
                    if trident.water_trail_active:
                        trident.deactivate_water_trail()
                        ball_vy = 8  # 아래로 방향 전환
                        print("🎾 보스가 공을 쳤습니다! 물 궤적 비활성화")
        
        # 공 이동
        ball_x += ball_vx
        ball_y += ball_vy
        
        # 벽 충돌
        if ball_x <= 10 or ball_x >= WIDTH - 10:
            ball_vx = -ball_vx
        
        # 화면 밖으로 나가면 리셋
        if ball_y < 0 or ball_y > HEIGHT:
            ball_x = WIDTH // 2
            ball_y = HEIGHT - 150
            ball_vx = 0
            ball_vy = -8
        
        # 회오리 효과 적용
        if trident.vortex_active:
            # 볼 물리 업데이트 (간단한 시뮬레이션)
            result_vx, result_vy = trident.apply_trajectory_influence(
                ball_x, ball_y, ball_vx, ball_vy,
                player_x, player_y
            )
            
            # 회오리에 캡처된 경우 속도 업데이트
            if trident.ball_in_vortex:
                ball_vx = result_vx
                ball_vy = result_vy
        
        # 화면 그리기
        screen.fill((20, 20, 40))  # 어두운 배경
        
        # 보스 패들 그리기
        boss_rect = pygame.Rect(boss_x, boss_y, boss_width, boss_height)
        pygame.draw.rect(screen, (255, 100, 100), boss_rect)
        pygame.draw.rect(screen, (255, 200, 200), boss_rect, 2)
        
        # 플레이어 패들 그리기
        player_rect = pygame.Rect(player_x, player_y, player_width, player_height)
        pygame.draw.rect(screen, (100, 200, 255), player_rect)
        pygame.draw.rect(screen, (200, 220, 255), player_rect, 2)
        
        # 회오리 그리기
        if trident.vortex_active:
            # 회오리 범위
            pygame.draw.circle(screen, (50, 100, 200, 50), 
                             (int(vortex_x), int(vortex_y)), 
                             80, 2)
            
            # 회오리 중심
            pygame.draw.circle(screen, (100, 150, 255), 
                             (int(vortex_x), int(vortex_y)), 
                             10)
            
            # 회오리 파티클
            for particle in trident.vortex_particles:
                pygame.draw.circle(screen, (100, 150, 255, 100),
                                 (int(particle['x']), int(particle['y'])),
                                 3)
        
        # 물 궤적 그리기
        if len(trident.water_trail) > 1:
            # 물 궤적 선 그리기
            for i in range(1, len(trident.water_trail)):
                p1 = trident.water_trail[i-1]
                p2 = trident.water_trail[i]
                
                alpha = int((p2['lifetime'] / 30) * 100)
                if alpha > 0:
                    pygame.draw.line(screen, (100, 150, 255),
                                   (int(p1['x']), int(p1['y'])),
                                   (int(p2['x']), int(p2['y'])), 3)
        
        # 물방울 그리기
        for droplet in trident.water_droplets:
            pygame.draw.circle(screen, (150, 200, 255),
                             (int(droplet['x']), int(droplet['y'])),
                             int(droplet['size']))
        
        # 공 그리기
        ball_color = (255, 200, 100) if trident.water_trail_active else (255, 255, 255)
        pygame.draw.circle(screen, ball_color, (int(ball_x), int(ball_y)), 10)
        if trident.water_trail_active:
            # 물에 젖은 효과
            pygame.draw.circle(screen, (100, 150, 255, 100), 
                             (int(ball_x), int(ball_y)), 12, 2)
        
        # UI 텍스트
        info_texts = [
            f"Water Trail Active: {trident.water_trail_active}",
            f"Trail Points: {len(trident.water_trail)}",
            f"Vortex Active: {trident.vortex_active}",
            f"Ball in Vortex: {trident.ball_in_vortex}",
            "",
            "Controls:",
            "SPACE: Create vortex",
            "B: Boss hits ball (deactivates trail)",
            "R: Reset",
            "ESC: Exit"
        ]
        
        y_offset = 10
        for text in info_texts:
            if text == "":
                y_offset += 10
                continue
            color = (255, 255, 100) if "Active: True" in text else (255, 255, 255)
            text_surface = font.render(text, True, color)
            screen.blit(text_surface, (10, y_offset))
            y_offset += 25
        
        # 상태 표시
        if trident.water_trail_active:
            status_text = font.render("WATER TRAIL ACTIVE - Ball is wet!", True, (100, 200, 255))
            status_rect = status_text.get_rect(center=(WIDTH//2, HEIGHT - 50))
            screen.blit(status_text, status_rect)
        
        pygame.display.flip()
    
    pygame.quit()
    
    print("\n테스트 종료")

if __name__ == "__main__":
    test_water_trail_deactivation()