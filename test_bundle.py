#!/usr/bin/env python3
"""
번들 앱 테스트 스크립트
리소스 파일 경로 문제를 진단합니다.
"""

import os
import sys
import traceback

def test_bundle():
    print("=" * 50)
    print("PingFighter 번들 테스트")
    print("=" * 50)
    
    # 실행 경로 확인
    print(f"실행 파일: {sys.argv[0]}")
    print(f"실행 디렉토리: {os.getcwd()}")
    print(f"Python 경로: {sys.executable}")
    
    # 번들 여부 확인
    if getattr(sys, 'frozen', False):
        print("✅ PyInstaller 번들로 실행 중")
        bundle_dir = sys._MEIPASS
        print(f"번들 디렉토리: {bundle_dir}")
    else:
        print("⚠️ 일반 Python으로 실행 중")
        bundle_dir = os.path.dirname(os.path.abspath(__file__))
        print(f"스크립트 디렉토리: {bundle_dir}")
    
    # 중요 파일 확인
    print("\n📁 리소스 파일 확인:")
    
    required_files = [
        'ball.png',
        'stage1.png',
        'NeoDunggeunmoPro.ttf',
        'items.py',
        'gacha.py',
        'sounds/paddle_hit.wav',
        'items/battery.png'
    ]
    
    for file in required_files:
        file_path = os.path.join(bundle_dir, file)
        if os.path.exists(file_path):
            print(f"  ✅ {file}")
        else:
            print(f"  ❌ {file} (찾을 수 없음)")
    
    # Pygame 초기화 테스트
    print("\n🎮 Pygame 초기화 테스트:")
    try:
        import pygame
        pygame.init()
        print("  ✅ Pygame 초기화 성공")
        
        # 디스플레이 테스트
        screen = pygame.display.set_mode((600, 750))
        pygame.display.set_caption("PingFighter Test")
        print("  ✅ 디스플레이 생성 성공")
        
        # 간단한 이벤트 루프
        clock = pygame.time.Clock()
        running = True
        frames = 0
        
        while running and frames < 60:  # 1초간 실행
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    running = False
            
            screen.fill((0, 0, 0))
            pygame.display.flip()
            clock.tick(60)
            frames += 1
        
        pygame.quit()
        print(f"  ✅ 테스트 완료 ({frames} 프레임)")
        
    except Exception as e:
        print(f"  ❌ Pygame 오류: {e}")
        traceback.print_exc()
    
    print("\n✅ 테스트 완료!")
    return True

if __name__ == "__main__":
    try:
        test_bundle()
    except Exception as e:
        print(f"❌ 치명적 오류: {e}")
        traceback.print_exc()
        sys.exit(1)