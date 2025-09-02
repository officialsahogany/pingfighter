#!/usr/bin/env python3
"""
라그나로크 해머 스턴 버그 - 실제 게임 테스트
AI가 활성화된 상태에서 실제로 스턴이 작동하는지 확인합니다.
"""

import pygame
import sys
import os
import time

# 게임 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 필요한 모듈 임포트
import pingfighter
from legendary_items import get_legendary_manager

def test_ragnarok_in_game():
    """실제 게임에서 라그나로크 해머 테스트"""
    
    # Pygame 초기화
    pygame.init()
    screen = pygame.display.set_mode((pingfighter.WIDTH, pingfighter.HEIGHT))
    pygame.display.set_caption("라그나로크 해머 스턴 테스트")
    clock = pygame.time.Clock()
    
    # 전설 아이템 매니저 가져오기
    legendary_manager = get_legendary_manager()
    
    # 라그나로크 해머 강제 활성화
    legendary_manager.activate_item("ragnarok_hammer", {})
    print("🔨 라그나로크 해머 활성화!")
    
    # 게임 상태 설정
    pingfighter.current_stage = 1
    pingfighter.ai_enabled = True
    pingfighter.ai_mode = "pro"
    pingfighter.boss_knockback_timer = 0
    pingfighter.boss_stun_timer = 0
    pingfighter.ragnarok_stun_pending = 0
    
    # 패들 초기화
    pingfighter.BOSS.x = 250
    pingfighter.BOSS.y = 50
    pingfighter.PLAYER.x = 250
    pingfighter.PLAYER.y = pingfighter.HEIGHT - 100
    
    # 공 초기화 (보스 쪽에서 시작)
    pingfighter.ball_pos = [300, 100]
    pingfighter.ball_vel = [0, 15]  # 아래쪽으로
    pingfighter.is_waiting_for_serve = False
    pingfighter.is_player_serve = False
    
    print("\n=== 테스트 시작 ===")
    print("공이 보스에게 향합니다...")
    print("라그나로크 해머가 활성화되어 있으므로 넉백과 스턴이 발생해야 합니다.")
    print("\n조작법:")
    print("ESC: 종료")
    print("SPACE: 공 리셋 (디버깅용)")
    print()
    
    running = True
    frame_count = 0
    hit_detected = False
    
    while running:
        dt = clock.tick(60)
        frame_count += 1
        
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 공 리셋
                    pingfighter.ball_pos = [300, 100]
                    pingfighter.ball_vel = [0, 15]
                    hit_detected = False
                    print("공 리셋!")
        
        # 키 입력 처리 (플레이어 이동)
        keys = pygame.key.get_pressed()
        if keys[pygame.K_LEFT]:
            pingfighter.PLAYER.x -= 10
            pingfighter.PLAYER.x = max(0, pingfighter.PLAYER.x)
        if keys[pygame.K_RIGHT]:
            pingfighter.PLAYER.x += 10
            pingfighter.PLAYER.x = min(pingfighter.WIDTH - pingfighter.PADDLE_WIDTH, pingfighter.PLAYER.x)
        
        # 공 업데이트
        pingfighter.ball_pos[0] += pingfighter.ball_vel[0]
        pingfighter.ball_pos[1] += pingfighter.ball_vel[1]
        
        # 벽 충돌
        if pingfighter.ball_pos[0] <= pingfighter.BALL_SIZE or pingfighter.ball_pos[0] >= pingfighter.WIDTH - pingfighter.BALL_SIZE:
            pingfighter.ball_vel[0] = -pingfighter.ball_vel[0]
        
        # 보스 패들과 충돌 체크
        if (pingfighter.ball_vel[1] < 0 and  # 공이 위로 이동 중
            pingfighter.ball_pos[1] - pingfighter.BALL_SIZE <= pingfighter.BOSS.y + 20 and
            pingfighter.ball_pos[0] >= pingfighter.BOSS.x and 
            pingfighter.ball_pos[0] <= pingfighter.BOSS.x + pingfighter.PADDLE_WIDTH):
            
            if not hit_detected:
                hit_detected = True
                print(f"\n[프레임 {frame_count}] 보스가 공을 받았습니다!")
                
                # 라그나로크 해머 넉백 효과 시뮬레이션
                hammer = legendary_manager.items.get("ragnarok_hammer")
                if hammer and hammer.active:
                    import math
                    ball_speed = math.sqrt(pingfighter.ball_vel[0]**2 + pingfighter.ball_vel[1]**2)
                    horizontal_velocity, stun_duration = hammer.calculate_knockback(ball_speed, pingfighter.BOSS.x)
                    
                    # 넉백 설정
                    pingfighter.boss_knockback_timer = 180  # 3초
                    pingfighter.boss_knockback_vel = horizontal_velocity
                    pingfighter.ragnarok_stun_pending = int(stun_duration * 60)
                    
                    print(f"  넉백 타이머: {pingfighter.boss_knockback_timer}")
                    print(f"  넉백 속도: {pingfighter.boss_knockback_vel:.1f}")
                    print(f"  예정된 스턴: {pingfighter.ragnarok_stun_pending} 프레임")
            
            # 공 반사
            pingfighter.ball_vel[1] = abs(pingfighter.ball_vel[1])
        
        # 플레이어 패들과 충돌
        if (pingfighter.ball_vel[1] > 0 and
            pingfighter.ball_pos[1] + pingfighter.BALL_SIZE >= pingfighter.PLAYER.y and
            pingfighter.ball_pos[0] >= pingfighter.PLAYER.x and 
            pingfighter.ball_pos[0] <= pingfighter.PLAYER.x + pingfighter.PADDLE_WIDTH):
            
            pingfighter.ball_vel[1] = -abs(pingfighter.ball_vel[1])
            hit_detected = False
        
        # 공이 화면 밖으로 나가면 리셋
        if pingfighter.ball_pos[1] < 0 or pingfighter.ball_pos[1] > pingfighter.HEIGHT:
            pingfighter.ball_pos = [300, 100]
            pingfighter.ball_vel = [0, 15]
            hit_detected = False
            print("공이 화면 밖으로 나갔습니다. 리셋!")
        
        # 보스 AI 처리
        pingfighter.handle_boss()
        
        # 디버그 정보 출력 (주요 프레임에만)
        if frame_count % 30 == 0 or pingfighter.boss_knockback_timer == 1 or pingfighter.boss_stun_timer == 1:
            if pingfighter.boss_knockback_timer > 0 or pingfighter.boss_stun_timer > 0 or pingfighter.ragnarok_stun_pending > 0:
                print(f"[프레임 {frame_count}] 넉백: {pingfighter.boss_knockback_timer}, 스턴: {pingfighter.boss_stun_timer}, 예정: {pingfighter.ragnarok_stun_pending}")
        
        # 화면 그리기
        screen.fill((0, 0, 0))
        
        # 패들 그리기
        pygame.draw.rect(screen, (255, 0, 0) if pingfighter.boss_stun_timer > 0 else (255, 255, 255), 
                        (pingfighter.BOSS.x, pingfighter.BOSS.y, pingfighter.PADDLE_WIDTH, 20))
        pygame.draw.rect(screen, (0, 255, 0), 
                        (pingfighter.PLAYER.x, pingfighter.PLAYER.y, pingfighter.PADDLE_WIDTH, 20))
        
        # 공 그리기
        pygame.draw.circle(screen, (255, 255, 0), 
                          (int(pingfighter.ball_pos[0]), int(pingfighter.ball_pos[1])), 
                          pingfighter.BALL_SIZE)
        
        # 상태 표시
        font = pygame.font.Font(None, 36)
        if pingfighter.boss_stun_timer > 0:
            text = font.render(f"STUN: {pingfighter.boss_stun_timer/60:.1f}s", True, (255, 0, 0))
            screen.blit(text, (10, 10))
        elif pingfighter.boss_knockback_timer > 0:
            text = font.render(f"KNOCKBACK: {pingfighter.boss_knockback_timer/60:.1f}s", True, (255, 255, 0))
            screen.blit(text, (10, 10))
        
        # 라그나로크 해머 상태 표시
        if "ragnarok_hammer" in legendary_manager.active_items:
            hammer_text = font.render("RAGNAROK ACTIVE", True, (255, 100, 100))
            screen.blit(hammer_text, (10, 50))
        
        pygame.display.flip()
    
    pygame.quit()
    print("\n=== 테스트 종료 ===")

if __name__ == "__main__":
    test_ragnarok_in_game()