#!/usr/bin/env python3
"""
PingFighter 게임 실행 스크립트
원본 pingfighter.py를 실행합니다.
"""
import sys
import os

def main():
    """게임 실행"""
    try:
        print("🎮 PingFighter 게임을 시작합니다...")
        
        # 새로운 모듈화된 pingfighter.py 실행
        import pingfighter
        pingfighter.main()
        
    except Exception as e:
        print(f"게임 실행 중 오류가 발생했습니다: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()

