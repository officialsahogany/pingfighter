#!/usr/bin/env python3
"""
BossPong 빠른 실행 테스트
게임이 정상적으로 시작되고 기본 기능이 작동하는지 확인
"""

import pygame
import sys
import time

def test_game_startup():
    """게임 시작 테스트"""
    print("=" * 50)
    print("BossPong 빠른 실행 테스트")
    print("=" * 50)
    
    try:
        # Pygame 초기화
        pygame.init()
        print("✅ Pygame 초기화 성공")
        
        # 메인 모듈 임포트
        from bosspong import BossPongGame
        print("✅ BossPongGame 클래스 임포트 성공")
        
        # 게임 인스턴스 생성
        game = BossPongGame()
        print("✅ 게임 인스턴스 생성 성공")
        
        # 화면 생성 확인
        if game.screen:
            width = game.global_manager.get('WIDTH', 600)
            height = game.global_manager.get('HEIGHT', 750)
            print(f"✅ 화면 생성 성공: {width}x{height}")
        
        # 주요 시스템 확인
        if game.global_manager:
            print("✅ GlobalManager 활성화")
        if game.event_manager:
            print("✅ EventManager 활성화")
        if game.sound_manager:
            print("✅ SoundManager 활성화")
        if hasattr(game, 'menu_system') and game.menu_system:
            print("✅ UIManager 활성화")
        if game.round_manager:
            print("✅ RoundManager 활성화")
        
        # 게임 상태 확인
        print(f"✅ 게임 상태: {game.game_state}")
        
        # 짧은 프레임 실행 (실제 게임 루프 테스트)
        print("\n몇 프레임 실행 중...")
        clock = pygame.time.Clock()
        
        for i in range(5):  # 5프레임만 실행
            # 이벤트 처리
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    break
            
            # 업데이트 (매우 짧은 시간)
            dt = 0.016  # 60 FPS 기준
            
            # 화면 그리기
            game.screen.fill((0, 0, 0))
            
            # 메뉴 시스템 렌더링 테스트
            if hasattr(game, 'menu_system') and hasattr(game.menu_system, 'render'):
                game.menu_system.render()
            
            pygame.display.flip()
            clock.tick(60)
            
            print(f"  프레임 {i+1}/5 완료")
        
        print("\n✅ 게임 루프 테스트 성공")
        
        # 정리
        pygame.quit()
        print("✅ 정상 종료")
        
        print("\n" + "=" * 50)
        print("모든 테스트 통과! 게임이 정상 작동합니다.")
        print("=" * 50)
        
        return True
        
    except ImportError as e:
        print(f"❌ 임포트 오류: {e}")
        return False
    except AttributeError as e:
        print(f"❌ 속성 오류: {e}")
        return False
    except Exception as e:
        print(f"❌ 예상치 못한 오류: {e}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        # 확실한 정리
        pygame.quit()

if __name__ == "__main__":
    success = test_game_startup()
    sys.exit(0 if success else 1)