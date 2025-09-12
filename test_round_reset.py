#!/usr/bin/env python3
"""
라운드 효과 초기화 테스트
- 물방울 파티클이 라운드 종료 시 초기화되는지 확인
"""
import pygame
import sys
import os
import random

# 모듈 임포트를 위한 경로 설정
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from legendary_items import get_legendary_manager

def test_round_reset():
    """라운드 리셋 시 물방울 파티클 초기화 테스트"""
    print("=" * 60)
    print("포세이돈의 삼지창 라운드 효과 초기화 테스트")
    print("=" * 60)
    
    # Pygame 초기화
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("Round Reset Test")
    clock = pygame.time.Clock()
    
    # 전설 아이템 매니저 가져오기
    legendary_manager = get_legendary_manager()
    if not legendary_manager:
        print("❌ 전설 아이템 매니저를 가져올 수 없습니다.")
        return
    
    # 포세이돈의 삼지창 활성화
    trident = legendary_manager.get_item("poseidon_trident")
    if not trident:
        print("❌ 포세이돈의 삼지창을 찾을 수 없습니다.")
        return
    
    trident.activate({})
    print("✅ 포세이돈의 삼지창 활성화됨")
    
    # 테스트용 물방울 생성
    print("\n물방울 파티클 생성 중...")
    for i in range(10):
        # 임의의 위치에 물방울 생성
        x = random.randint(100, 700)
        y = random.randint(100, 500)
        
        for _ in range(3):
            droplet = {
                'x': x + random.randint(-20, 20),
                'y': y + random.randint(-20, 20),
                'vx': random.uniform(-2, 2),
                'vy': random.uniform(-3, 0),
                'life': 1.0,
                'size': random.randint(3, 6)
            }
            trident.water_droplets.append(droplet)
    
    print(f"생성된 물방울 수: {len(trident.water_droplets)}개")
    
    # 화면에 표시
    running = True
    frame_count = 0
    reset_done = False
    
    font = pygame.font.Font(None, 36)
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE and not reset_done:
                    # 스페이스바로 라운드 리셋
                    print("\n🔄 라운드 효과 리셋 실행...")
                    legendary_manager.reset_round_effects()
                    reset_done = True
                    print(f"리셋 후 물방울 수: {len(trident.water_droplets)}개")
                elif event.key == pygame.K_ESCAPE:
                    running = False
        
        # 화면 그리기
        screen.fill((20, 20, 40))  # 어두운 배경
        
        # 물방울 업데이트 및 그리기
        if not reset_done:
            # 물방울 업데이트
            for droplet in trident.water_droplets[:]:
                droplet['x'] += droplet['vx']
                droplet['y'] += droplet['vy']
                droplet['vy'] += 0.3  # 중력
                droplet['life'] -= 0.01
                
                if droplet['life'] <= 0 or droplet['y'] > 600:
                    trident.water_droplets.remove(droplet)
        
        # 물방울 그리기
        for droplet in trident.water_droplets:
            alpha = int(droplet['life'] * 200)
            color = (100, 150, 255)
            pygame.draw.circle(screen, color, 
                             (int(droplet['x']), int(droplet['y'])), 
                             droplet['size'])
            # 하이라이트
            pygame.draw.circle(screen, (200, 220, 255), 
                             (int(droplet['x'] - droplet['size']//3), 
                              int(droplet['y'] - droplet['size']//3)), 
                             droplet['size']//2)
        
        # 텍스트 표시
        if not reset_done:
            text1 = font.render(f"Water Droplets: {len(trident.water_droplets)}", True, (255, 255, 255))
            text2 = font.render("Press SPACE to reset round effects", True, (255, 255, 100))
            screen.blit(text1, (250, 50))
            screen.blit(text2, (150, 100))
        else:
            text1 = font.render(f"Water Droplets: {len(trident.water_droplets)}", True, (255, 255, 255))
            text2 = font.render("Round effects reset!", True, (100, 255, 100))
            text3 = font.render("Press ESC to exit", True, (200, 200, 200))
            screen.blit(text1, (250, 50))
            screen.blit(text2, (250, 100))
            screen.blit(text3, (280, 150))
        
        pygame.display.flip()
        clock.tick(60)
        frame_count += 1
    
    pygame.quit()
    
    # 결과 출력
    print("\n" + "=" * 60)
    print("테스트 결과:")
    if reset_done and len(trident.water_droplets) == 0:
        print("✅ 라운드 효과 초기화 성공! 모든 물방울이 제거되었습니다.")
    elif reset_done:
        print(f"❌ 라운드 효과 초기화 실패. 남은 물방울: {len(trident.water_droplets)}개")
    else:
        print("⚠️ 테스트가 완료되지 않았습니다.")

if __name__ == "__main__":
    test_round_reset()