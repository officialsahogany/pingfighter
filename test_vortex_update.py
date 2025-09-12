#!/usr/bin/env python3
"""
수정된 회오리 효과 테스트
- 지속시간: 1.6초
- 최대 높이: 350픽셀
- 수평 범위: 100픽셀
"""
import pygame
import sys
import os

# 모듈 임포트를 위한 경로 설정
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from legendary_items import get_legendary_manager

def test_vortex_update():
    """수정된 회오리 효과 테스트"""
    print("=" * 60)
    print("포세이돈의 삼지창 - 수정된 회오리 효과 테스트")
    print("=" * 60)
    
    # Pygame 초기화
    pygame.init()
    WIDTH, HEIGHT = 800, 600
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Updated Vortex Test")
    clock = pygame.time.Clock()
    
    # 전설 아이템 매니저
    legendary_manager = get_legendary_manager()
    trident = legendary_manager.get_item("poseidon_trident")
    trident.activate({})
    
    print(f"✅ 포세이돈의 삼지창 활성화됨")
    print(f"📏 회오리 최대 높이: {trident.vortex_max_height}픽셀")
    print(f"📏 회오리 너비: {trident.vortex_width}픽셀 (반경: {trident.vortex_width/2}픽셀)")
    print(f"⏱️  총 지속시간: 1.6초 (96프레임)")
    
    # 플레이어 위치
    player_x = WIDTH // 2
    player_y = HEIGHT - 100
    
    # 회오리 활성화
    trident.trigger_dash_wave(player_x, player_y)
    
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
                elif event.key == pygame.K_r:
                    # R키로 회오리 재활성화
                    trident.trigger_dash_wave(player_x, player_y)
                    frame_count = 0
                    print("🌊 회오리 재활성화!")
        
        # 화면 그리기
        screen.fill((20, 20, 40))
        
        # 플레이어 패들
        pygame.draw.rect(screen, (100, 200, 255), 
                        (player_x - 40, player_y - 10, 80, 20))
        
        # 회오리 업데이트
        if trident.vortex_active:
            trident.update(dt)
            
            # 왼쪽 회오리 범위 표시
            left_x = int(trident.vortex_left_x)
            left_y = int(trident.vortex_left_y)
            left_height = int(min(trident.vortex_left_height, trident.vortex_max_height))
            
            # 수평 범위 (반경 100픽셀)
            pygame.draw.circle(screen, (50, 100, 200, 50), 
                             (left_x, left_y), 
                             int(trident.vortex_width / 2), 2)
            
            # 수직 범위
            if left_height > 0:
                pygame.draw.rect(screen, (50, 100, 200, 30),
                               (left_x - trident.vortex_width/2, 
                                left_y - left_height, 
                                trident.vortex_width, 
                                left_height), 1)
            
            # 오른쪽 회오리 범위 표시
            right_x = int(trident.vortex_right_x)
            right_y = int(trident.vortex_right_y)
            right_height = int(min(trident.vortex_right_height, trident.vortex_max_height))
            
            # 수평 범위 (반경 100픽셀)
            pygame.draw.circle(screen, (50, 100, 200, 50), 
                             (right_x, right_y), 
                             int(trident.vortex_width / 2), 2)
            
            # 수직 범위
            if right_height > 0:
                pygame.draw.rect(screen, (50, 100, 200, 30),
                               (right_x - trident.vortex_width/2, 
                                right_y - right_height, 
                                trident.vortex_width, 
                                right_height), 1)
            
            # 회오리 파티클 그리기
            for particle in trident.vortex_particles:
                pygame.draw.circle(screen, particle['color'],
                                 (int(particle['x']), int(particle['y'])),
                                 int(particle['size']))
        
        # UI 정보
        info_texts = [
            f"Frame: {frame_count} / Timer: {trident.vortex_timer:.1f}",
            f"Left Height: {int(trident.vortex_left_height)} / {trident.vortex_max_height}",
            f"Right Height: {int(trident.vortex_right_height)} / {trident.vortex_max_height}",
            f"Width: {trident.vortex_width}px (Radius: {int(trident.vortex_width/2)}px)",
            f"Active: {trident.vortex_active}",
            "",
            "Stage:",
            f"0-18f (0-0.3s): Growing",
            f"18-48f (0.3-0.8s): Active",
            f"48-96f (0.8-1.6s): Fading",
            "",
            "Press R to restart vortex"
        ]
        
        y_offset = 10
        for text in info_texts:
            if text == "":
                y_offset += 10
                continue
                
            # 현재 단계 강조
            color = (255, 255, 255)
            if trident.vortex_active:
                if "0-18f" in text and trident.vortex_timer < 18:
                    color = (100, 255, 100)
                elif "18-48f" in text and 18 <= trident.vortex_timer < 48:
                    color = (255, 255, 100)
                elif "48-96f" in text and 48 <= trident.vortex_timer < 96:
                    color = (255, 100, 100)
            
            text_surface = font.render(text, True, color)
            screen.blit(text_surface, (10, y_offset))
            y_offset += 25
        
        pygame.display.flip()
    
    pygame.quit()
    
    print("\n테스트 종료")

if __name__ == "__main__":
    test_vortex_update()