#!/usr/bin/env python3
"""
물방울 파티클과 보스 패들 충돌 테스트
- 물방울이 보스 패들에 닿으면 사라지는지 확인
"""
import pygame
import sys
import os
import random
import math

# 모듈 임포트를 위한 경로 설정
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from legendary_items import get_legendary_manager

def test_boss_collision():
    """보스 패들과 물방울 충돌 테스트"""
    print("=" * 60)
    print("포세이돈의 삼지창 - 보스 패들 충돌 테스트")
    print("=" * 60)
    
    # Pygame 초기화
    pygame.init()
    WIDTH, HEIGHT = 800, 600
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Boss Paddle Collision Test")
    clock = pygame.time.Clock()
    
    # 전설 아이템 매니저
    legendary_manager = get_legendary_manager()
    trident = legendary_manager.get_item("poseidon_trident")
    trident.activate({})
    print("✅ 포세이돈의 삼지창 활성화됨")
    
    # 보스 패들 설정
    boss_x = WIDTH // 2 - 40
    boss_y = 50
    boss_width = 80
    boss_height = 20
    boss_speed = 5
    
    # 물방울 생성 타이머
    droplet_spawn_timer = 0
    
    font = pygame.font.Font(None, 24)
    
    def spawn_water_droplets(x, y, count=5):
        """물방울 생성"""
        for _ in range(count):
            droplet = {
                'x': x + random.randint(-20, 20),
                'y': y + random.randint(-20, 20),
                'vx': random.uniform(-3, 3),
                'vy': random.uniform(2, 5),  # 아래로 떨어지게
                'life': 1.0,
                'size': random.randint(4, 8),
                'lifetime': 30  # lifetime 추가 (draw_water_trail에서 사용)
            }
            trident.water_droplets.append(droplet)
    
    # 메인 루프
    running = True
    auto_spawn = True
    
    while running:
        dt = clock.tick(60) / 1000.0
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 스페이스바로 수동 물방울 생성
                    spawn_water_droplets(WIDTH // 2, HEIGHT // 4, 10)
                    print(f"물방울 생성! 현재 개수: {len(trident.water_droplets)}")
                elif event.key == pygame.K_a:
                    # A키로 자동 생성 토글
                    auto_spawn = not auto_spawn
                    print(f"자동 생성: {'ON' if auto_spawn else 'OFF'}")
        
        # 키 입력으로 보스 패들 이동
        keys = pygame.key.get_pressed()
        if keys[pygame.K_LEFT]:
            boss_x -= boss_speed
        if keys[pygame.K_RIGHT]:
            boss_x += boss_speed
        
        # 보스 패들 경계 체크
        boss_x = max(0, min(WIDTH - boss_width, boss_x))
        
        # 자동 물방울 생성 (1초마다) - 보스 패들 위치 근처에 생성
        if auto_spawn:
            droplet_spawn_timer += dt
            if droplet_spawn_timer >= 1.0:
                droplet_spawn_timer = 0
                # 보스 패들 근처에서 물방울 생성
                spawn_x = boss_x + boss_width // 2 + random.randint(-50, 50)
                spawn_y = boss_y - 30  # 보스 패들 위에서 생성
                spawn_water_droplets(spawn_x, spawn_y, 5)
        
        # 물방울 업데이트 (중력 적용)
        for droplet in trident.water_droplets[:]:
            droplet['x'] += droplet['vx']
            droplet['y'] += droplet['vy']
            droplet['vy'] += 0.3  # 중력
            droplet['life'] -= 0.01
            
            # lifetime 업데이트
            if 'lifetime' in droplet:
                droplet['lifetime'] -= 1
            
            # 화면 밖으로 나가거나 수명이 다하면 제거
            if droplet['life'] <= 0 or droplet['y'] > HEIGHT:
                trident.water_droplets.remove(droplet)
        
        # 보스 패들과 충돌 체크
        initial_count = len(trident.water_droplets)
        trident.update_water_droplets_with_boss(boss_x, boss_y, boss_width, boss_height)
        removed_count = initial_count - len(trident.water_droplets)
        
        if removed_count > 0:
            print(f"💥 {removed_count}개의 물방울이 보스 패들과 충돌하여 제거됨!")
        
        # 화면 그리기
        screen.fill((20, 20, 40))  # 어두운 배경
        
        # 보스 패들 그리기
        boss_rect = pygame.Rect(boss_x, boss_y, boss_width, boss_height)
        pygame.draw.rect(screen, (255, 100, 100), boss_rect)
        pygame.draw.rect(screen, (255, 200, 200), boss_rect, 2)  # 테두리
        
        # 보스 패들 히트박스 표시 (디버그용)
        debug_rect = pygame.Rect(boss_x - 5, boss_y - 5, boss_width + 10, boss_height + 10)
        pygame.draw.rect(screen, (255, 255, 0, 50), debug_rect, 1)
        
        # 물방울 그리기
        for droplet in trident.water_droplets:
            alpha = int(droplet['life'] * 200)
            color = (100, 150, 255)
            
            # 물방울 본체
            pygame.draw.circle(screen, color, 
                             (int(droplet['x']), int(droplet['y'])), 
                             droplet['size'])
            
            # 하이라이트
            highlight_pos = (int(droplet['x'] - droplet['size']//3), 
                           int(droplet['y'] - droplet['size']//3))
            pygame.draw.circle(screen, (200, 220, 255), 
                             highlight_pos, droplet['size']//2)
            
            # 물방울 히트박스 표시 (디버그용)
            droplet_rect = pygame.Rect(
                droplet['x'] - droplet['size'],
                droplet['y'] - droplet['size'],
                droplet['size'] * 2,
                droplet['size'] * 2
            )
            pygame.draw.rect(screen, (0, 255, 255, 50), droplet_rect, 1)
        
        # UI 텍스트
        info_texts = [
            f"Water Droplets: {len(trident.water_droplets)}",
            "Boss Paddle: Use LEFT/RIGHT arrows to move",
            "SPACE: Spawn droplets manually",
            f"A: Toggle auto-spawn ({'ON' if auto_spawn else 'OFF'})",
            "ESC: Exit"
        ]
        
        y_offset = 10
        for text in info_texts:
            text_surface = font.render(text, True, (255, 255, 255))
            screen.blit(text_surface, (10, y_offset))
            y_offset += 25
        
        # 보스 패들 위치 표시
        boss_text = font.render("BOSS", True, (255, 100, 100))
        boss_text_rect = boss_text.get_rect(center=(boss_x + boss_width//2, boss_y - 10))
        screen.blit(boss_text, boss_text_rect)
        
        pygame.display.flip()
    
    pygame.quit()
    
    print("\n테스트 종료")
    print(f"최종 물방울 개수: {len(trident.water_droplets)}개")

if __name__ == "__main__":
    test_boss_collision()