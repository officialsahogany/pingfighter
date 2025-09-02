#!/usr/bin/env python3
"""
BossPong 빠른 시작
오프닝을 건너뛰고 바로 게임 시작
"""

import os
import sys

# 빠른 시작 플래그 설정
os.environ['BOSSPONG_QUICK_START'] = '1'

# 메인 게임 실행
from bosspong import BossPongGame

def main():
    """메인 함수"""
    print("=" * 50)
    print("BossPong - 빠른 시작 모드")
    print("=" * 50)
    print("오프닝을 건너뛰고 바로 게임을 시작합니다!")
    print()
    print("조작법:")
    print("  ← / → 또는 A / D : 패들 이동")
    print("  SHIFT : 대시")
    print("  SPACE : 파워 스매싱")
    print("  1-6 : 특수 아이템")
    print("  P : 일시정지")
    print("  ESC : 메뉴로 돌아가기")
    print("=" * 50)
    
    # 게임 실행
    game = BossPongGame()
    game.run()

if __name__ == "__main__":
    main()