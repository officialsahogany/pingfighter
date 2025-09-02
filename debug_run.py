#!/usr/bin/env python3
"""
BossPong 디버그 실행
게임이 바로 종료되는 문제 디버깅
"""

import pygame
import sys

def debug_run():
    """디버그 실행"""
    print("=" * 50)
    print("BossPong 디버그 실행")
    print("=" * 50)
    
    # 게임 임포트 및 초기화
    from bosspong import BossPongGame
    
    # 게임 인스턴스 생성
    print("🔍 게임 인스턴스 생성 중...")
    game = BossPongGame()
    
    print(f"🔍 running 상태: {game.running}")
    print(f"🔍 current_mode: {game.current_mode}")
    print(f"🔍 opening_system.active: {game.opening_system.active}")
    
    # 수동으로 몇 프레임 실행
    print("\n🔍 게임 루프 수동 실행...")
    
    for i in range(5):
        print(f"\n--- 프레임 {i+1} ---")
        
        # 이벤트 체크
        events = pygame.event.get()
        print(f"  이벤트 수: {len(events)}")
        
        for event in events:
            if event.type == pygame.QUIT:
                print("  QUIT 이벤트 감지!")
                game.running = False
                break
        
        # 상태 확인
        print(f"  running: {game.running}")
        print(f"  mode: {game.current_mode}")
        
        if not game.running:
            print("  게임이 종료됨!")
            break
        
        # 업데이트
        dt = 0.016  # 60 FPS
        game.update(dt)
        
        # 오프닝 상태 확인
        if hasattr(game.opening_system, 'active'):
            print(f"  opening active: {game.opening_system.active}")
            print(f"  opening mode: {game.opening_system.mode}")
            print(f"  opening timer: {game.opening_system.timer}")
        
        # 렌더링
        game.render()
        
        # 잠시 대기
        pygame.time.wait(100)  # 100ms
    
    print("\n🔍 디버그 완료")
    
    # 정리
    if hasattr(game, 'cleanup'):
        game.cleanup()
    else:
        pygame.quit()

if __name__ == "__main__":
    debug_run()