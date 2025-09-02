#!/usr/bin/env python3
"""
BossPong 실행 테스트
게임이 실제로 실행되는지 확인
"""

import pygame
import sys
import time

def test_basic_run():
    """기본 실행 테스트"""
    print("=" * 50)
    print("BossPong 실행 테스트")
    print("=" * 50)
    
    # 게임 실행 (3초 후 자동 종료)
    import threading
    
    def auto_quit():
        time.sleep(3)
        pygame.event.post(pygame.event.Event(pygame.QUIT))
    
    # 자동 종료 타이머
    timer = threading.Thread(target=auto_quit)
    timer.daemon = True
    timer.start()
    
    try:
        from bosspong import main
        main()
    except SystemExit:
        print("✅ 게임이 정상적으로 종료되었습니다")
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_basic_run()